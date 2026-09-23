--!strict

return function(loadService: (string) -> any)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
	local AnomalyPulseScore = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AnomalyPulseScore"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local ProgressionService = loadService("ProgressionService")

	local AnomalyService = {}

	-- Pulse timing must use Workspace:GetServerTimeNow (sub-second, Roblox-synced), not
	-- os.time() (1s resolution). A 1.6s sweep with a ~0.35s sweet zone cannot be judged
	-- fairly from whole-second stamps, and the client needle already predicts from
	-- GetServerTimeNow — mixing clocks made "perfect" taps miss on the server.
	local function pulseNow(): number
		return Workspace:GetServerTimeNow()
	end

	-- Partial Profiles (Studio fixtures / mid-migrate) may omit Stats — pulse /
	-- stabilize / protocol / directive ledgers must not throw before the Anomaly bag updates.
	local function bumpAnomalyStat(profile, key: string)
		if type(profile.Stats) ~= "table" then
			profile.Stats = {}
		end
		profile.Stats[key] = math.max(0, math.floor(tonumber(profile.Stats[key]) or 0)) + 1
	end

	-- Overdrive: a server-wide (not per-player) shared meter. Deliberately module-level state
	-- rather than anything persisted -- Luau modules are singletons per server, so this is
	-- naturally scoped to "this server instance," resets cleanly on restart, and needs no
	-- datastore surface or save-conflict handling for what's meant to be a bonus layer on top
	-- of core per-player progression, not part of it.
	local overdrive: { Charge: number, BonusEndsAt: number } = {
		Charge = 0,
		BonusEndsAt = 0,
	}

	local function overdriveActive(now: number): boolean
		return overdrive.BonusEndsAt > now
	end

	-- Adds a contribution to the shared meter and returns true exactly once, the instant the
	-- meter crosses its target, so the caller can fire a one-time "Overdrive!" broadcast
	-- instead of every player's next state poll silently noticing it's already full.
	local function contributeOverdrive(amount: number, now: number): boolean
		if overdriveActive(now) then
			return false
		end
		local target = GameConfig.Anomalies.OverdriveTarget
		local before = overdrive.Charge
		overdrive.Charge = math.min(target, overdrive.Charge + math.max(0, amount))
		if before < target and overdrive.Charge >= target then
			overdrive.Charge = 0
			overdrive.BonusEndsAt = now + GameConfig.Anomalies.OverdriveBonusSeconds
			return true
		end
		return false
	end

	function AnomalyService.OverdriveState(now: number?)
		-- Same GetServerTimeNow clock as pulse / client useWallClock countdowns.
		local timestamp = now or pulseNow()
		return {
			Charge = overdrive.Charge,
			Target = GameConfig.Anomalies.OverdriveTarget,
			Active = overdriveActive(timestamp),
			BonusEndsAt = overdrive.BonusEndsAt,
			Multiplier = GameConfig.Anomalies.OverdriveBonusMultiplier,
		}
	end

	function AnomalyService.OverdriveMultiplier(now: number?): number
		if overdriveActive(now or pulseNow()) then
			return GameConfig.Anomalies.OverdriveBonusMultiplier
		end
		return 1
	end

	local function currentCycle(now: number?): (number, any, number)
		local timestamp = now or pulseNow()
		local cycle = math.floor(timestamp / GameConfig.Anomalies.CycleSeconds)
		local index = cycle % #GameConfig.Anomalies.Types + 1
		return cycle, GameConfig.Anomalies.Types[index], (cycle + 1) * GameConfig.Anomalies.CycleSeconds
	end

	local function findProtocol(protocolId: string)
		for _, protocol in GameConfig.Anomalies.Protocols do
			if protocol.Id == protocolId then
				return protocol
			end
		end
		return nil
	end

	local function activeDirectives(cycle: number)
		local definitions = GameConfig.Anomalies.Directives
		local selected = {}
		local count = #definitions
		local start = cycle % count
		for slot = 1, GameConfig.Anomalies.DirectiveSlots do
			local index = (start + (slot - 1) * 3) % count + 1
			local definition = definitions[index]
			local difficulty = ((cycle * 7 + slot * 13) % 5) / 4
			local target = math.floor(
				definition.TargetMin + (definition.TargetMax - definition.TargetMin) * difficulty + 0.5
			)
			selected[slot] = {
				Definition = definition,
				Target = math.max(1, target),
			}
		end
		return selected
	end

	local function protocolEffect(profile, effectKind: string): number
		local total = 0
		for _, protocol in GameConfig.Anomalies.Protocols do
			if protocol.EffectKind == effectKind then
				total += (profile.Anomaly.Protocols[protocol.Id] or 0) * protocol.EffectPerLevel
			end
		end
		return total
	end

	local function rewardMultiplier(profile, anomaly): number
		local multiplier = anomaly.RewardMultiplier * (1 + protocolEffect(profile, "Reward"))
		local channel = GameConfig.Anomalies.Channels[profile.Anomaly.Channel]
		if channel and channel.EffectKind == "Reward" then
			multiplier *= 1 + channel.EffectAmount
		end
		return multiplier
	end

	local function coreTierMaximumBonus(profile): number
		local tier = profile.Anomaly.CoreTier or 0
		local bonus = 0
		for _, tierConfig in GameConfig.Anomalies.CoreTiers do
			if tierConfig.Tier <= tier then
				bonus = tierConfig.MaximumTargetBonus
			end
		end
		return bonus
	end

	function AnomalyService.Target(profile): number
		return math.min(
			GameConfig.Anomalies.MaximumTarget + coreTierMaximumBonus(profile),
			GameConfig.Anomalies.BaseTarget
				+ profile.Anomaly.Stabilizations * GameConfig.Anomalies.TargetPerStabilization
		)
	end

	function AnomalyService.Ensure(profile): boolean
		local cycle = currentCycle()
		local changed = false
		if profile.Anomaly.Cycle ~= cycle then
			profile.Anomaly.Cycle = cycle
			profile.Anomaly.LastActionAt = 0
			changed = true
		end
		if profile.Anomaly.DirectiveCycle ~= cycle then
			profile.Anomaly.DirectiveCycle = cycle
			profile.Anomaly.DirectiveProgress = {}
			profile.Anomaly.DirectiveClaims = {}
			changed = true
		end
		return changed
	end

	function AnomalyService.Signal(profile, kind: string, amount: number?)
		AnomalyService.Ensure(profile)
		local cycle = currentCycle()
		for _, directive in activeDirectives(cycle) do
			local definition = directive.Definition
			if definition.Kind == kind then
				local previous = profile.Anomaly.DirectiveProgress[definition.Id] or 0
				if kind == "Combo" then
					profile.Anomaly.DirectiveProgress[definition.Id] =
						math.min(directive.Target, math.max(previous, amount or 0))
				else
					profile.Anomaly.DirectiveProgress[definition.Id] =
						math.min(directive.Target, previous + math.max(0, amount or 1))
				end
			end
		end
	end

	-- Chain (a bonus for pulsing frequently) used to stack on top of Combo (a bonus for pulsing
	-- accurately) here -- both rewarded the same repeated-Pulse action, so a player mashing
	-- Pulse accurately watched two numbers climb for the same clicks with no clear read on which
	-- one mattered. Combo already covers "keep pulsing well"; Progress now applies only the
	-- protocol/anomaly-type multipliers, and the caller (Pulse) folds its own comboBonus in.
	function AnomalyService.Progress(profile, baseAmount: number): (number, boolean)
		AnomalyService.Ensure(profile)
		local _, anomaly = currentCycle()
		profile.Anomaly.LastActionAt = pulseNow()

		local target = AnomalyService.Target(profile)
		local wasReady = profile.Anomaly.Charge >= target
		local capture = 1 + protocolEffect(profile, "ChargeGain")
		local amount = math.max(0, baseAmount) * capture * anomaly.ChargeMultiplier
		profile.Anomaly.Charge = math.min(target * 1.5, profile.Anomaly.Charge + amount)
		AnomalyService.Signal(profile, "Action", 1)
		return amount, not wasReady and profile.Anomaly.Charge >= target
	end

	-- Server-authoritative timing-window accuracy via AnomalyPulseScore. PulseWindowStartedAt
	-- anchors a sweep of length PulseWindowSeconds; the "sweet zone" is the tail fraction of
	-- that sweep, matching what the client's needle visually approaches. Computed entirely from
	-- the server's own clock and the server's own record of when the current window began -- the
	-- client never reports a timing/accuracy value that gets trusted, so there is no new spoofing
	-- surface. A pulse always starts the next window regardless of accuracy, so players are never
	-- stuck unable to pulse while waiting out a window they didn't want.
	function AnomalyService.Pulse(profile, random: Random): (boolean, string, any)
		local now = pulseNow()
		local accurate = AnomalyPulseScore.IsAccurate(
			now,
			profile.Anomaly.PulseWindowStartedAt,
			GameConfig.Anomalies.PulseWindowSeconds,
			GameConfig.Anomalies.PulseWindowSweetZone
		)
		profile.Anomaly.PulseWindowStartedAt = now

		profile.Anomaly.Combo = AnomalyPulseScore.NextCombo(
			profile.Anomaly.Combo,
			accurate,
			GameConfig.Anomalies.PulseComboMax
		)
		if accurate then
			profile.Anomaly.BestCombo = AnomalyPulseScore.NextBestCombo(profile.Anomaly.BestCombo, profile.Anomaly.Combo)
		end
		local comboBonus = AnomalyPulseScore.ComboBonus(
			profile.Anomaly.Combo,
			GameConfig.Anomalies.PulseComboBonusPerStack
		)
		local accuracyBonus = AnomalyPulseScore.AccuracyBonus(accurate, GameConfig.Anomalies.PulseAccurateBonus)

		-- Overdrive / Progress share the pulse clock so BonusEndsAt / LastActionAt match
		-- client GetServerTimeNow countdowns (no os.time dual-clock drift).
		local pulsePower = 1 + protocolEffect(profile, "PulsePower")
		local overdriveMultiplier = AnomalyService.OverdriveMultiplier(now)
		local amount, becameReady = AnomalyService.Progress(
			profile,
			random:NextNumber(3.8, 5.4) * pulsePower * comboBonus * accuracyBonus * overdriveMultiplier
		)
		AnomalyService.Signal(profile, "Pulse", 1)
		AnomalyService.Signal(profile, "Combo", profile.Anomaly.Combo)
		bumpAnomalyStat(profile, "AnomalyPulses")
		local overdriveTriggered = contributeOverdrive(GameConfig.Anomalies.OverdrivePulseContribution, now)
		return true,
			accurate
				and string.format("Perfect pulse! Combo x%d, +%.1f charge.", profile.Anomaly.Combo, amount)
				or string.format("Quantum pulse captured %.1f charge.", amount),
			{
				Amount = amount,
				Charge = profile.Anomaly.Charge,
				Ready = profile.Anomaly.Charge >= AnomalyService.Target(profile),
				BecameReady = becameReady,
				Accurate = accurate,
				Combo = profile.Anomaly.Combo,
				PulseWindowStartedAt = profile.Anomaly.PulseWindowStartedAt,
				OverdriveTriggered = overdriveTriggered,
			}
	end

	-- Applies pending Core XP, advancing CoreTier as many times as it now qualifies for (banking
	-- a big XP gain can cross more than one tier at once). Returns the number of tiers gained,
	-- so the caller can surface a "Core Tier up!" moment distinct from a routine stabilization.
	local function applyCoreXP(profile, xp: number): number
		profile.Anomaly.CoreXP = (profile.Anomaly.CoreXP or 0) + xp
		local currentTier = profile.Anomaly.CoreTier or 0
		local gained = 0
		for _, tierConfig in GameConfig.Anomalies.CoreTiers do
			if tierConfig.Tier > currentTier and profile.Anomaly.CoreXP >= tierConfig.RequiredXP then
				currentTier = tierConfig.Tier
				gained += 1
			end
		end
		if gained > 0 then
			profile.Anomaly.CoreTier = currentTier
		end
		return gained
	end

	function AnomalyService.Stabilize(profile): (boolean, string, any?)
		AnomalyService.Ensure(profile)
		local _, anomaly = currentCycle()
		local target = AnomalyService.Target(profile)
		if profile.Anomaly.Charge < target then
			return false, string.format("The anomaly needs %.1f more charge.", target - profile.Anomaly.Charge)
		end

		local now = pulseNow()
		profile.Anomaly.Charge = math.max(0, profile.Anomaly.Charge - target)
		profile.Anomaly.Stabilizations += 1
		profile.Anomaly.Discoveries[anomaly.Id] = (profile.Anomaly.Discoveries[anomaly.Id] or 0) + 1
		bumpAnomalyStat(profile, "AnomalyStabilizations")
		AnomalyService.Signal(profile, "Stabilize", 1)
		local tiersGained = applyCoreXP(profile, GameConfig.Anomalies.CoreXPPerStabilization)
		local overdriveTriggered = contributeOverdrive(GameConfig.Anomalies.OverdriveStabilizeContribution, now)

		local level = profile.Anomaly.Stabilizations
		local yield = rewardMultiplier(profile, anomaly)
		local fragments = math.max(1, math.floor((4 + level * 0.72) * yield))
		local reward = {
			Stardust = math.max(1, math.floor((5 + level * 0.85) * yield)),
			Signals = math.max(1, math.floor((4 + level * 0.55) * yield)),
			CommandXP = math.max(10, math.floor((35 + level * 6) * yield)),
			Cores = level % 5 == 0 and math.max(1, math.floor(level / 5)) or nil,
		}
		profile.Anomaly.Fragments += fragments
		local rewardText = ProgressionService.ApplyReward(profile, reward, Economy.SteadyProduction(profile))
		local message = string.format("%s stabilized: %d fragments, %s.", anomaly.Name, fragments, rewardText)
		if tiersGained > 0 then
			message = string.format("%s Core Tier %d reached!", message, profile.Anomaly.CoreTier)
		end
		return true,
			message,
			{
				AnomalyId = anomaly.Id,
				AnomalyName = anomaly.Name,
				Fragments = fragments,
				Stabilizations = level,
				Reward = reward,
				CoreTier = profile.Anomaly.CoreTier,
				CoreXP = profile.Anomaly.CoreXP,
				TiersGained = tiersGained,
				OverdriveTriggered = overdriveTriggered,
			}
	end

	function AnomalyService.ProtocolCost(protocol, level: number): number
		return math.max(1, math.floor(protocol.BaseCost * protocol.CostScale ^ math.max(0, level) + 0.5))
	end

	function AnomalyService.BuyProtocol(profile, protocolId: string): (boolean, string, any?)
		local protocol = findProtocol(protocolId)
		if not protocol then
			return false, "That reactor upgrade was not found."
		end
		local level = profile.Anomaly.Protocols[protocol.Id] or 0
		if level >= protocol.MaxLevel then
			return false, "That reactor upgrade is at max level."
		end
		local cost = AnomalyService.ProtocolCost(protocol, level)
		if profile.Anomaly.Fragments < cost then
			return false, string.format("Requires %d anomaly fragments.", cost)
		end
		profile.Anomaly.Fragments -= cost
		profile.Anomaly.Protocols[protocol.Id] = level + 1
		bumpAnomalyStat(profile, "AnomalyProtocols")
		return true,
			string.format("%s advanced to level %d.", protocol.Name, level + 1),
			{
				ProtocolId = protocol.Id,
				ProtocolName = protocol.Name,
				Level = level + 1,
			}
	end

	function AnomalyService.ActivateSurge(profile): (boolean, string, any?)
		local now = pulseNow()
		if profile.Anomaly.SurgeEndsAt > now then
			return false, "Quantum Surge is already active."
		end
		local cost = GameConfig.Anomalies.SurgeCost
		if profile.Anomaly.Fragments < cost then
			return false, string.format("Requires %d anomaly fragments.", cost)
		end
		profile.Anomaly.Fragments -= cost
		local duration = GameConfig.Anomalies.SurgeBaseSeconds + protocolEffect(profile, "SurgeDuration")
		profile.Anomaly.SurgeEndsAt = now + duration
		return true,
			string.format("Surge on for %d seconds.", duration),
			{
				EndsAt = profile.Anomaly.SurgeEndsAt,
				Duration = duration,
			}
	end

	-- Overdrive Core: replaces the old single-Channel selection with a loadout of up to
	-- LoadoutSlots channels active at once, each contributing its own EffectAmount (summed in
	-- Economy.AnomalyEffect). Rejects unknown channel IDs and duplicate entries rather than
	-- silently deduping/dropping them, so a malformed payload fails cleanly instead of quietly
	-- saving a loadout the player didn't actually pick.
	function AnomalyService.SetLoadout(profile, rawLoadout: any): (boolean, string, any?)
		if type(rawLoadout) ~= "table" then
			return false, "Invalid reactor loadout."
		end
		local slots = GameConfig.Anomalies.LoadoutSlots
		if #rawLoadout > slots then
			return false, string.format("You can only slot %d channels at once.", slots)
		end
		local seen = {}
		local resolved = {}
		for _, channelId in rawLoadout do
			if type(channelId) ~= "string" then
				return false, "Invalid reactor loadout."
			end
			local channel = GameConfig.Anomalies.Channels[channelId]
			if not channel then
				return false, "That channel doesn't exist."
			end
			if seen[channelId] then
				return false, "Each channel can only be slotted once."
			end
			seen[channelId] = true
			table.insert(resolved, channelId)
		end
		profile.Anomaly.Loadout = resolved
		profile.Anomaly.Channel = resolved[1] or "Flux"
		local label = #resolved == 0 and "cleared" or string.format("%d channel%s slotted", #resolved, #resolved == 1 and "" or "s")
		return true, string.format("Reactor loadout %s.", label), { Loadout = resolved }
	end

	function AnomalyService.ClaimMilestone(profile, rawTier: any): (boolean, string, any?)
		if type(rawTier) ~= "number" then
			return false, "Invalid anomaly milestone."
		end
		local tier = math.floor(rawTier)
		local milestone = GameConfig.Anomalies.Milestones[tier]
		if not milestone or profile.Anomaly.Stabilizations < milestone.Required then
			return false, "That anomaly milestone is still locked."
		end
		local key = tostring(tier)
		if profile.Anomaly.MilestoneClaims[key] then
			return false, "That anomaly milestone was already claimed."
		end
		profile.Anomaly.MilestoneClaims[key] = true
		local rewardText = ProgressionService.ApplyReward(profile, milestone.Reward, Economy.SteadyProduction(profile))
		return true,
			string.format("Reactor mark %d: %s.", tier, rewardText),
			{
				Tier = tier,
				Reward = milestone.Reward,
			}
	end

	function AnomalyService.ClaimDirective(profile, directiveId: string): (boolean, string, any?)
		AnomalyService.Ensure(profile)
		local cycle = currentCycle()
		local active = nil
		for _, directive in activeDirectives(cycle) do
			if directive.Definition.Id == directiveId then
				active = directive
				break
			end
		end
		if not active then
			return false, "That reactor job isn't active anymore."
		end
		local definition = active.Definition
		if profile.Anomaly.DirectiveClaims[definition.Id] then
			return false, "You already claimed that job."
		end
		local progress = profile.Anomaly.DirectiveProgress[definition.Id] or 0
		if progress < active.Target then
			return false, "That job isn't finished yet."
		end
		profile.Anomaly.DirectiveClaims[definition.Id] = true
		profile.Anomaly.Fragments += definition.Fragments
		bumpAnomalyStat(profile, "AnomalyDirectives")
		local rewardText = ProgressionService.ApplyReward(profile, definition.Reward, Economy.SteadyProduction(profile))
		return true,
			string.format("%s complete: %d fragments, %s.", definition.Name, definition.Fragments, rewardText),
			{
				DirectiveId = definition.Id,
				DirectiveName = definition.Name,
				Fragments = definition.Fragments,
			}
	end

	function AnomalyService.State(profile)
		local now = pulseNow()
		local cycle, anomaly, endsAt = currentCycle(now)

		local directiveCycleIsCurrent = profile.Anomaly.DirectiveCycle == cycle
		local directiveProgress = directiveCycleIsCurrent and profile.Anomaly.DirectiveProgress or {}
		local directiveClaims = directiveCycleIsCurrent and profile.Anomaly.DirectiveClaims or {}
		local protocols = {}
		local protocolLevels = 0
		for _, protocol in GameConfig.Anomalies.Protocols do
			local level = profile.Anomaly.Protocols[protocol.Id] or 0
			protocolLevels += level
			protocols[protocol.Id] = level
		end
		local discoveries = table.clone(profile.Anomaly.Discoveries)
		local milestones = {}
		local claimable = 0
		for tier, milestone in GameConfig.Anomalies.Milestones do
			local claimed = profile.Anomaly.MilestoneClaims[tostring(tier)] == true
			if not claimed and profile.Anomaly.Stabilizations >= milestone.Required then
				claimable += 1
			end
			milestones[tier] = {
				Tier = tier,
				Required = milestone.Required,
				Reward = milestone.Reward,
				Claimed = claimed,
			}
		end
		local directives = {}
		local claimableDirectives = 0
		for slot, directive in activeDirectives(cycle) do
			local definition = directive.Definition
			local progress = math.min(directive.Target, directiveProgress[definition.Id] or 0)
			local claimed = directiveClaims[definition.Id] == true
			if not claimed and progress >= directive.Target then
				claimableDirectives += 1
			end
			local reward = table.clone(definition.Reward)
			reward.Fragments = definition.Fragments
			directives[slot] = {
				Id = definition.Id,
				Name = definition.Name,
				Description = definition.Description,
				Kind = definition.Kind,
				Target = directive.Target,
				Progress = progress,
				Claimed = claimed,
				Reward = reward,
				Color = definition.Color,
			}
		end
		local target = AnomalyService.Target(profile)
		local ready = profile.Anomaly.Charge >= target
		local surgeActive = profile.Anomaly.SurgeEndsAt > now
		local phase = if surgeActive
			then (if ready then "SurgingReady" else "Surging")
			elseif ready then "Ready"
			else "Charging"

		local coreTier = profile.Anomaly.CoreTier or 0
		local coreXP = profile.Anomaly.CoreXP or 0
		local nextCoreTier = nil
		for _, tierConfig in GameConfig.Anomalies.CoreTiers do
			if tierConfig.Tier > coreTier then
				nextCoreTier = tierConfig
				break
			end
		end
		local loadout = type(profile.Anomaly.Loadout) == "table" and profile.Anomaly.Loadout or {}
		if #loadout == 0 and profile.Anomaly.Channel and GameConfig.Anomalies.Channels[profile.Anomaly.Channel] then
			loadout = { profile.Anomaly.Channel }
		end

		return {
			Cycle = cycle,
			TypeId = anomaly.Id,
			EndsAt = endsAt,
			Charge = profile.Anomaly.Charge,
			Target = target,
			Ready = ready,
			Phase = phase,
			Fragments = profile.Anomaly.Fragments,
			Stabilizations = profile.Anomaly.Stabilizations,
			SurgeEndsAt = profile.Anomaly.SurgeEndsAt,
			Channel = profile.Anomaly.Channel,
			Loadout = loadout,
			LoadoutSlots = GameConfig.Anomalies.LoadoutSlots,
			Protocols = protocols,
			ProtocolLevels = protocolLevels,
			Discoveries = discoveries,
			Milestones = milestones,
			ClaimableMilestones = claimable,
			Directives = directives,
			ClaimableDirectives = claimableDirectives,
			ChargeMultiplier = anomaly.ChargeMultiplier * (1 + protocolEffect(profile, "ChargeGain")),
			RewardMultiplier = rewardMultiplier(profile, anomaly),
			-- Overdrive Core additions.
			PulseWindowStartedAt = profile.Anomaly.PulseWindowStartedAt or 0,
			PulseWindowSeconds = GameConfig.Anomalies.PulseWindowSeconds,
			PulseWindowSweetZone = GameConfig.Anomalies.PulseWindowSweetZone,
			Combo = profile.Anomaly.Combo or 0,
			BestCombo = profile.Anomaly.BestCombo or 0,
			ComboMax = GameConfig.Anomalies.PulseComboMax,
			CoreTier = coreTier,
			CoreXP = coreXP,
			NextCoreTier = nextCoreTier,
			Overdrive = AnomalyService.OverdriveState(now),
		}
	end

	return table.freeze(AnomalyService)
end
