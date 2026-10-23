// Adaptive fit optimiser: pure, deterministic search over small bounded layout adjustments.
//
// Input is a measured FitContainer (a page host's real content against its visible window) and
// the player's context (input kind). Output is the best FitKnobs, scored by how much of the
// content is visible per screen minus penalties. Only layout values move: spacing, grid columns,
// cell heights and opted-in side-by-side pairs. Text is never resized, so the 11px floor holds by
// construction; touch keeps every tappable cell at 44px or more.
//
// Adjustments in priority order (greedy, fixed enumeration order, so the same input always gives
// the same decision):
//   1. collapse spacing toward the spacing-token ladder (list gap, then vertical padding)
//   2. add grid columns while cells stay at or above their minimum width
//   3. trim cell heights within [min, base] and only by measured slack
//   4. put an opted-in pair of short sections side by side on wide containers
// A container whose content already fits gets the base knobs: nothing changes on pages that
// don't scroll.

export type InputKind = "mouse" | "touch" | "gamepad";

/** spacing tokens a gap or padding may collapse onto (px) */
export const SPACING_TOKENS: ReadonlyArray<number> = [16, 14, 12, 10, 8, 6, 4];
export const MIN_TAP = 44;
/** cell height multipliers tried in stage 3 */
export const HEIGHT_STEPS: ReadonlyArray<number> = [1, 0.95, 0.9, 0.85];
export const MAX_EXTRA_COLUMNS = 2;

export interface FitGrid {
	/** container inner width the grid lays out in */
	width: number;
	cellW: number;
	cellH: number;
	padX: number;
	padY: number;
	count: number;
	/** smallest cell width the content still fits at (defaults to 85% of cellW) */
	minCellW: number;
	/** smallest cell height allowed by the design */
	minCellH: number;
	/** px of empty space at the bottom of the tightest cell: the most a height trim may remove */
	slackH: number;
	/** cells are buttons (touch keeps them >= 44px) */
	tappable: boolean;
}

export interface FitPair {
	leftH: number;
	rightH: number;
	/** each side needs at least this width */
	minW: number;
	gap: number;
}

export interface FitContainer {
	id: string;
	/** visible window height */
	windowH: number;
	/** inner width */
	width: number;
	/** content height at the base knobs */
	contentH: number;
	gap: number;
	gapCount: number;
	minGap: number;
	pad: number;
	padCount: number;
	minPad: number;
	grids: FitGrid[];
	pairs: FitPair[];
}

export interface FitKnobs {
	gap: number;
	pad: number;
	extraCols: number[];
	heightStep: number[];
	pairs: boolean[];
}

export interface Evaluation {
	valid: boolean;
	contentH: number;
	score: number;
	reason?: string;
}

export function baseKnobs(c: FitContainer): FitKnobs {
	return {
		gap: c.gap,
		pad: c.pad,
		extraCols: c.grids.map(() => 0),
		heightStep: c.grids.map(() => 0),
		pairs: c.pairs.map(() => false),
	};
}

export function knobsKey(k: FitKnobs): string {
	return `g${k.gap}p${k.pad}c${k.extraCols.join(",")}h${k.heightStep.join(",")}m${k.pairs.map((b) => (b ? 1 : 0)).join(",")}`;
}

export function sameKnobs(a: FitKnobs, b: FitKnobs): boolean {
	return knobsKey(a) === knobsKey(b);
}

export function cloneKnobs(k: FitKnobs): FitKnobs {
	return { gap: k.gap, pad: k.pad, extraCols: [...k.extraCols], heightStep: [...k.heightStep], pairs: [...k.pairs] };
}

export function baseColumns(g: FitGrid): number {
	if (g.cellW <= 0) return 1;
	return math.max(1, math.floor((g.width + g.padX) / (g.cellW + g.padX)));
}

export function rowsFor(count: number, cols: number): number {
	if (count <= 0) return 0;
	return math.ceil(count / math.max(1, cols));
}

export interface GridLayoutResult {
	cols: number;
	cellW: number;
	cellH: number;
	rows: number;
	height: number;
	valid: boolean;
	reason?: string;
}

export function gridLayout(g: FitGrid, extra: number, step: number, input: InputKind): GridLayoutResult {
	const base = baseColumns(g);
	const cols = base + extra;
	const cellW = extra === 0 ? g.cellW : math.floor((g.width - g.padX * (cols - 1)) / cols);
	const scale = HEIGHT_STEPS[step] ?? 1;
	const cellH = step === 0 ? g.cellH : math.floor(g.cellH * scale + 0.5);
	const rows = rowsFor(g.count, cols);
	const height = rows > 0 ? rows * cellH + (rows - 1) * g.padY : 0;
	let valid = true;
	let reason: string | undefined;
	if (cellW < g.minCellW) {
		valid = false;
		reason = "cell narrower than its minimum";
	} else if (cellW > g.cellW) {
		valid = false;
		reason = "cells only shrink";
	} else if (cellH < g.minCellH) {
		valid = false;
		reason = "cell shorter than its minimum";
	} else if (g.cellH - cellH > g.slackH) {
		valid = false;
		reason = "trim exceeds measured slack (would clip)";
	} else if (g.tappable && input === "touch" && (cellH < MIN_TAP || cellW < MIN_TAP)) {
		valid = false;
		reason = "tap target under 44px";
	} else if (extra > 0 && rowsFor(g.count, cols) === rowsFor(g.count, base)) {
		valid = false;
		reason = "extra column saves no row";
	}
	return { cols, cellW, cellH, rows, height, valid, reason };
}

