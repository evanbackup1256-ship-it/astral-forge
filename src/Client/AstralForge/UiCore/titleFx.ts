// Title looks for FancyText: every equipped-title look (fire, aurora, starforge ...) as one FancyText
// effect per look, so a title is plain FancyText markup ("<afx_fire>Title") with the same layered
// motion, stroke, gradients, shadow, sparks and cipher flicker the looks were authored with.
//
// A look is written once as a tag stack (see ReactHosts/HyperTextHost buildKindMarkup); this module
// reads that stack and builds per-character layers from it. Numbers are taken as written, nothing is
// scaled down. Moving characters are driven from one RenderStepped connection that exists only while
// a moving title is on screen, so idle titles cost nothing.
import * as FancyText from "./fancyText";

const RunService = game.GetService("RunService");
const TweenService = game.GetService("TweenService");

const SPARK_IMAGE = "rbxassetid://115010102642915";
const CIPHER = "0123456789ABCDEF#%&*+/?@";

type Attrs = Record<string, string>;
interface Layer {
	tag: string;
	value: string;
	attrs: Attrs;
}

// ---------------------------------------------------------------------------------------------
// parsing the authored stack

/** `<a=1 k=v><b=true>` (the opening run of a look) to a list of layers */
export function parseStack(prefix: string): Layer[] {
	const layers: Layer[] = [];
	for (const [inner] of string.gmatch(prefix, "<([^>]+)>")) {
		const tokens: string[] = [];
		for (const [token] of string.gmatch(inner as string, "%S+")) {
			tokens.push(token as string);
		}
		if (tokens.size() === 0) {
			continue;
		}
		const [tag, value] = string.match(tokens[0], "^([%w%-]+)=?(.*)$") as LuaTuple<[string?, string?]>;
		if (tag === undefined) {
			continue;
		}
		const attrs: Attrs = {};
		for (let i = 1; i < tokens.size(); i++) {
			const [k, v] = string.match(tokens[i], "^([%w]+)=(.*)$") as LuaTuple<[string?, string?]>;
			if (k !== undefined && v !== undefined) {
				attrs[k] = v;
			}
		}
		layers.push({ tag, value: value ?? "", attrs });
	}
	return layers;
}

const num = (value: string | undefined, fallback: number) => (value !== undefined ? tonumber(value) ?? fallback : fallback);
const bool = (value: string | undefined, fallback: boolean) => (value === undefined ? fallback : value === "true");
function range(value: string | undefined, a: number, b: number): [number, number] {
	if (value === undefined) {
		return [a, b];
	}
	const [x, y] = string.match(value, "^([^,]+),?(.*)$") as LuaTuple<[string?, string?]>;
	const lo = tonumber(x) ?? a;
	return [lo, tonumber(y) ?? lo];
}
const pick = (r: [number, number]) => r[0] + math.random() * (r[1] - r[0]);
function color(value: string | undefined, fallback: Color3): Color3 {
	if (value === undefined) {
		return fallback;
	}
	const [r, g, b] = string.match(value, "^(%d+),(%d+),(%d+)$") as LuaTuple<[string?, string?, string?]>;
	return r !== undefined ? Color3.fromRGB(tonumber(r)!, tonumber(g)!, tonumber(b)!) : fallback;
}
function colors(value: string | undefined): Color3[] {
	const list: Color3[] = [];
	if (value !== undefined) {
		for (const [entry] of string.gmatch(value, "[^;]+")) {
			list.push(color(entry as string, Color3.fromRGB(255, 255, 255)));
		}
	}
	return list.size() > 0 ? list : [Color3.fromRGB(255, 255, 255)];
}

// ---------------------------------------------------------------------------------------------
// a compiled look

interface GradientSpec {
	colors: Color3[];
	individual: boolean;
	speed: number;
	spacing: number;
	rotation: number;
}
interface Look {
	italic: boolean;
	color?: Color3;
	shadow?: { color: Color3; x: number; y: number; trans: number };
	stroke?: { color: Color3; thickness: number; trans: number };
	strokeGradient?: GradientSpec;
	gradient?: GradientSpec;
	rainbow?: { freq: number; offset: number };
	pulseTrans?: { from: number; to: number; dur: number };
	anim?: { kind: string; freq: number; amp: number; offset: number; rot: number; dir: string; exp: number; startScale: number };
	shake?: { maxOffset: number; maxRot: number; freq: number };
	decode?: { dur: number; freq: number };
	sparks?: {
		color: Color3;
		rate: number;
		chance: number;
		lifetime: [number, number];
		startSize: [number, number];
		endSize: [number, number];
		velX: [number, number];
		velY: [number, number];
		accelX: [number, number];
		accelY: [number, number];
		rotVel: [number, number];
		startPosX: [number, number];
		startPosY: [number, number];
	};
	moving: boolean;
}

