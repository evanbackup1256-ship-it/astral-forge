import { isTouchOnly } from "./CoreKit/inputLayer";
// Tooltips: one bubble for the whole game, drawn by <TooltipProvider> (mounted once at the UI
// root) in its own top-layer ScreenGui.
//
// Targets call useTooltip(content) and merge the returned handlers into their Event table
// (mergeEvents keeps the target's own handlers). Content is a string or { title, body, hint,
// accent }. How a tip opens depends on the input:
//   mouse    rest on the target (0.45s; 0.08s right after another tip closed)
//   gamepad  selection rests on it (0.7s; 0.25s warm)
//   touch    long press (0.45s), stays 1.6s after lifting; sliding 12px cancels it
// Any key, B, the wheel, or a tap/click outside the target closes it. The bubble goes above the
// target, else below, right, left, and is clamped inside the device safe area.
import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";
import { InteractionFeedback } from "./CoreKit/interaction";
import { Palette, Radius } from "./CoreKit/theme";
import { visibleObstacles } from "./MotionKit/choreography";
import { usePresence } from "./MotionKit/motion";
import { surfaceFont, SurfaceType } from "./UiCore/surface";

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

export type TooltipContent =
	| string
	| { title?: string; body?: string; stats?: { label: string; value: string }[]; hint?: string; accent?: Color3 };

const Timing = {
	mouse: 0.45,
	mouseWarm: 0.08,
	pad: 0.7,
	padWarm: 0.25,
	warmWindow: 0.6,
	longPress: 0.45,
	touchLinger: 1.6,
} as const;
const TOUCH_SLOP = 12;
const GAP = 8;
const EDGE = 10;
const BUBBLE_PAD = 12;
// pixels the bubble travels while it arrives, from the side it sits on
const SLIDE = 6;
const FONT_TITLE = surfaceFont(Enum.FontWeight.SemiBold);
const FONT_BODY = surfaceFont(Enum.FontWeight.Medium);
const FONT_KEY = surfaceFont(Enum.FontWeight.Bold);

// names for icon-only buttons, by icon concept ("Close.24" -> "Close")
const ICON_NAMES: { [concept: string]: string } = {
	Close: "Close",
	Back: "Back",
	Settings: "Settings",
	Menu: "Menu",
	Search: "Search",
	Refresh: "Refresh",
	Send: "Send",
	Chat: "Chat",
	Mail: "Mail",
	Inventory: "Inventory",
	Shop: "Shop",
	Play: "Play",
	Pause: "Pause",
	Hide: "Hide",
	Lock: "Locked",
	Check: "Done",
	Chevron: "More",
	Visit: "Visit",
	Wave: "Wave",
	Gift: "Gift",
	Leaderboard: "Ranks",
	Guide: "Guide",
	Credits: "Credits",
	Crew: "Crew",
	Guild: "Guild",
	Admin: "Admin",
	Rewards: "Rewards",
	Calendar: "Calendar",
	Code: "Codes",
	Travel: "Travel",
	Loadout: "Loadout",
};

export function labelFor(icon: string | undefined): string | undefined {
	if (!typeIs(icon, "string")) {
		return undefined;
	}
	const [concept] = icon.match("^[^.]+");
	return ICON_NAMES[(concept as string | undefined) ?? icon];
}

interface TipData {
	title?: string;
	body?: string;
	stats?: { label: string; value: string }[];
	hint?: string;
	accent?: Color3;
}

function readContent(content: TooltipContent | undefined): TipData | undefined {
	if (content === undefined) {
		return undefined;
	}
	const data: TipData = typeIs(content, "string") ? { title: content } : content;
	const filled = (text: string | undefined) => text !== undefined && text !== "";
	const stats = data.stats?.filter((stat) => filled(stat.label) && filled(stat.value));
	const normalized = { ...data, stats };
	return filled(data.title) || filled(data.body) || (stats !== undefined && stats.size() > 0) ? normalized : undefined;
}

// ── The one open tip ───────────────────────────────────────────────────────────

interface OpenTip {
	id: number;
	target: GuiObject;
	data: TipData;
}

