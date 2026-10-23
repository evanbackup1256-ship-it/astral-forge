// Layout engine: pure sizing maths shared by every page, plus an opt-in whitespace debug overlay.
// It has no colours, motion or sounds of its own, so pages keep their look and animation timing.
//
//  - Space / spacingFor: spacing tokens, scaled to the space actually available.
//  - breakpointFor: breakpoints by available width (the container, not the device).
//  - fitColumns: column count from content (item count, min/max cell width), with an even last row.
//  - resolveTrack: constraint + priority sizing on one axis; on overflow the lowest priority drops first.
//  - packMasonry: shortest-column packing for uneven cards.
//  - balanceColumns: evens out two stacked columns by moving tail blocks across.
//  - measureText: cached text measurement so render code never calls TextService per frame.
//  - whitespaceReport / attachWhitespaceDebug: set Workspace attribute `LayoutDebug` = true to see
//    empty bands outlined in red over every SplitColumns container, with an "N% empty" tag.

const TextService = game.GetService("TextService");
const Workspace = game.GetService("Workspace");

export const Space = { xxs: 2, xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 48 } as const;
export type SpaceToken = keyof typeof Space;

export type Breakpoint = "xs" | "sm" | "md" | "lg" | "xl";
export function breakpointFor(available: number): Breakpoint {
	if (available < 480) return "xs";
	if (available < 720) return "sm";
	if (available < 1024) return "md";
	if (available < 1440) return "lg";
	return "xl";
}
const GAP_BY_BREAKPOINT: Record<Breakpoint, number> = { xs: 8, sm: 10, md: 12, lg: 14, xl: 16 };
/** gap that tightens on narrow containers and opens up on wide ones */
export function spacingFor(available: number): number {
	return GAP_BY_BREAKPOINT[breakpointFor(available)];
}

export interface ColumnFit {
	columns: number;
	cell: number;
	gap: number;
	rows: number;
}
/** Content-aware columns: never more columns than items, and cells stretch to fill the width. */
export function fitColumns(width: number, count: number, minCell: number, maxColumns = 6, gap = 10, maxCell?: number): ColumnFit {
	const usable = math.max(0, math.floor(width));
	const items = math.max(1, count);
	const cap = math.max(1, math.min(maxColumns, items));
	let columns = math.clamp(math.floor((usable + gap) / (minCell + gap)), 1, cap);
	if (maxCell !== undefined) {
		while (columns < cap && (usable - gap * (columns - 1)) / columns > maxCell) {
			columns += 1;
		}
	}
	// even the last row: 5 items in 4 columns -> 3 + 2 when cells stay >= minCell
	const rows = math.ceil(items / columns);
	const evened = math.ceil(items / rows);
	if (evened < columns && (usable - gap * (evened - 1)) / evened >= minCell) {
		columns = evened;
	}
	const cell = math.max(1, math.floor((usable - gap * (columns - 1)) / columns));
	return { columns, cell, gap, rows: math.ceil(items / columns) };
}

export interface TrackItem {
	id: string;
	min: number;
	pref?: number;
	max?: number;
	grow?: number;
	/** higher survives longer when space runs out */
	priority?: number;
}
export interface TrackResult {
	sizes: Record<string, number>;
	offsets: Record<string, number>;
	hidden: Record<string, boolean>;
	used: number;
	overflow: boolean;
}
/** Constraint + priority sizing: every item gets min, then pref, then grows into the slack up to max.
 *  If even the mins don't fit, the lowest-priority items drop until they do (graceful degrade). */
