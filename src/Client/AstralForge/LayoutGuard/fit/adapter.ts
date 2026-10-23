// Roblox side of the adaptive fit engine: reads a page host into a FitContainer, applies FitKnobs
// as layout values only (UIListLayout.Padding, UIPadding top/bottom, UIGridLayout.CellSize, an
// opted-in pair's FillDirection/width) and measures the real penalty the loop verifies against.
// Base values are remembered per instance; when React re-renders a value we didn't set, that
// becomes the new base. Nothing here touches colour, text size, images or motion.
import { FitContainer, FitGrid, FitKnobs, FitPair, InputKind, MIN_TAP, gridLayout, savedBy } from "./optimizer";

const MAX_GRIDS = 6;
const MAX_PAIRS = 4;
const MAX_PENALTY_NODES = 700;
const SLACK_SAMPLE = 6;
const MIN_GAP = 6;
const MIN_PAD = 4;

interface Base<T> {
	base: T;
	applied: T | undefined;
}

export interface HostRefs {
	host: ScrollingFrame;
	list: UIListLayout | undefined;
	padding: UIPadding | undefined;
	grids: UIGridLayout[];
	pairs: Frame[];
}

const listBase = new Map<UIListLayout, Base<number>>();
const padBase = new Map<UIPadding, Base<number>>();
const gridBase = new Map<UIGridLayout, Base<UDim2>>();
const pairBase = new Map<Frame, { dir: Enum.FillDirection; sizes: Map<GuiObject, UDim2> }>();

function tracked<T>(map: Map<Instance, Base<T>>, inst: Instance, current: T): T {
	const entry = map.get(inst);
	if (entry === undefined || (entry.applied !== undefined ? entry.applied !== current : entry.base !== current)) {
		// first sight, or something other than us changed it: that's the design value now
		map.set(inst, { base: current, applied: undefined });
		return current;
	}
	return entry.base;
}

function visibleChildren(parent: Instance): GuiObject[] {
	const out: GuiObject[] = [];
	for (const child of parent.GetChildren()) {
		if (child.IsA("GuiObject") && child.Visible) out.push(child);
	}
	return out;
}

/** true when height changes inside `inst` reach the host's canvas (every ancestor auto-sizes) */
function heightReachesHost(inst: Instance, host: ScrollingFrame): boolean {
	let node: Instance | undefined = inst;
	while (node !== undefined && node !== host) {
		if (node.IsA("ScrollingFrame")) return false;
		if (node.IsA("GuiObject")) {
			const auto = node.AutomaticSize;
			if (auto !== Enum.AutomaticSize.Y && auto !== Enum.AutomaticSize.XY) return false;
		}
		node = node.Parent;
	}
	return node === host;
}

function innerWidth(frame: GuiObject): number {
	const pad = frame.FindFirstChildOfClass("UIPadding");
	const w = frame.AbsoluteSize.X;
	if (pad === undefined) return w;
	return w - pad.PaddingLeft.Offset - pad.PaddingRight.Offset - w * (pad.PaddingLeft.Scale + pad.PaddingRight.Scale);
}

function cellSlack(cell: GuiObject, cellH: number): number {
	const top = cell.AbsolutePosition.Y;
	let bottom = 0;
	let any = false;
	for (const d of cell.GetDescendants()) {
		if (d.IsA("GuiObject") && d.Visible) {
			any = true;
			bottom = math.max(bottom, d.AbsolutePosition.Y + d.AbsoluteSize.Y - top);
		}
	}
	return any ? math.max(0, cellH - bottom) : 0;
}

function hasButton(cell: GuiObject): boolean {
	if (cell.IsA("GuiButton")) return true;
	return cell.FindFirstChildWhichIsA("GuiButton", true) !== undefined;
}

export function discover(host: ScrollingFrame): HostRefs {
	const grids: UIGridLayout[] = [];
	const pairFrames: Frame[] = [];
	for (const d of host.GetDescendants()) {
		if (grids.size() < MAX_GRIDS && d.IsA("UIGridLayout")) {
			const parent = d.Parent;
			if (parent !== undefined && parent.IsA("GuiObject") && d.CellSize.X.Scale === 0 && d.CellSize.Y.Scale === 0 && heightReachesHost(d, host)) grids.push(d);
		} else if (pairFrames.size() < MAX_PAIRS && d.IsA("Frame") && d.GetAttribute("AutoFitPair") === true && d.FindFirstChildOfClass("UIListLayout") !== undefined && heightReachesHost(d, host)) {
			pairFrames.push(d);
		}
	}
	return { host, list: host.FindFirstChildOfClass("UIListLayout"), padding: host.FindFirstChildOfClass("UIPadding"), grids, pairs: pairFrames };
}

