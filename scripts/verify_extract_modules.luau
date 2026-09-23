--!strict
-- Pure-module extract guards: UpgradeCostReason / ForgePathClaim / OfflineProjection.
-- Mirrors verify_trade style — require the modules under Lune, assert behavior.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local UpgradeCostReason = require("../src/Server/AstralForge/Modules/UpgradeCostReason")
local ForgePathClaim = require("../src/Server/AstralForge/Modules/ForgePathClaim")
local OfflineProjection = require("../src/Server/AstralForge/Modules/OfflineProjection")

-- --- UpgradeCostReason -------------------------------------------------------
local cost = UpgradeCostReason.LevelCost(OmegaMath, { BaseCost = 100, CostScale = 1.15 }, 0)
assert(OmegaMath.ToNumber(cost) == 100, "level-0 cost is base")
assert(UpgradeCostReason.LevelCost(OmegaMath, nil, 3) == math.huge, "missing def → huge")

local def = { BaseCost = 10, CostScale = 1.5 }
local bulk = UpgradeCostReason.BulkCost(OmegaMath, def, 0, 3)
assert(
	OmegaMath.ToNumber(bulk) == OmegaMath.ToNumber(OmegaMath.GeometricSum(def.BaseCost, def.CostScale, 0, 3)),
	"bulk matches GeometricSum"
)
assert(UpgradeCostReason.BulkCost(OmegaMath, nil, 0, 3) == math.huge, "missing bulk def → huge")

local affordCount, affordCost = UpgradeCostReason.AffordableLevels(OmegaMath, def, 0, 40, 10)
local expectedCount, expectedCost = OmegaMath.AffordableCount(def.BaseCost, def.CostScale, 0, 40, 10)
assert(affordCount == expectedCount, "affordable count matches OmegaMath")
assert(OmegaMath.ToNumber(affordCost) == OmegaMath.ToNumber(expectedCost), "affordable cost matches")
local zeroCount = UpgradeCostReason.AffordableLevels(OmegaMath, nil, 0, 100, 5)
assert(zeroCount == 0, "missing afford def → 0")

local reasonZone = UpgradeCostReason.Evaluate(
	{ Zone = 0, Rebirths = 0 },
	{ RequiredZone = 2 },
	{},
	function(idx)
		return if idx == 2 then "Nebula Reach" else nil
	end,
	function()
		return nil
	end
)
assert(reasonZone == "Reach Nebula Reach", "zone gate reason")

local reasonWorld = UpgradeCostReason.Evaluate(
	{ Zone = nil, Rebirths = 0 },
	{ RequiredZone = 3 },
	{},
	function()
		return nil
	end,
	function()
		return nil
	end
)
assert(reasonWorld == "Reach World 3", "nil zone name falls back to World N")

local reasonRebirth = UpgradeCostReason.Evaluate(
	{ Zone = 5, Rebirths = 0 },
	{ RequiredZone = 1, RequiredRebirths = 2 },
	{},
	function()
		return nil
	end,
	function()
		return nil
	end
)
assert(reasonRebirth == "Complete 2 rebirths", "rebirth gate plural")

local reasonPrev = UpgradeCostReason.Evaluate(
	{ Zone = 5, Rebirths = 9 },
	{ RequiredZone = 1, PreviousId = "Drill", PreviousLevel = 3 },
	{ Drill = 1 },
	function()
		return nil
	end,
	function(id)
		return if id == "Drill" then "Flux Drill" else nil
	end
)
assert(reasonPrev == "Raise Flux Drill to level 3", "previous-level gate")

assert(
	UpgradeCostReason.Evaluate({ Zone = 9, Rebirths = 9 }, { RequiredZone = 1 }, {}, function()
		return nil
	end, function()
		return nil
	end) == nil,
	"unlocked → nil reason"
)

-- --- ForgePathClaim ----------------------------------------------------------
local steps = {
	{ XPCost = 10, Reward = { Kind = "Cash", Amount = 1 } },
	{ XPCost = 20, Reward = { Kind = "Cash", Amount = 2 } },
	{ XPCost = 30, Reward = { Kind = "Cash", Amount = 3 } },
}

local bag = ForgePathClaim.Ensure(nil)
assert(bag.XP == 0 and type(bag.ClaimedSteps) == "table", "Ensure nil → fresh bag")

local partial = ForgePathClaim.Ensure({ XP = 50 })
assert(type(partial.ClaimedSteps) == "table", "Ensure partial fills ClaimedSteps")
assert(partial.XP == 50, "Ensure keeps XP")

local ok, err, step = ForgePathClaim.TryClaim({ XP = 100, ClaimedSteps = {} }, "1", steps)
assert(ok == false and err == "Invalid forge path step.", "non-number step rejected")

ok, err, step = ForgePathClaim.TryClaim({ XP = 100, ClaimedSteps = {} }, 99, steps)
assert(ok == false and err == "That forge path step doesn't exist.", "missing step")

