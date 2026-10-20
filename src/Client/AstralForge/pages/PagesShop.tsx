// PagesShop.luau — compiled page bundle for the Shop tab.
// Members are required lazily: PagesShop("WheelView") only pays for that page's code.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import * as Fmt from "../CoreKit/format";
import { InteractionFeedback } from "../CoreKit/interaction";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Layout, Palette, scrollTail, surfaceGradient, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { FlexGrid, useShopColumns } from "../MotionKit/flexbox";
import { easeOutCubic, useBoatTween, useStagger, useViewport, useWallClock } from "../MotionKit/motion";
import { Icon, rewardIconKind } from "../ArtKit/Icon";
import BrowseModel = require("../BrowseModel");
import ElementFxModule = require("../ElementFx");
import PrizeWheel = require("../PrizeWheel");
import JuiceFx = require("../JuiceFx");
import CrateAppearance = require("../../../Shared/AstralForge/Shared/CrateAppearance");
import CrateRevealStageModule = require("./CrateRevealStage");
import {
	Component,
	Components,
	loadAudio,
	loadBrowse,
	loadPageScaffold,
	loadUi,
	luauKit,
	sharedModule,
} from "./luauDeps";

const MarketplaceService = game.GetService("MarketplaceService");
const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

const { ElementFx } = ElementFxModule;

// Still-Luau dependencies are pulled through their kits like the bundled code did.
const { PurchaseOverlay } = luauKit<{ PurchaseOverlay: Component }>("UiOverlays", "purchaseOverlay");
const PageScaffold = loadPageScaffold();
const {
	Badge,
	Button,
	EmptyState,
	IconTile,
	Meter,
	Panel,
	SectionLabel,
	SegmentedTabs,
	Text,
} = loadUi() as Components;
const { FlatList } = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList");
const Audio = loadAudio();
const { CrateModel, skinAccent } = luauKit<{
	CrateModel: Component;
	skinAccent: (this: void, id: string) => Color3;
}>("UiCore", "crateModel");
const { PrismAura, isAscended } = luauKit<{
	PrismAura: Component;
	isAscended: (this: void, rarity: string) => boolean;
}>("UiCore", "prismFx");
const Browse = loadBrowse();

const SharedData = sharedModule<(name: string) => unknown>("SharedData");

interface Reward extends Fmt.Reward {
	[key: string]: unknown;
}

interface DevProduct {
	Key: string;
	Name: string;
	Description: string;
	ProductId: number;
	PriceLabel: string;
	StudioPrice: Fmt.Flux;
	Reward?: Reward;
	Accent?: number[];
	Icon?: string;
}

interface GamePass {
	Key: string;
	Name: string;
	Description: string;
	PassId: number;
	PriceLabel: string;
	StudioPrice: Fmt.Flux;
	ProductionBonus?: number;
	CapacityBonus?: number;
	Accent?: number[];
	Icon?: string;
}

interface MonetizationCatalog {
	DevProducts: DevProduct[];
	GamePasses: GamePass[];
	Error?: string;
}

interface SkinDef {
	Id: string;
	Name: string;
	Tier?: string;
	Blurb: string;
	Description?: string;
	Rarity?: string;
	Accent?: number[];
	Glow?: number[];
	Vfx?: string;
	Default?: boolean;
	DailyOnly?: boolean;
	Price?: { Currency: string; Amount: number };
}

interface DailyOffer {
	Id: string;
	Name?: string;
	Kind: string;
	Slot: number;
	CrateId?: string;
	Amount?: number;
	Minutes?: number;
	BoostId?: string;
	Rarity?: string;
	SkinId?: string;
	Currency: string;
	Price: number;
	Stock?: number;
	Weight?: number;
	Deal?: boolean;
}

interface ShopCatalogApi {
	SLOTS: number;
	DEAL_DISCOUNT: number;
	DAY_SECONDS: number;
	SKINS: SkinDef[];
	DEFAULT_SKIN: string;
	skin(this: void, id: unknown): SkinDef | undefined;
	day(this: void, now: number): number;
	secondsLeft(this: void, now: number): number;
	roll(this: void, userId: number, day: number, ownedSkins?: unknown): DailyOffer[];
	remaining(this: void, offer: DailyOffer, bought: unknown): number;
}

interface RelicDefinition {
	Id: string;
	Name: string;
	Description?: string;
	Rarity: string;
	Slot?: string;
	EffectKind?: string;
	[key: string]: unknown;
}

interface RelicInstance {
	DefinitionId?: unknown;
	Stars?: unknown;
	[key: string]: unknown;
}

interface RelicSystemApi {
	ORDER: string[];
	stars(this: void, instance: unknown): number;
	fusionPair(this: void, inventory: unknown, equipped: unknown, definitionId: string, maxStars?: number): unknown;
	codex(this: void, discovered: unknown, items: unknown): Record<string, { found: number; total: number }>;
	odds(this: void, weights?: unknown): { rarity: string; chance: number }[];
	chanceText(this: void, chance: number): string;
}

const ShopCatalog = SharedData("ShopCatalog") as ShopCatalogApi;
const RelicSystem = SharedData("RelicSystem") as RelicSystemApi;

interface CrateConfig {
	Id: string;
	Name: string;
	Description?: string;
	Color?: unknown;
	Weights?: Record<string, number>;
	PityAfter?: number;
	PityRarity?: string;
}

interface ItemsConfig {
	Crates?: CrateConfig[];
	Rarities?: Record<string, { Color?: Color3 }>;
	Definitions?: RelicDefinition[];
	CodexBonus?: Record<string, number>;
	MaxStars?: number;
	StarBonus?: number;
}

interface ArtifactDef {
	Id: string;
	Name: string;
	Description: string;
	Rarity: string;
	Color?: Color3;
	Element?: string;
	EffectKind?: string;
	EffectPerLevel?: number;
	ShopOnly?: boolean;
}

interface OwnedArtifact {
	Level?: number;
	Fragments?: number;
}

interface ArtifactPrice {
	Refill?: number;
	Stardust?: number;
	Fragments?: number;
}

interface OperationsConfig {
	Artifacts?: ArtifactDef[];
	ArtifactShop?: Record<string, ArtifactPrice>;
}

interface WheelReward {
	Id: string;
	Name?: string;
	Rarity: string;
	Weight?: number;
	Color?: Color3;
	ShortLabel?: string;
	Reward?: Reward;
}

interface WheelConfig {
	Rewards: WheelReward[];
	PityAfter?: number;
	PityRarity?: string;
	CooldownSeconds: number;
}

interface ShopConfig {
	[key: string]: unknown;
	Items?: ItemsConfig;
	Boosts?: Record<string, { Name?: string }>;
	Operations?: OperationsConfig;
	Wheel: WheelConfig;
	ClientPageGuides?: { Wheel?: { PityArmed?: string; Ready?: string } };
}

const EMPTY_CONFIG = {} as ShopConfig;

interface DailyShopState {
	Day?: number;
	Owned?: unknown;
	Bought?: Record<number, number>;
}

interface CosmeticsState {
	CrateSkins?: Record<string, boolean>;
	CrateSkin?: string;
}

interface ItemsState {
	Keys?: Record<string, number>;
	Pity?: Record<string, number>;
	Discovered?: Record<string, boolean>;
	Inventory?: RelicInstance[] | Record<string, RelicInstance>;
	Equipped?: unknown;
	CodexBonus?: number;
}

interface WheelReceipt {
	PrizeIndex?: unknown;
	PrizeId?: unknown;
	ExpectedSpin?: unknown;
}

interface WheelHistoryEntry {
	PrizeId?: string;
	At?: number;
	Pity?: boolean;
}

interface WheelState {
	LastReceipt?: WheelReceipt;
	CanSpin?: boolean;
	Spins?: number;
	FreeSpins?: number;
	PityMisses?: number;
	PityAfter?: number;
	PityArmed?: boolean;
	ReadyAt?: number;
	History?: unknown;
}

interface ShopState {
	[key: string]: unknown;
	Shop?: { OwnedPasses?: Record<string, boolean> };
	SocialRewards?: { CreatorFollowClaimed?: boolean; CreatorName?: string };
	DailyShop?: DailyShopState;
	Cosmetics?: CosmeticsState;
	Items?: ItemsState;
	Command?: { Artifacts?: Record<string, OwnedArtifact> };
	Wheel?: WheelState;
}

interface CrateRevealRequest {
	crateId: string;
	crateName: string;
	accent?: Color3;
	rolls: unknown[];
}

interface DispatchResponse {
	[key: string]: unknown;
	ok?: boolean;
	error?: string;
	message?: string;
}

type Dispatch = (
	this: void,
	action: string,
	payload?: unknown,
	reply?: (this: void, response: DispatchResponse) => void,
) => void;

const h = React.createElement as unknown as (
	component: unknown,
	props?: Record<string, unknown> | undefined,
	...children: unknown[]
) => React.ReactElement;

const SHOP_TABS = ["Featured", "Passes", "Supplies", "Codes"];
const SHOP_TAB_TIPS: Record<string, string> = {
	Featured: "What's on sale.",
	Passes: "Permanent upgrades. Buy once, keep forever.",
	Supplies: "One-time packs of flux, dust and boosts.",
	Codes: "Type a promo code for a free reward.",
};
const PRODUCT_PENDING_FAILSAFE = 40;
const REDEEM_DEBOUNCE = 0.85;

function loadMonetization(): MonetizationCatalog {
	const astral = ReplicatedStorage.WaitForChild("AstralForge", 12);
	const shared = astral !== undefined ? astral.WaitForChild("Shared", 6) : undefined;
	const catalogModule = shared !== undefined ? shared.WaitForChild("SharedData", 6) : undefined;
	if (catalogModule === undefined || !catalogModule.IsA("ModuleScript")) {
		ClientLog.warn("shop", "shop catalog missing");
		return {
			DevProducts: [],
			GamePasses: [],
			Error: "The shop couldn't load. Close it and try again.",
		};
	}
	const [loaded, result] = pcall(() => (require(catalogModule) as (member: string) => unknown)("MonetizationConfig"));
	if (!loaded || !typeIs(result, "table") || !typeIs((result as MonetizationCatalog).DevProducts, "table") || !typeIs((result as MonetizationCatalog).GamePasses, "table")) {
		ClientLog.warn("shop", `couldn't load shop catalog: ${tostring(result)}`);
		return {
			DevProducts: [],
			GamePasses: [],
			Error: "The shop couldn't load. Close it and try again.",
		};
	}
	return result as MonetizationCatalog;
}

const EMPTY_CATALOG: MonetizationCatalog = {
	DevProducts: [],
	GamePasses: [],
};

function useMonetization(): MonetizationCatalog {
	const [catalog, setCatalog] = React.useState<MonetizationCatalog>(EMPTY_CATALOG);
	React.useEffect(() => {
		let alive = true;
		const worker = task.spawn(() => {
			const loaded = loadMonetization();
			if (alive) {
				setCatalog(loaded);
			}
		});
		return () => {
			alive = false;
			pcall(() => task.cancel(worker));
		};
	}, []);
	return catalog;
}

const SCROLL_PAD = 16 + 16;
const TAB_LABELS: Record<string, string> = {
	Featured: "Picks",
	Passes: "Passes",
	Supplies: "Packs",
	Codes: "Codes",
};
const SHOP_TAB_OPTIONS = SHOP_TABS.map((id) => ({
	id: id,
	label: TAB_LABELS[id],
}));

function accentOf(rgb: number[] | undefined): Color3 {
	return Color3.fromRGB(rgb?.[0] ?? 255, rgb?.[1] ?? 255, rgb?.[2] ?? 255);
}

function iconOf(name: string | undefined): string {
	const known = ["Dust", "Flux", "Forge", "Core", "StarGrid", "Research", "Vault", "Shop", "Gift", "Chat"];
	for (const entry of known) {
		if (entry === name) {
			return entry;
		}
	}
	return "Shop";
}

function rewardLine(reward: Reward | undefined): string {
	const parts: string[] = [];
	if (reward?.Cash !== undefined) {
		parts.push(`${reward.Cash} flux`);
	}
	if (reward?.Stardust !== undefined) {
		parts.push(`${reward.Stardust} stardust`);
	}
	if (reward?.Cores !== undefined) {
		parts.push(`${reward.Cores} cores`);
	}
	if (reward?.Boost !== undefined) {
		parts.push(`${reward.Boost} boost`);
	}
	if (reward?.Signals !== undefined) {
		parts.push(`${reward.Signals} signals`);
	}
	if (reward?.CashMinutes !== undefined) {
		parts.push(`${reward.CashMinutes}m of production`);
	}
	return parts.size() > 0 ? parts.join(" · ") : "Bonus stash";
}

function passBenefitLine(pass: GamePass): string {
	const parts: string[] = [];
	if (pass.ProductionBonus !== undefined) {
		parts.push(`+${math.floor(pass.ProductionBonus * 100)}% output`);
	}
	if (pass.CapacityBonus !== undefined) {
		parts.push(`+${math.floor(pass.CapacityBonus * 100)}% vault`);
	}
	if (pass.Key === "AutoSalvage") {
		parts.push("Configurable relic recycling");
	}
	return parts.size() > 0 ? parts.join(" · ") : "Permanent account upgrade";
}

function priceText(label: Fmt.Flux, studioPrice: Fmt.Flux, offerId: number): string {
	if (offerId > 0) {
		return `${label}${studioPrice}`;
	}
	if (RunService.IsStudio()) {
		return `Test · ${studioPrice}`;
	}
	return "Unavailable";
}

interface TabPaneProps {
	reducedMotion?: boolean;
	height: number;
	children?: React.ReactNode;
}

