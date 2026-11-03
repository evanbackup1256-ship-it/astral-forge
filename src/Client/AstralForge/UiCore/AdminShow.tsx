import { clamp01, easeOut } from "../CoreKit/easing";
// Admin "show" effects: the screen effects staff can play on a player (or everyone in a server) that are about
// atmosphere rather than pranks: fireworks, aurora ribbons, shooting stars, code rain, a signal glitch, a
// heartbeat vignette, snowfall and a cinematic letterbox. They never take input (nothing here is Active), ease
// in and out over their duration, and thin themselves out as the antilag tier drops.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { useClock } from "../MotionKit/motion";
import type { Prank } from "./AdminPrankOverlay";

const TAU = math.pi * 2;

export const SHOW_KINDS: Record<string, boolean | undefined> = {
	Fireworks: true,
	Aurora: true,
	Starfall: true,
	MatrixRain: true,
	Glitch: true,
	Heartbeat: true,
	Snowfall: true,
	Letterbox: true,
};

// the same pseudo-random number for the same inputs, so an effect looks the same every frame it is drawn
function hash01(a: number, b: number): number {
	const x = math.sin(a * 127.1 + b * 311.7) * 43758.5453;
	return x - math.floor(x);
}


interface FxProps {
	/** seconds since the effect started */
	t: React.Binding<number>;
	/** 0..1 fade in and out over the effect's life */
	env: React.Binding<number>;
	/** 0.25..1: how much of the effect this machine can afford */
	scale: number;
	duration: number;
	caption: string;
	/** pixel multiplier: 1 on a real screen, smaller in the Show Room thumbnails */
	unit: number;
}

const SPARK_COLORS = [Palette.mango, Palette.pink, Palette.cyan, Palette.violet, Palette.mint, Palette.cream];

// ── Fireworks ──────────────────────────────────────────────────────────────────

