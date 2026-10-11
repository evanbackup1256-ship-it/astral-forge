--!strict
-- Guards for the real-time layout guard (layoutGuard + layoutGuardPlan).
--
--   1. Budgets: steady frames stay cheap, a resize gets a burst, fresh work
--      goes first and never exceeds what is waiting.
--   2. Latency: on a 3,000-element screen a changed label is caught within
--      about a second at 60 fps (the old two-second slices took ~20 s to
--      cover the same tree), and a new element the frame after it is measured.
--   3. Resize detection ignores sub-pixel jitter but never misses a rotation.
--   4. Touch legibility floor: small text is raised on touch screens only,
--      never scaled text, never glyph-sized decoration.
--   5. The guard is wired to all of it: event-driven fresh queue, the resize
--      signal, the per-frame plan, the verified text floor.
--
-- HARD: pure checks -- no Roblox instances.

local fs = require("./_memberfs")(require("@lune/fs"))
local Plan = require("../src/Client/AstralForge/LayoutKit")("layoutGuardPlan")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

------------------------------------------------------------------------
-- 1. Budgets
------------------------------------------------------------------------
local steady = Plan.budget(0, 500)
assert(steady.fresh == Plan.FRESH_PER_FRAME and steady.sweep == Plan.SWEEP_PER_FRAME, "steady budget")
local idle = Plan.budget(0, 0)
assert(idle.fresh == 0 and idle.sweep == Plan.SWEEP_PER_FRAME, "no fresh work, sweep continues")
local light = Plan.budget(0, 5)
assert(light.fresh == 5, "fresh budget never exceeds what is waiting")
local burst = Plan.budget(Plan.BURST_FRAMES, 40)
assert(burst.fresh == 40 and burst.fresh + burst.sweep == Plan.BURST_PER_FRAME, "burst budget covers fresh work first")
local flood = Plan.budget(3, 10000)
assert(flood.fresh == Plan.BURST_PER_FRAME and flood.sweep == 0, "a flood of fresh work takes the whole burst")
assert(Plan.BURST_PER_FRAME <= 400, "a burst frame must stay affordable")
assert(Plan.FRESH_PER_FRAME + Plan.SWEEP_PER_FRAME <= 160, "a steady frame must stay cheap")

------------------------------------------------------------------------
-- 2. Latency
------------------------------------------------------------------------
local tree = 3000
local caught = Plan.worstCatchSeconds(tree, 60)
assert(caught <= 1.1, string.format("a changed label on a %d-element screen takes %.2fs to catch at 60 fps", tree, caught))
assert(Plan.worstCatchSeconds(tree, 30) <= 2.1, "still under ~2 s at 30 fps")
local oldSeconds = math.ceil(tree / 280) * 2
assert(oldSeconds / caught >= 10, "the real-time sweep must be an order of magnitude faster than the old slices")
assert(Plan.SETTLE_FRAMES <= 2, "new elements are checked within two frames")
-- A resize burst alone covers a big screen in its dozen frames.
assert(Plan.BURST_PER_FRAME * Plan.BURST_FRAMES >= tree, "a resize burst covers a 3,000-element screen")

------------------------------------------------------------------------
-- 3. Resize detection
------------------------------------------------------------------------
assert(Plan.resized(-1, -1, 800, 600), "the first measurement counts")
assert(not Plan.resized(800, 600, 803, 598), "sub-pixel / few-pixel jitter is ignored")
assert(Plan.resized(800, 600, 820, 600), "a real resize counts")
assert(Plan.resized(844, 390, 390, 844), "a rotation counts")
assert(Plan.resized(600, 596, 596, 600) == false, "a near-square flip within the slop is jitter")

------------------------------------------------------------------------
-- 4. Touch legibility floor
------------------------------------------------------------------------
assert(Plan.textFloor(true, 9, false) == Plan.TOUCH_TEXT_FLOOR, "small text is raised on touch")
assert(Plan.textFloor(false, 9, false) == nil, "desktop text is left alone")
assert(Plan.textFloor(true, 9, true) == nil, "scaled text is left alone")
assert(Plan.textFloor(true, Plan.TOUCH_TEXT_FLOOR, false) == nil, "text at the floor is left alone")
assert(Plan.textFloor(true, 4, false) == nil, "glyph-sized decoration is left alone")
assert(Plan.TOUCH_TEXT_FLOOR >= 11, "the touch floor must be readable")

