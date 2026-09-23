--!strict
-- Pure-module extract guards: ProgressionOpsMath (WeeklyValue / CommanderReward /
-- FindById / TitleUnlocked). Evidence: weekly baselines and commander gifts are
-- pure; TitleUnlocked must tolerate missing Artifacts/Stats without throwing.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local ProgressionOpsMath = require("../src/Server/AstralForge/Modules/ProgressionOpsMath")

------------------------------------------------------------------------
-- WeeklyValue
------------------------------------------------------------------------
assert(ProgressionOpsMath.WeeklyValue(nil, "Taps") == 0, "nil profile")
assert(ProgressionOpsMath.WeeklyValue({}, "Taps") == 0, "nil Stats")
assert(ProgressionOpsMath.WeeklyValue({ Stats = { Taps = 7 } }, "Taps") == 7, "taps")
assert(
	ProgressionOpsMath.WeeklyValue({
		Stats = { MachinesBought = 3, ResearchBought = 2 },
	}, "Upgrades") == 5,
	"upgrades sum"
)
assert(
	ProgressionOpsMath.WeeklyValue({
		Command = { ExpeditionsCompleted = 4 },
	}, "Expeditions") == 4,
	"expeditions from Command"
)
assert(ProgressionOpsMath.WeeklyValue({ Stats = nil }, "Expeditions") == 0, "nil command expeditions")

------------------------------------------------------------------------
-- CommanderReward
------------------------------------------------------------------------
local r1 = ProgressionOpsMath.CommanderReward(1)
assert(r1.CashMinutes == 6 and r1.Signals == 3, "level 1 gift")
local r5 = ProgressionOpsMath.CommanderReward(5)
assert(r5.StreakShield == 1 and r5.Stardust == 13, "level 5 milestone")
local r10 = ProgressionOpsMath.CommanderReward(10)
assert(r10.Cores == 1 and r10.Signals == 20, "level 10 cores")
assert(ProgressionOpsMath.CommanderReward(nil).CashMinutes == 6, "nil level → 1")

------------------------------------------------------------------------
-- FindById
------------------------------------------------------------------------
assert(ProgressionOpsMath.FindById(nil, "x") == nil, "nil list")
assert(ProgressionOpsMath.FindById({ { Id = "a" }, { Id = "b" } }, "b").Id == "b", "find b")
assert(ProgressionOpsMath.FindById({ { Id = "a" } }, "z") == nil, "missing")

------------------------------------------------------------------------
-- TitleUnlocked
------------------------------------------------------------------------
local command = {
	ExpeditionsCompleted = 5,
	Artifacts = { A = true, B = true },
}
assert(
	ProgressionOpsMath.TitleUnlocked({}, { Kind = "Level", Target = 3 }, command, 4, nil) == true,
	"level ok"
)
assert(
	ProgressionOpsMath.TitleUnlocked({}, { Kind = "Level", Target = 5 }, command, 4, nil) == false,
	"level short"
)
assert(
	ProgressionOpsMath.TitleUnlocked({}, { Kind = "Expeditions", Target = 5 }, command, 1, nil) == true,
	"expeditions ok"
)
assert(
	ProgressionOpsMath.TitleUnlocked({}, { Kind = "Artifacts", Target = 2 }, command, 1, nil) == true,
	"artifacts ok"
)
assert(
	ProgressionOpsMath.TitleUnlocked({}, { Kind = "Artifacts", Target = 3 }, { Artifacts = nil }, 1, nil)
		== false,
	"nil artifacts"
)
assert(
	ProgressionOpsMath.TitleUnlocked({ Rebirths = 9 }, { Kind = "Rebirths", Target = 8 }, command, 1, nil)
		== true,
	"rebirths ok"
)
assert(
	ProgressionOpsMath.TitleUnlocked(
		{ LifetimeCash = 100 },
		{ Kind = "LifetimeCash", Target = 50 },
		command,
		1,
		function(left, right)
			return (tonumber(left) or 0) >= (tonumber(right) or 0)
		end
	) == true,
	"lifetime gte"
)
assert(
	ProgressionOpsMath.TitleUnlocked({ LifetimeCash = 10 }, { Kind = "LifetimeCash", Target = 50 }, command, 1, nil)
		== false,
	"lifetime without gte"
)

