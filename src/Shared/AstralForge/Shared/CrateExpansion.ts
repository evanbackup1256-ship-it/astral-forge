// Purpose: expanded crate catalog and deterministic owned-skin bonuses.
// Owner: gameplay. Dependencies: existing catalog definitions. Review: 2026-10-05.

interface Price {
	Currency: string;
	Amount: number;
}

interface Skin {
	Id: string;
	Name: string;
	Tier: string;
	Blurb: string;
	Accent: [number, number, number];
	Glow: [number, number, number];
	Vfx: string;
	Price?: Price;
	Default?: boolean;
	DailyOnly?: boolean;
	EssencePerOpen?: number;
	PityStep?: number;
	SalvageBonus?: number;
	Family?: string;
}

interface BonusSkin {
	Id: string;
	EssencePerOpen?: number;
	PityStep?: number;
	SalvageBonus?: number;
}

interface Cosmetics {
	CrateSkins: Record<string, boolean>;
	CrateSkin?: string;
}

interface Crate {
	Id: string;
	Name: string;
	Description: string;
	PityAfter: number;
	PityRarity: string;
	Color: Color3;
	Weights: Record<string, number>;
	ModelId?: string;
}

interface Offer {
	Id: string;
	Name: string;
	Description: string;
	Currency: string;
	Price: number;
	Kind: string;
	CrateId?: string;
	Amount?: number;
	StockMax?: number;
	DailyRefresh?: boolean;
	DailyRestock?: number;
	Color: Color3;
}

interface ItemCatalog {
	Crates: Crate[];
	ShopOffers: Offer[];
}

interface Definition {
	Id: string;
	Name: string;
	Description: string;
	Palette: number;
	PityAfter: number;
	PityRarity: string;
	Price: number;
	Essence: number;
	Color?: [number, number, number];
	Accent?: [number, number, number];
	Glow?: [number, number, number];
	Vfx?: string;
	Family?: string;
	PityStep?: number;
	SalvageBonus?: number;
}

