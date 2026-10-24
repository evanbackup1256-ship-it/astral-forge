// Ascension: the final, endless reset. One hero (rank, Aether, production), the ascend panel with a
// hold-to-confirm button, a harmony strip, and the six sigils.
import React from "@rbxts/react";
import { useFocusOrder } from "../CoreKit/focusOrder";
import { splitColumns } from "../UiCore/ui";
import { splitSection } from "./layoutRise";
import { compactNumber } from "../CoreKit/format";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { useClock, useFlipperSpring, useViewport } from "../MotionKit/motion";
import { ConstellationsView, constellationsHeight, ConstellationState } from "./PagesProgress/ConstellationsView";
import { AudioPlayer, kitMember, LuauComponent } from "./luauKits";
import { Bar, BODY, BODY_SEMI, Chip, Line, MockPanel, mockGap, NUM, PanelHeading, panelPad, RowSurface } from "../UiCore/mockKit";
import { Grid, headingBlock, IconWell, MockBtn, MockRow, panelHeight, rowHeight } from "./mockRows";

const RunService = game.GetService("RunService");
const Ui = kitMember<Record<string, LuauComponent>>("UiCore", "ui");
const { PageScaffold } = kitMember<{ PageScaffold: LuauComponent }>("LayoutKit", "pageScaffold");
const { Audio } = kitMember<{ Audio: AudioPlayer }>("AudioKit", "audio");

const ACCENT = Color3.fromRGB(255, 196, 120); // warm aether gold
const SIGIL_COLORS: Record<string, Color3 | undefined> = {
	Sol: Color3.fromRGB(255, 184, 52),
	Bastion: Color3.fromRGB(96, 166, 255),
	Strike: Color3.fromRGB(255, 104, 112),
	Ember: Color3.fromRGB(250, 104, 178),
	Crown: Color3.fromRGB(178, 134, 255),
	Lodestar: Color3.fromRGB(86, 236, 178),
};
const SIGIL_ICONS: Record<string, string | undefined> = {
	Sol: "Forge",
	Bastion: "Vault",
	Strike: "Overcharge",
	Ember: "Rebirth",
	Crown: "Domain",
	Lodestar: "StarGrid",
};
// generated from design/10-ascension by scripts/gen_from_layout.js (scripts/layout/ascension.spec.json)
import { AscensionLayout as L } from "./generated/AscensionLayout";
const GAP = 18;
const HOLD_SECONDS = 1.6;

type Flux = number | string;
interface Sigil {
	Id: string;
	Name: string;
	Line: string;
	Effect: string;
	Level: number;
	EffectiveLevel: number;
	Multiplier: Flux;
	Cost: Flux;
	Affordable: boolean;
}
interface AscensionState {
	Rank: number;
	Aether: Flux;
	Production: Flux;
	DomainRank: number;
	RequiredDomainRank: number;
	CanAscend: boolean;
	Gain: Flux;
	NextRankProduction: Flux;
	Harmony: number;
	Sigils: Sigil[];
}
interface Response {
	ok?: boolean;
	message?: string;
	error?: string;
}
interface Section {
	id: string;
	height: number;
	element: React.Element;
}

function compact(value: unknown) {
	return compactNumber(value);
}

interface OrbitProps {
	count: number;
	radius: number;
	dot: number;
	speed: number;
	color: Color3;
	position: UDim2;
	softMotion?: boolean;
	zIndex: number;
}

