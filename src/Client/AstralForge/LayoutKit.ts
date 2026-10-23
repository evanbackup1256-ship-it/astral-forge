import { isConstrainedInput } from "./CoreKit/inputLayer";
import type React from "@rbxts/react";

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`LayoutKit: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`LayoutKit: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

type LuaKit = (name: string) => unknown;
type LooseCreate = (type: unknown, props?: { [key: string]: unknown }, ...children: unknown[]) => React.ReactElement;
type Binding<T> = React.Binding<T>;
type MutableRefObject<T> = React.MutableRefObject<T>;
type Context<T> = React.Context<T>;

const AstralForge = script.Parent!;

function kitMember(kit: string, member: string): unknown {
	return (require(AstralForge.FindFirstChild(kit)! as ModuleScript) as LuaKit)(member);
}

function loadReact(): typeof import("@rbxts/react") {
	return require(
		game
			.GetService("ReplicatedStorage")
			.WaitForChild("rbxts_include")
			.WaitForChild("node_modules")
			.WaitForChild("@rbxts")
			.WaitForChild("react") as ModuleScript,
	) as typeof import("@rbxts/react");
}

interface AudioPlayer {
	play(name: string, ...rest: unknown[]): unknown;
	[key: string]: unknown;
}

interface ScrollHostContext {
	hostRef: MutableRefObject<ScrollingFrame | undefined>;
	sectionRef: MutableRefObject<GuiObject | undefined>;
	overflowing: boolean;
	report: (height: number) => void;
}

interface VirtualWindow {
	frame: MutableRefObject<ScrollingFrame | undefined>;
	first: number;
	last: number;
}

interface ScrollingModule {
	disposeScrollPerformance: () => void;
	setScrollSpeed: (value: number) => void;
	setScrollMomentum: (value: number) => void;
	installScrollPerformance: () => () => void;
	AutoGrid: React.FunctionComponent<Record<string, unknown>>;
	VirtualGrid: React.FunctionComponent<Record<string, unknown>>;
	useVirtualWindow: (
		count: number,
		stride: number,
		topOffset: number,
		overscan?: number,
		hostRef?: MutableRefObject<ScrollingFrame | undefined>,
	) => VirtualWindow;
	PageScrollContext: Context<ScrollHostContext | undefined>;
}

interface ScaffoldSection {
	id?: unknown;
	fill?: boolean;
	height?: number;
	minHeight?: number;
	stretch?: boolean;
	element?: unknown;
	[key: string]: unknown;
}

interface ScaffoldPlanModule {
	planFillHeight: (sections: ReadonlyArray<ScaffoldSection>, availableHeight: number, gap?: number, tailPad?: number) => number;
	planFittedHeights: (
		sections: ReadonlyArray<ScaffoldSection>,
		availableHeight: number,
		gap?: number,
		tailPad?: number,
	) => number[];
	planOverflow: (sections: ReadonlyArray<ScaffoldSection>, availableHeight: number, gap?: number, tailPad?: number) => boolean;
}

interface GridLayoutInfo {
	columns: number;
	cellWidth: number;
	cellHeight: number;
	contentWidth: number;
}

interface GridBreakpoint {
	minWidth: number;
	columns: number;
}