local path = { XP = 100, ClaimedSteps = {} }
ok, err, step = ForgePathClaim.TryClaim(path, 2, steps)
assert(ok == false and err == "Claim the previous step first.", "order gate")

ok, err, step = ForgePathClaim.TryClaim({ XP = 5, ClaimedSteps = {} }, 1, steps)
assert(ok == false and err == "Not enough forge XP for that step.", "xp gate")

path = { XP = 100, ClaimedSteps = {} }
ok, err, step = ForgePathClaim.TryClaim(path, 1, steps)
assert(ok == true and err == nil and step ~= nil, "claim step 1")
assert(path.XP == 90 and path.ClaimedSteps["1"] == true, "XP deducted + claimed")

ok, err, step = ForgePathClaim.TryClaim(path, 1, steps)
assert(ok == false and err == "That step was already claimed.", "double claim")

ok, err, step = ForgePathClaim.TryClaim(path, 2, steps)
assert(ok == true and path.XP == 70 and path.ClaimedSteps["2"] == true, "claim step 2 in order")

-- --- OfflineProjection -------------------------------------------------------
local function identityPersist(v)
	return v
end

local reward, elapsed, avgEff, capped = OfflineProjection.Project(
	1000,
	1010,
	3600,
	30,
	3600,
	0,
	0,
	function()
		return { Production = 10, Efficiency = 0.5 }
	end,
	function(a, b)
		return a + b
	end,
	function(a, b)
		return a * b
	end,
	identityPersist
)
assert(reward == 0 and elapsed == 10 and avgEff == 0 and capped == false, "under minElapsed → 0")

reward, elapsed, avgEff, capped = OfflineProjection.Project(
	0,
	10_000,
	3600,
	30,
	3600,
	0,
	0,
	function()
		return { Production = 2, Efficiency = 0.5 }
	end,
	function(a, b)
		return a + b
	end,
	function(a, b)
		return a * b
	end,
	identityPersist
)
-- cap 3600s * prod 2 * eff 0.5 = 3600
assert(elapsed == 3600 and capped == true, "raw elapsed capped")
assert(reward == 3600 and avgEff == 0.5, "capped projection reward")

local samples = {}
reward, elapsed, avgEff, capped = OfflineProjection.Project(
	0,
	100,
	3600,
	30,
	50,
	40,
	0,
	function(t)
		table.insert(samples, t)
		local eff = if t < 40 then 1.0 else 0.5
		return { Production = 1, Efficiency = eff }
	end,
	function(a, b)
		return a + b
	end,
	function(a, b)
		return a * b
	end,
	identityPersist
)
assert(elapsed == 100 and capped == false, "uncapped short run")
-- boundaries: 0, 40 (boost), 50 (cycle), 100 → segments midpoints 20, 45, 75
assert(#samples == 3, "boost + cycle split into 3 samples")
-- 40*1 + 10*0.5 + 50*0.5 = 40+5+25 = 70
assert(reward == 70, "segmented boost/cycle reward")
assert(math.abs(avgEff - 0.7) < 1e-9, "weighted efficiency 70/100")

-- --- Source wiring + HARD constraints ----------------------------------------
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local gateSrc = fs.readFile("src/Server/AstralForge/Modules/ProgressionGate.luau")
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local upgradeSrc = fs.readFile("src/Server/AstralForge/Modules/UpgradeCostReason.luau")
local forgeSrc = fs.readFile("src/Server/AstralForge/Modules/ForgePathClaim.luau")
local offlineSrc = fs.readFile("src/Server/AstralForge/Modules/OfflineProjection.luau")

assert(string.find(economySrc, "OfflineProjection.Project", 1, true), "Economy must delegate OfflineProjection")
assert(string.find(economySrc, "UpgradeCostReason.LevelCost", 1, true), "Economy must use UpgradeCostReason costs")
assert(string.find(economySrc, "TapCritProjection.TapPower", 1, true), "Economy must delegate TapCritProjection")
assert(string.find(economySrc, "CapacityProjection.SteadyProduction", 1, true), "Economy must delegate CapacityProjection")
assert(string.find(gateSrc, "UpgradeCostReason.Evaluate", 1, true), "ProgressionGate must delegate Evaluate")
assert(string.find(progressionSrc, "ForgePathClaim.TryClaim", 1, true), "ProgressionService must delegate TryClaim")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { economySrc, gateSrc, progressionSrc, upgradeSrc, forgeSrc, offlineSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(upgradeSrc, "GetService", 1, true), "UpgradeCostReason must stay pure")
assert(not string.find(forgeSrc, "GetService", 1, true), "ForgePathClaim must stay pure")
assert(not string.find(offlineSrc, "GetService", 1, true), "OfflineProjection must stay pure")

print("[INFO] [TEST] extractable modules passed | UpgradeCostReason+ForgePathClaim+OfflineProjection")
