// Expeditions v3. One card per slot. An open slot picks a route, a stance and up to three relics, and
// shows the exact forecast the server will lock in (time, haul, risk, find) with the synergies that
// apply. A running slot is a big timer over a meter; a finished one claims, and the outcome lands as
// a banner at the top with a screen moment to match: Triumph, Clean or Setback.
// Every figure on the page says what it is: the summary reads "1 of 3 slots out", the streak reads
// "Streak 3 · +6% haul", and each forecast number has a caption and a one-line hint under it.
import React from "@rbxts/react";
import Board = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import { clockText } from "../../CoreKit/format";
import { chromeFor, Palette, TapTarget } from "../../CoreKit/theme";
import { useViewport } from "../../MotionKit/motion";
import { useServerClock } from "../../hooks/useServerClock";
import { ScreenFx } from "../../UiCore/screenFx";
import { loadPageScaffold, loadUi } from "../luauDeps";

const { Button, Dropdown, Meter, Panel, SegmentedTabs, Text } = loadUi();
const PageScaffold = loadPageScaffold();

type Stance = (typeof Board.STANCES)[number];
type Role = (typeof Board.ROLES)[number];
type Forecast = ReturnType<typeof Board.forecast>;
type Outcome = ReturnType<typeof Board.outcomeFor>;

interface Reply {
	ok?: boolean;
	message?: string;
	Outcome?: Outcome;
	Streak?: number;
	Route?: string;
	ArtifactNew?: boolean;
}
type Dispatch = (action: string, payload?: object, callback?: (response: Reply) => void) => unknown;

interface Route {
	Id: string;
	Name: string;
	Duration: number;
	RequiredLevel: number;
	Color?: Color3;
}
interface SlotState {
	Slot: number;
	Id: string;
	Crew: string[];
	StartedAt: number;
	EndsAt: number;
	Stance?: Stance;
	Yield?: number;
	Risk?: number;
	Find?: number;
}
interface BoardState {
	Slots: SlotState[];
	CrewMax: number;
	Paused?: boolean;
	Streak?: number;
	Best?: number;
	Companion?: string;
	Speed?: number;
}
interface ItemDef {
	Id: string;
	Name: string;
	Rarity: string;
	EffectKind: string;
}
interface Instance_ {
	DefinitionId: string;
	Stars?: number;
}

