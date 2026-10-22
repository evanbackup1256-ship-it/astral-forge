// Command, rebuilt on Forge2 at the old page's depth: commander rank + level gifts, officers,
// weekly jobs (with reset clock), the title wardrobe (animated previews, closed state), profile
// style, the signal shop, machine mastery, expeditions (active trip clock, landing, collect, send
// again, trip report line, search / filter / sort), relics (element FX, equip, upgrade, mystery
// state) and the season rank track (free + pass rewards). Same remotes and payloads as before.
// Motion reused from the old page: the tab slide (useBoatTween 0.2s easeOutCubic, 7px), the trip
// clock that ticks only while a trip runs, pending spinners and refusal shakes on claims, and
// gamepad focus jumping to the first ready claim.
import React from "@rbxts/react";
import * as GamepadNavigationService from "../../CoreKit/GamepadNavigationService";
import { clockText, compactNumber, Flux, formatReward, gteFlux, Reward } from "../../CoreKit/format";
import { easeOutCubic, useBoatTween, useStagger } from "../../MotionKit/motion";
import { useServerClock } from "../../hooks/useServerClock";
import { clientModule, kitMember, LuauComponent } from "../../pages/luauKits";
import { ProfileStylePanel } from "../../pages/PagesSystem/ProfileStylePanel";
import { Button } from "../design/Button";
import { Meter, Panel } from "../design/Panel";
import { Chip, Tab } from "../design/Pick";
import { EmptyState } from "../design/Layers";
import { Text, Title } from "../design/Text";
import { Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import type { PageProps } from "../router/routes";

const UserInputService = game.GetService("UserInputService");
const Shared = game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared");
const DescribeGenerated = require(Shared.WaitForChild("DescribeGenerated") as ModuleScript) as {
	seasonTierName(this: void, tier: number): string;
	tripLine(this: void, count: number, foundRelic: boolean): string;
};
const SeasonPremium = require(Shared.WaitForChild("SeasonPremium") as ModuleScript) as { Reward(this: void, tier: number): Reward };
const { AnimatedTitlePreview, darkTitlePlate, titleFxAccent, titleTier } = kitMember<{
	AnimatedTitlePreview: LuauComponent;
	darkTitlePlate: (this: void, fx: string) => Color3;
	titleFxAccent: (this: void, fx: string) => Color3;
	titleTier: (this: void, fx: string) => string;
}>("ReactHosts", "AnimatedTitle");
const ElementFxModule = clientModule<{ ElementFx: LuauComponent; sheet: (this: void, element: unknown) => { Color: Color3; Label: string } | undefined }>("ElementFx");
const ElementFx = ElementFxModule.ElementFx;

interface Directive { Id: string; Name: string; Description?: string; Claimed?: boolean; Progress: number; Target: number; Reward?: Reward }
interface TitleEntry { Id: string; Name: string; Description?: string; Unlocked?: boolean; Equipped?: boolean; Fx?: string }
interface ShopOffer { Id: string; Name: string; Color: Color3; Price: number; Purchased?: boolean; Reward?: Reward }
interface CommandState {
	Level: number; XP: number; LevelFloorXP: number; NextLevelXP: number; Rank?: string; Signals: number;
	ExpeditionsCompleted: number; StreakShields: number; ClaimableCommanderLevels: number[];
	ActiveExpedition?: { Id?: string; EndsAt?: number; StartedAt?: number };
	Weekly: Directive[]; SeasonClaims: Record<string, boolean | undefined>; PremiumClaims?: Record<string, boolean | undefined>;
	SeasonPassOwned?: boolean; SeasonXP: number; Artifacts: Record<string, { Level: number; Fragments: number } | undefined>;
	EquippedArtifact?: string; Titles: TitleEntry[]; Shop: ShopOffer[]; Crew: Record<string, number | undefined>;
	MachineMastery: Record<string, number | undefined>;
}
interface Expedition { Id: string; Name: string; Color: Color3; RequiredLevel: number; Duration: number; ArtifactChance: number; ArtifactId?: string; Reward?: Reward }
interface ArtifactDef { Id: string; Name: string; Rarity: string; Color: Color3; Element: unknown; EffectKind: string; EffectPerLevel: number }
interface SeasonTier { Tier: number; RequiredXP: number; Reward?: Reward }
interface Operations {
	Expeditions: Expedition[]; Artifacts: ArtifactDef[]; SeasonTiers: SeasonTier[]; SeasonName?: string; TitlesEnabled?: boolean;
	TitleStatus?: string; MaxCommanderLevel: number;
	Crew: Record<string, { Name: string; Color: Color3; BaseCost: number; MaxLevel: number; Description?: string } | undefined>;
}
type Reply = { ok?: boolean; message?: string; ArtifactNew?: boolean };

const TABS: Array<[string, string]> = [["Overview", "Overview"], ["Expeditions", "Expeditions"], ["Artifacts", "Relics"], ["Season", "Rank Track"]];
const TITLE_FX_FALLBACKS = ["shimmer", "aurora", "pulse", "chrome", "wave", "glow"];
const CREW_ROLES = ["Pilot", "Engineer", "Navigator"];
const WEEK_SECONDS = 7 * 24 * 60 * 60;
// the last trip this session, so the hero can offer it again once the crew is home
let lastTripId: string | undefined;

const crewCost = (base: number, level: number) => math.floor(base * math.pow(level, 1.55));
function artifactEffect(a: ArtifactDef, level: number) {
	if (a.EffectKind === "OfflineHours") return `+${"%.1f".format(a.EffectPerLevel * level)}h offline`;
	return `+${"%.0f".format(a.EffectPerLevel * level * 100)}% ${a.EffectKind}`;
}
function landsAt(unix: number): string {
	const [text] = string.gsub(os.date("%I:%M %p", math.floor(unix)), "^0", "");
	return text;
}
function weeklyResetText(now: number): string {
	const left = math.max(0, (math.floor(now / WEEK_SECONDS) + 1) * WEEK_SECONDS - now);
	const days = math.floor(left / 86400);
	const hours = math.floor((left % 86400) / 3600);
	if (days > 0) return `New jobs in ${days}d ${hours}h`;
	const minutes = math.max(1, math.floor((left % 3600) / 60));
	return hours > 0 ? `New jobs in ${hours}h ${minutes}m` : `New jobs in ${minutes}m`;
}
const fill01 = (value: number, target: number, full = false) => (full ? 1 : math.clamp(value / math.max(1, target), 0, 1));
const serverNow = () => game.GetService("Workspace").GetServerTimeNow();

// flips once when the trip lands instead of re-rendering the page every second
function useTripLanded(active: boolean, endsAt: number): boolean {
	const [landed, setLanded] = React.useState(() => active && serverNow() >= endsAt);
	React.useEffect(() => {
		if (!active) {
			setLanded(false);
			return undefined;
		}
		const left = endsAt - serverNow();
		if (left <= 0) {
			setLanded(true);
			return undefined;
		}
		setLanded(false);
		const timer = task.delay(left, () => setLanded(true));
		return () => {
			pcall(() => task.cancel(timer));
		};
	}, [active, endsAt]);
	return landed;
}
function TripClock(props: { ticking: boolean; render: (now: number) => React.Element }) {
	const now = useServerClock(props.ticking);
	return props.render(props.ticking ? now : serverNow());
}

/** The old page's tab entrance: 0.2s easeOutCubic slide in from 7px. */
function TabPane(props: { children?: React.ReactNode; spacing: number }) {
	const enter = useBoatTween(1, 0.2, false, easeOutCubic, 0);
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={20}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} Position={enter.map((a) => new UDim2(0, math.round((1 - math.clamp(a, 0, 1)) * 7), 0, 0))} BackgroundTransparency={1}>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, props.spacing)} />
				{props.children}
			</frame>
		</frame>
	);
}

