// Star Foundry on Forge2 (serves the Continuum, Foundry and Anomaly routes, like the old router).
// A hex board of star pieces: Embers push energy the way they face, Conduits and Lenses carry it,
// Prisms split it, Anvils turn it into bonuses. Pick a piece, then a cell, to place, move or fuse.
// The board runs the same FoundryMath as the server, so the drawn flow is the real flow.
// Remote: FoundryAct { Op: place | move | rotate | store | ignite | draw | expand, From?, To?, At?, Back? }
import React from "@rbxts/react";
import { Audio } from "../../AudioKit/audio";
import { compactNumber } from "../../CoreKit/format";
import { useChangePop, useClock, useFlash, useStagger, useViewport } from "../../MotionKit/motion";
import FoundryMath = require("../../../../Shared/AstralForge/Shared/FoundryMath");
import Juice = require("../../JuiceFx");
import { Button } from "../design/Button";
import { EmptyState, Tooltip } from "../design/Layers";
import { Panel } from "../design/Panel";
import { Text, Title } from "../design/Text";
import { Corner, Fonts, gap, HIT, Iron, Type } from "../design/tokens";
import { useBack } from "../input/input";
import { Burst, MotionFX } from "../motion/motion";
import type { PageProps } from "../router/routes";

const Workspace = game.GetService("Workspace");

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
	line: string;
}

const WARM = Color3.fromRGB(255, 176, 92);
const LOOKS: Record<string, Look> = {
	Ember: { name: "Ember", color: Color3.fromRGB(255, 132, 64), line: "Pushes energy the way it faces." },
	Conduit: { name: "Conduit", color: Color3.fromRGB(120, 196, 255), line: "Carries energy on." },
	Lens: { name: "Lens", color: Color3.fromRGB(150, 236, 255), line: "Carries energy and makes it stronger." },
	Prism: { name: "Prism", color: Color3.fromRGB(200, 150, 255), line: "Splits energy three ways." },
	ForgeAnvil: { name: "Forge Anvil", color: Color3.fromRGB(255, 196, 84), line: "Turns energy into production." },
	StrikeAnvil: { name: "Strike Anvil", color: Color3.fromRGB(255, 104, 112), line: "Turns energy into tap power." },
	VaultAnvil: { name: "Vault Anvil", color: Color3.fromRGB(96, 220, 168), line: "Turns energy into vault space." },
	EchoAnvil: { name: "Echo Anvil", color: Color3.fromRGB(176, 140, 255), line: "Turns energy into offline income." },
};
const lookOf = (kind: string) => LOOKS[kind] ?? LOOKS.Conduit;
const isBench = (key: string | undefined) => key !== undefined && key.sub(1, 6) === "bench:";
const SQRT3 = math.sqrt(3);

function cellPoint(q: number, r: number, size: number): Vector2 {
	return new Vector2(size * 1.5 * q, size * SQRT3 * (r + q / 2));
}

function roleOf(kind: string): string {
	return FoundryMath.KINDS[kind]?.role ?? "relay";
}

