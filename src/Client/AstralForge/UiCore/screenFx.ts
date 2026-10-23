// Screen effects for UI moments: light at the edges, flashes, tints, a frosted blur, flipbook
// overlays and a sound, layered into one effect. Camera untouched (the game is UI-only).
//
//   ScreenFx.play("confirm");                 // a named effect
//   ScreenFx.play("reveal", 0.8);             // intensity scales strength (not timing)
//   ScreenFx.play(ScreenFx.forRarity(item.Rarity));
//   ScreenFx.playStack([                      // a custom stack, same tracks as the presets
//       ScreenFx.Track.Edge({ color: Palette.brass, size: 0.3, release: 0.6 }),
//       ScreenFx.Track.Sound({ cue: "unlock" }),
//   ]);
//
// Costs nothing when idle: the layer and its frame loop exist only while something plays.
// Settings > Graphics > Screen effects off leaves the sounds; Screen flashes and reduced motion
// gate the flash track. A different backend (e.g. MotionFX, if it's ever inserted) can take over
// with ScreenFx.setBackend; anything it declines falls back to this one.
import { flashesAllowed, isReducedMotion } from "../MotionPreference";
import { Palette } from "../CoreKit/theme";
import { easeOutCubic, useBoatTween, useStagger, useTokenEntrance } from "../MotionKit/motion";

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const Lighting = game.GetService("Lighting");

interface Envelope {
	/** seconds to full */
	attack?: number;
	/** seconds held at full */
	hold?: number;
	/** seconds back to nothing */
	release?: number;
	/** seconds before it starts */
	delay?: number;
}

export interface EdgeTrack extends Envelope {
	kind: "Edge";
	color: Color3;
	/** how far in from the edges, 0..1 of the shorter side */
	size?: number;
	strength?: number;
}
export interface FlashTrack extends Envelope {
	kind: "Flash";
	color: Color3;
	strength?: number;
}
export interface TintTrack extends Envelope {
	kind: "Tint";
	color: Color3;
	strength?: number;
}
export interface BlurTrack extends Envelope {
	kind: "Blur";
	/** BlurEffect size at full */
	size?: number;
	/** a frosted veil so the UI itself reads as blurred */
	veil?: Color3;
	strength?: number;
}
export interface OverlayTrack extends Envelope {
	kind: "Overlay";
	/** a flipbook sheet */
	image: string;
	columns: number;
	rows: number;
	frames?: number;
	fps?: number;
	/** cell size in pixels on the sheet */
	cell: Vector2;
	color?: Color3;
	strength?: number;
}
export interface SoundTrack {
	kind: "Sound";
	cue: string;
	delay?: number;
	speed?: number;
}
export type Track = EdgeTrack | FlashTrack | TintTrack | BlurTrack | OverlayTrack | SoundTrack;

export interface ScreenFxBackend {
	/** return false to let the built-in renderer handle it */
	play(this: void, name: string, intensity: number): boolean;
	playStack(this: void, tracks: Track[], intensity: number): boolean;
	stopAll(this: void): void;
}

interface AudioLike {
	play(this: unknown, name: string, speedMult?: number): boolean;
}

// ---------------------------------------------------------------------------------------------
// tracks (the short form; every field has a default)

const Track = table.freeze({
	Edge: (o: Partial<Omit<EdgeTrack, "kind">> = {}): EdgeTrack => ({ kind: "Edge", color: o.color ?? Palette.brass, ...o }),
	Flash: (o: Partial<Omit<FlashTrack, "kind">> = {}): FlashTrack => ({ kind: "Flash", color: o.color ?? Palette.cream, ...o }),
	Tint: (o: Partial<Omit<TintTrack, "kind">> = {}): TintTrack => ({ kind: "Tint", color: o.color ?? Palette.brass, ...o }),
	Blur: (o: Partial<Omit<BlurTrack, "kind">> = {}): BlurTrack => ({ kind: "Blur", ...o }),
	Overlay: (o: Omit<OverlayTrack, "kind">): OverlayTrack => ({ kind: "Overlay", ...o }),
	Sound: (o: Omit<SoundTrack, "kind">): SoundTrack => ({ kind: "Sound", ...o }),
});

