// Statistics and 1-D/2-D measures used by the whitespace, alignment, density and focus-order
// rules. Pure; tested under lune.
import { Rect, area, intersect, isEmpty } from "./geom";

export function sum(values: ReadonlyArray<number>): number {
	let total = 0;
	for (const v of values) total += v;
	return total;
}

export function mean(values: ReadonlyArray<number>): number {
	return values.size() > 0 ? sum(values) / values.size() : 0;
}

export function sortedCopy(values: ReadonlyArray<number>): number[] {
	const copy = [...values];
	copy.sort((a, b) => a < b);
	return copy;
}

/** Linear-interpolated quantile (type 7, same as numpy's default). */
export function quantile(values: ReadonlyArray<number>, q: number): number {
	const n = values.size();
	if (n === 0) return 0;
	const s = sortedCopy(values);
	const h = (n - 1) * math.clamp(q, 0, 1);
	const lo = math.floor(h);
	const hi = math.min(n - 1, lo + 1);
	return s[lo] + (h - lo) * (s[hi] - s[lo]);
}

export function median(values: ReadonlyArray<number>): number {
	return quantile(values, 0.5);
}

export function variance(values: ReadonlyArray<number>): number {
	const n = values.size();
	if (n < 2) return 0;
	const m = mean(values);
	let acc = 0;
	for (const v of values) acc += (v - m) * (v - m);
	return acc / (n - 1);
}

export function stddev(values: ReadonlyArray<number>): number {
	return math.sqrt(variance(values));
}

/** Coefficient of variation (stddev / mean); 0 for an empty or zero-mean set. */
export function cv(values: ReadonlyArray<number>): number {
	const m = mean(values);
	return m !== 0 ? stddev(values) / math.abs(m) : 0;
}

/** Median absolute deviation (robust spread). */
export function mad(values: ReadonlyArray<number>): number {
	const m = median(values);
	const dev: number[] = [];
	for (const v of values) dev.push(math.abs(v - m));
	return median(dev);
}

/** Gini coefficient of non-negative values: 0 = perfectly even, ->1 = one value holds everything. */
export function gini(values: ReadonlyArray<number>): number {
	const n = values.size();
	if (n === 0) return 0;
	const s = sortedCopy(values);
	let weighted = 0;
	let total = 0;
	for (let i = 0; i < n; i++) {
		weighted += (i + 1) * s[i];
		total += s[i];
	}
	if (total <= 0) return 0;
	return (2 * weighted) / (n * total) - (n + 1) / n;
}

/** Shannon entropy (bits) of a histogram, normalised to [0, 1] by log2(bins). */
export function normalizedEntropy(counts: ReadonlyArray<number>): number {
	const total = sum(counts);
	if (total <= 0 || counts.size() < 2) return 0;
	let h = 0;
	for (const c of counts) {
		if (c > 0) {
			const p = c / total;
			h -= p * (math.log(p) / math.log(2));
		}
	}
	return h / (math.log(counts.size()) / math.log(2));
}

// ---------------------------------------------------------------------------------------------
// 1-D clustering

export interface Cluster {
	center: number;
	members: number[];
	/** indices into the input array */
	indices: number[];
	spread: number;
}

/**
 * Single-linkage clustering of scalars: sorted values join the previous cluster while the gap to
 * its last member is <= tolerance. O(n log n). Used for edge alignment (left edges within 2px are
 * meant to be one guide line).
 */
export function clusterByGap(values: ReadonlyArray<number>, tolerance: number): Cluster[] {
	const order: number[] = [];
	for (let i = 0; i < values.size(); i++) order.push(i);
	order.sort((a, b) => values[a] < values[b]);
	const clusters: Cluster[] = [];
	let current: Cluster | undefined;
	let last = -math.huge;
	for (const i of order) {
		const v = values[i];
		if (current === undefined || v - last > tolerance) {
			current = { center: 0, members: [], indices: [], spread: 0 };
			clusters.push(current);
		}
		current.members.push(v);
		current.indices.push(i);
		last = v;
	}
	for (const c of clusters) {
		c.center = median(c.members);
		c.spread = c.members[c.members.size() - 1] - c.members[0];
	}
	return clusters;
}