__defs["layoutGeom"] = () => {
	const EPS = 1e-4;
	const INF = math.huge;

	interface Vec2 {
		x: number;
		y: number;
	}
	interface Rect {
		x0: number;
		y0: number;
		x1: number;
		y1: number;
	}
	interface Insets {
		l: number;
		t: number;
		r: number;
		b: number;
	}
	interface UDim1 {
		scale: number;
		offset: number;
	}

	function eps(): number {
		return EPS;
	}

	function finite(value: number): boolean {
		return value === value && value !== INF && value !== -INF;
	}

	function clamp(value: number, lo: number, hi: number): number {
		if (hi < lo) {
			const t = lo;
			lo = hi;
			hi = t;
		}
		if (!finite(value)) {
			return lo;
		}
		if (value < lo) {
			return lo;
		}
		if (value > hi) {
			return hi;
		}
		return value;
	}

	function lerp(a: number, b: number, t: number): number {
		return a + (b - a) * clamp(t, 0, 1);
	}

	function inverseLerp(a: number, b: number, value: number): number {
		const span = b - a;
		if (math.abs(span) < EPS) {
			return 0;
		}
		return clamp((value - a) / span, 0, 1);
	}

	function smoothstep(t: number): number {
		const x = clamp(t, 0, 1);
		return x * x * (3 - 2 * x);
	}

	function smootherstep(t: number): number {
		const x = clamp(t, 0, 1);
		return x * x * x * (x * (x * 6 - 15) + 10);
	}

	function sign(value: number): number {
		if (value > EPS) {
			return 1;
		}
		if (value < -EPS) {
			return -1;
		}
		return 0;
	}

	function snap(value: number, step: number): number {
		if (step <= EPS) {
			return value;
		}
		return math.floor(value / step + 0.5) * step;
	}

	function snapPixel(value: number): number {
		return math.floor(value + 0.5);
	}

	function approach(current: number, target: number, maxDelta: number): number {
		const delta = target - current;
		if (math.abs(delta) <= maxDelta) {
			return target;
		}
		return current + sign(delta) * maxDelta;
	}

	function damp(current: number, target: number, rate: number): number {
		const t = clamp(rate, 0, 1);
		return current + (target - current) * t;
	}

	function vec(x: number, y: number): Vec2 {
		return { x, y };
	}

	function vadd(a: Vec2, b: Vec2): Vec2 {
		return { x: a.x + b.x, y: a.y + b.y };
	}

	function vsub(a: Vec2, b: Vec2): Vec2 {
		return { x: a.x - b.x, y: a.y - b.y };
	}

	function vmul(a: Vec2, s: number): Vec2 {
		return { x: a.x * s, y: a.y * s };
	}

	function vdot(a: Vec2, b: Vec2): number {
		return a.x * b.x + a.y * b.y;
	}

	function vcross(a: Vec2, b: Vec2): number {
		return a.x * b.y - a.y * b.x;
	}

	function vlen2(a: Vec2): number {
		return a.x * a.x + a.y * a.y;
	}

	function vlen(a: Vec2): number {
		return math.sqrt(vlen2(a));
	}

	function vnorm(a: Vec2): Vec2 {
		const length = vlen(a);
		if (length < EPS) {
			return { x: 0, y: 0 };
		}
		return { x: a.x / length, y: a.y / length };
	}

	function vperp(a: Vec2): Vec2 {
		return { x: -a.y, y: a.x };
	}

	function vreflect(direction: Vec2, normal: Vec2): Vec2 {
		const n = vnorm(normal);
		const scale = 2 * vdot(direction, n);
		return vsub(direction, vmul(n, scale));
	}

	function vproject(a: Vec2, onto: Vec2): Vec2 {
		const denom = vlen2(onto);
		if (denom < EPS) {
			return { x: 0, y: 0 };
		}
		return vmul(onto, vdot(a, onto) / denom);
	}

	function vrotate(a: Vec2, radians: number): Vec2 {
		const c = math.cos(radians);
		const s = math.sin(radians);
		return { x: a.x * c - a.y * s, y: a.x * s + a.y * c };
	}

	function vlerp(a: Vec2, b: Vec2, t: number): Vec2 {
		return { x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t) };
	}

	function vmin(a: Vec2, b: Vec2): Vec2 {
		return { x: math.min(a.x, b.x), y: math.min(a.y, b.y) };
	}

	function vmax(a: Vec2, b: Vec2): Vec2 {
		return { x: math.max(a.x, b.x), y: math.max(a.y, b.y) };
	}

	function vfloor(a: Vec2): Vec2 {
		return { x: snapPixel(a.x), y: snapPixel(a.y) };
	}

	function rect(x0: number, y0: number, x1: number, y1: number): Rect {
		if (x1 < x0) {
			const t = x0;
			x0 = x1;
			x1 = t;
		}
		if (y1 < y0) {
			const t = y0;
			y0 = y1;
			y1 = t;
		}
		return { x0, y0, x1, y1 };
	}

	function rectFromPosSize(x: number, y: number, w: number, h: number): Rect {
		return rect(x, y, x + math.max(0, w), y + math.max(0, h));
	}

	function rectFromCenter(cx: number, cy: number, w: number, h: number): Rect {
		return rectFromPosSize(cx - w * 0.5, cy - h * 0.5, w, h);
	}

	function rectWidth(r: Rect): number {
		return math.max(0, r.x1 - r.x0);
	}

	function rectHeight(r: Rect): number {
		return math.max(0, r.y1 - r.y0);
	}

	function rectArea(r: Rect): number {
		return rectWidth(r) * rectHeight(r);
	}

	function rectCenter(r: Rect): Vec2 {
		return { x: (r.x0 + r.x1) * 0.5, y: (r.y0 + r.y1) * 0.5 };
	}

	function rectContainsPoint(r: Rect, p: Vec2, slop?: number): boolean {
		const pad = slop ?? 0;
		return p.x >= r.x0 - pad && p.x <= r.x1 + pad && p.y >= r.y0 - pad && p.y <= r.y1 + pad;
	}

	function rectContainsRect(outer: Rect, inner: Rect, slop?: number): boolean {
		const pad = slop ?? 0;
		return inner.x0 >= outer.x0 - pad && inner.y0 >= outer.y0 - pad && inner.x1 <= outer.x1 + pad && inner.y1 <= outer.y1 + pad;
	}

	function rectIntersects(a: Rect, b: Rect): boolean {
		return a.x0 < b.x1 && b.x0 < a.x1 && a.y0 < b.y1 && b.y0 < a.y1;
	}

	function rectIntersection(a: Rect, b: Rect): Rect | undefined {
		const x0 = math.max(a.x0, b.x0);
		const y0 = math.max(a.y0, b.y0);
		const x1 = math.min(a.x1, b.x1);
		const y1 = math.min(a.y1, b.y1);
		if (x1 <= x0 || y1 <= y0) {
			return undefined;
		}
		return { x0, y0, x1, y1 };
	}

	function rectUnion(a: Rect, b: Rect): Rect {
		return {
			x0: math.min(a.x0, b.x0),
			y0: math.min(a.y0, b.y0),
			x1: math.max(a.x1, b.x1),
			y1: math.max(a.y1, b.y1),
		};
	}

	function rectInflate(r: Rect, px: number, py?: number): Rect {
		const dy = py ?? px;
		return { x0: r.x0 - px, y0: r.y0 - dy, x1: r.x1 + px, y1: r.y1 + dy };
	}

	function rectTranslate(r: Rect, dx: number, dy: number): Rect {
		return { x0: r.x0 + dx, y0: r.y0 + dy, x1: r.x1 + dx, y1: r.y1 + dy };
	}

	function overlapWidth(a: Rect, b: Rect): number {
		return math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0));
	}

	function overlapHeight(a: Rect, b: Rect): number {
		return math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0));
	}

	function overlapArea(a: Rect, b: Rect): number {
		return overlapWidth(a, b) * overlapHeight(a, b);
	}

	function iou(a: Rect, b: Rect): number {
		const inter = overlapArea(a, b);
		if (inter <= 0) {
			return 0;
		}
		const union = rectArea(a) + rectArea(b) - inter;
		if (union <= EPS) {
			return 0;
		}
		return inter / union;
	}

	function coverage(inner: Rect, outer: Rect): number {
		const area = rectArea(inner);
		if (area <= EPS) {
			return 0;
		}
		return overlapArea(inner, outer) / area;
	}

	function overflow(inner: Rect, outer: Rect): Insets {
		return {
			l: math.max(0, outer.x0 - inner.x0),
			t: math.max(0, outer.y0 - inner.y0),
			r: math.max(0, inner.x1 - outer.x1),
			b: math.max(0, inner.y1 - outer.y1),
		};
	}

	function overflowAmount(inner: Rect, outer: Rect): number {
		const o = overflow(inner, outer);
		return o.l + o.t + o.r + o.b;
	}

	function insets(l: number, t: number, r: number, b: number): Insets {
		return { l, t, r, b };
	}

	function insetRect(r: Rect, pad: Insets): Rect {
		let x0 = r.x0 + pad.l;
		let y0 = r.y0 + pad.t;
		let x1 = r.x1 - pad.r;
		let y1 = r.y1 - pad.b;
		if (x1 < x0) {
			const mid = (x0 + x1) * 0.5;
			x0 = mid;
			x1 = mid;
		}
		if (y1 < y0) {
			const mid = (y0 + y1) * 0.5;
			y0 = mid;
			y1 = mid;
		}
		return { x0, y0, x1, y1 };
	}

	function udim(scale: number, offset: number, axis: number): number {
		if (!finite(scale)) {
			scale = 0;
		}
		if (!finite(offset)) {
			offset = 0;
		}
		return scale * axis + offset;
	}

	function splitUDim(pixels: number, axis: number, preferScale: boolean): UDim1 {
		if (axis <= EPS || !preferScale) {
			return { scale: 0, offset: pixels };
		}
		const scale = pixels / axis;
		return { scale, offset: 0 };
	}

	function fitRect(rect: Rect, box: Rect, anchorX: number, anchorY: number, minW: number, minH: number): Rect {
		const boxW = rectWidth(box);
		const boxH = rectHeight(box);
		const w = clamp(rectWidth(rect), math.min(minW, boxW), boxW);
		const h = clamp(rectHeight(rect), math.min(minH, boxH), boxH);
		const ax = clamp(anchorX, 0, 1);
		const ay = clamp(anchorY, 0, 1);
		const anchorPx = rect.x0 + rectWidth(rect) * ax;
		const anchorPy = rect.y0 + rectHeight(rect) * ay;
		let x = anchorPx - w * ax;
		let y = anchorPy - h * ay;
		x = clamp(x, box.x0, box.x1 - w);
		y = clamp(y, box.y0, box.y1 - h);
		return rectFromPosSize(x, y, w, h);
	}

	function separation(mover: Rect, blocker: Rect): Vec2 | undefined {
		const iw = overlapWidth(mover, blocker);
		const ih = overlapHeight(mover, blocker);
		if (iw <= EPS || ih <= EPS) {
			return undefined;
		}
		const mc = rectCenter(mover);
		const bc = rectCenter(blocker);
		if (iw < ih) {
			const dir = mc.x >= bc.x ? 1 : -1;
			return { x: dir * iw, y: 0 };
		}
		const dir = mc.y >= bc.y ? 1 : -1;
		return { x: 0, y: dir * ih };
	}

	function corners(r: Rect): Vec2[] {
		return [
			{ x: r.x0, y: r.y0 },
			{ x: r.x1, y: r.y0 },
			{ x: r.x1, y: r.y1 },
			{ x: r.x0, y: r.y1 },
		];
	}

	function rotateCorners(r: Rect, radians: number): Vec2[] {
		const c = rectCenter(r);
		const out: Vec2[] = [];
		for (const [, corner] of ipairs(corners(r))) {
			const rel = vsub(corner, c);
			out.push(vadd(c, vrotate(rel, radians)));
		}
		return out;
	}

	function projectPolygon(points: Vec2[], axis: Vec2): LuaTuple<[number, number]> {
		let minV = INF;
		let maxV = -INF;
		for (const point of points) {
			const d = vdot(point, axis);
			if (d < minV) {
				minV = d;
			}
			if (d > maxV) {
				maxV = d;
			}
		}
		return $tuple(minV, maxV);
	}

	function edgeAxes(points: Vec2[]): Vec2[] {
		const axes: Vec2[] = [];
		for (const index of $range(1, points.size())) {
			const a = points[index - 1];
			const b = points[index % points.size()];
			const edge = vsub(b, a);
			const normal = vnorm(vperp(edge));
			if (vlen2(normal) > EPS) {
				axes.push(normal);
			}
		}
		return axes;
	}

	function satMTV(aPoints: Vec2[], bPoints: Vec2[]): Vec2 | undefined {
		const axes = edgeAxes(aPoints);
		for (const axis of edgeAxes(bPoints)) {
			axes.push(axis);
		}
		let best = INF;
		let bestAxis: Vec2 | undefined = undefined;
		for (const axis of axes) {
			const [a0, a1] = projectPolygon(aPoints, axis);
			const [b0, b1] = projectPolygon(bPoints, axis);
			const overlap = math.min(a1, b1) - math.max(a0, b0);
			if (overlap <= EPS) {
				return undefined;
			}
			if (overlap < best) {
				best = overlap;
				bestAxis = axis;
			}
		}
		if (bestAxis === undefined) {
			return undefined;
		}
		let ac: Vec2 = { x: 0, y: 0 };
		let bc: Vec2 = { x: 0, y: 0 };
		for (const point of aPoints) {
			ac = vadd(ac, point);
		}
		for (const point of bPoints) {
			bc = vadd(bc, point);
		}
		ac = vmul(ac, 1 / math.max(1, aPoints.size()));
		bc = vmul(bc, 1 / math.max(1, bPoints.size()));
		const direction = vsub(ac, bc);
		if (vdot(direction, bestAxis) < 0) {
			bestAxis = vmul(bestAxis, -1);
		}
		return vmul(vnorm(bestAxis), best);
	}

	function obbMTV(a: Rect, aRot: number, b: Rect, bRot: number): Vec2 | undefined {
		if (math.abs(aRot) < EPS && math.abs(bRot) < EPS) {
			return separation(a, b);
		}
		return satMTV(rotateCorners(a, aRot), rotateCorners(b, bRot));
	}

	interface SpatialHash {
		cell: number;
		buckets: Record<string, number[]>;
	}

	function spatial(cell: number): SpatialHash {
		return { cell: math.max(8, cell), buckets: {} };
	}

	function cellKey(ix: number, iy: number): string {
		return `${ix}:${iy}`;
	}

	function spatialInsert(hash: SpatialHash, index: number, r: Rect): void {
		const cell = hash.cell;
		const x0 = math.floor(r.x0 / cell);
		const y0 = math.floor(r.y0 / cell);
		const x1 = math.floor(r.x1 / cell);
		const y1 = math.floor(r.y1 / cell);
		for (const ix of $range(x0, x1)) {
			for (const iy of $range(y0, y1)) {
				const key = cellKey(ix, iy);
				let bucket = hash.buckets[key];
				if (bucket === undefined) {
					bucket = [];
					hash.buckets[key] = bucket;
				}
				bucket.push(index);
			}
		}
	}

	function spatialQuery(hash: SpatialHash, r: Rect): number[] {
		const seen: Record<number, boolean> = {};
		const hits: number[] = [];
		const cell = hash.cell;
		const x0 = math.floor(r.x0 / cell);
		const y0 = math.floor(r.y0 / cell);
		const x1 = math.floor(r.x1 / cell);
		const y1 = math.floor(r.y1 / cell);
		for (const ix of $range(x0, x1)) {
			for (const iy of $range(y0, y1)) {
				const bucket = hash.buckets[cellKey(ix, iy)];
				if (bucket !== undefined) {
					for (const index of bucket) {
						if (!seen[index]) {
							seen[index] = true;
							hits.push(index);
						}
					}
				}
			}
		}
		return hits;
	}

	function sweepPairs(rects: Rect[]): number[][] {
		const order = table.create<number>(rects.size());
		for (const index of $range(1, rects.size())) {
			order[index - 1] = index;
		}
		table.sort(order, (a, b) => rects[a - 1].x0 < rects[b - 1].x0);
		const overlapPairs: number[][] = [];
		let active: number[] = [];
		for (const index of order) {
			const r = rects[index - 1];
			const nextActive: number[] = [];
			for (const other of active) {
				const orect = rects[other - 1];
				if (orect.x1 > r.x0) {
					nextActive.push(other);
					if (overlapHeight(r, orect) > EPS) {
						const lo = math.min(index, other);
						const hi = math.max(index, other);
						overlapPairs.push([lo, hi]);
					}
				}
			}
			nextActive.push(index);
			active = nextActive;
		}
		return overlapPairs;
	}

	function readingOrder(rects: Rect[], band: number): number[] {
		const order = table.create<number>(rects.size());
		for (const index of $range(1, rects.size())) {
			order[index - 1] = index;
		}
		table.sort(order, (a, b) => {
			const ra = rects[a - 1];
			const rb = rects[b - 1];
			const bandA = math.floor(ra.y0 / math.max(8, band));
			const bandB = math.floor(rb.y0 / math.max(8, band));
			if (bandA !== bandB) {
				return bandA < bandB;
			}
			if (math.abs(ra.x0 - rb.x0) > EPS) {
				return ra.x0 < rb.x0;
			}
			return a < b;
		});
		return order;
	}

	function rowBands(rects: Rect[], slack: number): number[][] {
		const order = readingOrder(rects, 1);
		const rows: number[][] = [];
		let current: number[] = [];
		let bandBottom = -INF;
		for (const index of order) {
			const r = rects[index - 1];
			if (current.size() === 0 || r.y0 <= bandBottom + slack) {
				current.push(index);
				bandBottom = math.max(bandBottom, r.y1);
			} else {
				rows.push(current);
				current = [index];
				bandBottom = r.y1;
			}
		}
		if (current.size() > 0) {
			rows.push(current);
		}
		return rows;
	}

	function packRow(rects: Rect[], indexes: number[], gap: number, minW: number, rightLimit: number): Record<number, number> {
		const placed: Record<number, number> = {};
		if (indexes.size() === 0) {
			return placed;
		}
		let cursor = rects[indexes[0] - 1].x0;
		let total = gap * math.max(0, indexes.size() - 1);
		for (const index of indexes) {
			total += math.max(minW, rectWidth(rects[index - 1]));
		}
		const available = rightLimit - cursor;
		let scale = 1;
		if (total > available && total > EPS) {
			scale = math.max(0.45, available / total);
		}
		for (const index of indexes) {
			let width = math.max(minW, rectWidth(rects[index - 1]) * scale);
			if (cursor + width > rightLimit && cursor > rects[indexes[0] - 1].x0) {
				width = math.max(minW, rightLimit - cursor);
			}
			placed[index] = cursor;
			cursor += width + gap;
		}
		return placed;
	}

	function packColumn(rects: Rect[], indexes: number[], gap: number, minH: number, bottomLimit: number): Record<number, number> {
		const placed: Record<number, number> = {};
		if (indexes.size() === 0) {
			return placed;
		}
		let cursor = rects[indexes[0] - 1].y0;
		for (const index of indexes) {
			let height = math.max(minH, rectHeight(rects[index - 1]));
			if (cursor + height > bottomLimit && cursor > rects[indexes[0] - 1].y0) {
				height = math.max(minH * 0.5, bottomLimit - cursor);
			}
			placed[index] = cursor;
			cursor += height + gap;
		}
		return placed;
	}

	function fitTextScale(
		boxW: number,
		boxH: number,
		design: number,
		minSize: number,
		maxSize: number,
		measure: (size: number) => LuaTuple<[number, number]>,
	): number {
		let lo = math.max(1, minSize);
		let hi = math.max(lo, math.min(maxSize, design));
		if (boxW <= 1 || boxH <= 1) {
			return lo;
		}
		let best = lo;
		for (const _ of $range(1, 12)) {
			const mid = (lo + hi) * 0.5;
			const [w, h] = measure(mid);
			if (w <= boxW + 0.5 && h <= boxH + 0.5) {
				best = mid;
				lo = mid;
			} else {
				hi = mid;
			}
			if (hi - lo < 0.25) {
				break;
			}
		}
		return best;
	}

	function projectScalar(value: number, target: number, limit: number, residual: number): LuaTuple<[number, number]> {
		const delta = clamp(target - value, -limit, limit);
		let nextValue = value + delta;
		let nextResidual = math.abs(target - nextValue);
		if (nextResidual > residual + EPS && residual < INF / 2) {
			nextValue = damp(value, target, 0.35);
			nextResidual = math.abs(target - nextValue);
		}
		return $tuple(nextValue, nextResidual);
	}

	function anchorTopLeft(anchorX: number, anchorY: number, x: number, y: number, w: number, h: number): Vec2 {
		return { x: x - w * anchorX, y: y - h * anchorY };
	}

	function topLeftToAnchor(anchorX: number, anchorY: number, x: number, y: number, w: number, h: number): Vec2 {
		return { x: x + w * anchorX, y: y + h * anchorY };
	}

	function offsetDelta(anchorX: number, anchorY: number, dx: number, dy: number, dw: number, dh: number): Vec2 {
		return {
			x: dx + anchorX * dw,
			y: dy + anchorY * dh,
		};
	}

	const Geom = {
		eps,
		finite,
		clamp,
		lerp,
		inverseLerp,
		smoothstep,
		smootherstep,
		sign,
		snap,
		snapPixel,
		approach,
		damp,
		vec,
		vadd,
		vsub,
		vmul,
		vdot,
		vcross,
		vlen2,
		vlen,
		vnorm,
		vperp,
		vreflect,
		vproject,
		vrotate,
		vlerp,
		vmin,
		vmax,
		vfloor,
		rect,
		rectFromPosSize,
		rectFromCenter,
		rectWidth,
		rectHeight,
		rectArea,
		rectCenter,
		rectContainsPoint,
		rectContainsRect,
		rectIntersects,
		rectIntersection,
		rectUnion,
		rectInflate,
		rectTranslate,
		overlapWidth,
		overlapHeight,
		overlapArea,
		iou,
		coverage,
		overflow,
		overflowAmount,
		insets,
		insetRect,
		udim,
		splitUDim,
		fitRect,
		separation,
		corners,
		rotateCorners,
		satMTV,
		obbMTV,
		spatial,
		spatialInsert,
		spatialQuery,
		sweepPairs,
		readingOrder,
		rowBands,
		packRow,
		packColumn,
		fitTextScale,
		projectScalar,
		anchorTopLeft,
		topLeftToAnchor,
		offsetDelta,
	};

	return Geom;
};

