// Interactive world panel; Roblox owns headset tracking and native laser input.
const VRService = game.GetService("VRService");
const RunService = game.GetService("RunService");
const ContextActionService = game.GetService("ContextActionService");
const Workspace = game.GetService("Workspace");

interface VRHost {
	active: boolean;
	disposed: boolean;
	connections: RBXScriptConnection[];
	container?: Frame;
	overlay?: Frame;
	dispose: () => void;
	recenter?: () => void;
}

const VRInterface = {
	Width: 1440,
	Height: 960,

	mount(this: void, playerGui: Instance, screen: ScreenGui, changed?: (host: VRHost) => void, forcePreview?: boolean): VRHost {
		const isVR = VRService.VREnabled || forcePreview === true;
		const host: VRHost = {
			active: false,
			disposed: false,
			connections: [],
			dispose: () => {
				host.disposed = true;
				for (const c of host.connections) {
					pcall(() => c.Disconnect());
				}
				host.connections.clear();
			},
		};
		if (!isVR) {
			return host;
		}
		const surface = new Instance("SurfaceGui");
		surface.Name = "AstralForgeVR";
		surface.Face = Enum.NormalId.Front;
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize;
		surface.CanvasSize = new Vector2(VRInterface.Width, VRInterface.Height);
		surface.AlwaysOnTop = true;
		surface.LightInfluence = 0;
		surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		surface.Enabled = false;
		surface.ResetOnSpawn = false;
		surface.Parent = playerGui;
		const part = new Instance("Part");
		part.Name = "AstralForgeVRPanel";
		part.Anchored = true;
		part.CanCollide = false;
		part.CanTouch = false;
		part.CanQuery = true;
		part.Transparency = 1;
		part.CastShadow = false;
		part.Size = new Vector3(6, 4, 0.05);
		part.Parent = Workspace;
		surface.Adornee = part;
		const content = new Instance("Frame");
		content.Name = "Content";
		content.Size = new UDim2(1, 0, 1, -64);
		content.Position = UDim2.fromOffset(0, 0);
		content.BackgroundColor3 = Color3.fromRGB(14, 11, 20);
		content.BorderSizePixel = 0;
		content.ClipsDescendants = true;
		content.Parent = surface;
		host.container = content;
		const overlay = new Instance("Frame");
		overlay.Name = "Overlay";
		overlay.Size = UDim2.fromScale(1, 1);
		overlay.BackgroundTransparency = 1;
		overlay.ZIndex = 1000;
		overlay.Parent = surface;
		host.overlay = overlay;
		const header = new Instance("TextButton");
		header.Name = "VRRecenter";
		header.Size = new UDim2(1, 0, 0, 64);
		header.Position = new UDim2(0, 0, 1, -64);
		header.BackgroundColor3 = Color3.fromRGB(27, 23, 39);
		header.TextColor3 = Color3.fromRGB(230, 239, 255);
		header.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold);
		header.TextSize = 23;
		header.Text = "ASTRAL FORGE  ·  RECENTER PANEL  ·  L3 recenter / R3 show or hide";
		header.Selectable = true;
		header.Parent = surface;
		const previousLaser = VRService.LaserPointer;
		const previousModels = VRService.ControllerModels;
		let basePosition: Vector3 | undefined;
		const recenter = () => {
			const camera = Workspace.CurrentCamera;
			if (!camera) {
				return;
			}
			const head = camera.GetRenderCFrame();
			const scale = math.max(0.1, camera.HeadScale);
			const position = head.Position.add(head.LookVector.mul(6 * scale));
			part.Size = new Vector3(6, 4, 0.05).mul(scale);
			const up = math.abs(head.LookVector.Y) > 0.95 ? head.UpVector : Vector3.yAxis;
			part.CFrame = CFrame.lookAt(position, head.Position, up);
			basePosition = camera.CFrame.Position;
		};
		host.recenter = recenter;
		const action = (name: string, state: Enum.UserInputState) => {
			if (state !== Enum.UserInputState.Begin) {
				return Enum.ContextActionResult.Pass;
			}
			if (name === "AFVRRecenter") {
				recenter();
			} else {
				surface.Enabled = !surface.Enabled;
			}
			return Enum.ContextActionResult.Sink;
		};
		const sync = () => {
			const active = VRService.VREnabled || forcePreview === true;
			if (active === host.active) {
				return;
			}
			host.active = active;
			surface.Enabled = active;
			screen.Enabled = !active;
			Workspace.SetAttribute("AstralForgeVRCanvasWidth", active ? VRInterface.Width : undefined);
			Workspace.SetAttribute("AstralForgeVRCanvasHeight", active ? VRInterface.Height - 64 : undefined);
			if (active) {
				pcall(() => {
					VRService.LaserPointer = Enum.VRLaserPointerMode.DualPointer;
					VRService.ControllerModels = Enum.VRControllerModelMode.Transparent;
				});
				recenter();
				ContextActionService.BindActionAtPriority("AFVRRecenter", action, false, 3000, Enum.KeyCode.ButtonL3);
				ContextActionService.BindActionAtPriority("AFVRToggle", action, false, 3000, Enum.KeyCode.ButtonR3);
			} else {
				ContextActionService.UnbindAction("AFVRRecenter");
				ContextActionService.UnbindAction("AFVRToggle");
				pcall(() => {
					VRService.LaserPointer = previousLaser;
					VRService.ControllerModels = previousModels;
				});
			}
			if (changed) {
				changed(host);
			}
		};
		host.connections.push(header.Activated.Connect(recenter));
		host.connections.push(VRService.GetPropertyChangedSignal("VREnabled").Connect(sync));
		host.connections.push(
			RunService.RenderStepped.Connect(() => {
				if (!host.active) {
					return;
				}
				const camera = Workspace.CurrentCamera;
				if (!camera || !basePosition) {
					return;
				}
				// Follow locomotion only. A head turn leaves the panel comfortably in place.
				const delta = camera.CFrame.Position.sub(basePosition);
				part.CFrame = part.CFrame.add(delta);
				basePosition = camera.CFrame.Position;
			}),
		);
		host.dispose = () => {
			if (host.disposed) {
				return;
			}
			host.disposed = true;
			for (const connection of host.connections) {
				connection.Disconnect();
			}
			ContextActionService.UnbindAction("AFVRRecenter");
			ContextActionService.UnbindAction("AFVRToggle");
			Workspace.SetAttribute("AstralForgeVRCanvasWidth", undefined);
			Workspace.SetAttribute("AstralForgeVRCanvasHeight", undefined);
			pcall(() => {
				VRService.LaserPointer = previousLaser;
				VRService.ControllerModels = previousModels;
			});
			surface.Destroy();
			part.Destroy();
			if (screen.Parent) {
				screen.Enabled = true;
			}
		};
		sync();
		return host;
	},
};

export = VRInterface;
