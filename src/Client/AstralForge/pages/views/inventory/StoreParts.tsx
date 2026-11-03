// The Crates, Market and Loadout tabs' cards: a crate with its keys and pity meter, the market's
// restock banner and offers, and the loadout board (bonuses from socketed relics and where they sit).
import React from "@rbxts/react";
import { asFlux, compactNumber } from "../../../CoreKit/format";
import { LoadoutEffectLines, OfferStock, RarityColor, SocketLabel } from "../../../CoreKit/inventoryMath";
import { Palette, Radius, Space, TapTarget } from "../../../CoreKit/theme";
import { useStagger } from "../../../MotionKit/motion";
import { counted, memoRow, sameFields } from "../../../UiCore/rowMemo";
import { Badge, Button, EmptyState, IconTile, Meter, Panel, Text } from "../../../UiCore/ui";

export interface CrateDef {
	Id: string;
	Name: string;
	Description: string;
	Color: Color3;
	PityRarity: string;
	PityAfter: number;
}
export interface MarketOffer {
	Id: string;
	Name: string;
	Description: string;
	Kind: string;
	Currency: string;
	Price: number;
	Color: Color3;
	[key: string]: unknown;
}

export const CRATE_CARD_H = (stack: boolean) => (stack ? 248 : 160);
export const MARKET_BANNER_H = 126;
export const MARKET_CARD_H = 176;
export const MARKET_CARD_H_STACK = 210;
const LOADOUT_COLORS: Record<string, Color3 | undefined> = {
	Production: Palette.green,
	Capacity: Palette.cyan,
	Tap: Palette.mango,
	Critical: Palette.pink,
	Automation: Palette.mint,
	Offline: Palette.violet,
};

interface CrateProps {
	crate: CrateDef;
	keys: number;
	pity: number;
	onOpen: (count: number) => void;
	busy: boolean;
	reducedMotion?: boolean;
	layoutOrder: number;
	stack: boolean;
}

