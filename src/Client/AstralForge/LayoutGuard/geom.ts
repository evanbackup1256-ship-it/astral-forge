// LayoutGuard geometry: axis-aligned and rotated rectangles, insets, polygon clipping and exact
// union area. Everything here is pure (no Instances, no services) so lune can test it directly.
//
// Conventions: screen space, +x right, +y down. A Rect is half-open [x0, x1) x [y0, y1); a rect with
// x1 <= x0 or y1 <= y0 is empty. Rotations are degrees clockwise, matching GuiObject.Rotation.

export interface Rect {
	x0: number;
	y0: number;
	x1: number;
	y1: number;
}

export interface Vec {
	x: number;
	y: number;
}

/** Per-side distances. Used for padding, safe-area insets and per-side overflow. */
export interface Insets {
	left: number;
	top: number;
	right: number;
	bottom: number;
}

export const EMPTY: Rect = table.freeze({ x0: 0, y0: 0, x1: 0, y1: 0 });
export const ZERO_INSETS: Insets = table.freeze({ left: 0, top: 0, right: 0, bottom: 0 });
const EPS = 1e-9;

export function isFiniteNumber(value: number): boolean {
	return value === value && value !== math.huge && value !== -math.huge;
}

export function rect(x0: number, y0: number, x1: number, y1: number): Rect {
	return { x0, y0, x1, y1 };
}

export function fromPosSize(x: number, y: number, w: number, h: number): Rect {
	return { x0: x, y0: y, x1: x + w, y1: y + h };
}

export function fromCenter(cx: number, cy: number, w: number, h: number): Rect {
	return { x0: cx - w / 2, y0: cy - h / 2, x1: cx + w / 2, y1: cy + h / 2 };
}

export function width(r: Rect): number {
	return math.max(0, r.x1 - r.x0);
}

export function height(r: Rect): number {
	return math.max(0, r.y1 - r.y0);
}

export function area(r: Rect): number {
	return width(r) * height(r);
}

export function isEmpty(r: Rect): boolean {
	return r.x1 - r.x0 <= EPS || r.y1 - r.y0 <= EPS;
}

export function isFiniteRect(r: Rect): boolean {
	return isFiniteNumber(r.x0) && isFiniteNumber(r.y0) && isFiniteNumber(r.x1) && isFiniteNumber(r.y1);
}

export function center(r: Rect): Vec {
	return { x: (r.x0 + r.x1) / 2, y: (r.y0 + r.y1) / 2 };
}

export function equals(a: Rect, b: Rect, tolerance = 0.5): boolean {
	return (
		math.abs(a.x0 - b.x0) <= tolerance &&
		math.abs(a.y0 - b.y0) <= tolerance &&
		math.abs(a.x1 - b.x1) <= tolerance &&
		math.abs(a.y1 - b.y1) <= tolerance
	);
}

/** Largest corner displacement between two rects; used to tell a moving element from a settled one. */
export function displacement(a: Rect, b: Rect): number {
	return math.max(math.abs(a.x0 - b.x0), math.abs(a.y0 - b.y0), math.abs(a.x1 - b.x1), math.abs(a.y1 - b.y1));
}

export function intersect(a: Rect, b: Rect): Rect {
	const x0 = math.max(a.x0, b.x0);
	const y0 = math.max(a.y0, b.y0);
	const x1 = math.min(a.x1, b.x1);
	const y1 = math.min(a.y1, b.y1);
	if (x1 <= x0 || y1 <= y0) {
		return { x0, y0, x1: x0, y1: y0 };
	}
	return { x0, y0, x1, y1 };
}

export function intersects(a: Rect, b: Rect): boolean {
	return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;
}

export function intersectionArea(a: Rect, b: Rect): number {
	const w = math.min(a.x1, b.x1) - math.max(a.x0, b.x0);
	const h = math.min(a.y1, b.y1) - math.max(a.y0, b.y0);
	return w > 0 && h > 0 ? w * h : 0;
}

/** Bounding union (not the exact union area; see unionArea for that). */
export function bounds(a: Rect, b: Rect): Rect {
	return { x0: math.min(a.x0, b.x0), y0: math.min(a.y0, b.y0), x1: math.max(a.x1, b.x1), y1: math.max(a.y1, b.y1) };
}

