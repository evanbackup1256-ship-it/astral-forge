import React from "@rbxts/react";
import { AppHelpers } from "../../CoreKit/appNav";
import { useBackLayer } from "../../CoreKit/backLayer";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { compactNumber, Flux, gteFlux } from "../../CoreKit/format";
import * as PageBoardHeights from "../../CoreKit/pageBoardHeights";
import { chromeFor, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { loadPageScaffold, named } from "../luauDeps";
import { Planet } from "./portKit";
import { BODY, Chip, DiamondRule, Line, MockPanel, mockGap, PanelHeading, panelPad, RowSurface, TITLE_FACE } from "../../UiCore/mockKit";
import { headingBlock, MockBtn, MockRow, panelHeight, rowHeight, useWidth } from "../mockRows";

const PageScaffold = loadPageScaffold();

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

interface WorldCardProps {
	zone: ZoneDef;
	current: boolean;
	unlocked: boolean;
	canUnlock: boolean;
	missing?: string;
	onSelect: () => unknown;
	reducedMotion?: boolean;
	layoutOrder: number;
	phone: boolean;
	artHeight: number;
}

// 12-worlds map card: .row column, 300x140 engraved art (#110C13), then a 12/14 padded footer
function worldCardHeight(phone: boolean, artHeight: number): number {
	return artHeight + (phone ? 10 : 12) * 2 + (phone ? TapTarget : 38);
}

function WorldCard(props: WorldCardProps) {
	const { zone, current, unlocked, canUnlock, phone, artHeight } = props;
	const antilag = useAntilag();
	const skipMotion = props.reducedMotion === true || props.layoutOrder > 8 || antilag.skipEntrance;
	const reveal = useStagger(math.min(props.layoutOrder, 8), skipMotion, 0.03, 0.2);
	const locked = !current && !unlocked;
	const padY = phone ? 10 : 12;
	const padX = phone ? 12 : 14;
	const titleSize = phone ? 15 : 17;
	const action = current ? (
		<Chip text="Here" accent={Palette.mango} />
	) : unlocked ? (
		<MockBtn text="Travel" icon="Travel" sm={true} phone={phone} onClick={() => props.onSelect()} reducedMotion={props.reducedMotion} />
	) : canUnlock ? (
		<MockBtn text="Unlock" icon="Lock" sm={true} phone={phone} onClick={() => props.onSelect()} reducedMotion={props.reducedMotion} />
	) : (
		<MockBtn text={props.missing ?? "Locked"} icon="Lock" sm={true} sec={true} phone={phone} disabled={true} reducedMotion={props.reducedMotion} />
	);
	return (
		<frame
			{...named(`World${zone.Id}`)}
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.white}
			BackgroundTransparency={0}
			BorderSizePixel={0}
			LayoutOrder={props.layoutOrder}
			ClipsDescendants={true}
		>
			<RowSurface />
			<canvasgroup
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				GroupTransparency={reveal.map((v: number) => (locked ? 0.28 : 0) + (1 - math.clamp(v, 0, 1)) * 0.7)}
			>
				<uicorner CornerRadius={new UDim(0, 11)} />
				<frame Size={new UDim2(1, 0, 0, artHeight)} BackgroundColor3={Color3.fromRGB(17, 12, 19)} BorderSizePixel={0} ClipsDescendants={true}>
					<Planet color={zone.Color} size={math.floor(artHeight * 0.6)} position={UDim2.fromScale(0.68, 0.5)} dim={locked} />
				</frame>
				<frame Size={new UDim2(1, -padX * 2, 0, phone ? TapTarget : 38)} Position={UDim2.fromOffset(padX, artHeight + padY)} BackgroundTransparency={1} BorderSizePixel={0}>
					<Line text={zone.Name} size={titleSize} font={TITLE_FACE} width={new UDim(1, -(phone ? 120 : 130))} height={titleSize + 4} position={new UDim2(0, 0, 0.5, -titleSize / 2 - 6)} anchor={new Vector2(0, 0.5)} />
					<Line
						text={`Cash x${compactNumber(zone.Multiplier ?? 1)}`}
						size={phone ? 11 : 12}
						font={BODY}
						color={Palette.muted}
						width={new UDim(1, -(phone ? 120 : 130))}
						position={new UDim2(0, 0, 0.5, 10)}
						anchor={new Vector2(0, 0.5)}
					/>
					<frame Size={UDim2.fromScale(0, 1)} AutomaticSize={Enum.AutomaticSize.X} Position={UDim2.fromScale(1, 0)} AnchorPoint={new Vector2(1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} VerticalAlignment={Enum.VerticalAlignment.Center} HorizontalAlignment={Enum.HorizontalAlignment.Right} />
						{action}
					</frame>
				</frame>
			</canvasgroup>
		</frame>
	);
}

interface WorldsViewProps {
	state: WorldsState;
	config: WorldsConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	navigate?: (page: string) => void;
	[key: string]: unknown;
}

function WorldsView(props: WorldsViewProps) {
	const state = props.state;
	const config = props.config;
	const dispatch = props.dispatch;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const gap = mockGap(phone);
	const panelReveal = useStagger(0, softMotion);
	const worldsHostRef = React.useRef<Frame>();
	const scrollRef = React.useRef<ScrollingFrame>();
	const catalogTotal = config.MaxZone ?? config.Zones.size();
	const total = catalogTotal > 0 ? math.clamp(state.Zone + 2, 1, catalogTotal) : 0;
	const currentIdx = math.clamp((state.CurrentZone ?? 0) - 1, 0, math.max(0, total - 1));
	const [range, setRange] = React.useState(() => AppHelpers.worldWindowAround(currentIdx, total));
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
	const remainingBelow = math.max(0, total - rangeEnd);
	const remainingAbove = range.start;
	const canShowMore = remainingBelow > 0 || remainingAbove > 0;
	const showMore = () => {
		setRange((prev) => {
			const stop = math.min(total, prev.start + prev.count);
			if (stop < total) {
				const nextStart =
					prev.count >= AppHelpers.worldWindow.maxMounted
						? math.min(math.max(0, total - AppHelpers.worldWindow.maxMounted), prev.start + AppHelpers.worldWindow.chunk)
						: prev.start;
				return {
					start: nextStart,
					count: math.min(AppHelpers.worldWindow.maxMounted, total - nextStart, stop - nextStart + AppHelpers.worldWindow.chunk),
				};
			}
			if (prev.start > 0) {
				const nextStart = math.max(0, prev.start - AppHelpers.worldWindow.chunk);
				return { start: nextStart, count: math.min(AppHelpers.worldWindow.maxMounted, total - nextStart) };
			}
			return prev;
		});
	};
	const resolveZone = (id: number) => (config.ResolveZone !== undefined ? config.ResolveZone(id) : config.Zones[id - 1]);
	const missingFor = (zone: ZoneDef): string | undefined => {
		if (state.Rebirths < zone.RequiredRebirths) return `Rebirth ${compactNumber(zone.RequiredRebirths)}`;
		if (state.Cores < zone.CoreCost) return `${compactNumber(zone.CoreCost)} cores`;
		if (!gteFlux(state.Cash, zone.Cost)) return `${compactNumber(zone.Cost)} cash`;
		return undefined;
	};
	// .pn grid: repeat(4, 1fr) gap 12 on desktop; the phone shows two cards a row with no panel around them
	const columns = phone ? 2 : viewport.width >= 1200 ? 4 : viewport.width >= 800 ? 3 : 2;
	const cardGap = phone ? gap : 12;
	const [gridWidth, onGridSize] = useWidth(phone ? 700 : 1500);
	const cellWidth = math.max(120, (gridWidth - cardGap * (columns - 1)) / columns);
	const artHeight = math.floor((cellWidth * 140) / 300);
	const cardH = worldCardHeight(phone, artHeight);
	const cards: React.Element[] = [];
	let nextLocked: ZoneDef | undefined;
	for (let index = range.start; index < rangeEnd; index++) {
		const zone = resolveZone(index + 1);
		if (zone === undefined) continue;
		const unlocked = state.Zone >= zone.Id;
		const missing = unlocked ? undefined : missingFor(zone);
		const canUnlock = !unlocked && zone.Id === state.Zone + 1 && missing === undefined;
		if (!unlocked && nextLocked === undefined) nextLocked = zone;
		cards.push(
			<WorldCard
				key={zone.Id}
				zone={zone}
				current={(state.CurrentZone ?? state.Zone) === zone.Id}
				unlocked={unlocked}
				canUnlock={canUnlock}
				missing={missing}
				reducedMotion={softMotion}
				onSelect={() => dispatch(unlocked ? "SelectZone" : "UnlockZone", { Id: zone.Id })}
				layoutOrder={index - range.start + 1}
				phone={phone}
				artHeight={artHeight}
			/>,
		);
	}
	const gridRows = math.max(1, math.ceil(cards.size() / columns));
	const gridH = gridRows * cardH + (gridRows - 1) * cardGap;
	const grid = (
		<frame
			{...named("WorldGrid")}
			Size={new UDim2(1, 0, 0, gridH)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			LayoutOrder={1}
			Change={{ AbsoluteSize: onGridSize }}
		>
			<uigridlayout
				CellSize={new UDim2(1 / columns, -math.ceil((cardGap * (columns - 1)) / columns), 0, cardH)}
				CellPadding={UDim2.fromOffset(cardGap, cardGap)}
				SortOrder={Enum.SortOrder.LayoutOrder}
				FillDirectionMaxCells={columns}
			/>
			{cards}
		</frame>
	);
	const nextLine =
		nextLocked !== undefined ? `${nextLocked.Name} at ${missingFor(nextLocked) ?? "the next unlock"}` : "Every world is open";
	// expedition board entry stays on Worlds (it was here before the port); one .row under the info rows
	const navigate = props.navigate;
	const board = (state as { ExpeditionBoard?: { Slots?: Array<{ Id: string; EndsAt: number }> } }).ExpeditionBoard;
	let out = 0;
	for (const slot of board?.Slots ?? []) if (slot.Id !== "") out += 1;
	const slotsTotal = board?.Slots?.size() ?? 3;
	const rowH = rowHeight(phone);
	const btnW = phone ? 150 : 140;
	const infoRows: React.Element[] = [
		<DiamondRule key="rule" layoutOrder={2} />,
		<MockRow key="travel" phone={phone} icon="Info" title="Travel cost" value="Free between open worlds" layoutOrder={3} />,
		<MockRow key="next" phone={phone} icon="Lock" title="Next unlock" value={nextLine} layoutOrder={4} />,
	];
	if (navigate !== undefined) {
		infoRows.push(
			<MockRow
				key="exp"
				phone={phone}
				icon="Command"
				title="Expeditions"
				value={out > 0 ? `${out}/${slotsTotal} out` : undefined}
				rightWidth={btnW}
				right={<MockBtn text="Open" sm={true} sec={true} phone={phone} width={btnW} onClick={() => navigate("Expeditions")} reducedMotion={softMotion} />}
				layoutOrder={5}
			/>,
		);
	}
	if (canShowMore) {
		infoRows.push(
			<MockBtn
				key="more"
				text={remainingBelow > 0 ? `Show more (${remainingBelow} left)` : `Show earlier (${remainingAbove})`}
				icon="Chevron"
				sec={true}
				fill={true}
				phone={phone}
				onClick={showMore}
				reducedMotion={softMotion}
				layoutOrder={6}
			/>,
		);
	}
	const infoH = 12 + 12 + rowH * 2 + 12 * 2 + (navigate !== undefined ? rowH + 12 : 0) + (canShowMore ? (phone ? TapTarget : 44) + 12 : 0);
	const panelGap = panelPad(phone).gap;
	const body = phone ? (
		<frame Size={new UDim2(1, 0, 0, gridH + panelGap + infoH)} BackgroundTransparency={1} BorderSizePixel={0}>
			<uilistlayout Padding={new UDim(0, panelGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{grid}
			{infoRows}
		</frame>
	) : (
		<MockPanel size={new UDim2(1, 0, 0, panelHeight(false, headingBlock(false) + gridH + panelGap + infoH))} phone={false} reveal={panelReveal} reducedMotion={softMotion} name="WorldMap">
			<PanelHeading icon="World" title="Map" phone={false} layoutOrder={0} />
			{grid}
			{infoRows}
		</MockPanel>
	);
	const bodyH = phone ? gridH + panelGap + infoH : panelHeight(false, headingBlock(false) + gridH + panelGap + infoH);
	useFocusOrder(worldsHostRef, { regions: ["map"], first: ["map"] }, [state.CurrentZone, state.Zone, range.start]);
	return (
		<frame ref={worldsHostRef} {...named("WorldsTravelClaim")} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			<PageScaffold
				hostRef={scrollRef}
				gap={gap}
				tailPad={scrollTail(phone, chrome.bottomSafe, 40) + Layout.stackGap * 2}
				scrollBarColor={Palette.mango}
				scrollBarThickness={4}
				sections={[{ id: "map", height: bodyH, element: body }]}
			/>
		</frame>
	);
}

export = { WorldsView };
