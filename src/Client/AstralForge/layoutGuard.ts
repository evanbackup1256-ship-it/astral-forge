import { ClientLog } from "./CoreKit/log";
import Diagnostics = require("./LayoutDiagnostics");
import { importTsModule } from "./vendor";

const core = importTsModule<{
	Reflect: {
		// Free functions. A method signature compiles to Reflect:decorate and shifts every argument.
		defineMetadata(this: void, target: object, key: string, value: unknown): void;
		decorate(this: void, target: object, id: string, decorator: unknown, args?: unknown[]): void;
	};
	Controller: unknown;
}>(
	game
		.GetService("ReplicatedStorage")
		.WaitForChild("rbxts_include")
		.WaitForChild("node_modules")
		.WaitForChild("@flamework")
		.WaitForChild("core")
		.WaitForChild("out"),
);
const Reflect = core.Reflect;
const Controller = core.Controller;

interface Rect {
	x0: number;
	y0: number;
	x1: number;
	y1: number;
}

interface LayoutGeom {
	rect(x0: number, y0: number, x1: number, y1: number): Rect;
	rectFromPosSize(x: number, y: number, w: number, h: number): Rect;
	rectWidth(r: Rect): number;
	rectHeight(r: Rect): number;
	overflowAmount(inner: Rect, outer: Rect): number;
}

interface GuardPlan {
	MAX_TRIES: number;
	FRESH_CAP: number;
	SETTLE_FRAMES: number;
	MIN_SWEEP_SECONDS: number;
	BURST_FRAMES: number;
	budget(burstFramesLeft: number, freshWaiting: number): { fresh: number; sweep: number };
	resized(lastWidth: number, lastHeight: number, width: number, height: number): boolean;
	labelsCollide(a: Rect, b: Rect): boolean;
	nudgeIntoView(x0: number, y0: number, x1: number, y1: number, screenW: number, screenH: number): LuaTuple<[number, number]>;
}

// LayoutKit is still Luau; require its members through the kit factory like the bundled code did.
const LayoutKit = require(script.Parent!.WaitForChild("LayoutKit") as ModuleScript) as (name: string) => unknown;
const Geom = LayoutKit("layoutGeom") as LayoutGeom;
const Plan = LayoutKit("layoutGuardPlan") as GuardPlan;

