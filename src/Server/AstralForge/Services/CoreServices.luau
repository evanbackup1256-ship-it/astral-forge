--!strict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("CoreServices: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("CoreServices: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["AnomalyService"] = function()

return function(loadService: (string) -> any)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local AnomalyPulseScore = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("OpsMath"))("AnomalyPulseScore")
	local AnomalyOpsMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("AnomalyOpsMath")
	local ProfileBagMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileBagMath"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local ProgressionService = loadService("ProgressionService")

	local AnomalyService = {}

	local function pulseNow(): number
		return Workspace:GetServerTimeNow()
	end

	local function bumpAnomalyStat(profile, key: string)
		ProfileBagMath.BumpStat(profile, key, 1)
	end

	local overdrive: { Charge: number, BonusEndsAt: number } = {
		Charge = 0,
		BonusEndsAt = 0,
	}

	local function overdriveActive(now: number): boolean
		return overdrive.BonusEndsAt > now
	end

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
		return AnomalyOpsMath.FindProtocol(GameConfig.Anomalies.Protocols, protocolId)
	end

	local function activeDirectives(cycle: number)
		return AnomalyOpsMath.SelectDirectives(
			cycle,
			GameConfig.Anomalies.Directives,
			GameConfig.Anomalies.DirectiveSlots
		)
	end

	local function protocolEffect(profile, effectKind: string): number
		local anomaly = profile.Anomaly
		return AnomalyOpsMath.ProtocolEffect(
			anomaly and anomaly.Protocols,
			GameConfig.Anomalies.Protocols,
			effectKind
		)
	end

	local function rewardMultiplier(profile, anomaly): number
		local channelAmount = 0
		local channelId = profile.Anomaly and profile.Anomaly.Channel
		local channel = if type(channelId) == "string" then GameConfig.Anomalies.Channels[channelId] else nil
		if channel and channel.EffectKind == "Reward" then
			channelAmount = channel.EffectAmount
		end
		return AnomalyOpsMath.RewardMultiplier(
			anomaly.RewardMultiplier,
			protocolEffect(profile, "Reward"),
			channelAmount
		)
	end

	local function coreTierMaximumBonus(profile): number
		local tier = profile.Anomaly and profile.Anomaly.CoreTier
		return AnomalyOpsMath.CoreTierMaximumBonus(tier, GameConfig.Anomalies.CoreTiers)
	end

	function AnomalyService.Target(profile): number
		local anomaly = ProfileBagMath.EnsureAnomaly(profile)
		return AnomalyOpsMath.ChargeTarget(
			GameConfig.Anomalies.BaseTarget,
			GameConfig.Anomalies.TargetPerStabilization,
			GameConfig.Anomalies.MaximumTarget,
			anomaly.Stabilizations,
			coreTierMaximumBonus(profile)
		)
	end

	function AnomalyService.Ensure(profile): boolean
		local anomaly = ProfileBagMath.EnsureAnomaly(profile)
		local cycle = currentCycle()
		local changed = false
		if anomaly.Cycle ~= cycle then
			anomaly.Cycle = cycle
			anomaly.LastActionAt = 0
			changed = true
		end
		if anomaly.DirectiveCycle ~= cycle then
			anomaly.DirectiveCycle = cycle
			anomaly.DirectiveProgress = {}
			anomaly.DirectiveClaims = {}
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

	local PULSE_MIN_INTERVAL = (GameConfig.Anomalies.PulseCooldownSeconds or 0.25) :: number

	function AnomalyService.Pulse(profile, random: Random): (boolean, string, any)
		AnomalyService.Ensure(profile)
		local now = pulseNow()
		local lastAction = profile.Anomaly.LastActionAt or 0
		if now - lastAction < PULSE_MIN_INTERVAL then
			return false, string.format("Pulse recharging (%.2fs).", PULSE_MIN_INTERVAL - (now - lastAction)), nil
		end
		profile.Anomaly.LastActionAt = now

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

	local function applyCoreXP(profile, xp: number): number
		return AnomalyOpsMath.ApplyCoreXP(profile.Anomaly, xp, GameConfig.Anomalies.CoreTiers)
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
		profile.Anomaly.Fragments = math.max(0, math.floor(tonumber(profile.Anomaly.Fragments) or 0)) + fragments
		if profile.Anomaly.Fragments ~= profile.Anomaly.Fragments or profile.Anomaly.Fragments == math.huge then
			profile.Anomaly.Fragments = 1e308
		end
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
		return AnomalyOpsMath.ProtocolCost(protocol, level)
	end

	function AnomalyService.BuyProtocol(profile, protocolId: string): (boolean, string, any?)
		AnomalyService.Ensure(profile)
		local protocol = findProtocol(protocolId)
		if not protocol then
			return false, "That reactor upgrade was not found."
		end
		local anomaly = profile.Anomaly
		local level = anomaly.Protocols[protocol.Id] or 0
		if level >= protocol.MaxLevel then
			return false, "That reactor upgrade is at max level."
		end
		local cost = AnomalyService.ProtocolCost(protocol, level)
		if anomaly.Fragments < cost then
			return false, string.format("Requires %d anomaly fragments.", cost)
		end
		anomaly.Fragments -= cost
		anomaly.Protocols[protocol.Id] = level + 1
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
		AnomalyService.Ensure(profile)
		local now = pulseNow()
		local anomaly = profile.Anomaly
		if anomaly.SurgeEndsAt > now then
			return false, "Quantum Surge is already active."
		end
		local cost = GameConfig.Anomalies.SurgeCost
		if anomaly.Fragments < cost then
			return false, string.format("Requires %d anomaly fragments.", cost)
		end
		anomaly.Fragments -= cost
		local duration = GameConfig.Anomalies.SurgeBaseSeconds + protocolEffect(profile, "SurgeDuration")
		anomaly.SurgeEndsAt = now + duration
		return true,
			string.format("Surge on for %d seconds.", duration),
			{
				EndsAt = anomaly.SurgeEndsAt,
				Duration = duration,
			}
	end

	function AnomalyService.SetLoadout(profile, rawLoadout: any): (boolean, string, any?)
		if type(rawLoadout) ~= "table" then
			return false, "Invalid reactor loadout."
		end
		AnomalyService.Ensure(profile)
		local slots = GameConfig.Anomalies.LoadoutSlots
		local count = 0
		for key in rawLoadout do
			count += 1
			if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
				return false, "Invalid reactor loadout."
			end
		end
		if count > slots then
			return false, string.format("You can only slot %d channels at once.", slots)
		end
		local seen = {}
		local resolved = {}
		for index = 1, count do
			local channelId = rawLoadout[index]
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
		AnomalyService.Ensure(profile)
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
		profile.Anomaly.Fragments = math.max(0, math.floor(tonumber(profile.Anomaly.Fragments) or 0)) + math.max(0, math.floor(tonumber(definition.Fragments) or 0))
		if profile.Anomaly.Fragments ~= profile.Anomaly.Fragments or profile.Anomaly.Fragments == math.huge then
			profile.Anomaly.Fragments = 1e308
		end
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
		AnomalyService.Ensure(profile)
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

		local coreTier = math.max(0, math.floor(tonumber(profile.Anomaly.CoreTier) or 0))
		local coreXP = math.max(0, tonumber(profile.Anomaly.CoreXP) or 0)
		local nextCoreTier = AnomalyOpsMath.NextCoreTier(coreTier, GameConfig.Anomalies.CoreTiers)
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
end

__defs["ServerEventService"] = function()

