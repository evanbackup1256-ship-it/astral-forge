// The crate reel: a strip of relics running past a brass marker, each one cast in its own pooled
// viewport and framed by FittedView. Only the slots in the window (plus one each side) have a
// viewport; as the strip moves, a slot that leaves one edge comes back in on the other with the
// next relic. The strip decelerates onto the drop, and how it gets there depends on the drop:
//   - a good drop hangs on the relic before it, then clicks over;
//   - a plain drop that has something rare right behind it stops just short of it;
//   - anything else settles with a small detent kick.
import { Palette } from "../CoreKit/theme";
import { FittedView, giveViewport, takeViewport } from "./viewportKit";

export interface ReelItem {
	rarity: string;
	rank: number;
	color: Color3;
	slot?: string;
}

export type Approach = "hang" | "tease" | "settle";

export interface ReelOptions {
	visible: number;
	slotW: number;
	zIndex: number;
	spinTime: number;
	approach: Approach;
	onTick?: (speed: number) => void;
}

const WHITE_HOT = Color3.fromRGB(255, 222, 170);
const BRASS = Color3.fromRGB(170, 126, 70);

function inert<T extends BasePart>(part: T, parent: Instance): T {
	part.Anchored = true;
	part.CanCollide = false;
	part.CanQuery = false;
	part.CanTouch = false;
	part.CastShadow = false;
	part.Parent = parent;
	return part;
}

function piece(parent: Instance, size: Vector3, color: Color3, material: Enum.Material, cf: CFrame, round = false): Part {
	const part = new Instance("Part");
	if (round) {
		part.Shape = Enum.PartType.Cylinder;
	}
	part.Size = size;
	part.Color = color;
	part.Material = material;
	part.CFrame = cf;
	return inert(part, parent);
}

// machine relics are a toothed ring on a brass hub, research relics a cut lens in a brass cradle;
// the best rarities keep a lit core. Built once per kind and cloned into slots.
const templates = new Map<string, Model>();
function relicTemplate(item: ReelItem): Model {
	const key = `${item.slot ?? "Machine"}|${item.rarity}`;
	const cached = templates.get(key);
	if (cached !== undefined) {
		return cached;
	}
	const model = new Instance("Model");
	const face = CFrame.Angles(0, math.pi / 2, 0);
	if (item.slot === "Research") {
		const lens = piece(model, new Vector3(0.14, 0.9, 0.9), item.color, Enum.Material.Glass, face, true);
		lens.Reflectance = 0.15;
		piece(model, new Vector3(0.18, 1.04, 1.04), BRASS, Enum.Material.Metal, face, true).Transparency = 0.55;
		for (let i = 0; i < 3; i++) {
			piece(model, new Vector3(0.08, 0.5, 0.1), BRASS, Enum.Material.Metal, face.mul(CFrame.Angles((i / 3) * math.pi * 2, 0, 0)).mul(new CFrame(0, -0.6, 0)));
		}
	} else {
		piece(model, new Vector3(0.32, 0.5, 0.5), BRASS, Enum.Material.Metal, face, true);
		piece(model, new Vector3(0.22, 0.9, 0.9), item.color, Enum.Material.Metal, face, true);
		const TEETH = 10;
		for (let i = 0; i < TEETH; i++) {
			piece(model, new Vector3(0.22, 0.16, 0.14), item.color, Enum.Material.Metal, face.mul(CFrame.Angles((i / TEETH) * math.pi * 2, 0, 0)).mul(new CFrame(0, 0.5, 0)));
		}
	}
	if (item.rank >= 5) {
		piece(model, new Vector3(0.26, 0.3, 0.3), WHITE_HOT.Lerp(item.color, 0.5), Enum.Material.Neon, face, true);
	}
	templates.set(key, model);
	return model;
}

// a three-quarter view, so the ring reads as a part and not a coin
const VIEW = CFrame.lookAt(new Vector3(0.55, 0.35, 1), Vector3.zero);

interface Slot {
	frame: Frame;
	plate: Frame;
	bar: Frame;
	stroke: UIStroke;
	viewport: ViewportFrame;
	view: FittedView;
	model?: Model;
	index: number;
}

function easeOutQuart(x: number) {
	return 1 - (1 - math.clamp(x, 0, 1)) ** 4;
}
function easeInOut(x: number) {
	const c = math.clamp(x, 0, 1);
	return c * c * (3 - 2 * c);
}

export class Reel {
	private readonly slots: Slot[] = [];
	private offset = 0;
	private lastWhole = 0;
	private lastTick = 0;
	private landed = false;
	/** seconds from start until the strip is at rest on the drop */
	readonly duration: number;

	constructor(
		private readonly host: GuiObject,
		private readonly items: ReelItem[],
		private readonly land: number,
		private readonly options: ReelOptions,
	) {
		this.duration = options.spinTime + (options.approach === "hang" ? 0.75 : options.approach === "tease" ? 0.45 : 0.25);
		const count = options.visible + 2;
		for (let k = 0; k < count; k++) {
			this.slots.push(this.makeSlot());
		}
		this.layout();
	}

