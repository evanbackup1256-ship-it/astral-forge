import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";

type Dict = Record<string, unknown>;

interface UILabsLib {
	Choose(this: void, list: defined[], index: number): unknown;
	Slider(this: void, value: number, min: number, max: number, step?: number): unknown;
	CreateReactStory(this: void, info: Dict, render: (props: { controls: Dict }) => React.ReactNode): unknown;
}
interface ViewportInfo {
	scale: number;
	width: number;
	height: number;
	topInset: number;
	bottomInset: number;
	sideInset: number;
	screenWidth: number;
	screenHeight: number;
	keyboardOpen: boolean;
	desktop: boolean;
	tenFoot: boolean;
	compact: boolean;
	tight: boolean;
	short: boolean;
}
interface AutoScale {
	computeViewportScale(this: void, width: number, height: number): number;
	ViewportScaleContext: React.Context<unknown>;
}
interface Theme {
	Palette: Record<string, Color3>;
	Breakpoints: Record<string, number>;
}
interface Kit {
	state: Dict;
	config: Dict;
	dispatch: (action: string, payload?: unknown, callback?: (result: Dict) => void) => void;
	reducedMotion: boolean;
	device: string;
}
interface Issue {
	kind: string;
	path: string;
	detail: string;
}

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const StarterPlayer = game.GetService("StarterPlayer");

const packages = ReplicatedStorage.WaitForChild("rbxts_include").WaitForChild("node_modules").WaitForChild("@rbxts");
const UILabs = require(packages.WaitForChild("ui-labs") as ModuleScript) as UILabsLib;

const client = StarterPlayer.WaitForChild("StarterPlayerScripts").WaitForChild("AstralForge");
const shared = ReplicatedStorage.WaitForChild("AstralForge").WaitForChild("Shared");

const MotionKit = require(client.WaitForChild("MotionKit") as ModuleScript) as (name: string) => unknown;
const CoreKit = require(client.WaitForChild("CoreKit") as ModuleScript) as (name: string) => unknown;
const autoScale = MotionKit("autoScale") as AutoScale;
const theme = CoreKit("theme") as Theme;
const Palette = theme.Palette;
const Breakpoints = theme.Breakpoints;

const DEVICES = [
	"Desktop 1920x1080",
	"Laptop 1366x768",
	"Tablet 1024x768",
	"Phone 390x844",
	"Phone landscape 844x390",
	"Small phone 360x640",
	"Small landscape 640x360",
];

function deviceSize(name: string): Vector2 {
	const [w, h] = (name ?? "").match("(%d+)x(%d+)");
	if (w === undefined) {
		return new Vector2(1366, 768);
	}
	return new Vector2(tonumber(w), tonumber(h));
}

function isPhone(name: string): boolean {
	return (
		(name ?? "").find("hone", 1, true)[0] !== undefined || (name ?? "").find("landscape", 1, true)[0] !== undefined
	);
}

function deviceInsets(name: string) {
	if (name.find("landscape", 1, true)[0] !== undefined) {
		return { top: 0, bottom: 12, side: 44 };
	} else if (isPhone(name)) {
		return { top: 47, bottom: 34, side: 0 };
	}
	return { top: 0, bottom: 0, side: 0 };
}

// The screen the game's layout code would see on that device, as AutoScale computes it.
function viewportInfo(device: string, keyboardOpen?: boolean): ViewportInfo {
	const size = deviceSize(device);
	const insets = deviceInsets(device);
	const width = size.X;
	const height = size.Y;
	const usable = keyboardOpen ? math.floor(height * 0.55) : height;
	return {
		scale: autoScale.computeViewportScale(width, usable),
		width: width,
		height: usable,
		topInset: insets.top,
		bottomInset: keyboardOpen ? 0 : insets.bottom,
		sideInset: insets.side,
		screenWidth: width,
		screenHeight: height,
		keyboardOpen: keyboardOpen === true,
		desktop: !isPhone(device) && width >= 840 && height >= 500,
		tenFoot: false,
		compact: width < Breakpoints.compact,
		tight: width < Breakpoints.tight,
		short: math.min(usable, height) < Breakpoints.short,
	};
}

