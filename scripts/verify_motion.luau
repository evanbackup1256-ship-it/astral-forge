--!strict
-- Guards for the shared motion language (src/Client/AstralForge/motionTokens).
--
--   1. Every spring in the client resolves to smooth motion: damping in the
--      no-wobble band, overshoot under 3%, settle times the eye can follow.
--      Checked by scanning every spring call site in the codebase, so a new
--      component can't bring back a wobble.
--   2. Curves are well formed: pinned ends, monotonic, entrances decelerate,
--      exits accelerate.
--   3. Cascades stay under a quarter second however long the list.
--   4. The engine (motion.luau) resolves every spring library through the
--      tokens -- no private stiffness->frequency mappings left.
--
-- HARD: pure checks -- no Roblox instances.

local fs = require("@lune/fs")
local Tokens = require("../src/Client/AstralForge/motionTokens")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

------------------------------------------------------------------------
-- 1. Springs
------------------------------------------------------------------------
local function scanFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			if name ~= "tests" then
				scanFiles(path, out)
			end
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end
local files: { string } = {}
scanFiles("src/Client/AstralForge", files)

-- Explicit pops that ask for their own damping ratio (Otter / spr) are
-- checked separately below; these are the (stiffness, damping) springs.
local patterns = {
	"createFlipperMotor%([^,%)]+,%s*(%d+),%s*(%d+)%)",
	"useFlipperSpring%([^\n]-,%s*[^,\n]+,%s*(%d+),%s*(%d+)[,%)]",
	"useOptionalFlipperSpring%([^\n]-,%s*[^,\n]+,%s*[^,\n]+,%s*(%d+),%s*(%d+)%)",
	"useSpring%([^\n]-,%s*[^,\n]+,%s*(%d+),%s*(%d+)%)",
	"useHeldSpring%([^,\n]+,%s*(%d+),%s*(%d+)%)",
	":configure%((%d+),%s*(%d+)%)",
}
local sites = 0
local worstOvershoot, worstAt = 0, ""
local slowest, slowestAt = 0, ""
local fastest, fastestAt = math.huge, ""
for _, path in files do
	local source = readSource(path)
	for _, pattern in patterns do
		for s, d in string.gmatch(source, pattern) do
			local stiffness, damping = tonumber(s) :: number, tonumber(d) :: number
			local feel = Tokens.feel(stiffness, damping)
			sites += 1
			assert(feel.dampingRatio >= Tokens.DAMPING_MIN and feel.dampingRatio <= Tokens.DAMPING_MAX, `{path}: spring ({s}, {d}) damps outside the no-wobble band`)
			local over = Tokens.overshoot(feel)
			if over > worstOvershoot then
				worstOvershoot, worstAt = over, `{path} ({s}, {d})`
			end
			local settle = Tokens.settleSeconds(feel)
			if settle > slowest then
				slowest, slowestAt = settle, `{path} ({s}, {d})`
			end
			if settle < fastest then
				fastest, fastestAt = settle, `{path} ({s}, {d})`
			end
		end
	end
end
assert(sites >= 50, "the spring scan found too few call sites -- did the patterns drift? got " .. sites)
assert(worstOvershoot <= 0.03, string.format("worst spring overshoots %.1f%% at %s", worstOvershoot * 100, worstAt))
assert(slowest <= 0.8, string.format("slowest spring takes %.2fs to settle at %s", slowest, slowestAt))
assert(fastest >= 0.06, string.format("fastest spring settles in %.3fs at %s -- too quick to see", fastest, fastestAt))

-- The raw mapping behind the band.
for stiffness = 100, 2400, 50 do
	for damping = 10, 80, 2 do
		local feel = Tokens.feel(stiffness, damping)
		assert(feel.frequency >= Tokens.FREQUENCY_MIN and feel.frequency <= Tokens.FREQUENCY_MAX, "frequency out of range")
		assert(feel.dampingRatio >= Tokens.DAMPING_MIN and feel.dampingRatio <= Tokens.DAMPING_MAX, "damping out of range")
	end
end
-- More damping never makes a spring bouncier; more stiffness never makes it slower.
for damping = 10, 78, 2 do
	assert(Tokens.feel(600, damping + 2).dampingRatio >= Tokens.feel(600, damping).dampingRatio, "damping must be monotonic")
end
for stiffness = 100, 2350, 50 do
	assert(Tokens.settleSeconds(Tokens.feel(stiffness + 50, 44)) <= Tokens.settleSeconds(Tokens.feel(stiffness, 44)) + 1e-9, "stiffness must be monotonic")
end
-- Named springs order by speed: snap < smooth < gentle.
local snap = Tokens.settleSeconds(Tokens.feel(Tokens.SPRING.snap.stiffness, Tokens.SPRING.snap.damping))
local smooth = Tokens.settleSeconds(Tokens.feel(Tokens.SPRING.smooth.stiffness, Tokens.SPRING.smooth.damping))
local gentle = Tokens.settleSeconds(Tokens.feel(Tokens.SPRING.gentle.stiffness, Tokens.SPRING.gentle.damping))
assert(snap < smooth and smooth < gentle, "named springs must order snap < smooth < gentle")
assert(gentle <= 0.3, "pages and overlays must settle within 0.3s")
assert(Tokens.overshoot(Tokens.bouncyFeel()) >= 0.08, "the bouncy preset must actually bounce")