const diagnostics = Diagnostics.new(os.clock);
const UserInputService = game.GetService("UserInputService");
const IGNORE_ATTRIBUTE = "LayoutGuardIgnore";
const FIT_SLOP = 6;
const WILD_ASPECT_SLOP = 2;
const MAX_TRIES = Plan.MAX_TRIES;
const stats = {
	scans: 0,
	freshChecked: 0,
	sweepChecked: 0,
	bursts: 0,
	canvasDesyncFixed: 0,
	scrollingReenabled: 0,
	degenerateHidden: 0,
	overlapDemoted: 0,
	outOfBoxFixed: 0,
	textFitFixed: 0,
	textFloorRaised: 0,
	textFloorReverted: 0,
	canvasSharpFixed: 0,
	textClearedOfButton: 0,
	textUnderButtonSeen: 0,
	textWrapped: 0,
	labelsUntangled: 0,
	stackSeparated: 0,
	pulledIntoView: 0,
	gaveUp: 0,
	learnedUpdates: 0,
	hotChecked: 0,
	signaturesSuppressed: 0,
	smallTouchTargets: 0,
	actionsOutsideViewport: 0,
	actionsOutsideParent: 0,
	actionCollisions: 0,
	clippedActions: 0,
	geometryChanges: 0,
	dirtyDescendants: 0,
	nestedScrollConflicts: 0,
};
const MIN_TOUCH_TARGET = 44;
const INPUT_SHIELD_SHARE = 0.8;
const COLLISION_CELL = 96;
const DIRTY_DESCENDANT_CAP = 128;
const REPORT_EVERY = 60;
const FRAME_BUDGET_SECONDS = 0.0015;
// Live clients use a smaller budget; all diagnostics and bounded collision passes still run.
const IS_STUDIO = game.GetService("RunService").IsStudio();
const LIVE_BUDGET_SECONDS = 0.0005;
const TEXT_COVER_SHARE = 0.08;
const TEXT_COVER_HEIGHT = 0.3;
const tryCount = setmetatable(new Map<Instance, number>(), { __mode: "k" } as LuaMetatable<Map<Instance, number>>);
const abandoned = setmetatable(new Map<Instance, boolean>(), { __mode: "k" } as LuaMetatable<Map<Instance, boolean>>);
// Inspection priority is learned from observed defects, not from changing the UI.
const LEARN_RATE = 0.18;
const HOT_THRESHOLD = 0.3;
const HOT_CAP = 48;
const HOT_EVERY_FRAMES = 6;
const HOT_BUDGET = 8;
const THRASH_LIMIT = 3;
const MODEL_CAP = 2048;
const signatureCache = setmetatable(new Map<Instance, string>(), { __mode: "k" } as LuaMetatable<Map<Instance, string>>);
interface ModelEntry {
	p: number;
	n: number;
	thrash: number;
}
const model = new Map<string, ModelEntry>();
let modelSize = 0;
const hotList: Instance[] = [];
const hotSet = setmetatable(new Map<Instance, boolean>(), { __mode: "k" } as LuaMetatable<Map<Instance, boolean>>);
function signatureOf(inst: Instance): string {
	const cached = signatureCache.get(inst);
	if (cached !== undefined) {
		return cached;
	}
	const parent = inst.Parent;
	const signature = `${inst.ClassName}|${inst.Name}|${parent !== undefined ? parent.Name : ""}`;
	signatureCache.set(inst, signature);
	return signature;
}
function forgetWeakest() {
	let kept = 0;
	for (const [signature, entry] of model) {
		if (entry.thrash === 0 && entry.p < 0.05) {
			model.delete(signature);
		} else {
			kept += 1;
		}
	}
	if (kept >= MODEL_CAP) {
		model.clear();
		kept = 0;
	}
	modelSize = kept;
}
function entryFor(signature: string): ModelEntry {
	let entry = model.get(signature);
	if (entry === undefined) {
		if (modelSize >= MODEL_CAP) {
			forgetWeakest();
		}
		entry = { p: 0, n: 0, thrash: 0 };
		model.set(signature, entry);
		modelSize += 1;
	}
	return entry;
}
function learn(inst: Instance, repaired: boolean) {
	const entry = entryFor(signatureOf(inst));
	entry.n += 1;
	const rate = math.max(LEARN_RATE, 1 / entry.n);
	entry.p += ((repaired ? 1 : 0) - entry.p) * rate;
	stats.learnedUpdates += 1;
	if (entry.p >= HOT_THRESHOLD && !hotSet.get(inst) && hotList.size() < HOT_CAP) {
		hotSet.set(inst, true);
		hotList.push(inst);
	}
}
function suppressed(inst: Instance): boolean {
	const entry = model.get(signatureOf(inst));
	return entry !== undefined && entry.thrash >= THRASH_LIMIT;
}
function noteThrash(inst: Instance) {
	const signature = signatureOf(inst);
	const entry = entryFor(signature);
	entry.thrash += 1;
	if (entry.thrash === THRASH_LIMIT) {
		stats.signaturesSuppressed += 1;
		ClientLog.warnEvery(`layoutguard:fight:${signature}`, 120, "LayoutGuard", `${signature} keeps undoing repairs; learned to leave it alone`);
	}
}
function isFiniteNumber(value: number): boolean {
	return value === value && value !== math.huge && value !== -math.huge;
}
function rectOf(object: GuiObject | LayerCollector): Rect {
	const pos = object.AbsolutePosition;
	const size = object.AbsoluteSize;
	return {
		x0: pos.X,
		y0: pos.Y,
		x1: pos.X + size.X,
		y1: pos.Y + size.Y,
	};
}
function overlapArea(a: Rect, b: Rect): number {
	const x = math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0));
	const y = math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0));
	return x * y;
}
function rectArea(rect: Rect): number {
	return math.max(0, rect.x1 - rect.x0) * math.max(0, rect.y1 - rect.y0);
}
function engineOwns(gui: GuiObject): boolean {
	if (gui.FindFirstChildOfClass("UIFlexItem") !== undefined) {
		return true;
	}
	const parent = gui.Parent;
	if (parent === undefined) {
		return false;
	}
	for (const child of parent.GetChildren()) {
		if (child.IsA("UIListLayout") || child.IsA("UIGridLayout") || child.IsA("UIPageLayout") || child.IsA("UITableLayout")) {
			return true;
		}
	}
	return false;
}
function allowWrite(inst: Instance): boolean {
	if (!Diagnostics.canRecover(inst, "Canvas") && !Diagnostics.canRecover(inst, "FloatingPanel")) {
		return false;
	}
	if (abandoned.get(inst) || suppressed(inst)) {
		return false;
	}
	const tries = tryCount.get(inst) ?? 0;
	if (tries >= MAX_TRIES) {
		diagnostics.record(inst, "OwnerConflict", "Scoped recovery repeatedly reset by owner; further writes suppressed");
		abandoned.set(inst, true);
		stats.gaveUp += 1;
		noteThrash(inst);
		return false;
	}
	tryCount.set(inst, tries + 1);
	return true;
}
function isFloatingPanel(instance: Instance): boolean {
	return instance.IsA("Frame") && instance.Parent !== undefined && instance.Parent.IsA("LayerCollector");
}
function isTrackedClass(instance: Instance): boolean {
	let ancestor: Instance | undefined = instance;
	while (ancestor !== undefined && !ancestor.IsA("LayerCollector")) {
		if (ancestor.GetAttribute(IGNORE_ATTRIBUTE) === true) {
			return false;
		}
		ancestor = ancestor.Parent;
	}
	return instance.IsA("TextLabel") || instance.IsA("TextBox") || instance.IsA("GuiButton") || instance.IsA("CanvasGroup") || instance.IsA("ScrollingFrame") || isFloatingPanel(instance);
}
function isActionable(instance: Instance): boolean {
	return (instance.IsA("GuiButton") && instance.Active) || (instance.IsA("TextBox") && instance.TextEditable);
}
function recordViewportAction(instance: Instance, rect: Rect) {
	const layer = interactionLayer(instance);
	if (layer === undefined) {
		return;
	}
	const layerRect = rectOf(layer);
	if (Geom.overflowAmount(rect, layerRect) > FIT_SLOP) {
		if (diagnostics.record(instance, "ActionOutsideViewport", "Active control extends beyond the visible viewport")) {
			stats.actionsOutsideViewport += 1;
		}
	}
}
function clippingAncestor(instance: Instance, rect: Rect): GuiObject | undefined {
	let ancestor = instance.Parent;
	while (ancestor !== undefined && !ancestor.IsA("LayerCollector")) {
		if (ancestor.IsA("GuiObject") && ancestor.ClipsDescendants && !ancestor.IsA("ScrollingFrame")) {
			if (Geom.overflowAmount(rect, rectOf(ancestor)) > FIT_SLOP) {
				return ancestor;
			}
		}
		ancestor = ancestor.Parent;
	}
	return undefined;
}
function repairText(label: TextLabel | TextBox | TextButton): undefined {
	if (abandoned.get(label) || label.GetAttribute(IGNORE_ATTRIBUTE) === true) {
		return undefined;
	}
	if (label.Text === "" || !label.Visible) {
		return undefined;
	}
	const size = label.AbsoluteSize;
	if (size.X < 8 || size.Y < 8 || !isFiniteNumber(size.X) || !isFiniteNumber(size.Y)) {
		return undefined;
	}
	const pos = label.AbsolutePosition;
	const rect = Geom.rectFromPosSize(pos.X, pos.Y, size.X, size.Y);
	if (isActionable(label)) {
		if (UserInputService.TouchEnabled && (size.X < MIN_TOUCH_TARGET || size.Y < MIN_TOUCH_TARGET)) {
			if (diagnostics.record(label, "SmallTouchTarget", `Editable field is ${math.floor(size.X)}×${math.floor(size.Y)}px; touch fields need at least ${MIN_TOUCH_TARGET}×${MIN_TOUCH_TARGET}px`)) {
				stats.smallTouchTargets += 1;
			}
		}
		recordViewportAction(label, rect);
		const clippedBy = clippingAncestor(label, rect);
		if (clippedBy !== undefined && diagnostics.record(label, "ClippedAction", `Action exceeds clipped ancestor ${clippedBy.GetFullName()}`)) {
			stats.clippedActions += 1;
		}
	}
	if (label.TextFits) {
		tryCount.delete(label);
		return undefined;
	}
	diagnostics.record(label, "TextOverflow", `Text ${label.TextBounds.X}×${label.TextBounds.Y} exceeds box ${size.X}×${size.Y}; owner must wrap, reflow or allocate space`);
	return undefined;
}
function repairButton(button: GuiButton): undefined {
	if (button.IsA("TextButton")) {
		repairText(button);
	}
	if (abandoned.get(button) || button.GetAttribute(IGNORE_ATTRIBUTE) === true) {
		return undefined;
	}
	const pos = button.AbsolutePosition;
	const size = button.AbsoluteSize;
	if (!isFiniteNumber(size.X) || !isFiniteNumber(size.Y) || !isFiniteNumber(pos.X) || !isFiniteNumber(pos.Y)) {
		return undefined;
	}
	const rect = Geom.rectFromPosSize(pos.X, pos.Y, size.X, size.Y);
	if (isActionable(button)) {
		if (UserInputService.TouchEnabled && (size.X < MIN_TOUCH_TARGET || size.Y < MIN_TOUCH_TARGET)) {
			if (diagnostics.record(button, "SmallTouchTarget", `Active control is ${math.floor(size.X)}×${math.floor(size.Y)}px; touch controls need at least ${MIN_TOUCH_TARGET}×${MIN_TOUCH_TARGET}px`)) {
				stats.smallTouchTargets += 1;
			}
		}
		recordViewportAction(button, rect);
		const clippedBy = clippingAncestor(button, rect);
		if (clippedBy !== undefined && diagnostics.record(button, "ClippedAction", `Action exceeds clipped ancestor ${clippedBy.GetFullName()}`)) {
			stats.clippedActions += 1;
		}
	}
	const parent = button.Parent;
	if (parent === undefined || !parent.IsA("GuiObject") || parent.IsA("ScrollingFrame") || engineOwns(button)) {
		return undefined;
	}
	const pad = parent.FindFirstChildOfClass("UIPadding");
	const parentSize = parent.AbsoluteSize;
	const parentPos = parent.AbsolutePosition;
	if (!isFiniteNumber(parentSize.X) || !isFiniteNumber(parentSize.Y) || !isFiniteNumber(parentPos.X) || !isFiniteNumber(parentPos.Y)) {
		return undefined;
	}
	const left = pad !== undefined ? pad.PaddingLeft.Scale * parentSize.X + pad.PaddingLeft.Offset : 0;
	const top = pad !== undefined ? pad.PaddingTop.Scale * parentSize.Y + pad.PaddingTop.Offset : 0;
	const right = pad !== undefined ? pad.PaddingRight.Scale * parentSize.X + pad.PaddingRight.Offset : 0;
	const bottom = pad !== undefined ? pad.PaddingBottom.Scale * parentSize.Y + pad.PaddingBottom.Offset : 0;
	const box = Geom.rect(parentPos.X + left, parentPos.Y + top, parentPos.X + parentSize.X - right, parentPos.Y + parentSize.Y - bottom);
	if (Geom.rectWidth(box) < 8 || Geom.rectHeight(box) < 8) {
		return undefined;
	}
	const parentOverflow = Geom.overflowAmount(rect, box);
	if (parentOverflow <= (math.max(size.X, size.Y) < 64 ? WILD_ASPECT_SLOP : FIT_SLOP)) {
		tryCount.delete(button);
		return undefined;
	}
	if (isActionable(button) && diagnostics.record(button, "ActionOutsideParent", `Action exceeds its padded parent by ${math.ceil(parentOverflow)}px`)) {
		stats.actionsOutsideParent += 1;
	}
	return undefined;
}
function repairFloatingPanel(panel: Frame): undefined {
	if (abandoned.get(panel) || panel.GetAttribute(IGNORE_ATTRIBUTE) === true || !panel.Visible) {
		return undefined;
	}
	const layer = panel.Parent;
	if (layer === undefined || !layer.IsA("LayerCollector")) {
		return undefined;
	}
	const screen = layer.AbsoluteSize;
	const pos = panel.AbsolutePosition;
	const size = panel.AbsoluteSize;
	const layerPos = layer.AbsolutePosition;
	if (!isFiniteNumber(pos.X) || !isFiniteNumber(pos.Y) || !isFiniteNumber(size.X) || !isFiniteNumber(size.Y) || size.X < 8 || size.Y < 8) {
		return undefined;
	}
	if (size.X >= screen.X - 2 && size.Y >= screen.Y - 2) {
		return undefined;
	}
	const [x0, y0] = [pos.X - layerPos.X, pos.Y - layerPos.Y];
	const [dx, dy] = Plan.nudgeIntoView(x0, y0, x0 + size.X, y0 + size.Y, screen.X, screen.Y);
	if (math.abs(dx) < 1 && math.abs(dy) < 1) {
		tryCount.delete(panel);
		return undefined;
	}
	diagnostics.record(panel, "ViewportOverflow", `Panel exceeds viewport by ${dx}, ${dy} pixels`);
	if (!Diagnostics.canRecover(panel, "FloatingPanel")) return undefined;
	if (!allowWrite(panel)) {
		return undefined;
	}
	panel.Position = new UDim2(panel.Position.X.Scale, panel.Position.X.Offset + dx, panel.Position.Y.Scale, panel.Position.Y.Offset + dy);
	stats.pulledIntoView += 1;
	return undefined;
}
function repairScrollingFrame(descendant: ScrollingFrame): undefined {
	if (descendant.GetAttribute(IGNORE_ATTRIBUTE) === true) {
		return undefined;
	}
	if (descendant.GetAttribute("LayoutGuardAllowNestedScroll") !== true) {
		let ancestor = descendant.Parent;
		while (ancestor !== undefined && !ancestor.IsA("LayerCollector")) {
			if (ancestor.IsA("ScrollingFrame") && ancestor.ScrollingEnabled && ancestor.GetAttribute("LayoutGuardAllowNestedScroll") !== true) {
				const childDirection = descendant.ScrollingDirection;
				const parentDirection = ancestor.ScrollingDirection;
				const childX = childDirection === Enum.ScrollingDirection.X || childDirection === Enum.ScrollingDirection.XY;
				const childY = childDirection !== Enum.ScrollingDirection.X;
				const parentX = parentDirection === Enum.ScrollingDirection.X || parentDirection === Enum.ScrollingDirection.XY;
				const parentY = parentDirection !== Enum.ScrollingDirection.X;
				if ((childX && parentX) || (childY && parentY)) {
					if (diagnostics.record(descendant, "NestedScrollConflict", `Shares a scroll axis with ${ancestor.GetFullName()}`)) {
						stats.nestedScrollConflicts += 1;
					}
					break;
				}
			}
			ancestor = ancestor.Parent;
		}
	}
	let heldScroll = false;
	if (!descendant.ScrollingEnabled && descendant.GetAttribute("LayoutGuardAllowDisabledScroll") !== true) {
		heldScroll = true;
		diagnostics.record(descendant, "DisabledScroll", "Owner disabled scrolling without LayoutGuardAllowDisabledScroll");
	}
	if (descendant.AutomaticCanvasSize !== Enum.AutomaticSize.None) {
		return undefined;
	}
	let [maxBottom, maxRight] = [0, 0];
	const size = descendant.AbsoluteSize;
	const pad = descendant.FindFirstChildOfClass("UIPadding");
	const bottomPad = pad ? pad.PaddingBottom.Scale * size.Y + pad.PaddingBottom.Offset : 0;
	const rightPad = pad ? pad.PaddingRight.Scale * size.X + pad.PaddingRight.Offset : 0;
	for (const child of descendant.GetChildren()) {
		if (child.IsA("UIListLayout") || child.IsA("UIGridLayout")) {
			const layoutContentHeight = child.AbsoluteContentSize.Y;
			const layoutContentWidth = child.AbsoluteContentSize.X;
			if (isFiniteNumber(layoutContentHeight)) maxBottom = math.max(maxBottom, layoutContentHeight);
			if (isFiniteNumber(layoutContentWidth)) maxRight = math.max(maxRight, layoutContentWidth);
		} else if (child.IsA("GuiObject") && child.Visible) {
			const bottom = child.AbsolutePosition.Y - descendant.AbsolutePosition.Y + descendant.CanvasPosition.Y + child.AbsoluteSize.Y;
			const right = child.AbsolutePosition.X - descendant.AbsolutePosition.X + descendant.CanvasPosition.X + child.AbsoluteSize.X;
			if (isFiniteNumber(bottom)) maxBottom = math.max(maxBottom, bottom);
			if (isFiniteNumber(right)) maxRight = math.max(maxRight, right);
		}
	}
	if (maxBottom > 0) maxBottom += bottomPad;
	if (maxRight > 0) maxRight += rightPad;
	const direction = descendant.ScrollingDirection;
	const xScroll = direction === Enum.ScrollingDirection.X || direction === Enum.ScrollingDirection.XY;
	const yScroll = direction !== Enum.ScrollingDirection.X;
	const canvas = descendant.CanvasSize;
	const currentX = math.max(size.X, canvas.X.Scale * size.X + canvas.X.Offset);
	const currentY = math.max(size.Y, canvas.Y.Scale * size.Y + canvas.Y.Offset);
	const shortX = xScroll && currentX + 1 < maxRight;
	const shortY = yScroll && currentY + 1 < maxBottom;
	if (!shortX && !shortY) {
		if (!heldScroll) {
			tryCount.delete(descendant);
		}
		return undefined;
	}
	diagnostics.record(descendant, "CanvasOverflow", `Canvas ${currentX}×${currentY}px is shorter than content ${maxRight}×${maxBottom}px`);
	if (!Diagnostics.canRecover(descendant, "Canvas")) return undefined;
	if (!allowWrite(descendant)) {
		return undefined;
	}
	descendant.CanvasSize = new UDim2(
		shortX ? 0 : canvas.X.Scale, shortX ? math.ceil(maxRight) : canvas.X.Offset,
		shortY ? 0 : canvas.Y.Scale, shortY ? math.ceil(maxBottom) : canvas.Y.Offset,
	);
	stats.canvasDesyncFixed += 1;
	ClientLog.warnEvery(`layoutguard:canvas:${descendant.GetFullName()}`, 30, "LayoutGuard", `${descendant.Name} CanvasSize was shorter than its content; scoped recovery applied`);
	return undefined;
}
function interactionLayer(instance: Instance): LayerCollector | undefined {
	let current = instance.Parent;
	while (current !== undefined && !current.IsA("LayerCollector")) {
		current = current.Parent;
	}
	return current as LayerCollector | undefined;
}
function isAncestorOf(ancestor: Instance, instance: Instance): boolean {
	let current = instance.Parent;
	while (current !== undefined) {
		if (current === ancestor) {
			return true;
		}
		current = current.Parent;
	}
	return false;
}
interface HitItem {
	instance: GuiButton;
	rect: Rect;
	area: number;
}
function checkOverlappingHitboxes(root: Instance | Instance[]) {
	const cellSize = COLLISION_CELL || 64;
	const shieldShare = INPUT_SHIELD_SHARE || 0.8;
	const byLayer = new Map<Instance, HitItem[]>();
	const list = typeIs((root as Instance).GetDescendants, "function") ? (root as Instance).GetDescendants() : (root as Instance[]);
	for (const descendant of list) {
		coroutine.yield();
		if (descendant.Parent === undefined || !descendant.IsA("GuiButton") || !isTrackedClass(descendant)) {
			continue;
		}
		if (!Diagnostics.visible(descendant) || !descendant.Active) {
			continue;
		}
		if (descendant.GetAttribute(IGNORE_ATTRIBUTE) === true) {
			continue;
		}
		const layer = interactionLayer(descendant);
		if (layer === undefined) {
			continue;
		}
		const rect = rectOf(descendant);
		const area = rectArea(rect);
		const layerArea = rectArea(rectOf(layer));
		if (area <= 0 || (layerArea > 0 && area >= layerArea * shieldShare)) {
			continue;
		}
		let items = byLayer.get(layer);
		if (items === undefined) {
			items = [];
			byLayer.set(layer, items);
		}
		items.push({ instance: descendant, rect, area });
	}
	for (const [, items] of byLayer) {
		if (items.size() < 2) {
			continue;
		}
		const cells = new Map<string, number[]>();
		for (let index = 0; index < items.size(); index++) {
			const item = items[index];
			coroutine.yield();
			const x0 = math.floor(item.rect.x0 / cellSize);
			const x1 = math.floor((item.rect.x1 - 0.001) / cellSize);
			const y0 = math.floor(item.rect.y0 / cellSize);
			const y1 = math.floor((item.rect.y1 - 0.001) / cellSize);
			for (let x = x0; x <= x1; x++) {
				for (let y = y0; y <= y1; y++) {
					const key = `${x}:${y}`;
					let bucket = cells.get(key);
					if (bucket === undefined) {
						bucket = [];
						cells.set(key, bucket);
					}
					bucket.push(index);
				}
			}
		}
		const compared = new Set<string>();
		for (const [, bucket] of cells) {
			for (let leftSlot = 0; leftSlot < bucket.size(); leftSlot++) {
				for (let rightSlot = leftSlot + 1; rightSlot < bucket.size(); rightSlot++) {
					coroutine.yield();
					const leftIndex = bucket[leftSlot];
					const rightIndex = bucket[rightSlot];
					const pairKey = `${leftIndex}:${rightIndex}`;
					if (compared.has(pairKey)) {
						continue;
					}
					compared.add(pairKey);
					const left = items[leftIndex];
					const right = items[rightIndex];
					const a = left.instance;
					const b = right.instance;
					if (a.Parent === undefined || b.Parent === undefined || !Diagnostics.visible(a) || !Diagnostics.visible(b)) {
						continue;
					}
					if (isAncestorOf(a, b) || isAncestorOf(b, a)) {
						continue;
					}
					const overlap = overlapArea(left.rect, right.rect);
					const smaller = math.min(left.area, right.area);
					const threshold = a.Parent === b.Parent ? 0.12 : a.ZIndex === b.ZIndex ? 0.35 : 0.2;
					if (smaller <= 0 || overlap < 64 || overlap / smaller < threshold) {
						continue;
					}
					let culprit = a;
					let victim = b;
					if ((a.ZIndex ?? 1) < (b.ZIndex ?? 1)) {
						culprit = b;
						victim = a;
					}
					if (diagnostics.record(culprit, "ActionCollision", `Overlaps ${victim.GetFullName()} by ${math.floor(overlap / smaller * 100 + 0.5)}% at the same input layer`)) {
						stats.actionCollisions += 1;
					}
				}
			}
		}
	}
}
function paintsOver(button: GuiButton): boolean {
	if (button.IsA("TextButton")) {
		return (button.BackgroundTransparency ?? 0) < 0.6 || (button.Text ?? "") !== "";
	}
	if (button.IsA("ImageButton")) {
		return (button.BackgroundTransparency ?? 0) < 0.6 || ((button.Image ?? "") !== "" && (button.ImageTransparency ?? 0) < 0.6);
	}
	return false;
}
function textRectOf(label: TextLabel): Rect {
	const pos = label.AbsolutePosition;
	const size = label.AbsoluteSize;
	const bounds = label.TextBounds;
	const w = math.min(bounds.X, size.X);
	const h = math.min(bounds.Y, size.Y);
	let x0 = pos.X;
	if (label.TextXAlignment === Enum.TextXAlignment.Right) {
		x0 = pos.X + size.X - w;
	} else if (label.TextXAlignment === Enum.TextXAlignment.Center) {
		x0 = pos.X + (size.X - w) / 2;
	}
	let y0 = pos.Y;
	if (label.TextYAlignment === Enum.TextYAlignment.Bottom) {
		y0 = pos.Y + size.Y - h;
	} else if (label.TextYAlignment === Enum.TextYAlignment.Center) {
		y0 = pos.Y + (size.Y - h) / 2;
	}
	return { x0, y0, x1: x0 + w, y1: y0 + h };
}
function clearTextOfButton(label: Instance, button: Instance, _buttonRect: Rect): boolean {
	diagnostics.record(label, "TextCollision", `Text overlaps ${button.GetFullName()}; owner must reserve space`);
	return false;
}
const textPassLabels = new Map<Instance, TextLabel[]>();
const textPassButtons = new Map<Instance, GuiButton[]>();
const textPassLayerLabels = new Map<Instance, TextLabel[]>();
const textPassLayerButtons = new Map<Instance, GuiButton[]>();
function checkTextUnderButtons(list: Instance[]) {
	textPassLabels.clear();
	textPassButtons.clear();
	textPassLayerLabels.clear();
	textPassLayerButtons.clear();
	for (const inst of list) {
		coroutine.yield();
		if (inst.Parent === undefined || !isTrackedClass(inst) || !Diagnostics.visible(inst as GuiObject)) {
			continue;
		}
		const layer = interactionLayer(inst);
		if (inst.IsA("GuiButton")) {
			if (inst.Visible && paintsOver(inst) && inst.GetAttribute(IGNORE_ATTRIBUTE) !== true) {
				let bucket = textPassButtons.get(inst.Parent);
				if (bucket === undefined) {
					bucket = [];
					textPassButtons.set(inst.Parent, bucket);
				}
				bucket.push(inst);
				if (layer !== undefined) {
					let layerBucket = textPassLayerButtons.get(layer);
					if (layerBucket === undefined) {
						layerBucket = [];
						textPassLayerButtons.set(layer, layerBucket);
					}
					layerBucket.push(inst);
				}
			}
		} else if (inst.IsA("TextLabel") && inst.Visible && inst.Text !== "") {
			let bucket = textPassLabels.get(inst.Parent);
			if (bucket === undefined) {
				bucket = [];
				textPassLabels.set(inst.Parent, bucket);
			}
			bucket.push(inst);
			if (layer !== undefined) {
				let layerBucket = textPassLayerLabels.get(layer);
				if (layerBucket === undefined) {
					layerBucket = [];
					textPassLayerLabels.set(layer, layerBucket);
				}
				layerBucket.push(inst);
			}
		}
	}
	for (const [parent, labels] of textPassLabels) {
		const buttons = textPassButtons.get(parent);
		if (labels.size() > 1 && !parent.FindFirstChildWhichIsA("UIGridStyleLayout")) {
			for (let i = 0; i < labels.size(); i++) {
				const left = labels[i];
				if (left.AbsoluteSize.X < 8) {
					continue;
				}
				const leftText = textRectOf(left);
				for (let j = 0; j < labels.size(); j++) {
					coroutine.yield();
					const right = labels[j];
					if (left.Parent === undefined || right.Parent !== left.Parent || !Diagnostics.visible(left) || !Diagnostics.visible(right)) {
						continue;
					}
					if (right === left || right.AbsoluteSize.X < 8) {
						continue;
					}
					const rightText = textRectOf(right);
					if (rightText.x0 > leftText.x0 + 4 && Plan.labelsCollide(leftText, rightText)) {
						clearTextOfButton(left, right, rightText);
						break;
					}
				}
			}
		}
		if (buttons === undefined) {
			continue;
		}
		for (const label of labels) {
			const size = label.AbsoluteSize;
			if (size.X < 8 || size.Y < 8 || !isFiniteNumber(size.X) || !isFiniteNumber(size.Y)) {
				continue;
			}
			const textRect = textRectOf(label);
			const textWidth = textRect.x1 - textRect.x0;
			const textHeight = textRect.y1 - textRect.y0;
			if (textWidth <= 0 || textHeight <= 0) {
				continue;
			}
			for (const button of buttons ?? []) {
				coroutine.yield();
				if (label.Parent === undefined || button.Parent !== label.Parent || !Diagnostics.visible(label) || !Diagnostics.visible(button)) {
					continue;
				}
				if (button.ZIndex < label.ZIndex) {
					continue;
				}
				const buttonRect = rectOf(button);
				const hidden = math.max(0, math.min(textRect.x1, buttonRect.x1) - math.max(textRect.x0, buttonRect.x0));
				const shared = math.max(0, math.min(textRect.y1, buttonRect.y1) - math.max(textRect.y0, buttonRect.y0));
				if (hidden / textWidth < TEXT_COVER_SHARE || shared / textHeight < TEXT_COVER_HEIGHT) {
					continue;
				}
				stats.textUnderButtonSeen += 1;
				clearTextOfButton(label, button, buttonRect);
				break;
			}
		}
	}
	for (const [, labels] of textPassLayerLabels) {
		for (const label of labels) {
			const layer = interactionLayer(label);
			const buttons = layer !== undefined ? textPassLayerButtons.get(layer) : undefined;
			if (buttons === undefined) {
				continue;
			}
			const size = label.AbsoluteSize;
			if (size.X < 8 || size.Y < 8 || !isFiniteNumber(size.X) || !isFiniteNumber(size.Y)) {
				continue;
			}
			const textRect = textRectOf(label);
			const textWidth = textRect.x1 - textRect.x0;
			const textHeight = textRect.y1 - textRect.y0;
			if (textWidth <= 0 || textHeight <= 0) {
				continue;
			}
			for (const button of buttons) {
				coroutine.yield();
				if (label.Parent === undefined || button.Parent === undefined || button.Parent === label.Parent || !Diagnostics.visible(label) || !Diagnostics.visible(button)) {
					continue;
				}
				if (isAncestorOf(label, button) || isAncestorOf(button, label) || (button.ZIndex ?? 1) < (label.ZIndex ?? 1)) {
					continue;
				}
				const buttonRect = rectOf(button);
				const hidden = math.max(0, math.min(textRect.x1, buttonRect.x1) - math.max(textRect.x0, buttonRect.x0));
				const shared = math.max(0, math.min(textRect.y1, buttonRect.y1) - math.max(textRect.y0, buttonRect.y0));
				if (hidden / textWidth < TEXT_COVER_SHARE || shared / textHeight < TEXT_COVER_HEIGHT) {
					continue;
				}
				stats.textUnderButtonSeen += 1;
				clearTextOfButton(label, button, buttonRect);
				break;
			}
		}
	}
	textPassLayerLabels.clear();
	textPassLayerButtons.clear();
}
const SOLID_MIN_GAP = 4;
const stackPassLabels = new Map<Instance, TextLabel[]>();
const stackPassSolids = new Map<Instance, GuiObject[]>();
function isSolid(inst: Instance): boolean {
	if (!inst.IsA("GuiObject") || !inst.Visible || inst.IsA("TextLabel")) {
		return false;
	}
	if (inst.GetAttribute(IGNORE_ATTRIBUTE) === true) {
		return false;
	}
	if (inst.IsA("TextBox") || inst.IsA("GuiButton")) {
		return true;
	}
	if (inst.BackgroundTransparency < 0.9) {
		return true;
	}
	return inst.FindFirstChildWhichIsA("TextBox") !== undefined || inst.FindFirstChildWhichIsA("GuiButton") !== undefined;
}
function separateStack(label: TextLabel, solid: GuiObject): boolean {
	const textRect = textRectOf(label);
	const solidRect = rectOf(solid);
	const across = math.min(textRect.x1, solidRect.x1) - math.max(textRect.x0, solidRect.x0);
	if (across < 8) {
		return false;
	}
	const labelRect = rectOf(label);
	if (labelRect.y0 >= solidRect.y0) {
		return false;
	}
	const intrude = textRect.y1 + SOLID_MIN_GAP - solidRect.y0;
	if (intrude <= 0.5) {
		return false;
	}
	diagnostics.record(label, "StackCollision", `Text runs into ${solid.GetFullName()} by ${math.ceil(intrude)}px`);
	return true;
}
function checkStackedText(list: Instance[]) {
	stackPassLabels.clear();
	stackPassSolids.clear();
	const seen = new Set<Instance>();
	const addSolid = (solid: Instance) => {
		const parent = solid.Parent;
		if (parent === undefined || seen.has(solid) || !isSolid(solid)) {
			return;
		}
		seen.add(solid);
		let bucket = stackPassSolids.get(parent);
		if (bucket === undefined) {
			bucket = [];
			stackPassSolids.set(parent, bucket);
		}
		bucket.push(solid as GuiObject);
	};
	for (const inst of list) {
		coroutine.yield();
		const parent = inst.Parent;
		if (parent === undefined || !isTrackedClass(inst) || !Diagnostics.visible(inst as GuiObject)) {
			continue;
		}
		if (inst.IsA("TextLabel")) {
			if (inst.Visible && inst.Text !== "" && inst.GetAttribute(IGNORE_ATTRIBUTE) !== true) {
				let bucket = stackPassLabels.get(parent);
				if (bucket === undefined) {
					bucket = [];
					stackPassLabels.set(parent, bucket);
				}
				bucket.push(inst);
			}
		} else if (inst.IsA("TextBox") || inst.IsA("GuiButton")) {
			addSolid(inst);
			if (parent.IsA("Frame") && !engineOwns(inst)) {
				addSolid(parent);
			}
		}
	}
	for (const [parent, labels] of stackPassLabels) {
		const solids = stackPassSolids.get(parent);
		if (solids === undefined || parent.FindFirstChildWhichIsA("UIGridStyleLayout")) {
			continue;
		}
		for (const label of labels) {
			if (label.AbsoluteSize.X < 8 || label.AbsoluteSize.Y < 4) {
				continue;
			}
			for (const solid of solids) {
				coroutine.yield();
				if (label.Parent === undefined || solid.Parent !== label.Parent || !Diagnostics.visible(label) || !Diagnostics.visible(solid)) {
					continue;
				}
				if (separateStack(label, solid)) {
					break;
				}
			}
		}
	}
	stackPassLabels.clear();
	stackPassSolids.clear();
}
function inspect(inst: Instance) {
	const before = diagnostics.observations();
	inspectOnce(inst);
	if (inst.Parent !== undefined && inst.GetAttribute(IGNORE_ATTRIBUTE) !== true) {
		learn(inst, diagnostics.observations() > before);
	}
}
function inspectOnce(inst: Instance): undefined {
	if (inst.Parent === undefined || !isTrackedClass(inst)) {
		return undefined;
	}
	if (!Diagnostics.visible(inst as GuiObject)) return undefined;
	const size = (inst as GuiObject).AbsoluteSize;
	const pos = (inst as GuiObject).AbsolutePosition;
	const broken = !isFiniteNumber(size.X) || !isFiniteNumber(size.Y) || !isFiniteNumber(pos.X) || !isFiniteNumber(pos.Y);
	if (broken && inst.IsA("GuiObject") && inst.Visible && inst.GetAttribute(IGNORE_ATTRIBUTE) !== true) {
		diagnostics.record(inst, "InvalidGeometry", "Non-finite geometry; owner must reject invalid layout values");
		return undefined;
	}
	if (inst.IsA("ScrollingFrame")) {
		repairScrollingFrame(inst);
	} else if (isFloatingPanel(inst)) {
		repairFloatingPanel(inst as Frame);
	} else if (inst.IsA("CanvasGroup")) {
		return undefined;
	} else if (inst.IsA("GuiButton")) {
		repairButton(inst);
	} else if (inst.IsA("TextLabel") || inst.IsA("TextBox")) {
		repairText(inst);
	}
	return undefined;
}

