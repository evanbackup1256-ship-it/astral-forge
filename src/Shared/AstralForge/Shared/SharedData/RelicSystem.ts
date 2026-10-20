type Dict = Record<string, unknown>;

const ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"];

// Luau `a or b`: only nil and false fall through.
function orElse<T>(value: unknown, fallback: T): T {
	return (value === undefined || value === false ? fallback : value) as T;
}

function stars(instance: unknown): number {
	const n = typeIs(instance, "table") ? tonumber((instance as Dict).Stars) : undefined;
	if (!typeIs(n, "number") || n !== n) {
		return 0;
	}
	return math.max(0, math.floor(n));
}

function starMultiplier(items: unknown, count: unknown): number {
	const maxStars = orElse<number>(typeIs(items, "table") && (items as Dict).MaxStars, 5);
	const bonus = orElse<number>(typeIs(items, "table") && (items as Dict).StarBonus, 0.25);
	const n = tonumber(count);
	if (!typeIs(n, "number") || n !== n) {
		return 1;
	}
	return 1 + bonus * math.clamp(math.floor(n), 0, maxStars);
}

function level(instance: unknown): number {
	return typeIs(instance, "table") && typeIs((instance as Dict).Level, "number") ? ((instance as Dict).Level as number) : 1;
}

function fusionPair(
	inventory: unknown,
	equipped: unknown,
	definitionId: string,
	maxStars?: number,
): LuaTuple<[string | undefined, string | undefined, string | undefined]> {
	if (!typeIs(inventory, "table")) {
		return $tuple(undefined, undefined, "You have no relics.");
	}
	const inv = inventory as Record<string, Dict>;
	const cap = maxStars ?? 5;
	const socketed = new Map<unknown, boolean>();
	if (typeIs(equipped, "table")) {
		for (const [, uid] of pairs(equipped as Dict)) {
			socketed.set(uid, true);
		}
	}
	const copies: string[] = [];
	for (const [uid, instance] of pairs(inv)) {
		if (typeIs(instance, "table") && instance.DefinitionId === definitionId) {
			copies.push(uid);
		}
	}
	if (copies.size() < 2) {
		return $tuple(undefined, undefined, "You need two copies of this relic to fuse them.");
	}
	copies.sort((a, b) => {
		const ia = inv[a];
		const ib = inv[b];
		if ((socketed.get(a) === true) !== (socketed.get(b) === true)) {
			return socketed.get(a) === true;
		}
		if (stars(ia) !== stars(ib)) {
			return stars(ia) > stars(ib);
		}
		if (level(ia) !== level(ib)) {
			return level(ia) > level(ib);
		}
		return a < b;
	});
	const target = copies[0];
	if (stars(inv[target]) >= cap) {
		return $tuple(undefined, undefined, "That relic already has every star.");
	}
	for (let index = copies.size() - 1; index >= 1; index--) {
		const uid = copies[index];
		const instance = inv[uid];
		if (!socketed.get(uid) && instance.Locked !== true) {
			return $tuple(target, uid, undefined);
		}
	}
	return $tuple(undefined, undefined, "Every spare copy is socketed or locked.");
}

function fuse(target: unknown, fodder: unknown, maxStars?: number): LuaTuple<[number, number]> {
	const cap = maxStars ?? 5;
	const nextStars = math.min(cap, stars(target) + 1 + stars(fodder));
	return $tuple(nextStars, math.max(level(target), level(fodder)));
}

type Progress = Record<string, { found: number; total: number }>;

function codex(discovered: unknown, items: unknown): LuaTuple<[Progress, number]> {
	const definitions = typeIs(items, "table") ? (items as Dict).Definitions : undefined;
	const bonuses = typeIs(items, "table") ? (items as Dict).CodexBonus : undefined;
	const progress: Progress = {};
	for (const rarity of ORDER) {
		progress[rarity] = { found: 0, total: 0 };
	}
	if (!typeIs(definitions, "table")) {
		return $tuple(progress, 0);
	}
	for (const [, definition] of pairs(definitions as Record<string, Dict>)) {
		const rarity = definition.Rarity as string;
		let row = progress[rarity] as Progress[string] | undefined;
		if (row === undefined) {
			row = { found: 0, total: 0 };
			progress[rarity] = row;
		}
		row.total += 1;
		if (typeIs(discovered, "table") && (discovered as Dict)[definition.Id as string] === true) {
			row.found += 1;
		}
	}
	let bonus = 0;
	for (const [rarity, row] of pairs(progress)) {
		if (row.total > 0 && row.found === row.total && typeIs(bonuses, "table")) {
			bonus += tonumber((bonuses as Dict)[rarity]) ?? 0;
		}
	}
	return $tuple(progress, bonus);
}

function odds(weights: unknown): { rarity: string; chance: number }[] {
	let total = 0;
	for (const [, weight] of pairs((typeIs(weights, "table") ? weights : {}) as Dict)) {
		total += math.max(0, tonumber(weight) ?? 0);
	}
	const list: { rarity: string; chance: number }[] = [];
	for (const rarity of ORDER) {
		const weight = typeIs(weights, "table") ? (tonumber((weights as Dict)[rarity]) ?? 0) : 0;
		if (weight > 0 && total > 0) {
			list.push({ rarity, chance: weight / total });
		}
	}
	return list;
}

function chanceText(chance: number): string {
	if (chance <= 0) {
		return "-";
	}
	if (chance < 0.001) {
		const oneIn = math.floor(1 / chance + 0.5);
		const text = tostring(oneIn);
		const formatted = text.reverse().gsub("(%d%d%d)", "%1,")[0].reverse();
		return "1 in " + formatted.gsub("^,", "")[0];
	}
	if (chance < 0.01) {
		return "%.2f%%".format(chance * 100);
	}
	return "%.1f%%".format(chance * 100);
}

export = table.freeze({ ORDER, stars, starMultiplier, fusionPair, fuse, codex, odds, chanceText });
