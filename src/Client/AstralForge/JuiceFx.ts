import { celebrationsAllowed, flashesAllowed, isReducedMotion } from "./MotionPreference";
// Game feel. Numbers pop where you tapped, coins fly into the counter they belong to and the counter
// bounces when they land, sparkle bursts mark big moments, short status lines float up mid-screen,
// and the screen flashes for the biggest hits. Everything is drawn by one host in its own ScreenGui
// (same insets as the main UI, so AbsolutePosition and tap positions share one space) from one clock.
import React from "@rbxts/react";
import * as theme from "./CoreKit/theme";
import * as NoticeMath from "./CoreKit/noticeMath";
import { compactNumber } from "./CoreKit/format";

// the coin shower plays a tick per landing; resolve the audio module once instead of per coin
let cachedJuiceAudio: { play(sound: string, pitch?: number): void } | undefined;
function juiceAudio(): { play(sound: string, pitch?: number): void } {
	if (cachedJuiceAudio === undefined) {
		cachedJuiceAudio = ((require(script.Parent!.FindFirstChild("AudioKit")! as ModuleScript) as (name: string) => unknown)("audio") as {
			Audio: { play(sound: string, pitch?: number): void };
		}).Audio;
	}
	return cachedJuiceAudio;
}

const RunService = game.GetService("RunService");
const UserInputService = game.GetService("UserInputService");
const Players = game.GetService("Players");

const P = theme.Palette;

// ArtKit is still Luau; require it through the kit factory at load time like the bundled code did.
const Icon = (
	(require(script.Parent!.FindFirstChild("ArtKit")! as ModuleScript) as (name: string) => unknown)("Icon") as {
		Icon: React.FunctionComponent<{
			kind: string;
			color: Color3;
			accent?: Color3;
			size?: number;
			position?: UDim2;
			anchorPoint?: Vector2;
			spin?: boolean;
		}>;
	}
).Icon;

// The react typings leave `Name` off host props (they expect keys), but the Luau pages set it
// directly so layouts and tests can find instances by name. Spread this to keep doing that.
function named(name: string): object {
	return { Name: name };
}

const h = React.createElement as unknown as (
	component: unknown,
	props?: Record<string, unknown> | undefined,
	...children: unknown[]
) => React.ReactElement;

type EffectKind = "number" | "coin" | "burst" | "flash" | "ring" | "press" | "spark" | "shockwave" | "gem";

interface Spark {
	vx: number;
	vy: number;
	life: number;
	hot: boolean;
}

interface EffectSpec {
	kind: EffectKind;
	text?: string;
	color?: Color3;
	at?: Vector2;
	big?: boolean;
	small?: boolean;
	icon?: string;
	drift?: number;
	tilt?: number;
	target?: string;
	from?: Vector2;
	to?: Vector2;
	velocity?: Vector2;
	scatter?: Vector2;
	delay?: number;
	size?: number;
	bend?: number;
	spin?: number;
	scale?: number;
	strength?: number;
	arrived?: boolean;
	last?: boolean;
	sparks?: Spark[];
	/** burst without the flash and ring (grind) */
	bare?: boolean;
}

interface Effect extends EffectSpec {
	id: number;
	born: number;
}

interface NoticeInfo {
	title: string;
	subtitle?: string;
	color: Color3;
	icon?: string;
	duration?: number;
	tone?: string;
	style: string;
	count: number;
	token?: number;
	hold?: number;
	startedAt?: number;
}

interface LiveEntry {
	key?: string;
	endsAt?: number;
	expiresAt: number;
	updatedAt: number;
	ttl?: number;
	priority?: number;
	[key: string]: unknown;
}

interface OmegaApi {
	Sub(this: void, a: unknown, b: unknown): unknown;
	Gt(this: void, a: unknown, b: unknown): boolean;
	Lt(this: void, a: unknown, b: unknown): boolean;
	Persist(this: void, a: unknown): number;
}

const CAPS: Record<string, number> = { number: 32, coin: 60, burst: 10, flash: 3, ring: 12, press: 10, spark: 32, shockwave: 8, gem: 16 };
const LIFE: Record<string, number> = { number: 1.25, burst: 1.05, flash: 0.45, ring: 0.65, press: 0.48, spark: 0.55, shockwave: 0.72, gem: 1.15 };
const COIN_SCATTER = 0.3; // the launch: a ballistic arc under gravity
const COIN_FLIGHT = 0.5; // the homing curve into the counter
const GRAVITY = 1100;
const COIN_STAGGER = 0.035;

// forge colours for heat (ForgeTheme.Base brass and ember)
const BRASS = Color3.fromRGB(250, 190, 72);
const EMBER = Color3.fromRGB(244, 92, 84);

const effects: Effect[] = [];
let hostSetter: ((list: Effect[]) => void) | undefined = undefined;
let clockSetter: ((time: number) => void) | undefined = undefined;
let nextId = 0;
const targets = new Map<string, Set<GuiObject>>();
const arrivalListeners = new Map<string, Set<() => void>>();
let lastPointer: Vector2 | undefined = undefined;
let lastPointerAt = -math.huge;
let reduced = false;

UserInputService.InputBegan.Connect((input) => {
	const kind = input.UserInputType;
	if (kind === Enum.UserInputType.MouseButton1 || kind === Enum.UserInputType.Touch) {
		lastPointer = new Vector2(input.Position.X, input.Position.Y);
		lastPointerAt = os.clock();
		const at = lastPointer;
		task.defer(() => {
			const playerGui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
			if (playerGui === undefined || reduced || isReducedMotion()) {
				return;
			}
			for (const object of playerGui.GetGuiObjectsAtPosition(at.X, at.Y)) {
				if (object.IsA("GuiButton") && object.Active && object.Visible) {
					Juice.press(at, P.cream);
					return;
				}
			}
		});
	}
});

// Studio only: Juice.debugFreeze(seconds) stops effect time so a screenshot can catch an effect
// mid-flight; when it ends, every effect resumes exactly where it stopped
let frozenAt: number | undefined = undefined;
let frozenTotal = 0;
function now(): number {
	return frozenAt ?? (os.clock() - frozenTotal);
}

// A tap can push four effects in one frame and every expiry used to re-render the host too;
// the list now goes out at most once per frame.
let notifyQueued = false;
function notify() {
	if (hostSetter === undefined || notifyQueued) {
		return;
	}
	notifyQueued = true;
	task.defer(() => {
		notifyQueued = false;
		if (hostSetter !== undefined) {
			hostSetter(table.clone(effects));
		}
	});
}

// An effect never changes after it's pushed (it animates off the shared clock), so its element
// is built once and handed back as the same object; React then skips the whole subtree when the
// list changes, instead of rebuilding dozens of spark bindings for every live effect.
const rendered = new Map<number, React.ReactElement | undefined>();
let renderedFor: React.Binding<number> | undefined = undefined;
function elementFor(effect: Effect, clock: React.Binding<number>): React.ReactElement | undefined {
	if (renderedFor !== clock) {
		rendered.clear();
		renderedFor = clock;
	}
	if (rendered.has(effect.id)) {
		return rendered.get(effect.id);
	}
	const element = renderEffect(effect, clock);
	rendered.set(effect.id, element);
	return element;
}

