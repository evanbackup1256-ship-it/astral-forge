// Pure layout simulator. A VNode tree mirrors the parts of a GuiObject tree that decide geometry
// (UDim2s, anchor, modifiers, the parent's UIListLayout / UIGridLayout, AutomaticSize). `resolve`
// lays the tree out for any viewport, which is how LayoutGuard checks the 11-phone matrix without
// resizing the real screen.
//
// Modelled behaviour (Creator Hub: UIListLayout, UIFlexItem, UIGridLayout, "List and flex layouts"):
//  - List: FillDirection, Horizontal/VerticalAlignment, Padding (UDim against the fill axis),
//    SortOrder LayoutOrder (stable by name) or Name, Wraps, HorizontalFlex/VerticalFlex
//    (Fill, SpaceBetween, SpaceAround, SpaceEvenly), UIFlexItem Grow/Shrink/Fill/Custom ratios,
//    ItemLineAlignment Start/Center/End/Stretch.
//  - Grid: CellSize/CellPadding (UDim2 against the content box), FillDirection,
//    FillDirectionMaxCells, StartCorner, alignment of the whole block.
//  - AutomaticSize X/Y/XY grows an element to its children's extent (+ padding).
//  - Layout-owned children ignore Position; UIAspectRatioConstraint still overrides size.
import * as C from "./constraints";
import { Rect, Vec, fromPosSize, inset } from "./geom";

export type FillDir = "Horizontal" | "Vertical";
export type HAlign = "Left" | "Center" | "Right";
export type VAlign = "Top" | "Center" | "Bottom";
export type Flex = "None" | "Fill" | "SpaceBetween" | "SpaceAround" | "SpaceEvenly";
export type LineAlign = "Automatic" | "Start" | "Center" | "End" | "Stretch";
export type Corner = "TopLeft" | "TopRight" | "BottomLeft" | "BottomRight";
export type AutoSize = "None" | "X" | "Y" | "XY";

export interface ListSpec {
	kind: "list";
	fill: FillDir;
	hAlign: HAlign;
	vAlign: VAlign;
	padding: C.UDimV;
	sortByName: boolean;
	wraps: boolean;
	hFlex: Flex;
	vFlex: Flex;
	lineAlign: LineAlign;
}

export interface GridSpec {
	kind: "grid";
	cellSize: C.UDim2V;
	cellPadding: C.UDim2V;
	fill: FillDir;
	maxCells: number;
	startCorner: Corner;
	hAlign: HAlign;
	vAlign: VAlign;
	sortByName: boolean;
}

export type LayoutSpec = ListSpec | GridSpec;

export interface FlexItemSpec {
	mode: "None" | "Grow" | "Shrink" | "Fill" | "Custom";
	grow: number;
	shrink: number;
	lineAlign: LineAlign;
}

export interface VNode {
	id: number;
	name: string;
	visible: boolean;
	layoutOrder: number;
	element: C.ElementSpec;
	padding?: C.PaddingSpec;
	automaticSize?: AutoSize;
	layout?: LayoutSpec;
	flex?: FlexItemSpec;
	/** text that grows an AutomaticSize label: measured by the injected measurer */
	text?: { text: string; size: number; font: string; wrapped: boolean };
	/** scrolling frames lay children out on a canvas of this size (UDim2 against the window) */
	canvas?: C.UDim2V;
	/** UIScale directly under this node */
	uiScale?: number;
	children: VNode[];
}

export type Measure = (text: string, size: number, font: string, maxWidth: number) => Vec;

export interface Resolved {
	rects: Map<number, Rect>;
	/** content rect (after padding) per node, used by rules that need the padded parent box */
	content: Map<number, Rect>;
	/** per list/grid parent: the content extent its layout produced (AbsoluteContentSize) */
	contentSize: Map<number, Vec>;
}

/** Rough fallback measurer: average glyph width ~0.52em, greedy word wrap. */
export function approxMeasure(text: string, size: number, _font: string, maxWidth: number): Vec {
	const glyph = size * 0.52;
	if (maxWidth <= 0 || maxWidth >= 1e5) {
		return { x: text.size() * glyph, y: size };
	}
	let lines = 1;
	let line = 0;
	let widest = 0;
	for (const [word] of text.gmatch("%S+")) {
		const w = (word as string).size() * glyph;
		const add = line > 0 ? w + glyph : w;
		if (line > 0 && line + add > maxWidth) {
			widest = math.max(widest, line);
			lines += 1;
			line = w;
		} else {
			line += add;
		}
	}
	widest = math.max(widest, line);
	return { x: math.min(widest, maxWidth), y: lines * size };
}

