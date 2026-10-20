// Tooltips, in React. One bubble for the whole game, rendered by <TooltipProvider> (mounted once at
// the UI root) through a portal into its own top-layer ScreenGui.
//
// Any component calls useTooltip(content) and spreads the returned handlers into its Event table
// (mergeEvents joins them with handlers the component already has). Content is a string or
// { title, body, hint, accent }. The bubble waits before fading in (quicker right after another
// was shown), sits beside its target, clamps to the screen, and goes on leave, press or scroll.
import React from "@rbxts/react";
import { InteractionFeedback } from "./CoreKit/interaction";
import ReactRoblox from "@rbxts/react-roblox";
import { Palette } from "./CoreKit/theme";

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

export type TooltipContent = string | { title?: string; body?: string; hint?: string; accent?: Color3 };

const SHOW_DELAY = 0.45;
const WARM_DELAY = 0.08;
const WARM_WINDOW = 0.6;
const PAD_DELAY = 0.7;
// gamepad focus moves in steps, so a warm tip waits a touch longer than the mouse one
const PAD_WARM_DELAY = 0.25;
// a long-press tip stays this long after the finger lifts, unless something else is touched
const TOUCH_LINGER = 1.6;
// a finger that slides this far is scrolling, not asking for a tip
const TOUCH_SLOP = 12;
const LONG_PRESS = 0.45;
const GAP = 8;
const EDGE = 10;
const FADE_IN = 0.12;

const LABELS: { [key: string]: string } = {
	Close: "Close", Back: "Back", Settings: "Settings", Menu: "Menu", Search: "Search",
	Refresh: "Refresh", Send: "Send", Chat: "Chat", Mail: "Mail", Inventory: "Inventory",
	Shop: "Shop", Play: "Play", Pause: "Pause", Hide: "Hide", Lock: "Locked", Check: "Done",
	Chevron: "More", Visit: "Visit", Wave: "Wave", Gift: "Gift", Leaderboard: "Ranks",
	Guide: "Guide", Credits: "Credits", Crew: "Crew", Guild: "Guild", Admin: "Admin",
	Rewards: "Rewards", Calendar: "Calendar", Code: "Codes", Travel: "Travel", Loadout: "Loadout",
};

// name for an icon-only button, by icon concept
export function labelFor(icon: string | undefined): string | undefined {
	if (!typeIs(icon, "string")) {
		return undefined;
	}
	const [matched] = icon.match("^[^.]+");
	return LABELS[(matched as string | undefined) ?? icon];
}

function hasContent(content: TooltipContent | undefined): content is TooltipContent {
	if (content === undefined) return false;
	if (typeIs(content, "string")) return content !== "";
	return (content.title !== undefined && content.title !== "") || (content.body !== undefined && content.body !== "");
}

// the shared store the provider renders ------------------------------------------------------------

interface Shown {
	id: number;
	target: GuiObject;
	content: TooltipContent;
}

let shown: Shown | undefined = undefined;
let pending: thread | undefined = undefined;
let lastHiddenAt = -math.huge;
let nextId = 0;
const listeners = new Set<() => void>();
function emit() {
	for (const listener of listeners) listener();
}

function cancelPending() {
	if (pending !== undefined) {
		pcall(task.cancel, pending);
		pending = undefined;
	}
}

function hideId(id: number | undefined) {
	cancelPending();
	if (shown !== undefined && (id === undefined || shown.id === id)) {
		shown = undefined;
		lastHiddenAt = os.clock();
		emit();
	}
}

export function hideTooltip() {
	hideId(undefined);
}

// For lists that move their own highlight (Quick Find) instead of using gamepad selection:
// show a tip beside `target` after the usual focus delay. Returns a function that hides it again.
export function showTooltipFor(target: GuiObject, content: TooltipContent): () => void {
	nextId += 1;
	const id = nextId;
	scheduleShow(id, target, () => content, os.clock() - lastHiddenAt < WARM_WINDOW ? PAD_WARM_DELAY : PAD_DELAY);
	return () => {
		if (shown !== undefined && shown.id === id) {
			hideId(id);
		} else if (shown === undefined) {
			cancelPending();
		}
	};
}

