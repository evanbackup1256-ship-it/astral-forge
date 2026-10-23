import React from "@rbxts/react";
import { clockText, compactNumber, Flux } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { chromeFor, darken, Layout, lighten, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useClock, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { SplitColumns, SplitPlan, StackBlocks, splitColumns, stackHeight } from "../../UiCore/ui";
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
const { Badge, Button, IconTile, Panel, Text } = loadUi();
const { Icon } = luauKit<{ Icon: Component }>("ArtKit", "Icon");
const PageScaffold = loadPageScaffold();
const { FlatList } = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList");
const Browse = loadBrowse();

const GAP = 10;
const TICKS = 36;
const CARD_H = 196;

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
		return [`${production}x`, `production, ${vault}x vault`];
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
	return (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={accent}
			background={Palette.panelRaised}
			padding={16}
			highlight={true}
			reducedMotion={softMotion}
			clips={false}
		>
			<Gauge
				fraction={fraction}
				accent={accent}
				size={gaugeSize}
				spin={spin}
				position={stack ? new UDim2(0.5, 0, 0, 0) : UDim2.fromOffset(0, 0)}
				anchorPoint={stack ? new Vector2(0.5, 0) : undefined}
			>
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
			<frame
				Size={stack ? new UDim2(1, 0, 0, 96) : new UDim2(1, -(gaugeSize + 20), 1, 0)}
				Position={stack ? UDim2.fromOffset(0, gaugeSize + 10) : UDim2.fromOffset(gaugeSize + 20, 0)}
				BackgroundTransparency={1}
			>
				<Badge value="RUNNING" accent={accent} filled={true} size={UDim2.fromOffset(96, 22)} />
				<Text
					value={boost.Name}
					size={stack ? 22 : 26}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={14}
					position={UDim2.fromOffset(0, 28)}
					sizeConstraint={new UDim2(1, 0, 0, 30)}
				/>
				<Text
					value={`${big} ${string.lower(small)}: ${boost.Description}`}
					size={12}
					color={Palette.creamSoft}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(0, 60)}
					sizeConstraint={new UDim2(1, 0, 0, 34)}
				/>
				{!stack && (
					<frame
						Size={new UDim2(1, 0, 0, 8)}
						Position={new UDim2(0, 0, 1, -14)}
						BackgroundColor3={Palette.ink}
						BorderSizePixel={0}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<frame
							Size={fraction.map((f) => UDim2.fromScale(f, 1))}
							BackgroundColor3={accent}
							BorderSizePixel={0}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</frame>
					</frame>
				)}
			</frame>
		</Panel>
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
	if (pick === undefined) {
		return (
			<Panel
				size={UDim2.fromScale(1, 1)}
				accent={Palette.muted}
				background={Palette.panelRaised}
				padding={16}
				clips={false}
			>
				<IconTile kind="Boost" accent={Palette.muted} size={48} radius={14} spin={false} />
				<Text
					value="The boost bay is empty"
					size={18}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					position={UDim2.fromOffset(62, 4)}
					sizeConstraint={new UDim2(1, -62, 0, 24)}
				/>
				<Text
					value="Win boosts from the prize wheel, daily rewards and the Shop's Daily offers."
					size={12}
					color={Palette.muted}
					wrap={true}
					fit={true}
					minSize={10}
					position={UDim2.fromOffset(62, 32)}
					sizeConstraint={new UDim2(1, -62, 0, 34)}
				/>
			</Panel>
		);
	}
	const accent = pick.boost.Color ?? Palette.pink;
	const [big, small] = headline(pick.boost);
	return (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={accent}
			background={Palette.panelRaised}
			padding={16}
			highlight={true}
			reducedMotion={softMotion}
			clips={false}
		>
			<Text value="Best pick" size={13} color={accent} weight={Enum.FontWeight.SemiBold} sizeConstraint={new UDim2(1, 0, 0, 14)} />
			<IconTile
				kind={boostIconKind(pick.boost.Id)}
				accent={accent}
				size={stack ? 52 : 64}
				radius={14}
				glow={true}
				position={UDim2.fromOffset(0, 22)}
				reducedMotion={softMotion}
			/>
			<Text
				value={pick.boost.Name}
				size={stack ? 18 : 22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={12}
				position={UDim2.fromOffset(stack ? 64 : 78, 24)}
				sizeConstraint={new UDim2(1, stack ? -64 : -(78 + 220), 0, 28)}
			/>
			<Text
				value={`${big} ${string.lower(small)} for ${clockText(pick.boost.Duration ?? 0)}, ${compactNumber(pick.owned)} stored`}
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(stack ? 64 : 78, 54)}
				sizeConstraint={new UDim2(1, stack ? -64 : -(78 + 220), 0, 32)}
			/>
			<frame
				{...named("BoostClaimActions")}
				Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(200, TapTarget)}
				Position={stack ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(1, -200, 0.5, -TapTarget / 2 + 8)}
				BackgroundTransparency={1}
				ClipsDescendants={false}
				ref={props.activateHostRef}
			>
				<Button
					text={`FIRE ${string.upper(pick.boost.Name)}`}
					icon="Boost.14"
					onClick={() => {
						props.dispatch("ActivateBoost", { Id: pick.boost.Id });
					}}
					color={accent}
					textColor={Palette.ink}
					size={UDim2.fromScale(1, 1)}
					highlight={true}
					reducedMotion={softMotion}
				/>
			</frame>
		</Panel>
	);
}