const store = {
	open: undefined as OpenTip | undefined,
	timer: undefined as thread | undefined,
	closedAt: -math.huge,
	ids: 0,
	listeners: new Set<() => void>(),
	// where the current long press started, so sliding away cancels it
	pressFrom: undefined as Vector2 | undefined,
};

function notify() {
	for (const listener of store.listeners) {
		listener();
	}
}

function newId(): number {
	store.ids += 1;
	return store.ids;
}

function stopTimer() {
	if (store.timer !== undefined) {
		pcall(task.cancel, store.timer);
		store.timer = undefined;
	}
}

function close(id?: number) {
	stopTimer();
	if (store.open !== undefined && (id === undefined || store.open.id === id)) {
		store.open = undefined;
		store.closedAt = os.clock();
		notify();
	}
}

function warm(): boolean {
	return os.clock() - store.closedAt < Timing.warmWindow;
}

function openAfter(id: number, target: GuiObject, read: () => TooltipContent | undefined, wait: number) {
	stopTimer();
	store.timer = task.delay(wait, () => {
		store.timer = undefined;
		const data = readContent(read());
		if (data === undefined || !target.IsDescendantOf(game) || !target.Visible) {
			return;
		}
		store.open = { id, target, data };
		// a long-press tip lands with a light tick so the finger knows it worked
		if (store.pressFrom !== undefined) {
			InteractionFeedback.tick();
		}
		notify();
	});
}

function screenRect(target: GuiObject): LuaTuple<[Vector2, Vector2]> {
	let position = target.AbsolutePosition;
	const holder = target.FindFirstAncestorWhichIsA("LayerCollector");
	if (holder !== undefined && holder.IsA("ScreenGui") && !holder.IgnoreGuiInset) {
		position = position.add(GuiService.GetGuiInset()[0]);
	}
	return $tuple(position, target.AbsoluteSize);
}

// ── Global dismissal ───────────────────────────────────────────────────────────

const MODIFIER_KEYS = new Set<Enum.KeyCode>([
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.LeftAlt,
	Enum.KeyCode.RightAlt,
	Enum.KeyCode.LeftMeta,
	Enum.KeyCode.RightMeta,
	Enum.KeyCode.LeftSuper,
	Enum.KeyCode.RightSuper,
	Enum.KeyCode.CapsLock,
]);

UserInputService.InputChanged.Connect((input) => {
	if (input.UserInputType === Enum.UserInputType.MouseWheel && store.open !== undefined) {
		close();
	}
	const from = store.pressFrom;
	if (input.UserInputType === Enum.UserInputType.Touch && from !== undefined) {
		if (new Vector2(input.Position.X, input.Position.Y).sub(from).Magnitude > TOUCH_SLOP) {
			store.pressFrom = undefined;
			close();
		}
	}
});

UserInputService.InputBegan.Connect((input) => {
	const open = store.open;
	if (open === undefined) {
		return;
	}
	const kind = input.UserInputType;
	// Shift, Ctrl, Alt and Cmd are often held while pointing, so they don't count
	if (kind === Enum.UserInputType.Keyboard && MODIFIER_KEYS.has(input.KeyCode)) {
		return;
	}
	if (kind === Enum.UserInputType.Keyboard || input.KeyCode === Enum.KeyCode.ButtonB) {
		close();
		return;
	}
	if (kind === Enum.UserInputType.Touch || kind === Enum.UserInputType.MouseButton1) {
		const [pos, size] = screenRect(open.target);
		const x = input.Position.X;
		const y = input.Position.Y;
		if (x < pos.X || x > pos.X + size.X || y < pos.Y || y > pos.Y + size.Y) {
			close();
		}
	}
});

// ── Target handlers ────────────────────────────────────────────────────────────

export interface TooltipEvents {
	MouseEnter: (this: void, rbx: GuiObject) => void;
	MouseLeave: (this: void, rbx: GuiObject) => void;
	SelectionGained: (this: void, rbx: GuiObject) => void;
	SelectionLost: (this: void, rbx: GuiObject) => void;
	InputBegan: (this: void, rbx: GuiObject, input: InputObject) => void;
	InputEnded: (this: void, rbx: GuiObject, input: InputObject) => void;
}

