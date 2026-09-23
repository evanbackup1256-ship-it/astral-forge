--!strict
-- Wave21 extract-checks: RemoteFirewallMath.Inspect, ForgeEchoMath.EquippedEffect,
-- EconomyEnvelopeMath.PermanentMultiplier, DataSanitizeMath.ClampLevelBag,
-- AdminGrantMath relic uid, UtcClockMath.Week, InventoryMath.UpgradeState.
-- Complements wave21-harden (ProfileClamp / AdvanceQuestProgress) with different extracts.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local RemoteFirewallMath = require("../src/Server/AstralForge/Modules/RemoteFirewallMath")
local ForgeEchoMath = require("../src/Server/AstralForge/Modules/ForgeEchoMath")
local EconomyEnvelopeMath = require("../src/Server/AstralForge/Modules/EconomyEnvelopeMath")
local DataSanitizeMath = require("../src/Server/AstralForge/Modules/DataSanitizeMath")
local AdminGrantMath = require("../src/Server/AstralForge/Modules/AdminGrantMath")
local UtcClockMath = require("../src/Server/AstralForge/Modules/UtcClockMath")
local InventoryMath = require("../src/Client/AstralForge/inventoryMath")

------------------------------------------------------------------------
-- RemoteFirewallMath.Inspect
------------------------------------------------------------------------
assert(select(1, RemoteFirewallMath.Inspect(nil)) == true, "nil ok")
assert(select(1, RemoteFirewallMath.Inspect(true)) == true, "bool ok")
assert(select(1, RemoteFirewallMath.Inspect(42)) == true, "number ok")
assert(select(1, RemoteFirewallMath.Inspect(math.huge)) == false, "inf rejected")
assert(select(1, RemoteFirewallMath.Inspect("x")) == true, "string ok")
assert(select(1, RemoteFirewallMath.Inspect(string.rep("a", 601))) == false, "long string")
assert(select(1, RemoteFirewallMath.Inspect({ a = 1 })) == true, "table ok")
do
	local cycle = {}
	cycle.self = cycle
	assert(select(1, RemoteFirewallMath.Inspect(cycle)) == false, "cycle rejected")
end
assert(select(1, RemoteFirewallMath.Inspect({ a = { b = { c = { d = { e = 1 } } } } })) == false, "depth rejected")
do
	local big = {}
	for i = 1, 40 do
		big[i] = i
	end
	assert(select(1, RemoteFirewallMath.Inspect(big)) == false, "budget rejected")
end

------------------------------------------------------------------------
-- ForgeEchoMath.EquippedEffect
------------------------------------------------------------------------
local traits = {
	{ Id = "Spark", Affinity = "Impulse", EffectKind = "Production", BaseEffect = 0.1, EffectPerLevel = 0.05 },
	{ Id = "Coil", Affinity = "Craft", EffectKind = "Tap", BaseEffect = 0.2, EffectPerLevel = 0.1 },
}
local echoes = {
	Inventory = {
		A = { TraitId = "Spark", Level = 2, Strength = 1 },
		B = { TraitId = "Coil", Level = 1, Strength = 1 },
	},
	Equipped = { ["1"] = "A", ["2"] = "B" },
}
assert(math.abs(ForgeEchoMath.EquippedEffect(echoes, "Production", traits, 10, 0.25) - 0.1875) < 1e-9, "equipped production with harmony")
assert(ForgeEchoMath.EquippedEffect(nil, "Production", traits, 10, 0.25) == 0, "nil echoes")
-- Same affinity on two slots → no harmony; distinct affinities → harmony.
local same = {
	Inventory = {
		A = { TraitId = "Spark", Level = 1, Strength = 1 },
		C = { TraitId = "Spark", Level = 1, Strength = 1 },
	},
	Equipped = { ["1"] = "A", ["2"] = "C" },
}
assert(
	math.abs(ForgeEchoMath.EquippedEffect(same, "Production", traits, 10, 0.5) - 0.2) < 1e-9,
	"same affinity no harmony"
)
local spark2 = {
	Id = "Spark2",
	Affinity = "Industry",
	EffectKind = "Production",
	BaseEffect = 0.1,
	EffectPerLevel = 0,
}
local harmonyTraits = { traits[1], spark2 }
local distinct = {
	Inventory = {
		A = { TraitId = "Spark", Level = 1, Strength = 1 },
		D = { TraitId = "Spark2", Level = 1, Strength = 1 },
	},
	Equipped = { ["1"] = "A", ["2"] = "D" },
}
assert(
	math.abs(ForgeEchoMath.EquippedEffect(distinct, "Production", harmonyTraits, 10, 0.5) - 0.3) < 1e-9,
	"distinct affinity harmony"
)

