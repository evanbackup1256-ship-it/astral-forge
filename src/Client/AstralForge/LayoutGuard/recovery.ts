// Scoped recovery, opt-in per element (LayoutGuardRecovery attribute set by the owning
// component), ported from the old guard and driven by confirmed findings:
//   "Canvas"        CanvasOverflow on a ScrollingFrame -> CanvasSize grows to the content.
//   "FloatingPanel" ViewportOverflow/SafeArea on a panel parented to a ScreenGui -> Position is
//                   nudged by the minimum vector that brings it back on screen.
// Each element is touched at most MAX_TRIES times per session so the guard never fights an
// owner that keeps moving it back.
import * as G from "./geom";
import { Finding, Snapshot } from "./types";
import { safeRect } from "./rules/touch";

const MAX_TRIES = 3;
const tries = setmetatable(new Map<Instance, number>(), { __mode: "k" } as LuaMetatable<Map<Instance, number>>);
export const recoveryStats = { canvasFixed: 0, panelsNudged: 0, gaveUp: 0 };

function allowed(inst: Instance): boolean {
	const n = tries.get(inst) ?? 0;
	if (n >= MAX_TRIES) {
		if (n === MAX_TRIES) recoveryStats.gaveUp += 1;
		tries.set(inst, n + 1);
		return false;
	}
	tries.set(inst, n + 1);
	return true;
}

export function recover(snap: Snapshot, findings: ReadonlyArray<Finding>, instances: Map<number, GuiObject>): string[] {
	const done: string[] = [];
	for (const f of findings) {
		const node = snap.byId.get(f.node);
		const inst = instances.get(f.node);
		if (node === undefined || inst === undefined || inst.Parent === undefined) continue;
		if (f.rule === "CanvasOverflow" && node.recovery === "Canvas" && inst.IsA("ScrollingFrame") && node.scroll !== undefined) {
			if (!allowed(inst)) continue;
			const s = node.scroll;
			const canvas = inst.CanvasSize;
			const growX = s.scrollX && s.content.x > s.canvas.x + 1;
			const growY = s.scrollY && s.content.y > s.canvas.y + 1;
			inst.CanvasSize = new UDim2(growX ? 0 : canvas.X.Scale, growX ? math.ceil(s.content.x) : canvas.X.Offset, growY ? 0 : canvas.Y.Scale, growY ? math.ceil(s.content.y) : canvas.Y.Offset);
			recoveryStats.canvasFixed += 1;
			done.push(`CanvasSize ${node.path}`);
		} else if ((f.rule === "ViewportOverflow" || f.rule === "SafeArea") && node.recovery === "FloatingPanel" && inst.Parent.IsA("LayerCollector")) {
			const layer = snap.layers[node.layer];
			const bounds = f.rule === "SafeArea" ? safeRect(snap, layer) : G.rect(0, 0, snap.viewport.width, snap.viewport.height);
			if (G.width(node.rect) > G.width(bounds) || G.height(node.rect) > G.height(bounds)) continue;
			const v = G.nudgeInto(node.rect, bounds);
			if (math.abs(v.x) < 1 && math.abs(v.y) < 1) continue;
			if (!allowed(inst)) continue;
			const p = inst.Position;
			inst.Position = new UDim2(p.X.Scale, p.X.Offset + math.round(v.x), p.Y.Scale, p.Y.Offset + math.round(v.y));
			recoveryStats.panelsNudged += 1;
			done.push(`nudged ${node.path}`);
		}
	}
	return done;
}
