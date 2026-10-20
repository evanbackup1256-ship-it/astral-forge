import React from "@rbxts/react";
import { useAntilag } from "../MotionKit/antilag";
import { useClock, useFlash } from "../MotionKit/motion";
import { EASE } from "../MotionKit/motionTokens";
import * as Fx from "../MotionKit/vfxMath";
import { darken, lighten, Palette, surfaceGradient } from "../CoreKit/theme";
import { Text } from "../UiCore/ui";

type SparkData = { id: number; kind: string; x: number; y: number; color: Color3 };
type PopData = { id: number; text: string; x: number; y: number; color: Color3; critical?: boolean };
type Station = { x: number; y: number; color: Color3; live: boolean };
const clamp01 = (value: number) => math.clamp(value, 0, 1);
function tail<T extends defined>(values: T[], count: number): T[] {
	const result: T[] = [];
	for (let index = math.max(0, values.size() - count); index < values.size(); index++) result.push(values[index]);
	return result;
}

export function ShockRing({ trigger, color, reducedMotion, size = 280 }: { trigger: number; color: Color3; reducedMotion: boolean; size?: number }) {
	const clock = useClock(trigger > 0 && !reducedMotion, 1, 1000, true);
	const rings: React.Element[] = [];
	for (let ring = 0; ring <= 2; ring++) {
		const delay = ring * 0.05;
		rings.push(<frame key={ring} Size={clock.map((seconds) => { const grow = Fx.ring(seconds - delay, 0.55)[0]; const d = 24 + grow * (size * 0.95 + ring * 26); return UDim2.fromOffset(d, d); })} Position={UDim2.fromScale(0.5, 0.5)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={81}><uicorner CornerRadius={new UDim(1, 0)} /><uistroke Color={ring === 1 ? Palette.cream : lighten(color, ring === 0 ? 0.25 : 0)} Thickness={ring === 0 ? 3 : 2} Transparency={clock.map((seconds) => 0.05 + Fx.ring(seconds - delay, 0.55)[2] * 0.95)} /></frame>);
	}
	return <frame key={`shock-${trigger}`} Size={UDim2.fromOffset(size, size)} Position={UDim2.fromScale(0.5, 0.54)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={80} Active={false}>{rings}</frame>;
}

function Spark({ spark, reducedMotion }: { spark: SparkData; reducedMotion: boolean }) {
	const clock = useClock(true, 1, 1000, true);
	const power = spark.kind === "perfect" ? 1.35 : spark.kind === "bank" ? 1.1 : 0.85;
	const angle = -math.pi / 2 + (Fx.hash(spark.id, 1) - 0.5) * math.rad(150);
	const speed = (260 + Fx.hash(spark.id, 2) * 260) * power * (reducedMotion ? 0.6 : 1);
	return <frame Size={UDim2.fromOffset(18, spark.kind === "perfect" ? 5 : 3.2)} Position={clock.map((seconds) => { const [dx, dy] = Fx.ballistic(seconds, angle, speed, 980, 2.6); return UDim2.fromScale(spark.x, spark.y).add(UDim2.fromOffset(dx, dy)); })} Rotation={math.deg(angle)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={spark.color} BackgroundTransparency={clock.map((seconds) => Fx.fade(seconds, 0.72, 0.3))} BorderSizePixel={0} ZIndex={91}><uicorner CornerRadius={new UDim(1, 0)} /></frame>;
}

export function SparkBurst({ sparks, reducedMotion }: { sparks: SparkData[]; reducedMotion: boolean }) {
	const max = math.max(4, math.min(useAntilag().maxPops * 2, 28));
	const children = tail(sparks, max).map((spark) => <Spark key={spark.id} spark={spark} reducedMotion={reducedMotion} />);
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={90} Active={false} ClipsDescendants={false}>{children}</frame>;
}

function ClickPop({ pop, reducedMotion }: { pop: PopData; reducedMotion: boolean }) {
	const clock = useClock(true, 1, 1000, true);
	const rise = pop.critical ? 118 : 86;
	const drift = (Fx.hash(pop.id, 3) - 0.5) * 36;
	return <frame Size={UDim2.fromOffset(pop.critical ? 168 : 128, 40)} Position={clock.map((seconds) => { const t = EASE.decelerate(clamp01(seconds / 0.8)); return UDim2.fromScale(pop.x, pop.y).add(UDim2.fromOffset(drift * t, -t * rise)); })} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={97}><uiscale Scale={clock.map((seconds) => reducedMotion ? 1 : Fx.popScale(seconds, pop.critical ? 0.24 : 0.18, pop.critical ? 0.55 : 0.4))} /><Text value={pop.text} size={pop.critical ? 34 : 24} color={pop.color} weight={Enum.FontWeight.Heavy} align={Enum.TextXAlignment.Center} fit={false} sizeConstraint={UDim2.fromScale(1, 1)} transparency={clock.map((seconds) => Fx.fade(seconds, 0.8, 0.5))} /></frame>;
}

export function ClickPops({ pops, reducedMotion }: { pops: PopData[]; reducedMotion: boolean }) {
	const max = math.max(3, math.min(useAntilag().maxPops, 10));
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={96} Active={false} ClipsDescendants={false}>{tail(pops, max).map((pop) => <ClickPop key={pop.id} pop={pop} reducedMotion={reducedMotion} />)}</frame>;
}

export function ComboBanner({ combo, heat, perfect, reducedMotion }: { combo: number; heat: number; perfect: boolean; reducedMotion: boolean }) {
	const pulse = useClock(!reducedMotion && combo > 1, 1.05);
	const bump = useFlash(combo, reducedMotion, 0.3);
	if (combo <= 1) return <frame Size={UDim2.fromOffset(0, 0)} BackgroundTransparency={1} BorderSizePixel={0} />;
	const accent = perfect ? Palette.mango : heat > 0.82 ? Palette.coral : Palette.brass;
	return <frame Size={UDim2.fromOffset(240, 52)} Position={UDim2.fromScale(0.5, 0.145)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={70}><uiscale Scale={React.joinBindings([pulse, bump]).map(([phase, flash]) => 1 + math.sin(phase) * (perfect ? 0.045 : 0.022) + flash * 0.16)} /><Text value={perfect ? "CRIT" : "STREAK"} size={11} color={accent} weight={Enum.FontWeight.Heavy} align={Enum.TextXAlignment.Center} fit={false} sizeConstraint={new UDim2(1, 0, 0, 14)} /><Text value={`x${combo}`} size={combo >= 10 ? 30 : 26} color={Palette.cream} weight={Enum.FontWeight.Heavy} align={Enum.TextXAlignment.Center} fit={false} position={UDim2.fromOffset(0, 14)} sizeConstraint={new UDim2(1, 0, 0, 32)} /></frame>;
}

export function HeatHaze({ heat, reducedMotion }: { heat: number; reducedMotion: boolean }) {
	const clock = useClock(!reducedMotion && heat > 0.12, 0.22);
	const strength = math.clamp(heat, 0, 1);
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={4} Active={false}><frame Size={new UDim2(1.08, 0, 0.42, 0)} Position={clock.map((phase) => new UDim2(-0.04 + math.sin(phase) * 0.02, 0, 0.48 + math.cos(phase * 0.7) * 0.012, 0))} BackgroundColor3={Palette.ember} BackgroundTransparency={1 - 0.07 * strength} BorderSizePixel={0}><uigradient Transparency={new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(0.5, 0.35), new NumberSequenceKeypoint(1, 1)])} Rotation={90} /></frame></frame>;
}

export function FluxRiver({ stations, reducedMotion, accent }: { stations: Station[]; reducedMotion: boolean; accent: Color3 }) {
	const clock = useClock(!reducedMotion, 0.55);
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={6} Active={false}>{stations.map((station, index) => station.live ? <frame key={`river-${index}`} Size={UDim2.fromOffset(3, 3)} Position={clock.map((phase) => { const t = (phase * 0.35 + index * 0.17) % 1; return UDim2.fromScale(station.x + (0.5 - station.x) * t, station.y + (0.58 - station.y) * t - math.sin(t * math.pi) * 0.04); })} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={station.color} BorderSizePixel={0} ZIndex={7}><uicorner CornerRadius={new UDim(1, 0)} /></frame> : undefined)}</frame>;
}

export function WorldHaze({ color, reducedMotion }: { color: Color3; reducedMotion: boolean }) {
	const clock = useClock(!reducedMotion, 0.07);
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={2} Active={false}><frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.void} BackgroundTransparency={0} BorderSizePixel={0}><uigradient Color={new ColorSequence([new ColorSequenceKeypoint(0, Palette.void), new ColorSequenceKeypoint(0.42, darken(color, 0.82)), new ColorSequenceKeypoint(1, Palette.ink)])} Rotation={118} /></frame><frame Size={UDim2.fromOffset(720, 720)} Position={clock.map((phase) => new UDim2(1, 90 + math.sin(phase) * 28, 1, 50 + math.cos(phase * 0.7) * 20))} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={color} BackgroundTransparency={0.9} BorderSizePixel={0}><uicorner CornerRadius={new UDim(1, 0)} /></frame></frame>;
}

export function CoreAura({ color, heat, squash, reducedMotion }: { color: Color3; heat: number; squash: React.Binding<number>; reducedMotion: boolean }) {
	const clock = useClock(!reducedMotion, 0.16);
	const glow = math.clamp(0.16 + heat * 0.22, 0.16, 0.4);
	return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={18} Active={false}><frame Size={clock.map((phase) => UDim2.fromScale(0.72 + math.sin(phase) * 0.03, 0.72 + math.sin(phase) * 0.03))} Position={UDim2.fromScale(0.5, 0.54)} AnchorPoint={new Vector2(0.5, 0.5)} BackgroundColor3={color} BackgroundTransparency={1 - glow} BorderSizePixel={0}><uiscale Scale={squash} /><uicorner CornerRadius={new UDim(1, 0)} /><uigradient Color={surfaceGradient(lighten(color, 0.2), 0.8)} Rotation={90} /></frame></frame>;
}