------------------------------------------------------------------------
-- AchievementProgress
------------------------------------------------------------------------
assert(ProgressionOpsMath.AchievementProgress(nil, "Zone") == 0, "nil profile progress")
assert(ProgressionOpsMath.AchievementProgress({ Zone = 4 }, "Zone") == 4, "zone progress")
assert(
	ProgressionOpsMath.AchievementProgress({ Machines = { A = 2, B = 3 } }, "MachineLevels") == 5,
	"machine levels"
)
assert(
	ProgressionOpsMath.AchievementProgress({ Research = { X = 1 } }, "ResearchLevels") == 1,
	"research levels"
)
assert(
	ProgressionOpsMath.AchievementProgress({ Rebirths = 2, Domain = { TotalRebirthsSpent = 3 } }, "Rebirths") == 5,
	"rebirths + spent"
)
assert(
	ProgressionOpsMath.AchievementProgress({ Anomaly = { Stabilizations = 7 }, Stats = { AnomalyStabilizations = 1 } }, "AnomalyStabilizations")
		== 7,
	"anomaly bag preferred"
)
assert(
	ProgressionOpsMath.AchievementProgress({ Command = { ExpeditionsCompleted = 9 }, Stats = { Expeditions = 1 } }, "Expeditions")
		== 9,
	"command expeditions preferred"
)
assert(
	ProgressionOpsMath.AchievementProgress({ ForgePath = { ClaimedSteps = { ["1"] = true, ["2"] = true } } }, "ForgePathSteps")
		== 2,
	"forge path steps"
)
assert(
	ProgressionOpsMath.AchievementProgress({ LifetimeCash = "100" }, "LifetimeCash", function(v)
		return tonumber(v) or 0
	end) == 100,
	"lifetime inject"
)
assert(ProgressionOpsMath.AchievementProgress({ LifetimeCash = 50 }, "LifetimeCash", nil) == 0, "lifetime needs inject")

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local ssSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/ProgressionOpsMath.luau")
local bagSrc = fs.readFile("src/Server/AstralForge/Modules/ProfileBagMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(progressionSrc, "ProgressionOpsMath.WeeklyValue", 1, true), "Progression WeeklyValue")
assert(string.find(progressionSrc, "ProgressionOpsMath.CommanderReward", 1, true), "Progression CommanderReward")
assert(string.find(progressionSrc, "ProgressionOpsMath.TitleUnlocked", 1, true), "Progression TitleUnlocked")
assert(string.find(progressionSrc, "ProgressionOpsMath.FindById", 1, true), "Progression FindById")
assert(string.find(progressionSrc, "ProgressionOpsMath.AchievementProgress", 1, true), "Progression AchievementProgress")
assert(string.find(progressionSrc, "Economy.AsNumber", 1, true), "AchievementProgress injects AsNumber")
assert(string.find(dataSrc, "ProfileBagMath.EnsureItems", 1, true), "DataService EnsureItems")
assert(string.find(dataSrc, "ProfileBagMath.EnsureDomain", 1, true), "DataService EnsureDomain")
assert(string.find(dataSrc, "ProfileBagMath.EnsureContinuum", 1, true), "DataService EnsureContinuum")
assert(string.find(dataSrc, "ProfileBagMath.EnsureAnomaly", 1, true), "DataService EnsureAnomaly")
assert(string.find(ssSrc, "ProfileBagMath.EnsureItems", 1, true), "ServerServices EnsureItems")
assert(string.find(ssSrc, "ProfileBagMath.EnsureAutoSalvage", 1, true), "ServerServices EnsureAutoSalvage")
assert(string.find(bagSrc, "EnsureAutoSalvage", 1, true), "ProfileBagMath EnsureAutoSalvage")
assert(string.find(bagSrc, "Shop = { Day = -1", 1, true), "EnsureItems includes Shop")
assert(not string.find(mathSrc, "GetService", 1, true), "ProgressionOpsMath must stay pure")
assert(not string.find(mathSrc, "vendor/", 1, true), "no vendor/")
assert(not string.find(mathSrc, "Packages/", 1, true), "no Packages/")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

assert(string.find(configSrc, "Wave15OpsMath", 1, true), "DV21 lab Wave15OpsMath")
assert(string.find(configSrc, "Wave15ItemsShopSoftMotion", 1, true), "DV21 lab Wave15ItemsShopSoftMotion")
assert(string.find(configSrc, "Wave15OpsCourier", 1, true), "DV21 achievement Wave15OpsCourier")
assert(string.find(configSrc, "wave15-harden-brief", 1, true), "DV21 story wave15")
assert(string.find(configSrc, "update-5-1-wave15-harden", 1, true), "DV21 mail wave15")

print("[INFO] [TEST] ProgressionOpsMath extract + Items.Shop Ensures + DV21 append passed")
