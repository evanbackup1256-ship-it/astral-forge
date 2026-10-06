--!strict
-- Guards for the interface-effect maths (motionTokens.fx, aliased as vfxMath).
--
--   1. The closed-form spark path matches a fine numerical simulation of drag
--      and gravity (so every frame lands exactly where physics says).
--   2. Sparks behave like sparks: they rise first, then fall; they slow down;
--      they stretch only while fast, within bounds.
--   3. Fades hold, then leave, and never come back; rings burst out, thin and
--      fade late; pops overshoot once, a little, and settle at full size.
--   4. The forge floor effects actually use this maths.
--
-- HARD: pure checks -- no Roblox instances.

local fs = require("./_memberfs")(require("@lune/fs"))
local Fx = require("../src/Client/AstralForge/MotionKit")("motionTokens").fx

------------------------------------------------------------------------
-- 1. Closed form vs simulation
------------------------------------------------------------------------
local g, k = 980, 2.6
for _, throw in { { -math.pi / 2, 400 }, { -math.pi / 3, 300 }, { -2.4, 520 }, { 0, 200 } } do
	local angle, speed = throw[1], throw[2]
	local x, y = 0, 0
	local vx, vy = math.cos(angle) * speed, math.sin(angle) * speed
	local dt = 1 / 20000
	local t = 0
	for _ = 1, 14400 do -- 0.72 s
		vx += (-k * vx) * dt
		vy += (g - k * vy) * dt
		x += vx * dt
		y += vy * dt
		t += dt
	end
	local cx, cy = Fx.ballistic(t, angle, speed, g, k)
	assert(math.abs(cx - x) < 0.5 and math.abs(cy - y) < 0.5, string.format("closed form drifts from physics: (%.2f, %.2f) vs (%.2f, %.2f)", cx, cy, x, y))
	local cvx, cvy = Fx.velocity(t, angle, speed, g, k)
	assert(math.abs(cvx - vx) < 0.5 and math.abs(cvy - vy) < 0.5, "closed-form velocity drifts from physics")
end
-- No drag reduces to the textbook parabola.
local px, py = Fx.ballistic(0.5, 0, 100, 10, 0)
assert(math.abs(px - 50) < 1e-6 and math.abs(py - 1.25) < 1e-6, "zero-drag path must be the parabola")

------------------------------------------------------------------------
-- 2. Sparks
------------------------------------------------------------------------
local up = -math.pi / 2
local _, y1 = Fx.ballistic(0.1, up, 400, g, k)
local _, y2 = Fx.ballistic(0.7, up, 400, g, k)
assert(y1 < 0, "a spark thrown up rises first")
assert(y2 > y1, "and gravity brings it back down")
local _, vy0 = Fx.velocity(0, up, 400, g, k)
local _, vyLate = Fx.velocity(0.6, up, 400, g, k)
assert(vy0 < 0 and vyLate > 0, "it turns over at the top of its arc")
assert(Fx.stretch(0) == 1, "a still spark is round")
assert(Fx.stretch(1e6) <= 3.2, "a fast spark stretches, within bounds")
assert(Fx.stretch(400) > Fx.stretch(100), "faster means longer")

------------------------------------------------------------------------
-- 3. Curves
------------------------------------------------------------------------
local last = -1
for i = 0, 100 do
	local t = i / 100 * 0.8
	local fade = Fx.fade(t, 0.72, 0.3)
	assert(fade >= last - 1e-9, "a fade never comes back")
	assert(fade >= 0 and fade <= 1, "fade stays in range")
	last = fade
end
assert(Fx.fade(0.1, 0.72, 0.3) == 0, "a particle holds solid early in its life")
assert(Fx.fade(0.72, 0.72, 0.3) >= 0.999, "and is gone at the end")
local lastGrow, lastThick = -1, 2
for i = 0, 100 do
	local grow, thick, fade = Fx.ring(i / 100 * 0.6, 0.55)
	assert(grow >= lastGrow - 1e-9 and thick <= lastThick + 1e-9, "rings only grow and only thin")
	assert(fade >= 0 and fade <= 1, "ring fade stays in range")
	lastGrow, lastThick = grow, thick
end
local growEarly = Fx.ring(0.11, 0.55)
assert(growEarly > 0.5, "a ring bursts most of the way out in its first fifth")
local peak = 0
for i = 0, 100 do
	peak = math.max(peak, Fx.popScale(i / 100 * 0.3, 0.2, 0.5))
end
assert(peak > 1.02 and peak < 1.15, string.format("a pop overshoots once, a little (peak %.3f)", peak))
assert(math.abs(Fx.popScale(0.2, 0.2, 0.5) - 1) < 1e-6, "and lands at full size")
assert(math.abs(Fx.popScale(0, 0.2, 0.5) - 0.5) < 1e-6, "starting from its shrunk size")
assert(Fx.heat(0, 0.16) == 1 and Fx.heat(0.16, 0.16) == 0, "sparks are white-hot at birth and cooled by the end")
for id = 1, 500 do
	local h = Fx.hash(id, 2)
	assert(h >= 0 and h < 1, "hash stays in [0, 1)")
	assert(Fx.hash(id, 2) == h, "hash is stable")
end

------------------------------------------------------------------------
-- 4. Wiring
------------------------------------------------------------------------
local floor = (string.gsub(fs.readFile("src/Client/AstralForge/UiOverlays.luau#floorFx"), "\r\n", "\n"))
for _, needle in { "Fx.ballistic(", "Fx.velocity(", "Fx.stretch(", "Fx.fade(", "Fx.ring(", "Fx.popScale(", "Fx.heat(" } do
	assert(string.find(floor, needle, 1, true), "floorFx must use " .. needle)
end

print("[INFO] [TEST] vfx maths passed | spark paths match physics, curves hold their shape")
