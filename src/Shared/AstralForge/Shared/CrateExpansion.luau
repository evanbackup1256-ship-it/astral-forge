--!strict
-- Purpose: expanded crate catalog and deterministic owned-skin bonuses.
-- Owner: gameplay. Dependencies: existing catalog definitions. Review: 2026-10-05.

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
	PityStep: number?,
	SalvageBonus: number?,
	Family: string?,
}
export type BonusSkin = { Id: string, EssencePerOpen: number?, PityStep: number?, SalvageBonus: number? }
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
	Color: { number }?,
	Accent: { number }?,
	Glow: { number }?,
	Vfx: string?,
	Family: string?,
	PityStep: number?,
	SalvageBonus: number?,
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
	{ Id = "Cinder", Name = "Cinder Coffer", Description = "Soot-black plating over banked coals.", Palette = 1, PityAfter = 18, PityRarity = "Rare", Price = 160, Essence = 6, Color = { 236, 110, 64 }, Accent = { 236, 110, 64 }, Glow = { 255, 196, 120 }, Vfx = "embers", Family = "Furnace", SalvageBonus = 0.1 },
	{ Id = "Verdant", Name = "Verdant Terrarium", Description = "A sealed greenhouse grown from the hull.", Palette = 2, PityAfter = 14, PityRarity = "Rare", Price = 260, Essence = 9, Color = { 96, 214, 120 }, Accent = { 96, 214, 120 }, Glow = { 200, 255, 180 }, Vfx = "shards", Family = "Garden", PityStep = 2 },
	{ Id = "Tidal", Name = "Tidal Ballast", Description = "Ballast tank still sloshing with sea glass.", Palette = 7, PityAfter = 11, PityRarity = "Epic", Price = 420, Essence = 13, Color = { 64, 178, 220 }, Accent = { 64, 178, 220 }, Glow = { 170, 240, 255 }, Vfx = "frost", Family = "Pressure", SalvageBonus = 0.15 },
	{ Id = "Runic", Name = "Runic Lockbox", Description = "Old script carved into every hinge.", Palette = 3, PityAfter = 10, PityRarity = "Epic", Price = 600, Essence = 18, Color = { 120, 160, 255 }, Accent = { 120, 160, 255 }, Glow = { 210, 225, 255 }, Vfx = "frost", Family = "Glyph", PityStep = 2 },
	{ Id = "Comet", Name = "Comet Pod", Description = "Ice-scored drop pod pulled from a tail.", Palette = 5, PityAfter = 9, PityRarity = "Epic", Price = 780, Essence = 22, Color = { 170, 220, 255 }, Accent = { 170, 220, 255 }, Glow = { 255, 255, 255 }, Vfx = "stars", Family = "Pod", SalvageBonus = 0.2 },
	{ Id = "Mirage", Name = "Mirage Casket", Description = "Hard to look at straight on.", Palette = 8, PityAfter = 8, PityRarity = "Epic", Price = 980, Essence = 26, Color = { 255, 170, 220 }, Accent = { 255, 170, 220 }, Glow = { 255, 236, 250 }, Vfx = "prism", Family = "Lens", PityStep = 2 },
	{ Id = "Quasar", Name = "Quasar Engine", Description = "A sealed jet core, spinning slowly.", Palette = 6, PityAfter = 7, PityRarity = "Legendary", Price = 1350, Essence = 30, Color = { 150, 110, 255 }, Accent = { 150, 110, 255 }, Glow = { 230, 200, 255 }, Vfx = "nebula", Family = "Core", SalvageBonus = 0.2 },
	{ Id = "Bastion", Name = "Bastion Magazine", Description = "Blast-rated ordnance locker.", Palette = 9, PityAfter = 6, PityRarity = "Legendary", Price = 1650, Essence = 34, Color = { 190, 196, 210 }, Accent = { 190, 196, 210 }, Glow = { 255, 220, 160 }, Vfx = "embers", Family = "Armory", PityStep = 2 },
	{ Id = "Eclipse", Name = "Eclipse Reliquary", Description = "A dark ring with a burning rim.", Palette = 6, PityAfter = 6, PityRarity = "Legendary", Price = 2000, Essence = 38, Color = { 255, 150, 70 }, Accent = { 255, 150, 70 }, Glow = { 255, 220, 150 }, Vfx = "void", Family = "Halo", SalvageBonus = 0.25 },
	{ Id = "Nova", Name = "Nova Canister", Description = "Bottled shockwave from a dying star.", Palette = 9, PityAfter = 5, PityRarity = "Legendary", Price = 2800, Essence = 46, Color = { 255, 224, 120 }, Accent = { 255, 224, 120 }, Glow = { 255, 255, 220 }, Vfx = "stars", Family = "Core", PityStep = 2, SalvageBonus = 0.1 },
	{ Id = "Halo", Name = "Halo Sanctum", Description = "Rings within rings. The last forge key.", Palette = 6, PityAfter = 4, PityRarity = "Mythic", Price = 4000, Essence = 56, Color = { 255, 246, 214 }, Accent = { 255, 246, 214 }, Glow = { 190, 240, 255 }, Vfx = "prism", Family = "Halo", PityStep = 2, SalvageBonus = 0.25 },
}

