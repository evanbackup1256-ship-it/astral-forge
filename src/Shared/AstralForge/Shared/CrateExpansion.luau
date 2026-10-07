--!strict
-- Purpose: expanded crate catalog and deterministic owned-skin bonuses.
-- Owner: gameplay. Dependencies: existing catalog definitions. Review: 2026-10-05.

local MAX_SKIN_ESSENCE_PER_CRATE = 100
local SKIN_COST_MULTIPLIER = 3

export type Price = { Currency: string, Amount: number }
export type Skin = {
	Id: string,
	Name: string,
	Tier: string,
	Blurb: string,
	Accent: { number },
	Glow: { number },
	Vfx: string,
	Price: Price?,
	Default: boolean?,
	DailyOnly: boolean?,
	EssencePerOpen: number?,
}
export type BonusSkin = { Id: string, EssencePerOpen: number? }
export type Cosmetics = { CrateSkins: { [string]: boolean }, CrateSkin: string? }
export type Crate = {
	Id: string,
	Name: string,
	Description: string,
	PityAfter: number,
	PityRarity: string,
	Color: Color3,
	Weights: { [string]: number },
	ModelId: string?,
}
export type Offer = {
	Id: string,
	Name: string,
	Description: string,
	Currency: string,
	Price: number,
	Kind: string,
	CrateId: string?,
	Amount: number?,
	StockMax: number?,
	DailyRefresh: boolean?,
	DailyRestock: number?,
	Color: Color3,
}
export type ItemCatalog = { Crates: { Crate }, ShopOffers: { Offer } }
type Definition = {
	Id: string,
	Name: string,
	Description: string,
	Palette: number,
	PityAfter: number,
	PityRarity: string,
	Price: number,
	Essence: number,
}

local Expansion = {}

local definitions: { Definition } = {
	{
		Id = "Salvage",
		Name = "Salvage Locker",
		Description = "Recovered dock fittings.",
		Palette = 1,
		PityAfter = 20,
		PityRarity = "Rare",
		Price = 120,
		Essence = 4,
	},
	{
		Id = "Reactor",
		Name = "Reactor Cask",
		Description = "Heat-shielded reactor fittings.",
		Palette = 2,
		PityAfter = 15,
		PityRarity = "Rare",
		Price = 220,
		Essence = 8,
	},
	{
		Id = "Glacier",
		Name = "Glacier Capsule",
		Description = "Cold-storage precision parts.",
		Palette = 3,
		PityAfter = 12,
		PityRarity = "Epic",
		Price = 360,
		Essence = 12,
	},
	{
		Id = "Solar",
		Name = "Solar Canister",
		Description = "Solar-array control parts.",
		Palette = 4,
		PityAfter = 10,
		PityRarity = "Epic",
		Price = 500,
		Essence = 16,
	},
	{
		Id = "Storm",
		Name = "Storm Cache",
		Description = "Lightning-rated conductors.",
		Palette = 5,
		PityAfter = 9,
		PityRarity = "Epic",
		Price = 700,
		Essence = 20,
	},
	{
		Id = "Lunar",
		Name = "Lunar Archive",
		Description = "Moon-station instruments.",
		Palette = 6,
		PityAfter = 8,
		PityRarity = "Epic",
		Price = 900,
		Essence = 24,
	},
	{
		Id = "DeepSea",
		Name = "Abyss Container",
		Description = "Pressure-rated salvage.",
		Palette = 7,
		PityAfter = 7,
		PityRarity = "Legendary",
		Price = 1200,
		Essence = 28,
	},
	{
		Id = "Prism",
		Name = "Prism Case",
		Description = "Optical research components.",
		Palette = 8,
		PityAfter = 7,
		PityRarity = "Legendary",
		Price = 1500,
		Essence = 32,
	},
	{
		Id = "Obsidian",
		Name = "Obsidian Vault",
		Description = "Armored high-temperature parts.",
		Palette = 9,
		PityAfter = 6,
		PityRarity = "Legendary",
		Price = 1800,
		Essence = 36,
	},
	{
		Id = "Chrono",
		Name = "Chrono Reliquary",
		Description = "Timing and navigation hardware.",
		Palette = 4,
		PityAfter = 6,
		PityRarity = "Legendary",
		Price = 2200,
		Essence = 40,
	},
	{
		Id = "Aurora",
		Name = "Aurora Chamber",
		Description = "Polar-observatory components.",
		Palette = 5,
		PityAfter = 5,
		PityRarity = "Legendary",
		Price = 2600,
		Essence = 44,
	},
	{
		Id = "Titan",
		Name = "Titan Strongbox",
		Description = "Heavy industrial components.",
		Palette = 6,
		PityAfter = 5,
		PityRarity = "Legendary",
		Price = 3200,
		Essence = 48,
	},
}

function Expansion.extendItems(items: ItemCatalog): ()
	local originals = table.clone(items.Crates)
	for index, definition in definitions do
		local base = originals[definition.Palette]
		local crateId = definition.Id .. "Crate"
		table.insert(items.Crates, {
			Id = crateId,
			Name = definition.Name,
			Description = definition.Description,
			PityAfter = definition.PityAfter,
			PityRarity = definition.PityRarity,
			Color = base.Color,
			Weights = table.clone(base.Weights),
			ModelId = definition.Id,
		})
		table.insert(items.ShopOffers, {
			Id = definition.Id .. "Key",
			Name = definition.Name .. " Key",
			Description = "One key. Drop odds and pity are shown on the crate.",
			Currency = "Stardust",
			Price = definition.Price,
			Kind = "Key",
			CrateId = crateId,
			Amount = 1,
			StockMax = 3,
			DailyRefresh = false,
			DailyRestock = 1,
			Color = base.Color,
		})
	end
end

function Expansion.extendSkins(originals: { Skin }): { Skin }
	local skins: { Skin } = {}
	for index, original in originals do
		local skin = table.clone(original)
		skin.EssencePerOpen = if skin.Default then 0 else index * 2
		if skin.EssencePerOpen > 0 then
			skin.Blurb ..= string.format(" Grants %d essence per opened crate.", skin.EssencePerOpen)
		end
		table.insert(skins, skin)
	end
	for _, definition in definitions do
		local base = originals[(definition.Palette - 1) % #originals + 1]
		table.insert(skins, {
			Id = definition.Id,
			Name = definition.Name,
			Tier = definition.PityRarity,
			Blurb = string.format("%s Grants %d essence per opened crate.", definition.Description, definition.Essence),
			Accent = table.clone(base.Accent),
			Glow = table.clone(base.Glow),
			Vfx = base.Vfx,
			Price = { Currency = "Stardust", Amount = definition.Price * SKIN_COST_MULTIPLIER },
			EssencePerOpen = definition.Essence,
		})
	end
	return table.freeze(skins)
end

function Expansion.openBonus(cosmetics: Cosmetics?, skin: BonusSkin?, count: number): number
	if type(cosmetics) ~= "table" or type(skin) ~= "table" then
		return 0
	end
	if type(cosmetics.CrateSkins) ~= "table" or cosmetics.CrateSkins[skin.Id] ~= true then
		return 0
	end
	local amount = skin.EssencePerOpen
	if type(amount) ~= "number" or amount ~= amount or math.abs(amount) == math.huge then
		return 0
	end
	if count ~= 1 and count ~= 5 then
		return 0
	end
	return math.floor(math.clamp(amount, 0, MAX_SKIN_ESSENCE_PER_CRATE)) * count
end

return table.freeze(Expansion)
