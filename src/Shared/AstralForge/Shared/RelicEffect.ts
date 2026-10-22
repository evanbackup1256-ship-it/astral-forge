// One calculator for what a relic is worth. Sockets, the companion, the inventory compare line
// and the HUD all ask here, so a level, a star or a bond rank means the same number everywhere.
//
//   effect = BaseEffect * (1 + LevelGrowth * (level - 1)) * (1 + STAR_BONUS * stars) * share
//
// share is 1 for a socketed relic and the companion share (40% + 10% per evolution) for the companion.
export const STAR_BONUS = 0.25;
export const MAX_STARS = 5;

export const COMPANION_SHARE = 0.4;
export const COMPANION_SHARE_PER_EVOLUTION = 0.1;
export const EVOLUTION_RANKS = [3, 6, 10];

interface EffectDefinition {
	BaseEffect?: unknown;
	LevelGrowth?: unknown;
}

function finite(value: unknown, fallback: number): number {
	const n = tonumber(value);
	return n !== undefined && n === n && n !== math.huge && n !== -math.huge ? n : fallback;
}

export function starMultiplier(stars: unknown): number {
	return 1 + STAR_BONUS * math.clamp(math.floor(finite(stars, 0)), 0, MAX_STARS);
}

export function levelMultiplier(definition: EffectDefinition, level: unknown): number {
	return 1 + finite(definition.LevelGrowth, 0) * math.max(0, finite(level, 1) - 1);
}

export function effectAt(definition: EffectDefinition | undefined, level: unknown, stars: unknown, share = 1): number {
	if (definition === undefined) return 0;
	return finite(definition.BaseEffect, 0) * levelMultiplier(definition, level) * starMultiplier(stars) * share;
}

export function evolutionsReached(rank: number): number {
	let step = 0;
	for (const at of EVOLUTION_RANKS) {
		if (rank >= at) step += 1;
	}
	return step;
}

export function companionShare(rank: number): number {
	return COMPANION_SHARE + COMPANION_SHARE_PER_EVOLUTION * evolutionsReached(rank);
}