export function boundsOf(rects: ReadonlyArray<Rect>): Rect {
	if (rects.size() === 0) {
		return EMPTY;
	}
	let out = rects[0];
	for (let i = 1; i < rects.size(); i++) {
		out = bounds(out, rects[i]);
	}
	return out;
}

export function contains(outer: Rect, inner: Rect, slop = 0): boolean {
	return inner.x0 >= outer.x0 - slop && inner.y0 >= outer.y0 - slop && inner.x1 <= outer.x1 + slop && inner.y1 <= outer.y1 + slop;
}

export function containsPoint(r: Rect, x: number, y: number): boolean {
	return x >= r.x0 && x < r.x1 && y >= r.y0 && y < r.y1;
}

export function translate(r: Rect, dx: number, dy: number): Rect {
	return { x0: r.x0 + dx, y0: r.y0 + dy, x1: r.x1 + dx, y1: r.y1 + dy };
}

/** Shrinks by insets. Never inverts: a rect inset past its size collapses to its midline. */
export function inset(r: Rect, i: Insets): Rect {
	let x0 = r.x0 + i.left;
	let x1 = r.x1 - i.right;
	let y0 = r.y0 + i.top;
	let y1 = r.y1 - i.bottom;
	if (x1 < x0) {
		const mid = (x0 + x1) / 2;
		x0 = mid;
		x1 = mid;
	}
	if (y1 < y0) {
		const mid = (y0 + y1) / 2;
		y0 = mid;
		y1 = mid;
	}
	return { x0, y0, x1, y1 };
}

export function insetUniform(r: Rect, amount: number): Rect {
	return inset(r, { left: amount, top: amount, right: amount, bottom: amount });
}

export function outset(r: Rect, i: Insets): Rect {
	return { x0: r.x0 - i.left, y0: r.y0 - i.top, x1: r.x1 + i.right, y1: r.y1 + i.bottom };
}

export function addInsets(a: Insets, b: Insets): Insets {
	return { left: a.left + b.left, top: a.top + b.top, right: a.right + b.right, bottom: a.bottom + b.bottom };
}

export function maxInsets(a: Insets, b: Insets): Insets {
	return {
		left: math.max(a.left, b.left),
		top: math.max(a.top, b.top),
		right: math.max(a.right, b.right),
		bottom: math.max(a.bottom, b.bottom),
	};
}

/** Scales a rect about a pivot point (UIScale scales about the element's anchor point). */
export function scaleAbout(r: Rect, pivot: Vec, s: number): Rect {
	return {
		x0: pivot.x + (r.x0 - pivot.x) * s,
		y0: pivot.y + (r.y0 - pivot.y) * s,
		x1: pivot.x + (r.x1 - pivot.x) * s,
		y1: pivot.y + (r.y1 - pivot.y) * s,
	};
}

/** How far `inner` sticks out of `outer` on each side (0 where it doesn't). */
export function overflow(inner: Rect, outer: Rect): Insets {
	return {
		left: math.max(0, outer.x0 - inner.x0),
		top: math.max(0, outer.y0 - inner.y0),
		right: math.max(0, inner.x1 - outer.x1),
		bottom: math.max(0, inner.y1 - outer.y1),
	};
}

/** Largest single-side overflow; matches the old LayoutKit overflowAmount contract. */
export function overflowAmount(inner: Rect, outer: Rect): number {
	const o = overflow(inner, outer);
	return math.max(o.left, o.top, o.right, o.bottom);
}

/** Share of `inner`'s area that lies outside `outer` (0 = fully inside, 1 = fully outside). */
export function outsideShare(inner: Rect, outer: Rect): number {
	const a = area(inner);
	if (a <= 0) {
		return 0;
	}
	return 1 - intersectionArea(inner, outer) / a;
}

/** Smallest translation that brings `inner` inside `outer`; centres it when it is larger. */
export function nudgeInto(inner: Rect, outer: Rect): Vec {
	const w = width(inner);
	const h = height(inner);
	let dx = 0;
	let dy = 0;
	if (w > width(outer)) {
		dx = (outer.x0 + outer.x1) / 2 - (inner.x0 + inner.x1) / 2;
	} else if (inner.x0 < outer.x0) {
		dx = outer.x0 - inner.x0;
	} else if (inner.x1 > outer.x1) {
		dx = outer.x1 - inner.x1;
	}
	if (h > height(outer)) {
		dy = (outer.y0 + outer.y1) / 2 - (inner.y0 + inner.y1) / 2;
	} else if (inner.y0 < outer.y0) {
		dy = outer.y0 - inner.y0;
	} else if (inner.y1 > outer.y1) {
		dy = outer.y1 - inner.y1;
	}
	return { x: math.round(dx), y: math.round(dy) };
}

