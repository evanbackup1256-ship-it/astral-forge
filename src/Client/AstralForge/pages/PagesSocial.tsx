// PagesSocial.luau — compiled page bundle for the Social tab.
// Members are required lazily: PagesSocial("TradeView") only pays for that page's code.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { unixNow } from "../CoreKit/deadlines";
import { asFlux, compactNumber } from "../CoreKit/format";
import { chromeFor, darken, Layout, Palette, scrollTail, TapTarget } from "../CoreKit/theme";
import { useEntrance, useStagger, useViewport } from "../MotionKit/motion";
import { Icon } from "../ArtKit/Icon";
import { HEADER_ART } from "../ArtKit/uiArt";
import * as ForgeTheme from "../../../Shared/AstralForge/Shared/ForgeTheme";
import { SpriteCard, SPRITE_CARD_GAP, SPRITE_CARD_H, SPRITE_CARD_W } from "./views/PortSpriteCard";
import { useTouchTargets } from "../UiCore/ui";
import { MockTabs } from "./socialKit";
import { useFocusOrder } from "../CoreKit/focusOrder";
import TradeHistory = require("../../../Shared/AstralForge/Shared/TradeHistory");
import { Dict } from "../lua";
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";
import { usePlayPolicy } from "../CoreKit/playPolicy";
import { loadAudio, loadBrowse, loadPageScaffold, loadUi } from "./luauDeps";
import { Chip, GlyphWell, Label, NUM, PanelHeading, PnSurface, ROW_RADIUS, rowFace, panelHeadingH } from "../UiCore/mockKit";
import { SEC } from "./mockRows";