function push(spec: EffectSpec): Effect {
	nextId += 1;
	const effect = spec as Effect;
	effect.id = nextId;
	effect.born = now();
	let count = 0;
	for (let index = effects.size() - 1; index >= 0; index--) {
		if (effects[index].kind === effect.kind) {
			count += 1;
			if (count >= (CAPS[effect.kind] ?? 32)) {
				effects.remove(index);
			}
		}
	}
	effects.push(effect);
	if (clockSetter !== undefined) {
		clockSetter(effect.born);
	}
	notify();
	return effect;
}

function screenSize(): Vector2 {
	const camera = game.GetService("Workspace").CurrentCamera;
	return camera ? camera.ViewportSize : new Vector2(1280, 720);
}

// a GuiObject's centre in the effects layer's space (undefined when it is not really on screen)
function shownOnScreen(object: GuiObject): boolean {
	let node: Instance | undefined = object;
	while (node !== undefined) {
		if (node.IsA("GuiObject") && !node.Visible) {
			return false;
		}
		if (node.IsA("LayerCollector")) {
			return node.Enabled;
		}
		node = node.Parent;
	}
	return false;
}

function centreOf(object: GuiObject | undefined): Vector2 | undefined {
	if (object === undefined || object.Parent === undefined) {
		return undefined;
	}
	const [position, size] = [object.AbsolutePosition, object.AbsoluteSize];
	if (size.X <= 1 || size.Y <= 1 || !shownOnScreen(object)) {
		return undefined;
	}
	const screen = screenSize();
	const centre = new Vector2(position.X + size.X / 2, position.Y + size.Y / 2);
	if (centre.X < 0 || centre.Y < 0 || centre.X > screen.X || centre.Y > screen.Y) {
		return undefined;
	}
	return centre;
}

// where a named counter is right now: the first registered copy that is actually visible
function targetCentre(name: string): Vector2 | undefined {
	const registered = targets.get(name);
	if (registered === undefined) {
		return undefined;
	}
	for (const object of registered) {
		const centre = centreOf(object);
		if (centre !== undefined) {
			return centre;
		}
	}
	return undefined;
}

function arrive(name: string) {
	const listeners = arrivalListeners.get(name);
	if (listeners === undefined) {
		return;
	}
	for (const callback of listeners) {
		task.spawn(callback);
	}
}

