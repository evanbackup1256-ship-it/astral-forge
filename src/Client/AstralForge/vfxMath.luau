--!strict
-- Pure motion maths for interface effects (sparks, rings, pops).
--
-- Real effects move under forces: a spark is thrown, air drags it, gravity
-- bends it down, and it stretches along its path when it's fast. These are
-- closed-form, so every frame lands on the exact point in time -- smooth at
-- 30 fps or 240 -- and scripts/verify_vfx_math.luau can check them in Lune.

-- Studio resolves the sibling through script; Lune (the tests) by path.
local Motion = if script ~= nil then require((script :: any).Parent.motionTokens) else require("./motionTokens")

local Fx = {}

-- Position (px, screen space: +y is down) of a particle thrown at `angle`
-- (radians, 0 = right, -pi/2 = up) with `speed` px/s, after `t` seconds, under
-- linear drag `k` (1/s) and gravity `g` (px/s^2).
function Fx.ballistic(t: number, angle: number, speed: number, g: number, k: number): (number, number)
	local vx0, vy0 = math.cos(angle) * speed, math.sin(angle) * speed
	if k < 1e-4 then
		return vx0 * t, vy0 * t + 0.5 * g * t * t
	end
	-- dv/dt = g - k v  =>  v(t) = g/k + (v0 - g/k) e^(-kt): the particle
	-- relaxes toward terminal velocity g/k (falling, +y).
	local decay = 1 - math.exp(-k * t)
	local x = vx0 / k * decay
	local terminal = g / k
	local y = terminal * t + (vy0 - terminal) / k * decay
	return x, y
end

-- Velocity (px/s) at time `t` for the same throw.
function Fx.velocity(t: number, angle: number, speed: number, g: number, k: number): (number, number)
	local vx0, vy0 = math.cos(angle) * speed, math.sin(angle) * speed
	if k < 1e-4 then
		return vx0, vy0 + g * t
	end
	local e = math.exp(-k * t)
	local terminal = g / k
	return vx0 * e, terminal + (vy0 - terminal) * e
end

-- How much a streak stretches along its motion at `speed` px/s (1 = round).
function Fx.stretch(speed: number): number
	return 1 + math.clamp(speed / 260, 0, 2.2)
end

-- A particle's fade over its life: holds, then accelerates out.
-- Returns transparency (0 = solid, 1 = gone).
function Fx.fade(t: number, life: number, hold: number?): number
	local start = life * (hold or 0.35)
	if t <= start then
		return 0
	end
	return Motion.EASE.accelerate(math.clamp((t - start) / math.max(1e-3, life - start), 0, 1))
end

-- How white-hot a particle is (1 at birth, cooling to 0 by `cool` seconds).
function Fx.heat(t: number, cool: number): number
	return 1 - Motion.EASE.decelerate(math.clamp(t / math.max(1e-3, cool), 0, 1))
end

-- A shock ring: bursts out fast and slows (grow 0..1), thinning as it goes,
-- and fades out late.
function Fx.ring(t: number, life: number): (number, number, number)
	local x = math.clamp(t / math.max(1e-3, life), 0, 1)
	local grow = Motion.EASE.decelerate(x)
	local thickness = 1 - x
	local transparency = Motion.EASE.accelerate(math.clamp((x - 0.15) / 0.85, 0, 1))
	return grow, thickness, transparency
end

-- A pop's entrance scale: overshoots once and settles, like a stamped number.
function Fx.popScale(t: number, rise: number, amount: number): number
	local x = math.clamp(t / math.max(1e-3, rise), 0, 1)
	-- easeOutBack with a soft overshoot.
	local c1 = 1.4
	local c3 = c1 + 1
	local back = 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	return 1 - amount + amount * back
end

-- Deterministic pseudo-random in [0, 1) from an integer id, so a particle's
-- path is stable across re-renders.
function Fx.hash(id: number, salt: number?): number
	local v = math.sin((id + (salt or 0) * 101.37) * 12.9898) * 43758.5453
	return v - math.floor(v)
end

return Fx
