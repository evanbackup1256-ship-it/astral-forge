--!strict
-- Pure-module extract guards: layoutSectionPlan / navRouteTable / vaultCollectEligibility.
-- Mirrors verify_extract_modules style — require under Lune, assert behavior.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("./_memberfs")(require("@lune/fs"))

local LayoutSectionPlan = require("./_kit_loader")("LayoutKit")("layoutSectionPlan")
local NavRouteTable = require("../out/Client/AstralForge/CoreKit/navRouteTable")
local VaultCollectEligibility = require("../out/Client/AstralForge/CoreKit/vaultCollectEligibility")

-- --- VaultCollectEligibility -------------------------------------------------
assert(VaultCollectEligibility.MIN_COLLECTABLE == 0.01, "min collectable threshold")
assert(VaultCollectEligibility.isEligible(0) == false, "empty vault not eligible")
assert(VaultCollectEligibility.isEligible(0.009) == false, "below threshold")
assert(VaultCollectEligibility.isEligible(0.01) == true, "at threshold eligible")
assert(VaultCollectEligibility.isEligible(100) == true, "full vault eligible")
assert(VaultCollectEligibility.isNearFull(0.84) == false, "near-full false")
assert(VaultCollectEligibility.isNearFull(0.85) == true, "near-full true")
assert(VaultCollectEligibility.isFull(0.98) == false, "full false")
assert(VaultCollectEligibility.isFull(0.99) == true, "full true")

-- --- LayoutSectionPlan.planOverview ------------------------------------------
local phonePortrait = LayoutSectionPlan.planOverview({
	stack = true,
	phone = true,
	landscapePhone = false,
	wideOverview = false,
	ultraOverview = false,
	rebirthVisible = true,
	domainVisible = true,
	countdownInPage = false,
	chromePanelGap = 10,
	layoutPanelGap = 14,
})
assert(phonePortrait.heroH == 320, "phone portrait hero")
assert(phonePortrait.rebirthH == 300, "phone portrait rebirth")
assert(phonePortrait.domainH == 320, "phone portrait domain")
assert(phonePortrait.notesH == 168, "phone portrait notes")
assert(phonePortrait.opsH == 196, "phone portrait ops")
assert(phonePortrait.metricCardH == 92, "phone portrait metric card")
assert(phonePortrait.metricsH == 92 * 3 + 16, "phone portrait metrics")
assert(phonePortrait.countdownH == 0, "no countdown height")
assert(phonePortrait.sectionGap == 10, "stack uses chrome panel gap")
assert(phonePortrait.sectionCount == 5, "hero+notes+ops+rebirth+domain")
assert(phonePortrait.overviewTail == 56, "phone portrait tail")
assert(
	phonePortrait.contentIntrinsic
		== phonePortrait.topBandH
			+ phonePortrait.notesH
			+ phonePortrait.opsH
			+ phonePortrait.countdownH
			+ phonePortrait.rebirthH
			+ phonePortrait.domainH
			+ phonePortrait.sectionGap * 4,
	"phone portrait intrinsic"
)

local landscapePhone = LayoutSectionPlan.planOverview({
	stack = true,
	phone = true,
	landscapePhone = true,
	wideOverview = false,
	ultraOverview = false,
	rebirthVisible = false,
	domainVisible = false,
	countdownInPage = true,
	chromePanelGap = 8,
	layoutPanelGap = 14,
})
assert(landscapePhone.heroH == 208, "landscape phone hero")
assert(landscapePhone.notesH == 132, "landscape phone notes")
assert(landscapePhone.opsH == 156, "landscape phone ops")
assert(landscapePhone.countdownH == 128, "landscape phone countdown")
assert(landscapePhone.rebirthH == 0 and landscapePhone.domainH == 0, "hidden sections zero")
assert(landscapePhone.sectionCount == 4, "top+notes+ops+countdown")
assert(landscapePhone.overviewTail == 48, "landscape phone tail")

local wideDesktop = LayoutSectionPlan.planOverview({
	stack = false,
	phone = false,
	landscapePhone = false,
	wideOverview = true,
	ultraOverview = false,
	rebirthVisible = true,
	domainVisible = false,
	countdownInPage = false,
	chromePanelGap = 10,
	layoutPanelGap = 14,
})
assert(wideDesktop.heroH == 258, "wide desktop hero")
assert(wideDesktop.metricsH == wideDesktop.heroH, "wide metrics matches hero")
assert(wideDesktop.topBandH == wideDesktop.heroH, "wide top band collapses")
assert(wideDesktop.sectionGap == 16, "wide gap")
assert(wideDesktop.rebirthH == 208, "wide rebirth")

local ultra = LayoutSectionPlan.planOverview({
	stack = false,
	phone = false,
	landscapePhone = false,
	wideOverview = true,
	ultraOverview = true,
	rebirthVisible = true,
	domainVisible = true,
	countdownInPage = true,
	chromePanelGap = 10,
	layoutPanelGap = 14,
})
assert(ultra.heroH == 268, "ultra hero")
assert(ultra.sectionGap == 18, "ultra gap")
assert(ultra.sectionCount == 6, "all sections")
assert(ultra.countdownH == 152, "ultra countdown")

