import React from "@rbxts/react";
import { useHoverPress, useIdleGlint, GLINT_TRANSPARENCY } from "../../MotionKit/motion";
import { isTouchOnly } from "../../CoreKit/inputLayer";
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
	onHover?: (on: boolean) => void;
}

function fill(tone: ButtonProps["tone"]): Color3 {
	if (tone === "iron") return Iron.raised();
	if (tone === "ember") return Iron.ember();
	if (tone === "quiet") return Iron.sunk();
	return Iron.brass();
}

export function Button(props: ButtonProps) {
	const [scale, events] = useHoverPress(false, 0.04, 0.06);
	const filled = props.tone === undefined || props.tone === "brass" || props.tone === "ember";
	const glint = useIdleGlint(filled && props.glint !== false && props.disabled !== true, 7);
	const off = props.disabled === true || props.busy === true;
	const height = math.max(props.height ?? HIT, isTouchOnly() ? HIT : 36);
	const size = props.stretch === true ? new UDim2(1, 0, 0, height) : new UDim2(0, props.width ?? 140, 0, height);
	const textColor = filled ? Iron.sunk() : Iron.text();
	return (
		<textbutton
			Size={size}
			BackgroundColor3={fill(props.tone)}
			BackgroundTransparency={off ? 0.45 : 0}
			AutoButtonColor={false}
			Text={props.busy === true ? "…" : props.text}
			FontFace={Fonts.heavy}
			TextColor3={textColor}
			TextTransparency={off ? 0.4 : 0}
			TextSize={props.textSize ?? 17}
			TextScaled
			Active={!off}
			Selectable={!off}
			LayoutOrder={props.order ?? 0}
			Event={{
				Activated: () => {
					if (!off) props.onPress();
				},
				MouseEnter: () => {
					events.MouseEnter();
					props.onHover?.(true);
				},
				MouseLeave: () => {
					events.MouseLeave();
					props.onHover?.(false);
				},
				MouseButton1Down: events.MouseButton1Down,
				MouseButton1Up: events.MouseButton1Up,
				SelectionGained: () => props.onHover?.(true),
				SelectionLost: () => props.onHover?.(false),
			}}
		>
			<uiscale Scale={scale} />
			<uicorner CornerRadius={new UDim(0, Corner.card)} />
			<uitextsizeconstraint MaxTextSize={props.textSize ?? 17} MinTextSize={11} />
			<uipadding PaddingLeft={new UDim(0, 14)} PaddingRight={new UDim(0, 14)} />
			{!filled && <uistroke Color={Iron.brassDeep()} Transparency={0.3} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />}
			{filled && (
				<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Color3.fromRGB(255, 255, 255)} BackgroundTransparency={0} BorderSizePixel={0} ZIndex={0}>
					<uicorner CornerRadius={new UDim(0, Corner.card)} />
					<uigradient Transparency={GLINT_TRANSPARENCY} Rotation={20} Offset={glint.map((x) => new Vector2(x, 0))} />
				</frame>
			)}
		</textbutton>
	);
}
