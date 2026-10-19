import React from "@rbxts/react";
import { easeInCubic, easeOutBack, easeOutCubic, ScaleFromCenter, useSprScale } from "../MotionKit/motion";
import { Palette } from "../CoreKit/theme";

const RunService = game.GetService("RunService");

const ATLAS_SIZE = 1024;
const CELL_HEIGHT = 512;
const CELL_SIZE = new Vector2(ATLAS_SIZE, CELL_HEIGHT);
const HAMMER_OFFSET = Vector2.zero;
const ANVIL_OFFSET = new Vector2(0, CELL_HEIGHT);
const ANVIL_HALF_SIZE = new Vector2(ATLAS_SIZE / 2, CELL_HEIGHT);
const ANVIL_RIGHT_OFFSET = new Vector2(ATLAS_SIZE / 2, CELL_HEIGHT);
const REGULAR_CONTACT = 0.7;
const FINALE_CONTACT = 0.75;
const HAMMER_WIDTH = 0.72;
const HAMMER_HEIGHT = 0.36;
const ANVIL_WIDTH = 0.74;
const ANVIL_HEIGHT = 0.37;
const HAMMER_ANCHOR_X = 0.92;
export const FORGE_RIG_LOOP_SECONDS = 2.05;
export const FORGE_RIG_ART_SCALE = 0.56;

function clamp01(value: number) {
	return math.clamp(value, 0, 1);
}
function span(value: number, start: number, finish: number) {
	return clamp01((value - start) / math.max(0.001, finish - start));
}
function pulse(value: number, start: number, peak: number, finish: number) {
	if (value <= start || value >= finish) {
		return 0;
	}
	return value <= peak ? span(value, start, peak) : 1 - span(value, peak, finish);
}
function dampedBounce(value: number, frequency = 3.4, decay = 6.2) {
	const amount = clamp01(value);
	return math.exp(-decay * amount) * math.sin(amount * math.pi * frequency);
}

interface Pose {
	hammerPosition: UDim2;
	hammerRotation: number;
	hammerScaleX: number;
	hammerScaleY: number;
	anvilPosition: UDim2;
	anvilScaleX: number;
	anvilScaleY: number;
	impact: number;
	trail: number;
	flex: number;
}

function regularPose(progress: number): Pose {
	const value = clamp01(progress);
	let rotation = 12;
	let pivotX = 1.04;
	let pivotY = 0.28;
	let stretch = 0;
	let trail = 0;
	let flex = 0;
	if (value < 0.18) {
		const idle = value / 0.18;
		rotation = 12 + math.sin(idle * math.pi) * 2.8;
		pivotX = 1.04 + math.sin(idle * math.pi * 2) * 0.002;
		pivotY = 0.28 - math.sin(idle * math.pi) * 0.007;
		flex = math.sin(idle * math.pi * 2) * 1.2;
	} else if (value < 0.43) {
		const amount = easeOutBack(span(value, 0.18, 0.43));
		rotation = 12 + amount * 36;
		pivotX = 1.04 - amount * 0.045;
		pivotY = 0.28 + amount * 0.03;
		stretch = -0.032 * amount;
		flex = -math.sin(clamp01(amount) * math.pi) * 8;
	} else if (value < 0.53) {
		const amount = span(value, 0.43, 0.53);
		rotation = 48 + math.sin(amount * math.pi) * 2.5;
		pivotX = 0.995;
		pivotY = 0.31 - amount * 0.04;
		stretch = -0.032 + amount * 0.012;
		flex = -math.sin(amount * math.pi) * 10;
	} else if (value < REGULAR_CONTACT) {
		const amount = easeInCubic(span(value, 0.53, REGULAR_CONTACT));
		rotation = 48 - amount * 58;
		pivotX = 0.995 + amount * 0.06;
		pivotY = 0.27 - amount * 0.052;
		stretch = amount * 0.082;
		trail = easeOutCubic(amount);
		flex = math.sin(amount * math.pi) * 16;
	} else {
		const recovery = span(value, REGULAR_CONTACT, 1);
		const settle = easeOutCubic(recovery);
		const bounce = dampedBounce(recovery, 3.6, 6.8);
		rotation = -10 + settle * 22 + bounce * 26;
		pivotX = 1.05 - settle * 0.01 - bounce * 0.008;
		pivotY = 0.22 + settle * 0.06 - bounce * 0.03;
		stretch = -bounce * 0.035;
		flex = -dampedBounce(recovery, 5.2, 5.6) * 16;
	}
	const impact = pulse(value, REGULAR_CONTACT - 0.012, REGULAR_CONTACT + 0.02, REGULAR_CONTACT + 0.15);
	const recovery = span(value, REGULAR_CONTACT, 1);
	const anvilBounce = value < REGULAR_CONTACT ? 0 : dampedBounce(recovery, 4.1, 7.4);
	return {
		hammerPosition: UDim2.fromScale(pivotX, pivotY),
		hammerRotation: rotation,
		hammerScaleX: 1 - stretch * 0.35,
		hammerScaleY: 1 + stretch,
		anvilPosition: UDim2.fromScale(0.5, 0.64 + impact * 0.01 - anvilBounce * 0.006),
		anvilScaleX: 1 + impact * 0.065 - anvilBounce * 0.022,
		anvilScaleY: 1 - impact * 0.14 + anvilBounce * 0.045,
		impact,
		trail,
		flex,
	};
}

