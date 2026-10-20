// Ascension: the final, endless reset. One hero (rank, Aether, production), the ascend panel with a
// hold-to-confirm button, a harmony strip, and the six sigils.
import React from "@rbxts/react";
import { compactNumber } from "../CoreKit/format";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { useClock, useFlipperSpring, useViewport } from "../MotionKit/motion";
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
const GAP = 14;
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

// A ring of dots slowly orbiting a centre: the Ascension mark.
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
	const stop = () => {
		if (holding.current) {
			holding.current.Disconnect();
			holding.current = undefined;
		}
		setFill(0);
	};
	React.useEffect(() => stop, []);
	const begin = () => {
		if (!enabled || holding.current) {
			return;
		}
		Audio.play("rebirthCharge");
		const started = os.clock();
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
						begin();
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
					return a > 0 ? "KEEP HOLDING…" : props.text;
				})}
				TextColor3={fill.map((a) => (a > 0.5 ? Palette.ink : Palette.cream))}
				TextSize={16}
				FontFace={new Font("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)}
				ZIndex={3}
			/>
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
	return (
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={16} accent={color} background={Palette.panelRaised} clips={false}>
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
				sizeConstraint={new UDim2(1, -150, 0, 24)}
			/>
			<Ui.Text
				value={sigil.Line}
				size={13}
				color={Palette.muted}
				position={UDim2.fromOffset(66, 28)}
				sizeConstraint={new UDim2(1, -66, 0, 18)}
			/>
			<Ui.Text
				value={sigil.Level > 0 ? `Lv ${compact(sigil.Level)}` : "Not started"}
				size={13}
				color={color}
				weight={Enum.FontWeight.Heavy}
				align={Enum.TextXAlignment.Right}
				position={new UDim2(1, -84, 0, 4)}
				sizeConstraint={UDim2.fromOffset(84, 18)}
			/>
			<Ui.Text
				value={
					sigil.Level > 0
						? `×${compact(sigil.Multiplier)} ${sigil.Effect.lower()}` +
							(boosted ? `  ·  acts as Lv ${compact(sigil.EffectiveLevel)}` : "")
						: "Buy a level to start it"
				}
				size={15}
				weight={Enum.FontWeight.Bold}
				color={Palette.cream}
				position={UDim2.fromOffset(0, 66)}
				sizeConstraint={new UDim2(1, 0, 0, 20)}
			/>
			<Ui.Button
				text={`Upgrade · ${compact(sigil.Cost)} Aether`}
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
	state: { Ascension?: AscensionState };
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
	const heroH = stack ? 216 : 168;
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
				value="ASCENSION"
				size={12}
				weight={Enum.FontWeight.Heavy}
				color={ACCENT}
				position={UDim2.fromOffset(col, 0)}
				sizeConstraint={new UDim2(1, -col, 0, 16)}
			/>
			<Ui.Text
				value={state.Rank > 0 ? `Ascended ${state.Rank} time${state.Rank === 1 ? "" : "s"}` : "The final reset"}
				size={stack ? 22 : 26}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={16}
				position={UDim2.fromOffset(col, 18)}
				sizeConstraint={new UDim2(1, -col, 0, 32)}
			/>
			<Ui.Text
				value={`${compact(state.Aether)} Aether to spend  ·  ×${compact(state.Production)} production from Ascension`}
				size={14}
				color={Palette.creamSoft}
				wrap={true}
				position={UDim2.fromOffset(col, 56)}
				sizeConstraint={new UDim2(1, -col, 0, stack ? 58 : 40)}
			/>
			<Ui.Text
				value="Ascension resets your Domain, rebirths, cores and current run. Research, relics, artifacts, the Star Foundry and sigils stay. You can ascend again."
				size={12}
				color={Palette.muted}
				wrap={true}
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
						? `Ascension ${state.Rank + 1} is ready: +${compact(state.Gain)} Aether`
						: `Reach Domain rank ${state.RequiredDomainRank} to ascend`
				}
				size={19}
				weight={Enum.FontWeight.Heavy}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, 26)}
			/>
			<Ui.Text
				value={
					`Domain rank ${state.DomainRank} of ${state.RequiredDomainRank}` +
					(state.CanAscend ? "  ·  going further past it pays more Aether" : "")
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
				size={new UDim2(1, stack ? 0 : -300, 0, 8)}
			/>
			<Ui.Text
				value={`Next rank: ×${compact(state.NextRankProduction)} production`}
				size={12}
				color={Palette.creamSoft}
				position={UDim2.fromOffset(0, 76)}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, 16)}
			/>
			<HoldButton
				enabled={state.CanAscend && !busy}
				text="HOLD TO ASCEND"
				disabledText="NOT READY"
				size={stack ? new UDim2(1, 0, 0, TapTarget + 8) : UDim2.fromOffset(280, 64)}
				position={stack ? new UDim2(0, 0, 1, -(TapTarget + 8)) : new UDim2(1, -280, 0.5, -32)}
				onConfirm={() => request("Ascend")}
			/>
		</Ui.Panel>,
	);
	if (note !== "") {
		add("note", 28, <Ui.Text value={note} size={14} color={Palette.creamSoft} sizeConstraint={new UDim2(1, 0, 0, 24)} />);
	}

	// harmony
	const pips: Record<string, React.Element> = {};
	state.Sigils.forEach((sigil, index) => {
		const color = SIGIL_COLORS[sigil.Id] ?? ACCENT;
		pips[sigil.Id] = (
			<frame
				Size={new UDim2(1 / 6, -8, 0, 26)}
				Position={new UDim2(index / 6, 4, 0, 40)}
				BackgroundColor3={darken(color, sigil.Level > state.Harmony ? 0.4 : 0.75)}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<Ui.Text
					value={`${sigil.Name} ${compact(sigil.Level)}`}
					size={11}
					weight={Enum.FontWeight.Bold}
					align={Enum.TextXAlignment.Center}
					fit={true}
					minSize={8}
					sizeConstraint={UDim2.fromScale(1, 1)}
				/>
			</frame>
		);
	});
	add(
		"harmony",
		82,
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={14} accent={Palette.mint} background={Palette.panel}>
			<Ui.Text
				value={
					state.Harmony > 0
						? `Harmony ${state.Harmony}: every started sigil acts ${state.Harmony} level${state.Harmony === 1 ? "" : "s"} higher`
						: "Harmony 0: raise all six sigils together and each one acts higher"
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
	const columns = stack ? 1 : viewport.width >= 1300 ? 3 : 2;
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
	return <PageScaffold sections={sections} gap={GAP} tailPad={72} scrollBarColor={ACCENT} />;
}

export = () => ({ AscensionView });