export function resolveTrack(items: TrackItem[], available: number, gap = 10): TrackResult {
	const live = [...items];
	const hidden: Record<string, boolean> = {};
	const minTotal = () => {
		let total = 0;
		for (const item of live) total += item.min;
		return total + gap * math.max(0, live.size() - 1);
	};
	while (live.size() > 1 && minTotal() > available) {
		let worst = 0;
		for (let i = 1; i < live.size(); i++) {
			if ((live[i].priority ?? 0) <= (live[worst].priority ?? 0)) worst = i;
		}
		hidden[live[worst].id] = true;
		live.remove(worst);
	}
	const sizes: Record<string, number> = {};
	let used = gap * math.max(0, live.size() - 1);
	for (const item of live) {
		sizes[item.id] = item.min;
		used += item.min;
	}
	for (const item of live) {
		const take = math.min(math.max(0, (item.pref ?? item.min) - item.min), math.max(0, available - used));
		sizes[item.id] += take;
		used += take;
	}
	for (let pass = 0; pass < 4 && used < available - 0.5; pass++) {
		let weight = 0;
		for (const item of live) {
			if ((item.grow ?? 0) > 0 && sizes[item.id] < (item.max ?? math.huge)) weight += item.grow ?? 0;
		}
		if (weight <= 0) break;
		const slack = available - used;
		for (const item of live) {
			const g = item.grow ?? 0;
			if (g <= 0) continue;
			const add = math.min((item.max ?? math.huge) - sizes[item.id], (slack * g) / weight);
			sizes[item.id] += add;
			used += add;
		}
	}
	const offsets: Record<string, number> = {};
	let at = 0;
	for (const item of live) {
		sizes[item.id] = math.floor(sizes[item.id]);
		offsets[item.id] = at;
		at += sizes[item.id] + gap;
	}
	return { sizes, offsets, hidden, used: math.floor(used), overflow: minTotal() > available };
}

export interface PackedCell {
	column: number;
	x: number;
	y: number;
}
/** Masonry: each card goes to the currently shortest column. */
export function packMasonry(heights: number[], columns: number, cellWidth: number, gap = 10): { cells: PackedCell[]; height: number } {
	const cols = math.max(1, columns);
	const tops: number[] = [];
	for (let i = 0; i < cols; i++) tops.push(0);
	const cells: PackedCell[] = [];
	for (const h of heights) {
		let best = 0;
		for (let c = 1; c < cols; c++) {
			if (tops[c] < tops[best] - 1) best = c;
		}
		cells.push({ column: best, x: best * (cellWidth + gap), y: tops[best] });
		tops[best] += h + gap;
	}
	let height = 0;
	for (const t of tops) height = math.max(height, t - gap);
	return { cells, height: math.max(0, height) };
}

export interface Sized {
	id: string;
	height: number;
}
function columnHeight(blocks: Sized[], gap: number): number {
	let total = 0;
	for (const [i, b] of ipairs(blocks)) total += b.height + (i > 1 ? gap : 0);
	return total;
}
/** Moves tail blocks from the taller column to the end of the shorter one while that lowers the
 *  taller height. The first `keep` blocks of a column always stay put. Columns already within
 *  `tolerance` (a fraction of the taller one) are left alone. */
export function balanceColumns<T extends Sized>(side: T[], main: T[], gap = 10, tolerance = 0.18, keep = 1): [T[], T[]] {
	const a = [...side];
	const b = [...main];
	for (let guard = 0; guard < 12; guard++) {
		const ha = columnHeight(a, gap);
		const hb = columnHeight(b, gap);
		const tall = ha >= hb ? a : b;
		const short = ha >= hb ? b : a;
		const tallH = math.max(ha, hb);
		const shortH = math.min(ha, hb);
		if (tallH <= 0 || (tallH - shortH) / tallH <= tolerance || tall.size() <= keep) break;
		const moving = tall[tall.size() - 1];
		const nextTall = tallH - moving.height - gap;
		const nextShort = shortH + (short.size() > 0 ? gap : 0) + moving.height;
		if (math.max(nextTall, nextShort) >= tallH) break;
		tall.pop();
		short.push(moving);
	}
	return [a, b];
}

