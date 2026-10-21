// Expedition Board (v8 #4): every expedition slot as a card. An open slot picks a route and up to
// three relics as crew; a running slot shows its timer and crew with Recall; a finished one Claims.
import React from "@rbxts/react";
import Board = require("../../../../Shared/AstralForge/Shared/ExpeditionBoard");
import { clockText } from "../../CoreKit/format";
import { chromeFor, Palette, TapTarget } from "../../CoreKit/theme";
import { useViewport } from "../../MotionKit/motion";
import { useServerClock } from "../../hooks/useServerClock";
import { loadPageScaffold, loadUi } from "../luauDeps";

const { Button, Dropdown, Meter, Panel, Text } = loadUi();
const PageScaffold = loadPageScaffold();

type Reply = (response: { ok?: boolean; message?: string }) => void;
type Dispatch = (action: string, payload?: object, callback?: Reply) => unknown;

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
		ExpeditionBoard?: { Slots: SlotState[]; CrewMax: number; Paused?: boolean };
		Command?: { Level?: number };
		Items?: { Inventory?: Record<string, Instance_>; Equipped?: Record<string, string> };
	};
	config: { Operations?: { Expeditions?: Route[] }; Items?: { Definitions?: ItemDef[] } };
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

const PAD = 16;
const CHIP_H = TapTarget;
const RUN_H = PAD * 2 + 22 + 18 + 16 + TapTarget + 8;

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
	const power = (c: Candidate) => Board.crewPower([{ Rarity: c.Def.Rarity, EffectKind: c.Def.EffectKind, Stars: c.Stars }]);
	out.sort((a, b) => (power(a) !== power(b) ? power(a) > power(b) : a.Uid < b.Uid));
	return out;
}

function OpenSlot(p: { props: Props; slot: SlotState; routes: Route[]; busyRoutes: Set<string>; candidates: Candidate[]; stack: boolean }) {
	const level = p.props.state.Command?.Level ?? 1;
	const open = p.routes.filter((route) => route.RequiredLevel <= level && !p.busyRoutes.has(route.Id));
	const [routeId, setRouteId] = React.useState<string | undefined>(undefined);
	const [crew, setCrew] = React.useState<string[]>([]);
	const [busy, setBusy] = React.useState(false);
	const route = open.find((r) => r.Id === routeId) ?? open[open.size() - 1];
	const crewMax = p.props.state.ExpeditionBoard?.CrewMax ?? Board.CREW_MAX;
	const shown = p.candidates.filter((_, i) => i < 8);
	const picked = shown.filter((c) => crew.includes(c.Uid));
	const chance = Board.bonusChance(picked.map((c) => ({ Rarity: c.Def.Rarity, EffectKind: c.Def.EffectKind, Stars: c.Stars })));
	const columns = p.stack ? 2 : 4;
	const rows = math.ceil(shown.size() / columns);
	const toggle = (uid: string) => {
		if (crew.includes(uid)) setCrew(crew.filter((u) => u !== uid));
		else if (crew.size() < crewMax) setCrew([...crew, uid]);
	};
	const launch = () => {
		if (route === undefined || busy) return;
		setBusy(true);
		p.props.dispatch("ExpeditionAct", { Op: "Launch", Slot: p.slot.Slot, Id: route.Id, Crew: crew }, (response) => {
			setBusy(false);
			if (response.ok === true) setCrew([]);
		});
	};
	const crewLine =
		picked.size() === 0 ? "No crew. The route still pays its reward." : `Crew bonus chance ${math.floor(chance * 100 + 0.5)}%`;
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={Palette.cyan} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion} clips={false}>
			{open.size() === 0 ? (
				<Text value="Every route you can run is already out." size={13} color={Palette.muted} fit={true} minSize={10} sizeConstraint={new UDim2(1, 0, 0, 20)} />
			) : (
				<frame Size={new UDim2(1, 0, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
					<Dropdown
						options={open.map((r) => ({ id: r.Id, label: r.Name, detail: clockText(r.Duration) }))}
						value={route?.Id}
						onChange={(id: string) => setRouteId(id)}
						accent={Palette.cyan}
						size={new UDim2(p.stack ? 1 : 0.5, p.stack ? 0 : -6, 0, TapTarget)}
						reducedMotion={p.props.reducedMotion}
						zIndex={40 + (10 - p.slot.Slot)}
					/>
					<Button
						text="Launch"
						onClick={launch}
						disabled={busy || route === undefined}
						color={Palette.cyan}
						textColor={Palette.ink}
						size={new UDim2(p.stack ? 1 : 0.5, p.stack ? 0 : -6, 0, TapTarget)}
						position={p.stack ? UDim2.fromOffset(0, TapTarget + 8) : new UDim2(0.5, 6, 0, 0)}
						reducedMotion={p.props.reducedMotion}
					/>
					<Text
						value={crewLine}
						size={12}
						color={Palette.creamSoft}
						fit={true}
						minSize={10}
						position={UDim2.fromOffset(0, (p.stack ? 2 : 1) * (TapTarget + 8))}
						sizeConstraint={new UDim2(1, 0, 0, 18)}
					/>
					{shown.map((c, i) => {
						const on = crew.includes(c.Uid);
						return (
							<Button
								key={c.Uid}
								text={c.Def.Name}
								onClick={() => toggle(c.Uid)}
								color={on ? Palette.violet : Palette.panelSoft}
								textColor={on ? Palette.ink : Palette.cream}
								outline={!on}
								size={new UDim2(1 / columns, -6, 0, CHIP_H)}
								position={new UDim2((i % columns) / columns, 0, 0, (p.stack ? 2 : 1) * (TapTarget + 8) + 26 + math.floor(i / columns) * (CHIP_H + 6))}
								reducedMotion={p.props.reducedMotion}
							/>
						);
					})}
					{rows === 0 && (
						<Text
							value="No free relics to crew with."
							size={12}
							color={Palette.muted}
							position={UDim2.fromOffset(0, (p.stack ? 2 : 1) * (TapTarget + 8) + 26)}
							sizeConstraint={new UDim2(1, 0, 0, 18)}
						/>
					)}
				</frame>
			)}
		</Panel>
	);
}

