// Relic engraving: a relic grows up to three extra lines as it levels (10, 25, 50). Each line is
// a small bonus of one kind, rolled on the server. Rerolling a line costs Essence and Starsteel;
// locking a line keeps it safe from rerolls and makes the others dearer to reroll.
//
// Lines pay only while the relic is doing something: socketed, or along as the companion.
// Lines live on the relic instance, so trades and fusion targets carry them.
// BALANCE: first pass. Line ceilings sit well under a socket bonus at the same rarity.
import { T } from "./Locale";

type Dict = Record<string, unknown>;

export interface Line {
	Kind: string;
	Value: number;
	Locked?: boolean;
}

export interface Engraving {
	Lines: Line[];
	Rolls: number;
}

export const UNLOCK_LEVELS = [10, 25, 50];

// the most a line can roll at rank 1; higher rarities scale it up
export const CEILING: Record<string, number> = {
	Production: 0.03,
	Capacity: 0.04,
	Tap: 0.04,
	Offline: 0.03,
	Critical: 0.004,
	Automation: 0.003,
};
export const KINDS = ["Production", "Capacity", "Tap", "Offline", "Critical", "Automation"];
const FLOOR_SHARE = 0.4;
const RANK_STEP = 0.2;
const COST_STEP = 0.25;
const COST_CAP_ROLLS = 12;

const RANKS: Record<string, number> = {
	Common: 1,
	Uncommon: 2,
	Rare: 3,
	Epic: 4,
	Legendary: 5,
	Mythic: 6,
	Celestial: 7,
	Astral: 8,
};

export function rankOf(rarity: unknown): number {
	return typeIs(rarity, "string") ? (RANKS[rarity] ?? 1) : 1;
}

export function ceilingFor(kind: string, rarity: unknown): number {
	const base = CEILING[kind];
	return base === undefined ? 0 : base * (1 + RANK_STEP * (rankOf(rarity) - 1));
}

export function slotsAt(level: unknown): number {
	const n = typeIs(level, "number") ? level : 1;
	let slots = 0;
	for (const at of UNLOCK_LEVELS) {
		if (n >= at) {
			slots += 1;
		}
	}
	return slots;
}

function int(value: unknown): number {
	const n = tonumber(value);
	return n !== undefined && n === n && n > 0 && n < math.huge ? math.floor(n) : 0;
}

// repairs an instance's engraving in place: known kinds only, no repeats, values inside the
// rarity's range, no more lines than the level allows. Returns undefined for "no engraving".
export function sanitize(instance: Dict, rarity: unknown): Engraving | undefined {
	const raw = instance.Engraving;
	if (!typeIs(raw, "table")) {
		instance.Engraving = undefined;
		return undefined;
	}
	const slots = slotsAt(instance.Level);
	const lines: Line[] = [];
	const seen: Record<string, boolean> = {};
	const input = (raw as Dict).Lines;
	if (typeIs(input, "table")) {
		for (const entry of input as unknown[]) {
			if (lines.size() >= slots || !typeIs(entry, "table")) {
				continue;
			}
			const kind = (entry as Dict).Kind;
			const value = tonumber((entry as Dict).Value);
			if (!typeIs(kind, "string") || CEILING[kind] === undefined || seen[kind] || value === undefined || value !== value) {
				continue;
			}
			seen[kind] = true;
			const line: Line = { Kind: kind, Value: math.clamp(value, 0, ceilingFor(kind, rarity)) };
			if ((entry as Dict).Locked === true) {
				line.Locked = true;
			}
			lines.push(line);
		}
	}
	const clean: Engraving = { Lines: lines, Rolls: int((raw as Dict).Rolls) };
	instance.Engraving = clean;
	return clean;
}

export interface CostDefinition {
	EssenceBase?: unknown;
	Rarity?: unknown;
}

// what the next roll on this relic costs
export function cost(definition: CostDefinition, engraving: Engraving | undefined): { Essence: number; Starsteel: number } {
	const base = math.max(1, tonumber(definition.EssenceBase) ?? 20);
	const rolls = math.min(COST_CAP_ROLLS, engraving !== undefined ? engraving.Rolls : 0);
	let locked = 0;
	if (engraving !== undefined) {
		for (const line of engraving.Lines) {
			if (line.Locked === true) {
				locked += 1;
			}
		}
	}
	return {
		Essence: math.floor(base * 3 * (1 + COST_STEP * rolls) * (1 + locked)),
		Starsteel: rankOf(definition.Rarity),
	};
}

function rollLine(random: () => number, rarity: unknown, taken: Record<string, boolean>): Line | undefined {
	const open = KINDS.filter((kind) => !taken[kind]);
	if (open.size() === 0) {
		return undefined;
	}
	const kind = open[math.clamp(math.floor(random() * open.size()), 0, open.size() - 1)];
	const top = ceilingFor(kind, rarity);
	const value = top * (FLOOR_SHARE + (1 - FLOOR_SHARE) * math.clamp(random(), 0, 1));
	return { Kind: kind, Value: math.floor(value * 1e5 + 0.5) / 1e5 };
}