/** Handlers for one target. Content may change every render; an open tip follows it. */
export function useTooltip(content: TooltipContent | undefined): TooltipEvents {
	const idRef = React.useRef(0);
	if (idRef.current === 0) {
		idRef.current = newId();
	}
	const id = idRef.current;
	const contentRef = React.useRef(content);
	contentRef.current = content;
	React.useEffect(() => {
		const open = store.open;
		if (open !== undefined && open.id === id) {
			const data = readContent(content);
			if (data !== undefined) {
				store.open = { id, target: open.target, data };
				notify();
			} else {
				close(id);
			}
		}
	});
	React.useEffect(() => () => close(id), []);
	return React.useMemo<TooltipEvents>(() => {
		const read = () => contentRef.current;
		let pressedAt = 0;
		const leave = () => {
			if (store.open === undefined || store.open.id === id) {
				close(id);
			} else {
				stopTimer();
			}
		};
		return {
			MouseEnter: (rbx) => {
				if (isTouchOnly()) {
					return;
				}
				if (readContent(read()) !== undefined) {
					openAfter(id, rbx, read, warm() ? Timing.mouseWarm : Timing.mouse);
				}
			},
			MouseLeave: leave,
			SelectionGained: (rbx) => {
				if (GuiService.SelectedObject === rbx && readContent(read()) !== undefined) {
					openAfter(id, rbx, read, warm() ? Timing.padWarm : Timing.pad);
				}
			},
			SelectionLost: leave,
			InputBegan: (rbx, input) => {
				const kind = input.UserInputType;
				if (kind === Enum.UserInputType.Touch) {
					pressedAt = os.clock();
					store.pressFrom = new Vector2(input.Position.X, input.Position.Y);
					if (readContent(read()) !== undefined) {
						openAfter(id, rbx, read, Timing.longPress);
					}
				} else if (
					kind === Enum.UserInputType.MouseButton1 ||
					kind === Enum.UserInputType.MouseButton2 ||
					kind === Enum.UserInputType.MouseWheel
				) {
					leave();
				}
			},
			InputEnded: (_rbx, input) => {
				if (input.UserInputType !== Enum.UserInputType.Touch) {
					return;
				}
				store.pressFrom = undefined;
				const open = store.open;
				if (open !== undefined && open.id === id && os.clock() - pressedAt >= Timing.longPress) {
					// a long-press tip stays up long enough to read
					task.delay(Timing.touchLinger, () => {
						if (store.open === open) {
							close(id);
						}
					});
				} else {
					leave();
				}
			},
		};
	}, []);
}

