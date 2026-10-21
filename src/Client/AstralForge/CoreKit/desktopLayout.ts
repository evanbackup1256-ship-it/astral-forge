// Desktop HUD layout: the saved profile string plus a live preview while the editor is open.
// Idle cost is one selector on the saved string; the preview listener only fires while editing.
import React from "@rbxts/react";
import DesktopLayout = require("../../../Shared/AstralForge/Shared/DesktopLayout");
import { useClientSelector } from "./clientStore";

export type DesktopLayoutValues = ReturnType<typeof DesktopLayout.Defaults>;
export type DesktopLayoutPlan = ReturnType<typeof DesktopLayout.Resolve>;

let preview: DesktopLayoutValues | undefined;
let editorOpen = false;
const listeners = new Set<() => void>();

function emit() {
	for (const listener of listeners) {
		listener();
	}
}

export function setDesktopPreview(layout: DesktopLayoutValues | undefined) {
	preview = layout;
	emit();
}

export function openDesktopEditor(open: boolean) {
	if (editorOpen === open) {
		return;
	}
	editorOpen = open;
	if (!open) {
		preview = undefined;
	}
	emit();
}

function useSignal<T>(read: () => T): T {
	const [value, setValue] = React.useState(read);
	React.useEffect(() => {
		const listener = () => setValue(read());
		listeners.add(listener);
		listener();
		return () => {
			listeners.delete(listener);
		};
	}, []);
	return value;
}

export function useDesktopEditorOpen(): boolean {
	return useSignal(() => editorOpen);
}

export function useSavedDesktopLayout(): DesktopLayoutValues {
	const raw = useClientSelector((store) => (store.session as { Flags?: { DesktopLayout?: unknown } } | undefined)?.Flags?.DesktopLayout);
	return React.useMemo(() => DesktopLayout.Decode(raw), [raw]);
}

export function useDesktopLayout(): DesktopLayoutValues {
	const saved = useSavedDesktopLayout();
	const live = useSignal(() => preview);
	return live ?? saved;
}

export function useDesktopPlan(viewportWidth: number, baseNav: number, baseTop: number): DesktopLayoutPlan {
	const layout = useDesktopLayout();
	return React.useMemo(() => DesktopLayout.Resolve(layout, viewportWidth, baseNav, baseTop), [layout, viewportWidth, baseNav, baseTop]);
}

export { DesktopLayout };
