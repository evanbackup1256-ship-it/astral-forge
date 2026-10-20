const GuiService = game.GetService("GuiService");

// Single source of truth for "reduced motion" outside the React tree.
// True when the Roblox OS setting is on, or the in-game Animation slider is below 30%
// (the same rule MainGame uses for `soft` motion). MainGame pushes the setting in.
let inGameReduced = false;

function osReduced(): boolean {
	const [ok, value] = pcall(() => GuiService.ReducedMotionEnabled);
	return ok && value === true;
}

export function setInGameReducedMotion(value: boolean): void {
	inGameReduced = value;
}

export function isReducedMotion(): boolean {
	return inGameReduced || osReduced();
}

// Settings > Graphics switches that gate non-React effects.
let flashesOn = true;
let celebrationsOn = true;

export function setEffectSwitches(flashes: boolean, celebrations: boolean): void {
	flashesOn = flashes;
	celebrationsOn = celebrations;
}

/** Screen flashes: off with the "Screen flashes" switch or reduced motion. */
export function flashesAllowed(): boolean {
	return flashesOn && !isReducedMotion();
}

/** Confetti and sparkle bursts on big wins ("Celebrations" switch). */
export function celebrationsAllowed(): boolean {
	return celebrationsOn;
}
