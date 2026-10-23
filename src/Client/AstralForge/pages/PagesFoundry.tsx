// Star Foundry: a hex board of star pieces. Embers send energy along the way they face, Conduits and
// Lenses carry it, Prisms split it, Anvils turn it into production, tap, capacity and offline bonuses.
// Tap a piece (board or bench), then a cell, to place, move or fuse it. Ignite when the sweeping wave
// crosses your brightest Anvil for Shards; ten on the beat in a row light a surge.
// The board you see runs the same FoundryMath the server does, so the flow drawn is the flow you get.
import React from "@rbxts/react";
import { headingBlock, MockBtn, MockRow, panelHeight, rowHeight, useWidth } from "./mockRows";
import { BODY, Line, MockPanel, mockGap, PanelHeading, panelPad } from "../UiCore/mockKit";
import { FlexCol, FlexFill, FlexFixed, FlexRow, stackSum } from "./mockLayout";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import * as Format from "../CoreKit/format";
import { chromeFor, darken, lighten, Palette, scrollTail, TapTarget } from "../CoreKit/theme";
import { useClock, useViewport } from "../MotionKit/motion";
import FoundryMath = require("../../../Shared/AstralForge/Shared/FoundryMath");
import { Component, loadAudio, loadPageScaffold, luauKit, luauModule } from "./luauDeps";

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

const ACCENT = Palette.brass;
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

const ROUND = <uicorner CornerRadius={new UDim(1, 0)} />;

