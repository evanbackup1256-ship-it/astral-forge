// Pure heatmap maths for the overlay: accumulates finding severity into a coarse screen grid
// with a separable box blur, then maps cells to a 0..1 intensity (log-scaled so one critical
// spot does not wash out the rest).
import * as G from "./geom";

export interface Heat {
	cols: number;
	rows: number;
	cell: number;
	values: number[];
	max: number;
}

export function heatmap(width: number, height: number, spots: ReadonlyArray<{ rect: G.Rect; weight: number }>, cell = 48, blur = 1): Heat {
	const cols = math.max(1, math.ceil(width / cell));
	const rows = math.max(1, math.ceil(height / cell));
	let values: number[] = [];
	for (let i = 0; i < cols * rows; i++) values.push(0);
	for (const s of spots) {
		const c0 = math.clamp(math.floor(s.rect.x0 / cell), 0, cols - 1);
		const c1 = math.clamp(math.floor((s.rect.x1 - 1e-6) / cell), 0, cols - 1);
		const r0 = math.clamp(math.floor(s.rect.y0 / cell), 0, rows - 1);
		const r1 = math.clamp(math.floor((s.rect.y1 - 1e-6) / cell), 0, rows - 1);
		for (let r = r0; r <= r1; r++) {
			for (let c = c0; c <= c1; c++) {
				// weight by the share of the cell the spot covers
				const cellRect = G.fromPosSize(c * cell, r * cell, cell, cell);
				values[r * cols + c] += (s.weight * G.intersectionArea(cellRect, s.rect)) / (cell * cell);
			}
		}
	}
	for (let pass = 0; pass < blur; pass++) values = boxBlur(values, cols, rows);
	let max = 0;
	for (const v of values) max = math.max(max, v);
	return { cols, rows, cell, values, max };
}

/** 3x3 box blur, separable (horizontal then vertical), edges clamped. */
export function boxBlur(values: ReadonlyArray<number>, cols: number, rows: number): number[] {
	const tmp: number[] = [];
	for (let r = 0; r < rows; r++) {
		for (let c = 0; c < cols; c++) {
			const a = values[r * cols + math.max(0, c - 1)];
			const b = values[r * cols + c];
			const d = values[r * cols + math.min(cols - 1, c + 1)];
			tmp.push((a + b + d) / 3);
		}
	}
	const out: number[] = [];
	for (let r = 0; r < rows; r++) {
		for (let c = 0; c < cols; c++) {
			const a = tmp[math.max(0, r - 1) * cols + c];
			const b = tmp[r * cols + c];
			const d = tmp[math.min(rows - 1, r + 1) * cols + c];
			out.push((a + b + d) / 3);
		}
	}
	return out;
}

export function intensity(h: Heat, index: number): number {
	if (h.max <= 0) return 0;
	return math.log(1 + h.values[index]) / math.log(1 + h.max);
}

/** Cold-to-hot ramp (blue -> yellow -> red) as 0..1 RGB. */
export function ramp(t: number): [number, number, number] {
	const x = math.clamp(t, 0, 1);
	if (x < 0.5) return [x * 2, x * 2, 1 - x * 2];
	return [1, 2 - x * 2, 0];
}
