import React from "@rbxts/react";

const ContextActionService = game.GetService("ContextActionService");

// Gamepad B backs out of the topmost open surface (modal, chamber, sheet, dropdown) and nothing
// else. Each open surface pushes its own close; one ContextAction is bound only while the stack
// is non-empty, above the overlay pad sinks (2400) and the shell bindings (2200), so a press
// reaches the newest surface and stops there.
const ACTION = "AstralForgeBackLayer";
const PRIORITY = 2500;

interface Layer {
	close: () => void;
}

const stack: Layer[] = [];

function onBack(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult {
	if (inputState === Enum.UserInputState.Begin) {
		const top = stack[stack.size() - 1];
		if (top !== undefined) {
			top.close();
		}
	}
	return Enum.ContextActionResult.Sink;
}

function push(layer: Layer): () => void {
	stack.push(layer);
	if (stack.size() === 1) {
		ContextActionService.BindActionAtPriority(ACTION, onBack, false, PRIORITY, Enum.KeyCode.ButtonB);
	}
	return () => {
		const index = stack.indexOf(layer);
		if (index >= 0) {
			stack.remove(index);
		}
		if (stack.size() === 0) {
			ContextActionService.UnbindAction(ACTION);
		}
	};
}

/**
 * While `open`, B calls `close` if this is the topmost open surface. `close` should be the
 * surface's own close path (the one its close button uses) so exit animations play and disabled
 * states (a close button that is off right now) are respected; the press is still consumed.
 */
export function useBackLayer(open: boolean, close: () => void) {
	const latest = React.useRef(close);
	latest.current = close;
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		return push({ close: () => latest.current() });
	}, [open]);
}