export function read(refs: HostRefs, id: string, input: InputKind, applied: FitKnobs | undefined): FitContainer {
	const host = refs.host;
	let gap = 0;
	let gapCount = 0;
	if (refs.list !== undefined && refs.list.FillDirection === Enum.FillDirection.Vertical && refs.list.Padding.Scale === 0) {
		gap = tracked(listBase as Map<Instance, Base<number>>, refs.list, refs.list.Padding.Offset);
		gapCount = math.max(0, visibleChildren(host).size() - 1);
	}
	let pad = 0;
	if (refs.padding !== undefined && refs.padding.PaddingTop.Scale === 0) {
		pad = tracked(padBase as Map<Instance, Base<number>>, refs.padding, refs.padding.PaddingTop.Offset);
	}
	const grids: FitGrid[] = [];
	for (const g of refs.grids) {
		const parent = g.Parent as GuiObject;
		const size = tracked(gridBase as Map<Instance, Base<UDim2>>, g, g.CellSize);
		const cells = visibleChildren(parent);
		let slack = math.huge;
		let tappable = false;
		for (let i = 0; i < math.min(SLACK_SAMPLE, cells.size()); i++) {
			slack = math.min(slack, cellSlack(cells[i], cells[i].AbsoluteSize.Y) + (size.Y.Offset - cells[i].AbsoluteSize.Y));
			tappable = tappable || hasButton(cells[i]);
		}
		const minW = g.GetAttribute("AutoFitMinCell");
		const minH = g.GetAttribute("AutoFitMinCellH");
		grids.push({
			width: innerWidth(parent),
			cellW: size.X.Offset,
			cellH: size.Y.Offset,
			padX: g.CellPadding.X.Offset,
			padY: g.CellPadding.Y.Offset,
			count: cells.size(),
			minCellW: typeIs(minW, "number") ? minW : math.floor(size.X.Offset * 0.85),
			minCellH: typeIs(minH, "number") ? minH : math.floor(size.Y.Offset * 0.85),
			slackH: slack === math.huge ? 0 : slack,
			tappable,
		});
	}
	const pairList: FitPair[] = [];
	for (const p of refs.pairs) {
		const kids = visibleChildren(p);
		const list = p.FindFirstChildOfClass("UIListLayout")!;
		const saved = pairBase.get(p);
		const horizontal = list.FillDirection === Enum.FillDirection.Horizontal && saved !== undefined;
		const lh = kids[0]?.AbsoluteSize.Y ?? 0;
		const rh = kids[1]?.AbsoluteSize.Y ?? 0;
		const minW = p.GetAttribute("AutoFitPairMinWidth");
		pairList.push({
			leftH: kids.size() === 2 ? lh : math.huge,
			rightH: kids.size() === 2 ? rh : math.huge,
			minW: typeIs(minW, "number") ? minW : 320,
			gap: horizontal ? list.Padding.Offset : list.Padding.Offset,
		});
	}
	const container: FitContainer = {
		id,
		windowH: host.AbsoluteWindowSize.Y,
		width: host.AbsoluteWindowSize.X,
		contentH: host.AbsoluteCanvasSize.Y,
		gap,
		gapCount,
		minGap: math.min(gap, MIN_GAP),
		pad,
		padCount: refs.padding !== undefined ? 2 : 0,
		minPad: math.min(pad, MIN_PAD),
		grids,
		pairs: pairList,
	};
	// the canvas was measured with the applied knobs; the optimiser wants it at base values
	if (applied !== undefined) container.contentH += savedBy(container, applied, input);
	return container;
}

