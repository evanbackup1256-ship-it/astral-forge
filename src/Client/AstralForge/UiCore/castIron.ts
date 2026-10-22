// Cast-iron surface language shared by the Shop, Bazaar, Crates and Trading pages: tight tool-steel
// corners, a face that darkens toward its foot, one struck brass highlight along the top edge and a
// faint brass hairline. Purely decorative children; no motion of their own, so every existing
// animation on the host keeps running untouched.
import React from "@rbxts/react";

export const IRON_RADIUS = 4;
export const BRASS = Color3.fromRGB(170, 126, 70);
export const BRASS_HOT = Color3.fromRGB(214, 170, 104);

const FALLOFF = new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(1, 0.4)]);
const SHADE = new ColorSequence(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 180));

/** gradient falloff + brass top lip; pass `lip: false` for small chips */
export function ironFace(lip = true): React.Element {
	const out: React.Element[] = [
		React.createElement("uigradient", { key: "IronFace", Rotation: 90, Transparency: FALLOFF, Color: SHADE }),
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
			}),
		);
	}
	return React.createElement(React.Fragment, { key: "Iron" }, ...out);
}
