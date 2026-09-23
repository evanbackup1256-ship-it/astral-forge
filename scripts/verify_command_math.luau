--!strict
-- Pure-module extract guards: CommandMath (Ensure / Level / FloorXP / NextXP / Rank).
-- Evidence: ApplyReward Signals seeds Command={Signals=N} without Crew/Artifacts —
-- DataService sanitize iterated nil Crew/MachineMastery/Artifacts and CommandState
-- crashed on CommanderClaims. Same class as WheelMath FreeSpins-only bags.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local CommandMath = require("../src/Server/AstralForge/Modules/CommandMath")

-- --- Ensure -------------------------------------------------------------------
local fresh = CommandMath.Ensure(nil, "SEASON_TEST")
assert(fresh.XP == 0 and fresh.Signals == 0 and fresh.SeasonId == "SEASON_TEST", "nil → empty bag")
assert(fresh.Crew.Pilot == 1 and fresh.Crew.Engineer == 1 and fresh.Crew.Navigator == 1, "default crew")
assert(type(fresh.Artifacts) == "table" and type(fresh.Weekly.Claimed) == "table", "nested bags")
assert(type(fresh.Shop.Purchased) == "table" and fresh.ActiveExpedition.Id == "", "shop + expedition")

local partial = CommandMath.Ensure({ Signals = 12 }, "DEEP_SPACE_01")
assert(partial.Signals == 12 and partial.XP == 0, "Signals-only preserves Signals")
assert(partial.Crew.Pilot == 1 and type(partial.Artifacts) == "table", "Signals-only fills Crew/Artifacts")
assert(partial.Weekly.Week == -1 and partial.Shop.Day == -1, "Signals-only fills Weekly/Shop")
assert(partial.SeasonId == "DEEP_SPACE_01", "season injected")
local same = CommandMath.Ensure(partial, "DEEP_SPACE_01")
assert(same == partial, "Ensure mutates in place when table provided")
assert(CommandMath.Ensure({ Signals = -3 }).Signals == 0, "negative Signals clamped")
assert(CommandMath.Ensure({ XP = 1.9 }).XP == 1, "XP floored")
assert(CommandMath.Ensure({}).SeasonId == "DEEP_SPACE_01", "default season when omitted")

-- --- Level / XP / Rank --------------------------------------------------------
assert(CommandMath.Level(0, 100) == 1, "0 XP → level 1")
assert(CommandMath.Level(100, 100) == 2, "100 XP → level 2")
assert(CommandMath.Level(400, 100) == 3, "400 XP → level 3")
assert(CommandMath.Level(1_000_000, 10) == 10, "clamps to maxLevel")
assert(CommandMath.Level(nil, 50) == 1, "nil XP → 1")
assert(CommandMath.FloorXP(1) == 0, "floor level 1")
assert(CommandMath.FloorXP(3) == 400, "floor level 3 = 100*2^2")
assert(CommandMath.NextXP(1, 100) == 100, "next after 1")
assert(CommandMath.NextXP(2, 100) == 400, "next after 2")
assert(CommandMath.NextXP(100, 100) == CommandMath.FloorXP(100), "max level next = floor")
assert(CommandMath.Rank(1) == "FORGE CADET", "rank cadet")
assert(CommandMath.Rank(5) == "FLIGHT SPECIALIST", "rank specialist")
assert(CommandMath.Rank(10) == "STAR OFFICER", "rank officer")
assert(CommandMath.Rank(60) == "TIMELESS COMMANDER", "rank timeless")
assert(CommandMath.Rank(nil) == "FORGE CADET", "nil rank → cadet")

-- --- Source wiring + HARD constraints ----------------------------------------
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/CommandMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(progressionSrc, "CommandMath.Ensure", 1, true), "ProgressionService must delegate Ensure")
assert(string.find(progressionSrc, "CommandMath.Level", 1, true), "ProgressionService must delegate Level")
assert(string.find(progressionSrc, "CommandMath.FloorXP", 1, true), "ProgressionService must delegate FloorXP")
assert(string.find(progressionSrc, "CommandMath.NextXP", 1, true), "ProgressionService must delegate NextXP")
assert(string.find(progressionSrc, "CommandMath.Rank", 1, true), "ProgressionService must delegate Rank")
assert(string.find(progressionSrc, "ensureCommand", 1, true), "ProgressionService must nil-safe via ensureCommand")
assert(
	string.find(progressionSrc, 'profile.Command = { XP = 0, SeasonXP = 0, Signals = 0, StreakShields = 0 }', 1, true) == nil,
	"thin Signals-only ensureCommand seed must be removed"
)
assert(string.find(dataSrc, "CommandMath.Ensure", 1, true), "DataService sanitize must rebuild Command via CommandMath")
assert(string.find(dataSrc, "LabOrderMath.Ensure", 1, true), "DataService sanitize must rebuild Lab via LabOrderMath")
assert(not string.find(mathSrc, "GetService", 1, true), "CommandMath must stay pure")
assert(not string.find(mathSrc, "vendor/", 1, true), "CommandMath must not reference vendor/")
assert(not string.find(mathSrc, "Packages/", 1, true), "CommandMath must not reference Packages/")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

print("[INFO] [TEST] CommandMath extract passed | Ensure+Level+Rank+Signals-only bags")