const Juice = {
	// where the last tap landed, if it was recent; otherwise undefined
	pointer(this: void): Vector2 | undefined {
		if (now() - lastPointerAt < 1.2) {
			return lastPointer;
		}
		return undefined;
	},

	setReducedMotion(this: void, value: boolean) {
		reduced = value === true;
	},

	debugFreeze(this: void, seconds: number) {
		if (!RunService.IsStudio() || frozenAt !== undefined) {
			return;
		}
		frozenAt = now();
		task.delay(seconds, () => {
			const stoppedFor = (os.clock() - frozenTotal) - frozenAt!;
			frozenTotal += stoppedFor;
			frozenAt = undefined;
		});
	},

	centreOf(this: void, object: GuiObject | undefined): Vector2 | undefined {
		return centreOf(object);
	},

	// "+1.2K", floating up from where you tapped
	number(
		this: void,
		text: string,
		color?: Color3,
		options?: { at?: Vector2; big?: boolean; small?: boolean; icon?: string },
	) {
		const opts = options ?? {};
		push({
			kind: "number",
			text,
			color: color ?? P.cream,
			at: opts.at ?? Juice.defaultOrigin(),
			big: opts.big === true,
			small: opts.small === true,
			icon: opts.icon,
			drift: math.random(-34, 34),
			tilt: math.random(-8, 8),
		});
	},

	defaultOrigin(this: void): Vector2 {
		const size = screenSize();
		return Juice.pointer() ?? new Vector2(size.X / 2, size.Y * 0.62);
	},

	// coins that burst out of `from` and fly into the named counter, which bounces as they land
	coins(this: void, target: string, color?: Color3, icon?: string, count?: number, from?: Vector2): boolean {
		const destination = targetCentre(target);
		if (destination === undefined) {
			return false;
		}
		const origin = from ?? Juice.defaultOrigin();
		const total = math.clamp(math.floor(count ?? 8), 1, 14);
		for (let index = 1; index <= total; index++) {
			// thrown up and out like sparks off an anvil, never the same twice
			const angle = -math.pi / 2 + (math.random() - 0.5) * 2.2;
			const speed = 230 + math.random() * 220;
			push({
				kind: "coin",
				target,
				color: color ?? P.mango,
				icon,
				from: origin,
				velocity: new Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
				to: destination,
				delay: (index - 1) * COIN_STAGGER + math.random() * 0.02,
				size: 7 + math.random() * 4,
				arrived: false,
				last: index === total,
			});
		}
		return true;
	},

	// a sparkle burst: four-point stars, rays and a ring
	burst(this: void, at?: Vector2, color?: Color3, scale?: number) {
		if (!celebrationsAllowed()) {
			return;
		}
		const s = scale ?? 1;
		const sparks: Spark[] = [];
		for (let index = 1; index <= math.floor(8 + 3 * math.min(s, 2)); index++) {
			const angle = -math.pi / 2 + (math.random() - 0.5) * math.pi * 1.7;
			const speed = (280 + math.random() * 420) * s;
			sparks[index - 1] = { vx: math.cos(angle) * speed, vy: math.sin(angle) * speed, life: 0.45 + math.random() * 0.45, hot: math.random() < 0.35 };
		}
		push({ kind: "burst", at: at ?? Juice.defaultOrigin(), color: color ?? P.mango, scale: s, spin: math.random() * 360, sparks });
	},

	// a grinder spray for machine installs: a low fan of short, fast sparks thrown off to one side
	// and dropping, no flash or ring, so it reads as metalwork rather than a celebration
	grind(this: void, at?: Vector2, color?: Color3) {
		if (!celebrationsAllowed()) {
			return;
		}
		const side = math.random() < 0.5 ? -1 : 1;
		const sparks: Spark[] = [];
		for (let index = 1; index <= 10; index++) {
			const angle = (side > 0 ? 0 : math.pi) + side * -(0.15 + math.random() * 0.55);
			const speed = 380 + math.random() * 360;
			sparks[index - 1] = { vx: math.cos(angle) * speed, vy: math.sin(angle) * speed, life: 0.25 + math.random() * 0.3, hot: math.random() < 0.5 };
		}
		push({ kind: "burst", at: at ?? Juice.defaultOrigin(), color: color ?? P.mango, scale: 0.6, spin: 0, sparks, bare: true });
	},

	// Overcharge heat: a band of heat rolls out from the press, brass on a cold start and running
	// toward ember as the combo builds, a little wider each step. A crit throws it wide and knocks
	// sparks upward off the strike. Reduced Motion: none of it (the CRIT number still shows).
	heat(this: void, heat: number, critical: boolean, at?: Vector2) {
		if (reduced || isReducedMotion()) {
			return;
		}
		const h01 = math.clamp(heat, 0, 1);
		const origin = at ?? Juice.pointer() ?? Juice.defaultOrigin();
		const color = BRASS.Lerp(EMBER, h01);
		push({ kind: "ring", at: origin, color, scale: critical ? 2.4 : 1 + h01 * 0.9, size: critical ? 5 : 2 + h01 * 3 });
		if (critical && celebrationsAllowed()) {
			const sparks: Spark[] = [];
			for (let index = 1; index <= 8; index++) {
				const angle = -math.pi / 2 + (math.random() - 0.5) * 1.6;
				const speed = 420 + math.random() * 380;
				sparks[index - 1] = { vx: math.cos(angle) * speed, vy: math.sin(angle) * speed, life: 0.3 + math.random() * 0.3, hot: math.random() < 0.5 };
			}
			push({ kind: "burst", at: origin, color: EMBER, scale: 0.7, spin: 0, sparks, bare: true });
		}
	},

	// Collect: one brass pulse out of the vault counter as it empties (the coins fly separately)
	collectPulse(this: void) {
		if (reduced || isReducedMotion()) {
			return;
		}
		const at = targetCentre("VAULT");
		if (at !== undefined) {
			push({ kind: "ring", at, color: BRASS, scale: 1.6, size: 3 });
		}
	},

	// a quick ring under a tap
	ring(this: void, at?: Vector2, color?: Color3) {
		push({ kind: "ring", at: at ?? Juice.defaultOrigin(), color: color ?? P.cream });
	},

	// a button press: short rays burst out around the tap
	press(this: void, at?: Vector2, color?: Color3) {
		push({ kind: "press", at: at ?? Juice.defaultOrigin(), color: color ?? P.cream, spin: math.random() * 45 });
	},

	// a little four-point sparkle (where coins land, and drifting around the screen)
	spark(this: void, at: Vector2, color?: Color3, size?: number) {
		push({ kind: "spark", at, color: color ?? P.white, spin: math.random() * 45, size: size ?? 30 });
	},

	// an expanding sonic shockwave ring
	shockwave(this: void, at?: Vector2, color?: Color3, scale?: number) {
		push({ kind: "shockwave", at: at ?? Juice.defaultOrigin(), color: color ?? P.cyan, scale: scale ?? 1 });
	},

	// 3D tumbling faceted gemstones that arc dynamically into a target counter
	gem(this: void, target: string, color?: Color3, icon?: string, count?: number, from?: Vector2): boolean {
		const destination = targetCentre(target);
		if (destination === undefined) {
			return false;
		}
		const origin = from ?? Juice.defaultOrigin();
		const total = math.clamp(math.floor(count ?? 4), 1, 8);
		for (let index = 1; index <= total; index++) {
			const angle = -math.pi / 2 + (index - (total + 1) / 2) * 0.38 + math.random() * 0.2 - 0.1;
			const reach = 55 + math.random() * 45;
			push({
				kind: "gem",
				target,
				color: color ?? P.violet,
				icon: icon ?? "Core.3",
				from: origin,
				scatter: new Vector2(math.cos(angle) * reach, math.sin(angle) * reach),
				to: destination,
				delay: (index - 1) * 0.05,
				bend: math.random(-90, 90),
				spin: math.random(180, 540),
				arrived: false,
				last: index === total,
			});
		}
		return true;
	},

	/** Hold queued messages (the one showing still finishes) while a modal owns the screen. */
	holdNotices(this: void, held: boolean) {
		islandHeld = held;
		if (!held && islandQueue.size() > 0) {
			ensureDriver();
		}
	},

	setToastDensity(this: void, density: number) {
		islandQueueLimit = math.min(QUEUE_CAP, NoticeMath.MaxNotices(density));
		while (islandQueue.size() > islandQueueLimit) {
			let drop = islandQueue.size();
			let dropRank = math.huge;
			for (const [index, waiting] of pairs(islandQueue)) {
				const rank = priorityOf(waiting);
				if (rank < dropRank) {
					drop = index;
					dropRank = rank;
				}
			}
			islandQueue.remove(drop - 1);
		}
		islandNotify();
	},

	// an island registers here; callback(current, queuedCount) runs now and on every change
	subscribeIsland(this: void, callback: (current: NoticeInfo | undefined, queued: number) => void): () => void {
		islandSubscribers.add(callback);
		pcall(() => callback(islandCurrent !== undefined ? table.clone(islandCurrent) : undefined, islandQueue.size()));
		ensureDriver();
		return () => {
			islandSubscribers.delete(callback);
		};
	},

	// tapping the island moves on to the next message
	skipIsland(this: void) {
		if (islandCurrent !== undefined) {
			islandAdvance();
			ensureDriver();
		}
	},

	hasIsland(this: void): boolean {
		return !islandSubscribers.isEmpty();
	},

	// style: "notice" (title + line), "moment" (a big milestone: taller, rainbow rim), "pill" (one short line)
	banner(
		this: void,
		title: string,
		subtitle?: string,
		color?: Color3,
		icon?: string,
		duration?: number,
		tone?: string,
		style?: string,
	) {
		const cleanTitle = cleanText(title, TITLE_CAP) ?? cleanText(subtitle, TITLE_CAP);
		if (cleanTitle === undefined) {
			return;
		}
		let cleanSubtitle = cleanText(subtitle, SUBTITLE_CAP);
		if (cleanSubtitle === cleanTitle) {
			cleanSubtitle = undefined;
		}
		const info: NoticeInfo = {
			title: cleanTitle,
			subtitle: cleanSubtitle,
			color: typeIs(color, "Color3") ? color : P.mango,
			icon: typeIs(icon, "string") ? icon : undefined,
			duration: typeIs(duration, "number") && duration === duration ? duration : undefined,
			tone,
			style: style === "moment" || style === "pill" ? style : "notice",
			count: 1,
		};
		// the same message again just counts up on the one already showing or waiting
		const same = (other: NoticeInfo | undefined): boolean => {
			return other !== undefined && other.title === info.title && other.subtitle === info.subtitle;
		};
		if (same(islandCurrent)) {
			islandCurrent!.count += 1;
			islandCurrent!.startedAt = os.clock(); // and stays up a little longer
			islandNotify();
			return;
		}
		for (const waiting of islandQueue) {
			if (same(waiting)) {
				waiting.count += 1;
				islandNotify();
				return;
			}
		}
		// higher priority goes ahead of anything lower that is still waiting
		const rank = priorityOf(info);
		let at = islandQueue.size() + 1;
		for (const [index, waiting] of pairs(islandQueue)) {
			if (priorityOf(waiting) < rank) {
				at = index;
				break;
			}
		}
		islandQueue.insert(at - 1, info);
		while (islandQueue.size() > islandQueueLimit) {
			// the oldest, least important message makes room
			let drop = islandQueue.size();
			let dropRank = math.huge;
			for (const [index, waiting] of pairs(islandQueue)) {
				const r = priorityOf(waiting);
				if (r < dropRank) {
					drop = index;
					dropRank = r;
				}
			}
			islandQueue.remove(drop - 1);
		}
		islandNotify();
		ensureDriver();
	},

	// a big milestone ("REBIRTH 12!", "NEW WORLD!")
	moment(this: void, title: string, subtitle?: string, color?: Color3, icon?: string) {
		Juice.banner(title, subtitle, color, icon, 3.2, "Special", "moment");
	},

	// a short reply to a tap ("No rewards to claim."): a quick pill out of the island
	status(this: void, text: string, tone?: string) {
		const color = tone === "error" ? P.coral : tone === "success" ? P.mint : tone === "special" ? P.mango : P.cream;
		const icon = tone === "error" ? "Close.1" : tone === "success" ? "Check.2" : tone === "special" ? "Boost.8" : "Wave.4";
		Juice.banner(text, undefined, color, icon, 1.5, tone, "pill");
	},

	live(this: void, key: string, data: LiveEntry | undefined) {
		if (data === undefined) {
			liveEntries.delete(key);
		} else {
			const entry = table.clone(data);
			entry.key = key;
			entry.updatedAt = os.clock();
			entry.expiresAt = os.clock() + (entry.ttl ?? 8);
			liveEntries.set(key, entry);
			const delay = math.max(0.25, (entry.endsAt ?? entry.expiresAt) - os.clock() + 0.3);
			task.delay(delay, liveNotify);
		}
		liveNotify();
	},

	subscribeLive(this: void, callback: (top: LiveEntry | undefined) => void): () => void {
		liveSubscribers.add(callback);
		liveNotify();
		return () => {
			liveSubscribers.delete(callback);
		};
	},

	onActivity(this: void, callback: (kind: string, data: unknown) => void): () => void {
		activityListeners.add(callback);
		return () => {
			activityListeners.delete(callback);
		};
	},

	activity(this: void, kind: string, data: unknown) {
		for (const callback of activityListeners) {
			task.spawn(callback, kind, data);
		}
	},

	flash(this: void, color?: Color3, strength?: number) {
		if (reduced || !flashesAllowed()) {
			return;
		}
		push({ kind: "flash", color: color ?? P.cream, strength: math.clamp((strength ?? 0.35) * 0.6, 0, 0.45) });
	},

	// counters register so coins know where to fly; returns a cleanup
	registerTarget(this: void, name: string, object: GuiObject): () => void {
		let set = targets.get(name);
		if (set === undefined) {
			set = new Set();
			targets.set(name, set);
		}
		set.add(object);
		return () => {
			const current = targets.get(name);
			if (current) {
				current.delete(object);
			}
		};
	},

	onArrive(this: void, name: string, callback: () => void): () => void {
		let set = arrivalListeners.get(name);
		if (set === undefined) {
			set = new Set();
			arrivalListeners.set(name, set);
		}
		set.add(callback);
		return () => {
			const current = arrivalListeners.get(name);
			if (current) {
				current.delete(callback);
			}
		};
	},

	// hook for a counter: a ref to attach, and a 0..1 bump binding that kicks each time coins land
	useTarget(this: void, name: string): LuaTuple<[React.MutableRefObject<GuiObject | undefined>, React.Binding<number>]> {
		const ref = React.useRef<GuiObject | undefined>(undefined);
		const [bump, setBump] = React.useBinding(0);
		React.useEffect(() => {
			const object = ref.current;
			const release = object ? Juice.registerTarget(name, object) : undefined;
			let decay: RBXScriptConnection | undefined = undefined;
			let level = 0;
			const stopListening = Juice.onArrive(name, () => {
				level = math.min(1, level + 0.55);
				setBump(level);
				if (decay === undefined) {
					decay = RunService.RenderStepped.Connect((dt) => {
						level = math.max(0, level - dt * 3.2);
						setBump(level);
						if (level <= 0 && decay) {
							decay.Disconnect();
							decay = undefined;
						}
					});
				}
			});
			return () => {
				stopListening();
				if (release) release();
				if (decay) decay.Disconnect();
			};
		}, [name]);
		return $tuple(ref, bump);
	},

	celebrateGains(
		this: void,
		before: unknown,
		after: unknown,
		options?: { spend?: boolean; big?: boolean; coins?: number; skipVault?: boolean },
	): number {
		const O = omega();
		const opts = options ?? {};
		if (O === undefined || !typeIs(before, "table") || !typeIs(after, "table")) {
			return 0;
		}
		const beforeTable = before as Record<string, unknown>;
		const afterTable = after as Record<string, unknown>;
		const origin = Juice.defaultOrigin();
		let shown = 0;
		for (const currency of CURRENCIES) {
			if (currency.field === "Vault" && opts.skipVault) {
				continue;
			}
			const [ok, delta] = pcall(() => O.Sub(afterTable[currency.field] ?? 0, beforeTable[currency.field] ?? 0));
			if (!ok) {
				continue;
			}
			const at = origin.add(new Vector2(0, -shown * 40));
			if (O.Gt(delta, 0)) {
				Juice.number(`+${compactNumber(O.Persist(delta))} ${currency.unit}`, currency.color, { at, big: opts.big, icon: currency.icon });
				if (currency.field === "Cores" || (currency.field === "Stardust" && opts.big)) {
					Juice.gem(currency.target, currency.color, currency.icon, opts.coins ?? 5, origin);
				} else {
					Juice.coins(currency.target, currency.color, currency.icon, opts.coins ?? (opts.big ? 10 : 6), origin);
				}
				if (opts.big) {
					Juice.shockwave(origin, currency.color, 0.85);
				}
				shown += 1;
			} else if (opts.spend && !currency.gainOnly && O.Lt(delta, 0)) {
				Juice.number(`-${compactNumber(O.Persist(O.Sub(0, delta)))} ${currency.unit}`, P.coral, { at });
				shown += 1;
			}
		}
		return shown;
	},

	// the host: mount once, above everything
	Host(this: void, _props: object): React.ReactElement {
		const [list, setList] = React.useState<Effect[]>([]);
		const [clock, setClock] = React.useBinding(now());
		React.useEffect(() => {
			hostSetter = setList;
			clockSetter = setClock;
			// (no ambient twinkles: random sparks over buttons and text read as glitches)
			let lastCoinTick = -math.huge;
			let coinRun = 0;
			const connection = RunService.RenderStepped.Connect(() => {
				if (effects.size() === 0) {
					return;
				}
				const t = now();
				setClock(t);
				let removed = false;
				for (let index = effects.size() - 1; index >= 0; index--) {
					const effect = effects[index];
					const age = t - effect.born;
					if (
						(effect.kind === "coin" || effect.kind === "gem") &&
						!effect.arrived &&
						age >= (effect.delay ?? 0) + COIN_SCATTER + COIN_FLIGHT
					) {
						effect.arrived = true;
						arrive(effect.target!);
						if (effect.kind === "gem") {
							Juice.spark(effect.to!, theme.lighten(effect.color!, 0.5), 24);
							if (effect.last) {
								Juice.shockwave(effect.to, effect.color, 0.75);
								pcall(() => {
									juiceAudio().play("successChime");
								});
							}
						} else {
							// the sound lands with the coin: a soft tick that climbs through a shower
							if (t - lastCoinTick > 0.035) {
								coinRun = t - lastCoinTick > 0.4 ? 0 : coinRun + 1;
								lastCoinTick = t;
								pcall(() => {
									juiceAudio().play("countTick", 1 + math.min(coinRun, 12) * 0.035 + (effect.last ? 0.12 : 0));
								});
							}
							if (effect.last) {
								Juice.spark(effect.to!.add(new Vector2(math.random(-10, 10), math.random(-8, 8))), theme.lighten(effect.color!, 0.5));
							}
						}
					}
					if (age >= lifeOf(effect)) {
						effects.remove(index);
						removed = true;
					}
				}
				if (removed) {
					notify();
				}
			});
			return () => {
				connection.Disconnect();
				if (hostSetter === setList) {
					hostSetter = undefined;
					clockSetter = undefined;
				}
			};
		}, []);
		const children: Record<number, React.ReactElement | undefined> = {};
		const live = new Set<number>();
		for (const effect of list) {
			live.add(effect.id);
			children[effect.id] = elementFor(effect, clock);
		}
		for (const [id] of rendered) {
			if (!live.has(id)) {
				rendered.delete(id);
			}
		}
		// Studio only: the command bar gets its own copy of this module, so tests reach the live one
		// through an event on the layer ("number" | "coins" | "burst" | "status" | "flash" | "ring", args...)
		const hostRef = React.useRef<Frame | undefined>(undefined);
		React.useEffect(() => {
			if (!RunService.IsStudio()) {
				return undefined;
			}
			const host = hostRef.current;
			if (host === undefined) {
				return undefined;
			}
			const event = new Instance("BindableEvent");
			event.Name = "JuiceDebug";
			event.Parent = host;
			const connection = event.Event.Connect((kind: unknown, ...args: unknown[]) => {
				const fn = (Juice as unknown as Record<string, unknown>)[kind as string];
				if (typeIs(fn, "function")) {
					(fn as (...a: unknown[]) => void)(...args);
				}
			});
			return () => {
				connection.Disconnect();
				event.Destroy();
			};
		}, []);
		return h(
			"frame",
			{
				ref: hostRef,
				...named("JuiceFx"),
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				Active: false,
				ZIndex: 1,
			},
			children,
		);
	},
};