function TabPane(props: TabPaneProps) {
	const reducedMotion = props.reducedMotion;
	const height = props.height;
	const children = props.children;
	const enter = useBoatTween(1, reducedMotion ? 0.01 : 0.12, reducedMotion, easeOutCubic, 0);
	const slide = enter.map((amount) => new UDim2(0, 0, 0, math.round((1 - math.clamp(amount, 0, 1)) * 10)));
	return (
		<frame Size={new UDim2(1, 0, 0, height)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<frame Size={UDim2.fromScale(1, 1)} Position={slide} BackgroundTransparency={1} BorderSizePixel={0}>
				{children}
			</frame>
		</frame>
	);
}

interface OfferTileProps {
	title: string;
	detail: string;
	meta: string;
	accent: Color3;
	icon: string;
	cta: string;
	disabled?: boolean;
	owned?: boolean;
	onClick?: () => void;
	layoutOrder?: number;
	reducedMotion?: boolean;
	staggerIndex?: number;
	packed?: boolean;
}

function OfferTile(props: OfferTileProps) {
	const title = props.title;
	const detail = props.detail;
	const meta = props.meta;
	const accent = props.accent;
	const icon = props.icon;
	const cta = props.cta;
	const disabled = props.disabled;
	const owned = props.owned;
	const onClick = props.onClick;
	const layoutOrder = props.layoutOrder;
	const reducedMotion = props.reducedMotion;
	const staggerIndex = props.staggerIndex;
	const packed = props.packed ?? false;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = packed || chrome.contentStack;
	const reveal = useStagger(staggerIndex ?? 0, reducedMotion, 0.036, 0.26);
	const canBuy = owned !== true && !disabled;
	const rowH = packed ? 244 : stack ? 184 : 168;
	const ctaH = stack ? TapTarget : 44;
	return (
		<frame
			Size={packed ? UDim2.fromScale(1, 1) : new UDim2(1, -4, 0, rowH)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ClipsDescendants={false}
		>
			{h(Panel, {
				size: UDim2.fromScale(1, 1),
				accent: accent,
				background: Palette.panelRaised,
				padding: packed ? 12 : 16,
				reveal: reveal,
				interactive: owned !== true,
				reducedMotion: reducedMotion,
				clips: false,
			},
				<frame
					Size={UDim2.fromOffset(50, 50)}
					Position={UDim2.fromOffset(0, stack ? 0 : 8)}
					BackgroundColor3={darken(accent, 0.32)}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					<uicorner CornerRadius={new UDim(0, 12)} />
					<uistroke Color={accent} Thickness={1.5} Transparency={0.28} />
					{h(Icon, {
						kind: icon,
						color: Palette.cream,
						accent: accent,
						size: 32,
						position: UDim2.fromOffset(9, 9),
						reducedMotion: reducedMotion,
						spin: false,
					})}
				</frame>,
				<frame
					Size={
						stack
							? new UDim2(1, packed ? 0 : -64, 0, packed ? 78 : 86)
							: new UDim2(1, -174, 0, 96)
					}
					Position={UDim2.fromOffset(packed ? 0 : 64, packed ? 56 : stack ? 0 : 6)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={true}
				>
					{h(Text, {
						value: title,
						size: packed ? 15 : stack ? 17 : 16,
						color: Palette.cream,
						weight: Enum.FontWeight.Heavy,
						fit: true,
						minSize: 11,
						sizeConstraint: new UDim2(1, 0, 0, 22),
					})}
					{h(Text, {
						value: detail,
						size: stack ? chrome.labelText : 11,
						color: Palette.creamSoft,
						wrap: true,
						position: UDim2.fromOffset(0, 24),
						sizeConstraint: new UDim2(1, 0, 0, packed ? 32 : 38),
					})}
					{h(Text, {
						value: meta,
						size: stack ? chrome.labelText : 11,
						color: accent,
						weight: Enum.FontWeight.Bold,
						fit: false,
						position: UDim2.fromOffset(0, packed ? 58 : 66),
						sizeConstraint: new UDim2(1, 0, 0, 16),
					})}
				</frame>,
				owned === true
					? h(Badge, {
						value: "OWNED",
						accent: Palette.green,
						filled: true,
						position: new UDim2(stack ? 0 : 1, stack ? 0 : -150, 1, -(ctaH + 4)),
						size: stack ? new UDim2(1, 0, 0, ctaH) : UDim2.fromOffset(136, ctaH),
					})
					: h(
						"frame",
						{
							Name: "ShopBuyCta",
							Size: stack ? new UDim2(1, 0, 0, ctaH) : UDim2.fromOffset(148, ctaH),
							Position: new UDim2(stack ? 0 : 1, stack ? 0 : -158, 1, -(ctaH + 4)),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
						},
						h(Button, {
							text: cta,
							icon: disabled ? "Lock.6" : "Shop.4",
							onClick: onClick,
							color: disabled ? Palette.panelSoft : accent,
							textColor: disabled ? Palette.creamSoft : Palette.ink,
							size: UDim2.fromScale(1, 1),
							disabled: !canBuy,
							reducedMotion: reducedMotion,
							highlight: canBuy,
							selectable: canBuy,
						}),
					),
			)}
		</frame>
	);
}

interface ShopViewProps {
	state: ShopState;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	onPurchasePresentationChange?: (open: boolean) => void;
}

interface OfferRow {
	Id: string;
	cells: { kind: string; key: string; pass?: GamePass; product?: DevProduct }[];
}

function ShopView(props: ShopViewProps) {
	const state = props.state;
	const dispatch = props.dispatch;
	const reducedMotion = props.reducedMotion;
	const onPurchasePresentationChange = props.onPurchasePresentationChange;
	const monetization = useMonetization();
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const stack = chrome.contentStack;
	const [tab, setTab] = React.useState("Featured");
	const [code, setCode] = React.useState("");
	const [codeFeedback, setCodeFeedback] = React.useState("");
	const [followFeedback, setFollowFeedback] = React.useState("");
	const [followBusy, setFollowBusy] = React.useState(false);
	const [busy, setBusy] = React.useState(false);
	const [banner, setBanner] = React.useState("Buy a pack, a pass, or enter a code.");
	const [purchasePhase, setPurchasePhase] = React.useState("hidden");
	const [purchaseDetail, setPurchaseDetail] = React.useState<string | undefined>(undefined);
	const heroReveal = useStagger(0, softMotion);
	const catalogReveal = useStagger(1, softMotion);
	const owned = state.Shop?.OwnedPasses ?? {};
	const pendingLabel = React.useRef("Item");
	const pendingOffer = React.useRef<{ kind: string; id: number } | undefined>(undefined);
	const failsafe = React.useRef<thread | undefined>(undefined);
	const busyRef = React.useRef(false);
	const sessionRef = React.useRef(0);
	const mountedRef = React.useRef(true);
	const lastRedeemAt = React.useRef(0);
	const purchasePhaseRef = React.useRef("hidden");
	purchasePhaseRef.current = purchasePhase;
	const purchasePresentationCallback = React.useRef(onPurchasePresentationChange);
	purchasePresentationCallback.current = onPurchasePresentationChange;
	React.useEffect(() => {
		purchasePresentationCallback.current?.(purchasePhase !== "hidden");
	}, [purchasePhase]);
	React.useEffect(() => {
		return () => {
			purchasePresentationCallback.current?.(false);
		};
	}, []);
	const setBusyGate = (value: boolean) => {
		busyRef.current = value;
		setBusy(value);
	};
	const clearFailsafe = () => {
		if (failsafe.current !== undefined) {
			pcall(() => task.cancel(failsafe.current!));
			failsafe.current = undefined;
		}
	};
	const dismissPurchase = React.useCallback(() => {
		clearFailsafe();
		sessionRef.current += 1;
		pendingOffer.current = undefined;
		setPurchasePhase("hidden");
		setPurchaseDetail(undefined);
		setBusyGate(false);
	}, []);
	const openPending = (label: string, seconds?: number) => {
		const timeout = seconds ?? PRODUCT_PENDING_FAILSAFE;
		pendingLabel.current = label;
		purchasePresentationCallback.current?.(true);
		const session = sessionRef.current + 1;
		sessionRef.current = session;
		setPurchasePhase("pending");
		setPurchaseDetail(undefined);
		clearFailsafe();
		failsafe.current = task.delay(timeout, () => {
			failsafe.current = undefined;
			if (!mountedRef.current || sessionRef.current !== session) {
				return;
			}
			setPurchasePhase("fail");
			setBusyGate(false);
			setBanner("That took too long. Try again.");
		});
	};
	const finishPurchase = (ok: boolean, detail?: string) => {
		clearFailsafe();
		sessionRef.current += 1;
		pendingOffer.current = undefined;
		setPurchasePhase(ok ? "success" : "fail");
		setPurchaseDetail(detail);
		setBusyGate(false);
	};
	React.useEffect(() => {
		mountedRef.current = true;
		dispatch("SyncShop");
		const productConn = MarketplaceService.PromptProductPurchaseFinished.Connect((userId, productId, isPurchased) => {
			if (userId !== Players.LocalPlayer!.UserId) {
				return;
			}
			const pending = pendingOffer.current;
			if (pending === undefined || pending.kind !== "product" || pending.id !== productId) {
				return;
			}
			if (isPurchased) {
				const session = sessionRef.current;
				const label = pendingLabel.current;
				dispatch("SyncShop", {}, (response) => {
					if (sessionRef.current !== session) {
						return;
					}
					finishPurchase(response.ok !== false);
					setBanner(
						response.ok === false
							? (response.error ?? "Purchase pending. Roblox is still confirming it.")
							: `${label} bought.`,
					);
				});
			} else {
				finishPurchase(false);
				setBanner("Cancelled. You weren't charged.");
			}
		});
		const passConn = MarketplaceService.PromptGamePassPurchaseFinished.Connect((player, passId, purchased) => {
			if (player !== Players.LocalPlayer) {
				return;
			}
			const pending = pendingOffer.current;
			if (pending === undefined || pending.kind !== "pass" || pending.id !== passId) {
				return;
			}
			if (purchased) {
				const session = sessionRef.current;
				dispatch("SyncShop", {}, (response) => {
					if (sessionRef.current !== session) {
						return;
					}
					finishPurchase(response.ok !== false);
					setBanner(
						response.ok === false
							? (response.error ?? "Pass pending. Reopen the Shop in a moment.")
							: "Pass unlocked. Its bonuses are active now.",
					);
				});
			} else {
				finishPurchase(false);
				setBanner("Cancelled. You weren't charged.");
			}
		});
		return () => {
			mountedRef.current = false;
			sessionRef.current += 1;
			productConn.Disconnect();
			passConn.Disconnect();
			clearFailsafe();
		};
	}, []);
	const promptProduct = (product: DevProduct) => {
		if (busyRef.current || purchasePhaseRef.current === "pending") {
			return;
		}
		const run = () => {
			if (!mountedRef.current) {
				return;
			}
			if (busyRef.current || purchasePhaseRef.current === "pending") {
				return;
			}
			if (product.ProductId <= 0) {
				if (RunService.IsStudio()) {
					setBusyGate(true);
					openPending(product.Name);
					const session = sessionRef.current;
					dispatch("StudioGrantProduct", { Id: product.Key }, (response) => {
						if (sessionRef.current !== session) {
							return;
						}
						if (response.ok) {
							finishPurchase(true);
							setBanner(response.message ?? "Test grant applied.");
						} else {
							finishPurchase(false, response.error);
							setBanner(response.error ?? "Test purchase could not be completed.");
						}
					});
					return;
				}
				setBanner("This pack isn’t for sale yet.");
				return;
			}
			setBusyGate(true);
			pendingOffer.current = {
				kind: "product",
				id: product.ProductId,
			};
			openPending(product.Name);
			const [ok] = pcall(() => MarketplaceService.PromptProductPurchase(Players.LocalPlayer!, product.ProductId));
			if (!ok) {
				finishPurchase(false);
				setBanner("Couldn't open checkout.");
			}
		};
		task.defer(run);
	};
	const promptPass = (pass: GamePass) => {
		if (busyRef.current || owned[pass.Key] === true || purchasePhaseRef.current === "pending") {
			return;
		}
		const run = () => {
			if (!mountedRef.current) {
				return;
			}
			if (busyRef.current || purchasePhaseRef.current === "pending" || owned[pass.Key] === true) {
				return;
			}
			if (pass.PassId <= 0) {
				if (RunService.IsStudio()) {
					setBusyGate(true);
					openPending(pass.Name);
					const session = sessionRef.current;
					dispatch("StudioGrantProduct", { Id: pass.Key }, (response) => {
						if (sessionRef.current !== session) {
							return;
						}
						if (response.ok) {
							finishPurchase(true);
							setBanner(response.message ?? "Test pass unlocked.");
						} else {
							finishPurchase(false, response.error);
							setBanner(response.error ?? "Test pass could not be unlocked.");
						}
					});
					return;
				}
				setBanner("This pass isn’t for sale yet.");
				return;
			}
			setBusyGate(true);
			pendingOffer.current = {
				kind: "pass",
				id: pass.PassId,
			};
			openPending(pass.Name);
			const [ok] = pcall(() => MarketplaceService.PromptGamePassPurchase(Players.LocalPlayer!, pass.PassId));
			if (!ok) {
				finishPurchase(false);
				setBanner("Couldn't open checkout.");
			}
		};
		task.defer(run);
	};
	const redeem = () => {
		const trimmed = code.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
		const now = os.clock();
		if (trimmed === "" || busyRef.current || purchasePhaseRef.current === "pending") {
			return;
		}
		if (now - lastRedeemAt.current < REDEEM_DEBOUNCE) {
			return;
		}
		lastRedeemAt.current = now;
		setBusyGate(true);
		setCodeFeedback("Checking code…");
		clearFailsafe();
		const session = sessionRef.current + 1;
		sessionRef.current = session;
		dispatch("RedeemCode", { Code: trimmed }, (response) => {
			if (sessionRef.current !== session) {
				return;
			}
			setBusyGate(false);
			if (response.ok) {
				setCode("");
				setBanner(response.message ?? "Code claimed.");
				setCodeFeedback(response.message ?? "Reward claimed.");
			} else {
				setBanner(response.error ?? "That code didn’t work.");
				setCodeFeedback(response.error ?? "That code didn’t work.");
			}
		});
	};
	const followClaimed = state.SocialRewards?.CreatorFollowClaimed === true;
	const creatorName = state.SocialRewards?.CreatorName ?? "usingINales";
	const verifyFollow = () => {
		if (followBusy || followClaimed || busyRef.current) {
			return;
		}
		setFollowBusy(true);
		setFollowFeedback(`Checking your follow for @${creatorName}…`);
		dispatch("VerifyCreatorFollow", {}, (response) => {
			if (!mountedRef.current) {
				return;
			}
			setFollowBusy(false);
			const message = response.ok
				? (response.message ?? "Follower reward claimed.")
				: (response.error ?? "Follow check failed.");
			setFollowFeedback(message);
			setBanner(message);
		});
	};
	const products = monetization.DevProducts;
	const passes = monetization.GamePasses;
	const featuredProducts = products.filter((_, index) => index < 2);
	const featuredPasses = passes.filter((pass, index) => index < 1 || pass.Key === "AutoSalvage");
	const listCount =
		tab === "Codes"
			? 1
			: tab === "Featured"
				? featuredProducts.size() + featuredPasses.size()
				: tab === "Passes"
					? passes.size()
					: products.size();
	const packCols = useShopColumns();
	const packedH = stack ? 208 : 244;
	const codePanelH = stack ? 214 : 176;
	const followPanelH = stack ? 186 : 148;
	const codesH = codePanelH + Layout.panelGap + followPanelH;
	const pageGap = stack ? Layout.stackGap : Layout.panelGap;
	const offerStride = packedH + pageGap;
	const heroH = stack ? 104 : 92; // same height as the other shop tabs' headers
	const tabRowH = stack ? TapTarget : 50;
	const sectionLabelH = 34;
	const codeReady = code.gsub("%s", "")[0] !== "";
	const redeemDisabled = busy || !codeReady || purchasePhase === "pending";
	const shopHostRef = React.useRef<Frame>();
	const offerRows: OfferRow[] = [];
	if (tab !== "Codes") {
		const passList = tab === "Featured" ? featuredPasses : tab === "Passes" ? passes : [];
		const productList = tab === "Featured" ? featuredProducts : tab === "Supplies" ? products : [];
		const flatOffers: { kind: string; key: string; pass?: GamePass; product?: DevProduct }[] = [];
		for (const pass of passList) {
			flatOffers.push({
				kind: "pass",
				key: pass.Key,
				pass: pass,
			});
		}
		for (const product of productList) {
			flatOffers.push({
				kind: "product",
				key: product.Key,
				product: product,
			});
		}
		let index = 0;
		while (index < flatOffers.size()) {
			const row: OfferRow = {
				Id: `row-${tab}-${index + 1}`,
				cells: [],
			};
			for (let col = 1; col <= packCols; col++) {
				const entry = flatOffers[index];
				if (entry === undefined) {
					break;
				}
				row.cells.push(entry);
				index += 1;
			}
			offerRows.push(row);
		}
	}
	React.useEffect(() => {
		if (purchasePhase !== "hidden" || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = shopHostRef.current;
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
	}, [tab, purchasePhase, listCount, redeemDisabled]);
	const heroPanel = h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			accent: Palette.mango,
			background: Palette.panelRaised,
			padding: stack ? 14 : 20,
			reveal: heroReveal,
			highlight: true,
			reducedMotion: softMotion,
			clips: false,
		},
		stack
			? h(
				React.Fragment,
				{},
				h(Badge, {
					value: "SHOP",
					accent: Palette.mango,
					filled: true,
					size: UDim2.fromOffset(68, 20),
				}),
				h(Text, {
					value: "Support the game and speed up your forge.",
					size: 18,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					fit: false,
					position: UDim2.fromOffset(0, 26),
					sizeConstraint: new UDim2(1, 0, 0, 24),
				}),
				h(Text, {
					value: monetization.Error ?? banner,
					size: 12,
					color: Palette.creamSoft,
					wrap: true,
					position: UDim2.fromOffset(0, 52),
					sizeConstraint: new UDim2(1, 0, 0, 36),
				}),
			)
			: h(
				React.Fragment,
				{},
				h(IconTile, {
					kind: "Shop",
					accent: Palette.mango,
					size: 44,
					radius: 12,
					position: UDim2.fromOffset(0, 4),
					glow: true,
					reducedMotion: softMotion,
				}),
				h(
					"frame",
					{
						Size: new UDim2(1, -60, 0, 60),
						Position: UDim2.fromOffset(60, 0),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClipsDescendants: false,
					},
					h(Text, {
						value: "Passes, packs and codes",
						size: 24,
						color: Palette.cream,
						weight: Enum.FontWeight.Heavy,
						fit: false,
						position: UDim2.fromOffset(0, 0),
						sizeConstraint: new UDim2(1, 0, 0, 30),
					}),
					h(Text, {
						value: monetization.Error ?? banner,
						size: 12,
						color: Palette.creamSoft,
						wrap: true,
						position: UDim2.fromOffset(0, 32),
						sizeConstraint: new UDim2(1, 0, 0, 28),
					}),
				),
			),
	);
	const tabsBar = h(SegmentedTabs, {
		options: SHOP_TAB_OPTIONS,
		value: tab,
		onChange: (entry: unknown) => {
			const id = entry as string;
			setTab(id);
			setBanner(SHOP_TAB_TIPS[id]);
		},
		accent: Palette.mango,
		columns: SHOP_TABS.size(),
		gap: Layout.stackGap,
		size: UDim2.fromScale(1, 1),
		reducedMotion: softMotion,
	});
	const sectionLabel = h(SectionLabel, {
		value: tab === "Codes" ? "REDEEM" : tab === "Passes" ? "GAME PASSES" : tab === "Supplies" ? "SUPPLY PACKS" : "FEATURED OFFERS",
		color: Palette.mango,
	});
	const codesPane = h(
		TabPane,
		{
			key: "Codes",
			reducedMotion: softMotion,
			height: codesH,
		},
		h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			<uilistlayout
				FillDirection={Enum.FillDirection.Vertical}
				SortOrder={Enum.SortOrder.LayoutOrder}
				Padding={new UDim(0, pageGap)}
			/>,
			h(
				Panel,
				{
					layoutOrder: 1,
					size: new UDim2(1, -4, 0, codePanelH),
					accent: Palette.cyan,
					background: Palette.panelRaised,
					padding: stack ? 14 : 18,
					reducedMotion: softMotion,
					clips: false,
				},
				h(Text, {
					value: "Promo codes",
					size: 18,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					fit: true,
					sizeConstraint: new UDim2(1, 0, 0, 26),
				}),
				h(Text, {
					value: "Enter a code, then claim the reward once.",
					size: 12,
					color: Palette.muted,
					wrap: true,
					position: UDim2.fromOffset(0, 30),
					sizeConstraint: new UDim2(1, 0, 0, 26),
				}),
				h(
					"frame",
					{
						Size: stack ? new UDim2(1, 0, 0, TapTarget) : new UDim2(1, -168, 0, 48),
						Position: UDim2.fromOffset(0, 66),
						BackgroundColor3: Palette.ink,
						BorderSizePixel: 0,
						ClipsDescendants: false,
					},
					<uicorner CornerRadius={new UDim(0, 10)} />,
					<uistroke Color={codeFeedback !== "" ? Palette.cyan : Palette.lineSoft} Thickness={1} Transparency={0.5} />,
					h("textbox", {
						Size: new UDim2(1, -20, 1, -12),
						Position: UDim2.fromOffset(10, 6),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClearTextOnFocus: false,
						Text: code,
						PlaceholderText: "ENTER CODE",
						PlaceholderColor3: Palette.muted,
						TextColor3: Palette.cream,
						TextSize: 14,
						FontFace: Font.fromEnum(Enum.Font.BuilderSansMedium),
						TextXAlignment: Enum.TextXAlignment.Left,
						TextYAlignment: Enum.TextYAlignment.Center,
						TextTruncate: Enum.TextTruncate.AtEnd,
						MultiLine: false,
						TextEditable: !busy,
						MaxVisibleGraphemes: 24,
						Change: {
							Text: (box: TextBox) => {
								setCode(box.Text.upper().sub(1, 24));
								if (codeFeedback !== "") {
									setCodeFeedback("");
								}
							},
						},
						Event: {
							Focused: () => Audio.play("inputFocus"),
							FocusLost: (_box: TextBox, enter: boolean) => {
								if (enter) {
									redeem();
								}
							},
						},
					}),
				),
				h(
					"frame",
					{
						Name: "ShopClaimCode",
						Size: stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(148, 48),
						Position: stack ? UDim2.fromOffset(0, 122) : new UDim2(1, -148, 0, 66),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ClipsDescendants: false,
						ref: tab === "Codes" ? shopHostRef : undefined,
					},
					h(Button, {
						text: busy ? "CHECKING…" : "CLAIM CODE",
						icon: "Code.1",
						onClick: redeem,
						color: Palette.cyan,
						textColor: Palette.ink,
						size: UDim2.fromScale(1, 1),
						disabled: redeemDisabled,
						reducedMotion: softMotion,
						highlight: !redeemDisabled,
						selectable: !redeemDisabled,
					}),
				),
				codeFeedback !== "" &&
					h(Text, {
						value: codeFeedback,
						size: 11,
						color: Palette.creamSoft,
						weight: Enum.FontWeight.Bold,
						fit: true,
						minSize: 9,
						position: UDim2.fromOffset(0, stack ? 174 : 120),
						sizeConstraint: new UDim2(1, 0, 0, 18),
					}),
			),
			h(
				Panel,
				{
					layoutOrder: 2,
					size: new UDim2(1, -4, 0, followPanelH),
					accent: Palette.mint,
					background: Palette.panelRaised,
					padding: 16,
					reducedMotion: softMotion,
				},
				h(Icon, {
					kind: "Pilot.1",
					color: Palette.cream,
					accent: Palette.mint,
					size: stack ? 38 : 42,
					spin: false,
					position: UDim2.fromOffset(0, 2),
				}),
				h(Text, {
					value: `Follow @${creatorName}`,
					size: 16,
					color: Palette.cream,
					weight: Enum.FontWeight.Heavy,
					fit: true,
					position: UDim2.fromOffset(52, 0),
					sizeConstraint: new UDim2(1, stack ? -52 : -230, 0, 24),
				}),
				h(Text, {
					value:
						followFeedback !== ""
							? followFeedback
							: followClaimed
								? "Reward claimed. Thanks for following!"
								: "Follow the creator on Roblox, then check it here for a one-time reward.",
					size: 11,
					color: followClaimed || followFeedback !== "" ? Palette.mint : Palette.muted,
					wrap: true,
					position: UDim2.fromOffset(52, 28),
					sizeConstraint: new UDim2(1, stack ? -52 : -230, 0, stack ? 42 : 36),
				}),
				h(Button, {
					text: followClaimed ? "CLAIMED" : followBusy ? "CHECKING…" : "CHECK FOLLOW",
					icon: followClaimed ? "Check.10" : "Search.5",
					onClick: verifyFollow,
					color: followClaimed ? Palette.panelSoft : Palette.mint,
					textColor: followClaimed ? Palette.muted : Palette.ink,
					size: stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(190, 48),
					position: stack ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(1, -190, 0.5, -24),
					disabled: followClaimed || followBusy,
					reducedMotion: softMotion,
					highlight: !followClaimed && !followBusy,
				}),
			),
		),
	);
	const catalogH = math.max(offerStride, offerRows.size() * offerStride);
	const offerList = h(FlatList, {
		data: offerRows,
		itemHeight: offerStride,
		headerHeight: 0,
		overscan: softMotion ? 0 : antilag.constrained ? 1 : 2,
		canvasTail: 8,
		embedded: true,
		Size: new UDim2(1, 0, 0, catalogH),
		scrollBarColor: Palette.mango,
		scrollBarThickness: 3,
		scrollBarTransparency: 0.28,
		keyExtractor: (row: OfferRow) => row.Id,
		renderItem: (info: { item: OfferRow; index: number }) => {
			const row = info.item;
			const rowIndex = info.index;
			return h(
				FlexGrid,
				{
					columns: packCols,
					cellMinHeight: packedH,
					size: UDim2.fromScale(1, 1),
				},
				(() => {
					const tiles: defined[] = [];
					for (const [cellIndex, entry] of ipairs(row.cells)) {
						const staggerIndex = (rowIndex - 1) * packCols + (cellIndex - 1);
						if (entry.kind === "pass") {
							const pass = entry.pass!;
							const cta = owned[pass.Key] === true ? "Owned" : priceText(pass.PriceLabel, pass.StudioPrice, pass.PassId);
							const unavailable = pass.PassId <= 0 && !RunService.IsStudio();
							tiles.push(
								h(OfferTile, {
									key: `${tab}-${pass.Key}`,
									layoutOrder: cellIndex,
									staggerIndex: staggerIndex,
									title: pass.Name,
									detail: pass.Description,
									meta: passBenefitLine(pass),
									accent: accentOf(pass.Accent),
									icon: iconOf(pass.Icon),
									cta: cta,
									disabled: unavailable || busy,
									owned: owned[pass.Key] === true,
									onClick: () => promptPass(pass),
									reducedMotion: softMotion,
									packed: true,
								}),
							);
						} else {
							const product = entry.product!;
							const unavailable = product.ProductId <= 0 && !RunService.IsStudio();
							tiles.push(
								h(OfferTile, {
									key: `${tab}-${product.Key}`,
									layoutOrder: cellIndex,
									staggerIndex: staggerIndex,
									title: product.Name,
									detail: product.Description,
									meta: rewardLine(product.Reward),
									accent: accentOf(product.Accent),
									icon: iconOf(product.Icon),
									cta: priceText(product.PriceLabel, product.StudioPrice, product.ProductId),
									disabled: unavailable || busy,
									onClick: () => promptProduct(product),
									reducedMotion: reducedMotion,
									packed: true,
								}),
							);
						}
					}
					return tiles;
				})(),
			);
		},
		ListEmptyComponent: h(EmptyState, {
			key: "shop-empty",
			icon: "Shop.5",
			title: "Nothing listed",
			body: "Nothing listed in this tab right now.",
			accent: Palette.mango,
			layoutOrder: 0,
			reducedMotion: reducedMotion,
		}),
	});
	const sections: { id: string; height: number; element: unknown }[] = [
		{
			id: "hero",
			height: heroH,
			element: heroPanel,
		},
		{
			id: "tabs",
			height: tabRowH,
			element: tabsBar,
		},
		{
			id: "label",
			height: sectionLabelH,
			element: sectionLabel,
		},
	];
	if (tab === "Codes") {
		sections.push({
			id: "list",
			height: codesH,
			element: codesPane,
		});
	} else {
		const catalogH = math.max(offerStride, offerRows.size() * offerStride);
		sections.push({
			id: "list",
			height: catalogH,
			element: h(
				Panel,
				{
					size: new UDim2(1, 0, 0, catalogH),
					accent: Palette.mango,
					background: Palette.panel,
					padding: 0,
					reveal: catalogReveal,
					reducedMotion: reducedMotion,
					clips: false,
				},
				offerList,
			),
		});
	}
	return React.createElement("frame", {
		ref: tab !== "Codes" ? shopHostRef : undefined,
		Name: "ShopViewHost",
		Size: UDim2.fromScale(1, 1),
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		ClipsDescendants: false,
	},
		h(PageScaffold, {
			gap: pageGap,
			tailPad: scrollTail(stack, chrome.bottomSafe, SCROLL_PAD),
			scrollBarColor: Palette.mango,
			scrollBarThickness: 4,
			sections: sections,
		}),
		h(PurchaseOverlay, {
			phase: purchasePhase,
			reducedMotion: reducedMotion,
			detail: purchaseDetail,
			onDismiss: dismissPurchase,
		}),
	) as React.Element;
}
const GAP = 10;
const SECTIONS = [
	{ id: "Daily", label: "Daily" },
	{ id: "Crates", label: "Crates" },
	{ id: "Skins", label: "Skins" },
	{ id: "Codex", label: "Codex" },
	{ id: "Artifacts", label: "Artifacts" },
	{ id: "Premium", label: "Premium" },
];
function sectionTabLayout(width: number, rowHeight: number): LuaTuple<[number, number]> {
	const gap = 6;
	const columns = math.clamp(math.floor((math.max(1, width) + gap) / (96 + gap)), 1, SECTIONS.size());
	const rows = math.ceil(SECTIONS.size() / columns);
	return $tuple(columns, rows * rowHeight + (rows - 1) * gap);
}
const ARTIFACT_RARITY: Record<string, { rank: number; color: Color3; label: string }> = {
	COMMON: { rank: 1, color: Color3.fromRGB(200, 196, 188), label: "Common" },
	UNCOMMON: { rank: 2, color: Color3.fromRGB(120, 220, 150), label: "Uncommon" },
	RARE: { rank: 3, color: Color3.fromRGB(110, 190, 255), label: "Rare" },
	EPIC: { rank: 4, color: Color3.fromRGB(190, 120, 255), label: "Epic" },
	LEGENDARY: { rank: 5, color: Color3.fromRGB(255, 190, 70), label: "Legendary" },
	MYTHIC: { rank: 6, color: Color3.fromRGB(255, 110, 150), label: "Mythic" },
};
const CURRENCY_ICON: Record<string, string> = { Stardust: "Dust", Cores: "Core" };
const KIND_ICON: Record<string, string> = { Key: "Crate", Essence: "Artifact", Flux: "Flux", Boost: "Boost", Cache: "Gift", Skin: "Crate" };
const TIER_COLOR: Record<string, Color3> = {
	Common: Color3.fromRGB(200, 196, 188),
	Rare: Color3.fromRGB(110, 190, 255),
	Epic: Color3.fromRGB(190, 120, 255),
	Legendary: Color3.fromRGB(255, 190, 70),
	Mythic: Color3.fromRGB(255, 110, 150),
};

function commas(value: unknown): string {
	const text = tostring(math.floor(math.max(0, tonumber(value) ?? 0)));
	const spaced = text.reverse().gsub("(%d%d%d)", "%1,")[0].reverse();
	return spaced.gsub("^,", "")[0];
}

function currencyColor(currency: unknown): Color3 {
	return currency === "Cores" ? Palette.cyan : Palette.violet;
}

function rarityColor(config: ShopConfig | undefined, rarity: string | undefined): Color3 {
	const entry = rarity !== undefined ? config?.Items?.Rarities?.[rarity] : undefined;
	return entry !== undefined && entry.Color !== undefined ? entry.Color : Palette.cream;
}

function crateById(config: ShopConfig | undefined, id: unknown): CrateConfig | undefined {
	for (const crate of config?.Items?.Crates ?? []) {
		if (crate.Id === id) {
			return crate;
		}
	}
	return undefined;
}

function dayClockText(seconds: number): string {
	const left = math.max(0, math.floor(seconds));
	const hours = math.floor(left / 3600);
	const minutes = math.floor((left % 3600) / 60);
	if (hours > 0) {
		return `${hours}h ${minutes}m`;
	}
	return `${minutes}m ${left % 60}s`;
}

function rowsHeight(count: number, columns: number, cell: number): number {
	const rows = math.max(1, math.ceil(count / math.max(1, columns)));
	return rows * cell + (rows - 1) * GAP;
}

interface GridProps {
	columns: number;
	cell: number;
	height: number;
	cells: Record<string, unknown>;
}

function Grid(props: GridProps) {
	const children: Record<string, unknown> = { ...props.cells };
	children.Layout = h("uigridlayout", {
		CellSize: new UDim2(1 / props.columns, -math.ceil((GAP * (props.columns - 1)) / props.columns), 0, props.cell),
		CellPadding: UDim2.fromOffset(GAP, GAP),
		FillDirectionMaxCells: props.columns,
		SortOrder: Enum.SortOrder.LayoutOrder,
	});
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, props.height),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
		},
		children,
	);
}

