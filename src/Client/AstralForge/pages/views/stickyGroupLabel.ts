import React from "@rbxts/react";
const TweenService = game.GetService("TweenService");
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
/** Tap the label to jump straight to another group (You, Leader, Quiet, ...). */
export function StickyGroupLabel(props: { groups: StickyGroup[]; height: number; inner?: boolean; reducedMotion?: unknown }) {
	const [menuOpen, setMenuOpen] = React.useState(false);
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
	const jump = (top: number) => {
		setMenuOpen(false);
		const host = hostRef.current;
		const container = host?.Parent as GuiObject | undefined;
		const scroller = inner
			? container?.FindFirstChildWhichIsA("ScrollingFrame", true)
			: host?.FindFirstAncestorWhichIsA("ScrollingFrame");
		if (container === undefined || scroller === undefined) {
			return;
		}
		// land with the group's first row just under the label, so the label names it
		const y = inner
			? top
			: scroller.CanvasPosition.Y + (container.AbsolutePosition.Y + top - STICKY_H) - scroller.AbsolutePosition.Y;
		const maxY = math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y);
		const goal = new Vector2(scroller.CanvasPosition.X, math.clamp(y, 0, maxY));
		if (props.reducedMotion !== undefined && props.reducedMotion !== false) {
			scroller.CanvasPosition = goal;
		} else {
			TweenService.Create(scroller, new TweenInfo(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CanvasPosition: goal }).Play();
		}
	};
	const Palette = luaProp(kit("CoreKit", "theme"), "Palette");
	const Button = luaProp(kit("UiCore", "ui"), "Button");
	const feedback = luaProp(kit("CoreKit", "interaction"), "InteractionFeedback") as unknown as { tick?: (this: void) => void };
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
		reactLoose.createElement(Text as never, {
			value: menuOpen ? "CLOSE" : "JUMP",
			size: 10,
			color: luaProp(Palette, "muted"),
			weight: Enum.FontWeight.Bold,
			align: Enum.TextXAlignment.Right,
			fit: true,
			minSize: 8,
			position: new UDim2(1, -70, 0, 5),
			sizeConstraint: UDim2.fromOffset(60, 14),
			zIndex: 21,
		}),
		// 44px tall hit area centred on the 24px bar
		reactLoose.createElement("textbutton", {
			Size: new UDim2(1, 0, 0, 44),
			Position: UDim2.fromOffset(0, -10),
			BackgroundTransparency: 1,
			Text: "",
			AutoButtonColor: false,
			ZIndex: 22,
			Event: {
				Activated: () => {
					feedback.tick?.();
					setMenuOpen(!menuOpen);
				},
			},
		}),
		menuOpen
			? reactLoose.createElement(
					"frame",
					{
						Size: new UDim2(1, 0, 0, 44),
						Position: UDim2.fromOffset(0, STICKY_H + 6),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
						ZIndex: 23,
					},
					reactLoose.createElement("uilistlayout", {
						FillDirection: Enum.FillDirection.Horizontal,
						Padding: new UDim(0, 8),
						SortOrder: Enum.SortOrder.LayoutOrder,
					}),
					...props.groups.map((g, i) =>
						reactLoose.createElement(Button as never, {
							key: `jump-${i}`,
							text: g.label,
							onClick: () => jump(g.top),
							sound: "tick",
							color: g.color,
							textColor: luaProp(Palette, "ink"),
							size: UDim2.fromOffset(0, 44),
							hug: true,
							layoutOrder: i,
							highlight: i === current,
							reducedMotion: props.reducedMotion,
						}),
					),
				)
			: undefined,
	);
}
