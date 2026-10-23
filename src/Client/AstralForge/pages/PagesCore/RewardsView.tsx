// Rewards, ported from design/15-rewards (desktop.html 1920x1080, phone.html 844x390).
// Desktop: "This week" panel with the 7-day strip (12px gap, column rows, today ringed in mango with
// a Claim button), then a row of two equal panels: Playtime gifts (icon well, minutes, time left)
// and Codes (code field + Redeem, one muted note). Phone: the strip at 4 per row, panels stacked.
// The limited event, community rewards and the reward shortcuts follow underneath, as before.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, formatReward, Reward } from "../../CoreKit/format";
import { chromeFor, Palette } from "../../CoreKit/theme";
import { useStagger, useViewport } from "../../MotionKit/motion";
import { Button } from "../../UiCore/ui";
import { BODY, BODY_BOLD, Glyph, Line, MockPanel, PanelHeading, RowSurface } from "../../UiCore/mockKit";
import { Flex, GcRow, GcScroll, Note, rowH } from "../gcKit";
import { CommunityDispatch, CommunityPanel, CommunityState, useCommunityRewards } from "./CommunityPanel";
import { EventDispatch, EventPanel, eventPanelHeight, EventState } from "./EventPanel";

const UserInputService = game.GetService("UserInputService");

type Reply = (response: { ok?: boolean; message?: string }) => void;
type Dispatch = (action: string, payload?: object, callback?: Reply) => unknown;

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

function readyTask(entry: unknown): boolean {
	if (!typeIs(entry, "table")) return false;
	const item = entry as ClaimableTask;
	return !item.Claimed && (tonumber(item.Progress) ?? 0) >= (tonumber(item.Target) ?? math.huge);
}

/** The glyph the strip shows for a reward: its biggest part. */
export function rewardGlyph(reward: Reward | undefined): string {
	if (reward === undefined) return "Gift";
	if (reward.Keys !== undefined && next(reward.Keys)[0] !== undefined) return "Crate";
	if ((reward.Cores ?? 0) > 0) return "Core";
	if ((reward.Stardust ?? 0) > 0) return "Dust";
	if ((reward.Signals ?? 0) > 0) return "Wave";
	if ((reward.FreeSpins ?? 0) > 0) return "Wheel";
	if ((reward.Cash ?? 0) > 0 || (reward.CashMinutes ?? 0) > 0) return "Flux";
	return "Gift";
}

function minutesText(seconds: number): string {
	const m = math.floor(seconds / 60);
	if (m >= 60 && m % 60 === 0) return `${m / 60} ${m === 60 ? "hour" : "hours"}`;
	return `${m} minutes`;
}

