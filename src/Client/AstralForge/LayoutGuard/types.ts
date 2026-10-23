// Data model shared by capture, rules, engine and overlay. A Snapshot is plain data captured from
// the live GuiObject tree in one pass, so every rule is a pure function of it (and is testable
// under lune with hand-built snapshots).
import { Insets, Rect } from "./geom";

export type NodeKind = "frame" | "text" | "button" | "textbutton" | "imagebutton" | "textbox" | "image" | "scroll" | "canvas" | "viewport" | "other";

export interface TextInfo {
	text: string;
	size: number;
	/** font family id (FontFace.Family) + weight, used as the measurement cache key */
	font: string;
	wrapped: boolean;
	scaled: boolean;
	fits: boolean;
	rich: boolean;
	/** engine TextBounds */
	bounds: { x: number; y: number };
	xAlign: "Left" | "Center" | "Right";
	yAlign: "Top" | "Center" | "Bottom";
	truncate: boolean;
}

export interface ScrollInfo {
	canvas: { x: number; y: number };
	window: { x: number; y: number };
	canvasPos: { x: number; y: number };
	scrollX: boolean;
	scrollY: boolean;
	enabled: boolean;
	automatic: boolean;
	/** content extent measured from children (canvas space) */
	content: { x: number; y: number };
}

export interface GNode {
	id: number;
	parent: number;
	children: number[];
	depth: number;
	name: string;
	className: string;
	kind: NodeKind;
	/** short dotted path from the layer, e.g. "App.Pages.Inventory.Grid.Slot" */
	path: string;
	/** path with list indices and numeric suffixes folded ("Slot12" -> "Slot#"), the dedupe key */
	shape: string;
	owner: string;
	layer: number;
	/** ScreenGui.DisplayOrder of the layer, then the global ZIndex walk for occlusion order */
	displayOrder: number;
	paintOrder: number;
	rect: Rect;
	rotation: number;
	zIndex: number;
	visible: boolean;
	/** effective transparency: 1 when every ancestor CanvasGroup / own background makes it invisible */
	opacity: number;
	drawn: boolean;
	interactive: boolean;
	selectable: boolean;
	selectionOrder: number;
	nextSelection: { up: number; down: number; left: number; right: number };
	clips: boolean;
	/** intersection of every clipping ancestor's rect (screen space) */
	clipRect: Rect;
	/** id of the closest ClipsDescendants ancestor (or -1) */
	clipper: number;
	padding: Insets;
	/** the parent's padded content box */
	parentContent: Rect;
	layoutOwned: boolean;
	parentLayout: "none" | "list" | "grid" | "page" | "table";
	listFill: "Horizontal" | "Vertical" | "none";
	floating: number;
	inMotion: boolean;
	/** inside a ScrollingFrame that can actually scroll (id or -1) */
	scroller: number;
	text?: TextInfo;
	scroll?: ScrollInfo;
	/** rule ids suppressed by LayoutGuardSuppress on this node or an ancestor; "*" = all */
	suppress: Set<string>;
	/** opt-in scoped recovery kinds from LayoutGuardRecovery */
	recovery: string;
	allowNestedScroll: boolean;
	allowDisabledScroll: boolean;
	/** container explicitly registered for whitespace analysis (SplitColumns / LayoutDebug) */
	whitespaceLabel?: string;
	/** finite and non-degenerate geometry */
	valid: boolean;
}

export interface Viewport {
	width: number;
	height: number;
	/** device cutouts (notch, home indicator) as insets from the full screen */
	deviceInsets: Insets;
	/** Roblox core UI (top bar) insets on top of the device ones */
	coreInsets: Insets;
	touch: boolean;
	gamepad: boolean;
	/** UI pixels per inch-ish scale: 1 on desktop, used for touch size thresholds */
	dpiScale: number;
}

export interface Layer {
	id: number;
	name: string;
	displayOrder: number;
	rect: Rect;
	ignoreInset: boolean;
	screenInsets: "None" | "DeviceSafeInsets" | "CoreUISafeInsets" | "TopbarSafeInsets";
	enabled: boolean;
}

export interface Snapshot {
	time: number;
	viewport: Viewport;
	layers: Layer[];
	nodes: GNode[];
	/** node id -> index in nodes (ids are dense, so this is usually identity) */
	byId: Map<number, GNode>;
	/** simulated snapshots carry the device name they model */
	device?: string;
}

export type Level = "info" | "warn" | "error";

export interface Finding {
	rule: string;
	node: number;
	other?: number;
	/** 0..1, comparable across rules */
	severity: number;
	level: Level;
	message: string;
	/** stable grouping key (rule + node shape [+ other shape]) */
	signature: string;
	rect?: Rect;
	metrics?: Record<string, number>;
	/** pixel fix hint, e.g. "move 12px left" */
	hint?: string;
}

export type Profile = "full" | "lite";

export interface RuleConfig {
	enabled: boolean;
	/** findings under this severity are dropped */
	minSeverity: number;
	/** per-rule numeric knobs; each rule documents its keys and defaults */
	params: Record<string, number>;
}

export interface RuleContext {
	snap: Snapshot;
	config: RuleConfig;
	measure: (text: string, size: number, font: string, maxWidth: number) => { x: number; y: number };
	/** cooperative yield point; rules call it inside long loops */
	step: () => void;
	param: (key: string, fallback: number) => number;
}

export interface Rule {
	id: string;
	title: string;
	/** "lite" rules are cheap enough to run in sampled production mode */
	profile: Profile;
	defaults: Record<string, number>;
	run(ctx: RuleContext): Finding[];
}

export function levelFor(severity: number): Level {
	if (severity >= 0.66) return "error";
	if (severity >= 0.33) return "warn";
	return "info";
}

export function isText(n: GNode): boolean {
	return n.text !== undefined && n.text.text !== "";
}

export function suppressed(n: GNode, rule: string): boolean {
	return n.suppress.has("*") || n.suppress.has(rule);
}
