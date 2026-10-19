import React from "@rbxts/react";
import { subscribeContinuous } from "../MotionKit/motion";

const h = React.createElement as unknown as (component: unknown, props?: object, ...children: unknown[]) => React.Element;

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const AstralForge = script.Parent!.Parent!;

export interface CrateSkin {
	Id: string;
	Family?: unknown;
	Accent?: unknown;
	Glow?: unknown;
	[key: string]: unknown;
}
interface ShopCatalogModule {
	skin(this: void, id: unknown): CrateSkin | undefined;
	DEFAULT_SKIN: string;
}
const ShopCatalog = (
	require(ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared").WaitForChild("SharedData") as ModuleScript) as (
		name: string,
	) => unknown
)("ShopCatalog") as ShopCatalogModule;

interface LidPiece {
	part: BasePart;
	offset: CFrame;
}
interface CrateDetailsModule {
	bodyMaterial(this: void, family: unknown): Enum.Material;
	family(this: void, id: string, family: unknown): unknown;
	build(this: void, model: Model, body: BasePart, accent: Color3, id: string, family: unknown): void;
	buildLid(this: void, model: Model, lid: BasePart, accent: Color3, id: string, family: unknown): LidPiece[];
}
const crateDetails = () => require(AstralForge.WaitForChild("CrateDetails") as ModuleScript) as CrateDetailsModule;

const OPEN_ANGLE = 1.95;
const kitListeners = new Set<() => void>();
let kitWatch: RBXScriptConnection | undefined = undefined;

function rgb(value: unknown, fallback: Color3): Color3 {
	if (!typeIs(value, "table")) {
		return fallback;
	}
	const v = value as number[];
	return Color3.fromRGB(v[0] ?? 255, v[1] ?? 255, v[2] ?? 255);
}

export function skinOf(id: unknown): CrateSkin {
	return (ShopCatalog.skin(id) ?? ShopCatalog.skin(ShopCatalog.DEFAULT_SKIN))!;
}

export function kitFolder(): Folder | undefined {
	const folder = ReplicatedStorage.FindFirstChild("CrateKit") ?? ReplicatedStorage.FindFirstChild("PropKit");
	return folder !== undefined && folder.IsA("Folder") ? folder : undefined;
}

export function useKitReady(): number {
	const [ready, setReady] = React.useState(kitFolder() !== undefined ? 1 : 0);
	React.useEffect(() => {
		const listener = () => setReady((revision) => revision + 1);
		kitListeners.add(listener);
		if (kitWatch === undefined) {
			kitWatch = ReplicatedStorage.ChildAdded.Connect((child) => {
				if (child.Name === "PropKit" || child.Name === "CrateKit") {
					for (const each of kitListeners) {
						task.defer(each);
					}
				}
			});
		}
		return () => {
			kitListeners.delete(listener);
		};
	}, [ready]);
	return ready;
}

function inert<T extends BasePart>(part: T): T {
	part.Anchored = true;
	part.CanCollide = false;
	part.CanQuery = false;
	part.CanTouch = false;
	part.CastShadow = false;
	return part;
}

interface CrateScene {
	lid: BasePart;
	lidPieces: LidPiece[];
	lidRest: CFrame;
	hinge: CFrame;
	glow: Part;
	center: Vector3;
}

function buildCrate(model: Model, skinId: string): CrateScene {
	const skin = skinOf(skinId);
	const folder = kitFolder();
	const bodySource = folder && folder.FindFirstChild(`Crate_${skin.Id}_Body`);
	const lidSource = folder && folder.FindFirstChild(`Crate_${skin.Id}_Lid`);
	let body: BasePart;
	let lid: BasePart;
	if (bodySource !== undefined && lidSource !== undefined && bodySource.IsA("MeshPart") && lidSource.IsA("MeshPart")) {
		body = bodySource.Clone();
		lid = lidSource.Clone();
	} else {
		const accent = rgb(skin.Accent, Color3.fromRGB(255, 184, 52));
		const material = crateDetails().bodyMaterial(crateDetails().family(skin.Id, skin.Family));
		body = new Instance("Part");
		body.Size = new Vector3(1.72, 1.04, 1.22);
		body.Color = accent.Lerp(new Color3(0, 0, 0), 0.55);
		body.Material = material;
		lid = new Instance("Part");
		lid.Size = new Vector3(1.8, 0.4, 1.3);
		lid.Color = accent.Lerp(new Color3(0, 0, 0), 0.3);
		lid.Material = material;
	}
	inert(body);
	inert(lid);
	const bodyH = body.Size.Y;
	body.CFrame = new CFrame(0, bodyH / 2, 0);
	body.Parent = model;
	if (bodySource === undefined || lidSource === undefined) {
		crateDetails().build(model, body, rgb(skin.Accent, body.Color), skin.Id, skin.Family);
	}
	const lidRest = new CFrame(0, bodyH + lid.Size.Y / 2 - 0.01, 0);
	lid.CFrame = lidRest;
	lid.Parent = model;
	let lidPieces: LidPiece[] = [];
	if (bodySource === undefined || lidSource === undefined) {
		lidPieces = crateDetails().buildLid(model, lid, rgb(skin.Accent, lid.Color), skin.Id, skin.Family);
	}
	const glow = inert(new Instance("Part"));
	glow.Shape = Enum.PartType.Ball;
	glow.Size = Vector3.one.mul(0.7);
	glow.Material = Enum.Material.Neon;
	glow.Color = rgb(skin.Glow, Color3.fromRGB(255, 220, 160));
	glow.Transparency = 1;
	glow.CFrame = new CFrame(0, bodyH - 0.2, 0);
	glow.Parent = model;
	return {
		lid: lid,
		lidPieces: lidPieces,
		lidRest: lidRest,
		hinge: new CFrame(0, bodyH, lid.Size.Z / 2),
		glow: glow,
		center: new Vector3(0, (bodyH + lid.Size.Y) * 0.46, 0),
	};
}

