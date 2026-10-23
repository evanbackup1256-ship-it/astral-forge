import { counted } from "../../UiCore/rowMemo";
import React from "@rbxts/react";
import Tools = require("../../UpgradeTools");
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { useEntrance, useStagger, useViewport } from "../../MotionKit/motion";
import { useAntilag } from "../../MotionKit/antilag";
import { useTooltip } from "../../Tooltip";
import { chromeFor, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { bulkCost, compactNumber, Flux, gteFlux } from "../../CoreKit/format";
import { AppHelpers, NavState, UpgradeConfig, UpgradeEntry } from "../../CoreKit/appNav";
import { SplitColumns, SplitPlan, StackBlocks, splitColumns, stackHeight } from "../../UiCore/ui";
import { Bar, Chip, MockPanel, PanelHeading } from "../../UiCore/mockKit";
import { BigFigure, ChipRow, HEADING_SECTION_H, HeadingSection, MockBtn, TILE_ROW_H, TileRow, Rise } from "../mockRows";
import { Component, loadBrowse, loadPageScaffold, loadUi, luauKit, named } from "../luauDeps";

// desktop two-column breakpoint for this page (ui4 helper in UiCore/ui.tsx): 1100px+, side 360/400px
function pagePlan(width: number, stack: boolean): SplitPlan {
	return splitColumns(stack ? 0 : width, width >= 1600 ? 400 : 360, 18, 1100);
}

// folds scaffold sections into one SplitColumns section: all but the last `mainCount` go on the
// side; each column is a SelectionGroup so gamepad focus stays in a column until moved across
function splitSections<S extends { id: string; height: number; element: React.Element }>(
	plan: SplitPlan,
	sections: S[],
	name: string,
	mainCount = 1,
): Array<{ id: string; height: number; element: React.Element }> {
	if (!plan.split || sections.size() <= mainCount) {
		return sections;
	}
	const cut = sections.size() - mainCount;
	const side = sections.filter((_, index) => index < cut);
	const main = sections.filter((_, index) => index >= cut);
	const height = math.max(stackHeight(side.map((s) => s.height), plan.gap), stackHeight(main.map((s) => s.height), plan.gap));
	const column = (blocks: S[]) => (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} SelectionGroup={true}>
			{blocks.size() === 1 ? blocks[0].element : <StackBlocks gap={plan.gap} blocks={blocks} />}
		</frame>
	);
	return [
		{
			id: `${name}-split`,
			height,
			element: <SplitColumns height={height} plan={plan} side={column(side)} main={column(main)} name={name} />,
		},
	];
}


const UserInputService = game.GetService("UserInputService");
const ui = loadUi();
const { AmountToggle } = ui;
const PageScaffold = loadPageScaffold();
const VirtualGrid = luauKit<{ VirtualGrid: Component }>("LayoutKit", "scrolling").VirtualGrid;

// 03-forge machine rows: 64px .row (56 on phones) with a 10px gap between rows
const NODE_ROW_HEIGHT = TILE_ROW_H;
const NODE_ROW_HEIGHT_STACK = 56;
const CONNECTOR_HEIGHT = 10;

interface ResearchConfig extends UpgradeConfig {
	Accent?: Color3;
	Color?: Color3;
	BaseProduction?: number;
	Description?: string;
}
type Entry = UpgradeEntry<ResearchConfig>;
type ModelEntries = Parameters<typeof Tools.Model.filter>[0];

function researchEffectLine(entry: Entry) {
	const production = entry.config.BaseProduction ?? 0;
	if (production > 0) {
		return `+${compactNumber(production)} effect per level`;
	}
	return entry.config.Description;
}

interface NodeProps {
	entry: Entry;
	reducedMotion?: boolean;
	index: number;
	onBuy: (id: unknown) => unknown;
	stack: boolean;
	buyAmount: number;
	cash: Flux;
}

