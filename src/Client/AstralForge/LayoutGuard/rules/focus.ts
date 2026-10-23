// Gamepad focus rules. Only run when the viewport reports a gamepad (or under the device matrix).
//
// Engine model (DevForum 1791278, Creator Hub GuiObject.SelectionOrder / NextSelection*):
//   - initial selection = lowest SelectionOrder among selectable on-screen objects; ties go to the
//     top-most, then left-most object;
//   - directional moves pick the nearest candidate in the pressed direction unless the source
//     sets NextSelectionUp/Down/Left/Right.
//
// FocusDeadLink: a NextSelection* property points at something not selectable or not visible
//   (capture stores -2 for those).
// FocusOrder: among objects with explicit SelectionOrder (non-zero), the order disagrees with the
//   reading order (rows top to bottom, then left to right): normalised Kendall tau distance
//   above `maxKendall`.
// FocusUnreachable: simulating directional navigation from the initial selection never reaches
//   some selectable control (BFS over the 4-neighbour graph).
import * as G from "../geom";
import * as M from "../metrics";
import { readingOrder, visibleRect } from "../snapUtil";
import { Finding, GNode, Rule, RuleContext, Snapshot } from "../types";
import { eligible, finding, pct, stepEvery } from "./common";

export type Dir = "up" | "down" | "left" | "right";
export const DIRS: Dir[] = ["up", "down", "left", "right"];

export function selectables(snap: Snapshot, rule: string): GNode[] {
	return eligible(snap, rule, (n) => n.selectable && G.area(visibleRect(n)) > 0);
}

/** The engine's initial pick: lowest SelectionOrder, then top-most, then left-most. */
export function initialSelection(nodes: ReadonlyArray<GNode>): GNode | undefined {
	let best: GNode | undefined;
	for (const n of nodes) {
		if (best === undefined) {
			best = n;
			continue;
		}
		if (n.selectionOrder !== best.selectionOrder) {
			if (n.selectionOrder < best.selectionOrder) best = n;
		} else if (n.rect.y0 !== best.rect.y0) {
			if (n.rect.y0 < best.rect.y0) best = n;
		} else if (n.rect.x0 < best.rect.x0) best = n;
	}
	return best;
}

/**
 * Directional neighbour: candidates whose centre lies in the pressed half-plane, scored by
 * primary-axis distance plus twice the cross-axis offset (favours straight lines, like the
 * engine's cone search).
 */
export function neighbour(from: GNode, nodes: ReadonlyArray<GNode>, dir: Dir): GNode | undefined {
	const c = G.center(visibleRect(from));
	let best: GNode | undefined;
	let bestScore = math.huge;
	for (const n of nodes) {
		if (n.id === from.id || n.layer !== from.layer) continue;
		const p = G.center(visibleRect(n));
		const dx = p.x - c.x;
		const dy = p.y - c.y;
		let primary: number;
		let cross: number;
		if (dir === "right") [primary, cross] = [dx, dy];
		else if (dir === "left") [primary, cross] = [-dx, dy];
		else if (dir === "down") [primary, cross] = [dy, dx];
		else [primary, cross] = [-dy, dx];
		if (primary <= 1) continue;
		const score = primary + 2 * math.abs(cross);
		if (score < bestScore) {
			bestScore = score;
			best = n;
		}
	}
	return best;
}

function explicit(n: GNode, dir: Dir): number {
	return n.nextSelection[dir];
}

/** Ids reachable from `start` by directional moves (explicit links win). */
export function reachable(snap: Snapshot, nodes: ReadonlyArray<GNode>, start: GNode, step?: () => void): Set<number> {
	const seen = new Set<number>([start.id]);
	const queue = [start];
	let head = 0;
	while (head < queue.size()) {
		const cur = queue[head++];
		if (step !== undefined && head % 16 === 0) step();
		for (const dir of DIRS) {
			const link = explicit(cur, dir);
			let target: GNode | undefined;
			if (link >= 0) target = snap.byId.get(link);
			else if (link === -1) target = neighbour(cur, nodes, dir);
			if (target !== undefined && target.selectable && !seen.has(target.id)) {
				seen.add(target.id);
				queue.push(target);
			}
		}
	}
	return seen;
}

