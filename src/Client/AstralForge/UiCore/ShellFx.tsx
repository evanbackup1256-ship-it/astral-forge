import { celebrationsAllowed } from "../MotionPreference";
import React from "@rbxts/react";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette, lighten } from "../CoreKit/theme";
import { useAntilag } from "../MotionKit/antilag";
import { useClock, useEntrance, usePulse } from "../MotionKit/motion";
import Fx = require("../MotionKit/vfxMath");
import { Button } from "./ui";
import { UiEffectsPausedContext } from "../CoreKit/effectsPause";

const UserInputService = game.GetService("UserInputService");

interface ConfettiPiece {
	side: number;
	angle: number;
	speed: number;
	size: number;
	spin: number;
	sway: number;
	phase: number;
	ribbon: boolean;
	delay: number;
	color: Color3;
}

// one warm family, brass to cream, instead of a party-pack of hues
const CONFETTI_COLORS = [Palette.brass, Palette.cream, lighten(Palette.brass, 0.25)];
const CONFETTI_COUNT = 24;
const CONFETTI_PIECES: ConfettiPiece[] = [];
for (let index = 1; index <= CONFETTI_COUNT; index++) {
	const side = index % 2 === 0 ? -1 : 1;
	CONFETTI_PIECES.push({
		side,
		angle: -math.pi / 2 - side * math.rad(8 + Fx.hash(index, 1) * 34),
		speed: 640 + Fx.hash(index, 2) * 560,
		size: 5 + math.floor(Fx.hash(index, 3) * 4),
		spin: 5 + Fx.hash(index, 4) * 9,
		sway: 12 + Fx.hash(index, 5) * 24,
		phase: Fx.hash(index, 6) * math.pi * 2,
		ribbon: index % 3 === 0,
		delay: (index % 6) * 0.018,
		color: CONFETTI_COLORS[(index - 1) % CONFETTI_COLORS.size()],
	});
}
const CONFETTI_GRAVITY = 760;
const CONFETTI_DRAG = 3.2;
const CONFETTI_LIFE = 1.95;

export function TradeReturnPill(props: { stack?: boolean; bottomPad: number; reducedMotion?: boolean; onReturn: () => void }) {
	const { stack, bottomPad, onReturn } = props;
	const softMotion = props.reducedMotion;
	const enter = useEntrance(softMotion);
	const pulse = usePulse(true, 1.35);
	const width = stack ? 176 : 198;
	const height = stack ? 48 : 46;
	const tradeReturnHostRef = React.useRef<Frame>();
	React.useEffect(() => {
		if (!UserInputService.GamepadEnabled) {
			return undefined;
		}
		const host = tradeReturnHostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const selectJob = task.defer(() => {
			if (host.Parent === undefined) {
				return;
			}
			GamepadNavigationService.FocusClaim(host);
		});
		return () => {
			pcall(task.cancel, selectJob);
		};
	}, [onReturn]);
	return (
		<frame
			{...{ Name: "TradeReturnClaim" }}
			ref={tradeReturnHostRef}
			Size={UDim2.fromOffset(width, height)}
			ClipsDescendants={false}
			Position={enter.map((amount) => new UDim2(0.5, 0, 1, -(bottomPad + (stack ? 10 : 16) - math.round((1 - amount) * 22))))}
			AnchorPoint={new Vector2(0.5, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={80}
		>
			<uiscale Scale={pulse.map((amount) => 1 + amount * 0.03)} />
			<Button
				text="BACK TO TRADE"
				icon="Visit.5"
				onClick={onReturn}
				sound="open"
				color={Palette.mint}
				textColor={Palette.ink}
				size={UDim2.fromScale(1, 1)}
				reducedMotion={softMotion}
				highlight={true}
			/>
		</frame>
	);
}

function AmbientLayerImpl(props: { reducedMotion?: boolean; intensity?: number }) {
	const { reducedMotion, intensity = 1 } = props;
	const antilag = useAntilag();
	const strength = math.clamp(intensity, 0, 1);
	const enabled = !reducedMotion && antilag.allowAmbient && strength > 0.02;
	const paused = React.useContext(UiEffectsPausedContext);
	const slow = useClock(enabled && !paused, 0.08);
	if (strength <= 0.02 || !antilag.allowAmbient) {
		return <frame {...{ Name: "AuroraBorealis" }} Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ZIndex={1} />;
	}
	const curtains: React.Element[] = [];
	const count = antilag.constrained ? 5 : 8;
	for (let index = 1; index <= count; index++) {
		const offset = index / count;
		curtains.push(
			<frame
				{...{ Name: "AuroraCurtain" + index }}
				Size={slow.map((t) => UDim2.fromScale(2.4 / count, 0.48 + math.sin(offset * 5 + t * 2) * 0.09))}
				Position={slow.map((t) =>
					UDim2.fromScale(offset - 0.12 + math.sin(t + offset * 4) * 0.025, 0.24 + math.sin(offset * 6 + t * 2) * 0.09),
				)}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={slow.map((t) => -18 + math.sin(t + offset * 3) * 8)}
				BackgroundColor3={Palette.white}
				BackgroundTransparency={1 - 0.1 * strength * antilag.glowScale}
				BorderSizePixel={0}
				ZIndex={1}
			>
				<uicorner CornerRadius={new UDim(1, 0)} />
				{/* one cool family, pale at the crest to deep at the hem, rather than three unrelated hues */}
				<uigradient
					Color={
						new ColorSequence([
							new ColorSequenceKeypoint(0, Palette.mint.Lerp(Palette.white, 0.3)),
							new ColorSequenceKeypoint(0.45, Palette.mint.Lerp(Palette.cyan, 0.55)),
							new ColorSequenceKeypoint(1, Palette.cyan),
						])
					}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.3, 0.25),
							new NumberSequenceKeypoint(0.55, 0.08),
							new NumberSequenceKeypoint(1, 1),
						])
					}
					Rotation={90}
				/>
			</frame>,
		);
	}
	return (
		<frame
			{...{ Name: "AuroraBorealis" }}
			Size={UDim2.fromScale(1, 1)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={1}
			ClipsDescendants={true}
		>
			{curtains}
		</frame>
	);
}
// primitives only; skips the shell's per-push re-render when motion and intensity are unchanged
export const AmbientLayer = React.memo(AmbientLayerImpl);

