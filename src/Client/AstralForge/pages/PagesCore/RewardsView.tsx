import React from "@rbxts/react";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, formatReward, Reward } from "../../CoreKit/format";
import { chromeFor, darken, lighten, Palette, scrollTail, TapTarget } from "../../CoreKit/theme";
import { useFlipperSpring, useStagger, useViewport } from "../../MotionKit/motion";
import { BrowseApi, clientModule, kitMember, LuauComponent } from "../luauKits";
import { CommunityDispatch, CommunityPanel, CommunityState, useCommunityRewards } from "./CommunityPanel";
import { EventDispatch, EventPanel, eventPanelHeight, EventState } from "./EventPanel";

const UserInputService = game.GetService("UserInputService");
const { Button, IconTile, Panel, Text } = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const Browse = clientModule<BrowseApi>("BrowseKit");

type Dispatch = (action: string, payload?: { Index?: number }) => unknown;

interface DailyState {
	Rewards?: Reward[];
	CanClaim?: boolean;
	NextStreak?: number;
	Streak?: number;
	RewardIndex?: number;
}
interface TimedEntry {
	Index?: number;
	Seconds: number;
	Claimed?: boolean;
	Reward?: Reward;
}
interface ClaimableTask {
	Claimed?: boolean;
	Progress?: number;
	Target?: number;
}

interface ChargeRailProps {
	value: number;
	accent: Color3;
	ready: boolean;
	reducedMotion?: boolean;
	position: UDim2;
	size: UDim2;
}

function RewardChargeRail({ value, accent, ready, reducedMotion, position, size }: ChargeRailProps) {
	const softMotion = reducedMotion;
	const progress = useFlipperSpring(math.clamp(value, 0, 1), softMotion, 420, 32);
	const emphasis = useFlipperSpring(ready ? 1 : 0, softMotion, 460, 32);
	const fillSize = progress.map((amount) => new UDim2(math.clamp(amount, 0, 1), 0, 1, 0));
	const markerPosition = progress.map((amount) => new UDim2(math.clamp(amount, 0, 1), 0, 0.5, 0));
	const markerScale = emphasis.map((amount) => 0.78 + math.clamp(amount, 0, 1) * 0.22);
	return (
		<frame
			Size={size}
			Position={position}
			BackgroundColor3={Palette.panelSoft}
			BackgroundTransparency={0.22}
			BorderSizePixel={0}
			ClipsDescendants={false}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<frame Size={fillSize} BackgroundColor3={accent} BorderSizePixel={0} ClipsDescendants={false}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Color={new ColorSequence(darken(accent, 0.18), lighten(accent, 0.3))} />
			</frame>
			<frame
				Size={UDim2.fromOffset(8, 8)}
				Position={markerPosition}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				BackgroundColor3={ready ? Palette.cream : accent}
				BackgroundTransparency={progress.map((amount) => (amount > 0.025 ? 0 : 1))}
				BorderSizePixel={0}
				ZIndex={2}
			>
				<uiscale Scale={markerScale} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					LineJoinMode={Enum.LineJoinMode.Round}
					Color={accent}
					Thickness={1}
					Transparency={emphasis.map((amount) => 0.68 - math.clamp(amount, 0, 1) * 0.46)}
				/>
			</frame>
		</frame>
	);
}