/** One crate: keys held, what it drops, its guarantee meter, and Open / Open 5. */
function CrateCard({ crate, keys, pity, onOpen, busy, reducedMotion, layoutOrder, stack }: CrateProps) {
	const reveal = useStagger(layoutOrder, reducedMotion);
	const textWidth = stack ? -(60 + 16) : -280;
	const ready = (count: number) => keys >= count && !busy;
	const openButton = (count: number, icon: string, size: UDim2, hug: boolean) => (
		<Button
			text={busy ? "…" : count === 1 ? "Open" : `Open ${count}`}
			icon={icon}
			onClick={() => onOpen(count)}
			sound="open"
			color={ready(count) ? (count === 1 ? crate.Color : Palette.mango) : Palette.panelSoft}
			textColor={ready(count) ? Palette.ink : Palette.muted}
			size={size}
			hug={hug}
			reducedMotion={reducedMotion}
			disabled={!ready(count)}
			highlight={ready(count)}
		/>
	);
	return (
		<Panel
			size={new UDim2(1, 0, 0, CRATE_CARD_H(stack))}
			accent={crate.Color}
			background={Palette.panelRaised}
			padding={stack ? Space.lg : Space.xl}
			layoutOrder={layoutOrder}
			reveal={reveal}
			highlight={ready(1)}
			clips={false}
		>
			<IconTile
				kind="Crate"
				accent={crate.Color}
				size={48}
				radius={Radius.lg}
				position={UDim2.fromOffset(0, stack ? 8 : 24)}
				reducedMotion={reducedMotion}
				glow={keys >= 1}
				filled={keys >= 1}
			/>
			<frame Position={UDim2.fromOffset(60, 4)} Size={new UDim2(1, textWidth, 0, 24)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={Enum.VerticalAlignment.Center} />
				<Text value={crate.Name} size={18} color={Palette.cream} weight={Enum.FontWeight.Heavy} fit={true} minSize={12} layoutOrder={0} sizeConstraint={UDim2.fromOffset(150, 24)} />
				<Badge
					value={keys > 0 ? `${keys} KEYS` : "No keys"}
					accent={keys > 0 ? crate.Color : Palette.muted}
					size={UDim2.fromOffset(64, 18)}
					filled={keys > 0}
					layoutOrder={1}
				/>
			</frame>
			<Text
				value={crate.Description}
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(60, 32)}
				sizeConstraint={new UDim2(1, textWidth, 0, 36)}
			/>
			<Text
				value={`Guaranteed ${crate.PityRarity} at ${crate.PityAfter} (${pity}/${crate.PityAfter})`}
				size={11}
				color={crate.Color}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(60, 72)}
				sizeConstraint={new UDim2(1, textWidth, 0, 16)}
			/>
			<Meter
				value={math.clamp(pity / math.max(1, crate.PityAfter), 0, 1)}
				color={crate.Color}
				reducedMotion={reducedMotion}
				position={UDim2.fromOffset(60, 92)}
				size={new UDim2(1, textWidth, 0, 4)}
			/>
			{stack ? (
				<frame Size={new UDim2(1, 0, 0, TapTarget * 2 + 8)} Position={new UDim2(0, 0, 1, -(TapTarget * 2 + 14))} BackgroundTransparency={1} BorderSizePixel={0}>
					<uilistlayout
						FillDirection={Enum.FillDirection.Vertical}
						HorizontalAlignment={Enum.HorizontalAlignment.Left}
						VerticalAlignment={Enum.VerticalAlignment.Top}
						Padding={new UDim(0, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{openButton(1, "Crate.7", new UDim2(1, 0, 0, TapTarget), false)}
					{openButton(5, "Crate.8", new UDim2(1, 0, 0, TapTarget), false)}
				</frame>
			) : (
				<frame
					Size={UDim2.fromOffset(0, TapTarget)}
					AutomaticSize={Enum.AutomaticSize.X}
					Position={new UDim2(1, 0, 0.5, 0)}
					AnchorPoint={new Vector2(1, 0.5)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						HorizontalAlignment={Enum.HorizontalAlignment.Right}
						VerticalAlignment={Enum.VerticalAlignment.Center}
						Padding={new UDim(0, 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
					/>
					{openButton(1, "Crate.9", UDim2.fromOffset(0, TapTarget), true)}
					{openButton(5, "Crate.10", UDim2.fromOffset(0, TapTarget), true)}
				</frame>
			)}
		</Panel>
	);
}

/** The market's header: when it next restocks, and how stock works. */
export function MarketBanner({ refreshText, reducedMotion, layoutOrder, stack }: { refreshText: string | React.Binding<string>; reducedMotion?: boolean; layoutOrder: number; stack: boolean }) {
	const textX = stack ? 56 : 64;
	const textWidth = stack ? -(56 + 12) : -16;
	const badges = (positioned: boolean) => (
		<>
			<Badge value="Daily keys" accent={Palette.cyan} filled={true} position={positioned ? new UDim2(1, -208, 1, -30) : undefined} size={UDim2.fromOffset(98, 24)} />
			<Badge value="Live" accent={Palette.violet} position={positioned ? new UDim2(1, -100, 1, -30) : undefined} size={UDim2.fromOffset(92, 24)} />
		</>
	);
	return (
		<Panel
			size={new UDim2(1, 0, 0, stack ? 132 : MARKET_BANNER_H)}
			accent={Palette.mango}
			background={Palette.panelRaised}
			padding={stack ? Space.lg : Space.lg + Space.xs}
			layoutOrder={layoutOrder}
			highlight={true}
			reducedMotion={reducedMotion}
			clips={false}
		>
			<IconTile kind="Shop" accent={Palette.mango} size={stack ? 44 : 48} radius={Radius.lg} position={UDim2.fromOffset(0, stack ? 6 : 12)} reducedMotion={reducedMotion} />
			<Text value="Market" size={10} color={Palette.mango} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(textX, 0)} sizeConstraint={new UDim2(1, textWidth, 0, 14)} />
			<Text
				value={refreshText}
				size={stack ? 16 : 18}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(textX, 18)}
				sizeConstraint={new UDim2(1, textWidth, 0, 24)}
			/>
			<Text
				value="Daily keys restock at UTC midnight. Rarer offers restock a little at a time."
				size={11}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(textX, 48)}
				sizeConstraint={new UDim2(1, textWidth, 0, stack ? 44 : 36)}
			/>
			{stack ? (
				<frame Size={new UDim2(1, 0, 0, 26)} Position={new UDim2(0, 0, 1, -28)} BackgroundTransparency={1} BorderSizePixel={0}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{badges(false)}
				</frame>
			) : (
				badges(true)
			)}
		</Panel>
	);
}

interface OfferProps {
	offer: MarketOffer;
	dispatch: (action: string, payload?: object) => unknown;
	reducedMotion?: boolean;
	layoutOrder: number;
	cash: unknown;
	stardust: number;
	cores: number;
	refreshShort?: string | React.Binding<string>;
	stack?: boolean;
}

/** One market offer: what it is, its stock today, its price against your balance, and Buy. */
function MarketCard({ offer, dispatch, reducedMotion, layoutOrder, cash, stardust, cores, refreshShort, stack = false }: OfferProps) {
	const balance = offer.Currency === "Cash" ? asFlux(cash) : offer.Currency === "Stardust" ? stardust : cores;
	const { stock, stockMax, soldOut, daily } = OfferStock(offer);
	const free = offer.Price <= 0;
	const canBuy = !soldOut && balance >= offer.Price;
	const accent = soldOut ? Palette.muted : offer.Color;
	const stockBadge = daily ? (soldOut ? (free ? "Claimed" : "Bought") : stockMax > 1 ? `${stock}/${stockMax} today` : "Daily") : soldOut ? "Sold out" : `${stock} left`;
	const statusLine = daily
		? soldOut
			? free
				? "Claimed today. The free key returns at restock."
				: "Bought today. Available again at restock."
			: `Refreshes daily · ${stock} of ${stockMax} left`
		: soldOut
			? "Sold out. More comes in at restock."
			: `Limited stock · ${stock} of ${stockMax} remaining`;
	const textReserve = stack ? -(56 + 16) : -240;
	const buy = (icon: string, size: UDim2, position?: UDim2, hug?: boolean) => (
		<Button
			text={soldOut ? (daily ? "Restocking" : "Sold out") : "Buy"}
			icon={icon}
			onClick={() => dispatch("BuyItemOffer", { Id: offer.Id })}
			color={canBuy ? offer.Color : Palette.panelSoft}
			textColor={canBuy ? Palette.ink : Palette.muted}
			size={size}
			position={position}
			hug={hug}
			reducedMotion={reducedMotion}
			disabled={!canBuy}
			highlight={canBuy}
		/>
	);
	return (
		<Panel
			size={new UDim2(1, 0, 0, stack ? MARKET_CARD_H_STACK : MARKET_CARD_H)}
			accent={accent}
			background={soldOut ? Palette.panelSoft : Palette.panelRaised}
			padding={stack ? Space.lg : Space.xl}
			layoutOrder={layoutOrder}
			clips={false}
			highlight={canBuy}
			reducedMotion={reducedMotion}
		>
			<IconTile
				kind={offer.Kind === "Essence" ? "Dust" : offer.Kind === "Key" ? "Gift" : "Loadout"}
				accent={accent}
				size={44}
				radius={Radius.md}
				position={UDim2.fromOffset(0, stack ? 8 : 32)}
				reducedMotion={reducedMotion}
			/>
			<Text
				value={offer.Name}
				size={16}
				color={soldOut ? Palette.creamSoft : Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(56, 4)}
				sizeConstraint={new UDim2(1, stack ? -(56 + 16) : -260, 0, 22)}
			/>
			<Badge
				value={stockBadge}
				accent={soldOut ? Palette.coral : daily ? Palette.cyan : Palette.violet}
				filled={!soldOut}
				position={stack ? UDim2.fromOffset(56, 28) : new UDim2(1, -150, 0, 4)}
				size={UDim2.fromOffset(140, stack ? 24 : 26)}
			/>
			<Text
				value={offer.Description}
				size={11}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(56, stack ? 56 : 30)}
				sizeConstraint={new UDim2(1, textReserve, 0, 34)}
			/>
			<Text
				value={free ? "Free" : `${compactNumber(offer.Price)} ${offer.Currency}`}
				size={13}
				color={soldOut ? Palette.muted : offer.Color}
				weight={Enum.FontWeight.Bold}
				position={UDim2.fromOffset(56, stack ? 94 : 70)}
				sizeConstraint={new UDim2(1, textReserve, 0, 18)}
			/>
			<Text
				value={statusLine}
				size={10}
				color={soldOut ? Palette.coral : Palette.muted}
				weight={Enum.FontWeight.Bold}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(56, stack ? 114 : 94)}
				sizeConstraint={new UDim2(1, textReserve, 0, 28)}
			/>
			{soldOut && daily && refreshShort !== undefined && (
				<Text
					value={refreshShort}
					size={10}
					color={Palette.mango}
					weight={Enum.FontWeight.Heavy}
					position={UDim2.fromOffset(56, stack ? 142 : 124)}
					sizeConstraint={new UDim2(1, textReserve, 0, 14)}
				/>
			)}
			{stack ? (
				buy(soldOut ? "Lock.14" : "Shop.11", new UDim2(1, 0, 0, TapTarget), new UDim2(0, 0, 1, -(TapTarget + 8)))
			) : (
				<frame
					Size={UDim2.fromOffset(0, 48)}
					AutomaticSize={Enum.AutomaticSize.X}
					AnchorPoint={new Vector2(1, 0.5)}
					Position={new UDim2(1, 0, 0.5, 0)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					{buy(soldOut ? "Lock.15" : "Shop.12", UDim2.fromOffset(0, 48), undefined, true)}
				</frame>
			)}
		</Panel>
	);
}