// ===========================================================================================
// The island's player. Every message in the game goes through here and nowhere else.
//
// One shared queue and one frame-driven clock, owned by this module rather than by any island:
//   * an island that remounts (phone <-> desktop layouts, a page rebuild) picks up exactly where
//     the player is; nothing queued is lost, nothing plays twice
//   * any number of islands show the same thing at the same time
//   * time, not a chain of callbacks, moves it on, so an error anywhere cannot stall it
//   * input is cleaned (tostring, no newlines, capped length), repeats coalesce into "x3",
//     milestones jump the queue, then warnings and errors, then everything else
//   * with no island mounted, messages wait (up to QUEUE_CAP) and play when one appears
// ===========================================================================================
const QUEUE_CAP = 10;
let islandQueueLimit = NoticeMath.MaxNotices(0.55);
const TITLE_CAP = 64;
const SUBTITLE_CAP = 150;
const islandQueue: NoticeInfo[] = [];
let islandCurrent: NoticeInfo | undefined = undefined;
const islandSubscribers = new Set<(current: NoticeInfo | undefined, queued: number) => void>();
let islandToken = 0;
let islandDriver: RBXScriptConnection | undefined = undefined;
// while a modal owns the screen, the message showing finishes and the rest wait their turn
let islandHeld = false;

