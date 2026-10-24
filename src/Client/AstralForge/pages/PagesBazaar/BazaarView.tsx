import React from "@rbxts/react";
import * as Format from "../../CoreKit/format";
import { chromeFor, Palette, Radius, scrollTail, StrokeWidth, TapTarget } from "../../CoreKit/theme";
import { useViewport } from "../../MotionKit/motion";
import { counted, memoRow, sameFields } from "../../UiCore/rowMemo";
import { columnsBalanced, SplitColumns, splitColumns, StackBlocks, stackHeight } from "../../UiCore/ui";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import type { Session } from "../../state";
import { HeaderArt } from "../../UiCore/HeaderArt";
import { loadAudio, loadBrowse, loadPageScaffold, loadUi, named } from "../luauDeps";
import { BODY, BODY_BOLD, BODY_SEMI, Bar, GlyphWell, Line, MockPanel, NUM, PanelHeading, PnSurface, ROW_RADIUS } from "../../UiCore/mockKit";
import { HEADING_SECTION_H, HeadingSection, headingBlock, MockBtn, MockRow, panelHeight, rowHeight, RowFace, SEC, TileWell } from "../mockRows";
import { useHeroTabs } from "../../UiCore/heroTabs";
import { MockTabs } from "../socialKit";
// generated from design/06-bazaar by scripts/gen_from_layout.js (scripts/layout/bazaar.spec.json)
import { BazaarLayout as L } from "../generated/BazaarLayout";

const Ui = loadUi();
const Audio = loadAudio();
const PageScaffold = loadPageScaffold();
const Browse = loadBrowse();
const HttpService = game.GetService("HttpService");
const Workspace = game.GetService("Workspace");

type Flux = Format.Flux;

const CATEGORIES = [
	{ id: "All", label: "All supplies" },
	{ id: "Resources", label: "Resources" },
	{ id: "Keys", label: "Keys" },
	{ id: "Boosts", label: "Boosts" },
	{ id: "Command", label: "Command" },
	{ id: "Tokens", label: "Wheel tokens" },
	{ id: "Rare", label: "Rare finds" },
	{ id: "Saved", label: "Saved" },
	{ id: "Requests", label: "Requests" },
	{ id: "History", label: "Purchases" },
];
const ACCENTS: Record<string, Color3 | undefined> = {
	Resources: Palette.mango,
	Keys: Palette.violet,
	Boosts: Palette.cyan,
	Command: Palette.green,
	Tokens: Palette.pink,
	Rare: Palette.creamSoft,
};

interface Order {
	Game: string;
	Pick: string;
	Bucket: unknown;
	Quantity: number;
	UnitPrice: Flux;
	Currency: string;
	RequestId: string;
	Rotation: unknown;
}

// an order whose reply never arrived survives the page closing, so a retry reuses its receipt
let sessionOrder: Order | undefined;

const FAVOR_ICONS: Record<string, string | undefined> = {
	Resources: "Forge",
	Keys: "Crate",
	Command: "Command",
	Boosts: "Boost",
	Tokens: "Wheel",
	Rare: "Artifact",
};

interface Offer {
	Id: string;
	Name: string;
	Category: string;
	Reward: Format.Reward & Record<string, unknown>;
	Price: Flux;
	Discount: number;
	Left: number;
	Stock: number;
	Rare?: boolean;
	Procured?: boolean;
	Featured?: boolean;
	Holdings?: Array<{ Label: string; Count: unknown }>;
}

interface Market {
	EndsAt: number;
	Offers: Offer[];
	CatalogSize: number;
	Saved?: Record<string, boolean | undefined>;
	Merchant?: { Name: string; Title: string; Favors: string; Line: string; Accent: [number, number, number] };
	Reputation?: {
		Name: string;
		Units: number;
		Bonus: number;
		Next?: string;
		NextAt?: number;
		CanProcure?: boolean;
		ProcureTier?: string;
	};
	Watched?: string[];
	Refunded?: Flux;
	RecoveryPending?: boolean;
	Procure?: { Id?: string; Name?: string; State?: string };
	Catalog?: Array<{ Id: string; Name: string; Category: string }>;
	History?: Array<{ Name: string; Quantity: number; Cost: Flux; At: number }>;
	Bucket: unknown;
	Rotation: unknown;
}

interface Response {
	ok?: boolean;
	message?: string;
	error?: string;
	Uncertain?: boolean;
}

interface BazaarProps {
	state: Session & { Bazaar?: { Market?: Market } };
	dispatch: (action: string, payload: object, callback: (response: Response) => void) => void;
	reducedMotion?: boolean;
	initialCategory?: string;
	initialQuery?: string;
}

interface Section {
	id: string;
	height: number;
	element: React.Element;
}

