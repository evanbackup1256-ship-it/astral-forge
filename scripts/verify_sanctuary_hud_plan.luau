--!strict
-- Guards for the sanctuary HUD plan (src/Client/AstralForge/sanctuaryHudPlan).
--
-- Sweeps a grid of screen sizes -- phones in both orientations, tablets,
-- laptops, ultrawides, tiny and giant windows -- with and without touch, and
-- holds every plan to the promises the HUD relies on:
--   1. every rectangle lies inside the safe area;
--   2. no two interactive rectangles overlap;
--   3. nothing interactive sits in the thumbstick zone;
--   4. touch targets are at least MIN_TAP on both sides;
--   5. touch screens never get dock columns (the edges belong to thumbs);
--   6. roomy desktops do get columns, and the plan is deterministic;
--   7. the HUD, the curtain docks and the touch controls all read the plan.
--
-- HARD: pure checks -- no Roblox instances.

local fs = require("@lune/fs")
local Plan = require("../src/Client/AstralForge/sanctuaryHudPlan")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local function describe(r): string
	return string.format("(%d,%d %dx%d)", r.x, r.y, r.w, r.h)
end

local named: { { string | number } } = {
	{ "iPhone SE portrait", 375, 627 },
	{ "iPhone SE landscape", 667, 355 },
	{ "iPhone 15 portrait", 393, 759 },
	{ "iPhone 15 landscape", 793, 361 },
	{ "Pixel 8 portrait", 412, 870 },
	{ "Pixel 8 landscape", 870, 380 },
	{ "small Android landscape", 640, 320 },
	{ "fold inner", 673, 841 },
	{ "iPad mini portrait", 744, 1093 },
	{ "iPad landscape", 1180, 780 },
	{ "iPad Pro landscape", 1366, 994 },
	{ "laptop", 1366, 704 },
	{ "1080p", 1920, 1036 },
	{ "1440p", 2560, 1396 },
	{ "ultrawide", 3440, 1396 },
	{ "4k", 3840, 2116 },
	{ "tiny window", 480, 300 },
	{ "tall narrow window", 420, 1000 },
}

local sizes: { { number } } = {}
for _, entry in named do
	table.insert(sizes, { entry[2] :: number, entry[3] :: number })
end
for width = 320, 3840, 160 do
	for height = 240, 2160, 120 do
		table.insert(sizes, { width, height })
	end
end

