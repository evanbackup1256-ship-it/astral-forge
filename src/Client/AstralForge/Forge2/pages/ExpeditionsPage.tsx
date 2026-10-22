// Expeditions v2 on Forge2. One card per slot. An open slot picks a route, a stance (Careful,
// Steady, Daring) and up to CrewMax relics, and shows the forecast the server locks in: time, haul,
// risk, find, plus the synergies that apply (crew roles Haul / Guard / Scout, companion, streak).
// A running slot is a timer over a meter; a finished one claims, and the outcome (Triumph, Clean,
// Setback) lands as a banner with the matching screen moment.
// Remote: ExpeditionAct { Op: Launch, Slot, Id, Crew, Stance } | { Op: Claim | Recall, Slot }
import React from "@rbxts/react";
import Board = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import { Audio } from "../../AudioKit/audio";
import { clockText } from "../../CoreKit/format";
import { Palette } from "../../CoreKit/theme";
import { useServerClock } from "../../hooks/useServerClock";
import { useChangePop, useFlash, useStagger } from "../../MotionKit/motion";
import { ScreenFx } from "../../UiCore/screenFx";
import { Button } from "../design/Button";
import { EmptyState } from "../design/Layers";
import { Card, Meter, Panel } from "../design/Panel";
import { Chip, Tab } from "../design/Pick";
import { Text, Title } from "../design/Text";
import { Fonts, gap, Iron, Type } from "../design/tokens";
import { Burst } from "../motion/motion";
import type { PageProps } from "../router/routes";

type Stance = (typeof Board.STANCES)[number];
type Role = (typeof Board.ROLES)[number];
type Forecast = ReturnType<typeof Board.forecast>;
type Outcome = ReturnType<typeof Board.outcomeFor>;

interface ExpReply {
	ok?: boolean;
	message?: string;
	Outcome?: Outcome;
	Streak?: number;
	Route?: string;
	ArtifactNew?: boolean;
}
interface Route {
	Id: string;
	Name: string;
	Duration: number;
	RequiredLevel: number;
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
interface ExpSession {
	ExpeditionBoard?: BoardState;
	Command?: { Level?: number; Crew?: { Pilot?: number } };
	Items?: { Inventory?: Record<string, { DefinitionId: string; Stars?: number }>; Equipped?: Record<string, string> };
}
interface ExpConfig {
	Operations?: { Expeditions?: Route[] };
	Items?: { Definitions?: ItemDef[] };
}
interface Candidate {
	Uid: string;
	Def: ItemDef;
	Stars: number;
}

const SHOWN = 8;
const ROLE_COLOR: Record<Role, () => Color3> = { Haul: () => Palette.mango, Guard: () => Palette.mint, Scout: () => Palette.cyan };
const STANCE_COLOR: Record<Stance, () => Color3> = { Careful: () => Palette.mint, Steady: () => Palette.cyan, Daring: () => Palette.coral };
const STANCE_LINE: Record<Stance, string> = { Careful: "Safer, smaller haul.", Steady: "Even odds.", Daring: "Bigger haul, more can go wrong." };
const OUTCOME_COLOR: Record<Outcome, () => Color3> = { Triumph: () => Palette.violet, Clean: () => Palette.mint, Setback: () => Palette.coral };
const SYNERGY: Record<string, string> = { Favoured: "favoured", Balanced: "balanced crew", Resonant: "resonant", Companion: "companion", Streak: "streak" };

const member = (c: Candidate) => ({ Rarity: c.Def.Rarity, EffectKind: c.Def.EffectKind, Stars: c.Stars });
const pct = (v: number) => `${math.floor(v * 100 + 0.5)}%`;

function freeRelics(session: ExpSession, defs: Map<string, ItemDef>): Candidate[] {
	const busy = new Set<string>();
	for (const [, uid] of pairs(session.Items?.Equipped ?? {})) busy.add(uid);
	for (const slot of session.ExpeditionBoard?.Slots ?? []) for (const uid of slot.Crew) busy.add(uid);
	const out: Candidate[] = [];
	for (const [uid, inst] of pairs(session.Items?.Inventory ?? {})) {
		const def = defs.get(inst.DefinitionId);
		if (def !== undefined && !busy.has(uid as string)) out.push({ Uid: uid as string, Def: def, Stars: inst.Stars ?? 0 });
	}
	const power = (c: Candidate) => Board.crewPower([member(c)]);
	out.sort((a, b) => (power(a) !== power(b) ? power(a) > power(b) : a.Uid < b.Uid));
	return out;
}

function tripLength(session: ExpSession, route: Route, odds: Forecast): number {
	const pilot = session.Command?.Crew?.Pilot ?? 1;
	const base = math.max(10, math.floor(route.Duration * math.max(0.35, 1 - (pilot - 1) * 0.05)));
	return math.max(10, math.floor(base * odds.Time * (1 - (session.ExpeditionBoard?.Speed ?? 0))));
}

function Row(props: { order: number; children?: React.ReactNode }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} VerticalAlignment={Enum.VerticalAlignment.Center} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
		</frame>
	);
}

