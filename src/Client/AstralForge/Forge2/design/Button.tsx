import React from "@rbxts/react";
import { useIdleGlint, GLINT_TRANSPARENCY, useFlash, useGlowStroke } from "../../MotionKit/motion";
import { Audio } from "../../AudioKit/audio";
import { InteractionFeedback } from "../../CoreKit/interaction";
import { Palette } from "../../CoreKit/theme";
import { isTouchOnly } from "../../CoreKit/inputLayer";
import { FocusRing, PressLayers, pressEvents, usePress } from "./press";
import { Corner, Fonts, HIT, Iron } from "./tokens";

export interface ButtonProps {
	text: string;
	onPress: () => void;
	width?: number;
	/** fill the parent width instead */
	stretch?: boolean;
	height?: number;
	tone?: "brass" | "iron" | "ember" | "quiet";
	disabled?: boolean;
	busy?: boolean;
	order?: number;
	textSize?: number;
	/** an occasional shine across filled buttons */
	glint?: boolean;
	/** the old client's idle shimmer (highlight) for the call to action */
	highlight?: boolean;
	/** click cue; "auto" (default) picks it from the label like the old Button, false for silent */
	sound?: string | false;
	onHover?: (on: boolean) => void;
	/** bump to play the old client's refusal shake (same 0.42s flash and sine path as UiCore Button) */
	shakeToken?: number;
}

function fill(tone: ButtonProps["tone"]): Color3 {
	if (tone === "iron") return Iron.raised();
	if (tone === "ember") return Iron.ember();
	if (tone === "quiet") return Iron.sunk();
	return Iron.brass();
}

// Hover/press/click motion, shimmer and impact are the old client's (see press.tsx); the face is
// the Forge2 cast-iron look. The face rides the old offset dip over a 5px shadow like UiCore Button.
export function Button(props: ButtonProps) {
	const filled = props.tone === undefined || props.tone === "brass" || props.tone === "ember";
	const off = props.disabled === true || props.busy === true;
	const press = usePress(props.onPress, off, { idle: props.highlight === true, sound: props.sound, label: props.text });
	const glint = useIdleGlint(filled && props.glint !== false && props.disabled !== true, 7);
	const height = math.max(props.height ?? HIT, isTouchOnly() ? HIT : 36);
	const size = props.stretch === true ? new UDim2(1, 0, 0, height) : new UDim2(0, props.width ?? 140, 0, height);
	const textColor = filled ? Iron.sunk() : Iron.text();
	const base = fill(props.tone);
	// old highlight breathing stroke (same useGlowStroke curve as the old client / PressButton)
	const breathe = useGlowStroke(props.highlight === true && !off && press.active, false, 0.5, 0.4, 0.62, 1.15);
	const shakeToken = props.shakeToken ?? 0;
	const shake = useFlash(shakeToken, false, 0.42);
	const lastShake = React.useRef(shakeToken);
	React.useEffect(() => {
		if (shakeToken !== lastShake.current) {
			lastShake.current = shakeToken;
			if (shakeToken > 0) {
				Audio.play("noticeError");
				InteractionFeedback.fail();
			}
		}
	}, [shakeToken]);
	return (
		<textbutton
			Size={size}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Text=""
			Active={!off}
			Selectable={!off}
			LayoutOrder={props.order ?? 0}
			Event={pressEvents<TextButton>(press, props.onHover)}
		>
			<frame Size={UDim2.fromScale(1, 1)} AnchorPoint={new Vector2(0.5, 0.5)} Position={shake.map((a) => new UDim2(0.5, math.sin(a * math.pi * 4.5) * a * 7, 0.5, 0))} Rotation={press.tilt} BackgroundTransparency={1}>
				<uiscale Scale={press.touchScale} />
				<frame Size={UDim2.fromScale(1, 1)} Position={press.offsetY.map((y) => UDim2.fromOffset(0, 5 - y))} BackgroundColor3={Iron.void()} BackgroundTransparency={off ? 1 : 0.55} BorderSizePixel={0}>
					<uicorner CornerRadius={new UDim(0, Corner.card)} />
				</frame>
				<frame
					Size={UDim2.fromScale(1, 1)}
					Position={press.offsetY.map((y) => UDim2.fromOffset(0, y))}
					BackgroundColor3={base}
					BackgroundTransparency={off ? 0.45 : 0}
					BorderSizePixel={0}
					ClipsDescendants
					ZIndex={2}
				>
					<uicorner CornerRadius={new UDim(0, Corner.card)} />
					{!filled && <uistroke Color={Iron.brassDeep()} Transparency={0.3} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />}
					{filled && props.highlight === true && !off && <uistroke Color={Iron.text()} Thickness={2} Transparency={breathe} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />}
					{filled && (
						<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Color3.fromRGB(255, 255, 255)} BackgroundTransparency={0} BorderSizePixel={0} ZIndex={1}>
							<uicorner CornerRadius={new UDim(0, Corner.card)} />
							<uigradient Transparency={GLINT_TRANSPARENCY} Rotation={20} Offset={glint.map((x) => new Vector2(x, 0))} />
						</frame>
					)}
					<frame
						Size={UDim2.fromScale(1, 1)}
						BackgroundColor3={Palette.coral}
						BackgroundTransparency={shake.map((a) => math.clamp(1 - a * 0.6, 0.4, 1))}
						BorderSizePixel={0}
						ZIndex={6}
						Visible={shake.map((a) => a > 0.02)}
					>
						<uicorner CornerRadius={new UDim(0, Corner.card)} />
					</frame>
					<PressLayers press={press} radius={Corner.card} color={base} idle={props.highlight === true} zIndex={2} />
					<textlabel
						Size={UDim2.fromScale(1, 1)}
						BackgroundTransparency={1}
						Text={props.busy === true ? "…" : props.text}
						FontFace={Fonts.heavy}
						TextColor3={textColor}
						TextTransparency={off ? 0.4 : 0}
						TextSize={props.textSize ?? 17}
						TextScaled
						ZIndex={8}
					>
						<uitextsizeconstraint MaxTextSize={props.textSize ?? 17} MinTextSize={11} />
						<uipadding PaddingLeft={new UDim(0, 14)} PaddingRight={new UDim(0, 14)} />
					</textlabel>
					<FocusRing press={press} radius={Corner.card} color={Iron.text()} />
				</frame>
			</frame>
		</textbutton>
	);
}
