// FancyText (vendor/@rbxts/fancytext, github.com/TonyCifer/fancy-text v1.1.0) behind a typed API.
//
// Titles are described by a config table instead of hand-written tag strings, so the effects can
// follow real state (rarity, an active mode, a full bar) and the player's settings:
//
//   const trove = FancyText.make(frame, {
//       text: "Forge Level 12",
//       size: 34,
//       color: Palette.cream,
//       shadow: true,
//       wave: true,
//       state: { rarity: "Celestial" },       // picks the colour sweep and how strong it is
//       parts: [{ text: " UNLOCKED", tags: ["smash"] }], // only this bit gets the effect
//   });
//   button.Activated.Once(() => trove.PlayEffect("fade", ["0", "0.4"], true));
//
// Reduced motion keeps colour and shadow but drops wave, shake, typewrite and moving colour.
// Settings > Graphics > Rainbow colour scales the sweep (0 turns it off).
import Rainbow = require("../Rainbow");
import IconManifest = require("../IconManifest");
import { isReducedMotion } from "../MotionPreference";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

export interface FancyTrove {
	Clean(this: FancyTrove): void;
	/** fade {delay, duration}, fall {delay, duration, distance}, smash {speed, rise}, clickpop {distance, rotation, duration} */
	PlayEffect(this: FancyTrove, effect: string, params?: string[], autoClean?: boolean): void;
}

interface RawConfig {
	Font?: Enum.Font;
	FontFace?: Font;
	CustomFont?: string;
	FontSize?: number;
	FontWeight?: Enum.FontWeight;
	TextColor?: Color3;
	TextAlign?: "Left" | "Right" | "Center";
	VerticalAlign?: "Top" | "Center" | "Bottom";
	ZIndex?: number;
	TextTransparency?: number;
	TextStrokeTransparency?: number;
	TextStrokeColor?: Color3;
	Scale?: boolean;
	TextSizeConstraint?: [number, number];
}

interface FancyTextModule {
	MakeText(this: void, container: GuiObject, text: string, config?: RawConfig): FancyTrove | undefined;
	FromLabel(this: void, label: TextLabel, config?: RawConfig, prefix?: string): FancyTrove | undefined;
}

let loaded: FancyTextModule | undefined;
let iconFolder: Folder | undefined;

function library(): FancyTextModule {
	if (loaded === undefined) {
		const root = ReplicatedStorage.WaitForChild("rbxts_include").WaitForChild("node_modules").WaitForChild("@rbxts").WaitForChild("fancytext") as ModuleScript;
		const config = require(root.WaitForChild("Config") as ModuleScript) as { IconsFolder?: Instance };
		iconFolder = new Instance("Folder");
		iconFolder.Name = "FancyTextIcons";
		config.IconsFolder = iconFolder;
		loaded = require(root) as FancyTextModule;
	}
	return loaded;
}

// <icon Name> clones a template from the icon folder; ours are built from the icon atlas on first use
function ensureIcon(kind: string): string | undefined {
	library();
	const name = kind.gsub("[^%w_]", "_")[0];
	if (iconFolder!.FindFirstChild(name) !== undefined) {
		return name;
	}
	const entry = IconManifest.Icons[kind] ?? IconManifest.Icons[(kind.match("^[^.]+")[0] as string | undefined) ?? kind];
	if (entry === undefined) {
		return undefined;
	}
	const sheet = IconManifest.Sheets[entry.b[0]] as string | undefined;
	const lightSheet = IconManifest.Sheets[entry.l[0]] as string | undefined;
	if (sheet === undefined || sheet === "") {
		return undefined;
	}
	const cell = IconManifest.Cell;
	const image = new Instance("ImageLabel");
	image.Name = name;
	image.BackgroundTransparency = 1;
	image.Image = sheet;
	image.ImageRectOffset = new Vector2(entry.b[1], entry.b[2]);
	image.ImageRectSize = new Vector2(cell, cell);
	if (lightSheet !== undefined && lightSheet !== "") {
		const light = new Instance("ImageLabel");
		light.Name = "Light";
		light.BackgroundTransparency = 1;
		light.Size = UDim2.fromScale(1, 1);
		light.Image = lightSheet;
		light.ImageRectOffset = new Vector2(entry.l[1], entry.l[2]);
		light.ImageRectSize = new Vector2(cell, cell);
		light.ImageTransparency = 0.12;
		light.Parent = image;
	}
	image.Parent = iconFolder;
	return name;
}

