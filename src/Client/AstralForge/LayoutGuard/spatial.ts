// Spatial indexes for pairwise checks. A UI page has a few hundred to a few thousand rects; a naive
// all-pairs pass is O(n^2) and was the old guard's main per-scan cost.
//
//  - UniformGrid: hash grid with a cell size picked from the median rect size. Best when rects are
//    similar in size (button grids, inventory slots). Pairs are deduplicated by reporting a pair
//    only from the cell that holds the top-left corner of the pair's intersection.
//  - IntervalTreap: balanced (randomised treap with a fixed-seed LCG, so runs are reproducible)
//    augmented interval tree keyed by y0 with subtree max(y1). Insert/delete O(log n), stabbing
//    and overlap queries O(log n + k).
//  - sweepPairs: sweep-and-prune over x; the active set is the interval treap over y. Total
//    O((n + k) log n) for k reported pairs, robust to wildly different rect sizes (full-screen
//    backdrops next to 12px icons), which is where grids degrade.
//  - choosePairs: picks the strategy from the size distribution.
// References: de Berg et al., "Computational Geometry", ch. 10 (interval trees); Baraff 1992 and
// the open-source PruneJuice / Broadmark / RBush implementations for broad-phase design.
import { Rect, intersects } from "./geom";

export interface Boxed {
	id: number;
	rect: Rect;
}

// ---------------------------------------------------------------------------------------------
// Uniform grid

export class UniformGrid {
	private cells = new Map<string, { cx: number; cy: number; list: number[] }>();
	private items: Boxed[] = [];
	constructor(readonly cell: number) {}

	private key(cx: number, cy: number): string {
		return cx + ":" + cy;
	}

	insert(item: Boxed) {
		const index = this.items.size();
		this.items.push(item);
		const c = this.cell;
		const x0 = math.floor(item.rect.x0 / c);
		const x1 = math.floor((item.rect.x1 - 1e-6) / c);
		const y0 = math.floor(item.rect.y0 / c);
		const y1 = math.floor((item.rect.y1 - 1e-6) / c);
		for (let x = x0; x <= x1; x++) {
			for (let y = y0; y <= y1; y++) {
				const k = this.key(x, y);
				let bucket = this.cells.get(k);
				if (bucket === undefined) {
					bucket = { cx: x, cy: y, list: [] };
					this.cells.set(k, bucket);
				}
				bucket.list.push(index);
			}
		}
	}

	/** every stored item whose rect intersects `r` (each once) */
	query(r: Rect): Boxed[] {
		const c = this.cell;
		const seen = new Set<number>();
		const out: Boxed[] = [];
		for (let x = math.floor(r.x0 / c); x <= math.floor((r.x1 - 1e-6) / c); x++) {
			for (let y = math.floor(r.y0 / c); y <= math.floor((r.y1 - 1e-6) / c); y++) {
				const bucket = this.cells.get(this.key(x, y));
				if (bucket === undefined) continue;
				for (const index of bucket.list) {
					if (seen.has(index)) continue;
					seen.add(index);
					const item = this.items[index];
					if (intersects(item.rect, r)) out.push(item);
				}
			}
		}
		return out;
	}

	/** all intersecting pairs, each reported exactly once */
	pairs(visit: (a: Boxed, b: Boxed) => void) {
		const c = this.cell;
		for (const [, cellEntry] of this.cells) {
			const bucket = cellEntry.list;
			if (bucket.size() < 2) continue;
			const cx = cellEntry.cx;
			const cy = cellEntry.cy;
			for (let i = 0; i < bucket.size(); i++) {
				const a = this.items[bucket[i]];
				for (let j = i + 1; j < bucket.size(); j++) {
					const b = this.items[bucket[j]];
					if (!intersects(a.rect, b.rect)) continue;
					// owner cell = the one containing the intersection's top-left corner
					const ox = math.floor(math.max(a.rect.x0, b.rect.x0) / c);
					const oy = math.floor(math.max(a.rect.y0, b.rect.y0) / c);
					if (ox === cx && oy === cy) visit(a, b);
				}
			}
		}
	}

	size(): number {
		return this.items.size();
	}
}

// ---------------------------------------------------------------------------------------------
// Interval treap (augmented BST keyed by lo, ties by id)

interface TNode {
	lo: number;
	hi: number;
	id: number;
	prio: number;
	max: number;
	left?: TNode;
	right?: TNode;
}

function lcg(seed: number): () => number {
	let state = seed % 2147483647;
	if (state <= 0) state += 2147483646;
	return () => {
		state = (state * 48271) % 2147483647;
		return state;
	};
}

function fix(n: TNode) {
	let m = n.hi;
	if (n.left !== undefined && n.left.max > m) m = n.left.max;
	if (n.right !== undefined && n.right.max > m) m = n.right.max;
	n.max = m;
}

function less(lo: number, id: number, n: TNode): boolean {
	return lo < n.lo || (lo === n.lo && id < n.id);
}

function rotateRight(n: TNode): TNode {
	const l = n.left!;
	n.left = l.right;
	l.right = n;
	fix(n);
	fix(l);
	return l;
}

function rotateLeft(n: TNode): TNode {
	const r = n.right!;
	n.right = r.left;
	r.left = n;
	fix(n);
	fix(r);
	return r;
}

export class IntervalTreap {
	private root?: TNode;
	private count = 0;
	private rand = lcg(1234567);

	size(): number {
		return this.count;
	}

	insert(lo: number, hi: number, id: number) {
		const node: TNode = { lo, hi, id, prio: this.rand(), max: hi };
		this.root = this.insertAt(this.root, node);
		this.count += 1;
	}

