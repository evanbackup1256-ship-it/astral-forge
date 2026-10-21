// A companion is one relic you keep with you instead of socketing it. It lives in
// Items.Equipped under its own key, so everything that already refuses to trade,
// salvage or fuse an equipped relic treats the companion the same way for free.
//
// It gives a share of its own effect as a global bonus of the same kind, so a
// levelled, starred favourite stays useful even after the sockets fill up.
// BALANCE: SHARE is a first pass. A socketed relic still pays more than a companion.
import GameConfig = require("./GameConfig");

type Dict = Record<string, unknown>;

const TARGET = "Companion:1";
const SLOT = "Companion";
const SHARE = 0.4;
const STAR_BONUS = 0.25;
const MAX_STARS = 5;

interface Definition {
	Id: string;
	Name: string;
	Rarity: string;
	EffectKind: string;
	BaseEffect: number;
	LevelGrowth: number;
}

function definitionOf(id: unknown): Definition | undefined {
	if (!typeIs(id, "string")) {
		return undefined;
	}
	const items = (GameConfig as unknown as { Items: { Definitions: Definition[] } }).Items;
	for (const definition of items.Definitions) {
		if (definition.Id === id) {
			return definition;
		}
	}
	return undefined;
}

function uidOf(items: unknown): string | undefined {
	if (!typeIs(items, "table")) {
		return undefined;
	}
	const equipped = (items as Dict).Equipped;
	const uid = typeIs(equipped, "table") ? (equipped as Dict)[TARGET] : undefined;
	return typeIs(uid, "string") && uid !== "" ? uid : undefined;
}

// the relic instance and its definition, or nothing when the slot is empty or stale
function current(items: unknown): LuaTuple<[Dict | undefined, Definition | undefined]> {
	const uid = uidOf(items);
	const inventory = uid !== undefined ? (items as Dict).Inventory : undefined;
	const instance = typeIs(inventory, "table") ? (inventory as Dict)[uid as string] : undefined;
	if (!typeIs(instance, "table")) {
		return $tuple(undefined, undefined);
	}
	const definition = definitionOf((instance as Dict).DefinitionId);
	return $tuple(definition !== undefined ? (instance as Dict) : undefined, definition);
}

function effectOf(instance: Dict, definition: Definition): number {
	const level = typeIs(instance.Level, "number") ? math.max(1, instance.Level) : 1;
	const stars = typeIs(instance.Stars, "number") ? math.clamp(math.floor(instance.Stars), 0, MAX_STARS) : 0;
	const base = definition.BaseEffect * (1 + definition.LevelGrowth * (level - 1));
	return base * (1 + STAR_BONUS * stars) * SHARE;
}

function bonus(items: unknown, kind: string): number {
	const [instance, definition] = current(items);
	if (instance === undefined || definition === undefined || definition.EffectKind !== kind) {
		return 0;
	}
	return effectOf(instance, definition);
}

// what the profile card and HUD show; undefined when nobody is along for the ride
function describe(items: unknown): { Uid: string; Id: string; Name: string; Rarity: string; Kind: string; Bonus: number } | undefined {
	const [instance, definition] = current(items);
	if (instance === undefined || definition === undefined) {
		return undefined;
	}
	return {
		Uid: uidOf(items) as string,
		Id: definition.Id,
		Name: definition.Name,
		Rarity: definition.Rarity,
		Kind: definition.EffectKind,
		Bonus: effectOf(instance, definition),
	};
}

// drops the key when it points at nothing, so a salvaged or traded relic can't linger
function sanitize(items: unknown): void {
	if (!typeIs(items, "table")) {
		return;
	}
	const equipped = (items as Dict).Equipped;
	if (!typeIs(equipped, "table")) {
		return;
	}
	if ((equipped as Dict)[TARGET] !== undefined && current(items)[0] === undefined) {
		(equipped as Dict)[TARGET] = undefined;
	}
}

const CompanionRelic = { TARGET, SLOT, SHARE, uidOf, bonus, describe, sanitize };
export = table.freeze(CompanionRelic);
