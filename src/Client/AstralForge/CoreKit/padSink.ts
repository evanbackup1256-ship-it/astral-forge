import React from "@rbxts/react";

const ContextActionService = game.GetService("ContextActionService");

// Above the shell's gamepad bindings (2200) and the per-page ones (2300), so an open overlay
// gets these keys and nothing behind it reacts. UserInputService still sees sunk input, so an
// overlay can keep reading it there.
export const PAD_SINK_PRIORITY = 2400;

/** Sinks `keys` until the returned function is called. */
export function sinkPadInput(name: string, keys: Enum.KeyCode[], priority = PAD_SINK_PRIORITY): () => void {
	ContextActionService.BindActionAtPriority(name, () => Enum.ContextActionResult.Sink, false, priority, ...keys);
	return () => ContextActionService.UnbindAction(name);
}

/** Sinks `keys` while `active` is true (an overlay or menu that is open). */
export function usePadSink(active: boolean, name: string, keys: Enum.KeyCode[], priority = PAD_SINK_PRIORITY) {
	React.useEffect(() => {
		if (!active) {
			return undefined;
		}
		return sinkPadInput(name, keys, priority);
	}, [active, name, priority]);
}
