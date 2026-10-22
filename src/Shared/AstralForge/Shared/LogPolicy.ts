// Which log lines get printed: levels, per-scope thresholds and sampling.
//
// Levels, quietest last: debug < info < net < warn < error < fatal. The global threshold comes from
// the ReplicatedStorage attribute AstralLogLevel ("debug", "info", "warn", ...); the older
// AstralDebugLogs=true still means "debug". A scope can be set on its own with
// AstralLogLevel_<scope> (for example AstralLogLevel_layoutguard = "warn").
//
// Sampling keeps noisy lines readable without hiding them: throttle() lets one line per key
// through per window and counts the rest, sample() lets one in N through. Both hand back how
// many were dropped since the last line printed so the caller can add it as a field.
// The policy is pure apart from reading attributes, which tests can replace with setSource.

export type LogLevel = "debug" | "info" | "net" | "warn" | "error" | "fatal";

const RANK: Record<LogLevel, number> = { debug: 0, info: 1, net: 2, warn: 3, error: 4, fatal: 5 };

const SEVERITY_LEVEL: Record<string, LogLevel> = {
	DEBUG: "debug",
	INFO: "info",
	NETWORK: "net",
	WARN: "warn",
	ERROR: "error",
	FATAL: "fatal",
};

export type AttributeSource = (this: void, name: string) => unknown;

const defaultSource: AttributeSource = (name) => game.GetService("ReplicatedStorage").GetAttribute(name);
let source: AttributeSource = defaultSource;

const throttles = new Map<string, { last: number; dropped: number }>();
const samplers = new Map<string, number>();
const MAX_KEYS = 512;

function asLevel(value: unknown): LogLevel | undefined {
	if (!typeIs(value, "string")) {
		return undefined;
	}
	const lowered = string.lower(value) as LogLevel;
	return RANK[lowered] !== undefined ? lowered : undefined;
}

export function levelOf(severity: string): LogLevel {
	return SEVERITY_LEVEL[string.upper(severity)] ?? asLevel(severity) ?? "info";
}

/** The threshold in force for a scope. */
export function threshold(scope?: string): LogLevel {
	if (scope !== undefined) {
		const scoped = asLevel(source(`AstralLogLevel_${string.lower(scope)}`));
		if (scoped !== undefined) {
			return scoped;
		}
	}
	const global = asLevel(source("AstralLogLevel"));
	if (global !== undefined) {
		return global;
	}
	return source("AstralDebugLogs") === true ? "debug" : "info";
}

/** True when a line at this severity and scope should print. Warnings and above always print. */
export function enabled(severity: string, scope?: string): boolean {
	const rank = RANK[levelOf(severity)];
	return rank >= RANK.warn || rank >= RANK[threshold(scope)];
}

function trim<T>(map: Map<string, T>) {
	if (map.size() > MAX_KEYS) {
		map.clear();
	}
}

/**
 * One line per key per window. Returns undefined when the line should be dropped, otherwise the
 * number dropped since the last line that printed for this key.
 */
export function throttle(key: string, seconds: number, now = os.clock()): number | undefined {
	const entry = throttles.get(key);
	if (entry !== undefined && now - entry.last < seconds) {
		entry.dropped += 1;
		return undefined;
	}
	trim(throttles);
	const dropped = entry?.dropped ?? 0;
	throttles.set(key, { last: now, dropped: 0 });
	return dropped;
}

/** One line in every `rate` for a key (the first always prints). Same return as throttle. */
export function sample(key: string, rate: number): number | undefined {
	const every = math.max(1, math.floor(rate));
	const seen = samplers.get(key);
	if (seen === undefined) {
		trim(samplers);
		samplers.set(key, 1 % every);
		return 0;
	}
	samplers.set(key, (seen + 1) % every);
	return seen === 0 ? every - 1 : undefined;
}

/** Forget throttles and samplers (new session, tests). */
export function reset(): void {
	throttles.clear();
	samplers.clear();
}

/** Replace where attributes are read from (tests); pass undefined to restore ReplicatedStorage. */
export function setSource(replacement?: AttributeSource): void {
	source = replacement ?? defaultSource;
}