local narrowDesktop = LayoutSectionPlan.planOverview({
	stack = false,
	phone = false,
	landscapePhone = false,
	wideOverview = false,
	ultraOverview = false,
	rebirthVisible = false,
	domainVisible = false,
	countdownInPage = false,
	chromePanelGap = 10,
	layoutPanelGap = 14,
})
assert(narrowDesktop.heroH == 248, "default desktop hero")
assert(narrowDesktop.metricsH == 104, "default metrics")
assert(narrowDesktop.sectionGap == 14, "layout panel gap")
assert(narrowDesktop.topBandH == 248 + 104 + 14, "stacked top band")

-- --- LayoutSectionPlan.planWorkspace -----------------------------------------
local desktopWs = LayoutSectionPlan.planWorkspace({
	keyboardCompact = false,
	stack = false,
	landscape = false,
	workspaceHeaderH = 0,
	layoutWorkspaceHeaderHeight = 86,
	tapTarget = 48,
	showNextGoal = true,
})
assert(desktopWs.headerHeight == 86, "desktop workspace header")
assert(desktopWs.unlockH == 32, "desktop next-goal strip")

local phoneWs = LayoutSectionPlan.planWorkspace({
	keyboardCompact = false,
	stack = true,
	landscape = false,
	workspaceHeaderH = 0,
	layoutWorkspaceHeaderHeight = 86,
	tapTarget = 48,
	showNextGoal = true,
})
assert(phoneWs.headerHeight == 0, "phone stack collapses workspace header")
assert(phoneWs.unlockH == 0, "no unlock strip without header")

local keyboardWs = LayoutSectionPlan.planWorkspace({
	keyboardCompact = true,
	stack = false,
	landscape = false,
	workspaceHeaderH = 86,
	layoutWorkspaceHeaderHeight = 86,
	tapTarget = 48,
	showNextGoal = true,
})
assert(keyboardWs.headerHeight == 48, "keyboard compact uses tap target")
assert(keyboardWs.unlockH == 0, "keyboard hides next-goal")

local landscapeWs = LayoutSectionPlan.planWorkspace({
	keyboardCompact = true,
	stack = false,
	landscape = true,
	workspaceHeaderH = 86,
	layoutWorkspaceHeaderHeight = 86,
	tapTarget = 48,
	showNextGoal = true,
})
assert(landscapeWs.headerHeight == 0, "landscape keyboard collapses header")

