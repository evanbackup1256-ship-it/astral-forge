--!strict
-- Pure-module extract guards: ForgeEchoMath (inventory count / slots / effect /
-- upgrade cost / dominant pattern). Mirrors verify_anomaly_pulse style.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local ForgeEchoMath = require("../src/Server/AstralForge/Modules/ForgeEchoMath")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label)
end

-- --- Inventory / slots -------------------------------------------------------
assert(ForgeEchoMath.InventoryCount(nil) == 0, "nil inventory → 0")
assert(ForgeEchoMath.InventoryCount({}) == 0, "empty inventory → 0")
assert(ForgeEchoMath.InventoryCount({ A = true, B = true }) == 2, "two echoes")

local requirements = { 0, 3, 8, 15 }
assert(ForgeEchoMath.UnlockedSlots(0, requirements, 4) == 1, "0 captures → slot 1")
assert(ForgeEchoMath.UnlockedSlots(2, requirements, 4) == 1, "below second gate → 1")
assert(ForgeEchoMath.UnlockedSlots(3, requirements, 4) == 2, "hits second gate → 2")
assert(ForgeEchoMath.UnlockedSlots(20, requirements, 4) == 4, "past all gates → max")
assert(ForgeEchoMath.UnlockedSlots(nil, requirements, 3) == 1, "nil captures → 1")
assert(ForgeEchoMath.UnlockedSlots(99, requirements, 2) == 2, "clamp to maxSlots")

-- --- Effect / upgrade --------------------------------------------------------
local trait = { BaseEffect = 0.1, EffectPerLevel = 0.05 }
near(ForgeEchoMath.EffectValue({ Level = 1, Strength = 1 }, trait, 5), 0.1, "L1 base")
near(ForgeEchoMath.EffectValue({ Level = 3, Strength = 1.2 }, trait, 5), (0.1 + 0.1) * 1.2, "L3 scaled")
near(ForgeEchoMath.EffectValue({ Level = 99, Strength = 2 }, trait, 5), (0.1 + 0.2) * 1.5, "clamp level+strength")
near(ForgeEchoMath.EffectValue(nil, trait, 5), 0.1, "nil instance → L1×1")

assert(ForgeEchoMath.UpgradeCost(1, 5, 10, 2) == 10, "L1 upgrade cost")
assert(ForgeEchoMath.UpgradeCost(2, 5, 10, 2) == 20, "L2 upgrade cost")
assert(ForgeEchoMath.UpgradeCost(5, 5, 10, 2) == 0, "max level → 0")
assert(ForgeEchoMath.UpgradeCost(nil, 5, 10, 2) == 10, "nil level → L1 cost")

-- --- Dominant pattern --------------------------------------------------------
local id, affinity = ForgeEchoMath.DominantPattern(nil)
assert(id == "Collect" and affinity == "Industry", "nil pattern → Collect/Industry")
id, affinity = ForgeEchoMath.DominantPattern({ Collect = 1, Surge = 9, Build = 2, Explore = 0 })
assert(id == "Surge" and affinity == "Impulse", "Surge dominates")
id, affinity = ForgeEchoMath.DominantPattern({ Collect = 0, Surge = 0, Build = 0, Explore = 0 })
assert(id == "Collect" and affinity == "Industry", "all-zero ties Collect")
id, affinity = ForgeEchoMath.DominantPattern({ Explore = 4 }, { Explore = "Void", Collect = "Industry" })
assert(id == "Explore" and affinity == "Void", "injected affinity map")

-- --- Ensure (Charge-only / missing bags) --------------------------------------
local fresh = ForgeEchoMath.Ensure(nil)
assert(fresh.Charge == 0 and fresh.NextId == 1, "nil → empty bag")
assert(type(fresh.Pattern) == "table" and type(fresh.Draft.Choices) == "table", "nil seeds Pattern/Draft")
assert(type(fresh.Inventory) == "table" and type(fresh.Equipped) == "table", "nil seeds Inventory/Equipped")

local chargeOnly = ForgeEchoMath.Ensure({ Charge = 12.7 })
assert(chargeOnly.Charge == 12.7, "Charge-only keeps Charge")
assert(type(chargeOnly.Draft.Choices) == "table", "Charge-only rebuilds Draft.Choices")
assert(type(chargeOnly.Pattern.Collect) == "number", "Charge-only rebuilds Pattern")
assert(chargeOnly.Captures == 0 and chargeOnly.NextId == 1, "Charge-only defaults Captures/NextId")

local partialDraft = ForgeEchoMath.Ensure({ Charge = 3, Draft = { Id = "D1" } })
assert(partialDraft.Draft.Id == "D1" and type(partialDraft.Draft.Choices) == "table", "Draft without Choices rebuilt")

-- --- Source wiring + HARD constraints ----------------------------------------
local serviceSrc = fs.readFile("src/Server/AstralForge/Services/ForgeEchoService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/ForgeEchoMath.luau")
local adminSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(serviceSrc, "ForgeEchoMath.InventoryCount", 1, true), "ForgeEchoService must delegate InventoryCount")
assert(string.find(serviceSrc, "ForgeEchoMath.UnlockedSlots", 1, true), "ForgeEchoService must delegate UnlockedSlots")
assert(string.find(serviceSrc, "ForgeEchoMath.EffectValue", 1, true), "ForgeEchoService must delegate EffectValue")
assert(string.find(serviceSrc, "ForgeEchoMath.DominantPattern", 1, true), "ForgeEchoService must delegate DominantPattern")
assert(string.find(serviceSrc, "ForgeEchoMath.UpgradeCost", 1, true), "ForgeEchoService must delegate UpgradeCost")
assert(string.find(serviceSrc, "ForgeEchoMath.Ensure", 1, true), "ForgeEchoService must delegate Ensure")
assert(string.find(mathSrc, "function ForgeEchoMath.EquippedEffect", 1, true), "ForgeEchoMath.EquippedEffect missing")
assert(string.find(fs.readFile("src/Server/AstralForge/Modules/Economy.luau"), "ForgeEchoMath.EquippedEffect", 1, true), "Economy must delegate EquippedEffect")
assert(not string.find(serviceSrc, "local function inventoryCount", 1, true), "inline inventoryCount must be removed")
assert(not string.find(serviceSrc, "local function unlockedSlots", 1, true), "inline unlockedSlots must be removed")
assert(not string.find(serviceSrc, "local function dominantPattern", 1, true), "inline dominantPattern must be removed")
assert(
	string.find(adminSrc, "ForgeEchoMath.Ensure", 1, true),
	"Admin GrantEchoCharge must ForgeEchoMath.Ensure"
)
assert(
	not string.find(adminSrc, "if profile.ForgeEchoes then profile.ForgeEchoes.Charge", 1, true),
	"Admin GrantEchoCharge must not silent-noop missing ForgeEchoes"
)
assert(string.find(configSrc, "Wave17EchoEnsure", 1, true), "DV21 lab Wave17EchoEnsure")
assert(string.find(configSrc, "Wave17ClaimClipsSoftMotion", 1, true), "DV21 lab Wave17ClaimClipsSoftMotion")
assert(string.find(configSrc, "Wave17EchoCourier", 1, true), "DV21 achievement Wave17EchoCourier")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for badgeId, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. badgeId .. " must be 0")
end

for _, body in { serviceSrc, mathSrc, adminSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] ForgeEchoMath extract guards passed")