function scheduleShow(id: number, target: GuiObject, read: () => TooltipContent | undefined, delayTime: number) {
	cancelPending();
	pending = task.delay(delayTime, () => {
		pending = undefined;
		const content = read();
		if (!hasContent(content) || !target.IsDescendantOf(game) || !target.Visible) return;
		shown = { id, target, content };
		// a long-press tip lands with a light tick so the finger knows it worked
		if (pressStart !== undefined) InteractionFeedback.tick();
		emit();
	});
}

const MODIFIERS = new Set<Enum.KeyCode>([
	Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt, Enum.KeyCode.LeftMeta, Enum.KeyCode.RightMeta,
	Enum.KeyCode.LeftSuper, Enum.KeyCode.RightSuper, Enum.KeyCode.CapsLock,
]);

// where the current long press started, so a slide can cancel it
let pressStart: Vector2 | undefined = undefined;

UserInputService.InputChanged.Connect((input) => {
	if (input.UserInputType === Enum.UserInputType.MouseWheel && shown !== undefined) hideTooltip();
	if (input.UserInputType === Enum.UserInputType.Touch && pressStart !== undefined) {
		const at = new Vector2(input.Position.X, input.Position.Y);
		if (at.sub(pressStart).Magnitude > TOUCH_SLOP) {
			pressStart = undefined;
			hideTooltip();
		}
	}
});

// the same things close every tip: a tap or click somewhere else, any key, or Escape/B on a pad.
// The target's own handlers run first and decide whether its tip stays (a long press).
UserInputService.InputBegan.Connect((input) => {
	if (shown === undefined) return;
	const kind = input.UserInputType;
	// modifiers alone (Shift, Ctrl, Alt, Cmd) don't count: they're often held while hovering
	if (kind === Enum.UserInputType.Keyboard && MODIFIERS.has(input.KeyCode)) return;
	if (kind === Enum.UserInputType.Keyboard || input.KeyCode === Enum.KeyCode.ButtonB) {
		hideTooltip();
		return;
	}
	if (kind === Enum.UserInputType.Touch || kind === Enum.UserInputType.MouseButton1) {
		const target = shown.target;
		const point = new Vector2(input.Position.X, input.Position.Y);
		const [pos, size] = targetRect(target);
		const inside = point.X >= pos.X && point.X <= pos.X + size.X && point.Y >= pos.Y && point.Y <= pos.Y + size.Y;
		if (!inside) hideTooltip();
	}
});

export interface TooltipEvents {
	MouseEnter: (this: void, rbx: GuiObject) => void;
	MouseLeave: (this: void, rbx: GuiObject) => void;
	SelectionGained: (this: void, rbx: GuiObject) => void;
	SelectionLost: (this: void, rbx: GuiObject) => void;
	InputBegan: (this: void, rbx: GuiObject, input: InputObject) => void;
	InputEnded: (this: void, rbx: GuiObject, input: InputObject) => void;
}