const textCache = new Map<string, Vector2>();
let textCacheSize = 0;
/** Cached TextService measurement. */
export function measureText(text: string, size: number, font: Enum.Font = Enum.Font.BuilderSansBold, width = 10000): Vector2 {
	const key = `${size}|${font.Name}|${width}|${text}`;
	const hit = textCache.get(key);
	if (hit !== undefined) return hit;
	let result = new Vector2(text.size() * size * 0.5, size);
	pcall(() => {
		result = TextService.GetTextSize(text, size, font, new Vector2(width, 10000));
	});
	if (textCacheSize > 2000) {
		textCache.clear();
		textCacheSize = 0;
	}
	textCache.set(key, result);
	textCacheSize += 1;
	return result;
}

export interface WhitespaceBand {
	top: number;
	bottom: number;
}
/** Horizontal bands (container pixels) with no visible content, plus the empty fraction. */
export function whitespaceReport(container: GuiObject, minBand = 24): { ratio: number; bands: WhitespaceBand[] } {
	const origin = container.AbsolutePosition;
	const size = container.AbsoluteSize;
	if (size.X <= 0 || size.Y <= 0) return { ratio: 0, bands: [] };
	const rows = math.min(200, math.ceil(size.Y / 4));
	const step = size.Y / rows;
	const covered: boolean[] = [];
	for (let i = 0; i < rows; i++) covered.push(false);
	for (const child of container.GetDescendants()) {
		if (!child.IsA("GuiObject") || !child.Visible) continue;
		if (child.Name === "WhitespaceDebug" || child.IsDescendantOf(container.FindFirstChild("WhitespaceDebug") ?? Workspace)) continue;
		const drawn =
			child.IsA("TextLabel") || child.IsA("TextButton") || child.IsA("ImageLabel") || child.IsA("ImageButton")
				? true
				: child.BackgroundTransparency < 0.98;
		if (!drawn) continue;
		const top = child.AbsolutePosition.Y - origin.Y;
		const bottom = top + child.AbsoluteSize.Y;
		for (let i = math.max(0, math.floor(top / step)); i < math.min(rows, math.ceil(bottom / step)); i++) covered[i] = true;
	}
	const bands: WhitespaceBand[] = [];
	let empty = 0;
	let start = -1;
	for (let i = 0; i <= rows; i++) {
		const free = i < rows && !covered[i];
		if (free) {
			empty += 1;
			if (start < 0) start = i;
		} else if (start >= 0) {
			if ((i - start) * step >= minBand) bands.push({ top: start * step, bottom: i * step });
			start = -1;
		}
	}
	return { ratio: empty / rows, bands };
}

export function layoutDebugEnabled(): boolean {
	return Workspace.GetAttribute("LayoutDebug") === true;
}
// Containers registered through attachWhitespaceDebug, read by LayoutGuard so its whitespace
// rules analyse exactly these panels (and label findings with the same names).
const registeredWhitespace = new Map<GuiObject, string>();
export function whitespaceContainers(): ReadonlyMap<GuiObject, string> {
	return registeredWhitespace;
}

/** Outlines empty bands in red while Workspace.LayoutDebug is true. Returns a cleanup. */
export function attachWhitespaceDebug(container: GuiObject, label: string): () => void {
	registeredWhitespace.set(container, label);
	let overlay: Frame | undefined;
	const draw = () => {
		overlay?.Destroy();
		overlay = undefined;
		if (!layoutDebugEnabled() || container.Parent === undefined) return;
		const report = whitespaceReport(container);
		const root = new Instance("Frame");
		root.Name = "WhitespaceDebug";
		root.BackgroundTransparency = 1;
		root.Size = UDim2.fromScale(1, 1);
		root.ZIndex = 1000;
		for (const band of report.bands) {
			const f = new Instance("Frame");
			f.BackgroundColor3 = Color3.fromRGB(255, 40, 60);
			f.BackgroundTransparency = 0.8;
			f.BorderSizePixel = 0;
			f.Position = UDim2.fromOffset(0, band.top);
			f.Size = new UDim2(1, 0, 0, band.bottom - band.top);
			f.ZIndex = 1000;
			f.Parent = root;
		}
		const tag = new Instance("TextLabel");
		tag.BackgroundTransparency = 0.3;
		tag.BackgroundColor3 = new Color3(0, 0, 0);
		tag.TextColor3 = new Color3(1, 1, 1);
		tag.TextSize = 12;
		tag.Size = UDim2.fromOffset(240, 16);
		tag.Text = `${label}: ${math.floor(report.ratio * 100)}% empty`;
		tag.ZIndex = 1001;
		tag.Parent = root;
		root.Parent = container;
		overlay = root;
		if (report.ratio > 0.18) {
			warn(`[LayoutDebug] ${label} is ${math.floor(report.ratio * 100)}% empty`);
		}
	};
	const connections = [
		Workspace.GetAttributeChangedSignal("LayoutDebug").Connect(() => task.defer(draw)),
		container.GetPropertyChangedSignal("AbsoluteSize").Connect(() => {
			if (layoutDebugEnabled()) task.delay(0.6, draw);
		}),
	];
	if (layoutDebugEnabled()) task.delay(0.8, draw);
	return () => {
		for (const c of connections) c.Disconnect();
		overlay?.Destroy();
		if (registeredWhitespace.get(container) === label) registeredWhitespace.delete(container);
	};
}

