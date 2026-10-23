import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable, luaRequire, instChild, kit, mod } from "./viewRuntime";

function __member(): unknown {
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let Audio: unknown = luaProp(kit("AudioKit", "audio"), "Audio");
	let formatReward: unknown = luaProp(kit("CoreKit", "format"), "formatReward");
	let Icon: unknown = luaProp(kit("ArtKit", "Icon"), "Icon");
	let useAntilag: unknown = luaProp(kit("MotionKit", "antilag"), "useAntilag");
	let GamepadNavigationService: unknown = kit("CoreKit", "GamepadNavigationService");
	let _motion: unknown = kit("MotionKit", "motion");
	let useFlash: unknown = luaProp(_motion, "useFlash");
	let useFlipperSpring: unknown = luaProp(_motion, "useFlipperSpring");
	let useStagger: unknown = luaProp(_motion, "useStagger");
	let useViewport: unknown = luaProp(_motion, "useViewport");
	let _theme: unknown = kit("CoreKit", "theme");
	let chromeFor: unknown = luaProp(_theme, "chromeFor");
	let Palette: unknown = luaProp(_theme, "Palette");
	let darken: unknown = luaProp(_theme, "darken");
	let lighten: unknown = luaProp(_theme, "lighten");
	let TapTarget: unknown = luaProp(_theme, "TapTarget");
	let FlatList: unknown = luaProp(kit("LayoutKit", "virtualizedList"), "FlatList");
	let _ui: unknown = kit("UiCore", "ui");
	let Badge: unknown = luaProp(_ui, "Badge");
	let Button: unknown = luaProp(_ui, "Button");
	let EmptyState: unknown = luaProp(_ui, "EmptyState");
	let SegmentedTabs: unknown = luaProp(_ui, "SegmentedTabs");
	let Text: unknown = luaProp(_ui, "Text");
	let measureWrappedTextHeight: unknown = luaProp(_ui, "measureWrappedTextHeight");
	let ScriptedText: unknown = luaProp(kit("ReactHosts", "RichTextHost"), "ScriptedText");
	let SearchField: unknown = luaProp(_ui, "SearchField");
	let Browse: unknown = mod("BrowseKit");
	let ChatText: unknown = kit("CoreKit", "chatText");
	let h: unknown = reactLoose.createElement;
	let ROW_H: unknown = 84;
	let ROW_GAP: unknown = 8;
	let FILTERS: unknown = [{ id: "All", label: "All" }, { id: "Unread", label: "Unread" }, { id: "Gifts", label: "Gifts" }, { id: "Collected", label: "Collected" }, { id: "Alerts", label: "Alerts" }];
	let NoticeMath: unknown = kit("CoreKit", "noticeMath");
	let ALERT_COLORS: unknown = { Success: "mint", Warning: "mango", Error: "coral", Special: "violet" };
	function alertRows(query?: unknown): unknown | undefined {
		let rows: unknown = {};
		for (const [_, entry] of pairs((luaCall(luaProp(NoticeMath, "Entries"))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let subject: unknown = (((luaProp(entry, "Count") as unknown as number) > (1 as unknown as number)) ? `${luaProp(entry, "Title")}  ×${luaProp(entry, "Count")}` : luaProp(entry, "Title"));
			let keep: unknown = ((query === "") || luaCall(luaProp(Browse, "matches"), query, luaProp(entry, "Title"), luaProp(entry, "Body")));
			if (luaTruthy(keep)) {
				let item: unknown = { Id: luaProp(entry, "Id"), Subject: ((subject !== "") ? subject : "Forge alert"), Sender: "Forge alerts", Preview: luaProp(entry, "Body"), Date: (os.date as unknown as (...a: unknown[]) => unknown)("%H:%M", luaProp(entry, "At")), Body: [((luaProp(entry, "Body") !== "") ? luaProp(entry, "Body") : luaProp(entry, "Title"))], Color: (luaIndex(Palette, ((luaTruthy(luaIndex(ALERT_COLORS, luaProp(entry, "Tone")) ) ? luaIndex(ALERT_COLORS, luaProp(entry, "Tone")) :  "cyan"))) || luaProp(Palette, "mango")) };
				luaTable.insert(rows, { Id: luaProp(entry, "Id"), item: item, mail: { Read: true, Claimed: false } });
			}
		}
		return rows;
		return undefined;
	}
	function paragraphHeight(value?: unknown, width?: unknown, size?: unknown): unknown | undefined {
		return (math.max as unknown as (...a: unknown[]) => unknown)(20, ((luaCall(measureWrappedTextHeight, value, width, size, luaProp(luaProp(Enum, "FontWeight"), "Regular")) as unknown as number) + (6 as unknown as number)));
		return undefined;
	}
	function hasGift(item?: unknown): unknown | undefined {
		return ((luaProp(item, "Attachment") !== undefined) && (luaCall(next, luaProp(item, "Attachment")) !== undefined));
		return undefined;
	}
	function Avatar(props?: unknown): unknown | undefined {
		let item: unknown = luaProp(props, "item");
		let letter: unknown = luaCall(luaProp(ChatText, "initial"), luaProp(item, "Sender"));
		return luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), luaProp(props, "size"), luaProp(props, "size")), Position: luaProp(props, "position"), BackgroundColor3: luaCall(darken, luaProp(item, "Color"), (luaTruthy(luaProp(props, "unread")) ? 0.25 : 0.65)), BorderSizePixel: 0, ZIndex: 3 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(1, 0) }), luaCall(h, "uistroke", { Color: luaProp(item, "Color"), Thickness: 1.5, Transparency: (luaTruthy(luaProp(props, "unread")) ? 0.05 : 0.55) }), luaCall(h, Text, { value: letter, size: (math.floor as unknown as (...a: unknown[]) => unknown)(((luaProp(props, "size") as unknown as number) * (0.42 as unknown as number))), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), sizeConstraint: luaCall(luaProp(UDim2, "fromScale"), 1, 1), zIndex: 4 }));
		return undefined;
	}
	function MailRow(props?: unknown): unknown | undefined {
		let item: unknown = luaProp(props, "item");
		let mail: unknown = luaProp(props, "mail");
		let unread: unknown = (!luaTruthy(luaProp(mail, "Read")));
		let gift: unknown = (luaCall(hasGift, item) && (!luaTruthy(luaProp(mail, "Claimed"))));
		let softMotion: unknown = luaProp(props, "softMotion");
		let reveal: unknown = luaCall(useStagger, luaProp(props, "order"), softMotion, 0.02, 0.2);
		let hover: unknown;
		let setHover: unknown;
		[hover, setHover] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let glow: unknown = luaCall(useFlipperSpring, (luaTruthy(luaProp(props, "active")) ? 1 : (luaTruthy(hover) ? 0.5 : 0)), softMotion, 640, 36);
		return luaCall(h, "imagebutton", { Name: "MailRow", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -4, 0, ROW_H), BackgroundColor3: luaProp(Palette, "panelRaised"), BackgroundTransparency: colon(reveal).map(function(this: void, a?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (a as unknown as number));
			return undefined;
		}), AutoButtonColor: false, BorderSizePixel: 0, Selectable: true, ClipsDescendants: false, Event: { Activated: function(this: void): unknown | undefined {
			luaCall(luaProp(props, "onChoose"), luaProp(item, "Id"));
			return undefined;
		}, MouseEnter: function(this: void): unknown | undefined {
			luaCall(setHover, true);
			colon(Audio).play("hover");
			return undefined;
		}, MouseLeave: function(this: void): unknown | undefined {
			luaCall(setHover, false);
			return undefined;
		}, SelectionGained: function(this: void): unknown | undefined {
			luaCall(setHover, true);
			return undefined;
		}, SelectionLost: function(this: void): unknown | undefined {
			luaCall(setHover, false);
			return undefined;
		} } }, luaCall(h, "uicorner", { CornerRadius: new UDim(0, 16) }), luaCall(h, "frame", { Name: "BrassRule", Size: new UDim2(1, -6, 1, -6), Position: UDim2.fromOffset(3, 3), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, luaCall(h, "uicorner", { CornerRadius: new UDim(0, 15) }), luaCall(h, "uistroke", { Color: luaProp(Palette, "brass"), Thickness: 1, Transparency: 0.75 })), luaCall(h, "uistroke", { Color: ((luaTruthy(luaProp(props, "active")) || luaTruthy(unread)) ? luaProp(item, "Color") : luaProp(Palette, "lineSoft")), Thickness: colon(glow).map(function(this: void, a?: unknown): unknown | undefined {
			return ((1 as unknown as number) + (a as unknown as number));
			return undefined;
		}), Transparency: colon(glow).map(function(this: void, a?: unknown): unknown | undefined {
			return (luaTruthy(unread) ? ((0.35 as unknown as number) - (((a as unknown as number) * (0.3 as unknown as number)) as unknown as number)) : ((0.7 as unknown as number) - (((a as unknown as number) * (0.5 as unknown as number)) as unknown as number)));
			return undefined;
		}) }), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(item, "Color"), BackgroundTransparency: colon(glow).map(function(this: void, a?: unknown): unknown | undefined {
			return ((1 as unknown as number) - (((a as unknown as number) * (0.1 as unknown as number)) as unknown as number));
			return undefined;
		}), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 16) })), luaCall(h, Avatar, { item: item, unread: unread, size: 44, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 12, 0.5, -22) }), luaCall(h, Text, { value: luaProp(item, "Subject"), size: 15, color: luaProp(Palette, "cream"), weight: (luaTruthy(unread) ? luaProp(luaProp(Enum, "FontWeight"), "Heavy") : luaProp(luaProp(Enum, "FontWeight"), "Bold")), fit: true, minSize: 11, position: luaCall(luaProp(UDim2, "fromOffset"), 68, 12), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -150, 0, 20), zIndex: 3 }), luaCall(h, Text, { value: luaProp(item, "Sender"), size: 12, color: luaProp(item, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), 68, 33), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -150, 0, 16), zIndex: 3 }), luaCall(h, Text, { value: ((luaTruthy(luaProp(item, "Preview") ) ? luaProp(item, "Preview") :  "")), size: 12, color: luaProp(Palette, "muted"), position: luaCall(luaProp(UDim2, "fromOffset"), 68, 52), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -80, 0, 18), zIndex: 3 }), luaCall(h, Text, { value: ((luaTruthy(luaProp(item, "Date") ) ? luaProp(item, "Date") :  "")), size: 11, color: luaProp(Palette, "muted"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), align: luaProp(luaProp(Enum, "TextXAlignment"), "Right"), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -94, 0, 12), sizeConstraint: luaCall(luaProp(UDim2, "fromOffset"), 82, 16), zIndex: 3 }), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 70, 20), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -82, 0, 32), BackgroundTransparency: 1, ZIndex: 3 }, luaCall(h, "uilistlayout", { FillDirection: luaProp(luaProp(Enum, "FillDirection"), "Horizontal"), HorizontalAlignment: luaProp(luaProp(Enum, "HorizontalAlignment"), "Right"), Padding: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 4) }), ((luaTruthy(unread ) ?  luaCall(h, Badge, { value: "NEW", accent: luaProp(item, "Color"), filled: true, size: luaCall(luaProp(UDim2, "fromOffset"), 40, 18) }) : unread)), ((luaTruthy(gift ) ?  luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 22, 18), BackgroundColor3: luaProp(Palette, "mint"), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }), luaCall(h, Icon, { kind: "Gift.10", color: luaProp(Palette, "ink"), accent: luaProp(Palette, "mint"), size: 14, position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), spin: false })) : gift)), ((((!luaTruthy(gift)) && luaProp(mail, "Claimed")) && luaCall(hasGift, item)) && luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 22, 18), BackgroundColor3: luaProp(Palette, "panelSoft"), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 6) }), luaCall(h, Icon, { kind: "Check.15", color: luaProp(Palette, "mint"), accent: luaProp(Palette, "mint"), size: 14, position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), spin: false })))));
		return undefined;
	}
	function Parcel(props?: unknown): unknown | undefined {
		let item: unknown = luaProp(props, "item");
		let claimed: unknown = luaProp(props, "claimed");
		let softMotion: unknown = luaProp(props, "softMotion");
		let stack: unknown = luaProp(props, "stack");
		let pop: unknown = luaCall(useFlash, luaProp(props, "claimToken"), softMotion, 0.7);
		return luaCall(h, "frame", { Name: "MailClaimActions", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, luaProp(props, "height")), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, (-(luaProp(props, "height") as unknown as number))), BackgroundColor3: luaCall(darken, luaProp(item, "Color"), (luaTruthy(claimed) ? 0.85 : 0.72)), BorderSizePixel: 0, ClipsDescendants: false, ZIndex: 6 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 11) }), luaCall(h, "uistroke", { Color: (luaTruthy(claimed) ? luaProp(Palette, "lineSoft") : luaProp(item, "Color")), Thickness: colon(pop).map(function(this: void, a?: unknown): unknown | undefined {
			return ((1.5 as unknown as number) + (((a as unknown as number) * (2 as unknown as number)) as unknown as number));
			return undefined;
		}), Transparency: (luaTruthy(claimed) ? 0.6 : 0.15) }), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 48, 48), Position: luaCall(luaProp(UDim2, "fromOffset"), 14, 14), BackgroundColor3: (luaTruthy(claimed) ? luaProp(Palette, "panelSoft") : luaProp(item, "Color")), BorderSizePixel: 0, ZIndex: 7 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), luaCall(h, "uiscale", { Scale: colon(pop).map(function(this: void, a?: unknown): unknown | undefined {
			return ((1 as unknown as number) + (((a as unknown as number) * (0.3 as unknown as number)) as unknown as number));
			return undefined;
		}) }), luaCall(h, Icon, { kind: (luaTruthy(claimed) ? "Check.16" : "Gift.11"), color: (luaTruthy(claimed) ? luaProp(Palette, "mint") : luaProp(Palette, "ink")), accent: luaProp(item, "Color"), size: 28, position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), spin: false, reducedMotion: softMotion })), luaCall(h, Text, { value: (luaTruthy(claimed) ? "COLLECTED" : "ATTACHED GIFT"), size: 11, color: (luaTruthy(claimed) ? luaProp(Palette, "mint") : luaProp(item, "Color")), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 74, 16), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -86 : -340), 0, 14), zIndex: 7 }), luaCall(h, Text, { value: luaCall(formatReward, luaProp(item, "Attachment")), size: 15, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 10, position: luaCall(luaProp(UDim2, "fromOffset"), 74, 34), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(stack) ? -86 : -340), 0, 22), zIndex: 7 }), luaCall(h, "frame", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -28, 0, TapTarget) : luaCall(luaProp(UDim2, "fromOffset"), 310, TapTarget)), Position: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 14, 1, (-((((TapTarget as unknown as number) + (14 as unknown as number))) as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -324, 0.5, (((-(TapTarget as unknown as number)) as unknown as number) / (2 as unknown as number)))), BackgroundTransparency: 1, ClipsDescendants: false, ZIndex: 8 }, luaCall(h, "frame", { Name: "MailClaim", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.62, -4, 1, 0), BackgroundTransparency: 1, ClipsDescendants: false }, luaCall(h, Button, { text: (luaTruthy(claimed) ? "COLLECTED" : "CLAIM GIFT"), icon: "Gift.12", onClick: luaProp(props, "onClaim"), color: (luaTruthy(claimed) ? luaProp(Palette, "panelSoft") : luaProp(item, "Color")), textColor: (luaTruthy(claimed) ? luaProp(Palette, "muted") : luaProp(Palette, "ink")), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: claimed, highlight: (!luaTruthy(claimed)), reducedMotion: softMotion })), luaCall(h, "frame", { Name: "MailArchive", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.38, -4, 1, 0), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.62, 4, 0, 0), BackgroundTransparency: 1 }, luaCall(h, Button, { text: "ARCHIVE", icon: "Close.4", onClick: luaProp(props, "onArchive"), color: luaProp(Palette, "coral"), textColor: (luaTruthy(claimed) ? luaProp(Palette, "cream") : luaProp(Palette, "muted")), outline: true, size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), disabled: (!luaTruthy(claimed)), reducedMotion: softMotion }))));
		return undefined;
	}
	function MailboxView(_param?: unknown): unknown | undefined {
		let state: unknown = luaProp(_param, "state");
		let config: unknown = luaProp(_param, "config");
		let dispatch: unknown = luaProp(_param, "dispatch");
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		let softMotion: unknown = reducedMotion;
		reducedMotion = softMotion;
		let viewport: unknown = luaCall(useViewport);
		let chrome: unknown = luaCall(chromeFor, viewport);
		let antilag: unknown = luaCall(useAntilag);
		let stack: unknown = luaProp(chrome, "contentStack");
		let mobileRoute: unknown = ((luaTruthy(luaProp(chrome, "mobile") ) ? luaProp(chrome, "mobile") :  ((luaProp(viewport, "width") as unknown as number) < (760 as unknown as number))));
		let mountedRef: unknown = reactLoose.useRef(true);
		let mailActionsHostRef: unknown = reactLoose.useRef(undefined);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			luaSet(mountedRef, "current", true);
			return function(this: void): unknown | undefined {
				luaSet(mountedRef, "current", false);
				return undefined;
			};
			return undefined;
		}, {});
		let filter: unknown;
		let setFilter: unknown;
		[filter, setFilter] = reactLoose.useState("All") as LuaTuple<[unknown, unknown]>;
		let query: unknown;
		let setQuery: unknown;
		[query, setQuery] = luaCall(luaProp(Browse, "useLinkedQuery"), "Mail") as LuaTuple<[unknown, unknown]>;
		let claimToken: unknown;
		let setClaimToken: unknown;
		[claimToken, setClaimToken] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		let alertRevision: unknown;
		let setAlertRevision: unknown;
		[alertRevision, setAlertRevision] = reactLoose.useState(0) as LuaTuple<[unknown, unknown]>;
		reactLoose.useEffect(function(this: void): unknown | undefined {
			return luaCall(luaProp(NoticeMath, "Subscribe"), function(this: void): unknown | undefined {
				if (luaTruthy(luaProp(mountedRef, "current"))) {
					luaCall(setAlertRevision, function(this: void, n?: unknown): unknown | undefined {
						return ((n as unknown as number) + (1 as unknown as number));
						return undefined;
					});
				}
				return undefined;
			});
			return undefined;
		}, {});
		let messages: unknown = ((((luaTruthy(luaProp(state, "Mailbox") ) ?  luaProp(luaProp(state, "Mailbox"), "Messages") : luaProp(state, "Mailbox")))) || {});
		let defs: unknown = {};
		for (const [_, def] of pairs((((luaTruthy(luaProp(config, "Mail") ) ? luaProp(config, "Mail") :  {}))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaSetIndex(defs, luaProp(def, "Id"), def);
		}
		const _init1 = {};
		const _init2 = 0;
		const _init3 = 0;
		let rows: unknown = _init1;
		let unread: unknown = _init2;
		let gifts: unknown = _init3;
		for (const [_, mail] of pairs((messages) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let item: unknown = luaIndex(defs, luaProp(mail, "Id"));
			if ((item !== undefined)) {
				let gift: unknown = (luaCall(hasGift, item) && (!luaTruthy(luaProp(mail, "Claimed"))));
				if ((!luaTruthy(luaProp(mail, "Read")))) {
					unread = ((unread as unknown as number) + (1 as unknown as number));
				}
				if (luaTruthy(gift)) {
					gifts = ((gifts as unknown as number) + (1 as unknown as number));
				}
				let keep: unknown = ((((filter === "All") || (((filter === "Unread") && (!luaTruthy(luaProp(mail, "Read")))))) || (((filter === "Gifts") && gift))) || (((filter === "Collected") && luaProp(mail, "Claimed"))));
				if ((luaTruthy(keep) && (query !== ""))) {
					keep = luaCall(luaProp(Browse, "matches"), query, luaProp(item, "Subject"), luaProp(item, "Sender"), ((luaTypeIs(luaProp(item, "Body"), "table")) ? luaTable.concat(luaProp(item, "Body"), " ") : undefined));
				}
				if (luaTruthy(keep)) {
					luaTable.insert(rows, { Id: luaProp(item, "Id"), item: item, mail: mail });
				}
			}
		}
		if (((filter === "Alerts") && ((alertRevision as unknown as number) >= (0 as unknown as number)))) {
			rows = luaCall(alertRows, query);
		}
		let selectedId: unknown;
		let setSelectedId: unknown;
		[selectedId, setSelectedId] = reactLoose.useState((luaTruthy(mobileRoute) ? "" : ((((luaTruthy(luaIndex(rows, 1) ) ?  luaProp(luaIndex(rows, 1), "Id") : luaIndex(rows, 1))) || "")))) as LuaTuple<[unknown, unknown]>;
		let selected: unknown = undefined;
		for (const [_, row] of pairs((rows) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if ((luaProp(row, "Id") === selectedId)) {
				selected = row;
			}
		}
		if (((selected === undefined) && (!luaTruthy(mobileRoute)))) {
			selected = luaIndex(rows, 1);
		}
		let showReader: unknown = ((luaTruthy(mobileRoute ) ?  (selected !== undefined) : mobileRoute));
		let slide: unknown = luaCall(useFlipperSpring, (luaTruthy(showReader) ? 1 : 0), softMotion, 700, 40);
		let selectedKey: unknown = (((luaTruthy(selected ) ?  luaProp(selected, "Id") : selected)) || "");
		let selectedRead: unknown = ((selected !== undefined) && luaProp(luaProp(selected, "mail"), "Read"));
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if (((selected !== undefined) && (!luaTruthy(luaProp(luaProp(selected, "mail"), "Read"))))) {
				luaCall(dispatch, "ReadMail", { Id: luaProp(selected, "Id") });
			}
			return undefined;
		}, [selectedKey, selectedRead]);
		reactLoose.useEffect(function(this: void): unknown | undefined {
			if (((selected === undefined) || (!luaTruthy(luaProp(UserInputService, "GamepadEnabled"))))) {
				return undefined;
			}
			let host: unknown = luaProp(mailActionsHostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let job: unknown = (task.defer as unknown as (...a: unknown[]) => unknown)(function(this: void): unknown | undefined {
				if ((luaProp(host, "Parent") !== undefined)) {
					luaCall(luaProp(GamepadNavigationService, "FocusClaim"), host);
				}
				return undefined;
			});
			return function(this: void): unknown | undefined {
				luaCall(pcall, luaProp(task, "cancel"), job);
				return undefined;
			};
			return undefined;
		}, [selectedKey, ((selected !== undefined) && luaProp(luaProp(selected, "mail"), "Claimed"))]);
		let choose: unknown = function(this: void, id?: unknown): unknown | undefined {
			if ((id !== selectedId)) {
				colon(Audio).play("mailRead");
				luaCall(setSelectedId, id);
			}
			return undefined;
		};
		let headerH: unknown = (luaTruthy(stack) ? 118 : 64);
		let header: unknown = luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, headerH), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new UDim(0, 16) }), luaCall(h, "frame", { Name: "BrassRule", Size: new UDim2(1, -6, 1, -6), Position: UDim2.fromOffset(3, 3), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, luaCall(h, "uicorner", { CornerRadius: new UDim(0, 15) }), luaCall(h, "uistroke", { Color: luaProp(Palette, "brass"), Thickness: 1, Transparency: 0.75 })), luaCall(h, "uistroke", { Color: luaProp(Palette, "lineSoft"), Transparency: 0.5 }), luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), 40, 40), Position: luaCall(luaProp(UDim2, "fromOffset"), 12, 12), BackgroundColor3: luaCall(darken, luaProp(Palette, "mango"), 0.6), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 12) }), luaCall(h, Icon, { kind: "Mail.2", color: luaProp(Palette, "cream"), accent: luaProp(Palette, "mango"), size: 24, position: luaCall(luaProp(UDim2, "fromScale"), 0.5, 0.5), anchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), reducedMotion: softMotion })), luaCall(h, Text, { value: "Mailbox", size: 11, color: luaProp(Palette, "mango"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), position: luaCall(luaProp(UDim2, "fromOffset"), 62, 12), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 160, 0, 14) }), luaCall(h, Text, { value: (((unread === 0) && (gifts === 0)) ? "All caught up" : `${unread} unread · ${gifts} gift${((gifts === 1) ? "" : "s")} waiting`), size: 16, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 11, position: luaCall(luaProp(UDim2, "fromOffset"), 62, 28), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)((luaTruthy(stack) ? 1 : 0), (luaTruthy(stack) ? (-((((62 as unknown as number) + (150 as unknown as number))) as unknown as number)) : 260), 0, 22) }), (((gifts as unknown as number) > (0 as unknown as number)) && luaCall(h, Button, { text: `CLAIM ALL (${gifts})`, icon: "Gift.13", onClick: function(this: void): unknown | undefined {
			colon(Audio).play("mailClaim");
			luaCall(setClaimToken, function(this: void, n?: unknown): unknown | undefined {
				return ((n as unknown as number) + (1 as unknown as number));
				return undefined;
			});
			luaCall(dispatch, "ClaimAllMail", {});
			return undefined;
		}, color: luaProp(Palette, "mint"), textColor: luaProp(Palette, "ink"), size: luaCall(luaProp(UDim2, "fromOffset"), 140, ((TapTarget as unknown as number) - (4 as unknown as number))), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -152, 0, 10), highlight: true, reducedMotion: softMotion })), luaCall(h, "frame", { Size: (luaTruthy(stack) ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -24, 0, ((TapTarget as unknown as number) + (8 as unknown as number))) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (-((((380 as unknown as number) + (((((gifts as unknown as number) > (0 as unknown as number)) ? 164 : 12)) as unknown as number))) as unknown as number)), 0, 40)), Position: (luaTruthy(stack) ? luaCall(luaProp(UDim2, "fromOffset"), 12, ((((headerH as unknown as number) - (TapTarget as unknown as number)) as unknown as number) - (18 as unknown as number))) : luaCall(luaProp(UDim2, "fromOffset"), 372, 12)), BackgroundTransparency: 1 }, luaCall(h, SegmentedTabs, { options: FILTERS, value: filter, onChange: function(this: void, id?: unknown): unknown | undefined {
			luaCall(setFilter, id);
			luaCall(setSelectedId, "");
			return undefined;
		}, accent: luaProp(Palette, "mango"), columns: len(FILTERS), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion })));
		let selectedRowId: unknown = (((luaTruthy(selected ) ?  luaProp(selected, "Id") : selected)) || "");
		let searchH: unknown = (luaTruthy(stack) ? TapTarget : 40);
		let list: unknown = ((len(rows) === 0) ? luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-((((searchH as unknown as number) + (12 as unknown as number))) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, ((searchH as unknown as number) + (12 as unknown as number))), BackgroundTransparency: 1 }, luaCall(h, EmptyState, { icon: ((query !== "") ? "Search.6" : "Mail.3"), title: ((query !== "") ? `No letters match "${query}"` : ((filter === "All") ? "Your tray is empty" : ((filter === "Alerts") ? "No recent alerts" : concat("Nothing in ", (string.lower as unknown as (...a: unknown[]) => unknown)(filter))))), body: ((query !== "") ? "Try the sender's name or one word from the subject." : ((filter === "Alerts") ? "Pop-ups from this session are kept here so you can read them again." : "Patch notes, letters and gifts land here.")), accent: luaProp(Palette, "mango"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion })) : reactLoose.createElement(FlatList, { data: rows, itemHeight: ((ROW_H as unknown as number) + (ROW_GAP as unknown as number)), overscan: (luaTruthy(softMotion) ? 0 : (luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2)), canvasTail: 6, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -12, 1, (-((((searchH as unknown as number) + (18 as unknown as number))) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 6, ((searchH as unknown as number) + (12 as unknown as number))), scrollBarColor: luaProp(Palette, "mango"), scrollBarThickness: 3, keyExtractor: function(this: void, row?: unknown): unknown | undefined {
			return luaProp(row, "Id");
			return undefined;
		}, renderItem: function(this: void, entry?: unknown): unknown | undefined {
			let row: unknown = luaProp(entry, "item");
			return luaCall(h, MailRow, { item: luaProp(row, "item"), mail: luaProp(row, "mail"), active: (luaProp(row, "Id") === selectedRowId), order: 0, softMotion: softMotion, onChoose: choose });
			return undefined;
		} }));
		let bodyArea: unknown = undefined;
		if ((selected !== undefined)) {
			let item: unknown = luaProp(selected, "item");
			let readerW: unknown = (luaTruthy(mobileRoute) ? ((luaProp(viewport, "width") as unknown as number) - (24 as unknown as number)) : ((luaProp(viewport, "width") as unknown as number) * (0.6 as unknown as number)));
			let textW: unknown = (math.max as unknown as (...a: unknown[]) => unknown)(60, ((readerW as unknown as number) - (64 as unknown as number)));
			let bodySize: unknown = (luaTruthy(stack) ? 16 : 15);
			let bodyRows: unknown = {};
			let stride: unknown = 28;
			for (const [index, paragraph] of pairs((((luaTruthy(luaProp(item, "Body") ) ? luaProp(item, "Body") :  {}))) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				let height: unknown = luaCall(paragraphHeight, paragraph, textW, bodySize);
				stride = (math.max as unknown as (...a: unknown[]) => unknown)(stride, ((height as unknown as number) + (10 as unknown as number)));
				luaSetIndex(bodyRows, index, { Id: `${luaProp(item, "Id")}:${index}`, Text: paragraph, Index: ((index as unknown as number) - (1 as unknown as number)), Height: height });
			}
			let gift: unknown = luaCall(hasGift, item);
			let claimed: unknown = (luaProp(luaProp(selected, "mail"), "Claimed") === true);
			let parcelH: unknown = ((!luaTruthy(gift)) ? 0 : (luaTruthy(stack) ? 138 : 78));
			let letterTop: unknown = (luaTruthy(stack) ? 74 : 92);
			bodyArea = luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaCall(lighten, luaProp(Palette, "panel"), 0.02), BorderSizePixel: 0, ClipsDescendants: true }, luaCall(h, "uicorner", { CornerRadius: new UDim(0, 16) }), luaCall(h, "frame", { Name: "BrassRule", Size: new UDim2(1, -6, 1, -6), Position: UDim2.fromOffset(3, 3), BackgroundTransparency: 1, BorderSizePixel: 0, Active: false }, luaCall(h, "uicorner", { CornerRadius: new UDim(0, 15) }), luaCall(h, "uistroke", { Color: luaProp(Palette, "brass"), Thickness: 1, Transparency: 0.75 })), luaCall(h, "uistroke", { Color: luaProp(item, "Color"), Transparency: 0.5 }), luaCall(h, "frame", { Name: "LetterHead", Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, letterTop), BackgroundColor3: luaCall(darken, luaProp(item, "Color"), 0.8), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 16) }), ((luaTruthy(mobileRoute ) ?  luaCall(h, Button, { text: "", icon: "Back.1", onClick: function(this: void): unknown | undefined {
				luaCall(setSelectedId, "");
				return undefined;
			}, color: luaProp(Palette, "panelSoft"), textColor: luaProp(item, "Color"), outline: true, size: luaCall(luaProp(UDim2, "fromOffset"), TapTarget, TapTarget), position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 10, 0.5, (((-(TapTarget as unknown as number)) as unknown as number) / (2 as unknown as number))), reducedMotion: softMotion }) : mobileRoute)), ((!luaTruthy(mobileRoute)) && luaCall(h, Avatar, { item: item, unread: true, size: 52, position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 18, 0.5, -26) })), luaCall(h, Text, { value: luaProp(item, "Subject"), size: (luaTruthy(stack) ? 18 : 22), color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "Heavy"), fit: true, minSize: 12, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(mobileRoute) ? 64 : 84), (luaTruthy(stack) ? 12 : 20)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(mobileRoute) ? -76 : -104), 0, (luaTruthy(stack) ? 24 : 30)) }), luaCall(h, Text, { value: `From ${luaProp(item, "Sender")}${(luaTruthy(luaProp(item, "Date")) ? concat("  ·  ", luaProp(item, "Date")) : "")}`, size: 12, color: luaProp(item, "Color"), weight: luaProp(luaProp(Enum, "FontWeight"), "Bold"), fit: true, minSize: 9, position: luaCall(luaProp(UDim2, "fromOffset"), (luaTruthy(mobileRoute) ? 64 : 84), (luaTruthy(stack) ? 40 : 54)), sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, (luaTruthy(mobileRoute) ? -76 : -104), 0, 18) })), reactLoose.createElement(FlatList, { key: luaProp(item, "Id"), data: bodyRows, itemHeight: stride, overscan: (luaTruthy(softMotion) ? 0 : (luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2)), canvasTail: 8, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -40, 1, (-((((((letterTop as unknown as number) + (parcelH as unknown as number)) as unknown as number) + (24 as unknown as number))) as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 20, ((letterTop as unknown as number) + (10 as unknown as number))), scrollBarColor: luaProp(item, "Color"), scrollBarThickness: 3, keyExtractor: function(this: void, row?: unknown): unknown | undefined {
				return luaProp(row, "Id");
				return undefined;
			}, renderItem: function(this: void, entry?: unknown): unknown | undefined {
				let row: unknown = luaProp(entry, "item");
				if ((luaProp(row, "Index") === 0)) {
					return luaCall(h, ScriptedText, { key: luaProp(row, "Id"), text: luaProp(row, "Text"), width: textW, height: luaProp(row, "Height"), size: bodySize, color: luaProp(Palette, "cream"), weight: luaProp(luaProp(Enum, "FontWeight"), "SemiBold"), typewriterInterval: 0.01, reducedMotion: softMotion });
				}
				return luaCall(h, Text, { key: luaProp(row, "Id"), value: luaProp(row, "Text"), size: bodySize, color: luaProp(Palette, "creamSoft"), wrap: true, sizeConstraint: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -8, 0, luaProp(row, "Height")) });
				return undefined;
			} }), ((luaTruthy(gift ) ?  luaCall(h, "frame", { ref: mailActionsHostRef, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -20, 0, parcelH), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 10, 1, (-((((parcelH as unknown as number) + (10 as unknown as number))) as unknown as number))), BackgroundTransparency: 1, ClipsDescendants: false }, luaCall(h, Parcel, { item: item, claimed: claimed, stack: stack, height: parcelH, softMotion: softMotion, claimToken: claimToken, onClaim: function(this: void): unknown | undefined {
				colon(Audio).play("mailClaim");
				luaCall(setClaimToken, function(this: void, n?: unknown): unknown | undefined {
					return ((n as unknown as number) + (1 as unknown as number));
					return undefined;
				});
				luaCall(dispatch, "ClaimMail", { Id: luaProp(item, "Id") });
				return undefined;
			}, onArchive: function(this: void): unknown | undefined {
				luaCall(dispatch, "DeleteMail", { Id: luaProp(item, "Id") }, function(this: void, response?: unknown): unknown | undefined {
					if ((luaTruthy(luaProp(mountedRef, "current")) && luaTruthy(luaProp(response, "ok")))) {
						luaCall(setSelectedId, "");
					}
					return undefined;
				});
				return undefined;
			} })) : gift)));
		} else if ((!luaTruthy(mobileRoute))) {
			bodyArea = luaCall(h, EmptyState, { icon: "Mail.4", title: "Pick a letter", body: "Choose a message on the left to read it.", accent: luaProp(Palette, "mango"), size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), reducedMotion: softMotion });
		}
		let bodyTop: unknown = ((headerH as unknown as number) + (10 as unknown as number));
		return luaCall(h, "frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, ClipsDescendants: true }, header, luaCall(h, "frame", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 1, (-(bodyTop as unknown as number))), Position: luaCall(luaProp(UDim2, "fromOffset"), 0, bodyTop), BackgroundTransparency: 1, ClipsDescendants: true }, luaCall(h, "frame", { Name: "Inbox", SelectionGroup: true, Size: (luaTruthy(mobileRoute) ? luaCall(luaProp(UDim2, "fromScale"), 1, 1) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.38, -6, 1, 0)), Position: (luaTruthy(mobileRoute) ? colon(slide).map(function(this: void, a?: unknown): unknown | undefined {
			return luaCall(luaProp(UDim2, "fromScale"), (-((math.clamp as unknown as (...a: unknown[]) => unknown)(a, 0, 1) as unknown as number)), 0);
			return undefined;
		}) : undefined), Visible: (luaTruthy(mobileRoute) ? colon(slide).map(function(this: void, a?: unknown): unknown | undefined {
			return ((a as unknown as number) < (0.99 as unknown as number));
			return undefined;
		}) : true), BackgroundColor3: luaProp(Palette, "panel"), BorderSizePixel: 0 }, luaCall(h, "uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 11) }), luaCall(h, SearchField, { value: query, onChange: function(this: void, text?: unknown): unknown | undefined {
			luaCall(setQuery, text);
			luaCall(setSelectedId, "");
			return undefined;
		}, placeholder: "Search letters", accent: luaProp(Palette, "mango"), reducedMotion: softMotion, position: luaCall(luaProp(UDim2, "fromOffset"), 6, 6), size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -12, 0, searchH), zIndex: 6 }), list), ((bodyArea !== undefined) && luaCall(h, "frame", { Name: "Reader", SelectionGroup: true, Size: (luaTruthy(mobileRoute) ? luaCall(luaProp(UDim2, "fromScale"), 1, 1) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.62, -6, 1, 0)), Position: (luaTruthy(mobileRoute) ? colon(slide).map(function(this: void, a?: unknown): unknown | undefined {
			return luaCall(luaProp(UDim2, "fromScale"), ((1 as unknown as number) - ((math.clamp as unknown as (...a: unknown[]) => unknown)(a, 0, 1) as unknown as number)), 0);
			return undefined;
		}) : new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.38, 6, 0, 0)), Visible: (luaTruthy(mobileRoute) ? colon(slide).map(function(this: void, a?: unknown): unknown | undefined {
			return ((a as unknown as number) > (0.01 as unknown as number));
			return undefined;
		}) : true), BackgroundTransparency: 1 }, bodyArea))));
		return undefined;
	}
	return { MailboxView: MailboxView };
	return undefined;
}
export = __member();
