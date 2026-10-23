import React from "@rbxts/react";
import { useAntilag } from "../../MotionKit/antilag";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { useFlash, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { chromeFor, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { Component, loadBrowse, loadPageScaffold, loadUi, luauKit, named } from "../luauDeps";
import { SplitColumns, splitColumns, StackBlocks, stackHeight } from "../../UiCore/ui";

const UserInputService = game.GetService("UserInputService");
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;
const ui = loadUi();
const { Badge, Button, EmptyState, IconTile, Meter, Panel, SectionLabel, Text } = ui;
const meterFill = (ui as unknown as { meterFill: (this: void, progress: number, target: number, done: boolean) => number })
	.meterFill;

const ORDER_HEIGHT = 168;
const ORDER_HEIGHT_STACK = 224;
const ORDER_GAP = Layout.panelGap;
const CHANNEL_IDS = ["Production", "Storage", "Tap"];
const SCROLL_PAD = 36 + 16;
const SECTION_LABEL_H = 28;
const BTN_W = 176;
const SCROLL_BAR = 4;
const ROW_RIGHT = SCROLL_BAR + 10;

type Dispatch = (action: string, payload: object, callback?: (response: { ok?: boolean }) => void) => unknown;

interface OrderState {
	Id: string;
	Claimed?: boolean;
	Progress: number;
	Target: number;
}
interface OrderConfig {
	Id: string;
	Name: string;
	Description?: string;
	Color: Color3;
	Reward: Reward;
}
interface ChannelConfig {
	Name: string;
	Description: string;
	Color: Color3;
}
interface LabState {
	ResetAt: number;
	Orders: OrderState[];
	AvailableCells: number;
	TotalCells: number;
	Routing: Record<string, number | undefined>;
	Effects: Record<string, number | undefined>;
}
interface LabConfig {
	Lab: { Orders: OrderConfig[]; Power: { Channels: Record<string, ChannelConfig | undefined> } };
	ClientPageGuides?: { Lab?: { EmptyOrders?: string } };
}
interface LabProps {
	state: { Lab?: LabState };
	config: LabConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

function OrderRow(props: {
	state: OrderState;
	config: OrderConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	order: number;
	stack: boolean;
}) {
	const { state, config, dispatch, order, stack } = props;
	const ready = !state.Claimed && state.Progress >= state.Target;
	const fill = meterFill(state.Progress, state.Target, state.Claimed || ready);
	const reducedMotion = props.reducedMotion;
	const reveal = useStagger(order, reducedMotion);
	const [claimTrigger, setClaimTrigger] = React.useState(0);
	const claimFlash = useFlash(claimTrigger, reducedMotion, 0.4);
	// one claim in flight per order: the button spins until the server answers, a refusal shakes it
	const [claiming, setClaiming] = React.useState(false);
	const [refused, setRefused] = React.useState(0);
	const fireClaim = () => {
		if (!ready || claiming) {
			return undefined;
		}
		setClaimTrigger((value) => value + 1);
		setClaiming(true);
		const fallback = task.delay(8, () => setClaiming(false));
		return dispatch("ClaimLabOrder", { Id: state.Id }, (response) => {
			pcall(task.cancel, fallback);
			setClaiming(false);
			if (response.ok !== true) {
				setRefused((value) => value + 1);
			}
		});
	};
	const rowH = stack ? ORDER_HEIGHT_STACK : ORDER_HEIGHT;
	const pad = stack ? 14 : Layout.cardPadding;
	const contentH = rowH - pad * 2;
	const btnReserve = stack ? TapTarget + 14 : 0;
	const meterY = stack ? contentH - btnReserve - 8 : 118;
	const progressY = meterY - 18;
	const meterSize = stack ? new UDim2(1, 0, 0, 8) : new UDim2(1, -(BTN_W + ROW_RIGHT + 12), 0, 8);
	const textW = stack ? -(58 + 12) : -(BTN_W + 74 + ROW_RIGHT);
	return (
		<Panel
			size={new UDim2(1, 0, 0, rowH)}
			accent={config.Color}
			background={Palette.panelRaised}
			padding={pad}
			layoutOrder={order}
			reveal={reveal}
			interactive={true}
			highlight={ready}
			reducedMotion={reducedMotion}
		>
			<frame Size={UDim2.fromOffset(46, 46)} Position={UDim2.fromOffset(0, stack ? 4 : 10)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uiscale Scale={claimFlash.map((amount) => 1 + amount * 0.18)} />
				<IconTile kind="Mission" accent={config.Color} size={46} radius={14} glow={ready} reducedMotion={reducedMotion} />
			</frame>
			<Text
				value={config.Name}
				size={17}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(58, 2)}
				sizeConstraint={new UDim2(1, textW, 0, 24)}
			/>
			<Text
				value={config.Description}
				size={stack ? 12 : 11}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(58, 28)}
				sizeConstraint={new UDim2(1, textW, 0, stack ? 36 : 28)}
			/>
			<Text
				value={formatReward(config.Reward)}
				size={11}
				color={config.Color}
				weight={Enum.FontWeight.Bold}
				fit={false}
				position={UDim2.fromOffset(58, stack ? 68 : 60)}
				sizeConstraint={new UDim2(1, textW, 0, 16)}
			/>
			<Text
				value={`${compactNumber(state.Progress)} / ${compactNumber(state.Target)}`}
				size={11}
				color={Palette.creamSoft}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, progressY)}
				sizeConstraint={UDim2.fromOffset(180, 16)}
			/>
			<Meter
				value={fill}
				color={config.Color}
				position={UDim2.fromOffset(0, meterY)}
				size={meterSize}
				reducedMotion={reducedMotion}
				shimmer={ready || state.Claimed}
			/>
			{stack ? (
				<Button
					text={state.Claimed ? "COLLECTED" : ready ? "COLLECT" : "NOT YET"}
					icon="Gift.5"
					onClick={fireClaim}
					loading={claiming}
					shakeToken={refused}
					color={ready ? config.Color : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.creamSoft}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={new UDim2(0, 0, 1, -(TapTarget + 6))}
					disabled={!ready}
					reducedMotion={reducedMotion}
					highlight={ready}
				/>
			) : (
				<Button
					text={state.Claimed ? "COLLECTED" : ready ? "COLLECT" : "NOT YET"}
					icon="Gift.6"
					onClick={fireClaim}
					loading={claiming}
					shakeToken={refused}
					color={ready ? config.Color : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.creamSoft}
					size={UDim2.fromOffset(BTN_W, 48)}
					position={new UDim2(1, -(BTN_W + ROW_RIGHT), 0.5, -24)}
					disabled={!ready}
					reducedMotion={reducedMotion}
					highlight={ready}
				/>
			)}
		</Panel>
	);
}

