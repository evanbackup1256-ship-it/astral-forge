// Purpose: public equipped-artifact companion and nameplate, without orbiting
// shards, particle wakes or world lights. Reads server-replicated attributes.
// Reads the EquippedArtifact* attributes replicated by GameService:_syncLeaderstats.
// Owner: presentation. Dependencies: Shared/ElementSprites. Review: 2026-10-09.

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const TweenService = game.GetService("TweenService");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
import { isReducedMotion } from "./MotionPreference";
const Workspace = game.GetService("Workspace");

const astral = ReplicatedStorage.WaitForChild("AstralForge");

interface ElementSpritesApi {
	FRAME: number;
	FRAMERATE: number;
	COUNT: number;
	COLUMNS: number;
	sheet(this: void, element?: string): { Image: string } | undefined;
}
const ElementSprites = require(astral.WaitForChild("Shared").WaitForChild("ElementSprites") as ModuleScript) as ElementSpritesApi;

interface ThemeApi {
	Base: { void: Color3; creamSoft: Color3 };
}
const Theme = require(astral.WaitForChild("Shared").WaitForChild("ForgeTheme") as ModuleScript) as ThemeApi;

interface ArtifactPresenceApi {
	attach(this: void): () => void;
}

interface ArtifactInfo {
	Id: string;
	Name: string;
	Element: unknown;
	Rarity: string;
	Level: number;
	Color: Color3;
	Effect: unknown;
}

interface Rig {
	id: string;
	root: BasePart;
	color: Color3;
	instances: Instance[];
	glyph?: ImageLabel;
	plate?: BillboardGui;
}

const DRAW_DISTANCE = 140;
const MAX_ANIMATED_COMPANIONS = 12;
const ATTRS = [
	"EquippedArtifact",
	"EquippedArtifactName",
	"EquippedArtifactElement",
	"EquippedArtifactRarity",
	"EquippedArtifactLevel",
	"EquippedArtifactColor",
	"EquippedArtifactEffect",
];

function read(player: Player): ArtifactInfo | undefined {
	const id = player.GetAttribute("EquippedArtifact");
	if (!typeIs(id, "string") || id === "") {
		return undefined;
	}
	const color = player.GetAttribute("EquippedArtifactColor");
	const level = player.GetAttribute("EquippedArtifactLevel");
	const name = player.GetAttribute("EquippedArtifactName");
	return {
		Id: id,
		Name: typeIs(name, "string") && name !== "" ? name : id,
		Element: player.GetAttribute("EquippedArtifactElement"),
		Rarity: tostring(player.GetAttribute("EquippedArtifactRarity") ?? "COMMON"),
		Level: typeIs(level, "number") ? math.max(1, math.floor(level)) : 1,
		Color: typeIs(color, "Color3") ? color : Color3.fromRGB(240, 212, 140),
		Effect: player.GetAttribute("EquippedArtifactEffect"),
	};
}

function lighten(color: Color3, amount: number): Color3 {
	return color.Lerp(new Color3(1, 1, 1), amount);
}

function visibleRig(rig: Rig, camera: Camera | undefined): boolean {
	const plate = rig.plate;
	const root = rig.root;
	if (
		camera === undefined ||
		root === undefined ||
		root.Parent === undefined ||
		plate === undefined ||
		!plate.Enabled ||
		plate.Adornee === undefined ||
		plate.Adornee.Parent === undefined
	) {
		return false;
	}
	const adornee = plate.Adornee as BasePart;
	const position = adornee.Position.add(plate.StudsOffsetWorldSpace);
	const distance = position.sub(camera.CFrame.Position).Magnitude;
	if (distance > math.min(DRAW_DISTANCE, plate.MaxDistance)) {
		return false;
	}
	const [projected] = camera.WorldToViewportPoint(position);
	const viewport = camera.ViewportSize;
	return projected.Z > 0 && projected.X >= -120 && projected.X <= viewport.X + 120 && projected.Y >= -70 && projected.Y <= viewport.Y + 70;
}