// handlers for one target; content can change every render and an open bubble follows it
export function useTooltip(content: TooltipContent | undefined): TooltipEvents {
	const idRef = React.useRef<number>(0);
	if (idRef.current === 0) {
		nextId += 1;
		idRef.current = nextId;
	}
	const contentRef = React.useRef<TooltipContent | undefined>(content);
	contentRef.current = content;
	const id = idRef.current!;
	React.useEffect(() => {
		if (shown !== undefined && shown.id === id) {
			if (hasContent(content)) {
				shown = { id, target: shown.target, content };
				emit();
			} else {
				hideId(id);
			}
		}
	});
	React.useEffect(() => () => hideId(id), []);
	return React.useMemo<TooltipEvents>(() => {
		const read = () => contentRef.current;
		let pressAt = 0;
		const leave = (_rbx: GuiObject) => {
			if (shown === undefined || shown.id === id) hideId(id);
			else cancelPending();
		};
		return {
			MouseEnter: (rbx) => {
				if (UserInputService.TouchEnabled && !UserInputService.MouseEnabled) return;
				if (!hasContent(read())) return;
				scheduleShow(id, rbx, read, os.clock() - lastHiddenAt < WARM_WINDOW ? WARM_DELAY : SHOW_DELAY);
			},
			MouseLeave: leave,
			SelectionGained: (rbx) => {
				if (GuiService.SelectedObject !== rbx || !hasContent(read())) return;
				scheduleShow(id, rbx, read, os.clock() - lastHiddenAt < WARM_WINDOW ? PAD_WARM_DELAY : PAD_DELAY);
			},
			SelectionLost: leave,
			InputBegan: (rbx, input) => {
				const kind = input.UserInputType;
				if (kind === Enum.UserInputType.Touch) {
					pressAt = os.clock();
					pressStart = new Vector2(input.Position.X, input.Position.Y);
					if (hasContent(read())) scheduleShow(id, rbx, read, LONG_PRESS);
				} else if (
					kind === Enum.UserInputType.MouseButton1 ||
					kind === Enum.UserInputType.MouseButton2 ||
					kind === Enum.UserInputType.MouseWheel
				) {
					leave(rbx);
				}
			},
			InputEnded: (rbx, input) => {
				if (input.UserInputType !== Enum.UserInputType.Touch) return;
				pressStart = undefined;
				if (shown !== undefined && shown.id === id && os.clock() - pressAt >= LONG_PRESS) {
					// leave a long-press tip up long enough to read
					const tipId = shown;
					task.delay(TOUCH_LINGER, () => {
						if (shown === tipId) hideId(id);
					});
				} else {
					leave(rbx);
				}
			},
		};
	}, []);
}

type AnyHandler = (this: void, ...args: unknown[]) => void;
// join handler tables; both run, in order
export function mergeEvents<A extends object, B extends object>(a: A | undefined, b: B | undefined): A & B {
	const out: Record<string, AnyHandler> = {};
	for (const [key, handler] of pairs((a ?? {}) as Record<string, AnyHandler>)) out[key as string] = handler;
	for (const [key, handler] of pairs((b ?? {}) as Record<string, AnyHandler>)) {
		const first = out[key as string];
		out[key as string] =
			first !== undefined
				? (...args: unknown[]) => {
						first(...args);
						handler(...args);
					}
				: handler;
	}
	return out as unknown as A & B;
}

// placement ----------------------------------------------------------------------------------------

function viewport(): Vector2 {
	const camera = Workspace.CurrentCamera;
	return camera ? camera.ViewportSize : new Vector2(1280, 720);
}

function targetRect(target: GuiObject): LuaTuple<[Vector2, Vector2]> {
	let position = target.AbsolutePosition;
	const holder = target.FindFirstAncestorWhichIsA("LayerCollector");
	if (holder !== undefined && holder.IsA("ScreenGui") && !holder.IgnoreGuiInset) {
		position = position.add(GuiService.GetGuiInset()[0]);
	}
	return $tuple(position, target.AbsoluteSize);
}

// the device's safe area (notches, rounded corners, home bar), measured by the provider
let safeFrame: Frame | undefined = undefined;

