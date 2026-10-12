-- Run with: lune run scripts/verify_layout.luau
-- These assertions exercise the pure device-planning layer without Studio.
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }

local mobileLayout = require("../src/Client/AstralForge/CoreKit")("mobileLayout")
local planMobileLayout = mobileLayout.planMobileLayout
local scrollTail = mobileLayout.scrollTail

local TAP_TARGET = 48
local MIN_CONTENT_BUDGET = 120

local cases = {
	{ name = "phone portrait", width = 390, height = 844, desktop = false, mobile = true, landscape = false },
	{ name = "phone landscape", width = 844, height = 390, desktop = false, mobile = true, landscape = true },
	{ name = "short landscape", width = 640, height = 320, desktop = false, mobile = true, landscape = true },
	{ name = "tablet", width = 768, height = 1024, desktop = false, mobile = true, landscape = false },
	-- 4:3 tablet variants stay under the mobile planner (width < 900 / narrow).
	{ name = "tablet 4:3 landscape", width = 800, height = 600, desktop = false, mobile = true, landscape = true },
	{ name = "tablet 4:3 portrait", width = 720, height = 960, desktop = false, mobile = true, landscape = false },
	{ name = "foldable", width = 600, height = 700, desktop = false, mobile = true, landscape = false },
	{ name = "desktop", width = 1920, height = 1080, desktop = true, mobile = false, landscape = false },
	{ name = "1080p tv", width = 1920, height = 1080, desktop = true, mobile = false, landscape = false },
	{ name = "4k tv", width = 3840, height = 2160, desktop = true, mobile = false, landscape = false },
	{ name = "ultrawide", width = 3440, height = 1440, desktop = true, mobile = false, landscape = false },
	{ name = "pro max landscape", width = 932, height = 430, desktop = false, mobile = true, landscape = true },
	{ name = "iphone SE portrait", width = 375, height = 667, desktop = false, mobile = true, landscape = false },
	{ name = "portrait home indicator", width = 390, height = 844, desktop = false, mobile = true, landscape = false, bottomInset = 34, sideInset = 0 },
	{ name = "landscape notch", width = 844, height = 390, desktop = false, mobile = true, landscape = true, bottomInset = 21, sideInset = 59 },
	{ name = "short landscape notch", width = 640, height = 320, desktop = false, mobile = true, landscape = true, bottomInset = 34, sideInset = 44 },
	{ name = "keyboard open portrait", width = 390, height = 420, desktop = false, mobile = true, landscape = false, bottomInset = 0, sideInset = 0 },
	{ name = "keyboard open landscape", width = 844, height = 240, desktop = false, mobile = true, landscape = true, bottomInset = 0, sideInset = 0 },
}

for _, case in cases do
	local bottomInset = case.bottomInset or 0
	local sideInset = case.sideInset or 0
	local layout = planMobileLayout({
		width = case.width,
		height = case.height,
		orientationWidth = case.width,
		orientationHeight = case.height,
		compact = case.width < 900,
		tight = case.width < 700,
		short = case.height < 600,
		desktop = case.desktop,
		bottomInset = bottomInset,
		sideInset = sideInset,
	})
	assert(layout.mobile == case.mobile, case.name .. " mobile breakpoint")
	assert(layout.landscape == case.landscape, case.name .. " orientation")
	assert(layout.contentBudget > 0, case.name .. " content budget")
	assert(layout.sideSafe >= 0 and layout.bottomSafe >= 0, case.name .. " safe padding")
	assert(layout.sideSafe >= sideInset, case.name .. " side inset honored")
	assert(layout.tabBarH < case.height, case.name .. " tab bar fits")
	if layout.stack then
		assert(layout.workspaceHeaderH == 0, case.name .. " no duplicate workspace header on phone")
		assert(layout.contentBudget >= MIN_CONTENT_BUDGET, case.name .. " content budget healthy (>= " .. tostring(MIN_CONTENT_BUDGET) .. "), got " .. tostring(layout.contentBudget))
		assert(layout.contentBudget + layout.topbarRows + layout.workspaceHeaderH + layout.tabBarH + layout.panelGap + 4 <= case.height,
			case.name .. " content fits safe height")
		local tabCore = layout.tabBarH - layout.bottomSafe
		assert(tabCore >= TAP_TARGET, case.name .. " tab tap target >= " .. tostring(TAP_TARGET) .. ", got " .. tostring(tabCore))
		if bottomInset > 0 then
			assert(layout.bottomSafe >= bottomInset, case.name .. " bottomSafe >= bottomInset")
		end
		if sideInset > 0 then
			assert(layout.sideSafe >= sideInset, case.name .. " sideSafe >= sideInset")
		end
		assert(layout.topbarRows + layout.tabBarH < case.height * 0.7, case.name .. " chrome does not dominate viewport")
		local tail = scrollTail(true, layout.bottomSafe, if layout.landscape then 48 else 56)
		assert(tail >= layout.bottomSafe + 40, case.name .. " scrollTail clears chrome (" .. tostring(tail) .. ")")
		assert(layout.topbarRows <= (if layout.landscape then 36 else 52), case.name .. " compact mobile header")
	else
		assert(layout.tabBarH == 0, case.name .. " desktop has no tab bar")
		assert(scrollTail(false, 0, 40) == 40, case.name .. " desktop scrollTail is base only")
	end