interface UiRootComponent {
	instance: GuiObject;
}

interface ComponentsApi {
	onComponentAdded(callback: (component: UiRootComponent) => unknown, id: string): void;
	getAllComponents(id: string): UiRootComponent[];
}

interface RuntimeApi {
	primary(): UiRootComponent | undefined;
}

class LayoutGuardController {
	components: ComponentsApi;
	runtime: RuntimeApi | undefined;
	target: UiRootComponent | undefined;
	diagnosticEndpoint: BindableFunction | undefined;
	frame = 0;
	sinceSweep = 0;
	fresh: Instance[] = [];
	freshReady: number[] = [];
	freshSet = setmetatable(new Map<Instance, boolean>(), { __mode: "k" } as LuaMetatable<Map<Instance, boolean>>);
	freshScratch: Instance[] = [];
	freshReadyScratch: number[] = [];
	tracked: Instance[] = [];
	trackedIndex = setmetatable(new Map<Instance, number>(), { __mode: "k" } as LuaMetatable<Map<Instance, number>>);
	lastReportAt = os.clock();
	reportedTotal = 0;
	queue = this.tracked;
	cursor = 1;
	lastWidth = -1;
	lastHeight = -1;
	burstLeft = 0;
	armed = false;
	rootConnections: RBXScriptConnection[] = [];
	geometryConnections = setmetatable(new Map<Instance, RBXScriptConnection[]>(), { __mode: "k" } as LuaMetatable<Map<Instance, RBXScriptConnection[]>>);
	geometryReadyAt = setmetatable(new Map<Instance, number>(), { __mode: "k" } as LuaMetatable<Map<Instance, number>>);
	geometryUsers = setmetatable(new Map<Instance, number>(), { __mode: "k" } as LuaMetatable<Map<Instance, number>>);
	trackedAncestors = setmetatable(new Map<Instance, Instance[]>(), { __mode: "k" } as LuaMetatable<Map<Instance, Instance[]>>);
	layerConnections = new Map<Instance, RBXScriptConnection[]>();
	watchedLayers = new Map<Instance, boolean>();
	pendingOverlap = false;
	hotCursor = 1;
	deadline = math.huge;
	overlapPhase = 1;
	collisionWork: thread | undefined = undefined;

