// Ascension: the final, endless reset, drawn as an orrery.
//
// The six sigils are planets on two orbits around the Ascension core; the core is the thing you hold. A
// ring of sixty beads around it fills as your Domain rank approaches the requirement and lights solid when
// you can ascend. Holding the core (or the button beside it) charges the beads white and pulls every planet
// inward; at full charge you ascend. The lines between planets are the harmony: they light as all six sigils
// rise together. Pick a planet to read it and level it up. Nothing here is a card or a list.
import React from "@rbxts/react";
import { compactNumber } from "../CoreKit/format";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { useClock, useFlash, useFlipperSpring, useViewport } from "../MotionKit/motion";
import { ConstellationsView, constellationsHeight, ConstellationState } from "./PagesProgress/ConstellationsView";
import { AudioPlayer, kitMember, LuauComponent } from "./luauKits";

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
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
const HOLD_SECONDS = 1.8;
const BEADS = 60;
const TAU = math.pi * 2;

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

function isPress(input: InputObject) {
	return (
		input.UserInputType === Enum.UserInputType.MouseButton1 ||
		input.UserInputType === Enum.UserInputType.Touch ||
		input.KeyCode === Enum.KeyCode.ButtonA
	);
}

// Press and hold; letting go early cancels. The charge is shared, so the core and the button beside it
// show the same fill. Losing eligibility mid-hold (a snapshot lands) cancels instead of confirming on stale props.
function useHold(enabled: boolean, onConfirm: () => void) {
	const [charge, setCharge] = React.useBinding(0);
	const beat = React.useRef<RBXScriptConnection>();
	const release = React.useRef<RBXScriptConnection>();
	const confirmRef = React.useRef(onConfirm);
	confirmRef.current = onConfirm;
	const stop = () => {
		beat.current?.Disconnect();
		beat.current = undefined;
		release.current?.Disconnect();
		release.current = undefined;
		setCharge(0);
	};
	React.useEffect(() => stop, []);
	React.useEffect(() => {
		if (!enabled) {
			stop();
		}
	}, [enabled]);
	const begin = (pressed: InputObject) => {
		if (!enabled || beat.current !== undefined) {
			return;
		}
		Audio.play("rebirthCharge");
		const started = os.clock();
		release.current = UserInputService.InputEnded.Connect((input) => {
			if (input.UserInputType === pressed.UserInputType && input.KeyCode === pressed.KeyCode) {
				stop();
			}
		});
		beat.current = RunService.Heartbeat.Connect(() => {
			const amount = math.clamp((os.clock() - started) / HOLD_SECONDS, 0, 1);
			setCharge(amount);
			if (amount >= 1) {
				stop();
				confirmRef.current();
			}
		});
	};
	const events = {
		InputBegan: (_: unknown, input: InputObject) => {
			if (isPress(input)) {
				begin(input);
			}
		},
		InputEnded: (_: unknown, input: InputObject) => {
			if (isPress(input)) {
				if (beat.current !== undefined) {
					Audio.play("close");
				}
				stop();
			}
		},
		MouseLeave: stop,
	};
	return { charge, events };
}

// where planet `index` is, in fractions of the orrery: two orbits turning together, pulled inward by the charge
function planetAt(index: number, t: number, pull: number): Vector2 {
	const inner = index % 2 === 0;
	const orbit = (inner ? 0.3 : 0.405) * (1 - pull * 0.6);
	// both orbits turn together: planets on opposite drifts slid over each other (and over each other's tap area)
	const turn = t * 0.09;
	const angle = (index / 6) * TAU - math.pi / 2 + turn;
	return new Vector2(0.5 + math.cos(angle) * orbit, 0.5 + math.sin(angle) * orbit);
}

interface PlanetProps {
	sigil: Sigil;
	index: number;
	size: number;
	selected: boolean;
	clock: React.Binding<number>;
	charge: React.Binding<number>;
	reduced?: boolean;
	onPick: (id: string) => void;
}

