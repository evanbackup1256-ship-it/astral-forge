import React from "@rbxts/react";
import Tools = require("../../UpgradeTools");
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { useClock, useStagger, useViewport } from "../../MotionKit/motion";
import { useTooltip } from "../../Tooltip";
import { chromeFor, darken, ensureContrast, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { bulkCost, compactNumber, compareFlux, Flux, gteFlux } from "../../CoreKit/format";
import { AppHelpers, NavState, UpgradeConfig, UpgradeEntry } from "../../CoreKit/appNav";
import * as PageBoardHeights from "../../CoreKit/pageBoardHeights";
import { Component, loadBrowse, loadPageScaffold, loadUi, luauKit, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const { AmountToggle, Badge, Button, Dropdown, EmptyState, IconTile, Panel, Text, SearchField } = loadUi();
const PageScaffold = loadPageScaffold();
const VirtualGrid = luauKit<{ VirtualGrid: Component }>("LayoutKit", "scrolling").VirtualGrid;

interface MachineConfig extends UpgradeConfig {
	Accent?: Color3;
	Color: Color3;
	Icon?: string;
	Description?: string;
	BaseProduction?: number;
}
type Entry = UpgradeEntry<MachineConfig>;
type ModelEntry = Parameters<typeof Tools.Model.quote>[0];
type ModelEntries = Parameters<typeof Tools.Model.filter>[0];
type Dispatch = (action: unknown, payload: unknown, reply?: (response: unknown) => void) => unknown;

interface WorkshopState {
	Cash?: Flux;
	Production?: unknown;
	Machines: Record<string, number | undefined>;
	Zone: number;
	Rebirths: number;
	AutoForge?: { Enabled: boolean; MachineId: string; Reserve: number; Bought: number };
	[key: string]: unknown;
}

function MachineRow(props: {
	machine: MachineConfig;
	level: number;
	cash: Flux;
	buyAmount: number;
	reducedMotion?: boolean;
	onBuy: () => unknown;
	y?: number;
	x?: UDim2;
	width?: UDim2;
	unlocked: boolean;
	lockReason: string;
	lockShort?: string;
}) {
	const { machine, level, cash, buyAmount, onBuy, y, x, width, unlocked, lockReason } = props;
	const lockShort = props.lockShort ?? "";
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const softMotion = props.reducedMotion;
	const reducedMotion = softMotion;
	const rowH = PageBoardHeights.Machine(stack);
	const price = bulkCost(machine.BaseCost, machine.CostScale, level, buyAmount, machine.MaxLevel, cash);
	const maxed = level >= machine.MaxLevel;
	const ready = unlocked && gteFlux(cash, price) && !maxed;
	const accent = machine.Accent ?? machine.Color;
	const running = level > 0;
	const flow = useClock(running, 0.55, 1);
	const buyLabel = !unlocked
		? lockShort !== ""
			? lockShort
			: "Locked"
		: maxed
			? "Maxed"
			: ready
				? level < 1
					? "Buy this"
					: "Buy level"
				: `Need ${compactNumber(price)} Flux`;
	const production = machine.BaseProduction ?? 0;
	const hasOutput = production > 0;
	const rateLine = !unlocked
		? lockReason
		: hasOutput
			? level < 1
				? `+${compactNumber(production)} Flux/sec once bought`
				: `${compactNumber(production)} Flux/sec · level ${compactNumber(level)}`
			: maxed
				? `Level ${compactNumber(level)} · maxed`
				: `Level ${compactNumber(level)} · next ${compactNumber(price)}`;
	// a locked card still says what it will give, so it isn't half empty
	const lockedGain = !unlocked && hasOutput ? `+${compactNumber(machine.BaseProduction)} Flux/sec once unlocked` : undefined;
	// machine accents can be deep (violet, indigo); lift them until the line reads on the card
	const rateColor = ensureContrast(Palette.panel, accent, 4.5);
	const cardWidth = width !== undefined ? width.X.Offset + width.X.Scale * viewport.width : viewport.width;
	const buttonBesideText = !stack && cardWidth >= 360;
	const absolute = y !== undefined || x !== undefined;
	const layoutY = y === undefined ? 0 : y;
	const tip = useTooltip({
		title: machine.Name,
		body: unlocked ? machine.Description : lockReason,
		hint: !unlocked
			? undefined
			: maxed
				? "Fully upgraded."
				: hasOutput
					? `Next ${buyAmount > 1 ? `${buyAmount} levels` : "level"}: ${compactNumber(price)} Flux`
					: `Next: ${compactNumber(price)} Flux`,
		accent: accent,
	});
	return (
		<frame
			Event={tip}
			Size={absolute ? (width ?? new UDim2(1, 0, 0, rowH)) : UDim2.fromScale(1, 1)}
			Position={x !== undefined ? new UDim2(x.X.Scale, x.X.Offset, 0, layoutY) : UDim2.fromOffset(0, layoutY)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={accent}
				background={Palette.panel}
				padding={stack ? chrome.cardPadding : 14}
				interactive={true}
				reducedMotion={softMotion}
			>
				<IconTile
					kind={unlocked ? (machine.Icon ?? "Forge") : "Lock"}
					accent={unlocked ? machine.Color : Palette.muted}
					size={46}
					radius={12}
					position={UDim2.fromOffset(0, stack ? 6 : 16)}
					glow={unlocked && running && ready && !softMotion}
					filled={running}
					spin={false}
					reducedMotion={softMotion}
				/>
				<frame
					Size={buttonBesideText ? new UDim2(1, -226, 1, -4) : new UDim2(1, -60, 0, 78)}
					Position={UDim2.fromOffset(58, stack || !buttonBesideText ? 2 : 4)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					<frame Size={new UDim2(1, 0, 0, 22)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
						<uilistlayout
							FillDirection={Enum.FillDirection.Horizontal}
							Padding={new UDim(0, 8)}
							SortOrder={Enum.SortOrder.LayoutOrder}
							VerticalAlignment={Enum.VerticalAlignment.Center}
						/>
						<Text
							value={machine.Name}
							size={stack ? 17 : 16}
							color={unlocked ? Palette.cream : Palette.muted}
							weight={Enum.FontWeight.Heavy}
							fit={true}
							minSize={11}
							layoutOrder={0}
							sizeConstraint={new UDim2(1, level > 0 ? -66 : 0, 0, 22)}
						/>
						{level > 0 && (
							<Badge
								value={maxed ? "MAX" : `LV ${compactNumber(level)}`}
								accent={maxed ? Palette.cyan : accent}
								size={UDim2.fromOffset(58, 18)}
								filled={true}
								layoutOrder={1}
							/>
						)}
					</frame>
					<Text
						value={unlocked ? machine.Description : lockReason}
						size={stack ? chrome.labelText : 11}
						color={unlocked ? Palette.muted : machine.Color}
						weight={unlocked ? Enum.FontWeight.Regular : Enum.FontWeight.Bold}
						wrap={true}
						position={UDim2.fromOffset(0, 24)}
						sizeConstraint={new UDim2(1, -4, 0, stack ? 42 : 34)}
					/>
					{(unlocked || lockedGain !== undefined) && (
						<Text
							value={unlocked ? rateLine : lockedGain}
							size={stack ? chrome.labelText : 11}
							color={unlocked ? rateColor : Palette.muted}
							weight={Enum.FontWeight.Bold}
							fit={true}
							minSize={9}
							position={UDim2.fromOffset(0, stack ? 72 : 64)}
							sizeConstraint={new UDim2(1, -4, 0, 16)}
						/>
					)}
					{running && (
						<frame
							Size={new UDim2(1, 0, 0, 2)}
							Position={UDim2.fromOffset(0, stack || !buttonBesideText ? 88 : 84)}
							BackgroundColor3={Palette.line}
							BackgroundTransparency={0.4}
							BorderSizePixel={0}
							ClipsDescendants={true}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
							<frame
								Size={new UDim2(0.28, 0, 1, 0)}
								Position={flow.map((phase) => new UDim2(phase * 1.4 - 0.32, 0, 0, 0))}
								BackgroundColor3={accent}
								BorderSizePixel={0}
							>
								<uicorner CornerRadius={new UDim(1, 0)} />
								<uigradient
									Transparency={
										new NumberSequence([
											new NumberSequenceKeypoint(0, 1),
											new NumberSequenceKeypoint(0.5, 0.1),
											new NumberSequenceKeypoint(1, 1),
										])
									}
								/>
							</frame>
						</frame>
					)}
				</frame>
				{!ready && unlocked && !maxed ? (
					<Button
						text={buyLabel}
						icon="Flux.10"
						onClick={onBuy}
						color={Palette.panelSoft}
						textColor={Palette.creamSoft}
						size={buttonBesideText ? UDim2.fromOffset(150, TapTarget) : new UDim2(1, 0, 0, TapTarget)}
						position={buttonBesideText ? new UDim2(1, -158, 0.5, -TapTarget / 2) : new UDim2(0, 0, 1, -(TapTarget + 4))}
						reducedMotion={softMotion}
						disabled={true}
						highlight={false}
					/>
				) : (
					<Button
						text={buyLabel}
						icon={unlocked ? "Flux.11" : "Lock.4"}
						onClick={onBuy}
						color={ready ? machine.Color : Palette.panelSoft}
						textColor={ready ? Palette.ink : Palette.creamSoft}
						size={buttonBesideText ? UDim2.fromOffset(150, TapTarget) : new UDim2(1, 0, 0, TapTarget)}
						position={buttonBesideText ? new UDim2(1, -158, 0.5, -TapTarget / 2) : new UDim2(0, 0, 1, -(TapTarget + 4))}
						reducedMotion={softMotion}
						disabled={!ready}
						highlight={ready}
					/>
				)}
			</Panel>
		</frame>
	);
}

const SORT_OPTIONS = [
	{ id: "Return", label: "Best level return" },
	{ id: "Default", label: "Tier order" },
	{ id: "Cheapest", label: "Cheapest first" },
	{ id: "Output", label: "Biggest level gain" },
	{ id: "Level", label: "Highest level" },
];

function UpgradeBoard(props: {
	title: string;
	eyebrow: string;
	blurb: string;
	accent: Color3;
	entries: Entry[];
	state: WorkshopState;
	buyAmount: number;
	setBuyAmount: (amount: number) => void;
	reducedMotion?: boolean;
	dispatch: Dispatch;
	featurePanel?: React.Element;
	featurePanelHeight?: number;
}) {
	const { title, eyebrow, blurb, accent, entries, state, buyAmount, setBuyAmount, featurePanel } = props;
	const featurePanelHeight = props.featurePanelHeight ?? 0;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const softMotion = props.reducedMotion;
	const reducedMotion = softMotion;
	const workshopHostReveal = useStagger(4, softMotion);
	const workshopBuyHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = workshopBuyHostRef.current;
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
	}, [buyAmount, entries.size()]);
	const Browse = loadBrowse();
	const [query, setQuery] = Browse.useLinkedQuery("Workshop");
	const [sort, setSort] = React.useState("Default");
	const [filter, setFilter] = React.useState("All");
	const headerReveal = useStagger(0, softMotion);
	useStagger(1, softMotion);
	useStagger(2, softMotion);
	useStagger(3, softMotion);
	const cash = state.Cash;
	const canBuy = (entry: Entry) => Tools.Model.quote(entry as unknown as ModelEntry, buyAmount, cash).ready;
	const affordableCount = entries.reduce((total, entry) => total + (canBuy(entry) ? 1 : 0), 0);
	const ownedCount = entries.reduce((total, entry) => total + (entry.level > 0 ? 1 : 0), 0);
	const near = AppHelpers.trimFarLockedUpgrades(entries);
	const nextCount = near.reduce((total, entry) => total + (!entry.unlocked ? 1 : 0), 0);
	const filterOptions = [
		{ id: "All", label: "Near unlocks", count: near.size() },
		{ id: "Affordable", label: "Can afford", count: affordableCount },
		{ id: "Owned", label: "Owned", count: ownedCount },
		{ id: "Next", label: "Coming up", count: nextCount },
	];
	const needle = (query.match("^%s*(.-)%s*$")[0] as string).lower();
	const pool = needle !== "" ? entries : near;
	const visible: Entry[] = [];
	for (const entry of pool) {
		if (filter === "Affordable" && !canBuy(entry)) {
			continue;
		}
		if (filter === "Owned" && entry.level <= 0) {
			continue;
		}
		if (filter === "Next" && entry.unlocked) {
			continue;
		}
		if (needle !== "" && !loadBrowse().matches(needle, entry.config.Name, entry.config.Description)) {
			continue;
		}
		visible.push(entry);
	}
	visible.sort((left, right) => {
		if (sort === "Return") {
			const leftRank = canBuy(left) ? 0 : left.unlocked && !left.maxed ? 1 : 2;
			const rightRank = canBuy(right) ? 0 : right.unlocked && !right.maxed ? 1 : 2;
			if (leftRank !== rightRank) {
				return leftRank < rightRank;
			}
			const a = Tools.Model.returnScore(left as unknown as ModelEntry);
			const b = Tools.Model.returnScore(right as unknown as ModelEntry);
			if (a !== b) {
				return a > b;
			}
		} else if (sort === "Cheapest") {
			const comparison = compareFlux(
				Tools.Model.quote(left as unknown as ModelEntry, buyAmount, cash).cost as Flux,
				Tools.Model.quote(right as unknown as ModelEntry, buyAmount, cash).cost as Flux,
			);
			if (comparison !== 0) {
				return comparison < 0;
			}
		} else if (sort === "Output") {
			const a = Tools.Model.gainScore(left as unknown as ModelEntry);
			const b = Tools.Model.gainScore(right as unknown as ModelEntry);
			if (a !== b) {
				return a > b;
			}
		} else if (sort === "Level" && left.level !== right.level) {
			return left.level > right.level;
		}
		return left.order < right.order;
	});
	const batch = Tools.useBatch(props.dispatch, "BuyMachine", visible as unknown as ModelEntries, buyAmount, cash);
	const onBuy = batch.buy;
	const onBuyAll: (() => boolean) | undefined = batch.start;
	const stack = chrome.contentStack;
	const touchLayout = chrome.mobile;
	const searchW = 252;
	const sortW = 176;
	const filterW = 176;
	const controlGap = 12;
	const controlsWrap = !stack && viewport.width < 900;
	const stackControlsY = chrome.landscape ? 40 : 56;
	const headerHeight = chrome.landscape && stack ? 136 : stack ? 268 : controlsWrap ? 232 : 188;
	const rowH = PageBoardHeights.Machine(stack);
	const gap = stack ? chrome.panelGap : Layout.panelGap;
	// machine cards put their buy button beside the text; below ~460px a card can't fit both, so add columns late
	const columns = stack ? 1 : viewport.width >= 2400 ? 4 : viewport.width >= 1750 ? 3 : viewport.width >= 900 ? 2 : 1;
	const columnWidth = new UDim2(1 / columns, -(gap * (columns - 1)) / columns, 0, rowH);
	const gridRows = math.ceil(math.max(1, visible.size()) / columns);
	const machinesBlock = visible.size() === 0 ? 150 : gridRows * rowH + math.max(0, gridRows - 1) * gap;
	const machineScrollTail = stack
		? scrollTail(stack, chrome.bottomSafe, chrome.landscape ? 52 : 80)
		: scrollTail(stack, chrome.bottomSafe, 28);
	const scrollRef = React.useRef<ScrollingFrame>();
	React.useEffect(() => {
		const host = scrollRef.current;
		if (host) {
			host.CanvasPosition = Vector2.zero;
		}
	}, [query, sort, filter]);
	const controlH = TapTarget;
	const desktopControlH = touchLayout ? TapTarget : 40;
	const controlsY = controlsWrap ? 98 : 100;
	const sortX = searchW + controlGap;
	const filterX = sortX + sortW + controlGap;
	const wrapRowY = controlsY + desktopControlH + 6;
	const stackCompact = stack && chrome.landscape;
	const stackSearchY = stackControlsY + controlH + 6;
	const stackFilterY = stackControlsY + (controlH + 6) * 2;
	const buyAll = () => (onBuyAll !== undefined ? onBuyAll() : undefined);
	const headerPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={accent}
			background={Palette.panelRaised}
			padding={stack ? chrome.cardPadding : 14}
			reveal={headerReveal}
			zIndex={30}
			clips={false}
		>
			<Text
				value={eyebrow}
				size={10}
				color={accent}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				sizeConstraint={new UDim2(1, stack ? -8 : -248, 0, stack ? 14 : 18)}
			/>
			<Text
				value={title}
				size={stack ? (stackCompact ? 18 : 20) : 24}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(0, stack ? 14 : 16)}
				sizeConstraint={new UDim2(1, stack ? -8 : -248, 0, stack ? 26 : 30)}
			/>
			{!stackCompact && (
				<Text
					value={blurb}
					size={stack ? chrome.labelText : 12}
					color={Palette.creamSoft}
					wrap={true}
					position={UDim2.fromOffset(0, stack ? 42 : 46)}
					sizeConstraint={new UDim2(1, stack ? -8 : -248, 0, stack ? 20 : 34)}
				/>
			)}
			{!stack && (
				<>
					<Text
						value={compactNumber(state.Production) + " / sec"}
						size={14}
						color={accent}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={new UDim2(1, -236, 0, 2)}
						sizeConstraint={new UDim2(0, 228, 0, 18)}
						align={Enum.TextXAlignment.Right}
					/>
					<AmountToggle
						value={buyAmount}
						onChange={setBuyAmount}
						accent={accent}
						position={new UDim2(1, -236, 0, 22)}
						size={UDim2.fromOffset(228, desktopControlH)}
						reducedMotion={reducedMotion}
					/>
					<Button
						text={batch.busy ? batch.status : batch.count > 0 ? `Buy batch · ${batch.count}` : "Nothing to buy yet"}
						icon="Flux.12"
						onClick={buyAll}
						color={affordableCount > 0 ? accent : Palette.panelSoft}
						textColor={affordableCount > 0 ? Palette.ink : Palette.muted}
						size={UDim2.fromOffset(228, 30)}
						position={new UDim2(1, -236, 0, 66)}
						disabled={batch.count <= 0 || batch.busy || onBuyAll === undefined}
						reducedMotion={reducedMotion}
						highlight={affordableCount > 0}
					/>
					<SearchField
						value={query}
						onChange={setQuery}
						accent={accent}
						placeholder="Search upgrades"
						position={UDim2.fromOffset(0, controlsY)}
						size={UDim2.fromOffset(searchW, desktopControlH)}
						reducedMotion={reducedMotion}
						zIndex={31}
					/>
					{controlsWrap ? (
						<>
							<Dropdown
								options={SORT_OPTIONS}
								value={sort}
								onChange={setSort}
								accent={accent}
								position={UDim2.fromOffset(0, wrapRowY)}
								size={UDim2.fromOffset(sortW, desktopControlH)}
								reducedMotion={reducedMotion}
								zIndex={44}
							/>
							<Dropdown
								options={filterOptions}
								value={filter}
								onChange={setFilter}
								accent={accent}
								position={UDim2.fromOffset(sortW + controlGap, wrapRowY)}
								size={UDim2.fromOffset(filterW, desktopControlH)}
								reducedMotion={reducedMotion}
								zIndex={42}
							/>
						</>
					) : (
						<>
							<Dropdown
								options={SORT_OPTIONS}
								value={sort}
								onChange={setSort}
								accent={accent}
								position={UDim2.fromOffset(sortX, controlsY)}
								size={UDim2.fromOffset(sortW, desktopControlH)}
								reducedMotion={reducedMotion}
								zIndex={44}
							/>
							<Dropdown
								options={filterOptions}
								value={filter}
								onChange={setFilter}
								accent={accent}
								position={UDim2.fromOffset(filterX, controlsY)}
								size={UDim2.fromOffset(filterW, desktopControlH)}
								reducedMotion={reducedMotion}
								zIndex={42}
							/>
						</>
					)}
				</>
			)}
			{stack && (
				<>
					<AmountToggle
						value={buyAmount}
						onChange={setBuyAmount}
						accent={accent}
						position={new UDim2(0, 0, 0, stackControlsY)}
						size={new UDim2(0.62, -6, 0, controlH)}
						reducedMotion={reducedMotion}
					/>
					<Button
						text={batch.busy ? batch.status : batch.count > 0 ? `Buy batch · ${batch.count}` : "Nothing to buy"}
						icon="Flux.13"
						onClick={buyAll}
						color={affordableCount > 0 ? accent : Palette.panelSoft}
						textColor={affordableCount > 0 ? Palette.ink : Palette.muted}
						size={new UDim2(0.38, -6, 0, controlH)}
						position={new UDim2(0.62, 6, 0, stackControlsY)}
						disabled={batch.count <= 0 || batch.busy || onBuyAll === undefined}
						reducedMotion={reducedMotion}
						highlight={affordableCount > 0}
					/>
					{!stackCompact && (
						<SearchField
							value={query}
							onChange={setQuery}
							accent={accent}
							placeholder="Search upgrades"
							position={new UDim2(0, 0, 0, stackSearchY)}
							size={new UDim2(1, 0, 0, controlH)}
							reducedMotion={reducedMotion}
							zIndex={31}
						/>
					)}
					{!stackCompact && (
						<Dropdown
							options={SORT_OPTIONS}
							value={sort}
							onChange={setSort}
							accent={accent}
							position={new UDim2(0, 0, 0, stackFilterY)}
							size={new UDim2(0.5, -4, 0, controlH)}
							reducedMotion={reducedMotion}
							zIndex={44}
						/>
					)}
					{!stackCompact && (
						<Dropdown
							options={filterOptions}
							value={filter}
							onChange={setFilter}
							accent={accent}
							position={new UDim2(0.5, 4, 0, stackFilterY)}
							size={new UDim2(0.5, -4, 0, controlH)}
							reducedMotion={reducedMotion}
							zIndex={42}
						/>
					)}
				</>
			)}
		</Panel>
	);
	let machinesElement: React.Element;
	if (visible.size() === 0) {
		machinesElement = (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<EmptyState
					icon="Forge.9"
					title={
						needle !== "" || filter !== "All"
							? "Nothing matches"
							: (filter as string) === "Affordable"
								? "Can't afford a machine yet"
								: "No machines to show"
					}
					body={
						needle !== ""
							? "Clear the search to see the machines again."
							: filter === "Affordable"
								? "Collect Flux on Overview, then come back to buy the next machine."
								: filter !== "All"
									? "Switch the filter back to Near unlocks."
									: "Buy a machine to start earning Flux into your vault."
					}
					accent={accent}
					size={UDim2.fromScale(1, 1)}
				/>
				{filter === "Affordable" && affordableCount === 0 && (
					<Button
						text="Show next machines"
						icon="Forge.10"
						onClick={() => setFilter("All")}
						color={accent}
						textColor={Palette.ink}
						size={new UDim2(1, 0, 0, TapTarget)}
						position={new UDim2(0, 0, 1, -(TapTarget + 8))}
						reducedMotion={reducedMotion}
						highlight={true}
					/>
				)}
			</frame>
		);
	} else {
		machinesElement = (
			<VirtualGrid
				scrollRef={scrollRef}
				count={visible.size()}
				columns={columns}
				cellHeight={rowH}
				gap={gap}
				overscanRows={softMotion ? 0 : stack ? 2 : 3}
				itemKey={(index: number) => {
					const entry = visible[index] as Entry | undefined;
					return entry !== undefined ? entry.config.Id : `machine-${index}`;
				}}
				renderItem={(index: number) => {
					const entry = visible[index];
					return (
						<MachineRow
							machine={entry.config}
							level={entry.level}
							cash={state.Cash as Flux}
							buyAmount={buyAmount}
							reducedMotion={reducedMotion}
							onBuy={() => onBuy(entry.config.Id)}
							width={columnWidth}
							unlocked={entry.unlocked}
							lockReason={entry.lockReason}
							lockShort={entry.lockShort}
						/>
					);
				}}
			/>
		);
	}
	const sections: Array<{ id: string; height: number; element: React.Element }> = [
		{ id: "header", height: headerHeight, element: headerPanel },
		{
			id: "purchase-plan",
			height: 128,
			element: (
				<Tools.Planner entries={visible as unknown as ModelEntries} amount={buyAmount} cash={cash} batch={batch} accent={accent} />
			),
		},
		{ id: "machines", height: machinesBlock, element: machinesElement },
	];
	if (featurePanel !== undefined) {
		sections.push({ id: "autoforge", height: featurePanelHeight, element: featurePanel });
	}
	return (
		<frame
			{...named("WorkshopBuyClaim")}
			ref={workshopBuyHostRef}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
		>
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={Palette.cyan}
				background={Palette.panel}
				padding={0}
				reveal={workshopHostReveal}
				reducedMotion={reducedMotion}
				clips={false}
			>
				<PageScaffold
					hostRef={scrollRef}
					gap={gap}
					tailPad={machineScrollTail}
					scrollBarColor={accent}
					scrollBarThickness={4}
					sections={sections}
				/>
			</Panel>
		</frame>
	);
}

const AUTO_FORGE_RESERVES = [
	{ id: "NONE", label: "No reserve" },
	{ id: "SAFE", label: "Keep 25%" },
	{ id: "HALF", label: "Keep 50%" },
	{ id: "HIGH", label: "Keep 75%" },
];

function machineLocked(state: WorkshopState, machine: MachineConfig) {
	return (
		state.Zone < (machine.RequiredZone ?? 1) ||
		state.Rebirths < (machine.RequiredRebirths ?? 0) ||
		(machine.PreviousId !== undefined && (state.Machines[machine.PreviousId] ?? 0) < (machine.PreviousLevel ?? 1))
	);
}

function AutoForgePanel(props: {
	state: WorkshopState;
	machines: MachineConfig[];
	dispatch: Dispatch;
	reducedMotion?: boolean;
	height: number;
}) {
	const { state, machines, dispatch, height } = props;
	const viewport = useViewport();
	const softMotion = props.reducedMotion;
	const stack = chromeFor(viewport).stack;
	const queue = state.AutoForge ?? {
		Enabled: false,
		MachineId: (machines[0] as MachineConfig | undefined)?.Id ?? "StellarCore",
		Reserve: 0.25,
		Bought: 0,
	};
	const target = machines.find((machine) => machine.Id === queue.MachineId) ?? (machines[0] as MachineConfig | undefined);
	const machineOptions = (() => {
		const options: Array<{ id: string; label: string }> = [];
		const seen = new Set<string>();
		const push = (machine: MachineConfig) => {
			if (seen.has(machine.Id)) {
				return undefined;
			}
			seen.add(machine.Id);
			options.push({ id: machine.Id, label: machine.Name });
		};
		const current = machines.find((machine) => machine.Id === queue.MachineId);
		if (current !== undefined) {
			push(current);
		}
		for (let index = machines.size() - 1; index >= 0 && options.size() < 24; index--) {
			const machine = machines[index];
			if ((state.Machines[machine.Id] ?? 0) > 0) {
				push(machine);
			}
		}
		for (const machine of machines) {
			if (options.size() >= 40) {
				break;
			}
			if (machineLocked(state, machine)) {
				continue;
			}
			push(machine);
		}
		return options;
	})();
	const level = target !== undefined ? (state.Machines[target.Id] ?? 0) : 0;
	const nextCost: Flux =
		target !== undefined && level < target.MaxLevel ? bulkCost(target.BaseCost, target.CostScale, level, 1, target.MaxLevel) : 0;
	const targetLocked = target !== undefined && machineLocked(state, target);
	const waiting = !targetLocked && target !== undefined && level < target.MaxLevel && !gteFlux(state.Cash as Flux, nextCost);
	const status = !queue.Enabled
		? "PAUSED"
		: target === undefined || level >= target.MaxLevel
			? "TARGET COMPLETE"
			: targetLocked
				? "WAITING FOR UNLOCK"
				: waiting
					? `WAITING FOR ${compactNumber(nextCost)} FLUX`
					: "NEXT LEVEL QUEUED";
	const badgeStatus = !queue.Enabled
		? "PAUSED"
		: targetLocked
			? "LOCKED"
			: waiting
				? "WAITING"
				: target === undefined || level >= (target.MaxLevel ?? 0)
					? "DONE"
					: "LIVE";
	const apply = (enabled: boolean, machineId?: string, reserve?: number) =>
		dispatch("SetAutoForge", {
			Enabled: enabled,
			MachineId: machineId ?? queue.MachineId,
			Reserve: reserve ?? queue.Reserve,
		});
	const controlY = stack ? 124 : 102;
	const machineW = stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(270, 42);
	const reserveW = stack ? new UDim2(0.5, -5, 0, TapTarget) : UDim2.fromOffset(174, 42);
	const buttonW = stack ? new UDim2(0.5, -5, 0, TapTarget) : UDim2.fromOffset(158, 42);
	return (
		<Panel
			size={new UDim2(1, -4, 0, height)}
			accent={Palette.mango}
			background={darken(Palette.mango, 0.9)}
			padding={14}
			layoutOrder={1}
			reducedMotion={softMotion}
			zIndex={24}
			clips={false}
		>
			<IconTile
				kind="Forge"
				accent={queue.Enabled ? Palette.mango : Palette.muted}
				size={48}
				radius={12}
				position={UDim2.fromOffset(0, 0)}
				spin={queue.Enabled}
				reducedMotion={softMotion}
			/>
			<Text
				value="AUTO-FORGE"
				size={10}
				color={Palette.mango}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(62, 0)}
				sizeConstraint={new UDim2(1, stack ? -168 : -220, 0, 16)}
			/>
			<Text
				value="Your production queue"
				size={18}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(62, 16)}
				sizeConstraint={new UDim2(1, stack ? -168 : -220, 0, 24)}
			/>
			<Text
				value={
					stack
						? "Buys one level at a time and never spends your reserve."
						: "Pick a machine. Auto-Forge buys one affordable level at a time and leaves your saved Flux alone."
				}
				size={11}
				color={Palette.creamSoft}
				wrap={true}
				position={UDim2.fromOffset(62, 42)}
				sizeConstraint={new UDim2(1, stack ? -168 : -70, 0, stack ? 36 : 28)}
			/>
			<Badge
				value={stack ? badgeStatus : status}
				accent={queue.Enabled ? Palette.mint : Palette.muted}
				position={stack ? new UDim2(1, -92, 0, 0) : new UDim2(1, -210, 0, 4)}
				size={stack ? UDim2.fromOffset(88, 24) : UDim2.fromOffset(200, 22)}
			/>
			{!stack && (
				<Text
					value={`${compactNumber(queue.Bought)} AUTO LEVELS`}
					size={10}
					color={Palette.muted}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(1, -210, 0, 30)}
					sizeConstraint={new UDim2(0, 210, 0, 16)}
				/>
			)}
			<Dropdown
				options={machineOptions}
				value={target?.Id ?? machineOptions[0]?.id ?? "StellarCore"}
				onChange={(id: string) => apply(queue.Enabled, id, queue.Reserve)}
				accent={Palette.mango}
				label="TARGET MACHINE"
				position={UDim2.fromOffset(0, controlY)}
				size={machineW}
				reducedMotion={softMotion}
				zIndex={54}
			/>
			<Dropdown
				options={AUTO_FORGE_RESERVES}
				value={AppHelpers.reserveId(queue.Reserve)}
				onChange={(id: string) => apply(queue.Enabled, queue.MachineId, AppHelpers.reserveValue(id))}
				accent={Palette.cyan}
				label="FLUX RESERVE"
				position={stack ? UDim2.fromOffset(0, controlY + TapTarget + 26) : UDim2.fromOffset(282, controlY)}
				size={reserveW}
				reducedMotion={softMotion}
				zIndex={52}
			/>
			<frame
				Size={buttonW}
				Position={stack ? new UDim2(0.5, 5, 0, controlY + TapTarget + 26) : UDim2.fromOffset(468, controlY)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ZIndex={26}
			>
				<Button
					text={queue.Enabled ? "PAUSE QUEUE" : "START QUEUE"}
					icon={queue.Enabled ? "Pause.1" : "Play.1"}
					onClick={() => apply(!queue.Enabled)}
					color={queue.Enabled ? Palette.panelSoft : Palette.mango}
					textColor={queue.Enabled ? Palette.cream : Palette.ink}
					outline={queue.Enabled}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
					highlight={!queue.Enabled}
					zIndex={27}
				/>
			</frame>
		</Panel>
	);
}