export interface Wallet {
	Essence: number;
	Starsteel: number;
}

// rolls (or rerolls) line `index` (1-based). Mutates instance and wallet only when it succeeds.
export function roll(
	instance: Dict,
	definition: CostDefinition,
	index: unknown,
	wallet: Wallet,
	random: () => number,
): LuaTuple<[boolean, string, Line | undefined]> {
	const slots = slotsAt(instance.Level);
	if (slots === 0) {
		return $tuple(false, T("RelicEngraving.ReachLevelDToEngrave", UNLOCK_LEVELS[0]), undefined);
	}
	if (!typeIs(index, "number") || index !== math.floor(index) || index < 1 || index > UNLOCK_LEVELS.size()) {
		return $tuple(false, T("RelicEngraving.PickALine"), undefined);
	}
	if (index > slots) {
		return $tuple(false, T("RelicEngraving.ThatLineOpensAtLevelD", UNLOCK_LEVELS[index - 1]), undefined);
	}
	const engraving = sanitize(instance, definition.Rarity) ?? { Lines: [], Rolls: 0 };
	const existing = engraving.Lines[index - 1];
	if (existing === undefined && index > engraving.Lines.size() + 1) {
		return $tuple(false, T("RelicEngraving.FillTheLinesInOrder"), undefined);
	}
	if (existing !== undefined && existing.Locked === true) {
		return $tuple(false, T("RelicEngraving.UnlockThatLineFirst"), undefined);
	}
	const price = cost(definition, engraving);
	if (wallet.Essence < price.Essence) {
		return $tuple(false, T("RelicEngraving.YouNeedDMoreEssence", price.Essence - wallet.Essence), undefined);
	}
	if (wallet.Starsteel < price.Starsteel) {
		return $tuple(false, T("RelicEngraving.YouNeedDMoreStarsteel", price.Starsteel - wallet.Starsteel), undefined);
	}
	const taken: Record<string, boolean> = {};
	engraving.Lines.forEach((line, i) => {
		if (i !== index - 1) {
			taken[line.Kind] = true;
		}
	});
	const line = rollLine(random, definition.Rarity, taken);
	if (line === undefined) {
		return $tuple(false, T("RelicEngraving.PickALine"), undefined);
	}
	wallet.Essence -= price.Essence;
	wallet.Starsteel -= price.Starsteel;
	engraving.Lines[index - 1] = line;
	engraving.Rolls += 1;
	instance.Engraving = engraving;
	return $tuple(true, T("RelicEngraving.LineDNowReadsS", index, describe(line)), line);
}

export function toggleLock(instance: Dict, rarity: unknown, index: unknown): LuaTuple<[boolean, string]> {
	const engraving = sanitize(instance, rarity);
	const line = engraving !== undefined && typeIs(index, "number") ? engraving.Lines[index - 1] : undefined;
	if (line === undefined) {
		return $tuple(false, T("RelicEngraving.ThereSNothingEngravedThere"));
	}
	line.Locked = line.Locked === true ? undefined : true;
	return $tuple(true, line.Locked === true ? T("RelicEngraving.LineLocked") : T("RelicEngraving.LineUnlocked"));
}

export function describe(line: Line): string {
	const scaled = math.floor(line.Value * 10000 + 0.5) / 100;
	return `+${scaled}% ${line.Kind.lower()}`;
}

// sum of every line of `kind` on relics that are socketed or along as the companion. Read-only.
export function bonus(items: unknown, kind: string): number {
	if (!typeIs(items, "table")) {
		return 0;
	}
	const equipped = (items as Dict).Equipped;
	const inventory = (items as Dict).Inventory;
	if (!typeIs(equipped, "table") || !typeIs(inventory, "table")) {
		return 0;
	}
	const counted: Record<string, boolean> = {};
	let total = 0;
	for (const [, uid] of pairs(equipped as Dict)) {
		if (!typeIs(uid, "string") || counted[uid]) {
			continue;
		}
		counted[uid] = true;
		const instance = (inventory as Dict)[uid];
		const engraving = typeIs(instance, "table") ? (instance as Dict).Engraving : undefined;
		const lines = typeIs(engraving, "table") ? (engraving as Dict).Lines : undefined;
		if (!typeIs(lines, "table")) {
			continue;
		}
		const slots = slotsAt((instance as Dict).Level);
		let index = 0;
		for (const line of lines as unknown[]) {
			index += 1;
			if (index > slots) {
				break;
			}
			if (typeIs(line, "table") && (line as Dict).Kind === kind) {
				const value = tonumber((line as Dict).Value);
				if (value !== undefined && value === value && value > 0) {
					total += value;
				}
			}
		}
	}
	return total;
}
