// Tooltip placement: pure math, no instances. Modeled on Floating UI's offset -> flip -> shift ->
// arrow pipeline (floating-ui.com/docs/middleware), adapted to Roblox screen space:
//   1. try the preferred side, then its opposite, then the two cross sides
//   2. score each by how far it overflows the bounds and how much it covers registered HUD rects
//   3. shift the winner along its side to stay inside the bounds
//   4. put the arrow where the target's center projects onto the bubble edge, kept off the corners
import type { TooltipSide } from "./content";

export interface Rect {
	x: number;
	y: number;
	w: number;
	h: number;
}

export interface PlaceInput {
	target: Rect;
	bubble: Vector2;
	bounds: Rect;
	side: TooltipSide;
	gap: number;
	/** screen rects the bubble should stay off (top bar, nav rail, buff strip...) */
	avoid: ReadonlyArray<Rect>;
	/** keep the arrow this far from the bubble corners */
	arrowInset: number;
}

export interface Placement {
	x: number;
	y: number;
	side: TooltipSide;
	/** arrow center along the bubble edge facing the target, in bubble pixels */
	arrow: number;
	/** the target was too big to point at cleanly (centered fallback) */
	fallback: boolean;
}

const OPPOSITE: { [K in TooltipSide]: TooltipSide } = { top: "bottom", bottom: "top", left: "right", right: "left" };
const CROSS: { [K in TooltipSide]: [TooltipSide, TooltipSide] } = {
	top: ["right", "left"],
	bottom: ["right", "left"],
	left: ["top", "bottom"],
	right: ["top", "bottom"],
};

export function sideOrder(preferred: TooltipSide): TooltipSide[] {
	const [a, b] = CROSS[preferred];
	return [preferred, OPPOSITE[preferred], a, b];
}

function overlapArea(a: Rect, b: Rect): number {
	const w = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x);
	const h = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y);
	return w > 0 && h > 0 ? w * h : 0;
}

function overflow(r: Rect, bounds: Rect): number {
	return (
		math.max(0, bounds.x - r.x) +
		math.max(0, r.x + r.w - (bounds.x + bounds.w)) +
		math.max(0, bounds.y - r.y) +
		math.max(0, r.y + r.h - (bounds.y + bounds.h))
	);
}

function raw(input: PlaceInput, side: TooltipSide): Rect {
	const t = input.target;
	const s = input.bubble;
	const cx = t.x + t.w / 2 - s.X / 2;
	const cy = t.y + t.h / 2 - s.Y / 2;
	if (side === "top") return { x: cx, y: t.y - input.gap - s.Y, w: s.X, h: s.Y };
	if (side === "bottom") return { x: cx, y: t.y + t.h + input.gap, w: s.X, h: s.Y };
	if (side === "right") return { x: t.x + t.w + input.gap, y: cy, w: s.X, h: s.Y };
	return { x: t.x - input.gap - s.X, y: cy, w: s.X, h: s.Y };
}

/** slide along the side's axis only, so the bubble never ends up on top of its target */
function shift(r: Rect, side: TooltipSide, bounds: Rect): Rect {
	const along = side === "top" || side === "bottom";
	if (along) {
		const x = math.clamp(r.x, bounds.x, math.max(bounds.x, bounds.x + bounds.w - r.w));
		return { x, y: r.y, w: r.w, h: r.h };
	}
	const y = math.clamp(r.y, bounds.y, math.max(bounds.y, bounds.y + bounds.h - r.h));
	return { x: r.x, y, w: r.w, h: r.h };
}

/** overflow counts most, then covering the target, then covering HUD, then distance from preference */
function score(r: Rect, input: PlaceInput, rank: number): number {
	let hud = 0;
	for (const zone of input.avoid) {
		hud += overlapArea(r, zone);
	}
	const area = math.max(1, r.w * r.h);
	return overflow(r, input.bounds) * 1000 + (overlapArea(r, input.target) / area) * 500 + (hud / area) * 200 + rank;
}

export function place(input: PlaceInput): Placement {
	let best: Rect | undefined;
	let bestSide: TooltipSide = input.side;
	let bestScore = math.huge;
	const order = sideOrder(input.side);
	for (let i = 0; i < order.size(); i++) {
		const side = order[i];
		const r = shift(raw(input, side), side, input.bounds);
		const s = score(r, input, i);
		if (s < bestScore) {
			best = r;
			bestSide = side;
			bestScore = s;
		}
		// first clean fit wins: no overflow, no target cover, no HUD cover
		if (s < 1 + i) {
			break;
		}
	}
	const r = best!;
	const b = input.bounds;
	const x = math.clamp(r.x, b.x, math.max(b.x, b.x + b.w - r.w));
	const y = math.clamp(r.y, b.y, math.max(b.y, b.y + b.h - r.h));
	const t = input.target;
	const along = bestSide === "top" || bestSide === "bottom";
	const length = along ? r.w : r.h;
	const center = along ? t.x + t.w / 2 - x : t.y + t.h / 2 - y;
	const inset = math.min(input.arrowInset, length / 2);
	const arrow = math.clamp(center, inset, length - inset);
	const fallback = overlapArea({ x, y, w: r.w, h: r.h }, t) > 0;
	return { x: math.round(x), y: math.round(y), side: bestSide, arrow: math.round(arrow), fallback };
}
