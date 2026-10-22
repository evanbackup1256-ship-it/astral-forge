// Tab and Chip: the two "pick one" controls. Tabs switch whole views; chips filter a list.
import React from "@rbxts/react";
import { useChangePop, useHoverPress } from "../../MotionKit/motion";
import { RainbowGradient } from "../../UiCore/rainbowFx";
import { Corner, Fonts, HIT, Iron } from "./tokens";

export interface TabProps {
	text: string;
	active: boolean;
	onPress: () => void;
	width?: number;
	order?: number;
	/** small count dot, e.g. claims waiting */
	badge?: number;
}

export function Tab(props: TabProps) {
	const [scale, events] = useHoverPress(false, 0.03, 0.05);
	const pop = useChangePop(props.badge ?? 0);
	return (
		<textbutton
			Size={new UDim2(0, props.width ?? 120, 0, HIT)}
			BackgroundColor3={props.active ? Iron.raised() : Iron.sunk()}
			BackgroundTransparency={props.active ? 0 : 0.4}
			AutoButtonColor={false}
			Text={props.text}
			FontFace={props.active ? Fonts.heavy : Fonts.bold}
			TextColor3={props.active ? Iron.text() : Iron.muted()}
			TextSize={16}
			LayoutOrder={props.order ?? 0}
			Selectable
			Event={{ Activated: props.onPress, ...events }}
		>
			<uiscale Scale={scale} />
			<uicorner CornerRadius={new UDim(0, Corner.card)} />
			{props.active && (
				<frame Size={new UDim2(1, -16, 0, 2)} Position={new UDim2(0, 8, 1, -3)} BackgroundColor3={Color3.fromRGB(255, 255, 255)} BorderSizePixel={0}>
					<RainbowGradient base={Iron.brass()} state={{ selected: true, active: true }} style="flow" />
				</frame>
			)}
			{(props.badge ?? 0) > 0 && (
				<frame Size={UDim2.fromOffset(18, 18)} Position={new UDim2(1, -6, 0, -4)} AnchorPoint={new Vector2(1, 0)} BackgroundColor3={Iron.ember()} BorderSizePixel={0}>
					<uiscale Scale={pop} />
					<uicorner CornerRadius={new UDim(1, 0)} />
					<textlabel Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Text={tostring(props.badge)} FontFace={Fonts.heavy} TextColor3={Iron.sunk()} TextSize={12} />
				</frame>
			)}
		</textbutton>
	);
}

export interface ChipProps {
	text: string;
	on: boolean;
	onPress: () => void;
	color?: Color3;
	order?: number;
}

export function Chip(props: ChipProps) {
	const [scale, events] = useHoverPress(false, 0.05, 0.07);
	const tint = props.color ?? Iron.brass();
	const width = math.max(64, props.text.size() * 9 + 28);
	return (
		<textbutton
			Size={new UDim2(0, width, 0, HIT)}
			BackgroundColor3={props.on ? tint : Iron.sunk()}
			BackgroundTransparency={props.on ? 0.15 : 0.35}
			AutoButtonColor={false}
			Text={props.text}
			FontFace={Fonts.bold}
			TextColor3={props.on ? Iron.sunk() : Iron.soft()}
			TextSize={14}
			LayoutOrder={props.order ?? 0}
			Selectable
			Event={{ Activated: props.onPress, ...events }}
		>
			<uiscale Scale={scale} />
			<uicorner CornerRadius={new UDim(0, Corner.chip)} />
			<uistroke Color={tint} Transparency={props.on ? 1 : 0.55} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
		</textbutton>
	);
}