function gradientSpec(attrs: Attrs): GradientSpec {
	const speed = num(attrs.moveSpeed, 0);
	return {
		colors: colors(attrs.colors),
		individual: bool(attrs.individual, false),
		speed: attrs.moveDir === "left" ? -speed : speed,
		spacing: num(attrs.spacing, 0.1),
		rotation: num(attrs.rot, 0),
	};
}

const ANIM_DEFAULTS: Record<string, [number, number, number, number]> = {
	// freq, amp, offset, rot (rot=true)
	wiggle: [0.75, 0.3, 0.12, 14],
	orbit: [1.1, 0.22, 0.14, 14],
	pendulum: [1.25, 0.2, 0.15, 14],
	spiral: [1.35, 0.22, 0.16, 14],
	pulsewave: [1.6, 0.26, 0.14, 14],
	slide: [1, 0, 0.75, 55],
	bounce: [1, 0, 0.75, 0],
	grow: [1, 0, 0, 0],
};

export function compile(layers: Layer[]): Look {
	const look: Look = { italic: false, moving: false };
	for (const { tag, value, attrs } of layers) {
		if (tag === "italic") {
			look.italic = value === "true";
		} else if (tag === "color") {
			look.color = color(value, Color3.fromRGB(255, 255, 255));
		} else if (tag === "shadow") {
			const [x, y] = range(attrs.offset, 0.05, 0.18);
			look.shadow = { color: color(attrs.color, new Color3(0, 0, 0)), x, y, trans: num(attrs.trans, 0) };
		} else if (tag === "stroke") {
			look.stroke = { color: color(attrs.color, new Color3(0, 0, 0)), thickness: num(attrs.thickness, 0.04), trans: num(attrs.trans, 0) };
		} else if (tag === "strokeGradient") {
			look.strokeGradient = gradientSpec(attrs);
		} else if (tag === "gradient") {
			look.gradient = gradientSpec(attrs);
		} else if (tag === "rainbow") {
			look.rainbow = { freq: num(attrs.freq, 0.5), offset: num(attrs.offset, 0.12) };
		} else if (tag === "trans") {
			look.pulseTrans = { to: num(value, 0), from: num(attrs.tweenFrom, num(value, 0)), dur: num(attrs.tweenDur, 1) };
		} else if (tag === "anim") {
			const d = ANIM_DEFAULTS[value] ?? [1, 0.2, 0.14, 14];
			const rotRaw = attrs.rot;
			const rot = rotRaw === undefined ? d[3] : rotRaw === "true" ? d[3] : rotRaw === "false" ? 0 : num(rotRaw, d[3]);
			look.anim = {
				kind: value,
				freq: num(attrs.freq, d[0]),
				amp: num(attrs.amp, d[1]),
				offset: num(attrs.offset, d[2]),
				rot,
				dir: attrs.dir ?? "down",
				exp: num(attrs.exp, 1),
				startScale: num(attrs.startScale, 0.86),
			};
		} else if (tag === "shake") {
			look.shake = { maxOffset: num(attrs.maxOffset, 0.03), maxRot: num(attrs.maxRot, 2), freq: num(attrs.freq, 16) };
		} else if (tag === "decode") {
			look.decode = { dur: num(attrs.dur, 0.16), freq: num(attrs.freq, 14) };
		} else if (tag === "shiny") {
			look.sparks = {
				color: color(attrs.color, Color3.fromRGB(255, 255, 255)),
				rate: num(attrs.rate, 4),
				chance: num(attrs.chance, 25),
				lifetime: range(attrs.lifetime, 1, 3),
				startSize: range(attrs.startSize, 0.75, 1),
				endSize: range(attrs.endSize, 0.3, 0.5),
				velX: range(attrs.velX, -0.25, 0.25),
				velY: range(attrs.velY, -1.25, -1),
				accelX: range(attrs.accelX, -0.2, 0.2),
				accelY: range(attrs.accelY, 1.75, 2),
				rotVel: range(attrs.rotVel, -70, 70),
				startPosX: range(attrs.startPosX, -0.5, 0.5),
				startPosY: range(attrs.startPosY, -0.5, 0.5),
			};
		}
	}
	look.moving =
		look.anim !== undefined ||
		look.shake !== undefined ||
		look.decode !== undefined ||
		look.sparks !== undefined ||
		look.rainbow !== undefined ||
		look.pulseTrans !== undefined ||
		(look.gradient !== undefined && look.gradient.speed !== 0) ||
		(look.strokeGradient !== undefined && look.strokeGradient.speed !== 0);
	return look;
}