------------------------------------------------------------------------
-- 4b. Wrap, label collisions, off-screen panels
------------------------------------------------------------------------
assert(Plan.shouldWrap(14, 40, false, false), "a two-line box wraps")
assert(not Plan.shouldWrap(14, 20, false, false), "a one-line box does not")
assert(not Plan.shouldWrap(14, 40, true, false) and not Plan.shouldWrap(14, 40, false, true), "already wrapped or scaled: leave it")
local a1 = { x0 = 0, y0 = 0, x1 = 100, y1 = 20 }
assert(Plan.labelsCollide(a1, { x0 = 80, y0 = 2, x1 = 160, y1 = 22 }), "overlapping row labels collide")
assert(not Plan.labelsCollide(a1, { x0 = 104, y0 = 0, x1 = 160, y1 = 20 }), "side by side is fine")
assert(not Plan.labelsCollide(a1, { x0 = 50, y0 = 30, x1 = 150, y1 = 50 }), "different rows are fine")
local dx, dy = Plan.nudgeIntoView(900, 500, 1100, 700, 1000, 600)
assert(dx == -106 and dy == -106, "a panel hanging off the bottom-right moves back in")
dx, dy = Plan.nudgeIntoView(-20, 10, 80, 60, 1000, 600)
assert(dx == 26 and dy == 0, "off the left edge moves right")
dx, dy = Plan.nudgeIntoView(0, 0, 2000, 100, 1000, 600)
assert(dx == 6, "wider than the screen keeps its left edge in view")

------------------------------------------------------------------------
-- 5. Wiring
------------------------------------------------------------------------
local guard = readSource("src/Client/AstralForge/layoutGuard.luau")
assert(string.find(guard, "(\"layoutGuardPlan\")", 1, true), "the guard schedules from layoutGuardPlan")
assert(string.find(guard, "Plan.budget(self.burstLeft, #self.fresh)", 1, true), "every frame spends the planned budget")
assert(string.find(guard, "layer.DescendantAdded:Connect", 1, true), "new elements enter the fresh queue")
assert(string.find(guard, "playerGui.ChildAdded:Connect(consider)", 1, true), "portaled layers (dropdowns, sheets, toasts) are watched too")
assert(string.find(guard, 'diagnostics:record(label, "TextOverflow"', 1, true), "overflow reports the responsible owner")
assert(string.find(guard, "Plan.labelsCollide(leftText, rightText)", 1, true), "labels that run into each other are untangled")
assert(string.find(guard, "repairFloatingPanel(inst)", 1, true), "floating panels are pulled back on screen")
local autoScale = readSource("src/Client/AstralForge/MotionKit.luau#autoScale")
assert(string.find(autoScale, "useCoalescedScreen(function()", 1, true), "resize signals fold into one update per frame")
assert(string.find(guard, 'root:GetPropertyChangedSignal("AbsoluteSize")', 1, true), "a resize is handled the frame it happens")
assert(not string.find(guard, "label.TextSize =", 1, true), "font size remains component-owned")
assert(not string.find(guard, "label.TextScaled = true", 1, true), "guard never shrinks overflowing labels")
assert(not string.find(guard, "SCAN_INTERVAL_SECONDS = 2", 1, true), "the two-second scan is gone")
assert(string.find(guard, "checkOverlappingHitboxes(self.queue)", 1, true), "the hitbox pass runs over each finished sweep")
local syntax = readSource("scripts/_syntax_check.luau")
assert(string.find(syntax, "LayoutKit.luau", 1, true), "layoutGuardPlan is in the O0 compile gate")

print(
	string.format(
		"[INFO] [TEST] real-time layout guard passed | %d-element screen caught in %.2fs (was ~%ds), burst %d/frame x %d",
		tree,
		caught,
		oldSeconds,
		Plan.BURST_PER_FRAME,
		Plan.BURST_FRAMES
	)
)