/** The loadout board's bonus grid height and its total height (the empty-sockets card is 112px). */
function loadoutLayout(lineCount: number, equippedCount: number, stack: boolean) {
	const gridH = math.ceil(lineCount / (stack ? 2 : 3)) * ((stack ? 58 : 54) + 8);
	const listH = 28 + (equippedCount === 0 ? 112 : equippedCount * 32);
	return { gridH, height: 40 + gridH + 22 + listH };
}

interface ItemsState {
	Effects?: unknown;
	Equipped?: Record<string, unknown>;
	Inventory?: Record<string, { DefinitionId?: string; Level?: number } | undefined>;
}

/** The Loadout tab: every bonus your socketed relics add, then each socket and what's in it. */
/** How tall LoadoutBoard draws for this state, so its section reserves exactly that. */
export function loadoutBoardHeight(state: { Items?: ItemsState }, config: { Items?: { Definitions?: Array<{ Id: string }> } }, stack: boolean): number {
	const items = state.Items;
	const known = new Set<string>();
	for (const definition of config.Items?.Definitions ?? []) known.add(definition.Id);
	let equipped = 0;
	for (const [, uid] of pairs(items?.Equipped ?? {})) {
		const id = typeIs(uid, "string") ? items?.Inventory?.[uid]?.DefinitionId : undefined;
		if (id !== undefined && known.has(id)) equipped += 1;
	}
	return loadoutLayout(LoadoutEffectLines(items?.Effects).size(), equipped, stack).height;
}