function Row(props: { order?: number; children?: React.ReactNode; spacing?: number; center?: boolean }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, props.spacing ?? 8)} SortOrder={Enum.SortOrder.LayoutOrder} VerticalAlignment={props.center ? Enum.VerticalAlignment.Center : Enum.VerticalAlignment.Top} />
			{props.children}
		</frame>
	);
}

/** fixed-width cells that wrap into as many columns as fit (one column on phones) */
function Grid(props: { order?: number; cellW: number; cellH: number; phone: boolean; children?: React.ReactNode }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<uigridlayout CellSize={props.phone ? new UDim2(1, 0, 0, props.cellH) : UDim2.fromOffset(props.cellW, props.cellH)} CellPadding={UDim2.fromOffset(8, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</frame>
	);
}

function Cell(props: { order: number; stroke: Color3; strokeT?: number; color?: Color3; transparency?: number; children?: React.ReactNode }) {
	return (
		<frame BackgroundColor3={props.color ?? Iron.sunk()} BackgroundTransparency={props.transparency ?? 0} BorderSizePixel={0} LayoutOrder={props.order} ClipsDescendants>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<uistroke Color={props.stroke} Transparency={props.strokeT ?? 0.4} />
			<uipadding PaddingTop={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
			<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</frame>
	);
}

function TitleCard(props: { title: TitleEntry; index: number; request: PageProps["request"] }) {
	const t = props.title;
	const fx = t.Fx ?? TITLE_FX_FALLBACKS[props.index % TITLE_FX_FALLBACKS.size()];
	const accent = titleFxAccent(fx);
	return (
		<frame BackgroundColor3={darkTitlePlate(fx)} BackgroundTransparency={t.Equipped ? 0.06 : 0.28} BorderSizePixel={0} LayoutOrder={props.index} ClipsDescendants>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={t.Unlocked || t.Equipped ? accent : Iron.edge()} Thickness={t.Equipped ? 1.8 : 1} Transparency={t.Equipped ? 0.08 : t.Unlocked ? 0.48 : 0.58} />
			<uipadding PaddingTop={new UDim(0, 8)} PaddingBottom={new UDim(0, 8)} PaddingLeft={new UDim(0, 8)} PaddingRight={new UDim(0, 8)} />
			<uilistlayout Padding={new UDim(0, 4)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<Text text={`${titleTier(fx).upper()}  ${fx.gsub("-", " ")[0].upper()}${t.Equipped ? "  ·  ACTIVE" : t.Unlocked ? "" : "  ·  LOCKED"}`} size={10} color={t.Unlocked ? accent : Iron.muted()} font={Fonts.heavy} order={0} />
			<frame Size={new UDim2(1, 0, 0, 36)} BackgroundTransparency={1} LayoutOrder={1}>
				<AnimatedTitlePreview text={t.Name} fx={fx} size={16} preview={!t.Equipped} transparency={t.Unlocked ? 0 : 0.42} />
			</frame>
			<Text text={t.Description ?? "This is how the title looks in chat and on your nameplate."} size={11} color={t.Unlocked ? Iron.soft() : Iron.muted()} align="Center" box={new UDim2(1, 0, 0, 40)} minSize={9} order={2} />
			{t.Unlocked && !t.Equipped ? (
				<Button text="Equip crest" stretch height={34} order={3} onPress={() => props.request("EquipTitle", { Id: t.Id })} />
			) : (
				<Text text={t.Equipped ? "Equipped" : "Locked"} size={12} font={Fonts.heavy} color={t.Equipped ? accent : Iron.muted()} align="Center" box={new UDim2(1, 0, 0, 34)} order={3} />
			)}
		</frame>
	);
}

export function CommandPage(props: PageProps) {
	const session = props.session as unknown as { Command?: CommandState; Stardust?: Flux; Cosmetics?: unknown; Rebirths?: unknown };
	const ops = props.config.Operations as Operations | undefined;
	const command = session.Command;
	if (ops === undefined || command === undefined) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, 48)} PaddingLeft={new UDim(0, 16)} PaddingRight={new UDim(0, 16)} />
				<EmptyState title="Loading your crew" phone={props.phone} />
			</frame>
		);
	}
	return <CommandReady page={props} ops={ops} command={command} session={session} />;
}

