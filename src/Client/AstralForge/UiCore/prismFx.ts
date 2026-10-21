import React from "@rbxts/react";
import { useClock } from "../MotionKit/motion";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const Rainbow = require(script.Parent!.Parent!.WaitForChild("Rainbow") as ModuleScript) as {
	loop(this: void, name: string): ColorSequence;
};

const PERIOD = 40;
const TAU = math.pi * 2;
export const SEQUENCES: Record<string, ColorSequence> = {
	Celestial: new ColorSequence([
		new ColorSequenceKeypoint(0, Color3.fromRGB(170, 218, 232)),
		new ColorSequenceKeypoint(0.5, Color3.fromRGB(236, 240, 242)),
		new ColorSequenceKeypoint(1, Color3.fromRGB(170, 218, 232)),
	]),
	// indigo, magenta and gold mixed in OKLab: deep-space colour with even brightness, no candy pastels
	Astral: Rainbow.loop("nebula"),
};
export const CORE: Record<string, Color3> = {
	Celestial: Color3.fromRGB(206, 232, 240),
	Astral: Color3.fromRGB(214, 200, 236),
};
const SPARKS: Array<[number, number, number]> = [
	[0.08, 0.18, 7],
	[0.92, 0.12, 9],
	[0.82, 0.8, 11],
	[0.2, 0.86, 8],
	[0.5, 0.06, 10],
	[0.04, 0.55, 12],
	[0.96, 0.5, 13],
	[0.36, 0.94, 9],
	[0.66, 0.92, 7],
	[0.62, 0.1, 14],
];

export function isAscended(rarity: unknown) {
	return rarity === "Celestial" || rarity === "Astral";
}

export interface PrismAuraProps {
	rarity?: string;
	zIndex?: number;
	intensity?: number | React.Binding<number>;
	corner?: number;
	thickness?: number;
	rays?: boolean;
	clipRays?: boolean;
	sparks?: boolean;
}

export function PrismAura(props: PrismAuraProps) {
	const rarity = props.rarity === "Astral" ? "Astral" : "Celestial";
	const clock = useClock(true, 1, PERIOD, false);
	const zIndex = props.zIndex ?? 1;
	let intensity = props.intensity;
	if (intensity === undefined) {
		intensity = 1;
	}
	const scaled = <T>(map: (t: number, k: number) => T): React.Binding<T> => {
		if (typeIs(intensity, "number")) {
			const k = intensity;
			return clock.map((t) => map(t, k));
		}
		return React.joinBindings([clock, intensity as React.Binding<number>]).map((values) =>
			map(values[0], math.clamp(values[1], 0, 1)),
		);
	};
	const children: Record<string, unknown> = {
		Rim: h(
			"frame",
			{ Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: zIndex + 2 },
			h("uicorner", { CornerRadius: new UDim(0, props.corner ?? 12) }),
			h(
				"uistroke",
				{
					Color: new Color3(1, 1, 1),
					Thickness: props.thickness ?? 2.5,
					Transparency: scaled((t, k) => 1 - k * (0.82 + 0.18 * math.sin(((t * TAU) / PERIOD) * 8))),
					ApplyStrokeMode: Enum.ApplyStrokeMode.Border,
				},
				h("uigradient", { Color: SEQUENCES[rarity], Rotation: clock.map((t) => (t * 90) % 360) }),
			),
		),
	};
	if (props.rays !== false) {
		const rays: Record<string, unknown> = {};
		for (let index = 1; index <= 6; index++) {
			rays[`Ray${index}`] = h(
				"frame",
				{
					Size: new UDim2(0, 10, 1.6, 0),
					Position: UDim2.fromScale(0.5, 0.5),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: clock.map((t) => (index - 1) * 30 + ((t * 9) % 360)),
					BackgroundColor3: CORE[rarity],
					BackgroundTransparency: scaled((t, k) => 1 - k * (0.16 + 0.1 * math.sin(((t * TAU) / PERIOD) * (3 + index)))),
					BorderSizePixel: 0,
					ZIndex: zIndex,
				},
				h("uigradient", {
					Transparency: new NumberSequence([
						new NumberSequenceKeypoint(0, 1),
						new NumberSequenceKeypoint(0.5, 0),
						new NumberSequenceKeypoint(1, 1),
					]),
					Rotation: 90,
				}),
			);
		}
		children.Rays = h(
			"frame",
			{
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				BorderSizePixel: 0,
				ClipsDescendants: props.clipRays !== false,
				ZIndex: zIndex,
			},
			rays,
		);
	}
	if (props.sparks !== false) {
		for (const [index, spot] of ipairs(SPARKS)) {
			children[`Spark${index}`] = h("frame", {
				Size: scaled((t, k) => {
					const wave = math.max(0, math.sin(((t * TAU) / PERIOD) * spot[2] + index));
					const px = math.round((3 + wave * 6) * k);
					return UDim2.fromOffset(px, px);
				}),
				Position: UDim2.fromScale(spot[0], spot[1]),
				AnchorPoint: new Vector2(0.5, 0.5),
				Rotation: 45,
				BackgroundColor3: CORE[rarity],
				BackgroundTransparency: scaled((t, k) => {
					const wave = math.max(0, math.sin(((t * TAU) / PERIOD) * spot[2] + index));
					return 1 - k * wave;
				}),
				BorderSizePixel: 0,
				ZIndex: zIndex + 3,
			});
		}
	}
	return h(
		"frame",
		{ Name: "PrismAura", Size: UDim2.fromScale(1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: zIndex },
		children,
	);
}