// A ring of dots around a centre: the Ascension mark. Icons never move (QA rule), so the ring is still.
function Orbit(props: OrbitProps) {
	const spin = useClock(!props.softMotion, 0.05, math.pi * 2);
	const dots: Record<string, React.Element> = {};
	for (let index = 1; index <= props.count; index++) {
		const phase = ((index - 1) / props.count) * math.pi * 2;
		dots["d" + index] = (
			<frame
				Size={UDim2.fromOffset(props.dot, props.dot)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={spin.map((angle) => {
					const a = angle * props.speed + phase;
					return new UDim2(0.5, math.cos(a) * props.radius, 0.5, math.sin(a) * props.radius);
				})}
				BackgroundColor3={props.color}
				BackgroundTransparency={0.15 + (index % 3) * 0.2}
				BorderSizePixel={0}
				ZIndex={props.zIndex}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}
	return (
		<frame
			Size={UDim2.fromOffset(props.radius * 2 + props.dot, props.radius * 2 + props.dot)}
			Position={props.position}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			ZIndex={props.zIndex}
		>
			{dots}
		</frame>
	);
}

// Concentric tilted rings around the ascension star; one ring per tier, nodes sit still (icons don't move).
const TIER_RINGS = 3;
function OrbitDiagram(props: { rank: number; height: number }) {
	const rings: Record<string, React.Element> = {};
	const tilt = -18;
	for (let i = 1; i <= TIER_RINGS; i++) {
		const w = props.height * (0.55 + i * 0.42);
		const h = w * 0.42;
		const lit = props.rank >= i;
		const nodes: Record<string, React.Element> = {};
		for (let n = 0; n < 2; n++) {
			const a = (n * math.pi) + i * 0.9;
			nodes["n" + n] = (
				<frame
					Size={UDim2.fromOffset(lit ? 12 : 8, lit ? 12 : 8)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Position={new UDim2(0.5 + math.cos(a) * 0.5, 0, 0.5 + math.sin(a) * 0.5, 0)}
					BackgroundColor3={lit ? Palette.pink : Palette.panel}
					BorderSizePixel={0}
					ZIndex={3}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={Palette.violet} Thickness={1.5} />
				</frame>
			);
		}
		rings["ring" + i] = (
			<frame Size={UDim2.fromOffset(w, h)} AnchorPoint={new Vector2(0.5, 0.5)} Position={UDim2.fromScale(0.5, 0.5)} Rotation={tilt} BackgroundTransparency={1} ZIndex={2}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.violet} Thickness={lit ? 2 : 1} Transparency={lit ? 0.15 : 0.55} />
				{nodes}
			</frame>
		);
	}
	const core = math.floor(props.height * 0.22);
	return (
		<frame Size={new UDim2(1, 0, 0, props.height)} BackgroundTransparency={1} ClipsDescendants={false}>
			{rings}
			<frame Size={UDim2.fromOffset(core, core)} AnchorPoint={new Vector2(0.5, 0.5)} Position={UDim2.fromScale(0.5, 0.5)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ZIndex={4}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={Palette.violet} Thickness={2} />
				<Ui.Text value={tostring(props.rank)} size={math.floor(core * 0.45)} weight={Enum.FontWeight.Heavy} align={Enum.TextXAlignment.Center} position={new UDim2(0, 0, 0.5, -math.floor(core * 0.3))} sizeConstraint={new UDim2(1, 0, 0, math.floor(core * 0.6))} zIndex={5} />
			</frame>
		</frame>
	);
}

interface HoldButtonProps {
	enabled: boolean;
	text: string;
	disabledText: string;
	size: UDim2;
	position: UDim2;
	onConfirm: () => void;
}

function isPress(input: InputObject) {
	return (
		input.UserInputType === Enum.UserInputType.MouseButton1 ||
		input.UserInputType === Enum.UserInputType.Touch ||
		input.KeyCode === Enum.KeyCode.ButtonA
	);
}

// Press and hold to ascend; letting go early cancels. It resets everything below it, so a tap is
// never enough.
function HoldButton(props: HoldButtonProps) {
	const [fill, setFill] = React.useBinding(0);
	const holding = React.useRef<RBXScriptConnection>();
	const enabled = props.enabled;
	const release = React.useRef<RBXScriptConnection>();
	const stop = () => {
		if (holding.current) {
			holding.current.Disconnect();
			holding.current = undefined;
		}
		release.current?.Disconnect();
		release.current = undefined;
		setFill(0);
	};
	React.useEffect(() => stop, []);
	// losing eligibility mid-hold (a snapshot lands) cancels instead of confirming on stale props
	React.useEffect(() => {
		if (!enabled) {
			stop();
		}
	}, [enabled]);
	const begin = (pressed: InputObject) => {
		if (!enabled || holding.current) {
			return;
		}
		Audio.play("rebirthCharge");
		const started = os.clock();
		// a finger or button released anywhere (dragged off the button first) still counts as letting go
		release.current = game.GetService("UserInputService").InputEnded.Connect((input) => {
			if (input.UserInputType === pressed.UserInputType && input.KeyCode === pressed.KeyCode) {
				stop();
			}
		});
		holding.current = RunService.Heartbeat.Connect(() => {
			const amount = math.clamp((os.clock() - started) / HOLD_SECONDS, 0, 1);
			setFill(amount);
			if (amount >= 1) {
				stop();
				props.onConfirm();
			}
		});
	};
	return (
		<textbutton
			Size={props.size}
			Position={props.position}
			BackgroundColor3={enabled ? darken(ACCENT, 0.55) : Palette.panelSoft}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Text=""
			Active={enabled}
			Selectable={enabled}
			ClipsDescendants={true}
			Event={{
				InputBegan: (_, input) => {
					if (isPress(input)) {
						begin(input);
					}
				},
				InputEnded: (_, input) => {
					if (isPress(input)) {
						if (holding.current) {
							Audio.play("close");
						}
						stop();
					}
				},
				MouseLeave: stop,
			}}
		>
			<uicorner CornerRadius={new UDim(0, 14)} />
			<uistroke Color={enabled ? ACCENT : Palette.lineSoft} Transparency={0.25} Thickness={1.5} />
			<frame
				key="Fill"
				Size={fill.map((a) => UDim2.fromScale(a, 1))}
				BackgroundColor3={ACCENT}
				BorderSizePixel={0}
				ZIndex={2}
			/>
			<textlabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Text={fill.map((a) => {
					if (!enabled) {
						return props.disabledText;
					}
					return a > 0 ? "Keep holding…" : props.text;
				})}
				TextColor3={fill.map((a) => (a > 0.5 ? Palette.ink : Palette.cream))}
				TextSize={16}
				TextTruncate={Enum.TextTruncate.AtEnd}
				FontFace={new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)}
				ZIndex={3}
			>
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} />
			</textlabel>
		</textbutton>
	);
}

interface SigilCardProps {
	sigil: Sigil;
	softMotion?: boolean;
	busy: boolean;
	onBuy: (id: string) => void;
}

// sigil cell: a .row column (radius 11) with the icon well, name + line, level, effect and a cost button
const SIGIL_CELL_H = 150;
function SigilCard(props: SigilCardProps & { phone: boolean }) {
	const sigil = props.sigil;
	const color = SIGIL_COLORS[sigil.Id] ?? ACCENT;
	const pulse = useClock(!props.softMotion && sigil.Level > 0, 0.6, math.pi * 2);
	const boughtFlash = useFlipperSpring(sigil.Level, props.softMotion, 300, 22);
	const boosted = sigil.EffectiveLevel > sigil.Level;
	const phone = props.phone;
	const pad = phone ? 10 : 14;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.white} BorderSizePixel={0}>
			<RowSurface />
			<uistroke
				Color={color}
				Thickness={1}
				Transparency={pulse.map((a) => (sigil.Level > 0 ? 0.55 + (math.sin(a) + 1) * 0.15 : 0.92))}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			/>
			<uipadding PaddingLeft={new UDim(0, pad)} PaddingRight={new UDim(0, pad)} PaddingTop={new UDim(0, pad)} PaddingBottom={new UDim(0, pad)} />
			<IconWell icon={SIGIL_ICONS[sigil.Id] ?? "StarGrid"} accent={color} />
			<Line text={sigil.Name} size={phone ? 13 : 15} font={BODY_SEMI} position={UDim2.fromOffset(48, 0)} width={new UDim(1, -48 - 70)} height={19} />
			<Line text={sigil.Line} size={phone ? 11 : 12} font={BODY} color={Palette.muted} position={UDim2.fromOffset(48, 21)} width={new UDim(1, -48)} height={15} />
			<Line text={sigil.Level > 0 ? `Lv ${compact(sigil.Level)}` : "Lv 0"} size={phone ? 14 : 17} font={NUM} color={color} position={UDim2.fromScale(1, 0)} anchor={new Vector2(1, 0)} width={new UDim(0, 70)} align={Enum.TextXAlignment.Right} />
			<Line
				text={
					sigil.Level > 0
						? `×${compact(sigil.Multiplier)} ${sigil.Effect.lower()}` + (boosted ? `, as Lv ${compact(sigil.EffectiveLevel)}` : "")
						: "Buy a level to start it"
				}
				size={phone ? 12 : 13}
				font={BODY_SEMI}
				color={Palette.creamSoft}
				position={UDim2.fromOffset(0, 46)}
				width={new UDim(1, 0)}
			/>
			<MockBtn
				text={compact(sigil.Cost)}
				icon="StarGrid"
				sm={true}
				phone={phone}
				fill={true}
				accent={color}
				disabled={!sigil.Affordable || props.busy}
				position={new UDim2(0, 0, 1, 0)}
				anchor={new Vector2(0, 1)}
				reducedMotion={props.softMotion}
				onClick={() => props.onBuy(sigil.Id)}
			/>
			{/* a brief glow when a level lands */}
			<frame
				Size={new UDim2(1, pad * 2, 1, pad * 2)}
				Position={UDim2.fromOffset(-pad, -pad)}
				BackgroundColor3={color}
				BackgroundTransparency={boughtFlash.map((value) => 1 - math.clamp(math.abs(value - sigil.Level), 0, 1) * 0.35)}
				BorderSizePixel={0}
				ZIndex={0}
			>
				<uicorner CornerRadius={new UDim(0, 11)} />
			</frame>
		</frame>
	);
}

