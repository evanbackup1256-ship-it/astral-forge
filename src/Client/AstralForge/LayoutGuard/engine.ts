// Pure engine: configuration, rule execution, confirmation across scans, dedupe.
//
// Confirmation is what kills transient spam. A finding is only *reported* when the same key
// (rule + node path + other path) has been seen in >= `confirmScans` scans spanning at least
// `confirmSeconds`, and the node's rect moved less than `stablePx` between the last two
// sightings. A tweening BuffIsland or a page sliding in produces a different rect every scan,
// so it never confirms; once it settles, a real problem confirms on the next scan.
// Reported keys are remembered until the problem disappears (no re-logging every scan, and a
// viewport resize does not wipe this memory). A reported finding is re-logged only if its
// severity worsens by more than `worsenBy`.
import * as G from "./geom";
import { LEGACY_IDS, RULES } from "./rules";
import { Finding, Profile, Rule, RuleConfig, RuleContext, Snapshot } from "./types";

export interface EngineOptions {
	confirmScans: number;
	confirmSeconds: number;
	stablePx: number;
	worsenBy: number;
	/** findings below this severity are kept in the report but never logged */
	logMinSeverity: number;
}

export const DEFAULT_OPTIONS: EngineOptions = {
	confirmScans: 2,
	confirmSeconds: 0.4,
	stablePx: 1,
	worsenBy: 0.15,
	logMinSeverity: 0.33,
};

export type Measure = RuleContext["measure"];

export function defaultConfig(rule: Rule): RuleConfig {
	return { enabled: true, minSeverity: 0.05, params: { ...rule.defaults } };
}

/**
 * Parses the LayoutGuardRules attribute:
 *   "ActionCollision=off, TouchTarget.recommendedPx=48, EmptyBand.minSeverity=0.3, *=off, Misalignment=on"
 * Unknown rules/keys are reported back so a typo is visible instead of silently ignored.
 */
export function parseConfig(spec: string | undefined, rules: ReadonlyArray<Rule> = RULES): [Map<string, RuleConfig>, string[]] {
	const configs = new Map<string, RuleConfig>();
	for (const r of rules) configs.set(r.id, defaultConfig(r));
	const errors: string[] = [];
	if (spec === undefined || spec === "") return [configs, errors];
	for (const [rawEntry] of spec.gmatch("[^,;]+")) {
		const entry = (rawEntry as string).match("^%s*(.-)%s*$")[0] as string;
		if (entry === "") continue;
		const [lhs, rhs] = entry.match("^([%w%*%._:]+)%s*=%s*(.+)$") as LuaTuple<[string | undefined, string | undefined]>;
		if (lhs === undefined || rhs === undefined) {
			errors.push(`bad entry '${entry}'`);
			continue;
		}
		const [ruleIdRaw, key] = lhs.match("^([^%.]+)%.?(.*)$") as LuaTuple<[string, string]>;
		const ruleId = LEGACY_IDS.get(ruleIdRaw) ?? ruleIdRaw;
		const targets: RuleConfig[] = [];
		if (ruleId === "*") for (const [, c] of configs) targets.push(c);
		else {
			const c = configs.get(ruleId);
			if (c === undefined) {
				errors.push(`unknown rule '${ruleIdRaw}'`);
				continue;
			}
			targets.push(c);
		}
		const lower = rhs.lower();
		for (const c of targets) {
			if (key === "") {
				if (lower === "off" || lower === "false" || lower === "0") c.enabled = false;
				else if (lower === "on" || lower === "true" || lower === "1") c.enabled = true;
				else errors.push(`'${lhs}' expects on/off`);
			} else {
				const value = tonumber(rhs);
				if (value === undefined) errors.push(`'${lhs}' expects a number`);
				else if (key === "minSeverity") c.minSeverity = value;
				else if (c.params[key] !== undefined || ruleId === "*") c.params[key] = value;
				else errors.push(`unknown key '${lhs}'`);
			}
		}
	}
	return [configs, errors];
}

export interface RunStats {
	rules: number;
	findings: number;
	failures: string[];
	perRule: Map<string, number>;
}

