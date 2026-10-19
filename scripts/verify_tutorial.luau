--!strict
-- The guided tutorial (SharedData#TutorialScript):
--  * fits the server's 15-step clamp and every step is complete,
--  * every spotlight target is a Name the UI really sets,
--  * goals, progress and the callout card's placement and leader line behave.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Script = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#TutorialScript"), { chunkName = "TutorialScript" })() :: any
local NavRouteTable = require("./_kit_loader")("CoreKit")("navRouteTable")

local steps = Script.STEPS
assert(#steps >= 8, "the tour covers the core loop, got " .. #steps .. " steps")
assert(#steps <= 15, "DataService clamps TutorialStep to 15")
assert(Script.EXPERIENCE_NAME == "GETTING STARTED", "tutorial heading stays plain and human")
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
	for _, field in { "title", "line", "watch" } do
		assert(type(step[field]) == "string" and step[field] ~= "", label .. " needs " .. field)
	end
	assert(#step.title <= 28, label .. ": the title fits one line of the card")
	assert(#step.line <= 110, label .. ": one or two lines, not a paragraph")
	assert(not string.find(step.title .. step.line, "!", 1, true), label .. ": plain copy, no exclamation marks")
	if step.watch ~= "continue" and step.watch ~= "finish" then
		assert(type(step.task) == "string" and step.task ~= "", label .. ": an action step names its task")
	end
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
assert(Script.goalMet(step("collect"), { vaultFlux = 0 }), "an already-empty vault cannot strand the tutorial")
assert(not Script.goalMet(step("buy"), { ownedMachines = 0 }) and Script.goalMet(step("buy"), { ownedMachines = 2 }), "buy")
assert(not Script.goalMet(step("amount"), { buyAmount = 1 }) and Script.goalMet(step("amount"), { buyAmount = 5 }), "amount")
assert(Script.goalMet(step("page:Workshop"), { page = "Workshop" }) and not Script.goalMet(step("page:Workshop"), { page = "Overview" }), "page")
assert(not Script.goalMet(nil, {}) and not Script.goalMet(step("mystery"), {}), "unknown goals never pass")
assert(Script.needsAction(step("buy")) and not Script.needsAction(step("continue")), "needsAction")
assert(Script.progress(1, 10, false) == 0.05 and Script.progress(10, 10, true) == 1, "progress")

-- The callout card: beside the target with room for the leader, else docked away from it
local W, H, CW, CH = 1600, 900, 360, 200
local function inside(x, y)
	return x >= 12 - 0.01 and y >= 0 and x + CW <= W - 12 + 0.01 and y + CH <= H + 0.01
end
local function clear(rect, x, y)
	return x + CW <= rect.x or x >= rect.x + rect.w or y + CH <= rect.y or y >= rect.y + rect.h
end
for _, case in {
	{ rect = { x = 100, y = 300, w = 200, h = 60 }, side = "right" },
	{ rect = { x = 1300, y = 300, w = 250, h = 60 }, side = "left" },
	{ rect = { x = 40, y = 40, w = 1520, h = 120 }, side = "below" },
	{ rect = { x = 40, y = 700, w = 1520, h = 160 }, side = "above" },
} do
	local x, y, side = Script.calloutPlacement(case.rect, W, H, CW, CH, 0, 0)
	assert(side == case.side, "expected " .. case.side .. ", got " .. side)
	assert(inside(x, y), side .. ": the card stays on screen")
	assert(clear(case.rect, x, y), side .. ": the card never covers its target")
	local x1, y1, x2, y2 = Script.leader(case.rect, side, x, y, CW, CH)
	assert(x1 ~= nil, side .. ": a leader line joins card and target")
	assert(x1 >= x - 0.01 and x1 <= x + CW + 0.01 and y1 >= y - 0.01 and y1 <= y + CH + 0.01, side .. ": the line starts on the card")
	local r = case.rect
	assert(x2 >= r.x - 0.01 and x2 <= r.x + r.w + 0.01 and y2 >= r.y - 0.01 and y2 <= r.y + r.h + 0.01, side .. ": the line ends on the target")
end
local huge = { x = 0, y = 0, w = W, h = 700 }
local _, hy, hside = Script.calloutPlacement(huge, W, H, CW, CH, 0, 0)
assert(hside == "dock" and hy + CH <= H, "no room beside a huge target: docked")
assert(Script.leader(huge, "dock", 0, 0, CW, CH) == nil, "a docked card draws no leader")
local _, ny, nside = Script.calloutPlacement(nil, W, H, CW, CH, 0, 40)
assert(nside == "dock" and math.abs(ny - (H - 40 - CH)) < 0.01, "no target: docked above the safe inset")
local _, ty = Script.calloutPlacement({ x = 0, y = 640, w = W, h = 260 }, W, H, CW, CH, 30, 0)
assert(ty <= 640 - CH, "target filling the bottom: the card docks at the top")

-- Wiring
local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(string.find(shell, '("TutorialScript").STEPS', 1, true), "the shell uses the script")
assert(string.find(shell, "tutorial.startPage == nil", 1, true), "only startPage steps navigate")
local overlay = fs.readFile("src/Client/AstralForge/UiCore.luau#onboarding")
for _, needle in { "local function findTarget", "TutorialScript.calloutPlacement", "TutorialScript.leader", "AutomaticSize = Enum.AutomaticSize.Y", "missingSince", "StampedCheck", "Juice.burst" } do
	assert(string.find(overlay, needle, 1, true), "tutorial overlay has " .. needle)
end
for _, gone in { "PET_SIZE", "QUIPS", "Bolt", "dizzyUntil", "SLEEP_AFTER" } do
	assert(not string.find(overlay, gone, 1, true), "the mascot is gone: " .. gone)
end
-- The card lays itself out top to bottom; nothing in it may sit at a hard-coded y again.
local overlayFn = string.match(overlay, "local function TutorialOverlay%(_param%)(.-)\nlocal VERSION_ROW_H") or ""
assert(not string.find(overlayFn, "dockH", 1, true), "the step card sizes itself from its content")
assert(string.find(overlay, 'segments["s" .. n] = React.createElement("frame"', 1, true), "progress markers are visual and cannot skip required objectives")
assert(string.find(overlay, "TextSize = 11", 1, true), "skip control remains readable")
assert(string.find(overlay, "Size = UDim2.new(1, 0, 0, TapTarget)", 1, true), "tutorial actions keep full touch height")

local confirmStart = assert(overlay:find('ContextActionService:BindActionAtPriority("AstralForgeTutorialConfirm", ', 1, true))
local callbackStart = assert(overlay:find("function(_name, inputState)", confirmStart, true))
local callbackEnd = assert(overlay:find("end, false, 2300", callbackStart, true))
local stateRef = { current = {} }
local enum = require("@lune/roblox").Enum
local confirm = luau.load("return " .. overlay:sub(callbackStart, callbackEnd + 2), {
	environment = { stateRef = stateRef, Enum = enum },
})()
local nextCalls, ctaCalls = 0, 0
stateRef.current = { needsAction = true, met = false, exiting = false, requestNext = function() nextCalls += 1 end }
assert(confirm("", enum.UserInputState.Begin) == enum.ContextActionResult.Pass, "required target activation must reach the underlying button")
assert(confirm("", enum.UserInputState.End) == enum.ContextActionResult.Pass and nextCalls == 0, "unmet actions do not skip the tutorial")
stateRef.current.onCta = function() ctaCalls += 1 end
assert(confirm("", enum.UserInputState.Begin) == enum.ContextActionResult.Sink and ctaCalls == 1, "available CTA handles gamepad confirm once")
confirm("", enum.UserInputState.End)
assert(ctaCalls == 1, "key release must not repeat the CTA")
stateRef.current.met = true
confirm("", enum.UserInputState.Begin)
assert(nextCalls == 1, "completed steps advance")
stateRef.current.exiting = true
confirm("", enum.UserInputState.Begin)
assert(nextCalls == 1 and ctaCalls == 1, "exit transition rejects duplicate actions")

local focusStart = assert(overlay:find("local function constrainSelection()", 1, true))
local focusEnd = assert(overlay:find('local connection = GuiService:GetPropertyChangedSignal("SelectedObject")', focusStart, true))
local function node(parent, selectable)
	local value = { parent = parent, selectable = selectable, children = {} }
	function value:IsDescendantOf(other)
		local ancestor = self.parent
		while ancestor do
			if ancestor == other then return true end
			ancestor = ancestor.parent
		end
		return false
	end
	function value:GetDescendants() return self.children end
	function value:IsA(class) return class == "GuiButton" and self.selectable end
	return value
end
local root, target, dock = node(nil, false), node(nil, true), node(nil, false)
local targetChild, dockButton, outside = node(target, true), node(root, true), node(nil, true)
dock.children = { dockButton }
local rootRef, guide, dockRef = { current = root }, { current = { target = target } }, { current = dock }
local gui = { SelectedObject = outside }
local input = { GamepadEnabled = true }
local redirects, clears = 0, 0
local constrain = luau.load("local redirecting = false\n" .. overlay:sub(focusStart, focusEnd - 1) .. "\nreturn constrainSelection", {
	environment = {
		rootRef = rootRef, guide = guide, dockRef = dockRef, GuiService = gui, UserInputService = input,
		GamepadNavigationService = {
			AssignSelection = function(candidate)
				if not candidate.selectable then return false end
				gui.SelectedObject = candidate
				redirects += 1
				return true
			end,
			ClearSelection = function() gui.SelectedObject = nil; clears += 1 end,
		},
	},
})()
constrain()
assert(gui.SelectedObject == target and redirects == 1, "unrelated gamepad focus redirects to the required action")
gui.SelectedObject = targetChild
constrain()
assert(redirects == 1, "required target descendants retain focus")
gui.SelectedObject = dockButton
constrain()
assert(redirects == 1, "tutorial controls retain focus")
guide.current.target = nil
gui.SelectedObject = outside
constrain()
assert(gui.SelectedObject == dockButton and redirects == 2, "missing target falls back to tutorial controls")
dock.children = {}
gui.SelectedObject = outside
constrain()
assert(gui.SelectedObject == nil and clears == 1, "missing selectable controls clear unrelated focus")
input.GamepadEnabled = false
gui.SelectedObject = outside
constrain()
assert(gui.SelectedObject == outside, "mouse and keyboard selection are not hijacked")
local maskStart = assert(overlay:find("local function dim(", 1, true))
local maskEnd = assert(overlay:find("local spotlight =", maskStart, true))
local masks = overlay:sub(maskStart, maskEnd - 1)
assert(masks:find('createElement("textbutton"', 1, true) and masks:find("Selectable = false", 1, true), "tutorial masks block pointers without becoming gamepad targets")

print("verify_tutorial: ok")
