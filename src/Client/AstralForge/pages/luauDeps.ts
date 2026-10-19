// Typed loaders for the client modules the page kits still reach as Luau (UiCore, LayoutKit, AudioKit,
// ArtKit, BrowseKit, ...). Each call requires at the moment it runs, exactly where the bundled Luau did,
// so load order is unchanged. Callers describe the slice of the API they use.
import React from "@rbxts/react";

export type Component = React.FunctionComponent<Record<string, unknown>>;
export type Components = { readonly [name: string]: Component };

const root = script.Parent!.Parent!;
const ReplicatedStorage = game.GetService("ReplicatedStorage");

// require(script.Parent.Parent.<kit>)("<member>")
export function luauKit<T>(kit: string, member: string): T {
	const loader = require(root.WaitForChild(kit) as ModuleScript) as (name: string) => unknown;
	return loader(member) as T;
}

// require(script.Parent.Parent.<name>)
export function luauModule<T>(name: string): T {
	return require(root.WaitForChild(name) as ModuleScript) as T;
}

// require(game.ReplicatedStorage.AstralForge.Shared.<name>)
export function sharedModule<T>(name: string): T {
	return require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild(name) as ModuleScript) as T;
}

export interface AudioApi {
	play(sound: string, ...rest: unknown[]): void;
	[key: string]: unknown;
}

export function loadAudio(): AudioApi {
	return luauKit<{ Audio: AudioApi }>("AudioKit", "audio").Audio;
}

export function loadUi(): Components {
	return luauKit<Components>("UiCore", "ui");
}

export function loadPageScaffold(): Component {
	return luauKit<{ PageScaffold: Component }>("LayoutKit", "pageScaffold").PageScaffold;
}

export interface BrowseOption<T> {
	id: string;
	label: string;
	test?: (item: T) => boolean;
	compare?: (a: T, b: T) => boolean;
	[key: string]: unknown;
}

export interface BrowseConfig<T> {
	id?: string;
	items?: ReadonlyArray<T>;
	text?: (item: T) => Array<string | undefined>;
	textKey?: unknown;
	categories?: Array<BrowseOption<T>>;
	sorts?: Array<BrowseOption<T>>;
	aliases?: unknown;
	initialQuery?: string;
	initialCategory?: string;
	initialSort?: string;
}

export interface BrowseState<T> {
	query: string;
	setQuery: (this: void, value: string) => void;
	category: string;
	setCategory: (this: void, id: string) => void;
	sort?: string;
	setSort: (this: void, id: string) => void;
	categories?: Array<BrowseOption<T>>;
	sorts?: Array<BrowseOption<T>>;
	results: T[];
	counts: Record<string, number>;
	matched: number;
	total: number;
	relevance: unknown;
	searching: boolean;
	filtered: boolean;
	firstCategory: string;
	reset: (this: void) => void;
	label: (this: void, id?: string) => string;
}

export interface BrowseApi {
	useLinkedTab(this: void, id: string, fallback: string, preferred?: string): LuaTuple<[string, (value: string) => void]>;
	useLinkedQuery(this: void, id: string, initial?: string): LuaTuple<[string, (value: string) => void]>;
	matches(this: void, query: string | undefined, ...fields: Array<string | undefined>): boolean;
	useServerNow(this: void, period?: number): number;
	untilUtcReset(this: void, now: number): number;
	shortDuration(this: void, seconds: number): string;
	barHeight(this: void, stack: boolean | undefined, hasChips: boolean | undefined): number;
	useBrowse<T>(this: void, config: BrowseConfig<T>): BrowseState<T>;
	ChipRow: Component;
	BrowseBar: Component;
	NoResults: Component;
	CHIP_H: number;
	ROW_GAP: number;
	[key: string]: unknown;
}

export function loadBrowse(): BrowseApi {
	return luauModule<BrowseApi>("BrowseKit");
}

// The react typings leave `Name` off host props (they expect keys), but the Luau pages set it
// directly so layouts and tests can find instances by name. Spread this to keep doing that.
export function named(name: string): object {
	return { Name: name };
}