function finalePose(progress: number): Pose {
	const value = clamp01(progress);
	let rotation = 12;
	let pivotX = 1.04;
	let pivotY = 0.28;
	let stretch = 0;
	let trail = 0;
	let flex = 0;
	if (value < 0.16) {
		const amount = easeOutBack(span(value, 0, 0.16));
		rotation = 12 + amount * 58;
		pivotX = 1.04 - amount * 0.07;
		pivotY = 0.28 - amount * 0.06;
		stretch = -amount * 0.025;
		flex = -math.sin(clamp01(amount) * math.pi) * 9;
	} else if (value < 0.52) {
		const amount = easeOutCubic(span(value, 0.16, 0.52));
		const arc = math.sin(amount * math.pi);
		rotation = 70 + amount * 900;
		pivotX = 0.97 - arc * 0.13 - amount * 0.025;
		pivotY = 0.22 - arc * 0.15;
		stretch = arc * 0.06;
		trail = 0.62 + arc * 0.38;
		flex = math.sin(amount * math.pi * 4) * 12;
	} else if (value < 0.64) {
		const amount = easeOutCubic(span(value, 0.52, 0.64));
		rotation = 970 + math.sin(amount * math.pi) * 14;
		pivotX = 0.945 - amount * 0.008;
		pivotY = 0.21 - amount * 0.09;
		stretch = -0.025 + amount * 0.012;
		trail = 0.45 - amount * 0.15;
		flex = -math.sin(amount * math.pi) * 18;
	} else if (value < FINALE_CONTACT) {
		const amount = easeInCubic(span(value, 0.64, FINALE_CONTACT));
		rotation = 970 - amount * 258;
		pivotX = 0.937 + amount * 0.113;
		pivotY = 0.12 + amount * 0.1;
		stretch = amount * 0.2;
		trail = 0.35 + amount * 0.65;
		flex = math.sin(amount * math.pi) * 31;
	} else {
		const recovery = span(value, FINALE_CONTACT, 1);
		const settle = easeOutCubic(recovery);
		const bounce = dampedBounce(recovery, 3.8, 6.8);
		rotation = 712 + settle * 22 + bounce * 31;
		pivotX = 1.05 - settle * 0.01 - bounce * 0.008;
		pivotY = 0.22 + settle * 0.06 - bounce * 0.035;
		stretch = -bounce * 0.032;
		flex = -dampedBounce(recovery, 5.4, 5.5) * 16;
	}
	const impact = pulse(value, FINALE_CONTACT - 0.012, FINALE_CONTACT + 0.018, 0.93);
	const recovery = span(value, FINALE_CONTACT, 1);
	const anvilBounce = value < FINALE_CONTACT ? 0 : dampedBounce(recovery, 4.4, 7.2);
	return {
		hammerPosition: UDim2.fromScale(pivotX, pivotY),
		hammerRotation: rotation,
		hammerScaleX: 1 - stretch * 0.32,
		hammerScaleY: 1 + stretch,
		anvilPosition: UDim2.fromScale(0.5, 0.64 + impact * 0.023 - anvilBounce * 0.011),
		anvilScaleX: 1 + impact * 0.11 - anvilBounce * 0.028,
		anvilScaleY: 1 - impact * 0.22 + anvilBounce * 0.06,
		impact,
		trail,
		flex,
	};
}

