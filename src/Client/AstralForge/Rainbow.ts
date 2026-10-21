// Colour that flows, for UIGradients, without rebuilding a ColorSequence every frame.
//
// The colours are worked out in OKLCH, where equal steps look equal: a plain HSV wheel has a glaring
// yellow, a muddy blue and a hard magenta seam, and that is what makes a rainbow look cheap. Here
// lightness and chroma stay even all the way round and each stop is interpolated in OKLab, so the
// band between two keypoints never goes grey.
//
// Three ways to animate:
//   * Bound (preferred for anything new): Rainbow.bind(gradient, options) hands the UIGradient to one
//     shared clock. Each slot has its own phase, so neighbouring rims don't move in lockstep, and
//     only bindings whose state calls for colour (hover, selection, rarity, progress, an active mode)
//     move at all. Hidden or offscreen gradients are skipped, and the clock disconnects when nothing
//     is moving. See RainbowGradient (UiCore/rainbowFx.tsx) for the React side.
//   * Rotation: put a looping sequence (Rainbow.LOOP, or Rainbow.loop(name)) on a UIGradient under
//     a UIStroke and spin its Rotation with Rainbow.spin. The sequence ends where it starts, so the
//     colours chase round the rim with no seam. One number per frame.
//   * Phase: Rainbow.at(phase) hands back one of PHASES precomputed sequences shifted by `phase`, so
//     a fill can flow sideways. 360 phases is finer than a frame at any speed the game uses, so the
//     flow is continuous rather than stepping, and nothing is allocated per frame.

const STOPS = 16; // a ColorSequence takes at most 20 keypoints
const PHASES = 360;

// Lua's % is floored modulo; wrap keeps that behaviour for negative values
function wrap1(value: number): number {
	return ((value % 1) + 1) % 1;
}
function wrap360(value: number): number {
	return ((value % 360) + 360) % 360;
}

function toLinear(c: number): number {
	return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4);
}
function toGamma(c: number): number {
	c = math.clamp(c, 0, 1);
	return c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
}

// OKLab (Björn Ottosson) <-> sRGB
function oklabToColor(L: number, a: number, b: number): Color3 {
	const l_ = L + 0.3963377774 * a + 0.2158037573 * b;
	const m_ = L - 0.1055613458 * a - 0.0638541728 * b;
	const s_ = L - 0.0894841775 * a - 1.291485548 * b;
	const l = l_ * l_ * l_;
	const m = m_ * m_ * m_;
	const s = s_ * s_ * s_;
	const r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
	const g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
	const bl = -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s;
	return new Color3(toGamma(r), toGamma(g), toGamma(bl));
}
function colorToOklab(color: Color3): [number, number, number] {
	const r = toLinear(color.R);
	const g = toLinear(color.G);
	const b = toLinear(color.B);
	const l = math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3);
	const m = math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3);
	const s = math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3);
	return [
		0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
	];
}

function oklch(L: number, C: number, hueTurns: number): Color3 {
	const angle = hueTurns * math.pi * 2;
	return oklabToColor(L, C * math.cos(angle), C * math.sin(angle));
}

// a palette is a function from position round the loop (0..1) to a colour
type Palette = (share: number) => Color3;

// mix two colours in OKLab, so the midpoint keeps its colour instead of going grey
// (standalone function: `through` calls it while PALETTES is built at module load)
function mix(a: Color3, b: Color3, t: number): Color3 {
	const [L1, a1, b1] = colorToOklab(a);
	const [L2, a2, b2] = colorToOklab(b);
	return oklabToColor(L1 + (L2 - L1) * t, a1 + (a2 - a1) * t, b1 + (b2 - b1) * t);
}

function spectrum(L: number, C: number): Palette {
	return (share: number): Color3 => {
		// a gentle lift through the warm half keeps yellows from sinking to olive
		const lift = 0.035 * math.cos((share - 0.28) * math.pi * 2);
		return oklch(L + lift, C, share + 0.08);
	};
}

// a closed loop through hand-picked colours, interpolated in OKLab with a smooth ease between them
function through(colors: Color3[]): Palette {
	const count = colors.size();
	return (share: number): Color3 => {
		const position = wrap1(share) * count;
		const index = math.floor(position);
		let t = position - index;
		t = t * t * (3 - 2 * t);
		return mix(colors[index % count], colors[(index + 1) % count], t);
	};
}

