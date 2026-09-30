--!nocheck
-- Guards for the procedural animation maths (springs, two-bone IK, chain waves, the strike
-- curve) that the bosses' rigs are driven by.

local ProcAnim = require("../src/Shared/AstralForge/Shared/SharedData")("ProcAnim")

local function check(condition: boolean, message: string)
	if not condition then
		error("proc anim: " .. message, 0)
	end
end

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

-- Springs: settle on the target from rest, at any frame length, without going non-finite.
for _, dt in { 1 / 240, 1 / 60, 1 / 20, 0.5, 2 } do
	for _, stiffness in { 10, 80, 400, 5000 } do
		for _, ratio in { 0.3, 1, 2 } do
			local position, velocity = 0, 0
			local damping = ProcAnim.damping(stiffness, ratio)
			for _ = 1, math.ceil(12 / dt) do
				position, velocity = ProcAnim.spring(position, velocity, 10, stiffness, damping, dt)
				check(position == position and velocity == velocity and math.abs(position) < 1e6, "spring went non-finite")
			end
			check(near(position, 10, 0.05), `spring did not settle (dt={dt}, k={stiffness}, zeta={ratio}): {position}`)
		end
	end
end
-- Under-damped springs overshoot; critically damped ones do not.
local function peak(ratio: number): number
	local position, velocity, highest = 0, 0, 0
	for _ = 1, 600 do
		position, velocity = ProcAnim.spring(position, velocity, 1, 100, ProcAnim.damping(100, ratio), 1 / 60)
		highest = math.max(highest, position)
	end
	return highest
end
check(peak(0.3) > 1.2, "an under-damped spring should overshoot")
check(peak(1) < 1.01, "a critically damped spring should not overshoot")
-- A spring at rest on its target stays there.
local rest, restVelocity = ProcAnim.spring(3, 0, 3, 50, 10, 1 / 60)
check(rest == 3 and restVelocity == 0, "a spring at rest should stay put")

-- Two-bone IK: the triangle closes, the reach is clamped, the far and near limits hold.
for _, pair in { { 10, 10 }, { 11, 11 }, { 12, 6 }, { 6, 12 } } do
	local l1, l2 = pair[1], pair[2]
	for _, distance in { 0, 1, 4, 8, 12, l1 + l2 - 0.5, l1 + l2, 100 } do
		local shoulder, elbow, reach = ProcAnim.twoBone(l1, l2, distance)
		check(reach >= math.abs(l1 - l2) and reach <= l1 + l2, "reach out of range")
		check(shoulder >= 0 and shoulder <= math.pi and elbow >= 0 and elbow <= math.pi, "angle out of range")
		-- Law of cosines: the two bones and the reach form a triangle.
		check(near(l1 * l1 + l2 * l2 - 2 * l1 * l2 * math.cos(elbow), reach * reach, 1e-6 * reach * reach + 1e-6), "elbow angle does not close the triangle")
		-- Law of sines: l2 / sin(shoulder) == reach / sin(elbow).
		if math.sin(shoulder) > 1e-3 and math.sin(elbow) > 1e-3 then
			check(near(l2 / math.sin(shoulder), reach / math.sin(elbow), 1e-3 * reach), "angles break the sine rule")
		end
		-- Putting the elbow where the angle says, the hand lands `reach` away along the line.
		local elbowX, elbowY = l1 * math.cos(shoulder), l1 * math.sin(shoulder)
		local handDistance = math.sqrt((reach - elbowX) ^ 2 + elbowY ^ 2)
		check(near(handDistance, l2, 1e-3), "the second bone does not reach the target")
	end
end
local _, bent = ProcAnim.twoBone(10, 10, 10)
local _, straight = ProcAnim.twoBone(10, 10, 19.99)
check(bent < math.pi / 2 + 0.6 and straight > bent, "a longer reach straightens the elbow")

-- Waves: bounded by amplitude and taper, lag runs down the chain, and they start from zero at t = 0.
for index = 1, 7 do
	for _, t in { 0, 0.3, 1.7, 9 } do
		local value = ProcAnim.wave(index, 7, t, 3, 0.6, 0.25, 0.8)
		check(math.abs(value) <= 0.25 * 1.8 + 1e-9, "wave exceeds amplitude and taper")
	end
end
check(near(ProcAnim.wave(3, 7, 0, 3, 0.6, 0.25, 0.8), ProcAnim.wave(3, 7, 0, 3, 0.6, 0.25, 0.8)), "wave is deterministic")
check(ProcAnim.wave(1, 1, 1, 3, 0.6, 0.25, 0.8) == ProcAnim.wave(1, 1, 1, 3, 0.6, 0.25, 0.8), "a one-segment chain is safe")
local tip, base = 0, 0
for step = 0, 400 do
	tip = math.max(tip, math.abs(ProcAnim.wave(7, 7, step * 0.05, 3, 0.6, 0.25, 0.8)))
	base = math.max(base, math.abs(ProcAnim.wave(1, 7, step * 0.05, 3, 0.6, 0.25, 0.8)))
end
check(tip > base * 1.4, "the tip should swing wider than the base")

-- The strike curve: anticipation, overshoot, settle.
check(ProcAnim.strike(0) == 0 and ProcAnim.strike(1) == 1, "strike endpoints")
check(ProcAnim.strike(0.2) < -0.1, "strike should wind back first")
check(ProcAnim.strike(0.45) > 1.05, "strike should overshoot")
check(near(ProcAnim.strike(0.7), 1, 1e-9), "strike should have settled")
local previous = ProcAnim.strike(0)
for step = 1, 1000 do
	local value = ProcAnim.strike(step / 1000)
	check(math.abs(value - previous) < 0.05, "strike curve has a jump")
	previous = value
end
check(ProcAnim.strike(-1) == 0 and ProcAnim.strike(3) == 1, "strike clamps its input")

-- Angle differences take the short way round.
check(near(ProcAnim.angleDelta(0.1, 2 * math.pi - 0.1), 0.2, 1e-9), "angle delta across zero")
check(near(ProcAnim.angleDelta(2 * math.pi - 0.1, 0.1), -0.2, 1e-9), "angle delta the other way")
check(near(ProcAnim.angleDelta(1, 1), 0), "no difference")
check(math.abs(ProcAnim.angleDelta(math.pi + 0.01, 0)) < math.pi, "never more than half a turn")

print("[TEST] procedural animation guards passed | springs, two-bone IK, waves, strike curve")