import { Service } from "@flamework/core";
import * as ForgeTheme from "../../../Shared/AstralForge/Shared/ForgeTheme";
import { Dict } from "./LuaInterop";

const Workspace = game.GetService("Workspace");

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
	part.Color = ForgeTheme.Base.graphite;
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
	// drawn by the client (PromptStyle): brass key cap plus the action panel
	prompt.Style = Enum.ProximityPromptStyle.Custom;
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

@Service({ loadOrder: 1 })
export class WorldService {
	_interactionHandler: unknown = undefined;
	_plots = new Map<Player, Model>();
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

	CreatePlot(player: Player) {
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
		attachCollectPrompt(base, player, this._interactionHandler);

		model.Parent = this._folder;
		this._plots.set(player, model);
		return model;
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
			plot.Destroy();
		}
		this._plots.delete(player);
		if (!keepSlot) {
			this._plotIndex.delete(player);
		}
	}
}