function MerchantPortrait(props: {
	accent?: Color3;
	favors?: string;
	size?: UDim2;
	position?: UDim2;
	tilt?: number;
	name?: string;
	reducedMotion?: boolean;
}) {
	const accent = props.accent ?? Palette.cyan;
	const favors = props.favors ?? "Resources";
	const iconKind = FAVOR_ICONS[favors] ?? "Shop";
	const tag = (props.favors ?? "MERCHANT").upper();
	const round = (radius: UDim) => <uicorner CornerRadius={radius} />;

	return (
		<frame
			{...named("MerchantPortrait")}
			Size={props.size}
			Position={props.position}
			BackgroundColor3={Palette.panelSoft}
			BorderSizePixel={0}
			ClipsDescendants={true}
		>
			{round(new UDim(0, ROW_RADIUS))}
			<uistroke Color={accent} Thickness={StrokeWidth.hairline} Transparency={0.5} />
			{/* Soft radial atmospheric glow from top */}
			<frame
				{...named("Atmosphere")}
				Size={UDim2.fromScale(1, 0.78)}
				Position={UDim2.fromScale(0, 0)}
				BorderSizePixel={0}
				BackgroundColor3={accent}
				BackgroundTransparency={0.88}
			>
				<uigradient
					Rotation={90}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0),
							new NumberSequenceKeypoint(0.65, 0.55),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>
			{/* Specular sheen glint */}
			<frame
				{...named("Sheen")}
				Size={UDim2.fromScale(1.4, 0.3)}
				Position={UDim2.fromScale(-0.2, 0.05)}
				Rotation={-28}
				BorderSizePixel={0}
				BackgroundColor3={Palette.white}
				BackgroundTransparency={0.94}
			/>
			{/* Top crest jeweler accent bar */}
			<frame
				{...named("CrestBar")}
				Size={UDim2.fromOffset(24, 3)}
				Position={new UDim2(0.5, 0, 0, 7)}
				AnchorPoint={new Vector2(0.5, 0)}
				BorderSizePixel={0}
				BackgroundColor3={accent}
				BackgroundTransparency={0.25}
			>
				{round(new UDim(1, 0))}
			</frame>
			{/* Centered Heraldic Sigil GlyphWell */}
			<frame
				{...named("SigilWell")}
				Size={UDim2.fromOffset(50, 50)}
				Position={new UDim2(0.5, 0, 0.42, 0)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<GlyphWell
					kind={iconKind}
					accent={accent}
					size={50}
					radius={ROW_RADIUS}
					glow={true}
					filled={true}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
			{/* Bottom Favors / Guild Ribbon */}
			<frame
				{...named("GuildRibbon")}
				Size={new UDim2(1, -12, 0, 18)}
				Position={new UDim2(0.5, 0, 1, -7)}
				AnchorPoint={new Vector2(0.5, 1)}
				BackgroundColor3={Palette.ink}
				BackgroundTransparency={0.15}
				BorderSizePixel={0}
			>
				{round(new UDim(0, ROW_RADIUS))}
				<uistroke Color={accent} Thickness={1} Transparency={0.45} />
				<Ui.Text
					value={tag}
					size={9}
					weight={Enum.FontWeight.Heavy}
					color={accent}
					align={Enum.TextXAlignment.Center}
					position={UDim2.fromOffset(0, 1)}
					sizeConstraint={new UDim2(1, 0, 1, -2)}
					fit={false}
				/>
			</frame>
		</frame>
	);
}

interface BazaarOfferCardProps {
	offer: Offer;
	quantity: number;
	total: Flux;
	enough: boolean;
	saved: boolean;
	inspected: boolean;
	busy: boolean;
	expired: boolean;
	reducedMotion?: boolean;
	size: UDim2;
	position: UDim2;
	phone?: boolean;
	onToggleSave: () => void;
	onInspect: () => void;
	onBuy: () => void;
}

function darken3(c: Color3): Color3 {
	return c.Lerp(Palette.ink, 0.55);
}

// 06-bazaar listing .row: tile, Name over the deal line, stock, price, sm buttons
// desktop row = the 06-bazaar listing .row (generated BazaarLayout.Row: 64px, padding 6/12, 14px gaps)
const OFFER_ROW_H = L.Row.h;
const OFFER_ROW_H_PHONE = 64 + TapTarget + 8;
function offerRowHeight(phone: boolean): number {
	return phone ? OFFER_ROW_H_PHONE : OFFER_ROW_H;
}

