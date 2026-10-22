// ForgeButton: kept as a name only. Renders Forge2's single Button (design/Button.tsx -> press.tsx,
// the old client's useButtonChrome + ButtonShimmer), so there is one press path for button/tab/chip.
import React from "@rbxts/react";
import { Button, ButtonProps } from "./Button";

export interface ForgeButtonProps extends Omit<ButtonProps, "highlight"> {
	/** the old client's idle "live" shimmer for the action that matters */
	glint?: boolean;
	tooltip?: string;
}

export function ForgeButton(props: ForgeButtonProps) {
	const { glint, tooltip: _tooltip, ...rest } = props;
	return <Button {...rest} highlight={glint === true && props.disabled !== true} />;
}
