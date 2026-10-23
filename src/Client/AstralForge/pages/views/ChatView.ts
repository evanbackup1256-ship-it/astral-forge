import React from "@rbxts/react";
import { frameStroke } from "../../CoreKit/profileFrame";
import { segmentedHeight } from "../../UiCore/ui";
import ReactRoblox from "@rbxts/react-roblox";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable, luaRequire, instChild, kit, mod } from "./viewRuntime";
import { BODY, BODY_BOLD, BODY_SEMI, Line, MockPanel, NUM, PanelHeading, ROW_RADIUS, RowSurface, mockGap } from "../../UiCore/mockKit";
import { IconWell, MockRow, SEC } from "../mockRows";
import { TapTarget } from "../../CoreKit/theme";

// .row avatar in design/27-social: a #2a2030 disc
const AVATAR_FILL = Color3.fromRGB(42, 32, 48);

const CHAT_PEER_SIDE_MIN = 1280;
const CHAT_PEER_SIDE_W = 220;

function __member(): unknown {
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let _AnimatedTitle: unknown = kit("ReactHosts", "AnimatedTitle");
	let AnimatedTitle: unknown = luaProp(_AnimatedTitle, "AnimatedTitle");
	let titleFxAccent: unknown = luaProp(_AnimatedTitle, "titleFxAccent");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let _Icon: unknown = kit("ArtKit", "Icon");
	let Icon: unknown = luaProp(_Icon, "Icon");
	let PlayerMark: unknown = luaProp(_Icon, "PlayerMark");
	let _motion: unknown = kit("MotionKit", "motion");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let usePulse: unknown = luaProp(_motion, "usePulse");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let Palette: unknown = luaProp(_theme, "Palette");
	let Layout: unknown = luaProp(_theme, "Layout");
	let darken: unknown = luaProp(_theme, "darken");
	let lighten: unknown = luaProp(_theme, "lighten");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let Text: unknown = luaProp(_ui, "Text");
	let PageScaffold: unknown = luaProp(kit("LayoutKit", "pageScaffold"), "PageScaffold");
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let SegmentedTabs: unknown = luaProp(_ui, "SegmentedTabs");
	let ElementFx: unknown = luaProp(mod("ElementFx"), "ElementFx");
	let ARTIFACT_CHIP_W: unknown = 124;
	let ROW_HEIGHT: unknown = 68;
	const CHAT_ROW_GAP = 12;
	let CARD_H: unknown = 90;
	let SYSTEM_CARD_H: unknown = 66;
	let STATUS_HEIGHT: unknown = 64;
	let BANNER_HEIGHT: unknown = 52;
	let INPUT_HEIGHT: unknown = 60;
	let GAP: unknown = luaProp(Layout, "stackGap");
	let SIDE_INSET: unknown = 12;
	let STATUS_RESERVE: unknown = 128;
	// message rows: the name/title column starts at x=66 and stops before the 62px channel badge (at -72)
	// with a 6px gap; the header's STATUS_RESERVE used to be subtracted here too, leaving ~0px on phones
	let MESSAGE_RIGHT: unknown = 66 + 78;
	let NEAR_BOTTOM: unknown = 96;
	let ChatText: unknown = kit("CoreKit", "chatText");
	let ChatRules: unknown = luaRequire(colon(colon(colon(colon(game).GetService("ReplicatedStorage")).WaitForChild("AstralForge")).WaitForChild("Shared")).WaitForChild("ChatRules"));
	let DRAFT_LIMIT: unknown = ((luaProp(ChatRules, "MAX_INPUT") as unknown as number) + (40 as unknown as number));
	// room for "/w name " in front of a full message
	let TAB_ROW_H: unknown = 44;
	let PEER_ROW_H: unknown = 40;
	let SUGGEST_ROW_H: unknown = 40;
	let TAB_DEFS: unknown = [{ id: "all", label: "All" }, { id: "global", label: "Global" }, { id: "server", label: "Server" }, { id: "crew", label: "Crew" }, { id: "friends", label: "Friends" }, { id: "whispers", label: "Whispers" }];
	let EMPTY_CHAT: unknown = { messages: {}, unread: 0, unreadByTab: {}, connected: false, tab: "all", setTab: function(this: void): unknown | undefined {

		return undefined;
	}, peer: undefined, setPeer: function(this: void): unknown | undefined {

		return undefined;
	}, whispers: {}, send: function(this: void, _?: unknown, done?: unknown): unknown | undefined {
		if (luaTruthy(done)) {
			luaCall(done, false, "Chat is still connecting.");
		}
		return undefined;
	}, clear: function(this: void): unknown | undefined {

		return undefined;
	}, suggest: function(this: void): unknown | undefined {
		return {};
		return undefined;
	} };
	// one-row chip strip (whisper peers, autocomplete). Chat keeps no raw scrollers, so it clips:
	// callers pass chips most-relevant first and the tail is what gets cut on narrow screens.
	function chipRail(chips?: unknown, zIndex?: unknown): unknown | undefined {
		let children: unknown = { layout: reactLoose.createElement("uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6), SortOrder: luaProp(luaProp(Enum, "SortOrder"), "LayoutOrder"), VerticalAlignment: luaProp(luaProp(Enum, "VerticalAlignment"), "Center") }) };
		for (const [order, chip] of pairs((chips) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(children, luaProp(chip, "key"), reactLoose.createElement("frame", { LayoutOrder: order, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, -4), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), BackgroundTransparency: 1 }, luaProp(chip, "element")));
		}
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true, ZIndex: zIndex }, children);
		return undefined;
	}
	function channelBadge(message?: unknown): unknown | undefined {
		if (luaTruthy(luaProp(message, "localPlayer"))) {
			return "YOU";
		}
		if ((luaProp(message, "channel") === "global")) {
			return "GLOBAL";
		} else if ((luaProp(message, "channel") === "crew")) {
			return "CREW";
		} else if ((luaProp(message, "channel") === "whisper")) {
			return "WHISPER";
		} else if ((luaProp(message, "channel") === "friends")) {
			return "FRIEND";
		}
		return `WORLD ${luaProp(message, "world")}`;
		return undefined;
	}
	let TAG_COLORS: unknown = [luaProp(Palette, "mango"), luaProp(Palette, "mint"), luaProp(Palette, "violet"), luaProp(Palette, "mango"), luaProp(Palette, "pink"), luaProp(Palette, "blue")];
	function userColor(userId?: unknown): unknown | undefined {
		let authorId: unknown = (tonumber(userId) || 0);
		if (((authorId !== authorId) || ((math.abs as unknown as (...a: unknown[]) => unknown)(authorId) === luaProp(math, "huge")))) {
			authorId = 0;
		}
		return luaIndex(TAG_COLORS, (((((math.floor as unknown as (...a: unknown[]) => unknown)((math.abs as unknown as (...a: unknown[]) => unknown)(authorId)) as unknown as number) % (len(TAG_COLORS) as unknown as number)) as unknown as number) + (1 as unknown as number)));
		return undefined;
	}
	function useMessageEntrance(animate?: unknown, reducedMotion?: unknown): unknown | undefined {
		let shouldAnimate: unknown = reactLoose.useRef(((luaTruthy(animate ) ?  (!luaTruthy(reducedMotion)) : animate)));
		let live: unknown;
		let setLive: unknown;
		[live, setLive] = reactLoose.useState((!luaTruthy(luaProp(shouldAnimate, "current")))) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!luaTruthy(luaProp(shouldAnimate, "current")))) {
				luaCall(setLive, true);
				return undefined;
			}
			luaCall(setLive, false);
			let alive: unknown = true;
			let job: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if (luaTruthy(alive)) {
					luaCall(setLive, true);
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				alive = false;
				luaCall(pcall, luaProp(task, "cancel"), job);
				return undefined;
			};
			return undefined;
		}, {});
		return luaCall(useFlipperSpring, (luaTruthy(live) ? 1 : 0), reducedMotion, 780, 38);
		return undefined;
	}
	// design/27-social .row: a 30px avatar ring (brass, or the sender's profile frame), the name (and title)
	// over the message, the time muted on the right. One horizontal list per row, no hand-placed offsets.
	const P = Palette as Record<string, Color3>;
	function rowShell(rowHeight: number, enter: React.Binding<number>, fade: React.Binding<number>, face: React.Element[], content: (React.Element | undefined)[], overlay?: React.Element) {
		return React.createElement("frame", { Size: new UDim2(1, 0, 0, rowHeight), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true },
			React.createElement("frame", {
				Name: "Card",
				Size: new UDim2(1, -4, 0, rowHeight - CHAT_ROW_GAP),
				Position: enter.map((amount: number) => UDim2.fromOffset(math.round((1 - amount) * 14), math.round((1 - amount) * 10))),
				BackgroundColor3: P.white,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
				React.createElement("uiscale", { Scale: enter.map((amount: number) => 0.97 + amount * 0.03) }),
				React.createElement(React.Fragment, undefined, ...face),
				React.createElement("frame", { Name: "Content", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 },
					React.createElement("uipadding", { PaddingLeft: new UDim(0, 12), PaddingRight: new UDim(0, 12), PaddingTop: new UDim(0, 6), PaddingBottom: new UDim(0, 6) }),
					React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Horizontal, VerticalAlignment: Enum.VerticalAlignment.Center, Padding: new UDim(0, 12), SortOrder: Enum.SortOrder.LayoutOrder }),
					...content,
				),
				overlay,
			),
		);
	}
	function MessageRow(_param?: unknown): unknown | undefined {
		const message = luaProp(_param, "message");
		const reducedMotion = luaProp(_param, "reducedMotion");
		const bodySize = luaProp(_param, "bodySize") as number;
		const rowHeight = luaProp(_param, "rowHeight") as number;
		const enter = luaCall(useMessageEntrance, luaProp(_param, "animate"), reducedMotion) as React.Binding<number>;
		const system = luaTruthy(luaProp(message, "system"));
		const accent = (system ? P.mango : (luaProp(message, "profileAccent") ?? luaCall(userColor, luaProp(message, "userId")))) as Color3;
		const fade = enter.map((amount: number) => 1 - amount);
		if (system) {
			// game notices: a panel-raised card with the accent sliver, a 38px icon well and two lines
			return rowShell(rowHeight, enter, fade, [
				React.createElement("uicorner", { key: "corner", CornerRadius: new UDim(0, ROW_RADIUS) }),
				React.createElement("frame", { key: "fill", Size: UDim2.fromScale(1, 1), BackgroundColor3: P.panelRaised, BackgroundTransparency: fade.map((a: number) => 0.08 + a * 0.92), BorderSizePixel: 0, ZIndex: 0 }, React.createElement("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) })),
				React.createElement("uistroke", { key: "stroke", Color: accent, Thickness: 1, Transparency: fade.map((a: number) => 0.42 + a * 0.58), ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
				React.createElement("frame", { key: "sliver", Size: new UDim2(0, 3, 1, -12), Position: UDim2.fromOffset(0, 6), BackgroundColor3: accent, BackgroundTransparency: fade, BorderSizePixel: 0, ZIndex: 3 }, React.createElement("uicorner", { CornerRadius: new UDim(0, 2) })),
			], [
				React.createElement("frame", { key: "well", Size: UDim2.fromOffset(36, 36), BackgroundTransparency: 1, LayoutOrder: 0 }, React.createElement(IconWell, { icon: "Chat.2", accent, size: 36 })),
				React.createElement("frame", { key: "text", Size: new UDim2(0, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
					React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
					React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Vertical, VerticalAlignment: Enum.VerticalAlignment.Center, Padding: new UDim(0, 2), SortOrder: Enum.SortOrder.LayoutOrder }),
					React.createElement(Line, { text: "Game message", size: 12, font: BODY_BOLD, color: accent, width: new UDim(1, 0), height: 16, layoutOrder: 0 }),
					React.createElement("textlabel", { Text: tostring(luaProp(message, "text") ?? ""), FontFace: BODY, TextSize: bodySize - 1, TextColor3: P.cream, TextTransparency: fade, BackgroundTransparency: 1, TextWrapped: true, TextTruncate: Enum.TextTruncate.AtEnd, TextXAlignment: Enum.TextXAlignment.Left, TextYAlignment: Enum.TextYAlignment.Top, Size: new UDim2(1, 0, 0, math.max(16, rowHeight - CHAT_ROW_GAP - 12 - 18)), LayoutOrder: 1 }),
				),
			]);
		}
		// the sender's chosen profile frame on their avatar ring (default frame: the brass .4 ring)
		const markRing = frameStroke(luaProp(message, "profileFrame") as string | undefined, accent);
		const mention = luaTruthy(luaProp(message, "mention"));
		const mine = luaTruthy(luaProp(message, "localPlayer"));
		const artifactName = luaProp(message, "artifactName") as string | undefined;
		const artifactColor = (luaProp(message, "artifactColor") as Color3 | undefined) ?? accent;
		const ringColor = markRing.gradient !== undefined || luaProp(message, "profileFrame") !== undefined ? markRing.color : P.brass;
		const badge = luaCall(channelBadge, message) as string | undefined;
		const clock = tostring(luaCall(luaProp(ChatRules, "clock"), luaProp(message, "at")));
		const onWhisper = luaProp(_param, "onWhisper");
		const titleName = luaProp(message, "titleName");
		const face: React.Element[] = mention
			? [
					React.createElement("uicorner", { key: "corner", CornerRadius: new UDim(0, ROW_RADIUS) }),
					React.createElement("frame", { key: "fill", Size: UDim2.fromScale(1, 1), BackgroundColor3: P.mango, BackgroundTransparency: 0.86, BorderSizePixel: 0, ZIndex: 0 }, React.createElement("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) })),
					React.createElement("uistroke", { key: "stroke", Color: P.mango, Transparency: 0.5, Thickness: 1, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
				]
			: [React.createElement(RowSurface, { key: "surface" })];
		if (mine) {
			face.push(React.createElement("frame", { key: "mine", Size: new UDim2(0, 3, 1, -16), Position: UDim2.fromOffset(0, 8), BackgroundColor3: accent, BorderSizePixel: 0, ZIndex: 3 }, React.createElement("uicorner", { CornerRadius: new UDim(0, 2) })));
		}
		const textBlock = React.createElement("frame", { key: "text", Size: new UDim2(0, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
			React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
			React.createElement("frame", { Name: "Lines", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1 },
				React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Vertical, VerticalAlignment: Enum.VerticalAlignment.Center, Padding: new UDim(0, 2), SortOrder: Enum.SortOrder.LayoutOrder }),
				// .tt b: name 600 15px, then the title chip when they wear one
				React.createElement("frame", { Size: new UDim2(1, 0, 0, 20), BackgroundTransparency: 1, LayoutOrder: 0 },
					React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Horizontal, Padding: new UDim(0, 8), VerticalAlignment: Enum.VerticalAlignment.Center, SortOrder: Enum.SortOrder.LayoutOrder }),
					React.createElement("textlabel", { Text: tostring(luaProp(message, "displayName") ?? ""), FontFace: BODY_SEMI, TextSize: 15, TextColor3: mine ? accent : P.cream, TextTransparency: fade, BackgroundTransparency: 1, TextTruncate: Enum.TextTruncate.AtEnd, AutomaticSize: Enum.AutomaticSize.X, Size: UDim2.fromOffset(0, 20), LayoutOrder: 0 },
						React.createElement("uisizeconstraint", { MaxSize: new Vector2(220, 20) })),
					titleName !== undefined
						? React.createElement("frame", { Size: UDim2.fromOffset(160, 16), BackgroundTransparency: 1, LayoutOrder: 1 }, reactLoose.createElement(AnimatedTitle, { text: titleName, fx: luaProp(message, "titleFx"), size: 12, reducedMotion, inline: true, sizeConstraint: UDim2.fromScale(1, 1) }) as React.Element)
						: undefined,
				),
				// .tt small: the message (wraps to the row height, then truncates)
				React.createElement("textlabel", { Text: tostring(luaProp(message, "text") ?? ""), FontFace: BODY, TextSize: bodySize - 1, TextColor3: P.creamSoft, TextTransparency: fade, BackgroundTransparency: 1, TextWrapped: true, TextTruncate: Enum.TextTruncate.AtEnd, TextXAlignment: Enum.TextXAlignment.Left, TextYAlignment: Enum.TextYAlignment.Top, Size: new UDim2(1, 0, 0, math.max(16, rowHeight - CHAT_ROW_GAP - 12 - 22)), LayoutOrder: 1 }),
			),
			onWhisper !== undefined && !mine
				? React.createElement("textbutton", { Name: "WhisperAuthor", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, Text: "", AutoButtonColor: false, ZIndex: 5, Event: { Activated: () => luaCall(onWhisper, luaProp(message, "userId")) } })
				: undefined,
		);
		return rowShell(rowHeight, enter, fade, face, [
			React.createElement("frame", { key: "avatar", Size: UDim2.fromOffset(30, 30), BackgroundColor3: AVATAR_FILL, BorderSizePixel: 0, LayoutOrder: 0 },
				React.createElement("uicorner", { CornerRadius: new UDim(1, 0) }),
				React.createElement("uistroke", { Color: ringColor, Thickness: math.max(1.5, markRing.thickness), Transparency: markRing.gradient !== undefined ? 0 : 0.6, ApplyStrokeMode: Enum.ApplyStrokeMode.Border },
					markRing.gradient !== undefined ? React.createElement("uigradient", { Color: markRing.gradient, Rotation: 35 }) : undefined),
				reactLoose.createElement(PlayerMark, { userId: luaProp(message, "userId"), color: P.cream, accent, size: 18, position: UDim2.fromOffset(6, 6) }) as React.Element,
			),
			textBlock,
			artifactName !== undefined
				? React.createElement("frame", { key: "artifact", Size: UDim2.fromOffset(ARTIFACT_CHIP_W as number, 28), BackgroundColor3: P.white, BackgroundTransparency: 0.95, BorderSizePixel: 0, LayoutOrder: 2 },
						React.createElement("uicorner", { CornerRadius: new UDim(0, 8) }),
						React.createElement("uistroke", { Color: artifactColor, Transparency: 0.5, Thickness: 1, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
						React.createElement("uipadding", { PaddingLeft: new UDim(0, 6), PaddingRight: new UDim(0, 8) }),
						React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Horizontal, VerticalAlignment: Enum.VerticalAlignment.Center, Padding: new UDim(0, 4), SortOrder: Enum.SortOrder.LayoutOrder }),
						luaProp(message, "artifactElement") !== undefined
							? React.createElement("frame", { Size: UDim2.fromOffset(20, 20), BackgroundTransparency: 1, LayoutOrder: 0 }, reactLoose.createElement(ElementFx, { element: luaProp(message, "artifactElement"), size: UDim2.fromOffset(20, 20), reducedMotion }) as React.Element)
							: undefined,
						React.createElement("textlabel", { Text: artifactName, FontFace: BODY_BOLD, TextSize: 12, TextColor3: artifactColor, BackgroundTransparency: 1, TextTruncate: Enum.TextTruncate.AtEnd, TextXAlignment: Enum.TextXAlignment.Left, Size: new UDim2(0, 0, 1, 0), LayoutOrder: 1 }, React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill })),
					)
				: undefined,
			// .v.num in muted: the clock, with the channel tag under it
			React.createElement("frame", { key: "time", Size: new UDim2(0, 76, 1, 0), BackgroundTransparency: 1, LayoutOrder: 3 },
				React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Vertical, VerticalAlignment: Enum.VerticalAlignment.Center, HorizontalAlignment: Enum.HorizontalAlignment.Right, Padding: new UDim(0, 2), SortOrder: Enum.SortOrder.LayoutOrder }),
				React.createElement(Line, { text: clock, size: 17, font: NUM, color: P.muted, width: new UDim(1, 0), height: 20, align: Enum.TextXAlignment.Right, layoutOrder: 0 }),
				luaTruthy(badge) ? React.createElement(Line, { text: tostring(badge), size: 11, font: BODY_BOLD, color: P.muted, width: new UDim(1, 0), height: 14, align: Enum.TextXAlignment.Right, layoutOrder: 1 }) : undefined,
			),
		]);
	}
	function ChatView(_param?: unknown): unknown | undefined {
		let chat: unknown = ((luaTruthy(luaProp(_param, "chat") ) ? luaProp(_param, "chat") :  EMPTY_CHAT));
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let antilag: unknown = luaCall(useAntilag);
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let textScale: unknown = ((luaTruthy(luaProp(chat, "textScale") ) ? luaProp(chat, "textScale") :  1.075));
		let bodySize: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((((((luaTruthy(luaProp(chrome, "mobile")) ? 15 : 14)) as unknown as number) * (textScale as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
		let rowHeight: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((((((luaTruthy(luaProp(chrome, "mobile")) ? 84 : ROW_HEIGHT)) as unknown as number) * ((math.max as unknown as (...a: unknown[]) => unknown)(1, ((textScale as unknown as number) * (0.95 as unknown as number))) as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
		let condensed: unknown = (((luaTruthy(luaProp(chrome, "landscape") ) ? luaProp(chrome, "landscape") :  luaProp(viewport, "keyboardOpen"))) || ((luaProp(viewport, "height") as unknown as number) < (700 as unknown as number)));
		let showStatus: unknown = (!luaTruthy(condensed));
		let showBanner: unknown = ((!luaTruthy(condensed)) && ((luaProp(viewport, "height") as unknown as number) >= (760 as unknown as number)));
		let chromeGap: unknown = (luaTruthy(condensed) ? 8 : GAP);
		let inputHeight: unknown = (luaTruthy(condensed) ? 62 : INPUT_HEIGHT);
		let draft: unknown;
		let setDraft: unknown;
		[draft, setDraft] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let failure: unknown;
		let setFailure: unknown;
		[failure, setFailure] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let viewHeight: unknown;
		let setViewHeight: unknown;
		[viewHeight, setViewHeight] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let searchOpen: unknown;
		let setSearchOpen: unknown;
		[searchOpen, setSearchOpen] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let logQuery: unknown;
		let setLogQuery: unknown;
		[logQuery, setLogQuery] = reactLoose.useState("") as LuaTuple<[unknown, unknown]>;
		let input: unknown = reactLoose.useRef();
		let stickBottom: unknown = reactLoose.useRef(true);
		let lastMessageId: unknown = reactLoose.useRef(undefined);
		let sendAttempt: unknown = reactLoose.useRef(0);
		let sentHistory: unknown = reactLoose.useRef({});
		let recallIndex: unknown = reactLoose.useRef(0);
		let recallDraft: unknown = reactLoose.useRef("");
		let chatClaimHostRef: unknown = reactLoose.useRef(undefined);
		let headerReveal: unknown = luaCall(useStagger, 0, softMotion);
		let bannerReveal: unknown = luaCall(useStagger, 1, softMotion);
		let composerReveal: unknown = luaCall(useStagger, 2, softMotion);
		let statusReveal: unknown = luaCall(useStagger, 3, softMotion);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			return function(this: void): unknown | undefined {
				luaSet(sendAttempt, "current", ((luaProp(sendAttempt, "current") as unknown as number) + (1 as unknown as number)));
				return undefined;
			};
			return undefined;
		}, {});
		let enteredIds: unknown = reactLoose.useRef({});
		let listFrame: unknown = reactLoose.useRef(undefined);
		let count: unknown = len(luaProp(chat, "messages"));
		let latestMessageId: unknown = (((count as unknown as number) > (0 as unknown as number)) ? luaProp(luaIndex(luaProp(chat, "messages"), count), "id") : undefined);
		let tab: unknown = ((luaTruthy(luaProp(chat, "tab") ) ? luaProp(chat, "tab") :  "all"));
		let peer: unknown = ((tab === "whispers") ? luaProp(chat, "peer") : undefined);
		// searching the log shows only matching lines; the live log keeps scrolling underneath
		let filteringLog: unknown = ((luaTruthy(searchOpen ) ?  (!luaTruthy((string.match as unknown as (...a: unknown[]) => unknown)(logQuery, "^%s*$"))) : searchOpen));
		let shownMessages: unknown = luaProp(chat, "messages");
		if (((luaTruthy(filteringLog) || (tab !== "all")) || (luaProp(chat, "showGlobal") === false))) {
			shownMessages = {};
			for (const [_, message] of pairs((luaProp(chat, "messages")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let channel: unknown = ((luaTruthy(luaProp(message, "channel") ) ? luaProp(message, "channel") :  "server"));
				let keep: unknown = ((luaCall(luaProp(ChatRules, "inTab"), channel, tab) && (!((((tab === "all") && (channel === "global")) && (luaProp(chat, "showGlobal") === false))))) && ((((peer === undefined) || (channel === "system")) || (luaProp(message, "peerId") === peer))));
				if ((luaTruthy(keep) && luaTruthy(filteringLog))) {
					keep = luaCall(luaProp(ChatRules, "matches"), { text: ((luaTruthy(luaProp(message, "text") ) ? luaProp(message, "text") :  "")), username: ((luaTruthy(luaProp(message, "username") ) ? luaProp(message, "username") :  "")), displayName: ((luaTruthy(luaProp(message, "displayName") ) ? luaProp(message, "displayName") :  "")), channel: channel }, logQuery);
				}
				if (luaTruthy(keep)) {
					luaTable.insert(shownMessages, message);
				}
			}
		}
		let suggestions: unknown = (luaTruthy((string.match as unknown as (...a: unknown[]) => unknown)(draft, "^%s*$")) ? {} : luaCall(luaProp(chat, "suggest"), draft));
		let stackH: unknown = (((math.max as unknown as (...a: unknown[]) => unknown)(0, len(shownMessages)) as unknown as number) * (rowHeight as unknown as number));
		let topPad: unknown = (((viewHeight as unknown as number) > (0 as unknown as number)) ? (math.max as unknown as (...a: unknown[]) => unknown)(0, ((viewHeight as unknown as number) - (stackH as unknown as number))) : 0);
		let renderedIds: unknown = {};
		{
					let index: unknown = 0;
					while (((index as unknown as number) < (count as unknown as number))) {
						let message: unknown = luaIndex(luaProp(chat, "messages"), ((index as unknown as number) + (1 as unknown as number)));
						if ((message !== undefined)) {
							let _current: unknown = luaProp(enteredIds, "current");
							let _id: unknown = luaProp(message, "id");
							let animate: unknown = (!((luaIndex(_current, _id) !== undefined)));
							if (luaTruthy(animate)) {
								let _current_1: unknown = luaProp(enteredIds, "current");
								let _id_1: unknown = luaProp(message, "id");
								luaSetIndex(_current_1, _id_1, true);
							}
							luaSetIndex(renderedIds, luaProp(message, "id"), animate);
						}
						index = ((index as unknown as number) + (1 as unknown as number));
					}
				}
		let _size: unknown = 0;
		for (const [_] of pairs((luaProp(enteredIds, "current")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			_size = ((_size as unknown as number) + (1 as unknown as number));
		}
		if (((_size as unknown as number) > (((count as unknown as number) + (8 as unknown as number)) as unknown as number))) {
			let live: unknown = {};
			for (const [_, message] of pairs((luaProp(chat, "messages")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let _id: unknown = luaProp(message, "id");
				luaSetIndex(live, _id, true);
			}
			luaSet(enteredIds, "current", live);
		}
		let scrollToBottom: unknown = reactLoose.useCallback(function(this: void, force?: unknown): unknown | undefined {
			(task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				let frame: unknown = luaProp(listFrame, "current");
				if ((!luaTruthy(frame))) {
					return undefined;
				}
				if (((force !== true) && (!luaTruthy(luaProp(stickBottom, "current"))))) {
					return undefined;
				}
				let bottom: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(luaProp(luaProp(frame, "CanvasSize"), "Y"), "Offset") as unknown as number) - (luaProp(luaProp(frame, "AbsoluteWindowSize"), "Y") as unknown as number)));
				luaSet(frame, "CanvasPosition", new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, bottom));
				luaSet(stickBottom, "current", true);
				return undefined;
			});
			return undefined;
		}, [listFrame]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let frame: unknown = luaProp(listFrame, "current");
			if ((!luaTruthy(frame))) {
				return undefined;
			}
			let syncSize: unknown = function(this: void): unknown | undefined {
				return luaCall(setViewHeight, (math.max as unknown as (...a: unknown[]) => unknown)(0, luaProp(luaProp(frame, "AbsoluteWindowSize"), "Y")));
				return undefined;
			};
			luaCall(syncSize);
			let sizeConn: unknown = colon(colon(frame).GetPropertyChangedSignal("AbsoluteWindowSize")).Connect(syncSize);
			let scrollConn: unknown = colon(colon(frame).GetPropertyChangedSignal("CanvasPosition")).Connect(function(this: void): unknown | undefined {
				let maxY: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(luaProp(luaProp(frame, "CanvasSize"), "Y"), "Offset") as unknown as number) - (luaProp(luaProp(frame, "AbsoluteWindowSize"), "Y") as unknown as number)));
				luaSet(stickBottom, "current", ((luaProp(luaProp(frame, "CanvasPosition"), "Y") as unknown as number) >= (((maxY as unknown as number) - (NEAR_BOTTOM as unknown as number)) as unknown as number)));
				return undefined;
			});
			return function(this: void): unknown | undefined {
				colon(sizeConn).Disconnect();
				colon(scrollConn).Disconnect();
				return undefined;
			};
			return undefined;
		}, [listFrame, count, topPad]);
		// reading history: new messages are counted instead of yanking the list, and a button jumps back
		let unseen: unknown;
		let setUnseen: unknown;
		[unseen, setUnseen] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((latestMessageId !== luaProp(lastMessageId, "current"))) {
				if (((luaProp(lastMessageId, "current") !== undefined) && (!luaTruthy(luaProp(stickBottom, "current"))))) {
					luaCall(setUnseen, function(this: void, n?: unknown): unknown | undefined {
						return (math.min as unknown as (...a: unknown[]) => unknown)(99, ((n as unknown as number) + (1 as unknown as number)));
						return undefined;
					});
				}
				luaCall(scrollToBottom);
			}
			luaSet(lastMessageId, "current", latestMessageId);
			return undefined;
		}, [latestMessageId, scrollToBottom]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let frame: unknown = luaProp(listFrame, "current");
			if ((!luaTruthy(frame))) {
				return undefined;
			}
			let connection: unknown = colon(colon(frame).GetPropertyChangedSignal("CanvasPosition")).Connect(function(this: void): unknown | undefined {
				let maxY: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(0, ((luaProp(luaProp(luaProp(frame, "CanvasSize"), "Y"), "Offset") as unknown as number) - (luaProp(luaProp(frame, "AbsoluteWindowSize"), "Y") as unknown as number)));
				if (((luaProp(luaProp(frame, "CanvasPosition"), "Y") as unknown as number) >= (((maxY as unknown as number) - (NEAR_BOTTOM as unknown as number)) as unknown as number))) {
					luaCall(setUnseen, 0);
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				colon(connection).Disconnect();
				return undefined;
			};
			return undefined;
		}, [listFrame, count]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaCall(scrollToBottom, true);
			return undefined;
		}, [scrollToBottom]);
		let submit: unknown = function(this: void): unknown | undefined {
			let box: unknown = luaProp(input, "current");
			let outgoing: unknown = ((box !== undefined) ? luaProp(box, "Text") : draft);
			if ((((string.gsub as unknown as (...a: unknown[]) => unknown)(outgoing, "%s", "")) === "")) {
				return undefined;
			}
			let attempt: unknown = ((luaProp(sendAttempt, "current") as unknown as number) + (1 as unknown as number));
			luaSet(sendAttempt, "current", attempt);
			luaCall(luaProp(ChatRules, "remember"), luaProp(sentHistory, "current"), outgoing);
			luaSet(recallIndex, "current", 0);
			luaCall(setFailure, "");
			luaCall(setDraft, "");
			if ((box !== undefined)) {
				luaSet(box, "Text", "");
				(task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
					if ((luaProp(input, "current") === box)) {
						colon(box).CaptureFocus();
					}
					return undefined;
				});
			}
			luaSet(stickBottom, "current", true);
			luaCall(luaProp(chat, "send"), outgoing, function(this: void, ok?: unknown, reason?: unknown): unknown | undefined {
				if ((attempt !== luaProp(sendAttempt, "current"))) {
					return undefined;
				}
				if (luaTruthy(ok)) {
					luaCall(setFailure, "");
					luaCall(scrollToBottom, true);
				} else {
					let restore: unknown = luaProp(input, "current");
					if ((restore !== undefined)) {
						if ((((string.gsub as unknown as (...a: unknown[]) => unknown)(luaProp(restore, "Text"), "%s", "")) === "")) {
							luaSet(restore, "Text", outgoing);
							luaCall(setDraft, outgoing);
						}
					} else {
						luaCall(setDraft, function(this: void, current?: unknown): unknown | undefined {
							return ((((string.gsub as unknown as (...a: unknown[]) => unknown)(current, "%s", "")) === "") ? outgoing : current);
							return undefined;
						});
					}
					let _condition: unknown = reason;
					if ((_condition === undefined)) {
						_condition = "Message not sent.";
					}
					luaCall(setFailure, _condition);
				}
				return undefined;
			});
			return undefined;
		};
		// global and slash commands go through the server, so they don't wait on the TextChannel
		let canSend: unknown = ((((string.gsub as unknown as (...a: unknown[]) => unknown)(draft, "%s", "")) !== "") && ((((luaTruthy(luaProp(chat, "connected") ) ? luaProp(chat, "connected") :  (tab === "global"))) || ((string.match as unknown as (...a: unknown[]) => unknown)(draft, "^%s*/") !== undefined))));
		let applySuggestion: unknown = function(this: void, fill?: unknown): unknown | undefined {
			luaCall(setDraft, fill);
			let box: unknown = luaProp(input, "current");
			if ((box !== undefined)) {
				luaSet(box, "Text", fill);
				(task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
					if ((luaProp(input, "current") === box)) {
						colon(box).CaptureFocus();
						luaSet(box, "CursorPosition", ((len(fill) as unknown as number) + (1 as unknown as number)));
					}
					return undefined;
				});
			}
			return undefined;
		};
		// The "/" key asks for the box; wait a frame so the slash itself isn't typed into it.
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let requested: unknown = ((luaTruthy(luaProp(chat, "focusRequest") ) ? luaProp(chat, "focusRequest") :  0));
			if ((((requested as unknown as number) <= (0 as unknown as number)) || (((((os.clock as unknown as (...a: unknown[]) => unknown)() as unknown as number) - (requested as unknown as number)) as unknown as number) > (1 as unknown as number)))) {
				return;
			}
			let thread: unknown = (task.delay as unknown as (...a: unknown[]) => unknown)(0.05, function(this: void): unknown | undefined {
				let box: unknown = luaProp(input, "current");
				if (((box !== undefined) && luaTruthy(colon(box).IsDescendantOf(game)))) {
					colon(box).CaptureFocus();
					if ((luaProp(box, "Text") === "/")) {
						luaSet(box, "Text", "");
						luaCall(setDraft, "");
					}
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				(task.cancel as unknown as (...a: unknown[]) => unknown)(thread);
				return undefined;
			};
			return undefined;
		}, [luaProp(chat, "focusRequest")]);
		// Up / Down in the focused chat box walks back through what you sent; coming back down past
		// the newest message restores whatever you had been typing.
		reactLoose.useEffect(function(this: void): unknown | undefined {
			let connection: unknown = colon(luaProp(UserInputService, "InputBegan")).Connect(function(this: void, inputObject?: unknown): unknown | undefined {
				let box: unknown = luaProp(input, "current");
				if (((box === undefined) || (!luaTruthy(colon(box).IsFocused())))) {
					return;
				}
				let direction: unknown = ((luaProp(inputObject, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "Up")) ? 1 : ((luaProp(inputObject, "KeyCode") === luaProp(luaProp(Enum, "KeyCode"), "Down")) ? -1 : 0));
				if ((direction === 0)) {
					return;
				}
				if ((luaProp(recallIndex, "current") === 0)) {
					luaSet(recallDraft, "current", luaProp(box, "Text"));
				}
				let index: unknown;
				let text: unknown;
				[index, text] = luaCall(luaProp(ChatRules, "recall"), luaProp(sentHistory, "current"), luaProp(recallIndex, "current"), direction) as LuaTuple<[unknown, unknown]>;
				if ((index === luaProp(recallIndex, "current"))) {
					return;
				}
				luaSet(recallIndex, "current", index);
				let fill: unknown = ((index === 0) ? luaProp(recallDraft, "current") : text);
				luaCall(setDraft, fill);
				luaSet(box, "Text", fill);
				(task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
					if ((luaProp(input, "current") === box)) {
						luaSet(box, "CursorPosition", ((len(fill) as unknown as number) + (1 as unknown as number)));
					}
					return undefined;
				});
				return undefined;
			});
			return function(this: void): unknown | undefined {
				colon(connection).Disconnect();
				return undefined;
			};
			return undefined;
		}, {});
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if ((!luaTruthy(luaProp(UserInputService, "GamepadEnabled")))) {
				return undefined;
			}
			let host: unknown = luaProp(chatClaimHostRef, "current");
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
		}, [condensed, canSend]);
		let statusLabel: unknown = (luaTruthy(luaProp(chat, "connected")) ? "ONLINE" : "CONNECTING");
		let statusAccent: unknown = (luaTruthy(luaProp(chat, "connected")) ? luaProp(Palette, "mint") : luaProp(Palette, "mango"));
		let placeholder: unknown = ((failure !== "") ? failure : (luaTruthy(luaProp(chrome, "mobile")) ? (((tab === "global") ? "Message global…  (/help)" : ((tab === "server") ? "Message server…  (/help)" : ((tab === "crew") ? "Message crew…  (/help)" : ((tab === "friends") ? "Message friends…  (/help)" : ((tab === "whispers") ? "Private message…  (/help)" : "Message…  (/help)")))))) : (((luaTruthy(luaProp(chat, "placeholder") ) ? luaProp(chat, "placeholder") :  "Say something... (/help)")))));
		const phone = luaTruthy(luaProp(chrome, "mobile")) || luaTruthy(luaProp(viewport, "compact"));
		const gap = condensed ? 8 : mockGap(phone);
		// header: .pn h3 "Server chat" with the log count, then the ONLINE badge and the search toggle
		const tabLabel = (TAB_DEFS as { id: string; label: string }[]).find((def) => def.id === tab)?.label ?? "Server";
		const heading = React.createElement("frame", { key: "heading", Size: new UDim2(1, 0, 0, 44), BackgroundTransparency: 1, LayoutOrder: 0 },
			React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Horizontal, VerticalAlignment: Enum.VerticalAlignment.Center, Padding: new UDim(0, 10), SortOrder: Enum.SortOrder.LayoutOrder }),
			React.createElement("frame", { Size: new UDim2(0, 0, 0, 22), BackgroundTransparency: 1, LayoutOrder: 0 },
				React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
				React.createElement(PanelHeading, {
					icon: "Chat.3",
					title: tab === "all" || tab === "server" ? (phone ? "Server" : "Server chat") : `${tabLabel} chat`,
					note: luaTruthy(filteringLog) ? `${len(shownMessages)} of ${count} match` : `${count} log${count === 1 ? "" : "s"} · Roblox-filtered`,
					accent: P.mint,
					phone,
				}),
			),
			showStatus ? React.createElement("frame", { Size: UDim2.fromOffset(phone ? 96 : 112, 26), BackgroundTransparency: 1, LayoutOrder: 1 }, reactLoose.createElement(Badge, { value: statusLabel, accent: statusAccent, filled: true, size: UDim2.fromScale(1, 1) }) as React.Element) : undefined,
			showStatus
				? React.createElement("frame", { Size: UDim2.fromOffset(44, 44), BackgroundTransparency: 1, LayoutOrder: 2 },
						reactLoose.createElement(Button, { text: "", icon: luaTruthy(searchOpen) ? "Close.5" : "Search.7", onClick: () => {
							if (luaTruthy(searchOpen)) {
								luaCall(setLogQuery, "");
							}
							luaCall(setSearchOpen, !luaTruthy(searchOpen));
						}, color: luaTruthy(searchOpen) ? P.mint : SEC, textColor: luaTruthy(searchOpen) ? P.ink : P.cream, size: UDim2.fromScale(1, 1), reducedMotion: softMotion }) as React.Element)
				: undefined,
		);
		const children: React.Element[] = [heading];
		// channel tabs: All / Global / Server / Crew / Friends / Whispers with their unread counts
		const unreadByTab = (luaProp(chat, "unreadByTab") ?? {}) as Record<string, number>;
		const tabOptions = (TAB_DEFS as { id: string; label: string }[]).map((def) => {
			const waiting = unreadByTab[def.id] ?? 0;
			return { id: def.id, label: waiting > 0 ? `${def.label} ${waiting}` : def.label };
		});
		const tabColumns = luaTruthy(luaProp(viewport, "compact")) ? 3 : tabOptions.size();
		const tabsH = segmentedHeight(tabOptions.size(), tabColumns, viewport as never, TAB_ROW_H as number, 6);
		children.push(React.createElement("frame", { key: "tabs", Size: new UDim2(1, 0, 0, tabsH), BackgroundTransparency: 1, LayoutOrder: 1 },
			reactLoose.createElement(SegmentedTabs, { options: tabOptions, value: tab, onChange: luaProp(chat, "setTab"), accent: P.mint, columns: tabColumns, gap: 6, size: UDim2.fromScale(1, 1), reducedMotion: softMotion }) as React.Element));
		if (showStatus && luaTruthy(searchOpen)) {
			children.push(React.createElement("frame", { key: "search", Size: new UDim2(1, 0, 0, 44), BackgroundTransparency: 1, LayoutOrder: 2 },
				reactLoose.createElement(SearchField, { value: logQuery, onChange: setLogQuery, placeholder: "Search words, from:name or in:global", accent: P.mint, reducedMotion: softMotion, size: UDim2.fromScale(1, 1), zIndex: 22 }) as React.Element));
		}
		// whisper threads: a side list on wide windows, a one-row chip rail otherwise
		const whispers = (luaProp(chat, "whispers") ?? {}) as { userId: number; displayName: string; unread?: number; online?: boolean }[];
		const hasWhispers = tab === "whispers" && whispers.size() > 0;
		const peerSide = hasWhispers && !luaTruthy(luaProp(viewport, "compact")) && (luaProp(viewport, "width") as number) >= CHAT_PEER_SIDE_MIN;
		const peerButtons: React.Element[] = [];
		const peerChips: { key: string; element: unknown }[] = [];
		if (hasWhispers) {
			for (const entry of whispers) {
				const selected = entry.userId === luaProp(chat, "peer");
				let label = entry.displayName;
				if ((entry.unread ?? 0) > 0) {
					label = `${label} (${entry.unread})`;
				}
				if (entry.online === false) {
					label = `${label} · away`;
				}
				const pick = () => luaCall(luaProp(chat, "setPeer"), entry.userId);
				peerButtons.push(React.createElement("frame", { key: `peer-${entry.userId}`, Size: new UDim2(1, 0, 0, (PEER_ROW_H as number) - 4), LayoutOrder: peerButtons.size(), BackgroundTransparency: 1, BorderSizePixel: 0 },
					reactLoose.createElement(Button, { text: label, onClick: pick, color: selected ? P.violet : SEC, textColor: selected ? P.ink : P.cream, size: UDim2.fromScale(1, 1), reducedMotion: softMotion }) as React.Element));
				peerChips.push({ key: `peer-${entry.userId}`, element: reactLoose.createElement(Button, { text: label, onClick: pick, color: selected ? P.violet : SEC, textColor: selected ? P.ink : P.cream, size: UDim2.fromOffset(0, (PEER_ROW_H as number) - 4), hug: true, reducedMotion: softMotion }) });
			}
			if (!peerSide) {
				children.push(React.createElement("frame", { key: "peers", Size: new UDim2(1, 0, 0, PEER_ROW_H as number), BackgroundTransparency: 1, LayoutOrder: 3 }, luaCall(chipRail, peerChips, undefined) as React.Element));
			}
		}
		const emptyLine = (text: string) =>
			React.createElement("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1 },
				React.createElement("uipadding", { PaddingTop: new UDim(0, 20) }),
				React.createElement(Line, { text, size: 14, font: BODY, color: P.muted, width: new UDim(1, 0), height: 40, align: Enum.TextXAlignment.Center }));
		const messagesPane =
			!luaTruthy(filteringLog) && len(shownMessages) === 0
				? emptyLine(tab === "whispers" ? "No whispers yet. Type /w name message to start one." : tab === "friends" ? "Nothing from friends in this server yet." : tab === "crew" ? "Crew chat is private to your crew. Start one on the Crew page." : tab === "global" ? "Global chat is quiet. Say hello to every server." : "Nobody has said anything here yet. Say hi.")
				: luaTruthy(filteringLog) && len(shownMessages) === 0
					? emptyLine(`No messages match "${logQuery}".`)
					: React.createElement("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1 },
							reactLoose.createElement(FlatList, { data: shownMessages, itemHeight: rowHeight, headerHeight: topPad, overscan: luaTruthy(softMotion) ? 0 : luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2, canvasTail: 0, Size: UDim2.fromScale(1, 1), scrollBarColor: P.mint, scrollBarThickness: 4, scrollBarTransparency: 0.12, ZIndex: 10, frameRef: listFrame, keyExtractor: (message: unknown) => luaProp(message, "id"), renderItem: (_item: unknown) => {
								const message = luaProp(_item, "item");
								const animate = luaIndex(renderedIds, luaProp(message, "id")) === true;
								return reactLoose.createElement(MessageRow, { message, reducedMotion: softMotion, bodySize, animate, rowHeight, onWhisper: !luaTruthy(luaProp(message, "system")) && luaProp(chat, "openWhisper") !== undefined && !luaTruthy(luaProp(message, "remote")) ? (userId: unknown) => luaCall(luaProp(chat, "openWhisper"), userId) : undefined });
							} }) as React.Element,
							// reading history: the "N new messages" pill floats over the bottom of the list
							(unseen as number) > 0
								? React.createElement("frame", { Name: "NewMessages", Size: UDim2.fromOffset(0, 40), AutomaticSize: Enum.AutomaticSize.X, AnchorPoint: new Vector2(0.5, 1), Position: new UDim2(0.5, 0, 1, -12), BackgroundTransparency: 1, ZIndex: 30 },
										reactLoose.createElement(Button, { text: `${unseen} new message${unseen === 1 ? "" : "s"}`, icon: "Chat.4", color: P.mint, textColor: P.ink, hug: true, reducedMotion: softMotion, size: UDim2.fromOffset(0, 40), zIndex: 30, onClick: () => {
											luaCall(setUnseen, 0);
											luaCall(scrollToBottom, true);
										} }) as React.Element)
								: undefined,
						);
		children.push(React.createElement("frame", { key: "messages", Name: "Messages", Size: new UDim2(1, 0, 0, 120), BackgroundTransparency: 1, LayoutOrder: 4 },
			React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
			peerSide
				? React.createElement("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0 },
						React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Horizontal, Padding: new UDim(0, 10), SortOrder: Enum.SortOrder.LayoutOrder }),
						React.createElement("scrollingframe", { Name: "WhisperPeers", Size: new UDim2(0, CHAT_PEER_SIDE_W, 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, CanvasSize: new UDim2(), AutomaticCanvasSize: Enum.AutomaticSize.Y, ScrollBarThickness: 3, ScrollBarImageColor3: P.violet, SelectionGroup: true, LayoutOrder: 0 },
							React.createElement("uilistlayout", { SortOrder: Enum.SortOrder.LayoutOrder, Padding: new UDim(0, 6) }),
							React.createElement("uipadding", { PaddingRight: new UDim(0, 6) }),
							...peerButtons),
						React.createElement("frame", { Name: "Thread", Size: new UDim2(0, 0, 1, 0), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 1 },
							React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
							messagesPane))
				: messagesPane));
		if (showBanner) {
			children.push(React.createElement(MockRow, { key: "banner", title: "Keep it clean", sub: "Roblox filters messages. /help for shortcuts.", icon: "Forge.18", accent: P.mango, phone, layoutOrder: 5, height: BANNER_HEIGHT as number }));
		}
		const suggestions2 = suggestions as { kind?: string; label: string; detail?: string; fill: string }[];
		if (len(suggestions2) > 0) {
			const chips = suggestions2.map((suggestion, index) => ({ key: `suggest-${index + 1}`, element: reactLoose.createElement(Button, { text: suggestion.kind === "command" ? suggestion.label : `${suggestion.label}  ${suggestion.detail}`, onClick: () => luaCall(applySuggestion, suggestion.fill), color: index === 0 ? P.mint : SEC, textColor: index === 0 ? P.ink : P.cream, size: UDim2.fromOffset(0, (SUGGEST_ROW_H as number) - 4), hug: true, reducedMotion: softMotion }) }));
			children.push(React.createElement("frame", { key: "suggest", Size: new UDim2(1, 0, 0, SUGGEST_ROW_H as number), BackgroundTransparency: 1, LayoutOrder: 6 }, luaCall(chipRail, chips, 24) as React.Element));
		}
		// .flexr input: the "Say something" chip (fills) and the icon send button
		const fieldH = math.max(TapTarget, (inputHeight as number) - 14);
		children.push(React.createElement("frame", { key: "input", Name: "Composer", Size: new UDim2(1, 0, 0, fieldH), BackgroundTransparency: 1, LayoutOrder: 7, ClipsDescendants: false },
			React.createElement("uilistlayout", { FillDirection: Enum.FillDirection.Horizontal, VerticalAlignment: Enum.VerticalAlignment.Center, Padding: new UDim(0, gap), SortOrder: Enum.SortOrder.LayoutOrder }),
			React.createElement("frame", { Name: "Field", Size: new UDim2(0, 0, 1, 0), BackgroundColor3: P.white, BackgroundTransparency: 0.95, BorderSizePixel: 0, LayoutOrder: 0 },
				React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
				React.createElement("uicorner", { CornerRadius: new UDim(0, 8) }),
				React.createElement("uistroke", { Color: failure !== "" ? P.coral : P.white, Transparency: failure !== "" ? 0.45 : 0.9, Thickness: 1, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
				React.createElement("uipadding", { PaddingLeft: new UDim(0, 14), PaddingRight: new UDim(0, 14) }),
				React.createElement("textbox", { ref: input as never, Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClearTextOnFocus: false, Text: draft as string, PlaceholderText: placeholder as string, PlaceholderColor3: failure !== "" ? P.coral : P.muted, TextColor3: P.cream, TextSize: 16, FontFace: BODY, TextXAlignment: Enum.TextXAlignment.Left, TextYAlignment: Enum.TextYAlignment.Center, TextTruncate: Enum.TextTruncate.None, TextScaled: false, MultiLine: false, TextEditable: true, MaxVisibleGraphemes: DRAFT_LIMIT as number,
					Change: { Text: (box: TextBox) => luaCall(setDraft, luaCall(luaProp(ChatText, "limit"), box.Text, DRAFT_LIMIT)) },
					Event: {
						Focused: () => colon(Audio).play("inputFocus"),
						FocusLost: (_box: TextBox, enterPressed: boolean) => {
							if (enterPressed) {
								luaCall(submit);
							}
						},
					} }),
			),
			React.createElement("frame", { Name: "ChatClaimActions", ref: chatClaimHostRef as never, Size: UDim2.fromOffset(phone ? fieldH : 0, fieldH), AutomaticSize: phone ? Enum.AutomaticSize.None : Enum.AutomaticSize.X, BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, LayoutOrder: 1 },
				reactLoose.createElement(Button, { text: phone ? "" : "SEND", icon: "Send.4", onClick: submit, color: P.mint, textColor: P.ink, size: phone ? UDim2.fromScale(1, 1) : UDim2.fromOffset(0, fieldH), hug: !phone, disabled: !luaTruthy(canSend), reducedMotion, highlight: canSend }) as React.Element),
		));
		// .pn.f1 "Server chat": the brass-ruled panel holds the whole conversation, top to bottom
		return React.createElement(MockPanel as never, { size: UDim2.fromScale(1, 1), phone, accent: P.brass, gap, name: "ChatPanel", reducedMotion: softMotion } as never, ...children);
	}
	return { ChatView: ChatView };
}
export = __member();