function cleanText(value: unknown, cap: number): string | undefined {
	if (value === undefined) {
		return undefined;
	}
	let [text] = tostring(value).gsub("[\r\n\t]+", " ");
	[text] = text.gsub("%s%s+", " ");
	text = (text.match("^%s*(.-)%s*$")[0] as string | undefined) ?? text;
	if (text === "") {
		return undefined;
	}
	const [length] = utf8.len(text);
	if (typeIs(length, "number") && length > cap) {
		const cut = utf8.offset(text, cap) ?? (cap + 1);
		text = text.sub(1, cut - 1) + "…";
	}
	return text;
}

function priorityOf(info: NoticeInfo): number {
	if (info.style === "moment") {
		return 3;
	}
	const tone = tostring(info.tone ?? "").lower();
	if (tone === "error" || tone === "warning") {
		return 2;
	}
	return 1;
}

function islandNotify() {
	const queued = islandQueue.size();
	// a fresh copy each time, so a count going up still reads as a change
	const snapshot = islandCurrent !== undefined ? table.clone(islandCurrent) : undefined;
	for (const callback of islandSubscribers) {
		const [ok, problem] = pcall(() => callback(snapshot, queued));
		if (!ok) {
			warn("[Island] a subscriber failed: " + tostring(problem));
		}
	}
}

function holdFor(info: NoticeInfo): number {
	const base = info.duration ?? (info.style === "pill" ? 1.5 : info.style === "moment" ? 3.2 : 2.6);
	// a backlog plays through faster
	const backlog = islandQueue.size();
	return math.clamp(base * (backlog >= 3 ? 0.55 : backlog >= 1 ? 0.75 : 1), 0.9, 6);
}

function islandAdvance() {
	islandCurrent = undefined;
	if (!islandSubscribers.isEmpty() && !islandHeld) {
		const nextInfo = islandQueue.shift();
		if (nextInfo !== undefined) {
			islandToken += 1;
			nextInfo.token = islandToken;
			nextInfo.hold = holdFor(nextInfo);
			nextInfo.startedAt = os.clock();
			islandCurrent = nextInfo;
		}
	}
	islandNotify();
}

function ensureDriver() {
	if (islandDriver !== undefined) {
		return;
	}
	islandDriver = RunService.Heartbeat.Connect(() => {
		const [ok, problem] = pcall(() => {
			if (islandCurrent !== undefined) {
				if (os.clock() >= islandCurrent.startedAt! + islandCurrent.hold!) {
					islandAdvance();
				}
			} else if (islandQueue.size() > 0 && !islandSubscribers.isEmpty() && !islandHeld) {
				islandAdvance();
			}
			if (islandCurrent === undefined && islandQueue.size() === 0 && islandDriver !== undefined) {
				islandDriver.Disconnect();
				islandDriver = undefined;
			}
		});
		if (!ok) {
			// never let one bad message wedge the player: drop it and carry on
			warn("[Island] skipped a message: " + tostring(problem));
			islandCurrent = undefined;
		}
	});
}