// ---------------------------------------------------------------------------------------------
// gradients: a cyclic palette sampled at a moving phase (keeps the authored colours, wraps cleanly)

function sample(list: Color3[], t: number): Color3 {
	const n = list.size();
	if (n === 1) {
		return list[0];
	}
	const x = (t % 1) * n;
	const i = math.floor(x);
	return list[i % n].Lerp(list[(i + 1) % n], x - i);
}
function sequence(list: Color3[], start: number, width: number): ColorSequence {
	if (list.size() === 1) {
		return new ColorSequence(list[0]);
	}
	const steps = math.clamp(list.size() * 2, 3, 12);
	const keys: ColorSequenceKeypoint[] = [];
	for (let i = 0; i <= steps; i++) {
		keys.push(new ColorSequenceKeypoint(i / steps, sample(list, start + (i / steps) * width)));
	}
	return new ColorSequence(keys);
}

// ---------------------------------------------------------------------------------------------
// live characters

interface Spark {
	image: ImageLabel;
	vel: Vector2;
	accel: Vector2;
	rotVel: number;
}
interface Live {
	char: TextLabel;
	look: Look;
	index: number;
	base: UDim2;
	size: number;
	scale: UIScale;
	shadow?: TextLabel;
	gradient?: UIGradient;
	strokeGradient?: UIGradient;
	span: [number, number];
	text: string;
	lastShake: number;
	shakePos: Vector2;
	shakeRot: number;
	lastDecode: number;
	lastSpark: number;
	sparks: Spark[];
	visibleCheck: number;
	onScreen: boolean;
}

const live = new Set<Live>();
let driver: RBXScriptConnection | undefined;

function onScreen(item: Live, now: number): boolean {
	if (now - item.visibleCheck < 0.25) {
		return item.onScreen;
	}
	item.visibleCheck = now;
	let node: Instance | undefined = item.char;
	let shown = true;
	for (let depth = 0; depth < 14 && node !== undefined; depth++) {
		if (node.IsA("GuiObject") && !node.Visible) {
			shown = false;
			break;
		}
		if (node.IsA("LayerCollector")) {
			shown = node.Enabled;
			break;
		}
		node = node.Parent;
	}
	item.onScreen = shown && item.char.Parent !== undefined;
	return item.onScreen;
}

function step(dt: number) {
	const now = os.clock();
	for (const item of live) {
		if (onScreen(item, now)) {
			pcall(update, item, now, dt);
		}
	}
}

function track(item: Live) {
	live.add(item);
	if (driver === undefined) {
		driver = RunService.RenderStepped.Connect(step);
	}
}
function untrack(item: Live) {
	live.delete(item);
	for (const spark of item.sparks) {
		spark.image.Destroy();
	}
	item.sparks.clear();
	if (live.size() === 0 && driver !== undefined) {
		driver.Disconnect();
		driver = undefined;
	}
}

