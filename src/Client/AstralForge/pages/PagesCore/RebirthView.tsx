// The Rebirth page: the run's charge ring, what a rebirth pays and resets, the machines you keep,
// past runs and the next rebirth unlocks. "Rebirth now" opens the same chamber as the overview
// card, so the vow, keepsake picks and the two-step ignition ceremony are unchanged.
import React from "@rbxts/react";
import { asFlux, compactNumber } from "../../CoreKit/format";
import { useFocusOrder } from "../../CoreKit/focusOrder";
import { chromeFor, darken, Palette, TapTarget } from "../../CoreKit/theme";
import { Bar, BODY_SEMI, ItemTile, Line, MockPanel, mockGap, NUM, PanelHeading, panelPad, spaced, TITLE_FACE } from "../../UiCore/mockKit";
import { headingBlock, MockRow, panelHeight, rowHeight, SEC } from "../mockRows";
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
// generated from design/09-rebirth by scripts/gen_from_layout.js (scripts/layout/rebirth.spec.json)
import { RebirthLayout as L } from "../generated/RebirthLayout";

const Ui = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { Icon } = kitMember<{ Icon: LuauComponent }>("ArtKit", "Icon");
const meterFill = (Ui as unknown as { meterFill: (this: void, a: number, b: number) => number }).meterFill;

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

