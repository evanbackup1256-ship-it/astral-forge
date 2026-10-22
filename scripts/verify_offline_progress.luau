--!nocheck
-- Offline progress calculator (Shared/OfflineProgress): window clamping, segment cuts at cycle
-- edges and boost/surge ends, reward sums and the away label. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local Offline = H.load("Shared/AstralForge/Shared/OfflineProgress")

local failures, checks = {}, 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

local limits = { maxSeconds = 6 * 3600, minSeconds = 30, cycleSeconds = 600, boostEndsAt = 0, surgeEndsAt = 0 }
local numeric = { zero = 0, add = function(a, b) return a + b end, scale = function(v, f) return v * f end }
local flat = function() return { production = 10, efficiency = 0.5 } end

local short = Offline.project(1000, 1020, limits, flat, numeric)
check(short.reward == 0 and short.elapsed == 20 and short.efficiency == 0 and not short.capped, "20s away pays nothing")

local back = Offline.project(1000, 900, limits, flat, numeric)
check(back.elapsed == 0 and back.reward == 0, "negative away time is zero")

local hour = Offline.project(0, 3600, limits, flat, numeric)
check(near(hour.reward, 10 * 0.5 * 3600), "one flat hour pays 18000")
check(near(hour.efficiency, 0.5) and not hour.capped, "average efficiency is the flat rate")

local long = Offline.project(0, 10 * 3600, limits, flat, numeric)
check(long.capped and long.elapsed == 6 * 3600, "10h away is capped at 6h")
check(near(long.reward, 10 * 0.5 * 6 * 3600), "capped reward covers only 6h")

local cut = Offline.planWindow(100, 1900, { maxSeconds = 1e9, minSeconds = 0, cycleSeconds = 600, boostEndsAt = 700, surgeEndsAt = 5000 })
local edges = {}
for _, s in cut.segments do table.insert(edges, s.from) end
check(#cut.segments == 4, "100..1900 splits into 4 pieces")
check(edges[1] == 100 and edges[2] == 600 and edges[3] == 700 and edges[4] == 1200, "segments are ordered")
check(cut.segments[1].at == 350, "segments sample at their midpoint")

local boosted = Offline.project(0, 1200, { maxSeconds = 1e9, minSeconds = 0, cycleSeconds = 1e9, boostEndsAt = 600, surgeEndsAt = 0 },
	function(at) return { production = at < 600 and 2 or 1, efficiency = 1 } end, numeric)
check(near(boosted.reward, 600 * 2 + 600 * 1), "the boost only pays until it ends")

local tableNumeric = {
	zero = { v = 0 },
	add = function(a, b) return { v = a.v + b.v } end,
	scale = function(x, f) return { v = x.v * f } end,
}
local wrapped = Offline.project(0, 100, limits, function() return { production = { v = 3 }, efficiency = 1 } end, tableNumeric)
check(near(wrapped.reward.v, 300), "works with non-number production values")

check(Offline.formatAway(45) == "45s" and Offline.formatAway(720) == "12m" and Offline.formatAway(3 * 3600) == "3h", "away labels")

if #failures > 0 then
	error(string.format("verify_offline_progress: %d of %d failed:\n  %s", #failures, checks, table.concat(failures, "\n  ")))
end
print(string.format("verify_offline_progress: %d checks ok", checks))
