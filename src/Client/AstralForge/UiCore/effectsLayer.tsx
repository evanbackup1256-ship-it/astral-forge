// UiCore effects layer. Depth, rims and noise are built in code (no baked images).
// Motion reuses MotionKit (useHoverPress, useFlipperSpring, motionTokens) unchanged.
// Rarity shimmer reuses RainbowGradient / PrismAura / ShimmerText exactly as they are.
import React from "@rbxts/react";
const AssetService = game.GetService("AssetService");
import { Palette, Radius } from "../CoreKit/theme";
import { Rarity } from "../../../Shared/AstralForge/Shared/ForgeTheme";
import { useFlipperSpring, useHoverPress, useMotionSettings } from "../MotionKit/motion";
import { DURATION, SPRING } from "../MotionKit/motionTokens";
import * as PageTransition from "../MotionKit/pageTransition";

export { RainbowGradient } from "./rainbowFx";
export { PrismAura, isAscended } from "./prismFx";
export { ShimmerText, ButtonShimmer } from "./ui";

/** Design-system tokens (design/system/af.css). */
export const FxTokens = table.freeze({
	brass: Color3.fromHex("FABE48"),
	ink: Color3.fromHex("0C090E"),
	void: Color3.fromHex("08060A"),
	line: Color3.fromHex("4A3A50"),
	radiusCard: Radius.lg,
	radiusPanel: Radius.sheet,
	rimThickness: 1.5,
	innerRule: 1,
	selectedLift: 4,
	panelRise: 8,
	panelFade: 0.12,
});

export type RarityName = keyof typeof Rarity;

export function rarityColor(rarity: string | undefined): Color3 {
	const palette = Rarity as unknown as Record<string, Color3>;
	return (rarity !== undefined && palette[rarity]) || Rarity.Common;
}

// ---------------------------------------------------------------- Shadow / Glow
export interface DepthProps {
	/** corner radius in px; defaults to the card radius (14) */
	corner?: number;
	/** number of stacked layers (1..6), default 3 */
	layers?: number;
	/** px each layer grows by, default 2 */
	spread?: number;
	/** transparency of the innermost layer, default 0.7 (shadow) / 0.82 (glow) */
	strength?: number;
	/** glow colour; omitted = ink shadow offset downward */
	color?: Color3;
	/** shadow drop in px, default 3 (ignored for glow) */
	offsetY?: number;
	zIndex?: number;
}