// A device screen inside the story canvas: the page lays out at the device's real size and the
// whole screen is scaled to fit the preview.
function DeviceFrame(props: { device: string; keyboardOpen?: boolean; children?: React.ReactNode }) {
	const hostRef = React.useRef<Frame>();
	const [fit, setFit] = React.useState(1);
	const info = viewportInfo(props.device, props.keyboardOpen);
	const size = deviceSize(props.device);
	React.useEffect(() => {
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const sync = () => {
			const avail = host.AbsoluteSize;
			if (avail.X > 0 && avail.Y > 0) {
				setFit(math.min(1, (avail.X - 16) / size.X, (avail.Y - 16) / size.Y));
			}
		};
		sync();
		const connection = host.GetPropertyChangedSignal("AbsoluteSize").Connect(sync);
		return () => {
			connection.Disconnect();
		};
	}, [size.X, size.Y]);
	return React.createElement(
		"frame",
		{
			ref: hostRef,
			Size: UDim2.fromScale(1, 1),
			BackgroundColor3: Color3.fromRGB(8, 6, 12),
			BorderSizePixel: 0,
		},
		React.createElement(
			"frame",
			{
				Name: "DeviceScreen",
				Size: UDim2.fromOffset(size.X, size.Y),
				Position: UDim2.fromScale(0.5, 0.5),
				AnchorPoint: new Vector2(0.5, 0.5),
				BackgroundColor3: Palette.void,
				BorderSizePixel: 0,
				ClipsDescendants: true,
			},
			React.createElement("uiscale", { Scale: fit }),
			React.createElement("uistroke", { Color: Palette.lineSoft, Thickness: 2 }),
			React.createElement(
				autoScale.ViewportScaleContext.Provider,
				{ value: info },
				React.createElement(
					"frame",
					{
						Name: "SafeArea",
						Size: new UDim2(1, -info.sideInset * 2, 1, -(info.topInset + info.bottomInset)),
						Position: UDim2.fromOffset(info.sideInset, info.topInset),
						BackgroundTransparency: 1,
						BorderSizePixel: 0,
					},
					props.children,
				),
			),
		),
	);
}

// Shows a render error inside the story instead of a blank canvas.
@React.ReactComponent
class StoryBoundary extends React.Component<{ children?: React.ReactNode }, { message?: string }> {
	static getDerivedStateFromError(this: void, err: unknown) {
		return { message: tostring(err) };
	}
	constructor(props: { children?: React.ReactNode }) {
		super(props);
		this.state = { message: undefined };
	}
	render() {
		if (this.state.message !== undefined) {
			return React.createElement("textlabel", {
				Size: UDim2.fromScale(1, 1),
				BackgroundColor3: Color3.fromRGB(40, 12, 18),
				TextColor3: Color3.fromRGB(255, 200, 200),
				TextWrapped: true,
				TextXAlignment: Enum.TextXAlignment.Left,
				TextYAlignment: Enum.TextYAlignment.Top,
				Font: Enum.Font.Code,
				TextSize: 14,
				Text:
					"This story could not render.\n\n" +
					this.state.message +
					"\n\nPages that read deep server state need a captured snapshot: see src/Stories/README.md.",
			});
		}
		return this.props.children;
	}
}

// Game state for stories: a captured snapshot when one exists, otherwise the hand-built fixture.
function state(save?: string): Dict {
	const captured = script.Parent!.FindFirstChild("StorySnapshot");
	let base: Dict;
	if (captured !== undefined) {
		base = require(captured as ModuleScript) as Dict;
	} else {
		const fixture = require(script.Parent!.WaitForChild("StoryFixture") as ModuleScript) as {
			build(this: void, save: string): Dict;
		};
		base = fixture.build(save ?? "Mid game");
	}
	return table.clone(base);
}

function config(): Dict {
	return require(shared.WaitForChild("GameConfig") as ModuleScript) as Dict;
}

