--!strict
-- Ensure retired planning labels now route to real replacement systems.

local fs = require("@lune/fs")

local core = fs.readFile("src/Client/AstralForge/CoreKit.luau")
local router = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local progress = fs.readFile("src/Client/AstralForge/pages/PagesProgress.luau")
local system = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau")
local planning = fs.readFile("src/Client/AstralForge/PlanningViews.luau")
local ready = fs.readFile("src/Client/AstralForge/ReadyBoard.luau")
local find = fs.readFile("src/Client/AstralForge/QuickFind.luau")

local function contains(source: string, value: string): boolean
	return string.find(source, value, 1, true) ~= nil
end

assert(
	contains(core, 'id = "AscensionPath"') and contains(core, 'label = "Ascension Path"'),
	"navigation exposes the Ascension Path"
)
assert(contains(core, 'id = "ExpeditionPlanner", label = "Expeditions"'), "navigation exposes Expeditions")
assert(
	contains(router, 'page == "AscensionPath"') and contains(progress, '__defs["AscensionPathView"]'),
	"Ascension Path routes to the real skill tree"
)
assert(
	contains(router, 'page == "ExpeditionPlanner"') and contains(system, '__defs["ExpeditionPlannerView"]'),
	"Expeditions routes to the real route planner"
)
assert(
	contains(system, 'initialTab = "Expeditions"') and contains(system, "useState(initialTab)"),
	"planner opens on its expedition tab"
)
assert(contains(planning, 'navigate("ExpeditionPlanner")'), "resource plan directs players to Expeditions")
assert(contains(ready, '"Anomaly"') and not contains(ready, '"Shift Plan"'), "ready row uses the anomaly system name")
assert(
	contains(find, 'AscensionPath = "ascension path skill tree nodes"'),
	"quick find indexes the replacement skill tree"
)
assert(
	contains(find, 'ExpeditionPlanner = "expeditions plan routes crew"'),
	"quick find indexes the expedition planner"
)
assert(
	not contains(core, 'label = "Next Rank"') and not contains(core, 'label = "Shift Plan"'),
	"retired labels are absent from navigation"
)

print("[TEST] replacement routes expose the Ascension Path and Expedition Planner and retire obsolete labels")