__defs["layoutGuardPlan"] = () => {
	interface Budget {
		fresh: number;
		sweep: number;
	}
	interface LabelBox {
		x0: number;
		y0: number;
		x1: number;
		y1: number;
	}

	function budget(burstFramesLeft: number, freshWaiting: number): Budget {
		if (burstFramesLeft > 0) {
			const fresh = math.min(freshWaiting, Plan.BURST_PER_FRAME);
			return { fresh, sweep: Plan.BURST_PER_FRAME - fresh };
		}
		return { fresh: math.min(freshWaiting, Plan.FRESH_PER_FRAME), sweep: Plan.SWEEP_PER_FRAME };
	}

	function resized(lastWidth: number, lastHeight: number, width: number, height: number): boolean {
		if (lastWidth < 0 || lastHeight < 0) {
			return true;
		}
		const rotated = lastWidth > lastHeight !== width > height && math.abs(width - height) > Plan.RESIZE_SLOP;
		return rotated || math.abs(width - lastWidth) >= Plan.RESIZE_SLOP || math.abs(height - lastHeight) >= Plan.RESIZE_SLOP;
	}

	function textFloor(touch: boolean, textSize: number, scaled: boolean): number | undefined {
		if (!touch || scaled) {
			return undefined;
		}
		if (textSize >= Plan.TOUCH_TEXT_FLOOR || textSize < Plan.TEXT_FLOOR_MIN_SOURCE) {
			return undefined;
		}
		return Plan.TOUCH_TEXT_FLOOR;
	}

	function shouldWrap(textSize: number, boxHeight: number, wrapped: boolean, scaled: boolean): boolean {
		if (wrapped || scaled || textSize <= 0) {
			return false;
		}
		return boxHeight >= textSize * Plan.WRAP_LINE_FACTOR;
	}

	function labelsCollide(a: LabelBox, b: LabelBox): boolean {
		const width = math.min(a.x1 - a.x0, b.x1 - b.x0);
		const height = math.min(a.y1 - a.y0, b.y1 - b.y0);
		if (width <= 0 || height <= 0) {
			return false;
		}
		const sideways = math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0));
		const shared = math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0));
		return sideways / width >= Plan.LABEL_COLLIDE_SHARE && shared / height >= Plan.LABEL_ROW_SHARE;
	}

	function nudgeIntoView(
		x0: number,
		y0: number,
		x1: number,
		y1: number,
		screenW: number,
		screenH: number,
	): LuaTuple<[number, number]> {
		const margin = Plan.SCREEN_MARGIN;
		let dx = 0;
		let dy = 0;
		if (x1 > screenW - margin) {
			dx = screenW - margin - x1;
		}
		if (x0 + dx < margin) {
			dx = margin - x0;
		}
		if (y1 > screenH - margin) {
			dy = screenH - margin - y1;
		}
		if (y0 + dy < margin) {
			dy = margin - y0;
		}
		return $tuple(dx, dy);
	}

	function sweepFrames(count: number): number {
		return math.max(1, math.ceil(math.max(0, count) / Plan.SWEEP_PER_FRAME));
	}

	function worstCatchSeconds(count: number, fps: number): number {
		return math.max(Plan.MIN_SWEEP_SECONDS, sweepFrames(count) / math.max(1, fps));
	}

	const Plan = {
		FRESH_PER_FRAME: 96,
		SWEEP_PER_FRAME: 48,
		BURST_PER_FRAME: 320,
		BURST_FRAMES: 12,
		SETTLE_FRAMES: 1,
		MIN_SWEEP_SECONDS: 0.75,
		FRESH_CAP: 4000,
		MAX_TRIES: 3,
		RESIZE_SLOP: 8,
		TOUCH_TEXT_FLOOR: 11,
		TEXT_FLOOR_MIN_SOURCE: 7,
		WRAP_LINE_FACTOR: 2.1,
		LABEL_COLLIDE_SHARE: 0.12,
		LABEL_ROW_SHARE: 0.5,
		SCREEN_MARGIN: 6,
		budget,
		resized,
		textFloor,
		shouldWrap,
		labelsCollide,
		nudgeIntoView,
		sweepFrames,
		worstCatchSeconds,
	};

	return table.freeze(Plan);
};

__defs["layoutSectionPlan"] = () => {
	interface OverviewFlags {
		stack: boolean;
		phone: boolean;
		landscapePhone: boolean;
		wideOverview: boolean;
		ultraOverview: boolean;
		rebirthVisible: boolean;
		domainVisible: boolean;
		countdownInPage: boolean;
		short: boolean;
		chromePanelGap: number;
		layoutPanelGap: number;
		fitHeight?: number;
		// optional, additive: hero card gets a full-width vault-meter band under the readout/CTA row
		roomyHero?: boolean;
	}

	interface OverviewPlan {
		heroH: number;
		// height of that band (0 when roomyHero is off / not applicable)
		heroBandH: number;
		rebirthH: number;
		domainH: number;
		notesH: number;
		opsH: number;
		metricCardH: number;
		metricsH: number;
		countdownH: number;
		sectionGap: number;
		topBandH: number;
		sectionCount: number;
		overviewTail: number;
		contentIntrinsic: number;
	}

	interface WorkspaceFlags {
		keyboardCompact: boolean;
		stack: boolean;
		landscape: boolean;
		workspaceHeaderH: number;
		layoutWorkspaceHeaderHeight: number;
		tapTarget: number;
		showNextGoal: boolean;
	}

	interface WorkspacePlan {
		headerHeight: number;
		unlockH: number;
	}

	const HERO_BAND_H = 58;
	const HERO_ROOMY_EXTRA = 40;

	function planOverview(flags: OverviewFlags): OverviewPlan {
		const stack = flags.stack === true;
		const phone = flags.phone === true;
		const landscapePhone = flags.landscapePhone === true;
		const wideOverview = flags.wideOverview === true;
		const ultraOverview = flags.ultraOverview === true;
		const rebirthVisible = flags.rebirthVisible === true;
		const domainVisible = flags.domainVisible === true;
		const countdownInPage = flags.countdownInPage === true;
		const short = flags.short === true && !stack;
		const chromePanelGap = tonumber(flags.chromePanelGap) ?? 10;
		const layoutPanelGap = tonumber(flags.layoutPanelGap) ?? 14;

		let heroH = landscapePhone
			? 208
			: phone
				? 320 // readout 168 + two stacked buttons 108 + gaps + 16px padding each side
				: short && wideOverview
					? 260
					: short
						? 248
						: ultraOverview
							? 268
							: wideOverview
								? 258
								: 248;
		const denseHero = short && wideOverview && !phone;
		const heroBandH = flags.roomyHero === true && !phone && !denseHero ? HERO_BAND_H : 0;
		if (heroBandH > 0) {
			heroH += HERO_ROOMY_EXTRA;
		}
		const rebirthH = rebirthVisible ? (phone ? (landscapePhone ? 248 : 300) : ultraOverview ? 220 : 208) : 0;
		const domainH = domainVisible ? (phone ? (landscapePhone ? 268 : 320) : ultraOverview ? 196 : 188) : 0; // desktop content ends ~150px in
		let notesH = stack ? (landscapePhone ? 132 : 168) : short ? 168 : ultraOverview ? 160 : 148;
		const opsH = landscapePhone ? 156 : stack ? 196 : short || ultraOverview ? 176 : 172;
		let metricCardH = stack ? (landscapePhone ? 72 : 92) : wideOverview ? (ultraOverview ? 84 : 80) : 0;
		let metricsH = stack ? metricCardH * 3 + 16 : wideOverview ? heroH : 104;
		const countdownH = countdownInPage ? (stack ? (landscapePhone ? 128 : 168) : ultraOverview ? 152 : 140) : 0;
		let sectionGap = stack ? chromePanelGap : short ? 10 : ultraOverview ? 18 : wideOverview ? 16 : layoutPanelGap;
		const fitHeight = tonumber(flags.fitHeight);
		if (short && wideOverview && fitHeight !== undefined && fitHeight > 0) {
			sectionGap = 8;
			metricCardH = 72;
			const heroFloor = 212;
			const notesFloor = 146;
			const pair = heroFloor + notesFloor + sectionGap;
			if (fitHeight <= pair) {
				heroH = heroFloor;
				notesH = math.max(140, notesFloor - (pair - fitHeight));
			} else {
				heroH = math.min(240, heroFloor + (fitHeight - pair));
				notesH = notesFloor;
			}
			metricsH = heroH;
		}
		const topBandH = wideOverview ? heroH : heroH + metricsH + sectionGap;
		const sectionCount = 1 + 1 + 1 + (countdownInPage ? 1 : 0) + (rebirthVisible ? 1 : 0) + (domainVisible ? 1 : 0);
		const overviewTail = landscapePhone ? 48 : stack ? 56 : ultraOverview ? 48 : 40;
		const contentIntrinsic = topBandH + notesH + opsH + countdownH + rebirthH + domainH + sectionGap * math.max(0, sectionCount - 1);

		return {
			heroH,
			heroBandH,
			rebirthH,
			domainH,
			notesH,
			opsH,
			metricCardH,
			metricsH,
			countdownH,
			sectionGap,
			topBandH,
			sectionCount,
			overviewTail,
			contentIntrinsic,
		};
	}

	function planWorkspace(flags: WorkspaceFlags): WorkspacePlan {
		const keyboardCompact = flags.keyboardCompact === true;
		const stack = flags.stack === true;
		const landscape = flags.landscape === true;
		const workspaceHeaderH = tonumber(flags.workspaceHeaderH) ?? 0;
		const layoutWorkspaceHeaderHeight = tonumber(flags.layoutWorkspaceHeaderHeight) ?? 86;
		const tapTarget = tonumber(flags.tapTarget) ?? 48;
		const showNextGoal = flags.showNextGoal === true;

		let headerHeight: number;
		if (keyboardCompact) {
			headerHeight = landscape || workspaceHeaderH <= 0 ? 0 : tapTarget;
		} else if (stack) {
			headerHeight = workspaceHeaderH;
		} else {
			headerHeight = workspaceHeaderH > 0 ? workspaceHeaderH : layoutWorkspaceHeaderHeight;
		}

		let unlockH = 0;
		if (!keyboardCompact && !landscape && headerHeight > 0 && showNextGoal) {
			unlockH = 32;
		}

		return {
			headerHeight,
			unlockH,
		};
	}

	const LayoutSectionPlan = {
		planOverview,
		planWorkspace,
	};

	return table.freeze(LayoutSectionPlan);
};