	constructor(components: ComponentsApi, runtime: RuntimeApi) {
		this.components = components;
		this.runtime = runtime;
	}

	hotPass(budget: number) {
		let cursor = this.hotCursor || 1;
		while (budget > 0 && hotList.size() > 0 && os.clock() < this.deadline) {
			if (cursor > hotList.size()) {
				cursor = 1;
			}
			const inst = hotList[cursor - 1];
			const entry = model.get(signatureOf(inst));
			if (inst.Parent === undefined || entry === undefined || entry.p < HOT_THRESHOLD * 0.5 || entry.thrash >= THRASH_LIMIT) {
				hotSet.delete(inst);
				hotList[cursor - 1] = hotList[hotList.size() - 1];
				hotList.pop();
			} else {
				cursor += 1;
				budget -= 1;
				if (!this.freshSet.get(inst)) {
					inspect(inst);
					stats.hotChecked += 1;
				}
			}
		}
		this.hotCursor = cursor;
	}

	onInit() {
		this.armed = true;
	}

	enqueue(instance: Instance, delay?: number): undefined {
		if (this.freshSet.get(instance) || !isTrackedClass(instance)) {
			return undefined;
		}
		if (this.fresh.size() >= Plan.FRESH_CAP) {
			return undefined;
		}
		this.freshSet.set(instance, true);
		this.fresh.push(instance);
		this.freshReady.push(this.frame + (delay ?? Plan.SETTLE_FRAMES));
		return undefined;
	}

