import { Service } from "@flamework/core";
import { Dict, isTable, num, req, SharedFolder } from "./LuaInterop";

const Workspace = game.GetService("Workspace");

const GameConfig = req<{ Machines: Array<{ Id?: string; Color?: unknown }> }>(
	SharedFolder().WaitForChild("GameConfig"),
);

const PLOT_SIZE_X = 72;
const PLOT_SIZE_Z = 56;
const PLOT_SPACING_X = 96;
const PLOT_SPACING_Z = 80;
const BASE_Y = 64;

const createBasePlate = (name: string): Part => {
	const part = new Instance("Part");
	part.Name = name;
	part.Anchored = true;
	part.CanCollide = true;
	part.Size = new Vector3(PLOT_SIZE_X, 4, PLOT_SIZE_Z);
	part.Position = Vector3.zero;
	part.Material = Enum.Material.SmoothPlastic;
	part.TopSurface = Enum.SurfaceType.Smooth;
	part.BottomSurface = Enum.SurfaceType.Smooth;
	return part;
};

const attachCollectPrompt = (part: Part, player: Player, handler: unknown) => {
	const existing = part.FindFirstChild("CollectPrompt");
	if (existing) {
		existing.Destroy();
	}
	const prompt = new Instance("ProximityPrompt");
	prompt.Name = "CollectPrompt";
	prompt.ActionText = "Collect Flux";
	prompt.ObjectText = "Forge";
	prompt.KeyboardKeyCode = Enum.KeyCode.E;
	prompt.MaxActivationDistance = 18;
	prompt.HoldDuration = 0;
	prompt.RequiresLineOfSight = false;
	prompt.Enabled = true;
	prompt.Parent = part;
	prompt.Triggered.Connect((triggerPlayer: Player) => {
		if (triggerPlayer !== player) {
			return;
		}
		if (typeIs(handler, "function")) {
			(handler as (this: void, player: Player, action: string, payload: Dict) => void)(
				player,
				"Collect",
				{},
			);
		}
	});
	return prompt;
};

const gridPosition = (index: number): Vector3 => {
	const n = index + 1;
	const cols = 8;
	const row = math.floor((n - 1) / cols);
	const col = (n - 1) % cols;
	const x = (col - (cols - 1) / 2) * PLOT_SPACING_X;
	const z = row * PLOT_SPACING_Z;
	return new Vector3(x, BASE_Y, z);
};

const machineById: Record<string, { Id?: string; Color?: unknown }> = {};
for (const [, machine] of pairs(GameConfig.Machines)) {
	if (machine.Id !== undefined) {
		machineById[machine.Id] = machine;
	}
}

const clearMachineVisuals = (model: Instance) => {
	const existing = model.FindFirstChild("Machines");
	if (existing) {
		existing.Destroy();
	}
};

const renderMachineVisuals = (model: Model, base: BasePart, profile: unknown) => {
	clearMachineVisuals(model);
	const machines = isTable(profile) ? profile.Machines : undefined;
	if (!isTable(machines)) {
		return;
	}

	const container = new Instance("Folder");
	container.Name = "Machines";
	container.Parent = model;

	const basePos = base.CFrame.Position;
	let count = 0;
	for (const [machineId, level] of pairs(machines)) {
		if (!typeIs(level, "number") || level <= 0) {
			continue;
		}
		const machine = machineById[machineId as string];
		if (!machine) {
			continue;
		}
		count += 1;
		const col = (count - 1) % 4;
		const row = math.floor((count - 1) / 4);
		const offset = new Vector3((col - 1.5) * 12, 4, -8 + row * 12);
		const size = math.clamp(3 + math.log10(level + 1) * 0.8, 3, 8);

		const part = new Instance("Part");
		part.Name = machineId as string;
		part.Anchored = true;
		part.CanCollide = false;
		part.Size = new Vector3(size, size, size);
		part.CFrame = new CFrame(basePos.add(offset));
		part.Color = typeIs(machine.Color, "Color3") ? machine.Color : Color3.fromRGB(200, 200, 200);
		part.Material = Enum.Material.Neon;
		part.Transparency = 0.15;
		part.Parent = container;
	}
};

