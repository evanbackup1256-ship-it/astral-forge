// PagesShop.luau — compiled page bundle for the Shop tab.
// Members are required lazily: PagesShop("WheelView") only pays for that page's code.
import React from "@rbxts/react";
import { counted, memoRow, sameFields } from "../UiCore/rowMemo";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import * as Fmt from "../CoreKit/format";
import { ClientLog } from "../CoreKit/log";
import { chromeFor, darken, Palette, scrollTail, StrokeWidth, TapTarget } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { FlexGrid, useShopColumns } from "../MotionKit/flexbox";
import { MotionFX } from "../UiCore/screenFx";
import { useStagger, useViewport, useWallClock } from "../MotionKit/motion";
import { Icon } from "../ArtKit/Icon";
import BrowseModel = require("../BrowseModel");
import ElementFxModule = require("../ElementFx");
import CrateAppearance = require("../../../Shared/AstralForge/Shared/CrateAppearance");
import * as PlayPolicy from "../../../Shared/AstralForge/Shared/PlayPolicy";
import { usePlayPolicy } from "../CoreKit/playPolicy";
import { SpriteCard } from "./views/PortSpriteCard";
import { splitColumns } from "../UiCore/ui";
import { FocusPlan, useFocusOrder } from "../CoreKit/focusOrder";
import {
	Component,
	loadAudio,
	loadBrowse,
	luauKit,
	sharedModule,
	type BrowseState,
} from "./luauDeps";
import { clientModule } from "./luauKits";
import {
	Bar,
	BODY,
	BODY_BOLD,
	BODY_SEMI,
	Chip,
	Glyph,
	Line,
	MockPanel,
	mockGap,
	NUM,
	PanelHeading,
	panelPad,
	ROW_RADIUS,
	rowFace,
	spaced,
	TITLE_FACE,
} from "../UiCore/mockKit";
import { Grid as MockGrid, headingBlock, IconWell, MockBtn, RowFace } from "./mockRows";
// generated from design/05-shop by scripts/gen_from_layout.js (scripts/layout/shop.spec.json)
import { ShopLayout as L } from "./generated/ShopLayout";
// generated from design/07-crates by scripts/gen_from_layout.js (scripts/layout/crates.spec.json)
import { CratesLayout as CL } from "./generated/CratesLayout";
import { useHeroTabs } from "../UiCore/heroTabs";
import { MockTabs } from "./socialKit";

const MarketplaceService = game.GetService("MarketplaceService");
const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

const { ElementFx } = ElementFxModule;

// Still-Luau dependencies are pulled through their kits like the bundled code did.
// purchase results are announced on the buff strip island like every other notice
const Juice = clientModule<{
	banner(this: void, title: string, subtitle?: string, color?: Color3, icon?: string, duration?: number, tone?: string): void;
}>("JuiceFx");
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
	artifact?: { name: string; rarity?: string; color?: Color3; element?: string; description?: string; fresh?: boolean };
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

const SHOP_TABS = ["Featured", "Flux", "Gems", "Passes", "Codes"];
const SHOP_DEFAULT_LINE = "";
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
	Featured: "Featured",
	Flux: "Flux",
	Gems: "Gems",
	Passes: "Passes",
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
	// catalog icons are "Kind.frame" ids ("Dust.16"); the glyph kind is the part before the dot
	if (name !== undefined) {
		name = name.split(".")[0];
	}
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
		parts.push("Auto-recycle the relics you pick");
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

/** Section/tab switcher in the kit language: .chip pills, the live one a filled .btn in the accent.
 * Desktop lays them on a grid (columns x rows fill the host); phone strip mode scrolls one row. */
