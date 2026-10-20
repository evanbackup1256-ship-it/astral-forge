// Profile style: a nameplate accent and a profile frame each player picks for themselves.
// Pure and shared: the server validates every choice with these rules, and the client uses the
// same catalog to draw the picker. Stored in the save as Cosmetics.ProfileAccent / ProfileFrame;
// missing or unknown values fall back to the defaults, so old saves load unchanged.

export interface StyleUnlock {
	/** "Free" is always available; "Rebirths" needs that many lifetime rebirths. */
	Kind: "Free" | "Rebirths";
	Target: number;
}

export interface AccentOption {
	Id: string;
	Name: string;
	/** RGB 0-255 so the catalog stays plain data on both sides. */
	Rgb: [number, number, number];
	Unlock: StyleUnlock;
}

export interface FrameOption {
	Id: string;
	Name: string;
	Description: string;
	/** Stroke thickness in px for the frame ring. */
	Thickness: number;
	/** Whether the ring uses the animated gradient treatment. */
	Gradient: boolean;
	Unlock: StyleUnlock;
}

export interface ProfileStyleState {
	Accent: string;
	Frame: string;
}

export const DEFAULT_ACCENT = "Cyan";
export const DEFAULT_FRAME = "Plain";

export const ACCENTS: ReadonlyArray<AccentOption> = [
	{ Id: "Cyan", Name: "Forge Cyan", Rgb: [86, 214, 255], Unlock: { Kind: "Free", Target: 0 } },
	{ Id: "Mint", Name: "Mint", Rgb: [104, 232, 170], Unlock: { Kind: "Free", Target: 0 } },
	{ Id: "Mango", Name: "Mango", Rgb: [255, 184, 82], Unlock: { Kind: "Free", Target: 0 } },
	{ Id: "Violet", Name: "Violet", Rgb: [170, 128, 255], Unlock: { Kind: "Rebirths", Target: 1 } },
	{ Id: "Coral", Name: "Coral", Rgb: [255, 118, 108], Unlock: { Kind: "Rebirths", Target: 5 } },
	{ Id: "Pink", Name: "Nova Pink", Rgb: [255, 120, 200], Unlock: { Kind: "Rebirths", Target: 15 } },
	{ Id: "Ice", Name: "Glacier", Rgb: [168, 226, 255], Unlock: { Kind: "Rebirths", Target: 2 } },
	{ Id: "Lime", Name: "Lime", Rgb: [190, 240, 96], Unlock: { Kind: "Rebirths", Target: 8 } },
	{ Id: "Ember", Name: "Ember", Rgb: [255, 140, 56], Unlock: { Kind: "Rebirths", Target: 10 } },
	{ Id: "Teal", Name: "Deep Teal", Rgb: [64, 196, 186], Unlock: { Kind: "Rebirths", Target: 20 } },
	{ Id: "Crimson", Name: "Crimson", Rgb: [228, 64, 84], Unlock: { Kind: "Rebirths", Target: 35 } },
	{ Id: "Gold", Name: "Astral Gold", Rgb: [255, 214, 102], Unlock: { Kind: "Rebirths", Target: 50 } },
	{ Id: "Silver", Name: "Starlight", Rgb: [226, 232, 244], Unlock: { Kind: "Rebirths", Target: 75 } },
	{ Id: "Void", Name: "Void Indigo", Rgb: [120, 102, 255], Unlock: { Kind: "Rebirths", Target: 100 } },
];

export const FRAMES: ReadonlyArray<FrameOption> = [
	{ Id: "Plain", Name: "Plain", Description: "A clean, thin ring.", Thickness: 1, Gradient: false, Unlock: { Kind: "Free", Target: 0 } },
	{ Id: "Bold", Name: "Bold", Description: "A thicker ring in your accent.", Thickness: 2, Gradient: false, Unlock: { Kind: "Rebirths", Target: 3 } },
	{ Id: "Double", Name: "Heavy", Description: "A thick ring that reads from across the room.", Thickness: 3, Gradient: false, Unlock: { Kind: "Rebirths", Target: 10 } },
	{ Id: "Prism", Name: "Prism", Description: "A shifting gradient ring.", Thickness: 2, Gradient: true, Unlock: { Kind: "Rebirths", Target: 25 } },
	{ Id: "Forged", Name: "Forged", Description: "A heavy gradient ring for long-time players.", Thickness: 3, Gradient: true, Unlock: { Kind: "Rebirths", Target: 60 } },
];