	private insertAt(at: TNode | undefined, node: TNode): TNode {
		if (at === undefined) return node;
		if (less(node.lo, node.id, at)) {
			at.left = this.insertAt(at.left, node);
			if (at.left.prio > at.prio) at = rotateRight(at);
		} else {
			at.right = this.insertAt(at.right, node);
			if (at.right.prio > at.prio) at = rotateLeft(at);
		}
		fix(at);
		return at;
	}

	remove(lo: number, id: number): boolean {
		const before = this.count;
		this.root = this.removeAt(this.root, lo, id);
		return this.count < before;
	}

	private removeAt(at: TNode | undefined, lo: number, id: number): TNode | undefined {
		if (at === undefined) return undefined;
		if (at.lo === lo && at.id === id) {
			this.count -= 1;
			return this.merge(at.left, at.right);
		}
		if (less(lo, id, at)) {
			at.left = this.removeAt(at.left, lo, id);
		} else {
			at.right = this.removeAt(at.right, lo, id);
		}
		fix(at);
		return at;
	}

	private merge(a: TNode | undefined, b: TNode | undefined): TNode | undefined {
		if (a === undefined) return b;
		if (b === undefined) return a;
		if (a.prio > b.prio) {
			a.right = this.merge(a.right, b);
			fix(a);
			return a;
		}
		b.left = this.merge(a, b.left);
		fix(b);
		return b;
	}

	/** ids of intervals that overlap the open interval (lo, hi) */
	overlapping(lo: number, hi: number, out: number[] = []): number[] {
		const walk = (n: TNode | undefined) => {
			if (n === undefined || n.max <= lo) return;
			walk(n.left);
			if (n.lo < hi && lo < n.hi) out.push(n.id);
			// right subtree keys are >= n.lo; once n.lo >= hi nothing to the right can overlap
			if (n.lo < hi) walk(n.right);
		};
		walk(this.root);
		return out;
	}

	/** tree height (for tests: a treap stays O(log n) expected) */
	height(): number {
		const h = (n: TNode | undefined): number => (n === undefined ? 0 : 1 + math.max(h(n.left), h(n.right)));
		return h(this.root);
	}
}

// ---------------------------------------------------------------------------------------------
// Sweep and prune

interface SweepEvent {
	x: number;
	open: boolean;
	index: number;
}

/** Visits every pair of intersecting rects once. O((n + k) log n). */
export function sweepPairs(items: ReadonlyArray<Boxed>, visit: (a: Boxed, b: Boxed) => void) {
	const events: SweepEvent[] = [];
	for (let i = 0; i < items.size(); i++) {
		const r = items[i].rect;
		if (r.x1 <= r.x0 || r.y1 <= r.y0) continue;
		events.push({ x: r.x0, open: true, index: i });
		events.push({ x: r.x1, open: false, index: i });
	}
	// closes before opens at the same x: touching edges are not overlaps (half-open rects)
	events.sort((a, b) => (a.x === b.x ? !a.open && b.open : a.x < b.x));
	const active = new IntervalTreap();
	const hits: number[] = [];
	for (const e of events) {
		const item = items[e.index];
		if (e.open) {
			hits.clear();
			active.overlapping(item.rect.y0, item.rect.y1, hits);
			for (const other of hits) visit(items[other], item);
			active.insert(item.rect.y0, item.rect.y1, e.index);
		} else {
			active.remove(item.rect.y0, e.index);
		}
	}
}

export function medianSide(items: ReadonlyArray<Boxed>): number {
	const sides: number[] = [];
	for (const item of items) {
		sides.push(math.max(item.rect.x1 - item.rect.x0, item.rect.y1 - item.rect.y0));
	}
	if (sides.size() === 0) return 64;
	sides.sort((a, b) => a < b);
	return sides[math.floor(sides.size() / 2)];
}

/**
 * Strategy pick: a grid is cheapest when the biggest rect spans only a few cells; one full-screen
 * rect in a grid of 40px cells would touch hundreds of cells, so mixed sizes go to the sweep.
 */
export function choosePairs(items: ReadonlyArray<Boxed>, visit: (a: Boxed, b: Boxed) => void): "grid" | "sweep" | "brute" {
	const n = items.size();
	if (n < 24) {
		for (let i = 0; i < n; i++) {
			for (let j = i + 1; j < n; j++) {
				if (intersects(items[i].rect, items[j].rect)) visit(items[i], items[j]);
			}
		}
		return "brute";
	}
	const median = math.max(8, medianSide(items));
	let largest = 0;
	for (const item of items) {
		largest = math.max(largest, item.rect.x1 - item.rect.x0, item.rect.y1 - item.rect.y0);
	}
	if (largest <= median * 4) {
		const grid = new UniformGrid(median * 1.5);
		for (const item of items) grid.insert(item);
		grid.pairs(visit);
		return "grid";
	}
	sweepPairs(items, visit);
	return "sweep";
}

/** Static query index over many rects: buckets by x via the treap, filters by y. */
export class RectIndex {
	private tree = new IntervalTreap();
	private items: Boxed[] = [];
	constructor(items: ReadonlyArray<Boxed>) {
		for (const item of items) {
			this.tree.insert(item.rect.x0, item.rect.x1, this.items.size());
			this.items.push(item);
		}
	}
	query(r: Rect): Boxed[] {
		const out: Boxed[] = [];
		for (const index of this.tree.overlapping(r.x0, r.x1)) {
			const item = this.items[index];
			if (item.rect.y0 < r.y1 && r.y0 < item.rect.y1) out.push(item);
		}
		return out;
	}
	/** items whose rect contains the point */
	at(x: number, y: number): Boxed[] {
		return this.query({ x0: x, y0: y, x1: x + 1e-3, y1: y + 1e-3 });
	}
}