/** the spacing values tried for a base value: the base itself, then each smaller token >= floor */
export function spacingLadder(base: number, floor: number): number[] {
	const out = [base];
	for (const t of SPACING_TOKENS) {
		if (t < base && t >= floor) out.push(t);
	}
	return out;
}

const CHANGE_COST = 0.002;
const GAMEPAD_ORDER_PENALTY = 0.05;

function changeMagnitude(c: FitContainer, k: FitKnobs): number {
	let m = 0;
	if (k.gap !== c.gap) m += 1;
	if (k.pad !== c.pad) m += 1;
	for (const e of k.extraCols) m += e;
	for (const s of k.heightStep) m += s;
	for (const p of k.pairs) if (p) m += 2;
	return m;
}

export function evaluate(c: FitContainer, k: FitKnobs, input: InputKind): Evaluation {
	if (k.gap < c.minGap || k.gap > c.gap) return { valid: false, contentH: c.contentH, score: -math.huge, reason: "gap outside [min, base]" };
	if (k.pad < c.minPad || k.pad > c.pad) return { valid: false, contentH: c.contentH, score: -math.huge, reason: "padding outside [min, base]" };
	let h = c.contentH - (c.gap - k.gap) * c.gapCount - (c.pad - k.pad) * c.padCount;
	let penalty = 0;
	for (let i = 0; i < c.grids.size(); i++) {
		const g = c.grids[i];
		const extra = k.extraCols[i] ?? 0;
		const step = k.heightStep[i] ?? 0;
		if (extra === 0 && step === 0) continue;
		const before = gridLayout(g, 0, 0, input);
		const after = gridLayout(g, extra, step, input);
		if (!after.valid) return { valid: false, contentH: h, score: -math.huge, reason: after.reason };
		h -= before.height - after.height;
		// gamepad players move through grids by order; reflowing columns moves their targets
		if (extra > 0 && input === "gamepad") penalty += GAMEPAD_ORDER_PENALTY;
	}
	for (let i = 0; i < c.pairs.size(); i++) {
		if (!k.pairs[i]) continue;
		const p = c.pairs[i];
		if (c.width < p.minW * 2 + p.gap) return { valid: false, contentH: h, score: -math.huge, reason: "pair too narrow to sit side by side" };
		if (math.max(p.leftH, p.rightH) > c.windowH * 0.6) return { valid: false, contentH: h, score: -math.huge, reason: "pair too tall to share a row" };
		h -= math.min(p.leftH, p.rightH) + p.gap;
	}
	h = math.max(0, h);
	const visible = h <= 0 ? 1 : math.min(1, c.windowH / h);
	const score = visible - penalty - CHANGE_COST * changeMagnitude(c, k);
	return { valid: true, contentH: h, score };
}

export interface Decision {
	knobs: FitKnobs;
	evaluation: Evaluation;
	/** candidates evaluated (for budget tests) */
	evaluated: number;
}

const EPS = 1e-6;

/**
 * Greedy search in priority order. `banned` holds knob keys a verifier rejected; they are skipped.
 * Deterministic: options are tried in a fixed order and ties keep the earlier (smaller) change.
 */
export function optimise(c: FitContainer, input: InputKind, banned?: ReadonlySet<string>): Decision {
	let best = baseKnobs(c);
	let bestEval = evaluate(c, best, input);
	let evaluated = 1;
	if (c.contentH <= c.windowH) return { knobs: best, evaluation: bestEval, evaluated };
	const consider = (k: FitKnobs) => {
		evaluated += 1;
		if (banned !== undefined && banned.has(knobsKey(k))) return;
		const e = evaluate(c, k, input);
		if (e.valid && e.score > bestEval.score + EPS) {
			best = k;
			bestEval = e;
		}
	};
	const fits = () => bestEval.contentH <= c.windowH;
	// 1. spacing
	for (const g of spacingLadder(c.gap, c.minGap)) {
		const k = cloneKnobs(best);
		k.gap = g;
		consider(k);
	}
	if (!fits()) {
		for (const p of spacingLadder(c.pad, c.minPad)) {
			const k = cloneKnobs(best);
			k.pad = p;
			consider(k);
		}
	}
	// 2. grid columns
	for (let i = 0; i < c.grids.size() && !fits(); i++) {
		const start = best;
		for (let extra = 1; extra <= MAX_EXTRA_COLUMNS; extra++) {
			const k = cloneKnobs(start);
			k.extraCols[i] = extra;
			consider(k);
		}
	}
	// 3. cell heights
	for (let i = 0; i < c.grids.size() && !fits(); i++) {
		const start = best;
		for (let step = 1; step < HEIGHT_STEPS.size(); step++) {
			const k = cloneKnobs(start);
			k.heightStep[i] = step;
			consider(k);
		}
	}
	// 4. side-by-side pairs
	for (let i = 0; i < c.pairs.size() && !fits(); i++) {
		const k = cloneKnobs(best);
		k.pairs[i] = true;
		consider(k);
	}
	return { knobs: best, evaluation: bestEval, evaluated };
}

/** px the knobs remove from the content height (independent of the content height itself) */
export function savedBy(c: FitContainer, k: FitKnobs, input: InputKind): number {
	const big = 1e7;
	const probe: FitContainer = { ...c, contentH: big, windowH: c.windowH };
	const e = evaluate(probe, k, input);
	return e.valid ? big - e.contentH : 0;
}
