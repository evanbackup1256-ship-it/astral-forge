// The layered scene behind a crate opening.
//
// Every layer is its own ViewportFrame (no background, its own camera) stacked in screen space, so
// depth comes from the stack rather than one busy 3D scene: far slag, the furnace light, the crate
// (CrateModel, its own viewport), mid debris, the cast relic, then a few near plates that cross the
// lens. All cameras share one drift and one recoil, scaled per layer, which is where the parallax
// comes from. Viewports are pooled across openings and the count is capped on phones.

export type ForgePhase = "build" | "breach" | "cast" | "done";
export type LayerKind = "far" | "light" | "mid" | "relic" | "near";

export interface ForgeFrame {
	phase: ForgePhase;
	/** seconds since this phase began */
	t: number;
	/** seconds since the overlay opened */
	clock: number;
	/** 0..1 how far the pressure has built */
	pressure: number;
	/** colour of the rarity step the gauge is on */
	heat: Color3;
	/** the best drop's rarity colour */
	color: Color3;
}

export interface ForgeLayer {
	kind: LayerKind;
	viewport: ViewportFrame;
	step(frame: ForgeFrame): void;
}

// ── pool ───────────────────────────────────────────────────────────────────────

const POOL_MAX = 6;
const pool: ViewportFrame[] = [];

function makeViewport(): ViewportFrame {
	const viewport = new Instance("ViewportFrame");
	viewport.Name = "ForgeLayer";
	viewport.BackgroundTransparency = 1;
	viewport.BorderSizePixel = 0;
	viewport.Size = UDim2.fromScale(1, 1);
	viewport.Active = false;
	viewport.Selectable = false;
	return viewport;
}

function take(host: GuiObject, zIndex: number): [ViewportFrame, Camera] {
	const viewport = pool.pop() ?? makeViewport();
	viewport.ImageTransparency = 0;
	viewport.ImageColor3 = new Color3(1, 1, 1);
	viewport.Ambient = Color3.fromRGB(120, 112, 118);
	viewport.LightColor = Color3.fromRGB(255, 226, 196);
	viewport.LightDirection = new Vector3(-0.4, -1, 0.6);
	viewport.ZIndex = zIndex;
	const camera = new Instance("Camera");
	camera.FieldOfView = 32;
	camera.Parent = viewport;
	viewport.CurrentCamera = camera;
	viewport.Parent = host;
	return [viewport, camera];
}

export function release(layer: ForgeLayer) {
	const viewport = layer.viewport;
	viewport.CurrentCamera = undefined;
	viewport.ClearAllChildren();
	viewport.Parent = undefined;
	if (pool.size() < POOL_MAX) {
		pool.push(viewport);
	} else {
		viewport.Destroy();
	}
}

/**
 * How many pooled layers this opening gets, best first. The crate's own viewport is always there,
 * so phones get three more and desktops five. Lower rarities don't ask for the far or near layers.
 */
export function layersFor(rank: number, phone: boolean): LayerKind[] {
	const wanted: LayerKind[] = ["relic", "mid", "light"];
	if (rank >= 3) {
		wanted.push("far");
	}
	if (rank >= 5) {
		wanted.push("near");
	}
	const cap = phone ? 3 : 5;
	const out: LayerKind[] = [];
	for (const kind of wanted) {
		if (out.size() < cap) {
			out.push(kind);
		}
	}
	return out;
}

// ── shared helpers ─────────────────────────────────────────────────────────────

const IRON = Color3.fromRGB(52, 50, 56);
const SOOT = Color3.fromRGB(34, 31, 33);
const BRASS = Color3.fromRGB(170, 126, 70);
const WHITE_HOT = Color3.fromRGB(255, 222, 170);

function inert<T extends BasePart>(part: T, parent: Instance): T {
	part.Anchored = true;
	part.CanCollide = false;
	part.CanQuery = false;
	part.CanTouch = false;
	part.CastShadow = false;
	part.Parent = parent;
	return part;
}

function block(parent: Instance, size: Vector3, color: Color3, material: Enum.Material, wedge = false): BasePart {
	const part = wedge ? new Instance("WedgePart") : new Instance("Part");
	part.Size = size;
	part.Color = color;
	part.Material = material;
	return inert(part, parent);
}

function clamp01(x: number) {
	return math.clamp(x, 0, 1);
}

function easeOut(x: number) {
	return 1 - (1 - clamp01(x)) ** 3;
}

