-- Run with: lune run scripts/verify_playability.luau
-- Offline playability audit: PageScaffold hot pages, raw scroll allowlist,
-- overlay FocusClaim, and antilag softMotion gates. No Studio.
-- Does not touch vendor/ or Packages/.

local fs = require("@lune/fs")

------------------------------------------------------------------------
-- HARD: DataVersion <= 21, PlatformBadges zeroed, no vendor/Packages
------------------------------------------------------------------------
do
	local cfg = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
	local dv = tonumber(string.match(cfg, "DataVersion%s*=%s*(%d+)"))
	assert(dv ~= nil, "DataVersion missing")
	assert(dv <= 21, "DataVersion must stay <= 21, got " .. tostring(dv))
	assert(dv == 21, "DataVersion must remain pinned at 21")
	local badges = string.match(cfg, "PlatformBadges = %{(.-)\n\t%},")
	assert(badges, "PlatformBadges missing")
	local badgeCount = 0
	for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
		badgeCount += 1
		assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
	end
	assert(badgeCount > 0, "PlatformBadges empty")
end

------------------------------------------------------------------------
-- Hot primary pages: must import + mount PageScaffold
------------------------------------------------------------------------
-- Keep this list complete for every primary page migrated onto PageScaffold.
-- Overview lives in OverviewView; Mailbox stays dual-pane (no outer scaffold).
local HOT_PAGES = {
	"src/Client/AstralForge/pages/WorkshopView.luau",
	"src/Client/AstralForge/pages/OverviewView.luau",
	"src/Client/AstralForge/pages/WorldsView.luau",
	"src/Client/AstralForge/pages/RewardsView.luau",
	"src/Client/AstralForge/pages/WorkshopView.luau",
	"src/Client/AstralForge/pages/AdminView.luau",
	"src/Client/AstralForge/pages/AnomalyView.luau",
	"src/Client/AstralForge/pages/BoostsView.luau",
	"src/Client/AstralForge/pages/ChatView.luau",
	"src/Client/AstralForge/pages/CommandView.luau",
	"src/Client/AstralForge/pages/ContinuumView.luau",
	"src/Client/AstralForge/pages/ConvergenceView.luau",
	"src/Client/AstralForge/pages/CreditsView.luau",
	"src/Client/AstralForge/pages/CrewView.luau",
	"src/Client/AstralForge/pages/EchoForgeView.luau",
	"src/Client/AstralForge/pages/ForgePathView.luau",
	"src/Client/AstralForge/pages/GuildView.luau",
	"src/Client/AstralForge/pages/InventoryView.luau",
	"src/Client/AstralForge/pages/LabView.luau",
	"src/Client/AstralForge/pages/LeaderboardsView.luau",
	"src/Client/AstralForge/pages/MilestonesView.luau",
	"src/Client/AstralForge/pages/MissionsView.luau",
	"src/Client/AstralForge/pages/ResearchView.luau",
	"src/Client/AstralForge/pages/SettingsView.luau",
	"src/Client/AstralForge/pages/ShopView.luau",
	"src/Client/AstralForge/pages/StarGridView.luau",
	"src/Client/AstralForge/pages/StoryView.luau",
	"src/Client/AstralForge/pages/TradeView.luau",
	"src/Client/AstralForge/pages/WheelView.luau",
}

-- Playability scaffolding + hot pages must stay free of vendor/Packages coupling.
do
	local paths = {
		"src/Client/AstralForge/pageScaffold.luau",
		"src/Client/AstralForge/pageScaffoldPlan.luau",
		"src/Client/AstralForge/input/GamepadNavigationService.luau",
	}
	for _, path in HOT_PAGES do
		table.insert(paths, path)
	end
	for _, path in paths do
		local body = fs.readFile(path)
		assert(not string.find(body, "vendor/", 1, true), path .. " must not reference vendor/")
		assert(not string.find(body, "Packages/", 1, true), path .. " must not reference Packages/")
	end
end

local hotSet = {}
for _, path in HOT_PAGES do
	hotSet[path] = true
	assert(fs.isFile(path), "hot page missing: " .. path)
	local src = fs.readFile(path)
	assert(
		string.find(src, "pageScaffold", 1, true) and string.find(src, "PageScaffold", 1, true),
		path .. " must import PageScaffold"
	)
	assert(string.find(src, "createElement(PageScaffold", 1, true), path .. " must mount PageScaffold")
end

