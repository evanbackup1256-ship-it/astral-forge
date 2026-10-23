import { SplitColumns, splitColumns } from "../../UiCore/ui";
import React from "@rbxts/react";
import { BODY, BODY_SEMI, GlyphWell, Line, NUM, PnSurface, RowSurface } from "../../UiCore/mockKit";
import { IconWell } from "../gcKit";
import { counted, sameFields } from "../../UiCore/rowMemo";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { taskFilterCounts, taskMatchesFilter } from "../../CoreKit/taskFilter";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useFlash, useListStagger, usePulse, useViewport } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import Juice = require("../../JuiceFx");

const UserInputService = game.GetService("UserInputService");
const { Button, Meter, Stroke, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const Browse = clientModule<BrowseApi>("BrowseKit");

export { taskFilterCounts, taskMatchesFilter };

export interface TaskEntry {
	Id: string;
	Name: string;
	Description?: string;
	Reward?: Reward;
	Kind?: string;
	Claimed: boolean;
	Progress: number;
	Target: number;
}

type Dispatch = (action: string, payload: { Id: string }, callback?: (response: { ok?: boolean }) => void) => unknown;

export const NEAR_COMPLETE_THRESHOLD = 0.85;

interface CloseGlowProps {
	progress: number;
	ready: boolean;
	accent: Color3;
	reducedMotion?: boolean;
	position: UDim2;
	size: UDim2;
}

export function ProgressCloseGlow({ progress, ready, accent, reducedMotion, position, size }: CloseGlowProps) {
	const antilag = useAntilag();
	const near = !ready && progress >= NEAR_COMPLETE_THRESHOLD && progress < 1;
	const active = near && antilag.allowAmbient && antilag.tier >= 1 && !reducedMotion;
	const pulse = usePulse(active, 2.4);
	if (!near) {
		return undefined;
	}
	return (
		<frame Size={size} Position={position} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={4}>
			<Stroke
				color={accent}
				thickness={1.5}
				transparency={active ? pulse.map((amount) => math.clamp(0.65 - amount * 0.45, 0.18, 0.65)) : 0.5}
			/>
		</frame>
	);
}

function useReadyPop(ready: boolean, reducedMotion?: boolean) {
	const wasReady = React.useRef(ready);
	const [trigger, setTrigger] = React.useState(0);
	React.useEffect(() => {
		if (ready && !wasReady.current) {
			setTrigger((current) => current + 1);
		}
		wasReady.current = ready;
	}, [ready]);
	return useFlash(trigger, reducedMotion, 0.6);
}

export const TASK_FILTERS = [
	{ id: "All", label: "Everything", short: "All" },
	{ id: "Ready", label: "Ready to claim", short: "Ready" },
	{ id: "Active", label: "Still in progress", short: "In progress" },
	{ id: "Done", label: "Already claimed", short: "Claimed" },
];

interface MissionRowProps {
	quest: TaskEntry;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	position: UDim2;
	stack: boolean;
}

// rows slide up and settle one after another the first time the list shows them
function RowArrive(props: { index: number; reducedMotion?: boolean; children?: React.ReactNode }) {
	const arrive = useListStagger(props.index, props.reducedMotion);
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			Position={arrive.map((t) => UDim2.fromOffset(0, math.round((1 - math.clamp(t, 0, 1)) * 14)))}
			BackgroundTransparency={1}
			BorderSizePixel={0}
		>
			{props.children}
		</frame>
	);
}

// one place for the row height so the list stride can't drift from the row again
// design/16-season "This week" row: .row with icon well, .tt (name, thin bar), .v progress, Claim
function missionRowH(stack: boolean): number {
	return stack ? 64 : 76;
}

function MissionRowImpl({ quest, dispatch, reducedMotion, position, stack }: MissionRowProps) {
	return <TaskRow quest={quest} icon="Mission" onClaim={() => dispatch("ClaimQuest", { Id: quest.Id })} reducedMotion={reducedMotion} position={position} stack={stack} />;
}