interface Props {
	state: {
		ExpeditionBoard?: BoardState;
		Command?: { Level?: number; Crew?: { Pilot?: number } };
		Items?: { Inventory?: Record<string, Instance_>; Equipped?: Record<string, string> };
	};
	config: { Operations?: { Expeditions?: Route[] }; Items?: { Definitions?: ItemDef[] } };
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

const PAD = 20;
const GAP = 12;
const CHIP_H = TapTarget;
const HEAD_H = 22;
const LABEL_H = 16;
const NOTE_H = 18;
const STAT_H = 64;
const MAX_SHOWN = 8;
// the compact line shown when no relic is free for a crew
const EMPTY_CREW_H = 40;

const ROLE_COLOR: Record<Role, Color3> = { Haul: Palette.mango, Guard: Palette.mint, Scout: Palette.cyan };
const STANCE_COLOR: Record<Stance, Color3> = { Careful: Palette.mint, Steady: Palette.cyan, Daring: Palette.coral };
const OUTCOME_COLOR: Record<Outcome, Color3> = { Triumph: Palette.violet, Clean: Palette.mint, Setback: Palette.coral };
const STANCE_NOTE: Record<string, string> = {
	Careful: "Safer trip, smaller haul.",
	Steady: "Balanced risk and haul.",
	Daring: "Bigger haul, a real chance of a setback.",
};
const SYNERGY_TEXT: Record<string, string> = {
	Favoured: "favoured crew",
	Balanced: "balanced crew",
	Resonant: "resonant relics",
	Companion: "companion bonus",
	Streak: "streak bonus",
};

function defsById(config: Props["config"]): Map<string, ItemDef> {
	const out = new Map<string, ItemDef>();
	for (const def of config.Items?.Definitions ?? []) out.set(def.Id, def);
	return out;
}

interface Candidate {
	Uid: string;
	Def: ItemDef;
	Stars: number;
}

function member(c: Candidate) {
	return { Rarity: c.Def.Rarity, EffectKind: c.Def.EffectKind, Stars: c.Stars };
}

// free relics (not socketed, not the companion, not away), strongest first
function candidatesOf(props: Props, defs: Map<string, ItemDef>): Candidate[] {
	const items = props.state.Items;
	const busy = new Set<string>();
	for (const [, uid] of pairs(items?.Equipped ?? {})) busy.add(uid);
	const out: Candidate[] = [];
	for (const [uid, instance] of pairs(items?.Inventory ?? {})) {
		const def = defs.get(instance.DefinitionId);
		if (def !== undefined && !busy.has(uid as string)) out.push({ Uid: uid as string, Def: def, Stars: instance.Stars ?? 0 });
	}
	const power = (c: Candidate) => Board.crewPower([member(c)]);
	out.sort((a, b) => (power(a) !== power(b) ? power(a) > power(b) : a.Uid < b.Uid));
	return out;
}

// the v7 launch length (pilot upgrade), then the forecast and the companion's Scout trait
function launchLength(props: Props, route: Route, odds: Forecast): number {
	const pilot = props.state.Command?.Crew?.Pilot ?? 1;
	const base = math.max(10, math.floor(route.Duration * math.max(0.35, 1 - (pilot - 1) * 0.05)));
	const speed = props.state.ExpeditionBoard?.Speed ?? 0;
	return math.max(10, math.floor(base * odds.Time * (1 - speed)));
}

function pct(value: number): string {
	return `${math.floor(value * 100 + 0.5)}%`;
}

// a forecast figure: the number, what it is, and one line saying what it means
function Stat(p: { value: string; caption: string; hint: string; color: Color3; x: number; width: number; y: number }) {
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Position={new UDim2(p.x, 0, 0, p.y)} Size={new UDim2(p.width, -8, 0, STAT_H)}>
			<Text value={p.value} size={22} color={p.color} weight={Enum.FontWeight.Bold} fit={true} minSize={14} sizeConstraint={new UDim2(1, 0, 0, 30)} />
			<Text value={p.caption} size={12} color={Palette.cream} weight={Enum.FontWeight.Bold} position={UDim2.fromOffset(0, 31)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			<Text value={p.hint} size={11} color={Palette.muted} fit={true} minSize={9} position={UDim2.fromOffset(0, 48)} sizeConstraint={new UDim2(1, 0, 0, 14)} />
		</frame>
	);
}

// one source of truth for an open slot's rows, so the card's height always matches what is drawn
function openRows(candidates: number, stack: boolean) {
	const columns = stack ? 2 : 4;
	const shown = math.min(MAX_SHOWN, candidates);
	const crewRows = math.max(1, math.ceil(shown / columns));
	let y = 0;
	const headRow = y;
	y += HEAD_H + GAP;
	const routeRow = y;
	y += stack ? TapTarget * 2 + GAP : TapTarget;
	const stanceRow = y + GAP;
	y = stanceRow + TapTarget;
	const noteRow = y + 4;
	y = noteRow + NOTE_H + GAP;
	const crewLabelRow = y;
	y += LABEL_H + 6;
	const crewRow = y;
	y += (shown === 0 ? EMPTY_CREW_H : crewRows * (CHIP_H + 6)) + GAP;
	const statRow = y;
	y += STAT_H;
	const synergyRow = y;
	y += 20 + GAP;
	const launchRow = y;
	return { columns, headRow, routeRow, stanceRow, noteRow, crewLabelRow, crewRow, statRow, synergyRow, launchRow, height: PAD * 2 + launchRow + TapTarget };
}

function OpenSlot(p: { props: Props; slot: SlotState; routes: Route[]; busyRoutes: Set<string>; candidates: Candidate[]; stack: boolean }) {
	const board = p.props.state.ExpeditionBoard;
	const level = p.props.state.Command?.Level ?? 1;
	const open = p.routes.filter((route) => route.RequiredLevel <= level && !p.busyRoutes.has(route.Id));
	const [routeId, setRouteId] = React.useState<string | undefined>(undefined);
	const [stance, setStance] = React.useState<Stance>("Steady");
	const [crew, setCrew] = React.useState<string[]>([]);
	const [busy, setBusy] = React.useState(false);
	const [refused, setRefused] = React.useState(0);
	const route = open.find((r) => r.Id === routeId) ?? open[open.size() - 1];
	const crewMax = board?.CrewMax ?? Board.CREW_MAX;
	const shown = p.candidates.filter((_, i) => i < MAX_SHOWN);
	const picked = shown.filter((c) => crew.includes(c.Uid));
	const odds = route !== undefined ? Board.forecast(route.Id, stance, picked.map(member), board?.Companion, board?.Streak ?? 0) : undefined;
	const rows = openRows(p.candidates.size(), p.stack);
	const columns = rows.columns;
	const toggle = (uid: string) => {
		if (crew.includes(uid)) setCrew(crew.filter((u) => u !== uid));
		else if (crew.size() < crewMax) setCrew([...crew, uid]);
	};
	const launch = () => {
		if (route === undefined || busy) return;
		setBusy(true);
		p.props.dispatch("ExpeditionAct", { Op: "Launch", Slot: p.slot.Slot, Id: route.Id, Crew: crew, Stance: stance }, (response) => {
			setBusy(false);
			if (response.ok === true) {
				setCrew([]);
				ScreenFx.play("confirm", stance === "Daring" ? 1.2 : 0.8);
			} else {
				setRefused(refused + 1);
				ScreenFx.play("error", 0.6);
			}
		});
	};
	if (open.size() === 0 || route === undefined || odds === undefined) {
		return (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.lineSoft} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion}>
				<Text value={`Slot ${p.slot.Slot}`} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(1, 0, 0, HEAD_H)} />
				<Text value="Every route you can run is already out." size={14} color={Palette.muted} fit={true} minSize={10} position={UDim2.fromOffset(0, HEAD_H + 6)} sizeConstraint={new UDim2(1, 0, 0, 20)} />
			</Panel>
		);
	}
	const role = odds.Role;
	const synergyText = odds.Synergies.map((s) => SYNERGY_TEXT[s] ?? s).join("  ·  ");
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={STANCE_COLOR[stance]} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion} clips={false}>
			<frame Size={new UDim2(1, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Text value={`Slot ${p.slot.Slot}`} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} position={UDim2.fromOffset(0, rows.headRow)} sizeConstraint={new UDim2(0.5, 0, 0, HEAD_H)} />
				<Text
					value="Ready to launch"
					size={13}
					color={STANCE_COLOR[stance]}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(0.5, 0, 0, rows.headRow + 2)}
					sizeConstraint={new UDim2(0.5, 0, 0, 18)}
				/>
				<Dropdown
					options={open.map((r) => ({ id: r.Id, label: r.Name, detail: clockText(r.Duration) }))}
					value={route.Id}
					onChange={(id: string) => setRouteId(id)}
					accent={ROLE_COLOR[role]}
					label="ROUTE"
					size={new UDim2(p.stack ? 1 : 0.6, 0, 0, TapTarget)}
					position={UDim2.fromOffset(0, rows.routeRow)}
					reducedMotion={p.props.reducedMotion}
					zIndex={40 + (10 - p.slot.Slot)}
				/>
				<frame
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Position={p.stack ? UDim2.fromOffset(0, rows.routeRow + TapTarget + GAP) : new UDim2(0.6, 16, 0, rows.routeRow)}
					Size={new UDim2(p.stack ? 1 : 0.4, p.stack ? 0 : -16, 0, TapTarget)}
				>
					<frame BackgroundColor3={ROLE_COLOR[role]} BorderSizePixel={0} AnchorPoint={new Vector2(0, 0.5)} Position={new UDim2(0, 0, 0.5, 0)} Size={UDim2.fromOffset(10, 10)}>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
					<Text value={`${role} route`} size={14} color={Palette.creamSoft} position={new UDim2(0, 20, 0.5, -10)} sizeConstraint={new UDim2(1, -20, 0, 20)} fit={true} minSize={10} />
				</frame>
				<SegmentedTabs
					options={Board.STANCES.map((s) => ({ id: s, label: s, accent: STANCE_COLOR[s] }))}
					value={stance}
					onChange={(id: string) => setStance(id as Stance)}
					accent={STANCE_COLOR[stance]}
					columns={3}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={UDim2.fromOffset(0, rows.stanceRow)}
					reducedMotion={p.props.reducedMotion}
				/>
				<Text value={STANCE_NOTE[stance] ?? ""} size={12} color={Palette.muted} position={UDim2.fromOffset(0, rows.noteRow)} sizeConstraint={new UDim2(1, 0, 0, NOTE_H)} fit={true} minSize={9} />
				<Text value="CREW" size={11} color={Palette.muted} weight={Enum.FontWeight.Bold} position={UDim2.fromOffset(0, rows.crewLabelRow)} sizeConstraint={new UDim2(0.3, 0, 0, LABEL_H)} />
				<Text
					value={`${crew.size()} of ${crewMax} relics chosen`}
					size={12}
					color={crew.size() > 0 ? Palette.cream : Palette.muted}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(0.3, 0, 0, rows.crewLabelRow)}
					sizeConstraint={new UDim2(0.7, 0, 0, LABEL_H)}
				/>
				{shown.map((c, i) => {
					const on = crew.includes(c.Uid);
					const tint = ROLE_COLOR[Board.roleOf(c.Def.EffectKind)];
					return (
						<Button
							key={c.Uid}
							text={c.Def.Name}
							onClick={() => toggle(c.Uid)}
							color={on ? tint : Palette.panelSoft}
							textColor={on ? Palette.ink : Palette.cream}
							outline={!on}
							highlight={on}
							size={new UDim2(1 / columns, -6, 0, CHIP_H)}
							position={new UDim2((i % columns) / columns, 0, 0, rows.crewRow + math.floor(i / columns) * (CHIP_H + 6))}
							reducedMotion={p.props.reducedMotion}
						/>
					);
				})}
				{shown.size() === 0 && (
					<Text
						value="No free relics. The route still pays, just less."
						size={13}
						color={Palette.muted}
						fit={true}
						minSize={10}
						position={UDim2.fromOffset(0, rows.crewRow + 8)}
						sizeConstraint={new UDim2(1, 0, 0, 20)}
					/>
				)}
				<Stat value={clockText(launchLength(p.props, route, odds))} caption="Time" hint="until it returns" color={Palette.cream} x={0} width={0.25} y={rows.statRow} />
				<Stat value={string.format("×%.2f", odds.Yield)} caption="Haul" hint="reward multiplier" color={Palette.mango} x={0.25} width={0.25} y={rows.statRow} />
				<Stat value={pct(odds.Risk)} caption="Risk" hint="chance of a setback" color={odds.Risk > 0 ? Palette.coral : Palette.muted} x={0.5} width={0.25} y={rows.statRow} />
				<Stat value={pct(odds.Find)} caption="Find" hint="chance of an artifact" color={odds.Find > 0 ? Palette.violet : Palette.muted} x={0.75} width={0.25} y={rows.statRow} />
				{synergyText !== "" && (
					<Text value={`Bonuses: ${synergyText}`} size={13} color={Palette.creamSoft} position={UDim2.fromOffset(0, rows.synergyRow)} sizeConstraint={new UDim2(1, 0, 0, 18)} fit={true} minSize={10} />
				)}
				<Button
					text="Launch"
					onClick={launch}
					disabled={busy || board?.Paused === true}
					loading={busy}
					shakeToken={refused}
					highlight={board?.Paused !== true}
					color={STANCE_COLOR[stance]}
					textColor={Palette.ink}
					size={new UDim2(p.stack ? 1 : 0, p.stack ? 0 : 200, 0, TapTarget)}
					position={UDim2.fromOffset(0, rows.launchRow)}
					reducedMotion={p.props.reducedMotion}
				/>
			</frame>
		</Panel>
	);
}

