import React from "@rbxts/react";
const TweenService = game.GetService("TweenService");
const UserInputService = game.GetService("UserInputService");
const ContextActionService = game.GetService("ContextActionService");
const GuiService = game.GetService("GuiService");
let jumpBindings = 0;

function inside(gui: GuiObject | undefined, point: Vector2): boolean {
	if (gui === undefined) {
		return false;
	}
	const at = gui.AbsolutePosition;
	const size = gui.AbsoluteSize;
	return point.X >= at.X && point.X <= at.X + size.X && point.Y >= at.Y && point.Y <= at.Y + size.Y;
}
import { luaProp, reactLoose, kit } from "./viewRuntime";
import { KeyLabel } from "../../CoreKit/GamepadNavigationService";

// The group you're scrolling through stays pinned to the top of a list until the next group
// pushes it off. Shared by the guild member list and the crew roster.
export const STICKY_H = 24;

export interface StickyGroup {
	top: number;
	label: string;
	color: Color3;
	/** shown on the jump button when the label doesn't already carry one */
	count?: number;
}

// the group you last jumped to in each list, for this session only (nothing is saved)
const lastJump = new Map<string, string>();
// "OFFICERS · 4" and "OFFICERS" are the same group
function groupKey(label: string): string {
	const [at] = label.find(" ·", 1, true);
	return at !== undefined ? label.sub(1, at - 1) : label;
}
// after opening, focus moving onto the menu can nudge the scroller; don't let that close it
const OPEN_GUARD = 0.35;

// "QUIET · 3"; labels that already count (OFFICERS · 4) or are one person (YOU, LEADER) stay as they are
function jumpText(group: StickyGroup): string {
	if (group.count === undefined || group.label === "YOU" || group.label === "LEADER" || group.label.find("·", 1, true)[0] !== undefined) {
		return group.label;
	}
	return `${group.label} · ${group.count}`;
}

/**
 * `inner` lists own their scroller (a FlatList sitting next to the label): the label stays at the
 * top and reads that scroller's canvas. Otherwise the label rides inside a page scroller and slides
 * down with it until the list ends.
 */