// nameplate serif (the closest Roblox serif to the design's Cinzel)
const PLATE_SERIF = new Font("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold);

function nameplate(info: ArtifactInfo, adornee: BasePart): [BillboardGui, ImageLabel, boolean] {
	const gui = new Instance("BillboardGui");
	gui.Name = "ArtifactPlate";
	gui.Adornee = adornee;
	gui.AlwaysOnTop = false;
	gui.LightInfluence = 0;
	gui.MaxDistance = 60;
	gui.Size = UDim2.fromOffset(240, 70);
	gui.StudsOffsetWorldSpace = new Vector3(0, 3.6, 0);
	gui.ResetOnSpawn = false;

	// the companion's elemental light is lit into its own frames; nothing plays behind it
	const sheet = ElementSprites.sheet(info.Element as string);
	const glyph = new Instance("ImageLabel");
	glyph.Name = "Glyph";
	glyph.BackgroundTransparency = 1;
	glyph.Size = UDim2.fromOffset(64, 64);
	glyph.Position = UDim2.fromOffset(0, 3);
	glyph.ImageColor3 = new Color3(1, 1, 1);
	glyph.ZIndex = 2;
	if (sheet !== undefined) {
		glyph.Image = sheet.Image;
		glyph.ImageRectSize = new Vector2(ElementSprites.FRAME, ElementSprites.FRAME);
		glyph.ImageRectOffset = new Vector2(0, 0);
	}
	glyph.Parent = gui;

	const title = new Instance("TextLabel");
	title.Name = "Title";
	title.BackgroundTransparency = 1;
	title.Position = UDim2.fromOffset(70, 12);
	title.Size = new UDim2(1, -70, 0, 22);
	title.FontFace = PLATE_SERIF;
	title.TextScaled = true;
	title.TextXAlignment = Enum.TextXAlignment.Left;
	title.TextColor3 = lighten(info.Color, 0.25);
	title.TextStrokeColor3 = Theme.Base.void;
	title.TextStrokeTransparency = 0.35;
	title.Text = string.upper(info.Name);
	title.ZIndex = 3;
	title.Parent = gui;
	// 2px black drop under the serif name
	const drop = title.Clone();
	drop.Name = "TitleDrop";
	drop.Position = UDim2.fromOffset(72, 14);
	drop.TextColor3 = new Color3(0, 0, 0);
	drop.TextStrokeTransparency = 1;
	drop.TextTransparency = 0.25;
	drop.ZIndex = 2;
	drop.Parent = gui;

	const detail = new Instance("TextLabel");
	detail.Name = "Detail";
	detail.BackgroundTransparency = 1;
	detail.Position = UDim2.fromOffset(70, 36);
	detail.Size = new UDim2(1, -70, 0, 26);
	detail.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold);
	detail.TextScaled = true;
	detail.TextWrapped = true;
	detail.TextXAlignment = Enum.TextXAlignment.Left;
	detail.TextColor3 = Theme.Base.creamSoft;
	detail.TextStrokeColor3 = Theme.Base.void;
	detail.TextStrokeTransparency = 0.45;
	const effect = typeIs(info.Effect, "string") && info.Effect !== "" ? ` · ${info.Effect}` : "";
	detail.Text = `${string.upper(info.Rarity)} LV${info.Level}${effect}`;
	detail.Parent = gui;
	return [gui, glyph, sheet !== undefined];
}