function update(item: Live, now: number, dt: number) {
	const { look, char, index } = item;
	const h = item.size;
	let dx = 0;
	let dy = 0;
	let rot = 0;
	let scale = 1;
	const anim = look.anim;
	if (anim !== undefined) {
		const tau = math.pi * 2;
		if (anim.kind === "wiggle") {
			const x = now * anim.freq * tau - tau * anim.offset * index;
			dy = (math.sin(x) + 0.2 * math.sin(x * 2 + 0.6)) * anim.amp * h;
			dx = math.cos(x) * anim.amp * h * 0.16;
			scale = 1 + math.sin(x) * 0.055;
			if (anim.rot !== 0) {
				const slope = math.cos(x) * tau * anim.offset * anim.amp * h;
				rot = math.deg(math.atan2(slope, math.max(1, h * 0.6)));
			}
		} else if (anim.kind === "orbit") {
			const p = now * anim.freq * tau - index * anim.offset * tau;
			dx = math.cos(p) * anim.amp * h * 0.55;
			dy = math.sin(p * 2) * anim.amp * h * 0.75;
			scale = 1 + math.sin(p) * 0.065;
			if (anim.rot !== 0) {
				rot = math.cos(p) * 7.5;
			}
		} else if (anim.kind === "pendulum") {
			const swing = math.sin(now * anim.freq * tau - index * anim.offset * tau);
			dx = swing * anim.amp * h * 0.45;
			dy = (1 - math.cos(swing * 0.85)) * anim.amp * h * 1.1;
			rot = swing * anim.rot;
			scale = 1 + (1 - math.abs(swing)) * 0.05;
		} else if (anim.kind === "spiral") {
			const p = now * anim.freq * tau - index * anim.offset * tau;
			const env = 0.55 + 0.45 * math.sin(p * 0.5);
			dx = math.cos(p) * anim.amp * h * env * 0.55;
			dy = math.sin(p) * anim.amp * h * env * 0.75;
			rot = math.sin(p) * anim.rot * env;
			scale = 1 + math.cos(p) * 0.075 * env;
		} else if (anim.kind === "pulsewave") {
			const phase = (now * anim.freq - index * anim.offset) % 1;
			const crest = math.exp(-(((phase - 0.25) / 0.16) ** 2));
			dy = -crest * anim.amp * h;
			rot = math.sin((phase - 0.25) * tau) * crest * anim.rot;
			scale = 1 + crest * 0.16;
		} else if (anim.kind === "slide") {
			const sign = anim.dir === "up" ? 1 : -1;
			const phase = (now / 0.5) * tau - index * 0.42;
			const wave = math.sin(phase);
			dx = h * anim.offset * 0.45 * math.cos(phase) * 0.55;
			dy = sign * h * anim.offset * wave * 0.65;
			rot = sign * anim.rot * math.sin(phase) * 0.55;
			scale = 1 + (1 - (wave * 0.5 + 0.5)) * 0.06;
		} else if (anim.kind === "bounce") {
			const sign = anim.dir === "down" ? -1 : 1;
			const cycle = (now / 0.5 - index * 0.11) % 1;
			const arc = math.abs(math.sin(cycle * math.pi)) ** (1 / math.clamp(math.max(0.5, anim.exp), 0.7, 2.4));
			dy = -math.abs(sign * h * anim.offset) * arc * 0.75;
			rot = math.sin(cycle * tau) * 2.2;
			scale = 1 + (arc - 0.35) * 0.09;
		} else if (anim.kind === "grow") {
			const phase = (now / 0.5) * tau - index * 0.36;
			const wave = math.sin(phase) * 0.5 + 0.5;
			const shaped = wave ** math.clamp(anim.exp * 0.65, 0.6, 2.2);
			const minS = math.clamp(anim.startScale, 0.78, 0.96);
			scale = minS + (1.08 - minS) * shaped;
			dy = -(scale - 1) * 0.45 * h;
			rot = math.cos(phase) * 1.8;
		}
	}
	const shake = look.shake;
	if (shake !== undefined) {
		if (now - item.lastShake >= 1 / math.max(1, shake.freq)) {
			item.lastShake = now;
			const seed = index * 1.73;
			const t = now * math.max(4, shake.freq * 0.85) + seed;
			const nx = math.noise(t, seed, 0.37) * 1.45 + math.sin(t * 2.3) * 0.35;
			const ny = math.noise(seed, t, 0.91) * 1.45 + math.cos(t * 2.9) * 0.35;
			const nr = math.noise(t * 0.9, 0.53, seed) * 1.5;
			const off = shake.maxOffset * h;
			item.shakePos = new Vector2(math.clamp(nx, -1, 1) * off, math.clamp(ny, -1, 1) * off);
			item.shakeRot = math.clamp(nr, -1, 1) * shake.maxRot;
		}
		dx += item.shakePos.X;
		dy += item.shakePos.Y;
		rot += item.shakeRot;
	}
	const pos = item.base.add(UDim2.fromOffset(dx, dy));
	char.Position = pos;
	char.Rotation = rot;
	item.scale.Scale = scale;
	if (item.shadow !== undefined) {
		const s = look.shadow!;
		item.shadow.Position = pos.add(UDim2.fromOffset(s.x * h, s.y * h));
		item.shadow.Rotation = rot;
		item.shadow.Visible = char.Visible;
		const shadowScale = item.shadow.FindFirstChildOfClass("UIScale");
		if (shadowScale !== undefined) {
			shadowScale.Scale = scale;
		}
	}
	const decode = look.decode;
	if (decode !== undefined) {
		const dur = math.max(0.08, decode.dur);
		const period = math.max(1.35, dur * 7.5);
		const phase = (now - index * 0.085) % period;
		if (phase < dur) {
			if (now - item.lastDecode >= 1 / math.max(1, decode.freq)) {
				item.lastDecode = now;
				const at = ((math.floor(now * decode.freq) + index * 7) % CIPHER.size()) + 1;
				char.Text = string.sub(CIPHER, at, at);
			}
		} else if (char.Text !== item.text) {
			char.Text = item.text;
		}
	}
	if (look.rainbow !== undefined) {
		char.TextColor3 = Color3.fromHSV((now * look.rainbow.freq - index * look.rainbow.offset) % 1, 0.62, 1);
	}
	if (look.pulseTrans !== undefined) {
		const p = look.pulseTrans;
		const k = (math.sin((now / math.max(0.05, p.dur)) * math.pi) + 1) / 2;
		char.TextTransparency = p.to + (p.from - p.to) * k;
	}
	paintGradient(item.gradient, look.gradient, item, now);
	paintGradient(item.strokeGradient, look.strokeGradient, item, now);
	const sparks = look.sparks;
	if (sparks !== undefined) {
		for (const spark of item.sparks) {
			spark.image.Position = spark.image.Position.add(UDim2.fromScale(spark.vel.X * dt, spark.vel.Y * dt));
			spark.vel = spark.vel.add(spark.accel.mul(dt));
			spark.image.Rotation += spark.rotVel * dt;
		}
		if (now - item.lastSpark >= 1 / sparks.rate) {
			item.lastSpark = now;
			if (math.random() * 100 <= sparks.chance) {
				emit(item, sparks);
			}
		}
	}
}

