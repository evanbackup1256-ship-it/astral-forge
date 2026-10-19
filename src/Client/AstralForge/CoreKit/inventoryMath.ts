// Inline helpers so the compiled output has no cross-module TS.import (keeps Lune tests working)
type Dict = Record<string, unknown>;
function isTable(value: unknown): value is Dict {
	return typeIs(value, "table");
}
function truthy<T>(value: T): value is Exclude<T, undefined | false> {
	return value !== undefined && (value as unknown) !== false;
}

export const AUTO_RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"];

export const ROW_H = 112;
export const ROW_H_STACK = 132;

export interface ItemDefinition {
	Id?: string;
	Name?: string;
	Description?: string;
	EffectKind?: string;
	Rarity?: string;
	Slot?: string;
	BaseEffect?: number;
	LevelGrowth?: number;
	EssenceBase?: number;
	Targets?: string[];
	[key: string]: unknown;
}

export interface ItemInstance {
	DefinitionId?: string;
	Level: number;
	Stars?: number;
	Locked?: boolean;
	AcquiredAt?: number;
	[key: string]: unknown;
}

export interface OwnedItem {
	uid: string;
	instance: ItemInstance;
	definition: ItemDefinition;
	equippedOn?: string;
}

interface RarityConfig {
	Items?: { Rarities?: Record<string, { Rank?: number; Color?: Color3 }>; Definitions?: unknown };
	Machines?: unknown;
	Research?: unknown;
}

export function RelicRowHeight(stack: boolean): number {
	return stack ? ROW_H_STACK : ROW_H;
}

function rarityEntry(config: unknown, rarity: unknown): { Rank?: unknown; Color?: unknown } | undefined {
	const items = isTable(config) ? (config as RarityConfig).Items : undefined;
	const rarities = isTable(items) ? items.Rarities : undefined;
	const entry = isTable(rarities) ? rarities[rarity as string] : undefined;
	return isTable(entry) ? entry : undefined;
}

export function RarityRank(config: unknown, rarity: unknown): number {
	const rank = rarityEntry(config, rarity)?.Rank;
	return typeIs(rank, "number") ? rank : 0;
}

export function StarMultiplier(stars: unknown): number {
	const n = tonumber(stars);
	if (!typeIs(n, "number") || n !== n) {
		return 1;
	}
	return 1 + 0.25 * math.clamp(math.floor(n), 0, 5);
}

export function EffectAtLevel(definition: unknown, level: unknown, stars?: unknown): number {
	if (!isTable(definition)) {
		return 0;
	}
	const base = tonumber(definition.BaseEffect) ?? 0;
	const growth = tonumber(definition.LevelGrowth) ?? 0;
	const safeLevel = typeIs(level, "number") ? level : 1;
	return base * (1 + growth * math.max(0, safeLevel - 1)) * StarMultiplier(stars);
}

export function RarityColor<T>(config: unknown, rarity: unknown, fallback: T): Color3 | T {
	const color = rarityEntry(config, rarity)?.Color;
	if (color !== undefined) {
		return color as Color3;
	}
	return fallback;
}

export function EffectLabel(definition: unknown, level: unknown, stars?: unknown): string {
	const pct = math.floor(EffectAtLevel(definition, level, stars) * 1000 + 0.5) / 10;
	const kind = isTable(definition) && typeIs(definition.EffectKind, "string") ? definition.EffectKind : "Effect";
	return `+${pct}% ${kind}`;
}

export function UpgradeCost(definition: unknown, level: unknown): number {
	if (!isTable(definition)) {
		return 0;
	}
	const base = tonumber(definition.EssenceBase) ?? 0;
	const safeLevel = typeIs(level, "number") ? level : 1;
	return math.floor(base * 1.55 ** math.max(0, safeLevel - 1));
}

export function SalvageValue(level: unknown, rarityRank: unknown): number {
	const rank = typeIs(rarityRank, "number") ? rarityRank : 1;
	const safeLevel = typeIs(level, "number") ? level : 1;
	return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3;
}

export function SalvagePreview(config: unknown, definition: unknown, level: unknown): number {
	const rarity = isTable(definition) ? definition.Rarity : undefined;
	return SalvageValue(level, RarityRank(config, rarity));
}

export function SocketLabel(target: unknown): string {
	if (!typeIs(target, "string")) {
		return tostring(target);
	}
	const parts = target.split(":");
	return parts.size() >= 2 ? `${parts[0]} / ${parts[1]}` : target;
}

