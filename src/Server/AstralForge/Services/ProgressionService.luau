--!strict

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
	local Format = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Format"))
	local ForgePathClaim = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ForgePathClaim"))

	local ProgressionService = {}

	local function currentDay(): number
		return math.floor(os.time() / 86400)
	end

	local function currentWeek(): number
		return math.floor(os.time() / (86400 * 7))
	end

	local function copyReward(reward)
		return table.clone(reward)
	end

	local function commanderLevel(xp: number): number
		return math.clamp(
			math.floor(math.sqrt(math.max(0, xp) / 100)) + 1,
			1,
			GameConfig.Operations.MaxCommanderLevel
		)
	end

	local function commanderFloorXP(level: number): number
		return 100 * math.max(0, level - 1) ^ 2
	end

	local function commanderNextXP(level: number): number
		if level >= GameConfig.Operations.MaxCommanderLevel then
			return commanderFloorXP(level)
		end
		return 100 * level ^ 2
	end

	local function commanderRank(level: number): string
		if level >= 60 then
			return "TIMELESS COMMANDER"
		elseif level >= 50 then
			return "VOID MARSHAL"
		elseif level >= 40 then
			return "FLEET DIRECTOR"
		elseif level >= 30 then
			return "SECTOR ADMIRAL"
		elseif level >= 20 then
			return "EXPEDITION CAPTAIN"
		elseif level >= 10 then
			return "STAR OFFICER"
		elseif level >= 5 then
			return "FLIGHT SPECIALIST"
		end
		return "FORGE CADET"
	end

	local function ensureCommand(profile)
		if type(profile.Command) ~= "table" then
			profile.Command = { XP = 0, SeasonXP = 0, Signals = 0, StreakShields = 0 }
		end
		return profile.Command
	end

	-- Partial Profiles (Studio fixtures / mid-migrate) may omit Stats — weekly /
	-- expedition / season / signal-shop claim paths must not throw before rewards apply.
	local function ensureStats(profile)
		if type(profile.Stats) ~= "table" then
			profile.Stats = {}
		end
		return profile.Stats
	end

	local function bumpStat(profile, key: string, amount: number?)
		local stats = ensureStats(profile)
		local delta = math.max(0, math.floor(tonumber(amount) or 1))
		stats[key] = math.max(0, math.floor(tonumber(stats[key]) or 0)) + delta
		return stats[key]
	end

	-- WeeklyRelics (and similar) grant Keys tables — ApplyReward must not throw when
	-- Items / Items.Keys are absent on Studio fixtures before the Claimed flag sticks.
	local function ensureItemKeys(profile)
		if type(profile.Items) ~= "table" then
			profile.Items = { Keys = {} }
		elseif type(profile.Items.Keys) ~= "table" then
			profile.Items.Keys = {}
		end
		return profile.Items.Keys
	end

	local function ensureDaily(profile)
		if type(profile.Daily) ~= "table" then
			profile.Daily = { LastClaimDay = -1, Streak = 0 }
		end
		profile.Daily.LastClaimDay = math.floor(tonumber(profile.Daily.LastClaimDay) or -1)
		profile.Daily.Streak = math.max(0, math.floor(tonumber(profile.Daily.Streak) or 0))
		return profile.Daily
	end

	local function awardCommandXP(profile, amount: number)
		local value = math.max(0, math.floor(amount))
		value = math.floor(value * (1 + Economy.DomainTreeBonus(profile, "CommandXP")))
		local command = ensureCommand(profile)
		command.XP = (tonumber(command.XP) or 0) + value
		command.SeasonXP = (tonumber(command.SeasonXP) or 0) + value
	end

	ProgressionService.AwardCommandXP = awardCommandXP

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
			if type(profile.BoostInventory) ~= "table" then
				profile.BoostInventory = {}
			end
			profile.BoostInventory[reward.Boost] = (tonumber(profile.BoostInventory[reward.Boost]) or 0) + 1
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
			profile.Domain = profile.Domain or { Rank = 0, Essence = 0, Nodes = {}, SkillPoints = 0 }
			profile.Domain.Essence = math.min(1_000_000, math.max(0, math.floor(tonumber(profile.Domain.Essence) or 0)) + math.floor(reward.Essence))
			table.insert(parts, Format.Number(reward.Essence) .. " domain essence")
		end
		if reward.DomainEssence and reward.DomainEssence > 0 then
			profile.Domain = profile.Domain or { Rank = 0, Essence = 0, Nodes = {}, SkillPoints = 0 }
			profile.Domain.Essence = math.min(1_000_000, math.max(0, math.floor(tonumber(profile.Domain.Essence) or 0)) + math.floor(reward.DomainEssence))
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
			if type(profile.Wheel) ~= "table" then
				profile.Wheel = { FreeSpins = 0 }
			end
			profile.Wheel.FreeSpins = math.max(0, math.floor(tonumber(profile.Wheel.FreeSpins) or 0)) + math.floor(reward.FreeSpins)
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
		if profile.Quests.Day == day and #profile.Quests.Items > 0 then
			return false
		end

		local production = Economy.Max(4, Economy.Production(profile))
		local scale = 1 + profile.Rebirths * 0.15
		local earnTarget = math.floor(math.max(2_000, Economy.AsNumber(Economy.Mul(production, 8 * 60)) * scale))
		local tapTarget = math.floor((40 + profile.Rebirths * 3) * scale)
		local upgradeTarget = math.floor(3 + math.min(7, profile.Rebirths / 2))
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
		for _, quest in profile.Quests.Items do
			if
				quest.Kind == kind
				or (quest.Kind == "BuyAny" and (kind == "BuyMachine" or kind == "BuyResearch"))
			then
				quest.Progress = math.min(quest.Target, quest.Progress + amount)
			end
		end
	end

	function ProgressionService.ClaimQuest(profile, questId: string): (boolean, string)
		for _, quest in profile.Quests.Items do
			if quest.Id == questId then
				if quest.Claimed then
					return false, "That mission reward was already claimed."
				end
				if quest.Progress < quest.Target then
					return false, "That mission is not complete yet."
				end
				quest.Claimed = true
				return true, ProgressionService.ApplyReward(profile, quest.Reward)
			end
		end
		return false, "Mission not found."
	end

	function ProgressionService.AchievementProgress(profile, kind: string): number
		if kind == "LifetimeCash" then
			return Economy.AsNumber(profile.LifetimeCash)
		elseif kind == "MachineLevels" then
			return Economy.TotalMachineLevels(profile)
		elseif kind == "ResearchLevels" then
			return Economy.TotalResearchLevels(profile)
		elseif kind == "Rebirths" then
			-- Match ProgressionGate: Domain expand zeroes current Rebirths but keeps
			-- TotalRebirthsSpent — achievements must not regress after expansion.
			local current = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
			local spent = 0
			if type(profile.Domain) == "table" then
				spent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0))
			end
			return current + spent
		elseif kind == "Zone" then
			return math.max(0, math.floor(tonumber(profile.Zone) or 0))
		elseif kind == "PlayTime" then
			local stats = profile.Stats
			return math.max(0, math.floor(tonumber(stats and stats.PlayTime) or 0))
		elseif kind == "AnomalyPulses" then
			local stats = profile.Stats
			return math.max(0, math.floor(tonumber(stats and stats.AnomalyPulses) or 0))
		elseif kind == "AnomalyStabilizations" then
			-- Prefer Anomaly bag (source of truth + Admin GrantAnomalyStabilizations);
			-- Stats can lag when admin grants only bump Anomaly.Stabilizations.
			local anomaly = profile.Anomaly
			local fromAnomaly = tonumber(anomaly and anomaly.Stabilizations)
			if fromAnomaly ~= nil then
				return math.max(0, math.floor(fromAnomaly))
			end
			local stats = profile.Stats
			return math.max(0, math.floor(tonumber(stats and stats.AnomalyStabilizations) or 0))
		elseif kind == "AnomalyProtocols" then
			local stats = profile.Stats
			return math.max(0, math.floor(tonumber(stats and stats.AnomalyProtocols) or 0))
		elseif kind == "ForgePathSteps" then
			local claimed = 0
			local forgePath = profile.ForgePath
			if type(forgePath) == "table" and type(forgePath.ClaimedSteps) == "table" then
				for _ in forgePath.ClaimedSteps do
					claimed += 1
				end
			end
			return claimed
		elseif kind == "DailyStreak" then
			return math.max(0, math.floor(tonumber(profile.Daily and profile.Daily.Streak) or 0))
		elseif kind == "WheelSpins" then
			return math.max(0, math.floor(tonumber(profile.Wheel and profile.Wheel.Spins) or 0))
		elseif kind == "LabOrders" then
			return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.OrdersCompleted) or 0))
		elseif kind == "Expeditions" then
			-- Prefer Command bag (ClaimExpedition source of truth); Stats can lag on partial fixtures.
			local command = profile.Command
			local fromCommand = tonumber(command and command.ExpeditionsCompleted)
			if fromCommand ~= nil then
				return math.max(0, math.floor(fromCommand))
			end
			return math.max(0, math.floor(tonumber(profile.Stats and profile.Stats.Expeditions) or 0))
		elseif kind == "DomainRank" or kind == "Domain" then
			return math.max(0, math.floor(tonumber(profile.Domain and profile.Domain.Rank) or 0))
		elseif kind == "StoryClaims" then
			local count = 0
			local claimed = profile.Story and profile.Story.Claimed
			if type(claimed) == "table" then
				for _, value in claimed do
					if value == true then
						count += 1
					end
				end
			end
			return count
		end
		return 0
	end

	function ProgressionService.AchievementStates(profile)
		local states = {}
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
				Claimed = profile.Achievements[achievement.Id] == true,
			})
		end
		return states
	end

	function ProgressionService.ClaimAchievement(profile, achievementId: string): (boolean, string)
		for _, achievement in GameConfig.Achievements do
			if achievement.Id == achievementId then
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

	local function findOperation(list, id: string)
		for _, item in list do
			if item.Id == id then
				return item
			end
		end
		return nil
	end

	local function currentWeeklyValue(profile, kind: string): number
		local stats = profile.Stats
		if kind == "Upgrades" then
			return math.max(0, math.floor(tonumber(stats and stats.MachinesBought) or 0))
				+ math.max(0, math.floor(tonumber(stats and stats.ResearchBought) or 0))
		elseif kind == "Expeditions" then
			local command = profile.Command
			return math.max(0, math.floor(tonumber(command and command.ExpeditionsCompleted) or 0))
		end
		if type(stats) ~= "table" then
			return 0
		end
		return math.max(0, math.floor(tonumber(stats[kind]) or 0))
	end

	function ProgressionService.EnsureWeekly(profile): boolean
		local week = currentWeek()
		if profile.Command.Weekly.Week == week then

			local changed = false
			for _, directive in GameConfig.Operations.WeeklyDirectives do
				if profile.Command.Weekly.Baseline[directive.Kind] == nil then
					profile.Command.Weekly.Baseline[directive.Kind] = currentWeeklyValue(profile, directive.Kind)
					changed = true
				end
			end
			return changed
		end
		local baseline = {}
		for _, directive in GameConfig.Operations.WeeklyDirectives do
			baseline[directive.Kind] = currentWeeklyValue(profile, directive.Kind)
		end
		profile.Command.Weekly = { Week = week, Baseline = baseline, Claimed = {} }
		return true
	end

	function ProgressionService.WeeklyState(profile)

		local current = profile.Command.Weekly
		local weekMatches = current.Week == currentWeek()
		local baselines = weekMatches and current.Baseline or {}
		local claimed = weekMatches and current.Claimed or {}
		local level = commanderLevel(profile.Command.XP)
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
		ProgressionService.EnsureWeekly(profile)
		for _, item in ProgressionService.WeeklyState(profile) do
			if item.Id == directiveId then
				if item.Claimed then
					return false, "That weekly directive was already claimed."
				end
				if item.Progress < item.Target then
					return false, "That weekly directive is not complete."
				end
				profile.Command.Weekly.Claimed[directiveId] = true
				bumpStat(profile, "WeeklyClaimed", 1)
				return true, ProgressionService.ApplyReward(profile, item.Reward, Economy.Production(profile))
			end
		end
		return false, "Weekly directive not found."
	end

	local function titleUnlocked(profile, title): boolean
		local level = commanderLevel(profile.Command.XP)
		if title.Kind == "Level" then
			return level >= title.Target
		elseif title.Kind == "Expeditions" then
			return profile.Command.ExpeditionsCompleted >= title.Target
		elseif title.Kind == "Artifacts" then
			local count = 0
			for _ in profile.Command.Artifacts do
				count += 1
			end
			return count >= title.Target
		elseif title.Kind == "LifetimeCash" then
			return Economy.Gte(profile.LifetimeCash, title.Target)
		elseif title.Kind == "Rebirths" then
			return (tonumber(profile.Rebirths) or 0) >= title.Target
		end
		return false
	end

	function ProgressionService.TitleStates(profile)
		if GameConfig.Operations.TitlesEnabled == false then
			return {}
		end
		local titles = {}
		for _, title in GameConfig.Operations.Titles do
			table.insert(titles, {
				Id = title.Id,
				Name = title.Name,
				Description = title.Description,
				Unlocked = titleUnlocked(profile, title),
				Equipped = profile.Command.EquippedTitle == title.Id,
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
		profile.Command.EquippedTitle = titleId
		return true, title.Name .. " equipped."
	end

	function ProgressionService.EnsureCommandRotations(profile): boolean
		local changed = ProgressionService.EnsureWeekly(profile)
		local day = currentDay()
		if profile.Command.Shop.Day ~= day then
			profile.Command.Shop = { Day = day, Purchased = {} }
			changed = true
		end
		if profile.Command.SeasonId ~= GameConfig.Operations.SeasonId then
			profile.Command.SeasonId = GameConfig.Operations.SeasonId
			profile.Command.SeasonXP = 0
			profile.Command.SeasonClaims = {}
			changed = true
		end
		return changed
	end

	function ProgressionService.SignalShopState(profile)
		local offers = {}
		local source = GameConfig.Operations.ShopOffers
		local day = currentDay()
		local purchased = if profile.Command.Shop.Day == day then profile.Command.Shop.Purchased else {}
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

	local function commanderReward(level: number)
		if level % 10 == 0 then
			return { Cores = math.max(1, level / 10), Stardust = 10 + level, Signals = 10 + level }
		elseif level % 5 == 0 then
			return { Stardust = 8 + level, Signals = 8 + math.floor(level / 2), StreakShield = 1 }
		end
		return { CashMinutes = 5 + level, Signals = 3 + math.floor(level / 3) }
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
		local level = commanderLevel(profile.Command.XP)
		local claimable = {}
		for rewardLevel = 1, level do
			if not profile.Command.CommanderClaims[tostring(rewardLevel)] then
				table.insert(claimable, rewardLevel)
			end
		end
		return {
			XP = profile.Command.XP,
			Level = level,
			Rank = commanderRank(level),
			LevelFloorXP = commanderFloorXP(level),
			NextLevelXP = commanderNextXP(level),
			Signals = profile.Command.Signals,
			StreakShields = profile.Command.StreakShields,
			ExpeditionsCompleted = profile.Command.ExpeditionsCompleted,
			ActiveExpedition = profile.Command.ActiveExpedition,
			Artifacts = profile.Command.Artifacts,
			EquippedArtifact = profile.Command.EquippedArtifact,
			Crew = profile.Command.Crew,
			CommanderClaims = profile.Command.CommanderClaims,
			ClaimableCommanderLevels = claimable,
			SeasonXP = profile.Command.SeasonXP,
			SeasonClaims = profile.Command.SeasonClaims,
			Weekly = ProgressionService.WeeklyState(profile),
			Shop = ProgressionService.SignalShopState(profile),
			Titles = ProgressionService.TitleStates(profile),
			MachineMastery = profile.Command.MachineMastery,
		}
	end

	function ProgressionService.WheelState(profile)
		local now = os.time()
		local readyAt = profile.Wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds
		local freeSpins = math.max(0, math.floor(tonumber(profile.Wheel.FreeSpins) or 0))
		local pityMisses = math.floor(tonumber(profile.Wheel.PityMisses) or 0)
		local pityAfter = math.max(1, math.floor(tonumber(GameConfig.Wheel.PityAfter) or 8))
		local cooldownReady = now >= readyAt
		return {
			CanSpin = freeSpins > 0 or cooldownReady,
			ReadyAt = if freeSpins > 0 then now else math.max(now, readyAt),
			Spins = profile.Wheel.Spins,
			FreeSpins = freeSpins,
			PityMisses = pityMisses,
			PityAfter = pityAfter,
			PityArmed = pityMisses + 1 >= pityAfter,
		}
	end

	local WHEEL_RARITY_RANK = {
		COMMON = 1,
		UNCOMMON = 2,
		RARE = 3,
		EPIC = 4,
		LEGENDARY = 5,
		MYTHIC = 6,
	}

	function ProgressionService.SpinWheel(profile, random: Random): (boolean, string, number?, string?, boolean?)
		local now = os.time()
		local freeSpins = math.max(0, math.floor(tonumber(profile.Wheel.FreeSpins) or 0))
		local onCooldown = now < profile.Wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds
		if freeSpins <= 0 and onCooldown then
			return false, "The fortune reactor is still recharging."
		end

		profile.Wheel.PityMisses = math.floor(tonumber(profile.Wheel.PityMisses) or 0)
		local pityAfter = math.max(1, math.floor(tonumber(GameConfig.Wheel.PityAfter) or 8))
		local pityRarity = string.upper(tostring(GameConfig.Wheel.PityRarity or "RARE"))
		local floorRank = WHEEL_RARITY_RANK[pityRarity] or 3
		local forcePity = profile.Wheel.PityMisses + 1 >= pityAfter

		local pool = {}
		local totalWeight = 0
		for index, prize in GameConfig.Wheel.Rewards do
			local rank = WHEEL_RARITY_RANK[string.upper(prize.Rarity)] or 1
			if not forcePity or rank >= floorRank then
				table.insert(pool, { Index = index, Prize = prize, Weight = prize.Weight })
				totalWeight += prize.Weight
			end
		end
		if totalWeight <= 0 then
			pool = {}
			for index, prize in GameConfig.Wheel.Rewards do
				table.insert(pool, { Index = index, Prize = prize, Weight = prize.Weight })
				totalWeight += prize.Weight
			end
		end

		local roll = random:NextNumber(0, totalWeight)
		local selectedEntry = pool[#pool]
		local cursor = 0
		for _, entry in pool do
			cursor += entry.Weight
			if roll <= cursor then
				selectedEntry = entry
				break
			end
		end

		local selectedIndex = selectedEntry.Index
		local selected = selectedEntry.Prize
		local selectedRank = WHEEL_RARITY_RANK[string.upper(selected.Rarity)] or 1
		local pityHit = forcePity
		if selectedRank >= floorRank then
			profile.Wheel.PityMisses = 0
		else
			profile.Wheel.PityMisses += 1
		end

		if freeSpins > 0 then
			profile.Wheel.FreeSpins = freeSpins - 1
		else
			profile.Wheel.LastSpinAt = now
		end
		profile.Wheel.Spins += 1
		local rewardText = ProgressionService.ApplyReward(profile, selected.Reward, Economy.Production(profile))
		local label = selected.Name .. ": " .. rewardText
		if pityHit then
			label = label .. " (guaranteed)"
		end
		return true, label, selectedIndex, selected.Id, pityHit
	end

	function ProgressionService.EnsureTimedRewards(profile): boolean
		local day = currentDay()
		if profile.TimedRewards.Day == day then
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
		local dayMatches = profile.TimedRewards.Day == currentDay()
		local playSeconds = dayMatches and profile.TimedRewards.PlaySeconds or 0
		local claimed = dayMatches and profile.TimedRewards.Claimed or {}
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
		local key = tostring(index)
		if profile.TimedRewards.Claimed[key] then
			return false, "That playtime gift was already claimed today."
		end
		if profile.TimedRewards.PlaySeconds < timedReward.Minutes * 60 then
			return false, "Keep playing to unlock that gift."
		end
		profile.TimedRewards.Claimed[key] = true
		return true, ProgressionService.ApplyReward(profile, timedReward.Reward, Economy.Production(profile))
	end

	return table.freeze(ProgressionService)
end