export function ConfettiBurst(props: { onDone?: () => void; intensity?: number }) {
	const { onDone, intensity = 1 } = props;
	const antilag = useAntilag();
	const softMotion = false;
	const confettiLive = antilag.allowConfetti === true && celebrationsAllowed();
	const clock = useClock(confettiLive, softMotion ? 1.4 : 1, 1000, true);
	const confettiSpan = softMotion ? 1.35 : 2.15;
	const onDoneRef = React.useRef(onDone);
	onDoneRef.current = onDone;
	const spanRef = React.useRef(confettiSpan);
	spanRef.current = confettiSpan;
	React.useEffect(() => {
		if (!confettiLive) {
			const finish = onDoneRef.current;
			if (finish !== undefined) {
				finish();
			}
			return undefined;
		}
		let alive = true;
		const completion = task.delay(spanRef.current, () => {
			if (alive) {
				const finish = onDoneRef.current;
				if (finish !== undefined) {
					finish();
				}
			}
		});
		return () => {
			alive = false;
			pcall(task.cancel, completion);
		};
	}, [confettiLive]);
	if (!confettiLive) {
		return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />;
	}
	const activeCount = math.clamp(
		math.floor(CONFETTI_PIECES.size() * math.clamp(intensity, 0, 1.5) * math.max(0.34, antilag.fxBudget)),
		0,
		CONFETTI_PIECES.size(),
	);
	if (activeCount <= 0) {
		return <frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} />;
	}
	const pieces = CONFETTI_PIECES.filter((_, index) => index < activeCount);
	const rings = [0].map((ring) => (
		<frame
			key={`confetti-ring-${ring}`}
			Size={clock.map((seconds) => {
				const [grow] = Fx.ring(seconds - ring * 0.08, 0.6);
				const d = 24 + grow * (190 + ring * 52);
				return UDim2.fromOffset(d, d);
			})}
			Position={UDim2.fromScale(0.5, 0.56)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={141}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<uistroke
				Color={Palette.brass}
				Thickness={1.5}
				Transparency={clock.map((seconds) => {
					const [, , fade] = Fx.ring(seconds - ring * 0.08, 0.6);
					return 0.4 + fade * 0.6;
				})}
			/>
		</frame>
	));
	const flakes = pieces.map((piece, index) => {
		const origin = UDim2.fromScale(0.5 + piece.side * 0.12, 0.66);
		const age = (seconds: number) => math.max(0, seconds - piece.delay);
		const flip = (t: number) => math.abs(math.cos(t * piece.spin + piece.phase));
		return (
			<frame
				key={index}
				Size={clock.map((seconds) => {
					const long = piece.size * (piece.ribbon ? 3 : 1.6);
					return UDim2.fromOffset(math.max(1.5, piece.size * (0.18 + 0.82 * flip(age(seconds)))), long);
				})}
				Position={clock.map((seconds) => {
					const t = age(seconds);
					const [dx, dy] = Fx.ballistic(t, piece.angle, piece.speed, CONFETTI_GRAVITY, CONFETTI_DRAG);
					const flutter = math.sin(t * 2.6 + piece.phase) * piece.sway * math.clamp(t / 0.6, 0, 1);
					return origin.add(UDim2.fromOffset(dx + flutter, dy));
				})}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Rotation={clock.map((seconds) => {
					const t = age(seconds);
					return math.deg(piece.phase) + t * (index % 2 === 0 ? 210 : -190) + math.sin(t * 3 + piece.phase) * 18;
				})}
				BackgroundColor3={clock.map((seconds) => piece.color.Lerp(lighten(piece.color, 0.18), flip(age(seconds))))}
				BackgroundTransparency={clock.map((seconds) => {
					if (seconds < piece.delay) {
						return 1;
					}
					return Fx.fade(age(seconds), CONFETTI_LIFE, 0.7);
				})}
				BorderSizePixel={0}
				ZIndex={142 + (index % 3)}
			>
				<uicorner CornerRadius={new UDim(0, piece.ribbon ? 1 : 2)} />
			</frame>
		);
	});
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} ClipsDescendants={true} ZIndex={140} Active={false}>
			{rings}
			{flakes}
		</frame>
	);
}
