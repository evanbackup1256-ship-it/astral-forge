import { Service } from "@flamework/core";
import * as ForgeTheme from "../../../Shared/AstralForge/Shared/ForgeTheme";
import * as PlotLayout from "../../../Shared/AstralForge/Shared/PlotLayout";
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
	part.CastShadow = false;
	part.Size = new Vector3(PLOT_SIZE_X, 4, PLOT_SIZE_Z);
	part.Position = Vector3.zero;
	part.Material = Enum.Material.Metal;
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

// Older builds parented a part per machine. Drop those if a hot reload left them behind.
const dropLegacyVisuals = (model: Instance) => {
	for (const name of ["Machines", "Scenery", "DomainPillar"]) {
		const existing = model.FindFirstChild(name);
		if (existing) {
			existing.Destroy();
		}
	}
};

const colorChannels = (color: unknown): { r: number; g: number; b: number } => {
	if (!typeIs(color, "Color3")) {
		return { r: 200, g: 200, b: 200 };
	}
	return {
		r: math.floor(color.R * 255 + 0.5),
		g: math.floor(color.G * 255 + 0.5),
		b: math.floor(color.B * 255 + 0.5),
	};
};

const rosterFromProfile = (profile: unknown): PlotLayout.MachineMark[] => {
	const machines = isTable(profile) ? profile.Machines : undefined;
	if (!isTable(machines)) {
		return [];
	}
	const entries: PlotLayout.MachineMark[] = [];
	for (const [machineId, level] of pairs(machines)) {
		if (!typeIs(machineId, "string") || !typeIs(level, "number") || level <= 0) {
			continue;
		}
		const machine = machineById[machineId];
		if (!machine) {
			continue;
		}
		const color = colorChannels(machine.Color);
		entries.push({ id: machineId, level, r: color.r, g: color.g, b: color.b });
	}
	return entries;
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

// `type(profile) == "table" and tonumber(x) or fallback`
const profileNumber = (profile: unknown, read: (profile: Dict) => unknown, fallback: number): number => {
	if (!isTable(profile)) {
		return fallback;
	}
	return num(read(profile)) ?? fallback;
};
const domainRankOf = (profile: unknown): number =>
	profileNumber(profile, (p) => (isTable(p.Domain) ? p.Domain.Rank : undefined), 0);

const whole = (value: number, fallback: number): number => {
	if (value !== value || value === math.huge || value === -math.huge) {
		return fallback;
	}
	return math.max(fallback, math.floor(value));
};

// Pads, prompts and a roster string replicate. The parts for machines and scenery do not.
const publishPlot = (looks: Map<Model, string>, model: Model, player: Player, profile: unknown) => {
	const base = model.FindFirstChild("Base") as Part | undefined;
	if (!base) {
		return;
	}
	const zone = whole(profileNumber(profile, (p) => p.Zone, 1), 1);
	const rebirths = whole(profileNumber(profile, (p) => p.Rebirths, 0), 0);
	const domain = whole(domainRankOf(profile), 0);
	const payload = PlotLayout.encodeRoster(rosterFromProfile(profile));
	const look = `${zone}|${rebirths}|${domain}|${payload}`;
	if (looks.get(model) === look) {
		return;
	}
	looks.set(model, look);
	dropLegacyVisuals(model);

	let color = zoneColor(zone);
	if (rebirths > 0) {
		color = color.Lerp(Color3.fromRGB(255, 255, 255), math.min(0.3, rebirths * 0.02));
	}
	base.Color = color;
	model.SetAttribute(PlotLayout.ATTR.zone, zone);
	model.SetAttribute(PlotLayout.ATTR.rebirths, rebirths);
	model.SetAttribute(PlotLayout.ATTR.domain, domain);
	model.SetAttribute(PlotLayout.ATTR.machines, payload);
	model.SetAttribute(PlotLayout.ATTR.owner, player.UserId);
};

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
		base.CastShadow = false;
		base.Size = new Vector3(2048, 8, 2048);
		base.Position = new Vector3(0, BASE_Y - 6, 0);
		base.Material = Enum.Material.Slate;
		base.Color = ForgeTheme.Base.graphite;
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

		const position = gridPosition(index);
		base.CFrame = new CFrame(position);
		publishPlot(this._plotLooks, model, player, profile);
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
		publishPlot(this._plotLooks, plot, player, profile);
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
