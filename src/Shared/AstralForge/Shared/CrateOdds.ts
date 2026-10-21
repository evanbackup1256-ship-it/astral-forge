// Purpose: the exact drop chances of a crate, worked out the same way CrateRollResolver picks a drop:
// a rarity is drawn by weight (only rarities at or above the pity floor once pity is due), then one
// item of that rarity with equal chance. The odds sheet in the Shop shows these numbers as they are.
// Owner: gameplay. Dependencies: none.

export interface OddsCrate {
	Weights?: Record<string, number>;
	PityAfter?: number;
	PityRarity?: string;
}

export interface OddsItem {
	Id: string;
	Name?: string;
	Rarity: string;
}

export interface RarityOdds {
	rarity: string;
	chance: number;
	items: { id: string; name: string; chance: number }[];
}

function rankOf(rarities: Record<string, { Rank?: number }>, rarity: string): number | undefined {
	const definition = rarities[rarity];
	return definition !== undefined ? (definition.Rank ?? 0) : undefined;
}

function weightOf(value: unknown): number {
	const weight = tonumber(value) ?? 0;
	return weight === weight && weight > 0 && weight !== math.huge ? weight : 0;
}

// The lowest rank the resolver will draw from. `pity` is the crate's saved pity count.
export function floorRank(crate: OddsCrate, rarities: Record<string, { Rank?: number }>, pity: number): number {
	const pityAfter = math.max(0, math.floor(crate.PityAfter ?? 0));
	if (crate.PityRarity === undefined || math.max(0, math.floor(pity)) + 1 < pityAfter) {
		return 0;
	}
	return math.max(0, math.floor(rankOf(rarities, crate.PityRarity) ?? 0));
}

// Rarities come back rarest first. A rarity with weight but no items is still listed (with no items),
// because the resolver can land on it; the crate test treats that as a config error.
export function crateOdds(
	crate: OddsCrate,
	rarities: Record<string, { Rank?: number }>,
	definitions: OddsItem[],
	order: string[],
	pity = 0,
): RarityOdds[] {
	const minimum = floorRank(crate, rarities, pity);
	const weights = crate.Weights ?? {};
	let total = 0;
	for (const rarity of order) {
		const rank = rankOf(rarities, rarity);
		if (rank !== undefined && rank >= minimum) {
			total += weightOf(weights[rarity]);
		}
	}
	const result: RarityOdds[] = [];
	if (total <= 0) {
		return result;
	}
	for (let index = order.size() - 1; index >= 0; index--) {
		const rarity = order[index];
		const rank = rankOf(rarities, rarity);
		const weight = weightOf(weights[rarity]);
		if (rank === undefined || rank < minimum || weight <= 0) {
			continue;
		}
		const chance = weight / total;
		const pool = definitions.filter((definition) => definition.Rarity === rarity);
		const items = pool.map((definition) => ({
			id: definition.Id,
			name: definition.Name ?? definition.Id,
			chance: chance / pool.size(),
		}));
		items.sort((a, b) => a.name < b.name);
		result.push({ rarity, chance, items });
	}
	return result;
}

// Rarities a crate can roll that have no item to hand out. Empty for a healthy crate.
export function emptyRarities(
	crate: OddsCrate,
	rarities: Record<string, { Rank?: number }>,
	definitions: OddsItem[],
	order: string[],
): string[] {
	const missing: string[] = [];
	for (const row of crateOdds(crate, rarities, definitions, order, 0)) {
		if (row.items.size() === 0) {
			missing.push(row.rarity);
		}
	}
	return missing;
}
