// Purpose: the weekly Flux board. A week runs Monday 00:00 UTC to the next Monday; a player's score
// is the Flux they made since their first tick of the week (LifetimeCash minus where it stood then).
// The top 100 of a finished week are paid the next time they play.
// Owner: gameplay. Dependencies: OmegaMath.
import OmegaMath = require("./OmegaMath");

export const WEEK_SECONDS = 7 * 86400;
// the Unix epoch fell on a Thursday; shift by four days so weeks turn over on Monday
const MONDAY_OFFSET = 4 * 86400;
export const BOARD_ID = "Weekly";
export const PAID_RANKS = 100;

export interface WeeklyBag {
	Week: number;
	Base: number | string;
	ClaimedWeek: number;
}

export interface RewardTier {
	upTo: number;
	label: string;
	reward: { Cores: number; Stardust: number };
}

export const TIERS: readonly RewardTier[] = table.freeze([
	{ upTo: 1, label: "#1", reward: { Cores: 25, Stardust: 600 } },
	{ upTo: 3, label: "#2 to #3", reward: { Cores: 18, Stardust: 400 } },
	{ upTo: 10, label: "#4 to #10", reward: { Cores: 12, Stardust: 250 } },
	{ upTo: 50, label: "#11 to #50", reward: { Cores: 6, Stardust: 120 } },
	{ upTo: PAID_RANKS, label: "#51 to #100", reward: { Cores: 3, Stardust: 60 } },
]);

export function weekOf(now: number): number {
	return math.floor((now - MONDAY_OFFSET) / WEEK_SECONDS);
}

export function weekEndsAt(week: number): number {
	return (week + 1) * WEEK_SECONDS + MONDAY_OFFSET;
}

export function storeName(base: string, week: number): string {
	return base + "_W" + tostring(week);
}

export function tierFor(rank: number): RewardTier | undefined {
	if (rank < 1 || rank !== rank) {
		return undefined;
	}
	return TIERS.find((tier) => rank <= tier.upTo);
}

function validBase(value: unknown): boolean {
	return (typeIs(value, "number") && value === value && value >= 0) || typeIs(value, "string");
}

// Brings a saved bag up to this week. Returns true when it changed. Read the bag with `scoreOf`.
export function ensure(profile: { WeeklyBoard?: unknown; LifetimeCash?: unknown }, now: number): boolean {
	const week = weekOf(now);
	const raw = profile.WeeklyBoard;
	const bag = (typeIs(raw, "table") ? raw : {}) as Partial<WeeklyBag>;
	const claimed = math.max(0, math.floor(tonumber(bag.ClaimedWeek) ?? 0));
	if (typeIs(raw, "table") && bag.Week === week && validBase(bag.Base) && bag.ClaimedWeek === claimed) {
		return false;
	}
	profile.WeeklyBoard = {
		Week: week,
		// a new week (or a damaged bag) starts counting from today's lifetime total
		Base: bag.Week === week && validBase(bag.Base) ? bag.Base! : (profile.LifetimeCash as number | string) ?? 0,
		// a bag that never started a week (the template's Week is -1) has nothing to collect from before it
		ClaimedWeek: typeIs(bag.Week, "number") && bag.Week >= 0 ? claimed : week - 1,
	};
	return true;
}

export function scoreOf(profile: { WeeklyBoard?: unknown; LifetimeCash?: unknown }, now: number): number | string {
	const bag = profile.WeeklyBoard as Partial<WeeklyBag> | undefined;
	if (!typeIs(bag, "table") || bag.Week !== weekOf(now) || !validBase(bag.Base)) {
		return 0;
	}
	return OmegaMath.Max(0, OmegaMath.Sub((profile.LifetimeCash as number | string) ?? 0, bag.Base!));
}

// The finished week this profile can still be paid for, if any.
export function unpaidWeek(profile: { WeeklyBoard?: unknown }, now: number): number | undefined {
	const bag = profile.WeeklyBoard as Partial<WeeklyBag> | undefined;
	const last = weekOf(now) - 1;
	if (!typeIs(bag, "table") || (tonumber(bag.ClaimedWeek) ?? last) >= last) {
		return undefined;
	}
	return last;
}