interface WalletProps {
	state: ShopState;
	left?: boolean;
	size: UDim2;
	position: UDim2;
	anchorPoint?: Vector2;
}

function Wallet(props: WalletProps) {
	const state = props.state;
	const chips: Record<string, unknown> = {
		Layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Horizontal,
			HorizontalAlignment: props.left ? Enum.HorizontalAlignment.Left : Enum.HorizontalAlignment.Right,
			Padding: new UDim(0, 6),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
	};
	for (const [index, currency] of ipairs(["Stardust", "Cores"])) {
		chips[currency] = h(
			"frame",
			{
				Size: UDim2.fromOffset(112, 30),
				BackgroundColor3: Palette.panelSoft,
				BackgroundTransparency: 0.15,
				BorderSizePixel: 0,
				LayoutOrder: index,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: currencyColor(currency),
				Transparency: 0.55,
				Thickness: 1,
			}),
			h(Icon, {
				kind: CURRENCY_ICON[currency],
				color: Palette.cream,
				accent: currencyColor(currency),
				size: 20,
				position: UDim2.fromOffset(6, 5),
				spin: false,
			}),
			h(Text, {
				value: Fmt.compactNumber(state[currency]),
				size: 13,
				color: Palette.cream,
				weight: Enum.FontWeight.Bold,
				fit: true,
				minSize: 9,
				position: UDim2.fromOffset(32, 6),
				sizeConstraint: new UDim2(1, -40, 0, 18),
			}),
		);
	}
	return h(
		"frame",
		{
			Size: props.size,
			Position: props.position,
			AnchorPoint: props.anchorPoint,
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
		},
		chips,
	);
}

