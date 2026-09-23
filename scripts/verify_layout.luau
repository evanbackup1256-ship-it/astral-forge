-- Run with: lune run scripts/verify_layout.luau
-- These assertions exercise the pure device-planning layer without Studio.
Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }

local planMobileLayout = require("../src/Client/AstralForge/mobileLayout").planMobileLayout

local cases = {
	{ name = "phone portrait", width = 390, height = 844, desktop = false, mobile = true, landscape = false },
	{ name = "phone landscape", width = 844, height = 390, desktop = false, mobile = true, landscape = true },
	{ name = "short landscape", width = 640, height = 320, desktop = false, mobile = true, landscape = true },
	{ name = "tablet", width = 768, height = 1024, desktop = false, mobile = true, landscape = false },
	{ name = "foldable", width = 600, height = 700, desktop = false, mobile = true, landscape = false },
	{ name = "desktop", width = 1920, height = 1080, desktop = true, mobile = false, landscape = false },
	{ name = "ultrawide", width = 3440, height = 1440, desktop = true, mobile = false, landscape = false },
}

for _, case in cases do
	local layout = planMobileLayout({
		width = case.width,
		height = case.height,
		orientationWidth = case.width,
		orientationHeight = case.height,
		compact = case.width < 900,
		tight = case.width < 700,
		short = case.height < 600,
		desktop = case.desktop,
		bottomInset = 0,
		sideInset = 0,
	})
	assert(layout.mobile == case.mobile, case.name .. " mobile breakpoint")
	assert(layout.landscape == case.landscape, case.name .. " orientation")
	assert(layout.contentBudget > 0, case.name .. " content budget")
	assert(layout.sideSafe >= 0 and layout.bottomSafe >= 0, case.name .. " safe padding")
	assert(layout.tabBarH < case.height, case.name .. " tab bar fits")
	if layout.stack then
		assert(layout.contentBudget + layout.topbarRows + layout.workspaceHeaderH + layout.tabBarH + layout.panelGap + 4 <= case.height,
			case.name .. " content fits safe height")
	end
end

print("[INFO] [TEST] responsive layout cases passed | Count: " .. tostring(#cases))