function CommandReady(outer: { page: PageProps; ops: Operations; command: CommandState; session: { Stardust?: Flux; Cosmetics?: unknown; Rebirths?: unknown } }) {
	const { page, ops, command, session } = outer;
	const phone = page.phone;
	const request = page.request;
	const machines = (page.config.Machines ?? []) as Array<{ Id: string; Name: string; Color: Color3 }>;
	const [tab, setTab] = React.useState("Overview");
	const scrollRef = React.useRef<ScrollingFrame>();
	const claimHostRef = React.useRef<Frame>();
	const heroIn = useStagger(0);
	React.useEffect(() => {
		const frame = scrollRef.current;
		if (frame) frame.CanvasPosition = new Vector2(0, 0);
	}, [tab]);

	// expedition browse: search, filter (All/Available/Locked) and sort (level / shortest / best relic odds)
	const [query, setQuery] = React.useState("");
	const [filter, setFilter] = React.useState("All");
	const [sort, setSort] = React.useState("Level");
	let trips = (ops.Expeditions ?? []).filter((e) => {
		if (filter === "Available" && command.Level < e.RequiredLevel) return false;
		if (filter === "Locked" && command.Level >= e.RequiredLevel) return false;
		if (query === "") return true;
		const hay = `${e.Name} ${formatReward(e.Reward)} level ${e.RequiredLevel}`.lower();
		return hay.find(query.lower(), 1, true)[0] !== undefined;
	});
	if (sort === "Shortest") trips = [...trips].sort((a, b) => a.Duration < b.Duration);
	else if (sort === "Relic") trips = [...trips].sort((a, b) => a.ArtifactChance > b.ArtifactChance);

	const titlesEnabled = ops.TitlesEnabled !== false;
	const maxed = command.Level >= ops.MaxCommanderLevel;
	const levelProgress = maxed ? 1 : fill01(command.XP - command.LevelFloorXP, command.NextLevelXP - command.LevelFloorXP);
	const nextClaim = command.ClaimableCommanderLevels[0] as number | undefined;
	const active = command.ActiveExpedition;
	const activeId = active?.Id ?? "";
	const activeEnds = active?.EndsAt ?? 0;
	const activeStarted = active?.StartedAt ?? 0;
	const expeditionReady = useTripLanded(activeId !== "", activeEnds);
	const tripTicking = tab === "Expeditions" && activeId !== "" && !expeditionReady;
	const tripProgress = (now: number) => (activeId === "" ? 0 : math.clamp((now - activeStarted) / math.max(1, activeEnds - activeStarted), 0, 1));
	if (activeId !== "") lastTripId = activeId;
	const [tripReport, setTripReport] = React.useState<{ name: string; haul: string; found: boolean } | undefined>(undefined);

	// claims and buys: the pressed button waits for the server, a refusal shakes it, and nothing
	// else can be sent meanwhile (no double buys or double claims)
	const [pendingKey, setPendingKey] = React.useState<string | undefined>(undefined);
	const [refusal, setRefusal] = React.useState({ key: "", token: 0 });
	const sendPending = (key: string, action: string, payload: Record<string, unknown>) => {
		if (pendingKey !== undefined) return;
		setPendingKey(key);
		const fallback = task.delay(8, () => setPendingKey(undefined));
		request(action, payload, (reply) => {
			pcall(task.cancel, fallback);
			setPendingKey(undefined);
			if (reply.ok !== true) setRefusal((c) => ({ key, token: c.token + 1 }));
		});
	};
	const pend = (key: string) => ({ busy: pendingKey === key, shakeToken: refusal.key === key ? refusal.token : 0 });

	const repeatTrip = activeId === "" && lastTripId !== undefined ? ops.Expeditions.find((e) => e.Id === lastTripId) : undefined;
	const canRepeat = repeatTrip !== undefined && command.Level >= repeatTrip.RequiredLevel;
	const statusLine =
		activeId === ""
			? tripReport !== undefined
				? `${tripReport.name} came back with ${tripReport.haul}.`
				: "Launch an unlocked adventure below."
			: expeditionReady
				? "Crew is back. Collect their rewards."
				: undefined;
	const claimLabel = activeId === "" ? (canRepeat ? "Send again" : "Choose below") : expeditionReady ? "Collect" : undefined;
	const collectTrip = () => {
		const name = ops.Expeditions.find((e) => e.Id === activeId)?.Name ?? "Your crew";
		request("ClaimExpedition", {}, (reply) => {
			const r = reply as Reply;
			if (r.ok === true) setTripReport({ name, haul: r.message !== undefined && r.message !== "" ? r.message : "their rewards", found: r.ArtifactNew === true });
		});
	};
	const onHeroAction = () => {
		if (activeId === "" && canRepeat && repeatTrip !== undefined) {
			setTripReport(undefined);
			request("LaunchExpedition", { Id: repeatTrip.Id });
		} else collectTrip();
	};

	let firstReadyWeeklyId: string | undefined;
	for (const d of command.Weekly ?? []) {
		if (!d.Claimed && d.Progress >= d.Target) {
			firstReadyWeeklyId = d.Id;
			break;
		}
	}
	const passOwned = command.SeasonPassOwned === true;
	const premiumClaims = command.PremiumClaims ?? {};
	let firstReadySeasonTier: number | undefined;
	for (const tier of ops.SeasonTiers ?? []) {
		const claimed = command.SeasonClaims[tostring(tier.Tier)] === true;
		const passClaimed = !passOwned || premiumClaims[tostring(tier.Tier)] === true;
		if (command.SeasonXP >= tier.RequiredXP && (!claimed || !passClaimed)) {
			firstReadySeasonTier = tier.Tier;
			break;
		}
	}
	const claimReady =
		(tab === "Overview" && (nextClaim !== undefined || firstReadyWeeklyId !== undefined)) ||
		(tab === "Expeditions" && expeditionReady) ||
		(tab === "Season" && firstReadySeasonTier !== undefined);
	// a gamepad lands on the first ready claim, as before
	React.useEffect(() => {
		if (!claimReady || !UserInputService.GamepadEnabled) return undefined;
		const host = claimHostRef.current;
		if (host === undefined) return undefined;
		const job = task.defer(() => {
			if (host.Parent !== undefined) GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, job);
		};
	}, [tab, nextClaim, firstReadyWeeklyId, expeditionReady, firstReadySeasonTier, claimReady]);

	const activeConfig = ops.Expeditions.find((e) => e.Id === activeId);
	const ownedArtifacts = ops.Artifacts.filter((a) => command.Artifacts[a.Id] !== undefined).size();
	const nextTier = ops.SeasonTiers.find((t) => command.SeasonClaims[tostring(t.Tier)] !== true);
	const space = gap(phone, "l");
	const pad = gap(phone, "l");

	const claimHost = (on: boolean, children: React.ReactNode, order = 50, w?: number) => (
		<frame ref={on ? claimHostRef : undefined} Size={phone || w === undefined ? new UDim2(1, 0, 0, HIT + 4) : UDim2.fromOffset(w, HIT + 4)} BackgroundTransparency={1} LayoutOrder={order}>
			{children}
		</frame>
	);

	// ---------- Overview ----------
	const overview = tab === "Overview" && (
		<TabPane spacing={space}>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0} Position={heroIn.map((p) => UDim2.fromOffset(0, (1 - p) * 16))}>
				<Panel pad={pad} spacing={gap(phone, "m")} seam={nextClaim !== undefined}>
					<Row order={0} spacing={14} center>
						<frame Size={UDim2.fromOffset(phone ? 72 : 96, phone ? 72 : 96)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={0}>
							<uicorner CornerRadius={new UDim(0, 12)} />
							<uistroke Color={Iron.steel()} Thickness={2} Transparency={0.25} />
							<Text text={"%02d".format(command.Level)} size={phone ? 28 : 36} font={Fonts.heavy} color={Iron.steel()} align="Center" box={new UDim2(1, 0, 0.7, 0)} />
							<Text text="LVL" size={11} color={Iron.muted()} align="Center" box={new UDim2(1, 0, 0.28, 0)} position={UDim2.fromScale(0, 0.68)} />
						</frame>
						<frame Size={new UDim2(1, -(phone ? 86 : 110), 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
							<uilistlayout Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Title text={command.Rank ?? "Commander"} size={Type.title(phone)} tags={["wave"]} order={0} />
							<Text text={maxed ? "Top rank" : `${compactNumber(math.max(0, command.NextLevelXP - command.XP))} XP to next`} size={Type.small(phone)} color={Iron.muted()} order={1} />
							<Meter value={levelProgress} color={Iron.steel()} order={2} height={8} />
						</frame>
					</Row>
					<Text
						text={`${compactNumber(command.Signals)} signals  ·  ${compactNumber(command.ExpeditionsCompleted)} ${command.ExpeditionsCompleted === 1 ? "trip" : "trips"}  ·  ${compactNumber(command.StreakShields)} ${command.StreakShields === 1 ? "shield" : "shields"}`}
						size={Type.small(phone)}
						color={Iron.soft()}
						multiline
						order={1}
					/>
					{claimHost(
						nextClaim !== undefined,
						<Button
							text={nextClaim !== undefined ? `Claim level ${nextClaim}` : "Rank gifts complete"}
							stretch
							highlight={nextClaim !== undefined}
							disabled={nextClaim === undefined}
							{...pend("commander")}
							onPress={() => nextClaim !== undefined && sendPending("commander", "ClaimCommanderReward", { Level: nextClaim })}
						/>,
						2,
						220,
					)}
				</Panel>
			</frame>

			<Panel pad={pad} spacing={gap(phone, "s")} order={1}>
				<Title text="Officers" size={Type.title(phone) - 4} order={0} />
				<Text text="Train officers with signals." size={Type.small(phone)} color={Iron.muted()} order={1} />
				<Grid order={2} cellW={210} cellH={phone ? 150 : 140} phone={phone}>
					{CREW_ROLES.map((roleId, i) => {
						const role = ops.Crew[roleId];
						if (!role) return undefined;
						const level = command.Crew[roleId] ?? 1;
						const cost = crewCost(role.BaseCost, level);
						const maxRole = level >= role.MaxLevel;
						const can = !maxRole && command.Signals >= cost;
						return (
							<Cell key={roleId} order={i} stroke={role.Color}>
								<Text text={role.Name} size={14} font={Fonts.heavy} color={role.Color} order={0} />
								<Text text={role.MaxLevel >= 1000000000 ? `Lv ${compactNumber(level)}` : `Lv ${compactNumber(level)} / ${compactNumber(role.MaxLevel)}`} size={12} color={Iron.soft()} order={1} />
								{role.Description !== undefined && <Text text={role.Description} size={11} color={Iron.muted()} box={new UDim2(1, 0, 0, 30)} minSize={9} order={2} />}
								<Button text={maxRole ? "Max" : `Train · ${compactNumber(cost)} signals`} stretch height={36} disabled={!can} highlight={can} order={3} onPress={() => request("UpgradeCrew", { Role: roleId })} />
							</Cell>
						);
					})}
				</Grid>
			</Panel>

			<Panel pad={pad} spacing={gap(phone, "s")} order={2}>
				<Row order={0} center>
					<Title text="Weekly jobs" size={Type.title(phone) - 4} order={0} />
					<Text text={weeklyResetText(serverNow())} size={Type.small(phone)} color={Iron.muted()} box={UDim2.fromOffset(170, 18)} order={1} />
				</Row>
				{(command.Weekly ?? []).map((d, i) => {
					const ready = !d.Claimed && d.Progress >= d.Target;
					const reward = formatReward(d.Reward);
					return (
						<Panel key={d.Id} pad={12} spacing={4} color={Iron.sunk()} seam={ready} order={i + 1}>
							<Text text={d.Name} size={Type.body(phone)} font={Fonts.heavy} color={ready ? Iron.brass() : Iron.text()} order={0} />
							{d.Description !== undefined && <Text text={d.Description} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />}
							<Text text={reward !== "" ? reward : `${compactNumber(d.Progress)} / ${compactNumber(d.Target)}`} size={Type.small(phone)} color={Iron.soft()} multiline order={2} />
							<Meter value={fill01(d.Progress, d.Target, d.Claimed === true || ready)} color={Iron.brass()} order={3} height={7} />
							{claimHost(
								ready && nextClaim === undefined && d.Id === firstReadyWeeklyId,
								<Button text={d.Claimed ? "Done" : ready ? "Claim" : "Not yet"} stretch disabled={d.Claimed === true || !ready} highlight={ready} {...pend(`weekly:${d.Id}`)} onPress={() => sendPending(`weekly:${d.Id}`, "ClaimWeeklyDirective", { Id: d.Id })} />,
								4,
								150,
							)}
						</Panel>
					);
				})}
			</Panel>

			<Panel pad={pad} spacing={gap(phone, "s")} order={3}>
				<Title text="Title wardrobe" size={Type.title(phone) - 4} order={0} />
				{titlesEnabled ? (
					<>
						<Text text="Each title shows as it looks on you." size={Type.small(phone)} color={Iron.muted()} order={1} />
						<Grid order={2} cellW={210} cellH={176} phone={false}>
							{command.Titles.map((t, i) => (
								<TitleCard key={t.Id} title={t} index={i} request={request} />
							))}
						</Grid>
					</>
				) : (
					<>
						<Text text="Temporarily closed" size={Type.small(phone)} font={Fonts.heavy} color={Iron.muted()} order={1} />
						<Text text={ops.TitleStatus ?? "Titles are temporarily unavailable."} size={Type.small(phone)} color={Iron.muted()} multiline order={2} />
					</>
				)}
			</Panel>

			<Panel pad={pad} spacing={gap(phone, "s")} order={4}>
				<Title text="Profile style" size={Type.title(phone) - 4} order={0} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					<ProfileStylePanel cosmetics={session.Cosmetics} rebirths={session.Rebirths} dispatch={request as never} stack={phone} reducedMotion={false} />
				</frame>
			</Panel>

			<Panel pad={pad} spacing={gap(phone, "s")} order={5}>
				<Title text={`Signal shop · ${compactNumber(command.Signals)} ready`} size={Type.title(phone) - 4} order={0} />
				<Grid order={1} cellW={190} cellH={170} phone={false}>
					{command.Shop.map((offer, i) => {
						const can = !offer.Purchased && command.Signals >= offer.Price;
						return (
							<Cell key={offer.Id} order={i} stroke={offer.Color} strokeT={0.35}>
								<Text text={offer.Name} size={13} font={Fonts.heavy} color={offer.Color} order={0} />
								<Text text={formatReward(offer.Reward)} size={12} color={Iron.soft()} box={new UDim2(1, 0, 0, 52)} minSize={10} order={1} />
								<Button text={offer.Purchased ? "Bought" : `${offer.Price} signals`} stretch height={40} disabled={!can} highlight={can} {...pend(`signal:${offer.Id}`)} order={2} onPress={() => sendPending(`signal:${offer.Id}`, "BuySignalOffer", { Id: offer.Id })} />
							</Cell>
						);
					})}
				</Grid>
			</Panel>

			<Panel pad={pad} spacing={gap(phone, "s")} order={6}>
				<Title text="Machine mastery" size={Type.title(phone) - 4} order={0} />
				<Grid order={1} cellW={210} cellH={70} phone={phone}>
					{machines.map((m, i) => {
						const mastery = command.MachineMastery[m.Id] ?? 0;
						const rank = math.floor(math.sqrt(mastery));
						const nextRank = math.pow(rank + 1, 2);
						const f = rank >= 99 ? 1 : (mastery - rank * rank) / math.max(1, nextRank - rank * rank);
						return (
							<Cell key={m.Id} order={i} stroke={m.Color} strokeT={0.7}>
								<Text text={`${m.Name}  ·  Rank ${rank}`} size={12} font={Fonts.bold} order={0} />
								<Meter value={f} color={m.Color} order={1} height={6} />
								<Text text={`${compactNumber(mastery)} built`} size={11} color={Iron.muted()} order={2} />
							</Cell>
						);
					})}
				</Grid>
			</Panel>
		</TabPane>
	);

	// ---------- Expeditions ----------
	const expeditions = tab === "Expeditions" && (
		<TabPane spacing={space}>
			<Panel pad={pad} spacing={gap(phone, "s")} seam={expeditionReady} order={0}>
				<Text text={activeId === "" && tripReport !== undefined ? `"${DescribeGenerated.tripLine(command.ExpeditionsCompleted, tripReport.found)}"` : "Active trip"} size={Type.small(phone)} color={Iron.muted()} order={0} />
				<Title text={activeConfig?.Name ?? (canRepeat ? `Last trip: ${repeatTrip!.Name}` : "No trip underway")} size={Type.title(phone)} color={expeditionReady ? Iron.brass() : undefined} tags={expeditionReady ? ["wave"] : undefined} order={1} />
				<TripClock ticking={tripTicking} render={(now) => <Text text={statusLine ?? `Back in ${clockText(math.max(0, activeEnds - now))}, around ${landsAt(activeEnds)}`} size={Type.small(phone)} color={Iron.soft()} order={2} />} />
				<TripClock ticking={tripTicking} render={(now) => <Meter value={expeditionReady ? 1 : tripProgress(now)} color={expeditionReady ? Iron.brass() : Iron.steel()} order={3} height={8} />} />
				{claimHost(
					expeditionReady,
					<TripClock
						ticking={tripTicking}
						render={(now) => (
							<Button text={claimLabel ?? clockText(math.max(0, activeEnds - now))} stretch highlight={expeditionReady} disabled={!expeditionReady && !(activeId === "" && canRepeat)} onPress={onHeroAction} />
						)}
					/>,
					4,
					220,
				)}
			</Panel>
			<Panel pad={gap(phone, "m")} spacing={8} order={1} color={Iron.sunk()}>
				<textbox
					Size={new UDim2(1, 0, 0, HIT)}
					BackgroundColor3={Iron.void()}
					BorderSizePixel={0}
					Text={query}
					PlaceholderText="Search adventures by name or reward"
					PlaceholderColor3={Iron.muted()}
					TextColor3={Iron.text()}
					FontFace={Fonts.bold}
					TextSize={Type.body(phone)}
					TextXAlignment={Enum.TextXAlignment.Left}
					ClearTextOnFocus={false}
					LayoutOrder={0}
					Change={{ Text: (box) => setQuery(box.Text) }}
				>
					<uicorner CornerRadius={new UDim(0, 6)} />
					<uipadding PaddingLeft={new UDim(0, 12)} PaddingRight={new UDim(0, 12)} />
				</textbox>
				<Row order={1}>
					{["All", "Available", "Locked"].map((id, i) => (
						<Chip key={id} text={id} on={filter === id} order={i} onPress={() => setFilter(id)} />
					))}
				</Row>
				<Row order={2}>
					{[["Level", "By level"], ["Shortest", "Shortest trip"], ["Relic", "Best relic odds"]].map(([id, label], i) => (
						<Chip key={id} text={label} on={sort === id} color={Iron.steel()} order={i} onPress={() => setSort(id)} />
					))}
				</Row>
			</Panel>
			{trips.size() === 0 && (
				<EmptyState title="No adventures match" action={{ text: "Clear search", onPress: () => { setQuery(""); setFilter("All"); } }} phone={phone} order={2} />
			)}
			{trips.map((e, i) => {
				const locked = command.Level < e.RequiredLevel;
				const busy = activeId !== "";
				const can = !locked && !busy;
				const pilot = command.Crew.Pilot ?? 1;
				return (
					<Panel key={e.Id} pad={gap(phone, "m")} spacing={4} seam={can} order={3 + i}>
						<Text text={`Lv ${e.RequiredLevel}  ·  ${clockText(math.max(10, math.floor(e.Duration * math.max(0.35, 1 - (pilot - 1) * 0.05))))}`} size={Type.small(phone)} color={e.Color} order={0} />
						<Text text={e.Name} size={Type.body(phone) + 1} font={Fonts.heavy} order={1} />
						<Text text={`${formatReward(e.Reward)}  ·  ${"%.0f".format(e.ArtifactChance * 100)}% relic`} size={Type.small(phone)} color={Iron.muted()} multiline order={2} />
						<Button text={locked ? `Need lv ${e.RequiredLevel}` : busy ? "Crew away" : "Launch"} width={200} stretch={phone} disabled={!can} highlight={can} order={3} onPress={() => request("LaunchExpedition", { Id: e.Id })} />
					</Panel>
				);
			})}
		</TabPane>
	);

	// ---------- Relics ----------
	const relics = tab === "Artifacts" && (
		<TabPane spacing={space}>
			<Panel pad={pad} spacing={gap(phone, "s")} order={0}>
				<Title text={`Relics  ${ownedArtifacts}/${ops.Artifacts.size()}`} size={Type.title(phone)} order={0} />
				<Text text="Equip one relic. Duplicates add spark fragments for upgrades." size={Type.small(phone)} color={Iron.muted()} multiline order={1} />
				<Meter value={ownedArtifacts / math.max(1, ops.Artifacts.size())} order={2} height={8} />
			</Panel>
			{ops.Artifacts.map((a, i) => {
				const owned = command.Artifacts[a.Id];
				const equipped = command.EquippedArtifact === a.Id;
				const fragmentCost = owned ? 4 + owned.Level * 2 : 0;
				const dustCost = owned ? 8 * owned.Level : 0;
				const canUpgrade = owned !== undefined && owned.Level < 10 && owned.Fragments >= fragmentCost && gteFlux(session.Stardust as Flux, dustCost);
				const sheet = ElementFxModule.sheet(a.Element);
				return (
					<Panel key={a.Id} pad={gap(phone, "m")} spacing={6} color={owned ? undefined : Iron.sunk()} seam={equipped} order={1 + i}>
						<Row order={0} spacing={12} center>
							<frame Size={UDim2.fromOffset(48, 48)} BackgroundColor3={Iron.void()} BackgroundTransparency={0.15} BorderSizePixel={0} ClipsDescendants LayoutOrder={0}>
								<uicorner CornerRadius={new UDim(0, 12)} />
								<uistroke Color={owned ? (sheet ?? { Color: a.Color }).Color : Iron.edge()} Transparency={equipped ? 0 : 0.45} Thickness={equipped ? 2 : 1} />
								<ElementFx element={a.Element} size={UDim2.fromOffset(48, 48)} position={UDim2.fromScale(0.5, 0.5)} still={!owned} transparency={owned ? 0 : 0.7} reaction="reveal" reactionKey={owned !== undefined} />
							</frame>
							<frame Size={new UDim2(1, -62, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
								<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
								<Text text={owned ? `${a.Rarity}  ·  ${(sheet ?? { Label: "" }).Label}  ·  Lv ${owned.Level}/10` : a.Rarity} size={Type.small(phone)} color={owned ? a.Color : Iron.muted()} order={0} />
								<Text text={owned ? a.Name : "Mystery relic"} size={Type.body(phone) + 1} font={Fonts.heavy} order={1} />
								<Text text={owned ? `${artifactEffect(a, owned.Level)}  ·  ${owned.Fragments}/${fragmentCost} sparks` : "Finish its expedition to discover it."} size={Type.small(phone)} color={Iron.muted()} multiline order={2} />
							</frame>
						</Row>
						<Row order={1}>
							<Button text={equipped ? "In use" : "Equip"} width={phone ? 120 : 130} disabled={!owned || equipped} order={0} onPress={() => request("EquipArtifact", { Id: a.Id })} />
							<Button text={!owned ? "—" : owned.Level >= 10 ? "Max" : `${dustCost} dust`} tone="ember" width={phone ? 120 : 130} disabled={!canUpgrade} highlight={canUpgrade} order={1} onPress={() => request("UpgradeArtifact", { Id: a.Id })} />
						</Row>
					</Panel>
				);
			})}
		</TabPane>
	);

	// ---------- Rank track ----------
	const season = tab === "Season" && (
		<TabPane spacing={space}>
			<Panel pad={pad} spacing={gap(phone, "s")} seam={passOwned} rarity="Mythic" order={0}>
				<Title text={ops.SeasonName ?? "Deep Space Command"} size={Type.title(phone)} color={Iron.brass()} order={0} />
				<Text text={compactNumber(command.SeasonXP)} size={Type.body(phone)} color={Iron.muted()} order={1} />
				<Meter value={nextTier ? fill01(command.SeasonXP, nextTier.RequiredXP) : 1} order={2} height={9} />
				<Text text={nextTier ? (command.SeasonXP >= nextTier.RequiredXP ? `Gift ${nextTier.Tier} is ready` : `${compactNumber(nextTier.RequiredXP - command.SeasonXP)} XP to gift ${nextTier.Tier}`) : "All season gifts claimed"} size={Type.small(phone)} color={Iron.soft()} order={3} />
				<Text text={passOwned ? "Season Pass active: every tier pays out twice." : "The Season Pass in the Shop adds a second reward to every tier."} size={Type.small(phone)} color={passOwned ? Iron.brass() : Iron.muted()} multiline order={4} />
			</Panel>
			{ops.SeasonTiers.map((tier, i) => {
				const unlocked = command.SeasonXP >= tier.RequiredXP;
				const claimed = command.SeasonClaims[tostring(tier.Tier)] === true;
				const major = tier.Tier % 5 === 0;
				const passClaimed = premiumClaims[tostring(tier.Tier)] === true;
				const passReady = passOwned && unlocked && !passClaimed;
				return (
					<Panel key={tostring(tier.Tier)} pad={gap(phone, "m")} spacing={6} color={major ? Iron.raised() : undefined} seam={unlocked && (!claimed || passReady)} order={1 + i}>
						<Row order={0} spacing={12} center>
							<frame Size={UDim2.fromOffset(52, 52)} BackgroundColor3={claimed ? Iron.brass() : unlocked ? Iron.ember() : Iron.sunk()} BorderSizePixel={0} LayoutOrder={0}>
								<uicorner CornerRadius={new UDim(1, 0)} />
								<Text text={"%02d".format(tier.Tier)} size={20} font={Fonts.heavy} color={claimed || unlocked ? Iron.sunk() : Iron.muted()} align="Center" box={UDim2.fromScale(1, 1)} />
							</frame>
							<frame Size={new UDim2(1, -66, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
								<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
								<Text text={DescribeGenerated.seasonTierName(tier.Tier)} size={Type.body(phone)} font={Fonts.heavy} color={major ? Iron.brass() : Iron.text()} order={0} />
								<Text text={formatReward(tier.Reward)} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />
								<Text text={formatReward(SeasonPremium.Reward(tier.Tier))} size={Type.small(phone)} color={passOwned ? Iron.brass() : Iron.muted()} multiline order={2} />
							</frame>
						</Row>
						<Meter value={fill01(command.SeasonXP, tier.RequiredXP, claimed || unlocked)} color={major ? Iron.brass() : Iron.steel()} order={1} height={7} />
						<frame ref={unlocked && (!claimed || passReady) && tier.Tier === firstReadySeasonTier ? claimHostRef : undefined} Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
							<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
							<Button text={claimed ? "Done" : unlocked ? "Open" : "Locked"} width={phone ? 110 : 120} disabled={claimed || !unlocked} highlight={unlocked && !claimed} {...pend(`season:${tier.Tier}`)} order={0} onPress={() => sendPending(`season:${tier.Tier}`, "ClaimSeasonTier", { Tier: tier.Tier })} />
							<Button text={passClaimed ? "Done" : !passOwned || unlocked ? "Pass" : "Locked"} tone="ember" width={phone ? 110 : 120} disabled={!passReady} highlight={passReady} {...pend(`pass:${tier.Tier}`)} order={1} onPress={() => sendPending(`pass:${tier.Tier}`, "ClaimSeasonPremium", { Tier: tier.Tier })} />
						</frame>
					</Panel>
				);
			})}
		</TabPane>
	);

	return (
		<scrollingframe
			ref={scrollRef}
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
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={0}>
				<uilistlayout Padding={new UDim(0, 2)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Text text="Season" size={Type.small(phone)} color={Iron.steel()} order={0} />
				<Title text={ops.SeasonName ?? "Deep Space Command"} size={Type.title(phone) + 2} tags={["wave"]} order={1} />
			</frame>
			<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{TABS.map(([id, label], i) => (
					<Tab
						key={id}
						text={label}
						active={tab === id}
						width={phone ? 124 : 140}
						order={i}
						badge={
							id === "Overview"
								? (command.ClaimableCommanderLevels.size() + (firstReadyWeeklyId !== undefined ? 1 : 0)) || undefined
								: id === "Expeditions" && expeditionReady
									? 1
									: id === "Season" && firstReadySeasonTier !== undefined
										? 1
										: undefined
						}
						onPress={() => setTab(id)}
					/>
				))}
			</frame>
			{overview}
			{expeditions}
			{relics}
			{season}
		</scrollingframe>
	);
}