export type TitleTag = "wave" | "shake" | "jitter" | "flicker" | "floatwave" | "typewrite" | "rainbow" | "shadow" | "smash" | "fade" | "fall" | "clickpop";

export interface TitlePart {
	text?: string;
	/** an icon from the game's icon set, e.g. "Forge.27" */
	icon?: string;
	/** effects for this part only (on top of the title's own) */
	tags?: TitleTag[];
	color?: Color3;
}

export interface TitleState {
	rarity?: string;
	hover?: boolean;
	selected?: boolean;
	progress?: number;
	active?: boolean;
}

export interface TitleConfig {
	text: string;
	size: number;
	color: Color3;
	font?: Font;
	weight?: Enum.FontWeight;
	align?: "Left" | "Right" | "Center";
	verticalAlign?: "Top" | "Center" | "Bottom";
	zIndex?: number;
	/** a soft drop shadow; numbers are the pixel offset */
	shadow?: boolean | { x: number; y: number; color?: Color3 };
	wave?: boolean;
	shake?: boolean;
	/** characters per second */
	typewrite?: number;
	/** what the text belongs to; decides the colour sweep */
	state?: TitleState;
	/** a fixed two-colour sweep instead of the state's palette */
	gradient?: { color: Color3; amount?: number; moving?: boolean };
	parts?: TitlePart[];
	/** extra registered effect tags for the whole text, with optional params ("afx_fire 0.015") */
	effects?: string[];
	/** scale against 1920x1080 (FancyText's own scaling); off when the tree already scales */
	scale?: boolean;
	minSize?: number;
	maxSize?: number;
	/** 0 is solid */
	transparency?: number;
}

const rgb = (c: Color3) => `${math.floor(c.R * 255 + 0.5)} ${math.floor(c.G * 255 + 0.5)} ${math.floor(c.B * 255 + 0.5)}`;
// player text can't open a tag
const plain = (text: string) => text.gsub("[<>]", "")[0];

const MOVING: Record<string, boolean> = { wave: true, shake: true, jitter: true, flicker: true, floatwave: true, typewrite: true, rainbow: true };

function openTags(tags: string[]): string {
	return tags.map((tag) => `<${tag}>`).join("");
}
// FancyText toggles a tag each time it sees it, so closing is the bare name again
function closeTags(tags: string[]): string {
	return tags.map((tag) => `<${tag.split(" ")[0]}>`).join("");
}

