--!nocheck
-- Regression checks for the day-b gameplay bug hunt (batch 45+), run from the compiled TS (out/)
-- through scripts/_server_harness. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local Progression = H.load("Server/AstralForge/Services/Gameplay/Progression")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local CommandMath = H.load("Server/AstralForge/Modules/CommandMath")
local day = math.floor(os.time() / 86400)

-- daily preview matches the claim when a streak shield covers a missed day
do
	local p = DataTemplate.New()
	p.Daily.LastClaimDay = day - 3
	p.Daily.Streak = 4
	p.Command.StreakShields = 1
	local preview = Progression.DailyState(p)
	check(preview.CanClaim and preview.NextStreak == 5, "shielded preview keeps the streak (got " .. tostring(preview.NextStreak) .. ")")
	local ok = Progression.ClaimDaily(p)
	check(ok and p.Daily.Streak == preview.NextStreak, "claim lands on the previewed streak")
	check(p.Command.StreakShields == 0, "shield spent")

	local q = DataTemplate.New()
	q.Daily.LastClaimDay = day - 3
	q.Daily.Streak = 4
	q.Command.StreakShields = 0
	local reset = Progression.DailyState(q)
	check(reset.NextStreak == 1, "no shield: preview resets")
	Progression.ClaimDaily(q)
	check(q.Daily.Streak == reset.NextStreak, "no shield: claim matches preview")
end

-- weekly targets stay fixed when the commander levels up mid-week
do
	local p = DataTemplate.New()
	p.Command.XP = 0
	Progression.EnsureWeekly(p)
	local before = Progression.WeeklyState(p)[1].Target
	p.Command.XP = 1e9
	local after = Progression.WeeklyState(p)[1].Target
	check(before == after, string.format("weekly target held mid-week (%s -> %s)", tostring(before), tostring(after)))
	check(type(p.Command.Weekly.Scale) == "number", "new week stores its scale")

	-- a week saved before Scale existed gets it backfilled, keeping old saves loadable
	local old = DataTemplate.New()
	old.Command.Weekly = { Week = p.Command.Weekly.Week, Baseline = {}, Claimed = {} }
	check(Progression.EnsureWeekly(old) == true and type(old.Command.Weekly.Scale) == "number", "old week backfills Scale")
	local ensured = CommandMath.Ensure(old.Command, GameConfig.Operations.SeasonId)
	check(type(ensured.Weekly.Scale) == "number", "CommandMath keeps Scale")
end

if #failures > 0 then
	error("gameplay fixes failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] gameplay fixes: %d checks passed", checks))