	queueGeometryDirty(instance: Instance) {
		const now = os.clock();
		if (now < (this.geometryReadyAt.get(instance) ?? 0)) {
			return;
		}
		this.geometryReadyAt.set(instance, now + 0.2);
		stats.geometryChanges += 1;
		this.markDirty(instance);
		const parent = instance.Parent;
		if (parent !== undefined && this.trackedIndex.get(parent) !== undefined) {
			this.enqueue(parent, Plan.SETTLE_FRAMES);
		}
		let queued = 0;
		if (instance.IsA("GuiObject")) {
			for (const descendant of instance.GetDescendants()) {
				if (this.trackedIndex.get(descendant) !== undefined && !this.freshSet.get(descendant)) {
					this.enqueue(descendant, Plan.SETTLE_FRAMES);
					queued += 1;
					if (queued >= DIRTY_DESCENDANT_CAP) {
						break;
					}
				}
			}
		}
		stats.dirtyDescendants += queued;
		if (queued >= DIRTY_DESCENDANT_CAP) {
			this.sinceSweep = math.max(this.sinceSweep, Plan.MIN_SWEEP_SECONDS);
		}
		this.pendingOverlap = true;
	}

	watchGeometry(instance: Instance) {
		if (!instance.IsA("GuiObject")) {
			return;
		}
		const users = (this.geometryUsers.get(instance) ?? 0) + 1;
		this.geometryUsers.set(instance, users);
		if (this.geometryConnections.get(instance) !== undefined) {
			return;
		}
		const properties = ["Position", "Size", "Visible", "ClipsDescendants"];
		if (instance.IsA("GuiButton")) {
			properties.push("Active");
			properties.push("Rotation");
			properties.push("ZIndex");
		} else if (instance.IsA("TextLabel") || instance.IsA("TextBox")) {
			properties.push("Text");
			properties.push("TextFits");
			properties.push("TextWrapped");
			properties.push("TextScaled");
			properties.push("TextSize");
			if (instance.IsA("TextBox")) {
				properties.push("TextEditable");
			}
		} else if (instance.IsA("ScrollingFrame")) {
			properties.push("AutomaticCanvasSize");
			properties.push("CanvasPosition");
			properties.push("CanvasSize");
			properties.push("ScrollingDirection");
			properties.push("ScrollingEnabled");
		}
		const connections: RBXScriptConnection[] = [];
		for (const property of properties) {
			const [ok, signal] = pcall(() => {
				return (instance as GuiObject).GetPropertyChangedSignal(property as "Name");
			});
			if (ok && signal !== undefined) {
				connections.push(signal.Connect(() => {
					this.queueGeometryDirty(instance);
				}));
			}
		}
		this.geometryConnections.set(instance, connections);
	}

