// Admin report: a plain table any admin panel can render (or a developer can print from the
// command bar via the AstralForgeLayoutDiagnostics BindableFunction).
import { Group, groupFindings } from "./logger";
import { Tracked } from "./engine";
import { Finding, Level, Snapshot } from "./types";

export interface ReportRow {
	rule: string;
	level: Level;
	severity: number;
	count: number;
	path: string;
	owner: string;
	message: string;
	hint?: string;
	examples: string[];
}

export interface Report {
	generatedAt: number;
	mode: string;
	device?: string;
	viewport: { width: number; height: number; touch: boolean; gamepad: boolean };
	nodes: number;
	totals: Record<Level, number>;
	byRule: Record<string, number>;
	rows: ReportRow[];
	matrix: ReportRow[];
	/** 0..100, 100 = clean; severity-weighted, saturating so one screen cannot go below 0 */
	score: number;
	stats: Record<string, number>;
}

export function scoreOf(findings: ReadonlyArray<Finding>): number {
	let load = 0;
	for (const f of findings) load += f.severity * f.severity;
	// 1 - e^(-load/k): k chosen so ~6 serious findings halve the score
	return math.floor(100 * math.exp(-load / 8) + 0.5);
}

function rowsOf(groups: ReadonlyArray<Group>, snap: Snapshot | undefined, pathOf: (id: number) => string): ReportRow[] {
	return groups.map((g) => ({
		rule: g.rule,
		level: g.level,
		severity: math.floor(g.severity * 100 + 0.5) / 100,
		count: g.count,
		path: pathOf(g.sample.node),
		owner: snap?.byId.get(g.sample.node)?.owner ?? "",
		message: g.sample.message,
		hint: g.sample.hint,
		examples: g.paths,
	}));
}

export function buildReport(
	snap: Snapshot | undefined,
	active: ReadonlyArray<Tracked>,
	matrix: ReadonlyArray<Finding>,
	mode: string,
	stats: Record<string, number>,
	pathOf: (id: number) => string,
	limit = 60,
): Report {
	const findings = active.map((t) => t.finding);
	const totals: Record<Level, number> = { info: 0, warn: 0, error: 0 };
	const byRule: Record<string, number> = {};
	for (const f of findings) {
		totals[f.level] += 1;
		byRule[f.rule] = (byRule[f.rule] ?? 0) + 1;
	}
	const rows = rowsOf(groupFindings(findings, pathOf), snap, pathOf);
	const matrixRows = rowsOf(groupFindings(matrix, pathOf), snap, pathOf);
	while (rows.size() > limit) rows.pop();
	while (matrixRows.size() > limit) matrixRows.pop();
	return {
		generatedAt: snap?.time ?? 0,
		mode,
		device: snap?.device,
		viewport: snap !== undefined ? { width: snap.viewport.width, height: snap.viewport.height, touch: snap.viewport.touch, gamepad: snap.viewport.gamepad } : { width: 0, height: 0, touch: false, gamepad: false },
		nodes: snap?.nodes.size() ?? 0,
		totals,
		byRule,
		rows,
		matrix: matrixRows,
		score: scoreOf(findings),
		stats,
	};
}

/** Plain-text rendering for the console / a TextLabel. */
export function reportText(r: Report): string {
	const lines: string[] = [];
	lines.push(
		string.format("LayoutGuard %s  score %d  %dx%d%s  nodes %d  errors %d warns %d infos %d", r.mode, r.score, r.viewport.width, r.viewport.height, r.viewport.touch ? " touch" : "", r.nodes, r.totals.error, r.totals.warn, r.totals.info),
	);
	for (const row of r.rows) {
		lines.push(string.format("[%s] %s%s %s: %s%s", row.level, row.rule, row.count > 1 ? ` x${row.count}` : "", row.path, row.message, row.hint !== undefined ? ` -> ${row.hint}` : ""));
	}
	if (r.matrix.size() > 0) {
		lines.push("device matrix:");
		for (const row of r.matrix) lines.push(string.format("  [%s] %s %s: %s", row.level, row.rule, row.path, row.message));
	}
	return lines.join("\n");
}