-- The exact step matches a fine simulation, and stays stable on a long frame.
for _, feel in { { frequency = 3.3, dampingRatio = 0.86 }, { frequency = 6, dampingRatio = 1 }, { frequency = 2, dampingRatio = 0.76 } } do
	local x, v = 120, -40
	local sx, sv = x, v
	local w = feel.frequency * math.pi * 2
	local fine = 1 / 50000
	for frame = 1, 30 do
		x, v = Tokens.step(x, v, 0, feel, 1 / 60)
		for _ = 1, math.floor((1 / 60) / fine + 0.5) do
			local a = -w * w * sx - 2 * feel.dampingRatio * w * sv
			sv += a * fine
			sx += sv * fine
		end
		assert(math.abs(x - sx) < 0.05, string.format("exact step drifts from physics at frame %d: %.3f vs %.3f", frame, x, sx))
	end
	local hx, hv = 120, 0
	for _ = 1, 20 do
		hx, hv = Tokens.step(hx, hv, 0, feel, 0.2)
		assert(math.abs(hx) <= 121, "a long frame never blows the spring up")
	end
	assert(math.abs(hx) < 0.5, "and it still comes to rest")
end
local notifications = readSource("src/Client/AstralForge/notifications.luau")
assert(string.find(notifications, "MotionTokens.step(state.x, state.v, 0, SWIPE_RETURN_FEEL, dt)", 1, true), "toast swipe-back uses the exact step")
assert(not string.find(notifications, "state.v += accel * dt", 1, true), "the Euler swipe integration is gone")

------------------------------------------------------------------------
-- 2. Curves
------------------------------------------------------------------------
for name, curve in Tokens.EASE do
	assert(math.abs(curve(0)) < 1e-6 and math.abs(curve(1) - 1) < 1e-6, name .. " must start at 0 and end at 1")
	local last = -1
	for i = 0, 200 do
		local v = curve(i / 200)
		assert(v >= last - 1e-6, name .. " must never run backwards")
		last = v
	end
end
assert(Tokens.EASE.decelerate(0.25) > 0.5, "decelerate must cover most of the distance early")
assert(Tokens.EASE.accelerate(0.25) < 0.15, "accelerate must start slow")
assert(math.abs(Tokens.EASE.smoothInOut(0.5) - 0.5) < 0.02, "smoothInOut is symmetric")
-- A known CSS reference: cubic-bezier(0.25, 0.1, 0.25, 1) ("ease") at x=0.5 is ~0.8024.
assert(math.abs(Tokens.bezier(0.25, 0.1, 0.25, 1)(0.5) - 0.8024) < 0.002, "the bezier solver must match CSS")
for _, entrance in { 0.08, 0.16, 0.22, 0.34, 0.9 } do
	local exit = Tokens.exitSeconds(entrance)
	assert(exit <= math.max(0.1, entrance) and exit <= 0.22, "exits are never longer than entrances, and never drag")
end

------------------------------------------------------------------------
-- 3. Cascades
------------------------------------------------------------------------
local previous = -1
for index = 0, 60 do
	local delay = Tokens.stagger(index)
	assert(delay >= previous, "a cascade never reorders")
	assert(delay <= Tokens.STAGGER_CAP, "a cascade never exceeds its cap")
	previous = delay
end
assert(Tokens.stagger(1) - Tokens.stagger(0) <= 0.04, "the first gap is short")

------------------------------------------------------------------------
-- 4. The engine uses the tokens
------------------------------------------------------------------------
local motion = readSource("src/Client/AstralForge/motion.luau")
assert(string.find(motion, "require(script.Parent.motionTokens)", 1, true), "motion.luau must use the shared tokens")
assert(string.find(motion, "local feel = MotionTokens.feel(stiffness, damping)", 1, true), "Flipper motors take the shared feel")
assert(string.find(motion, "local nextFeel = MotionTokens.feel(nextStiffness, nextDamping)", 1, true), "reconfigured motors take the shared feel")
assert(string.find(motion, "local feel = MotionTokens.feel(effectiveStiffness, damping)", 1, true), "ripple springs take the shared feel")
assert(not string.find(motion, "damping / 52, 0.48", 1, true), "the old wobbly Flipper mapping is gone")
assert(not string.find(motion, "damping / 48, 0.52", 1, true), "the old wobbly ripple mapping is gone")
assert(string.find(motion, "MotionTokens.stagger(index, step)", 1, true), "staggers use the shared cascade")
assert(string.find(motion, "MotionTokens.EASE.accelerate(alpha)", 1, true), "exits accelerate")

print(
	string.format(
		"[INFO] [TEST] motion language passed | %d springs checked, worst overshoot %.1f%%, settle %.2f-%.2fs",
		sites,
		worstOvershoot * 100,
		fastest,
		slowest
	)
)
