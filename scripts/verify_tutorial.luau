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
	if name == "Nav_Menu" then
		return string.find(uiSource, 'id = "Menu"', 1, true) ~= nil
	end
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
		local names = if type(step.target) == "table" then step.target else { step.target }
		for _, name in names do
			assert(targetExists(name), label .. ": nothing in the UI is named " .. name)
		end
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
local _, topY, topAngle = Script.petPose(nil, 800, 600, 56, { x = 100, y = 20, w = 500, h = 180 })
assert(topY > 200 and topAngle == -90, "card at the top: Bolt waits under it, pointing up")
-- Never on the card: the screenshot case, a wide target on the right with the card beside it on the left.
local cardRect = { x = 250, y = 40, w = 520, h = 300 }
local px, py, _, pside = Script.petPose({ x = 700, y = 270, w = 890, h = 160 }, 1640, 730, 56, cardRect)
local onCard = px + 28 > cardRect.x - 8 and px - 28 < cardRect.x + cardRect.w + 8 and py + 28 > cardRect.y - 8 and py - 28 < cardRect.y + cardRect.h + 8
assert(not onCard, "Bolt must not sit on the card (side " .. tostring(pside) .. ")")

-- The card: bottom by default, top only when the bottom would cover the target
local y, where = Script.dockPlacement({ x = 700, y = 270, w = 890, h = 160 }, 730, 230, 0, 0)
assert(where == "bottom" and y + 230 <= 730 - 12 + 0.01, "target in the upper half: the card stays at the bottom")
y, where = Script.dockPlacement({ x = 100, y = 600, w = 300, h = 60 }, 730, 230, 0, 0)
assert(where == "top" and y < 100, "target at the bottom: the card moves to the top")
y, where = Script.dockPlacement(nil, 730, 230, 0, 30)
assert(where == "bottom" and math.abs(y - (730 - 30 - 230)) < 0.01, "no target: bottom, above the safe inset")

-- Wiring
local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(string.find(shell, '("TutorialScript").STEPS', 1, true), "the shell uses the script")
assert(string.find(shell, "tutorial.startPage == nil", 1, true), "only startPage steps navigate")
local overlay = fs.readFile("src/Client/AstralForge/UiCore.luau#onboarding")
for _, needle in { "local function findTarget", "wingPhase", "blink", "GetMouseLocation", "onPetClick", "MaxVisibleGraphemes", "dizzyUntil", "st.rub", "SLEEP_AFTER", "TutorialScript.dockPlacement", "AutomaticSize = Enum.AutomaticSize.Y" } do
	assert(string.find(overlay, needle, 1, true), "tutorial overlay has " .. needle)
end
-- The card lays itself out top to bottom; nothing in it may sit at a hard-coded y again.
local overlayFn = string.match(overlay, "local function TutorialOverlay%(_param%)(.-)\nlocal VERSION_ROW_H") or ""
assert(not string.find(overlayFn, "dockH", 1, true), "the step card sizes itself from its content")
assert(not string.find(overlayFn, "math.floor(t * 12)", 1, true), "wings flap continuously, not in stepped frames")

print("verify_tutorial: ok")
