import React from "@rbxts/react";
import { counted, sameFields } from "../../UiCore/rowMemo";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { compactNumber, formatReward, Reward } from "../../CoreKit/format";
import { taskFilterCounts, taskMatchesFilter } from "../../CoreKit/taskFilter";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useFlash, usePulse, useViewport } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import Juice = require("../../JuiceFx");

const UserInputService = game.GetService("UserInputService");
const { Button, IconTile, Meter, Panel, Stroke, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
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

// one place for the row height so the list stride can't drift from the row again
function missionRowH(stack: boolean): number {
	return stack ? 226 : 148;
}

function MissionRowImpl({ quest, dispatch, reducedMotion, position, stack }: MissionRowProps) {
	const softMotion = reducedMotion;
	const ready = !quest.Claimed && quest.Progress >= quest.Target;
	const reward = formatReward(quest.Reward);
	const accent = quest.Claimed ? Palette.muted : ready ? Palette.green : Palette.cyan;
	const rowH = missionRowH(stack);
	const pad = stack ? 14 : 16;
	const contentH = rowH - pad * 2;
	const btnReserve = stack ? TapTarget + 14 : 0;
	const meterY = stack ? contentH - btnReserve - 8 : 108;
	const progressY = meterY - 18;
	const progressFrac = math.clamp(quest.Progress / math.max(1, quest.Target), 0, 1);
	const meterSize = new UDim2(1, stack ? 0 : -182, 0, 8);
	const meterPosition = UDim2.fromOffset(0, meterY);
	const readyPop = useReadyPop(ready, softMotion);
	const iconScale = readyPop.map((amount) => 1 + amount * 0.22);
	const claimText = quest.Claimed ? "CLAIMED" : ready ? "CLAIM" : "NOT YET";
	const claim = () => dispatch("ClaimQuest", { Id: quest.Id });
	return (
		<Panel
			size={new UDim2(1, 0, 0, rowH)}
			position={position}
			accent={accent}
			background={Palette.panel}
			padding={pad}
			interactive={true}
			highlight={ready}
			reducedMotion={softMotion}
		>
			<frame Size={UDim2.fromOffset(42, 42)} Position={UDim2.fromOffset(0, stack ? 4 : 10)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uiscale Scale={iconScale} />
				<IconTile
					kind="Mission"
					accent={quest.Claimed ? Palette.cyan : accent}
					size={42}
					radius={10}
					glow={ready}
					filled={ready}
					reducedMotion={softMotion}
				/>
			</frame>
			<Text
				value={quest.Name}
				size={stack ? 17 : 16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={stack}
				minSize={12}
				position={UDim2.fromOffset(56, 2)}
				sizeConstraint={new UDim2(1, stack ? -(56 + 12) : -182, 0, stack ? 28 : 22)}
			/>
			<Text
				value={quest.Description ?? ""}
				size={stack ? 12 : 11}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(56, stack ? 32 : 26)}
				sizeConstraint={new UDim2(1, stack ? -(56 + 12) : -182, 0, stack ? 36 : 28)}
			/>
			{reward !== "" && (
				<frame
					Size={UDim2.fromOffset(math.min(stack ? 170 : 220, reward.size() * 7 + 24), 20)}
					Position={UDim2.fromOffset(56, stack ? 72 : 56)}
					BackgroundColor3={Palette.ink}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uistroke Color={Palette.cyan} Thickness={1} Transparency={0.65} />
					<Text
						value={reward}
						size={11}
						color={Palette.cyan}
						weight={Enum.FontWeight.Heavy}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(6, 2)}
						sizeConstraint={new UDim2(1, -12, 1, -4)}
					/>
				</frame>
			)}
			<Text
				value={
					ready
						? "Reward ready"
						: quest.Claimed
							? "Claimed"
							: `${compactNumber(quest.Progress)} / ${compactNumber(quest.Target)}  ·  ${math.floor(progressFrac * 100)}%`
				}
				size={11}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				fit={true}
				minSize={8}
				position={UDim2.fromOffset(0, progressY)}
				sizeConstraint={stack ? new UDim2(1, 0, 0, 16) : new UDim2(1, -182, 0, 16)}
			/>
			<Meter
				value={quest.Claimed || ready ? 1 : progressFrac}
				color={quest.Claimed ? Palette.muted : accent}
				reducedMotion={softMotion}
				shimmer={ready}
				position={meterPosition}
				size={meterSize}
			/>
			<ProgressCloseGlow
				progress={progressFrac}
				ready={ready}
				accent={accent}
				reducedMotion={softMotion}
				position={meterPosition}
				size={meterSize}
			/>
			{stack ? (
				<Button
					text={claimText}
					icon="Mission.4"
					onClick={claim}
					color={ready ? Palette.green : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.creamSoft}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={new UDim2(0, 0, 1, -(TapTarget + 6))}
					reducedMotion={softMotion}
					disabled={quest.Claimed || !ready}
					highlight={ready}
				/>
			) : (
				<Button
					text={claimText}
					icon="Mission.5"
					onClick={claim}
					color={ready ? Palette.green : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.creamSoft}
					size={UDim2.fromOffset(166, 44)}
					position={new UDim2(1, -166, 0.5, -22)}
					reducedMotion={softMotion}
					disabled={quest.Claimed || !ready}
					highlight={ready}
				/>
			)}
		</Panel>
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
			<Meter
				value={fraction}
				color={accent}
				reducedMotion={props.reducedMotion}
				position={UDim2.fromOffset(0, 46)}
				size={new UDim2(1, 0, 0, 6)}
			/>
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
	const rowStride = missionRowH(rowStack) + 16;
	const pageGap = 10;
	const headerPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.cyan}
			background={Palette.panelRaised}
			padding={16}
			reveal={enter}
			reducedMotion={softMotion}
			zIndex={30}
			clips={false}
		>
			{stack ? (
				<Text
					value="TODAY'S MISSIONS · NEW EACH DAY"
					size={13}
					color={counts.Ready > 0 ? Palette.green : Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					wrap={true} fit={true} minSize={10}
					sizeConstraint={new UDim2(1, -8, 0, 34)}
				/>
			) : (
				<>
					<Text
						value="MISSIONS"
						size={11}
						color={Palette.cyan}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						sizeConstraint={new UDim2(1, -headerSide, 0, 16)}
					/>
					<Text
						value={
							counts.Ready > 0
								? `${counts.Ready} ready to claim · ${counts.Done} of ${quests.size()} done`
								: `${counts.Done} of ${quests.size()} done today`
						}
						size={22}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={UDim2.fromOffset(0, 16)}
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
						accent={Palette.cyan}
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
						text={`CLAIM ALL · ${counts.Ready}`}
						icon="Gift.4"
						onClick={claimAllReady}
						color={Palette.green}
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
				accent={Palette.cyan}
				stack={stack}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, introH + claimRowH + 10)}
				zIndex={40}
			/>
		</Panel>
	);
	const missionsList = (
		<FlatList
			data={visible}
			itemHeight={rowStride}
			headerHeight={0}
			overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
			canvasTail={8}
			Size={UDim2.fromScale(1, 1)}
			scrollBarColor={Palette.cyan}
			scrollBarThickness={3}
			scrollBarTransparency={0.28}
			keyExtractor={(quest: TaskEntry) => quest.Id}
			renderItem={({ item }: { item: TaskEntry }) => (
				<MissionRow quest={item} dispatch={dispatch} reducedMotion={softMotion} position={UDim2.fromOffset(0, 0)} stack={rowStack} />
			)}
			ListEmptyComponent={
				visible.size() === 0 ? (
					<Browse.NoResults
						browse={browse}
						noun="missions"
						icon="Mission.6"
						emptyBody={guide?.EmptyNone ?? "New dailies land at reset."}
						filteredBody={guide?.EmptyFilter ?? "Switch the filter back to All."}
						accent={Palette.cyan}
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
			scrollBarColor={Palette.cyan}
			scrollBarThickness={4}
			sections={[
				{ id: "hero", height: headerHeight, element: headerPanel },
				{ id: "list", fill: true, minHeight: math.max(160, rowStride * 2), element: missionsList },
			]}
		/>
	);
}