/**
 * Optimal 1-D k-means by dynamic programming (Wang & Song 2011, "Ckmeans.1d.dp"), O(k n^2).
 * Returns cluster boundaries as arrays of sorted values. n is capped by callers (<= 256).
 */
export function kmeans1d(values: ReadonlyArray<number>, k: number): number[][] {
	const x = sortedCopy(values);
	const n = x.size();
	if (n === 0) return [];
	const kk = math.clamp(k, 1, n);
	const prefix: number[] = [0];
	const prefix2: number[] = [0];
	for (let i = 0; i < n; i++) {
		prefix.push(prefix[i] + x[i]);
		prefix2.push(prefix2[i] + x[i] * x[i]);
	}
	// within-cluster sum of squares for x[i..j] inclusive
	const ssq = (i: number, j: number): number => {
		const cnt = j - i + 1;
		const s = prefix[j + 1] - prefix[i];
		const s2 = prefix2[j + 1] - prefix2[i];
		return math.max(0, s2 - (s * s) / cnt);
	};
	const cost: number[][] = [];
	const back: number[][] = [];
	for (let m = 0; m < kk; m++) {
		const row: number[] = [];
		const brow: number[] = [];
		for (let j = 0; j < n; j++) {
			if (m === 0) {
				row.push(ssq(0, j));
				brow.push(0);
			} else {
				let best = math.huge;
				let arg = m;
				for (let i = m; i <= j; i++) {
					const c = cost[m - 1][i - 1] + ssq(i, j);
					if (c < best) {
						best = c;
						arg = i;
					}
				}
				row.push(best);
				brow.push(arg);
			}
		}
		cost.push(row);
		back.push(brow);
	}
	const groups: number[][] = [];
	let j = n - 1;
	for (let m = kk - 1; m >= 0; m--) {
		const start = back[m][j];
		const g: number[] = [];
		for (let i = start; i <= j; i++) g.push(x[i]);
		groups.unshift(g);
		j = start - 1;
		if (j < 0) break;
	}
	return groups;
}

/** Total within-cluster sum of squares of a grouping. */
export function withinSS(groups: ReadonlyArray<ReadonlyArray<number>>): number {
	let total = 0;
	for (const g of groups) {
		const m = mean(g);
		for (const v of g) total += (v - m) * (v - m);
	}
	return total;
}

/** Elbow pick for k in [1, maxK]: the first k whose marginal SS gain drops under `gain` of total. */
export function bestK(values: ReadonlyArray<number>, maxK: number, gain = 0.1): number {
	const base = withinSS([values as number[]]);
	if (base <= 0) return 1;
	let previous = base;
	for (let k = 2; k <= math.min(maxK, values.size()); k++) {
		const ss = withinSS(kmeans1d(values, k));
		if ((previous - ss) / base < gain) return k - 1;
		previous = ss;
	}
	return math.min(maxK, values.size());
}

// ---------------------------------------------------------------------------------------------
// Intervals and bands

export interface Span {
	lo: number;
	hi: number;
}

/** Merges overlapping/touching spans; output sorted and disjoint. */
export function mergeSpans(spans: ReadonlyArray<Span>, join = 0): Span[] {
	const s = [...spans];
	s.sort((a, b) => a.lo < b.lo);
	const out: Span[] = [];
	for (const span of s) {
		if (span.hi <= span.lo) continue;
		const last = out[out.size() - 1];
		if (last !== undefined && span.lo <= last.hi + join) {
			last.hi = math.max(last.hi, span.hi);
		} else {
			out.push({ lo: span.lo, hi: span.hi });
		}
	}
	return out;
}