function Figure(props: { value: string; caption: string; color: Color3; phone: boolean; order: number }) {
	const pop = useChangePop(props.value);
	return (
		<frame Size={new UDim2(props.phone ? 0.5 : 0.25, -8, 0, 54)} BackgroundTransparency={1} LayoutOrder={props.order}>
			<uiscale Scale={pop} />
			<Text text={props.value} size={22} font={Fonts.heavy} color={props.color} box={new UDim2(1, 0, 0, 30)} />
			<Text text={props.caption} size={Type.small(props.phone)} color={Iron.muted()} box={new UDim2(1, 0, 0, 16)} position={UDim2.fromOffset(0, 32)} />
		</frame>
	);
}

function OpenSlot(p: { page: PageProps; session: ExpSession; slot: SlotState; routes: Route[]; taken: Set<string>; relics: Candidate[]; order: number }) {
	const phone = p.page.phone;
	const board = p.session.ExpeditionBoard;
	const level = p.session.Command?.Level ?? 1;
	const open = p.routes.filter((r) => r.RequiredLevel <= level && !p.taken.has(r.Id));
	const [routeId, setRouteId] = React.useState<string | undefined>(undefined);
	const [stance, setStance] = React.useState<Stance>("Steady");
	const [crew, setCrew] = React.useState<string[]>([]);
	const [busy, setBusy] = React.useState(false);
	const rise = useStagger(p.order + 1);
	const route = open.find((r) => r.Id === routeId) ?? open[open.size() - 1];
	const crewMax = board?.CrewMax ?? Board.CREW_MAX;
	const shown = p.relics.filter((_, i) => i < SHOWN);
	const picked = shown.filter((c) => crew.includes(c.Uid));
	if (route === undefined) {
		return (
			<Card pad={gap(phone, "l")} order={p.order} color={Iron.sunk()}>
				<Text text="Every route you can run is already out." size={Type.body(phone)} color={Iron.muted()} multiline />
			</Card>
		);
	}
	const odds = Board.forecast(route.Id, stance, picked.map(member), board?.Companion, board?.Streak ?? 0);
	const role = odds.Role as Role;
	const toggle = (uid: string) => {
		if (crew.includes(uid)) setCrew(crew.filter((u) => u !== uid));
		else if (crew.size() < crewMax) setCrew([...crew, uid]);
		Audio.play("click");
	};
	const launch = () => {
		if (busy) return;
		setBusy(true);
		p.page.request("ExpeditionAct", { Op: "Launch", Slot: p.slot.Slot, Id: route.Id, Crew: crew, Stance: stance }, (reply) => {
			setBusy(false);
			if (reply.ok === true) {
				setCrew([]);
				ScreenFx.play("confirm", stance === "Daring" ? 1.2 : 0.8);
			} else {
				ScreenFx.play("error", 0.6);
			}
		});
	};
	const synergies = odds.Synergies.map((s) => SYNERGY[s] ?? s).join(" · ");
	return (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={p.order} Position={rise.map((v) => UDim2.fromOffset(0, (1 - v) * 12))}>
			<Card accent={STANCE_COLOR[stance]()} pad={gap(phone, "l")} spacing={gap(phone, "m")}>
				<Text text={`Slot ${p.slot.Slot} · route`} size={Type.small(phone)} color={Iron.muted()} order={0} />
				<Row order={1}>
					{open.map((r, i) => (
						<Chip key={r.Id} text={`${r.Name} · ${clockText(r.Duration)}`} on={r.Id === route.Id} color={ROLE_COLOR[role]()} order={i} onPress={() => setRouteId(r.Id)} />
					))}
				</Row>
				<Text text={`${role} route`} size={Type.small(phone)} color={ROLE_COLOR[role]()} order={2} />
				<Row order={3}>
					{Board.STANCES.map((s, i) => (
						<Tab key={s} text={s} active={s === stance} width={phone ? 96 : 120} order={i} onPress={() => setStance(s)} />
					))}
				</Row>
				<Text text={STANCE_LINE[stance]} size={Type.small(phone)} color={Iron.muted()} order={4} />
				<Text text={`Crew ${crew.size()}/${crewMax}`} size={Type.small(phone)} color={Iron.muted()} order={5} />
				{shown.size() === 0 ? (
					<EmptyState title="No free relics" body="The route still pays without a crew." phone={phone} order={6} />
				) : (
					<Row order={6}>
						{shown.map((c, i) => (
							<Chip key={c.Uid} text={c.Def.Name} on={crew.includes(c.Uid)} color={ROLE_COLOR[Board.roleOf(c.Def.EffectKind) as Role]()} order={i} onPress={() => toggle(c.Uid)} />
						))}
					</Row>
				)}
				<Row order={7}>
					<Figure value={clockText(tripLength(p.session, route, odds))} caption="time" color={Iron.text()} phone={phone} order={0} />
					<Figure value={string.format("×%.2f", odds.Yield)} caption="haul" color={Palette.mango} phone={phone} order={1} />
					<Figure value={pct(odds.Risk)} caption="risk" color={odds.Risk > 0 ? Palette.coral : Iron.muted()} phone={phone} order={2} />
					<Figure value={pct(odds.Find)} caption="find" color={odds.Find > 0 ? Palette.violet : Iron.muted()} phone={phone} order={3} />
				</Row>
				{synergies !== "" && <Text text={synergies} size={Type.small(phone)} color={Iron.soft()} order={8} />}
				<Button text="Launch" tone={stance === "Daring" ? "ember" : "brass"} width={phone ? 200 : 220} busy={busy} disabled={board?.Paused === true} glint onPress={launch} order={9} />
			</Card>
		</frame>
	);
}