/** Tap the label to jump straight to another group (You, Leader, Quiet, ...). */
export function StickyGroupLabel(props: { groups: StickyGroup[]; height: number; inner?: boolean; reducedMotion?: unknown; listId?: string }) {
	const [menuOpen, setMenuOpen] = React.useState(false);
	const menuOpenRef = React.useRef(false);
	menuOpenRef.current = menuOpen;
	const menuRef = React.useRef<Frame>();
	const openedAt = React.useRef(0);
	const openMenuRef = React.useRef<(open: boolean) => void>(() => undefined);
	const feedback = luaProp(kit("CoreKit", "interaction"), "InteractionFeedback") as unknown as { tick?: (this: void) => void };

	const hostRef = React.useRef<Frame>();
	const [offset, setOffset] = React.useBinding(0);
	const [current, setCurrent] = React.useState(0);
	// redraw the key hint when a controller is plugged in or pulled out
	const [gamepad, setGamepad] = React.useState(UserInputService.GamepadEnabled);
	React.useEffect(() => {
		const sync = () => task.defer(() => setGamepad(UserInputService.GamepadEnabled));
		const plugged = UserInputService.GamepadConnected.Connect(sync);
		const pulled = UserInputService.GamepadDisconnected.Connect(sync);
		return () => {
			plugged.Disconnect();
			pulled.Disconnect();
		};
	}, []);
	const currentRef = React.useRef(0);
	currentRef.current = current;
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
			// scrolling by hand closes the jump menu
			if (menuOpenRef.current && os.clock() - openedAt.current > OPEN_GUARD) {
				openMenuRef.current(false);
			}
		};
		update();
		const connection = scroller.GetPropertyChangedSignal("CanvasPosition").Connect(update);
		return () => connection.Disconnect();
	}, [props.height, inner]);
	// open/close by tap, B or L3. The menu takes gamepad focus while open and hands it back after.
	const focusBefore = React.useRef<GuiObject>();
	const openMenu = (open: boolean) => {
		if (open === menuOpenRef.current) {
			return;
		}
		menuOpenRef.current = open;
		if (open) {
			openedAt.current = os.clock();
		}
		setMenuOpen(open);
		if (!UserInputService.GamepadEnabled) {
			return;
		}
		if (open) {
			focusBefore.current = GuiService.SelectedObject;
			task.defer(() => {
				const menu = menuRef.current;
				if (menu !== undefined && menuOpenRef.current) {
					// start on the group you jumped to last time, else the one you're in
					openedAt.current = os.clock();
					const remembered = props.listId !== undefined ? lastJump.get(props.listId) : undefined;
					const groups = groupsRef.current;
					let target: Instance | undefined;
					if (remembered !== undefined) {
						target = menu.FindFirstChild(`jump-${remembered}`);
					}
					const here = groups[math.min(currentRef.current, groups.size() - 1)];
					if (target === undefined && here !== undefined) {
						target = menu.FindFirstChild(`jump-${groupKey(here.label)}`);
					}
					GuiService.Select(target !== undefined && target.IsA("GuiObject") ? target : menu);
				}
			});
		} else {
			const back = focusBefore.current;
			focusBefore.current = undefined;
			const selected = GuiService.SelectedObject;
			if (back !== undefined && back.Parent !== undefined && (selected === undefined || (menuRef.current !== undefined && selected.IsDescendantOf(menuRef.current)))) {
				GuiService.SelectedObject = back;
			}
		}
	};
	openMenuRef.current = openMenu;
	React.useEffect(() => {
		jumpBindings += 1;
		const name = `AstralForgeStickyJump${jumpBindings}`;
		ContextActionService.BindActionAtPriority(
			name,
			(_: string, inputState: Enum.UserInputState, input: InputObject) => {
				if (inputState !== Enum.UserInputState.Begin) {
					return Enum.ContextActionResult.Pass;
				}
				if (input.KeyCode === Enum.KeyCode.ButtonB) {
					if (!menuOpenRef.current) {
						return Enum.ContextActionResult.Pass;
					}
					openMenu(false);
					return Enum.ContextActionResult.Sink;
				}
				// L3 opens the menu for the list that has gamepad focus
				const container = hostRef.current?.Parent;
				const selected = GuiService.SelectedObject;
				const mine = container !== undefined && selected !== undefined && selected.IsDescendantOf(container);
				if (!mine && !menuOpenRef.current) {
					return Enum.ContextActionResult.Pass;
				}
				feedback.tick?.();
				openMenu(!menuOpenRef.current);
				return Enum.ContextActionResult.Sink;
			},
			false,
			2300,
			Enum.KeyCode.ButtonB,
			Enum.KeyCode.ButtonL3,
		);
		return () => ContextActionService.UnbindAction(name);
	}, []);
	React.useEffect(() => {
		if (!menuOpen) {
			return undefined;
		}
		// a tap or click anywhere outside the bar and the menu closes it
		const connection = UserInputService.InputBegan.Connect((input) => {
			const kind = input.UserInputType;
			if (kind !== Enum.UserInputType.MouseButton1 && kind !== Enum.UserInputType.Touch) {
				return;
			}
			const point = new Vector2(input.Position.X, input.Position.Y);
			const inset = GuiService.GetGuiInset()[0];
			const gui = point.sub(inset);
			const hit = (target: GuiObject | undefined) => inside(target, point) || inside(target, gui);
			if (!hit(hostRef.current) && !hit(menuRef.current)) {
				openMenu(false);
			}
		});
		return () => connection.Disconnect();
	}, [menuOpen]);
	const jump = (group: StickyGroup) => {
		const top = group.top;
		if (props.listId !== undefined) {
			lastJump.set(props.listId, groupKey(group.label));
		}
		openMenu(false);
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
			value: menuOpen ? "CLOSE" : gamepad ? `JUMP · ${KeyLabel(Enum.KeyCode.ButtonL3, "L3")}` : "JUMP",
			size: 10,
			color: luaProp(Palette, "muted"),
			weight: Enum.FontWeight.Bold,
			align: Enum.TextXAlignment.Right,
			fit: true,
			minSize: 8,
			position: new UDim2(1, -100, 0, 5),
			sizeConstraint: UDim2.fromOffset(90, 14),
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
					openMenu(!menuOpenRef.current);
				},
			},
		}),
		menuOpen
			? reactLoose.createElement(
					"frame",
					{
						ref: menuRef,
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
						reactLoose.createElement(
							"frame",
							{
								key: `jump-${i}`,
								Name: `jump-${groupKey(g.label)}`,
								Size: UDim2.fromOffset(0, 44),
								AutomaticSize: Enum.AutomaticSize.X,
								BackgroundTransparency: 1,
								BorderSizePixel: 0,
								LayoutOrder: i,
							},
							reactLoose.createElement(Button as never, {
							text: jumpText(g),
							onClick: () => jump(g),
							sound: "tick",
							color: g.color,
							textColor: luaProp(Palette, "ink"),
							size: UDim2.fromOffset(0, 44),
							hug: true,
							layoutOrder: i,
							highlight: i === current,
							// the group you're in also gets the pilot icon, so it doesn't rely on colour alone
							icon: i === current ? "Pilot.4" : undefined,
							reducedMotion: props.reducedMotion,
						}),
						),
					),
				)
			: undefined,
	);
}
