// Studio-only debug overlay (F8) drawn with the vendored egooe immediate-mode UI.
const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const Stats = game.GetService("Stats");
const UserInputService = game.GetService("UserInputService");

const HOST_NAME = "AstralForgeEgooE";

interface Clickable {
	clicked(): boolean;
}
interface WindowHandle {
	closed(): boolean;
}
interface Egooe {
	new: (this: void, layer: Instance) => unknown;
	start: (this: void, node: unknown, body: () => void) => void;
	window: (this: void, options: Record<string, unknown>, body: () => void) => WindowHandle;
	heading: (this: void, text: string) => void;
	separator: (this: void) => void;
	label: (this: void, text: string) => void;
	space: (this: void) => void;
	checkbox: (this: void, text: string, options: { checked: boolean }) => Clickable;
	button: (this: void, text: string) => Clickable;
	demoWindow: (this: void) => void;
}

function loadEgooe(): Egooe | undefined {
	const include = ReplicatedStorage.FindFirstChild("rbxts_include");
	const modules = include?.FindFirstChild("node_modules");
	const scope = modules?.FindFirstChild("@rbxts");
	const pack = scope?.FindFirstChild("egooe");
	const out = pack?.FindFirstChild("out");
	if (out === undefined || !out.IsA("ModuleScript")) {
		return undefined;
	}
	const [ok, loaded] = pcall(() => require(out));
	if (!ok) {
		warn(`[WARN] [EGOOE] couldn't load studio overlay: ${tostring(loaded)}`);
		return undefined;
	}
	return loaded as Egooe;
}

function startEgooeHost(playerGui?: Instance): () => void {
	if (!RunService.IsStudio()) {
		return () => undefined;
	}
	const hostGui = playerGui ?? Players.LocalPlayer.FindFirstChildOfClass("PlayerGui");
	if (hostGui === undefined) {
		return () => undefined;
	}
	const stale = hostGui.FindFirstChild(HOST_NAME);
	if (stale !== undefined) {
		stale.Destroy();
	}
	const layer = new Instance("ScreenGui");
	layer.Name = HOST_NAME;
	layer.ResetOnSpawn = false;
	layer.IgnoreGuiInset = true;
	layer.DisplayOrder = 240;
	layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	layer.Parent = hostGui;
	let api: Egooe | undefined;
	let node: unknown;
	let open = false;
	let showDemo = false;
	let frames = 0;
	let fps = 60;
	let sampleAt = os.clock();
	let heartbeat: RBXScriptConnection | undefined;
	const paint = (dt: number) => {
		if (api === undefined) {
			return undefined;
		}
		const ui = api;
		frames += 1;
		const now = os.clock();
		if (now - sampleAt >= 0.4) {
			fps = frames / math.max(0.001, now - sampleAt);
			frames = 0;
			sampleAt = now;
		}
		const player = Players.LocalPlayer;
		ui.start(node, () => {
			if (!open) {
				return undefined;
			}
			const handle = ui.window(
				{
					title: "Astral Forge",
					closable: true,
					minimizable: true,
					movable: true,
					resizable: true,
					size: new Vector2(340, 300),
					position: new Vector2(18, 86),
				},
				() => {
					ui.heading("Studio debug");
					ui.separator();
					ui.label(`FPS     ${string.format("%.0f", fps)}  (${string.format("%.1f", dt * 1000)} ms)`);
					ui.label(`Player  ${player.Name}  (${player.UserId})`);
					ui.label(`Mem     ${string.format("%.1f", Stats.GetTotalMemoryUsageMb())} MB`);
					ui.label(`Inst    ${Stats.InstanceCount}`);
					ui.space();
					ui.label("F8 toggles this overlay. It is not the game UI.");
					ui.separator();
					const gallery = ui.checkbox("Widget gallery", { checked: showDemo });
					if (gallery.clicked()) {
						showDemo = !showDemo;
					}
					if (ui.button("Close overlay").clicked()) {
						open = false;
					}
				},
			);
			if (handle.closed()) {
				open = false;
			}
			if (showDemo) {
				ui.demoWindow();
			}
		});
	};
	const ensureHeartbeat = () => {
		if (heartbeat !== undefined) {
			return undefined;
		}
		heartbeat = RunService.Heartbeat.Connect(paint);
	};
	const stopHeartbeat = () => {
		heartbeat?.Disconnect();
		heartbeat = undefined;
	};
	const setOpen = (shouldOpen: boolean) => {
		if (shouldOpen && api === undefined) {
			api = loadEgooe();
			if (api === undefined) {
				return undefined;
			}
			node = api.new(layer);
		}
		open = shouldOpen && api !== undefined;
		if (open) {
			ensureHeartbeat();
		} else {
			stopHeartbeat();
			for (const child of layer.GetChildren()) {
				child.Destroy();
			}
		}
	};
	const input = UserInputService.InputBegan.Connect((inputObject, processed) => {
		if (processed) {
			return undefined;
		}
		if (inputObject.KeyCode !== Enum.KeyCode.F8) {
			return undefined;
		}
		setOpen(!open);
	});
	return () => {
		input.Disconnect();
		stopHeartbeat();
		layer.Destroy();
	};
}

export { startEgooeHost };
