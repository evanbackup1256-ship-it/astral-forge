// Helpers over a Snapshot: tree walks, folding paths into dedupe shapes, visible rects, text ink
// rects and reading order.
import * as G from "./geom";
import { Rect } from "./geom";
import { clusterByGap } from "./metrics";
import { GNode, Snapshot } from "./types";

export function nodeOf(snap: Snapshot, id: number): GNode | undefined {
	return snap.byId.get(id);
}

export function isAncestor(snap: Snapshot, ancestor: number, id: number): boolean {
	let current = snap.byId.get(id);
	while (current !== undefined && current.parent >= 0) {
		if (current.parent === ancestor) return true;
		current = snap.byId.get(current.parent);
	}
	return false;
}

export function related(snap: Snapshot, a: number, b: number): boolean {
	return a === b || isAncestor(snap, a, b) || isAncestor(snap, b, a);
}

/** Lowest common ancestor id, or -1 when the nodes are in different layers. */
export function commonAncestor(snap: Snapshot, a: number, b: number): number {
	const seen = new Set<number>();
	let current = snap.byId.get(a);
	while (current !== undefined) {
		seen.add(current.id);
		current = current.parent >= 0 ? snap.byId.get(current.parent) : undefined;
	}
	current = snap.byId.get(b);
	while (current !== undefined) {
		if (seen.has(current.id)) return current.id;
		current = current.parent >= 0 ? snap.byId.get(current.parent) : undefined;
	}
	return -1;
}

/**
 * Folds a path into a structural shape so N copies of one component group into one log line:
 * digits become '#', GUIDs/hex ids become '*', and runs like "Slot_12" -> "Slot_#".
 */
export function foldShape(path: string): string {
	let s = path.gsub("%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x", "*")[0];
	s = s.gsub("%d+", "#")[0];
	return s;
}

/** The part of a node the player can actually see: its rect cut by every clipping ancestor. */
export function visibleRect(n: GNode): Rect {
	return G.intersect(n.rect, n.clipRect);
}

export function visibleShare(n: GNode): number {
	const a = G.area(n.rect);
	return a > 0 ? G.area(visibleRect(n)) / a : 0;
}

/** Where the glyphs sit inside a text node, from TextBounds and alignment. */
export function inkRect(n: GNode): Rect {
	const t = n.text;
	if (t === undefined) return n.rect;
	const w = math.min(t.bounds.x, G.width(n.rect));
	const h = math.min(t.bounds.y, G.height(n.rect));
	let x0 = n.rect.x0;
	if (t.xAlign === "Right") x0 = n.rect.x1 - w;
	else if (t.xAlign === "Center") x0 = n.rect.x0 + (G.width(n.rect) - w) / 2;
	let y0 = n.rect.y0;
	if (t.yAlign === "Bottom") y0 = n.rect.y1 - h;
	else if (t.yAlign === "Center") y0 = n.rect.y0 + (G.height(n.rect) - h) / 2;
	return { x0, y0, x1: x0 + w, y1: y0 + h };
}

export function children(snap: Snapshot, n: GNode): GNode[] {
	const out: GNode[] = [];
	for (const id of n.children) {
		const c = snap.byId.get(id);
		if (c !== undefined) out.push(c);
	}
	return out;
}

export function visibleChildren(snap: Snapshot, n: GNode): GNode[] {
	const out: GNode[] = [];
	for (const c of children(snap, n)) {
		if (c.visible && c.valid && !G.isEmpty(c.rect)) out.push(c);
	}
	return out;
}

export function descendants(snap: Snapshot, n: GNode, out: GNode[] = []): GNode[] {
	for (const c of children(snap, n)) {
		out.push(c);
		descendants(snap, c, out);
	}
	return out;
}

/** Drawn leaf-ish content under a container: what a player perceives as "stuff". */
export function contentRects(snap: Snapshot, container: GNode): Rect[] {
	const out: Rect[] = [];
	const walk = (n: GNode) => {
		for (const c of children(snap, n)) {
			if (!c.visible || !c.valid) continue;
			if (c.drawn && c.opacity < 0.98) out.push(G.intersect(c.rect, container.rect));
			walk(c);
		}
	};
	walk(container);
	return out;
}

/**
 * Reading order: cluster rows by vertical centre (tolerance = half the median height), then
 * left-to-right within a row. Returns node ids.
 */
export function readingOrder(nodes: ReadonlyArray<GNode>): number[] {
	if (nodes.size() === 0) return [];
	const heights: number[] = [];
	const centersY: number[] = [];
	for (const n of nodes) {
		heights.push(G.height(n.rect));
		centersY.push((n.rect.y0 + n.rect.y1) / 2);
	}
	heights.sort((a, b) => a < b);
	const tol = math.max(4, heights[math.floor(heights.size() / 2)] / 2);
	const rows = clusterByGap(centersY, tol);
	const out: number[] = [];
	for (const row of rows) {
		const members: GNode[] = [];
		for (const i of row.indices) members.push(nodes[i]);
		members.sort((a, b) => a.rect.x0 < b.rect.x0);
		for (const m of members) out.push(m.id);
	}
	return out;
}

/** True when a node or any ancestor is a floating layer (LayoutFloating). */
export function floatingRoot(n: GNode): number {
	return n.floating;
}

export function shortName(n: GNode): string {
	return n.path;
}
