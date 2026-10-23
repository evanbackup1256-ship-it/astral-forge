import React from "@rbxts/react";
import { FocusPlan, useFocusOrder } from "../../CoreKit/focusOrder";
import { counted, sameFields } from "../../UiCore/rowMemo";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { compactNumber, formatReward } from "../../CoreKit/format";
import { chromeFor, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useAntilag } from "../../MotionKit/antilag";
import { useEntrance, useViewport } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import {
	ProgressCloseGlow,
	TASK_FILTERS,
	TaskEntry,
	taskFilterCounts,
	taskMatchesFilter,
	taskProgress,
	taskRank,
	TaskRow,
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
	return stack ? 64 : 76;
}

function MilestoneRowImpl({ achievement, dispatch, reducedMotion, position, stack, claimHostRef }: MilestoneRowProps) {
	return (
		<TaskRow
			quest={achievement}
			icon="Milestone"
			onClaim={() => dispatch("ClaimAchievement", { Id: achievement.Id })}
			reducedMotion={reducedMotion}
			position={position}
			stack={stack}
			claimHostRef={claimHostRef}
		/>
	);
}

interface MilestoneRowProps {
	achievement: TaskEntry;
	dispatch: Dispatch;
	reducedMotion?: boolean;
	position: UDim2;
	stack: boolean;
	claimHostRef?: React.Ref<Frame>;
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
	const rowStride = milestoneRowH(rowStack) + (stack ? 8 : 12);
	const pageGap = stack ? chrome.panelGap : 18;
	const headerPanel = (
		<Panel radius={18} rule
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
					value="Milestones (kept on rebirth)"
					size={13}
					color={counts.Ready > 0 ? Palette.mango : Palette.creamSoft}
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
						text={`Claim all · ${counts.Ready}`}
						icon="Gift.3"
						onClick={claimAllReady}
						color={Palette.mango}
						textColor={Color3.fromRGB(27, 15, 8)}
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
