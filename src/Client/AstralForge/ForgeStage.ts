// Local plot dressing. The server replicates a pad, a collect prompt and a short roster;
// the parts, lights and sparks live only on this client and only for plots in range.
import { Audio } from "./AudioKit/audio";
import { getActiveClientStore } from "./CoreKit/clientStore";
import { currentAntilagInfo } from "./MotionKit/antilag";
import { isReducedMotion } from "./MotionPreference";
import * as ForgeTheme from "../../Shared/AstralForge/Shared/ForgeTheme";
import * as PlotLayout from "../../Shared/AstralForge/Shared/PlotLayout";

const Players = game.GetService("Players");
const ProximityPromptService = game.GetService("ProximityPromptService");
const RunService = game.GetService("RunService");
const TweenService = game.GetService("TweenService");
const Workspace = game.GetService("Workspace");

const SCAN_SECONDS = 0.25;
const SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds";

interface Spinner {
	part: BasePart;
	home: CFrame;
	phase: number;
}

	interface Dressed {
	folder: Folder;
	signature: string;
	cores: Map<string, BasePart>;
	lead?: BasePart;
	spinners: Spinner[];
	lights: PointLight[];
	emitters: ParticleEmitter[];
	tweens: Tween[];
}

interface Watched {
	model: Model;
	connections: RBXScriptConnection[];
	dressed?: Dressed;
	lastRoster: PlotLayout.MachineMark[];
	localPlot: boolean;
}

const player = Players.LocalPlayer;

function settingNumber(settings: Record<string, unknown> | undefined, key: string, fallback: number): number {
	const value = settings?.[key];
	if (!typeIs(value, "number") || value !== value) {
		return fallback;
	}
	return value;
}

function readBudget(): { budget: PlotLayout.StageBudget; glow: number } {
	const info = currentAntilagInfo();
	const settings = getActiveClientStore()?.getState().session?.Settings;
	const glow = settingNumber(settings, "GlowIntensity", 0.75) * info.glowScale;
	const motion = settingNumber(settings, "MotionIntensity", 1);
	const budget = PlotLayout.stageBudget({
		fx: info.fxBudget,
		density: settingNumber(settings, "ParticleDensity", 0.75),
		glow,
		effects: settingNumber(settings, "EffectsIntensity", 1),
		reducedMotion: isReducedMotion() || motion < 0.3,
		hideOtherPlots: settings?.HideOtherPlots === true || settings?.HideOtherPlots === 1,
		constrained: info.constrained,
	});
	return { budget, glow };
}

function finish(part: BasePart) {
	part.Anchored = true;
	part.CanCollide = false;
	part.CanQuery = false;
	part.CanTouch = false;
	part.CastShadow = false;
	if (part.IsA("Part") || part.IsA("WedgePart")) {
		part.TopSurface = Enum.SurfaceType.Smooth;
		part.BottomSurface = Enum.SurfaceType.Smooth;
	}
}

function pose(spinner: Spinner, bob: number, yaw: number) {
	spinner.part.CFrame = spinner.home
		.mul(new CFrame(0, bob, 0))
		.mul(CFrame.Angles(0, yaw, 0))
		.mul(CFrame.Angles(0, 0, math.rad(90)));
}

function inWorld(instance: Instance): boolean {
	let current: Instance | undefined = instance;
	while (current !== undefined) {
		if (current.Name === "AstralForgeWorld") {
			return true;
		}
		current = current.Parent;
	}
	return false;
}

function attributeNumber(model: Model, name: string): number | undefined {
	const value = model.GetAttribute(name);
	if (!typeIs(value, "number") || value !== value) {
		return undefined;
	}
	return value;
}

function isLocalPlot(model: Model): boolean {
	const owner = model.GetAttribute(PlotLayout.ATTR.owner);
	if (typeIs(owner, "number") && owner === player.UserId) {
		return true;
	}
	return model.Name === `Plot_${player.Name}`;
}