interface HeroProps {
	title: string;
	body: string;
	accent: Color3;
	icon: string;
	state: ShopState;
	stack: boolean;
	reveal?: React.Binding<number>;
	reducedMotion?: boolean;
	extra?: unknown;
}

function Hero(props: HeroProps) {
	const stack = props.stack;
	const textW = stack ? -56 : -300;
	return h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			accent: props.accent,
			background: Palette.panelRaised,
			padding: 14,
			reveal: props.reveal,
			highlight: true,
			reducedMotion: props.reducedMotion,
			clips: false,
		},
		h(IconTile, {
			kind: props.icon,
			accent: props.accent,
			size: 44,
			radius: 12,
			position: UDim2.fromOffset(0, 2),
			glow: true,
			reducedMotion: props.reducedMotion,
		}),
		h(Text, {
			value: props.title,
			size: stack ? 18 : 22,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 13,
			position: UDim2.fromOffset(56, 0),
			sizeConstraint: new UDim2(1, textW, 0, 28),
		}),
		h(Text, {
			value: props.body,
			size: 12,
			color: Palette.creamSoft,
			wrap: true,
			position: UDim2.fromOffset(56, 30),
			sizeConstraint: new UDim2(1, textW, 0, 34),
		}),
		h(Wallet, {
			state: props.state,
			left: stack,
			size: stack ? new UDim2(1, 0, 0, 30) : UDim2.fromOffset(240, 30),
			position: stack ? new UDim2(0, 0, 1, -30) : UDim2.fromScale(1, 0),
			anchorPoint: stack ? undefined : new Vector2(1, 0),
		}),
		props.extra,
	);
}

function heroHeight(stack: boolean): number {
	return stack ? 124 : 92;
}

function offerDetail(offer: DailyOffer, config: ShopConfig): string {
	if (offer.Kind === "Key") {
		const crate = crateById(config, offer.CrateId);
		return `${offer.Amount} key${offer.Amount === 1 ? "" : "s"} for the ${crate !== undefined ? crate.Name : offer.CrateId}. Open ${offer.Amount === 1 ? "it" : "them"} under Crates.`;
	} else if (offer.Kind === "Essence") {
		return `+${commas(offer.Amount)} relic essence, for levelling relics.`;
	} else if (offer.Kind === "Flux") {
		const span = (offer.Minutes ?? 0) >= 60 ? `${math.floor((offer.Minutes ?? 0) / 60)} hour${(offer.Minutes ?? 0) >= 120 ? "s" : ""}` : `${offer.Minutes} minutes`;
		return `${span} of your current flux output, paid at once.`;
	} else if (offer.Kind === "Boost") {
		const boost = config.Boosts?.[tostring(offer.BoostId)];
		const name = boost !== undefined && boost.Name !== undefined ? boost.Name : tostring(offer.BoostId).gsub("(%l)(%u)", "%1 %2")[0];
		return `${offer.Amount} ${name} ${offer.Amount === 1 ? "charge" : "charges"}. Use it from Boosts.`;
	} else if (offer.Kind === "Cache") {
		return `One ${offer.Rarity} relic, guaranteed, revealed on the spot.`;
	} else if (offer.Kind === "Skin") {
		const skin = ShopCatalog.skin(offer.SkinId);
		return `Crate skin. ${skin !== undefined ? skin.Blurb : ""}`;
	}
	return "";
}

function offerAccent(offer: DailyOffer, config: ShopConfig): Color3 {
	if (offer.Kind === "Skin") {
		return skinAccent(offer.SkinId ?? "");
	} else if (offer.Kind === "Cache") {
		return rarityColor(config, offer.Rarity);
	} else if (offer.Kind === "Key") {
		const crate = crateById(config, offer.CrateId);
		return crate !== undefined && typeIs(crate.Color, "Color3") ? crate.Color : Palette.cyan;
	}
	return offer.Deal ? Palette.mango : Palette.cyan;
}

interface SectionProps {
	state: ShopState;
	config: ShopConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	stack: boolean;
	width: number;
	reveal?: React.Binding<number>;
	tailPad: number;
	navigate?: (page: string) => void;
	onCrateReveal?: (request: CrateRevealRequest) => void;
	crateRevealActive?: boolean;
	[key: string]: unknown;
}

interface OfferCardProps {
	offer: DailyOffer;
	index: number;
	config: ShopConfig;
	state: ShopState;
	left: number;
	busy: boolean;
	pending: boolean;
	reducedMotion?: boolean;
	onBuy: () => void;
}

function OfferCard(props: OfferCardProps) {
	const offer = props.offer;
	const accent = offerAccent(offer, props.config);
	const reveal = useStagger(props.index, props.reducedMotion, 0.04, 0.26);
	const left = props.left;
	const soldOut = left <= 0;
	const have = tonumber(props.state[offer.Currency]) ?? 0;
	const short = math.max(0, offer.Price - have);
	const canBuy = !soldOut && short === 0 && !props.busy;
	const fullPrice = offer.Deal ? math.floor(offer.Price / (1 - ShopCatalog.DEAL_DISCOUNT) + 0.5) : undefined;
	const cta = soldOut ? "SOLD OUT" : short > 0 ? `NEED ${commas(short)}` : props.pending ? "BUYING…" : "BUY";
	return h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			accent: accent,
			background: Palette.panelRaised,
			padding: 12,
			reveal: reveal,
			interactive: canBuy,
			highlight: offer.Deal,
			reducedMotion: props.reducedMotion,
			clips: false,
			layoutOrder: props.index,
		},
		h(
			"frame",
			{
				Size: UDim2.fromOffset(62, 62),
				BackgroundColor3: darken(accent, 0.4),
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
			h("uicorner", { CornerRadius: new UDim(0, 12) }),
			h("uistroke", {
				Color: accent,
				Thickness: 1.5,
				Transparency: 0.3,
			}),
			offer.Kind === "Skin"
				? h(CrateModel, {
					skin: offer.SkinId,
					live: offer.Deal === true && !props.reducedMotion,
					spin: true,
					zoom: 0.95,
				})
				: h(Icon, {
					kind: KIND_ICON[offer.Kind] ?? "Shop.6",
					color: Palette.cream,
					accent: accent,
					size: 38,
					position: UDim2.fromOffset(12, 12),
					spin: false,
					reducedMotion: props.reducedMotion,
				}),
		),
		h(Text, {
			value: offer.Name,
			size: 15,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 11,
			position: UDim2.fromOffset(74, 0),
			sizeConstraint: new UDim2(1, -74 - (offer.Deal ? 76 : 0), 0, 22),
		}),
		h(Text, {
			value: offerDetail(offer, props.config),
			size: 12,
			color: Palette.creamSoft,
			wrap: true,
			position: UDim2.fromOffset(74, 24),
			sizeConstraint: new UDim2(1, -74, 0, 44),
		}),
		offer.Deal === true &&
			h(Badge, {
				value: `DEAL -${math.floor(ShopCatalog.DEAL_DISCOUNT * 100)}%`,
				accent: Palette.mango,
				filled: true,
				size: UDim2.fromOffset(72, 20),
				position: new UDim2(1, -72, 0, 0),
			}),
		h(Text, {
			value: soldOut ? "Bought out today" : `${left} left today`,
			size: 11,
			color: soldOut ? Palette.muted : accent,
			weight: Enum.FontWeight.Bold,
			position: UDim2.fromOffset(0, 74),
			sizeConstraint: new UDim2(1, 0, 0, 16),
		}),
		h(Icon, {
			kind: CURRENCY_ICON[offer.Currency] ?? "Dust.3",
			color: Palette.cream,
			accent: currencyColor(offer.Currency),
			size: 22,
			position: new UDim2(0, 0, 1, fullPrice !== undefined ? -38 : -31),
			spin: false,
		}),
		h(Text, {
			value: commas(offer.Price),
			size: 18,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			position: new UDim2(0, 28, 1, fullPrice !== undefined ? -40 : -32),
			sizeConstraint: UDim2.fromOffset(80, 24),
		}),
		fullPrice !== undefined &&
			h(Text, {
				value: `was ${commas(fullPrice)}`,
				size: 11,
				color: Palette.muted,
				position: new UDim2(0, 28, 1, -15),
				sizeConstraint: UDim2.fromOffset(80, 14),
			}),
		h(
			"frame",
			{
				Name: "DailyBuy",
				Size: UDim2.fromOffset(124, 48),
				Position: new UDim2(1, -124, 1, -48),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h(Button, {
				text: cta,
				icon: soldOut ? "Check.11" : short > 0 ? "Lock.7" : "Shop.7",
				onClick: props.onBuy,
				color: canBuy ? accent : Palette.panelSoft,
				textColor: canBuy ? Palette.ink : Palette.creamSoft,
				size: UDim2.fromScale(1, 1),
				disabled: !canBuy,
				reducedMotion: props.reducedMotion,
				highlight: canBuy,
				selectable: canBuy,
			}),
		),
	);
}

