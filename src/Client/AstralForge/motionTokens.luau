--!strict
-- One motion language for the whole game.
--
-- Every spring, tween, entrance, exit and stagger resolves its feel here, so
-- a button press, a card sliding in, a page change and a reward ceremony all
-- move with the same physics and the same curves -- they read as one system
-- instead of four spring libraries tuned one component at a time.
--
-- Principles:
--   * No wobble. Interface springs settle with a damping ratio of 0.76-1.0:
--     fluid deceleration, at most a hair of overshoot. Bounce is a deliberate
--     choice (the `bouncy` preset), never an accident of a low damping value.
--   * Speed follows size. Small things (hover, press) are quick; big things
--     (pages, overlays, ceremonies) take longer so the eye can follow them.
--   * Enter decelerates, exit accelerates. Things arrive and settle; they
--     leave by picking up speed. Exits are shorter than entrances.
--   * Cascades ease. Staggered items open with a short gap that widens, and
--     the whole cascade stays under a quarter second so a list never crawls.
--
-- Pure math, no Roblox services -- scripts/verify_motion.luau checks it.

local Tokens = {}

------------------------------------------------------------------------
-- Springs
------------------------------------------------------------------------

export type Feel = { frequency: number, dampingRatio: number }

-- Frequencies (Hz) the interface is allowed to use. Below the floor a spring
-- drifts; above the ceiling it snaps and the motion can't be seen.
Tokens.FREQUENCY_MIN = 1.35
Tokens.FREQUENCY_MAX = 8.5
-- Damping the interface is allowed to use (see "No wobble").
Tokens.DAMPING_MIN = 0.76
Tokens.DAMPING_MAX = 1.0

-- The codebase describes springs as (stiffness, damping) pairs tuned over
-- time. This maps any pair onto the shared feel: the relative speed each
-- caller chose is kept, while damping is lifted into the no-wobble band
-- (damping 28 and below -> 0.76, 36 -> 0.82, 44 -> 0.91, 52+ -> critical).
function Tokens.feel(stiffness: number, damping: number): Feel
	local frequency = math.clamp(stiffness / 130, Tokens.FREQUENCY_MIN, Tokens.FREQUENCY_MAX)
	local raw = damping / 52
	local ratio = math.clamp(0.76 + (raw - 0.6) * 0.6, Tokens.DAMPING_MIN, Tokens.DAMPING_MAX)
	return { frequency = frequency, dampingRatio = ratio }
end

-- Named springs for new code. (stiffness, damping) pairs so they drop into
-- every existing hook.
Tokens.SPRING = table.freeze({
	-- Hover, press, toggles: immediate but never jittery.
	snap = table.freeze({ stiffness = 1000, damping = 44 }),
	-- Most interface movement: panels, tabs, indicators, reveals.
	smooth = table.freeze({ stiffness = 620, damping = 48 }),
	-- Large surfaces: pages, sheets, overlays.
	gentle = table.freeze({ stiffness = 420, damping = 52 }),
	-- Numbers and meters catching up to a new value.
	settle = table.freeze({ stiffness = 360, damping = 52 }),
	-- Celebrations only: a visible, pleasant overshoot.
	bouncy = table.freeze({ stiffness = 560, damping = 22 }),
})

-- The explicit bouncy preset keeps its bounce; everything else is lifted.
function Tokens.bouncyFeel(): Feel
	return { frequency = Tokens.SPRING.bouncy.stiffness / 130, dampingRatio = 0.58 }
end

-- Settling time (to within 2%) of a spring, in seconds. Used by tests and by
-- anything that needs to wait for a spring to land.
function Tokens.settleSeconds(feel: Feel): number
	local omega = feel.frequency * math.pi * 2
	return 4 / (math.max(0.1, feel.dampingRatio) * omega)
end

-- Peak overshoot (fraction of the travel) of a spring released from rest.
function Tokens.overshoot(feel: Feel): number
	local z = feel.dampingRatio
	if z >= 1 then
		return 0
	end
	return math.exp(-z * math.pi / math.sqrt(1 - z * z))
end

-- Advance a spring exactly by `dt` seconds (the closed-form damped
-- oscillator, as Flipper uses). For hand-driven motion -- drags that spring
-- back, cameras -- so it is smooth and stable at any frame rate, where a
-- per-frame Euler step drifts and can jitter on uneven frames.
function Tokens.step(x: number, v: number, goal: number, feel: Feel, dt: number): (number, number)
	local z = feel.dampingRatio
	local w = feel.frequency * math.pi * 2
	local offset = x - goal
	local decay = math.exp(-z * w * dt)
	if z >= 1 then
		local nx = (offset * (1 + w * dt) + v * dt) * decay + goal
		local nv = (v * (1 - w * dt) - offset * (w * w * dt)) * decay
		return nx, nv
	end
	local c = math.sqrt(1 - z * z)
	local i = math.cos(w * c * dt)
	local j = math.sin(w * c * dt)
	local nx = (offset * (i + z * j / c) + v * j / (w * c)) * decay + goal
	local nv = (v * (i - z * j / c) - offset * (j / c * w)) * decay
	return nx, nv
