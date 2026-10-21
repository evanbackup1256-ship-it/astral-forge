// Profile style: a nameplate accent and a profile frame each player picks for themselves.
// Pure and shared: the server validates every choice with these rules, and the client uses the
// same catalog to draw the picker. Stored in the save as Cosmetics.ProfileAccent / ProfileFrame;
// missing or unknown values fall back to the defaults, so old saves load unchanged.

/**
 * What earns a cosmetic. "Free" is always available; every other kind needs Target of that
 * lifetime milestone (see MilestoneFacts). Titles in GameConfig.Operations.Titles use the same kinds.
 */
export type UnlockKind = "Free" | "Rebirths" | "Crates" | "Rigs" | "Guild" | "Trades" | "Seasons" | "Goals" | "Visits" | "Taps";

export interface StyleUnlock {
	Kind: UnlockKind;
	Target: number;
}

/** Lifetime counts the unlocks are checked against. Built from the save on the server (factsOf). */
export interface MilestoneFacts {
	Rebirths: number;
	Crates: number;
	Rigs: number;
	Guild: number;
	Trades: number;
	Seasons: number;
	Goals: number;
	Visits: number;
	Taps: number;
}

const count = (value: unknown) => (typeIs(value, "number") && value === value ? math.max(0, math.floor(value)) : 0);
const bag = (value: unknown) => (typeIs(value, "table") ? (value as Record<string, unknown>) : ({} as Record<string, unknown>));

/** Reads the milestone counts out of a save (or out of a snapshot's Cosmetics.Facts). */
export function factsOf(profile: unknown): MilestoneFacts {
	const save = bag(profile);
	const stats = bag(save.Stats);
	let rigs = 0;
	for (const [, lit] of pairs(bag(bag(bag(save.Items).Rigs).Lit))) {
		if (lit !== false) {
			rigs += 1;
		}
	}
	const goals = bag(save.Flags).FirstGoals;
	const guildId = bag(save.Guild).Id;
	return {
		Rebirths: count(save.Rebirths),
		Crates: count(stats.CratesOpened),
		Rigs: rigs,
		Guild: typeIs(guildId, "string") && guildId !== "" ? 1 : 0,
		Trades: count(stats.TradesDone),
		Seasons: count(stats.SeasonTiers),
		Goals: typeIs(goals, "table") ? (goals as unknown[]).size() : 0,
		Visits: count(stats.Joins),
		Taps: count(stats.Taps),
	};
}

/** Snapshot copy of the facts; the client reads it back with readFacts. */
export function readFacts(raw: unknown): MilestoneFacts {
	const facts = bag(raw);
	return {
		Rebirths: count(facts.Rebirths),
		Crates: count(facts.Crates),
		Rigs: count(facts.Rigs),
		Guild: count(facts.Guild),
		Trades: count(facts.Trades),
		Seasons: count(facts.Seasons),
		Goals: count(facts.Goals),
		Visits: count(facts.Visits),
		Taps: count(facts.Taps),
	};
}

/** Short "what it takes" line, e.g. "Open 50 crates". */
export function unlockText(unlock: StyleUnlock): string {
	const n = unlock.Target;
	const plural = (one: string, many: string) => (n === 1 ? one : many);
	switch (unlock.Kind) {
		case "Free":
			return "Free";
		case "Rebirths":
			return `${n} ${plural("rebirth", "rebirths")}`;
		case "Crates":
			return `Open ${n} ${plural("crate", "crates")}`;
		case "Rigs":
			return `Light ${n} relic ${plural("rig", "rigs")}`;
		case "Guild":
			return "Join a guild";
		case "Trades":
			return `Finish ${n} ${plural("trade", "trades")}`;
		case "Seasons":
			return `Claim ${n} season ${plural("tier", "tiers")}`;
		case "Goals":
			return "Finish the first goals";
		case "Visits":
			return `Visit ${n} times`;
		case "Taps":
			return `Tap ${n} times`;
	}
	return "";
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
	{ Id: "Sky", Name: "Sky", Rgb: [120, 180, 255], Unlock: { Kind: "Free", Target: 0 } },
	{ Id: "Rose", Name: "Rose", Rgb: [244, 150, 170], Unlock: { Kind: "Rebirths", Target: 3 } },
	{ Id: "Moss", Name: "Moss", Rgb: [140, 186, 110], Unlock: { Kind: "Rebirths", Target: 12 } },
	{ Id: "Lilac", Name: "Lilac", Rgb: [200, 168, 240], Unlock: { Kind: "Rebirths", Target: 30 } },
	{ Id: "Solar", Name: "Solar Flare", Rgb: [255, 160, 40], Unlock: { Kind: "Rebirths", Target: 150 } },
	// day-a batch 31: fills the 4/6/40 gaps and gives very long runs something to chase
	{ Id: "SeaGlass", Name: "Sea Glass", Rgb: [150, 220, 200], Unlock: { Kind: "Rebirths", Target: 4 } },
	{ Id: "Copper", Name: "Copper", Rgb: [214, 132, 92], Unlock: { Kind: "Rebirths", Target: 6 } },
	{ Id: "Plum", Name: "Plum", Rgb: [196, 108, 186], Unlock: { Kind: "Rebirths", Target: 40 } },
	{ Id: "Nebula", Name: "Nebula Blue", Rgb: [92, 132, 240], Unlock: { Kind: "Rebirths", Target: 200 } },
	{ Id: "Supernova", Name: "Supernova", Rgb: [255, 236, 180], Unlock: { Kind: "Rebirths", Target: 300 } },
	// day-a batch 38: earned from milestones other than rebirths
	{ Id: "Brass", Name: "Key Brass", Rgb: [222, 178, 96], Unlock: { Kind: "Crates", Target: 25 } },
	{ Id: "RigGlow", Name: "Rig Glow", Rgb: [110, 238, 255], Unlock: { Kind: "Rigs", Target: 1 } },
	{ Id: "Banner", Name: "Banner Green", Rgb: [86, 200, 120], Unlock: { Kind: "Guild", Target: 1 } },
	{ Id: "Market", Name: "Market Amber", Rgb: [255, 196, 120], Unlock: { Kind: "Trades", Target: 5 } },
	{ Id: "Frontier", Name: "Frontier Blue", Rgb: [76, 150, 230], Unlock: { Kind: "Seasons", Target: 5 } },
	{ Id: "FreshPaint", Name: "Fresh Paint", Rgb: [255, 250, 236], Unlock: { Kind: "Goals", Target: 5 } },
	{ Id: "NightShift", Name: "Night Shift", Rgb: [90, 100, 170], Unlock: { Kind: "Visits", Target: 20 } },
	{ Id: "Blister", Name: "Blister Pink", Rgb: [255, 150, 160], Unlock: { Kind: "Taps", Target: 5000 } },
];

