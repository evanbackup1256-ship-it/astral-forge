// The Rebirth page: the run's charge ring, what a rebirth pays and resets, the machines you keep,
// past runs and the next rebirth unlocks. "Rebirth now" opens the same chamber as the overview
// card, so the vow, keepsake picks and the two-step ignition ceremony are unchanged.
import React from "@rbxts/react";
import { asFlux, compactNumber } from "../../CoreKit/format";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { chromeFor, darken, Palette, TapTarget } from "../../CoreKit/theme";
import { useClock, useViewport } from "../../MotionKit/motion";
import { splitColumns } from "../../UiCore/ui";
import { splitSection, PageBlock } from "../layoutRise";
import { kitMember, LuauComponent } from "../luauKits";
import {
	clock,
	Dispatch,
	MachineConfig,
	RebirthChamber,
	RebirthConfig,
	rebirthOf,
	RebirthState,
	RunEntry,
} from "./RebirthPanel";

const Ui = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const meterFill = (Ui as unknown as { meterFill: (this: void, a: number, b: number) => number }).meterFill;

const GAP = 14;
const RING_SEGMENTS = 48;
const GRADE_COLOR: Record<string, Color3 | undefined> = { S: Palette.mango, A: Palette.mint, B: Palette.cyan, C: Palette.muted };

interface RebirthViewProps {
	state: RebirthState;
	config?: RebirthConfig;
	dispatch: Dispatch;
	reducedMotion?: boolean;
}

// Swept charge ring: segments fill clockwise with progress; a soft glow breathes behind it.
function SweptRing(props: { size: number; fill: number; accent: Color3; softMotion?: boolean; children?: React.ReactNode }) {
	const breathe = useClock(!props.softMotion, 0.5, math.pi * 2);
	const radius = props.size * 0.5 - 6;
	const segs: Record<string, React.Element> = {};
	const segLen = math.max(4, (math.pi * 2 * radius) / RING_SEGMENTS - 3);
	for (let i = 0; i < RING_SEGMENTS; i++) {
		const t = i / RING_SEGMENTS;
		const angle = -math.pi / 2 + t * math.pi * 2;
		const lit = t < props.fill;
		segs["s" + i] = (
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={new UDim2(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius)}
				Size={UDim2.fromOffset(segLen, lit ? 8 : 3)}
				Rotation={math.deg(angle) + 90}
				BackgroundColor3={lit ? props.accent.Lerp(Palette.violet, t) : Palette.lineSoft}
				BackgroundTransparency={lit ? 0 : 0.6}
				BorderSizePixel={0}
				ZIndex={3}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}
	return (
		<frame Size={UDim2.fromOffset(props.size, props.size)} Position={UDim2.fromScale(0.5, 0)} AnchorPoint={new Vector2(0.5, 0)} BackgroundTransparency={1}>
			<frame
				Size={UDim2.fromScale(0.78, 0.78)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={darken(props.accent, 0.7)}
				BackgroundTransparency={breathe.map((a) => 0.35 + (math.sin(a) + 1) * 0.12)}
				BorderSizePixel={0}
				ZIndex={1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.7)])} Rotation={90} />
				<uistroke Color={props.accent} Thickness={1} Transparency={0.7} />
			</frame>
			{segs}
			{props.children}
		</frame>
	);
}

function Row(props: { icon: string; label: string; sub?: string; value: string; color: Color3; order: number }) {
	return (
		<frame Size={new UDim2(1, 0, 0, 40)} Position={UDim2.fromOffset(0, 30 + props.order * 46)} BackgroundColor3={Palette.panelSoft} BackgroundTransparency={0.4} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<Icon kind={props.icon} size={20} position={UDim2.fromOffset(10, 10)} />
			<Ui.Text value={props.label} size={13} weight={Enum.FontWeight.Bold} position={UDim2.fromOffset(38, props.sub !== undefined ? 4 : 11)} sizeConstraint={new UDim2(1, -110, 0, 18)} />
			{props.sub !== undefined && (
				<Ui.Text value={props.sub} size={10} color={Palette.muted} position={UDim2.fromOffset(38, 22)} sizeConstraint={new UDim2(1, -110, 0, 14)} />
			)}
			<Ui.Text value={props.value} size={13} weight={Enum.FontWeight.Heavy} color={props.color} align={Enum.TextXAlignment.Right} position={new UDim2(1, -80, 0, 11)} sizeConstraint={UDim2.fromOffset(70, 18)} />
		</frame>
	);
}