const clearScenery = (model: Instance) => {
	const existing = model.FindFirstChild("Scenery");
	if (existing) {
		existing.Destroy();
	}
};

const addRock = (parent: Instance, position: Vector3, color: Color3, size: Vector3) => {
	const part = new Instance("Part");
	part.Name = "Rock";
	part.Anchored = true;
	part.CanCollide = false;
	part.Size = size;
	part.CFrame = new CFrame(position);
	part.Color = color;
	part.Material = Enum.Material.Rock;
	part.Transparency = 0.25;
	part.Parent = parent;
	return part;
};

const addCrystal = (parent: Instance, position: Vector3, color: Color3, height: number) => {
	const part = new Instance("Part");
	part.Name = "Crystal";
	part.Anchored = true;
	part.CanCollide = false;
	part.Size = new Vector3(3, height, 3);
	part.CFrame = new CFrame(position);
	part.Color = color;
	part.Material = Enum.Material.Neon;
	part.Transparency = 0.3;
	part.Parent = parent;
	return part;
};

const addRing = (parent: Instance, center: Vector3, color: Color3) => {
	const ring = new Instance("Part");
	ring.Name = "HeatRing";
	ring.Anchored = true;
	ring.CanCollide = false;
	ring.Size = new Vector3(18, 0.8, 18);
	ring.CFrame = new CFrame(center.add(new Vector3(0, 2, 0)));
	ring.Color = color;
	ring.Material = Enum.Material.Neon;
	ring.Transparency = 0.5;
	ring.Shape = Enum.PartType.Cylinder;
	ring.Parent = parent;
	return ring;
};

const addOrb = (parent: Instance, position: Vector3, color: Color3) => {
	const part = new Instance("Part");
	part.Name = "EnergyOrb";
	part.Anchored = true;
	part.CanCollide = false;
	part.Size = new Vector3(3, 3, 3);
	part.Shape = Enum.PartType.Ball;
	part.CFrame = new CFrame(position);
	part.Color = color;
	part.Material = Enum.Material.Neon;
	part.Transparency = 0.4;
	part.Parent = parent;
	return part;
};

const zoneColor = (zoneId: number): Color3 => {
	const palette = [
		Color3.fromRGB(68, 190, 255),
		Color3.fromRGB(167, 106, 255),
		Color3.fromRGB(255, 172, 66),
		Color3.fromRGB(81, 246, 207),
		Color3.fromRGB(255, 84, 117),
		Color3.fromRGB(120, 196, 255),
		Color3.fromRGB(255, 210, 96),
		Color3.fromRGB(255, 88, 196),
		Color3.fromRGB(76, 255, 194),
		Color3.fromRGB(175, 119, 255),
	];
	return (palette[(zoneId - 1) % palette.size()] as Color3 | undefined) ?? palette[0];
};

const renderZoneScenery = (model: Model, base: BasePart, zoneId: number) => {
	clearScenery(model);
	const container = new Instance("Folder");
	container.Name = "Scenery";
	container.Parent = model;

	const center = base.CFrame.Position;
	const color = zoneColor(zoneId);
	const radius = math.max(PLOT_SIZE_X, PLOT_SIZE_Z) * 0.8;

	if (zoneId === 1) {
		for (let i = 1; i <= 4; i++) {
			const angle = (i - 1) * math.pi * 0.5;
			const pos = center.add(new Vector3(math.cos(angle) * radius, 6, math.sin(angle) * radius));
			addRock(container, pos, Color3.fromRGB(120, 130, 150), new Vector3(5, 5, 5));
		}
	} else if (zoneId === 2) {
		for (let i = 1; i <= 5; i++) {
			const angle = (i - 1) * math.pi * 0.4;
			const pos = center.add(new Vector3(math.cos(angle) * radius, 4, math.sin(angle) * radius));
			addCrystal(container, pos, color, 8 + i * 2);
		}
	} else if (zoneId === 3) {
		for (let i = 1; i <= 3; i++) {
			const angle = (i - 1) * math.pi * 0.33;
			const pos = center.add(new Vector3(math.cos(angle) * radius, 2, math.sin(angle) * radius));
			addRing(container, pos, color);
		}
	} else if (zoneId === 4) {
		for (let i = 1; i <= 4; i++) {
			const angle = (i - 1) * math.pi * 0.5;
			const pos = center.add(new Vector3(math.cos(angle) * radius, 8, math.sin(angle) * radius));
			addOrb(container, pos, color);
		}
	} else {
		for (let i = 1; i <= 4; i++) {
			const angle = (i - 1) * math.pi * 0.5 + zoneId * 0.4;
			const pos = center.add(
				new Vector3(math.cos(angle) * radius, 6 + (i % 2) * 4, math.sin(angle) * radius),
			);
			addOrb(container, pos, color);
		}
	}
};

