// Rewards + Daily, rebuilt on Forge2. One counter up top (what's waiting, or time to the UTC
// reset), the week's streak as seven plates, the next playtime drop on a charging bar, every drop
// laid out below, then the live event, community goals and the four hops to the other free stuff.
// Same remotes as before: ClaimDaily, ClaimTimedReward {Index}, EventAct {Op, Item},
// ClaimCommunityReward {Kind, Index}.
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { clockText, formatReward, Reward } from "../../CoreKit/format";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { taskFilterCounts } from "../../CoreKit/taskFilter";
import { useChangePop, useFlash, useGlowStroke, useListStagger, useStagger } from "../../MotionKit/motion";
import * as LimitedEvents from "../../../../Shared/AstralForge/Shared/LimitedEvents";
import { PressButton as Button } from "../design/PressButton";
import { Meter, Panel } from "../design/Panel";
import { Chip } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

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
interface Task {
	Claimed: boolean;
	Progress: number;
	Target: number;
}
interface CommunityState {
	GroupId?: number;
	GroupName?: string;
	GroupClaimed?: boolean;
	GroupReward?: Reward;
	Likes?: number;
	LikeGoals?: { Index: number; Likes: number; Reward?: Reward; Claimed?: boolean }[];
	NotifyRewardEnabled?: boolean;
	NotifyClaimed?: boolean;
	NotifyReward?: Reward;
}
interface EventState {
	Id?: string;
	Tokens?: number;
	DayEarned?: number;
	Bought?: Record<string, number>;
	NextId?: string;
}
interface RewardsSession {
	Daily?: DailyState;
	TimedRewards?: { Rewards?: TimedEntry[]; PlaySeconds?: number };
	Quests?: unknown;
	Achievements?: unknown;
	Community?: CommunityState;
	LimitedEvent?: EventState;
}

function tasks(raw: unknown): Task[] {
	const out: Task[] = [];
	if (!typeIs(raw, "table")) return out;
	for (const [, entry] of pairs(raw as Record<string, unknown>)) {
		if (typeIs(entry, "table")) {
			const t = entry as Partial<Task>;
			out.push({ Claimed: t.Claimed === true, Progress: tonumber(t.Progress) ?? 0, Target: tonumber(t.Target) ?? math.huge });
		}
	}
	return out;
}

/** Server time, refreshed every `period` seconds. */
function useServerNow(period: number): number {
	const [now, setNow] = React.useState(() => Workspace.GetServerTimeNow());
	React.useEffect(() => {
		let alive = true;
		task.spawn(() => {
			while (alive) {
				task.wait(period);
				if (alive) setNow(Workspace.GetServerTimeNow());
			}
		});
		return () => {
			alive = false;
		};
	}, [period]);
	return now;
}

function shortClock(seconds: number): string {
	const total = math.max(0, math.floor(seconds));
	const days = math.floor(total / 86400);
	const hours = math.floor((total % 86400) / 3600);
	const minutes = math.floor((total % 3600) / 60);
	if (days > 0) return `${days}d ${hours}h`;
	if (hours > 0) return `${hours}h ${minutes}m`;
	return `${math.max(1, minutes)}m`;
}

