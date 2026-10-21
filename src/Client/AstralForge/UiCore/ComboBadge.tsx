import React from "@rbxts/react";
import { Palette, darken, ensureContrast, lighten } from "../CoreKit/theme";
import { joinTuple } from "../lua";
import { useAntilag } from "../MotionKit/antilag";
import { ScaleFromCenter, useClock, useFlash, useGlowStroke, useOptionalFlipperSpring, usePulse } from "../MotionKit/motion";
import { LooseComponent, Stroke, Text } from "./ui";

const AstralForge = script.Parent!.Parent!;
const Icon = (require(AstralForge.WaitForChild("ArtKit") as ModuleScript) as (name: string) => { Icon: LooseComponent })("Icon").Icon;

// the same brass-to-ember heat the Overcharge ring uses, so the badge and the strike agree
const COOL = Color3.fromRGB(250, 190, 72);
const HOT = Color3.fromRGB(244, 92, 84);
function heatColor(ratio: number): Color3 {
	return COOL.Lerp(HOT, math.clamp(ratio, 0, 1));
}

function DecayRing({
	accent,
	updatedAt,
	windowSeconds,
	animate,
}: {
	accent: Color3;
	updatedAt: number;
	windowSeconds: number;
	animate: boolean;
}) {
	const anchorOffset = os.clock() - updatedAt;
	const sweep = useClock(animate, 1 / math.max(0.1, windowSeconds), 1, true);
	const remaining = sweep.map((raw) => math.clamp(1 - ((raw + anchorOffset / windowSeconds) % 1), 0, 1));
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Rotation={-90}>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke
				Color={accent}
				Thickness={2}
				Transparency={0.2}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				LineJoinMode={Enum.LineJoinMode.Round}
			>
				<uigradient
					Transparency={remaining.map((fraction) => {
						const edge = math.clamp(fraction, 0.001, 0.998);
						return new NumberSequence([
							new NumberSequenceKeypoint(0, 0.05),
							new NumberSequenceKeypoint(edge, 0.05),
							new NumberSequenceKeypoint(edge + 0.001, 1),
							new NumberSequenceKeypoint(1, 1),
						]);
					})}
				/>
			</uistroke>
		</frame>
	);
}

export interface ComboReadout {
	combo: number;
	comboMax?: number;
	comboMultiplier?: number;
	comboWindow: number;
	updatedAt: number;
}