// Live readouts any feature can pin to the island while something is happening:
//   Juice.live("wheel", { title = "SPINNING", value = "…", icon = <its own icon id>, color = c,
//                         endsAt = os.clock() + 4 (a draining bar) | progress = 0.4, priority = 2 })
//   Juice.live("wheel", nil)  -- done
// The island shows the most important live one whenever no message is playing. Entries expire on
// their own (endsAt, or `ttl` seconds after the last update, default 8) so nothing can stick.
const liveEntries = new Map<string, LiveEntry>();
const liveSubscribers = new Set<(top: LiveEntry | undefined) => void>();
function liveNotify() {
	const list: LiveEntry[] = [];
	const clock = os.clock();
	for (const [key, entry] of liveEntries) {
		if ((entry.endsAt !== undefined && clock > entry.endsAt + 0.2) || clock > entry.expiresAt) {
			liveEntries.delete(key);
		} else {
			list.push(entry);
		}
	}
	list.sort((a, b) => {
		if ((a.priority ?? 1) !== (b.priority ?? 1)) {
			return (a.priority ?? 1) > (b.priority ?? 1);
		}
		return a.updatedAt > b.updatedAt;
	});
	const top = list[0];
	for (const callback of liveSubscribers) {
		pcall(() => callback(top !== undefined ? table.clone(top) : undefined));
	}
}

// live activities the island can show while they last ("combo" = { combo, multiplier, max, window })
const activityListeners = new Set<(kind: string, data: unknown) => void>();

// big-number deltas between two snapshots: what you gained (or spent), shown where you tapped
let omegaModule: OmegaApi | false | undefined = undefined;
function omega(): OmegaApi | undefined {
	if (omegaModule === undefined) {
		const [ok, module] = pcall(() => {
			return require(
				game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("OmegaMath") as ModuleScript,
			) as OmegaApi;
		});
		omegaModule = ok ? module : false;
	}
	return omegaModule || undefined;
}

const CURRENCIES: { field: string; target: string; icon: string; color: Color3; unit: string; gainOnly?: boolean }[] = [
	{ field: "Cash", target: "FLUX", icon: "Flux.3", color: P.cyan, unit: "flux" },
	{ field: "Stardust", target: "DUST", icon: "Dust.1", color: P.mango, unit: "stardust" },
	{ field: "Cores", target: "CORES", icon: "Core.4", color: P.violet, unit: "cores" },
	{ field: "Vault", target: "VAULT", icon: "Flux.4", color: P.green, unit: "Flux stored", gainOnly: true },
];

function easeOutBack(x: number): number {
	const [c1, c3] = [1.70158, 2.70158];
	return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2;
}
function easeOutCubic(x: number): number {
	return 1 - (1 - x) ** 3;
}
function easeInCubic(x: number): number {
	return x * x * x;
}

function outlined(text: string, size: number, color: Color3, transparency: number, z: number): React.ReactElement {
	return h(
		"textlabel",
		{
			Size: UDim2.fromScale(1, 1),
			BackgroundTransparency: 1,
			Text: text,
			TextColor3: P.white,
			TextSize: size,
			TextTransparency: transparency,
			FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			ZIndex: z,
		},
		h("uigradient", {
			Color: new ColorSequence(theme.lighten(color, 0.3), color),
			Rotation: 90,
		}),
		h("uistroke", {
			Color: theme.darken(color, 0.82),
			Thickness: math.max(2, math.floor(size / 9)),
			Transparency: transparency,
			LineJoinMode: Enum.LineJoinMode.Round,
		}),
	);
}

function star(size: number, color: Color3, transparency: number, z: number): React.ReactElement {
	// a four-point sparkle: two tapered bars crossed
	const bar = (rotation: number): React.ReactElement => {
		return h(
			"frame",
			{
				Size: UDim2.fromOffset(math.max(2, size * 0.18), size),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				Rotation: rotation,
				BackgroundColor3: color,
				BackgroundTransparency: transparency,
				BorderSizePixel: 0,
				ZIndex: z,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uigradient", {
				Rotation: 90,
				Transparency: new NumberSequence([
					new NumberSequenceKeypoint(0, 1),
					new NumberSequenceKeypoint(0.5, 0),
					new NumberSequenceKeypoint(1, 1),
				]),
			}),
		);
	};
	return h(
		"frame",
		{
			Size: UDim2.fromOffset(size, size),
			AnchorPoint: new Vector2(0.5, 0.5),
			BackgroundTransparency: 1,
			ZIndex: z,
		},
		bar(0),
		bar(90),
		h(
			"frame",
			{
				Size: UDim2.fromOffset(size * 0.22, size * 0.22),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: P.white,
				BackgroundTransparency: transparency,
				BorderSizePixel: 0,
				ZIndex: z + 1,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
		),
	);
}

// where a droplet is `local_` seconds into its flight: a ballistic launch, then a quadratic curve
// into the counter whose first control point continues the launch velocity (no stall, no kink)
function dropletAt(effect: Effect, local_: number): Vector2 {
	if (local_ <= 0) {
		return effect.from!;
	}
	const v = effect.velocity ?? Vector2.zero;
	if (local_ < COIN_SCATTER) {
		return effect.from!.add(v.mul(local_)).add(new Vector2(0, 0.5 * GRAVITY * local_ * local_));
	}
	const launchEnd = effect.from!.add(v.mul(COIN_SCATTER)).add(new Vector2(0, 0.5 * GRAVITY * COIN_SCATTER * COIN_SCATTER));
	const exitVelocity = v.add(new Vector2(0, GRAVITY * COIN_SCATTER));
	const control = launchEnd.add(exitVelocity.mul(COIN_FLIGHT * 0.45));
	let u = math.clamp((local_ - COIN_SCATTER) / COIN_FLIGHT, 0, 1);
	u = u * u * (3 - 2 * u) * 0.35 + u * u * 0.65;
	const a1 = launchEnd.Lerp(control, u);
	const a2 = control.Lerp(effect.to!, u);
	return a1.Lerp(a2, u);
}