	unwatchGeometry(instance: Instance) {
		const users = this.geometryUsers.get(instance);
		if (users === undefined) {
			return;
		}
		if (users > 1) {
			this.geometryUsers.set(instance, users - 1);
			return;
		}
		this.geometryUsers.delete(instance);
		const connections = this.geometryConnections.get(instance);
		if (connections !== undefined) {
			for (const connection of connections) {
				connection.Disconnect();
			}
			this.geometryConnections.delete(instance);
		}
		this.geometryReadyAt.delete(instance);
	}

	track(instance: Instance): undefined {
		if (this.trackedIndex.get(instance) !== undefined || !isTrackedClass(instance)) {
			return undefined;
		}
		const tracked = this.tracked;
		const index = tracked.size() + 1;
		tracked[index - 1] = instance;
		this.trackedIndex.set(instance, index);
		const ancestors: GuiObject[] = [];
		let ancestor = instance.Parent;
		while (ancestor !== undefined && !ancestor.IsA("LayerCollector")) {
			if (ancestor.IsA("GuiObject")) {
				ancestors.push(ancestor);
				this.watchGeometry(ancestor);
			}
			ancestor = ancestor.Parent;
		}
		this.trackedAncestors.set(instance, ancestors);
		this.watchGeometry(instance);
		return undefined;
	}

