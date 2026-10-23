// Containment rules.
//
// ClippedContent: an interactive or text node is partly cut off by a ClipsDescendants ancestor
//   chain (clipRect is the intersection of every clipping ancestor). Scroll windows are exempt
//   because clipping there is the point; a control is reachable by scrolling.
// OutOfParent: a control sticks out of its parent's padded content box. Exempt:
//   - floating roots and their direct content (LayoutFloating on the node OR an ancestor: the
//     old guard only looked at the node itself, which produced the steady
//     "BuffIsland 12px outside parent" warning while the island hangs off the top bar by design);
//   - nodes in motion; nodes inside a scroller (the canvas, not the window, is the parent);
//   - overflow under `slopPx` (anti-aliasing, UIStroke) or when the parent is invisible chrome
//     (a zero-size or transparent holder whose only job is positioning).
// Occlusion: an interactive control partly covered by opaque surfaces painted above it. Full
//   coverage by a large panel is an intentional modal and is not reported; partial coverage
//   (a chip sliding over half a button) is a real usability bug.
import * as G from "../geom";
import { isAncestor, visibleRect, visibleShare } from "../snapUtil";
import { Finding, GNode, Rule, RuleContext, isText } from "../types";
import { eligible, finding, pct, px, ramp, stepEvery } from "./common";
import { surfaceIndex } from "./overlap";

function scrollClipped(ctx: RuleContext, n: GNode): boolean {
	if (n.scroller === -1) return false;
	const s = ctx.snap.byId.get(n.scroller);
	return s !== undefined && (n.clipper === s.id || isAncestor(ctx.snap, n.clipper, s.id));
}

/**
 * Content hidden on purpose is not "clipped": a collapsed card (Rise/Collapse tween closing a
 * CanvasGroup), a zero-size or fully transparent holder, anything in motion, anything inside a
 * ScrollingFrame (off-canvas content is reached by scrolling), and content that is entirely
 * hidden (a real clip cuts a control *partly*; 100% hidden means the container is closed).
 */
function intentionallyHidden(ctx: RuleContext, n: GNode, hidden: number): boolean {
	if (hidden >= 0.98) return true;
	if (n.opacity >= 0.99) return true;
	let id = n.parent;
	while (id !== -1) {
		const a = ctx.snap.byId.get(id);
		if (a === undefined) break;
		if (a.inMotion || a.kind === "scroll" || a.className === "ScrollingFrame") return true;
		if (a.rect.x1 - a.rect.x0 < 2 || a.rect.y1 - a.rect.y0 < 2) return true;
		if (a.clips && a.className === "CanvasGroup") return true;
		if (id === n.clipper) break;
		id = a.parent;
	}
	return false;
}

export const ClippedContent: Rule = {
	id: "ClippedContent",
	title: "Control or text cut off by a clipping ancestor",
	profile: "lite",
	defaults: { minHiddenShare: 0.08, minHiddenPx: 4 },
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		const minShare = ctx.param("minHiddenShare", 0.08);
		const minPx = ctx.param("minHiddenPx", 4);
		const nodes = eligible(ctx.snap, "ClippedContent", (n) => (n.interactive || isText(n)) && n.clipper !== -1 && !n.inMotion);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i);
			if (scrollClipped(ctx, n)) return;
			const share = visibleShare(n);
			const hidden = 1 - share;
			const amount = G.overflowAmount(n.rect, n.clipRect);
			if (hidden < minShare || amount < minPx) return;
			if (intentionallyHidden(ctx, n, hidden)) return;
			const clipper = ctx.snap.byId.get(n.clipper);
			const base = n.interactive ? 0.35 : 0.2;
			out.push(
				finding("ClippedContent", n, base + ramp(hidden, minShare, 0.6) * (1 - base), `${pct(hidden)} hidden by ${clipper?.path ?? "a clipping ancestor"}`, {
					other: clipper,
					rect: n.rect,
					metrics: { hidden, amount },
					hint: hintFor(G.nudgeInto(n.rect, n.clipRect)),
				}),
			);
		});
		return out;
	},
};