/** Runs every enabled rule allowed by the profile. Rule errors are isolated and reported. */
export function runRules(
	snap: Snapshot,
	configs: Map<string, RuleConfig>,
	profile: Profile,
	measure: Measure,
	step: () => void,
	only?: ReadonlyArray<string>,
	rules: ReadonlyArray<Rule> = RULES,
): [Finding[], RunStats] {
	const findings: Finding[] = [];
	const stats: RunStats = { rules: 0, findings: 0, failures: [], perRule: new Map() };
	const onlySet = only !== undefined ? new Set(only) : undefined;
	for (const rule of rules) {
		const config = configs.get(rule.id) ?? defaultConfig(rule);
		if (!config.enabled) continue;
		if (profile === "lite" && rule.profile !== "lite") continue;
		if (onlySet !== undefined && !onlySet.has(rule.id)) continue;
		const ctx: RuleContext = {
			snap,
			config,
			measure,
			step,
			param: (key, fallback) => config.params[key] ?? fallback,
		};
		stats.rules += 1;
		const [ok, result] = pcall(() => rule.run(ctx));
		if (!ok) {
			stats.failures.push(`${rule.id}: ${tostring(result)}`);
			continue;
		}
		let n = 0;
		for (const f of result as Finding[]) {
			if (f.severity < config.minSeverity) continue;
			findings.push(f);
			n += 1;
		}
		stats.perRule.set(rule.id, n);
		stats.findings += n;
		step();
	}
	return [findings, stats];
}

export interface Tracked {
	key: string;
	finding: Finding;
	path: string;
	firstSeen: number;
	lastSeen: number;
	sightings: number;
	rect: G.Rect;
	confirmed: boolean;
	reportedSeverity: number;
}

export interface TrackResult {
	/** confirmed findings to log now (new, or worsened beyond `worsenBy`) */
	toLog: Finding[];
	/** every confirmed finding currently present (for the report / overlay) */
	active: Tracked[];
	/** keys that disappeared this scan after having been reported */
	resolved: string[];
	pending: number;
}

export function keyOf(f: Finding, pathOf: (id: number) => string): string {
	return f.other !== undefined ? `${f.rule}|${pathOf(f.node)}|${pathOf(f.other)}` : `${f.rule}|${pathOf(f.node)}`;
}

/** Cross-scan memory. Pure apart from its own state; time is passed in. */
export class Tracker {
	private entries = new Map<string, Tracked>();
	constructor(public options: EngineOptions = DEFAULT_OPTIONS) {}

	update(findings: ReadonlyArray<Finding>, snap: Snapshot, now: number, pathOf: (id: number) => string): TrackResult {
		const o = this.options;
		const seen = new Set<string>();
		const toLog: Finding[] = [];
		for (const f of findings) {
			const key = keyOf(f, pathOf);
			if (seen.has(key)) continue;
			seen.add(key);
			const node = snap.byId.get(f.node);
			const rect = node !== undefined ? node.rect : (f.rect ?? G.EMPTY);
			let e = this.entries.get(key);
			if (e === undefined) {
				e = { key, finding: f, path: pathOf(f.node), firstSeen: now, lastSeen: now, sightings: 1, rect, confirmed: false, reportedSeverity: -1 };
				this.entries.set(key, e);
			} else {
				if (G.displacement(e.rect, rect) >= o.stablePx) {
					// still moving: restart the confirmation window but keep any reported state
					e.firstSeen = now;
					e.sightings = 1;
				} else {
					e.sightings += 1;
				}
				e.rect = rect;
				e.lastSeen = now;
				e.finding = f;
			}
			if (!e.confirmed && e.sightings >= o.confirmScans && now - e.firstSeen >= o.confirmSeconds) e.confirmed = true;
			if (e.confirmed && f.severity >= o.logMinSeverity && (e.reportedSeverity < 0 || f.severity > e.reportedSeverity + o.worsenBy)) {
				e.reportedSeverity = f.severity;
				toLog.push(f);
			}
		}
		const resolved: string[] = [];
		const active: Tracked[] = [];
		let pending = 0;
		for (const [key, e] of this.entries) {
			if (!seen.has(key)) {
				if (e.reportedSeverity >= 0) resolved.push(key);
				this.entries.delete(key);
			} else if (e.confirmed) active.push(e);
			else pending += 1;
		}
		active.sort((a, b) => a.finding.severity > b.finding.severity);
		return { toLog, active, resolved, pending };
	}

	size(): number {
		let n = 0;
		for (const _ of this.entries) n += 1;
		return n;
	}

	clear() {
		this.entries.clear();
	}
}

/** Deterministic sampling: a player is in the sample when hash(userId, salt) falls under rate. */
export function inSample(userId: number, rate: number, salt = 0x5bd1e995): boolean {
	if (rate >= 1) return true;
	if (rate <= 0) return false;
	// integer mix (xorshift-multiply) keeps the choice stable per player across sessions
	let h = (math.floor(userId) + salt) % 4294967296;
	h = bit32.bxor(h, bit32.rshift(h, 16));
	h = (h * 0x45d9f3) % 4294967296; // < 2^56 would lose bits; 0x45d9f3 keeps the product under 2^53
	h = bit32.bxor(h, bit32.rshift(h, 16));
	return h / 4294967296 < rate;
}