function listedFluxPerSec(machine: unknown): number {
	const base = typeIs(machine, "table") ? (machine as { BaseProduction?: unknown }).BaseProduction : undefined;
	if (!typeIs(base, "number") || base <= 0) {
		return 0;
	}
	return base;
}

function WorkshopView(props: {
	state: WorkshopState;
	config?: { Machines?: unknown };
	dispatch: Dispatch;
	buyAmount: number;
	setBuyAmount: (amount: number) => void;
	reducedMotion?: boolean;
}) {
	const { state, config, dispatch, buyAmount, setBuyAmount, reducedMotion } = props;
	const machines = (config !== undefined && typeIs(config.Machines, "table") ? config.Machines : []) as MachineConfig[];
	const viewport = useViewport();
	const chainStack = chromeFor(viewport).contentStack;
	const stellarLevel = state.Machines.StellarCore ?? 0;
	const firstMachine = stellarLevel < 1;
	let ownedMachines = 0;
	for (const machine of machines) {
		if ((tonumber(state.Machines[machine.Id]) ?? 0) > 0) {
			ownedMachines += 1;
		}
	}
	let chainLine: string | undefined;
	if (!firstMachine) {
		const names: Record<string, string> = {};
		for (const machine of machines) {
			if (typeIs(machine, "table") && typeIs(machine.Id, "string")) {
				names[machine.Id] = typeIs(machine.Name, "string") ? machine.Name : machine.Id;
			}
		}
		for (const machine of machines) {
			if (!typeIs(machine, "table") || !typeIs(machine.PreviousId, "string")) {
				continue;
			}
			const rawNeed: unknown = machine.PreviousLevel;
			const needLevel = typeIs(rawNeed, "number") ? rawNeed : 1;
			const rawHave: unknown = state.Machines[machine.PreviousId];
			const haveLevel = typeIs(rawHave, "number") ? rawHave : 0;
			const rawRebirthsNeed: unknown = machine.RequiredRebirths;
			const rebirthsNeed = typeIs(rawRebirthsNeed, "number") ? rawRebirthsNeed : 0;
			const rawZoneNeed: unknown = machine.RequiredZone;
			const zoneNeed = typeIs(rawZoneNeed, "number") ? rawZoneNeed : 1;
			const rawRebirthsHave: unknown = state.Rebirths;
			const rebirthsHave = typeIs(rawRebirthsHave, "number") ? rawRebirthsHave : 0;
			const rawZoneHave: unknown = state.Zone;
			const zoneHave = typeIs(rawZoneHave, "number") ? rawZoneHave : 1;
			const machineName = typeIs(machine.Name, "string") ? machine.Name : machine.Id;
			const rate = listedFluxPerSec(machine);
			const earns = rate > 0 ? ` earns ${compactNumber(rate)} Flux/sec` : "";
			const rateBit = rate > 0 ? ` +${compactNumber(rate)}/sec` : "";
			if (rebirthsHave < rebirthsNeed) {
				chainLine = chainStack
					? `${machineName}${rateBit}. ${rebirthsHave}/${rebirthsNeed} rebirths.`
					: `${machineName}${earns}. Needs ${rebirthsNeed} rebirth${rebirthsNeed === 1 ? "" : "s"}. You have ${rebirthsHave}.`;
				break;
			} else if (zoneHave < zoneNeed) {
				chainLine = chainStack
					? `${machineName}${rateBit}. World ${zoneHave}/${zoneNeed}.`
					: `${machineName}${earns}. Needs world ${zoneNeed}. You are on world ${zoneHave}.`;
				break;
			} else if (haveLevel < needLevel) {
				const prevName = names[machine.PreviousId] ?? machine.PreviousId;
				chainLine = chainStack
					? `Next: ${machineName}${rateBit}. ${prevName} ${haveLevel}/${needLevel}.`
					: rate > 0
						? `Next: ${machineName} earns ${compactNumber(rate)} Flux/sec. Get ${prevName} to level ${needLevel}. You have ${haveLevel}.`
						: `Next: ${machineName}. Get ${prevName} to level ${needLevel}. You have ${haveLevel}.`;
				break;
			}
		}
	}
	const entries = React.useMemo(
		() => AppHelpers.buildUpgradeEntries(machines, state.Machines, state as NavState),
		[machines, state.Machines, state.Zone, state.Rebirths],
	);
	const featureHeight = chromeFor(viewport).landscape ? 128 : chromeFor(viewport).stack ? 188 : 168;
	return (
		<UpgradeBoard
			title={firstMachine ? "Buy a machine" : `${ownedMachines} machine${ownedMachines === 1 ? "" : "s"} running`}
			eyebrow={firstMachine ? "EARNS FLUX" : "BUILD QUEUE"}
			blurb={
				firstMachine
					? "A machine earns Flux into your vault every second."
					: chainLine !== undefined
						? chainLine
						: "More machines = more Flux, even while you're AFK."
			}
			accent={Palette.coral}
			entries={entries}
			state={state}
			buyAmount={buyAmount}
			setBuyAmount={setBuyAmount}
			reducedMotion={reducedMotion}
			dispatch={dispatch}
			featurePanelHeight={featureHeight}
			featurePanel={
				<AutoForgePanel state={state} machines={machines} dispatch={dispatch} reducedMotion={reducedMotion} height={featureHeight} />
			}
		/>
	);
}

export = { WorkshopView };
