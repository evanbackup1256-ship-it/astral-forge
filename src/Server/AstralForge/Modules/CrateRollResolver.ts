// Purpose: server-owned crate rarity, pity and definition selection with typed inputs.
// Owner: gameplay. Dependencies: caller-provided random functions and rarity order.
// Last-reviewed: 2026-10-07.

interface Crate {
	PityRarity: string;
	PityAfter: number;
	Weights: Record<string, number>;
}
interface Rarity {
	Rank: number;
}
type RandomNumber = (min: number, max: number) => number;
type RandomInteger = (min: number, max: number) => number;

const Resolver = {
	roll<T extends defined>(
		this: void,
		crate: Crate,
		pity: number,
		rarities: Record<string, Rarity>,
		definitions: T[],
		rarityOf: (definition: T) => string,
		nextNumber: RandomNumber,
		nextInteger: RandomInteger,
		order: string[],
		minimumInterval: number,
	): LuaTuple<[T | undefined, string, boolean]> {
		assert(finite(pity) && finite(crate.PityAfter), "Invalid crate pity state");
		assert(finite(minimumInterval) && minimumInterval > 0, "Invalid crate roll interval");
		const pityDefinition = rarities[crate.PityRarity];
		const pityRank = pityDefinition ? pityDefinition.Rank : 0;
		const minimumRank =
			math.max(0, math.floor(pity)) + 1 >= math.max(0, math.floor(crate.PityAfter))
				? math.max(0, math.floor(pityRank))
				: 0;
		let total = 0;
		for (const [rarity, weight] of pairs(crate.Weights)) {
			assert(finite(weight) && weight >= 0, "Invalid crate rarity weight");
			const definition = rarities[rarity];
			if (definition && definition.Rank >= minimumRank) {
				total += weight;
			}
		}
		assert(finite(total), "Crate rarity weights overflowed");
		const maximum = math.max(total, minimumInterval);
		let remaining = nextNumber(0, maximum);
		assert(
			finite(remaining) && remaining >= 0 && remaining <= maximum,
			"Invalid crate random result",
		);
		let selected = crate.PityRarity;
		for (const rarity of order) {
			const definition = rarities[rarity];
			const weight = crate.Weights[rarity] ?? 0;
			if (definition && definition.Rank >= minimumRank && weight > 0) {
				remaining -= weight;
				if (remaining <= 0) {
					selected = rarity;
					break;
				}
			}
		}
		const candidates: T[] = [];
		for (const definition of definitions) {
			if (rarityOf(definition) === selected) {
				candidates.push(definition);
			}
		}
		let index = nextInteger(1, math.max(1, candidates.size()));
		assert(finite(index), "Invalid crate candidate index");
		if (candidates.size() === 0) {
			return $tuple(undefined, selected, false);
		}
		index = math.clamp(math.floor(index), 1, candidates.size());
		const selectedDefinition = rarities[selected];
		const selectedRank = selectedDefinition ? selectedDefinition.Rank : 0;
		return $tuple(candidates[index - 1], selected, selectedRank >= pityRank);
	},
};

function finite(value: number): boolean {
	return value === value && math.abs(value) !== math.huge;
}

export = table.freeze(Resolver);