const definitions: Definition[] = [
	{
		Id: "Salvage",
		Name: "Salvage Locker",
		Description: "Recovered dock fittings.",
		Palette: 1,
		PityAfter: 20,
		PityRarity: "Rare",
		Price: 120,
		Essence: 4,
	},
	{
		Id: "Reactor",
		Name: "Reactor Cask",
		Description: "Heat-shielded reactor fittings.",
		Palette: 2,
		PityAfter: 15,
		PityRarity: "Rare",
		Price: 220,
		Essence: 8,
	},
	{
		Id: "Glacier",
		Name: "Glacier Capsule",
		Description: "Cold-storage precision parts.",
		Palette: 3,
		PityAfter: 12,
		PityRarity: "Epic",
		Price: 360,
		Essence: 12,
	},
	{
		Id: "Solar",
		Name: "Solar Canister",
		Description: "Solar-array control parts.",
		Palette: 4,
		PityAfter: 10,
		PityRarity: "Epic",
		Price: 500,
		Essence: 16,
	},
	{
		Id: "Storm",
		Name: "Storm Cache",
		Description: "Lightning-rated conductors.",
		Palette: 5,
		PityAfter: 9,
		PityRarity: "Epic",
		Price: 700,
		Essence: 20,
	},
	{
		Id: "Lunar",
		Name: "Lunar Archive",
		Description: "Moon-station instruments.",
		Palette: 6,
		PityAfter: 8,
		PityRarity: "Epic",
		Price: 900,
		Essence: 24,
	},
	{
		Id: "DeepSea",
		Name: "Abyss Container",
		Description: "Pressure-rated salvage.",
		Palette: 7,
		PityAfter: 7,
		PityRarity: "Legendary",
		Price: 1200,
		Essence: 28,
	},
	{
		Id: "Prism",
		Name: "Prism Case",
		Description: "Optical research components.",
		Palette: 8,
		PityAfter: 7,
		PityRarity: "Legendary",
		Price: 1500,
		Essence: 32,
	},
	{
		Id: "Obsidian",
		Name: "Obsidian Vault",
		Description: "Armored high-temperature parts.",
		Palette: 9,
		PityAfter: 6,
		PityRarity: "Legendary",
		Price: 1800,
		Essence: 36,
	},
	{
		Id: "Chrono",
		Name: "Chrono Reliquary",
		Description: "Timing and navigation hardware.",
		Palette: 4,
		PityAfter: 6,
		PityRarity: "Legendary",
		Price: 2200,
		Essence: 40,
	},
	{
		Id: "Aurora",
		Name: "Aurora Chamber",
		Description: "Polar-observatory components.",
		Palette: 5,
		PityAfter: 5,
		PityRarity: "Legendary",
		Price: 2600,
		Essence: 44,
	},
	{
		Id: "Titan",
		Name: "Titan Strongbox",
		Description: "Heavy industrial components.",
		Palette: 6,
		PityAfter: 5,
		PityRarity: "Legendary",
		Price: 3200,
		Essence: 48,
	},
	{
		Id: "Cinder",
		Name: "Cinder Coffer",
		Description: "Soot-black plating over banked coals.",
		Palette: 1,
		PityAfter: 18,
		PityRarity: "Rare",
		Price: 160,
		Essence: 6,
		Color: [236, 110, 64],
		Accent: [236, 110, 64],
		Glow: [255, 196, 120],
		Vfx: "embers",
		Family: "Furnace",
		SalvageBonus: 0.1,
	},
	{
		Id: "Verdant",
		Name: "Verdant Terrarium",
		Description: "A sealed greenhouse grown from the hull.",
		Palette: 2,
		PityAfter: 14,
		PityRarity: "Rare",
		Price: 260,
		Essence: 9,
		Color: [96, 214, 120],
		Accent: [96, 214, 120],
		Glow: [200, 255, 180],
		Vfx: "shards",
		Family: "Garden",
		PityStep: 2,
	},
	{
		Id: "Tidal",
		Name: "Tidal Ballast",
		Description: "Ballast tank still sloshing with sea glass.",
		Palette: 7,
		PityAfter: 11,
		PityRarity: "Epic",
		Price: 420,
		Essence: 13,
		Color: [64, 178, 220],
		Accent: [64, 178, 220],
		Glow: [170, 240, 255],
		Vfx: "frost",
		Family: "Pressure",
		SalvageBonus: 0.15,
	},
	{
		Id: "Runic",
		Name: "Runic Lockbox",
		Description: "Old script carved into every hinge.",
		Palette: 3,
		PityAfter: 10,
		PityRarity: "Epic",
		Price: 600,
		Essence: 18,
		Color: [120, 160, 255],
		Accent: [120, 160, 255],
		Glow: [210, 225, 255],
		Vfx: "frost",
		Family: "Glyph",
		PityStep: 2,
	},
	{
		Id: "Comet",
		Name: "Comet Pod",
		Description: "Ice-scored drop pod pulled from a tail.",
		Palette: 5,
		PityAfter: 9,
		PityRarity: "Epic",
		Price: 780,
		Essence: 22,
		Color: [170, 220, 255],
		Accent: [170, 220, 255],
		Glow: [255, 255, 255],
		Vfx: "stars",
		Family: "Pod",
		SalvageBonus: 0.2,
	},
	{
		Id: "Mirage",
		Name: "Mirage Casket",
		Description: "Hard to look at straight on.",
		Palette: 8,
		PityAfter: 8,
		PityRarity: "Epic",
		Price: 980,
		Essence: 26,
		Color: [255, 170, 220],
		Accent: [255, 170, 220],
		Glow: [255, 236, 250],
		Vfx: "prism",
		Family: "Lens",
		PityStep: 2,
	},
	{
		Id: "Quasar",
		Name: "Quasar Engine",
		Description: "A sealed jet core, spinning slowly.",
		Palette: 6,
		PityAfter: 7,
		PityRarity: "Legendary",
		Price: 1350,
		Essence: 30,
		Color: [150, 110, 255],
		Accent: [150, 110, 255],
		Glow: [230, 200, 255],
		Vfx: "nebula",
		Family: "Core",
		SalvageBonus: 0.2,
	},
	{
		Id: "Bastion",
		Name: "Bastion Magazine",
		Description: "Blast-rated ordnance locker.",
		Palette: 9,
		PityAfter: 6,
		PityRarity: "Legendary",
		Price: 1650,
		Essence: 34,
		Color: [190, 196, 210],
		Accent: [190, 196, 210],
		Glow: [255, 220, 160],
		Vfx: "embers",
		Family: "Armory",
		PityStep: 2,
	},
	{
		Id: "Eclipse",
		Name: "Eclipse Reliquary",
		Description: "A dark ring with a burning rim.",
		Palette: 6,
		PityAfter: 6,
		PityRarity: "Legendary",
		Price: 2000,
		Essence: 38,
		Color: [255, 150, 70],
		Accent: [255, 150, 70],
		Glow: [255, 220, 150],
		Vfx: "void",
		Family: "Halo",
		SalvageBonus: 0.25,
	},
	{
		Id: "Nova",
		Name: "Nova Canister",
		Description: "Bottled shockwave from a dying star.",
		Palette: 9,
		PityAfter: 5,
		PityRarity: "Legendary",
		Price: 2800,
		Essence: 46,
		Color: [255, 224, 120],
		Accent: [255, 224, 120],
		Glow: [255, 255, 220],
		Vfx: "stars",
		Family: "Core",
		PityStep: 2,
		SalvageBonus: 0.1,
	},
	{
		Id: "Halo",
		Name: "Halo Sanctum",
		Description: "Rings within rings. The last forge key.",
		Palette: 6,
		PityAfter: 4,
		PityRarity: "Mythic",
		Price: 4000,
		Essence: 56,
		Color: [255, 246, 214],
		Accent: [255, 246, 214],
		Glow: [190, 240, 255],
		Vfx: "prism",
		Family: "Halo",
		PityStep: 2,
		SalvageBonus: 0.25,
	},
];