/** Euclidean gap between two rects (0 when they touch or overlap). */
export function gap(a: Rect, b: Rect): number {
	const dx = math.max(0, math.max(a.x0, b.x0) - math.min(a.x1, b.x1));
	const dy = math.max(0, math.max(a.y0, b.y0) - math.min(a.y1, b.y1));
	return math.sqrt(dx * dx + dy * dy);
}

/** Signed gaps on each axis: negative means overlap depth on that axis. */
export function axisGaps(a: Rect, b: Rect): Vec {
	return {
		x: math.max(a.x0, b.x0) - math.min(a.x1, b.x1),
		y: math.max(a.y0, b.y0) - math.min(a.y1, b.y1),
	};
}

/** Minimum translation vector to separate a from b (along the axis of least penetration). */
export function separation(a: Rect, b: Rect): Vec {
	const gp = axisGaps(a, b);
	if (gp.x >= 0 || gp.y >= 0) {
		return { x: 0, y: 0 };
	}
	// on each axis a can leave b on either side; when one rect contains the other the overlap
	// width is not enough, so take the true distance to each of b's edges
	const left = a.x1 - b.x0;
	const right = b.x1 - a.x0;
	const up = a.y1 - b.y0;
	const down = b.y1 - a.y0;
	const dx = left <= right ? -left : right;
	const dy = up <= down ? -up : down;
	if (math.abs(dx) <= math.abs(dy)) {
		return { x: dx, y: 0 };
	}
	return { x: 0, y: dy };
}

/** a minus b as up to four disjoint rects (top band, bottom band, left, right). */
export function subtract(a: Rect, b: Rect): Rect[] {
	if (!intersects(a, b)) {
		return isEmpty(a) ? [] : [a];
	}
	const out: Rect[] = [];
	const i = intersect(a, b);
	if (i.y0 > a.y0) out.push({ x0: a.x0, y0: a.y0, x1: a.x1, y1: i.y0 });
	if (i.y1 < a.y1) out.push({ x0: a.x0, y0: i.y1, x1: a.x1, y1: a.y1 });
	if (i.x0 > a.x0) out.push({ x0: a.x0, y0: i.y0, x1: i.x0, y1: i.y1 });
	if (i.x1 < a.x1) out.push({ x0: i.x1, y0: i.y0, x1: a.x1, y1: i.y1 });
	return out;
}

/** Removes every hole from `base`, returning the disjoint visible pieces. */
export function subtractAll(base: Rect, holes: ReadonlyArray<Rect>): Rect[] {
	let pieces: Rect[] = isEmpty(base) ? [] : [base];
	for (const hole of holes) {
		if (pieces.size() === 0) {
			break;
		}
		const nextPieces: Rect[] = [];
		for (const piece of pieces) {
			for (const rest of subtract(piece, hole)) {
				nextPieces.push(rest);
			}
		}
		pieces = nextPieces;
	}
	return pieces;
}

// ---------------------------------------------------------------------------------------------
// Exact union area: sweep over x with a segment tree on compressed y (O(n log n)).

interface SweepEvent {
	x: number;
	y0: number;
	y1: number;
	delta: number;
}

function uniqueSorted(values: number[]): number[] {
	values.sort((a, b) => a < b);
	const out: number[] = [];
	for (const v of values) {
		if (out.size() === 0 || math.abs(out[out.size() - 1] - v) > EPS) {
			out.push(v);
		}
	}
	return out;
}

function lowerBound(sorted: ReadonlyArray<number>, value: number): number {
	let lo = 0;
	let hi = sorted.size();
	while (lo < hi) {
		const mid = (lo + hi) >>> 1;
		if (sorted[mid] < value - EPS) {
			lo = mid + 1;
		} else {
			hi = mid;
		}
	}
	return lo;
}