	untrack(instance: Instance): undefined {
		const index = this.trackedIndex.get(instance);
		if (index === undefined) {
			return undefined;
		}
		const tracked = this.tracked;
		const last = tracked.size();
		const moved = tracked[last - 1];
		tracked[index - 1] = moved;
		this.trackedIndex.set(moved, index);
		tracked.pop();
		this.trackedIndex.delete(instance);
		this.unwatchGeometry(instance);
		const ancestors = this.trackedAncestors.get(instance);
		if (ancestors !== undefined) {
			for (const ancestor of ancestors) {
				this.unwatchGeometry(ancestor);
			}
			this.trackedAncestors.delete(instance);
		}
		return undefined;
	}

	releaseSubtree(instance: Instance) {
		this.untrack(instance);
		const [ok, descendants] = pcall(() => {
			return instance.GetDescendants();
		});
		if (!ok || descendants === undefined) {
			return;
		}
		for (const descendant of descendants) {
			this.untrack(descendant);
		}
	}

	markDirty(instance: Instance | undefined) {
		if (instance !== undefined) {
			tryCount.delete(instance);
			abandoned.delete(instance);
			this.enqueue(instance, Plan.SETTLE_FRAMES);
		}
	}

	watchLayer(layer: Instance): undefined {
		if (this.watchedLayers.get(layer)) {
			return undefined;
		}
		this.watchedLayers.set(layer, true);
		for (const descendant of layer.GetDescendants()) {
			this.track(descendant);
		}
		const connections: RBXScriptConnection[] = [];
		this.layerConnections.set(layer, connections);
		connections.push(layer.DescendantAdded.Connect((instance) => {
			this.track(instance);
			this.markDirty(instance);
		}));
		connections.push(layer.DescendantRemoving.Connect((instance) => {
			this.releaseSubtree(instance);
			tryCount.delete(instance);
			abandoned.delete(instance);
		}));
		return undefined;
	}

	unwatchLayer(layer: Instance) {
		const connections = this.layerConnections.get(layer);
		if (connections !== undefined) {
			for (const connection of connections) {
				connection.Disconnect();
			}
			this.layerConnections.delete(layer);
		}
		if (!this.watchedLayers.get(layer)) {
			return;
		}
		this.watchedLayers.delete(layer);
		this.releaseSubtree(layer);
	}

	bindRoot(root: GuiObject | undefined): undefined {
		if (this.diagnosticEndpoint) {
			this.diagnosticEndpoint.Destroy();
			this.diagnosticEndpoint = undefined;
		}
		if (this.layerConnections !== undefined) {
			for (const [layer] of this.layerConnections) {
				this.unwatchLayer(layer);
			}
		}
		for (const connection of this.rootConnections) {
			connection.Disconnect();
		}
		for (const [instance, connections] of this.geometryConnections) {
			for (const connection of connections) {
				connection.Disconnect();
			}
			this.geometryConnections.delete(instance);
		}
		this.rootConnections.clear();
		this.tracked.clear();
		this.trackedIndex.clear();
		this.fresh.clear();
		this.freshReady.clear();
		this.freshSet.clear();
		this.freshScratch.clear();
		this.freshReadyScratch.clear();
		if (this.geometryUsers !== undefined) this.geometryUsers.clear();
		if (this.trackedAncestors !== undefined) this.trackedAncestors.clear();
		if (this.geometryReadyAt !== undefined) this.geometryReadyAt.clear();
		this.collisionWork = undefined;
		this.layerConnections = new Map();
		this.watchedLayers = new Map();
		if (root === undefined) {
			return undefined;
		}
		this.watchLayer(root);
		const playerGui = root.FindFirstAncestorOfClass("PlayerGui");
		const endpoint = new Instance("BindableFunction");
		endpoint.Name = "AstralForgeLayoutDiagnostics";
		endpoint.OnInvoke = () => {
			return {
				Diagnostics: diagnostics.snapshot(),
				Stats: table.clone(stats),
				Tracked: this.tracked.size(),
				Fresh: this.fresh.size(),
				Cursor: this.cursor,
				PendingOverlap: this.pendingOverlap,
				OverlapPhase: this.overlapPhase,
			};
		};
		// React owns root descendants and removes children created before mounting.
		endpoint.Parent = playerGui ?? root;
		this.diagnosticEndpoint = endpoint;
		this.rootConnections.push(root.Destroying.Connect(() => {
			endpoint.Destroy();
		}));
		if (playerGui !== undefined) {
			const consider = (layer: Instance) => {
				if (layer.IsA("LayerCollector") && layer !== (root as Instance) && layer.GetAttribute(IGNORE_ATTRIBUTE) !== true) {
					this.watchLayer(layer);
				}
			};
			for (const layer of playerGui.GetChildren()) {
				consider(layer);
			}
			this.rootConnections.push(playerGui.ChildAdded.Connect(consider));
			this.rootConnections.push(playerGui.ChildRemoved.Connect((layer) => {
				this.unwatchLayer(layer);
			}));
		}
		this.rootConnections.push(root.GetPropertyChangedSignal("AbsoluteSize").Connect(() => {
			this.checkResize(root);
		}));
		this.lastWidth = -1;
		this.lastHeight = -1;
		this.checkResize(root);
		return undefined;
	}

