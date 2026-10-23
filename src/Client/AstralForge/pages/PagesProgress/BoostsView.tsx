import React from "@rbxts/react";
import { clockText, compactNumber, Flux } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, darken, Layout, lighten, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useClock, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { SplitColumns, SplitPlan, StackBlocks, splitColumns, stackHeight } from "../../UiCore/ui";
import { Bar, BODY, BODY_BOLD, BODY_SEMI, Glyph, MockPanel, PanelHeading, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { Grid, headingBlock, MockBtn, MockRow, panelHeight, Rise, RowFace, rowHeight } from "../mockRows";
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
const Workspace = game.GetService("Workspace");
const { Text } = loadUi();
const PageScaffold = loadPageScaffold();
const { FlatList } = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList");
const Browse = loadBrowse();

const GAP = 12;
const TICKS = 36;
const CARD_H = 176;

interface BoostDef {
	Id: string;
	Name: string;
	Color?: Color3;
	Multiplier?: Flux;
	CapacityMultiplier?: Flux;
	Duration?: number;
	Description?: string;
}
interface BoostPick {
	boost: BoostDef;
	owned: number;
}
interface BoostsState {
	BoostInventory?: Record<string, unknown>;
	ActiveBoost?: { Id?: string; EndsAt?: unknown };
	[key: string]: unknown;
}
interface BoostsConfig {
	Boosts?: Record<string, BoostDef>;
	Economy?: { Rebirth?: { StardustBoostPrices?: Record<string, number>; StardustBoostPerRebirth?: number } };
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

function boostIconKind(boostId: unknown): string {
	if (boostId === "DomainSurge") {
		return "Domain";
	} else if (boostId === "VaultSurge" || boostId === "StarforgeFlow" || boostId === "VaultTide") {
		return "Vault";
	} else if (boostId === "Hyperdrive") {
		return "World";
	}
	return "Reactor";
}

function headline(boost: BoostDef): [string, string] {
	const production = tonumber(boost.Multiplier);
	const vault = tonumber(boost.CapacityMultiplier);
	if (production !== undefined && vault !== undefined) {
		return [`${production}x`, `PRODUCTION · ${vault}x VAULT`];
	} else if (production !== undefined) {
		return [`${production}x`, "PRODUCTION"];
	} else if (vault !== undefined) {
		return [`${vault}x`, "VAULT"];
	}
	return ["+", "SPECIAL"];
}

// How much a boost is worth: extra production-minutes it adds (vault boosts count at a third).
function value(boost: BoostDef): number {
	const production = (tonumber(boost.Multiplier) ?? 1) - 1;
	const vault = ((tonumber(boost.CapacityMultiplier) ?? 1) - 1) / 3;
	return (production + vault) * (tonumber(boost.Duration) ?? 0);
}

interface GaugeProps {
	fraction: React.Binding<number>;
	accent: Color3;
	size: number;
	spin: React.Binding<number>;
	position?: UDim2;
	anchorPoint?: Vector2;
	children?: React.ReactNode;
}

function Gauge(props: GaugeProps) {
	const fraction = props.fraction;
	const accent = props.accent;
	const size = props.size;
	const spin = props.spin;
	const ticks: React.Element[] = [];
	for (let index = 0; index < TICKS; index++) {
		const threshold = index / TICKS;
		ticks.push(
			<frame
				key={index}
				Size={UDim2.fromScale(1, 1)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={index * (360 / TICKS)}
				BackgroundTransparency={1}
				ZIndex={3}
			>
				<frame
					Size={UDim2.fromOffset(4, math.max(8, math.floor(size * 0.09)))}
					Position={UDim2.fromScale(0.5, 0)}
					AnchorPoint={new Vector2(0.5, 0)}
					BackgroundColor3={accent}
					BackgroundTransparency={fraction.map((f) => (threshold < f ? 0.05 : 0.82))}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>,
		);
	}
	return (
		<frame
			Size={UDim2.fromOffset(size, size)}
			Position={props.position}
			AnchorPoint={props.anchorPoint}
			BackgroundTransparency={1}
			ZIndex={2}
		>
			<frame
				Size={UDim2.fromScale(0.78, 0.78)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={darken(accent, 0.78)}
				BorderSizePixel={0}
				ZIndex={2}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={accent} Thickness={2} Transparency={0.35}>
					<uigradient Color={new ColorSequence(new Color3(1, 1, 1), accent)} Rotation={spin} />
				</uistroke>
			</frame>
			{ticks}
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={6}>
				{props.children}
			</frame>
		</frame>
	);
}

interface ActiveReactorProps {
	boost: BoostDef;
	endsAt: number;
	now: React.Binding<number>;
	softMotion?: boolean;
	stack?: boolean;
}

function ActiveReactor(props: ActiveReactorProps) {
	const boost = props.boost;
	const endsAt = props.endsAt;
	const now = props.now;
	const softMotion = props.softMotion;
	const stack = props.stack;
	const accent = boost.Color ?? Palette.pink;
	const spin = useClock(!softMotion, 40, 360, false);
	const fraction = now.map((t) => math.clamp((endsAt - t) / math.max(1, boost.Duration ?? 1), 0, 1));
	const [big, small] = headline(boost);
	const gaugeSize = stack ? 132 : 150;
	const phone = stack === true;
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={accent} glow={accent} reducedMotion={softMotion} name="BoostRunning">
			<PanelHeading icon="Boost" title="Running" note={now.map((t) => `${clockText(math.max(0, endsAt - t))} left`)} accent={accent} phone={phone} layoutOrder={0} />
			<frame BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, gaugeSize)} LayoutOrder={1}>
				<Gauge fraction={fraction} accent={accent} size={gaugeSize} spin={spin}>
					<Text
						value={big}
						size={math.floor(gaugeSize * 0.22)}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						position={new UDim2(0, 0, 0.5, -math.floor(gaugeSize * 0.17))}
						sizeConstraint={new UDim2(1, 0, 0, math.floor(gaugeSize * 0.24))}
					/>
					<Text
						value={now.map((t) => clockText(math.max(0, endsAt - t)))}
						size={12}
						color={accent}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						position={new UDim2(0, 0, 0.5, math.floor(gaugeSize * 0.08))}
						sizeConstraint={new UDim2(1, 0, 0, 16)}
					/>
				</Gauge>
				<frame BackgroundTransparency={1} BorderSizePixel={0} Position={UDim2.fromOffset(gaugeSize + 18, 0)} Size={new UDim2(1, -(gaugeSize + 18), 1, 0)}>
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<textlabel BackgroundTransparency={1} Text={boost.Name} TextSize={phone ? 20 : 26} FontFace={TITLE_FACE} TextColor3={Palette.cream} TextXAlignment={Enum.TextXAlignment.Left} TextTruncate={Enum.TextTruncate.AtEnd} Size={new UDim2(1, 0, 0, phone ? 24 : 32)} LayoutOrder={0} />
					<textlabel BackgroundTransparency={1} Text={`${big} ${string.lower(small)}`} TextSize={phone ? 13 : 15} FontFace={BODY_SEMI} TextColor3={accent} TextXAlignment={Enum.TextXAlignment.Left} Size={new UDim2(1, 0, 0, 18)} LayoutOrder={1} />
					<textlabel BackgroundTransparency={1} Text={boost.Description ?? ""} TextSize={phone ? 12 : 14} FontFace={BODY} TextColor3={Palette.creamSoft} TextWrapped={true} TextXAlignment={Enum.TextXAlignment.Left} TextYAlignment={Enum.TextYAlignment.Top} Size={new UDim2(1, 0, 0, phone ? 32 : 40)} LayoutOrder={2} />
				</frame>
			</frame>
			<Bar fill={fraction} color={accent} layoutOrder={2} />
		</MockPanel>
	);
}

interface IdleBayProps {
	pick?: BoostPick;
	dispatch: Dispatch;
	softMotion?: boolean;
	stack?: boolean;
	activateHostRef?: React.MutableRefObject<Frame | undefined>;
}

// mirrors GameService.stardustBoostPrice: base x (1 + rebirths x PerRebirth), or undefined when not sold
function stardustPriceFor(config: BoostsConfig, boostId: string, rebirths: number): number | undefined {
	const rebirth = config.Economy?.Rebirth;
	const base = rebirth?.StardustBoostPrices?.[boostId];
	if (!typeIs(base, "number") || base <= 0) {
		return undefined;
	}
	const perRebirth = tonumber(rebirth?.StardustBoostPerRebirth) ?? 0;
	return math.floor(base * (1 + math.max(0, rebirths) * perRebirth));
}

function IdleBay(props: IdleBayProps) {
	const pick = props.pick;
	const softMotion = props.softMotion;
	const stack = props.stack;
	const phone = stack === true;
	if (pick === undefined) {
		return (
			<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.muted} reducedMotion={softMotion} name="BoostBay">
				<PanelHeading icon="Boost" title="Boost bay" note="Empty" accent={Palette.muted} phone={phone} layoutOrder={0} />
				<MockRow phone={phone} icon="Info" accent={Palette.muted} title="Nothing stored" sub="Win boosts from the prize wheel, daily rewards and the Shop's Daily offers." layoutOrder={1} />
			</MockPanel>
		);
	}
	const accent = pick.boost.Color ?? Palette.pink;
	const [big, small] = headline(pick.boost);
	return (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={accent} glow={accent} reducedMotion={softMotion} name="BoostBay">
			<PanelHeading icon="Boost" title="Best pick" note={`${compactNumber(pick.owned)} stored`} accent={accent} phone={phone} layoutOrder={0} />
			<MockRow
				phone={phone}
				icon={boostIconKind(pick.boost.Id)}
				accent={accent}
				title={pick.boost.Name}
				sub={`${big} ${string.lower(small)} for ${clockText(pick.boost.Duration ?? 0)}`}
				value={big}
				layoutOrder={1}
			/>
			<frame {...named("BoostClaimActions")} Size={new UDim2(1, 0, 0, phone ? TapTarget : 44)} BackgroundTransparency={1} ClipsDescendants={false} ref={props.activateHostRef} LayoutOrder={2}>
				<MockBtn text={`Fire ${pick.boost.Name}`} icon="Boost" accent={accent} phone={phone} fill={true} onClick={() => props.dispatch("ActivateBoost", { Id: pick.boost.Id })} reducedMotion={softMotion} />
			</frame>
		</MockPanel>
	);
}

