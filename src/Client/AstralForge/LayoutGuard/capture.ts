// Live capture: one pass over the PlayerGui ScreenGuis builds a plain-data Snapshot (and,
// optionally, VNode trees for the device matrix). Everything engine-specific lives here.
//
// Engine facts this relies on (sources in docs/layoutguard-research.md):
//   - AbsolutePosition is the top-left corner of the box regardless of AnchorPoint, and is
//     relative to the GUI inset origin unless the ScreenGui has IgnoreGuiInset; we add the inset
//     back so every rect is in full-screen space.
//   - AbsoluteSize already includes UIScale and constraint effects; Rotation does not change
//     AbsoluteSize (rotated boxes keep their unrotated AABB), so AbsoluteRotation is stored.
//   - ZIndexBehavior.Sibling paints a parent before its children with siblings ordered by
//     ZIndex (ties by child order); Global orders every object by ZIndex first.
//   - GuiService:GetInsetArea(ScreenInsets) gives the usable rect for a ScreenInsets mode; the
//     difference between None and DeviceSafeInsets is the device cutout.
import * as G from "./geom";
import * as C from "./constraints";
import * as L from "./layoutSim";
import { foldShape } from "./snapUtil";
import { fontKey } from "./measure";
import { LEGACY_IDS } from "./rules";
import { GNode, Layer, NodeKind, ScrollInfo, Snapshot, TextInfo, Viewport } from "./types";

const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

export const OVERLAY_NAME = "LayoutGuardOverlay";

export interface CaptureOptions {
	maxNodes: number;
	step: () => void;
	withVNodes: boolean;
	/** containers registered for whitespace analysis (layoutEngine hook) */
	whitespace?: ReadonlyMap<GuiObject, string>;
}

export interface Captured {
	snap: Snapshot;
	instances: Map<number, GuiObject>;
	ids: Map<Instance, number>;
	roots: { layer: number; root: L.VNode; ignoreInset: boolean }[];
	truncated: boolean;
}

function finite(v: number): boolean {
	return v === v && v !== math.huge && v !== -math.huge;
}

function kindOf(o: GuiObject): NodeKind {
	if (o.IsA("TextButton")) return "textbutton";
	if (o.IsA("ImageButton")) return "imagebutton";
	if (o.IsA("TextBox")) return "textbox";
	if (o.IsA("TextLabel")) return "text";
	if (o.IsA("ScrollingFrame")) return "scroll";
	if (o.IsA("CanvasGroup")) return "canvas";
	if (o.IsA("ViewportFrame")) return "viewport";
	if (o.IsA("ImageLabel")) return "image";
	if (o.IsA("Frame")) return "frame";
	return "other";
}

function insetsFromRects(outer: Rect, inner: Rect): G.Insets {
	return {
		left: math.max(0, inner.Min.X - outer.Min.X),
		top: math.max(0, inner.Min.Y - outer.Min.Y),
		right: math.max(0, outer.Max.X - inner.Max.X),
		bottom: math.max(0, outer.Max.Y - inner.Max.Y),
	};
}

/** Viewport plus device / core-UI insets, from GuiService. */
export function captureViewport(): Viewport {
	const camera = Workspace.CurrentCamera;
	const size = camera !== undefined ? camera.ViewportSize : new Vector2(1280, 720);
	let deviceInsets = G.ZERO_INSETS;
	let coreInsets = G.ZERO_INSETS;
	const [ok, rects] = pcall(() => [
		GuiService.GetInsetArea(Enum.ScreenInsets.None),
		GuiService.GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets),
		GuiService.GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets),
	]);
	const full = ok && typeIs(rects, "table") ? (rects as Rect[])[0] : undefined;
	const device = ok && typeIs(rects, "table") ? (rects as Rect[])[1] : undefined;
	const core = ok && typeIs(rects, "table") ? (rects as Rect[])[2] : undefined;
	if (full !== undefined && device !== undefined && core !== undefined) {
		deviceInsets = insetsFromRects(full, device);
		coreInsets = insetsFromRects(full, core);
	} else {
		const [topLeft, bottomRight] = GuiService.GetGuiInset();
		coreInsets = { left: topLeft.X, top: topLeft.Y, right: bottomRight.X, bottom: bottomRight.Y };
	}
	return {
		width: size.X,
		height: size.Y,
		deviceInsets,
		coreInsets,
		touch: UserInputService.TouchEnabled && !UserInputService.MouseEnabled,
		gamepad: UserInputService.GamepadEnabled && GuiService.GuiNavigationEnabled,
		dpiScale: 1,
	};
}

