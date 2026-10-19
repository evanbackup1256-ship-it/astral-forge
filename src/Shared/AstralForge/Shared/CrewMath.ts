// Crews: small parties inside one server (guilds are the large, persistent groups).
// Pure rules shared by CrewService, the Crew page and Lune.
//
//   size     : up to MAX_MEMBERS, one leader
//   bonus    : each other member online adds BONUS_PER_MEMBER production, capped
//   goal     : vault collects pooled by the crew each UTC day; tiers pay stardust once per
//              player per day, and only to members who pitched in, so a parked alt earns nothing

interface Tier {
	readonly Target: number;
	readonly Stardust: number;
}

// Daily claim record kept in profile.Flags: the day it belongs to and a bitmask of claimed tiers.
interface DailyRecord {
	Day: number;
	Claimed: number;
}

const MAX_MEMBERS = 4;
const BONUS_PER_MEMBER = 0.03;
const INVITE_SECONDS = 60;
const MIN_CONTRIBUTION = 3; // collects a member must add today before goal tiers pay them
const GOAL_TIERS: ReadonlyArray<Tier> = table.freeze([
	table.freeze({ Target: 15, Stardust: 15 }),
	table.freeze({ Target: 40, Stardust: 25 }),
	table.freeze({ Target: 80, Stardust: 40 }),
]);

function dayOf(now: number): number {
	return math.floor(math.max(0, now) / 86400);
}

// Production multiplier for a member when `size` members (including them) are in the crew.
function multiplier(size: number): number {
	const others = math.clamp(math.floor(tonumber(size) ?? 0) - 1, 0, MAX_MEMBERS - 1);
	return 1 + others * BONUS_PER_MEMBER;
}

// Highest tier index reached by a pooled total (0 when none).
function tierReached(total: number): number {
	let reached = 0;
	GOAL_TIERS.forEach((tier, index) => {
		if (total >= tier.Target) {
			reached = index + 1;
		}
	});
	return reached;
}

function normalizeRecord(day: unknown, claimed: unknown, today: number): DailyRecord {
	const recordDay = typeIs(day, "number") && day === day ? math.floor(day) : -1;
	const mask = typeIs(claimed, "number") && claimed === claimed ? math.floor(claimed) : 0;
	if (recordDay !== today) {
		return { Day: today, Claimed: 0 };
	}
	return { Day: recordDay, Claimed: math.clamp(mask, 0, 2 ** GOAL_TIERS.size() - 1) };
}

function isClaimed(record: DailyRecord, tier: number): boolean {
	return math.floor(record.Claimed / 2 ** (tier - 1)) % 2 === 1;
}

// Whether a member may claim `tier` now; returns (ok, reason).
function canClaim(record: DailyRecord, tier: number, pooled: number, contribution: number): LuaTuple<[boolean, string?]> {
	const spec = (GOAL_TIERS as unknown as Record<number, Tier | undefined>)[tier];
	if (spec === undefined) {
		return $tuple(false, "That crew goal doesn't exist.");
	}
	if (isClaimed(record, tier)) {
		return $tuple(false, "You already claimed that crew goal today.");
	}
	if (pooled < spec.Target) {
		return $tuple(false, "Your crew hasn't reached that goal yet.");
	}
	if (contribution < MIN_CONTRIBUTION) {
		return $tuple(
			false,
			"Collect your vault %d more time%s to share this reward.".format(
				MIN_CONTRIBUTION - contribution,
				MIN_CONTRIBUTION - contribution === 1 ? "" : "s",
			),
		);
	}
	return $tuple(true, undefined);
}

function markClaimed(record: DailyRecord, tier: number): DailyRecord {
	if (isClaimed(record, tier)) {
		return record;
	}
	return { Day: record.Day, Claimed: record.Claimed + 2 ** (tier - 1) };
}

// Crew names: short, plain, filtered separately by the server.
function cleanName(raw: unknown): string | undefined {
	if (!typeIs(raw, "string")) {
		return undefined;
	}
	let name = raw.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
	name = name.gsub("%s+", " ")[0];
	const [length] = utf8.len(name);
	if (!typeIs(length, "number") || length < 2 || length > 20) {
		return undefined;
	}
	return name;
}

export = table.freeze({
	MAX_MEMBERS,
	BONUS_PER_MEMBER,
	INVITE_SECONDS,
	MIN_CONTRIBUTION,
	GOAL_TIERS,
	dayOf,
	multiplier,
	tierReached,
	normalizeRecord,
	isClaimed,
	canClaim,
	markClaimed,
	cleanName,
});
