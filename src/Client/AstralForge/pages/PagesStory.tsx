// PagesStory.luau — compiled page bundle for the Story tab.
// Members are required lazily: PagesStory("StoryView") only pays for that page's code.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import * as InventoryMath from "../CoreKit/inventoryMath";
import { ClientLog } from "../CoreKit/log";
import { asFlux, compactNumber, formatReward } from "../CoreKit/format";
import { chromeFor, contrastOn, darken, Layout, Palette, scrollTail, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { useEntrance, useFlipperSpring, usePulse, useStagger, useViewport, useWallClock } from "../MotionKit/motion";
import { Icon, itemIconKind } from "../ArtKit/Icon";
import EchoMath = require("../../../Shared/AstralForge/Shared/EchoMath");
import { isTable, truthy } from "../lua";
import { AudioApi, Component, Components, loadAudio, loadBrowse, loadPageScaffold, loadUi, luauKit } from "./luauDeps";

const UserInputService = game.GetService("UserInputService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`PagesStory: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`PagesStory: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def);
	delete __loading[name];
	if (!ok) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

const h = React.createElement as unknown as (
	component: unknown,
	props?: Record<string, unknown> | undefined,
	...children: unknown[]
) => React.ReactElement;

type Dict = Record<string, unknown>;

const str = (value: unknown): string | undefined => (typeIs(value, "string") ? value : undefined);
const num = (value: unknown): number | undefined => (typeIs(value, "number") ? value : undefined);

__defs["StoryView"] = () => {
	const Audio = loadAudio();
	const _ui = luauKit<
		Components & {
			meterFill: (this: void, progress: unknown, target: unknown, complete?: boolean) => number;
			measureWrappedTextHeight: (
				this: void,
				text: unknown,
				width: unknown,
				size?: number,
				weight?: Enum.FontWeight,
			) => number;
		}
	>("UiCore", "ui");
	const { Badge, Button, Meter, Text, SearchField } = _ui;
	const meterFill = _ui.meterFill;
	const measureWrappedTextHeight = _ui.measureWrappedTextHeight;
	const { FlatList } = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList");
	const PageScaffold = loadPageScaffold();
	const Browse = loadBrowse();
	const CHAPTER_ROW_H = 58;
	const CHAPTER_ROW_GAP = 8;
	const CHAPTER_ROW_STRIDE = CHAPTER_ROW_H + CHAPTER_ROW_GAP;
	// @@STORY_BODY@@
	function StoryView() { return undefined as unknown as React.Element; }
	return { StoryView };
};

__defs["EchoForgeView"] = () => {
	const _ui = loadUi();
	const { Badge, Button, Dropdown, EmptyState, IconTile, Meter, Panel, SearchField, SegmentedTabs, Text } = _ui;
	const meterFill = (_ui as unknown as { meterFill: (this: void, progress: unknown, target: unknown, complete?: boolean) => number }).meterFill;
	const PageScaffold = loadPageScaffold();
	// @@ECHO_BODY@@
	function EchoForgeView() { return undefined as unknown as React.Element; }
	return { EchoForgeView };
};

__defs["InventoryView"] = () => {
	const Audio = loadAudio() as AudioApi;
	const _ui = luauKit<
		Components & {
			SCROLL_EDGE: number;
			ShimmerText: Component;
		}
	>("UiCore", "ui");
	const {
		Badge,
		Button,
		Dropdown,
		EmptyState,
		IconTile,
		Meter,
		Panel,
		SearchField,
		SectionLabel,
		SegmentedTabs,
		Text,
	} = _ui;
	const SCROLL_EDGE = _ui.SCROLL_EDGE;
	const ShimmerText = _ui.ShimmerText;
	const { FlatList } = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList");
	const PageScaffold = loadPageScaffold();
	const Browse = loadBrowse();
	// @@INVENTORY_BODY@@
	function InventoryView() { return undefined as unknown as React.Element; }
	return { InventoryView };
};

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type PagesStoryCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const PagesStory = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string): unknown => {
			return __load(name);
		},
		__index: (_self: unknown, name: string): unknown => {
			if (name === "__members") {
				return __members;
			}
			return __load(name);
		},
	} as LuaMetatable<object>,
) as unknown as PagesStoryCallable;

export = PagesStory;