__defs["pageScaffold"] = () => {
	const React = loadReact();
	const Palette = (kitMember("CoreKit", "theme") as typeof import("./CoreKit/theme")).Palette;
	const planFillHeight = (__load("pageScaffoldPlan") as ScaffoldPlanModule).planFillHeight;
	const planFittedHeights = (__load("pageScaffoldPlan") as ScaffoldPlanModule).planFittedHeights;
	const planOverflow = (__load("pageScaffoldPlan") as ScaffoldPlanModule).planOverflow;
	const PageScrollContext = (__load("scrolling") as ScrollingModule).PageScrollContext;
	const h = React.createElement as unknown as LooseCreate;

	// sections rise into place one after another when a page opens (once; layout changes don't replay it)
	// while a section is still rising it is tagged LayoutInMotion so the layout guard ignores the
	// few frames where it slides through its neighbour
	function sectionEntrance(index: number, riseRef: MutableRefObject<GuiObject | undefined>): Binding<number> {
		const [amount, setAmount] = React.useBinding(0);
		React.useEffect(() => {
			const start = os.clock() + math.min(index, 8) * 0.055;
			riseRef.current?.SetAttribute("LayoutInMotion", true);
			const connection = game.GetService("RunService").RenderStepped.Connect(() => {
				const t = math.clamp((os.clock() - start) / 0.45, 0, 1);
				setAmount(t);
				if (t >= 1) {
					connection.Disconnect();
					riseRef.current?.SetAttribute("LayoutInMotion", undefined);
				}
			});
			return () => {
				if (connection.Connected) {
					connection.Disconnect();
				}
			};
		}, []);
		return amount;
	}

	function easeOutBackSoft(x: number): number {
		const c1 = 1.2;
		const c3 = 2.2;
		return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2;
	}

	interface SpringSectionProps {
		id?: unknown;
		frameRef?: MutableRefObject<GuiObject | undefined>;
		height: number;
		layoutOrder?: number;
		element?: unknown;
	}

	function SpringSection(props: SpringSectionProps) {
		const sectionRef = React.useCallback(
			(host: Frame | undefined) => {
				if (props.frameRef !== undefined) {
					props.frameRef.current = host;
				}
				if (host !== undefined) {
					host.SetAttribute("LayoutOwner", `PageScaffold:${tostring(props.id ?? "PageSection")}`);
				}
			},
			[props.frameRef, props.id],
		);
		const riseRef = React.useRef<GuiObject>();
		const entrance = sectionEntrance(props.layoutOrder ?? 0, riseRef);
		return h(
			"frame",
			{
				Name: tostring(props.id ?? "PageSection"),
				ref: sectionRef,
				Size: new UDim2(1, 0, 0, math.max(0, props.height)),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				LayoutOrder: props.layoutOrder,
				ClipsDescendants: false,
			},
			h(
				"frame",
				{
					Name: "Rise",
					ref: riseRef,
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					Position: entrance.map((t: number) => UDim2.fromOffset(0, math.round((1 - easeOutBackSoft(t)) * 22))),
				},
				props.element,
			),
		);
	}

	interface PageScaffoldProps {
		sections: ScaffoldSection[];
		gap?: number;
		tailPad?: number;
		inset?: number;
		scrollBarThickness?: number;
		scrollBarColor?: Color3;
		size?: UDim2;
		position?: UDim2;
		zIndex?: number;
		hostRef?: MutableRefObject<ScrollingFrame | undefined>;
		owner?: string;
	}

	function PageScaffold(_param: PageScaffoldProps) {
		const sections = _param.sections;
		let gap = _param.gap;
		if (gap === undefined) {
			gap = 10;
		}
		let tailPad = _param.tailPad;
		if (tailPad === undefined) {
			tailPad = 8;
		}
		let inset = _param.inset;
		if (inset === undefined) {
			inset = 0;
		}
		let scrollBarThickness = _param.scrollBarThickness;
		if (scrollBarThickness === undefined) {
			scrollBarThickness = 3;
		}
		const scrollBarColor = _param.scrollBarColor;
		let size = _param.size;
		if (size === undefined) {
			size = UDim2.fromScale(1, 1);
		}
		const position = _param.position;
		let zIndex = _param.zIndex;
		if (zIndex === undefined) {
			zIndex = 1;
		}
		const internalRef = React.useRef<ScrollingFrame>();
		let hostRef = _param.hostRef;
		if (hostRef === undefined) {
			hostRef = internalRef;
		}
		const [available, setAvailable] = React.useState(0);
		React.useEffect(() => {
			const host = hostRef.current;
			if (host === undefined) {
				return undefined;
			}
			host.SetAttribute("LayoutOwner", _param.owner ?? "PageScaffold");
			const sync = () => {
				const height = math.max(0, math.floor(host.AbsoluteSize.Y + 0.5));
				setAvailable((current) => (current === height ? current : height));
			};
			sync();
			const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(sync);
			return () => {
				return connection.Disconnect();
			};
		}, []);
		const _callback = (section: ScaffoldSection) => {
			return section.fill === true;
		};
		let _result: ScaffoldSection | undefined;
		for (const [_i, _v] of ipairs(sections)) {
			if (_callback(_v) === true) {
				_result = _v;
				break;
			}
		}
		// The inset padding sits inside the measured host, so plan against what is left after it.
		const usable = available > 0 ? math.max(1, available - inset * 2) : 0;
		const overflowing = planOverflow(sections, usable, gap, tailPad);
		const [fillContent, setFillContent] = React.useState(0);
		const reportFill = React.useCallback((height: number) => {
			const rounded = math.max(0, math.ceil(height));
			setFillContent((current) => (current === rounded ? current : rounded));
		}, []);
		const fillSectionRef = React.useRef<GuiObject>();
		const scrollContext = React.useMemo((): ScrollHostContext => {
			return {
				hostRef,
				sectionRef: fillSectionRef,
				overflowing,
				report: reportFill,
			};
		}, [overflowing, hostRef]);
		let planSections = sections;
		if (overflowing && fillContent > 0) {
			const grown: ScaffoldSection[] = table.create(sections.size());
			for (const [index, section] of ipairs(sections)) {
				if (section.fill === true) {
					const grownSection = table.clone(section);
					grownSection.height = math.max(section.height ?? 0, fillContent);
					grown[index - 1] = grownSection;
				} else {
					grown[index - 1] = section;
				}
			}
			planSections = grown;
		}
		const fittedHeights = planFittedHeights(planSections, usable, gap, tailPad);
		const _exp = h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			SortOrder: Enum.SortOrder.LayoutOrder,
			Padding: new UDim(0, gap),
		});
		const _exp_1 = inset > 0
			? h("uipadding", {
					PaddingLeft: new UDim(0, inset),
					PaddingRight: new UDim(0, inset),
					PaddingTop: new UDim(0, inset),
					PaddingBottom: new UDim(0, inset),
				})
			: h("uipadding", {
					// keep an 8px gutter between the content and the scrollbar so cards never sit under it
					PaddingRight: new UDim(0, 8),
				});
		const _newValue: unknown[] = table.create(sections.size());
		const _callback_2 = (section: ScaffoldSection, index: number) => {
			const _attributes: Record<string, unknown> = {
				key: section.id,
				id: section.id,
			};
			let _result_3 = fittedHeights[index] as number | undefined;
			if (_result_3 === undefined) {
				_result_3 = 0;
			}
			_attributes.height = _result_3;
			_attributes.layoutOrder = index;
			_attributes.element =
				section.fill === true
					? h(PageScrollContext.Provider, { value: scrollContext }, section.element)
					: section.element;
			if (section.fill === true) {
				_attributes.frameRef = fillSectionRef;
			}
			return h(SpringSection, _attributes);
		};
		for (const [_k, _v] of ipairs(sections)) {
			_newValue[_k - 1] = _callback_2(_v, _k - 1);
		}
		return h(
			"scrollingframe",
			{
				ref: hostRef,
				Size: size,
				Position: position,
				CanvasSize: new UDim2(0, 0, 0, 0),
				AutomaticCanvasSize: Enum.AutomaticSize.Y,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ScrollBarThickness: scrollBarThickness,
				ScrollBarImageColor3: scrollBarColor ?? Palette.muted,
				ScrollBarImageTransparency: 0.42,
				VerticalScrollBarInset: Enum.ScrollBarInset.ScrollBar,
				ScrollingDirection: Enum.ScrollingDirection.Y,
				ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
				ClipsDescendants: true,
				Active: true,
				Selectable: false,
				ZIndex: zIndex,
			},
			_exp,
			_exp_1,
			_newValue,
			tailPad > 0
				? h("frame", {
						Size: new UDim2(1, 0, 0, tailPad),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						LayoutOrder: sections.size(),
					})
				: undefined,
		);
	}

	return {
		PageScaffold,
		planFillHeight,
	};
};

__defs["pageScaffoldPlan"] = () => {
	function planFillHeight(sections: ReadonlyArray<ScaffoldSection>, availableHeight: number, gap?: number, tailPad?: number): number {
		const resolvedGap = gap ?? 10;
		const resolvedTail = tailPad ?? 8;
		let fillSection: ScaffoldSection | undefined = undefined;
		let fixedTotal = 0;
		for (const section of sections) {
			if (section.fill === true) {
				fillSection = section;
			} else {
				const height = section.height ?? 0;
				fixedTotal += height;
			}
		}
		if (fillSection === undefined) {
			return 0;
		}
		const gapsTotal = resolvedGap * math.max(0, sections.size() - 1);
		const minHeight = fillSection.minHeight ?? 120;
		const contentFloor = fillSection.height ?? 0;
		return math.max(minHeight, contentFloor, availableHeight - fixedTotal - gapsTotal - resolvedTail);
	}

	function planFittedHeights(
		sections: ReadonlyArray<ScaffoldSection>,
		availableHeight: number,
		gap?: number,
		tailPad?: number,
	): number[] {
		const resolvedGap = gap ?? 10;
		const fillHeight = planFillHeight(sections, availableHeight, gap, tailPad);
		const heights = table.create<number>(sections.size());
		for (const [index, section] of ipairs(sections)) {
			if (section.fill === true) {
				heights[index - 1] = fillHeight;
			} else {
				const height = section.height;
				heights[index - 1] = height ?? 0;
			}
		}
		if (availableHeight <= 0 || heights.size() <= 1) {
			return heights;
		}
		let cursor = 0;
		let lastFit = 0;
		for (const [index, height] of ipairs(heights)) {
			if (cursor + height > availableHeight) {
				break;
			}
			lastFit = index;
			cursor += height;
			if (index < heights.size()) {
				cursor += resolvedGap;
			}
		}
		if (lastFit === 0 || lastFit === heights.size()) {
			return heights;
		}
		const extra = availableHeight - cursor;
		const nextHeight = heights[lastFit] ?? 0;
		// only a section that asks for it (stretch = true) is padded out to the fold; padding any other
		// section just leaves an empty band inside its panel
		if (extra > 0 && extra <= 96 && extra < nextHeight && sections[lastFit - 1].stretch === true) {
			heights[lastFit - 1] += extra;
		}
		return heights;
	}

	function planOverflow(sections: ReadonlyArray<ScaffoldSection>, availableHeight: number, gap?: number, tailPad?: number): boolean {
		if (availableHeight <= 0) {
			return false;
		}
		const resolvedGap = gap ?? 10;
		const resolvedTail = tailPad ?? 8;
		let total = resolvedGap * math.max(0, sections.size() - 1) + resolvedTail;
		let hasFill = false;
		for (const section of sections) {
			if (section.fill === true) {
				hasFill = true;
				total += section.minHeight ?? 120;
			} else {
				total += section.height ?? 0;
			}
		}
		return hasFill && total > availableHeight + 0.5;
	}

	return {
		planFillHeight,
		planFittedHeights,
		planOverflow,
	};
};