function active(ctx: RuleContext): boolean {
	return ctx.snap.viewport.gamepad || ctx.param("always", 0) > 0;
}

export const FocusDeadLink: Rule = {
	id: "FocusDeadLink",
	title: "NextSelection points at a hidden or unselectable object",
	profile: "lite",
	defaults: { always: 0 },
	run(ctx: RuleContext): Finding[] {
		if (!active(ctx)) return [];
		const out: Finding[] = [];
		for (const n of selectables(ctx.snap, "FocusDeadLink")) {
			for (const dir of DIRS) {
				if (explicit(n, dir) === -2) {
					out.push(finding("FocusDeadLink", n, 0.5, `NextSelection${dir.sub(1, 1).upper()}${dir.sub(2)} leads nowhere`, { hint: "clear it or point it at a visible selectable" }));
				}
			}
		}
		return out;
	},
};

export const FocusOrder: Rule = {
	id: "FocusOrder",
	title: "SelectionOrder contradicts the reading order",
	profile: "full",
	defaults: { always: 0, maxKendall: 0.25, minNodes: 3 },
	run(ctx: RuleContext): Finding[] {
		if (!active(ctx)) return [];
		const out: Finding[] = [];
		const byLayer = new Map<number, GNode[]>();
		for (const n of selectables(ctx.snap, "FocusOrder")) {
			if (n.selectionOrder === 0) continue;
			const list = byLayer.get(n.layer) ?? [];
			list.push(n);
			byLayer.set(n.layer, list);
		}
		for (const [, list] of byLayer) {
			if (list.size() < ctx.param("minNodes", 3)) continue;
			const reading = readingOrder(list);
			const rankOf = new Map<number, number>();
			reading.forEach((id, i) => rankOf.set(id, i));
			const bySel = [...list];
			bySel.sort((a, b) => (a.selectionOrder !== b.selectionOrder ? a.selectionOrder < b.selectionOrder : rankOf.get(a.id)! < rankOf.get(b.id)!));
			const sequence = bySel.map((n) => rankOf.get(n.id)!);
			const tau = M.kendallDistance(sequence);
			if (tau <= ctx.param("maxKendall", 0.25)) continue;
			// the first element whose SelectionOrder rank jumps ahead of its reading position
			let culprit = bySel[0];
			for (let i = 0; i < sequence.size(); i++) {
				if (sequence[i] !== i) {
					culprit = bySel[i];
					break;
				}
			}
			out.push(
				finding("FocusOrder", culprit, 0.25 + tau * 0.5, `SelectionOrder disagrees with reading order (${pct(tau)} of pairs swapped)`, {
					metrics: { kendall: tau, nodes: list.size() },
				}),
			);
		}
		return out;
	},
};

export const FocusUnreachable: Rule = {
	id: "FocusUnreachable",
	title: "Selectable control unreachable with the D-pad",
	profile: "full",
	defaults: { always: 0 },
	run(ctx: RuleContext): Finding[] {
		if (!active(ctx)) return [];
		const out: Finding[] = [];
		const snap = ctx.snap;
		const all = selectables(snap, "FocusUnreachable");
		// navigation stays inside the top-most layer that has selectables (modal pages)
		let topOrder = -math.huge;
		for (const n of all) topOrder = math.max(topOrder, n.displayOrder);
		const nodes = all.filter((n) => n.displayOrder === topOrder);
		const start = initialSelection(nodes);
		if (start === undefined) return out;
		const seen = reachable(snap, nodes, start, ctx.step);
		nodes.forEach((n, i) => {
			stepEvery(ctx, i, 32);
			if (seen.has(n.id)) return;
			out.push(finding("FocusUnreachable", n, 0.45, `cannot be reached from ${start.path} with the D-pad`, { other: start }));
		});
		return out;
	},
};
