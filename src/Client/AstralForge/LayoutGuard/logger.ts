// Rate-limited, grouped log output.
//
// Each scan produces findings; the engine passes only *new or worsened* confirmed findings here.
// Lines are grouped by signature (rule + folded shape), so twelve inventory slots with the same
// problem print once with "x12". A token bucket caps output (burst `capacity`, refill
// `perSecond`); whatever does not fit is counted and reported in a single summary line at the
// next window boundary instead of being dropped silently.
import { Finding, Level } from "./types";

export interface Sink {
	(level: Level, line: string): void;
}

export class TokenBucket {
	private tokens: number;
	private last: number;
	constructor(
		private readonly capacity: number,
		private readonly perSecond: number,
		now: number,
	) {
		this.tokens = capacity;
		this.last = now;
	}
	take(now: number, cost = 1): boolean {
		this.tokens = math.min(this.capacity, this.tokens + (now - this.last) * this.perSecond);
		this.last = now;
		if (this.tokens < cost) return false;
		this.tokens -= cost;
		return true;
	}
	available(now: number): number {
		return math.min(this.capacity, this.tokens + (now - this.last) * this.perSecond);
	}
}

export interface Group {
	signature: string;
	rule: string;
	level: Level;
	severity: number;
	count: number;
	sample: Finding;
	paths: string[];
}

const LEVEL_RANK: Record<Level, number> = { info: 0, warn: 1, error: 2 };

/** Groups findings by signature, keeping the worst sample and up to 3 example paths. */
export function groupFindings(findings: ReadonlyArray<Finding>, pathOf: (id: number) => string): Group[] {
	const map = new Map<string, Group>();
	const order: Group[] = [];
	for (const f of findings) {
		let g = map.get(f.signature);
		if (g === undefined) {
			g = { signature: f.signature, rule: f.rule, level: f.level, severity: f.severity, count: 0, sample: f, paths: [] };
			map.set(f.signature, g);
			order.push(g);
		}
		g.count += 1;
		if (f.severity > g.severity) {
			g.severity = f.severity;
			g.sample = f;
		}
		if (LEVEL_RANK[f.level] > LEVEL_RANK[g.level]) g.level = f.level;
		if (g.paths.size() < 3) g.paths.push(pathOf(f.node));
	}
	order.sort((a, b) => (a.severity !== b.severity ? a.severity > b.severity : a.signature < b.signature));
	return order;
}

export function formatGroup(g: Group, pathOf: (id: number) => string): string {
	const f = g.sample;
	const where = pathOf(f.node);
	const count = g.count > 1 ? ` x${g.count}` : "";
	const hint = f.hint !== undefined ? ` -> ${f.hint}` : "";
	return string.format("%s%s %s: %s%s (sev %.2f)", f.rule, count, where, f.message, hint, g.severity);
}

export class GroupedLogger {
	private bucket: TokenBucket;
	private suppressedLines = 0;
	private suppressedFindings = 0;
	private windowStart: number;
	constructor(
		private readonly sink: Sink,
		now: number,
		private readonly capacity = 6,
		private readonly perSecond = 0.2,
		private readonly windowSeconds = 30,
	) {
		this.bucket = new TokenBucket(capacity, perSecond, now);
		this.windowStart = now;
	}

	/** Emits grouped lines for findings; returns the number of lines written. */
	emit(findings: ReadonlyArray<Finding>, pathOf: (id: number) => string, now: number, prefix = ""): number {
		this.flushSummary(now);
		let written = 0;
		for (const g of groupFindings(findings, pathOf)) {
			// errors may borrow from the bucket even when it is low; info never jumps the queue
			const cost = g.level === "error" ? 0.5 : g.level === "warn" ? 1 : 2;
			if (this.bucket.take(now, cost)) {
				this.sink(g.level, prefix + formatGroup(g, pathOf));
				written += 1;
			} else {
				this.suppressedLines += 1;
				this.suppressedFindings += g.count;
			}
		}
		return written;
	}

	/** At window boundaries, one line accounts for everything the bucket held back. */
	flushSummary(now: number, force = false) {
		if (!force && now - this.windowStart < this.windowSeconds) return;
		if (this.suppressedLines > 0) {
			this.sink("info", `(${this.suppressedLines} more groups / ${this.suppressedFindings} findings held back by rate limit; open the LayoutGuard report for all)`);
		}
		this.suppressedLines = 0;
		this.suppressedFindings = 0;
		this.windowStart = now;
	}

	pending(): number {
		return this.suppressedLines;
	}
}