function useDay(): number {
	const [day, setDay] = React.useState(() => ShopCatalog.day(Workspace.GetServerTimeNow()));
	React.useEffect(() => {
		const job = task.delay(ShopCatalog.secondsLeft(Workspace.GetServerTimeNow()) + 1, () => {
			setDay(ShopCatalog.day(Workspace.GetServerTimeNow()));
		});
		return () => {
			pcall(() => task.cancel(job));
		};
	}, [day]);
	return day;
}

function DailySection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const stack = props.stack;
	const day = useDay();
	const wall = useWallClock(true);
	const [pendingSlot, setPendingSlot] = React.useState<number | undefined>(undefined);
	const mounted = React.useRef(true);
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
		};
	}, []);
	const daily = state.DailyShop ?? {};
	const current = daily.Day === day;
	const owned = current && typeIs(daily.Owned, "table") ? daily.Owned : (state.Cosmetics?.CrateSkins ?? {});
	const bought = current ? (daily.Bought ?? {}) : {};
	const offers = ShopCatalog.roll(Players.LocalPlayer!.UserId, day, owned);
	const columns = stack ? 1 : props.width >= 1000 ? 3 : 2;
	const cellH = 178;
	const buy = (offer: DailyOffer) => {
		if (pendingSlot !== undefined) {
			return;
		}
		setPendingSlot(offer.Slot);
		props.dispatch("BuyDailyOffer", { Slot: offer.Slot }, (response) => {
			if (!mounted.current) {
				return;
			}
			setPendingSlot(undefined);
			if (response.ok && typeIs(response.Rolls, "table") && (response.Rolls as unknown[]).size() > 0 && props.onCrateReveal !== undefined) {
				const roll = (response.Rolls as { Rarity?: string }[])[0];
				props.onCrateReveal({
					crateId: "ForgeCrate",
					crateName: offer.Name ?? "",
					accent: rarityColor(config, roll.Rarity),
					rolls: response.Rolls as unknown[],
				});
			} else if (response.ok) {
				Audio.play("purchase");
			}
		});
	};
	const cells: Record<string, unknown> = {};
	for (const [index, offer] of ipairs(offers)) {
		cells[`Offer${offer.Slot}`] = h(OfferCard, {
			key: `${day}-${offer.Id}`,
			offer: offer,
			index: index,
			config: config,
			state: state,
			left: ShopCatalog.remaining(offer, bought),
			busy: pendingSlot !== undefined,
			pending: pendingSlot === offer.Slot,
			reducedMotion: props.reducedMotion,
			onBuy: () => buy(offer),
		});
	}
	const gridH = rowsHeight(offers.size(), columns, cellH);
	const resetText = wall.map((now) => `New offers in ${dayClockText(ShopCatalog.secondsLeft(now))}`);
	const marketH = stack ? 132 : 96;
	return h(PageScaffold, {
		gap: GAP,
		tailPad: props.tailPad,
		scrollBarColor: Palette.mango,
		sections: [
			{
				id: "hero",
				height: heroHeight(stack),
				element: h(Hero, {
					title: "Daily Shop",
					body: "Six offers picked for you each day. The first is the Deal of the Day.",
					accent: Palette.mango,
					icon: "Calendar.3",
					state: state,
					stack: stack,
					reveal: props.reveal,
					reducedMotion: props.reducedMotion,
				}),
			},
			{
				id: "clock",
				height: 22,
				element: h(Text, {
					value: resetText,
					size: 13,
					color: Palette.mango,
					weight: Enum.FontWeight.Bold,
					sizeConstraint: new UDim2(1, 0, 0, 20),
				}),
			},
			{
				id: "offers",
				height: gridH,
				element: h(Grid, { columns: columns, cell: cellH, height: gridH, cells: cells }),
			},
			{
				id: "market",
				height: marketH,
				element: h(
					Panel,
					{
						size: UDim2.fromScale(1, 1),
						accent: Palette.coral,
						background: Palette.panel,
						padding: 14,
						reducedMotion: props.reducedMotion,
						clips: false,
					},
					h(Icon, {
						kind: "Jackpot.3",
						color: Palette.cream,
						accent: Palette.coral,
						size: 38,
						position: UDim2.fromOffset(0, 4),
						spin: false,
					}),
					h(Text, {
						value: "The Black Market",
						size: 16,
						color: Palette.cream,
						weight: Enum.FontWeight.Heavy,
						position: UDim2.fromOffset(50, 0),
						sizeConstraint: new UDim2(1, stack ? -50 : -220, 0, 22),
					}),
					h(Text, {
						value: "Keys, materials and boosts from the Black Market's hourly shipments.",
						size: 12,
						color: Palette.creamSoft,
						wrap: true,
						position: UDim2.fromOffset(50, 24),
						sizeConstraint: new UDim2(1, stack ? -50 : -220, 0, 36),
					}),
					h(Button, {
						text: "VISIT MARKET",
						icon: "Visit.1",
						onClick: () => {
							if (props.navigate !== undefined) {
								props.navigate("Bazaar");
							}
						},
						color: Palette.coral,
						textColor: Palette.ink,
						size: stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(190, 44),
						position: stack ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(1, -190, 0.5, -22),
						reducedMotion: props.reducedMotion,
						highlight: true,
					}),
				),
			},
		],
	});
}

interface OddsRowProps {
	row: { rarity: string; chance: number };
	config: ShopConfig;
	order: number;
}

function OddsRow(props: OddsRowProps) {
	const row = props.row;
	const color = rarityColor(props.config, row.rarity);
	return h(
		"frame",
		{
			Size: new UDim2(1, 0, 0, 20),
			BackgroundColor3: color,
			BackgroundTransparency: isAscended(row.rarity) ? 0.86 : 1,
			BorderSizePixel: 0,
			LayoutOrder: props.order,
		},
		h("uicorner", { CornerRadius: new UDim(0, 6) }),
		isAscended(row.rarity) &&
			h(PrismAura, {
				rarity: row.rarity,
				intensity: 0.8,
				rays: false,
				sparks: false,
				thickness: 1.5,
				corner: 6,
			}),
		h("frame", {
			Size: UDim2.fromOffset(8, 8),
			Position: new UDim2(0, 6, 0.5, 0),
			AnchorPoint: new Vector2(0, 0.5),
			Rotation: 45,
			BackgroundColor3: color,
			BorderSizePixel: 0,
		}),
		h(Text, {
			value: row.rarity,
			size: 12,
			color: isAscended(row.rarity) ? Palette.cream : color,
			weight: Enum.FontWeight.Bold,
			position: UDim2.fromOffset(22, 2),
			sizeConstraint: new UDim2(0.6, -22, 0, 16),
		}),
		h(Text, {
			value: RelicSystem.chanceText(row.chance),
			size: 12,
			color: Palette.cream,
			weight: Enum.FontWeight.Bold,
			align: Enum.TextXAlignment.Right,
			position: new UDim2(0.4, 0, 0, 2),
			sizeConstraint: new UDim2(0.6, -8, 0, 16),
		}),
	);
}

interface CrateStageProps {
	crate: CrateConfig;
	config: ShopConfig;
	stack: boolean;
	keys: number;
	pity: number;
	skin?: string;
	busy: boolean;
	reveal?: React.Binding<number>;
	onOpen: (count: number) => void;
	reducedMotion?: boolean;
}

function CrateStage(props: CrateStageProps) {
	const crate = props.crate;
	const config = props.config;
	const stack = props.stack;
	const keys = props.keys;
	const odds = RelicSystem.odds(crate.Weights);
	const accent = typeIs(crate.Color, "Color3") ? crate.Color : Palette.violet;
	const oddsRows: Record<string, unknown> = {
		Layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			Padding: new UDim(0, 2),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
	};
	for (let index = odds.size(); index >= 1; index--) {
		const row = odds[index - 1];
		oddsRows[row.rarity] = h(OddsRow, { row: row, config: config, order: odds.size() - index });
	}
	const modelH = stack ? 190 : 280;
	const infoX = stack ? 0 : 300;
	const infoY = stack ? modelH + 6 : 0;
	const pity = props.pity ?? 0;
	const pityLine =
		crate.PityAfter !== undefined && crate.PityRarity !== undefined
			? `Pity: a ${crate.PityRarity} or better within ${math.max(1, crate.PityAfter - pity)} opens.`
			: "";
	const openButton = (count: number, order: number) => {
		const can = keys >= count && !props.busy;
		return h(Button, {
			text: keys >= count ? `OPEN ${count}` : `NEED ${count - keys} KEY${count - keys === 1 ? "" : "S"}`,
			icon: keys >= count ? "Crate.2" : "Lock.8",
			onClick: () => {
				props.onOpen(count);
			},
			color: can ? accent : Palette.panelSoft,
			textColor: can ? Palette.ink : Palette.creamSoft,
			size: new UDim2(0.5, -4, 1, 0),
			position: UDim2.fromScale(order === 1 ? 0 : 0.5, 0),
			disabled: !can,
			reducedMotion: props.reducedMotion,
			highlight: can,
			selectable: can,
		});
	};
	return h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			accent: accent,
			background: Palette.panelRaised,
			padding: 14,
			reveal: props.reveal,
			reducedMotion: props.reducedMotion,
			clips: false,
		},
		h(
			"frame",
			{
				Size: stack ? new UDim2(1, 0, 0, modelH) : UDim2.fromOffset(286, modelH),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: 0.25,
				BorderSizePixel: 0,
			},
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h("uigradient", {
				Color: new ColorSequence(darken(accent, 0.55), Palette.void),
				Rotation: 90,
			}),
			h(CrateModel, {
				skin: CrateAppearance.resolve(props.skin, crate.Id, (config.Items?.Crates ?? []) as { Id: string; ModelId?: string }[]),
				spin: true,
				open: props.busy ? 0.35 : 0,
				shake: props.busy ? 1 : 0,
				live: !props.reducedMotion,
				zoom: 0.85,
			}),
			h(Badge, {
				value: `${keys} KEY${keys === 1 ? "" : "S"}`,
				accent: keys > 0 ? accent : Palette.lineSoft,
				filled: keys > 0,
				size: UDim2.fromOffset(78, 22),
				position: UDim2.fromOffset(10, 10),
			}),
		),
		h(
			"frame",
			{
				Size: stack ? new UDim2(1, 0, 1, -infoY) : new UDim2(1, -infoX, 1, 0),
				Position: UDim2.fromOffset(infoX, infoY),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h(Text, {
				value: crate.Name,
				size: 20,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 13,
				sizeConstraint: new UDim2(1, 0, 0, 26),
			}),
			h(Text, {
				value: crate.Description ?? "",
				size: 12,
				color: Palette.creamSoft,
				wrap: true,
				position: UDim2.fromOffset(0, 28),
				sizeConstraint: new UDim2(1, 0, 0, 30),
			}),
			h(Text, {
				value: pityLine,
				size: 11,
				color: accent,
				weight: Enum.FontWeight.Bold,
				position: UDim2.fromOffset(0, 60),
				sizeConstraint: new UDim2(1, 0, 0, 16),
			}),
			h(
				"frame",
				{
					Size: new UDim2(1, 0, 0, odds.size() * 22),
					Position: UDim2.fromOffset(0, 82),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				oddsRows,
			),
			h(
				"frame",
				{
					Name: "CrateOpen",
					Size: new UDim2(1, 0, 0, TapTarget),
					Position: new UDim2(0, 0, 1, -TapTarget),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				openButton(1, 1),
				openButton(5, 2),
			),
		),
	);
}

function crateStageHeight(stack: boolean, crate: CrateConfig | undefined): number {
	const rows = RelicSystem.odds(crate?.Weights).size();
	const info = 82 + rows * 22 + 10 + TapTarget + 28;
	return stack ? 190 + 6 + info : math.max(280, info) + 28;
}

interface CrateChipProps {
	crate: CrateConfig;
	selected: boolean;
	order: number;
	keys: number;
	onSelect: () => void;
}

function CrateChip(props: CrateChipProps) {
	const crate = props.crate;
	const accent = typeIs(crate.Color, "Color3") ? crate.Color : Palette.violet;
	return h(
		"textbutton",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: props.selected ? darken(accent, 0.45) : Palette.panel,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			LayoutOrder: props.order,
			Event: {
				Activated: () => {
					Audio.play("tabSwitch");
					props.onSelect();
				},
			},
		},
		h("uicorner", { CornerRadius: new UDim(0, 12) }),
		h("uistroke", {
			Color: accent,
			Thickness: props.selected ? 2 : 1,
			Transparency: props.selected ? 0 : 0.6,
		}),
		h(Icon, {
			kind: "Crate.3",
			color: Palette.cream,
			accent: accent,
			size: 30,
			position: new UDim2(0, 10, 0.5, -15),
			spin: false,
		}),
		h(Text, {
			value: crate.Name,
			size: 13,
			color: Palette.cream,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 10,
			position: UDim2.fromOffset(48, 8),
			sizeConstraint: new UDim2(1, -56, 0, 18),
		}),
		h(Text, {
			value: props.keys > 0 ? `${props.keys} key${props.keys === 1 ? "" : "s"}` : "No keys",
			size: 11,
			color: props.keys > 0 ? accent : Palette.muted,
			weight: Enum.FontWeight.Bold,
			position: UDim2.fromOffset(48, 28),
			sizeConstraint: new UDim2(1, -56, 0, 16),
		}),
	);
}