	checkResize(root: GuiObject): boolean {
		const size = root.AbsoluteSize;
		if (!Plan.resized(this.lastWidth, this.lastHeight, size.X, size.Y)) {
			return false;
		}
		const first = this.lastWidth < 0;
		this.lastWidth = size.X;
		this.lastHeight = size.Y;
		if (!first) {
			diagnostics.reset();
			tryCount.clear();
			abandoned.clear();
			// A fight at the old size must not suppress repairs in the new layout.
			for (const [, entry] of model) {
				entry.thrash = 0;
			}
		}
		this.cursor = 1;
		this.sinceSweep = Plan.MIN_SWEEP_SECONDS;
		this.pendingOverlap = false;
		this.overlapPhase = 1;
		this.collisionWork = undefined;
		this.burstLeft = Plan.BURST_FRAMES;
		stats.bursts += 1;
		return true;
	}

	onStart() {
		this.components.onComponentAdded((component) => {
			this.target = component;
			this.bindRoot(component.instance);
			return this.target;
		}, "client/framework/init@UiRootComponent");
		const _binding = this.components.getAllComponents("client/framework/init@UiRootComponent");
		const existing = _binding[0];
		if (existing !== undefined) {
			this.target = existing;
			this.bindRoot(existing.instance);
		}
	}

	drainFresh(budget: number): undefined {
		const fresh = this.fresh;
		const ready = this.freshReady;
		if (fresh.size() === 0 || budget <= 0) {
			return undefined;
		}
		let anyDue = false;
		for (let index = 0; index < fresh.size(); index++) {
			if (ready[index] <= this.frame) {
				anyDue = true;
				break;
			}
		}
		if (!anyDue) {
			return undefined;
		}
		const keptItems = this.freshScratch;
		const keptReady = this.freshReadyScratch;
		keptItems.clear();
		keptReady.clear();
		const count = fresh.size();
		let done = 0;
		for (let index = 0; index < count; index++) {
			const instance = fresh[index];
			if (done < budget && ready[index] <= this.frame && os.clock() < this.deadline) {
				done += 1;
				this.freshSet.delete(instance);
				if (instance.Parent !== undefined) {
					inspect(instance);
					stats.freshChecked += 1;
				}
			} else {
				keptItems.push(instance);
				keptReady.push(ready[index]);
			}
		}
		for (let index = count; index < fresh.size(); index++) {
			keptItems.push(fresh[index]);
			keptReady.push(ready[index]);
		}
		this.freshScratch = fresh;
		this.freshReadyScratch = ready;
		this.fresh = keptItems;
		this.freshReady = keptReady;
		return undefined;
	}

	onTick(_dt: number): undefined {
		let _root: GuiObject | undefined = undefined;
		const target = this.target;
		if (target !== undefined) {
			_root = target.instance;
		}
		let root = _root;
		if (root === undefined && this.runtime !== undefined) {
			const primary = this.runtime.primary();
			if (primary !== undefined) {
				this.target = primary;
				root = primary.instance;
				this.bindRoot(root);
			}
		}
		if (root === undefined) {
			return undefined;
		}
		this.frame += 1;
		this.deadline = os.clock() + (IS_STUDIO ? FRAME_BUDGET_SECONDS : LIVE_BUDGET_SECONDS);
		diagnostics.beginPairs(this.deadline);
		this.sinceSweep += _dt;
		this.checkResize(root);
		const budget = Plan.budget(this.burstLeft, this.fresh.size());
		if (this.burstLeft > 0) {
			this.burstLeft -= 1;
		}
		this.drainFresh(budget.fresh);
		const tracked = this.tracked;
		if (this.cursor > tracked.size()) {
			if (this.pendingOverlap) {
				if (os.clock() >= this.deadline) {
					return undefined;
				}
				if (this.collisionWork === undefined) {
					this.collisionWork = coroutine.create(() => {
						if (this.overlapPhase === 1) {
							checkOverlappingHitboxes(this.queue);
						} else if (this.overlapPhase === 2) {
							checkTextUnderButtons(this.queue);
						} else {
							checkStackedText(this.queue);
							textPassLabels.clear();
							textPassButtons.clear();
						}
					});
				}
				if (diagnostics.runWork(this.collisionWork)) {
					this.collisionWork = undefined;
					if (this.overlapPhase === 3) this.pendingOverlap = false;
					this.overlapPhase = this.overlapPhase % 3 + 1;
				}
				this.report();
				return undefined;
			}
			if (this.sinceSweep < Plan.MIN_SWEEP_SECONDS) {
				this.report();
				return undefined;
			}
			this.sinceSweep = 0;
			this.cursor = 1;
			this.pendingOverlap = true;
			stats.scans += 1;
		}
		let sweepBudget = budget.sweep;
		while (sweepBudget > 0 && this.cursor <= tracked.size() && os.clock() < this.deadline) {
			const inst = tracked[this.cursor - 1];
			this.cursor += 1;
			sweepBudget -= 1;
			if (inst.Parent === undefined || this.freshSet.get(inst)) {
				continue;
			}
			inspect(inst);
			stats.sweepChecked += 1;
		}
		if (this.frame % HOT_EVERY_FRAMES === 0) {
			this.hotPass(HOT_BUDGET);
		}
		this.report();
		return undefined;
	}

	report(): undefined {
		const now = os.clock();
		if (now - this.lastReportAt < REPORT_EVERY) {
			return undefined;
		}
		this.lastReportAt = now;
		const total = diagnostics.total();
		if (total === this.reportedTotal) {
			return undefined;
		}
		const delta = total - this.reportedTotal;
		this.reportedTotal = total;
		ClientLog.info("LayoutGuard", `${delta} layout diagnostic${delta === 1 ? "" : "s"} in the last ${REPORT_EVERY}s; component owners retain geometry`, {
			tracked: this.tracked.size(),
			textFit: stats.textFitFixed,
			textOffButton: stats.textClearedOfButton,
			wrapped: stats.textWrapped,
			labels: stats.labelsUntangled,
			stacked: stats.stackSeparated,
			intoView: stats.pulledIntoView,
			overlap: stats.overlapDemoted,
			outOfBox: stats.outOfBoxFixed,
			gaveUp: stats.gaveUp,
			learned: modelSize,
			hot: hotList.size(),
			hotChecked: stats.hotChecked,
			fighting: stats.signaturesSuppressed,
			smallTouch: stats.smallTouchTargets,
			outsideViewport: stats.actionsOutsideViewport,
			outsideParent: stats.actionsOutsideParent,
			actionCollisions: stats.actionCollisions,
			clippedActions: stats.clippedActions,
			geometryChanges: stats.geometryChanges,
			dirtyDescendants: stats.dirtyDescendants,
			nestedScroll: stats.nestedScrollConflicts,
		});
		return undefined;
	}
}

Reflect.defineMetadata(LayoutGuardController, "identifier", "client/layoutGuard@LayoutGuardController");
Reflect.defineMetadata(LayoutGuardController, "flamework:parameters", ["$c:components@Components", "client/framework/init@UiRuntimeController"]);
Reflect.defineMetadata(LayoutGuardController, "flamework:implements", ["$:flamework@OnInit", "$:flamework@OnStart", "$:flamework@OnTick"]);
Reflect.decorate(LayoutGuardController, "$:flamework@Controller", Controller, [{ loadOrder: 10 }]);

function layoutGuardStats() {
	return stats;
}

export = {
	layoutGuardStats,
	layoutGuardDiagnostics: () => diagnostics.snapshot(),
	LayoutGuardController,
};
