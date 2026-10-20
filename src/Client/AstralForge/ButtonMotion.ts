// !strict
// Purpose: give every GuiButton the game's press/hover motion, including hand-built buttons that
// don't go through ui.Button. Shared Buttons (they carry their own UIScale) are left alone.
// Owner: UI shell. Dependencies: TweenService, GuiService. Review: 2026-10-08.

import { isReducedMotion } from "./MotionPreference";
const TweenService = game.GetService("TweenService");
const Workspace = game.GetService("Workspace");

const ButtonMotion = {} as {
	attach: (root: Instance) => () => void;
	setReducedMotion: (value: boolean | undefined) => void;
};

const SCALE_NAME = "AF_Motion";
// in pixels on the button's longest side, so a 40px icon and a 400px row feel the same as ui.Button
const HOVER_PIXELS = 2;
const PRESS_PIXELS = 4;
const HOVER_IN = new TweenInfo(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
const PRESS_IN = new TweenInfo(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
const RELEASE = new TweenInfo(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
const SETTLE = new TweenInfo(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);

let reducedOverride: boolean | undefined = undefined;

function setReducedMotion(value: boolean | undefined) {
	reducedOverride = value;
}

function reduced(): boolean {
	if (reducedOverride !== undefined) {
		return reducedOverride;
	}
	return isReducedMotion();
}

function optedOut(button: GuiButton): boolean {
	let node: Instance | undefined = button;
	for (let i = 0; i < 4; i++) {
		if (node === undefined) {
			break;
		}
		if (node.GetAttribute("NoMotion") === true) {
			return true;
		}
		node = node.Parent;
	}
	return false;
}

// ui.Button nests its own UIScale one level down; anything already scaling animates itself
function ownsMotion(button: GuiButton): boolean {
	for (const child of button.GetChildren()) {
		if (child.IsA("UIScale") && child.Name !== SCALE_NAME) {
			return true;
		}
		if (child.IsA("GuiObject")) {
			for (const grandchild of child.GetChildren()) {
				if (grandchild.IsA("UIScale")) {
					return true;
				}
			}
		}
	}
	return false;
}

function eligible(button: GuiButton): boolean {
	if (!button.Active || optedOut(button) || ownsMotion(button)) {
		return false;
	}
	const size = button.AbsoluteSize;
	if (size.X < 8 || size.Y < 8) {
		return false;
	}
	const camera = Workspace.CurrentCamera;
	const viewport = camera ? camera.ViewportSize : new Vector2(1920, 1080);
	// full-screen scrims and dismiss layers must never pulse
	if (size.X > viewport.X * 0.6 && size.Y > viewport.Y * 0.6) {
		return false;
	}
	return true;
}

function gains(button: GuiButton): [number, number] {
	const longest = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y, 1);
	const hover = math.clamp(HOVER_PIXELS / longest, 0.006, 0.05);
	const press = math.clamp(PRESS_PIXELS / longest, 0.012, 0.08);
	return [hover, press];
}

function attach(root: Instance): () => void {
	const tracked = new Map<GuiButton, RBXScriptConnection[]>();
	const tweens = new Map<GuiButton, Tween>();
	let alive = true;

	function scaleOf(button: GuiButton): UIScale | undefined {
		const scale = button.FindFirstChild(SCALE_NAME);
		if (scale && scale.IsA("UIScale")) {
			return scale;
		}
		return undefined;
	}

	function tween(button: GuiButton, goal: number, info: TweenInfo) {
		const existing = tweens.get(button);
		if (existing !== undefined) {
			existing.Cancel();
		}
		const scale = scaleOf(button);
		if (scale === undefined) {
			return;
		}
		const nextTween = TweenService.Create(scale, info, { Scale: goal });
		tweens.set(button, nextTween);
		nextTween.Play();
	}

	function attachButton(button: GuiButton) {
		if (tracked.has(button)) {
			return;
		}
		let hovered = false;
		let pressed = false;
		const connections: RBXScriptConnection[] = [];
		function rest() {
			const scale = button.FindFirstChild(SCALE_NAME);
			if (scale && scale.IsA("UIScale")) {
				tween(button, 1, SETTLE);
			}
		}
		function enter() {
			hovered = true;
			if (pressed || reduced() || !eligible(button)) {
				return;
			}
			// Roblox's default grey tint doesn't match the game's chrome; motion replaces it
			if (button.AutoButtonColor) {
				button.AutoButtonColor = false;
			}
			const [hover] = gains(button);
			tween(button, 1 + hover, HOVER_IN);
		}
		function leave() {
			hovered = false;
			pressed = false;
			rest();
		}
		function down() {
			if (!eligible(button)) {
				return;
			}
			pressed = true;
			if (button.AutoButtonColor) {
				button.AutoButtonColor = false;
			}
			const [, press] = gains(button);
			tween(button, 1 - (reduced() ? press * 0.5 : press), PRESS_IN);
		}
		function up() {
			if (!pressed) {
				return;
			}
			pressed = false;
			if (reduced()) {
				rest();
				return;
			}
			const [hover] = gains(button);
			tween(button, hovered ? 1 + hover : 1, RELEASE);
		}
		connections.push(button.MouseEnter.Connect(enter));
		connections.push(button.SelectionGained.Connect(enter));
		connections.push(button.MouseLeave.Connect(leave));
		connections.push(button.SelectionLost.Connect(leave));
		connections.push(
			button.InputBegan.Connect((input) => {
				const kind = input.UserInputType;
				if (
					kind === Enum.UserInputType.MouseButton1 ||
					kind === Enum.UserInputType.Touch ||
					input.KeyCode === Enum.KeyCode.ButtonA
				) {
					down();
				}
			}),
		);
		connections.push(
			button.InputEnded.Connect((input) => {
				const kind = input.UserInputType;
				if (
					kind === Enum.UserInputType.MouseButton1 ||
					kind === Enum.UserInputType.Touch ||
					input.KeyCode === Enum.KeyCode.ButtonA
				) {
					up();
				}
			}),
		);
		connections.push(
			button.GetPropertyChangedSignal("Active").Connect(() => {
				if (!button.Active) {
					pressed = false;
					rest();
				}
			}),
		);
		connections.push(
			button.Destroying.Connect(() => {
				const activeTween = tweens.get(button);
				if (activeTween !== undefined) {
					activeTween.Cancel();
					tweens.delete(button);
				}
				const list = tracked.get(button);
				tracked.delete(button);
				if (list) {
					for (const connection of list) {
						connection.Disconnect();
					}
				}
			}),
		);
		tracked.set(button, connections);
	}

	function consider(instance: Instance) {
		if (instance.IsA("GuiButton")) {
			const button = instance;
			// React fills children after creation; decide once the subtree exists
			task.defer(() => {
				if (alive && button.Parent !== undefined) {
					attachButton(button);
				}
			});
		}
	}

	for (const descendant of root.GetDescendants()) {
		consider(descendant);
	}
	const added = root.DescendantAdded.Connect(consider);

	return () => {
		alive = false;
		added.Disconnect();
		for (const [button, activeTween] of tweens) {
			activeTween.Cancel();
			tweens.delete(button);
		}
		for (const [button, connections] of tracked) {
			for (const connection of connections) {
				connection.Disconnect();
			}
			tracked.delete(button);
			const scale = button.FindFirstChild(SCALE_NAME);
			if (scale !== undefined) {
				scale.Destroy();
			}
		}
	};
}

ButtonMotion.attach = attach;
ButtonMotion.setReducedMotion = setReducedMotion;

export = ButtonMotion;