// Records what a story dispatches; answers with the chosen outcome.
function dispatcher(outcome?: string, log?: string[]) {
	return (action: string, payload?: unknown, callback?: (result: Dict) => void) => {
		const line = `dispatch ${action}`;
		if (log !== undefined) {
			log.push(line);
		}
		print("[story]", line, payload);
		if (callback !== undefined) {
			task.delay(0.35, () => {
				if (outcome === "Fail") {
					callback({ ok: false, error: "Story preview: the server said no." });
				} else {
					callback({ ok: true, message: "Story preview: done." });
				}
			});
		}
	};
}

// Controls every story shares.
function controls(extra?: Dict): Dict {
	const result: Dict = {
		Device: UILabs.Choose(DEVICES, 2),
		ReducedMotion: false,
		Save: UILabs.Choose(["New player", "Mid game", "Late game"], 2),
		Dispatch: UILabs.Choose(["Succeed", "Fail"], 1),
	};
	for (const [key, value] of pairs(extra ?? {})) {
		result[key] = value;
	}
	return result;
}

// A React story rendered on a device screen. render(controls, kit) returns the element to show, where
// kit carries state, config, dispatch and reducedMotion for the chosen controls.
function story(info: { name?: string; summary?: string; controls?: Dict }, render: (controls: Dict, kit: Kit) => React.ReactNode) {
	return UILabs.CreateReactStory(
		{
			name: info.name,
			summary: info.summary,
			react: React,
			reactRoblox: ReactRoblox,
			controls: controls(info.controls),
		},
		(props) => {
			const c = props.controls;
			const kit: Kit = {
				state: state(c.Save as string),
				config: config(),
				dispatch: dispatcher(c.Dispatch as string),
				reducedMotion: c.ReducedMotion === true,
				device: c.Device as string,
			};
			return React.createElement(
				DeviceFrame,
				{ device: c.Device as string, keyboardOpen: c.KeyboardOpen === true },
				React.createElement(StoryBoundary, undefined, render(c, kit)),
			);
		},
	);
}

// A page from PageRouter's suites, with the props PageRouter passes.
function page(suite: string, member: string, summary?: string, extraProps?: Dict) {
	return story({ name: member, summary: summary }, (_controls, kit) => {
		const pages = client.WaitForChild("pages");
		const suiteKit = require(pages.WaitForChild(suite) as ModuleScript) as (name: string) => Dict;
		const component = suiteKit(member)[member] as React.FunctionComponent<Dict>;
		const props: Dict = {
			state: kit.state,
			config: kit.config,
			dispatch: kit.dispatch,
			reducedMotion: kit.reducedMotion,
			navigate: (target: unknown) => {
				print("[story] navigate", target);
			},
			onCrateReveal: (session?: { crateName?: string }) => {
				print("[story] crate reveal", session && session.crateName);
			},
			crateRevealActive: false,
			onPurchasePresentationChange: () => {},
			setVisit: () => {},
			openShop: () => {},
		};
		for (const [key, value] of pairs(extraProps ?? {})) {
			props[key] = value;
		}
		return React.createElement(component, props);
	});
}