// above, else below, right, left; slid along the edge and clamped inside the safe area.
// On touch the finger sits over the target, so below is only used when above won't fit.
export function placeTooltip(targetPos: Vector2, targetSize: Vector2, size: Vector2): Vector2 {
	const view = viewport();
	const safe = safeFrame !== undefined && safeFrame.Parent !== undefined ? safeFrame : undefined;
	const safeMin = safe !== undefined ? safe.AbsolutePosition : new Vector2(0, 0);
	const maxCorner = safe !== undefined ? safe.AbsolutePosition.add(safe.AbsoluteSize) : view;
	const left = math.max(EDGE, safeMin.X + EDGE);
	const right = math.min(view.X, maxCorner.X) - EDGE;
	const top = math.max(EDGE, GuiService.GetGuiInset()[0].Y + 4, safeMin.Y + EDGE);
	const bottom = math.min(view.Y, maxCorner.Y) - EDGE;
	const clampPos = (p: Vector2) =>
		new Vector2(
			math.clamp(p.X, left, math.max(left, right - size.X)),
			math.clamp(p.Y, top, math.max(top, bottom - size.Y)),
		);
	const fits = (p: Vector2) => p.X >= left && p.Y >= top && p.X + size.X <= right && p.Y + size.Y <= bottom;
	const cx = targetPos.X + targetSize.X / 2 - size.X / 2;
	const cy = targetPos.Y + targetSize.Y / 2 - size.Y / 2;
	const spots = [
		new Vector2(clampPos(new Vector2(cx, 0)).X, targetPos.Y - GAP - size.Y),
		new Vector2(clampPos(new Vector2(cx, 0)).X, targetPos.Y + targetSize.Y + GAP),
		new Vector2(targetPos.X + targetSize.X + GAP, clampPos(new Vector2(0, cy)).Y),
		new Vector2(targetPos.X - GAP - size.X, clampPos(new Vector2(0, cy)).Y),
	];
	for (const spot of spots) {
		if (fits(spot)) return spot;
	}
	return clampPos(spots[0]);
}

// the provider -------------------------------------------------------------------------------------

export interface TooltipProviderProps {
	enabled?: boolean;
	reducedMotion?: boolean;
	children?: React.ReactNode;
}

