--!strict
-- Pure-module extract guards: EconomyEnvelopeMath + ContinuumEffects /
-- ForgePathClaim.Effect / RebirthGate.NextPrestigeTarget wiring.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local ContinuumDomainMath = require("../src/Server/AstralForge/Modules/ContinuumDomainMath")
local ForgePathClaim = require("../src/Server/AstralForge/Modules/ForgePathClaim")
local RebirthGate = require("../src/Server/AstralForge/Modules/RebirthGate")
local EconomyEnvelopeMath = require("../src/Server/AstralForge/Modules/EconomyEnvelopeMath")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label .. " got " .. tostring(actual))
end

------------------------------------------------------------------------
-- EconomyEnvelopeMath
------------------------------------------------------------------------
assert(EconomyEnvelopeMath.SumNumericLevels(nil) == 0, "nil bag → 0")
assert(EconomyEnvelopeMath.SumNumericLevels({ A = 2, B = 3, C = "x" }) == 5, "sum numeric only")
assert(EconomyEnvelopeMath.MasteryMultiplier(nil) == 1, "nil mastery → 1")
near(EconomyEnvelopeMath.MasteryMultiplier({ Drill = 100, Pump = 150 }), 1.5, "mastery soft-caps +50%")
near(EconomyEnvelopeMath.MasteryMultiplier({ Drill = 10 }), 1.02, "mastery 10 pts → +2%")
assert(
	EconomyEnvelopeMath.DomainTreeBonus({ NodeA = true }, { { Id = "NodeA", Production = 0.05 } }, "Production")
		== 0.05,
	"domain tree bonus"
)
assert(EconomyEnvelopeMath.DomainTreeBonus(nil, {}, "Production") == 0, "nil nodes → 0")
near(EconomyEnvelopeMath.AutoCollectRate(10, 0.1, 0, 0, 0, 0, 0, 0.05), math.min(0.8, 0.2 + 0.1 + 0.05), "auto collect")
assert(EconomyEnvelopeMath.AutoCollectRate(1000, 1, 1, 1, 1, 1, 1, 1) == 0.8, "auto collect soft-cap")
near(EconomyEnvelopeMath.OfflineHours(4, 2, 0.5, 24), 4 + 2.5 + 0.5, "offline hours")
assert(EconomyEnvelopeMath.OfflineHours(4, 100, 0, 24) == 24, "offline hours soft-cap")
near(
	EconomyEnvelopeMath.OfflineEfficiency(0.25, 1, 0.05, 0, 0, 0, 0, 0, 2, 0.01, 0.1, 0.02),
	math.min(1, 0.25 + 0.06 + 0.05 + 0.02 + 0.1 + 0.02),
	"offline efficiency"
)

------------------------------------------------------------------------
-- ContinuumDomainMath.ContinuumEffects
------------------------------------------------------------------------
local continuumFx = {
	ProductionScale = 1.16,
	MilestoneEvery = 25,
	MilestoneScale = 1.5,
	CapacityScale = 1.10,
	TapScale = 1.14,
	OfflineCap = 0.45,
	OfflinePerRank = 0.0025,
}
local prod0, cap0, tap0, off0 = ContinuumDomainMath.ContinuumEffects(OmegaMath, continuumFx, 0)
assert(OmegaMath.ToNumber(prod0) == 1 and OmegaMath.ToNumber(cap0) == 1 and OmegaMath.ToNumber(tap0) == 1, "rank 0 identity")
assert(off0 == 0, "rank 0 offline")
local prod25 = select(1, ContinuumDomainMath.ContinuumEffects(OmegaMath, continuumFx, 25))
local prod24 = select(1, ContinuumDomainMath.ContinuumEffects(OmegaMath, continuumFx, 24))
assert(OmegaMath.Gt(prod25, prod24), "milestone must boost production")
local _, _, _, off200 = ContinuumDomainMath.ContinuumEffects(OmegaMath, continuumFx, 200)
assert(off200 == continuumFx.OfflineCap, "offline soft-cap")

------------------------------------------------------------------------
-- ForgePathClaim.Effect
------------------------------------------------------------------------
local steps = {
	{ EffectKind = "Production", EffectAmount = 2 },
	{ EffectKind = "TapPower", EffectAmount = 5 },
	{ EffectKind = "Production", EffectAmount = 3 },
}
near(ForgePathClaim.Effect({ ["1"] = true, ["3"] = true }, steps, "Production"), 0.05, "forge path production")
near(ForgePathClaim.Effect({ ["2"] = true }, steps, "TapPower"), 0.05, "forge path tap")
assert(ForgePathClaim.Effect(nil, steps, "Production") == 0, "nil claimed → 0")
assert(ForgePathClaim.Effect({ ["1"] = true }, nil, "Production") == 0, "nil steps → 0")

------------------------------------------------------------------------
-- RebirthGate.NextPrestigeTarget
------------------------------------------------------------------------
local nextTarget = RebirthGate.NextPrestigeTarget(OmegaMath, 0, 1000, 0.5)
assert(type(OmegaMath.ToNumber(nextTarget)) == "number", "next prestige numeric")
assert(OmegaMath.ToNumber(nextTarget) > 0, "next prestige at 0 reward > 0")
-- Floating Persist floors can land just under requirement (999.999→999); allow ≤1 ulp.
assert(math.abs(OmegaMath.ToNumber(nextTarget) - 1000) <= 1, "next prestige near requirement")
local higher = RebirthGate.NextPrestigeTarget(OmegaMath, 4, 1000, 0.5)
assert(OmegaMath.Gte(higher, nextTarget), "next prestige must not regress with reward")

------------------------------------------------------------------------
-- Economy wiring residuals
------------------------------------------------------------------------
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
assert(string.find(economySrc, "ContinuumDomainMath.ContinuumEffects", 1, true), "Economy ContinuumEffects must delegate")
assert(string.find(economySrc, "ForgePathClaim.Effect", 1, true), "Economy ForgePathEffect must delegate")
assert(string.find(economySrc, "RebirthGate.NextPrestigeTarget", 1, true), "Economy NextPrestigeTarget must delegate")
assert(string.find(economySrc, "EconomyEnvelopeMath.AutoCollectRate", 1, true), "Economy AutoCollectRate must delegate")
assert(string.find(economySrc, "EconomyEnvelopeMath.OfflineHours", 1, true), "Economy OfflineHours must delegate")
assert(string.find(economySrc, "EconomyEnvelopeMath.OfflineEfficiency", 1, true), "Economy OfflineEfficiency must delegate")
assert(string.find(economySrc, "EconomyEnvelopeMath.SumNumericLevels", 1, true), "Economy totals must delegate")
assert(string.find(economySrc, "EconomyEnvelopeMath.MasteryMultiplier", 1, true), "Economy MasteryMultiplier must delegate")
assert(string.find(economySrc, "EconomyEnvelopeMath.DomainTreeBonus", 1, true), "Economy DomainTreeBonus must delegate")

local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
for _, body in {
	economySrc,
	fs.readFile("src/Server/AstralForge/Modules/EconomyEnvelopeMath.luau"),
	fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau"),
	fs.readFile("src/Server/AstralForge/Modules/ForgePathClaim.luau"),
	fs.readFile("src/Server/AstralForge/Modules/RebirthGate.luau"),
} do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] economy envelope extract passed | ContinuumEffects+ForgePathEffect+NextPrestige+Envelope")
