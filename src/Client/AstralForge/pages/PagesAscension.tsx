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
const GAP = 20;
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

function SigilCard(props: SigilCardProps) {
	const sigil = props.sigil;
	const color = SIGIL_COLORS[sigil.Id] ?? ACCENT;
	const pulse = useClock(!props.softMotion && sigil.Level > 0, 0.6, math.pi * 2);
	const boughtFlash = useFlipperSpring(sigil.Level, props.softMotion, 300, 22);
	const boosted = sigil.EffectiveLevel > sigil.Level;
	// narrow phones: the level number only needs ~44 px, so the name gets the rest of the row
	const levelW = useViewport().width < 420 ? 44 : 84;
	return (
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={20} accent={color} background={Palette.panelRaised} clips={false}>
			<frame Size={UDim2.fromOffset(52, 52)} BackgroundColor3={darken(color, 0.72)} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke
					Color={color}
					Thickness={2}
					Transparency={pulse.map((a) => (sigil.Level > 0 ? 0.15 + (math.sin(a) + 1) * 0.2 : 0.6))}
				/>
				<Ui.IconTile
					kind={SIGIL_ICONS[sigil.Id] ?? "StarGrid"}
					accent={color}
					size={34}
					position={UDim2.fromOffset(9, 9)}
					reducedMotion={props.softMotion}
				/>
			</frame>
			<Ui.Text
				value={sigil.Name}
				size={20}
				weight={Enum.FontWeight.Heavy}
				position={UDim2.fromOffset(66, 2)}
				sizeConstraint={new UDim2(1, -(66 + levelW), 0, 24)}
			/>
			<Ui.Text
				value={sigil.Line}
				size={13}
				color={Palette.muted}
				position={UDim2.fromOffset(66, 28)}
				sizeConstraint={new UDim2(1, -66, 0, 18)}
			/>
			<Ui.Text
				value={sigil.Level > 0 ? compact(sigil.Level) : "—"}
				size={13}
				color={color}
				weight={Enum.FontWeight.Heavy}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -levelW, 0, 4)}
				sizeConstraint={UDim2.fromOffset(levelW, 18)}
			/>
			<Ui.Text
				value={
					sigil.Level > 0
						? `×${compact(sigil.Multiplier)} ${sigil.Effect.lower()}` +
							(boosted ? `, as Lv ${compact(sigil.EffectiveLevel)}` : "")
						: "Buy a level to start it"
				}
				size={15}
				weight={Enum.FontWeight.Bold}
				color={Palette.cream}
				position={UDim2.fromOffset(0, 60)}
				sizeConstraint={new UDim2(1, 0, 0, 20)}
			/>
			<Ui.Button
				text={`${compact(sigil.Cost)}`}
				icon="StarGrid.2"
				color={sigil.Affordable ? color : Palette.panelSoft}
				textColor={sigil.Affordable ? Palette.ink : Palette.muted}
				disabled={!sigil.Affordable || props.busy}
				highlight={sigil.Affordable}
				size={new UDim2(1, 0, 0, 44)}
				position={new UDim2(0, 0, 1, -44)}
				reducedMotion={props.softMotion}
				onClick={() => props.onBuy(sigil.Id)}
			/>
			{/* a brief glow when a level lands */}
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={color}
				BackgroundTransparency={boughtFlash.map((value) => 1 - math.clamp(math.abs(value - sigil.Level), 0, 1) * 0.35)}
				BorderSizePixel={0}
				ZIndex={0}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
			</frame>
		</Ui.Panel>
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

	// hero (phones: a smaller orbit and a narrower left column so the copy keeps its width)
	const heroH = stack ? 216 : 176;
	const col = stack ? 104 : 140;
	const orbitX = stack ? 44 : 60;
	const outer = stack ? 38 : 52;
	const inner = stack ? 22 : 30;
	add(
		"hero",
		heroH,
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={stack ? 16 : 20} accent={ACCENT} background={darken(ACCENT, 0.9)} clips={true}>
			<Orbit
				count={12}
				radius={outer}
				dot={6}
				speed={1}
				color={ACCENT}
				position={new UDim2(0, orbitX, 0, outer + 12)}
				softMotion={softMotion}
				zIndex={2}
			/>
			<Orbit
				count={7}
				radius={inner}
				dot={5}
				speed={-1.6}
				color={lighten(ACCENT, 0.25)}
				position={new UDim2(0, orbitX, 0, outer + 12)}
				softMotion={softMotion}
				zIndex={2}
			/>
			<Ui.Text
				value={tostring(state.Rank)}
				size={stack ? 24 : 30}
				weight={Enum.FontWeight.Heavy}
				color={Palette.cream}
				align={Enum.TextXAlignment.Center}
				position={new UDim2(0, orbitX - 30, 0, outer + 12 - 18)}
				sizeConstraint={UDim2.fromOffset(60, 36)}
				zIndex={3}
			/>
			<Ui.Text
				value={state.Rank > 0 ? "Ascended" : "Ascension"}
				size={stack ? 22 : 26}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={16}
				position={UDim2.fromOffset(col, 9)}
				sizeConstraint={new UDim2(1, -col, 0, 32)}
			/>
			<Ui.Text
				value={`${compact(state.Aether)} Aether     ×${compact(state.Production)}`}
				size={14}
				color={Palette.creamSoft}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(col, 56)}
				sizeConstraint={new UDim2(1, -col, 0, stack ? 58 : 40)}
			/>
			<Ui.Text
				value="Resets your Domain, rebirths, cores and current run. Research, relics, artifacts, the Star Foundry and sigils stay."
				size={12}
				color={Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={stack ? UDim2.fromOffset(0, 124) : UDim2.fromOffset(col, 96)}
				sizeConstraint={stack ? new UDim2(1, 0, 0, 56) : new UDim2(1, -col, 0, 36)}
			/>
		</Ui.Panel>,
	);

	// ascend
	const progress = math.clamp(state.DomainRank / math.max(1, state.RequiredDomainRank), 0, 1);
	add(
		"ascend",
		stack ? 196 : 132,
		<Ui.Panel
			size={UDim2.fromScale(1, 1)}
			padding={18}
			accent={state.CanAscend ? ACCENT : Palette.lineSoft}
			background={Palette.panel}
		>
			<Ui.Text
				value={
					state.CanAscend
						? `+${compact(state.Gain)} Aether`
						: `Domain ${state.DomainRank} / ${state.RequiredDomainRank}`
				}
				size={19}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, 26)}
			/>
			<Ui.Text
				value={
					state.CanAscend ? `Domain ${state.DomainRank} / ${state.RequiredDomainRank}` : ""
				}
				size={13}
				color={Palette.muted}
				position={UDim2.fromOffset(0, 30)}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, 18)}
			/>
			<Ui.Meter
				value={progress}
				color={ACCENT}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, 58)}
				size={new UDim2(1, stack ? 0 : -300, 0, 4)}
			/>
			<Ui.Text
				value={`next ×${compact(state.NextRankProduction)}`}
				size={12}
				color={Palette.creamSoft}
				position={UDim2.fromOffset(0, 76)}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, 16)}
			/>
			<frame
				key="AscendConfirm"
				Size={stack ? new UDim2(1, 0, 0, TapTarget + 8) : UDim2.fromOffset(280, 64)}
				Position={stack ? new UDim2(0, 0, 1, -(TapTarget + 8)) : new UDim2(1, -280, 0.5, -32)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<HoldButton
					enabled={state.CanAscend && !busy}
					text="Hold"
					disabledText="Not ready"
					size={UDim2.fromScale(1, 1)}
					position={UDim2.fromOffset(0, 0)}
					onConfirm={() => request("Ascend")}
				/>
			</frame>
		</Ui.Panel>,
	);
	if (note !== "") {
		add("note", 28, <Ui.Text value={note} size={14} color={Palette.creamSoft} sizeConstraint={new UDim2(1, 0, 0, 24)} />);
	}

	// harmony
	// pips sat at y 40 in a 54 px body (12 px past the panel); phones get two rows of three so names fit
	const pipCols = stack ? 3 : 6;
	const pipRows = math.ceil(state.Sigils.size() / pipCols);
	const pips: Record<string, React.Element> = {};
	state.Sigils.forEach((sigil, index) => {
		const color = SIGIL_COLORS[sigil.Id] ?? ACCENT;
		pips[sigil.Id] = (
			<frame
				Size={new UDim2(1 / pipCols, -8, 0, 26)}
				Position={new UDim2((index % pipCols) / pipCols, 4, 0, 30 + math.floor(index / pipCols) * 32)}
				BackgroundColor3={darken(color, sigil.Level > state.Harmony ? 0.4 : 0.75)}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<Ui.Text
					value={`${sigil.Name} ${compact(sigil.Level)}`}
					size={11}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Center}
					fit={false}
					sizeConstraint={new UDim2(1, -12, 0, 26)}
					position={UDim2.fromOffset(6, 0)}
				/>
			</frame>
		);
	});
	add(
		"harmony",
		28 + 30 + pipRows * 26 + (pipRows - 1) * 6,
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={14} accent={Palette.mint} background={Palette.panel}>
			<Ui.Text
				value={
					state.Harmony > 0
						? `Harmony ${state.Harmony}: started sigils act ${state.Harmony} level${state.Harmony === 1 ? "" : "s"} higher`
						: "Harmony 0: raise all six together"
				}
				size={15}
				weight={Enum.FontWeight.Bold}
				sizeConstraint={new UDim2(1, 0, 0, 22)}
			/>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				{pips}
			</frame>
		</Ui.Panel>,
	);

	// sigils
	// wide desktop: the star charts get their own column beside the Ascension board
	const plan = splitColumns(stack || !typeIs(props.state.Constellations, "table") ? 0 : viewport.width, 440, GAP, 1500);
	const sideColumn = plan.split;
	const columns = stack ? 1 : sideColumn ? 2 : viewport.width >= 1300 ? 3 : 2;
	const cardH = 168;
	const rows = math.ceil(state.Sigils.size() / columns);
	const cards: Record<string, React.Element> = {};
	state.Sigils.forEach((sigil, index) => {
		const cardCol = index % columns;
		const row = math.floor(index / columns);
		cards[sigil.Id] = (
			<frame
				Size={new UDim2(1 / columns, -GAP + GAP / columns, 0, cardH)}
				Position={new UDim2(cardCol / columns, (cardCol * GAP) / columns, 0, row * (cardH + GAP))}
				BackgroundTransparency={1}
			>
				<SigilCard sigil={sigil} softMotion={softMotion} busy={busy} onBuy={(id) => request("UpgradeSigil", { Id: id })} />
			</frame>
		);
	});
	add(
		"sigils",
		rows * cardH + (rows - 1) * GAP,
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{cards}
		</frame>,
	);

	// v8 star charts: every rebirth is a Star Point
	const charts = props.state.Constellations;
	if (typeIs(charts, "table")) {
		add(
			"constellations",
			constellationsHeight(stack || sideColumn),
			<ConstellationsView
				state={charts}
				stack={stack || sideColumn}
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
		const split = splitSection("AscensionSplit", plan, GAP, side, main, false, sections.map((section) => section.id));
		return <PageScaffold sections={[split]} gap={GAP} tailPad={72} scrollBarColor={ACCENT} />;
	}
	return <PageScaffold sections={sections} gap={GAP} tailPad={72} scrollBarColor={ACCENT} />;
}


function AscensionView(props: AscensionViewProps) {
	const hostRef = React.useRef<Frame>();
	useFocusOrder(
		hostRef,
		// explicit pad order down the board; Hold first when it can be pressed, then the sigils; the charts column links left/right
		{ regions: ["hero", "AscendConfirm", "ascend", "harmony", "sigils", "constellations"], first: ["AscendConfirm", "sigils"], columns: [["Main", "Side"]] },
		[props.state.Ascension?.CanAscend === true, props.state.Ascension?.Rank],
	);
	return (
		<frame ref={hostRef} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0}>
			<AscensionViewBoard {...props} />
		</frame>
	);
}

export = () => ({ AscensionView });
