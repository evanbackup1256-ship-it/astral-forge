const UserInputService = game.GetService("UserInputService");
const Players = game.GetService("Players");
const GuiService = game.GetService("GuiService");
const Workspace = game.GetService("Workspace");

interface TouchPointer {
	id: number;
	startPos: Vector2;
	currentPos: Vector2;
	previousPos: Vector2;
	velocity: Vector2;
	startTime: number;
	lastUpdateTime: number;
	isConsumed: boolean;
}

export type GestureEvent = "Tap" | "DoubleTap" | "LongPress" | "Swipe" | "Pinch" | "ThumbstickMove";

export interface SwipeData {
	direction: Vector2;
	distance: number;
	velocity: Vector2;
	isFlick: boolean;
}

export interface PinchData {
	center: Vector2;
	scaleDelta: number;
	rotationDelta: number;
	distance: number;
}

export interface ThumbstickData {
	origin: Vector2;
	current: Vector2;
	direction: Vector2;
	magnitude: number;
	active: boolean;
}

const MIN_SWIPE_DISTANCE = 40;
const FLICK_VELOCITY_THRESHOLD = 800;
const PINCH_MIN_TOUCH_DIST = 16;
const THUMBSTICK_RADIUS = 64;
const THUMBSTICK_DEADZONE = 0.12;
const FAT_FINGER_EXPANSION_PX = 14;
const TAP_MAX_DURATION = 0.35;
const TAP_MAX_TRAVEL = 12;

type Listener = (payload: unknown) => void;

const activeTouches = new Map<InputObject, TouchPointer>();
let pointerIdCounter = 0;
const listeners: Record<GestureEvent, Listener[]> = {
	Tap: [],
	DoubleTap: [],
	LongPress: [],
	Swipe: [],
	Pinch: [],
	ThumbstickMove: [],
};

const thumbstickState: ThumbstickData = {
	origin: Vector2.zero,
	current: Vector2.zero,
	direction: Vector2.zero,
	magnitude: 0,
	active: false,
};
let thumbstickTouch: InputObject | undefined;

interface HitTarget {
	id: string;
	gui: GuiObject;
	priority: number;
	callback: () => void;
	customExpansion?: number;
}
const registeredTargets = new Array<HitTarget>();
const inputConnections = new Array<RBXScriptConnection>();
let initialized = false;

function isVisible(gui: GuiObject): boolean {
	let ancestor: Instance | undefined = gui;
	while (ancestor) {
		if (ancestor.IsA("GuiObject") && !ancestor.Visible) {
			return false;
		}
		if (ancestor.IsA("ScreenGui") && !ancestor.Enabled) {
			return false;
		}
		ancestor = ancestor.Parent;
	}
	return true;
}

// kept for callers that hit-test raw screen positions; inputs below are already in GUI space
export function toGuiPosition(rawPosition: Vector2): Vector2 {
	const [ok, topLeft] = pcall(() => GuiService.GetGuiInset()[0]);
	return ok && typeIs(topLeft, "Vector2") ? rawPosition.sub(topLeft) : rawPosition;
}

function isPointUnclipped(gui: GuiObject, position: Vector2): boolean {
	let ancestor: Instance | undefined = gui.Parent;
	while (ancestor) {
		if (ancestor.IsA("GuiObject") && ancestor.ClipsDescendants) {
			const origin = ancestor.AbsolutePosition;
			const size = ancestor.AbsoluteSize;
			if (position.X < origin.X || position.X > origin.X + size.X || position.Y < origin.Y || position.Y > origin.Y + size.Y) {
				return false;
			}
		}
		ancestor = ancestor.Parent;
	}
	return true;
}

function isOnInteractiveGui(position: Vector2): boolean {
	const playerGui = Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
	if (!playerGui) {
		return false;
	}
	for (const gui of playerGui.GetGuiObjectsAtPosition(position.X, position.Y)) {
		if (gui.IsA("GuiButton") && isVisible(gui)) {
			return true;
		}
	}
	return false;
}

function emit(event: GestureEvent, payload: unknown) {
	const list = listeners[event];
	if (list) {
		for (const handler of list) {
			task.spawn(handler, payload);
		}
	}
}

