// Shared bits for rule implementations.
import { Rect, area } from "../geom";
import { isAncestor } from "../snapUtil";
import { Finding, GNode, RuleContext, Snapshot, levelFor, suppressed } from "../types";

export function finding(
	rule: string,
	node: GNode,
	severity: number,
	message: string,
	extra?: { other?: GNode; rect?: Rect; metrics?: Record<string, number>; hint?: string },
): Finding {
	const s = math.clamp(severity, 0, 1);
	const other = extra?.other;
	return {
		rule,
		node: node.id,
		other: other?.id,
		severity: s,
		level: levelFor(s),
		message,
		signature: other !== undefined ? `${rule}|${node.shape}|${other.shape}` : `${rule}|${node.shape}`,
		rect: extra?.rect ?? node.rect,
		metrics: extra?.metrics,
		hint: extra?.hint,
	};
}

/** Nodes a rule may look at: visible, valid geometry, not suppressed for this rule. */
const backdropCache = new WeakMap<Snapshot, GNode[]>();

/**
 * Active modal backdrops: visible interactive click shields covering (nearly) the whole layer
 * (offline rewards, player list, dialogs). Everything painted beneath one is dimmed on purpose
 * while the modal is open, so rules skip it instead of reporting the HUD as overlapped.
 */
function modalBackdrops(snap: Snapshot): GNode[] {
	const cached = backdropCache.get(snap);
	if (cached !== undefined) return cached;
	const layerArea = new Map<number, number>();
	for (const l of snap.layers) layerArea.set(l.id, area(l.rect));
	const out: GNode[] = [];
	for (const n of snap.nodes) {
		if (!n.visible || !n.valid || !n.interactive || n.opacity >= 0.995) continue;
		if (area(n.rect) >= (layerArea.get(n.layer) ?? math.huge) * 0.9) out.push(n);
	}
	backdropCache.set(snap, out);
	return out;
}

export function underModal(snap: Snapshot, n: GNode): boolean {
	for (const b of modalBackdrops(snap)) {
		if (b.id === n.id || isAncestor(snap, n.id, b.id)) continue;
		// the modal's own content is a sibling of (or under) the backdrop's parent and paints above it
		if (b.parent >= 0 && (n.parent === b.parent || isAncestor(snap, b.parent, n.id)) && n.paintOrder > b.paintOrder) continue;
		const below = b.displayOrder !== n.displayOrder ? b.displayOrder > n.displayOrder : b.paintOrder > n.paintOrder;
		if (below) return true;
	}
	return false;
}

export function eligible(snap: Snapshot, rule: string, filter?: (n: GNode) => boolean): GNode[] {
	const out: GNode[] = [];
	for (const n of snap.nodes) {
		if (!n.visible || !n.valid || suppressed(n, rule)) continue;
		if (underModal(snap, n)) continue;
		if (filter !== undefined && !filter(n)) continue;
		out.push(n);
	}
	return out;
}

/** Maps a raw ratio onto 0..1 severity: `at` -> 0, `full` -> 1, smooth in between. */
export function ramp(value: number, at: number, full: number): number {
	if (full === at) return value >= full ? 1 : 0;
	const t = math.clamp((value - at) / (full - at), 0, 1);
	return t * t * (3 - 2 * t);
}

export function px(value: number): string {
	return tostring(math.floor(value + 0.5)) + "px";
}

export function pct(value: number): string {
	return tostring(math.floor(value * 100 + 0.5)) + "%";
}

export function stepEvery(ctx: RuleContext, i: number, every = 32) {
	if (i % every === 0) ctx.step();
}