/** Gaps inside [lo, hi] not covered by `spans`, at least `minGap` long. */
export function freeBands(spans: ReadonlyArray<Span>, lo: number, hi: number, minGap: number): Span[] {
	const merged = mergeSpans(spans);
	const out: Span[] = [];
	let at = lo;
	for (const s of merged) {
		if (s.hi <= lo) continue;
		if (s.lo >= hi) break;
		if (s.lo - at >= minGap) out.push({ lo: at, hi: math.min(s.lo, hi) });
		at = math.max(at, s.hi);
	}
	if (hi - at >= minGap) out.push({ lo: at, hi });
	return out;
}

export function coveredLength(spans: ReadonlyArray<Span>, lo: number, hi: number): number {
	let total = 0;
	for (const s of mergeSpans(spans)) {
		total += math.max(0, math.min(hi, s.hi) - math.max(lo, s.lo));
	}
	return total;
}

// ---------------------------------------------------------------------------------------------
// 2-D: occupancy raster and the largest empty rectangle

export interface Raster {
	cols: number;
	rows: number;
	cell: number;
	origin: { x: number; y: number };
	/** row-major occupancy, 1 = covered */
	cells: number[];
}

/** Rasterises rects (clipped to the container) into a coarse occupancy grid (<= maxCells cells). */
export function rasterize(container: Rect, rects: ReadonlyArray<Rect>, maxCells = 4096): Raster {
	const w = container.x1 - container.x0;
	const h = container.y1 - container.y0;
	const cell = math.max(4, math.ceil(math.sqrt((w * h) / maxCells)));
	const cols = math.max(1, math.ceil(w / cell));
	const rows = math.max(1, math.ceil(h / cell));
	const cells: number[] = [];
	for (let i = 0; i < cols * rows; i++) cells.push(0);
	for (const raw of rects) {
		const r = intersect(raw, container);
		if (isEmpty(r)) continue;
		// a cell counts as covered when its centre is inside the rect
		const c0 = math.max(0, math.floor((r.x0 - container.x0) / cell + 0.5));
		const c1 = math.min(cols - 1, math.ceil((r.x1 - container.x0) / cell - 0.5) - 1);
		const r0 = math.max(0, math.floor((r.y0 - container.y0) / cell + 0.5));
		const r1 = math.min(rows - 1, math.ceil((r.y1 - container.y0) / cell - 0.5) - 1);
		for (let y = r0; y <= r1; y++) {
			for (let x = c0; x <= c1; x++) cells[y * cols + x] = 1;
		}
	}
	return { cols, rows, cell, origin: { x: container.x0, y: container.y0 }, cells };
}

export function rasterFill(r: Raster): number {
	return r.cells.size() > 0 ? sum(r.cells) / r.cells.size() : 0;
}

/**
 * Largest all-empty axis-aligned rectangle in the raster (maximal-rectangle via per-row
 * histograms and a monotonic stack, O(rows * cols)). Returned in absolute pixels.
 */
export function largestEmptyRect(r: Raster): Rect {
	const heights: number[] = [];
	for (let i = 0; i < r.cols; i++) heights.push(0);
	let bestArea = 0;
	let best = { x0: 0, y0: 0, x1: 0, y1: 0 };
	for (let y = 0; y < r.rows; y++) {
		for (let x = 0; x < r.cols; x++) {
			heights[x] = r.cells[y * r.cols + x] === 0 ? heights[x] + 1 : 0;
		}
		const stack: number[] = [];
		for (let x = 0; x <= r.cols; x++) {
			const hx = x < r.cols ? heights[x] : 0;
			while (stack.size() > 0 && heights[stack[stack.size() - 1]] >= hx) {
				const top = stack.pop()!;
				const hgt = heights[top];
				const left = stack.size() > 0 ? stack[stack.size() - 1] + 1 : 0;
				const a = hgt * (x - left);
				if (a > bestArea) {
					bestArea = a;
					best = { x0: left, y0: y - hgt + 1, x1: x, y1: y + 1 };
				}
			}
			stack.push(x);
		}
	}
	return {
		x0: r.origin.x + best.x0 * r.cell,
		y0: r.origin.y + best.y0 * r.cell,
		x1: r.origin.x + best.x1 * r.cell,
		y1: r.origin.y + best.y1 * r.cell,
	};
}

