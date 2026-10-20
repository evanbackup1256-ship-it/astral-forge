import React from "@rbxts/react";
import { Audio } from "../AudioKit/audio";
import * as GamepadNavigationService from "../CoreKit/GamepadNavigationService";
import { Palette } from "../CoreKit/theme";
import { isReducedMotion } from "../MotionPreference";

// Purchase status card: a small card with three bouncing dots while Roblox checkout runs,
// then it settles into a plain success or failure line and gets out of the way.

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");

const PURCHASE_RESULT_HOLD = 1.8;
const PURCHASE_RESULT_HOLD_REDUCED = 1.4;
const PURCHASE_PENDING_FAILSAFE = 45;

const CARD_W = 248;
const CARD_H = 84;
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
			<textbutton
				ref={hostRef}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Size={UDim2.fromOffset(CARD_W, CARD_H)}
				Position={enter.map((a) => new UDim2(0.5, 0, 0.5, math.floor((1 - a) * 10)))}
				BackgroundColor3={Palette.panelRaised}
				BackgroundTransparency={enter.map((a) => 1 - a)}
				AutoButtonColor={false}
				Text=""
				Selectable={result}
				ZIndex={401}
				Event={{ Activated: dismiss }}
			>
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke Color={accent} Thickness={1} Transparency={settle.map((s) => 0.55 - s * 0.45)} />
				<uiscale Scale={settle.map((s) => 1 + s * 0.03)} />
				{/* left marker: dots while waiting, a solid accent bar once it's decided */}
				<frame Size={UDim2.fromOffset(56, CARD_H)} BackgroundTransparency={1} ZIndex={402}>
					{phase === "pending" ? (
						<frame Size={UDim2.fromOffset(48, 30)} Position={UDim2.fromOffset(8, 24)} BackgroundTransparency={1} ZIndex={402}>
							<Dot index={0} t={t} still={still} />
							<Dot index={1} t={t} still={still} />
							<Dot index={2} t={t} still={still} />
						</frame>
					) : (
						<frame
							Size={UDim2.fromOffset(4, 40)}
							Position={UDim2.fromOffset(20, 22)}
							BackgroundColor3={accent}
							BorderSizePixel={0}
							ZIndex={402}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</frame>
					)}
				</frame>
				<textlabel
					Size={new UDim2(1, -72, 0, 22)}
					Position={UDim2.fromOffset(60, 18)}
					BackgroundTransparency={1}
					Text={title}
					TextColor3={phase === "pending" ? Palette.cream : accent}
					TextTransparency={enter.map((a) => 1 - a)}
					TextSize={17}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansBold)}
					TextXAlignment={Enum.TextXAlignment.Left}
					ZIndex={402}
				/>
				<textlabel
					Size={new UDim2(1, -72, 0, 30)}
					Position={UDim2.fromOffset(60, 40)}
					BackgroundTransparency={1}
					Text={detail}
					TextColor3={Palette.muted}
					TextTransparency={enter.map((a) => 1 - a)}
					TextSize={13}
					TextWrapped={true}
					TextYAlignment={Enum.TextYAlignment.Top}
					FontFace={Font.fromEnum(Enum.Font.BuilderSans)}
					TextXAlignment={Enum.TextXAlignment.Left}
					ZIndex={402}
				/>
			</textbutton>
		</frame>
	);
}

export { PurchaseOverlay, PURCHASE_RESULT_HOLD, PURCHASE_RESULT_HOLD_REDUCED, PURCHASE_PENDING_FAILSAFE };
