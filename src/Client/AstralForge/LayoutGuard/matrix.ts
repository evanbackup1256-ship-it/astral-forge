// Device matrix: re-resolve the captured layout tree (VNode) at simulated phone sizes with
// layoutSim, rebuild a Snapshot per device, and run the layout rules on each. This catches
// "fine on my monitor, broken on an iPhone SE" without owning eleven phones.
//
// Sizes are landscape logical points (what Roblox reports as the viewport on those devices);
// insets approximate the notch / Dynamic Island side cutout and the home indicator. The Roblox
// top bar inset is 58px with the 2024 top bar (GuiService:GetGuiInset) and is applied to layers
// that use CoreUISafeInsets.
import * as G from "./geom";
import { Measure, VNode, resolve } from "./layoutSim";
import { Finding, GNode, Snapshot, Viewport } from "./types";

export interface Device {
	name: string;
	width: number;
	height: number;
	/** cutout depth on the long edges (notch / island in landscape) */
	side: number;
	/** home indicator band at the bottom */
	bottom: number;
}

export const PHONES: ReadonlyArray<Device> = [
	{ name: "iPhone SE", width: 667, height: 375, side: 0, bottom: 0 },
	{ name: "iPhone 8 Plus", width: 736, height: 414, side: 0, bottom: 0 },
	{ name: "iPhone 13 mini", width: 812, height: 375, side: 44, bottom: 21 },
	{ name: "iPhone 14", width: 844, height: 390, side: 47, bottom: 21 },
	{ name: "iPhone 14 Plus", width: 926, height: 428, side: 47, bottom: 21 },
	{ name: "iPhone 15 Pro Max", width: 932, height: 430, side: 59, bottom: 21 },
	{ name: "Pixel 7a", width: 915, height: 412, side: 32, bottom: 0 },
	{ name: "Pixel 8 Pro", width: 892, height: 412, side: 36, bottom: 0 },
	{ name: "Galaxy S23", width: 780, height: 360, side: 30, bottom: 0 },
	{ name: "Galaxy A14", width: 803, height: 360, side: 28, bottom: 0 },
	{ name: "Small Android", width: 640, height: 360, side: 0, bottom: 0 },
];

export const TOPBAR_INSET = 58;

export function deviceViewport(d: Device): Viewport {
	return {
		width: d.width,
		height: d.height,
		deviceInsets: { left: d.side, right: d.side, top: 0, bottom: d.bottom },
		coreInsets: { left: 0, right: 0, top: TOPBAR_INSET, bottom: 0 },
		touch: true,
		gamepad: false,
		dpiScale: 1,
	};
}

/**
 * Rebuild a snapshot with rects from `rects`, recomputing everything derived from geometry
 * (clip chains, padded parent boxes, text fit) and keeping identity, attributes and suppression.
 * Nodes without a simulated rect (not in the VNode tree) are hidden.
 */
export function rebase(template: Snapshot, rects: Map<number, G.Rect>, vp: Viewport, device: string, measure: Measure): Snapshot {
	const nodes: GNode[] = [];
	const byId = new Map<number, GNode>();
	const screen = G.rect(0, 0, vp.width, vp.height);
	for (const src of template.nodes) {
		const r = rects.get(src.id);
		const parent = byId.get(src.parent);
		const clipRect = parent !== undefined ? (parent.clips ? G.intersect(parent.clipRect, parent.rect) : parent.clipRect) : screen;
		const rect = r ?? G.EMPTY;
		let text = src.text;
		if (text !== undefined && r !== undefined && !text.scaled) {
			const m = measure(text.text, text.size, text.font, text.wrapped ? G.width(r) : math.huge);
			const fits = (text.wrapped || m.x <= G.width(r) + 0.5) && m.y <= G.height(r) + 0.5;
			text = { ...text, fits, bounds: { x: math.min(m.x, text.wrapped ? G.width(r) : m.x), y: m.y } };
		}
		const node: GNode = {
			...src,
			children: [],
			rect,
			visible: src.visible && r !== undefined && (parent === undefined || parent.visible),
			clipRect,
			parentContent: parent !== undefined ? G.inset(parent.rect, parent.padding) : screen,
			text,
			valid: r !== undefined && G.isFiniteRect(rect),
		};
		if (parent !== undefined) parent.children.push(node.id);
		nodes.push(node);
		byId.set(node.id, node);
	}
	const layers = template.layers.map((l) => ({ ...l, rect: l.ignoreInset ? screen : G.rect(0, vp.coreInsets.top, vp.width, vp.height) }));
	return { time: template.time, viewport: vp, layers, nodes, byId, device };
}

export interface MatrixResult {
	device: string;
	findings: Finding[];
}

/**
 * Runs `check` on each simulated device. `roots` maps each layer's root VNode; the root is
 * resolved against the layer rect for that device.
 */
export function runMatrix(
	template: Snapshot,
	roots: ReadonlyArray<{ layer: number; root: VNode; ignoreInset: boolean }>,
	check: (snap: Snapshot) => Finding[],
	measure: Measure,
	devices: ReadonlyArray<Device> = PHONES,
	step?: () => void,
): MatrixResult[] {
	const out: MatrixResult[] = [];
	for (const d of devices) {
		const vp = deviceViewport(d);
		const rects = new Map<number, G.Rect>();
		for (const entry of roots) {
			const base = entry.ignoreInset ? G.rect(0, 0, vp.width, vp.height) : G.rect(0, vp.coreInsets.top, vp.width, vp.height);
			const res = resolve(entry.root, base, measure);
			for (const [id, r] of res.rects) rects.set(id, r);
		}
		if (step !== undefined) step();
		const snap = rebase(template, rects, vp, d.name, measure);
		out.push({ device: d.name, findings: check(snap) });
		if (step !== undefined) step();
	}
	return out;
}

/**
 * Folds per-device findings into one line per signature: "fails on 4/11 phones (iPhone SE,
 * Galaxy S23, ...)", severity weighted by the share of devices affected.
 */
export function summarizeMatrix(results: ReadonlyArray<MatrixResult>): Finding[] {
	const groups = new Map<string, { finding: Finding; devices: string[]; worst: number }>();
	for (const res of results) {
		const seen = new Set<string>();
		for (const f of res.findings) {
			if (seen.has(f.signature)) continue;
			seen.add(f.signature);
			const g = groups.get(f.signature);
			if (g === undefined) groups.set(f.signature, { finding: f, devices: [res.device], worst: f.severity });
			else {
				g.devices.push(res.device);
				if (f.severity > g.worst) {
					g.worst = f.severity;
					g.finding = f;
				}
			}
		}
	}
	const total = math.max(1, results.size());
	const out: Finding[] = [];
	for (const [signature, g] of groups) {
		const share = g.devices.size() / total;
		const names = g.devices.size() > 3 ? `${g.devices[0]}, ${g.devices[1]}, ${g.devices[2]}, ...` : g.devices.join(", ");
		const severity = g.worst * (0.5 + 0.5 * share);
		out.push({
			...g.finding,
			rule: "DeviceMatrix:" + g.finding.rule,
			signature: "Matrix|" + signature,
			severity,
			level: severity >= 0.66 ? "error" : severity >= 0.33 ? "warn" : "info",
			message: `${g.finding.message} on ${g.devices.size()}/${results.size()} phones (${names})`,
			metrics: { ...(g.finding.metrics ?? {}), devices: g.devices.size() },
		});
	}
	out.sort((a, b) => a.severity > b.severity);
	return out;
}
