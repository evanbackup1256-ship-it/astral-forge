// Overlay core: the stack every modal, sheet and popup joins, plus the gamepad focus rules they
// share. Rendering stays with each overlay (their motion is untouched); this decides who is on top,
// who owns B, and where selection lives.
//
//   * Each open overlay pushes an entry; the top one is the only one that answers B / Esc.
//   * Modal focus is scoped with a SelectionGroup whose four SelectionBehaviors are Stop, the
//     pattern Roblox documents for popups (devforum "New Gamepad UI Selection APIs"), instead of
//     switching navigation off globally.
//   * Focus moves in when the open motion settles (useGamepadAutofocus(active, presence)), and
//     goes back to what was selected before when the overlay closes.
import React from "@rbxts/react";

const GuiService = game.GetService("GuiService");

/** Spread onto an overlay's root frame to keep gamepad selection inside it. */
export const ModalSelectionScope = {
	SelectionGroup: true,
	SelectionBehaviorUp: Enum.SelectionBehavior.Stop,
	SelectionBehaviorDown: Enum.SelectionBehavior.Stop,
	SelectionBehaviorLeft: Enum.SelectionBehavior.Stop,
	SelectionBehaviorRight: Enum.SelectionBehavior.Stop,
} as const;

/** For page panels: selection may leave at the edges toward the nav and top bar. */
export const PanelSelectionScope = {
	SelectionGroup: true,
	SelectionBehaviorUp: Enum.SelectionBehavior.Escape,
	SelectionBehaviorDown: Enum.SelectionBehavior.Escape,
	SelectionBehaviorLeft: Enum.SelectionBehavior.Escape,
	SelectionBehaviorRight: Enum.SelectionBehavior.Escape,
} as const;

export interface OverlayEntry {
	id: number;
	name: string;
	/** called when this overlay is on top and the player backs out */
	onBack?: () => void;
	/** selection to restore when this overlay closes */
	returnTo?: GuiObject;
}

const stack: OverlayEntry[] = [];
const listeners = new Set<() => void>();
let ids = 0;

function changed() {
	for (const listener of listeners) {
		listener();
	}
}

export function subscribeOverlays(listener: () => void): () => void {
	listeners.add(listener);
	return () => {
		listeners.delete(listener);
	};
}

export function overlayDepth(): number {
	return stack.size();
}

export function topOverlay(): OverlayEntry | undefined {
	return stack[stack.size() - 1];
}

/** Join the stack; returns a function that leaves it and gives selection back. */
export function pushOverlay(name: string, onBack?: () => void): () => void {
	ids += 1;
	const selected = GuiService.SelectedObject;
	const entry: OverlayEntry = { id: ids, name, onBack, returnTo: selected };
	stack.push(entry);
	changed();
	return () => {
		const index = stack.indexOf(entry);
		if (index < 0) {
			return;
		}
		const wasTop = index === stack.size() - 1;
		stack.remove(index);
		const back = entry.returnTo;
		if (wasTop && back !== undefined && back.IsDescendantOf(game) && back.Visible && back.Selectable) {
			GuiService.SelectedObject = back;
		}
		changed();
	};
}

/** B / Esc for the top overlay; true when someone handled it. */
export function backOutOfTop(): boolean {
	const top = topOverlay();
	if (top === undefined || top.onBack === undefined) {
		return false;
	}
	top.onBack();
	return true;
}

/** Join the stack while `open`; returns [depth, isTop] for z-ordering and input gating. */
export function useOverlay(name: string, open: boolean, onBack?: () => void): LuaTuple<[number, boolean]> {
	const backRef = React.useRef(onBack);
	backRef.current = onBack;
	const [, force] = React.useState(0);
	const idRef = React.useRef<number>();
	React.useEffect(() => subscribeOverlays(() => force((n) => n + 1)), []);
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const leave = pushOverlay(name, () => backRef.current?.());
		idRef.current = ids;
		return leave;
	}, [open]);
	const index = stack.findIndex((entry) => entry.id === idRef.current);
	return $tuple(index + 1, open && index >= 0 && index === stack.size() - 1);
}

/** Base ZIndex for an overlay at `depth`, so nested overlays always stack in open order. */
export function overlayZ(depth: number, base = 700): number {
	return base + math.max(0, depth - 1) * 100;
}