function attach(): () => void {
	const folder = new Instance("Folder");
	folder.Name = "ArtifactPresence";
	folder.Parent = Workspace;

	const rigs = new Map<Player, Rig>();
	const watchers = new Map<Player, RBXScriptConnection[]>();
	const connections: RBXScriptConnection[] = [];
	let spriteClock = 0;
	let spriteFrame = 0;
	let alive = true;
	const refreshJobs = new Map<Player, { announce: boolean; job: thread }>();
	const rigBuilds = new Map<Player, object>();

	function clearRig(player: Player) {
		rigBuilds.delete(player);
		const rig = rigs.get(player);
		if (rig === undefined) {
			return;
		}
		rigs.delete(player);
		for (const instance of rig.instances) {
			instance.Destroy();
		}
	}

	function burst(rig: Rig) {
		if (isReducedMotion() || rig.glyph === undefined || rig.glyph.Parent === undefined) {
			return;
		}
		rig.glyph.ImageTransparency = 1;
		TweenService.Create(rig.glyph, new TweenInfo(0.25, Enum.EasingStyle.Quad), { ImageTransparency: 0 }).Play();
	}

	function buildRig(player: Player, announce: boolean) {
		if (!alive || watchers.get(player) === undefined) {
			return;
		}
		clearRig(player);
		const info = read(player);
		const character = player.Character;
		const root = character?.FindFirstChild("HumanoidRootPart") as BasePart | undefined;
		const head = character?.FindFirstChild("Head") as BasePart | undefined;
		if (info === undefined || root === undefined) {
			return;
		}
		const buildToken = {};
		rigBuilds.set(player, buildToken);
		const rig: Rig = {
			id: info.Id,
			root,
			color: info.Color,
			instances: [],
		};

		const [plate, glyph, animated] = nameplate(info, (head ?? root)!);
		plate.Parent = folder;
		rig.instances.push(plate);
		rig.glyph = animated ? glyph : undefined;
		rig.plate = plate;

		if (
			rigBuilds.get(player) !== buildToken ||
			!alive ||
			watchers.get(player) === undefined ||
			player.Parent === undefined ||
			player.Character !== character ||
			player.GetAttribute("EquippedArtifact") !== info.Id
		) {
			for (const instance of rig.instances) {
				instance.Destroy();
			}
			return;
		}
		rigs.set(player, rig);
		if (announce) {
			burst(rig);
		}
	}

	function watch(player: Player) {
		const list: RBXScriptConnection[] = [];
		watchers.set(player, list);
		let lastId = player.GetAttribute("EquippedArtifact");
		function refresh(announce: boolean) {
			const pending = refreshJobs.get(player);
			if (pending !== undefined) {
				pending.announce = pending.announce || announce;
				return;
			}
			const newPending = { announce, job: undefined as unknown as thread };
			refreshJobs.set(player, newPending);
			newPending.job = task.defer(() => {
				refreshJobs.delete(player);
				buildRig(player, newPending.announce);
			});
		}
		// EquippedArtifact is written last on the server, so the other fields are already current
		list.push(
			player.GetAttributeChangedSignal("EquippedArtifact").Connect(() => {
				const nextId = player.GetAttribute("EquippedArtifact");
				const changed = nextId !== lastId && typeIs(nextId, "string") && nextId !== "";
				lastId = nextId;
				refresh(changed);
			}),
		);
		for (const attr of ATTRS) {
			if (attr !== "EquippedArtifact") {
				list.push(
					player.GetAttributeChangedSignal(attr).Connect(() => {
						const rig = rigs.get(player);
						if (rig !== undefined && rig.id === player.GetAttribute("EquippedArtifact")) {
							refresh(false);
						}
					}),
				);
			}
		}
		list.push(
			player.CharacterAdded.Connect((character) => {
				character.WaitForChild("HumanoidRootPart", 10);
				character.WaitForChild("Head", 5);
				if (alive && player.Parent !== undefined && player.Character === character) {
					buildRig(player, false);
				}
			}),
		);
		list.push(
			player.CharacterRemoving.Connect(() => {
				clearRig(player);
			}),
		);
		if (player.Character !== undefined) {
			const character = player.Character;
			task.spawn(() => {
				character.WaitForChild("HumanoidRootPart", 10);
				if (alive && player.Character === character) {
					buildRig(player, false);
				}
			});
		}
	}

	function unwatch(player: Player) {
		const pending = refreshJobs.get(player);
		if (pending !== undefined) {
			task.cancel(pending.job);
			refreshJobs.delete(player);
		}
		clearRig(player);
		const list = watchers.get(player);
		watchers.delete(player);
		if (list !== undefined) {
			for (const connection of list) {
				connection.Disconnect();
			}
		}
	}

	for (const player of Players.GetPlayers()) {
		watch(player);
	}
	connections.push(Players.PlayerAdded.Connect(watch));
	connections.push(Players.PlayerRemoving.Connect(unwatch));

	const frameStep = 1 / ElementSprites.FRAMERATE;
	const grid = ElementSprites.FRAME;
	connections.push(
		RunService.RenderStepped.Connect((dt) => {
			const camera = Workspace.CurrentCamera;
			spriteClock += dt;
			let advance = false;
			if (spriteClock >= frameStep) {
				const frames = math.floor(spriteClock / frameStep);
				spriteClock %= frameStep;
				spriteFrame = (spriteFrame + frames) % ElementSprites.COUNT;
				advance = true;
			}
			if (!advance || isReducedMotion()) {
				return;
			}
			const offset = new Vector2((spriteFrame % ElementSprites.COLUMNS) * grid, math.floor(spriteFrame / ElementSprites.COLUMNS) * grid);
			let animated = 0;
			for (const [, rig] of rigs) {
				if (animated < MAX_ANIMATED_COMPANIONS && rig.glyph !== undefined && visibleRig(rig, camera)) {
					animated += 1;
					rig.glyph.ImageRectOffset = offset;
				}
			}
		}),
	);

	return () => {
		alive = false;
		for (const connection of connections) {
			connection.Disconnect();
		}
		for (const player of Players.GetPlayers()) {
			unwatch(player);
		}
		for (const [player] of watchers) {
			unwatch(player);
		}
		folder.Destroy();
	};
}

const ArtifactPresence: ArtifactPresenceApi = {
	attach,
};

export = ArtifactPresence;