// ---------------------------------------------------------------------------------------------
// Page composition (bento). A page is described by roles, not by a column list:
//   hero      full-width focal band at the top (the one thing the page is about)
//   primary   the main working zone (wide column)
//   secondary the supporting rail beside it (narrow column, either side)
//   tiles     small summary/stat cards packed into an even grid band below
//   footer    full-width closing band (long lists, logs)
// planComposition turns that into absolute rectangles for one width, so every zone has exact,
// testable geometry: aligned outer edges, one gutter everywhere, the shorter split column's last
// block stretched to the row height, every tile row stretched to its tallest tile (no dead bands).
// ---------------------------------------------------------------------------------------------
export interface ComposeSpec {
	hero?: number[];
	primary: number[];
	secondary?: number[];
	tiles?: number[];
	footer?: number[];
	/** secondary rail share of the width, clamped to [secondaryMin, secondaryMax] */
	secondaryRatio?: number;
	secondaryMin?: number;
	secondaryMax?: number;
	secondaryOnRight?: boolean;
	/** below this width the split row stacks (primary first, then secondary) */
	splitMin?: number;
	/** tiles: minimum and maximum cell width, max columns */
	tileMin?: number;
	tileMax?: number;
	tileColumns?: number;
	/** tiles sit inside the primary column (beside the rail) instead of a full-width band */
	tilesInPrimary?: boolean;
}
export interface ZoneRect {
	role: "hero" | "primary" | "secondary" | "tiles" | "footer";
	index: number;
	x: number;
	y: number;
	w: number;
	h: number;
}
export interface Composition {
	width: number;
	height: number;
	split: boolean;
	rects: ZoneRect[];
	tileColumns: number;
}

function stackRects(role: ZoneRect["role"], heights: number[], x: number, y: number, w: number, gap: number, out: ZoneRect[], fillTo?: number): number {
	let cursor = y;
	for (let i = 0; i < heights.size(); i++) {
		const rect: ZoneRect = { role, index: i, x, y: cursor, w, h: math.max(0, heights[i]) };
		out.push(rect);
		cursor += rect.h + (i < heights.size() - 1 ? gap : 0);
	}
	if (fillTo !== undefined && out.size() > 0 && heights.size() > 0 && cursor < fillTo) {
		const last = out[out.size() - 1];
		last.h += fillTo - cursor;
		cursor = fillTo;
	}
	return cursor;
}