const RARITY_COLOR: Record<string, Color3 | undefined> = {
	Common: Palette.cream,
	Uncommon: Palette.mint,
	Rare: Palette.cyan,
	Epic: Palette.violet,
	Legendary: Palette.mango,
	Mythic: Palette.pink,
	Celestial: Color3.fromRGB(170, 218, 232),
	Astral: Color3.fromRGB(167, 139, 250),
};

const presets: Record<string, Track[]> = {
	confirm: [
		Track.Edge({ color: Palette.brass, size: 0.16, strength: 0.55, attack: 0.05, release: 0.35 }),
		Track.Sound({ cue: "confirm" }),
	],
	modeSwitch: [
		Track.Tint({ color: Palette.cyan, strength: 0.14, attack: 0.08, hold: 0.05, release: 0.4 }),
		Track.Edge({ color: Palette.cyan, size: 0.22, strength: 0.6, attack: 0.08, release: 0.5 }),
		Track.Sound({ cue: "tabSwitch" }),
	],
	success: [
		Track.Flash({ color: Palette.cream, strength: 0.35, attack: 0.02, release: 0.3 }),
		Track.Edge({ color: Palette.mint, size: 0.24, strength: 0.7, attack: 0.06, hold: 0.1, release: 0.6 }),
		Track.Sound({ cue: "successChime" }),
	],
	error: [
		Track.Edge({ color: Palette.coral, size: 0.22, strength: 0.8, attack: 0.04, hold: 0.08, release: 0.45 }),
		Track.Tint({ color: Palette.coral, strength: 0.1, attack: 0.04, release: 0.35 }),
		Track.Sound({ cue: "error" }),
	],
	warning: [
		Track.Edge({ color: Palette.mango, size: 0.2, strength: 0.65, attack: 0.06, hold: 0.12, release: 0.5 }),
		Track.Sound({ cue: "locked" }),
	],
	milestone: [
		Track.Flash({ color: Palette.cream, strength: 0.55, attack: 0.03, release: 0.5 }),
		Track.Blur({ size: 14, veil: Palette.ink, strength: 0.35, attack: 0.1, hold: 0.35, release: 0.7 }),
		Track.Edge({ color: Palette.brass, size: 0.34, strength: 0.9, attack: 0.1, hold: 0.5, release: 1 }),
		Track.Tint({ color: Palette.brass, strength: 0.12, attack: 0.15, hold: 0.3, release: 0.9 }),
		Track.Sound({ cue: "unlock" }),
	],
};

/** a reveal coloured by rarity, stronger and longer for the rarer tiers */
function forRarity(rarity: string | undefined): Track[] {
	const color = RARITY_COLOR[rarity ?? ""] ?? Palette.cream;
	const rank = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"].indexOf(rarity ?? "Common");
	const k = math.clamp(rank, 0, 7) / 7;
	const tracks: Track[] = [
		Track.Edge({ color, size: 0.14 + k * 0.24, strength: 0.5 + k * 0.45, attack: 0.06, hold: 0.1 + k * 0.4, release: 0.5 + k * 0.6 }),
		Track.Sound({ cue: k >= 0.5 ? "crateRare" : "crateLand" }),
	];
	if (k >= 0.4) {
		tracks.push(Track.Flash({ color, strength: 0.25 + k * 0.35, attack: 0.02, release: 0.35 + k * 0.3 }));
	}
	if (k >= 0.7) {
		tracks.push(Track.Tint({ color, strength: 0.12, attack: 0.1, hold: 0.3, release: 0.8 }));
		tracks.push(Track.Blur({ size: 10, strength: 0.25, attack: 0.08, hold: 0.25, release: 0.6 }));
	}
	return tracks;
}
presets.reveal = forRarity("Epic");

// ---------------------------------------------------------------------------------------------
// the built-in renderer

let enabled = true;
let backend: ScreenFxBackend | undefined;
let audio: AudioLike | undefined;

interface Live {
	track: Track;
	intensity: number;
	born: number;
	length: number;
	apply(this: void, amount: number, age: number): void;
	finish(this: void): void;
}

let layer: ScreenGui | undefined;
let blur: BlurEffect | undefined;
let blurLevel = 0;
const live: Live[] = [];
let driver: RBXScriptConnection | undefined;