/** The Missions / Milestones row (design/16-season "This week" .row with a thin bar). */
export function TaskRow({
	quest,
	icon,
	onClaim,
	reducedMotion,
	position,
	stack,
	claimHostRef,
}: {
	quest: TaskEntry;
	icon: string;
	onClaim: () => void;
	reducedMotion?: boolean;
	position: UDim2;
	stack: boolean;
	claimHostRef?: React.Ref<Frame>;
}) {
	const softMotion = reducedMotion;
	const ready = !quest.Claimed && quest.Progress >= quest.Target;
	const reward = formatReward(quest.Reward);
	const accent = quest.Claimed ? Palette.muted : ready ? Palette.mint : Palette.mango;
	const rowH = missionRowH(stack);
	const progressFrac = math.clamp(quest.Progress / math.max(1, quest.Target), 0, 1);
	const readyPop = useReadyPop(ready, softMotion);
	const iconScale = readyPop.map((amount) => 1 + amount * 0.22);
	const claim = onClaim;
	const valueText = quest.Claimed ? "Done" : `${compactNumber(quest.Progress)} / ${compactNumber(quest.Target)}`;
	const btnW = stack ? 92 : 120;
	const valueW = stack ? 84 : 120;
	const left = stack ? 42 : 48;
	const meterSize = new UDim2(1, -(left + valueW + btnW + 24), 0, 6);
	const meterPosition = new UDim2(0, left, 0, stack ? 40 : 50);
	return (
		<frame Size={new UDim2(1, 0, 0, rowH)} Position={position} BackgroundColor3={Palette.white} BorderSizePixel={0}>
			<RowSurface />
			{quest.Claimed && <uigradient Transparency={new NumberSequence(0.55)} />}
			{ready && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<uistroke Color={Palette.mint} Thickness={2} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				</frame>
			)}
			<uipadding PaddingLeft={new UDim(0, stack ? 10 : 12)} PaddingRight={new UDim(0, stack ? 10 : 12)} />
			<frame Size={UDim2.fromOffset(stack ? 30 : 36, stack ? 30 : 36)} Position={new UDim2(0, 0, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uiscale Scale={iconScale} />
				<IconWell icon={quest.Claimed ? "Check" : icon} accent={accent} size={stack ? 30 : 36} />
			</frame>
			<Line text={quest.Name} size={stack ? 13 : 15} font={BODY_SEMI} width={new UDim(1, -(left + valueW + btnW + 24))} position={UDim2.fromOffset(left, stack ? 8 : 10)} />
			<Line
				text={reward !== "" ? `${quest.Description ?? ""}${quest.Description !== undefined && quest.Description !== "" ? "  ·  " : ""}${reward}` : quest.Description ?? ""}
				size={stack ? 11 : 12}
				font={BODY}
				color={Palette.muted}
				width={new UDim(1, -(left + valueW + btnW + 24))}
				position={UDim2.fromOffset(left, stack ? 24 : 30)}
			/>
			<Meter
				value={quest.Claimed || ready ? 1 : progressFrac}
				color={accent}
				reducedMotion={softMotion}
				shimmer={ready}
				position={meterPosition}
				size={meterSize}
			/>
			<ProgressCloseGlow progress={progressFrac} ready={ready} accent={accent} reducedMotion={softMotion} position={meterPosition} size={meterSize} />
			<Line
				text={valueText}
				size={stack ? 15 : 17}
				font={NUM}
				color={quest.Claimed ? Palette.muted : Palette.mango}
				width={new UDim(0, valueW)}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -(btnW + 12), 0.5, 0)}
				anchor={new Vector2(1, 0.5)}
			/>
			<frame Size={UDim2.fromOffset(btnW, 36)} Position={new UDim2(1, -btnW, 0.5, -18)} BackgroundTransparency={1} BorderSizePixel={0} ref={ready ? claimHostRef : undefined}>
				<Button
					text={quest.Claimed ? "Claimed" : ready ? "Claim" : "Not yet"}
					onClick={claim}
					color={ready ? Palette.mango : undefined}
					textColor={ready ? Palette.ink : Palette.creamSoft}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
					disabled={quest.Claimed || !ready}
					highlight={ready}
				/>
			</frame>
		</frame>
	);
}

// shows: the quest (Name, Description, Reward, Progress/Target, Claimed; Id for the claim) by value,
// position, stack layout, motion; dispatch is the shell's stable dispatcher
const MissionRow = React.memo(counted("Mission", MissionRowImpl), sameFields<MissionRowProps>(["quest", "dispatch", "reducedMotion", "position", "stack"]));

export interface TaskSummaryProps {
	reducedMotion?: boolean;
	done: number;
	total: number;
	accent: Color3;
	size: UDim2;
	position: UDim2;
}

