// Forge journal: chapters read from the profile the server already sends.
import RelicRigs from "../../../Shared/AstralForge/Shared/RelicRigs";

const HOUR = 3600;

type Reader = (state: unknown) => number;

interface JourneyState {
	Stats?: Record<string, unknown>;
	Rebirths?: unknown;
	Domain?: { Rank?: unknown };
}

function stat(state: unknown, key: string): number {
	const stats = typeIs(state, "table") ? (state as JourneyState).Stats : undefined;
	const value = typeIs(stats, "table") ? tonumber(stats[key]) : undefined;
	return math.max(0, math.floor(value ?? 0));
}

const rebirths: Reader = (state) =>
	math.max(0, math.floor(tonumber(typeIs(state, "table") ? (state as JourneyState).Rebirths : undefined) ?? 0));

const domainRank: Reader = (state) => {
	const domain = typeIs(state, "table") ? (state as JourneyState).Domain : undefined;
	return math.max(0, math.floor(tonumber(typeIs(domain, "table") ? domain.Rank : undefined) ?? 0));
};

function statReader(key: string): Reader {
	return (state) => stat(state, key);
}

const rigsLit: Reader = (state) => {
	const items = typeIs(state, "table") ? (state as { Items?: { Rigs?: unknown } }).Items : undefined;
	return RelicRigs.litCount(typeIs(items, "table") ? items.Rigs : undefined);
};

export interface Chapter {
	Id: string;
	Title: string;
	Line: string;
	Target: number;
	Unit: string;
	Scale?: number;
	Read: Reader;
}

// prettier-ignore
export const CHAPTERS: ReadonlyArray<Chapter> = table.freeze([
	{ Id: "spark", Title: "First spark", Line: "Bought the first machine.", Target: 1, Unit: "machine", Read: statReader("MachinesBought") },
	{ Id: "hands", Title: "Steady hands", Line: "Struck the forge 500 times.", Target: 500, Unit: "taps", Read: statReader("Taps") },
	{ Id: "orders", Title: "Order book", Line: "Filled ten work orders.", Target: 10, Unit: "orders", Read: statReader("OrdersCompleted") },
	{ Id: "reborn", Title: "Reborn", Line: "Melted it all down once.", Target: 1, Unit: "rebirth", Read: rebirths },
	{ Id: "crates", Title: "Deep vault", Line: "Opened 25 crates.", Target: 25, Unit: "crates", Read: statReader("CratesOpened") },
	{ Id: "scrap", Title: "Scrapper", Line: "Salvaged 50 pieces.", Target: 50, Unit: "salvaged", Read: statReader("ItemsSalvaged") },
	{ Id: "shift", Title: "Night shift", Line: "Five hours at the anvil.", Target: 5 * HOUR, Unit: "hours", Scale: HOUR, Read: statReader("PlayTime") },
	{ Id: "ten", Title: "Ten lives", Line: "Rebirthed ten times.", Target: 10, Unit: "rebirths", Read: rebirths },
	{ Id: "gate", Title: "Gatekeeper", Line: "Opened the first domain gate.", Target: 1, Unit: "gate", Read: domainRank },
	{ Id: "warden", Title: "Warden breaker", Line: "Beat five wardens.", Target: 5, Unit: "wardens", Read: statReader("WardenDefeats") },
	{ Id: "haul", Title: "Long haul", Line: "A full day of forging.", Target: 24 * HOUR, Unit: "hours", Scale: HOUR, Read: statReader("PlayTime") },
	{ Id: "fifty", Title: "Fifty lives", Line: "Rebirthed fifty times.", Target: 50, Unit: "rebirths", Read: rebirths },
	{ Id: "rig", Title: "Two parts", Line: "Lit a relic rig.", Target: 1, Unit: "rig", Read: rigsLit },
	{ Id: "bench", Title: "Full bench", Line: "Lit every relic rig.", Target: RelicRigs.COUNT, Unit: "rigs", Read: rigsLit },
]);

export interface Entry {
	Id: string;
	Title: string;
	Line: string;
	Done: boolean;
	Have: number;
	Target: number;
	Unit: string;
	Progress: number;
}

export function Build(state: unknown): { Done: Entry[]; Next?: Entry; Count: number; Total: number } {
	const done = new Array<Entry>();
	let nextEntry: Entry | undefined;
	for (const chapter of CHAPTERS) {
		const scale = chapter.Scale ?? 1;
		const raw = chapter.Read(state);
		const entry: Entry = {
			Id: chapter.Id,
			Title: chapter.Title,
			Line: chapter.Line,
			Done: raw >= chapter.Target,
			Have: math.floor(math.min(raw, chapter.Target) / scale),
			Target: math.floor(chapter.Target / scale),
			Unit: chapter.Unit,
			Progress: math.clamp(raw / chapter.Target, 0, 1),
		};
		if (entry.Done) {
			done.push(entry);
		} else if (nextEntry === undefined || entry.Progress > nextEntry.Progress) {
			nextEntry = entry;
		}
	}
	return { Done: done, Next: nextEntry, Count: done.size(), Total: CHAPTERS.size() };
}
