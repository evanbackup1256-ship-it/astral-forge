--!nocheck
-- Economy pacing guard: a fresh save played for one 30-minute session (taps on) and one idle
-- session through the real EconomyMath/GameConfig/RebirthMath rules (scripts/_balance_sim.luau).
-- The bands are wide on purpose; a failure means a config or formula change moved early pacing
-- a lot, so re-read /workspace/balance-report.md before widening them. Run `npx rbxtsc` first.
local Sim = require("./_balance_sim")
local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function finite(x) return type(x) == "number" and x == x and x ~= math.huge end

local active = Sim.run({ Days = 1, Sessions = { { Start = 3600, Length = 2700 } }, TapsPerSecond = 1, Step = 5 })
local first = active.Stats.Rebirths[1]
check(first ~= nil, "a fresh save reaches its first rebirth inside 45 active minutes")
if first then
	check(first.Active >= 300 and first.Active <= 900, string.format("first rebirth between 5 and 15 active minutes at 1 tap/s (got %ds)", first.Active))
end
local rb = active.Profile.Rebirths
check(rb >= 2 and rb <= 12, "counted rebirths after 45 active minutes in [2, 12] (got " .. rb .. ")")
check(active.Profile.Zone >= 2, "world 2 opens in the first session")
check(finite(active.Production) and finite(active.Multiplier), "production stays finite")
check(active.Profile.Cores < 1e14 and active.Profile.Stardust >= 0, "cores under the save clamp, stardust non-negative")
check(active.Stats.StardustSpent <= active.Stats.StardustEarned + 1, "the grid never spends Stardust it didn't earn")
check(active.Stats.ForgePathStep >= 1, "Forge Path advances from banking")

-- v8 rebirth rules
local H = require("./_server_harness")
local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
local G = H.load("Shared/AstralForge/Shared/GameConfig")
local base = Economy.PrestigeRequirementFor(0)
local full = G.Economy.PrestigeRequirement
local span = G.Economy.PrestigeEarlyDiscountRebirths
check(math.abs(base - full * G.Economy.PrestigeEarlyDiscount) < 1, "rebirth 0 needs the discounted base requirement")
local prev = 0
for r = 0, span + 2 do
	local need = Economy.PrestigeRequirementFor(r)
	check(need > prev, "the requirement rises every rebirth through the early ramp (r=" .. r .. ")")
	prev = need
end
check(math.abs(Economy.PrestigeRequirementFor(span) - full * G.Economy.PrestigeRequirementGrowth ^ span) < 1, "the early discount is gone by rebirth " .. span)
check(Economy.PrestigeRequirementFor(10) > full * 2.4 and Economy.PrestigeRequirementFor(10) < full * 2.8, "the requirement grows about x1.10 a rebirth")
check(Economy.PrestigeRequirementFor(1e9) == full * G.Economy.PrestigeRequirementMaxScale, "the growth stops at its cap")
local w5 = Economy.GetZone(5)
check(w5.RequiredRebirths <= 10 and w5.RequiredRebirths > Economy.GetZone(4).RequiredRebirths, "world 5 opens by 10 counted rebirths, after world 4")
check(G.Economy.Rebirth.MinCountedRunSeconds >= 60, "short runs don't count toward world gates")
local spam = Sim.run({ Days = 1, Sessions = { { Start = 3600, Length = 1800 } }, TapsPerSecond = 4, Step = 5, SpamRebirth = true })
check(spam.Profile.Rebirths <= 30 * 60 / G.Economy.Rebirth.MinCountedRunSeconds, "rebirth spam can't count more than one rebirth per minimum run")

local idle = Sim.run({ Days = 2, Sessions = { { Start = 3600, Length = 900 } }, TapsPerSecond = 0, Step = 5 })
check(idle.Stats.OfflineCash > 0, "offline earnings pay out between sessions")
check(idle.Profile.Rebirths >= 1, "an idle player still rebirths")

if #failures > 0 then error("balance sim failed:\n  " .. table.concat(failures, "\n  ")) end
print(string.format("[TEST] balance sim: %d checks passed (45 min active: %d rebirths, world %d)", checks, rb, active.Profile.Zone))