export function ResolveFatFingerHit(screenPosition: Vector2): boolean {
	if (isOnInteractiveGui(screenPosition)) {
		return false;
	}
	let bestTarget: HitTarget | undefined;
	let bestScore = math.huge;

	for (const target of registeredTargets) {
		if (!target.gui.Parent || !isVisible(target.gui) || !isPointUnclipped(target.gui, screenPosition)) {
			continue;
		}
		const absPos = target.gui.AbsolutePosition;
		const absSize = target.gui.AbsoluteSize;
		const expansion = target.customExpansion ?? FAT_FINGER_EXPANSION_PX;

		const minX = absPos.X - expansion;
		const maxX = absPos.X + absSize.X + expansion;
		const minY = absPos.Y - expansion;
		const maxY = absPos.Y + absSize.Y + expansion;

		if (screenPosition.X >= minX && screenPosition.X <= maxX && screenPosition.Y >= minY && screenPosition.Y <= maxY) {
			const center = absPos.add(absSize.mul(0.5));
			const dist = screenPosition.sub(center).Magnitude;
			const score = dist - target.priority * 20;
			if (score < bestScore) {
				bestScore = score;
				bestTarget = target;
			}
		}
	}

	if (bestTarget) {
		task.spawn(bestTarget.callback);
		return true;
	}
	return false;
}

export function RegisterTouchTarget(id: string, gui: GuiObject, callback: () => void, priority?: number, customExpansion?: number) {
	const entry: HitTarget = { id, gui, priority: priority ?? 1, callback, customExpansion };
	const index = registeredTargets.findIndex((t) => t.id === id);
	if (index >= 0) {
		registeredTargets[index] = entry;
		return;
	}
	registeredTargets.push(entry);
}

export function UnregisterTouchTarget(id: string) {
	const index = registeredTargets.findIndex((t) => t.id === id);
	if (index >= 0) {
		registeredTargets.remove(index);
	}
}

export function IsNearRegisteredTarget(position: Vector2): boolean {
	for (const target of registeredTargets) {
		if (target.gui.Parent && isVisible(target.gui) && isPointUnclipped(target.gui, position)) {
			const origin = target.gui.AbsolutePosition;
			const size = target.gui.AbsoluteSize;
			const margin = target.customExpansion ?? FAT_FINGER_EXPANSION_PX;
			if (
				position.X >= origin.X - margin &&
				position.X <= origin.X + size.X + margin &&
				position.Y >= origin.Y - margin &&
				position.Y <= origin.Y + size.Y + margin
			) {
				return true;
			}
		}
	}
	return false;
}

function evaluatePinch(p1: TouchPointer, p2: TouchPointer) {
	const curDist = p1.currentPos.sub(p2.currentPos).Magnitude;
	const prevDist = p1.previousPos.sub(p2.previousPos).Magnitude;
	if (prevDist < PINCH_MIN_TOUCH_DIST) {
		return;
	}
	const scaleDelta = curDist / prevDist;
	const center = p1.currentPos.add(p2.currentPos).mul(0.5);
	const curVec = p1.currentPos.sub(p2.currentPos);
	const prevVec = p1.previousPos.sub(p2.previousPos);
	const curAngle = math.atan2(curVec.Y, curVec.X);
	const prevAngle = math.atan2(prevVec.Y, prevVec.X);
	const pinchPayload: PinchData = {
		center,
		scaleDelta,
		rotationDelta: curAngle - prevAngle,
		distance: curDist,
	};
	emit("Pinch", pinchPayload);
}