// `type(profile) == "table" and tonumber(x) or fallback`
const profileNumber = (profile: unknown, read: (profile: Dict) => unknown, fallback: number): number => {
	if (!isTable(profile)) {
		return fallback;
	}
	return num(read(profile)) ?? fallback;
};
const domainRankOf = (profile: unknown): number =>
	profileNumber(profile, (p) => (isTable(p.Domain) ? p.Domain.Rank : undefined), 0);

@Service({ loadOrder: 1 })
export class WorldService {
	_interactionHandler: unknown = undefined;
	_plots = new Map<Player, Model>();
	// what each plot was last drawn from; an unchanged plot is not torn down and rebuilt
	_plotLooks = new Map<Model, string>();
	_plotIndex = new Map<Player, number>();
	_folder: Folder | undefined = undefined;

	Start() {
		const oldWorld = Workspace.FindFirstChild("AstralForgeWorld");
		if (oldWorld) {
			oldWorld.Destroy();
		}

		const folder = new Instance("Folder");
		folder.Name = "AstralForgeWorld";
		folder.Parent = Workspace;
		this._folder = folder;

		const base = new Instance("Part");
		base.Name = "WorldBase";
		base.Anchored = true;
		base.CanCollide = true;
		base.Size = new Vector3(2048, 8, 2048);
		base.Position = new Vector3(0, BASE_Y - 6, 0);
		base.Material = Enum.Material.Slate;
		base.Color = Color3.fromRGB(28, 30, 36);
		base.TopSurface = Enum.SurfaceType.Smooth;
		base.BottomSurface = Enum.SurfaceType.Smooth;
		base.Parent = folder;
	}

	SetInteractionHandler(handler: unknown) {
		this._interactionHandler = handler;
	}

	CreatePlot(player: Player, profile: unknown) {
		if (!this._folder) {
			return undefined;
		}
		const keptIndex = this._plotIndex.get(player);
		if (this._plots.get(player)) {
			this.RemovePlot(player, true);
		}

		let index = keptIndex;
		if (index === undefined) {
			const used = new Set<number>();
			for (const [, occupied] of this._plotIndex) {
				used.add(occupied);
			}
			index = 0;
			while (used.has(index)) {
				index += 1;
			}
			this._plotIndex.set(player, index);
		}

		const model = new Instance("Model");
		model.Name = "Plot_" + player.Name;

		const base = createBasePlate("Base");
		base.Parent = model;
		model.PrimaryPart = base;

		const profileZone = profileNumber(profile, (p) => p.Zone, 1);
		const rebirths = profileNumber(profile, (p) => p.Rebirths, 0);
		const domainRank = domainRankOf(profile);

		let color = zoneColor(profileZone);
		if (rebirths > 0) {
			color = color.Lerp(Color3.fromRGB(255, 255, 255), math.min(0.3, rebirths * 0.02));
		}
		base.Color = color;

		const position = gridPosition(index);
		base.CFrame = new CFrame(position);

		if (domainRank > 0) {
			const pillar = new Instance("Part");
			pillar.Name = "DomainPillar";
			pillar.Anchored = true;
			pillar.CanCollide = false;
			pillar.Size = new Vector3(6, 8 + domainRank * 2, 6);
			pillar.CFrame = new CFrame(position.add(new Vector3(0, 6 + domainRank, 0)));
			pillar.Color = Color3.fromRGB(255, 88, 196);
			pillar.Material = Enum.Material.Neon;
			pillar.Transparency = 0.4;
			pillar.Parent = model;
		}

		renderMachineVisuals(model, base, profile);
		renderZoneScenery(model, base, profileZone);
		attachCollectPrompt(base, player, this._interactionHandler);

		model.Parent = this._folder;
		this._plots.set(player, model);
		return model;
	}