export function hintFor(v: { x: number; y: number }): string | undefined {
	const parts: string[] = [];
	if (math.abs(v.x) >= 1) parts.push(`move ${px(math.abs(v.x))} ${v.x > 0 ? "right" : "left"}`);
	if (math.abs(v.y) >= 1) parts.push(`move ${px(math.abs(v.y))} ${v.y > 0 ? "down" : "up"}`);
	return parts.size() > 0 ? parts.join(", ") : undefined;
}

/** Floating exemption: the floating root itself, or a direct child of it. */
export function floatingExempt(ctx: RuleContext, n: GNode): boolean {
	if (n.floating === -1) return false;
	if (n.floating === n.id || n.parent === n.floating) return true;
	// the parent is the floating root's descendant but the node's own floating root differs from
	// its parent's: entering a nested floating scope
	const parent = ctx.snap.byId.get(n.parent);
	return parent !== undefined && parent.floating !== n.floating;
}

export const OutOfParent: Rule = {
	id: "OutOfParent",
	title: "Control extends outside its parent",
	profile: "lite",
	defaults: { slopPx: 3, minOutsideShare: 0.05 },
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		const slop = ctx.param("slopPx", 3);
		const minShare = ctx.param("minOutsideShare", 0.05);
		const nodes = eligible(ctx.snap, "OutOfParent", (n) => n.interactive && n.parent !== -1 && !n.inMotion && n.scroller === -1);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i);
			if (floatingExempt(ctx, n)) return;
			const parent = ctx.snap.byId.get(n.parent);
			if (parent === undefined || !parent.valid) return;
			if (G.area(parent.rect) < 4 || (!parent.drawn && !parent.clips)) return;
			const box = n.parentContent;
			const amount = G.overflowAmount(n.rect, box);
			if (amount <= slop) return;
			const share = G.outsideShare(n.rect, box);
			if (share < minShare && amount < slop * 4) return;
			out.push(
				finding("OutOfParent", n, 0.2 + ramp(share, minShare, 0.5) * 0.6, `${px(amount)} outside ${parent.path}`, {
					other: parent,
					metrics: { amount, share },
					hint: hintFor(G.nudgeInto(n.rect, box)),
				}),
			);
		});
		return out;
	},
};

export const Occlusion: Rule = {
	id: "Occlusion",
	title: "Control partly covered by a surface painted above it",
	profile: "full",
	defaults: { minCovered: 0.15, maxCovered: 0.92 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const [index, surfaces] = surfaceIndex(snap);
		const lo = ctx.param("minCovered", 0.15);
		const hi = ctx.param("maxCovered", 0.92);
		const nodes = eligible(snap, "Occlusion", (n) => n.interactive && !n.inMotion);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i, 16);
			const vis = visibleRect(n);
			const total = G.area(vis);
			if (total <= 0) return;
			const holes: G.Rect[] = [];
			let top: GNode | undefined;
			for (const box of index.query(vis)) {
				const s = surfaces.get(box.id)!;
				if (s.id === n.id || s.layer !== n.layer && s.displayOrder <= n.displayOrder) continue;
				if (isAncestor(snap, s.id, n.id) || isAncestor(snap, n.id, s.id)) continue;
				if (s.floating !== n.floating && s.inMotion) continue;
				const above = s.displayOrder !== n.displayOrder ? s.displayOrder > n.displayOrder : s.paintOrder > n.paintOrder;
				if (!above) continue;
				holes.push(G.intersect(box.rect, vis));
				if (top === undefined || G.intersectionArea(box.rect, vis) > G.intersectionArea(top.rect, vis)) top = s;
			}
			if (holes.size() === 0) return;
			const covered = G.unionArea(holes, vis) / total;
			if (covered < lo || covered > hi) return;
			out.push(
				finding("Occlusion", n, 0.3 + ramp(covered, lo, 0.6) * 0.5, `${pct(covered)} covered by ${top!.path}`, {
					other: top,
					rect: vis,
					metrics: { covered },
				}),
			);
		});
		return out;
	},
};