function Planet(props: PlanetProps) {
	const { sigil, size } = props;
	const color = SIGIL_COLORS[sigil.Id] ?? ACCENT;
	const lift = useFlipperSpring(props.selected ? 1 : 0, props.reduced, 420, 26);
	const pop = useFlash(sigil.Level, props.reduced, 0.5);
	const dot = math.floor(size * 0.82);
	return (
		<textbutton
			key={sigil.Id}
			Size={UDim2.fromOffset(size, size)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Position={React.joinBindings([props.clock, props.charge]).map(([t, pull]) => {
				const p = planetAt(props.index, t, pull);
				return UDim2.fromScale(p.X, p.Y);
			})}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Text=""
			ZIndex={6}
			Event={{ Activated: () => props.onPick(sigil.Id) }}
		>
			<uiscale Scale={React.joinBindings([lift, pop]).map(([l, p]) => 1 + l * 0.18 + math.sin(math.clamp(p, 0, 1) * math.pi) * 0.14)} />
			{/* the affordable ones breathe a ring, so the next purchase is easy to spot */}
			{sigil.Affordable && (
				<frame
					Size={props.clock.map((t) => {
						const s = size * (1.05 + 0.18 * (0.5 + 0.5 * math.sin(t * 2.2 + props.index)));
						return UDim2.fromOffset(s, s);
					})}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Position={UDim2.fromScale(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={5}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={lighten(color, 0.3)} Thickness={1.5} Transparency={0.45} />
				</frame>
			)}
			<frame
				Size={UDim2.fromOffset(dot, dot)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				BackgroundColor3={darken(color, sigil.Level > 0 ? 0.6 : 0.82)}
				BorderSizePixel={0}
				ZIndex={6}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={color} Thickness={props.selected ? 3 : 1.6} Transparency={sigil.Level > 0 ? 0.05 : 0.5} />
				<Ui.IconTile
					kind={SIGIL_ICONS[sigil.Id] ?? "StarGrid"}
					accent={color}
					size={math.floor(dot * 0.58)}
					position={new UDim2(0.5, -math.floor(dot * 0.29), 0.5, -math.floor(dot * 0.29) - 3)}
					reducedMotion={props.reduced}
				/>
				<Ui.Text
					value={sigil.Level > 0 ? `Lv ${compact(sigil.Level)}` : "New"}
					size={11}
					weight={Enum.FontWeight.Heavy}
					color={sigil.Level > 0 ? lighten(color, 0.4) : Palette.muted}
					align={Enum.TextXAlignment.Center}
					position={new UDim2(0, 0, 1, -math.floor(dot * 0.2) - 8)}
					sizeConstraint={new UDim2(1, 0, 0, 14)}
					zIndex={8}
				/>
			</frame>
		</textbutton>
	);
}

interface OrreryProps {
	state: AscensionState;
	size: number;
	selected: string;
	reduced?: boolean;
	busy: boolean;
	onPick: (id: string) => void;
	hold: ReturnType<typeof useHold>;
}

function Orrery(props: OrreryProps) {
	const { state, size, hold } = props;
	const clock = useClock(!props.reduced, 1, 3600, true);
	const progress = math.clamp(state.DomainRank / math.max(1, state.RequiredDomainRank), 0, 1);
	const lit = math.floor(progress * BEADS + 0.5);
	const planetSize = math.floor(size * 0.17);
	const coreSize = math.floor(size * 0.27);

	// the bead ring: lit by progress, then flooded white by the hold charge
	const beads: Record<string, React.Element> = {};
	for (let i = 0; i < BEADS; i++) {
		const a = (i / BEADS) * TAU - math.pi / 2;
		const isLit = i < lit || state.CanAscend;
		beads["b" + i] = (
			<frame
				Size={UDim2.fromOffset(i % 5 === 0 ? 6 : 4, i % 5 === 0 ? 6 : 4)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5 + math.cos(a) * 0.475, 0.5 + math.sin(a) * 0.475)}
				BackgroundColor3={hold.charge.map((c) => (c * BEADS > i ? Palette.cream : isLit ? ACCENT : Palette.line))}
				BackgroundTransparency={hold.charge.map((c) => (c * BEADS > i ? 0 : isLit ? 0.1 : 0.55))}
				BorderSizePixel={0}
				ZIndex={3}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}

	// orbit tracks
	const tracks: Record<string, React.Element> = {};
	[0.3, 0.405].forEach((radius, i) => {
		tracks["t" + i] = (
			<frame
				Size={hold.charge.map((c) => UDim2.fromScale(radius * 2 * (1 - c * 0.6), radius * 2 * (1 - c * 0.6)))}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				BackgroundTransparency={1}
				ZIndex={2}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={ACCENT} Thickness={1} Transparency={0.86} />
			</frame>
		);
	});

	// harmony: a thread between neighbouring planets, lit as the six rise together
	const threads: Record<string, React.Element> = {};
	for (let i = 0; i < 6; i++) {
		const j = (i + 1) % 6;
		threads["h" + i] = (
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={state.Harmony > 0 ? lighten(ACCENT, 0.2) : Palette.line}
				BackgroundTransparency={state.Harmony > 0 ? 0.45 : 0.88}
				BorderSizePixel={0}
				ZIndex={4}
				Position={React.joinBindings([clock, hold.charge]).map(([t, c]) => {
					const a = planetAt(i, t, c);
					const b = planetAt(j, t, c);
					return UDim2.fromScale((a.X + b.X) / 2, (a.Y + b.Y) / 2);
				})}
				Size={React.joinBindings([clock, hold.charge]).map(([t, c]) => {
					const a = planetAt(i, t, c);
					const b = planetAt(j, t, c);
					return UDim2.fromOffset(a.sub(b).Magnitude * size, 2);
				})}
				Rotation={React.joinBindings([clock, hold.charge]).map(([t, c]) => {
					const a = planetAt(i, t, c);
					const b = planetAt(j, t, c);
					return math.deg(math.atan2(b.Y - a.Y, b.X - a.X));
				})}
			/>
		);
	}

	const planets: Record<string, React.Element> = {};
	state.Sigils.forEach((sigil, index) => {
		planets[sigil.Id] = (
			<Planet
				sigil={sigil}
				index={index}
				size={planetSize}
				selected={props.selected === sigil.Id}
				clock={clock}
				charge={hold.charge}
				reduced={props.reduced}
				onPick={props.onPick}
			/>
		);
	});

	// the core: heats toward white while held, shakes a little, and is the hold target
	const heat = hold.charge.map((c) => ACCENT.Lerp(Palette.cream, c));
	return (
		<frame Size={UDim2.fromOffset(size, size)} BackgroundTransparency={1}>
			{tracks}
			{beads}
			{threads}
			<textbutton
				Size={hold.charge.map((c) => UDim2.fromOffset(coreSize * (1 + c * 0.12), coreSize * (1 + c * 0.12)))}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={React.joinBindings([clock, hold.charge]).map(([t, c]) =>
					new UDim2(0.5, math.sin(t * 61) * c * 2.4, 0.5, math.cos(t * 53) * c * 2.4),
				)}
				BackgroundColor3={heat.map((color) => darken(color, state.CanAscend ? 0.55 : 0.82))}
				AutoButtonColor={false}
				Text=""
				Active={state.CanAscend && !props.busy}
				Selectable={state.CanAscend && !props.busy}
				ZIndex={7}
				Event={hold.events}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={heat} Thickness={state.CanAscend ? 3 : 1.5} Transparency={state.CanAscend ? 0.05 : 0.5} />
				<Ui.Text
					value={tostring(state.Rank)}
					size={math.floor(coreSize * 0.36)}
					weight={Enum.FontWeight.Heavy}
					color={Palette.cream}
					align={Enum.TextXAlignment.Center}
					position={new UDim2(0, 0, 0.5, -math.floor(coreSize * 0.3))}
					sizeConstraint={new UDim2(1, 0, 0, math.floor(coreSize * 0.44))}
					zIndex={9}
				/>
				<Ui.Text
					value={state.CanAscend ? "HOLD" : `${state.DomainRank} / ${state.RequiredDomainRank}`}
					size={12}
					weight={Enum.FontWeight.Heavy}
					color={state.CanAscend ? ACCENT : Palette.muted}
					align={Enum.TextXAlignment.Center}
					position={new UDim2(0, 0, 0.5, math.floor(coreSize * 0.16))}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
					zIndex={9}
				/>
				<Ui.Text
					value={state.CanAscend ? "to ascend" : "Domain"}
					size={11}
					color={Palette.creamSoft}
					align={Enum.TextXAlignment.Center}
					position={new UDim2(0, 0, 0.5, math.floor(coreSize * 0.16) + 15)}
					sizeConstraint={new UDim2(1, 0, 0, 14)}
					zIndex={9}
				/>
			</textbutton>
			{planets}
		</frame>
	);
}

interface ConsoleProps {
	state: AscensionState;
	sigil: Sigil | undefined;
	busy: boolean;
	note: string;
	stack: boolean;
	reduced?: boolean;
	hold: ReturnType<typeof useHold>;
	onBuy: (id: string) => void;
}

function stat(label: string, value: string, color: Color3) {
	return (
		<frame key={label} BackgroundColor3={Palette.panelSoft} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<Ui.Text value={label} size={11} color={Palette.muted} position={UDim2.fromOffset(10, 5)} sizeConstraint={new UDim2(1, -20, 0, 14)} />
			<Ui.Text
				value={value}
				size={16}
				weight={Enum.FontWeight.Heavy}
				color={color}
				position={UDim2.fromOffset(10, 22)}
				sizeConstraint={new UDim2(1, -20, 0, 20)}
				fit={true}
				minSize={11}
			/>
		</frame>
	);
}

function Console(props: ConsoleProps) {
	const { state, sigil, hold } = props;
	const color = sigil !== undefined ? (SIGIL_COLORS[sigil.Id] ?? ACCENT) : ACCENT;
	const boosted = sigil !== undefined && sigil.EffectiveLevel > sigil.Level;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			{/* the numbers that matter */}
			<frame Size={new UDim2(1, 0, 0, 46)} BackgroundTransparency={1}>
				<uigridlayout CellSize={new UDim2(1 / 3, -8, 1, 0)} CellPadding={UDim2.fromOffset(8, 0)} SortOrder={Enum.SortOrder.LayoutOrder} />
				{stat("AETHER", compact(state.Aether), ACCENT)}
				{stat("PRODUCTION", `×${compact(state.Production)}`, Palette.cream)}
				{stat("NEXT RANK", `×${compact(state.NextRankProduction)}`, Palette.mint)}
			</frame>
			{/* the planet in focus */}
			<frame Position={UDim2.fromOffset(0, 62)} Size={new UDim2(1, 0, 1, -62 - (TapTarget + 12) - 6)} BackgroundColor3={Palette.panel} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={color} Transparency={0.55} Thickness={1} />
				{sigil === undefined ? (
					<Ui.Text value="Pick a planet" size={15} color={Palette.muted} align={Enum.TextXAlignment.Center} sizeConstraint={UDim2.fromScale(1, 1)} />
				) : (
					<>
						<Ui.Text
							value={`${sigil.Name}  ·  ${sigil.Level > 0 ? "Level " + compact(sigil.Level) : "not started"}`}
							size={18}
							weight={Enum.FontWeight.Heavy}
							color={lighten(color, 0.25)}
							position={UDim2.fromOffset(16, 12)}
							sizeConstraint={new UDim2(1, -32, 0, 24)}
						/>
						<Ui.Text
							value={sigil.Line}
							size={13}
							color={Palette.creamSoft}
							position={UDim2.fromOffset(16, 40)}
							sizeConstraint={new UDim2(1, -32, 0, 18)}
						/>
						<Ui.Text
							value={
								sigil.Level > 0
									? `×${compact(sigil.Multiplier)} ${sigil.Effect.lower()}` + (boosted ? `   ·   acts as Level ${compact(sigil.EffectiveLevel)}` : "")
									: "Level it once to start its effect"
							}
							size={14}
							weight={Enum.FontWeight.Bold}
							position={UDim2.fromOffset(16, 66)}
							sizeConstraint={new UDim2(1, -32, 0, 20)}
						/>
						<Ui.Button
							text={`Level up  ·  ${compact(sigil.Cost)} Aether`}
							color={sigil.Affordable ? color : Palette.panelSoft}
							textColor={sigil.Affordable ? Palette.ink : Palette.muted}
							disabled={!sigil.Affordable || props.busy}
							highlight={sigil.Affordable}
							size={new UDim2(1, -32, 0, TapTarget)}
							position={new UDim2(0, 16, 1, -TapTarget - 14)}
							reducedMotion={props.reduced}
							onClick={() => props.onBuy(sigil.Id)}
						/>
					</>
				)}
			</frame>
			{/* the ascent itself */}
			<textbutton
				Size={new UDim2(1, 0, 0, TapTarget + 12)}
				Position={new UDim2(0, 0, 1, -(TapTarget + 12))}
				BackgroundColor3={state.CanAscend ? darken(ACCENT, 0.55) : Palette.panelSoft}
				AutoButtonColor={false}
				Text=""
				ClipsDescendants={true}
				Active={state.CanAscend && !props.busy}
				Selectable={state.CanAscend && !props.busy}
				Event={hold.events}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke Color={state.CanAscend ? ACCENT : Palette.lineSoft} Transparency={0.25} Thickness={1.5} />
				<frame Size={hold.charge.map((c) => UDim2.fromScale(c, 1))} BackgroundColor3={ACCENT} BorderSizePixel={0} ZIndex={2} />
				<Ui.Text
					value={state.CanAscend ? `Hold to ascend   ·   +${compact(state.Gain)} Aether` : `Not ready yet   ·   Domain ${state.DomainRank} / ${state.RequiredDomainRank}`}
					size={15}
					weight={Enum.FontWeight.Heavy}
					color={state.CanAscend ? Palette.cream : Palette.muted}
					align={Enum.TextXAlignment.Center}
					sizeConstraint={UDim2.fromScale(1, 1)}
					zIndex={3}
				/>
			</textbutton>
			{props.note !== "" && (
				<Ui.Text value={props.note} size={12} color={Palette.creamSoft} position={new UDim2(0, 0, 1, 4)} sizeConstraint={new UDim2(1, 0, 0, 16)} />
			)}
		</frame>
	);
}

interface AscensionViewProps {
	state: { Ascension?: AscensionState; Constellations?: ConstellationState };
	reducedMotion?: boolean;
	dispatch: (action: string, payload: object, callback: (response: unknown) => void) => void;
}

function AscensionView(props: AscensionViewProps) {
	const state = props.state.Ascension;
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const [busy, setBusy] = React.useState(false);
	const [note, setNote] = React.useState("");
	const [picked, setPicked] = React.useState("");
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
	const hold = useHold(state !== undefined && state.CanAscend && !busy, () => request("Ascend"));
	const sections: Section[] = [];
	const add = (id: string, height: number, element: React.Element) => {
		sections.push({ id, height, element });
	};
	if (!typeIs(state, "table")) {
		add("loading", 80, <Ui.Text value="Loading Ascension…" size={16} color={Palette.muted} sizeConstraint={new UDim2(1, 0, 0, 24)} />);
		return <PageScaffold sections={sections} gap={GAP} tailPad={72} />;
	}

	// the planet in focus: the one you picked, else the first you can afford, else the first
	let focus: Sigil | undefined;
	for (const sigil of state.Sigils) {
		if (sigil.Id === picked) {
			focus = sigil;
		}
	}
	if (focus === undefined) {
		for (const sigil of state.Sigils) {
			if (focus === undefined && sigil.Affordable) {
				focus = sigil;
			}
		}
		focus = focus ?? state.Sigils[0];
	}

	const orrery = math.clamp(stack ? viewport.width - 72 : math.min(420, viewport.height - 330), 260, 440);
	// the console beside the orrery needs room for its stats, the planet in focus and the ascend bar
	const panelH = stack ? orrery + 28 : math.max(orrery + 40, 400);
	add(
		"orrery",
		panelH,
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={stack ? 14 : 20} accent={state.CanAscend ? ACCENT : Palette.lineSoft} background={darken(ACCENT, 0.92)} clips={false}>
			<frame Size={UDim2.fromOffset(orrery, orrery)} Position={new UDim2(0, 0, 0.5, 0)} AnchorPoint={new Vector2(0, 0.5)} BackgroundTransparency={1}>
				<Orrery
					state={state}
					size={orrery}
					selected={focus !== undefined ? focus.Id : ""}
					reduced={softMotion}
					busy={busy}
					onPick={setPicked}
					hold={hold}
				/>
			</frame>
			{!stack && (
				<frame Size={new UDim2(1, -(orrery + 28), 1, 0)} Position={UDim2.fromOffset(orrery + 28, 0)} BackgroundTransparency={1}>
					<Console state={state} sigil={focus} busy={busy} note={note} stack={false} reduced={softMotion} hold={hold} onBuy={(id) => request("UpgradeSigil", { Id: id })} />
				</frame>
			)}
		</Ui.Panel>,
	);
	if (stack) {
		add(
			"console",
			TapTarget + 12 + 62 + 168 + 22,
			<Ui.Panel size={UDim2.fromScale(1, 1)} padding={14} accent={Palette.lineSoft} background={Palette.panel} clips={false}>
				<Console state={state} sigil={focus} busy={busy} note={note} stack={true} reduced={softMotion} hold={hold} onBuy={(id) => request("UpgradeSigil", { Id: id })} />
			</Ui.Panel>,
		);
	}

	// v8 star charts: every rebirth is a Star Point
	const charts = props.state.Constellations;
	if (typeIs(charts, "table")) {
		add(
			"constellations",
			constellationsHeight(stack),
			<ConstellationsView
				state={charts}
				stack={stack}
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
	return <PageScaffold sections={sections} gap={GAP} tailPad={72} scrollBarColor={ACCENT} />;
}

export = () => ({ AscensionView });