const PALETTES: Record<string, Palette> = {
	// the full wheel at even brightness
	spectrum: spectrum(0.8, 0.13),
	// the full wheel, quieter, for big fills and text
	soft: spectrum(0.86, 0.08),
	// cool night sky: teal, blue, violet, rose
	aurora: through([
		Color3.fromRGB(94, 234, 212),
		Color3.fromRGB(96, 165, 250),
		Color3.fromRGB(167, 139, 250),
		Color3.fromRGB(244, 143, 177),
	]),
	// forge heat: deep red, orange, gold, white-hot
	ember: through([
		Color3.fromRGB(220, 72, 54),
		Color3.fromRGB(250, 140, 50),
		Color3.fromRGB(255, 205, 96),
		Color3.fromRGB(255, 240, 200),
	]),
	// cold metal: steel, ice, silver
	frost: through([
		Color3.fromRGB(148, 178, 214),
		Color3.fromRGB(196, 232, 255),
		Color3.fromRGB(232, 236, 246),
		Color3.fromRGB(170, 200, 236),
	]),
	// deep space: indigo, magenta, gold
	nebula: through([
		Color3.fromRGB(92, 84, 220),
		Color3.fromRGB(196, 92, 214),
		Color3.fromRGB(255, 176, 102),
		Color3.fromRGB(140, 110, 240),
	]),
};

const PALETTE_NAMES = table.freeze(
	(() => {
		const names: string[] = [];
		for (const [name] of pairs(PALETTES)) {
			names.push(name);
		}
		table.sort(names);
		return names;
	})(),
);

function build(palette: Palette, phase: number): ColorSequence {
	const keys = table.create<ColorSequenceKeypoint>(STOPS + 1);
	for (let index = 0; index <= STOPS; index++) {
		const share = index / STOPS;
		keys[index] = new ColorSequenceKeypoint(share, palette(wrap1(share + phase)));
	}
	return new ColorSequence(keys);
}

// the old (saturation, value) arguments pick a strength of the full spectrum
function paletteFor(saturation?: number, value?: number): [string, Palette] {
	const s = saturation ?? 0.62;
	const v = value ?? 1;
	const key = string.format("spectrum:%.2f:%.2f", s, v);
	let found = PALETTES[key];
	if (found === undefined) {
		// HSV saturation 0.62 ~ the default spectrum; lower is calmer, lower value is darker
		found = spectrum(0.58 + 0.28 * v - 0.08 * s, 0.21 * s);
		PALETTES[key] = found;
	}
	return [key, found];
}

const cache: Record<string, ColorSequence[]> = {};
const loops: Record<string, ColorSequence> = {};
// phases are built the first time they're shown, so nothing hitches when a bar first appears
function phaseOf(key: string, palette: Palette, phase: number): ColorSequence {
	let list = cache[key];
	if (list === undefined) {
		list = table.create<ColorSequence>(PHASES);
		cache[key] = list;
	}
	const index = math.clamp(math.floor(wrap1(phase) * PHASES), 0, PHASES - 1);
	let found = list[index];
	if (found === undefined) {
		found = build(palette, index / PHASES);
		list[index] = found;
	}
	return found;
}

// the whole loop once, ending where it starts (for spinning rims)
function loop(name?: string): ColorSequence {
	const key = name ?? "spectrum";
	let found = loops[key];
	if (found === undefined) {
		found = build(PALETTES[key] ?? PALETTES.spectrum, 0);
		loops[key] = found;
	}
	return found;
}

const LOOP = loop("spectrum");
const SOFT = loop("soft");

// a palette shifted by `phase` (any number; wraps every 1)
function flow(name: string, phase: number): ColorSequence {
	return phaseOf(name, PALETTES[name] ?? PALETTES.spectrum, phase);
}

// the full spectrum shifted by `phase`; saturation/value soften or darken it
function at(phase: number, saturation?: number, value?: number): ColorSequence {
	const [key, palette] = paletteFor(saturation, value);
	return phaseOf(key, palette, phase);
}

// a loop built from one colour: a pale crest, the colour, a deeper trough, back to the colour. Fills
// and buttons use it to flow in their own colour instead of a rainbow. Phases are cached per colour.
const WHITE = new Color3(1, 1, 1);
const BLACK = new Color3(0, 0, 0);
function family(color: Color3, phase: number, depth?: number): ColorSequence {
	const d = depth ?? 1;
	const key = string.format(
		"family:%02x%02x%02x:%.2f",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255),
		d,
	);
	let palette = PALETTES[key];
	if (palette === undefined) {
		palette = through([mix(color, WHITE, 0.3 * d), color, mix(color, BLACK, 0.22 * d), color]);
		PALETTES[key] = palette;
	}
	return phaseOf(key, palette, phase);
}

// one colour from a palette (for a tint that drifts: text, a dot, a light)
function color(name: string, phase: number): Color3 {
	return (PALETTES[name] ?? PALETTES.spectrum)(wrap1(phase));
}

// degrees for a rim that turns once every `period` seconds
function spin(seconds: number, period?: number): number {
	return wrap360((seconds / (period ?? 3)) * 360);
}

