import { countRedraw, redrawCounterEnabled } from "./devRedrawCounter";
import { sameChromeProps, MOBILE_STATE_KEYS } from "./chromeMemo";
import React from "@rbxts/react";
import { AppHelpers, MORE_NAV, NavEntry, NavState, PRIMARY_NAV } from "../CoreKit/appNav";
import { Flux, asFlux, compactNumber } from "../CoreKit/format";
import { InteractionFeedback } from "../CoreKit/interaction";
import * as NavRouteTable from "../CoreKit/navRouteTable";
import * as NavRoutes from "../../../Shared/AstralForge/Shared/NavRoutes";
import { Palette, TapTarget, chromeFor, darken } from "../CoreKit/theme";
import { useEntrance, useFlipperSpring, useViewport } from "../MotionKit/motion";
import { joinTuple } from "../lua";
import { EVENTS, EventDef, ServerEvent, accentOf, openServerEventPanel, useServerEvent } from "./serverEventsUi";
import { readLevelState, openRoadmap, progressFraction } from "./levelRoadmap";
import { Button, CountBadge, IconTile, LooseComponent, SearchField, Text } from "./ui";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const UserInputService = game.GetService("UserInputService");

const AstralForge = script.Parent!.Parent!;
const loadKit = (name: string) => require(AstralForge.WaitForChild(name) as ModuleScript) as (member: string) => unknown;

const Icon = (loadKit("ArtKit")("Icon") as { Icon: LooseComponent }).Icon;

interface AudioApi {
	play(name: string): void;
}
const Audio = (loadKit("AudioKit")("audio") as { Audio: AudioApi }).Audio;

interface JuiceFxModule {
	useTarget(this: void, name: string): LuaTuple<[React.MutableRefObject<GuiObject | undefined>, React.Binding<number>]>;
}
const JuiceFx = require(AstralForge.WaitForChild("JuiceFx") as ModuleScript) as JuiceFxModule;

const SHEET_SWIPE_CLOSE = 90;
const OVERCHARGE_REPEAT = 0.11;

interface MobileState extends NavState {
	Stardust?: Flux;
	Cores?: Flux;
	Visitors?: unknown;
	ServerEvent?: ServerEvent;
	Capacity?: Flux;
	Vault?: Flux;
	Level?: unknown;
}

function allNav(state: MobileState, tutorialPage?: string) {
	const list: NavEntry[] = [];
	for (const entry of PRIMARY_NAV) {
		list.push(entry);
	}
	for (const entry of MORE_NAV) {
		list.push(entry);
	}
	return AppHelpers.filterNav(list, state, tutorialPage);
}

interface TabButtonProps {
	entry: NavEntry;
	active: boolean;
	onClick: () => void;
	badge?: number;
	reducedMotion?: boolean;
	compact?: boolean;
	size: UDim2;
	order: number;
}

function TabButtonInner(_param: TabButtonProps) {
	const entry = _param.entry;
	const active = _param.active;
	const onClick = _param.onClick;
	const badge = _param.badge ?? 0;
	const reducedMotion = _param.reducedMotion;
	const accent = entry.accent ?? Palette.cyan;
	const [pressed, setPressed] = React.useState(false);
	const selection = useFlipperSpring(active ? 1 : 0, reducedMotion, 620, 38);
	const press = useFlipperSpring(pressed ? 1 : 0, reducedMotion, 1100, 44);
	const compactLabel = _param.compact === true;
	return h(
		"imagebutton",
		{
			Name: "Nav_" + entry.id,
			Size: _param.size,
			LayoutOrder: _param.order,
			BackgroundTransparency: 1,
			AutoButtonColor: false,
			Selectable: true,
			ZIndex: 41,
			Event: {
				Activated: () => {
					Audio.play("tabSwitch");
					InteractionFeedback.tap();
					onClick();
				},
				InputBegan: (_gui: GuiObject, input: InputObject) => {
					if (input.UserInputType === Enum.UserInputType.Touch || input.UserInputType === Enum.UserInputType.MouseButton1) {
						setPressed(true);
					}
				},
				InputEnded: () => {
					setPressed(false);
				},
				MouseLeave: () => {
					setPressed(false);
				},
			},
		},
		h("uiscale", {
			Scale: press.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.06),
		}),
		h(
			"frame",
			{
				Size: selection.map((amount) => {
					const t = math.clamp(amount, 0, 1);
					return UDim2.fromOffset(math.round(28 + 22 * t), 28);
				}),
				Position: new UDim2(0.5, 0, 0, compactLabel ? 3 : 5),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundColor3: darken(accent, 0.5),
				BackgroundTransparency: selection.map((amount) => 1 - math.clamp(amount, 0, 1) * 0.85),
				BorderSizePixel: 0,
				ZIndex: 42,
			},
			h("uicorner", {
				CornerRadius: new UDim(1, 0),
			}),
		),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(24, 24),
				Position: new UDim2(0.5, 0, 0, compactLabel ? 5 : 7),
				AnchorPoint: new Vector2(0.5, 0),
				BackgroundTransparency: 1,
				ZIndex: 43,
			},
			h(Icon, {
				kind: entry.icon,
				color: active ? Palette.cream : Palette.creamSoft,
				accent: active ? accent : Palette.muted,
				size: 24,
				spin: false,
				reducedMotion: reducedMotion,
			}),
			badge > 0 &&
				h(CountBadge, {
					count: badge,
					zIndex: 46,
					compact: true,
				}),
		),
		h("textlabel", {
			Size: new UDim2(1, -4, 0, 14),
			Position: new UDim2(0.5, 0, 0, compactLabel ? 32 : 36),
			AnchorPoint: new Vector2(0.5, 0),
			BackgroundTransparency: 1,
			Text: entry.label,
			TextColor3: active ? Palette.cream : Palette.muted,
			TextSize: 11,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", active ? Enum.FontWeight.Heavy : Enum.FontWeight.Bold),
			ZIndex: 43,
		}),
	);
}