function RunningSlot(p: { page: PageProps; session: ExpSession; slot: SlotState; route?: Route; defs: Map<string, ItemDef>; now: number; order: number; onResult: (r: ExpReply) => void }) {
	const phone = p.page.phone;
	const [busy, setBusy] = React.useState(false);
	const total = math.max(1, p.slot.EndsAt - p.slot.StartedAt);
	const left = math.max(0, p.slot.EndsAt - p.now);
	const done = left <= 0;
	const stance: Stance = p.slot.Stance ?? "Steady";
	const inv = p.session.Items?.Inventory ?? {};
	const names = p.slot.Crew.map((uid) => p.defs.get(inv[uid]?.DefinitionId ?? "")?.Name ?? "Relic");
	const accent = done ? Palette.mint : STANCE_COLOR[stance]();
	const odds = [string.format("×%.2f", p.slot.Yield ?? 1)];
	if ((p.slot.Risk ?? 0) > 0) odds.push(`${pct(p.slot.Risk ?? 0)} risk`);
	if ((p.slot.Find ?? 0) > 0) odds.push(`${pct(p.slot.Find ?? 0)} find`);
	const act = (op: "Claim" | "Recall") => {
		if (busy) return;
		setBusy(true);
		p.page.request("ExpeditionAct", { Op: op, Slot: p.slot.Slot }, (reply) => {
			setBusy(false);
			if (op === "Claim" && reply.ok === true) p.onResult(reply as ExpReply);
		});
	};
	return (
		<Card accent={accent} pad={gap(phone, "l")} spacing={gap(phone, "s")} selected={done} order={p.order}>
			<Row order={0}>
				<Text text={p.route?.Name ?? p.slot.Id} size={Type.body(phone) + 1} font={Fonts.heavy} box={new UDim2(1, -150, 0, 26)} order={0} />
				<Text text={done ? "Back" : clockText(left)} size={28} font={Fonts.heavy} color={done ? Palette.mint : Iron.text()} align="Right" box={UDim2.fromOffset(140, 34)} order={1} />
			</Row>
			<Text text={stance} size={Type.small(phone)} color={STANCE_COLOR[stance]()} order={1} />
			<Meter value={1 - left / total} color={accent} height={10} order={2} />
			<Text text={names.size() > 0 ? names.join(" · ") : "Solo run"} size={Type.small(phone)} color={Iron.soft()} order={3} />
			<Text text={odds.join(" · ")} size={Type.small(phone)} color={Iron.muted()} order={4} />
			<Button text={done ? "Claim" : "Recall"} tone={done ? "brass" : "iron"} width={180} busy={busy} glint={done} onPress={() => act(done ? "Claim" : "Recall")} order={5} />
		</Card>
	);
}

