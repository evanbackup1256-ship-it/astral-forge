// Overlap rules.
//
// ActionCollision: two interactive controls whose hit areas overlap on the same input layer.
//   Severity = overlap area / smaller control area, ramped from a relationship-dependent
//   threshold (siblings 12%, same ZIndex 35%, other 20%, as the old guard tuned them).
// ContentOverlap: visible text glyphs colliding with other text or with a painted control that
//   draws above them.
//
// Not collisions (each was a source of the old log spam):
//   - ancestor/descendant pairs (a card and its own button);
//   - pairs in different floating roots (BuffIsland vs. the page under it);
//   - elements in motion (LayoutInMotion) or whose rect moved since the previous scan (tween);
//   - a control fully covered by an opaque panel that contains the other control (an inspect
//     sheet over an inventory grid: the slots under it are hidden on purpose, not colliding);
//   - controls under a CanvasGroup / fading container that is effectively invisible.
import * as G from "../geom";
import { choosePairs, Boxed, RectIndex } from "../spatial";
import { inkRect, isAncestor, related, visibleRect } from "../snapUtil";
import { Finding, GNode, Rule, RuleContext, Snapshot, isText } from "../types";
import { eligible, finding, pct, ramp } from "./common";

function hitArea(n: GNode): G.Rect {
	return visibleRect(n);
}

function paintsAbove(a: GNode, b: GNode): boolean {
	if (a.displayOrder !== b.displayOrder) return a.displayOrder > b.displayOrder;
	return a.paintOrder > b.paintOrder;
}

/** Opaque drawn panels, indexed for "is this point covered" queries. */
export function surfaceIndex(snap: Snapshot): [RectIndex, Map<number, GNode>] {
	const items: Boxed[] = [];
	const map = new Map<number, GNode>();
	for (const n of snap.nodes) {
		if (!n.visible || !n.valid || !n.drawn || n.opacity > 0.35) continue;
		if (G.area(n.rect) < 400) continue;
		items.push({ id: n.id, rect: visibleRect(n) });
		map.set(n.id, n);
	}
	return [new RectIndex(items), map];
}

/**
 * True when `lower` is hidden behind an opaque panel that paints above it and holds `upper`
 * (or is `upper` itself): an intentional overlay, not a collision.
 */
export function hiddenByOverlay(snap: Snapshot, index: RectIndex, surfaces: Map<number, GNode>, lower: GNode, upper: GNode, region: G.Rect): boolean {
	for (const box of index.query(region)) {
		const panel = surfaces.get(box.id)!;
		if (panel.id === lower.id || isAncestor(snap, panel.id, lower.id) || isAncestor(snap, lower.id, panel.id)) continue;
		// the panel must hold the upper control; the upper control itself is not an overlay
		if (!isAncestor(snap, panel.id, upper.id)) continue;
		if (!paintsAbove(panel, lower)) continue;
		if (G.contains(box.rect, region, 0.5)) return true;
	}
	return false;
}

export function pairExempt(snap: Snapshot, a: GNode, b: GNode): boolean {
	if (a.layer !== b.layer) return true;
	if (related(snap, a.id, b.id)) return true;
	if (a.floating !== b.floating) return true;
	if (a.inMotion || b.inMotion) return true;
	return false;
}

