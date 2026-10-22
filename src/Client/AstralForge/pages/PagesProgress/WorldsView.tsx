import React from "@rbxts/react";
import { AppHelpers } from "../../CoreKit/appNav";
import { compactNumber, Flux, gteFlux } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import * as PageBoardHeights from "../../CoreKit/pageBoardHeights";
import { chromeFor, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { loadBrowse, loadPageScaffold, loadUi, named } from "../luauDeps";

const UserInputService = game.GetService("UserInputService");
const { Badge, Button, IconTile, Panel, Text } = loadUi();
const PageScaffold = loadPageScaffold();
const Browse = loadBrowse();

const WORLD_SCAN = 600;
const WORLD_RESULTS = 60;

interface ZoneDef {
	Id: number;
	Name: string;
	Tagline?: string;
	Description?: string;
	Features?: string[];
	Multiplier?: Flux;
	Cost: Flux;
	CoreCost: number;
	RequiredRebirths: number;
	Color: Color3;
	DarkColor: Color3;
	[key: string]: unknown;
}
interface WorldsState {
	Zone: number;
	CurrentZone?: number;
	Rebirths: number;
	Cores: number;
	Cash: Flux;
	[key: string]: unknown;
}
interface WorldsConfig {
	Zones: ZoneDef[];
	MaxZone?: number;
	ResolveZone?: (this: void, id: number) => ZoneDef | undefined;
	[key: string]: unknown;
}
type Dispatch = (action: string, payload?: object) => unknown;
interface Section {
	id: string;
	height?: number;
	fill?: boolean;
	minHeight?: number;
	element: React.Element;
}

interface WorldRowProps {
	zone: ZoneDef;
	current: boolean;
	unlocked: boolean;
	canUnlock: boolean;
	onSelect: () => unknown;
	reducedMotion?: boolean;
	layoutOrder: number;
	stack: boolean;
	cashOk: boolean;
	coresOk: boolean;
	rebirthOk: boolean;
}

function WorldRow(props: WorldRowProps) {
	const { zone, current, unlocked, canUnlock, onSelect, layoutOrder, stack, cashOk, coresOk, rebirthOk } = props;
	const antilag = useAntilag();
	const softMotion = props.reducedMotion;
	const reducedMotion = softMotion;
	const skipMotion = softMotion || layoutOrder > 4 || antilag.skipEntrance;
	const reveal = useStagger(math.min(layoutOrder, 4), skipMotion, 0.02, 0.14);
	const feature = zone.Features?.[0] ?? zone.Description;
	const actionable = current || unlocked || canUnlock;
	const costBits: string[] = [];
	if (!unlocked && !current) {
		if (zone.RequiredRebirths > 0) {
			costBits.push(`${zone.RequiredRebirths} rebirth${zone.RequiredRebirths === 1 ? "" : "s"}`);
		}
		if (zone.CoreCost > 0) {
			costBits.push(`${compactNumber(zone.CoreCost)} cores`);
		}
		if (gteFlux(zone.Cost, 0.01)) {
			costBits.push(`${compactNumber(zone.Cost)} flux`);
		}
	}
	const costLine = costBits.size() > 0 ? costBits.join(" · ") : undefined;
	const missing =
		!unlocked && !current
			? !rebirthOk
				? `${zone.RequiredRebirths} rebirths`
				: !coresOk
					? `${compactNumber(zone.CoreCost)} cores`
					: !cashOk
						? `${compactNumber(zone.Cost)} flux`
						: undefined
			: undefined;
	const cta = current
		? "CURRENT"
		: unlocked
			? "ENTER"
			: canUnlock
				? "UNLOCK"
				: missing !== undefined
					? string.upper(missing)
					: "LOCKED";
	const btnColor = current ? Palette.green : unlocked ? Palette.green : canUnlock ? Palette.mango : Palette.panelSoft;
	const btnText = current || unlocked || canUnlock ? Palette.ink : Palette.muted;
	const rowH = PageBoardHeights.World(stack);
	return (
		<frame
			Size={new UDim2(1, -4, 0, rowH)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={layoutOrder}
			ClipsDescendants={false}
		>
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={zone.Color}
				background={current ? zone.DarkColor.Lerp(Palette.panelRaised, 0.45) : Palette.panel}
				padding={stack ? 18 : 22}
				reveal={reveal}
				interactive={!current}
				highlight={current}
				reducedMotion={skipMotion}
				clips={false}
			>
				<IconTile
					kind="World"
					accent={zone.Color}
					size={stack ? 48 : 56}
					radius={14}
					position={UDim2.fromOffset(0, stack ? 12 : 30)}
					spin={false}
					glow={current || canUnlock}
					filled={current}
					reducedMotion={reducedMotion}
				/>
				<frame
					Size={stack ? new UDim2(1, -64, 0, 126) : new UDim2(1, -200, 1, -6)}
					Position={UDim2.fromOffset(stack ? 60 : 72, stack ? 4 : 6)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					<frame Size={new UDim2(1, 0, 0, 26)} BackgroundTransparency={1} BorderSizePixel={0}>
						<uilistlayout
							FillDirection={Enum.FillDirection.Horizontal}
							Padding={new UDim(0, 8)}
							VerticalAlignment={Enum.VerticalAlignment.Center}
							SortOrder={Enum.SortOrder.LayoutOrder}
						/>
						<Text
							value={zone.Name}
							size={stack ? 18 : 19}
							color={Palette.cream}
							weight={Enum.FontWeight.Heavy}
							// the name sizes to itself so ACTIVE/READY sit right after it (a zero-width box hid it)
							autoWidth={true}
							layoutOrder={0}
							sizeConstraint={new UDim2(0, 0, 0, 26)}
						/>
						{current && (
							<frame Size={UDim2.fromOffset(8, 8)} BackgroundColor3={Palette.green} BorderSizePixel={0} LayoutOrder={1}>
								<uicorner CornerRadius={new UDim(1, 0)} />
							</frame>
						)}
						{canUnlock && (
							<frame Size={UDim2.fromOffset(8, 8)} BackgroundColor3={Palette.mango} BorderSizePixel={0} LayoutOrder={1}>
								<uicorner CornerRadius={new UDim(1, 0)} />
								<uistroke Color={Palette.mango} Thickness={2} Transparency={0.55} />
							</frame>
						)}
					</frame>
					<Text
						value={`${feature}  ·  ${AppHelpers.formatWorldMultiplier(tonumber(zone.Multiplier) ?? 0)}x`}
						size={stack ? 13 : 11}
						color={zone.Color}
						weight={Enum.FontWeight.Bold}
						fit={false}
						position={UDim2.fromOffset(0, 38)}
						sizeConstraint={new UDim2(1, 0, 0, 18)}
					/>
					{costLine !== undefined && (
						<Text
							value={costLine}
							size={12}
							color={canUnlock ? Palette.mango : Palette.muted}
							weight={Enum.FontWeight.Bold}
							fit={false}
							position={UDim2.fromOffset(0, 66)}
							sizeConstraint={new UDim2(1, 0, 0, 16)}
						/>
					)}
				</frame>
				<Button
					text={cta}
					tooltip={zone.Tagline}
					icon="World.4"
					onClick={onSelect}
					color={btnColor}
					textColor={btnText}
					size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(150, TapTarget)}
					position={stack ? new UDim2(0, 0, 1, -(TapTarget + 4)) : new UDim2(1, -166, 0.5, -TapTarget / 2)}
					reducedMotion={reducedMotion}
					disabled={!actionable || current}
					highlight={actionable && !current}
					zIndex={12}
				/>
			</Panel>
		</frame>
	);
}

interface WorldsViewProps {
	state: WorldsState;
	config: WorldsConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	navigate?: (page: string) => void;
}

function WorldsView(props: WorldsViewProps) {
	const state = props.state;
	const config = props.config;
	const dispatch = props.dispatch;
	const softMotion = props.reducedMotion;
	const reducedMotion = softMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const boardReveal = useStagger(0, softMotion);
	const travelReveal = useStagger(1, softMotion);
	const headerReveal = boardReveal;
	const worldsHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = worldsHostRef.current;
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
	}, [state.CurrentZone, state.Zone]);
	const barH = Browse.barHeight(stack, true);
	const headerHeight = (stack ? 168 : 112) + barH + 10;
	const rowHeight = PageBoardHeights.World(stack);
	const rowGap = stack ? chrome.panelGap : Layout.panelGap;
	const worldColumns = stack ? 1 : viewport.width >= 1700 ? 3 : viewport.width >= 1100 ? 2 : 1;
	const listPad = Layout.stackGap * 2;
	const catalogTotal = config.MaxZone ?? config.Zones.size();
	const total = catalogTotal > 0 ? math.clamp(state.Zone + 2, 1, catalogTotal) : 0;
	const currentIdx = math.clamp((state.CurrentZone ?? 0) - 1, 0, math.max(0, total - 1));
	const [range, setRange] = React.useState(() => AppHelpers.worldWindowAround(currentIdx, total));
	const scrollRef = React.useRef<ScrollingFrame>();
	React.useEffect(() => {
		setRange((prev) => {
			const stop = prev.start + prev.count;
			if (currentIdx >= prev.start && currentIdx < stop) {
				return prev;
			}
			return AppHelpers.worldWindowAround(currentIdx, total, AppHelpers.worldWindow.chunk);
		});
	}, [currentIdx, total]);
	const rangeEnd = math.min(total, range.start + range.count);
	let shownCount = math.max(0, rangeEnd - range.start);
	const remainingBelow = math.max(0, total - rangeEnd);
	const remainingAbove = range.start;
	let canShowMore = remainingBelow > 0 || remainingAbove > 0;
	const showMore = () => {
		setRange((prev) => {
			const stop = math.min(total, prev.start + prev.count);
			if (stop < total) {
				if (prev.count >= AppHelpers.worldWindow.maxMounted) {
					const nextStart = math.min(
						math.max(0, total - AppHelpers.worldWindow.maxMounted),
						prev.start + AppHelpers.worldWindow.chunk,
					);
					return {
						start: nextStart,
						count: math.min(AppHelpers.worldWindow.maxMounted, total - nextStart),
					};
				}
				return {
					start: prev.start,
					count: math.min(AppHelpers.worldWindow.maxMounted, total - prev.start, prev.count + AppHelpers.worldWindow.chunk),
				};
			}
			if (prev.start > 0) {
				if (prev.count >= AppHelpers.worldWindow.maxMounted) {
					const nextStart = math.max(0, prev.start - AppHelpers.worldWindow.chunk);
					return {
						start: nextStart,
						count: math.min(AppHelpers.worldWindow.maxMounted, total - nextStart),
					};
				}
				const grow = math.min(AppHelpers.worldWindow.chunk, prev.start, AppHelpers.worldWindow.maxMounted - prev.count);
				return {
					start: prev.start - grow,
					count: prev.count + grow,
				};
			}
			return prev;
		});
	};
	const jumpToCurrent = () => {
		const focused = AppHelpers.worldWindowAround(currentIdx, total, AppHelpers.worldWindow.chunk);
		setRange(focused);
		task.defer(() => {
			const scrolling = scrollRef.current;
			if (scrolling === undefined) {
				return;
			}
			const localIndex = math.clamp(currentIdx - focused.start, 0, math.max(0, focused.count - 1));
			scrolling.CanvasPosition = new Vector2(0, math.max(0, headerHeight + rowGap + localIndex * (rowHeight + rowGap) - 40));
		});
	};
	const moreLabel =
		remainingBelow > 0 ? `SHOW MORE  (${remainingBelow} left)` : remainingAbove > 0 ? `SHOW EARLIER  (${remainingAbove})` : "SHOW MORE";
	const worldTail = scrollTail(stack, chrome.bottomSafe, 40);
	const resolveZone = (id: number) => (config.ResolveZone !== undefined ? config.ResolveZone(id) : config.Zones[id - 1]);
	// search covers the newest WORLD_SCAN worlds you can see (owned plus the next stops)
	const zoneItems = React.useMemo(() => {
		const list: ZoneDef[] = [];
		for (let id = math.max(1, total - WORLD_SCAN + 1); id <= total; id++) {
			const zone = resolveZone(id);
			if (zone !== undefined) {
				list.push(zone);
			}
		}
		return list;
	}, [total]);
	const browse = Browse.useBrowse<ZoneDef>({
		id: "Worlds",
		items: zoneItems,
		text: (zone) => [zone.Name, zone.Tagline, (zone.Features ?? []).join(" "), zone.Description, `world ${zone.Id}`],
		categories: [
			{ id: "All", label: "All" },
			{
				id: "Owned",
				label: "Owned",
				test: (zone) => state.Zone >= zone.Id,
			},
			{
				id: "Locked",
				label: "Next stops",
				test: (zone) => state.Zone < zone.Id,
			},
			{
				id: "Current",
				label: "Current",
				test: (zone) => state.CurrentZone === zone.Id,
			},
		],
		sorts: [
			{ id: "Order", label: "World order" },
			{
				id: "Newest",
				label: "Newest first",
				compare: (a, b) => a.Id > b.Id,
			},
			{
				id: "Multiplier",
				label: "Best multiplier",
				compare: (a, b) => (tonumber(a.Multiplier) ?? 0) > (tonumber(b.Multiplier) ?? 0),
			},
			{
				id: "Name",
				label: "A to Z",
				compare: (a, b) => tostring(a.Name) < tostring(b.Name),
			},
		],
	});
	const browsing = browse.filtered || browse.sort !== "Order";
	const worldRow = (zone: ZoneDef, localOrder: number) => {
		const unlocked = state.Zone >= zone.Id;
		const rebirthOk = state.Rebirths >= zone.RequiredRebirths;
		const coresOk = state.Cores >= zone.CoreCost;
		const cashOk = gteFlux(state.Cash, zone.Cost);
		const canUnlock = !unlocked && zone.Id === state.Zone + 1 && rebirthOk && coresOk && cashOk;
		return (
			<WorldRow
				key={zone.Id}
				zone={zone}
				current={state.CurrentZone === zone.Id}
				unlocked={unlocked}
				canUnlock={canUnlock}
				cashOk={cashOk}
				coresOk={coresOk}
				rebirthOk={rebirthOk}
				reducedMotion={reducedMotion}
				onSelect={() => dispatch(unlocked ? "SelectZone" : "UnlockZone", { Id: zone.Id })}
				layoutOrder={localOrder}
				stack={stack}
			/>
		);
	};
	let rows: React.Element[] = [];
	if (browsing) {
		let order = 0;
		for (const zone of browse.results) {
			order += 1;
			if (order > WORLD_RESULTS) {
				break;
			}
			rows.push(worldRow(zone, order));
		}
		shownCount = rows.size();
		canShowMore = false;
	} else {
		for (let index = range.start; index < rangeEnd; index++) {
			const zone = resolveZone(index + 1);
			if (zone !== undefined) {
				rows.push(worldRow(zone, index - range.start + 1));
			}
		}
	}
	const gridRows = math.ceil(math.max(1, shownCount) / worldColumns);
	const rowsHeight = math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap);
	if (browsing && rows.size() === 0) {
		rows = [
			<Browse.NoResults
				key="none"
				browse={browse}
				noun="worlds"
				icon="World.5"
				accent={Palette.mint}
				reducedMotion={softMotion}
				size={new UDim2(1, 0, 0, rowHeight)}
			/>,
		];
	}
	const rowsBlock = (
		<frame
			Size={new UDim2(1, 0, 0, math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap))}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={1}
			ClipsDescendants={false}
		>
			{worldColumns > 1 ? (
				<uigridlayout
					CellSize={new UDim2(1 / worldColumns, -math.ceil((rowGap * (worldColumns - 1)) / worldColumns), 0, rowHeight)}
					CellPadding={UDim2.fromOffset(rowGap, rowGap)}
					SortOrder={Enum.SortOrder.LayoutOrder}
					FillDirectionMaxCells={worldColumns}
				/>
			) : (
				<uilistlayout
					FillDirection={Enum.FillDirection.Vertical}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, rowGap)}
				/>
			)}
			{rows}
		</frame>
	);
	const sections: Section[] = [
		{
			id: "header",
			height: headerHeight,
			element: (
				<Panel
					size={UDim2.fromScale(1, 1)}
					accent={Palette.mint}
					background={Palette.panelRaised}
					padding={stack ? 16 : 14}
					reveal={headerReveal}
					reducedMotion={softMotion}
					highlight={!softMotion && travelReveal !== undefined}
					layoutOrder={0}
					clips={false}
				>
					<Text
						value={
							state.CurrentZone !== undefined && state.CurrentZone !== state.Zone
								? `You are on World ${compactNumber(state.CurrentZone)} (Farthest: World ${compactNumber(state.Zone)})`
								: `You are on World ${compactNumber(state.CurrentZone ?? state.Zone)}`
						}
						size={stack ? chrome.titleText : 22}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={UDim2.fromOffset(0, 10)}
						sizeConstraint={new UDim2(1, stack ? -8 : -320, 0, 30)}
					/>
					{!stack && (
						<frame
							Size={UDim2.fromOffset(0, 42)}
							AutomaticSize={Enum.AutomaticSize.X}
							AnchorPoint={new Vector2(1, 0)}
							Position={new UDim2(1, 0, 0, 14)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							ClipsDescendants={false}
						>
							<uilistlayout
								FillDirection={Enum.FillDirection.Horizontal}
								HorizontalAlignment={Enum.HorizontalAlignment.Right}
								VerticalAlignment={Enum.VerticalAlignment.Center}
								Padding={new UDim(0, 10)}
								SortOrder={Enum.SortOrder.LayoutOrder}
							/>
							<Badge
								// how far along you are, rather than a bare catalogue size that reads like a typo next to "6 total"
								value={`${compactNumber(state.Zone ?? 1)} OF ${compactNumber(catalogTotal)} OPEN`}
								accent={Palette.mint}
								size={UDim2.fromOffset(150, 28)}
							/>
							<Button
								text="FIND CURRENT"
								icon="Search.3"
								onClick={() => {
									browse.reset();
									browse.setSort("Order");
									jumpToCurrent();
								}}
								color={Palette.mint}
								textColor={Palette.ink}
								size={UDim2.fromOffset(0, 42)}
								hug={true}
								reducedMotion={softMotion}
							/>
						</frame>
					)}
					{stack && (
						<Button
							text="FIND CURRENT"
							icon="Search.4"
							onClick={() => {
								browse.reset();
								browse.setSort("Order");
								jumpToCurrent();
							}}
							color={Palette.mint}
							textColor={Palette.ink}
							size={new UDim2(1, 0, 0, TapTarget)}
							position={new UDim2(0, 0, 1, -(TapTarget + 8 + barH + 10))}
							reducedMotion={softMotion}
						/>
					)}
					<Browse.BrowseBar
						browse={browse}
						placeholder="Search worlds by name or feature"
						accent={Palette.mint}
						stack={stack}
						reducedMotion={softMotion}
						position={new UDim2(0, 0, 1, -barH)}
						zIndex={30}
					/>
				</Panel>
			),
		},
		{
			id: "rows",
			height: rowsHeight,
			element: rowsBlock,
		},
	];
	// v8 Expedition Board: the way in sits right under the header
	const navigate = props.navigate;
	if (navigate !== undefined) {
		const board = (state as { ExpeditionBoard?: { Slots?: Array<{ Id: string; EndsAt: number }> } }).ExpeditionBoard;
		let out = 0;
		for (const slot of board?.Slots ?? []) if (slot.Id !== "") out += 1;
		const total = board?.Slots?.size() ?? 3;
		const entry: Section = {
			id: "expeditions",
			height: TapTarget + 8,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<Button
						text={out > 0 ? `Expeditions  ${out}/${total} out` : "Expeditions"}
						icon="Command.2"
						onClick={() => navigate("Expeditions")}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						size={new UDim2(1, 0, 0, TapTarget)}
						reducedMotion={softMotion}
						outline={true}
					/>
				</frame>
			),
		};
		const reordered: Section[] = [];
		sections.forEach((section, index) => {
			reordered.push(section);
			if (index === 0) reordered.push(entry);
		});
		sections.clear();
		for (const section of reordered) sections.push(section);
	}
	if (canShowMore) {
		sections.push({
			id: "more",
			height: TapTarget + 8,
			element: (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
					<Button
						text={moreLabel}
						icon="Chevron.2"
						onClick={showMore}
						color={Palette.panelSoft}
						textColor={Palette.cream}
						size={new UDim2(1, 0, 0, TapTarget)}
						reducedMotion={softMotion}
						outline={true}
					/>
				</frame>
			),
		});
	}
	return (
		<frame
			ref={worldsHostRef}
			{...named("WorldsTravelClaim")}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
		>
			<PageScaffold
				hostRef={scrollRef}
				gap={rowGap}
				tailPad={worldTail + listPad}
				scrollBarColor={Palette.mint}
				scrollBarThickness={4}
				sections={sections}
			/>
		</frame>
	);
}

export = { WorldsView };