type AnyHandler = (this: void, ...args: unknown[]) => void;
/** Join two Event tables; where both have a handler, both run (first, then second). */
export function mergeEvents<A extends object, B extends object>(a: A | undefined, b: B | undefined): A & B {
	const out: Record<string, AnyHandler> = {};
	for (const [key, handler] of pairs((a ?? {}) as Record<string, AnyHandler>)) {
		out[key as string] = handler;
	}
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

// ── Placement ──────────────────────────────────────────────────────────────────

// the device safe area (notch, rounded corners, home bar), measured by the provider
let safeArea: Frame | undefined = undefined;

function screenSize(): Vector2 {
	const camera = Workspace.CurrentCamera;
	return camera !== undefined ? camera.ViewportSize : new Vector2(1280, 720);
}

// above, else below, right, left; slid along that side and clamped inside the safe area. Also
// returns which way the bubble sits from its target (up, down, right, left): the entrance slides
// in from that side.
const AWAY = [new Vector2(0, -1), new Vector2(0, 1), new Vector2(1, 0), new Vector2(-1, 0)];

function place(targetPos: Vector2, targetSize: Vector2, size: Vector2): LuaTuple<[Vector2, Vector2]> {
	const view = screenSize();
	const safe = safeArea !== undefined && safeArea.Parent !== undefined ? safeArea : undefined;
	const low = safe !== undefined ? safe.AbsolutePosition : Vector2.zero;
	const high = safe !== undefined ? safe.AbsolutePosition.add(safe.AbsoluteSize) : view;
	const left = math.max(EDGE, low.X + EDGE);
	const right = math.min(view.X, high.X) - EDGE;
	const top = math.max(EDGE, GuiService.GetGuiInset()[0].Y + 4, low.Y + EDGE);
	const bottom = math.min(view.Y, high.Y) - EDGE;
	const clampX = (x: number) => math.clamp(x, left, math.max(left, right - size.X));
	const clampY = (y: number) => math.clamp(y, top, math.max(top, bottom - size.Y));
	const midX = clampX(targetPos.X + targetSize.X / 2 - size.X / 2);
	const midY = clampY(targetPos.Y + targetSize.Y / 2 - size.Y / 2);
	const options = [
		new Vector2(midX, targetPos.Y - GAP - size.Y),
		new Vector2(midX, targetPos.Y + targetSize.Y + GAP),
		new Vector2(targetPos.X + targetSize.X + GAP, midY),
		new Vector2(targetPos.X - GAP - size.X, midY),
	];
	// other floating UI (the trade-return pill ...) is in the way: the tip takes a side that doesn't cover it
	const blocked = (spot: Vector2): boolean => {
		for (const obstacle of visibleObstacles()) {
			const [at, extent] = screenRect(obstacle);
			if (spot.X < at.X + extent.X && spot.X + size.X > at.X && spot.Y < at.Y + extent.Y && spot.Y + size.Y > at.Y) {
				return true;
			}
		}
		return false;
	};
	for (let i = 0; i < options.size(); i++) {
		const spot = options[i];
		if (spot.X >= left && spot.Y >= top && spot.X + size.X <= right && spot.Y + size.Y <= bottom && !blocked(spot)) {
			return $tuple(spot, AWAY[i]);
		}
	}
	return $tuple(new Vector2(clampX(options[0].X), clampY(options[0].Y)), AWAY[0]);
}

// ── Provider ───────────────────────────────────────────────────────────────────

export interface TooltipProviderProps {
	enabled?: boolean;
	reducedMotion?: boolean;
	children?: React.ReactNode;
}

// The bubble: the game's raised plate with a hairline edge, nothing else. It enters and leaves with
// the game's panel presence (usePresence), like every other panel: it slides in from the side it
// sits on while it fades up, and the body copy lands a beat after the title. Reduced Motion drops the
// slide and the beat. A shortcut hint is a key cap on the title row; an accent is a small dot.
function Bubble(props: { tip: OpenTip; leaving: boolean; reducedMotion: boolean; onGone: (id: number) => void }) {
	const tip = props.tip;
	const data = tip.data;
	const calm = props.reducedMotion;
	// parked on screen (and invisible: appear is 0) until the first measure, so the layout guard never
	// sees a bubble outside the viewport
	const [spot, setSpot] = React.useBinding(new Vector2(EDGE, EDGE));
	const [away, setAway] = React.useBinding(AWAY[0]);
	// waits a frame so AutomaticSize has measured before the bubble shows
	const [ready, setReady] = React.useState(false);
	const [presence, , beginExit] = usePresence(calm);
	const appear = React.useMemo(() => presence.map((a) => (ready ? math.clamp(a, 0, 1) : 0)), [presence, ready]);
	const onGone = props.onGone;
	React.useEffect(() => {
		if (props.leaving) {
			beginExit(() => onGone(tip.id));
		}
	}, [props.leaving]);
	const bubbleRef = React.useRef<Frame>();
	React.useEffect(() => {
		const target = tip.target;
		let frames = 0;
		let lastPos = Vector2.zero;
		let lastSize = Vector2.zero;
		let lastOwn = Vector2.zero;
		const connection = RunService.RenderStepped.Connect(() => {
			if (!target.IsDescendantOf(game) || !target.Visible) {
				close(tip.id);
				return;
			}
			if (props.leaving && frames >= 2) {
				return;
			}
			const bubble = bubbleRef.current;
			const [pos, size] = screenRect(target);
			const own = bubble !== undefined ? bubble.AbsoluteSize : Vector2.zero;
			// only re-place when the target moved or the bubble resized
			if (frames >= 2 && pos === lastPos && size === lastSize && own === lastOwn) {
				return;
			}
			lastPos = pos;
			lastSize = size;
			lastOwn = own;
			const [at, side] = place(pos, size, own);
			setSpot(new Vector2(math.round(at.X), math.round(at.Y)));
			setAway(side);
			frames += 1;
			if (frames === 2) {
				setReady(true);
			}
		});
		return () => connection.Disconnect();
	}, [tip.target, props.leaving]);
	const narrow = screenSize().X < 700;
	const maxW = math.max(120, math.min(narrow ? 220 : 280, screenSize().X - EDGE * 2 - BUBBLE_PAD * 2));
	const titleFade = appear.map((a) => 1 - a);
	const bodyFade = calm ? titleFade : appear.map((a) => 1 - math.clamp((a - 0.3) / 0.7, 0, 1));
	const hasTitle = data.title !== undefined && data.title !== "";
	const hasBody = data.body !== undefined && data.body !== "";
	const hasHint = data.hint !== undefined && data.hint !== "";
	const accent = data.accent;

	return (
		<frame
			ref={bubbleRef}
			AutomaticSize={Enum.AutomaticSize.XY}
			BackgroundColor3={Palette.panelRaised}
			BackgroundTransparency={appear.map((a) => 1 - a * 0.97)}
			BorderSizePixel={0}
			ZIndex={9100}
			Position={React.joinBindings({ spot, away, appear }).map((v) => {
				const slide = calm ? 0 : (1 - v.appear) * SLIDE;
				return UDim2.fromOffset(v.spot.X - v.away.X * slide, v.spot.Y - v.away.Y * slide);
			})}
		>
			<uicorner CornerRadius={new UDim(0, Radius.md)} />
			<uistroke
				ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
				Thickness={1}
				Color={Palette.lineSoft}
				Transparency={appear.map((a) => 1 - a * 0.65)}
			/>
			<uipadding
				PaddingLeft={new UDim(0, BUBBLE_PAD)}
				PaddingRight={new UDim(0, BUBBLE_PAD)}
				PaddingTop={new UDim(0, 8)}
				PaddingBottom={new UDim(0, 8)}
			/>
			<uilistlayout SortOrder={Enum.SortOrder.LayoutOrder} Padding={new UDim(0, 4)} FillDirection={Enum.FillDirection.Vertical} />

			{(hasTitle || hasHint) && (
				<frame AutomaticSize={Enum.AutomaticSize.XY} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={1}>
					<uilistlayout
						SortOrder={Enum.SortOrder.LayoutOrder}
						Padding={new UDim(0, 8)}
						FillDirection={Enum.FillDirection.Horizontal}
						VerticalAlignment={Enum.VerticalAlignment.Center}
					/>
					{accent !== undefined && (
						<frame
							Size={UDim2.fromOffset(6, 6)}
							BackgroundColor3={accent}
							BackgroundTransparency={titleFade}
							BorderSizePixel={0}
							LayoutOrder={1}
							ZIndex={9101}
						>
							<uicorner CornerRadius={new UDim(1, 0)} />
						</frame>
					)}
					{hasTitle && (
						<textlabel
							AutomaticSize={Enum.AutomaticSize.XY}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							LayoutOrder={2}
							Text={data.title!}
							TextSize={SurfaceType.body.size}
							TextColor3={Palette.cream}
							TextTransparency={titleFade}
							FontFace={FONT_TITLE}
							TextXAlignment={Enum.TextXAlignment.Left}
							TextWrapped={true}
							ZIndex={9101}
						>
							<uisizeconstraint MaxSize={new Vector2(maxW, math.huge)} />
						</textlabel>
					)}
					{hasHint && (
						<frame
							AutomaticSize={Enum.AutomaticSize.XY}
							BackgroundColor3={Palette.panelSoft}
							BackgroundTransparency={appear.map((a) => 1 - a * 0.85)}
							BorderSizePixel={0}
							LayoutOrder={3}
							ZIndex={9101}
						>
							<uicorner CornerRadius={new UDim(0, 4)} />
							<uistroke ApplyStrokeMode={Enum.ApplyStrokeMode.Border} Thickness={1} Color={Palette.lineSoft} Transparency={appear.map((a) => 1 - a * 0.5)} />
							<uipadding PaddingLeft={new UDim(0, 6)} PaddingRight={new UDim(0, 6)} PaddingTop={new UDim(0, 2)} PaddingBottom={new UDim(0, 2)} />
							<textlabel
								AutomaticSize={Enum.AutomaticSize.XY}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								Text={data.hint!}
								TextSize={SurfaceType.hint.size}
								TextColor3={Palette.creamSoft}
								TextTransparency={titleFade}
								FontFace={FONT_KEY}
								ZIndex={9102}
							/>
						</frame>
					)}
				</frame>
			)}

			{hasBody && (
				<frame AutomaticSize={Enum.AutomaticSize.XY} BackgroundTransparency={1} BorderSizePixel={0} LayoutOrder={2}>
					<textlabel
						AutomaticSize={Enum.AutomaticSize.XY}
						BackgroundTransparency={1}
						BorderSizePixel={0}
						Text={data.body!}
						TextSize={SurfaceType.small.size}
						TextColor3={Palette.muted}
						TextTransparency={bodyFade}
						FontFace={FONT_BODY}
						TextXAlignment={Enum.TextXAlignment.Left}
						TextWrapped={true}
						ZIndex={9101}
					>
						<uisizeconstraint MaxSize={new Vector2(maxW, math.huge)} />
					</textlabel>
				</frame>
			)}

			{data.stats !== undefined && data.stats.size() > 0 && (
				<frame
					AutomaticSize={Enum.AutomaticSize.Y}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					LayoutOrder={3}
					Size={UDim2.fromOffset(maxW, 0)}
				>
					<uilistlayout
						SortOrder={Enum.SortOrder.LayoutOrder}
						Padding={new UDim(0, 3)}
						FillDirection={Enum.FillDirection.Vertical}
					/>
					{data.stats.map((stat, index) => (
						<frame
							key={`${stat.label}${index}`}
							Size={UDim2.fromOffset(maxW, 18)}
							BackgroundTransparency={1}
							BorderSizePixel={0}
							LayoutOrder={index}
						>
							<textlabel
								Size={UDim2.fromScale(0.56, 1)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								Text={stat.label}
								TextSize={SurfaceType.hint.size}
								TextColor3={Palette.muted}
								FontFace={FONT_BODY}
								TextTruncate={Enum.TextTruncate.AtEnd}
								TextXAlignment={Enum.TextXAlignment.Left}
								TextYAlignment={Enum.TextYAlignment.Center}
							/>
							<textlabel
								Position={UDim2.fromScale(0.56, 0)}
								Size={UDim2.fromScale(0.44, 1)}
								BackgroundTransparency={1}
								BorderSizePixel={0}
								Text={stat.value}
								TextSize={SurfaceType.hint.size}
								TextColor3={Palette.creamSoft}
								FontFace={FONT_BODY}
								TextTruncate={Enum.TextTruncate.AtEnd}
								TextXAlignment={Enum.TextXAlignment.Right}
								TextYAlignment={Enum.TextYAlignment.Center}
							/>
						</frame>
					))}
				</frame>
			)}
		</frame>
	);
}
export function TooltipProvider(props: TooltipProviderProps) {
	const [open, setOpen] = React.useState<OpenTip | undefined>(store.open);
	// the last tip stays mounted while it plays its exit
	const [shown, setShown] = React.useState<OpenTip | undefined>(store.open);
	const enabled = props.enabled !== false;
	const onGone = React.useCallback(
		(id: number) => setShown((current) => (current !== undefined && current.id === id ? undefined : current)),
		[],
	);
	React.useEffect(() => {
		const listener = () => {
			setOpen(store.open);
			if (store.open !== undefined) {
				setShown(store.open);
			}
		};
		store.listeners.add(listener);
		listener();
		return () => {
			store.listeners.delete(listener);
		};
	}, []);
	React.useEffect(() => {
		if (!enabled) {
			close();
			setShown(undefined);
		}
	}, [enabled]);
	const playerGui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
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
						{enabled && shown !== undefined && (
							<Bubble
								key={`tip${shown.id}`}
								tip={shown}
								leaving={open === undefined || open.id !== shown.id}
								reducedMotion={props.reducedMotion === true}
								onGone={onGone}
							/>
						)}
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
								safeArea = rbx;
							}}
						/>
					</screengui>,
					playerGui,
				)}
		</>
	);
}