// tab buttons only re-render when what they show changes (onClick is rebuilt each render)
const TabButton = React.memo(TabButtonInner, (previous, nextProps) => {
	for (const [key, value] of pairs(previous as unknown as Record<string, unknown>)) {
		if (key !== "onClick" && (nextProps as unknown as Record<string, unknown>)[key] !== value) {
			return false;
		}
	}
	for (const [key, value] of pairs(nextProps as unknown as Record<string, unknown>)) {
		if (key !== "onClick" && (previous as unknown as Record<string, unknown>)[key] !== value) {
			return false;
		}
	}
	return true;
});

function MenuCell(_param: { entry: NavEntry; active: boolean; badge?: number; order: number; onPick: (id: string) => void }) {
	const entry = _param.entry;
	const active = _param.active;
	const badge = _param.badge ?? 0;
	const accent = entry.accent ?? Palette.cyan;
	return h(
		"textbutton",
		{
			Name: "Menu_" + entry.id,
			LayoutOrder: _param.order,
			BackgroundColor3: active ? darken(accent, 0.6) : Palette.panel,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			ZIndex: 512,
			Event: {
				Activated: () => {
					Audio.play("tabSwitch");
					InteractionFeedback.tap();
					_param.onPick(entry.id);
				},
			},
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 14),
		}),
		h("uistroke", {
			Color: active ? accent : Palette.line,
			Thickness: active ? 1.5 : 1,
			Transparency: active ? 0.15 : 0.55,
		}),
		h(IconTile, {
			kind: entry.icon,
			accent: accent,
			size: 34,
			radius: 10,
			position: new UDim2(0.5, -17, 0, 10),
			spin: false,
			zIndex: 513,
		}),
		h("textlabel", {
			Size: new UDim2(1, -8, 0, 24),
			Position: new UDim2(0.5, 0, 0, 44),
			AnchorPoint: new Vector2(0.5, 0),
			BackgroundTransparency: 1,
			Text: entry.label,
			TextColor3: Palette.cream,
			TextSize: 13,
			TextWrapped: true,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
			ZIndex: 513,
		}),
		h("textlabel", {
			Size: new UDim2(1, -8, 0, 12),
			Position: new UDim2(0.5, 0, 0, 69),
			AnchorPoint: new Vector2(0.5, 0),
			BackgroundTransparency: 1,
			Text: entry.eyebrow ?? "",
			TextColor3: Palette.muted,
			TextSize: 11,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
			ZIndex: 513,
		}),
		badge > 0 &&
			h(CountBadge, {
				count: badge,
				zIndex: 515,
			}),
	);
}

interface MenuSheetProps {
	open: boolean;
	page: string;
	state: MobileState;
	setPage: (page: string) => void;
	chatUnread: number;
	tutorialPage?: string;
	bottomSafe: number;
	reducedMotion?: boolean;
	onClose: () => void;
}