export function findAccent(id: unknown): AccentOption | undefined {
	for (const option of ACCENTS) {
		if (option.Id === id) {
			return option;
		}
	}
	return undefined;
}

export function findFrame(id: unknown): FrameOption | undefined {
	for (const option of FRAMES) {
		if (option.Id === id) {
			return option;
		}
	}
	return undefined;
}

export function isUnlocked(unlock: StyleUnlock, rebirths: unknown): boolean {
	if (unlock.Kind === "Free") {
		return true;
	}
	const count = typeIs(rebirths, "number") && rebirths === rebirths ? rebirths : 0;
	return count >= unlock.Target;
}

/** Reads a save's Cosmetics bag; unknown or missing ids become the defaults. */
export function read(cosmetics: unknown): ProfileStyleState {
	const bag = typeIs(cosmetics, "table") ? (cosmetics as Record<string, unknown>) : {};
	const accent = findAccent(bag.ProfileAccent) !== undefined ? (bag.ProfileAccent as string) : DEFAULT_ACCENT;
	const frame = findFrame(bag.ProfileFrame) !== undefined ? (bag.ProfileFrame as string) : DEFAULT_FRAME;
	return { Accent: accent, Frame: frame };
}

/**
 * Validates a requested change. Either field may be omitted to keep the current choice.
 * Returns the new state, or an error message the player can read.
 */
export function validate(
	current: ProfileStyleState,
	requestedAccent: unknown,
	requestedFrame: unknown,
	rebirths: unknown,
): LuaTuple<[ProfileStyleState | undefined, string | undefined]> {
	let accent = current.Accent;
	let frame = current.Frame;
	if (requestedAccent !== undefined) {
		const option = findAccent(requestedAccent);
		if (option === undefined) {
			return $tuple(undefined, "That accent does not exist.");
		}
		if (!isUnlocked(option.Unlock, rebirths)) {
			return $tuple(undefined, `${option.Name} unlocks at ${option.Unlock.Target} rebirths.`);
		}
		accent = option.Id;
	}
	if (requestedFrame !== undefined) {
		const option = findFrame(requestedFrame);
		if (option === undefined) {
			return $tuple(undefined, "That frame does not exist.");
		}
		if (!isUnlocked(option.Unlock, rebirths)) {
			return $tuple(undefined, `${option.Name} unlocks at ${option.Unlock.Target} rebirths.`);
		}
		frame = option.Id;
	}
	return $tuple({ Accent: accent, Frame: frame }, undefined);
}

export function accentColor(id: unknown): Color3 {
	const option = findAccent(id) ?? findAccent(DEFAULT_ACCENT)!;
	return Color3.fromRGB(option.Rgb[0], option.Rgb[1], option.Rgb[2]);
}

export interface PlayerProfileStyle {
	/** Only set when the player picked a non-default accent, so default looks stay unchanged. */
	accent?: Color3;
	/** Only set when the player picked a non-default frame. */
	frame?: FrameOption;
}

/** Reads the published ProfileAccent / ProfileFrame attributes of any player. */
export function fromPlayer(player: Player | undefined): PlayerProfileStyle {
	if (player === undefined) {
		return {};
	}
	const accentId = player.GetAttribute("ProfileAccent");
	const frameId = player.GetAttribute("ProfileFrame");
	const accent = accentId !== DEFAULT_ACCENT ? findAccent(accentId) : undefined;
	const frame = frameId !== DEFAULT_FRAME ? findFrame(frameId) : undefined;
	return {
		accent: accent !== undefined ? Color3.fromRGB(accent.Rgb[0], accent.Rgb[1], accent.Rgb[2]) : undefined,
		frame,
	};
}