function BazaarOfferCardImpl(props: BazaarOfferCardProps) {
	const offer = props.offer;
	const quantity = props.quantity;
	const total = props.total;
	const enough = props.enough;
	const reducedMotion = props.reducedMotion;
	const phone = props.phone === true;
	const accent = ACCENTS[offer.Category] ?? Palette.violet;
	const flag = offer.Rare ? "Rare find · " : offer.Procured ? "Requested · " : offer.Featured ? "Featured · " : "";
	const buyText = props.expired
		? "Refresh stock"
		: offer.Left === 0
			? "Sold out"
			: offer.Left < quantity
				? "Not enough stock"
				: `Buy ${quantity}`;
	const canBuy = !(props.busy || props.expired || !enough || offer.Left < quantity);
	const buttonsW = phone ? 0 : 44 + 8 + 96 + 8 + 128;
	const buttons = (
		<>
			<MockBtn text={props.saved ? "★" : "☆"} sec={true} sm={true} phone={phone} width={44} disabled={props.busy} onClick={props.onToggleSave} reducedMotion={reducedMotion} layoutOrder={0} />
			<MockBtn text={props.inspected ? "Inspecting" : "Inspect"} sec={true} sm={true} phone={phone} width={96} onClick={props.onInspect} reducedMotion={reducedMotion} layoutOrder={1} />
			<MockBtn text={buyText} accent={accent} sm={true} phone={phone} width={128} disabled={!canBuy} onClick={props.onBuy} reducedMotion={reducedMotion} layoutOrder={2} />
		</>
	);
	if (!phone) {
		// 06-bazaar listing .row on a horizontal list: tile / name over the deal line (fills) / stock in the
		// 110px seller column / price / sm buttons, all centred, 14px apart
		return (
			<frame Size={props.size} Position={props.position} BackgroundColor3={Palette.white} BorderSizePixel={0}>
				<RowFace outline={props.inspected ? accent : undefined} />
				<uipadding PaddingLeft={new UDim(0, L.Row.pad.left)} PaddingRight={new UDim(0, L.Row.pad.right)} PaddingTop={new UDim(0, L.Row.pad.top)} PaddingBottom={new UDim(0, L.Row.pad.bottom)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.Row.gap)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				<TileWell icon="Shop" accent={accent} size={L.RowTile.w} dim={offer.Left === 0} layoutOrder={0} />
				<frame BackgroundTransparency={1} Size={new UDim2(0, 0, 0, L.RowText.h)} LayoutOrder={1}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<Line text={offer.Name} size={L.RowName.text.size} font={BODY_SEMI} color={L.RowName.text.color} width={new UDim(1, 0)} height={L.RowName.h} />
					<Line
						text={`${flag}-${math.floor(offer.Discount * 100)}% · ${Format.formatReward(offer.Reward)}`}
						size={L.RowSub.text.size}
						font={BODY}
						color={accent}
						width={new UDim(1, 0)}
						position={UDim2.fromOffset(0, L.RowSub.y - L.RowText.y)}
						height={L.RowSub.h}
					/>
				</frame>
				<Line text={`${offer.Left}/${offer.Stock} left`} size={L.RowSeller.text.size} font={BODY} color={L.RowSeller.text.color} width={new UDim(0, L.RowSeller.w)} height={L.RowSeller.h} layoutOrder={2} />
				<Line text={Format.compactNumber(total)} size={L.RowPrice.text.size} font={NUM} color={Palette.mango} align={Enum.TextXAlignment.Right} height={L.RowPrice.h} layoutOrder={3} />
				<frame BackgroundTransparency={1} Size={UDim2.fromOffset(buttonsW, L.RowBuy.h)} LayoutOrder={4}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Right} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{buttons}
				</frame>
			</frame>
		);
	}
	return (
		<frame Size={props.size} Position={props.position} BackgroundColor3={Palette.white} BorderSizePixel={0}>
			<RowFace outline={props.inspected ? accent : undefined} />
			<uipadding PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 12)} PaddingTop={new UDim(0, 8)} PaddingBottom={new UDim(0, 8)} />
			<TileWell icon="Shop" accent={accent} size={56} dim={offer.Left === 0} />
			<frame BackgroundTransparency={1} Position={UDim2.fromOffset(68, 6)} Size={new UDim2(1, -(68 + 110), 0, 44)}>
				<Line text={offer.Name} size={14} font={BODY_BOLD} width={new UDim(1, 0)} />
				<Line text={`${flag}-${math.floor(offer.Discount * 100)}% · ${Format.formatReward(offer.Reward)}`} size={12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} position={UDim2.fromOffset(0, 22)} height={16} />
			</frame>
			<frame BackgroundTransparency={1} AnchorPoint={new Vector2(1, 0)} Position={new UDim2(1, 0, 0, 6)} Size={UDim2.fromOffset(110, 44)}>
				<Line text={Format.compactNumber(total)} size={14} font={NUM} color={Palette.mango} width={new UDim(1, 0)} align={Enum.TextXAlignment.Right} />
				<Line text={`${offer.Left}/${offer.Stock} left`} size={12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} align={Enum.TextXAlignment.Right} position={UDim2.fromOffset(0, 22)} height={16} />
			</frame>
			<frame BackgroundTransparency={1} AnchorPoint={new Vector2(0, 1)} Position={new UDim2(0, 0, 1, 0)} Size={new UDim2(1, 0, 0, TapTarget)}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Right} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{buttons}
			</frame>
			<frame BackgroundTransparency={1} Position={new UDim2(0, 68, 0, 52)} Size={new UDim2(1, -68, 0, 4)}>
				<Bar fill={offer.Left / math.max(1, offer.Stock)} color={accent} thin={true} />
			</frame>
		</frame>
	);
}

// shows: the offer (name, category/flags, discount, reward, stock, price) by value, the quantity and
// total for the chosen amount, can-afford, saved/inspected button text, busy/expired button state,
// motion, and its grid slot (size/position); the three handlers go through memoRow's latest-callback refs
const BazaarOfferCard = memoRow<BazaarOfferCardProps>(counted("BazaarOffer", BazaarOfferCardImpl), ["onToggleSave", "onInspect", "onBuy"],
	sameFields<BazaarOfferCardProps>(["offer", "quantity", "total", "enough", "saved", "inspected", "busy", "expired", "reducedMotion", "size", "position", "phone"]));

function orderTotal(price: Flux, quantity: number): Flux {
	const value = tonumber(price);
	if (value !== undefined && value < math.huge && value * quantity < math.huge) {
		return value * quantity;
	}
	const logarithm = Format.log10Flux(price) + math.log(quantity) / math.log(10);
	if (logarithm === math.huge) {
		return "inf";
	}
	const exponent = math.floor(logarithm);
	return "%.8fe%d".format(10 ^ (logarithm - exponent), exponent);
}

function supplyUnit(reward: Record<string, unknown>): LuaTuple<[string | undefined, number | undefined]> {
	let identity: string | undefined;
	let units: number | undefined;
	for (const [kind, value] of pairs(reward)) {
		if (identity !== undefined) {
			return $tuple(undefined, undefined);
		}
		if (kind === "Keys") {
			for (const [crate, count] of pairs(value as Record<string, number>)) {
				if (identity !== undefined) {
					return $tuple(undefined, undefined);
				}
				identity = "Keys:" + crate;
				units = count;
			}
		} else if (kind === "Boost") {
			identity = "Boost:" + tostring(value);
			units = 1;
		} else if (typeIs(value, "number") && value > 0) {
			identity = kind;
			units = value;
		} else {
			return $tuple(undefined, undefined);
		}
	}
	return $tuple(identity, units);
}

function plainFind(text: string, needle: string): boolean {
	return text.find(needle, 1, true)[0] !== undefined;
}

