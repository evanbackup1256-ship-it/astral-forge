--!strict
-- The v3 mobile shell:
--  * the tab bar picks the most-used pages that fit, Menu holds the rest, and the
--    current page shows on Menu when it isn't on the bar,
--  * every nav route is reachable from the Menu sheet (grouped like the PC rail),
--  * touch targets are at least TapTarget, the bar fits its icon and label,
--  * phone chrome doesn't stack on itself: toasts at the top, the event banner and
--    surge chip in the status slot above the tab bar, nothing left of the preview gate.

local fs = require("./_memberfs")(require("@lune/fs"))
local NavRouteTable = require("../src/Client/AstralForge/CoreKit")("navRouteTable")

local function set(list)
	local out = {}
	for _, id in list do
		out[id] = true
	end
	return out
end

-- Tab selection
local everything = set(NavRouteTable.allNavIds())
local tabs, behindMenu = NavRouteTable.mobileTabs(everything, 5, "Workshop")
assert(#tabs == 4 and tabs[1] == "Overview" and tabs[2] == "Workshop", "four most-used pages, then Menu")
assert(not behindMenu, "Workshop is on the bar")
tabs, behindMenu = NavRouteTable.mobileTabs(everything, 5, "Bazaar")
assert(behindMenu, "a page behind Menu shows on Menu")
tabs = NavRouteTable.mobileTabs(set({ "Overview", "Workshop", "Settings" }), 5, "Overview")
assert(#tabs == 2, "locked pages never take a tab")
tabs = NavRouteTable.mobileTabs(everything, 7, nil)
assert(#tabs == 6, "wider phones get more tabs")
for _, id in NavRouteTable.MOBILE_TAB_PRIORITY do
	assert(NavRouteTable.isNavRoute(id), id .. " is a real page")
end

-- Every page is reachable from the Menu sheet: it walks NAV_GROUPS and adds anything loose.
local grouped = {}
for _, group in NavRouteTable.NAV_GROUPS do
	for _, id in group.routes do
		grouped[id] = true
	end
end
for id in everything do
	assert(grouped[id], id .. " is in a menu section")
end

local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#MobileShell")
for _, needle in {
	"local function MenuSheet",
	"for order, group in NAV_GROUPS do",
	'addSection("More", "More", loose',
	"SHEET_SWIPE_CLOSE",
	'placeholder = "Find a page"',
	"OVERCHARGE_REPEAT",
	"setHolding(true)",
	"mobileTabs(availableIds, slots, page)",
	'Name = "Nav_" .. entry.id',
} do
	assert(string.find(shell, needle, 1, true), "mobile shell has " .. needle)
end

-- The bar fits its contents: icon + label inside the smallest (landscape) bar core.
local coreKit = fs.readFile("src/Client/AstralForge/CoreKit.luau#mobileLayout")
assert(string.find(coreKit, "local tabBarCore = if landscape then TAP_TARGET", 1, true), "landscape bar is a full tap target tall")
assert(string.find(shell, "Position = UDim2.new(0.5, 0, 0, if compactLabel then 32 else 36)", 1, true), "labels sit inside the bar")
assert(string.find(shell, "local height = TapTarget + 14", 1, true), "quick actions are a tap target tall")

-- Phone chrome placement
local toasts = fs.readFile("src/Client/AstralForge/UiCore.luau#notifications")
assert(string.find(toasts, "then UDim2.new(0.5, 0, 0, topInset)", 1, true), "phone toasts sit under the header")
local events = fs.readFile("src/Client/AstralForge/UiCore.luau#serverEventsUi")
assert(string.find(events, "UDim2.new(0, edge, 1, -(chrome.tabBarH + 8))", 1, true), "event banner in the status slot")
local moments = fs.readFile("src/Client/AstralForge/UiCore.luau#levelMoments")
assert(string.find(moments, "UDim2.new(0, edge, 1, -(chrome.tabBarH + 8 + 54))", 1, true), "surge chip above it")
local shellChrome = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(not string.find(shellChrome, "MobilePreviewGate", 1, true), "the 'mobile is a preview' gate is gone")

print("verify_mobile_shell: ok")