function Fireworks(props: FxProps) {
	const bursts = math.clamp(math.floor(5 * props.scale + 0.5), 2, 5);
	const sparks = math.clamp(math.floor(18 * props.scale + 0.5), 7, 18);
	const cycle = 2.2;
	const children: React.Element[] = [];
	for (let b = 0; b < bursts; b++) {
		const delay = b * 0.55;
		const ox = 0.14 + hash01(b, 1) * 0.72;
		const oy = 0.1 + hash01(b, 2) * 0.38;
		const color = SPARK_COLORS[b % SPARK_COLORS.size()];
		const age = (sec: number) => {
			const since = sec - delay;
			return since < 0 ? -1 : since % cycle;
		};
		// a ring pulses out from the burst point as the sparks leave it
		children.push(
			<frame
				key={`ring${b}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={new UDim2(ox, 0, oy, 0)}
				Size={props.t.map((sec) => {
					const a = age(sec);
					const d = a < 0 ? 0 : (20 + easeOut(a / 0.6) * 150) * props.unit;
					return UDim2.fromOffset(d, d);
				})}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				<uistroke
					Color={color}
					Thickness={2}
					Transparency={props.t.map((sec) => {
						const a = age(sec);
						return a < 0 || a > 0.6 ? 1 : 0.2 + (a / 0.6) * 0.8;
					})}
				/>
			</frame>,
		);
		for (let s = 0; s < sparks; s++) {
			const angle = (s / sparks) * TAU + hash01(b, s) * 0.35;
			const speed = 120 + hash01(b, s + 40) * 120;
			const size = math.max(3, math.floor((4 + hash01(b, s + 80) * 3) * props.unit + 0.5));
			children.push(
				<frame
					key={`spark${b}_${s}`}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Size={UDim2.fromOffset(size, size)}
					BackgroundColor3={s % 5 === 0 ? Palette.cream : color}
					BorderSizePixel={0}
					Position={props.t.map((sec) => {
						const a = math.max(age(sec), 0);
						return new UDim2(ox, math.cos(angle) * speed * a * props.unit, oy, (math.sin(angle) * speed * a + 150 * a * a) * props.unit);
					})}
					BackgroundTransparency={props.t.map((sec) => {
						const a = age(sec);
						return a < 0 ? 1 : 1 - clamp01(1 - a / 1.6) * 0.95;
					})}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
				</frame>,
			);
		}
	}
	return <React.Fragment>{children}</React.Fragment>;
}

// ── Aurora ─────────────────────────────────────────────────────────────────────

const AURORA_BANDS: Array<{ from: Color3; to: Color3; y: number; h: number; speed: number }> = [
	{ from: Palette.mint, to: Palette.cyan, y: 0.04, h: 150, speed: 0.31 },
	{ from: Palette.cyan, to: Palette.violet, y: 0.12, h: 190, speed: 0.23 },
	{ from: Palette.violet, to: Palette.pink, y: 0.2, h: 130, speed: 0.37 },
	{ from: Palette.mint, to: Palette.violet, y: 0.27, h: 110, speed: 0.19 },
];

function Aurora(props: FxProps) {
	const count = props.scale < 0.5 ? 2 : AURORA_BANDS.size();
	const bands: React.Element[] = [];
	for (let i = 0; i < count; i++) {
		const band = AURORA_BANDS[i];
		bands.push(
			<frame
				key={`band${i}`}
				AnchorPoint={new Vector2(0.5, 0)}
				Size={new UDim2(1.3, 0, 0, band.h)}
				BackgroundColor3={Color3.fromRGB(255, 255, 255)}
				BorderSizePixel={0}
				// the band breathes: its strength drifts a little, so the ribbons shimmer instead of sitting still
				BackgroundTransparency={React.joinBindings({ t: props.t, e: props.env }).map(({ t, e }) => 1 - e * (0.5 + 0.12 * math.sin(t * band.speed * 3 + i * 1.7)))}
				Position={props.t.map((sec) => new UDim2(0.5 + math.sin(sec * band.speed + i) * 0.05, 0, band.y + math.sin(sec * band.speed * 1.7 + i * 2) * 0.025, 0))}
				Rotation={props.t.map((sec) => math.sin(sec * band.speed + i * 1.3) * 5 - 4)}
			>
				<uigradient
					// the band is wider than the screen, so only the top and bottom edges need softening
					Rotation={90}
					Color={new ColorSequence([new ColorSequenceKeypoint(0, band.to), new ColorSequenceKeypoint(1, band.from)])}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.35, 0.55),
							new NumberSequenceKeypoint(0.6, 0.3),
							new NumberSequenceKeypoint(1, 1),
						])
					}
				/>
			</frame>,
		);
	}
	return <React.Fragment>{bands}</React.Fragment>;
}

// ── Starfall ───────────────────────────────────────────────────────────────────

function Starfall(props: FxProps) {
	const streaks = math.clamp(math.floor(11 * props.scale + 0.5), 4, 11);
	const children: React.Element[] = [];
	for (let i = 0; i < streaks; i++) {
		const delay = hash01(i, 3) * 2.5;
		const cycle = 1.7 + hash01(i, 4) * 1.5;
		const x0 = hash01(i, 5) * 0.8 - 0.1;
		const slope = 0.45 + hash01(i, 6) * 0.2;
		const length = 50 + hash01(i, 7) * 70;
		const flight = 0.9;
		const progress = (sec: number) => {
			const since = sec - delay;
			if (since < 0) {
				return -1;
			}
			const within = since % cycle;
			return within > flight ? -1 : within / flight;
		};
		children.push(
			<frame
				key={`star${i}`}
				AnchorPoint={new Vector2(1, 0.5)}
				Size={UDim2.fromOffset(length, 3)}
				BackgroundColor3={Palette.cream}
				BorderSizePixel={0}
				Rotation={math.deg(math.atan2(1, slope))}
				Position={props.t.map((sec) => {
					const p = math.max(progress(sec), 0);
					return new UDim2(x0 + p * slope * 0.9, 0, -0.05 + p * 1.1, 0);
				})}
				BackgroundTransparency={props.t.map((sec) => (progress(sec) < 0 ? 1 : 0.05))}
			>
				<uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(1, 0)])} />
			</frame>,
		);
	}
	return <React.Fragment>{children}</React.Fragment>;
}

// ── Code rain ──────────────────────────────────────────────────────────────────

const GLYPHS = "01ABCDEFGHJKLMNPRSTUVWXYZ23456789";

function glyphColumn(seed: number, rows: number): string {
	const out: string[] = [];
	for (let r = 0; r < rows; r++) {
		const index = math.floor(hash01(seed, r) * GLYPHS.size()) + 1;
		out.push(GLYPHS.sub(index, index));
	}
	return out.join("\n");
}

function MatrixRain(props: FxProps) {
	const columns = math.clamp(math.floor(24 * props.scale + 0.5), 6, 24);
	const rows = 15;
	const children: React.Element[] = [
		<frame key="dim" Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BorderSizePixel={0} BackgroundTransparency={props.env.map((e) => 1 - e * 0.42)} />,
	];
	for (let c = 0; c < columns; c++) {
		const speed = 0.22 + hash01(c, 1) * 0.3;
		const offset = hash01(c, 2) * 1.4;
		const text = glyphColumn(c + 1, rows);
		children.push(
			<textlabel
				key={`col${c}`}
				Size={UDim2.fromOffset(20, rows * 15)}
				BackgroundTransparency={1}
				Text={text}
				TextSize={14}
				Font={Enum.Font.Code}
				TextColor3={c % 6 === 0 ? Palette.cream : Palette.mint}
				TextYAlignment={Enum.TextYAlignment.Top}
				TextTransparency={props.env.map((e) => 1 - e)}
				Position={props.t.map((sec) => new UDim2((c + 0.5) / columns, -10, ((sec * speed + offset) % 1.35) - 0.3, 0))}
			>
				<uigradient
					Rotation={90}
					Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.65, 0.5), new NumberSequenceKeypoint(1, 0)])}
				/>
			</textlabel>,
		);
	}
	return <React.Fragment>{children}</React.Fragment>;
}

// ── Glitch ─────────────────────────────────────────────────────────────────────

function Glitch(props: FxProps) {
	const slices = math.clamp(math.floor(10 * props.scale + 0.5), 4, 10);
	const children: React.Element[] = [
		<frame
			key="flash"
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.pink}
			BorderSizePixel={0}
			BackgroundTransparency={props.t.map((sec) => {
				// a short full-screen flash about once a second
				const beat = (sec * 0.9) % 1;
				return beat < 0.07 ? 0.78 : 1;
			})}
		/>,
	];
	for (let i = 0; i < slices; i++) {
		const stepAt = (sec: number) => math.floor(sec * 9);
		const cyan = i % 2 === 0;
		children.push(
			<frame
				key={`slice${i}`}
				BackgroundColor3={cyan ? Palette.cyan : Palette.pink}
				BorderSizePixel={0}
				Size={props.t.map((sec) => {
					const step = stepAt(sec);
					return new UDim2(0.25 + hash01(i, step) * 0.75, 0, 0, 5 + math.floor(hash01(i, step + 9) * 36));
				})}
				Position={props.t.map((sec) => {
					const step = stepAt(sec);
					return new UDim2(hash01(i, step + 17) * 0.4, 0, hash01(i, step + 31), 0);
				})}
				BackgroundTransparency={props.t.map((sec) => (hash01(i, stepAt(sec) + 53) < 0.5 ? 0.62 : 1))}
			/>,
		);
	}
	return <React.Fragment>{children}</React.Fragment>;
}

// ── Heartbeat ──────────────────────────────────────────────────────────────────

function beat(sec: number): number {
	// lub-dub at about 66 beats a minute
	const p = (sec * 1.1) % 1;
	return math.exp(-(((p - 0.02) / 0.07) ** 2)) + 0.7 * math.exp(-(((p - 0.27) / 0.06) ** 2));
}

function Heartbeat(props: FxProps) {
	const edges: Array<{ key: string; size: UDim2; position: UDim2; anchor: Vector2; rotation: number }> = [
		{ key: "l", size: new UDim2(0.26, 0, 1, 0), position: UDim2.fromScale(0, 0), anchor: new Vector2(0, 0), rotation: 0 },
		{ key: "r", size: new UDim2(0.26, 0, 1, 0), position: UDim2.fromScale(1, 0), anchor: new Vector2(1, 0), rotation: 180 },
		{ key: "t", size: new UDim2(1, 0, 0.3, 0), position: UDim2.fromScale(0, 0), anchor: new Vector2(0, 0), rotation: 90 },
		{ key: "b", size: new UDim2(1, 0, 0.3, 0), position: UDim2.fromScale(0, 1), anchor: new Vector2(0, 1), rotation: 270 },
	];
	return (
		<React.Fragment>
			{edges.map((edge) => (
				<frame
					key={edge.key}
					Size={edge.size}
					Position={edge.position}
					AnchorPoint={edge.anchor}
					BackgroundColor3={Palette.coral}
					BorderSizePixel={0}
					BackgroundTransparency={React.joinBindings({ t: props.t, e: props.env }).map(({ t, e }) => 1 - e * (0.1 + 0.62 * clamp01(beat(t))))}
				>
					<uigradient Rotation={edge.rotation} Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0.1), new NumberSequenceKeypoint(1, 1)])} />
				</frame>
			))}
		</React.Fragment>
	);
}

// ── Snowfall ───────────────────────────────────────────────────────────────────

function Snowfall(props: FxProps) {
	const flakes = math.clamp(math.floor(46 * props.scale + 0.5), 12, 46);
	const children: React.Element[] = [];
	for (let i = 0; i < flakes; i++) {
		const size = 3 + math.floor(hash01(i, 1) * 4);
		const speed = 0.12 + hash01(i, 2) * 0.16;
		const offset = hash01(i, 3);
		const base = hash01(i, 4);
		const sway = 0.01 + hash01(i, 5) * 0.025;
		const rate = 0.8 + hash01(i, 6) * 1.2;
		children.push(
			<frame
				key={`flake${i}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(size, size)}
				BackgroundColor3={Palette.cream}
				BorderSizePixel={0}
				BackgroundTransparency={props.env.map((e) => 1 - e * (0.4 + hash01(i, 7) * 0.4))}
				Position={props.t.map((sec) => new UDim2(base + math.sin(sec * rate + i) * sway, 0, ((sec * speed + offset) % 1.1) - 0.05, 0))}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	return <React.Fragment>{children}</React.Fragment>;
}

// ── Letterbox ──────────────────────────────────────────────────────────────────

const BAR = 0.13;

function Letterbox(props: FxProps) {
	const slide = props.t.map((sec) => math.min(easeOut(sec / 0.7), easeOut((props.duration - sec) / 0.7)));
	// the caption is tracked out by hand: Roblox text has no letter spacing
	const upper = string.upper(props.caption);
	const letters: string[] = [];
	for (let i = 1; i <= upper.size(); i++) {
		letters.push(upper.sub(i, i));
	}
	const spaced = letters.join(" ");
	return (
		<React.Fragment>
			<frame Size={new UDim2(1, 0, BAR, 0)} BackgroundColor3={Color3.fromRGB(0, 0, 0)} BorderSizePixel={0} Position={slide.map((s) => new UDim2(0, 0, -BAR * (1 - s), 0))}>
				<frame Size={new UDim2(1, 0, 0, 1)} Position={UDim2.fromScale(0, 1)} AnchorPoint={new Vector2(0, 1)} BackgroundColor3={Palette.brass} BackgroundTransparency={0.55} BorderSizePixel={0} />
			</frame>
			<frame
				Size={new UDim2(1, 0, BAR, 0)}
				AnchorPoint={new Vector2(0, 1)}
				BackgroundColor3={Color3.fromRGB(0, 0, 0)}
				BorderSizePixel={0}
				Position={slide.map((s) => new UDim2(0, 0, 1 + BAR * (1 - s), 0))}
			>
				<frame Size={new UDim2(1, 0, 0, 1)} BackgroundColor3={Palette.brass} BackgroundTransparency={0.55} BorderSizePixel={0} />
				{props.unit >= 1 && (
					<textlabel
						Size={UDim2.fromScale(1, 1)}
						BackgroundTransparency={1}
						Text={spaced}
						TextScaled={true}
						FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
						TextColor3={Palette.cream}
						TextTransparency={slide.map((s) => 1 - s)}
					>
						<uitextsizeconstraint MinTextSize={8} MaxTextSize={20} />
						<uipadding PaddingLeft={new UDim(0, 24)} PaddingRight={new UDim(0, 24)} PaddingTop={new UDim(0, 10)} PaddingBottom={new UDim(0, 10)} />
					</textlabel>
				)}
			</frame>
		</React.Fragment>
	);
}

// ── Overlay ────────────────────────────────────────────────────────────────────

export function AdminShowOverlay(props: { prank: Prank; onClose: () => void }) {
	const prank = props.prank;
	const antilag = useAntilag();
	const duration = typeIs(prank.duration, "number") ? prank.duration : math.max(2, prank.endsAt - os.clock());
	const t = useClock(true, 1, 100000, true);
	const env = t.map((sec) => clamp01(math.min(sec / 0.6, (duration - sec) / 0.8)));
	React.useEffect(() => {
		const worker = task.spawn(() => {
			while (os.clock() < prank.endsAt) {
				task.wait(0.2);
			}
			props.onClose();
		});
		return () => task.cancel(worker);
	}, [prank.endsAt, prank.kind]);
	const scale = antilag.allowAmbient ? math.clamp(antilag.fxBudget / 0.8, 0.3, 1) : 0.25;
	const caption = prank.caption !== undefined && prank.caption !== "" ? prank.caption : "ACT ONE";
	const fx: FxProps = { t, env, scale, duration, caption, unit: 1 };
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			Active={false}
			ClipsDescendants={true}
			ZIndex={415}
			ref={(host: Frame | undefined) => {
				// decoration: the layout guard has nothing to repair in it
				if (host !== undefined) {
					host.SetAttribute("LayoutGuardIgnore", true);
				}
			}}
		>
			<ShowEffect kind={prank.kind} fx={fx} />
		</frame>
	);
}

function ShowEffect(props: { kind: string; fx: FxProps }) {
	const kind = props.kind;
	return (
		<React.Fragment>
			{kind === "Fireworks" && <Fireworks {...props.fx} />}
			{kind === "Aurora" && <Aurora {...props.fx} />}
			{kind === "Starfall" && <Starfall {...props.fx} />}
			{kind === "MatrixRain" && <MatrixRain {...props.fx} />}
			{kind === "Glitch" && <Glitch {...props.fx} />}
			{kind === "Heartbeat" && <Heartbeat {...props.fx} />}
			{kind === "Snowfall" && <Snowfall {...props.fx} />}
			{kind === "Letterbox" && <Letterbox {...props.fx} />}
		</React.Fragment>
	);
}

/** A small stage for the Show Room: holds a poster frame until `live`, then plays the effect on a loop. */
export function ShowPreview(props: { kind: string; live: boolean }) {
	const antilag = useAntilag();
	const clock = useClock(props.live && antilag.allowAmbient, 1, 100000, true);
	// the clock rests at 0, which is a blank stage for most effects; offset it to a frame with something in it
	const t = React.useMemo(() => clock.map((sec) => sec + 1.2), [clock]);
	const env = React.useMemo(() => t.map(() => 1), [t]);
	const fx: FxProps = { t, env, scale: 0.4, duration: 100000, caption: "", unit: 0.45 };
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			BackgroundColor3={Palette.void}
			BorderSizePixel={0}
			ClipsDescendants={true}
			ref={(host: Frame | undefined) => {
				if (host !== undefined) {
					host.SetAttribute("LayoutGuardIgnore", true);
				}
			}}
		>
			<uicorner CornerRadius={new UDim(0, 8)} />
			<ShowEffect kind={props.kind} fx={fx} />
		</frame>
	);
}
