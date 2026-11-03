// Star Foundry: a hex board of star pieces. Embers send energy along the way they face, Conduits and
// Lenses carry it, Prisms split it, Anvils turn it into production, tap, capacity and offline bonuses.
// Tap a piece (board or bench), then a cell, to place, move or fuse it. Ignite when the sweeping wave
// crosses your brightest Anvil for Shards; ten on the beat in a row light a surge.
// The board you see runs the same FoundryMath the server does, so the flow drawn is the flow you get.
import React from "@rbxts/react";
import { ART } from "../ArtKit/ArtAssets";
import * as Format from "../CoreKit/format";
import { chromeFor, darken, lighten, Palette, TapTarget } from "../CoreKit/theme";
import { useClock, useViewport } from "../MotionKit/motion";
import FoundryMath = require("../../../Shared/AstralForge/Shared/FoundryMath");
import { Component, loadAudio, loadPageScaffold, loadUi, luauKit, luauModule } from "./luauDeps";

const Ui = loadUi();
const PageScaffold = loadPageScaffold();
const Audio = loadAudio();
const Icon = luauKit<{ Icon: Component }>("ArtKit", "Icon").Icon;
const Workspace = game.GetService("Workspace");

interface JuiceApi {
	live(this: void, id: string, entry: Record<string, unknown> | undefined): void;
}

type Flow = ReturnType<typeof FoundryMath.flow>;
interface Piece {
	Kind: string;
	Tier: number;
	Facing: number;
}
interface Foundry {
	Radius: number;
	Pieces: Record<string, Piece>;
	Bench: Piece[];
	Shards: number;
	ShardRate?: number;
	DrawCost?: number;
	ExpandCost?: number;
	Effects?: { Production?: number; Tap?: number; Capacity?: number; Offline?: number };
	SurgeEndsAt?: number;
	IgniteAt?: number;
}
interface Look {
	name: string;
	color: Color3;
	icon: string;
	line: string;
}

const ACCENT = Color3.fromRGB(255, 176, 92);
const GAP = 14;
const KIND_LOOK: Record<string, Look | undefined> = {
	Ember: { name: "Ember", color: Color3.fromRGB(255, 132, 64), icon: "Flux.5", line: "Sends energy the way it faces" },
	Conduit: { name: "Conduit", color: Color3.fromRGB(120, 196, 255), icon: "Travel.1", line: "Carries energy onward" },
	Lens: { name: "Lens", color: Color3.fromRGB(150, 236, 255), icon: "Boost.10", line: "Focuses energy, stronger" },
	Prism: { name: "Prism", color: Color3.fromRGB(200, 150, 255), icon: "StarGrid.3", line: "Splits energy three ways" },
	ForgeAnvil: { name: "Forge Anvil", color: Color3.fromRGB(255, 196, 84), icon: "Forge.8", line: "Energy becomes production" },
	StrikeAnvil: { name: "Strike Anvil", color: Color3.fromRGB(255, 104, 112), icon: "Overcharge.5", line: "Energy becomes tap power" },
	VaultAnvil: { name: "Vault Anvil", color: Color3.fromRGB(96, 220, 168), icon: "Vault.4", line: "Energy becomes vault capacity" },
	EchoAnvil: { name: "Echo Anvil", color: Color3.fromRGB(176, 140, 255), icon: "Continuum.3", line: "Energy becomes offline income" },
};
const CONDUIT = KIND_LOOK.Conduit!;
const EMBER = KIND_LOOK.Ember!;

function compact(value: unknown) {
	return Format.compactNumber(value);
}

// flat-top hex layout: axial (q, r) -> pixel centre
function hexPixel(q: number, r: number, size: number) {
	return new Vector2(size * 1.5 * q, size * math.sqrt(3) * (r + q / 2));
}

function directionAngle(direction: number) {
	const d = FoundryMath.DIRECTIONS[direction];
	const p = hexPixel(d[0], d[1], 1);
	return math.deg(math.atan2(p.Y, p.X));
}

// ---- the optimizer: what is the single best rotation on this board, and how much does the board waste?
//
// FoundryMath.flow runs here the same way it runs on the server, so every rotation can be tried against it
// before you spend a tap. A suggestion is the one rotation that sends the most extra energy into Anvils.
interface Suggestion {
	key: string;
	facing: number;
	/** taps needed, and which way (the shortest way round) */
	taps: number;
	left: boolean;
	/** extra energy delivered to Anvils, as a share of what is delivered now */
	gain: number;
	kind: string;
}

const FACED_KINDS: Record<string, true | undefined> = { Ember: true, Conduit: true, Lens: true, Prism: true };
const SEARCH_BUDGET_SECONDS = 0.045;
let lastSignature = "";
let lastSuggestion: Suggestion | undefined;

function boardSignature(foundry: Foundry): string {
	const parts: string[] = [tostring(foundry.Radius)];
	for (const key of FoundryMath.cells(foundry.Radius)) {
		const piece = foundry.Pieces[key] as Piece | undefined;
		if (piece !== undefined) {
			parts.push(`${key}:${piece.Kind}:${piece.Tier}:${piece.Facing}`);
		}
	}
	return parts.join("|");
}

