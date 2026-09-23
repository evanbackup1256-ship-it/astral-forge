-- Run with: lune run scripts/verify_layout.luau
-- These assertions exercise the pure device-planning layer without Studio.
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }

local mobileLayout = require("../src/Client/AstralForge/mobileLayout")
local planMobileLayout = mobileLayout.planMobileLayout
local scrollTail = mobileLayout.scrollTail

local TAP_TARGET = 48
local MIN_CONTENT_BUDGET = 120

local cases = {
	{ name = "phone portrait", width = 390, height = 844, desktop = false, mobile = true, landscape = false },
	{ name = "phone landscape", width = 844, height = 390, desktop = false, mobile = true, landscape = true },
	{ name = "short landscape", width = 640, height = 320, desktop = false, mobile = true, landscape = true },
	{ name = "tablet", width = 768, height = 1024, desktop = false, mobile = true, landscape = false },
	{ name = "foldable", width = 600, height = 700, desktop = false, mobile = true, landscape = false },
	{ name = "desktop", width = 1920, height = 1080, desktop = true, mobile = false, landscape = false },
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