/** Area covered by at least one rect, each clipped to `clip` when given. */
export function unionArea(rects: ReadonlyArray<Rect>, clip?: Rect): number {
	const events: SweepEvent[] = [];
	const ys: number[] = [];
	for (const raw of rects) {
		const r = clip !== undefined ? intersect(raw, clip) : raw;
		if (isEmpty(r) || !isFiniteRect(r)) {
			continue;
		}
		events.push({ x: r.x0, y0: r.y0, y1: r.y1, delta: 1 });
		events.push({ x: r.x1, y0: r.y0, y1: r.y1, delta: -1 });
		ys.push(r.y0);
		ys.push(r.y1);
	}
	if (events.size() === 0) {
		return 0;
	}
	const coords = uniqueSorted(ys);
	const segments = coords.size() - 1;
	if (segments <= 0) {
		return 0;
	}
	// count[node] = how many rects fully cover the node's range; len[node] = covered length below it
	const count: number[] = [];
	const len: number[] = [];
	for (let i = 0; i < segments * 4; i++) {
		count.push(0);
		len.push(0);
	}
	const update = (node: number, lo: number, hi: number, a: number, b: number, delta: number) => {
		if (b <= lo || hi <= a) {
			return;
		}
		if (a <= lo && hi <= b) {
			count[node] += delta;
		} else {
			const mid = (lo + hi) >>> 1;
			update(node * 2 + 1, lo, mid, a, b, delta);
			update(node * 2 + 2, mid, hi, a, b, delta);
		}
		if (count[node] > 0) {
			len[node] = coords[hi] - coords[lo];
		} else if (hi - lo === 1) {
			len[node] = 0;
		} else {
			len[node] = len[node * 2 + 1] + len[node * 2 + 2];
		}
	};
	events.sort((a, b) => (a.x === b.x ? a.delta > b.delta : a.x < b.x));
	let total = 0;
	let lastX = events[0].x;
	for (const e of events) {
		total += len[0] * (e.x - lastX);
		lastX = e.x;
		update(0, 0, segments, lowerBound(coords, e.y0), lowerBound(coords, e.y1), e.delta);
	}
	return total;
}

/** Fraction of `container` covered by `rects` (exact, overlaps counted once). */
export function coverage(container: Rect, rects: ReadonlyArray<Rect>): number {
	const a = area(container);
	if (a <= 0) {
		return 0;
	}
	return math.clamp(unionArea(rects, container) / a, 0, 1);
}

// ---------------------------------------------------------------------------------------------
// Rotated rectangles. GuiObject.Rotation rotates about the element's centre (not its anchor).

export interface Obb {
	cx: number;
	cy: number;
	hw: number;
	hh: number;
	/** radians, clockwise in screen space */
	angle: number;
}

export function obbFromRect(r: Rect, rotationDegrees: number): Obb {
	const c = center(r);
	return { cx: c.x, cy: c.y, hw: width(r) / 2, hh: height(r) / 2, angle: math.rad(rotationDegrees) };
}

export function rotatePoint(p: Vec, pivot: Vec, radians: number): Vec {
	const c = math.cos(radians);
	const s = math.sin(radians);
	const dx = p.x - pivot.x;
	const dy = p.y - pivot.y;
	return { x: pivot.x + dx * c - dy * s, y: pivot.y + dx * s + dy * c };
}

/** Corners clockwise from top-left. */
export function obbCorners(o: Obb): Vec[] {
	const c = math.cos(o.angle);
	const s = math.sin(o.angle);
	const corner = (lx: number, ly: number): Vec => ({ x: o.cx + lx * c - ly * s, y: o.cy + lx * s + ly * c });
	return [corner(-o.hw, -o.hh), corner(o.hw, -o.hh), corner(o.hw, o.hh), corner(-o.hw, o.hh)];
}

export function obbBounds(o: Obb): Rect {
	const c = math.abs(math.cos(o.angle));
	const s = math.abs(math.sin(o.angle));
	const ex = o.hw * c + o.hh * s;
	const ey = o.hw * s + o.hh * c;
	return { x0: o.cx - ex, y0: o.cy - ey, x1: o.cx + ex, y1: o.cy + ey };
}

function projectOnto(points: ReadonlyArray<Vec>, ax: number, ay: number): [number, number] {
	let lo = math.huge;
	let hi = -math.huge;
	for (const p of points) {
		const d = p.x * ax + p.y * ay;
		lo = math.min(lo, d);
		hi = math.max(hi, d);
	}
	return [lo, hi];
}

