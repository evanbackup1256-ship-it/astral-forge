// Rarity moments for crate and companion reveals. A thin table on top of the existing reel timing in
// CrateRevealOverlay (spinTime, approach, ScreenFx.forRarity): it only says how big the landing beat is
// and which of the existing shimmers (RainbowGradient, PrismAura, ShimmerText) a drop is allowed to wear.

export interface CrateMoment {
	/** 0 plain, 1 rare, 2 epic, 3 legendary, 4 mythic, 5 ascended */
	tier: number;
	/** seconds the landing ring takes to open */
	ring: number;
	/** ring end radius, px */
	reach: number;
	/** marker flash strength 0..1 */
	flash: number;
	shimmerName: boolean;
	rainbowRim: boolean;
	prism: boolean;
}

const TABLE: ReadonlyArray<CrateMoment> = [
	{ tier: 0, ring: 0, reach: 0, flash: 0.25, shimmerName: false, rainbowRim: false, prism: false },
	{ tier: 1, ring: 0.32, reach: 70, flash: 0.45, shimmerName: false, rainbowRim: false, prism: false },
	{ tier: 2, ring: 0.4, reach: 110, flash: 0.65, shimmerName: true, rainbowRim: false, prism: false },
	{ tier: 3, ring: 0.5, reach: 160, flash: 0.85, shimmerName: true, rainbowRim: true, prism: false },
	{ tier: 4, ring: 0.6, reach: 210, flash: 1, shimmerName: true, rainbowRim: true, prism: false },
	{ tier: 5, ring: 0.7, reach: 260, flash: 1, shimmerName: true, rainbowRim: true, prism: true },
];

/** rank on the overlay LADDER (Common 0 ... Astral 7) to a moment */
export function momentFor(rank: number): CrateMoment {
	const tier = rank <= 1 ? 0 : rank === 2 ? 1 : rank === 3 ? 2 : rank === 4 ? 3 : rank === 5 ? 4 : 5;
	return TABLE[tier];
}

/** 0..1 ring progress to [scale, transparency]; ease matches the overlay's easeOut */
export function ringAt(moment: CrateMoment, seconds: number): LuaTuple<[number, number]> {
	if (moment.ring <= 0) {
		return $tuple(0, 1);
	}
	const x = math.clamp(seconds / moment.ring, 0, 1);
	const k = 1 - (1 - x) ** 3;
	return $tuple(k, 0.2 + x * 0.8);
}