function Outcome(p: { reply: ExpReply; routeName: string; phone: boolean }) {
	const outcome: Outcome = p.reply.Outcome ?? "Clean";
	const streak = p.reply.Streak ?? 0;
	const tail = outcome === "Setback" ? "Streak reset" : streak > 1 ? `${streak} in a row` : p.routeName;
	const flash = useFlash(1, false, 0.5);
	return (
		<Panel pad={gap(p.phone, "l")} spacing={6} seam={outcome === "Triumph"} rarity="Mythic" color={Iron.raised()} scale={flash.map((v) => 1 + v * 0.03)} order={0}>
			<Title text={outcome} size={Type.title(p.phone)} color={OUTCOME_COLOR[outcome]()} tags={outcome === "Triumph" ? ["rainbow", "wave"] : outcome === "Setback" ? ["shake"] : ["wave"]} order={0} />
			<Text text={tail} size={Type.body(p.phone)} color={Iron.soft()} order={1} />
			{p.reply.message !== undefined && <Text text={p.reply.message} size={Type.small(p.phone)} color={Iron.muted()} multiline order={2} />}
		</Panel>
	);
}

function playOutcome(reply: ExpReply) {
	if (reply.Outcome === "Triumph") {
		ScreenFx.play("milestone", 1.1);
		Burst.spark(Palette.violet, 1);
	} else if (reply.Outcome === "Setback") ScreenFx.play("warning", 0.9);
	else ScreenFx.play("success", reply.ArtifactNew === true ? 1.2 : 0.9);
}

export function ExpeditionsPage(props: PageProps) {
	const phone = props.phone;
	const session = props.session as unknown as ExpSession;
	const config = props.config as unknown as ExpConfig;
	const board = session.ExpeditionBoard;
	const slots = board?.Slots ?? [];
	const running = slots.some((s) => s.Id !== "");
	const [result, setResult] = React.useState<{ reply: ExpReply; at: number } | undefined>(undefined);
	const now = useServerClock(running || result !== undefined);
	React.useEffect(() => {
		if (result === undefined) return;
		const job = task.delay(6, () => setResult(undefined));
		return () => {
			pcall(task.cancel, job);
		};
	}, [result]);
	const routes = config.Operations?.Expeditions ?? [];
	const defs = new Map<string, ItemDef>();
	for (const def of config.Items?.Definitions ?? []) defs.set(def.Id, def);
	const relics = freeRelics(session, defs);
	const taken = new Set<string>();
	for (const s of slots) if (s.Id !== "") taken.add(s.Id);
	const streak = board?.Streak ?? 0;
	const out = slots.filter((s) => s.Id !== "").size();
	const space = gap(phone, "l");
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
			{result !== undefined && (
				<Outcome key={`r${result.at}`} reply={result.reply} routeName={routes.find((r) => r.Id === result.reply.Route)?.Name ?? ""} phone={phone} />
			)}
			<Panel pad={gap(phone, "l")} spacing={6} order={1}>
				<Title text="Expeditions" size={Type.title(phone)} tags={["wave"]} order={0} />
				<Text
					text={`${out} of ${slots.size()} out${streak > 0 ? ` · streak ${streak}, ${string.format("+%d%%", math.min(streak, Board.STREAK_CAP) * Board.STREAK_STEP * 100)} haul` : ""}${(board?.Best ?? 0) > 0 ? ` · best ${board!.Best}` : ""}`}
					size={Type.small(phone) + 1}
					color={streak > 0 ? Palette.mango : Iron.muted()}
					order={1}
				/>
				{board?.Paused === true && <Text text="Paused for a moment. Running trips keep going." size={Type.small(phone)} color={Palette.mango} order={2} />}
			</Panel>
			{board === undefined || slots.size() === 0 ? (
				<EmptyState title="No expedition slots yet" body="Slots open as your command level grows." phone={phone} order={2} />
			) : (
				slots.map((slot, i) =>
					slot.Id === "" ? (
						<OpenSlot key={`s${slot.Slot}`} page={props} session={session} slot={slot} routes={routes} taken={taken} relics={relics} order={10 + i} />
					) : (
						<RunningSlot
							key={`s${slot.Slot}`}
							page={props}
							session={session}
							slot={slot}
							route={routes.find((r) => r.Id === slot.Id)}
							defs={defs}
							now={now}
							order={10 + i}
							onResult={(reply) => {
								playOutcome(reply);
								setResult({ reply, at: os.clock() });
							}}
						/>
					),
				)
			)}
		</scrollingframe>
	);
}