function definitionId(item: OwnedItem): string | undefined {
	return isTable(item.definition) ? (item.definition.Id ?? item.definition.Name) : undefined;
}

export function FilterOwned(list: unknown, filter: unknown): OwnedItem[] {
	if (!typeIs(list, "table")) {
		return [];
	}
	const items = list as OwnedItem[];
	if (filter === "All" || filter === undefined) {
		return items;
	}
	const defCounts = new Map<string, number>();
	if (filter === "Duplicates") {
		for (const item of items) {
			if (isTable(item) && isTable(item.definition)) {
				const id = definitionId(item);
				if (id !== undefined) {
					defCounts.set(id, (defCounts.get(id) ?? 0) + 1);
				}
			}
		}
	}
	const out = new Array<OwnedItem>();
	for (const item of items) {
		if (!isTable(item)) {
			continue;
		}
		let keep = false;
		if (filter === "Duplicates") {
			const id = definitionId(item);
			keep = id !== undefined && (defCounts.get(id) ?? 0) > 1;
		} else if (filter === "Starred") {
			keep = isTable(item.instance) && (tonumber(item.instance.Stars) ?? 0) > 0;
		} else if (filter === "Equipped") {
			keep = item.equippedOn !== undefined;
		} else if (filter === "Unequipped") {
			keep = item.equippedOn === undefined;
		} else if (filter === "Protected") {
			keep = isTable(item.instance) && item.instance.Locked === true;
		} else if (isTable(item.definition)) {
			keep = item.definition.Slot === filter;
		}
		if (keep) {
			out.push(item);
		}
	}
	return out;
}

export type ItemMatcher = (
	query: string,
	name?: string,
	description?: string,
	effectKind?: string,
	rarity?: string,
	slot?: string,
	uid?: string,
) => unknown;

// `matcher(query, ...)` swaps in fuzzy matching (Quick Find style); substring otherwise.
export function SearchOwned(list: unknown, query: unknown, rarity: unknown, matcher?: ItemMatcher): OwnedItem[] {
	if (!typeIs(list, "table")) {
		return [];
	}
	const [needle] = tostring(query ?? "").lower().gsub("^%s*(.-)%s*$", "%1");
	const rarityFilter = rarity === undefined ? "Any" : rarity;
	const out = new Array<OwnedItem>();
	for (const item of list as OwnedItem[]) {
		if (!isTable(item) || !isTable(item.definition)) {
			continue;
		}
		const definition = item.definition;
		if (rarityFilter !== "Any" && definition.Rarity !== rarityFilter) {
			continue;
		}
		if (needle === "") {
			out.push(item);
			continue;
		}
		let found: unknown;
		if (matcher !== undefined) {
			found = matcher(needle, definition.Name, definition.Description, definition.EffectKind, definition.Rarity, definition.Slot, item.uid);
		} else {
			const haystack = `${definition.Name ?? ""} ${definition.Description ?? ""} ${definition.EffectKind ?? ""} ${item.uid ?? ""}`.lower();
			found = haystack.find(needle, 1, true)[0] !== undefined;
		}
		if (truthy(found)) {
			out.push(item);
		}
	}
	return out;
}