function CratesSection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const stack = props.stack;
	const crates = config.Items?.Crates ?? [];
	const items = state.Items ?? {};
	const keys = items.Keys ?? {};
	let firstWithKeys: string | undefined = undefined;
	for (const crate of crates) {
		if ((keys[crate.Id] ?? 0) > 0) {
			firstWithKeys = crate.Id;
			break;
		}
	}
	const [selected, setSelected] = React.useState<string | undefined>(firstWithKeys ?? crates[0]?.Id);
	const [busy, setBusy] = React.useState(false);
	const attempt = React.useRef(0);
	const mounted = React.useRef(true);
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
		};
	}, []);
	const crate = crateById(config, selected) ?? crates[0];
	if (crate === undefined) {
		return h(Text, { value: "No crates right now.", size: 14, color: Palette.creamSoft });
	}
	const skin = state.Cosmetics?.CrateSkin;
	const onOpen = (count: number) => {
		if (busy || props.crateRevealActive) {
			return;
		}
		attempt.current += 1;
		const mine = attempt.current;
		setBusy(true);
		props.dispatch("OpenItemCrate", { Id: crate.Id, Count: count }, (response) => {
			if (!mounted.current || attempt.current !== mine) {
				return;
			}
			setBusy(false);
			if (response.ok && typeIs(response.Rolls, "table") && (response.Rolls as unknown[]).size() > 0 && props.onCrateReveal !== undefined) {
				props.onCrateReveal({
					crateId: crate.Id,
					crateName: crate.Name,
					accent: typeIs(crate.Color, "Color3") ? crate.Color : undefined,
					rolls: response.Rolls as unknown[],
				});
			}
		});
	};
	const columns = stack ? 2 : props.width >= 1000 ? 4 : 3;
	const chips: Record<string, unknown> = {};
	for (const [index, entry] of ipairs(crates)) {
		chips[entry.Id] = h(CrateChip, {
			crate: entry,
			order: index,
			keys: keys[entry.Id] ?? 0,
			selected: entry.Id === crate.Id,
			onSelect: () => {
				setSelected(entry.Id);
			},
		});
	}
	const chipsH = rowsHeight(crates.size(), columns, 58);
	return h(PageScaffold, {
		gap: GAP,
		tailPad: props.tailPad,
		scrollBarColor: Palette.violet,
		sections: [
			{
				id: "hero",
				height: heroHeight(stack),
				element: h(Hero, {
					title: "Crates",
					body: "Every crate's odds, all the way up to Celestial and Astral. Your crate skin opens every one.",
					accent: Palette.violet,
					icon: "Crate.4",
					state: state,
					stack: stack,
					reveal: props.reveal,
					reducedMotion: props.reducedMotion,
				}),
			},
			{
				id: "stage",
				height: crateStageHeight(stack, crate),
				element: h(CrateStage, {
					key: crate.Id,
					crate: crate,
					config: config,
					stack: stack,
					keys: keys[crate.Id] ?? 0,
					pity: items.Pity?.[crate.Id] ?? 0,
					skin: skin,
					busy: busy || props.crateRevealActive === true,
					onOpen: onOpen,
					reducedMotion: props.reducedMotion,
				}),
			},
			{
				id: "chips",
				height: chipsH,
				element: h(Grid, { columns: columns, cell: 58, height: chipsH, cells: chips }),
			},
		],
	});
}

function skinStatus(skin: SkinDef, cosmetics: CosmeticsState): LuaTuple<[boolean, boolean]> {
	const owned = (cosmetics.CrateSkins !== undefined && cosmetics.CrateSkins[skin.Id] === true) || skin.Default === true;
	const equipped = (cosmetics.CrateSkin ?? ShopCatalog.DEFAULT_SKIN) === skin.Id;
	return $tuple(owned, equipped);
}

interface SkinPreviewProps {
	skin: SkinDef;
	state: ShopState;
	cosmetics: CosmeticsState;
	stack: boolean;
	busy: boolean;
	onAction: (action: string, id: string) => void;
	reducedMotion?: boolean;
}

function SkinPreview(props: SkinPreviewProps) {
	const skin = props.skin;
	const stack = props.stack;
	const [owned, equipped] = skinStatus(skin, props.cosmetics);
	const accent = skinAccent(skin.Id);
	const price = skin.Price;
	const have = price !== undefined ? (tonumber(props.state[price.Currency]) ?? 0) : 0;
	const short = price !== undefined ? math.max(0, price.Amount - have) : 0;
	const [peek, setPeek] = React.useState(false);
	let action: string | undefined;
	let label: string;
	let enabled: boolean;
	if (equipped) {
		[action, label, enabled] = [undefined, "EQUIPPED", false];
	} else if (owned) {
		[action, label, enabled] = ["EquipCrateSkin", "EQUIP", true];
	} else if (skin.DailyOnly === true) {
		[action, label, enabled] = [undefined, "DAILY SHOP ONLY", false];
	} else if (short > 0) {
		[action, label, enabled] = [undefined, `NEED ${commas(short)} ${price!.Currency.upper()}`, false];
	} else {
		[action, label, enabled] = ["BuyCrateSkin", `BUY · ${commas(price!.Amount)} ${price!.Currency.upper()}`, true];
	}
	enabled = enabled && !props.busy;
	const modelSize = stack ? 200 : 250;
	return h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			accent: accent,
			background: Palette.panelRaised,
			padding: 14,
			highlight: true,
			reducedMotion: props.reducedMotion,
			clips: false,
		},
		h(
			"textbutton",
			{
				Size: stack ? new UDim2(1, 0, 0, modelSize) : UDim2.fromOffset(modelSize, modelSize),
				BackgroundColor3: Palette.void,
				BackgroundTransparency: 0.2,
				BorderSizePixel: 0,
				AutoButtonColor: false,
				Text: "",
				Event: {
					Activated: () => {
						setPeek(!peek);
						Audio.play(peek ? "close" : "crateOpen");
					},
				},
			},
			h("uicorner", { CornerRadius: new UDim(0, 14) }),
			h("uigradient", {
				Color: new ColorSequence(darken(accent, 0.5), Palette.void),
				Rotation: 90,
			}),
			h(CrateModel, {
				skin: skin.Id,
				spin: true,
				open: peek ? 1 : 0,
				live: !props.reducedMotion,
				zoom: 0.82,
			}),
			h(Text, {
				value: peek ? "Tap to close" : "Tap to look inside",
				size: 11,
				color: Palette.muted,
				align: Enum.TextXAlignment.Center,
				position: new UDim2(0, 0, 1, -20),
				sizeConstraint: new UDim2(1, 0, 0, 16),
			}),
		),
		h(
			"frame",
			{
				Size: stack ? new UDim2(1, 0, 1, -(modelSize + 8)) : new UDim2(1, -(modelSize + 16), 1, 0),
				Position: stack ? UDim2.fromOffset(0, modelSize + 8) : UDim2.fromOffset(modelSize + 16, 0),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h(Badge, {
				value: (skin.Tier ?? "Common").upper(),
				accent: TIER_COLOR[skin.Tier ?? ""] ?? accent,
				filled: true,
				size: UDim2.fromOffset(92, 20),
			}),
			h(Text, {
				value: skin.Name,
				size: 22,
				color: Palette.cream,
				weight: Enum.FontWeight.Heavy,
				fit: true,
				minSize: 14,
				position: UDim2.fromOffset(0, 26),
				sizeConstraint: new UDim2(1, 0, 0, 30),
			}),
			h(Text, {
				value: skin.Blurb,
				size: 13,
				color: Palette.creamSoft,
				wrap: true,
				position: UDim2.fromOffset(0, 60),
				sizeConstraint: new UDim2(1, 0, 0, 40),
			}),
			h(Text, {
				value: owned ? "Yours. Every crate you open wears the equipped skin." : "Equip this skin for its guaranteed essence bonus.",
				size: 11,
				color: accent,
				weight: Enum.FontWeight.Bold,
				wrap: true,
				position: UDim2.fromOffset(0, 104),
				sizeConstraint: new UDim2(1, 0, 0, 30),
			}),
			h(
				"frame",
				{
					Name: "SkinClaim",
					Size: new UDim2(1, 0, 0, TapTarget),
					Position: new UDim2(0, 0, 1, -TapTarget),
					BackgroundTransparency: 1,
					BorderSizePixel: 0,
				},
				h(Button, {
					text: label,
					icon: equipped ? "Check.12" : enabled ? "Shop.8" : "Lock.9",
					onClick: () => {
						if (action !== undefined) {
							props.onAction(action, skin.Id);
						}
					},
					color: enabled ? accent : Palette.panelSoft,
					textColor: enabled ? Palette.ink : Palette.creamSoft,
					size: UDim2.fromScale(1, 1),
					disabled: !enabled,
					reducedMotion: props.reducedMotion,
					highlight: enabled,
					selectable: enabled,
				}),
			),
		),
	);
}

interface SkinCardProps {
	skin: SkinDef;
	cosmetics: CosmeticsState;
	selected: boolean;
	order: number;
	onSelect: () => void;
}

function SkinCard(props: SkinCardProps) {
	const skin = props.skin;
	const [owned, equipped] = skinStatus(skin, props.cosmetics);
	const accent = skinAccent(skin.Id);
	return h(
		"textbutton",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: props.selected ? darken(accent, 0.5) : Palette.panel,
			BorderSizePixel: 0,
			AutoButtonColor: false,
			Text: "",
			LayoutOrder: props.order,
			Event: {
				Activated: () => {
					Audio.play("tabSwitch");
					props.onSelect();
				},
			},
		},
		h("uicorner", { CornerRadius: new UDim(0, 14) }),
		h("uistroke", {
			Color: accent,
			Thickness: props.selected ? 2 : 1,
			Transparency: props.selected ? 0 : 0.55,
		}),
		h(CrateModel, {
			skin: skin.Id,
			live: false,
			size: new UDim2(1, 0, 1, -40),
			zoom: 0.9,
		}),
		skin.Id === "Celestial" &&
			h(PrismAura, {
				rarity: "Celestial",
				intensity: 0.7,
				rays: false,
				corner: 14,
			}),
		h(Text, {
			value: skin.Name,
			size: 13,
			color: Palette.cream,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 10,
			align: Enum.TextXAlignment.Center,
			position: new UDim2(0, 6, 1, -38),
			sizeConstraint: new UDim2(1, -12, 0, 18),
		}),
		h(Text, {
			value: equipped
				? "EQUIPPED"
				: owned
					? "OWNED"
					: skin.DailyOnly === true
						? "DAILY SHOP"
						: `${commas(skin.Price!.Amount)} ${skin.Price!.Currency.upper()}`,
			size: 11,
			color: equipped ? Palette.mint : owned ? Palette.creamSoft : accent,
			weight: Enum.FontWeight.Bold,
			align: Enum.TextXAlignment.Center,
			position: new UDim2(0, 6, 1, -20),
			sizeConstraint: new UDim2(1, -12, 0, 16),
		}),
	);
}

