import React from "@rbxts/react";
import { Palette, lighten } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { ScaleFromCenter, easeOutBack, easeOutCubic, useClock } from "../MotionKit/motion";
import { Text } from "./ui";
import { UiEffectsPausedContext } from "../CoreKit/effectsPause";

export const POP_SECONDS = 1.15;

export interface PopEntry {
	id: string | number;
	text: string;
	color: Color3;
	offset: number;
	critical?: boolean;
}

function Pop({ pop }: { pop: PopEntry }) {
	const clock = useClock(true, 1, 1000, true);
	const size = pop.critical ? 30 : 22;
	const travel = pop.critical ? 190 : 140;
	const rise = clock.map((seconds) => {
		const progress = easeOutCubic(math.clamp(seconds / POP_SECONDS, 0, 1));
		return new UDim2(0.5, pop.offset, 1, -70 - math.floor(progress * travel));
	});
	const fade = clock.map((seconds) => math.clamp((seconds - 0.5) / 0.6, 0, 1));
	const scale = clock.map((seconds) => 0.72 + easeOutBack(math.clamp(seconds / 0.2, 0, 1)) * 0.28);
	return (
		<frame
			Size={UDim2.fromOffset(240, 40)}
			Position={rise}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={150}
		>
			<ScaleFromCenter scale={scale} zIndex={150}>
				<Text
					value={pop.text}
					size={size}
					color={pop.color}
					weight={Enum.FontWeight.Heavy}
					align={Enum.TextXAlignment.Center}
					transparency={fade}
					zIndex={151}
				/>
				{pop.critical && (
					<Text
						value="CRITICAL"
						size={11}
						color={lighten(pop.color, 0.2)}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Center}
						position={UDim2.fromOffset(0, 22)}
						sizeConstraint={new UDim2(1, 0, 0, 16)}
						transparency={fade}
						zIndex={151}
					/>
				)}
			</ScaleFromCenter>
		</frame>
	);
}

function EffectLayerImpl({ pops }: { pops: PopEntry[] }) {
	const antilag = useAntilag();
	const max = math.max(1, math.min(antilag.maxPops, math.floor(12 * antilag.fxBudget)));
	const visible = pops.size() > max ? pops.filter((_, index) => index >= pops.size() - max) : pops;
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={150} Active={false} ClipsDescendants={true}>
			{visible.map((pop) => (
				<Pop key={pop.id} pop={pop} />
			))}
		</frame>
	);
}
// re-render only when the pop list itself changes (the shell keeps the same array between pushes)
export const EffectLayer = React.memo(EffectLayerImpl);

const STARS = [
	{ x: 0.08, y: 0.18, size: 2, phase: 0.4 },
	{ x: 0.17, y: 0.72, size: 3, phase: 2.1 },
	{ x: 0.31, y: 0.34, size: 2, phase: 4.0 },
	{ x: 0.44, y: 0.86, size: 2, phase: 1.3 },
	{ x: 0.58, y: 0.22, size: 3, phase: 5.2 },
	{ x: 0.69, y: 0.62, size: 2, phase: 3.1 },
	{ x: 0.79, y: 0.14, size: 2, phase: 0.9 },
	{ x: 0.88, y: 0.78, size: 3, phase: 2.7 },
	{ x: 0.94, y: 0.42, size: 2, phase: 4.6 },
	{ x: 0.24, y: 0.52, size: 2, phase: 5.8 },
	{ x: 0.52, y: 0.48, size: 2, phase: 1.7 },
	{ x: 0.12, y: 0.9, size: 2, phase: 3.4 },
];

function StarFieldImpl({ accent }: { accent: Color3 }) {
	const antilag = useAntilag();
	const enabled = antilag.tier > 0 && antilag.maxStars > 0 && antilag.allowAmbient;
	const paused = React.useContext(UiEffectsPausedContext);
	const clock = useClock(enabled && !paused, antilag.constrained ? 0.7 : 1.1);
	const starCap = antilag.maxStars;
	const budgeted = math.clamp(math.floor(STARS.size() * antilag.fxBudget), 0, STARS.size());
	const count = enabled ? math.clamp(math.min(budgeted, starCap), 0, STARS.size()) : 0;
	if (count <= 0) {
		return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={1} ClipsDescendants={true} />;
	}
	const glow = antilag.glowScale;
	const children: React.Element[] = [];
	for (let index = 0; index < count; index++) {
		const star = STARS[index];
		children.push(
			<frame
				key={index}
				Size={UDim2.fromOffset(star.size, star.size)}
				Position={UDim2.fromScale(star.x, star.y)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundColor3={Palette.creamSoft}
				BackgroundTransparency={clock.map((phase) => 0.72 + math.sin(phase + star.phase) * 0.16 * glow)}
				BorderSizePixel={0}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
			</frame>,
		);
	}
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={1} ClipsDescendants={true}>
			{children}
		</frame>
	);
}
// the shell re-renders on every state push; the star field only depends on its accent
// (compared by value: Color3 equality is per component, not per object)
export const StarField = React.memo(StarFieldImpl, (a, b) => a.accent === b.accent);