end

print("[INFO] [TEST] responsive layout cases passed | Count: " .. tostring(#cases))

-- Sweep: every phone/tablet size on a 20px grid, with the insets that
-- orientation really has (home indicator in portrait, notch + home bar in
-- landscape), must keep the same promises as the named cases above.
do
	local swept = 0
	for width = 320, 1400, 20 do
		for height = 280, 1400, 20 do
			local portrait = height > width
			local insetSets = if portrait then { { 0, 0 }, { 34, 0 } } else { { 0, 0 }, { 21, 47 } }
			for _, insets in insetSets do
				local bottomInset, sideInset = insets[1], insets[2]
				local layout = planMobileLayout({
					width = width,
					height = height,
					orientationWidth = width,
					orientationHeight = height,
					compact = width < 1100,
					tight = width < 840,
					short = height < 740,
					desktop = false,
					bottomInset = bottomInset,
					sideInset = sideInset,
				})
				local label = string.format("%dx%d (insets %d/%d)", width, height, bottomInset, sideInset)
				assert(layout.contentBudget > 0, label .. " content budget")
				assert(layout.sideSafe >= sideInset and layout.bottomSafe >= 0, label .. " safe padding")
				if layout.stack then
					assert(layout.contentBudget >= MIN_CONTENT_BUDGET, label .. " content budget " .. tostring(layout.contentBudget))
					assert(layout.topbarRows + layout.tabBarH < height * 0.7, label .. " chrome dominates the screen")
					assert(layout.tabBarH - layout.bottomSafe >= TAP_TARGET, label .. " tab tap target")
					assert(layout.tabBarSlots * 64 <= width - layout.sideSafe * 2 + 1, label .. " tab slots overflow the width")
					assert(layout.bottomSafe >= bottomInset, label .. " home indicator honored")
				end
				swept += 1
			end
		end
	end
	print("[INFO] [TEST] mobile planner sweep passed | screens: " .. tostring(swept))
end

-- PageScaffold fill/minHeight planner (pure; mirrors pageScaffoldPlan.luau).
local planFillHeight = require("../src/Client/AstralForge/LayoutKit")("pageScaffoldPlan").planFillHeight

local scaffoldCases = {
	{
		name = "fill honors minHeight when viewport is tight",
		available = 200,
		gap = 10,
		tailPad = 8,
		sections = {
			{ id = "hero", height = 80 },
			{ id = "list", fill = true, minHeight = 120 },
			{ id = "actions", height = 48 },
		},
		-- 200 - 80 - 48 - 20 - 8 = 44, clamped to minHeight 120
		expect = 120,
	},
	{
		name = "fill expands into leftover space",
		available = 640,
		gap = 10,
		tailPad = 8,
		sections = {
			{ id = "hero", height = 100 },
			{ id = "list", fill = true, minHeight = 120 },
			{ id = "actions", height = 56 },
		},
		-- 640 - 100 - 56 - 20 - 8 = 456
		expect = 456,
	},
	{
		name = "no fill section yields zero",
		available = 400,
		gap = 8,
		tailPad = 0,
		sections = {
			{ id = "a", height = 40 },
			{ id = "b", height = 40 },
		},
		expect = 0,
	},
	{
		name = "default minHeight is 120",
		available = 100,
		gap = 0,
		tailPad = 0,
		sections = {
			{ id = "list", fill = true },
		},
		expect = 120,
	},
	{
		name = "fill honors intrinsic content height above leftover",
		available = 400,
		gap = 10,
		tailPad = 8,
		sections = {
			{ id = "header", height = 56 },
			{ id = "tabs", height = 48 },
			-- leftover = 400 - 56 - 48 - 20 - 8 = 268; content floor 520 wins
			{ id = "body", fill = true, minHeight = 160, height = 520 },
		},
		expect = 520,
	},
	{
		name = "fill expands when content is shorter than leftover",
		available = 640,
		gap = 10,
		tailPad = 8,
		sections = {
			{ id = "header", height = 56 },
			{ id = "tabs", height = 48 },
			-- leftover = 640 - 56 - 48 - 20 - 8 = 508; content floor 200 loses
			{ id = "body", fill = true, minHeight = 160, height = 200 },
		},
		expect = 508,
	},
}

for _, case in scaffoldCases do
	local got = planFillHeight(case.sections, case.available, case.gap, case.tailPad)
	assert(got == case.expect, case.name .. " expected " .. tostring(case.expect) .. " got " .. tostring(got))
end

print("[INFO] [TEST] pageScaffold fill/minHeight cases passed | Count: " .. tostring(#scaffoldCases))

local planFittedHeights = require("../src/Client/AstralForge/LayoutKit")("pageScaffoldPlan").planFittedHeights
local fitted = planFittedHeights({
	{ id = "hero", height = 278 },
	{ id = "notes", height = 196 },
}, 367, 8, 8)
assert(fitted[1] == 359, "partial second section grows the first so the fold is clean, got " .. tostring(fitted[1]))
assert(fitted[2] == 196, "the following section keeps its height")
local fittedAll = planFittedHeights({
	{ id = "hero", height = 200 },
	{ id = "notes", height = 140 },
}, 400, 8, 8)
assert(fittedAll[1] == 200 and fittedAll[2] == 140, "sections that already fit stay at their design height")
local fittedFirst = planFittedHeights({
	{ id = "hero", height = 420 },
	{ id = "notes", height = 140 },
}, 367, 8, 8)
assert(fittedFirst[1] == 420, "a section taller than the window is left unchanged")
local unstretched = planFittedHeights({
	{ id = "hero", height = 278, stretch = false },
	{ id = "notes", height = 196 },
}, 367, 8, 8)
assert(unstretched[1] == 278, "a section with stretch = false keeps its height at the fold")
print("[INFO] [TEST] pageScaffold fold fit passed")

-- An inset scaffold must plan against the space left inside its padding, or the fill section
-- overflows by twice the inset and the page scrolls its first row out of view (chat tabs).
do
	local layoutSource = require("@lune/fs").readFile("src/Client/AstralForge/LayoutKit.luau")
	assert(layoutSource:find("available - inset * 2", 1, true), "PageScaffold subtracts its inset from the measured height")
	assert(layoutSource:find("planFittedHeights(planSections, usable", 1, true), "fitted heights use the usable height")
	assert(layoutSource:find("planOverflow(sections, usable", 1, true), "overflow uses the usable height")
	local inset, gap, tail, host = 12, 8, 8, 600
	local sections = { { id = "tabs", height = 92 }, { id = "messages", fill = true, minHeight = 120 }, { id = "input", height = 64 } }
	local heights = planFittedHeights(sections, host - inset * 2, gap, tail)
	local total = inset * 2 + tail + gap * (#sections - 1)
	for _, h in heights do
		total += h
	end
	assert(total <= host, "inset scaffold content fits its host, got " .. tostring(total) .. " > " .. tostring(host))
	print("[INFO] [TEST] pageScaffold inset fit passed")
end