/** A gamepad lands on the ref'd claim the moment one becomes ready. */
function useClaimFocus(ready: boolean, key: unknown): React.MutableRefObject<Frame | undefined> {
	const ref = React.useRef<Frame>();
	React.useEffect(() => {
		if (!ready || !UserInputService.GamepadEnabled) return undefined;
		const job = task.defer(() => {
			const host = ref.current;
			if (host !== undefined && host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [ready, key]);
	return ref;
}

function Row(props: { order: number; gap?: number; children?: React.ReactNode; wrap?: boolean }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout
				FillDirection={Enum.FillDirection.Horizontal}
				Wraps={props.wrap !== false}
				Padding={new UDim(0, props.gap ?? 10)}
				VerticalAlignment={Enum.VerticalAlignment.Center}
				SortOrder={Enum.SortOrder.LayoutOrder}
			/>
			{props.children}
		</frame>
	);
}

// ── the week ────────────────────────────────────────────────────────────────────────────────

function DayPlate(props: { day: number; reward?: Reward; claimed: boolean; today: boolean; phone: boolean; index: number; width: UDim2 }) {
	const rise = useListStagger(props.index);
	const glow = useGlowStroke(props.today, false, 0.6);
	const height = props.phone ? 64 : 84;
	return (
		<frame Size={new UDim2(props.width.X.Scale, props.width.X.Offset, 0, height)} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame
				Size={UDim2.fromScale(1, 1)}
				Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 12))}
				BackgroundColor3={props.today ? Iron.raised() : Iron.sunk()}
				BackgroundTransparency={props.claimed ? 0.5 : 0}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, Corner.card)} />
				<uistroke Color={props.today ? Iron.brass() : Iron.edge()} Transparency={props.today ? glow : 0.7} Thickness={props.today ? 2 : 1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				<Text
					text={tostring(props.day)}
					size={props.today ? (props.phone ? 20 : 26) : props.phone ? 16 : 20}
					font={Fonts.heavy}
					color={props.today ? Iron.brass() : props.claimed ? Iron.muted() : Iron.soft()}
					align="Center"
					box={new UDim2(1, 0, 0, props.phone ? 24 : 32)}
					position={UDim2.fromOffset(0, 6)}
				/>
				<Text
					text={props.claimed ? "✓" : formatReward(props.reward)}
					size={Type.small(props.phone)}
					color={props.claimed ? Iron.muted() : Iron.text()}
					align="Center"
					minSize={8}
					box={new UDim2(1, -8, 0, props.phone ? 26 : 34)}
					position={new UDim2(0, 4, 1, props.phone ? -32 : -42)}
				/>
			</frame>
		</frame>
	);
}

function Week(props: { daily: DailyState; phone: boolean; order: number }) {
	const daily = props.daily;
	const rewards = daily.Rewards ?? [];
	const count = math.max(1, rewards.size());
	const canClaim = daily.CanClaim === true;
	const current = math.max(1, canClaim ? (tonumber(daily.NextStreak) ?? 1) : (tonumber(daily.Streak) ?? 0));
	const start = math.floor((current - 1) / 7) * 7 + 1;
	const spacing = props.phone ? 4 : 10;
	const plates: React.Element[] = [];
	for (let offset = 0; offset < 7; offset++) {
		const day = start + offset;
		plates.push(
			<DayPlate
				key={`d${day}`}
				day={day}
				reward={rewards[(day - 1) % count]}
				claimed={day < current || (day === current && !canClaim)}
				today={day === current && canClaim}
				phone={props.phone}
				index={offset}
				width={new UDim2(1 / 7, -math.ceil((spacing * 6) / 7), 0, 0)}
			/>,
		);
	}
	return (
		<Row order={props.order} gap={spacing} wrap={false}>
			{plates}
		</Row>
	);
}

// ── playtime drops ──────────────────────────────────────────────────────────────────────────