// .row column cell: lbl "Day n", 20px glyph, 700 15px reward, then a check (claimed) or Claim (today)
function DayCell(p: {
	day: number;
	reward?: Reward;
	claimed: boolean;
	today: boolean;
	phone: boolean;
	order: number;
	claim: () => void;
	claimRef?: React.MutableRefObject<Frame | undefined>;
	reducedMotion?: boolean;
}) {
	const text = formatReward(p.reward);
	return (
		<frame BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={p.order}>
			<RowSurface />
			{p.claimed && <uigradient Transparency={new NumberSequence(0.55)} />}
			{p.today && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2}>
					<uicorner CornerRadius={new UDim(0, 11)} />
					<uistroke Color={Palette.mango} Thickness={2} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				</frame>
			)}
			<uipadding PaddingTop={new UDim(0, 14)} PaddingBottom={new UDim(0, 14)} PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} />
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} Padding={new UDim(0, 8)} HorizontalAlignment={Enum.HorizontalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Line text={`DAY ${p.day}`} size={11} color={Palette.muted} layoutOrder={0} />
			<Glyph kind={rewardGlyph(p.reward)} size={20} color={p.today ? Palette.mango : Palette.cream} layoutOrder={1} />
			<Line text={text !== "" ? text : "-"} size={15} font={BODY_BOLD} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} layoutOrder={2} />
			{p.claimed && <Glyph kind="Check" size={20} color={Palette.muted} layoutOrder={3} />}
			{p.today && (
				<frame Size={UDim2.fromOffset(0, 36)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3} ref={p.claimRef}>
					<Button text="Claim" onClick={p.claim} color={Palette.mango} textColor={Color3.fromRGB(27, 15, 8)} hug={true} size={UDim2.fromOffset(0, 36)} reducedMotion={p.reducedMotion} highlight={true} />
				</frame>
			)}
		</frame>
	);
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
	const phone = chrome.stack;
	const daily = state.Daily ?? {};
	const dailyReady = daily.CanClaim === true;
	const timedEntries = state.TimedRewards?.Rewards ?? [];
	const played = tonumber(state.TimedRewards?.PlaySeconds) ?? 0;
	const weekReveal = useStagger(0, reducedMotion);
	const giftsReveal = useStagger(1, reducedMotion);
	const codesReveal = useStagger(2, reducedMotion);
	const community = useCommunityRewards(state.Community, phone);
	const claimRef = React.useRef<Frame>();

	React.useEffect(() => {
		if (!dailyReady || !UserInputService.GamepadEnabled) return undefined;
		const host = claimRef.current;
		if (host === undefined) return undefined;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [dailyReady]);

	// --- This week ---------------------------------------------------------------------------
	const rewards = daily.Rewards ?? [];
	const count = math.max(1, rewards.size());
	const current = math.max(1, dailyReady ? (tonumber(daily.NextStreak) ?? 1) : (tonumber(daily.Streak) ?? 0));
	const weekStart = math.floor((current - 1) / 7) * 7 + 1;
	const cols = phone ? 4 : 7;
	const cellH = phone ? 138 : 152;
	const gridRows = math.ceil(7 / cols);
	const gap = 12;
	const days: React.Element[] = [];
	for (let offset = 0; offset < 7; offset++) {
		const day = weekStart + offset;
		days.push(
			<DayCell
				key={`d${day}`}
				day={day - weekStart + 1}
				reward={rewards[(day - 1) % count]}
				claimed={day < current || (day === current && !dailyReady)}
				today={day === current && dailyReady}
				phone={phone}
				order={offset}
				claim={() => dispatch("ClaimDaily")}
				claimRef={day === current ? claimRef : undefined}
				reducedMotion={reducedMotion}
			/>,
		);
	}
	const weekGridH = gridRows * cellH + (gridRows - 1) * gap;
	const weekPanelH = (phone ? 20 : 36) + (phone ? 18 : 22) + 12 + weekGridH;
	const weekPanel = (
		<MockPanel size={new UDim2(1, 0, 0, weekPanelH)} phone={phone} layoutOrder={0} reveal={weekReveal} reducedMotion={reducedMotion} name="RewardsWeek">
			<PanelHeading icon="Calendar" title="This week" note={`Day ${math.min(current - weekStart + 1, 7)} of 7`} phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, weekGridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uigridlayout
					CellSize={new UDim2(1 / cols, -math.ceil((gap * (cols - 1)) / cols), 0, cellH)}
					CellPadding={UDim2.fromOffset(gap, gap)}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				{days}
			</frame>
		</MockPanel>
	);

	// --- Playtime gifts ------------------------------------------------------------------------
	const giftRows = timedEntries.map((entry, i) => {
		const seconds = tonumber(entry.Seconds) ?? 0;
		const ready = !entry.Claimed && played >= seconds;
		const locked = !entry.Claimed && !ready && i > 0 && !(timedEntries[i - 1].Claimed === true || played >= (tonumber(timedEntries[i - 1].Seconds) ?? 0));
		const reward = formatReward(entry.Reward);
		return (
			<GcRow
				key={`t${entry.Index ?? i + 1}`}
				phone={phone}
				layoutOrder={i + 1}
				icon={entry.Claimed ? "Check" : locked ? "Lock" : "Timer"}
				title={minutesText(seconds)}
				sub={reward !== "" ? reward : undefined}
				value={entry.Claimed ? "Claimed" : ready ? undefined : clockText(seconds - played)}
				right={
					ready ? (
						<Button
							text="Claim"
							onClick={() => dispatch("ClaimTimedReward", { Index: entry.Index })}
							color={Palette.mango}
							textColor={Color3.fromRGB(27, 15, 8)}
							hug={true}
							size={UDim2.fromOffset(0, 36)}
							reducedMotion={reducedMotion}
							highlight={true}
						/>
					) : undefined
				}
			/>
		);
	});
	const rowGap = phone ? 0 : 4;
	const rh = rowH(phone) + rowGap;
	const listH = (n: number) => n * rh + math.max(0, n - 1) * (phone ? 8 : 12);
	const giftsH = (phone ? 20 : 36) + (phone ? 18 : 22) + (phone ? 8 : 12) + listH(math.max(1, timedEntries.size()));

	// --- Codes ---------------------------------------------------------------------------------
	const [code, setCode] = React.useState("");
	const [codeNote, setCodeNote] = React.useState("New codes drop with each update.");
	const redeem = () => {
		const trimmed = code.gsub("^%s+", "")[0].gsub("%s+$", "")[0];
		if (trimmed === "") return;
		setCodeNote("Checking code…");
		dispatch("RedeemCode", { Code: trimmed }, (response) => {
			if (response.ok === true) setCode("");
			setCodeNote(response.message ?? (response.ok === true ? "Code claimed." : "That code didn't work."));
		});
	};
	const codesH = (phone ? 20 : 36) + (phone ? 18 : 22) + (phone ? 8 : 12) * 2 + rowH(phone) + 18;
	const codeField = (
		<frame Size={new UDim2(1, 0, 0, rowH(phone))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, phone ? 8 : 18)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={new UDim2(0, 0, 1, 0)} BackgroundColor3={Palette.white} BorderSizePixel={0} LayoutOrder={0}>
				<uiflexitem FlexMode={Enum.UIFlexMode.Fill} />
				<RowSurface />
				<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
				<Glyph kind="Code" size={20} color={Palette.muted} position={new UDim2(0, 0, 0.5, -10)} />
				<textbox
					Size={new UDim2(1, -32, 1, 0)}
					Position={UDim2.fromOffset(32, 0)}
					BackgroundTransparency={1}
					Text={code}
					PlaceholderText="Enter a code"
					PlaceholderColor3={Palette.muted}
					TextColor3={Palette.cream}
					TextSize={phone ? 13 : 15}
					FontFace={BODY}
					TextXAlignment={Enum.TextXAlignment.Left}
					ClearTextOnFocus={false}
					Change={{ Text: (rbx) => setCode(rbx.Text) }}
					Event={{ FocusLost: (_, enter) => (enter ? redeem() : undefined) }}
				/>
			</frame>
			<frame Size={UDim2.fromOffset(0, 44)} AutomaticSize={Enum.AutomaticSize.X} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<Button text="Redeem" onClick={redeem} color={Palette.mango} textColor={Color3.fromRGB(27, 15, 8)} hug={true} size={UDim2.fromOffset(0, 44)} reducedMotion={reducedMotion} />
			</frame>
		</frame>
	);

	const sideBySide = !phone;
	const pairH = sideBySide ? math.max(giftsH, codesH) : giftsH + 8 + codesH;
	const pair = (
		<Flex dir={sideBySide ? "row" : "col"} phone={phone} size={new UDim2(1, 0, 0, pairH)} layoutOrder={1}>
			<MockPanel size={sideBySide ? new UDim2(0, 0, 1, 0) : new UDim2(1, 0, 0, giftsH)} flex={sideBySide} phone={phone} layoutOrder={0} reveal={giftsReveal} reducedMotion={reducedMotion} name="RewardsPlaytime">
				<PanelHeading icon="Timer" title="Playtime gifts" note={clockText(played)} phone={phone} layoutOrder={0} />
				{giftRows.size() > 0 ? giftRows : <Note text="No playtime gifts right now." phone={phone} layoutOrder={1} />}
			</MockPanel>
			<MockPanel size={sideBySide ? new UDim2(0, 0, 1, 0) : new UDim2(1, 0, 0, codesH)} flex={sideBySide} phone={phone} layoutOrder={1} reveal={codesReveal} reducedMotion={reducedMotion} name="RewardsCodes">
				<PanelHeading icon="Code" title="Codes" phone={phone} layoutOrder={0} />
				{codeField}
				<Note text={codeNote} phone={phone} layoutOrder={2} />
			</MockPanel>
		</Flex>
	);

	// --- what was on the page before the port stays reachable underneath -----------------------
	const eventH = eventPanelHeight(state.LimitedEvent, phone);
	let readyMissions = 0;
	for (const quest of (typeIs(state.Quests, "table") ? state.Quests : []) as unknown[]) if (readyTask(quest)) readyMissions += 1;
	let readyMilestones = 0;
	for (const a of state.Achievements ?? []) if (readyTask(a)) readyMilestones += 1;
	const shortcuts: Array<{ id: string; label: string; icon: string; badge?: number }> = [
		{ id: "Missions", label: "Missions", icon: "Mission", badge: readyMissions },
		{ id: "Milestones", label: "Milestones", icon: "Milestone", badge: readyMilestones },
		{ id: "Wheel", label: "Wheel", icon: "Wheel" },
		{ id: "Boosts", label: "Boosts", icon: "Boost" },
	];

	return (
		<GcScroll phone={phone} name="RewardsPage" tail={chrome.bottomSafe + (phone ? 10 : 24)}>
			{weekPanel}
			{pair}
			{state.LimitedEvent !== undefined && eventH > 0 && (
				<frame Size={new UDim2(1, 0, 0, eventH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<EventPanel state={state.LimitedEvent} dispatch={dispatch as unknown as EventDispatch} stack={phone} reducedMotion={reducedMotion} />
				</frame>
			)}
			{state.Community !== undefined && community.height > 0 && (
				<frame Size={new UDim2(1, 0, 0, community.height)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
					<CommunityPanel
						state={state.Community}
						dispatch={dispatch as unknown as CommunityDispatch}
						stack={phone}
						canNotify={community.canNotify}
						promptNotify={community.promptNotify}
						reducedMotion={reducedMotion}
					/>
				</frame>
			)}
			{navigate !== undefined && (
				<frame Size={new UDim2(1, 0, 0, 44)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={4}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, phone ? 8 : 12)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{shortcuts.map((s, i) => (
						<frame key={s.id} Size={new UDim2(0.25, phone ? -6 : -9, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={i}>
							<Button
								text={s.badge !== undefined && s.badge > 0 ? `${s.label} · ${s.badge}` : s.label}
								icon={s.icon}
								onClick={() => navigate(s.id)}
								color={s.badge !== undefined && s.badge > 0 ? Palette.mango : undefined}
								textColor={s.badge !== undefined && s.badge > 0 ? Color3.fromRGB(27, 15, 8) : undefined}
								size={UDim2.fromScale(1, 1)}
								reducedMotion={reducedMotion}
							/>
						</frame>
					))}
				</frame>
			)}
		</GcScroll>
	);
}
