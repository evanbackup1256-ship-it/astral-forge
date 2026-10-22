import CompanionRelic = require("../../../../Shared/AstralForge/Shared/CompanionRelic");
import React from "@rbxts/react";
import { CompanionBondCard, companionBondHeight } from "../PagesCore/CompanionBondCard";
import { EngravingPanel, engravingPanelHeight } from "./EngravingPanel";
import { RecipeBench, recipeBenchHeight } from "./RecipeBench";
import { useTooltip } from "../../Tooltip";
import { EffectLabel } from "../../CoreKit/inventoryMath";
import ReactRoblox from "@rbxts/react-roblox";
import { counted, memoRow, sameFields } from "../../UiCore/rowMemo";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable } from "./viewRuntime";
function luaRequire(moduleScript: unknown): unknown {
	return require(moduleScript as ModuleScript) as unknown;
}
function instChild(parent: Instance, name: string): Instance {
	return (parent as unknown as Record<string, Instance>)[name];
}

const AstralForge = script.Parent!.Parent!.Parent!;

function kit(name: string, member: string): unknown {
	return luaCall(luaRequire(AstralForge.WaitForChild(name) as ModuleScript), member);
}
function mod(...names: string[]): unknown {
	let current: Instance = AstralForge;
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}
function modRel(ups: number, ...names: string[]): unknown {
	let current: Instance = script;
	for (let i = 0; i < ups; i++) {
		current = current.Parent!;
	}
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}

