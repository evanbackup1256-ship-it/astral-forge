--!strict
-- The guided tutorial (SharedData#TutorialScript):
--  * fits the server's 15-step clamp and every step is complete,
--  * every spotlight target is a Name the UI really sets,
--  * goals, progress and Bolt's placement behave.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Script = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#TutorialScript"), { chunkName = "TutorialScript" })() :: any
local NavRouteTable = require("../src/Client/AstralForge/CoreKit")("navRouteTable")

local steps = Script.STEPS
assert(#steps >= 10, "the tour should be thorough, got " .. #steps .. " steps")
assert(#steps <= 15, "DataService clamps TutorialStep to 15")
assert(steps[#steps].watch == "finish", "the last step finishes the guide")

-- Every Name the client UI sets, plus the Nav_<id> buttons.
local uiSource = table.concat({
	fs.readFile("src/Client/AstralForge/UiCore.luau"),
	fs.readFile("src/Client/AstralForge/pages/PagesCore.luau"),
	fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau"),
}, "\n")
local function targetExists(name: string): boolean
	if string.sub(name, 1, 4) == "Nav_" then
		return NavRouteTable.isNavRoute(string.sub(name, 5)) and string.find(uiSource, 'Name = "Nav_" .. entry.id', 1, true) ~= nil
	end
	return string.find(uiSource, 'Name = "' .. name .. '"', 1, true) ~= nil
end

local ids = {}
for index, step in steps do
	local label = "step " .. index .. " (" .. tostring(step.id) .. ")"
	assert(type(step.id) == "string" and not ids[step.id], label .. " needs a unique id")
	ids[step.id] = true
	for _, field in { "title", "say", "body", "goal", "watch" } do
		assert(type(step[field]) == "string" and step[field] ~= "", label .. " needs " .. field)
	end
	assert(#step.say <= 140, label .. ": Bolt's line should fit the bubble")
	if step.target ~= nil then
		assert(targetExists(step.target), label .. ": nothing in the UI is named " .. step.target)
	end
	if step.page ~= nil then
		assert(NavRouteTable.isNavRoute(step.page), label .. ": unknown page " .. step.page)
	end
	if step.startPage ~= nil then
		assert(NavRouteTable.isNavRoute(step.startPage), label .. ": unknown startPage " .. step.startPage)
	end
	local watch = step.watch
	local known = watch == "continue" or watch == "finish" or watch == "collect" or watch == "buy" or watch == "amount"
	if string.sub(watch, 1, 5) == "page:" then
		known = NavRouteTable.isNavRoute(string.sub(watch, 6))
		-- A "go to page X" step must not take the player there itself.
		assert(step.startPage ~= string.sub(watch, 6), label .. " navigates for the player")
		assert(step.page == string.sub(watch, 6), label .. " must keep its nav button visible")
	end
	assert(known, label .. ": unknown watch " .. watch)
	if step.cta ~= nil then
		assert(step.cta == "collect" or step.cta == "workshop" or step.cta == "research", label .. ": unknown cta")
		assert(type(step.ctaLabel) == "string", label .. ": cta needs a label")
	end
end

-- Goals
local function step(watch)
	return { watch = watch }
end
assert(Script.goalMet(step("continue"), {}) and Script.goalMet(step("finish"), {}), "read steps are always met")
assert(not Script.goalMet(step("collect"), {}) and Script.goalMet(step("collect"), {}, true), "collect waits for the vault to empty")
assert(not Script.goalMet(step("buy"), { ownedMachines = 0 }) and Script.goalMet(step("buy"), { ownedMachines = 2 }), "buy")
assert(not Script.goalMet(step("amount"), { buyAmount = 1 }) and Script.goalMet(step("amount"), { buyAmount = 5 }), "amount")
assert(Script.goalMet(step("page:Workshop"), { page = "Workshop" }) and not Script.goalMet(step("page:Workshop"), { page = "Overview" }), "page")
assert(not Script.goalMet(nil, {}) and not Script.goalMet(step("mystery"), {}), "unknown goals never pass")
assert(Script.needsAction(step("buy")) and not Script.needsAction(step("continue")), "needsAction")
assert(Script.progress(1, 10, false) == 0.05 and Script.progress(10, 10, true) == 1, "progress")

-- Bolt's placement
local x, y, angle, side = Script.petPose({ x = 100, y = 100, w = 80, h = 40 }, 1000, 600, 56)
assert(side == "right" and x > 180 and math.abs(y - 120) < 1, "room on the right: Bolt sits there")
assert(math.abs(angle - 180) < 1, "and points left at it, got " .. angle)
x, y, angle, side = Script.petPose({ x = 900, y = 100, w = 90, h = 40 }, 1000, 600, 56)
assert(side == "left" and x < 900, "no room right: left")
x, y, angle, side = Script.petPose({ x = 0, y = 10, w = 1000, h = 40 }, 1000, 600, 56)
assert(side == "below" and y > 50 and math.abs(angle + 90) < 1, "full-width target: below, pointing up")
x, y = Script.petPose({ x = -500, y = -500, w = 10, h = 10 }, 400, 300, 56)
assert(x >= 28 and y >= 28 and x <= 372 and y <= 272, "Bolt stays on screen")
local _, _, dockAngle, dockSide = Script.petPose(nil, 800, 600, 56, { x = 100, y = 400, w = 500 })
assert(dockSide == "dock" and dockAngle == 90, "no target: Bolt waits by the card")

-- Wiring
local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(string.find(shell, '("TutorialScript").STEPS', 1, true), "the shell uses the script")
assert(string.find(shell, "tutorial.startPage == nil", 1, true), "only startPage steps navigate")
local overlay = fs.readFile("src/Client/AstralForge/UiCore.luau#onboarding")
for _, needle in { "local function findTarget", "WING_FRAMES", "TALK_FRAMES", "blink", "GetMouseLocation", "onPetClick", "MaxVisibleGraphemes" } do
	assert(string.find(overlay, needle, 1, true), "tutorial overlay has " .. needle)
end

print("verify_tutorial: ok")
