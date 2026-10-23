// Whitespace and density rules for containers.
//
// Which containers: those registered through attachWhitespaceDebug (whitespaceLabel), plus any
// drawn panel >= minPanelPx on each side that hosts a list/grid or >= 3 visible children.
//
// EmptyBand: a horizontal (or vertical) strip of the container with no content taller than
//   `bandShare` of its height. Computed exactly from merged 1-D spans of content rects.
// LowFill: union content area / container area (exact sweep union, not a sum) below `minFill`,
//   with the largest empty rectangle (raster + histogram stack) reported as the fix target.
// ColumnImbalance: a container laid out as side-by-side columns (horizontal list or >= 2 tall
//   children side by side) whose content heights differ a lot: the short column leaves a dead
//   block. Uses metrics.columnBalance (ratio, CV, summed dead space).
import * as G from "../geom";
import * as M from "../metrics";
import { contentRects, visibleChildren } from "../snapUtil";
import { Finding, GNode, Rule, RuleContext, Snapshot } from "../types";
import { eligible, finding, pct, px, ramp, stepEvery } from "./common";

export function whitespaceContainers(snap: Snapshot, rule: string, minPanel: number): GNode[] {
	return eligible(snap, rule, (n) => {
		if (n.whitespaceLabel !== undefined) return true;
		if (n.kind === "scroll" || n.inMotion) return false;
		const w = G.width(n.rect);
		const h = G.height(n.rect);
		if (w < minPanel || h < minPanel || !n.drawn) return false;
		const vp = snap.viewport;
		if (w >= vp.width * 0.98 && h >= vp.height * 0.98) return false; // full-screen backdrops
		return n.children.size() >= 3;
	});
}

/** Content extent along an axis, as merged spans relative to the container. */
export function spansOf(rects: ReadonlyArray<G.Rect>, axis: "x" | "y"): M.Span[] {
	const spans: M.Span[] = [];
	for (const r of rects) {
		if (G.area(r) <= 0) continue;
		spans.push(axis === "y" ? { lo: r.y0, hi: r.y1 } : { lo: r.x0, hi: r.x1 });
	}
	return M.mergeSpans(spans);
}

function label(n: GNode): string {
	return n.whitespaceLabel !== undefined ? `${n.whitespaceLabel} (${n.path})` : n.path;
}

export const EmptyBand: Rule = {
	id: "EmptyBand",
	title: "Large empty band inside a panel",
	profile: "full",
	defaults: { minPanelPx: 160, bandShare: 0.22, minBandPx: 48 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const share = ctx.param("bandShare", 0.22);
		const minBand = ctx.param("minBandPx", 48);
		whitespaceContainers(snap, "EmptyBand", ctx.param("minPanelPx", 160)).forEach((c, i) => {
			stepEvery(ctx, i, 4);
			const box = G.inset(c.rect, c.padding);
			const rects = contentRects(snap, c).map((r) => G.intersect(r, box)).filter((r) => G.area(r) > 0);
			if (rects.size() < 2) return;
			for (const axis of ["y", "x"] as const) {
				const lo = axis === "y" ? box.y0 : box.x0;
				const hi = axis === "y" ? box.y1 : box.x1;
				const length = hi - lo;
				const content = spansOf(rects, axis);
				if (content.size() === 0) continue;
				// only interior bands: leading/trailing space under a top-aligned list is normal
				const first = content[0].lo;
				const last = content[content.size() - 1].hi;
				const bands = M.freeBands(content, first, last, math.max(minBand, length * share));
				for (const band of bands) {
					const s = (band.hi - band.lo) / length;
					const rect = axis === "y" ? G.rect(box.x0, band.lo, box.x1, band.hi) : G.rect(band.lo, box.y0, band.hi, box.y1);
					out.push(
						finding("EmptyBand", c, 0.15 + ramp(s, share, 0.6) * 0.45, `${px(band.hi - band.lo)} empty ${axis === "y" ? "row" : "column"} in ${label(c)} (${pct(s)})`, {
							rect,
							metrics: { share: s, size: band.hi - band.lo },
						}),
					);
				}
			}
		});
		return out;
	},
};

