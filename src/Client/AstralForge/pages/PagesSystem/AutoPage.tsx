import React from "@rbxts/react";
import { Palette } from "../../CoreKit/theme";

export interface AutoPageProps {
	accent?: Color3;
	scrollRef?: React.Ref<ScrollingFrame>;
	tailPad?: number;
	children?: React.ReactNode;
}

// A scrolling page for content that sizes itself. PageScaffold wants a fixed pixel height per
// section; pages built from auto-sized panels (Command, Admin) use this instead: the canvas grows
// with whatever is inside, and the host ref is the scrolling frame itself.
export function AutoPage(props: AutoPageProps) {
	return (
		<scrollingframe
			ref={props.scrollRef}
			Size={UDim2.fromScale(1, 1)}
			CanvasSize={new UDim2()}
			AutomaticCanvasSize={Enum.AutomaticSize.Y}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ScrollBarThickness={4}
			ScrollBarImageColor3={props.accent ?? Palette.muted}
			ScrollBarImageTransparency={0.42}
			VerticalScrollBarInset={Enum.ScrollBarInset.ScrollBar}
			ScrollingDirection={Enum.ScrollingDirection.Y}
			ElasticBehavior={Enum.ElasticBehavior.WhenScrollable}
			ClipsDescendants={true}
			Active={true}
			Selectable={false}
		>
			<uilistlayout FillDirection={Enum.FillDirection.Vertical} SortOrder={Enum.SortOrder.LayoutOrder} />
			{props.children}
			<frame Size={new UDim2(1, 0, 0, props.tailPad ?? 72)} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1000} />
		</scrollingframe>
	);
}
