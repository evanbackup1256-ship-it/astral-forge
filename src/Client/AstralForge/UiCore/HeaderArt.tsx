// Purpose: uploaded page-header strip behind a hero title, with the readability fades built in code.
// Drop it as the first child of a padded Panel; `inset` is that Panel's padding so the art reaches the panel edge.
import React from "@rbxts/react";
import { Palette } from "../CoreKit/theme";
import { HEADER_ART, type HeaderArtName } from "../ArtKit/uiArt";

export function HeaderArt(props: { art: HeaderArtName; inset: number; radius?: number; fill?: Color3; transparency?: number }) {
	const inset = props.inset;
	const fill = props.fill ?? Palette.panelRaised;
	return (
		<frame
			Size={new UDim2(1, inset * 2, 1, inset * 2)}
			Position={UDim2.fromOffset(-inset, -inset)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ClipsDescendants={true}
			ZIndex={0}
		>
			<uicorner CornerRadius={new UDim(0, props.radius ?? 18)} />
			<imagelabel
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				Image={HEADER_ART[props.art]}
				ScaleType={Enum.ScaleType.Crop}
				ImageTransparency={props.transparency ?? 0.3}
				ZIndex={0}
			/>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={fill} BorderSizePixel={0} ZIndex={0}>
				<uigradient
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0.05),
							new NumberSequenceKeypoint(0.45, 0.55),
							new NumberSequenceKeypoint(1, 0.9),
						])
					}
				/>
			</frame>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundColor3={Palette.ink} BorderSizePixel={0} ZIndex={0}>
				<uigradient
					Rotation={90}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 1),
							new NumberSequenceKeypoint(0.6, 1),
							new NumberSequenceKeypoint(1, 0.45),
						])
					}
				/>
			</frame>
		</frame>
	);
}