export function Init() {
	if (initialized || !UserInputService.TouchEnabled) {
		return;
	}
	initialized = true;

	inputConnections.push(
		UserInputService.InputBegan.Connect((input, gameProcessed) => {
			if (input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			pointerIdCounter += 1;
			const pos = new Vector2(input.Position.X, input.Position.Y);
			const now = os.clock();
			const pointer: TouchPointer = {
				id: pointerIdCounter,
				startPos: pos,
				currentPos: pos,
				previousPos: pos,
				velocity: Vector2.zero,
				startTime: now,
				lastUpdateTime: now,
				isConsumed: gameProcessed || isOnInteractiveGui(pos),
			};
			activeTouches.set(input, pointer);

			const cam = Workspace.CurrentCamera;
			const vSize = cam ? cam.ViewportSize : new Vector2(1000, 800);
			if (
				!pointer.isConsumed &&
				!IsNearRegisteredTarget(pos) &&
				!thumbstickState.active &&
				pos.X < vSize.X * 0.45 &&
				pos.Y > vSize.Y * 0.5
			) {
				thumbstickTouch = input;
				thumbstickState.active = true;
				thumbstickState.origin = pos;
				thumbstickState.current = pos;
				thumbstickState.direction = Vector2.zero;
				thumbstickState.magnitude = 0;
				emit("ThumbstickMove", thumbstickState);
			}
		}),
	);

	inputConnections.push(
		UserInputService.InputChanged.Connect((input) => {
			if (input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			const pointer = activeTouches.get(input);
			if (!pointer) {
				return;
			}
			const newPos = new Vector2(input.Position.X, input.Position.Y);
			const now = os.clock();
			const dt = math.max(0.001, now - pointer.lastUpdateTime);

			pointer.velocity = newPos.sub(pointer.currentPos).div(dt);
			pointer.previousPos = pointer.currentPos;
			pointer.currentPos = newPos;
			pointer.lastUpdateTime = now;

			if (input === thumbstickTouch && thumbstickState.active) {
				const delta = newPos.sub(thumbstickState.origin);
				const rawMag = delta.Magnitude;
				const clampedDist = math.min(rawMag, THUMBSTICK_RADIUS);
				const unitDir = rawMag > 0.001 ? delta.div(rawMag) : Vector2.zero;
				const normalized = clampedDist / THUMBSTICK_RADIUS;
				let filteredMag = 0;
				if (normalized > THUMBSTICK_DEADZONE) {
					filteredMag = (normalized - THUMBSTICK_DEADZONE) / (1 - THUMBSTICK_DEADZONE);
				}
				thumbstickState.current = thumbstickState.origin.add(unitDir.mul(clampedDist));
				thumbstickState.direction = unitDir;
				thumbstickState.magnitude = filteredMag;
				emit("ThumbstickMove", thumbstickState);
			}

			const touches = new Array<TouchPointer>();
			for (const [touchInput, ptr] of activeTouches) {
				if (!ptr.isConsumed && touchInput !== thumbstickTouch) {
					touches.push(ptr);
				}
			}
			if (touches.size() === 2) {
				evaluatePinch(touches[0], touches[1]);
			}
		}),
	);

	inputConnections.push(
		UserInputService.InputEnded.Connect((input) => {
			if (input.UserInputType !== Enum.UserInputType.Touch) {
				return;
			}
			const pointer = activeTouches.get(input);
			if (!pointer) {
				return;
			}
			const now = os.clock();
			const duration = now - pointer.startTime;
			const travel = pointer.currentPos.sub(pointer.startPos).Magnitude;

			const wasThumbstick = input === thumbstickTouch;
			if (wasThumbstick) {
				thumbstickTouch = undefined;
				thumbstickState.active = false;
				thumbstickState.direction = Vector2.zero;
				thumbstickState.magnitude = 0;
				emit("ThumbstickMove", thumbstickState);
			}

			if (!pointer.isConsumed && !wasThumbstick && duration <= TAP_MAX_DURATION && travel <= TAP_MAX_TRAVEL) {
				const handled = ResolveFatFingerHit(pointer.currentPos);
				if (!handled) {
					emit("Tap", pointer.currentPos);
				}
			} else if (!pointer.isConsumed && !wasThumbstick && travel >= MIN_SWIPE_DISTANCE) {
				const swipe: SwipeData = {
					direction: pointer.currentPos.sub(pointer.startPos).Unit,
					distance: travel,
					velocity: pointer.velocity,
					isFlick: pointer.velocity.Magnitude >= FLICK_VELOCITY_THRESHOLD,
				};
				emit("Swipe", swipe);
			}
			activeTouches.delete(input);
		}),
	);
}

export function Stop() {
	for (const connection of inputConnections) {
		connection.Disconnect();
	}
	inputConnections.clear();
	activeTouches.clear();
	registeredTargets.clear();
	thumbstickTouch = undefined;
	thumbstickState.active = false;
	thumbstickState.direction = Vector2.zero;
	thumbstickState.magnitude = 0;
	initialized = false;
}

export function On(event: GestureEvent, callback: Listener): () => void {
	const list = listeners[event];
	if (list) {
		list.push(callback);
		return () => {
			const idx = list.indexOf(callback);
			if (idx >= 0) {
				list.remove(idx);
			}
		};
	}
	return () => {};
}

export function GetThumbstickState(): ThumbstickData {
	return thumbstickState;
}