export function attach(): () => void {
	let alive = true;
	let world: Folder | undefined;
	let budget = PlotLayout.stageBudget({
		fx: 0.5,
		density: 0.75,
		glow: 0.5,
		effects: 1,
		reducedMotion: false,
		hideOtherPlots: false,
		constrained: false,
	});
	let glowNow = 0.5;
	let watching = false;
	let scanDebt = SCAN_SECONDS;
	let scanForced = true;
	let motionDebt = 0;
	let cursor = 0;
	const watched = new Map<Model, Watched>();
	let spinners: Spinner[] = [];
	const connections: RBXScriptConnection[] = [];
	let worldConnections: RBXScriptConnection[] = [];

	function activeTweens(): number {
		let count = 0;
		for (const [, record] of watched) {
			if (record.dressed !== undefined) {
				count += record.dressed.tweens.size();
			}
		}
		return count;
	}

	function pulseCore(core: BasePart, dressed: Dressed) {
		if (budget.tweens <= 0 || activeTweens() >= budget.tweens) {
			return;
		}
		const rest = core.GetAttribute("RestTransparency");
		const target = typeIs(rest, "number") ? rest : 0.12;
		core.Transparency = 0.02;
		const tween = TweenService.Create(
			core,
			new TweenInfo(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency: target },
		);
		dressed.tweens.push(tween);
		tween.Completed.Connect(() => {
			const index = dressed.tweens.indexOf(tween);
			if (index >= 0) {
				dressed.tweens.remove(index);
			}
			tween.Destroy();
		});
		tween.Play();
	}

	function stopTweens(dressed: Dressed) {
		for (const tween of dressed.tweens) {
			tween.Cancel();
			tween.Destroy();
		}
		dressed.tweens.clear();
	}

	function undress(record: Watched) {
		const dressed = record.dressed;
		if (dressed === undefined) {
			return;
		}
		stopTweens(dressed);
		dressed.folder.Destroy();
		record.dressed = undefined;
	}

	function forget(model: Model) {
		const record = watched.get(model);
		if (record === undefined) {
			return;
		}
		watched.delete(model);
		for (const connection of record.connections) {
			connection.Disconnect();
		}
		undress(record);
	}

	function addTrim(baseCf: CFrame, parent: Instance) {
		const strips = [
			{ x: 0, z: -27, sx: 68, sz: 0.55 },
			{ x: 0, z: 27, sx: 68, sz: 0.55 },
			{ x: -35, z: 0, sx: 0.55, sz: 52 },
			{ x: 35, z: 0, sx: 0.55, sz: 52 },
		];
		for (const strip of strips) {
			const part = new Instance("Part");
			part.Name = "Trim";
			part.Size = new Vector3(strip.sx, 0.22, strip.sz);
			part.CFrame = baseCf.mul(new CFrame(strip.x, 2.11, strip.z));
			part.Material = Enum.Material.Metal;
			part.Color = ForgeTheme.Base.brass;
			finish(part);
			part.Parent = parent;
		}
	}

	function addScenery(baseCf: CFrame, zoneColor: Color3, zoneId: number, parent: Instance) {
		const marks = PlotLayout.sceneryMarks(zoneId, budget.scenery);
		if (marks.size() === 0) {
			return;
		}
		const folder = new Instance("Folder");
		folder.Name = "Scenery";
		folder.Parent = parent;
		for (const mark of marks) {
			let cf = baseCf
				.mul(new CFrame(mark.x, mark.y, mark.z))
				.mul(CFrame.Angles(0, mark.yaw, 0))
				.mul(CFrame.Angles(mark.pitch, 0, 0));
			let part: BasePart;
			if (mark.shape === "wedge") {
				const shard = new Instance("WedgePart");
				shard.Name = "Shard";
				shard.Material = Enum.Material.Glass;
				shard.Color = zoneColor;
				shard.Transparency = 0.2;
				part = shard;
			} else {
				const block = new Instance("Part");
				if (mark.shape === "ring") {
					block.Name = "Ring";
					block.Shape = Enum.PartType.Cylinder;
					block.Material = Enum.Material.Neon;
					block.Color = zoneColor.Lerp(ForgeTheme.Base.ember, 0.35);
					block.Transparency = 0.38;
					cf = cf.mul(CFrame.Angles(0, 0, math.rad(90)));
				} else if (mark.shape === "ball") {
					block.Name = "Orb";
					block.Shape = Enum.PartType.Ball;
					block.Material = Enum.Material.Neon;
					block.Color = zoneColor;
					block.Transparency = 0.22;
				} else {
					block.Name = "Post";
					block.Material = Enum.Material.Metal;
					block.Color = zoneColor.Lerp(ForgeTheme.Base.graphite, 0.5);
				}
				part = block;
			}
			part.Size = new Vector3(mark.sx, mark.sy, mark.sz);
			part.CFrame = cf;
			finish(part);
			part.Parent = folder;
		}
	}

	function addPillar(baseCf: CFrame, rank: number, parent: Instance) {
		const height = PlotLayout.pillarHeight(rank);
		if (height <= 0) {
			return;
		}
		const column = new Instance("Part");
		column.Name = "Column";
		column.Size = new Vector3(1.6, height, 1.6);
		column.CFrame = baseCf.mul(new CFrame(0, 2 + height / 2, 24));
		column.Material = Enum.Material.Metal;
		column.Color = ForgeTheme.Base.graphite;
		finish(column);
		column.Parent = parent;

		const cap = new Instance("Part");
		cap.Name = "Cap";
		cap.Shape = Enum.PartType.Ball;
		cap.Size = new Vector3(2.1, 2.1, 2.1);
		cap.CFrame = baseCf.mul(new CFrame(0, 2 + height + 0.7, 24));
		cap.Material = Enum.Material.Neon;
		cap.Color = ForgeTheme.Base.pink;
		cap.Transparency = 0.12;
		finish(cap);
		cap.Parent = parent;
	}

	function addSpark(core: BasePart, color: Color3, dressed: Dressed) {
		const emitter = new Instance("ParticleEmitter");
		emitter.Name = "Sparks";
		emitter.Texture = SPARK_TEXTURE;
		emitter.Color = new ColorSequence(color);
		emitter.LightEmission = 0.45;
		emitter.LightInfluence = 0;
		emitter.LockedToPart = true;
		emitter.EmissionDirection = Enum.NormalId.Top;
		emitter.Lifetime = new NumberRange(0.35, 0.7);
		emitter.Speed = new NumberRange(0.5, 1.3);
		emitter.SpreadAngle = new Vector2(16, 16);
		emitter.RotSpeed = new NumberRange(-30, 30);
		emitter.Rotation = new NumberRange(0, 360);
		emitter.Drag = 1.6;
		emitter.Acceleration = new Vector3(0, 1.1, 0);
		emitter.Size = new NumberSequence([
			new NumberSequenceKeypoint(0, 0.2),
			new NumberSequenceKeypoint(1, 0.04),
		]);
		emitter.Transparency = new NumberSequence([
			new NumberSequenceKeypoint(0, 0.2),
			new NumberSequenceKeypoint(1, 1),
		]);
		emitter.Rate = budget.particleRate;
		emitter.Enabled = false;
		emitter.Parent = core;
		dressed.emitters.push(emitter);
	}

	function dress(record: Watched, base: BasePart) {
		const zone = attributeNumber(record.model, PlotLayout.ATTR.zone);
		const machines = record.model.GetAttribute(PlotLayout.ATTR.machines);
		if (zone === undefined || !typeIs(machines, "string")) {
			return;
		}
		const rebirths = attributeNumber(record.model, PlotLayout.ATTR.rebirths) ?? 0;
		const domain = attributeNumber(record.model, PlotLayout.ATTR.domain) ?? 0;
		const signature = `${zone}|${rebirths}|${domain}|${machines}|${PlotLayout.budgetKey(budget)}`;
		if (record.dressed !== undefined && record.dressed.signature === signature) {
			return;
		}

		const roster = PlotLayout.decodeRoster(machines);
		const drawn: PlotLayout.MachineMark[] = [];
		const count = math.min(roster.size(), budget.machines);
		for (let index = 0; index < count; index++) {
			drawn.push(roster[index]);
		}
		const wasDressed = record.dressed !== undefined;
		const raised = wasDressed && record.localPlot ? PlotLayout.raisedLevels(record.lastRoster, roster) : [];
		record.lastRoster = roster;

		undress(record);
		const folder = new Instance("Folder");
		folder.Name = "Dressing";
		const dressed: Dressed = {
			folder,
			signature,
			cores: new Map(),
			spinners: [],
			lights: [],
			emitters: [],
			tweens: [],
		};
		const baseCf = base.CFrame;
		if (budget.trim) {
			addTrim(baseCf, folder);
		}
		addScenery(baseCf, base.Color, zone, folder);
		addPillar(baseCf, domain, folder);

		const machinesFolder = new Instance("Folder");
		machinesFolder.Name = "Machines";
		machinesFolder.Parent = folder;
		for (let index = 0; index < drawn.size(); index++) {
			const mark = drawn[index];
			const offset = PlotLayout.machineOffset(index);
			const span = PlotLayout.machineScale(mark.level);
			const color = Color3.fromRGB(mark.r, mark.g, mark.b);
			const plinthH = span * 0.38;
			const bedH = 0.22;
			const model = new Instance("Model");
			model.Name = mark.id;
			model.Parent = machinesFolder;

			const plinth = new Instance("Part");
			plinth.Name = "Plinth";
			plinth.Size = new Vector3(span, plinthH, span);
			plinth.CFrame = baseCf.mul(new CFrame(offset.x, 2 + plinthH / 2, offset.z));
			plinth.Material = Enum.Material.Metal;
			plinth.Color = ForgeTheme.Base.graphite;
			finish(plinth);
			plinth.Parent = model;

			let seat = 2 + plinthH;
			if (budget.detail === 3) {
				const bed = new Instance("Part");
				bed.Name = "Bed";
				bed.Size = new Vector3(span * 0.72, bedH, span * 0.72);
				bed.CFrame = baseCf.mul(new CFrame(offset.x, seat + bedH / 2, offset.z));
				bed.Material = Enum.Material.Metal;
				bed.Color = ForgeTheme.Base.brassDeep;
				finish(bed);
				bed.Parent = model;
				seat += bedH;
			}

			const coreH = span * 0.62;
			const coreD = span * 0.34;
			const core = new Instance("Part");
			core.Name = "Core";
			core.Shape = Enum.PartType.Cylinder;
			core.Size = new Vector3(coreH, coreD, coreD);
			core.Material = Enum.Material.Neon;
			core.Color = color;
			core.Transparency = 0.12;
			core.SetAttribute("RestTransparency", 0.12);
			finish(core);
			core.Parent = model;
			const home = baseCf.mul(new CFrame(offset.x, seat + coreH / 2, offset.z));
			const spinner: Spinner = { part: core, home, phase: index * 0.7 };
			pose(spinner, 0, 0);
			dressed.spinners.push(spinner);
			dressed.cores.set(mark.id, core);
			if (dressed.lead === undefined) {
				dressed.lead = core;
			}

			if (record.localPlot && dressed.lights.size() < budget.lights) {
				const light = new Instance("PointLight");
				light.Name = "CoreLight";
				light.Color = color;
				light.Range = 12;
				light.Brightness = 0.3 + glowNow * 1.2;
				light.Shadows = false;
				light.Enabled = false;
				light.Parent = core;
				dressed.lights.push(light);
			}
			if (record.localPlot && dressed.emitters.size() < budget.particles) {
				addSpark(core, color, dressed);
			}
		}

		folder.Parent = record.model;
		record.dressed = dressed;

		if (watching) {
			for (const id of raised) {
				const core = dressed.cores.get(id);
				if (core !== undefined) {
					pulseCore(core, dressed);
				}
			}
		}
	}

	function rebuildSpinners() {
		const ordered: Spinner[] = [];
		const rest: Spinner[] = [];
		for (const [, record] of watched) {
			const dressed = record.dressed;
			if (dressed === undefined) {
				continue;
			}
			const bucket = record.localPlot ? ordered : rest;
			for (const spinner of dressed.spinners) {
				bucket.push(spinner);
			}
		}
		for (const spinner of rest) {
			ordered.push(spinner);
		}
		spinners = ordered;
		if (cursor >= spinners.size()) {
			cursor = 0;
		}
	}

	function applyFx() {
		for (const [, record] of watched) {
			const dressed = record.dressed;
			if (dressed === undefined) {
				continue;
			}
			const lit = watching && record.localPlot;
			for (const light of dressed.lights) {
				light.Enabled = lit;
				light.Brightness = 0.3 + glowNow * 1.2;
			}
			for (const emitter of dressed.emitters) {
				emitter.Rate = budget.particleRate;
				emitter.Enabled = lit && budget.particleRate > 0;
			}
		}
	}

	function cameraNear(): boolean {
		const camera = Workspace.CurrentCamera;
		if (camera === undefined) {
			return false;
		}
		const reach = budget.radius + 70;
		const position = camera.CFrame.Position;
		for (const [, record] of watched) {
			if (record.dressed === undefined) {
				continue;
			}
			const base = record.model.FindFirstChild("Base");
			if (base === undefined || !base.IsA("BasePart")) {
				continue;
			}
			if (base.Position.sub(position).Magnitude <= reach) {
				return true;
			}
		}
		return false;
	}

	function park() {
		for (const spinner of spinners) {
			if (spinner.part.Parent !== undefined) {
				pose(spinner, 0, 0);
			}
		}
	}

	function scan() {
		if (!alive || world === undefined || world.Parent === undefined) {
			return;
		}
		const reading = readBudget();
		budget = reading.budget;
		glowNow = reading.glow;

		let originX = 0;
		let originY = 0;
		let originZ = 0;
		let haveOrigin = false;
		const spots: PlotLayout.PlotSpot[] = [];
		for (const [model, record] of watched) {
			if (model.Parent !== world) {
				continue;
			}
			const base = model.FindFirstChild("Base");
			if (base === undefined || !base.IsA("BasePart")) {
				continue;
			}
			record.localPlot = isLocalPlot(model);
			if (record.localPlot && !haveOrigin) {
				const root = player.Character?.FindFirstChild("HumanoidRootPart");
				const position = root !== undefined && root.IsA("BasePart") ? root.Position : base.Position;
				originX = position.X;
				originY = position.Y;
				originZ = position.Z;
				haveOrigin = true;
			}
			spots.push({
				key: model.Name,
				x: base.Position.X,
				y: base.Position.Y,
				z: base.Position.Z,
				localPlot: record.localPlot,
			});
		}
		const keys = PlotLayout.streamPlots(
			spots,
			originX,
			originY,
			originZ,
			budget.radius,
			budget.plots,
			budget.plots <= 1,
		);
		const wanted = new Set<string>();
		for (const key of keys) {
			wanted.add(key);
		}
		for (const [, record] of watched) {
			if (!wanted.has(record.model.Name)) {
				undress(record);
			}
		}
		for (const [, record] of watched) {
			if (!wanted.has(record.model.Name)) {
				continue;
			}
			const base = record.model.FindFirstChild("Base");
			if (base !== undefined && base.IsA("BasePart")) {
				dress(record, base);
			}
		}
		rebuildSpinners();
		const wasWatching = watching;
		watching = cameraNear();
		if (wasWatching && !watching) {
			park();
		}
		applyFx();
	}

	function scanSoon() {
		scanForced = true;
	}

	function watch(model: Model) {
		if (watched.has(model)) {
			return;
		}
		const record: Watched = { model, connections: [], lastRoster: [], localPlot: false };
		const poke = () => scanSoon();
		record.connections.push(model.GetAttributeChangedSignal(PlotLayout.ATTR.zone).Connect(poke));
		record.connections.push(model.GetAttributeChangedSignal(PlotLayout.ATTR.rebirths).Connect(poke));
		record.connections.push(model.GetAttributeChangedSignal(PlotLayout.ATTR.domain).Connect(poke));
		record.connections.push(model.GetAttributeChangedSignal(PlotLayout.ATTR.machines).Connect(poke));
		record.connections.push(model.GetAttributeChangedSignal(PlotLayout.ATTR.owner).Connect(poke));
		record.connections.push(
			model.AncestryChanged.Connect(() => {
				if (model.Parent === undefined) {
					forget(model);
				}
			}),
		);
		watched.set(model, record);
		scanSoon();
	}

	function consider(child: Instance) {
		if (child.IsA("Model")) {
			watch(child);
		}
	}

	function unbindWorld() {
		for (const connection of worldConnections) {
			connection.Disconnect();
		}
		worldConnections = [];
		const models: Model[] = [];
		for (const [model] of watched) {
			models.push(model);
		}
		for (const model of models) {
			forget(model);
		}
		world = undefined;
		spinners = [];
		watching = false;
	}

	function bindWorld(folder: Folder) {
		if (world === folder) {
			return;
		}
		unbindWorld();
		world = folder;
		worldConnections.push(folder.ChildAdded.Connect(consider));
		worldConnections.push(
			folder.ChildRemoved.Connect((child) => {
				if (child.IsA("Model")) {
					forget(child);
				}
			}),
		);
		for (const child of folder.GetChildren()) {
			consider(child);
		}
		scanSoon();
	}

	connections.push(
		Workspace.ChildAdded.Connect((child) => {
			if (alive && child.Name === "AstralForgeWorld" && child.IsA("Folder")) {
				bindWorld(child);
			}
		}),
	);
	connections.push(
		Workspace.ChildRemoved.Connect((child) => {
			if (child === world) {
				unbindWorld();
			}
		}),
	);
	connections.push(
		ProximityPromptService.PromptTriggered.Connect((prompt, who) => {
			if (!alive || who !== player || prompt.Name !== "CollectPrompt" || !inWorld(prompt)) {
				return;
			}
			task.defer(() => {
				if (alive) {
					Audio.play("collect");
				}
			});
			if (!watching) {
				return;
			}
			for (const [, record] of watched) {
				const dressed = record.dressed;
				if (record.localPlot && dressed !== undefined && dressed.lead !== undefined) {
					pulseCore(dressed.lead, dressed);
					break;
				}
			}
		}),
	);
	connections.push(
		RunService.Heartbeat.Connect((dt) => {
			if (!alive) {
				return;
			}
			scanDebt += dt;
			if (scanForced || scanDebt >= SCAN_SECONDS) {
				scanForced = false;
				scanDebt = 0;
				scan();
			}
			if (!watching || budget.spins <= 0 || spinners.size() === 0) {
				return;
			}
			motionDebt += dt;
			const step = 1 / budget.motionHz;
			if (motionDebt < step) {
				return;
			}
			motionDebt = math.min(motionDebt - step, step);
			const now = os.clock();
			const updates = math.min(budget.spins, spinners.size());
			for (let index = 0; index < updates; index++) {
				cursor = (cursor + 1) % spinners.size();
				const spinner = spinners[cursor];
				if (spinner.part.Parent === undefined) {
					continue;
				}
				pose(spinner, math.sin(now * 1.7 + spinner.phase) * 0.1, now * 0.35 + spinner.phase);
			}
		}),
	);

	const existing = Workspace.FindFirstChild("AstralForgeWorld");
	if (existing !== undefined && existing.IsA("Folder")) {
		bindWorld(existing);
	}
	task.spawn(() => {
		const found = Workspace.WaitForChild("AstralForgeWorld", 30);
		if (!alive || found === undefined || !found.IsA("Folder")) {
			return;
		}
		bindWorld(found);
	});

	return () => {
		if (!alive) {
			return;
		}
		alive = false;
		for (const connection of connections) {
			connection.Disconnect();
		}
		unbindWorld();
	};
}