function MenuSheet(_param: MenuSheetProps) {
	const open = _param.open;
	const page = _param.page;
	const state = _param.state;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const reducedMotion = _param.reducedMotion;
	const [query, setQuery] = React.useState("");
	const amount = useFlipperSpring(open ? 1 : 0, reducedMotion, 620, 42);
	const [drag, setDrag] = React.useBinding(0);
	const dragState = React.useRef({ active: false, startY: 0, value: 0 });
	React.useEffect(() => {
		if (!open) {
			setQuery("");
		}
		dragState.current.value = 0;
		setDrag(0);
	}, [open]);
	React.useEffect(() => {
		if (!open) {
			return undefined;
		}
		const moved = UserInputService.InputChanged.Connect((input) => {
			const current = dragState.current;
			if (!current.active) {
				return;
			}
			if (input.UserInputType === Enum.UserInputType.Touch || input.UserInputType === Enum.UserInputType.MouseMovement) {
				current.value = math.max(0, input.Position.Y - current.startY);
				setDrag(current.value);
			}
		});
		const ended = UserInputService.InputEnded.Connect((input) => {
			const current = dragState.current;
			if (!current.active) {
				return;
			}
			if (input.UserInputType === Enum.UserInputType.Touch || input.UserInputType === Enum.UserInputType.MouseButton1) {
				current.active = false;
				if (current.value > SHEET_SWIPE_CLOSE) {
					_param.onClose();
				} else {
					current.value = 0;
					setDrag(0);
				}
			}
		});
		const back = UserInputService.InputBegan.Connect((input, processed) => {
			if (input.KeyCode === Enum.KeyCode.ButtonB || (input.KeyCode === Enum.KeyCode.Escape && !processed)) {
				_param.onClose();
			}
		});
		return () => {
			moved.Disconnect();
			ended.Disconnect();
			back.Disconnect();
		};
	}, [open]);

	const visible = allNav(state, _param.tutorialPage);
	const byId: Record<string, NavEntry> = {};
	for (const entry of visible) {
		byId[entry.id] = entry;
	}
	const [needleRaw] = string.gsub(query, "^%s*(.-)%s*$", "%1");
	const needle = string.lower(needleRaw);
	const cols = chrome.landscape ? 6 : viewport.width >= 560 ? 5 : 4;
	const sideGap = math.max(chrome.sideSafe, 12);
	const sheetW = viewport.width - sideGap * 2;
	const cellGap = 8;
	const cellW = math.floor((sheetW - 24 - cellGap * (cols - 1)) / cols);
	const cellH = 82;
	const sections: Record<string, unknown> = {};
	sections.layout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Vertical,
		Padding: new UDim(0, 14),
		SortOrder: Enum.SortOrder.LayoutOrder,
	});
	sections.pad = h("uipadding", {
		PaddingBottom: new UDim(0, 12),
	});
	const placed: Record<string, boolean> = {};
	const addSection = (key: string, label: string, ids: ReadonlyArray<string>, order: number) => {
		const entries: NavEntry[] = [];
		for (const id of ids) {
			const entry = byId[id];
			if (entry !== undefined && !placed[id]) {
				const [labelHit] = string.find(string.lower(entry.label), needle, 1, true);
				const [eyebrowHit] = string.find(string.lower(entry.eyebrow ?? ""), needle, 1, true);
				const matches = needle === "" || labelHit !== undefined || eyebrowHit !== undefined;
				if (matches) {
					placed[id] = true;
					entries.push(entry);
				}
			}
		}
		if (entries.size() === 0) {
			return;
		}
		const rows = math.ceil(entries.size() / cols);
		const cells: Record<string, unknown> = {};
		cells.grid = h("uigridlayout", {
			CellSize: UDim2.fromOffset(cellW, cellH),
			CellPadding: UDim2.fromOffset(cellGap, cellGap),
			SortOrder: Enum.SortOrder.LayoutOrder,
		});
		for (const [index, entry] of ipairs(entries)) {
			cells[entry.id] = h(MenuCell, {
				entry: entry,
				order: index,
				active: entry.id === page,
				badge: AppHelpers.navBadge(entry, state, _param.chatUnread),
				onPick: (id: string) => {
					_param.setPage(id);
					_param.onClose();
				},
			});
		}
		sections[key] = h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 22 + rows * (cellH + cellGap) - cellGap),
				LayoutOrder: order,
				BackgroundTransparency: 1,
				ZIndex: 511,
			},
			h(Text, {
				value: string.upper(label),
				size: 11,
				color: Palette.muted,
				weight: Enum.FontWeight.Heavy,
				sizeConstraint: new UDim2(1, 0, 0, 16),
				zIndex: 512,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 1, -22),
					Position: UDim2.fromOffset(0, 22),
					BackgroundTransparency: 1,
					ZIndex: 511,
				},
				cells,
			),
		);
	};
	for (const [order, group] of ipairs(NavRouteTable.NAV_GROUPS)) {
		addSection(group.key, group.label, group.routes, order);
	}
	const loose: string[] = [];
	for (const entry of visible) {
		if (!placed[entry.id]) {
			loose.push(entry.id);
		}
	}
	addSection("More", "More", loose, NavRouteTable.NAV_GROUPS.size() + 1);

	const topGap = math.max(viewport.topInset + 24, 40);
	const sheetH = viewport.height - topGap;
	const searchH = chrome.landscape ? 0 : 40;
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			Visible: amount.map((value) => value > 0.01),
			ZIndex: 505,
		},
		h("textbutton", {
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.void,
			BackgroundTransparency: amount.map((value) => 1 - math.clamp(value, 0, 1) * 0.55),
			AutoButtonColor: false,
			Text: "",
			Selectable: false,
			ZIndex: 506,
			Event: {
				Activated: _param.onClose,
			},
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, -sideGap * 2, 0, sheetH),
				Position: joinTuple(amount, drag).map((values) => {
					const hidden = (1 - math.clamp(values[0] as number, 0, 1)) * (sheetH + 20);
					return new UDim2(0.5, 0, 1, math.round(hidden + (values[1] as number)));
				}),
				AnchorPoint: new Vector2(0.5, 1),
				BackgroundColor3: Palette.night,
				BorderSizePixel: 0,
				Active: true,
				ZIndex: 508,
			},
			h("uicorner", {
				CornerRadius: new UDim(0, 22),
			}),
			h("uistroke", {
				Color: Palette.line,
				Transparency: 0.3,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 30),
					BackgroundTransparency: 1,
					Active: true,
					ZIndex: 509,
					Event: {
						InputBegan: (_gui: GuiObject, input: InputObject) => {
							if (
								input.UserInputType === Enum.UserInputType.Touch ||
								input.UserInputType === Enum.UserInputType.MouseButton1
							) {
								dragState.current.active = true;
								dragState.current.startY = input.Position.Y;
							}
						},
					},
				},
				h(
					"frame",
					{
						Size: UDim2.fromOffset(44, 5),
						Position: new UDim2(0.5, 0, 0, 10),
						AnchorPoint: new Vector2(0.5, 0),
						BackgroundColor3: Palette.lineSoft,
						BorderSizePixel: 0,
						ZIndex: 510,
					},
					h("uicorner", {
						CornerRadius: new UDim(1, 0),
					}),
				),
			),
			h(Text, {
				value: "All pages",
				size: 18,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				position: UDim2.fromOffset(16, 28),
				sizeConstraint: new UDim2(1, -80, 0, 24),
				zIndex: 510,
			}),
			h(
				"frame",
				{
					Size: UDim2.fromOffset(TapTarget, TapTarget),
					Position: new UDim2(1, -(TapTarget + 8), 0, 18),
					BackgroundTransparency: 1,
					ZIndex: 510,
				},
				h(Button, {
					text: "",
					icon: "Close.15",
					onClick: _param.onClose,
					color: Palette.panel,
					textColor: Palette.cream,
					outline: true,
					size: UDim2.fromScale(1, 1),
					reducedMotion: reducedMotion,
					zIndex: 511,
				}),
			),
			searchH > 0 &&
				h(SearchField, {
					value: query,
					onChange: setQuery,
					accent: Palette.cyan,
					placeholder: "Find a page",
					position: UDim2.fromOffset(12, 68),
					size: new UDim2(1, -24, 0, searchH),
					reducedMotion: reducedMotion,
					zIndex: 511,
				}),
			h(
				"scrollingframe",
				{
					Size: new UDim2(1, -24, 1, -(76 + searchH + _param.bottomSafe)),
					Position: UDim2.fromOffset(12, 72 + searchH),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					CanvasSize: new UDim2(),
					AutomaticCanvasSize: Enum.AutomaticSize.Y,
					ScrollBarThickness: 3,
					ScrollBarImageColor3: Palette.lineSoft,
					ScrollingDirection: Enum.ScrollingDirection.Y,
					ElasticBehavior: Enum.ElasticBehavior.WhenScrollable,
					ZIndex: 510,
				},
				sections,
			),
		),
	);
}

