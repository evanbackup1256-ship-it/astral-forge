// PressButton: kept as a name only. Renders Forge2's single Button (design/Button.tsx -> press.tsx,
// the old client's useButtonChrome + ButtonShimmer + breathing stroke). Live filled buttons
// shimmer idle and breathe, as before.
import React from "@rbxts/react";
import { Button, ButtonProps } from "./Button";

export function PressButton(props: ButtonProps) {
	const filled = props.tone === undefined || props.tone === "brass" || props.tone === "ember";
	const off = props.disabled === true || props.busy === true;
	return <Button {...props} glint={false} highlight={props.highlight ?? (filled && !off && props.glint !== false)} />;
}
