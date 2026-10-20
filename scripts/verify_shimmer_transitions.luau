--!strict
-- Shimmers and page transitions:
--  * the shimmer band is a soft bell (no hard shoulders), brightest in the middle,
--  * each pass crosses once, eased, then waits off-surface so the wrap is never seen,
--  * page changes slide in from the side of the nav they came from, the veil
--    dissolves before the slide lands, and Reduced Motion shortens but keeps it.

local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")

-- Lune has no NumberSequence/Vector2; stand in minimal versions.
local env = {
	NumberSequenceKeypoint = { new = function(time, value) return { Time = time, Value = value } end },
	NumberSequence = { new = function(points) return { Keypoints = points } end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
}
setmetatable(env, { __index = _G })
local Shimmer = luau.load(fs.readFile("src/Client/AstralForge/MotionKit.luau#shimmer"), { chunkName = "shimmer", environment = env })() :: any
local Page = luau.load(fs.readFile("src/Client/AstralForge/MotionKit.luau#pageTransition"), { chunkName = "pageTransition" })() :: any

-- The band
for _, name in { "GLINT", "TRAIL" } do
	local points = Shimmer[name].Keypoints
	assert(#points <= 20, name .. ": Roblox allows 20 keypoints")
	assert(points[1].Time == 0 and points[#points].Time == 1, name .. " spans 0..1")
	local brightest, at = 1, 0
	for index = 2, #points do
		assert(points[index].Time > points[index - 1].Time, name .. " keypoints ascend")
		-- No hard edge anywhere: the falloff slope stays gentle.
		local slope = math.abs(points[index].Value - points[index - 1].Value) / (points[index].Time - points[index - 1].Time)
		assert(slope <= 9, name .. " has a hard edge at " .. points[index].Time)
		if points[index].Value < brightest then
			brightest, at = points[index].Value, points[index].Time
		end
	end
	assert(math.abs(at - 0.5) < 0.06, name .. " peaks in the middle")
end
assert(Shimmer.GLINT.Keypoints[1].Value == 1 and Shimmer.GLINT.Keypoints[#Shimmer.GLINT.Keypoints].Value == 1, "flanks are clear")

-- The sweep
assert(Shimmer.sweepProgress(0) == 0, "starts before the surface")
assert(Shimmer.sweepProgress(Shimmer.SWEEP_SHARE) == 1 and Shimmer.sweepProgress(0.99) == 1, "then waits after it")
local last = -1
for i = 0, 99 do
	local p = Shimmer.sweepProgress(i / 100)
	assert(p >= last - 1e-9, "the band never runs backwards")
	last = p
end
local half = Shimmer.SWEEP_SHARE * 0.5
assert(math.abs(Shimmer.sweepProgress(half) - 0.5) < 1e-6, "eased symmetrically")
assert(Shimmer.sweepProgress(0.05) < 0.05 / Shimmer.SWEEP_SHARE, "glides in rather than starting at full speed")
-- At both ends the band (and its bloom) is fully off the surface, so the wrap is invisible.
local travel = Shimmer.DEFAULT_TRAVEL
local startX = Shimmer.offset(0, travel).X
local endX = Shimmer.offset(0.999, travel).X
assert(startX + 0.5 + 0.3 <= 0 and endX + 0.5 - 0.3 >= 1, "band starts and ends off-surface")
for _, t in { 2.05, 2.2, 2.6 } do
	assert(-t * 0.5 + 0.5 + 0.17 <= 0, "travel " .. t .. " hides the glint at the start")
end
assert(Shimmer.surfaceStrength(1, false, 1) <= 0.5 and Shimmer.surfaceStrength(0, true, 1) > 0, "hover strength capped, idle subtle")

-- Page transitions
local order = { "Overview", "Workshop", "Research" }
-- tightened in the UI visuals pass (24/36 -> 12/16); still a visible slide, phones a bit further
assert(Page.SLIDE_DESKTOP >= 8 and Page.SLIDE_PHONE >= Page.SLIDE_DESKTOP, "page changes use clear directional travel")
assert(Page.VEIL_PEAK == 0.68, "page veil visibly bridges route changes")
assert(Page.direction("Overview", "Research", order) == 1 and Page.direction("Research", "Workshop", order) == -1, "follows the nav")
assert(Page.direction("Nowhere", "Workshop", order) == 1, "unknown pages arrive forward")
local dx, dy = Page.offset(0, 1, "x", 28)
assert(dx == 28 and dy == 0, "phones slide along the tab bar")
dx, dy = Page.offset(0, -1, "y", 18)
assert(dx == 0 and dy == -18, "PC slides along the rail")
dx, dy = Page.offset(1, 1, "y", 18)
assert(dx == 0 and dy == 0, "lands exactly")
assert(Page.distance(true, true) < Page.distance(true, false) and Page.distance(false, true) > 0, "Reduced Motion shortens, never removes")
assert(Page.veilTransparency(1) == 1 and Page.veilTransparency(0) < 0.5, "veil covers the swap and clears")
assert(Page.veilTransparency(0.5) > 0.85, "veil is mostly gone by half way")

-- Wiring
local workspace = fs.readFile("src/Client/AstralForge/UiCore.luau#WorkspaceChrome")
for _, needle in { 'Name = "PageVeil"', "PageTransition.offset(amount, pageDirection, slideAxis, slideDistance)", "pageOrderFor(chrome.stack)" } do
	assert(string.find(workspace, needle, 1, true), "workspace has " .. needle)
end
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau#ui")
assert(string.find(ui, "ColorSequenceKeypoint.new(0.5, Palette.white)", 1, true), "white-hot specular core")
assert(not string.find(ui, "Rotation = 14,", 1, true), "every sweep shares one angle")

print("verify_shimmer_transitions: ok")