/** one recoil + drift for every camera; `depth` scales it per layer */
function aim(camera: Camera, frame: ForgeFrame, depth: number, distance: number, focus = new Vector3(0, 0.6, 0)) {
	const drift = math.sin(frame.clock * 0.45) * 0.18 * depth;
	const lift = math.cos(frame.clock * 0.31) * 0.06 * depth;
	const kick = frame.phase === "breach" ? (1 - easeOut(frame.t / 0.35)) * 0.35 * depth : 0;
	const shake = frame.phase === "build" ? math.sin(frame.clock * 41) * 0.012 * frame.pressure * depth : 0;
	const eye = focus.add(new Vector3(drift + shake, distance * 0.3 + lift, -(distance + kick)));
	camera.CFrame = CFrame.lookAt(eye, focus.add(new Vector3(drift * 0.4, 0, 0)));
}

/** seconds since the lid let go, or undefined before it */
function sinceBreach(frame: ForgeFrame, breachLength: number): number | undefined {
	if (frame.phase === "build") {
		return undefined;
	}
	if (frame.phase === "breach") {
		return frame.t;
	}
	return breachLength + frame.t;
}

// ── debris ─────────────────────────────────────────────────────────────────────

interface Piece {
	part: BasePart;
	from: Vector3;
	velocity: Vector3;
	spin: Vector3;
	hot: boolean;
	life: number;
}

/**
 * Pieces of the crate's seal: iron plate, brass rivet strip, a few chips of slag still glowing.
 * They come out of the crate mouth, fall under gravity and cool from white-hot to the drop colour.
 */
function debrisLayer(kind: LayerKind, host: GuiObject, zIndex: number, rank: number, phone: boolean, seed: number, breach: number): ForgeLayer {
	const [viewport, camera] = take(host, zIndex);
	const model = new Instance("Model");
	model.Parent = viewport;
	const rng = new Random(seed + (kind === "far" ? 11 : kind === "near" ? 23 : 0));
	const scale = kind === "far" ? 0.55 : kind === "near" ? 2.1 : 1;
	let count = kind === "far" ? 4 + rank * 2 : kind === "near" ? 2 + (rank - 5) * 2 : 6 + rank * 2;
	count = math.min(phone ? math.ceil(count / 2) : count, kind === "mid" ? 22 : 14);
	const depth = kind === "far" ? 0.35 : kind === "near" ? 1.8 : 1;
	const distance = kind === "far" ? 9 : kind === "near" ? 3.2 : 6;
	viewport.Ambient = kind === "far" ? Color3.fromRGB(70, 64, 70) : Color3.fromRGB(128, 118, 120);
	const pieces: Piece[] = [];
	for (let i = 0; i < count; i++) {
		const hot = kind !== "near" && i % 4 === 0;
		const plate = !hot && i % 3 !== 2;
		const size = hot
			? new Vector3(0.09, 0.09, 0.09).mul(scale * rng.NextNumber(0.8, 1.4))
			: plate
				? new Vector3(rng.NextNumber(0.22, 0.42), 0.04, rng.NextNumber(0.14, 0.3)).mul(scale)
				: new Vector3(0.08, rng.NextNumber(0.2, 0.34), 0.06).mul(scale);
		const color = hot ? WHITE_HOT : plate ? (i % 2 === 0 ? IRON : SOOT) : BRASS;
		const material = hot ? Enum.Material.Neon : plate ? Enum.Material.DiamondPlate : Enum.Material.Metal;
		const part = block(model, size, color, material, plate && i % 5 === 1);
		part.Transparency = 1;
		const angle = rng.NextNumber(0, math.pi * 2);
		const outward = rng.NextNumber(1.2, 3.2) * (kind === "near" ? 1.4 : 1);
		pieces.push({
			part,
			from: new Vector3(rng.NextNumber(-0.3, 0.3), 0.9, rng.NextNumber(-0.2, 0.2)),
			velocity: new Vector3(math.cos(angle) * outward, rng.NextNumber(2.6, 4.8) + rank * 0.15, math.sin(angle) * outward * 0.6),
			spin: new Vector3(rng.NextNumber(-9, 9), rng.NextNumber(-9, 9), rng.NextNumber(-9, 9)),
			hot,
			life: rng.NextNumber(0.9, 1.4) + (kind === "near" ? -0.3 : 0),
		});
	}
	return {
		kind,
		viewport,
		step(frame) {
			aim(camera, frame, depth, distance);
			const s = sinceBreach(frame, breach);
			for (const piece of pieces) {
				if (s === undefined || s > piece.life + 0.3) {
					piece.part.Transparency = 1;
					continue;
				}
				const p = piece.from.add(piece.velocity.mul(s)).add(new Vector3(0, -4.9 * s * s, 0));
				piece.part.CFrame = new CFrame(p).mul(CFrame.Angles(piece.spin.X * s, piece.spin.Y * s, piece.spin.Z * s));
				piece.part.Transparency = clamp01((s - piece.life) / 0.3);
				if (piece.hot) {
					piece.part.Color = WHITE_HOT.Lerp(frame.color, clamp01(s / 0.7)).Lerp(SOOT, clamp01((s - 0.7) / 0.6));
				}
			}
		},
	};
}