function BazaarView(props: BazaarProps) {
	const market = props.state.Bazaar && props.state.Bazaar.Market;
	const [category, setCategory] = Browse.useLinkedTab("Bazaar", "All", props.initialCategory);
	const [query, setQuery] = Browse.useLinkedQuery("Bazaar", props.initialQuery);
	const [sort, setSort] = React.useState("Discount");
	const [amount, setAmount] = React.useState("One");
	const [inspected, setInspected] = React.useState<string | undefined>(undefined);
	const saved: Record<string, boolean | undefined> = market ? (market.Saved ?? {}) : {};
	const [note, setNote] = React.useState("");
	const [busy, setBusy] = React.useState(false);
	const [width, setWidth] = React.useState(320);
	// tab hosts reserve one row when SegmentedTabs draws as a phone strip
	const categoriesH = (Ui.useSegmentedHeight as unknown as (count: number, columns: number, rowH: number, gap: number) => number)(
		CATEGORIES.size(), math.max(1, math.min(4, math.floor((width + 6) / 130))), 48, 6);
	const optionsH = (Ui.useSegmentedHeight as unknown as (count: number, columns: number, rowH: number, gap: number) => number)(
		3, math.max(1, math.min(3, math.floor((width + 6) / 120))), 48, 6);
	const [now, setNow] = React.useState(Workspace.GetServerTimeNow());
	// phones: clear the tab bar and home indicator like the other pages (was a flat 72 everywhere;
	// desktop keeps 72, a phone with a small inset still gets 72)
	const chrome = chromeFor(useViewport());
	const bazaarTail = chrome.stack ? scrollTail(true, chrome.bottomSafe, 32) : 72;
	const scrollRef = React.useRef<GuiObject>();
	// 06-bazaar .hero .tabs: Buy is this market; players can't sell or keep a stall here, so those two
	// tabs open an honest empty state instead of invented listings
	const [bazaarTab, setBazaarTab] = React.useState("Buy");
	useHeroTabs(
		chrome.stack ? undefined : (
			<MockTabs
				options={[
					{ id: "Buy", label: "Buy" },
					{ id: "Sell", label: "Sell" },
					{ id: "Stall", label: "My stall" },
				]}
				value={bazaarTab}
				onChange={setBazaarTab}
				accent={Palette.violet}
				phone={false}
				reducedMotion={props.reducedMotion}
				layoutOrder={0}
			/>
		),
	);
	// gamepad: header > search > categories > sort/quantity > (Close inspection) > shelf; the shelf
	// (Main) and the inspection column (Side, right) step left/right on desktop. First focus: an offer.
	useFocusOrder(
		scrollRef,
		{
			regions: [
				"market-header",
				"legacy-*",
				"search",
				"categories",
				"request-status",
				"request-cancel",
				"request-*",
				"sort",
				"quantity",
				"inspection-heading",
				"shelf-*",
				"purchase-*",
			],
			first: ["shelf-*", "request-*", "categories"],
			columns: [["Main", "Side"]],
		},
		[category],
	);
	const pending = React.useRef(false);
	const nonce = React.useRef(0);
	const live = React.useRef(true);
	const timeout = React.useRef<thread>();
	const unresolved = React.useRef<Order | undefined>(sessionOrder);
	React.useEffect(() => {
		live.current = true;
		const host = scrollRef.current;
		let connection: RBXScriptConnection | undefined;
		if (host) {
			const measure = () => {
				if (host.AbsoluteSize.X > 0) {
					setWidth(host.AbsoluteSize.X);
				}
			};
			measure();
			connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		}
		const clock = task.spawn(() => {
			while (live.current) {
				task.wait(1);
				if (live.current) {
					setNow(Workspace.GetServerTimeNow());
				}
			}
		});
		return () => {
			live.current = false;
			nonce.current += 1;
			if (connection) {
				connection.Disconnect();
			}
			task.cancel(clock);
			if (timeout.current) {
				task.cancel(timeout.current);
			}
		};
	}, []);
	const request = (action: string, payload: object) => {
		if (pending.current) {
			return;
		}
		if (action === "BazaarPlay") {
			const order = payload as Order;
			const previous = unresolved.current;
			if (previous) {
				if (previous.Pick !== order.Pick || previous.Quantity !== order.Quantity) {
					setNote("Resolve the previous order before buying something else. Retry that same item and quantity.");
					return;
				}
				payload = previous;
			} else {
				unresolved.current = order;
				sessionOrder = order;
			}
		}
		pending.current = true;
		nonce.current += 1;
		const token = nonce.current;
		setBusy(true);
		timeout.current = task.delay(20, () => {
			if (live.current && nonce.current === token) {
				nonce.current += 1;
				pending.current = false;
				timeout.current = undefined;
				setBusy(false);
				setNote("No response yet. Retry the same order to check its receipt without buying twice.");
			}
		});
		props.dispatch(action, payload, (response) => {
			if (action === "BazaarPlay" && response.Uncertain !== true) {
				const requestId = (payload as Order).RequestId;
				if (sessionOrder && sessionOrder.RequestId === requestId) {
					sessionOrder = undefined;
				}
				if (unresolved.current && unresolved.current.RequestId === requestId) {
					unresolved.current = undefined;
				}
			}
			if (!live.current || nonce.current !== token) {
				return;
			}
			if (timeout.current) {
				task.cancel(timeout.current);
				timeout.current = undefined;
			}
			pending.current = false;
			setBusy(false);
			setNote(
				response.Uncertain
					? "The connection interrupted your order. Retry it below to check the original receipt."
					: response.ok
						? (response.message ?? "Stock updated.")
						: (response.error ?? "The order could not be completed."),
			);
			Audio.play(response.ok ? "successChime" : "error");
		});
	};
	const sections: Section[] = [];
	const add = (id: string, height: number, element: React.Element) => {
		sections.push({ id, height, element });
	};
	const left = market ? math.max(0, market.EndsAt - now) : 0;
	const expired = market !== undefined && left === 0;
	// wide: title left, next shipment and Refresh right, rules below. Narrow: the title gets its own row.
	const narrowHeader = width < 560;
	const rowY = narrowHeader ? 44 : 0;
	add(
		"market-header",
		narrowHeader ? 168 : 112,
		<PnSurface
			size={UDim2.fromScale(1, 1)}
			padding={16}
			accent={Palette.brass}
			background={Palette.panel}
			reducedMotion={props.reducedMotion}
		>
			<HeaderArt art="market" inset={16} />
			<Ui.Text
				value={expired ? "Fresh stock" : "This shipment"}
				size={28}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={20}
				sizeConstraint={narrowHeader ? new UDim2(1, 0, 0, 38) : new UDim2(1, -300, 0, 38)}
			/>
			<Ui.Text
				value={
					expired
						? "New stock is ready"
						: market
							? "Next shipment in " + Format.clockText(left)
							: "Waiting for stock"
				}
				size={14}
				weight={Enum.FontWeight.Bold}
				color={Palette.violet}
				align={narrowHeader ? Enum.TextXAlignment.Left : Enum.TextXAlignment.Right}
				position={narrowHeader ? UDim2.fromOffset(0, rowY + 2) : new UDim2(1, -292, 0, 2)}
				sizeConstraint={narrowHeader ? new UDim2(1, -124, 0, 36) : UDim2.fromOffset(170, 36)}
			/>
			<Ui.Button
				text="Refresh"
				size={UDim2.fromOffset(112, 40)}
				position={new UDim2(1, -112, 0, rowY)}
				color={Palette.violet}
				disabled={busy}
				reducedMotion={props.reducedMotion}
				onClick={() => request("GetState", {})}
			/>
			<Ui.Text
				value={
					(market
						? `${market.Offers.size()} shipments from a ${market.CatalogSize}-item catalog. Stock limits are yours alone. `
						: "Opening the supply ledger... ") + "Prices follow your steady production, with a 1,000-Flux minimum."
				}
				size={13}
				wrap={true}
				fit={true}
				minSize={10}
				color={Palette.muted}
				position={UDim2.fromOffset(0, rowY + 50)}
				sizeConstraint={new UDim2(1, 0, 0, 44)}
			/>
		</PnSurface>,
	);
	if (note !== "") {
		add(
			"receipt",
			80,
			<Ui.Text value={note} size={14} wrap={true} sizeConstraint={UDim2.fromScale(1, 1)} color={Palette.creamSoft} />,
		);
	}
	const merchant = market && market.Merchant;
	const reputation = market && market.Reputation;
	if (merchant && reputation) {
		const accent = Color3.fromRGB(merchant.Accent[0], merchant.Accent[1], merchant.Accent[2]);
		const progress = reputation.NextAt !== undefined ? reputation.Units / reputation.NextAt : 1;
		add(
			"merchant",
			212,
			<PnSurface
				size={UDim2.fromScale(1, 1)}
				padding={18}
				accent={Palette.brass}
				background={Palette.panel}
				reducedMotion={props.reducedMotion}
			>
				<MerchantPortrait
					accent={accent}
					size={UDim2.fromOffset(84, 96)}
					position={UDim2.fromOffset(0, 0)}
					tilt={((merchant.Name.size() % 3) - 1) * 5}
					favors={merchant.Favors}
					name={merchant.Name}
					reducedMotion={props.reducedMotion}
				/>
				<Ui.Text
					value={merchant.Name}
					size={19}
					weight={Enum.FontWeight.Heavy}
					position={UDim2.fromOffset(98, 0)}
					sizeConstraint={new UDim2(1, -98, 0, 26)}
				/>
				<Ui.Text
					value={`${merchant.Title} · ${merchant.Favors.lower()}`}
					size={12}
					color={accent}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(98, 28)}
					sizeConstraint={new UDim2(1, -98, 0, 32)}
				/>
				<Ui.Text
					value={"“" + merchant.Line + "”"}
					size={13}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(98, 60)}
					sizeConstraint={new UDim2(1, -98, 0, 40)}
				/>
				<Ui.Text
					value={
						`Standing: ${reputation.Name}` +
						(reputation.Bonus > 0 ? ` · +${reputation.Bonus} stock on regular shelves` : "") +
						(reputation.Next !== undefined
							? ` · ${math.max(0, reputation.NextAt! - reputation.Units)} more units bought for ${reputation.Next}`
							: " · highest standing")
					}
					size={12}
					wrap={true}
					fit={true}
					minSize={10}
					color={Palette.muted}
					position={UDim2.fromOffset(0, 108)}
					sizeConstraint={new UDim2(1, 0, 0, 40)}
				/>
				<Bar fill={math.clamp(progress, 0, 1)} color={accent} thin={true} position={UDim2.fromOffset(0, 154)} />
				<Ui.Text
					value={
						reputation.CanProcure
							? "Requests are open: ask for any supply and it is held for you."
							: `Supply requests open at ${reputation.ProcureTier} standing.`
					}
					size={12}
					wrap={true}
					fit={true}
					minSize={10}
					color={Palette.muted}
					position={UDim2.fromOffset(0, 166)}
					sizeConstraint={new UDim2(1, 0, 0, 22)}
				/>
			</PnSurface>,
		);
	}
	if (market && market.Watched && market.Watched.size() > 0) {
		add(
			"watched",
			64,
			<Ui.Text
				value={"★ " + market.Watched.join(", ")}
				size={14}
				wrap={true}
				color={Palette.green}
				sizeConstraint={UDim2.fromScale(1, 1)}
			/>,
		);
	}
	if (unresolved.current) {
		add(
			"retry-order",
			48,
			<Ui.Button
				text="Retry previous order"
				size={UDim2.fromScale(1, 1)}
				color={Palette.violet}
				disabled={busy}
				reducedMotion={props.reducedMotion}
				onClick={() => request("BazaarPlay", unresolved.current!)}
			/>,
		);
	}
	if (market && Format.compareFlux(market.Refunded ?? 0, 0) > 0) {
		add(
			"legacy-refund",
			36,
			<Ui.Text
				value={`+${Format.compactNumber(market.Refunded)} flux refunded`}
				size={13}
				wrap={true}
				color={Palette.green}
				sizeConstraint={UDim2.fromScale(1, 1)}
			/>,
		);
	}
	if (market && market.RecoveryPending) {
		add(
			"legacy-pending",
			48,
			<Ui.Text
				value="Claim pending. Refresh to retry."
				size={14}
				wrap={true}
				color={Palette.mango}
				sizeConstraint={UDim2.fromScale(1, 1)}
			/>,
		);
	}
	add(
		"search",
		48,
		<Ui.SearchField
			value={query}
			onChange={setQuery}
			placeholder="Search supplies or rewards"
			size={UDim2.fromScale(1, 1)}
			accent={Palette.violet}
			reducedMotion={props.reducedMotion}
		/>,
	);
	const columns = math.max(1, math.min(4, math.floor((width + 6) / 130)));
	add(
		"categories",
		categoriesH,
		<Ui.SegmentedTabs
			options={CATEGORIES}
			value={category}
			columns={columns}
			gap={6}
			size={UDim2.fromScale(1, 1)}
			reducedMotion={props.reducedMotion}
			onChange={setCategory}
			accent={Palette.violet}
		/>,
	);
	if (!chrome.stack && bazaarTab !== "Buy") {
		const emptySections: Section[] = [
			{
				id: "tab-empty",
				height: 160,
				element: (
					<Ui.EmptyState
						icon="Shop"
						title={bazaarTab === "Sell" ? "Nothing to sell here" : "No stall yet"}
						body="The bazaar sells supplies from the market. Player listings aren't part of the game yet."
						accent={Palette.violet}
						compact={true}
						size={UDim2.fromScale(1, 1)}
					/>
				),
			},
		];
		return <PageScaffold hostRef={scrollRef} sections={emptySections} gap={12} tailPad={bazaarTail} scrollBarColor={Palette.violet} />;
	}
	if (category === "Requests") {
		const procure = market && market.Procure;
		const canProcure = reputation && reputation.CanProcure;
		let status: string;
		if (!market) {
			status = "Opening the supply ledger...";
		} else if (procure && procure.Name !== undefined) {
			status =
				procure.State === "Pending"
					? `${procure.Name} requested: next shipment, held 24 hours.`
					: procure.State === "Listed"
						? `${procure.Name} is on your shelf at 20% off until bought or lapsed.`
						: procure.State === "Filled"
							? `Your request for ${procure.Name} was filled. Place a new request any time.`
							: `${procure.Name} lapsed. Request again for a new 24-hour hold.`;
		} else {
			status = canProcure
				? "No open request. Pick a supply below: next shipment, held 24 hours."
				: `Requests open at ${(reputation && reputation.ProcureTier) ?? "Regular"} standing. Every unit bought counts.`;
		}
		const rph = chrome.stack === true;
		add(
			"request-status",
			panelHeight(rph, headingBlock(rph) + rowHeight(rph, true)),
			<MockPanel size={UDim2.fromScale(1, 1)} phone={rph} accent={Palette.violet} reducedMotion={props.reducedMotion}>
				<PanelHeading icon="Mail" title="Requests" note={canProcure ? "Open" : "Locked"} accent={Palette.violet} phone={rph} layoutOrder={0} />
				<MockRow phone={rph} icon="Info" accent={Palette.violet} title={procure && procure.Name !== undefined ? procure.Name : "No open request"} sub={status} layoutOrder={1} />
			</MockPanel>,
		);
		if (procure && procure.Name !== undefined && procure.State !== "Filled" && procure.State !== "Expired") {
			add(
				"request-cancel",
				48,
				<Ui.Button
					text="Cancel request"
					size={UDim2.fromScale(1, 1)}
					color={SEC}
					disabled={busy}
					reducedMotion={props.reducedMotion}
					onClick={() => request("RequestProcurement", { Id: "" })}
				/>,
			);
		}
		let shown = 0;
		for (const entry of market ? (market.Catalog ?? []) : []) {
			if (query !== "" && !plainFind(entry.Name.lower(), query.lower())) {
				continue;
			}
			shown += 1;
			const current =
				procure !== undefined && procure.Id === entry.Id && (procure.State === "Pending" || procure.State === "Listed");
			const rowPhone = chrome.stack === true;
			add(
				"request-" + entry.Id,
				rowHeight(rowPhone, true),
				<MockRow
					phone={rowPhone}
					icon="Shop"
					accent={ACCENTS[entry.Category] ?? Palette.violet}
					title={entry.Name}
					sub={entry.Category}
					outline={current ? Palette.violet : undefined}
					rightWidth={120}
					right={
						<MockBtn
							text={current ? "Requested" : "Request"}
							sm={true}
							width={120}
							accent={Palette.violet}
							disabled={busy || current || !canProcure}
							reducedMotion={props.reducedMotion}
							onClick={() => request("RequestProcurement", { Id: entry.Id })}
						/>
					}
				/>,
			);
		}
		if (shown === 0 && market) {
			add(
				"request-empty",
				112,
				<Ui.EmptyState
					icon="Search"
					title="Nothing here"
					body="No supplies match that search. Try another word or clear the filter."
					accent={Palette.violet}
					compact={true}
					size={UDim2.fromScale(1, 1)}
				/>,
			);
		}
		return <PageScaffold hostRef={scrollRef} sections={sections} gap={12} tailPad={bazaarTail} scrollBarColor={Palette.violet} />;
	}
	if (category === "History") {
		const history = market ? (market.History ?? []) : [];
		let shown = 0;
		history.forEach((entry, i) => {
			const name = entry.Name;
			if (query !== "" && !plainFind(name.lower(), query.lower())) {
				return;
			}
			shown += 1;
			add(
				"purchase-" + (i + 1),
				rowHeight(chrome.stack === true, true),
				<MockRow
					phone={chrome.stack === true}
					icon="Shop"
					accent={Palette.violet}
					title={`${entry.Quantity} × ${name}`}
					sub={`${DateTime.fromUnixTimestamp(entry.At).FormatUniversalTime("MMM D, HH:mm", "en-us")} UTC`}
					value={`${Format.compactNumber(entry.Cost)} flux`}
				/>,
			);
		});
		if (shown === 0) {
			add(
				"history-empty",
				96,
				<Ui.Text
					value={
						history.size() === 0
							? "Your completed purchases will appear here. The last 50 orders are kept after rejoining."
							: "No purchases match that search."
					}
					size={15}
					wrap={true}
					sizeConstraint={UDim2.fromScale(1, 1)}
				/>,
			);
		}
		return <PageScaffold hostRef={scrollRef} sections={sections} gap={12} tailPad={bazaarTail} scrollBarColor={Palette.violet} />;
	}
	const optionColumns = math.max(1, math.min(3, math.floor((width + 6) / 120)));
	const optionHeight = optionsH;
	add(
		"sort",
		optionHeight,
		<Ui.SegmentedTabs
			options={[
				{ id: "Discount", label: "Best deals" },
				{ id: "Price", label: "Lowest price" },
				{ id: "Name", label: "By name" },
			]}
			value={sort}
			onChange={setSort}
			columns={optionColumns}
			gap={6}
			size={UDim2.fromScale(1, 1)}
			reducedMotion={props.reducedMotion}
		/>,
	);
	add(
		"quantity",
		optionHeight,
		<Ui.SegmentedTabs
			options={[
				{ id: "One", label: "Buy 1" },
				{ id: "Three", label: "Buy 3" },
				{ id: "Shelf", label: "Buy stock" },
			]}
			value={amount}
			onChange={setAmount}
			columns={optionColumns}
			gap={6}
			size={UDim2.fromScale(1, 1)}
			reducedMotion={props.reducedMotion}
		/>,
	);
	let selected: Offer | undefined;
	for (const offer of market ? market.Offers : []) {
		if (offer.Id === inspected) {
			selected = offer;
			break;
		}
	}
	// desktop with room: the inspection (detail + per-unit comparison) sits in a right-hand column
	// beside the shelf instead of pushing the shelf below it
	const inspectStart = sections.size();
	const plan = splitColumns(width, 340, 12);
	if (selected) {
		const chosen = selected;
		const iph = chrome.stack === true;
		const holdings: Array<{ Label: string; Count: unknown }> = [];
		for (const entry of chosen.Holdings ?? []) {
			holdings.push(entry);
		}
		const quantity = amount === "Three" ? 3 : amount === "Shelf" ? math.clamp(chosen.Left, 1, 8) : 1;
		const [identity] = supplyUnit(chosen.Reward);
		const comparisons: Array<{ Offer: Offer; Units: number; UnitPrice: Flux }> = [];
		if (identity !== undefined) {
			for (const offer of market!.Offers) {
				const [other, units] = supplyUnit(offer.Reward);
				if (other === identity) {
					comparisons.push({ Offer: offer, Units: units!, UnitPrice: orderTotal(offer.Price, 1 / units!) });
				}
			}
		}
		comparisons.sort((a, b) => {
			const comparison = Format.compareFlux(a.UnitPrice, b.UnitPrice);
			return comparison !== 0 ? comparison < 0 : a.Offer.Name < b.Offer.Name;
		});
		// 06 side panel: heading, .row facts, held amounts, close
		const rowsN = 3 + math.max(1, holdings.size());
		const ig = iph ? 8 : 12;
		add(
			"inspection-heading",
			panelHeight(iph, headingBlock(iph) + rowsN * rowHeight(iph) + (rowsN - 1) * ig + ig + (iph ? TapTarget : 44)),
			<MockPanel size={UDim2.fromScale(1, 1)} phone={iph} accent={Palette.violet} glow={Palette.violet} reducedMotion={props.reducedMotion}>
				<PanelHeading icon="Search" title={chosen.Name} note="Inspecting" accent={Palette.violet} phone={iph} layoutOrder={0} />
				<MockRow phone={iph} icon="Gift" accent={Palette.violet} title="Per unit" value={Format.formatReward(chosen.Reward)} layoutOrder={1} />
				<MockRow phone={iph} icon="Flux" accent={Palette.mango} title={`Order of ${quantity}`} value={`${Format.compactNumber(orderTotal(chosen.Price, quantity))} flux`} layoutOrder={2} />
				<MockRow phone={iph} icon="Timer" accent={Palette.violet} title="Your limit" value={`${chosen.Left} of ${chosen.Stock} this hour`} layoutOrder={3} />
				{holdings.size() > 0 ? (
					holdings.map((entry, index) => (
						<MockRow phone={iph} icon="Vault" accent={Palette.creamSoft} title={`Held · ${entry.Label}`} value={Format.compactNumber(entry.Count as Flux)} layoutOrder={4 + index} />
					))
				) : (
					<MockRow phone={iph} icon="Vault" accent={Palette.muted} title="Held" value="Loading…" layoutOrder={4} />
				)}
				<MockBtn text="Close inspection" sec={true} fill={true} phone={iph} reducedMotion={props.reducedMotion} onClick={() => setInspected(undefined)} layoutOrder={99} />
			</MockPanel>,
		);
		add(
			"comparison-heading",
			HEADING_SECTION_H,
			<HeadingSection
				icon="StarGrid"
				title="Per unit"
				note={comparisons.size() > 1 ? "Same supply, every pack size" : "Nothing comparable this shipment"}
				accent={Palette.violet}
				phone={iph}
			/>,
		);
		for (const comparison of comparisons) {
			const offer = comparison.Offer;
			add(
				"compare-" + offer.Id,
				rowHeight(iph, true),
				<MockRow
					phone={iph}
					icon="Shop"
					accent={Palette.violet}
					title={offer.Name + (offer.Id === chosen.Id ? " (selected)" : "")}
					sub={`×${comparison.Units} · ${offer.Left} left`}
					value={`${Format.compactNumber(comparison.UnitPrice)}/unit`}
					outline={offer.Id === chosen.Id ? Palette.violet : undefined}
				/>,
			);
		}
	} else if (inspected !== undefined) {
		add(
			"inspection-expired",
			96,
			<Ui.Text
				value="Sold out. Pick another."
				size={14}
				wrap={true}
				color={Palette.muted}
				sizeConstraint={UDim2.fromScale(1, 1)}
			/>,
		);
	}
	const inspectEnd = sections.size();
	const offers: Offer[] = [];
	for (const offer of market ? market.Offers : []) {
		const text = (offer.Name + " " + Format.formatReward(offer.Reward)).lower();
		if (
			(category === "All" || offer.Category === category || (category === "Saved" && saved[offer.Id])) &&
			(query === "" || plainFind(text, query.lower()))
		) {
			offers.push(offer);
		}
	}
	offers.sort((a, b) => {
		if (sort === "Price") {
			const comparison = Format.compareFlux(a.Price, b.Price);
			if (comparison !== 0) {
				return comparison < 0;
			}
		} else if (sort === "Discount" && a.Discount !== b.Discount) {
			return a.Discount > b.Discount;
		}
		return a.Name < b.Name;
	});
	const phone = chrome.stack === true;
	const cardHeight = offerRowHeight(phone);
	const gap = phone ? 10 : L.Row2.y - L.Row.y - L.Row.h;
	const shelfColumns = (_shelfW: number) => 1;
	// the shelf's height only depends on the offer count and the column count, so it can be worked out
	// exactly at the split width before deciding; split only when it roughly matches the inspection column
	const shelfHeightAt = (shelfW: number) => {
		if (offers.size() === 0) {
			return market ? 100 : 0;
		}
		const rows = math.ceil(offers.size() / shelfColumns(shelfW));
		return rows * cardHeight + (rows - 1) * gap;
	};
	const inspectH = stackHeight(
		sections.filter((_, index) => index >= inspectStart && index < inspectEnd).map((section) => section.height),
		12,
	);
	const splitInspect =
		plan.split &&
		selected !== undefined &&
		inspectEnd > inspectStart &&
		columnsBalanced(inspectH, shelfHeightAt(plan.main));
	const shelfWidth = splitInspect ? plan.main : width;
	const cardColumns = shelfColumns(shelfWidth);
	for (let first = 0; first < offers.size(); first += cardColumns) {
		const cards: Record<string, React.Element> = {};
		for (let offset = 0; offset <= cardColumns - 1; offset++) {
			const offer = offers[first + offset];
			if (!offer) {
				break;
			}
			const quantity = amount === "Three" ? 3 : amount === "Shelf" ? math.clamp(offer.Left, 1, 8) : 1;
			const total = orderTotal(offer.Price, quantity);
			const enough = Format.gteFlux(props.state.Cash as Flux, total);
			cards[offer.Id] = (
				<BazaarOfferCard
					key={offer.Id}
					offer={offer}
					quantity={quantity}
					total={total}
					enough={enough}
					saved={saved[offer.Id] === true}
					inspected={inspected === offer.Id}
					busy={busy}
					expired={expired}
					reducedMotion={props.reducedMotion}
					phone={phone}
					size={new UDim2(1 / cardColumns, (-gap * (cardColumns - 1)) / cardColumns, 1, 0)}
					position={new UDim2(offset / cardColumns, (gap * offset) / cardColumns, 0, 0)}
					onToggleSave={() => {
						request("SetMarketFavorite", { Id: offer.Id, Saved: saved[offer.Id] !== true });
					}}
					onInspect={() => setInspected(offer.Id)}
					onBuy={() =>
						request("BazaarPlay", {
							Game: "Market",
							Pick: offer.Id,
							Bucket: market!.Bucket,
							Quantity: quantity,
							UnitPrice: offer.Price,
							Currency: "Flux",
							RequestId: HttpService.GenerateGUID(false),
							Rotation: market!.Rotation,
						})
					}
				/>
			);
		}
		add(
			"shelf-" + (first + 1),
			cardHeight,
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				{cards}
			</frame>,
		);
	}
	if (offers.size() === 0 && market) {
		add(
			"empty",
			100,
			<Ui.Text
				value={
					category === "Saved"
						? "No saved supplies on this shipment. Save an item to keep it in view."
						: "No supplies match those filters."
				}
				size={15}
				wrap={true}
				sizeConstraint={UDim2.fromScale(1, 1)}
			/>,
		);
	}
	if (splitInspect) {
		const head: Section[] = [];
		const inspection: Section[] = [];
		const shelf: Section[] = [];
		sections.forEach((section, index) => {
			(index < inspectStart ? head : index < inspectEnd ? inspection : shelf).push(section);
		});
		const sideH = stackHeight(inspection.map((section) => section.height), 12);
		const mainH = stackHeight(shelf.map((section) => section.height), 12);
		const rowH = math.max(sideH, mainH);
		head.push({
			id: "shelf-split",
			height: rowH,
			element: (
				<SplitColumns
					name="BazaarSplit"
					height={rowH}
					plan={plan}
					sideOnRight={true}
					side={<StackBlocks gap={12} blocks={inspection} />}
					main={<StackBlocks gap={12} blocks={shelf} />}
				/>
			),
		});
		return <PageScaffold hostRef={scrollRef} sections={head} gap={12} tailPad={bazaarTail} scrollBarColor={Palette.violet} />;
	}
	return <PageScaffold hostRef={scrollRef} sections={sections} gap={12} tailPad={bazaarTail} scrollBarColor={Palette.violet} />;
}

export = { BazaarView };