const POWER_ROW_H = 76;
const POWER_ROW_H_STACK = 96;
const POWER_ROW_STRIDE = 82;
const POWER_ROW_STRIDE_STACK = 104;
const POWER_ROW_START = 48;
const POWER_BTN = 44;

function PowerRow(props: {
	id: string;
	config: ChannelConfig;
	value: number;
	effect: number;
	available: number;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	y: number;
	stack: boolean;
}) {
	const { id, config, value, effect, available, dispatch, reducedMotion, y, stack } = props;
	const rowH = stack ? POWER_ROW_H_STACK : POWER_ROW_H;
	const badgeX = POWER_BTN + 94 + ROW_RIGHT;
	const minusX = POWER_BTN * 2 + 100 + 8 + ROW_RIGHT;
	const route = (delta: number) => () => dispatch("RouteLabPower", { Channel: id, Delta: delta });
	return (
		<frame
			Size={new UDim2(1, 0, 0, rowH)}
			Position={UDim2.fromOffset(0, y)}
			BackgroundColor3={Palette.ink}
			BackgroundTransparency={0.25}
			BorderSizePixel={0}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={config.Color} Thickness={1} Transparency={0.68} />
			<IconTile
				kind={id === "Production" ? "Forge" : id === "Storage" ? "Vault" : "Command"}
				accent={config.Color}
				size={38}
				radius={10}
				position={UDim2.fromOffset(10, stack ? 10 : 15)}
				reducedMotion={reducedMotion}
			/>
			<Text
				value={config.Name}
				size={14}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(58, stack ? 8 : 10)}
				sizeConstraint={new UDim2(1, stack ? -(58 + 20) : -(minusX + 12), 0, 21)}
			/>
			<Text
				value={`${config.Description}  /  +${math.floor(effect * 100)}% active`}
				size={11}
				color={config.Color}
				weight={Enum.FontWeight.Bold}
				wrap={true}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(58, stack ? 32 : 34)}
				sizeConstraint={new UDim2(1, stack ? -(58 + 20) : -(minusX + 12), 0, stack ? 28 : 17)}
			/>
			{stack ? (
				<frame
					Size={new UDim2(1, -(20 + ROW_RIGHT), 0, POWER_BTN)}
					Position={new UDim2(0, 10, 1, -(POWER_BTN + 8))}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					<uilistlayout
						FillDirection={Enum.FillDirection.Horizontal}
						HorizontalAlignment={Enum.HorizontalAlignment.Right}
						VerticalAlignment={Enum.VerticalAlignment.Center}
						Padding={new UDim(0, 8)}
					/>
					<Button
						text="−"
						onClick={route(-1)}
						color={Palette.panelSoft}
						textColor={value > 0 ? Palette.cream : Palette.muted}
						outline={true}
						size={UDim2.fromOffset(POWER_BTN, POWER_BTN)}
						disabled={value <= 0}
						reducedMotion={reducedMotion}
					/>
					<Badge value={`${value} CELLS`} accent={config.Color} filled={true} size={UDim2.fromOffset(86, 28)} />
					<Button
						text="+"
						onClick={route(1)}
						color={config.Color}
						textColor={Palette.ink}
						size={UDim2.fromOffset(POWER_BTN, POWER_BTN)}
						disabled={available <= 0}
						reducedMotion={reducedMotion}
					/>
				</frame>
			) : (
				<>
					<Button
						text="−"
						onClick={route(-1)}
						color={Palette.panelSoft}
						textColor={value > 0 ? Palette.cream : Palette.muted}
						outline={true}
						size={UDim2.fromOffset(POWER_BTN, POWER_BTN)}
						position={new UDim2(1, -minusX, 0.5, -POWER_BTN / 2)}
						disabled={value <= 0}
						reducedMotion={reducedMotion}
					/>
					<Badge
						value={`${value} CELLS`}
						accent={config.Color}
						filled={true}
						position={new UDim2(1, -badgeX, 0.5, -14)}
						size={UDim2.fromOffset(86, 28)}
					/>
					<Button
						text="+"
						onClick={route(1)}
						color={config.Color}
						textColor={Palette.ink}
						size={UDim2.fromOffset(POWER_BTN, POWER_BTN)}
						position={new UDim2(1, -(ROW_RIGHT + POWER_BTN), 0.5, -POWER_BTN / 2)}
						disabled={available <= 0}
						reducedMotion={reducedMotion}
					/>
				</>
			)}
		</frame>
	);
}

