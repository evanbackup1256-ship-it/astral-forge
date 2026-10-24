import React from "@rbxts/react";

// Header tab slot for the shell's .hero (design .hero .tabs: bottom-right, 30px from the right, 24px from the
// bottom). A page calls useHeroTabs(<SegTabs .../>) and Workspace renders it inside the painted header; the slot
// clears when the page unmounts. Only one page is mounted at a time, so the last writer wins.
type Listener = (element: React.Element | undefined) => void;
let current: React.Element | undefined;
const listeners = new Set<Listener>();

function publish(element: React.Element | undefined) {
	current = element;
	for (const listener of listeners) {
		listener(element);
	}
}

export const HERO_TABS_RIGHT = 30;
export const HERO_TABS_BOTTOM = 24;

export function useHeroTabs(element: React.Element | undefined) {
	React.useEffect(() => {
		publish(element);
	});
	React.useEffect(() => () => publish(undefined), []);
}

export function useHeroTabSlot(): React.Element | undefined {
	const [element, setElement] = React.useState<React.Element | undefined>(current);
	React.useEffect(() => {
		listeners.add(setElement);
		setElement(current);
		return () => {
			listeners.delete(setElement);
		};
	}, []);
	return element;
}
