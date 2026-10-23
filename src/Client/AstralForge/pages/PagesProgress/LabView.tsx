import React from "@rbxts/react";
import { useAntilag } from "../../MotionKit/antilag";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { useFlash, useStagger, useViewport, useWallClock } from "../../MotionKit/motion";
import { chromeFor, Layout, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { Component, loadBrowse, loadPageScaffold, loadUi, luauKit, named } from "../luauDeps";
import { SplitColumns, splitColumns, StackBlocks, stackHeight } from "../../UiCore/ui";
import { Bar, Chip, MockPanel, NUM, PanelHeading } from "../../UiCore/mockKit";
import { BigFigure, ChipRow, HEADING_SECTION_H, HeadingSection, headingBlock, MockBtn, MockRow, panelHeight, SEC, TILE_ROW_H, TileRow, Rise } from "../mockRows";

const UserInputService = game.GetService("UserInputService");
const PageScaffold = loadPageScaffold();
const FlatList = luauKit<{ FlatList: Component }>("LayoutKit", "virtualizedList").FlatList;
const ui = loadUi();
const { Button, EmptyState } = ui;
const meterFill = (ui as unknown as { meterFill: (this: void, progress: number, target: number, done: boolean) => number })
	.meterFill;

// 03-forge machine rows
const ORDER_HEIGHT = TILE_ROW_H;
const ORDER_HEIGHT_STACK = 56;
const ORDER_GAP = 10;
const CHANNEL_IDS = ["Production", "Storage", "Tap"];
const SCROLL_PAD = 36 + 16;
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
	return (
		<Rise reveal={reveal} height={stack ? ORDER_HEIGHT_STACK : ORDER_HEIGHT} layoutOrder={order}>
			<uiscale Scale={claimFlash.map((amount) => 1 + amount * 0.02)} />
			<TileRow
				phone={stack}
				icon="Mission"
				accent={config.Color}
				title={config.Name}
				meta={formatReward(config.Reward)}
				fill={fill}
				barColor={config.Color}
				value={`${compactNumber(state.Progress)} / ${compactNumber(state.Target)}`}
				valueColor={ready ? Palette.mint : Palette.creamSoft}
				outline={ready ? Palette.mint : undefined}
				rightWidth={stack ? 96 : 130}
				right={
					<Button
						text={state.Claimed ? "Collected" : ready ? "Collect" : "Not yet"}
						icon={ready ? "Gift" : undefined}
						onClick={fireClaim}
						loading={claiming}
						shakeToken={refused}
						color={ready ? Palette.mint : SEC}
						textColor={ready ? Palette.ink : Palette.cream}
						size={UDim2.fromScale(1, 1)}
						disabled={!ready}
						reducedMotion={reducedMotion}
						highlight={ready}
					/>
				}
			/>
		</Rise>
	);
}