function paintGradient(gradient: UIGradient | undefined, spec: GradientSpec | undefined, item: Live, now: number) {
	if (gradient === undefined || spec === undefined || spec.speed === 0) {
		return;
	}
	const phase = now * spec.speed;
	if (spec.individual) {
		gradient.Color = sequence(spec.colors, phase - item.index * spec.spacing, 1);
	} else {
		gradient.Color = sequence(spec.colors, phase + item.span[0], item.span[1]);
	}
}

function emit(item: Live, sparks: NonNullable<Look["sparks"]>) {
	const image = new Instance("ImageLabel");
	image.Name = "Spark";
	image.BackgroundTransparency = 1;
	image.AnchorPoint = new Vector2(0.5, 0.5);
	image.Image = SPARK_IMAGE;
	image.ImageColor3 = sparks.color;
	image.SizeConstraint = Enum.SizeConstraint.RelativeYY;
	image.ZIndex = item.char.ZIndex + 1;
	image.Position = UDim2.fromScale(0.5 + pick(sparks.startPosX), 0.5 + pick(sparks.startPosY));
	image.Rotation = math.random(-360, 360);
	const start = pick(sparks.startSize);
	image.Size = UDim2.fromScale(start, start);
	image.Parent = item.char;
	const spark: Spark = {
		image,
		vel: new Vector2(pick(sparks.velX), pick(sparks.velY)),
		accel: new Vector2(pick(sparks.accelX), pick(sparks.accelY)),
		rotVel: pick(sparks.rotVel),
	};
	item.sparks.push(spark);
	const finish = pick(sparks.endSize);
	const tween = TweenService.Create(image, new TweenInfo(pick(sparks.lifetime), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size: UDim2.fromScale(finish, finish),
		ImageTransparency: 1,
	});
	tween.Completed.Once(() => {
		const at = item.sparks.indexOf(spark);
		if (at >= 0) {
			item.sparks.unorderedRemove(at);
		}
		image.Destroy();
	});
	tween.Play();
}

interface TroveLike {
	Add<T>(this: TroveLike, item: T): T;
}

