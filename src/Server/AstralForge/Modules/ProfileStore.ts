// ProfileStore: the versioned load path for stored profiles (rewrite 03).
//
//   raw document -> ReadVersion (refuses newer schemas) -> Migrate (ordered, versioned steps on the
//   raw table) -> DataService reconciles the template and sanitizes -> Stamp (current DataVersion)
//
// A migration is a pure step keyed by the DataVersion it upgrades a save *to*; it runs only for
// saves stored below that version, once, in order, before template defaults are filled in (so a
// step can still tell a missing field from a default). The DataVersion field and save shape are
// unchanged; adding a schema change means bumping GameConfig.Game.DataVersion and appending a step.
import ProfileVersionGuard from "./ProfileVersionGuard";

type Dict = Record<string, unknown>;

export interface Migration {
	/** the DataVersion this step upgrades a save to; it runs for saves stored below it */
	readonly to: number;
	readonly name: string;
	readonly run: (this: void, profile: Dict) => void;
}

function bag(profile: Dict, key: string): Dict | undefined {
	const value = profile[key];
	return typeIs(value, "table") ? (value as Dict) : undefined;
}

export const MIGRATIONS: ReadonlyArray<Migration> = table.freeze([
	{
		// v5 replaced the on/off sound, effects and motion toggles with 0..1 sliders: a player who
		// had a toggle off keeps it off as slider 0 (sanitize then derives the toggles back).
		to: 5,
		name: "settings toggles become sliders",
		run: (profile) => {
			const settings = bag(profile, "Settings");
			if (settings === undefined) return;
			if (settings.SoundEffects === false) settings.SoundVolume = 0;
			if (settings.UIEffects === false) settings.EffectsIntensity = 0;
			if (settings.ReducedMotion === true) settings.MotionIntensity = 0;
		},
	},
]);

/** The stored DataVersion (0 when absent); errors on a non-table, an invalid or a newer schema. */
export function ReadVersion(raw: unknown, target: number): number {
	return ProfileVersionGuard.ReadCompatible(raw, target);
}

/** The steps a save stored at `from` needs to reach `target`, in order. */
export function Pending(from: number, target: number, steps: ReadonlyArray<Migration> = MIGRATIONS): Migration[] {
	const out: Migration[] = [];
	for (const step of steps) {
		if (step.to > from && step.to <= target) out.push(step);
	}
	out.sort((a, b) => a.to < b.to);
	return out;
}

/** Runs the pending steps on the raw table in place and returns their names. */
export function Migrate(raw: unknown, from: number, target: number, steps: ReadonlyArray<Migration> = MIGRATIONS): string[] {
	const applied: string[] = [];
	if (!typeIs(raw, "table")) return applied;
	for (const step of Pending(from, target, steps)) {
		step.run(raw as Dict);
		applied.push(step.name);
	}
	return applied;
}

/** Marks a normalized profile as current. */
export function Stamp(profile: Dict, target: number): Dict {
	profile.DataVersion = target;
	return profile;
}
