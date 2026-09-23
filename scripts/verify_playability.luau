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
-- Overview lives inside PageRouter; Chat/Admin/Credits stay out (special chrome).
local HOT_PAGES = {
	"src/Client/AstralForge/pages/PageRouter.luau",
	"src/Client/AstralForge/pages/AnomalyView.luau",
	"src/Client/AstralForge/pages/BoostsView.luau",
	"src/Client/AstralForge/pages/CommandView.luau",
	"src/Client/AstralForge/pages/ContinuumView.luau",
	"src/Client/AstralForge/pages/ConvergenceView.luau",
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
-- only OK when justified below (horizontal chips, dual-pane body, dual Confirm trees).
local RAW_SCROLL_ALLOWLIST = {
	["src/Client/AstralForge/pages/LeaderboardsView.luau"] = "horizontal filter-tab strip (ScrollingDirection.X), not page body",
	["src/Client/AstralForge/pages/TradeView.luau"] = "nested offer/session scrolls inside dual compact/desktop Confirm trees",
	["src/Client/AstralForge/pages/StoryView.luau"] = "nested chapter/content scrolls under scaffolded story chrome",
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
			reason ~= nil and #reason > 12,
			path .. " has " .. tostring(rawCount) .. " raw scrollingframe(s); migrate to PageScaffold or document allowlist justification"
		)
		-- Allowlisted pages must still show CanvasSize / AutomaticCanvasSize near the raw frame
		-- so we are auditing the real canvas pattern, not a false-positive element name.
		assert(
			string.find(src, "CanvasSize", 1, true) and string.find(src, "AutomaticCanvasSize", 1, true),
			path .. " allowlisted raw scroll must still declare CanvasSize/AutomaticCanvasSize"
		)
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
	local softLine = string.match(src, "local softMotion = ([^\n]+)")
	assert(softLine, path .. " softMotion assignment unreadable")
	assert(
		string.find(softLine, "antilag", 1, true),
		path .. " softMotion must reference antilag on the assignment line"
	)
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