export function TaskSummary(props: TaskSummaryProps) {
	const { done, total, accent } = props;
	const fraction = total > 0 ? done / total : 0;
	return (
		<frame Size={props.size} Position={props.position} BackgroundTransparency={1} BorderSizePixel={0}>
			{/* the headline beside this already gives the count; lead with how far along you are */}
			<Text
				value={`${math.floor(fraction * 100 + 0.5)}%`}
				size={20}
				color={accent}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				align={Enum.TextXAlignment.Right}
				sizeConstraint={new UDim2(1, 0, 0, 26)}
			/>
			<Text
				value={done >= total && total > 0 ? "all done" : "complete"}
				size={12}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				fit={true}
				align={Enum.TextXAlignment.Right}
				position={UDim2.fromOffset(0, 26)}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<Bar fill={fraction} color={accent} thin={true} position={UDim2.fromOffset(0, 46)} />
		</frame>
	);
}

// shared with Milestones: 0 ready to claim, 1 in progress, 2 claimed
export function taskRank(quest: TaskEntry) {
	if (!quest.Claimed && (tonumber(quest.Progress) ?? 0) >= (tonumber(quest.Target) ?? 0)) {
		return 0;
	} else if (quest.Claimed) {
		return 2;
	}
	return 1;
}

export function taskProgress(quest: TaskEntry) {
	return math.clamp((tonumber(quest.Progress) ?? 0) / math.max(1, tonumber(quest.Target) ?? 1), 0, 1);
}

interface PageGuide {
	EmptyNone?: string;
	EmptyFilter?: string;
}

interface MissionsViewProps {
	state: { Quests?: unknown };
	config?: { ClientPageGuides?: Record<string, PageGuide | undefined> };
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

// the list section is a fill section, so its height is only known once laid out; the ui4
// SplitColumns takes a fixed height, so measure the section and hand that down
function MeasuredSplit(props: { minHeight: number; render: (height: number) => React.Element }) {
	const ref = React.useRef<Frame>();
	const [height, setHeight] = React.useState(props.minHeight);
	React.useEffect(() => {
		const host = ref.current;
		if (host === undefined) {
			return undefined;
		}
		const sync = () => {
			const measured = math.max(props.minHeight, math.floor(host.AbsoluteSize.Y + 0.5));
			setHeight((current) => (current === measured ? current : measured));
		};
		sync();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(sync);
		return () => connection.Disconnect();
	}, [props.minHeight]);
	return (
		<frame ref={ref} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false}>
			{props.render(height)}
		</frame>
	);
}

