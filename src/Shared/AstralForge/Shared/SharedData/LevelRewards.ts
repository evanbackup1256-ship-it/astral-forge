interface Reward {
	FluxSeconds: number;
	MinFlux: number;
	Stardust: number;
	SurgeMultiplier: number;
	SurgeSeconds: number;
}
interface Surge {
	Multiplier?: unknown;
	EndsAt?: unknown;
}

const TIER_INDEX: Record<string, number> = { Beginner: 1, Apprentice: 2, Journeyman: 3, Expert: 4, Master: 5, Legend: 6 };

const MASTERY_PER_LEVEL = 0.02;
const SURGE_CAP_SECONDS = 1800;
const SURGE_MAX_MULTIPLIER = 1.6;
const HALFWAY_SHARE = 0.5;

function forLevel(level: number, tier?: string): Reward {
	const tierIndex = TIER_INDEX[tier ?? ""] ?? 1;
	level = math.max(1, math.floor(level));
	return {
		FluxSeconds: 90 + level * 30,
		MinFlux: 60 * level,
		Stardust: level * 4 + tierIndex * 8,
		SurgeMultiplier: math.min(SURGE_MAX_MULTIPLIER, 1.2 + tierIndex * 0.05),
		SurgeSeconds: math.min(900, 240 + level * 30),
	};
}

function halfway(nextLevel: number): { FluxSeconds: number; MinFlux: number } {
	nextLevel = math.max(2, math.floor(nextLevel));
	return { FluxSeconds: 30 + nextLevel * 10, MinFlux: 25 * nextLevel };
}

function mastery(level: number): number {
	return math.max(0, math.floor(level) - 1) * MASTERY_PER_LEVEL;
}

function mergeSurge(current: unknown, now: number, multiplier: number, seconds: number) {
	const c = current as Surge;
	const active = typeIs(current, "table") && typeIs(c.EndsAt, "number") && c.EndsAt > now;
	const baseEnd = active ? (c.EndsAt as number) : now;
	const baseMultiplier = active && typeIs(c.Multiplier, "number") ? c.Multiplier : 1;
	return {
		Multiplier: math.min(SURGE_MAX_MULTIPLIER, math.max(baseMultiplier, multiplier)),
		EndsAt: math.min(now + SURGE_CAP_SECONDS, baseEnd + math.max(0, seconds)),
	};
}

function surgeMultiplier(surge: unknown, now: number): number {
	const s = surge as Surge;
	if (!typeIs(surge, "table") || !typeIs(s.EndsAt, "number") || s.EndsAt <= now) {
		return 1;
	}
	const multiplier = tonumber(s.Multiplier) ?? 1;
	return math.clamp(multiplier, 1, SURGE_MAX_MULTIPLIER);
}

function owed(rewarded: number, level: number): LuaTuple<[number[], number]> {
	if (!typeIs(rewarded, "number") || rewarded < 0) {
		return $tuple([], level);
	}
	const list: number[] = [];
	for (let value = math.floor(rewarded) + 1; value <= math.floor(level); value++) {
		list.push(value);
	}
	return $tuple(list, math.max(math.floor(rewarded), math.floor(level)));
}

function halfwayDue(paidFor: number, nextLevel: number | undefined, progress: number, target: number): boolean {
	if (nextLevel === undefined || target <= 0 || !typeIs(paidFor, "number") || paidFor < 0) {
		return false;
	}
	return paidFor < nextLevel && progress / target >= HALFWAY_SHARE;
}

function eta(kind: string, remaining: number, ratePerSecond: number): number | undefined {
	if (kind !== "LifetimeCash" || ratePerSecond <= 0 || remaining <= 0) {
		return undefined;
	}
	return remaining / ratePerSecond;
}

function etaText(seconds?: number): string {
	if (seconds === undefined || seconds !== seconds) {
		return "";
	}
	const total = math.max(0, math.floor(seconds));
	if (total < 60) {
		return `${math.max(1, total)}s`;
	} else if (total < 3600) {
		return `${math.floor(total / 60)}m`;
	} else if (total < 86400) {
		const minutes = math.floor((total % 3600) / 60);
		return minutes > 0 ? `${math.floor(total / 3600)}h ${minutes}m` : `${math.floor(total / 3600)}h`;
	}
	return `${math.floor(total / 86400)}d`;
}

export = table.freeze({
	MASTERY_PER_LEVEL,
	SURGE_CAP_SECONDS,
	SURGE_MAX_MULTIPLIER,
	HALFWAY_SHARE,
	forLevel,
	halfway,
	mastery,
	mergeSurge,
	surgeMultiplier,
	owed,
	halfwayDue,
	eta,
	etaText,
});