interface MobileTabBarProps {
	page: string;
	setPage: (page: string) => void;
	state: MobileState;
	chatUnread: number;
	tutorialPage?: string;
	reducedMotion?: boolean;
	height: number;
	bottomSafe: number;
	visible?: boolean;
}

function MobileTabBarImpl(_param: MobileTabBarProps) {
	countRedraw("MobileTabBar", redrawCounterEnabled(_param.state as { Admin?: { Access?: boolean } }));
	const page = _param.page;
	const setPage = _param.setPage;
	const state = _param.state;
	const chatUnread = _param.chatUnread;
	const tutorialPage = _param.tutorialPage;
	const reducedMotion = _param.reducedMotion;
	const height = _param.height;
	const bottomSafe = _param.bottomSafe;
	const visible = _param.visible ?? true;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const enter = useEntrance(reducedMotion);
	const [menuOpen, setMenuOpen] = React.useState(false);
	const available = allNav(state, tutorialPage);
	const byId: Record<string, NavEntry> = {};
	for (const entry of available) {
		byId[entry.id] = entry;
	}
	const slots = math.clamp(chrome.tabBarSlots, 4, 6);
	const availableIds: Record<string, boolean> = {};
	for (const [id] of pairs(byId)) {
		availableIds[id as string] = true;
	}
	const pins = NavRoutes.normalizeMobileTabPins(state.Flags?.MobileTabPins);
	const [tabIds] = NavRouteTable.mobileTabs(availableIds, slots, page, pins);
	const tabs: NavEntry[] = [];
	for (const id of tabIds) {
		tabs.push(byId[id]);
	}
	const current = byId[page];
	const pageOffBar = current !== undefined && tabIds.indexOf(page) === -1;
	if (pageOffBar && tabs.size() > 0) {
		tabs[tabs.size() - 1] = current;
	}
	const onBar: Record<string, boolean> = {};
	for (const entry of tabs) {
		onBar[entry.id] = true;
	}
	let menuBadge = 0;
	for (const entry of available) {
		if (!onBar[entry.id]) {
			menuBadge += AppHelpers.navBadge(entry, state, chatUnread);
		}
	}
	const menuEntry: NavEntry = { id: "Menu", label: "Menu", eyebrow: "", icon: "Menu.4", accent: Palette.cyan };
	const compact = chrome.landscape;
	const items: Record<string, unknown> = {};
	items.layout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		SortOrder: Enum.SortOrder.LayoutOrder,
		VerticalAlignment: Enum.VerticalAlignment.Center,
	});
	const tabSize = new UDim2(1 / (tabs.size() + 1), 0, 1, 0);
	for (const [index, entry] of ipairs(tabs)) {
		items[entry.id] = h(TabButton, {
			entry: entry,
			order: index,
			size: tabSize,
			active: page === entry.id,
			badge: AppHelpers.navBadge(entry, state, chatUnread),
			compact: compact,
			reducedMotion: reducedMotion,
			onClick: () => {
				setMenuOpen(false);
				setPage(entry.id);
			},
		});
	}
	items.menu = h(TabButton, {
		entry: menuEntry,
		order: tabs.size() + 1,
		size: tabSize,
		active: menuOpen,
		badge: menuBadge,
		compact: compact,
		reducedMotion: reducedMotion,
		onClick: () => {
			Audio.play(menuOpen ? "dropdownClose" : "dropdownOpen");
			setMenuOpen(!menuOpen);
		},
	});
	return h(
		React.Fragment,
		undefined,
		h(
			"frame",
			{
				Name: "MobileTabBar",
				Size: new UDim2(1, 0, 0, height),
				Position: enter.map((value) => new UDim2(0, 0, 1, math.round((1 - math.clamp(value, 0, 1)) * height))),
				AnchorPoint: new Vector2(0, 1),
				BackgroundColor3: Palette.night,
				BorderSizePixel: 0,
				Active: true,
				Visible: visible,
				ZIndex: 40,
			},
			h("frame", {
				Size: new UDim2(1, 0, 0, 1),
				BackgroundColor3: Palette.line,
				BorderSizePixel: 0,
				ZIndex: 41,
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, -(chrome.sideSafe * 2), 0, height - bottomSafe),
					Position: UDim2.fromOffset(chrome.sideSafe, 0),
					BackgroundTransparency: 1,
					ZIndex: 41,
				},
				items,
			),
		),
		h(MenuSheet, {
			open: menuOpen,
			page: page,
			setPage: setPage,
			state: state,
			chatUnread: chatUnread,
			tutorialPage: tutorialPage,
			bottomSafe: bottomSafe,
			reducedMotion: reducedMotion,
			onClose: () => {
				setMenuOpen(false);
			},
		}),
	);
}

