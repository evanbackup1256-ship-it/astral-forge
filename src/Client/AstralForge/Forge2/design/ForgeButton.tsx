// ForgeButton: Forge2's button API on top of the current client's Button, so hover lift, press
// dip, click impact/ripple, the hover shimmer, the "live" idle shimmer, the breathing highlight
// stroke, the error shake and the loading spinner are the SAME code with the same springs, timing
// and easing as the old client (useButtonChrome / ButtonShimmer). Only the colours come from
// Forge2's Night Iron roles. Additive: Forge2's own Button is untouched.
import React from "@rbxts/react";
import { Button as ClientButton } from "../../UiCore/ui";
import { HIT, Iron } from "./tokens";

export interface ForgeButtonProps {
	text: string;
	onPress: () => void;
	width?: number;
	stretch?: boolean;
	height?: number;
	tone?: "brass" | "iron" | "ember" | "quiet";
	disabled?: boolean;
	busy?: boolean;
	order?: number;
	/** the old client's idle "live" shimmer + breathing stroke, for the action that matters */
	glint?: boolean;
	/** bump to play the old client's refusal shake */
	shakeToken?: number;
	tooltip?: string;
}

function colors(tone: ForgeButtonProps["tone"]): [Color3, Color3, boolean] {
	if (tone === "iron") return [Iron.raised(), Iron.text(), false];
	if (tone === "ember") return [Iron.ember(), Iron.sunk(), false];
	if (tone === "quiet") return [Iron.sunk(), Iron.soft(), true];
	return [Iron.brass(), Iron.sunk(), false];
}

export function ForgeButton(props: ForgeButtonProps) {
	const [fill, label, outline] = colors(props.tone);
	const height = math.max(props.height ?? HIT, HIT);
	const size = props.stretch === true ? new UDim2(1, 0, 0, height) : new UDim2(0, props.width ?? 140, 0, height);
	return (
		<frame Size={size} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<ClientButton
				text={props.text}
				onClick={props.onPress}
				size={UDim2.fromScale(1, 1)}
				color={fill}
				textColor={label}
				outline={outline}
				disabled={props.disabled === true}
				loading={props.busy === true}
				highlight={props.glint === true && props.disabled !== true}
				shakeToken={props.shakeToken ?? 0}
				tooltip={props.tooltip}
			/>
		</frame>
	);
}