// ── furnace light ──────────────────────────────────────────────────────────────

/**
 * The light is built, not glowed: a floor grate whose bars heat up from the middle, and behind the
 * crate a row of narrow slots, like light through a furnace door's louvres. More slots open with
 * rarity; their colour follows the gauge and settles on the drop colour.
 */
function lightLayer(host: GuiObject, zIndex: number, rank: number, breach: number): ForgeLayer {
	const [viewport, camera] = take(host, zIndex);
	const model = new Instance("Model");
	model.Parent = viewport;
	viewport.Ambient = new Color3(1, 1, 1);
	const bars: BasePart[] = [];
	const BARS = 7;
	for (let i = 0; i < BARS; i++) {
		const bar = block(model, new Vector3(2.6, 0.03, 0.07), WHITE_HOT, Enum.Material.Neon);
		bar.CFrame = new CFrame(0, 0, (i - (BARS - 1) / 2) * 0.2);
		bar.Transparency = 1;
		bars.push(bar);
	}
	const frameBar = block(model, new Vector3(2.8, 0.05, 1.5), SOOT, Enum.Material.Metal);
	frameBar.CFrame = new CFrame(0, -0.04, 0);
	const slots: BasePart[] = [];
	const slotCount = rank >= 3 ? math.min(2 + (rank - 3) * 2, 9) : 0;
	for (let i = 0; i < slotCount; i++) {
		const offset = (i - (slotCount - 1) / 2) * 0.34;
		const slot = block(model, new Vector3(0.07, 3.4, 0.02), WHITE_HOT, Enum.Material.Neon);
		slot.CFrame = new CFrame(offset, 1.4, 1.6);
		slot.Transparency = 1;
		slots.push(slot);
	}
	return {
		kind: "light",
		viewport,
		step(frame) {
			aim(camera, frame, 0.6, 6);
			const s = sinceBreach(frame, breach);
			const flare = s === undefined ? 0 : math.exp(-s * 3.2);
			const settle = s === undefined ? 0 : clamp01(s / 0.5) * (0.35 + rank * 0.05);
			const heat = s === undefined ? frame.heat : frame.heat.Lerp(frame.color, clamp01(s / 0.4));
			for (let i = 0; i < BARS; i++) {
				const fromMiddle = math.abs(i - (BARS - 1) / 2) / ((BARS - 1) / 2);
				const lit = clamp01(frame.pressure * 1.4 - fromMiddle * 0.6) * 0.7 + flare * 0.3;
				bars[i].Transparency = 1 - clamp01(lit);
				bars[i].Color = WHITE_HOT.Lerp(heat, 0.35 + fromMiddle * 0.5);
			}
			for (let i = 0; i < slots.size(); i++) {
				const fromMiddle = math.abs(i - (slots.size() - 1) / 2) / math.max(1, (slots.size() - 1) / 2);
				// slots open from the middle out as the pressure builds
				const open = clamp01((frame.pressure - fromMiddle * 0.5) * 2);
				const slot = slots[i];
				const height = 3.4 * (s === undefined ? open : 1);
				slot.Size = new Vector3(0.07 + flare * 0.05, math.max(0.01, height), 0.02);
				slot.CFrame = new CFrame((i - (slots.size() - 1) / 2) * 0.34, height / 2 - 0.2, 1.6);
				slot.Color = heat;
				slot.Transparency = 1 - clamp01(open * 0.45 + flare * 0.4 + settle * 0.4) * (1 - fromMiddle * 0.4);
			}
			viewport.ImageTransparency = frame.phase === "done" ? clamp01(frame.t / 0.6) * 0.35 : 0;
		},
	};
}

// ── the relic ──────────────────────────────────────────────────────────────────

/**
 * A small cast part rather than a floating gem: a machine relic is a toothed ring on a hub, a
 * research relic a cut lens in a brass cradle. It rises out of the crate white-hot and cools to the
 * rarity colour; the best rarities keep a lit core.
 */