-- --- NavRouteTable -----------------------------------------------------------
assert(#NavRouteTable.PRIMARY_ROUTES == 6, "primary route count")
assert(#NavRouteTable.MORE_ROUTES == 24, "more routes carry no minigames; the Reactor folded into the Star Foundry")
assert(NavRouteTable.PRIMARY_ROUTES[1].id == "Overview", "primary starts Overview")
assert(NavRouteTable.find("Trade") ~= nil, "find Trade")
assert(NavRouteTable.find("Trade").accentKey == "mint", "Trade accent key")
assert(NavRouteTable.find("Missing") == nil, "missing route")
assert(NavRouteTable.isNavRoute("Credits") == true, "Credits is nav")
assert(NavRouteTable.isPageRoute("Credits") == false, "Credits not PageRouter page")
assert(NavRouteTable.isPageRoute("Overview") == true, "Overview is page")
assert(NavRouteTable.isPageRoute("Workshop") == true, "Workshop is page")
assert(#NavRouteTable.PAGE_ROUTES == 30, "page routes carry no minigames")
assert(NavRouteTable.find("Charts") == nil and NavRouteTable.find("Cipher") == nil and NavRouteTable.find("Salvage") == nil and NavRouteTable.find("Trials") == nil, "retired minigames have no navigation")

local ids = NavRouteTable.allNavIds()
assert(#ids == #NavRouteTable.PRIMARY_ROUTES + #NavRouteTable.MORE_ROUTES, "all nav ids")
local seen = {}
for _, id in ids do
	assert(seen[id] == nil, "duplicate nav id " .. id)
	seen[id] = true
end
-- Rail groups: every nav route sits in exactly one group, so grouping hides nothing.
local grouped = {}
for _, group in NavRouteTable.NAV_GROUPS do
	assert(type(group.key) == "string" and group.label ~= "", "group needs a key and label")
	for _, id in group.routes do
		assert(seen[id], "group " .. group.key .. " lists unknown route " .. id)
		assert(grouped[id] == nil, id .. " is in two rail groups")
		grouped[id] = group.key
		assert(NavRouteTable.groupOf(id) == group.key, "groupOf " .. id)
	end
end
for _, id in ids do
	assert(grouped[id] ~= nil, id .. " is in no rail group")
end
-- Every page route except nothing — Chat/Admin are both nav + page.
-- Anomaly (Shift Plan) and Continuum (Next Rank) left the nav for Star Charts and Signal Cipher;
-- they stay as link-only pages (deep links only; Overview now points at Signal Cipher).
local LINK_ONLY = { Anomaly = true, Continuum = true }
for _, pageId in NavRouteTable.PAGE_ROUTES do
	assert(LINK_ONLY[pageId] or NavRouteTable.isNavRoute(pageId), "page route " .. pageId .. " must appear in nav tables")
end

-- --- Source wiring + HARD constraints ----------------------------------------
local routerSrc = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local overviewSrc = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau#OverviewView")
local mainSrc = fs.readFile("src/Client/AstralForge/UiCore.luau#MainGame")
local navSrc = fs.readFile("src/Client/AstralForge/CoreKit.luau#appNav")
local planSrc = fs.readFile("src/Client/AstralForge/LayoutKit.luau#layoutSectionPlan")
local routeSrc = fs.readFile("src/Client/AstralForge/CoreKit.luau#navRouteTable")
local vaultSrc = fs.readFile("src/Client/AstralForge/CoreKit.luau#vaultCollectEligibility")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(overviewSrc, "LayoutSectionPlan.planOverview", 1, true), "OverviewView must plan Overview via LayoutSectionPlan")
assert(string.find(overviewSrc, "VaultCollectEligibility.isEligible", 1, true), "OverviewView must use vault eligibility")
assert(string.find(overviewSrc, "PageReadyMath.OpsClaims", 1, true), "OverviewView must use OpsClaims")
assert(string.find(overviewSrc, "PageReadyMath.CountReadyQuests", 1, true), "OverviewView must use PageReadyMath")
assert(not string.find(overviewSrc, "PageReadyMath.CipherOpen", 1, true), "OverviewView must not advertise retired minigames")
assert(not string.find(overviewSrc, "PageReadyMath.AnomalyReady", 1, true), "OverviewView must not surface the retired Shift Plan")
local workshopSrc = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau#WorkshopView")
assert(string.find(workshopSrc, "PageBoardHeights.Machine", 1, true), "WorkshopView must use PageBoardHeights")
assert(string.find(routerSrc, 'lazyView("WorkshopView", "WorkshopView")', 1, true), "PageRouter must lazy-load WorkshopView")
local readySrc = fs.readFile("src/Client/AstralForge/LayoutKit.luau#pageReadyMath")
assert(not string.find(readySrc, "GetService", 1, true), "pageReadyMath must stay pure")
assert(string.find(readySrc, "function PageReadyMath.AnomalyReady", 1, true), "AnomalyReady must exist")
assert(string.find(readySrc, "function PageReadyMath.CipherOpen", 1, true), "CipherOpen must exist")
local boardSrc = fs.readFile("src/Client/AstralForge/CoreKit.luau#pageBoardHeights")
assert(not string.find(boardSrc, "GetService", 1, true), "pageBoardHeights must stay pure")
assert(string.find(mainSrc, "LayoutSectionPlan.planWorkspace", 1, true) or string.find(fs.readFile("src/Client/AstralForge/UiCore.luau#WorkspaceChrome"), "LayoutSectionPlan.planWorkspace", 1, true), "WorkspaceChrome must plan Workspace via LayoutSectionPlan")
assert(string.find(fs.readFile("src/Client/AstralForge/UiCore.luau#WorkspaceChrome"), "VaultCollectEligibility.isEligible", 1, true), "WorkspaceChrome must use vault eligibility")
assert(string.find(mainSrc, "NetworkPolicy.Cooldown", 1, true), "MainGame must use NetworkPolicy")
assert(string.find(navSrc, "navRouteTable", 1, true), "appNav must require navRouteTable")
assert(string.find(navSrc, "NavRouteTable.PRIMARY_ROUTES", 1, true), "appNav must build PRIMARY from table")
assert(string.find(navSrc, "NavRouteTable.MORE_ROUTES", 1, true), "appNav must build MORE from table")

-- Inline thresholds should not reappear in wired call sites (eligibility module owns them).
assert(not string.find(routerSrc, "asFlux(state.Vault) >= 0.01", 1, true), "PageRouter must not inline collect threshold")
assert(not string.find(mainSrc, "asFlux(state.Vault) >= 0.01", 1, true), "MainGame must not inline collect threshold")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { routerSrc, mainSrc, navSrc, planSrc, routeSrc, vaultSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(planSrc, "GetService", 1, true), "layoutSectionPlan must stay pure")
assert(not string.find(routeSrc, "GetService", 1, true), "navRouteTable must stay pure")
assert(not string.find(vaultSrc, "GetService", 1, true), "vaultCollectEligibility must stay pure")
assert(not string.find(planSrc, "require(", 1, true), "layoutSectionPlan must not require")
assert(not string.find(routeSrc, "require(", 1, true), "navRouteTable must not require")
assert(not string.find(vaultSrc, "require(", 1, true), "vaultCollectEligibility must not require")

print("[INFO] [TEST] pagerouter/maingame extracts passed | layoutSectionPlan+navRouteTable+vaultCollectEligibility")
