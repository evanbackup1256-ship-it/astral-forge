import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { LuaObj, Colon, colon, luaProp, luaIndex, luaSet, luaSetIndex, luaCall, len, concat, luaTruthy, luaTypeIs, reactLoose, LuaTableOps, luaTable, luaRequire, instChild, kit, mod } from "./viewRuntime";
import { BODY, BODY_BOLD, BODY_SEMI, Line, MockPanel, NUM, PanelHeading, ROW_RADIUS, RowSurface, TITLE_FACE, mockGap } from "../../UiCore/mockKit";
import { SEC } from "../mockRows";

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
	let ROW_H: unknown = 52;
	let ROW_GAP: unknown = 12;
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
	const P = Palette as Record<string, Color3>;
	const hl = (component: unknown, props: object, ...children: unknown[]) => luaCall(h, component, props, ...children) as React.Element;
	const list = (direction: "Horizontal" | "Vertical", padding: number, extra?: object) =>
		React.createElement("uilistlayout", { FillDirection: Enum.FillDirection[direction], Padding: new UDim(0, padding), SortOrder: Enum.SortOrder.LayoutOrder, VerticalAlignment: direction === "Horizontal" ? Enum.VerticalAlignment.Center : undefined, ...(extra ?? {}) });
	const fill = () => React.createElement("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill });
	/** sender initial in a round well tinted by the letter's colour (reader head) */
	function Avatar(props?: unknown): unknown | undefined {
		const item = luaProp(props, "item");
		const size = luaProp(props, "size") as number;
		const tint = luaProp(item, "Color") as Color3;
		const unread = luaTruthy(luaProp(props, "unread"));
		return React.createElement("frame", { Size: UDim2.fromOffset(size, size), BackgroundColor3: luaCall(darken, tint, unread ? 0.25 : 0.65) as Color3, BorderSizePixel: 0, LayoutOrder: (luaProp(props, "layoutOrder") as number) ?? 0 },
			React.createElement("uicorner", { CornerRadius: new UDim(1, 0) }),
			React.createElement("uistroke", { Color: tint, Thickness: 1.5, Transparency: unread ? 0.05 : 0.55 }),
			React.createElement("textlabel", { Text: tostring(luaCall(luaProp(ChatText, "initial"), luaProp(item, "Sender")) ?? ""), FontFace: BODY_BOLD, TextSize: math.floor(size * 0.42), TextColor3: P.cream, BackgroundTransparency: 1, Size: UDim2.fromScale(1, 1) }));
	}
	function MailRow(props?: unknown): unknown | undefined {
		const item = luaProp(props, "item");
		const mail = luaProp(props, "mail");
		const unread = !luaTruthy(luaProp(mail, "Read"));
		const gift = luaTruthy(luaCall(hasGift, item)) && !luaTruthy(luaProp(mail, "Claimed"));
		const softMotion = luaProp(props, "softMotion");
		const reveal = luaCall(useStagger, luaProp(props, "order"), softMotion, 0.02, 0.2) as React.Binding<number>;
		const [hover, setHover] = React.useState(false);
		const active = luaTruthy(luaProp(props, "active"));
		const glow = luaCall(useFlipperSpring, active ? 1 : hover ? 0.5 : 0, softMotion, 640, 36) as React.Binding<number>;
		// design/27 mail .row: 36px icon well (sender initial), subject over "from <sender>", and the action
		// on the right in the accent (Claim when a gift waits, otherwise Open)
		const tint = luaProp(item, "Color") as Color3;
		const action = gift ? "Claim" : "Open";
		return React.createElement("imagebutton", {
			Name: "MailRow", Size: new UDim2(1, -4, 0, ROW_H as number), BackgroundColor3: P.white, BackgroundTransparency: reveal.map((a: number) => 1 - a),
			AutoButtonColor: false, BorderSizePixel: 0, Selectable: true, ClipsDescendants: false, Image: "",
			Event: {
				Activated: () => luaCall(luaProp(props, "onChoose"), luaProp(item, "Id")),
				MouseEnter: () => { setHover(true); colon(Audio).play("hover"); },
				MouseLeave: () => setHover(false),
				SelectionGained: () => setHover(true),
				SelectionLost: () => setHover(false),
			},
		},
			React.createElement(RowSurface, {}),
			React.createElement("uistroke", {
				ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				Color: active || unread ? P.mint : P.white,
				Thickness: glow.map((a: number) => 1 + a),
				Transparency: glow.map((a: number) => (active ? 0.2 : unread ? 0.55 - a * 0.3 : 0.95 - a * 0.6)),
			}),
			React.createElement("uipadding", { PaddingLeft: new UDim(0, 12), PaddingRight: new UDim(0, 12), PaddingTop: new UDim(0, 6), PaddingBottom: new UDim(0, 6) }),
			list("Horizontal", 12),
			React.createElement("frame", { Size: UDim2.fromOffset(36, 36), BackgroundColor3: P.void, BackgroundTransparency: 0.35, BorderSizePixel: 0, LayoutOrder: 0 },
				React.createElement("uicorner", { CornerRadius: new UDim(0, 9) }),
				React.createElement("uistroke", { ApplyStrokeMode: Enum.ApplyStrokeMode.Border, Color: P.white, Transparency: 0.92, Thickness: 1 }),
				React.createElement("textlabel", { Text: tostring(luaCall(luaProp(ChatText, "initial"), luaProp(item, "Sender")) ?? ""), FontFace: BODY_BOLD, TextSize: 16, TextColor3: tint, BackgroundTransparency: 1, Size: UDim2.fromScale(1, 1) }),
				// unread pip on the well's top-right corner
				unread ? React.createElement("frame", { Size: UDim2.fromOffset(8, 8), AnchorPoint: new Vector2(0.5, 0.5), Position: UDim2.fromScale(1, 0), BackgroundColor3: P.mint, BorderSizePixel: 0, ZIndex: 4 }, React.createElement("uicorner", { CornerRadius: new UDim(1, 0) })) : undefined,
			),
			React.createElement("frame", { Size: new UDim2(0, 0, 0, 38), BackgroundTransparency: 1, LayoutOrder: 1 },
				fill(),
				list("Vertical", 2),
				React.createElement(Line, { text: tostring(luaProp(item, "Subject") ?? ""), size: 15, font: unread ? BODY_BOLD : BODY_SEMI, color: P.cream, width: new UDim(1, 0), height: 20, layoutOrder: 0 }),
				React.createElement(Line, { text: `from ${tostring(luaProp(item, "Sender") ?? "")}${luaTruthy(luaProp(item, "Date")) ? `  ·  ${tostring(luaProp(item, "Date"))}` : ""}`, size: 12, font: BODY, color: P.muted, width: new UDim(1, 0), height: 16, layoutOrder: 1 }),
			),
			React.createElement("frame", { Size: UDim2.fromOffset(0, 24), AutomaticSize: Enum.AutomaticSize.X, BackgroundTransparency: 1, LayoutOrder: 2 },
				list("Horizontal", 6),
				luaTruthy(luaProp(mail, "Claimed")) && luaTruthy(luaCall(hasGift, item))
					? React.createElement("frame", { Size: UDim2.fromOffset(16, 16), BackgroundTransparency: 1, LayoutOrder: 0 }, hl(Icon, { kind: "Check.15", color: P.mint, accent: P.mint, size: 16, spin: false }))
					: undefined,
				React.createElement(Line, { text: action, size: 17, font: NUM, color: gift ? P.mint : P.creamSoft, height: 24, layoutOrder: 1 }),
			),
		);
	}
	/** The attached gift under a letter: well, label and reward, then Claim / Archive. */
	function Parcel(props?: unknown): unknown | undefined {
		const item = luaProp(props, "item");
		const claimed = luaTruthy(luaProp(props, "claimed"));
		const softMotion = luaProp(props, "softMotion");
		const stack = luaTruthy(luaProp(props, "stack"));
		const tint = luaProp(item, "Color") as Color3;
		const pop = luaCall(useFlash, luaProp(props, "claimToken"), softMotion, 0.7) as React.Binding<number>;
		const actions = React.createElement("frame", { Size: stack ? new UDim2(1, 0, 0, TapTarget as number) : UDim2.fromOffset(310, TapTarget as number), BackgroundTransparency: 1, ClipsDescendants: false, LayoutOrder: 2 },
			list("Horizontal", 8, { HorizontalFlex: Enum.UIFlexAlignment.Fill }),
			React.createElement("frame", { Name: "MailClaim", Size: new UDim2(0.62, 0, 1, 0), BackgroundTransparency: 1, ClipsDescendants: false, LayoutOrder: 0 },
				hl(Button, { text: claimed ? "COLLECTED" : "CLAIM GIFT", icon: "Gift.12", onClick: luaProp(props, "onClaim"), color: claimed ? SEC : P.mint, textColor: claimed ? P.muted : P.ink, size: UDim2.fromScale(1, 1), disabled: claimed, highlight: !claimed, reducedMotion: softMotion })),
			React.createElement("frame", { Name: "MailArchive", Size: new UDim2(0.38, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
				hl(Button, { text: "ARCHIVE", icon: "Close.4", onClick: luaProp(props, "onArchive"), color: P.coral, textColor: claimed ? P.cream : P.muted, outline: true, size: UDim2.fromScale(1, 1), disabled: !claimed, reducedMotion: softMotion })),
		);
		const head = React.createElement("frame", { Size: new UDim2(stack ? 1 : 0, 0, 0, 48), BackgroundTransparency: 1, LayoutOrder: 1 },
			stack ? undefined : fill(),
			list("Horizontal", 12),
			React.createElement("frame", { Size: UDim2.fromOffset(48, 48), BackgroundColor3: claimed ? SEC : tint, BorderSizePixel: 0, LayoutOrder: 0 },
				React.createElement("uicorner", { CornerRadius: new UDim(0, 12) }),
				React.createElement("uiscale", { Scale: pop.map((a: number) => 1 + a * 0.3) }),
				hl(Icon, { kind: claimed ? "Check.16" : "Gift.11", color: claimed ? P.mint : P.ink, accent: tint, size: 28, position: UDim2.fromScale(0.5, 0.5), anchorPoint: new Vector2(0.5, 0.5), spin: false, reducedMotion: softMotion })),
			React.createElement("frame", { Size: new UDim2(0, 0, 0, 40), BackgroundTransparency: 1, LayoutOrder: 1 },
				fill(),
				list("Vertical", 2),
				React.createElement(Line, { text: claimed ? "COLLECTED" : "ATTACHED GIFT", size: 11, font: BODY_BOLD, color: claimed ? P.mint : tint, width: new UDim(1, 0), height: 14, layoutOrder: 0 }),
				React.createElement(Line, { text: tostring(luaCall(formatReward, luaProp(item, "Attachment"))), size: 15, font: NUM, color: P.cream, width: new UDim(1, 0), height: 22, layoutOrder: 1 }),
			),
		);
		return React.createElement("frame", { Name: "MailClaimActions", Size: UDim2.fromScale(1, 1), BackgroundColor3: luaCall(darken, tint, claimed ? 0.85 : 0.72) as Color3, BorderSizePixel: 0, ClipsDescendants: false },
			React.createElement("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }),
			React.createElement("uistroke", { Color: claimed ? P.lineSoft : tint, Thickness: pop.map((a: number) => 1.5 + a * 2), Transparency: claimed ? 0.6 : 0.15, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
			React.createElement("uipadding", { PaddingLeft: new UDim(0, 14), PaddingRight: new UDim(0, 14), PaddingTop: new UDim(0, stack ? 12 : 0), PaddingBottom: new UDim(0, stack ? 12 : 0) }),
			list(stack ? "Vertical" : "Horizontal", stack ? 10 : 14, stack ? {} : { VerticalAlignment: Enum.VerticalAlignment.Center }),
			head,
			actions,
		);
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
		const phone = luaTruthy(stack);
		const gap = mockGap(phone);
		const nGifts = gifts as number;
		// header .pn: Mailbox heading with the unread/gift count, CLAIM ALL, and the filter tabs
		const claimAll = nGifts > 0
			? React.createElement("frame", { Size: UDim2.fromOffset(phone ? 0 : 150, (TapTarget as number) - 4), AutomaticSize: phone ? Enum.AutomaticSize.X : Enum.AutomaticSize.None, BackgroundTransparency: 1, LayoutOrder: 1 },
					hl(Button, { text: `CLAIM ALL (${nGifts})`, icon: "Gift.13", onClick: () => {
						colon(Audio).play("mailClaim");
						luaCall(setClaimToken, (n: number) => n + 1);
						luaCall(dispatch, "ClaimAllMail", {});
					}, color: P.mint, textColor: P.ink, size: phone ? UDim2.fromOffset(0, (TapTarget as number) - 4) : UDim2.fromScale(1, 1), hug: phone, highlight: true, reducedMotion: softMotion }))
			: undefined;
		const filters = React.createElement("frame", { Size: phone ? new UDim2(1, 0, 0, (TapTarget as number) + 4) : UDim2.fromOffset(420, 40), BackgroundTransparency: 1, LayoutOrder: phone ? 1 : 2 },
			hl(SegmentedTabs, { options: FILTERS, value: filter, onChange: (id: unknown) => {
				luaCall(setFilter, id);
				luaCall(setSelectedId, "");
			}, accent: P.mint, columns: len(FILTERS), size: UDim2.fromScale(1, 1), reducedMotion: softMotion }));
		const summary = unread === 0 && nGifts === 0 ? "All caught up" : `${unread} unread · ${nGifts} gift${nGifts === 1 ? "" : "s"} waiting`;
		const headingRow = React.createElement("frame", { Size: new UDim2(1, 0, 0, phone ? 40 : 44), BackgroundTransparency: 1, LayoutOrder: 0 },
			list("Horizontal", 12),
			React.createElement("frame", { Size: new UDim2(0, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 0 },
				fill(),
				React.createElement(PanelHeading, { icon: "Mail.2", title: "Mailbox", note: summary, accent: P.mint, phone, layoutOrder: 0 })),
			claimAll,
			phone ? undefined : filters,
		);
		const headerH = phone ? 40 + 8 + (TapTarget as number) + 4 + 20 : 44 + 36;
		const header = React.createElement(MockPanel as never, { size: new UDim2(1, 0, 0, headerH), phone, accent: P.brass, gap: 8, layoutOrder: 0, name: "MailHeader" } as never, headingRow, phone ? filters : undefined) as unknown as React.Element;
		const selectedRowId = (luaTruthy(selected) ? luaProp(selected, "Id") : undefined) ?? "";
		const searchH = phone ? (TapTarget as number) : 40;
		const nRows = len(rows) as number;
		const inboxList = nRows === 0
			? React.createElement("frame", { Size: new UDim2(1, 0, 0, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
					fill(),
					hl(EmptyState, { icon: query !== "" ? "Search.6" : "Mail.3", title: query !== "" ? `No letters match "${query}"` : filter === "All" ? "Your tray is empty" : filter === "Alerts" ? "No recent alerts" : `Nothing in ${string.lower(filter as string)}`, body: query !== "" ? "Try the sender's name or one word from the subject." : filter === "Alerts" ? "Pop-ups from this session are kept here so you can read them again." : "Patch notes, letters and gifts land here.", accent: P.mint, size: UDim2.fromScale(1, 1), reducedMotion: softMotion }))
			: React.createElement("frame", { Size: new UDim2(1, 0, 0, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
					fill(),
					hl(FlatList, { data: rows, itemHeight: (ROW_H as number) + (ROW_GAP as number), overscan: luaTruthy(softMotion) ? 0 : luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2, canvasTail: 6, Size: UDim2.fromScale(1, 1), scrollBarColor: P.mint, scrollBarThickness: 3, keyExtractor: (row: unknown) => luaProp(row, "Id"), renderItem: (entry: unknown) => {
						const row = luaProp(entry, "item");
						return hl(MailRow, { item: luaProp(row, "item"), mail: luaProp(row, "mail"), active: luaProp(row, "Id") === selectedRowId, order: 0, softMotion, onChoose: choose });
					} }));
		const inboxChildren = [
			React.createElement("frame", { key: "search", Size: new UDim2(1, 0, 0, searchH), BackgroundTransparency: 1, LayoutOrder: 0 },
				hl(SearchField, { value: query, onChange: (text: unknown) => {
					luaCall(setQuery, text);
					luaCall(setSelectedId, "");
				}, placeholder: "Search letters", accent: P.mint, reducedMotion: softMotion, size: UDim2.fromScale(1, 1), zIndex: 6 })),
			inboxList,
		];
		let reader: React.Element | undefined;
		if (selected !== undefined) {
			const item = luaProp(selected, "item");
			const tint = luaProp(item, "Color") as Color3;
			const readerW = luaTruthy(mobileRoute) ? (luaProp(viewport, "width") as number) - 24 : (luaProp(viewport, "width") as number) * 0.6;
			const textW = math.max(60, readerW - 64);
			const bodySize = phone ? 16 : 15;
			const bodyRows: defined[] = [];
			let stride = 28;
			for (const [index, paragraph] of pairs((luaProp(item, "Body") ?? {}) as object) as IterableFunction<LuaTuple<[number, unknown]>>) {
				const height = luaCall(paragraphHeight, paragraph, textW, bodySize) as number;
				stride = math.max(stride, height + 10);
				bodyRows.push({ Id: `${luaProp(item, "Id")}:${index}`, Text: paragraph, Index: index - 1, Height: height });
			}
			const gift = luaTruthy(luaCall(hasGift, item));
			const claimed = luaProp(luaProp(selected, "mail"), "Claimed") === true;
			const parcelH = !gift ? 0 : phone ? 48 + 10 + (TapTarget as number) + 24 : 78;
			const letterH = phone ? 52 : 64;
			const head = React.createElement("frame", { key: "head", Name: "LetterHead", Size: new UDim2(1, 0, 0, letterH), BackgroundTransparency: 1, LayoutOrder: 0 },
				list("Horizontal", 14),
				luaTruthy(mobileRoute)
					? React.createElement("frame", { Size: UDim2.fromOffset(TapTarget as number, TapTarget as number), BackgroundTransparency: 1, LayoutOrder: 0 },
							hl(Button, { text: "", icon: "Back.1", onClick: () => luaCall(setSelectedId, ""), color: SEC, textColor: tint, outline: true, size: UDim2.fromScale(1, 1), reducedMotion: softMotion }))
					: hl(Avatar, { item, unread: true, size: 52, layoutOrder: 0 }),
				React.createElement("frame", { Size: new UDim2(0, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
					fill(),
					list("Vertical", 4, { VerticalAlignment: Enum.VerticalAlignment.Center }),
					React.createElement(Line, { text: tostring(luaProp(item, "Subject") ?? ""), size: phone ? 18 : 22, font: TITLE_FACE, color: P.cream, width: new UDim(1, 0), height: phone ? 24 : 30, layoutOrder: 0 }),
					React.createElement(Line, { text: `From ${luaProp(item, "Sender")}${luaTruthy(luaProp(item, "Date")) ? `  ·  ${luaProp(item, "Date")}` : ""}`, size: 12, font: BODY_BOLD, color: tint, width: new UDim(1, 0), height: 18, layoutOrder: 1 }),
				),
			);
			const body = React.createElement("frame", { key: "body", Size: new UDim2(1, 0, 0, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
				fill(),
				hl(FlatList, { key: luaProp(item, "Id"), data: bodyRows, itemHeight: stride, overscan: luaTruthy(softMotion) ? 0 : luaTruthy(luaProp(antilag, "constrained")) ? 1 : 2, canvasTail: 8, Size: UDim2.fromScale(1, 1), scrollBarColor: tint, scrollBarThickness: 3, keyExtractor: (row: unknown) => luaProp(row, "Id"), renderItem: (entry: unknown) => {
					const row = luaProp(entry, "item");
					if (luaProp(row, "Index") === 0) {
						return hl(ScriptedText, { key: luaProp(row, "Id"), text: luaProp(row, "Text"), width: textW, height: luaProp(row, "Height"), size: bodySize, color: P.cream, weight: Enum.FontWeight.SemiBold, typewriterInterval: 0.01, reducedMotion: softMotion });
					}
					return hl(Text, { key: luaProp(row, "Id"), value: luaProp(row, "Text"), size: bodySize, color: P.creamSoft, wrap: true, fit: true, minSize: 10, sizeConstraint: new UDim2(1, -8, 0, luaProp(row, "Height") as number) });
				} }));
			const parcel = gift
				? React.createElement("frame", { key: "parcel", ref: mailActionsHostRef as never, Size: new UDim2(1, 0, 0, parcelH), BackgroundTransparency: 1, ClipsDescendants: false, LayoutOrder: 2 },
						hl(Parcel, { item, claimed, stack, height: parcelH, softMotion, claimToken, onClaim: () => {
							colon(Audio).play("mailClaim");
							luaCall(setClaimToken, (n: number) => n + 1);
							luaCall(dispatch, "ClaimMail", { Id: luaProp(item, "Id") });
						}, onArchive: () => {
							luaCall(dispatch, "DeleteMail", { Id: luaProp(item, "Id") }, (response: unknown) => {
								if (luaTruthy(luaProp(mountedRef, "current")) && luaTruthy(luaProp(response, "ok"))) {
									luaCall(setSelectedId, "");
								}
							});
						} }))
				: undefined;
			reader = React.createElement(MockPanel as never, { size: UDim2.fromScale(1, 1), phone, accent: tint, gap, name: "Letter" } as never, head, body, parcel) as unknown as React.Element;
		} else if (!luaTruthy(mobileRoute)) {
			reader = hl(EmptyState, { icon: "Mail.4", title: "Pick a letter", body: "Choose a message on the left to read it.", accent: P.mint, size: UDim2.fromScale(1, 1), reducedMotion: softMotion });
		}
		const inboxPanel = React.createElement(MockPanel as never, { size: UDim2.fromScale(1, 1), phone, accent: P.brass, gap: 8 } as never, ...inboxChildren) as unknown as React.Element;
		let bodyRow: React.Element;
		if (luaTruthy(mobileRoute)) {
			// phones: the inbox and the letter are two pages; the spring slides one off as the other comes in
			const s = slide as React.Binding<number>;
			bodyRow = React.createElement("frame", { Name: "MailPager", Size: new UDim2(1, 0, 0, 0), BackgroundTransparency: 1, ClipsDescendants: true, LayoutOrder: 1 },
				fill(),
				React.createElement("frame", { Name: "Inbox", SelectionGroup: true, Size: UDim2.fromScale(1, 1), Position: s.map((a: number) => UDim2.fromScale(-math.clamp(a, 0, 1), 0)), Visible: s.map((a: number) => a < 0.99), BackgroundTransparency: 1 }, inboxPanel),
				reader !== undefined
					? React.createElement("frame", { Name: "Reader", SelectionGroup: true, Size: UDim2.fromScale(1, 1), Position: s.map((a: number) => UDim2.fromScale(1 - math.clamp(a, 0, 1), 0)), Visible: s.map((a: number) => a > 0.01), BackgroundTransparency: 1 }, reader)
					: undefined,
			);
		} else {
			// desktop .flexr: inbox 38%, the open letter fills the rest
			bodyRow = React.createElement("frame", { Name: "MailBody", Size: new UDim2(1, 0, 0, 0), BackgroundTransparency: 1, LayoutOrder: 1 },
				fill(),
				list("Horizontal", gap, { VerticalAlignment: Enum.VerticalAlignment.Top }),
				React.createElement("frame", { Name: "Inbox", SelectionGroup: true, Size: new UDim2(0.38, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 0 }, inboxPanel),
				React.createElement("frame", { Name: "Reader", SelectionGroup: true, Size: new UDim2(0, 0, 1, 0), BackgroundTransparency: 1, LayoutOrder: 1 }, fill(), reader),
			);
		}
		return React.createElement("frame", { Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, ClipsDescendants: true },
			list("Vertical", gap, { VerticalAlignment: Enum.VerticalAlignment.Top }),
			header,
			bodyRow,
		);
	}
	return { MailboxView: MailboxView };
}
export = __member();