return function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerEvents = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("ServerEvents")

	local ServerEventService = {}
	ServerEventService.__index = ServerEventService

	function ServerEventService.new(hooks)
		local self = setmetatable({}, ServerEventService)
		self._hooks = hooks
		self._state = nil
		self._points = {}
		self._names = {}
		self._goal = 0
		self._progress = 0
		self._completed = false
		self._accumulator = 0
		self._broadcastDue = false
		self._lastBroadcast = 0
		return self
	end

	function ServerEventService:_def()
		local state = self._state
		return state and state.Id and ServerEvents.EVENTS[state.Id] or nil
	end

	function ServerEventService:Step(dt: number)
		self._accumulator += dt
		if self._accumulator < 1 then
			return
		end
		self._accumulator = 0
		local now = os.time()
		local nextState, changed = ServerEvents.advance(self._state, now, self._hooks.random())
		if changed then
			local previous = self._state
			self._state = nextState
			self:_enter(previous, nextState)
		end
		if self._broadcastDue and os.clock() - self._lastBroadcast >= 1 then
			self._broadcastDue = false
			self._lastBroadcast = os.clock()
			self._hooks.broadcast()
		end
	end

	function ServerEventService:_enter(previous, state)
		local def = self:_def()
		if state.Phase == "Live" and state.Id == "CommunityForge" then
			self._points = {}
			self._names = {}
			self._progress = 0
			self._completed = false
			self._goal = ServerEvents.communityGoal(#Players:GetPlayers())
		end
		if state.Phase == "Results" and state.Id == "CommunityForge" and not self._completed then
			self._completed = false
		end
		if def ~= nil and (state.Phase == "Warning" or state.Phase == "Live" or state.Phase == "Results") then
			self._hooks.announce(state.Phase, def)
		end
		self._hooks.broadcast()
		self._lastBroadcast = os.clock()
		self._broadcastDue = false
	end

	function ServerEventService:ProductionMultiplier(): number
		return ServerEvents.productionMultiplier(self._state)
	end

	function ServerEventService:OnCollect(player: Player, collected: number, perSecond: number): number
		local state = self._state
		if state == nil or state.Phase ~= "Live" then
			return 0
		end
		if state.Id == "StardustRain" then
			return ServerEvents.rainDust(collected, perSecond)
		end
		if state.Id == "CommunityForge" and not self._completed then
			local points = ServerEvents.collectPoints(collected, perSecond)
			self._points[player.UserId] = (self._points[player.UserId] or 0) + points
			self._names[player.UserId] = player.DisplayName
			self._progress += points
			self._broadcastDue = true
			if self._progress >= self._goal then
				self._completed = true
				local ranking = ServerEvents.ranking(self._points)
				self._hooks.payout(ranking, ServerEvents.EVENTS.CommunityForge)
				self._hooks.announce("Completed", ServerEvents.EVENTS.CommunityForge)
				self._hooks.broadcast()
			end
		end
		return 0
	end

	function ServerEventService:Start(id: string)
		if ServerEvents.EVENTS[id] == nil then
			return false
		end
		local previous = self._state
		self._state = { Phase = "Live", Id = id, PhaseEndsAt = os.time() + ServerEvents.LIVE_SECONDS, LastId = previous and previous.LastId }
		self:_enter(previous, self._state)
		return true
	end

	function ServerEventService:State(player: Player?)
		local state = self._state
		local now = os.time()
		if state == nil then
			return { Phase = "Rest", PhaseEndsAt = now + ServerEvents.FIRST_REST_SECONDS }
		end
		local public = {
			Phase = state.Phase,
			Id = state.Id,
			PhaseEndsAt = state.PhaseEndsAt,
			Multiplier = ServerEvents.productionMultiplier(state),
		}
		if state.Id == "CommunityForge" and (state.Phase == "Live" or state.Phase == "Results") then
			local top = {}
			for index, entry in ServerEvents.ranking(self._points) do
				if index > 5 then
					break
				end
				table.insert(top, { Name = self._names[entry.UserId] or tostring(entry.UserId), Points = entry.Points, UserId = entry.UserId })
			end
			public.Goal = self._goal
			public.Progress = math.min(self._progress, self._goal)
			public.Completed = self._completed
			public.Yours = if player ~= nil then (self._points[player.UserId] or 0) else 0
			public.Top = top
		end
		return public
	end

	return ServerEventService
end
end

__defs["ForgeEchoService"] = function()

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local ForgeEchoMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ForgeEchoMath"))
	local ProgressionGate = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("ProgressionGate")

	local ForgeEchoService = {}
	local Config = GameConfig.ForgeEchoes

	local traitById = {}
	for _, trait in Config.Traits do
		traitById[trait.Id] = trait
	end

	local patternAffinity = ForgeEchoMath.PATTERN_AFFINITY

	local function ensure(profile)
		profile.ForgeEchoes = ForgeEchoMath.Ensure(profile.ForgeEchoes)
		return profile.ForgeEchoes
	end

	local function display(instance, uidOverride: string?)
		local trait = traitById[instance.TraitId]
		if not trait then return nil end
		local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, Config.MaxLevel)
		return {
			Uid = tostring(uidOverride or instance.Uid or ""),
			TraitId = trait.Id,
			Name = trait.Name,
			Description = trait.Description,
			Affinity = trait.Affinity,
			EffectKind = trait.EffectKind,
			Level = level,
			Strength = math.clamp(tonumber(instance.Strength) or 1, 0.75, 1.5),
			EffectValue = ForgeEchoMath.EffectValue(instance, trait, Config.MaxLevel),
			UpgradeCost = ForgeEchoMath.UpgradeCost(level, Config.MaxLevel, Config.UpgradeBaseDust, Config.UpgradeScale),
			Color = trait.Color,
			CapturedAt = math.max(0, math.floor(tonumber(instance.CapturedAt) or 0)),
			Origin = tostring(instance.Origin or "Collect"),
		}
	end

	function ForgeEchoService.Record(profile, patternId: string, weight: number): boolean
		if not ProgressionGate.IsFeatureUnlocked(profile, "Echoes") then return false end
		if not patternAffinity[patternId] then return false end
		local echoes = ensure(profile)
		if #(echoes.Draft.Choices) > 0 then return false end
		local safeWeight = math.clamp(tonumber(weight) or 0, 0, 14)
		if safeWeight <= 0 then return false end
		echoes.Pattern[patternId] = math.min(1e9, (tonumber(echoes.Pattern[patternId]) or 0) + safeWeight)
		echoes.Charge = math.min(Config.ChargeTarget, (tonumber(echoes.Charge) or 0) + safeWeight)
		return true
	end

	function ForgeEchoService.Capture(profile, random: Random): (boolean, string, any?)
		local echoes = ensure(profile)
		if #(echoes.Draft.Choices) > 0 then return false, "Choose one of the echoes already waiting." end
		if ForgeEchoMath.InventoryCount(echoes.Inventory) >= Config.InventoryLimit then return false, "Your echo vault is full. Dismantle one first." end
		if (tonumber(echoes.Charge) or 0) < Config.ChargeTarget then return false, "The forge has not recorded a complete pattern yet." end
		local origin, affinity = ForgeEchoMath.DominantPattern(echoes.Pattern, patternAffinity)
		local pool = table.clone(Config.Traits)
		local selected = {}
		local used = {}
		local preferred = {}
		for _, trait in pool do if trait.Affinity == affinity then table.insert(preferred, trait) end end
		-- Guard empty preferred list; if no trait matches the dominant affinity, fall back
		-- to a uniform pick from the full pool so capture never hard-errors.
		local firstPool = if #preferred > 0 then preferred else pool
		local first = firstPool[random:NextInteger(1, #firstPool)]
		if not first then return false, "No echo traits available for capture.", nil end
		table.insert(selected, first)
		used[first.Id] = true
		while #selected < 3 do
			local candidate = pool[random:NextInteger(1, #pool)]
			if not used[candidate.Id] then
				used[candidate.Id] = true
				table.insert(selected, candidate)
			end
		end
		local qualityBonus = math.min(
			Config.MaxResonanceQualityBonus,
			math.sqrt(math.max(0, tonumber(echoes.Resonance) or 0)) * 0.006
		)
		local draftId = string.format("D%d_%d", os.time(), random:NextInteger(1000, 9999))
		local choices = {}
		for index, trait in selected do
			local strength = math.clamp(0.9 + random:NextNumber() * 0.22 + qualityBonus, 0.9, 1.32)
			choices[index] = {
				Uid = draftId .. "_" .. tostring(index),
				TraitId = trait.Id,
				Level = 1,
				Strength = strength,
				CapturedAt = os.time(),
				Origin = origin,
			}
		end
		echoes.Draft = { Id = draftId, Choices = choices }
		echoes.Charge = 0
		echoes.Pattern = { Collect = 0, Surge = 0, Build = 0, Explore = 0 }
		return true, "Three echoes answered your forge pattern.", { Origin = origin }
	end

	function ForgeEchoService.Claim(profile, choiceId: any): (boolean, string, any?)
		if type(choiceId) ~= "string" then return false, "That echo is not part of this capture." end
		local echoes = ensure(profile)
		local picked = nil
		for _, choice in echoes.Draft.Choices do
			if choice.Uid == choiceId then picked = choice break end
		end
		if not picked or not traitById[picked.TraitId] then return false, "That echo is no longer available." end
		if ForgeEchoMath.InventoryCount(echoes.Inventory) >= Config.InventoryLimit then return false, "Your echo vault is full." end
		local uid = "E" .. tostring(math.max(1, math.floor(tonumber(echoes.NextId) or 1)))
		echoes.NextId = math.max(1, math.floor(tonumber(echoes.NextId) or 1)) + 1
		picked.Uid = uid
		echoes.Inventory[uid] = picked
		echoes.Captures = math.max(0, math.floor(tonumber(echoes.Captures) or 0)) + 1
		echoes.Draft = { Id = "", Choices = {} }
		local slots = ForgeEchoMath.UnlockedSlots(echoes.Captures, Config.SlotCaptureRequirements, Config.MaxSlots)
		for slot = 1, slots do
			local key = tostring(slot)
			if not echoes.Equipped[key] or echoes.Equipped[key] == "" then
				echoes.Equipped[key] = uid
				break
			end
		end
		local shown = display(picked)
		return true, "Captured " .. (shown and shown.Name or "a forge echo") .. ".", { EchoUid = uid }
	end

	function ForgeEchoService.Equip(profile, uid: any, slot: any): (boolean, string)
		if type(uid) ~= "string" or type(slot) ~= "number" or slot ~= math.floor(slot) then return false, "Choose a valid echo slot." end
		local echoes = ensure(profile)
		if not echoes.Inventory[uid] then return false, "That echo is not in your vault." end
		if slot < 1 or slot > ForgeEchoMath.UnlockedSlots(echoes.Captures, Config.SlotCaptureRequirements, Config.MaxSlots) then
			return false, "That echo slot has not stabilized yet."
		end
		for key, equippedUid in echoes.Equipped do if equippedUid == uid then echoes.Equipped[key] = "" end end
		echoes.Equipped[tostring(slot)] = uid
		return true, "Echo linked to slot " .. tostring(slot) .. "."
	end

	function ForgeEchoService.UpgradeCost(instance): number
		return ForgeEchoMath.UpgradeCost(
			instance and instance.Level,
			Config.MaxLevel,
			Config.UpgradeBaseDust,
			Config.UpgradeScale
		)
	end

	function ForgeEchoService.Upgrade(profile, uid: any): (boolean, string, any?)
		if type(uid) ~= "string" then return false, "Choose an echo to tune." end
		local echoes = ensure(profile)
		local instance = echoes.Inventory[uid]
		if not instance or not traitById[instance.TraitId] then return false, "That echo is not in your vault." end
		local level = math.clamp(math.floor(tonumber(instance.Level) or 1), 1, Config.MaxLevel)
		if level >= Config.MaxLevel then return false, "That echo is already perfectly tuned." end
		local cost = ForgeEchoService.UpgradeCost(instance)
		if Economy.Lt(profile.Stardust, cost) then return false, "You need more stardust to tune that echo." end
		profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, cost))
		instance.Level = level + 1
		return true, "Echo tuned to level " .. tostring(instance.Level) .. ".", { Cost = cost, EchoUid = uid }
	end

	function ForgeEchoService.Dismantle(profile, uid: any): (boolean, string, any?)
		if type(uid) ~= "string" then return false, "Choose an echo to dismantle." end
		local echoes = ensure(profile)
		local instance = echoes.Inventory[uid]
		if not instance then return false, "That echo is not in your vault." end
		for key, equippedUid in echoes.Equipped do if equippedUid == uid then echoes.Equipped[key] = "" end end
		local level = math.max(1, math.floor(tonumber(instance.Level) or 1))
		local gained = 5 + level * Config.ResonancePerDismantleLevel
		echoes.Resonance = math.max(0, math.floor(tonumber(echoes.Resonance) or 0)) + gained
		echoes.Inventory[uid] = nil
		return true, "Echo returned " .. tostring(gained) .. " resonance.", { Resonance = gained }
	end

	function ForgeEchoService.State(profile)
		local echoes = ensure(profile)
		local inventory = {}
		for uid, instance in echoes.Inventory do
			local shown = display(instance, uid)
			if shown then table.insert(inventory, shown) end
		end
		table.sort(inventory, function(a, b)
			if a.Level == b.Level then return a.Uid < b.Uid end
			return a.Level > b.Level
		end)
		local choices = {}
		for index, choice in echoes.Draft.Choices do choices[index] = display(choice) end
		local slots = ForgeEchoMath.UnlockedSlots(echoes.Captures, Config.SlotCaptureRequirements, Config.MaxSlots)
		local equipped = {}
		local affinities = {}
		local equippedCount = 0
		for slot = 1, Config.MaxSlots do
			local uid = echoes.Equipped[tostring(slot)] or ""
			local shown = uid ~= "" and echoes.Inventory[uid] and display(echoes.Inventory[uid], uid) or nil
			equipped[slot] = { Slot = slot, Unlocked = slot <= slots, Echo = shown }
			if shown and slot <= slots then
				equippedCount += 1
				affinities[shown.Affinity] = true
			end
		end
		local affinityCount = 0
		for _ in affinities do affinityCount += 1 end
		local harmony = equippedCount >= 2 and affinityCount == equippedCount
		local origin, _ = ForgeEchoMath.DominantPattern(echoes.Pattern, patternAffinity)
		local nextRequirement = slots < Config.MaxSlots and Config.SlotCaptureRequirements[slots + 1] or nil
		return {
			Charge = math.clamp(tonumber(echoes.Charge) or 0, 0, Config.ChargeTarget),
			ChargeTarget = Config.ChargeTarget,
			Ready = (tonumber(echoes.Charge) or 0) >= Config.ChargeTarget,
			Resonance = math.max(0, math.floor(tonumber(echoes.Resonance) or 0)),
			Captures = math.max(0, math.floor(tonumber(echoes.Captures) or 0)),
			InventoryLimit = Config.InventoryLimit,
			MaxLevel = Config.MaxLevel,
			SlotsUnlocked = slots,
			NextSlotAt = nextRequirement,
			Harmony = harmony,
			HarmonyBonus = harmony and Config.HarmonyBonus or 0,
			DominantPattern = origin,
			Pattern = {
				Collect = math.max(0, tonumber(echoes.Pattern.Collect) or 0),
				Surge = math.max(0, tonumber(echoes.Pattern.Surge) or 0),
				Build = math.max(0, tonumber(echoes.Pattern.Build) or 0),
				Explore = math.max(0, tonumber(echoes.Pattern.Explore) or 0),
			},
			DraftId = tostring(echoes.Draft.Id or ""),
			Choices = choices,
			Inventory = inventory,
			Equipped = equipped,
		}
	end

	return table.freeze(ForgeEchoService)
end
end

__defs["GuildService"] = function()

return function()

	local DataStoreService = game:GetService("DataStoreService")
	local RunService = game:GetService("RunService")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
	local LeaderboardCodec = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("LeaderboardCodec"))
	local GuildMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("OpsMath"))("GuildMath")
	local GuildGoalMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("OpsMath"))("GuildGoalMath")
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))

	local Social = require(game.ReplicatedStorage.AstralForge.Shared.SocialProgression)(OmegaMath)
	local GuildService = {}
	GuildService.__index = GuildService

	local function finiteNonNegative(value): number
		return GuildMath.FiniteNonNegative(value)
	end

	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in value do result[key] = copy(child) end
		return result
	end

	local function normalTag(tag: string): string
		return string.upper(tag:gsub("%s+", ""))
	end

	local function upgradeCost(definition, level: number): number
		return GuildMath.UpgradeCost(definition, level)
	end

	local function upgradeEffect(definition, level: number): number
		return GuildMath.UpgradeEffect(definition, level)
	end

	local function goalTypeById(typeId: string)
		return GuildGoalMath.GoalTypeById(GameConfig.Guild.Goal.Types, typeId)
	end

	local function ensureGoal(guild, now: number): boolean
		return GuildGoalMath.EnsureGoal(guild, now, GameConfig.Guild.Goal)
	end

	local function advanceGoal(guild, userKey: string, metric: string, amount: number, now: number)
		GuildGoalMath.AdvanceGoal(guild, userKey, metric, amount, now, GameConfig.Guild.Goal)
	end

	local function emptyBonuses()
		return GuildMath.EmptyBonuses()
	end

	local function bonusesFromDocument(guild)
		if not guild then
			return emptyBonuses()
		end
		return GuildMath.BonusesFromUpgrades(guild.Upgrades, GameConfig.Guild.Upgrades)
	end


	local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)
		local getOrderedStore = StoreAccess.ordered
		local getDataStore = StoreAccess.data
		local previewEnabled = StoreAccess.isPreview()

		function GuildService.new()
		local self = setmetatable({}, GuildService)
		self._cache = {}
		self._cacheExpiry = {}
		self._cachePruneAt = 0
		self._studio = {}
		self._store = getDataStore(ServerConfig.GuildStoreName)
		self._leaderboard = getOrderedStore(ServerConfig.GuildLeaderboardStoreName)
		self._leaderboardPending = {}
		self._leaderboardBusy = {}
		self._leaderboardCache = nil
		self._leaderboardCacheExpires = 0
		self._warmQueue = {}
		self._warmQueued = {}
		self._warmWorkers = 0
		self._running = true
		self._workers = {}
		return self
	end

	function GuildService:_spawnWorker(callback)
		if not self._running then return nil end
		local token = {}
		local worker = task.defer(function()
			if self._running then callback() end
			self._workers[token] = nil
		end)
		self._workers[token] = worker
		return worker
	end

	function GuildService:_queueWarmRead(id: string)
		if not self._running then return end
		if self._cache[id] or self._studio[id] or self._warmQueued[id] then return end
		self._warmQueued[id] = true
		table.insert(self._warmQueue, id)
		while self._warmWorkers < 2 and #self._warmQueue > 0 do
			self._warmWorkers += 1
			local worker = self:_spawnWorker(function()
				local ok, err = pcall(function()
					while self._running and #self._warmQueue > 0 do
						local nextId = table.remove(self._warmQueue, 1)
						if nextId then
							local readOk, readErr = pcall(function()
								self:_read(nextId)
							end)
							self._warmQueued[nextId] = nil
							if readOk then
								self._leaderboardCacheExpires = 0
							else
								warn(string.format("[WARN] [GUILD] warm read failed for %s — %s", tostring(nextId), tostring(readErr)))
							end
						end
					end
				end)
				self._warmWorkers -= 1
				if not ok then
					warn(string.format("[WARN] [GUILD] warm worker crashed — %s", tostring(err)))
				end
			end)
			if not worker then
				self._warmWorkers -= 1
			end
		end
	end

	function GuildService:_queueLeaderboard(id: string, activity: number)
		if not self._running then return end
		self._leaderboardPending[id] = LeaderboardCodec.Encode(activity)
		if self._leaderboardBusy[id] then return end
		self._leaderboardBusy[id] = true
		local worker = self:_spawnWorker(function()
			local lastWarnAt = 0
			local ok, err = pcall(function()
				while self._running and self._leaderboardPending[id] ~= nil do
					local encoded = self._leaderboardPending[id]
					self._leaderboardPending[id] = nil
					local wrote, writeErr = pcall(function()
						self._leaderboard:SetAsync(id, encoded)
					end)
					if not wrote then
						if self._leaderboardPending[id] == nil then
							self._leaderboardPending[id] = encoded
						end
						local now = os.clock()
						if now - lastWarnAt >= 30 then
							lastWarnAt = now
							warn(string.format("[WARN] [GUILD] leaderboard write failed for %s — %s", id, tostring(writeErr)))
						end
						task.wait(8)
					end
				end
			end)
			self._leaderboardBusy[id] = nil
			if not ok then
				warn(string.format("[WARN] [GUILD] leaderboard worker crashed for %s — %s", tostring(id), tostring(err)))
			end
		end)
		if not worker then
			self._leaderboardBusy[id] = nil
		end
	end

	function GuildService:Destroy()
		if not self._running then return end
		self._running = false
		for _, worker in self._workers do
			pcall(task.cancel, worker)
		end
		table.clear(self._workers)
		table.clear(self._warmQueue)
		table.clear(self._warmQueued)
		table.clear(self._leaderboardPending)
		table.clear(self._leaderboardBusy)
		self._warmWorkers = 0
	end

	function GuildService:_pruneCache()
		local now = os.clock()
		if now < self._cachePruneAt then return end
		self._cachePruneAt = now + 30
		for id, expiresAt in self._cacheExpiry do
			if type(expiresAt) ~= "number" or expiresAt <= now then
				self._cacheExpiry[id] = nil
				self._cache[id] = nil
			end
		end
	end

	function GuildService:_read(id: string)
	self:_pruneCache()
	if RunService:IsStudio() and self._studio[id] then
		return copy(self._studio[id])
	end
	local cached = self._cache[id]
	if cached and (self._cacheExpiry[id] or 0) > os.clock() then
		return copy(cached)
	end
	local ok, result = pcall(function()
		return self._store:GetAsync(id)
	end)
	if ok and type(result) == "table" then
		self._cache[id] = result
		self._cacheExpiry[id] = os.clock() + 60
		return copy(result)
	end

	if ok and result == nil and not RunService:IsStudio() then
		self._cache[id] = nil
		self._cacheExpiry[id] = nil
		return nil
	end
	if cached then
		return copy(cached)
	end
	return nil
