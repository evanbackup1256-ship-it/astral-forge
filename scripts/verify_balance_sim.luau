--!nocheck
-- Economy pacing guard: a fresh save played for one 30-minute session (taps on) and one idle
-- session through the real EconomyMath/GameConfig/RebirthMath rules (scripts/_balance_sim.luau).
-- The bands are wide on purpose; a failure means a config or formula change moved early pacing
-- a lot, so re-read /workspace/balance-report.md before widening them. Run `npx rbxtsc` first.
local Sim = require("./_balance_sim")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function finite(x) return type(x) == "number" and x == x and x ~= math.huge end

local active = Sim.run({ Days = 1, Sessions = { { Start = 3600, Length = 1800 } }, TapsPerSecond = 4, Step = 5 })
local first = active.Stats.Rebirths[1]
check(first ~= nil, "a fresh save reaches its first rebirth inside 30 active minutes")
if first then
	check(first.Active >= 20 and first.Active <= 900, string.format("first rebirth between 20s and 15min active (got %ds)", first.Active))
end
local rb = active.Profile.Rebirths
check(rb >= 8 and rb <= 60, "rebirths after 30 active minutes in [8, 60] (got " .. rb .. ")")
check(active.Profile.Zone >= 3, "worlds 2-3 open in the first session")
check(finite(active.Production) and finite(active.Multiplier), "production stays finite")
check(active.Profile.Cores < 1e14 and active.Profile.Stardust >= 0, "cores under the save clamp, stardust non-negative")
check(active.Stats.StardustSpent <= active.Stats.StardustEarned + 1, "the grid never spends Stardust it didn't earn")
check(active.Stats.ForgePathStep >= 1, "Forge Path advances from banking")

local idle = Sim.run({ Days = 2, Sessions = { { Start = 3600, Length = 900 } }, TapsPerSecond = 0, Step = 5 })
check(idle.Stats.OfflineCash > 0, "offline earnings pay out between sessions")
check(idle.Profile.Rebirths >= 1, "an idle player still rebirths")

if #failures > 0 then error("balance sim failed:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] balance sim: %d checks passed (30 min active: %d rebirths, world %d)", checks, rb, active.Profile.Zone))
