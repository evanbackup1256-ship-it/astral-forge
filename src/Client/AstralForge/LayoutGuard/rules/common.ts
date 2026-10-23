// Shared bits for rule implementations.
import { Rect } from "../geom";
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
export function eligible(snap: Snapshot, rule: string, filter?: (n: GNode) => boolean): GNode[] {
	const out: GNode[] = [];
	for (const n of snap.nodes) {
		if (!n.visible || !n.valid || suppressed(n, rule)) continue;
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