function StreakStrip(props: { daily: DailyState; reducedMotion?: boolean; position: UDim2; size: UDim2 }) {
	const daily = props.daily;
	const rewards = daily.Rewards ?? [];
	const count = math.max(1, rewards.size());
	const canClaim = daily.CanClaim === true;
	let current = canClaim ? (tonumber(daily.NextStreak) ?? 1) : (tonumber(daily.Streak) ?? 0);
	current = math.max(1, current);
	const weekStart = math.floor((current - 1) / 7) * 7 + 1;
	const cells: Record<string, React.Element> = {
		layout: (
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 6)} />
		),
	};
	for (let offset = 0; offset <= 6; offset++) {
		const day = weekStart + offset;
		const reward = rewards[(day - 1) % count];
		const claimed = day < current || (day === current && !canClaim);
		const today = day === current && canClaim;
		const accent = today ? Palette.mint : claimed ? Palette.muted : Palette.cyan;
		cells["d" + day] = (
			<frame
				Size={new UDim2(1 / 7, (-6 * 6) / 7, 1, 0)}
				LayoutOrder={offset}
				BackgroundColor3={today ? darken(Palette.mint, 0.55) : Palette.panelSoft}
				BackgroundTransparency={claimed ? 0.45 : 0}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke
					Color={accent}
					Transparency={today ? 0.1 : 0.7}
					Thickness={today ? 1.5 : 1}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				/>
				<Text
					value={today ? "TODAY" : `DAY ${day}`}
					size={11}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={8}
					align={Enum.TextXAlignment.Center}
					position={UDim2.fromOffset(4, 6)}
					sizeConstraint={new UDim2(1, -8, 0, 14)}
				/>
				{claimed ? (
					<frame
						Size={UDim2.fromOffset(18, 18)}
						Position={new UDim2(0.5, 0, 0, 24)}
						AnchorPoint={new Vector2(0.5, 0)}
						BackgroundTransparency={1}
					>
						<Icon kind="Check.3" color={Palette.muted} accent={Palette.muted} size={18} spin={false} />
					</frame>
				) : (
					<Text
						value={formatReward(reward)}
						size={11}
						color={today ? Palette.cream : Palette.creamSoft}
						weight={Enum.FontWeight.Bold}
						wrap={true}
						fit={true}
						minSize={8}
						align={Enum.TextXAlignment.Center}
						position={UDim2.fromOffset(4, 22)}
						sizeConstraint={new UDim2(1, -8, 1, -26)}
					/>
				)}
			</frame>
		);
	}
	return (
		<frame Size={props.size} Position={props.position} BackgroundTransparency={1} BorderSizePixel={0}>
			{cells}
		</frame>
	);
}

interface TimelineProps {
	entries: TimedEntry[];
	played: number;
	dispatch: Dispatch;
	columns: number;
	reducedMotion?: boolean;
}

function TimedTimeline({ entries, played, dispatch, columns, reducedMotion }: TimelineProps) {
	const softMotion = reducedMotion;
	const cellH = 92;
	const cells: Record<string, React.Element> = {
		grid: (
			<uigridlayout
				CellSize={new UDim2(1 / columns, -math.ceil((8 * (columns - 1)) / columns), 0, cellH)}
				CellPadding={UDim2.fromOffset(8, 8)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
		),
	};
	entries.forEach((entry, i) => {
		const index = i + 1;
		const seconds = tonumber(entry.Seconds) ?? 0;
		const ready = !entry.Claimed && played >= seconds;
		const accent = entry.Claimed ? Palette.muted : ready ? Palette.violet : Palette.cyan;
		const reward = formatReward(entry.Reward);
		cells["t" + tostring(entry.Index ?? index)] = (
			<frame
				LayoutOrder={index}
				BackgroundColor3={ready ? Palette.panelRaised : Palette.panelSoft}
				BackgroundTransparency={entry.Claimed ? 0.45 : 0}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke Color={accent} Transparency={ready ? 0.2 : 0.72} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				<Text
					value={
						entry.Claimed
							? `${clockText(seconds)} · COLLECTED`
							: ready
								? "READY"
								: `AT ${clockText(seconds)} · IN ${clockText(seconds - played)}`
					}
					size={11}
					color={accent}
					weight={Enum.FontWeight.Heavy}
					fit={true}
					minSize={8}
					position={UDim2.fromOffset(10, 8)}
					sizeConstraint={new UDim2(1, -20, 0, 14)}
				/>
				<Text
					value={reward !== "" ? reward : "Mystery parcel"}
					size={13}
					color={entry.Claimed ? Palette.muted : Palette.cream}
					weight={Enum.FontWeight.Bold}
					fit={true}
					minSize={9}
					position={UDim2.fromOffset(10, 26)}
					sizeConstraint={new UDim2(1, -20, 0, 18)}
				/>
				{ready ? (
					<Button
						text="CLAIM"
						icon="Timer.2"
						onClick={() => {
							dispatch("ClaimTimedReward", { Index: entry.Index });
						}}
						color={Palette.violet}
						textColor={Palette.ink}
						size={new UDim2(1, -16, 0, 34)}
						position={new UDim2(0, 8, 1, -40)}
						reducedMotion={softMotion}
						highlight={true}
					/>
				) : (
					<RewardChargeRail
						value={entry.Claimed ? 1 : played / math.max(1, seconds)}
						accent={accent}
						ready={false}
						reducedMotion={softMotion}
						position={new UDim2(0, 10, 1, -16)}
						size={new UDim2(1, -20, 0, 5)}
					/>
				)}
			</frame>
		);
	});
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			{cells}
		</frame>
	);
}

