// Builds Snapshots from compact specs. Used by the lune tests and by the device-matrix
// simulation, which re-runs rules on rects produced by the layout simulator.
import * as G from "./geom";
import { Rect } from "./geom";
import { foldShape } from "./snapUtil";
import { GNode, Layer, NodeKind, Snapshot, TextInfo, Viewport } from "./types";

export interface NodeSpec {
	name: string;
	kind?: NodeKind;
	rect: Rect;
	parent?: string;
	zIndex?: number;
	visible?: boolean;
	interactive?: boolean;
	selectable?: boolean;
	selectionOrder?: number;
	clips?: boolean;
	drawn?: boolean;
	opacity?: number;
	text?: Partial<TextInfo> & { text: string };
	floating?: boolean;
	inMotion?: boolean;
	layout?: "none" | "list" | "grid";
	listFill?: "Horizontal" | "Vertical";
	padding?: G.Insets;
	suppress?: string[];
	rotation?: number;
	owner?: string;
	whitespace?: string;
}

export function viewport(width: number, height: number, partial: Partial<Viewport> = {}): Viewport {
	return {
		width,
		height,
		deviceInsets: partial.deviceInsets ?? G.ZERO_INSETS,
		coreInsets: partial.coreInsets ?? G.ZERO_INSETS,
		touch: partial.touch ?? false,
		gamepad: partial.gamepad ?? false,
		dpiScale: partial.dpiScale ?? 1,
	};
}

function kindFor(spec: NodeSpec): NodeKind {
	if (spec.kind !== undefined) return spec.kind;
	if (spec.text !== undefined) return spec.interactive ? "textbutton" : "text";
	return spec.interactive ? "button" : "frame";
}

/** Specs must list parents before children. The first spec without a parent is the layer root. */
export function build(specs: ReadonlyArray<NodeSpec>, vp: Viewport, time = 0): Snapshot {
	const nodes: GNode[] = [];
	const byName = new Map<string, GNode>();
	const byId = new Map<number, GNode>();
	const layer: Layer = {
		id: 0,
		name: "Layer",
		displayOrder: 0,
		rect: G.rect(0, 0, vp.width, vp.height),
		ignoreInset: true,
		screenInsets: "DeviceSafeInsets",
		enabled: true,
	};
	let paint = 0;
	const specByName = new Map<string, NodeSpec>();
	for (const spec of specs) {
		specByName.set(spec.name, spec);
		const parent = spec.parent !== undefined ? byName.get(spec.parent) : undefined;
		const id = nodes.size();
		const kind = kindFor(spec);
		const path = parent !== undefined ? parent.path + "." + spec.name : spec.name;
		const parentClip = parent !== undefined ? (parent.clips ? G.intersect(parent.clipRect, parent.rect) : parent.clipRect) : layer.rect;
		const suppress = new Set<string>();
		if (parent !== undefined) for (const s of parent.suppress) suppress.add(s);
		for (const s of spec.suppress ?? []) suppress.add(s);
		const padding = spec.padding ?? G.ZERO_INSETS;
		const text: TextInfo | undefined =
			spec.text !== undefined
				? {
						text: spec.text.text,
						size: spec.text.size ?? 14,
						font: spec.text.font ?? "BuilderSans",
						wrapped: spec.text.wrapped ?? false,
						scaled: spec.text.scaled ?? false,
						fits: spec.text.fits ?? true,
						rich: spec.text.rich ?? false,
						bounds: spec.text.bounds ?? { x: G.width(spec.rect), y: G.height(spec.rect) },
						xAlign: spec.text.xAlign ?? "Left",
						yAlign: spec.text.yAlign ?? "Center",
						truncate: spec.text.truncate ?? false,
					}
				: undefined;
		paint += 1;
		const parentSpec = spec.parent !== undefined ? specByName.get(spec.parent) : undefined;
		const parentLayout = parentSpec?.layout ?? "none";
		const node: GNode = {
			id,
			parent: parent !== undefined ? parent.id : -1,
			children: [],
			depth: parent !== undefined ? parent.depth + 1 : 0,
			name: spec.name,
			className: kind,
			kind,
			path,
			shape: foldShape(path),
			owner: spec.owner ?? (parent !== undefined ? parent.owner : spec.name),
			layer: 0,
			displayOrder: 0,
			paintOrder: (spec.zIndex ?? 1) * 100000 + paint,
			rect: spec.rect,
			rotation: spec.rotation ?? 0,
			zIndex: spec.zIndex ?? 1,
			visible: spec.visible ?? true,
			opacity: spec.opacity ?? (spec.drawn === false ? 1 : 0),
			drawn: spec.drawn ?? (kind !== "frame" || spec.interactive === true),
			interactive: spec.interactive ?? false,
			selectable: spec.selectable ?? spec.interactive ?? false,
			selectionOrder: spec.selectionOrder ?? 0,
			nextSelection: { up: -1, down: -1, left: -1, right: -1 },
			clips: spec.clips ?? false,
			clipRect: parentClip,
			clipper: parent !== undefined ? (parent.clips ? parent.id : parent.clipper) : -1,
			padding,
			parentContent: parent !== undefined ? G.inset(parent.rect, parent.padding) : layer.rect,
			layoutOwned: parentLayout !== "none",
			parentLayout,
			listFill: parentSpec?.listFill ?? "none",
			floating: spec.floating ? id : parent !== undefined ? parent.floating : -1,
			inMotion: spec.inMotion ?? (parent !== undefined ? parent.inMotion : false),
			scroller: parent !== undefined ? (parent.kind === "scroll" ? parent.id : parent.scroller) : -1,
			text,
			suppress,
			recovery: "",
			allowNestedScroll: false,
			allowDisabledScroll: false,
			whitespaceLabel: spec.whitespace,
			valid: G.isFiniteRect(spec.rect),
		};
		if (parent !== undefined) parent.children.push(id);
		nodes.push(node);
		byName.set(spec.name, node);
		byId.set(id, node);
	}
	return { time, viewport: vp, layers: [layer], nodes, byId };
}

export function find(snap: Snapshot, name: string): GNode {
	for (const n of snap.nodes) if (n.name === name) return n;
	error(`fixture node ${name} not found`);
}