// 0..1 that eases in and out once per `period`: for glints and sweeps that shouldn't move at a
// constant robotic speed
function sweep(seconds: number, period?: number): number {
	const t = wrap1(seconds / (period ?? 3));
	return t * t * t * (t * (t * 6 - 15) + 10);
}

// ---------------------------------------------------------------------------------------------------
// State-driven, layered gradients on one shared clock

const RunService = game.GetService("RunService");
const Workspace = game.GetService("Workspace");

/** What a piece of UI is doing right now; the colour follows from it. */
interface RainbowState {
	/** item rarity id; the ascended tiers get their own palettes, Legendary runs hot */
	rarity?: string;
	hover?: boolean;
	selected?: boolean;
	/** 0..1 fill; colour builds with it and a full bar flows the whole spectrum */
	progress?: number;
	/** a mode that is switched on (auto-forge, an event, a boost) */
	active?: boolean;
}

interface RainbowLook {
	palette: string;
	/** 0 = the base colour alone, 1 = the full palette */
	intensity: number;
	/** seconds per loop */
	period: number;
	/** whether the colour moves; a still look keeps its gradient but costs nothing per frame */
	moving: boolean;
}

const RARITY_PALETTE: Record<string, string | undefined> = {
	Astral: "nebula",
	Celestial: "aurora",
	Mythic: "spectrum",
	Legendary: "ember",
	Epic: "nebula",
};

/** Maps UI state to a look. Plain items stay plain; colour is earned by state, not sprayed on. */
function lookFor(state: RainbowState): RainbowLook {
	const rarityPalette = state.rarity !== undefined ? RARITY_PALETTE[state.rarity] : undefined;
	const ascended = state.rarity === "Astral" || state.rarity === "Celestial" || state.rarity === "Mythic";
	let intensity = 0;
	let period = 6;
	if (rarityPalette !== undefined) {
		intensity = ascended ? 0.85 : 0.45;
		period = ascended ? 5 : 8;
	}
	if (state.progress !== undefined) {
		const p = math.clamp(state.progress, 0, 1);
		intensity = math.max(intensity, p >= 1 ? 1 : p * 0.6);
		period = p >= 1 ? 3 : period;
	}
	if (state.active === true) {
		intensity = math.max(intensity, 0.7);
		period = math.min(period, 4);
	}
	if (state.selected === true) {
		intensity = math.max(intensity, 0.6);
	}
	if (state.hover === true) {
		intensity = math.min(1, math.max(intensity, 0.35) + 0.15);
		period = math.min(period, 3.5);
	}
	const moving = intensity > 0.05 && (state.hover === true || state.selected === true || state.active === true || ascended || (state.progress ?? 0) >= 1);
	return { palette: rarityPalette ?? (state.progress !== undefined && (state.progress ?? 0) >= 1 ? "spectrum" : "soft"), intensity, period, moving };
}

// the player's Rainbow slider (Settings > Graphics) and reduced motion
let globalIntensity = 0.7;
let motionAllowed = true;

// a palette blended toward a base colour, so low intensity is a tinted sheen rather than a weak
// rainbow. Steps of 0.1 keep the cache small; phases are cached per blend like every other loop.
function blendKey(name: string, base: Color3, k: number): string {
	return string.format("blend:%s:%02x%02x%02x:%d", name, math.floor(base.R * 255), math.floor(base.G * 255), math.floor(base.B * 255), k);
}
function blended(name: string, base: Color3, intensity: number, phase: number): ColorSequence {
	const k = math.clamp(math.floor(intensity * 10 + 0.5), 0, 10);
	const key = blendKey(name, base, k);
	let palette = PALETTES[key];
	if (palette === undefined) {
		const source = PALETTES[name] ?? PALETTES.spectrum;
		const t = k / 10;
		palette = (share: number) => mix(base, source(share), t);
		PALETTES[key] = palette;
	}
	return phaseOf(key, palette, phase);
}

interface RainbowOptions {
	/** colour the gradient settles to when the state asks for none */
	base: Color3;
	state?: RainbowState;
	/** 0..1 offset round the loop; defaults to a spread based on the slot order */
	phase?: number;
	/** flow sideways (fills, text) or spin round (rims under a UIStroke) */
	style?: "flow" | "spin";
	/** checked for visibility; defaults to the gradient's parent */
	host?: GuiObject;
}

interface Slot {
	gradient: UIGradient;
	host?: GuiObject;
	base: Color3;
	phase: number;
	style: "flow" | "spin";
	look: RainbowLook;
	shown: boolean;
	alive: boolean;
}

interface RainbowHandle {
	setState(this: void, state: RainbowState): void;
	setBase(this: void, base: Color3): void;
	destroy(this: void): void;
}