export function LoadoutBoard({ state, config, layoutOrder, stack }: { state: { Items?: ItemsState }; config: { Items?: { Definitions?: Array<{ Id: string; Name: string; Rarity?: string }> } }; layoutOrder: number; stack: boolean }) {
	const items = state.Items;
	const lines = LoadoutEffectLines(items?.Effects).map((entry) => ({ ...entry, color: LOADOUT_COLORS[entry.id] ?? Palette.muted }));
	const byId = new Map<string, { Name: string; Rarity?: string }>();
	for (const definition of config.Items?.Definitions ?? []) byId.set(definition.Id, definition);
	const equipped: Array<{ target: string; name: string; rarity?: string }> = [];
	for (const [target, uid] of pairs(items?.Equipped ?? {})) {
		if (!typeIs(uid, "string")) continue;
		const instance = items?.Inventory?.[uid];
		const definition = instance?.DefinitionId !== undefined ? byId.get(instance.DefinitionId) : undefined;
		if (definition === undefined) continue;
		equipped.push({ target, name: `${definition.Name} LV${instance!.Level}`, rarity: definition.Rarity });
	}
	const { gridH, height } = loadoutLayout(lines.size(), equipped.size(), stack);
	const cols = stack ? 2 : 3;
	const tileH = stack ? 58 : 54;
	const tileGap = 8;
	return (
		<Panel
			size={new UDim2(1, 0, 0, height)}
			accent={Palette.violet}
			background={Palette.panelRaised}
			padding={stack ? Space.lg : Space.xl}
			layoutOrder={layoutOrder}
			clips={false}
			highlight={true}
		>
			<Text value="Bonuses" size={11} color={Palette.violet} weight={Enum.FontWeight.Heavy} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			<frame Size={new UDim2(1, 0, 0, gridH)} Position={UDim2.fromOffset(0, 22)} BackgroundTransparency={1} BorderSizePixel={0}>
				{lines.map((line, index) => {
					const col = index % cols;
					const live = line.value > 0;
					return (
						<frame
							key={line.id}
							Size={new UDim2(1 / cols, -tileGap, 0, tileH)}
							Position={new UDim2(col / cols, col === 0 ? 0 : tileGap / 2, 0, math.floor(index / cols) * (tileH + tileGap))}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={0.04}
							BorderSizePixel={0}
						>
							<uicorner CornerRadius={new UDim(0, 8)} />
							<uistroke Color={live ? line.color : Palette.lineSoft} Transparency={0.5} Thickness={1} />
							<Text value={line.label} size={10} color={Palette.creamSoft} weight={Enum.FontWeight.Bold} position={UDim2.fromOffset(10, 8)} sizeConstraint={new UDim2(1, -20, 0, 14)} />
							<Text
								value={`+${math.floor(line.value * 1000 + 0.5) / 10}%`}
								size={16}
								color={live ? line.color : Palette.muted}
								weight={Enum.FontWeight.Heavy}
								position={UDim2.fromOffset(10, 24)}
								sizeConstraint={new UDim2(1, -20, 0, 22)}
							/>
						</frame>
					);
				})}
			</frame>
			<Text value="Socketed" size={11} color={Palette.mint} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(0, 28 + gridH)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			{equipped.size() === 0 && (
				<frame BackgroundTransparency={1} BorderSizePixel={0} Position={UDim2.fromOffset(0, 48 + gridH)} Size={new UDim2(1, 0, 0, 104)}>
					<EmptyState icon="Loadout" title="No relics socketed" body="Tap a relic below to socket it." accent={Palette.violet} compact={true} size={UDim2.fromScale(1, 1)} />
				</frame>
			)}
			{equipped.map((entry, index) => (
				<frame
					key={entry.target}
					Size={new UDim2(1, 0, 0, 28)}
					Position={UDim2.fromOffset(0, 48 + gridH + index * 32)}
					BackgroundColor3={Palette.ink}
					BackgroundTransparency={0.12}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 8)} />
					<Text
						value={`${SocketLabel(entry.target)}  ·  ${entry.name}`}
						size={12}
						color={RarityColor(config, entry.rarity, Palette.muted)}
						weight={Enum.FontWeight.Bold}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(10, 0)}
						sizeConstraint={new UDim2(1, -20, 1, 0)}
					/>
				</frame>
			))}
		</Panel>
	);
}

// Row memos (memoRow keeps click handlers pointing at the latest closure).
// CrateCard shows: the crate (by value), key count, pity, busy, motion, layout order, stack layout.
export const CrateCardMemo = memoRow<CrateProps>(counted("InvCrate", CrateCard), ["onOpen"], sameFields<CrateProps>(["crate", "keys", "pity", "busy", "reducedMotion", "layoutOrder", "stack"]));
// MarketCard shows: the offer (by value), the three wallet balances it prices against, refresh text,
// motion, layout order, stack layout; dispatch is the shell's stable dispatcher.
export const MarketCardMemo = React.memo(
	counted("InvMarket", MarketCard) as (props: OfferProps) => React.Element,
	sameFields<OfferProps>(["offer", "dispatch", "cash", "stardust", "cores", "refreshShort", "reducedMotion", "layoutOrder", "stack"]),
);