function PillTabs(p: {
	options: { id: string; label: string }[];
	value: string;
	onChange: (id: string) => void;
	accent: Color3;
	columns: number;
	gap: number;
	strip?: boolean;
}) {
	const count = p.options.size();
	const columns = math.max(1, p.columns);
	const rows = math.max(1, math.ceil(count / columns));
	const pills: React.Element[] = [];
	for (const [index, option] of ipairs(p.options)) {
		const on = option.id === p.value;
		pills.push(
			<textbutton
				key={option.id}
				Size={p.strip === true ? new UDim2(0, 96, 1, 0) : UDim2.fromScale(1, 1)}
				BackgroundColor3={on ? p.accent : Palette.white}
				BackgroundTransparency={on ? 0 : 0.95}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text={option.label}
				TextSize={13}
				FontFace={BODY_BOLD}
				TextColor3={on ? Palette.ink : Palette.creamSoft}
				TextTruncate={Enum.TextTruncate.AtEnd}
				LayoutOrder={index}
				Event={{
					Activated: () => {
						if (!on) {
							Audio.play("tabSwitch");
							p.onChange(option.id);
						}
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke Color={on ? p.accent : Palette.white} Transparency={on ? 0 : 0.9} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
			</textbutton>,
		);
	}
	if (p.strip === true) {
		return (
			<scrollingframe
				key="Pills"
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				CanvasSize={new UDim2(0, 0, 0, 0)}
				AutomaticCanvasSize={Enum.AutomaticSize.X}
				ScrollingDirection={Enum.ScrollingDirection.X}
				ScrollBarThickness={0}
				Selectable={false}
			>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, p.gap)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				{pills}
			</scrollingframe>
		);
	}
	return (
		<frame key="Pills" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uigridlayout
				CellSize={new UDim2(1 / columns, -(p.gap * (columns - 1)) / columns, 1 / rows, -(p.gap * (rows - 1)) / rows)}
				CellPadding={UDim2.fromOffset(p.gap, p.gap)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{pills}
		</frame>
	);
}

/** 05-shop .tabs segmented control (ShopLayout.Tabs / TabOn / Tab): dark 48px well, tabs hug their label. */
function SegTabs(p: { options: { id: string; label: string }[]; value: string; onChange: (id: string) => void }) {
	const tabs: React.Element[] = [];
	for (const [index, option] of ipairs(p.options)) {
		const on = option.id === p.value;
		tabs.push(
			<textbutton
				key={option.id}
				Size={UDim2.fromOffset(0, L.Tab.h)}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundColor3={Palette.white}
				BackgroundTransparency={on ? 0 : 1}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text={option.label}
				TextSize={L.Tab.text.size}
				FontFace={BODY_BOLD}
				TextColor3={on ? L.TabOn.text.color : L.Tab.text.color}
				LayoutOrder={index}
				Event={{
					Activated: () => {
						if (!on) {
							Audio.play("tabSwitch");
							p.onChange(option.id);
						}
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, L.Tab.radius)} />
				<uipadding PaddingLeft={new UDim(0, L.Tab.pad.left)} PaddingRight={new UDim(0, L.Tab.pad.right)} />
				{on && <uigradient Rotation={L.TabOn.gradient.rotation} Color={L.TabOn.gradient.color} Transparency={L.TabOn.gradient.transparency} />}
			</textbutton>,
		);
	}
	return (
		<frame key="Tabs" Size={UDim2.fromOffset(0, L.Tabs.h)} AutomaticSize={Enum.AutomaticSize.X} BackgroundColor3={L.Tabs.fill!.color} BackgroundTransparency={L.Tabs.fill!.transparency} BorderSizePixel={0} LayoutOrder={1}>
			<uicorner CornerRadius={new UDim(0, L.Tabs.radius)} />
			<uistroke Color={L.Tabs.stroke!.color} Transparency={L.Tabs.stroke!.transparency} Thickness={L.Tabs.stroke!.thickness} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			<uipadding PaddingTop={new UDim(0, L.Tabs.pad.top)} PaddingBottom={new UDim(0, L.Tabs.pad.bottom)} PaddingLeft={new UDim(0, L.Tabs.pad.left)} PaddingRight={new UDim(0, L.Tabs.pad.right)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.Tabs.gap)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{tabs}
		</frame>
	);
}

// ---- Shop (mockup 05-shop, design/system/af.css at 1920x1080; phone = the .p rules) ----
// Every block is a list or grid child: no hand-placed offsets, so nothing can drift onto a sibling.
//   .flexr        featured .pn (620px) | catalog .pn (flex 1), both as tall as the page
//   .pn h3        PanelHeading           grid 2x1fr / 4x1fr   Grid (mockRows) with LayoutOrder cells
//   .row column   UpgradeCard / PackCard (RowFace + padding + vertical UIListLayout)
const SHOP_FEATURED_W = L.Featured.w;
const SHOP_UPGRADE_COLS = 2;

function upgradeCardHeight(phone: boolean): number {
	// .row padding 16, gap 10: 22px head, 18px detail, .btn 44 (phone: tap target)
	// desktop: the 05-shop .row box (141 = pad 16 + head 28 + 10 + line 17 + 10 + .btn 44 + pad 16)
	return phone ? 12 + 22 + 8 + 18 + 8 + TapTarget + 12 : L.UpgradeCard.h;
}

function packCardHeight(phone: boolean): number {
	// .row column padding 14, gap 6: 20px glyph, 26px .big figure (+4 line), 16px unit, .btn.sm 36
	// desktop: the 05-shop gem .row box (122 = pad 14 + glyph 20 + 6 + .big 26 + 6 + .btn.sm 36 + pad 14)
	return phone ? 10 + 18 + 4 + 24 + 4 + 16 + 4 + TapTarget + 10 : L.GemCard.h;
}

/** Card entrance: the face rides `reveal` up 8px inside its grid cell (the cell itself never moves). */
function CardCell(p: { name: string; layoutOrder: number; reveal: React.Binding<number>; children?: React.ReactNode }) {
	return (
		<frame key={p.name} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder} ClipsDescendants={false}>
			<frame
				Size={UDim2.fromScale(1, 1)}
				Position={p.reveal.map((amount: number) => UDim2.fromOffset(0, math.round((1 - math.clamp(amount, 0, 1)) * 8)))}
				BackgroundColor3={Palette.white}
				BorderSizePixel={0}
			>
				{p.children}
			</frame>
		</frame>
	);
}

interface UpgradeCardProps {
	title: string;
	chip?: string;
	chipColor?: Color3;
	detail: string;
	cta: string;
	accent: Color3;
	icon: string;
	disabled?: boolean;
	owned?: boolean;
	onClick?: () => void;
	layoutOrder: number;
	staggerIndex?: number;
	reducedMotion?: boolean;
	phone: boolean;
}

// .row (column): glyph + 17px name + chip pushed right / 14px muted line / full-width .btn in the accent
function UpgradeCardImpl(props: UpgradeCardProps) {
	const phone = props.phone;
	const pad = phone ? 12 : L.UpgradeCard.pad.top;
	const headH = phone ? 22 : L.UpgradeHead.h;
	const reveal = useStagger(props.staggerIndex ?? 0, props.reducedMotion, 0.036, 0.26);
	const canBuy = props.owned !== true && props.disabled !== true;
	return (
		<CardCell name="Offer" layoutOrder={props.layoutOrder} reveal={reveal}>
			<RowFace />
			<uipadding PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} PaddingLeft={new UDim(0, pad)} PaddingRight={new UDim(0, pad)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, phone ? 8 : L.UpgradeCard.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame key="Head" Size={new UDim2(1, 0, 0, headH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, L.UpgradeHead.gap)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Glyph kind={props.icon} size={phone ? 18 : L.UpgradeIcon.w} color={props.accent} layoutOrder={1} />
				<frame key="Name" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<Line text={props.title} size={phone ? 15 : L.UpgradeName.text.size} font={BODY_BOLD} color={L.UpgradeName.text.color} width={new UDim(1, 0)} height={phone ? 22 : L.UpgradeName.h} />
				</frame>
				{props.chip !== undefined && <Chip text={props.chip} accent={props.chipColor ?? Palette.mango} phone={true} layoutOrder={3} />}
			</frame>
			<Line text={props.detail} size={phone ? 13 : L.UpgradeLine.text.size} font={BODY} color={L.UpgradeLine.text.color} width={new UDim(1, 0)} height={phone ? 18 : L.UpgradeLine.h} layoutOrder={2} />
			<frame key="ShopBuyCta" Size={new UDim2(1, 0, 0, phone ? TapTarget : L.UpgradeBuy.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
				<MockBtn
					text={props.cta}
					icon={props.owned === true ? "Check.10" : props.disabled === true ? "Lock.6" : undefined}
					accent={props.accent}
					sec={!canBuy}
					disabled={!canBuy}
					fill={true}
					phone={phone}
					onClick={props.onClick}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</CardCell>
	);
}

const UpgradeCard = memoRow<UpgradeCardProps>(counted("ShopOffer", UpgradeCardImpl), ["onClick"],
	sameFields<UpgradeCardProps>(["title", "chip", "chipColor", "detail", "cta", "accent", "icon", "disabled", "owned", "layoutOrder", "staggerIndex", "reducedMotion", "phone"]));

interface PackCardProps {
	figure: string;
	unit: string;
	cta: string;
	accent: Color3;
	icon: string;
	disabled?: boolean;
	onClick?: () => void;
	layoutOrder: number;
	staggerIndex?: number;
	reducedMotion?: boolean;
	phone: boolean;
}

// .row (column, centred): glyph / .big 26px figure / unit / .btn.sm pink price pill
function PackCardImpl(props: PackCardProps) {
	const phone = props.phone;
	const pad = phone ? 10 : L.GemCard.pad.top;
	const reveal = useStagger(props.staggerIndex ?? 0, props.reducedMotion, 0.036, 0.26);
	const canBuy = props.disabled !== true;
	return (
		<CardCell name="Pack" layoutOrder={props.layoutOrder} reveal={reveal}>
			<RowFace />
			<uipadding PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} PaddingLeft={new UDim(0, pad)} PaddingRight={new UDim(0, pad)} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Vertical}
				Padding={new UDim(0, phone ? 4 : L.GemCard.gap)}
				HorizontalAlignment={Enum.HorizontalAlignment.Center}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<Glyph kind={props.icon} size={phone ? 18 : L.GemIcon.w} color={props.accent} layoutOrder={1} />
			<Line text={props.figure} size={phone ? 20 : L.GemFigure.text.size} font={NUM} color={L.GemFigure.text.color} width={new UDim(1, 0)} height={phone ? 24 : L.GemFigure.h} align={Enum.TextXAlignment.Center} layoutOrder={2} />
			{/* desktop 05-shop gem card is glyph / figure / price: the unit reads from the glyph; phone keeps its line */}
			{phone && <Line text={props.unit} size={12} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={16} align={Enum.TextXAlignment.Center} layoutOrder={3} />}
			<frame key="ShopBuyCta" Size={new UDim2(1, 0, 0, phone ? TapTarget : L.GemBuy.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<MockBtn
					text={props.cta}
					icon={canBuy ? undefined : "Lock.6"}
					accent={L.GemBuy.accent}
					sec={!canBuy}
					disabled={!canBuy}
					sm={true}
					fill={true}
					phone={phone}
					onClick={props.onClick}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</CardCell>
	);
}

const PackCard = memoRow<PackCardProps>(counted("ShopPack", PackCardImpl), ["onClick"],
	sameFields<PackCardProps>(["figure", "unit", "cta", "accent", "icon", "disabled", "layoutOrder", "staggerIndex", "reducedMotion", "phone"]));

/** The pack's headline amount and unit (".big 40" + "gems"); non-numeric rewards show the item name. */
function packFigure(product: DevProduct): LuaTuple<[string, string]> {
	const reward = product.Reward;
	if (reward !== undefined) {
		if (typeIs(reward.Stardust, "number")) return $tuple(Fmt.compactNumber(reward.Stardust), "stardust");
		if (typeIs(reward.Cores, "number")) return $tuple(Fmt.compactNumber(reward.Cores), reward.Cores === 1 ? "core" : "cores");
		if (reward.Cash !== undefined) return $tuple(Fmt.compactNumber(reward.Cash), "flux");
		if (reward.CashMinutes !== undefined) return $tuple(`${reward.CashMinutes}m`, "of production");
		if (typeIs(reward.Signals, "number")) return $tuple(Fmt.compactNumber(reward.Signals), "signals");
	}
	return $tuple(product.Name, rewardLine(reward));
}

/** Gems = the premium currencies (stardust, cores); everything else is a flux-side pack. */
function isGemPack(product: DevProduct): boolean {
	return product.Reward !== undefined && (product.Reward.Stardust !== undefined || product.Reward.Cores !== undefined);
}

interface FeaturedPanelProps {
	product: DevProduct;
	cta: string;
	disabled: boolean;
	onClick: () => void;
	phone: boolean;
	height: number;
	layoutOrder: number;
	reveal?: React.Binding<number>;
	reducedMotion?: boolean;
}

// the 05-shop "this week" .pn (ShopLayout.Featured*): 12px kicker, 46px title face, 16px line, art
// (flex 1, the 300px figure centred), 58px price button; the amber radial wash at 75% / 30%
function FeaturedPanel(props: FeaturedPanelProps) {
	const product = props.product;
	const phone = props.phone;
	const accent = accentOf(product.Accent);
	const titleSize = phone ? 26 : L.FeaturedTitle.text.size;
	const detail = product.Description !== "" ? product.Description : rewardLine(product.Reward);
	const glow = L.Featured.radialGlow;
	return (
		<MockPanel
			name="Featured"
			size={phone ? new UDim2(1, 0, 0, props.height) : new UDim2(0, SHOP_FEATURED_W, 0, props.height)}
			phone={phone}
			accent={Palette.mango}
			glow={glow.color}
			glowBox={phone ? undefined : glow}
			gap={phone ? undefined : L.Featured.gap}
			reveal={props.reveal}
			reducedMotion={props.reducedMotion}
			layoutOrder={props.layoutOrder}
		>
			<Line
				text={spaced(L.FeaturedKick.text.value)}
				size={L.FeaturedKick.text.size}
				font={BODY_BOLD}
				color={L.FeaturedKick.text.color}
				width={new UDim(1, 0)}
				height={L.FeaturedKick.h}
				layoutOrder={1}
			/>
			<Line text={product.Name} size={titleSize} font={TITLE_FACE} color={L.FeaturedTitle.text.color} width={new UDim(1, 0)} height={phone ? titleSize + 4 : L.FeaturedTitle.h} layoutOrder={2} />
			<textlabel
				key="Detail"
				BackgroundTransparency={1}
				BorderSizePixel={0}
				Text={detail}
				TextSize={phone ? 13 : L.FeaturedLine.text.size}
				FontFace={BODY}
				TextColor3={L.FeaturedLine.text.color}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				TextWrapped={true}
				TextTruncate={Enum.TextTruncate.AtEnd}
				Size={new UDim2(1, 0, 0, phone ? 34 : L.FeaturedLine.h)}
				LayoutOrder={3}
			/>
			<frame key="Art" Size={new UDim2(1, 0, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				{h(Icon, {
					kind: iconOf(product.Icon),
					color: Palette.cream,
					accent: accent,
					size: phone ? 72 : L.FeaturedArt.w,
					spin: false,
					position: UDim2.fromScale(0.5, 0.5),
					anchorPoint: new Vector2(0.5, 0.5),
					reducedMotion: props.reducedMotion,
				})}
			</frame>
			{/* .flexr: price button (flex 1); the struck-through "was" chip needs a sale price the catalog doesn't carry */}
			<frame key="ShopBuyCta" Size={new UDim2(1, 0, 0, phone ? TapTarget : L.FeaturedBuy.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={5}>
				<MockBtn
					text={props.cta}
					icon={props.disabled ? "Lock.6" : undefined}
					accent={L.FeaturedBuy.accent}
					sec={props.disabled}
					disabled={props.disabled}
					fill={true}
					phone={phone}
					onClick={props.onClick}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</MockPanel>
	);
}

interface CatalogBlock {
	name: string;
	icon: string;
	title: string;
	columns: number;
	cellHeight: number;
	count: number;
	cells: React.Element[];
}

function catalogHeight(phone: boolean, blocks: CatalogBlock[]): number {
	const pad = panelPad(phone);
	let inner = 0;
	for (const [index, block] of ipairs(blocks)) {
		const rows = math.max(1, math.ceil(block.count / block.columns));
		inner += (index > 1 ? pad.gap : 0) + headingBlock(phone) + rows * block.cellHeight + (rows - 1) * pad.gap;
	}
	return inner + pad.y * 2;
}

interface ShopViewProps {
	state: ShopState;
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

interface OfferRow {
	Id: string;
	cells: { kind: string; key: string; pass?: GamePass; product?: DevProduct }[];
}

function ShopView(props: ShopViewProps) {
	const state = props.state;
	const dispatch = props.dispatch;
	const reducedMotion = props.reducedMotion;
	const monetization = useMonetization();
	const policy = usePlayPolicy();
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const stack = chrome.contentStack;
	const [tab, setTab] = React.useState("Featured");
	const [hostW, setHostW] = React.useState(viewport.width);
	const [viewH, setViewH] = React.useState(math.max(0, viewport.height - 260));
	const [code, setCode] = React.useState("");
	const [codeFeedback, setCodeFeedback] = React.useState("");
	const [followFeedback, setFollowFeedback] = React.useState("");
	const [followBusy, setFollowBusy] = React.useState(false);
	const [busy, setBusy] = React.useState(false);
	const [banner, setBanner] = React.useState(SHOP_DEFAULT_LINE);
	// true from opening checkout until Roblox (or the server) answers; blocks a second checkout meanwhile
	const [purchasePending, setPurchasePending] = React.useState(false);
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
	const purchasePendingRef = React.useRef(false);
	const setPendingGate = (value: boolean) => {
		purchasePendingRef.current = value;
		setPurchasePending(value);
	};
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
	const openPending = (label: string, seconds?: number) => {
		const timeout = seconds ?? PRODUCT_PENDING_FAILSAFE;
		pendingLabel.current = label;
		const session = sessionRef.current + 1;
		sessionRef.current = session;
		setPendingGate(true);
		clearFailsafe();
		failsafe.current = task.delay(timeout, () => {
			failsafe.current = undefined;
			if (!mountedRef.current || sessionRef.current !== session) {
				return;
			}
			setPendingGate(false);
			setBusyGate(false);
			setBanner("That took too long. Try again.");
		});
	};
	// announce: true puts the result on the buff strip (Robux checkouts); Studio test grants already get a
	// server notice, and a cancelled checkout needs none
	const finishPurchase = (ok: boolean, detail?: string, announce = false) => {
		clearFailsafe();
		sessionRef.current += 1;
		pendingOffer.current = undefined;
		setPendingGate(false);
		setBusyGate(false);
		if (announce) {
			if (ok) {
				Audio.play("purchase");
				Juice.banner("Purchased", detail ?? `${pendingLabel.current} is yours.`, Palette.mint, "Shop", undefined, "Success");
			} else {
				Audio.play("error");
				Juice.banner("Purchase pending", detail ?? "Roblox is still confirming it.", Palette.mango, "Shop", undefined, "Info");
			}
		}
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
					finishPurchase(response.ok !== false, response.ok === false ? response.error : `${label} is yours.`, true);
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
					finishPurchase(
						response.ok !== false,
						response.ok === false ? (response.error ?? "Pass pending. Reopen the Shop in a moment.") : "Pass unlocked. Its bonuses are active now.",
						true,
					);
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
		if (busyRef.current || purchasePendingRef.current) {
			return;
		}
		const run = () => {
			if (!mountedRef.current) {
				return;
			}
			if (busyRef.current || purchasePendingRef.current) {
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
		if (busyRef.current || owned[pass.Key] === true || purchasePendingRef.current) {
			return;
		}
		const run = () => {
			if (!mountedRef.current) {
				return;
			}
			if (busyRef.current || purchasePendingRef.current || owned[pass.Key] === true) {
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
		if (trimmed === "" || busyRef.current || purchasePendingRef.current) {
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
	// keys and spins for Robux aren't sold where paid random items are restricted
	const products = monetization.DevProducts.filter((product) => !PlayPolicy.productBlocked(policy, product));
	const passes = monetization.GamePasses;
	const listCount =
		tab === "Codes"
			? 1
			: tab === "Passes"
				? passes.size()
				: tab === "Featured"
					? math.min(products.size(), 5) + math.min(passes.size(), 4)
					: products.size();
	const codeReady = code.gsub("%s", "")[0] !== "";
	const redeemDisabled = busy || !codeReady || purchasePending;
	const shopHostRef = React.useRef<ScrollingFrame>();
	const claimHostRef = React.useRef<Frame>();
	// first measure: Change.AbsoluteSize only fires on later resizes
	React.useEffect(() => {
		const host = shopHostRef.current;
		if (host === undefined) {
			return;
		}
		if (host.AbsoluteWindowSize.X > 0) {
			setHostW(host.AbsoluteWindowSize.X);
		}
		if (host.AbsoluteSize.Y > 0) {
			setViewH(host.AbsoluteSize.Y);
		}
	}, []);
	React.useEffect(() => {
		if (purchasePending || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host: GuiObject | undefined = tab === "Codes" ? claimHostRef.current : shopHostRef.current;
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
	}, [tab, purchasePending, listCount, redeemDisabled]);
	// ---- layout (mockup 05-shop) ----
	const phone = stack;
	const pad = panelPad(phone);
	const pageGap = mockGap(phone);
	const tabRowH = phone ? TapTarget : L.Tabs.h;
	const tailPad = scrollTail(stack, chrome.bottomSafe, SCROLL_PAD);
	const passCta = (pass: GamePass) => (owned[pass.Key] === true ? "Owned" : priceText(pass.PriceLabel, pass.StudioPrice, pass.PassId));
	const upgradeCell = (pass: GamePass, index: number) => {
		const benefit = passBenefitLine(pass);
		const isOwned = owned[pass.Key] === true;
		const shortBenefit = benefit.size() <= 14;
		return (
			<UpgradeCard
				key={`${tab}-${pass.Key}`}
				layoutOrder={index}
				staggerIndex={index}
				title={pass.Name}
				chip={isOwned ? "Owned" : shortBenefit ? benefit : undefined}
				chipColor={isOwned ? Palette.green : Palette.mango}
				detail={shortBenefit || isOwned ? pass.Description : benefit}
				cta={passCta(pass)}
				accent={accentOf(pass.Accent)}
				icon={iconOf(pass.Icon)}
				disabled={(pass.PassId <= 0 && !RunService.IsStudio()) || busy}
				owned={isOwned}
				onClick={() => promptPass(pass)}
				reducedMotion={softMotion}
				phone={phone}
			/>
		);
	};
	const packCell = (product: DevProduct, index: number, stagger: number) => {
		const [figure, unit] = packFigure(product);
		return (
			<PackCard
				key={`${tab}-${product.Key}`}
				layoutOrder={index}
				staggerIndex={stagger}
				figure={figure}
				unit={unit}
				cta={priceText(product.PriceLabel, product.StudioPrice, product.ProductId)}
				accent={accentOf(product.Accent)}
				icon={iconOf(product.Icon)}
				disabled={(product.ProductId <= 0 && !RunService.IsStudio()) || busy}
				onClick={() => promptProduct(product)}
				reducedMotion={softMotion}
				phone={phone}
			/>
		);
	};
	const featuredProduct = tab === "Featured" ? products[0] : undefined;
	const upgradeList = tab === "Featured" ? passes.filter((_, index) => index < 4) : tab === "Passes" ? passes : [];
	const packList =
		tab === "Featured"
			? (() => {
					// 05-shop lists four gem packs under the upgrades; fall back to any packs if none are gems
					const rest = products.filter((_, index) => index > 0);
					const gems = rest.filter((product) => isGemPack(product));
					return (gems.size() > 0 ? gems : rest).filter((_, index) => index < 4);
				})()
			: tab === "Flux"
				? products.filter((product) => !isGemPack(product))
				: tab === "Gems"
					? products.filter((product) => isGemPack(product))
					: [];
	const packCols = phone ? 2 : 4;
	const blocks: CatalogBlock[] = [];
	if (upgradeList.size() > 0) {
		blocks.push({
			name: "Upgrades",
			icon: "Shop",
			title: tab === "Passes" ? "Game passes" : "Upgrades",
			columns: SHOP_UPGRADE_COLS,
			cellHeight: upgradeCardHeight(phone),
			count: upgradeList.size(),
			cells: upgradeList.map((pass, index) => upgradeCell(pass, index + 1)),
		});
	}
	if (packList.size() > 0) {
		blocks.push({
			name: "Packs",
			icon: tab === "Flux" ? "Flux" : "Dust",
			title: tab === "Flux" ? "Flux" : tab === "Gems" || packList.every((product) => isGemPack(product)) ? "Gems" : "Packs",
			columns: packCols,
			cellHeight: packCardHeight(phone),
			count: packList.size(),
			cells: packList.map((product, index) => packCell(product, index + 1, upgradeList.size() + index + 1)),
		});
	}
	const statusLine = monetization.Error ?? banner;
	const statusH = statusLine !== "" ? 20 : 0;
	// the .flexr row fills the page under the tabs (flex: 1), and grows with the catalog when that is taller
	const fillH = math.max(0, viewH - tailPad - tabRowH - pageGap - (statusH > 0 ? statusH + pageGap : 0));
	const catalogH = blocks.size() > 0 ? catalogHeight(phone, blocks) : 0;
	const showFeatured = featuredProduct !== undefined;
	const split = showFeatured && !phone && hostW >= SHOP_FEATURED_W + pageGap + 420;
	const featuredH = split ? math.max(catalogH, fillH, 560) : phone ? 300 : 560;
	const catalogPanelH = split ? featuredH : math.max(catalogH, showFeatured ? 0 : math.min(fillH, 180));
	const catalogPanel =
		blocks.size() > 0 ? (
			<MockPanel
				name="Catalog"
				size={split ? new UDim2(0, 0, 0, catalogPanelH) : new UDim2(1, 0, 0, catalogPanelH)}
				phone={phone}
				flex={split}
				reveal={catalogReveal}
				reducedMotion={reducedMotion}
				layoutOrder={2}
			>
				{blocks.map((block, index) => (
					<React.Fragment key={block.name}>
						<PanelHeading icon={block.icon} title={block.title} phone={phone} layoutOrder={index * 2 + 1} />
						<MockGrid columns={block.columns} gap={pad.gap} cellHeight={block.cellHeight} count={block.count} layoutOrder={index * 2 + 2}>
							{block.cells}
						</MockGrid>
					</React.Fragment>
				))}
			</MockPanel>
		) : (
			<EmptyNote key="Catalog" name="Catalog" icon="Shop.5" title="Nothing listed" body="Check back after the next restock." accent={Palette.mango} phone={phone} reducedMotion={reducedMotion} layoutOrder={2} />
		);
	const featuredPanel =
		featuredProduct !== undefined ? (
			<FeaturedPanel
				key={`featured-${featuredProduct.Key}`}
				product={featuredProduct}
				cta={priceText(featuredProduct.PriceLabel, featuredProduct.StudioPrice, featuredProduct.ProductId)}
				disabled={(featuredProduct.ProductId <= 0 && !RunService.IsStudio()) || busy}
				onClick={() => promptProduct(featuredProduct)}
				phone={!split}
				height={featuredH}
				layoutOrder={1}
				reveal={heroReveal}
				reducedMotion={reducedMotion}
			/>
		) : undefined;
	// Codes: promo-code .pn and the creator-follow .pn, stacked
	const codeFieldH = phone ? TapTarget : 48;
	const codesBody = (
		<frame key="Codes" Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, pageGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<MockPanel
				name="PromoCodes"
				size={new UDim2(1, 0, 0, pad.y * 2 + headingBlock(phone) + 18 + pad.gap + (phone ? codeFieldH * 2 + pad.gap : codeFieldH) + pad.gap + 18)}
				phone={phone}
				accent={Palette.cyan}
				reducedMotion={softMotion}
				layoutOrder={1}
			>
				<PanelHeading icon="Code" title="Promo codes" accent={Palette.cyan} phone={phone} layoutOrder={1} />
				<Line text="Type a code to claim it. Each one works once." size={phone ? 12 : 14} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={18} layoutOrder={2} />
				<frame key="CodeRow" Size={new UDim2(1, 0, 0, phone ? codeFieldH * 2 + pad.gap : codeFieldH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
					<uilistlayout
						FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
						Padding={new UDim(0, pad.gap)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					<frame
						key="CodeField"
						Size={phone ? new UDim2(1, 0, 0, codeFieldH) : new UDim2(0, 0, 1, 0)}
						BackgroundColor3={Palette.ink}
						BorderSizePixel={0}
						LayoutOrder={1}
					>
						{!phone && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
						<uicorner CornerRadius={new UDim(0, ROW_RADIUS)} />
						{rowFace()}
						<uistroke Color={codeFeedback !== "" ? Palette.cyan : Palette.lineSoft} Thickness={1} Transparency={0.5} />
						<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
						{h("textbox", {
							Size: UDim2.fromScale(1, 1),
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
						})}
					</frame>
					{h(
						"frame",
						{
							Name: "ShopClaimCode",
							Size: phone ? new UDim2(1, 0, 0, codeFieldH) : UDim2.fromOffset(148, codeFieldH),
							BackgroundTransparency: 1,
							BorderSizePixel: 0,
							LayoutOrder: 2,
							ref: claimHostRef,
						},
						<MockBtn
							text={busy ? "Checking…" : "Claim code"}
							icon="Code.1"
							accent={Palette.cyan}
							disabled={redeemDisabled}
							fill={true}
							phone={phone}
							onClick={redeem}
							reducedMotion={softMotion}
						/>,
					)}
				</frame>
				<Line text={codeFeedback} size={12} font={BODY_SEMI} color={Palette.creamSoft} width={new UDim(1, 0)} height={18} layoutOrder={4} />
			</MockPanel>
			<MockPanel
				name="CreatorFollow"
				size={new UDim2(1, 0, 0, pad.y * 2 + (phone ? 52 + pad.gap + TapTarget : 52))}
				phone={phone}
				accent={Palette.mint}
				reducedMotion={softMotion}
				layoutOrder={2}
			>
				<frame key="FollowRow" Size={new UDim2(1, 0, 0, phone ? 52 + pad.gap + TapTarget : 52)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uilistlayout
						FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
						Padding={new UDim(0, phone ? pad.gap : 14)}
						VerticalAlignment={Enum.VerticalAlignment.Center}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					<frame key="Copy" Size={phone ? new UDim2(1, 0, 0, 52) : new UDim2(0, 0, 0, 52)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
						{!phone && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 12)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						<IconWell icon="Pilot.1" accent={Palette.mint} size={phone ? 40 : 44} layoutOrder={1} />
						<frame key="Text" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
							<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
							<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 4)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Line text={`Follow @${creatorName}`} size={phone ? 15 : 17} font={BODY_BOLD} width={new UDim(1, 0)} height={22} layoutOrder={1} />
							<Line
								text={
									followFeedback !== ""
										? followFeedback
										: followClaimed
											? "Reward claimed. Thanks for the follow."
											: "Follow the creator on Roblox, then check here for a one-time reward."
								}
								size={phone ? 12 : 14}
								font={BODY}
								color={followClaimed || followFeedback !== "" ? Palette.mint : Palette.muted}
								width={new UDim(1, 0)}
								height={18}
								layoutOrder={2}
							/>
						</frame>
					</frame>
					<MockBtn
						text={followClaimed ? "Claimed" : followBusy ? "Checking…" : "Check follow"}
						icon={followClaimed ? "Check.10" : "Search.5"}
						accent={Palette.mint}
						disabled={followClaimed || followBusy}
						fill={phone}
						width={phone ? undefined : 190}
						phone={phone}
						onClick={verifyFollow}
						reducedMotion={softMotion}
						layoutOrder={2}
					/>
				</frame>
			</MockPanel>
		</frame>
	);
	// Featured / Flux / Gems / Passes (+ Codes) pill tabs, right-aligned like the hero .tabs
	const pickTab = (entry: string) => {
		setTab(entry);
		setBanner(SHOP_DEFAULT_LINE);
	};
	const tabsRow = (
		<frame key="ShopTabs" Size={new UDim2(1, 0, 0, tabRowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				HorizontalAlignment={Enum.HorizontalAlignment.Right}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{phone ? (
				<frame key="Tabs" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<PillTabs options={SHOP_TAB_OPTIONS} value={tab} onChange={pickTab} accent={Palette.mango} columns={SHOP_TABS.size()} gap={6} strip={true} />
				</frame>
			) : (
				<SegTabs options={SHOP_TAB_OPTIONS} value={tab} onChange={pickTab} />
			)}
		</frame>
	);
	let body: React.Element;
	if (tab === "Codes") {
		body = codesBody;
	} else if (featuredPanel !== undefined) {
		body = (
			<frame
				key="ShopSplit"
				Size={new UDim2(1, 0, 0, split ? featuredH : featuredH + pageGap + catalogPanelH)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				LayoutOrder={3}
			>
				<uilistlayout
					FillDirection={split ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
					Padding={new UDim(0, pageGap)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				{featuredPanel}
				{catalogPanel}
			</frame>
		);
	} else {
		body = catalogPanel;
	}
	return (
		<scrollingframe
			ref={shopHostRef}
			key="ShopViewHost"
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2(0, 0, 0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ScrollBarThickness={4}
			ScrollBarImageColor3={Palette.mango}
			VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
			ElasticBehavior={Enum.ElasticBehavior.Never}
			Selectable={false}
			Change={{
				AbsoluteSize: (rbx: ScrollingFrame) => {
					const size = rbx.AbsoluteWindowSize;
					if (size.X > 0 && math.abs(size.X - hostW) >= 1) {
						setHostW(size.X);
					}
					if (size.Y > 0 && math.abs(rbx.AbsoluteSize.Y - viewH) >= 1) {
						setViewH(rbx.AbsoluteSize.Y);
					}
				},
			}}
		>
			<uipadding PaddingBottom={new UDim(0, tailPad)} PaddingRight={new UDim(0, 2)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, pageGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{tabsRow}
			{statusLine !== "" && (
				<Line text={statusLine} size={13} font={BODY} color={Palette.creamSoft} width={new UDim(1, 0)} height={20} layoutOrder={2} />
			)}
			{body}
		</scrollingframe>
	);
}


const GAP = 10;
// Premium is the mockup 05 storefront (featured bundle, upgrades, gems), so the Shop opens on it
const SECTIONS = [
	{ id: "Premium", label: "Premium" },
	{ id: "Daily", label: "Daily" },
	{ id: "Crates", label: "Crates" },
	{ id: "Skins", label: "Skins" },
	{ id: "Codex", label: "Codex" },
	{ id: "Artifacts", label: "Artifacts" },
];
function sectionTabLayout(width: number, rowHeight: number, phone = false): LuaTuple<[number, number]> {
	const gap = 6;
	// phones get one scrolling row of tabs (PillTabs strip mode), so reserve a single row
	if (phone) {
		return $tuple(SECTIONS.size(), rowHeight);
	}
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

// ---- Store sections (Daily / Crates / Skins / Codex / Artifacts) in the mockup-05 language ----
// Every section is one auto-canvas scroller holding a vertical list of .pn panels (MockPanel) with
// PanelHeading, .row cards (RowFace) in UIGridLayouts, .chip pills and MockBtn buttons. Nothing is
// hand-placed: each block is a list or grid child with a LayoutOrder, sized from the rows it holds.
// Crates follows mockup 07-crates: crate panel (3-up cards + Open 1 / Open 10 / Auto) beside a 520px
// odds + last pulls rail. Frame names stay the gamepad regions storeFocusPlan points at.

function rowsHeight(count: number, columns: number, cell: number, gap: number): number {
	const rows = math.max(1, math.ceil(count / math.max(1, columns)));
	return rows * cell + (rows - 1) * gap;
}

/** A .pn's height for `content` px of stacked children plus its own padding. */
function pnHeight(phone: boolean, content: number): number {
	return content + panelPad(phone).y * 2;
}

/** The section page: an auto-canvas vertical scroller; children are list items with LayoutOrder. */
function SectionPage(p: { phone: boolean; tailPad: number; bar: Color3; children?: React.ReactNode }) {
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2(0, 0, 0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ScrollBarThickness={4}
			ScrollBarImageColor3={p.bar}
			ScrollBarImageTransparency={0.35}
			VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
			ElasticBehavior={Enum.ElasticBehavior.Never}
			Selectable={false}
		>
			<uipadding PaddingBottom={new UDim(0, p.tailPad)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, mockGap(p.phone))} SortOrder={Enum.SortOrder.LayoutOrder} />
			{p.children}
		</scrollingframe>
	);
}

/** .flexr: a fixed-width rail and a flex column side by side (named Main / Side for gamepad columns). */
function SplitRow(p: { phone: boolean; height: number; sideWidth: number; sideOnRight: boolean; main: React.Element; side: React.Element; layoutOrder: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, p.height)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, mockGap(p.phone))} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame key="Main" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.sideOnRight ? 1 : 2}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				{p.main}
			</frame>
			<frame key="Side" Size={new UDim2(0, p.sideWidth, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.sideOnRight ? 2 : 1}>
				{p.side}
			</frame>
		</frame>
	);
}

function chipHeight(phone: boolean): number {
	return phone ? TapTarget : 32;
}

/** Filter pills: .chip (.chip.a for the live one) as buttons, with the match count. */
function FilterChips(p: { browse: BrowseState<unknown>; accent: Color3; phone: boolean; layoutOrder: number; name?: string }) {
	const browse = p.browse;
	const chips: React.Element[] = [];
	for (const [index, option] of ipairs(browse.categories ?? [])) {
		const on = option.id === browse.category;
		const count = browse.counts[option.id];
		chips.push(
			<textbutton
				key={option.id}
				Size={UDim2.fromOffset(0, chipHeight(p.phone))}
				AutomaticSize={Enum.AutomaticSize.X}
				BackgroundColor3={on ? p.accent : Palette.white}
				BackgroundTransparency={on ? 0.8 : 0.95}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text={count !== undefined ? `${option.label}  ${count}` : option.label}
				TextSize={12}
				FontFace={BODY_BOLD}
				TextColor3={on ? Palette.cream : Palette.creamSoft}
				LayoutOrder={index}
				Event={{
					Activated: () => {
						Audio.play("tabSwitch");
						browse.setCategory(option.id);
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, 8)} />
				<uistroke Color={on ? p.accent : Palette.white} Transparency={on ? 0.4 : 0.9} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
			</textbutton>,
		);
	}
	return (
		<scrollingframe
			key={p.name ?? "Chips"}
			Size={new UDim2(1, 0, 0, chipHeight(p.phone))}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2(0, 0, 0, 0)}
			AutomaticCanvasSize={Enum.AutomaticSize.X}
			ScrollingDirection={Enum.ScrollingDirection.X}
			ScrollBarThickness={0}
			Selectable={false}
			LayoutOrder={p.layoutOrder}
			{...(p.name !== undefined ? { Name: p.name } : {})}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{chips}
		</scrollingframe>
	);
}

function searchHeight(phone: boolean): number {
	return phone ? TapTarget : 40;
}

/** Search field on a .row face: glyph, text box (flex), Clear when there is a query. */
function SearchField(p: { browse: BrowseState<unknown>; placeholder: string; accent: Color3; phone: boolean; reducedMotion?: boolean; layoutOrder: number }) {
	const browse = p.browse;
	return (
		<frame Size={new UDim2(1, 0, 0, searchHeight(p.phone))} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={p.layoutOrder}>
			<RowFace outline={browse.query !== "" ? p.accent : undefined} />
			<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 4)} />
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Glyph kind="Search.9" size={16} color={browse.query !== "" ? p.accent : Palette.muted} layoutOrder={1} />
			<textbox
				key="Query"
				Size={new UDim2(0, 0, 1, 0)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClearTextOnFocus={false}
				Text={browse.query}
				PlaceholderText={p.placeholder}
				PlaceholderColor3={Palette.muted}
				TextSize={14}
				FontFace={BODY}
				TextColor3={Palette.cream}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextTruncate={Enum.TextTruncate.AtEnd}
				LayoutOrder={2}
				Change={{
					Text: (box: TextBox) => {
						if (box.Text !== browse.query) {
							browse.setQuery(box.Text);
						}
					},
				}}
			>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
			</textbox>
			{browse.query !== "" && (
				<MockBtn text="Clear" sec={true} sm={true} phone={p.phone} width={72} onClick={() => browse.setQuery("")} reducedMotion={p.reducedMotion} layoutOrder={3} />
			)}
		</frame>
	);
}

function browseHeight(phone: boolean): number {
	return searchHeight(phone) + (phone ? 8 : 10) + chipHeight(phone);
}

/** The search + filter block (gamepad region "browse"). */
function BrowseBlock(p: { browse: BrowseState<unknown>; placeholder: string; accent: Color3; phone: boolean; reducedMotion?: boolean; layoutOrder: number }) {
	const gap = p.phone ? 8 : 10;
	return (
		<frame Size={new UDim2(1, 0, 0, browseHeight(p.phone))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={p.layoutOrder} ZIndex={30} {...{ Name: "browse" }}>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<SearchField browse={p.browse} placeholder={p.placeholder} accent={p.accent} phone={p.phone} reducedMotion={p.reducedMotion} layoutOrder={1} />
			<FilterChips browse={p.browse} accent={p.accent} phone={p.phone} layoutOrder={2} />
		</frame>
	);
}

const EMPTY_NOTE_H = 196;

/** Empty / no-match block: a .row face with glyph, 17px title, muted line and an optional reset. */
function EmptyNote(p: { icon: string; title: string; body: string; accent: Color3; phone: boolean; action?: string; onAction?: () => void; reducedMotion?: boolean; layoutOrder?: number; name?: string }) {
	return (
		<frame Size={new UDim2(1, 0, 0, EMPTY_NOTE_H)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={p.layoutOrder ?? 0} {...(p.name !== undefined ? { Name: p.name } : {})}>
			<RowFace />
			<uipadding PaddingLeft={new UDim(0, 16)} PaddingRight={new UDim(0, 16)} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Vertical}
				Padding={new UDim(0, 8)}
				HorizontalAlignment={Enum.HorizontalAlignment.Center}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<Glyph kind={p.icon} size={28} color={p.accent} layoutOrder={1} />
			<Line text={p.title} size={17} font={BODY_BOLD} width={new UDim(1, 0)} height={22} align={Enum.TextXAlignment.Center} layoutOrder={2} />
			<Line text={p.body} size={13} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={18} align={Enum.TextXAlignment.Center} layoutOrder={3} />
			{p.action !== undefined && <MockBtn text={p.action} accent={p.accent} sm={true} phone={p.phone} onClick={p.onAction} reducedMotion={p.reducedMotion} layoutOrder={4} />}
		</frame>
	);
}

/** Browse.NoResults in the kit language: names the query/filter and offers to clear it. */
function NoMatches(p: { browse: BrowseState<unknown>; noun: string; icon: string; accent: Color3; phone: boolean; reducedMotion?: boolean; layoutOrder: number }) {
	const browse = p.browse;
	const what = browse.query !== "" ? `No ${p.noun} match "${browse.query}"` : `No ${p.noun} in ${browse.label(browse.category)}`;
	return (
		<EmptyNote
			name="none"
			icon={p.icon}
			title={what}
			body="Clear the search or switch the filter back to All."
			accent={p.accent}
			phone={p.phone}
			action="Show all"
			onAction={() => browse.reset()}
			reducedMotion={p.reducedMotion}
			layoutOrder={p.layoutOrder}
		/>
	);
}

/** One card's inner padding + vertical stack (the .row column). */
function CardBody(p: { pad: number; gap: number; center?: boolean; children?: React.ReactNode }) {
	return (
		<>
			<uipadding PaddingTop={new UDim(0, p.pad)} PaddingBottom={new UDim(0, p.pad)} PaddingLeft={new UDim(0, p.pad)} PaddingRight={new UDim(0, p.pad)} />
			<uilistlayout
				FillDirection={Enum.FillDirection.Vertical}
				Padding={new UDim(0, p.gap)}
				HorizontalAlignment={p.center === true ? Enum.HorizontalAlignment.Center : Enum.HorizontalAlignment.Left}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{p.children}
		</>
	);
}

/** Wrapped copy of a fixed height (the .row 14px line when it needs two lines). */
function Copy(p: { text: string; size: number; height: number; color?: Color3; font?: Font; layoutOrder: number }) {
	return (
		<textlabel
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Text={p.text}
			TextSize={p.size}
			FontFace={p.font ?? BODY}
			TextColor3={p.color ?? Palette.muted}
			TextXAlignment={Enum.TextXAlignment.Left}
			TextYAlignment={Enum.TextYAlignment.Top}
			TextWrapped={true}
			TextTruncate={Enum.TextTruncate.AtEnd}
			Size={new UDim2(1, 0, 0, p.height)}
			LayoutOrder={p.layoutOrder}
		/>
	);
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
	phone: boolean;
	reducedMotion?: boolean;
	policyNote?: string;
	onBuy: () => void;
}

function offerCardHeight(phone: boolean): number {
	// .row column: padding 16 (12), gap 10 (8): 44px head, two-line detail, price line, .btn
	return phone ? 12 + 40 + 8 + 30 + 8 + 24 + 8 + TapTarget + 12 : 16 + 44 + 10 + 34 + 10 + 26 + 10 + 44 + 16;
}

// .row (column): art well + 17px name / stock line + deal chip; detail; currency price (was ...); .btn
function OfferCardImpl(props: OfferCardProps) {
	const offer = props.offer;
	const phone = props.phone;
	const accent = offerAccent(offer, props.config);
	const reveal = useStagger(props.index, props.reducedMotion, 0.036, 0.26);
	const left = props.left;
	const soldOut = left <= 0;
	const have = tonumber(props.state[offer.Currency]) ?? 0;
	const short = math.max(0, offer.Price - have);
	const blocked = props.policyNote !== undefined;
	const canBuy = !soldOut && !blocked && short === 0 && !props.busy;
	const fullPrice = offer.Deal ? math.floor(offer.Price / (1 - ShopCatalog.DEAL_DISCOUNT) + 0.5) : undefined;
	const cta = soldOut ? "Sold out" : blocked ? "Unavailable" : short > 0 ? `Need ${commas(short)}` : props.pending ? "Buying…" : "Buy";
	const well = phone ? 40 : 44;
	const stock = blocked ? props.policyNote! : soldOut ? "Bought out today" : `${left} left today`;
	return (
		<CardCell name={`Offer${offer.Slot}`} layoutOrder={props.index} reveal={reveal}>
			<RowFace outline={offer.Deal === true ? Palette.mango : undefined} />
			<CardBody pad={phone ? 12 : 16} gap={phone ? 8 : 10}>
				<frame key="Head" Size={new UDim2(1, 0, 0, well)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 12)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					<frame key="Art" Size={UDim2.fromOffset(well, well)} BackgroundColor3={darken(accent, 0.4)} BorderSizePixel={0} ClipsDescendants={true} LayoutOrder={1}>
						<uicorner CornerRadius={new UDim(0, ROW_RADIUS)} />
						<uistroke Color={accent} Thickness={StrokeWidth.hairline} Transparency={0.5} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
						{offer.Kind === "Skin" ? (
							h(CrateModel, { skin: offer.SkinId, live: offer.Deal === true && !props.reducedMotion, spin: true, zoom: 0.95 })
						) : (
							<Glyph kind={KIND_ICON[offer.Kind] ?? "Shop.6"} size={well - 16} color={accent} position={UDim2.fromOffset(8, 8)} />
						)}
					</frame>
					<frame key="Title" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
						<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
						<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 2)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Line text={offer.Name ?? ""} size={phone ? 15 : 17} font={BODY_BOLD} width={new UDim(1, 0)} height={22} layoutOrder={1} />
						<Line text={stock} size={12} font={BODY_BOLD} color={soldOut || blocked ? Palette.muted : accent} width={new UDim(1, 0)} height={16} layoutOrder={2} />
					</frame>
					{offer.Deal === true && <Chip text={`Deal -${math.floor(ShopCatalog.DEAL_DISCOUNT * 100)}%`} accent={Palette.mango} phone={true} layoutOrder={3} />}
				</frame>
				<Copy text={offerDetail(offer, props.config)} size={phone ? 12 : 13} height={phone ? 30 : 34} layoutOrder={2} />
				<frame key="Price" Size={new UDim2(1, 0, 0, phone ? 24 : 26)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Glyph kind={CURRENCY_ICON[offer.Currency] ?? "Dust.3"} size={20} color={currencyColor(offer.Currency)} layoutOrder={1} />
					<Line text={commas(offer.Price)} size={phone ? 18 : 20} font={NUM} layoutOrder={2} />
					{fullPrice !== undefined && <Line text={`was ${commas(fullPrice)}`} size={12} font={BODY} color={Palette.muted} layoutOrder={3} />}
				</frame>
				<frame key="DailyBuy" Size={new UDim2(1, 0, 0, phone ? TapTarget : 44)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
					<MockBtn
						text={cta}
						icon={soldOut ? "Check.11" : blocked || short > 0 ? "Lock.7" : undefined}
						accent={accent}
						sec={!canBuy}
						disabled={!canBuy}
						fill={true}
						phone={phone}
						onClick={props.onBuy}
						reducedMotion={props.reducedMotion}
					/>
				</frame>
			</CardBody>
		</CardCell>
	);
}

// shows: the offer (price, reward, slot), its accent/detail from config, stock left, busy/pending button state,
// stagger index, motion, phone, and only the one wallet balance it prices in (state[offer.Currency]) for "can afford"
const OfferCard = memoRow<OfferCardProps>(counted("DailyOffer", OfferCardImpl), ["onBuy"], (prev, incoming) =>
	sameFields<OfferCardProps>(["offer", "index", "config", "left", "busy", "pending", "phone", "reducedMotion", "policyNote"])(prev, incoming) &&
	prev.state[incoming.offer.Currency] === incoming.state[incoming.offer.Currency]);

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
	const phone = props.stack;
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
	const policy = usePlayPolicy();
	const daily = state.DailyShop ?? {};
	const current = daily.Day === day;
	const owned = current && typeIs(daily.Owned, "table") ? daily.Owned : (state.Cosmetics?.CrateSkins ?? {});
	const bought = current ? (daily.Bought ?? {}) : {};
	const offers = ShopCatalog.roll(Players.LocalPlayer!.UserId, day, owned);
	const columns = phone ? 1 : props.width >= 1000 ? 3 : 2;
	const pad = panelPad(phone);
	const cellH = offerCardHeight(phone);
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
	const cards: React.Element[] = [];
	for (const [index, offer] of ipairs(offers)) {
		cards.push(
			h(OfferCard, {
				key: `${day}-${offer.Id}`,
				offer: offer,
				index: index,
				config: config,
				state: state,
				left: ShopCatalog.remaining(offer, bought),
				busy: pendingSlot !== undefined,
				pending: pendingSlot === offer.Slot,
				phone: phone,
				reducedMotion: props.reducedMotion,
				policyNote: PlayPolicy.offerBlocked(policy, offer),
				onBuy: () => buy(offer),
			}) as React.Element,
		);
	}
	// one binding per mount (B35), so the heading note keeps the same prop between renders
	const resetText = React.useMemo(() => wall.map((now) => `New offers in ${dayClockText(ShopCatalog.secondsLeft(now))}`), [wall]);
	const gridH = rowsHeight(offers.size(), columns, cellH, pad.gap);
	const offersH = pnHeight(phone, headingBlock(phone) + 18 + pad.gap + gridH);
	const marketRowH = phone ? 36 + pad.gap + TapTarget : 44;
	const marketH = pnHeight(phone, headingBlock(phone) + marketRowH);
	const visit = () => {
		if (props.navigate !== undefined) {
			props.navigate("Bazaar");
		}
	};
	return (
		<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.mango}>
			<MockPanel name="offers" size={new UDim2(1, 0, 0, offersH)} phone={phone} accent={Palette.mango} glow={Palette.mango} reveal={props.reveal} reducedMotion={props.reducedMotion} layoutOrder={1}>
				<PanelHeading icon="Calendar.3" title="Daily shop" note={resetText} accent={Palette.mango} phone={phone} layoutOrder={1} />
				<Line text="Six offers a day, picked for you. The first is the Deal of the Day." size={phone ? 13 : 14} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={18} layoutOrder={2} />
				<MockGrid columns={columns} gap={pad.gap} cellHeight={cellH} count={offers.size()} layoutOrder={3}>
					{cards}
				</MockGrid>
			</MockPanel>
			<MockPanel name="market" size={new UDim2(1, 0, 0, marketH)} phone={phone} accent={Palette.coral} reducedMotion={props.reducedMotion} layoutOrder={2}>
				<PanelHeading icon="Jackpot.3" title="The Black Market" accent={Palette.coral} phone={phone} layoutOrder={1} />
				<frame key="Visit" Size={new UDim2(1, 0, 0, marketRowH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uilistlayout
						FillDirection={phone ? Enum.FillDirection.Vertical : Enum.FillDirection.Horizontal}
						Padding={new UDim(0, pad.gap)}
						VerticalAlignment={Enum.VerticalAlignment.Center}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					<frame key="Copy" Size={phone ? new UDim2(1, 0, 0, 36) : new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
						{!phone && <uiflexitem FlexMode={Enum.UIFlexMode.Fill} />}
						<textlabel
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Size={UDim2.fromScale(1, 1)}
							Text="Keys, materials and boosts from the Black Market's hourly shipments."
							TextSize={phone ? 13 : 14}
							FontFace={BODY}
							TextColor3={Palette.creamSoft}
							TextWrapped={true}
							TextXAlignment={Enum.TextXAlignment.Left}
							TextYAlignment={Enum.TextYAlignment.Center}
						/>
					</frame>
					{phone ? (
						<frame key="Go" Size={new UDim2(1, 0, 0, TapTarget)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
							<MockBtn text="Visit market" icon="Visit.1" accent={Palette.coral} fill={true} phone={true} onClick={visit} reducedMotion={props.reducedMotion} />
						</frame>
					) : (
						<MockBtn text="Visit market" icon="Visit.1" accent={Palette.coral} width={190} onClick={visit} reducedMotion={props.reducedMotion} layoutOrder={2} />
					)}
				</frame>
			</MockPanel>
		</SectionPage>
	);
}

// .row min-height 48 (phone 36)
function oddsRowHeight(phone: boolean): number {
	return phone ? 36 : CL.OddsRow.h;
}

interface OddsRowProps {
	row: { rarity: string; chance: number };
	config: ShopConfig;
	order: number;
	top: number;
	phone: boolean;
}

// odds rail .row: 10px rotated swatch, rarity name (flex), 200px thin bar scaled to the top chance, 17px value
function OddsRow(props: OddsRowProps) {
	const row = props.row;
	const phone = props.phone;
	const color = rarityColor(props.config, row.rarity);
	const fill = props.top > 0 ? math.clamp(row.chance / props.top, 0, 1) : 0;
	const ascended = isAscended(row.rarity);
	return (
		<frame Size={new UDim2(1, 0, 0, oddsRowHeight(phone))} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.order}>
			<RowFace />
			{ascended && h(PrismAura, { rarity: row.rarity, intensity: 0.8, rays: false, sparks: false, thickness: 1.5, corner: ROW_RADIUS })}
			<frame key="Body" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uipadding PaddingLeft={new UDim(0, phone ? 14 : CL.OddsRow.pad.left + 2)} PaddingRight={new UDim(0, CL.OddsRow.pad.right)} />
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, CL.OddsRow.gap)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				<frame key="Swatch" Size={UDim2.fromOffset(10, 10)} Rotation={45} BackgroundColor3={color} BorderSizePixel={0} LayoutOrder={1}>
					<uicorner CornerRadius={new UDim(0, 2)} />
				</frame>
				<frame key="Name" Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<Line text={row.rarity} size={phone ? 13 : CL.OddsName.text.size} font={phone ? BODY_SEMI : BODY} width={new UDim(1, 0)} height={oddsRowHeight(phone)} />
				</frame>
				<Bar fill={fill} color={Palette.violet} thin={true} width={new UDim(0, phone ? 120 : CL.OddsBar.w)} layoutOrder={3} />
				<Line text={RelicSystem.chanceText(row.chance)} size={phone ? 14 : CL.OddsValue.text.size} font={NUM} color={Palette.violet} width={new UDim(0, phone ? 64 : 40)} height={CL.OddsValue.h} align={Enum.TextXAlignment.Right} layoutOrder={4} />
			</frame>
		</frame>
	);
}

const OPEN_BATCH = 5;

// Line-art crate drawn in code: a box face, a lid line, a dashed seam and a brass latch (art, not layout).
function CrateGlyph(p: { accent: Color3; side: number; layoutOrder: number }) {
	const accent = p.accent;
	const dashes: React.Element[] = [];
	for (let index = 0; index < 4; index++) {
		dashes.push(
			<frame key={`Dash${index}`} Size={new UDim2(0.14, 0, 0, 2)} Position={new UDim2(0.12 + index * 0.2, 0, 0.3, 0)} BackgroundColor3={Palette.mango} BorderSizePixel={0} />,
		);
	}
	return (
		<frame Size={UDim2.fromOffset(p.side, p.side)} BackgroundColor3={darken(accent, 0.7)} BackgroundTransparency={0.4} BorderSizePixel={0} LayoutOrder={p.layoutOrder}>
			<uicorner CornerRadius={new UDim(0, 4)} />
			<uistroke Color={accent} Thickness={2} Transparency={0} />
			<frame key="Lid" Size={new UDim2(1, 0, 0, 2)} Position={UDim2.fromScale(0, 0.18)} BackgroundColor3={accent} BorderSizePixel={0} />
			<frame key="Spine" Size={new UDim2(0, 2, 0.82, 0)} Position={UDim2.fromScale(0.5, 0.18)} BackgroundColor3={accent} BorderSizePixel={0} />
			<frame key="Seam" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				{dashes}
			</frame>
			<frame key="Latch" Size={UDim2.fromOffset(8, 8)} Position={new UDim2(0.5, -4, 0.5, -2)} BackgroundColor3={Palette.mango} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		</frame>
	);
}

// "Common · Rare · Epic" for short ranges, "Rare to Legendary" for long ones
function crateRangeLine(crate: CrateConfig): string {
	const odds = RelicSystem.odds(crate.Weights);
	if (odds.size() === 0) {
		return "";
	}
	if (odds.size() <= 3) {
		return odds.map((row) => row.rarity).join(" · ");
	}
	return `${odds[0].rarity} to ${odds[odds.size() - 1].rarity}`;
}

// crate card (.row column, centred): desktop metrics from the generated 07-crates CratesLayout.Card
function crateCardHeight(phone: boolean): number {
	return phone ? 12 + 64 + 8 + 20 + 8 + 16 + 8 + TapTarget + 12 : CL.Card.h;
}

interface CrateCardProps {
	crate: CrateConfig;
	selected: boolean;
	order: number;
	keys: number;
	onSelect: () => void;
	phone: boolean;
	reducedMotion?: boolean;
}

function CrateCard(props: CrateCardProps) {
	const crate = props.crate;
	const phone = props.phone;
	const accent = typeIs(crate.Color, "Color3") ? crate.Color : Palette.violet;
	const selected = props.selected;
	// the picked card lifts 4px inside its grid cell (the cell itself never moves)
	const lift = MotionFX.useEase(selected ? 1 : 0, 0.18, props.reducedMotion, 0);
	const pick = () => {
		Audio.play("tabSwitch");
		props.onSelect();
	};
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order}>
			<textbutton
				key="CrateCard"
				Size={UDim2.fromScale(1, 1)}
				Position={lift.map((amount) => UDim2.fromOffset(0, -4 * amount))}
				BackgroundColor3={Palette.white}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text=""
				Event={{ Activated: pick }}
			>
				<RowFace outline={selected ? accent : undefined} strong={selected} />
				<CardBody pad={phone ? 12 : CL.Card.pad.top} gap={phone ? 8 : CL.Card.gap} center={true}>
					<frame key="Well" Size={phone ? UDim2.fromOffset(80, 64) : UDim2.fromOffset(selected ? CL.CardArtOn.w : CL.CardArt.w, selected ? CL.CardArtOn.h : CL.CardArt.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
						<uilistlayout HorizontalAlignment={Enum.HorizontalAlignment.Center} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
						<CrateGlyph accent={accent} side={phone ? 56 : selected ? CL.CardArtOn.w : CL.CardArt.w} layoutOrder={1} />
					</frame>
					<Line text={crate.Name} size={phone ? 15 : CL.CardName.text.size} font={BODY_BOLD} width={new UDim(1, 0)} height={phone ? 20 : CL.CardName.h} align={Enum.TextXAlignment.Center} layoutOrder={2} />
					<Line text={crateRangeLine(crate)} size={phone ? 12 : CL.CardRange.text.size} font={BODY} color={phone ? Palette.muted : CL.CardRange.text.color} width={new UDim(1, 0)} height={phone ? 16 : CL.CardRange.h} align={Enum.TextXAlignment.Center} layoutOrder={3} />
					<frame key="Keys" Size={new UDim2(1, 0, 0, phone ? TapTarget : CL.CardBtn.h)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
						<MockBtn
							text={props.keys > 0 ? `${props.keys} key${props.keys === 1 ? "" : "s"}` : "No keys"}
							accent={Palette.mango}
							sec={props.keys <= 0}
							sm={true}
							fill={true}
							phone={phone}
							onClick={pick}
							reducedMotion={props.reducedMotion}
						/>
					</frame>
				</CardBody>
			</textbutton>
		</frame>
	);
}

interface CratePull {
	id: string;
	definitionId?: string;
	rarity: string;
	salvaged: boolean;
}

function definitionOf(config: ShopConfig, id: string | undefined): RelicDefinition | undefined {
	if (id === undefined) {
		return undefined;
	}
	for (const def of config.Items?.Definitions ?? []) {
		if (def.Id === id) {
			return def;
		}
	}
	return undefined;
}

const CRATE_RAIL_W = CL.Odds.w;
function CratesSection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const phone = props.stack;
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
	const [pulls, setPulls] = React.useState<CratePull[]>([]);
	const pullSeq = React.useRef(0);
	const [auto, setAuto] = React.useState(false);
	// 07-crates .hero .tabs: Crates (picker + odds) / History (this session's pulls; the server keeps no log)
	const [view, setView] = React.useState("Crates");
	const crateTabs = (
		<MockTabs
			options={[
				{ id: "Crates", label: "Crates" },
				{ id: "History", label: "History" },
			]}
			value={view}
			onChange={setView}
			accent={Palette.violet}
			phone={phone}
			reducedMotion={props.reducedMotion}
			fill={phone}
			layoutOrder={0}
		/>
	);
	useHeroTabs(phone ? undefined : crateTabs);
	const attempt = React.useRef(0);
	const mounted = React.useRef(true);
	React.useEffect(() => {
		mounted.current = true;
		return () => {
			mounted.current = false;
		};
	}, []);
	const crate = crateById(config, selected) ?? crates[0];
	const openRef = React.useRef<(count: number) => void>();
	const crateKeys = crate !== undefined ? (keys[crate.Id] ?? 0) : 0;
	React.useEffect(() => {
		if (!auto) {
			return;
		}
		if (crateKeys <= 0) {
			setAuto(false);
			return;
		}
		if (busy || props.crateRevealActive) {
			return;
		}
		const token = task.delay(0.4, () => {
			if (mounted.current) {
				openRef.current?.(1);
			}
		});
		return () => task.cancel(token);
	}, [auto, crateKeys, busy, props.crateRevealActive, crate?.Id]);
	if (crate === undefined) {
		return (
			<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.violet}>
				<EmptyNote icon="Crate" title="No crates right now" body="Crates come back with the next rotation." accent={Palette.mango} phone={phone} layoutOrder={1} />
			</SectionPage>
		);
	}
	const onOpen = (count: number) => {
		if (busy || props.crateRevealActive) {
			return;
		}
		attempt.current += 1;
		const mine = attempt.current;
		setBusy(true);
		// the server opens at most 5 per call, so ×10 is two calls in a row with one reveal for all of them
		const rolls: defined[] = [];
		const finish = () => {
			setBusy(false);
			if (rolls.size() > 0) {
				const fresh: CratePull[] = [];
				for (const roll of rolls as { DefinitionId?: unknown; Rarity?: unknown; AutoSalvaged?: unknown }[]) {
					pullSeq.current += 1;
					fresh.push({
						id: `pull-${pullSeq.current}`,
						definitionId: typeIs(roll.DefinitionId, "string") ? roll.DefinitionId : undefined,
						rarity: typeIs(roll.Rarity, "string") ? roll.Rarity : "Common",
						salvaged: roll.AutoSalvaged === true,
					});
				}
				if (fresh.size() > 0) {
					setPulls((previous) => {
						const merged: CratePull[] = [];
						for (let index = fresh.size() - 1; index >= 0 && merged.size() < 6; index--) {
							merged.push(fresh[index]);
						}
						for (const entry of previous) {
							if (merged.size() >= 6) {
								break;
							}
							merged.push(entry);
						}
						return merged;
					});
				}
			}
			if (rolls.size() > 0 && props.onCrateReveal !== undefined) {
				props.onCrateReveal({
					crateId: crate.Id,
					crateName: crate.Name,
					accent: typeIs(crate.Color, "Color3") ? crate.Color : undefined,
					rolls: rolls,
				});
			}
		};
		const step = (left: number) => {
			const batch = math.min(OPEN_BATCH, left);
			props.dispatch("OpenItemCrate", { Id: crate.Id, Count: batch }, (response) => {
				if (!mounted.current || attempt.current !== mine) {
					return;
				}
				const got = response.ok && typeIs(response.Rolls, "table") ? (response.Rolls as defined[]) : [];
				for (const roll of got) {
					rolls.push(roll);
				}
				if (!response.ok) {
					setAuto(false);
				}
				if (response.ok && left - batch > 0) {
					task.delay(0.25, () => {
						if (mounted.current && attempt.current === mine) {
							step(left - batch);
						}
					});
				} else {
					finish();
				}
			});
		};
		step(count);
	};
	openRef.current = onOpen;
	// mockup 07-crates: crate panel (3-up cards + Open 1 / Open 10 / Auto) beside a 520px odds + last pulls rail
	const pad = panelPad(phone);
	const plan = splitColumns(phone ? 0 : props.width, CRATE_RAIL_W, mockGap(phone));
	const columns = math.clamp(crates.size(), 1, 3);
	const cardH = crateCardHeight(phone);
	const accent = typeIs(crate.Color, "Color3") ? crate.Color : Palette.violet;
	const busyNow = busy || props.crateRevealActive === true;
	const pity = items.Pity?.[crate.Id] ?? 0;
	const pityNote =
		crate.PityAfter !== undefined && crate.PityRarity !== undefined
			? `${crate.PityRarity}+ in ${math.max(1, crate.PityAfter - pity)} opens`
			: undefined;

	// crate cards
	const cards: React.Element[] = [];
	for (const [index, entry] of ipairs(crates)) {
		cards.push(
			<CrateCard
				key={entry.Id}
				crate={entry}
				order={index}
				keys={keys[entry.Id] ?? 0}
				selected={entry.Id === crate.Id}
				phone={phone}
				reducedMotion={props.reducedMotion}
				onSelect={() => {
					setAuto(false);
					setSelected(entry.Id);
				}}
			/>,
		);
	}
	const gridH = rowsHeight(crates.size(), columns, cardH, pad.gap);
	const openH = phone ? TapTarget : 44;
	const autoW = phone ? 96 : math.ceil(CL.Auto.w);
	const openButton = (count: number, order: number) => {
		const can = crateKeys >= count && !busyNow && !auto;
		const label =
			count === 1
				? crateKeys >= 1 ? "Open 1" : "Open 1 · no keys"
				: crateKeys >= count ? `Open ${count} · ${count} keys` : `Open ${count} · ${count - crateKeys} more keys`;
		// .flexr: Open 1 (.btn.sec) and Open 10 (violet) share what Auto leaves
		return (
			<frame key={`Open${count}`} Size={new UDim2(0, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={order}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<MockBtn
					text={label}
					accent={order === 1 ? undefined : Palette.violet}
					sec={order === 1 || !can}
					disabled={!can}
					fill={true}
					phone={phone}
					onClick={() => onOpen(count)}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		);
	};
	const mainContent = headingBlock(phone) + gridH + pad.gap + openH;
	const mainPanel = (
		<MockPanel name="CratesPanel" size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reveal={props.reveal} reducedMotion={props.reducedMotion}>
			<PanelHeading icon="Crate" title="Crates" note={plan.split ? undefined : pityNote} accent={Palette.violet} phone={phone} layoutOrder={1} />
			<frame Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2} {...{ Name: "chips" }}>
				<MockGrid columns={columns} gap={pad.gap} cellHeight={cardH} count={crates.size()}>
					{cards}
				</MockGrid>
			</frame>
			<frame Size={new UDim2(1, 0, 0, openH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3} {...{ Name: "CrateOpen" }}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, mockGap(phone))} SortOrder={Enum.SortOrder.LayoutOrder} />
				{openButton(1, 1)}
				{openButton(10, 2)}
				{/* Auto opens one at a time after each reveal closes; press again to stop, and it stops itself at 0 keys */}
				<MockBtn
					text={auto ? "Stop" : "Auto"}
					icon={auto ? "Close.3" : "Settings"}
					accent={auto ? Palette.coral : undefined}
					sec={!auto}
					disabled={!auto && crateKeys <= 0}
					width={autoW}
					phone={phone}
					onClick={() => setAuto(!auto)}
					reducedMotion={props.reducedMotion}
					layoutOrder={3}
				/>
			</frame>
		</MockPanel>
	);

	// odds rail
	const odds = RelicSystem.odds(crate.Weights);
	let top = 0;
	for (const row of odds) {
		top = math.max(top, row.chance);
	}
	const oddsGap = phone ? 6 : CL.OddsRow2.y - CL.OddsRow.y - CL.OddsRow.h;
	const oddsRows: React.Element[] = [];
	for (const [index, row] of ipairs(odds)) {
		oddsRows.push(<OddsRow key={row.rarity} row={row} config={config} order={index} top={top} phone={phone} />);
	}
	const oddsH = odds.size() * oddsRowHeight(phone) + math.max(0, odds.size() - 1) * oddsGap;
	const pullW = phone ? 120 : 176;
	const pullH = phone ? 160 : 234;
	const pullCards: React.Element[] = [];
	for (const [index, pull] of ipairs(pulls)) {
		const def = definitionOf(config, pull.definitionId);
		const element = def !== undefined && typeIs(def.Element, "string") ? def.Element : undefined;
		pullCards.push(
			h(SpriteCard, {
				key: pull.id,
				name: pull.salvaged ? "Recycled" : def?.Name ?? pull.rarity,
				rarity: pull.rarity,
				color: rarityColor(config, pull.rarity),
				element: element,
				iconKind: pull.salvaged ? "Dust.9" : "Artifact",
				layoutOrder: index,
				size: UDim2.fromOffset(pullW, pullH),
				reducedMotion: props.reducedMotion,
			}) as React.Element,
		);
	}
	// History tab: the pulls grid spans the full section width
	const perRow = math.max(1, math.floor((props.width - pad.x * 2 + pad.gap) / (pullW + pad.gap)));
	const pullRows = math.ceil(pulls.size() / perRow);
	const pullsGridH = pulls.size() > 0 ? pullRows * pullH + (pullRows - 1) * pad.gap : 20;
	const dropsH = headingBlock(phone) + oddsH;
	const pullsH = headingBlock(phone) + pullsGridH;
	const sideContent = dropsH;
	const phoneTabs = phone && (
		<frame key="CrateTabs" Size={new UDim2(1, 0, 0, TapTarget)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
			{crateTabs}
		</frame>
	);
	if (view === "History") {
		return (
			<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.violet}>
				{phoneTabs}
				<frame key="History" Size={new UDim2(1, 0, 0, pnHeight(phone, pullsH))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<MockPanel name="PullsPanel" size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reveal={props.reveal} reducedMotion={props.reducedMotion}>
						<PanelHeading icon="Calendar" title="Pulls this session" accent={accent} phone={phone} layoutOrder={1} />
						{pulls.size() > 0 ? (
							<frame key="Cards" Size={new UDim2(1, 0, 0, pullsGridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
								<uigridlayout CellSize={UDim2.fromOffset(pullW, pullH)} CellPadding={UDim2.fromOffset(pad.gap, pad.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
								{pullCards}
							</frame>
						) : (
							<Line text="Nothing opened yet this session." size={13} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={20} layoutOrder={2} />
						)}
					</MockPanel>
				</frame>
			</SectionPage>
		);
	}
	const sidePanel = (
		<MockPanel name="OddsPanel" size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reveal={props.reveal} reducedMotion={props.reducedMotion}>
			<PanelHeading icon="Info" title={`${crate.Name} odds`} note={pityNote} accent={accent} phone={phone} layoutOrder={1} />
			<frame key="Odds" Size={new UDim2(1, 0, 0, oddsH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, oddsGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{oddsRows}
			</frame>
		</MockPanel>
	);
	if (plan.split) {
		const rowH = pnHeight(phone, math.max(mainContent, sideContent));
		return (
			<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.violet}>
				<SplitRow phone={phone} height={rowH} sideWidth={plan.side} sideOnRight={true} main={mainPanel} side={sidePanel} layoutOrder={1} />
			</SectionPage>
		);
	}
	return (
		<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.violet}>
			{phoneTabs}
			<frame key="Main" Size={new UDim2(1, 0, 0, pnHeight(phone, mainContent))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				{mainPanel}
			</frame>
			<frame key="Side" Size={new UDim2(1, 0, 0, pnHeight(phone, sideContent))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				{sidePanel}
			</frame>
		</SectionPage>
	);
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
	phone: boolean;
	busy: boolean;
	onAction: (action: string, id: string) => void;
	reveal?: React.Binding<number>;
	reducedMotion?: boolean;
}

function skinModelSize(phone: boolean): number {
	return phone ? 200 : 250;
}

function skinPreviewContent(phone: boolean): number {
	const gap = panelPad(phone).gap;
	// model well, tier chips, title-face name, two-line blurb, note, claim .btn
	return skinModelSize(phone) + gap + 24 + gap + 28 + gap + 36 + gap + 30 + gap + (phone ? TapTarget : 44);
}

// .pn "preview": model well (tap to look inside), tier .chip, title-face name, blurb, note, full-width .btn
function SkinPreview(props: SkinPreviewProps) {
	const skin = props.skin;
	const phone = props.phone;
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
		[action, label, enabled] = [undefined, "Equipped", false];
	} else if (owned) {
		[action, label, enabled] = ["EquipCrateSkin", "Equip", true];
	} else if (skin.DailyOnly === true) {
		[action, label, enabled] = [undefined, "Daily Shop only", false];
	} else if (short > 0) {
		[action, label, enabled] = [undefined, `Need ${commas(short)} ${price!.Currency.lower()}`, false];
	} else {
		[action, label, enabled] = ["BuyCrateSkin", `Buy · ${commas(price!.Amount)} ${price!.Currency.lower()}`, true];
	}
	enabled = enabled && !props.busy;
	const tier = skin.Tier ?? "Common";
	return (
		<MockPanel name="preview" size={UDim2.fromScale(1, 1)} phone={phone} accent={accent} glow={accent} reveal={props.reveal} reducedMotion={props.reducedMotion}>
			<textbutton
				key="Model"
				Size={new UDim2(1, 0, 0, skinModelSize(phone))}
				BackgroundColor3={Palette.void}
				BackgroundTransparency={0.2}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text=""
				LayoutOrder={1}
				Event={{
					Activated: () => {
						setPeek(!peek);
						Audio.play(peek ? "close" : "crateOpen");
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, ROW_RADIUS)} />
				<uigradient Color={new ColorSequence(darken(accent, 0.5), Palette.void)} Rotation={90} />
				{h(CrateModel, { skin: skin.Id, spin: true, open: peek ? 1 : 0, live: !props.reducedMotion, zoom: 0.82 })}
				<frame key="Hint" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<uipadding PaddingBottom={new UDim(0, 6)} />
					<uilistlayout VerticalAlignment={Enum.VerticalAlignment.Bottom} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Line text={peek ? "Tap to close" : "Tap to look inside"} size={11} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={16} align={Enum.TextXAlignment.Center} />
				</frame>
			</textbutton>
			<frame key="Tier" Size={new UDim2(1, 0, 0, 24)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Chip text={tier.upper()} accent={TIER_COLOR[tier] ?? accent} phone={true} layoutOrder={1} />
				{equipped ? <Chip text="Equipped" accent={Palette.mint} phone={true} layoutOrder={2} /> : owned ? <Chip text="Owned" phone={true} layoutOrder={2} /> : undefined}
			</frame>
			<Line text={skin.Name} size={phone ? 20 : 24} font={TITLE_FACE} width={new UDim(1, 0)} height={28} layoutOrder={3} />
			<Copy text={skin.Blurb} size={phone ? 13 : 14} height={36} color={Palette.creamSoft} layoutOrder={4} />
			<Copy
				text={owned ? "Yours. Every crate you open wears the equipped skin." : "Equip this skin for its guaranteed essence bonus."}
				size={12}
				height={30}
				color={accent}
				font={BODY_BOLD}
				layoutOrder={5}
			/>
			<frame Size={new UDim2(1, 0, 0, phone ? TapTarget : 44)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={6} {...{ Name: "SkinClaim" }}>
				<MockBtn
					text={label}
					icon={equipped ? "Check.12" : enabled ? undefined : "Lock.9"}
					accent={accent}
					sec={!enabled}
					disabled={!enabled}
					fill={true}
					phone={phone}
					onClick={() => {
						if (action !== undefined) {
							props.onAction(action, skin.Id);
						}
					}}
					reducedMotion={props.reducedMotion}
				/>
			</frame>
		</MockPanel>
	);
}

interface SkinCardProps {
	skin: SkinDef;
	cosmetics: CosmeticsState;
	selected: boolean;
	order: number;
	onSelect: () => void;
}

const SKIN_CELL_H = 156;

// .row cell: crate model, 13px name, status / price line; picked = accent outline
function SkinCardImpl(props: SkinCardProps) {
	const skin = props.skin;
	const [owned, equipped] = skinStatus(skin, props.cosmetics);
	const accent = skinAccent(skin.Id);
	return (
		<textbutton
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={props.selected ? darken(accent, 0.5) : Palette.white}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Text=""
			LayoutOrder={props.order}
			Event={{
				Activated: () => {
					Audio.play("tabSwitch");
					props.onSelect();
				},
			}}
		>
			<RowFace outline={props.selected ? accent : undefined} strong={props.selected} />
			{skin.Id === "Celestial" && h(PrismAura, { rarity: "Celestial", intensity: 0.7, rays: false, corner: ROW_RADIUS })}
			<frame key="Body" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<CardBody pad={8} gap={2} center={true}>
					<frame key="Model" Size={new UDim2(1, 0, 0, SKIN_CELL_H - 16 - 18 - 16 - 4)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
						{h(CrateModel, { skin: skin.Id, live: false, size: UDim2.fromScale(1, 1), zoom: 0.9 })}
					</frame>
					<Line text={skin.Name} size={13} font={BODY_BOLD} width={new UDim(1, 0)} height={18} align={Enum.TextXAlignment.Center} layoutOrder={2} />
					<Line
						text={equipped ? "Equipped" : owned ? "Owned" : skin.DailyOnly === true ? "Daily Shop" : `${commas(skin.Price!.Amount)} ${skin.Price!.Currency.lower()}`}
						size={11}
						font={BODY_BOLD}
						color={equipped ? Palette.mint : owned ? Palette.creamSoft : accent}
						width={new UDim(1, 0)}
						height={16}
						align={Enum.TextXAlignment.Center}
						layoutOrder={3}
					/>
				</CardBody>
			</frame>
		</textbutton>
	);
}

// shows: the skin, owned/equipped from the cosmetics section, selected highlight, grid order
const SkinCard = memoRow<SkinCardProps>(counted("Skin", SkinCardImpl), ["onSelect"], sameFields<SkinCardProps>(["skin", "cosmetics", "selected", "order"]));

const SKIN_RAIL_W = 340;

function SkinsSection(props: SectionProps) {
	const state = props.state;
	const phone = props.stack;
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
	const cards: React.Element[] = [];
	for (const [index, entry] of ipairs(skinBrowse.results as SkinDef[])) {
		cards.push(
			h(SkinCard, {
				key: entry.Id,
				skin: entry,
				order: index,
				cosmetics: cosmetics,
				selected: entry.Id === skin?.Id,
				onSelect: () => {
					setSelected(entry.Id);
				},
			}) as React.Element,
		);
	}
	let ownedCount = 0;
	for (const entry of ShopCatalog.SKINS) {
		const [has] = skinStatus(entry, cosmetics);
		if (has) {
			ownedCount += 1;
		}
	}
	const pad = panelPad(phone);
	const noSkins = skinBrowse.results.size() === 0;
	// desktop with room: the preview becomes a 340px rail beside the filter + grid panel
	const plan = splitColumns(phone ? 0 : props.width, SKIN_RAIL_W, mockGap(phone));
	const gridColumns = phone ? 2 : plan.split ? (plan.main >= 640 ? 3 : 2) : props.width >= 1000 ? 4 : 3;
	const gridH = noSkins ? EMPTY_NOTE_H : rowsHeight(skinBrowse.results.size(), gridColumns, SKIN_CELL_H, pad.gap);
	const mainContent = headingBlock(phone) + chipHeight(phone) + pad.gap + gridH;
	const previewContent = skinPreviewContent(phone);
	const preview =
		skin !== undefined ? (
			<SkinPreview
				key={skin.Id}
				skin={skin}
				state={state}
				cosmetics={cosmetics}
				phone={phone}
				busy={busy}
				onAction={onAction}
				reveal={props.reveal}
				reducedMotion={props.reducedMotion}
			/>
		) : (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />
		);
	const main = (
		<MockPanel name="SkinsPanel" size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.cyan} reveal={props.reveal} reducedMotion={props.reducedMotion}>
			<PanelHeading icon="Crate.5" title="Crate skins" note={`${ownedCount}/${ShopCatalog.SKINS.size()} owned`} accent={Palette.cyan} phone={phone} layoutOrder={1} />
			<FilterChips browse={skinBrowse as unknown as BrowseState<unknown>} accent={Palette.cyan} phone={phone} layoutOrder={2} name="filter" />
			{noSkins ? (
				<EmptyNote
					name="grid"
					icon="Crate.5"
					title={skinBrowse.category === "Locked" ? "You own every skin" : "Nothing matches"}
					body={skinBrowse.category === "Locked" ? "Every crate skin is in your collection. Pick one to wear it." : "Switch the filter back to All to see every skin."}
					accent={Palette.cyan}
					phone={phone}
					layoutOrder={3}
				/>
			) : (
				<frame Size={new UDim2(1, 0, 0, gridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3} {...{ Name: "grid" }}>
					<MockGrid columns={gridColumns} gap={pad.gap} cellHeight={SKIN_CELL_H} count={skinBrowse.results.size()}>
						{cards}
					</MockGrid>
				</frame>
			)}
		</MockPanel>
	);
	if (plan.split) {
		const rowH = pnHeight(phone, math.max(mainContent, previewContent));
		return (
			<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.cyan}>
				<SplitRow phone={phone} height={rowH} sideWidth={plan.side} sideOnRight={false} main={main} side={preview} layoutOrder={1} />
			</SectionPage>
		);
	}
	return (
		<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.cyan}>
			<frame key="Side" Size={new UDim2(1, 0, 0, pnHeight(phone, previewContent))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				{preview}
			</frame>
			<frame key="Main" Size={new UDim2(1, 0, 0, pnHeight(phone, mainContent))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				{main}
			</frame>
		</SectionPage>
	);
}

interface CodexProgressProps {
	config: ShopConfig;
	progress: Record<string, { found: number; total: number }>;
	bonus?: number;
	starLine: string;
	phone: boolean;
	height: number;
	reveal?: React.Binding<number>;
	reducedMotion?: boolean;
}

const CODEX_ROW_H = 22;
const CODEX_ROW_GAP = 6;

function codexRowCount(progress: Record<string, { found: number; total: number }>): number {
	let count = 0;
	for (const rarity of RelicSystem.ORDER) {
		if (progress[rarity] !== undefined && progress[rarity].total > 0) {
			count += 1;
		}
	}
	return count;
}

function codexProgressContent(phone: boolean, rows: number): number {
	const gap = panelPad(phone).gap;
	return headingBlock(phone) + 18 + gap + rows * CODEX_ROW_H + math.max(0, rows - 1) * CODEX_ROW_GAP;
}

function pct(value: number | undefined): string {
	return `+${math.floor((tonumber(value) ?? 0) * 1000 + 0.5) / 10}%`;
}

// .pn "progress": heading (note = codex bonus), star line, one row per rarity: name, flex thin bar, found/total, bonus
function CodexProgressImpl(props: CodexProgressProps) {
	const config = props.config;
	const progress = props.progress;
	const phone = props.phone;
	const bonuses = config.Items?.CodexBonus ?? {};
	const rows: React.Element[] = [];
	for (const [index, rarity] of ipairs(RelicSystem.ORDER)) {
		const row = progress[rarity];
		if (row === undefined || row.total === 0) {
			continue;
		}
		const done = row.found === row.total;
		const color = rarityColor(config, rarity);
		rows.push(
			<frame key={rarity} Size={new UDim2(1, 0, 0, CODEX_ROW_H)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={index}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 10)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Line text={rarity} size={12} font={BODY_BOLD} color={color} width={new UDim(0, phone ? 70 : 84)} height={16} layoutOrder={1} />
				<frame key="Meter" Size={new UDim2(0, 0, 0, 8)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
					<Bar fill={row.found / row.total} color={color} thin={true} width={new UDim(1, 0)} layoutOrder={1} />
				</frame>
				<Line text={`${row.found}/${row.total}`} size={12} font={NUM} width={new UDim(0, 44)} height={16} align={Enum.TextXAlignment.Right} layoutOrder={3} />
				<Line
					text={`${done ? "Complete · " : ""}${pct(tonumber(bonuses[rarity]))}`}
					size={12}
					font={BODY_BOLD}
					color={done ? Palette.mint : Palette.muted}
					width={new UDim(0, phone ? 64 : 110)}
					height={16}
					align={Enum.TextXAlignment.Right}
					layoutOrder={4}
				/>
			</frame>,
		);
	}
	return (
		<MockPanel name="progress" size={new UDim2(1, 0, 0, props.height)} phone={phone} accent={Palette.mint} reveal={props.reveal} reducedMotion={props.reducedMotion} layoutOrder={1}>
			<PanelHeading icon="Artifact.2" title="Relic codex" note={`Codex bonus ${pct(props.bonus)} production`} accent={Palette.mint} phone={phone} layoutOrder={1} />
			<Line text={props.starLine} size={phone ? 12 : 13} font={BODY} color={Palette.creamSoft} width={new UDim(1, 0)} height={18} layoutOrder={2} />
			<frame key="Rows" Size={new UDim2(1, 0, 0, rows.size() * CODEX_ROW_H + math.max(0, rows.size() - 1) * CODEX_ROW_GAP)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
				<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, CODEX_ROW_GAP)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{rows}
			</frame>
		</MockPanel>
	);
}

// shows: per-rarity found/total (compared by value), bonus tiers from config, the bonus total, layout, motion
const CodexProgress = React.memo(
	counted("CodexProgress", CodexProgressImpl),
	sameFields<CodexProgressProps>(["config", "progress", "bonus", "starLine", "phone", "height", "reveal", "reducedMotion"]),
);

interface RelicCellProps {
	definition: RelicDefinition;
	found: boolean;
	copies: number;
	stars: number;
	canFuse: boolean;
	busy: boolean;
	order: number;
	config: ShopConfig;
	phone: boolean;
	onFuse: () => void;
	reducedMotion?: boolean;
}

function relicCellHeight(phone: boolean): number {
	return 10 + 18 + 4 + 16 + 8 + (phone ? TapTarget : 36) + 10;
}

// .row cell: name (??? until found), status line, Fuse .btn.sm when a spare copy can fuse
function RelicCellImpl(props: RelicCellProps) {
	const definition = props.definition;
	const found = props.found;
	const color = rarityColor(props.config, definition.Rarity);
	const ascended = isAscended(definition.Rarity);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={props.order}>
			<RowFace outline={found ? color : undefined} />
			{found && ascended && h(PrismAura, { rarity: definition.Rarity, intensity: 1, rays: false, corner: ROW_RADIUS })}
			<frame key="Body" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<CardBody pad={10} gap={4}>
					<Line text={found ? definition.Name : "???"} size={13} font={BODY_BOLD} color={found ? Palette.cream : Palette.muted} width={new UDim(1, 0)} height={18} layoutOrder={1} />
					<Line
						text={
							found
								? props.copies > 0
									? `${props.copies} owned${props.stars > 0 ? "  " + "★".rep(props.stars) : ""}`
									: "Found before"
								: `${definition.Slot} relic · not found yet`
						}
						size={11}
						font={BODY_BOLD}
						color={found ? color : Palette.muted}
						width={new UDim(1, 0)}
						height={16}
						layoutOrder={2}
					/>
					{props.canFuse && (
						<frame key="Fuse" Size={new UDim2(1, 0, 0, (props.phone ? TapTarget : 36) + 4)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
							<uipadding PaddingTop={new UDim(0, 4)} />
							<MockBtn text="Fuse" icon="Forge.14" accent={color} sm={true} fill={true} disabled={props.busy} phone={props.phone} onClick={props.onFuse} reducedMotion={props.reducedMotion} />
						</frame>
					)}
				</CardBody>
			</frame>
		</frame>
	);
}

// shows: the relic definition (rarity colour from config), found, copies, stars, fuse button (canFuse, busy), order, layout, motion
const RelicCell = memoRow<RelicCellProps>(counted("Relic", RelicCellImpl), ["onFuse"],
	sameFields<RelicCellProps>(["definition", "found", "copies", "stars", "canFuse", "busy", "order", "config", "phone", "reducedMotion"]));

function CodexSection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const phone = props.stack;
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
	const pad = panelPad(phone);
	const columns = phone ? 2 : props.width >= 1000 ? 4 : 3;
	const cellH = relicCellHeight(phone);
	const starLine = `Fuse a spare copy into a relic for a star: +${math.floor((config.Items?.StarBonus ?? 0.25) * 100)}% effect each, up to ${maxStars}.`;
	const progressH = pnHeight(phone, codexProgressContent(phone, codexRowCount(progress)));
	const blocks: React.Element[] = [
		<CodexProgress
			key="progress"
			config={config}
			progress={progress}
			bonus={items.CodexBonus}
			starLine={starLine}
			phone={phone}
			height={progressH}
			reveal={props.reveal}
			reducedMotion={props.reducedMotion}
		/>,
		<BrowseBlock
			key="browse"
			browse={codexBrowse as unknown as BrowseState<unknown>}
			placeholder="Search relics by name, slot or rarity"
			accent={Palette.mint}
			phone={phone}
			reducedMotion={props.reducedMotion}
			layoutOrder={2}
		/>,
	];
	if (codexBrowse.results.size() === 0) {
		blocks.push(<NoMatches key="none" browse={codexBrowse as unknown as BrowseState<unknown>} noun="relics" icon="Artifact.3" accent={Palette.mint} phone={phone} reducedMotion={props.reducedMotion} layoutOrder={3} />);
	}
	// one .pn per rarity, rarest first
	let order = 10;
	for (let index = RelicSystem.ORDER.size(); index >= 1; index--) {
		const rarity = RelicSystem.ORDER[index - 1];
		const cells: React.Element[] = [];
		for (const [defOrder, definition] of ipairs(definitions)) {
			if (definition.Rarity !== rarity || !shownIds[definition.Id]) {
				continue;
			}
			cells.push(
				h(RelicCell, {
					key: definition.Id,
					definition: definition,
					order: defOrder,
					config: config,
					found: discovered[definition.Id] === true || (copies[definition.Id] ?? 0) > 0,
					copies: copies[definition.Id] ?? 0,
					stars: stars[definition.Id] ?? 0,
					canFuse: canFuseRelic(definition),
					busy: busy,
					phone: phone,
					onFuse: () => {
						fuse(definition);
					},
					reducedMotion: props.reducedMotion,
				}) as React.Element,
			);
		}
		if (cells.size() === 0) {
			continue;
		}
		order += 1;
		const color = rarityColor(config, rarity);
		const gridH = rowsHeight(cells.size(), columns, cellH, pad.gap);
		blocks.push(
			<MockPanel
				key={`grid${rarity}`}
				name={`grid${rarity}`}
				size={new UDim2(1, 0, 0, pnHeight(phone, headingBlock(phone) + gridH))}
				phone={phone}
				accent={color}
				reducedMotion={props.reducedMotion}
				layoutOrder={order}
			>
				<PanelHeading icon="Artifact" title={rarity} note={`${progress[rarity]?.found ?? 0}/${progress[rarity]?.total ?? 0} found`} accent={color} phone={phone} layoutOrder={1} />
				<MockGrid columns={columns} gap={pad.gap} cellHeight={cellH} count={cells.size()} layoutOrder={2}>
					{cells}
				</MockGrid>
			</MockPanel>,
		);
	}
	return (
		<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.mint}>
			{blocks}
		</SectionPage>
	);
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
	phone: boolean;
	onBuy: (artifact: ArtifactDef) => void;
	reducedMotion?: boolean;
}

function artifactStageHeight(phone: boolean): number {
	return phone ? 116 : 132;
}

function artifactCardHeight(phone: boolean): number {
	return 10 + artifactStageHeight(phone) + 6 + 20 + 6 + 14 + 6 + 28 + 6 + (phone ? TapTarget : 36) + 10;
}

// .row card: element stage (ElementFx + rarity/element .chips), name, effect, blurb, .btn.sm in the element colour
function ArtifactCard(props: ArtifactCardProps) {
	const artifact = props.artifact;
	const phone = props.phone;
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
			? "Not sold"
			: have < cost
				? `Need ${commas(cost - have)} dust`
				: owned !== undefined
					? `+${price!.Fragments} fragments · ${commas(cost)}`
					: `Acquire · ${commas(cost)} dust`;
	const [hovered, setHovered] = React.useState(false);
	const stageH = artifactStageHeight(phone);
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={props.order}>
			<frame
				key="Face"
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.white}
				BorderSizePixel={0}
				Event={{
					MouseEnter: () => setHovered(true),
					MouseLeave: () => setHovered(false),
				}}
			>
				<RowFace outline={hovered || tone.rank >= 5 || owned !== undefined ? elementColor.Lerp(accent, 0.35) : undefined} strong={hovered || tone.rank >= 5} />
				<CardBody pad={10} gap={6}>
					<frame key="Stage" Size={new UDim2(1, 0, 0, stageH)} BackgroundColor3={Palette.void} BorderSizePixel={0} ClipsDescendants={true} LayoutOrder={1}>
						<uicorner CornerRadius={new UDim(0, ROW_RADIUS)} />
						<uigradient Color={new ColorSequence(darken(elementColor, 0.6), Palette.void)} Rotation={90} />
						{h(ElementFx, {
							element: element,
							size: UDim2.fromOffset(stageH, stageH),
							position: UDim2.fromScale(0.5, 0.5),
							framerate: 24,
							// acquiring the artifact plays its companion's reveal
							reaction: "reveal",
							reactionKey: owned !== undefined,
							reducedMotion: props.reducedMotion,
							zIndex: 2,
						})}
						<frame key="Tags" Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={3}>
							<uipadding PaddingTop={new UDim(0, 6)} PaddingBottom={new UDim(0, 6)} PaddingLeft={new UDim(0, 6)} PaddingRight={new UDim(0, 6)} />
							<uilistlayout FillDirection={Enum.FillDirection.Vertical} VerticalFlex={Enum.UIFlexAlignment.SpaceBetween} SortOrder={Enum.SortOrder.LayoutOrder} />
							<frame key="Top" Size={new UDim2(1, 0, 0, 22)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
								<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalFlex={Enum.UIFlexAlignment.SpaceBetween} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
								<Chip text={tone.label.upper()} accent={tone.color} phone={true} layoutOrder={1} />
								<Chip text={sheet?.Label ?? element.upper()} accent={elementColor} phone={true} layoutOrder={2} />
							</frame>
							<frame key="Bottom" Size={new UDim2(1, 0, 0, 22)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
								<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalFlex={Enum.UIFlexAlignment.SpaceBetween} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
								{owned !== undefined ? <Chip text={`Lv ${owned.Level ?? 1} · ${owned.Fragments ?? 0} frag`} phone={true} layoutOrder={1} /> : undefined}
								{artifact.ShopOnly === true && owned === undefined ? <Chip text="Shop exclusive" accent={elementGlow} phone={true} layoutOrder={2} /> : undefined}
							</frame>
						</frame>
					</frame>
					<Line text={artifact.Name} size={15} font={BODY_BOLD} width={new UDim(1, 0)} height={20} layoutOrder={2} />
					<Line text={artifactEffectText(artifact)} size={11} font={BODY_BOLD} color={elementColor.Lerp(Palette.cream, 0.25)} width={new UDim(1, 0)} height={14} layoutOrder={3} />
					<Copy text={artifact.Description} size={11} height={28} color={Palette.muted} layoutOrder={4} />
					<frame key="Buy" Size={new UDim2(1, 0, 0, phone ? TapTarget : 36)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={5}>
						<MockBtn
							text={label}
							icon={enabled ? "Shop.9" : "Lock.10"}
							accent={elementColor}
							sec={!enabled}
							disabled={!enabled}
							sm={true}
							fill={true}
							phone={phone}
							onClick={() => {
								if (enabled) {
									props.onBuy(artifact);
								}
							}}
							reducedMotion={props.reducedMotion}
						/>
					</frame>
				</CardBody>
			</frame>
		</frame>
	);
}

function ArtifactsSection(props: SectionProps) {
	const state = props.state;
	const config = props.config;
	const phone = props.stack;
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
			if (response.ok && props.onCrateReveal !== undefined) {
				props.onCrateReveal({
					crateId: "Artifact",
					crateName: artifact.Name,
					accent: artifact.Color,
					rolls: [],
					artifact: {
						name: artifact.Name,
						rarity: artifact.Rarity,
						color: artifact.Color,
						element: artifact.Element,
						description: artifact.Description,
						fresh: response.ArtifactNew !== false,
					},
				});
			} else {
				Audio.play(response.ok ? "purchase" : "error");
			}
		});
	};
	const pad = panelPad(phone);
	const columns = phone ? 2 : props.width >= 1000 ? 4 : 3;
	const cellH = artifactCardHeight(phone);
	const cards: React.Element[] = [];
	for (const [order, artifact] of ipairs(browse.results as ArtifactDef[])) {
		cards.push(
			<ArtifactCard
				key={artifact.Id}
				artifact={artifact}
				order={order}
				owned={owned[artifact.Id]}
				price={prices[artifact.Rarity]}
				dust={dust}
				busy={busy}
				phone={phone}
				onBuy={onBuy}
				reducedMotion={props.reducedMotion}
			/>,
		);
	}
	let ownedCount = 0;
	for (const artifact of artifacts) {
		if (owned[artifact.Id] !== undefined) {
			ownedCount += 1;
		}
	}
	const browseState = browse as unknown as BrowseState<unknown>;
	const gridH = rowsHeight(cards.size(), columns, cellH, pad.gap);
	return (
		<SectionPage phone={phone} tailPad={props.tailPad} bar={Palette.violet}>
			<BrowseBlock browse={browseState} placeholder="Search artifacts by name, effect or rarity" accent={Palette.violet} phone={phone} reducedMotion={props.reducedMotion} layoutOrder={1} />
			{cards.size() === 0 ? (
				<NoMatches browse={browseState} noun="artifacts" icon="Artifact.5" accent={Palette.violet} phone={phone} reducedMotion={props.reducedMotion} layoutOrder={2} />
			) : (
				<MockPanel name="grid" size={new UDim2(1, 0, 0, pnHeight(phone, headingBlock(phone) + 18 + pad.gap + gridH))} phone={phone} accent={Palette.violet} reveal={props.reveal} reducedMotion={props.reducedMotion} layoutOrder={2}>
					<PanelHeading icon="Artifact.4" title="Artifact vault" note={`${ownedCount}/${artifacts.size()} held`} accent={Palette.violet} phone={phone} layoutOrder={1} />
					<Line text="Buy artifacts outright for stardust. Ones you hold restock as upgrade fragments." size={phone ? 12 : 13} font={BODY} color={Palette.muted} width={new UDim(1, 0)} height={18} layoutOrder={2} />
					<MockGrid columns={columns} gap={pad.gap} cellHeight={cellH} count={cards.size()} layoutOrder={3}>
						{cards}
					</MockGrid>
				</MockPanel>
			)}
		</SectionPage>
	);
}


// Explicit gamepad order per Shop section (frame Names are scaffold section ids / SplitColumns columns).
// Premium (ShopView) keeps its own FocusClaim.
function storeFocusPlan(section: string): FocusPlan | undefined {
	if (section === "Crates") {
		// Open (×1, ×10, Auto) first; down from it the rest of the stage, the crate picker and the drop table.
		// Two-column desktop: picker (Side) <-> stage/drops (Main) step left/right.
		return {
			regions: ["StoreSections", "chips", "CrateOpen", "drops", "pulls"],
			// no keys (Open locked): the crate picker, so a crate with keys is one press away
			first: ["CrateOpen", "chips"],
			// crate cards + stage (Main) on the left, odds + last pulls (Side) on the right
			columns: [["Main", "Side"]],
		};
	}
	if (section === "Daily") {
		// the offer cards (Deal of the Day first), then the market panel
		return { regions: ["StoreSections", "offers", "market"], first: ["offers", "market"] };
	}
	if (section === "Skins") {
		// preview actions (equip / buy) first, then filter chips and the skin grid; on desktop the
		// preview column (Side) and filter + grid (Main) step left/right
		return {
			regions: ["StoreSections", "preview", "filter", "grid"],
			first: ["preview", "grid"],
			columns: [["Side", "Main"]],
		};
	}
	if (section === "Codex") {
		// search/filters, then each rarity grid top to bottom
		return { regions: ["StoreSections", "hero", "progress", "browse", "none", "grid*"], first: ["grid*", "browse"] };
	}
	if (section === "Artifacts") {
		return { regions: ["StoreSections", "hero", "browse", "none", "grid"], first: ["grid", "browse"] };
	}
	return undefined;
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
	const [section, setSection] = React.useState(props.initialSection ?? linked?.category ?? "Premium");
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
	const focusPlan = storeFocusPlan(section);
	useFocusOrder(hostRef, focusPlan ?? { regions: [] }, [section, focusPlan !== undefined]);
	const [tabColumns, tabH] = sectionTabLayout(contentWidth, stack ? TapTarget : 44, stack);
	const shared: SectionProps = {
		key: section,
		state: props.state ?? {},
		config: props.config ?? EMPTY_CONFIG,
		dispatch: props.dispatch,
		reducedMotion: softMotion,
		stack: stack,
		// columns follow the page's own content width (the nav rail / side chrome is already excluded)
		width: contentWidth,
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
		h("uilistlayout", { FillDirection: Enum.FillDirection.Vertical, Padding: new UDim(0, GAP), SortOrder: Enum.SortOrder.LayoutOrder }),
		h(
			"frame",
			{
				Name: "StoreSections",
				Size: new UDim2(1, 0, 0, tabH),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				LayoutOrder: 1,
			},
			h(PillTabs, {
				options: SECTIONS,
				value: section,
				onChange: (entry: string) => {
					setSection(entry);
				},
				accent: Palette.mango,
				columns: tabColumns,
				gap: 6,
				strip: stack,
			}),
		),
		h(
			"frame",
			{
				Name: "StoreSection",
				Size: new UDim2(1, 0, 1, -(tabH + GAP)),
				LayoutOrder: 2,
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
	WheelView: () => require(script.Parent!.WaitForChild("views")!.WaitForChild("WheelView") as ModuleScript),
};

export = (name: string) => {
	const load = pages[name];
	if (load === undefined) {
		error(`PagesShop: unknown module ${tostring(name)}`, 2);
	}
	return load();
};
