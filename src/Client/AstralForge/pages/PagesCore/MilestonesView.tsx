import React from "@rbxts/react";
import { FocusPlan, useFocusOrder } from "../../CoreKit/focusOrder";
import { counted, sameFields } from "../../UiCore/rowMemo";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { compactNumber, formatReward } from "../../CoreKit/format";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useFlash, useViewport } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import {
	ProgressCloseGlow,
	TASK_FILTERS,
	TaskEntry,
	taskFilterCounts,
	taskMatchesFilter,
	taskProgress,
	taskRank,
	TaskSummary,
} from "./MissionsView";

const UserInputService = game.GetService("UserInputService");
const { Button, IconTile, Meter, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { FlatList } = kitMember<{ FlatList: LuauComponent }>("LayoutKit", "virtualizedList");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const Browse = clientModule<BrowseApi>("BrowseKit");

type Dispatch = (action: string, payload: { Id: string }) => unknown;

// one place for the row height so the list stride can't drift from the row
function milestoneRowH(stack: boolean): number {
	return stack ? 220 : 148;
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

interface MilestoneRowProps {
	achievement: TaskEntry;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	position: UDim2;
	stack: boolean;
	claimHostRef?: React.Ref<Frame>;
}

function MilestoneRowImpl({ achievement, dispatch, reducedMotion, position, stack, claimHostRef }: MilestoneRowProps) {
	const softMotion = reducedMotion;
	const ready = !achievement.Claimed && achievement.Progress >= achievement.Target;
	const reward = formatReward(achievement.Reward);
	const accent = achievement.Claimed ? Palette.muted : ready ? Palette.green : Palette.mango;
	const rowH = milestoneRowH(stack);
	const pad = stack ? 14 : 16;
	const contentH = rowH - pad * 2;
	const btnReserve = stack ? TapTarget + 14 : 0;
	const meterY = stack ? contentH - btnReserve - 8 : 108;
	const progressY = meterY - 18;
	const progressFrac = math.clamp(achievement.Progress / math.max(1, achievement.Target), 0, 1);
	const meterSize = new UDim2(1, stack ? 0 : -182, 0, 8);
	const meterPosition = UDim2.fromOffset(0, meterY);
	const readyPop = useReadyPop(ready, softMotion);
	const iconScale = readyPop.map((amount) => 1 + amount * 0.22);
	const claimText = achievement.Claimed ? "CLAIMED" : ready ? "CLAIM REWARD" : "LOCKED";
	const claim = () => dispatch("ClaimAchievement", { Id: achievement.Id });
	return (
		<Panel radius={18} rule
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
					kind="Milestone"
					accent={achievement.Claimed ? Palette.mango : accent}
					size={42}
					radius={10}
					glow={ready}
					filled={ready}
					reducedMotion={softMotion}
				/>
			</frame>
			<Text
				value={achievement.Name}
				size={stack ? 17 : 16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				position={UDim2.fromOffset(56, 2)}
				sizeConstraint={new UDim2(1, stack ? -(56 + 12) : -182, 0, 22)}
			/>
			<Text
				value={achievement.Description ?? ""}
				size={stack ? 12 : 11}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(56, 26)}
				sizeConstraint={new UDim2(1, stack ? -(56 + 12) : -182, 0, stack ? 36 : 28)}
			/>
			{reward !== "" && (
				<frame
					Size={UDim2.fromOffset(math.min(220, reward.size() * 7 + 24), 20)}
					Position={UDim2.fromOffset(56, stack ? 66 : 56)}
					BackgroundColor3={Palette.ink}
					BorderSizePixel={0}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uistroke Color={Palette.mango} Thickness={1} Transparency={0.65} />
					<Text
						value={reward}
						size={11}
						color={Palette.mango}
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
						: achievement.Claimed
							? "Claimed"
							: `${compactNumber(achievement.Progress)} / ${compactNumber(achievement.Target)}  ·  ${math.floor(progressFrac * 100)}%`
				}
				size={11}
				color={Palette.muted}
				weight={Enum.FontWeight.Bold}
				fit={false}
				position={UDim2.fromOffset(0, progressY)}
				sizeConstraint={new UDim2(0, 220, 0, 16)}
			/>
			<Meter
				value={achievement.Claimed || ready ? 1 : progressFrac}
				color={achievement.Claimed ? Palette.muted : accent}
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
			<frame
				key="MilestoneClaimActions"
				Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(166, 44)}
				Position={stack ? new UDim2(0, 0, 1, -(TapTarget + 6)) : new UDim2(1, -166, 0.5, -22)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ref={ready ? claimHostRef : undefined}
			>
				<Button
					text={claimText}
					icon={stack ? "Wheel.4" : "Wheel.5"}
					onClick={claim}
					color={ready ? Palette.green : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.creamSoft}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
					disabled={achievement.Claimed || !ready}
					highlight={ready}
				/>
			</frame>
		</Panel>
	);
}

// shows: the achievement (Name, Description, Reward, Progress/Target, Claimed; Id for the claim) by value,
// position, stack layout, motion, and whether it hosts the gamepad claim focus (claimHostRef)
const MilestoneRow = React.memo(counted("Milestone", MilestoneRowImpl), sameFields<MilestoneRowProps>(["achievement", "dispatch", "reducedMotion", "position", "stack", "claimHostRef"]));

interface MilestonesViewProps {
	state: { Achievements?: TaskEntry[] };
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

export function MilestonesView({ state, dispatch, reducedMotion }: MilestonesViewProps) {
	const softMotion = reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const antilag = useAntilag();
	const enter = useEntrance(softMotion);
	const stack = chrome.contentStack;
	// phones in landscape get the side-by-side milestone row (claim on the right)
	const rowStack = stack && !chrome.landscape;
	const list = state.Achievements ?? [];
	const counts = taskFilterCounts(list);
	const categories = TASK_FILTERS.map((option) => ({
		id: option.id,
		label: option.short ?? option.label,
		test: option.id === "All" ? undefined : (achievement: TaskEntry) => taskMatchesFilter(achievement, option.id),
	}));
	const browse = Browse.useBrowse<TaskEntry>({
		id: "Milestones",
		items: list,
		text: (achievement) => [achievement.Name, achievement.Description, formatReward(achievement.Reward)],
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
			{ id: "Name", label: "A to Z", compare: (a, b) => tostring(a.Name) < tostring(b.Name) },
		],
	});
	const visible = browse.results;
	const claimHostRef = React.useRef<Frame>();
	// gamepad: Claim all (when ready) or search first, then down into the list
	const pageHostRef = React.useRef<Frame>();
	useFocusOrder(pageHostRef, { regions: ["hero", "list"], first: ["hero", "list"] }, [counts.Ready, browse.category, stack]);
	let firstReadyId: string | undefined;
	for (const achievement of visible) {
		if (taskRank(achievement) === 0) {
			firstReadyId = achievement.Id;
			break;
		}
	}
	React.useEffect(() => {
		if (firstReadyId === undefined || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = claimHostRef.current;
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
	}, [firstReadyId, browse.category]);
	const claimAllReady = () => {
		for (const achievement of list) {
			if (typeIs(achievement, "table") && taskRank(achievement) === 0) {
				dispatch("ClaimAchievement", { Id: achievement.Id });
			}
		}
	};
	const barH = Browse.barHeight(stack, true);
	const introH = stack ? 40 : 64;
	const claimRowH = stack && counts.Ready > 0 ? TapTarget + 10 : 0;
	const headerHeight = (stack ? 32 : 44) + introH + claimRowH + 10 + barH;
	const rowStride = milestoneRowH(rowStack) + 16;
	const pageGap = stack ? chrome.panelGap : 18;
	const headerPanel = (
		<Panel radius={18} rule
			size={UDim2.fromScale(1, 1)}
			accent={Palette.mango}
			background={Palette.panelRaised}
			padding={stack ? 16 : 22}
			reveal={enter}
			reducedMotion={softMotion}
			zIndex={30}
			clips={false}
		>
			{stack ? (
				<Text
					value="Milestones (kept on rebirth)"
					size={13}
					color={counts.Ready > 0 ? Palette.green : Palette.creamSoft}
					weight={Enum.FontWeight.Bold}
					wrap={true}
					fit={true}
					minSize={10}
					sizeConstraint={new UDim2(1, -8, 0, 34)}
				/>
			) : (
				<>
					<Text
						value={
							counts.Ready > 0
								? `${counts.Ready} ready to claim · ${counts.Done} of ${list.size()} done`
								: `${counts.Done} of ${list.size()} reached`
						}
						size={22}
						color={Palette.cream}
						weight={Enum.FontWeight.Heavy}
						fit={false}
						position={UDim2.fromOffset(0, 17)}
						sizeConstraint={new UDim2(1, -420, 0, 30)}
					/>
					<TaskSummary
						done={counts.Done}
						total={list.size()}
						accent={Palette.mango}
						reducedMotion={softMotion}
						position={new UDim2(1, -190, 0, 4)}
						size={UDim2.fromOffset(190, 56)}
					/>
				</>
			)}
			{counts.Ready > 0 && (
				<frame
					key="MilestoneClaimAllActions"
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(200, 44)}
					Position={stack ? UDim2.fromOffset(0, introH) : new UDim2(1, -404, 0, 10)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					<Button
						text={`CLAIM ALL · ${counts.Ready}`}
						icon="Gift.3"
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
				placeholder="Search milestones and rewards"
				accent={Palette.mango}
				stack={stack}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, introH + claimRowH + 10)}
				zIndex={40}
			/>
		</Panel>
	);
	const milestonesList = (
		<FlatList
			data={visible}
			itemHeight={rowStride}
			headerHeight={0}
			overscan={softMotion ? 0 : antilag.constrained ? 1 : 2}
			canvasTail={8}
			Size={UDim2.fromScale(1, 1)}
			scrollBarColor={Palette.mango}
			scrollBarThickness={3}
			scrollBarTransparency={0.28}
			keyExtractor={(achievement: TaskEntry) => achievement.Id}
			renderItem={({ item }: { item: TaskEntry }) => (
				<MilestoneRow
					achievement={item}
					dispatch={dispatch}
					reducedMotion={softMotion}
					position={UDim2.fromOffset(0, 0)}
					stack={rowStack}
					claimHostRef={item.Id === firstReadyId ? claimHostRef : undefined}
				/>
			)}
			ListEmptyComponent={
				visible.size() === 0 ? (
					<Browse.NoResults
						browse={browse}
						noun="milestones"
						icon="Milestone.3"
						emptyBody="Keep playing and they will show up."
						accent={Palette.mango}
						reducedMotion={softMotion}
						size={UDim2.fromScale(1, 1)}
					/>
				) : undefined
			}
		/>
	);
	return (
		<frame ref={pageHostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<PageScaffold
				gap={pageGap}
				tailPad={scrollTail(stack, chrome.bottomSafe, 24)}
				scrollBarColor={Palette.mango}
				scrollBarThickness={4}
				sections={[
					{ id: "hero", height: headerHeight, element: headerPanel },
					{ id: "list", fill: true, minHeight: math.max(160, rowStride * 2), element: milestonesList },
				]}
			/>
		</frame>
	);
}
