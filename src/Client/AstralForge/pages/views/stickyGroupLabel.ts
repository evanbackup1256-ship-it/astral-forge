import React from "@rbxts/react";
import { luaProp, reactLoose, kit } from "./viewRuntime";

// The group you're scrolling through stays pinned to the top of a list until the next group
// pushes it off. Shared by the guild member list and the crew roster.
export const STICKY_H = 24;

export interface StickyGroup {
	top: number;
	label: string;
	color: Color3;
}

/**
 * `inner` lists own their scroller (a FlatList sitting next to the label): the label stays at the
 * top and reads that scroller's canvas. Otherwise the label rides inside a page scroller and slides
 * down with it until the list ends.
 */
export function StickyGroupLabel(props: { groups: StickyGroup[]; height: number; inner?: boolean }) {
	const hostRef = React.useRef<Frame>();
	const [offset, setOffset] = React.useBinding(0);
	const [current, setCurrent] = React.useState(0);
	const groupsRef = React.useRef(props.groups);
	groupsRef.current = props.groups;
	const inner = props.inner === true;
	React.useEffect(() => {
		const host = hostRef.current;
		const container = host?.Parent as GuiObject | undefined;
		const scroller = inner
			? container?.FindFirstChildWhichIsA("ScrollingFrame", true)
			: host?.FindFirstAncestorWhichIsA("ScrollingFrame");
		if (host === undefined || container === undefined || scroller === undefined) {
			return undefined;
		}
		const update = () => {
			const scrolled = inner
				? scroller.CanvasPosition.Y
				: scroller.AbsolutePosition.Y - container.AbsolutePosition.Y;
			if (!inner) {
				setOffset(math.clamp(scrolled, 0, math.max(0, props.height - STICKY_H)));
			}
			const groups = groupsRef.current;
			let index = 0;
			for (let i = 0; i < groups.size(); i++) {
				if (groups[i].top <= scrolled + STICKY_H) {
					index = i;
				}
			}
			setCurrent(index);
		};
		update();
		const connection = scroller.GetPropertyChangedSignal("CanvasPosition").Connect(update);
		return () => connection.Disconnect();
	}, [props.height, inner]);
	const Palette = luaProp(kit("CoreKit", "theme"), "Palette");
	const Text = luaProp(kit("UiCore", "ui"), "Text");
	const group = props.groups[math.min(current, props.groups.size() - 1)];
	return reactLoose.createElement(
		"frame",
		{
			ref: hostRef,
			Size: new UDim2(1, 0, 0, STICKY_H),
			Position: offset.map((y) => UDim2.fromOffset(0, y)),
			BackgroundColor3: luaProp(Palette, "panelRaised") as unknown as Color3,
			BackgroundTransparency: 0.08,
			BorderSizePixel: 0,
			ZIndex: 20,
		},
		reactLoose.createElement("uicorner", { CornerRadius: new UDim(0, 6) }),
		reactLoose.createElement(Text as never, {
			value: group !== undefined ? group.label : "",
			size: 11,
			color: group !== undefined ? group.color : luaProp(Palette, "muted"),
			weight: Enum.FontWeight.Heavy,
			fit: true,
			minSize: 9,
			position: UDim2.fromOffset(10, 4),
			sizeConstraint: new UDim2(1, -20, 0, 16),
			zIndex: 21,
		}),
	);
}