// header, route + stance, timer over a meter, crew line, odds line, button
const RUN_ODDS_ROW = 132;
const RUN_H = PAD * 2 + RUN_ODDS_ROW + 18 + GAP + TapTarget;

function RunningSlot(p: { props: Props; slot: SlotState; route?: Route; defs: Map<string, ItemDef>; now: number; onResult: (reply: Reply) => void }) {
	const [busy, setBusy] = React.useState(false);
	const total = math.max(1, p.slot.EndsAt - p.slot.StartedAt);
	const left = math.max(0, p.slot.EndsAt - p.now);
	const done = left <= 0;
	const stance: Stance = p.slot.Stance ?? "Steady";
	const inventory = p.props.state.Items?.Inventory ?? {};
	const names = p.slot.Crew.map((uid) => p.defs.get(inventory[uid]?.DefinitionId ?? "")?.Name ?? "Relic");
	const accent = done ? Palette.mint : STANCE_COLOR[stance];
	const odds = [string.format("×%.2f haul", p.slot.Yield ?? 1)];
	if ((p.slot.Risk ?? 0) > 0) odds.push(`${pct(p.slot.Risk ?? 0)} risk of a setback`);
	if ((p.slot.Find ?? 0) > 0) odds.push(`${pct(p.slot.Find ?? 0)} artifact find`);
	const act = (op: "Claim" | "Recall") => {
		if (busy) return;
		setBusy(true);
		p.props.dispatch("ExpeditionAct", { Op: op, Slot: p.slot.Slot }, (response) => {
			setBusy(false);
			if (op === "Claim" && response.ok === true) p.onResult(response);
		});
	};
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={accent} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion} highlight={done} clips={false}>
			<Text value={`Slot ${p.slot.Slot}`} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(0.5, 0, 0, HEAD_H)} />
			<Text
				value={done ? "Back, ready to claim" : "Out on a trip"}
				size={13}
				color={accent}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(0.5, 0, 0, 2)}
				sizeConstraint={new UDim2(0.5, 0, 0, 18)}
			/>
			<Text value={p.route?.Name ?? p.slot.Id} size={18} color={Palette.cream} weight={Enum.FontWeight.Bold} fit={true} minSize={12} position={UDim2.fromOffset(0, 32)} sizeConstraint={new UDim2(1, -170, 0, 24)} />
			<Text value={`${stance} stance`} size={13} color={STANCE_COLOR[stance]} position={UDim2.fromOffset(0, 58)} sizeConstraint={new UDim2(1, -170, 0, 16)} />
			<Text
				value={done ? "Back" : clockText(left)}
				size={28}
				color={done ? Palette.mint : Palette.cream}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -170, 0, 26)}
				sizeConstraint={new UDim2(0, 170, 0, 34)}
				fit={true}
				minSize={16}
			/>
			<Text
				value={done ? "trip finished" : "time left"}
				size={12}
				color={Palette.muted}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -170, 0, 60)}
				sizeConstraint={new UDim2(0, 170, 0, 16)}
			/>
			<Meter value={done ? 1 : 1 - left / total} color={accent} position={UDim2.fromOffset(0, 86)} size={new UDim2(1, 0, 0, 10)} reducedMotion={p.props.reducedMotion} shimmer={done} />
			<Text
				value={names.size() > 0 ? `Crew: ${names.join("  ·  ")}` : "Solo run, no relics sent"}
				size={13}
				color={Palette.creamSoft}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 106)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
			<Text value={odds.join("  ·  ")} size={13} color={Palette.muted} position={UDim2.fromOffset(0, RUN_ODDS_ROW - 2)} sizeConstraint={new UDim2(1, 0, 0, 18)} fit={true} minSize={10} />
			<Button
				text={done ? "Claim" : "Recall"}
				onClick={() => act(done ? "Claim" : "Recall")}
				disabled={busy}
				loading={busy}
				color={done ? Palette.mint : Palette.panelSoft}
				textColor={done ? Palette.ink : Palette.cream}
				outline={!done}
				highlight={done}
				size={new UDim2(0, 180, 0, TapTarget)}
				position={UDim2.fromOffset(0, RUN_ODDS_ROW + 18 + GAP)}
				reducedMotion={p.props.reducedMotion}
			/>
		</Panel>
	);
}

