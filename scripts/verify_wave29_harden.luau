--!strict
-- Wave29 offline residuals: OverviewView extract from PageRouter, Collect/Overcharge
-- FocusClaim, MainGame RailButton/Navigation softMotion, AdminConfirmRun clips, DV21 briefs.

local fs = require("@lune/fs")

local overview = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overview, "local function OverviewView", 1, true), "OverviewView missing")
assert(string.find(overview, "local function ReleaseCountdown", 1, true), "ReleaseCountdown must live with Overview")
assert(string.find(overview, "createElement(PageScaffold", 1, true), "Overview PageScaffold")
assert(string.find(overview, "LayoutSectionPlan.planOverview", 1, true), "Overview planOverview")
assert(
	string.find(overview, "local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true),
	"Overview softMotion canon"
)
assert(
	string.find(overview, "local quietMotion = softMotion or effectsPaused or antilag.skipEntrance", 1, true),
	"Overview quietMotion"
)
assert(string.find(overview, "GamepadNavigationService.FocusClaim", 1, true), "Overview FocusClaim")
assert(string.find(overview, 'Name = "OverviewVaultClaimActions"', 1, true), "OverviewVaultClaimActions host")
do
	local hostStart = string.find(overview, 'Name = "OverviewVaultClaimActions"', 1, true)
	assert(hostStart, "OverviewVaultClaimActions missing")
	local hostSlice = string.sub(overview, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "OverviewVaultClaimActions clips")
end
do
	local soft = 0
	for _ in string.gmatch(overview, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Overview softMotion density, got " .. tostring(soft))
end

local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(router, 'lazyView("OverviewView", "OverviewView")', 1, true), "PageRouter lazy OverviewView")
assert(string.find(router, "createElement(OverviewView,", 1, true), "PageRouter mounts OverviewView")
assert(not string.find(router, "local function OverviewView", 1, true), "inline OverviewView must leave PageRouter")
assert(not string.find(router, "local function Metric", 1, true), "Metric must leave PageRouter")
assert(not string.find(router, "local function ReleaseCountdown", 1, true), "ReleaseCountdown must leave PageRouter")
assert(not string.find(router, "LayoutSectionPlan.planOverview", 1, true), "planOverview must leave PageRouter")

local main = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(main, "Canonical softMotion antilag gate — RailButton", 1, true), "RailButton softMotion gate")
assert(string.find(main, "Canonical softMotion antilag gate — Navigation", 1, true), "Navigation softMotion gate")
do
	local soft = 0
	for _ in string.gmatch(main, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "MainGame softMotion densify, got " .. tostring(soft))
end

local admin = fs.readFile("src/Client/AstralForge/pages/AdminView.luau")
do
	local hostStart = string.find(admin, 'Name = "AdminConfirmRun"', 1, true)
	assert(hostStart, "AdminConfirmRun missing")
	local hostSlice = string.sub(admin, hostStart, hostStart + 280)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "AdminConfirmRun clips")
end

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave29-offline-brief"', 1, true), "Story wave29")
assert(string.find(config, 'Id = "update-5-1-wave29-offline"', 1, true), "Mail wave29")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave29 harden residuals passed")
