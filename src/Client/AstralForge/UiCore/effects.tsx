import React from "@rbxts/react";
import { Palette, darken, lighten } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { ScaleFromCenter, easeOutBack, easeOutCubic, loadCanvasDraw, useClock } from "../MotionKit/motion";
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
						color={lighten(pop.color, 0.4)}
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

export function EffectLayer({ pops }: { pops: PopEntry[] }) {
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

export function StarField({ accent }: { accent: Color3 }) {
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
				BackgroundColor3={index % 3 === 0 ? accent : Palette.creamSoft}
				BackgroundTransparency={clock.map((phase) => 0.62 + math.sin(phase + star.phase) * 0.3 * glow)}
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

interface CanvasDraw {
	AutoUpdate: boolean;
	OutputWarnings: boolean;
	SetPixel(x: number, y: number, color: Color3): void;
	DrawCircle(center: Vector2, radius: number, color: Color3, fill: boolean): void;
	DrawLine(from: Vector2, to: Vector2, color: Color3, thickness: number): void;
	Update(): void;
	DestroyCanvas(): void;
}
interface CanvasDrawModule {
	new: (this: void, host: GuiObject, resolution: Vector2, background: Color3, blur: boolean) => CanvasDraw;
}

const ENERGY_FIELD_RESOLUTION = new Vector2(48, 28);
export function CanvasEnergyField({
	time,
	enabled,
	reducedMotion,
	zIndex = 712,
}: {
	time: React.Binding<number>;
	enabled?: boolean;
	reducedMotion?: boolean;
	zIndex?: number;
}) {
	const host = React.useRef<Frame>();
	const renderCanvas = React.useRef(enabled && !reducedMotion).current;
	React.useEffect(() => {
		if (!renderCanvas || host.current === undefined) {
			return undefined;
		}
		const module = loadCanvasDraw() as CanvasDrawModule | undefined;
		if (module === undefined) {
			return undefined;
		}
		const canvas = module.new(host.current, ENERGY_FIELD_RESOLUTION, Palette.void, false);
		canvas.AutoUpdate = false;
		canvas.OutputWarnings = false;
		const center = new Vector2((ENERGY_FIELD_RESOLUTION.X + 1) * 0.5, (ENERGY_FIELD_RESOLUTION.Y + 1) * 0.5);
		for (let y = 1; y <= ENERGY_FIELD_RESOLUTION.Y; y++) {
			for (let x = 1; x <= ENERGY_FIELD_RESOLUTION.X; x++) {
				const dx = (x - center.X) / ENERGY_FIELD_RESOLUTION.X;
				const dy = (y - center.Y) / ENERGY_FIELD_RESOLUTION.Y;
				const distance = math.sqrt(dx * dx + dy * dy);
				const ribbon = math.max(0, 1 - math.abs(distance - 0.23) * 13);
				const cross = math.max(0, 1 - math.abs(dx * 0.65 + dy) * 18) * math.max(0, 1 - distance * 2.2);
				const energy = math.clamp(ribbon * 0.42 + cross * 0.28, 0, 1);
				canvas.SetPixel(
					x,
					y,
					darken(Palette.violet.Lerp(Palette.cyan, math.clamp(x / ENERGY_FIELD_RESOLUTION.X, 0, 1)), 0.86 - energy * 0.28),
				);
			}
		}
		canvas.DrawCircle(center, 7, darken(Palette.pink, 0.36), false);
		canvas.DrawCircle(center, 11, darken(Palette.cyan, 0.54), false);
		canvas.DrawLine(new Vector2(7, 22), new Vector2(41, 6), darken(Palette.violet, 0.42), 1);
		canvas.Update();
		return () => canvas.DestroyCanvas();
	}, [renderCanvas]);
	return (
		<frame
			ref={host}
			Size={UDim2.fromScale(0.88, 0.88)}
			Position={UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			Rotation={time.map((value) => (reducedMotion ? 0 : value * -3.4))}
			BackgroundColor3={Palette.void}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			ClipsDescendants={true}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
}
