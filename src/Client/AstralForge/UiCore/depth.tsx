// Purpose: code-built depth for the revamp. Soft shadows and glows are stacks of rounded frames
// with falling transparency (no baked images); the rim is a UIStroke lit by a vertical gradient.
import React from "@rbxts/react";

export interface SoftShadowProps {
	radius?: number;
	/** how far the shadow spreads past the card, in px */
	spread?: number;
	/** px the shadow drops below the card */
	drop?: number;
	color?: Color3;
	/** transparency of the darkest (innermost) layer */
	strength?: number;
	layers?: number;
	zIndex?: number;
}

/** A blurred-looking shadow: `layers` rounded frames, each a little larger and fainter. */
export function SoftShadow(props: SoftShadowProps) {
	const radius = props.radius ?? 18;
	const spread = props.spread ?? 18;
	const drop = props.drop ?? 8;
	const layers = math.clamp(props.layers ?? 6, 2, 10);
	const strength = props.strength ?? 0.82;
	const color = props.color ?? new Color3(0, 0, 0);
	const items: React.Element[] = [];
	for (let index = 0; index < layers; index++) {
		const t = (index + 1) / layers;
		const grow = math.round(spread * t);
		// every layer adds a little darkness; together they fall off like a gaussian edge
		const alpha = 1 - ((1 - strength) * 1.4 * (1.15 - t)) / layers;
		items.push(
			<frame
				key={`s${index}`}
				AnchorPoint={new Vector2(0.5, 0.5)}
				Position={new UDim2(0.5, 0, 0.5, drop * t)}
				Size={new UDim2(1, grow * 2, 1, grow * 2)}
				BackgroundColor3={color}
				BackgroundTransparency={math.clamp(alpha, 0, 1)}
				BorderSizePixel={0}
				ZIndex={props.zIndex ?? 0}
			>
				<uicorner CornerRadius={new UDim(0, radius + grow)} />
			</frame>,
		);
	}
	return (
		<frame BackgroundTransparency={1} Size={UDim2.fromScale(1, 1)} ZIndex={props.zIndex ?? 0}>
			{items}
		</frame>
	);
}

/** A coloured halo built the same way as SoftShadow, centred, for selected or rare items. */
export function Glow(props: { color: Color3; radius?: number; spread?: number; strength?: number; zIndex?: number }) {
	return (
		<SoftShadow
			color={props.color}
			radius={props.radius}
			spread={props.spread ?? 14}
			drop={0}
			strength={props.strength ?? 0.86}
			layers={5}
			zIndex={props.zIndex}
		/>
	);
}

/** Rim light: 1px stroke that is brighter on the top edge, plus an optional brass inner rule. */
export function RimLight(props: { color: Color3; transparency?: number; thickness?: number; inner?: Color3 }) {
	return (
		<>
			<uistroke
				Color={props.color}
				Thickness={props.thickness ?? 1}
				Transparency={props.transparency ?? 0}
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
			>
				<uigradient
					Rotation={90}
					Transparency={
						new NumberSequence([
							new NumberSequenceKeypoint(0, 0),
							new NumberSequenceKeypoint(0.5, 0.45),
							new NumberSequenceKeypoint(1, 0.7),
						])
					}
				/>
			</uistroke>
			{props.inner !== undefined ? (
				<frame
					key="InnerRule"
					BackgroundTransparency={1}
					Position={UDim2.fromOffset(3, 3)}
					Size={new UDim2(1, -6, 1, -6)}
				>
					<uicorner CornerRadius={new UDim(0, 15)} />
					<uistroke Color={props.inner} Transparency={0.75} Thickness={1} />
				</frame>
			) : undefined}
		</>
	);
}
