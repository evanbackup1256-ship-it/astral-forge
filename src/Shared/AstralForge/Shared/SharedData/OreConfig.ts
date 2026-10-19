type Rgb = [number, number, number];

interface OreType {
	Id: string;
	Name: string;
	Region: string;
	Color: Rgb;
	Glow: Rgb;
	YieldMin: number;
	YieldMax: number;
}

interface OreUpgrade {
	Id: string;
	Name: string;
	Description: string;
	Effect: string;
	PerLevel: number;
	MaxLevel: number;
	Cost: Record<string, number>;
	Scale: number;
}

const Types: OreType[] = [
	{ Id: "Emberite", Name: "Emberite", Region: "Emberreach", Color: [255, 128, 64], Glow: [255, 196, 120], YieldMin: 3, YieldMax: 5 },
	{ Id: "Voidglass", Name: "Voidglass", Region: "Hollows", Color: [150, 104, 255], Glow: [206, 172, 255], YieldMin: 2, YieldMax: 4 },
	{ Id: "Starsteel", Name: "Starsteel", Region: "Spire", Color: [140, 220, 255], Glow: [226, 248, 255], YieldMin: 1, YieldMax: 2 },
];

const Upgrades: OreUpgrade[] = [
	{
		Id: "TemperedCores",
		Name: "Tempered Cores",
		Description: "Machines produce 3% more per level.",
		Effect: "Production",
		PerLevel: 0.03,
		MaxLevel: 30,
		Cost: { Emberite: 6 },
		Scale: 1.24,
	},
	{
		Id: "DeepVault",
		Name: "Deep Vault",
		Description: "The vault holds 4% more per level.",
		Effect: "Capacity",
		PerLevel: 0.04,
		MaxLevel: 25,
		Cost: { Voidglass: 5 },
		Scale: 1.26,
	},
	{
		Id: "ResonantStrike",
		Name: "Resonant Strike",
		Description: "Overcharge taps hit 5% harder per level.",
		Effect: "Tap",
		PerLevel: 0.05,
		MaxLevel: 25,
		Cost: { Emberite: 3, Voidglass: 3 },
		Scale: 1.27,
	},
	{
		Id: "StarsteelEdge",
		Name: "Starsteel Edge",
		Description: "Strikes on the Rift Warden land 8% harder per level.",
		Effect: "BossDamage",
		PerLevel: 0.08,
		MaxLevel: 15,
		Cost: { Starsteel: 3 },
		Scale: 1.32,
	},
	{
		Id: "ProspectorsEye",
		Name: "Prospector's Eye",
		Description: "Every outcrop gives 6% more ore per level.",
		Effect: "OreYield",
		PerLevel: 0.06,
		MaxLevel: 10,
		Cost: { Starsteel: 2, Emberite: 8 },
		Scale: 1.4,
	},
];

export = table.freeze({
	Ore: {
		RegrowSeconds: 90,
		HoldSeconds: 1.1,
		PromptDistance: 12,
		ServerReach: 18,
		Types,
		Upgrades,
	},
});