export const FRAMES: ReadonlyArray<FrameOption> = [
	{ Id: "Plain", Name: "Plain", Description: "A clean, thin ring.", Thickness: 1, Gradient: false, Unlock: { Kind: "Free", Target: 0 } },
	{
		Id: "Bold",
		Name: "Bold",
		Description: "A thicker ring in your accent.",
		Thickness: 2,
		Gradient: false,
		Unlock: { Kind: "Rebirths", Target: 3 },
	},
	{
		Id: "Double",
		Name: "Heavy",
		Description: "A thick ring that reads from across the room.",
		Thickness: 3,
		Gradient: false,
		Unlock: { Kind: "Rebirths", Target: 10 },
	},
	{
		Id: "Glint",
		Name: "Glint",
		Description: "A thin gradient ring that catches the light.",
		Thickness: 1,
		Gradient: true,
		Unlock: { Kind: "Rebirths", Target: 15 },
	},
	{
		Id: "Prism",
		Name: "Prism",
		Description: "A shifting gradient ring.",
		Thickness: 2,
		Gradient: true,
		Unlock: { Kind: "Rebirths", Target: 25 },
	},
	{
		Id: "Forged",
		Name: "Forged",
		Description: "A heavy gradient ring for long-time players.",
		Thickness: 3,
		Gradient: true,
		Unlock: { Kind: "Rebirths", Target: 60 },
	},
	// day-a batch 38: earned from milestones other than rebirths
	{
		Id: "Riveted",
		Name: "Riveted",
		Description: "A thick ring for people who open a lot of crates.",
		Thickness: 2,
		Gradient: false,
		Unlock: { Kind: "Crates", Target: 100 },
	},
	{
		Id: "Rigwork",
		Name: "Rigwork",
		Description: "A gradient ring for lighting your relic rigs.",
		Thickness: 2,
		Gradient: true,
		Unlock: { Kind: "Rigs", Target: 5 },
	},
	{
		Id: "GuildBand",
		Name: "Guild Band",
		Description: "A thin ring you get for joining a guild.",
		Thickness: 1,
		Gradient: false,
		Unlock: { Kind: "Guild", Target: 1 },
	},
	{
		Id: "Handshake",
		Name: "Handshake",
		Description: "A gradient ring for finishing 25 trades.",
		Thickness: 1,
		Gradient: true,
		Unlock: { Kind: "Trades", Target: 25 },
	},
	{
		Id: "SeasonStripe",
		Name: "Season Stripe",
		Description: "A heavy ring for sticking with the season.",
		Thickness: 3,
		Gradient: false,
		Unlock: { Kind: "Seasons", Target: 20 },
	},
	{
		Id: "StarterRing",
		Name: "Clock-In",
		Description: "A bold ring for finishing the first goals.",
		Thickness: 2,
		Gradient: false,
		Unlock: { Kind: "Goals", Target: 5 },
	},
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

/** Facts may be a plain rebirth count (older callers) or a full MilestoneFacts. */
export function progressOf(unlock: StyleUnlock, facts: MilestoneFacts | number): number {
	if (unlock.Kind === "Free") {
		return unlock.Target;
	}
	if (typeIs(facts, "number")) {
		return unlock.Kind === "Rebirths" ? count(facts) : 0;
	}
	return facts[unlock.Kind];
}

export function isUnlocked(unlock: StyleUnlock, facts: MilestoneFacts | number): boolean {
	return unlock.Kind === "Free" || progressOf(unlock, facts) >= unlock.Target;
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
	facts: MilestoneFacts | number,
): LuaTuple<[ProfileStyleState | undefined, string | undefined]> {
	let accent = current.Accent;
	let frame = current.Frame;
	if (requestedAccent !== undefined) {
		const option = findAccent(requestedAccent);
		if (option === undefined) {
			return $tuple(undefined, "That accent does not exist.");
		}
		if (!isUnlocked(option.Unlock, facts)) {
			return $tuple(undefined, `${option.Name} is still locked: ${unlockText(option.Unlock)}.`);
		}
		accent = option.Id;
	}
	if (requestedFrame !== undefined) {
		const option = findFrame(requestedFrame);
		if (option === undefined) {
			return $tuple(undefined, "That frame does not exist.");
		}
		if (!isUnlocked(option.Unlock, facts)) {
			return $tuple(undefined, `${option.Name} is still locked: ${unlockText(option.Unlock)}.`);
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