end

------------------------------------------------------------------------
-- Curves
------------------------------------------------------------------------

-- A CSS-style cubic-bezier(x1, y1, x2, y2) timing function. Solved with
-- Newton-Raphson and a bisection fallback, so it is exact enough for motion
-- at any frame rate.
function Tokens.bezier(x1: number, y1: number, x2: number, y2: number): (number) -> number
	local function sample(a1: number, a2: number, t: number): number
		local u = 1 - t
		return 3 * u * u * t * a1 + 3 * u * t * t * a2 + t * t * t
	end
	local function slope(a1: number, a2: number, t: number): number
		local u = 1 - t
		return 3 * u * u * a1 + 6 * u * t * (a2 - a1) + 3 * t * t * (1 - a2)
	end
	return function(x: number): number
		if x <= 0 then
			return 0
		end
		if x >= 1 then
			return 1
		end
		local t = x
		for _ = 1, 8 do
			local err = sample(x1, x2, t) - x
			if math.abs(err) < 1e-5 then
				return sample(y1, y2, t)
			end
			local d = slope(x1, x2, t)
			if math.abs(d) < 1e-6 then
				break
			end
			t -= err / d
		end
		-- Bisection for the rare flat spots Newton can't cross.
		local lo, hi = 0, 1
		t = x
		for _ = 1, 24 do
			local value = sample(x1, x2, t)
			if math.abs(value - x) < 1e-5 then
				break
			end
			if value < x then
				lo = t
			else
				hi = t
			end
			t = (lo + hi) / 2
		end
		return sample(y1, y2, t)
	end
end

-- The curve set. "Emphasized" curves are for arrivals that matter (pages,
-- overlays, rewards); "standard" for everyday movement.
Tokens.EASE = table.freeze({
	standard = Tokens.bezier(0.2, 0, 0, 1),
	decelerate = Tokens.bezier(0.05, 0.7, 0.1, 1),
	accelerate = Tokens.bezier(0.3, 0, 0.8, 0.15),
	emphasized = Tokens.bezier(0.2, 0, 0, 1),
	smoothInOut = Tokens.bezier(0.45, 0, 0.55, 1),
	linear = function(x: number): number
		return math.clamp(x, 0, 1)
	end,
})

------------------------------------------------------------------------
-- Durations
------------------------------------------------------------------------

Tokens.DURATION = table.freeze({
	instant = 0.08,
	quick = 0.14,
	standard = 0.22,
	emphasized = 0.34,
	slow = 0.5,
	ceremony = 0.9,
})

-- Exits are shorter than entrances and never drag.
function Tokens.exitSeconds(entrance: number): number
	return math.clamp(entrance * 0.65, 0.1, 0.22)
end

------------------------------------------------------------------------
-- Choreography
------------------------------------------------------------------------

-- Delay before the `index`-th item of a cascade starts (index 0 = first).
-- The gaps widen gently and the whole cascade is capped, so a long list
-- arrives as one motion rather than a slow march.
Tokens.STAGGER_STEP = 0.028
Tokens.STAGGER_CAP = 0.24
function Tokens.stagger(index: number, step: number?): number
	local s = step or Tokens.STAGGER_STEP
	local i = math.max(0, index)
	return math.min(Tokens.STAGGER_CAP, s * (i ^ 1.12))
end

-- How far (px) a surface rises into place as it enters, by its size class.
Tokens.RISE = table.freeze({ small = 6, standard = 10, large = 16 })

------------------------------------------------------------------------
-- Effect maths (sparks, rings, pops, confetti)
------------------------------------------------------------------------

-- Real effects move under forces: a spark is thrown, air drags it, gravity
-- bends it down, and it stretches along its path when it's fast. Closed
-- form, so every frame lands on the exact point in time at any frame rate.
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
	return Tokens.EASE.accelerate(math.clamp((t - start) / math.max(1e-3, life - start), 0, 1))
end

-- How white-hot a particle is (1 at birth, cooling to 0 by `cool` seconds).
function Fx.heat(t: number, cool: number): number
	return 1 - Tokens.EASE.decelerate(math.clamp(t / math.max(1e-3, cool), 0, 1))
end

-- A shock ring: bursts out fast and slows (grow 0..1), thinning as it goes,
-- and fades out late.
function Fx.ring(t: number, life: number): (number, number, number)
	local x = math.clamp(t / math.max(1e-3, life), 0, 1)
	local grow = Tokens.EASE.decelerate(x)
	local thickness = 1 - x
	local transparency = Tokens.EASE.accelerate(math.clamp((x - 0.15) / 0.85, 0, 1))
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

Tokens.fx = Fx

return Tokens