function __member(): unknown {
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let itemIconKind: unknown = luaProp(kit("ArtKit", "Icon"), "itemIconKind");
	let _format: unknown = kit("CoreKit", "format");
	let asFlux: unknown = luaProp(_format, "asFlux");
	let compactNumber: unknown = luaProp(_format, "compactNumber");
	let _motion: unknown = kit("MotionKit", "motion");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let useWallClock: unknown = luaProp(_motion, "useWallClock");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let Layout: unknown = luaProp(_theme, "Layout");
	let Palette: unknown = luaProp(_theme, "Palette");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	// uirevamp: inventory plates snap to the shared radius and spacing scales
	const Radius = luaProp(_theme, "Radius") as { sm: number; md: number; lg: number; card: number; sheet: number };
	const Space = luaProp(_theme, "Space") as { xs: number; sm: number; md: number; lg: number; xl: number };
	let contrastOn: unknown = luaProp(_theme, "contrastOn");
	let scrollTail: unknown = luaProp(_theme, "scrollTail");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	// wide desktop: crate and market cards sit two per row (each card keeps its own height)
	const CARD_PAIR_MIN_WIDTH = 1600;
	const pairCards = (list: unknown, idOf: (item: unknown) => unknown): unknown[] => {
		const out: defined[] = [];
		const items = (list ?? []) as unknown[];
		for (let index = 0; index < items.size(); index += 2) {
			const a = items[index];
			const b = items[index + 1];
			out.push({ Id: `${tostring(idOf(a))}|${b !== undefined ? tostring(idOf(b)) : ""}`, a, b });
		}
		return out;
	};
	const pairRow = (gap: number, a: React.Element, b: React.Element | undefined): React.Element =>
		React.createElement(
			"frame",
			{ Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false },
			React.createElement("frame", { Size: new UDim2(0.5, -math.floor(gap / 2), 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, a),
			b !== undefined
				? React.createElement("frame", { Size: new UDim2(0.5, -math.ceil(gap / 2), 1, 0), Position: new UDim2(0.5, math.ceil(gap / 2), 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, b)
				: undefined,
		);
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let InventoryMath: unknown = kit("CoreKit", "inventoryMath");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let Dropdown: unknown = luaProp(_ui, "Dropdown");
	let EmptyState: unknown = luaProp(_ui, "EmptyState");
	let IconTile: unknown = luaProp(_ui, "IconTile");
	let Meter: unknown = luaProp(_ui, "Meter");
	let Panel: unknown = luaProp(_ui, "Panel");
	let SCROLL_EDGE: unknown = luaProp(_ui, "SCROLL_EDGE");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let SectionLabel: unknown = luaProp(_ui, "SectionLabel");
	let SegmentedTabs: unknown = luaProp(_ui, "SegmentedTabs");
	let ShimmerText: unknown = luaProp(_ui, "ShimmerText");
	let Text: unknown = luaProp(_ui, "Text");
	let RELIC_ROW_SHOWN: unknown = luaCall(luaProp(React, "createBinding"), 1);
	let TABS: unknown = ["Relics", "Crates", "Market", "Recipes", "Loadout"];
	let _newValue: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(TABS));
	let _callback: unknown = function(this: void, id?: unknown): unknown | undefined {
		return { id: id, label: (string.upper as unknown as (...a: unknown[]) => unknown)(id) };
		return undefined;
	};
	for (const [_k, _v] of pairs((TABS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
		luaSetIndex(_newValue, _k, luaCall(_callback, _v, ((_k as unknown as number) - (1 as unknown as number)), TABS));
	}
	let TAB_OPTIONS: unknown = _newValue;
	let FILTERS: unknown = [{ id: "All", label: "All relics" }, { id: "Machine", label: "Machine slot" }, { id: "Research", label: "Research slot" }, { id: "Equipped", label: "Equipped only" }, { id: "Unequipped", label: "Unequipped only" }, { id: "Protected", label: "Protected only" }, { id: "Duplicates", label: "Duplicates" }, { id: "Starred", label: "Starred only" }];
	let SORTS: unknown = [{ id: "Rarity", label: "Rarity first" }, { id: "Power", label: "Highest power" }, { id: "Weakest", label: "Lowest power" }, { id: "Level", label: "Highest level" }, { id: "Newest", label: "Newest first" }, { id: "Stars", label: "Most stars" }, { id: "Salvage", label: "Salvage value" }, { id: "Name", label: "Name A-Z" }];
	let RARITY_FILTERS: unknown = [{ id: "Any", label: "Any rarity" }, { id: "Common", label: "Common" }, { id: "Uncommon", label: "Uncommon" }, { id: "Rare", label: "Rare" }, { id: "Epic", label: "Epic" }, { id: "Legendary", label: "Legendary" }, { id: "Mythic", label: "Mythic" }, { id: "Celestial", label: "Celestial" }, { id: "Astral", label: "Astral" }];
	let AUTO_RARITIES: unknown = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"];
	let HERO_H: unknown = 96;
	let HERO_H_STACK: unknown = 124;
	let ROW_GAP: unknown = 10;
	let SCROLL_PAD: unknown = ((24 as unknown as number) + (16 as unknown as number));
	let TOOL_FIELD_DESK: unknown = 50;
	let BULK_DOCK_H: unknown = 58;
	function InventoryTools(_param?: unknown): unknown | undefined {
		let search: unknown = luaProp(_param, "search");
		let setSearch: unknown = luaProp(_param, "setSearch");
		let filter: unknown = luaProp(_param, "filter");
		let setFilter: unknown = luaProp(_param, "setFilter");
		let rarity: unknown = luaProp(_param, "rarity");
		let setRarity: unknown = luaProp(_param, "setRarity");
		let sort: unknown = luaProp(_param, "sort");
		let setSort: unknown = luaProp(_param, "setSort");
		let bulkMode: unknown = luaProp(_param, "bulkMode");
		let setBulkMode: unknown = luaProp(_param, "setBulkMode");
		let autoOpen: unknown = luaProp(_param, "autoOpen");
		let setAutoOpen: unknown = luaProp(_param, "setAutoOpen");
		let equipBest: unknown = luaProp(_param, "equipBest");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let stack: unknown = luaProp(_param, "stack");
		let filled: unknown = luaProp(_param, "filled");
		let limit: unknown = luaProp(_param, "limit");
		let essence: unknown = luaProp(_param, "essence");
		let fieldH: unknown = (luaTruthy(stack) ? (math.max as unknown as (...a: unknown[]) => unknown)(TapTarget, 52) : TOOL_FIELD_DESK);
		let gap: unknown = (luaTruthy(stack) ? 8 : 10);
		let pad: unknown = (luaTruthy(stack) ? 8 : 12);
		let filterOptions: unknown = FILTERS;
		let rarityOptions: unknown = RARITY_FILTERS;
		let sortOptions: unknown = SORTS;
		let bagW: unknown = (luaTruthy(stack) ? 100 : 104);
		let essW: unknown = (luaTruthy(stack) ? 112 : 116);
		let metaW: unknown = ((((bagW as unknown as number) + (essW as unknown as number)) as unknown as number) + (gap as unknown as number));
		let filterH: unknown = (luaTruthy(stack) ? ((((fieldH as unknown as number) * (2 as unknown as number)) as unknown as number) + (gap as unknown as number)) : fieldH);
		let actionW: unknown = new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), (-((math.ceil as unknown as (...a: unknown[]) => unknown)((((((gap as unknown as number) * (2 as unknown as number))) as unknown as number) / (3 as unknown as number))) as unknown as number)), 0, fieldH);
		let accent: unknown = (luaTruthy(bulkMode) ? luaProp(Palette, "coral") : (luaTruthy(autoOpen) ? luaProp(Palette, "mango") : luaProp(Palette, "violet")));
		let bagBadge: unknown = reactLoose.createElement(Badge, { value: `${filled} / ${limit} BAG`, accent: luaProp(Palette, "violet"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), bagW, 26) });
		let essBadge: unknown = reactLoose.createElement(Badge, { value: `${luaCall(compactNumber, essence)} ESS`, accent: luaProp(Palette, "mango"), size: luaCall(luaProp(UDim2, "fromOffset"), essW, 26) });
		return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: accent, Thickness: 1, Transparency: 0.5 }), reactLoose.createElement("uipadding", { PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, pad), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, pad), PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, ((pad as unknown as number) + (2 as unknown as number))), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, ((pad as unknown as number) + (2 as unknown as number))) }), reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, gap) }), ((luaTruthy(stack ) ?  reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 26), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, gap), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), bagBadge, essBadge) : stack)), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, filterH), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 1, ClipsDescendants: false }, (luaTruthy(stack) ? reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(SearchField, { value: search, onChange: setSearch, placeholder: "Search relics, effects, or ID", accent: luaProp(Palette, "violet"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, fieldH), reducedMotion: reducedMotion, zIndex: 62 }), reactLoose.createElement(Dropdown, { options: filterOptions, value: filter, onChange: setFilter, accent: luaProp(Palette, "violet"), position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((fieldH as unknown as number) + (gap as unknown as number))), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), -6, 0, fieldH), reducedMotion: reducedMotion, zIndex: 61 }), reactLoose.createElement(Dropdown, { options: rarityOptions, value: rarity, onChange: setRarity, accent: luaProp(Palette, "mango"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), 2, 0, ((fieldH as unknown as number) + (gap as unknown as number))), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), -6, 0, fieldH), reducedMotion: reducedMotion, zIndex: 60 }), reactLoose.createElement(Dropdown, { options: sortOptions, value: sort, onChange: setSort, accent: luaProp(Palette, "cyan"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((2 as unknown as number) / (3 as unknown as number)), 4, 0, ((fieldH as unknown as number) + (gap as unknown as number))), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (3 as unknown as number)), -4, 0, fieldH), reducedMotion: reducedMotion, zIndex: 59 })) : reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), metaW, fieldH), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, gap), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), bagBadge, essBadge), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((metaW as unknown as number) + (gap as unknown as number))) as unknown as number)), 0, fieldH), Position: luaCall(luaProp(UDim2, "fromOffset"), ((metaW as unknown as number) + (gap as unknown as number)), 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(SearchField, { value: search, onChange: setSearch, placeholder: "Search relics, effects, or ID", accent: luaProp(Palette, "violet"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.4, -6, 0, fieldH), reducedMotion: reducedMotion, zIndex: 62 }), reactLoose.createElement(Dropdown, { options: filterOptions, value: filter, onChange: setFilter, accent: luaProp(Palette, "violet"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.4, 0, 0, 0), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -6, 0, fieldH), reducedMotion: reducedMotion, zIndex: 61 }), reactLoose.createElement(Dropdown, { options: rarityOptions, value: rarity, onChange: setRarity, accent: luaProp(Palette, "mango"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.6, 0, 0, 0), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, -6, 0, fieldH), reducedMotion: reducedMotion, zIndex: 60 }), reactLoose.createElement(Dropdown, { options: sortOptions, value: sort, onChange: setSort, accent: luaProp(Palette, "cyan"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.8, 0, 0, 0), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.2, 0, 0, fieldH), reducedMotion: reducedMotion, zIndex: 59 }))))), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, fieldH), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 2, ClipsDescendants: false }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, gap), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Button, { text: (luaTruthy(stack) ? "BEST" : "EQUIP BEST"), icon: "Loadout.2", onClick: equipBest, color: luaProp(Palette, "mint"), textColor: luaProp(Palette, "ink"), size: actionW, reducedMotion: reducedMotion, highlight: true }), reactLoose.createElement(Button, { text: (luaTruthy(bulkMode) ? "DONE" : (luaTruthy(stack) ? "SELECT" : "MULTI SALVAGE")), icon: (luaTruthy(bulkMode) ? "Check.18" : "Dust.5"), onClick: function(this: void): unknown | undefined {
			luaCall(setBulkMode, (!luaTruthy(bulkMode)));
			luaCall(setAutoOpen, false);
			return undefined;
		}, color: (luaTruthy(bulkMode) ? luaProp(Palette, "coral") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(bulkMode) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), size: actionW, reducedMotion: reducedMotion, outline: (!luaTruthy(bulkMode)) }), reactLoose.createElement(Button, { text: (luaTruthy(stack) ? "RECYCLE" : "AUTO-SALVAGE"), icon: "Inventory.5", onClick: function(this: void): unknown | undefined {
			luaCall(setAutoOpen, (!luaTruthy(autoOpen)));
			luaCall(setBulkMode, false);
			return undefined;
		}, color: (luaTruthy(autoOpen) ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(autoOpen) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), size: actionW, reducedMotion: reducedMotion, outline: (!luaTruthy(autoOpen)) })));
		return undefined;
	}
	function BulkDock(_param?: unknown): unknown | undefined {
		let selectedCount: unknown = luaProp(_param, "selectedCount");
		let selectableCount: unknown = luaProp(_param, "selectableCount");
		let selectionEssence: unknown = luaProp(_param, "selectionEssence");
		let selectVisible: unknown = luaProp(_param, "selectVisible");
		let clearSelection: unknown = luaProp(_param, "clearSelection");
		let salvageSelected: unknown = luaProp(_param, "salvageSelected");
		let bulkBusy: unknown = luaProp(_param, "bulkBusy");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, ZIndex: 30, ClipsDescendants: false }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: luaProp(Palette, "coral"), Thickness: 1, Transparency: 0.5 }), reactLoose.createElement("uipadding", { PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), reactLoose.createElement(Button, { text: (((selectableCount as unknown as number) > (0 as unknown as number)) ? `Select ${(math.min as unknown as (...a: unknown[]) => unknown)(25, selectableCount)}` : "Nothing to pick"), icon: "Check.19", onClick: selectVisible, color: luaProp(Palette, "violet"), textColor: luaProp(Palette, "cream"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.42, -4, 1, 0), reducedMotion: reducedMotion, disabled: (selectableCount === 0), outline: true }), reactLoose.createElement(Button, { text: (luaTruthy(bulkBusy) ? "Salvaging" : ((((selectedCount as unknown as number) > (0 as unknown as number)) && luaTruthy(luaProp(_param, "bulkArmed"))) ? `Tap again · salvage ${selectedCount}` : (((selectedCount as unknown as number) > (0 as unknown as number)) ? `Salvage ${selectedCount}  +${luaCall(compactNumber, selectionEssence)} essence` : "Clear"))), icon: "Dust.6", onClick: (((selectedCount as unknown as number) > (0 as unknown as number)) ? salvageSelected : clearSelection), color: (((selectedCount as unknown as number) > (0 as unknown as number)) ? luaProp(Palette, "coral") : luaProp(Palette, "panelSoft")), textColor: (((selectedCount as unknown as number) > (0 as unknown as number)) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.58, -4, 1, 0), reducedMotion: reducedMotion, disabled: bulkBusy, highlight: ((selectedCount as unknown as number) > (0 as unknown as number)) }));
		return undefined;
	}
	function AutoSalvageSheet(_param?: unknown): unknown | undefined {
		let passOwned: unknown = luaProp(_param, "passOwned");
		let rules: unknown = luaProp(_param, "rules");
		let updateRules: unknown = luaProp(_param, "updateRules");
		let autoBusy: unknown = luaProp(_param, "autoBusy");
		let openShop: unknown = luaProp(_param, "openShop");
		let runNow: unknown = luaProp(_param, "runNow");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let stack: unknown = luaProp(_param, "stack");
		let config: unknown = luaProp(_param, "config");
		let onClose: unknown = luaProp(_param, "onClose");
		let sheetHostRef: unknown = reactLoose.useRef(undefined);
		let fieldH: unknown = (luaTruthy(stack) ? (math.max as unknown as (...a: unknown[]) => unknown)(TapTarget, 52) : TOOL_FIELD_DESK);
		let rarityH: unknown = (luaTruthy(stack) ? TapTarget : 36);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(luaProp(GamepadNavigationService, "BeginOverlayFocus"));
			return function(this: void): unknown | undefined {
				luaCall(luaProp(GamepadNavigationService, "EndOverlayFocus"));
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!luaTruthy(luaProp(UserInputService, "GamepadEnabled")))) {
				return undefined;
			}
			let host: unknown = luaProp(sheetHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let selectJob: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if ((luaProp(host, "Parent") === undefined)) {
					return;
				}
				luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), selectJob);
				return undefined;
			};
			return undefined;
		}, [passOwned, autoBusy]);
		let toggleAutoRarity: unknown = function(this: void, entry?: unknown): unknown | undefined {
			if ((entry === "Any")) {
				return undefined;
			}
			let updated: unknown = {};
			for (const [key, value] of pairs((luaProp(rules, "Rarities")) as object)) {
				luaSetIndex(updated, key, value);
			}
			if ((luaIndex(luaProp(rules, "Rarities"), entry) === true)) {
				let _entry: unknown = entry;
				luaSetIndex(updated, _entry, undefined);
			} else {
				let _entry: unknown = entry;
				luaSetIndex(updated, _entry, true);
			}
			let packed: unknown = {};
			let _callback_1: unknown = function(this: void, value?: unknown, key?: unknown): unknown | undefined {
				luaSetIndex(packed, key, value);
				return undefined;
			};
			for (const [_k, _v] of pairs((updated) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaCall(_callback_1, _v, _k, updated);
			}
			let _object: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(rules);
			setmetatable(_object as object, undefined as unknown as LuaMetatable<object>);
			luaSet(_object, "Rarities", packed);
			luaCall(updateRules, _object);
			return undefined;
		};
		let _exp: unknown = reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, Radius.sheet) });
		let _exp_1: unknown = reactLoose.createElement("uistroke", { ApplyStrokeMode: luaProp(luaProp(Enum, "ApplyStrokeMode"), "Border"), LineJoinMode: luaProp(luaProp(Enum, "LineJoinMode"), "Round"), Color: (luaTruthy(passOwned) ? luaProp(Palette, "mango") : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: 0.4 });
		let _exp_2: unknown = reactLoose.createElement("uipadding", { PaddingTop: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingBottom: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingLeft: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10), PaddingRight: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) });
		let _exp_3: unknown = reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) });
		let _exp_4: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 0 }, reactLoose.createElement(Text, { value: "Auto-salvage", size: 12, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -44, 1, 0) }), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 28, 28), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -28, 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement(Button, { text: "", icon: "Close.7", onClick: onClose, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: reducedMotion })));
		let _result: unknown;
		if ((!luaTruthy(passOwned))) {
			_result = reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Text, { value: "Pick rarities once. Later crate drops of those rarities turn into essence.", size: 11, color: luaProp(Palette, "creamSoft"), wrap: true, layoutOrder: 1, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(stack) ? 32 : 18)) }), reactLoose.createElement(Button, { text: "View pass", icon: "Shop.10", onClick: openShop, color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 132, TapTarget)), reducedMotion: reducedMotion, highlight: true }));
		} else {
			let _exp_5: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, fieldH), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 1, ClipsDescendants: false }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Button, { text: (luaTruthy(autoBusy) ? "Saving" : (luaTruthy(luaProp(rules, "Enabled")) ? "ON" : "Off")), icon: (luaTruthy(luaProp(rules, "Enabled")) ? "Check.20" : "Inventory.6"), onClick: function(this: void): unknown | undefined {
				let _object: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(rules);
				setmetatable(_object as object, undefined as unknown as LuaMetatable<object>);
				luaSet(_object, "Enabled", (!luaTruthy(luaProp(rules, "Enabled"))));
				return luaCall(updateRules, _object);
				return undefined;
			}, color: (luaTruthy(luaProp(rules, "Enabled")) ? luaProp(Palette, "mint") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(luaProp(rules, "Enabled")) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.28, -6, 0, fieldH), reducedMotion: reducedMotion, disabled: autoBusy, outline: (!luaTruthy(luaProp(rules, "Enabled"))) }), reactLoose.createElement(Button, { text: (luaTruthy(luaProp(rules, "KeepNew")) ? "Keep new" : "Recycle new"), icon: (luaTruthy(luaProp(rules, "KeepNew")) ? "Lock.12" : "Dust.7"), onClick: function(this: void): unknown | undefined {
				let _object: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(rules);
				setmetatable(_object as object, undefined as unknown as LuaMetatable<object>);
				luaSet(_object, "KeepNew", (!luaTruthy(luaProp(rules, "KeepNew"))));
				return luaCall(updateRules, _object);
				return undefined;
			}, color: (luaTruthy(luaProp(rules, "KeepNew")) ? luaProp(Palette, "violet") : luaProp(Palette, "coral")), textColor: (luaTruthy(luaProp(rules, "KeepNew")) ? luaProp(Palette, "cream") : luaProp(Palette, "ink")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.44, -6, 0, fieldH), reducedMotion: reducedMotion, disabled: autoBusy, outline: true }), reactLoose.createElement(Button, { text: "Run", icon: "Dust.8", onClick: runNow, color: luaProp(Palette, "mango"), textColor: luaProp(Palette, "ink"), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.28, -6, 0, fieldH), reducedMotion: reducedMotion, disabled: ((luaTruthy(autoBusy ) ? autoBusy :  (!luaTruthy(luaProp(rules, "Enabled"))))), highlight: luaProp(rules, "Enabled") }));
			let _newValue_1: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(AUTO_RARITIES));
			let _callback_1: unknown = function(this: void, entry?: unknown, index?: unknown): unknown | undefined {
				let active: unknown = (luaIndex(luaProp(rules, "Rarities"), entry) === true);
				let cols: unknown = (luaTruthy(stack) ? 3 : 6);
				let col: unknown = ((index as unknown as number) % (cols as unknown as number));
				let row: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((index as unknown as number) / (cols as unknown as number)));
				let label: unknown = ((luaTruthy(stack) && (entry === "Legendary")) ? "Legend" : entry);
				return reactLoose.createElement(Button, { key: entry, text: label, onClick: function(this: void): unknown | undefined {
					return luaCall(toggleAutoRarity, entry);
					return undefined;
				}, color: (luaTruthy(active) ? luaCall(luaProp(InventoryMath, "RarityColor"), config, entry, luaProp(Palette, "muted")) : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(active) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((col as unknown as number) / (cols as unknown as number)), ((col === 0) ? 0 : 4), 0, ((row as unknown as number) * ((((rarityH as unknown as number) + (8 as unknown as number))) as unknown as number))), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (cols as unknown as number)), -6, 0, rarityH), reducedMotion: reducedMotion, disabled: autoBusy, outline: (!luaTruthy(active)) });
				return undefined;
			};
			for (const [_k, _v] of pairs((AUTO_RARITIES) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue_1, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), AUTO_RARITIES));
			}
			_result = reactLoose.createElement(React.Fragment, undefined, _exp_5, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(stack) ? ((((rarityH as unknown as number) * (2 as unknown as number)) as unknown as number) + (8 as unknown as number)) : rarityH)), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 2, ClipsDescendants: false }, _newValue_1));
		}
		return reactLoose.createElement("frame", { ref: sheetHostRef, Name: "AutoSalvageSheet", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 40, ClipsDescendants: false }, reactLoose.createElement("frame", { Name: "AutoSalvageClaim", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, 0), Position: luaCall(luaProp(UDim2, "fromOffset"), 4, 6), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "Y"), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, ZIndex: 41, ClipsDescendants: false }, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _result));
		return undefined;
	}
	function RelicRow(_param?: unknown): unknown | undefined {
		let item: unknown = luaProp(_param, "item");
		let config: unknown = luaProp(_param, "config");
		let selected: unknown = luaProp(_param, "selected");
		let bulkSelected: unknown = luaProp(_param, "bulkSelected");
		let bulkMode: unknown = luaProp(_param, "bulkMode");
		let onSelect: unknown = luaProp(_param, "onSelect");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let y: unknown = luaProp(_param, "y");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		if ((layoutOrder === undefined)) {
			layoutOrder = 0;
		}
		let stack: unknown = luaProp(_param, "stack");
		if ((stack === undefined)) {
			stack = false;
		}
		let accent: unknown = luaCall(luaProp(InventoryMath, "RarityColor"), config, luaProp(luaProp(item, "definition"), "Rarity"), luaProp(Palette, "muted"));
		// rarity polish: a faint rarity wash on the row and a rarity-tinted name (falls back to cream)
		let rarityTint: Color3 = typeIs(accent, "Color3") ? accent : (luaProp(Palette, "cream") as Color3);
		let textW: unknown = (luaTruthy(stack) ? (-((((58 as unknown as number) + (8 as unknown as number))) as unknown as number)) : -176);
		let locked: unknown = (luaProp(luaProp(item, "instance"), "Locked") === true);
		let height: unknown = luaCall(luaProp(InventoryMath, "RelicRowHeight"), stack);
		const relicDef = luaProp(item, "definition") as { Name?: string; Rarity?: string; Description?: string; Slot?: string } | undefined;
		const relicInst = luaProp(item, "instance") as { Level?: number; Stars?: number } | undefined;
		const equippedOn = luaProp(item, "equippedOn");
		const tip = useTooltip({
			title: `${relicDef?.Name ?? "Relic"} · ${relicDef?.Rarity ?? "Common"}`,
			body: `${EffectLabel(relicDef, relicInst?.Level, relicInst?.Stars)} · ${relicDef?.Slot ?? "Machine"} slot`,
			hint: equippedOn !== undefined ? "Socketed now." : locked ? "Protected from salvage." : undefined,
			accent: rarityTint,
		});
		return reactLoose.createElement("imagebutton", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, height), Position: ((y !== undefined) ? luaCall(luaProp(UDim2, "fromOffset"), 0, y) : undefined), LayoutOrder: layoutOrder, BackgroundTransparency: 1, BorderSizePixel: 0, AutoButtonColor: false, Active: true, Selectable: true, Event: { Activated: function(this: void): unknown | undefined {
			colon(Audio).play("tick");
			luaCall(onSelect);
			return undefined;
		}, MouseEnter: function(this: void, rbx: GuiObject): unknown | undefined {
			tip.MouseEnter(rbx);
			return colon(Audio).play("hover");
		}, SelectionGained: function(this: void, rbx: GuiObject): unknown | undefined {
			tip.SelectionGained(rbx);
			return colon(Audio).play("hover");
		}, MouseLeave: tip.MouseLeave, SelectionLost: tip.SelectionLost, InputBegan: tip.InputBegan, InputEnded: tip.InputEnded } }, reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: (luaTruthy(bulkSelected) ? luaProp(Palette, "coral") : accent), background: (((luaTruthy(selected) || luaTruthy(bulkSelected)) ? luaProp(Palette, "panelRaised") : luaProp(Palette, "panel")) as Color3).Lerp(rarityTint.Lerp(new Color3(0, 0, 0), 0.78), 0.18), padding: (luaTruthy(stack) ? Space.md : Space.lg), interactive: true, highlight: ((luaTruthy(selected ) ? selected :  bulkSelected)), reducedMotion: reducedMotion, reveal: RELIC_ROW_SHOWN, clips: true }, reactLoose.createElement(IconTile, { kind: luaCall(itemIconKind, luaProp(luaProp(item, "instance"), "DefinitionId"), luaProp(luaProp(item, "definition"), "Slot")), accent: accent, size: (luaTruthy(stack) ? 44 : 46), radius: Radius.md, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 4 : 8)), reducedMotion: reducedMotion, glow: selected }), reactLoose.createElement(Text, { value: luaProp(luaProp(item, "definition"), "Name"), size: (luaTruthy(stack) ? 15 : 16), color: (luaProp(Palette, "cream") as Color3).Lerp(rarityTint, 0.22), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 12, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textW, 0, 22) }), reactLoose.createElement(Text, { value: `${luaProp(luaProp(item, "definition"), "Description")}  ·  ${luaCall(luaProp(InventoryMath, "EffectLabel"), luaProp(item, "definition"), luaProp(luaProp(item, "instance"), "Level"), luaProp(luaProp(item, "instance"), "Stars"))}`, size: 11, color: accent, wrap: false, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textW, 0, 18) }), reactLoose.createElement(Text, { value: ((luaProp(item, "equippedOn") !== undefined) ? `On ${luaCall(luaProp(InventoryMath, "SocketLabel"), luaProp(item, "equippedOn"))}` : (luaTruthy(locked) ? "Protected" : "")), size: 11, color: ((luaProp(item, "equippedOn") !== undefined) ? luaProp(Palette, "mint") : (luaTruthy(locked) ? luaProp(Palette, "mango") : luaProp(Palette, "creamSoft"))), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 58, 44), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textW, 0, 16) }), reactLoose.createElement("frame", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((58 as unknown as number) + (8 as unknown as number))) as unknown as number)), 0, 22) : luaCall(luaProp(UDim2, "fromOffset"), 84, 86)), Position: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 58, 68) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -84, 0, 4)), BackgroundTransparency: 1, BorderSizePixel: 0 }, (luaTruthy(stack) ? reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }) : reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), HorizontalAlignment: luaProp(luaProp(Enum, "HorizontalAlignment"), "Right"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") })), reactLoose.createElement(Badge, { value: tostring(luaProp(luaProp(item, "definition"), "Rarity") ?? "Common"), accent: accent, filled: false, size: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 78, 20) : luaCall(luaProp(UDim2, "fromOffset"), 84, 20)) }), reactLoose.createElement(Badge, { value: (((((tonumber(luaProp(luaProp(item, "instance"), "Stars")) || 0)) as unknown as number) > (0 as unknown as number)) ? `Lv ${luaProp(luaProp(item, "instance"), "Level")} ${(string.rep as unknown as (...a: unknown[]) => unknown)("★", (math.min as unknown as (...a: unknown[]) => unknown)(5, luaProp(luaProp(item, "instance"), "Stars")))}` : `Lv ${luaProp(luaProp(item, "instance"), "Level")}`), accent: luaProp(Palette, "mango"), size: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), (((((tonumber(luaProp(luaProp(item, "instance"), "Stars")) || 0)) as unknown as number) > (0 as unknown as number)) ? 92 : 56), 20) : luaCall(luaProp(UDim2, "fromOffset"), 84, 20)) }), ((((luaTruthy(locked ) ?  (!luaTruthy(bulkMode)) : locked)) && stack) && reactLoose.createElement(Badge, { value: "LOCK", accent: luaProp(Palette, "mango"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), 44, 20) })), ((luaTruthy(bulkMode ) ?  reactLoose.createElement(Badge, { value: (luaTruthy(bulkSelected) ? "ON" : (luaTruthy(locked) ? "LOCK" : ((luaProp(item, "equippedOn") !== undefined) ? "USED" : "PICK"))), accent: (luaTruthy(bulkSelected) ? luaProp(Palette, "coral") : ((luaTruthy(locked) || (luaProp(item, "equippedOn") !== undefined)) ? luaProp(Palette, "lineSoft") : accent)), filled: bulkSelected, size: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 52, 20) : luaCall(luaProp(UDim2, "fromOffset"), 84, 20)) }) : bulkMode)))));
		return undefined;
	}
	let INSPECT_PAD: unknown = luaProp(InventoryMath, "INSPECT_PAD");
	let INSPECT_BTN_GAP: unknown = luaProp(InventoryMath, "INSPECT_BTN_GAP");
	let INSPECT_FOOTER_H: unknown = luaProp(InventoryMath, "INSPECT_FOOTER_H");
	let ACTION_BTN: unknown = luaProp(InventoryMath, "ACTION_BTN");
	function DetailPanel(_param?: unknown): unknown | undefined {
		let item: unknown = luaProp(_param, "item");
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		if ((stack === undefined)) {
			stack = false;
		}
		let fill: unknown = luaProp(_param, "fill");
		if ((fill === undefined)) {
			fill = false;
		}
		let inspectActionsHostRef: unknown = reactLoose.useRef(undefined);
		let accent: unknown = luaCall(luaProp(InventoryMath, "RarityColor"), config, luaProp(luaProp(item, "definition"), "Rarity"), luaProp(Palette, "muted"));
		let _result: unknown = luaProp(state, "Items");
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Essence");
		}
		let _condition: unknown = _result;
		if ((_condition === undefined)) {
			_condition = 0;
		}
		let essence: unknown = _condition;
		let cost: unknown = luaCall(luaProp(InventoryMath, "UpgradeCost"), luaProp(item, "definition"), luaProp(luaProp(item, "instance"), "Level"));
		let canUpgrade: unknown;
		let maxed: unknown;
		[canUpgrade, maxed] = luaCall(luaProp(InventoryMath, "UpgradeState"), luaProp(luaProp(item, "instance"), "Level"), luaProp(luaProp(item, "definition"), "MaxLevel"), essence, cost) as LuaTuple<[unknown, unknown]>;
		let targets: unknown = reactLoose.useMemo(function(this: void): unknown | undefined {
			return luaCall(luaProp(InventoryMath, "SocketTargets"), state, config, luaProp(item, "definition"));
			return undefined;
		}, [config, luaProp(item, "definition"), luaProp(state, "Machines"), luaProp(state, "Research")]);
		let _condition_1: unknown = luaProp(item, "equippedOn");
		if ((_condition_1 === undefined)) {
			let _result_1: unknown = luaIndex(targets, 1);
			if ((_result_1 !== undefined)) {
				_result_1 = luaProp(_result_1, "id");
			}
			_condition_1 = _result_1;
			if ((_condition_1 === undefined)) {
				_condition_1 = "";
			}
		}
		let target: unknown;
		let setTarget: unknown;
		[target, setTarget] = reactLoose.useState(_condition_1) as LuaTuple<[unknown, unknown]>;
		let salvageArmedFor: unknown;
		let setSalvageArmedFor: unknown;
		[salvageArmedFor, setSalvageArmedFor] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((salvageArmedFor === undefined)) {
				return undefined;
			}
			let lapse: unknown = (task.delay as unknown as (...a: unknown[]) => unknown)(4, function(this: void): unknown | undefined {
				luaCall(setSalvageArmedFor, undefined);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), lapse);
				return undefined;
			};
			return undefined;
		}, [salvageArmedFor]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(setTarget, function(this: void, current?: unknown): unknown | undefined {
				if ((luaProp(item, "equippedOn") !== undefined)) {
					return luaProp(item, "equippedOn");
				}
				let _result_1: unknown = false;
				let _callback_1: unknown = function(this: void, candidate?: unknown): unknown | undefined {
					return (luaProp(candidate, "id") === current);
					return undefined;
				};
				for (const [_k, _v] of pairs((targets) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					if (luaTruthy(luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), targets))) {
						_result_1 = true;
						break;
					}
				}
				if (luaTruthy(_result_1)) {
					return current;
				}
				let _result_2: unknown = luaIndex(targets, 1);
				if ((_result_2 !== undefined)) {
					_result_2 = luaProp(_result_2, "id");
				}
				let _condition_2: unknown = _result_2;
				if ((_condition_2 === undefined)) {
					_condition_2 = "";
				}
				return _condition_2;
				return undefined;
			});
			return undefined;
		}, [luaProp(item, "uid"), luaProp(item, "equippedOn"), targets]);
		let salvage: unknown = luaCall(luaProp(InventoryMath, "SalvagePreview"), config, luaProp(item, "definition"), luaProp(luaProp(item, "instance"), "Level"));
		let equipped: unknown = (luaProp(item, "equippedOn") !== undefined);
		const compareLine: string | undefined = (luaProp(item, "equippedOn") !== undefined) ? undefined : luaCall(luaProp(InventoryMath, "CompareSocket"), state, config, luaProp(item, "uid"), luaProp(item, "definition"), luaProp(luaProp(item, "instance"), "Level"), luaProp(luaProp(item, "instance"), "Stars"), target) as string | undefined;
		const swapping: boolean = compareLine !== undefined && compareLine.sub(1, 8) === "Replaces";
		let locked: unknown = (luaProp(luaProp(item, "instance"), "Locked") === true);
		let chipCols: unknown = (luaTruthy(stack) ? 2 : 3);
		let chipRows: unknown = luaCall(luaProp(InventoryMath, "ChipRows"), len(targets), stack);
		let socketBlock: unknown = luaCall(luaProp(InventoryMath, "InspectSocketBlock"), equipped, len(targets), chipRows, stack, TapTarget);
		let chipHeight: unknown = (luaTruthy(stack) ? TapTarget : 40);
		let chipStep: unknown = (luaTruthy(stack) ? ((TapTarget as unknown as number) + (6 as unknown as number)) : 42);
		let actionsH: unknown = luaCall(luaProp(InventoryMath, "InspectActionsHeight"), stack);
		let detailH: unknown = luaCall(luaProp(InventoryMath, "InspectPanelHeight"), socketBlock, stack);
		let actionSize: unknown = (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -5, 0, ACTION_BTN) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, -7, 0, ACTION_BTN));
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!luaTruthy(luaProp(UserInputService, "GamepadEnabled")))) {
				return undefined;
			}
			let host: unknown = luaProp(inspectActionsHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let selectJob: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if ((luaProp(host, "Parent") === undefined)) {
					return;
				}
				luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), selectJob);
				return undefined;
			};
			return undefined;
		}, [luaProp(item, "uid"), equipped, locked, canUpgrade, target]);
		let socketBtn: unknown = function(this: void, size?: unknown, position?: unknown): unknown | undefined {
			return (luaTruthy(equipped) ? reactLoose.createElement(Button, { text: "Detach", icon: "Close.8", onClick: function(this: void): unknown | undefined {
				return luaCall(dispatch, "UnequipItem", { Target: luaProp(item, "equippedOn") });
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(Palette, "cream"), size: size, position: position, reducedMotion: reducedMotion, outline: true }) : reactLoose.createElement(Button, { text: (swapping ? "Swap in" : "Socket"), icon: "Loadout.3", onClick: function(this: void): unknown | undefined {
				if ((target !== "")) {
					luaCall(dispatch, "EquipItem", { Uid: luaProp(item, "uid"), Target: target });
				}
				return undefined;
			}, color: luaProp(Palette, "mint"), textColor: luaProp(Palette, "ink"), size: size, position: position, reducedMotion: reducedMotion, disabled: (target === ""), highlight: (target !== "") }));
			return undefined;
		};
		let upgradeBtn: unknown = function(this: void, size?: unknown, position?: unknown): unknown | undefined {
			return reactLoose.createElement(Button, { text: (luaTruthy(maxed) ? "Maxed" : `Upgrade  ${luaCall(compactNumber, cost)}`), icon: "StarGrid.5", onClick: function(this: void): unknown | undefined {
				return luaCall(dispatch, "UpgradeItem", { Uid: luaProp(item, "uid") });
				return undefined;
			}, color: (luaTruthy(canUpgrade) ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(canUpgrade) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: size, position: position, reducedMotion: reducedMotion, disabled: (!luaTruthy(canUpgrade)), highlight: canUpgrade });
			return undefined;
		};
		// salvaging destroys the relic, so it takes a second tap within a few seconds
		let salvageArmed: unknown = (salvageArmedFor === luaProp(item, "uid"));
		let salvageBtn: unknown = function(this: void, size?: unknown, position?: unknown): unknown | undefined {
			return reactLoose.createElement(Button, { text: (luaTruthy(salvageArmed) ? `Tap again · +${salvage}` : `Salvage  +${salvage}`), icon: "Dust.9", onClick: function(this: void): unknown | undefined {
				if ((!luaTruthy(salvageArmed))) {
					luaCall(setSalvageArmedFor, luaProp(item, "uid"));
					return undefined;
				}
				luaCall(setSalvageArmedFor, undefined);
				return luaCall(dispatch, "SalvageItem", { Uid: luaProp(item, "uid") });
				return undefined;
			}, color: ((luaTruthy(equipped) || luaTruthy(locked)) ? luaProp(Palette, "panelSoft") : luaProp(Palette, "coral")), textColor: ((luaTruthy(equipped) || luaTruthy(locked)) ? luaProp(Palette, "muted") : luaProp(Palette, "ink")), size: size, position: position, reducedMotion: reducedMotion, disabled: ((luaTruthy(equipped ) ? equipped :  locked)), outline: ((luaTruthy(equipped ) ? equipped :  locked)) });
			return undefined;
		};
		let lockBtn: unknown = function(this: void, size?: unknown, position?: unknown): unknown | undefined {
			return reactLoose.createElement(Button, { text: (luaTruthy(locked) ? "Unprotect" : "Protect"), icon: "Lock.13", sound: (luaTruthy(locked) ? "favoriteOff" : "favoriteOn"), onClick: function(this: void): unknown | undefined {
				return luaCall(dispatch, "ToggleItemLock", { Uid: luaProp(item, "uid") });
				return undefined;
			}, color: (luaTruthy(locked) ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(locked) ? luaProp(Palette, "ink") : luaProp(Palette, "creamSoft")), size: size, position: position, reducedMotion: reducedMotion, outline: (!luaTruthy(locked)) });
			return undefined;
		};
		let _exp: unknown = reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, INSPECT_BTN_GAP) });
		let _exp_1: unknown = ((luaTruthy(equipped ) ?  reactLoose.createElement(Text, { value: luaProp(item, "equippedOn") === CompanionRelic.TARGET ? "Your companion. Detach it to socket it instead." : string.sub(tostring(luaProp(item, "equippedOn")), 1, 11) === "Expedition:" ? "Away on an expedition until it's claimed or recalled." : `Socketed on ${luaCall(luaProp(InventoryMath, "SocketLabel"), luaProp(item, "equippedOn"))}`, size: 13, color: luaProp(Palette, "mint"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, layoutOrder: 0, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 20) }) : equipped));
		let _condition_2: unknown = ((!luaTruthy(equipped)) && ((len(targets) as unknown as number) > (0 as unknown as number)));
		if (luaTruthy(_condition_2)) {
			let _newValue_1: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(targets));
			let _callback_1: unknown = function(this: void, entry?: unknown, index?: unknown): unknown | undefined {
				let active: unknown = (luaProp(entry, "id") === target);
				let col: unknown = ((index as unknown as number) % (chipCols as unknown as number));
				let row: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((index as unknown as number) / (chipCols as unknown as number)));
				return reactLoose.createElement("imagebutton", { key: luaProp(entry, "id"), Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (chipCols as unknown as number)), -6, 0, chipHeight), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((col as unknown as number) / (chipCols as unknown as number)), 0, 0, ((row as unknown as number) * (chipStep as unknown as number))), BackgroundColor3: (luaTruthy(active) ? accent : luaProp(Palette, "panelSoft")), BackgroundTransparency: (luaTruthy(active) ? 0.15 : 0.2), BorderSizePixel: 0, AutoButtonColor: false, Active: true, Selectable: true, Event: { Activated: function(this: void): unknown | undefined {
					luaCall(setTarget, luaProp(entry, "id"));
					colon(Audio).play("tick");
					return undefined;
				}, MouseEnter: function(this: void): unknown | undefined {
					return colon(Audio).play("hover");
					return undefined;
				}, SelectionGained: function(this: void): unknown | undefined {
					return colon(Audio).play("hover");
					return undefined;
				} } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement("uistroke", { Color: (luaTruthy(active) ? accent : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: (luaTruthy(active) ? 0.2 : 0.55) }), reactLoose.createElement(Text, { value: luaProp(entry, "label"), size: 12, color: (luaTruthy(active) ? luaCall(contrastOn, accent) : luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 6, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -12, 1, 0) }));
				return undefined;
			};
			for (const [_k, _v] of pairs((targets) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue_1, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), targets));
			}
			_condition_2 = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((chipRows as unknown as number) * (chipStep as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 0 }, _newValue_1);
		}
		return reactLoose.createElement(Panel, { size: (luaTruthy(fill) ? luaCall(luaProp(UDim2, "fromScale"), 1, 1) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, detailH)), accent: accent, background: luaProp(Palette, "panelRaised"), padding: INSPECT_PAD, layoutOrder: layoutOrder, clips: false, zIndex: 20 }, reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 }, _exp, _exp_1, _condition_2, (((!luaTruthy(equipped)) && (len(targets) === 0)) && reactLoose.createElement(Text, { value: "Nothing it fits is unlocked yet. Unlock its machine or research first.", size: 12, color: luaProp(Palette, "mango"), wrap: true, fit: true, minSize: 10, layoutOrder: 0, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28) })), reactLoose.createElement("frame", { ref: inspectActionsHostRef, Name: "InspectClaimActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, actionsH), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 2, ClipsDescendants: false }, (luaTruthy(stack) ? reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement("frame", { Name: "InspectSocketClaim", Size: actionSize, Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, luaCall(socketBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined)), reactLoose.createElement("frame", { Name: "InspectUpgradeClaim", Size: actionSize, Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 5, 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, luaCall(upgradeBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined)), reactLoose.createElement("frame", { Name: "InspectProtect", Size: actionSize, Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((ACTION_BTN as unknown as number) + (INSPECT_BTN_GAP as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0 }, luaCall(lockBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined)), reactLoose.createElement("frame", { Name: "InspectSalvage", Size: actionSize, Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 5, 0, ((ACTION_BTN as unknown as number) + (INSPECT_BTN_GAP as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0 }, luaCall(salvageBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined))) : reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement("frame", { Name: "InspectSocketClaim", Size: actionSize, Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, luaCall(socketBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined)), reactLoose.createElement("frame", { Name: "InspectUpgradeClaim", Size: actionSize, Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.25, 2, 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, luaCall(upgradeBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined)), reactLoose.createElement("frame", { Name: "InspectProtect", Size: actionSize, Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 4, 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0 }, luaCall(lockBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined)), reactLoose.createElement("frame", { Name: "InspectSalvage", Size: actionSize, Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.75, 6, 0, 0), BackgroundTransparency: 1, BorderSizePixel: 0 }, luaCall(salvageBtn, luaCall(luaProp(UDim2, "fromScale"), 1, 1), undefined))))), reactLoose.createElement(Text, { value: (luaTruthy(equipped) ? "Detach before salvaging." : (compareLine !== undefined ? compareLine : (luaTruthy(locked) ? "Protected relics can't be salvaged." : `Essence bank: ${luaCall(compactNumber, essence)}`))), size: 12, color: (compareLine !== undefined && !luaTruthy(equipped) ? luaProp(Palette, "cream") : luaProp(Palette, "muted")), fit: false, layoutOrder: 3, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, INSPECT_FOOTER_H) })));
		return undefined;
	}
	function CrateCard(_param?: unknown): unknown | undefined {
		let crate: unknown = luaProp(_param, "crate");
		let keys: unknown = luaProp(_param, "keys");
		let pity: unknown = luaProp(_param, "pity");
		let onOpen: unknown = luaProp(_param, "onOpen");
		let busy: unknown = luaProp(_param, "busy");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		let reveal: unknown = luaCall(useStagger, layoutOrder, reducedMotion);
		let cardH: unknown = (luaTruthy(stack) ? 248 : 160);
		let actions: unknown = (luaTruthy(stack) ? reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number) + (8 as unknown as number))), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((((TapTarget as unknown as number) * (2 as unknown as number)) as unknown as number) + (14 as unknown as number))) as unknown as number))), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Vertical"), HorizontalAlignment: luaProp(luaProp(Enum, "HorizontalAlignment"), "Left"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Top"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Button, { text: (luaTruthy(busy) ? "…" : "Open"), icon: "Crate.7", onClick: function(this: void): unknown | undefined {
			return luaCall(onOpen, 1);
			return undefined;
		}, sound: "open", color: ((((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(crate, "Color") : luaProp(Palette, "panelSoft")), textColor: ((((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), reducedMotion: reducedMotion, disabled: (((keys as unknown as number) < (1 as unknown as number)) || busy), highlight: (((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))) }), reactLoose.createElement(Button, { text: (luaTruthy(busy) ? "…" : "Open 5"), icon: "Crate.8", onClick: function(this: void): unknown | undefined {
			return luaCall(onOpen, 5);
			return undefined;
		}, sound: "open", color: ((((keys as unknown as number) >= (5 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: ((((keys as unknown as number) >= (5 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), reducedMotion: reducedMotion, disabled: (((keys as unknown as number) < (5 as unknown as number)) || busy), highlight: (((keys as unknown as number) >= (5 as unknown as number)) && (!luaTruthy(busy))) })) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.5, 0), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), HorizontalAlignment: luaProp(luaProp(Enum, "HorizontalAlignment"), "Right"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Button, { text: (luaTruthy(busy) ? "…" : "Open"), icon: "Crate.9", onClick: function(this: void): unknown | undefined {
			return luaCall(onOpen, 1);
			return undefined;
		}, sound: "open", color: ((((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(crate, "Color") : luaProp(Palette, "panelSoft")), textColor: ((((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), hug: true, reducedMotion: reducedMotion, disabled: (((keys as unknown as number) < (1 as unknown as number)) || busy), highlight: (((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))) }), reactLoose.createElement(Button, { text: (luaTruthy(busy) ? "…" : "Open 5"), icon: "Crate.10", onClick: function(this: void): unknown | undefined {
			return luaCall(onOpen, 5);
			return undefined;
		}, sound: "open", color: ((((keys as unknown as number) >= (5 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(Palette, "mango") : luaProp(Palette, "panelSoft")), textColor: ((((keys as unknown as number) >= (5 as unknown as number)) && (!luaTruthy(busy))) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: luaCall(luaProp(UDim2, "fromOffset"), 0, TapTarget), hug: true, reducedMotion: reducedMotion, disabled: (((keys as unknown as number) < (5 as unknown as number)) || busy), highlight: (((keys as unknown as number) >= (5 as unknown as number)) && (!luaTruthy(busy))) })));
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, cardH), accent: luaProp(crate, "Color"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? Space.lg : Space.xl), layoutOrder: layoutOrder, reveal: reveal, highlight: (((keys as unknown as number) >= (1 as unknown as number)) && (!luaTruthy(busy))), clips: false }, reactLoose.createElement(IconTile, { kind: "Crate", accent: luaProp(crate, "Color"), size: 48, radius: Radius.lg, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 8 : 24)), reducedMotion: reducedMotion, glow: ((keys as unknown as number) >= (1 as unknown as number)), filled: ((keys as unknown as number) >= (1 as unknown as number)) }), reactLoose.createElement("frame", { Position: luaCall(luaProp(UDim2, "fromOffset"), 60, 4), Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((60 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -280), 0, 24), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }), reactLoose.createElement(Text, { value: luaProp(crate, "Name"), size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 12, layoutOrder: 0, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 150, 0, 24) }), reactLoose.createElement(Badge, { value: (((keys as unknown as number) > (0 as unknown as number)) ? `${keys} KEYS` : "No keys"), accent: (((keys as unknown as number) > (0 as unknown as number)) ? luaProp(crate, "Color") : luaProp(Palette, "muted")), size: luaCall(luaProp(UDim2, "fromOffset"), 64, 18), filled: ((keys as unknown as number) > (0 as unknown as number)), layoutOrder: 1 })), reactLoose.createElement(Text, { value: luaProp(crate, "Description"), size: 12, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 60, 32), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((60 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -280), 0, 36) }), reactLoose.createElement(Text, { value: `Guaranteed ${luaProp(crate, "PityRarity")} at ${luaProp(crate, "PityAfter")} (${pity}/${luaProp(crate, "PityAfter")})`, size: 11, color: luaProp(crate, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 60, 72), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((60 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -280), 0, 16) }), reactLoose.createElement(Meter, { value: (math.clamp as unknown as (...a: unknown[]) => unknown)(((pity as unknown as number) / ((math.max as unknown as (...a: unknown[]) => unknown)(1, luaProp(crate, "PityAfter")) as unknown as number)), 0, 1), color: luaProp(crate, "Color"), reducedMotion: reducedMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 60, 92), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((60 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -280), 0, 4) }), actions);
		return undefined;
	}
	let MARKET_BANNER_H: unknown = 126;
	let MARKET_CARD_H: unknown = 176;
	let MARKET_CARD_H_STACK: unknown = 210;
	function MarketBanner(_param?: unknown): unknown | undefined {
		let refreshText: unknown = luaProp(_param, "refreshText");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, (luaTruthy(stack) ? 132 : MARKET_BANNER_H)), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? Space.lg : Space.lg + Space.xs), layoutOrder: layoutOrder, highlight: true, reducedMotion: reducedMotion, clips: false }, reactLoose.createElement(IconTile, { kind: "Shop", accent: luaProp(Palette, "mango"), size: (luaTruthy(stack) ? 44 : 48), radius: Radius.lg, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 6 : 12)), reducedMotion: reducedMotion }), reactLoose.createElement(Text, { value: "Market", size: 10, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 56 : 64), 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((56 as unknown as number) + (12 as unknown as number))) as unknown as number)) : -16), 0, 14) }), reactLoose.createElement(Text, { value: refreshText, size: (luaTruthy(stack) ? 16 : 18), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 56 : 64), 18), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((56 as unknown as number) + (12 as unknown as number))) as unknown as number)) : -16), 0, 24) }), reactLoose.createElement(Text, { value: "Daily keys restock at UTC midnight. Rarer offers restock a little at a time.", size: 11, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 56 : 64), 48), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((56 as unknown as number) + (12 as unknown as number))) as unknown as number)) : -16), 0, (luaTruthy(stack) ? 44 : 36)) }), ((!luaTruthy(stack)) && reactLoose.createElement(React.Fragment, undefined, reactLoose.createElement(Badge, { value: "Daily keys", accent: luaProp(Palette, "cyan"), filled: true, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -208, 1, -30), size: luaCall(luaProp(UDim2, "fromOffset"), 98, 24) }), reactLoose.createElement(Badge, { value: "Live", accent: luaProp(Palette, "violet"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -100, 1, -30), size: luaCall(luaProp(UDim2, "fromOffset"), 92, 24) }))), ((luaTruthy(stack ) ?  reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 26), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -28), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Badge, { value: "Daily keys", accent: luaProp(Palette, "cyan"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), 98, 24) }), reactLoose.createElement(Badge, { value: "Live", accent: luaProp(Palette, "violet"), size: luaCall(luaProp(UDim2, "fromOffset"), 92, 24) })) : stack)));
		return undefined;
	}
	function MarketCard(_param?: unknown): unknown | undefined {
		let offer: unknown = luaProp(_param, "offer");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let cash: unknown = luaProp(_param, "cash");
		let stardust: unknown = luaProp(_param, "stardust");
		let cores: unknown = luaProp(_param, "cores");
		let refreshShort: unknown = luaProp(_param, "refreshShort");
		let stack: unknown = luaProp(_param, "stack");
		if ((stack === undefined)) {
			stack = false;
		}
		let balance: unknown = ((luaProp(offer, "Currency") === "Cash") ? luaCall(asFlux, cash) : ((luaProp(offer, "Currency") === "Stardust") ? stardust : cores));
		let _binding: unknown = luaCall(luaProp(InventoryMath, "OfferStock"), offer);
		let stock: unknown = luaProp(_binding, "stock");
		let stockMax: unknown = luaProp(_binding, "stockMax");
		let soldOut: unknown = luaProp(_binding, "soldOut");
		let daily: unknown = luaProp(_binding, "daily");
		let canBuy: unknown = ((!luaTruthy(soldOut)) && ((balance as unknown as number) >= (luaProp(offer, "Price") as unknown as number)));
		let priceLabel: unknown = (((luaProp(offer, "Price") as unknown as number) <= (0 as unknown as number)) ? "Free" : `${luaCall(compactNumber, luaProp(offer, "Price"))} ${luaProp(offer, "Currency")}`);
		let accent: unknown = (luaTruthy(soldOut) ? luaProp(Palette, "muted") : luaProp(offer, "Color"));
		let stockBadge: unknown = (luaTruthy(daily) ? ((luaTruthy(soldOut) ? ((((luaProp(offer, "Price") as unknown as number) <= (0 as unknown as number)) ? "Claimed" : "Bought")) : (((stockMax as unknown as number) > (1 as unknown as number)) ? `${stock}/${stockMax} today` : "Daily"))) : ((luaTruthy(soldOut) ? "Sold out" : `${stock} left`)));
		let stockBadgeAccent: unknown = (luaTruthy(soldOut) ? luaProp(Palette, "coral") : (luaTruthy(daily) ? luaProp(Palette, "cyan") : luaProp(Palette, "violet")));
		let statusLine: unknown = (luaTruthy(daily) ? ((luaTruthy(soldOut) ? ((((luaProp(offer, "Price") as unknown as number) <= (0 as unknown as number)) ? "Claimed today. The free key returns at restock." : "Bought today. Available again at restock.")) : `Refreshes daily · ${stock} of ${stockMax} left`)) : ((luaTruthy(soldOut) ? "Sold out. More comes in at restock." : `Limited stock · ${stock} of ${stockMax} remaining`)));
		let buttonText: unknown = (luaTruthy(soldOut) ? ((luaTruthy(daily) ? "Restocking" : "Sold out")) : "Buy");
		let cardH: unknown = (luaTruthy(stack) ? MARKET_CARD_H_STACK : MARKET_CARD_H);
		let textReserve: unknown = (luaTruthy(stack) ? (-((((56 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -240);
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, cardH), accent: accent, background: (luaTruthy(soldOut) ? luaProp(Palette, "panelSoft") : luaProp(Palette, "panelRaised")), padding: (luaTruthy(stack) ? Space.lg : Space.xl), layoutOrder: layoutOrder, clips: false, highlight: canBuy, reducedMotion: reducedMotion }, reactLoose.createElement(IconTile, { kind: ((luaProp(offer, "Kind") === "Essence") ? "Dust" : ((luaProp(offer, "Kind") === "Key") ? "Gift" : "Loadout")), accent: accent, size: 44, radius: Radius.md, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 8 : 32)), reducedMotion: reducedMotion }), reactLoose.createElement(Text, { value: luaProp(offer, "Name"), size: 16, color: (luaTruthy(soldOut) ? luaProp(Palette, "creamSoft") : luaProp(Palette, "cream")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 11, position: luaCall(luaProp(UDim2, "fromOffset"), 56, 4), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? (-((((56 as unknown as number) + (16 as unknown as number))) as unknown as number)) : -260), 0, 22) }), (luaTruthy(stack) ? reactLoose.createElement(Badge, { value: stockBadge, accent: stockBadgeAccent, filled: (!luaTruthy(soldOut)), position: luaCall(luaProp(UDim2, "fromOffset"), 56, 28), size: luaCall(luaProp(UDim2, "fromOffset"), 140, 24) }) : reactLoose.createElement(Badge, { value: stockBadge, accent: stockBadgeAccent, filled: (!luaTruthy(soldOut)), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -150, 0, 4), size: luaCall(luaProp(UDim2, "fromOffset"), 140, 26) })), reactLoose.createElement(Text, { value: luaProp(offer, "Description"), size: 11, color: luaProp(Palette, "creamSoft"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 56, (luaTruthy(stack) ? 56 : 30)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textReserve, 0, 34) }), reactLoose.createElement(Text, { value: priceLabel, size: 13, color: (luaTruthy(soldOut) ? luaProp(Palette, "muted") : luaProp(offer, "Color")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 56, (luaTruthy(stack) ? 94 : 70)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textReserve, 0, 18) }), reactLoose.createElement(Text, { value: statusLine, size: 10, color: (luaTruthy(soldOut) ? luaProp(Palette, "coral") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), wrap: true, fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 56, (luaTruthy(stack) ? 114 : 94)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textReserve, 0, 28) }), ((((luaTruthy(soldOut ) ?  daily : soldOut)) && (refreshShort !== undefined)) && (reactLoose.createElement(Text, { value: refreshShort, size: 10, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 56, (luaTruthy(stack) ? 142 : 124)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, textReserve, 0, 14) }))), (luaTruthy(stack) ? reactLoose.createElement(Button, { text: buttonText, icon: (luaTruthy(soldOut) ? "Lock.14" : "Shop.11"), onClick: function(this: void): unknown | undefined {
			return luaCall(dispatch, "BuyItemOffer", { Id: luaProp(offer, "Id") });
			return undefined;
		}, color: (luaTruthy(canBuy) ? luaProp(offer, "Color") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(canBuy) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-((((TapTarget as unknown as number) + (8 as unknown as number))) as unknown as number))), reducedMotion: reducedMotion, disabled: (!luaTruthy(canBuy)), highlight: canBuy }) : reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 0, 48), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0.5, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(Button, { text: buttonText, icon: (luaTruthy(soldOut) ? "Lock.15" : "Shop.12"), onClick: function(this: void): unknown | undefined {
			return luaCall(dispatch, "BuyItemOffer", { Id: luaProp(offer, "Id") });
			return undefined;
		}, color: (luaTruthy(canBuy) ? luaProp(offer, "Color") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(canBuy) ? luaProp(Palette, "ink") : luaProp(Palette, "muted")), size: luaCall(luaProp(UDim2, "fromOffset"), 0, 48), hug: true, reducedMotion: reducedMotion, disabled: (!luaTruthy(canBuy)), highlight: canBuy }))));
		return undefined;
	}
	function LoadoutBoard(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		let stack: unknown = luaProp(_param, "stack");
		let items: unknown = luaProp(state, "Items");
		let _effects: unknown = items;
		if ((_effects !== undefined)) {
			_effects = luaProp(_effects, "Effects");
		}
		let effects: unknown = _effects;
		let paletteById: unknown = { Production: luaProp(Palette, "green"), Capacity: luaProp(Palette, "cyan"), Tap: luaProp(Palette, "mango"), Critical: luaProp(Palette, "pink"), Automation: luaProp(Palette, "mint"), Offline: luaProp(Palette, "violet") };
		let lines: unknown = {};
		for (const [_, entry] of pairs((luaCall(luaProp(InventoryMath, "LoadoutEffectLines"), effects)) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaTable.insert(lines, { id: luaProp(entry, "id"), label: luaProp(entry, "label"), value: luaProp(entry, "value"), color: ((luaTruthy(luaIndex(paletteById, luaProp(entry, "id")) ) ? luaIndex(paletteById, luaProp(entry, "id")) :  luaProp(Palette, "muted"))) });
		}
		let equipped: unknown = {};
		let byId: unknown = {};
		let _result_6: unknown = luaProp(config, "Items");
		if ((_result_6 !== undefined)) {
			_result_6 = luaProp(_result_6, "Definitions");
		}
		let _condition_6: unknown = _result_6;
		if ((_condition_6 === undefined)) {
			_condition_6 = {};
		}
		for (const [_, definition] of pairs((_condition_6) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let _id: unknown = luaProp(definition, "Id");
			luaSetIndex(byId, _id, definition);
		}
		if ((items !== undefined)) {
			for (const [target, uid] of pairs((luaProp(items, "Equipped")) as object)) {
				if ((!((luaTypeIs(uid, "string"))))) {
					continue;
				}
				let instance: unknown = luaIndex(luaProp(items, "Inventory"), uid);
				let _result_7: unknown;
				if ((instance !== undefined)) {
					let _definitionId: unknown = luaProp(instance, "DefinitionId");
					_result_7 = luaIndex(byId, _definitionId);
				} else {
					_result_7 = undefined;
				}
				let definition: unknown = _result_7;
				if ((definition === undefined)) {
					continue;
				}
				let _arg0: unknown = { target: target, name: `${luaProp(definition, "Name")} LV${luaProp(instance, "Level")}`, rarity: luaProp(definition, "Rarity") };
				luaTable.insert(equipped, _arg0);
			}
		}
		let cols: unknown = (luaTruthy(stack) ? 2 : 3);
		let tileH: unknown = (luaTruthy(stack) ? 58 : 54);
		let tileGap: unknown = 8;
		let gridH: unknown = (((math.ceil as unknown as (...a: unknown[]) => unknown)(((len(lines) as unknown as number) / (cols as unknown as number))) as unknown as number) * ((((tileH as unknown as number) + (tileGap as unknown as number))) as unknown as number));
		let listH: unknown = ((28 as unknown as number) + (len(equipped) === 0 ? 112 : (len(equipped) as number) * 32));
		let _exp: unknown = reactLoose.createElement(Text, { value: "Bonuses", size: 11, color: luaProp(Palette, "violet"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) });
		let _newValue_1: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(lines));
		let _callback_1: unknown = function(this: void, line?: unknown, index?: unknown): unknown | undefined {
			let col: unknown = ((index as unknown as number) % (cols as unknown as number));
			let row: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((index as unknown as number) / (cols as unknown as number)));
			return reactLoose.createElement("frame", { key: luaProp(line, "id"), Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((1 as unknown as number) / (cols as unknown as number)), (-(tileGap as unknown as number)), 0, tileH), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(((col as unknown as number) / (cols as unknown as number)), ((col === 0) ? 0 : ((tileGap as unknown as number) / (2 as unknown as number))), 0, ((row as unknown as number) * ((((tileH as unknown as number) + (tileGap as unknown as number))) as unknown as number))), BackgroundColor3: luaProp(Palette, "panelSoft"), BackgroundTransparency: 0.04, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement("uistroke", { Color: (((luaProp(line, "value") as unknown as number) > (0 as unknown as number)) ? luaProp(line, "color") : luaProp(Palette, "lineSoft")), Transparency: 0.5, Thickness: 1 }), reactLoose.createElement(Text, { value: luaProp(line, "label"), size: 10, color: luaProp(Palette, "creamSoft"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 14) }), reactLoose.createElement(Text, { value: `+${(((math.floor as unknown as (...a: unknown[]) => unknown)(((((luaProp(line, "value") as unknown as number) * (1000 as unknown as number)) as unknown as number) + (0.5 as unknown as number))) as unknown as number) / (10 as unknown as number))}%`, size: 16, color: (((luaProp(line, "value") as unknown as number) > (0 as unknown as number)) ? luaProp(line, "color") : luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 24), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, 22) }));
			return undefined;
		};
		for (const [_k, _v] of pairs((lines) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue_1, _k, luaCall(_callback_1, _v, ((_k as unknown as number) - (1 as unknown as number)), lines));
		}
		let _exp_1: unknown = reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, gridH), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 22), BackgroundTransparency: 1, BorderSizePixel: 0 }, _newValue_1);
		let _exp_2: unknown = reactLoose.createElement(Text, { value: "Socketed", size: 11, color: luaProp(Palette, "mint"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((28 as unknown as number) + (gridH as unknown as number))), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 16) });
		let _exp_3: unknown = ((len(equipped) === 0) && reactLoose.createElement("frame", { BackgroundTransparency: 1, BorderSizePixel: 0, Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((48 as unknown as number) + (gridH as unknown as number))), Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 104) }, reactLoose.createElement(EmptyState, { icon: "Loadout", title: "No relics socketed", body: "Tap a relic below to socket it.", accent: luaProp(Palette, "violet"), compact: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1) })));
		let _newValue_2: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(equipped));
		let _callback_2: unknown = function(this: void, entry?: unknown, index?: unknown): unknown | undefined {
			return reactLoose.createElement("frame", { key: luaProp(entry, "target"), Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((((48 as unknown as number) + (gridH as unknown as number)) as unknown as number) + (((index as unknown as number) * (32 as unknown as number)) as unknown as number))), BackgroundColor3: luaProp(Palette, "ink"), BackgroundTransparency: 0.12, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) }), reactLoose.createElement(Text, { value: `${luaCall(luaProp(InventoryMath, "SocketLabel"), luaProp(entry, "target"))}  ·  ${luaProp(entry, "name")}`, size: 12, color: luaCall(luaProp(InventoryMath, "RarityColor"), config, luaProp(entry, "rarity"), luaProp(Palette, "muted")), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 10, 0), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 1, 0) }));
			return undefined;
		};
		for (const [_k, _v] of pairs((equipped) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(_newValue_2, _k, luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), equipped));
		}
		return reactLoose.createElement(Panel, { size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((((((40 as unknown as number) + (gridH as unknown as number)) as unknown as number) + (22 as unknown as number)) as unknown as number) + (listH as unknown as number))), accent: luaProp(Palette, "violet"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? Space.lg : Space.xl), layoutOrder: layoutOrder, clips: false, highlight: true }, _exp, _exp_1, _exp_2, _exp_3, _newValue_2);
		return undefined;
	}
	// Row memos (memoRow keeps click handlers pointing at the latest closure).
	// RelicRow shows: the relic (item, by value), config (slot/rarity labels), selected, bulk tick and
	// mode, motion, y/layout order, stack layout.
	let RelicRowMemo: unknown = memoRow<Record<string, unknown>>(counted("InvRelic", RelicRow as never), ["onSelect"], sameFields<Record<string, unknown>>(["item", "config", "selected", "bulkSelected", "bulkMode", "reducedMotion", "y", "layoutOrder", "stack"]));
	// CrateCard shows: the crate (by value), key count, pity, busy, motion, layout order, stack layout.
	let CrateCardMemo: unknown = memoRow<Record<string, unknown>>(counted("InvCrate", CrateCard as never), ["onOpen"], sameFields<Record<string, unknown>>(["crate", "keys", "pity", "busy", "reducedMotion", "layoutOrder", "stack"]));
	// MarketCard shows: the offer (by value), the three wallet balances it prices against, refresh text,
	// motion, layout order, stack layout; dispatch is the shell's stable dispatcher.
	let MarketCardMemo: unknown = React.memo(counted("InvMarket", MarketCard as never) as never, sameFields<Record<string, unknown>>(["offer", "dispatch", "cash", "stardust", "cores", "refreshShort", "reducedMotion", "layoutOrder", "stack"]) as never);
	function InventoryView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let crateRevealActive: unknown = luaProp(_param, "crateRevealActive");
		if ((crateRevealActive === undefined)) {
			crateRevealActive = false;
		}
		let onCrateReveal: unknown = luaProp(_param, "onCrateReveal");
		let openShop: unknown = luaProp(_param, "openShop");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let stack: unknown = luaProp(chrome, "contentStack");
		const pairWide = !luaTruthy(stack) && ((luaProp(viewport, "width") as number) ?? 0) >= CARD_PAIR_MIN_WIDTH;
		let touchLayout: unknown = luaProp(chrome, "mobile");
		let headerReveal: unknown = luaCall(useStagger, 0, softMotion);
		let tabsReveal: unknown = luaCall(useStagger, 1, softMotion);
		let inspectReveal: unknown = luaCall(useStagger, 2, softMotion);
		let bulkReveal: unknown = luaCall(useStagger, 3, softMotion);
		let inventorySoft: unknown = ((((luaTruthy(softMotion ) ? softMotion :  (tabsReveal === undefined))) || (inspectReveal === undefined)) || (bulkReveal === undefined));
		let tab: unknown;
		let setTab: unknown;
		[tab, setTab] = reactLoose.useState("Relics") as LuaTuple<[unknown, unknown]>;
		let activeTabIndex: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, ((((luaTable.find(TABS, tab) || 0)) as unknown as number) - (1 as unknown as number)));
		let paneTravel: unknown = luaCall(useFlipperSpring, activeTabIndex, reducedMotion, 1540, 40);
		let panePosition: unknown = colon(paneTravel).map(function(this: void, position?: unknown): unknown | undefined {
			return new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, (math.round as unknown as (...a: unknown[]) => unknown)((((math.clamp as unknown as (...a: unknown[]) => unknown)(((position as unknown as number) - (activeTabIndex as unknown as number)), -1, 1) as unknown as number) * (22 as unknown as number))), 0, 0);
			return undefined;
		});
		let filter: unknown;
		let setFilter: unknown;
		[filter, setFilter] = reactLoose.useState("All") as LuaTuple<[unknown, unknown]>;
		let sort: unknown;
		let setSort: unknown;
		[sort, setSort] = reactLoose.useState("Rarity") as LuaTuple<[unknown, unknown]>;
		let rarity: unknown;
		let setRarity: unknown;
		[rarity, setRarity] = reactLoose.useState("Any") as LuaTuple<[unknown, unknown]>;
		let search: unknown;
		let setSearch: unknown;
		[search, setSearch] = luaCall(luaProp(mod("BrowseKit"), "useLinkedQuery"), "Inventory") as LuaTuple<[unknown, unknown]>;
		let bulkMode: unknown;
		let setBulkModeState: unknown;
		[bulkMode, setBulkModeState] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let bulkSelected: unknown;
		let setBulkSelected: unknown;
		[bulkSelected, setBulkSelected] = reactLoose.useState({}) as LuaTuple<[unknown, unknown]>;
		let bulkBusy: unknown;
		let setBulkBusy: unknown;
		[bulkBusy, setBulkBusy] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let autoOpen: unknown;
		let setAutoOpen: unknown;
		[autoOpen, setAutoOpen] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let autoBusy: unknown;
		let setAutoBusy: unknown;
		[autoBusy, setAutoBusy] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let autoDraft: unknown;
		let setAutoDraft: unknown;
		[autoDraft, setAutoDraft] = reactLoose.useState() as LuaTuple<[unknown, unknown]>;
		let selectedUid: unknown;
		let setSelectedUid: unknown;
		[selectedUid, setSelectedUid] = reactLoose.useState(undefined) as LuaTuple<[unknown, unknown]>;
		let crateBusy: unknown;
		let setCrateBusy: unknown;
		[crateBusy, setCrateBusy] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let mountedRef: unknown = reactLoose.useRef(true);
		let crateAttemptRef: unknown = reactLoose.useRef(0);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			return function(this: void): unknown | undefined {
				luaSet(mountedRef, "current", false);
				luaSet(crateAttemptRef, "current", ((luaProp(crateAttemptRef, "current") as unknown as number) + (1 as unknown as number)));
				return undefined;
			};
			return undefined;
		}, {});
		let items: unknown = luaProp(state, "Items");
		let _exp: unknown = function(this: void): unknown | undefined {
			return luaCall(luaProp(InventoryMath, "CollectOwned"), state, config);
			return undefined;
		};
		let _exp_1: unknown = luaProp(config, "Items");
		let _result: unknown = items;
		if ((_result !== undefined)) {
			_result = luaProp(_result, "Equipped");
		}
		let _result_1: unknown = items;
		if ((_result_1 !== undefined)) {
			_result_1 = luaProp(_result_1, "Inventory");
		}
		let owned: unknown = reactLoose.useMemo(_exp, [_exp_1, _result, _result_1]);
		let filtered: unknown = reactLoose.useMemo(function(this: void): unknown | undefined {
			return luaCall(luaProp(InventoryMath, "SortOwned"), luaCall(luaProp(InventoryMath, "SearchOwned"), luaCall(luaProp(InventoryMath, "FilterOwned"), owned, filter), search, rarity, luaProp(mod("BrowseKit"), "matches")), config, sort);
			return undefined;
		}, [luaProp(config, "Items"), filter, owned, rarity, search, sort]);
		let _callback_1: unknown = function(this: void, entry?: unknown): unknown | undefined {
			return (luaProp(entry, "uid") === selectedUid);
			return undefined;
		};
		let _result_2: unknown;
		for (const [_i, _v] of pairs((filtered) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaCall(_callback_1, _v, ((_i as unknown as number) - (1 as unknown as number)), filtered) === true)) {
				_result_2 = _v;
				break;
			}
		}
		let _condition: unknown = _result_2;
		if ((_condition === undefined)) {
			_condition = luaIndex(filtered, 1);
		}
		let selected: unknown = _condition;
		let relicListRef: unknown = reactLoose.useRef();
		let relicRowStride: unknown = ((luaCall(luaProp(InventoryMath, "RelicRowHeight"), stack) as unknown as number) + (ROW_GAP as unknown as number));
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if (((selected !== undefined) && (luaProp(selected, "uid") !== selectedUid))) {
				luaCall(setSelectedUid, luaProp(selected, "uid"));
			}
			if ((len(filtered) === 0)) {
				luaCall(setSelectedUid, undefined);
			}
			return undefined;
		}, [filtered, selected, selectedUid]);
		let _exp_2: unknown = function(this: void): unknown | undefined {
			let frame: unknown = luaProp(relicListRef, "current");
			if (((((frame === undefined) || (selected === undefined)) || luaTruthy(bulkMode)) || (tab !== "Relics"))) {
				return undefined;
			}
			let selectedIndex: unknown = 0;
			for (const [index, item] of pairs((filtered) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaProp(item, "uid") === luaProp(selected, "uid"))) {
					selectedIndex = ((index as unknown as number) - (1 as unknown as number));
					break;
				}
			}
			let top: unknown = ((SCROLL_PAD as unknown as number) + (((selectedIndex as unknown as number) * (relicRowStride as unknown as number)) as unknown as number));
			let block: unknown = luaCall(luaProp(InventoryMath, "RelicRowHeight"), stack);
			let view: unknown = luaProp(luaProp(frame, "AbsoluteWindowSize"), "Y");
			if (((view as unknown as number) <= (1 as unknown as number))) {
				return undefined;
			}
			let pos: unknown = luaProp(luaProp(frame, "CanvasPosition"), "Y");
			if (((top as unknown as number) < (((pos as unknown as number) + (8 as unknown as number)) as unknown as number))) {
				luaSet(frame, "CanvasPosition", new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, (math.max as unknown as (...a: unknown[]) => unknown)(0, ((top as unknown as number) - (8 as unknown as number)))));
			} else if (((((top as unknown as number) + (block as unknown as number)) as unknown as number) > (((((pos as unknown as number) + (view as unknown as number)) as unknown as number) - (8 as unknown as number)) as unknown as number))) {
				luaSet(frame, "CanvasPosition", new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, (math.max as unknown as (...a: unknown[]) => unknown)(0, ((((((top as unknown as number) + (block as unknown as number)) as unknown as number) - (view as unknown as number)) as unknown as number) + (8 as unknown as number)))));
			}
			return undefined;
		};
		let _exp_3: unknown = len(filtered);
		let _result_3: unknown = selected;
		if ((_result_3 !== undefined)) {
			_result_3 = luaProp(_result_3, "uid");
		}
		reactLoose.useEffect(_exp_2, [bulkMode, filter, _exp_3, rarity, relicRowStride, search, _result_3, sort, stack, tab]);
		let _exp_4: unknown = function(this: void): unknown | undefined {
			let present: unknown = {};
			for (const [_, item] of pairs((owned) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let _uid: unknown = luaProp(item, "uid");
				luaSetIndex(present, _uid, true);
			}
			luaCall(setBulkSelected, function(this: void, current?: unknown): unknown | undefined {
				let _newValue_1: unknown = {};
				let _callback_2: unknown = function(this: void, uid?: unknown): unknown | undefined {
					let _uid: unknown = uid;
					return (luaIndex(present, _uid) !== undefined);
					return undefined;
				};
				let _length: unknown = 0;
				for (const [_k, _v] of pairs((current) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					if ((luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), current) === true)) {
						_length = ((_length as unknown as number) + (1 as unknown as number));
						luaSetIndex(_newValue_1, _length, _v);
					}
				}
				return _newValue_1;
				return undefined;
			});
			return undefined;
		};
		let _result_4: unknown = items;
		if ((_result_4 !== undefined)) {
			_result_4 = luaProp(_result_4, "Inventory");
		}
		reactLoose.useEffect(_exp_4, [_result_4]);
		let filled: unknown = len(owned);
		let _result_5: unknown = items;
		if ((_result_5 !== undefined)) {
			_result_5 = luaProp(_result_5, "InventoryLimit");
		}
		let _condition_1: unknown = _result_5;
		if ((_condition_1 === undefined)) {
			let _result_6: unknown = luaProp(config, "Items");
			if ((_result_6 !== undefined)) {
				_result_6 = luaProp(_result_6, "InventoryLimit");
			}
			_condition_1 = _result_6;
			if ((_condition_1 === undefined)) {
				_condition_1 = 100;
			}
		}
		let limit: unknown = _condition_1;
		let _result_6: unknown = items;
		if ((_result_6 !== undefined)) {
			_result_6 = luaProp(_result_6, "Essence");
		}
		let _condition_2: unknown = _result_6;
		if ((_condition_2 === undefined)) {
			_condition_2 = 0;
		}
		let essence: unknown = _condition_2;
		let heroH: unknown = (luaTruthy(stack) ? HERO_H_STACK : HERO_H);
		let pageGap: unknown = (luaTruthy(stack) ? ROW_GAP : luaProp(Layout, "panelGap"));
		let toolPad: unknown = (luaTruthy(stack) ? 8 : 12);
		let toolGap: unknown = (luaTruthy(stack) ? 8 : 10);
		let tabH: unknown = (luaTruthy(touchLayout) ? 54 : 56);
		let fieldH: unknown = (luaTruthy(stack) ? (math.max as unknown as (...a: unknown[]) => unknown)(TapTarget, 52) : TOOL_FIELD_DESK);
		let toolsH: unknown = ((tab === "Relics") ? ((((((((((toolPad as unknown as number) * (2 as unknown as number)) as unknown as number) + (((luaTruthy(stack) ? ((26 as unknown as number) + (toolGap as unknown as number)) : 0)) as unknown as number)) as unknown as number) + (((luaTruthy(stack) ? ((((fieldH as unknown as number) * (2 as unknown as number)) as unknown as number) + (toolGap as unknown as number)) : fieldH)) as unknown as number)) as unknown as number) + (toolGap as unknown as number)) as unknown as number) + (fieldH as unknown as number)) : 0);
		let _exp_5: unknown = function(this: void): unknown | undefined {
			return ((selected !== undefined) ? luaCall(luaProp(InventoryMath, "SocketTargets"), state, config, luaProp(selected, "definition")) : {});
			return undefined;
		};
		let _result_7: unknown = selected;
		if ((_result_7 !== undefined)) {
			_result_7 = luaProp(_result_7, "uid");
		}
		let targetsForSelected: unknown = reactLoose.useMemo(_exp_5, [config, _result_7, luaProp(state, "Machines"), luaProp(state, "Research")]);
		let chipRows: unknown = ((((selected !== undefined) && (luaProp(selected, "equippedOn") === undefined)) && ((len(targetsForSelected) as unknown as number) > (0 as unknown as number))) ? luaCall(luaProp(InventoryMath, "ChipRows"), len(targetsForSelected), stack) : 0);
		let inspectPanelH: unknown = ((((tab === "Relics") && (selected !== undefined)) && (!luaTruthy(bulkMode))) ? luaCall(luaProp(InventoryMath, "InspectPanelHeight"), luaCall(luaProp(InventoryMath, "InspectSocketBlock"), (luaProp(selected, "equippedOn") !== undefined), len(targetsForSelected), chipRows, stack, TapTarget), stack) : 0);
		let detailH: unknown = (((inspectPanelH as unknown as number) > (0 as unknown as number)) ? ((inspectPanelH as unknown as number) + (ROW_GAP as unknown as number)) : 0);
		let listH: unknown = (((math.max as unknown as (...a: unknown[]) => unknown)(1, len(filtered)) as unknown as number) * (relicRowStride as unknown as number));
		let listStart: unknown = ((((((((((((heroH as unknown as number) + (pageGap as unknown as number)) as unknown as number) + (tabH as unknown as number)) as unknown as number) + (pageGap as unknown as number)) as unknown as number) + (toolsH as unknown as number)) as unknown as number) + (detailH as unknown as number)) as unknown as number) + (SCROLL_EDGE as unknown as number));
		let _result_8: unknown = luaProp(config, "Items");
		if ((_result_8 !== undefined)) {
			_result_8 = luaProp(_result_8, "Crates");
		}
		let _condition_3: unknown = _result_8;
		if ((_condition_3 === undefined)) {
			_condition_3 = {};
		}
		let crates: unknown = _condition_3;
		let _result_9: unknown = items;
		if ((_result_9 !== undefined)) {
			_result_9 = luaProp(_result_9, "Shop");
		}
		let _condition_4: unknown = _result_9;
		if ((_condition_4 === undefined)) {
			_condition_4 = {};
		}
		let shopOffers: unknown = _condition_4;
		let marketNow: unknown = luaCall(useWallClock, (tab === "Market"));
		let _result_10: unknown = items;
		if ((_result_10 !== undefined)) {
			_result_10 = luaProp(_result_10, "ShopRefreshAt");
		}
		let _condition_5: unknown = _result_10;
		if ((_condition_5 === undefined)) {
			_condition_5 = 0;
		}
		let shopRefreshAt: unknown = _condition_5;
		let marketBannerH: unknown = (luaTruthy(stack) ? 132 : MARKET_BANNER_H);
		let keysRefreshText: unknown = colon(marketNow).map(function(this: void, timestamp?: unknown): unknown | undefined {
			let remaining: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, ((shopRefreshAt as unknown as number) - (timestamp as unknown as number)));
			return (((remaining as unknown as number) > (0 as unknown as number)) ? `Keys refresh in ${luaCall(luaProp(InventoryMath, "RestockClock"), remaining)}` : "Keys refreshing now…");
			return undefined;
		});
		let refreshShort: unknown = colon(marketNow).map(function(this: void, timestamp?: unknown): unknown | undefined {
			let remaining: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, ((shopRefreshAt as unknown as number) - (timestamp as unknown as number)));
			return (((remaining as unknown as number) > (0 as unknown as number)) ? `Restock in ${luaCall(luaProp(InventoryMath, "RestockClock"), remaining)}` : "Restocking…");
			return undefined;
		});
		let selectedForBulk: unknown = reactLoose.useMemo(function(this: void): unknown | undefined {
			let _newValue_1: unknown = {};
			let _callback_2: unknown = function(this: void, item?: unknown): unknown | undefined {
				let _uid: unknown = luaProp(item, "uid");
				let _condition_6: unknown = ((((((luaTable.find(bulkSelected, _uid) || 0)) as unknown as number) - (1 as unknown as number)) as unknown as number) >= (0 as unknown as number));
				if (luaTruthy(_condition_6)) {
					_condition_6 = ((luaProp(item, "equippedOn") === undefined) && (luaProp(luaProp(item, "instance"), "Locked") !== true));
				}
				return _condition_6;
				return undefined;
			};
			let _length: unknown = 0;
			for (const [_k, _v] of pairs((owned) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), owned) === true)) {
					_length = ((_length as unknown as number) + (1 as unknown as number));
					luaSetIndex(_newValue_1, _length, _v);
				}
			}
			return _newValue_1;
			return undefined;
		}, [bulkSelected, owned]);
		let selectableVisible: unknown = reactLoose.useMemo(function(this: void): unknown | undefined {
			let _newValue_1: unknown = {};
			let _callback_2: unknown = function(this: void, item?: unknown): unknown | undefined {
				return ((luaProp(item, "equippedOn") === undefined) && (luaProp(luaProp(item, "instance"), "Locked") !== true));
				return undefined;
			};
			let _length: unknown = 0;
			for (const [_k, _v] of pairs((filtered) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), filtered) === true)) {
					_length = ((_length as unknown as number) + (1 as unknown as number));
					luaSetIndex(_newValue_1, _length, _v);
				}
			}
			return _newValue_1;
			return undefined;
		}, [filtered]);
		let selectionEssence: unknown = 0;
		for (const [_, item] of pairs((selectedForBulk) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			selectionEssence = ((selectionEssence as unknown as number) + (luaCall(luaProp(InventoryMath, "SalvagePreview"), config, luaProp(item, "definition"), luaProp(luaProp(item, "instance"), "Level")) as unknown as number));
		}
		let _result_11: unknown = luaProp(state, "Shop");
		if ((_result_11 !== undefined)) {
			_result_11 = luaProp(luaProp(_result_11, "OwnedPasses"), "AutoSalvage");
		}
		let passOwned: unknown = (_result_11 === true);
		let _result_12: unknown = items;
		if ((_result_12 !== undefined)) {
			_result_12 = luaProp(_result_12, "AutoSalvage");
		}
		let _condition_6: unknown = _result_12;
		if ((_condition_6 === undefined)) {
			_condition_6 = { Enabled: false, KeepNew: true, Rarities: { Common: true, Uncommon: true } };
		}
		let serverAutoRules: unknown = _condition_6;
		let autoRules: unknown = ((luaTruthy(autoDraft ) ? autoDraft :  serverAutoRules));
		let serverAutoSignature: unknown = luaCall(luaProp(InventoryMath, "AutoSalvageSignature"), serverAutoRules, AUTO_RARITIES);
		let draftAutoSignature: unknown = ((autoDraft !== undefined) ? luaCall(luaProp(InventoryMath, "AutoSalvageSignature"), autoDraft, AUTO_RARITIES) : undefined);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if (((draftAutoSignature !== undefined) && (draftAutoSignature === serverAutoSignature))) {
				luaCall(setAutoDraft, undefined);
			}
			return undefined;
		}, [draftAutoSignature, serverAutoSignature]);
		let setBulkMode: unknown = function(this: void, value?: unknown): unknown | undefined {
			luaCall(setBulkModeState, value);
			if ((!luaTruthy(value))) {
				luaCall(setBulkSelected, {});
			}
			return undefined;
		};
		let toggleBulkItem: unknown = function(this: void, item?: unknown): unknown | undefined {
			if (((luaProp(item, "equippedOn") !== undefined) || (luaProp(luaProp(item, "instance"), "Locked") === true))) {
				colon(Audio).play("error");
				return undefined;
			}
			luaCall(setBulkSelected, function(this: void, current?: unknown): unknown | undefined {
				let _current: unknown = current;
				let _uid: unknown = luaProp(item, "uid");
				let index: unknown = ((((luaTable.find(_current, _uid) || 0)) as unknown as number) - (1 as unknown as number));
				if (((index as unknown as number) >= (0 as unknown as number))) {
					let _newValue_1: unknown = {};
					let _callback_2: unknown = function(this: void, uid?: unknown): unknown | undefined {
						return (uid !== luaProp(item, "uid"));
						return undefined;
					};
					let _length: unknown = 0;
					for (const [_k, _v] of pairs((current) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
						if ((luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), current) === true)) {
							_length = ((_length as unknown as number) + (1 as unknown as number));
							luaSetIndex(_newValue_1, _length, _v);
						}
					}
					return _newValue_1;
				}
				if (((len(current) as unknown as number) >= (25 as unknown as number))) {
					return current;
				}
				let _array: unknown = {};
				let _length: unknown = len(_array);
				let _currentLength: unknown = len(current);
				luaTable.move(current, 1, _currentLength, ((_length as unknown as number) + (1 as unknown as number)), _array);
				_length = ((_length as unknown as number) + (_currentLength as unknown as number));
				luaSetIndex(_array, ((_length as unknown as number) + (1 as unknown as number)), luaProp(item, "uid"));
				return _array;
				return undefined;
			});
			return undefined;
		};
		let selectVisible: unknown = function(this: void): unknown | undefined {
			let _newValue_1: unknown = {};
			let _callback_2: unknown = function(this: void, _?: unknown, index?: unknown): unknown | undefined {
				return ((index as unknown as number) < (25 as unknown as number));
				return undefined;
			};
			let _length: unknown = 0;
			for (const [_k, _v] of pairs((selectableVisible) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if ((luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), selectableVisible) === true)) {
					_length = ((_length as unknown as number) + (1 as unknown as number));
					luaSetIndex(_newValue_1, _length, _v);
				}
			}
			let _newValue_2: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(_newValue_1));
			let _callback_3: unknown = function(this: void, item?: unknown): unknown | undefined {
				return luaProp(item, "uid");
				return undefined;
			};
			for (const [_k, _v] of pairs((_newValue_1) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue_2, _k, luaCall(_callback_3, _v, ((_k as unknown as number) - (1 as unknown as number)), _newValue_1));
			}
			luaCall(setBulkSelected, _newValue_2);
			colon(Audio).play("filterPick");
			return undefined;
		};
		let clearSelection: unknown = function(this: void): unknown | undefined {
			return luaCall(setBulkSelected, {});
			return undefined;
		};
		let bulkArmed: unknown;
		let setBulkArmed: unknown;
		[bulkArmed, setBulkArmed] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!luaTruthy(bulkArmed))) {
				return undefined;
			}
			let lapse: unknown = (task.delay as unknown as (...a: unknown[]) => unknown)(4, function(this: void): unknown | undefined {
				luaCall(setBulkArmed, false);
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), lapse);
				return undefined;
			};
			return undefined;
		}, [bulkArmed, len(selectedForBulk)]);
		let runAutoNow: unknown = function(this: void): unknown | undefined {
			if ((((luaTruthy(autoBusy) || luaTruthy(bulkBusy)) || (!luaTruthy(passOwned))) || (!luaTruthy(luaProp(autoRules, "Enabled"))))) {
				return undefined;
			}
			let uids: unknown = {};
			for (const [_, item] of pairs((owned) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((luaProp(item, "equippedOn") !== undefined) || (luaProp(luaProp(item, "instance"), "Locked") === true))) {
					continue;
				}
				if ((luaIndex(luaProp(autoRules, "Rarities"), luaProp(luaProp(item, "definition"), "Rarity")) !== true)) {
					continue;
				}
				let _uid: unknown = luaProp(item, "uid");
				luaTable.insert(uids, _uid);
				if (((len(uids) as unknown as number) >= (25 as unknown as number))) {
					break;
				}
			}
			if ((len(uids) === 0)) {
				colon(Audio).play("error");
				return undefined;
			}
			luaCall(setBulkBusy, true);
			luaCall(dispatch, "BulkSalvageItems", { Uids: uids }, function(this: void, response?: unknown): unknown | undefined {
				if ((!luaTruthy(luaProp(mountedRef, "current")))) {
					return undefined;
				}
				luaCall(setBulkBusy, false);
				if (luaTruthy(luaProp(response, "ok"))) {
					colon(Audio).play("reward");
				}
				return undefined;
			});
			return undefined;
		};
		let salvageSelected: unknown = function(this: void): unknown | undefined {
			if (((len(selectedForBulk) === 0) || luaTruthy(bulkBusy))) {
				return undefined;
			}
			// first press arms (the button asks again), the second within 4 seconds salvages
			if ((!luaTruthy(bulkArmed))) {
				luaCall(setBulkArmed, true);
				return undefined;
			}
			luaCall(setBulkArmed, false);
			luaCall(setBulkBusy, true);
			let _object: unknown = {};
			let _left: unknown = "Uids";
			let _newValue_1: unknown = (table.create as unknown as (...a: unknown[]) => unknown)(len(selectedForBulk));
			let _callback_2: unknown = function(this: void, item?: unknown): unknown | undefined {
				return luaProp(item, "uid");
				return undefined;
			};
			for (const [_k, _v] of pairs((selectedForBulk) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaSetIndex(_newValue_1, _k, luaCall(_callback_2, _v, ((_k as unknown as number) - (1 as unknown as number)), selectedForBulk));
			}
			luaSetIndex(_object, _left, _newValue_1);
			luaCall(dispatch, "BulkSalvageItems", _object, function(this: void, response?: unknown): unknown | undefined {
				if ((!luaTruthy(luaProp(mountedRef, "current")))) {
					return undefined;
				}
				luaCall(setBulkBusy, false);
				if (luaTruthy(luaProp(response, "ok"))) {
					luaCall(setBulkSelected, {});
					colon(Audio).play("reward");
				}
				return undefined;
			});
			return undefined;
		};
		let updateAutoRules: unknown = function(this: void, updatedRules?: unknown): unknown | undefined {
			if ((luaTruthy(autoBusy) || (!luaTruthy(passOwned)))) {
				return undefined;
			}
			let rarities: unknown = {};
			for (const [_, entry] of pairs((AUTO_RARITIES) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((entry !== "Any") && (luaIndex(luaProp(updatedRules, "Rarities"), entry) === true))) {
					luaTable.insert(rarities, entry);
				}
			}
			if ((luaTruthy(luaProp(updatedRules, "Enabled")) && (len(rarities) === 0))) {
				luaTable.insert(rarities, "Common");
				luaTable.insert(rarities, "Uncommon");
				let _object: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(updatedRules);
				setmetatable(_object as object, undefined as unknown as LuaMetatable<object>);
				let _left: unknown = "Rarities";
				let _object_1: unknown = (table.clone as unknown as (...a: unknown[]) => unknown)(luaProp(updatedRules, "Rarities"));
				setmetatable(_object_1 as object, undefined as unknown as LuaMetatable<object>);
				luaSet(_object_1, "Common", true);
				luaSet(_object_1, "Uncommon", true);
				luaSetIndex(_object, _left, _object_1);
				updatedRules = _object;
			}
			luaCall(setAutoDraft, updatedRules);
			luaCall(setAutoBusy, true);
			luaCall(dispatch, "SetItemAutoSalvage", { Enabled: luaProp(updatedRules, "Enabled"), KeepNew: luaProp(updatedRules, "KeepNew"), Rarities: rarities }, function(this: void, response?: unknown): unknown | undefined {
				if ((!luaTruthy(luaProp(mountedRef, "current")))) {
					return undefined;
				}
				luaCall(setAutoBusy, false);
				if ((!luaTruthy(luaProp(response, "ok")))) {
					luaCall(setAutoDraft, undefined);
				} else {
					colon(Audio).play("filterPick");
				}
				return undefined;
			});
			return undefined;
		};
		let canvasHeight: unknown = ((listStart as unknown as number) + (luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), SCROLL_PAD) as unknown as number));
		if ((tab === "Relics")) {
			canvasHeight = ((((listStart as unknown as number) + (listH as unknown as number)) as unknown as number) + (luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), SCROLL_PAD) as unknown as number));
		} else if ((tab === "Crates")) {
			canvasHeight = ((((listStart as unknown as number) + (((len(crates) as unknown as number) * ((((((luaTruthy(stack) ? 248 : 160)) as unknown as number) + (pageGap as unknown as number))) as unknown as number)) as unknown as number)) as unknown as number) + (luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), SCROLL_PAD) as unknown as number));
		} else if ((tab === "Market")) {
			let marketCardH: unknown = (luaTruthy(stack) ? MARKET_CARD_H_STACK : MARKET_CARD_H);
			canvasHeight = ((((((((listStart as unknown as number) + (marketBannerH as unknown as number)) as unknown as number) + (pageGap as unknown as number)) as unknown as number) + ((((math.max as unknown as (...a: unknown[]) => unknown)(1, len(shopOffers)) as unknown as number) * ((((marketCardH as unknown as number) + (pageGap as unknown as number))) as unknown as number)) as unknown as number)) as unknown as number) + (luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), SCROLL_PAD) as unknown as number));
		} else if ((tab === "Recipes")) {
			canvasHeight = ((listStart as unknown as number) + recipeBenchHeight(((luaProp(luaProp(config, "Items"), "Definitions") ?? []) as never[]), (items ?? {}) as never, luaTruthy(stack)) + (luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), SCROLL_PAD) as unknown as number));
		} else {
			let equippedCount: unknown = 0;
			if ((items !== undefined)) {
				for (const [_, uid] of pairs((luaProp(items, "Equipped")) as object)) {
					if (((luaTypeIs(uid, "string")) && (luaIndex(luaProp(items, "Inventory"), uid) !== undefined))) {
						equippedCount = ((equippedCount as unknown as number) + (1 as unknown as number));
					}
				}
			}
			let cols: unknown = (luaTruthy(stack) ? 2 : 3);
			let gridH: unknown = (((math.ceil as unknown as (...a: unknown[]) => unknown)(((6 as unknown as number) / (cols as unknown as number))) as unknown as number) * (((luaTruthy(stack) ? 66 : 62)) as unknown as number));
			canvasHeight = ((((((((((((listStart as unknown as number) + (54 as unknown as number)) as unknown as number) + (gridH as unknown as number)) as unknown as number) + (18 as unknown as number)) as unknown as number) + (28 as unknown as number)) as unknown as number) + ((((math.max as unknown as (...a: unknown[]) => unknown)(1, equippedCount) as unknown as number) * (32 as unknown as number)) as unknown as number)) as unknown as number) + (luaCall(scrollTail, luaProp(chrome, "stack"), luaProp(chrome, "bottomSafe"), SCROLL_PAD) as unknown as number));
		}
		let paneHeight: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(1, ((((((canvasHeight as unknown as number) - (heroH as unknown as number)) as unknown as number) - (tabH as unknown as number)) as unknown as number) - (((pageGap as unknown as number) * (2 as unknown as number)) as unknown as number)));
		let openCrate: unknown = function(this: void, crate?: unknown, count?: unknown): unknown | undefined {
			if ((luaTruthy(crateBusy) || luaTruthy(crateRevealActive))) {
				return undefined;
			}
			let attempt: unknown = ((luaProp(crateAttemptRef, "current") as unknown as number) + (1 as unknown as number));
			luaSet(crateAttemptRef, "current", attempt);
			luaCall(setCrateBusy, true);
			luaCall(dispatch, "OpenItemCrate", { Id: luaProp(crate, "Id"), Count: count }, function(this: void, response?: unknown): unknown | undefined {
				if (((!luaTruthy(luaProp(mountedRef, "current"))) || (luaProp(crateAttemptRef, "current") !== attempt))) {
					return undefined;
				}
				luaCall(setCrateBusy, false);
				if ((!luaTruthy(luaProp(response, "ok")))) {
					return undefined;
				}
				let rolls: unknown = luaProp(response, "Rolls");
				if (((rolls === undefined) || (len(rolls) === 0))) {
					return undefined;
				}
				luaCall(onCrateReveal, { crateId: luaProp(crate, "Id"), crateName: luaProp(crate, "Name"), accent: luaProp(crate, "Color"), rolls: rolls });
				luaCall(setTab, "Relics");
				return undefined;
			});
			return undefined;
		};
		let tabsBar: unknown = reactLoose.createElement(SegmentedTabs, { options: TAB_OPTIONS, value: tab, onChange: function(this: void, entry?: unknown): unknown | undefined {
			luaCall(setTab, entry);
			if ((entry !== "Relics")) {
				luaCall(setBulkMode, false);
				luaCall(setAutoOpen, false);
			}
			return undefined;
		}, accent: luaProp(Palette, "violet"), columns: len(TABS), gap: pageGap, size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, tabH), layoutOrder: 1, reducedMotion: softMotion });
		let toolsBar: unknown = reactLoose.createElement(InventoryTools, { search: search, setSearch: setSearch, filter: filter, setFilter: setFilter, rarity: rarity, setRarity: setRarity, sort: sort, setSort: setSort, bulkMode: bulkMode, setBulkMode: setBulkMode, autoOpen: autoOpen, setAutoOpen: setAutoOpen, equipBest: function(this: void): unknown | undefined {
			return luaCall(dispatch, "EquipBestItems");
			return undefined;
		}, reducedMotion: softMotion, stack: stack, filled: filled, limit: limit, essence: essence });
		let heroPanel: unknown = reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "violet"), background: luaProp(Palette, "panelRaised"), padding: (luaTruthy(stack) ? Space.lg : Space.xl), layoutOrder: 0, reveal: (luaTruthy(reducedMotion) ? tabsReveal : headerReveal), highlight: (!luaTruthy(inventorySoft)), reducedMotion: softMotion, clips: false }, reactLoose.createElement(IconTile, { kind: "Loadout", accent: luaProp(Palette, "violet"), size: (luaTruthy(stack) ? 38 : 44), radius: 10, position: luaCall(luaProp(UDim2, "fromOffset"), 0, (luaTruthy(stack) ? 4 : 6)), spin: false, reducedMotion: softMotion, glow: true }), reactLoose.createElement(Text, { value: "Relics", size: 12, color: luaProp(Palette, "violet"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 50 : 56), 2), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -58 : -20), 0, 16) }), reactLoose.createElement(ShimmerText, { value: ((tab === "Crates") ? "Open crates for new relics" : ((tab === "Market") ? "Crate keys and live stock" : ((tab === "Loadout") ? "What your sockets add" : `${filled} of ${limit} relics in your bag`))), size: (luaTruthy(stack) ? 18 : 22), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 50 : 56), 20), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -58 : -20), 0, 26), enabled: (!luaTruthy(softMotion)), periodSeconds: 4.8 }), reactLoose.createElement("frame", { Visible: (tab !== "Relics"), Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 28) : luaCall(luaProp(UDim2, "fromOffset"), 220, 30)), Position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -28) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -220, 0.5, -15)), BackgroundTransparency: 1, BorderSizePixel: 0 }, reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), HorizontalAlignment: (luaTruthy(stack) ? luaProp(luaProp(Enum, "HorizontalAlignment"), "Left") : luaProp(luaProp(Enum, "HorizontalAlignment"), "Right")), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder") }), reactLoose.createElement(Badge, { value: `${filled} / ${limit}`, accent: luaProp(Palette, "violet"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 108 : 118), 28) }), reactLoose.createElement(Badge, { value: `${luaCall(compactNumber, essence)} essence`, accent: luaProp(Palette, "mango"), size: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(stack) ? 100 : 112), 28) })));
		if ((tab === "Relics")) {
			let listPane: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(SectionLabel, { value: (luaTruthy(bulkMode) ? "Select relics" : "Relics"), color: (luaTruthy(bulkMode) ? luaProp(Palette, "coral") : luaProp(Palette, "violet")) }), reactLoose.createElement(FlatList, { data: filtered, itemHeight: relicRowStride, headerHeight: SCROLL_PAD, overscan: (luaTruthy(softMotion) ? 0 : (((((luaProp(antilag, "tier") as unknown as number) <= (1 as unknown as number)) || luaTruthy(luaProp(antilag, "constrained"))) ? 1 : 2))), canvasTail: SCROLL_PAD, frameRef: relicListRef, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, -34), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 34), scrollBarColor: luaProp(Palette, "violet"), scrollBarThickness: 4, scrollBarTransparency: 0.22, keyExtractor: function(this: void, item?: unknown): unknown | undefined {
				return luaProp(item, "uid");
				return undefined;
			}, renderItem: function(this: void, _param_1?: unknown): unknown | undefined {
				let item: unknown = luaProp(_param_1, "item");
				let _attributes: unknown = { item: item, config: config };
				let _result_13: unknown = selected;
				if ((_result_13 !== undefined)) {
					_result_13 = luaProp(_result_13, "uid");
				}
				luaSet(_attributes, "selected", (_result_13 === luaProp(item, "uid")));
				let _uid: unknown = luaProp(item, "uid");
				luaSet(_attributes, "bulkSelected", ((((((luaTable.find(bulkSelected, _uid) || 0)) as unknown as number) - (1 as unknown as number)) as unknown as number) >= (0 as unknown as number)));
				luaSet(_attributes, "bulkMode", bulkMode);
				luaSet(_attributes, "onSelect", function(this: void): unknown | undefined {
					colon(Audio).play("tick");
					if (luaTruthy(bulkMode)) {
						luaCall(toggleBulkItem, item);
					} else {
						luaCall(setSelectedUid, luaProp(item, "uid"));
					}
					return undefined;
				});
				luaSet(_attributes, "reducedMotion", softMotion);
				luaSet(_attributes, "layoutOrder", 0);
				luaSet(_attributes, "stack", stack);
				return reactLoose.createElement(RelicRowMemo, _attributes);
				return undefined;
			}, ListEmptyComponent: reactLoose.createElement(EmptyState, { icon: "Loadout.4", title: ((len(owned) === 0) ? "No relics yet" : "Nothing matches"), body: ((len(owned) === 0) ? ((((((luaTruthy(luaProp(config, "ClientPageGuides") ) ?  luaProp(luaProp(config, "ClientPageGuides"), "Inventory") : luaProp(config, "ClientPageGuides"))) && luaProp(luaProp(luaProp(config, "ClientPageGuides"), "Inventory"), "EmptyItems"))) || "Open crates or buy a starter coupler from the Market tab.")) : "Clear the search or set the filters back to All relics."), accent: luaProp(Palette, "violet"), layoutOrder: 0 }) }));
			let sections: unknown = [{ id: "hero", height: heroH, element: heroPanel }, { id: "tabs", height: tabH, element: tabsBar }, { id: "tools", height: toolsH, element: toolsBar }];
			const bondH = companionBondHeight(items, luaTruthy(stack));
			if (bondH > 0) {
				luaTable.insert(sections, { id: "companion", height: bondH, element: reactLoose.createElement(CompanionBondCard, { items: items, dispatch: dispatch as never, stack: luaTruthy(stack), reducedMotion: luaTruthy(reducedMotion) }) });
			}
			if ((((inspectPanelH as unknown as number) > (0 as unknown as number)) && (selected !== undefined))) {
				luaTable.insert(sections, { id: "inspect", height: inspectPanelH, element: reactLoose.createElement(DetailPanel, { item: selected, state: state, config: config, dispatch: dispatch, reducedMotion: reducedMotion, layoutOrder: 0, stack: stack, fill: true }) });
			}
			// v8 engraving: the selected relic's lines, right under its inspect panel
			if ((((inspectPanelH as unknown as number) > (0 as unknown as number)) && (selected !== undefined))) {
				const engraveItems = (items ?? {}) as { Essence?: number; EngravingPaused?: boolean };
				const engraveOre = (luaProp(state, "Ore") ?? {}) as { Starsteel?: number };
				luaTable.insert(sections, { id: "engrave", height: engravingPanelHeight() + 28, element: reactLoose.createElement(Panel, { size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), accent: luaProp(Palette, "mango"), background: luaProp(Palette, "panelRaised"), padding: 14, reducedMotion: reducedMotion, clips: false }, reactLoose.createElement(EngravingPanel, { uid: luaProp(selected, "uid") as string, instance: luaProp(selected, "instance") as never, definition: luaProp(selected, "definition") as never, essence: tonumber(engraveItems.Essence) ?? 0, starsteel: tonumber(engraveOre.Starsteel) ?? 0, paused: engraveItems.EngravingPaused === true, dispatch: dispatch as never, reducedMotion: luaTruthy(reducedMotion) })) });
			}
			luaTable.insert(sections, { id: "list", fill: true, minHeight: (math.max as unknown as (...a: unknown[]) => unknown)(160, ((luaCall(luaProp(InventoryMath, "RelicRowHeight"), stack) as unknown as number) + (48 as unknown as number))), element: listPane });
			if (luaTruthy(bulkMode)) {
				luaTable.insert(sections, { id: "bulk", height: BULK_DOCK_H, element: reactLoose.createElement(BulkDock, { selectedCount: len(selectedForBulk), selectableCount: len(selectableVisible), selectionEssence: selectionEssence, selectVisible: selectVisible, clearSelection: clearSelection, salvageSelected: salvageSelected, bulkArmed: bulkArmed, bulkBusy: bulkBusy, reducedMotion: reducedMotion }) });
			}
			return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(PageScaffold, { gap: pageGap, tailPad: (luaTruthy(stack) ? 10 : 14), scrollBarColor: luaProp(Palette, "violet"), scrollBarThickness: 4, sections: sections }), ((luaTruthy(autoOpen ) ?  reactLoose.createElement(AutoSalvageSheet, { passOwned: passOwned, rules: autoRules, updateRules: updateAutoRules, autoBusy: autoBusy, openShop: openShop, runNow: runAutoNow, reducedMotion: reducedMotion, stack: stack, config: config, onClose: function(this: void): unknown | undefined {
				return luaCall(setAutoOpen, false);
				return undefined;
			} }) : autoOpen)));
		}
		let sections: unknown = [{ id: "hero", height: heroH, element: heroPanel }, { id: "tabs", height: tabH, element: tabsBar }];
		if ((tab === "Crates")) {
			let crateCardH: unknown = (luaTruthy(stack) ? 248 : 160);
			let crateStride: unknown = ((crateCardH as unknown as number) + (pageGap as unknown as number));
			let crateLabelH: unknown = 28;
			let crateList: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(FlatList, { data: (pairWide ? pairCards(crates, (c) => luaProp(c, "Id")) : crates), itemHeight: crateStride, headerHeight: ((crateLabelH as unknown as number) + (pageGap as unknown as number)), overscan: (luaTruthy(softMotion) ? 0 : (((((luaProp(antilag, "tier") as unknown as number) <= (1 as unknown as number)) || luaTruthy(luaProp(antilag, "constrained"))) ? 1 : 2))), canvasTail: SCROLL_PAD, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), scrollBarColor: luaProp(Palette, "violet"), scrollBarThickness: 4, scrollBarTransparency: 0.22, keyExtractor: function(this: void, crate?: unknown): unknown | undefined {
				return luaProp(crate, "Id");
				return undefined;
			}, renderItem: function(this: void, _param_1?: unknown): unknown | undefined {
				if (pairWide) {
					const row = luaProp(_param_1, "item");
					const cardFor = (crate: unknown): React.Element | undefined => {
						if (crate === undefined) return undefined;
						let keysTable: unknown = ((items !== undefined) ? luaProp(items, "Keys") : undefined);
						let pityTable: unknown = ((items !== undefined) ? luaProp(items, "Pity") : undefined);
						let keyCount: unknown = ((luaTypeIs(keysTable, "table")) ? luaIndex(keysTable, luaProp(crate, "Id")) : undefined);
						let pityCount: unknown = ((luaTypeIs(pityTable, "table")) ? luaIndex(pityTable, luaProp(crate, "Id")) : undefined);
						return reactLoose.createElement(CrateCardMemo, { crate: crate, keys: ((luaTypeIs(keyCount, "number")) ? keyCount : 0), pity: ((luaTypeIs(pityCount, "number")) ? pityCount : 0), onOpen: function(this: void, count?: unknown): unknown | undefined {
							return luaCall(openCrate, crate, count);
						}, busy: crateBusy, reducedMotion: reducedMotion, layoutOrder: 0, stack: stack }) as React.Element;
					};
					return pairRow(pageGap as number, cardFor(luaProp(row, "a"))!, cardFor(luaProp(row, "b")));
				}
				let crate: unknown = luaProp(_param_1, "item");
				let keysTable: unknown = ((items !== undefined) ? luaProp(items, "Keys") : undefined);
				let pityTable: unknown = ((items !== undefined) ? luaProp(items, "Pity") : undefined);
				let keyCount: unknown = ((luaTypeIs(keysTable, "table")) ? luaIndex(keysTable, luaProp(crate, "Id")) : undefined);
				let pityCount: unknown = ((luaTypeIs(pityTable, "table")) ? luaIndex(pityTable, luaProp(crate, "Id")) : undefined);
				return reactLoose.createElement(CrateCardMemo, { crate: crate, keys: ((luaTypeIs(keyCount, "number")) ? keyCount : 0), pity: ((luaTypeIs(pityCount, "number")) ? pityCount : 0), onOpen: function(this: void, count?: unknown): unknown | undefined {
					return luaCall(openCrate, crate, count);
					return undefined;
				}, busy: crateBusy, reducedMotion: reducedMotion, layoutOrder: 0, stack: stack });
				return undefined;
			}, ListHeaderComponent: reactLoose.createElement(SectionLabel, { value: "Crates", color: luaProp(Palette, "violet"), layoutOrder: 0 }), ListEmptyComponent: reactLoose.createElement(EmptyState, { icon: "Crate.11", title: "No crate channels", body: "More crate channels open as you progress through the story and the Lab.", accent: luaProp(Palette, "violet"), layoutOrder: 0, reducedMotion: reducedMotion }) }));
			luaTable.insert(sections, { id: "crates", fill: true, minHeight: (math.max as unknown as (...a: unknown[]) => unknown)(160, ((((crateLabelH as unknown as number) + (crateCardH as unknown as number)) as unknown as number) + (((pageGap as unknown as number) * (2 as unknown as number)) as unknown as number))), element: crateList });
		} else if ((tab === "Market")) {
			let marketCardH: unknown = (luaTruthy(stack) ? MARKET_CARD_H_STACK : MARKET_CARD_H);
			let marketStride: unknown = ((marketCardH as unknown as number) + (pageGap as unknown as number));
			let marketList: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(FlatList, { data: (pairWide ? pairCards(shopOffers, (o) => luaProp(o, "Id")) : shopOffers), itemHeight: marketStride, headerHeight: ((marketBannerH as unknown as number) + (pageGap as unknown as number)), overscan: (luaTruthy(softMotion) ? 0 : (((((luaProp(antilag, "tier") as unknown as number) <= (1 as unknown as number)) || luaTruthy(luaProp(antilag, "constrained"))) ? 1 : 2))), canvasTail: SCROLL_PAD, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), scrollBarColor: luaProp(Palette, "mango"), scrollBarThickness: 4, scrollBarTransparency: 0.22, keyExtractor: function(this: void, offer?: unknown): unknown | undefined {
				return luaProp(offer, "Id");
				return undefined;
			}, renderItem: function(this: void, _param_1?: unknown): unknown | undefined {
				if (pairWide) {
					const row = luaProp(_param_1, "item");
					const cardFor = (offer: unknown): React.Element | undefined =>
						offer === undefined
							? undefined
							: (reactLoose.createElement(MarketCardMemo, { offer: offer, dispatch: dispatch, reducedMotion: reducedMotion, layoutOrder: 0, cash: luaProp(state, "Cash"), stardust: luaProp(state, "Stardust"), cores: luaProp(state, "Cores"), refreshShort: refreshShort, stack: stack }) as React.Element);
					return pairRow(pageGap as number, cardFor(luaProp(row, "a"))!, cardFor(luaProp(row, "b")));
				}
				let offer: unknown = luaProp(_param_1, "item");
				return reactLoose.createElement(MarketCardMemo, { offer: offer, dispatch: dispatch, reducedMotion: reducedMotion, layoutOrder: 0, cash: luaProp(state, "Cash"), stardust: luaProp(state, "Stardust"), cores: luaProp(state, "Cores"), refreshShort: refreshShort, stack: stack });
				return undefined;
			}, ListHeaderComponent: reactLoose.createElement(MarketBanner, { refreshText: keysRefreshText, reducedMotion: reducedMotion, layoutOrder: 0, stack: stack }), ListEmptyComponent: reactLoose.createElement(EmptyState, { icon: "Shop.13", title: "Market offline", body: ((((((luaTruthy(luaProp(config, "ClientPageGuides") ) ?  luaProp(luaProp(config, "ClientPageGuides"), "Inventory") : luaProp(config, "ClientPageGuides"))) && luaProp(luaProp(luaProp(config, "ClientPageGuides"), "Inventory"), "EmptyMarket"))) || "No dock offers right now. More arrive at the next restock.")), accent: luaProp(Palette, "mango"), layoutOrder: 0, reducedMotion: reducedMotion }) }));
			luaTable.insert(sections, { id: "market", fill: true, minHeight: (math.max as unknown as (...a: unknown[]) => unknown)(160, ((((marketBannerH as unknown as number) + (marketCardH as unknown as number)) as unknown as number) + (((pageGap as unknown as number) * (2 as unknown as number)) as unknown as number))), element: marketList });
		} else if ((tab === "Recipes")) {
			// v8 recipe forging: craft relics already in the codex
			const benchDefs = ((luaProp(luaProp(config, "Items"), "Definitions") ?? []) as never[]);
			const benchItems = (items ?? {}) as never;
			const benchOre = (luaProp(state, "Ore") ?? {}) as never;
			luaTable.insert(sections, { id: "recipes", height: recipeBenchHeight(benchDefs, benchItems, luaTruthy(stack)), element: reactLoose.createElement(RecipeBench, { definitions: benchDefs, items: benchItems, ore: benchOre, stack: luaTruthy(stack), dispatch: dispatch as never, reducedMotion: luaTruthy(reducedMotion) }) });
		} else {
			let equippedCount: unknown = 0;
			if ((items !== undefined)) {
				for (const [_, uid] of pairs((luaProp(items, "Equipped")) as object)) {
					if (((luaTypeIs(uid, "string")) && (luaIndex(luaProp(items, "Inventory"), uid) !== undefined))) {
						equippedCount = ((equippedCount as unknown as number) + (1 as unknown as number));
					}
				}
			}
			let cols: unknown = (luaTruthy(stack) ? 2 : 3);
			let tileH: unknown = (luaTruthy(stack) ? 58 : 54);
			let tileGap: unknown = 8;
			let gridH: unknown = (((math.ceil as unknown as (...a: unknown[]) => unknown)(((6 as unknown as number) / (cols as unknown as number))) as unknown as number) * ((((tileH as unknown as number) + (tileGap as unknown as number))) as unknown as number));
			let loadoutH: unknown = ((((((((40 as unknown as number) + (gridH as unknown as number)) as unknown as number) + (22 as unknown as number)) as unknown as number) + (28 as unknown as number)) as unknown as number) + ((((math.max as unknown as (...a: unknown[]) => unknown)(1, equippedCount) as unknown as number) * (32 as unknown as number)) as unknown as number));
			luaTable.insert(sections, { id: "loadout-label", height: 28, element: reactLoose.createElement(SectionLabel, { value: "Sockets", color: luaProp(Palette, "mint"), layoutOrder: 0 }) });
			luaTable.insert(sections, { id: "loadout", height: loadoutH, element: reactLoose.createElement(LoadoutBoard, { state: state, config: config, reducedMotion: reducedMotion, layoutOrder: 0, stack: stack }) });
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(PageScaffold, { gap: pageGap, tailPad: (luaTruthy(stack) ? 10 : 14), scrollBarColor: ((tab === "Market") ? luaProp(Palette, "mango") : luaProp(Palette, "violet")), scrollBarThickness: 4, sections: sections }));
		return undefined;
	}
	return { InventoryView: InventoryView };
	return undefined;
}
export = __member();