function bestRotation(foundry: Foundry): Suggestion | undefined {
	const signature = boardSignature(foundry);
	if (signature === lastSignature) {
		return lastSuggestion;
	}
	const started = os.clock();
	const base = FoundryMath.flow({ Radius: foundry.Radius, Pieces: foundry.Pieces }).Delivered;
	let best: Suggestion | undefined;
	let bestGain = math.max(base * 0.004, 0.0001);
	for (const key of FoundryMath.cells(foundry.Radius)) {
		const piece = foundry.Pieces[key] as Piece | undefined;
		if (piece === undefined || FACED_KINDS[piece.Kind] !== true) {
			continue;
		}
		for (let facing = 0; facing < 6; facing++) {
			if (facing === piece.Facing) {
				continue;
			}
			const trial: Record<string, Piece> = {};
			for (const [other, value] of pairs(foundry.Pieces)) {
				trial[other as string] = value as Piece;
			}
			trial[key] = { Kind: piece.Kind, Tier: piece.Tier, Facing: facing };
			const delivered = FoundryMath.flow({ Radius: foundry.Radius, Pieces: trial }).Delivered;
			if (delivered - base > bestGain) {
				bestGain = delivered - base;
				const right = (facing - piece.Facing + 6) % 6;
				best = {
					key,
					facing,
					taps: right <= 3 ? right : 6 - right,
					left: right > 3,
					gain: base > 0 ? (delivered - base) / base : 1,
					kind: piece.Kind,
				};
			}
		}
		if (os.clock() - started > SEARCH_BUDGET_SECONDS) {
			break;
		}
	}
	lastSignature = signature;
	lastSuggestion = best;
	return best;
}

const ROUND = <uicorner CornerRadius={new UDim(1, 0)} />;

// tier shown as pips under the piece (a compact corner badge when cells are small or tier > 5)
function TierMark(props: { tier: number; color: Color3; cellSize?: number; zIndex?: number }) {
	const tier = props.tier;
	const color = props.color;
	const d = props.cellSize ?? 40;
	if (d < 32 || tier > 5) {
		return (
			<textlabel
				Size={UDim2.fromOffset(d < 32 ? 18 : 22, d < 32 ? 10 : 12)}
				Position={d < 32 ? new UDim2(1, -1, 0, 1) : new UDim2(0.5, 0, 1, 2)}
				AnchorPoint={d < 32 ? new Vector2(1, 0) : new Vector2(0.5, 0)}
				BackgroundColor3={darken(color, 0.7)}
				Text={tostring(tier)}
				TextColor3={lighten(color, 0.5)}
				TextScaled={true}
				FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
				ZIndex={props.zIndex}
			>
				{ROUND}
			</textlabel>
		);
	}
	const pips: Record<string, React.Element> = {};
	for (let index = 1; index <= tier; index++) {
		pips["p" + index] = (
			<frame
				Size={UDim2.fromOffset(4, 4)}
				Position={new UDim2(0.5, (index - (tier + 1) / 2) * 7, 1, 4)}
				AnchorPoint={new Vector2(0.5, 0)}
				BackgroundColor3={lighten(color, 0.4)}
				BorderSizePixel={0}
				ZIndex={props.zIndex}
			>
				{ROUND}
			</frame>
		);
	}
	return <>{pips}</>;
}

// The pieces are engraved plates (tools/assetgen/art/foundry.html): directional ones are drawn facing east and
// turned to their facing here, so the art itself shows where energy goes.
const KIND_ART: Record<string, string | undefined> = {
	Ember: ART.FoundryEmber,
	Conduit: ART.FoundryConduit,
	Lens: ART.FoundryLens,
	Prism: ART.FoundryPrism,
	ForgeAnvil: ART.FoundryForgeAnvil,
	StrikeAnvil: ART.FoundryStrikeAnvil,
	VaultAnvil: ART.FoundryVaultAnvil,
	EchoAnvil: ART.FoundryEchoAnvil,
};