end


function GuildService:_update(id: string, transform)
	local updated
	local function apply(current)
		-- UpdateAsync can invoke this callback again after a concurrent write.
		-- No approval from an earlier attempt may survive a cancelled final attempt.
		updated = nil
		local doc = if type(current) == "table" then current else nil
		if doc == nil and RunService:IsStudio() then
			doc = self._studio[id] or self._cache[id]
		end
		if type(doc) ~= "table" then
			return nil
		end
		local nextDoc = transform(copy(doc))

		if nextDoc == nil then
			return nil
		end
		updated = nextDoc
		return nextDoc
	end
	local ok, err = pcall(function()
		return self._store:UpdateAsync(id, apply)
	end)
	if not ok then
		if not RunService:IsStudio() then
			return false, tostring(err), nil
		end
		local fallback = self._studio[id] or self._cache[id]
		if type(fallback) == "table" then
			updated = transform(copy(fallback))
			if type(updated) == "table" then
				self._studio[id] = updated
			end
		else
			return false, tostring(err), nil
		end
	end
	if type(updated) ~= "table" then
		return false, "Guild request was denied.", nil
	end
	self._cache[id] = updated
	self._cacheExpiry[id] = os.clock() + 60
	if RunService:IsStudio() then
		self._studio[id] = updated
	end
	self:_queueLeaderboard(id, updated.Activity)
	return true, nil, copy(updated)