__defs["pageReadyMath"] = () => {
	function CountReadyQuests(quests: unknown): number {
		let ready = 0;
		if (!typeIs(quests, "table")) {
			return 0;
		}
		for (const [, quest] of pairs(quests as object)) {
			if (typeIs(quest, "table") && (quest as Record<string, unknown>).Claimed !== true) {
				const progress = tonumber((quest as Record<string, unknown>).Progress) ?? 0;
				const target = tonumber((quest as Record<string, unknown>).Target) ?? 0;
				if (target > 0 && progress >= target) {
					ready += 1;
				}
			}
		}
		return ready;
	}

	function CountReadyLabOrders(lab: unknown): number {
		let ready = 0;
		if (!typeIs(lab, "table") || !typeIs((lab as Record<string, unknown>).Orders, "table")) {
			return 0;
		}
		for (const [, order] of pairs((lab as Record<string, unknown>).Orders as object)) {
			if (typeIs(order, "table") && (order as Record<string, unknown>).Claimed !== true) {
				const progress = tonumber((order as Record<string, unknown>).Progress) ?? 0;
				const target = tonumber((order as Record<string, unknown>).Target) ?? 0;
				if (target > 0 && progress >= target) {
					ready += 1;
				}
			}
		}
		return ready;
	}

	function ForgePathReady(state: unknown, config: unknown): boolean {
		if (!typeIs(state, "table")) {
			return false;
		}
		const forgePath = (state as Record<string, unknown>).ForgePath;
		if (!typeIs(forgePath, "table")) {
			return false;
		}
		let steps: unknown = undefined;
		if (typeIs(config, "table") && typeIs((config as Record<string, unknown>).ForgePath, "table")) {
			steps = ((config as Record<string, unknown>).ForgePath as Record<string, unknown>).Steps;
		}
		if (!typeIs(steps, "table") || (steps as unknown[]).size() === 0) {
			return false;
		}
		const claimed = new Map<unknown, boolean>();
		const claimedSteps = (forgePath as Record<string, unknown>).ClaimedSteps;
		if (typeIs(claimedSteps, "table")) {
			for (const [, stepId] of pairs(claimedSteps as object)) {
				claimed.set(stepId, true);
			}
		}
		const xp = tonumber((forgePath as Record<string, unknown>).XP) ?? 0;
		for (const [, step] of pairs(steps as object)) {
			if (typeIs(step, "table") && !claimed.has((step as Record<string, unknown>).Step)) {
				const stepRecord = step as Record<string, unknown>;
				const stepNumber = stepRecord.Step as number;
				const unlocked = stepRecord.Step === 1 || claimed.has(stepNumber - 1);
				if (unlocked) {
					return xp >= (tonumber(stepRecord.XPCost) ?? 0);
				}
				return false;
			}
		}
		return false;
	}

	const CREW_KEYS = [
		"UserId",
		"Name",
		"DisplayName",
		"CurrentZone",
		"Rebirths",
		"Production",
		"LifetimeCash",
		"IsLocal",
		"CurrentPage",
	];

	function SameCrewSnapshot(left: unknown, right: unknown): boolean {
		if (!typeIs(left, "table") || !typeIs(right, "table")) {
			return left === right;
		}
		const leftList = left as unknown[];
		const rightList = right as unknown[];
		if (leftList.size() !== rightList.size()) {
			return false;
		}
		for (const index of $range(1, leftList.size())) {
			const a = leftList[index - 1];
			const b = rightList[index - 1];
			if (!typeIs(a, "table") || !typeIs(b, "table")) {
				return false;
			}
			for (const key of CREW_KEYS) {
				if ((a as Record<string, unknown>)[key] !== (b as Record<string, unknown>)[key]) {
					return false;
				}
			}
		}
		return true;
	}

	function AnomalyReady(anomaly: unknown): boolean {
		if (!typeIs(anomaly, "table")) {
			return false;
		}
		if ((anomaly as Record<string, unknown>).Ready === true) {
			return true;
		}
		const directives = (anomaly as Record<string, unknown>).Directives;
		if (!typeIs(directives, "table")) {
			return false;
		}
		for (const [, directive] of pairs(directives as object)) {
			if (typeIs(directive, "table") && (directive as Record<string, unknown>).Claimed !== true) {
				const progress = tonumber((directive as Record<string, unknown>).Progress);
				const target = tonumber((directive as Record<string, unknown>).Target);
				if (progress !== undefined && target !== undefined && progress >= target) {
					return true;
				}
			}
		}
		return false;
	}

	// Signal Cipher replaced Shift Plan as the daily call to action: open until solved or failed today
	function CipherOpen(sky: unknown): boolean {
		const cipher = typeIs(sky, "table") ? (sky as Record<string, unknown>).Cipher : undefined;
		return (
			typeIs(cipher, "table") &&
			(cipher as Record<string, unknown>).Solved !== true &&
			(cipher as Record<string, unknown>).Failed !== true
		);
	}

	function OpsClaims(missionsReady: unknown, labReady: unknown, pathReady: unknown, anomalyReady: unknown): number {
		let total = math.max(0, math.floor(tonumber(missionsReady) ?? 0)) + math.max(0, math.floor(tonumber(labReady) ?? 0));
		if (pathReady) {
			total += 1;
		}
		if (anomalyReady) {
			total += 1;
		}
		return total;
	}

	const PageReadyMath = {
		CountReadyQuests,
		CountReadyLabOrders,
		ForgePathReady,
		SameCrewSnapshot,
		AnomalyReady,
		CipherOpen,
		OpsClaims,
	};

	return table.freeze(PageReadyMath);
};

interface LayoutUtilApi {
	grid(this: void, layout: UIGridLayout, size: Vector2): void;
	resize(this: void, frame: ScrollingFrame, layout: UIGridLayout | UIListLayout, axis: Enum.AutomaticSize): RBXScriptConnection;
}

function loadLayoutUtil(): LayoutUtilApi {
	return require(
		game
			.GetService("ReplicatedStorage")
			.WaitForChild("rbxts_include")
			.WaitForChild("node_modules")
			.WaitForChild("@rbxts")
			.WaitForChild("layoututil")
			.WaitForChild("src") as ModuleScript,
	) as LayoutUtilApi;
}

interface ScrollMotion {
	target: Vector2;
	lastTouched: number;
}

interface AutoGridProps {
	columns: number;
	cellHeight: number;
	gap?: number;
	rowGap?: number;
	columnGap?: number;
	minColumns?: number;
	minCellWidth?: number;
	maxCellWidth?: number;
	cellAspectRatio?: number;
	breakpoints?: ReadonlyArray<GridBreakpoint>;
	pack?: boolean;
	horizontalAlignment?: Enum.HorizontalAlignment;
	verticalAlignment?: Enum.VerticalAlignment;
	startCorner?: Enum.StartCorner;
	fillDirection?: Enum.FillDirection;
	sortOrder?: Enum.SortOrder;
	autoCanvas?: boolean;
	canvasTail?: number;
	onLayout?: (info: GridLayoutInfo) => void;
}

interface VirtualGridProps {
	scrollRef: MutableRefObject<ScrollingFrame | undefined>;
	count: number;
	columns: number;
	cellHeight: number;
	gap: number;
	overscanRows?: number;
	layoutOrder?: number;
	position?: UDim2;
	itemKey: (index: number) => string;
	renderItem: (index: number) => unknown;
}