export function ComboBadge(props: {
	readout?: ComboReadout;
	reducedMotion?: boolean;
	position?: UDim2;
	anchorPoint?: Vector2;
	zIndex?: number;
}) {
	const { readout, reducedMotion, position, anchorPoint, zIndex = 65 } = props;
	const antilag = useAntilag();
	const [visible, setVisible] = React.useState(false);
	React.useEffect(() => {
		if (readout === undefined || readout.combo <= 0) {
			setVisible(false);
			return undefined;
		}
		setVisible(true);
		const expiresIn = math.max(0.05, readout.comboWindow - (os.clock() - readout.updatedAt)) + readout.comboWindow * 0.35;
		const timer = task.delay(expiresIn, () => setVisible(false));
		return () => task.cancel(timer);
	}, [readout]);
	const combo = readout?.combo ?? 0;
	const comboMax = math.max(1, readout?.comboMax ?? 12);
	const multiplier = readout?.comboMultiplier ?? 1;
	const ratio = math.clamp(combo / comboMax, 0, 1);
	const maxed = combo >= comboMax;
	const accent = heatColor(ratio);
	const [everVisible, setEverVisible] = React.useState(false);
	React.useEffect(() => {
		if (visible) {
			setEverVisible(true);
		}
	}, [visible]);
	const [tapPunch, setTapPunch] = React.useState(0);
	const lastCombo = React.useRef(0);
	React.useEffect(() => {
		if (combo > lastCombo.current) {
			setTapPunch((current) => current + 1);
		}
		lastCombo.current = combo;
	}, [combo]);
	const punch = useFlash(tapPunch, reducedMotion, 0.28);
	const presence = useOptionalFlipperSpring(visible ? 1 : 0, everVisible, reducedMotion, 580, 32);
	const intensitySpring = useOptionalFlipperSpring(ratio, visible, reducedMotion, 380, 28);
	const glow = useGlowStroke(maxed && visible && antilag.allowAmbient, reducedMotion, 0.42, 0.22, 0.5, maxed ? 1.6 : 1.2);
	const maxPulse = usePulse(maxed && visible && !reducedMotion, 1.7);
	const scale = React.useMemo(
		() =>
			joinTuple<[number, number, number]>(presence, intensitySpring, punch).map(
				(values) => 0.72 + values[0] * 0.28 + values[1] * 0.05 + values[2] * 0.14,
			),
		[presence, intensitySpring, punch],
	);
	const iconScale = React.useMemo(() => punch.map((amount) => 1 + amount * 0.28), [punch]);
	const rise = React.useMemo(() => presence.map((amount) => math.round((1 - amount) * 18)), [presence]);
	const fade = React.useMemo(() => presence.map((amount) => 1 - amount), [presence]);
	if (!everVisible) {
		return <frame Size={UDim2.fromOffset(0, 0)} BackgroundTransparency={1} BorderSizePixel={0} />;
	}
	return (
		<frame
			Size={UDim2.fromOffset(96, 40)}
			Position={position}
			AnchorPoint={anchorPoint}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={zIndex}
			Active={presence.map((amount) => amount > 0.01)}
			Visible={presence.map((amount) => amount > 0.01)}
		>
			<ScaleFromCenter scale={scale} zIndex={zIndex}>
				<frame
					Size={UDim2.fromScale(1, 1)}
					Position={rise.map((offset) => UDim2.fromOffset(0, offset))}
					BackgroundColor3={darken(accent, 0.58)}
					BackgroundTransparency={fade.map((amount) => math.clamp(0.12 + amount * 0.88, 0, 1))}
					BorderSizePixel={0}
					ClipsDescendants={false}
				>
					<uicorner CornerRadius={new UDim(0, 14)} />
					<Stroke
						color={accent}
						thickness={1}
						transparency={maxed ? glow : fade.map((amount) => math.clamp(0.28 + amount * 0.72, 0, 1))}
					/>
					<frame
						Size={UDim2.fromOffset(28, 28)}
						Position={UDim2.fromOffset(6, 6)}
						BackgroundColor3={darken(accent, 0.3)}
						BackgroundTransparency={fade}
						BorderSizePixel={0}
						ZIndex={zIndex + 1}
					>
						<uicorner CornerRadius={new UDim(0, 10)} />
						{!maxed && readout !== undefined && visible && (
							<frame
								Size={UDim2.fromScale(1, 1)}
								Position={UDim2.fromOffset(-2, -2)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								ClipsDescendants={false}
							>
								<uisizeconstraint MaxSize={new Vector2(32, 32)} />
								<DecayRing
									accent={accent}
									updatedAt={readout.updatedAt}
									windowSeconds={readout.comboWindow}
									animate={!reducedMotion && antilag.allowAmbient}
								/>
							</frame>
						)}
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							ClipsDescendants={true}
							ZIndex={zIndex + 1}
						>
							<uicorner CornerRadius={new UDim(0, 10)} />
							<ScaleFromCenter scale={iconScale} zIndex={zIndex + 1}>
								<Icon
									kind="Overcharge.9"
									color={Palette.cream}
									accent={accent}
									size={17}
									spin={false}
									reducedMotion={reducedMotion}
									position={UDim2.fromScale(0.5, 0.5)}
									anchorPoint={new Vector2(0.5, 0.5)}
								/>
							</ScaleFromCenter>
						</frame>
					</frame>
					<Text
						value={`×${math.floor(combo)}`}
						size={maxed ? 19 : 16}
						color={ensureContrast(darken(accent, 0.58), Palette.cream)}
						weight={Enum.FontWeight.Heavy}
						align={Enum.TextXAlignment.Left}
						fit={true}
						minSize={12}
						position={UDim2.fromOffset(40, 4)}
						sizeConstraint={new UDim2(1, -46, 0, 20)}
						transparency={fade}
						zIndex={zIndex + 1}
					/>
					<Text
						value={maxed ? "MAXED" : `${string.format("%.2f", multiplier)}x`}
						size={10}
						color={ensureContrast(darken(accent, 0.58), accent)}
						weight={Enum.FontWeight.Bold}
						align={Enum.TextXAlignment.Left}
						fit={true}
						minSize={9}
						position={UDim2.fromOffset(40, 22)}
						sizeConstraint={new UDim2(1, -46, 0, 14)}
						transparency={fade}
						zIndex={zIndex + 1}
					/>
					{maxed && (
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundColor3={accent}
							BackgroundTransparency={maxPulse.map((amount) => 0.93 - amount * 0.04)}
							BorderSizePixel={0}
							ZIndex={zIndex - 1}
						>
							<uicorner CornerRadius={new UDim(0, 14)} />
						</frame>
					)}
				</frame>
			</ScaleFromCenter>
		</frame>
	);
}
