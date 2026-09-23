--!strict

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
	local Format = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Format"))
	local ForgePathClaim = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ForgePathClaim"))
	local WheelMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("WheelMath"))
	local CommandMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CommandMath"))
	local ProfileBagMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileBagMath"))
	local ProgressionOpsMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProgressionOpsMath"))
	local UtcClockMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UtcClockMath"))

	local ProgressionService = {}

	local function currentDay(): number
		return UtcClockMath.Day(os.time())
	end

	local function currentWeek(): number
		return UtcClockMath.Week(os.time())
	end

	local function copyReward(reward)
		return table.clone(reward)
	end

	local function commanderLevel(xp: number): number
		return CommandMath.Level(xp, GameConfig.Operations.MaxCommanderLevel)
	end

	local function commanderFloorXP(level: number): number
		return CommandMath.FloorXP(level)
	end

	local function commanderNextXP(level: number): number
		return CommandMath.NextXP(level, GameConfig.Operations.MaxCommanderLevel)
	end

	local function commanderRank(level: number): string
		return CommandMath.Rank(level)
	end

	local function ensureCommand(profile)
		profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
		return profile.Command
	end

	-- Partial Profiles (Studio fixtures / mid-migrate) may omit Stats — weekly /
	-- expedition / season / signal-shop claim paths must not throw before rewards apply.
	local function ensureStats(profile)
		return ProfileBagMath.EnsureStats(profile)
	end

	local function bumpStat(profile, key: string, amount: number?)
		return ProfileBagMath.BumpStat(profile, key, amount)
	end

	-- WeeklyRelics (and similar) grant Keys tables — ApplyReward must not throw when
	-- Items / Items.Keys are absent on Studio fixtures before the Claimed flag sticks.
	local function ensureItemKeys(profile)
		return ProfileBagMath.EnsureItemKeys(profile)
	end

	local function ensureDaily(profile)
		return ProfileBagMath.EnsureDaily(profile)
	end

	-- Studio fixtures / mid-migrate bags may omit Quests entirely — EnsureQuests /
	-- Progress / ClaimQuest must not throw before the day roll can seed Items.
	local function ensureQuests(profile)
		return ProfileBagMath.EnsureQuests(profile)
	end

	-- ApplyReward FreeSpins may leave TimedRewards untouched while Studio fixtures
	-- omit the bag — EnsureTimedRewards / ClaimTimedReward must nil-safe first.
	local function ensureTimedRewardsBag(profile)
		return ProfileBagMath.EnsureTimedRewards(profile)
	end

	-- ApplyReward FreeSpins seeds Wheel={FreeSpins=N} without LastSpinAt/Spins —
	-- WheelState / SpinWheel must rebuild before cooldown arithmetic.
	local function ensureWheel(profile)
		profile.Wheel = WheelMath.Ensure(profile.Wheel)
		return profile.Wheel
	end

	local function awardCommandXP(profile, amount: number)
		local value = math.max(0, math.floor(amount))
		value = math.floor(value * (1 + Economy.DomainTreeBonus(profile, "CommandXP")))
		local command = ensureCommand(profile)
		command.XP = (tonumber(command.XP) or 0) + value
		command.SeasonXP = (tonumber(command.SeasonXP) or 0) + value
	end

	ProgressionService.AwardCommandXP = awardCommandXP

	local function findOperation(list, id: string)
		return ProgressionOpsMath.FindById(list, id)
	end

	local function currentWeeklyValue(profile, kind: string): number
		return ProgressionOpsMath.WeeklyValue(profile, kind)
	end

	local function commanderReward(level: number)
		return ProgressionOpsMath.CommanderReward(level)
	end

	local function titleUnlocked(profile, title): boolean
		local command = ensureCommand(profile)
		return ProgressionOpsMath.TitleUnlocked(
			profile,
			title,
			command,
			commanderLevel(command.XP),
			Economy.Gte
		)
	end

	function ProgressionService.ApplyReward(profile, reward, production: number?): string
		local parts = {}
		if reward.Cash and reward.Cash > 0 then
			profile.Cash = Economy.Add(profile.Cash, reward.Cash)
			profile.RunCash = Economy.Add(profile.RunCash, reward.Cash)
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, reward.Cash)
			table.insert(parts, Format.Number(reward.Cash) .. " flux")
		end
		if reward.CashMinutes and reward.CashMinutes > 0 then
			local generated = Economy.Max(500, Economy.Mul(production or Economy.SteadyProduction(profile), 60 * reward.CashMinutes))
			profile.Cash = Economy.Add(profile.Cash, generated)
			profile.RunCash = Economy.Add(profile.RunCash, generated)
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, generated)
			table.insert(parts, Format.Number(generated) .. " flux")
		end
		if reward.Stardust and reward.Stardust > 0 then
			-- Partial Profiles (Studio fixtures) may omit numeric Stardust/Cores.
			profile.Stardust = (tonumber(profile.Stardust) or 0) + reward.Stardust
			table.insert(parts, Format.Number(reward.Stardust) .. " stardust")
		end
		if reward.Cores and reward.Cores > 0 then
			profile.Cores = (tonumber(profile.Cores) or 0) + reward.Cores
			table.insert(parts, Format.Number(reward.Cores) .. " cores")
		end
		if reward.Boost and GameConfig.Boosts[reward.Boost] then
			local inventory = ProfileBagMath.EnsureBoostInventory(profile)
			inventory[reward.Boost] = (tonumber(inventory[reward.Boost]) or 0) + 1
			table.insert(parts, GameConfig.Boosts[reward.Boost].Name)
		end
		if reward.Signals and reward.Signals > 0 then
			local command = ensureCommand(profile)
			command.Signals = (tonumber(command.Signals) or 0) + reward.Signals
			table.insert(parts, Format.Number(reward.Signals) .. " signals")
		end
		if reward.CommandXP and reward.CommandXP > 0 then
			awardCommandXP(profile, reward.CommandXP)
			table.insert(parts, Format.Number(reward.CommandXP) .. " command XP")
		end
		if reward.StreakShield and reward.StreakShield > 0 then
			local command = ensureCommand(profile)
			command.StreakShields = (tonumber(command.StreakShields) or 0) + reward.StreakShield
			table.insert(parts, Format.Number(reward.StreakShield) .. " streak shield")
		end
		if reward.Essence and reward.Essence > 0 then
			local domain = ProfileBagMath.EnsureDomain(profile)
			domain.Essence = math.min(1_000_000, math.max(0, math.floor(tonumber(domain.Essence) or 0)) + math.floor(reward.Essence))
			table.insert(parts, Format.Number(reward.Essence) .. " domain essence")
		end
		if reward.DomainEssence and reward.DomainEssence > 0 then
			local domain = ProfileBagMath.EnsureDomain(profile)
			domain.Essence = math.min(1_000_000, math.max(0, math.floor(tonumber(domain.Essence) or 0)) + math.floor(reward.DomainEssence))
			table.insert(parts, Format.Number(reward.DomainEssence) .. " domain essence")
		end
		if reward.Fragments and reward.Fragments > 0 then
			if type(profile.Anomaly) ~= "table" then
				profile.Anomaly = { Fragments = 0 }
			end
			profile.Anomaly.Fragments = (tonumber(profile.Anomaly.Fragments) or 0) + math.floor(reward.Fragments)
			table.insert(parts, Format.Number(reward.Fragments) .. " fragments")
		end
		if reward.FreeSpins and reward.FreeSpins > 0 then
			local wheel = ensureWheel(profile)
			-- Belt-and-suspenders: Ensure already tonumber-safes, but keep grant
			-- path robust if a caller bypasses Ensure with a string FreeSpins bag.
			wheel.FreeSpins = (tonumber(wheel.FreeSpins) or 0) + math.floor(reward.FreeSpins)
			table.insert(parts, Format.Number(reward.FreeSpins) .. " free spin" .. (reward.FreeSpins == 1 and "" or "s"))
		end
		if type(reward.Keys) == "table" then
			local keys = ensureItemKeys(profile)
			for crateId, amount in reward.Keys do
				if type(crateId) == "string" and type(amount) == "number" and amount > 0 then
					keys[crateId] = (tonumber(keys[crateId]) or 0) + math.floor(amount)
					table.insert(parts, Format.Number(amount) .. " " .. crateId)
				end
			end
		end
		return table.concat(parts, ", ")
	end

	function ProgressionService.EnsureQuests(profile, userId: number)
		local day = currentDay()
		local questsBag = ensureQuests(profile)
		if questsBag.Day == day and #questsBag.Items > 0 then
			return false
		end

		local production = Economy.Max(4, Economy.Production(profile))
		local scale = 1 + (tonumber(profile.Rebirths) or 0) * 0.15
		local earnTarget = math.floor(math.max(2_000, Economy.AsNumber(Economy.Mul(production, 8 * 60)) * scale))
		local tapTarget = math.floor((40 + (tonumber(profile.Rebirths) or 0) * 3) * scale)
		local upgradeTarget = math.floor(3 + math.min(7, (tonumber(profile.Rebirths) or 0) / 2))
		local rotation = (day + userId) % 3

		local quests = {
			{
				Id = string.format("earn_%d", day),
				Name = "Shift Quota",
				Description = "Bank flux from your vault.",
				Kind = "EarnCash",
				Target = earnTarget,
				Progress = 0,
				Reward = { Cash = math.floor(earnTarget * 0.15), Stardust = 5 },
				Claimed = false,
			},
			{
				Id = string.format("tap_%d", day),
				Name = "Hands On",
				Description = "Use manual overcharge.",
				Kind = "Tap",
				Target = tapTarget,
				Progress = 0,
				Reward = { Cash = math.floor(earnTarget * 0.08), Stardust = 4 },
				Claimed = false,
			},
			{
				Id = string.format("upgrade_%d", day),
				Name = rotation == 0 and "Machinist" or (rotation == 1 and "Research Grant" or "Expansion Plan"),
				Description = rotation == 0 and "Upgrade any machines."
					or (rotation == 1 and "Purchase research levels." or "Purchase machines or research."),
				Kind = rotation == 0 and "BuyMachine" or (rotation == 1 and "BuyResearch" or "BuyAny"),
				Target = upgradeTarget,
				Progress = 0,
				Reward = { Cash = math.floor(earnTarget * 0.12), Stardust = 6 },
				Claimed = false,
			},
		}

		profile.Quests = { Day = day, Items = quests }
		return true
	end

	function ProgressionService.Progress(profile, kind: string, amount: number)
		local questsBag = ensureQuests(profile)
		-- Progress/Target may arrive as numeric strings from Studio fixtures —
		-- AdvanceQuestProgress tonumber-safes before summing.
		ProgressionOpsMath.AdvanceQuestProgress(questsBag.Items, kind, amount)
	end

	function ProgressionService.ClaimQuest(profile, questId: string): (boolean, string)
		local questsBag = ensureQuests(profile)
		for _, quest in questsBag.Items do
			if quest.Id == questId then
				local ok, reason = ProgressionOpsMath.CanClaimQuest(quest)
				if not ok then
					return false, reason
				end
				quest.Claimed = true
				return true, ProgressionService.ApplyReward(profile, quest.Reward)
			end
		end
		return false, "Mission not found."
	end

	function ProgressionService.AchievementProgress(profile, kind: string): number
		return ProgressionOpsMath.AchievementProgress(profile, kind, Economy.AsNumber)
	end

	function ProgressionService.AchievementStates(profile)
		local states = {}
		-- Partial Profiles (Studio fixtures) may omit Achievements — UI projection must not throw.
		local claimed = type(profile.Achievements) == "table" and profile.Achievements or {}
		for _, achievement in GameConfig.Achievements do
			table.insert(states, {
				Id = achievement.Id,
				Name = achievement.Name,
				Description = achievement.Description,
				Target = achievement.Target,
				Progress = math.min(
					achievement.Target,
					ProgressionService.AchievementProgress(profile, achievement.Kind)
				),
				Reward = copyReward(achievement.Reward),
				Claimed = claimed[achievement.Id] == true,
			})
		end
		return states
	end

	function ProgressionService.ClaimAchievement(profile, achievementId: string): (boolean, string)
		for _, achievement in GameConfig.Achievements do
			if achievement.Id == achievementId then
				if type(profile.Achievements) ~= "table" then
					profile.Achievements = {}
				end
				if profile.Achievements[achievementId] then
					return false, "That milestone was already claimed."
				end
				if ProgressionService.AchievementProgress(profile, achievement.Kind) < achievement.Target then
					return false, "That milestone is not complete yet."
				end
				profile.Achievements[achievementId] = true
				return true, ProgressionService.ApplyReward(profile, achievement.Reward)
			end
		end
		return false, "Milestone not found."
	end

	function ProgressionService.DailyState(profile)
		local day = currentDay()
		local daily = ensureDaily(profile)
		local canClaim = daily.LastClaimDay < day
		local nextStreak
		if daily.LastClaimDay == day - 1 then
			nextStreak = daily.Streak + 1
		elseif canClaim then
			nextStreak = 1
		else
			nextStreak = daily.Streak
		end
		local rewardIndex = ((math.max(1, nextStreak) - 1) % #GameConfig.DailyRewards) + 1
		return {
			CanClaim = canClaim,
			Streak = daily.Streak,
			NextStreak = nextStreak,
			RewardIndex = rewardIndex,
			Rewards = GameConfig.DailyRewards,
		}
	end

	function ProgressionService.ClaimDaily(profile): (boolean, string)
		local day = currentDay()
		local daily = ensureDaily(profile)
		if daily.LastClaimDay >= day then
			return false, "Come back tomorrow for the next daily."
		end
		if daily.LastClaimDay == day - 1 then
			daily.Streak += 1
		elseif daily.LastClaimDay < day - 1 and daily.Streak > 0 then
			-- Partial Command bags must not throw before streak shield consume / ApplyReward.
			local command = ensureCommand(profile)
			local shields = math.max(0, math.floor(tonumber(command.StreakShields) or 0))
			if shields > 0 then
				command.StreakShields = shields - 1
				daily.Streak += 1
			else
				daily.Streak = 1
			end
		else
			daily.Streak = 1
		end
		daily.LastClaimDay = day
		local rewardIndex = ((daily.Streak - 1) % #GameConfig.DailyRewards) + 1
		local reward = GameConfig.DailyRewards[rewardIndex]
		return true, ProgressionService.ApplyReward(profile, reward, Economy.Production(profile))
	end

	function ProgressionService.EnsureWeekly(profile): boolean
		local command = ensureCommand(profile)
		local week = currentWeek()
		if command.Weekly.Week == week then

			local changed = false
			for _, directive in GameConfig.Operations.WeeklyDirectives do
				if command.Weekly.Baseline[directive.Kind] == nil then
					command.Weekly.Baseline[directive.Kind] = currentWeeklyValue(profile, directive.Kind)
					changed = true
				end
			end
			return changed
		end
		local baseline = {}
		for _, directive in GameConfig.Operations.WeeklyDirectives do
			baseline[directive.Kind] = currentWeeklyValue(profile, directive.Kind)
		end
		command.Weekly = { Week = week, Baseline = baseline, Claimed = {} }
		return true
	end

	function ProgressionService.WeeklyState(profile)
		local command = ensureCommand(profile)
		local current = command.Weekly
		local weekMatches = current.Week == currentWeek()
		local baselines = weekMatches and current.Baseline or {}
		local claimed = weekMatches and current.Claimed or {}
		local level = commanderLevel(command.XP)
		local scale = 1 + math.floor((level - 1) / 10) * 0.35
		local items = {}
		for _, directive in GameConfig.Operations.WeeklyDirectives do
			local target = math.floor(directive.BaseTarget * scale)
			local baseline = baselines[directive.Kind]
			if baseline == nil then
				baseline = currentWeeklyValue(profile, directive.Kind)
			end
			table.insert(items, {
				Id = directive.Id,
				Name = directive.Name,
				Description = directive.Description,
				Progress = math.min(target, math.max(0, currentWeeklyValue(profile, directive.Kind) - baseline)),
				Target = target,
				Reward = copyReward(directive.Reward),
				Claimed = claimed[directive.Id] == true,
			})
		end
		return items
	end

	function ProgressionService.ClaimWeeklyDirective(profile, directiveId: string): (boolean, string)
		local command = ensureCommand(profile)
		ProgressionService.EnsureWeekly(profile)
		for _, item in ProgressionService.WeeklyState(profile) do
			if item.Id == directiveId then
				if item.Claimed then
					return false, "That weekly directive was already claimed."
				end
				if item.Progress < item.Target then
					return false, "That weekly directive is not complete."
				end
				command.Weekly.Claimed[directiveId] = true
				bumpStat(profile, "WeeklyClaimed", 1)
				return true, ProgressionService.ApplyReward(profile, item.Reward, Economy.Production(profile))
			end
		end
		return false, "Weekly directive not found."
	end

	function ProgressionService.TitleStates(profile)
		if GameConfig.Operations.TitlesEnabled == false then
			return {}
		end
		local command = ensureCommand(profile)
		local titles = {}
		for _, title in GameConfig.Operations.Titles do
			table.insert(titles, {
				Id = title.Id,
				Name = title.Name,
				Description = title.Description,
				Unlocked = titleUnlocked(profile, title),
				Equipped = command.EquippedTitle == title.Id,
				Fx = title.Fx,
			})
		end
		return titles
	end

	function ProgressionService.EquipTitle(profile, titleId: string): (boolean, string)
		if GameConfig.Operations.TitlesEnabled == false then
			return false, GameConfig.Operations.TitleStatus or "Titles are temporarily unavailable."
		end
		local title = findOperation(GameConfig.Operations.Titles, titleId)
		if not title or not titleUnlocked(profile, title) then
			return false, "That command title is still locked."
		end
		ensureCommand(profile).EquippedTitle = titleId
		return true, title.Name .. " equipped."
	end

	function ProgressionService.EnsureCommandRotations(profile): boolean
		local command = ensureCommand(profile)
		local changed = ProgressionService.EnsureWeekly(profile)
		local day = currentDay()
		if command.Shop.Day ~= day then
			command.Shop = { Day = day, Purchased = {} }
			changed = true
		end
		if command.SeasonId ~= GameConfig.Operations.SeasonId then
			command.SeasonId = GameConfig.Operations.SeasonId
			command.SeasonXP = 0
			command.SeasonClaims = {}
			changed = true
		end
		return changed
	end

	function ProgressionService.SignalShopState(profile)
		local command = ensureCommand(profile)
		local offers = {}
		local source = GameConfig.Operations.ShopOffers
		local day = currentDay()
		local purchased = if command.Shop.Day == day then command.Shop.Purchased else {}
		for slot = 1, 4 do
			local index = ((day + slot - 2) % #source) + 1
			local offer = source[index]
			table.insert(offers, {
				Id = offer.Id,
				Name = offer.Name,
				Description = offer.Description,
				Price = offer.Price,
				Reward = copyReward(offer.Reward),
				Color = offer.Color,
				Purchased = purchased[offer.Id] == true,
			})
		end
		return offers
	end

	function ProgressionService.BuySignalOffer(profile, offerId: string): (boolean, string)
		ProgressionService.EnsureCommandRotations(profile)
		for _, offer in ProgressionService.SignalShopState(profile) do
			if offer.Id == offerId then
				if offer.Purchased then
					return false, "That signal offer was already purchased today."
				end
				if profile.Command.Signals < offer.Price then
					return false, "You need more command signals."
				end
				profile.Command.Signals -= offer.Price
				profile.Command.Shop.Purchased[offerId] = true
				bumpStat(profile, "ShopPurchases", 1)
				return true, ProgressionService.ApplyReward(profile, offer.Reward, Economy.Production(profile))
			end
		end
		return false, "That signal offer is not in today's rotation."
	end

	function ProgressionService.LaunchExpedition(profile, expeditionId: string): (boolean, string)
		if profile.Command.ActiveExpedition.Id ~= "" then
			return false, "Claim or finish the active expedition first."
		end
		local expedition = Economy.GetExpedition(expeditionId) or findOperation(GameConfig.Operations.Expeditions, expeditionId)
		if not expedition then
			return false, "Expedition route not found."
		end
		if commanderLevel(profile.Command.XP) < expedition.RequiredLevel then
			return false, string.format("Commander level %d is required.", expedition.RequiredLevel)
		end
		local pilotLevel = profile.Command.Crew.Pilot or 1
		local durationScale = math.max(0.35, 1 - (pilotLevel - 1) * 0.05)
		local now = os.time()
		local duration = math.max(10, math.floor(expedition.Duration * durationScale))
		profile.Command.ActiveExpedition = { Id = expedition.Id, StartedAt = now, EndsAt = now + duration }
		return true, expedition.Name .. " launched."
	end

	function ProgressionService.ClaimExpedition(profile, random: Random): (boolean, string, string?, boolean?)
		local active = profile.Command.ActiveExpedition
		if active.Id == "" then
			return false, "No expedition is currently active."
		end
		if os.time() < active.EndsAt then
			return false, "That expedition is still underway."
		end
		local expedition = Economy.GetExpedition(active.Id) or findOperation(GameConfig.Operations.Expeditions, active.Id)
		if not expedition then
			profile.Command.ActiveExpedition = { Id = "", StartedAt = 0, EndsAt = 0 }
			return false, "The expedition route could not be recovered."
		end

		local reward = copyReward(expedition.Reward)
		local engineerLevel = profile.Command.Crew.Engineer or 1
		local yieldScale = 1 + (engineerLevel - 1) * 0.08
		if reward.CashMinutes then
			reward.CashMinutes *= yieldScale
		end
		if reward.Stardust then
			reward.Stardust = math.floor(reward.Stardust * yieldScale)
		end
		if reward.Signals then
			reward.Signals = math.floor(reward.Signals * yieldScale)
		end

		profile.Command.ExpeditionsCompleted += 1
		bumpStat(profile, "Expeditions", 1)
		profile.Command.ActiveExpedition = { Id = "", StartedAt = 0, EndsAt = 0 }
		local message = ProgressionService.ApplyReward(profile, reward, Economy.Production(profile))

		local navigatorLevel = profile.Command.Crew.Navigator or 1
		local chance = math.min(0.95, expedition.ArtifactChance + (navigatorLevel - 1) * 0.03)
		local artifactState = profile.Command.Artifacts[expedition.ArtifactId]
		local discovered = artifactState == nil
		local shouldDiscover = discovered and next(profile.Command.Artifacts) == nil
			or random:NextNumber() <= chance
		if shouldDiscover then
			if artifactState then
				artifactState.Fragments += 4 + math.floor(expedition.RequiredLevel / 10)
				message ..= string.format(", %s fragments", expedition.ArtifactId)
			else
				profile.Command.Artifacts[expedition.ArtifactId] = { Level = 1, Fragments = 0 }
				bumpStat(profile, "ArtifactsFound", 1)
				message ..= ", artifact discovered"
			end
			return true, message, expedition.ArtifactId, discovered
		end
		return true, message
	end

	function ProgressionService.EquipArtifact(profile, artifactId: string): (boolean, string)
		local artifact = findOperation(GameConfig.Operations.Artifacts, artifactId)
		if not artifact or not profile.Command.Artifacts[artifactId] then
			return false, "That artifact has not been discovered."
		end
		profile.Command.EquippedArtifact = artifactId
		return true, artifact.Name .. " equipped."
	end

	function ProgressionService.UpgradeArtifact(profile, artifactId: string): (boolean, string)
		local artifact = findOperation(GameConfig.Operations.Artifacts, artifactId)
		local owned = profile.Command.Artifacts[artifactId]
		if not artifact or not owned then
			return false, "That artifact has not been discovered."
		end
		if owned.Level >= 10 then
			return false, "That artifact is already max level."
		end
		local fragmentCost = 4 + owned.Level * 2
		local dustCost = 8 * owned.Level
		if owned.Fragments < fragmentCost or Economy.Lt(profile.Stardust, dustCost) then
			return false, string.format("Requires %d fragments and %d stardust.", fragmentCost, dustCost)
		end
		owned.Fragments -= fragmentCost
		profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, dustCost))
		owned.Level += 1
		awardCommandXP(profile, 45 * owned.Level)
		return true, string.format("%s upgraded to level %d.", artifact.Name, owned.Level)
	end

	function ProgressionService.UpgradeCrew(profile, roleId: string): (boolean, string)
		local role = GameConfig.Operations.Crew[roleId]
		local level = profile.Command.Crew[roleId]
		if not role or type(level) ~= "number" then
			return false, "Crew role not found."
		end
		if level >= role.MaxLevel then
			return false, "That crew career is already maxed."
		end
		local cost = math.floor(role.BaseCost * level ^ 1.55)
		if profile.Command.Signals < cost then
			return false, string.format("Requires %d command signals.", cost)
		end
		profile.Command.Signals -= cost
		profile.Command.Crew[roleId] += 1
		awardCommandXP(profile, 60 * level)
		return true, string.format("%s advanced to level %d.", role.Name, level + 1)
	end

	function ProgressionService.ClaimCommanderReward(profile, rawLevel: any): (boolean, string)
		if type(rawLevel) ~= "number" then
			return false, "Invalid commander level."
		end
		local level = math.floor(rawLevel)
		if level < 1 or level > commanderLevel(profile.Command.XP) then
			return false, "That commander level is not unlocked."
		end
		local key = tostring(level)
		if profile.Command.CommanderClaims[key] then
			return false, "That commander reward was already claimed."
		end
		profile.Command.CommanderClaims[key] = true
		return true, ProgressionService.ApplyReward(profile, commanderReward(level), Economy.Production(profile))
	end

	function ProgressionService.ClaimSeasonTier(profile, rawTier: any): (boolean, string)
		if type(rawTier) ~= "number" then
			return false, "Invalid season tier."
		end
		ProgressionService.EnsureCommandRotations(profile)
		local tierIndex = math.floor(rawTier)
		local tier = GameConfig.Operations.SeasonTiers[tierIndex]
		if not tier or profile.Command.SeasonXP < tier.RequiredXP then
			return false, "That season tier is still locked."
		end
		local key = tostring(tierIndex)
		if profile.Command.SeasonClaims[key] then
			return false, "That season tier was already claimed."
		end
		profile.Command.SeasonClaims[key] = true
		bumpStat(profile, "SeasonTiers", 1)
		return true, ProgressionService.ApplyReward(profile, tier.Reward, Economy.Production(profile))
	end

	-- "Forge Path" (src_ts/client/pages/ForgePathView.tsx): the single meta-progression track
	-- that replaced the old three-way split between Progression Tree (skill grid), Prestige
	-- (tier multipliers), and Season Pass (battle-pass chests). XP trickles in passively from
	-- normal play (see the CollectVault handler, which is the sole XP source) and each of the
	-- 80 steps (GameConfig.ForgePath.Steps) is claimed as one action that grants both a
	-- permanent stat bonus (Economy.ForgePathEffect reads ClaimedSteps the same way the old
	-- tree read UnlockedNodes) and a one-time reward chest together.
	local function ensureForgePath(profile)
		profile.ForgePath = ForgePathClaim.Ensure(profile.ForgePath)
	end

	local function awardForgePathXP(profile, amount: number)
		ensureForgePath(profile)
		local value = math.max(0, math.floor(amount))
		value = math.floor(value * (1 + Economy.DomainTreeBonus(profile, "ForgePathXP")))
		local config = GameConfig.Economy.ForgePathXP
		if type(config) == "table" then
			local day = currentDay()
			if profile.ForgePath.XPDay ~= day then
				profile.ForgePath.XPDay = day
				profile.ForgePath.XPEarnedToday = 0
			end
			local earned = math.max(0, math.floor(tonumber(profile.ForgePath.XPEarnedToday) or 0))
			local softCap = math.max(1, math.floor(tonumber(config.DailySoftCap) or 12_000))
			if earned >= softCap then
				value = math.max(0, math.floor(value * (tonumber(config.SoftCapScale) or 0.35)))
			end
			profile.ForgePath.XPEarnedToday = earned + value
		end
		profile.ForgePath.XP += value
	end
	ProgressionService.AwardForgePathXP = awardForgePathXP

	function ProgressionService.TotalForgePathXP(profile): number
		ensureForgePath(profile)
		return profile.ForgePath.XP
	end

	function ProgressionService.ClaimForgePathStep(profile, rawStep: any): (boolean, string)
		ensureForgePath(profile)
		local ok, err, step = ForgePathClaim.TryClaim(profile.ForgePath, rawStep, GameConfig.ForgePath.Steps)
		if not ok or not step then
			return false, err or "Invalid forge path step."
		end
		return true, ProgressionService.ApplyReward(profile, step.Reward, Economy.SteadyProduction(profile))
	end

	function ProgressionService.ForgePathState(profile)
		ensureForgePath(profile)
		local claimed = {}
		for key in pairs(profile.ForgePath.ClaimedSteps) do
			table.insert(claimed, tonumber(key))
		end
		return {
			ClaimedSteps = claimed,
			XP = profile.ForgePath.XP,
			StepCount = GameConfig.ForgePath.StepCount or #GameConfig.ForgePath.Steps,
			ChapterMarks = GameConfig.ForgePath.ChapterMarks,
			XPEarnedToday = math.max(0, math.floor(tonumber(profile.ForgePath.XPEarnedToday) or 0)),
		}
	end

	function ProgressionService.CommandState(profile)
		local command = ensureCommand(profile)
		local level = commanderLevel(command.XP)
		local claimable = {}
		for rewardLevel = 1, level do
			if not command.CommanderClaims[tostring(rewardLevel)] then
				table.insert(claimable, rewardLevel)
			end
		end
		return {
			XP = command.XP,
			Level = level,
			Rank = commanderRank(level),
			LevelFloorXP = commanderFloorXP(level),
			NextLevelXP = commanderNextXP(level),
			Signals = command.Signals,
			StreakShields = command.StreakShields,
			ExpeditionsCompleted = command.ExpeditionsCompleted,
			ActiveExpedition = command.ActiveExpedition,
			Artifacts = command.Artifacts,
			EquippedArtifact = command.EquippedArtifact,
			Crew = command.Crew,
			CommanderClaims = command.CommanderClaims,
			ClaimableCommanderLevels = claimable,
			SeasonXP = command.SeasonXP,
			SeasonClaims = command.SeasonClaims,
			Weekly = ProgressionService.WeeklyState(profile),
			Shop = ProgressionService.SignalShopState(profile),
			Titles = ProgressionService.TitleStates(profile),
			MachineMastery = command.MachineMastery,
		}
	end

	function ProgressionService.WheelState(profile)
		local wheel = ensureWheel(profile)
		return WheelMath.Snapshot(
			os.time(),
			wheel,
			GameConfig.Wheel.CooldownSeconds,
			GameConfig.Wheel.PityAfter
		)
	end

	function ProgressionService.SpinWheel(profile, random: Random): (boolean, string, number?, string?, boolean?)
		local now = os.time()
		local wheel = ensureWheel(profile)
		local freeSpins = wheel.FreeSpins
		local onCooldown = now < wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds
		if freeSpins <= 0 and onCooldown then
			return false, "The fortune reactor is still recharging."
		end

		local pityAfter = math.max(1, math.floor(tonumber(GameConfig.Wheel.PityAfter) or 8))
		local pityKey = string.upper(tostring(GameConfig.Wheel.PityRarity or "RARE"))
		local floorRank = WheelMath.RARITY_RANK[pityKey] or 3
		local forcePity = wheel.PityMisses + 1 >= pityAfter

		local pool, totalWeight = WheelMath.BuildPool(GameConfig.Wheel.Rewards, forcePity, floorRank)
		if totalWeight <= 0 then
			pool, totalWeight = WheelMath.FullPool(GameConfig.Wheel.Rewards)
		end

		local roll = random:NextNumber(0, totalWeight)
		local selectedEntry = WheelMath.PickEntry(pool, totalWeight, roll)
		if selectedEntry == nil then
			return false, "The fortune reactor has no prizes configured."
		end

		local selectedIndex = selectedEntry.Index
		local selected = selectedEntry.Prize
		local selectedRank = WheelMath.RarityRank(selected.Rarity)
		local pityHit = forcePity
		wheel.PityMisses = WheelMath.NextPityMisses(wheel.PityMisses, selectedRank, floorRank)

		if freeSpins > 0 then
			wheel.FreeSpins = freeSpins - 1
		else
			wheel.LastSpinAt = now
		end
		wheel.Spins += 1
		local rewardText = ProgressionService.ApplyReward(profile, selected.Reward, Economy.Production(profile))
		local label = selected.Name .. ": " .. rewardText
		if pityHit then
			label = label .. " (guaranteed)"
		end
		return true, label, selectedIndex, selected.Id, pityHit
	end

	function ProgressionService.EnsureTimedRewards(profile): boolean
		local day = currentDay()
		local timed = ensureTimedRewardsBag(profile)
		if timed.Day == day then
			return false
		end
		profile.TimedRewards = {
			Day = day,
			PlaySeconds = 0,
			Claimed = {},
		}
		return true
	end

	function ProgressionService.TimedRewardState(profile)
		local timed = ensureTimedRewardsBag(profile)
		local dayMatches = timed.Day == currentDay()
		local playSeconds = dayMatches and timed.PlaySeconds or 0
		local claimed = dayMatches and timed.Claimed or {}
		local rewards = {}
		for index, timedReward in GameConfig.TimedRewards do
			table.insert(rewards, {
				Index = index,
				Seconds = timedReward.Minutes * 60,
				Reward = copyReward(timedReward.Reward),
				Claimed = claimed[tostring(index)] == true,
			})
		end
		return {
			PlaySeconds = playSeconds,
			Rewards = rewards,
		}
	end

	function ProgressionService.ClaimTimedReward(profile, rawIndex: any): (boolean, string)
		ProgressionService.EnsureTimedRewards(profile)
		if type(rawIndex) ~= "number" then
			return false, "That playtime gift does not exist."
		end
		local index = math.floor(rawIndex)
		local timedReward = GameConfig.TimedRewards[index]
		if not timedReward then
			return false, "That playtime gift does not exist."
		end
		local timed = ensureTimedRewardsBag(profile)
		local key = tostring(index)
		if timed.Claimed[key] then
			return false, "That playtime gift was already claimed today."
		end
		if timed.PlaySeconds < timedReward.Minutes * 60 then
			return false, "Keep playing to unlock that gift."
		end
		timed.Claimed[key] = true
		return true, ProgressionService.ApplyReward(profile, timedReward.Reward, Economy.Production(profile))
	end

	return table.freeze(ProgressionService)
end
