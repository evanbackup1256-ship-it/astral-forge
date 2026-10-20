import React from "@rbxts/react";
import { usesDesktopStructure } from "../CoreKit/interaction";
import { Breakpoints } from "../CoreKit/theme";
import { Flipper, FlipperSingleMotor, loadReactRipple, loadSpr, vendoredTs } from "../vendor";
import { ViewportScaleContext } from "./autoScale";
import * as MotionTokens from "./motionTokens";

const GuiService = game.GetService("GuiService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

const { Instant, SingleMotor, Spring } = Flipper;
const useRippleSpring = loadReactRipple().useSpring;
const spr = loadSpr();
const { BezierCurve } = vendoredTs<{
	BezierCurve: { cubicBezier(alpha: number, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3): Vector3 };
}>("bezierts");

export interface IntentRequest {
	role?: string;
	name?: string;
	rarity?: string;
	tone?: string;
	emphasis?: number;
	reduced?: boolean;
	tier?: unknown;
	particleBudget?: number;
	glowScale?: number;
	allowConfetti?: boolean;
}

export interface SpringSpec {
	stiffness: number;
	damping: number;
}

export interface IntentPlan {
	enter: SpringSpec;
	exit: SpringSpec;
	reduced: boolean;
	[key: string]: unknown;
}

export const MotionIntent = require(
	ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("MotionIntent") as ModuleScript,
) as { resolve(this: void, request: IntentRequest): IntentPlan; [key: string]: unknown };


function cubicPoint(alpha: number, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3): Vector2 {
	const point = BezierCurve.cubicBezier(math.clamp(alpha, 0, 1), p0, p1, p2, p3);
	return new Vector2(point.X, point.Y);
}

export const easeOutCubic = (value: number) => MotionTokens.EASE.standard(math.clamp(value, 0, 1));
export const easeInCubic = (value: number) => MotionTokens.EASE.accelerate(math.clamp(value, 0, 1));
export const easeOutBack = (value: number) => {
	const overshoot = 1.35;
	const shifted = math.clamp(value, 0, 1) - 1;
	return 1 + (overshoot + 1) * shifted * shifted * shifted + overshoot * shifted * shifted;
};

export interface FlipperMotor {
	raw: FlipperSingleMotor;
	configure(stiffness: number, damping: number): void;
	setGoal(goal: number): void;
	setPosition(position: number): void;
	onChange(callback: (value: number) => void): () => void;
	halt(): void;
	destroy(): void;
	alive(): boolean;
}

interface MotorListener {
	callback: (value: number) => void;
	done: boolean;
	disconnect: () => void;
}

export function createFlipperMotor(initial: number, stiffness = 220, damping = 22): FlipperMotor {
	const raw = SingleMotor.new(initial, false);
	let atRest = true;
	raw.onComplete(() => {
		atRest = true;
	});
	const startFeel = MotionTokens.feel(stiffness, damping);
	let frequency = startFeel.frequency;
	let dampingRatio = startFeel.dampingRatio;
	const callbacks = new Set<MotorListener>();
	let destroyed = false;
	let finished = false;
	let stepping = false;
	let destroyQueued = false;
	let suppressEmit = false;
	const scratch = new Array<MotorListener>();
	let reportedError = false;
	const springGoal = Spring.new(initial, { frequency, dampingRatio });
	const instantGoal = Instant.new(initial);

	const finishDestroy = () => {
		if (finished) {
			return;
		}
		finished = true;
		destroyed = true;
		destroyQueued = false;
		const pending = [...callbacks];
		for (const entry of pending) {
			entry.disconnect();
		}
		callbacks.clear();
		disarmFlipper(raw);
		raw.destroy();
		stopDriverIfIdle();
	};

	const emit = (value: number) => {
		if (finished || suppressEmit) {
			return;
		}
		const pending = stepping ? new Array<MotorListener>() : scratch;
		const wasStepping = stepping;
		stepping = true;
		let size = 0;
		for (const entry of callbacks) {
			pending[size] = entry;
			size += 1;
		}
		for (let index = 0; index < size; index++) {
			const entry = pending[index];
			pending[index] = undefined!;
			if (!entry.done && !destroyed) {
				const [ok, problem] = pcall(entry.callback, value);
				if (!ok && !reportedError) {
					reportedError = true;
					warn(`[motion] listener error: ${tostring(problem)}`);
				}
			}
		}
		stepping = wasStepping;
		if (destroyQueued && !stepping) {
			finishDestroy();
		}
	};
	raw.onStep((value) => emit(value));

	return {
		raw,
		configure(nextStiffness, nextDamping) {
			if (destroyed) {
				return;
			}
			const nextFeel = MotionTokens.feel(nextStiffness, nextDamping);
			frequency = nextFeel.frequency;
			dampingRatio = nextFeel.dampingRatio;
			springGoal._frequency = frequency;
			springGoal._dampingRatio = dampingRatio;
		},
		setGoal(goal) {
			if (destroyed) {
				return;
			}
			if (atRest && math.abs(raw.getValue() - goal) < 1e-7) {
				return;
			}
			atRest = false;
			springGoal._targetValue = goal;
			springGoal._frequency = frequency;
			springGoal._dampingRatio = dampingRatio;
			armFlipper(raw);
			raw.setGoal(springGoal);
		},
		setPosition(position) {
			if (destroyed) {
				return;
			}
			instantGoal._targetValue = position;
			atRest = true;
			suppressEmit = true;
			raw.setGoal(instantGoal);
			const complete = raw.step(0);
			suppressEmit = false;
			if (finished) {
				return;
			}
			if (complete) {
				disarmFlipper(raw);
			} else {
				armFlipper(raw);
			}
			emit(position);
		},
		onChange(callback) {
			if (destroyed) {
				return () => undefined;
			}
			const entry: MotorListener = {
				callback,
				done: false,
				disconnect: () => {
					if (entry.done) {
						return;
					}
					entry.done = true;
					callbacks.delete(entry);
				},
			};
			callbacks.add(entry);
			return () => entry.disconnect();
		},
		halt() {
			if (destroyed) {
				return;
			}
			raw.stop();
			disarmFlipper(raw);
		},
		destroy() {
			if (finished) {
				return;
			}
			if (stepping) {
				destroyed = true;
				destroyQueued = true;
				return;
			}
			finishDestroy();
		},
		alive() {
			return !finished;
		},
	};
}

const nativePackageCache = new Map<string, unknown>();
const missingNativePackages = new Set<string>();

function loadNativePackage(name: string): unknown {
	const cached = nativePackageCache.get(name);
	if (cached !== undefined) {
		return cached;
	}
	if (missingNativePackages.has(name)) {
		return undefined;
	}
	const candidate = ReplicatedStorage.FindFirstChild("Packages")?.FindFirstChild(name);
	if (candidate === undefined || !candidate.IsA("ModuleScript")) {
		return undefined;
	}
	const [ok, result] = pcall(() => require(candidate));
	if (!ok) {
		missingNativePackages.add(name);
		warn(`[forge] ${name} failed: ${tostring(result)}`);
		return undefined;
	}
	nativePackageCache.set(name, result);
	return result;
}

interface OtterMotor {
	onStep(callback: (value: number) => void): () => void;
	setGoal(goal: unknown): void;
	destroy(): void;
}
interface Otter {
	createSingleMotor(initial: number): OtterMotor;
	spring(goal: number, options: Record<string, number>): unknown;
}

export function loadOtter(): Otter | undefined {
	return loadNativePackage("Otter") as Otter | undefined;
}

export function loadCanvasDraw(): unknown {
	return loadNativePackage("CanvasDraw");
}

export interface MotionSettings {
	motionScale: number;
	soft: boolean;
	viewportScale: number;
	textScale: number;
	reducedTransparency: boolean;
	boldText?: number;
	shimmerScale?: number;
	panelHoverScale?: number;
	panelEntranceScale?: number;
	[key: string]: unknown;
}

export const DefaultMotionSettings: MotionSettings = {
	motionScale: 1,
	soft: false,
	viewportScale: 1,
	textScale: 1,
	reducedTransparency: false,
};

export const MotionSettingsContext = React.createContext<MotionSettings>(DefaultMotionSettings);
export const EntranceMotionSuppressedContext = React.createContext(false);

export function useMotionSettings(): MotionSettings {
	return React.useContext(MotionSettingsContext);
}

const MOTION_SCALE_FLOOR = 0.32;
const MOTION_SCALE_CEIL = 1.6;
const SOFT_STIFFNESS = 0.82;
const SOFT_DAMPING = 56;
const SOFT_CLOCK_SPEED = 0.6;
const SOFT_PULSE_DEPTH = 0.45;
const SOFT_FLASH_PEAK = 0.55;

function softSpring(stiffness: number, damping: number, soft: boolean): LuaTuple<[number, number]> {
	if (!soft) {
		return $tuple(stiffness, damping);
	}
	return $tuple(stiffness * SOFT_STIFFNESS, math.max(damping, SOFT_DAMPING));
}

function softRatio(dampingRatio: number, frequency: number, soft: boolean): LuaTuple<[number, number]> {
	if (!soft) {
		return $tuple(dampingRatio, frequency);
	}
	return $tuple(math.max(dampingRatio, 1), frequency * SOFT_STIFFNESS);
}

const TAU = math.pi * 2;

type FrameListener = (deltaTime: number) => void;

interface ClockSlot {
	speed: number;
	period: number;
	phase: number;
	alive: boolean;
	listed: boolean;
	realtime: boolean;
	push?: (value: number) => void;
}

const listeners = new Map<FrameListener, number>();
const continuousListeners = new Map<FrameListener, number>();
const realtimeClocks = new Array<ClockSlot>();
const decorativeClocks = new Array<ClockSlot>();
let listenerCount = 0;
let continuousListenerCount = 0;
let realtimeClockCount = 0;
let decorativeClockCount = 0;
let driver: RBXScriptConnection | undefined;
const LISTENER_SOFT_CAP = 32;
let warnedOverCap = false;
const freezeNav = false;
let clockBudget = 24;
const flipperMotors = new Set<FlipperSingleMotor>();
const flipperToken = new Map<FlipperSingleMotor, number>();
let flipperCount = 0;

export interface ArrivalMotor {
	setGoal(goal: number): void;
	alive?(): boolean;
}

const pendingArrivals = new Map<ArrivalMotor, number>();
let pendingArrivalCount = 0;
const LAG_START_SECONDS = 1 / 48;
const LAG_FULL_SECONDS = 1 / 28;
let frameEma = 1 / 60;
let lagPressure = 0;
const flipperScratch = new Array<FlipperSingleMotor>();
const listenerScratch = new Array<FrameListener>();
const continuousScratch = new Array<FrameListener>();

function snapshotKeys<K>(set: ReadonlyMap<K, unknown> | ReadonlySet<K>, scratch: K[]): number {
	let size = 0;
	if (typeIs(set, "table")) {
		for (const [key] of pairs(set as unknown as Record<string, unknown>)) {
			scratch[size] = key as unknown as K;
			size += 1;
		}
	}
	return size;
}

function armFlipper(motor: FlipperSingleMotor) {
	flipperToken.set(motor, (flipperToken.get(motor) ?? 0) + 1);
	if (flipperMotors.has(motor)) {
		return;
	}
	flipperMotors.add(motor);
	flipperCount += 1;
	ensureDriver();
}

function disarmFlipper(motor: FlipperSingleMotor, expectedToken?: number) {
	if (expectedToken !== undefined && flipperToken.get(motor) !== expectedToken) {
		return;
	}
	flipperToken.delete(motor);
	if (!flipperMotors.has(motor)) {
		return;
	}
	flipperMotors.delete(motor);
	flipperCount -= 1;
	if (flipperCount < 0) {
		flipperCount = 0;
	}
}

function compactClocks(list: ClockSlot[]) {
	let write = 0;
	for (let index = 0; index < list.size(); index++) {
		const slot = list[index];
		if (slot !== undefined && slot.alive) {
			list[write] = slot;
			write += 1;
		} else if (slot !== undefined) {
			slot.listed = false;
		}
	}
	while (list.size() > write) {
		list.pop();
	}
}

let clockTicking = 0;
function tickClocks(list: ClockSlot[], deltaTime: number): number {
	let live = 0;
	let dead = 0;
	clockTicking += 1;
	for (let index = 0; index < list.size(); index++) {
		const slot = list[index];
		if (slot === undefined || !slot.alive) {
			dead += 1;
			continue;
		}
		const advanced = (slot.phase + deltaTime * slot.speed) % slot.period;
		slot.phase = advanced;
		live += 1;
		slot.push!(advanced);
	}
	clockTicking -= 1;
	if (dead >= 6 && clockTicking === 0) {
		compactClocks(list);
	}
	return live;
}

function removeClockSlot(list: ClockSlot[], slot: ClockSlot) {
	for (let index = list.size() - 1; index >= 0; index--) {
		if (list[index] === slot) {
			list.remove(index);
			return;
		}
	}
}

function addClock(slot: ClockSlot, realtime: boolean) {
	if (slot.listed && slot.realtime !== realtime) {
		removeClockSlot(slot.realtime ? realtimeClocks : decorativeClocks, slot);
		slot.listed = false;
		slot.alive = false;
	}
	slot.realtime = realtime;
	if (slot.listed) {
		if (!slot.alive) {
			slot.alive = true;
			if (realtime) {
				realtimeClockCount += 1;
			} else {
				decorativeClockCount += 1;
			}
			ensureDriver();
		}
		return;
	}
	slot.listed = true;
	slot.alive = true;
	if (realtime) {
		realtimeClocks.push(slot);
		realtimeClockCount += 1;
	} else {
		decorativeClocks.push(slot);
		decorativeClockCount += 1;
	}
	ensureDriver();
}

function dropClock(slot: ClockSlot | undefined, realtime: boolean) {
	if (slot === undefined || !slot.alive) {
		return;
	}
	slot.alive = false;
	if (realtime) {
		realtimeClockCount = math.max(0, realtimeClockCount - 1);
	} else {
		decorativeClockCount = math.max(0, decorativeClockCount - 1);
	}
	if (clockTicking === 0) {
		removeClockSlot(realtime ? realtimeClocks : decorativeClocks, slot);
		slot.listed = false;
		const remaining = realtime ? realtimeClockCount : decorativeClockCount;
		if (remaining === 0) {
			compactClocks(realtime ? realtimeClocks : decorativeClocks);
		}
	}
	stopDriverIfIdle();
}

export function setContinuousMotionRate(_rate: number) {}
export function beginUiTransition(_seconds?: number) {}

export function setClockBudget(budget: unknown) {
	const requested = typeIs(budget, "number") && budget === budget ? budget : 24;
	clockBudget = math.clamp(math.floor(requested + 0.5), 20, 48);
}

function scheduleArrival(motor: ArrivalMotor | undefined, delaySeconds: number) {
	if (motor === undefined) {
		return;
	}
	if (motor.alive !== undefined && !motor.alive()) {
		return;
	}
	if (!pendingArrivals.has(motor)) {
		pendingArrivalCount += 1;
	}
	pendingArrivals.set(motor, os.clock() + math.max(0, delaySeconds));
	ensureDriver();
}

function cancelArrival(motor: ArrivalMotor | undefined) {
	if (motor === undefined || !pendingArrivals.has(motor)) {
		return;
	}
	pendingArrivals.delete(motor);
	pendingArrivalCount -= 1;
	if (pendingArrivalCount < 0) {
		pendingArrivalCount = 0;
	}
}

function pumpArrivals() {
	if (pendingArrivalCount <= 0) {
		return;
	}
	const now = os.clock();
	let due: ArrivalMotor[] | undefined;
	for (const [motor, deadline] of pendingArrivals) {
		if (now >= deadline) {
			due ??= [];
			due.push(motor);
		}
	}
	if (due === undefined) {
		return;
	}
	for (const motor of due) {
		if (pendingArrivals.has(motor)) {
			pendingArrivals.delete(motor);
			pendingArrivalCount -= 1;
			if (motor.alive === undefined || motor.alive()) {
				motor.setGoal(1);
			}
		}
	}
	if (pendingArrivalCount < 0) {
		pendingArrivalCount = 0;
	}
}

function ensureDriver() {
	if (driver !== undefined) {
		return;
	}
	driver = RunService.RenderStepped.Connect((deltaTime) => {
		const clamped = math.clamp(deltaTime, 0, 0.25);
		const sample = math.min(deltaTime, 0.1);
		frameEma += (sample - frameEma) * math.min(1, sample * 2.5);
		const pressureTarget = math.clamp((frameEma - LAG_START_SECONDS) / (LAG_FULL_SECONDS - LAG_START_SECONDS), 0, 1);
		lagPressure += (pressureTarget - lagPressure) * math.min(1, sample * 1.5);
		if (flipperCount > 0) {
			const size = snapshotKeys(flipperMotors, flipperScratch);
			for (let index = 0; index < size; index++) {
				const motor = flipperScratch[index];
				flipperScratch[index] = undefined!;
				if (flipperMotors.has(motor)) {
					const token = flipperToken.get(motor);
					const SUBSTEP_MAX_DT = 1 / 60;
					const steps = math.clamp(math.ceil(clamped / SUBSTEP_MAX_DT), 1, 3);
					const subDt = clamped / steps;
					let completed = false;
					for (let n = 1; n <= steps; n++) {
						if (motor.step(subDt)) {
							completed = true;
							break;
						}
					}
					if (completed) {
						disarmFlipper(motor, token);
					}
				}
			}
		}
		if (realtimeClockCount > 0) {
			tickClocks(realtimeClocks, clamped);
		}
		if (listenerCount > 0) {
			const size = snapshotKeys(listeners, listenerScratch);
			for (let index = 0; index < size; index++) {
				const active = listenerScratch[index];
				listenerScratch[index] = undefined!;
				if (listeners.has(active)) {
					active(clamped);
				}
			}
		}
		if (decorativeClockCount > 0) {
			tickClocks(decorativeClocks, clamped);
		}
		if (continuousListenerCount > 0) {
			const size = snapshotKeys(continuousListeners, continuousScratch);
			for (let index = 0; index < size; index++) {
				const active = continuousScratch[index];
				continuousScratch[index] = undefined!;
				if (continuousListeners.has(active)) {
					active(clamped);
				}
			}
		}
		pumpArrivals();
		stopDriverIfIdle();
	});
}

function stopDriverIfIdle() {
	if (
		driver !== undefined &&
		flipperCount === 0 &&
		listenerCount === 0 &&
		continuousListenerCount === 0 &&
		realtimeClockCount === 0 &&
		decorativeClockCount === 0 &&
		pendingArrivalCount === 0
	) {
		driver.Disconnect();
		driver = undefined;
	}
}

function subscribe(listener: FrameListener): () => void {
	const held = listeners.get(listener);
	if (held === undefined) {
		listeners.set(listener, 1);
		listenerCount += 1;
		if (listenerCount > LISTENER_SOFT_CAP && !warnedOverCap) {
			warnedOverCap = true;
			print(`[forge] ${listenerCount} frame listeners (cap ${LISTENER_SOFT_CAP})`);
		}
	} else {
		listeners.set(listener, held + 1);
	}
	ensureDriver();
	let released = false;
	return () => {
		if (released) {
			return;
		}
		released = true;
		const remaining = listeners.get(listener);
		if (remaining === undefined) {
			return;
		}
		if (remaining > 1) {
			listeners.set(listener, remaining - 1);
			return;
		}
		listeners.delete(listener);
		listenerCount = math.max(0, listenerCount - 1);
		if (listenerCount <= LISTENER_SOFT_CAP) {
			warnedOverCap = false;
		}
		stopDriverIfIdle();
	};
}

export function subscribeContinuous(listener: FrameListener): () => void {
	const held = continuousListeners.get(listener);
	if (held === undefined) {
		continuousListeners.set(listener, 1);
		continuousListenerCount += 1;
	} else {
		continuousListeners.set(listener, held + 1);
	}
	ensureDriver();
	let released = false;
	return () => {
		if (released) {
			return;
		}
		released = true;
		const remaining = continuousListeners.get(listener);
		if (remaining === undefined) {
			return;
		}
		if (remaining > 1) {
			continuousListeners.set(listener, remaining - 1);
			return;
		}
		continuousListeners.delete(listener);
		continuousListenerCount = math.max(0, continuousListenerCount - 1);
		stopDriverIfIdle();
	};
}

export function useSpring(goal: number, _reducedMotion?: boolean, stiffness = 230, damping = 22, initial = goal): React.Binding<number> {
	const settings = useMotionSettings();
	const motionScale = settings.motionScale;
	[stiffness, damping] = softSpring(stiffness, damping, settings.soft === true);
	const effectiveStiffness = stiffness * MotionTokens.responseScale(motionScale);
	const spring = MotionTokens.feel(effectiveStiffness, damping);
	const [binding, ripple] = useRippleSpring(initial, {
		start: true,
		frequency: spring.frequency,
		dampingRatio: spring.dampingRatio,
	});
	React.useEffect(() => {
		ripple.setGoal(goal, { frequency: spring.frequency, dampingRatio: spring.dampingRatio });
	}, [damping, effectiveStiffness, goal, motionScale, ripple]);
	return binding as React.Binding<number>;
}

// a motor that lives as long as the component, reporting into a binding
function useMotor(initial: number, stiffness: number, damping: number, onRelease?: (motor: FlipperMotor) => void) {
	const [binding, setBinding] = React.useBinding(initial);
	const setBindingRef = React.useRef(setBinding);
	setBindingRef.current = setBinding;
	const motor = React.useRef<FlipperMotor>();
	if (motor.current === undefined) {
		motor.current = createFlipperMotor(initial, stiffness, damping);
	}
	React.useEffect(() => {
		const active = motor.current!;
		const disconnect = active.onChange((value) => setBindingRef.current(value));
		return () => {
			onRelease?.(active);
			disconnect();
			active.destroy();
			if (motor.current === active) {
				motor.current = undefined;
			}
		};
	}, []);
	return $tuple(binding, setBinding, motor);
}

export function useFlipperSpring(goal: number, reducedMotion?: boolean, stiffness = 900, damping = 36, initial = goal): React.Binding<number> {
	const settings = useMotionSettings();
	const motionScale = settings.motionScale;
	[stiffness, damping] = softSpring(stiffness, damping, settings.soft === true);
	const effectiveStiffness = stiffness * MotionTokens.responseScale(motionScale);
	const reducedRef = React.useRef(reducedMotion);
	const goalRef = React.useRef(goal);
	reducedRef.current = reducedMotion;
	goalRef.current = goal;
	const [binding, setBinding, motor] = useMotor(initial, effectiveStiffness, damping);
	React.useEffect(() => {
		const active = motor.current;
		if (active === undefined) {
			return;
		}
		active.configure(effectiveStiffness, damping);
		active.setGoal(goalRef.current);
	}, [damping, effectiveStiffness, goal, motionScale, setBinding]);
	return binding;
}

export function useSprScale(goal: number, _reducedMotion = false, initial = goal, dampingRatio = 0.82, frequency = 9): React.MutableRefObject<UIScale | undefined> {
	const settings = useMotionSettings();
	const motionScale = settings.motionScale;
	[dampingRatio, frequency] = softRatio(dampingRatio, frequency, settings.soft === true);
	const scaleRef = React.useRef<UIScale>();
	const mounted = React.useRef(false);
	const drivenScale = React.useRef<UIScale>();
	React.useEffect(() => {
		return () => {
			const scale = drivenScale.current;
			drivenScale.current = undefined;
			if (scale !== undefined) {
				spr.stop(scale);
			}
		};
	}, []);
	React.useEffect(() => {
		const scale = scaleRef.current;
		if (scale === undefined) {
			return;
		}
		drivenScale.current = scale;
		if (!mounted.current) {
			mounted.current = true;
			scale.Scale = initial;
		}
		if (scale.Parent !== undefined && scaleRef.current === scale) {
			spr.target(scale, math.clamp(dampingRatio, 0.6, 1.25), math.max(1, frequency * MotionTokens.responseScale(motionScale)), {
				Scale: goal,
			});
		}
	}, [dampingRatio, frequency, goal, initial, motionScale]);
	return scaleRef;
}

export function ScaleFromCenter(props: {
	scale?: number | React.Binding<number>;
	scaleRef?: React.Ref<UIScale>;
	zIndex?: number;
	children?: React.ReactNode;
}) {
	return (
		<frame
			Size={UDim2.fromScale(1, 1)}
			Position={UDim2.fromScale(0.5, 0.5)}
			AnchorPoint={new Vector2(0.5, 0.5)}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={props.zIndex}
		>
			{props.scaleRef !== undefined ? <uiscale ref={props.scaleRef} /> : <uiscale Scale={props.scale ?? 1} />}
			{props.children}
		</frame>
	);
}

export function useOptionalFlipperSpring(
	goal: number,
	enabled: boolean | undefined,
	reducedMotion?: boolean,
	stiffness = 900,
	damping = 36,
): React.Binding<number> {
	const settings = useMotionSettings();
	const motionScale = settings.motionScale;
	[stiffness, damping] = softSpring(stiffness, damping, settings.soft === true);
	const effectiveStiffness = stiffness * MotionTokens.responseScale(motionScale);
	const reducedRef = React.useRef(reducedMotion === true);
	const goalRef = React.useRef(goal);
	const enabledRef = React.useRef(enabled === true);
	reducedRef.current = reducedMotion === true;
	goalRef.current = goal;
	enabledRef.current = enabled === true;
	const [binding, setBinding, motor] = useMotor(enabled ? goal : 0, effectiveStiffness, damping);
	React.useEffect(() => {
		const active = motor.current;
		if (active === undefined) {
			return;
		}
		if (!enabledRef.current) {
			active.halt();
			active.setPosition(0);
			if (!enabledRef.current) {
				setBinding(0);
				return;
			}
		}
		active.configure(effectiveStiffness, damping);
		active.setGoal(goalRef.current);
	}, [damping, effectiveStiffness, enabled, goal, motionScale, setBinding]);
	return binding;
}

export function useBoatTween(
	goal: number,
	duration = 0.22,
	reducedMotion = false,
	easing: MotionTokens.Easing = MotionTokens.EASE.standard,
	initial?: number,
): React.Binding<number> {
	const start = initial === undefined ? goal : initial;
	const [binding, setBinding] = React.useBinding(start);
	const setBindingRef = React.useRef(setBinding);
	setBindingRef.current = setBinding;
	const current = React.useRef(start);
	const fromRef = React.useRef(start);
	const goalRef = React.useRef(goal);
	const elapsedRef = React.useRef(0);
	const runningRef = React.useRef(false);
	const easingRef = React.useRef(easing);
	const durationRef = React.useRef(duration);
	const reducedRef = React.useRef(reducedMotion);
	const stopRef = React.useRef<() => void>();
	const tickRef = React.useRef<FrameListener>();
	const release = () => {
		const stop = stopRef.current;
		stopRef.current = undefined;
		stop?.();
	};
	if (tickRef.current === undefined) {
		tickRef.current = (deltaTime) => {
			if (!runningRef.current) {
				release();
				return;
			}
			elapsedRef.current += deltaTime;
			const alpha = math.clamp(elapsedRef.current / math.max(0.01, durationRef.current), 0, 1);
			const from = fromRef.current;
			const target = goalRef.current;
			const value = from + (target - from) * easingRef.current(alpha);
			current.current = value;
			setBindingRef.current(value);
			if (alpha >= 1) {
				runningRef.current = false;
				release();
			}
		};
	}
	React.useEffect(() => {
		return () => {
			runningRef.current = false;
			release();
		};
	}, []);
	React.useEffect(() => {
		easingRef.current = easing;
		durationRef.current = duration;
		reducedRef.current = reducedMotion;
		goalRef.current = goal;
		const from = current.current;
		if (math.abs(from - goal) < 0.001) {
			current.current = goal;
			setBinding(goal);
			runningRef.current = false;
			return;
		}
		fromRef.current = from;
		elapsedRef.current = 0;
		runningRef.current = true;
		if (stopRef.current === undefined) {
			stopRef.current = subscribe(tickRef.current!);
		}
	}, [duration, easing, goal, reducedMotion, setBinding]);
	return binding;
}

const ALWAYS_VISIBLE = React.createBinding(1)[0];
export const ExitPresenceContext = React.createContext<React.Binding<number> | undefined>(undefined);

export function useExitPresence(): React.Binding<number> {
	return React.useContext(ExitPresenceContext) ?? ALWAYS_VISIBLE;
}

export function composePresence(enter: React.Binding<number>, leave: React.Binding<number>): React.Binding<number> {
	return React.joinBindings([enter, leave]).map((values) => math.clamp(math.min(values[0], values[1]), 0, 1));
}

export function useExitTransition(
	reducedMotion = false,
	duration = 0.18,
	resetWhenActive?: boolean,
): [React.Binding<number>, boolean, (after?: () => void) => void] {
	const [exiting, setExiting] = React.useState(false);
	const closing = React.useRef(false);
	const finished = React.useRef(false);
	const afterRef = React.useRef<() => void>();
	const startedAt = React.useRef(0);
	const spanRef = React.useRef(0.18);
	const running = React.useRef(false);
	const pendingAfter = React.useRef(false);
	const [amount, setAmount] = React.useBinding(1);
	const setAmountRef = React.useRef(setAmount);
	setAmountRef.current = setAmount;
	const stopRef = React.useRef<() => void>();
	const tickRef = React.useRef<FrameListener>();
	if (tickRef.current === undefined) {
		const release = () => {
			const stop = stopRef.current;
			stopRef.current = undefined;
			stop?.();
		};
		tickRef.current = () => {
			if (pendingAfter.current) {
				pendingAfter.current = false;
				const callback = afterRef.current;
				afterRef.current = undefined;
				if (!running.current) {
					release();
				}
				callback?.();
				return;
			}
			if (!running.current) {
				release();
				return;
			}
			let span = spanRef.current;
			if (span <= 0) {
				span = 0.01;
			}
			const alpha = math.clamp((os.clock() - startedAt.current) / span, 0, 1);
			const shown = alpha >= 1 ? 0 : 1 - MotionTokens.EASE.accelerate(alpha);
			setAmountRef.current(shown);
			if (alpha < 1) {
				return;
			}
			running.current = false;
			if (finished.current) {
				release();
				return;
			}
			finished.current = true;
			pendingAfter.current = true;
		};
	}
	React.useEffect(() => {
		return () => {
			running.current = false;
			pendingAfter.current = false;
			const stop = stopRef.current;
			stopRef.current = undefined;
			stop?.();
		};
	}, []);
	const begin = React.useCallback(
		(after?: () => void) => {
			closing.current = true;
			finished.current = false;
			pendingAfter.current = false;
			afterRef.current = after;
			setExiting(true);
			setAmount(1);
			startedAt.current = os.clock();
			spanRef.current = MotionTokens.exitSeconds(duration);
			running.current = true;
			if (stopRef.current === undefined) {
				stopRef.current = subscribe(tickRef.current!);
			}
		},
		[duration, reducedMotion, setAmount],
	);
	React.useEffect(() => {
		if (resetWhenActive !== true) {
			return;
		}
		running.current = false;
		pendingAfter.current = false;
		closing.current = false;
		finished.current = false;
		afterRef.current = undefined;
		setExiting(false);
		setAmount(1);
	}, [resetWhenActive, setAmount]);
	return [amount, exiting, begin];
}

export function useTokenEntrance(token: unknown, reducedMotion = false, duration = 0.16): React.Binding<number> {
	const [stiffness, damping] = MotionTokens.entranceSpring(duration, useMotionSettings().soft === true || reducedMotion === true);
	const [binding, setBinding, motor] = useMotor(0, stiffness, damping);
	React.useEffect(() => {
		const active = motor.current;
		if (active === undefined) {
			return;
		}
		active.halt();
		active.setPosition(0);
		setBinding(0);
		active.configure(stiffness, damping);
		active.setGoal(1);
	}, [damping, duration, setBinding, stiffness, token]);
	return binding;
}

export function useEntrance(reducedMotion = false): React.Binding<number> {
	return useFlipperSpring(1, reducedMotion === true, MotionTokens.SPRING.smooth.stiffness, MotionTokens.SPRING.smooth.damping, 0);
}

export function useStagger(index: number, reducedMotion = false, step = 0.025, duration = 0.14): React.Binding<number> {
	const [stiffness, damping] = MotionTokens.entranceSpring(duration, useMotionSettings().soft === true || reducedMotion === true);
	const [binding, setBinding, motor] = useMotor(0, stiffness, damping, (active) => cancelArrival(active));
	React.useEffect(() => {
		const active = motor.current;
		if (active === undefined) {
			return;
		}
		active.halt();
		active.setPosition(0);
		setBinding(0);
		active.configure(stiffness, damping);
		scheduleArrival(active, MotionTokens.stagger(index, step));
		return () => cancelArrival(active);
	}, [damping, duration, index, setBinding, step, stiffness]);
	return binding;
}

export function useClock(enabled: boolean, speed = 1, period = TAU, realtime = false): React.Binding<number> {
	const settings = useMotionSettings();
	const motionScale = settings.motionScale;
	const scaledSpeed =
		speed * math.clamp(motionScale, MOTION_SCALE_FLOOR, MOTION_SCALE_CEIL) * (settings.soft === true && !realtime ? SOFT_CLOCK_SPEED : 1);
	const live = enabled && speed > 0;
	const [binding, setBinding] = React.useBinding(0);
	const setBindingRef = React.useRef(setBinding);
	setBindingRef.current = setBinding;
	const phase = React.useRef(0);
	const slotRef = React.useRef<ClockSlot>();
	React.useEffect(() => {
		if (!live) {
			return undefined;
		}
		let slot = slotRef.current;
		if (slot === undefined) {
			slot = { speed: scaledSpeed, period, phase: phase.current, alive: false, listed: false, realtime };
			slotRef.current = slot;
		}
		const held = slot;
		held.speed = scaledSpeed;
		held.period = period;
		held.phase = phase.current;
		held.push = (value) => {
			phase.current = value;
			setBindingRef.current(value);
		};
		addClock(held, realtime);
		return () => {
			phase.current = held.phase;
			dropClock(held, held.realtime);
		};
	}, [live, period, realtime, setBinding, scaledSpeed]);
	return binding;
}

function syncedNow(): number {
	const value = Workspace.GetServerTimeNow();
	return typeIs(value, "number") && value === value ? value : os.time();
}

const [sharedWall, setSharedWall] = React.createBinding(syncedNow());
let wallUsers = 0;
let wallRelease: (() => void) | undefined;

export function useWallClock(_enabled?: boolean): React.Binding<number> {
	React.useEffect(() => {
		wallUsers += 1;
		if (wallRelease === undefined) {
			setSharedWall(syncedNow());
			wallRelease = subscribeContinuous(() => setSharedWall(syncedNow()));
		}
		return () => {
			wallUsers = math.max(0, wallUsers - 1);
			if (wallUsers === 0 && wallRelease !== undefined) {
				wallRelease();
				wallRelease = undefined;
			}
		};
	}, []);
	return sharedWall;
}

export function useRotation(enabled: boolean, degreesPerSecond?: number): React.Binding<number> {
	return useClock(enabled, degreesPerSecond, 360, true);
}

export function useFlash(trigger: number, reducedMotion = false, duration = 0.22): React.Binding<number> {
	const reducedRef = React.useRef(reducedMotion === true);
	reducedRef.current = reducedMotion === true;
	const seenTrigger = React.useRef<number>();
	const [binding, setBinding, motor] = useMotor(0, 900, 52);
	React.useEffect(() => {
		const active = motor.current;
		if (active === undefined) {
			return;
		}
		const triggerChanged = seenTrigger.current !== trigger;
		seenTrigger.current = trigger;
		if (trigger === 0) {
			active.halt();
			active.setPosition(0);
			setBinding(0);
			return;
		}
		if (!triggerChanged) {
			return;
		}
		const span = duration >= 0.75 ? duration : math.min(duration, 0.22);
		const stiffness = math.clamp(math.floor(180 / math.max(0.08, span)), 320, 1400);
		active.configure(stiffness, 52);
		active.setPosition(1);
		setBinding(1);
		active.setGoal(0);
	}, [duration, setBinding, trigger]);
	const peak = useMotionSettings().soft === true ? SOFT_FLASH_PEAK : 1;
	return React.useMemo(() => (peak >= 1 ? binding : binding.map((value) => value * peak)), [binding, peak]);
}

export function usePulse(enabled: boolean, speed = 1.35): React.Binding<number> {
	const clock = useClock(enabled, speed, TAU);
	const depth = useMotionSettings().soft === true ? SOFT_PULSE_DEPTH : 1;
	return React.useMemo(() => clock.map((phase) => 0.5 + math.sin(phase) * 0.5 * depth), [clock, depth]);
}

export function useGlowStroke(active: boolean, reducedMotion: boolean | undefined, rest: number, near = 0.2, far = 0.48, speed = 1.55): React.Binding<number> {
	const [everActive, setEverActive] = React.useState(active);
	React.useEffect(() => {
		if (active) {
			setEverActive(true);
		}
	}, [active]);
	const pulse = usePulse(active, speed);
	const blend = useOptionalFlipperSpring(active ? 1 : 0, everActive, reducedMotion, 420, 36);
	return React.useMemo(
		() =>
			React.joinBindings([pulse, blend]).map((values) => {
				const swept = near + (1 - values[0]) * (far - near);
				return rest + (swept - rest) * values[1];
			}),
		[blend, far, near, pulse, rest],
	);
}

export interface Viewport {
	width: number;
	height: number;
	screenWidth: number;
	screenHeight: number;
	topInset: number;
	bottomInset: number;
	sideInset: number;
	keyboardOpen: boolean;
	desktop: boolean;
	compact: boolean;
	tight: boolean;
	short: boolean;
	tenFoot?: boolean;
}

function safeSize(): Vector2 {
	const rect = GuiService.GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets);
	return rect.Max.sub(rect.Min);
}