	RefreshPlot(player: Player, profile: unknown) {
		const plot = this._plots.get(player);
		if (!plot) {
			return;
		}
		const base = plot.FindFirstChild("Base") as Part | undefined;
		if (!base) {
			return;
		}

		const profileZone = profileNumber(profile, (p) => p.Zone, 1);
		const rebirths = profileNumber(profile, (p) => p.Rebirths, 0);
		const domainRank = domainRankOf(profile);
		let look = tostring(profileZone) + "|" + tostring(rebirths) + "|" + tostring(domainRank) + "|";
		const machinesNow = isTable(profile) ? profile.Machines : undefined;
		if (isTable(machinesNow)) {
			for (const [machineId, level] of pairs(machinesNow)) {
				look += tostring(machineId) + "=" + tostring(level) + ";";
			}
		} else {
			look += "none";
		}
		if (
			this._plotLooks.get(plot) === look &&
			plot.FindFirstChild("Scenery") !== undefined &&
			(!isTable(machinesNow) || plot.FindFirstChild("Machines") !== undefined)
		) {
			return;
		}
		this._plotLooks.set(plot, look);

		let color = zoneColor(profileZone);
		if (rebirths > 0) {
			color = color.Lerp(Color3.fromRGB(255, 255, 255), math.min(0.3, rebirths * 0.02));
		}
		base.Color = color;

		const existingPillar = plot.FindFirstChild("DomainPillar");
		if (existingPillar) {
			existingPillar.Destroy();
		}

		if (domainRank > 0) {
			const pillar = new Instance("Part");
			pillar.Name = "DomainPillar";
			pillar.Anchored = true;
			pillar.CanCollide = false;
			pillar.Size = new Vector3(6, 8 + domainRank * 2, 6);
			pillar.CFrame = base.CFrame.mul(new CFrame(0, 6 + domainRank, 0));
			pillar.Color = Color3.fromRGB(255, 88, 196);
			pillar.Material = Enum.Material.Neon;
			pillar.Transparency = 0.4;
			pillar.Parent = plot;
		}

		renderMachineVisuals(plot, base, profile);
		renderZoneScenery(plot, base, profileZone);
	}

	TeleportToPlot(player: Player) {
		const plot = this._plots.get(player);
		if (!plot) {
			return;
		}
		const base = plot.PrimaryPart;
		if (!base) {
			return;
		}
		const character = player.Character;
		if (!character) {
			return;
		}
		const humanoidRootPart = character.FindFirstChild("HumanoidRootPart") as BasePart | undefined;
		if (!humanoidRootPart) {
			return;
		}
		humanoidRootPart.CFrame = new CFrame(base.Position.add(new Vector3(0, 8, 0)));
	}

	GetPlotPosition(player: Player): Vector3 {
		const plot = this._plots.get(player);
		if (plot && plot.PrimaryPart) {
			return plot.PrimaryPart.Position;
		}
		return Vector3.zero;
	}

	RemovePlot(player: Player, keepSlot?: boolean) {
		const plot = this._plots.get(player);
		if (plot) {
			this._plotLooks.delete(plot);
			plot.Destroy();
		}
		this._plots.delete(player);
		if (!keepSlot) {
			this._plotIndex.delete(player);
		}
	}
}