const BANNER_H = PAD * 2 + 34 + 20;
const BANNER_SECONDS = 6;

function ResultBanner(p: { reply: Reply; routeName: string; reducedMotion?: boolean }) {
	const outcome = p.reply.Outcome ?? "Clean";
	const streak = p.reply.Streak ?? 0;
	const tail = outcome === "Setback" ? "Streak reset" : streak > 1 ? `${streak} clean trips in a row` : p.routeName;
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={OUTCOME_COLOR[outcome]} background={Palette.panelRaised} padding={PAD} reducedMotion={p.reducedMotion} highlight={outcome === "Triumph"}>
			<Text value={outcome} size={28} color={OUTCOME_COLOR[outcome]} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(0.5, 0, 0, 34)} fit={true} minSize={16} />
			<Text value={tail} size={14} color={Palette.creamSoft} align={Enum.TextXAlignment.Right} position={new UDim2(0.5, 0, 0, 8)} sizeConstraint={new UDim2(0.5, 0, 0, 20)} fit={true} minSize={10} />
			<Text value={p.reply.message ?? ""} size={13} color={Palette.muted} position={UDim2.fromOffset(0, 36)} sizeConstraint={new UDim2(1, 0, 0, 18)} fit={true} minSize={10} />
		</Panel>
	);
}

