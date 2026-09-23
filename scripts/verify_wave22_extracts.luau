--!strict
-- Wave22 extract-checks: RemoteFirewallMath.IsSessionOnlyPayload,
-- DataSanitizeMath.ClampAutoForge, ForgeEchoMath.Sanitize,
-- EconomyEnvelopeMath.ItemEffect, ItemLoadoutMath EquipBest plan,
-- InventoryMath ChipRows/LoadoutEffectLines, ProgressionOpsMath CommandXP,
-- ReleaseClockMath + UtcClockMath Remaining.
-- Complements wave22-harden with different extracts.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local RemoteFirewallMath = require("../src/Server/AstralForge/Modules/RemoteFirewallMath")
local DataSanitizeMath = require("../src/Server/AstralForge/Modules/DataSanitizeMath")
local ForgeEchoMath = require("../src/Server/AstralForge/Modules/ForgeEchoMath")
local EconomyEnvelopeMath = require("../src/Server/AstralForge/Modules/EconomyEnvelopeMath")
local ItemLoadoutMath = require("../src/Server/AstralForge/Modules/ItemLoadoutMath")
local ProgressionOpsMath = require("../src/Server/AstralForge/Modules/ProgressionOpsMath")
local UtcClockMath = require("../src/Server/AstralForge/Modules/UtcClockMath")
local InventoryMath = require("../src/Client/AstralForge/inventoryMath")
local ReleaseClockMath = require("../src/Client/AstralForge/releaseClockMath")

------------------------------------------------------------------------
-- RemoteFirewallMath.IsSessionOnlyPayload
------------------------------------------------------------------------
assert(RemoteFirewallMath.IsSessionOnlyPayload({ Gen = 1, N = 2 }) == true, "session only ok")
assert(RemoteFirewallMath.IsSessionOnlyPayload({ Gen = 1, Amount = 3 }) == false, "extra key rejected")
assert(RemoteFirewallMath.IsSessionOnlyPayload({}) == true, "empty session ok")
assert(RemoteFirewallMath.IsSessionOnlyPayload(nil) == false, "nil rejected")
assert(RemoteFirewallMath.SESSION_KEYS.TxnId == true, "TxnId session key")

------------------------------------------------------------------------
-- DataSanitizeMath.ClampAutoForge
------------------------------------------------------------------------
local auto = DataSanitizeMath.ClampAutoForge(nil, { StellarCore = {}, Drill = {} }, "StellarCore")
assert(auto.Enabled == false and auto.MachineId == "StellarCore", "autoforge defaults")
assert(auto.Reserve == 0.25 and auto.Bought == 0, "autoforge reserve/bought")
local dirty = DataSanitizeMath.ClampAutoForge({
	Enabled = true,
	MachineId = "Ghost",
	Reserve = 2,
	Bought = -3,
}, { StellarCore = {}, Drill = {} }, "StellarCore", DataSanitizeMath.NonNegative)
assert(dirty.MachineId == "StellarCore", "unknown machine → default")
assert(dirty.Reserve == 0.9 and dirty.Bought == 0, "reserve/bought clamp")
assert(dirty.Enabled == true, "enabled kept")