// Turns a live value into Luau source (for capturing a snapshot from a playtest into StorySnapshot).
function serialize(value: unknown, indent?: string): string {
	indent = indent ?? "";
	const kind = typeOf(value);
	if (kind === "string") {
		return "%q".format(value as string);
	} else if (kind === "number") {
		const n = value as number;
		if (n !== n) {
			return "0/0";
		} else if (n === math.huge) {
			return "math.huge";
		} else if (n === -math.huge) {
			return "-math.huge";
		}
		return tostring(n);
	} else if (kind === "boolean" || kind === "nil") {
		return tostring(value);
	} else if (kind === "Color3") {
		const c = value as Color3;
		return "Color3.fromRGB(%d, %d, %d)".format(math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255));
	} else if (kind === "Vector3") {
		const v = value as Vector3;
		return "Vector3.new(%s, %s, %s)".format(v.X, v.Y, v.Z);
	} else if (kind === "Vector2") {
		const v = value as Vector2;
		return "Vector2.new(%s, %s)".format(v.X, v.Y);
	} else if (kind === "UDim2") {
		const u = value as UDim2;
		return "UDim2.new(%s, %s, %s, %s)".format(u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset);
	} else if (kind === "EnumItem") {
		return tostring(value);
	} else if (kind === "table") {
		const t = value as Map<defined, unknown>;
		const inner = indent + "\t";
		const parts: string[] = [];
		const keys: defined[] = [];
		for (const [key] of pairs(t)) {
			keys.push(key);
		}
		keys.sort((a, b) => tostring(a) < tostring(b));
		for (const key of keys) {
			const keyText =
				typeIs(key, "string") && key.match("^[%a_][%w_]*$")[0] !== undefined ? key : `[${serialize(key)}]`;
			parts.push(`${inner}${keyText} = ${serialize(t.get(key), inner)},`);
		}
		if (parts.size() === 0) {
			return "{}";
		}
		return "{\n" + parts.join("\n") + "\n" + indent + "}";
	}
	return "nil";
}

// Layout problems in a rendered tree: text that doesn't fit, controls under the phone tap size,
// elements outside the screen, and labels running into solid siblings. Used by the mobile audit.
function audit(root: GuiObject, minTap?: number): Issue[] {
	const issues: Issue[] = [];
	const tap = minTap ?? 40;
	const screen = root.AbsolutePosition;
	const screenSize = root.AbsoluteSize;
	let scale = 1;
	const uiScale = root.FindFirstChildOfClass("UIScale");
	if (uiScale !== undefined) {
		scale = uiScale.Scale;
	}
	const visible = (gui: Instance) => {
		let node: Instance | undefined = gui;
		while (node !== undefined && node !== root) {
			if (node.IsA("GuiObject") && !node.Visible) {
				return false;
			}
			node = node.Parent;
		}
		return true;
	};
	for (const gui of root.GetDescendants()) {
		if (!gui.IsA("GuiObject") || !visible(gui)) {
			continue;
		}
		const pos = gui.AbsolutePosition;
		const size = gui.AbsoluteSize;
		if (size.X < 1 || size.Y < 1) {
			continue;
		}
		const name = gui.GetFullName();
		if ((gui.IsA("TextLabel") || gui.IsA("TextButton")) && gui.Text !== "" && !gui.TextFits) {
			issues.push({ kind: "text-overflow", path: name, detail: gui.Text });
		}
		if (
			gui.IsA("GuiButton") &&
			gui.Active &&
			(size.X / scale < tap - 0.5 || size.Y / scale < tap - 0.5) &&
			gui.BackgroundTransparency < 1
		) {
			issues.push({ kind: "small-tap", path: name, detail: "%dx%d".format(size.X / scale, size.Y / scale) });
		}
		if (
			pos.X + size.X < screen.X - 1 ||
			pos.Y + size.Y < screen.Y - 1 ||
			pos.X > screen.X + screenSize.X + 1 ||
			pos.Y > screen.Y + screenSize.Y + 1
		) {
			continue;
		}
		if (pos.X < screen.X - 2 || pos.X + size.X > screen.X + screenSize.X + 2) {
			if (gui.IsA("TextLabel") || gui.IsA("GuiButton") || gui.IsA("TextBox")) {
				issues.push({
					kind: "offscreen-x",
					path: name,
					detail: "%d..%d of %d".format(
						(pos.X - screen.X) / scale,
						(pos.X + size.X - screen.X) / scale,
						screenSize.X / scale,
					),
				});
			}
		}
	}
	return issues;
}

export = {
	React,
	ReactRoblox,
	UILabs,
	client,
	shared,
	DEVICES,
	deviceSize,
	isPhone,
	viewportInfo,
	DeviceFrame,
	Boundary: StoryBoundary,
	state,
	config,
	dispatcher,
	controls,
	story,
	page,
	serialize,
	audit,
};
