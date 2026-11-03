--!nocheck
-- The antilag governor: fast to drop, slow to climb, protected against flapping, bounded by ceilings, and
-- every tier's profile only ever gets lighter going down. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local G = H.load("Shared/AstralForge/Shared/AntilagGovernor")

local GOOD = { fps = 60, p95Ms = 16, p99Ms = 20, worstMs = 24, jank = 0, hitch = 0 }
local SLOW = { fps = 28, p95Ms = 52, p99Ms = 70, worstMs = 90, jank = 0.5, hitch = 0.3 }
local COLLAPSE = { fps = 14, p95Ms = 90, p99Ms = 160, worstMs = 220, jank = 0.9, hitch = 0.7 }

-- feed `seconds` of windows (one every 0.32s) starting at `t`; returns the next t
local function run(gov, window, t, seconds)
	local stop = t + seconds
	while t < stop do
		gov:update(window, t)
		t += 0.32
	end
	return t
end

-- profiles: every number grows with the tier, every switch that is on at a tier is on above it
local last = G.profileFor(0)
for tier = 1, 3 do
	local now = G.profileFor(tier)
	for _, key in { "quality", "fxBudget", "particleBudget", "glowScale", "maxClocks", "maxPops", "maxStars", "clockHz", "springGain", "layoutBudgetMs", "paintScale" } do
		if key == "springGain" or key == "paintScale" then
			check(now[key] <= last[key], key .. " shrinks going up")
		else
			check(now[key] >= last[key], key .. " grows going up")
		end
	end
	for _, key in { "allowAmbient", "allowConfetti", "textShadows", "shimmer", "entrance", "viewports" } do
		check(not last[key] or now[key], key .. " never turns off going up")
	end
	check(last.skipEntrance or not now.skipEntrance, "skipEntrance only at the low tiers")
	last = now
end
check(G.profileFor(0).allowAmbient == false and G.profileFor(1).allowAmbient == false, "no ambient effects at the two lowest tiers")
check(G.profileFor(0).textShadows == false and G.profileFor(1).textShadows == false, "no text shadows at the two lowest tiers")
check(G.profileFor(3).clockHz == 60 and G.profileFor(0).clockHz <= 10, "clock rate runs from 60Hz to a crawl")
check(G.profileFor(3, true).clockHz <= 30 and G.profileFor(3, true).particleBudget < G.profileFor(3).particleBudget, "phones get lighter profiles at every tier")
check(G.profileFor(99).tier == 3 and G.profileFor(-4).tier == 0, "tiers clamp")

-- boot measurement and the Priority setting
check(G.tierForBootFps(60, false) == 3 and G.tierForBootFps(45, false) == 2 and G.tierForBootFps(30, false) == 1 and G.tierForBootFps(15, false) == 0, "boot fps picks the starting tier")
check(G.tierForBootFps(60, true) == 2, "phones never start above tier 2")
check(G.ceilingForPreference(0) == 3 and G.ceilingForPreference(0.5) == 3 and G.ceilingForPreference(0.75) == 1 and G.ceilingForPreference(1) == 0, "Performance mode sets the ceiling")
check(G.performanceModeFor(0) == "good" and G.performanceModeFor(0.5) == "auto" and G.performanceModeFor(0.75) == "bad" and G.performanceModeFor(1) == "potato", "saved bias maps to the four modes")
check(G.boundsForMode("good").floor == 1 and G.boundsForMode("auto").trustCeiling == false, "Good holds a floor, Auto trusts the measurement")
local function device(over)
	local d = { fps = 60, p95Ms = 18, pingMs = 60, memoryMb = 900, graphics = 0, constrained = false }
	for k, v in over do
		d[k] = v
	end
	return d
end
check(G.tierForDevice(device({})) == 3, "a healthy desktop tunes to tier 3")
check(G.tierForDevice(device({ p95Ms = 60 })) == 2, "stutter under a good average costs a tier")
check(G.tierForDevice(device({ pingMs = 400 })) == 2, "a far server caps the start at 2")
check(G.tierForDevice(device({ graphics = 2 })) == 1, "a low Roblox graphics slider caps the start at 1")
check(G.tierForDevice(device({ fps = 15, p95Ms = 90, memoryMb = 4000 })) == 0, "a struggling device never goes below 0")
check(G.tierForDevice(device({ constrained = true, memoryMb = 1800 })) == 1, "a phone near its memory limit starts at 1")

-- a healthy machine earns the top tier slowly
do
	local gov = G.Governor.new(false, 2)
	local t = run(gov, GOOD, 10, 9)
	check(gov.tier == 2, "9 clean seconds are not enough for tier 3")
	t = run(gov, GOOD, t, 6)
	check(gov.tier == 3, "15 clean seconds earn tier 3")
	t = run(gov, GOOD, t, 30)
	check(gov.tier == 3, "the top tier is the top")
end

-- a slow machine drops fast, one tier per bad stretch, and bottoms out at 0
do
	local gov = G.Governor.new(false, 3)
	local verdict = gov:update(SLOW, 100)
	check(verdict.changed and gov.tier == 2 and verdict.reason == "slow frames", "the first bad window drops a tier at once")
	gov:update(SLOW, 100.2)
	check(gov.tier == 2, "drops are at least 0.6s apart")
	gov:update(SLOW, 100.7)
	check(gov.tier == 1, "a second bad stretch drops another tier")
	run(gov, SLOW, 101, 5)
	check(gov.tier == 0, "sustained slowness reaches tier 0")
	run(gov, SLOW, 106, 10)
	check(gov.tier == 0, "and never goes below it")