/** Build the FancyText markup for a config (exported for tests and previews). */
export function markup(config: TitleConfig): string {
	const still = isReducedMotion();
	const rainbow = Rainbow.settings();
	const outer: string[] = [];
	if (config.shadow !== undefined && config.shadow !== false) {
		const s = config.shadow === true ? { x: 2, y: 2, color: undefined } : config.shadow;
		outer.push(`shadow ${s.x} ${s.y} ${rgb(s.color ?? new Color3(0, 0, 0))}`);
	}
	if (config.gradient !== undefined) {
		const amount = math.clamp(config.gradient.amount ?? 0.5, 0, 1);
		outer.push(`${config.gradient.moving === true && !still ? "gradientWave" : "gradient"} ${amount} ${rgb(config.gradient.color)}`);
	} else if (config.state !== undefined) {
		const look = Rainbow.lookFor(config.state);
		const strength = look.intensity * rainbow.intensity;
		if (strength >= 0.8 && look.moving && rainbow.motion && !still) {
			outer.push("rainbow");
		} else if (strength > 0.05) {
			const tint = Rainbow.color(look.palette, 0.15);
			const moves = look.moving && rainbow.motion && !still;
			outer.push(`${moves ? "gradientWave" : "gradient"} ${string.format("%.2f", strength)} ${rgb(tint)}`);
		}
	}
	if (config.wave === true && !still) {
		outer.push("wave");
	}
	if (config.shake === true && !still) {
		outer.push("shake");
	}
	if (config.typewrite !== undefined && !still) {
		outer.push(`typewrite ${config.typewrite}`);
	}
	for (const effect of config.effects ?? []) {
		outer.push(effect);
	}
	let body = plain(config.text);
	for (const part of config.parts ?? []) {
		const tags = (part.tags ?? []).filter((tag) => !(still && MOVING[tag]));
		let chunk = part.text !== undefined ? plain(part.text) : "";
		if (part.icon !== undefined) {
			const icon = ensureIcon(part.icon);
			if (icon !== undefined) {
				chunk = `<icon ${icon}>${chunk}`;
			}
		}
		body += tags.size() > 0 ? openTags(tags) + chunk + closeTags(tags) : chunk;
	}
	return openTags(outer) + body;
}

function rawConfig(config: TitleConfig): RawConfig {
	const raw: RawConfig = {
		FontSize: config.size,
		TextColor: config.color,
		TextAlign: config.align ?? "Left",
		VerticalAlign: config.verticalAlign ?? "Center",
		ZIndex: config.zIndex ?? 1,
		Scale: config.scale === true,
	};
	if (config.transparency !== undefined) {
		raw.TextTransparency = config.transparency;
	}
	if (config.font !== undefined) {
		raw.FontFace = config.font;
	}
	if (config.weight !== undefined) {
		raw.FontWeight = config.weight;
	}
	if (config.minSize !== undefined || config.maxSize !== undefined) {
		raw.TextSizeConstraint = [config.minSize ?? 1, config.maxSize ?? 100];
	}
	return raw;
}

export interface EffectModule {
	Init?: (this: void, char: TextLabel | ImageLabel, index: number, trove: never, params?: string[]) => unknown;
	Update?: (this: void, char: TextLabel | ImageLabel, index: number, dt: number, trove: never, data: unknown, params?: string[]) => void;
}

/** Add an effect FancyText can use as a tag (looked up before its Effects folder). */
export function registerEffect(name: string, effect: EffectModule) {
	library();
	const root = ReplicatedStorage.WaitForChild("rbxts_include").WaitForChild("node_modules").WaitForChild("@rbxts").WaitForChild("fancytext");
	const util = require(root.WaitForChild("Dependencies").WaitForChild("Util") as ModuleScript) as { module_cache: Record<string, EffectModule> };
	util.module_cache[name] = effect;
}

/** Render a title into `container`; Clean() the trove to remove it. Undefined if FancyText refused the config. */
export function make(container: GuiObject, config: TitleConfig): FancyTrove | undefined {
	const [ok, result] = pcall(() => library().MakeText(container, markup(config), rawConfig(config)));
	if (!ok) {
		warn(`[FancyTitle] ${tostring(result)}`);
		return undefined;
	}
	return result;
}

/** Upgrade a TextLabel in place (its font, size, colour and alignment carry over). */
export function fromLabel(label: TextLabel, config: Partial<TitleConfig> = {}): FancyTrove | undefined {
	const full: TitleConfig = { text: label.Text, size: label.TextSize, color: label.TextColor3, ...config };
	const tags = markup({ ...full, text: "" });
	const [ok, result] = pcall(() => library().FromLabel(label, config.size !== undefined ? { FontSize: config.size } : undefined, tags));
	if (!ok) {
		warn(`[FancyTitle] ${tostring(result)}`);
		return undefined;
	}
	return result;
}