function attrString(inst: Instance, name: string): string | undefined {
	const v = inst.GetAttribute(name);
	return typeIs(v, "string") && v !== "" ? v : undefined;
}

function suppressionOf(inst: Instance, inherited: ReadonlySet<string>): Set<string> {
	const out = new Set<string>();
	for (const s of inherited) out.add(s);
	if (inst.GetAttribute("LayoutGuardIgnore") === true) out.add("*");
	const list = attrString(inst, "LayoutGuardSuppress");
	if (list !== undefined) {
		for (const [raw] of list.gmatch("[^,%s]+")) {
			const id = raw as string;
			out.add(LEGACY_IDS.get(id) ?? id);
		}
	}
	return out;
}

function paddingOf(o: GuiObject): [G.Insets, C.PaddingSpec | undefined] {
	const p = o.FindFirstChildOfClass("UIPadding");
	if (p === undefined) return [G.ZERO_INSETS, undefined];
	const spec: C.PaddingSpec = {
		left: C.udim(p.PaddingLeft.Scale, p.PaddingLeft.Offset),
		top: C.udim(p.PaddingTop.Scale, p.PaddingTop.Offset),
		right: C.udim(p.PaddingRight.Scale, p.PaddingRight.Offset),
		bottom: C.udim(p.PaddingBottom.Scale, p.PaddingBottom.Offset),
	};
	return [C.resolvePadding(spec, o.AbsoluteSize.X, o.AbsoluteSize.Y), spec];
}

function layoutKind(o: Instance): ["none" | "list" | "grid" | "page" | "table", "Horizontal" | "Vertical" | "none"] {
	for (const c of o.GetChildren()) {
		if (c.IsA("UIGridLayout")) return ["grid", c.FillDirection.Name as "Horizontal" | "Vertical"];
		if (c.IsA("UIListLayout")) return ["list", c.FillDirection.Name as "Horizontal" | "Vertical"];
		if (c.IsA("UIPageLayout")) return ["page", c.FillDirection.Name as "Horizontal" | "Vertical"];
		if (c.IsA("UITableLayout")) return ["table", "none"];
	}
	return ["none", "none"];
}

function textOf(o: GuiObject): TextInfo | undefined {
	if (!(o.IsA("TextLabel") || o.IsA("TextButton") || o.IsA("TextBox"))) return undefined;
	const t = o as TextLabel;
	return {
		text: t.ContentText !== "" ? t.ContentText : t.Text,
		size: t.TextSize,
		font: fontKey(t.FontFace, t.Font),
		wrapped: t.TextWrapped,
		scaled: t.TextScaled,
		fits: t.TextFits,
		// ContentText already strips rich-text markup, so measurement needs no tag stripping
		rich: false,
		bounds: { x: t.TextBounds.X, y: t.TextBounds.Y },
		xAlign: t.TextXAlignment === Enum.TextXAlignment.Right ? "Right" : t.TextXAlignment === Enum.TextXAlignment.Center ? "Center" : "Left",
		yAlign: t.TextYAlignment === Enum.TextYAlignment.Bottom ? "Bottom" : t.TextYAlignment === Enum.TextYAlignment.Top ? "Top" : "Center",
		truncate: t.TextTruncate !== Enum.TextTruncate.None,
	};
}