__defs["scrolling"] = () => {
	const React = loadReact();
	const h = React.createElement as unknown as LooseCreate;
	const LayoutUtil = loadLayoutUtil();
	const GuiService = game.GetService("GuiService");
	const Players = game.GetService("Players");
	const RunService = game.GetService("RunService");
	const UserInputService = game.GetService("UserInputService");
	const Workspace = game.GetService("Workspace");
	const Audio = (kitMember("AudioKit", "audio") as { Audio: AudioPlayer }).Audio;
	const PACK_BREAKPOINTS = (kitMember("MotionKit", "flexbox") as { PACK_BREAKPOINTS: ReadonlyArray<GridBreakpoint> })
		.PACK_BREAKPOINTS;

	let installed = false;
	let scrollPreference = 0.6;
	let momentumPreference = 0.75;
	let titleFxHoldGeneration = 0;
	let titleFxHeld = false;
	const motions = new Map<ScrollingFrame, ScrollMotion>();
	let motionCount = 0;
	let gamepadAxis = Vector2.zero;
	let lastScrollSound = -math.huge;
	let motionDriver: RBXScriptConnection | undefined;
	const globalConnections = new Array<RBXScriptConnection>();
	const CONSTRAINED_SCROLL = isConstrainedInput();
	let titleFxHoldUntil = 0;

	function holdTitleFx() {
		titleFxHoldUntil = os.clock() + 0.16;
		if (titleFxHeld) {
			return undefined;
		}
		titleFxHeld = true;
		pcall(() => {
			Workspace.SetAttribute("AF_TitleFxHold", true);
		});
		titleFxHoldGeneration += 1;
		const generation = titleFxHoldGeneration;
		task.spawn(() => {
			while (generation === titleFxHoldGeneration && os.clock() < titleFxHoldUntil) {
				task.wait(0.05);
			}
			if (generation !== titleFxHoldGeneration) {
				return undefined;
			}
			titleFxHeld = false;
			pcall(() => {
				Workspace.SetAttribute("AF_TitleFxHold", false);
			});
		});
	}

	function disposeScrollPerformance() {
		installed = false;
		titleFxHoldGeneration += 1;
		titleFxHeld = false;
		pcall(() => {
			Workspace.SetAttribute("AF_TitleFxHold", false);
		});
		for (const connection of globalConnections) {
			connection.Disconnect();
		}
		globalConnections.clear();
		if (motionDriver !== undefined) {
			motionDriver.Disconnect();
		}
		motionDriver = undefined;
		motions.clear();
		motionCount = 0;
		gamepadAxis = Vector2.zero;
	}

	function setScrollSpeed(value: number) {
		scrollPreference = math.clamp(value, 0, 1);
	}

	function setScrollMomentum(value: number) {
		momentumPreference = math.clamp(value, 0, 1);
	}

	function scrollingAncestor(instance: Instance | undefined): ScrollingFrame | undefined {
		let cursor = instance;
		while (cursor !== undefined) {
			if (cursor.IsA("ScrollingFrame") && cursor.Visible && cursor.ScrollingEnabled) {
				return cursor;
			}
			cursor = cursor.Parent;
		}
		return undefined;
	}

	function fallbackScrollingFrame(): ScrollingFrame | undefined {
		const localPlayer = Players.LocalPlayer;
		const playerGui = localPlayer !== undefined ? localPlayer.FindFirstChildOfClass("PlayerGui") : undefined;
		if (playerGui === undefined) {
			return undefined;
		}
		let bestFrame: ScrollingFrame | undefined;
		let bestArea = 0;
		for (const desc of playerGui.GetDescendants()) {
			if (desc.IsA("ScrollingFrame") && desc.Visible && desc.ScrollingEnabled) {
				let visible = true;
				let ancestor: Instance | undefined = desc.Parent;
				while (ancestor !== undefined) {
					if (ancestor.IsA("GuiObject") && !ancestor.Visible) {
						visible = false;
						break;
					}
					if (ancestor.IsA("LayerCollector") && !ancestor.Enabled) {
						visible = false;
						break;
					}
					ancestor = ancestor.Parent;
				}
				if (visible) {
					const size = desc.AbsoluteSize;
					const area = size.X * size.Y;
					if (area > bestArea) {
						bestArea = area;
						bestFrame = desc;
					}
				}
			}
		}
		return bestFrame;
	}

	function frameUnderPointer(pointer?: Vector2): ScrollingFrame | undefined {
		if (pointer === undefined) {
			pointer = UserInputService.GetMouseLocation();
		}
		const playerGui = Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
		if (playerGui === undefined) {
			return undefined;
		}
		const objects = playerGui.GetGuiObjectsAtPosition(math.floor(pointer.X), math.floor(pointer.Y));
		for (const object of objects) {
			const frame = scrollingAncestor(object);
			if (frame !== undefined) {
				return frame;
			}
		}
		return undefined;
	}

	function frameUnderInput(position: Vector3): ScrollingFrame | undefined {
		const [ok, topLeft] = pcall(() => GuiService.GetGuiInset());
		const inset = ok && topLeft !== undefined && typeIs(topLeft, "Vector2") ? topLeft : Vector2.zero;
		return frameUnderPointer(new Vector2(position.X - inset.X, position.Y - inset.Y));
	}

	const EDGE_GESTURE_BAND = 22;
	function inSystemGestureZone(position: Vector2): boolean {
		if (!UserInputService.TouchEnabled) {
			return false;
		}
		const viewport = Workspace.CurrentCamera?.ViewportSize;
		if (viewport === undefined) {
			return false;
		}
		if (position.X <= EDGE_GESTURE_BAND || position.X >= viewport.X - EDGE_GESTURE_BAND) {
			return true;
		}
		return position.Y >= viewport.Y - EDGE_GESTURE_BAND;
	}

	function bounds(frame: ScrollingFrame): Vector2 {
		return new Vector2(
			math.max(0, frame.AbsoluteCanvasSize.X - frame.AbsoluteWindowSize.X),
			math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y),
		);
	}

	function clampFor(frame: ScrollingFrame, value: Vector2): Vector2 {
		const maximum = bounds(frame);
		return new Vector2(math.clamp(value.X, 0, maximum.X), math.clamp(value.Y, 0, maximum.Y));
	}

	function canScrollToward(frame: ScrollingFrame, delta: Vector2): boolean {
		const maximum = bounds(frame);
		const motion = motions.get(frame);
		const from = motion !== undefined ? motion.target : frame.CanvasPosition;
		if (delta.Y !== 0) {
			if (maximum.Y <= 0.5) {
				return false;
			}
			return delta.Y < 0 ? from.Y > 0.5 : from.Y < maximum.Y - 0.5;
		}
		if (delta.X !== 0) {
			if (maximum.X <= 0.5) {
				return false;
			}
			return delta.X < 0 ? from.X > 0.5 : from.X < maximum.X - 0.5;
		}
		return false;
	}

	function ensureMotionDriver() {
		if (!installed) {
			return undefined;
		}
		if (motionDriver !== undefined) {
			return undefined;
		}
		let frameSkip = 0;
		const signal = CONSTRAINED_SCROLL ? RunService.Heartbeat : RunService.RenderStepped;
		motionDriver = signal.Connect((deltaTime) => {
			if (CONSTRAINED_SCROLL) {
				frameSkip += 1;
				if (frameSkip % 2 === 1 && gamepadAxis.Magnitude <= 0.16) {
					return undefined;
				}
			}
			if (gamepadAxis.Magnitude > 0.16) {
				let selectedFrame = scrollingAncestor(GuiService.SelectedObject);
				if (selectedFrame === undefined) {
					const [ok, nav] = pcall(() => kitMember("CoreKit", "GamepadNavigationService"));
					if (ok && typeIs(nav, "table")) {
						const getScrollTarget = (nav as { GetScrollTarget?: unknown }).GetScrollTarget;
						if (typeIs(getScrollTarget, "function")) {
							const target = (getScrollTarget as () => GuiObject | undefined)();
							if (target !== undefined && target.IsA("ScrollingFrame")) {
								selectedFrame = target;
							}
						} else {
							selectedFrame = fallbackScrollingFrame();
						}
					} else {
						selectedFrame = fallbackScrollingFrame();
					}
				}
				if (selectedFrame !== undefined) {
					const speed = 260 + scrollPreference * 220;
					let delta = gamepadAxis.mul(speed * math.min(deltaTime, 0.05));
					if (selectedFrame.ScrollingDirection === Enum.ScrollingDirection.X) {
						delta = new Vector2(delta.X, 0);
					} else if (selectedFrame.ScrollingDirection === Enum.ScrollingDirection.Y) {
						delta = new Vector2(0, delta.Y);
					}
					addImpulse(selectedFrame, delta, false);
				}
			}
			const response = 14 - momentumPreference * 5;
			const alpha = 1 - math.exp(-response * math.min(deltaTime, 0.05));
			const now = os.clock();
			const remove = new Array<ScrollingFrame>();
			for (const [frame, motion] of motions) {
				if (frame.Parent === undefined || !frame.Visible || !frame.ScrollingEnabled) {
					remove.push(frame);
					continue;
				}
				motion.target = clampFor(frame, motion.target);
				const settledPosition = frame.CanvasPosition.Lerp(motion.target, alpha);
				frame.CanvasPosition = settledPosition;
				if (settledPosition.sub(motion.target).Magnitude < 0.45 && now - motion.lastTouched > 0.08) {
					frame.CanvasPosition = motion.target;
					remove.push(frame);
				}
			}
			for (const frame of remove) {
				if (motions.delete(frame)) {
					motionCount = math.max(0, motionCount - 1);
				}
			}
			if (motionCount <= 0 && gamepadAxis.Magnitude <= 0.16) {
				if (motionDriver !== undefined) {
					motionDriver.Disconnect();
				}
				motionDriver = undefined;
				motionCount = 0;
			}
		});
	}

	function addImpulse(frame: ScrollingFrame, delta: Vector2, audible = true) {
		if (!installed) {
			return undefined;
		}
		holdTitleFx();
		const motion = targetFor(frame);
		motion.target = clampFor(frame, motion.target.add(delta));
		motion.lastTouched = os.clock();
		if (audible && os.clock() - lastScrollSound >= 0.095) {
			lastScrollSound = os.clock();
			Audio.play("scroll", math.clamp(0.92 + delta.Magnitude / 900, 0.92, 1.16));
		}
	}

	function targetFor(frame: ScrollingFrame): ScrollMotion {
		const existing = motions.get(frame);
		if (existing !== undefined) {
			return existing;
		}
		const created: ScrollMotion = {
			target: clampFor(frame, frame.CanvasPosition),
			lastTouched: os.clock(),
		};
		motions.set(frame, created);
		motionCount += 1;
		ensureMotionDriver();
		return created;
	}

	function revealSelection(selected: GuiObject | undefined) {
		if (!installed) {
			return undefined;
		}
		const frame = scrollingAncestor(selected);
		if (frame === undefined || selected === undefined) {
			return undefined;
		}
		const windowOrigin = frame.AbsolutePosition;
		const windowSize = frame.AbsoluteWindowSize;
		const itemOrigin = selected.AbsolutePosition;
		const itemSize = selected.AbsoluteSize;
		const margin = 14;
		let deltaX = 0;
		let deltaY = 0;
		if (itemOrigin.X < windowOrigin.X + margin) {
			deltaX = itemOrigin.X - (windowOrigin.X + margin);
		} else if (itemOrigin.X + itemSize.X > windowOrigin.X + windowSize.X - margin) {
			deltaX = itemOrigin.X + itemSize.X - (windowOrigin.X + windowSize.X - margin);
		}
		if (itemOrigin.Y < windowOrigin.Y + margin) {
			deltaY = itemOrigin.Y - (windowOrigin.Y + margin);
		} else if (itemOrigin.Y + itemSize.Y > windowOrigin.Y + windowSize.Y - margin) {
			deltaY = itemOrigin.Y + itemSize.Y - (windowOrigin.Y + windowSize.Y - margin);
		}
		if (frame.ScrollingDirection === Enum.ScrollingDirection.X) {
			deltaY = 0;
		}
		if (frame.ScrollingDirection === Enum.ScrollingDirection.Y) {
			deltaX = 0;
		}
		if (math.abs(deltaX) > 0.5 || math.abs(deltaY) > 0.5) {
			addImpulse(frame, new Vector2(deltaX, deltaY), false);
		}
	}

	const boundScrolls = new Set<ScrollingFrame>();
	function bindLayoutUtil(frame: ScrollingFrame) {
		if (boundScrolls.has(frame)) {
			return undefined;
		}
		boundScrolls.add(frame);
		let resizeConnection: RBXScriptConnection | undefined;
		const apply = () => {
			if (frame.Parent === undefined) {
				return undefined;
			}
			if (resizeConnection !== undefined) {
				resizeConnection.Disconnect();
			}
			resizeConnection = undefined;
			const layout = frame.FindFirstChildWhichIsA("UIListLayout") ?? frame.FindFirstChildWhichIsA("UIGridLayout");
			if (layout === undefined) {
				return undefined;
			}
			if (layout.IsA("UIGridLayout")) {
				pcall(() => {
					LayoutUtil.grid(layout, frame.AbsoluteSize);
				});
			}
			const axis =
				frame.ScrollingDirection === Enum.ScrollingDirection.X
					? Enum.AutomaticSize.X
					: frame.ScrollingDirection === Enum.ScrollingDirection.XY
						? Enum.AutomaticSize.XY
						: Enum.AutomaticSize.Y;
			const [ok, connection] = pcall(() => LayoutUtil.resize(frame, layout, axis));
			if (ok && typeIs(connection, "RBXScriptConnection")) {
				resizeConnection = connection;
			}
		};
		let applyScheduled = false;
		const scheduleApply = () => {
			if (applyScheduled) {
				return undefined;
			}
			applyScheduled = true;
			task.defer(() => {
				applyScheduled = false;
				apply();
			});
		};
		scheduleApply();
		const added = frame.ChildAdded.Connect(scheduleApply);
		const scrolled = frame.GetPropertyChangedSignal("CanvasPosition").Connect(holdTitleFx);
		frame.Destroying.Once(() => {
			added.Disconnect();
			scrolled.Disconnect();
			if (resizeConnection !== undefined) {
				resizeConnection.Disconnect();
			}
			boundScrolls.delete(frame);
		});
	}

	function watchPlayerGui(playerGui: PlayerGui) {
		for (const descendant of playerGui.GetDescendants()) {
			if (descendant.IsA("ScrollingFrame")) {
				bindLayoutUtil(descendant);
			}
		}
		return playerGui.DescendantAdded.Connect((instance) => {
			if (instance.IsA("ScrollingFrame")) {
				bindLayoutUtil(instance);
			}
		});
	}

	function installScrollPerformance() {
		if (installed) {
			return disposeScrollPerformance;
		}
		installed = true;
		const playerGui = Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
		if (playerGui !== undefined) {
			globalConnections.push(watchPlayerGui(playerGui));
		} else {
			globalConnections.push(
				Players.LocalPlayer.ChildAdded.Connect((child) => {
					if (child.IsA("PlayerGui")) {
						globalConnections.push(watchPlayerGui(child));
					}
				}),
			);
		}
		globalConnections.push(
			UserInputService.InputBegan.Connect((input) => {
				if (input.UserInputType !== Enum.UserInputType.Touch && input.UserInputType !== Enum.UserInputType.MouseButton1) {
					return undefined;
				}
				if (motionCount <= 0) {
					return undefined;
				}
				const position = new Vector2(input.Position.X, input.Position.Y);
				if (input.UserInputType === Enum.UserInputType.Touch && inSystemGestureZone(position)) {
					return undefined;
				}
				const frame = frameUnderInput(input.Position);
				const active = frame !== undefined ? motions.get(frame) : undefined;
				if (frame !== undefined && active !== undefined) {
					motions.delete(frame);
					motionCount = math.max(0, motionCount - 1);
				}
			}),
		);
		globalConnections.push(
			UserInputService.InputChanged.Connect((input) => {
				if (input.UserInputType === Enum.UserInputType.MouseWheel) {
					const direction = input.Position.Z;
					if (direction === 0) {
						return undefined;
					}
					task.defer(() => {
						if (!installed) {
							return undefined;
						}
						const innermost = frameUnderPointer();
						if (innermost === undefined) {
							return undefined;
						}
						const travel = 78 + scrollPreference * 110;
						const shift =
							UserInputService.IsKeyDown(Enum.KeyCode.LeftShift) || UserInputService.IsKeyDown(Enum.KeyCode.RightShift);
						let frame: ScrollingFrame | undefined = innermost;
						while (frame !== undefined) {
							const horizontal =
								frame.ScrollingDirection === Enum.ScrollingDirection.X ||
								(shift && frame.ScrollingDirection === Enum.ScrollingDirection.XY);
							const delta = horizontal ? new Vector2(-direction * travel, 0) : new Vector2(0, -direction * travel);
							if (canScrollToward(frame, delta)) {
								addImpulse(frame, delta);
								return undefined;
							}
							frame = scrollingAncestor(frame.Parent);
						}
					});
					return undefined;
				}
				if (input.UserInputType === Enum.UserInputType.Gamepad1 && input.KeyCode === Enum.KeyCode.Thumbstick2) {
					gamepadAxis = new Vector2(input.Position.X, -input.Position.Y);
					if (gamepadAxis.Magnitude > 0.16) {
						ensureMotionDriver();
					}
				}
			}),
		);
		globalConnections.push(
			UserInputService.InputEnded.Connect((input) => {
				if (input.UserInputType === Enum.UserInputType.Gamepad1 && input.KeyCode === Enum.KeyCode.Thumbstick2) {
					gamepadAxis = Vector2.zero;
				}
			}),
		);
		globalConnections.push(
			GuiService.GetPropertyChangedSignal("SelectedObject").Connect(() => {
				task.defer(() => {
					if (installed) {
						revealSelection(GuiService.SelectedObject);
					}
				});
			}),
		);
		return disposeScrollPerformance;
	}

	function breakpointColumns(width: number, fallback: number, breakpoints?: ReadonlyArray<GridBreakpoint>): number {
		if (breakpoints === undefined || breakpoints.size() === 0) {
			return fallback;
		}
		let resolved = 1;
		for (const point of breakpoints) {
			if (width >= point.minWidth) {
				resolved = point.columns;
			}
		}
		return resolved;
	}

	function AutoGrid(_param: AutoGridProps) {
		const columns = _param.columns;
		const cellHeight = _param.cellHeight;
		let gap = _param.gap;
		if (gap === undefined) {
			gap = 8;
		}
		let rowGap = _param.rowGap;
		if (rowGap === undefined) {
			rowGap = gap;
		}
		let columnGap = _param.columnGap;
		if (columnGap === undefined) {
			columnGap = gap;
		}
		let minColumns = _param.minColumns;
		if (minColumns === undefined) {
			minColumns = 1;
		}
		const minCellWidth = _param.minCellWidth;
		const maxCellWidth = _param.maxCellWidth;
		const cellAspectRatio = _param.cellAspectRatio;
		const breakpoints = _param.breakpoints;
		let pack = _param.pack;
		if (pack === undefined) {
			pack = false;
		}
		let horizontalAlignment = _param.horizontalAlignment;
		if (horizontalAlignment === undefined) {
			horizontalAlignment = Enum.HorizontalAlignment.Center;
		}
		let verticalAlignment = _param.verticalAlignment;
		if (verticalAlignment === undefined) {
			verticalAlignment = Enum.VerticalAlignment.Top;
		}
		let startCorner = _param.startCorner;
		if (startCorner === undefined) {
			startCorner = Enum.StartCorner.TopLeft;
		}
		let fillDirection = _param.fillDirection;
		if (fillDirection === undefined) {
			fillDirection = Enum.FillDirection.Horizontal;
		}
		let sortOrder = _param.sortOrder;
		if (sortOrder === undefined) {
			sortOrder = Enum.SortOrder.LayoutOrder;
		}
		let autoCanvas = _param.autoCanvas;
		if (autoCanvas === undefined) {
			autoCanvas = false;
		}
		let canvasTail = _param.canvasTail;
		if (canvasTail === undefined) {
			canvasTail = 0;
		}
		const onLayout = _param.onLayout;
		const layoutRef = React.useRef<UIGridLayout>();
		const callbackRef = React.useRef<((info: GridLayoutInfo) => void) | undefined>(onLayout);
		callbackRef.current = onLayout;
		React.useEffect(() => {
			const layout = layoutRef.current;
			const parentInstance = layout?.Parent;
			if (layout === undefined || parentInstance === undefined || !parentInstance.IsA("GuiObject")) {
				return undefined;
			}
			const parent = parentInstance;
			let alive = true;
			let scheduled = false;
			let previous = "";
			const sync = () => {
				scheduled = false;
				if (!alive || layout.Parent === undefined || parent.Parent === undefined) {
					return undefined;
				}
				const parentWidth = math.max(1, math.floor(parent.AbsoluteSize.X + 0.5));
				const preferred = breakpointColumns(parentWidth, columns, pack ? PACK_BREAKPOINTS : breakpoints);
				const widthDriven =
					minCellWidth !== undefined
						? math.floor((parentWidth + columnGap) / math.max(1, minCellWidth + columnGap))
						: preferred;
				const maximumColumns = math.max(1, math.floor(columns));
				const minimumColumns = math.clamp(math.floor(minColumns), 1, maximumColumns);
				const count = math.clamp(math.min(preferred, widthDriven), minimumColumns, maximumColumns);
				const available = math.max(1, parentWidth - columnGap * (count - 1));
				const widthCap = maxCellWidth ?? math.huge;
				const resolvedWidth = math.max(1, math.floor(math.min(widthCap, available / count)));
				const resolvedHeight =
					cellAspectRatio !== undefined && cellAspectRatio > 0
						? math.max(1, math.floor(resolvedWidth / cellAspectRatio + 0.5))
						: math.max(1, math.floor(cellHeight));
				const signature = `${count}:${resolvedWidth}:${resolvedHeight}:${columnGap}:${rowGap}`;
				if (signature !== previous) {
					previous = signature;
					layout.CellPadding = UDim2.fromOffset(columnGap, rowGap);
					layout.CellSize = UDim2.fromOffset(resolvedWidth, resolvedHeight);
					layout.FillDirectionMaxCells = count;
					const callback = callbackRef.current;
					if (callback !== undefined) {
						callback({
							columns: count,
							cellWidth: resolvedWidth,
							cellHeight: resolvedHeight,
							contentWidth: resolvedWidth * count + columnGap * (count - 1),
						});
					}
				}
				if (autoCanvas && parent.IsA("ScrollingFrame")) {
					const height = math.max(0, math.ceil(layout.AbsoluteContentSize.Y + canvasTail));
					if (parent.CanvasSize.Y.Offset !== height || parent.CanvasSize.Y.Scale !== 0) {
						parent.CanvasSize = new UDim2(parent.CanvasSize.X.Scale, parent.CanvasSize.X.Offset, 0, height);
					}
				}
			};
			const schedule = () => {
				if (scheduled) {
					return undefined;
				}
				scheduled = true;
				task.defer(sync);
			};
			sync();
			const sizeConnection = parent.GetPropertyChangedSignal("AbsoluteSize").Connect(schedule);
			const contentConnection = layout.GetPropertyChangedSignal("AbsoluteContentSize").Connect(schedule);
			return () => {
				alive = false;
				sizeConnection.Disconnect();
				contentConnection.Disconnect();
			};
		}, [autoCanvas, breakpoints, canvasTail, cellAspectRatio, cellHeight, columnGap, columns, maxCellWidth, minCellWidth, minColumns, pack, rowGap]);
		const columnCount = math.max(1, math.floor(columns));
		return h("uigridlayout", {
			ref: layoutRef,
			CellSize: new UDim2(1 / columnCount, -math.ceil((columnGap * (columnCount - 1)) / columnCount), 0, cellHeight),
			CellPadding: UDim2.fromOffset(columnGap, rowGap),
			FillDirection: fillDirection,
			FillDirectionMaxCells: columnCount,
			HorizontalAlignment: horizontalAlignment,
			VerticalAlignment: verticalAlignment,
			StartCorner: startCorner,
			SortOrder: sortOrder,
		});
	}

	function VirtualGrid(_param: VirtualGridProps) {
		const scrollRef = _param.scrollRef;
		const count = _param.count;
		const columns = _param.columns;
		const cellHeight = _param.cellHeight;
		const gap = _param.gap;
		let overscanRows = _param.overscanRows;
		if (overscanRows === undefined || overscanRows < 1) {
			overscanRows = 1;
		}
		let layoutOrder = _param.layoutOrder;
		if (layoutOrder === undefined) {
			layoutOrder = 0;
		}
		const position = _param.position;
		const itemKey = _param.itemKey;
		const renderItem = _param.renderItem;
		const hostRef = React.useRef<Frame>();
		const rows = math.ceil(count / math.max(1, columns));
		const stride = cellHeight + gap;
		const height = math.max(0, rows * cellHeight + math.max(0, rows - 1) * gap);
		const seedLast = count <= 0 ? -1 : math.min(count - 1, math.max(columns * 3, columns) - 1);
		const initial = {
			first: 0,
			last: seedLast,
		};
		const [window, setWindow] = React.useState(initial);
		const latest = React.useRef(initial);
		React.useEffect(() => {
			const host = hostRef.current;
			const scroll = scrollRef.current;
			if (host === undefined || scroll === undefined || count <= 0) {
				return undefined;
			}
			let alive = true;
			const sync = () => {
				if (!alive || host.Parent === undefined || scroll.Parent === undefined) {
					return undefined;
				}
				const viewportTop = scroll.AbsolutePosition.Y;
				const viewportBottom = viewportTop + math.max(1, scroll.AbsoluteWindowSize.Y);
				const hostTop = host.AbsolutePosition.Y;
				const hostBottom = hostTop + host.AbsoluteSize.Y;
				let first = 0;
				let last = -1;
				if (hostBottom >= viewportTop - stride * overscanRows && hostTop <= viewportBottom + stride * overscanRows) {
					const firstRow = math.clamp(math.floor((viewportTop - hostTop) / stride) - overscanRows, 0, math.max(0, rows - 1));
					const lastRow = math.clamp(
						math.floor((viewportBottom - hostTop) / stride) + overscanRows,
						firstRow,
						math.max(0, rows - 1),
					);
					first = firstRow * columns;
					last = math.min(count - 1, (lastRow + 1) * columns - 1);
				}
				const previous = latest.current;
				if (previous.first === first && previous.last === last) {
					return undefined;
				}
				const nextWindow = {
					first: first,
					last: last,
				};
				latest.current = nextWindow;
				setWindow(nextWindow);
			};
			const connections = [
				scroll.GetPropertyChangedSignal("CanvasPosition").Connect(sync),
				scroll.GetPropertyChangedSignal("AbsolutePosition").Connect(sync),
				scroll.GetPropertyChangedSignal("AbsoluteWindowSize").Connect(sync),
				host.GetPropertyChangedSignal("AbsoluteSize").Connect(sync),
			];
			task.defer(sync);
			return () => {
				alive = false;
				for (const connection of connections) {
					connection.Disconnect();
				}
			};
		}, [cellHeight, columns, count, gap, overscanRows, rows, scrollRef, stride]);
		const visible: Record<string, React.ReactElement> = {};
		const windowLast = math.min(window.last, count - 1);
		if (windowLast >= window.first) {
			for (let index = window.first; index <= windowLast; index++) {
				const row = math.floor(index / columns);
				const column = index % columns;
				visible[itemKey(index)] = h(
					"frame",
					{
						Size: new UDim2(1 / columns, -(gap * (columns - 1)) / columns, 0, cellHeight),
						Position: new UDim2(column / columns, (column * gap) / columns, 0, row * stride),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						Active: false,
					},
					renderItem(index),
				);
			}
		}
		return h(
			"frame",
			{
				ref: hostRef,
				Size: new UDim2(1, 0, 0, height),
				Position: position,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				LayoutOrder: layoutOrder,
				Active: false,
				ClipsDescendants: false,
			},
			visible,
		);
	}

	const PageScrollContext = React.createContext<ScrollHostContext | undefined>(undefined);
	function useVirtualWindow(
		count: number,
		stride: number,
		topOffset: number,
		overscan?: number,
		hostRef?: MutableRefObject<ScrollingFrame | undefined>,
	): VirtualWindow {
		if (overscan === undefined) {
			overscan = CONSTRAINED_SCROLL ? 1 : 2;
		}
		overscan = math.max(1, overscan);
		const frame = React.useRef<ScrollingFrame>();
		const initial = {
			first: 0,
			last: math.min(math.max(0, count - 1), CONSTRAINED_SCROLL ? 6 : 10),
		};
		const [window, setWindow] = React.useState(initial);
		const latest = React.useRef(initial);
		React.useEffect(() => {
			const scrolling = frame.current;
			if (!scrolling) {
				return undefined;
			}
			let scheduled = false;
			let alive = true;
			const host = hostRef !== undefined ? hostRef.current : undefined;
			const sync = () => {
				scheduled = false;
				if (!alive) {
					return undefined;
				}
				if (count <= 0) {
					const empty = {
						first: 0,
						last: -1,
					};
					latest.current = empty;
					setWindow(empty);
					return undefined;
				}
				let top: number;
				let height: number;
				if (host !== undefined && host.Parent !== undefined) {
					top = host.AbsolutePosition.Y - scrolling.AbsolutePosition.Y;
					height = math.max(1, host.AbsoluteWindowSize.Y);
				} else {
					top = scrolling.CanvasPosition.Y;
					height = math.max(1, scrolling.AbsoluteWindowSize.Y);
				}
				const first = math.clamp(math.floor((top - topOffset) / stride) - overscan, 0, count - 1);
				const last = math.clamp(math.ceil((top + height - topOffset) / stride) + overscan, first, count - 1);
				const previous = latest.current;
				if (previous.first === first && previous.last === last) {
					return undefined;
				}
				const range = {
					first: first,
					last: last,
				};
				latest.current = range;
				setWindow(range);
			};
			const schedule = () => {
				if (scheduled) {
					return undefined;
				}
				scheduled = true;
				task.defer(sync);
			};
			sync();
			const source = host !== undefined ? host : scrolling;
			const moved = source.GetPropertyChangedSignal("CanvasPosition").Connect(schedule);
			const resized = source.GetPropertyChangedSignal("AbsoluteWindowSize").Connect(schedule);
			const shifted = host !== undefined ? scrolling.GetPropertyChangedSignal("AbsolutePosition").Connect(schedule) : undefined;
			return () => {
				alive = false;
				moved.Disconnect();
				resized.Disconnect();
				if (shifted !== undefined) {
					shifted.Disconnect();
				}
			};
		}, [count, overscan, stride, topOffset, hostRef ?? false]);
		return {
			frame: frame,
			first: window.first,
			last: window.last,
		};
	}

	return {
		disposeScrollPerformance: disposeScrollPerformance,
		setScrollSpeed: setScrollSpeed,
		setScrollMomentum: setScrollMomentum,
		installScrollPerformance: installScrollPerformance,
		AutoGrid: AutoGrid,
		VirtualGrid: VirtualGrid,
		useVirtualWindow: useVirtualWindow,
		PageScrollContext: PageScrollContext,
	};
};