// what cash changes on a research row: the price text and whether BUY is live
function sameQuote(a: NodeProps, b: NodeProps): boolean {
	if (a.cash === b.cash) {
		return true;
	}
	const quote = (p: NodeProps) => {
		const price = bulkCost(p.entry.config.BaseCost, p.entry.config.CostScale, p.entry.level, p.buyAmount, p.entry.config.MaxLevel, p.cash);
		return $tuple(compactNumber(price), p.entry.unlocked && !p.entry.maxed && gteFlux(p.cash, price));
	};
	const [priceA, readyA] = quote(a);
	const [priceB, readyB] = quote(b);
	return priceA === priceB && readyA === readyB;
}

const ResearchNode = React.memo(
	counted("ResearchNode", (props: NodeProps) => {
		const { entry, reducedMotion, index, onBuy, stack, buyAmount, cash } = props;
		const reveal = useStagger(math.min(index, 6), reducedMotion, 0.02, 0.14);
		const accent = entry.config.Accent ?? entry.config.Color;
		const maxed = entry.maxed;
		const price = bulkCost(entry.config.BaseCost, entry.config.CostScale, entry.level, buyAmount, entry.config.MaxLevel, cash);
		const ready = entry.unlocked && !maxed && gteFlux(cash, price);
		const levelFrac = math.clamp(entry.level / math.max(1, entry.config.MaxLevel), 0, 1);
		const buyLabel = !entry.unlocked ? "Locked" : maxed ? "Maxed" : compactNumber(price);
		const buy = () => {
			if (!ready) {
				return undefined;
			}
			return onBuy(entry.config.Id);
		};
		const tip = useTooltip({
			title: entry.config.Name,
			body: entry.unlocked ? entry.config.Description : entry.lockReason,
			hint: !entry.unlocked
				? undefined
				: maxed
					? "Maxed. The bonus is permanent."
					: `Level ${compactNumber(entry.level)} of ${compactNumber(entry.config.MaxLevel)} · next ${compactNumber(price)} Flux`,
			accent: accent,
		});
		const tint = accent ?? Palette.cyan;
		const production = entry.config.BaseProduction ?? 0;
		return (
			<frame Size={new UDim2(1, 0, 0, (stack ? NODE_ROW_HEIGHT_STACK : NODE_ROW_HEIGHT) + CONNECTOR_HEIGHT)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
				<Rise reveal={reveal} height={stack ? NODE_ROW_HEIGHT_STACK : NODE_ROW_HEIGHT}>
					<TileRow
						event={tip}
						phone={stack}
						icon={entry.unlocked ? "Research" : "Lock"}
						accent={tint}
						dim={!entry.unlocked}
						title={entry.config.Name}
						meta={entry.unlocked ? (maxed ? `Lv ${compactNumber(entry.level)} · Max` : `Lv ${compactNumber(entry.level)}`) : "Locked"}
						fill={entry.unlocked ? levelFrac : 0}
						barColor={maxed ? Palette.mango : tint}
						value={entry.unlocked ? (production > 0 ? `+${compactNumber(production)}/lv` : `${compactNumber(entry.level)}/${compactNumber(entry.config.MaxLevel)}`) : entry.lockReason}
						valueColor={entry.unlocked ? tint : Palette.muted}
						rightWidth={stack ? 84 : 120}
						right={<MockBtn text={buyLabel} icon={entry.unlocked && !maxed ? "Flux" : undefined} accent={tint} sm={true} phone={stack} fill={true} disabled={!ready} onClick={buy} reducedMotion={reducedMotion} />}
					/>
				</Rise>
			</frame>
		);
	}),
	(prev, incoming) =>
		prev.entry.config === incoming.entry.config &&
		prev.entry.level === incoming.entry.level &&
		prev.entry.price === incoming.entry.price &&
		prev.entry.affordable === incoming.entry.affordable &&
		prev.entry.maxed === incoming.entry.maxed &&
		prev.entry.unlocked === incoming.entry.unlocked &&
		prev.entry.lockReason === incoming.entry.lockReason &&
		prev.buyAmount === incoming.buyAmount &&
		// cash moves on every state push; the row only shows it through its price and BUY state
		sameQuote(prev, incoming) &&
		prev.reducedMotion === incoming.reducedMotion &&
		prev.index === incoming.index &&
		prev.onBuy === incoming.onBuy &&
		prev.stack === incoming.stack,
);

interface ResearchProps {
	state: {
		Research?: Record<string, number | undefined>;
		Zone?: unknown;
		Rebirths?: unknown;
		Cash?: Flux;
		FeatureUnlocks?: Record<string, { Unlocked?: boolean } | undefined>;
		[key: string]: unknown;
	};
	config: { Research: ResearchConfig[]; [key: string]: unknown };
	dispatch: (action: unknown, payload: unknown, reply?: (response: unknown) => void) => unknown;
	buyAmount: number;
	setBuyAmount: (amount: number) => void;
	reducedMotion?: boolean;
}

function ResearchView(props: ResearchProps) {
	const { state, config, dispatch, buyAmount, setBuyAmount } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const softMotion = props.reducedMotion;
	const enter = useEntrance(softMotion);
	const stack = chrome.contentStack;
	// wide desktop: hero + controls in a side column, the chain in the main column. The side
	// column reuses the stacked hero/controls arrangement, which is built for narrow widths.
	const plan = pagePlan(viewport.width, stack);
	const heroStack = stack || plan.split;
	// phones in landscape have the width for side-by-side rows (button on the right); the
	// stacked row with its button underneath fills too much of a 360px-tall screen
	const rowStack = stack && !chrome.landscape;
	const scrollRef = React.useRef<ScrollingFrame>();
	const buyAllHostRef = React.useRef<Frame>();
	const entries = React.useMemo(
		() => AppHelpers.buildUpgradeEntries(config.Research, state.Research ?? {}, state as NavState),
		[config.Research, state.Research, state.Zone, state.Rebirths],
	);
	const unlockedCount = entries.reduce((sum, entry) => sum + (entry.unlocked ? 1 : 0), 0);
	const maxedCount = entries.reduce((sum, entry) => sum + (entry.maxed ? 1 : 0), 0);
	const nextEntry = entries.find((entry) => entry.unlocked && !entry.maxed);
	const Browse = loadBrowse();
	const [query, setQuery] = Browse.useLinkedQuery("Research");
	const [filter, setFilter] = React.useState(query !== "" ? "All" : "Available");
	const visible = Tools.Model.filter(
		entries as unknown as ModelEntries,
		query,
		filter,
		buyAmount,
		state.Cash,
		loadBrowse().matches,
	) as unknown as Entry[];
	const batch = Tools.useBatch(dispatch, "BuyResearch", visible as unknown as ModelEntries, buyAmount, state.Cash);
	const onBuy = batch.buy;
	const onBuyAll = batch.start;
	const canBuyAll = batch.count > 0 && !batch.busy;
	React.useEffect(() => {
		const host = scrollRef.current;
		if (host) {
			host.CanvasPosition = Vector2.zero;
		}
	}, [query, filter]);
	React.useEffect(() => {
		if (!canBuyAll || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = buyAllHostRef.current;
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
			pcall(task.cancel, selectJob);
		};
	}, [canBuyAll, buyAmount, unlockedCount]);
	const listGap = stack ? chrome.panelGap : Layout.panelGap;
	const summaryH = stack ? 10 * 2 + 26 + 38 + 8 + 24 + 8 + 10 + 8 + TapTarget : 18 * 2 + 34 + 62 + 12 + 28 + 12 + 10 + 12 + 44;
	const researchGate = state.FeatureUnlocks !== undefined ? state.FeatureUnlocks.Research : undefined;
	const researchLocked = researchGate !== undefined && researchGate.Unlocked === false;
	const chainCount = visible.size();
	const rowStride = (rowStack ? NODE_ROW_HEIGHT_STACK : NODE_ROW_HEIGHT) + CONNECTOR_HEIGHT;
	const chainH = math.max(rowStride, chainCount * rowStride);
	return (
		<PageScaffold
			hostRef={scrollRef}
			gap={listGap}
			tailPad={scrollTail(stack, chrome.bottomSafe, 48)}
			scrollBarColor={Palette.cyan}
			scrollBarThickness={4}
			sections={splitSections(plan, [
				{
					id: "summary",
					height: summaryH,
					element: (
						<MockPanel size={UDim2.fromScale(1, 1)} phone={stack} accent={Palette.cyan} glow={Palette.cyan} reveal={enter} reducedMotion={softMotion} name="ResearchSummary">
							<PanelHeading icon="Research" title="Research" note={researchLocked ? "Unlocks at 100 Flux" : `${maxedCount} maxed`} accent={Palette.cyan} phone={stack} layoutOrder={0} />
							<BigFigure value={`${unlockedCount} of ${entries.size()}`} unit="researched" color={Palette.cyan} phone={stack} layoutOrder={1} />
							<ChipRow height={stack ? 24 : 28} layoutOrder={2}>
								<Chip text={nextEntry !== undefined ? `Next: ${nextEntry.config.Name}` : "All researched"} accent={Palette.cyan} phone={stack} layoutOrder={0} />
								<Chip text="Kept through rebirth" phone={stack} layoutOrder={1} />
							</ChipRow>
							<Bar fill={entries.size() > 0 ? unlockedCount / entries.size() : 0} color={Palette.cyan} layoutOrder={3} />
							<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, stack ? TapTarget : 44)} LayoutOrder={4}>
								<AmountToggle value={buyAmount} onChange={setBuyAmount} accent={Palette.cyan} size={new UDim2(1, -(stack ? 112 : 190), 1, 0)} reducedMotion={softMotion} />
								<frame
									{...named("ResearchBuyClaimActions")}
									Size={new UDim2(0, stack ? 104 : 180, 1, 0)}
									Position={new UDim2(1, stack ? -104 : -180, 0, 0)}
									BackgroundTransparency={1}
									BorderSizePixel={0}
									ClipsDescendants={false}
									ref={canBuyAll ? buyAllHostRef : undefined}
								>
									<MockBtn
										text={batch.busy ? batch.status : `Buy ${batch.count}`}
										icon="Flux"
										accent={Palette.cyan}
										phone={stack}
										fill={true}
										disabled={!canBuyAll}
										onClick={onBuyAll}
										reducedMotion={softMotion}
									/>
								</frame>
							</frame>
						</MockPanel>
					),
				},
				{
					id: "research-controls",
					height: heroStack ? 164 : 96,
					element: (
						<Tools.ResearchControls
							query={query}
							setQuery={setQuery}
							filter={filter}
							setFilter={setFilter}
							count={visible.size()}
							stack={heroStack}
							reducedMotion={softMotion}
							batch={batch}
						/>
					),
				},
				{
					id: "chain-head",
					height: HEADING_SECTION_H,
					element: <HeadingSection icon="Research" title="Chain" note={`${visible.size()} shown`} accent={Palette.cyan} phone={stack} />,
				},
				{
					id: "chain",
					height: chainH,
					element:
						visible.size() === 0 ? (
							<ui.EmptyState
								title="No matching research"
								body="Try another search or choose All research."
								icon="Research.2"
								accent={Palette.cyan}
								reducedMotion={softMotion}
								size={UDim2.fromScale(1, 1)}
							/>
						) : (
							<VirtualGrid
								scrollRef={scrollRef}
								count={chainCount}
								columns={1}
								cellHeight={rowStride}
								gap={0}
								overscanRows={softMotion ? 0 : antilag.constrained ? 1 : 2}
								itemKey={(index: number) => {
									const entry = visible[index] as Entry | undefined;
									return entry !== undefined ? entry.config.Id : `node-${index}`;
								}}
								renderItem={(index: number) => (
									<ResearchNode
										entry={visible[index]}
										buyAmount={buyAmount}
										cash={state.Cash as Flux}
										reducedMotion={softMotion}
										index={index}
										onBuy={onBuy}
										stack={rowStack}
									/>
								)}
							/>
						),
				},
			], "Research", 2)}
		/>
	);
}

export = { ResearchView };
