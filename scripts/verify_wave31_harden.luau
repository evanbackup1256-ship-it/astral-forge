--!strict
-- Wave31 offline residuals: WorkshopView extract (MachineRow/UpgradeBoard/AutoForge),
-- WorkshopBuyClaim FocusClaim, PageRouter thin dispatcher, Overview PageReadyMath fix, DV21 briefs.

local fs = require("@lune/fs")

local workshop = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
assert(string.find(workshop, "local function WorkshopView", 1, true), "WorkshopView missing")
assert(string.find(workshop, "local function MachineRow", 1, true), "MachineRow missing")
assert(string.find(workshop, "local function UpgradeBoard", 1, true), "UpgradeBoard missing")
assert(string.find(workshop, "local function AutoForgePanel", 1, true), "AutoForgePanel missing")
assert(string.find(workshop, 'Name = "WorkshopBuyClaim"', 1, true), "WorkshopBuyClaim host")
assert(string.find(workshop, "GamepadNavigationService.FocusClaim", 1, true), "Workshop FocusClaim")
assert(string.find(workshop, "overscanRows = if softMotion then 0 else (if stack then 2 else 3)", 1, true), "UpgradeBoard overscan")
assert(string.find(workshop, "reducedMotion = softMotion", 1, true), "Workshop fold softMotion")
do
	local soft = 0
	for _ in string.gmatch(workshop, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Workshop softMotion density, got " .. tostring(soft))
end
do
	local hostStart = string.find(workshop, 'Name = "WorkshopBuyClaim"', 1, true)
	assert(hostStart, "WorkshopBuyClaim missing")
	local hostSlice = string.sub(workshop, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "WorkshopBuyClaim clips")
end

local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(router, 'lazyView("WorkshopView", "WorkshopView")', 1, true), "PageRouter lazy WorkshopView")
assert(not string.find(router, "local function MachineRow", 1, true), "MachineRow must leave PageRouter")
assert(not string.find(router, "local function UpgradeBoard", 1, true), "UpgradeBoard must leave PageRouter")
assert(not string.find(router, "local function WorkshopView", 1, true), "inline WorkshopView must leave PageRouter")
assert(not string.find(router, "VirtualGrid", 1, true), "PageRouter must drop VirtualGrid")
assert(not string.find(router, "softMotion", 1, true), "PageRouter must drop softMotion after Workshop peel")
assert(#router < 20000, "PageRouter must stay thin after Workshop peel")

local overview = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overview, "PageReadyMath.CountReadyQuests", 1, true), "Overview CountReadyQuests")
assert(string.find(overview, "PageReadyMath.ForgePathReady", 1, true), "Overview ForgePathReady")
assert(not string.find(overview, "countReadyQuests(", 1, true), "Overview must not call missing countReadyQuests local")

local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(config, 'Id = "wave31-offline-brief"', 1, true), "Story wave31")
assert(string.find(config, 'Id = "update-5-1-wave31-offline"', 1, true), "Mail wave31")
assert(string.find(config, "DataVersion = 21", 1, true), "DV21")

print("[INFO] [TEST] wave31 harden residuals passed")