/** Per-cell density heat (0..1) on a coarse grid: share of each cell covered by any rect. */
export function densityGrid(container: Rect, rects: ReadonlyArray<Rect>, cols: number, rows: number): number[] {
	const out: number[] = [];
	const cw = (container.x1 - container.x0) / cols;
	const ch = (container.y1 - container.y0) / rows;
	for (let y = 0; y < rows; y++) {
		for (let x = 0; x < cols; x++) {
			const cellRect = {
				x0: container.x0 + x * cw,
				y0: container.y0 + y * ch,
				x1: container.x0 + (x + 1) * cw,
				y1: container.y0 + (y + 1) * ch,
			};
			let covered = 0;
			for (const r of rects) covered += area(intersect(r, cellRect));
			out.push(math.clamp(covered / math.max(1, cw * ch), 0, 1));
		}
	}
	return out;
}

// ---------------------------------------------------------------------------------------------
// Columns

export interface ColumnBalance {
	/** tallest / shortest content height */
	ratio: number;
	cv: number;
	/** px of dead space under the shorter columns, summed */
	deadSpace: number;
	/** 0 = even .. 1 = everything in one column */
	imbalance: number;
}

export function columnBalance(heights: ReadonlyArray<number>): ColumnBalance {
	if (heights.size() < 2) return { ratio: 1, cv: 0, deadSpace: 0, imbalance: 0 };
	let tallest = 0;
	let shortest = math.huge;
	for (const h of heights) {
		tallest = math.max(tallest, h);
		shortest = math.min(shortest, h);
	}
	let dead = 0;
	for (const h of heights) dead += tallest - h;
	const n = heights.size();
	return {
		ratio: shortest > 0 ? tallest / shortest : math.huge,
		cv: cv(heights),
		deadSpace: dead,
		imbalance: tallest > 0 ? dead / (tallest * (n - 1)) : 0,
	};
}

// ---------------------------------------------------------------------------------------------
// Orders

/** Number of discordant pairs between `order` and the identity (O(n log n) via merge sort). */
export function inversions(order: ReadonlyArray<number>): number {
	const a = [...order];
	const tmp: number[] = [];
	for (let i = 0; i < a.size(); i++) tmp.push(0);
	const sortCount = (lo: number, hi: number): number => {
		if (hi - lo < 2) return 0;
		const mid = (lo + hi) >>> 1;
		let count = sortCount(lo, mid) + sortCount(mid, hi);
		let i = lo;
		let j = mid;
		let k = lo;
		while (i < mid && j < hi) {
			if (a[i] <= a[j]) {
				tmp[k] = a[i];
				i += 1;
			} else {
				tmp[k] = a[j];
				j += 1;
				count += mid - i;
			}
			k += 1;
		}
		while (i < mid) {
			tmp[k] = a[i];
			i += 1;
			k += 1;
		}
		while (j < hi) {
			tmp[k] = a[j];
			j += 1;
			k += 1;
		}
		for (let x = lo; x < hi; x++) a[x] = tmp[x];
		return count;
	};
	return sortCount(0, a.size());
}

/** Kendall tau distance normalised to [0, 1] (0 = same order, 1 = reversed). */
export function kendallDistance(order: ReadonlyArray<number>): number {
	const n = order.size();
	if (n < 2) return 0;
	return inversions(order) / ((n * (n - 1)) / 2);
}

/** Longest increasing subsequence length (patience sorting) — elements "in order" relative to it. */
export function lisLength(values: ReadonlyArray<number>): number {
	const tails: number[] = [];
	for (const v of values) {
		let lo = 0;
		let hi = tails.size();
		while (lo < hi) {
			const mid = (lo + hi) >>> 1;
			if (tails[mid] < v) lo = mid + 1;
			else hi = mid;
		}
		if (lo === tails.size()) tails.push(v);
		else tails[lo] = v;
	}
	return tails.size();
}

/** Exponential moving average helper for learning per-signature defect rates. */
export function ema(previous: number, sample: number, alpha: number): number {
	return previous + (sample - previous) * alpha;
}