function SkinsSection(props: SectionProps) {
	const state = props.state;
	const stack = props.stack;
	const cosmetics = state.Cosmetics ?? { CrateSkins: { Classic: true }, CrateSkin: ShopCatalog.DEFAULT_SKIN };
	const [selected, setSelected] = React.useState(cosmetics.CrateSkin ?? ShopCatalog.DEFAULT_SKIN);
	const [busy, setBusy] = React.useState(false);
	const mounted = React.useRef(true);
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
		};
	}, []);
	const skin = ShopCatalog.skin(selected) ?? ShopCatalog.skin(ShopCatalog.DEFAULT_SKIN);
	const onAction = (action: string, id: string) => {
		if (busy) {
			return;
		}
		setBusy(true);
		props.dispatch(action, { Id: id }, (response) => {
			if (!mounted.current) {
				return;
			}
			setBusy(false);
			if (response.ok) {
				Audio.play(action === "BuyCrateSkin" ? "purchase" : "confirm");
			}
		});
	};
	const columns = stack ? 2 : props.width >= 1000 ? 4 : 3;
	const ownedSkins = cosmetics.CrateSkins ?? {};
	const skinBrowse = Browse.useBrowse({
		id: "Skins",
		items: ShopCatalog.SKINS,
		text: (entry: unknown) => {
			const skinEntry = entry as SkinDef;
			return [skinEntry.Name, skinEntry.Blurb, skinEntry.Tier];
		},
		categories: [
			{ id: "All", label: "All" },
			{
				id: "Owned",
				label: "Owned",
				test: (entry: unknown) => ownedSkins[(entry as SkinDef).Id] === true,
			},
			{
				id: "Locked",
				label: "Not owned",
				test: (entry: unknown) => ownedSkins[(entry as SkinDef).Id] !== true,
			},
		],
	});
	const cells: Record<string, unknown> = {};
	for (const [index, entry] of ipairs(skinBrowse.results as SkinDef[])) {
		cells[entry.Id] = h(SkinCard, {
			skin: entry,
			order: index,
			cosmetics: cosmetics,
			selected: entry.Id === skin?.Id,
			onSelect: () => {
				setSelected(entry.Id);
			},
		});
	}
	const cellH = 156;
	const gridH = rowsHeight(math.max(1, skinBrowse.results.size()), columns, cellH);
	return h(PageScaffold, {
		gap: GAP,
		tailPad: props.tailPad,
		scrollBarColor: Palette.cyan,
		sections: [
			{
				id: "hero",
				height: heroHeight(stack),
				element: h(Hero, {
					title: "Crate Skins",
					body: "Dress the crate you open. The Celestial Ark only ever turns up in the Daily Shop.",
					accent: Palette.cyan,
					icon: "Crate.5",
					state: state,
					stack: stack,
					reveal: props.reveal,
					reducedMotion: props.reducedMotion,
				}),
			},
			{
				id: "preview",
				height: stack ? 200 + 8 + 140 + TapTarget + 28 : 278,
				element: h(SkinPreview, {
					key: skin?.Id,
					skin: skin!,
					state: state,
					cosmetics: cosmetics,
					stack: stack,
					busy: busy,
					onAction: onAction,
					reducedMotion: props.reducedMotion,
				}),
			},
			{
				id: "filter",
				height: Browse.CHIP_H,
				element: h(Browse.ChipRow, {
					options: skinBrowse.categories,
					value: skinBrowse.category,
					onChange: skinBrowse.setCategory,
					counts: skinBrowse.counts,
					accent: Palette.cyan,
				}),
			},
			{
				id: "grid",
				height: gridH,
				element: h(Grid, { columns: columns, cell: cellH, height: gridH, cells: cells }),
			},
		],
	});
}

interface CodexProgressProps {
	config: ShopConfig;
	progress: Record<string, { found: number; total: number }>;
	bonus?: number;
	reducedMotion?: boolean;
}

function CodexProgress(props: CodexProgressProps) {
	const config = props.config;
	const progress = props.progress;
	const bonuses = config.Items?.CodexBonus ?? {};
	const rows: Record<string, unknown> = {
		Layout: h("uilistlayout", {
			FillDirection: Enum.FillDirection.Vertical,
			Padding: new UDim(0, 4),
			SortOrder: Enum.SortOrder.LayoutOrder,
		}),
	};
	for (const [index, rarity] of ipairs(RelicSystem.ORDER)) {
		const row = progress[rarity];
		if (row === undefined || row.total === 0) {
			continue;
		}
		const done = row.found === row.total;
		const color = rarityColor(config, rarity);
		rows[rarity] = h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 22),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				LayoutOrder: index,
			},
			h(Text, {
				value: rarity,
				size: 12,
				color: color,
				weight: Enum.FontWeight.Bold,
				position: UDim2.fromOffset(0, 3),
				sizeConstraint: new UDim2(0, 84, 0, 16),
			}),
			h(Meter, {
				value: row.found / row.total,
				color: color,
				size: new UDim2(1, -230, 0, 8),
				position: UDim2.fromOffset(90, 7),
				reducedMotion: props.reducedMotion,
			}),
			h(Text, {
				value: `${row.found}/${row.total}`,
				size: 12,
				color: Palette.cream,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Right,
				position: new UDim2(1, -134, 0, 3),
				sizeConstraint: UDim2.fromOffset(44, 16),
			}),
			h(Text, {
				value: `${done ? "✓ " : ""}+${math.floor((tonumber(bonuses[rarity]) ?? 0) * 1000 + 0.5) / 10}%`,
				size: 12,
				color: done ? Palette.mint : Palette.muted,
				weight: Enum.FontWeight.Bold,
				align: Enum.TextXAlignment.Right,
				position: new UDim2(1, -84, 0, 3),
				sizeConstraint: UDim2.fromOffset(84, 16),
			}),
		);
	}
	return h(
		Panel,
		{
			size: UDim2.fromScale(1, 1),
			accent: Palette.mint,
			background: Palette.panelRaised,
			padding: 14,
			reducedMotion: props.reducedMotion,
			clips: false,
		},
		h(Text, {
			value: `Codex bonus: +${math.floor((tonumber(props.bonus) ?? 0) * 1000 + 0.5) / 10}% production`,
			size: 16,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			sizeConstraint: new UDim2(1, 0, 0, 22),
		}),
		h(Text, {
			value: "Find every relic of a rarity to earn its bonus for good.",
			size: 12,
			color: Palette.creamSoft,
			position: UDim2.fromOffset(0, 24),
			sizeConstraint: new UDim2(1, 0, 0, 18),
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 1, -50),
				Position: UDim2.fromOffset(0, 50),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			rows,
		),
	);
}

interface RelicCellProps {
	definition: RelicDefinition;
	found: boolean;
	copies: number;
	stars: number;
	canFuse: boolean;
	busy: boolean;
	order: number;
	config: ShopConfig;
	onFuse: () => void;
	reducedMotion?: boolean;
}

function RelicCell(props: RelicCellProps) {
	const definition = props.definition;
	const found = props.found;
	const color = rarityColor(props.config, definition.Rarity);
	const ascended = isAscended(definition.Rarity);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: found ? darken(color, 0.72) : Palette.panel,
			BorderSizePixel: 0,
			LayoutOrder: props.order,
		},
		h("uicorner", { CornerRadius: new UDim(0, 12) }),
		h("uistroke", {
			Color: found ? color : Palette.line,
			Thickness: 1,
			Transparency: found ? 0.25 : 0.5,
		}),
		found &&
			ascended &&
			h(PrismAura, {
				rarity: definition.Rarity,
				intensity: 1,
				rays: false,
				corner: 12,
			}),
		h(Text, {
			value: found ? definition.Name : "???",
			size: 13,
			color: found ? Palette.cream : Palette.muted,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 10,
			position: UDim2.fromOffset(10, 8),
			sizeConstraint: new UDim2(1, -20, 0, 18),
		}),
		h(Text, {
			value: found
				? props.copies > 0
					? `${props.copies} owned${props.stars > 0 ? "  " + "★".rep(props.stars) : ""}`
					: "Found before"
				: `${definition.Slot} relic · not found yet`,
			size: 11,
			color: found ? color : Palette.muted,
			weight: Enum.FontWeight.Bold,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(10, 28),
			sizeConstraint: new UDim2(1, -20, 0, 16),
		}),
		props.canFuse &&
			h(Button, {
				text: "FUSE",
				icon: "Forge.14",
				onClick: props.onFuse,
				color: color,
				textColor: Palette.ink,
				size: new UDim2(1, -20, 0, 30),
				position: new UDim2(0, 10, 1, -38),
				disabled: props.busy,
				reducedMotion: props.reducedMotion,
				highlight: !props.busy,
			}),
	);
}

function CodexSection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const stack = props.stack;
	const items = state.Items ?? {};
	const discovered = items.Discovered ?? {};
	const inventory = items.Inventory ?? {};
	const definitions = config.Items?.Definitions ?? [];
	const maxStars = config.Items?.MaxStars ?? 5;
	const [busy, setBusy] = React.useState(false);
	const mounted = React.useRef(true);
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
		};
	}, []);
	const progress = RelicSystem.codex(discovered, config.Items);
	const copies: Record<string, number> = {};
	const stars: Record<string, number> = {};
	for (const [, instance] of pairs(inventory)) {
		if (typeIs(instance, "table") && typeIs((instance as RelicInstance).DefinitionId, "string")) {
			const id = (instance as RelicInstance).DefinitionId as string;
			copies[id] = (copies[id] ?? 0) + 1;
			stars[id] = math.max(stars[id] ?? 0, RelicSystem.stars(instance));
		}
	}
	const isFound = (definition: RelicDefinition): boolean => {
		return discovered[definition.Id] === true || (copies[definition.Id] ?? 0) > 0;
	};
	const canFuseRelic = (definition: RelicDefinition): boolean => {
		return (copies[definition.Id] ?? 0) >= 2 && RelicSystem.fusionPair(inventory, items.Equipped, definition.Id, maxStars) !== undefined;
	};
	const codexBrowse = Browse.useBrowse({
		id: "Codex",
		items: definitions,
		textKey: tostring((inventory as defined[]).size()),
		text: (definition: unknown) => {
			// undiscovered relics only match on slot and rarity, so search never spoils names
			const def = definition as RelicDefinition;
			if (isFound(def)) {
				return [def.Name, def.Description, def.Rarity, def.Slot, def.EffectKind];
			}
			return [undefined, undefined, def.Rarity, def.Slot];
		},
		categories: [
			{ id: "All", label: "All" },
			{ id: "Found", label: "Found", test: (definition: unknown) => isFound(definition as RelicDefinition) },
			{
				id: "Missing",
				label: "Missing",
				test: (definition: unknown) => !isFound(definition as RelicDefinition),
			},
			{
				id: "Owned",
				label: "Owned",
				test: (definition: unknown) => (copies[(definition as RelicDefinition).Id] ?? 0) > 0,
			},
			{ id: "Fuse", label: "Can fuse", test: (definition: unknown) => canFuseRelic(definition as RelicDefinition) },
		],
	});
	const shownIds: Record<string, boolean> = {};
	for (const definition of codexBrowse.results as RelicDefinition[]) {
		shownIds[definition.Id] = true;
	}
	const fuse = (definition: RelicDefinition) => {
		if (busy) {
			return;
		}
		setBusy(true);
		props.dispatch("FuseRelics", { Id: definition.Id }, (response) => {
			if (!mounted.current) {
				return;
			}
			setBusy(false);
			if (response.ok) {
				Audio.play("autoForge");
			}
		});
	};
	const columns = stack ? 2 : props.width >= 1000 ? 4 : 3;
	const cellH = 96;
	const sections: { id: string; height: number; element: unknown }[] = [
		{
			id: "hero",
			height: heroHeight(stack),
			element: h(Hero, {
				title: "Relic Codex",
				body: `Every relic in the forge. Fuse a spare copy into a relic for a star: +${math.floor((config.Items?.StarBonus ?? 0.25) * 100)}% effect each, up to ${maxStars}.`,
				accent: Palette.mint,
				icon: "Artifact.2",
				state: state,
				stack: stack,
				reveal: props.reveal,
				reducedMotion: props.reducedMotion,
			}),
		},
	];
	let progressRows = 0;
	for (const rarity of RelicSystem.ORDER) {
		if (progress[rarity] !== undefined && progress[rarity].total > 0) {
			progressRows += 1;
		}
	}
	sections.push({
		id: "progress",
		height: 50 + progressRows * 26 + 24,
		element: h(CodexProgress, {
			config: config,
			progress: progress,
			bonus: items.CodexBonus,
			reducedMotion: props.reducedMotion,
		}),
	});
	sections.push({
		id: "browse",
		height: Browse.barHeight(stack, true),
		element: h(Browse.BrowseBar, {
			browse: codexBrowse,
			placeholder: "Search relics by name, slot or rarity",
			accent: Palette.mint,
			stack: stack,
			reducedMotion: props.reducedMotion,
			zIndex: 30,
		}),
	});
	if (codexBrowse.results.size() === 0) {
		sections.push({
			id: "none",
			height: 220,
			element: h(Browse.NoResults, {
				browse: codexBrowse,
				noun: "relics",
				icon: "Artifact.3",
				accent: Palette.mint,
				reducedMotion: props.reducedMotion,
				size: UDim2.fromScale(1, 1),
			}),
		});
	}
	for (let index = RelicSystem.ORDER.size(); index >= 1; index--) {
		const rarity = RelicSystem.ORDER[index - 1];
		const cells: Record<string, unknown> = {};
		let count = 0;
		for (const [order, definition] of ipairs(definitions)) {
			if (definition.Rarity !== rarity || !shownIds[definition.Id]) {
				continue;
			}
			count += 1;
			const canFuse = canFuseRelic(definition);
			cells[definition.Id] = h(RelicCell, {
				definition: definition,
				order: order,
				config: config,
				found: discovered[definition.Id] === true || (copies[definition.Id] ?? 0) > 0,
				copies: copies[definition.Id] ?? 0,
				stars: stars[definition.Id] ?? 0,
				canFuse: canFuse,
				busy: busy,
				onFuse: () => {
					fuse(definition);
				},
				reducedMotion: props.reducedMotion,
			});
		}
		if (count === 0) {
			continue;
		}
		const gridH = rowsHeight(count, columns, cellH);
		const color = rarityColor(config, rarity);
		sections.push({
			id: `label${rarity}`,
			height: 22,
			element: h(Text, {
				value: `${rarity.upper()}  ·  ${progress[rarity].found}/${progress[rarity].total}`,
				size: 13,
				color: color,
				weight: Enum.FontWeight.Heavy,
				sizeConstraint: new UDim2(1, 0, 0, 20),
			}),
		});
		sections.push({
			id: `grid${rarity}`,
			height: gridH,
			element: h(Grid, { columns: columns, cell: cellH, height: gridH, cells: cells }),
		});
	}
	return h(PageScaffold, {
		gap: GAP,
		tailPad: props.tailPad,
		scrollBarColor: Palette.mint,
		sections: sections,
	});
}

function artifactEffectText(artifact: ArtifactDef): string {
	const per = tonumber(artifact.EffectPerLevel) ?? 0;
	if (artifact.EffectKind === "OfflineHours") {
		return `+${"%.2f".format(per)}h offline cap per level`;
	}
	return `+${"%.1f".format(per * 100)}% ${artifact.EffectKind} per level`;
}

interface ElementSheet {
	Image?: string;
	Color?: Color3;
	Glow?: Color3;
	Label?: string;
}
const elementSheet = ElementFxModule.sheet as unknown as (element?: string) => ElementSheet | undefined;

