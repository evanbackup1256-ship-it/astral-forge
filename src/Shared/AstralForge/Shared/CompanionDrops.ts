// Purpose: the companion entries in the crate loot tables. A crate roll that lands on a rarity with a
// companion entry gets one extra draw against that entry's chance; a hit grants the companion once.
// The item roll itself (odds, pity, slots) is untouched, so old saves and crate math stay the same.

export interface CompanionDrop {
	Key: string;
	Name: string;
	Rarity: "Rare" | "Epic" | "Legendary" | "Mythic" | "Celestial";
	/** chance per crate roll that landed on this rarity */
	Chance: number;
}

// Rough odds per Horizon Crate open (Rare 42%, Epic 22%, Legendary 7%, Mythic 1%, Celestial 0.3%):
// Cinder or Frostlet ~1 in 600 opens each, Tidepup ~1 in 900, Brass Owl ~1 in 700,
// Lumen ~1 in 2,500, Voidmote ~1 in 6,700.
export const COMPANION_DROPS: ReadonlyArray<CompanionDrop> = table.freeze([
	table.freeze({ Key: "Cinder", Name: "Cinder", Rarity: "Rare", Chance: 0.004 }),
	table.freeze({ Key: "Frostlet", Name: "Frostlet", Rarity: "Rare", Chance: 0.004 }),
	table.freeze({ Key: "Tidepup", Name: "Tidepup", Rarity: "Epic", Chance: 0.005 }),
	table.freeze({ Key: "BrassOwl", Name: "Brass Owl", Rarity: "Legendary", Chance: 0.02 }),
	table.freeze({ Key: "Lumen", Name: "Lumen", Rarity: "Mythic", Chance: 0.04 }),
	table.freeze({ Key: "Voidmote", Name: "Voidmote", Rarity: "Celestial", Chance: 0.05 }),
]) as ReadonlyArray<CompanionDrop>;

export function isCompanionKey(key: unknown): key is string {
	return typeIs(key, "string") && COMPANION_DROPS.some((drop) => drop.Key === key);
}

/** The owned set on a profile. Optional on old saves: created empty the first time it's needed. */
export function ensureOwned(profile: Record<string, unknown>): Record<string, boolean> {
	const current = profile.Companions;
	if (typeIs(current, "table")) {
		return current as Record<string, boolean>;
	}
	const fresh: Record<string, boolean> = {};
	profile.Companions = fresh;
	return fresh;
}

/** A read-only copy for the client snapshot: only known keys, only `true`. */
export function publicOwned(raw: unknown): Record<string, boolean> {
	const out: Record<string, boolean> = {};
	if (typeIs(raw, "table")) {
		for (const drop of COMPANION_DROPS) {
			if ((raw as Record<string, unknown>)[drop.Key] === true) {
				out[drop.Key] = true;
			}
		}
	}
	return out;
}

/**
 * One draw for the roll's rarity. `draw` returns a number in [0, 1). Companions already owned are
 * skipped, so a hit is always new. Returns the companion key, or undefined.
 */
export function rollCompanion(rarity: string, owned: Record<string, boolean>, draw: () => number): string | undefined {
	let pool = 0;
	for (const drop of COMPANION_DROPS) {
		if (drop.Rarity === rarity && owned[drop.Key] !== true) {
			pool += drop.Chance;
		}
	}
	if (pool <= 0) {
		return undefined;
	}
	let u = draw();
	if (u >= pool) {
		return undefined;
	}
	for (const drop of COMPANION_DROPS) {
		if (drop.Rarity === rarity && owned[drop.Key] !== true) {
			if (u < drop.Chance) {
				return drop.Key;
			}
			u -= drop.Chance;
		}
	}
	return undefined;
}

export function dropOf(key: unknown): CompanionDrop | undefined {
	return COMPANION_DROPS.find((drop) => drop.Key === key);
}