function envelopeLength(e: Envelope): number {
	return (e.delay ?? 0) + (e.attack ?? 0.08) + (e.hold ?? 0) + (e.release ?? 0.4);
}
function envelopeAt(e: Envelope, age: number): number {
	const t = age - (e.delay ?? 0);
	const attack = e.attack ?? 0.08;
	const hold = e.hold ?? 0;
	const release = e.release ?? 0.4;
	if (t < 0) {
		return 0;
	} else if (t < attack) {
		const u = t / math.max(attack, 1e-3);
		return 1 - (1 - u) * (1 - u);
	} else if (t < attack + hold) {
		return 1;
	}
	const u = math.clamp((t - attack - hold) / math.max(release, 1e-3), 0, 1);
	return (1 - u) * (1 - u);
}

function ensureLayer(): ScreenGui | undefined {
	if (layer !== undefined && layer.Parent !== undefined) {
		return layer;
	}
	const playerGui = Players.LocalPlayer?.FindFirstChildOfClass("PlayerGui");
	if (playerGui === undefined) {
		return undefined;
	}
	layer = new Instance("ScreenGui");
	layer.Name = "ScreenFx";
	layer.IgnoreGuiInset = true;
	layer.ResetOnSpawn = false;
	layer.DisplayOrder = 900;
	layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	layer.Parent = playerGui;
	return layer;
}

function fullFrame(parent: Instance, color: Color3, z: number): Frame {
	const frame = new Instance("Frame");
	frame.Size = UDim2.fromScale(1, 1);
	frame.BorderSizePixel = 0;
	frame.BackgroundColor3 = color;
	frame.BackgroundTransparency = 1;
	frame.Active = false;
	frame.ZIndex = z;
	frame.Parent = parent;
	return frame;
}

// light that comes in from all four sides: four strips, each fading toward the middle
function edgeFrames(parent: Instance, color: Color3, size: number): Frame[] {
	const strips: Frame[] = [];
	const fade = new NumberSequence([new NumberSequenceKeypoint(0, 0), new NumberSequenceKeypoint(0.55, 0.7), new NumberSequenceKeypoint(1, 1)]);
	const sides: Array<[UDim2, UDim2, Vector2, number]> = [
		[new UDim2(1, 0, size, 0), UDim2.fromScale(0, 0), new Vector2(0, 0), 90],
		[new UDim2(1, 0, size, 0), UDim2.fromScale(0, 1), new Vector2(0, 1), -90],
		[new UDim2(size * 0.62, 0, 1, 0), UDim2.fromScale(0, 0), new Vector2(0, 0), 0],
		[new UDim2(size * 0.62, 0, 1, 0), UDim2.fromScale(1, 0), new Vector2(1, 0), 180],
	];
	for (const [frameSize, position, anchor, rotation] of sides) {
		const strip = fullFrame(parent, color, 3);
		strip.Size = frameSize;
		strip.Position = position;
		strip.AnchorPoint = anchor;
		const gradient = new Instance("UIGradient");
		gradient.Rotation = rotation;
		gradient.Transparency = fade;
		gradient.Parent = strip;
		strips.push(strip);
	}
	return strips;
}

