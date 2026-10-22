// Cast-iron surfaces. The shading and brass lip come from the shared ironFace() plate (its own
// child frame, so a host never carries two UIGradients); an optional rainbow seam runs on the
// shared Rainbow clock so every rainbow on screen moves in step.
import React from "@rbxts/react";
import { ironFace } from "../../UiCore/castIron";
import { useSpring } from "../../MotionKit/motion";
import { RainbowGradient } from "../../UiCore/rainbowFx";
import { Corner, Iron } from "./tokens";

export interface PanelProps {
	size?: UDim2;
	position?: UDim2;
	order?: number;
	pad?: number;
	color?: Color3;
	/** a thin rainbow seam along the top edge, for the surface that matters most on the page */
	seam?: boolean;
	/** rarity / state passed to the shared rainbow look */
	rarity?: string;
	/** grow with content instead of a fixed height */
	auto?: boolean;
	layout?: "column" | "row" | "none";
	spacing?: number;
	scale?: React.Binding<number> | number;
	children?: React.ReactNode;
}

export function Panel(props: PanelProps) {
	const pad = props.pad ?? 0;
	const layout = props.layout ?? "column";
	return (
		<frame
			Size={props.size ?? new UDim2(1, 0, 0, 0)}
			Position={props.position}
			AutomaticSize={props.auto === false ? Enum.AutomaticSize.None : Enum.AutomaticSize.Y}
			BackgroundColor3={props.color ?? Iron.face()}
			BorderSizePixel={0}
			LayoutOrder={props.order ?? 0}
			ClipsDescendants={false}
		>
			<uicorner CornerRadius={new UDim(0, Corner.panel)} />
			<uistroke Color={Iron.edge()} Transparency={0.55} Thickness={1} ApplyStrokeMode={Enum.ApplyStrokeMode.Border} />
			{props.scale !== undefined && <uiscale Scale={props.scale} />}
			{ironFace()}
			{props.seam === true && (
				<frame
					key="Seam"
					Size={new UDim2(1, -Corner.panel * 2, 0, 2)}
					Position={UDim2.fromOffset(Corner.panel, 0)}
					BackgroundColor3={Color3.fromRGB(255, 255, 255)}
					BorderSizePixel={0}
					ZIndex={3}
				>
					<RainbowGradient base={Iron.brass()} state={{ rarity: props.rarity ?? "Legendary", active: true }} style="flow" />
				</frame>
			)}
			<frame key="Body" Size={new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} ZIndex={2}>
				<uipadding
					PaddingTop={new UDim(0, pad)}
					PaddingBottom={new UDim(0, pad)}
					PaddingLeft={new UDim(0, pad)}
					PaddingRight={new UDim(0, pad)}
				/>
				{layout !== "none" && (
					<uilistlayout
						FillDirection={layout === "row" ? Enum.FillDirection.Horizontal : Enum.FillDirection.Vertical}
						Padding={new UDim(0, props.spacing ?? 8)}
						SortOrder={Enum.SortOrder.LayoutOrder}
						VerticalAlignment={layout === "row" ? Enum.VerticalAlignment.Center : Enum.VerticalAlignment.Top}
					/>
				)}
				{props.children}
			</frame>
		</frame>
	);
}

export interface CardProps extends PanelProps {
	/** rarity / accent colour drawn as a left rail */
	accent?: Color3;
	selected?: boolean;
	onPress?: () => void;
}

/** A Panel that can be picked: accent rail, selected glow, whole card pressable. */
export function Card(props: CardProps) {
	const accent = props.accent ?? Iron.brass();
	const [hover, setHover] = React.useState(false);
	return (
		<frame Size={props.size ?? new UDim2(1, 0, 0, 0)} AutomaticSize={Enum.AutomaticSize.Y} BackgroundTransparency={1} LayoutOrder={props.order ?? 0}>
			<Panel {...props} order={0} color={props.selected === true ? Iron.raised() : props.color} seam={props.seam ?? props.selected === true}>
				{props.children}
			</Panel>
			<frame
				key="Rail"
				Size={new UDim2(0, 3, 1, -16)}
				Position={UDim2.fromOffset(0, 8)}
				BackgroundColor3={accent}
				BackgroundTransparency={hover || props.selected === true ? 0 : 0.35}
				BorderSizePixel={0}
				ZIndex={4}
			/>
			{props.onPress !== undefined && (
				<textbutton
					key="Hit"
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					Text=""
					ZIndex={5}
					Selectable
					Event={{
						Activated: () => props.onPress?.(),
						MouseEnter: () => setHover(true),
						MouseLeave: () => setHover(false),
						SelectionGained: () => setHover(true),
						SelectionLost: () => setHover(false),
					}}
				/>
			)}
		</frame>
	);
}

/** A filled bar; the fill springs to its value and rides the shared rainbow when full. */
export function Meter(props: { value: number; color?: Color3; order?: number; height?: number }) {
	const fill = useSpring(math.clamp(props.value, 0, 1), false, 140, 20, 0);
	const full = props.value >= 1;
	return (
		<frame Size={new UDim2(1, 0, 0, props.height ?? 10)} BackgroundColor3={Iron.sunk()} BorderSizePixel={0} LayoutOrder={props.order ?? 0}>
			<uicorner CornerRadius={new UDim(1, 0)} />
			<frame Size={fill.map((v) => UDim2.fromScale(math.max(0.02, v), 1))} BackgroundColor3={full ? Color3.fromRGB(255, 255, 255) : (props.color ?? Iron.brass())} BorderSizePixel={0}>
				<uicorner CornerRadius={new UDim(1, 0)} />
				{full && <RainbowGradient base={props.color ?? Iron.brass()} state={{ active: true, progress: 1 }} style="flow" />}
			</frame>
		</frame>
	);
}