interface AscensionViewProps {
	state: { Ascension?: AscensionState; Constellations?: ConstellationState };
	reducedMotion?: boolean;
	dispatch: (action: string, payload: object, callback: (response: unknown) => void) => void;
}

function AscensionViewBoard(props: AscensionViewProps) {
	const state = props.state.Ascension;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const [busy, setBusy] = React.useState(false);
	const [note, setNote] = React.useState("");
	const request = (action: string, payload?: object) => {
		if (busy) {
			return;
		}
		setBusy(true);
		props.dispatch(action, payload ?? {}, (raw) => {
			setBusy(false);
			if (typeIs(raw, "table")) {
				const response = raw as Response;
				setNote(response.ok ? (response.message ?? "") : (response.error ?? "That didn't work."));
				Audio.play(response.ok ? "successChime" : "error");
			}
		});
	};
	const sections: Section[] = [];
	const add = (id: string, height: number, element: React.Element) => {
		sections.push({ id, height, element });
	};
	if (!typeIs(state, "table")) {
		add(
			"loading",
			80,
			<Ui.Text value="Loading Ascension…" size={16} color={Palette.muted} sizeConstraint={new UDim2(1, 0, 0, 24)} />,
		);
		return <PageScaffold sections={sections} gap={GAP} tailPad={72} />;
	}

	// 10-ascension: orbit panel (f1) beside the 480px tier perks panel; harmony and sigils follow as panels
	const phone = stack;
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const head = headingBlock(phone);
	const progress = math.clamp(state.DomainRank / math.max(1, state.RequiredDomainRank), 0, 1);
	const rowH2 = rowHeight(phone, true);
	const reqRows: [string, string, string, string, boolean][] = [
		["Domain", "Domain rank", "Reach it to ascend", `${state.DomainRank} / ${state.RequiredDomainRank}`, state.DomainRank >= state.RequiredDomainRank],
		["StarGrid", "Aether gain", "Paid when you ascend", `+${compact(state.Gain)}`, state.CanAscend],
		["Forge", "Next tier", "Production multiplier", `×${compact(state.NextRankProduction)}`, false],
	];
	const btnH = phone ? TapTarget : L.PerksBtn.h;
	const perksContent = head + reqRows.size() * (rowH2 + pad.gap) + pad.gap + L.PerksBar.h + pad.gap + btnH;
	const perksH = panelHeight(phone, perksContent);
	const diagramH = phone ? 220 : L.OrbitArt.h;
	const statsH = L.Stats.h;
	const orbitContent = diagramH + L.Orbit.gap + statsH;
	const boardH = phone ? panelHeight(true, orbitContent) + gap + perksH : math.max(panelHeight(false, orbitContent), perksH);
	const perks = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} reducedMotion={softMotion} name="TierPerks">
			<PanelHeading icon="StarGrid" title={`Tier ${state.Rank + 1}`} accent={Palette.violet} phone={phone} layoutOrder={0} />
			{reqRows.map(([icon, label, sub, value, met], i) => (
				<MockRow key={"r" + i} phone={phone} icon={icon} accent={Palette.violet} dim={!met} title={label} sub={sub} value={value} valueColor={met ? Palette.violet : Palette.creamSoft} layoutOrder={i + 1} />
			))}
			<frame Size={new UDim2(1, 0, 0, math.max(0, (phone ? perksH : boardH) - perksH))} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={8} />
			<Bar fill={progress} color={Palette.violet} layoutOrder={9} />
			<frame key="AscendConfirm" Size={new UDim2(1, 0, 0, btnH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={10}>
				<HoldButton
					enabled={state.CanAscend && !busy}
					text="Hold to ascend"
					disabledText={`Ascend at Domain ${state.RequiredDomainRank}`}
					size={UDim2.fromScale(1, 1)}
					position={UDim2.fromOffset(0, 0)}
					onConfirm={() => request("Ascend")}
				/>
			</frame>
		</MockPanel>
	);
	const diagram = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.violet} glow={Palette.violet} reducedMotion={softMotion} name="AscensionOrbit">
			<frame Size={new UDim2(1, 0, 0, diagramH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0} ClipsDescendants={true}>
				<OrbitDiagram rank={state.Rank} height={diagramH} />
			</frame>
			<frame Size={new UDim2(1, 0, 0, statsH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} HorizontalAlignment={Enum.HorizontalAlignment.Center} Padding={new UDim(0, L.Stats.gap)} SortOrder={Enum.SortOrder.LayoutOrder} />
				<Line text={`Domain ${state.DomainRank} / ${state.RequiredDomainRank}`} size={L.Stat.text.size} font={BODY_SEMI} color={Palette.cream} layoutOrder={0} />
				<Line text={`Aether ${compact(state.Aether)}`} size={L.Stat.text.size} font={BODY_SEMI} color={Palette.cream} layoutOrder={1} />
				<Line text={`Production ×${compact(state.Production)}`} size={L.Stat.text.size} font={BODY_SEMI} color={L.Stat.text.color} layoutOrder={2} />
			</frame>
		</MockPanel>
	);
	add(
		"ascend",
		boardH,
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<frame Size={phone ? new UDim2(1, 0, 0, boardH - perksH - gap) : new UDim2(1, -(L.Perks.w + gap), 1, 0)} BackgroundTransparency={1}>
				{diagram}
			</frame>
			<frame Size={phone ? new UDim2(1, 0, 0, perksH) : new UDim2(0, L.Perks.w, 1, 0)} Position={phone ? new UDim2(0, 0, 1, -perksH) : new UDim2(1, -L.Perks.w, 0, 0)} BackgroundTransparency={1}>
				{perks}
			</frame>
		</frame>,
	);
	if (note !== "") {
		add("note", 24, <Line text={note} size={14} font={BODY_SEMI} color={Palette.creamSoft} width={new UDim(1, 0)} />);
	}

	// harmony: one chip per sigil, accent when it is above the harmony floor
	const harmonyLine =
		state.Harmony > 0
			? `Started sigils act ${state.Harmony} level${state.Harmony === 1 ? "" : "s"} higher`
			: "Raise all six together";
	const chips: React.Element[] = [];
	state.Sigils.forEach((sigil, index) => {
		const color = SIGIL_COLORS[sigil.Id] ?? ACCENT;
		chips.push(<Chip key={sigil.Id} text={`${sigil.Name} ${compact(sigil.Level)}`} accent={sigil.Level > state.Harmony ? color : undefined} layoutOrder={index} phone={phone} />);
	});
	const chipRows = phone ? 2 : 1;
	const chipH = phone ? 24 : 28;
	add(
		"harmony",
		panelHeight(phone, head + chipRows * chipH + (chipRows - 1) * 6),
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} accent={Palette.mint} reducedMotion={softMotion} name="Harmony">
			<PanelHeading icon="Wave" title={`Harmony ${state.Harmony}`} note={harmonyLine} accent={Palette.mint} phone={phone} layoutOrder={0} />
			<frame Size={new UDim2(1, 0, 0, chipRows * chipH + (chipRows - 1) * 6)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps={true} Padding={new UDim(0, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{chips}
			</frame>
		</MockPanel>,
	);

	// sigils
	// wide desktop: the star charts get their own column beside the Ascension board
	const plan = splitColumns(stack || !typeIs(props.state.Constellations, "table") ? 0 : viewport.width, 440, gap, 1500);
	const sideColumn = plan.split;
	const columns = stack ? 1 : sideColumn ? 2 : viewport.width >= 1300 ? 3 : 2;
	const rows = math.ceil(state.Sigils.size() / columns);
	const cellH = phone ? SIGIL_CELL_H - 20 + TapTarget - 36 : SIGIL_CELL_H;
	const cells: React.Element[] = [];
	state.Sigils.forEach((sigil, index) => {
		cells.push(
			<frame key={sigil.Id} BackgroundTransparency={1} LayoutOrder={index}>
				<SigilCard sigil={sigil} softMotion={softMotion} busy={busy} phone={phone} onBuy={(id) => request("UpgradeSigil", { Id: id })} />
			</frame>,
		);
	});
	add(
		"sigils",
		panelHeight(phone, head + rows * cellH + (rows - 1) * 12),
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={softMotion} name="Sigils">
			<PanelHeading icon="StarGrid" title="Sigils" note={`${compact(state.Aether)} Aether`} phone={phone} layoutOrder={0} />
			<Grid columns={columns} gap={12} cellHeight={cellH} count={state.Sigils.size()} layoutOrder={1}>
				{cells}
			</Grid>
		</MockPanel>,
	);

	// v8 star charts: every rebirth is a Star Point
	const charts = props.state.Constellations;
	// the room the charts get: their side column, or the page width less its padding
	const chartsWidth = sideColumn ? plan.side : math.max(0, viewport.width - 48);
	if (typeIs(charts, "table")) {
		add(
			"constellations",
			constellationsHeight(stack || sideColumn, chartsWidth, stack),
			<ConstellationsView
				state={charts}
				stack={stack || sideColumn}
				width={chartsWidth}
				phone={stack}
				reducedMotion={softMotion}
				dispatch={(action, payload, callback) =>
					props.dispatch(action, payload ?? {}, (raw) => {
						const response = (typeIs(raw, "table") ? raw : {}) as { ok?: boolean; message?: string; error?: string };
						Audio.play(response.ok === true ? "successChime" : "error");
						setNote(response.ok === true ? (response.message ?? "") : (response.error ?? "That didn't work."));
						callback?.(response);
					})
				}
			/>,
		);
	}
	if (sideColumn) {
		const side = sections.filter((section) => section.id === "constellations");
		const main = sections.filter((section) => section.id !== "constellations");
		const split = splitSection("AscensionSplit", plan, gap, side, main, true, sections.map((section) => section.id));
		return <PageScaffold sections={[split]} gap={gap} tailPad={72} scrollBarColor={ACCENT} />;
	}
	return <PageScaffold sections={sections} gap={gap} tailPad={72} scrollBarColor={ACCENT} />;
}


function AscensionView(props: AscensionViewProps) {
	const hostRef = React.useRef<Frame>();
	useFocusOrder(
		hostRef,
		// explicit pad order down the board; Hold first when it can be pressed, then the sigils; the charts column links left/right
		{ regions: ["AscendConfirm", "ascend", "harmony", "sigils", "constellations"], first: ["AscendConfirm", "sigils"], columns: [["Main", "Side"]] },
		[props.state.Ascension?.CanAscend === true, props.state.Ascension?.Rank],
	);
	return (
		<frame ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<AscensionViewBoard {...props} />
		</frame>
	);
}

export = () => ({ AscensionView });