function Stack(props: DepthProps & { glow: boolean }) {
	const layers = math.clamp(props.layers ?? 3, 1, 6);
	const spread = props.spread ?? 2;
	const corner = props.corner ?? FxTokens.radiusCard;
	const base = props.strength ?? (props.glow ? 0.82 : 0.7);
	const color = props.color ?? FxTokens.void;
	const dy = props.glow ? 0 : props.offsetY ?? 3;
	const children: React.Element[] = [];
	for (let i = 1; i <= layers; i++) {
		const grow = i * spread;
		const t = 1 - (1 - base) * ((layers - i + 1) / layers);
		children.push(
			<frame
				key={`l${i}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={new UDim2(0.5, 0, 0.5, dy)}
				Size={new UDim2(1, grow * 2, 1, grow * 2)}
				BackgroundColor3={color}
				BackgroundTransparency={props.glow ? 1 : t}
				BorderSizePixel={0}
				ZIndex={props.zIndex ?? 0}
			>
				<uicorner CornerRadius={new UDim(0, corner + grow)} />
				{props.glow ? (
					<uistroke Color={color} Thickness={1} Transparency={t} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
				) : undefined}
			</frame>,
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={props.zIndex ?? 0}>
			{children}
		</frame>
	);
}

/** Soft drop shadow behind a card/panel. Place as a sibling under the same parent, lower ZIndex. */
export function Shadow(props: DepthProps) {
	return <Stack {...props} glow={false} />;
}

/** Thin halo of stacked strokes (rim light, not a blob). Use for selected/focused states only. */
export function Glow(props: DepthProps) {
	return <Stack {...props} glow={true} layers={props.layers ?? 2} />;
}

export interface RarityRimProps {
	rarity?: string;
	corner?: number;
	/** selected cards: rim at alpha 1 */
	selected?: boolean;
}

/** Rarity rim: 1.5px rarity UIStroke + 1px brass inner rule with a vertical UIGradient. */
export function RarityRim(props: RarityRimProps) {
	const c = rarityColor(props.rarity);
	const corner = props.corner ?? FxTokens.radiusCard;
	return (
		<React.Fragment>
			<uistroke
				Color={c}
				Thickness={FxTokens.rimThickness}
				Transparency={props.selected ? 0 : 0.25}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			/>
			<frame
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={UDim2.fromScale(0.5, 0.5)}
				Size={new UDim2(1, -6, 1, -6)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(0, math.max(corner - 3, 0))} />
				<uistroke Color={FxTokens.brass} Thickness={FxTokens.innerRule} Transparency={0.55}>
					<uigradient
						Rotation={90}
						Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.7)])}
					/>
				</uistroke>
			</frame>
		</React.Fragment>
	);
}

// ---------------------------------------------------------------- Noise (EditableImage)
function hash(x: number, y: number, seed: number): number {
	let h = (x * 374761393 + y * 668265263 + seed * 2147483647) % 4294967296;
	h = ((h ^ (h >>> 13)) * 1274126177) % 4294967296;
	return ((h ^ (h >>> 16)) % 65536) / 65535;
}

function valueNoise(x: number, y: number, seed: number): number {
	const xi = math.floor(x);
	const yi = math.floor(y);
	const fx = x - xi;
	const fy = y - yi;
	const u = fx * fx * (3 - 2 * fx);
	const v = fy * fy * (3 - 2 * fy);
	const a = hash(xi, yi, seed);
	const b = hash(xi + 1, yi, seed);
	const c = hash(xi, yi + 1, seed);
	const d = hash(xi + 1, yi + 1, seed);
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}

const noiseCache = new Map<string, EditableImage | false>();

function makeImage(key: string, size: number, pixel: (x: number, y: number) => [number, number, number, number]) {
	const cached = noiseCache.get(key);
	if (cached !== undefined) return cached === false ? undefined : cached;
	const [ok, image] = pcall(() =>
		AssetService.CreateEditableImage({ Size: new Vector2(size, size) }),
	);
	if (!ok || image === undefined) {
		noiseCache.set(key, false);
		return undefined;
	}
	const buf = buffer.create(size * size * 4);
	for (let y = 0; y < size; y++) {
		for (let x = 0; x < size; x++) {
			const [r, g, b, a] = pixel(x, y);
			const o = (y * size + x) * 4;
			buffer.writeu8(buf, o, r);
			buffer.writeu8(buf, o + 1, g);
			buffer.writeu8(buf, o + 2, b);
			buffer.writeu8(buf, o + 3, a);
		}
	}
	image.WritePixelsBuffer(Vector2.zero, new Vector2(size, size), buf);
	noiseCache.set(key, image);
	return image;
}

/** White film grain (alpha ~7%, matches --grain in af.css). Tiled 128px, cached per seed. */
export function grainImage(seed = 1, size = 128): EditableImage | undefined {
	return makeImage(`grain:${seed}:${size}`, size, (x, y) => {
		const n = hash(x, y, seed);
		return [255, 255, 255, math.floor(n * 18)];
	});
}

/** Nebula: 4-octave value noise tinted between two colours. Cached per seed/colours. */
export function nebulaImage(seed = 7, tintA = FxTokens.ink, tintB = Color3.fromHex("271F2A"), size = 128): EditableImage | undefined {
	return makeImage(`neb:${seed}:${tintA.ToHex()}:${tintB.ToHex()}:${size}`, size, (x, y) => {
		let n = 0;
		let amp = 0.5;
		let freq = 4 / size;
		for (let o = 0; o < 4; o++) {
			n += valueNoise(x * freq, y * freq, seed + o) * amp;
			amp *= 0.5;
			freq *= 2;
		}
		const c = tintA.Lerp(tintB, math.clamp(n * 1.3 - 0.15, 0, 1));
		return [math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), math.floor(60 + n * 120)];
	});
}

export interface NoiseProps {
	kind: "grain" | "nebula";
	seed?: number;
	/** tile size in px for grain (default 128); nebula stretches */
	tile?: number;
	transparency?: number;
	zIndex?: number;
	corner?: number;
}

/** Full-size overlay of grain or nebula noise; renders nothing if EditableImage is unavailable. */
export function Noise(props: NoiseProps) {
	const image = React.useMemo(
		() => (props.kind === "grain" ? grainImage(props.seed) : nebulaImage(props.seed)),
		[props.kind, props.seed],
	);
	if (image === undefined) return undefined;
	const tile = props.tile ?? 128;
	return (
		<imagelabel
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			ImageContent={Content.fromObject(image)}
			ImageTransparency={props.transparency ?? 0}
			ScaleType={props.kind === "grain" ? Enum.ScaleType.Tile : Enum.ScaleType.Stretch}
			TileSize={UDim2.fromOffset(tile, tile)}
			ZIndex={props.zIndex ?? 1}
			Active={false}
		>
			{props.corner !== undefined ? <uicorner CornerRadius={new UDim(0, props.corner)} /> : undefined}
		</imagelabel>
	);
}

// ---------------------------------------------------------------- Motion (MotionKit, unchanged feel)
/**
 * Button hover/press: thin wrapper over MotionKit useHoverPress (flipper spring 620/30,
 * lift 0.035, dip 0.05, halved under soft/reduced motion). Returns [scale, events, hovered].
 */
export function useButtonMotion(reducedMotion = false) {
	return useHoverPress(reducedMotion);
}

/** <uiscale> driven by useButtonMotion; spread `events` on the button as Event={...}. */
export function ButtonMotionScale(props: { scale: React.Binding<number> }) {
	return <uiscale Scale={props.scale} />;
}

/**
 * Panel open/close spring (0 closed .. 1 open) on MotionKit useFlipperSpring with the
 * SPRING.smooth token. Reduced motion snaps. Pair with panelStyle() for fade + 8px rise.
 */
export function usePanelSpring(open: boolean, reducedMotion = false): React.Binding<number> {
	const soft = useMotionSettings().soft === true || reducedMotion;
	return useFlipperSpring(open ? 1 : 0, soft, SPRING.smooth.stiffness, SPRING.smooth.damping, 0);
}

/** Maps a panel spring to CanvasGroup props: GroupTransparency and an 8px rise. */
export function panelStyle(amount: React.Binding<number>, basePosition = UDim2.fromScale(0.5, 0.5)) {
	return {
		GroupTransparency: amount.map((a) => 1 - math.clamp(a, 0, 1)),
		Position: amount.map((a) => basePosition.add(UDim2.fromOffset(0, (1 - math.clamp(a, 0, 1)) * FxTokens.panelRise))),
	};
}

export const PANEL_TIMING = table.freeze({
	enter: PageTransition.ENTER_SECONDS,
	standard: DURATION.standard,
});