const ORIGINAL_PERKS: Record<string, { PityStep?: number; SalvageBonus?: number; Family: string }> = table.freeze({
	Classic: table.freeze({ Family: "Armory" }),
	Crystal: table.freeze({ SalvageBonus: 0.1, Family: "Lens" }),
	Frost: table.freeze({ PityStep: 2, Family: "Glyph" }),
	Molten: table.freeze({ SalvageBonus: 0.2, Family: "Furnace" }),
	Nebula: table.freeze({ PityStep: 2, Family: "Core" }),
	Void: table.freeze({ PityStep: 2, SalvageBonus: 0.1, Family: "Halo" }),
	Gilded: table.freeze({ SalvageBonus: 0.3, Family: "Armory" }),
	Celestial: table.freeze({ PityStep: 2, SalvageBonus: 0.25, Family: "Halo" }),
});

function perkText(skin: Skin): string {
	const parts: string[] = [];
	if (typeIs(skin.EssencePerOpen, "number") && skin.EssencePerOpen > 0) {
		parts.push(`+${skin.EssencePerOpen} essence per open`);
	}
	if (skin.PityStep === 2) {
		parts.push("pity charges twice as fast");
	}
	if (typeIs(skin.SalvageBonus, "number") && skin.SalvageBonus > 0) {
		parts.push(`+${math.round(skin.SalvageBonus * 100)}% auto-salvage essence`);
	}
	if (parts.size() === 0) {
		return "";
	}
	return " Equipped: " + parts.join(", ") + ".";
}

function rgbColor(value: unknown, fallback: Color3): Color3 {
	if (!typeIs(value, "table")) {
		return fallback;
	}
	const rgb = value as [number, number, number];
	return Color3.fromRGB(rgb[0] ?? 255, rgb[1] ?? 255, rgb[2] ?? 255);
}

