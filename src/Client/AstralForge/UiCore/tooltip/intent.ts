// Tooltip intent: decides when the one global tip opens and closes. No rendering here.
//
//   mouse    rests on the target for 0.45s (0.08s right after another tip closed). The pointer
//            has to actually settle: while it is still sweeping faster than 900px/s the wait
//            restarts, so dragging across a grid doesn't flash a tip on every cell.
//   gamepad  selection rests on it for 0.7s (0.25s warm); also follows GuiService.SelectedObject
//   touch    long press 0.45s, stays 1.6s after lifting; sliding 12px cancels
//   lists    showTooltipFor(target, content) for highlights that move without selection
// Any key (not modifiers), B, the wheel, or a tap/click outside the target closes it.
import { isTouchOnly } from "../../CoreKit/inputLayer";
import { InteractionFeedback } from "../../CoreKit/interaction";
import { InputKind, TooltipContent, TooltipData, readContent } from "./content";
import type { Rect } from "./placement";

const GuiService = game.GetService("GuiService");
const UserInputService = game.GetService("UserInputService");

export const TooltipTiming = {
	mouse: 0.45,
	mouseWarm: 0.08,
	pad: 0.7,
	padWarm: 0.25,
	warmWindow: 0.6,
	longPress: 0.45,
	touchLinger: 1.6,
	/** pointer must be slower than this (px/s) for a hover to count */
	settleSpeed: 900,
	settleRetry: 0.08,
} as const;
const TOUCH_SLOP = 12;

export interface OpenTip {
	id: number;
	target: GuiObject;
	data: TooltipData;
	input: InputKind;
	/** opened by showTooltipFor: a list highlight, not engine selection */
	manual: boolean;
}

type Listener = () => void;

const tip = {
	open: undefined as OpenTip | undefined,
	timer: undefined as thread | undefined,
	closedAt: -math.huge,
	ids: 0,
	listeners: new Set<Listener>(),
	pressFrom: undefined as Vector2 | undefined,
	input: "keyboard" as InputKind,
	pointer: Vector2.zero,
	pointerAt: 0,
	speed: 0,
};

export function subscribeTooltip(listener: Listener): () => void {
	tip.listeners.add(listener);
	return () => {
		tip.listeners.delete(listener);
	};
}

export function openTooltip(): OpenTip | undefined {
	return tip.open;
}

function notify() {
	for (const listener of tip.listeners) {
		listener();
	}
}

export function nextTooltipId(): number {
	tip.ids += 1;
	return tip.ids;
}

function stopTimer() {
	if (tip.timer !== undefined) {
		pcall(task.cancel, tip.timer);
		tip.timer = undefined;
	}
}

export function closeTooltip(id?: number) {
	stopTimer();
	if (tip.open !== undefined && (id === undefined || tip.open.id === id)) {
		tip.open = undefined;
		tip.closedAt = os.clock();
		notify();
	}
}

/** retarget an open tip's content (or close it when the content went empty) */
export function refreshTooltip(id: number, content: TooltipContent | undefined) {
	const open = tip.open;
	if (open === undefined || open.id !== id) {
		return;
	}
	const data = readContent(content);
	if (data === undefined) {
		closeTooltip(id);
	} else if (data !== open.data) {
		tip.open = { id, target: open.target, data, input: open.input, manual: open.manual };
		notify();
	}
}

function warm(): boolean {
	return os.clock() - tip.closedAt < TooltipTiming.warmWindow;
}

function showable(target: GuiObject): boolean {
	return target.IsDescendantOf(game) && target.Visible;
}

export function scheduleTooltip(
	id: number,
	target: GuiObject,
	read: () => TooltipContent | undefined,
	wait: number,
	input: InputKind,
	manual = false,
) {
	stopTimer();
	tip.timer = task.delay(wait, () => {
		tip.timer = undefined;
		// hover intent: a pointer still sweeping across doesn't mean "tell me about this"
		if (input === "keyboard" && !manual && tip.speed > TooltipTiming.settleSpeed) {
			scheduleTooltip(id, target, read, TooltipTiming.settleRetry, input, manual);
			return;
		}
		const data = readContent(read());
		if (data === undefined || !showable(target)) {
			return;
		}
		tip.open = { id, target, data, input, manual };
		if (input === "touch") {
			InteractionFeedback.tick();
		}
		notify();
	});
}

export function hoverDelay(): number {
	return warm() ? TooltipTiming.mouseWarm : TooltipTiming.mouse;
}

export function padDelay(): number {
	return warm() ? TooltipTiming.padWarm : TooltipTiming.pad;
}

