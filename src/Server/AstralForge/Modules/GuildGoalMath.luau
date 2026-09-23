--!strict
-- Pure guild co-op goal roll / ensure / advance / claim-readiness helpers. No
-- Roblox services — GuildService and Lune verify scripts share this so rotating
-- goals stay testable without Studio. Datastore writes and reward application
-- stay with the caller; Goal config is injected. Mirrors GuildMath finite /
-- GoalTarget / AddClamped so this module stays require-free under Lune.

local GuildGoalMath = {}

local MAX_NUMBER = 1e308

export type GoalType = {
	Id: string,
	Metric: string,
	BaseTarget: number,
	TargetPerMember: number,
	Reward: any?,
	Name: string?,
	Description: string?,
}

export type GoalConfig = {
	DurationSeconds: number,
	MinContributionForReward: number?,
	Types: { GoalType },
}

export type GoalState = {
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

-- Deterministic rotation so every server that touches this guild picks the same
-- next goal rather than racing on math.random.
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

-- Mutates `guild` in place. Returns true when the goal was created, rotated, or
-- when nested Claimed/Contributors bags were rebuilt — callers inside UpdateAsync
-- must persist those repairs (evidence: ClaimGoal early-return used to drop a
-- rebuilt Claimed table when the goal was not yet Completed).
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
	-- tonumber so Studio fixtures with string Target/Progress coerce (same class
	-- as ConvergenceOpsMath Contribution coercion) instead of collapsing to 0.
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
	-- Mid-migrate / Studio fixtures may keep TypeId-matched goals with nil Claimed
	-- or Contributors — ClaimGoal indexes Claimed[userKey] and Contributors[userKey].
	if type(goal.Contributors) ~= "table" then
		goal.Contributors = {}
		changed = true
	end
	if type(goal.Claimed) ~= "table" then
		goal.Claimed = {}
		changed = true
	end
	-- An expired window rotates. A completed goal stays put until its window ends
	-- so members who were offline still get a chance to claim.
	if safeNow >= goal.EndsAt then
		guild.Goal = GuildGoalMath.RollGoal(guild, safeNow, goalConfig)
		return true
	end
	return changed
end

-- Records progress toward the live goal from a member action. `metric` must match
-- the goal type's Metric or the action simply does not count.
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

-- Claim readiness shared by ClaimGoal. Returns ok + optional reason.
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