function extendItems(items: ItemCatalog): void {
	const originals = table.clone(items.Crates);
	for (const definition of definitions) {
		const base = originals[definition.Palette - 1];
		const crateId = definition.Id + "Crate";
		items.Crates.push({
			Id: crateId,
			Name: definition.Name,
			Description: definition.Description,
			PityAfter: definition.PityAfter,
			PityRarity: definition.PityRarity,
			Color: rgbColor(definition.Color, base.Color),
			Weights: table.clone(base.Weights),
			ModelId: definition.Id,
		});
		items.ShopOffers.push({
			Id: definition.Id + "Key",
			Name: definition.Name + " Key",
			Description: "One key. Drop odds and pity are shown on the crate.",
			Currency: "Stardust",
			Price: definition.Price,
			Kind: "Key",
			CrateId: crateId,
			Amount: 1,
			StockMax: 3,
			DailyRefresh: false,
			DailyRestock: 1,
			Color: rgbColor(definition.Color, base.Color),
		});
	}
}

function extendSkins(originals: Skin[]): Skin[] {
	const skins: Skin[] = [];
	for (let index = 0; index < originals.size(); index++) {
		const original = originals[index];
		const skin = table.clone(original);
		skin.EssencePerOpen = skin.Default ? 0 : (index + 1) * 2;
		const perk = ORIGINAL_PERKS[skin.Id];
		if (perk) {
			skin.PityStep = perk.PityStep;
			skin.SalvageBonus = perk.SalvageBonus;
			skin.Family = perk.Family;
		}
		skin.Blurb += perkText(skin);
		skins.push(skin);
	}
	for (const definition of definitions) {
		const base = originals[(definition.Palette - 1) % originals.size()];
		const skin: Skin = {
			Id: definition.Id,
			Name: definition.Name,
			Tier: definition.PityRarity,
			Blurb: definition.Description,
			Accent: table.clone(definition.Accent ?? base.Accent) as [number, number, number],
			Glow: table.clone(definition.Glow ?? base.Glow) as [number, number, number],
			Vfx: definition.Vfx ?? base.Vfx,
			Price: { Currency: "Stardust", Amount: definition.Price * 3 },
			EssencePerOpen: definition.Essence,
			PityStep: definition.PityStep,
			SalvageBonus: definition.SalvageBonus,
			Family: definition.Family,
		};
		skin.Blurb += perkText(skin);
		skins.push(skin);
	}
	return table.freeze(skins) as unknown as Skin[];
}

function openBonus(cosmetics: unknown, skin: unknown, count: number): number {
	if (!typeIs(cosmetics, "table") || !typeIs(skin, "table")) {
		return 0;
	}
	const c = cosmetics as Cosmetics;
	const s = skin as BonusSkin;
	if (!typeIs(c.CrateSkins, "table") || c.CrateSkins[s.Id] !== true) {
		return 0;
	}
	const amount = s.EssencePerOpen;
	if (!typeIs(amount, "number") || amount !== amount || math.abs(amount) === math.huge) {
		return 0;
	}
	if (count !== 1 && count !== 5) {
		return 0;
	}
	return math.floor(math.clamp(amount, 0, 100)) * count;
}

function equipped(cosmetics: unknown, skin: unknown): boolean {
	return (
		typeIs(cosmetics, "table") &&
		typeIs(skin, "table") &&
		typeIs((cosmetics as Cosmetics).CrateSkins, "table") &&
		(cosmetics as Cosmetics).CrateSkins[(skin as BonusSkin).Id] === true
	);
}

function pityStep(cosmetics: unknown, skin: unknown): number {
	if (!equipped(cosmetics, skin)) {
		return 1;
	}
	const step = (skin as BonusSkin).PityStep;
	return step === 2 ? 2 : 1;
}

function salvageEssence(cosmetics: unknown, skin: unknown, base: number): number {
	if (!typeIs(base, "number") || base !== base || base <= 0 || base === math.huge) {
		return 0;
	}
	if (!equipped(cosmetics, skin)) {
		return math.floor(base);
	}
	const bonus = (skin as BonusSkin).SalvageBonus;
	if (!typeIs(bonus, "number") || bonus !== bonus) {
		return math.floor(base);
	}
	return math.floor(base * (1 + math.clamp(bonus, 0, 0.5)));
}

const Expansion = {
	extendItems,
	extendSkins,
	openBonus,
	pityStep,
	salvageEssence,
};

export = table.freeze(Expansion);
