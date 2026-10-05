--!strict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then
		return hit.value
	end
	local def = __defs[name]
	if def == nil then
		error("OpsMath: unknown module " .. tostring(name), 2)
	end
	if __loading[name] then
		error("OpsMath: cyclic require of member " .. name, 2)
	end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then
		error(value, 0)
	end
	__cache[name] = { value = value }
	return value
end

__defs["GuildGoalMath"] = function()
	local GuildGoalMath = {}

	local MAX_NUMBER = 1e308

	type GoalType = {
		Id: string,
		Metric: string,
		BaseTarget: number,
		TargetPerMember: number,
		Reward: any?,
		Name: string?,
		Description: string?,
	}

	type GoalConfig = {
		DurationSeconds: number,
		MinContributionForReward: number?,
		Types: { GoalType },
	}

	type GoalState = {
		TypeId: string,
		Target: number,
		Progress: number,
		StartedAt: number,
		EndsAt: number,
		Completed: boolean,
		CompletedAt: number,
		Contributors: { [string]: number },
		Claimed: { [string]: any },
	}

	local function finiteNonNegative(value: any): number
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return math.clamp(value, 0, MAX_NUMBER)
	end

	local function goalTarget(baseTarget: number, targetPerMember: number, members: number): number
		return math.max(1, math.floor(baseTarget + targetPerMember * math.max(0, members - 1) + 0.5))
	end

	local function addClamped(current: any, amount: number): number
		return math.min(MAX_NUMBER, finiteNonNegative(current) + amount)
	end

	function GuildGoalMath.GoalTypeById(types: any, typeId: string): GoalType?
		if type(types) ~= "table" or type(typeId) ~= "string" or typeId == "" then
			return nil
		end
		for _, entry in types do
			if type(entry) == "table" and entry.Id == typeId then
				return entry :: GoalType
			end
		end
		return nil
	end

	function GuildGoalMath.MemberCount(guild: any): number
		local count = 0
		if type(guild) == "table" and type(guild.Members) == "table" then
			for _ in guild.Members do
				count += 1
			end
		end
		return count
	end

	function GuildGoalMath.RollGoal(guild: any, now: number, goalConfig: GoalConfig): GoalState
		local types = goalConfig.Types
		local previous = type(guild) == "table" and type(guild.Goal) == "table" and guild.Goal.TypeId or nil
		local index = 1
		local duration = math.max(1, math.floor(tonumber(goalConfig.DurationSeconds) or 1))
		local safeNow = math.max(0, math.floor(tonumber(now) or 0))
		if type(types) ~= "table" or #types < 1 then
			return {
				TypeId = "",
				Target = 1,
				Progress = 0,
				StartedAt = safeNow,
				EndsAt = safeNow + duration,
				Completed = false,
				CompletedAt = 0,
				Contributors = {},
				Claimed = {},
			}
		end
		if previous then
			for position, entry in types do
				if type(entry) == "table" and entry.Id == previous then
					index = position % #types + 1
					break
				end
			end
		else
			index = (math.floor(safeNow / duration) % #types) + 1
		end
		local definition = types[index]
		local target = goalTarget(
			tonumber(definition.BaseTarget) or 1,
			tonumber(definition.TargetPerMember) or 0,
			GuildGoalMath.MemberCount(guild)
		)
		return {
			TypeId = definition.Id,
			Target = target,
			Progress = 0,
			StartedAt = safeNow,
			EndsAt = safeNow + duration,
			Completed = false,
			CompletedAt = 0,
			Contributors = {},
			Claimed = {},
		}
	end

	function GuildGoalMath.EnsureGoal(guild: any, now: number, goalConfig: GoalConfig): boolean
		if type(guild) ~= "table" then
			return false
		end
		local safeNow = math.max(0, math.floor(tonumber(now) or 0))
		local goal = guild.Goal
		local types = goalConfig and goalConfig.Types
		if type(goal) ~= "table" or GuildGoalMath.GoalTypeById(types, goal.TypeId or "") == nil then
			guild.Goal = GuildGoalMath.RollGoal(guild, safeNow, goalConfig)
			return true
		end
		local changed = false
		local nextTarget = math.max(1, finiteNonNegative(tonumber(goal.Target)))
		local nextProgress = finiteNonNegative(tonumber(goal.Progress))
		local nextEndsAt = finiteNonNegative(tonumber(goal.EndsAt))
		local nextCompletedAt = finiteNonNegative(tonumber(goal.CompletedAt))
		local nextCompleted = goal.Completed == true
		if goal.Target ~= nextTarget then
			goal.Target = nextTarget
			changed = true
		end
		if goal.Progress ~= nextProgress then
			goal.Progress = nextProgress
			changed = true
		end
		if goal.EndsAt ~= nextEndsAt then
			goal.EndsAt = nextEndsAt
			changed = true
		end
		if goal.Completed ~= nextCompleted then
			goal.Completed = nextCompleted
			changed = true
		end
		if goal.CompletedAt ~= nextCompletedAt then
			goal.CompletedAt = nextCompletedAt
			changed = true
		end
		if type(goal.Contributors) ~= "table" then
			goal.Contributors = {}
			changed = true
		end
		if type(goal.Claimed) ~= "table" then
			goal.Claimed = {}
			changed = true
		end
		if safeNow >= goal.EndsAt then
			guild.Goal = GuildGoalMath.RollGoal(guild, safeNow, goalConfig)
			return true
		end
		return changed
	end

	function GuildGoalMath.AdvanceGoal(
		guild: any,
		userKey: string,
		metric: string,
		amount: number,
		now: number,
		goalConfig: GoalConfig
	)
		GuildGoalMath.EnsureGoal(guild, now, goalConfig)
		local goal = guild.Goal
		if type(goal) ~= "table" or goal.Completed then
			return
		end
		local definition = GuildGoalMath.GoalTypeById(goalConfig.Types, goal.TypeId)
		if not definition or definition.Metric ~= metric then
			return
		end
		local gain = finiteNonNegative(amount)
		if gain <= 0 then
			return
		end
		goal.Progress = addClamped(goal.Progress, gain)
		goal.Contributors[userKey] = addClamped(goal.Contributors[userKey], gain)
		if goal.Progress >= goal.Target then
			goal.Completed = true
			goal.CompletedAt = math.max(0, math.floor(tonumber(now) or 0))
		end
	end

	function GuildGoalMath.CanClaimGoal(
		goal: any,
		userKey: string,
		isMember: boolean,
		minContribution: number
	): (boolean, string?)
		if not isMember then
			return false, "You are not in that guild."
		end
		if type(goal) ~= "table" then
			return false, "The guild goal is not finished yet."
		end
		if goal.Completed ~= true then
			return false, "The guild goal is not finished yet."
		end
		local claimed = type(goal.Claimed) == "table" and goal.Claimed or nil
		if claimed and claimed[userKey] then
			return false, "You already claimed this goal."
		end
		local contributors = type(goal.Contributors) == "table" and goal.Contributors or nil
		local contributed = finiteNonNegative(contributors and contributors[userKey])
		local min = math.max(0, tonumber(minContribution) or 0)
		if contributed < min then
			return false, "Only members who helped with this goal can claim it."
		end
		return true, nil
	end

	return table.freeze(GuildGoalMath)
end

__defs["GuildMath"] = function()
	local GuildMath = {}

	GuildMath.MAX_NUMBER = 1e308
	GuildMath.BONUS_KEYS = { "Production", "Capacity", "Offline", "Automation", "Tap" }

	type UpgradeDefinition = {
		BaseCost: number,
		CostScale: number,
		EffectPerLevel: number,
		MaxLevel: number?,
		Currency: string?,
		Bonus: string?,
		Tiers: { { Name: string?, Effect: number?, Cost: number? } }?,
	}

	function GuildMath.FiniteNonNegative(value: any): number
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return 0
		end
		return math.clamp(value, 0, GuildMath.MAX_NUMBER)
	end

	function GuildMath.UpgradeTier(definition: UpgradeDefinition, level: number): any
		local tiers = definition.Tiers
		if type(tiers) ~= "table" then
			return nil
		end
		if level < 1 or level > #tiers then
			return nil
		end
		return tiers[level]
	end

	function GuildMath.UpgradeCost(definition: UpgradeDefinition, level: number): number
		local tier = GuildMath.UpgradeTier(definition, level + 1)
		if tier and type(tier.Cost) == "number" then
			return math.floor(tier.Cost + 0.5)
		end
		return math.floor(definition.BaseCost * definition.CostScale ^ math.max(0, level) + 0.5)
	end

	function GuildMath.UpgradeEffect(definition: UpgradeDefinition, level: number): number
		local safeLevel = math.max(0, math.floor(level))
		if safeLevel <= 0 then
			return 0
		end
		local tiers = definition.Tiers
		if type(tiers) ~= "table" then
			return safeLevel * definition.EffectPerLevel
		end
		local total = 0
		local named = math.min(safeLevel, #tiers)
		for index = 1, named do
			local tier = tiers[index]
			total += (type(tier) == "table" and type(tier.Effect) == "number") and tier.Effect or 0
		end
		if safeLevel > named then
			total += (safeLevel - named) * definition.EffectPerLevel
		end
		return total
	end

	function GuildMath.EmptyBonuses(): { [string]: number }
		local result = {}
		for _, key in GuildMath.BONUS_KEYS do
			result[key] = 0
		end
		return result
	end

	function GuildMath.BonusesFromUpgrades(
		upgrades: { [string]: any }?,
		upgradeDefs: { [string]: UpgradeDefinition }
	): { [string]: number }
		local result = GuildMath.EmptyBonuses()
		if type(upgrades) ~= "table" then
			return result
		end
		for id, level in upgrades do
			local definition = upgradeDefs[id]
			if definition and type(level) == "number" then
				local key = definition.Bonus
				if key ~= nil and result[key] ~= nil then
					result[key] = math.min(1, result[key] + GuildMath.UpgradeEffect(definition, level))
				end
			end
		end
		return result
	end

	function GuildMath.GoalTarget(baseTarget: number, targetPerMember: number, members: number): number
		return math.max(1, math.floor(baseTarget + targetPerMember * math.max(0, members - 1) + 0.5))
	end

	function GuildMath.NormalizeContributionAmount(amount: any): (number?, string?)
		if
			type(amount) ~= "number"
			or amount ~= amount
			or amount == math.huge
			or amount == -math.huge
			or amount < 1
			or amount > GuildMath.MAX_NUMBER
		then
			return nil, "Pick a positive contribution amount."
		end
		return math.floor(amount), nil
	end

	function GuildMath.CanAffordBank(omegaMath: any, currency: string, bank: any, cost: number): boolean
		if currency == "Cash" then
			return not omegaMath.Lt(bank or 0, cost)
		end
		return (tonumber(bank) or 0) >= cost
	end

	function GuildMath.CreditBank(omegaMath: any, currency: string, bank: any, amount: number): any
		if currency == "Cash" then
			return omegaMath.Add(bank or 0, amount)
		end
		return math.min(GuildMath.MAX_NUMBER, GuildMath.FiniteNonNegative(bank) + amount)
	end

	function GuildMath.DebitBank(omegaMath: any, currency: string, bank: any, cost: number): any?
		if not GuildMath.CanAffordBank(omegaMath, currency, bank, cost) then
			return nil
		end
		if currency == "Cash" then
			return omegaMath.Sub(bank or 0, cost)
		end
		return (tonumber(bank) or 0) - cost
	end

	function GuildMath.AddClamped(current: any, amount: number): number
		return math.min(GuildMath.MAX_NUMBER, GuildMath.FiniteNonNegative(current) + amount)
	end

	function GuildMath.EmptyHall(membership: any)
		local tag = type(membership) == "table" and type(membership.Tag) == "string" and membership.Tag or ""
		local guildId = type(membership) == "table" and membership.Id or ""
		return {
			Id = guildId,
			Name = "Guild Hall",
			Tag = tag,
			Level = 1,
			XP = 0,
			Activity = 0,
			BankCash = 0,
			BankDust = 0,
			Members = {},
			Upgrades = {},
			CreatedAt = 0,
			OwnerUserId = 0,
		}
	end

	function GuildMath.SnapshotPublic(membership: any, publicGuild: any): any
		local guildId = type(membership) == "table" and membership.Id or ""
		if guildId == "" then
			return nil
		end
		if publicGuild ~= nil then
			return publicGuild
		end
		return GuildMath.EmptyHall(membership)
	end

	return table.freeze(GuildMath)
end

__defs["AdminGrantMath"] = function()
	local AdminGrantMath = {}

	AdminGrantMath.DEFAULT_MAX_GRANT = 1e308

	function AdminGrantMath.Finite(value: any): boolean
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	function AdminGrantMath.BoundedAmount(raw: any, fallback: number?, maxGrant: number?): number?
		local ceiling = tonumber(maxGrant) or AdminGrantMath.DEFAULT_MAX_GRANT
		local value = if type(raw) == "string" then tonumber(raw) else raw
		if value == nil and fallback ~= nil then
			value = fallback
		end
		if not AdminGrantMath.Finite(value) or (value :: number) <= 0 then
			return nil
		end
		return math.clamp(value :: number, 1, ceiling)
	end

	function AdminGrantMath.CleanText(raw: any, maximum: number): string
		if type(raw) ~= "string" then
			return ""
		end
		local cap = math.max(0, math.floor(tonumber(maximum) or 0))
		local value = string.gsub(raw, "[%c]", " ")
		value = string.gsub(value, "^%s+", "")
		value = string.gsub(value, "%s+$", "")
		return string.sub(value, 1, cap)
	end

	function AdminGrantMath.CommandDanger(definition: { [string]: any }?): string
		if type(definition) ~= "table" then
			return "quick"
		end
		if type(definition.Danger) == "string" and definition.Danger ~= "" then
			return definition.Danger
		end
		local category = definition.Category or "Economy"
		if category == "Troll" or category == "Resets" or category == "Moderation" then
			return "arm"
		end
		return "quick"
	end

	AdminGrantMath.AUDIT_ONLY_REASONS = table.freeze({
		["Owner gameplay administration"] = true,
		["Balance correction"] = true,
		["Playtest grant"] = true,
		["Troll / joke"] = true,
		["Moderation action"] = true,
		["Player request"] = true,
		["Bug recovery"] = true,
		["Trade settle recovery"] = true,
	})

	function AdminGrantMath.PlayerFacingReason(command: any, reason: any, auditOnly: { [string]: boolean }?): string
		local safeReason = if type(reason) == "string" then reason else ""
		local blocked = auditOnly or AdminGrantMath.AUDIT_ONLY_REASONS
		if safeReason ~= "" and blocked[safeReason] ~= true then
			return safeReason
		end
		if command == "ServerBan" then
			return "You are banned from this Astral Forge server."
		end
		if command == "GlobalBan" then
			return "You are banned from Astral Forge."
		end
		return "You were kicked from this Astral Forge server by an administrator."
	end

	function AdminGrantMath.NextRelicUid(inventory: any, nextId: any): (string?, number)
		local bag = if type(inventory) == "table" then inventory else {}
		local cursor = math.max(1, math.floor(tonumber(nextId) or 1))
		for _ = 1, 64 do
			local uid = string.format("IT%07d", cursor)
			cursor += 1
			if bag[uid] == nil then
				return uid, cursor
			end
		end
		return nil, cursor
	end

	function AdminGrantMath.BuildRelicInstance(definitionId: any, acquiredAt: any): { [string]: any }?
		if type(definitionId) ~= "string" or definitionId == "" then
			return nil
		end
		return {
			DefinitionId = definitionId,
			Level = 1,
			AcquiredAt = math.max(0, math.floor(tonumber(acquiredAt) or 0)),
		}
	end

	return table.freeze(AdminGrantMath)
end

__defs["AnomalyPulseScore"] = function()
	local AnomalyPulseScore = {}

	function AnomalyPulseScore.Elapsed(now: number, startedAt: number, period: number): number
		return (now - startedAt) % period
	end

	function AnomalyPulseScore.Fraction(now: number, startedAt: number, period: number): number
		local safePeriod = math.max(0.1, period)
		return AnomalyPulseScore.Elapsed(now, startedAt, safePeriod) / safePeriod
	end

	function AnomalyPulseScore.IsAccurate(
		now: number,
		startedAt: any,
		period: number,
		sweetZoneFraction: number
	): boolean
		if type(startedAt) ~= "number" or startedAt <= 0 then
			return false
		end
		local elapsed = AnomalyPulseScore.Elapsed(now, startedAt, period)
		local sweetZone = period * sweetZoneFraction
		return elapsed >= period - sweetZone
	end

	function AnomalyPulseScore.NextCombo(currentCombo: number?, accurate: boolean, comboMax: number): number
		if not accurate then
			return 0
		end
		return math.min(comboMax, (currentCombo or 0) + 1)
	end

	function AnomalyPulseScore.NextBestCombo(bestCombo: number?, combo: number): number
		return math.max(bestCombo or 0, combo)
	end

	function AnomalyPulseScore.ComboBonus(combo: number, bonusPerStack: number): number
		return 1 + math.min(1, combo * bonusPerStack)
	end

	function AnomalyPulseScore.AccuracyBonus(accurate: boolean, accurateBonus: number): number
		if accurate then
			return 1 + accurateBonus
		end
		return 1
	end

	function AnomalyPulseScore.ScoreMultiplier(
		combo: number,
		accurate: boolean,
		bonusPerStack: number,
		accurateBonus: number
	): number
		return AnomalyPulseScore.ComboBonus(combo, bonusPerStack)
			* AnomalyPulseScore.AccuracyBonus(accurate, accurateBonus)
	end

	return table.freeze(AnomalyPulseScore)
end

__defs["ConvergenceOpsMath"] = function()
	local ConvergenceOpsMath = {}

	type EventProfile = {
		EventId: string,
		Contribution: number,
		Claimed: { [string]: any },
	}

	type GlobalPhase = {
		Target: number,
		Name: string,
		ProductionMultiplier: number,
	}

	function ConvergenceOpsMath.EnsureEventProfile(profile: any, eventId: string): EventProfile
		if type(profile.LiveOps) ~= "table" then
			profile.LiveOps = {}
		end
		local current = profile.LiveOps.Convergence
		if type(current) ~= "table" or current.EventId ~= eventId then
			current = { EventId = eventId, Contribution = 0, Claimed = {} }
			profile.LiveOps.Convergence = current
		end
		current.Claimed = type(current.Claimed) == "table" and current.Claimed or {}
		current.Contribution = math.max(0, tonumber(current.Contribution) or 0)
		if type(current.EventId) ~= "string" then
			current.EventId = eventId
		end
		return current :: EventProfile
	end

	function ConvergenceOpsMath.ReadEventProfile(profile: any, eventId: string): EventProfile
		local liveOps = type(profile) == "table" and type(profile.LiveOps) == "table" and profile.LiveOps or nil
		local current = liveOps and liveOps.Convergence or nil
		if type(current) ~= "table" or current.EventId ~= eventId then
			return { EventId = eventId, Contribution = 0, Claimed = {} }
		end
		return {
			EventId = eventId,
			Contribution = math.max(0, tonumber(current.Contribution) or 0),
			Claimed = type(current.Claimed) == "table" and current.Claimed or {},
		}
	end

	function ConvergenceOpsMath.EnsureRewardBags(profile: any)
		if type(profile.Stats) ~= "table" then
			profile.Stats = {}
		end
		if type(profile.Command) ~= "table" then
			profile.Command = { Signals = 0 }
		end
		if type(profile.BoostInventory) ~= "table" then
			profile.BoostInventory = {}
		end
	end

	function ConvergenceOpsMath.ProductionMultiplier(total: number, phases: { GlobalPhase }): number
		local multiplier = 1
		local safeTotal = math.max(0, tonumber(total) or 0)
		if type(phases) ~= "table" then
			return multiplier
		end
		for _, phase in phases do
			local target = tonumber(phase.Target) or 0
			local mult = tonumber(phase.ProductionMultiplier) or 1
			if safeTotal >= target then
				multiplier = mult
			else
				break
			end
		end
		return multiplier
	end

	function ConvergenceOpsMath.PhaseState(total: number, phases: { GlobalPhase }): (number, string, number)
		local safeTotal = math.max(0, tonumber(total) or 0)
		local phaseIndex, phaseName = 0, "HEATING"
		local nextTarget = 0
		if type(phases) == "table" and phases[1] then
			nextTarget = tonumber(phases[1].Target) or 0
		end
		if type(phases) ~= "table" then
			return phaseIndex, phaseName, nextTarget
		end
		for index, phase in phases do
			local target = tonumber(phase.Target) or 0
			if safeTotal >= target then
				phaseIndex = index
				phaseName = if type(phase.Name) == "string" then phase.Name else phaseName
				local following = phases[index + 1]
				nextTarget = if following then (tonumber(following.Target) or target) else target
			else
				nextTarget = target
				break
			end
		end
		return phaseIndex, phaseName, nextTarget
	end

	function ConvergenceOpsMath.CanClaimTier(
		contribution: number,
		required: number,
		claimed: { [string]: any }?,
		tierIndex: number
	): boolean
		local key = tostring(tierIndex)
		local already = type(claimed) == "table" and claimed[key] == true
		return not already and math.max(0, tonumber(contribution) or 0) >= math.max(0, tonumber(required) or 0)
	end

	return table.freeze(ConvergenceOpsMath)
end

__defs["RemoteFirewallMath"] = function()
	local RemoteFirewallMath = {}

	RemoteFirewallMath.MAX_SAFE_USER_ID = 9007199254740991
	RemoteFirewallMath.MIN_SAFE_USER_ID = -9007199254740991

	RemoteFirewallMath.COOLDOWN_KEY_FIELDS = table.freeze({
		"Id",
		"Key",
		"Index",
		"Code",
		"Channel",
		"Target",
		"Uid",
		"ChoiceId",
		"Slot",
		"Tier",
		"Level",
		"Role",
		"UserId",
		"MachineId",
	})

	function RemoteFirewallMath.Integer(value: any): boolean
		return type(value) == "number" and value == math.floor(value)
	end

	function RemoteFirewallMath.SafeNumber(value: any): boolean
		return type(value) == "number"
			and value == value
			and value ~= math.huge
			and value ~= -math.huge
			and math.abs(value) <= RemoteFirewallMath.MAX_SAFE_USER_ID
	end

	function RemoteFirewallMath.CoerceUserId(raw: any, studio: boolean?): number?
		local value = raw
		if type(value) == "string" then
			local trimmed = string.match(value, "^%s*(%-?%d+)%s*$")
			if not trimmed then
				return nil
			end
			value = tonumber(trimmed)
		end
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		local rounded = if value >= 0 then math.floor(value + 0.5) else math.ceil(value - 0.5)
		if math.abs(value - rounded) > 1e-6 then
			return nil
		end
		if rounded == 0 then
			return nil
		end
		if rounded < RemoteFirewallMath.MIN_SAFE_USER_ID or rounded > RemoteFirewallMath.MAX_SAFE_USER_ID then
			return nil
		end
		if studio ~= true and rounded < 1 then
			return nil
		end
		return rounded
	end

	function RemoteFirewallMath.ExtractUserId(payload: any): any
		if payload == nil then
			return nil
		end
		if type(payload) == "number" or type(payload) == "string" then
			return payload
		end
		if type(payload) ~= "table" then
			return nil
		end
		local raw = payload.UserId
		if raw == nil then
			raw = payload.userId
		end
		if raw == nil then
			raw = payload.Id
		end
		if raw == nil then
			raw = payload.TargetUserId
		end
		return raw
	end

	function RemoteFirewallMath.CooldownKey(action: string, payload: any, fields: { string }?): string
		if type(payload) ~= "table" then
			return action
		end
		local keyFields = fields or RemoteFirewallMath.COOLDOWN_KEY_FIELDS
		local parts = table.create(#keyFields)
		for _, field in keyFields do
			local value = payload[field]
			if value ~= nil then
				table.insert(parts, field .. "=" .. tostring(value))
			end
		end
		if #parts == 0 then
			return action
		end
		return action .. ":" .. table.concat(parts, "|")
	end

	function RemoteFirewallMath.StringField(
		payload: { [any]: any },
		key: string,
		minimum: number,
		maximum: number
	): boolean
		local value = payload[key]
		return type(value) == "string" and value:len() >= minimum and value:len() <= maximum
	end

	function RemoteFirewallMath.StringArrayField(
		payload: { [any]: any },
		key: string,
		maxEntries: number,
		entryMinLen: number,
		entryMaxLen: number
	): boolean
		local value = payload[key]
		if type(value) ~= "table" then
			return false
		end
		local count = 0
		for _, entry in value do
			count += 1
			if count > maxEntries then
				return false
			end
			if type(entry) ~= "string" or entry:len() < entryMinLen or entry:len() > entryMaxLen then
				return false
			end
		end
		return true
	end

	function RemoteFirewallMath.NumberField(
		payload: { [any]: any },
		key: string,
		minimum: number,
		maximum: number,
		mustBeInteger: boolean?
	): boolean
		local value = payload[key]
		return RemoteFirewallMath.SafeNumber(value)
			and (not mustBeInteger or RemoteFirewallMath.Integer(value))
			and value >= minimum
			and value <= maximum
	end

	RemoteFirewallMath.INSPECT_MAX_DEPTH = 3
	RemoteFirewallMath.INSPECT_MAX_ENTRIES = 32
	RemoteFirewallMath.INSPECT_MAX_STRING = 600
	RemoteFirewallMath.INSPECT_MAX_KEY_LEN = 64
	RemoteFirewallMath.INSPECT_MAX_INDEX = 10000

	function RemoteFirewallMath.Inspect(
		value: any,
		depth: number?,
		seen: { [any]: boolean }?,
		budget: { Value: number }?
	): (boolean, string?)
		local nest = math.max(0, math.floor(tonumber(depth) or 0))
		local visited = seen or {}
		local entries = budget or { Value = 0 }
		local valueType = type(value)
		if value == nil or valueType == "boolean" then
			return true
		end
		if valueType == "number" then
			return RemoteFirewallMath.SafeNumber(value), "number is outside the safe range"
		end
		if valueType == "string" then
			return value:len() <= RemoteFirewallMath.INSPECT_MAX_STRING, "string is too long"
		end
		if valueType ~= "table" then
			return false, "payload contains an unsupported value"
		end
		if nest > RemoteFirewallMath.INSPECT_MAX_DEPTH then
			return false, "payload nesting is too deep"
		end
		if visited[value] then
			return false, "payload contains a cycle"
		end
		visited[value] = true
		for key, child in value do
			entries.Value += 1
			if entries.Value > RemoteFirewallMath.INSPECT_MAX_ENTRIES then
				visited[value] = nil
				return false, "payload is too large"
			end
			local keyType = type(key)
			if keyType ~= "string" and keyType ~= "number" then
				visited[value] = nil
				return false, "payload keys must be strings or numbers"
			end
			if keyType == "string" and key:len() > RemoteFirewallMath.INSPECT_MAX_KEY_LEN then
				visited[value] = nil
				return false, "payload key is too long"
			end
			if
				keyType == "number"
				and (
					not RemoteFirewallMath.SafeNumber(key)
					or not RemoteFirewallMath.Integer(key)
					or math.abs(key) > RemoteFirewallMath.INSPECT_MAX_INDEX
				)
			then
				visited[value] = nil
				return false, "payload index is outside the safe range"
			end
			local ok, reason = RemoteFirewallMath.Inspect(child, nest + 1, visited, entries)
			if not ok then
				visited[value] = nil
				return false, reason
			end
		end
		visited[value] = nil
		return true
	end

	RemoteFirewallMath.SESSION_KEYS = table.freeze({
		Gen = true,
		N = true,
		Auth = true,
		Txn = true,
		TxnId = true,
	})

	function RemoteFirewallMath.IsSessionOnlyPayload(payload: any, sessionKeys: { [string]: boolean }?): boolean
		if type(payload) ~= "table" then
			return false
		end
		local allowed = sessionKeys or RemoteFirewallMath.SESSION_KEYS
		for key in payload do
			if allowed[key] ~= true then
				return false
			end
		end
		return true
	end

	return table.freeze(RemoteFirewallMath)
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