function Chip(_param: { target?: string; width: number; height: number; order: number; value: unknown; accent: Color3 }) {
	const [juiceRef, juiceBump] = JuiceFx.useTarget(_param.target ?? "");
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(_param.width, _param.height),
			LayoutOrder: _param.order,
			BackgroundColor3: Palette.panelSoft,
			BorderSizePixel: 0,
			ZIndex: 22,
			ref: juiceRef,
		},
		h("uiscale", {
			Scale: juiceBump.map((b) => 1 + math.sin(b * math.pi) * 0.16),
		}),
		h("uicorner", {
			CornerRadius: new UDim(0, 10),
		}),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(6, 6),
				Position: new UDim2(0, 7, 0.5, 0),
				AnchorPoint: new Vector2(0, 0.5),
				BackgroundColor3: _param.accent,
				BorderSizePixel: 0,
				ZIndex: 23,
			},
			h("uicorner", {
				CornerRadius: new UDim(1, 0),
			}),
		),
		h(
			"textlabel",
			{
				Size: new UDim2(1, -20, 1, 0),
				Position: UDim2.fromOffset(16, 0),
				BackgroundTransparency: 1,
				Text: compactNumber(_param.value),
				TextColor3: Palette.cream,
				TextScaled: true,
				FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
				ZIndex: 23,
			},
			h("uitextsizeconstraint", {
				MaxTextSize: 13,
				MinTextSize: 11,
			}),
		),
	);
}

interface MobileHeaderProps {
	state: MobileState;
	page: string;
	accent: Color3;
	topPad: number;
	barHeight: number;
	edgePad: number;
	reducedMotion?: boolean;
	openPlayerlist: () => void;
}