interface StatTileProps {
	label: string;
	value: string;
	accent: Color3;
	order: number;
}

function StatTile(props: StatTileProps) {
	return (
		<frame BackgroundColor3={darken(props.accent, 0.78)} BorderSizePixel={0} LayoutOrder={props.order}>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={props.accent} Transparency={0.6} />
			<Text
				value={props.value}
				size={18}
				color={lighten(props.accent, 0.12)}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(12, 8)}
				sizeConstraint={new UDim2(1, -24, 0, 24)}
			/>
			<Text
				value={props.label}
				size={10}
				color={props.accent}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(12, 34)}
				sizeConstraint={new UDim2(1, -24, 0, 14)}
			/>
		</frame>
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
	return (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={shown}
			background={Palette.panelRaised}
			padding={0}
			reveal={reveal}
			interactive={true}
			highlight={ready}
			reducedMotion={softMotion}
			clips={false}
		>
			<frame
				{...named("Band")}
				Size={new UDim2(1, 0, 0, 58)}
				BackgroundColor3={darken(shown, owned > 0 ? 0.45 : 0.75)}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, Layout.cardRadius ?? 14)} />
				<uigradient Color={new ColorSequence(darken(shown, 0.3), darken(shown, 0.75))} Rotation={20} />
				<Icon
					kind={boostIconKind(boost.Id)}
					color={Palette.cream}
					accent={shown}
					size={30}
					position={UDim2.fromOffset(14, 14)}
					spin={false}
				/>
				<Text
					value={big}
					size={26}
					color={Palette.cream}
					weight={Enum.FontWeight.Heavy}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(0, 0, 0, 6)}
					sizeConstraint={new UDim2(1, -14, 0, 30)}
				/>
				<Text
					value={small}
					size={10}
					color={Palette.creamSoft}
					weight={Enum.FontWeight.Heavy}
					align={Enum.TextXAlignment.Right}
					fit={true}
					minSize={8}
					position={new UDim2(0, 56, 0, 36)}
					sizeConstraint={new UDim2(1, -70, 0, 14)}
				/>
			</frame>
			<Text
				value={boost.Name}
				size={16}
				color={owned > 0 ? Palette.cream : Palette.creamSoft}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(14, 66)}
				sizeConstraint={new UDim2(1, -110, 0, 20)}
			/>
			<Badge
				value={owned > 0 ? `×${compactNumber(owned)}` : "NONE"}
				accent={owned > 0 ? accent : Palette.lineSoft}
				filled={owned > 0}
				size={UDim2.fromOffset(84, 20)}
				position={new UDim2(1, -98, 0, 66)}
			/>
			<Text
				value={boost.Description}
				size={11}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(14, 90)}
				sizeConstraint={new UDim2(1, -28, 0, 30)}
			/>
			<Text
				value={`Lasts ${clockText(boost.Duration ?? 0)}`}
				size={11}
				color={shown}
				weight={Enum.FontWeight.Bold}
				position={UDim2.fromOffset(14, 120)}
				sizeConstraint={new UDim2(1, -28, 0, 16)}
			/>
			<frame
				{...named("BoostClaimActions")}
				Size={new UDim2(1, -28, 0, TapTarget)}
				Position={new UDim2(0, 14, 1, -(TapTarget + 12))}
				BackgroundTransparency={1}
				ClipsDescendants={false}
				ref={ready && props.focus ? props.activateHostRef : undefined}
			>
				<Button
					text={
						!props.canActivate && (owned > 0 || buyable)
							? props.busyText
							: owned > 0
								? "ACTIVATE"
								: buyable
									? `RUN (${compactNumber(price)} STARDUST)`
									: "NONE STORED"
					}
					icon={ready ? "Boost.15" : "Lock.5"}
					onClick={() => {
						if (owned > 0) {
							props.dispatch("ActivateBoost", { Id: boost.Id });
						} else if (buyable) {
							props.dispatch("ActivateBoost", { Id: boost.Id, Buy: true });
						}
					}}
					color={ready ? accent : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.muted}
					size={UDim2.fromScale(1, 1)}
					disabled={!ready}
					highlight={ready}
					reducedMotion={softMotion}
				/>
			</frame>
		</Panel>
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
	const heroH = activeBoost !== undefined ? (heroStack ? 260 : 182) : heroStack ? 190 : 132;
	const statsH = heroStack ? 128 : 60;
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
		<>
			<uigridlayout
				CellSize={new UDim2(heroStack ? 0.5 : 0.25, -8, 0, 56)}
				CellPadding={UDim2.fromOffset(8, 8)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			<StatTile label="Stored" value={compactNumber(stored)} accent={Palette.pink} order={1} />
			<StatTile label="Types owned" value={`${types} / ${all.size()}`} accent={Palette.cyan} order={2} />
			<StatTile label="Time banked" value={`${compactNumber(math.floor(bankedSeconds / 3600))}h`} accent={Palette.mango} order={3} />
			<StatTile label="Best multiplier" value={`${bestMult}x`} accent={Palette.mint} order={4} />
		</>
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
			gap={stack ? 12 : Layout.panelGap}
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
						element: (
							<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
								{statTiles}
							</frame>
						),
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