function sortedChildren(node: VNode, byName: boolean): VNode[] {
	const list: VNode[] = [];
	for (const child of node.children) {
		if (child.visible) {
			list.push(child);
		}
	}
	list.sort((a, b) => {
		if (!byName && a.layoutOrder !== b.layoutOrder) {
			return a.layoutOrder < b.layoutOrder;
		}
		if (a.name !== b.name) {
			return a.name < b.name;
		}
		return a.id < b.id;
	});
	return list;
}

function flexRatios(item: FlexItemSpec | undefined, listFlex: Flex): [number, number] {
	if (item !== undefined) {
		if (item.mode === "Grow") return [1, 0];
		if (item.mode === "Shrink") return [0, 1];
		if (item.mode === "Fill") return [1, 1];
		if (item.mode === "Custom") return [math.max(0, item.grow), math.max(0, item.shrink)];
	}
	return listFlex === "Fill" ? [1, 1] : [0, 0];
}

interface LineItem {
	node: VNode;
	main: number;
	cross: number;
	grow: number;
	shrink: number;
}

/**
 * Distributes `free` main-axis space on a flex line. Positive free space grows items by their
 * grow ratio; negative free space shrinks them by shrink ratio weighted by basis size (CSS-like),
 * never below zero. Returns per-item final main sizes.
 */
export function distributeFlex(bases: number[], grow: number[], shrink: number[], free: number): number[] {
	const out = [...bases];
	if (free > 0) {
		let total = 0;
		for (const g of grow) total += g;
		if (total <= 0) return out;
		for (let i = 0; i < out.size(); i++) out[i] += (free * grow[i]) / total;
		return out;
	}
	if (free < 0) {
		// iterative so items clamped at zero hand their share to the rest
		let remaining = -free;
		const frozen: boolean[] = [];
		for (let i = 0; i < out.size(); i++) frozen.push(false);
		for (let pass = 0; pass < 6 && remaining > 1e-6; pass++) {
			let weight = 0;
			for (let i = 0; i < out.size(); i++) if (!frozen[i]) weight += shrink[i] * out[i];
			if (weight <= 0) break;
			let taken = 0;
			for (let i = 0; i < out.size(); i++) {
				if (frozen[i]) continue;
				const cut = (remaining * shrink[i] * out[i]) / weight;
				const reduced = out[i] - cut;
				if (reduced <= 0) {
					taken += out[i];
					out[i] = 0;
					frozen[i] = true;
				} else {
					taken += cut;
					out[i] = reduced;
				}
			}
			remaining -= taken;
		}
	}
	return out;
}

/** Leading offset and between-gap for SpaceBetween/Around/Evenly distributions. */
export function spaceDistribution(flex: Flex, free: number, count: number): [number, number] {
	if (free <= 0 || count <= 0) return [0, 0];
	if (flex === "SpaceBetween") return count > 1 ? [0, free / (count - 1)] : [0, 0];
	if (flex === "SpaceAround") return [free / count / 2, free / count];
	if (flex === "SpaceEvenly") return [free / (count + 1), free / (count + 1)];
	return [0, 0];
}

function alignOffset(free: number, align: "Left" | "Top" | "Center" | "Right" | "Bottom"): number {
	if (align === "Center") return free / 2;
	if (align === "Right" || align === "Bottom") return free;
	return 0;
}

export class Resolver {
	private out: Resolved = { rects: new Map(), content: new Map(), contentSize: new Map() };
	constructor(private measure: Measure = approxMeasure) {}

	run(root: VNode, viewport: Rect): Resolved {
		this.out = { rects: new Map(), content: new Map(), contentSize: new Map() };
		this.place(root, viewport, 1);
		return this.out;
	}

	/** natural size of a node for AutomaticSize / list basis, given its parent content size */
	private naturalSize(node: VNode, pw: number, ph: number, scale: number): Vec {
		const e = node.element;
		let size = C.resolveSize(e.size, pw, ph, e.sizeConstraint ?? "XY");
		const auto = node.automaticSize ?? "None";
		if (auto !== "None") {
			const pad = C.resolvePadding(node.padding, size.x, size.y);
			const ext = this.contentExtent(node, size.x - pad.left - pad.right, size.y - pad.top - pad.bottom, scale);
			if (auto === "X" || auto === "XY") size = { x: math.max(size.x, ext.x + pad.left + pad.right), y: size.y };
			if (auto === "Y" || auto === "XY") size = { x: size.x, y: math.max(size.y, ext.y + pad.top + pad.bottom) };
		}
		size = C.clampSize(size, e.limits);
		size = C.applyAspect(size, e.aspect, pw, ph);
		return { x: size.x * scale, y: size.y * scale };
	}