export const LowFill: Rule = {
	id: "LowFill",
	title: "Panel mostly empty",
	profile: "full",
	defaults: { minPanelPx: 160, minFill: 0.18, minEmptyShare: 0.35 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const minFill = ctx.param("minFill", 0.18);
		const minEmpty = ctx.param("minEmptyShare", 0.35);
		whitespaceContainers(snap, "LowFill", ctx.param("minPanelPx", 160)).forEach((c, i) => {
			stepEvery(ctx, i, 4);
			const box = G.inset(c.rect, c.padding);
			const total = G.area(box);
			if (total <= 0) return;
			const rects = contentRects(snap, c);
			// a panel whose children are only invisible holders is still empty
			const fill = G.coverage(box, rects);
			if (fill >= minFill) return;
			const raster = M.rasterize(box, rects, 2048);
			const empty = M.largestEmptyRect(raster);
			const emptyShare = G.area(empty) / total;
			if (emptyShare < minEmpty) return;
			out.push(
				finding("LowFill", c, 0.15 + ramp(minFill - fill, 0, minFill) * 0.4, `${label(c)} is ${pct(fill)} filled; ${px(G.width(empty))}x${px(G.height(empty))} empty block`, {
					rect: empty,
					metrics: { fill, emptyShare },
				}),
			);
		});
		return out;
	},
};

/** Bottom of drawn content inside a column, measured from the column top. */
export function columnContentHeight(snap: Snapshot, column: GNode): number {
	let bottom = column.rect.y0;
	for (const r of contentRects(snap, column)) if (G.area(r) > 0) bottom = math.max(bottom, r.y1);
	return bottom - column.rect.y0;
}

/** Children laid out side by side as columns: tall, horizontally disjoint, vertically shared. */
export function columnsOf(snap: Snapshot, c: GNode): GNode[] {
	const kids = visibleChildren(snap, c).filter((k) => G.height(k.rect) >= G.height(c.rect) * 0.5 && G.width(k.rect) >= 80);
	if (kids.size() < 2) return [];
	kids.sort((a, b) => a.rect.x0 < b.rect.x0);
	for (let i = 1; i < kids.size(); i++) {
		if (kids[i].rect.x0 < kids[i - 1].rect.x1 - 2) return [];
	}
	return kids;
}

export const ColumnImbalance: Rule = {
	id: "ColumnImbalance",
	title: "Side-by-side columns with very different content heights",
	profile: "full",
	defaults: { minRatio: 1.8, minDeadPx: 120 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const minRatio = ctx.param("minRatio", 1.8);
		const minDead = ctx.param("minDeadPx", 120);
		whitespaceContainers(snap, "ColumnImbalance", 200).forEach((c, i) => {
			stepEvery(ctx, i, 4);
			const cols = columnsOf(snap, c);
			if (cols.size() < 2) return;
			const heights = cols.map((col) => columnContentHeight(snap, col));
			if (heights.some((h) => h <= 0)) return;
			const bal = M.columnBalance(heights);
			if (bal.ratio < minRatio || bal.deadSpace < minDead) return;
			let shortest = 0;
			for (let k = 1; k < heights.size(); k++) if (heights[k] < heights[shortest]) shortest = k;
			const col = cols[shortest];
			out.push(
				finding("ColumnImbalance", c, 0.2 + ramp(bal.imbalance, 0.2, 0.7) * 0.4, `columns ${string.format("%.1f", bal.ratio)}x uneven in ${label(c)}; ${px(bal.deadSpace)} dead under short columns`, {
					other: col,
					rect: G.rect(col.rect.x0, col.rect.y0 + heights[shortest], col.rect.x1, col.rect.y1),
					metrics: { ratio: bal.ratio, cv: bal.cv, deadSpace: bal.deadSpace },
				}),
			);
		});
		return out;
	},
};
