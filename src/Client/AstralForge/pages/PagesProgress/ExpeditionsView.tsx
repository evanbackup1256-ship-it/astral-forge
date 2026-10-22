// Expeditions v2. One card per slot. An open slot picks a route, a stance and up to three relics,
// and shows the exact forecast the server will lock in (time, haul, risk, find) with the synergies
// that apply. A running slot is a big timer over a meter; a finished one claims, and the outcome
// lands as a banner at the top with a screen moment to match: Triumph, Clean or Setback.
import React from "@rbxts/react";
import Board = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import { clockText } from "../../CoreKit/format";
import { chromeFor, Palette, TapTarget } from "../../CoreKit/theme";
import { useViewport } from "../../MotionKit/motion";
import { useServerClock } from "../../hooks/useServerClock";
import { ScreenFx } from "../../UiCore/screenFx";
import { loadPageScaffold, loadUi } from "../luauDeps";
import { SplitColumns, splitColumns, StackBlocks, stackHeight } from "../../UiCore/ui";

const { Button, Dropdown, EmptyState, Meter, Panel, SegmentedTabs, Text } = loadUi();
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
// the compact EmptyState shown when no relic is free for a crew
const EMPTY_CREW_H = 112;
const STAT_H = 52;
const MAX_SHOWN = 8;