function build(look: Look, char: TextLabel | ImageLabel, index: number, trove: TroveLike, params: string[] | undefined, still: boolean) {
	if (!char.IsA("TextLabel")) {
		return undefined;
	}
	const size = char.TextSize;
	if (look.italic) {
		const face = char.FontFace;
		char.FontFace = new Font(face.Family, face.Weight, Enum.FontStyle.Italic);
	}
	if (look.color !== undefined) {
		char.TextColor3 = look.color;
	}
	let shadow: TextLabel | undefined;
	if (look.shadow !== undefined) {
		const s = look.shadow;
		shadow = trove.Add(char.Clone());
		shadow.Name = `${char.Name}_Shadow`;
		shadow.TextColor3 = s.color;
		shadow.TextTransparency = s.trans;
		shadow.ZIndex = char.ZIndex;
		char.ZIndex += 1;
		shadow.Position = char.Position.add(UDim2.fromOffset(s.x * size, s.y * size));
		new Instance("UIScale").Parent = shadow;
		const made = shadow;
		trove.Add(task.defer(() => (made.Parent = char.Parent)));
	}
	if (look.stroke !== undefined) {
		const stroke = new Instance("UIStroke");
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual;
		stroke.LineJoinMode = Enum.LineJoinMode.Round;
		stroke.Color = look.stroke.color;
		stroke.Thickness = math.max(1, look.stroke.thickness * size);
		stroke.Transparency = look.stroke.trans;
		stroke.Parent = char;
		if (look.strokeGradient !== undefined) {
			const g = new Instance("UIGradient");
			g.Rotation = look.strokeGradient.rotation;
			g.Parent = stroke;
		}
	}
	// where this character sits across the word, so a shared gradient runs through the whole title
	const holder = char.Parent;
	const width = holder !== undefined && holder.IsA("GuiObject") ? math.max(1, holder.AbsoluteSize.X) : math.max(1, char.Size.X.Offset * 8);
	const span: [number, number] = [char.Position.X.Offset / width, math.max(0.02, char.Size.X.Offset / width)];
	const item: Live = {
		char,
		look,
		index,
		base: char.Position,
		size,
		scale: new Instance("UIScale"),
		shadow,
		span,
		text: char.Text,
		lastShake: -1,
		shakePos: Vector2.zero,
		shakeRot: 0,
		lastDecode: -1,
		lastSpark: os.clock() - math.random(),
		sparks: [],
		visibleCheck: -1,
		onScreen: true,
	};
	item.scale.Parent = char;
	if (look.gradient !== undefined) {
		const g = new Instance("UIGradient");
		g.Rotation = look.gradient.rotation;
		g.Parent = char;
		item.gradient = g;
	}
	const strokeGradient = char.FindFirstChildOfClass("UIStroke")?.FindFirstChildOfClass("UIGradient");
	item.strokeGradient = strokeGradient;
	// first paint (also the whole paint for still titles)
	for (const [gradient, spec] of [
		[item.gradient, look.gradient],
		[item.strokeGradient, look.strokeGradient],
	] as [UIGradient | undefined, GradientSpec | undefined][]) {
		if (gradient !== undefined && spec !== undefined) {
			gradient.Color = spec.individual ? sequence(spec.colors, -index * spec.spacing, 1) : sequence(spec.colors, span[0], span[1]);
		}
	}
	// preview reveal: characters arrive one after another
	const stagger = tonumber(params?.[0]) ?? 0;
	if (stagger > 0) {
		const target = char.TextTransparency;
		char.TextTransparency = 1;
		const shadowTarget = shadow?.TextTransparency;
		if (shadow !== undefined) {
			shadow.TextTransparency = 1;
		}
		trove.Add(
			task.delay(index * stagger, () => {
				char.TextTransparency = target;
				if (shadow !== undefined && shadowTarget !== undefined) {
					shadow.TextTransparency = shadowTarget;
				}
			}),
		);
	}
	if (look.moving && !still) {
		track(item);
		trove.Add(() => untrack(item));
	}
	return item;
}

// ---------------------------------------------------------------------------------------------
// registration

const registered = new Map<string, Look>();

/** Register a look as the FancyText tag `afx_<name>`; returns the tag name. */
export function register(name: string, prefix: string, still = false): string {
	const tag = `afx_${name}${still ? "_still" : ""}`;
	if (!registered.has(tag)) {
		const look = compile(parseStack(prefix));
		registered.set(tag, look);
		FancyText.registerEffect(tag, {
			Init: (char: TextLabel | ImageLabel, index: number, trove: TroveLike, params?: string[]) => {
				const [ok, result] = pcall(build, look, char, index, trove, params, still);
				if (!ok) {
					warn(`[titleFx] ${tag}: ${tostring(result)}`);
				}
				return undefined;
			},
		});
	}
	return tag;
}

/** how many moving title characters are being driven right now (0 when idle) */
export function activeCount(): number {
	return live.size();
}
