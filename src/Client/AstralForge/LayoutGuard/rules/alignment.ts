// Alignment and gutter consistency among free-positioned siblings (layout-owned children are
// placed by UIListLayout/UIGridLayout and are aligned by construction).
//
// Misalignment: edges (left, right, top, bottom, centre-x) are clustered with single-linkage at
//   `tolerancePx`. A cluster with >= 2 members whose spread is > 0.5px means elements were
//   meant to share a guide line but miss it by a pixel or three ("near miss"). Exact matches
//   and far-apart edges are fine.
// GutterInconsistency: siblings arranged in a row or column (projections overlap on the cross
//   axis) whose consecutive gaps vary: coefficient of variation > `maxCv` and range > `minRangePx`.
//   The outlier gap (furthest from the median) is reported with the median as the fix target.
import * as G from "../geom";
import * as M from "../metrics";
import { visibleChildren } from "../snapUtil";
import { Finding, GNode, Rule, RuleContext, Snapshot } from "../types";
import { eligible, finding, px, ramp, stepEvery } from "./common";

type Edge = "left" | "right" | "top" | "bottom" | "centerX";

function edgeOf(r: G.Rect, e: Edge): number {
	if (e === "left") return r.x0;
	if (e === "right") return r.x1;
	if (e === "top") return r.y0;
	if (e === "bottom") return r.y1;
	return (r.x0 + r.x1) / 2;
}

export function freeChildren(snap: Snapshot, parent: GNode): GNode[] {
	return visibleChildren(snap, parent).filter((c) => !c.layoutOwned && !c.inMotion && c.valid && G.area(c.rect) >= 64 && (c.drawn || c.interactive || c.text !== undefined));
}

export interface NearMiss {
	edge: Edge;
	node: GNode;
	offset: number;
	line: number;
	members: number;
}

export function nearMisses(nodes: ReadonlyArray<GNode>, tolerance: number): NearMiss[] {
	const out: NearMiss[] = [];
	const edges: Edge[] = ["left", "right", "top", "bottom", "centerX"];
	for (const e of edges) {
		const values = nodes.map((n) => edgeOf(n.rect, e));
		for (const cluster of M.clusterByGap(values, tolerance)) {
			if (cluster.indices.size() < 2 || cluster.spread <= 0.5) continue;
			// the guide line is the mode: the value most members share exactly (else the median)
			const counts = new Map<number, number>();
			let line = M.median(cluster.members);
			let best = 1;
			for (const v of cluster.members) {
				const k = math.floor(v + 0.5);
				const c = (counts.get(k) ?? 0) + 1;
				counts.set(k, c);
				if (c > best) {
					best = c;
					line = k;
				}
			}
			for (const i of cluster.indices) {
				const offset = values[i] - line;
				if (math.abs(offset) > 0.5) out.push({ edge: e, node: nodes[i], offset, line, members: cluster.indices.size() });
			}
		}
	}
	return out;
}

export const Misalignment: Rule = {
	id: "Misalignment",
	title: "Edges almost but not quite aligned",
	profile: "full",
	defaults: { tolerancePx: 3, minSiblings: 3 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const tol = ctx.param("tolerancePx", 3);
		const minSiblings = ctx.param("minSiblings", 3);
		const reported = new Set<number>();
		eligible(snap, "Misalignment", (n) => n.children.size() >= minSiblings && n.parentLayout !== "grid").forEach((parent, i) => {
			stepEvery(ctx, i, 8);
			const kids = freeChildren(snap, parent);
			if (kids.size() < minSiblings) return;
			for (const miss of nearMisses(kids, tol)) {
				if (reported.has(miss.node.id)) continue;
				reported.add(miss.node.id);
				const horizontal = miss.edge === "left" || miss.edge === "right" || miss.edge === "centerX";
				out.push(
					finding("Misalignment", miss.node, 0.1 + ramp(math.abs(miss.offset), 0.5, tol) * 0.25, `${miss.edge} edge ${px(math.abs(miss.offset))} off the line shared by ${miss.members - 1} siblings`, {
						metrics: { offset: miss.offset, line: miss.line },
						hint: `move ${px(math.abs(miss.offset))} ${horizontal ? (miss.offset > 0 ? "left" : "right") : miss.offset > 0 ? "up" : "down"}`,
					}),
				);
			}
		});
		return out;
	},
};

/** Groups siblings into a single row/column run when their cross-axis projections overlap. */
export function runOf(nodes: ReadonlyArray<GNode>): { axis: "x" | "y"; ordered: GNode[] } | undefined {
	if (nodes.size() < 3) return undefined;
	const all = [...nodes];
	const sharesY = all.every((n) => n.rect.y0 < all[0].rect.y1 && all[0].rect.y0 < n.rect.y1);
	const sharesX = all.every((n) => n.rect.x0 < all[0].rect.x1 && all[0].rect.x0 < n.rect.x1);
	if (sharesY && !sharesX) {
		all.sort((a, b) => a.rect.x0 < b.rect.x0);
		return { axis: "x", ordered: all };
	}
	if (sharesX && !sharesY) {
		all.sort((a, b) => a.rect.y0 < b.rect.y0);
		return { axis: "y", ordered: all };
	}
	return undefined;
}

export const GutterInconsistency: Rule = {
	id: "GutterInconsistency",
	title: "Uneven spacing between siblings in a row or column",
	profile: "full",
	defaults: { maxCv: 0.25, minRangePx: 4 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const maxCv = ctx.param("maxCv", 0.25);
		const minRange = ctx.param("minRangePx", 4);
		eligible(snap, "GutterInconsistency", (n) => n.children.size() >= 3).forEach((parent, i) => {
			stepEvery(ctx, i, 8);
			// the loading screen places its tip on purpose, away from the logo/progress stack
			if (parent.name === "boot" || parent.path.find(".boot", 1, true)[0] !== undefined) return;
			const run = runOf(freeChildren(snap, parent));
			if (run === undefined) return;
			const gaps: number[] = [];
			for (let k = 1; k < run.ordered.size(); k++) {
				const a = run.ordered[k - 1].rect;
				const b = run.ordered[k].rect;
				gaps.push(run.axis === "x" ? b.x0 - a.x1 : b.y0 - a.y1);
			}
			if (gaps.some((g) => g < 0)) return; // overlapping: collision rules own it
			const sorted = M.sortedCopy(gaps);
			const range = sorted[sorted.size() - 1] - sorted[0];
			const variation = M.cv(gaps);
			if (range < minRange || variation < maxCv) return;
			const med = M.median(gaps);
			let worst = 0;
			for (let k = 1; k < gaps.size(); k++) if (math.abs(gaps[k] - med) > math.abs(gaps[worst] - med)) worst = k;
			const node = run.ordered[worst + 1];
			out.push(
				finding("GutterInconsistency", node, 0.1 + ramp(variation, maxCv, 1) * 0.3, `gap ${px(gaps[worst])} vs median ${px(med)} in ${parent.path}`, {
					other: parent,
					metrics: { cv: variation, range, median: med },
					hint: `set the gap to ${px(med)}`,
				}),
			);
		});
		return out;
	},
};
