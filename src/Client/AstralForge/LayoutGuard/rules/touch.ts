// Touch and screen-edge rules.
//
// TouchTarget: on touch devices a control's hit area should be >= 44px (Apple HIG 44pt, WCAG
//   2.5.5 AAA 44 CSS px; Material asks 48dp). Under the WCAG 2.5.8 AA floor of 24px it is an
//   error unless the spacing exception holds: a 24px circle centred on the target does not
//   intersect any other target's circle.
// TargetSpacing: two touch targets closer than `minGapPx` edge to edge (mis-tap risk).
// SafeArea: controls or text inside device cutouts (notch, rounded corners, home indicator)
//   or under the Roblox top bar when the layer does not reserve it.
// ViewportOverflow: controls partly or wholly off screen.
import * as G from "../geom";
import { choosePairs, Boxed } from "../spatial";
import { visibleRect } from "../snapUtil";
import { Finding, GNode, Layer, Rule, RuleContext, Snapshot, isText } from "../types";
import { eligible, finding, pct, px, ramp, stepEvery } from "./common";
import { hintFor } from "./clipping";

function touchTargets(snap: Snapshot, rule: string): GNode[] {
	return eligible(snap, rule, (n) => n.interactive && !n.inMotion && G.area(visibleRect(n)) > 0);
}

/** Distance from p to the nearest point of r (0 inside). */
export function pointRectDistance(x: number, y: number, r: G.Rect): number {
	const dx = math.max(r.x0 - x, 0, x - r.x1);
	const dy = math.max(r.y0 - y, 0, y - r.y1);
	return math.sqrt(dx * dx + dy * dy);
}

export const TouchTarget: Rule = {
	id: "TouchTarget",
	title: "Touch target too small",
	profile: "lite",
	defaults: { recommendedPx: 44, minimumPx: 24 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		if (!snap.viewport.touch) return [];
		const out: Finding[] = [];
		const scale = snap.viewport.dpiScale;
		const rec = ctx.param("recommendedPx", 44) / scale;
		const min = ctx.param("minimumPx", 24) / scale;
		const targets = touchTargets(snap, "TouchTarget");
		const centres = targets.map((t) => G.center(visibleRect(t)));
		targets.forEach((n, i) => {
			stepEvery(ctx, i, 16);
			const r = visibleRect(n);
			const side = math.min(G.width(r), G.height(r));
			if (side >= rec) return;
			let spaced = true;
			if (side < min) {
				// WCAG 2.5.8 spacing exception: 24px circles around undersized targets must not meet
				const c = centres[i];
				for (let j = 0; j < targets.size(); j++) {
					if (j === i) continue;
					const o = targets[j];
					if (o.layer !== n.layer) continue;
					if (pointRectDistance(c.x, c.y, visibleRect(o)) < min / 2 + (G.width(visibleRect(o)) < min ? min / 2 : 0)) {
						spaced = false;
						break;
					}
				}
			}
			const severity = side < min ? (spaced ? 0.45 : 0.8) : 0.15 + ramp(rec - side, 0, rec - min) * 0.3;
			out.push(
				finding("TouchTarget", n, severity, `${px(G.width(r))}x${px(G.height(r))} target (${side < min ? "below 24px minimum" : "under 44px"})`, {
					metrics: { side, recommended: rec },
					hint: `grow by ${px(rec - side)}`,
				}),
			);
		});
		return out;
	},
};