interface ShortcutTileProps {
	reducedMotion?: boolean;
	layoutOrder: number;
	badge?: number;
	label: string;
	icon: string;
	accent: Color3;
	onClick: () => void;
}

function ShortcutTile(props: ShortcutTileProps) {
	const badged = props.badge !== undefined && props.badge > 0;
	return (
		<frame LayoutOrder={props.layoutOrder} BackgroundTransparency={1} BorderSizePixel={0}>
			<Button
				text={badged ? `${props.label} · ${props.badge}` : props.label}
				icon={props.icon}
				onClick={props.onClick}
				color={badged ? props.accent : Palette.panelSoft}
				textColor={badged ? Palette.ink : Palette.cream}
				outline={!badged}
				highlight={badged}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={props.reducedMotion}
			/>
		</frame>
	);
}

function readyTask(entry: unknown): boolean {
	if (!typeIs(entry, "table")) {
		return false;
	}
	const item = entry as ClaimableTask;
	return !item.Claimed && (tonumber(item.Progress) ?? 0) >= (tonumber(item.Target) ?? math.huge);
}

interface RewardsViewProps {
	state: {
		Daily?: DailyState;
		TimedRewards?: { Rewards?: TimedEntry[]; PlaySeconds?: number };
		Quests?: unknown;
		Achievements?: unknown[];
		Community?: CommunityState;
		LimitedEvent?: EventState;
	};
	dispatch: Dispatch;
	navigate?: (page: string) => void;
	reducedMotion?: boolean;
}