function MobileHeaderImpl(_param: MobileHeaderProps) {
	countRedraw("MobileHeader", redrawCounterEnabled(_param.state as { Admin?: { Access?: boolean } }));
	const state = _param.state;
	const page = _param.page;
	const accent = _param.accent;
	const topPad = _param.topPad;
	const barHeight = _param.barHeight;
	const edgePad = _param.edgePad;
	const reducedMotion = _param.reducedMotion;
	const viewport = useViewport();
	const entry = AppHelpers.pageEntry(page);
	const short = barHeight <= 40;
	const width = viewport.width - edgePad * 2;
	const chipH = short ? 24 : 30;
	let chipW = short ? 84 : 96;
	const playersW = math.min(44, barHeight);
	const iconSize = short ? 24 : 30;
	const wanted: { key: string; target: string; value: unknown; accent: Color3 }[] = [
		{ key: "flux", target: "FLUX", value: state.Cash, accent: Palette.cyan },
	];
	if (AppHelpers.featureUnlocked(state, "StarGrid")) {
		wanted.push({ key: "dust", target: "DUST", value: state.Stardust, accent: Palette.mango });
	}
	if (AppHelpers.featureUnlocked(state, "Rebirth")) {
		wanted.push({ key: "cores", target: "CORES", value: state.Cores, accent: Palette.violet });
	}
	const visitors = typeIs(state.Visitors, "table") ? (state.Visitors as unknown[]).size() : 0;
	const liveEvent = useServerEvent(state.ServerEvent);
	const eventDef = liveEvent !== undefined && liveEvent.Phase !== "Rest" ? EVENTS[liveEvent.Id ?? ""] : undefined;
	const eventAccent = accentOf(eventDef);
	const eventW = eventDef !== undefined ? playersW + 6 : 0;
	const titleMin = width < 440 ? 60 : 110;
	const room = width - (8 + iconSize + 8 + titleMin + playersW + eventW + 22);
	// narrow phones shrink the chips so every currency stays readable without scrolling
	chipW = math.clamp(math.floor((room - math.max(0, wanted.size() - 1) * 6) / math.max(1, wanted.size())), 58, chipW);
	const chips: Record<string, unknown> = {};
	chips.layout = h("uilistlayout", {
		FillDirection: Enum.FillDirection.Horizontal,
		HorizontalAlignment: Enum.HorizontalAlignment.Left,
		VerticalAlignment: Enum.VerticalAlignment.Center,
		Padding: new UDim(0, 6),
		SortOrder: Enum.SortOrder.LayoutOrder,
	});
	for (const [index, item] of ipairs(wanted)) {
		chips[item.key] = h(Chip, {
			order: index,
			value: item.value,
			accent: item.accent,
			target: item.target,
			width: chipW,
			height: chipH,
		});
	}
	const contentW = wanted.size() * chipW + math.max(0, wanted.size() - 1) * 6;
	const chipsW = math.min(contentW, math.max(48, room));
	const [level, _tier, nextStep] = readLevelState(state);
	const fill = nextStep !== undefined ? progressFraction(nextStep) : 1;
	return h(
		"frame",
		{
			Name: "MobileHeader",
			Size: new UDim2(1, -edgePad * 2, 0, barHeight),
			Position: UDim2.fromOffset(edgePad, topPad),
			BackgroundColor3: Palette.panel,
			BorderSizePixel: 0,
			ClipsDescendants: true,
			ZIndex: 20,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 14),
		}),
		h("uistroke", {
			Color: Palette.line,
			Transparency: 0.4,
		}),
		h(IconTile, {
			kind: entry.icon,
			accent: accent,
			size: iconSize,
			radius: 10,
			position: UDim2.fromOffset(8, math.floor((barHeight - iconSize) / 2)),
			spin: false,
			reducedMotion: reducedMotion,
			zIndex: 21,
		}),
		h("textlabel", {
			Size: new UDim2(1, -(8 + iconSize + 8 + chipsW + playersW + eventW + 22), 0, barHeight),
			Position: UDim2.fromOffset(8 + iconSize + 8, 0),
			BackgroundTransparency: 1,
			Text: entry.label,
			TextColor3: Palette.cream,
			TextSize: short ? 14 : 16,
			TextXAlignment: Enum.TextXAlignment.Left,
			TextTruncate: Enum.TextTruncate.AtEnd,
			FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
			ZIndex: 21,
		}),
		!short &&
			h("imagebutton", {
				Name: "MobileRoadmapButton",
				Size: new UDim2(1, -(chipsW + playersW + eventW + 22), 1, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				ZIndex: 22,
				Event: {
					Activated: () => {
						Audio.play("open");
						openRoadmap();
					},
				},
			}),
		false &&
			h(
				"textlabel",
				{
					// level chip retired with the level system
					Name: "MobileLevelLabel",
					Size: UDim2.fromOffset(64, 16),
					Position: UDim2.fromOffset(8 + iconSize + 8, 24),
					BackgroundColor3: darken(accent, 0.55),
					BorderSizePixel: 0,
					Text: `LV ${level}`,
					TextColor3: Palette.cream,
					TextSize: 10,
					FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
					ZIndex: 22,
				},
				h("uicorner", {
					CornerRadius: new UDim(1, 0),
				}),
			),
		h(
			"scrollingframe",
			{
				Name: "MobileResourceRail",
				Size: UDim2.fromOffset(chipsW, chipH + 4),
				AutomaticCanvasSize: Enum.AutomaticSize.X,
				CanvasSize: new UDim2(),
				ScrollingDirection: Enum.ScrollingDirection.X,
				ScrollBarThickness: 2,
				ScrollBarImageColor3: accent,
				Active: true,
				Position: new UDim2(1, -(playersW + eventW + 12), 0.5, 0),
				AnchorPoint: new Vector2(1, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 21,
			},
			chips,
		),
		eventDef !== undefined &&
			h(
				"imagebutton",
				{
					Name: "MobileEventButton",
					Size: UDim2.fromOffset(playersW, playersW),
					Position: new UDim2(1, -(playersW + 10), 0.5, 0),
					AnchorPoint: new Vector2(1, 0.5),
					BackgroundColor3: darken(eventAccent, 0.6),
					BorderSizePixel: 0,
					AutoButtonColor: false,
					ZIndex: 22,
					Event: {
						Activated: openServerEventPanel,
					},
				},
				h("uicorner", {
					CornerRadius: new UDim(0, 10),
				}),
				h("uistroke", {
					Color: eventAccent,
					Thickness: 1.5,
					Transparency: 0.2,
				}),
				h(Icon, {
					kind: eventDef.Icon,
					color: Palette.cream,
					accent: eventAccent,
					size: math.floor(playersW * 0.62),
					position: UDim2.fromScale(0.5, 0.5),
					anchorPoint: new Vector2(0.5, 0.5),
				}),
			),
		h(
			"imagebutton",
			{
				Name: "MobilePlayersButton",
				Size: UDim2.fromOffset(playersW, playersW),
				Position: new UDim2(1, -4, 0.5, 0),
				AnchorPoint: new Vector2(1, 0.5),
				BackgroundColor3: Palette.panelSoft,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				ZIndex: 22,
				Event: {
					Activated: () => {
						Audio.play("playerlistOpen");
						_param.openPlayerlist();
					},
				},
			},
			h("uicorner", {
				CornerRadius: new UDim(0, 10),
			}),
			h(Icon, {
				kind: "Crew.15",
				color: Palette.cream,
				accent: Palette.cyan,
				size: math.floor(playersW * 0.62),
				position: UDim2.fromScale(0.5, 0.5),
				anchorPoint: new Vector2(0.5, 0.5),
			}),
			visitors > 0 &&
				h(
					"frame",
					{
						Size: UDim2.fromOffset(9, 9),
						Position: new UDim2(1, -3, 0, 3),
						AnchorPoint: new Vector2(1, 0),
						BackgroundColor3: Palette.mango,
						BorderSizePixel: 0,
						ZIndex: 23,
					},
					h("uicorner", {
						CornerRadius: new UDim(1, 0),
					}),
				),
		),
		h(
			"frame",
			{
				Size: new UDim2(1, -24, 0, 2),
				Position: new UDim2(0, 12, 1, -2),
				BackgroundColor3: Palette.line,
				BorderSizePixel: 0,
				ZIndex: 21,
			},
			h("frame", {
				Size: UDim2.fromScale(math.clamp(fill, 0, 1), 1),
				BackgroundColor3: accent,
				BorderSizePixel: 0,
				ZIndex: 22,
			}),
		),
	);
}