function renderEffect(effect: Effect, clock: React.Binding<number>): React.ReactElement | undefined {
	const age = (): React.Binding<number> => {
		return clock.map((t) => t - effect.born);
	};
	if (effect.kind === "number") {
		// hot-stamped: slams in white-hot with a jolt, cools into its colour, rises and fades
		const size = effect.big ? 34 : effect.small ? 17 : 24;
		const t = age();
		const textW = effect.text!.size() * size * 0.52;
		const life = LIFE.number;
		const heat = t.map((a) => 1 - math.clamp((a - 0.08) / 0.35, 0, 1));
		const fade = t.map((a) => math.clamp((a - life * 0.62) / (life * 0.38), 0, 1));
		const hotColor = heat.map((heatValue) => effect.color!.Lerp(P.white, heatValue * 0.4));
		return h(
			"frame",
			{
				key: effect.id,
				Size: UDim2.fromOffset(textW + size * 2 + 20, size + 14),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 30,
				Position: t.map((a) => {
					const jolt = a < 0.16 ? math.sin(a * 90) * 4 * (1 - a / 0.16) : 0;
					const rise = easeOutCubic(math.clamp((a - 0.18) / (life - 0.18), 0, 1)) * (effect.small ? 30 : 70);
					return UDim2.fromOffset(effect.at!.X + jolt + effect.drift! * 0.15 * math.clamp(a / life, 0, 1), effect.at!.Y - 20 - rise);
				}),
			},
			h("uiscale", {
				Scale: t.map((a) => {
					if (a < 0.1) {
						return 1.55 - (a / 0.1) * 0.65;
					}
					return 0.9 + easeOutBack(math.clamp((a - 0.1) / 0.18, 0, 1)) * 0.1;
				}),
			}),
			h(
				"textlabel",
				{
					Size: new UDim2(1, 0, 1, 0),
					BackgroundTransparency: 1,
					Text: effect.text,
					TextColor3: hotColor,
					TextTransparency: fade,
					TextSize: size,
					FontFace: Font.fromEnum(Enum.Font.BuilderSansExtraBold),
					ZIndex: 31,
				},
				// a soft drop shadow rather than an outline
				h("uistroke", {
					Color: theme.darken(effect.color!, 0.8),
					Thickness: effect.small ? 1 : 1.5,
					Transparency: fade.map((f) => 0.45 + f * 0.55),
				}),
			),
			effect.icon &&
				h(
					"frame",
					{
						Size: UDim2.fromOffset(size * 0.9, size * 0.9),
						Position: new UDim2(0.5, -textW / 2 - size * 0.62, 0.5, 0),
						AnchorPoint: new Vector2(0.5, 0.5),
						BackgroundColor3: theme.darken(effect.color!, 0.55),
						BackgroundTransparency: fade,
						BorderSizePixel: 0,
						ZIndex: 31,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
					h(Icon, {
						kind: effect.icon,
						color: P.white,
						accent: effect.color,
						size: math.floor(size * 0.66),
						position: UDim2.fromScale(0.5, 0.5),
						anchorPoint: new Vector2(0.5, 0.5),
						spin: false,
					}),
				),
		);
	} else if (effect.kind === "coin") {
		// a molten droplet: white-hot core, coloured glow, a short trail of cooling embers behind it
		const t = age();
		const d = effect.size ?? 9;
		const parts: Record<string, React.ReactElement> = {};
		for (let index = 0; index <= 2; index++) {
			const lag = index * 0.028;
			parts[`e${index}`] = h(
				"frame",
				{
					Size: UDim2.fromOffset(d * (1 - index * 0.2), d * (1 - index * 0.2)),
					AnchorPoint: new Vector2(0.5, 0.5),
					Position: t.map((a) => {
						const spot = dropletAt(effect, a - (effect.delay ?? 0) - lag);
						return UDim2.fromOffset(spot.X, spot.Y);
					}),
					BackgroundColor3: index === 0 ? theme.lighten(effect.color!, 0.55) : effect.color!,
					BackgroundTransparency: index === 0 ? 0 : 0.45 + index * 0.2,
					BorderSizePixel: 0,
					ZIndex: 26 - index,
					Visible: t.map((a) => a - lag >= (effect.delay ?? 0)),
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
				index === 0 &&
					h("uistroke", {
						Color: theme.darken(effect.color!, 0.35),
						Thickness: 1,
						Transparency: 0.3,
					}),
			);
		}
		return h(
			"frame",
			{
				key: effect.id,
				Size: UDim2.fromScale(1, 1),
				BackgroundTransparency: 1,
				ZIndex: 26,
			},
			parts,
		);
	} else if (effect.kind === "burst") {
		// an anvil strike: sparks fly at uneven angles and speeds, fall, and stretch along their path
		const t = age();
		const s = effect.scale ?? 1;
		const children: Record<string, React.ReactElement> = {};
		const progress = t.map((a) => math.clamp(a / LIFE.burst, 0, 1));
		for (const [index, spark] of pairs(effect.sparks ?? [])) {
			const alive = (a: number): number => {
				const u = math.clamp(a / spark.life, 0, 1);
				return 1 - u * u;
			};
			const streak = (name: string, thickness: number) => {
				children[name + index] = h(
					"frame",
					{
						Size: t.map((a) => {
							const vy = spark.vy + GRAVITY * a;
							const speed = math.sqrt(spark.vx * spark.vx + vy * vy);
							return UDim2.fromOffset(math.clamp(speed * 0.06, 8, 44) * (0.35 + 0.65 * alive(a)), thickness);
						}),
						AnchorPoint: new Vector2(0.5, 0.5),
						Position: t.map((a) => {
							return UDim2.fromOffset(spark.vx * a, spark.vy * a + 0.5 * GRAVITY * a * a);
						}),
						Rotation: t.map((a) => {
							return math.deg(math.atan2(spark.vy + GRAVITY * a, spark.vx));
						}),
						BackgroundColor3: theme.lighten(effect.color!, spark.hot ? 0.6 : 0.3),
						BackgroundTransparency: t.map((a) => 1 - alive(a) * 0.85),
						BorderSizePixel: 0,
						ZIndex: 28,
					},
					h("uicorner", { CornerRadius: new UDim(1, 0) }),
					h("uigradient", {
						// bright head, cooling tail
						Transparency: new NumberSequence([new NumberSequenceKeypoint(0, 0.85), new NumberSequenceKeypoint(0.7, 0.1), new NumberSequenceKeypoint(1, 0)]),
					}),
				);
			};
			streak("spark", spark.hot ? 3 : 2);
		}
		if (effect.bare === true) {
			return h(
				"frame",
				{ key: effect.id, Size: UDim2.fromOffset(0, 0), Position: UDim2.fromOffset(effect.at!.X, effect.at!.Y), BackgroundTransparency: 1, ZIndex: 27 },
				children,
			);
		}
		children.core = h(
			"frame",
			{
				Size: progress.map((p) => {
					const dd = (14 + easeOutCubic(math.min(1, p * 7)) * 46) * s;
					return UDim2.fromOffset(dd, dd);
				}),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: theme.lighten(effect.color!, 0.55),
				BackgroundTransparency: progress.map((p) => 0.4 + math.clamp(p * 7, 0, 1) * 0.6),
				BorderSizePixel: 0,
				ZIndex: 29,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
		);
		children.ring = h(
			"frame",
			{
				Size: progress.map((p) => {
					const dd = (20 + easeOutCubic(p) * 110) * s;
					return UDim2.fromOffset(dd, dd);
				}),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 27,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: effect.color,
				Thickness: progress.map((p) => math.max(1, 2 * (1 - p))),
				Transparency: progress.map((p) => 0.3 + math.clamp(p * 1.6, 0, 1) * 0.7),
			}),
		);
		return h(
			"frame",
			{
				key: effect.id,
				Size: UDim2.fromOffset(0, 0),
				Position: UDim2.fromOffset(effect.at!.X, effect.at!.Y),
				BackgroundTransparency: 1,
				ZIndex: 27,
			},
			children,
		);
	} else if (effect.kind === "ring") {
		const t = age();
		return h(
			"frame",
			{
				key: effect.id,
				Size: t.map((a) => {
					const d = 18 + easeOutCubic(math.clamp(a / LIFE.ring, 0, 1)) * 70 * (effect.scale ?? 1);
					return UDim2.fromOffset(d, d);
				}),
				Position: UDim2.fromOffset(effect.at!.X, effect.at!.Y),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 25,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: effect.color,
				Thickness: t.map((a) => (effect.size ?? 2) * (1 - 0.5 * math.clamp(a / LIFE.ring, 0, 1))),
				Transparency: t.map((a) => 0.35 + math.clamp(a / LIFE.ring, 0, 1) * 0.65),
			}),
		);
	} else if (effect.kind === "press") {
		const t = age();
		const progress = t.map((a) => math.clamp(a / LIFE.press, 0, 1));
		const spokes: Record<string, React.ReactElement> = {};
		for (let index = 1; index <= 6; index++) {
			const angle = math.rad((effect.spin ?? 0) + index * 60);
			spokes[`s${index}`] = h(
				"frame",
				{
					Size: progress.map((p) => UDim2.fromOffset(2, 5 + (1 - p) * 8)),
					AnchorPoint: new Vector2(0.5, 0.5),
					Rotation: math.deg(angle) + 90,
					Position: progress.map((p) => {
						const r = 14 + easeOutCubic(p) * 26;
						return UDim2.fromOffset(math.cos(angle) * r, math.sin(angle) * r);
					}),
					BackgroundColor3: effect.color,
					BackgroundTransparency: progress.map((p) => 0.3 + p * 0.7),
					BorderSizePixel: 0,
					ZIndex: 25,
				},
				h("uicorner", { CornerRadius: new UDim(1, 0) }),
			);
		}
		spokes.ring = h(
			"frame",
			{
				Size: progress.map((p) => {
					const d = 16 + easeOutCubic(p) * 44;
					return UDim2.fromOffset(d, d);
				}),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 25,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: effect.color,
				Thickness: 1,
				Transparency: progress.map((p) => 0.45 + p * 0.55),
			}),
		);
		return h(
			"frame",
			{
				key: effect.id,
				Size: UDim2.fromOffset(0, 0),
				Position: UDim2.fromOffset(effect.at!.X, effect.at!.Y),
				BackgroundTransparency: 1,
				ZIndex: 25,
			},
			spokes,
		);
	} else if (effect.kind === "spark") {
		const t = age();
		return h(
			"frame",
			{
				key: effect.id,
				Size: UDim2.fromOffset(effect.size ?? 30, effect.size ?? 30),
				Position: UDim2.fromOffset(effect.at!.X, effect.at!.Y),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 34,
				Rotation: t.map((a) => (effect.spin ?? 0) + a * 120),
			},
			h("uiscale", {
				Scale: t.map((a) => math.sin(math.clamp(a / LIFE.spark, 0, 1) * math.pi) * 0.85 + 0.01),
			}),
			star(effect.size ?? 30, effect.color!, 0, 34),
		);
	} else if (effect.kind === "flash") {
		const t = age();
		return h("frame", {
			key: effect.id,
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: effect.color,
			BorderSizePixel: 0,
			ZIndex: 20,
			BackgroundTransparency: t.map((a) => {
				return 1 - (effect.strength ?? 0) * (1 - math.clamp(a / LIFE.flash, 0, 1));
			}),
		});
	} else if (effect.kind === "shockwave") {
		const t = age();
		const s = effect.scale ?? 1;
		const progress = t.map((a) => math.clamp(a / LIFE.shockwave, 0, 1));
		return h(
			"frame",
			{
				key: effect.id,
				Size: progress.map((p) => {
					const d = (24 + easeOutCubic(p) * 200) * s;
					return UDim2.fromOffset(d, d);
				}),
				Position: UDim2.fromOffset(effect.at!.X, effect.at!.Y),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 25,
			},
			h("uicorner", { CornerRadius: new UDim(1, 0) }),
			h("uistroke", {
				Color: effect.color,
				Thickness: progress.map((p) => math.max(1, (1 - p) * 2)),
				Transparency: progress.map((p) => 0.35 + p * 0.65),
			}),
		);
	} else if (effect.kind === "gem") {
		const t = age();
		const size = 28;
		return h(
			"frame",
			{
				key: effect.id,
				Size: UDim2.fromOffset(size, size),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundTransparency: 1,
				ZIndex: 28,
				Position: t.map((a) => {
					const local_ = a - (effect.delay ?? 0);
					if (local_ <= 0) {
						return UDim2.fromOffset(effect.from!.X, effect.from!.Y);
					}
					if (local_ < COIN_SCATTER) {
						const p = easeOutCubic(local_ / COIN_SCATTER);
						const spot = effect.from!.add(effect.scatter!.mul(p));
						return UDim2.fromOffset(spot.X, spot.Y);
					}
					const p = easeInCubic(math.clamp((local_ - COIN_SCATTER) / COIN_FLIGHT, 0, 1));
					const start = effect.from!.add(effect.scatter!);
					const mid = start.add(effect.to!).div(2).add(new Vector2(effect.bend ?? 0, -110));
					const a1 = start.Lerp(mid, p);
					const a2 = mid.Lerp(effect.to!, p);
					const spot = a1.Lerp(a2, p);
					return UDim2.fromOffset(spot.X, spot.Y);
				}),
				Rotation: t.map((a) => {
					const local_ = math.max(0, a - (effect.delay ?? 0));
					return (local_ * (effect.spin ?? 360)) % 360;
				}),
				Visible: t.map((a) => a >= (effect.delay ?? 0)),
			},
			h("uiscale", {
				Scale: t.map((a) => {
					const local_ = a - (effect.delay ?? 0);
					const grow = easeOutBack(math.clamp(local_ / 0.16, 0, 1));
					const shrink = 1 - 0.4 * math.clamp((local_ - COIN_SCATTER - COIN_FLIGHT * 0.6) / (COIN_FLIGHT * 0.4), 0, 1);
					const tumble = 0.8 + math.abs(math.cos(local_ * 12)) * 0.35;
					return math.max(0.05, grow * shrink * tumble);
				}),
			}),
			h(
				"frame",
				{
					Size: UDim2.fromScale(1, 1),
					BackgroundColor3: theme.darken(effect.color!, 0.6),
					BorderSizePixel: 0,
					Rotation: 45,
					ZIndex: 28,
				},
				h("uicorner", { CornerRadius: new UDim(0, 6) }),
				h("uistroke", {
					Color: theme.lighten(effect.color!, 0.25),
					Thickness: 1,
					Transparency: 0.35,
				}),
				h("uigradient", {
					Color: new ColorSequence(theme.lighten(effect.color!, 0.3), theme.darken(effect.color!, 0.25)),
					Rotation: 45,
				}),
				effect.icon &&
					h(Icon, {
						kind: effect.icon,
						color: P.white,
						accent: effect.color,
						size: size - 8,
						position: UDim2.fromScale(0.5, 0.5),
						anchorPoint: new Vector2(0.5, 0.5),
						spin: false,
					}),
			),
		);
	}
	return undefined;
}

function lifeOf(effect: Effect): number {
	if (effect.kind === "coin" || effect.kind === "gem") {
		return (effect.delay ?? 0) + COIN_SCATTER + COIN_FLIGHT + 0.04;
	}
	return LIFE[effect.kind] ?? 1;
}

export = Juice;