interface BoostCardProps {
	boost: BoostDef;
	owned: number;
	canActivate: boolean;
	busyText: string;
	dispatch: Dispatch;
	softMotion?: boolean;
	index: number;
	focus?: boolean;
	activateHostRef?: React.MutableRefObject<Frame | undefined>;
	// Stardust price to run this boost without a stored charge (same formula as the server)
	stardustPrice?: number;
	stardust: number;
}

function BoostCard(props: BoostCardProps) {
	const boost = props.boost;
	const owned = props.owned;
	const softMotion = props.softMotion;
	const reveal = useStagger(props.index, softMotion);
	const price = props.stardustPrice;
	const buyable = owned <= 0 && price !== undefined;
	const affordable = buyable && props.stardust >= price;
	const ready = (owned > 0 || affordable) && props.canActivate;
	const accent = boost.Color ?? Palette.pink;
	const shown = owned > 0 ? accent : Palette.muted;
	const [big, small] = headline(boost);
	const label = !props.canActivate && (owned > 0 || buyable) ? props.busyText : owned > 0 ? "Activate" : buyable ? `Run · ${compactNumber(price)} dust` : "None stored";
	// 15-rewards day cell: label, glyph, figure, line, button; cells with nothing stored sit at .55
	return (
		<Rise reveal={reveal} height={CARD_H}>
			<canvasgroup Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} GroupTransparency={owned > 0 || buyable ? 0 : 0.45}>
				<frame BackgroundColor3={Palette.white} BorderSizePixel={0} Size={UDim2.fromScale(1, 1)}>
					<RowFace outline={ready && owned > 0 ? accent : undefined} />
					<uipadding PaddingTop={new UDim(0, 14)} PaddingBottom={new UDim(0, 14)} PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
					<uilistlayout FillDirection={Enum.FillDirection.Vertical} HorizontalAlignment={Enum.HorizontalAlignment.Center} VerticalAlignment={Enum.VerticalAlignment.Center} Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<textlabel BackgroundTransparency={1} Text={spaced(small)} TextSize={11} FontFace={BODY_BOLD} TextColor3={Palette.muted} TextTruncate={Enum.TextTruncate.AtEnd} Size={new UDim2(1, 0, 0, 14)} LayoutOrder={0} />
					<frame BackgroundTransparency={1} Size={UDim2.fromOffset(28, 28)} LayoutOrder={1}>
						<Glyph kind={boostIconKind(boost.Id)} size={28} color={shown} />
					</frame>
					<textlabel BackgroundTransparency={1} Text={`${big} ${boost.Name}`} TextSize={15} FontFace={BODY_BOLD} TextColor3={Palette.cream} TextTruncate={Enum.TextTruncate.AtEnd} Size={new UDim2(1, 0, 0, 18)} LayoutOrder={2} />
					<textlabel
						BackgroundTransparency={1}
						Text={`${clockText(boost.Duration ?? 0)} · ${owned > 0 ? `${compactNumber(owned)} stored` : "none stored"}`}
						TextSize={12}
						FontFace={BODY}
						TextColor3={Palette.muted}
						TextTruncate={Enum.TextTruncate.AtEnd}
						Size={new UDim2(1, 0, 0, 15)}
						LayoutOrder={3}
					/>
					<frame {...named("BoostClaimActions")} Size={new UDim2(1, 0, 0, 36)} BackgroundTransparency={1} ClipsDescendants={false} ref={ready && props.focus ? props.activateHostRef : undefined} LayoutOrder={4}>
						<MockBtn
							text={label}
							icon={ready ? "Boost" : undefined}
							accent={accent}
							sm={true}
							fill={true}
							disabled={!ready}
							onClick={() => {
								if (owned > 0) {
									props.dispatch("ActivateBoost", { Id: boost.Id });
								} else if (buyable) {
									props.dispatch("ActivateBoost", { Id: boost.Id, Buy: true });
								}
							}}
							reducedMotion={softMotion}
						/>
					</frame>
				</frame>
			</canvasgroup>
		</Rise>
	);
}