export function TooltipProvider(props: TooltipProviderProps) {
	const [current, setCurrent] = React.useState<Shown | undefined>(shown);
	const [position, setPosition] = React.useBinding(new Vector2(-1000, -1000));
	const [alpha, setAlpha] = React.useBinding(0);
	const bubbleRef = React.useRef<Frame>();
	const enabled = props.enabled !== false;
	const reducedMotion = props.reducedMotion === true;

	React.useEffect(() => {
		const listener = () => setCurrent(shown);
		listeners.add(listener);
		listener();
		return () => {
			listeners.delete(listener);
		};
	}, []);
	React.useEffect(() => {
		if (!enabled) hideTooltip();
	}, [enabled]);

	const targetId = current !== undefined ? current.id : undefined;
	React.useEffect(() => {
		if (current === undefined) {
			setAlpha(0);
			return undefined;
		}
		const target = current.target;
		let age = 0;
		setAlpha(reducedMotion ? 1 : 0);
		const connection = RunService.RenderStepped.Connect((dt) => {
			if (!target.IsDescendantOf(game) || !target.Visible) {
				hideTooltip();
				return;
			}
			age += dt;
			const bubble = bubbleRef.current;
			const [pos, size] = targetRect(target);
			const bubbleSize = bubble !== undefined ? bubble.AbsoluteSize : new Vector2(0, 0);
			const spot = placeTooltip(pos, size, bubbleSize);
			setPosition(new Vector2(math.round(spot.X), math.round(spot.Y)));
			// wait a frame for AutomaticSize before fading in, then ease in
			const t = reducedMotion ? 1 : math.clamp((age - 1 / 60) / FADE_IN, 0, 1);
			setAlpha(1 - (1 - t) * (1 - t));
		});
		return () => connection.Disconnect();
	}, [targetId, reducedMotion]);

	const playerGui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
	let bubble: React.Element | undefined = undefined;
	if (enabled && current !== undefined) {
		const data = typeIs(current.content, "string") ? { title: current.content } : current.content;
		const hasTitle = data.title !== undefined && data.title !== "";
		const hasBody = data.body !== undefined && data.body !== "";
		const hasHint = data.hint !== undefined && data.hint !== "";
		const narrow = viewport().X < 700;
		// never wider than the screen allows on very small phones (bubble padding is 22px)
		const maxW = math.max(120, math.min(narrow ? 220 : 280, viewport().X - EDGE * 2 - 22));
		const fade = alpha.map((a) => 1 - a);
		const label = (name: string, order: number, text: string, weight: Enum.FontWeight, size: number, color: Color3) => (
			<textlabel
				key={name}
				LayoutOrder={order}
				BackgroundTransparency={1}
				AutomaticSize={Enum.AutomaticSize.XY}
				Size={UDim2.fromOffset(0, 0)}
				TextWrapped={true}
				RichText={false}
				Text={text}
				TextXAlignment={Enum.TextXAlignment.Left}
				TextYAlignment={Enum.TextYAlignment.Top}
				FontFace={new Font("rbxasset://fonts/families/BuilderSans.json", weight)}
				TextSize={size}
				TextColor3={color}
				TextTransparency={fade}
				ZIndex={3}
			>
				<uisizeconstraint MaxSize={new Vector2(maxW, math.huge)} />
			</textlabel>
		);
		bubble = (
			<frame
				ref={bubbleRef}
				key={`tip${current.id}`}
				AutomaticSize={Enum.AutomaticSize.XY}
				Size={UDim2.fromOffset(0, 0)}
				Position={position.map((p) => UDim2.fromOffset(p.X, p.Y + (1 - alpha.getValue()) * (reducedMotion ? 0 : 4)))}
				BackgroundColor3={Palette.ink}
				BackgroundTransparency={alpha.map((a) => 1 - a * 0.94)}
				BorderSizePixel={0}
				Active={false}
				Selectable={false}
			>
				<uicorner CornerRadius={new UDim(0, 10)} />
				<uistroke
					Thickness={1}
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					Color={data.accent ?? Palette.lineSoft}
					Transparency={alpha.map((a) => 1 - a * (data.accent !== undefined ? 0.8 : 0.55))}
				/>
				<uipadding
					PaddingLeft={new UDim(0, 11)}
					PaddingRight={new UDim(0, 11)}
					PaddingTop={new UDim(0, 8)}
					PaddingBottom={new UDim(0, 9)}
				/>
				<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 3)} />
				{hasTitle && label("Title", 1, data.title!, Enum.FontWeight.Bold, 14, Palette.cream)}
				{hasBody && label("Body", 2, data.body!, Enum.FontWeight.Regular, 13, hasTitle ? Palette.creamSoft : Palette.cream)}
				{hasHint && label("Hint", 3, data.hint!, Enum.FontWeight.SemiBold, 11, Palette.muted)}
			</frame>
		);
	}
	return (
		<>
			{props.children}
			{playerGui !== undefined &&
				ReactRoblox.createPortal(
					<screengui
						key="AstralForgeTooltips"
						DisplayOrder={9000}
						IgnoreGuiInset={true}
						ResetOnSpawn={false}
						ZIndexBehavior={Enum.ZIndexBehavior.Sibling}
					>
						{bubble}
					</screengui>,
					playerGui,
				)}
			{playerGui !== undefined &&
				ReactRoblox.createPortal(
					<screengui
						key="AstralForgeTooltipSafeArea"
						DisplayOrder={8999}
						IgnoreGuiInset={true}
						ScreenInsets={Enum.ScreenInsets.DeviceSafeInsets}
						ResetOnSpawn={false}
					>
						<frame
							Size={UDim2.fromScale(1, 1)}
							BackgroundTransparency={1}
							Active={false}
							Selectable={false}
							ref={(rbx: Frame | undefined) => {
								safeFrame = rbx;
							}}
						/>
					</screengui>,
					playerGui,
				)}
		</>
	);
}
