import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Layout, Palette } from "../CoreKit/theme";
import { Panel, Text } from "../UiCore/ui";
import { isReducedMotion } from "../MotionPreference";

// Purchase status card: a small card with three bouncing dots while Roblox checkout runs,
// then it settles into a plain success or failure line and gets out of the way.

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");

const PURCHASE_RESULT_HOLD = 1.8;
const PURCHASE_RESULT_HOLD_REDUCED = 1.4;
const PURCHASE_PENDING_FAILSAFE = 45;

const CARD_W = 260;
const CARD_H = 88;
const DOT = 9;

type Phase = "hidden" | "pending" | "success" | "fail";

interface PurchaseOverlayProps {
	phase: string;
	reducedMotion?: boolean;
	detail?: string;
	onDismiss?: () => void;
}

// one binding drives everything: t counts seconds since the phase began
function usePhaseClock(phase: string): React.Binding<number> {
	const [t, setT] = React.useBinding(0);
	React.useEffect(() => {
		setT(0);
		if (phase === "hidden") {
			return undefined;
		}
		let elapsed = 0;
		const conn = RunService.RenderStepped.Connect((dt) => {
			elapsed += dt;
			setT(elapsed);
			// the result state is fully settled after half a second; stop paying for frames
			if (phase !== "pending" && elapsed > 0.6) {
				conn.Disconnect();
			}
		});
		return () => conn.Disconnect();
	}, [phase]);
	return t;
}

function Dot(props: { index: number; t: React.Binding<number>; still: boolean }) {
	const i = props.index;
	// a soft hop with a short rest at the bottom, each dot a beat behind the last
	const hop = props.t.map((t) => {
		const cycle = (t * 1.6 - i * 0.16) % 1;
		const phase = cycle < 0 ? cycle + 1 : cycle;
		return phase < 0.42 ? math.sin((phase / 0.42) * math.pi) : 0;
	});
	return (
		<frame
			Size={UDim2.fromOffset(DOT, DOT)}
			AnchorPoint={new Vector2(0.5, 1)}
			Position={hop.map((h) => new UDim2(0.5, (i - 1) * (DOT + 7), 1, props.still ? 0 : -math.floor(h * 9)))}
			BackgroundColor3={Palette.mango}
			BackgroundTransparency={hop.map((h) => (props.still ? 0.55 - h * 0.45 : 0.1 - h * 0.1))}
			BorderSizePixel={0}
		>
			<uicorner CornerRadius={new UDim(1, 0)} />
		</frame>
	);
}

function PurchaseOverlay(props: PurchaseOverlayProps) {
	const phase = props.phase as Phase;
	const still = props.reducedMotion === true || isReducedMotion();
	const visible = phase !== "hidden";
	const result = phase === "success" || phase === "fail";
	const t = usePhaseClock(phase);
	const dismissRef = React.useRef(props.onDismiss);
	dismissRef.current = props.onDismiss;
	const hostRef = React.useRef<TextButton>();

	React.useEffect(() => {
		if (phase === "success") {
			Audio.play("purchaseResult");
		} else if (phase === "fail") {
			Audio.play("error");
		}
		if (!result) {
			return undefined;
		}
		const job = task.delay(still ? PURCHASE_RESULT_HOLD_REDUCED : PURCHASE_RESULT_HOLD, () => dismissRef.current?.());
		return () => {
			pcall(task.cancel, job);
		};
	}, [phase]);

	React.useEffect(() => {
		if (!visible) {
			return undefined;
		}
		GamepadNavigationService.BeginOverlayFocus();
		if (result && UserInputService.GamepadEnabled && hostRef.current !== undefined) {
			GamepadNavigationService.FocusClaim(hostRef.current);
		}
		return () => GamepadNavigationService.EndOverlayFocus();
	}, [visible, result]);

	if (!visible) {
		return undefined;
	}

	const accent = phase === "success" ? Palette.mint : phase === "fail" ? Palette.coral : Palette.mango;
	const title = phase === "pending" ? "Buying" : phase === "success" ? "Bought" : "Didn't go through";
	const detail =
		phase === "pending"
			? "Finish checkout in the Roblox window."
			: phase === "success"
				? "It's on your account."
				: props.detail ?? "You weren't charged.";

	// enter: card drops 10px into place; result: a single small settle, nothing loops
	const enter = t.map((s) => (still ? 1 : math.clamp(s / 0.18, 0, 1)));
	const settle = t.map((s) => (still || !result ? 0 : math.max(0, 1 - s / 0.28)));

	const dismiss = () => {
		if (result) {
			Audio.play("purchaseExit");
			dismissRef.current?.();
		}
	};

	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={400}>
			<textbutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Palette.void}
				BackgroundTransparency={0.55}
				AutoButtonColor={false}
				Text=""
				Modal={true}
				Selectable={false}
				ZIndex={400}
				Event={{ Activated: dismiss }}
			/>
			<Panel
				size={UDim2.fromOffset(CARD_W, CARD_H)}
				position={enter.map((a) => new UDim2(0.5, -CARD_W / 2, 0.5, -CARD_H / 2 + math.floor((1 - a) * 10)))}
				accent={accent}
				background={Palette.panelRaised}
				padding={0}
				reveal={enter}
				highlight={result}
				reducedMotion={still}
				zIndex={401}
			>
				<uiscale Scale={settle.map((s) => 1 + s * 0.03)} />
				{/* left marker: dots while waiting, a solid accent bar once it's decided */}
				{phase === "pending" ? (
					<frame Size={UDim2.fromOffset(48, 30)} Position={UDim2.fromOffset(8, 24)} BackgroundTransparency={1} ZIndex={402}>
						<Dot index={0} t={t} still={still} />
						<Dot index={1} t={t} still={still} />
						<Dot index={2} t={t} still={still} />
					</frame>
				) : (
					<frame Size={UDim2.fromOffset(4, 40)} Position={UDim2.fromOffset(22, 22)} BackgroundColor3={accent} BorderSizePixel={0} ZIndex={402}>
						<uicorner CornerRadius={new UDim(1, 0)} />
					</frame>
				)}
				<Text
					value={title}
					size={17}
					color={phase === "pending" ? Palette.cream : accent}
					weight={Enum.FontWeight.Heavy}
					transparency={enter.map((a) => 1 - a)}
					position={UDim2.fromOffset(60, 16)}
					sizeConstraint={new UDim2(1, -72, 0, 22)}
					zIndex={402}
				/>
				<Text
					value={detail}
					size={13}
					color={Palette.creamSoft}
					wrap={true}
					transparency={enter.map((a) => 1 - a)}
					position={UDim2.fromOffset(60, 40)}
					sizeConstraint={new UDim2(1, -72, 0, 32)}
					zIndex={402}
				/>
				{/* tap target over the card, also what gamepad focus lands on */}
				<textbutton
					ref={hostRef}
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text=""
					Selectable={result}
					ZIndex={403}
					Event={{ Activated: dismiss }}
				/>
			</Panel>
		</frame>
	);
}

export { PurchaseOverlay, PURCHASE_RESULT_HOLD, PURCHASE_RESULT_HOLD_REDUCED, PURCHASE_PENDING_FAILSAFE };
