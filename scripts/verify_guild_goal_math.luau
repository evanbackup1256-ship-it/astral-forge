--!strict
-- Pure-module extract guards: GuildGoalMath (roll / ensure / advance / claim).
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local GuildGoalMath = require("../src/Server/AstralForge/Modules/GuildGoalMath")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label)
end

local goalConfig = {
	DurationSeconds = 100,
	MinContributionForReward = 1,
	Types = {
		{
			Id = "BankFlux",
			Metric = "ContributeCash",
			BaseTarget = 100,
			TargetPerMember = 50,
			Reward = { Stardust = 1 },
		},
		{
			Id = "BankDust",
			Metric = "ContributeDust",
			BaseTarget = 10,
			TargetPerMember = 5,
			Reward = { Stardust = 2 },
		},
		{
			Id = "HallWorks",
			Metric = "Upgrades",
			BaseTarget = 4,
			TargetPerMember = 1,
			Reward = { Stardust = 3 },
		},
	},
}

------------------------------------------------------------------------
-- GoalTypeById / MemberCount
------------------------------------------------------------------------
assert(GuildGoalMath.GoalTypeById(goalConfig.Types, "BankDust").Metric == "ContributeDust", "GoalTypeById")
assert(GuildGoalMath.GoalTypeById(goalConfig.Types, "missing") == nil, "unknown type")
assert(GuildGoalMath.GoalTypeById(nil, "BankFlux") == nil, "nil types")
assert(GuildGoalMath.MemberCount({ Members = { a = true, b = true } }) == 2, "member count")
assert(GuildGoalMath.MemberCount({}) == 0, "empty guild members")
assert(GuildGoalMath.MemberCount(nil) == 0, "nil guild")

------------------------------------------------------------------------
-- RollGoal — deterministic index + TargetPerMember scaling
------------------------------------------------------------------------
local solo = { Members = { ["1"] = { Role = "Leader" } } }
local rolled = GuildGoalMath.RollGoal(solo, 0, goalConfig)
assert(rolled.TypeId == "BankFlux", "now=0 → first type")
near(rolled.Target, 100, "solo target = BaseTarget")
assert(rolled.Progress == 0 and rolled.Completed == false, "fresh goal progress")
assert(type(rolled.Claimed) == "table" and type(rolled.Contributors) == "table", "fresh bags")

local duo = { Members = { ["1"] = true, ["2"] = true }, Goal = { TypeId = "BankFlux" } }
local nextGoal = GuildGoalMath.RollGoal(duo, 50, goalConfig)
assert(nextGoal.TypeId == "BankDust", "previous BankFlux → rotate to BankDust")
near(nextGoal.Target, 10 + 5 * 1, "duo TargetPerMember scaling")

------------------------------------------------------------------------
-- EnsureGoal — create / rebuild Claimed / rotate
------------------------------------------------------------------------
local fresh = { Members = { ["9"] = true } }
assert(GuildGoalMath.EnsureGoal(fresh, 10, goalConfig) == true, "nil Goal creates")
assert(type(fresh.Goal) == "table" and fresh.Goal.TypeId ~= "", "Goal seeded")

-- Evidence bug: TypeId-matched bags missing Claimed used to rebuild then ClaimGoal
-- early-return dropped the repair (UpdateAsync got nil). Ensure must report changed.
local brokenClaimed = {
	Members = { ["9"] = true },
	Goal = {
		TypeId = "BankFlux",
		Target = 100,
		Progress = 0,
		StartedAt = 0,
		EndsAt = 10_000,
		Completed = false,
		CompletedAt = 0,
		Contributors = { ["9"] = 5 },
		-- Claimed omitted
	},
}
assert(GuildGoalMath.EnsureGoal(brokenClaimed, 20, goalConfig) == true, "nil Claimed → changed")
assert(type(brokenClaimed.Goal.Claimed) == "table", "Claimed rebuilt")
assert(GuildGoalMath.EnsureGoal(brokenClaimed, 20, goalConfig) == false, "second Ensure is no-op")