export function MissionsView({ state, config, dispatch, reducedMotion }: MissionsViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const softMotion = reducedMotion;
	const enter = useEntrance(softMotion);
	const stack = chrome.contentStack;
	const quests = (typeIs(state.Quests, "table") ? state.Quests : []) as TaskEntry[];
	const counts = taskFilterCounts(quests);
	// desktop header: the summary card takes 190px on the right, the claim-all button another 214 when shown
	const headerSide = counts.Ready > 0 ? 420 : 206;
	const categories = TASK_FILTERS.map((option) => ({
		id: option.id,
		label: option.short ?? option.label,
		test: option.id === "All" ? undefined : (quest: TaskEntry) => taskMatchesFilter(quest, option.id),
	}));
	const browse = Browse.useBrowse<TaskEntry>({
		id: "Missions",
		items: quests,
		text: (quest) => [quest.Name, quest.Description, formatReward(quest.Reward), quest.Kind],
		categories,
		sorts: [
			{ id: "Recommended", label: "Ready first", compare: (a, b) => taskRank(a) < taskRank(b) },
			{
				id: "Closest",
				label: "Almost done",
				compare: (a, b) => {
					const ra = taskRank(a);
					const rb = taskRank(b);
					if (ra !== rb) {
						return ra < rb;
					}
					return taskProgress(a) > taskProgress(b);
				},
			},
			{ id: "List", label: "Daily order" },
		],
	});
	const visible = browse.results;
	const missionClaimHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (counts.Ready <= 0 || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = missionClaimHostRef.current;
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
	}, [counts.Ready, browse.category]);
	const guide = config !== undefined && config.ClientPageGuides !== undefined ? config.ClientPageGuides.Missions : undefined;
	const claimAllReady = () => {
		if (!typeIs(quests, "table")) {
			return;
		}
		const ready: TaskEntry[] = [];
		for (const quest of quests) {
			if (typeIs(quest, "table") && !quest.Claimed) {
				const progress = tonumber(quest.Progress) ?? 0;
				const target = tonumber(quest.Target) ?? 0;
				if (target > 0 && progress >= target) {
					ready.push(quest);
				}
			}
		}
		// one line for the whole batch instead of a pile of separate pops
		const total: Reward = {};
		let pending = ready.size();
		let landed = 0;
		const finish = () => {
			pending -= 1;
			if (pending > 0 || landed < 2) return;
			const summary = formatReward(total);
			Juice.status(summary !== "" ? `+${summary} from ${landed} missions` : `${landed} missions claimed`, "success");
		};
		for (const quest of ready) {
			dispatch("ClaimQuest", { Id: quest.Id }, (response) => {
				if (response.ok === true) {
					landed += 1;
					const reward = quest.Reward;
					if (reward !== undefined) {
						for (const key of ["Cash", "CashMinutes", "Stardust", "Cores", "Signals", "CommandXP", "StreakShield"] as const) {
							const amount = reward[key];
							if (amount !== undefined) total[key] = (total[key] ?? 0) + amount;
						}
					}
				}
				finish();
			});
		}
	};
	// the unfinished mission you're closest to, so the header names an actual next step
	let closest: TaskEntry | undefined;
	if (typeIs(quests, "table")) {
		for (const quest of quests) {
			if (!typeIs(quest, "table") || quest.Claimed === true || taskProgress(quest) >= 1) continue;
			if (closest === undefined || taskProgress(quest) > taskProgress(closest)) closest = quest;
		}
	}
	const closestReward = closest !== undefined ? formatReward(closest.Reward) : "";
	const nextStepText =
		closest === undefined
			? "Finish these for Flux and Stardust. They refresh every day."
			: `Closest: ${closest.Name}, ${compactNumber(closest.Progress)} / ${compactNumber(closest.Target)}` +
				(closestReward !== "" ? ` for ${closestReward}` : "");
	const barH = Browse.barHeight(stack, true);
	const introH = stack ? 40 : 70;
	const claimRowH = stack && counts.Ready > 0 ? TapTarget + 10 : 0;
	const headerHeight = 32 + introH + claimRowH + 10 + barH;
	// phones in landscape have the width for the side-by-side row; the tall stacked row
	// (claim button underneath) would fill most of a 360px-tall screen on its own
	const rowStack = stack && !chrome.landscape;
	const rowGap = stack ? 8 : 12;
	const rowStride = missionRowH(rowStack) + rowGap;
	const pageGap = 10;
	// wide desktop: header, summary, claim-all and browse controls in a side column; the list
	// fills the main column at full height
	// 1100px+ desktop, side 360/400px, 18px gap (ui4 helper in UiCore/ui.tsx)
	const plan = splitColumns(stack ? 0 : viewport.width, viewport.width >= 1600 ? 400 : 360, 18, 1100);
	// side column is ~330px: four counted chips don't fit one line, so they wrap onto a second
	const sideBarH = Browse.barHeight(true, true, 2);
	const sideClaimY = 106;
	const sideBarY = sideClaimY + (counts.Ready > 0 ? 54 : 0);
	const sideHeaderH = sideBarY + sideBarH + 32;
	const sidePanel = (
		<PnSurface radius={18} rule
			size={UDim2.fromScale(1, 1)}
			accent={Palette.brass}
			background={Palette.panel}
			padding={stack ? 10 : 18}
			reveal={enter}
			reducedMotion={softMotion}
			zIndex={30}
			clips={false}
		>
			<Text
				value={nextStepText}
				size={12}
				color={closest !== undefined ? Palette.creamSoft : Palette.muted}
				wrap={true}
				fit={true}
				minSize={9}
				position={UDim2.fromOffset(0, 0)}
				sizeConstraint={new UDim2(1, 0, 0, 34)}
			/>
			<TaskSummary
				done={counts.Done}
				total={quests.size()}
				accent={Palette.mango}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, 40)}
				size={new UDim2(1, 0, 0, 56)}
			/>
			{counts.Ready > 0 && (
				<frame
					key="MissionClaimActions"
					Size={new UDim2(1, 0, 0, 44)}
					Position={UDim2.fromOffset(0, sideClaimY)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={missionClaimHostRef}
				>
					<Button
						text={`Claim all · ${counts.Ready}`}
						icon="Gift.4"
						onClick={claimAllReady}
						color={Palette.mango}
						textColor={Palette.ink}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
						highlight={true}
					/>
				</frame>
			)}
			<Browse.BrowseBar
				browse={browse}
				placeholder="Search missions and rewards"
				accent={Palette.mango}
				stack={true}
				chipLines={2}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, sideBarY)}
				zIndex={40}
			/>
		</PnSurface>
	);
	const headerPanel = (
		<PnSurface radius={18} rule
			size={UDim2.fromScale(1, 1)}
			accent={Palette.brass}
			background={Palette.panel}
			padding={stack ? 10 : 18}
			reveal={enter}
			reducedMotion={softMotion}
			zIndex={30}
			clips={false}
		>
			{stack ? (
				<Text
					value="Today's missions"
					size={13}
					color={counts.Ready > 0 ? Palette.mango : Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					wrap={true} fit={true} minSize={10}
					sizeConstraint={new UDim2(1, -8, 0, 34)}
				/>
			) : (
				<>
					<Text
						// the ready count already shows on Claim All and the Ready chip
						value={`${counts.Done} of ${quests.size()} done today`}
						size={22}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={UDim2.fromOffset(0, 8)}
						sizeConstraint={new UDim2(1, -headerSide, 0, 30)}
					/>
					<Text
						value={nextStepText}
						size={12}
						color={closest !== undefined ? Palette.creamSoft : Palette.muted}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(0, 48)}
						sizeConstraint={new UDim2(1, -headerSide, 0, 16)}
					/>
					<TaskSummary
						done={counts.Done}
						total={quests.size()}
						accent={Palette.mango}
						reducedMotion={softMotion}
						position={new UDim2(1, -190, 0, 4)}
						size={UDim2.fromOffset(190, 56)}
					/>
				</>
			)}
			{counts.Ready > 0 && (
				<frame
					key="MissionClaimActions"
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(200, 44)}
					Position={stack ? UDim2.fromOffset(0, introH) : new UDim2(1, -404, 0, 10)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={missionClaimHostRef}
				>
					<Button
						text={`Claim all · ${counts.Ready}`}
						icon="Gift.4"
						onClick={claimAllReady}
						color={Palette.mango}
						textColor={Palette.ink}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
						highlight={true}
					/>
				</frame>
			)}
			<Browse.BrowseBar
				browse={browse}
				placeholder="Search missions and rewards"
				accent={Palette.mango}
				stack={stack}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, introH + claimRowH + 10)}
				zIndex={40}
			/>
		</PnSurface>
	);
	const missionsList = (
		<FlatList
			data={visible}
			itemHeight={rowStride}
			headerHeight={0}
			overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
			canvasTail={8}
			Size={UDim2.fromScale(1, 1)}
			scrollBarColor={Palette.brass}
			scrollBarThickness={3}
			scrollBarTransparency={0.28}
			keyExtractor={(quest: TaskEntry) => quest.Id}
			renderItem={({ item, index }: { item: TaskEntry; index?: number }) => (
				<RowArrive index={index ?? 0} reducedMotion={softMotion}>
					<MissionRow quest={item} dispatch={dispatch} reducedMotion={softMotion} position={UDim2.fromOffset(0, 0)} stack={rowStack} />
				</RowArrive>
			)}
			ListEmptyComponent={
				visible.size() === 0 ? (
					<Browse.NoResults
						browse={browse}
						noun="missions"
						icon="Mission.6"
						emptyBody={guide?.EmptyNone ?? "New dailies land at reset."}
						filteredBody={guide?.EmptyFilter ?? "Switch the filter back to All."}
						accent={Palette.mango}
						reducedMotion={softMotion}
						size={UDim2.fromScale(1, 1)}
					/>
				) : undefined
			}
		/>
	);
	return (
		<PageScaffold
			gap={pageGap}
			tailPad={scrollTail(stack, chrome.bottomSafe, 24)}
			scrollBarColor={Palette.brass}
			scrollBarThickness={4}
			sections={
				plan.split
					? [
							{
								id: "list",
								fill: true,
								minHeight: math.max(sideHeaderH, rowStride * 2),
								element: (
									<MeasuredSplit
										minHeight={math.max(sideHeaderH, rowStride * 2)}
										render={(splitH: number) => (
									<SplitColumns
										height={splitH}
										plan={plan}
										side={
											<frame Size={new UDim2(1, 0, 0, sideHeaderH)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} SelectionGroup={true}>
												{sidePanel}
											</frame>
										}
										main={
											<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={false} SelectionGroup={true}>
												{missionsList}
											</frame>
										}
										name="MissionsSplit"
									/>
										)}
									/>
								),
							},
						]
					: [
							{ id: "hero", height: headerHeight, element: headerPanel },
							{ id: "list", fill: true, minHeight: math.max(160, rowStride * 2), element: missionsList },
						]
			}
		/>
	);
}
