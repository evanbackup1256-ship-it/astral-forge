--!strict
-- Pure-module extract guards: InventoryMath (effect/upgrade/salvage, filter/sort/
-- search, auto-salvage signature) + ItemSalvage formula parity.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local InventoryMath = require("../src/Client/AstralForge/inventoryMath")
local ItemSalvage = require("../src/Server/AstralForge/Modules/ItemSalvage")

local config = {
	Items = {
		Rarities = {
			Common = { Rank = 1 },
			Rare = { Rank = 3 },
			Mythic = { Rank = 6 },
		},
	},
}

assert(InventoryMath.RarityRank(config, "Rare") == 3, "rarity rank")
assert(InventoryMath.RarityRank(config, "Missing") == 0, "missing rarity → 0")
assert(InventoryMath.RelicRowHeight(false) == InventoryMath.ROW_H, "desk row height")
assert(InventoryMath.RelicRowHeight(true) == InventoryMath.ROW_H_STACK, "stack row height")

local def = { BaseEffect = 0.1, LevelGrowth = 0.05, EffectKind = "Production", EssenceBase = 20, Rarity = "Rare", Name = "Flux Core", Description = "boosts", Slot = "Core" }
assert(math.abs(InventoryMath.EffectAtLevel(def, 1) - 0.1) < 1e-9, "effect L1")
assert(math.abs(InventoryMath.EffectAtLevel(def, 3) - 0.1 * (1 + 0.1)) < 1e-9, "effect L3")
assert(InventoryMath.EffectLabel(def, 1) == "+10% Production", "effect label")
assert(InventoryMath.UpgradeCost(def, 1) == 20, "upgrade L1")
assert(InventoryMath.UpgradeCost(def, 2) == math.floor(20 * 1.55), "upgrade L2")

-- Salvage parity with server ItemSalvage.Value
assert(InventoryMath.SalvageValue(1, 3) == ItemSalvage.Value(1, 3), "salvage L1 parity")
assert(InventoryMath.SalvageValue(5, 3) == ItemSalvage.Value(5, 3), "salvage L5 parity")
assert(InventoryMath.SalvagePreview(config, def, 4) == ItemSalvage.Value(4, 3), "salvage preview uses rarity rank")

assert(InventoryMath.SocketLabel("Machine:Drill") == "Machine / Drill", "socket label")
assert(InventoryMath.SocketLabel("Solo") == "Solo", "socket passthrough")

local owned = {
	{
		uid = "a",
		equippedOn = "Machine:Drill",
		instance = { Level = 2, Locked = false, AcquiredAt = 10 },
		definition = { Name = "Beta", Rarity = "Common", Slot = "Core", Description = "old", EffectKind = "Tap", BaseEffect = 0.05, LevelGrowth = 0.01 },
	},
	{
		uid = "b",
		equippedOn = nil,
		instance = { Level = 5, Locked = true, AcquiredAt = 20 },
		definition = { Name = "Alpha", Rarity = "Mythic", Slot = "Frame", Description = "shine", EffectKind = "Production", BaseEffect = 0.2, LevelGrowth = 0.1 },
	},
	{
		uid = "c",
		equippedOn = nil,
		instance = { Level = 1, Locked = false, AcquiredAt = 5 },
		definition = { Name = "Gamma", Rarity = "Rare", Slot = "Core", Description = "mid", EffectKind = "Capacity", BaseEffect = 0.08, LevelGrowth = 0.02 },
	},
}