end


function GuildService:_findByTag(tag: string)
		self:_pruneCache()
		local wanted = normalTag(tag)
		for _, doc in self._cache do
			if doc.Tag == wanted then return copy(doc) end
		end
		for _, doc in self._studio do
			if doc.Tag == wanted then return copy(doc) end
		end

		local ok, id = pcall(function() return self._store:GetAsync("tag:" .. wanted) end)
		if ok and type(id) == "string" then return self:_read(id) end
		return nil
	end

	function GuildService:Create(player, profile, rawName: string, rawTag: string)
		if type(rawName) ~= "string" or type(rawTag) ~= "string" then return false, "Guild names must be 3–28 letters, numbers, spaces, - or _." end
		if profile.Guild and profile.Guild.Id ~= "" then
			local existing = self:GetCachedPublic(profile.Guild.Id) or self:GetPublic(profile.Guild.Id)
			if existing then return true, "You're already in this guild.", existing end
			return false, "Leave your current guild first."
		end
		local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
		local tag = normalTag(rawTag)
		if #name < 3 or #name > 28 or not string.match(name, "^[%w%s%-_]+$") then return false, "Guild names must be 3–28 letters, numbers, spaces, - or _." end
		if #tag < 3 or #tag > 4 or not string.match(tag, "^[A-Z0-9]+$") then return false, "Guild tags must be 3–4 letters or numbers." end
		if OmegaMath.Lt(profile.Cash, GameConfig.Guild.CreateCost) then return false, "You need more flux to charter a guild." end
		if self:_findByTag(tag) then return false, "That guild tag is already in use." end
		local id = HttpService:GenerateGUID(false)
		local doc = {
			Id = id, Name = name, Tag = tag, Level = 1, XP = 0, Activity = 0, BankCash = 0, BankDust = 0,
			Members = { [tostring(player.UserId)] = { Name = (player.DisplayName ~= "" and player.DisplayName) or player.Name, Role = "Leader", JoinedAt = os.time(), Contributed = 0 } },
			Upgrades = {}, CreatedAt = os.time(), OwnerUserId = player.UserId,
		}
		ensureGoal(doc, os.time())
		local documentCreated = false
		local tagClaimed = false
		local ok, err = pcall(function()
			self._store:UpdateAsync(id, function(existing)
				documentCreated = false
				if existing ~= nil then return existing end
				documentCreated = true
				return doc
			end)
			if not documentCreated then error("generated guild id already exists") end
			self._store:UpdateAsync("tag:" .. tag, function(existing)
				tagClaimed = false
				if existing == nil or existing == id then
					tagClaimed = true
					return id
				end
				return existing
			end)
		end)
		if not ok then
			warn(string.format("[WARN] [GUILD] create failed for %s — %s", player.Name, tostring(err)))
		end
		if not RunService:IsStudio() and (not ok or not documentCreated or not tagClaimed) then

			if documentCreated and not tagClaimed then
				local removed, removeErr = pcall(function() self._store:RemoveAsync(id) end)
				if not removed then
					warn(string.format("[WARN] [GUILD] could not roll back guild %s — %s", id, tostring(removeErr)))
				end
			end
			if not ok then return false, "Guild records are unavailable. Try again shortly." end
			return false, "That guild tag is already in use."
		end
		self._cache[id] = doc
		if RunService:IsStudio() then self._studio[id] = doc end
		self._cacheExpiry[id] = os.clock() + 60
		profile.Cash = OmegaMath.Sub(profile.Cash, GameConfig.Guild.CreateCost)
		profile.Guild = { Id = id, Role = "Leader", JoinedAt = os.time(), Tag = tag }
		return true, "Guild Hall chartered.", copy(doc)
	end

	function GuildService:Rename(player, profile, newName: string, newTag: string?)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "You are not in a guild." end
		local membership = profile.Guild
		if type(membership) ~= "table" or membership.Role ~= "Leader" then
			return false, "Only the guild leader can rename the guild."
		end
		local name = newName:gsub("^%s+", ""):gsub("%s+$", "")
		if #name < 3 or #name > 28 or not string.match(name, "^[%w%s%-_]+$") then
			return false, "Guild names must be 3–28 letters, numbers, spaces, - or _."
		end
		local changeTag = type(newTag) == "string" and #newTag > 0
		local tag = changeTag and normalTag(newTag :: string) or ""
		if changeTag and (#tag < 3 or #tag > 4 or not string.match(tag, "^[A-Z0-9]+$")) then
			return false, "Guild tags must be 3–4 letters or numbers."
		end
		if OmegaMath.Lt(profile.Cash, GameConfig.Guild.RenameCost) then
			return false, "You need more flux to rename the guild."
		end
		local guild = self:_read(guildId)
		if type(guild) ~= "table" then return false, "Guild records are unavailable." end
		local now = os.time()
		local cooldown = tonumber(guild.LastRenamedAt) or 0
		if cooldown + GameConfig.Guild.RenameCooldownSeconds > now then
			return false, "The guild was renamed too recently."
		end
		local oldName, oldTag = guild.Name, guild.Tag
		if name == oldName and (not changeTag or tag == oldTag) then
			return false, "Pick a new name or tag."
		end
		if changeTag then
			local existing = self:_findByTag(tag)
			if existing and existing.Id ~= guildId then
				return false, "That guild tag is already in use."
			end
		end
		local ok, message, updated = self:_update(guildId, function(doc)
			if type(doc) ~= "table" then return nil end
			local docCooldown = tonumber(doc.LastRenamedAt) or 0
			if docCooldown + GameConfig.Guild.RenameCooldownSeconds > now then
				return nil
			end
			doc.Name = name
			doc.LastRenamedAt = now
			if changeTag then
				doc.Tag = tag
			end
			if type(doc.AuditLog) ~= "table" then
				doc.AuditLog = {}
			end
			table.insert(doc.AuditLog, 1, {
				At = now,
				By = player.UserId,
				Action = "Rename",
				FromName = oldName,
				ToName = name,
				FromTag = changeTag and oldTag or nil,
				ToTag = changeTag and tag or nil,
				Cost = GameConfig.Guild.RenameCost,
			})
			if #doc.AuditLog > 50 then
				table.remove(doc.AuditLog)
			end
			return doc
		end)
		if not ok then return false, message or "Could not rename the guild." end
		if changeTag then
			local released, releaseErr = pcall(function()
				if self._store:GetAsync("tag:" .. oldTag) == guildId then
					self._store:RemoveAsync("tag:" .. oldTag)
				end
			end)
			if not released then
				warn(string.format("[WARN] [GUILD] rename could not release old tag %s — %s", oldTag, tostring(releaseErr)))
			end
			local claimed, claimErr = pcall(function()
				self._store:UpdateAsync("tag:" .. tag, function(existing)
					if existing == nil or existing == guildId then
						return guildId
					end
					return existing
				end)
			end)
			if not claimed then
				warn(string.format("[WARN] [GUILD] rename could not claim new tag %s — %s", tag, tostring(claimErr)))
			end
		end
		profile.Cash = OmegaMath.Sub(profile.Cash, GameConfig.Guild.RenameCost)
		profile.Guild.Tag = changeTag and tag or profile.Guild.Tag
		return true, "Guild renamed.", updated
	end

	function GuildService:JoinByTag(player, profile, rawTag: string)
		if type(rawTag) ~= "string" then return false, "No guild has that tag." end
		if profile.Guild and profile.Guild.Id ~= "" then
			local existing = self:GetCachedPublic(profile.Guild.Id) or self:GetPublic(profile.Guild.Id)
			if existing then return true, "You're already in this guild.", existing end
			return false, "Leave your current guild first."
		end
		local doc = self:_findByTag(rawTag)
		if not doc then return false, "No guild has that tag." end
		local blockedFull = false
		local ok, message, updated = self:_update(doc.Id, function(guild)
			blockedFull = false
			local key = tostring(player.UserId)
			if guild.Members[key] then return guild end
			local count = 0; for _ in guild.Members do count += 1 end
			if count >= GameConfig.Guild.MaxMembers then
				blockedFull = true
				return nil
			end
			guild.Members[key] = { Name = (player.DisplayName ~= "" and player.DisplayName) or player.Name, Role = "Member", JoinedAt = os.time(), Contributed = 0 }
			return guild
		end)
		if not ok then
			if blockedFull then return false, "That guild is full." end
			return false, message
		end
		local membership = updated.Members[tostring(player.UserId)]
		if not membership then return false, "That guild is full." end
		profile.Guild = { Id = updated.Id, Role = membership.Role or "Member", JoinedAt = os.time(), Tag = updated.Tag }
		return true, "Joined " .. updated.Name .. ".", updated
	end

	function GuildService:Leave(player, profile)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "You are not in a guild." end
		local blockedLastMember = false
		local ok, message, updated = self:_update(guildId, function(guild)
			blockedLastMember = false
			local key = tostring(player.UserId)
			local member = guild.Members[key]
			if not member then return nil end
			local otherCount = 0
			for otherKey in guild.Members do
				if otherKey ~= key then otherCount += 1 end
			end
			if otherCount == 0 then
				blockedLastMember = true
				return nil
			end
			if member.Role == "Leader" then
				local successor = Social.successor(guild.Members,key)
				if successor then
					guild.Members[successor].Role = "Leader"
					guild.OwnerUserId = tonumber(successor) or 0
				end
			end
			guild.Members[key] = nil
			return guild
		end)
		if not ok then
			if blockedLastMember then return false, "You're the last member — disband the guild instead of leaving." end
			return false, message
		end
		profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
		profile.GuildBonuses = emptyBonuses()
		return true, "Left the guild.", { Id = "", Name = "", Tag = "", Level = 0, XP = 0, Activity = 0, BankCash = 0, BankDust = 0, Members = {}, Upgrades = {}, CreatedAt = 0, OwnerUserId = 0 }
	end

	function GuildService:Disband(player, profile)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "You are not in a guild." end
		self._cache[guildId] = nil
		self._cacheExpiry[guildId] = nil
		local guild = self:_read(guildId)
		if not guild then return false, "Guild records are unavailable." end
		local key = tostring(player.UserId)
		local member = guild.Members[key]
		if not member or member.Role ~= "Leader" then return false, "Only the guild leader can disband it." end
		local memberCount = 0
		for _ in guild.Members do memberCount += 1 end
		if memberCount > 1 then return false, "Remove every other member before disbanding." end
		local tag = guild.Tag
		local removedDoc, removeErr = pcall(function() self._store:RemoveAsync(guildId) end)
		if not removedDoc and not RunService:IsStudio() then
			warn(string.format("[WARN] [GUILD] disband could not delete %s — %s", guildId, tostring(removeErr)))
			return false, "Guild records are unavailable. Try again shortly."
		end
		if removedDoc then
			local released, releaseErr = pcall(function()
				if self._store:GetAsync("tag:" .. tag) == guildId then
					self._store:RemoveAsync("tag:" .. tag)
				end
			end)
			pcall(function()
				self._leaderboard:RemoveAsync(guildId)
			end)
			if not released then
				warn(string.format("[WARN] [GUILD] disband deleted %s but the tag %s is still reserved — %s", guildId, tostring(tag), tostring(releaseErr)))
				if not RunService:IsStudio() then
					return false, "Guild records are unavailable. Try again shortly."
				end
			end
		end
		self._cache[guildId] = nil
		self._cacheExpiry[guildId] = nil
		if RunService:IsStudio() then self._studio[guildId] = nil end
		profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
		profile.GuildBonuses = emptyBonuses()
		return true, "Guild disbanded.", { Id = "", Name = "", Tag = "", Level = 0, XP = 0, Activity = 0, BankCash = 0, BankDust = 0, Members = {}, Upgrades = {}, CreatedAt = 0, OwnerUserId = 0 }
	end

	function GuildService:Kick(player, profile, targetUserId: number)
		local guildId = profile.Guild and profile.Guild.Id or ""
		local ok, message, updated = self:_update(guildId, function(guild)
			local actor, target = guild.Members[tostring(player.UserId)], guild.Members[tostring(targetUserId)]
			if player.UserId == targetUserId or not Social.canManage(actor,target,"Kick") then return nil end
			guild.Members[tostring(targetUserId)] = nil
			return guild
		end)
		return ok, ok and "Member removed." or (message or "You cannot remove that member."), updated
	end

	function GuildService:SetRole(player, profile, targetUserId: number, role: string)
		if role ~= "Officer" and role ~= "Member" then return false, "Invalid guild role." end
		local guildId = profile.Guild and profile.Guild.Id or ""
		local ok, message, updated = self:_update(guildId, function(guild)
			local actor, target = guild.Members[tostring(player.UserId)], guild.Members[tostring(targetUserId)]
			if player.UserId == targetUserId or not Social.canManage(actor,target,"Role") then return nil end
			target.Role = role
			return guild
		end)
		return ok, ok and "Role updated." or (message or "Only the leader can set roles."), updated
	end

	function GuildService:ContributeBank(player, profile, amount: number, currency: string)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "Join a guild before contributing." end
		local normalized, amountError = GuildMath.NormalizeContributionAmount(amount)
		if not normalized then
			return false, amountError or "Pick a positive contribution amount."
		end
		amount = normalized
		if currency ~= "Cash" and currency ~= "Dust" then
			return false, "Contribute flux or dust."
		end
		if currency == "Cash" then
			if OmegaMath.Lt(profile.Cash, amount) then
				return false, "You do not have enough currency."
			end
		else
			if (tonumber(profile.Stardust) or 0) < amount then
				return false, "You do not have enough currency."
			end
		end

		local ok, message, updated = self:_update(guildId, function(guild)
			local member = guild.Members[tostring(player.UserId)]
			if not member then return nil end
			local bankKey = currency == "Cash" and "BankCash" or "BankDust"
			guild[bankKey] = GuildMath.CreditBank(OmegaMath, currency, guild[bankKey], amount)
			guild.Activity = GuildMath.AddClamped(guild.Activity, amount)
			member.Contributed = GuildMath.AddClamped(member.Contributed, amount)
			if member.Name == nil or member.Name == "" then
				member.Name = (player.DisplayName ~= "" and player.DisplayName) or player.Name
			end
			advanceGoal(
				guild,
				tostring(player.UserId),
				currency == "Cash" and "ContributeCash" or "ContributeDust",
				amount,
				os.time()
			)
			return guild
		end)
		if not ok then return false, message or "You are not in that guild.", updated end
		if currency == "Cash" then
			profile.Cash = OmegaMath.Sub(profile.Cash, amount)
		else
			profile.Stardust -= amount
		end
		return true, "Contribution deposited.", updated
	end

	function GuildService:BuyUpgrade(player, profile, upgradeId: string)
		local definition = GameConfig.Guild.Upgrades[upgradeId]
		if not definition then return false, "Unknown guild upgrade." end
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "Join a guild first." end
		local guild = self:_read(guildId)
		if not guild then return false, "Guild records are unavailable." end
		local member = guild.Members[tostring(player.UserId)]
		if not member or (member.Role ~= "Leader" and member.Role ~= "Officer") then
			return false, "Only leaders and officers can buy hall upgrades."
		end
		local level = guild.Upgrades[upgradeId] or 0
		if level >= definition.MaxLevel then return false, "That upgrade is already maxed." end
		local cost = upgradeCost(definition, level)
		local bankKey = definition.Currency == "Cash" and "BankCash" or "BankDust"
		local bank = guild[bankKey] or 0
		if not GuildMath.CanAffordBank(OmegaMath, definition.Currency, bank, cost) then
			local label = definition.Currency == "Cash" and "flux" or "dust"
			local haveLabel = if definition.Currency == "Cash"
				then tostring(bank)
				else tostring(math.floor(tonumber(bank) or 0))
			return false, string.format("Need %d %s in the guild bank (have %s). Contribute first.", cost, label, haveLabel)
		end
		local ok, message, updated = self:_update(guildId, function(current)
			local actor = current.Members[tostring(player.UserId)]
			if not actor or (actor.Role ~= "Leader" and actor.Role ~= "Officer") then return nil end
			local nextLevel = current.Upgrades[upgradeId] or 0
			if nextLevel >= definition.MaxLevel then return nil end
			local nextCost = upgradeCost(definition, nextLevel)
			local nextBank = GuildMath.DebitBank(OmegaMath, definition.Currency, current[bankKey], nextCost)
			if nextBank == nil then return nil end
			current[bankKey] = nextBank
			current.Upgrades[upgradeId] = nextLevel + 1
			current.Activity = GuildMath.AddClamped(current.Activity, nextCost)
			advanceGoal(current, tostring(player.UserId), "Upgrades", 1, os.time())
			return current
		end)
		return ok, ok and "Guild upgrade installed." or (message or "Could not buy that upgrade."), updated
	end

	function GuildService:ClaimGoal(player, profile)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "Join a guild first." end
		local userKey = tostring(player.UserId)
		local failure = nil
		local rewardTypeId = nil
		local ok, message, updated = self:_update(guildId, function(guild)
			failure = nil
			rewardTypeId = nil
			local now = os.time()
			local repaired = ensureGoal(guild, now)
			local goal = guild.Goal
			local canClaim, claimError = GuildGoalMath.CanClaimGoal(
				goal,
				userKey,
				guild.Members[userKey] ~= nil,
				GameConfig.Guild.Goal.MinContributionForReward
			)
			if not canClaim then
				failure = claimError
				return if repaired then guild else nil
			end
			goal.Claimed[userKey] = true
			rewardTypeId = goal.TypeId
			return guild
		end)
		if not ok then return false, failure or message or "Could not claim the guild goal." end
		if failure then return false, failure, updated end
		local definition = rewardTypeId and goalTypeById(rewardTypeId) or nil
		if not definition then return false, "That guild goal is no longer available." end
		return true, "Guild goal reward claimed.", updated, definition.Reward
	end

	function GuildService:GetPublic(guildId: string)
		if guildId == "" then return nil end
		local doc = self:_read(guildId)
		if not doc then return nil end
		ensureGoal(doc, os.time())
		return doc
	end

	function GuildService:GetCachedPublic(guildId: string)
		if guildId == "" then return nil end
		local doc = self._cache[guildId] or (RunService:IsStudio() and self._studio[guildId] or nil)
		if type(doc) ~= "table" then
			doc = self:_read(guildId)
		end
		if type(doc) ~= "table" then return nil end
		local result = copy(doc)
		ensureGoal(result, os.time())
		return result
	end

	function GuildService:GetLeaderboard(page: number)
		local pageIndex = math.max(0, math.floor(tonumber(page) or 0))
		if pageIndex == 0 and self._leaderboardCache and self._leaderboardCacheExpires > os.clock() then
			return copy(self._leaderboardCache)
		end
		local entries = {}
		local hasPlaceholders = false
		local ok, pages = pcall(function() return self._leaderboard:GetSortedAsync(false, 100, nil, nil) end)
		if ok and pages then
			for _, row in pages:GetCurrentPage() do
				local doc = self._cache[row.key] or self._studio[row.key]
				if doc then
					table.insert(entries, { Id = doc.Id, Name = doc.Name, Tag = doc.Tag, Activity = LeaderboardCodec.Decode(row.value), Level = doc.Level })
				else
					hasPlaceholders = true
					self:_queueWarmRead(row.key)
					table.insert(entries, { Id = row.key, Name = "Uncharted Guild", Tag = "...", Activity = LeaderboardCodec.Decode(row.value), Level = 0 })
				end
			end
		end
		if #entries == 0 then
			for _, doc in self._cache do table.insert(entries, { Id = doc.Id, Name = doc.Name, Tag = doc.Tag, Activity = doc.Activity, Level = doc.Level }) end
			table.sort(entries, function(a, b) return a.Activity > b.Activity end)
		end
		local start = pageIndex * 20 + 1
		local sliced = {}
		for i = start, math.min(#entries, start + 19) do
			table.insert(sliced, entries[i])
		end
		if pageIndex == 0 then
			self._leaderboardCache = copy(sliced)
			self._leaderboardCacheExpires = os.clock() + (hasPlaceholders and 3 or 15)
		end
		return copy(sliced)
	end

	function GuildService:GetBonuses(guildId: string)
		return bonusesFromDocument(self:GetPublic(guildId))
	end

	function GuildService:GetCachedBonuses(guildId: string)
		return bonusesFromDocument(self:GetCachedPublic(guildId))
	end

	function GuildService:ReconcileMembership(profile, userId: number): boolean
		local membership = profile.Guild
		local guildId = membership and membership.Id or ""
		if guildId == "" then
			profile.GuildBonuses = emptyBonuses()
			return false
		end
		local guild = self:_read(guildId)
		if not guild then return false end
		local member = guild.Members[tostring(userId)]
		if not member then
			profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
			profile.GuildBonuses = emptyBonuses()
			return true
		end
		local changed = membership.Role ~= member.Role or membership.Tag ~= guild.Tag
		membership.Role = member.Role
		membership.Tag = guild.Tag
		profile.GuildBonuses = bonusesFromDocument(guild)
		return changed
	end

	return GuildService
end
end

__defs["LabService"] = function()

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local LabOrderMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("LabOrderMath"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

	local LabService = {}

	local orderById = {}
	for _, order in GameConfig.Lab.Orders do
		orderById[order.Id] = order
	end

	local channelOrder = LabOrderMath.CHANNEL_ORDER

	local function utcDay(): number
		return math.floor(os.time() / 86_400)
	end

	local function ensureLab(profile)
		profile.Lab = LabOrderMath.Ensure(profile.Lab, GameConfig.Lab.Power.BaseCells)
		return profile.Lab
	end

	local function totalCells(profile): number
		return LabOrderMath.TotalCells(
			profile.Rebirths,
			GameConfig.Lab.Power.BaseCells,
			GameConfig.Lab.Power.RebirthsPerCell,
			GameConfig.Lab.Power.MaxCells
		)
	end

	local function normalizeRouting(profile): boolean
		local lab = ensureLab(profile)
		return LabOrderMath.NormalizeRouting(lab.Routing, channelOrder, totalCells(profile))
	end

	local function orderTarget(profile, order): number
		local bankFluxTarget = nil
		if order.Kind == "BankFlux" then
			local steady = Economy.SteadyProduction(profile)
			bankFluxTarget = Economy.AsNumber(Economy.Mul(steady, order.ProductionSeconds))
		end
		return LabOrderMath.OrderTarget(order, math.max(0, profile.Rebirths), bankFluxTarget)
	end

	local function rollOrders(profile, day: number, userId: number)
		local available = table.create(#GameConfig.Lab.Orders)
		for index, definition in GameConfig.Lab.Orders do
			if definition.Kind ~= "UnlockWorld" or profile.Zone < GameConfig.MaxZone then
				table.insert(available, index)
			end
		end
		local seed = math.abs((day * 48_271 + userId * 69_621 + 17) % 2_147_483_647)
		local random = Random.new(seed)
		local rolled = {}
		for slot = 1, math.min(GameConfig.Lab.OrderCount, #available) do
			local pick = random:NextInteger(1, #available)
			local definition = GameConfig.Lab.Orders[available[pick]]
			table.remove(available, pick)
			rolled[slot] = {
				Id = definition.Id,
				Progress = 0,
				Target = orderTarget(profile, definition),
				Claimed = false,
			}
		end
		profile.Lab.Day = day
		profile.Lab.Orders = rolled
	end

	function LabService.Ensure(profile, userId: number): boolean
		local lab = ensureLab(profile)
		local changed = normalizeRouting(profile)
		local day = utcDay()
		if lab.Day ~= day then
			rollOrders(profile, day, userId)
			changed = true
		else
			local seen = {}
			local count = 0
			for index, state in lab.Orders do
				count += 1
				if
					type(index) ~= "number"
					or index ~= math.floor(index)
					or index < 1
					or index > GameConfig.Lab.OrderCount
					or type(state) ~= "table"
					or not orderById[state.Id]
					or seen[state.Id]
				then
					rollOrders(profile, day, userId)
					changed = true
					break
				end
				seen[state.Id] = true
			end
			if count ~= GameConfig.Lab.OrderCount then
				rollOrders(profile, day, userId)
				changed = true
			end
		end
		return changed
	end

	function LabService.Progress(profile, kind: string, amount: number): boolean
		local lab = ensureLab(profile)
		return LabOrderMath.ApplyProgress(lab.Orders, orderById, kind, amount)
	end

	function LabService.ClaimOrder(profile, orderId: string)
		local lab = ensureLab(profile)
		local orders = lab.Orders
		if type(orders) ~= "table" then
			return false, "That order is no longer on the board.", nil
		end
		local ok, message, reward = LabOrderMath.TryClaim(orders, orderById, orderId)
		if ok then
			if type(profile.Stats) ~= "table" then
				profile.Stats = { OrdersCompleted = 0 }
			end
			profile.Stats.OrdersCompleted =
				math.max(0, math.floor(tonumber(profile.Stats.OrdersCompleted) or 0)) + 1
		end
		return ok, message, reward
	end

	function LabService.RoutePower(profile, channelId: string, delta: number)
		if not GameConfig.Lab.Power.Channels[channelId] then
			return false, "That power rail does not exist."
		end
		if delta ~= -1 and delta ~= 1 then
			return false, "Move one cell at a time."
		end
		local lab = ensureLab(profile)
		normalizeRouting(profile)
		local total = totalCells(profile)
		local used = 0
		for _, id in channelOrder do
			used += lab.Routing[id]
		end
		local current = lab.Routing[channelId]
		if delta > 0 and used >= total then
			return false, "All cells are already assigned. Free one first."
		end
		if delta < 0 and current <= 0 then
			return false, "That rail is already empty."
		end
		lab.Routing[channelId] = current + delta
		if type(profile.Stats) ~= "table" then
			profile.Stats = { PowerMoves = 0 }
		end
		profile.Stats.PowerMoves = math.max(0, math.floor(tonumber(profile.Stats.PowerMoves) or 0)) + 1
		return true, delta > 0 and "Power cell assigned." or "Power cell returned."
	end

	function LabService.PowerEffect(profile, channelId: string): number
		local channel = GameConfig.Lab.Power.Channels[channelId]
		if not channel then
			return 0
		end
		local lab = ensureLab(profile)
		return math.max(0, lab.Routing[channelId] or 0) * channel.EffectPerCell
	end

	function LabService.State(profile)
		local lab = ensureLab(profile)
		local total = totalCells(profile)
		local used = 0
		local routing = {}
		local effects = {}
		for _, channelId in channelOrder do
			local raw = lab.Routing[channelId]
			local value = if type(raw) == "number" and raw == raw and raw ~= math.huge and raw ~= -math.huge
				then math.clamp(math.floor(raw), 0, math.max(0, total - used))
				else 0
			routing[channelId] = value
			local channel = GameConfig.Lab.Power.Channels[channelId]
			effects[channelId] = if channel then value * channel.EffectPerCell else 0
			used += value
		end
		local orders = table.create(#lab.Orders)
		for index, state in lab.Orders do
			orders[index] = {
				Id = state.Id,
				Progress = state.Progress,
				Target = state.Target,
				Claimed = state.Claimed,
			}
		end
		return {
			Day = lab.Day,
			ResetAt = (utcDay() + 1) * 86_400,
			Orders = orders,
			Routing = routing,
			Effects = effects,
			TotalCells = total,
			AvailableCells = math.max(0, total - used),
		}
	end

	return table.freeze(LabService)
end
end

__defs["ProgressionService"] = function()

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local Format = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("Format")
	local ForgePathClaim = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("ForgePathClaim")
	local WheelMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("WheelMath")
	local CommandMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CommandMath"))
	local ProfileBagMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileBagMath"))
	local ProgressionOpsMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("ProgressionOpsMath")
	local UtcClockMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("UtcClockMath")

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

	local function ensureStats(profile)
		return ProfileBagMath.EnsureStats(profile)
	end

	local function bumpStat(profile, key: string, amount: number?)
		return ProfileBagMath.BumpStat(profile, key, amount)
	end

	local function ensureItemKeys(profile)
		return ProfileBagMath.EnsureItemKeys(profile)
	end

	local function ensureDaily(profile)
		return ProfileBagMath.EnsureDaily(profile)
	end

	local function ensureQuests(profile)
		return ProfileBagMath.EnsureQuests(profile)
	end

	local function ensureTimedRewardsBag(profile)
		return ProfileBagMath.EnsureTimedRewards(profile)
	end

	local function ensureWheel(profile)
		profile.Wheel = WheelMath.Ensure(profile.Wheel)
		return profile.Wheel
	end

	local function awardCommandXP(profile, amount: number)
		local command = ensureCommand(profile)
		ProgressionOpsMath.ApplyCommandXP(
			command,
			amount,
			Economy.DomainTreeBonus(profile, "CommandXP")
		)
	end

	ProgressionService.AwardCommandXP = awardCommandXP

	local function findOperation(list, id: string)
		return ProgressionOpsMath.FindById(list, id)
	end

	local function currentWeeklyValue(profile, kind: string): number
		local value = ProgressionOpsMath.WeeklyValue(profile, kind)
		if type(value) ~= "number" or value ~= value then
			return 0
		end
		return math.clamp(value, -1e308, 1e308)
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
		for _, currency in { "Stardust", "Cores" } do
			local amount = reward[currency]
			if type(amount) == "number" and amount > 0 then
				local balance = tonumber(profile[currency]) or 0
				local credited = balance + amount
				if credited <= balance or credited >= math.huge then
					error("Your " .. currency:lower() .. " balance cannot represent this reward. The claim has not been granted.")
				end
			end
		end
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
		local earnTarget = math.floor(math.min(1e300, math.max(2_000, Economy.AsNumber(Economy.Mul(production, 8 * 60)) * scale)))
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
				local existing = command.Weekly.Baseline[directive.Kind]
				if existing == nil or existing ~= existing or existing == math.huge or existing == -math.huge then
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

	function ProgressionService.BuyArtifact(profile, artifactId: string): (boolean, string, boolean?)
		local artifact = findOperation(GameConfig.Operations.Artifacts, artifactId)
		local price = artifact and GameConfig.Operations.ArtifactShop[artifact.Rarity]
		if not artifact or not price then
			return false, "That artifact is not sold here."
		end
		local owned = profile.Command.Artifacts[artifactId]
		local cost = if owned then price.Refill else price.Stardust
		if Economy.Lt(profile.Stardust, cost) then
			return false, string.format("Requires %d stardust.", cost)
		end
		profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, cost))
		if owned then
			owned.Fragments += price.Fragments
			return true, string.format("+%d %s fragments.", price.Fragments, artifact.Name), false
		end
		profile.Command.Artifacts[artifactId] = { Level = 1, Fragments = 0 }
		bumpStat(profile, "ArtifactsFound", 1)
		return true, artifact.Name .. " acquired.", true
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
		if type(rawLevel) ~= "number" or rawLevel ~= rawLevel or math.abs(rawLevel) == math.huge then
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
			profile.ForgePath.XPEarnedToday = ProfileBagMath.AddFinite(earned, value)
		end
		profile.ForgePath.XP = ProfileBagMath.AddFinite(profile.ForgePath.XP, value)
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

	function ProgressionService.SpinWheel(profile, random: Random, expectedSpin: number?): (boolean, string, number?, string?, boolean?)
		local now = os.time()
		local wheel = ensureWheel(profile)
		if expectedSpin ~= nil then
			if not WheelMath.ValidExpectedSpin(expectedSpin) then return false, "Refresh the wheel before spinning." end
			local receipt = wheel.LastReceipt
			if receipt and receipt.ExpectedSpin == expectedSpin then
				return true, receipt.Message, receipt.PrizeIndex, receipt.PrizeId, receipt.Pity
			end
			if expectedSpin ~= wheel.Spins then return false, "That spin is already resolved. Refresh to see your latest result." end
		end
		if not WheelMath.ValidExpectedSpin(wheel.Spins) then return false, "Your spin counter needs support review." end
		local sequence = wheel.Spins
		local freeSpins = wheel.FreeSpins
		local onCooldown = now < wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds
		if freeSpins <= 0 and onCooldown then
			return false, "Your next free wheel spin is not ready yet."
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
			return false, "The wheel has no prizes configured."
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
		ensureWheel(profile).LastReceipt = {
			ExpectedSpin = sequence, PrizeIndex = selectedIndex, PrizeId = selected.Id, Message = label, Pity = pityHit,
		}
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
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