/** Separating-axis test for two oriented boxes. */
export function obbIntersects(a: Obb, b: Obb): boolean {
	const pa = obbCorners(a);
	const pb = obbCorners(b);
	const axes: [number, number][] = [
		[math.cos(a.angle), math.sin(a.angle)],
		[-math.sin(a.angle), math.cos(a.angle)],
		[math.cos(b.angle), math.sin(b.angle)],
		[-math.sin(b.angle), math.cos(b.angle)],
	];
	for (const [ax, ay] of axes) {
		const [aLo, aHi] = projectOnto(pa, ax, ay);
		const [bLo, bHi] = projectOnto(pb, ax, ay);
		if (aHi <= bLo + EPS || bHi <= aLo + EPS) {
			return false;
		}
	}
	return true;
}

/** Shoelace area of a simple polygon (absolute). */
export function polygonArea(points: ReadonlyArray<Vec>): number {
	const n = points.size();
	if (n < 3) {
		return 0;
	}
	let sum = 0;
	for (let i = 0; i < n; i++) {
		const p = points[i];
		const q = points[(i + 1) % n];
		sum += p.x * q.y - q.x * p.y;
	}
	return math.abs(sum) / 2;
}

function signedArea(points: ReadonlyArray<Vec>): number {
	let sum = 0;
	const n = points.size();
	for (let i = 0; i < n; i++) {
		const p = points[i];
		const q = points[(i + 1) % n];
		sum += p.x * q.y - q.x * p.y;
	}
	return sum / 2;
}

function cross(o: Vec, a: Vec, b: Vec): number {
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
}

function lineIntersection(p: Vec, q: Vec, a: Vec, b: Vec): Vec {
	const a1 = q.y - p.y;
	const b1 = p.x - q.x;
	const c1 = a1 * p.x + b1 * p.y;
	const a2 = b.y - a.y;
	const b2 = a.x - b.x;
	const c2 = a2 * a.x + b2 * a.y;
	const det = a1 * b2 - a2 * b1;
	if (math.abs(det) < EPS) {
		return q;
	}
	return { x: (b2 * c1 - b1 * c2) / det, y: (a1 * c2 - a2 * c1) / det };
}

/** Sutherland–Hodgman: clips `subject` by the convex polygon `clipPoly`. */
export function clipPolygon(subject: ReadonlyArray<Vec>, clipPoly: ReadonlyArray<Vec>): Vec[] {
	let output: Vec[] = [...subject];
	const n = clipPoly.size();
	if (n < 3) {
		return [];
	}
	// orientation of the clip polygon decides which side of each edge is "inside"
	const orientation = signedArea(clipPoly) >= 0 ? 1 : -1;
	for (let i = 0; i < n; i++) {
		if (output.size() === 0) {
			break;
		}
		const a = clipPoly[i];
		const b = clipPoly[(i + 1) % n];
		const input = output;
		output = [];
		for (let j = 0; j < input.size(); j++) {
			const current = input[j];
			const previous = input[(j + input.size() - 1) % input.size()];
			const currentInside = cross(a, b, current) * orientation >= -EPS;
			const previousInside = cross(a, b, previous) * orientation >= -EPS;
			if (currentInside) {
				if (!previousInside) {
					output.push(lineIntersection(previous, current, a, b));
				}
				output.push(current);
			} else if (previousInside) {
				output.push(lineIntersection(previous, current, a, b));
			}
		}
	}
	return output;
}

/** Exact intersection area of two oriented boxes. */
export function obbIntersectionArea(a: Obb, b: Obb): number {
	if (!intersects(obbBounds(a), obbBounds(b))) {
		return 0;
	}
	if (math.abs(a.angle) < EPS && math.abs(b.angle) < EPS) {
		return intersectionArea(obbBounds(a), obbBounds(b));
	}
	return polygonArea(clipPolygon(obbCorners(a), obbCorners(b)));
}

export function obbArea(o: Obb): number {
	return 4 * o.hw * o.hh;
}

/** Rect sizes are snapped to whole pixels by the engine; keep comparisons on the same grid. */
export function snap(r: Rect): Rect {
	return { x0: math.round(r.x0), y0: math.round(r.y0), x1: math.round(r.x1), y1: math.round(r.y1) };
}

export function describe(r: Rect): string {
	return string.format("(%d,%d %dx%d)", math.floor(r.x0), math.floor(r.y0), math.floor(width(r)), math.floor(height(r)));
}