const bindings = new Set<Slot>();
const moving = new Set<Slot>();
let driver: RBXScriptConnection | undefined;
let visibilityAt = 0;
let bindCount = 0;
const GOLDEN = 0.618034;

function onScreen(item: GuiObject): boolean {
	if (!item.Visible) {
		return false;
	}
	const gui = item.FindFirstAncestorWhichIsA("LayerCollector");
	if (gui === undefined || !gui.Enabled) {
		return false;
	}
	const camera = Workspace.CurrentCamera;
	const view = camera !== undefined ? camera.ViewportSize : new Vector2(1920, 1080);
	const at = item.AbsolutePosition;
	const size = item.AbsoluteSize;
	return size.X > 0 && size.Y > 0 && at.X < view.X && at.Y < view.Y && at.X + size.X > 0 && at.Y + size.Y > 0;
}

function paint(slot: Slot, now: number) {
	const look = slot.look;
	const strength = look.intensity * globalIntensity;
	if (strength <= 0.05) {
		slot.gradient.Color = new ColorSequence(slot.base);
		slot.gradient.Rotation = 0;
		return;
	}
	if (slot.style === "spin") {
		slot.gradient.Color = blended(look.palette, slot.base, strength, slot.phase);
		slot.gradient.Rotation = look.moving && motionAllowed ? spin(now + slot.phase * look.period, look.period) : slot.phase * 360;
	} else {
		const drift = look.moving && motionAllowed ? now / look.period : 0;
		slot.gradient.Color = blended(look.palette, slot.base, strength, slot.phase + drift);
	}
}

function step() {
	const now = os.clock();
	if (now >= visibilityAt) {
		// visibility is a layout question; four checks a second is plenty
		visibilityAt = now + 0.25;
		for (const slot of moving) {
			slot.shown = slot.host === undefined || onScreen(slot.host);
		}
	}
	for (const slot of moving) {
		if (slot.shown) {
			paint(slot, now);
		}
	}
}

function refreshDriver() {
	const wanted = motionAllowed && globalIntensity > 0.05 && moving.size() > 0;
	if (wanted && driver === undefined) {
		visibilityAt = 0;
		driver = RunService.RenderStepped.Connect(step);
	} else if (!wanted && driver !== undefined) {
		driver.Disconnect();
		driver = undefined;
	}
}

function settle(slot: Slot) {
	if (!slot.alive) {
		return;
	}
	if (slot.look.moving && slot.look.intensity * globalIntensity > 0.05) {
		moving.add(slot);
	} else {
		moving.delete(slot);
	}
	paint(slot, os.clock());
	refreshDriver();
}

/** Hand a UIGradient to the shared clock. Call destroy() on unmount (it also cleans up if the gradient is destroyed). */
function bind(gradient: UIGradient, options: RainbowOptions): RainbowHandle {
	bindCount += 1;
	const parent = gradient.Parent;
	const host = options.host ?? (parent !== undefined && parent.IsA("GuiObject") ? parent : undefined);
	const slot: Slot = {
		gradient,
		host,
		base: options.base,
		phase: options.phase ?? wrap1(bindCount * GOLDEN),
		style: options.style ?? "flow",
		look: lookFor(options.state ?? {}),
		shown: true,
		alive: true,
	};
	bindings.add(slot);
	const destroy = () => {
		if (!slot.alive) {
			return;
		}
		slot.alive = false;
		bindings.delete(slot);
		moving.delete(slot);
		refreshDriver();
	};
	const gone = gradient.Destroying.Connect(destroy);
	settle(slot);
	return {
		setState: (state) => {
			slot.look = lookFor(state);
			settle(slot);
		},
		setBase: (base) => {
			slot.base = base;
			settle(slot);
		},
		destroy: () => {
			gone.Disconnect();
			destroy();
		},
	};
}

/** Settings > Graphics > Rainbow (0..1) and reduced motion; still bindings keep their colour. */
function configure(intensity: number, reducedMotion: boolean) {
	const wanted = math.clamp(intensity === intensity ? intensity : 0.7, 0, 1);
	if (wanted === globalIntensity && motionAllowed === !reducedMotion) {
		return;
	}
	globalIntensity = wanted;
	motionAllowed = !reducedMotion;
	for (const slot of bindings) {
		settle(slot);
	}
	refreshDriver();
}

/** how many gradients are moving right now (for the perf overlay and tests) */
function activeCount(): number {
	return driver === undefined ? 0 : moving.size();
}

export = table.freeze({ mix, PALETTES: PALETTE_NAMES, loop, LOOP, SOFT, flow, at, family, color, spin, sweep, lookFor, bind, configure, activeCount });