------------------------------------------------------------------------
-- EconomyEnvelopeMath.PermanentMultiplier
------------------------------------------------------------------------
local base = EconomyEnvelopeMath.PermanentMultiplier(0, 0.01, 0.5, 0, 0, 1e6, 0.01, 0.001, 0, 0, 0, 0.05, 0, 0)
assert(math.abs(base - 1) < 1e-9, "identity permanent")
local ranked = EconomyEnvelopeMath.PermanentMultiplier(0, 0.01, 0.5, 2, 100, 1e6, 0.01, 0.001, 0.05, 0.02, 0, 0.05, 0, 0)
assert(math.abs(ranked - (1 + 0.02 + 0.1 + 0.05 + 0.02)) < 1e-9, "rank+essence+tree+path")
local capped = EconomyEnvelopeMath.PermanentMultiplier(0, 0, 1, 0, 2_000_000, 1_000_000, 0, 0.001, 0, 0, 0, 0, 0, 0)
assert(math.abs(capped - (1 + 1000)) < 1e-6, "essence soft-cap")

------------------------------------------------------------------------
-- DataSanitizeMath.ClampLevelBag
------------------------------------------------------------------------
local bag = { Drill = 5, Ghost = 3, Pump = -2 }
DataSanitizeMath.ClampLevelBag(bag, { Drill = { MaxLevel = 10 }, Pump = { MaxLevel = 4 } }, DataSanitizeMath.NonNegative)
assert(bag.Drill == 5, "drill kept")
assert(bag.Ghost == nil, "unknown dropped")
assert(bag.Pump == nil, "zero after clamp dropped")
local over = { Drill = 99 }
DataSanitizeMath.ClampLevelBag(over, { Drill = { MaxLevel = 7 } })
assert(over.Drill == 7, "max clamp")

------------------------------------------------------------------------
-- AdminGrantMath relic uid
------------------------------------------------------------------------
local uid, nextId = AdminGrantMath.NextRelicUid({}, 1)
assert(uid == "IT0000001" and nextId == 2, "first uid")
local uid2, nextId2 = AdminGrantMath.NextRelicUid({ IT0000002 = true }, 2)
assert(uid2 == "IT0000003" and nextId2 == 4, "skip collision")
local inst = AdminGrantMath.BuildRelicInstance("RelicA", 123)
assert(inst and inst.DefinitionId == "RelicA" and inst.Level == 1 and inst.AcquiredAt == 123, "relic instance")
assert(AdminGrantMath.BuildRelicInstance("", 1) == nil, "empty def rejected")

------------------------------------------------------------------------
-- UtcClockMath.Week
------------------------------------------------------------------------
assert(UtcClockMath.Day(86_400) == 1, "day")
assert(UtcClockMath.Week(UtcClockMath.WEEK_SECONDS) == 1, "week")
assert(UtcClockMath.Week(UtcClockMath.WEEK_SECONDS * 3 + 10) == 3, "week floor")

------------------------------------------------------------------------
-- InventoryMath.UpgradeState
------------------------------------------------------------------------
local can, maxed = InventoryMath.UpgradeState(3, 5, 100, 50)
assert(can == true and maxed == false, "affordable")
local can2, maxed2 = InventoryMath.UpgradeState(5, 5, 999, 1)
assert(can2 == false and maxed2 == true, "maxed")
local can3 = InventoryMath.UpgradeState(2, 5, 10, 50)
assert(can3 == false, "underfunded")

------------------------------------------------------------------------
-- Service residual wiring markers
------------------------------------------------------------------------
local firewallSrc = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local adminSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local invViewSrc = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(firewallSrc, "RemoteFirewallMath.Inspect", 1, true), "Firewall Inspect residual")
assert(string.find(dataSrc, "DataSanitizeMath.ClampLevelBag", 1, true), "DataService ClampLevelBag residual")
assert(string.find(adminSrc, "AdminGrantMath.NextRelicUid", 1, true), "Admin NextRelicUid residual")
assert(string.find(adminSrc, "AdminGrantMath.BuildRelicInstance", 1, true), "Admin BuildRelicInstance residual")
assert(string.find(progressionSrc, "UtcClockMath.Week", 1, true), "Progression Week residual")
assert(string.find(progressionSrc, "UtcClockMath.Day", 1, true), "Progression Day residual")
assert(string.find(economySrc, "EconomyEnvelopeMath.PermanentMultiplier", 1, true), "Economy PermanentMultiplier residual")
assert(string.find(economySrc, "ForgeEchoMath.EquippedEffect", 1, true), "Economy EquippedEffect residual")
assert(string.find(invViewSrc, "InventoryMath.UpgradeState", 1, true), "InventoryView UpgradeState residual")

assert(string.find(configSrc, "Wave21FirewallEchoExtract", 1, true), "DV21 lab Wave21FirewallEchoExtract")
assert(string.find(configSrc, "Wave21EnvelopeUtcExtract", 1, true), "DV21 lab Wave21EnvelopeUtcExtract")
assert(string.find(configSrc, "Wave21ExtractCourier", 1, true), "DV21 achievement Wave21ExtractCourier")
assert(string.find(configSrc, "wave21-extract-brief", 1, true), "DV21 story wave21-extract-brief")
assert(string.find(configSrc, "update-5-1-wave21-extract", 1, true), "DV21 mail update-5-1-wave21-extract")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { firewallSrc, dataSrc, adminSrc, progressionSrc, economySrc, invViewSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] wave21 extract-checks guards passed")