const ROLE_COLOR: Record<Role, Color3> = { Haul: Palette.mango, Guard: Palette.mint, Scout: Palette.cyan };
const STANCE_COLOR: Record<Stance, Color3> = { Careful: Palette.mint, Steady: Palette.cyan, Daring: Palette.coral };
const OUTCOME_COLOR: Record<Outcome, Color3> = { Triumph: Palette.violet, Clean: Palette.mint, Setback: Palette.coral };
const SYNERGY_TEXT: Record<string, string> = {
	Favoured: "favoured",
	Balanced: "balanced crew",
	Resonant: "resonant",
	Companion: "companion",
	Streak: "streak",
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

function Stat(p: { value: string; caption: string; color: Color3; x: number; width: number; y: number }) {
	return (
		<frame BackgroundTransparency={1} BorderSizePixel={0} Position={new UDim2(p.x, 0, 0, p.y)} Size={new UDim2(p.width, -8, 0, STAT_H)}>
			<Text value={p.value} size={22} color={p.color} weight={Enum.FontWeight.Bold} fit={true} minSize={14} sizeConstraint={new UDim2(1, 0, 0, 30)} />
			<Text value={p.caption} size={12} color={Palette.muted} position={UDim2.fromOffset(0, 32)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
		</frame>
	);
}

// crew chips per row: two on phones, three in the narrower desktop column, four full width
function crewColumns(stack: boolean, wide: boolean): number {
	return stack ? 2 : wide ? 3 : 4;
}

// the four forecast stats sit in one row, or two rows of two on phones
function statsHeight(stack: boolean): number {
	return stack ? STAT_H * 2 + 6 : STAT_H;
}

function openSlotHeight(candidates: number, stack: boolean, wide = false): number {
	const columns = crewColumns(stack, wide);
	const rows = math.max(1, math.ceil(math.min(MAX_SHOWN, candidates) / columns));
	const top = stack ? TapTarget * 2 + GAP : TapTarget;
	const crew = candidates === 0 ? EMPTY_CREW_H : rows * (CHIP_H + 6);
	return PAD * 2 + top + GAP + TapTarget + GAP * 2 + crew + GAP + statsHeight(stack) + 20 + GAP + TapTarget;
}

function OpenSlot(p: { props: Props; slot: SlotState; routes: Route[]; busyRoutes: Set<string>; candidates: Candidate[]; stack: boolean; wide?: boolean }) {
	const board = p.props.state.ExpeditionBoard;
	const level = p.props.state.Command?.Level ?? 1;
	const open = p.routes.filter((route) => route.RequiredLevel <= level && !p.busyRoutes.has(route.Id));
	const [routeId, setRouteId] = React.useState<string | undefined>(undefined);
	const [stance, setStance] = React.useState<Stance>("Steady");
	const [crew, setCrew] = React.useState<string[]>([]);
	const [busy, setBusy] = React.useState(false);
	const route = open.find((r) => r.Id === routeId) ?? open[open.size() - 1];
	const crewMax = board?.CrewMax ?? Board.CREW_MAX;
	const shown = p.candidates.filter((_, i) => i < MAX_SHOWN);
	const picked = shown.filter((c) => crew.includes(c.Uid));
	const odds = route !== undefined ? Board.forecast(route.Id, stance, picked.map(member), board?.Companion, board?.Streak ?? 0) : undefined;
	const columns = crewColumns(p.stack, p.wide === true);
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
				ScreenFx.play("error", 0.6);
			}
		});
	};
	if (open.size() === 0 || route === undefined || odds === undefined) {
		return (
			<Panel size={UDim2.fromScale(1, 1)} accent={Palette.lineSoft} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion}>
				<Text value="Every route you can run is out." size={14} color={Palette.muted} fit={true} minSize={10} sizeConstraint={new UDim2(1, 0, 0, 20)} />
			</Panel>
		);
	}
	const role = odds.Role;
	let y = 0;
	const routeRow = y;
	y += p.stack ? TapTarget * 2 + GAP : TapTarget;
	const stanceRow = y + GAP;
	y = stanceRow + TapTarget + GAP * 2;
	const crewRow = y;
	const rows = math.max(1, math.ceil(shown.size() / columns));
	y += (shown.size() === 0 ? EMPTY_CREW_H : rows * (CHIP_H + 6)) + GAP;
	const statRow = y;
	y += statsHeight(p.stack);
	const synergyRow = y;
	y += 20 + GAP;
	const launchRow = y;
	const synergyText = odds.Synergies.map((s) => SYNERGY_TEXT[s] ?? s).join("  ·  ");
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={STANCE_COLOR[stance]} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion} clips={false}>
			<frame Size={new UDim2(1, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Dropdown
					options={open.map((r) => ({ id: r.Id, label: r.Name, detail: clockText(r.Duration) }))}
					value={route.Id}
					onChange={(id: string) => setRouteId(id)}
					accent={ROLE_COLOR[role]}
					size={new UDim2(p.stack ? 1 : 0.6, 0, 0, TapTarget)}
					position={UDim2.fromOffset(0, routeRow)}
					reducedMotion={p.props.reducedMotion}
					zIndex={40 + (10 - p.slot.Slot)}
				/>
				<frame
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Position={p.stack ? UDim2.fromOffset(0, routeRow + TapTarget + GAP) : new UDim2(0.6, 16, 0, routeRow)}
					Size={new UDim2(p.stack ? 1 : 0.4, p.stack ? 0 : -16, 0, TapTarget)}
				>
					<frame
						BackgroundColor3={ROLE_COLOR[role]}
						BorderSizePixel={0}
						AnchorPoint={new Vector2(0, 0.5)}
						Position={new UDim2(0, 0, 0.5, 0)}
						Size={UDim2.fromOffset(10, 10)}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
					<Text
						value={`${role} route`}
						size={14}
						color={Palette.creamSoft}
						position={new UDim2(0, 20, 0.5, -10)}
						sizeConstraint={new UDim2(1, -20, 0, 20)}
						fit={true}
						minSize={10}
					/>
				</frame>
				<SegmentedTabs
					options={Board.STANCES.map((s) => ({ id: s, label: s, accent: STANCE_COLOR[s] }))}
					value={stance}
					onChange={(id: string) => setStance(id as Stance)}
					accent={STANCE_COLOR[stance]}
					columns={3}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={UDim2.fromOffset(0, stanceRow)}
					reducedMotion={p.props.reducedMotion}
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
							position={new UDim2((i % columns) / columns, 0, 0, crewRow + math.floor(i / columns) * (CHIP_H + 6))}
							reducedMotion={p.props.reducedMotion}
						/>
					);
				})}
				{shown.size() === 0 && (
					<frame BackgroundTransparency={1} BorderSizePixel={0} Position={UDim2.fromOffset(0, crewRow)} Size={new UDim2(1, 0, 0, EMPTY_CREW_H)}>
						<EmptyState
							icon="Artifact"
							title="No free relics."
							body="The route still pays."
							compact={true}
							reducedMotion={p.props.reducedMotion}
						/>
					</frame>
				)}
				<Stat value={clockText(launchLength(p.props, route, odds))} caption="time" color={Palette.cream} x={0} width={p.stack ? 0.5 : 0.25} y={statRow} />
				<Stat value={string.format("×%.2f", odds.Yield)} caption="haul" color={Palette.mango} x={p.stack ? 0.5 : 0.25} width={p.stack ? 0.5 : 0.25} y={statRow} />
				<Stat value={pct(odds.Risk)} caption="risk" color={odds.Risk > 0 ? Palette.coral : Palette.muted} x={p.stack ? 0 : 0.5} width={p.stack ? 0.5 : 0.25} y={p.stack ? statRow + STAT_H + 6 : statRow} />
				<Stat value={pct(odds.Find)} caption="find" color={odds.Find > 0 ? Palette.violet : Palette.muted} x={p.stack ? 0.5 : 0.75} width={p.stack ? 0.5 : 0.25} y={p.stack ? statRow + STAT_H + 6 : statRow} />
				{synergyText !== "" && (
					<Text value={synergyText} size={13} color={Palette.creamSoft} position={UDim2.fromOffset(0, synergyRow)} sizeConstraint={new UDim2(1, 0, 0, 18)} fit={true} minSize={10} />
				)}
				<Button
					text="Launch"
					onClick={launch}
					disabled={busy || board?.Paused === true}
					loading={busy}
					color={STANCE_COLOR[stance]}
					textColor={Palette.ink}
					size={new UDim2(p.stack ? 1 : 0, p.stack ? 0 : 200, 0, TapTarget)}
					position={UDim2.fromOffset(0, launchRow)}
					reducedMotion={p.props.reducedMotion}
				/>
			</frame>
		</Panel>
	);
}