	/** size needed by a node's children (text, layout content or free children's far edges) */
	private contentExtent(node: VNode, cw: number, ch: number, scale: number): Vec {
		let x = 0;
		let y = 0;
		if (node.text !== undefined && node.text.text !== "") {
			const auto = node.automaticSize ?? "None";
			const limit = node.text.wrapped && auto !== "X" && auto !== "XY" ? cw : 1e6;
			const m = this.measure(node.text.text, node.text.size, node.text.font, limit);
			x = math.max(x, m.x);
			y = math.max(y, m.y);
		}
		const s = scale * (node.uiScale ?? 1);
		const layout = node.layout;
		if (layout !== undefined && layout.kind === "list") {
			const kids = sortedChildren(node, layout.sortByName);
			const gap = C.resolveUDim(layout.padding, layout.fill === "Vertical" ? ch : cw);
			let main = 0;
			let cross = 0;
			for (const [i, kid] of ipairs(kids)) {
				const n = this.naturalSize(kid, cw, ch, s);
				if (layout.fill === "Vertical") {
					main += n.y + (i > 1 ? gap : 0);
					cross = math.max(cross, n.x);
				} else {
					main += n.x + (i > 1 ? gap : 0);
					cross = math.max(cross, n.y);
				}
			}
			if (layout.fill === "Vertical") {
				x = math.max(x, cross);
				y = math.max(y, main);
			} else {
				x = math.max(x, main);
				y = math.max(y, cross);
			}
		} else if (layout !== undefined && layout.kind === "grid") {
			const kids = sortedChildren(node, layout.sortByName);
			const g = this.gridGeometry(layout, cw, ch, kids.size());
			x = math.max(x, g.blockW);
			y = math.max(y, g.blockH);
		} else {
			for (const kid of node.children) {
				if (!kid.visible) continue;
				const n = this.naturalSize(kid, cw, ch, s);
				const p = C.resolvePosition(kid.element.position, cw, ch);
				const tl = C.topLeftFromAnchor(p, kid.element.anchor, n);
				x = math.max(x, tl.x + n.x);
				y = math.max(y, tl.y + n.y);
			}
		}
		return { x, y };
	}

	private gridGeometry(g: GridSpec, cw: number, ch: number, count: number) {
		const cell = C.resolveSize(g.cellSize, cw, ch);
		const pad = { x: g.cellPadding.xs * cw + g.cellPadding.xo, y: g.cellPadding.ys * ch + g.cellPadding.yo };
		const horizontal = g.fill === "Horizontal";
		const along = horizontal ? cw : ch;
		const step = horizontal ? cell.x + pad.x : cell.y + pad.y;
		let perLine = step > 0 ? math.max(1, math.floor((along + (horizontal ? pad.x : pad.y)) / step)) : 1;
		if (g.maxCells > 0) perLine = math.min(perLine, g.maxCells);
		const lines = count > 0 ? math.ceil(count / perLine) : 0;
		const usedAlong = math.min(count, perLine);
		const cols = horizontal ? usedAlong : lines;
		const rows = horizontal ? lines : usedAlong;
		const blockW = cols > 0 ? cols * cell.x + (cols - 1) * pad.x : 0;
		const blockH = rows > 0 ? rows * cell.y + (rows - 1) * pad.y : 0;
		return { cell, pad, perLine, cols, rows, blockW, blockH };
	}

