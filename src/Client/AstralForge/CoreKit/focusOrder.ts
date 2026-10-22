// Explicit gamepad focus order for a page (layout rebuild). Additive: built on the existing input layer
// (GamepadNavigationService.IsValidFocusTarget / AssignSelection); it never changes visuals or motion.
//
// A page names its regions in reading order (frame Names already in the tree: scaffold section ids,
// SplitColumns "Side"/"Main" blocks, ...). Inside a region Roblox's geometric navigation is kept;
// between regions the edge buttons are linked with NextSelectionDown/Up so the pad walks the regions
// in that order, and side/main column pairs are linked left/right. The first selection goes to the
// first valid button of the first region that has one (e.g. Crates: the Open buttons).
import React from "@rbxts/react";
import { AssignSelection, IsValidFocusTarget } from "./GamepadNavigationService";

const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");

export interface FocusPlan {
	// region frame Names, in the order the pad should visit them; "prefix*" takes every frame whose
	// Name starts with prefix (dynamic rows such as "shelf-1", "shelf-2" ...)
	regions: string[];
	// regions whose first button takes the initial selection, tried in order (default: the first
	// region of the order that has a valid button)
	first?: string[];
	// [left region, right region] pairs that sit side by side (two-column layouts)
	columns?: Array<[string, string]>;
}

function findRegions(root: Instance, name: string): Instance[] {
	if (name.sub(-1) === "*") {
		const prefix = name.sub(1, -2);
		const found: Instance[] = [];
		for (const child of root.GetDescendants()) {
			if (child.IsA("GuiObject") && child.Name.sub(1, prefix.size()) === prefix) {
				found.push(child);
			}
		}
		return found;
	}
	const single = root.Name === name ? root : root.FindFirstChild(name, true);
	return single !== undefined ? [single] : [];
}

// valid buttons of a region in reading order (top to bottom, then left to right)
function regionButtons(root: Instance, name: string, used?: Set<Instance>): GuiObject[] {
	const out: GuiObject[] = [];
	const seen = new Set<Instance>();
	for (const region of findRegions(root, name)) {
		for (const child of region.GetDescendants()) {
			if (child.IsA("GuiButton") && !seen.has(child) && !(used?.has(child) ?? false) && IsValidFocusTarget(child)) {
				seen.add(child);
				out.push(child);
			}
		}
	}
	out.sort((a, b) => {
		const ay = math.floor(a.AbsolutePosition.Y);
		const by = math.floor(b.AbsolutePosition.Y);
		return ay !== by ? ay < by : a.AbsolutePosition.X < b.AbsolutePosition.X;
	});
	return out;
}

function inside(root: Instance, object: Instance | undefined): boolean {
	return object !== undefined && (object === root || object.IsDescendantOf(root));
}

// Wires the explicit links; returns the first button of the order (undefined when none is valid).
export function applyFocusOrder(root: Instance, plan: FocusPlan): GuiObject | undefined {
	let first: GuiObject | undefined;
	const preferredBy = new Map<string, GuiObject>();
	let previous: GuiObject[] | undefined;
	const used = new Set<Instance>();
	for (const name of plan.regions) {
		const buttons = regionButtons(root, name, used);
		if (buttons.size() === 0) {
			continue;
		}
		for (const button of buttons) {
			used.add(button);
		}
		first = first ?? buttons[0];
		preferredBy.set(name, buttons[0]);
		if (previous !== undefined) {
			const tail = previous[previous.size() - 1];
			tail.NextSelectionDown = buttons[0];
			buttons[0].NextSelectionUp = tail;
		}
		previous = buttons;
	}
	for (const [leftName, rightName] of plan.columns ?? []) {
		const left = regionButtons(root, leftName);
		const right = regionButtons(root, rightName);
		if (left.size() === 0 || right.size() === 0) {
			continue;
		}
		// each left button steps right into the nearest-height main button, and back
		for (const button of left) {
			let best = right[0];
			for (const candidate of right) {
				if (math.abs(candidate.AbsolutePosition.Y - button.AbsolutePosition.Y) < math.abs(best.AbsolutePosition.Y - button.AbsolutePosition.Y)) {
					best = candidate;
				}
			}
			button.NextSelectionRight = best;
		}
		for (const button of right) {
			// only the right column's left edge steps back across
			let edge = true;
			for (const other of right) {
				if (other !== button && math.abs(other.AbsolutePosition.Y - button.AbsolutePosition.Y) < 4 && other.AbsolutePosition.X < button.AbsolutePosition.X) {
					edge = false;
					break;
				}
			}
			if (edge) {
				let best = left[0];
				for (const candidate of left) {
					if (math.abs(candidate.AbsolutePosition.Y - button.AbsolutePosition.Y) < math.abs(best.AbsolutePosition.Y - button.AbsolutePosition.Y)) {
						best = candidate;
					}
				}
				button.NextSelectionLeft = best;
			}
		}
	}
	for (const name of plan.first ?? []) {
		const preferred = preferredBy.get(name);
		if (preferred !== undefined) {
			return preferred;
		}
	}
	return first;
}

// Rewires whenever `deps` change or the page's tree changes; claims the first selection when the
// page opens (or when the current selection is gone / outside the page).
export function useFocusOrder(hostRef: React.RefObject<Instance>, plan: FocusPlan, deps: unknown[]) {
	const planRef = React.useRef(plan);
	planRef.current = plan;
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled || game.GetService("VRService").VREnabled) {
			return undefined;
		}
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		let job: thread | undefined;
		const run = (claim: boolean) => {
			if (job !== undefined) {
				return;
			}
			job = task.defer(() => {
				job = undefined;
				if (host.Parent === undefined) {
					return;
				}
				const first = applyFocusOrder(host, planRef.current);
				const current = GuiService.SelectedObject;
				// later rewires never pull the pad away from the nav bar or another page; they only recover a lost selection
				const lost = current === undefined || (inside(host, current) && !IsValidFocusTarget(current));
				if (first !== undefined && (claim || lost)) {
					AssignSelection(first);
				}
			});
		};
		run(true);
		const added = host.DescendantAdded.Connect(() => run(false));
		return () => {
			added.Disconnect();
			if (job !== undefined) {
				pcall(() => task.cancel(job!));
			}
		};
	}, deps);
}