function scrollOf(s: ScrollingFrame): ScrollInfo {
	const dir = s.ScrollingDirection;
	let cx = 0;
	let cy = 0;
	const [pad] = paddingOf(s);
	for (const c of s.GetChildren()) {
		if (c.IsA("UIGridStyleLayout")) {
			cx = math.max(cx, c.AbsoluteContentSize.X + pad.left + pad.right);
			cy = math.max(cy, c.AbsoluteContentSize.Y + pad.top + pad.bottom);
		} else if (c.IsA("GuiObject") && c.Visible) {
			cx = math.max(cx, c.AbsolutePosition.X - s.AbsolutePosition.X + s.CanvasPosition.X + c.AbsoluteSize.X + pad.right);
			cy = math.max(cy, c.AbsolutePosition.Y - s.AbsolutePosition.Y + s.CanvasPosition.Y + c.AbsoluteSize.Y + pad.bottom);
		}
	}
	return {
		canvas: { x: s.AbsoluteCanvasSize.X, y: s.AbsoluteCanvasSize.Y },
		window: { x: s.AbsoluteWindowSize.X, y: s.AbsoluteWindowSize.Y },
		canvasPos: { x: s.CanvasPosition.X, y: s.CanvasPosition.Y },
		scrollX: dir === Enum.ScrollingDirection.X || dir === Enum.ScrollingDirection.XY,
		scrollY: dir !== Enum.ScrollingDirection.X,
		enabled: s.ScrollingEnabled,
		automatic: s.AutomaticCanvasSize !== Enum.AutomaticSize.None,
		content: { x: finite(cx) ? cx : 0, y: finite(cy) ? cy : 0 },
	};
}

/** Own visual transparency (1 = invisible) and whether the object paints anything. */
function surfaceOf(o: GuiObject): [number, boolean] {
	let own = o.BackgroundTransparency;
	if (o.IsA("ImageLabel") || o.IsA("ImageButton")) {
		if (o.Image !== "") own = math.min(own, o.ImageTransparency);
	} else if (o.IsA("ViewportFrame")) {
		own = math.min(own, o.ImageTransparency);
	} else if (o.IsA("CanvasGroup")) {
		own = math.min(own, o.GroupTransparency);
	}
	return [own, own < 0.99 || o.FindFirstChildOfClass("UIStroke") !== undefined];
}