	private place(node: VNode, rect: Rect, scale: number) {
		this.out.rects.set(node.id, rect);
		const w = rect.x1 - rect.x0;
		const h = rect.y1 - rect.y0;
		const s = scale * (node.uiScale ?? 1);
		const pad = C.resolvePadding(node.padding, w, h);
		let content = inset(rect, { left: pad.left * s, top: pad.top * s, right: pad.right * s, bottom: pad.bottom * s });
		if (node.canvas !== undefined) {
			const cw = math.max(content.x1 - content.x0, node.canvas.xs * w + node.canvas.xo);
			const chh = math.max(content.y1 - content.y0, node.canvas.ys * h + node.canvas.yo);
			content = fromPosSize(content.x0, content.y0, cw, chh);
		}
		this.out.content.set(node.id, content);
		const layout = node.layout;
		if (layout !== undefined && layout.kind === "list") {
			this.placeList(node, layout, content, s);
		} else if (layout !== undefined && layout.kind === "grid") {
			this.placeGrid(node, layout, content, s);
		}
		const owned = new Set<number>();
		if (layout !== undefined) {
			for (const kid of node.children) owned.add(kid.id);
		}
		const cw = (content.x1 - content.x0) / s;
		const ch = (content.y1 - content.y0) / s;
		for (const kid of node.children) {
			if (!kid.visible || owned.has(kid.id)) continue;
			const n = this.naturalSize(kid, cw, ch, s);
			const p = C.resolvePosition(kid.element.position, cw, ch);
			const tl = C.topLeftFromAnchor({ x: p.x * s, y: p.y * s }, kid.element.anchor, n);
			this.place(kid, fromPosSize(content.x0 + tl.x, content.y0 + tl.y, n.x, n.y), s);
		}
	}

	private placeList(node: VNode, layout: ListSpec, content: Rect, s: number) {
		const kids = sortedChildren(node, layout.sortByName);
		const cw = (content.x1 - content.x0) / s;
		const ch = (content.y1 - content.y0) / s;
		const vertical = layout.fill === "Vertical";
		const mainLen = vertical ? ch : cw;
		const crossLen = vertical ? cw : ch;
		const gap = C.resolveUDim(layout.padding, mainLen);
		const mainFlex = vertical ? layout.vFlex : layout.hFlex;
		const crossFlex = vertical ? layout.hFlex : layout.vFlex;
		const items: LineItem[] = [];
		for (const kid of kids) {
			const n = this.naturalSize(kid, cw, ch, 1);
			const [g, sh] = flexRatios(kid.flex, mainFlex);
			items.push({ node: kid, main: vertical ? n.y : n.x, cross: vertical ? n.x : n.y, grow: g, shrink: sh });
		}
		// break into lines
		const lines: LineItem[][] = [];
		let current: LineItem[] = [];
		let used = 0;
		for (const item of items) {
			const add = current.size() > 0 ? gap + item.main : item.main;
			if (layout.wraps && current.size() > 0 && used + add > mainLen + 0.5) {
				lines.push(current);
				current = [item];
				used = item.main;
			} else {
				current.push(item);
				used += add;
			}
		}
		if (current.size() > 0) lines.push(current);
		let crossAt = 0;
		let maxMain = 0;
		const lineCross: number[] = [];
		for (const line of lines) {
			let c = 0;
			for (const item of line) c = math.max(c, item.cross);
			lineCross.push(lines.size() === 1 && layout.lineAlign === "Stretch" ? crossLen : c);
		}
		let totalCross = 0;
		for (const [i, c] of ipairs(lineCross)) totalCross += c + (i > 1 ? gap : 0);
		const crossAlign = vertical ? layout.hAlign : layout.vAlign;
		crossAt = alignOffset(crossLen - totalCross, crossAlign);
		for (const [li, line] of ipairs(lines)) {
			const bases: number[] = [];
			const grows: number[] = [];
			const shrinks: number[] = [];
			let basisTotal = gap * (line.size() - 1);
			for (const item of line) {
				bases.push(item.main);
				grows.push(item.grow);
				shrinks.push(layout.wraps ? 0 : item.shrink);
				basisTotal += item.main;
			}
			const free = mainLen - basisTotal;
			const sizes = mainFlex === "Fill" || line.some((i) => i.grow > 0 || i.shrink > 0) ? distributeFlex(bases, grows, shrinks, free) : bases;
			let finalTotal = gap * (line.size() - 1);
			for (const v of sizes) finalTotal += v;
			const leftover = mainLen - finalTotal;
			let [lead, extraGap] = spaceDistribution(mainFlex, leftover, line.size());
			if (mainFlex === "None" || mainFlex === "Fill") {
				lead = alignOffset(leftover, vertical ? layout.vAlign : layout.hAlign);
				extraGap = 0;
			}
			let at = lead;
			const thisCross = lineCross[li - 1];
			for (const [i, item] of ipairs(line)) {
				const itemAlign = item.node.flex?.lineAlign ?? layout.lineAlign;
				let cross = item.cross;
				let crossOff = 0;
				if (itemAlign === "Stretch" || crossFlex === "Fill") {
					cross = thisCross;
				} else if (itemAlign === "Center") {
					crossOff = (thisCross - cross) / 2;
				} else if (itemAlign === "End") {
					crossOff = thisCross - cross;
				} else if (itemAlign === "Automatic" && lines.size() === 1) {
					crossOff = alignOffset(crossLen - cross, crossAlign) - crossAt;
				}
				const main = sizes[i - 1];
				const x = vertical ? crossAt + crossOff : at;
				const y = vertical ? at : crossAt + crossOff;
				const wv = vertical ? cross : main;
				const hv = vertical ? main : cross;
				this.place(item.node, fromPosSize(content.x0 + x * s, content.y0 + y * s, wv * s, hv * s), s);
				at += main + gap + extraGap;
			}
			maxMain = math.max(maxMain, at - gap - extraGap);
			crossAt += thisCross + gap;
		}
		const extentCross = math.max(0, totalCross);
		this.out.contentSize.set(node.id, vertical ? { x: extentCross * s, y: maxMain * s } : { x: maxMain * s, y: extentCross * s });
	}

