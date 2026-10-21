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
	p.Daily.LastClaimDay = day - 2
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

-- batch 46: one shield per missed day; too few shields resets and spends none
do
	local p = DataTemplate.New()
	p.Daily.LastClaimDay = day - 4 -- three missed days
	p.Daily.Streak = 6
	p.Command.StreakShields = 2
	check(Progression.DailyState(p).NextStreak == 1, "two shields can't cover three missed days")
	Progression.ClaimDaily(p)
	check(p.Daily.Streak == 1 and p.Command.StreakShields == 2, "reset keeps the shields")

	local q = DataTemplate.New()
	q.Daily.LastClaimDay = day - 4
	q.Daily.Streak = 6
	q.Command.StreakShields = 5
	check(Progression.DailyState(q).NextStreak == 7, "enough shields: preview keeps the streak")
	Progression.ClaimDaily(q)
	check(q.Daily.Streak == 7 and q.Command.StreakShields == 2, "three missed days spend three shields")

	local fresh = DataTemplate.New()
	fresh.Command.StreakShields = 3
	Progression.ClaimDaily(fresh)
	check(fresh.Daily.Streak == 1 and fresh.Command.StreakShields == 3, "first ever claim spends no shields")
end

-- batch 46: Lab power only counts cells the player still owns
do
	local Lab = H.load("Server/AstralForge/Services/Gameplay/Lab")
	local LabMath = H.load("Server/AstralForge/Modules/LabOrderMath")
	local p = DataTemplate.New()
	p.Rebirths = 200
	Lab.Ensure(p, 1)
	local order = LabMath.CHANNEL_ORDER
	local power = GameConfig.Lab.Power
	p.Lab.Routing[order[1]] = power.MaxCells
	p.Rebirths = 0 -- after an ascension
	local per = power.Channels[order[1]].EffectPerCell
	check(Lab.PowerEffect(p, order[1]) == power.BaseCells * per, "routed cells above the owned count give nothing")
	for i = 2, #order do
		check(Lab.PowerEffect(p, order[i]) == 0, "later rails get no phantom cells")
	end
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
