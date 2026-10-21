interface RewardTable {
	Cash?: number;
	CashMinutes?: number;
	Stardust?: number;
	Cores?: number;
	Boost?: string;
	Signals?: number;
	CommandXP?: number;
	StreakShield?: number;
	Keys?: Record<string, number>;
}

interface DevProductDef {
	Key: string;
	ProductId: number;
	Name: string;
	Description: string;
	Category: string;
	Icon: string;
	Accent: [number, number, number];
	PriceLabel: string;
	StudioPrice: number;
	Reward: RewardTable;
}

interface GamePassDef {
	Key: string;
	PassId: number;
	Name: string;
	Description: string;
	Category: string;
	Icon: string;
	Accent: [number, number, number];
	PriceLabel: string;
	StudioPrice: number;
	ProductionBonus?: number;
	CapacityBonus?: number;
}

const DevProducts: DevProductDef[] = [
	{
		Key: "StardustParcel",
		ProductId: 3716811152,
		Name: "Stardust Pack",
		Description: "80 Stardust for grid upgrades.",
		Category: "Packs",
		Icon: "Dust.16",
		Accent: [93, 247, 180],
		PriceLabel: "R$",
		StudioPrice: 49,
		Reward: { Stardust: 80 },
	},
	{
		Key: "FluxCrate",
		ProductId: 3716811274,
		Name: "Flux Drop",
		Description: "120k Flux you can spend right now.",
		Category: "Packs",
		Icon: "Flux.26",
		Accent: [72, 190, 255],
		PriceLabel: "R$",
		StudioPrice: 99,
		Reward: { Cash: 120_000 },
	},
	{
		Key: "RelayBooster",
		ProductId: 3716811317,
		Name: "Overdrive Charge",
		Description: "One Overdrive boost for the Rewards tab.",
		Category: "Boosts",
		Icon: "Forge.32",
		Accent: [255, 83, 111],
		PriceLabel: "R$",
		StudioPrice: 75,
		Reward: { Boost: "Overdrive" },
	},
	{
		Key: "CoreCluster",
		ProductId: 3716811360,
		Name: "Core Bundle",
		Description: "3 permanent cores. No rebirth needed.",
		Category: "Packs",
		Icon: "Core.11",
		Accent: [161, 126, 255],
		PriceLabel: "R$",
		StudioPrice: 199,
		Reward: { Cores: 3 },
	},
];

const GamePasses: GamePassDef[] = [
	{
		Key: "VIP",
		PassId: 2005587679,
		Name: "VIP",
		Description: "+12% production forever.",
		Category: "Passes",
		Icon: "StarGrid.8",
		Accent: [255, 191, 78],
		PriceLabel: "R$",
		StudioPrice: 399,
		ProductionBonus: 0.12,
	},
	{
		Key: "DoubleProduction",
		PassId: 2006769725,
		Name: "Overclock",
		Description: "+25% line output forever.",
		Category: "Passes",
		Icon: "Research.5",
		Accent: [102, 177, 255],
		PriceLabel: "R$",
		StudioPrice: 499,
		ProductionBonus: 0.25,
	},
	{
		Key: "DoubleCapacity",
		PassId: 2005557744,
		Name: "Bigger Vault",
		Description: "+35% vault size forever.",
		Category: "Passes",
		Icon: "Vault.12",
		Accent: [72, 190, 255],
		PriceLabel: "R$",
		StudioPrice: 349,
		CapacityBonus: 0.35,
	},
	{
		Key: "AutoSalvage",
		PassId: 2006703685,
		Name: "Relic Recycler",
		Description:
			"Automatically salvage selected crate rarities. First discoveries stay protected by default.",
		Category: "Passes",
		Icon: "Inventory.8",
		Accent: [255, 88, 156],
		PriceLabel: "R$",
		StudioPrice: 299,
	},
	{
		// PassId 0 until the pass exists on the Creator Dashboard; the Shop shows it as unavailable
		// in live servers and Studio grants it locally.
		Key: "SeasonPass",
		PassId: 0,
		Name: "Season Pass",
		Description: "Adds a second reward to every Rank Track tier this season and after.",
		Category: "Passes",
		Icon: "StarGrid.8",
		Accent: [255, 191, 78],
		PriceLabel: "R$",
		StudioPrice: 449,
	},
];

function FindDevProductByProductId(productId: number): DevProductDef | undefined {
	if (productId <= 0) {
		return undefined;
	}
	return DevProducts.find((entry) => entry.ProductId === productId);
}

function FindDevProductByKey(key: string): DevProductDef | undefined {
	return DevProducts.find((entry) => entry.Key === key);
}

function FindPassByPassId(passId: number): GamePassDef | undefined {
	if (passId <= 0) {
		return undefined;
	}
	return GamePasses.find((entry) => entry.PassId === passId);
}

function FindPassByKey(key: string): GamePassDef | undefined {
	return GamePasses.find((entry) => entry.Key === key);
}

function PassBonuses(owned: Record<string, boolean>): LuaTuple<[number, number]> {
	let production = 0;
	let capacity = 0;
	for (const entry of GamePasses) {
		if (owned[entry.Key] === true) {
			production += entry.ProductionBonus ?? 0;
			capacity += entry.CapacityBonus ?? 0;
		}
	}
	return $tuple(production, capacity);
}

export = table.freeze({
	DevProducts,
	GamePasses,
	FindDevProductByProductId,
	FindDevProductByKey,
	FindPassByPassId,
	FindPassByKey,
	PassBonuses,
});
