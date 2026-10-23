// ScrollingFrame and geometry sanity rules (ported from the old guard, tightened).
//
// CanvasOverflow: children extend past CanvasSize on a scrollable axis, so the tail of the list
//   cannot be scrolled into view (AutomaticCanvasSize off). Ported recovery hint: new CanvasSize.
// NestedScroll: a scroller inside another scroller that scrolls on the same axis (touch drags
//   fight). Opt out with LayoutGuardAllowNestedScroll.
// DisabledScroll: content overflows the window but ScrollingEnabled is false. Opt out with
//   LayoutGuardAllowDisabledScroll.
// InvalidGeometry: NaN/inf rects or negative sizes (division by zero in a size formula).
import * as G from "../geom";
import { Finding, Rule, RuleContext } from "../types";
import { eligible, finding, px, ramp } from "./common";

export const CanvasOverflow: Rule = {
	id: "CanvasOverflow",
	title: "Scroll content longer than CanvasSize",
	profile: "lite",
	defaults: { slopPx: 4 },
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		const slop = ctx.param("slopPx", 4);
		for (const n of eligible(ctx.snap, "CanvasOverflow", (x) => x.scroll !== undefined && !x.scroll.automatic)) {
			const s = n.scroll!;
			const overX = s.scrollX || !s.scrollY ? math.max(0, s.content.x - math.max(s.canvas.x, s.window.x)) : 0;
			const overY = s.scrollY ? math.max(0, s.content.y - math.max(s.canvas.y, s.window.y)) : 0;
			const amount = math.max(overX, overY);
			if (amount <= slop) continue;
			const axisLen = overY >= overX ? s.canvas.y : s.canvas.x;
			out.push(
				finding("CanvasOverflow", n, 0.4 + ramp(amount / math.max(1, axisLen), 0, 0.3) * 0.4, `${px(amount)} of content past CanvasSize`, {
					metrics: { overX, overY },
					hint: `CanvasSize ${px(math.max(s.canvas.x, s.content.x))}x${px(math.max(s.canvas.y, s.content.y))} or AutomaticCanvasSize`,
				}),
			);
		}
		return out;
	},
};

export const NestedScroll: Rule = {
	id: "NestedScroll",
	title: "Scroller inside a scroller on the same axis",
	profile: "lite",
	defaults: {},
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		for (const n of eligible(ctx.snap, "NestedScroll", (x) => x.scroll !== undefined && x.scroll.enabled && !x.allowNestedScroll)) {
			let p = ctx.snap.byId.get(n.parent);
			while (p !== undefined) {
				if (p.scroll !== undefined && p.scroll.enabled && !p.allowNestedScroll) {
					const sameAxis = (p.scroll.scrollY && n.scroll!.scrollY) || (p.scroll.scrollX && n.scroll!.scrollX);
					const innerScrolls = n.scroll!.content.y > n.scroll!.window.y + 1 || n.scroll!.content.x > n.scroll!.window.x + 1;
					if (sameAxis && innerScrolls) out.push(finding("NestedScroll", n, 0.4, `scrolls on the same axis as ${p.path}`, { other: p }));
					break;
				}
				p = ctx.snap.byId.get(p.parent);
			}
		}
		return out;
	},
};

export const DisabledScroll: Rule = {
	id: "DisabledScroll",
	title: "Overflowing scroller with scrolling disabled",
	profile: "lite",
	defaults: { slopPx: 4 },
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		const slop = ctx.param("slopPx", 4);
		for (const n of eligible(ctx.snap, "DisabledScroll", (x) => x.scroll !== undefined && !x.scroll.enabled && !x.allowDisabledScroll)) {
			const s = n.scroll!;
			const over = math.max(s.content.x - s.window.x, s.content.y - s.window.y);
			if (over > slop) out.push(finding("DisabledScroll", n, 0.45, `${px(over)} of content unreachable (ScrollingEnabled=false)`, { metrics: { over } }));
		}
		return out;
	},
};

export const InvalidGeometry: Rule = {
	id: "InvalidGeometry",
	title: "Non-finite or negative geometry",
	profile: "lite",
	defaults: {},
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		for (const n of ctx.snap.nodes) {
			if (n.valid || !n.visible || n.suppress.has("*") || n.suppress.has("InvalidGeometry")) continue;
			const finite = G.isFiniteRect(n.rect);
			out.push(finding("InvalidGeometry", n, 0.7, finite ? "negative size" : "non-finite position or size", { rect: finite ? n.rect : G.EMPTY }));
		}
		return out;
	},
};