function vnodeOf(o: GuiObject, id: number, children: L.VNode[]): L.VNode {
	const el: C.ElementSpec = {
		position: C.udim2(o.Position.X.Scale, o.Position.X.Offset, o.Position.Y.Scale, o.Position.Y.Offset),
		size: C.udim2(o.Size.X.Scale, o.Size.X.Offset, o.Size.Y.Scale, o.Size.Y.Offset),
		anchor: { x: o.AnchorPoint.X, y: o.AnchorPoint.Y },
		sizeConstraint: o.SizeConstraint.Name as C.SizeConstraintKind,
	};
	const node: L.VNode = { id, name: o.Name, visible: o.Visible, layoutOrder: o.LayoutOrder, element: el, children };
	const auto = o.AutomaticSize;
	if (auto !== Enum.AutomaticSize.None) node.automaticSize = auto.Name as L.AutoSize;
	for (const c of o.GetChildren()) {
		if (c.IsA("UIAspectRatioConstraint")) {
			el.aspect = { ratio: c.AspectRatio, aspectType: c.AspectType.Name as C.AspectTypeKind, dominant: c.DominantAxis.Name as C.DominantAxisKind };
		} else if (c.IsA("UISizeConstraint")) {
			el.limits = { minX: c.MinSize.X, minY: c.MinSize.Y, maxX: c.MaxSize.X, maxY: c.MaxSize.Y };
		} else if (c.IsA("UIScale")) {
			node.uiScale = c.Scale;
		} else if (c.IsA("UIPadding")) {
			node.padding = paddingOf(o)[1];
		} else if (c.IsA("UIGridLayout")) {
			node.layout = L.defaultGrid({
				cellSize: C.udim2(c.CellSize.X.Scale, c.CellSize.X.Offset, c.CellSize.Y.Scale, c.CellSize.Y.Offset),
				cellPadding: C.udim2(c.CellPadding.X.Scale, c.CellPadding.X.Offset, c.CellPadding.Y.Scale, c.CellPadding.Y.Offset),
				fill: c.FillDirection.Name as L.FillDir,
				maxCells: c.FillDirectionMaxCells,
				startCorner: c.StartCorner.Name as L.Corner,
				hAlign: c.HorizontalAlignment.Name as L.HAlign,
				vAlign: c.VerticalAlignment.Name as L.VAlign,
				sortByName: c.SortOrder === Enum.SortOrder.Name,
			});
		} else if (c.IsA("UIListLayout")) {
			node.layout = L.defaultList({
				fill: c.FillDirection.Name as L.FillDir,
				hAlign: c.HorizontalAlignment.Name as L.HAlign,
				vAlign: c.VerticalAlignment.Name as L.VAlign,
				padding: C.udim(c.Padding.Scale, c.Padding.Offset),
				sortByName: c.SortOrder === Enum.SortOrder.Name,
				wraps: c.Wraps,
				hFlex: c.HorizontalFlex.Name as L.Flex,
				vFlex: c.VerticalFlex.Name as L.Flex,
				lineAlign: c.ItemLineAlignment.Name as L.LineAlign,
			});
		} else if (c.IsA("UIFlexItem")) {
			node.flex = { mode: c.FlexMode.Name as L.FlexItemSpec["mode"], grow: c.GrowRatio, shrink: c.ShrinkRatio, lineAlign: c.ItemLineAlignment.Name as L.LineAlign };
		}
	}
	if (o.IsA("ScrollingFrame")) node.canvas = C.udim2(o.CanvasSize.X.Scale, o.CanvasSize.X.Offset, o.CanvasSize.Y.Scale, o.CanvasSize.Y.Offset);
	if (o.IsA("TextLabel") || o.IsA("TextButton") || o.IsA("TextBox")) {
		const t = o as TextLabel;
		if (auto !== Enum.AutomaticSize.None) node.text = { text: t.ContentText, size: t.TextSize, font: fontKey(t.FontFace, t.Font), wrapped: t.TextWrapped };
	}
	return node;
}

type CNode = GNode & { inheritedFade: number };

interface Frame0 {
	inst: GuiObject;
	parent: CNode | undefined;
	vparent: L.VNode | undefined;
}

/**
 * Captures every enabled ScreenGui under `playerGui`. Work is bounded by `maxNodes`; `step` is
 * called every 64 nodes so the caller can spread the pass over frames.
 */