function start(track: Track, intensity: number, gui: ScreenGui): Live | undefined {
	const now = os.clock();
	if (track.kind === "Sound") {
		const cue = track.cue;
		const speed = track.speed;
		const fire = () => audio?.play(cue, speed);
		if ((track.delay ?? 0) > 0) {
			task.delay(track.delay!, fire);
		} else {
			fire();
		}
		return undefined;
	}
	if (!enabled) {
		return undefined;
	}
	const strength = (track.strength ?? 1) * intensity;
	if (track.kind === "Flash") {
		if (!flashesAllowed()) {
			return undefined;
		}
		const frame = fullFrame(gui, track.color, 5);
		return {
			track, intensity, born: now, length: envelopeLength(track),
			apply: (amount) => (frame.BackgroundTransparency = 1 - amount * math.clamp(strength, 0, 0.9)),
			finish: () => frame.Destroy(),
		};
	} else if (track.kind === "Tint") {
		const frame = fullFrame(gui, track.color, 1);
		return {
			track, intensity, born: now, length: envelopeLength(track),
			apply: (amount) => (frame.BackgroundTransparency = 1 - amount * math.clamp(strength, 0, 0.6)),
			finish: () => frame.Destroy(),
		};
	} else if (track.kind === "Edge") {
		const strips = edgeFrames(gui, track.color, math.clamp(track.size ?? 0.2, 0.02, 0.6));
		return {
			track, intensity, born: now, length: envelopeLength(track),
			apply: (amount) => {
				for (const strip of strips) {
					strip.BackgroundTransparency = 1 - amount * math.clamp(strength, 0, 1);
				}
			},
			finish: () => strips.forEach((strip) => strip.Destroy()),
		};
	} else if (track.kind === "Blur") {
		if (blur === undefined || blur.Parent === undefined) {
			blur = new Instance("BlurEffect");
			blur.Name = "ScreenFxBlur";
			blur.Size = 0;
			blur.Parent = Lighting;
		}
		const veil = fullFrame(gui, track.veil ?? Palette.ink, 2);
		const size = (track.size ?? 12) * intensity;
		let mine = 0;
		return {
			track, intensity, born: now, length: envelopeLength(track),
			apply: (amount) => {
				veil.BackgroundTransparency = 1 - amount * math.clamp(strength, 0, 0.7);
				blurLevel += amount * size - mine;
				mine = amount * size;
				blur!.Size = math.max(0, blurLevel);
			},
			finish: () => {
				blurLevel -= mine;
				veil.Destroy();
				if (blur !== undefined) {
					blur.Size = math.max(0, blurLevel);
				}
			},
		};
	} else if (track.kind === "Overlay") {
		if (isReducedMotion()) {
			return undefined;
		}
		const image = new Instance("ImageLabel");
		image.Size = UDim2.fromScale(1, 1);
		image.BackgroundTransparency = 1;
		image.Image = track.image;
		image.ImageRectSize = track.cell;
		image.ImageColor3 = track.color ?? new Color3(1, 1, 1);
		image.ImageTransparency = 1;
		image.ScaleType = Enum.ScaleType.Stretch;
		image.ZIndex = 4;
		image.Parent = gui;
		const frames = track.frames ?? track.columns * track.rows;
		const fps = track.fps ?? 24;
		const columns = track.columns;
		const cell = track.cell;
		return {
			track, intensity, born: now, length: envelopeLength(track),
			apply: (amount, age) => {
				const index = math.floor(math.max(0, age) * fps) % frames;
				image.ImageRectOffset = new Vector2((index % columns) * cell.X, math.floor(index / columns) * cell.Y);
				image.ImageTransparency = 1 - amount * math.clamp(strength, 0, 1);
			},
			finish: () => image.Destroy(),
		};
	}
	return undefined;
}

function step() {
	const now = os.clock();
	for (let index = live.size() - 1; index >= 0; index--) {
		const item = live[index];
		const age = now - item.born;
		if (age >= item.length) {
			item.finish();
			live.remove(index);
			continue;
		}
		const track = item.track as Envelope;
		item.apply(envelopeAt(track, age), age - (track.delay ?? 0));
	}
	if (live.size() === 0) {
		driver?.Disconnect();
		driver = undefined;
		// nothing left on screen: drop the layer and the blur so idle really is idle
		layer?.Destroy();
		layer = undefined;
		blur?.Destroy();
		blur = undefined;
		blurLevel = 0;
	}
}

function render(tracks: Track[], intensity: number) {
	const gui = ensureLayer();
	if (gui === undefined) {
		return;
	}
	for (const track of tracks) {
		const [ok, item] = pcall(start, track, intensity, gui);
		if (!ok) {
			warn(`[ScreenFx] ${track.kind}: ${tostring(item)}`);
		} else if (item !== undefined) {
			live.push(item);
			item.apply(0, 0);
		}
	}
	if (live.size() > 0 && driver === undefined) {
		driver = RunService.RenderStepped.Connect(step);
	} else if (live.size() === 0) {
		step();
	}
}

// ---------------------------------------------------------------------------------------------
// public API