function PowerRow(props: {
	id: string;
	config: ChannelConfig;
	value: number;
	effect: number;
	available: number;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	phone: boolean;
	layoutOrder: number;
}) {
	const { id, config, value, effect, available, dispatch, reducedMotion, phone } = props;
	const route = (delta: number) => () => dispatch("RouteLabPower", { Channel: id, Delta: delta });
	const btn = phone ? TapTarget : 36;
	return (
		<MockRow
			phone={phone}
			height={phone ? 56 : 56}
			icon={id === "Production" ? "Forge" : id === "Storage" ? "Vault" : "Command"}
			accent={config.Color}
			title={config.Name}
			sub={`${config.Description} · +${math.floor(effect * 100)}% now`}
			rightWidth={btn * 2 + 44 + 16}
			layoutOrder={props.layoutOrder}
			right={
				<>
					<frame BackgroundTransparency={1} Size={UDim2.fromOffset(btn, btn)} LayoutOrder={0}>
						<MockBtn text="-" sec={true} sm={true} phone={phone} fill={true} disabled={value <= 0} onClick={route(-1)} reducedMotion={reducedMotion} />
					</frame>
					<textlabel BackgroundTransparency={1} Text={`${value}`} TextSize={phone ? 14 : 17} FontFace={NUM} TextColor3={config.Color} Size={UDim2.fromOffset(44, btn)} LayoutOrder={1} />
					<frame BackgroundTransparency={1} Size={UDim2.fromOffset(btn, btn)} LayoutOrder={2}>
						<MockBtn text="+" accent={config.Color} sm={true} phone={phone} fill={true} disabled={available <= 0} onClick={route(1)} reducedMotion={reducedMotion} />
					</frame>
				</>
			}
		/>
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
	const plan = splitColumns(stack ? 0 : viewport.width, viewport.width >= 1600 ? 520 : 420, 18);
	const wide = plan.split;
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
	const paidCount = lab.Orders.filter((order) => order.Claimed === true).size();
	const g = stack ? 8 : 12;
	const heroHeight = panelHeight(stack, headingBlock(stack) + (stack ? 38 : 62) + g + (stack ? 24 : 28) + g + 10 + g + (stack ? TapTarget : 44));
	const powerBoardH = panelHeight(stack, headingBlock(stack) + CHANNEL_IDS.size() * (56 + g) - g);
	// 03-forge Output panel: free cells as the big figure, paid/reset chips, the paid bar, Claim all
	const hero = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={stack} accent={Palette.mint} glow={Palette.mint} reveal={reducedMotion ? boardReveal : headerReveal} reducedMotion={softMotion} name="LabSummary">
			<PanelHeading icon="Lab" title="Lab" note={resetText} accent={Palette.mint} phone={stack} layoutOrder={0} />
			<BigFigure value={`${lab.AvailableCells}`} unit={`power cell${lab.AvailableCells === 1 ? "" : "s"} free of ${lab.TotalCells}`} color={Palette.mint} phone={stack} layoutOrder={1} />
			<ChipRow height={stack ? 24 : 28} layoutOrder={2}>
				<Chip text={`${paidCount} of ${lab.Orders.size()} paid`} accent={Palette.mint} phone={stack} layoutOrder={0} />
				<Chip text="A new cell every 8 rebirths" phone={stack} layoutOrder={1} />
			</ChipRow>
			<Bar fill={lab.Orders.size() > 0 ? paidCount / lab.Orders.size() : 0} color={Palette.mint} layoutOrder={3} />
			<frame {...named("LabClaimActions")} BackgroundTransparency={1} BorderSizePixel={0} Size={new UDim2(1, 0, 0, stack ? TapTarget : 44)} LayoutOrder={4} ref={labClaimHostRef}>
				<MockBtn text={readyOrders > 0 ? `Claim all · ${readyOrders}` : "Nothing to claim"} icon={readyOrders > 0 ? "Gift" : undefined} accent={Palette.mint} phone={stack} fill={true} disabled={readyOrders <= 0} onClick={claimAllOrders} reducedMotion={softMotion} />
			</frame>
		</MockPanel>
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
					phone={stack}
					layoutOrder={1 + index}
				/>
			)
		);
	});
	const heroSection = { id: "hero", height: heroHeight, element: hero };
	const orderSections = [
		{ id: "orders-label", height: HEADING_SECTION_H, element: <HeadingSection icon="Mission" title="Today's orders" note={`${readyOrders} ready`} accent={Palette.mint} phone={stack} /> },
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
		{
			id: "power",
			height: powerBoardH,
			element: (
				<MockPanel size={UDim2.fromScale(1, 1)} phone={stack} accent={Palette.mango} reducedMotion={softMotion} name="PowerBoard">
					<PanelHeading icon="Production" title="Power cells" note={`${lab.AvailableCells} free · ${lab.TotalCells} total`} accent={Palette.mango} phone={stack} layoutOrder={0} />
					{powerRows}
				</MockPanel>
			),
		},
	];
	// desktop (03): orders in the wide column, the summary and power board in a 520px column on the right
	const sideBlocks = [heroSection, ...powerSections];
	const columnsH = math.max(stackHeight(orderSections.map((b) => b.height), 18), stackHeight(sideBlocks.map((b) => b.height), 18));
	return (
		<PageScaffold
			gap={stack ? 8 : 18}
			tailPad={scrollTail(stack, chrome.bottomSafe, SCROLL_PAD)}
			scrollBarColor={Palette.lineSoft}
			scrollBarThickness={SCROLL_BAR}
			sections={
				wide
					? [{
			id: "lab-columns",
			height: columnsH,
			element: (
				<SplitColumns
					plan={plan}
					height={columnsH}
					sideOnRight={true}
					main={<StackBlocks gap={18} riseFrom={0} blocks={orderSections.map((b, i) => ({ ...b, rise: 0 + i }))} />}
					side={<StackBlocks gap={18} riseFrom={0} blocks={sideBlocks.map((b, i) => ({ ...b, rise: orderSections.size() + i }))} />}
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
			<MockPanel size={new UDim2(1, 0, 0, 120)} phone={false} accent={Palette.mint} name="LabLoading">
				<PanelHeading icon="Lab" title="Lab" note="Loading" accent={Palette.mint} phone={false} />
			</MockPanel>
		);
	}
	return <LabViewReady {...props} />;
}

export = { LabView };
