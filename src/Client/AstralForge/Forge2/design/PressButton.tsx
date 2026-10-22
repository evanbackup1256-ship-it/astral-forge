// The current client's button motion on a Night Iron face. Hover lift, press dip, tilt, the
// click impact pop, gamepad focus ring, breathing highlight stroke, hover/focus shimmer sweep and
// the button sounds all come from UiCore's own useButtonChrome / ButtonShimmer, so springs,
// timing and easing are identical to the old client. Same props as Forge2's Button.
import React from "@rbxts/react";
import { buttonAudioCue } from "../../AudioKit/audio";
import { useGlowStroke } from "../../MotionKit/motion";
import { ButtonShimmer, useButtonChrome } from "../../UiCore/ui";
import { isTouchOnly } from "../../CoreKit/inputLayer";
import { darken, lighten } from "../../CoreKit/theme";
import type { ButtonProps } from "./Button";
import { Corner, Fonts, HIT, Iron } from "./tokens";

function fill(tone: ButtonProps["tone"]): Color3 {
	if (tone === "iron") return Iron.raised();
	if (tone === "ember") return Iron.ember();
	if (tone === "quiet") return Iron.sunk();
	return Iron.brass();
}

export function PressButton(props: ButtonProps) {
	const off = props.disabled === true || props.busy === true;
	const filled = props.tone === undefined || props.tone === "brass" || props.tone === "ember";
	// highlighted (filled + live) buttons shimmer idle and breathe, exactly like the old highlight prop
	const highlight = filled && !off && props.glint !== false;
	const height = math.max(props.height ?? HIT, isTouchOnly() ? HIT : 36);
	const size = props.stretch === true ? new UDim2(1, 0, 0, height) : new UDim2(0, props.width ?? 140, 0, height);
	const chrome = useButtonChrome(props.onPress, false, off, buttonAudioCue(props.text), true, highlight, { text: props.text, size } as never);
	const breathe = useGlowStroke(highlight && chrome.active, false, 0.5, 0.4, 0.62, 1.15);
	const base = fill(props.tone);
	const face = React.joinBindings([chrome.hoverAmount, chrome.pressAmount]).map(([h, p]) =>
		base.Lerp(lighten(base, 0.1), math.clamp(h, 0, 1)).Lerp(darken(base, 0.1), math.clamp(p, 0, 1)),
	);
	const hover = props.onHover;
	return (
		<frame Size={size} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<imagebutton
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				AutoButtonColor={false}
				Active={!off}
				Selectable={!off}
				Event={{
					...chrome.events,
					MouseEnter: (rbx: ImageButton, ...rest: unknown[]) => {
						(chrome.events.MouseEnter as ((r: ImageButton, ...a: unknown[]) => void) | undefined)?.(rbx, ...rest);
						hover?.(true);
					},
					MouseLeave: (rbx: ImageButton, ...rest: unknown[]) => {
						(chrome.events.MouseLeave as ((r: ImageButton, ...a: unknown[]) => void) | undefined)?.(rbx, ...rest);
						hover?.(false);
					},
				} as never}
			>
				<frame
					Size={UDim2.fromScale(1, 1)}
					Position={chrome.offsetY.map((y) => new UDim2(0.5, 0, 0.5, y))}
					AnchorPoint={new Vector2(0.5, 0.5)}
					Rotation={chrome.tilt}
					BackgroundColor3={face}
					BackgroundTransparency={off ? 0.45 : 0}
					BorderSizePixel={0}
				>
					<uiscale Scale={chrome.touchScale} />
					<uicorner CornerRadius={new UDim(0, Corner.card)} />
					<uistroke
						Color={filled ? Iron.text() : Iron.brassDeep()}
						Transparency={filled ? (highlight ? breathe : 1) : 0.3}
						Thickness={filled ? 2 : 1}
						ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					/>
					<ButtonShimmer hoverAmount={chrome.hoverAmount} shimmer={chrome.shimmer} idle={highlight} live={chrome.shimmerLive} radius={Corner.card} zIndex={2} />
					<textlabel
						Size={new UDim2(1, -28, 1, 0)}
						Position={UDim2.fromOffset(14, 0)}
						BackgroundTransparency={1}
						Text={props.busy === true ? "…" : props.text}
						FontFace={Fonts.heavy}
						TextColor3={filled ? Iron.sunk() : Iron.text()}
						TextTransparency={off ? 0.4 : 0}
						TextSize={props.textSize ?? 17}
						TextScaled
						ZIndex={3}
					>
						<uitextsizeconstraint MaxTextSize={props.textSize ?? 17} MinTextSize={11} />
					</textlabel>
					{/* click impact + gamepad focus ring, same springs as the old button */}
					<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} ZIndex={4}>
						<uicorner CornerRadius={new UDim(0, Corner.card)} />
						<uistroke Color={Iron.text()} Thickness={2} Transparency={chrome.focusRing.map((a) => 1 - a * 0.98)} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
					</frame>
					<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Color3.fromRGB(255, 255, 255)} BackgroundTransparency={chrome.impact.map((v) => 1 - v * 0.35)} BorderSizePixel={0} ZIndex={4}>
						<uicorner CornerRadius={new UDim(0, Corner.card)} />
					</frame>
				</frame>
			</imagebutton>
		</frame>
	);
}
