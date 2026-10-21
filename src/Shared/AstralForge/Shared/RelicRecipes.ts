// Recipe forging: craft a specific relic instead of hoping a crate drops it. A recipe opens once
// you've found that relic at least once (it's in your codex). Costs are Essence and ore you mine,
// and from Uncommon up you also give a spare relic one rarity lower. Weekly caps per relic and
// overall keep crates worth opening.
//
// Recipes come from the relic definitions, so a new relic gets one without extra data.
// BALANCE: first pass.
import { T } from "./Locale";
import * as WeeklyBoard from "./WeeklyBoard";

type Dict = Record<string, unknown>;

export interface Recipe {
	Essence: number;
	Emberite: number;
	Voidglass: number;
	Starsteel: number;
	SacrificeRarity?: string;
	WeeklyCap: number;
}

export interface Bag {
	Week: number;
	Crafted: Record<string, number>;
}

export interface RecipeDefinition {
	Id: string;
	Name?: string;
	Rarity?: string;
	EssenceBase?: number;
}

export const WEEKLY_TOTAL = 10;

const ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"];

export function rankOf(rarity: unknown): number {
	const index = typeIs(rarity, "string") ? ORDER.indexOf(rarity) : -1;
	return index >= 0 ? index + 1 : 1;
}

export function recipeFor(definition: RecipeDefinition): Recipe {
	const rank = rankOf(definition.Rarity);
	const base = math.max(1, tonumber(definition.EssenceBase) ?? 20);
	return {
		Essence: math.floor(base * 25),
		Emberite: 10 * rank,
		Voidglass: rank >= 3 ? 4 * rank : 0,
		Starsteel: rank >= 5 ? 2 * rank : 0,
		SacrificeRarity: rank >= 2 ? ORDER[rank - 2] : undefined,
		WeeklyCap: rank >= 5 ? 1 : 3,
	};
}

function int(value: unknown): number {
	const n = tonumber(value);
	return n !== undefined && n === n && n > 0 && n < math.huge ? math.floor(n) : 0;
}

// load-time repair: keeps the stored week as it is (the rollover happens lazily in ensure),
// drops junk counts, rebuilds a malformed bag
export function repair(raw: unknown): Bag {
	const input = typeIs(raw, "table") ? (raw as Dict) : {};
	const crafted: Record<string, number> = {};
	if (typeIs(input.Crafted, "table")) {
		for (const [id, count] of pairs(input.Crafted as Dict)) {
			if (typeIs(id, "string") && int(count) > 0) {
				crafted[id] = int(count);
			}
		}
	}
	return { Week: int(input.Week), Crafted: crafted };
}

// a stale week resets the counts; anything malformed starts clean
export function ensure(raw: unknown, now: number): Bag {
	const week = WeeklyBoard.weekOf(now);
	const input = typeIs(raw, "table") ? (raw as Dict) : {};
	const crafted: Record<string, number> = {};
	if (int(input.Week) === week && typeIs(input.Crafted, "table")) {
		for (const [id, count] of pairs(input.Crafted as Dict)) {
			if (typeIs(id, "string") && int(count) > 0) {
				crafted[id] = int(count);
			}
		}
	}
	return { Week: week, Crafted: crafted };
}

export function craftedThisWeek(bag: Bag): number {
	let total = 0;
	for (const [, count] of pairs(bag.Crafted)) {
		total += count;
	}
	return total;
}

export interface Plan {
	Recipe: Recipe;
	SacrificeUid?: string;
}