export function RewardsView({ state, dispatch, navigate, reducedMotion }: RewardsViewProps) {
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const softMotion = reducedMotion;
	const daily = state.Daily ?? {};
	const dailyReady = daily.CanClaim === true;
	const timed = state.TimedRewards ?? {};
	const timedEntries = timed.Rewards ?? [];
	const played = tonumber(timed.PlaySeconds) ?? 0;
	let nextTimed: TimedEntry | undefined;
	const readyTimed: TimedEntry[] = [];
	for (const entry of timedEntries) {
		if (!entry.Claimed) {
			if (nextTimed === undefined) {
				nextTimed = entry;
			}
			if (played >= (tonumber(entry.Seconds) ?? math.huge)) {
				readyTimed.push(entry);
			}
		}
	}
	const timedReady = nextTimed !== undefined && played >= nextTimed.Seconds;
	const timedProgress = nextTimed !== undefined ? math.clamp(played / math.max(1, nextTimed.Seconds), 0, 1) : 1;
	const dailyReward = daily.RewardIndex !== undefined ? (daily.Rewards ?? [])[daily.RewardIndex - 1] : undefined;
	const now = Browse.useServerNow(1);
	const resetIn = Browse.untilUtcReset(now);
	const headerReveal = useStagger(0, softMotion);
	const dailyReveal = useStagger(1, softMotion);
	const timedReveal = useStagger(2, softMotion);
	const streakReveal = useStagger(3, softMotion);
	const rewardsTail = scrollTail(stack, chrome.bottomSafe, 48);
	const community = useCommunityRewards(state.Community, stack);
	const rewardsClaimHostRef = React.useRef<Frame>();
	const readyCount = (dailyReady ? 1 : 0) + readyTimed.size();
	const rewardsClaimReady = readyCount > 0;
	React.useEffect(() => {
		if (!rewardsClaimReady || !UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = rewardsClaimHostRef.current;
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
	}, [dailyReady, timedReady, rewardsClaimReady]);
	const claimEverything = () => {
		if (dailyReady) {
			dispatch("ClaimDaily");
		}
		for (const entry of readyTimed) {
			dispatch("ClaimTimedReward", { Index: entry.Index });
		}
	};

	// counts for the shortcut tiles
	let readyMissions = 0;
	for (const quest of (typeIs(state.Quests, "table") ? state.Quests : []) as unknown[]) {
		if (readyTask(quest)) {
			readyMissions += 1;
		}
	}
	let readyMilestones = 0;
	for (const achievement of state.Achievements ?? []) {
		if (readyTask(achievement)) {
			readyMilestones += 1;
		}
	}

	const heroH = stack ? 116 + (readyCount > 0 ? TapTarget + 8 : 0) : 96;
	const headerPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.pink}
			background={Palette.panelRaised}
			padding={14}
			layoutOrder={0}
			reveal={headerReveal}
			reducedMotion={softMotion}
			clips={false}
		>
			<Text
				value="REWARDS"
				size={11}
				color={Palette.pink}
				weight={Enum.FontWeight.Heavy}
				fit={false}
				sizeConstraint={new UDim2(1, -120, 0, 14)}
			/>
			<Text
				value={readyCount > 0 ? `${readyCount} reward${readyCount === 1 ? "" : "s"} waiting.` : "All caught up."}
				size={stack ? 20 : 22}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={14}
				position={UDim2.fromOffset(0, 18)}
				sizeConstraint={new UDim2(1, stack ? 0 : -240, 0, 28)}
			/>
			<Text
				value={`Daily parcel and playtime drops reset in ${Browse.shortDuration(resetIn)} (midnight UTC).`}
				size={12}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 50)}
				sizeConstraint={new UDim2(1, stack ? 0 : -240, 0, stack ? 32 : 16)}
			/>
			{readyCount > 0 && (
				<frame
					key="RewardsClaimAllActions"
					Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(220, 44)}
					Position={stack ? new UDim2(0, 0, 1, -TapTarget) : new UDim2(1, -220, 0.5, -22)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					ClipsDescendants={false}
					ref={rewardsClaimHostRef}
				>
					<Button
						text={`CLAIM EVERYTHING · ${readyCount}`}
						icon="Gift.2"
						onClick={claimEverything}
						color={Palette.pink}
						textColor={Palette.ink}
						size={UDim2.fromScale(1, 1)}
						reducedMotion={softMotion}
						highlight={true}
					/>
				</frame>
			)}
		</Panel>
	);

	const stripH = 72;
	const stripY = stack ? 80 + TapTarget + 8 : 84;
	const dailyCardH = stripY + stripH + 28;
	const dailyRewardText = formatReward(dailyReward);
	const dailyPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.mint}
			background={Palette.panel}
			padding={14}
			layoutOrder={1}
			reveal={dailyReveal}
			highlight={dailyReady}
			reducedMotion={softMotion}
			clips={false}
		>
			<IconTile
				kind="Calendar"
				accent={dailyReady ? Palette.mint : Palette.panelSoft}
				size={46}
				radius={14}
				position={UDim2.fromOffset(0, stack ? 4 : 18)}
				glow={dailyReady}
				reducedMotion={softMotion}
			/>
			<Text
				value="Daily parcel"
				size={16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				position={UDim2.fromOffset(60, 6)}
				sizeConstraint={new UDim2(1, stack ? -60 : -230, 0, 23)}
			/>
			<Text
				value={dailyRewardText !== "" ? dailyRewardText : dailyReady ? "Ready to open" : "Already collected today"}
				size={12}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(60, 32)}
				sizeConstraint={new UDim2(1, stack ? -60 : -230, 0, 20)}
			/>
			<Text
				value={
					dailyReady
						? `Streak ${daily.Streak ?? 0} → ${daily.NextStreak ?? 1} when you claim`
						: `Streak ${daily.Streak ?? 0} · next parcel in ${Browse.shortDuration(resetIn)}`
				}
				size={12}
				color={Palette.mint}
				weight={Enum.FontWeight.Bold}
				fit={true}
				position={UDim2.fromOffset(60, 56)}
				sizeConstraint={new UDim2(1, stack ? -60 : -230, 0, 16)}
			/>
			<frame
				key="RewardsDailyClaimActions"
				Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(150, 44)}
				Position={stack ? UDim2.fromOffset(0, 80) : new UDim2(1, -150, 0, 18)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ref={dailyReady && readyCount === 0 ? rewardsClaimHostRef : undefined}
			>
				<Button
					text={dailyReady ? "Claim" : "Claimed"}
					icon="Calendar.2"
					onClick={() => dispatch("ClaimDaily")}
					color={dailyReady ? Palette.mint : Palette.panelSoft}
					textColor={dailyReady ? Palette.ink : Palette.muted}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
					disabled={!dailyReady}
					highlight={dailyReady}
				/>
			</frame>
			<StreakStrip daily={daily} reducedMotion={softMotion} position={UDim2.fromOffset(0, stripY)} size={new UDim2(1, 0, 0, stripH)} />
		</Panel>
	);

	const timedCardH = stack ? 172 : 110;
	const nextReward = nextTimed !== undefined ? formatReward(nextTimed.Reward) : "";
	const timedPanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.violet}
			background={Palette.panel}
			padding={14}
			layoutOrder={2}
			reveal={timedReady ? streakReveal : timedReveal}
			highlight={timedReady && !softMotion}
			reducedMotion={softMotion}
			clips={false}
		>
			<IconTile
				kind="Timer"
				accent={timedReady ? Palette.violet : Palette.panelSoft}
				size={46}
				radius={14}
				position={UDim2.fromOffset(0, stack ? 4 : 18)}
				glow={timedReady}
				reducedMotion={softMotion}
			/>
			<Text
				value="Next playtime drop"
				size={16}
				color={Palette.cream}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				position={UDim2.fromOffset(60, 6)}
				sizeConstraint={new UDim2(1, stack ? -60 : -230, 0, 23)}
			/>
			<Text
				value={
					nextTimed === undefined
						? "All caught up for today"
						: nextReward !== ""
							? nextReward
							: timedReady
								? "Ready to collect"
								: clockText(played) + " of " + clockText(nextTimed.Seconds) + " played"
				}
				size={12}
				color={Palette.muted}
				fit={true}
				position={UDim2.fromOffset(60, 32)}
				sizeConstraint={new UDim2(1, stack ? -60 : -230, 0, 17)}
			/>
			<RewardChargeRail
				value={timedProgress}
				accent={timedReady ? Palette.violet : Palette.cyan}
				ready={timedReady}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(stack ? 0 : 60, stack ? 76 : 58)}
				size={new UDim2(1, stack ? 0 : -230, 0, 6)}
			/>
			<frame
				key="RewardsTimedClaimActions"
				Size={stack ? new UDim2(1, 0, 0, TapTarget) : UDim2.fromOffset(150, 44)}
				Position={stack ? new UDim2(0, 0, 1, -(TapTarget + 4)) : new UDim2(1, -150, 0.5, -22)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
			>
				<Button
					text={timedReady ? "CLAIM" : nextTimed === undefined ? "DONE" : `IN ${clockText(nextTimed.Seconds - played)}`}
					icon="Timer.3"
					onClick={() => {
						if (nextTimed !== undefined) {
							dispatch("ClaimTimedReward", { Index: nextTimed.Index });
						}
					}}
					color={timedReady ? Palette.violet : Palette.panelSoft}
					textColor={timedReady ? Palette.ink : Palette.muted}
					size={UDim2.fromScale(1, 1)}
					reducedMotion={softMotion}
					disabled={!timedReady}
					highlight={timedReady}
				/>
			</frame>
		</Panel>
	);

	const columns = stack ? 2 : viewport.width >= 1200 ? 4 : 3;
	const timelineRows = math.max(1, math.ceil(timedEntries.size() / columns));
	const timelineH = 40 + timelineRows * 100;
	const timelinePanel = (
		<Panel
			size={UDim2.fromScale(1, 1)}
			accent={Palette.cyan}
			background={Palette.panel}
			padding={14}
			layoutOrder={3}
			reveal={streakReveal}
			reducedMotion={softMotion}
			clips={false}
		>
			<Text
				value={`TODAY'S PLAYTIME DROPS · ${clockText(played)} PLAYED`}
				size={11}
				color={Palette.cyan}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				sizeConstraint={new UDim2(1, 0, 0, 16)}
			/>
			<frame Size={new UDim2(1, 0, 1, -26)} Position={UDim2.fromOffset(0, 26)} BackgroundTransparency={1}>
				<TimedTimeline entries={timedEntries} played={played} dispatch={dispatch} columns={columns} reducedMotion={softMotion} />
			</frame>
		</Panel>
	);

	const shortcuts: Array<{ id: string; label: string; icon: string; accent: Color3; badge?: number }> = [
		{ id: "Wheel", label: "SPIN THE WHEEL", icon: "Wheel.3", accent: Palette.mango },
		{ id: "Missions", label: "MISSIONS", icon: "Mission.3", accent: Palette.green, badge: readyMissions },
		{ id: "Milestones", label: "MILESTONES", icon: "Milestone.2", accent: Palette.mango, badge: readyMilestones },
		{ id: "Boosts", label: "BOOSTS", icon: "Boost.9", accent: Palette.pink },
	];
	const shortcutCols = stack ? 2 : 4;
	const shortcutChildren: Record<string, React.Element> = {
		grid: (
			<uigridlayout
				CellSize={new UDim2(1 / shortcutCols, -math.ceil((8 * (shortcutCols - 1)) / shortcutCols), 0, TapTarget)}
				CellPadding={UDim2.fromOffset(8, 8)}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
		),
	};
	shortcuts.forEach((entry, index) => {
		shortcutChildren[entry.id] = (
			<ShortcutTile
				label={entry.label}
				icon={entry.icon}
				accent={entry.accent}
				badge={entry.badge}
				layoutOrder={index + 1}
				reducedMotion={softMotion}
				onClick={() => {
					if (navigate !== undefined) {
						navigate(entry.id);
					}
				}}
			/>
		);
	});
	const shortcutsH = math.ceil(shortcuts.size() / shortcutCols) * (TapTarget + 8);
	const shortcutsRow = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			{shortcutChildren}
		</frame>
	);

	// a running limited event sits right under the header; between events it's a one-line "next up"
	const eventH = eventPanelHeight(state.LimitedEvent, stack);
	const sections = [{ id: "header", height: heroH, element: headerPanel }];
	if (state.LimitedEvent !== undefined && eventH > 0) {
		sections.push({
			id: "event",
			height: eventH,
			element: (
				<EventPanel state={state.LimitedEvent} dispatch={dispatch as unknown as EventDispatch} stack={stack} reducedMotion={softMotion} />
			),
		});
	}
	sections.push(
		{ id: "daily", height: dailyCardH, element: dailyPanel },
		{ id: "timed", height: timedCardH, element: timedPanel },
	);
	if (timedEntries.size() > 0) {
		sections.push({ id: "timeline", height: timelineH, element: timelinePanel });
	}
	// group, like goals and the notification prompt sit with the other free rewards
	if (state.Community !== undefined && community.height > 0) {
		sections.push({
			id: "community",
			height: community.height,
			element: (
				<CommunityPanel
					state={state.Community}
					dispatch={dispatch as unknown as CommunityDispatch}
					stack={stack}
					canNotify={community.canNotify}
					promptNotify={community.promptNotify}
					reducedMotion={softMotion}
				/>
			),
		});
	}
	if (navigate !== undefined) {
		sections.push({ id: "shortcuts", height: shortcutsH, element: shortcutsRow });
	}
	return <PageScaffold gap={12} tailPad={rewardsTail} scrollBarColor={Palette.pink} scrollBarThickness={4} sections={sections} />;
}
