import React from "@rbxts/react";
import * as FancyText from "../../UiCore/fancyText";
import { FancyTitle } from "../../UiCore/FancyTitle";
import { useMotionSettings } from "../../MotionKit/motion";
import { Fonts, Iron } from "./tokens";

export interface TextProps {
	text: string;
	size: number;
	color?: Color3;
	font?: Font;
	align?: "Left" | "Center" | "Right";
	/** fixed box; text shrinks (never below `minSize`) instead of spilling */
	box?: UDim2;
	minSize?: number;
	/** allow several lines; the box then grows with the text */
	multiline?: boolean;
	position?: UDim2;
	anchor?: Vector2;
	order?: number;
	transparency?: number | React.Binding<number>;
	zIndex?: number;
	children?: React.ReactNode;
}

export function Text(props: TextProps) {
	const align = Enum.TextXAlignment[props.align ?? "Left"];
	const grows = props.multiline === true;
	const scale = useMotionSettings().textScale ?? 1;
	const size = math.floor(props.size * scale + 0.5);
	return (
		<textlabel
			Text={props.text}
			FontFace={props.font ?? Fonts.bold}
			TextColor3={props.color ?? Iron.text()}
			TextSize={size}
			TextScaled={!grows}
			TextWrapped={grows}
			TextXAlignment={align}
			TextTransparency={props.transparency ?? 0}
			BackgroundTransparency={1}
			Size={props.box ?? (grows ? new UDim2(1, 0, 0, 0) : new UDim2(1, 0, 0, size + 6))}
			AutomaticSize={grows ? Enum.AutomaticSize.Y : Enum.AutomaticSize.None}
			Position={props.position}
			AnchorPoint={props.anchor}
			LayoutOrder={props.order ?? 0}
			ZIndex={props.zIndex}
			RichText
		>
			{!grows && <uitextsizeconstraint MaxTextSize={size} MinTextSize={math.min(size, props.minSize ?? math.max(9, size - 6))} />}
			{props.children}
		</textlabel>
	);
}

export interface TitleProps {
	text: string;
	size: number;
	color?: Color3;
	rarity?: string;
	/** wave/rainbow/shake tags, played at full strength */
	tags?: FancyText.TitleTag[];
	align?: "Left" | "Center" | "Right";
	order?: number;
	hover?: "clickpop" | "smash";
}

/** Every heading is a FancyText title (animated, gradient-swept), never a plain label. */
export function Title(props: TitleProps) {
	const config: FancyText.TitleConfig = {
		text: props.text,
		size: props.size,
		color: props.color ?? Iron.text(),
		weight: Enum.FontWeight.Heavy,
		align: props.align ?? "Left",
		shadow: true,
		state: props.rarity !== undefined ? { rarity: props.rarity } : undefined,
		parts: props.tags !== undefined ? [{ text: props.text, tags: props.tags }] : undefined,
		scale: false,
	};
	return (
		<frame Size={new UDim2(1, 0, 0, props.size + 10)} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<FancyTitle config={config} size={UDim2.fromScale(1, 1)} hover={props.hover} />
		</frame>
	);
}
