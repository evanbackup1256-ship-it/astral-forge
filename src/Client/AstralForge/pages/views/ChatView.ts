import React from "@rbxts/react";
import { frameStroke } from "../../CoreKit/profileFrame";
import { segmentedHeight } from "../../UiCore/ui";
import ReactRoblox from "@rbxts/react-roblox";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable, luaRequire, instChild, kit, mod } from "./viewRuntime";

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
	let ROW_HEIGHT: unknown = 98;
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
	let TAG_COLORS: unknown = [luaProp(Palette, "cyan"), luaProp(Palette, "mint"), luaProp(Palette, "violet"), luaProp(Palette, "mango"), luaProp(Palette, "pink"), luaProp(Palette, "blue")];
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
	function MessageRow(_param?: unknown): unknown | undefined {
		let message: unknown = luaProp(_param, "message");
		let position: unknown = luaProp(_param, "position");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let bodySize: unknown = luaProp(_param, "bodySize");
		let animate: unknown = luaProp(_param, "animate");
		let rowHeight: unknown = luaProp(_param, "rowHeight");
		let softMotion: unknown = reducedMotion;
		let enter: unknown = luaCall(useMessageEntrance, animate, reducedMotion);
		let accent: unknown = (luaTruthy(luaProp(message, "system")) ? luaProp(Palette, "mango") : (luaProp(message, "profileAccent") ?? luaCall(userColor, luaProp(message, "userId"))));
		// the sender's chosen profile frame on their mark ring (default frame: unchanged 1px ring)
		const markRing = frameStroke(luaTruthy(luaProp(message, "system")) ? undefined : (luaProp(message, "profileFrame") as string | undefined), accent as Color3);
		let authorId: unknown = (tonumber(luaProp(message, "userId")) || 0);
		if (((authorId !== authorId) || ((math.abs as unknown as (...a: unknown[]) => unknown)(authorId) === luaProp(math, "huge")))) {
			authorId = 0;
		}
		let pulse: unknown = luaCall(usePulse, (!luaTruthy(luaProp(message, "system"))), ((2.4 as unknown as number) + ((((math.abs as unknown as (...a: unknown[]) => unknown)(((authorId as unknown as number) % (5 as unknown as number))) as unknown as number) * (0.14 as unknown as number)) as unknown as number)));
		let fade: unknown = colon(enter).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (amount as unknown as number));
			return undefined;
		});
		let cardY: unknown = (luaTruthy(luaProp(message, "system")) ? (math.floor as unknown as (...a: unknown[]) => unknown)((((((rowHeight as unknown as number) - (SYSTEM_CARD_H as unknown as number))) as unknown as number) / (2 as unknown as number))) : 4);
		let cardH: unknown = (luaTruthy(luaProp(message, "system")) ? SYSTEM_CARD_H : (math.max as unknown as (...a: unknown[]) => unknown)(CARD_H, ((rowHeight as unknown as number) - (8 as unknown as number))));
		if (luaTruthy(luaProp(message, "system"))) {
			return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, rowHeight), Position: position, BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, cardH), Position: colon(enter).map(function(this: void, amount?: unknown): unknown | undefined {
				return luaCall(luaProp(UDim2, "fromOffset"), (math.round as unknown as (...a: unknown[]) => unknown)((((((1 as unknown as number) - (amount as unknown as number))) as unknown as number) * (14 as unknown as number))), ((cardY as unknown as number) + ((math.round as unknown as (...a: unknown[]) => unknown)((((((1 as unknown as number) - (amount as unknown as number))) as unknown as number) * (8 as unknown as number))) as unknown as number)));
				return undefined;
			}), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0, 0), BackgroundColor3: luaProp(Palette, "panelRaised"), BackgroundTransparency: colon(fade).map(function(this: void, amount?: unknown): unknown | undefined {
				return ((0.08 as unknown as number) + (((amount as unknown as number) * (0.92 as unknown as number)) as unknown as number));
				return undefined;
			}), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uiscale", { Scale: colon(enter).map(function(this: void, amount?: unknown): unknown | undefined {
				return ((0.97 as unknown as number) + (((amount as unknown as number) * (0.03 as unknown as number)) as unknown as number));
				return undefined;
			}) }), reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { Color: accent, Thickness: 1, Transparency: colon(fade).map(function(this: void, amount?: unknown): unknown | undefined {
				return ((0.42 as unknown as number) + (((amount as unknown as number) * (0.58 as unknown as number)) as unknown as number));
				return undefined;
			}) }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 1, -12), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 6), BackgroundColor3: accent, BackgroundTransparency: fade, BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 38, 38), Position: luaCall(luaProp(UDim2, "fromOffset"), 14, 14), BackgroundColor3: luaCall(darken, accent, 0.62), BackgroundTransparency: fade, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 10) }), reactLoose.createElement(Icon, { kind: "Chat.2", color: luaProp(Palette, "ink"), accent: accent, size: 22, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 8), spin: false })), reactLoose.createElement(Text, { value: "Game message", size: 12, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 64, 12), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -78, 0, 16), transparency: fade }), reactLoose.createElement(Text, { value: luaProp(message, "text"), size: bodySize, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Medium"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 64, 32), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -78, 0, 28), transparency: fade })));
		}
		return reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, rowHeight), Position: position, BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, cardH), Position: colon(enter).map(function(this: void, amount?: unknown): unknown | undefined {
			return luaCall(luaProp(UDim2, "fromOffset"), (math.round as unknown as (...a: unknown[]) => unknown)((((((1 as unknown as number) - (amount as unknown as number))) as unknown as number) * (14 as unknown as number))), ((cardY as unknown as number) + ((math.round as unknown as (...a: unknown[]) => unknown)((((((1 as unknown as number) - (amount as unknown as number))) as unknown as number) * (10 as unknown as number))) as unknown as number)));
			return undefined;
		}), BackgroundColor3: (luaTruthy(luaProp(message, "mention")) ? luaCall(darken, luaProp(Palette, "mango"), 0.8) : (luaTruthy(luaProp(message, "localPlayer")) ? luaCall(darken, accent, 0.88) : luaProp(Palette, "panel"))), BackgroundTransparency: colon(fade).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((0.04 as unknown as number) + (((amount as unknown as number) * (0.96 as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uiscale", { Scale: colon(enter).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((0.97 as unknown as number) + (((amount as unknown as number) * (0.03 as unknown as number)) as unknown as number));
			return undefined;
		}) }), reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { Color: (luaTruthy(luaProp(message, "mention")) ? luaProp(Palette, "mango") : accent), Thickness: (luaTruthy(luaProp(message, "mention")) ? 2 : 1), Transparency: colon(fade).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((((luaTruthy(luaProp(message, "mention")) ? 0.1 : (luaTruthy(luaProp(message, "localPlayer")) ? 0.32 : 0.58))) as unknown as number) + (((amount as unknown as number) * (0.42 as unknown as number)) as unknown as number));
			return undefined;
		}) }), ((luaProp(message, "artifactElement") !== undefined) && reactLoose.createElement(ElementFx, { element: luaProp(message, "artifactElement"), size: luaCall(luaProp(UDim2, "fromOffset"), 64, 64), position: luaCall(luaProp(UDim2, "fromOffset"), 33, 38), transparency: 0.25, reducedMotion: reducedMotion })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 42, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 12, 17), BackgroundColor3: luaCall(darken, accent, 0.5), BackgroundTransparency: fade, BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uistroke", { Color: markRing.color, Thickness: markRing.thickness, Transparency: colon(pulse).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((0.2 as unknown as number) + (((amount as unknown as number) * (0.4 as unknown as number)) as unknown as number));
			return undefined;
		}) }, markRing.gradient !== undefined ? reactLoose.createElement("uigradient", { Color: markRing.gradient, Rotation: 35 }) : undefined), reactLoose.createElement(PlayerMark, { userId: luaProp(message, "userId"), color: luaProp(Palette, "ink"), accent: accent, size: 26, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 8) }), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 10, 10), Position: luaCall(luaProp(UDim2, "fromOffset"), 30, 30), BackgroundColor3: luaProp(Palette, "green"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "ink"), Thickness: 1 }))), reactLoose.createElement(Text, { value: luaProp(message, "displayName"), size: 15, color: accent, weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 10, position: luaCall(luaProp(UDim2, "fromOffset"), 66, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((MESSAGE_RIGHT as unknown as number)) as unknown as number) + ((((luaProp(message, "artifactName") !== undefined) ? ((ARTIFACT_CHIP_W as unknown as number) + (6 as unknown as number)) : 0)) as unknown as number))) as unknown as number)), 0, 18), transparency: fade }), ((luaProp(message, "artifactName") !== undefined) && reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), ARTIFACT_CHIP_W, 20), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((78 as unknown as number) + (ARTIFACT_CHIP_W as unknown as number))) as unknown as number)), 0, 9), BackgroundColor3: luaCall(darken, ((luaTruthy(luaProp(message, "artifactColor") ) ? luaProp(message, "artifactColor") :  accent)), 0.72), BackgroundTransparency: colon(fade).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((0.1 as unknown as number) + (((amount as unknown as number) * (0.9 as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), reactLoose.createElement("uistroke", { Color: ((luaTruthy(luaProp(message, "artifactColor") ) ? luaProp(message, "artifactColor") :  accent)), Thickness: 1, Transparency: colon(pulse).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((0.25 as unknown as number) + (((amount as unknown as number) * (0.35 as unknown as number)) as unknown as number));
			return undefined;
		}) }), ((luaProp(message, "artifactElement") !== undefined) && reactLoose.createElement(ElementFx, { element: luaProp(message, "artifactElement"), size: luaCall(luaProp(UDim2, "fromOffset"), 22, 22), position: luaCall(luaProp(UDim2, "fromOffset"), 12, 10), reducedMotion: reducedMotion })), reactLoose.createElement(Text, { value: (string.upper as unknown as (...a: unknown[]) => unknown)(luaProp(message, "artifactName")), size: 10, color: luaCall(lighten, ((luaTruthy(luaProp(message, "artifactColor") ) ? luaProp(message, "artifactColor") :  accent)), 0.2), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 8, position: luaCall(luaProp(UDim2, "fromOffset"), 24, 3), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -30, 0, 14), transparency: fade }))), ((luaProp(message, "titleName") !== undefined) ? reactLoose.createElement(AnimatedTitle, { text: luaProp(message, "titleName"), fx: luaProp(message, "titleFx"), size: 12, reducedMotion: reducedMotion, inline: true, position: luaCall(luaProp(UDim2, "fromOffset"), 66, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((MESSAGE_RIGHT as unknown as number))) as unknown as number)), 0, 18), transparency: fade }) : reactLoose.createElement(Text, { value: `@${luaProp(message, "username")}`, size: 12, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 66, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -80, 0, 16), transparency: fade })), reactLoose.createElement(Badge, { value: luaCall(channelBadge, message), accent: ((luaProp(message, "titleFx") !== undefined) ? luaCall(titleFxAccent, luaProp(message, "titleFx")) : accent), filled: true, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -72, 0, 10), size: luaCall(luaProp(UDim2, "fromOffset"), 62, 26) }), reactLoose.createElement(Text, { value: luaCall(luaProp(ChatRules, "clock"), luaProp(message, "at")), size: 11, color: luaProp(Palette, "muted"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -72, 0, 38), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 62, 16), transparency: fade }), ((((luaProp(_param, "onWhisper") !== undefined) && (!luaTruthy(luaProp(message, "localPlayer")))) && reactLoose.createElement("textbutton", { Name: "WhisperAuthor", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((MESSAGE_RIGHT as unknown as number))) as unknown as number)), 0, 24), Position: luaCall(luaProp(UDim2, "fromOffset"), 66, 6), BackgroundTransparency: 1, Text: "", AutoButtonColor: false, ZIndex: 5, [luaProp(luaProp(React, "Event"), "Activated") as never]: function(this: void): unknown | undefined {
			luaCall(luaProp(_param, "onWhisper"), luaProp(message, "userId"));
			return undefined;
		} })) || undefined), ((luaProp(message, "titleName") !== undefined) && reactLoose.createElement(Text, { value: `@${luaProp(message, "username")}`, size: 11, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 66, 46), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -80, 0, 14), transparency: fade })), reactLoose.createElement(Text, { value: luaProp(message, "text"), size: ((bodySize as unknown as number) + (1 as unknown as number)), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Medium"), wrap: true, position: luaCall(luaProp(UDim2, "fromOffset"), 66, ((luaProp(message, "titleName") !== undefined) ? 62 : 48)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -78, 0, (math.max as unknown as (...a: unknown[]) => unknown)(((luaProp(message, "titleName") !== undefined) ? 26 : 34), ((cardH as unknown as number) - ((((luaProp(message, "titleName") !== undefined) ? 70 : 56)) as unknown as number)))), transparency: fade })));
		return undefined;
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
		let rowHeight: unknown = (math.floor as unknown as (...a: unknown[]) => unknown)(((((((luaTruthy(luaProp(chrome, "mobile")) ? 144 : ROW_HEIGHT)) as unknown as number) * ((math.max as unknown as (...a: unknown[]) => unknown)(1, ((textScale as unknown as number) * (0.95 as unknown as number))) as unknown as number)) as unknown as number) + (0.5 as unknown as number)));
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
		let statusAccent: unknown = (luaTruthy(luaProp(chat, "connected")) ? luaProp(Palette, "green") : luaProp(Palette, "mango"));
		let placeholder: unknown = ((failure !== "") ? failure : (luaTruthy(luaProp(chrome, "mobile")) ? (((tab === "global") ? "Message global…  (/help)" : ((tab === "server") ? "Message server…  (/help)" : ((tab === "crew") ? "Message crew…  (/help)" : ((tab === "friends") ? "Message friends…  (/help)" : ((tab === "whispers") ? "Private message…  (/help)" : "Message…  (/help)")))))) : (((luaTruthy(luaProp(chat, "placeholder") ) ? luaProp(chat, "placeholder") :  "Say something... (/help)")))));
		let statusElement: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, ClipsDescendants: true, ZIndex: 20 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "lineSoft"), Thickness: 1, Transparency: 0.5 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 1, -16), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 8), BackgroundColor3: luaProp(Palette, "cyan"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 42, 42), Position: luaCall(luaProp(UDim2, "fromOffset"), 14, 11), BackgroundColor3: luaCall(darken, luaProp(Palette, "cyan"), 0.72), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 11) }), reactLoose.createElement("uigradient", { Color: new (ColorSequence as unknown as new (...args: unknown[]) => unknown)(luaCall(lighten, luaProp(Palette, "cyan"), 0.15), luaCall(darken, luaProp(Palette, "cyan"), 0.45)), Rotation: 120 }), reactLoose.createElement(Icon, { kind: "Chat.3", color: luaProp(Palette, "ink"), accent: luaProp(Palette, "cyan"), size: 26, position: luaCall(luaProp(UDim2, "fromOffset"), 8, 8), spin: false, reducedMotion: softMotion })), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((((STATUS_RESERVE as unknown as number) + (68 as unknown as number)) as unknown as number) + (52 as unknown as number))) as unknown as number)), 0, 48), Position: luaCall(luaProp(UDim2, "fromOffset"), 68, 8), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false }, reactLoose.createElement(Text, { value: "Chat", size: 18, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 24), transparency: colon(headerReveal).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (amount as unknown as number));
			return undefined;
		}) }), reactLoose.createElement(Text, { value: (luaTruthy(filteringLog) ? `${len(shownMessages)} of ${count} match` : `${count} log${((count === 1) ? "" : "s")}  ·  Roblox-filtered`), size: 13, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 0, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 18), transparency: colon(((luaTruthy(showBanner) ? bannerReveal : statusReveal))).map(function(this: void, amount?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (amount as unknown as number));
			return undefined;
		}) })), reactLoose.createElement(Button, { text: "", icon: (luaTruthy(searchOpen) ? "Close.5" : "Search.7"), onClick: function(this: void): unknown | undefined {
			if (luaTruthy(searchOpen)) {
				luaCall(setLogQuery, "");
			}
			luaCall(setSearchOpen, (!luaTruthy(searchOpen)));
			return undefined;
		}, color: (luaTruthy(searchOpen) ? luaProp(Palette, "cyan") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(searchOpen) ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: luaCall(luaProp(UDim2, "fromOffset"), 44, 44), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((STATUS_RESERVE as unknown as number) + (48 as unknown as number))) as unknown as number)), 0.5, -22), reducedMotion: softMotion }), reactLoose.createElement(Badge, { value: statusLabel, accent: statusAccent, filled: true, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((STATUS_RESERVE as unknown as number) - (4 as unknown as number))) as unknown as number)), 0.5, -13), size: luaCall(luaProp(UDim2, "fromOffset"), ((STATUS_RESERVE as unknown as number) - (16 as unknown as number)), 26) }));
		let composerSoft: unknown = ((luaTruthy(reducedMotion ) ? reducedMotion :  (composerReveal === undefined)));
		let _chatSoftKeep: unknown = (luaTruthy(composerSoft) ? bannerReveal : statusReveal);
		let messagesElement: unknown = reactLoose.createElement(FlatList, { data: shownMessages, itemHeight: rowHeight, headerHeight: topPad, overscan: (luaTruthy(softMotion) ? 0 : (luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2)), canvasTail: 0, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), scrollBarColor: luaProp(Palette, "cyan"), scrollBarThickness: 4, scrollBarTransparency: 0.12, ZIndex: 10, frameRef: listFrame, keyExtractor: function(this: void, message?: unknown): unknown | undefined {
			return luaProp(message, "id");
			return undefined;
		}, renderItem: function(this: void, _param_1?: unknown): unknown | undefined {
			let message: unknown = luaProp(_param_1, "item");
			let animate: unknown = (luaIndex(renderedIds, luaProp(message, "id")) === true);
			return reactLoose.createElement(MessageRow, { message: message, reducedMotion: softMotion, bodySize: bodySize, animate: animate, rowHeight: rowHeight, onWhisper: ((((!luaTruthy(luaProp(message, "system"))) && (luaProp(chat, "openWhisper") !== undefined)) && (!luaTruthy(luaProp(message, "remote")))) ? function(this: void, userId?: unknown): unknown | undefined {
				luaCall(luaProp(chat, "openWhisper"), userId);
				return undefined;
			} : undefined) });
			return undefined;
		} });
		if (((unseen as unknown as number) > (0 as unknown as number))) {
			messagesElement = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1 }, messagesElement, reactLoose.createElement(Button, { text: `${unseen} new message${((unseen === 1) ? "" : "s")}`, icon: "Chat.4", color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink"), hug: true, reducedMotion: softMotion, size: luaCall(luaProp(UDim2, "fromOffset"), 0, 40), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, -90, 1, -52), zIndex: 30, onClick: function(this: void): unknown | undefined {
				luaCall(setUnseen, 0);
				luaCall(scrollToBottom, true);
				return undefined;
			} }));
		}
		let bannerElement: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0, ClipsDescendants: true, ZIndex: 20 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Layout, "cardRadius")) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "mango"), Thickness: 1, Transparency: 0.32 }), reactLoose.createElement("frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 3, 1, -12), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, 6), BackgroundColor3: luaProp(Palette, "mango"), BorderSizePixel: 0 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 2) })), reactLoose.createElement(Icon, { kind: "Forge.18", color: luaProp(Palette, "ink"), accent: luaProp(Palette, "mango"), size: 24, position: luaCall(luaProp(UDim2, "fromOffset"), 14, 14), spin: false, reducedMotion: softMotion }), reactLoose.createElement(Text, { value: "Keep it clean", size: 12, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: false, position: luaCall(luaProp(UDim2, "fromOffset"), 48, 8), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -60, 0, 16) }), reactLoose.createElement(Text, { value: "Roblox filters messages. /help for shortcuts.", size: 13, minSize: 10, color: luaProp(Palette, "creamSoft"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, position: luaCall(luaProp(UDim2, "fromOffset"), 48, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -60, 0, 16) }));
		let inputElement: unknown = reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "panelRaised"), BorderSizePixel: 0, ClipsDescendants: false, ZIndex: 20 }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), reactLoose.createElement("uistroke", { Color: ((failure !== "") ? luaProp(Palette, "coral") : luaProp(Palette, "lineSoft")), Thickness: 1, Transparency: 0.45 }), reactLoose.createElement("textbox", { ref: input, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -148, 1, -14), Position: luaCall(luaProp(UDim2, "fromOffset"), 14, 7), BackgroundTransparency: 1, BorderSizePixel: 0, ClearTextOnFocus: false, Text: draft, PlaceholderText: placeholder, PlaceholderColor3: ((failure !== "") ? luaProp(Palette, "coral") : luaProp(Palette, "muted")), TextColor3: luaProp(Palette, "cream"), TextSize: 16, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Left"), TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center"), TextTruncate: luaProp(luaProp(Enum, "TextTruncate"), "None"), TextScaled: false, MultiLine: false, TextEditable: true, MaxVisibleGraphemes: DRAFT_LIMIT, Change: { Text: function(this: void, box?: unknown): unknown | undefined {
			return luaCall(setDraft, luaCall(luaProp(ChatText, "limit"), luaProp(box, "Text"), DRAFT_LIMIT));
			return undefined;
		} }, Event: { Focused: function(this: void): unknown | undefined {
			return colon(Audio).play("inputFocus");
			return undefined;
		}, FocusLost: function(this: void, _box?: unknown, enterPressed?: unknown): unknown | undefined {
			if (luaTruthy(enterPressed)) {
				luaCall(submit);
			}
			return undefined;
		} } }), reactLoose.createElement("frame", { Name: "ChatClaimActions", Size: luaCall(luaProp(UDim2, "fromOffset"), 0, 48), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(1, 0.5), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0.5, 0), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ref: chatClaimHostRef }, reactLoose.createElement(Button, { text: "SEND", icon: "Send.4", onClick: submit, color: luaProp(Palette, "cyan"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromOffset"), 0, 48), hug: true, disabled: (!luaTruthy(canSend)), reducedMotion: reducedMotion, highlight: canSend })));
		let sections: unknown = {};
		if (luaTruthy(showStatus)) {
			luaTable.insert(sections, { id: "status", height: STATUS_HEIGHT, element: statusElement });
		}
		if ((luaTruthy(showStatus) && luaTruthy(searchOpen))) {
			luaTable.insert(sections, { id: "search", height: 44, element: reactLoose.createElement(SearchField, { value: logQuery, onChange: setLogQuery, placeholder: "Search words, from:name or in:global", accent: luaProp(Palette, "cyan"), reducedMotion: softMotion, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), zIndex: 22 }) });
		}
		let unreadByTab: unknown = ((luaTruthy(luaProp(chat, "unreadByTab") ) ? luaProp(chat, "unreadByTab") :  {}));
		let tabOptions: unknown = {};
		for (const [_, def] of pairs((TAB_DEFS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let waiting: unknown = ((luaTruthy(luaIndex(unreadByTab, luaProp(def, "id")) ) ? luaIndex(unreadByTab, luaProp(def, "id")) :  0));
			luaTable.insert(tabOptions, { id: luaProp(def, "id"), label: (((waiting as unknown as number) > (0 as unknown as number)) ? `${luaProp(def, "label")} ${waiting}` : luaProp(def, "label")) });
		}
		let tabColumns: unknown = (luaTruthy(luaProp(viewport, "compact")) ? 3 : len(TAB_DEFS));
		let tabRows: unknown = (math.ceil as unknown as (...a: unknown[]) => unknown)(((len(TAB_DEFS) as unknown as number) / (tabColumns as unknown as number)));
		luaTable.insert(sections, { id: "tabs", height: segmentedHeight(len(TAB_DEFS) as number, tabColumns as number, viewport as never, TAB_ROW_H as number, 6), element: reactLoose.createElement(SegmentedTabs, { options: tabOptions, value: tab, onChange: luaProp(chat, "setTab"), accent: luaProp(Palette, "cyan"), columns: tabColumns, gap: 6, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion }) });
		if (((tab === "whispers") && ((len(luaProp(chat, "whispers")) as unknown as number) > (0 as unknown as number)))) {
			let peerChips: unknown = {};
			for (const [_, entry] of pairs((luaProp(chat, "whispers")) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let selected: unknown = (luaProp(entry, "userId") === luaProp(chat, "peer"));
				let label: unknown = luaProp(entry, "displayName");
				if (((luaProp(entry, "unread") as unknown as number) > (0 as unknown as number))) {
					label = `${label} (${luaProp(entry, "unread")})`;
				}
				if ((luaProp(entry, "online") === false)) {
					label = concat(label, " · away");
				}
				luaTable.insert(peerChips, { key: `peer-${luaProp(entry, "userId")}`, element: reactLoose.createElement(Button, { text: label, onClick: function(this: void): unknown | undefined {
					luaCall(luaProp(chat, "setPeer"), luaProp(entry, "userId"));
					return undefined;
				}, color: (luaTruthy(selected) ? luaProp(Palette, "violet") : luaProp(Palette, "panelSoft")), textColor: (luaTruthy(selected) ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: luaCall(luaProp(UDim2, "fromOffset"), 0, ((PEER_ROW_H as unknown as number) - (4 as unknown as number))), hug: true, reducedMotion: softMotion }) });
			}
			luaTable.insert(sections, { id: "peers", height: PEER_ROW_H, element: luaCall(chipRail, peerChips, undefined) });
		}
		luaTable.insert(sections, { id: "messages", fill: true, minHeight: 120, element: (((!luaTruthy(filteringLog)) && (len(shownMessages) === 0)) ? reactLoose.createElement(Text, { value: ((tab === "whispers") ? "No whispers yet. Type /w name message to start one." : ((tab === "friends") ? "Nothing from friends in this server yet." : ((tab === "crew") ? "Crew chat is private to your crew. Start one on the Crew page." : ((tab === "global") ? "Global chat is quiet. Say hello to every server." : "Nobody has said anything here yet. Say hi.")))), size: 14, color: luaProp(Palette, "muted"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20) }) : ((luaTruthy(filteringLog) && (len(shownMessages) === 0)) ? reactLoose.createElement(Text, { value: `No messages match "${logQuery}".`, size: 14, color: luaProp(Palette, "muted"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, 40), position: luaCall(luaProp(UDim2, "fromOffset"), 0, 20) }) : messagesElement)) });
		if (luaTruthy(showBanner)) {
			luaTable.insert(sections, { id: "banner", height: BANNER_HEIGHT, element: bannerElement });
		}
		if (((len(suggestions) as unknown as number) > (0 as unknown as number))) {
			let suggestChips: unknown = {};
			for (const [order, suggestion] of pairs((suggestions) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				luaTable.insert(suggestChips, { key: `suggest-${order}`, element: reactLoose.createElement(Button, { text: ((luaProp(suggestion, "kind") === "command") ? luaProp(suggestion, "label") : `${luaProp(suggestion, "label")}  ${luaProp(suggestion, "detail")}`), onClick: function(this: void): unknown | undefined {
					luaCall(applySuggestion, luaProp(suggestion, "fill"));
					return undefined;
				}, color: ((order === 1) ? luaProp(Palette, "cyan") : luaProp(Palette, "panelSoft")), textColor: ((order === 1) ? luaProp(Palette, "ink") : luaProp(Palette, "cream")), size: luaCall(luaProp(UDim2, "fromOffset"), 0, ((SUGGEST_ROW_H as unknown as number) - (4 as unknown as number))), hug: true, reducedMotion: softMotion }) });
			}
			luaTable.insert(sections, { id: "suggest", height: SUGGEST_ROW_H, element: luaCall(chipRail, suggestChips, 24) });
		}
		luaTable.insert(sections, { id: "input", height: inputHeight, element: inputElement });
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "void"), BorderSizePixel: 0, ClipsDescendants: true }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaProp(Layout, "cardRadius")) }), reactLoose.createElement("uistroke", { Color: luaProp(Palette, "cyan"), Thickness: 1, Transparency: 0.55 }), reactLoose.createElement(PageScaffold, { gap: chromeGap, inset: SIDE_INSET, tailPad: chromeGap, scrollBarColor: luaProp(Palette, "cyan"), scrollBarThickness: 0, sections: sections }));
		return undefined;
	}
	return { ChatView: ChatView };
	return undefined;
}
export = __member();