/** Play a named effect (see names()); intensity scales strength, not timing. */
function play(nameOrTracks: string | Track[], intensity = 1): boolean {
	const k = math.clamp(intensity, 0, 2);
	if (typeIs(nameOrTracks, "table")) {
		return playStack(nameOrTracks as Track[], k);
	}
	const name = nameOrTracks as string;
	if (backend !== undefined) {
		const [ok, handled] = pcall(backend.play, name, k);
		if (ok && handled === true) {
			return true;
		}
	}
	const tracks = presets[name];
	if (tracks === undefined) {
		warn(`[ScreenFx] no effect named "${name}"`);
		return false;
	}
	render(tracks, k);
	return true;
}

/** The screen part of an effect only, for moments whose sound already plays elsewhere. */
function visual(nameOrTracks: string | Track[], intensity = 1): boolean {
	const tracks = typeIs(nameOrTracks, "table") ? (nameOrTracks as Track[]) : presets[nameOrTracks as string];
	if (tracks === undefined) {
		warn(`[ScreenFx] no effect named "${tostring(nameOrTracks)}"`);
		return false;
	}
	return playStack(
		tracks.filter((track) => track.kind !== "Sound"),
		intensity,
	);
}

/** Play a custom stack of tracks together. */
function playStack(tracks: Track[], intensity = 1): boolean {
	const k = math.clamp(intensity, 0, 2);
	if (backend !== undefined) {
		const [ok, handled] = pcall(backend.playStack, tracks, k);
		if (ok && handled === true) {
			return true;
		}
	}
	render(tracks, k);
	return true;
}

/** Register (or replace) a named effect. */
function define(name: string, tracks: Track[]) {
	presets[name] = tracks;
}

function names(): string[] {
	const list: string[] = [];
	for (const [name] of pairs(presets)) {
		list.push(name);
	}
	table.sort(list);
	return list;
}

function stopAll() {
	if (backend !== undefined) {
		pcall(backend.stopAll);
	}
	for (const item of live) {
		pcall(item.finish);
	}
	live.clear();
	step();
}

/** Settings > Graphics > Screen effects; off keeps the sounds. */
function configure(on: boolean) {
	enabled = on;
	if (!on) {
		stopAll();
	}
}

function setBackend(replacement: ScreenFxBackend | undefined) {
	backend = replacement;
}

function setAudio(api: AudioLike) {
	audio = api;
}

/** tracks on screen right now (0 when idle) */
function activeCount(): number {
	return live.size();
}

// ---- value motion: thin hooks over MotionKit so surfaces ask MotionFX for motion instead of
// hand-rolling it. No new curves: these are the same tweens/springs the pre-redesign UI used.
const TweenService = game.GetService("TweenService");

/** eased 0..1 value (MotionKit useBoatTween, easeOutCubic): tab slides, selection lifts */
function useEase(goal: number, seconds: number, reducedMotion = false, initial?: number) {
	return useBoatTween(goal, reducedMotion ? 0.01 : seconds, reducedMotion, easeOutCubic, initial);
}

/** 0..1 entrance that replays whenever `token` changes (MotionKit entrance spring) */
function useEnter(token: unknown, reducedMotion = false, seconds?: number) {
	return useTokenEntrance(token, reducedMotion, seconds);
}

/** list item reveal (MotionKit useStagger) */
function useReveal(index: number, reducedMotion = false) {
	return useStagger(index, reducedMotion);
}

/**
 * Imperative property tween for instance-driven surfaces (prompts, sprite stages). Same
 * TweenService curves those surfaces always used; reduced motion snaps to the goal.
 */
function tween<T extends Instance>(
	instance: T,
	info: TweenInfo,
	goal: Partial<ExtractMembers<T, Tweenable>>,
	reducedMotion?: boolean,
): Tween | undefined {
	if (reducedMotion ?? isReducedMotion()) {
		for (const [key, value] of pairs(goal as object)) {
			(instance as unknown as Record<string, unknown>)[key as string] = value;
		}
		return undefined;
	}
	const t = TweenService.Create(instance, info, goal);
	t.Play();
	return t;
}

export const ScreenFx = table.freeze({ Track, play, visual, playStack, define, names, forRarity, stopAll, configure, setBackend, setAudio, activeCount, useEase, useEnter, useReveal, tween });

/** the same API under the name the effect settings use */
export const MotionFX = ScreenFx;