function faded(effectTransparency: number, masterFade: number) {
	return clamp01(1 - (1 - effectTransparency) * (1 - masterFade));
}

export interface ForgeRig2DProps {
	atlasId: number;
	size?: UDim2;
	position?: UDim2;
	reducedMotion?: boolean;
	lowQuality?: boolean;
	exiting?: boolean;
	finaleActive?: boolean;
	finaleTimeline: React.Binding<number>;
	fade: React.Binding<number>;
	onWindup?: () => void;
	onStrike?: () => void;
	onSpark?: () => void;
	zIndex?: number;
}

export function ForgeRig2D({
	atlasId,
	size,
	position,
	reducedMotion,
	lowQuality,
	exiting = false,
	finaleActive = false,
	finaleTimeline,
	fade,
	onWindup,
	onStrike,
	onSpark,
	zIndex = 520,
}: ForgeRig2DProps) {
	const [regularTimeline, setRegularTimeline] = React.useBinding(0);
	const windupRef = React.useRef(onWindup);
	const strikeRef = React.useRef(onStrike);
	const sparkRef = React.useRef(onSpark);
	windupRef.current = onWindup;
	strikeRef.current = onStrike;
	sparkRef.current = onSpark;
	const entranceScale = useSprScale(1, reducedMotion, 0.78, 0.7, 6.8);
	React.useEffect(() => {
		if (reducedMotion || finaleActive || exiting) {
			setRegularTimeline(0.04);
			return undefined;
		}
		const startedAt = os.clock();
		let priorCycle = -1;
		let windupSent = false;
		let strikeSent = false;
		let sparkSent = false;
		const connection = RunService.RenderStepped.Connect(() => {
			const elapsed = math.max(0, os.clock() - startedAt);
			const cycle = math.floor(elapsed / FORGE_RIG_LOOP_SECONDS);
			const progress = (elapsed % FORGE_RIG_LOOP_SECONDS) / FORGE_RIG_LOOP_SECONDS;
			if (cycle !== priorCycle) {
				priorCycle = cycle;
				windupSent = false;
				strikeSent = false;
				sparkSent = false;
			}
			setRegularTimeline(progress);
			if (!windupSent && progress >= 0.28) {
				windupSent = true;
				windupRef.current?.();
			}
			if (!strikeSent && progress >= REGULAR_CONTACT) {
				strikeSent = true;
				strikeRef.current?.();
			}
			if (!sparkSent && progress >= REGULAR_CONTACT + 0.018) {
				sparkSent = true;
				sparkRef.current?.();
			}
		});
		return () => connection.Disconnect();
	}, [exiting, finaleActive, reducedMotion, setRegularTimeline]);
	const pose = React.joinBindings({ regular: regularTimeline, finale: finaleTimeline }).map(({ regular, finale }) =>
		finaleActive ? finalePose(finale) : regularPose(regular),
	);
	const atlas = `rbxassetid://${atlasId}`;
	const hammerPosition = pose.map((value) => value.hammerPosition);
	const anvilPosition = pose.map((value) => value.anvilPosition);
	const anvilScaleX = pose.map((value) => value.anvilScaleX);
	const anvilScaleY = pose.map((value) => value.anvilScaleY);
	const hammerSize = pose.map((value) =>
		UDim2.fromScale(
			HAMMER_WIDTH * value.hammerScaleX,
			HAMMER_HEIGHT * value.hammerScaleY * (1 + math.abs(value.flex) * 0.0015),
		),
	);
	const silhouetteRotation = pose.map((value) => value.hammerRotation + value.flex * 0.16);
	const anvilSize = React.joinBindings({ x: anvilScaleX, y: anvilScaleY }).map(({ x, y }) =>
		UDim2.fromScale(ANVIL_WIDTH * x, ANVIL_HEIGHT * y),
	);
	const anvilHalfSize = React.joinBindings({ x: anvilScaleX, y: anvilScaleY }).map(({ x, y }) =>
		UDim2.fromScale(ANVIL_WIDTH * x * 0.5, ANVIL_HEIGHT * y),
	);
	const splitAmount = finaleTimeline.map((amount) =>
		finaleActive ? easeOutCubic(span(amount, FINALE_CONTACT, 0.97)) : 0,
	);
	const leftAnvilPosition = React.joinBindings({ pose, split: splitAmount }).map(
		({ pose: value, split }) =>
			new UDim2(
				value.anvilPosition.X.Scale - ANVIL_WIDTH * value.anvilScaleX * 0.25 - split * 0.14,
				value.anvilPosition.X.Offset,
				value.anvilPosition.Y.Scale + split * split * 0.12,
				value.anvilPosition.Y.Offset,
			),
	);
	const rightAnvilPosition = React.joinBindings({ pose, split: splitAmount }).map(
		({ pose: value, split }) =>
			new UDim2(
				value.anvilPosition.X.Scale + ANVIL_WIDTH * value.anvilScaleX * 0.25 + split * 0.14,
				value.anvilPosition.X.Offset,
				value.anvilPosition.Y.Scale + split * split * 0.12,
				value.anvilPosition.Y.Offset,
			),
	);
	const leftAnvilRotation = splitAmount.map((amount) => -amount * 22);
	const rightAnvilRotation = splitAmount.map((amount) => amount * 22);
	const fractureTransparency = React.joinBindings({ split: splitAmount, fade }).map(({ split, fade: leaving }) =>
		faded(1 - pulse(split, 0, 0.08, 0.72) * 0.94, leaving),
	);
	const impactSize = pose.map((value) => UDim2.fromScale(0.11 + value.impact * 0.3, 0.11 + value.impact * 0.3));
	const impactTransparency = React.joinBindings({ pose, fade }).map(({ pose: value, fade: leaving }) =>
		faded(1 - value.impact * 0.82, leaving),
	);
	const shadowSize = pose.map((value) => UDim2.fromScale(0.48 + value.impact * 0.05, 0.045 - value.impact * 0.012));
	const ribbons =
		!reducedMotion &&
		!lowQuality &&
		(finaleActive ? [0, 1, 2, 3] : [0, 1]).map((index) => {
			const lag = 0.024 + index * 0.028;
			const trailPose = React.joinBindings({ regular: regularTimeline, finale: finaleTimeline }).map(
				({ regular, finale }) =>
					finaleActive ? finalePose(math.max(0, finale - lag)) : regularPose(math.max(0, regular - lag)),
			);
			const ribbonPosition = trailPose.map((value) => {
				const angle = math.rad(value.hammerRotation);
				const lever = HAMMER_WIDTH * value.hammerScaleX * (HAMMER_ANCHOR_X - 0.36);
				return UDim2.fromScale(
					value.hammerPosition.X.Scale - math.cos(angle) * lever,
					value.hammerPosition.Y.Scale - math.sin(angle) * lever,
				);
			});
			const ribbonSize = trailPose.map((value) =>
				UDim2.fromScale(
					0.012 + value.trail * (0.012 - index * 0.0015),
					0.06 + value.trail * (0.17 - index * 0.018),
				),
			);
			const transparency = React.joinBindings({ pose: trailPose, fade }).map(({ pose: value, fade: leaving }) =>
				faded(0.98 - value.trail * (0.36 - index * 0.055), leaving),
			);
			return (
				<frame
					key={`forge-motion-ribbon-${index}`}
					Size={ribbonSize}
					Position={ribbonPosition}
					Rotation={trailPose.map((value) => value.hammerRotation + 90)}
					AnchorPoint={new Vector2(0.5, 1)}
					BackgroundColor3={index % 3 === 0 ? Palette.cream : index % 2 === 0 ? Palette.violet : Palette.cyan}
					BackgroundTransparency={transparency}
					BorderSizePixel={0}
					ZIndex={zIndex + 4 + index}
				>
					<uicorner CornerRadius={new UDim(1, 0)} />
					<uigradient
						Transparency={
							new NumberSequence([
								new NumberSequenceKeypoint(0, 1),
								new NumberSequenceKeypoint(0.35, 0.25),
								new NumberSequenceKeypoint(1, 1),
							])
						}
						Rotation={90}
					/>
				</frame>
			);
		});
	return (
		<frame
			Size={size}
			Position={position}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={false}
			ZIndex={zIndex}
		>
			<frame
				Size={UDim2.fromScale(FORGE_RIG_ART_SCALE, FORGE_RIG_ART_SCALE)}
				Position={UDim2.fromScale(0.5, 0.5)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				ZIndex={zIndex}
			>
				<ScaleFromCenter scaleRef={entranceScale} zIndex={zIndex}>
					<uiaspectratioconstraint AspectRatio={1} DominantAxis={Enum.DominantAxis.Height} />
					<frame
						Size={shadowSize}
						Position={UDim2.fromScale(0.5, 0.815)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundColor3={Palette.cyan}
						BackgroundTransparency={fade.map((leaving) => faded(0.87, leaving))}
						BorderSizePixel={0}
						ZIndex={zIndex}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uigradient
							Transparency={
								new NumberSequence([
									new NumberSequenceKeypoint(0, 1),
									new NumberSequenceKeypoint(0.5, 0.25),
									new NumberSequenceKeypoint(1, 1),
								])
							}
						/>
					</frame>
					<frame
						Size={impactSize}
						Position={UDim2.fromScale(0.5, 0.47)}
						AnchorPoint={new Vector2(0.5, 0.5)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						ZIndex={zIndex + 1}
					>
						<uicorner CornerRadius={new UDim(1, 0)} />
						<uistroke Color={Palette.mango} Thickness={2.5} Transparency={impactTransparency} />
					</frame>
					{!finaleActive ? (
						<imagelabel
							Size={anvilSize}
							Position={anvilPosition}
							AnchorPoint={new Vector2(0.5, 0.5)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							Image={atlas}
							ImageRectOffset={ANVIL_OFFSET}
							ImageRectSize={CELL_SIZE}
							ImageTransparency={fade}
							ScaleType={Enum.ScaleType.Fit}
							ResampleMode={Enum.ResamplerMode.Default}
							ZIndex={zIndex + 3}
						>
							<uisizeconstraint MinSize={new Vector2(1, 1)} />
						</imagelabel>
					) : (
						<>
							<imagelabel
								Size={anvilHalfSize}
								Position={leftAnvilPosition}
								Rotation={leftAnvilRotation}
								AnchorPoint={new Vector2(0.5, 0.5)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								Image={atlas}
								ImageRectOffset={ANVIL_OFFSET}
								ImageRectSize={ANVIL_HALF_SIZE}
								ImageTransparency={fade}
								ScaleType={Enum.ScaleType.Fit}
								ResampleMode={Enum.ResamplerMode.Default}
								ZIndex={zIndex + 3}
							/>
							<imagelabel
								Size={anvilHalfSize}
								Position={rightAnvilPosition}
								Rotation={rightAnvilRotation}
								AnchorPoint={new Vector2(0.5, 0.5)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								Image={atlas}
								ImageRectOffset={ANVIL_RIGHT_OFFSET}
								ImageRectSize={ANVIL_HALF_SIZE}
								ImageTransparency={fade}
								ScaleType={Enum.ScaleType.Fit}
								ResampleMode={Enum.ResamplerMode.Default}
								ZIndex={zIndex + 3}
							/>
							<frame
								Size={UDim2.fromScale(0.012, ANVIL_HEIGHT * 0.58)}
								Position={anvilPosition}
								AnchorPoint={new Vector2(0.5, 0.34)}
								Rotation={7}
								BackgroundColor3={Palette.cream}
								BackgroundTransparency={fractureTransparency}
								BorderSizePixel={0}
								ZIndex={zIndex + 6}
							>
								<uigradient
									Color={new ColorSequence(Palette.cream, Palette.mango)}
									Transparency={
										new NumberSequence([
											new NumberSequenceKeypoint(0, 0.78),
											new NumberSequenceKeypoint(0.42, 0),
											new NumberSequenceKeypoint(1, 0.9),
										])
									}
									Rotation={90}
								/>
							</frame>
						</>
					)}
					{ribbons}
					<imagelabel
						Size={hammerSize}
						Position={hammerPosition}
						Rotation={silhouetteRotation}
						AnchorPoint={new Vector2(HAMMER_ANCHOR_X, 0.5)}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Image={atlas}
						ImageRectOffset={HAMMER_OFFSET}
						ImageRectSize={CELL_SIZE}
						ImageTransparency={fade}
						ScaleType={Enum.ScaleType.Fit}
						ResampleMode={Enum.ResamplerMode.Default}
						ZIndex={zIndex + 8}
					>
						<uisizeconstraint MinSize={new Vector2(1, 1)} />
					</imagelabel>
				</ScaleFromCenter>
			</frame>
		</frame>
	);
}