export function SortOwned(list: unknown, config: unknown, sort: unknown): OwnedItem[] {
	if (!typeIs(list, "table")) {
		return [];
	}
	const copy = [...(list as OwnedItem[])];
	copy.sort((a, b) => {
		if (!isTable(a) || !isTable(b)) {
			return false;
		}
		const aDef = a.definition;
		const bDef = b.definition;
		const aInst = a.instance;
		const bInst = b.instance;
		if (!isTable(aDef) || !isTable(bDef) || !isTable(aInst) || !isTable(bInst)) {
			return false;
		}
		const aName = aDef.Name ?? "";
		const bName = bDef.Name ?? "";
		if (sort === "Level") {
			if (aInst.Level !== bInst.Level) {
				return aInst.Level > bInst.Level;
			}
			return aName < bName;
		}
		if (sort === "Name") {
			return aName < bName;
		}
		if (sort === "Stars") {
			const sa = tonumber(aInst.Stars) ?? 0;
			const sb = tonumber(bInst.Stars) ?? 0;
			if (sa !== sb) {
				return sa > sb;
			}
			return RarityRank(config, aDef.Rarity) > RarityRank(config, bDef.Rarity);
		}
		if (sort === "Salvage") {
			const va = SalvageValue(aInst.Level, RarityRank(config, aDef.Rarity));
			const vb = SalvageValue(bInst.Level, RarityRank(config, bDef.Rarity));
			if (va !== vb) {
				return va > vb;
			}
			return aName < bName;
		}
		if (sort === "Newest") {
			if (aInst.AcquiredAt !== bInst.AcquiredAt) {
				return (aInst.AcquiredAt ?? 0) > (bInst.AcquiredAt ?? 0);
			}
			return tostring(a.uid ?? "") > tostring(b.uid ?? "");
		}
		if (sort === "Power") {
			const pa = EffectAtLevel(aDef, aInst.Level, aInst.Stars);
			const pb = EffectAtLevel(bDef, bInst.Level, bInst.Stars);
			if (pa !== pb) {
				return pa > pb;
			}
			return RarityRank(config, aDef.Rarity) > RarityRank(config, bDef.Rarity);
		}
		const ra = RarityRank(config, aDef.Rarity);
		const rb = RarityRank(config, bDef.Rarity);
		if (ra !== rb) {
			return ra > rb;
		}
		if (aInst.Level !== bInst.Level) {
			return aInst.Level > bInst.Level;
		}
		return aName < bName;
	});
	return copy;
}

export interface AutoSalvageRules {
	Enabled?: boolean;
	KeepNew?: boolean;
	Rarities?: Record<string, boolean>;
}

export function AutoSalvageSignature(rules: unknown, rarities?: ReadonlyArray<string>): string {
	const bag: AutoSalvageRules = isTable(rules) ? (rules as AutoSalvageRules) : {};
	const rarityList = rarities ?? AUTO_RARITIES;
	const active = new Array<string>();
	const rarityBag = isTable(bag.Rarities) ? bag.Rarities : {};
	for (const rarity of rarityList) {
		if (rarity !== "Any" && rarityBag[rarity] === true) {
			active.push(rarity);
		}
	}
	return `${truthy(bag.Enabled) ? 1 : 0}:${truthy(bag.KeepNew) ? 1 : 0}:${active.join(",")}`;
}

export function CollectOwned(state: unknown, config: unknown): OwnedItem[] {
	const items = isTable(state) ? (state.Items as Dict | undefined) : undefined;
	const configItems = isTable(config) ? (config.Items as Dict | undefined) : undefined;
	const definitions = truthy(configItems) ? configItems.Definitions : undefined;
	if (!isTable(items) || !isTable(definitions)) {
		return [];
	}
	const inventory = items.Inventory;
	if (!isTable(inventory)) {
		return [];
	}
	const byId = new Map<string, ItemDefinition>();
	for (const [, definition] of pairs(definitions)) {
		if (isTable(definition) && typeIs(definition.Id, "string")) {
			byId.set(definition.Id, definition as ItemDefinition);
		}
	}
	const equippedByUid = new Map<string, string>();
	if (isTable(items.Equipped)) {
		for (const [target, uid] of pairs(items.Equipped)) {
			if (typeIs(uid, "string")) {
				equippedByUid.set(uid, target as string);
			}
		}
	}
	const owned = new Array<OwnedItem>();
	for (const [uid, instance] of pairs(inventory)) {
		if (!typeIs(uid, "string") || !isTable(instance)) {
			continue;
		}
		const definition = byId.get(instance.DefinitionId as string);
		if (definition === undefined) {
			continue;
		}
		owned.push({
			uid,
			instance: instance as ItemInstance,
			definition,
			equippedOn: equippedByUid.get(uid),
		});
	}
	return owned;
}

export interface SocketTarget {
	id: string;
	label: unknown;
}

export function SocketTargets(state: unknown, config: unknown, definition: unknown): SocketTarget[] {
	const out = new Array<SocketTarget>();
	if (!isTable(definition) || !isTable(config) || !isTable(state)) {
		return out;
	}
	const pushUpgrade = (upgrades: unknown, slot: string, owned: unknown) => {
		if (!typeIs(upgrades, "table") || !isTable(owned)) {
			return;
		}
		for (const [, upgrade] of pairs(upgrades)) {
			if (!isTable(upgrade) || !typeIs(upgrade.Id, "string")) {
				continue;
			}
			const level = owned[upgrade.Id];
			if (!typeIs(level, "number") || level < 1) {
				continue;
			}
			const targets = definition.Targets;
			if (typeIs(targets, "table") && !(targets as defined[]).includes(upgrade.Id)) {
				continue;
			}
			out.push({ id: `${slot}:${upgrade.Id}`, label: upgrade.Name });
		}
	};
	if (definition.Slot === "Machine") {
		pushUpgrade(config.Machines, "Machine", state.Machines);
	} else {
		pushUpgrade(config.Research, "Research", state.Research);
	}
	return out;
}

