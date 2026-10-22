// Purpose: the data behind every world that isn't hand-written in GameConfig.Zones, as plain tables.
// Two kinds of world come from here:
//   - generated: the rows GameConfig fills in after the last authored world, up to GENERATED_LAST_ID.
//     Their costs are then rewritten by WorldCurve, so only names, flavour and layout really matter.
//   - resolved: any id past the generated list up to MaxZone, built on demand by ResolveZone.
// Pure data, no Roblox APIs: GameConfig requires it raw and the config generator can load it under Lune.
// Owner: gameplay. Dependencies: none.

export interface WorldNaming {
	// a world's name is Prefixes[tier % n] + " " + Nouns[tier / n]
	Prefixes: string[];
	Nouns: string[];
	// three feature lines per world, cycled by tier
	Features: string[][];
	Layouts: string[];
}

export const GENERATED_LAST_ID = 125;

export const GENERATED: WorldNaming = {
	Prefixes: ["Ember", "Aether", "Verdant", "Obsidian", "Lumen", "Tidal", "Gilded", "Frost", "Echo", "Violet", "Titan", "Mirage"],
	Nouns: ["Basin", "Crown", "Concourse", "Garden", "Array", "Reach", "Spire", "Archive", "Tessellation", "Citadel"],
	Features: [
		["Fast lanes", "Safe vaults", "Crew tips"],
		["Bright freight", "Bonus contracts", "Low waste"],
		["Heat exchanges", "Core fabs", "Pressure clocks"],
		["Short routes", "Stable research", "Weird geometry"],
		["Deep collectors", "Long vaults", "Endless synth"],
	],
	Layouts: ["Dock", "Crystal", "Foundry", "Rift", "Horizon"],
};

// placeholder stats for generated rows; WorldCurve.apply replaces Cost, CoreCost, Multiplier and RequiredRebirths
export const GENERATED_STATS = {
	CostLnBase: math.log(25_000_000_000),
	CostLnPerTier: 0.095,
	CostLnCap: 700,
	CoreCostBase: 20,
	CoreCostPerTier: 1.65,
	MultiplierBase: 12,
	MultiplierPerTier: 0.24,
	RebirthsBase: 20,
	RebirthsPerTier: 0.8,
};

export interface ResolvedNaming {
	Names: string[];
	Features: string[][];
	Layouts: string[];
}

// prettier-ignore
export const RESOLVED: ResolvedNaming = {
	Names: [
		"Ashen Reach", "Ion Shelf", "Mirror Trench", "Violet Harbor", "Drift Spire",
		"Hollow Crown", "Nadir Reef", "Aurora Kiln", "Static Orchard", "Null Causeway",
		"Ember Causeway", "Signal Bazaar", "Folded Pier", "Quiet Anvil", "Prism Quay",
	],
	Features: [
		["Bigger multiplier", "Rebirth gate", "Familiar machines"],
		["Familiar machines", "Steeper core costs", "Bigger multiplier"],
		["Bigger multiplier", "Rebirth gate", "Long offline time"],
		["Wide rails", "Rebirth gate", "Safe offline vault"],
		["Bigger multiplier", "Core costs", "Familiar machines"],
	],
	Layouts: ["Dock", "Crystal", "Foundry", "Rift", "Horizon"],
};

// 1-based cycling pick, the way every table above is read
export function cycle<T>(list: T[], n: number): T {
	return list[(n - 1) % list.size()];
}

export interface GeneratedNames {
	Name: string;
	Prefix: string;
	Layout: string;
	Features: string[];
}

// name, layout and features for the generated world `tier` steps past the last authored one
export function generatedNames(tier: number): GeneratedNames {
	const prefix = cycle(GENERATED.Prefixes, tier);
	const noun = GENERATED.Nouns[math.floor((tier - 1) / GENERATED.Prefixes.size())];
	return {
		Name: prefix + " " + noun,
		Prefix: prefix,
		Layout: cycle(GENERATED.Layouts, tier),
		Features: cycle(GENERATED.Features, tier),
	};
}

export function generatedStats(tier: number) {
	const s = GENERATED_STATS;
	return {
		Cost: math.floor(math.exp(math.min(s.CostLnCap, s.CostLnBase + tier * s.CostLnPerTier))),
		CoreCost: s.CoreCostBase + math.floor(tier * s.CoreCostPerTier),
		Multiplier: s.MultiplierBase * (1 + tier * s.MultiplierPerTier),
		RequiredRebirths: s.RebirthsBase + math.floor(tier * s.RebirthsPerTier),
	};
}