function relicLayer(host: GuiObject, zIndex: number, rank: number, slot: string | undefined, still: boolean, breach: number): ForgeLayer {
	const [viewport, camera] = take(host, zIndex);
	const model = new Instance("Model");
	model.Parent = viewport;
	viewport.Ambient = Color3.fromRGB(150, 140, 140);
	viewport.LightDirection = new Vector3(-0.6, -0.7, 0.5);
	const body: BasePart[] = [];
	const trim: BasePart[] = [];
	let core: BasePart | undefined = undefined;
	if (slot === "Research") {
		const lens = block(model, new Vector3(0.12, 0.9, 0.9), WHITE_HOT, Enum.Material.Glass);
		(lens as Part).Shape = Enum.PartType.Cylinder;
		lens.Reflectance = 0.15;
		body.push(lens);
		for (let i = 0; i < 3; i++) {
			const arm = block(model, new Vector3(0.08, 0.5, 0.1), BRASS, Enum.Material.Metal);
			arm.CFrame = CFrame.Angles((i / 3) * math.pi * 2, 0, 0).mul(new CFrame(0, -0.55, 0));
			trim.push(arm);
		}
		const ring = block(model, new Vector3(0.16, 1.02, 1.02), BRASS, Enum.Material.Metal);
		(ring as Part).Shape = Enum.PartType.Cylinder;
		ring.Transparency = 0.55;
		trim.push(ring);
	} else {
		const hub = block(model, new Vector3(0.3, 0.5, 0.5), BRASS, Enum.Material.Metal);
		(hub as Part).Shape = Enum.PartType.Cylinder;
		trim.push(hub);
		const rim = block(model, new Vector3(0.22, 0.9, 0.9), WHITE_HOT, Enum.Material.Metal);
		(rim as Part).Shape = Enum.PartType.Cylinder;
		body.push(rim);
		const TEETH = 10;
		for (let i = 0; i < TEETH; i++) {
			const tooth = block(model, new Vector3(0.22, 0.16, 0.14), WHITE_HOT, Enum.Material.Metal);
			tooth.CFrame = CFrame.Angles((i / TEETH) * math.pi * 2, 0, 0).mul(new CFrame(0, 0.5, 0));
			body.push(tooth);
		}
	}
	if (rank >= 5) {
		core = block(model, new Vector3(0.24, 0.3, 0.3), WHITE_HOT, Enum.Material.Neon);
		(core as Part).Shape = Enum.PartType.Cylinder;
	}
	const rest = body.map((part) => part.CFrame);
	const trimRest = trim.map((part) => part.CFrame);
	const coreRest = core?.CFrame;
	return {
		kind: "relic",
		viewport,
		step(frame) {
			aim(camera, frame, 0.8, 3.4, new Vector3(0, 0, 0));
			const s = sinceBreach(frame, breach);
			const castT = frame.phase === "cast" ? frame.t : frame.phase === "done" ? 99 : -1;
			const rise = still ? 1 : castT < 0 ? 0 : easeOut(castT / 0.45);
			const turn = still ? 0.5 : frame.clock * 0.6;
			const root = new CFrame(0, (1 - rise) * -1.4, 0).mul(CFrame.Angles(0.35, turn, 0)).mul(CFrame.Angles(0, math.pi / 2, 0));
			const cool = still ? 1 : castT < 0 ? 0 : clamp01(castT / 0.8);
			const tone = WHITE_HOT.Lerp(frame.color, cool);
			for (let i = 0; i < body.size(); i++) {
				body[i].CFrame = root.mul(rest[i]);
				body[i].Color = tone;
			}
			for (let i = 0; i < trim.size(); i++) {
				trim[i].CFrame = root.mul(trimRest[i]);
			}
			if (core !== undefined && coreRest !== undefined) {
				core.CFrame = root.mul(coreRest);
				core.Color = WHITE_HOT.Lerp(frame.color, cool * 0.6);
			}
			viewport.ImageTransparency = s === undefined && !still ? 1 : 1 - rise;
		},
	};
}

export function buildLayer(
	kind: LayerKind,
	host: GuiObject,
	zIndex: number,
	options: { rank: number; phone: boolean; seed: number; slot?: string; still: boolean; breach: number },
): ForgeLayer {
	if (kind === "light") {
		return lightLayer(host, zIndex, options.rank, options.breach);
	}
	if (kind === "relic") {
		return relicLayer(host, zIndex, options.rank, options.slot, options.still, options.breach);
	}
	return debrisLayer(kind, host, zIndex, options.rank, options.phone, options.seed, options.breach);
}
