--!strict
-- Pure-module extract guards: TapCritProjection + CapacityProjection.
-- Mirrors verify_extract_modules style — require under Lune, assert behavior.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local CapacityProjection = require("../src/Shared/AstralForge/Shared/CapacityProjection")
local TapCritProjection = require("../src/Server/AstralForge/Modules/TapCritProjection")

-- --- TapCritProjection -------------------------------------------------------
local tap = TapCritProjection.TapPower(OmegaMath, 100, 0, {
	Grid = 0,
	Echo = 0,
	Artifact = 0,
	Item = 0,
	Anomaly = 0,
	Lab = 0,
	Guild = 0,
	Continuum = 1,
	ForgePath = 0,
})
assert(OmegaMath.ToNumber(tap) == 15, "base tap is 15% of production")

tap = TapCritProjection.TapPower(OmegaMath, 100, 2, {
	Grid = 0.1,
	Echo = 0,
	Artifact = 0,
	Item = 0,
	Anomaly = 0,
	Lab = 0,
	Guild = 0.05,
	Continuum = 1.2,
	ForgePath = 0.1,
})
-- 15 * (1+0.7) * 1.1 * 1.05 * 1.2 * 1.1
local expectedTap = 15 * 1.7 * 1.1 * 1.05 * 1.2 * 1.1
assert(math.abs(OmegaMath.ToNumber(tap) - expectedTap) < 1e-9, "tap multiplies overcharge+bonuses")

tap = TapCritProjection.TapPower(OmegaMath, 1, 0, {
	Grid = 0,
	Echo = 0,
	Artifact = 0,
	Item = 0,
	Anomaly = 0,
	Lab = 0,
	Guild = 0,
	Continuum = 1,
	ForgePath = 0,
})
assert(OmegaMath.ToNumber(tap) == 1, "tap floors at 1 when production*0.15 < 1")

assert(TapCritProjection.CriticalChance(0, 0, 0, 0, 0, 0, 0) == 0.05, "base crit chance 5%")
assert(
	TapCritProjection.CriticalChance(10, 0.1, 0, 0, 0, 0, 0.05) == math.min(0.75, 0.05 + 0.12 + 0.1 + 0.05),
	"crit chance stacks research+effects"
)
assert(TapCritProjection.CriticalChance(1000, 1, 1, 1, 1, 1, 1) == 0.75, "crit chance soft-caps at 75%")

assert(TapCritProjection.CriticalMultiplier(0, 0, 0) == 2, "base crit mult 2x")
assert(TapCritProjection.CriticalMultiplier(5, 2, 0.1) == 2 + 0.5 + 0.2 + 0.1, "crit mult floors /5 + Impact")
assert(TapCritProjection.CriticalMultiplier(9, 0, 0) == 2 + math.floor(9 / 5) * 0.5, "crit mult floor at 9")

-- --- CapacityProjection (steady + vault) -------------------------------------
local steady = CapacityProjection.SteadyProduction(OmegaMath, 10, {
	EfficiencyLevel = 0,
	ZoneMultiplier = 1,
	PermanentMultiplier = 1,
	Additives = { 0, 0, 0, 0, 0, 0, 0, 0 },
	SocialMultiplier = 1,
	MasteryMultiplier = 1,
	ContinuumProduction = 1,
})
assert(OmegaMath.ToNumber(steady) == 10, "identity steady production")

steady = CapacityProjection.SteadyProduction(OmegaMath, 10, {
	EfficiencyLevel = 2, -- 1 + 0.3 = 1.3
	ZoneMultiplier = 2,
	PermanentMultiplier = 1.5,
	Additives = { 0.1, 0, 0, 0, 0, 0, 0.05, 0 }, -- 1.1 * 1.05
	SocialMultiplier = 0.5, -- max(1, 0.5) = 1
	MasteryMultiplier = 1.2,
	ContinuumProduction = 1.1,
})
-- 10 * 1.3 * 2 * 1.5 * 1.1 * 1.05 * 1 * 1.2 * 1.1
local expectedSteady = 10 * 1.3 * 2 * 1.5 * 1.1 * 1.05 * 1.2 * 1.1
assert(math.abs(OmegaMath.ToNumber(steady) - expectedSteady) < 1e-9, "steady multiplies permanent parts")

local seconds = CapacityProjection.Seconds({
	BaseSeconds = 45,
	SecondsPerLevel = 1.16,
	StorageLevel = 0,
	Additives = { 0, 0, 0, 0, 0, 0, 0, 0, 0 },
	DomainRank = 0,
	CapacityPerRank = 0.1,
	BoostCapacityMultiplier = 1,
	MaxSeconds = 6 * 60 * 60,
	DomainTreeCapacity = 0,
})
assert(seconds == 45, "base capacity seconds")

-- DomainTree applied AFTER clamp: start huge → clamp → then * (1+tree)
seconds = CapacityProjection.Seconds({
	BaseSeconds = 45,
	SecondsPerLevel = 1.16,
	StorageLevel = 80,
	Additives = { 10, 10, 10, 10, 10, 10, 10, 10, 10 },
	DomainRank = 100,
	CapacityPerRank = 1,
	BoostCapacityMultiplier = 10,
	MaxSeconds = 100,
	DomainTreeCapacity = 0.5,
})
assert(seconds == 150, "tree bonus applies after max clamp (100 * 1.5)")

local vault = CapacityProjection.Vault(OmegaMath, 500, 10, 45, 1)
assert(OmegaMath.ToNumber(vault) == 450, "vault = steady * seconds when above base")
vault = CapacityProjection.Vault(OmegaMath, 500, 1, 10, 1)
assert(OmegaMath.ToNumber(vault) == 500, "vault floors at BaseCapacity")
vault = CapacityProjection.Vault(OmegaMath, 500, 10, 45, 2)
assert(OmegaMath.ToNumber(vault) == 900, "continuum capacity scales vault")

assert(CapacityProjection.CapacitySeconds(OmegaMath, 450, 10, OmegaMath.Lte) == 45, "capacity seconds from ratio")
assert(CapacityProjection.CapacitySeconds(OmegaMath, 500, 0, OmegaMath.Lte) == 0, "idle steady → 0 seconds")

-- --- Source wiring + HARD constraints ----------------------------------------
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local tapSrc = fs.readFile("src/Server/AstralForge/Modules/TapCritProjection.luau")
local capSrc = fs.readFile("src/Shared/AstralForge/Shared/CapacityProjection.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(economySrc, "TapCritProjection.TapPower", 1, true), "Economy must delegate TapPower")
assert(string.find(economySrc, "TapCritProjection.CriticalChance", 1, true), "Economy must delegate CriticalChance")
assert(string.find(economySrc, "TapCritProjection.CriticalMultiplier", 1, true), "Economy must delegate CriticalMultiplier")
assert(string.find(economySrc, "CapacityProjection.SteadyProduction", 1, true), "Economy must delegate SteadyProduction")
assert(string.find(economySrc, "CapacityProjection.Seconds", 1, true), "Economy must delegate Capacity seconds")
assert(string.find(economySrc, "CapacityProjection.Vault", 1, true), "Economy must delegate Capacity vault")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { economySrc, tapSrc, capSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(tapSrc, "GetService", 1, true), "TapCritProjection must stay pure")
assert(not string.find(capSrc, "GetService", 1, true), "CapacityProjection must stay pure")

print("[INFO] [TEST] economy projection passed | TapCrit+Capacity/Steady")