function Card(props: { title: string; accent: Color3; children?: React.ReactNode }) {
	return (
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={14} accent={props.accent} background={Palette.panel} radius={18}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<uistroke Color={Palette.brass} Transparency={0.75} Thickness={1} />
				<uicorner CornerRadius={new UDim(0, 12)} />
			</frame>
			<Ui.Text value={props.title} size={12} weight={Enum.FontWeight.Heavy} color={Palette.brass} sizeConstraint={new UDim2(1, 0, 0, 18)} />
			{props.children}
		</Ui.Panel>
	);
}

function RebirthBoard(props: RebirthViewProps) {
	const { state, config, reducedMotion } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const info = rebirthOf(state);
	const [chamberOpen, setChamberOpen] = React.useState(false);
	const rebirths = math.max(0, math.floor(tonumber(state.Rebirths) ?? 0));
	const ready = info.Ready === true;
	const target = math.max(1, asFlux(state.NextPrestigeTarget));
	const earned = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault));
	const progress = ready ? 1 : meterFill(earned, target);
	const accent = Palette.pink;

	const sections: PageBlock[] = [];
	// hero
	sections.push({
		id: "hero",
		height: stack ? 76 : 104,
		element: (
			<Ui.Panel size={UDim2.fromScale(1, 1)} padding={stack ? 12 : 18} accent={Palette.brass} background={darken(accent, 0.9)} radius={18} clips={true}>
				<Ui.Text value={`REBIRTH ${rebirths} → ${rebirths + 1}`} size={10} weight={Enum.FontWeight.Heavy} color={accent} sizeConstraint={new UDim2(1, 0, 0, 14)} />
				<Ui.Text value="Rebirth" size={stack ? 22 : 30} weight={Enum.FontWeight.Heavy} position={UDim2.fromOffset(0, 16)} sizeConstraint={new UDim2(1, 0, 0, stack ? 26 : 36)} />
				<Ui.Text value="Melt it all down. Come back brighter." size={12} color={Palette.creamSoft} position={UDim2.fromOffset(0, stack ? 44 : 56)} sizeConstraint={new UDim2(1, -120, 0, 16)} />
				<SweptRing size={stack ? 52 : 72} fill={progress} accent={accent} softMotion={reducedMotion} />
			</Ui.Panel>
		),
	});
	// the main dial and the button
	const dialSize = stack ? 180 : 260;
	const dialH = dialSize + 24 + 34 + 12 + TapTarget + 36;
	sections.push({
		id: "dial",
		height: dialH,
		element: (
			<Ui.Panel size={UDim2.fromScale(1, 1)} padding={16} accent={accent} background={Palette.panelRaised} radius={18} highlight={ready && !reducedMotion} reducedMotion={reducedMotion} clips={false}>
				<SweptRing size={dialSize} fill={progress} accent={accent} softMotion={reducedMotion}>
					<Ui.Text value={`REBIRTH ${rebirths + 1}`} size={12} weight={Enum.FontWeight.Heavy} color={Palette.muted} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, -46)} sizeConstraint={new UDim2(1, 0, 0, 16)} zIndex={4} />
					<Ui.Text value={ready ? "Ready" : `${math.floor(progress * 100)}%`} size={stack ? 30 : 42} weight={Enum.FontWeight.Heavy} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, -28)} sizeConstraint={new UDim2(1, 0, 0, 48)} zIndex={4} />
					<Ui.Text value={`+${compactNumber(info.Cores)} cores`} size={12} color={accent} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, 22)} sizeConstraint={new UDim2(1, 0, 0, 16)} zIndex={4} />
				</SweptRing>
				<Ui.Meter value={progress} color={accent} rainbow={true} shimmer={ready} reducedMotion={reducedMotion} position={UDim2.fromOffset(0, dialSize + 24)} size={new UDim2(1, 0, 0, 6)} />
				<Ui.Text value={`${compactNumber(earned)} earned`} size={11} color={Palette.muted} position={UDim2.fromOffset(0, dialSize + 36)} sizeConstraint={new UDim2(0.5, 0, 0, 16)} />
				<Ui.Text value={`${compactNumber(target)} needed`} size={11} color={Palette.muted} align={Enum.TextXAlignment.Right} position={new UDim2(0.5, 0, 0, dialSize + 36)} sizeConstraint={new UDim2(0.5, 0, 0, 16)} />
				<Ui.Button
					text={ready ? "Rebirth now" : "Plan rebirth"}
					icon="Rebirth.rebirthPlan"
					sound="page"
					color={ready ? accent : Palette.panelSoft}
					textColor={ready ? Palette.ink : Palette.cream}
					highlight={ready && !reducedMotion}
					reducedMotion={reducedMotion}
					size={new UDim2(1, 0, 0, TapTarget)}
					position={new UDim2(0, 0, 1, -TapTarget)}
					onClick={() => setChamberOpen(true)}
				/>
			</Ui.Panel>
		),
	});
	// you get / you lose
	const machines = state.Machines ?? {};
	let levels = 0;
	for (const [, level] of pairs(machines)) levels += tonumber(level) ?? 0;
	const listH = 30 + 3 * 46 + 14;
	const gainLose = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<frame Size={stack ? new UDim2(1, 0, 0, listH) : new UDim2(0.5, -GAP / 2, 1, 0)} BackgroundTransparency={1}>
				<Card title="YOU GET" accent={Palette.mint}>
					<Row order={0} icon="Production.rebirthStarCores" label="Cores" value={`+${compactNumber(info.Cores)}`} color={accent} />
					<Row order={1} icon="Dust.rebirthStarDust" label="Stardust" value={`+${compactNumber(info.Stardust)}`} color={accent} />
					<Row order={2} icon="Rebirth.rebirthDial" label="Run grade" sub={info.Runs !== undefined && info.Runs.size() > 0 ? "beat your last run" : undefined} value={info.Grade} color={GRADE_COLOR[info.Grade] ?? Palette.cream} />
				</Card>
			</frame>
			<frame Size={stack ? new UDim2(1, 0, 0, listH) : new UDim2(0.5, -GAP / 2, 1, 0)} Position={stack ? UDim2.fromOffset(0, listH + GAP) : new UDim2(0.5, GAP / 2, 0, 0)} BackgroundTransparency={1}>
				<Card title="YOU LOSE" accent={Palette.coral}>
					<Row order={0} icon="Flux.rebirthStarSeed" label="Cash" value={compactNumber(state.RunCash)} color={Palette.coral} />
					<Row order={1} icon="Forge.rebirthWorkshop" label="Machine levels" value={compactNumber(levels)} color={Palette.coral} />
					<Row order={2} icon="Vault.rebirthVowOverflow" label="Vault" value={compactNumber(state.Vault)} color={Palette.coral} />
				</Card>
			</frame>
		</frame>
	);
	// keepsakes and history
	const keep = info.Keep ?? [];
	const names = new Map<string, string>();
	for (const machine of (config?.Machines ?? []) as MachineConfig[]) names.set(machine.Id, machine.Name ?? machine.Id);
	const slots = math.max(keep.size(), info.KeepSlots ?? 0);
	const keepCards: Record<string, React.Element> = {};
	const cardW = 1 / math.max(3, slots);
	for (let i = 0; i < math.max(1, slots); i++) {
		const id = keep[i];
		keepCards["k" + i] = (
			<frame Size={new UDim2(cardW, -8, 1, -30)} Position={new UDim2(i * cardW, 0, 0, 26)} BackgroundColor3={id !== undefined ? darken(Palette.violet, 0.75) : Palette.panelSoft} BackgroundTransparency={id !== undefined ? 0 : 0.5} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke Color={id !== undefined ? Palette.violet : Palette.lineSoft} Thickness={1.5} Transparency={id !== undefined ? 0 : 0.6} />
				<Icon kind={id !== undefined ? "Loadout.rebirthKeepOther" : "Lock.rebirthStarVow"} size={28} position={new UDim2(0.5, -14, 0, 10)} />
				<Ui.Text value={id !== undefined ? (names.get(id) ?? id) : "Empty"} size={11} weight={Enum.FontWeight.Bold} align={Enum.TextXAlignment.Center} fit={true} minSize={9} position={new UDim2(0, 4, 1, -24)} sizeConstraint={new UDim2(1, -8, 0, 18)} />
			</frame>
		);
	}
	const runs = (info.Runs ?? []) as RunEntry[];
	const historyRows: Record<string, React.Element> = {};
	const shown = math.min(3, runs.size());
	for (let i = 0; i < shown; i++) {
		const run = runs[runs.size() - 1 - i];
		historyRows["h" + i] = (
			<Row order={i} icon="Timer.rebirthVowSwift" label={`#${rebirths - i}`} sub={clock(run.Seconds)} value={`${run.Grade} +${compactNumber(run.Cores ?? 0)}`} color={GRADE_COLOR[run.Grade] ?? Palette.cream} />
		);
	}
	const keepH = 150;
	const histH = 30 + math.max(1, shown) * 46 + 14;
	const keepHistory = (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<frame Size={stack ? new UDim2(1, 0, 0, keepH) : new UDim2(0.58, -GAP / 2, 1, 0)} BackgroundTransparency={1}>
				<Card title="KEEPSAKES" accent={Palette.violet}>{keepCards}</Card>
			</frame>
			<frame Size={stack ? new UDim2(1, 0, 0, histH) : new UDim2(0.42, -GAP / 2, 1, 0)} Position={stack ? UDim2.fromOffset(0, keepH + GAP) : new UDim2(0.58, GAP / 2, 0, 0)} BackgroundTransparency={1}>
				<Card title="HISTORY" accent={Palette.pink}>
					{shown > 0 ? historyRows : <Ui.Text value="No runs yet" size={12} color={Palette.muted} position={UDim2.fromOffset(0, 40)} sizeConstraint={new UDim2(1, 0, 0, 18)} />}
				</Card>
			</frame>
		</frame>
	);
	// milestones: the next rebirth unlocks from config
	const steps: { need: number; name: string }[] = [];
	const unlocks = config !== undefined && typeIs(config.Unlocks, "table") ? (config.Unlocks as unknown[]) : [];
	for (const raw of unlocks) {
		const rule = raw as { Kind?: unknown; Target?: unknown; Name?: unknown };
		if (typeIs(raw, "table") && rule.Kind === "Rebirths" && typeIs(rule.Target, "number") && typeIs(rule.Name, "string")) {
			steps.push({ need: rule.Target, name: rule.Name });
		}
	}
	steps.sort((a, b) => a.need < b.need);
	let first = 0;
	for (let i = 0; i < steps.size(); i++) {
		if (steps[i].need <= rebirths) first = i;
	}
	const track = steps.filter((_, i) => i >= first && i < first + 4);
	const nodes: Record<string, React.Element> = {};
	track.forEach((step, i) => {
		const done = step.need <= rebirths;
		const x = track.size() <= 1 ? 0.5 : i / (track.size() - 1);
		nodes["m" + i] = (
			<frame Size={UDim2.fromOffset(96, 64)} Position={new UDim2(x, -48 + (1 - x * 2) * 30, 0, 26)} BackgroundTransparency={1}>
				<frame Size={UDim2.fromOffset(28, 28)} Position={new UDim2(0.5, -14, 0, 0)} BackgroundColor3={done ? accent : Palette.panelSoft} BorderSizePixel={0} ZIndex={3}>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={done ? Palette.cream : Palette.lineSoft} Thickness={1.5} Transparency={0.3} />
					<Ui.Text value={tostring(step.need)} size={10} weight={Enum.FontWeight.Heavy} color={done ? Palette.ink : Palette.cream} align={Enum.TextXAlignment.Center} position={UDim2.fromOffset(0, 7)} sizeConstraint={new UDim2(1, 0, 0, 14)} zIndex={4} />
				</frame>
				<Ui.Text value={step.name} size={10} color={done ? Palette.cream : Palette.muted} wrap={true} fit={true} minSize={9} align={Enum.TextXAlignment.Center} position={UDim2.fromOffset(0, 32)} sizeConstraint={new UDim2(1, 0, 0, 30)} />
			</frame>
		);
	});
	const milestones = (
		<Card title="MILESTONES" accent={Palette.brass}>
			<frame Size={new UDim2(1, -60, 0, 2)} Position={UDim2.fromOffset(30, 39)} BackgroundColor3={Palette.lineSoft} BackgroundTransparency={0.5} BorderSizePixel={0} />
			{track.size() > 0 ? nodes : <Ui.Text value="All unlocked" size={12} color={Palette.muted} position={UDim2.fromOffset(0, 36)} sizeConstraint={new UDim2(1, 0, 0, 18)} />}
		</Card>
	);

	const right: PageBlock[] = [
		{ id: "gainLose", height: stack ? listH * 2 + GAP : listH, element: gainLose },
		{ id: "keepHistory", height: stack ? keepH + histH + GAP : math.max(keepH, histH), element: keepHistory },
		{ id: "milestones", height: 104, element: milestones },
	];
	const plan = splitColumns(stack ? 0 : viewport.width - 40, math.floor((viewport.width - 40) * 0.36), GAP, 900);
	let body: PageBlock[];
	if (plan.split) {
		body = [sections[0], splitSection("RebirthSplit", plan, GAP, [sections[1]], right, false, ["dial", "gainLose", "keepHistory", "milestones"])];
	} else {
		body = [...sections, ...right];
	}
	return (
		<>
			<PageScaffold sections={body} gap={GAP} tailPad={72} scrollBarColor={accent} owner="RebirthView" />
			{chamberOpen && (
				<RebirthChamber state={state} config={config} dispatch={props.dispatch} reducedMotion={reducedMotion} onClose={() => setChamberOpen(false)} />
			)}
		</>
	);
}

export function RebirthView(props: RebirthViewProps) {
	const hostRef = React.useRef<Frame>();
	useFocusOrder(hostRef, { regions: ["hero", "dial", "gainLose", "keepHistory", "milestones"], first: ["dial"], columns: [["Side", "Main"]] }, [
		rebirthOf(props.state).Ready === true,
	]);
	return (
		<frame ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<RebirthBoard {...props} />
		</frame>
	);
}