export function apply(refs: HostRefs, k: FitKnobs, input: InputKind) {
	if (refs.list !== undefined) {
		const e = listBase.get(refs.list);
		if (e !== undefined) {
			refs.list.Padding = new UDim(0, k.gap);
			e.applied = k.gap;
		}
	}
	if (refs.padding !== undefined) {
		const e = padBase.get(refs.padding);
		if (e !== undefined) {
			refs.padding.PaddingTop = new UDim(0, k.pad);
			refs.padding.PaddingBottom = new UDim(0, k.pad);
			e.applied = k.pad;
		}
	}
	for (let i = 0; i < refs.grids.size(); i++) {
		const g = refs.grids[i];
		const e = gridBase.get(g);
		if (e === undefined) continue;
		const extra = k.extraCols[i] ?? 0;
		const step = k.heightStep[i] ?? 0;
		let size = e.base;
		if (extra !== 0 || step !== 0) {
			const parent = g.Parent as GuiObject;
			const fg: FitGrid = {
				width: innerWidth(parent),
				cellW: e.base.X.Offset,
				cellH: e.base.Y.Offset,
				padX: g.CellPadding.X.Offset,
				padY: g.CellPadding.Y.Offset,
				count: visibleChildren(parent).size(),
				minCellW: 0,
				minCellH: 0,
				slackH: math.huge,
				tappable: false,
			};
			const r = gridLayout(fg, extra, step, input);
			size = UDim2.fromOffset(r.cellW, r.cellH);
		}
		g.CellSize = size;
		e.applied = size;
	}
	for (let i = 0; i < refs.pairs.size(); i++) {
		const p = refs.pairs[i];
		const list = p.FindFirstChildOfClass("UIListLayout");
		if (list === undefined) continue;
		const kids = visibleChildren(p);
		let saved = pairBase.get(p);
		if (k.pairs[i] === true && kids.size() === 2) {
			if (saved === undefined) {
				saved = { dir: list.FillDirection, sizes: new Map() };
				for (const kid of kids) saved.sizes.set(kid, kid.Size);
				pairBase.set(p, saved);
			}
			list.FillDirection = Enum.FillDirection.Horizontal;
			const half = math.floor(list.Padding.Offset / 2);
			for (const kid of kids) kid.Size = new UDim2(0.5, -half, kid.Size.Y.Scale, kid.Size.Y.Offset);
		} else if (saved !== undefined) {
			list.FillDirection = saved.dir;
			for (const [kid, size] of saved.sizes) if (kid.Parent === p) kid.Size = size;
			pairBase.delete(p);
		}
	}
}

/** put every value back to its design base and forget it */
export function restore(refs: HostRefs) {
	if (refs.list !== undefined) {
		const e = listBase.get(refs.list);
		if (e !== undefined && e.applied !== undefined) refs.list.Padding = new UDim(0, e.base);
		listBase.delete(refs.list);
	}
	if (refs.padding !== undefined) {
		const e = padBase.get(refs.padding);
		if (e !== undefined && e.applied !== undefined) {
			refs.padding.PaddingTop = new UDim(0, e.base);
			refs.padding.PaddingBottom = new UDim(0, e.base);
		}
		padBase.delete(refs.padding);
	}
	for (const g of refs.grids) {
		const e = gridBase.get(g);
		if (e !== undefined && e.applied !== undefined) g.CellSize = e.base;
		gridBase.delete(g);
	}
	for (const p of refs.pairs) {
		const saved = pairBase.get(p);
		const list = p.FindFirstChildOfClass("UIListLayout");
		if (saved !== undefined && list !== undefined) {
			list.FillDirection = saved.dir;
			for (const [kid, size] of saved.sizes) if (kid.Parent === p) kid.Size = size;
		}
		pairBase.delete(p);
	}
}

/**
 * Measured penalty for the self-correcting loop: text that no longer fits, grid cells whose
 * content pokes out, touch targets under 44px inside adjusted grids, and an overflowing host that
 * can't scroll. Capped node walk.
 */
export function penalty(refs: HostRefs, input: InputKind): number {
	const host = refs.host;
	let p = 0;
	if (host.AbsoluteCanvasSize.Y > host.AbsoluteWindowSize.Y + 1 && !host.ScrollingEnabled) p += 5;
	let seen = 0;
	for (const d of host.GetDescendants()) {
		seen += 1;
		if (seen > MAX_PENALTY_NODES) break;
		if ((d.IsA("TextLabel") || d.IsA("TextButton")) && d.Visible && !d.TextScaled && d.TextTruncate === Enum.TextTruncate.None && d.Text !== "" && !d.TextFits) p += 1;
	}
	for (const g of refs.grids) {
		const parent = g.Parent;
		if (parent === undefined) continue;
		for (const cell of visibleChildren(parent)) {
			const top = cell.AbsolutePosition.Y;
			const bottom = top + cell.AbsoluteSize.Y;
			for (const d of cell.GetDescendants()) {
				if (d.IsA("GuiObject") && d.Visible && d.AbsolutePosition.Y + d.AbsoluteSize.Y > bottom + 1) {
					p += 1;
					break;
				}
			}
			if (input === "touch" && cell.IsA("GuiButton") && (cell.AbsoluteSize.Y < MIN_TAP - 0.5 || cell.AbsoluteSize.X < MIN_TAP - 0.5)) p += 1;
		}
	}
	return p;
}