const Players = game.GetService("Players");
const UserInputService = game.GetService("UserInputService");

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
		error(`PagesSocial: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`PagesSocial: cyclic require of member ${name}`, 2);
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

interface DispatchResponse {
	ok?: boolean;
	[key: string]: unknown;
}

type SocialDispatch = (
	this: void,
	action: string,
	payload?: unknown,
	reply?: (this: void, response: DispatchResponse) => void,
) => void;

/** af.css .row face (radius 11, faint top-lit fill) for trade cards; replaces the old cast-iron plate and brass lip. */
function tradeFace(): React.ReactElement {
	return h(
		React.Fragment,
		{ key: "Face" },
		h("uicorner", { CornerRadius: new UDim(0, 11) }),
		h("uigradient", {
			Rotation: 90,
			Color: new ColorSequence(Palette.white, Palette.void),
			Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0.965), new NumberSequenceKeypoint(1, 0.88)]),
		}),
	);
}

__defs["TradeView"] = () => {
	const Audio = loadAudio();
	const PageScaffold = loadPageScaffold();
	const {
		Badge,
		Button,
		EmptyState,
		QuantityStepper,
		SearchField,
		Stroke,
		Text,
} = loadUi();
	const Browse = loadBrowse();

	const BOOSTS = [
		"DomainSurge",
		"Overdrive",
		"Hyperdrive",
		"VaultSurge",
		"NightShift",
		"FoundryRush",
		"Afterburner",
		"SteadyBurn",
		"CoreSurge",
		"StarforgeFlow",
		"EchoDrive",
		"Ionstorm",
		"TwinCatalyst",
		"MidnightForge",
	];
	const KEYS = ["ForgeCrate", "CrystalCrate", "HorizonCrate", "NebulaCrate", "OrbitCrate", "SingularityCrate", "EchoCrate"];
	const BOOST_LABELS: Record<string, string> = {
		Overdrive: "Overdrive",
		Hyperdrive: "Hyperdrive",
		VaultSurge: "Vault Surge",
		DomainSurge: "Domain Surge",
		NightShift: "Night Shift",
		FoundryRush: "Foundry Rush",
		Afterburner: "Afterburner",
		SteadyBurn: "Steady Burn",
		CoreSurge: "Core Surge",
		StarforgeFlow: "Starforge Flow",
		EchoDrive: "Echo Drive",
		Ionstorm: "Ionstorm",
		TwinCatalyst: "Twin Catalyst",
		MidnightForge: "Midnight Forge",
	};
	const KEY_LABELS: Record<string, string> = {
		ForgeCrate: "Forge key",
		CrystalCrate: "Crystal key",
		HorizonCrate: "Horizon key",
		NebulaCrate: "Nebula key",
		OrbitCrate: "Orbit key",
		SingularityCrate: "Singularity key",
		EchoCrate: "Echo key",
	};

	interface RelicPreview {
		Uid: string;
		Name: string;
		DefinitionId: string;
		[key: string]: unknown;
	}

	interface TradeOffer {
		Cash: number;
		Stardust: number;
		Cores: number;
		Signals: number;
		Essence: number;
		Boosts: Record<string, number>;
		Keys: Record<string, number>;
		ItemIds: string[];
		Items?: RelicPreview[];
		[key: string]: unknown;
	}

	interface ItemDefinition {
		Id: string;
		Name: string;
		Rarity?: string;
		[key: string]: unknown;
	}

	interface TradeConfig {
		Items?: { Definitions?: ItemDefinition[]; [key: string]: unknown };
		Trading?: { DailyTrades?: number; [key: string]: unknown };
		ClientPageGuides?: { Trade?: { EmptySession?: string; [key: string]: unknown }; [key: string]: unknown };
		[key: string]: unknown;
	}

	interface RelicInstance {
		DefinitionId: string;
		Locked?: boolean;
		[key: string]: unknown;
	}

	interface ChatLine {
		From: number;
		Name: string;
		Text: string;
		Phrase?: number;
		[key: string]: unknown;
	}

	interface PartnerRelic {
		Uid: string;
		Name: string;
		Rarity: string;
		Level?: number;
		[key: string]: unknown;
	}

	interface TradeSession {
		Id: string;
		PartnerName: string;
		PartnerAway?: boolean;
		You: TradeOffer;
		Them: TradeOffer;
		YouReady?: boolean;
		ThemReady?: boolean;
		YouConfirmed?: boolean;
		ThemConfirmed?: boolean;
		ExpiresAt: number;
		ConfirmEndsAt: number;
		Chat?: ChatLine[];
		YourRequest?: TradeOffer;
		TheirRequest?: TradeOffer;
		PartnerRelics?: PartnerRelic[];
		[key: string]: unknown;
	}

	interface TradeInvite {
		FromUserId: number;
		FromName?: string;
		ExpiresAt: number;
		[key: string]: unknown;
	}

	interface TradeOutgoing {
		ToUserId: number;
		ToName?: string;
		ExpiresAt: number;
		[key: string]: unknown;
	}

	interface TradeDaily {
		PerTrade?: Record<string, number>;
		Sent?: Record<string, number>;
		Caps?: Record<string, number>;
		Limit?: number;
		Completed?: number;
		[key: string]: unknown;
	}

	interface HistoryEntry {
		At: number;
		PartnerId: number;
		Partner: string;
		Gave: string;
		Got: string;
		[key: string]: unknown;
	}

	interface TradeState {
		Unlocked?: boolean;
		Session?: TradeSession;
		Invite?: TradeInvite;
		Outgoing?: TradeOutgoing;
		Daily?: TradeDaily;
		Epoch?: unknown;
		History?: HistoryEntry[];
		[key: string]: unknown;
	}

	interface TradeRelic {
		uid: string;
		name: string;
		art: RelicArt;
	}

	// 08-trading: relics show as sprite cards; rarity and element come from the item definition
	interface RelicArt {
		rarity: string;
		element?: string;
	}

	const TRADE_SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);
	const TRADE_NUMERIC = NUM;
	// 08 .sc .w well #0d090f
	const SLOT_WELL = Color3.fromRGB(13, 9, 15);

	function relicArt(config: TradeConfig, definitionId: string): RelicArt {
		for (const definition of config.Items?.Definitions ?? []) {
			if (definition.Id === definitionId) {
				const element = (definition as { Element?: unknown }).Element;
				return { rarity: definition.Rarity ?? "Common", element: typeIs(element, "string") ? element : undefined };
			}
		}
		return { rarity: "Common" };
	}

	function rarityTint(rarity: string): Color3 {
		return (ForgeTheme.Rarity as Record<string, Color3 | undefined>)[rarity] ?? Palette.lineSoft;
	}

	// card grid height for `count` cards at a conservative column count (the pane hugs its content)
	function relicGridHeight(count: number, columns: number): number {
		if (count <= 0) {
			return 0;
		}
		const rows = math.ceil(count / math.max(1, columns));
		return rows * SPRITE_CARD_H + (rows - 1) * SPRITE_CARD_GAP + 12;
	}

	interface RosterRow {
		UserId: number;
		DisplayName: string;
		Name?: string;
		IsLocal?: boolean;
		Rebirths?: number;
		CurrentZone?: number;
		[key: string]: unknown;
	}

	interface OfferLine {
		key: string;
		label: string;
		detail: string;
		accent: Color3;
		icon: string;
		relic?: RelicArt;
	}

	function emptyOffer(): TradeOffer {
		return {
			Cash: 0,
			Stardust: 0,
			Cores: 0,
			Signals: 0,
			Essence: 0,
			Boosts: {
				DomainSurge: 0,
				Overdrive: 0,
				Hyperdrive: 0,
				VaultSurge: 0,
				NightShift: 0,
				FoundryRush: 0,
				Afterburner: 0,
				SteadyBurn: 0,
				CoreSurge: 0,
				StarforgeFlow: 0,
				EchoDrive: 0,
				Ionstorm: 0,
				TwinCatalyst: 0,
				MidnightForge: 0,
			},
			Keys: {
				ForgeCrate: 0,
				CrystalCrate: 0,
				HorizonCrate: 0,
				NebulaCrate: 0,
				OrbitCrate: 0,
				SingularityCrate: 0,
				EchoCrate: 0,
			},
			ItemIds: [],
			Items: [],
		};
	}

	function wireOffer(offer: unknown): TradeOffer {
		if (!typeIs(offer, "table")) {
			return emptyOffer();
		}
		const o = offer as Dict;
		const result: TradeOffer = {
			Cash: tonumber(o.Cash) ?? 0,
			Stardust: tonumber(o.Stardust) ?? 0,
			Cores: tonumber(o.Cores) ?? 0,
			Signals: tonumber(o.Signals) ?? 0,
			Essence: tonumber(o.Essence) ?? 0,
			Boosts: {},
			Keys: {},
			ItemIds: typeIs(o.ItemIds, "table") ? table.clone(o.ItemIds as string[]) : [],
		};
		const boosts = o.Boosts as Dict | undefined;
		for (const id of BOOSTS) {
			const amount = (boosts !== undefined ? tonumber(boosts[id]) : 0) ?? 0;
			if (amount > 0) {
				result.Boosts[id] = amount;
			}
		}
		const keys = o.Keys as Dict | undefined;
		for (const id of KEYS) {
			const amount = (keys !== undefined ? tonumber(keys[id]) : 0) ?? 0;
			if (amount > 0) {
				result.Keys[id] = amount;
			}
		}
		return result;
	}

	function itemName(config: TradeConfig, definitionId: string): string {
		for (const definition of config.Items?.Definitions ?? []) {
			if (definition.Id === definitionId) {
				return definition.Name;
			}
		}
		return definitionId;
	}

	function clockLabel(deadline: number, now: number): string {
		const left = math.max(0, math.floor(deadline - now));
		const minutes = math.floor(left / 60);
		const seconds = left % 60;
		return minutes > 0 ? `${minutes}:${"%02d".format(seconds)}` : `${seconds}s`;
	}

	function offerEmpty(offer: TradeOffer): boolean {
		if (offer.Cash > 0 || offer.Stardust > 0 || offer.Cores > 0 || offer.Signals > 0 || offer.Essence > 0) {
			return false;
		}
		for (const id of BOOSTS) {
			if ((offer.Boosts[id] ?? 0) > 0) {
				return false;
			}
		}
		for (const id of KEYS) {
			if ((offer.Keys[id] ?? 0) > 0) {
				return false;
			}
		}
		return offer.ItemIds.size() === 0;
	}

	function offerLines(offer: TradeOffer, config: TradeConfig, inventory: Record<string, RelicInstance>): OfferLine[] {
		const lines: OfferLine[] = [];
		if (offer.Cash > 0) {
			lines.push({
				key: "cash",
				label: `${compactNumber(offer.Cash)} Flux`,
				detail: "Currency",
				accent: Palette.cyan,
				icon: "Flux.15",
			});
		}
		if (offer.Stardust > 0) {
			lines.push({
				key: "dust",
				label: `${compactNumber(offer.Stardust)} Stardust`,
				detail: "Dust",
				accent: Palette.mango,
				icon: "Dust.4",
			});
		}
		if (offer.Cores > 0) {
			lines.push({
				key: "cores",
				label: `${offer.Cores} Cores`,
				detail: "Prestige",
				accent: Palette.violet,
				icon: "Core.6",
			});
		}
		if (offer.Signals > 0) {
			lines.push({
				key: "signals",
				label: `${offer.Signals} Signals`,
				detail: "Command",
				accent: Palette.cyan,
				icon: "Command.3",
			});
		}
		if (offer.Essence > 0) {
			lines.push({
				key: "essence",
				label: `${offer.Essence} Essence`,
				detail: "Relic craft",
				accent: Palette.pink,
				icon: "Artifact.6",
			});
		}
		for (const id of BOOSTS) {
			const count = offer.Boosts[id] ?? 0;
			if (count > 0) {
				lines.push({
					key: `boost-${id}`,
					label: `${count}× ${BOOST_LABELS[id] ?? id}`,
					detail: "Boost",
					accent: Palette.coral,
					icon: "Boost.17",
				});
			}
		}
		for (const id of KEYS) {
			const count = offer.Keys[id] ?? 0;
			if (count > 0) {
				lines.push({
					key: `key-${id}`,
					label: `${count}× ${KEY_LABELS[id] ?? id}`,
					detail: "Crate key",
					accent: Palette.mango,
					icon: "Crate.6",
				});
			}
		}
		const previews = offer.Items ?? [];
		if (previews.size() > 0) {
			for (const preview of previews) {
				lines.push({
					key: preview.Uid,
					label: preview.Name,
					detail: "Relic",
					accent: Palette.mint,
					icon: "Inventory.2",
					relic: relicArt(config, preview.DefinitionId),
				});
			}
		} else {
			for (const uid of offer.ItemIds) {
				const instance = inventory[uid];
				lines.push({
					key: uid,
					label: instance !== undefined ? itemName(config, instance.DefinitionId) : "Relic",
					detail: "Relic",
					accent: Palette.mint,
					icon: "Inventory.3",
					relic: instance !== undefined ? relicArt(config, instance.DefinitionId) : { rarity: "Common" },
				});
			}
		}
		return lines;
	}

	function useSecondClock(): number {
		const [now, setNow] = React.useState(unixNow());
		React.useEffect(() => {
			let alive = true;
			const worker = task.spawn(() => {
				while (alive) {
					task.wait(0.5);
					if (!alive) {
						break;
					}
					setNow(unixNow());
				}
			});
			return () => {
				alive = false;
				pcall(() => task.cancel(worker));
			};
		}, []);
		return now;
	}

	interface AvatarMarkProps {
		userId: number;
		accent: Color3;
		size: number;
		layoutOrder?: number;
	}

	// round headshot well: 2px inset via padding, so it drops straight into a row list
	function AvatarMark(_param: AvatarMarkProps) {
		const userId = _param.userId;
		const accent = _param.accent;
		const size = _param.size;
		return h(
			"frame",
			{
				Size: UDim2.fromOffset(size, size),
				BackgroundColor3: darken(accent, 0.62),
				BorderSizePixel: 0,
				ClipsDescendants: true,
				LayoutOrder: _param.layoutOrder ?? 0,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(Stroke, {
				color: accent,
				thickness: 1,
				transparency: 0.28,
			}),
			h("uipadding", {
				PaddingTop: new UDim(0, 2),
				PaddingBottom: new UDim(0, 2),
				PaddingLeft: new UDim(0, 2),
				PaddingRight: new UDim(0, 2),
			}),
			h(
				"imagelabel",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					Image: `rbxthumb://type=AvatarHeadShot&id=${userId > 0 ? userId : 1}&w=150&h=150`,
					ScaleType: Enum.ScaleType.Crop,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			),
		);
	}

	interface OfferRowProps {
		line: OfferLine;
		touch?: boolean;
		layoutOrder?: number;
	}

	// 08 .row: [36px well] [name, flex] [value]; one horizontal list, 12px gap, 6/12 padding
	function OfferRow(_param: OfferRowProps) {
		const line = _param.line;
		const touch = _param.touch ?? false;
		const rowH = touch ? 52 : 48;
		const tile = 36;
		return h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, rowH),
				BackgroundColor3: Palette.panelRaised,
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: true,
				LayoutOrder: _param.layoutOrder ?? 0,
			},
			rowFace(),
			h("uipadding", {
				PaddingTop: new UDim(0, 6),
				PaddingBottom: new UDim(0, 6),
				PaddingLeft: new UDim(0, 12),
				PaddingRight: new UDim(0, 12),
			}),
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				VerticalAlignment: Enum.VerticalAlignment.Center,
				Padding: new UDim(0, 12),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			h(GlyphWell, {
				kind: line.icon,
				accent: line.accent,
				size: tile,
				layoutOrder: 0,
			}),
			h(
				"frame",
				{
					Size: new UDim2(0, 0, 0, 20),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: 1,
				},
				h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
				h(Text, {
					value: line.detail,
					size: 14,
					color: Palette.cream,
					weight: Enum.FontWeight.SemiBold,
					fit: true,
					sizeConstraint: new UDim2(1, 0, 0, 20),
				}),
			),
			h(
				"textlabel",
				{
					Text: line.label,
					FontFace: TRADE_NUMERIC,
					TextColor3: line.accent,
					TextSize: 17,
					TextXAlignment: Enum.TextXAlignment.Right,
					BackgroundTransparency: 1,
					Size: new UDim2(0, 0, 0, 20),
					AutomaticSize: Enum.AutomaticSize.X,
					LayoutOrder: 2,
				},
			),
		);
	}

	function calcOfferValue(offer: unknown): number {
		if (!typeIs(offer, "table")) {
			return 0;
		}
		const o = offer as Dict;
		let total =
			(tonumber(o.Cash) ?? 0) / 10000 +
			(tonumber(o.Stardust) ?? 0) * 10 +
			(tonumber(o.Cores) ?? 0) * 1000 +
			(tonumber(o.Signals) ?? 0) * 20 +
			(tonumber(o.Essence) ?? 0) * 15;
		if (typeIs(o.Boosts, "table")) {
			for (const [, count] of pairs(o.Boosts as Dict)) {
				total += (tonumber(count) ?? 0) * 450;
			}
		}
		if (typeIs(o.Keys, "table")) {
			for (const [, count] of pairs(o.Keys as Dict)) {
				total += (tonumber(count) ?? 0) * 350;
			}
		}
		if (typeIs(o.ItemIds, "table")) {
			total += (o.ItemIds as defined[]).size() * 800;
		}
		return math.round(total);
	}

	// 08 action bar chip: "Value check: you give about 1.4x what you get"
	function tradeBalance(draft: TradeOffer, them: TradeOffer | undefined): { text: string; accent?: Color3 } {
		const yourScore = calcOfferValue(draft);
		const theirScore = calcOfferValue(them);
		if (yourScore === 0 && theirScore === 0) {
			return { text: "Value check: add something to compare" };
		}
		if (theirScore === 0) {
			return { text: "Value check: they haven't added anything yet", accent: Palette.mango };
		}
		if (yourScore === 0) {
			return { text: "Value check: you haven't added anything yet", accent: Palette.cyan };
		}
		const ratio = yourScore / theirScore;
		if (ratio >= 0.85 && ratio <= 1.18) {
			return { text: "Value check: about even", accent: Palette.mint };
		}
		const factor = math.min(99, ratio > 1 ? ratio : 1 / ratio);
		// 1.4x under ten, whole numbers above (capped at 99x) so the phone line never outgrows 360px
		const times = factor < 10 ? string.format("%.1f", factor) : tostring(math.floor(factor));
		return ratio > 1
			? { text: `Value check: you give about ${times}x what you get`, accent: Palette.mango }
			: { text: `Value check: you get about ${times}x what you give`, accent: Palette.cyan };
	}

	// quick phrases: the same list as the server's (TradeDesk.PHRASES), sent by index so they never need filtering
	const TRADE_PHRASES = [
		"Deal?",
		"Can you add a little more?",
		"That's fair.",
		"Not for that.",
		"Let me look.",
		"Ready when you are.",
		"Thanks for the trade.",
		"One sec.",
	];

	interface TradeChatStreamProps {
		session: TradeSession;
		dispatch: SocialDispatch;
	}

	// table talk: the real conversation from the server, quick phrases, and a filtered line of your own.
	// One vertical list: heading, the log (fills, newest pinned to the bottom, older lines clip off the top:
	// no scroller inside the page scroller), wrapping phrase pills, then the input row.
	const CHAT_VISIBLE_LINES = 14;
	function TradeChatStream(props: TradeChatStreamProps) {
		const session = props.session;
		const dispatch = props.dispatch;
		const [inputVal, setInputVal] = React.useState("");
		// phones and touch: quick phrases and the input row get full tap height
		const touchRows = useTouchTargets();
		const pillH = touchRows ? TapTarget : 26;
		const inputH = touchRows ? TapTarget : 32;
		const lines = session.Chat ?? [];
		const myId = Players.LocalPlayer!.UserId;
		const seen = React.useRef(lines.size());
		React.useEffect(() => {
			// a new line from them gets a sound
			if (lines.size() > seen.current && lines[lines.size() - 1] !== undefined && lines[lines.size() - 1].From !== myId) {
				Audio.play("chatReceive");
			}
			seen.current = lines.size();
		}, [lines.size()]);
		const send = (text?: string, phrase?: number) => {
			const clean = text !== undefined ? string.gsub(text, "^%s*(.-)%s*$", "%1")[0] : undefined;
			if (phrase === undefined && (clean === undefined || clean === "")) {
				return;
			}
			Audio.play("chatSend");
			dispatch("TradeChat", phrase !== undefined ? { Phrase: phrase } : { Text: clean!.sub(1, 140) });
			setInputVal("");
		};
		const pills: Record<string, unknown> = {
			layout: h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				Wraps: true,
				Padding: new UDim(0, 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		for (const [index, phrase] of ipairs(TRADE_PHRASES)) {
			pills[`p${index}`] = h(
				"textbutton",
				{
					LayoutOrder: index,
					Text: phrase,
					Size: new UDim2(0, 0, 0, pillH),
					AutomaticSize: Enum.AutomaticSize.X,
					BackgroundColor3: Palette.panelSoft,
					TextColor3: Palette.cream,
					TextSize: 12,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansBold),
					AutoButtonColor: false,
					Event: {
						Activated: () => {
							send(undefined, index);
						},
					},
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h("uipadding", {
					PaddingLeft: new UDim(0, 10),
					PaddingRight: new UDim(0, 10),
				}),
			);
		}
		const rows: Record<string, unknown> = {
			layout: h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				VerticalAlignment: Enum.VerticalAlignment.Bottom,
				Padding: new UDim(0, 4),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		if (lines.size() === 0) {
			rows.empty = h(Text, {
				value: "…",
				size: 12,
				color: Palette.muted,
				layoutOrder: 0,
				sizeConstraint: new UDim2(1, 0, 0, 18),
			});
		}
		const firstShown = math.max(1, lines.size() - CHAT_VISIBLE_LINES + 1);
		for (const [index, line] of ipairs(lines)) {
			if (index < firstShown) {
				continue;
			}
			const mine = line.From === myId;
			rows[`l${index}`] = h(
				"frame",
				{
					LayoutOrder: index,
					Size: new UDim2(1, 0, 0, 0),
					AutomaticSize: Enum.AutomaticSize.Y,
					BackgroundTransparency: 1,
				},
				// mine sit right, theirs left: a one-item list aligned to the speaker's side
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					HorizontalAlignment: mine ? Enum.HorizontalAlignment.Right : Enum.HorizontalAlignment.Left,
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h(
					"textlabel",
					{
						Size: new UDim2(0.82, 0, 0, 0),
						AutomaticSize: Enum.AutomaticSize.Y,
						LayoutOrder: 0,
						BackgroundColor3: mine ? darken(Palette.mint, 0.6) : Palette.panelSoft,
						Text: `${mine ? "" : `<b>${line.Name}</b>  `}${line.Text}`,
						RichText: true,
						TextWrapped: true,
						TextSize: 13,
						FontFace: Font.fromEnum(line.Phrase !== undefined ? Enum.Font.BuilderSansBold : Enum.Font.BuilderSansMedium),
						TextColor3: Palette.cream,
						TextXAlignment: mine ? Enum.TextXAlignment.Right : Enum.TextXAlignment.Left,
					},
					h("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }), rowFace(),
					h("uipadding", {
						PaddingTop: new UDim(0, 6),
						PaddingBottom: new UDim(0, 6),
						PaddingLeft: new UDim(0, 10),
						PaddingRight: new UDim(0, 10),
					}),
				),
			);
		}
		return h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.panel,
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }), rowFace(),
			h(Stroke, {
				color: Palette.brass,
				thickness: 1,
				transparency: 0.4,
			}),
			h("uipadding", {
				PaddingTop: new UDim(0, 10),
				PaddingBottom: new UDim(0, 10),
				PaddingLeft: new UDim(0, 12),
				PaddingRight: new UDim(0, 12),
			}),
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			h(Text, {
				value: session.PartnerAway === true ? `${session.PartnerName} stepped away` : "Table talk",
				size: 11,
				color: session.PartnerAway === true ? Palette.coral : Palette.mint,
				weight: Enum.FontWeight.Heavy,
				layoutOrder: 0,
				sizeConstraint: new UDim2(1, 0, 0, 14),
			}),
			h(
				"frame",
				{
					Name: "TradeChatLog",
					Size: new UDim2(1, 0, 0, 0),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: true,
					LayoutOrder: 1,
				},
				h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
				rows,
			),
			h(
				"frame",
				{
					Name: "TradeChatPhrases",
					Size: new UDim2(1, 0, 0, 0),
					AutomaticSize: Enum.AutomaticSize.Y,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: 2,
				},
				pills,
			),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, inputH),
					BackgroundTransparency: 1,
					LayoutOrder: 3,
				},
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					Padding: new UDim(0, 8),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h(
					"textbox",
					{
						Size: new UDim2(0, 0, 1, 0),
						LayoutOrder: 0,
						BackgroundColor3: Palette.graphite,
						TextColor3: Palette.cream,
						PlaceholderText: `Say something to ${session.PartnerName}`,
						PlaceholderColor3: Palette.muted,
						Text: inputVal,
						TextSize: 13,
						FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextXAlignment: Enum.TextXAlignment.Left,
						ClearTextOnFocus: false,
						BorderSizePixel: 0,
						Change: {
							Text: (rbx: TextBox) => {
								if (rbx.Text.size() > 140) {
									rbx.Text = rbx.Text.sub(1, 140);
								}
								setInputVal(rbx.Text);
							},
						},
						Event: {
							FocusLost: (_rbx: TextBox, enterPressed: boolean) => {
								if (enterPressed) {
									send(inputVal);
								}
							},
						},
					},
					h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
					h("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }), rowFace(),
					h("uipadding", { PaddingLeft: new UDim(0, 10) }),
				),
				h(
					"frame",
					{
						Size: new UDim2(0, 70, 1, 0),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						LayoutOrder: 1,
					},
					h(Button, {
						text: "Send",
						onClick: () => {
							send(inputVal);
						},
						color: Palette.mint,
						textColor: Palette.ink,
						size: UDim2.fromScale(1, 1),
					}),
				),
			),
		);
	}

	// asking: browse what they could trade and ask for it; see what they asked of you and add it in one tap
	const RARITY_COLOR: Record<string, Color3> = {
		Common: Palette.muted,
		Uncommon: Palette.mint,
		Rare: Palette.cyan,
		Epic: Palette.violet,
		Legendary: Palette.mango,
		Mythic: Palette.pink,
	};

	interface TradeAsksProps {
		session: TradeSession;
		myRelics: TradeRelic[];
		dispatch: SocialDispatch;
		onAddRequested: (request: TradeOffer) => void;
	}

	function TradeAsks(props: TradeAsksProps) {
		const session = props.session;
		const myRelics = props.myRelics;
		const [asked, setAsked] = React.useState((): Record<string, boolean | undefined> => {
			const set: Record<string, boolean | undefined> = {};
			for (const uid of session.YourRequest?.ItemIds ?? []) {
				set[uid] = true;
			}
			return set;
		});
		let askCount = 0;
		for (const _ of pairs(asked)) {
			askCount += 1;
		}
		const relicNames: Record<string, string> = {};
		for (const relic of session.PartnerRelics ?? []) {
			relicNames[relic.Uid] = relic.Name;
		}
		// what they asked you for, and how much of it you actually have
		const theirs = session.TheirRequest;
		let theirLine: string | undefined = undefined;
		if (theirs !== undefined) {
			const parts: string[] = [];
			for (const key of ["Cash", "Stardust", "Cores", "Signals", "Essence"]) {
				if ((tonumber(theirs[key]) ?? 0) > 0) {
					parts.push(`${compactNumber(theirs[key])} ${key === "Cash" ? "Flux" : key}`);
				}
			}
			const mine: Record<string, string> = {};
			for (const relic of myRelics) {
				mine[relic.uid] = relic.name;
			}
			for (const uid of theirs.ItemIds ?? []) {
				if (mine[uid] !== undefined) {
					parts.push(mine[uid]);
				}
			}
			theirLine = parts.size() > 0 ? parts.join(", ") : undefined;
		}
		const chips: Record<string, unknown> = {
			layout: h("uigridlayout", {
				CellSize: new UDim2(0.5, -4, 0, 40),
				CellPadding: UDim2.fromOffset(8, 6),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		for (const [index, relic] of ipairs(session.PartnerRelics ?? [])) {
			const on = asked[relic.Uid] === true;
			const color = RARITY_COLOR[relic.Rarity] ?? Palette.muted;
			chips[`r${relic.Uid}`] = h(
				"textbutton",
				{
					LayoutOrder: index,
					BackgroundColor3: on ? darken(color, 0.55) : Palette.panelSoft,
					AutoButtonColor: false,
					Text: "",
					Event: {
						Activated: () => {
							Audio.play("tick");
							setAsked((current) => {
								const nextSet = table.clone(current);
								nextSet[relic.Uid] = nextSet[relic.Uid] === true ? undefined : true;
								return nextSet;
							});
						},
					},
				},
				h("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }), rowFace(),
				h(Stroke, {
					color: on ? color : Palette.line,
					thickness: on ? 2 : 1,
					transparency: on ? 0 : 0.5,
				}),
				h("uipadding", {
					PaddingTop: new UDim(0, 4),
					PaddingLeft: new UDim(0, 10),
					PaddingRight: new UDim(0, 10),
				}),
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					Padding: new UDim(0, 1),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h(Text, {
					value: relic.Name,
					size: 12,
					color: Palette.cream,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 9,
					layoutOrder: 0,
					sizeConstraint: new UDim2(1, 0, 0, 16),
				}),
				h(Text, {
					value: `${relic.Rarity.upper()}  ·  L${relic.Level}${on ? "  ·  ASKED" : ""}`,
					size: 10,
					color: color,
					weight: Enum.FontWeight.Heavy,
					layoutOrder: 1,
					sizeConstraint: new UDim2(1, 0, 0, 14),
				}),
			);
		}
		const partnerCount = (session.PartnerRelics ?? []).size();
		const gridRows = math.ceil(partnerCount / 2);
		return h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Palette.panel,
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }), rowFace(),
			h(Stroke, {
				color: Palette.brass,
				thickness: 1,
				transparency: 0.4,
			}),
			h("uipadding", {
				PaddingTop: new UDim(0, 10),
				PaddingBottom: new UDim(0, 10),
				PaddingLeft: new UDim(0, 12),
				PaddingRight: new UDim(0, 12),
			}),
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, 8),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
			theirLine !== undefined
				? h(
						"frame",
						{
							LayoutOrder: 1,
							Size: new UDim2(1, 0, 0, 58),
							BackgroundColor3: darken(Palette.mango, 0.7),
							BorderSizePixel: 0,
						},
						h("uicorner", { CornerRadius: new UDim(0, ROW_RADIUS) }), rowFace(),
						h("uipadding", {
							PaddingLeft: new UDim(0, 10),
							PaddingRight: new UDim(0, 10),
						}),
						h("uilistlayout", {
							FillDirection: Enum.FillDirection.Horizontal,
							VerticalAlignment: Enum.VerticalAlignment.Center,
							Padding: new UDim(0, 10),
							SortOrder: Enum.SortOrder.LayoutOrder,
						}),
						h(
							"frame",
							{
								Size: new UDim2(0, 0, 0, 44),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 0,
							},
							h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
							h("uilistlayout", {
								FillDirection: Enum.FillDirection.Vertical,
								Padding: new UDim(0, 4),
								SortOrder: Enum.SortOrder.LayoutOrder,
							}),
							h(Text, {
								value: `${session.PartnerName} wants`,
								size: 10,
								color: Palette.mango,
								weight: Enum.FontWeight.Heavy,
								layoutOrder: 0,
								sizeConstraint: new UDim2(1, 0, 0, 14),
							}),
							h(Text, {
								value: theirLine,
								size: 13,
								color: Palette.cream,
								weight: Enum.FontWeight.Bold,
								fit: true,
								minSize: 9,
								layoutOrder: 1,
								sizeConstraint: new UDim2(1, 0, 0, 26),
							}),
						),
						h(
							"frame",
							{
								Size: UDim2.fromOffset(130, 36),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 1,
							},
							h(Button, {
								text: "Add to my offer",
								onClick: () => {
									props.onAddRequested(theirs!);
								},
								color: Palette.mango,
								textColor: Palette.ink,
								size: UDim2.fromScale(1, 1),
							}),
						),
					)
				: undefined,
			h(Text, {
				value:
					partnerCount === 0
						? `${session.PartnerName} has no relics they could trade right now.`
						: `ASK ${session.PartnerName.upper()} FOR THEIR RELICS`,
				size: 11,
				color: Palette.mint,
				weight: Enum.FontWeight.Heavy,
				layoutOrder: 2,
				sizeConstraint: new UDim2(1, 0, 0, 16),
			}),
			partnerCount > 0
				? h(
						"frame",
						{
							LayoutOrder: 3,
							Size: new UDim2(1, 0, 0, gridRows * 46),
							BackgroundTransparency: 1,
						},
						chips,
					)
				: undefined,
			partnerCount > 0
				? h(
						"frame",
						{
							LayoutOrder: 4,
							Size: new UDim2(1, 0, 0, TapTarget),
							BackgroundTransparency: 1,
						},
						h(Button, {
							text:
								askCount > 0
									? `Ask for ${askCount} ${askCount === 1 ? "relic" : "relics"}`
									: "Pick relics to ask for",
							onClick: () => {
								const ids: string[] = [];
								for (const [uid] of pairs(asked)) {
									ids.push(uid);
								}
								props.dispatch("TradeRequest", { Request: { ItemIds: ids } });
							},
							disabled: askCount === 0,
							color: Palette.mint,
							textColor: Palette.ink,
							size: UDim2.fromScale(1, 1),
						}),
					)
				: undefined,
		);
	}

	// how tall TradeAsks wants to be
	function tradeAsksHeight(session: TradeSession): number {
		const partnerCount = (session.PartnerRelics ?? []).size();
		return (
			20 +
			(session.TheirRequest !== undefined ? 66 : 0) +
			24 +
			(partnerCount > 0 ? math.ceil(partnerCount / 2) * 46 + 8 + TapTarget : 0)
		);
	}

	interface TradeViewProps {
		state: {
			Trade?: TradeState;
			Items?: {
				Inventory?: Record<string, RelicInstance>;
				Equipped?: unknown;
				Essence?: unknown;
				Keys?: Record<string, number>;
				[key: string]: unknown;
			};
			Command?: { Signals?: unknown; [key: string]: unknown };
			Cash?: unknown;
			Stardust?: unknown;
			Cores?: unknown;
			BoostInventory?: Record<string, number>;
			FeatureUnlocks?: { Trade?: { Requirement?: string; [key: string]: unknown }; [key: string]: unknown };
			[key: string]: unknown;
		};
		config: TradeConfig;
		dispatch: SocialDispatch;
		reducedMotion?: boolean;
		[key: string]: unknown;
	}

	function TradeView(_param: TradeViewProps) {
		const state = _param.state;
		const config = _param.config;
		const dispatch = _param.dispatch;
		let reducedMotion = _param.reducedMotion;
		const viewport = useViewport();
		const chrome = chromeFor(viewport);
		const softMotion = reducedMotion;
		reducedMotion = softMotion;
		const enter = useEntrance(reducedMotion);
		const reveal = useStagger(0, softMotion);
		const boardReveal = useStagger(1, reducedMotion);
		const inviteReveal = useStagger(2, reducedMotion);
		const confirmReveal = useStagger(3, reducedMotion);
		const deskReveal = useStagger(4, reducedMotion);
		const dailyReveal = useStagger(5, reducedMotion);
		const softInvite = softMotion === true || inviteReveal !== undefined;
		const softConfirm = softMotion === true || confirmReveal !== undefined;
		const tradeSoft = softMotion === true || deskReveal === undefined || dailyReveal === undefined;
		const now = useSecondClock();
		const trade = state.Trade;
		const policy = usePlayPolicy();
		const regionBlocked = !policy.PaidItemTradingAllowed;
		const unlocked = trade?.Unlocked === true && !regionBlocked;
		const session = trade?.Session;
		const invite = trade?.Invite;
		const outgoing = trade?.Outgoing;
		const daily = trade?.Daily;
		const [rows, setRows] = React.useState<RosterRow[]>([]);
		const [query, setQuery] = React.useState("");
		const [selected, setSelected] = React.useState(0);
		const [draft, setDraft] = React.useState<TradeOffer>(emptyOffer());
		const [youReadyLocal, setYouReadyLocal] = React.useState(false);
		const [busy, setBusy] = React.useState("");
		const [shakeAction, setShakeAction] = React.useState<{ action: string; token: number }>();
		const [deskTab, setDeskTab] = React.useState("Trade");
		const dirtyRef = React.useRef(false);
		const flushRef = React.useRef<thread>();
		const offerRevisionRef = React.useRef(0);
		const offerSessionRef = React.useRef<string | undefined>(session !== undefined ? session.Id : undefined);
		const [offerPending, setOfferPending] = React.useState(false);
		const sessionActionsHostRef = React.useRef<Frame>();
		const lobbyHostRef = React.useRef<Frame>();
		// gamepad (lobby): incoming invite > outgoing > search > roster > Invite > history ("Trade again");
		// on desktop the roster column (Main) and history column (Side, right) step left/right.
		// The live session keeps its own FocusClaim on the Ready/Confirm bar.
		useFocusOrder(
			lobbyHostRef,
			{
				regions: ["daily", "lock", "invite", "outgoing", "search", "roster", "invite-cta", "history-*"],
				first: ["invite", "roster", "invite-cta", "search"],
			},
			[session === undefined, deskTab],
		);
		const inventory = state.Items?.Inventory ?? {};
		const equippedUids: Record<string, boolean> = {};
		for (const [, uid] of pairs((state.Items?.Equipped ?? {}) as Record<string, string>)) {
			if (uid !== "") {
				equippedUids[uid] = true;
			}
		}
		const loadRoster = React.useCallback(() => {
			dispatch("GetPlayers", {}, (response) => {
				if (!response.ok) {
					return;
				}
				const roster: RosterRow[] = [];
				for (const row of (response.Players ?? []) as RosterRow[]) {
					if (!row.IsLocal) {
						roster.push(row);
					}
				}
				setRows(roster);
				if (selected === 0 && roster.size() > 0) {
					setSelected(roster[0].UserId);
				}
			});
		}, [dispatch, selected]);
		React.useEffect(() => {
			loadRoster();
			const added = Players.PlayerAdded.Connect(() => loadRoster());
			const removed = Players.PlayerRemoving.Connect(() => loadRoster());
			let alive = true;
			const pulse = task.spawn(() => {
				while (alive) {
					task.wait(4);
					if (!alive) {
						break;
					}
					if (session === undefined) {
						loadRoster();
					}
				}
			});
			return () => {
				alive = false;
				added.Disconnect();
				removed.Disconnect();
				pcall(() => task.cancel(pulse));
			};
		}, [loadRoster, session?.Id]);
		React.useEffect(() => {
			const sessionId = session !== undefined ? session.Id : undefined;
			if (offerSessionRef.current !== sessionId) {
				offerSessionRef.current = sessionId;
				offerRevisionRef.current += 1;
				if (flushRef.current !== undefined) {
					pcall(() => task.cancel(flushRef.current!));
					flushRef.current = undefined;
				}
				dirtyRef.current = false;
				setOfferPending(false);
			}
			if (session === undefined) {
				if (flushRef.current !== undefined) {
					pcall(() => task.cancel(flushRef.current!));
					flushRef.current = undefined;
				}
				offerRevisionRef.current += 1;
				setOfferPending(false);
				setDraft(emptyOffer());
				setYouReadyLocal(false);
				dirtyRef.current = false;
				return;
			}
			setYouReadyLocal(session.YouReady === true);
			if (!dirtyRef.current) {
				setDraft(session.You);
			}
		}, [session?.Id, trade?.Epoch, session?.YouReady, session?.ThemReady, session?.YouConfirmed]);
		React.useEffect(() => {
			return () => {
				offerRevisionRef.current += 1;
				if (flushRef.current !== undefined) {
					pcall(() => task.cancel(flushRef.current!));
				}
			};
		}, []);
		const queueOffer = (offer: TradeOffer) => {
			setDraft(offer);
			setYouReadyLocal(false);
			dirtyRef.current = true;
			setOfferPending(true);
			offerRevisionRef.current += 1;
			const revision = offerRevisionRef.current;
			if (flushRef.current !== undefined) {
				pcall(() => task.cancel(flushRef.current!));
			}
			flushRef.current = task.delay(0.14, () => {
				flushRef.current = undefined;
				dispatch("UpdateTradeOffer", { Offer: wireOffer(offer) }, (response) => {
					if (revision !== offerRevisionRef.current) {
						return;
					}
					dirtyRef.current = false;
					setOfferPending(false);
					if (!response.ok && session !== undefined) {
						setDraft(session.You);
						setYouReadyLocal(false);
					}
				});
			});
		};
		const run = (action: string, payload?: unknown) => {
			if (payload === undefined) {
				payload = {};
			}
			if (busy !== "") {
				return;
			}
			setBusy(action);
			dispatch(action, payload, (response) => {
				setBusy("");
				if (!response.ok) {
					if (action === "SetTradeReady") {
						setYouReadyLocal(session !== undefined && session.YouReady === true);
					}
					setShakeAction((current) => ({
						action: action,
						token: (current !== undefined && current.action === action ? current.token : 0) + 1,
					}));
				}
			});
		};
		const shakeFor = (action: string): number => {
			return shakeAction !== undefined && shakeAction.action === action ? shakeAction.token : 0;
		};
		const cap = (key: string, owned: number): number => {
			const per = daily?.PerTrade?.[key];
			const used = daily?.Sent?.[key];
			const dailyLeft = (daily?.Caps?.[key] ?? owned) - (used ?? 0);
			return math.max(0, math.min(owned, per ?? owned, dailyLeft));
		};
		const lock = state.FeatureUnlocks?.Trade;
		const accent = Palette.brass;
		const fade = enter.map((amount) => {
			return 1 - math.clamp(amount, 0, 1);
		});
		const phone = chrome.stack || chrome.mobile;
		const compactTrade = phone || chrome.landscape || viewport.height < 700;
		const needle = query.lower();
		const visibleRows = (() => {
			const matches: RosterRow[] = [];
			for (const row of rows) {
				if (needle === "") {
					matches.push(row);
					continue;
				}
				if (Browse.matches(needle, row.DisplayName, row.Name)) {
					matches.push(row);
				}
			}
			return matches;
		})();
		const selectedRow =
			visibleRows.find((row) => row.UserId === selected) ?? rows.find((row) => row.UserId === selected);
		const inviteLive = invite !== undefined && invite.ExpiresAt > now;
		const outgoingLive = outgoing !== undefined && outgoing.ExpiresAt > now;
		const sessionLeft = session !== undefined ? math.max(0, session.ExpiresAt - now) : 0;
		const confirmLeft = session !== undefined && session.ConfirmEndsAt > 0 ? math.max(0, session.ConfirmEndsAt - now) : 0;
		const tableEmpty = session !== undefined && offerEmpty(draft) && offerEmpty(session.Them);
		const bothReady = youReadyLocal && session?.ThemReady === true;
		const lockBanner = !unlocked;
		const actionPad = phone ? 8 : 10;
		const actionH = TapTarget + actionPad * 2;
		const rosterRowH = compactTrade ? 64 : 66;
		const searchH = TapTarget;
		const relics: TradeRelic[] = [];
		for (const [uid, instance] of pairs(inventory)) {
			if (equippedUids[uid] !== undefined || instance.Locked === true) {
				continue;
			}
			relics.push({
				uid: uid,
				name: itemName(config, instance.DefinitionId),
				art: relicArt(config, instance.DefinitionId),
			});
			if (relics.size() >= 40) {
				break;
			}
		}
		const addRequested = (request: unknown) => {
			if (!typeIs(request, "table")) {
				return;
			}
			const req = request as TradeOffer;
			const offer = table.clone(draft);
			offer.Boosts = table.clone(draft.Boosts ?? {});
			offer.Keys = table.clone(draft.Keys ?? {});
			offer.ItemIds = table.clone(draft.ItemIds ?? []);
			const owned: Record<string, number> = {
				Cash: asFlux(state.Cash),
				Stardust: tonumber(state.Stardust) ?? 0,
				Cores: asFlux(state.Cores),
				Signals: state.Command !== undefined ? (tonumber(state.Command.Signals) ?? 0) : 0,
				Essence: state.Items !== undefined ? (tonumber(state.Items.Essence) ?? 0) : 0,
			};
			for (const [key, have] of pairs(owned)) {
				const want = tonumber(req[key]) ?? 0;
				if (want > 0) {
					offer[key] = math.max((offer[key] as number | undefined) ?? 0, math.min(want, cap(key, have)));
				}
			}
			const mine: Record<string, boolean> = {};
			for (const relic of relics) {
				mine[relic.uid] = true;
			}
			const already: Record<string, boolean> = {};
			for (const uid of offer.ItemIds) {
				already[uid] = true;
			}
			for (const uid of req.ItemIds ?? []) {
				if (mine[uid] && !already[uid]) {
					offer.ItemIds.push(uid);
				}
			}
			Audio.play("tick");
			queueOffer(offer);
		};
		const yourLines = offerLines(draft, config, inventory);
		const theirLines = session !== undefined ? offerLines(session.Them, config, inventory) : [];
		const raritiesOf = (offer: TradeOffer | undefined, fromInventory: boolean): string[] => {
			const list: string[] = [];
			const definitions = config.Items !== undefined && config.Items.Definitions !== undefined ? config.Items.Definitions : [];
			const rarityFor = (definitionId: string): string | undefined => {
				for (const definition of definitions) {
					if (definition.Id === definitionId) {
						return definition.Rarity;
					}
				}
				return undefined;
			};
			if (fromInventory) {
				for (const uid of offer?.ItemIds ?? []) {
					const instance = inventory[uid];
					const rarity = instance !== undefined ? rarityFor(instance.DefinitionId) : undefined;
					if (rarity !== undefined) {
						list.push(rarity);
					}
				}
			} else {
				for (const preview of offer?.Items ?? []) {
					const rarity = rarityFor(preview.DefinitionId);
					if (rarity !== undefined) {
						list.push(rarity);
					}
				}
			}
			return list;
		};
		const tradeWarnings =
			session !== undefined
				? TradeHistory.warnings(draft, session.Them, raritiesOf(draft, true), raritiesOf(session.Them, false))
				: [];
		// sprite-card well: cards wrap left to right and the frame grows with them
		const relicGrid = (cards: React.ReactElement[], order?: number) =>
			h(
				"frame",
				{
					LayoutOrder: order,
					Size: new UDim2(1, 0, 0, 0),
					AutomaticSize: Enum.AutomaticSize.Y,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: false,
				},
				h("uipadding", { PaddingTop: new UDim(0, 6), PaddingBottom: new UDim(0, 6) }),
				h("uigridlayout", {
					CellSize: UDim2.fromOffset(SPRITE_CARD_W, SPRITE_CARD_H),
					CellPadding: UDim2.fromOffset(SPRITE_CARD_GAP, SPRITE_CARD_GAP),
					SortOrder: Enum.SortOrder.LayoutOrder,
					FillDirectionMaxCells: 0,
				}),
				cards,
			);
		const dailyLimit = daily?.Limit ?? config.Trading?.DailyTrades;
		const dailyLabel =
			daily !== undefined && dailyLimit !== undefined
				? `${daily.Completed} / ${dailyLimit} trades today`
				: "Daily limits on every side";
		const onReadyClick = () => {
			if (offerPending || (tableEmpty && !youReadyLocal)) {
				return;
			}
			const following = !youReadyLocal;
			setYouReadyLocal(following);
			run("SetTradeReady", {
				Ready: following,
			});
		};
		const onConfirmClick = () => {
			return run("ConfirmTrade");
		};
		const onCancelClick = () => {
			return run("CancelTrade");
		};
		const readyDisabled = busy !== "" || offerPending || (tableEmpty && !youReadyLocal);
		const confirmDisabled = busy !== "" || offerPending || !bothReady;
		React.useEffect(() => {
			if (session === undefined) {
				GamepadNavigationService.EndOverlayFocus();
				return undefined;
			}
			GamepadNavigationService.BeginOverlayFocus();
			return () => {
				GamepadNavigationService.EndOverlayFocus();
			};
		}, [session !== undefined]);
		React.useEffect(() => {
			if (session === undefined || !UserInputService.GamepadEnabled) {
				return undefined;
			}
			const host = sessionActionsHostRef.current;
			if (host === undefined) {
				return undefined;
			}
			const selectJob = task.defer(() => {
				if (host.Parent === undefined) {
					return;
				}
				GamepadNavigationService.FocusClaim(host);
			});
			return () => {
				pcall(() => task.cancel(selectJob));
			};
		}, [session !== undefined, bothReady, youReadyLocal, tableEmpty, busy, readyDisabled, confirmDisabled]);
		// 08 .sc empty slot: dark well, faint rim, "+" over "Empty"
		const emptySlot = (index: number) =>
			h(
				"frame",
				{
					key: `empty${index}`,
					LayoutOrder: 1000 + index,
					BackgroundColor3: SLOT_WELL,
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(0, 11) }),
				h("uistroke", { Color: Palette.white, Thickness: 1, Transparency: 0.9, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					HorizontalAlignment: Enum.HorizontalAlignment.Center,
					VerticalAlignment: Enum.VerticalAlignment.Center,
					Padding: new UDim(0, 2),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				h(Text, {
					value: "+",
					size: 26,
					color: Palette.muted,
					weight: Enum.FontWeight.Bold,
					align: Enum.TextXAlignment.Center,
					layoutOrder: 0,
					sizeConstraint: new UDim2(1, 0, 0, 30),
				}),
				h(Text, {
					value: "Empty",
					size: 12,
					color: Palette.muted,
					align: Enum.TextXAlignment.Center,
					layoutOrder: 1,
					sizeConstraint: new UDim2(1, 0, 0, 16),
				}),
			);
		const minSlots = phone ? 2 : 3;
		const paneGridColumns = phone ? 1 : 2;
		const panePad = phone ? 10 : 18;
		const paneGap = phone ? 8 : 12;
		const paneHeadingH = panelHeadingH(phone);
		const paneChipH = phone ? 24 : 28;
		const paneRowH = phone ? 52 : 48;
		// a side's table: relic cards (yours lift out with a tap), then Flux and the other currencies as .rows
		const sideCards = (lines: OfferLine[], mine: boolean) => {
			const relicLines = lines.filter((line) => line.relic !== undefined);
			const cards: React.ReactElement[] = relicLines.map((line, index) =>
				h(SpriteCard, {
					key: line.key,
					name: line.label,
					rarity: line.relic!.rarity,
					color: rarityTint(line.relic!.rarity),
					element: line.relic!.element,
					iconKind: line.icon,
					reducedMotion: softMotion,
					layoutOrder: index,
					onSelect: mine
						? () => {
								Audio.play("tick");
								queueOffer({ ...draft, ItemIds: draft.ItemIds.filter((id) => id !== line.key) });
							}
						: undefined,
				}),
			);
			for (let index = relicLines.size(); index < minSlots; index++) {
				cards.push(emptySlot(index));
			}
			return cards;
		};
		const sideRows = (lines: OfferLine[]) => {
			const rest = lines.filter((line) => line.relic === undefined);
			if (rest.size() === 0) {
				rest.push({ key: "cash", label: "0 Flux", detail: "Currency", accent: Palette.cyan, icon: "Flux.15" });
			}
			return rest;
		};
		const offerPaneHeight = (lines: OfferLine[]): number => {
			const relicCount = lines.filter((line) => line.relic !== undefined).size();
			const rows = sideRows(lines).size();
			return (
				panePad * 2 +
				paneHeadingH +
				paneGap +
				relicGridHeight(math.max(minSlots, relicCount), paneGridColumns) +
				paneGap +
				rows * (paneRowH + paneGap) +
				paneChipH
			);
		};
		// 08 .pn "You give" / "You get": heading with the partner note, the card wrap, the rows, the state chip
		const offerPane = (
			title: string,
			note: string,
			stateText: string,
			stateAccent: Color3 | undefined,
			lines: OfferLine[],
			mine: boolean,
			order: number,
		) =>
			h(
				"frame",
				{
					Name: mine ? "TradeGive" : "TradeGet",
					Size: new UDim2(0, 0, 1, 0),
					BackgroundColor3: Palette.panel,
					BorderSizePixel: 0,
					ClipsDescendants: true,
					LayoutOrder: order,
				},
				h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
				// af.css .pn: panel fill, 16px radius, faint white rim
				h("uicorner", { CornerRadius: new UDim(0, phone ? 12 : 16) }),
				h("uistroke", { Color: Palette.white, Thickness: 1, Transparency: 0.9, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
				h("uipadding", {
					PaddingTop: new UDim(0, panePad),
					PaddingBottom: new UDim(0, panePad),
					PaddingLeft: new UDim(0, phone ? 12 : 20),
					PaddingRight: new UDim(0, phone ? 12 : 20),
				}),
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					SortOrder: Enum.SortOrder.LayoutOrder,
					Padding: new UDim(0, paneGap),
				}),
				h(PanelHeading, { icon: "Trade", title: title, note: note, accent: accent, phone: phone, layoutOrder: 0 }),
				relicGrid(sideCards(lines, mine), 1),
				sideRows(lines).map((line, index) => h(OfferRow, { key: line.key, line: line, touch: phone, layoutOrder: 10 + index })),
				h(Chip, {
					text: stateText,
					accent: stateAccent,
					icon: stateAccent !== undefined ? "Check" : undefined,
					phone: phone,
					layoutOrder: 100,
				}),
			);
		// what you put on the table: clear, currency steppers, the relic picker
		const stepperCount = 5 + BOOSTS.size() + KEYS.size();
		const stepperH = phone || viewport.width < 560 || viewport.height < 420 ? 108 : 52;
		const editorColumns = phone ? 2 : 3;
		const editorHeight =
			panePad * 2 +
			paneHeadingH +
			paneGap +
			(!offerEmpty(draft) ? (phone ? TapTarget : 34) + paneGap : 0) +
			stepperCount * (stepperH + paneGap) +
			20 +
			paneGap +
			(relics.size() > 0 ? relicGridHeight(relics.size(), editorColumns) : 120);
		const offerEditor = () => {
			const stepper = (order: number, props: Record<string, unknown>) =>
				h(QuantityStepper, { ...props, layoutOrder: order });
			const boostSteppers = BOOSTS.map((id, index) => {
				const perTradeBoostCap = daily?.PerTrade?.Boost ?? 3;
				const otherBoostsUsed = BOOSTS.reduce(
					(sum, other) => sum + (other === id ? 0 : (draft.Boosts[other] ?? 0)),
					0,
				);
				const remainingBudget = math.max(0, perTradeBoostCap - otherBoostsUsed);
				return h(QuantityStepper, {
					key: id,
					label: BOOST_LABELS[id] ?? id,
					value: draft.Boosts[id] ?? 0,
					max: math.min(remainingBudget, state.BoostInventory?.[id] ?? 0),
					accent: Palette.coral,
					reducedMotion: softMotion,
					layoutOrder: 20 + index,
					onChange: (value: number) => queueOffer({ ...draft, Boosts: { ...draft.Boosts, [id]: value } }),
				});
			});
			const keySteppers = KEYS.map((id, index) =>
				h(QuantityStepper, {
					key: id,
					label: KEY_LABELS[id] ?? id,
					value: draft.Keys[id] ?? 0,
					max: math.min(daily?.PerTrade?.Keys ?? 5, state.Items?.Keys?.[id] ?? 0),
					accent: Palette.mango,
					reducedMotion: softMotion,
					layoutOrder: 60 + index,
					onChange: (value: number) => queueOffer({ ...draft, Keys: { ...draft.Keys, [id]: value } }),
				}),
			);
			return h(
				"frame",
				{
					Name: "TradeOfferEditor",
					Size: new UDim2(1, 0, 0, 0),
					AutomaticSize: Enum.AutomaticSize.Y,
					BackgroundColor3: Palette.panel,
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(0, phone ? 12 : 16) }),
				h("uistroke", { Color: Palette.white, Thickness: 1, Transparency: 0.9, ApplyStrokeMode: Enum.ApplyStrokeMode.Border }),
				h("uipadding", {
					PaddingTop: new UDim(0, panePad),
					PaddingBottom: new UDim(0, panePad),
					PaddingLeft: new UDim(0, phone ? 12 : 20),
					PaddingRight: new UDim(0, phone ? 12 : 20),
				}),
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					SortOrder: Enum.SortOrder.LayoutOrder,
					Padding: new UDim(0, paneGap),
				}),
				h(PanelHeading, { icon: "Inventory.4", title: "Add to your offer", note: dailyLabel, accent: accent, phone: phone, layoutOrder: 0 }),
				!offerEmpty(draft)
					? h(
							"frame",
							{
								Size: new UDim2(1, 0, 0, phone ? TapTarget : 34),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 1,
							},
							h(Button, {
								text: "Clear offer",
								icon: "Refresh.1",
								onClick: () => queueOffer(emptyOffer()),
								color: SEC,
								textColor: Palette.creamSoft,
								size: UDim2.fromScale(1, 1),
								reducedMotion: softInvite,
							}),
						)
					: undefined,
				stepper(10, {
					label: "Flux",
					detail:
						cap("Cash", asFlux(state.Cash)) <= 0
							? "None tradable"
							: `${compactNumber(draft.Cash)} / ${compactNumber(cap("Cash", asFlux(state.Cash)))}`,
					value: draft.Cash,
					max: cap("Cash", asFlux(state.Cash)),
					accent: Palette.cyan,
					reducedMotion: softConfirm,
					onChange: (value: number) => queueOffer({ ...draft, Cash: value }),
				}),
				stepper(11, {
					label: "Stardust",
					value: draft.Stardust,
					max: cap("Stardust", tonumber(state.Stardust) ?? 0),
					accent: Palette.mango,
					reducedMotion: softMotion,
					onChange: (value: number) => queueOffer({ ...draft, Stardust: value }),
				}),
				stepper(12, {
					label: "Cores",
					value: draft.Cores,
					max: cap("Cores", tonumber(state.Cores) ?? 0),
					accent: Palette.violet,
					reducedMotion: softMotion,
					onChange: (value: number) => queueOffer({ ...draft, Cores: value }),
				}),
				stepper(13, {
					label: "Signals",
					value: draft.Signals,
					max: cap("Signals", tonumber(state.Command?.Signals) ?? 0),
					accent: Palette.cyan,
					reducedMotion: softMotion,
					onChange: (value: number) => queueOffer({ ...draft, Signals: value }),
				}),
				stepper(14, {
					label: "Essence",
					value: draft.Essence,
					max: cap("Essence", tonumber(state.Items?.Essence) ?? 0),
					accent: Palette.pink,
					reducedMotion: softMotion,
					onChange: (value: number) => queueOffer({ ...draft, Essence: value }),
				}),
				boostSteppers,
				keySteppers,
				h(Label, {
					text: "Relics",
					layoutOrder: 90,
				}),
				relics.size() === 0
					? h(EmptyState, {
							icon: "Artifact",
							title: "No tradeable relics",
							body: "Equipped and locked pieces stay home.",
							compact: true,
							layoutOrder: 91,
						})
					: relicGrid(
							relics.map((relic, index) => {
								const picked = draft.ItemIds.indexOf(relic.uid) >= 0;
								const onToggle = () => {
									const pickedIds: string[] = [];
									if (picked) {
										for (const id of draft.ItemIds) {
											if (id !== relic.uid) {
												pickedIds.push(id);
											}
										}
									} else {
										const itemCap = daily?.PerTrade?.Items ?? 6;
										if (draft.ItemIds.size() < itemCap) {
											for (const id of draft.ItemIds) {
												pickedIds.push(id);
											}
											pickedIds.push(relic.uid);
										} else {
											return;
										}
									}
									Audio.play("tick");
									queueOffer({ ...draft, ItemIds: pickedIds });
								};
								return h(SpriteCard, {
									key: relic.uid,
									name: relic.name,
									rarity: relic.art.rarity,
									color: rarityTint(relic.art.rarity),
									element: relic.art.element,
									iconKind: "Inventory.4",
									selected: picked,
									tag: picked ? "In" : undefined,
									tagColor: Palette.brass,
									reducedMotion: softMotion,
									layoutOrder: index,
									onSelect: onToggle,
								});
							}),
							91,
						),
			);
		};
		const balance = session !== undefined ? tradeBalance(draft, session.Them) : { text: "" };
		// 08 bottom .pn: [value check chip] [spacer] [Cancel] [Ready] [Confirm]; phones drop the chip
		// (it rides in the status block) and split the three buttons evenly
		const buildConfirmActions = () => {
			if (session === undefined) {
				return undefined;
			}
			const slot = (name: string, order: number, width: number, button: React.ReactElement) =>
				h(
					"frame",
					{
						Name: name,
						Size: new UDim2(0, phone ? 0 : width, 0, TapTarget),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						LayoutOrder: order,
					},
					phone ? h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }) : undefined,
					button,
				);
			const waitingOnThem = youReadyLocal && session.ThemReady !== true;
			return h(
				"frame",
				{
					ref: sessionActionsHostRef,
					Name: "TradeSessionActions",
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: false,
				},
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Horizontal,
					SortOrder: Enum.SortOrder.LayoutOrder,
					Padding: new UDim(0, 8),
					VerticalAlignment: Enum.VerticalAlignment.Center,
				}),
				!phone ? h(Chip, { text: balance.text, accent: balance.accent, layoutOrder: 0 }) : undefined,
				!phone
					? h(
							"frame",
							{ Size: new UDim2(0, 0, 0, TapTarget), BackgroundTransparency: 1, BorderSizePixel: 0, LayoutOrder: 1 },
							h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
						)
					: undefined,
				slot(
					"TradeCancel",
					2,
					120,
					h(Button, {
						text: "Cancel",
						onClick: onCancelClick,
						color: SEC,
						textColor: Palette.cream,
						size: UDim2.fromScale(1, 1),
						disabled: busy !== "",
						loading: busy === "CancelTrade",
						shakeToken: shakeFor("CancelTrade"),
						reducedMotion: reducedMotion,
						selectable: busy === "",
					}),
				),
				slot(
					"TradeReady",
					3,
					180,
					h(Button, {
						text: offerPending
							? "Sending…"
							: youReadyLocal
								? "Unready"
								: tableEmpty
									? "Add something first"
									: "Ready",
						onClick: onReadyClick,
						color: youReadyLocal ? SEC : accent,
						textColor: youReadyLocal ? Palette.cream : Palette.ink,
						size: UDim2.fromScale(1, 1),
						disabled: readyDisabled,
						loading: busy === "SetTradeReady",
						shakeToken: shakeFor("SetTradeReady"),
						reducedMotion: softMotion,
						highlight: !youReadyLocal && !tableEmpty,
						selectable: !readyDisabled,
					}),
				),
				slot(
					"TradeConfirm",
					4,
					260,
					h(Button, {
						text: session.YouConfirmed
							? "Confirmed"
							: confirmLeft > 0
								? `Confirm  ${clockLabel(session.ConfirmEndsAt, now)}`
								: waitingOnThem && !phone
									? `Confirm · waiting for ${session.PartnerName}`
									: "Confirm",
						icon: confirmDisabled && !session.YouConfirmed ? "Lock.1" : undefined,
						onClick: onConfirmClick,
						color: Palette.mango,
						textColor: Palette.ink,
						size: UDim2.fromScale(1, 1),
						disabled: confirmDisabled,
						loading: busy === "ConfirmTrade",
						shakeToken: shakeFor("ConfirmTrade"),
						reducedMotion: reducedMotion,
						highlight: bothReady && !session.YouConfirmed,
						selectable: !confirmDisabled,
					}),
				),
			);
		};
		// a two-line text column that takes the rest of a row
		const textColumn = (order: number, height: number, children: unknown[]) =>
			h(
				"frame",
				{
					Size: new UDim2(0, 0, 0, height),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: order,
				},
				h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					VerticalAlignment: Enum.VerticalAlignment.Center,
					Padding: new UDim(0, 2),
					SortOrder: Enum.SortOrder.LayoutOrder,
				}),
				...(children as React.ReactElement[]),
			);
		const rowList = (gap: number) =>
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Horizontal,
				VerticalAlignment: Enum.VerticalAlignment.Center,
				Padding: new UDim(0, gap),
				SortOrder: Enum.SortOrder.LayoutOrder,
			});
		const stackList = (gap: number) =>
			h("uilistlayout", {
				FillDirection: Enum.FillDirection.Vertical,
				Padding: new UDim(0, gap),
				SortOrder: Enum.SortOrder.LayoutOrder,
			});
		const fixedBox = (order: number, size: UDim2, child: unknown, name?: string) =>
			h(
				"frame",
				{
					Name: name,
					Size: size,
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: order,
				},
				child,
			);
		const rosterCards = visibleRows.map((row, index) => {
			const active = row.UserId === selected;
			const waiting = outgoingLive && outgoing?.ToUserId === row.UserId;
			return h(
				PnSurface,
				{
					key: row.UserId,
					size: new UDim2(1, 0, 0, rosterRowH),
					accent: active ? accent : Palette.line,
					background: active ? darken(accent, 0.82) : Palette.panel,
					padding: 10,
					interactive: true,
					reveal: reducedMotion === true ? deskReveal : boardReveal,
					reducedMotion: reducedMotion === true || tradeSoft,
					layoutOrder: 6 + index,
				},
				// whole-card hit area under the row content
				h("textbutton", {
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					Text: "",
					AutoButtonColor: false,
					Active: true,
					Selectable: false,
					Event: {
						Activated: () => {
							Audio.play("tick");
							setSelected(row.UserId);
						},
						MouseEnter: () => {
							return Audio.play("hover");
						},
					},
				}),
				h(
					"frame",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
					},
					rowList(12),
					h(AvatarMark, {
						userId: row.UserId,
						accent: active ? accent : Palette.cyan,
						size: 44,
						layoutOrder: 0,
					}),
					textColumn(1, 44, [
						h(Text, {
							value: row.DisplayName,
							size: 16,
							color: Palette.cream,
							weight: Enum.FontWeight.Heavy,
							fit: true,
							layoutOrder: 0,
							sizeConstraint: new UDim2(1, 0, 0, 22),
						}),
						h(Text, {
							value: `${row.Rebirths} rebirths · world ${row.CurrentZone}`,
							size: 12,
							color: Palette.creamSoft,
							fit: true,
							layoutOrder: 1,
							sizeConstraint: new UDim2(1, 0, 0, 18),
						}),
					]),
					!compactTrade
						? fixedBox(
								2,
								UDim2.fromOffset(110, 40),
								h(Button, {
									text: waiting ? "WAITING" : "INVITE",
									onClick: () => {
										setSelected(row.UserId);
										if (!waiting) {
											run("InviteTrade", {
												UserId: row.UserId,
											});
										}
									},
									color: waiting ? Palette.panelSoft : accent,
									textColor: waiting ? Palette.cream : Palette.ink,
									size: UDim2.fromScale(1, 1),
									disabled: busy !== "" || waiting || !unlocked,
									loading: busy === "InviteTrade",
									shakeToken: shakeFor("InviteTrade"),
									reducedMotion: reducedMotion,
									highlight: !waiting,
								}),
							)
						: waiting
							? fixedBox(
									2,
									UDim2.fromOffset(80, 24),
									h(Badge, {
										value: "WAITING",
										accent: Palette.mango,
										filled: true,
										size: UDim2.fromScale(1, 1),
									}),
								)
							: undefined,
				),
			);
		});
		// 08-trading hero: market header art behind a serif title, eyebrow names the partner when a table is open;
		// the Trade / Requests / History tabs sit at the right (phones get them as their own row)
		const heroH = compactTrade ? 72 : 104;
		const deskTabs = h(MockTabs, {
			options: [
				{ id: "Trade", label: "Trade" },
				{ id: "Requests", label: "Requests" },
				{ id: "History", label: "History" },
			],
			value: deskTab,
			onChange: setDeskTab,
			accent: accent,
			phone: phone,
			reducedMotion: reducedMotion,
			fill: phone,
			layoutOrder: 1,
		});
		const tradeHero = (eyebrow: string, subline: string) =>
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundColor3: Palette.panel,
					BorderSizePixel: 0,
					ClipsDescendants: true,
				},
				h("uicorner", { CornerRadius: new UDim(0, 18) }),
				h(Stroke, { color: Palette.line, thickness: 1, transparency: 0.2 }),
				h(
					"imagelabel",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						Image: HEADER_ART.market,
						ScaleType: Enum.ScaleType.Crop,
						ImageTransparency: fade.map((amount) => 0.15 + amount * 0.85),
					},
					h("uicorner", { CornerRadius: new UDim(0, 18) }),
					// fade the art out under the title so the text always reads
					h("uigradient", {
						Transparency: new NumberSequence([
							new NumberSequenceKeypoint(0, 0.9),
							new NumberSequenceKeypoint(0.45, 0.55),
							new NumberSequenceKeypoint(1, 0),
						]),
					}),
				),
				// brass inner rule, 3px in from the edge
				h(
					"frame",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
					},
					h("uipadding", {
						PaddingTop: new UDim(0, 3),
						PaddingBottom: new UDim(0, 3),
						PaddingLeft: new UDim(0, 3),
						PaddingRight: new UDim(0, 3),
					}),
					h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
						},
						h("uicorner", { CornerRadius: new UDim(0, 15) }),
						h("uistroke", { Color: Palette.brass, Thickness: 1, Transparency: 0.75 }),
					),
				),
				h(
					"frame",
					{
						Size: UDim2.fromScale(1, 1),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
					},
					h("uipadding", { PaddingLeft: new UDim(0, 18), PaddingRight: new UDim(0, 18) }),
					rowList(12),
					h(
						"frame",
						{
							Size: new UDim2(0, 0, 1, 0),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							LayoutOrder: 0,
						},
						h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
						h("uilistlayout", {
							FillDirection: Enum.FillDirection.Vertical,
							VerticalAlignment: Enum.VerticalAlignment.Center,
							SortOrder: Enum.SortOrder.LayoutOrder,
							Padding: new UDim(0, compactTrade ? 1 : 3),
						}),
						h("textlabel", {
							Text: eyebrow.upper(),
							FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Bold),
							TextColor3: Palette.brass,
							TextSize: 11,
							TextTransparency: fade,
							TextTruncate: Enum.TextTruncate.AtEnd,
							TextXAlignment: Enum.TextXAlignment.Left,
							BackgroundTransparency: 1,
							Size: new UDim2(1, 0, 0, 14),
							LayoutOrder: 1,
						}),
						h("textlabel", {
							Text: "Trading",
							FontFace: TRADE_SERIF,
							TextColor3: Palette.cream,
							TextSize: compactTrade ? 24 : 32,
							TextTransparency: fade,
							TextXAlignment: Enum.TextXAlignment.Left,
							BackgroundTransparency: 1,
							Size: new UDim2(1, 0, 0, compactTrade ? 28 : 38),
							LayoutOrder: 2,
						}),
						!compactTrade
							? h("textlabel", {
									Text: subline,
									FontFace: Font.fromName("BuilderSans", Enum.FontWeight.Medium),
									TextColor3: Palette.creamSoft,
									TextSize: 13,
									TextTransparency: fade,
									TextTruncate: Enum.TextTruncate.AtEnd,
									TextXAlignment: Enum.TextXAlignment.Left,
									BackgroundTransparency: 1,
									Size: new UDim2(1, 0, 0, 16),
									LayoutOrder: 3,
								})
							: undefined,
					),
					!phone ? deskTabs : undefined,
				),
			);
		const heroSections = (eyebrow: string, subline: string) => {
			const list: { id: string; height: number; element: unknown; fill?: boolean; minHeight?: number }[] = [
				{ id: "hero", height: heroH, element: tradeHero(eyebrow, subline) },
			];
			if (phone) {
				list.push({ id: "desk-tabs", height: TapTarget + 8, element: deskTabs });
			}
			return list;
		};
		// completed trades, newest first: who, when, what changed hands
		const history = (trade !== undefined && typeIs(trade.History, "table") ? trade.History : []) as HistoryEntry[];
		const historySections = () => {
			const list: { id: string; height: number; element: unknown; fill?: boolean; minHeight?: number }[] = [
				{
					id: "history-heading",
					height: 30,
					element: h(Text, {
						value:
							history.size() > 0 ? "Recent trades" : "Recent trades: none yet. Finished trades show up here.",
						size: 15,
						color: Palette.cream,
						weight: Enum.FontWeight.Heavy,
						wrap: true,
						fit: true,
						minSize: 10,
						sizeConstraint: new UDim2(1, 0, 0, 28),
					}),
				},
			];
			for (const [index, entry] of ipairs(history)) {
				const ago = math.max(0, os.time() - entry.At);
				const when =
					ago < 3600
						? `${math.max(1, math.floor(ago / 60))}m ago`
						: ago < 86400
							? `${math.floor(ago / 3600)}h ago`
							: `${math.floor(ago / 86400)}d ago`;
				const again = Players.GetPlayerByUserId(entry.PartnerId) !== undefined;
				const bodyH = phone ? 56 : 40;
				list.push({
					id: `history-${index}`,
					height: phone ? 104 : 84,
					element: h(
						PnSurface,
						{
							size: UDim2.fromScale(1, 1),
							accent: accent,
							background: Palette.panel,
							padding: 16,
							clips: false,
						},
						rowList(10),
						textColumn(0, 24 + bodyH, [
							h(Text, {
								value: `With ${entry.Partner}  ·  ${when}`,
								size: 14,
								color: Palette.cream,
								weight: Enum.FontWeight.Bold,
								layoutOrder: 0,
								sizeConstraint: new UDim2(1, 0, 0, 20),
							}),
							h(Text, {
								value: `− ${entry.Gave}\n+ ${entry.Got}`,
								size: 13,
								color: Palette.muted,
								wrap: true,
								fit: true,
								minSize: 10,
								layoutOrder: 1,
								sizeConstraint: new UDim2(1, 0, 0, bodyH),
							}),
						]),
						again
							? fixedBox(
									1,
									UDim2.fromOffset(140, TapTarget),
									h(Button, {
										// the same partner is still here: one tap opens a fresh trade with them
										text: "Trade again",
										icon: "Send.3",
										color: accent,
										textColor: Palette.ink,
										size: UDim2.fromScale(1, 1),
										reducedMotion: reducedMotion,
										onClick: () => dispatch("InviteTrade", { UserId: entry.PartnerId }),
									}),
								)
							: undefined,
					),
				});
			}
			return list;
		};
		if (session !== undefined) {
			const pinnedActions = buildConfirmActions();
			const giveLines = yourLines;
			const offersH = math.max(offerPaneHeight(giveLines), offerPaneHeight(theirLines));
			const youState = session.YouConfirmed ? "Confirmed" : youReadyLocal ? "Ready" : "Not ready";
			const youAccent = session.YouConfirmed ? Palette.mango : youReadyLocal ? Palette.mint : undefined;
			const themState =
				session.ThemConfirmed === true ? "Confirmed" : session.ThemReady === true ? "Ready" : "Still choosing";
			const themAccent =
				session.ThemConfirmed === true ? Palette.mango : session.ThemReady === true ? Palette.mint : undefined;
			const sections = heroSections(`Trade with ${session.PartnerName}`, "Both sides lock in before anything moves.");
			if (deskTab === "Trade") {
				sections.push({
					id: "status",
					height: (chrome.landscape ? 52 : 60) + (tradeWarnings.size() > 0 ? 40 : 0) + (phone ? 18 : 0),
					element: h(
						"frame",
						{
							Size: UDim2.fromScale(1, 1),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
						},
						stackList(2),
						h(Text, {
							value: bothReady
								? "Both ready. Confirm to finish the trade."
								: youReadyLocal
									? `Waiting on ${session.PartnerName}.`
									: "Add your offer, then select Ready.",
							size: 13,
							color: bothReady ? Palette.mango : Palette.creamSoft,
							wrap: true,
							fit: true,
							minSize: 10,
							layoutOrder: 0,
							sizeConstraint: new UDim2(1, 0, 0, 32),
						}),
						h(
							"frame",
							{
								Size: new UDim2(1, 0, 0, 18),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 1,
							},
							rowList(10),
							h(Text, {
								value: sessionLeft > 0 ? `Table ${clockLabel(session.ExpiresAt, now)}` : "Table expired",
								size: 11,
								color: sessionLeft > 12 ? Palette.mint : Palette.coral,
								weight: Enum.FontWeight.Bold,
								fit: true,
								layoutOrder: 0,
								sizeConstraint: new UDim2(0, 110, 0, 18),
							}),
						),
						// phones: the value check gets its own full-width line (desktop shows it as the action-bar chip)
						phone
							? h(Text, {
									value: balance.text,
									size: 12,
									fit: true,
									minSize: 10,
									color: balance.accent ?? Palette.creamSoft,
									weight: Enum.FontWeight.Bold,
									layoutOrder: 2,
									sizeConstraint: new UDim2(1, 0, 0, 16),
								})
							: undefined,
						tradeWarnings.size() > 0
							? h(Text, {
									// one-sided offers are allowed (gifts), but never by accident
									value: tradeWarnings[0],
									size: 13,
									color: Palette.coral,
									weight: Enum.FontWeight.Bold,
									wrap: true,
									fit: true,
									minSize: 10,
									layoutOrder: 3,
									sizeConstraint: new UDim2(1, 0, 0, 36),
								})
							: undefined,
					),
				});
				// 08 .flexr: [You give] [⇄ 70px] [You get]
				sections.push({
					id: "offer",
					height: offersH,
					element: h(
						"frame",
						{
							Name: "TradeOffers",
							Size: UDim2.fromScale(1, 1),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
						},
						h("uilistlayout", {
							FillDirection: Enum.FillDirection.Horizontal,
							Padding: new UDim(0, phone ? 8 : 18),
							SortOrder: Enum.SortOrder.LayoutOrder,
						}),
						offerPane("You give", session.PartnerName, youState, youAccent, giveLines, true, 0),
						!phone
							? h(
									"frame",
									{
										Name: "TradeSwap",
										Size: new UDim2(0, 70, 1, 0),
										BackgroundTransparency: 1,
										BorderSizePixel: 0,
										LayoutOrder: 1,
									},
									h("uilistlayout", {
										FillDirection: Enum.FillDirection.Vertical,
										HorizontalAlignment: Enum.HorizontalAlignment.Center,
										VerticalAlignment: Enum.VerticalAlignment.Center,
										SortOrder: Enum.SortOrder.LayoutOrder,
									}),
									h(GlyphWell, { kind: "Trade", accent: accent, size: 48, glow: true, layoutOrder: 0 }),
								)
							: undefined,
						offerPane("You get", session.PartnerName, themState, themAccent, theirLines, false, 2),
					),
				});
				sections.push({
					id: "offer-editor",
					height: editorHeight,
					element: offerEditor(),
				});
			} else if (deskTab === "Requests") {
				sections.push({
					id: "asks",
					height: tradeAsksHeight(session),
					element: h(TradeAsks, {
						session: session,
						dispatch: dispatch,
						myRelics: relics,
						onAddRequested: addRequested,
					}),
				});
				sections.push({
					id: "chat",
					height: compactTrade ? 260 : 300,
					element: h(TradeChatStream, {
						session: session,
						dispatch: dispatch,
					}),
				});
			} else {
				for (const section of historySections()) {
					sections.push(section);
				}
			}
			return h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: false,
				},
				stackList(8),
				h(
					"frame",
					{
						Name: "TradeDeskScroll",
						Size: new UDim2(1, 0, 0, 0),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClipsDescendants: true,
						LayoutOrder: 0,
					},
					h("uiflexitem", { FlexMode: Enum.UIFlexMode.Fill }),
					h(PageScaffold, {
						scrollBarColor: accent,
						scrollBarThickness: 4,
						tailPad: scrollTail(true, chrome.bottomSafe, chrome.landscape ? 16 : 20),
						gap: chrome.landscape ? 8 : Layout.stackGap,
						sections: sections,
					}),
				),
				h(
					"frame",
					{
						Name: "TradeActionBar",
						Size: new UDim2(1, 0, 0, actionH),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 6,
						LayoutOrder: 1,
					},
					h(
						PnSurface,
						{
							size: UDim2.fromScale(1, 1),
							padding: actionPad,
							phone: phone,
							reducedMotion: reducedMotion,
						},
						pinnedActions,
					),
				),
			);
		}
		const dailyElement = h(Text, {
			value: dailyLabel,
			size: 14,
			color: Palette.mint,
			weight: Enum.FontWeight.Bold,
			layoutOrder: 0,
			sizeConstraint: new UDim2(1, 0, 0, 22),
			transparency: fade,
		});
		const lockElement =
			lockBanner && session === undefined
				? h(
						PnSurface,
						{
							size: new UDim2(1, 0, 0, 86),
							accent: Palette.muted,
							padding: compactTrade ? 12 : Layout.cardPadding + 4,
							reducedMotion: reducedMotion,
							layoutOrder: 1,
						},
						stackList(4),
						h(Text, {
							value: regionBlocked ? PlayPolicy.Copy.TradingShort : "Player trading is locked",
							size: 15,
							color: Palette.cream,
							weight: Enum.FontWeight.Heavy,
							layoutOrder: 0,
							sizeConstraint: new UDim2(1, 0, 0, 22),
						}),
						h(Text, {
							value: regionBlocked ? PlayPolicy.Copy.Trading : (lock?.Requirement ?? "Complete your first rebirth."),
							size: 13,
							color: Palette.creamSoft,
							wrap: true,
							fit: true,
							minSize: 10,
							layoutOrder: 1,
							sizeConstraint: new UDim2(1, 0, 0, 48),
						}),
					)
				: undefined;
		const inviteElement =
			inviteLive && session === undefined
				? h(
						PnSurface,
						{
							size: new UDim2(1, 0, 0, 128),
							accent: Palette.cyan,
							padding: compactTrade ? 12 : Layout.cardPadding + 4,
							reducedMotion: reducedMotion,
							layoutOrder: 2,
						},
						stackList(8),
						h(
							"frame",
							{
								Size: new UDim2(1, 0, 0, 44),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 0,
							},
							rowList(12),
							h(AvatarMark, {
								userId: invite.FromUserId,
								accent: Palette.cyan,
								size: 44,
								layoutOrder: 0,
							}),
							textColumn(1, 44, [
								h(Text, {
									value: `${invite.FromName ?? "Someone"} invited you`,
									size: 16,
									color: Palette.cream,
									weight: Enum.FontWeight.Heavy,
									fit: true,
									layoutOrder: 0,
									sizeConstraint: new UDim2(1, 0, 0, 22),
								}),
								h(Text, {
									value: clockLabel(invite.ExpiresAt, now),
									size: 13,
									color: Palette.creamSoft,
									fit: true,
									layoutOrder: 1,
									sizeConstraint: new UDim2(1, 0, 0, 20),
								}),
							]),
						),
						h(
							"frame",
							{
								Size: new UDim2(1, 0, 0, TapTarget),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 1,
							},
							h("uilistlayout", {
								FillDirection: Enum.FillDirection.Horizontal,
								HorizontalFlex: Enum.UIFlexAlignment.Fill,
								Padding: new UDim(0, 8),
								SortOrder: Enum.SortOrder.LayoutOrder,
							}),
							fixedBox(
								0,
								new UDim2(0, 0, 1, 0),
								h(Button, {
									text: "Accept",
									onClick: () => {
										return run("RespondTrade", {
											Accept: true,
										});
									},
									color: Palette.mint,
									textColor: Palette.ink,
									size: UDim2.fromScale(1, 1),
									disabled: busy !== "",
									loading: busy === "RespondTrade",
									shakeToken: shakeFor("RespondTrade"),
									reducedMotion: reducedMotion,
									highlight: true,
								}),
							),
							fixedBox(
								1,
								new UDim2(0, 0, 1, 0),
								h(Button, {
									text: "Decline",
									onClick: () => {
										return run("RespondTrade", {
											Accept: false,
										});
									},
									color: SEC,
									textColor: Palette.cream,
									size: UDim2.fromScale(1, 1),
									disabled: busy !== "",
									loading: busy === "RespondTrade",
									shakeToken: shakeFor("RespondTrade"),
									reducedMotion: reducedMotion,
								}),
							),
						),
					)
				: undefined;
		const outgoingElement =
			outgoingLive && session === undefined && !inviteLive
				? h(
						PnSurface,
						{
							size: new UDim2(1, 0, 0, 124),
							accent: Palette.mango,
							padding: compactTrade ? 12 : Layout.cardPadding + 4,
							reducedMotion: reducedMotion,
							layoutOrder: 3,
						},
						stackList(8),
						h(
							"frame",
							{
								Size: new UDim2(1, 0, 0, 44),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: 0,
							},
							rowList(10),
							fixedBox(
								0,
								UDim2.fromOffset(22, 22),
								h(Icon, {
									kind: "Timer.4",
									color: Palette.mango,
									accent: Palette.mango,
									size: 22,
									clipSafe: true,
									spin: false,
								}),
							),
							textColumn(1, 44, [
								h(Text, {
									value: `Waiting on ${outgoing.ToName ?? "partner"}`,
									size: 15,
									color: Palette.cream,
									weight: Enum.FontWeight.Heavy,
									fit: true,
									layoutOrder: 0,
									sizeConstraint: new UDim2(1, 0, 0, 22),
								}),
								h(Text, {
									value: clockLabel(outgoing.ExpiresAt, now),
									size: 13,
									color: Palette.mango,
									weight: Enum.FontWeight.Bold,
									fit: true,
									layoutOrder: 1,
									sizeConstraint: new UDim2(1, 0, 0, 18),
								}),
							]),
						),
						fixedBox(
							1,
							new UDim2(1, 0, 0, TapTarget),
							h(Button, {
								text: "Cancel",
								onClick: () => {
									return run("CancelTrade");
								},
								color: Palette.coral,
								textColor: Palette.ink,
								size: UDim2.fromScale(1, 1),
								disabled: busy !== "",
								loading: busy === "CancelTrade",
								shakeToken: shakeFor("CancelTrade"),
								reducedMotion: reducedMotion,
							}),
						),
					)
				: undefined;
		const searchElement =
			session === undefined
				? h(
						"frame",
						{
							Size: new UDim2(1, 0, 0, searchH),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							LayoutOrder: 4,
						},
						rowList(8),
						h(SearchField, {
							value: query,
							onChange: setQuery,
							accent: accent,
							placeholder: "Find a forgemaster",
							size: new UDim2(1, -(searchH + 8), 0, searchH),
							reducedMotion: reducedMotion,
							layoutOrder: 0,
						}),
						fixedBox(
							1,
							UDim2.fromOffset(searchH, searchH),
							h(Button, {
								text: "",
								icon: "Refresh.2",
								onClick: () => {
									return loadRoster();
								},
								color: Palette.panelSoft,
								textColor: Palette.cream,
								size: UDim2.fromScale(1, 1),
								reducedMotion: reducedMotion,
							}),
						),
					)
				: undefined;
		const emptyElement =
			session === undefined && visibleRows.size() === 0
				? h(EmptyState, {
						icon: "Crew.4",
						title: rows.size() === 0 ? "Server is quiet" : "No match",
						body:
							rows.size() === 0
								? (config.ClientPageGuides?.Trade?.EmptySession ??
									"Nobody else is in this server. Invites only work here.")
								: "Try a different name.",
						accent: accent,
						compact: true,
						layoutOrder: 5,
						reducedMotion: reducedMotion,
					})
				: undefined;
		const ctaElement =
			session === undefined
				? h(
						"frame",
						{
							Size: new UDim2(1, 0, 0, TapTarget),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							LayoutOrder: 7,
						},
						h(Button, {
							text:
								selectedRow !== undefined
									? `INVITE  ${selectedRow.DisplayName.upper()}`
									: "CHOOSE SOMEONE",
							icon: "Send.2",
							onClick: () => {
								if (selected !== 0) {
									run("InviteTrade", {
										UserId: selected,
									});
								}
							},
							color: accent,
							textColor: Palette.ink,
							size: new UDim2(1, 0, 0, TapTarget),
							disabled:
								selected === 0 ||
								busy !== "" ||
								(outgoingLive && outgoing?.ToUserId === selected) ||
								!unlocked,
							reducedMotion: reducedMotion,
							highlight: true,
						}),
					)
				: undefined;
		const rosterStride = rosterRowH + (chrome.landscape ? 8 : Layout.stackGap);
		const rosterFloor = visibleRows.size() === 0 ? 140 : visibleRows.size() * rosterStride;
		const sections = heroSections("Social", "Both sides lock in before anything moves.");
		const pushRequests = () => {
			if (inviteElement !== undefined) {
				sections.push({
					id: "invite",
					height: 128,
					element: inviteElement,
				});
			}
			if (outgoingElement !== undefined) {
				sections.push({
					id: "outgoing",
					height: 124,
					element: outgoingElement,
				});
			}
		};
		if (deskTab === "Trade") {
			sections.push({
				id: "daily",
				height: 22,
				element: dailyElement,
			});
			if (lockElement !== undefined) {
				sections.push({
					id: "lock",
					height: 86,
					element: lockElement,
				});
			}
			pushRequests();
			if (searchElement !== undefined) {
				sections.push({
					id: "search",
					height: searchH,
					element: searchElement,
				});
			}
			const rosterElement =
				emptyElement !== undefined
					? emptyElement
					: h(
								"frame",
								{
									Size: UDim2.fromScale(1, 1),
									BackgroundTransparency: 1,
									BorderSizePixel: 0,
								},
								h("uilistlayout", {
									FillDirection: Enum.FillDirection.Vertical,
									SortOrder: Enum.SortOrder.LayoutOrder,
									Padding: new UDim(0, chrome.landscape ? 8 : Layout.stackGap),
								}),
								rosterCards,
							);
			// a plain list (a server holds a few dozen at most): no virtualised scroller inside the page scroller
			sections.push({
				id: "roster",
				minHeight: rosterFloor,
				height: rosterFloor,
				element: rosterElement,
			});
			if (ctaElement !== undefined) {
				sections.push({
					id: "invite-cta",
					height: TapTarget,
					element: ctaElement,
				});
			}
		} else if (deskTab === "Requests") {
			pushRequests();
			if (inviteElement === undefined && outgoingElement === undefined) {
				sections.push({
					id: "requests-empty",
					height: 140,
					element: h(EmptyState, {
						icon: "Send.2",
						title: "No open requests",
						body: "Invites you send or receive show up here until they're answered.",
						accent: accent,
						compact: true,
						reducedMotion: reducedMotion,
					}),
				});
			}
		} else {
			for (const section of historySections()) {
				sections.push(section);
			}
		}
		return h(
			"frame",
			{
				Name: "TradeLobbyHost",
				ref: lobbyHostRef,
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: false,
			},
			h(PageScaffold, {
				scrollBarColor: accent,
				scrollBarThickness: 4,
				tailPad: scrollTail(true, chrome.bottomSafe, chrome.landscape ? 24 : 32),
				gap: chrome.landscape ? 8 : Layout.stackGap,
				sections: sections,
			}),
		);
	}
	return {
		TradeView: TradeView,
	};
};

function loadPort(name: string): unknown {
	return require(script.Parent!.WaitForChild("views")!.WaitForChild(name) as ModuleScript);
}

__defs["CrewView"] = () => loadPort("CrewView");
__defs["GuildView"] = () => loadPort("GuildView");
__defs["MailboxView"] = () => loadPort("MailboxView");
__defs["ChatView"] = () => loadPort("ChatView");

const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type PagesSocialCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const PagesSocial = setmetatable(
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
) as unknown as PagesSocialCallable;

export = PagesSocial;
