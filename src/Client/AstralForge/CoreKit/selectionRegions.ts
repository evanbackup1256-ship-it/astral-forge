// Gamepad selection regions for the shell. Each region (nav rail, page workspace, ...) is a
// SelectionGroup, so the D-pad stays inside it until it runs off an edge. Every region remembers
// the last thing selected in it, and leaving the nav to the right goes back to where you were on
// the page (or its first control, top-left first) instead of whatever is geometrically closest.
// Pages need no wiring: anything Selectable inside the workspace joins the page region, and kit
// Buttons already draw their own focus ring.
import { IsValidFocusTarget } from "./GamepadNavigationService";

const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");

export type RegionName = "nav" | "page";

interface Region {
	root: GuiObject;
	last?: GuiObject;
}

const regions = new Map<RegionName, Region>();
let selectionConnection: RBXScriptConnection | undefined;

function regionOf(object: Instance): RegionName | undefined {
	for (const [name, region] of regions) {
		if (object === region.root || object.IsDescendantOf(region.root)) {
			return name;
		}
	}
	return undefined;
}

/** First control in reading order: top row first, then left to right. */
export function firstTarget(root: Instance): GuiObject | undefined {
	let best: GuiObject | undefined;
	for (const child of root.GetDescendants()) {
		if (child.IsA("GuiButton") && IsValidFocusTarget(child)) {
			if (best === undefined) {
				best = child;
				continue;
			}
			const a = child.AbsolutePosition;
			const b = best.AbsolutePosition;
			// rows within 8px count as the same line
			if (a.Y < b.Y - 8 || (math.abs(a.Y - b.Y) <= 8 && a.X < b.X)) {
				best = child;
			}
		}
	}
	return best;
}

function entryFor(name: RegionName): GuiObject | undefined {
	const region = regions.get(name);
	if (region === undefined) {
		return undefined;
	}
	if (region.last !== undefined && region.last.IsDescendantOf(region.root) && IsValidFocusTarget(region.last)) {
		return region.last;
	}
	return firstTarget(region.root);
}

function onSelectionChanged() {
	const selected = GuiService.SelectedObject;
	if (selected === undefined) {
		return;
	}
	const name = regionOf(selected);
	if (name === undefined) {
		return;
	}
	regions.get(name)!.last = selected;
	if (name === "nav") {
		// D-pad right from the rail lands on the remembered page control
		const target = entryFor("page");
		pcall(() => {
			selected.NextSelectionRight = target;
		});
	}
}

function ensureListener() {
	if (selectionConnection === undefined) {
		selectionConnection = GuiService.GetPropertyChangedSignal("SelectedObject").Connect(onSelectionChanged);
	}
}

export function registerRegion(name: RegionName, root: GuiObject): () => void {
	regions.set(name, { root });
	pcall(() => {
		root.SelectionGroup = true;
		root.SelectionBehaviorLeft = Enum.SelectionBehavior.Escape;
		root.SelectionBehaviorRight = Enum.SelectionBehavior.Escape;
		// the rail is a vertical list: up/down never falls out into the top bar or the page
		const vertical = name === "nav" ? Enum.SelectionBehavior.Stop : Enum.SelectionBehavior.Escape;
		root.SelectionBehaviorUp = vertical;
		root.SelectionBehaviorDown = vertical;
	});
	ensureListener();
	return () => {
		if (regions.get(name)?.root === root) {
			regions.delete(name);
		}
		if (regions.size() === 0 && selectionConnection !== undefined) {
			selectionConnection.Disconnect();
			selectionConnection = undefined;
		}
	};
}

/** Called when the page changes: forget the old page's spot and, on a gamepad, select the new page's first control unless the player is browsing the rail. */
export function enterPage(): void {
	const region = regions.get("page");
	if (region === undefined) {
		return;
	}
	region.last = undefined;
	if (!UserInputService.GamepadEnabled || UserInputService.PreferredInput !== Enum.PreferredInput.Gamepad) {
		return;
	}
	const current = GuiService.SelectedObject;
	if (current !== undefined && regionOf(current) === "nav") {
		return;
	}
	// wait a frame so the new page has laid out
	task.defer(() => {
		const target = firstTarget(region.root);
		if (target !== undefined) {
			pcall(() => {
				GuiService.SelectedObject = target;
			});
		}
	});
}