assert(#InventoryMath.FilterOwned(owned, "All") == 3, "filter all")
assert(#InventoryMath.FilterOwned(owned, "Equipped") == 1, "filter equipped")
assert(#InventoryMath.FilterOwned(owned, "Unequipped") == 2, "filter unequipped")
assert(#InventoryMath.FilterOwned(owned, "Protected") == 1, "filter protected")
assert(#InventoryMath.FilterOwned(owned, "Core") == 2, "filter slot")

assert(#InventoryMath.SearchOwned(owned, "alpha", "Any") == 1, "search name")
assert(#InventoryMath.SearchOwned(owned, "", "Mythic") == 1, "search rarity")
assert(#InventoryMath.SearchOwned(owned, "shine", "Any") == 1, "search description")

local byName = InventoryMath.SortOwned(owned, config, "Name")
assert(byName[1].definition.Name == "Alpha", "sort name")
local byLevel = InventoryMath.SortOwned(owned, config, "Level")
assert(byLevel[1].instance.Level == 5, "sort level")
local byRarity = InventoryMath.SortOwned(owned, config, "Rarity")
assert(byRarity[1].definition.Rarity == "Mythic", "sort rarity default")

local sig = InventoryMath.AutoSalvageSignature({
	Enabled = true,
	KeepNew = false,
	Rarities = { Common = true, Rare = true, Epic = false },
}, InventoryMath.AUTO_RARITIES)
assert(sig == "1:0:Common,Rare", "auto salvage signature")

------------------------------------------------------------------------
-- CollectOwned / SocketTargets / RestockClock / OfferStock / Inspect heights
------------------------------------------------------------------------
local collectState = {
	Items = {
		Inventory = {
			u1 = { DefinitionId = "CoreA", Level = 2 },
			bad = { DefinitionId = "Missing" },
			u2 = { DefinitionId = "FrameB", Level = 1 },
		},
		Equipped = { ["Machine:Drill"] = "u1" },
	},
}
local collectConfig = {
	Items = {
		Definitions = {
			{ Id = "CoreA", Name = "Core A", Slot = "Machine", Targets = { "Drill" } },
			{ Id = "FrameB", Name = "Frame B", Slot = "Research" },
		},
	},
	Machines = { { Id = "Drill", Name = "Flux Drill" }, { Id = "Pump", Name = "Pump" } },
	Research = { { Id = "Critical", Name = "Critical" } },
}
local collected = InventoryMath.CollectOwned(collectState, collectConfig)
assert(#collected == 2, "collectOwned drops unknown defs")
local sockets = InventoryMath.SocketTargets(
	{ Machines = { Drill = 2, Pump = 0 }, Research = {} },
	collectConfig,
	{ Slot = "Machine", Targets = { "Drill" } }
)
assert(#sockets == 1 and sockets[1].id == "Machine:Drill", "socket targets filter")
assert(InventoryMath.RestockClock(0) == "READY", "restock ready")
assert(InventoryMath.RestockClock(3661) == "1h 1m", "restock hours")
assert(InventoryMath.RestockClock(90) == "1m", "restock minutes")
assert(InventoryMath.RestockClock(9) == "9s", "restock seconds")
local stock = InventoryMath.OfferStock({ StockMax = 3, Stock = 1, DailyRefresh = true })
assert(stock.stock == 1 and stock.stockMax == 3 and stock.soldOut == false and stock.daily == true, "offer stock")
assert(InventoryMath.OfferStock({ Purchased = true }).soldOut == true, "purchased sold out")
assert(InventoryMath.InspectSocketBlock(true, 2, 1, false) == 20, "inspect equipped block")
assert(InventoryMath.InspectActionsHeight(true) == InventoryMath.ACTION_BTN * 2 + InventoryMath.INSPECT_BTN_GAP, "inspect stack actions")
assert(
	InventoryMath.InspectPanelHeight(20, false)
		== InventoryMath.INSPECT_PAD * 2 + 20 + InventoryMath.INSPECT_BTN_GAP + InventoryMath.ACTION_BTN + InventoryMath.INSPECT_BTN_GAP + InventoryMath.INSPECT_FOOTER_H,
	"inspect panel height"
)

------------------------------------------------------------------------
-- InventoryView wiring residual
------------------------------------------------------------------------
local invSrc = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
assert(string.find(invSrc, "inventoryMath", 1, true), "InventoryView must require inventoryMath")
assert(string.find(invSrc, "InventoryMath.FilterOwned", 1, true), "InventoryView FilterOwned residual")
assert(string.find(invSrc, "InventoryMath.SortOwned", 1, true), "InventoryView SortOwned residual")
assert(string.find(invSrc, "InventoryMath.SearchOwned", 1, true), "InventoryView SearchOwned residual")
assert(string.find(invSrc, "InventoryMath.SalvagePreview", 1, true), "InventoryView SalvagePreview residual")
assert(string.find(invSrc, "InventoryMath.AutoSalvageSignature", 1, true), "InventoryView AutoSalvageSignature residual")
assert(string.find(invSrc, "InventoryMath.CollectOwned", 1, true), "InventoryView CollectOwned residual")
assert(string.find(invSrc, "InventoryMath.SocketTargets", 1, true), "InventoryView SocketTargets residual")
assert(string.find(invSrc, "InventoryMath.RestockClock", 1, true), "InventoryView RestockClock residual")
assert(string.find(invSrc, "InventoryMath.OfferStock", 1, true), "InventoryView OfferStock residual")
assert(string.find(invSrc, "InventoryMath.InspectPanelHeight", 1, true), "InventoryView InspectPanelHeight residual")

local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
local mathSrc = fs.readFile("src/Client/AstralForge/inventoryMath.luau")
for _, body in { mathSrc, invSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] InventoryMath extract guards passed | salvage parity + filter/sort/search + collect/socket/market")
