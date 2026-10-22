// Forge2 input: one place for the B back layer, gamepad selection regions and the active input kind.
// The back layer is the shared CoreKit stack, so legacy overlays reused by Forge2 (domain chamber,
// crate reveal) and Forge2's own modals take B in the order they were opened.
import React from "@rbxts/react";
import { useBackLayer } from "../../CoreKit/backLayer";
import { activeKind, InputKind, onKindChanged } from "../../CoreKit/inputLayer";
import { enterPage, RegionName, registerRegion } from "../../CoreKit/selectionRegions";

/** While `open`, gamepad B runs `close` (the surface's own close path, so exit motion plays). */
export function useBack(open: boolean, close: () => void) {
	useBackLayer(open, close);
}

/** Registers the ref'd frame as a gamepad selection region for as long as it is mounted. */
export function useRegion(name: RegionName): React.MutableRefObject<Frame | undefined> {
	const ref = React.useRef<Frame>();
	React.useEffect(() => {
		const root = ref.current;
		if (root === undefined) return undefined;
		return registerRegion(name, root);
	}, [name]);
	return ref;
}

/** On a page change, a gamepad lands on the new page's first control. */
export function usePageEntry(page: string) {
	React.useEffect(() => {
		task.defer(enterPage);
	}, [page]);
}

export function useInputKind(): InputKind {
	const [kind, setKind] = React.useState(activeKind());
	React.useEffect(() => onKindChanged(setKind), []);
	return kind;
}