// 09-rebirth body: 640px dial panel left; You get / You lose, Keepsakes + 340px History, Milestones on the right
function RebirthBoard(props: RebirthViewProps) {
	const { state, config, reducedMotion } = props;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const info = rebirthOf(state);
	const [chamberOpen, setChamberOpen] = React.useState(false);
	const rebirths = math.max(0, math.floor(tonumber(state.Rebirths) ?? 0));
	const ready = info.Ready === true;
	const target = math.max(1, asFlux(state.NextPrestigeTarget));
	const earned = math.max(0, asFlux(state.RunCash)) + math.max(0, asFlux(state.Vault));
	const progress = ready ? 1 : meterFill(earned, target);
	const accent = Palette.pink;
	const rowH = rowHeight(phone);
	const rowH2 = rowHeight(phone, true);
	const head = headingBlock(phone);

	// .pn dial: 400px ring, bar + earned / needed, 60px pink button
	const dialSize = phone ? 200 : L.DialRing.w;
	const btnH = phone ? TapTarget : L.DialBtn.h;
	const meterH = phone ? 10 + 8 + 18 : L.DialMeter.h;
	const dialContent = dialSize + L.Dial.gap + meterH + L.Dial.gap + btnH;
	const dialPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={accent} glow={accent} reducedMotion={reducedMotion} gap={L.Dial.gap} name="RebirthDial">
			<frame Size={new UDim2(1, 0, 0, dialSize)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0}>
				<SweptRing size={dialSize} fill={progress} accent={accent} softMotion={reducedMotion}>
					<Line text={spaced(`REBIRTH ${rebirths + 1}`)} size={phone ? 11 : 13} color={Palette.muted} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, phone ? -40 : -70)} zIndex={4} />
					<Line text={ready ? "Ready" : `${math.floor(progress * 100)}%`} size={phone ? 40 : 72} font={TITLE_FACE} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, 0)} anchor={new Vector2(0, 0.5)} zIndex={4} />
					<Line text={`+${compactNumber(info.Cores)} cores`} size={phone ? 12 : 15} font={BODY_SEMI} color={accent} width={new UDim(1, 0)} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, phone ? 26 : 48)} zIndex={4} />
				</SweptRing>
			</frame>
			<frame Size={new UDim2(1, 0, 0, meterH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<Bar fill={progress} color={accent} />
				<Line text={`${compactNumber(earned)} cash earned`} size={L.DialEarned.text.size} font={BODY_SEMI} color={L.DialEarned.text.color} position={UDim2.fromOffset(0, meterH - L.DialEarned.h)} />
				<Line text={`${compactNumber(target)} needed`} size={L.DialEarned.text.size} font={BODY_SEMI} color={L.DialEarned.text.color} position={new UDim2(1, 0, 0, meterH - L.DialEarned.h)} anchor={new Vector2(1, 0)} width={new UDim(0.5, 0)} align={Enum.TextXAlignment.Right} />
			</frame>
			<frame Size={new UDim2(1, 0, 0, btnH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				<Ui.Button
					text={ready ? "Rebirth now" : "Plan rebirth"}
					icon="Rebirth.rebirthPlan"
					sound="page"
					color={ready ? accent : SEC}
					textColor={ready ? Palette.ink : Palette.cream}
					highlight={ready && !reducedMotion}
					reducedMotion={reducedMotion}
					size={UDim2.fromScale(1, 1)}
					onClick={() => setChamberOpen(true)}
				/>
			</frame>
		</MockPanel>
	);

	// you get / you lose
	const machines = state.Machines ?? {};
	let levels = 0;
	for (const [, level] of pairs(machines)) levels += tonumber(level) ?? 0;
	const listH = panelHeight(phone, head + rowH * 2 + rowH2 + pad.gap * 2);
	const getPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.mint} reducedMotion={reducedMotion} name="YouGet">
			<PanelHeading icon="Collect" title="You get" accent={Palette.mint} phone={phone} layoutOrder={0} />
			<MockRow phone={phone} icon="Production" title="Cores" value={`+${compactNumber(info.Cores)}`} layoutOrder={1} />
			<MockRow phone={phone} icon="Dust" title="Stardust" value={`+${compactNumber(info.Stardust)}`} layoutOrder={2} />
			<MockRow
				phone={phone}
				icon="Rebirth"
				title="Run grade"
				sub={(info.Runs ?? []).size() > 0 ? "beat your last run" : "first run"}
				value={info.Grade}
				valueColor={GRADE_COLOR[info.Grade] ?? Palette.cream}
				layoutOrder={3}
			/>
		</MockPanel>
	);
	const losePanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.coral} reducedMotion={reducedMotion} name="YouLose">
			<PanelHeading icon="Minus" title="You lose" accent={Palette.coral} phone={phone} layoutOrder={0} />
			<MockRow phone={phone} icon="Flux" accent={Palette.coral} title="Cash" value={compactNumber(state.RunCash)} layoutOrder={1} />
			<MockRow phone={phone} icon="Forge" accent={Palette.coral} title="Machine levels" value={compactNumber(levels)} layoutOrder={2} />
			<MockRow phone={phone} icon="Vault" accent={Palette.coral} title="Vault" sub="banked cash" value={compactNumber(state.Vault)} layoutOrder={3} />
		</MockPanel>
	);

	// keepsakes (.it cards with a Kept count) and the last three runs
	const keep = info.Keep ?? [];
	const names = new Map<string, string>();
	const levelsOf = state.Machines ?? {};
	for (const machine of (config?.Machines ?? []) as MachineConfig[]) names.set(machine.Id, machine.Name ?? machine.Id);
	const slots = math.max(keep.size(), info.KeepSlots ?? 0);
	const tileW = phone ? 96 : L.KeepTile.w;
	const tiles: React.Element[] = [];
	for (let i = 0; i < math.max(1, slots); i++) {
		const id = keep[i];
		tiles.push(
			<ItemTile
				key={"k" + i}
				color={id !== undefined ? Palette.violet : Palette.muted}
				icon={id !== undefined ? "Loadout" : "Lock"}
				width={tileW}
				locked={id === undefined}
				name={id !== undefined ? (names.get(id) ?? id) : slots > 0 ? "Empty" : "No slots yet"}
				tag={id !== undefined ? "Kept" : undefined}
				count={id !== undefined ? `Lv ${compactNumber(tonumber(levelsOf[id]) ?? 0)}` : undefined}
				layoutOrder={i}
				phone={phone}
			/>,
		);
	}
	const tileH = (() => {
		const p2 = phone ? 5 : 8;
		const well = tileW - p2 * 2;
		return p2 + math.floor(well / 1.15) + (phone ? 4 : 6) * 2 + (phone ? 14 : 17) * 2 + (phone ? 7 : 10);
	})();
	const keepPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reducedMotion={reducedMotion} name="Keepsakes">
			<PanelHeading icon="Loadout" title="Keepsakes" note="Survive every rebirth" phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, tileH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Padding={new UDim(0, phone ? 6 : L.KeepGrid.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{tiles}
			</frame>
		</MockPanel>
	);
	const runs = (info.Runs ?? []) as RunEntry[];
	const shown = math.min(3, runs.size());
	const historyRows: React.Element[] = [];
	for (let i = 0; i < shown; i++) {
		const run = runs[runs.size() - 1 - i];
		historyRows.push(
			<MockRow
				key={"h" + i}
				phone={phone}
				title={clock(run.Seconds)}
				value={`${run.Grade}  +${compactNumber(run.Cores ?? 0)}`}
				valueColor={GRADE_COLOR[run.Grade] ?? Palette.cream}
				right={<Line text={`#${rebirths - i}`} size={phone ? 14 : L.HistNum.text.size} font={NUM} color={L.HistNum.text.color} width={new UDim(0, L.HistNum.w)} />}
				rightWidth={0}
				layoutOrder={i + 1}
			/>,
		);
	}
	const histH = panelHeight(phone, head + math.max(1, shown) * rowH + math.max(0, shown - 1) * pad.gap);
	const keepH = math.max(panelHeight(phone, head + tileH), histH);
	const historyPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={accent} reducedMotion={reducedMotion} name="History">
			<PanelHeading icon="Timer" title="History" phone={phone} layoutOrder={0} />
			{shown > 0 ? historyRows : <MockRow phone={phone} title="No runs yet" layoutOrder={1} />}
		</MockPanel>
	);

	// milestones: the next four rebirth unlocks from config, 44px nodes on a pink/line track
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
	let doneCount = 0;
	for (const step of track) if (step.need <= rebirths) doneCount += 1;
	const node = phone ? 34 : L.MileNode.w;
	const nameGap = phone ? 8 : L.MileStep.gap;
	const nameH = phone ? 18 : L.MileName.h;
	const trackH = node + nameGap + nameH;
	const nodes: React.Element[] = [];
	track.forEach((step, i) => {
		const done = step.need <= rebirths;
		nodes.push(
			<frame key={"m" + i} Size={new UDim2(1 / math.max(1, track.size()), 0, 1, 0)} Position={new UDim2(i / math.max(1, track.size()), 0, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
				<frame Size={UDim2.fromOffset(node, node)} Position={new UDim2(0.5, 0, 0, 0)} AnchorPoint={new Vector2(0.5, 0)} BackgroundColor3={done ? accent : Color3.fromRGB(27, 21, 29)} BorderSizePixel={0} ZIndex={3}>
					<uicorner CornerRadius={new UDim(1, 0)} />
					{done && <uigradient Rotation={90} Color={new ColorSequence(Color3.fromRGB(255, 200, 240), accent)} />}
					<uistroke Color={done ? accent : Color3.fromRGB(74, 58, 80)} Thickness={2} />
					<Line text={tostring(step.need)} size={phone ? 14 : L.MileNode.text.size} font={NUM} color={done ? Color3.fromRGB(42, 15, 29) : Palette.muted} width={new UDim(1, 0)} height={node} align={Enum.TextXAlignment.Center} zIndex={4} />
				</frame>
				<Line text={step.name} size={phone ? 12 : L.MileName.text.size} font={BODY_SEMI} color={done ? L.MileName.text.color : Palette.muted} width={new UDim(1, -8)} align={Enum.TextXAlignment.Center} position={UDim2.fromOffset(4, node + nameGap)} height={nameH} />
			</frame>,
		);
	});
	const lit = track.size() > 0 ? math.clamp((doneCount - 0.5) / track.size(), 0, 1) : 0;
	const milestonesH = panelHeight(phone, head + trackH);
	const milestones = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={reducedMotion} name="Milestones">
			<PanelHeading icon="Milestone" title="Milestones" phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, trackH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				{track.size() > 0 ? (
					<>
						<frame Size={new UDim2(L.MileLine.w / L.MileTrack.w, 0, 0, L.MileLine.h)} Position={new UDim2((L.MileLine.x - L.MileTrack.x) / L.MileTrack.w, 0, 0, node / 2 - L.MileLine.h / 2)} BackgroundColor3={Color3.fromRGB(74, 58, 80)} BorderSizePixel={0}>
							<frame Size={UDim2.fromScale(lit, 1)} BackgroundColor3={accent} BorderSizePixel={0} />
						</frame>
						{nodes}
					</>
				) : (
					<Line text="Every rebirth unlock is open" size={14} font={BODY_SEMI} color={Palette.muted} />
				)}
			</frame>
		</MockPanel>
	);

	const pair = (left: React.Element, right: React.Element, rightWidth: number | undefined, height: number, id: string): PageBlock => ({
		id,
		height: phone ? height * 2 + gap : height,
		element: (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<frame Size={phone ? new UDim2(1, 0, 0, height) : new UDim2(1, -(rightWidth ?? 0) - gap, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
					{left}
				</frame>
				<frame
					Size={phone ? new UDim2(1, 0, 0, height) : new UDim2(0, rightWidth ?? 0, 1, 0)}
					Position={phone ? UDim2.fromOffset(0, height + gap) : new UDim2(1, -(rightWidth ?? 0), 0, 0)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
				>
					{right}
				</frame>
			</frame>
		),
	});
	const right: PageBlock[] = [];
	// You get / You lose split evenly: give each half the same width
	right.push({
		id: "gainLose",
		height: phone ? listH * 2 + gap : listH,
		element: (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
				<frame Size={phone ? new UDim2(1, 0, 0, listH) : new UDim2(0.5, -gap / 2, 1, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
					{getPanel}
				</frame>
				<frame Size={phone ? new UDim2(1, 0, 0, listH) : new UDim2(0.5, -gap / 2, 1, 0)} Position={phone ? UDim2.fromOffset(0, listH + gap) : new UDim2(0.5, gap / 2, 0, 0)} BackgroundTransparency={1} BorderSizePixel={0}>
					{losePanel}
				</frame>
			</frame>
		),
	});
	right.push(pair(keepPanel, historyPanel, L.History.w, keepH, "keepHistory"));
	right.push({ id: "milestones", height: milestonesH, element: milestones });
	let rightH = 0;
	for (const block of right) rightH += block.height + gap;
	rightH -= gap;
	const dialH = phone ? panelHeight(true, dialContent) : math.max(panelHeight(false, dialContent), rightH);
	const dialBlock: PageBlock = { id: "dial", height: dialH, element: dialPanel };
	const wide = !phone && viewport.width >= 1280;
	const plan = splitColumns(wide ? viewport.width - 40 : 0, L.Dial.w, gap, 900);
	const body: PageBlock[] = plan.split
		? [splitSection("RebirthSplit", plan, gap, [dialBlock], right, false, ["dial", "gainLose", "keepHistory", "milestones"])]
		: [dialBlock, ...right];
	return (
		<>
			<PageScaffold sections={body} gap={gap} tailPad={72} scrollBarColor={accent} owner="RebirthView" />
			{chamberOpen && (
				<RebirthChamber state={state} config={config} dispatch={props.dispatch} reducedMotion={reducedMotion} onClose={() => setChamberOpen(false)} />
			)}
		</>
	);
}

export function RebirthView(props: RebirthViewProps) {
	const hostRef = React.useRef<Frame>();
	useFocusOrder(hostRef, { regions: ["dial", "gainLose", "keepHistory", "milestones"], first: ["dial"], columns: [["Side", "Main"]] }, [
		rebirthOf(props.state).Ready === true,
	]);
	return (
		<frame ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<RebirthBoard {...props} />
		</frame>
	);
}
