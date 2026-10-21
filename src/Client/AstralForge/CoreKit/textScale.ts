// Text size for the whole UI. The player's Text size choice (0..1, M = 0.5) maps into a band per
// surface; Roblox's own text size setting (PreferredTextSize) lifts that floor when "Match Roblox
// text size" is on. The bands are the limits the text-fit and tap-target tests were measured at.

export const TEXT_SCALE_BANDS = {
	touch: { min: 0.92, max: 1.26 },
	desktop: { min: 0.96, max: 1.16 },
} as const;

/** Roblox PreferredTextSize as a multiplier (Medium is the Roblox default = 1). */
export function preferredTextMultiplier(name: string | undefined): number {
	if (name === "Large") return 1.1;
	if (name === "Larger") return 1.18;
	if (name === "Largest") return 1.26;
	return 1;
}

export function resolveTextScale(touch: boolean, choice: number | undefined, followRoblox: boolean, preferred: string | undefined): number {
	const band = touch ? TEXT_SCALE_BANDS.touch : TEXT_SCALE_BANDS.desktop;
	const picked = math.clamp(typeIs(choice, "number") && choice === choice ? choice : 0.5, 0, 1);
	const own = band.min + picked * (band.max - band.min);
	const system = followRoblox ? preferredTextMultiplier(preferred) : 1;
	// never shrink below what the player picked; a bigger Roblox size only raises it
	return math.clamp(math.max(own, system), band.min, band.max);
}