// checks everything without changing anything. `rarityOf` maps a definition id to its rarity.
export function plan(
	profile: Dict,
	definition: RecipeDefinition | undefined,
	sacrificeUid: unknown,
	now: number,
	rarityOf: (id: unknown) => string | undefined,
	inventoryLimit: number,
): LuaTuple<[Plan | undefined, string]> {
	if (definition === undefined) {
		return $tuple(undefined, T("RelicRecipes.ThereSNoRecipeFor"));
	}
	const items = (typeIs(profile.Items, "table") ? profile.Items : {}) as Dict;
	const discovered = typeIs(items.Discovered, "table") ? (items.Discovered as Dict) : {};
	if (discovered[definition.Id] !== true) {
		return $tuple(undefined, T("RelicRecipes.FindOneFirst", definition.Name ?? definition.Id));
	}
	const bag = ensure(items.Recipes, now);
	const recipe = recipeFor(definition);
	if (craftedThisWeek(bag) >= WEEKLY_TOTAL) {
		return $tuple(undefined, T("RelicRecipes.TheBenchIsDoneFor", WEEKLY_TOTAL));
	}
	if ((bag.Crafted[definition.Id] ?? 0) >= recipe.WeeklyCap) {
		return $tuple(undefined, T("RelicRecipes.YouVeForgedThatOne", recipe.WeeklyCap));
	}
	const inventory = (typeIs(items.Inventory, "table") ? items.Inventory : {}) as Dict;
	let count = 0;
	for (const _ of pairs(inventory)) {
		count += 1;
	}
	let sacrifice: string | undefined;
	if (recipe.SacrificeRarity !== undefined) {
		const instance = typeIs(sacrificeUid, "string") ? inventory[sacrificeUid] : undefined;
		if (!typeIs(instance, "table")) {
			return $tuple(undefined, T("RelicRecipes.PickASRelicToGive", recipe.SacrificeRarity.lower()));
		}
		if (rarityOf((instance as Dict).DefinitionId) !== recipe.SacrificeRarity) {
			return $tuple(undefined, T("RelicRecipes.ItHasToBeS", recipe.SacrificeRarity.lower()));
		}
		if ((instance as Dict).Locked === true) {
			return $tuple(undefined, T("RelicRecipes.ThatRelicIsProtected"));
		}
		const equipped = typeIs(items.Equipped, "table") ? (items.Equipped as Dict) : {};
		for (const [, uid] of pairs(equipped)) {
			if (uid === sacrificeUid) {
				return $tuple(undefined, T("RelicRecipes.DetachItFirst"));
			}
		}
		sacrifice = sacrificeUid as string;
	} else if (count >= inventoryLimit) {
		return $tuple(undefined, T("RelicRecipes.YourRelicBagIsFull"));
	}
	const ore = (typeIs(profile.Ore, "table") ? profile.Ore : {}) as Dict;
	const short: string[] = [];
	if (int(items.Essence) < recipe.Essence) short.push(`${recipe.Essence - int(items.Essence)} Essence`);
	if (int(ore.Emberite) < recipe.Emberite) short.push(`${recipe.Emberite - int(ore.Emberite)} Emberite`);
	if (int(ore.Voidglass) < recipe.Voidglass) short.push(`${recipe.Voidglass - int(ore.Voidglass)} Voidglass`);
	if (int(ore.Starsteel) < recipe.Starsteel) short.push(`${recipe.Starsteel - int(ore.Starsteel)} Starsteel`);
	if (short.size() > 0) {
		return $tuple(undefined, T("RelicRecipes.YouNeedS", short.join(", ")));
	}
	return $tuple({ Recipe: recipe, SacrificeUid: sacrifice }, "");
}

// spends the plan's costs and records the craft. The caller then creates the relic.
export function pay(profile: Dict, definitionId: string, chosen: Plan, now: number): void {
	const items = profile.Items as Dict;
	const ore = profile.Ore as Dict;
	const recipe = chosen.Recipe;
	items.Essence = int(items.Essence) - recipe.Essence;
	ore.Emberite = int(ore.Emberite) - recipe.Emberite;
	ore.Voidglass = int(ore.Voidglass) - recipe.Voidglass;
	ore.Starsteel = int(ore.Starsteel) - recipe.Starsteel;
	if (chosen.SacrificeUid !== undefined) {
		(items.Inventory as Dict)[chosen.SacrificeUid] = undefined;
	}
	const bag = ensure(items.Recipes, now);
	bag.Crafted[definitionId] = (bag.Crafted[definitionId] ?? 0) + 1;
	items.Recipes = bag;
}