interface RenderInfo {
	item: unknown;
	index: number;
}

interface VirtualizedListProps {
	data: ReadonlyArray<unknown>;
	itemHeight: number;
	headerHeight?: number;
	footerHeight?: number;
	overscan?: number;
	embedded?: boolean;
	frameRef?: MutableRefObject<ScrollingFrame | undefined>;
	keyExtractor?: (item: unknown, index: number) => string;
	renderItem: (info: RenderInfo) => unknown;
	ListHeaderComponent?: unknown;
	ListEmptyComponent?: unknown;
	ListFooterComponent?: unknown;
	canvasTail?: number;
	Size?: UDim2;
	Position?: UDim2;
	scrollBarThickness?: number;
	scrollBarColor?: Color3;
	scrollBarTransparency?: number;
	ZIndex?: number;
	layoutOrder?: number;
}

__defs["virtualizedList"] = () => {
	const React = loadReact();
	const h = React.createElement as unknown as LooseCreate;
	const scrolling = __load("scrolling") as ScrollingModule;
	const useVirtualWindow = scrolling.useVirtualWindow;
	const PageScrollContext = scrolling.PageScrollContext;
	const Palette = (kitMember("CoreKit", "theme") as typeof import("./CoreKit/theme")).Palette;

	function virtualRange(count: number, stride: number, topOffset: number, scrollY: number, viewHeight: number, overscan = 2) {
		if (count <= 0 || stride <= 0) {
			return {
				first: 0,
				last: -1,
			};
		}
		const height = math.max(1, viewHeight);
		const first = math.clamp(math.floor((scrollY - topOffset) / stride) - overscan, 0, count - 1);
		const last = math.clamp(math.ceil((scrollY + height - topOffset) / stride) + overscan, first, count - 1);
		return {
			first: first,
			last: last,
		};
	}

	function useVirtualizedList(count: number, itemHeight: number, headerHeight = 0, overscan?: number) {
		return useVirtualWindow(count, itemHeight, headerHeight, overscan);
	}

	function resolveKey(item: unknown, index: number, extractor?: (item: unknown, index: number) => string): string {
		if (extractor !== undefined) {
			return extractor(item, index);
		}
		if (!typeIs(item, "table")) {
			return tostring(index);
		}
		const record = item as Record<string, unknown>;
		const id = record.Id;
		if (typeIs(id, "string") && id.size() > 0) {
			return id;
		}
		const lowerId = record.id;
		if (typeIs(lowerId, "string") && lowerId.size() > 0) {
			return lowerId;
		}
		const uid = record.uid;
		if (typeIs(uid, "string") && uid.size() > 0) {
			return uid;
		}
		return tostring(index);
	}

	function VirtualRow(props: { height: number; top: number; children?: unknown }) {
		return h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, props.height),
				Position: UDim2.fromOffset(0, props.top),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			props.children,
		);
	}

	function VirtualizedList(props: VirtualizedListProps) {
		const data = props.data;
		const itemHeight = math.max(1, props.itemHeight);
		const headerHeight = math.max(0, props.headerHeight ?? 0);
		const footerHeight = math.max(0, props.footerHeight ?? 0);
		const overscan = props.overscan;
		const count = data.size();
		const scrollHost = React.useContext(PageScrollContext);
		const autoEmbed = scrollHost !== undefined && scrollHost.overflowing === true && props.embedded !== false;
		const embedded = props.embedded === true || autoEmbed;
		const hostRef = embedded && scrollHost !== undefined ? scrollHost.hostRef : undefined;
		const window = useVirtualWindow(count, itemHeight, headerHeight, overscan, hostRef);
		const windowed = !embedded || hostRef !== undefined;
		const rangeFirst = windowed ? window.first : 0;
		const rangeLast = windowed ? window.last : count - 1;
		const ownedRef = React.useRef<ScrollingFrame>();
		const bindRef = (frame: ScrollingFrame | undefined) => {
			ownedRef.current = frame;
			window.frame.current = frame;
			if (frame !== undefined) {
				frame.SetAttribute("LayoutGuardAllowDisabledScroll", embedded);
			}
			if (props.frameRef !== undefined) {
				props.frameRef.current = frame;
			}
		};
		const rows = new Array<React.ReactElement>();
		for (let index = rangeFirst; index <= rangeLast; index++) {
			const item = data[index];
			if (item === undefined) {
				continue;
			}
			rows.push(
				h(
					VirtualRow,
					{
						key: resolveKey(item, index, props.keyExtractor),
						index: index,
						height: itemHeight,
						top: headerHeight + index * itemHeight,
					},
					props.renderItem({
						item: item,
						index: index,
					}),
				),
			);
		}
		const canvasTail = props.canvasTail ?? 0;
		const canvasH =
			headerHeight +
			math.max(count, count === 0 && props.ListEmptyComponent !== undefined ? 1 : 0) * (count > 0 ? itemHeight : 0) +
			footerHeight +
			canvasTail;
		const emptyCanvas = headerHeight + (count === 0 && props.ListEmptyComponent !== undefined ? 150 : 0) + footerHeight + canvasTail;
		const reportedHeight = count > 0 ? canvasH : emptyCanvas;
		let trailing = 0;
		const declaredSize = props.Size;
		if (typeIs(declaredSize, "UDim2") && declaredSize.Y.Scale >= 0.999) {
			const declaredPosition = props.Position;
			const positionOffset = typeIs(declaredPosition, "UDim2") ? declaredPosition.Y.Offset : 0;
			trailing = math.max(0, -declaredSize.Y.Offset - positionOffset);
		}
		React.useEffect(() => {
			if (!autoEmbed || scrollHost === undefined) {
				return undefined;
			}
			let lastReport = -1;
			const push = () => {
				const frame = ownedRef.current;
				const section = scrollHost.sectionRef.current;
				let lead = 0;
				if (frame !== undefined && section !== undefined) {
					lead = math.max(0, frame.AbsolutePosition.Y - section.AbsolutePosition.Y);
				}
				const total = math.ceil(lead + reportedHeight + trailing + 4);
				if (total !== lastReport) {
					lastReport = total;
					scrollHost.report(total);
				}
			};
			push();
			const frame = ownedRef.current;
			const moved = frame !== undefined ? frame.GetPropertyChangedSignal("AbsolutePosition").Connect(push) : undefined;
			return () => {
				if (moved !== undefined) {
					moved.Disconnect();
				}
			};
		}, [autoEmbed, reportedHeight, trailing]);
		const attributes: Record<string, unknown> = {
			ref: bindRef,
			Size: props.Size ?? UDim2.fromScale(1, 1),
			Position: props.Position ?? UDim2.fromOffset(0, 0),
			CanvasSize: new UDim2(0, 0, 0, count > 0 ? canvasH : emptyCanvas),
			AutomaticCanvasSize: Enum.AutomaticSize.None,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ScrollingDirection: Enum.ScrollingDirection.Y,
			ScrollBarThickness: props.scrollBarThickness ?? 3,
			ScrollBarImageColor3: props.scrollBarColor ?? Palette.cyan,
			ScrollBarImageTransparency: props.scrollBarTransparency ?? 0.28,
			ClipsDescendants: true,
			ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
			VerticalScrollBarInset: Enum.ScrollBarInset.ScrollBar,
			Active: !embedded,
			Selectable: false,
			ZIndex: props.ZIndex,
			LayoutOrder: props.layoutOrder,
		};
		if (embedded) {
			attributes.ScrollingEnabled = false;
			attributes.ScrollBarThickness = 0;
			attributes.ClipsDescendants = false;
			attributes.Size = new UDim2(1, 0, 0, count > 0 ? canvasH : emptyCanvas);
		}
		return h(
			"scrollingframe",
			attributes,
			props.ListHeaderComponent,
			count === 0 && props.ListEmptyComponent,
			rows,
			props.ListFooterComponent,
		);
	}

	function FlatList(props: VirtualizedListProps) {
		const attributes = table.clone(props) as unknown as Record<string, unknown>;
		setmetatable(attributes, undefined);
		return h(VirtualizedList, attributes);
	}

	return {
		virtualRange: virtualRange,
		useVirtualizedList: useVirtualizedList,
		VirtualizedList: VirtualizedList,
		FlatList: FlatList,
	};
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type LayoutKitCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const LayoutKit = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string): unknown => {
			return __load(name);
		},
		__index: (_self: unknown, name: string): unknown => {
			if (name === "__members") {
				return __members;
			}
			return __load(name);
		},
	} as LuaMetatable<object>,
) as unknown as LayoutKitCallable;
export = LayoutKit;