-- Completeness: every pages/*.luau that imports pageScaffold must be hot (or allowlisted).
local PAGE_SCAFFOLD_EXTRA_OK = {
	-- none today — keep empty so new scaffold imports force a HOT_PAGES update
}
local pagesDir = "src/Client/AstralForge/pages"
for _, name in fs.readDir(pagesDir) do
	if string.sub(name, -5) == ".luau" then
		local path = pagesDir .. "/" .. name
		local src = fs.readFile(path)
		if string.find(src, "pageScaffold", 1, true) then
			assert(
				hotSet[path] or PAGE_SCAFFOLD_EXTRA_OK[path],
				path .. " imports PageScaffold but is not in HOT_PAGES — extend the hot list"
			)
		end
	end
end

-- Hot list must also appear in the syntax parse gate (boot-critical coverage).
do
	local syntax = fs.readFile("scripts/_syntax_check.luau")
	for _, path in HOT_PAGES do
		assert(
			string.find(syntax, path, 1, true),
			"hot page missing from _syntax_check parse list: " .. path
		)
	end
end

------------------------------------------------------------------------
-- Raw ScrollingFrame canvas patterns on scaffold pages → fail unless allowlisted
------------------------------------------------------------------------
-- PageScaffold owns the outer AutomaticCanvasSize.Y scroll. Nested raw frames are
-- only OK when justified below (horizontal chips, dual-pane body). Prefer FlatList /
-- VirtualGrid / PageScaffold fill instead of page-local scrollingframe literals.
-- Chat message list migrated onto FlatList (virtualizedList owns the scroller) so the
-- raw-scroll allowlist stays empty — reintroduce entries only with a >40-char justification.
local RAW_SCROLL_ALLOWLIST = {
}

local RAW_SCROLL_BUDGET = {
}

local function countRawScrollingFrames(src)
	local count = 0
	for _ in string.gmatch(src, 'createElement%(%s*"scrollingframe"') do
		count += 1
	end
	-- Also catch PascalCase if any page still emits it.
	for _ in string.gmatch(src, 'createElement%(%s*"ScrollingFrame"') do
		count += 1
	end
	return count
end

for _, path in HOT_PAGES do
	local src = fs.readFile(path)
	local rawCount = countRawScrollingFrames(src)
	local reason = RAW_SCROLL_ALLOWLIST[path]
	if rawCount > 0 then
		assert(
			reason ~= nil and #reason > 40,
			path .. " has " .. tostring(rawCount) .. " raw scrollingframe(s); migrate to PageScaffold or document allowlist justification"
		)
		-- Allowlisted pages must still show CanvasSize / AutomaticCanvasSize near the raw frame
		-- so we are auditing the real canvas pattern, not a false-positive element name.
		assert(
			string.find(src, "CanvasSize", 1, true) and string.find(src, "AutomaticCanvasSize", 1, true),
			path .. " allowlisted raw scroll must still declare CanvasSize/AutomaticCanvasSize"
		)
		assert(
			string.find(src, "ScrollingDirection", 1, true),
			path .. " allowlisted raw scroll must declare ScrollingDirection (X vs Y justification)"
		)
		local budget = RAW_SCROLL_BUDGET[path]
		if budget ~= nil then
			assert(
				rawCount <= budget,
				path .. " raw scrollingframe budget " .. tostring(budget) .. " exceeded: " .. tostring(rawCount)
			)
		end
	else
		assert(reason == nil, path .. " is allowlisted for raw scroll but has none — drop stale allowlist entry")
	end
end

------------------------------------------------------------------------
-- Mailbox dual-pane: pinned CLAIM/ARCHIVE footer (no outer PageScaffold double-scroll)
------------------------------------------------------------------------
do
	local path = "src/Client/AstralForge/pages/MailboxView.luau"
	local src = fs.readFile(path)
	assert(not string.find(src, "pageScaffold", 1, true), path .. " must not nest PageScaffold (double-scroll trap)")
	assert(string.find(src, "createElement(FlatList", 1, true), path .. " must FlatList inbox and body catalogs")
	assert(not string.find(src, 'createElement("scrollingframe"', 1, true), path .. " must not keep raw body scrollingframe")
	assert(string.find(src, "CLAIM", 1, true) and string.find(src, "ARCHIVE", 1, true), path .. " must expose CLAIM/ARCHIVE")
	assert(string.find(src, "Position = UDim2.new(0, 0, 1, -footerH)", 1, true), path .. " must pin footer to bottom")
	assert(string.find(src, "stackListH", 1, true), path .. " must reserve stack list height so detail actions stay reachable")
	assert(string.find(src, "0.34, -7", 1, true) and string.find(src, "0.66, -7", 1, true), path .. " must keep desktop split chrome widths")
end

------------------------------------------------------------------------
-- Studio edge harden (offline): Trade Confirm pin, StoryBeat CTA pin, LB wrap tabs
------------------------------------------------------------------------
do
	local trade = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
	assert(string.find(trade, "buildConfirmActions", 1, true), "TradeView must share Confirm panel builder")
	assert(string.find(trade, "CONFIRM_TRADE_PANEL", 1, true), "TradeView must mark shared Confirm panel")
	local story = fs.readFile("src/Client/AstralForge/pages/StoryView.luau")
	assert(string.find(story, "estimatedBodyH", 1, true), "StoryBeat must keep content-floor estimate")
	assert(string.find(story, "measureWrappedTextHeight", 1, true), "StoryBeat content floor must measure wrap")
	assert(string.find(story, "Position = UDim2.new(0, 0, 1, -actionsH)", 1, true), "StoryBeat must pin Continue/Back")
	assert(string.find(story, "Pin Continue/Back", 1, true), "StoryBeat must document pinned CTAs")
	local boards = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
	assert(not string.find(boards, 'createElement("scrollingframe"', 1, true), "Leaderboards must not X-scroll filter tabs")
	assert(string.find(boards, "filterColumns = 4", 1, true), "Leaderboards must wrap RANK_TABS in a 4-column grid")
	assert(string.find(boards, "ClipsDescendants = false", 1, true), "Leaderboards filter strip must not clip selection")
	assert(string.find(boards, "FlatList", 1, true), "Leaderboards must FlatList long rank catalogs")
	local lab = fs.readFile("src/Client/AstralForge/pages/LabView.luau")
	assert(string.find(lab, "FlatList", 1, true), "Lab must FlatList long order catalogs")
	assert(string.find(lab, "virtOrders", 1, true), "Lab must gate order virtualization")
	local forge = fs.readFile("src/Client/AstralForge/pages/ForgePathView.luau")
	assert(string.find(forge, "FlatList", 1, true), "ForgePath must FlatList step catalog")
	local wheel = fs.readFile("src/Client/AstralForge/pages/WheelView.luau")
	assert(string.find(wheel, "FlatList", 1, true), "Wheel must FlatList prize table")
	assert(string.find(wheel, "PrizeCatalogRow", 1, true), "Wheel prize table must render PrizeCatalogRow")
	local command = fs.readFile("src/Client/AstralForge/pages/CommandView.luau")
	assert(string.find(command, "VirtualGrid", 1, true), "Command grid must stay virtual")
	-- Expeditions / Weekly / Season long catalogs must VirtualGrid (or FlatList) — never map-mount.
	assert(string.find(command, "count = #ops.Expeditions", 1, true), "Command Expeditions must VirtualGrid count")
	assert(string.find(command, "count = #command.Weekly", 1, true), "Command Weekly must VirtualGrid count")
	assert(string.find(command, "count = #ops.SeasonTiers", 1, true), "Command Season must VirtualGrid count")
	assert(string.find(command, "Weekly jobs", 1, true), "Command Weekly jobs header must stay")
	assert(string.find(command, "overscanRows = if softMotion then 0 else 1", 1, true), "Command catalogs must softMotion-gate overscan")
end

------------------------------------------------------------------------
-- Overlay FocusClaim (modal overlays that steal gamepad focus)
------------------------------------------------------------------------
local FOCUS_OVERLAYS = {
	"src/Client/AstralForge/OfflineRewardsOverlay.luau",
	"src/Client/AstralForge/DomainExpansionOverlay.luau",
	"src/Client/AstralForge/FeedbackOverlay.luau",
	"src/Client/AstralForge/purchaseOverlay.luau",
	"src/Client/AstralForge/pages/CrateRevealOverlay.luau",
	"src/Client/AstralForge/AdminPrankOverlay.luau",
	"src/Client/AstralForge/pages/CreditsView.luau",
	"src/Client/AstralForge/DomainSkillTree.luau",
	"src/Client/AstralForge/onboarding.luau",
}
-- Non-modal / persistent HUD overlays intentionally omit FocusClaim:
-- PlayerlistOverlay (persistent HUD list), MobilePreviewGate (boot gate).

for _, path in FOCUS_OVERLAYS do
	assert(fs.isFile(path), "overlay missing: " .. path)
	local src = fs.readFile(path)
	assert(
		string.find(src, "GamepadNavigationService.BeginOverlayFocus", 1, true),
		path .. " must BeginOverlayFocus"
	)
	assert(
		string.find(src, "GamepadNavigationService.FocusClaim", 1, true),
		path .. " must FocusClaim"
	)
end

-- High-traffic pinned CTAs (page chrome, not full-screen overlays) still FocusClaim.
do
	local trade = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
	assert(string.find(trade, "GamepadNavigationService.BeginOverlayFocus", 1, true), "TradeView session must BeginOverlayFocus")
	assert(string.find(trade, "GamepadNavigationService.EndOverlayFocus", 1, true), "TradeView session must EndOverlayFocus")
	assert(string.find(trade, "GamepadNavigationService.FocusClaim", 1, true), "TradeView session must FocusClaim")
	assert(string.find(trade, "TradeSessionActions", 1, true), "TradeView must host FocusClaim on TradeSessionActions")
	local story = fs.readFile("src/Client/AstralForge/pages/StoryView.luau")
	assert(string.find(story, "GamepadNavigationService.FocusClaim", 1, true), "StoryBeat must FocusClaim pinned Continue/Back")
	assert(string.find(story, "StoryBeatActions", 1, true), "StoryBeat must name the pinned actions host")
	local mailbox = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
	assert(string.find(mailbox, "GamepadNavigationService.FocusClaim", 1, true), "Mailbox must FocusClaim CLAIM/ARCHIVE")
	assert(string.find(mailbox, "MailClaimActions", 1, true), "Mailbox must host FocusClaim on MailClaimActions")
	-- CLAIM/ARCHIVE footgun: parent clips=true buried claimSlide overshoot on short phones.
	do
		local hostStart = string.find(mailbox, 'Name = "MailClaimActions"', 1, true)
		assert(hostStart, "Mailbox MailClaimActions host missing")
		local hostSlice = string.sub(mailbox, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"Mailbox MailClaimActions host must keep ClipsDescendants = false"
		)
		assert(
			not string.find(hostSlice, "ClipsDescendants = true", 1, true),
			"Mailbox MailClaimActions must not clip CLAIM/ARCHIVE"
		)
	end
	local admin = fs.readFile("src/Client/AstralForge/pages/AdminView.luau")
	assert(string.find(admin, "GamepadNavigationService.FocusClaim", 1, true), "Admin must FocusClaim ARM/RUN")
	assert(string.find(admin, "AdminExecuteActions", 1, true), "Admin must host FocusClaim on AdminExecuteActions")
	assert(string.find(admin, "AdminConfirmRun", 1, true), "Admin ARM/RUN must be Confirm-tagged for FocusClaim")
	assert(string.find(admin, "Capacity or 0", 1, true), "Admin VAULT cell must show vault/capacity")
	assert(string.find(admin, "FlatList", 1, true), "Admin long player/command lists must FlatList")
	assert(string.find(admin, "createElement(PageScaffold", 1, true), "Admin must mount PageScaffold")
	assert(not string.find(admin, 'createElement("scrollingframe"', 1, true), "Admin must not keep raw scrollingframes under PageScaffold")
	local invCrates = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
	assert(string.find(invCrates, 'id = "crates"', 1, true), "Inventory Crates tab must stay named")
	assert(string.find(invCrates, "crateStride", 1, true), "Inventory Crates must FlatList with crateStride")
	assert(string.find(invCrates, "CRATE CHANNELS", 1, true), "Inventory Crates must keep CRATE CHANNELS header")
	local starGrid = fs.readFile("src/Client/AstralForge/pages/StarGridView.luau")
	assert(string.find(starGrid, "FlatList", 1, true), "StarGrid long node boards must FlatList")
	local boostsVirt = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
	assert(string.find(boostsVirt, "FlatList", 1, true), "Boosts long inventory must FlatList")
	local settingsVirt = fs.readFile("src/Client/AstralForge/pages/SettingsView.luau")
	assert(string.find(settingsVirt, "FlatList", 1, true), "Settings long section catalogs must FlatList")
	assert(string.find(settingsVirt, "virtSettings", 1, true), "Settings must gate catalog virtualization")
	assert(string.find(settingsVirt, "VIRT_SETTINGS_MIN", 1, true), "Settings must keep VIRT_SETTINGS_MIN threshold")
	assert(not string.find(settingsVirt, 'createElement("scrollingframe"', 1, true), "Settings must not keep raw scrollingframes under PageScaffold")
	local chatVirt = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
	assert(string.find(chatVirt, "FlatList", 1, true), "Chat message list must FlatList under PageScaffold fill")
	assert(not string.find(chatVirt, 'createElement("scrollingframe"', 1, true), "Chat must not keep raw scrollingframes (allowlist cleared)")
	assert(string.find(chatVirt, "headerHeight = topPad", 1, true), "Chat FlatList must stick short logs via headerHeight topPad")
	assert(string.find(chatVirt, "overscan = if softMotion then 0", 1, true), "Chat FlatList must softMotion-gate overscan")
	local rebirth = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
	assert(string.find(rebirth, "GamepadNavigationService.FocusClaim", 1, true), "RebirthPanel must FocusClaim REBIRTH/CONFIRM")
	assert(string.find(rebirth, "RebirthClaimActions", 1, true), "RebirthPanel must host FocusClaim on RebirthClaimActions")
	local continuum = fs.readFile("src/Client/AstralForge/pages/ContinuumView.luau")
	assert(string.find(continuum, "GamepadNavigationService.FocusClaim", 1, true), "Continuum must FocusClaim forge CTA")
	assert(string.find(continuum, "ContinuumClaimActions", 1, true), "Continuum must host FocusClaim on ContinuumClaimActions")
	local missions = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
	assert(string.find(missions, "GamepadNavigationService.FocusClaim", 1, true), "Missions must FocusClaim CLAIM ALL")
	assert(string.find(missions, "MissionClaimActions", 1, true), "Missions must host FocusClaim on MissionClaimActions")
	local lab = fs.readFile("src/Client/AstralForge/pages/LabView.luau")
	assert(string.find(lab, "GamepadNavigationService.FocusClaim", 1, true), "Lab must FocusClaim CLAIM ALL")
	assert(string.find(lab, "LabClaimActions", 1, true), "Lab must host FocusClaim on LabClaimActions")
	local anomaly = fs.readFile("src/Client/AstralForge/pages/AnomalyView.luau")
	assert(string.find(anomaly, "GamepadNavigationService.FocusClaim", 1, true), "Anomaly must FocusClaim PULSE/BANK strip")
	assert(string.find(anomaly, "AnomalyClaimActions", 1, true), "Anomaly must host FocusClaim on AnomalyClaimActions")
	local wheel = fs.readFile("src/Client/AstralForge/pages/WheelView.luau")
	assert(string.find(wheel, "GamepadNavigationService.FocusClaim", 1, true), "Wheel must FocusClaim SPIN CTA")
	assert(string.find(wheel, "WheelSpinClaimActions", 1, true), "Wheel must host FocusClaim on WheelSpinClaimActions")
	local forge = fs.readFile("src/Client/AstralForge/pages/ForgePathView.luau")
	assert(string.find(forge, "GamepadNavigationService.FocusClaim", 1, true), "ForgePath spotlight must FocusClaim")
	assert(string.find(forge, "ForgePathClaimActions", 1, true), "ForgePath must host FocusClaim on ForgePathClaimActions")
end

------------------------------------------------------------------------
-- Antilag softMotion usages on motion-heavy hot surfaces
------------------------------------------------------------------------
local SOFT_MOTION_FILES = {
	"src/Client/AstralForge/pages/ContinuumView.luau",
	"src/Client/AstralForge/pages/MilestonesView.luau",
	"src/Client/AstralForge/pages/MailboxView.luau",
	"src/Client/AstralForge/pages/LabView.luau",
	"src/Client/AstralForge/pages/MissionsView.luau",
	"src/Client/AstralForge/pages/AnomalyView.luau",
	"src/Client/AstralForge/pages/StarGridView.luau",
	"src/Client/AstralForge/pages/WorkshopView.luau",
	"src/Client/AstralForge/pages/OverviewView.luau",
	"src/Client/AstralForge/pages/WorldsView.luau",
	"src/Client/AstralForge/pages/RewardsView.luau",
	"src/Client/AstralForge/pages/CrateRevealOverlay.luau",
	"src/Client/AstralForge/pages/ShopView.luau",
	"src/Client/AstralForge/pages/WheelView.luau",
	"src/Client/AstralForge/pages/TradeView.luau",
	"src/Client/AstralForge/pages/StoryView.luau",
	"src/Client/AstralForge/pages/LeaderboardsView.luau",
	"src/Client/AstralForge/pages/BoostsView.luau",
	"src/Client/AstralForge/pages/InventoryView.luau",
	"src/Client/AstralForge/pages/ForgePathView.luau",
	"src/Client/AstralForge/pages/EchoForgeView.luau",
	"src/Client/AstralForge/pages/ResearchView.luau",
	"src/Client/AstralForge/pages/ConvergenceView.luau",
	"src/Client/AstralForge/pages/SettingsView.luau",
	"src/Client/AstralForge/pages/CommandView.luau",
	"src/Client/AstralForge/pages/GuildView.luau",
	"src/Client/AstralForge/pages/ChatView.luau",
	"src/Client/AstralForge/pages/CrewView.luau",
	"src/Client/AstralForge/pages/AdminView.luau",
	"src/Client/AstralForge/pages/RebirthPanel.luau",
	"src/Client/AstralForge/pages/CreditsView.luau",
}

for _, path in SOFT_MOTION_FILES do
	local src = fs.readFile(path)
	assert(string.find(src, "softMotion", 1, true), path .. " must define/use softMotion")
	assert(string.find(src, "antilag", 1, true), path .. " softMotion must consult antilag")
	-- Canonical gate: softMotion combines reduced/quiet motion with tier or allowAmbient.
	assert(
		string.find(src, "local softMotion =", 1, true),
		path .. " must declare local softMotion ="
	)
	-- Footgun: every softMotion assignment must reference antilag (tier and/or allowAmbient).
	for softLine in string.gmatch(src, "local softMotion = ([^\n]+)") do
		assert(
			string.find(softLine, "antilag", 1, true),
			path .. " softMotion must reference antilag on the assignment line: " .. softLine
		)
		assert(
			string.find(softLine, "allowAmbient", 1, true) or string.find(softLine, "tier", 1, true),
			path .. " softMotion must gate on antilag.allowAmbient or antilag.tier: " .. softLine
		)
	end
end

-- Thicken softMotion density on Trade/Command + Guild/Admin/Convergence/Settings/Credits/Rebirth
-- plus Continuum/Mailbox/Missions/Milestones/Research/Leaderboards thin surfaces.
-- Continuum/Mailbox/Missions/Milestones/Research/Leaderboards must stay past floor=4
-- (wave softmotion-thin-surfaces). Guild/Convergence/Settings/Trade stay past floor=4 too.
-- Admin/Boosts must stay past softUses=5 toward DENSE≥6 (wave softmotion-admin-boosts).
-- Chat/Command/Lab/Shop/Wheel/StarGrid/Story/Echo/ForgePath must stay DENSE≥6
-- (wave softmotion-ungated-layout).
do
	local CANON = "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient"
	local DENSE = {
		["src/Client/AstralForge/pages/TradeView.luau"] = 12,
		["src/Client/AstralForge/pages/GuildView.luau"] = 12,
		["src/Client/AstralForge/pages/ConvergenceView.luau"] = 12,
		["src/Client/AstralForge/pages/SettingsView.luau"] = 12,
		["src/Client/AstralForge/pages/ContinuumView.luau"] = 12,
		["src/Client/AstralForge/pages/MailboxView.luau"] = 12,
		["src/Client/AstralForge/pages/MissionsView.luau"] = 12,
		["src/Client/AstralForge/pages/MilestonesView.luau"] = 12,
		["src/Client/AstralForge/pages/ResearchView.luau"] = 12,
		["src/Client/AstralForge/pages/LeaderboardsView.luau"] = 12,
		["src/Client/AstralForge/pages/AdminView.luau"] = 12,
		["src/Client/AstralForge/pages/BoostsView.luau"] = 12,
		["src/Client/AstralForge/pages/CreditsView.luau"] = 12,
		["src/Client/AstralForge/pages/CrewView.luau"] = 12,
		["src/Client/AstralForge/pages/WorldsView.luau"] = 12,
		["src/Client/AstralForge/pages/RewardsView.luau"] = 12,
		["src/Client/AstralForge/pages/WorkshopView.luau"] = 12,
		["src/Client/AstralForge/pages/RebirthPanel.luau"] = 12,
		["src/Client/AstralForge/pages/AnomalyView.luau"] = 12,
		["src/Client/AstralForge/pages/InventoryView.luau"] = 12,
		["src/Client/AstralForge/pages/ChatView.luau"] = 12,
		["src/Client/AstralForge/pages/CommandView.luau"] = 12,
		["src/Client/AstralForge/pages/LabView.luau"] = 12,
		["src/Client/AstralForge/pages/ShopView.luau"] = 12,
		["src/Client/AstralForge/pages/WheelView.luau"] = 12,
		["src/Client/AstralForge/pages/StarGridView.luau"] = 12,
		["src/Client/AstralForge/pages/StoryView.luau"] = 12,
		["src/Client/AstralForge/pages/EchoForgeView.luau"] = 12,
		["src/Client/AstralForge/pages/ForgePathView.luau"] = 12,
		["src/Client/AstralForge/pages/OverviewView.luau"] = 12,
		["src/Client/AstralForge/FeedbackOverlay.luau"] = 12,
	}
	for _, path in {
		"src/Client/AstralForge/pages/TradeView.luau",
		"src/Client/AstralForge/pages/CommandView.luau",
		"src/Client/AstralForge/pages/GuildView.luau",
		"src/Client/AstralForge/pages/AdminView.luau",
		"src/Client/AstralForge/pages/BoostsView.luau",
		"src/Client/AstralForge/pages/ConvergenceView.luau",
		"src/Client/AstralForge/pages/SettingsView.luau",
		"src/Client/AstralForge/pages/CreditsView.luau",
		"src/Client/AstralForge/pages/CrewView.luau",
		"src/Client/AstralForge/pages/WorldsView.luau",
		"src/Client/AstralForge/pages/RewardsView.luau",
		"src/Client/AstralForge/pages/WorkshopView.luau",
		"src/Client/AstralForge/pages/RebirthPanel.luau",
		"src/Client/AstralForge/pages/ContinuumView.luau",
		"src/Client/AstralForge/pages/MailboxView.luau",
		"src/Client/AstralForge/pages/MissionsView.luau",
		"src/Client/AstralForge/pages/MilestonesView.luau",
		"src/Client/AstralForge/pages/ResearchView.luau",
		"src/Client/AstralForge/pages/LeaderboardsView.luau",
		"src/Client/AstralForge/pages/AnomalyView.luau",
		"src/Client/AstralForge/pages/InventoryView.luau",
		"src/Client/AstralForge/pages/ChatView.luau",
		"src/Client/AstralForge/pages/LabView.luau",
		"src/Client/AstralForge/pages/ShopView.luau",
		"src/Client/AstralForge/pages/WheelView.luau",
		"src/Client/AstralForge/pages/StarGridView.luau",
		"src/Client/AstralForge/pages/StoryView.luau",
		"src/Client/AstralForge/pages/EchoForgeView.luau",
		"src/Client/AstralForge/pages/ForgePathView.luau",
		"src/Client/AstralForge/pages/OverviewView.luau",
		"src/Client/AstralForge/FeedbackOverlay.luau",
	} do
		local src = fs.readFile(path)
		assert(string.find(src, CANON, 1, true), path .. " must use canonical softMotion antilag line")
		assert(string.find(src, "reducedMotion = softMotion", 1, true), path .. " must fold softMotion into reducedMotion")
		local softUses = 0
		for _ in string.gmatch(src, "softMotion") do
			softUses += 1
		end
		local floor = DENSE[path] or 4
		assert(softUses >= floor, path .. " softMotion density too thin, got " .. tostring(softUses) .. " need >=" .. tostring(floor))
	end
	-- Footgun: Rebirth must not fold effectsPaused into the softMotion assignment line.
	local rebirth = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
	assert(
		not string.find(rebirth, "local softMotion = reducedMotion or effectsPaused", 1, true),
		"RebirthPanel must keep effectsPaused off the softMotion assignment line"
	)
end

------------------------------------------------------------------------

	-- Wave14: Missions claimAllReady must tonumber Progress/Target; Research overscan softMotion-gated.
	local missions = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
	assert(string.find(missions, "tonumber(quest.Progress)", 1, true), "Missions claimAllReady must tonumber Progress")
	assert(string.find(missions, 'type(quests) ~= "table"', 1, true), "Missions claimAllReady must nil-guard quests")
	local research = fs.readFile("src/Client/AstralForge/pages/ResearchView.luau")
	assert(string.find(research, "overscanRows = if softMotion then 0", 1, true), "Research VirtualGrid must softMotion-gate overscan")
	local routerReady = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
	assert(string.find(routerReady, 'lazyView("WorkshopView", "WorkshopView")', 1, true), "PageRouter must lazy-load WorkshopView")
	local overviewReady = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
	assert(string.find(overviewReady, "PageReadyMath.CountReadyQuests", 1, true), "OverviewView must use PageReadyMath")
	-- Wave15: Boosts/Inventory/Anomaly overscan softMotion-gated.
	local boostsSoft = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
	assert(string.find(boostsSoft, "overscan = if softMotion then 0", 1, true), "Boosts FlatList must softMotion-gate overscan")
	local invSoft = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
	assert(string.find(invSoft, "overscan = if softMotion then 0", 1, true), "Inventory FlatList must softMotion-gate overscan")
	local anomalySoft = fs.readFile("src/Client/AstralForge/pages/AnomalyView.luau")
	assert(string.find(anomalySoft, "overscan = if softMotion then 0", 1, true), "Anomaly FlatList must softMotion-gate overscan")
	-- Wave16: Lab/Wheel/StarGrid/Shop FlatList overscan softMotion-gated.
	local labSoft = fs.readFile("src/Client/AstralForge/pages/LabView.luau")
	assert(string.find(labSoft, "overscan = if softMotion then 0", 1, true), "Lab FlatList must softMotion-gate overscan")
	local wheelSoft = fs.readFile("src/Client/AstralForge/pages/WheelView.luau")
	assert(string.find(wheelSoft, "overscan = if softMotion then 0", 1, true), "Wheel FlatList must softMotion-gate overscan")
	local starSoft = fs.readFile("src/Client/AstralForge/pages/StarGridView.luau")
	assert(string.find(starSoft, "overscan = if softMotion then 0", 1, true), "StarGrid FlatList must softMotion-gate overscan")
	local shopSoft = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
	assert(string.find(shopSoft, "overscan = if softMotion then 0", 1, true), "Shop FlatList must softMotion-gate overscan to 0")
	-- Wave17: ForgePath/Echo/Story FlatList overscan softMotion-gated to 0.
	local forgeSoft = fs.readFile("src/Client/AstralForge/pages/ForgePathView.luau")
	assert(string.find(forgeSoft, "overscan = if softMotion then 0", 1, true), "ForgePath FlatList must softMotion-gate overscan")
	local echoSoft = fs.readFile("src/Client/AstralForge/pages/EchoForgeView.luau")
	assert(string.find(echoSoft, "overscan = if softMotion then 0", 1, true), "EchoForge FlatList must softMotion-gate overscan")
	local storySoft = fs.readFile("src/Client/AstralForge/pages/StoryView.luau")
	assert(string.find(storySoft, "overscan = if softMotion then 0", 1, true), "Story FlatList must softMotion-gate overscan")
	-- Wave18: Missions/Mailbox/Guild/Trade/Admin/Leaderboards FlatList overscan softMotion-gated.
	local missionsSoft = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
	assert(string.find(missionsSoft, "overscan = if softMotion then 0", 1, true), "Missions FlatList must softMotion-gate overscan")
	local mailboxSoft = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
	assert(string.find(mailboxSoft, "overscan = if softMotion then 0", 1, true), "Mailbox FlatList must softMotion-gate overscan")
	local guildSoft = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
	assert(string.find(guildSoft, "overscan = if softMotion then 0", 1, true), "Guild FlatList must softMotion-gate overscan")
	local tradeSoft = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
	assert(string.find(tradeSoft, "overscan = if softMotion then 0", 1, true), "Trade FlatList must softMotion-gate overscan")
	local adminSoft = fs.readFile("src/Client/AstralForge/pages/AdminView.luau")
	assert(string.find(adminSoft, "overscan = if softMotion then 0", 1, true), "Admin FlatList must softMotion-gate overscan")
	local boardsSoft = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
	assert(string.find(boardsSoft, "overscan = if softMotion then 0", 1, true), "Leaderboards FlatList must softMotion-gate overscan")
	-- Wave19: Milestones FlatList overscan softMotion-gated (Echo/Command ClaimActions clips below).
	local milestonesSoft = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
	assert(string.find(milestonesSoft, "overscan = if softMotion then 0", 1, true), "Milestones FlatList must softMotion-gate overscan")
	-- Wave20: UpgradeBoard (WorkshopView) VirtualGrid overscan softMotion-gated.
	local upgradeSoft = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
	assert(
		string.find(upgradeSoft, "overscanRows = if softMotion then 0 else (if stack then 2 else 3)", 1, true),
		"UpgradeBoard VirtualGrid must softMotion-gate overscanRows"
	)
	assert(
		string.find(upgradeSoft, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true),
		"UpgradeBoard must declare canonical softMotion"
	)
	-- Wave21: Command titles VirtualGrid overscan softMotion-gated (catalogs already gated).
	local commandTitlesSoft = fs.readFile("src/Client/AstralForge/pages/CommandView.luau")
	local titleGateCount = 0
	for _ in string.gmatch(commandTitlesSoft, "overscanRows = if softMotion then 0 else 1") do
		titleGateCount += 1
	end
	assert(titleGateCount >= 3, "Command catalogs + titles must softMotion-gate overscanRows, got " .. tostring(titleGateCount))

	-- Wave22: MailClaim + Inspect SOCKET/UPGRADE nested hosts must not clip CTA overshoot.
	for _, entry in {
		{ path = "src/Client/AstralForge/pages/MailboxView.luau", name = "MailClaim" },
		{ path = "src/Client/AstralForge/pages/InventoryView.luau", name = "InspectSocketClaim" },
		{ path = "src/Client/AstralForge/pages/InventoryView.luau", name = "InspectUpgradeClaim" },
	} do
		local src = fs.readFile(entry.path)
		local hostStart = string.find(src, 'Name = "' .. entry.name .. '"', 1, true)
		assert(hostStart, entry.name .. " host missing")
		assert(string.find(string.sub(src, hostStart, hostStart + 280), "ClipsDescendants = false", 1, true), entry.name .. " clips")
	end
	local rebirthSoft = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
	local rebirthSoftUses = 0
	for _ in string.gmatch(rebirthSoft, "softMotion") do rebirthSoftUses += 1 end
	assert(rebirthSoftUses >= 8, "RebirthPanel softMotion density too thin after wave22")

------------------------------------------------------------------------
-- Known CTA / FocusClaim footguns (offline)
------------------------------------------------------------------------
do
	local inv = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
	assert(string.find(inv, "InspectClaimActions", 1, true), "Inventory DetailPanel must name InspectClaimActions")
	assert(string.find(inv, "GamepadNavigationService.FocusClaim", 1, true), "Inventory inspect must FocusClaim")
	assert(string.find(inv, "clips = false", 1, true), "Inventory DetailPanel must not clip SOCKET/UPGRADE CTAs")
	assert(string.find(inv, "AutoSalvageSheet", 1, true), "Inventory AutoSalvage sheet must stay named for FocusClaim")
	assert(string.find(inv, "BeginOverlayFocus", 1, true), "Inventory AutoSalvage sheet must BeginOverlayFocus")
	assert(string.find(inv, "EndOverlayFocus", 1, true), "Inventory AutoSalvage sheet must EndOverlayFocus")

	local echo = fs.readFile("src/Client/AstralForge/pages/EchoForgeView.luau")
	-- Inventory echo cards pin LINK/UPGRADE/BREAK to the panel floor — clips=true was a footgun.
	assert(
		string.find(echo, "LINK SLOT", 1, true) and string.find(echo, "clips = false", 1, true),
		"EchoForge inventory cards must keep clips = false near LINK SLOT CTAs"
	)
	assert(string.find(echo, "GamepadNavigationService.FocusClaim", 1, true), "EchoForge LINK must FocusClaim when actionable")
	assert(string.find(echo, 'Name = "EchoClaimActions"', 1, true), "EchoForge LINK host must be named EchoClaimActions")
	assert(string.find(echo, "FlatList", 1, true), "EchoForge vault must FlatList long inventory catalogs")

	local research = fs.readFile("src/Client/AstralForge/pages/ResearchView.luau")
	assert(string.find(research, "GamepadNavigationService.FocusClaim", 1, true), "Research BUY ALL must FocusClaim when affordable")
	assert(string.find(research, 'Name = "ResearchBuyClaimActions"', 1, true), "Research BUY ALL host must be named ResearchBuyClaimActions")
	assert(string.find(research, "VirtualGrid", 1, true), "Research chain must stay VirtualGrid")

	local boosts = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
	assert(string.find(boosts, "clips = false", 1, true), "Boosts cards must keep clips = false for Activate CTA")
	assert(string.find(boosts, "position = UDim2.new(0, 0, 1, -TapTarget)", 1, true) or string.find(boosts, 'Name = "BoostClaimActions"', 1, true), "Boosts Activate must stay bottom-pinned")
	assert(string.find(boosts, "GamepadNavigationService.FocusClaim", 1, true), "Boosts Activate must FocusClaim when ready")
	assert(string.find(boosts, 'Name = "BoostClaimActions"', 1, true), "Boosts Activate host must be named BoostClaimActions")

	local milestones = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
	assert(string.find(milestones, "GamepadNavigationService.FocusClaim", 1, true), "Milestones CLAIM must FocusClaim when ready")
	assert(string.find(milestones, 'Name = "MilestoneClaimActions"', 1, true), "Milestones CLAIM host must be named MilestoneClaimActions")

	local guild = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
	assert(string.find(guild, "GamepadNavigationService.FocusClaim", 1, true), "Guild CLAIM REWARD must FocusClaim when ready")
	assert(string.find(guild, 'Name = "GuildClaimActions"', 1, true), "Guild CLAIM host must be named GuildClaimActions")
	-- CLAIM REWARD footgun: parent clips=true buried claimSlide overshoot on short phones.
	do
		local hostStart = string.find(guild, 'Name = "GuildClaimActions"', 1, true)
		assert(hostStart, "Guild GuildClaimActions host missing")
		local hostSlice = string.sub(guild, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"Guild GuildClaimActions host must keep ClipsDescendants = false"
		)
	end

	local convergence = fs.readFile("src/Client/AstralForge/pages/ConvergenceView.luau")
	assert(string.find(convergence, "GamepadNavigationService.FocusClaim", 1, true), "Convergence CLAIM must FocusClaim when ready")
	assert(string.find(convergence, 'Name = "ConvergenceClaimActions"', 1, true), "Convergence CLAIM host must be named ConvergenceClaimActions")

	local starGrid = fs.readFile("src/Client/AstralForge/pages/StarGridView.luau")
	assert(string.find(starGrid, "GamepadNavigationService.FocusClaim", 1, true), "StarGrid BUY ALL must FocusClaim")
	assert(string.find(starGrid, 'Name = "StarGridBuyClaimActions"', 1, true), "StarGrid BUY ALL host must be named StarGridBuyClaimActions")
	do
		local hostStart = string.find(starGrid, 'Name = "StarGridBuyClaimActions"', 1, true)
		assert(hostStart, "StarGridBuyClaimActions host missing")
		local hostSlice = string.sub(starGrid, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"StarGridBuyClaimActions host must keep ClipsDescendants = false"
		)
	end

	local command = fs.readFile("src/Client/AstralForge/pages/CommandView.luau")
	assert(string.find(command, "GamepadNavigationService.FocusClaim", 1, true), "Command claim CTAs must FocusClaim when ready")
	assert(string.find(command, 'Name = "CommandClaimActions"', 1, true), "Command claim hosts must be named CommandClaimActions")
	assert(string.find(command, "clips = false", 1, true), "Command weekly panel must keep clips = false near CLAIM CTAs")

	local shop = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
	assert(string.find(shop, 'Name = "ShopClaimCode"', 1, true), "Shop CLAIM CODE host must stay named ShopClaimCode")
	assert(string.find(shop, "GamepadNavigationService.FocusClaim", 1, true), "Shop must FocusClaim CLAIM CODE / offer hosts")
	assert(string.find(shop, "ref = if tab == \"Codes\" then shopHostRef else nil", 1, true), "Shop Codes tab must park FocusClaim on ShopClaimCode")

	local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
	local rewards = fs.readFile("src/Client/AstralForge/pages/RewardsView.luau")
	assert(string.find(rewards, "GamepadNavigationService.FocusClaim", 1, true), "Rewards Daily/Timed CLAIM must FocusClaim when ready")
	assert(string.find(rewards, 'Name = "RewardsDailyClaimActions"', 1, true), "Rewards Daily Claim host must be named RewardsDailyClaimActions")
	assert(string.find(rewards, 'Name = "RewardsTimedClaimActions"', 1, true), "Rewards Timed CLAIM host must be named RewardsTimedClaimActions")
	assert(string.find(rewards, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true), "RewardsView must softMotion via antilag")
	local workshop = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
	assert(string.find(workshop, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true), "UpgradeBoard/Workshop must softMotion via antilag")
	assert(string.find(workshop, 'Name = "WorkshopBuyClaim"', 1, true), "WorkshopBuyClaim host must stay named")
	assert(string.find(workshop, "GamepadNavigationService.FocusClaim", 1, true), "Workshop must FocusClaim BUY ALL")

	local credits = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
	assert(string.find(credits, 'Name = "CreditsClaimActions"', 1, true), "Credits primary CTA host must be named CreditsClaimActions")

	local settings = fs.readFile("src/Client/AstralForge/pages/SettingsView.luau")
	assert(string.find(settings, "GamepadNavigationService.FocusClaim", 1, true), "Settings GUIDE/UPDATES must FocusClaim")
	assert(string.find(settings, 'Name = "SettingsClaimActions"', 1, true), "Settings GUIDE/UPDATES host must be named SettingsClaimActions")
	assert(string.find(settings, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true), "SettingsView must softMotion via antilag")
	assert(string.find(settings, "overscan = if softMotion then 0", 1, true), "Settings FlatList must softMotion-gate overscan")

	local chat = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
	assert(string.find(chat, "GamepadNavigationService.FocusClaim", 1, true), "Chat SEND must FocusClaim")
	assert(string.find(chat, 'Name = "ChatClaimActions"', 1, true), "Chat SEND host must be named ChatClaimActions")
	assert(string.find(chat, "reducedMotion = softMotion", 1, true), "ChatView must fold softMotion into reducedMotion")
	assert(string.find(chat, "createElement(FlatList", 1, true), "ChatView must mount FlatList for messages")
	assert(not string.find(chat, "useVirtualizedList", 1, true), "ChatView must not hand-roll useVirtualizedList + raw scrollingframe")

	-- Wave16: Lab CLAIM ALL / Wheel SPIN hosts must not clip CTA overshoot.
	local labClips = fs.readFile("src/Client/AstralForge/pages/LabView.luau")
	do
		local hostStart = string.find(labClips, 'Name = "LabClaimActions"', 1, true)
		assert(hostStart, "LabClaimActions host missing")
		local hostSlice = string.sub(labClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"LabClaimActions host must keep ClipsDescendants = false"
		)
	end
	local wheelClips = fs.readFile("src/Client/AstralForge/pages/WheelView.luau")
	do
		local hostStart = string.find(wheelClips, 'Name = "WheelSpinClaimActions"', 1, true)
		assert(hostStart, "WheelSpinClaimActions host missing")
		local hostSlice = string.sub(wheelClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"WheelSpinClaimActions host must keep ClipsDescendants = false"
		)
	end
	-- Wave17: Convergence/Milestones/ForgePath ClaimActions must not clip CTA overshoot.
	local convergenceClips = fs.readFile("src/Client/AstralForge/pages/ConvergenceView.luau")
	do
		local hostStart = string.find(convergenceClips, 'Name = "ConvergenceClaimActions"', 1, true)
		assert(hostStart, "ConvergenceClaimActions host missing")
		local hostSlice = string.sub(convergenceClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"ConvergenceClaimActions host must keep ClipsDescendants = false"
		)
	end
	local milestoneClips = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
	do
		local hostStart = string.find(milestoneClips, 'Name = "MilestoneClaimActions"', 1, true)
		assert(hostStart, "MilestoneClaimActions host missing")
		local hostSlice = string.sub(milestoneClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"MilestoneClaimActions host must keep ClipsDescendants = false"
		)
	end
	local forgePathClips = fs.readFile("src/Client/AstralForge/pages/ForgePathView.luau")
	do
		local hostStart = string.find(forgePathClips, 'Name = "ForgePathClaimActions"', 1, true)
		assert(hostStart, "ForgePathClaimActions host missing")
		local hostSlice = string.sub(forgePathClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"ForgePathClaimActions host must keep ClipsDescendants = false"
		)
	end
	-- Wave18: Research/Missions/Continuum/Boosts/Anomaly/Settings/Rewards/Rebirth/Credits ClaimActions must not clip CTA overshoot.
	for _, entry in {
		{ path = "src/Client/AstralForge/pages/ResearchView.luau", name = "ResearchBuyClaimActions" },
		{ path = "src/Client/AstralForge/pages/MissionsView.luau", name = "MissionClaimActions" },
		{ path = "src/Client/AstralForge/pages/ContinuumView.luau", name = "ContinuumClaimActions" },
		{ path = "src/Client/AstralForge/pages/BoostsView.luau", name = "BoostClaimActions" },
		{ path = "src/Client/AstralForge/pages/AnomalyView.luau", name = "AnomalyClaimActions" },
		{ path = "src/Client/AstralForge/pages/SettingsView.luau", name = "SettingsClaimActions" },
		{ path = "src/Client/AstralForge/pages/RewardsView.luau", name = "RewardsDailyClaimActions" },
		{ path = "src/Client/AstralForge/pages/RewardsView.luau", name = "RewardsTimedClaimActions" },
		{ path = "src/Client/AstralForge/pages/OverviewView.luau", name = "OverviewVaultClaimActions" },
		{ path = "src/Client/AstralForge/pages/WorldsView.luau", name = "WorldsTravelClaim" },
		{ path = "src/Client/AstralForge/pages/RebirthPanel.luau", name = "RebirthClaimActions" },
		{ path = "src/Client/AstralForge/pages/CreditsView.luau", name = "CreditsClaimActions" },
		{ path = "src/Client/AstralForge/pages/AdminView.luau", name = "AdminConfirmRun" },
	} do
		local src = fs.readFile(entry.path)
		local needle = 'Name = "' .. entry.name .. '"'
		local hostStart = string.find(src, needle, 1, true)
		assert(hostStart, entry.name .. " host missing in " .. entry.path)
		local hostSlice = string.sub(src, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			entry.name .. " host must keep ClipsDescendants = false"
		)
	end

	-- Wave19: Echo/Chat/Command/Guild/Inventory/StarGrid ClaimActions must not clip CTA overshoot.
	-- Evidence: EchoClaimActions and Overview CommandClaimActions previously omitted ClipsDescendants.
	for _, entry in {
		{ path = "src/Client/AstralForge/pages/EchoForgeView.luau", name = "EchoClaimActions" },
		{ path = "src/Client/AstralForge/pages/ChatView.luau", name = "ChatClaimActions" },
		{ path = "src/Client/AstralForge/pages/CommandView.luau", name = "CommandClaimActions" },
		{ path = "src/Client/AstralForge/pages/GuildView.luau", name = "GuildClaimActions" },
		{ path = "src/Client/AstralForge/pages/InventoryView.luau", name = "InspectClaimActions" },
		{ path = "src/Client/AstralForge/pages/StarGridView.luau", name = "StarGridBuyClaimActions" },
	} do
		local src = fs.readFile(entry.path)
		local needle = 'Name = "' .. entry.name .. '"'
		local hostStart = string.find(src, needle, 1, true)
		assert(hostStart, entry.name .. " host missing in " .. entry.path)
		local hostSlice = string.sub(src, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			entry.name .. " host must keep ClipsDescendants = false"
		)
	end

	-- Wave20: ShopClaimCode + CrateRevealOverlay CrateClaim must not clip CTA overshoot.
	-- Evidence: Overlay CrateClaim previously omitted ClipsDescendants (Stage/Simple already false).
	do
		local shopClips = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
		local hostStart = string.find(shopClips, 'Name = "ShopClaimCode"', 1, true)
		assert(hostStart, "ShopClaimCode host missing")
		local hostSlice = string.sub(shopClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"ShopClaimCode host must keep ClipsDescendants = false"
		)
	end
	do
		local overlayClips = fs.readFile("src/Client/AstralForge/pages/CrateRevealOverlay.luau")
		local hostStart = string.find(overlayClips, 'Name = "CrateClaim"', 1, true)
		assert(hostStart, "CrateRevealOverlay CrateClaim host missing")
		local hostSlice = string.sub(overlayClips, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			"CrateRevealOverlay CrateClaim host must keep ClipsDescendants = false"
		)
	end

	-- Wave21: TradeSessionActions / AdminExecuteActions / StoryBeatActions must not clip CTA overshoot.
	-- Evidence: Trade Ready/Confirm/Cancel, Admin ARM/RUN, and Story Continue/Back previously omitted ClipsDescendants.
	for _, entry in {
		{ path = "src/Client/AstralForge/pages/TradeView.luau", name = "TradeSessionActions" },
		{ path = "src/Client/AstralForge/pages/AdminView.luau", name = "AdminExecuteActions" },
		{ path = "src/Client/AstralForge/pages/StoryView.luau", name = "StoryBeatActions" },
	} do
		local src = fs.readFile(entry.path)
		local needle = 'Name = "' .. entry.name .. '"'
		local hostStart = string.find(src, needle, 1, true)
		assert(hostStart, entry.name .. " host missing in " .. entry.path)
		local hostSlice = string.sub(src, hostStart, hostStart + 420)
		assert(
			string.find(hostSlice, "ClipsDescendants = false", 1, true),
			entry.name .. " host must keep ClipsDescendants = false"
		)
	end

	-- softMotion density polish: fold into reducedMotion on Shop/Echo/Boosts/Inventory/Leaderboards
	-- plus Mailbox/Lab/Anomaly/Research/Wheel (wave13 thicken) and Chat/Command/StarGrid/ForgePath
	-- (wave softmotion-ungated-layout).
	local CANON_SOFT = "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient"
	for _, path in {
		"src/Client/AstralForge/pages/ShopView.luau",
		"src/Client/AstralForge/pages/EchoForgeView.luau",
		"src/Client/AstralForge/pages/BoostsView.luau",
		"src/Client/AstralForge/pages/InventoryView.luau",
		"src/Client/AstralForge/pages/LeaderboardsView.luau",
		"src/Client/AstralForge/pages/StoryView.luau",
		"src/Client/AstralForge/pages/CrateRevealOverlay.luau",
		"src/Client/AstralForge/pages/MailboxView.luau",
		"src/Client/AstralForge/pages/LabView.luau",
		"src/Client/AstralForge/pages/AnomalyView.luau",
		"src/Client/AstralForge/pages/ResearchView.luau",
		"src/Client/AstralForge/pages/WheelView.luau",
		"src/Client/AstralForge/pages/ChatView.luau",
		"src/Client/AstralForge/pages/CommandView.luau",
		"src/Client/AstralForge/pages/StarGridView.luau",
		"src/Client/AstralForge/pages/ForgePathView.luau",
		"src/Client/AstralForge/pages/CrewView.luau",
		"src/Client/AstralForge/pages/WorldsView.luau",
		"src/Client/AstralForge/pages/RewardsView.luau",
		"src/Client/AstralForge/pages/WorkshopView.luau",
	} do
		local softSrc = fs.readFile(path)
		assert(string.find(softSrc, CANON_SOFT, 1, true), path .. " must use canonical softMotion antilag line")
		assert(string.find(softSrc, "reducedMotion = softMotion", 1, true), path .. " must fold softMotion into reducedMotion")
	end

	local continuumClips = fs.readFile("src/Client/AstralForge/pages/ContinuumView.luau")
	assert(string.find(continuumClips, 'Name = "ContinuumClaimActions"', 1, true), "Continuum forge CTA host must stay named")
	assert(
		string.find(continuumClips, "clips = false", 1, true)
			and string.find(continuumClips, "ContinuumClaimActions", 1, true),
		"Continuum forge panel must keep clips = false near FORGE CTA"
	)

	-- Crew header pins REFRESH to the panel floor — clips=true buried it on short phones.
	-- Wave28: CrewView extract owns this panel; keep the footgun assert on the extract.
	local crewViewSrc = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
	local crewClips = string.match(crewViewSrc, 'clips = (%w+),%s*}, React.createElement%(Text, %{%s*value = "CREW ROSTER"')
	assert(crewClips == "false", "Crew header must keep clips = false so REFRESH stays reachable")
	assert(string.find(crewViewSrc, "GamepadNavigationService.FocusClaim", 1, true), "Crew must FocusClaim VISIT/REFRESH hosts")
	assert(string.find(crewViewSrc, 'Name = "CrewVisitClaim"', 1, true), "Crew Visit host must stay named CrewVisitClaim")

	-- Crate reveal claim hosts (stage + overlay) must FocusClaim so D-pad/A can reach CLAIM.
	for _, path in {
		"src/Client/AstralForge/pages/CrateRevealStage.luau",
		"src/Client/AstralForge/pages/CrateRevealStageSimple.luau",
		"src/Client/AstralForge/pages/CrateRevealOverlay.luau",
	} do
		local src = fs.readFile(path)
		assert(string.find(src, "GamepadNavigationService.FocusClaim", 1, true), path .. " must FocusClaim claim CTA")
	end

	-- CLAIM hosts must not clip the button (short phones / claimSlide overshoot).
	local crateStage = fs.readFile("src/Client/AstralForge/pages/CrateRevealStage.luau")
	assert(
		string.find(crateStage, 'Name = "CrateClaim"', 1, true)
			and string.find(crateStage, "ClipsDescendants = false", 1, true),
		"CrateRevealStage CrateClaim host must keep ClipsDescendants = false"
	)
	local crateSimple = fs.readFile("src/Client/AstralForge/pages/CrateRevealStageSimple.luau")
	assert(
		string.find(crateSimple, 'Name = if canClaim then "CrateClaim"', 1, true)
			and string.find(crateSimple, "ClipsDescendants = false", 1, true),
		"CrateRevealStageSimple CrateClaim host must keep ClipsDescendants = false"
	)
end

------------------------------------------------------------------------
-- Footgun: do not grow MainGame / ServerServices via this polish lane
------------------------------------------------------------------------
do
	local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
	local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
	-- Soft ceiling: polish PRs must not dump huge extracts into these files.
	assert(#main < 420000, "MainGame.luau unexpectedly huge — avoid polish dumps here")
	assert(#services < 320000, "ServerServices.luau unexpectedly huge — avoid polish dumps here")
	assert(not string.find(main, "vendor/", 1, true), "MainGame must not reference vendor/")
	assert(not string.find(services, "Packages/", 1, true), "ServerServices must not reference Packages/")
end

print(string.format(
	"[INFO] [TEST] playability audit passed | hot=%d overlays=%d softMotion=%d allowlist=%d",
	#HOT_PAGES,
	#FOCUS_OVERLAYS,
	#SOFT_MOTION_FILES,
	(function()
		local n = 0
		for _ in pairs(RAW_SCROLL_ALLOWLIST) do
			n += 1
		end
		return n
	end)()
))
