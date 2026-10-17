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
	"TextWrapped = true",
	"Position = UDim2.new(0.5, 0, 0, 69)",
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
assert(not string.find(toasts, "ToastRail", 1, true), "phones get notices from the island under the header, not a toast stack")
local events = fs.readFile("src/Client/AstralForge/UiCore.luau#serverEventsUi")
assert(not string.find(events, "ServerEventBanner", 1, true), "phones see the event in the island, not a floating banner")
local moments = fs.readFile("src/Client/AstralForge/UiCore.luau#levelMoments")
assert(not string.find(moments, "SurgeChip", 1, true), "the surge is an island buff, not a floating chip")
local shellChrome = fs.readFile("src/Client/AstralForge/UiCore.luau#AppShellChrome")
assert(not string.find(shellChrome, "MobilePreviewGate", 1, true), "the 'mobile is a preview' gate is gone")
local eventWidthAt = assert(string.find(shell, "local eventW =", 1, true))
local resourceRoomAt = assert(string.find(shell, "local room =", 1, true))
assert(eventWidthAt < resourceRoomAt, "active event width is reserved before sizing mobile resources")
assert(string.find(shell, "+ playersW + eventW + 22", 1, true), "mobile resources reserve the event button")
assert(string.find(shell, "local playersW = math.min(44, barHeight)", 1, true), "mobile header actions keep a 44px touch target")
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau#ui")
assert(string.find(ui, "local fieldInset = if chrome.stack or (not searchViewport.desktop and UserInputService.TouchEnabled) then 0 else 4", 1, true), "mobile search fields use their full touch height")
local social = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau#ChatView")
assert(string.find(social, "local inputHeight = if condensed then 62 else INPUT_HEIGHT", 1, true), "mobile chat textbox keeps a 48px focus target")
assert(string.find(social, '"Message server…  (/help)"', 1, true), "mobile chat uses a readable short placeholder")
local mail = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau#MailboxView")
assert(string.find(mail, "Size = if stack then UDim2.new(1, -24, 0, TapTarget + 8)", 1, true), "mobile mail filters compensate for page scaling")
local shop = fs.readFile("src/Client/AstralForge/pages/PagesShop.luau")
assert(string.find(shop, 'Name = "DailyBuy",\n\t\tSize = UDim2.fromOffset(124, 48)', 1, true), "daily shop buy buttons keep a 48px touch target")

print("verify_mobile_shell: ok")
