// The black box recorder shared by the server ModuleLog and the client ClientLog.
//
// Printing is governed by LogPolicy (a quiet game prints little). Recording is not: every line, at every
// level including trace, lands in a fixed-size ring here whether or not it was printed, so when something
// goes wrong the lines leading up to it exist. The book also keeps counters (how many of this happened)
// and timings (how long this took: count, mean, max, last, how many were slow), and renders both as a
// summary. Nothing in here prints; the logs decide when to show it.
//
//   LogBook.record("DEBUG", "net", "Collect ok", "elapsed=12ms")     one line into the ring
//   LogBook.recent(40, "warn")                                         the last 40 lines at warn or above
//   LogBook.count("client.request.fail")                               a counter
//   LogBook.timing("client.request.Collect", 0.012)                    a duration, in seconds
//   LogBook.summary()                                                  lines for a dump

export interface BookEntry {
	/** os.clock() when it was recorded */
	at: number;
	/** the same seconds-since-start the printed line shows */
	level: string;
	scope: string;
	message: string;
	fields: string;
}

export interface TimingStat {
	count: number;
	total: number;
	max: number;
	last: number;
	slow: number;
}

const CAPACITY = 600;
const RANK: Record<string, number> = { TRACE: 0, DEBUG: 1, INFO: 2, NETWORK: 3, WARN: 4, ERROR: 5, FATAL: 6 };
const MAX_KEYS = 400;

const ring: BookEntry[] = [];
let cursor = 0;
let recorded = 0;
const startedAt = os.clock();
const counters = new Map<string, number>();
const timings = new Map<string, TimingStat>();
// anything slower than this counts toward a timing's `slow` figure
const SLOW_SECONDS = 0.15;

export function record(level: string, scope: string, message: string, fields: string): void {
	const entry: BookEntry = { at: os.clock(), level: string.upper(level), scope: string.lower(scope), message, fields };
	if (ring.size() < CAPACITY) {
		ring.push(entry);
	} else {
		ring[cursor] = entry;
		cursor = (cursor + 1) % CAPACITY;
	}
	recorded += 1;
	count("log." + string.lower(level));
}

function ordered(): BookEntry[] {
	if (ring.size() < CAPACITY) {
		return ring;
	}
	const out: BookEntry[] = [];
	for (let i = 0; i < CAPACITY; i++) {
		out.push(ring[(cursor + i) % CAPACITY]);
	}
	return out;
}

/** The most recent lines, oldest first, optionally only at `minLevel` or above and/or in one scope. */
export function recent(limit = 50, minLevel?: string, scope?: string): BookEntry[] {
	const floor = minLevel !== undefined ? (RANK[string.upper(minLevel)] ?? 0) : 0;
	const wanted = scope !== undefined ? string.lower(scope) : undefined;
	const all = ordered();
	const picked: BookEntry[] = [];
	for (let i = all.size() - 1; i >= 0 && picked.size() < limit; i--) {
		const entry = all[i];
		if ((RANK[entry.level] ?? 0) >= floor && (wanted === undefined || entry.scope === wanted)) {
			picked.push(entry);
		}
	}
	const out: BookEntry[] = [];
	for (let i = picked.size() - 1; i >= 0; i--) {
		out.push(picked[i]);
	}
	return out;
}

export function formatEntry(entry: BookEntry): string {
	const ago = os.clock() - entry.at;
	const text = `-${string.format("%6.2f", ago)}s  ${string.lower(string.sub(entry.level, 1, 5))}  ${entry.scope}  ${entry.message}`;
	return entry.fields !== "" ? `${text}  ${entry.fields}` : text;
}

/** A few lines of what just happened, newest last: attached to errors so they carry their context. */
export function breadcrumbs(limit = 6): string[] {
	const out: string[] = [];
	for (const entry of recent(limit, "debug")) {
		out.push(formatEntry(entry));
	}
	return out;
}

function trim<T>(map: Map<string, T>) {
	if (map.size() > MAX_KEYS) {
		map.clear();
	}
}

export function count(key: string, amount = 1): number {
	trim(counters);
	const total = (counters.get(key) ?? 0) + amount;
	counters.set(key, total);
	return total;
}

export function counter(key: string): number {
	return counters.get(key) ?? 0;
}

export function timing(key: string, seconds: number): TimingStat {
	trim(timings);
	let stat = timings.get(key);
	if (stat === undefined) {
		stat = { count: 0, total: 0, max: 0, last: 0, slow: 0 };
		timings.set(key, stat);
	}
	stat.count += 1;
	stat.total += seconds;
	stat.last = seconds;
	if (seconds > stat.max) {
		stat.max = seconds;
	}
	if (seconds >= SLOW_SECONDS) {
		stat.slow += 1;
	}
	return stat;
}

export function timingOf(key: string): TimingStat | undefined {
	return timings.get(key);
}

export interface Snapshot {
	uptime: number;
	recorded: number;
	counters: Record<string, number>;
	timings: Record<string, { count: number; meanMs: number; maxMs: number; lastMs: number; slow: number }>;
}

export function snapshot(): Snapshot {
	const c: Record<string, number> = {};
	for (const [key, value] of counters) {
		c[key] = value;
	}
	const t: Snapshot["timings"] = {};
	for (const [key, stat] of timings) {
		t[key] = {
			count: stat.count,
			meanMs: math.floor((stat.total / math.max(1, stat.count)) * 10000 + 0.5) / 10,
			maxMs: math.floor(stat.max * 10000 + 0.5) / 10,
			lastMs: math.floor(stat.last * 10000 + 0.5) / 10,
			slow: stat.slow,
		};
	}
	return { uptime: os.clock() - startedAt, recorded, counters: c, timings: t };
}

/** Lines for a dump: the counters that moved most, then the slowest timings. */
export function summary(top = 12): string[] {
	const lines: string[] = [];
	lines.push(`uptime ${string.format("%.0f", os.clock() - startedAt)}s, ${recorded} lines recorded (last ${math.min(recorded, CAPACITY)} kept)`);
	const counterList: Array<{ key: string; value: number }> = [];
	for (const [key, value] of counters) {
		counterList.push({ key, value });
	}
	counterList.sort((a, b) => a.value > b.value);
	if (counterList.size() > 0) {
		const parts: string[] = [];
		for (let i = 0; i < math.min(top, counterList.size()); i++) {
			parts.push(`${counterList[i].key}=${counterList[i].value}`);
		}
		lines.push("counters  " + parts.join("  "));
	}
	const timingList: Array<{ key: string; stat: TimingStat }> = [];
	for (const [key, stat] of timings) {
		timingList.push({ key, stat });
	}
	timingList.sort((a, b) => a.stat.max > b.stat.max);
	for (let i = 0; i < math.min(top, timingList.size()); i++) {
		const { key, stat } = timingList[i];
		lines.push(
			`timing    ${key}  n=${stat.count}  mean=${string.format("%.1f", (stat.total / math.max(1, stat.count)) * 1000)}ms  max=${string.format("%.1f", stat.max * 1000)}ms  slow=${stat.slow}`,
		);
	}
	return lines;
}

export function clear(): void {
	ring.clear();
	cursor = 0;
	recorded = 0;
	counters.clear();
	timings.clear();
}
