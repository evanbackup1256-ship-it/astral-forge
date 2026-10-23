import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";

export const FORGE_RADIUS = 18;

/** Thin brass inner rule laid over a padded Panel (03-forge card treatment). */
export function BrassRule({ pad, transparency = 0.75 }: { pad: number; transparency?: number }) {
	return (
		<frame
			Size={new UDim2(1, pad * 2 - 4, 1, pad * 2 - 4)}
			Position={UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={1}
		>
			<uicorner CornerRadius={new UDim(0, FORGE_RADIUS - 2)} />
			<uistroke Color={Palette.brass} Thickness={1} Transparency={transparency} />
		</frame>
	);
}