	private makeSlot(): Slot {
		const size = this.options.slotW;
		const z = this.options.zIndex;
		const frame = new Instance("Frame");
		frame.Size = UDim2.fromOffset(size - 8, size - 8);
		frame.AnchorPoint = new Vector2(0.5, 0.5);
		frame.BackgroundTransparency = 1;
		frame.ZIndex = z;
		frame.Parent = this.host;
		const plate = new Instance("Frame");
		plate.Size = UDim2.fromScale(1, 1);
		plate.BackgroundColor3 = Palette.panelSoft;
		plate.BackgroundTransparency = 0.35;
		plate.BorderSizePixel = 0;
		plate.ZIndex = z;
		plate.Parent = frame;
		const corner = new Instance("UICorner");
		corner.CornerRadius = new UDim(0, 3);
		corner.Parent = plate;
		// a cast-iron tile: dark face falling off toward the bottom, a single struck highlight on top
		const face = new Instance("UIGradient");
		face.Rotation = 90;
		face.Transparency = new NumberSequence(0, 0.45);
		face.Parent = plate;
		const lip = new Instance("Frame");
		lip.Position = UDim2.fromOffset(4, 1);
		lip.Size = new UDim2(1, -8, 0, 1);
		lip.BackgroundColor3 = BRASS;
		lip.BackgroundTransparency = 0.55;
		lip.BorderSizePixel = 0;
		lip.ZIndex = z;
		lip.Parent = plate;
		const stroke = new Instance("UIStroke");
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
		stroke.Color = BRASS;
		stroke.Transparency = 0.7;
		stroke.Parent = plate;
		// the rarity reads off a lit strip along the bottom of the slot, not a glow
		const bar = new Instance("Frame");
		bar.AnchorPoint = new Vector2(0.5, 1);
		bar.Position = new UDim2(0.5, 0, 1, -5);
		bar.Size = new UDim2(0, 14, 0, 2);
		bar.BorderSizePixel = 0;
		bar.ZIndex = z + 2;
		bar.Parent = frame;
		const barCorner = new Instance("UICorner");
		barCorner.CornerRadius = new UDim(1, 0);
		barCorner.Parent = bar;
		const viewport = takeViewport(frame, z + 1);
		const view = new FittedView(viewport, 30);
		return { frame, plate, bar, stroke, viewport, view, index: -1 };
	}

	private fill(slot: Slot, index: number) {
		slot.index = index;
		slot.model?.Destroy();
		const item = this.items[index];
		if (item === undefined) {
			slot.model = undefined;
			slot.frame.Visible = false;
			return;
		}
		slot.frame.Visible = true;
		const model = relicTemplate(item).Clone();
		model.Parent = slot.viewport;
		slot.model = model;
		slot.bar.BackgroundColor3 = item.color;
		slot.bar.BackgroundTransparency = item.rank >= 3 ? 0 : 0.4;
		slot.view.onFit = () => {
			slot.view.camera.CFrame = slot.view.frame(VIEW, 0.12);
		};
		slot.view.setModel(model);
	}

	/** strip position in slots for `t` seconds after the start */
	private at(t: number): number {
		const o = this.options;
		const final = this.land;
		if (o.approach === "hang") {
			// run up to the relic before the drop and nearly stop there, then click over
			const main = easeOutQuart(t / o.spinTime) * (final - 0.58);
			if (t <= o.spinTime) {
				return main;
			}
			const hold = t - o.spinTime;
			if (hold < 0.45) {
				return final - 0.58 + hold * 0.18;
			}
			return final - 0.5 + easeInOut((hold - 0.45) / 0.3) * 0.5;
		}
		if (o.approach === "tease") {
			// carries on toward the rare one behind the drop, runs out of momentum and falls back
			const main = easeOutQuart(t / o.spinTime) * (final + 0.36);
			if (t <= o.spinTime) {
				return main;
			}
			return final + 0.36 - easeInOut((t - o.spinTime) / 0.45) * 0.36;
		}
		const main = easeOutQuart(t / o.spinTime) * (final + 0.1);
		if (t <= o.spinTime) {
			return main;
		}
		return final + 0.1 - easeInOut((t - o.spinTime) / 0.25) * 0.1;
	}

	private layout() {
		const o = this.options;
		const n = this.slots.size();
		const first = math.floor(this.offset - o.visible / 2 - 0.5);
		for (let i = first; i < first + n; i++) {
			const slot = this.slots[((i % n) + n) % n];
			if (slot.index !== i) {
				this.fill(slot, i);
			}
			slot.frame.Position = new UDim2(0.5, math.round((i - this.offset) * o.slotW), 0.5, 0);
			const centre = math.max(0, 1 - math.abs(i - this.offset));
			slot.plate.BackgroundTransparency = 0.35 - centre * 0.2;
		}
	}

	step(t: number) {
		if (this.landed) {
			return;
		}
		const previous = this.offset;
		this.offset = this.at(t);
		const whole = math.floor(this.offset + 0.5);
		if (whole !== this.lastWhole) {
			this.lastWhole = whole;
			const now = os.clock();
			if (now - this.lastTick > 0.045) {
				this.lastTick = now;
				this.options.onTick?.(math.abs(this.offset - previous));
			}
		}
		this.layout();
		if (t >= this.duration) {
			this.settle();
		}
	}

	/** jump to rest on the drop and light it */
	settle() {
		this.offset = this.land;
		this.layout();
		this.landed = true;
		for (const slot of this.slots) {
			if (slot.index === this.land) {
				const item = this.items[this.land];
				slot.stroke.Color = item.color;
				slot.stroke.Transparency = 0;
				slot.stroke.Thickness = 2;
				slot.bar.Size = new UDim2(0.6, 0, 0, 3);
			} else {
				slot.viewport.ImageTransparency = 0.55;
				slot.bar.BackgroundTransparency = 0.7;
			}
		}
	}

	isLanded() {
		return this.landed;
	}

	destroy() {
		for (const slot of this.slots) {
			slot.view.destroy();
			giveViewport(slot.viewport);
			slot.frame.Destroy();
		}
		this.slots.clear();
	}
}

