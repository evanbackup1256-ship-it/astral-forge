// Typed loaders for kits that are still Luau (UiCore, LayoutKit, ArtKit, AudioKit, ...) and for
// shared Luau modules. Each loader returns the member exactly as Luau sees it; only what the pages
// use is typed. Props of Luau components are checked on the Luau side, so they take a loose bag.
import React from "@rbxts/react";

export type LuauProps = { [key: string]: unknown; children?: React.ReactNode };
export type LuauComponent = React.FunctionComponent<LuauProps>;

const root = script.Parent!.Parent!;

// require(script.Parent.Parent.<kit>)("<member>")
export function kitMember<T>(kit: string, member: string): T {
	const loader = require(root.WaitForChild(kit) as ModuleScript) as (name: string) => unknown;
	return loader(member) as T;
}

// require(script.Parent.Parent.<module>)
export function clientModule<T>(name: string): T {
	return require(root.WaitForChild(name) as ModuleScript) as T;
}

// require(ReplicatedStorage.AstralForge.Shared.<name>)
export function sharedModule<T>(name: string): T {
	return require(
		game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild(name) as ModuleScript,
	) as T;
}

// AudioKit("audio").Audio, called as Audio:play("name")
export interface AudioPlayer {
	play(name: string, ...rest: unknown[]): unknown;
	[key: string]: unknown;
}

// BrowseKit (plain module): search, category chips and sorting shared by list pages
export interface BrowseCategory<T> {
	id: string;
	label: string;
	test?: (item: T) => boolean;
	[key: string]: unknown;
}
export interface BrowseSort<T> {
	id: string;
	label: string;
	compare?: (a: T, b: T) => boolean;
}
export interface BrowseConfig<T> {
	id?: string;
	items: ReadonlyArray<T>;
	text: (item: T) => ReadonlyArray<unknown>;
	textKey?: unknown;
	categories?: ReadonlyArray<BrowseCategory<T>>;
	sorts?: ReadonlyArray<BrowseSort<T>>;
	aliases?: unknown;
	initialQuery?: string;
	initialCategory?: string;
	initialSort?: string;
}
export interface BrowseState<T> {
	query: string;
	setQuery: (query: string) => void;
	category: string;
	setCategory: (id: string) => void;
	sort?: string;
	setSort: (id: string) => void;
	results: T[];
	counts: Record<string, number>;
	matched: number;
	total: number;
	searching: boolean;
	filtered: boolean;
	firstCategory: string;
	reset: () => void;
	label: (id?: string) => string;
	[key: string]: unknown;
}
export interface BrowseApi {
	useBrowse<T>(this: void, config: BrowseConfig<T>): BrowseState<T>;
	useLinkedQuery(this: void, id: string, initial?: string): LuaTuple<[string, (query: string) => void]>;
	useLinkedTab(this: void, id: string, fallback: string, preferred?: string): LuaTuple<[string, (tab: string) => void]>;
	matches(this: void, query: string, ...fields: unknown[]): boolean;
	useServerNow(this: void, period?: number): number;
	untilUtcReset(this: void, now: number): number;
	shortDuration(this: void, seconds: number): string;
	barHeight(this: void, stack: boolean, hasChips?: boolean, chipLines?: number): number;
	CHIP_H: number;
	ChipRow: LuauComponent;
	BrowseBar: LuauComponent;
	NoResults: LuauComponent;
	[key: string]: unknown;
}