export function RestockClock(seconds: unknown): string {
	const total = math.max(0, math.floor(tonumber(seconds) ?? 0));
	if (total <= 0) {
		return "READY";
	}
	const hours = math.floor(total / 3600);
	const minutes = math.floor((total % 3600) / 60);
	if (hours > 0) {
		return `${hours}h ${minutes}m`;
	}
	if (minutes > 0) {
		return `${minutes}m`;
	}
	return `${total}s`;
}

export function OfferStock(offer: unknown): { stock: number; stockMax: number; soldOut: boolean; daily: boolean } {
	if (!isTable(offer)) {
		return { stock: 0, stockMax: 1, soldOut: true, daily: false };
	}
	const stockMax = math.max(1, tonumber(offer.StockMax) ?? 1);
	const defaultStock = offer.Purchased === true ? 0 : stockMax;
	const stock = math.clamp(tonumber(offer.Stock) ?? defaultStock, 0, stockMax);
	return {
		stock,
		stockMax,
		soldOut: stock <= 0,
		daily: offer.DailyRefresh === true,
	};
}

export const INSPECT_PAD = 14;
export const INSPECT_BTN_GAP = 8;
export const INSPECT_FOOTER_H = 18;
export const ACTION_BTN = 56;

export function InspectSocketBlock(equipped: unknown, targetCount: unknown, chipRows: unknown, stack?: boolean, tapTarget?: number): number {
	const stacked = stack === true;
	if (truthy(equipped)) {
		return 20;
	}
	const targets = math.max(0, math.floor(tonumber(targetCount) ?? 0));
	if (targets > 0) {
		const rowH = stacked ? (tonumber(tapTarget) ?? 48) + 6 : 42;
		return 18 + math.max(0, math.floor(tonumber(chipRows) ?? 0)) * rowH;
	}
	return 28;
}

export function InspectActionsHeight(stack?: boolean): number {
	return stack === true ? ACTION_BTN * 2 + INSPECT_BTN_GAP : ACTION_BTN;
}

export function InspectPanelHeight(socketBlock: unknown, stack?: boolean): number {
	return (
		INSPECT_PAD * 2 +
		math.max(0, tonumber(socketBlock) ?? 0) +
		INSPECT_BTN_GAP +
		InspectActionsHeight(stack) +
		INSPECT_BTN_GAP +
		INSPECT_FOOTER_H
	);
}

export function UpgradeState(level: unknown, maxLevel: unknown, essence: unknown, cost: unknown): LuaTuple<[boolean, boolean]> {
	const safeLevel = math.max(0, math.floor(tonumber(level) ?? 0));
	const safeMax = math.max(0, math.floor(tonumber(maxLevel) ?? 0));
	const maxed = safeMax > 0 && safeLevel >= safeMax;
	const canUpgrade = !maxed && (tonumber(essence) ?? 0) >= (tonumber(cost) ?? 0);
	return $tuple(canUpgrade, maxed);
}

export function ChipRows(targetCount: unknown, stack?: boolean): number {
	const targets = math.max(0, math.floor(tonumber(targetCount) ?? 0));
	if (targets <= 0) {
		return 0;
	}
	const cols = stack === true ? 2 : 3;
	return math.max(1, math.ceil(targets / cols));
}

export const LOADOUT_EFFECT_KEYS: ReadonlyArray<{ id: string; label: string }> = table.freeze([
	{ id: "Production", label: "Production" },
	{ id: "Capacity", label: "Vault" },
	{ id: "Tap", label: "Overcharge" },
	{ id: "Critical", label: "Critical" },
	{ id: "Automation", label: "Auto" },
	{ id: "Offline", label: "Offline" },
]);

export function LoadoutEffectLines(effects: unknown): Array<{ id: string; label: string; value: number }> {
	const bag = isTable(effects) ? effects : {};
	return LOADOUT_EFFECT_KEYS.map((entry) => ({
		id: entry.id,
		label: entry.label,
		value: tonumber(bag[entry.id]) ?? 0,
	}));
}