// A flat-top hexagon from plain frames: three rectangles (R wide, sqrt(3)R tall) at 0, 60 and 120
// degrees overlap into exactly the hexagon with circumradius R.
function Hexagon(props: {
	radius: number;
	color: Color3;
	transparency?: number;
	zIndex?: number;
	position?: UDim2;
	gradient?: { Rotation?: number; Color?: ColorSequence };
}) {
	const r = props.radius;
	const bars: Record<string, React.Element> = {};
	[0, 60, 120].forEach((angle, i) => {
		bars["bar" + (i + 1)] = (
			<frame
				Size={UDim2.fromOffset(r, r * math.sqrt(3))}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={angle}
				BackgroundColor3={props.color}
				BackgroundTransparency={props.transparency ?? 0}
				BorderSizePixel={0}
				ZIndex={props.zIndex ?? 1}
			>
				{props.gradient && <uigradient Rotation={props.gradient.Rotation} Color={props.gradient.Color} />}
			</frame>
		);
	});
	return (
		<frame
			Size={UDim2.fromOffset(r * 2, r * 2)}
			Position={props.position ?? UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			ZIndex={props.zIndex ?? 1}
		>
			{bars}
		</frame>
	);
}

// a soft round glow: concentric discs, each faint, so the middle builds up and the edge fades out
function Halo(props: { size: number; color: Color3; transparency?: number; zIndex?: number; position?: UDim2 }) {
	const d = props.size;
	const strength = 1 - (props.transparency ?? 0.2);
	const discs: Record<string, React.Element> = {};
	const steps = 6;
	for (let index = 1; index <= steps; index++) {
		const share = index / steps;
		discs["disc" + index] = (
			<frame
				Size={UDim2.fromScale(share, share)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={props.color}
				BackgroundTransparency={1 - (strength / steps) * 1.6}
				BorderSizePixel={0}
				ZIndex={props.zIndex ?? 1}
			>
				{ROUND}
			</frame>
		);
	}
	return (
		<frame
			Size={UDim2.fromOffset(d, d)}
			Position={props.position ?? UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			ZIndex={props.zIndex ?? 1}
		>
			{discs}
		</frame>
	);
}

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

// Each kind has its own silhouette: an Ember is a burning four-point star, a Conduit a diamond,
// a Lens a ring with a bright core, a Prism a triangle, an Anvil a solid hexagon plate.
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
	const color = look.color;
	const lit = props.lit ?? 0;
	const clock = props.clock;
	let body: React.Element;
	if (piece.Kind === "Ember") {
		const rays: Record<string, React.Element> = {};
		[0, 90].forEach((angle, i) => {
			rays["ray" + (i + 1)] = (
				<frame
					Size={new UDim2(1.15, 0, 0, math.max(2, math.floor(d * 0.1)))}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={clock ? clock.map((t) => angle + t * 18) : angle}
					BackgroundColor3={lighten(color, 0.45)}
					BorderSizePixel={0}
					ZIndex={z + 1}
				>
					<uigradient
						Transparency={
							new NumberSequence([
								new NumberSequenceKeypoint(0, 1),
								new NumberSequenceKeypoint(0.5, 0),
								new NumberSequenceKeypoint(1, 1),
							])
						}
					/>
				</frame>
			);
		});
		body = (
			<>
				<Halo size={d * 1.5} color={color} transparency={0.1} zIndex={z} />
				<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={z + 1}>
					{rays}
				</frame>
				<frame
					Size={UDim2.fromScale(0.42, 0.42)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={Palette.white}
					BorderSizePixel={0}
					ZIndex={z + 2}
				>
					{ROUND}
					<uistroke Color={color} Thickness={3} />
				</frame>
			</>
		);
	} else if (piece.Kind === "Conduit") {
		body = (
			<frame
				Size={UDim2.fromScale(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				BackgroundColor3={darken(color, 0.35)}
				BorderSizePixel={0}
				ZIndex={z + 1}
			>
				<uicorner CornerRadius={new UDim(0, 6)} />
				<uistroke Color={lighten(color, 0.3)} Thickness={2} />
			</frame>
		);
	} else if (piece.Kind === "Lens") {
		body = (
			<>
				<frame
					Size={UDim2.fromScale(0.7, 0.7)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={z + 1}
				>
					{ROUND}
					<uistroke Color={color} Thickness={math.max(2, d * 0.07)} />
				</frame>
				<frame
					Size={UDim2.fromScale(0.22, 0.22)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundColor3={lighten(color, 0.6)}
					BorderSizePixel={0}
					ZIndex={z + 2}
				>
					{ROUND}
				</frame>
			</>
		);
	} else if (piece.Kind === "Prism") {
		// a square with a hard diagonal mask, turned: an upward triangle
		body = (
			<frame
				Size={UDim2.fromScale(0.62, 0.62)}
				Position={UDim2.fromScale(0.5, 0.6)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={45}
				BackgroundColor3={color}
				BorderSizePixel={0}
				ZIndex={z + 1}
			>
				<uigradient
					Rotation={-135}
					Color={new ColorSequence(lighten(color, 0.4), darken(color, 0.2))}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.495, 1),
							new NumberSequenceKeypoint(0.505, 0),
							new NumberSequenceKeypoint(1, 0),
						])
					}
				/>
			</frame>
		);
	} else {
		// anvils: a solid hexagon plate in the colour of what they make, the stat icon inset
		body = (
			<>
				<Hexagon radius={d * 0.42} color={darken(color, 0.45)} zIndex={z + 1} />
				<Hexagon
					radius={d * 0.34}
					color={color}
					transparency={0.15}
					zIndex={z + 1}
					gradient={{ Rotation: 90, Color: new ColorSequence(lighten(color, 0.35), darken(color, 0.25)) }}
				/>
				<Icon
					kind={look.icon}
					color={Palette.ink}
					accent={Palette.ink}
					size={math.floor(d * 0.36)}
					position={UDim2.fromScale(0.5, 0.5)}
					anchorPoint={new Vector2(0.5, 0.5)}
					spin={false}
				/>
			</>
		);
	}
	return (
		<frame
			Size={UDim2.fromOffset(d, d)}
			Position={props.position ?? UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			ZIndex={z}
		>
			{/* energy passing through makes a piece glow */}
			{lit > 0.05 && FoundryMath.KINDS[piece.Kind].role !== "source" && (
				<Halo size={d * (1 + lit * 0.5)} color={color} transparency={0.55 - lit * 0.35} zIndex={z} />
			)}
			{props.selected && (
				<frame
					Size={UDim2.fromScale(1.2, 1.2)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					BackgroundTransparency={1}
					ZIndex={z + 3}
				>
					{ROUND}
					<uistroke Color={Palette.white} Thickness={2} Transparency={0.1} />
				</frame>
			)}
			{body}
			{props.showFacing && FoundryMath.KINDS[piece.Kind].role !== "sink" && (
				// a stub of beam out of the side it faces
				<frame
					Size={UDim2.fromOffset(math.floor(d * 0.62), 3)}
					Position={UDim2.fromScale(0.5, 0.5)}
					AnchorPoint={new Vector2(0, 0.5)}
					Rotation={directionAngle(piece.Facing)}
					BackgroundColor3={lighten(color, 0.4)}
					BorderSizePixel={0}
					ZIndex={z}
				>
					<uigradient
						Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.1), new NumberSequenceKeypoint(1, 1)])}
					/>
				</frame>
			)}
			<TierMark tier={piece.Tier} color={color} cellSize={d} zIndex={z + 3} />
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
}) {
	const foundry = props.foundry;
	const flow = props.flow;
	const size = props.cellSize;
	const clock = useClock(!props.softMotion, 1, 3600, true);
	const centre = new Vector2(props.width / 2, props.height / 2);
	const children: Record<string, React.Element> = {};
	// deep space: a warm nebula behind the board and a slow, faint drift of stars
	children.nebula = (
		<Halo
			size={math.min(props.width, props.height) * 1.25}
			color={Palette.brassDeep}
			transparency={0.55}
			position={UDim2.fromOffset(centre.X, centre.Y)}
			zIndex={0}
		/>
	);
	for (let index = 1; index <= 28; index++) {
		const x = ((index * 0.6180339) % 1) * props.width;
		const y = ((index * 0.7548776) % 1) * props.height;
		children["star" + index] = (
			<frame
				Size={UDim2.fromOffset(index % 5 === 0 ? 3 : 2, index % 5 === 0 ? 3 : 2)}
				Position={UDim2.fromOffset(x, y)}
				BackgroundColor3={Palette.white}
				BackgroundTransparency={props.softMotion ? 0.6 : clock.map((t) => 0.45 + 0.4 * math.sin(t * 0.8 + index))}
				BorderSizePixel={0}
				ZIndex={0}
			>
				{ROUND}
			</frame>
		);
	}
	// the orbit ring the ignite comet runs on, with a notch at the target
	const orbit = math.min(props.width, props.height) * 0.47;
	const target = FoundryMath.targetPhase({ Radius: foundry.Radius, Pieces: foundry.Pieces });
	children.orbit = (
		<frame
			Size={UDim2.fromOffset(orbit * 2, orbit * 2)}
			Position={UDim2.fromOffset(centre.X, centre.Y)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			ZIndex={1}
		>
			{ROUND}
			<uistroke Color={ACCENT} Thickness={1} Transparency={0.75} />
		</frame>
	);
	const tx = math.cos(target * 2 * math.pi);
	const ty = math.sin(target * 2 * math.pi);
	children.notch = (
		<frame
			Size={UDim2.fromOffset(18, 4)}
			Position={UDim2.fromOffset(centre.X + tx * orbit, centre.Y + ty * orbit)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Rotation={math.deg(target * 2 * math.pi)}
			BackgroundColor3={ACCENT}
			BorderSizePixel={0}
			ZIndex={7}
		>
			{ROUND}
		</frame>
	);
	const cometPoint = (lag: number) => () => {
		const phase = FoundryMath.wavePhase(foundry.IgniteAt ?? 0, Workspace.GetServerTimeNow()) - lag;
		const angle = phase * 2 * math.pi;
		return UDim2.fromOffset(centre.X + math.cos(angle) * orbit, centre.Y + math.sin(angle) * orbit);
	};
	for (let index = 0; index <= 5; index++) {
		const lag = index * 0.012;
		children["comet" + index] = (
			<frame
				Size={UDim2.fromOffset(10 - index * 1.4, 10 - index * 1.4)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={clock.map(cometPoint(lag))}
				BackgroundColor3={index === 0 ? Palette.white : ACCENT}
				BackgroundTransparency={clock.map(() => {
					const phase = FoundryMath.wavePhase(foundry.IgniteAt ?? 0, Workspace.GetServerTimeNow());
					const hot = FoundryMath.onBeat(phase, target);
					return math.clamp((hot ? 0 : 0.15) + index * 0.15, 0, 1);
				})}
				BorderSizePixel={0}
				ZIndex={8}
			>
				{ROUND}
			</frame>
		);
	}
	// energy beams: a wide soft glow under a thin bright core, shading from source to target colour
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
			const beam = (name: string, thickness: number, transparency: number, z: number) => {
				children[name + index] = (
					<frame
						Size={UDim2.fromOffset(delta.Magnitude, thickness)}
						Position={UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						Rotation={math.deg(math.atan2(delta.Y, delta.X))}
						BackgroundColor3={Palette.white}
						BackgroundTransparency={transparency}
						BorderSizePixel={0}
						ZIndex={z}
					>
						{ROUND}
						<uigradient Color={new ColorSequence(c1, c2)} />
					</frame>
				);
			};
			beam("glow", 6 + strength * 10, 0.82 - strength * 0.12, 2);
			beam("core", 1.5 + strength * 2, 0.15, 3);
			if (!props.softMotion) {
				const speed = 0.7 + strength * 1.4;
				const offset = (index * 0.37) % 1;
				for (let tail = 0; tail <= 2; tail++) {
					children["pulse" + index + "_" + tail] = (
						<frame
							Size={UDim2.fromOffset(7 - tail * 2, 7 - tail * 2)}
							AnchorPoint={new Vector2(0.5, 0.5)}
							Position={clock.map((t) => {
								const u = (t * speed + offset - tail * 0.04) % 1;
								const p = a.add(delta.mul(u));
								return UDim2.fromOffset(p.X, p.Y);
							})}
							BackgroundColor3={tail === 0 ? Palette.white : c2}
							BackgroundTransparency={tail * 0.3}
							BorderSizePixel={0}
							ZIndex={4}
						>
							{ROUND}
						</frame>
					);
				}
			}
		}
	}
	// the lattice: a faint hexagon socket for every cell, pieces sitting in them
	for (const key of FoundryMath.cells(foundry.Radius)) {
		const [q, r] = FoundryMath.parse(key);
		const p = centre.add(hexPixel(q!, r!, size));
		const piece = foundry.Pieces[key] as Piece | undefined;
		const targeted = props.selected !== undefined && props.selected !== key;
		children["socket" + key] = (
			<Hexagon
				radius={size * 0.94}
				color={targeted && piece === undefined ? darken(ACCENT, 0.55) : Palette.panelSoft}
				transparency={piece ? 0.6 : 0.2}
				position={UDim2.fromOffset(p.X, p.Y)}
				zIndex={1}
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
						showFacing={true}
						clock={props.softMotion ? undefined : clock}
						zIndex={5}
					/>
				)}
			</textbutton>
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ClipsDescendants={true}>
			<uicorner CornerRadius={new UDim(0, 18)} />
			{children}
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

type Section = { id: string; height: number; element: React.Element };

/** A bench slot: a raised square with the piece face, tap to pick it up or to store the selection. */
function BenchSlot(props: { piece?: Piece; selected: boolean; size: number; index: number; onPress: () => void }) {
	return (
		<textbutton
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.panelRaised}
			BackgroundTransparency={props.piece ? 0.6 : 0.3}
			BorderSizePixel={0}
			AutoButtonColor={false}
			Text=""
			LayoutOrder={props.index}
			Event={{ Activated: props.onPress }}
		>
			<uicorner CornerRadius={new UDim(0, 12)} />
			<uistroke Color={props.selected ? Palette.white : Palette.lineSoft} Thickness={props.selected ? 2 : 1} Transparency={0.4} />
			{props.piece && <PieceFace piece={props.piece} size={math.floor(props.size * 0.82)} selected={props.selected} zIndex={2} />}
		</textbutton>
	);
}

function FoundryView(props: {
	state: { Foundry?: unknown };
	reducedMotion?: boolean;
	dispatch: (action: string, payload: Payload, callback: (response: unknown) => void) => void;
}) {
	const softMotion = props.reducedMotion;
	const viewport = useViewport();
	const chrome = chromeFor(viewport);
	const phone = chrome.contentStack;
	// design/11: the board panel fills the row, the 460px side panel holds the readout and controls
	const wide = !phone && viewport.width >= 1100;
	const [selected, setSelected] = React.useState<string | undefined>(undefined);
	const [busy, setBusy] = React.useState(false);
	const [note, setNote] = React.useState("");
	const [combo, setCombo] = React.useState(0);
	const [boardWidth, onBoardSize] = useWidth(phone ? viewport.width - 48 : math.max(320, viewport.width - 460 - 120));
	// gamepad: first focus goes to Ignite once the foundry has loaded
	const igniteHostRef = React.useRef<Frame>();
	const foundryLoaded = typeIs(props.state.Foundry, "table");
	React.useEffect(() => {
		if (!foundryLoaded || !game.GetService("UserInputService").GamepadEnabled) {
			return undefined;
		}
		const selectJob = task.defer(() => {
			const host = igniteHostRef.current;
			if (host === undefined || host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [foundryLoaded]);
	const gap = mockGap(phone);
	const pad = panelPad(phone);
	const head = headingBlock(phone);
	const rowH = rowHeight(phone);
	const bH = phone ? TapTarget : 44;
	const tail = scrollTail(phone, chrome.bottomSafe, 24);
	if (!typeIs(props.state.Foundry, "table")) {
		return (
			<PageScaffold
				gap={gap}
				tailPad={tail}
				owner="FoundryView"
				sections={[
					{
						id: "loading",
						height: panelHeight(phone, head + rowH),
						element: (
							<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={softMotion}>
								<PanelHeading icon="Forge" title="Star Foundry" phone={phone} layoutOrder={0} />
								<MockRow phone={phone} icon="Timer" title="Loading the Star Foundry…" dim={true} layoutOrder={1} />
							</MockPanel>
						),
					},
				]}
			/>
		);
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
	const benchFull = foundry.Bench.size() >= FoundryMath.BENCH_CAP;
	const canDraw = foundry.Shards >= (foundry.DrawCost ?? math.huge) && !benchFull;
	const canExpand = foundry.ExpandCost !== undefined && foundry.Shards >= foundry.ExpandCost;

	// ---------- readout panel: shards, rate, the four bonuses, Ignite ----------
	const stats: Array<[string, string, string, Color3]> = [
		["Production", `×${compact(effects.Production ?? 1)}`, "Production", Color3.fromRGB(255, 196, 84)],
		["Tap", `×${compact(effects.Tap ?? 1)}`, "Boost", Color3.fromRGB(255, 104, 112)],
		["Capacity", `×${compact(effects.Capacity ?? 1)}`, "Vault", Color3.fromRGB(96, 220, 168)],
		["Offline", `+${math.floor((effects.Offline ?? 0) * 100 + 0.5)}%`, "Timer", Color3.fromRGB(176, 140, 255)],
	];
	const statGap = pad.gap;
	const statRows = 2;
	const statGridH = statRows * rowH + (statRows - 1) * statGap;
	const hintText = "Ignite when the white hand crosses the gold marker. Ten on the beat in a row: a surge.";
	const hintH = phone ? 32 : 36;
	const igniteText = surgeLeft > 0 ? `Surge ${math.ceil(surgeLeft)}s · Ignite` : combo > 0 ? `Ignite · ×${combo}` : "Ignite";
	const readoutH = panelHeight(phone, head + rowH + pad.gap + statGridH + pad.gap + bH + pad.gap + hintH);
	const readout = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reveal={undefined} reducedMotion={softMotion} name="FoundryReadout">
			<PanelHeading icon="Forge" title="Star Foundry" note={`Radius ${foundry.Radius}`} phone={phone} layoutOrder={0} />
			<MockRow
				phone={phone}
				icon="Flux"
				title={`${compact(foundry.Shards)} Shards`}
				value={dormant ? "Dormant" : `+${"%.1f".format((foundry.ShardRate ?? 0) * 60)}/min`}
				valueColor={dormant ? Palette.muted : undefined}
				sub={dormant ? "Rotate an Ember to face an Anvil" : undefined}
				height={rowH}
				layoutOrder={1}
			/>
			<frame key="Bonuses" Size={new UDim2(1, 0, 0, statGridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
				<uigridlayout
					CellSize={new UDim2(0.5, -math.ceil(statGap / 2), 0, rowH)}
					CellPadding={UDim2.fromOffset(statGap, statGap)}
					FillDirectionMaxCells={2}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				{stats.map(([label, value, icon, color], index) => (
					<MockRow key={label} phone={phone} icon={icon} accent={color} title={label} value={value} valueColor={color} layoutOrder={index} />
				))}
			</frame>
			<frame key="FoundryIgnite" ref={igniteHostRef} Size={new UDim2(1, 0, 0, bH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={3}>
				<MockBtn text={igniteText} icon="Boost.12" accent={ACCENT} fill={true} phone={phone} onClick={() => act({ Op: "ignite" }, true)} reducedMotion={softMotion} />
			</frame>
			<textlabel
				Size={new UDim2(1, 0, 0, hintH)}
				BackgroundTransparency={1}
				Text={hintText}
				TextSize={phone ? 11 : 13}
				FontFace={BODY}
				TextColor3={Palette.muted}
				TextWrapped={true}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				LayoutOrder={4}
			/>
		</MockPanel>
	);

	// ---------- selection panel: what is picked up and what to do with it ----------
	const boardPick = selected !== undefined && selected.sub(1, 6) !== "bench:" ? foundry.Pieces[selected] : undefined;
	const benchPick = selected !== undefined && selected.sub(1, 6) === "bench:" ? (foundry.Bench[(tonumber(selected.sub(7)) ?? 0) - 1] as Piece | undefined) : undefined;
	const picked = boardPick ?? benchPick;
	const look = picked !== undefined ? KIND_LOOK[picked.Kind] ?? CONDUIT : undefined;
	const selectH = panelHeight(phone, head + rowH + (boardPick !== undefined ? pad.gap + bH : 0));
	const selectPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={softMotion} name="FoundrySelected">
			<PanelHeading
				icon={look?.icon ?? "Search"}
				title={look !== undefined ? look.name : "Selected"}
				note={picked !== undefined ? `Tier ${picked.Tier}` : "Nothing picked up"}
				accent={look?.color}
				phone={phone}
				layoutOrder={0}
			/>
			<MockRow
				phone={phone}
				icon={look?.icon ?? "Info"}
				accent={look?.color}
				title={look !== undefined ? look.line : "Tap a piece, then a cell"}
				sub={benchPick !== undefined ? "Now tap a board cell to place it" : boardPick !== undefined ? "Tap a cell to move or fuse" : "Place, move or fuse pieces on the board"}
				dim={picked === undefined}
				right={
					picked !== undefined ? (
						<MockBtn text="" icon="Close" sec={true} sm={true} phone={phone} width={44} onClick={() => setSelected(undefined)} reducedMotion={softMotion} />
					) : undefined
				}
				rightWidth={picked !== undefined ? 44 : undefined}
				layoutOrder={1}
			/>
			{boardPick !== undefined && (
				<FlexRow height={bH} gap={8} layoutOrder={2}>
					<FlexFill layoutOrder={0}>
						<MockBtn text="Left" icon="Back.2" sec={true} fill={true} phone={phone} onClick={() => act({ Op: "rotate", At: selected, Back: true }, true)} reducedMotion={softMotion} />
					</FlexFill>
					<FlexFill layoutOrder={1}>
						<MockBtn text="Right" icon="Refresh" sec={true} fill={true} phone={phone} onClick={() => act({ Op: "rotate", At: selected }, true)} reducedMotion={softMotion} />
					</FlexFill>
					<FlexFill layoutOrder={2}>
						<MockBtn
							text="To bench"
							icon="Crate.1"
							sec={true}
							fill={true}
							phone={phone}
							disabled={benchFull}
							onClick={() => {
								act({ Op: "store", From: selected }, true);
								setSelected(undefined);
							}}
							reducedMotion={softMotion}
						/>
					</FlexFill>
				</FlexRow>
			)}
		</MockPanel>
	);

	// ---------- bench panel: the spare pieces, Draw and Expand ----------
	const slotGap = 6;
	const benchInner = wide ? 460 - pad.x * 2 : viewport.width - 24 - pad.x * 2;
	const benchCols = phone && benchInner < 6 * 44 + 5 * slotGap ? 4 : 6;
	const slotSize = math.clamp(math.floor((benchInner - (benchCols - 1) * slotGap) / benchCols), 44, 64);
	const benchRows = math.ceil(FoundryMath.BENCH_CAP / benchCols);
	const benchGridH = benchRows * slotSize + (benchRows - 1) * slotGap;
	const noteH = note !== "" ? (phone ? 18 : 20) + pad.gap : 0;
	const benchH = panelHeight(phone, head + benchGridH + pad.gap + bH + noteH);
	const slots: React.Element[] = [];
	for (let index = 1; index <= FoundryMath.BENCH_CAP; index++) {
		const piece = foundry.Bench[index - 1] as Piece | undefined;
		const key = `bench:${index}`;
		slots.push(
			<BenchSlot
				key={key}
				piece={piece}
				selected={selected === key}
				size={slotSize}
				index={index}
				onPress={() => {
					if (piece === undefined) {
						if (selected !== undefined && selected.sub(1, 6) !== "bench:") {
							act({ Op: "store", From: selected }, true);
							setSelected(undefined);
						}
						return;
					}
					Audio.play("foundryPickUp");
					setSelected(selected === key ? undefined : key);
				}}
			/>,
		);
	}
	const benchPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={softMotion} name="FoundryBench">
			<PanelHeading icon="Crate.1" title="Bench" note={`${foundry.Bench.size()} of ${FoundryMath.BENCH_CAP}`} phone={phone} layoutOrder={0} />
			<frame key="BenchSlots" Size={new UDim2(1, 0, 0, benchGridH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
				<uigridlayout
					CellSize={UDim2.fromOffset(slotSize, slotSize)}
					CellPadding={UDim2.fromOffset(slotGap, slotGap)}
					FillDirectionMaxCells={benchCols}
					HorizontalAlignment={Enum.HorizontalAlignment.Center}
					SortOrder={Enum.SortOrder.LayoutOrder}
				/>
				{slots}
			</frame>
			<FlexRow height={bH} gap={8} layoutOrder={2}>
				<FlexFill layoutOrder={0}>
					<MockBtn
						text={benchFull ? "Bench full" : `Draw · ${compact(foundry.DrawCost ?? 0)}`}
						icon="Crate.1"
						sec={true}
						fill={true}
						phone={phone}
						disabled={!canDraw || busy}
						onClick={() => act({ Op: "draw" })}
						reducedMotion={softMotion}
					/>
				</FlexFill>
				<FlexFill layoutOrder={1}>
					<MockBtn
						text={foundry.ExpandCost === undefined ? "Full size" : `Expand · ${compact(foundry.ExpandCost)}`}
						icon="World.3"
						sec={true}
						fill={true}
						phone={phone}
						disabled={!canExpand || busy}
						onClick={() => act({ Op: "expand" })}
						reducedMotion={softMotion}
					/>
				</FlexFill>
			</FlexRow>
			{note !== "" && <Line text={note} size={phone ? 12 : 14} font={BODY} color={Palette.creamSoft} width={new UDim(1, 0)} height={phone ? 18 : 20} layoutOrder={3} />}
		</MockPanel>
	);

	// ---------- the board panel (.pn.f1): the hex lattice fills it ----------
	const sideH = stackSum([readoutH, selectH, benchH], gap);
	const boardPanelH = wide ? math.max(560, sideH) : panelHeight(phone, math.min(viewport.width - 24, 420));
	const boardH = boardPanelH - pad.y * 2;
	const boardW = math.max(200, boardWidth);
	const cells = foundry.Radius * 2 + 1;
	// the lattice (and the orbit ring round it) fits the shorter side with a margin
	const cellSize = math.floor(math.min(boardW / (1.5 * cells + 0.6), (boardH * 0.86) / (math.sqrt(3) * cells + 0.2)));
	const boardPanel = (
		<MockPanel size={UDim2.fromScale(1, 1)} phone={phone} reducedMotion={softMotion} gap={0} name="FoundryBoard">
			<frame key="Board" Size={new UDim2(1, 0, 0, boardH)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={0} Change={{ AbsoluteSize: onBoardSize }}>
				<Board foundry={foundry} flow={flow} cellSize={cellSize} width={boardW} height={boardH} selected={selected} onCell={onCell} softMotion={softMotion} />
			</frame>
		</MockPanel>
	);

	const sections: Section[] = [];
	if (wide) {
		sections.push({
			id: "foundry",
			height: boardPanelH,
			element: (
				<FlexRow fillHeight={true} gap={gap} name="FoundryBody">
					<FlexFill layoutOrder={0}>{boardPanel}</FlexFill>
					<FlexFixed width={460} layoutOrder={1}>
						<FlexCol fill={true} gap={gap}>
							<FlexFixed width={460} height={readoutH} layoutOrder={0}>
								{readout}
							</FlexFixed>
							<FlexFixed width={460} height={selectH} layoutOrder={1}>
								{selectPanel}
							</FlexFixed>
							<FlexFixed width={460} height={math.max(benchH, boardPanelH - readoutH - selectH - gap * 2)} layoutOrder={2}>
								{benchPanel}
							</FlexFixed>
						</FlexCol>
					</FlexFixed>
				</FlexRow>
			),
		});
	} else {
		sections.push({ id: "readout", height: readoutH, element: readout });
		sections.push({ id: "board", height: boardPanelH, element: boardPanel });
		sections.push({ id: "selected", height: selectH, element: selectPanel });
		sections.push({ id: "bench", height: benchH, element: benchPanel });
	}
	return <PageScaffold sections={sections} gap={gap} tailPad={tail} scrollBarColor={ACCENT} scrollBarThickness={4} owner="FoundryView" />;
}

export = () => ({ FoundryView });