export function useViewport(): Viewport {
	const host = React.useContext(ViewportScaleContext);
	const [size, setSize] = React.useState(() => safeSize());
	React.useEffect(() => {
		if (host !== undefined) {
			return undefined;
		}
		let sizeConnection: RBXScriptConnection | undefined;
		const attach = () => {
			sizeConnection?.Disconnect();
			const camera = Workspace.CurrentCamera;
			if (!camera) {
				return;
			}
			setSize(safeSize());
			sizeConnection = camera.GetPropertyChangedSignal("ViewportSize").Connect(() => setSize(safeSize()));
		};
		attach();
		const cameraConnection = Workspace.GetPropertyChangedSignal("CurrentCamera").Connect(attach);
		return () => {
			sizeConnection?.Disconnect();
			cameraConnection.Disconnect();
		};
	}, [host]);
	React.useEffect(() => {
		if (host !== undefined) {
			return undefined;
		}
		const sync = () => setSize(safeSize());
		sync();
		const connection = GuiService.GetPropertyChangedSignal("TopbarInset").Connect(sync);
		return () => connection.Disconnect();
	}, [host]);
	const [keyboardOpen, setKeyboardOpen] = React.useState(UserInputService.OnScreenKeyboardVisible);
	React.useEffect(() => {
		if (host !== undefined) {
			return undefined;
		}
		const connection = UserInputService.GetPropertyChangedSignal("OnScreenKeyboardVisible").Connect(() => {
			setKeyboardOpen(UserInputService.OnScreenKeyboardVisible);
		});
		return () => connection.Disconnect();
	}, [host]);
	return React.useMemo((): Viewport => {
		if (host !== undefined) {
			return {
				width: host.width,
				height: host.height,
				screenWidth: host.screenWidth,
				screenHeight: host.screenHeight,
				topInset: host.topInset,
				bottomInset: host.bottomInset ?? 0,
				sideInset: host.sideInset ?? 0,
				keyboardOpen: host.keyboardOpen,
				desktop: host.desktop,
				compact: host.compact,
				tight: host.tight,
				short: host.short,
			};
		}
		return {
			width: size.X,
			height: size.Y,
			screenWidth: size.X,
			screenHeight: size.Y,
			topInset: 0,
			bottomInset: 0,
			sideInset: 0,
			keyboardOpen,
			desktop: usesDesktopStructure(size.X, size.Y),
			compact: size.X < Breakpoints.compact,
			tight: size.X < Breakpoints.tight,
			short: size.Y < Breakpoints.short,
		};
	}, [host, size, keyboardOpen]);
}

export function resolveIntent(request: IntentRequest): IntentPlan {
	return MotionIntent.resolve(request);
}

export interface AntilagInfo {
	tier?: unknown;
	particleBudget?: number;
	glowScale?: number;
	allowConfetti?: boolean;
}

ensureDriver();
