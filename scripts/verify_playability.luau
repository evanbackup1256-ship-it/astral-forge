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
-- Overview lives inside PageRouter; Mailbox stays dual-pane (no outer scaffold).
local HOT_PAGES = {
	"src/Client/AstralForge/pages/PageRouter.luau",
	"src/Client/AstralForge/pages/AdminView.luau",
	"src/Client/AstralForge/pages/AnomalyView.luau",
	"src/Client/AstralForge/pages/BoostsView.luau",
	"src/Client/AstralForge/pages/ChatView.luau",
	"src/Client/AstralForge/pages/CommandView.luau",
	"src/Client/AstralForge/pages/ContinuumView.luau",
	"src/Client/AstralForge/pages/ConvergenceView.luau",
	"src/Client/AstralForge/pages/CreditsView.luau",
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
local RAW_SCROLL_ALLOWLIST = {
	["src/Client/AstralForge/pages/ChatView.luau"] = "message list VirtualizedList Y-scroll under PageScaffold fill; status/banner/SEND stay fixed sections so stick-to-bottom chat chrome never buries SEND",
}

local RAW_SCROLL_BUDGET = {
	["src/Client/AstralForge/pages/ChatView.luau"] = 1,
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
	assert(string.find(src, 'createElement("scrollingframe"', 1, true), path .. " must keep a body scrollingframe")
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
		local hostSlice = string.sub(mailbox, hostStart, hostStart + 280)
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
	"src/Client/AstralForge/pages/PageRouter.luau",
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
do
	local CANON = "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient"
	local DENSE = {
		["src/Client/AstralForge/pages/TradeView.luau"] = 6,
		["src/Client/AstralForge/pages/GuildView.luau"] = 6,
		["src/Client/AstralForge/pages/ConvergenceView.luau"] = 6,
		["src/Client/AstralForge/pages/SettingsView.luau"] = 6,
		["src/Client/AstralForge/pages/ContinuumView.luau"] = 6,
		["src/Client/AstralForge/pages/MailboxView.luau"] = 6,
		["src/Client/AstralForge/pages/MissionsView.luau"] = 6,
		["src/Client/AstralForge/pages/MilestonesView.luau"] = 6,
		["src/Client/AstralForge/pages/ResearchView.luau"] = 6,
		["src/Client/AstralForge/pages/LeaderboardsView.luau"] = 6,
	}
	for _, path in {
		"src/Client/AstralForge/pages/TradeView.luau",
		"src/Client/AstralForge/pages/CommandView.luau",
		"src/Client/AstralForge/pages/GuildView.luau",
		"src/Client/AstralForge/pages/AdminView.luau",
		"src/Client/AstralForge/pages/ConvergenceView.luau",
		"src/Client/AstralForge/pages/SettingsView.luau",
		"src/Client/AstralForge/pages/CreditsView.luau",
		"src/Client/AstralForge/pages/RebirthPanel.luau",
		"src/Client/AstralForge/pages/ContinuumView.luau",
		"src/Client/AstralForge/pages/MailboxView.luau",
		"src/Client/AstralForge/pages/MissionsView.luau",
		"src/Client/AstralForge/pages/MilestonesView.luau",
		"src/Client/AstralForge/pages/ResearchView.luau",
		"src/Client/AstralForge/pages/LeaderboardsView.luau",
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

	local convergence = fs.readFile("src/Client/AstralForge/pages/ConvergenceView.luau")
	assert(string.find(convergence, "GamepadNavigationService.FocusClaim", 1, true), "Convergence CLAIM must FocusClaim when ready")
	assert(string.find(convergence, 'Name = "ConvergenceClaimActions"', 1, true), "Convergence CLAIM host must be named ConvergenceClaimActions")

	local starGrid = fs.readFile("src/Client/AstralForge/pages/StarGridView.luau")
	assert(string.find(starGrid, "GamepadNavigationService.FocusClaim", 1, true), "StarGrid BUY ALL must FocusClaim")
	assert(string.find(starGrid, 'Name = "StarGridBuyClaimActions"', 1, true), "StarGrid BUY ALL host must be named StarGridBuyClaimActions")

	local command = fs.readFile("src/Client/AstralForge/pages/CommandView.luau")
	assert(string.find(command, "GamepadNavigationService.FocusClaim", 1, true), "Command claim CTAs must FocusClaim when ready")
	assert(string.find(command, 'Name = "CommandClaimActions"', 1, true), "Command claim hosts must be named CommandClaimActions")
	assert(string.find(command, "clips = false", 1, true), "Command weekly panel must keep clips = false near CLAIM CTAs")

	local shop = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
	assert(string.find(shop, 'Name = "ShopClaimCode"', 1, true), "Shop CLAIM CODE host must stay named ShopClaimCode")
	assert(string.find(shop, "GamepadNavigationService.FocusClaim", 1, true), "Shop must FocusClaim CLAIM CODE / offer hosts")
	assert(string.find(shop, "ref = if tab == \"Codes\" then shopHostRef else nil", 1, true), "Shop Codes tab must park FocusClaim on ShopClaimCode")

	local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
	assert(string.find(router, "GamepadNavigationService.FocusClaim", 1, true), "Rewards Daily/Timed CLAIM must FocusClaim when ready")
	assert(string.find(router, 'Name = "RewardsDailyClaimActions"', 1, true), "Rewards Daily Claim host must be named RewardsDailyClaimActions")
	assert(string.find(router, 'Name = "RewardsTimedClaimActions"', 1, true), "Rewards Timed CLAIM host must be named RewardsTimedClaimActions")
	assert(string.find(router, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true), "RewardsView must softMotion via antilag")

	local credits = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
	assert(string.find(credits, 'Name = "CreditsClaimActions"', 1, true), "Credits primary CTA host must be named CreditsClaimActions")

	local settings = fs.readFile("src/Client/AstralForge/pages/SettingsView.luau")
	assert(string.find(settings, "GamepadNavigationService.FocusClaim", 1, true), "Settings GUIDE/UPDATES must FocusClaim")
	assert(string.find(settings, 'Name = "SettingsClaimActions"', 1, true), "Settings GUIDE/UPDATES host must be named SettingsClaimActions")
	assert(string.find(settings, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true), "SettingsView must softMotion via antilag")

	local chat = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
	assert(string.find(chat, "GamepadNavigationService.FocusClaim", 1, true), "Chat SEND must FocusClaim")
	assert(string.find(chat, 'Name = "ChatClaimActions"', 1, true), "Chat SEND host must be named ChatClaimActions")
	assert(string.find(chat, "reducedMotion = softMotion", 1, true), "ChatView must fold softMotion into reducedMotion")

	-- softMotion density polish: fold into reducedMotion on Shop/Echo/Boosts/Inventory/Leaderboards
	-- plus Mailbox/Lab/Anomaly/Research/Wheel (wave13 thicken).
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
	local crewClips = string.match(router, 'clips = (%w+),%s*}, React.createElement%(Text, %{%s*value = "CREW ROSTER"')
	assert(crewClips == "false", "Crew header must keep clips = false so REFRESH stays reachable")

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