export function capture(playerGui: Instance, opts: CaptureOptions): Captured {
	const vp = captureViewport();
	const [insetTopLeft] = GuiService.GetGuiInset();
	const nodes: CNode[] = [];
	const byId = new Map<number, GNode>();
	const instances = new Map<number, GuiObject>();
	const ids = new Map<Instance, number>();
	const layers: Layer[] = [];
	const roots: Captured["roots"] = [];
	const pendingLinks: [GNode, GuiObject, "up" | "down" | "left" | "right", GuiObject | undefined][] = [];
	let truncated = false;
	const screen = G.rect(0, 0, vp.width, vp.height);

	const guis = playerGui.GetChildren().filter((c): c is ScreenGui => c.IsA("ScreenGui") && c.Enabled && c.Name !== OVERLAY_NAME && c.GetAttribute("LayoutGuardIgnore") !== true);
	guis.sort((a, b) => (a.DisplayOrder !== b.DisplayOrder ? a.DisplayOrder < b.DisplayOrder : a.Name < b.Name));

	for (const gui of guis) {
		if (truncated) break;
		const layerId = layers.size();
		const offset = gui.IgnoreGuiInset ? 0 : insetTopLeft.Y;
		const offsetX = gui.IgnoreGuiInset ? 0 : insetTopLeft.X;
		const layer: Layer = {
			id: layerId,
			name: gui.Name,
			displayOrder: gui.DisplayOrder,
			rect: G.fromPosSize(gui.AbsolutePosition.X + offsetX, gui.AbsolutePosition.Y + offset, gui.AbsoluteSize.X, gui.AbsoluteSize.Y),
			ignoreInset: gui.IgnoreGuiInset,
			screenInsets: gui.ScreenInsets.Name as Layer["screenInsets"],
			enabled: gui.Enabled,
		};
		layers.push(layer);
		const global = gui.ZIndexBehavior === Enum.ZIndexBehavior.Global;
		const layerSuppress = suppressionOf(gui, new Set());
		const guiLayout = layoutKind(gui);
		const vroot: L.VNode = L.vnode(-1 - layerId, gui.Name, { size: C.fromScale(1, 1) });
		roots.push({ layer: layerId, root: vroot, ignoreInset: gui.IgnoreGuiInset });
		let dfs = 0;
		// explicit stack, children pushed in reverse paint order so they pop in paint order
		const stack: Frame0[] = [];
		const pushChildren = (parentInst: Instance, parent: CNode | undefined, vparent: L.VNode | undefined) => {
			const kids = parentInst.GetChildren().filter((c): c is GuiObject => c.IsA("GuiObject") && c.Name !== OVERLAY_NAME && c.Name !== "WhitespaceDebug");
			const order = new Map<GuiObject, number>();
			kids.forEach((k, i) => order.set(k, i));
			kids.sort((a, b) => (a.ZIndex !== b.ZIndex ? a.ZIndex < b.ZIndex : order.get(a)! < order.get(b)!));
			for (let i = kids.size() - 1; i >= 0; i--) stack.push({ inst: kids[i], parent, vparent });
		};
		pushChildren(gui, undefined, vroot);
		while (stack.size() > 0) {
			if (nodes.size() >= opts.maxNodes) {
				truncated = true;
				break;
			}
			const { inst, parent, vparent } = stack.pop()!;
			const id = nodes.size();
			if (id % 64 === 63) opts.step();
			const pos = inst.AbsolutePosition;
			const size = inst.AbsoluteSize;
			const x0 = pos.X + offsetX;
			const y0 = pos.Y + offset;
			const rect = G.fromPosSize(x0, y0, size.X, size.Y);
			const valid = finite(x0) && finite(y0) && finite(size.X) && finite(size.Y) && size.X >= 0 && size.Y >= 0;
			const kind = kindOf(inst);
			const [own, drawn] = surfaceOf(inst);
			// CanvasGroups compose transparency for the whole subtree; plain frames do not
			const groupT = parent !== undefined && instances.get(parent.id)!.IsA("CanvasGroup") ? (instances.get(parent.id) as CanvasGroup).GroupTransparency : 0;
			const inherited = parent !== undefined ? parent.inheritedFade : 0;
			const fade = 1 - (1 - inherited) * (1 - groupT);
			const opacity = 1 - (1 - own) * (1 - fade);
			const [layoutHere, fillHere] = parent !== undefined ? parentLayoutCache.get(parent.id)! : guiLayout;
			const [padding] = paddingOf(inst);
			const path = parent !== undefined ? parent.path + "." + inst.Name : gui.Name + "." + inst.Name;
			const parentRect = parent !== undefined ? parent.rect : layer.rect;
			const parentPad = parent !== undefined ? parent.padding : G.ZERO_INSETS;
			const clipRect = parent !== undefined ? (parent.clips ? G.intersect(parent.clipRect, parent.rect) : parent.clipRect) : gui.ClipToDeviceSafeArea ? G.inset(screen, vp.deviceInsets) : screen;
			const floatingAttr = inst.GetAttribute("LayoutFloating") === true;
			const motionAttr = inst.GetAttribute("LayoutInMotion") === true;
			const interactive = inst.IsA("GuiButton") || inst.IsA("TextBox");
			const node: CNode = {
				id,
				parent: parent !== undefined ? parent.id : -1,
				children: [],
				depth: parent !== undefined ? parent.depth + 1 : 0,
				name: inst.Name,
				className: inst.ClassName,
				kind,
				path,
				shape: foldShape(path),
				owner: attrString(inst, "LayoutOwner") ?? (parent !== undefined ? parent.owner : gui.Name),
				layer: layerId,
				displayOrder: gui.DisplayOrder,
				paintOrder: global ? inst.ZIndex * 1000000 + dfs : dfs,
				rect,
				rotation: inst.AbsoluteRotation,
				zIndex: inst.ZIndex,
				visible: inst.Visible && (parent === undefined || parent.visible),
				opacity,
				drawn,
				interactive: interactive && inst.Active !== false,
				selectable: inst.Selectable && interactive,
				selectionOrder: inst.SelectionOrder,
				nextSelection: { up: -1, down: -1, left: -1, right: -1 },
				clips: inst.ClipsDescendants,
				clipRect,
				clipper: parent !== undefined ? (parent.clips ? parent.id : parent.clipper) : -1,
				padding,
				parentContent: G.inset(parentRect, parentPad),
				layoutOwned: layoutHere !== "none",
				parentLayout: layoutHere,
				listFill: fillHere,
				floating: floatingAttr ? id : parent !== undefined ? parent.floating : -1,
				inMotion: motionAttr || (parent !== undefined && parent.inMotion),
				scroller: parent !== undefined ? (parent.kind === "scroll" && parent.scroll !== undefined && (parent.scroll.scrollX || parent.scroll.scrollY) ? parent.id : parent.scroller) : -1,
				text: textOf(inst),
				scroll: inst.IsA("ScrollingFrame") ? scrollOf(inst) : undefined,
				suppress: suppressionOf(inst, parent !== undefined ? parent.suppress : layerSuppress),
				recovery: attrString(inst, "LayoutGuardRecovery") ?? "",
				allowNestedScroll: inst.GetAttribute("LayoutGuardAllowNestedScroll") === true,
				allowDisabledScroll: inst.GetAttribute("LayoutGuardAllowDisabledScroll") === true,
				whitespaceLabel: opts.whitespace?.get(inst) ?? attrString(inst, "LayoutGuardWhitespace"),
				valid,
				inheritedFade: fade,
			};
			dfs += 1;
			parentLayoutCache.set(id, layoutKind(inst));
			if (parent !== undefined) parent.children.push(id);
			nodes.push(node);
			byId.set(id, node);
			instances.set(id, inst);
			ids.set(inst, id);
			if (node.selectable) {
				pendingLinks.push([node, inst, "up", inst.NextSelectionUp]);
				pendingLinks.push([node, inst, "down", inst.NextSelectionDown]);
				pendingLinks.push([node, inst, "left", inst.NextSelectionLeft]);
				pendingLinks.push([node, inst, "right", inst.NextSelectionRight]);
			}
			let vnode: L.VNode | undefined;
			if (opts.withVNodes && vparent !== undefined) {
				vnode = vnodeOf(inst, id, []);
				vparent.children.push(vnode);
			}
			pushChildren(inst, node, vnode);
		}
	}
	// NextSelection links resolve after the walk, when every target has an id
	for (const [node, , dir, target] of pendingLinks) {
		if (target === undefined) continue;
		const tid = ids.get(target);
		const t = tid !== undefined ? byId.get(tid) : undefined;
		node.nextSelection[dir] = t !== undefined && t.visible && t.selectable ? t.id : -2;
	}
	parentLayoutCache.clear();
	return { snap: { time: os.clock(), viewport: vp, layers, nodes, byId }, instances, ids, roots, truncated };
}

const parentLayoutCache = new Map<number, ReturnType<typeof layoutKind>>();