function tileRects(heights: number[], x: number, y: number, w: number, gap: number, spec: ComposeSpec, out: ZoneRect[]): [number, number] {
	const count = heights.size();
	if (count === 0) return [y, 0];
	const fit = fitColumns(w, count, spec.tileMin ?? 260, spec.tileColumns ?? 4, gap);
	const cols = math.max(1, fit.columns);
	const rows = math.ceil(count / cols);
	let cursor = y;
	for (let r = 0; r < rows; r++) {
		let rowH = 0;
		for (let c = 0; c < cols; c++) {
			const i = r * cols + c;
			if (i < count) rowH = math.max(rowH, heights[i]);
		}
		// the last row spreads its cells across the full width so no empty cell is left at the end
		const inRow = math.min(cols, count - r * cols);
		const cellW = (w - gap * (inRow - 1)) / inRow;
		for (let c = 0; c < inRow; c++) {
			const i = r * cols + c;
			// integer edges: each cell ends exactly one gutter before the next, the last ends flush right
			const left = math.floor(x + c * (cellW + gap));
			const right = c === inRow - 1 ? x + w : math.floor(x + (c + 1) * (cellW + gap)) - gap;
			out.push({ role: "tiles", index: i, x: left, y: cursor, w: right - left, h: rowH });
		}
		cursor += rowH + (r < rows - 1 ? gap : 0);
	}
	return [cursor, cols];
}

export function planComposition(width: number, gap: number, spec: ComposeSpec): Composition {
	const w = math.max(0, math.floor(width));
	const rects: ZoneRect[] = [];
	const hero = spec.hero ?? [];
	const secondary = spec.secondary ?? [];
	const tiles = spec.tiles ?? [];
	const footer = spec.footer ?? [];
	const split = secondary.size() > 0 && spec.primary.size() > 0 && w >= (spec.splitMin ?? 980);
	let y = 0;
	const band = (bottom: number) => (bottom > 0 ? bottom + gap : 0);
	if (hero.size() > 0) y = band(stackRects("hero", hero, 0, 0, w, gap, rects));
	let tileCols = 0;
	if (split) {
		const sideW = math.floor(math.clamp(w * (spec.secondaryRatio ?? 0.32), spec.secondaryMin ?? 300, math.min(spec.secondaryMax ?? 520, w * 0.5)));
		const mainW = w - sideW - gap;
		const right = spec.secondaryOnRight !== false;
		const mainX = right ? 0 : sideW + gap;
		const sideX = right ? mainW + gap : 0;
		// measure both columns first, then stretch the shorter one's last block to the taller
		const mainProbe: ZoneRect[] = [];
		let mainEnd = stackRects("primary", spec.primary, mainX, y, mainW, gap, mainProbe);
		const tileProbe: ZoneRect[] = [];
		if (spec.tilesInPrimary === true && tiles.size() > 0) {
			const [endY, cols] = tileRects(tiles, mainX, mainEnd + gap, mainW, gap, spec, tileProbe);
			mainEnd = endY;
			tileCols = cols;
		}
		const sideProbe: ZoneRect[] = [];
		const sideEnd = stackRects("secondary", secondary, sideX, y, sideW, gap, sideProbe);
		const rowEnd = math.max(mainEnd, sideEnd);
		if (sideEnd < rowEnd) sideProbe[sideProbe.size() - 1].h += rowEnd - sideEnd;
		else if (mainEnd < rowEnd) {
			const lastList = tileProbe.size() > 0 ? tileProbe : mainProbe;
			const lastY = lastList[lastList.size() - 1].y;
			for (const rect of lastList) if (rect.y === lastY) rect.h += rowEnd - mainEnd;
		}
		for (const rect of mainProbe) rects.push(rect);
		for (const rect of tileProbe) rects.push(rect);
		for (const rect of sideProbe) rects.push(rect);
		y = rowEnd + gap;
	} else {
		if (spec.primary.size() > 0) y = band(stackRects("primary", spec.primary, 0, y, w, gap, rects));
		if (secondary.size() > 0) y = band(stackRects("secondary", secondary, 0, y, w, gap, rects));
	}
	if (tiles.size() > 0 && !(split && spec.tilesInPrimary === true)) {
		const [endY, cols] = tileRects(tiles, 0, y, w, gap, spec, rects);
		tileCols = cols;
		y = endY + gap;
	}
	if (footer.size() > 0) y = band(stackRects("footer", footer, 0, y, w, gap, rects));
	return { width: w, height: math.max(0, y - gap), split, rects, tileColumns: tileCols };
}
