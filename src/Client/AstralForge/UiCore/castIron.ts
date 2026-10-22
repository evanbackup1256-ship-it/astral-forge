// Cast-iron surface language shared by the Shop, Bazaar, Crates and Trading pages: tight tool-steel
// corners, a face that darkens toward its foot, one struck brass highlight along the top edge and a
// faint brass hairline. Purely decorative children; no motion of their own, so every existing
// animation on the host keeps running untouched.
import React from "@rbxts/react";

export const IRON_RADIUS = 4;
export const BRASS = Color3.fromRGB(170, 126, 70);
export const BRASS_HOT = Color3.fromRGB(214, 170, 104);

// Shading lives on its own child plate ("IronShade") at ZIndex 0, so the host tile never gains a
// UIGradient of its own: a tile that already has (or later gets) a gradient keeps it untouched,
// and there is no way for two UIGradients to land on one instance.
const SHADE_FALLOFF = new NumberSequence([new NumberSequenceKeypoint(0, 1), new NumberSequenceKeypoint(1, 0.6)]);

/** falloff shade plate + brass top lip; pass `lip: false` for small chips */
export function ironFace(lip = true): React.Element {
	const out: React.Element[] = [
		React.createElement(
			"frame",
			{
				key: "IronShade",
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Color3.fromRGB(0, 0, 0),
				BackgroundTransparency: 0,
				BorderSizePixel: 0,
				Active: false,
				Selectable: false,
				ZIndex: 0,
			},
			React.createElement("uicorner", { CornerRadius: new UDim(0, IRON_RADIUS) }),
			React.createElement("uigradient", { Rotation: 90, Transparency: SHADE_FALLOFF }),
		),
	];
	if (lip) {
		out.push(
			React.createElement("frame", {
				key: "IronLip",
				Position: UDim2.fromOffset(6, 1),
				Size: new UDim2(1, -12, 0, 1),
				BackgroundColor3: BRASS,
				BackgroundTransparency: 0.55,
				BorderSizePixel: 0,
				Active: false,
			}),
		);
	}
	return React.createElement(React.Fragment, { key: "Iron" }, ...out);
}
