// The relic and inventory model in one place.
//
// Save shape (unchanged): profile.Items = {
//   Inventory: { [uid]: { DefinitionId, Level, AcquiredAt, Stars?, Locked?, Bond?, Engraving? } },
//   Equipped:  { [target]: uid },   // target is "Machine:<id>", "Research:<id>", "Companion:1", "Expedition:<n>"
//   Discovered: { [definitionId]: true },
//   NextId: number,                 // the counter behind "IT0000001"-style uids
// }
//
// A uid is minted once and never reused while the relic exists, so it is the stable id the
// client, trades and logs all refer to. Definition lookups go through a map built once from the
// config instead of scanning the list every call.
import GameConfig = require("./GameConfig");

type Dict = Record<string, unknown>;

export interface RelicDefinition {
	Id: string;
	Name: string;
	Rarity: string;
	Slot?: string;
	EffectKind: string;
	BaseEffect: number;
	LevelGrowth: number;
	MaxLevel?: number;
	Targets?: string[];
}

export interface RelicInstance {
	DefinitionId: string;
	Level: number;
	AcquiredAt: number;
	Stars?: number;
	Locked?: boolean;
}

export const UID_FORMAT = "IT%07d";

let byId: Map<string, RelicDefinition> | undefined;
let byRarity: Map<string, RelicDefinition[]> | undefined;

function definitions(): RelicDefinition[] {
	const items = (GameConfig as unknown as { Items?: { Definitions?: RelicDefinition[] } }).Items;
	return items?.Definitions ?? [];
}

function buildIndexes(): void {
	const ids = new Map<string, RelicDefinition>();
	const rarities = new Map<string, RelicDefinition[]>();
	for (const definition of definitions()) {
		ids.set(definition.Id, definition);
		let bucket = rarities.get(definition.Rarity);
		if (bucket === undefined) {
			bucket = [];
			rarities.set(definition.Rarity, bucket);
		}
		bucket.push(definition);
	}
	byId = ids;
	byRarity = rarities;
}

export function definition(id: unknown): RelicDefinition | undefined {
	if (!typeIs(id, "string")) return undefined;
	if (byId === undefined) buildIndexes();
	return (byId as Map<string, RelicDefinition>).get(id);
}

// every definition of one rarity, in config order; the same array each call, so don't mutate it
export function definitionsOfRarity(rarity: unknown): readonly RelicDefinition[] {
	if (!typeIs(rarity, "string")) return [];
	if (byRarity === undefined) buildIndexes();
	return (byRarity as Map<string, RelicDefinition[]>).get(rarity) ?? [];
}

export function inventoryOf(items: unknown): Dict | undefined {
	const inventory = typeIs(items, "table") ? (items as Dict).Inventory : undefined;
	return typeIs(inventory, "table") ? (inventory as Dict) : undefined;
}

export function equippedOf(items: unknown): Dict | undefined {
	const equipped = typeIs(items, "table") ? (items as Dict).Equipped : undefined;
	return typeIs(equipped, "table") ? (equipped as Dict) : undefined;
}

export function instance(items: unknown, uid: unknown): Dict | undefined {
	if (!typeIs(uid, "string") || uid === "") return undefined;
	const value = inventoryOf(items)?.[uid];
	return typeIs(value, "table") ? (value as Dict) : undefined;
}

// the uid sitting in one target, or nothing for an empty slot or a dangling uid
export function uidAt(items: unknown, target: string): string | undefined {
	const uid = equippedOf(items)?.[target];
	return typeIs(uid, "string") && instance(items, uid) !== undefined ? uid : undefined;
}

// the relic in a target with its definition; both undefined when the slot is empty or stale
export function at(items: unknown, target: string): LuaTuple<[Dict | undefined, RelicDefinition | undefined]> {
	const found = instance(items, uidAt(items, target));
	const def = found !== undefined ? definition(found.DefinitionId) : undefined;
	return $tuple(def !== undefined ? found : undefined, def);
}

// uid -> target for everything equipped anywhere (sockets, companion, expeditions)
export function equippedIndex(items: unknown): Map<string, string> {
	const index = new Map<string, string>();
	const equipped = equippedOf(items);
	if (equipped === undefined) return index;
	for (const [target, uid] of pairs(equipped)) {
		if (typeIs(target, "string") && typeIs(uid, "string")) index.set(uid, target);
	}
	return index;
}

export function isEquipped(items: unknown, uid: string): boolean {
	const equipped = equippedOf(items);
	if (equipped === undefined) return false;
	for (const [, value] of pairs(equipped)) {
		if (value === uid) return true;
	}
	return false;
}

export function count(items: unknown): number {
	let total = 0;
	const inventory = inventoryOf(items);
	if (inventory === undefined) return 0;
	for (const [, value] of pairs(inventory)) {
		if (typeIs(value, "table")) total += 1;
	}
	return total;
}

// Mints the next free uid and advances NextId past it. Uses the counter as the next number to
// hand out, and skips any uid already owned so a stale or reset counter can't overwrite a relic.
export function mintUid(items: Dict): string {
	const inventory = (inventoryOf(items) ?? {}) as Dict;
	let cursor = math.max(1, math.floor(tonumber(items.NextId) ?? 1));
	let uid = string.format(UID_FORMAT, cursor);
	while (inventory[uid] !== undefined) {
		cursor += 1;
		uid = string.format(UID_FORMAT, cursor);
	}
	items.NextId = cursor + 1;
	return uid;
}

// a fresh level-1 relic, stored under a new uid and marked discovered; returns the uid
export function add(items: Dict, definitionId: string, now: number): string {
	if (!typeIs(items.Inventory, "table")) items.Inventory = {};
	const uid = mintUid(items);
	(items.Inventory as Dict)[uid] = { DefinitionId: definitionId, Level: 1, AcquiredAt: now } satisfies RelicInstance;
	if (!typeIs(items.Discovered, "table")) items.Discovered = {};
	(items.Discovered as Dict)[definitionId] = true;
	return uid;
}