function DropCell(props: { entry: TimedEntry; played: number; phone: boolean; index: number; onClaim: (entry: TimedEntry) => void; width: UDim2 }) {
	const { entry, played } = props;
	const rise = useListStagger(props.index);
	const seconds = tonumber(entry.Seconds) ?? 0;
	const claimed = entry.Claimed === true;
	const ready = !claimed && played >= seconds;
	return (
		<frame Size={new UDim2(props.width.X.Scale, props.width.X.Offset, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<uiscale Scale={rise.map((p) => 0.95 + p * 0.05)} />
			<Panel pad={gap(props.phone, "m")} spacing={gap(props.phone, "s")} color={ready ? Iron.raised() : Iron.sunk()} seam={ready} rarity="Epic">
				<Text text={claimed || ready ? clockText(seconds) : clockText(seconds - played)} size={Type.small(props.phone)} color={ready ? Iron.brass() : Iron.muted()} font={Fonts.heavy} order={0} />
				<Text text={formatReward(entry.Reward)} size={Type.body(props.phone)} color={claimed ? Iron.muted() : Iron.text()} font={Fonts.heavy} order={1} />
				{ready ? (
					<Button text="Claim" onPress={() => props.onClaim(entry)} stretch order={2} />
				) : (
					<Meter value={claimed ? 1 : played / math.max(1, seconds)} color={claimed ? Iron.muted() : Iron.steel()} height={6} order={2} />
				)}
			</Panel>
		</frame>
	);
}

// ── event + community ───────────────────────────────────────────────────────────────────────

function rgb(c: [number, number, number]): Color3 {
	return Color3.fromRGB(c[0], c[1], c[2]);
}

interface Line {
	key: string;
	title: string;
	detail: string;
	button: string;
	ready: boolean;
	accent: Color3;
	onPress: () => void;
}

function LineCard(props: { line: Line; index: number; phone: boolean; pending: boolean; refusedToken: number }) {
	const rise = useListStagger(props.index);
	const shake = useFlash(props.refusedToken, false, 0.35);
	const line = props.line;
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.index}>
			<frame
				Size={new UDim2(1, 0, 0, 0)}
				AutomaticSize={Enum.AutomaticSize.Y}
				BackgroundTransparency={1}
				Position={React.joinBindings([rise, shake]).map(([p, s]) => UDim2.fromOffset(math.sin(s * math.pi * 6) * s * 6, (1 - p) * 10))}
			>
				<Panel pad={gap(props.phone, "m")} spacing={gap(props.phone, "s")} color={Iron.sunk()} layout={props.phone ? "column" : "row"}>
					<frame Size={new UDim2(1, props.phone ? 0 : -170, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
						<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Text text={line.title} size={Type.body(props.phone)} font={Fonts.heavy} color={Iron.text().Lerp(line.accent, 0.25)} order={0} />
						<Text text={line.detail} size={Type.small(props.phone)} color={Iron.soft()} multiline order={1} />
					</frame>
					{props.phone ? (
						<Button text={line.button} onPress={line.onPress} disabled={!line.ready} busy={props.pending} stretch tone={line.ready ? "brass" : "iron"} order={1} />
					) : (
						<Button text={line.button} onPress={line.onPress} disabled={!line.ready} busy={props.pending} width={150} tone={line.ready ? "brass" : "iron"} order={1} />
					)}
				</Panel>
			</frame>
		</frame>
	);
}

/** One-shot claims with a pending lock and a refusal shake, shared by the event shop and community goals. */
function usePendingClaims(request: PageProps["request"]) {
	const [pending, setPending] = React.useState<string | undefined>(undefined);
	const [refused, setRefused] = React.useState<{ key: string; token: number }>({ key: "", token: 0 });
	const run = (key: string, action: string, payload: Record<string, unknown>, color: Color3) => {
		if (pending !== undefined) return;
		setPending(key);
		const fallback = task.delay(8, () => setPending(undefined));
		request(action, payload, (reply) => {
			pcall(task.cancel, fallback);
			setPending(undefined);
			if (reply.ok === true) {
				Burst.spark(color, 0.9);
				MotionFX.play("success");
			} else {
				setRefused((current) => ({ key, token: current.token + 1 }));
			}
		});
	};
	return $tuple(pending, refused, run);
}

function EventBlock(props: { state: EventState; phone: boolean; request: PageProps["request"]; order: number }) {
	const now = useServerNow(30);
	const [pending, refused, run] = usePendingClaims(props.request);
	const event = LimitedEvents.byId(props.state.Id);
	if (event === undefined) {
		const upcoming = LimitedEvents.byId(props.state.NextId);
		if (upcoming === undefined) return undefined;
		return (
			<Panel pad={gap(props.phone, "l")} spacing={4} order={props.order} color={Iron.sunk()}>
				<Text text={upcoming.Name} size={Type.body(props.phone)} font={Fonts.heavy} color={rgb(upcoming.Accent)} order={0} />
				<Text text={`opens in ${shortClock(upcoming.StartsAt - now)}`} size={Type.small(props.phone)} color={Iron.muted()} order={1} />
			</Panel>
		);
	}
	const accent = rgb(event.Accent);
	const tokens = props.state.Tokens ?? 0;
	const bought = props.state.Bought ?? {};
	const dayEarned = props.state.DayEarned ?? 0;
	const token = event.Token.lower();
	const lines: Line[] = event.Shop.map((item) => {
		const left = math.max(0, item.Stock - (bought[item.Id] ?? 0));
		return {
			key: item.Id,
			title: item.Name,
			detail: `${formatReward(item.Reward as Reward)}  ·  ${left}/${item.Stock}`,
			button: left <= 0 ? "Sold out" : `${item.Price} ${token}`,
			ready: left > 0 && tokens >= item.Price,
			accent,
			onPress: () => run(item.Id, "EventAct", { Op: "Buy", Item: item.Id }, accent),
		};
	});
	return (
		<Panel pad={gap(props.phone, "l")} spacing={gap(props.phone, "m")} order={props.order} seam rarity="Mythic">
			<Title text={event.Name} size={Type.title(props.phone)} color={Iron.text().Lerp(accent, 0.35)} tags={["wave"]} order={0} />
			<Text text={event.Blurb} size={Type.small(props.phone)} color={Iron.soft()} multiline order={1} />
			<Row order={2} gap={gap(props.phone, "l")}>
				<Text text={`${tokens} ${token}`} size={Type.body(props.phone)} font={Fonts.heavy} color={accent} box={UDim2.fromOffset(140, Type.body(props.phone) + 6)} order={0} />
				<Text text={`${math.min(dayEarned, event.DailyCap)}/${event.DailyCap} today`} size={Type.small(props.phone)} color={Iron.muted()} box={UDim2.fromOffset(130, 18)} order={1} />
				<Text text={shortClock(event.EndsAt - now)} size={Type.small(props.phone)} color={Iron.muted()} box={UDim2.fromOffset(90, 18)} order={2} />
			</Row>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
				<uilistlayout Padding={new UDim(0, gap(props.phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
				{lines.map((line, i) => (
					<LineCard key={line.key} line={line} index={i} phone={props.phone} pending={pending === line.key} refusedToken={refused.key === line.key ? refused.token : 0} />
				))}
			</frame>
		</Panel>
	);
}

// can this player be shown Roblox's notification prompt? (13+, not opted in, not asked in 30 days)
function useNotifyPrompt(): LuaTuple<[boolean, () => void]> {
	const [can, setCan] = React.useState(false);
	React.useEffect(() => {
		let alive = true;
		const job = task.spawn(() => {
			const [found, service] = pcall(() => game.GetService("ExperienceNotificationService"));
			if (!found || service === undefined) return;
			const [ok, eligible] = pcall(() => service.CanPromptOptInAsync());
			if (alive && ok && eligible === true) setCan(true);
		});
		return () => {
			alive = false;
			pcall(task.cancel, job);
		};
	}, []);
	const prompt = () => {
		pcall(() => game.GetService("ExperienceNotificationService").PromptOptIn());
		setCan(false);
	};
	return $tuple(can, prompt);
}

function CommunityBlock(props: { state: CommunityState; phone: boolean; request: PageProps["request"]; order: number }) {
	const [canNotify, promptNotify] = useNotifyPrompt();
	const [pending, refused, run] = usePendingClaims(props.request);
	const state = props.state;
	const lines: Line[] = [];
	if ((state.GroupId ?? 0) > 0) {
		const claimed = state.GroupClaimed === true;
		const name = state.GroupName ?? "the group";
		lines.push({
			key: "group",
			title: claimed ? name : `Join ${name}`,
			detail: claimed ? "Thanks for joining." : formatReward(state.GroupReward),
			button: claimed ? "Claimed" : "Check & claim",
			ready: !claimed,
			accent: Iron.steel(),
			onPress: () => run("group", "ClaimCommunityReward", { Kind: "Group", Index: 1 }, Iron.steel()),
		});
	}
	const likes = state.Likes ?? 0;
	const goals = state.LikeGoals ?? [];
	if (goals.size() > 0) {
		const open = goals.find((goal) => goal.Claimed !== true);
		const reached = open !== undefined && likes >= open.Likes;
		lines.push({
			key: "likes",
			title: open === undefined ? `${likes} likes` : `${open.Likes} likes`,
			detail: open === undefined ? "Every goal claimed. Thank you." : reached ? formatReward(open.Reward) : `${likes} so far. A like gets us closer.`,
			button: open === undefined ? "Done" : reached ? "Claim" : "Not yet",
			ready: reached,
			accent: Iron.ember(),
			onPress: () => {
				if (open !== undefined) run("likes", "ClaimCommunityReward", { Kind: "Like", Index: open.Index }, Iron.ember());
			},
		});
	}
	if (canNotify) {
		const paid = state.NotifyRewardEnabled === true && state.NotifyClaimed !== true;
		lines.push({
			key: "notify",
			title: "Notifications",
			detail: paid ? formatReward(state.NotifyReward) : "Hear when the vault fills or an event opens.",
			button: "Turn on",
			ready: true,
			accent: Iron.brass(),
			onPress: () => {
				promptNotify();
				if (paid) run("notify", "ClaimCommunityReward", { Kind: "Notify", Index: 1 }, Iron.brass());
			},
		});
	}
	if (lines.size() === 0) return undefined;
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout Padding={new UDim(0, gap(props.phone, "s"))} SortOrder={Enum.SortOrder.LayoutOrder} />
			{lines.map((line, i) => (
				<LineCard key={line.key} line={line} index={i} phone={props.phone} pending={pending === line.key} refusedToken={refused.key === line.key ? refused.token : 0} />
			))}
		</frame>
	);
}

// ── page ────────────────────────────────────────────────────────────────────────────────────

export function RewardsPage(props: PageProps) {
	const s = props.session as unknown as RewardsSession;
	const phone = props.phone;
	const daily = s.Daily ?? {};
	const dailyReady = daily.CanClaim === true;
	const entries = s.TimedRewards?.Rewards ?? [];
	const played = tonumber(s.TimedRewards?.PlaySeconds) ?? 0;
	let nextDrop: TimedEntry | undefined;
	const readyDrops: TimedEntry[] = [];
	for (const entry of entries) {
		if (entry.Claimed === true) continue;
		if (nextDrop === undefined) nextDrop = entry;
		if (played >= (tonumber(entry.Seconds) ?? math.huge)) readyDrops.push(entry);
	}
	const nextReady = nextDrop !== undefined && played >= nextDrop.Seconds;
	const readyCount = (dailyReady ? 1 : 0) + readyDrops.size();
	const now = useServerNow(1);
	const resetIn = 86400 - (math.floor(now) % 86400);
	const todaysReward = daily.RewardIndex !== undefined ? (daily.Rewards ?? [])[daily.RewardIndex - 1] : undefined;
	const missionsReady = taskFilterCounts(tasks(s.Quests)).Ready;
	const milestonesReady = taskFilterCounts(tasks(s.Achievements)).Ready;

	const [claims, setClaims] = React.useState(0);
	const heroFlash = useFlash(claims, false, 0.42);
	const heroIn = useStagger(0);
	const counter = readyCount > 0 ? tostring(readyCount) : shortClock(resetIn);
	const counterPop = useChangePop(counter, false, 0.12);
	const focus = useClaimFocus(readyCount > 0, `${dailyReady}${readyDrops.size()}`);

	const celebrate = (reward: Reward | undefined) => {
		setClaims((n) => n + 1);
		Burst.gain(formatReward(reward), Iron.brass(), "Gift.2");
		Audio.play("collect");
	};
	const claimDaily = () => {
		if (!dailyReady) return;
		celebrate(todaysReward);
		props.request("ClaimDaily", {}, (reply) => reply.ok === true && MotionFX.play("success"));
	};
	const claimDrop = (entry: TimedEntry) => {
		celebrate(entry.Reward);
		props.request("ClaimTimedReward", { Index: entry.Index }, (reply) => reply.ok === true && MotionFX.play("confirm"));
	};
	const claimAll = () => {
		if (dailyReady) claimDaily();
		for (const entry of readyDrops) claimDrop(entry);
		MotionFX.play("milestone");
	};

	const space = gap(phone, "l");
	const columns = phone ? 2 : 4;
	const cellGap = gap(phone, "s");
	return (
		<scrollingframe
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			ScrollBarThickness={phone ? 0 : 4}
			ScrollBarImageColor3={Iron.brassDeep()}
		>
			<uipadding PaddingTop={new UDim(0, space)} PaddingBottom={new UDim(0, space * 3)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
			<uilistlayout Padding={new UDim(0, space)} SortOrder={Enum.SortOrder.LayoutOrder} />

			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={gap(phone, "xl")} spacing={gap(phone, "m")} seam={readyCount > 0} scale={heroFlash.map((v) => 1 + v * 0.02)}>
					<Title text="Free rewards" size={Type.title(phone)} tags={["wave"]} order={0} />
					<frame Size={new UDim2(1, 0, 0, Type.hero(phone) + 8)} BackgroundTransparency={1} LayoutOrder={1}>
						<uiscale Scale={counterPop} />
						<Text text={counter} size={Type.hero(phone)} font={Fonts.heavy} color={readyCount > 0 ? Iron.brass() : Iron.soft()} box={UDim2.fromScale(1, 1)} />
					</frame>
					{readyCount > 0 && (
						<frame ref={focus} Size={new UDim2(1, 0, 0, HIT + 8)} BackgroundTransparency={1} LayoutOrder={2}>
							<Button text="Claim all" onPress={claimAll} width={phone ? 180 : 220} height={phone ? 52 : 56} textSize={20} />
						</frame>
					)}
				</Panel>
			</frame>

			{s.LimitedEvent !== undefined && <EventBlock state={s.LimitedEvent} phone={phone} request={props.request} order={1} />}

			<Panel pad={gap(phone, "l")} spacing={gap(phone, "l")} order={2} seam={dailyReady}>
				<Row order={0} gap={gap(phone, "m")}>
					<frame Size={new UDim2(1, phone ? 0 : -190, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
						<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
						<Title text={`Day ${math.max(1, dailyReady ? (daily.NextStreak ?? 1) : (daily.Streak ?? 1))}`} size={Type.title(phone)} order={0} />
						<Text text={formatReward(todaysReward)} size={Type.body(phone)} color={dailyReady ? Iron.brass() : Iron.muted()} font={Fonts.heavy} order={1} />
					</frame>
					<Button
						text={dailyReady ? "Claim" : shortClock(resetIn)}
						onPress={claimDaily}
						disabled={!dailyReady}
						width={phone ? 160 : 170}
						height={52}
						textSize={19}
						order={1}
					/>
				</Row>
				<Week daily={daily} phone={phone} order={1} />
			</Panel>

			{entries.size() > 0 && (
				<Panel pad={gap(phone, "l")} spacing={gap(phone, "l")} order={3} seam={nextReady} rarity="Epic">
					<Row order={0} gap={gap(phone, "m")}>
						<frame Size={new UDim2(1, phone ? 0 : -190, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
							<uilistlayout Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Title text={clockText(played)} size={Type.title(phone)} order={0} />
							<Text text={nextDrop !== undefined ? formatReward(nextDrop.Reward) : "All dropped"} size={Type.body(phone)} color={nextReady ? Iron.brass() : Iron.muted()} font={Fonts.heavy} order={1} />
							<Meter value={nextDrop !== undefined ? played / math.max(1, nextDrop.Seconds) : 1} color={Iron.steel()} order={2} />
						</frame>
						<Button
							text={nextReady ? "Claim" : nextDrop === undefined ? "Done" : clockText(nextDrop.Seconds - played)}
							onPress={() => nextDrop !== undefined && claimDrop(nextDrop)}
							disabled={!nextReady}
							width={phone ? 160 : 170}
							height={52}
							textSize={19}
							order={1}
						/>
					</Row>
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, cellGap)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{entries.map((entry, i) => (
							<DropCell
								key={`t${entry.Index ?? i + 1}`}
								entry={entry}
								played={played}
								phone={phone}
								index={i}
								onClaim={claimDrop}
								width={new UDim2(1 / columns, -math.ceil((cellGap * (columns - 1)) / columns), 0, 0)}
							/>
						))}
					</frame>
				</Panel>
			)}

			{s.Community !== undefined && <CommunityBlock state={s.Community} phone={phone} request={props.request} order={4} />}

			<Row order={5} gap={8}>
				<Chip text="Wheel" on={false} onPress={() => props.navigate("Wheel")} order={0} />
				<Chip text={missionsReady > 0 ? `Missions ${missionsReady}` : "Missions"} on={missionsReady > 0} onPress={() => props.navigate("Missions")} order={1} />
				<Chip text={milestonesReady > 0 ? `Milestones ${milestonesReady}` : "Milestones"} on={milestonesReady > 0} onPress={() => props.navigate("Milestones")} order={2} />
				<Chip text="Boosts" on={false} onPress={() => props.navigate("Boosts")} order={3} />
			</Row>
		</scrollingframe>
	);
}