interface PoseState {
	t: number;
	yaw: number;
	open: number;
	shake: number;
}

export interface CrateModelProps {
	skin?: unknown;
	live?: boolean;
	yaw?: number;
	open?: unknown;
	shake?: unknown;
	spin?: boolean;
	zoom?: number;
	size?: UDim2;
	position?: UDim2;
	anchorPoint?: Vector2;
	ambient?: Color3;
	zIndex?: number;
	layoutOrder?: number;
}

function pose(scene: CrateScene, camera: Camera, state: PoseState, props: CrateModelProps) {
	const zoom = props.zoom ?? 1;
	const distance = 4.6 * zoom;
	const yaw = state.yaw;
	const lift = state.open;
	const angle = lift * OPEN_ANGLE;
	const shake = state.shake;
	const rattle = shake > 0 ? math.sin(state.t * 46) * 0.05 * shake : 0;
	scene.lid.CFrame = scene.hinge
		.mul(CFrame.Angles(angle + math.abs(rattle) * 0.6, 0, 0))
		.mul(scene.hinge.Inverse())
		.mul(scene.lidRest);
	const lidFrame = scene.lid.CFrame;
	for (const piece of scene.lidPieces) {
		piece.part.CFrame = lidFrame.mul(piece.offset);
	}
	scene.glow.Transparency = 1 - math.clamp(lift, 0, 1) * 0.55;
	scene.glow.Size = Vector3.one.mul(0.5 + lift * 0.5);
	const focus = scene.center.add(new Vector3(0, lift * 0.25, 0));
	const eye = focus.add(new Vector3(math.sin(yaw) * distance, distance * 0.42, -math.cos(yaw) * distance));
	camera.CFrame = CFrame.lookAt(eye, focus).mul(CFrame.Angles(0, 0, rattle));
}

export function CrateModel(props: CrateModelProps) {
	const host = React.useRef<ViewportFrame>();
	const propsRef = React.useRef(props);
	propsRef.current = props;
	const kitReady = useKitReady();
	const skinId = skinOf(props.skin).Id;
	const live = props.live !== false;
	React.useEffect(() => {
		const viewport = host.current;
		if (viewport === undefined) {
			return undefined;
		}
		viewport.ClearAllChildren();
		const camera = new Instance("Camera");
		camera.FieldOfView = 30;
		camera.Parent = viewport;
		viewport.CurrentCamera = camera;
		const model = new Instance("Model");
		model.Parent = viewport;
		const scene = buildCrate(model, skinId);
		const first = propsRef.current;
		const state: PoseState = {
			t: 0,
			yaw: first.yaw ?? -0.5,
			open: tonumber(first.open) ?? 0,
			shake: 0,
		};
		pose(scene, camera, state, first);
		if (!live) {
			return () => viewport.ClearAllChildren();
		}
		const release = subscribeContinuous((dt: number) => {
			const now = propsRef.current;
			state.t += dt;
			const base = now.yaw ?? -0.5;
			state.yaw = now.spin ? base + state.t * 0.55 : base + math.sin(state.t * 0.7) * 0.22;
			const target = math.clamp(tonumber(now.open) ?? 0, 0, 1);
			const rate = target > state.open ? 9 : 4;
			state.open += (target - state.open) * (1 - math.exp(-dt * rate));
			state.shake = math.clamp(tonumber(now.shake) ?? 0, 0, 1);
			pose(scene, camera, state, now);
		});
		return () => {
			release();
			viewport.ClearAllChildren();
		};
	}, [skinId, kitReady, live]);
	return h("viewportframe", {
		ref: host,
		Size: props.size ?? UDim2.fromScale(1, 1),
		Position: props.position,
		AnchorPoint: props.anchorPoint,
		BackgroundTransparency: 1,
		BorderSizePixel: 0,
		Ambient: props.ambient ?? (kitReady > 0 ? Color3.fromRGB(200, 194, 208) : Color3.fromRGB(150, 140, 165)),
		LightColor: kitReady > 0 ? Color3.fromRGB(200, 192, 180) : Color3.fromRGB(255, 244, 224),
		LightDirection: new Vector3(-0.5, -0.8, 1),
		ZIndex: props.zIndex,
		LayoutOrder: props.layoutOrder ?? 0,
	});
}

export function kitPiece(name: string, fit?: number): LuaTuple<[MeshPart | undefined, number]> {
	const folder = ReplicatedStorage.FindFirstChild("PropKit");
	const source = folder && folder.FindFirstChild(name);
	if (source === undefined || !source.IsA("MeshPart")) {
		return $tuple(undefined, 1);
	}
	const part = inert(source.Clone());
	const size = part.Size;
	const largest = math.max(size.X, size.Y, size.Z);
	if (fit !== undefined && largest > 1e-3) {
		part.Size = size.mul(fit / largest);
		return $tuple(part, fit / largest);
	}
	return $tuple(part, 1);
}

export function skinAccent(id: unknown) {
	return rgb(skinOf(id).Accent, Color3.fromRGB(255, 184, 52));
}

export function skinGlow(id: unknown) {
	return rgb(skinOf(id).Glow, Color3.fromRGB(255, 220, 160));
}