local ORIGINAL_PERKS: { [string]: { PityStep: number?, SalvageBonus: number?, Family: string } } = {
	Classic = { Family = "Armory" },
	Crystal = { SalvageBonus = 0.1, Family = "Lens" },
	Frost = { PityStep = 2, Family = "Glyph" },
	Molten = { SalvageBonus = 0.2, Family = "Furnace" },
	Nebula = { PityStep = 2, Family = "Core" },
	Void = { PityStep = 2, SalvageBonus = 0.1, Family = "Halo" },
	Gilded = { SalvageBonus = 0.3, Family = "Armory" },
	Celestial = { PityStep = 2, SalvageBonus = 0.25, Family = "Halo" },
}

local function perkText(skin: Skin): string
	local parts = {}
	if type(skin.EssencePerOpen) == "number" and skin.EssencePerOpen > 0 then
		table.insert(parts, string.format("+%d essence per open", skin.EssencePerOpen))
	end
	if skin.PityStep == 2 then
		table.insert(parts, "pity charges twice as fast")
	end
	if type(skin.SalvageBonus) == "number" and skin.SalvageBonus > 0 then
		table.insert(parts, string.format("+%d%% auto-salvage essence", math.round(skin.SalvageBonus * 100)))
	end
	if #parts == 0 then
		return ""
	end
	return " Equipped: " .. table.concat(parts, ", ") .. "."
end

local function rgbColor(value: { number }?, fallback: Color3): Color3
	if type(value) ~= "table" then
		return fallback
	end
	return Color3.fromRGB(value[1] or 255, value[2] or 255, value[3] or 255)
end

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
			Color = rgbColor(definition.Color, base.Color),
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
			Color = rgbColor(definition.Color, base.Color),
		})
	end
end

function Expansion.extendSkins(originals: { Skin }): { Skin }
	local skins: { Skin } = {}
	for index, original in originals do
		local skin = table.clone(original)
		skin.EssencePerOpen = if skin.Default then 0 else index * 2
		local perk = ORIGINAL_PERKS[skin.Id]
		if perk then
			skin.PityStep = perk.PityStep
			skin.SalvageBonus = perk.SalvageBonus
			skin.Family = perk.Family
		end
		skin.Blurb ..= perkText(skin)
		table.insert(skins, skin)
	end
	for _, definition in definitions do
		local base = originals[(definition.Palette - 1) % #originals + 1]
		local skin: Skin = {
			Id = definition.Id,
			Name = definition.Name,
			Tier = definition.PityRarity,
			Blurb = definition.Description,
			Accent = table.clone(definition.Accent or base.Accent),
			Glow = table.clone(definition.Glow or base.Glow),
			Vfx = definition.Vfx or base.Vfx,
			Price = { Currency = "Stardust", Amount = definition.Price * 3 },
			EssencePerOpen = definition.Essence,
			PityStep = definition.PityStep,
			SalvageBonus = definition.SalvageBonus,
			Family = definition.Family,
		}
		skin.Blurb ..= perkText(skin)
		table.insert(skins, skin)
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
	return math.floor(math.clamp(amount, 0, 100)) * count
end

local function equipped(cosmetics: Cosmetics?, skin: BonusSkin?): boolean
	return type(cosmetics) == "table"
		and type(skin) == "table"
		and type(cosmetics.CrateSkins) == "table"
		and cosmetics.CrateSkins[skin.Id] == true
end

function Expansion.pityStep(cosmetics: Cosmetics?, skin: BonusSkin?): number
	if not equipped(cosmetics, skin) then
		return 1
	end
	local step = (skin :: BonusSkin).PityStep
	return if step == 2 then 2 else 1
end

function Expansion.salvageEssence(cosmetics: Cosmetics?, skin: BonusSkin?, base: number): number
	if type(base) ~= "number" or base ~= base or base <= 0 or base == math.huge then
		return 0
	end
	if not equipped(cosmetics, skin) then
		return math.floor(base)
	end
	local bonus = (skin :: BonusSkin).SalvageBonus
	if type(bonus) ~= "number" or bonus ~= bonus then
		return math.floor(base)
	end
	return math.floor(base * (1 + math.clamp(bonus, 0, 0.5)))
end

return table.freeze(Expansion)