interface ArtifactCardProps {
	artifact: ArtifactDef;
	order: number;
	owned?: OwnedArtifact;
	price?: ArtifactPrice;
	dust: number;
	busy: boolean;
	stack: boolean;
	onBuy: (artifact: ArtifactDef) => void;
	reducedMotion?: boolean;
}

function ArtifactCard(props: ArtifactCardProps) {
	const artifact = props.artifact;
	const tone = ARTIFACT_RARITY[artifact.Rarity] ?? ARTIFACT_RARITY.COMMON;
	const accent = artifact.Color ?? tone.color;
	const element = artifact.Element ?? "Void";
	const sheet = elementSheet(element);
	const elementColor = sheet?.Color ?? accent;
	const elementGlow = sheet?.Glow ?? accent;
	const owned = props.owned;
	const price = props.price;
	const cost = price === undefined ? undefined : owned !== undefined ? price.Refill : price.Stardust;
	const have = tonumber(props.dust) ?? 0;
	const enabled = cost !== undefined && have >= cost && !props.busy;
	const label =
		cost === undefined
			? "NOT SOLD"
			: have < cost
				? `NEED ${commas(cost - have)} DUST`
				: owned !== undefined
					? `+${price!.Fragments} FRAGMENTS · ${commas(cost)}`
					: `ACQUIRE · ${commas(cost)} DUST`;
	const [hovered, setHovered] = React.useState(false);
	const lightH = props.stack ? 116 : 132;
	const fxSize = lightH;
	const elementBadgeW = math.max(62, (sheet?.Label ?? element).size() * 7 + 14);
	return h(
		"frame",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Palette.panel,
			BorderSizePixel: 0,
			LayoutOrder: props.order,
			Event: {
				MouseEnter: () => {
					setHovered(true);
				},
				MouseLeave: () => {
					setHovered(false);
				},
			},
		},
		h("uicorner", { CornerRadius: new UDim(0, 14) }),
		h("uistroke", {
			Color: elementColor.Lerp(accent, 0.35),
			Thickness: hovered || tone.rank >= 5 ? 2 : 1,
			Transparency: hovered ? 0.05 : owned !== undefined ? 0.3 : 0.55,
		}),
		h("uipadding", {
			PaddingTop: new UDim(0, 8),
			PaddingBottom: new UDim(0, 8),
			PaddingLeft: new UDim(0, 8),
			PaddingRight: new UDim(0, 8),
		}),
		h(
			"frame",
			{
				Name: "Stage",
				Size: new UDim2(1, 0, 0, lightH),
				BackgroundColor3: Palette.void,
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
			h("uicorner", { CornerRadius: new UDim(0, 12) }),
			h("uigradient", {
				Color: new ColorSequence(darken(elementColor, 0.6), Palette.void),
				Rotation: 90,
			}),
			h(ElementFx, {
				element: element,
				size: UDim2.fromOffset(fxSize, fxSize),
				position: UDim2.fromScale(0.5, 0.5),
				framerate: 24,
				// acquiring the artifact plays its companion's reveal
				reaction: "reveal",
				reactionKey: owned !== undefined,
				reducedMotion: props.reducedMotion,
				zIndex: 2,
			}),
			h(Badge, {
				value: tone.label.upper(),
				accent: tone.color,
				filled: tone.rank >= 4,
				size: UDim2.fromOffset(84, 18),
				position: UDim2.fromOffset(6, 6),
			}),
			h(Badge, {
				value: sheet?.Label ?? element.upper(),
				accent: elementColor,
				filled: true,
				size: UDim2.fromOffset(elementBadgeW, 18),
				position: new UDim2(1, -(elementBadgeW + 6), 0, 6),
			}),
			artifact.ShopOnly === true && owned === undefined
				? h(Badge, {
					value: "Shop exclusive",
					accent: elementGlow,
					filled: false,
					size: UDim2.fromOffset(106, 18),
					position: new UDim2(1, -112, 1, -24),
				})
				: undefined,
			owned !== undefined
				? h(Badge, {
					value: `LV ${owned.Level ?? 1} · ${owned.Fragments ?? 0} FRAG`,
					accent: Palette.cream,
					filled: false,
					size: UDim2.fromOffset(112, 18),
					position: new UDim2(0, 6, 1, -24),
				})
				: undefined,
		),
		h(Text, {
			value: artifact.Name,
			size: 15,
			color: Palette.cream,
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 11,
			position: UDim2.fromOffset(2, lightH + 8),
			sizeConstraint: new UDim2(1, -4, 0, 20),
		}),
		h(Text, {
			value: artifactEffectText(artifact),
			size: 11,
			color: elementColor.Lerp(Palette.cream, 0.25),
			weight: Enum.FontWeight.Bold,
			position: UDim2.fromOffset(2, lightH + 28),
			sizeConstraint: new UDim2(1, -4, 0, 14),
		}),
		h(Text, {
			value: artifact.Description,
			size: 11,
			color: Palette.muted,
			wrap: true,
			position: UDim2.fromOffset(2, lightH + 44),
			sizeConstraint: new UDim2(1, -4, 0, 28),
		}),
		h(
			"frame",
			{
				Size: new UDim2(1, 0, 0, 36),
				Position: new UDim2(0, 0, 1, -36),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h(Button, {
				text: label,
				icon: enabled ? "Shop.9" : "Lock.10",
				onClick: () => {
					if (enabled) {
						props.onBuy(artifact);
					}
				},
				color: enabled ? elementColor : Palette.panelSoft,
				textColor: enabled ? Palette.ink : Palette.creamSoft,
				size: UDim2.fromScale(1, 1),
				disabled: !enabled,
				reducedMotion: props.reducedMotion,
				highlight: enabled && tone.rank >= 4,
				selectable: enabled,
			}),
		),
	);
}

function ArtifactsSection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const stack = props.stack;
	const ops = config.Operations ?? {};
	const artifacts = ops.Artifacts ?? [];
	const prices = ops.ArtifactShop ?? {};
	const owned = state.Command?.Artifacts ?? {};
	const [busy, setBusy] = React.useState(false);
	const mounted = React.useRef(true);
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
		};
	}, []);
	const ordered = [...artifacts];
	ordered.sort((a, b) => {
		const ra = (ARTIFACT_RARITY[a.Rarity] ?? ARTIFACT_RARITY.COMMON).rank;
		const rb = (ARTIFACT_RARITY[b.Rarity] ?? ARTIFACT_RARITY.COMMON).rank;
		if (ra !== rb) {
			return ra > rb;
		}
		return a.Name < b.Name;
	});
	const dust = tonumber(state.Stardust) ?? 0;
	const browse = Browse.useBrowse({
		id: "Artifacts",
		items: ordered,
		textKey: tostring(dust),
		text: (artifact: unknown) => {
			const entry = artifact as ArtifactDef;
			return [entry.Name, entry.Description, entry.Rarity, entry.EffectKind];
		},
		categories: [
			{ id: "All", label: "All" },
			{
				id: "Missing",
				label: "Missing",
				test: (artifact: unknown) => owned[(artifact as ArtifactDef).Id] === undefined,
			},
			{
				id: "Owned",
				label: "Owned",
				test: (artifact: unknown) => owned[(artifact as ArtifactDef).Id] !== undefined,
			},
			{
				id: "Exclusive",
				label: "Shop exclusive",
				test: (artifact: unknown) => (artifact as ArtifactDef).ShopOnly === true,
			},
			{
				id: "Affordable",
				label: "Affordable",
				test: (artifact: unknown) => {
					const def = artifact as ArtifactDef;
					const price = prices[def.Rarity];
					const cost = price !== undefined ? (owned[def.Id] !== undefined ? price.Refill : price.Stardust) : undefined;
					return cost !== undefined && dust >= cost;
				},
			},
		],
	});
	const onBuy = (artifact: ArtifactDef) => {
		if (busy) {
			return;
		}
		setBusy(true);
		props.dispatch("BuyArtifact", { Id: artifact.Id }, (response) => {
			if (!mounted.current) {
				return;
			}
			setBusy(false);
			Audio.play(response.ok ? "purchase" : "error");
		});
	};
	const columns = stack ? 2 : props.width >= 1000 ? 4 : 3;
	const cellH = stack ? 262 : 282;
	const cells: Record<string, unknown> = {};
	for (const [order, artifact] of ipairs(browse.results as ArtifactDef[])) {
		cells[artifact.Id] = h(ArtifactCard, {
			artifact: artifact,
			order: order,
			owned: owned[artifact.Id],
			price: prices[artifact.Rarity],
			dust: dust,
			busy: busy,
			stack: stack,
			onBuy: onBuy,
			reducedMotion: props.reducedMotion,
		});
	}
	let ownedCount = 0;
	for (const artifact of artifacts) {
		if (owned[artifact.Id] !== undefined) {
			ownedCount += 1;
		}
	}
	const sections: { id: string; height: number; element: unknown }[] = [
		{
			id: "hero",
			height: heroHeight(stack),
			element: h(Hero, {
				title: "Artifact Vault",
				body: `Buy rare artifacts outright for stardust. Ones you hold restock as upgrade fragments. ${ownedCount}/${artifacts.size()} held.`,
				accent: Palette.violet,
				icon: "Artifact.4",
				state: state,
				stack: stack,
				reveal: props.reveal,
				reducedMotion: props.reducedMotion,
			}),
		},
		{
			id: "browse",
			height: Browse.barHeight(stack, true),
			element: h(Browse.BrowseBar, {
				browse: browse,
				placeholder: "Search artifacts by name, effect or rarity",
				accent: Palette.violet,
				stack: stack,
				reducedMotion: props.reducedMotion,
				zIndex: 30,
			}),
		},
	];
	if (browse.results.size() === 0) {
		sections.push({
			id: "none",
			height: 220,
			element: h(Browse.NoResults, {
				browse: browse,
				noun: "artifacts",
				icon: "Artifact.5",
				accent: Palette.violet,
				reducedMotion: props.reducedMotion,
				size: UDim2.fromScale(1, 1),
			}),
		});
	} else {
		const gridH = rowsHeight(browse.results.size(), columns, cellH);
		sections.push({
			id: "grid",
			height: gridH,
			element: h(Grid, { columns: columns, cell: cellH, height: gridH, cells: cells }),
		});
	}
	return h(PageScaffold, {
		gap: GAP,
		tailPad: props.tailPad,
		scrollBarColor: Palette.violet,
		sections: sections,
	});
}

interface StoreFrontProps {
	state?: ShopState;
	config?: ShopConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	initialSection?: string;
	navigate?: (page: string) => void;
	onCrateReveal?: (request: CrateRevealRequest) => void;
	crateRevealActive?: boolean;
	onPurchasePresentationChange?: (open: boolean) => void;
}

function StoreFront(props: StoreFrontProps) {
	const viewport = useViewport();
	const hostRef = React.useRef<Frame>();
	const [contentWidth, setContentWidth] = React.useState(viewport.width);
	React.useEffect(() => {
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const measure = () => {
			if (host.AbsoluteSize.X > 0) {
				setContentWidth(host.AbsoluteSize.X);
			}
		};
		measure();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(measure);
		return () => {
			connection.Disconnect();
		};
	}, []);
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const softMotion = props.reducedMotion;
	const linked = BrowseModel.recall("Shop");
	const [section, setSection] = React.useState(props.initialSection ?? linked?.category ?? "Daily");
	// Quick Find opens a section directly ("crates", "codex", "skins" ...)
	React.useEffect(() => {
		return BrowseModel.listen("Shop", (entry) => {
			if (entry.category !== undefined) {
				setSection(entry.category);
			}
		});
	}, []);
	React.useEffect(() => {
		BrowseModel.remember("Shop", { query: "", category: section });
	}, [section]);
	const reveal = useStagger(0, softMotion);
	const [tabColumns, tabH] = sectionTabLayout(contentWidth, stack ? TapTarget : 44);
	const shared: SectionProps = {
		key: section,
		state: props.state ?? {},
		config: props.config ?? EMPTY_CONFIG,
		dispatch: props.dispatch,
		reducedMotion: softMotion,
		stack: stack,
		width: viewport.width,
		reveal: reveal,
		tailPad: scrollTail(stack, chrome.bottomSafe, 32),
		navigate: props.navigate,
		onCrateReveal: props.onCrateReveal,
		crateRevealActive: props.crateRevealActive,
	};
	let body: unknown;
	if (section === "Daily") {
		body = h(DailySection, shared);
	} else if (section === "Crates") {
		body = h(CratesSection, shared);
	} else if (section === "Skins") {
		body = h(SkinsSection, shared);
	} else if (section === "Codex") {
		body = h(CodexSection, shared);
	} else if (section === "Artifacts") {
		body = h(ArtifactsSection, shared);
	} else {
		body = h(ShopView, {
			state: props.state,
			dispatch: props.dispatch,
			reducedMotion: softMotion,
			onPurchasePresentationChange: props.onPurchasePresentationChange,
		});
	}
	return h(
		"frame",
		{
			Name: "StoreFrontHost",
			ref: hostRef,
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			BorderSizePixel: 0,
			ClipsDescendants: false,
		},
		h(
			"frame",
			{
				Name: "StoreSections",
				Size: new UDim2(1, 0, 0, tabH),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
			},
			h(SegmentedTabs, {
				options: SECTIONS,
				value: section,
				onChange: (entry: unknown) => {
					setSection(entry as string);
				},
				accent: Palette.mango,
				columns: tabColumns,
				gap: 6,
				size: UDim2.fromScale(1, 1),
				reducedMotion: softMotion,
			}),
		),
		h(
			"frame",
			{
				Name: "StoreSection",
				Size: new UDim2(1, 0, 1, -(tabH + GAP)),
				Position: UDim2.fromOffset(0, tabH + GAP),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: false,
			},
			body,
		),
	);
}
const pages: Record<string, () => unknown> = {
	ShopView: () => ({ ShopView }),
	StoreFront: () => ({ StoreFront }),
	CrateRevealStage: () => CrateRevealStageModule,
};

export = (name: string) => {
	const load = pages[name];
	if (load === undefined) {
		error(`PagesShop: unknown module ${tostring(name)}`, 2);
	}
	return load();
};
