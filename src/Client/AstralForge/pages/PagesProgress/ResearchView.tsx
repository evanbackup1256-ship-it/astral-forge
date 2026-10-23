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
import { Component, loadBrowse, loadPageScaffold, loadUi, luauKit, named } from "../luauDeps";



const UserInputService = game.GetService("UserInputService");
const ui = loadUi();
const { IconTile, Panel, Button, Text, Meter, Badge, AmountToggle } = ui;
const PageScaffold = loadPageScaffold();
const VirtualGrid = luauKit<{ VirtualGrid: Component }>("LayoutKit", "scrolling").VirtualGrid;

const NODE_ROW_HEIGHT = 116; // content ends at 86px plus padding; taller only added an empty band
const NODE_ROW_HEIGHT_STACK = 190;
const CONNECTOR_HEIGHT = 22;

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

function ResearchConnector({ active, accent }: { active: boolean; accent?: Color3 }) {
	return (
		<frame
			Size={new UDim2(0, 3, 0, CONNECTOR_HEIGHT)}
			Position={new UDim2(0, 25, 0, 0)}
			BackgroundColor3={active ? accent : Palette.line}
			BackgroundTransparency={active ? 0.15 : 0.65}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
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
		const buyLabel = !entry.unlocked
			? "LOCKED"
			: maxed
				? "MAXED"
				: ready
					? `BUY ${compactNumber(price)}`
					: `NEED ${compactNumber(price)}`;
		const rowH = stack ? NODE_ROW_HEIGHT_STACK : NODE_ROW_HEIGHT;
		const textReserve = stack ? 0 : -200;
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
					: `Level ${compactNumber(entry.level)} of ${compactNumber(entry.config.MaxLevel)}, next ${compactNumber(price)} Flux`,
			accent: accent,
		});
		return (
			<frame
				Event={tip}
				Size={new UDim2(1, -4, 0, rowH + CONNECTOR_HEIGHT)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				{index > 0 && <ResearchConnector active={entry.unlocked} accent={accent} />}
				<Panel
					size={new UDim2(1, 0, 0, rowH)}
					position={UDim2.fromOffset(0, CONNECTOR_HEIGHT)}
					accent={entry.unlocked ? accent : Palette.lineSoft}
					background={Palette.panel}
					padding={14}
					reveal={reveal}
					highlight={ready}
					reducedMotion={reducedMotion}
					clips={false}
				>
					<IconTile
						kind={entry.unlocked ? "Research" : "Lock"}
						accent={entry.unlocked ? accent : Palette.muted}
						size={44}
						radius={14}
						position={UDim2.fromOffset(0, 6)}
						glow={maxed}
						spin={false}
						reducedMotion={reducedMotion}
					/>
					<Text
						value={entry.config.Name}
						size={16}
						color={entry.unlocked ? Palette.cream : Palette.muted}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={11}
						position={UDim2.fromOffset(56, 4)}
						sizeConstraint={new UDim2(1, textReserve, 0, 22)}
					/>
					<Text
						value={entry.unlocked ? researchEffectLine(entry) : entry.lockReason}
						size={11}
						color={entry.unlocked ? Palette.creamSoft : accent}
						weight={entry.unlocked ? Enum.FontWeight.Regular : Enum.FontWeight.Bold}
						wrap={true}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(56, 27)}
						sizeConstraint={new UDim2(1, textReserve, 0, 32)}
					/>
					{entry.unlocked && (
						<>
							<Text
								value={
									maxed
										? `Level ${compactNumber(entry.level)}, maxed`
										: `Level ${compactNumber(entry.level)} / ${compactNumber(entry.config.MaxLevel)}`
								}
								size={10}
								color={accent}
								weight={Enum.FontWeight.Bold}
								fit={true}
								position={UDim2.fromOffset(56, 62)}
								sizeConstraint={new UDim2(1, textReserve, 0, 14)}
							/>
							<Meter
								value={levelFrac}
								color={maxed ? Palette.mango : accent}
								reducedMotion={reducedMotion}
								position={UDim2.fromOffset(56, 80)}
								size={new UDim2(1, textReserve, 0, 6)}
							/>
						</>
					)}
					{stack ? (
						maxed ? (
							<Badge
								value="MAXED"
								accent={Palette.mango}
								filled={true}
								position={new UDim2(0, 0, 1, -TapTarget)}
								size={new UDim2(1, 0, 0, TapTarget)}
							/>
						) : (
							<Button
								text={buyLabel}
								icon={entry.unlocked ? "Flux.6" : "Lock.2"}
								onClick={buy}
								color={ready ? accent : Palette.panelSoft}
								textColor={ready ? Palette.ink : Palette.muted}
								size={new UDim2(1, 0, 0, TapTarget)}
								position={new UDim2(0, 0, 1, -TapTarget)}
								reducedMotion={reducedMotion}
								disabled={!ready}
								highlight={ready}
							/>
						)
					) : maxed ? (
						<Badge
							value="MAXED"
							accent={Palette.mango}
							filled={true}
							position={new UDim2(1, -140, 0, 24)}
							size={UDim2.fromOffset(130, 32)}
						/>
					) : (
						<Button
							text={buyLabel}
							icon={entry.unlocked ? "Flux.7" : "Lock.3"}
							onClick={buy}
							color={ready ? accent : Palette.panelSoft}
							textColor={ready ? Palette.ink : Palette.muted}
							size={UDim2.fromOffset(130, 32)}
							position={new UDim2(1, -140, 0, 24)}
							reducedMotion={reducedMotion}
							disabled={!ready}
							highlight={ready}
						/>
					)}
				</Panel>
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
	// composition (docs/layout-specs/research.md): full-width hero band, a one-row controls
	// toolbar, then the chain as a full-width vertical tree. The old side rail left an empty
	// stretched controls panel beside a chain many screens tall.
	// phones in landscape keep the one-row hero and toolbar so the chain starts on the first screen
	const heroStack = stack && !chrome.landscape;
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
	const headerH = heroStack ? 208 : 128;
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
			sections={[
				{
					id: "hero",
					height: headerH,
					element: (
						<Panel
							size={UDim2.fromScale(1, 1)}
							accent={Palette.cyan}
							background={Palette.panelRaised}
							padding={heroStack ? 14 : 16}
							reveal={enter}
							reducedMotion={softMotion}
							clips={false}
						>
							<IconTile
								kind="Research"
								accent={Palette.cyan}
								size={heroStack ? 48 : 56}
								radius={14}
								position={UDim2.fromOffset(0, heroStack ? 4 : 18)}
								glow={true}
								spin={false}
								reducedMotion={softMotion}
							/>
							<Text
								value={researchLocked ? "Unlocks at 100 Flux" : "Research chain"}
								size={10}
								color={Palette.cyan}
								weight={Enum.FontWeight.Heavy}
								position={UDim2.fromOffset(heroStack ? 0 : 72, heroStack ? 60 : 0)}
								sizeConstraint={new UDim2(1, heroStack ? -8 : -332, 0, 16)}
							/>
							<Text
								value={
									researchLocked
										? "Earn 100 Flux to begin research."
										: nextEntry !== undefined
											? `Next: ${nextEntry.config.Name}`
											: `${unlockedCount} of ${entries.size()} researched`
								}
								size={heroStack ? 18 : 24}
								color={Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={true}
								position={UDim2.fromOffset(heroStack ? 0 : 72, heroStack ? 78 : 18)}
								sizeConstraint={new UDim2(1, heroStack ? -8 : -332, 0, 32)}
							/>
							<Text
								value={`${unlockedCount}/${entries.size()} unlocked     ${maxedCount} maxed     kept on rebirth`}
								size={11}
								color={Palette.creamSoft}
								wrap={true}
								fit={true}
								minSize={9}
								position={UDim2.fromOffset(heroStack ? 0 : 72, heroStack ? 108 : 56)}
								sizeConstraint={new UDim2(1, heroStack ? -8 : -332, 0, 24)}
							/>
							{!heroStack && (
								<>
									<AmountToggle
										value={buyAmount}
										onChange={setBuyAmount}
										accent={Palette.cyan}
										position={new UDim2(1, -240, 0, 16)}
										size={UDim2.fromOffset(240, 32)}
										reducedMotion={softMotion}
									/>
									<frame
										{...named("ResearchBuyClaimActions")}
										Size={UDim2.fromOffset(240, 32)}
										Position={new UDim2(1, -240, 0, 56)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										ClipsDescendants={false}
										ref={canBuyAll ? buyAllHostRef : undefined}
									>
										<Button
											text={batch.busy ? batch.status : `BUY BATCH (${batch.count})`}
											icon="Flux.8"
											onClick={onBuyAll}
											color={canBuyAll ? Palette.cyan : Palette.panelSoft}
											textColor={canBuyAll ? Palette.ink : Palette.muted}
											size={UDim2.fromScale(1, 1)}
											reducedMotion={softMotion}
											disabled={!canBuyAll}
											highlight={canBuyAll}
										/>
									</frame>
								</>
							)}
							{heroStack && (
								<>
									<AmountToggle
										value={buyAmount}
										onChange={setBuyAmount}
										accent={Palette.cyan}
										position={new UDim2(0, 0, 0, 132)}
										size={new UDim2(1, -104, 0, TapTarget)}
										reducedMotion={softMotion}
									/>
									<frame
										{...named("ResearchBuyClaimActions")}
										Size={UDim2.fromOffset(96, TapTarget)}
										Position={new UDim2(1, -96, 0, 132)}
										BackgroundTransparency={1}
										BorderSizePixel={0}
										ClipsDescendants={false}
										ref={canBuyAll ? buyAllHostRef : undefined}
									>
										<Button
											text={batch.busy ? "…" : `BUY ${batch.count}`}
											icon="Flux.9"
											onClick={onBuyAll}
											color={canBuyAll ? Palette.cyan : Palette.panelSoft}
											textColor={canBuyAll ? Palette.ink : Palette.muted}
											size={UDim2.fromScale(1, 1)}
											reducedMotion={softMotion}
											disabled={!canBuyAll}
											highlight={canBuyAll}
										/>
									</frame>
								</>
							)}
						</Panel>
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
					id: "chain",
					height: chainH,
					element:
						visible.size() === 0 ? (
							<ui.EmptyState
								title="No matching research"
								body="Try All research."
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
			]}
		/>
	);
}

export = { ResearchView };