local brokenContrib = {
	Members = { ["9"] = true },
	Goal = {
		TypeId = "BankFlux",
		Target = "50",
		Progress = nil,
		StartedAt = 0,
		EndsAt = 10_000,
		Completed = "yes",
		CompletedAt = nil,
		Claimed = {},
		-- Contributors omitted
	},
}
assert(GuildGoalMath.EnsureGoal(brokenContrib, 20, goalConfig) == true, "nil Contributors + coerce → changed")
assert(type(brokenContrib.Goal.Contributors) == "table", "Contributors rebuilt")
assert(brokenContrib.Goal.Completed == false, "non-true Completed coerced")
near(brokenContrib.Goal.Target, 50, "string Target coerced via tonumber")
near(brokenContrib.Goal.Progress, 0, "nil Progress → 0")

local expired = {
	Members = { ["9"] = true },
	Goal = {
		TypeId = "BankFlux",
		Target = 100,
		Progress = 0,
		StartedAt = 0,
		EndsAt = 5,
		Completed = false,
		CompletedAt = 0,
		Contributors = {},
		Claimed = {},
	},
}
assert(GuildGoalMath.EnsureGoal(expired, 10, goalConfig) == true, "expired rotates")
assert(expired.Goal.TypeId == "BankDust", "rotate after BankFlux")

------------------------------------------------------------------------
-- AdvanceGoal
------------------------------------------------------------------------
local live = {
	Members = { ["1"] = true },
	Goal = {
		TypeId = "BankFlux",
		Target = 100,
		Progress = 90,
		StartedAt = 0,
		EndsAt = 10_000,
		Completed = false,
		CompletedAt = 0,
		Contributors = {},
		Claimed = {},
	},
}
GuildGoalMath.AdvanceGoal(live, "1", "ContributeDust", 50, 30, goalConfig)
near(live.Goal.Progress, 90, "wrong metric ignored")
GuildGoalMath.AdvanceGoal(live, "1", "ContributeCash", 15, 30, goalConfig)
near(live.Goal.Progress, 105, "cash contribution advances")
near(live.Goal.Contributors["1"], 15, "contributor tally")
assert(live.Goal.Completed == true and live.Goal.CompletedAt == 30, "target reached → completed")

------------------------------------------------------------------------
-- CanClaimGoal
------------------------------------------------------------------------
local okClaim, errClaim = GuildGoalMath.CanClaimGoal(live.Goal, "1", true, 1)
assert(okClaim == true and errClaim == nil, "contributor can claim")
live.Goal.Claimed["1"] = true
okClaim, errClaim = GuildGoalMath.CanClaimGoal(live.Goal, "1", true, 1)
assert(okClaim == false and errClaim ~= nil, "double claim rejected")
okClaim, errClaim = GuildGoalMath.CanClaimGoal(live.Goal, "2", true, 1)
assert(okClaim == false, "non-contributor rejected")
okClaim, errClaim = GuildGoalMath.CanClaimGoal(live.Goal, "1", false, 1)
assert(okClaim == false and string.find(errClaim or "", "not in", 1, true), "non-member rejected")

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local serviceSrc = fs.readFile("src/Server/AstralForge/Services/GuildService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/GuildGoalMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(serviceSrc, "GuildGoalMath.EnsureGoal", 1, true), "GuildService must delegate EnsureGoal")
assert(string.find(serviceSrc, "GuildGoalMath.AdvanceGoal", 1, true), "GuildService must delegate AdvanceGoal")
assert(string.find(serviceSrc, "GuildGoalMath.CanClaimGoal", 1, true), "GuildService must delegate CanClaimGoal")
assert(string.find(serviceSrc, "GuildGoalMath.GoalTypeById", 1, true), "GuildService must delegate GoalTypeById")
assert(not string.find(serviceSrc, "local function rollGoal", 1, true), "inline rollGoal must be removed")
assert(not string.find(serviceSrc, "local function memberCount", 1, true), "inline memberCount must be removed")
assert(
	string.find(serviceSrc, "return if repaired then guild else nil", 1, true),
	"ClaimGoal must persist Claimed/Contributors repairs on deny"
)
assert(
	string.find(serviceSrc, "if failure then return false, failure, updated end", 1, true),
	"ClaimGoal must not report success when deny persisted a repair"
)

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { serviceSrc, mathSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(mathSrc, "GetService", 1, true), "GuildGoalMath must stay pure")
assert(not string.find(mathSrc, "WaitForChild", 1, true), "GuildGoalMath must stay require-free under Lune")

print("[INFO] [TEST] guild goal math extract passed | GuildGoalMath")
