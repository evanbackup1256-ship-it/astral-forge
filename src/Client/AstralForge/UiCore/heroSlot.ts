// THE hero slot (one mechanism for groups A/B/C; replaces group A's heroTabs.ts). Page-owned parts of the
// shell's .hero (design/system af.css .hero): kicker, title, the line under it and the .tabs strip at the
// hero's bottom-right.
//   useHeroSlot(page, { kicker?, title?, line?, tabs? })  tabs = { options, value, onChange, accent? }; the
//                                                         shell draws them with MockTabs (af.css .tabs)
//   useHeroTabs(element | undefined)                      a page-built tabs element instead (group A API)
//   useHeroShown()                                        false on phone/landscape/compact: draw tabs in-page
// WorkspaceChrome reads it with useHeroFor(page) and useHeroTabElement().
import React from "@rbxts/react";

export interface HeroTabs {
	options: { id: string; label: string }[];
	value: string;
	onChange: (id: string) => void;
	accent?: Color3;
	/** @deprecated ignored: MockTabs hugs its tabs */
	width?: number;
}
export interface HeroInfo {
	kicker?: string;
	title?: string;
	line?: string;
	tabs?: HeroTabs;
}

const slots: Record<string, HeroInfo | undefined> = {};
const listeners = new Set<() => void>();
const notify = () => listeners.forEach((fn) => fn());

// only the visible parts decide whether the shell redraws; onChange is read through the stored info
function signature(info: HeroInfo | undefined): string {
	if (info === undefined) return "";
	const tabs = info.tabs;
	const labels = tabs !== undefined ? tabs.options.map((o) => `${o.id}=${o.label}`).join(",") : "";
	return `${info.kicker ?? ""}|${info.title ?? ""}|${info.line ?? ""}|${labels}|${tabs?.value ?? ""}|${tabs?.width ?? ""}|${tabs?.accent ?? ""}`;
}

export function useHeroSlot(page: string, info: HeroInfo | undefined) {
	const sig = signature(info);
	// keep the newest callbacks without redrawing the shell for them
	const stored = slots[page];
	if (stored !== undefined && info !== undefined && signature(stored) === sig) {
		slots[page] = info;
	}
	React.useEffect(() => {
		slots[page] = info;
		notify();
	}, [page, sig]);
	React.useEffect(() => {
		return () => {
			slots[page] = undefined;
			notify();
		};
	}, [page]);
}

export function useHeroFor(page: string): HeroInfo | undefined {
	const [, bump] = React.useState(0);
	React.useEffect(() => {
		const fn = () => bump((v) => v + 1);
		listeners.add(fn);
		return () => {
			listeners.delete(fn);
		};
	}, []);
	return slots[page];
}

// whether the shell is drawing the full .hero right now (wide desktop); pages draw their own .tabs otherwise
let heroShown = false;
const shownListeners = new Set<() => void>();
export function reportHeroShown(shown: boolean) {
	if (shown === heroShown) return;
	heroShown = shown;
	shownListeners.forEach((fn) => fn());
}
export function useHeroShown(): boolean {
	const [shown, setShown] = React.useState(heroShown);
	React.useEffect(() => {
		const fn = () => setShown(heroShown);
		shownListeners.add(fn);
		fn();
		return () => {
			shownListeners.delete(fn);
		};
	}, []);
	return shown;
}

// right/bottom inset of the .hero .tabs. The mockup's 30px right inset is where the shell's vault pill sits,
// so the tabs end 12px left of the pill (316px from the right).
export const HERO_TABS_RIGHT = 316 + 12;
export const HERO_TABS_BOTTOM = 24;

// page-built tabs element (group A's useHeroTabs): last writer wins, cleared on unmount
let tabElement: React.Element | undefined;
const elementListeners = new Set<(e: React.Element | undefined) => void>();
function publishElement(e: React.Element | undefined) {
	tabElement = e;
	elementListeners.forEach((fn) => fn(e));
}
export function useHeroTabs(element: React.Element | undefined) {
	React.useEffect(() => {
		publishElement(element);
	});
	React.useEffect(() => () => publishElement(undefined), []);
}
export function useHeroTabElement(): React.Element | undefined {
	const [e, setE] = React.useState<React.Element | undefined>(tabElement);
	React.useEffect(() => {
		elementListeners.add(setE);
		setE(tabElement);
		return () => {
			elementListeners.delete(setE);
		};
	}, []);
	return e;
}
