// PagesSocial.luau — compiled page bundle for the Social tab.
// Members are required lazily: PagesSocial("TradeView") only pays for that page's code.
import { BRASS, IRON_RADIUS, ironFace } from "../UiCore/castIron";
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { unixNow } from "../CoreKit/deadlines";
import { asFlux, compactNumber } from "../CoreKit/format";
import { chromeFor, darken, Layout, Palette, scrollTail, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { useEntrance, useStagger, useViewport } from "../MotionKit/motion";
import { Icon } from "../ArtKit/Icon";
import { SplitColumns, splitColumns, StackBlocks, stackHeight, useTouchTargets } from "../UiCore/ui";
import { useFocusOrder } from "../CoreKit/focusOrder";
import TradeHistory = require("../../../Shared/AstralForge/Shared/TradeHistory");
import { Dict } from "../lua";
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";
import { usePlayPolicy } from "../CoreKit/playPolicy";
import { Component, loadAudio, loadBrowse, loadPageScaffold, loadUi, luauKit } from "./luauDeps";

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

__defs["TradeView"] = () => {
	const Audio = loadAudio();
	const PageScaffold = loadPageScaffold();
	const { FlatList } = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList");
	const {
		Badge,
		Button,
		EmptyState,
		IconTile,
		Panel,
		QuantityStepper,
		SearchField,
		SectionLabel,
		SegmentedTabs,
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
		position?: UDim2;
	}

	function AvatarMark(_param: AvatarMarkProps) {
		const userId = _param.userId;
		const accent = _param.accent;
		const size = _param.size;
		const position = _param.position;
		return h(
			"frame",
			{
				Size: UDim2.fromOffset(size, size),
				Position: position,
				BackgroundColor3: darken(accent, 0.62),
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h(Stroke, {
				color: accent,
				thickness: 1,
				transparency: 0.28,
			}),
			h(
				"imagelabel",
				{
					Size: new UDim2(1, -4, 1, -4),
					Position: UDim2.fromOffset(2, 2),
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
	}

	function OfferRow(_param: OfferRowProps) {
		const line = _param.line;
		const touch = _param.touch ?? false;
		const rowH = touch ? 56 : 50;
		const tile = touch ? 40 : 36;
		const textX = tile + 16;
		return h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, rowH),
				BackgroundColor3: Palette.ink,
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
			h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
			h(Stroke, {
				color: line.accent,
				thickness: 1,
				transparency: 0.5,
			}),
			h(IconTile, {
				kind: line.icon,
				accent: line.accent,
				size: tile,
				radius: 10,
				position: UDim2.fromOffset(8, math.floor((rowH - tile) / 2)),
				spin: false,
				reducedMotion: true,
			}),
			h(Text, {
				value: line.label,
				size: 15,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				position: UDim2.fromOffset(textX, touch ? 6 : 5),
				sizeConstraint: new UDim2(1, -(textX + 12), 0, 22),
			}),
			h(Text, {
				value: line.detail,
				size: 12,
				color: line.accent,
				weight: Enum.FontWeight.Bold,
				fit: true,
				position: UDim2.fromOffset(textX, touch ? 30 : 28),
				sizeConstraint: new UDim2(1, -(textX + 12), 0, 16),
			}),
		);
	}

	interface RelicPickProps {
		name: string;
		picked: boolean;
		reducedMotion?: boolean;
		onToggle: () => void;
		touch?: boolean;
	}

	function RelicPick(_param: RelicPickProps) {
		const name = _param.name;
		const picked = _param.picked;
		const reducedMotion = _param.reducedMotion;
		const onToggle = _param.onToggle;
		const touch = _param.touch ?? false;
		return h(Button, {
			text: `${picked ? "IN OFFER  ·  " : ""}${name}`,
			icon: "Inventory.4",
			onClick: onToggle,
			color: picked ? Palette.mint : Palette.panelSoft,
			textColor: picked ? Palette.ink : Palette.cream,
			size: new UDim2(1, 0, 0, touch ? TapTarget : 40),
			reducedMotion: reducedMotion,
			highlight: picked,
		});
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

	interface TradeFairnessMeterProps {
		draft: TradeOffer;
		them?: TradeOffer;
	}

	function TradeFairnessMeter(props: TradeFairnessMeterProps) {
		const yourScore = calcOfferValue(props.draft);
		const theirScore = calcOfferValue(props.them);
		const total = yourScore + theirScore;
		const yourRatio = total > 0 ? yourScore / total : 0.5;
		let balanceText: string;
		let balanceColor: Color3;
		if (total === 0) {
			balanceText = "Add items or currency to see the balance";
			balanceColor = Palette.muted;
		} else if (yourRatio >= 0.42 && yourRatio <= 0.58) {
			balanceText = "About even";
			balanceColor = Palette.mint;
		} else if (yourRatio > 0.58) {
			const adv = math.round((yourRatio - 0.5) * 200);
			balanceText = `You're giving +${adv}% more than you get`;
			balanceColor = Palette.mango;
		} else {
			const adv = math.round((0.5 - yourRatio) * 200);
			balanceText = `You're getting +${adv}% more than you give`;
			balanceColor = Palette.cyan;
		}
		return h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 48),
				BackgroundColor3: Palette.panelSoft,
				BorderSizePixel: 0,
				ZIndex: 5,
			},
			h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
			h("uipadding", {
				PaddingTop: new UDim(0, 6),
				PaddingBottom: new UDim(0, 6),
				PaddingLeft: new UDim(0, 10),
				PaddingRight: new UDim(0, 10),
			}),
			h(Text, {
				value: balanceText,
				size: 12,
				fit: true,
				minSize: 10,
				color: balanceColor,
				weight: Enum.FontWeight.Bold,
				sizeConstraint: new UDim2(1, 0, 0, 16),
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 8),
					Position: UDim2.fromOffset(0, 24),
					BackgroundColor3: Palette.graphite,
					BorderSizePixel: 0,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				h(
					"frame",
					{
						Size: new UDim2(yourRatio, 0, 1, 0),
						BackgroundColor3: Palette.mango,
						BorderSizePixel: 0,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
				h(
					"frame",
					{
						Size: new UDim2(1 - yourRatio, 0, 1, 0),
						Position: new UDim2(yourRatio, 0, 0, 0),
						BackgroundColor3: Palette.cyan,
						BorderSizePixel: 0,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
				),
			),
		);
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

	// table talk: the real conversation from the server, quick phrases, and a filtered line of your own
	function TradeChatStream(props: TradeChatStreamProps) {
		const session = props.session;
		const dispatch = props.dispatch;
		const [inputVal, setInputVal] = React.useState("");
		const scrollRef = React.useRef<ScrollingFrame>();
		// phones and touch: quick phrases and the input row get full tap height
		const touchRows = useTouchTargets();
		const pillH = touchRows ? TapTarget : 26;
		const inputH = touchRows ? TapTarget : 32;
		const lines = session.Chat ?? [];
		const myId = Players.LocalPlayer!.UserId;
		const seen = React.useRef(lines.size());
		React.useEffect(() => {
			// a new line from them gets a sound; the list stays pinned to the newest line
			if (lines.size() > seen.current && lines[lines.size() - 1] !== undefined && lines[lines.size() - 1].From !== myId) {
				Audio.play("chatReceive");
			}
			seen.current = lines.size();
			const list = scrollRef.current;
			if (list) {
				task.defer(() => {
					list.CanvasPosition = new Vector2(0, math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y));
				});
			}
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
				Padding: new UDim(0, 4),
				SortOrder: Enum.SortOrder.LayoutOrder,
			}),
		};
		if (lines.size() === 0) {
			rows.empty = h(Text, {
				value: "…",
				size: 12,
				color: Palette.muted,
				sizeConstraint: new UDim2(1, 0, 0, 18),
			});
		}
		for (const [index, line] of ipairs(lines)) {
			const mine = line.From === myId;
			rows[`l${index}`] = h(
				"frame",
				{
					LayoutOrder: index,
					Size: new UDim2(1, 0, 0, 0),
					AutomaticSize: Enum.AutomaticSize.Y,
					BackgroundTransparency: 1,
				},
				h(
					"textlabel",
					{
						Size: new UDim2(0.82, 0, 0, 0),
						AutomaticSize: Enum.AutomaticSize.Y,
						Position: UDim2.fromScale(mine ? 1 : 0, 0),
						AnchorPoint: new Vector2(mine ? 1 : 0, 0),
						BackgroundColor3: mine ? darken(Palette.mint, 0.6) : Palette.panelSoft,
						Text: `${mine ? "" : `<b>${line.Name}</b>  `}${line.Text}`,
						RichText: true,
						TextWrapped: true,
						TextSize: 13,
						FontFace: Font.fromEnum(line.Phrase !== undefined ? Enum.Font.BuilderSansBold : Enum.Font.BuilderSansMedium),
						TextColor3: Palette.cream,
						TextXAlignment: mine ? Enum.TextXAlignment.Right : Enum.TextXAlignment.Left,
					},
					h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
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
			h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
			h(Stroke, {
				color: BRASS,
				thickness: 1,
				transparency: 0.4,
			}),
			h("uipadding", {
				PaddingTop: new UDim(0, 10),
				PaddingBottom: new UDim(0, 10),
				PaddingLeft: new UDim(0, 12),
				PaddingRight: new UDim(0, 12),
			}),
			h(Text, {
				value: session.PartnerAway === true ? `${session.PartnerName} stepped away` : "Table talk",
				size: 11,
				color: session.PartnerAway === true ? Palette.coral : Palette.mint,
				weight: Enum.FontWeight.Heavy,
				sizeConstraint: new UDim2(1, 0, 0, 14),
			}),
			h(
				"scrollingframe",
				{
					ref: scrollRef,
					Size: new UDim2(1, 0, 1, -(18 + inputH + pillH + 12)),
					Position: UDim2.fromOffset(0, 18),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					CanvasSize: new UDim2(),
					AutomaticCanvasSize: Enum.AutomaticSize.Y,
					ScrollBarThickness: 3,
					ScrollBarImageColor3: Palette.muted,
					// vertical only, so a sideways drag on the phrase row doesn't nudge the log
					ScrollingDirection: Enum.ScrollingDirection.Y,
				},
				rows,
			),
			h(
				"scrollingframe",
				{
					Size: new UDim2(1, 0, 0, pillH + 4),
					Position: new UDim2(0, 0, 1, -(inputH + pillH + 8)),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					CanvasSize: new UDim2(),
					AutomaticCanvasSize: Enum.AutomaticSize.X,
					ScrollingDirection: Enum.ScrollingDirection.X,
					ScrollBarThickness: 0,
				},
				pills,
			),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, inputH),
					Position: new UDim2(0, 0, 1, -inputH),
					BackgroundTransparency: 1,
				},
				h(
					"textbox",
					{
						Size: new UDim2(1, -78, 1, 0),
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
					h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
					h("uipadding", { PaddingLeft: new UDim(0, 10) }),
				),
				h(Button, {
					text: "Send",
					onClick: () => {
						send(inputVal);
					},
					color: Palette.mint,
					textColor: Palette.ink,
					size: new UDim2(0, 70, 1, 0),
					position: new UDim2(1, -70, 0, 0),
				}),
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
				h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
				h(Stroke, {
					color: on ? color : Palette.line,
					thickness: on ? 2 : 1,
					transparency: on ? 0 : 0.5,
				}),
				h(Text, {
					value: relic.Name,
					size: 12,
					color: Palette.cream,
					weight: Enum.FontWeight.Bold,
					fit: true,
					minSize: 9,
					position: UDim2.fromOffset(10, 4),
					sizeConstraint: new UDim2(1, -20, 0, 16),
				}),
				h(Text, {
					value: `${relic.Rarity.upper()}  ·  L${relic.Level}${on ? "  ·  ASKED" : ""}`,
					size: 10,
					color: color,
					weight: Enum.FontWeight.Heavy,
					position: UDim2.fromOffset(10, 21),
					sizeConstraint: new UDim2(1, -20, 0, 14),
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
			h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
			h(Stroke, {
				color: BRASS,
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
						h("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }), ironFace(),
						h(Text, {
							value: `${session.PartnerName} wants`,
							size: 10,
							color: Palette.mango,
							weight: Enum.FontWeight.Heavy,
							position: UDim2.fromOffset(10, 6),
							sizeConstraint: new UDim2(1, -150, 0, 14),
						}),
						h(Text, {
							value: theirLine,
							size: 13,
							color: Palette.cream,
							weight: Enum.FontWeight.Bold,
							fit: true,
							minSize: 9,
							position: UDim2.fromOffset(10, 24),
							sizeConstraint: new UDim2(1, -150, 0, 26),
						}),
						h(Button, {
							text: "Add to my offer",
							onClick: () => {
								props.onAddRequested(theirs!);
							},
							color: Palette.mango,
							textColor: Palette.ink,
							size: UDim2.fromOffset(130, 36),
							position: new UDim2(1, -140, 0.5, -18),
						}),
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
		const antilag = useAntilag();
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
		const [offerTab, setOfferTab] = React.useState("You");
		const dirtyRef = React.useRef(false);
		const flushRef = React.useRef<thread>();
		const offerRevisionRef = React.useRef(0);
		const offerSessionRef = React.useRef<string | undefined>(session !== undefined ? session.Id : undefined);
		const [offerPending, setOfferPending] = React.useState(false);
		const sessionActionsHostRef = React.useRef<Frame>();
		// lobby layout: measured content width decides whether history gets its own column
		const lobbyHostRef = React.useRef<Frame>();
		const [lobbyWidth, setLobbyWidth] = React.useState(0);
		React.useEffect(() => {
			const host = lobbyHostRef.current;
			if (host === undefined) {
				return undefined;
			}
			const measure = () => {
				const measured = math.floor(host.AbsoluteSize.X);
				setLobbyWidth((current) => (current === measured ? current : measured));
			};
			measure();
			const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
			return () => connection.Disconnect();
		}, [session === undefined]);
		// gamepad (lobby): incoming invite > outgoing > search > roster > Invite > history ("Trade again");
		// on desktop the roster column (Main) and history column (Side, right) step left/right.
		// The live session keeps its own FocusClaim on the Ready/Confirm bar.
		useFocusOrder(
			lobbyHostRef,
			{
				regions: ["daily", "lock", "invite", "outgoing", "search", "roster", "invite-cta", "history-*"],
				first: ["invite", "roster", "invite-cta", "search"],
				columns: [["Main", "Side"]],
			},
			[session === undefined],
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
		const accent = Palette.mint;
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
		const actionH = compactTrade ? TapTarget * 3 + 24 : TapTarget + 8;
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
		const offerBody = (editor: boolean, lines: OfferLine[]) => {
			const clearButton =
				editor && !offerEmpty(draft)
					? h(Button, {
							text: "CLEAR OFFER",
							icon: "Refresh.1",
							onClick: () => queueOffer(emptyOffer()),
							color: Palette.panelSoft,
							textColor: Palette.creamSoft,
							size: new UDim2(1, 0, 0, phone ? TapTarget : 34),
							reducedMotion: softInvite,
						})
					: undefined;
			const fluxStepper = h(QuantityStepper, {
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
			});
			const stardustStepper = h(QuantityStepper, {
				label: "Stardust",
				value: draft.Stardust,
				max: cap("Stardust", tonumber(state.Stardust) ?? 0),
				accent: Palette.mango,
				reducedMotion: softMotion,
				onChange: (value: number) => queueOffer({ ...draft, Stardust: value }),
			});
			const coresStepper = h(QuantityStepper, {
				label: "Cores",
				value: draft.Cores,
				max: cap("Cores", tonumber(state.Cores) ?? 0),
				accent: Palette.violet,
				reducedMotion: softMotion,
				onChange: (value: number) => queueOffer({ ...draft, Cores: value }),
			});
			const signalsStepper = h(QuantityStepper, {
				label: "Signals",
				value: draft.Signals,
				max: cap("Signals", tonumber(state.Command?.Signals) ?? 0),
				accent: Palette.cyan,
				reducedMotion: softMotion,
				onChange: (value: number) => queueOffer({ ...draft, Signals: value }),
			});
			const essenceStepper = h(QuantityStepper, {
				label: "Essence",
				value: draft.Essence,
				max: cap("Essence", tonumber(state.Items?.Essence) ?? 0),
				accent: Palette.pink,
				reducedMotion: softMotion,
				onChange: (value: number) => queueOffer({ ...draft, Essence: value }),
			});
			const boostSteppers = BOOSTS.map((id) => {
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
					onChange: (value: number) => queueOffer({ ...draft, Boosts: { ...draft.Boosts, [id]: value } }),
				});
			});
			const keySteppers = KEYS.map((id) => {
				return h(QuantityStepper, {
					key: id,
					label: KEY_LABELS[id] ?? id,
					value: draft.Keys[id] ?? 0,
					max: math.min(daily?.PerTrade?.Keys ?? 5, state.Items?.Keys?.[id] ?? 0),
					accent: Palette.mango,
					reducedMotion: softMotion,
					onChange: (value: number) => queueOffer({ ...draft, Keys: { ...draft.Keys, [id]: value } }),
				});
			});
			const editorContent = editor
				? h(
						React.Fragment,
						undefined,
						fluxStepper,
						stardustStepper,
						coresStepper,
						signalsStepper,
						essenceStepper,
						boostSteppers,
						keySteppers,
						h(SectionLabel, {
							value: "Relics",
						}),
						relics.size() === 0
							? h(EmptyState, {
									icon: "Artifact",
									title: "No tradeable relics",
									body: "Equipped and locked pieces stay home.",
									compact: true,
								})
							: undefined,
						relics.map((relic) => {
							const picked = draft.ItemIds.indexOf(relic.uid) >= 0;
							return h(RelicPick, {
								key: relic.uid,
								uid: relic.uid,
								name: relic.name,
								picked: picked,
								touch: phone,
								reducedMotion: softMotion,
								onToggle: () => {
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
									queueOffer({ ...draft, ItemIds: pickedIds });
								},
							});
						}),
					)
				: undefined;
			const viewerContent = !editor
				? lines.map((line) =>
						h(OfferRow, {
							key: line.key,
							line: line,
							touch: phone,
						}),
					)
				: undefined;
			return h(
				React.Fragment,
				undefined,
				clearButton,
				editorContent,
				viewerContent,
				!editor && lines.size() === 0
					? h(EmptyState, {
							icon: "Crew",
							title: "Nothing offered yet",
							body: "Their side fills in as they add items.",
							compact: true,
						})
					: undefined,
			);
		};
		const offerPane = (
			title: string,
			partnerName: string,
			ready: boolean | undefined,
			confirmed: boolean | undefined,
			lines: OfferLine[],
			editor: boolean,
			flow?: boolean,
			flowOrder?: number,
		) => {
			if (flow === undefined) {
				flow = false;
			}
			const paneAccent = editor ? accent : Palette.cyan;
			const header = flow
				? h(
						"frame",
						{
							Size: new UDim2(1, 0, 0, 78),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ZIndex: 4,
							LayoutOrder: 0,
						},
						h(Text, {
							value: title,
							size: 14,
							color: paneAccent,
							weight: Enum.FontWeight.Heavy,
							fit: true,
							sizeConstraint: new UDim2(1, 0, 0, 20),
						}),
						h(Text, {
							value: partnerName,
							size: 13,
							color: Palette.creamSoft,
							fit: true,
							position: UDim2.fromOffset(0, 22),
							sizeConstraint: new UDim2(1, 0, 0, 18),
						}),
						h(Badge, {
							value: confirmed ? "CONFIRMED" : ready ? "READY" : "NOT READY",
							accent: confirmed ? Palette.mango : ready ? Palette.mint : Palette.muted,
							filled: confirmed === true || ready === true,
							position: UDim2.fromOffset(0, 46),
							size: UDim2.fromOffset(120, 28),
						}),
					)
				: h(
						"frame",
						{
							Size: new UDim2(1, 0, 0, 52),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							ZIndex: 4,
							LayoutOrder: 0,
						},
						h(Text, {
							value: title,
							size: 13,
							color: paneAccent,
							weight: Enum.FontWeight.Heavy,
							fit: true,
							sizeConstraint: new UDim2(1, -120, 0, 18),
						}),
						h(Text, {
							value: partnerName,
							size: 12,
							color: Palette.creamSoft,
							fit: true,
							position: UDim2.fromOffset(0, 22),
							sizeConstraint: new UDim2(1, -120, 0, 18),
						}),
						h(Badge, {
							value: confirmed ? "CONFIRMED" : ready ? "READY" : "NOT READY",
							accent: confirmed ? Palette.mango : ready ? Palette.mint : Palette.muted,
							filled: confirmed === true || ready === true,
							position: new UDim2(1, -108, 0, 8),
							size: UDim2.fromOffset(108, 28),
						}),
					);
			if (flow === false) {
				flow = true;
			}
			return h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, 0),
					AutomaticSize: Enum.AutomaticSize.Y,
					BackgroundColor3: Palette.panel,
					BorderSizePixel: 0,
					ClipsDescendants: false,
					LayoutOrder: flowOrder,
				},
				h("uicorner", {
					CornerRadius: new UDim(0, 14),
				}),
				h(Stroke, {
					color: paneAccent,
					thickness: 1,
					transparency: 0.42,
				}),
				h("uipadding", {
					PaddingTop: new UDim(0, 12),
					PaddingBottom: new UDim(0, 12),
					PaddingLeft: new UDim(0, 12),
					PaddingRight: new UDim(0, 12),
				}),
				h("uilistlayout", {
					FillDirection: Enum.FillDirection.Vertical,
					SortOrder: Enum.SortOrder.LayoutOrder,
					Padding: new UDim(0, 8),
				}),
				header,
				offerBody(editor, lines),
			);
		};
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
		const buildConfirmActions = (orientation: string) => {
			if (session === undefined) {
				return undefined;
			}
			const vertical = orientation === "vertical";
			const readySlot = h(
				"frame",
				{
					Name: "TradeReady",
					Size: vertical ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0, 0, 0, TapTarget),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: 1,
				},
				!vertical
					? h("uiflexitem", {
							FlexMode: Enum.UIFlexMode.Fill,
						})
					: undefined,
				h(Button, {
					text: offerPending
						? "SENDING…"
						: youReadyLocal
							? "UNREADY"
							: tableEmpty
								? "ADD SOMETHING FIRST"
								: "READY",
					onClick: onReadyClick,
					color: youReadyLocal ? Palette.panelSoft : accent,
					textColor: youReadyLocal ? Palette.cream : Palette.ink,
					size: UDim2.fromScale(1, 1),
					disabled: readyDisabled,
					loading: busy === "SetTradeReady",
					shakeToken: shakeFor("SetTradeReady"),
					reducedMotion: softMotion,
					highlight: !youReadyLocal && !tableEmpty,
					selectable: !readyDisabled,
				}),
			);
			const confirmSlot = h(
				"frame",
				{
					Name: "TradeConfirm",
					Size: vertical ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0, 0, 0, TapTarget),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: 2,
				},
				!vertical
					? h("uiflexitem", {
							FlexMode: Enum.UIFlexMode.Fill,
						})
					: undefined,
				h(Button, {
					text: session.YouConfirmed
						? "CONFIRMED"
						: confirmLeft > 0
							? `CONFIRM  ${clockLabel(session.ConfirmEndsAt, now)}`
							: "CONFIRM",
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
			);
			const cancelSlot = h(
				"frame",
				{
					Name: "TradeCancel",
					Size: vertical ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0, 0, 0, TapTarget),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					LayoutOrder: 3,
				},
				!vertical
					? h("uiflexitem", {
							FlexMode: Enum.UIFlexMode.Fill,
						})
					: undefined,
				h(Button, {
					text: "CANCEL",
					onClick: onCancelClick,
					color: Palette.coral,
					textColor: Palette.coral,
					outline: true,
					size: UDim2.fromScale(1, 1),
					disabled: busy !== "",
					loading: busy === "CancelTrade",
					shakeToken: shakeFor("CancelTrade"),
					reducedMotion: reducedMotion,
					selectable: busy === "",
				}),
			);
			if (vertical) {
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
						FillDirection: Enum.FillDirection.Vertical,
						SortOrder: Enum.SortOrder.LayoutOrder,
						Padding: new UDim(0, 8),
					}),
					readySlot,
					confirmSlot,
					cancelSlot,
				);
			}
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
					HorizontalFlex: Enum.UIFlexAlignment.Fill,
				}),
				readySlot,
				confirmSlot,
				cancelSlot,
			);
		};
		const rosterCards = visibleRows.map((row, index) => {
			const active = row.UserId === selected;
			const waiting = outgoingLive && outgoing?.ToUserId === row.UserId;
			return h(
				Panel,
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
				h(AvatarMark, {
					userId: row.UserId,
					accent: active ? accent : Palette.cyan,
					size: 44,
				}),
				h(Text, {
					value: row.DisplayName,
					size: 16,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					fit: true,
					position: UDim2.fromOffset(56, 4),
					sizeConstraint: new UDim2(1, compactTrade ? -70 : -176, 0, 22),
				}),
				h(Text, {
					value: `${row.Rebirths} rebirths · world ${row.CurrentZone}`,
					size: 12,
					color: Palette.creamSoft,
					fit: true,
					position: UDim2.fromOffset(56, 28),
					sizeConstraint: new UDim2(1, compactTrade ? -70 : -176, 0, 18),
				}),
				!compactTrade
					? h(Button, {
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
							size: UDim2.fromOffset(110, 40),
							position: new UDim2(1, -110, 0.5, -20),
							disabled: busy !== "" || waiting || !unlocked,
							loading: busy === "InviteTrade",
							shakeToken: shakeFor("InviteTrade"),
							reducedMotion: reducedMotion,
							highlight: !waiting,
						})
					: waiting
						? h(Badge, {
								value: "WAITING",
								accent: Palette.mango,
								filled: true,
								position: new UDim2(1, -84, 0.5, -12),
								size: UDim2.fromOffset(80, 24),
							})
						: undefined,
			);
		});
		if (session !== undefined) {
			const pinnedActions = buildConfirmActions(compactTrade ? "vertical" : "horizontal");
			const stepRow = phone ? TapTarget + 10 : 48;
			const lineRow = phone ? 64 : 58;
			const offerFloor = (editor: boolean, lines: OfferLine[]): number => {
				const header = 96;
				if (!editor) {
					return header + math.max(lines.size(), 1) * lineRow + 24;
				}
				return header + 40 + 6 * stepRow + 140 + math.min(relics.size(), 24) * stepRow;
			};
			const youFloor = offerFloor(true, yourLines);
			const themFloor = offerFloor(false, theirLines);
			const offerContentFloor = compactTrade
				? offerTab === "You"
					? youFloor
					: themFloor
				: math.max(youFloor, themFloor);
			return h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
					ClipsDescendants: false,
				},
				h(
					"frame",
					{
						Size: new UDim2(1, 0, 1, -(actionH + 8)),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClipsDescendants: true,
					},
					h(PageScaffold, {
						scrollBarColor: accent,
						scrollBarThickness: 4,
						tailPad: scrollTail(true, chrome.bottomSafe, chrome.landscape ? 16 : 20),
						gap: chrome.landscape ? 8 : Layout.stackGap,
						sections: [
							{
								id: "status",
								height: (chrome.landscape ? 52 : 60) + (tradeWarnings.size() > 0 ? 40 : 0),
								element: h(
									"frame",
									{
										Size: UDim2.fromScale(1, 1),
										BackgroundTransparency: 1,
										BorderSizePixel: 0,
									},
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
										sizeConstraint: new UDim2(1, 0, 0, 32),
									}),
									h(Text, {
										value:
											sessionLeft > 0 ? `Table ${clockLabel(session.ExpiresAt, now)}` : "Table expired",
										size: 11,
										color: sessionLeft > 12 ? Palette.mint : Palette.coral,
										weight: Enum.FontWeight.Bold,
										fit: true,
										position: UDim2.fromOffset(0, 34),
										sizeConstraint: new UDim2(1, 0, 0, 18),
									}),
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
												position: UDim2.fromOffset(0, 56),
												sizeConstraint: new UDim2(1, 0, 0, 36),
											})
										: undefined,
								),
							},
							{
								id: "meter",
								height: 54,
								element: h(TradeFairnessMeter, {
									draft: draft,
									them: session.Them,
								}),
							},
							{
								id: "chat",
								height: compactTrade ? 200 : 230,
								element: h(TradeChatStream, {
									session: session,
									dispatch: dispatch,
								}),
							},
							{
								id: "asks",
								height: tradeAsksHeight(session),
								element: h(TradeAsks, {
									session: session,
									dispatch: dispatch,
									myRelics: relics,
									onAddRequested: addRequested,
								}),
							},
							{
								id: "tabs",
								height: TapTarget,
								element: h(
									"frame",
									{
										Size: UDim2.fromScale(1, 1),
										BackgroundTransparency: 1,
										BorderSizePixel: 0,
									},
									h(SegmentedTabs, {
										options: [
											{
												id: "You",
												label: `YOUR OFFER${youReadyLocal ? " · READY" : ""}`,
											},
											{
												id: "Them",
												label: `${session.PartnerName.upper()}${session.ThemReady === true ? " · READY" : ""}`,
											},
										],
										value: offerTab,
										onChange: setOfferTab,
										accent: accent,
										columns: 2,
										size: UDim2.fromScale(1, 1),
										reducedMotion: reducedMotion,
									}),
								),
							},
							{
								id: "offer",
								fill: true,
								minHeight: 120,
								height: offerContentFloor,
								element: compactTrade ? (
									offerTab === "You" ? (
										offerPane("Your offer", `${yourLines.size()} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true)
									) : (
										offerPane(
											`${session.PartnerName}\'s offer`,
											session.ThemReady === true ? "They locked their side" : "Still arranging",
											session.ThemReady,
											session.ThemConfirmed,
											theirLines,
											false,
											true,
										)
									)
								) : (
									h(
										"frame",
										{
											Size: UDim2.fromScale(1, 1),
											BackgroundTransparency: 1,
											BorderSizePixel: 0,
										},
										h(
											"frame",
											{
												Size: new UDim2(0.49, -4, 0, 0),
												AutomaticSize: Enum.AutomaticSize.Y,
												BackgroundTransparency: 1,
												BorderSizePixel: 0,
											},
											offerPane("Your offer", `${yourLines.size()} on the table`, youReadyLocal, session.YouConfirmed, yourLines, true, true),
										),
										h(
											"frame",
											{
												Size: new UDim2(0.49, -4, 0, 0),
												Position: new UDim2(0.51, 4, 0, 0),
												AutomaticSize: Enum.AutomaticSize.Y,
												BackgroundTransparency: 1,
												BorderSizePixel: 0,
											},
											offerPane(
												`${session.PartnerName}\'s offer`,
												session.ThemReady === true ? "They locked their side" : "Still arranging",
												session.ThemReady,
												session.ThemConfirmed,
												theirLines,
												false,
												true,
											),
										),
									)
								),
							},
						],
					}),
				),
				h(
					"frame",
					{
						Size: new UDim2(1, 0, 0, actionH),
						Position: new UDim2(0, 0, 1, -actionH),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 6,
					},
					pinnedActions,
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
						Panel,
						{
							size: new UDim2(1, 0, 0, 86),
							accent: Palette.muted,
							padding: compactTrade ? 12 : Layout.cardPadding + 4,
							reducedMotion: reducedMotion,
							layoutOrder: 1,
						},
						h(Text, {
							value: regionBlocked ? PlayPolicy.Copy.TradingShort : "Player trading is locked",
							size: 15,
							color: Palette.cream,
							weight: Enum.FontWeight.Heavy,
							sizeConstraint: new UDim2(1, 0, 0, 22),
						}),
						h(Text, {
							value: regionBlocked ? PlayPolicy.Copy.Trading : (lock?.Requirement ?? "Complete your first rebirth."),
							size: 13,
							color: Palette.creamSoft,
							wrap: true,
							fit: true,
							minSize: 10,
							position: UDim2.fromOffset(0, 26),
							sizeConstraint: new UDim2(1, 0, 0, 48),
						}),
					)
				: undefined;
		const inviteElement =
			inviteLive && session === undefined
				? h(
						Panel,
						{
							size: new UDim2(1, 0, 0, 128),
							accent: Palette.cyan,
							padding: compactTrade ? 12 : Layout.cardPadding + 4,
							reducedMotion: reducedMotion,
							layoutOrder: 2,
						},
						h(AvatarMark, {
							userId: invite.FromUserId,
							accent: Palette.cyan,
							size: 44,
						}),
						h(Text, {
							value: `${invite.FromName ?? "Someone"} invited you`,
							size: 16,
							color: Palette.cream,
							weight: Enum.FontWeight.Heavy,
							fit: true,
							position: UDim2.fromOffset(56, 2),
							sizeConstraint: new UDim2(1, -64, 0, 22),
						}),
						h(Text, {
							value: clockLabel(invite.ExpiresAt, now),
							size: 13,
							color: Palette.creamSoft,
							fit: true,
							position: UDim2.fromOffset(56, 26),
							sizeConstraint: new UDim2(1, -64, 0, 20),
						}),
						h(
							"frame",
							{
								Size: new UDim2(1, 0, 0, TapTarget),
								Position: new UDim2(0, 0, 1, -TapTarget),
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
							},
							h(Button, {
								text: "ACCEPT",
								onClick: () => {
									return run("RespondTrade", {
										Accept: true,
									});
								},
								color: Palette.mint,
								textColor: Palette.ink,
								size: new UDim2(0.48, -4, 1, 0),
								disabled: busy !== "",
								loading: busy === "RespondTrade",
								shakeToken: shakeFor("RespondTrade"),
								reducedMotion: reducedMotion,
								highlight: true,
							}),
							h(Button, {
								text: "DECLINE",
								onClick: () => {
									return run("RespondTrade", {
										Accept: false,
									});
								},
								color: Palette.coral,
								textColor: Palette.ink,
								size: new UDim2(0.48, -4, 1, 0),
								position: new UDim2(0.52, 4, 0, 0),
								disabled: busy !== "",
								loading: busy === "RespondTrade",
								shakeToken: shakeFor("RespondTrade"),
								reducedMotion: reducedMotion,
							}),
						),
					)
				: undefined;
		const outgoingElement =
			outgoingLive && session === undefined && !inviteLive
				? h(
						Panel,
						{
							size: new UDim2(1, 0, 0, 124),
							accent: Palette.mango,
							padding: compactTrade ? 12 : Layout.cardPadding + 4,
							reducedMotion: reducedMotion,
							layoutOrder: 3,
						},
						h(Icon, {
							kind: "Timer.4",
							color: Palette.mango,
							accent: Palette.mango,
							size: 22,
							position: UDim2.fromOffset(2, 6),
							clipSafe: true,
							spin: false,
						}),
						h(Text, {
							value: `Waiting on ${outgoing.ToName ?? "partner"}`,
							size: 15,
							color: Palette.cream,
							weight: Enum.FontWeight.Heavy,
							fit: true,
							position: UDim2.fromOffset(32, 2),
							sizeConstraint: new UDim2(1, -40, 0, 22),
						}),
						h(Text, {
							value: clockLabel(outgoing.ExpiresAt, now),
							size: 13,
							color: Palette.mango,
							weight: Enum.FontWeight.Bold,
							fit: true,
							position: UDim2.fromOffset(32, 26),
							sizeConstraint: new UDim2(1, -40, 0, 18),
						}),
						h(Button, {
							text: "CANCEL",
							onClick: () => {
								return run("CancelTrade");
							},
							color: Palette.coral,
							textColor: Palette.ink,
							size: new UDim2(1, 0, 0, TapTarget),
							position: new UDim2(0, 0, 1, -TapTarget),
							disabled: busy !== "",
							loading: busy === "CancelTrade",
							shakeToken: shakeFor("CancelTrade"),
							reducedMotion: reducedMotion,
						}),
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
						h(SearchField, {
							value: query,
							onChange: setQuery,
							accent: accent,
							placeholder: "Find a forgemaster",
							size: new UDim2(1, -(searchH + 8), 0, searchH),
							reducedMotion: reducedMotion,
						}),
						h(Button, {
							text: "",
							icon: "Refresh.2",
							onClick: () => {
								return loadRoster();
							},
							color: Palette.panelSoft,
							textColor: Palette.cream,
							size: UDim2.fromOffset(searchH, searchH),
							position: new UDim2(1, -searchH, 0, 0),
							reducedMotion: reducedMotion,
						}),
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
		const sections: { id: string; height: number; element: unknown; fill?: boolean; minHeight?: number }[] = [
			{
				id: "daily",
				height: 22,
				element: dailyElement,
			},
		];
		if (lockElement !== undefined) {
			sections.push({
				id: "lock",
				height: 86,
				element: lockElement,
			});
		}
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
				: visibleRows.size() >= 8
					? h(FlatList, {
							data: visibleRows,
							itemHeight: rosterStride,
							overscan: softMotion === true ? 0 : antilag.constrained ? 1 : 2,
							canvasTail: 8,
							Size: UDim2.fromScale(1, 1),
							scrollBarColor: accent,
							scrollBarThickness: 4,
							keyExtractor: (row: RosterRow) => {
								return row.UserId;
							},
							renderItem: (_param_1: { index: number }) => {
								const index = _param_1.index;
								return rosterCards[index];
							},
						})
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
		sections.push({
			id: "roster",
			fill: visibleRows.size() >= 4,
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
		// completed trades, newest first: who, when, what changed hands
		const history = (trade !== undefined && typeIs(trade.History, "table") ? trade.History : []) as HistoryEntry[];
		// desktop with room (and a short, non-virtualised roster): history moves to a right-hand column
		const lobbyPlan = splitColumns(phone ? 0 : lobbyWidth, 360, chrome.landscape ? 8 : Layout.stackGap);
		const splitLobby = lobbyPlan.split && visibleRows.size() < 8;
		const historyStart = sections.size();
		sections.push({
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
		});
		for (const [index, entry] of ipairs(history)) {
			const ago = math.max(0, os.time() - entry.At);
			const when =
				ago < 3600
					? `${math.max(1, math.floor(ago / 60))}m ago`
					: ago < 86400
						? `${math.floor(ago / 3600)}h ago`
						: `${math.floor(ago / 86400)}d ago`;
			sections.push({
				id: `history-${index}`,
				height: phone ? 104 : 84,
				element: h(
					Panel,
					{
						size: UDim2.fromScale(1, 1),
						accent: accent,
						background: Palette.panel,
						padding: 16,
						clips: false,
					},
					h(Text, {
						value: `With ${entry.Partner}  ·  ${when}`,
						size: 14,
						color: Palette.cream,
						weight: Enum.FontWeight.Bold,
						sizeConstraint: new UDim2(1, -150, 0, 20),
					}),
					h(Text, {
						value: `− ${entry.Gave}\n+ ${entry.Got}`,
						size: 13,
						color: Palette.muted,
						wrap: true,
						fit: true,
						minSize: 10,
						position: UDim2.fromOffset(0, 24),
						sizeConstraint: new UDim2(1, -150, 0, phone ? 56 : 40),
					}),
					Players.GetPlayerByUserId(entry.PartnerId) !== undefined
						? h(Button, {
								// the same partner is still here: one tap opens a fresh trade with them
								text: "Trade again",
								icon: "Send.3",
								color: accent,
								textColor: Palette.ink,
								size: UDim2.fromOffset(140, TapTarget),
								position: new UDim2(1, -140, 0, 4),
								reducedMotion: reducedMotion,
								onClick: () => dispatch("InviteTrade", { UserId: entry.PartnerId }),
							})
						: undefined,
				),
			});
		}
		const lobbyGap = chrome.landscape ? 8 : Layout.stackGap;
		let lobbySections = sections;
		if (splitLobby) {
			const main = sections.filter((_, index) => index < historyStart);
			const side = sections.filter((_, index) => index >= historyStart);
			const rowH = math.max(
				stackHeight(main.map((section) => section.height), lobbyGap),
				stackHeight(side.map((section) => section.height), lobbyGap),
			);
			lobbySections = [
				{
					id: "lobby-split",
					height: rowH,
					element: h(SplitColumns, {
						name: "TradeLobbySplit",
						height: rowH,
						plan: lobbyPlan,
						sideOnRight: true,
						side: h(StackBlocks, { gap: lobbyGap, blocks: side as never }),
						main: h(StackBlocks, { gap: lobbyGap, blocks: main as never }),
					}),
				},
			];
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
				gap: lobbyGap,
				sections: lobbySections,
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