interface MobileQuickActionsProps {
	state: MobileState;
	dispatch: (action: string, payload?: object) => void;
	reducedMotion?: boolean;
	bottomOffset: number;
	edgePad: number;
}

export function MobileQuickActions(_param: MobileQuickActionsProps) {
	const state = _param.state;
	const dispatch = _param.dispatch;
	const reducedMotion = _param.reducedMotion;
	const bottomOffset = _param.bottomOffset;
	const edgePad = _param.edgePad;
	const viewport = useViewport();
	const capacity = asFlux(state.Capacity);
	const vaultFill = capacity > 0 ? math.clamp(asFlux(state.Vault) / capacity, 0, 1) : 0;
	const vaultReady = asFlux(state.Vault) >= 1;
	const fillSpring = useFlipperSpring(vaultFill, reducedMotion, 280, 28);
	const enter = useEntrance(reducedMotion);
	const [holding, setHolding] = React.useState(false);
	const holdPulse = useFlipperSpring(holding ? 1 : 0, reducedMotion, 900, 40);
	React.useEffect(() => {
		if (!holding) {
			return undefined;
		}
		let alive = true;
		const worker = task.spawn(() => {
			while (alive) {
				dispatch("Overcharge");
				InteractionFeedback.tap();
				task.wait(OVERCHARGE_REPEAT);
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, [holding]);
	React.useEffect(() => {
		if (!holding) {
			return undefined;
		}
		const released = UserInputService.InputEnded.Connect((input) => {
			if (input.UserInputType === Enum.UserInputType.Touch || input.UserInputType === Enum.UserInputType.MouseButton1) {
				setHolding(false);
			}
		});
		return () => {
			released.Disconnect();
		};
	}, [holding]);
	const bank = () => {
		if (!vaultReady) {
			Audio.play("locked");
			return undefined;
		}
		InteractionFeedback.reward();
		dispatch("CollectVault");
	};
	const width = math.min(220, math.floor(viewport.width * 0.6));
	const height = TapTarget + 14;
	return h(
		"frame",
		{
			Name: "MobileQuickActions",
			Size: UDim2.fromOffset(width, height),
			AnchorPoint: new Vector2(1, 1),
			Position: enter.map((value) => new UDim2(1, -edgePad, 1, -bottomOffset + math.round((1 - value) * 14))),
			BackgroundColor3: Palette.panel,
			BorderSizePixel: 0,
			ZIndex: 38,
		},
		h("uicorner", {
			CornerRadius: new UDim(0, 14),
		}),
		h("uistroke", {
			Color: vaultFill > 0.8 ? Palette.green : Palette.line,
			Thickness: vaultFill > 0.8 ? 2 : 1,
			Transparency: 0.35,
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, -20, 0, 3),
				Position: UDim2.fromOffset(10, 3),
				BackgroundColor3: Palette.line,
				BorderSizePixel: 0,
				ZIndex: 39,
			},
			h("uicorner", {
				CornerRadius: new UDim(1, 0),
			}),
			h(
				"frame",
				{
					Size: fillSpring.map((value) => new UDim2(math.clamp(value, 0.02, 1), 0, 1, 0)),
					BackgroundColor3: vaultFill > 0.92 ? Palette.mango : Palette.green,
					BorderSizePixel: 0,
					ZIndex: 40,
				},
				h("uicorner", {
					CornerRadius: new UDim(1, 0),
				}),
			),
		),
		h(
			"frame",
			{
				Size: new UDim2(1, -12, 0, TapTarget),
				Position: UDim2.fromOffset(6, 9),
				BackgroundTransparency: 1,
				ZIndex: 40,
			},
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				Padding: new UDim(0, 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			h(
				"frame",
				{
					Name: "OverviewVaultClaimActions",
					Size: new UDim2(0.58, -3, 1, 0),
					LayoutOrder: 1,
					BackgroundTransparency: 1,
				},
				h(Button, {
					text: vaultReady ? `BANK ${compactNumber(state.Vault)}` : "EMPTY",
					icon: "Flux.22",
					onClick: bank,
					color: vaultReady ? Palette.green : Palette.panelSoft,
					textColor: vaultReady ? Palette.ink : Palette.muted,
					size: UDim2.fromScale(1, 1),
					reducedMotion: reducedMotion,
					disabled: !vaultReady,
					highlight: vaultReady && vaultFill > 0.5,
				}),
			),
			h(
				"imagebutton",
				{
					Name: "MobileOvercharge",
					Size: new UDim2(0.42, -3, 1, 0),
					LayoutOrder: 2,
					BackgroundColor3: Palette.cyan,
					BorderSizePixel: 0,
					AutoButtonColor: false,
					ZIndex: 41,
					Event: {
						InputBegan: (_gui: GuiObject, input: InputObject) => {
							if (
								input.UserInputType === Enum.UserInputType.Touch ||
								input.UserInputType === Enum.UserInputType.MouseButton1
							) {
								setHolding(true);
							}
						},
					},
				},
				h("uicorner", {
					CornerRadius: new UDim(0, 14),
				}),
				h("uiscale", {
					Scale: holdPulse.map((value) => 1 - math.clamp(value, 0, 1) * 0.06),
				}),
				h(Icon, {
					kind: "Forge.26",
					color: Palette.ink,
					accent: Palette.ink,
					size: 20,
					position: new UDim2(0, 8, 0.5, -10),
				}),
				h("textlabel", {
					Size: new UDim2(1, -34, 1, 0),
					Position: UDim2.fromOffset(30, 0),
					BackgroundTransparency: 1,
					Text: holding ? "HOLD" : "TAP",
					TextColor3: Palette.ink,
					TextSize: 14,
					FontFace: new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
					ZIndex: 42,
				}),
			),
		),
	);
}

export const MobileTabBar = React.memo(MobileTabBarImpl, sameChromeProps(MOBILE_STATE_KEYS));

export const MobileHeader = React.memo(MobileHeaderImpl, sameChromeProps(MOBILE_STATE_KEYS));