function openSlotHeight(candidates: number, stack: boolean): number {
	const columns = stack ? 2 : 4;
	const rows = math.max(1, math.ceil(math.min(8, candidates) / columns));
	return PAD * 2 + (stack ? 2 : 1) * (TapTarget + 8) + 26 + rows * (CHIP_H + 6);
}

function RunningSlot(p: { props: Props; slot: SlotState; route?: Route; defs: Map<string, ItemDef>; now: number }) {
	const [busy, setBusy] = React.useState(false);
	const total = math.max(1, p.slot.EndsAt - p.slot.StartedAt);
	const left = math.max(0, p.slot.EndsAt - p.now);
	const done = left <= 0;
	const inventory = p.props.state.Items?.Inventory ?? {};
	const names = p.slot.Crew.map((uid) => p.defs.get(inventory[uid]?.DefinitionId ?? "")?.Name ?? "Relic");
	const act = (op: "Claim" | "Recall") => {
		if (busy) return;
		setBusy(true);
		p.props.dispatch("ExpeditionAct", { Op: op, Slot: p.slot.Slot }, () => setBusy(false));
	};
	return (
		<Panel size={UDim2.fromScale(1, 1)} accent={done ? Palette.mint : Palette.cyan} background={Palette.panel} padding={PAD} reducedMotion={p.props.reducedMotion} clips={false}>
			<Text value={p.route?.Name ?? p.slot.Id} size={16} color={Palette.cream} weight={Enum.FontWeight.Bold} fit={true} minSize={11} sizeConstraint={new UDim2(1, -110, 0, 22)} />
			<Text
				value={done ? "Back" : clockText(left)}
				size={13}
				color={done ? Palette.mint : Palette.creamSoft}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -110, 0, 0)}
				sizeConstraint={new UDim2(0, 110, 0, 22)}
			/>
			<Meter value={1 - left / total} color={done ? Palette.mint : Palette.cyan} position={UDim2.fromOffset(0, 30)} size={new UDim2(1, 0, 0, 8)} reducedMotion={p.props.reducedMotion} />
			<Text
				value={names.size() > 0 ? names.join(", ") : "No crew"}
				size={12}
				color={Palette.muted}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 46)}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
			<Button
				text={done ? "Claim" : "Recall"}
				onClick={() => act(done ? "Claim" : "Recall")}
				disabled={busy}
				color={done ? Palette.mint : Palette.panelSoft}
				textColor={done ? Palette.ink : Palette.cream}
				outline={!done}
				size={new UDim2(0, 160, 0, TapTarget)}
				position={UDim2.fromOffset(0, 72)}
				reducedMotion={p.props.reducedMotion}
			/>
		</Panel>
	);
}

function ExpeditionsView(props: Props) {
	const viewport = useViewport();
	const stack = chromeFor(viewport).contentStack;
	const board = props.state.ExpeditionBoard;
	const slots = board?.Slots ?? [];
	const running = slots.some((slot) => slot.Id !== "");
	const now = useServerClock(running);
	const routes = props.config.Operations?.Expeditions ?? [];
	const defs = defsById(props.config);
	const candidates = candidatesOf(props, defs);
	const busyRoutes = new Set<string>();
	for (const slot of slots) if (slot.Id !== "") busyRoutes.add(slot.Id);
	const sections: { id: string; height: number; element: React.Element }[] = [];
	if (board?.Paused === true) {
		sections.push({
			id: "paused",
			height: 28,
			element: <Text value="Expeditions are paused for a moment. Running ones keep going." size={13} color={Palette.mango} fit={true} minSize={10} />,
		});
	}
	for (const slot of slots) {
		if (slot.Id === "") {
			sections.push({
				id: `slot${slot.Slot}`,
				height: openSlotHeight(candidates.size(), stack),
				element: <OpenSlot props={props} slot={slot} routes={routes} busyRoutes={busyRoutes} candidates={candidates} stack={stack} />,
			});
		} else {
			sections.push({
				id: `slot${slot.Slot}`,
				height: RUN_H,
				element: <RunningSlot props={props} slot={slot} route={routes.find((r) => r.Id === slot.Id)} defs={defs} now={now} />,
			});
		}
	}
	return <PageScaffold sections={sections} gap={12} tailPad={stack ? 10 : 14} owner="ExpeditionsView" />;
}
export = { ExpeditionsView };
