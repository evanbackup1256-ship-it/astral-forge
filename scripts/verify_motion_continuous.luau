--!strict
-- Motion never stops on its own:
--  * every live clock pushes its binding every frame (no rotating push budget),
--  * nothing freezes ambient motion (overlays, cinematics, low frame rate),
--  * the frame-rate governor thins effects but never switches motion off,
--  * Reduced Motion softens the feel (MotionSettingsContext.soft) instead of
--    turning animation off.

local fs = require("./_memberfs")(require("@lune/fs"))

local motion = fs.readFile("src/Client/AstralForge/MotionKit.luau#motion")
local antilag = fs.readFile("src/Client/AstralForge/MotionKit.luau#antilag")

assert(string.find(motion, "local function tickClocks(list, deltaTime)", 1, true), "tickClocks takes no push budget")
assert(not string.find(motion, "offset < math.max(1, budget)", 1, true), "no rotating push window")
assert(not string.find(motion, "applyFrozenFlag", 1, true), "no decorative freeze flag")
assert(string.find(motion, "local function setDecorativeMotionFrozen(_frozen)", 1, true), "setDecorativeMotionFrozen is a no-op")

-- Soft feel: springs lose overshoot, clocks slow, pulses and flashes swing less.
assert(string.find(motion, "soft = false,", 1, true), "default motion settings carry soft = false")
for _, needle in { "softSpring(stiffness, damping, _binding.soft == true)", "softRatio(dampingRatio, frequency, _binding.soft == true)", "SOFT_CLOCK_SPEED", "SOFT_PULSE_DEPTH", "SOFT_FLASH_PEAK" } do
	assert(string.find(motion, needle, 1, true), "soft feel wired: " .. needle)
end

assert(string.find(antilag, "allowAmbient = true,", 1, true), "antilag never disallows ambient motion")
assert(string.find(antilag, "skipEntrance = false,", 1, true), "antilag never skips entrances")
assert(string.find(antilag, "freezeIcons = false,", 1, true), "antilag never freezes icons")

local shell = fs.readFile("src/Client/AstralForge/UiCore.luau")
assert(not string.find(shell, "setDecorativeMotionFrozen(", 1, true), "the shell no longer freezes motion")
assert(string.find(shell, "soft = softFeel,", 1, true), "Reduced Motion reaches MotionSettingsContext as soft")

-- No component gates motion on the frame-rate governor any more.
for _, path in {
	"src/Client/AstralForge/UiCore.luau",
	"src/Client/AstralForge/UiOverlays.luau",
	"src/Client/AstralForge/BootKit.luau",
	"src/Client/AstralForge/pages/PagesCore.luau",
	"src/Client/AstralForge/pages/PagesProgress.luau",
	"src/Client/AstralForge/pages/PagesShop.luau",
	"src/Client/AstralForge/pages/PagesSocial.luau",
	"src/Client/AstralForge/pages/PagesStory.luau",
	"src/Client/AstralForge/pages/PagesSystem.luau",
	"src/Client/AstralForge/pages/PagesCasino.luau",
	"src/Client/AstralForge/pages/PagesBazaar.luau",
} do
	local src = fs.readFile(path)
	for line in string.gmatch(src, "local softMotion = ([^\n]+)") do
		assert(not string.find(line, "antilag", 1, true), path .. ": softMotion gated on antilag: " .. line)
	end
	assert(not string.find(src, "Settings.ReducedMotion == true,", 1, true) or path == "src/Client/AstralForge/UiCore.luau", path .. ": Reduced Motion passed down as an off switch")
end

-- Casino: viewports stay cheap and every animation runs at the frame rate.
local casino = fs.readFile("src/Client/AstralForge/pages/PagesCasino.luau#CasinoView")
assert(string.find(casino, "local function showAround(pos)", 1, true), "reels keep only the cells near the window")
assert(not string.find(casino, "reducedMotion, 20)", 1, true) and not string.find(casino, "reducedMotion, 30)", 1, true), "no throttled casino animation")
assert(not string.find(casino, "drift.current < 1 / 24", 1, true), "the idle wheel turns every frame")
assert(string.find(casino, "local function TabSwap", 1, true), "switching games animates")

print("verify_motion_continuous: ok")