end

-- a collapse is a panic: two tiers at once, then a long hold
do
	local gov = G.Governor.new(false, 3)
	local verdict = gov:update(COLLAPSE, 50)
	check(verdict.panic and gov.tier == 1, "a collapse drops two tiers")
	local t = run(gov, GOOD, 50.4, 4)
	check(gov.tier == 1, "no climbing during the post-panic hold")
	t = run(gov, GOOD, t, 20)
	check(gov.tier >= 2, "after the hold and a clean stretch it climbs again")
end

-- flap protection: a drop soon after a climb makes the next climb take twice as long
do
	local gov = G.Governor.new(false, 2)
	local t = run(gov, GOOD, 0, 13)
	check(gov.tier == 3 and gov.backoff == 1, "climbed to 3")
	gov:update(SLOW, t)
	check(gov.tier == 2 and gov.backoff == 2, "dropping right after a climb doubles the backoff")
	t = run(gov, GOOD, t + 0.5, 15)
	check(gov.tier == 2, "the second climb needs a longer clean stretch")
	t = run(gov, GOOD, t, 14)
	check(gov.tier == 3, "and still comes")
end

-- calm stretches forgive the backoff
do
	local gov = G.Governor.new(false, 2)
	local t = run(gov, GOOD, 0, 13)
	gov:update(SLOW, t)
	check(gov.backoff == 2, "backoff raised")
	run(gov, GOOD, t + 1, 140)
	check(gov.backoff == 1, "calm time brings the backoff back down")
end

-- ceilings (Speed priority, heavy scenes) apply at once and hold
do
	local gov = G.Governor.new(false, 3)
	gov:setCeiling(1)
	local verdict = gov:update(GOOD, 5)
	check(gov.tier == 1 and verdict.reason == "ceiling", "a lowered ceiling pulls the tier down at once")
	run(gov, GOOD, 6, 60)
	check(gov.tier == 1, "a clean machine still stays under the ceiling")
	gov:setCeiling(3)
	run(gov, GOOD, 70, 40)
	check(gov.tier == 3, "raising the ceiling lets it climb again")
end

-- pin (Studio test hook) beats everything
do
	local gov = G.Governor.new(false, 3)
	gov:setPin(0)
	gov:update(GOOD, 1)
	check(gov.tier == 0, "a pinned tier wins over good frames")
	run(gov, SLOW, 2, 3)
	check(gov.tier == 0, "and over slow ones")
	gov:setPin(nil)
	check(gov.pinned == nil, "unpinned")
end

-- grace: loading and resumes are not measurements
do
	local gov = G.Governor.new(false, 3)
	gov:grace(10)
	gov:update(COLLAPSE, 5)
	check(gov.tier == 3, "bad windows inside the grace period are ignored")
	gov:update(SLOW, 10.5)
	check(gov.tier == 2, "after it they count")
end

-- the same frames are worse on a desktop than on a phone
do
	local MIDDLING = { fps = 35, p95Ms = 33, p99Ms = 50, worstMs = 60, jank = 0.1, hitch = 0.05 }
	local desktop = G.Governor.new(false, 3)
	local phone = G.Governor.new(true, 2)
	desktop:update(MIDDLING, 20)
	phone:update(MIDDLING, 20)
	check(desktop.tier == 2, "35 fps is a bad window on a desktop")
	check(phone.tier == 2, "35 fps is fine on a phone")
end

-- a jittery machine still recovers: a merely-OK window drains some banked time, it does not wipe it
do
	local MIDDLING = { fps = 52, p95Ms = 24, p99Ms = 40, worstMs = 60, jank = 0.05, hitch = 0.03 }
	local gov = G.Governor.new(false, 1)
	local t = 0
	for i = 1, 70 do
		gov:update(i % 10 == 0 and MIDDLING or GOOD, t)
		t += 0.32
	end
	check(gov.tier == 2, "one OK window in ten does not stop the climb")
	-- but a bad window empties the bank
	local gov2 = G.Governor.new(false, 1)
	t = run(gov2, GOOD, 0, 7)
	gov2:update(SLOW, t)
	check(gov2.tier == 0 and gov2.cleanTime == 0, "a bad window empties the banked clean time")
end
-- one slow spell is one incident: dropping three tiers in a row raises the backoff once, not three times
do
	local gov = G.Governor.new(false, 2)
	local t = run(gov, GOOD, 0, 13)
	check(gov.tier == 3, "climbed to 3")
	t = run(gov, SLOW, t, 4)
	check(gov.tier == 0, "a spell of slowness took it to 0")
	check(gov.backoff == 2, "three drops in one spell raise the backoff once")
end
if #failures > 0 then
	error("antilag: " .. #failures .. " of " .. checks .. " checks failed:\n  " .. table.concat(failures, "\n  "))
end
print(`[TEST] antilag governor: {checks} checks (profiles, boot tiers, climb and drop timing, panic hold, flap backoff, ceilings, pin, grace) passed`)
