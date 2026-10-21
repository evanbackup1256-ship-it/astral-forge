// Colour that flows, for UIGradients, without rebuilding a ColorSequence every frame.
//
// The colours are worked out in OKLCH, where equal steps look equal: a plain HSV wheel has a glaring
// yellow, a muddy blue and a hard magenta seam, and that is what makes a rainbow look cheap. Here
// lightness and chroma stay even all the way round and each stop is interpolated in OKLab, so the
// band between two keypoints never goes grey.
//
// Two ways to animate:
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

// The "spectrum" is no longer the whole wheel: it is a warm metal sheen that swings between gold and
// copper and lifts toward cream at the crest. Everything that asked for a rainbow (rims, island
// moments, flowing fills) now reads as polished brass catching light, in the forge's one accent.
function spectrum(L: number, C: number): Palette {
	return (share: number): Color3 => {
		const wave = math.cos(share * math.pi * 2);
		return oklch(L + 0.04 * wave, C * (0.55 - 0.2 * wave), 0.2 - 0.04 * wave);
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
		Color3.fromRGB(116, 108, 196),
		Color3.fromRGB(150, 126, 206),
		Color3.fromRGB(214, 184, 146),
		Color3.fromRGB(132, 116, 200),
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
		palette = through([mix(color, WHITE, 0.16 * d), color, mix(color, BLACK, 0.12 * d), color]);
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

export = table.freeze({ mix, PALETTES: PALETTE_NAMES, loop, LOOP, SOFT, flow, at, family, color, spin, sweep });