local checked = 0
local columnsSeen = 0
for _, size in sizes do
	for _, touch in { false, true } do
		local width, height = size[1], size[2]
		local plan = Plan.compute({ width = width, height = height, touch = touch, dockEntries = 6 })
		local label = string.format("%dx%d touch=%s", width, height, tostring(touch))
		local shapes = Plan.interactive(plan)

		-- 1. Inside the safe area.
		for name, r in shapes do
			assert(Plan.inside(r, plan.width, plan.height), `{label}: {name} {describe(r)} leaves the screen`)
			assert(r.w > 0 and r.h > 0, `{label}: {name} has no size`)
		end
		assert(Plan.inside(plan.banner, plan.width, plan.height), `{label}: banner leaves the screen`)
		assert(Plan.inside(plan.sheet, plan.width, plan.height), `{label}: sheet leaves the screen`)
		if plan.hint ~= nil then
			assert(Plan.inside(plan.hint, plan.width, plan.height), `{label}: hint leaves the screen`)
		end

		-- 2. No overlaps between interactive pieces (or the key hint).
		local list: { { name: string, r: any } } = {}
		for name, r in shapes do
			table.insert(list, { name = name, r = r })
		end
		if plan.hint ~= nil then
			table.insert(list, { name = "hint", r = plan.hint })
		end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				assert(not Plan.overlaps(a.r, b.r), `{label}: {a.name} {describe(a.r)} overlaps {b.name} {describe(b.r)}`)
			end
		end

		-- 3. The thumbstick zone is clear.
		if touch then
			local zone = plan.stickZone
			assert(zone ~= nil, `{label}: touch plans need a thumbstick zone`)
			assert(zone.w >= 120 and zone.h >= 120, `{label}: thumbstick zone too small {describe(zone)}`)
			for name, r in shapes do
				assert(not Plan.overlaps(zone, r), `{label}: {name} {describe(r)} sits in the thumbstick zone {describe(zone)}`)
			end
		end

		-- 4. Tap targets.
		if touch then
			for _, name in { "strike", "recall", "jump", "run", "menuButton" } do
				local r = shapes[name]
				if r ~= nil then
					assert(r.w >= Plan.MIN_TAP and r.h >= Plan.MIN_TAP, `{label}: {name} {describe(r)} is under {Plan.MIN_TAP}px`)
				end
			end
			assert(plan.sheetRow >= Plan.MIN_TAP, `{label}: sheet rows under {Plan.MIN_TAP}px`)
		end

		-- 5. Columns only without touch, and only when they fit.
		if touch then
			assert(plan.dockMode == "menu", `{label}: touch screens use the menu button`)
		end
		if plan.dockMode == "columns" then
			columnsSeen += 1
			assert(plan.dockLeft ~= nil and plan.dockRight ~= nil and plan.menuButton == nil, `{label}: columns need both docks`)
			assert(plan.dockButton >= 46, `{label}: dock buttons shrank below 46px`)
			local expected = plan.dockButton * 6 + plan.dockGap * 5
			assert((plan.dockLeft :: any).h == expected, `{label}: dock column height mismatch`)
		else
			assert(plan.menuButton ~= nil and plan.dockLeft == nil, `{label}: menu mode needs the menu button only`)
		end
		checked += 1
	end
end

-- 6. Roomy desktops get columns; the same input gives the same plan.
for _, size in { { 1366, 704 }, { 1920, 1036 }, { 2560, 1396 } } do
	local plan = Plan.compute({ width = size[1], height = size[2], touch = false })
	assert(plan.dockMode == "columns", `{size[1]}x{size[2]} desktop should show dock columns`)
end
local a = Plan.compute({ width = 812, height = 375, touch = true })
local b = Plan.compute({ width = 812, height = 375, touch = true })
for name, r in Plan.interactive(a) do
	local other = (Plan.interactive(b) :: any)[name]
	assert(other ~= nil and other.x == r.x and other.y == r.y and other.w == r.w and other.h == r.h, "the plan must be deterministic")
end
assert(columnsSeen > 0, "the sweep never produced dock columns")
-- The Warden bar sits in the middle of the screen whenever there is room.
for _, size in { { 1920, 1036 }, { 2560, 1396 }, { 1366, 704 } } do
	local plan = Plan.compute({ width = size[1], height = size[2], touch = false })
	local middle = plan.warden.x + plan.warden.w / 2
	assert(math.abs(middle - plan.width / 2) <= 1, `{size[1]}x{size[2]}: the Warden bar is off centre ({middle} vs {plan.width / 2})`)
end

-- 7. Everyone reads the plan.
local hudSource = readSource("src/Client/AstralForge/sanctuaryHud.luau")
local chromeSource = readSource("src/Client/AstralForge/sanctuaryChrome.luau")
local controlsSource = readSource("src/Client/AstralForge/sanctuaryControls.luau")
assert(string.find(hudSource, "sanctuaryHudPlan", 1, true), "the HUD must place itself from the plan")
assert(string.find(chromeSource, "sanctuaryHudPlan", 1, true), "the curtain docks must follow the plan")
assert(string.find(controlsSource, "sanctuaryHudPlan", 1, true), "the touch controls must follow the plan")
assert(string.find(controlsSource, "CoreUISafeInsets", 1, true), "touch controls share the HUD's safe area")

print(`[INFO] [TEST] sanctuary HUD plan guards passed | {checked} screens, {columnsSeen} with dock columns`)
