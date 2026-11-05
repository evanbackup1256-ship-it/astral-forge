--!nocheck
-- Ignition runs (rebirth v3): heat grades the run, fast clean counted runs streak for
-- stardust, a counted close leaves a temper due (Quench cores / Anneal boosts), and v2
-- saves seed a streak from their run log. Plus the sigil wheel: ring harmonics, the
-- wheel turn, and rank attunement. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local R = H.load("Shared/AstralForge/Shared/RebirthMath")
local D = H.load("Shared/AstralForge/Shared/DomainLattice")

-- migration: a v2 ledger with two clean fast runs in its log keeps a streak of 2
local bag = R.ensure({
	Version = 2,
	Lifetime = 5,
	RunStartedAt = 100,
	Runs = {
		{ Attempt = 3, N = 3, At = 50, Seconds = 600, Cores = 10, Vow = "", Kept = false, Counted = true, Grade = "B" },
		{ Attempt = 4, N = 4, At = 90, Seconds = 800, Cores = 12, Vow = "Swift", Kept = true, Counted = true, Grade = "A" },
	},
	BestCores = 12,
}, 1000, 5)
check(bag.Version == R.VERSION, "ledger upgrades to v" .. R.VERSION)
check(bag.Streak == 2, "v2 log seeds a streak of 2 (got " .. tostring(bag.Streak) .. ")")
check(bag.BestStreak >= 2, "best streak covers the seed")
check(bag.TemperDue == false, "no temper waiting on an old save")
check(bag.Temper == "", "no temper chosen on an old save")

-- heat: a run beating the best with a kept vow grades hot, a cold run grades cold
local fresh = R.ensure(nil, 1000, 0)
local hotQuote = R.quote(fresh, { Cores = 100, Stardust = 10 }, { Seconds = 300, Zone = 1, MachineKinds = 2, Ratio = 2 })
check(type(hotQuote.Heat) == "number" and hotQuote.Heat >= 0 and hotQuote.Heat <= 100, "heat stays in 0..100")
check(hotQuote.Grade == "S" or hotQuote.Grade == "A", "a first strong run grades high (got " .. hotQuote.Grade .. ")")
check(hotQuote.StreakAfter == 1, "a fast clean run starts a streak")

-- streak: slow runs and broken vows end it; the multiplier pays on the current streak
local streaky = R.ensure(nil, 1000, 0)
streaky.Streak = 3
local slow = R.quote(streaky, { Cores = 50, Stardust = 10 }, { Seconds = R.STREAK_TARGET + 60, Zone = 1, MachineKinds = 2, Ratio = 2 })
check(slow.StreakAfter == 0, "a slow counted run resets the streak")
streaky.Vow = "Swift"
streaky.VowSince = 1200 -- sworn after the grace window, so it reads as broken
streaky.RunStartedAt = 990
local broken = R.quote(streaky, { Cores = 50, Stardust = 10 }, { Seconds = 300, Zone = 1, MachineKinds = 2, Ratio = 2 })
check(broken.Kept == false, "the vow is actually broken in this fixture")
check(broken.StreakAfter == 0, "a broken vow resets the streak even when fast")
check(slow.StardustMultiplier > 1 + R.STREAK_STEP * 3 - 1e-9 and slow.StardustMultiplier < 1 + R.STREAK_STEP * 3 + 0.5,
	"streak stardust multiplier applies (got " .. slow.StardustMultiplier .. ")")

-- close: counted runs set the streak and leave a temper due; practice runs don't
local closed = R.ensure(nil, 1000, 0)
local q1 = R.quote(closed, { Cores = 100, Stardust = 10 }, { Seconds = 400, Zone = 1, MachineKinds = 2, Ratio = 2 })
local e1 = R.close(closed, q1, 1400, nil, nil, true)
check(closed.Streak == 1, "counted close stores the streak")
check(closed.TemperDue == true, "counted close leaves a temper due")
check(e1.Heat == q1.Heat, "the log entry keeps the heat")
local ok0, err0 = R.temper(R.ensure(nil, 1000, 0), "Quench")
check(ok0 == false, "temper refuses when nothing is due")
local okQ, resQ = R.temper(closed, "Quench")
check(okQ == true and type(resQ) == "table" and resQ.Cores >= 1, "quench banks bonus cores")
check(resQ.Cores == math.floor(e1.Cores * R.QUENCH_SHARE) or resQ.Cores == 1, "quench pays QUENCH_SHARE of the last run")
check(closed.Temper == "Quench" and closed.TemperDue == false, "temper is consumed once")
local practice = R.close(closed, R.quote(closed, { Cores = 10, Stardust = 1 }, { Seconds = 30, Zone = 1, MachineKinds = 1, Ratio = 2 }), 1500, nil, nil, false)
check(closed.Streak == 1, "a practice run leaves the streak alone")
check(practice.Counted == false, "practice run logs uncounted")

-- sigil wheel: all 24 non-outer-ring links kindle the inner ring's harmonic
local all = {}
for _, e in D.EDGES do all[e.key] = true end
local innerOnly = {}
for _, e in D.EDGES do
	local a, b = e.a, e.b
	local outerish = (a >= 8 and b >= 8)
	if not outerish then innerOnly[e.key] = true end
end
local i0, o0, t0 = D.ringProgress(innerOnly)
check(i0 == 6 and o0 == 0 and t0 == false, "inner ring kindles without the outer ring (" .. i0 .. "/" .. o0 .. ")")
local withInner = D.bonus(innerOnly, "Production", 1)
local plain = {}
for k, v in innerOnly do plain[k] = v end
plain["2-3"] = nil -- unkindle one inner anchor
check(D.bonus(plain, "Production", 1) < withInner, "breaking one anchor drops the inner harmonic")
local ia, oa, ta = D.ringProgress(all)
check(ia == 6 and oa == 6 and ta == true, "all thirty links turn the wheel")
check(D.bonus(all, "Production", 1) > withInner + D.HARMONIC_OUTER + D.TURN_BONUS - 1e-9,
	"the turned wheel pays outer harmonic + turn bonus")
local attuned = D.bonus(innerOnly, "Tap", 5)
local base = D.bonus(innerOnly, "Tap", 1)
check(math.abs(attuned - base * (1 + 4 * D.ATTUNE_STEP)) < 1e-9, "rank attunes every anchor")
check(D.bonus(innerOnly, "Tap") == base, "rank defaults to 1 for old callers")

if #failures > 0 then error("rebirth heat failed:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] rebirth heat + sigil wheel: %d checks passed", checks))