interface BoostsViewProps {
	state: BoostsState;
	config: BoostsConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

interface BoostRow {
	Id: string;
	cells: { boost: BoostDef; order: number }[];
}

function BoostsView(props: BoostsViewProps) {
	const state = props.state;
	const config = props.config;
	const dispatch = props.dispatch;
	const reducedMotion = props.reducedMotion;
	const softMotion = reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const antilag = useAntilag();
	// phones in landscape fit two boost cards side by side; one column leaves a 360px-tall
	// screen showing a single card at a time
	// wide desktop: reactor, stats and browse controls in a side column, cards in the main one
	const plan = pagePlan(viewport.width, stack);
	const gridWidth = plan.split ? plan.main : viewport.width;
	const columns = stack && !chrome.landscape ? 1 : gridWidth >= 1100 ? 3 : 2;
	const activateHostRef = React.useRef<Frame>();
	const now = useWallClock(true);
	const inventory = state.BoostInventory ?? {};
	const all: BoostDef[] = [];
	for (const [, definition] of pairs(config.Boosts ?? {})) {
		all.push(definition);
	}
	const activeId = state.ActiveBoost?.Id ?? "";
	const activeEndsAt = (state.ActiveBoost !== undefined ? tonumber(state.ActiveBoost.EndsAt) : undefined) ?? 0;
	const boostRunning = activeId !== "" && activeEndsAt > Workspace.GetServerTimeNow();
	const activeBoost = boostRunning ? (config.Boosts ?? {})[activeId] : undefined;
	let stored = 0;
	let types = 0;
	let bankedSeconds = 0;
	let bestMult = 1;
	let pick: BoostPick | undefined;
	for (const boost of all) {
		const owned = math.max(0, math.floor(tonumber(inventory[boost.Id]) ?? 0));
		stored += owned;
		if (owned > 0) {
			types += 1;
			bankedSeconds += owned * (tonumber(boost.Duration) ?? 0);
			bestMult = math.max(bestMult, tonumber(boost.Multiplier) ?? 1);
			if (pick === undefined || value(boost) > value(pick.boost)) {
				pick = { boost, owned };
			}
		}
	}
	all.sort((a, b) => {
		const ao = (tonumber(inventory[a.Id]) ?? 0) > 0;
		const bo = (tonumber(inventory[b.Id]) ?? 0) > 0;
		if (ao !== bo) {
			return ao;
		}
		if (value(a) !== value(b)) {
			return value(a) > value(b);
		}
		return a.Id < b.Id;
	});
	const browse = Browse.useBrowse<BoostDef>({
		id: "Boosts",
		items: all,
		textKey: activeId,
		text: (boost) => [boost.Name, boost.Description, ...headline(boost)],
		categories: [
			{ id: "All", label: "All" },
			{
				id: "Owned",
				label: "Owned",
				test: (boost) => (tonumber(inventory[boost.Id]) ?? 0) > 0,
			},
			{
				id: "Production",
				label: "Production",
				test: (boost) => tonumber(boost.Multiplier) !== undefined,
			},
			{
				id: "Vault",
				label: "Vault",
				test: (boost) => tonumber(boost.CapacityMultiplier) !== undefined,
			},
		],
		sorts: [
			{ id: "Recommended", label: "Owned first" },
			{
				id: "Strongest",
				label: "Strongest",
				compare: (a, b) => (tonumber(a.Multiplier) ?? tonumber(a.CapacityMultiplier) ?? 1) > (tonumber(b.Multiplier) ?? tonumber(b.CapacityMultiplier) ?? 1),
			},
			{
				id: "Longest",
				label: "Longest",
				compare: (a, b) => (tonumber(a.Duration) ?? 0) > (tonumber(b.Duration) ?? 0),
			},
			{
				id: "Name",
				label: "A to Z",
				compare: (a, b) => tostring(a.Name) < tostring(b.Name),
			},
		],
	});
	const filter = browse.category;
	const boosts = browse.results;
	const focusId = !boostRunning && pick !== undefined ? pick.boost.Id : undefined;
	React.useEffect(() => {
		if (focusId === undefined || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = activateHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const job = task.defer(() => {
			if (host.Parent !== undefined) {
				GamepadNavigationService.FocusClaim(host);
			}
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [focusId, boostRunning, filter]);
	const rebirths = math.max(0, math.floor(tonumber(state.Rebirths) ?? 0));
	const stardust = math.max(0, tonumber(state.Stardust) ?? 0);
	const busyText = activeBoost !== undefined ? `${string.upper(activeBoost.Name)} RUNNING` : "ONE AT A TIME";
	// phones in landscape use the wide hero and a single row of stat tiles: the stacked ones
	// take 318-388px, more than a 360px-tall screen has
	const heroStack = (stack && !chrome.landscape) || plan.split;
	const barStack = stack || plan.split;
	const ph = stack;
	const heroH =
		activeBoost !== undefined
			? panelHeight(ph, headingBlock(ph) + (ph ? 132 : 150) + (ph ? 8 : 12) + 10)
			: pick === undefined
				? panelHeight(ph, headingBlock(ph) + rowHeight(ph, true))
				: panelHeight(ph, headingBlock(ph) + rowHeight(ph, true) + (ph ? 8 : 12) + (ph ? TapTarget : 44));
	// split layout puts Stock in the narrow side column: one tile per row so values never run into a neighbour
	const statCols = plan.split ? 1 : 2;
	const statRows = 4 / statCols;
	const statsH = panelHeight(ph, headingBlock(ph) + rowHeight(ph) * statRows + (ph ? 8 : 12) * (statRows - 1));
	const rowStride = CARD_H + GAP;
	const rows: BoostRow[] = [];
	let index = 1;
	while (index <= boosts.size()) {
		const row: BoostRow = { Id: `boost-row-${filter}-${index}`, cells: [] };
		for (let cell = 0; cell < columns; cell++) {
			const boost = boosts[index - 1];
			if (boost === undefined) {
				break;
			}
			row.cells.push({ boost, order: index - 1 });
			index += 1;
		}
		rows.push(row);
	}
	const gridH = math.max(rowStride, rows.size() * rowStride);
	const statTiles = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={ph} accent={Palette.pink} reducedMotion={softMotion} name="BoostStock">
			<PanelHeading icon="Vault" title="Stock" accent={Palette.pink} phone={ph} layoutOrder={0} />
			<Grid columns={statCols} gap={ph ? 8 : 12} cellHeight={rowHeight(ph)} count={4} layoutOrder={1}>
				<MockRow phone={ph} icon="Boost" accent={Palette.pink} title="Stored" value={compactNumber(stored)} layoutOrder={1} />
				<MockRow phone={ph} icon="StarGrid" accent={Palette.cyan} title="Types" value={`${types} / ${all.size()}`} layoutOrder={2} />
				<MockRow phone={ph} icon="Timer" accent={Palette.mango} title="Banked" value={`${compactNumber(math.floor(bankedSeconds / 3600))}h`} layoutOrder={3} />
				<MockRow phone={ph} icon="Production" accent={Palette.mint} title="Best" value={`${bestMult}x`} layoutOrder={4} />
			</Grid>
		</MockPanel>
	);
	const grid =
		boosts.size() === 0 ? (
			<Browse.NoResults
				browse={browse}
				noun="boosts"
				icon="Boost.16"
				filteredTitle={filter === "Owned" ? "Nothing stored" : undefined}
				filteredBody={filter === "Owned" ? "Win boosts from the prize wheel and daily rewards." : undefined}
				accent={Palette.cyan}
				reducedMotion={softMotion}
				size={new UDim2(1, 0, 0, 220)}
			/>
		) : (
			<FlatList
				data={rows}
				itemHeight={rowStride}
				overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
				canvasTail={8}
				embedded={true}
				Size={new UDim2(1, 0, 0, gridH)}
				scrollBarColor={Palette.pink}
				scrollBarThickness={3}
				keyExtractor={(row: BoostRow) => row.Id}
				renderItem={(item: { item: BoostRow }) => {
					const row = item.item;
					return (
						<frame Size={new UDim2(1, 0, 0, CARD_H)} BackgroundTransparency={1}>
							<uigridlayout
								CellSize={new UDim2(1 / columns, -math.ceil((GAP * (columns - 1)) / columns), 0, CARD_H)}
								CellPadding={UDim2.fromOffset(GAP, GAP)}
								SortOrder={Enum.SortOrder.LayoutOrder}
							/>
							{row.cells.map((cell, cellIndex) => (
								<frame key={cell.boost.Id} BackgroundTransparency={1} LayoutOrder={cellIndex}>
									<BoostCard
										boost={cell.boost}
										owned={math.max(0, math.floor(tonumber(inventory[cell.boost.Id]) ?? 0))}
										canActivate={!boostRunning}
										busyText={busyText}
										stardustPrice={stardustPriceFor(config, cell.boost.Id, rebirths)}
										stardust={stardust}
										dispatch={dispatch}
										softMotion={softMotion}
										index={cell.order}
										focus={false}
										activateHostRef={activateHostRef}
									/>
								</frame>
							))}
						</frame>
					);
				}}
			/>
		);
	return (
		<PageScaffold
			gap={stack ? 8 : 18}
			tailPad={scrollTail(stack, chrome.bottomSafe, stack ? 56 : 48)}
			scrollBarColor={Palette.pink}
			scrollBarThickness={4}
			sections={splitSections(
				plan,
				[
					{
						id: "hero",
						height: heroH,
						element:
							activeBoost !== undefined ? (
								<ActiveReactor boost={activeBoost} endsAt={activeEndsAt} now={now} softMotion={softMotion} stack={heroStack} />
							) : (
								<IdleBay
									pick={pick}
									dispatch={dispatch}
									softMotion={softMotion}
									stack={heroStack}
									activateHostRef={activateHostRef}
								/>
							),
					},
					{
						id: "stats",
						height: statsH,
						element: statTiles,
					},
					{
						id: "filters",
						height: Browse.barHeight(barStack, true),
						element: (
							<Browse.BrowseBar
								browse={browse}
								placeholder="Search boosts"
								accent={Palette.pink}
								stack={barStack}
								reducedMotion={softMotion}
								zIndex={30}
							/>
						),
					},
					{
						id: "grid",
						height: boosts.size() === 0 ? 220 : gridH,
						element: grid,
					},
				] as Array<Section & { height: number }>,
				"Boosts",
			)}
		/>
	);
}

export = { BoostsView };