function orderReady(o: OrderState) {
	return !o.Claimed && (tonumber(o.Target) ?? 0) > 0 && (tonumber(o.Progress) ?? 0) >= (tonumber(o.Target) ?? 0);
}

function LabViewReady(props: LabProps) {
	const { config, dispatch, reducedMotion } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	// phones in landscape have the width for side-by-side rows (button on the right); the
	// stacked row with its button underneath fills too much of a 360px-tall screen
	const rowStack = stack && !chrome.landscape;
	// desktop: orders on the left, the power board beside them (its rows use the compact layout)
	const plan = splitColumns(stack ? 0 : viewport.width, math.floor(viewport.width * 0.4), ORDER_GAP + 4);
	const wide = plan.split;
	const stackPower = stack || wide;
	const powerStart = POWER_ROW_START + (wide ? 34 : 0);
	const lab = props.state.Lab!;
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const now = useWallClock(true);
	const headerReveal = useStagger(0, softMotion);
	const ordersReveal = useStagger(1, softMotion);
	const claimReveal = useStagger(2, softMotion);
	const boardReveal = useStagger(3, softMotion);
	const labSoft = reducedMotion || ordersReveal === undefined || claimReveal === undefined || boardReveal === undefined;
	const labClaimHostRef = React.useRef<Frame>();
	const resetText = now.map((timestamp) => `New orders in ${clockText(lab.ResetAt - timestamp)}`);
	const orderConfigs: Record<string, OrderConfig | undefined> = {};
	for (const entry of config.Lab.Orders) {
		orderConfigs[entry.Id] = entry;
	}
	let readyOrders = 0;
	for (const order of lab.Orders) {
		if (!order.Claimed && order.Progress >= order.Target) {
			readyOrders += 1;
		}
	}
	// a second tap before the snapshot lands would resend every claim
	const claimAllAt = React.useRef(-math.huge);
	const claimAllOrders = () => {
		if (os.clock() - claimAllAt.current < 1.5) {
			return;
		}
		claimAllAt.current = os.clock();
		for (const order of lab.Orders) {
			if (!order.Claimed && order.Progress >= order.Target) {
				dispatch("ClaimLabOrder", { Id: order.Id });
			}
		}
	};
	React.useEffect(() => {
		if (readyOrders <= 0 || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = labClaimHostRef.current;
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
	}, [readyOrders]);
	const guide = config.ClientPageGuides !== undefined ? config.ClientPageGuides.Lab : undefined;
	const orderH = rowStack ? ORDER_HEIGHT_STACK : ORDER_HEIGHT;
	let orderBlock =
		lab.Orders.size() > 0 ? lab.Orders.size() * orderH + math.max(0, lab.Orders.size() - 1) * ORDER_GAP : 160;
	const powerStride = stackPower ? POWER_ROW_STRIDE_STACK : POWER_ROW_STRIDE;
	const powerBoardH = powerStart + CHANNEL_IDS.size() * powerStride + 10 + 28;
	const heroHeight = stack ? (chrome.landscape ? 156 : 188) : 132;
	const paidCount = lab.Orders.filter((order) => order.Claimed === true).size();
	const heroBody = stack ? (
		<>
			<Text value={resetText} size={12} color={Palette.mint} weight={Enum.FontWeight.Bold} fit={false} sizeConstraint={new UDim2(1, -8, 0, 18)} />
			<Text
				value="Clear today's jobs, then dump spare cells into output, vault, or taps."
				size={12}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 24)}
				sizeConstraint={new UDim2(1, -8, 0, chrome.landscape ? 28 : 40)}
			/>
			<frame Size={new UDim2(1, 0, 0, 28)} Position={new UDim2(0, 0, 1, -36)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, 8)} />
				<Badge value={`${paidCount} / ${lab.Orders.size()} PAID`} accent={Palette.mint} filled={true} size={UDim2.fromOffset(120, 26)} />
				<Badge value={`${lab.AvailableCells} FREE`} accent={Palette.mango} size={UDim2.fromOffset(100, 24)} />
			</frame>
		</>
	) : (
		<>
			<Text
				value="WORKSHOP LAB"
				size={10}
				color={Palette.mint}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(68, 0)}
				sizeConstraint={new UDim2(1, -(270 + ROW_RIGHT), 0, 16)}
			/>
			<Text
				value={`${lab.AvailableCells} power cell${lab.AvailableCells === 1 ? "" : "s"} free`}
				size={22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(68, 16)}
				sizeConstraint={new UDim2(1, -(270 + ROW_RIGHT), 0, 30)}
			/>
			<Text
				value="Clear today's jobs, then dump spare cells into output, vault, or taps."
				size={10}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(68, 46)}
				sizeConstraint={new UDim2(1, -(270 + ROW_RIGHT), 0, 26)}
			/>
			<Text
				value={resetText}
				size={11}
				color={Palette.mint}
				weight={Enum.FontWeight.Bold}
				fit={false}
				position={UDim2.fromOffset(68, 80)}
				sizeConstraint={new UDim2(1, -(270 + ROW_RIGHT), 0, 18)}
			/>
			<Badge
				value={`${paidCount} / ${lab.Orders.size()} PAID`}
				accent={Palette.mint}
				filled={true}
				position={new UDim2(1, -(156 + ROW_RIGHT), 0, 12)}
				size={UDim2.fromOffset(148, 26)}
			/>
			{/* the headline already says how many cells are free, so no separate badge for it */}
			{readyOrders > 0 && (
				<frame
					{...named("LabClaimActions")}
					Size={UDim2.fromOffset(148, 36)}
					Position={new UDim2(1, -(156 + ROW_RIGHT), 0, 46)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={labClaimHostRef}
				>
					<Button
						text={`CLAIM ALL · ${readyOrders}`}
						icon="Gift.7"
						onClick={claimAllOrders}
						color={Palette.mint}
						textColor={Palette.ink}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
						highlight={true}
					/>
				</frame>
			)}
		</>
	);
	const hero = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.mint}
			background={Palette.panelRaised}
			padding={16}
			reveal={reducedMotion ? boardReveal : headerReveal}
			highlight={!labSoft}
			reducedMotion={softMotion}
			clips={false}
		>
			{!stack && (
				<IconTile
					kind="Lab"
					accent={Palette.mint}
					size={52}
					radius={14}
					position={UDim2.fromOffset(0, 10)}
					spin={false}
					glow={true}
					reducedMotion={softMotion}
				/>
			)}
			{heroBody}
		</Panel>
	);
	const Browse = loadBrowse();
	const orderBrowse = Browse.useBrowse<OrderState>({
		id: "Lab",
		items: lab.Orders ?? [],
		text: (orderState) => {
			const orderConfig = orderConfigs[orderState.Id];
			return [orderConfig ? orderConfig.Name : orderState.Id, orderConfig ? orderConfig.Description : undefined];
		},
		categories: [
			{ id: "All", label: "All" },
			{ id: "Ready", label: "Ready", test: (o) => orderReady(o) },
			{ id: "Running", label: "In progress", test: (o) => !o.Claimed && !orderReady(o) },
			{ id: "Claimed", label: "Claimed", test: (o) => o.Claimed === true },
		],
	});
	const results = orderBrowse.results;
	orderBlock = results.size() > 0 ? results.size() * orderH + math.max(0, results.size() - 1) * ORDER_GAP : 160;
	const rows = results.map((orderState, index) => {
		const orderConfig = orderConfigs[orderState.Id];
		return (
			orderConfig !== undefined && (
				<OrderRow
					key={orderState.Id}
					state={orderState}
					config={orderConfig}
					dispatch={dispatch}
					reducedMotion={softMotion}
					order={index}
					stack={rowStack}
				/>
			)
		);
	});
	const orderStride = orderH + ORDER_GAP;
	const virtOrders = results.size() >= 6;
	const ordersBlock =
		lab.Orders.size() === 0 ? (
			<EmptyState
				icon="Lab.4"
				title="No orders yet"
				body={(guide && guide.EmptyOrders) ?? "Orders refresh at the lab reset clock."}
				accent={Palette.mint}
				reducedMotion={reducedMotion}
			/>
		) : results.size() === 0 ? (
			<Browse.NoResults
				browse={orderBrowse}
				noun="orders"
				icon="Lab.5"
				accent={Palette.mint}
				reducedMotion={softMotion}
				compact={true}
				size={UDim2.fromScale(1, 1)}
			/>
		) : virtOrders ? (
			<FlatList
				data={results}
				itemHeight={orderStride}
				overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
				canvasTail={8}
				Size={UDim2.fromScale(1, 1)}
				scrollBarColor={Palette.mint}
				scrollBarThickness={SCROLL_BAR}
				keyExtractor={(orderState: OrderState) => orderState.Id}
				renderItem={({ item: orderState, index }: { item: OrderState; index: number }) => {
					const orderConfig = orderConfigs[orderState.Id];
					if (orderConfig === undefined) {
						return undefined;
					}
					return (
						<OrderRow
							state={orderState}
							config={orderConfig}
							dispatch={dispatch}
							reducedMotion={softMotion}
							order={index}
							stack={rowStack}
						/>
					);
				}}
			/>
		) : (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uilistlayout
					FillDirection={Enum.FillDirection.Vertical}
					SortOrder={Enum.SortOrder.LayoutOrder}
					Padding={new UDim(0, ORDER_GAP)}
				/>
				{rows}
			</frame>
		);
	const powerRows = CHANNEL_IDS.map((id, index) => {
		const channel = config.Lab.Power.Channels[id];
		return (
			channel !== undefined && (
				<PowerRow
					key={id}
					id={id}
					config={channel}
					value={lab.Routing[id] ?? 0}
					effect={lab.Effects[id] ?? 0}
					available={lab.AvailableCells}
					dispatch={dispatch}
					reducedMotion={reducedMotion}
					y={powerStart + index * powerStride}
					stack={stackPower}
				/>
			)
		);
	});
	const heroSection = { id: "hero", height: heroHeight, element: hero };
	const orderSections = [
		{ id: "orders-label", height: SECTION_LABEL_H, element: <SectionLabel value="Today's orders" color={Palette.mint} /> },
				{
					id: "orders-filter",
					height: lab.Orders.size() > 2 ? Browse.CHIP_H : 0,
					element:
						(lab.Orders.size() > 2 && (
							<Browse.ChipRow
								options={orderBrowse.categories}
								value={orderBrowse.category}
								onChange={orderBrowse.setCategory}
								counts={orderBrowse.counts}
								accent={Palette.mint}
							/>
						)) ||
						undefined,
				},
				// phones: a long order list is the page's fill section, so the page scroll drives it (FlatList
				// embeds itself) instead of a 4-row scroller nested inside the page scroller fighting the drag
				stack && virtOrders
					? { id: "orders", fill: true, height: orderBlock, minHeight: orderStride * 4, element: ordersBlock }
					: { id: "orders", height: virtOrders ? math.min(orderBlock, orderStride * 4) : orderBlock, element: ordersBlock },
	];
	const powerSections = [
		{ id: "power-label", height: SECTION_LABEL_H, element: <SectionLabel value="Power board" color={Palette.mango} /> },
		{
					id: "power",
					height: powerBoardH,
					element: (
						<Panel
							size={UDim2.fromScale(1, 1)}
							accent={Palette.mango}
							background={Palette.panelRaised}
							padding={stackPower ? 14 : Layout.cardPadding}
							clips={false}
						>
							<Text
								value="Move cells whenever you like."
								size={stackPower ? 16 : 17}
								color={Palette.cream}
								weight={Enum.FontWeight.Heavy}
								fit={true}
								minSize={12}
								sizeConstraint={new UDim2(1, stackPower ? -8 : -(220 + ROW_RIGHT), 0, 24)}
							/>
							<Text
								value="Bonuses apply at once. A new cell unlocks every 8 rebirths."
								size={stackPower ? 11 : 10}
								color={Palette.muted}
								wrap={true}
								fit={true}
								minSize={10}
								position={UDim2.fromOffset(0, 24)}
								sizeConstraint={new UDim2(1, stackPower ? -8 : -(220 + ROW_RIGHT), 0, stackPower ? 32 : 16)}
							/>
							{!stack && (
								<>
									<Badge
										value={`${lab.TotalCells} TOTAL`}
										accent={Palette.mango}
										filled={true}
										position={wide ? UDim2.fromOffset(0, 62) : new UDim2(1, -(196 + ROW_RIGHT), 0, 3)}
										size={UDim2.fromOffset(92, 26)}
									/>
									<Badge
										value={`${lab.AvailableCells} FREE`}
										accent={Palette.mint}
										position={wide ? UDim2.fromOffset(100, 62) : new UDim2(1, -(94 + ROW_RIGHT), 0, 3)}
										size={UDim2.fromOffset(94, 26)}
									/>
								</>
							)}
							{powerRows}
						</Panel>
					),
				},
	];
	return (
		<PageScaffold
			gap={ORDER_GAP}
			tailPad={scrollTail(stack, chrome.bottomSafe, SCROLL_PAD)}
			scrollBarColor={Palette.lineSoft}
			scrollBarThickness={SCROLL_BAR}
			sections={
				wide
					? [heroSection, {
			id: "lab-columns",
			height: math.max(stackHeight(orderSections.map((b) => b.height), ORDER_GAP + 4), stackHeight(powerSections.map((b) => b.height), ORDER_GAP + 4)),
			element: (
				<SplitColumns
					plan={plan}
					height={math.max(stackHeight(orderSections.map((b) => b.height), ORDER_GAP + 4), stackHeight(powerSections.map((b) => b.height), ORDER_GAP + 4))}
					sideOnRight={true}
					main={<StackBlocks gap={ORDER_GAP + 4} riseFrom={1} blocks={orderSections.map((b, i) => ({ ...b, rise: 0 + i }))} />}
					side={<StackBlocks gap={ORDER_GAP + 4} riseFrom={1} blocks={powerSections.map((b, i) => ({ ...b, rise: orderSections.size() + i }))} />}
				/>
			),
		}]
					: [heroSection, ...orderSections, ...powerSections]
			}
		/>
	);
}

function LabView(props: LabProps) {
	const { reducedMotion } = props;
	const viewport = useViewport();
	chromeFor(viewport);
	useAntilag();
	const softMotion = reducedMotion;
	useWallClock(true);
	useStagger(0, softMotion);
	useStagger(1, softMotion);
	useStagger(2, softMotion);
	useStagger(3, softMotion);
	React.useRef<Frame>();
	if (props.state.Lab === undefined) {
		return (
			<Panel size={new UDim2(1, 0, 0, 160)} accent={Palette.mint} background={Palette.panelRaised} padding={20}>
				<Text value="Loading the Lab..." size={15} color={Palette.creamSoft} wrap={true} />
			</Panel>
		);
	}
	return <LabViewReady {...props} />;
}

export = { LabView };