function playOutcome(reply: Reply) {
	if (reply.Outcome === "Triumph") ScreenFx.play("milestone", 1.1);
	else if (reply.Outcome === "Setback") ScreenFx.play("warning", 0.9);
	else ScreenFx.play("success", reply.ArtifactNew === true ? 1.2 : 0.9);
}

function ExpeditionsView(props: Props) {
	const viewport = useViewport();
	const stack = chromeFor(viewport).contentStack;
	const board = props.state.ExpeditionBoard;
	const slots = board?.Slots ?? [];
	const running = slots.some((slot) => slot.Id !== "");
	const [result, setResult] = React.useState<{ reply: Reply; at: number } | undefined>(undefined);
	const now = useServerClock(running || result !== undefined);
	const routes = props.config.Operations?.Expeditions ?? [];
	const defs = defsById(props.config);
	const candidates = candidatesOf(props, defs);
	const busyRoutes = new Set<string>();
	for (const slot of slots) if (slot.Id !== "") busyRoutes.add(slot.Id);
	const onResult = (reply: Reply) => {
		playOutcome(reply);
		setResult({ reply, at: os.time() });
	};
	React.useEffect(() => {
		if (result === undefined) return;
		const thread = task.delay(BANNER_SECONDS, () => setResult(undefined));
		return () => task.cancel(thread);
	}, [result]);
	const sections: { id: string; height: number; element: React.Element }[] = [];
	if (result !== undefined) {
		const routeName = routes.find((r) => r.Id === result.reply.Route)?.Name ?? "";
		sections.push({
			id: `result${result.at}`,
			height: BANNER_H,
			element: <ResultBanner reply={result.reply} routeName={routeName} reducedMotion={props.reducedMotion} />,
		});
	}
	const streak = board?.Streak ?? 0;
	const best = board?.Best ?? 0;
	const out = slots.filter((slot) => slot.Id !== "").size();
	const streakBonus = math.min(streak, Board.STREAK_CAP) * Board.STREAK_STEP;
	const streakText =
		streak > 0
			? `Streak ${streak} · +${math.floor(streakBonus * 100 + 0.5)}% haul${best > streak ? ` · best ${best}` : ""}`
			: best > 0
				? `No streak · best ${best}`
				: "Clean trips in a row add haul";
	sections.push({
		id: "summary",
		height: 40,
		element: (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Text value={`${out} of ${slots.size()} slots out`} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(0.4, 0, 0, 24)} fit={true} minSize={11} />
				<Text
					value={streakText}
					size={14}
					color={streak > 0 ? Palette.mango : Palette.muted}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(0.4, 0, 0, 2)}
					sizeConstraint={new UDim2(0.6, 0, 0, 20)}
					fit={true}
					minSize={10}
				/>
			</frame>
		),
	});
	if (board?.Paused === true) {
		sections.push({
			id: "paused",
			height: 28,
			element: <Text value="Paused for a moment. Running trips keep going." size={13} color={Palette.mango} fit={true} minSize={10} />,
		});
	}
	for (const slot of slots) {
		if (slot.Id === "") {
			sections.push({
				id: `slot${slot.Slot}`,
				height: openRows(candidates.size(), stack).height,
				element: <OpenSlot props={props} slot={slot} routes={routes} busyRoutes={busyRoutes} candidates={candidates} stack={stack} />,
			});
		} else {
			sections.push({
				id: `slot${slot.Slot}`,
				height: RUN_H,
				element: <RunningSlot props={props} slot={slot} route={routes.find((r) => r.Id === slot.Id)} defs={defs} now={now} onResult={onResult} />,
			});
		}
	}
	return <PageScaffold sections={sections} gap={16} tailPad={stack ? 12 : 18} owner="ExpeditionsView" />;
}
export = { ExpeditionsView };