function PieceFace(props: {
	piece: Piece;
	size: number;
	zIndex?: number;
	lit?: number;
	clock?: React.Binding<number>;
	position?: UDim2;
	selected?: boolean;
	showFacing?: boolean;
}) {
	const piece = props.piece;
	const look = KIND_LOOK[piece.Kind] ?? CONDUIT;
	const d = props.size;
	const z = props.zIndex ?? 4;
	const lit = props.lit ?? 0;
	const clock = props.clock;
	const source = FoundryMath.KINDS[piece.Kind].role === "source";
	const turned = FACED_KINDS[piece.Kind] === true ? directionAngle(piece.Facing) : 0;
	// a source always burns; anything else carries a halo while energy runs through it
	const halo = source ? 0.7 : lit;
	return (
		<frame
			Size={UDim2.fromOffset(d, d)}
			Position={props.position ?? UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			ZIndex={z}
		>
			{halo > 0.05 && (
				<imagelabel
					Size={UDim2.fromScale(1.2 + halo * 0.25, 1.2 + halo * 0.25)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					Image={ART.FoundryLit}
					ImageColor3={look.color}
					ImageTransparency={math.clamp(0.7 - halo * 0.5, 0.1, 0.9)}
					Rotation={clock ? clock.map((t) => t * (source ? -10 : 14)) : 0}
					ZIndex={z}
				/>
			)}
			{props.selected && (
				<imagelabel
					Size={UDim2.fromScale(1.45, 1.45)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					Image={ART.BootShockwave}
					ImageTransparency={0.05}
					ZIndex={z + 3}
				/>
			)}
			<imagelabel
				Size={UDim2.fromScale(1.3, 1.3)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				Image={KIND_ART[piece.Kind] ?? ""}
				ScaleType={Enum.ScaleType.Fit}
				Rotation={turned}
				ZIndex={z + 1}
			/>
			<TierMark tier={piece.Tier} color={look.color} cellSize={d} zIndex={z + 3} />
		</frame>
	);
}

function Board(props: {
	foundry: Foundry;
	flow: Flow;
	cellSize: number;
	width: number;
	height: number;
	selected?: string;
	onCell: (key: string) => void;
	softMotion?: boolean;
	hint?: Suggestion;
}) {
	const foundry = props.foundry;
	const flow = props.flow;
	const size = props.cellSize;
	const clock = useClock(!props.softMotion, 1, 3600, true);
	const centre = new Vector2(props.width / 2, props.height / 2);
	const span = math.min(props.width, props.height);
	const children: Record<string, React.Element> = {};
	// the plate: an atlas margin of faint stars and the engraved orbit ring (radius 0.47 of the plate) the comet rides
	children.plate = (
		<imagelabel
			Size={UDim2.fromOffset(span, span)}
			Position={UDim2.fromOffset(centre.X, centre.Y)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			Image={ART.FoundryBoard}
			ZIndex={0}
		/>
	);
	const orbit = span * 0.47;
	const target = FoundryMath.targetPhase({ Radius: foundry.Radius, Pieces: foundry.Pieces });
	const tx = math.cos(target * 2 * math.pi);
	const ty = math.sin(target * 2 * math.pi);
	children.notch = (
		<imagelabel
			Size={UDim2.fromOffset(26, 26)}
			Position={UDim2.fromOffset(centre.X + tx * orbit, centre.Y + ty * orbit)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			Image={ART.FoundrySpark}
			ImageColor3={ACCENT}
			ZIndex={7}
		/>
	);
	const cometPoint = (lag: number) => () => {
		const phase = FoundryMath.wavePhase(foundry.IgniteAt ?? 0, Workspace.GetServerTimeNow()) - lag;
		const angle = phase * 2 * math.pi;
		return UDim2.fromOffset(centre.X + math.cos(angle) * orbit, centre.Y + math.sin(angle) * orbit);
	};
	for (let index = 0; index <= 5; index++) {
		const lag = index * 0.012;
		children["comet" + index] = (
			<imagelabel
				Size={UDim2.fromOffset(20 - index * 2.6, 20 - index * 2.6)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={clock.map(cometPoint(lag))}
				BackgroundTransparency={1}
				Image={ART.FoundrySpark}
				ImageColor3={index === 0 ? Palette.white : ACCENT}
				ImageTransparency={clock.map(() => {
					const phase = FoundryMath.wavePhase(foundry.IgniteAt ?? 0, Workspace.GetServerTimeNow());
					const hot = FoundryMath.onBeat(phase, target);
					return math.clamp((hot ? 0 : 0.15) + index * 0.15, 0, 1);
				})}
				ZIndex={8}
			/>
		);
	}
	// energy beams: the etched channel stretched along each link, shading from source to target colour
	let drawn = 0;
	for (let i = 0; i < flow.Links.size(); i++) {
		const index = i + 1;
		const link = flow.Links[i];
		if (drawn >= 80) {
			break;
		}
		const [q1, r1] = FoundryMath.parse(link.from);
		const [q2, r2] = FoundryMath.parse(link.to);
		if (q1 !== undefined && q2 !== undefined) {
			drawn += 1;
			const a = centre.add(hexPixel(q1, r1!, size));
			const b = centre.add(hexPixel(q2, r2!, size));
			const delta = b.sub(a);
			const strength = math.clamp(math.log10(1 + link.amount) / 4, 0.15, 1);
			const fromPiece = foundry.Pieces[link.from] as Piece | undefined;
			const toPiece = foundry.Pieces[link.to] as Piece | undefined;
			const c1 = ((fromPiece && KIND_LOOK[fromPiece.Kind]) || EMBER).color;
			const c2 = ((toPiece && KIND_LOOK[toPiece.Kind]) || EMBER).color;
			children["beam" + index] = (
				<imagelabel
					Size={UDim2.fromOffset(delta.Magnitude, 8 + strength * 10)}
					Position={UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={math.deg(math.atan2(delta.Y, delta.X))}
					BackgroundTransparency={1}
					Image={ART.FoundryBeam}
					ScaleType={Enum.ScaleType.Stretch}
					ImageTransparency={0.4 - strength * 0.3}
					ZIndex={2}
				>
					<uigradient Color={new ColorSequence(c1, c2)} />
				</imagelabel>
			);
			if (!props.softMotion) {
				const speed = 0.7 + strength * 1.4;
				const offset = (index * 0.37) % 1;
				for (let tail = 0; tail <= 2; tail++) {
					children["pulse" + index + "_" + tail] = (
						<imagelabel
							Size={UDim2.fromOffset(14 - tail * 3, 14 - tail * 3)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							Position={clock.map((t) => {
								const u = (t * speed + offset - tail * 0.04) % 1;
								const p = a.add(delta.mul(u));
								return UDim2.fromOffset(p.X, p.Y);
							})}
							BackgroundTransparency={1}
							Image={ART.FoundrySpark}
							ImageColor3={tail === 0 ? Palette.white : c2}
							ImageTransparency={tail * 0.3}
							ZIndex={4}
						/>
					);
				}
			}
		}
	}
	// the lattice: an engraved hex socket for every cell (brass-rimmed where a moved piece could go), pieces in them
	const socket = size * 0.94 * 2 * (128 / 118);
	for (const key of FoundryMath.cells(foundry.Radius)) {
		const [q, r] = FoundryMath.parse(key);
		const p = centre.add(hexPixel(q!, r!, size));
		const piece = foundry.Pieces[key] as Piece | undefined;
		const targeted = props.selected !== undefined && props.selected !== key;
		children["socket" + key] = (
			<imagelabel
				Size={UDim2.fromOffset(socket, socket)}
				Position={UDim2.fromOffset(p.X, p.Y)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				Image={targeted && piece === undefined ? ART.FoundrySocketTarget : ART.FoundrySocket}
				ImageTransparency={piece ? 0.35 : 0}
				ZIndex={1}
			/>
		);
		children["cell" + key] = (
			<textbutton
				Size={UDim2.fromOffset(size * 1.6, size * 1.6)}
				Position={UDim2.fromOffset(p.X, p.Y)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				Text=""
				ZIndex={5}
				Event={{ Activated: () => props.onCell(key) }}
			>
				{piece && (
					<PieceFace
						piece={piece}
						size={math.floor(size * 1.25)}
						selected={props.selected === key}
						lit={math.clamp(math.log10(1 + (flow.Lit[key] ?? 0)) / 3, 0, 1)}
						clock={props.softMotion ? undefined : clock}
						zIndex={5}
					/>
				)}
			</textbutton>
		);
	}
	// the hint: an engraved ring pulsing on the piece worth turning, and a drawn arrow toward the way to face
	if (props.hint !== undefined) {
		const [hq, hr] = FoundryMath.parse(props.hint.key);
		if (hq !== undefined && hr !== undefined) {
			const p = centre.add(hexPixel(hq, hr, size));
			const reach = size * 1.45;
			children.hintRing = (
				<imagelabel
					Size={clock.map((t) => {
						const d = size * (2 + 0.25 * math.sin(t * 4));
						return UDim2.fromOffset(d, d);
					})}
					Position={UDim2.fromOffset(p.X, p.Y)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					Image={ART.BootShockwave}
					ImageTransparency={clock.map((t) => 0.1 + 0.3 * (0.5 + 0.5 * math.sin(t * 4)))}
					ZIndex={9}
				/>
			);
			const angle = directionAngle(props.hint.facing);
			children.hintArrow = (
				<imagelabel
					Size={UDim2.fromOffset(reach, reach * 0.25)}
					Position={UDim2.fromOffset(p.X + math.cos(math.rad(angle)) * reach * 0.62, p.Y + math.sin(math.rad(angle)) * reach * 0.62)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={angle}
					BackgroundTransparency={1}
					Image={ART.FoundryArrow}
					ImageColor3={ACCENT}
					ZIndex={10}
				/>
			);
		}
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Color3.fromRGB(15, 16, 22)} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 14)} />
			{children}
		</frame>
	);
}

function Chip(props: { size: UDim2; position: UDim2; color: Color3; label: string; value: string }) {
	return (
		<frame Size={props.size} Position={props.position} BackgroundColor3={darken(props.color, 0.78)} BorderSizePixel={0}>
			<uicorner CornerRadius={new UDim(0, 10)} />
			<uistroke Color={props.color} Thickness={1} Transparency={0.55} />
			<Ui.Text
				value={props.label}
				size={11}
				weight={Enum.FontWeight.Bold}
				color={props.color}
				position={UDim2.fromOffset(10, 6)}
				sizeConstraint={new UDim2(1, -20, 0, 14)}
			/>
			<Ui.Text
				value={props.value}
				size={17}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={11}
				position={UDim2.fromOffset(10, 22)}
				sizeConstraint={new UDim2(1, -20, 0, 22)}
			/>
		</frame>
	);
}

interface FoundryResponse {
	ok?: boolean;
	Sound?: string;
	Combo?: number;
	message?: string;
	error?: string;
}

interface Payload {
	Op: string;
	At?: string;
	From?: string;
	To?: string;
	Back?: boolean;
}

function FoundryView(props: {
	state: { Foundry?: unknown };
	reducedMotion?: boolean;
	dispatch: (action: string, payload: Payload, callback: (response: unknown) => void) => void;
}) {
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const stack = chrome.contentStack;
	const [selected, setSelected] = React.useState<string | undefined>(undefined);
	const [busy, setBusy] = React.useState(false);
	const [note, setNote] = React.useState("");
	const [combo, setCombo] = React.useState(0);
	const [hintOn, setHintOn] = React.useState(false);
	const busyRef = React.useRef(false);
	const [boardWidth, setBoardWidth] = React.useState(stack ? viewport.width - 24 : math.max(320, viewport.width - 440));
	const sections: Array<{ id: string; height: number; element: React.Element }> = [];
	const add = (id: string, height: number, element: React.Element) => {
		sections.push({ id, height, element });
	};
	if (!typeIs(props.state.Foundry, "table")) {
		add(
			"loading",
			80,
			<Ui.Text value="Loading the Star Foundry…" size={16} color={Palette.muted} sizeConstraint={new UDim2(1, 0, 0, 24)} />,
		);
		return <PageScaffold sections={sections} gap={GAP} tailPad={72} />;
	}
	const foundry = props.state.Foundry as Foundry;
	const act = (payload: Payload, quiet?: boolean) => {
		if (busy && payload.Op !== "ignite") {
			return;
		}
		if (payload.Op !== "ignite") {
			setBusy(true);
		}
		props.dispatch("FoundryAct", payload, (raw) => {
			setBusy(false);
			if (!typeIs(raw, "table")) {
				return;
			}
			const response = raw as FoundryResponse;
			if (response.ok) {
				Audio.play(response.Sound ?? "foundryPlace");
				if (response.Combo !== undefined || payload.Op === "ignite") {
					setCombo(response.Combo ?? 0);
					// a running Ignite combo is pinned to the island; a miss clears it
					const Juice = luauModule<JuiceApi>("JuiceFx");
					if ((response.Combo ?? 0) > 0) {
						Juice.live("foundryIgnite", {
							title: `IGNITE ×${response.Combo}`,
							icon: "Boost.11",
							color: ACCENT,
							endsAt: os.clock() + FoundryMath.IGNITE_PERIOD + 0.4,
							span: FoundryMath.IGNITE_PERIOD + 0.4,
							priority: 2,
						});
					} else {
						Juice.live("foundryIgnite", undefined);
					}
				}
				if (response.message !== undefined && !quiet) {
					setNote(response.message);
				}
			} else {
				Audio.play("error");
				setNote(response.error ?? "That move didn't work.");
			}
		});
	};
	const onCell = (key: string) => {
		if (selected === undefined) {
			if (foundry.Pieces[key] !== undefined) {
				Audio.play("foundryPickUp");
				setSelected(key);
			}
			return;
		}
		if (selected === key) {
			// double-tap a selected board piece to rotate it directly
			if (key.sub(1, 6) !== "bench:") {
				act({ Op: "rotate", At: key }, true);
			} else {
				setSelected(undefined);
			}
			return;
		}
		const fromBench = selected.sub(1, 6) === "bench:";
		act({ Op: fromBench ? "place" : "move", From: selected, To: key });
		setSelected(undefined);
	};

	const flow = FoundryMath.flow({ Radius: foundry.Radius, Pieces: foundry.Pieces });
	const effects = foundry.Effects ?? {};
	const surgeLeft = math.max(0, (foundry.SurgeEndsAt ?? 0) - Workspace.GetServerTimeNow());
	const dormant = (flow.Delivered ?? 0) <= 0;

	// hero: what the board is worth right now
	const chipW = stack ? new UDim2(0.5, -6, 0, 50) : new UDim2(0.25, -9, 0, 50);
	const chips: Array<[string, string, Color3]> = [
		["PRODUCTION", `×${compact(effects.Production ?? 1)}`, Color3.fromRGB(255, 196, 84)],
		["TAP", `×${compact(effects.Tap ?? 1)}`, Color3.fromRGB(255, 104, 112)],
		["CAPACITY", `×${compact(effects.Capacity ?? 1)}`, Color3.fromRGB(96, 220, 168)],
		["OFFLINE", `+${math.floor((effects.Offline ?? 0) * 100 + 0.5)}%`, Color3.fromRGB(176, 140, 255)],
	];
	const chipEls: Record<string, React.Element> = {};
	chips.forEach((chip, i) => {
		const col = stack ? i % 2 : i;
		const row = stack ? math.floor(i / 2) : 0;
		chipEls["chip" + (i + 1)] = (
			<Chip
				label={chip[0]}
				value={chip[1]}
				color={chip[2]}
				size={chipW}
				position={stack ? new UDim2(col * 0.5, col * 6, 0, 64 + row * 58) : new UDim2(i * 0.25, i * 3, 0, 64)}
			/>
		);
	});
	add(
		"hero",
		stack ? 214 : 150,
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={16} accent={ACCENT} background={darken(ACCENT, 0.9)}>
			<Ui.Text
				value={
					`${compact(foundry.Shards)} Shards  ·  ` +
					(dormant ? "Dormant (rotate Ember to an Anvil)" : `+${"%.1f".format((foundry.ShardRate ?? 0) * 60)}/min`)
				}
				size={stack ? 17 : 22}
				weight={Enum.FontWeight.Heavy}
				fit={true}
				minSize={13}
				position={UDim2.fromOffset(0, 4)}
				sizeConstraint={new UDim2(1, 0, 0, 30)}
			/>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				{chipEls}
			</frame>
		</Ui.Panel>,
	);

	// insight: how much of the energy your Embers make actually reaches an Anvil, and the one rotation that
	// would improve it most. Hint draws it on the board; Apply taps it for you.
	busyRef.current = busy;
	const suggestion = bestRotation(foundry);
	const emitted = flow.Delivered + flow.Wasted;
	const efficiency = emitted > 0 ? flow.Delivered / emitted : 0;
	const applySuggestion = () => {
		if (suggestion === undefined) {
			return;
		}
		const move = suggestion;
		task.spawn(() => {
			for (let tap = 0; tap < move.taps; tap++) {
				let waited = 0;
				while (busyRef.current && waited < 2) {
					task.wait(0.05);
					waited += 0.05;
				}
				act({ Op: "rotate", At: move.key, Back: move.left }, true);
				task.wait(0.45);
			}
		});
	};
	const gainText =
		suggestion === undefined
			? flow.Delivered <= 0
				? "Nothing reaches an Anvil yet. Aim an Ember at an Anvil, or chain Conduits between them."
				: "Every rotation is already at its best."
			: `Turn the ${(KIND_LOOK[suggestion.kind] ?? CONDUIT).name} ${suggestion.taps === 1 ? "once" : suggestion.taps + " taps"} ${suggestion.left ? "left" : "right"}: +${math.floor(suggestion.gain * 100 + 0.5)}% energy to Anvils`;
	add(
		"insight",
		stack ? 138 : 92,
		<Ui.Panel size={UDim2.fromScale(1, 1)} padding={14} accent={Palette.lineSoft} background={Palette.panel}>
			<Ui.Text
				value={`ENERGY REACHING ANVILS   ${math.floor(efficiency * 100 + 0.5)}%`}
				size={12}
				weight={Enum.FontWeight.Heavy}
				color={efficiency >= 0.85 ? Palette.mint : efficiency >= 0.5 ? ACCENT : Palette.coral}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, 16)}
			/>
			<Ui.Meter
				value={efficiency}
				color={efficiency >= 0.85 ? Palette.mint : efficiency >= 0.5 ? ACCENT : Palette.coral}
				reducedMotion={softMotion}
				position={UDim2.fromOffset(0, 22)}
				size={new UDim2(1, stack ? 0 : -300, 0, 6)}
			/>
			<Ui.Text
				value={gainText}
				size={13}
				color={suggestion !== undefined ? Palette.cream : Palette.muted}
				wrap={true}
				fit={true}
				minSize={10}
				position={UDim2.fromOffset(0, 36)}
				sizeConstraint={new UDim2(1, stack ? 0 : -300, 0, stack ? 34 : 38)}
			/>
			<Ui.Button
				text={hintOn ? "HINT ON" : "SHOW HINT"}
				onClick={() => setHintOn(!hintOn)}
				color={hintOn ? ACCENT : Palette.panelSoft}
				textColor={hintOn ? Palette.ink : Palette.cream}
				size={stack ? new UDim2(0.5, -4, 0, 36) : UDim2.fromOffset(140, TapTarget)}
				position={stack ? new UDim2(0, 0, 1, -36) : new UDim2(1, -290, 0.5, -TapTarget / 2)}
				reducedMotion={softMotion}
			/>
			<Ui.Button
				text="APPLY"
				onClick={applySuggestion}
				color={suggestion !== undefined ? Palette.mint : Palette.panelSoft}
				textColor={suggestion !== undefined ? Palette.ink : Palette.muted}
				disabled={suggestion === undefined || busy}
				size={stack ? new UDim2(0.5, -4, 0, 36) : UDim2.fromOffset(140, TapTarget)}
				position={stack ? new UDim2(0.5, 4, 1, -36) : new UDim2(1, -140, 0.5, -TapTarget / 2)}
				reducedMotion={softMotion}
			/>
		</Ui.Panel>,
	);

	// the board
	const boardH = stack ? math.min(viewport.width - 24, 420) : 480;
	const boardW = math.max(200, boardWidth);
	const cells = foundry.Radius * 2 + 1;
	// the lattice (and the orbit ring round it) fits the shorter side with a margin
	const cellSize = math.floor(math.min(boardW / (1.5 * cells + 0.6), (boardH * 0.86) / (math.sqrt(3) * cells + 0.2)));
	add(
		"board",
		boardH,
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			Change={{
				AbsoluteSize: (frame) => {
					const measured = math.floor(frame.AbsoluteSize.X);
					if (measured > 0 && math.abs(measured - boardWidth) > 2) {
						setBoardWidth(measured);
					}
				},
			}}
		>
			<Board
				foundry={foundry}
				flow={flow}
				cellSize={cellSize}
				width={boardW}
				height={boardH}
				selected={selected}
				onCell={onCell}
				hint={hintOn ? suggestion : undefined}
				softMotion={softMotion}
			/>
		</frame>,
	);

	const benchFull = foundry.Bench.size() >= FoundryMath.BENCH_CAP;
	// controls for a selected board piece
	if (selected !== undefined && selected.sub(1, 6) !== "bench:" && foundry.Pieces[selected] !== undefined) {
		const piece = foundry.Pieces[selected];
		const look = KIND_LOOK[piece.Kind] ?? CONDUIT;
		const panelH = stack ? 96 : 64;
		add(
			"selected",
			panelH,
			<Ui.Panel size={UDim2.fromScale(1, 1)} padding={12} accent={look.color} background={Palette.panel}>
				{stack ? (
					<>
						<Ui.Text
							value={`${look.name} · Tier ${piece.Tier}`}
							size={15}
							weight={Enum.FontWeight.Heavy}
							sizeConstraint={new UDim2(1, -44, 0, 18)}
						/>
						<Ui.Button
							text=""
							icon="Close"
							tooltip="Deselect"
							onClick={() => setSelected(undefined)}
							size={UDim2.fromOffset(36, 26)}
							position={new UDim2(1, -36, 0, -2)}
							color={Palette.panelSoft}
							reducedMotion={softMotion}
						/>
						<Ui.Text
							value={look.line}
							size={11}
							color={Palette.muted}
							position={UDim2.fromOffset(0, 18)}
							sizeConstraint={new UDim2(1, -44, 0, 14)}
						/>
						<frame Size={new UDim2(1, 0, 0, 36)} Position={UDim2.fromOffset(0, 38)} BackgroundTransparency={1}>
							<Ui.Button
								text="⟲ LEFT"
								onClick={() => act({ Op: "rotate", At: selected, Back: true }, true)}
								size={new UDim2(0.28, -4, 1, 0)}
								position={new UDim2(0, 0, 0, 0)}
								color={Palette.panelSoft}
								reducedMotion={softMotion}
							/>
							<Ui.Button
								text="⟳ RIGHT"
								onClick={() => act({ Op: "rotate", At: selected }, true)}
								size={new UDim2(0.28, -4, 1, 0)}
								position={new UDim2(0.28, 0, 0, 0)}
								color={Palette.panelSoft}
								reducedMotion={softMotion}
							/>
							<Ui.Button
								text="TO BENCH"
								onClick={() => {
									act({ Op: "store", From: selected }, true);
									setSelected(undefined);
								}}
								size={new UDim2(0.44, 0, 1, 0)}
								position={new UDim2(0.56, 4, 0, 0)}
								color={Palette.panelSoft}
								reducedMotion={softMotion}
								disabled={benchFull}
							/>
						</frame>
					</>
				) : (
					<>
						<Ui.Text
							value={`${look.name} · Tier ${piece.Tier}`}
							size={15}
							weight={Enum.FontWeight.Heavy}
							sizeConstraint={new UDim2(1, -330, 0, 20)}
						/>
						<Ui.Text
							value={look.line}
							size={12}
							color={Palette.muted}
							position={UDim2.fromOffset(0, 22)}
							sizeConstraint={new UDim2(1, -330, 0, 16)}
						/>
						<Ui.Button
							text="⟲"
							onClick={() => act({ Op: "rotate", At: selected, Back: true }, true)}
							size={UDim2.fromOffset(56, 40)}
							position={new UDim2(1, -320, 0, 0)}
							color={Palette.panelSoft}
							reducedMotion={softMotion}
						/>
						<Ui.Button
							text="⟳"
							onClick={() => act({ Op: "rotate", At: selected }, true)}
							size={UDim2.fromOffset(56, 40)}
							position={new UDim2(1, -258, 0, 0)}
							color={Palette.panelSoft}
							reducedMotion={softMotion}
						/>
						<Ui.Button
							text="TO BENCH"
							onClick={() => {
								act({ Op: "store", From: selected }, true);
								setSelected(undefined);
							}}
							size={UDim2.fromOffset(120, 40)}
							position={new UDim2(1, -196, 0, 0)}
							color={Palette.panelSoft}
							reducedMotion={softMotion}
							disabled={benchFull}
						/>
						<Ui.Button
							text=""
							icon="Close"
							tooltip="Deselect"
							onClick={() => setSelected(undefined)}
							size={UDim2.fromOffset(64, 40)}
							position={new UDim2(1, -68, 0, 0)}
							color={Palette.panelSoft}
							reducedMotion={softMotion}
						/>
					</>
				)}
			</Ui.Panel>,
		);
	}

	// actions: ignite, draw, expand (placed directly below board on mobile for instant visibility)
	const canDraw = foundry.Shards >= (foundry.DrawCost ?? math.huge) && !benchFull;
	const canExpand = foundry.ExpandCost !== undefined && foundry.Shards >= foundry.ExpandCost;
	const buttonH = TapTarget;
	const renderActions = () => (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<Ui.Button
				text={surgeLeft > 0 ? `SURGE ${math.ceil(surgeLeft)}s · IGNITE` : combo > 0 ? `IGNITE · ×${combo}` : "IGNITE"}
				icon="Boost.12"
				onClick={() => act({ Op: "ignite" }, true)}
				color={ACCENT}
				textColor={Palette.ink}
				highlight={true}
				size={stack ? new UDim2(1, 0, 0, buttonH) : new UDim2(0.4, -8, 0, buttonH)}
				position={UDim2.fromOffset(0, 0)}
				reducedMotion={softMotion}
			/>
			<Ui.Button
				text={benchFull ? "BENCH FULL" : `DRAW · ${compact(foundry.DrawCost ?? 0)}`}
				icon="Crate.1"
				onClick={() => act({ Op: "draw" })}
				color={Palette.panelSoft}
				disabled={!canDraw || busy}
				size={stack ? new UDim2(1, 0, 0, buttonH) : new UDim2(0.3, -8, 0, buttonH)}
				position={stack ? UDim2.fromOffset(0, buttonH + 10) : new UDim2(0.4, 0, 0, 0)}
				reducedMotion={softMotion}
			/>
			<Ui.Button
				text={foundry.ExpandCost === undefined ? "FULL SIZE" : `EXPAND · ${compact(foundry.ExpandCost)}`}
				icon="World.3"
				onClick={() => act({ Op: "expand" })}
				color={Palette.panelSoft}
				disabled={!canExpand || busy}
				size={stack ? new UDim2(1, 0, 0, buttonH) : new UDim2(0.3, -8, 0, buttonH)}
				position={stack ? UDim2.fromOffset(0, (buttonH + 10) * 2) : new UDim2(0.7, 0, 0, 0)}
				reducedMotion={softMotion}
			/>
			{!stack && (
				<Ui.Text
					value="Ignite when the white hand crosses the gold marker. Ten on the beat in a row: a surge."
					size={12}
					color={Palette.muted}
					position={UDim2.fromOffset(0, buttonH + 8)}
					sizeConstraint={new UDim2(1, 0, 0, 16)}
				/>
			)}
		</frame>
	);

	if (stack) {
		add("actions", buttonH * 3 + 20, renderActions());
	}

	// the bench (centered with exact 5-gap math so slots hit 48-52px touch targets)
	const benchCols = 6;
	const slotGap = 6;
	const innerW = stack ? viewport.width - 24 : 380;
	const slotSize = stack ? math.clamp(math.floor((innerW - (benchCols - 1) * slotGap) / benchCols), 44, 58) : 58;
	const totalRowW = stack ? benchCols * slotSize + (benchCols - 1) * slotGap : benchCols * (58 + 6);
	const rowOffset = stack ? math.max(0, math.floor((innerW - totalRowW) / 2)) : 0;
	const benchRows = stack ? 2 : 1;
	const benchEls: Record<string, React.Element> = {};
	for (let index = 1; index <= FoundryMath.BENCH_CAP; index++) {
		const piece = foundry.Bench[index - 1] as Piece | undefined;
		const col = stack ? (index - 1) % benchCols : index - 1;
		const row = stack ? math.floor((index - 1) / benchCols) : 0;
		const key = `bench:${index}`;
		benchEls["slot" + index] = (
			<textbutton
				Size={UDim2.fromOffset(slotSize, slotSize)}
				Position={UDim2.fromOffset(rowOffset + col * (slotSize + slotGap), 24 + row * (slotSize + slotGap))}
				BackgroundColor3={Palette.panelRaised}
				BackgroundTransparency={piece ? 0.6 : 0.3}
				BorderSizePixel={0}
				AutoButtonColor={false}
				Text=""
				Event={{
					Activated: () => {
						if (piece === undefined) {
							if (selected !== undefined && selected.sub(1, 6) !== "bench:") {
								act({ Op: "store", From: selected }, true);
								setSelected(undefined);
							}
							return;
						}
						Audio.play("foundryPickUp");
						setSelected(selected === key ? undefined : key);
					},
				}}
			>
				<uicorner CornerRadius={new UDim(0, 14)} />
				<uistroke
					Color={selected === key ? Palette.white : Palette.lineSoft}
					Thickness={selected === key ? 2 : 1}
					Transparency={0.4}
				/>
				{piece && <PieceFace piece={piece} size={math.floor(slotSize * 0.82)} selected={selected === key} zIndex={2} />}
			</textbutton>
		);
	}
	const benchH = 24 + benchRows * (slotSize + slotGap);
	add(
		"bench",
		benchH,
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
			<Ui.Text
				value={`BENCH  ·  ${foundry.Bench.size()}/${FoundryMath.BENCH_CAP}  ·  tap a piece, then a cell`}
				size={12}
				weight={Enum.FontWeight.Bold}
				color={Palette.muted}
				sizeConstraint={new UDim2(1, 0, 0, 18)}
			/>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				{benchEls}
			</frame>
		</frame>,
	);

	if (!stack) {
		add("actions", buttonH + 30, renderActions());
	}
	if (note !== "") {
		add("note", 26, <Ui.Text value={note} size={14} color={Palette.creamSoft} sizeConstraint={new UDim2(1, 0, 0, 22)} />);
	}
	return <PageScaffold sections={sections} gap={GAP} tailPad={72} scrollBarColor={ACCENT} />;
}

export = () => ({ FoundryView });