/** Flat-top hex built from three overlapping bars. */
function Hex(props: { radius: number; color: Color3; transparency?: number | React.Binding<number>; at: UDim2; z: number }) {
	const bars: Record<string, React.Element> = {};
	for (const angle of [0, 60, 120]) {
		bars[`b${angle}`] = (
			<frame
				Size={UDim2.fromOffset(props.radius, props.radius * SQRT3)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={angle}
				BackgroundColor3={props.color}
				BackgroundTransparency={props.transparency ?? 0}
				BorderSizePixel={0}
				ZIndex={props.z}
			/>
		);
	}
	return (
		<frame Size={UDim2.fromOffset(props.radius * 2, props.radius * 2)} Position={props.at} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ZIndex={props.z}>
			{bars}
		</frame>
	);
}

function Glow(props: { size: number; color: Color3; strength: number; at?: UDim2; z: number }) {
	const rings: Record<string, React.Element> = {};
	for (let i = 1; i <= 5; i++) {
		rings[`g${i}`] = (
			<frame
				Size={UDim2.fromScale(i / 5, i / 5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={props.color}
				BackgroundTransparency={1 - (props.strength / 5) * 1.5}
				BorderSizePixel={0}
				ZIndex={props.z}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}
	return (
		<frame Size={UDim2.fromOffset(props.size, props.size)} Position={props.at ?? UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ZIndex={props.z}>
			{rings}
		</frame>
	);
}

/** One piece: its silhouette says what it does; pips show its tier; a beam stub shows where it faces. */
function PieceArt(props: { piece: Piece; size: number; lit?: number; spin?: React.Binding<number>; picked?: boolean; z: number }) {
	const { piece, size, z } = props;
	const look = lookOf(piece.Kind);
	const role = roleOf(piece.Kind);
	const lit = props.lit ?? 0;
	let core: React.Element;
	if (role === "source") {
		core = (
			<>
				<Glow size={size * 1.5} color={look.color} strength={0.9} z={z} />
				{[0, 90].map((angle) => (
					<frame
						key={`ray${angle}`}
						Size={new UDim2(1.1, 0, 0, math.max(2, math.floor(size * 0.1)))}
						Position={UDim2.fromScale(0.5, 0.5)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						Rotation={props.spin !== undefined ? props.spin.map((t) => angle + t * 20) : angle}
						BackgroundColor3={look.color.Lerp(new Color3(1, 1, 1), 0.45)}
						BorderSizePixel={0}
						ZIndex={z + 1}
					>
						<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.5, 0), new NumberSequenceKeypoint(1, 1)])} />
					</frame>
				))}
				<frame Size={UDim2.fromScale(0.4, 0.4)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={new Color3(1, 1, 1)} BorderSizePixel={0} ZIndex={z + 2}>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={look.color} Thickness={3} />
				</frame>
			</>
		);
	} else if (role === "sink") {
		core = (
			<>
				<Hex radius={size * 0.42} color={look.color.Lerp(new Color3(), 0.45)} at={UDim2.fromScale(0.5, 0.5)} z={z + 1} />
				<Hex radius={size * 0.32} color={look.color} transparency={0.1} at={UDim2.fromScale(0.5, 0.5)} z={z + 2} />
			</>
		);
	} else if (piece.Kind === "Prism") {
		core = (
			<frame Size={UDim2.fromScale(0.6, 0.6)} Position={UDim2.fromScale(0.5, 0.6)} AnchorPoint={new Vector2(0.5, 0.5)} Rotation={45} BackgroundColor3={look.color} BorderSizePixel={0} ZIndex={z + 1}>
				<uigradient
					Rotation={-135}
					Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.49, 1), new NumberSequenceKeypoint(0.51, 0), new NumberSequenceKeypoint(1, 0)])}
				/>
			</frame>
		);
	} else if (piece.Kind === "Lens") {
		core = (
			<frame Size={UDim2.fromScale(0.66, 0.66)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ZIndex={z + 1}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke Color={look.color} Thickness={math.max(2, size * 0.07)} />
				<frame Size={UDim2.fromScale(0.34, 0.34)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={look.color.Lerp(new Color3(1, 1, 1), 0.6)} BorderSizePixel={0} ZIndex={z + 2}>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>
			</frame>
		);
	} else {
		core = (
			<frame Size={UDim2.fromScale(0.48, 0.48)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} Rotation={45} BackgroundColor3={look.color.Lerp(new Color3(), 0.35)} BorderSizePixel={0} ZIndex={z + 1}>
				<uicorner CornerRadius={new UDim(0, 5)} />
				<uistroke Color={look.color.Lerp(new Color3(1, 1, 1), 0.3)} Thickness={2} />
			</frame>
		);
	}
	const facing = FoundryMath.DIRECTIONS[piece.Facing];
	const faceAngle = facing !== undefined ? math.deg(math.atan2(cellPoint(facing[0], facing[1], 1).Y, cellPoint(facing[0], facing[1], 1).X)) : 0;
	const pips: React.Element[] = [];
	const tier = piece.Tier;
	if (tier <= 5 && size >= 32) {
		for (let i = 1; i <= tier; i++) {
			pips.push(
				<frame
					key={`pip${i}`}
					Size={UDim2.fromOffset(4, 4)}
					Position={new UDim2(0.5, (i - (tier + 1) / 2) * 7, 1, 2)}
					AnchorPoint={new Vector2(0.5, 0)}
					BackgroundColor3={look.color.Lerp(new Color3(1, 1, 1), 0.4)}
					BorderSizePixel={0}
					ZIndex={z + 3}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>,
			);
		}
	} else {
		pips.push(
			<textlabel
				key="tier"
				Size={UDim2.fromOffset(20, 12)}
				Position={new UDim2(1, 0, 0, 0)}
				AnchorPoint={new Vector2(1, 0)}
				BackgroundColor3={look.color.Lerp(new Color3(), 0.7)}
				Text={tostring(tier)}
				TextColor3={look.color.Lerp(new Color3(1, 1, 1), 0.5)}
				TextScaled
				FontFace={Fonts.heavy}
				ZIndex={z + 3}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</textlabel>,
		);
	}
	return (
		<frame Size={UDim2.fromOffset(size, size)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ZIndex={z}>
			{lit > 0.05 && role !== "source" && <Glow size={size * (1 + lit * 0.5)} color={look.color} strength={0.4 + lit * 0.4} z={z} />}
			{props.picked === true && (
				<frame Size={UDim2.fromScale(1.08, 1.08)} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ZIndex={z + 4}>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uistroke Color={new Color3(1, 1, 1)} Thickness={2} />
				</frame>
			)}
			{core}
			{role !== "sink" && (
				<frame
					Size={new UDim2(0.32, 0, 0, 3)}
					Position={UDim2.fromScale(0.5 + math.cos(math.rad(faceAngle)) * 0.4, 0.5 + math.sin(math.rad(faceAngle)) * 0.4)}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={faceAngle}
					BackgroundColor3={look.color.Lerp(new Color3(1, 1, 1), 0.4)}
					BorderSizePixel={0}
					ZIndex={z + 3}
				/>
			)}
			{pips}
		</frame>
	);
}

function Board(props: { foundry: Foundry; flow: ReturnType<typeof FoundryMath.flow>; width: number; height: number; picked?: string; onCell: (key: string) => void }) {
	const { foundry, flow, width, height } = props;
	const spin = useClock(true, 1, 3600, true);
	const cells = foundry.Radius * 2 + 1;
	const size = math.floor(math.min(width / (1.5 * cells + 0.6), (height * 0.86) / (SQRT3 * cells + 0.2)));
	const mid = new Vector2(width / 2, height / 2);
	const kids: Record<string, React.Element> = {};
	kids.nebula = <Glow size={math.min(width, height) * 1.2} color={Color3.fromRGB(120, 60, 30)} strength={0.45} at={UDim2.fromOffset(mid.X, mid.Y)} z={0} />;
	for (let i = 1; i <= 30; i++) {
		const x = ((i * 0.6180339) % 1) * width;
		const y = ((i * 0.7548776) % 1) * height;
		kids[`star${i}`] = (
			<frame
				Size={UDim2.fromOffset(i % 4 === 0 ? 3 : 2, i % 4 === 0 ? 3 : 2)}
				Position={spin.map((t) => UDim2.fromOffset(x, (y + t * 3 * ((i % 3) + 1)) % height))}
				BackgroundColor3={new Color3(1, 1, 1)}
				BackgroundTransparency={spin.map((t) => 0.35 + 0.4 * math.abs(math.sin(t * 0.7 + i)))}
				BorderSizePixel={0}
				ZIndex={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}
	// orbit ring with a notch at the ignite target; the comet sweeps round on the server's clock
	const orbit = math.min(width, height) * 0.47;
	const target = FoundryMath.targetPhase({ Radius: foundry.Radius, Pieces: foundry.Pieces });
	kids.orbit = (
		<frame Size={UDim2.fromOffset(orbit * 2, orbit * 2)} Position={UDim2.fromOffset(mid.X, mid.Y)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} ZIndex={1}>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke Color={WARM} Thickness={1} Transparency={0.72} />
		</frame>
	);
	kids.notch = (
		<frame
			Size={UDim2.fromOffset(12, 12)}
			Position={UDim2.fromOffset(mid.X + math.cos(target * 2 * math.pi) * orbit, mid.Y + math.sin(target * 2 * math.pi) * orbit)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundColor3={WARM}
			ZIndex={2}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
	for (let i = 0; i <= 5; i++) {
		const lag = i * 0.012;
		kids[`comet${i}`] = (
			<frame
				Size={UDim2.fromOffset(10 - i, 10 - i)}
				Position={spin.map(() => {
					const angle = (FoundryMath.wavePhase(foundry.IgniteAt ?? 0, Workspace.GetServerTimeNow()) - lag) * 2 * math.pi;
					return UDim2.fromOffset(mid.X + math.cos(angle) * orbit, mid.Y + math.sin(angle) * orbit);
				})}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={i === 0 ? new Color3(1, 1, 1) : WARM}
				BackgroundTransparency={spin.map(() => {
					const hot = FoundryMath.onBeat(FoundryMath.wavePhase(foundry.IgniteAt ?? 0, Workspace.GetServerTimeNow()), target);
					return math.clamp((hot ? 0 : 0.15) + i * 0.15, 0, 1);
				})}
				BorderSizePixel={0}
				ZIndex={3}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>
		);
	}
	// beams: soft wide glow under a bright core, coloured from source to target
	for (let i = 0; i < math.min(80, flow.Links.size()); i++) {
		const link = flow.Links[i];
		const [q1, r1] = FoundryMath.parse(link.from);
		const [q2, r2] = FoundryMath.parse(link.to);
		if (q1 === undefined || q2 === undefined) continue;
		const a = mid.add(cellPoint(q1, r1!, size));
		const b = mid.add(cellPoint(q2, r2!, size));
		const d = b.sub(a);
		const strength = math.clamp(math.log10(1 + link.amount) / 4, 0.15, 1);
		const c1 = lookOf(foundry.Pieces[link.from]?.Kind ?? "Ember").color;
		const c2 = lookOf(foundry.Pieces[link.to]?.Kind ?? "Ember").color;
		const beam = (name: string, thick: number, fade: number, z: number) => (
			<frame
				key={`${name}${i}`}
				Size={UDim2.fromOffset(d.Magnitude, thick)}
				Position={UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={math.deg(math.atan2(d.Y, d.X))}
				BackgroundColor3={new Color3(1, 1, 1)}
				BackgroundTransparency={fade}
				BorderSizePixel={0}
				ZIndex={z}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uigradient Color={new ColorSequence(c1, c2)} Offset={spin.map((t) => new Vector2(((t * 0.6) % 1) * 0.3 - 0.15, 0))} />
			</frame>
		);
		kids[`glow${i}`] = beam("glow", math.max(5, size * 0.22 * strength + 4), 0.72, 2);
		kids[`core${i}`] = beam("core", math.max(2, size * 0.06 + strength * 2), 0.05, 3);
	}
	for (const key of FoundryMath.cells(foundry.Radius)) {
		const [q, r] = FoundryMath.parse(key);
		const p = mid.add(cellPoint(q!, r!, size));
		const piece = foundry.Pieces[key] as Piece | undefined;
		const aiming = props.picked !== undefined && props.picked !== key && piece === undefined;
		kids[`sock${key}`] = <Hex radius={size * 0.94} color={aiming ? WARM.Lerp(new Color3(), 0.55) : Color3.fromRGB(28, 26, 38)} transparency={piece ? 0.6 : 0.2} at={UDim2.fromOffset(p.X, p.Y)} z={1} />;
		kids[`cell${key}`] = (
			<textbutton
				Size={UDim2.fromOffset(size * 1.6, size * 1.6)}
				Position={UDim2.fromOffset(p.X, p.Y)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				Text=""
				Selectable
				ZIndex={5}
				Event={{ Activated: () => props.onCell(key) }}
			>
				{piece !== undefined && (
					<PieceArt piece={piece} size={math.floor(size * 1.25)} picked={props.picked === key} lit={math.clamp(math.log10(1 + (flow.Lit[key] ?? 0)) / 3, 0, 1)} spin={spin} z={5} />
				)}
			</textbutton>
		);
	}
	return (
		<frame Size={UDim2.fromOffset(width, height)} BackgroundColor3={Color3.fromRGB(8, 7, 14)} BorderSizePixel={0} ClipsDescendants>
			<uicorner CornerRadius={new UDim(0, Corner.panel)} />
			{kids}
		</frame>
	);
}

function Bonus(props: { label: string; value: string; color: Color3; phone: boolean; order: number; tip: string }) {
	const pop = useChangePop(props.value);
	const rise = useStagger(props.order + 1);
	return (
		<Tooltip tip={props.tip} size={new UDim2(props.phone ? 0.5 : 0.25, -8, 0, 58)} order={props.order}>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={props.color.Lerp(Iron.sunk(), 0.8)} BorderSizePixel={0} Position={rise.map((p) => UDim2.fromOffset(0, (1 - p) * 8))}>
				<uicorner CornerRadius={new UDim(0, Corner.card)} />
				<uistroke Color={props.color} Transparency={0.55} />
				<uiscale Scale={pop} />
				<uipadding PaddingLeft={new UDim(0, 10)} PaddingRight={new UDim(0, 10)} PaddingTop={new UDim(0, 6)} />
				<Text text={props.label} size={Type.small(props.phone)} color={props.color} box={new UDim2(1, 0, 0, 16)} />
				<Text text={props.value} size={20} font={Fonts.heavy} box={new UDim2(1, 0, 0, 24)} position={UDim2.fromOffset(0, 20)} />
			</frame>
		</Tooltip>
	);
}

interface FoundryReply {
	ok?: boolean;
	Sound?: string;
	Combo?: number;
	message?: string;
	error?: string;
}

export function FoundryPage(props: PageProps) {
	const phone = props.phone;
	const viewport = useViewport();
	const [picked, setPicked] = React.useState<string | undefined>(undefined);
	const [busy, setBusy] = React.useState(false);
	const [note, setNote] = React.useState("");
	const [combo, setCombo] = React.useState(0);
	const [ignites, setIgnites] = React.useState(0);
	const [boardW, setBoardW] = React.useState(math.max(260, viewport.width - (phone ? 28 : 320)));
	const igniteFlash = useFlash(ignites, false, 0.35);
	useBack(picked !== undefined, () => setPicked(undefined));
	React.useEffect(() => () => Juice.live("foundryIgnite", undefined), []);
	const raw = (props.session as unknown as { Foundry?: unknown }).Foundry;
	const space = gap(phone, "l");
	if (!typeIs(raw, "table")) {
		return (
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1}>
				<uipadding PaddingTop={new UDim(0, space)} PaddingLeft={new UDim(0, space)} PaddingRight={new UDim(0, space)} />
				<EmptyState title="Star Foundry" body="Warming up the board…" phone={phone} />
			</frame>
		);
	}
	const foundry = raw as Foundry;
	const act = (payload: Record<string, unknown>, quiet = false) => {
		const ignite = payload.Op === "ignite";
		if (busy && !ignite) return;
		if (!ignite) setBusy(true);
		props.request("FoundryAct", payload, (reply) => {
			setBusy(false);
			const r = reply as FoundryReply;
			if (r.ok === true) {
				Audio.play(r.Sound ?? "foundryPlace");
				if (r.Combo !== undefined || ignite) {
					const streak = r.Combo ?? 0;
					setCombo(streak);
					if (streak > 0) {
						Juice.live("foundryIgnite", {
							title: `Ignite ×${streak}`,
							icon: "Boost.11",
							color: WARM,
							endsAt: os.clock() + FoundryMath.IGNITE_PERIOD + 0.4,
							span: FoundryMath.IGNITE_PERIOD + 0.4,
							priority: 2,
						} as never);
						Burst.spark(WARM, 0.6 + math.min(streak, 10) * 0.05);
						if (streak >= FoundryMath.IGNITE_SURGE_AT) MotionFX.play("milestone");
					} else {
						Juice.live("foundryIgnite", undefined);
					}
				}
				if (r.message !== undefined && !quiet) setNote(r.message);
			} else {
				Audio.play("error");
				setNote(r.error ?? "That move didn't work.");
			}
		});
	};
	const onCell = (key: string) => {
		if (picked === undefined) {
			if (foundry.Pieces[key] !== undefined) {
				Audio.play("foundryPickUp");
				setPicked(key);
			}
			return;
		}
		if (picked === key) {
			if (!isBench(key)) act({ Op: "rotate", At: key }, true);
			else setPicked(undefined);
			return;
		}
		act({ Op: isBench(picked) ? "place" : "move", From: picked, To: key });
		setPicked(undefined);
	};
	const flow = FoundryMath.flow({ Radius: foundry.Radius, Pieces: foundry.Pieces });
	const fx = foundry.Effects ?? {};
	const surgeLeft = math.max(0, (foundry.SurgeEndsAt ?? 0) - Workspace.GetServerTimeNow());
	const dormant = (flow.Delivered ?? 0) <= 0;
	const benchFull = foundry.Bench.size() >= FoundryMath.BENCH_CAP;
	const canDraw = foundry.Shards >= (foundry.DrawCost ?? math.huge) && !benchFull;
	const canExpand = foundry.ExpandCost !== undefined && foundry.Shards >= foundry.ExpandCost;
	const boardH = phone ? math.min(boardW, 420) : 480;
	const boardPiece = picked !== undefined && !isBench(picked) ? foundry.Pieces[picked] : undefined;
	const benchPiece = isBench(picked) ? foundry.Bench[(tonumber(picked!.sub(7)) ?? 0) - 1] : undefined;
	const shown = boardPiece ?? benchPiece;
	const slot = phone ? math.clamp(math.floor((boardW - 5 * 6) / 6), HIT, 58) : 58;

	const igniteText = surgeLeft > 0 ? `Surge ${math.ceil(surgeLeft)}s · Ignite` : combo > 0 ? `Ignite ×${combo}` : "Ignite";
	const actions = (
		<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={3}>
			<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 10)} SortOrder={Enum.SortOrder.LayoutOrder} />
			<frame Size={UDim2.fromOffset(phone ? 150 : 200, 52)} BackgroundTransparency={1} LayoutOrder={0}>
				<uiscale Scale={igniteFlash.map((v) => 1 + v * 0.07)} />
				<Button
					text={igniteText}
					tone="ember"
					stretch
					height={52}
					textSize={19}
					onPress={() => {
						setIgnites((n) => n + 1);
						act({ Op: "ignite" }, true);
					}}
				/>
			</frame>
			<Button text={benchFull ? "Bench full" : `Draw · ${compactNumber(foundry.DrawCost ?? 0)}`} width={phone ? 150 : 180} height={52} disabled={!canDraw} busy={busy} onPress={() => act({ Op: "draw" })} order={1} />
			<Button
				text={foundry.ExpandCost === undefined ? "Full size" : `Expand · ${compactNumber(foundry.ExpandCost)}`}
				tone="iron"
				width={phone ? 150 : 180}
				height={52}
				disabled={!canExpand}
				busy={busy}
				onPress={() => {
					act({ Op: "expand" });
					MotionFX.play("success");
				}}
				order={2}
			/>
		</frame>
	);

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

			<Panel pad={gap(phone, "l")} spacing={gap(phone, "m")} seam={surgeLeft > 0} order={0}>
				<Title text="Star Foundry" size={Type.title(phone)} tags={surgeLeft > 0 ? ["rainbow", "wave"] : ["wave"]} order={0} />
				<Text
					text={`${compactNumber(foundry.Shards)} shards · ${dormant ? "dormant, turn an Ember toward an Anvil" : `+${"%.1f".format((foundry.ShardRate ?? 0) * 60)} a minute`}`}
					size={Type.body(phone)}
					color={dormant ? Iron.muted() : Iron.soft()}
					order={1}
				/>
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
					<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
					<Bonus label="Production" value={`×${compactNumber(fx.Production ?? 1)}`} color={LOOKS.ForgeAnvil.color} phone={phone} order={0} tip="From Forge Anvils." />
					<Bonus label="Tap" value={`×${compactNumber(fx.Tap ?? 1)}`} color={LOOKS.StrikeAnvil.color} phone={phone} order={1} tip="From Strike Anvils." />
					<Bonus label="Vault" value={`×${compactNumber(fx.Capacity ?? 1)}`} color={LOOKS.VaultAnvil.color} phone={phone} order={2} tip="From Vault Anvils." />
					<Bonus label="Offline" value={`+${math.floor((fx.Offline ?? 0) * 100 + 0.5)}%`} color={LOOKS.EchoAnvil.color} phone={phone} order={3} tip="From Echo Anvils." />
				</frame>
			</Panel>

			<frame
				Size={new UDim2(1, 0, 0, boardH)}
				BackgroundTransparency={1}
				LayoutOrder={1}
				Change={{
					AbsoluteSize: (f) => {
						const w = math.floor(f.AbsoluteSize.X);
						if (w > 0 && math.abs(w - boardW) > 2) setBoardW(w);
					},
				}}
			>
				<Board foundry={foundry} flow={flow} width={math.max(200, boardW)} height={boardH} picked={picked} onCell={onCell} />
			</frame>

			{shown !== undefined && (
				<Panel pad={gap(phone, "m")} spacing={8} order={2}>
					<Text text={`${lookOf(shown.Kind).name} · tier ${shown.Tier}`} size={Type.body(phone)} font={Fonts.heavy} color={lookOf(shown.Kind).color} order={0} />
					<Text text={isBench(picked) ? `${lookOf(shown.Kind).line} Pick a cell to place it.` : lookOf(shown.Kind).line} size={Type.small(phone)} color={Iron.muted()} multiline order={1} />
					<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={2}>
						<uilistlayout FillDirection={Enum.FillDirection.Horizontal} Wraps Padding={new UDim(0, 8)} SortOrder={Enum.SortOrder.LayoutOrder} />
						{boardPiece !== undefined && roleOf(boardPiece.Kind) !== "sink" && (
							<Button text="Turn left" tone="iron" width={110} onPress={() => act({ Op: "rotate", At: picked, Back: true }, true)} order={0} />
						)}
						{boardPiece !== undefined && roleOf(boardPiece.Kind) !== "sink" && (
							<Button text="Turn right" tone="iron" width={110} onPress={() => act({ Op: "rotate", At: picked }, true)} order={1} />
						)}
						{boardPiece !== undefined && (
							<Button
								text="To bench"
								tone="iron"
								width={110}
								disabled={benchFull}
								onPress={() => {
									act({ Op: "store", From: picked }, true);
									setPicked(undefined);
								}}
								order={2}
							/>
						)}
						<Button text="Done" tone="quiet" width={90} onPress={() => setPicked(undefined)} order={3} />
					</frame>
				</Panel>
			)}

			{actions}

			<Panel pad={gap(phone, "m")} spacing={8} order={4} color={Iron.sunk()}>
				<Text text={`Bench ${foundry.Bench.size()}/${FoundryMath.BENCH_CAP}`} size={Type.small(phone)} color={Iron.muted()} order={0} />
				<frame Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={1}>
					<uigridlayout CellSize={UDim2.fromOffset(slot, slot)} CellPadding={UDim2.fromOffset(6, 6)} SortOrder={Enum.SortOrder.LayoutOrder} />
					{(() => {
						const slots: React.Element[] = [];
						for (let i = 1; i <= FoundryMath.BENCH_CAP; i++) {
							const piece = foundry.Bench[i - 1] as Piece | undefined;
							const key = `bench:${i}`;
							slots.push(
								<textbutton
									key={key}
									Text=""
									LayoutOrder={i}
									AutoButtonColor={false}
									BackgroundColor3={picked === key ? Iron.raised() : Iron.face()}
									Selectable
									Event={{
										Activated: () => {
											if (piece === undefined) {
												if (picked !== undefined && !isBench(picked)) {
													act({ Op: "store", From: picked }, true);
													setPicked(undefined);
												}
												return;
											}
											Audio.play("foundryPickUp");
											setPicked(picked === key ? undefined : key);
										},
									}}
								>
									<uicorner CornerRadius={new UDim(0, Corner.card)} />
									<uistroke Color={piece !== undefined ? lookOf(piece.Kind).color : Iron.edge()} Transparency={picked === key ? 0 : 0.6} />
									{piece !== undefined && <PieceArt piece={piece} size={math.floor(slot * 0.8)} picked={picked === key} z={2} />}
								</textbutton>,
							);
						}
						return slots;
					})()}
				</frame>
			</Panel>

			{note !== "" && <Text text={note} size={Type.small(phone)} color={Iron.soft()} multiline order={5} />}
		</scrollingframe>
	);
}
