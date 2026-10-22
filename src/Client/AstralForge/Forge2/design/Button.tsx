import React from "@rbxts/react";
import { isTouchOnly } from "../../CoreKit/inputLayer";
import { ButtonShimmer, useButtonChrome } from "../../UiCore/ui";
import { Corner, Fonts, HIT, Iron } from "./tokens";

// Forge2's pressable. Hover lift, press dip, click impact flash, tilt, touch squash and the
// shimmer sweep all come from the current client's own button chrome (useButtonChrome +
// ButtonShimmer), so timing and easing are exactly the old ones; only the cast-iron face differs.

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
	/** idle shimmer (on by default for filled buttons, as before) */
	glint?: boolean;
	onHover?: (on: boolean) => void;
}

function fill(tone: ButtonProps["tone"]): Color3 {
	if (tone === "iron") return Iron.raised();
	if (tone === "ember") return Iron.ember();
	if (tone === "quiet") return Iron.sunk();
	return Iron.brass();
}

type Handler = (...args: unknown[]) => void;

export function Button(props: ButtonProps) {
	const filled = props.tone === undefined || props.tone === "brass" || props.tone === "ember";
	const off = props.disabled === true || props.busy === true;
	const idle = filled && props.glint !== false && !off;
	const chrome = useButtonChrome(() => props.onPress(), false, off, "click", true, idle);
	const height = math.max(props.height ?? HIT, isTouchOnly() ? HIT : 36);
	const size = props.stretch === true ? new UDim2(1, 0, 0, height) : new UDim2(0, props.width ?? 140, 0, height);
	const base = fill(props.tone);
	const textColor = filled ? Iron.sunk() : Iron.text();
	const corner = <uicorner CornerRadius={new UDim(0, Corner.card)} />;
	const raw = chrome.events as unknown as Record<string, Handler | undefined>;
	const events = {
		...raw,
		MouseEnter: (...args: unknown[]) => {
			raw.MouseEnter?.(...args);
			props.onHover?.(true);
		},
		MouseLeave: (...args: unknown[]) => {
			raw.MouseLeave?.(...args);
			props.onHover?.(false);
		},
		SelectionGained: (...args: unknown[]) => {
			raw.SelectionGained?.(...args);
			props.onHover?.(true);
		},
		SelectionLost: (...args: unknown[]) => {
			raw.SelectionLost?.(...args);
			props.onHover?.(false);
		},
	} as unknown as React.InstanceEvent<ImageButton>;
	return (
		<imagebutton
			Size={size}
			BackgroundTransparency={1}
			AutoButtonColor={false}
			Image=""
			Active={!off}
			Selectable={!off}
			LayoutOrder={props.order ?? 0}
			Event={events}
		>
			<frame Size={UDim2.fromScale(1, 1)} Position={chrome.offsetY.map((y) => UDim2.fromOffset(0, 5 - y))} BackgroundColor3={Iron.void()} BackgroundTransparency={off ? 0.85 : 0.6} BorderSizePixel={0} ZIndex={0}>
				{corner}
			</frame>
			<frame Size={UDim2.fromScale(1, 1)} Position={chrome.offsetY.map((y) => UDim2.fromOffset(0, y))} Rotation={chrome.tilt} BackgroundTransparency={1} ZIndex={1}>
				<uiscale Scale={chrome.touchScale} />
				<frame
					Size={UDim2.fromScale(1, 1)}
					BackgroundColor3={chrome.hoverAmount.map((h) => base.Lerp(new Color3(1, 1, 1), math.clamp(h, 0, 1) * 0.08))}
					BackgroundTransparency={off ? 0.45 : 0}
					BorderSizePixel={0}
					ZIndex={1}
				>
					{corner}
					{!filled && <uistroke Color={Iron.brassDeep()} Transparency={0.3} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />}
				</frame>
				{!off && <ButtonShimmer hoverAmount={chrome.hoverAmount} shimmer={chrome.shimmer} live={chrome.shimmerLive} idle={idle} zIndex={2} radius={Corner.card} />}
				{!off && (
					<frame
						Size={UDim2.fromScale(1, 1)}
						BackgroundColor3={new Color3(1, 1, 1)}
						BackgroundTransparency={chrome.impact.map((a) => math.clamp(1 - a * 0.48, 0.52, 1))}
						Visible={chrome.impact.map((a) => a > 0.05)}
						BorderSizePixel={0}
						ZIndex={4}
					>
						{corner}
					</frame>
				)}
				{!off && (
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Visible={chrome.impact.map((a) => a > 0.03)} BorderSizePixel={0} ZIndex={5}>
						{corner}
						<uistroke
							ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
							Color={base}
							Thickness={chrome.impact.map((a) => 1 + a * 2)}
							Transparency={chrome.impact.map((a) => math.clamp(1 - a * 0.78, 0.18, 1))}
						/>
					</frame>
				)}
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text={props.busy === true ? "…" : props.text}
					FontFace={Fonts.heavy}
					TextColor3={textColor}
					TextTransparency={off ? 0.4 : 0}
					TextSize={props.textSize ?? 17}
					TextScaled
					ZIndex={6}
				>
					<uitextsizeconstraint MaxTextSize={props.textSize ?? 17} MinTextSize={11} />
					<uipadding PaddingLeft={new UDim(0, 14)} PaddingRight={new UDim(0, 14)} />
				</textlabel>
			</frame>
		</imagebutton>
	);
}