const RUN_H = PAD * 2 + 34 + 12 + 10 + 14 + 18 + 6 + 18 + GAP + TapTarget;

function RunningSlot(p: { props: Props; slot: SlotState; route?: Route; defs: Map<string, ItemDef>; now: number; onResult: (reply: Reply) => void; stack?: boolean }) {
	const timerW = p.stack === true ? 104 : 150;
	const [busy, setBusy] = React.useState(false);
	const total = math.max(1, p.slot.EndsAt - p.slot.StartedAt);
	const left = math.max(0, p.slot.EndsAt - p.now);
	const done = left <= 0;
	const stance: Stance = p.slot.Stance ?? "Steady";
	const inventory = p.props.state.Items?.Inventory ?? {};
	const names = p.slot.Crew.map((uid) => p.defs.get(inventory[uid]?.DefinitionId ?? "")?.Name ?? "Relic");
	const accent = done ? Palette.mint : STANCE_COLOR[stance];
	const odds = [string.format("×%.2f", p.slot.Yield ?? 1)];
	if ((p.slot.Risk ?? 0) > 0) odds.push(`${pct(p.slot.Risk ?? 0)} risk`);
	if ((p.slot.Find ?? 0) > 0) odds.push(`${pct(p.slot.Find ?? 0)} find`);
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
			<Text value={p.route?.Name ?? p.slot.Id} size={18} color={Palette.cream} weight={Enum.FontWeight.Bold} fit={true} minSize={12} sizeConstraint={new UDim2(1, -timerW, 0, 24)} />
			<Text value={stance} size={13} color={STANCE_COLOR[stance]} position={UDim2.fromOffset(0, 24)} sizeConstraint={new UDim2(1, -timerW, 0, 16)} />
			<Text
				value={done ? "Back" : clockText(left)}
				size={28}
				color={done ? Palette.mint : Palette.cream}
				weight={Enum.FontWeight.Bold}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -timerW, 0, 0)}
				sizeConstraint={new UDim2(0, timerW, 0, 34)}
				fit={true}
				minSize={16}
			/>
			<Meter value={1 - left / total} color={accent} position={UDim2.fromOffset(0, 46)} size={new UDim2(1, 0, 0, 10)} reducedMotion={p.props.reducedMotion} shimmer={done} />
			<Text
				value={names.size() > 0 ? names.join("  ·  ") : "Solo run"}
				size={13}
				color={Palette.creamSoft}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 70)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
			<Text value={odds.join("  ·  ")} size={13} color={Palette.muted} position={UDim2.fromOffset(0, 94)} sizeConstraint={new UDim2(1, 0, 0, 18)} fit={true} minSize={10} />
			<Button
				text={done ? "Claim" : "Recall"}
				onClick={() => act(done ? "Claim" : "Recall")}
				disabled={busy}
				loading={busy}
				color={done ? Palette.mint : Palette.panelSoft}
				textColor={done ? Palette.ink : Palette.cream}
				outline={!done}
				highlight={done}
				size={p.stack === true ? new UDim2(1, 0, 0, TapTarget) : new UDim2(0, 180, 0, TapTarget)}
				position={UDim2.fromOffset(0, 94 + 18 + GAP)}
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
	const tail = outcome === "Setback" ? "streak reset" : streak > 1 ? `${streak} in a row` : p.routeName;
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
	const plan = splitColumns(stack ? 0 : viewport.width, math.floor(viewport.width * 0.42), 16);
	const wide = plan.split;
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
	const out = slots.filter((slot) => slot.Id !== "").size();
	sections.push({
		id: "summary",
		height: 40,
		element: (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<Text value={`${out} / ${slots.size()} out`} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} sizeConstraint={new UDim2(0.5, 0, 0, 24)} />
				<Text
					value={streak > 0 ? `streak ${streak}  ·  ${string.format("+%d%%", math.min(streak, Board.STREAK_CAP) * Board.STREAK_STEP * 100)}` : ""}
					size={14}
					color={Palette.mango}
					align={Enum.TextXAlignment.Right}
					position={new UDim2(0.5, 0, 0, 2)}
					sizeConstraint={new UDim2(0.5, 0, 0, 20)}
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
	// open slots (the launch planner) and running trips; on desktop they sit side by side
	const openBlocks: { id: string; height: number; element: React.Element }[] = [];
	const runBlocks: { id: string; height: number; element: React.Element }[] = [];
	const splitWide = wide && slots.some((slot) => slot.Id === "") && running;
	for (const slot of slots) {
		if (slot.Id === "") {
			openBlocks.push({
				id: `slot${slot.Slot}`,
				height: openSlotHeight(candidates.size(), stack, splitWide),
				element: <OpenSlot props={props} slot={slot} routes={routes} busyRoutes={busyRoutes} candidates={candidates} stack={stack} wide={splitWide} />,
			});
		} else {
			runBlocks.push({
				id: `slot${slot.Slot}`,
				height: RUN_H,
				element: <RunningSlot props={props} slot={slot} route={routes.find((r) => r.Id === slot.Id)} defs={defs} now={now} onResult={onResult} stack={stack} />,
			});
		}
	}
	if (splitWide) {
		sections.push({
			id: "slots",
			height: math.max(stackHeight(openBlocks.map((b) => b.height), 16), stackHeight(runBlocks.map((b) => b.height), 16)),
			element: (
				<SplitColumns
					plan={plan}
					height={math.max(stackHeight(openBlocks.map((b) => b.height), 16), stackHeight(runBlocks.map((b) => b.height), 16))}
					sideOnRight={true}
					main={<StackBlocks gap={16} blocks={openBlocks} />}
					side={<StackBlocks gap={16} blocks={runBlocks} />}
				/>
			),
		});
	} else {
		// running trips first so a finished claim is never below the fold
		for (const block of runBlocks) sections.push(block);
		for (const block of openBlocks) sections.push(block);
	}
	return <PageScaffold sections={sections} gap={16} tailPad={stack ? 12 : 18} owner="ExpeditionsView" />;
}
export = { ExpeditionsView };