export const ActionCollision: Rule = {
	id: "ActionCollision",
	title: "Interactive controls overlap",
	profile: "full",
	defaults: { minOverlapPx: 64, siblingThreshold: 0.12, sameZThreshold: 0.35, otherThreshold: 0.2, shieldShare: 0.8 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const layerArea = new Map<number, number>();
		for (const l of snap.layers) layerArea.set(l.id, G.area(l.rect));
		const shield = ctx.param("shieldShare", 0.8);
		const actions = eligible(snap, "ActionCollision", (n) => {
			if (!n.interactive) return false;
			const a = G.area(hitArea(n));
			// a full-screen click shield (modal backdrop) is not a control that can collide
			return a > 0 && a < (layerArea.get(n.layer) ?? math.huge) * shield;
		});
		const boxes: Boxed[] = [];
		for (const n of actions) boxes.push({ id: n.id, rect: hitArea(n) });
		const [index, surfaces] = surfaceIndex(snap);
		let visited = 0;
		choosePairs(boxes, (ba, bb) => {
			visited += 1;
			if (visited % 64 === 0) ctx.step();
			const a = snap.byId.get(ba.id)!;
			const b = snap.byId.get(bb.id)!;
			if (pairExempt(snap, a, b)) return;
			const overlap = G.intersectionArea(ba.rect, bb.rect);
			if (overlap < ctx.param("minOverlapPx", 64)) return;
			const smaller = math.min(G.area(ba.rect), G.area(bb.rect));
			const ratio = overlap / smaller;
			const threshold =
				a.parent === b.parent ? ctx.param("siblingThreshold", 0.12) : a.zIndex === b.zIndex ? ctx.param("sameZThreshold", 0.35) : ctx.param("otherThreshold", 0.2);
			if (ratio < threshold) return;
			const upper = paintsAbove(a, b) ? a : b;
			const lower = upper === a ? b : a;
			const region = G.intersect(ba.rect, bb.rect);
			if (hiddenByOverlay(snap, index, surfaces, lower, upper, region)) return;
			// rotated controls: refine with the exact oriented overlap
			let exact = ratio;
			if (a.rotation !== 0 || b.rotation !== 0) {
				const oa = G.obbFromRect(a.rect, a.rotation);
				const ob = G.obbFromRect(b.rect, b.rotation);
				exact = G.obbIntersectionArea(oa, ob) / math.min(G.obbArea(oa), G.obbArea(ob));
				if (exact < threshold) return;
			}
			const sep = G.separation(ba.rect, bb.rect);
			out.push(
				finding("ActionCollision", upper, ramp(exact, threshold, 0.75) * 0.7 + 0.3, `overlaps ${lower.path} by ${pct(exact)}`, {
					other: lower,
					rect: region,
					metrics: { ratio: exact, overlap },
					hint: sep.x !== 0 ? `${math.abs(sep.x)}px apart horizontally clears it` : `${math.abs(sep.y)}px apart vertically clears it`,
				}),
			);
		});
		return out;
	},
};

export const ContentOverlap: Rule = {
	id: "ContentOverlap",
	title: "Text collides with text or a control",
	profile: "full",
	defaults: { minShareX: 0.08, minShareY: 0.3, minInkPx: 6 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const minInk = ctx.param("minInkPx", 6);
		const texts = eligible(snap, "ContentOverlap", (n) => isText(n) && !n.interactive);
		const solids = eligible(snap, "ContentOverlap", (n) => n.interactive && n.drawn && n.opacity < 0.6);
		const boxes: Boxed[] = [];
		const ink = new Map<number, G.Rect>();
		for (const t of texts) {
			const r = G.intersect(inkRect(t), t.clipRect);
			if (G.width(r) < minInk || G.height(r) < minInk) continue;
			ink.set(t.id, r);
			boxes.push({ id: t.id, rect: r });
		}
		for (const s of solids) boxes.push({ id: s.id, rect: visibleRect(s) });
		const shareX = ctx.param("minShareX", 0.08);
		const shareY = ctx.param("minShareY", 0.3);
		const reported = new Set<number>();
		let visited = 0;
		choosePairs(boxes, (ba, bb) => {
			visited += 1;
			if (visited % 64 === 0) ctx.step();
			let a = snap.byId.get(ba.id)!;
			let b = snap.byId.get(bb.id)!;
			let ra = ba.rect;
			let rb = bb.rect;
			// text is always `a`
			if (!ink.has(a.id)) {
				[a, b] = [b, a];
				[ra, rb] = [rb, ra];
			}
			if (!ink.has(a.id) || reported.has(a.id)) return;
			if (pairExempt(snap, a, b)) return;
			const bothText = ink.has(b.id);
			// a control only hides text when it draws above it
			if (!bothText && !paintsAbove(b, a)) return;
			const w = G.width(G.intersect(ra, rb));
			const h = G.height(G.intersect(ra, rb));
			const sx = w / math.max(1, G.width(ra));
			const sy = h / math.max(1, G.height(ra));
			if (sx < shareX || sy < shareY) return;
			reported.add(a.id);
			const severity = ramp(sx * sy, shareX * shareY, 0.5) * 0.6 + (bothText ? 0.25 : 0.35);
			out.push(
				finding("ContentOverlap", a, severity, bothText ? `text runs into ${b.path}` : `text sits under ${b.path}`, {
					other: b,
					rect: G.intersect(ra, rb),
					metrics: { shareX: sx, shareY: sy },
				}),
			);
		});
		return out;
	},
};