	private placeGrid(node: VNode, layout: GridSpec, content: Rect, s: number) {
		const kids = sortedChildren(node, layout.sortByName);
		const cw = (content.x1 - content.x0) / s;
		const ch = (content.y1 - content.y0) / s;
		const g = this.gridGeometry(layout, cw, ch, kids.size());
		const ox = alignOffset(cw - g.blockW, layout.hAlign);
		const oy = alignOffset(ch - g.blockH, layout.vAlign);
		const fromRight = layout.startCorner === "TopRight" || layout.startCorner === "BottomRight";
		const fromBottom = layout.startCorner === "BottomLeft" || layout.startCorner === "BottomRight";
		for (const [i, kid] of ipairs(kids)) {
			const index = i - 1;
			let col: number;
			let row: number;
			if (layout.fill === "Horizontal") {
				col = index % g.perLine;
				row = math.floor(index / g.perLine);
			} else {
				row = index % g.perLine;
				col = math.floor(index / g.perLine);
			}
			if (fromRight) col = g.cols - 1 - col;
			if (fromBottom) row = g.rows - 1 - row;
			let size = { x: g.cell.x, y: g.cell.y };
			size = C.applyAspect(size, kid.element.aspect, g.cell.x, g.cell.y);
			size = C.clampSize(size, kid.element.limits);
			const x = ox + col * (g.cell.x + g.pad.x);
			const y = oy + row * (g.cell.y + g.pad.y);
			this.place(kid, fromPosSize(content.x0 + x * s, content.y0 + y * s, size.x * s, size.y * s), s);
		}
		this.out.contentSize.set(node.id, { x: g.blockW * s, y: g.blockH * s });
	}
}

export function resolve(root: VNode, viewport: Rect, measure?: Measure): Resolved {
	return new Resolver(measure).run(root, viewport);
}

/** Convenience constructor for tests and capture. */
export function vnode(id: number, name: string, element: Partial<C.ElementSpec>, children: VNode[] = [], extra?: Partial<VNode>): VNode {
	const node: VNode = {
		id,
		name,
		visible: true,
		layoutOrder: 0,
		element: {
			position: element.position ?? C.fromOffset(0, 0),
			size: element.size ?? C.fromOffset(0, 0),
			anchor: element.anchor ?? { x: 0, y: 0 },
			sizeConstraint: element.sizeConstraint,
			aspect: element.aspect,
			limits: element.limits,
		},
		children,
	};
	return extra !== undefined ? { ...node, ...extra } : node;
}

export function defaultList(partial: Partial<ListSpec> = {}): ListSpec {
	return {
		kind: "list",
		fill: partial.fill ?? "Vertical",
		hAlign: partial.hAlign ?? "Left",
		vAlign: partial.vAlign ?? "Top",
		padding: partial.padding ?? C.udim(0, 0),
		sortByName: partial.sortByName ?? false,
		wraps: partial.wraps ?? false,
		hFlex: partial.hFlex ?? "None",
		vFlex: partial.vFlex ?? "None",
		lineAlign: partial.lineAlign ?? "Automatic",
	};
}

export function defaultGrid(partial: Partial<GridSpec> = {}): GridSpec {
	return {
		kind: "grid",
		cellSize: partial.cellSize ?? C.fromOffset(100, 100),
		cellPadding: partial.cellPadding ?? C.fromOffset(5, 5),
		fill: partial.fill ?? "Horizontal",
		maxCells: partial.maxCells ?? 0,
		startCorner: partial.startCorner ?? "TopLeft",
		hAlign: partial.hAlign ?? "Left",
		vAlign: partial.vAlign ?? "Top",
		sortByName: partial.sortByName ?? false,
	};
}