export const TargetSpacing: Rule = {
	id: "TargetSpacing",
	title: "Touch targets too close together",
	profile: "full",
	defaults: { minGapPx: 8 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		if (!snap.viewport.touch) return [];
		const out: Finding[] = [];
		const gap = ctx.param("minGapPx", 8) / snap.viewport.dpiScale;
		const half = gap / 2;
		const boxes: Boxed[] = [];
		for (const n of touchTargets(snap, "TargetSpacing")) boxes.push({ id: n.id, rect: G.insetUniform(visibleRect(n), -half) });
		const reported = new Set<number>();
		choosePairs(boxes, (a, b) => {
			const na = snap.byId.get(a.id)!;
			const nb = snap.byId.get(b.id)!;
			if (na.layer !== nb.layer || na.floating !== nb.floating) return;
			const ra = visibleRect(na);
			const rb = visibleRect(nb);
			if (G.intersects(ra, rb)) return; // overlap belongs to ActionCollision
			const d = G.gap(ra, rb);
			if (d >= gap || reported.has(na.id)) return;
			// related controls (a button and its own badge) are one target
			if (na.parent !== nb.parent && (na.id === nb.parent || nb.id === na.parent)) return;
			reported.add(na.id);
			out.push(finding("TargetSpacing", na, 0.2 + ramp(gap - d, 0, gap) * 0.3, `${px(d)} from ${nb.path}`, { other: nb, metrics: { gap: d } }));
		});
		return out;
	},
};

/** Safe rect for a layer: screen minus device cutouts, minus core UI unless the layer ignores it. */
export function safeRect(snap: Snapshot, layer: Layer | undefined): G.Rect {
	const vp = snap.viewport;
	const screen = G.rect(0, 0, vp.width, vp.height);
	let insets = vp.deviceInsets;
	if (layer === undefined || layer.screenInsets === "CoreUISafeInsets" || layer.screenInsets === "TopbarSafeInsets") {
		insets = G.maxInsets(insets, vp.coreInsets);
	}
	// capture stores every rect in full-screen space (GuiInset added back), so this is direct
	return G.inset(screen, insets);
}

export const SafeArea: Rule = {
	id: "SafeArea",
	title: "Content inside a device cutout or under the top bar",
	profile: "lite",
	defaults: { minIntrusionPx: 4 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const layers = new Map<number, Layer>();
		for (const l of snap.layers) layers.set(l.id, l);
		const minPx = ctx.param("minIntrusionPx", 4);
		const nodes = eligible(snap, "SafeArea", (n) => (n.interactive || isText(n)) && !n.inMotion);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i, 32);
			const safe = safeRect(snap, layers.get(n.layer));
			const vis = visibleRect(n);
			if (G.area(vis) <= 0) return;
			const amount = G.overflowAmount(vis, safe);
			if (amount < minPx) return;
			const share = G.outsideShare(vis, safe);
			out.push(
				finding("SafeArea", n, (n.interactive ? 0.35 : 0.2) + ramp(share, 0, 0.5) * 0.4, `${px(amount)} into the unsafe edge (${pct(share)})`, {
					metrics: { amount, share },
					hint: hintFor(G.nudgeInto(vis, safe)),
				}),
			);
		});
		return out;
	},
};

export const ViewportOverflow: Rule = {
	id: "ViewportOverflow",
	title: "Control off screen",
	profile: "lite",
	defaults: { slopPx: 2 },
	run(ctx: RuleContext): Finding[] {
		const snap = ctx.snap;
		const out: Finding[] = [];
		const screen = G.rect(0, 0, snap.viewport.width, snap.viewport.height);
		const slop = ctx.param("slopPx", 2);
		const nodes = eligible(snap, "ViewportOverflow", (n) => n.interactive && !n.inMotion && n.scroller === -1);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i, 32);
			const vis = visibleRect(n);
			if (G.area(n.rect) <= 0) return;
			const amount = G.overflowAmount(n.rect, screen);
			if (amount <= slop) return;
			// already hidden by a clipping parent: ClippedContent owns it
			if (G.contains(screen, vis, slop) && n.clipper !== -1) return;
			const share = G.outsideShare(n.rect, screen);
			out.push(
				finding("ViewportOverflow", n, share >= 0.99 ? 0.5 : 0.3 + ramp(share, 0, 0.5) * 0.5, share >= 0.99 ? "entirely off screen" : `${px(amount)} off screen`, {
					metrics: { amount, share },
					hint: hintFor(G.nudgeInto(n.rect, screen)),
				}),
			);
		});
		return out;
	},
};