/** Show a tip beside `target` after the gamepad delay; returns a function that takes it away. */
export function showTooltipFor(target: GuiObject, content: TooltipContent): () => void {
	const id = nextTooltipId();
	scheduleTooltip(id, target, () => content, padDelay(), currentInput(), true);
	return () => {
		if (tip.open !== undefined && tip.open.id === id) {
			closeTooltip(id);
		} else if (tip.open === undefined) {
			stopTimer();
		}
	};
}

export function currentInput(): InputKind {
	return isTouchOnly() ? "touch" : tip.input;
}

export function beginPress(at: Vector2) {
	tip.pressFrom = at;
	tip.input = "touch";
}

export function endPress() {
	tip.pressFrom = undefined;
}

// ── Screen rects ───────────────────────────────────────────────────────────────

export function screenRect(target: GuiObject): Rect {
	let position = target.AbsolutePosition;
	const holder = target.FindFirstAncestorWhichIsA("LayerCollector");
	if (holder !== undefined && holder.IsA("ScreenGui") && !holder.IgnoreGuiInset) {
		position = position.add(GuiService.GetGuiInset()[0]);
	}
	const size = target.AbsoluteSize;
	return { x: position.X, y: position.Y, w: size.X, h: size.Y };
}

// HUD pieces register themselves so the bubble prefers not to cover them
const avoidZones = new Map<number, GuiObject>();
let avoidIds = 0;

/** Keep tooltips off this HUD element where there is another place to put them. */
export function registerTooltipAvoid(element: GuiObject): () => void {
	avoidIds += 1;
	const id = avoidIds;
	avoidZones.set(id, element);
	return () => {
		avoidZones.delete(id);
	};
}

export function avoidRects(except: GuiObject): Rect[] {
	const out: Rect[] = [];
	for (const [, element] of avoidZones) {
		if (element.Parent !== undefined && element.Visible && element !== except && !except.IsDescendantOf(element)) {
			out.push(screenRect(element));
		}
	}
	return out;
}

// ── Global input ───────────────────────────────────────────────────────────────

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

const GAMEPAD_TYPES = new Set<Enum.UserInputType>([
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
]);

function noteInput(kind: Enum.UserInputType) {
	if (GAMEPAD_TYPES.has(kind)) {
		tip.input = "gamepad";
	} else if (kind === Enum.UserInputType.Touch) {
		tip.input = "touch";
	} else if (
		kind === Enum.UserInputType.Keyboard ||
		kind === Enum.UserInputType.MouseMovement ||
		kind === Enum.UserInputType.MouseButton1
	) {
		tip.input = "keyboard";
	}
}

UserInputService.InputChanged.Connect((input) => {
	const kind = input.UserInputType;
	if (kind === Enum.UserInputType.MouseMovement) {
		noteInput(kind);
		const now = os.clock();
		const at = new Vector2(input.Position.X, input.Position.Y);
		const dt = math.max(now - tip.pointerAt, 1 / 240);
		// light smoothing so one jittery frame doesn't decide intent
		tip.speed = tip.speed * 0.5 + (at.sub(tip.pointer).Magnitude / dt) * 0.5;
		tip.pointer = at;
		tip.pointerAt = now;
		return;
	}
	if (kind === Enum.UserInputType.MouseWheel && tip.open !== undefined) {
		closeTooltip();
	}
	const from = tip.pressFrom;
	if (kind === Enum.UserInputType.Touch && from !== undefined) {
		if (new Vector2(input.Position.X, input.Position.Y).sub(from).Magnitude > TOUCH_SLOP) {
			tip.pressFrom = undefined;
			closeTooltip();
		}
	}
});

UserInputService.InputBegan.Connect((input) => {
	const kind = input.UserInputType;
	noteInput(kind);
	const open = tip.open;
	if (open === undefined) {
		return;
	}
	if (kind === Enum.UserInputType.Keyboard && MODIFIER_KEYS.has(input.KeyCode)) {
		return;
	}
	if (kind === Enum.UserInputType.Keyboard || input.KeyCode === Enum.KeyCode.ButtonB) {
		closeTooltip();
		return;
	}
	if (kind === Enum.UserInputType.Touch || kind === Enum.UserInputType.MouseButton1) {
		const r = screenRect(open.target);
		const x = input.Position.X;
		const y = input.Position.Y;
		if (x < r.x || x > r.x + r.w || y < r.y || y > r.y + r.h) {
			closeTooltip();
		}
	}
});

// a gamepad tip goes away the moment selection leaves its target, even if the target never
// heard SelectionLost (it was removed, or selection jumped to a CoreGui menu)
GuiService.GetPropertyChangedSignal("SelectedObject").Connect(() => {
	const open = tip.open;
	if (open !== undefined && open.input === "gamepad" && !open.manual && GuiService.SelectedObject !== open.target) {
		closeTooltip(open.id);
	}
});
GuiService.GetPropertyChangedSignal("MenuIsOpen").Connect(() => {
	if (GuiService.MenuIsOpen) {
		closeTooltip();
	}
});