------------------------------------------------------------------------
-- ForgeEchoMath.Sanitize
------------------------------------------------------------------------
local traits = { Spark = { Id = "Spark", Affinity = "Impulse" } }
local sanitized = ForgeEchoMath.Sanitize({
	Charge = 999,
	Resonance = -2,
	Captures = 1.7,
	NextId = 0,
	Pattern = { Collect = 3, Ghost = 9 },
	Inventory = {
		E1 = { TraitId = "Spark", Level = 99, Strength = 9, CapturedAt = -1 },
		Bad = { TraitId = "Nope", Level = 1 },
	},
	Equipped = { ["1"] = "E1", ["9"] = "E1", ["2"] = "missing" },
	Draft = {
		Id = string.rep("x", 60),
		Choices = {
			{ TraitId = "Spark", Uid = "C1", Strength = 2, CapturedAt = 5 },
			{ TraitId = "Nope", Uid = "C2" },
		},
	},
}, traits, { ChargeTarget = 100, MaxLevel = 10, InventoryLimit = 8, MaxSlots = 3 })
assert(sanitized.Charge == 100, "charge capped")
assert(sanitized.Resonance == 0 and sanitized.Captures == 1 and sanitized.NextId == 1, "echo scalars")
assert(sanitized.Pattern.Collect == 3 and sanitized.Pattern.Ghost == nil, "pattern scrub")
assert(sanitized.Inventory.E1 ~= nil and sanitized.Inventory.Bad == nil, "inventory scrub")
assert(sanitized.Inventory.E1.Level == 10 and sanitized.Inventory.E1.Strength == 1.5, "instance clamp")
assert(sanitized.Equipped["1"] == "E1" and sanitized.Equipped["2"] == "" and sanitized.Equipped["9"] == nil, "equip slots")
assert(#sanitized.Draft.Id == 48 and #sanitized.Draft.Choices == 1, "draft scrub")
assert(sanitized.Draft.Choices[1].Strength == 1.32, "draft strength clamp")

------------------------------------------------------------------------
-- EconomyEnvelopeMath.ItemEffect
------------------------------------------------------------------------
local defs = {
	RelicA = { EffectKind = "Production", BaseEffect = 0.1, LevelGrowth = 0.05 },
	RelicB = { EffectKind = "Tap", BaseEffect = 0.2, LevelGrowth = 0 },
}
local items = {
	Equipped = { ["Machine:Drill"] = "u1", ["Research:Efficiency"] = "u2" },
	Inventory = {
		u1 = { DefinitionId = "RelicA", Level = 3 },
		u2 = { DefinitionId = "RelicB", Level = 1 },
	},
}
local getDef = function(id)
	return defs[id]
end
assert(
	math.abs(EconomyEnvelopeMath.ItemEffect(items, { Drill = 2 }, { Efficiency = 1 }, "Production", getDef) - 0.1 * 1.1) < 1e-9,
	"item production"
)
assert(EconomyEnvelopeMath.ItemEffect(items, { Drill = 0 }, {}, "Production", getDef) == 0, "unowned socket")
assert(
	math.abs(EconomyEnvelopeMath.ItemEffect(items, { Drill = 1 }, { Efficiency = 1 }, "Tap", getDef, "Research") - 0.2) < 1e-9,
	"slot filter research tap"
)
assert(EconomyEnvelopeMath.ItemEffect(nil, {}, {}, "Production", getDef) == 0, "nil items")

------------------------------------------------------------------------
-- ItemLoadoutMath EquipBest
------------------------------------------------------------------------
assert(ItemLoadoutMath.IsCompatible({ Slot = "Machine" }, { Slot = "Machine", TargetId = "Drill" }) == true, "open targets")
assert(ItemLoadoutMath.IsCompatible({ Slot = "Machine", Targets = { "Pump" } }, { Slot = "Machine", TargetId = "Drill" }) == false, "targets miss")
assert(math.abs(ItemLoadoutMath.CandidatePower({ BaseEffect = 0.1, LevelGrowth = 0.05 }, 3) - 0.11) < 1e-9, "candidate power")
local sockets = ItemLoadoutMath.BuildTargets(
	{ { Id = "Drill" }, { Id = "Pump" } },
	{ { Id = "Efficiency" } },
	{ Drill = 2, Pump = 0 },
	{ Efficiency = 1 }
)
assert(#sockets == 2 and sockets[1].Id == "Machine:Drill", "build targets")
local nextEq, count, changed = ItemLoadoutMath.PlanEquipBest(
	sockets,
	{
		{
			Uid = "a",
			Power = 0.2,
			Definition = { Slot = "Machine", Rarity = "Rare" },
			Instance = { Level = 2 },
		},
		{
			Uid = "b",
			Power = 0.5,
			Definition = { Slot = "Research", Rarity = "Common", Targets = { "Efficiency" } },
			Instance = { Level = 1 },
		},
	},
	{ Rare = { Rank = 3 }, Common = { Rank = 1 } },
	{}
)
assert(count == 2 and nextEq["Machine:Drill"] == "a" and nextEq["Research:Efficiency"] == "b", "plan equip")
assert(changed == 2, "changed from empty")

------------------------------------------------------------------------
-- InventoryMath ChipRows / LoadoutEffectLines
------------------------------------------------------------------------
assert(InventoryMath.ChipRows(0, false) == 0, "chip empty")
assert(InventoryMath.ChipRows(4, false) == 2, "chip desk 3-col")
assert(InventoryMath.ChipRows(4, true) == 2, "chip stack 2-col")
assert(InventoryMath.ChipRows(5, true) == 3, "chip stack 5")
local lines = InventoryMath.LoadoutEffectLines({ Production = 0.12, Tap = 0.05 })
assert(#lines == 6 and lines[1].id == "Production" and lines[1].value == 0.12, "loadout production")
assert(lines[3].id == "Tap" and lines[3].value == 0.05, "loadout tap")
assert(lines[2].value == 0, "loadout missing → 0")

------------------------------------------------------------------------
-- ProgressionOpsMath CommandXP
------------------------------------------------------------------------
assert(ProgressionOpsMath.ScaledCommandXP(10, 0.5) == 15, "scaled xp")
assert(ProgressionOpsMath.ScaledCommandXP(-3, 1) == 0, "scaled floor")
local command = { XP = 4, SeasonXP = 2 }
assert(ProgressionOpsMath.ApplyCommandXP(command, 10, 0.5) == 15, "apply granted")
assert(command.XP == 19 and command.SeasonXP == 17, "apply bags")

------------------------------------------------------------------------
-- ReleaseClockMath / UtcClockMath Remaining parity
------------------------------------------------------------------------
assert(ReleaseClockMath.Remaining(100, 40) == 60, "release remaining")
assert(ReleaseClockMath.Remaining(10, 40) == 0, "release floored")
assert(ReleaseClockMath.IsLive(10, 40) == true, "release live")
assert(UtcClockMath.Remaining(100, 40) == 60, "utc remaining parity")
assert(UtcClockMath.IsLive(100, 40) == false, "utc not live")

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local firewallSrc = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local econSrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local ssSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local progSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local invSrc = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local mainSrc = fs.readFile("src/Client/AstralForge/MainGame.luau")
local routerSrc = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(firewallSrc, "RemoteFirewallMath.IsSessionOnlyPayload", 1, true), "Firewall session residual")
assert(string.find(dataSrc, "ForgeEchoMath.Sanitize", 1, true), "DataService Sanitize residual")
assert(string.find(dataSrc, "DataSanitizeMath.ClampAutoForge", 1, true), "DataService AutoForge residual")
assert(string.find(econSrc, "EconomyEnvelopeMath.ItemEffect", 1, true), "Economy ItemEffect residual")
assert(string.find(ssSrc, "ItemLoadoutMath.PlanEquipBest", 1, true), "ServerServices EquipBest residual")
assert(string.find(ssSrc, "ItemLoadoutMath.BuildTargets", 1, true), "ServerServices BuildTargets residual")
assert(string.find(progSrc, "ProgressionOpsMath.ApplyCommandXP", 1, true), "Progression ApplyCommandXP residual")
assert(string.find(invSrc, "InventoryMath.ChipRows", 1, true), "Inventory ChipRows residual")
assert(string.find(invSrc, "InventoryMath.LoadoutEffectLines", 1, true), "Inventory LoadoutEffectLines residual")
assert(string.find(mainSrc, "ReleaseClockMath.Remaining", 1, true), "MainGame ReleaseClock residual")
assert(string.find(routerSrc, "ReleaseClockMath.Remaining", 1, true), "PageRouter ReleaseClock residual")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in {
	firewallSrc,
	dataSrc,
	econSrc,
	ssSrc,
	progSrc,
	invSrc,
	mainSrc,
	routerSrc,
	fs.readFile("src/Server/AstralForge/Modules/ItemLoadoutMath.luau"),
	fs.readFile("src/Client/AstralForge/releaseClockMath.luau"),
	fs.readFile("src/Server/AstralForge/Modules/ForgeEchoMath.luau"),
} do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] wave22 extract-checks pure checks passed")
