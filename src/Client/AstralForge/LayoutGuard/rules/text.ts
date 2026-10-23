// Text rules.
//
// TextOverflow: glyphs do not fit their box. The engine's TextFits is authoritative for the live
//   box; we confirm with a measured size (TextService:GetTextBoundsAsync through the cached
//   measure callback) so the message carries real numbers and a fix hint. Exempt: TextScaled
//   (shrinks to fit), TextTruncate (ellipsis is a deliberate choice), empty or whitespace text.
// TextTooSmall: rendered glyph height under a legibility floor. TextScaled labels can collapse to
//   tiny sizes on phones; the effective size is the TextBounds height of one line.
import * as G from "../geom";
import { Finding, GNode, Rule, RuleContext, isText } from "../types";
import { eligible, finding, px, ramp, stepEvery } from "./common";

/** Strips rich-text tags so measurement sees the visible characters. */
export function visibleText(raw: string, rich: boolean): string {
	if (!rich) return raw;
	const [stripped] = raw.gsub("<[^>]->", "");
	const [a] = stripped.gsub("&lt;", "<");
	const [b] = a.gsub("&gt;", ">");
	const [c] = b.gsub("&quot;", '"');
	const [d] = c.gsub("&apos;", "'");
	const [e] = d.gsub("&amp;", "&");
	return e;
}

export function lineCount(text: string): number {
	let lines = 1;
	for (const _ of text.gmatch("\n")) lines += 1;
	return lines;
}

/** Measured overflow of a text node in px along each axis (>= 0). */
export function textOverflow(ctx: RuleContext, n: GNode): { x: number; y: number; measured: { x: number; y: number } } {
	const t = n.text!;
	const text = visibleText(t.text, t.rich);
	const w = G.width(n.rect);
	const h = G.height(n.rect);
	const measured = ctx.measure(text, t.size, t.font, t.wrapped ? w : math.huge);
	return { x: t.wrapped ? 0 : math.max(0, measured.x - w), y: math.max(0, measured.y - h), measured };
}

export const TextOverflow: Rule = {
	id: "TextOverflow",
	title: "Text does not fit its box",
	profile: "lite",
	defaults: { minOverflowPx: 2 },
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		const minPx = ctx.param("minOverflowPx", 2);
		const nodes = eligible(ctx.snap, "TextOverflow", (n) => isText(n) && !n.text!.scaled && !n.text!.truncate && !n.inMotion);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i, 16);
			const t = n.text!;
			if (t.text.match("^%s*$")[0] !== undefined) return;
			if (t.fits) return;
			const o = textOverflow(ctx, n);
			const amount = math.max(o.x, o.y);
			if (amount < minPx) return;
			const axis = o.x >= o.y ? G.width(n.rect) : G.height(n.rect);
			const share = amount / math.max(1, axis);
			const hint = o.x >= o.y ? `needs ${px(o.measured.x)} wide (has ${px(G.width(n.rect))})` : `needs ${px(o.measured.y)} tall (has ${px(G.height(n.rect))})`;
			out.push(
				finding("TextOverflow", n, 0.35 + ramp(share, 0.02, 0.4) * 0.5, `text overflows by ${px(amount)}`, {
					metrics: { overflowX: o.x, overflowY: o.y, size: t.size },
					hint,
				}),
			);
		});
		return out;
	},
};

export const TextTooSmall: Rule = {
	id: "TextTooSmall",
	title: "Text renders below the legibility floor",
	profile: "lite",
	defaults: { minPxTouch: 11, minPxDesktop: 9 },
	run(ctx: RuleContext): Finding[] {
		const out: Finding[] = [];
		const floor = ctx.snap.viewport.touch ? ctx.param("minPxTouch", 11) : ctx.param("minPxDesktop", 9);
		const nodes = eligible(ctx.snap, "TextTooSmall", (n) => isText(n) && n.opacity < 0.9);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i, 64);
			const t = n.text!;
			const lines = t.wrapped ? math.max(1, math.floor(t.bounds.y / math.max(1, t.size) + 0.5)) : lineCount(t.text);
			const effective = t.scaled ? t.bounds.y / lines : t.size * ctx.snap.viewport.dpiScale;
			if (effective <= 0 || effective >= floor) return;
			out.push(
				finding("TextTooSmall", n, 0.2 + ramp(floor - effective, 0, floor / 2) * 0.5, `renders at ${px(effective)} (floor ${px(floor)})`, {
					metrics: { effective, floor },
				}),
			);
		});
		return out;
	},
};
