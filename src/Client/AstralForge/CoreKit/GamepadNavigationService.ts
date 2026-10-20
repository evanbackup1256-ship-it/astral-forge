const UserInputService = game.GetService("UserInputService");
const GuiService = game.GetService("GuiService");
const GamepadService = game.GetService("GamepadService");
const Players = game.GetService("Players");

const TV_SAFE_MARGIN_RATIO = 0.08;
let isConsoleMode = false;
let inputConnection: RBXScriptConnection | undefined;
let connectedConnection: RBXScriptConnection | undefined;
let disconnectedConnection: RBXScriptConnection | undefined;
let preferredConnection: RBXScriptConnection | undefined;
let initialized = false;
let previousAutoSelect = false;
let previousNavigation = false;
let overlayFocusDepth = 0;
const overlaySelectionStack = new Array<{ target?: GuiObject }>();
// kept for parity with the overlay stack; read by nothing outside this module
let overlayPreviousSelection: GuiObject | undefined;

let tabCycleCallback: ((delta: number) => void) | undefined;
let modalCloseCallback: (() => void) | undefined;
let quickVaultCallback: (() => void) | undefined;
let overchargeCallback: (() => void) | undefined;
let settingsCallback: (() => void) | undefined;

export interface ControllerHint {
	id: string;
	label: string;
}

const CONTROLLER_HINTS: ControllerHint[] = [
	{ id: "pages", label: "LB / RB pages" },
	{ id: "vault", label: "Y vault" },
	{ id: "overcharge", label: "X overcharge" },
	{ id: "buy", label: "LT / RT buy ×" },
	{ id: "back", label: "B back" },
	{ id: "hide", label: "View hide" },
	{ id: "settings", label: "Start settings" },
];

const TUTORIAL_HINTS: ControllerHint[] = [
	{ id: "confirm", label: "A confirm" },
	{ id: "back", label: "B back" },
];

const CRATE_HINTS: ControllerHint[] = [
	{ id: "confirm", label: "A claim / skip" },
	{ id: "back", label: "B claim / skip" },
];

const HINT_KEYS: Record<string, Enum.KeyCode> = {
	A: Enum.KeyCode.ButtonA,
	B: Enum.KeyCode.ButtonB,
	X: Enum.KeyCode.ButtonX,
	Y: Enum.KeyCode.ButtonY,
	LB: Enum.KeyCode.ButtonL1,
	RB: Enum.KeyCode.ButtonR1,
	LT: Enum.KeyCode.ButtonL2,
	RT: Enum.KeyCode.ButtonR2,
	View: Enum.KeyCode.ButtonSelect,
	Start: Enum.KeyCode.ButtonStart,
};

const PLATFORM_NAMES: Record<string, string> = {
	ButtonCross: "Cross",
	ButtonCircle: "Circle",
	ButtonSquare: "Square",
	ButtonTriangle: "Triangle",
	ButtonL1: "L1",
	ButtonR1: "R1",
	ButtonL2: "L2",
	ButtonR2: "R2",
	ButtonTouchpad: "Touchpad",
	ButtonOptions: "Options",
};

export function GetTVSafeInsets(viewportSize: Vector2): { top: number; bottom: number; left: number; right: number } {
	const marginX = math.floor(viewportSize.X * TV_SAFE_MARGIN_RATIO);
	const marginY = math.floor(viewportSize.Y * TV_SAFE_MARGIN_RATIO);
	return { top: marginY, bottom: marginY, left: marginX, right: marginX };
}

export function GetHints(kind?: string): ControllerHint[] {
	const source = kind === "tutorial" ? TUTORIAL_HINTS : kind === "crate" ? CRATE_HINTS : CONTROLLER_HINTS;
	return source.map((entry) => {
		const [label] = entry.label.gsub("%w+", (token: string) => {
			const key = HINT_KEYS[token];
			if (key === undefined) {
				return token;
			}
			const [ok, mapped] = pcall(() => UserInputService.GetStringForKeyCode(key));
			return ok ? (PLATFORM_NAMES[mapped] ?? token) : token;
		});
		return { id: entry.id, label };
	});
}

// One button's label the way the hint bar writes it (platform glyph names where Roblox has them).
export function KeyLabel(key: Enum.KeyCode, fallback: string): string {
	const [ok, mapped] = pcall(() => UserInputService.GetStringForKeyCode(key));
	return ok && typeIs(mapped, "string") && mapped !== "" ? (PLATFORM_NAMES[mapped] ?? mapped) : fallback;
}

export function GetHintLabels(kind?: string): string[] {
	return GetHints(kind).map((entry) => entry.label);
}

export function IsValidFocusTarget(object: Instance | undefined): object is GuiObject {
	if (object === undefined || !object.IsA("GuiObject")) {
		return false;
	}
	const gui = object;
	if (!gui.Visible || gui.AbsoluteSize.X < 2 || gui.AbsoluteSize.Y < 2) {
		return false;
	}
	if (gui.IsA("GuiButton")) {
		if (!gui.Selectable || !gui.Active) {
			return false;
		}
	} else if (!gui.Selectable) {
		return false;
	}
	let current: Instance | undefined = gui;
	while (current !== undefined) {
		if (current.IsA("GuiObject") && current.Visible === false) {
			return false;
		}
		if (current.IsA("LayerCollector") && !current.Enabled) {
			return false;
		}
		if (current.IsA("GuiObject") && current !== gui && current.ClipsDescendants) {
			const p = current.AbsolutePosition;
			const size = current.AbsoluteSize;
			const q = gui.AbsolutePosition;
			const qs = gui.AbsoluteSize;
			if (q.X + qs.X <= p.X || q.X >= p.X + size.X || q.Y + qs.Y <= p.Y || q.Y >= p.Y + size.Y) {
				return false;
			}
		}
		current = current.Parent;
	}
	return true;
}

export function AssignSelection(object: Instance | undefined): boolean {
	if (!IsValidFocusTarget(object)) {
		return false;
	}
	const [ok] = pcall(() => {
		GuiService.SelectedObject = object;
	});
	return ok;
}

export function ClearSelection() {
	pcall(() => {
		GuiService.SelectedObject = undefined;
	});
}

const TAG_PRIORITY: Record<string, number> = {
	claim: 1,
	confirm: 1,
	buy: 2,
	dismiss: 2,
	continue: 2,
	ready: 3,
	skip: 4,
};

export function FocusClaim(root: Instance | undefined): GuiObject | undefined {
	if (game.GetService("VRService").VREnabled) {
		return undefined;
	}
	if (!UserInputService.GamepadEnabled) {
		return undefined;
	}
	if (root === undefined || root.Parent === undefined) {
		return undefined;
	}
	GuiService.GuiNavigationEnabled = true;
	GuiService.AutoSelectGuiEnabled = true;
	const tagScore = (instance: Instance): number | undefined => {
		let current: Instance | undefined = instance;
		let best: number | undefined;
		while (current !== undefined && current !== root) {
			const name = current.Name.lower();
			for (const [tag, rank] of pairs(TAG_PRIORITY)) {
				if (name.find(tag, 1, true)[0] !== undefined) {
					if (best === undefined || rank < best) {
						best = rank;
					}
				}
			}
			current = current.Parent;
		}
		return best;
	};
	let preferred: GuiObject | undefined;
	let preferredScore = math.huge;
	let fallback: GuiObject | undefined;
	for (const child of root.GetDescendants()) {
		if (child.IsA("GuiButton") && IsValidFocusTarget(child)) {
			const score = tagScore(child);
			if (score !== undefined && score < preferredScore) {
				preferred = child;
				preferredScore = score;
			} else if (fallback === undefined) {
				fallback = child;
			}
		}
	}
	const target = preferred ?? fallback;
	if (target !== undefined) {
		AssignSelection(target);
	}
	return target;
}

export function GetScrollTarget(): GuiObject | undefined {
	const current = GuiService.SelectedObject;
	if (current !== undefined) {
		let cursor: Instance | undefined = current;
		while (cursor !== undefined) {
			if (cursor.IsA("ScrollingFrame") && cursor.Visible && cursor.ScrollingEnabled) {
				return cursor;
			}
			cursor = cursor.Parent;
		}
	}
	const localPlayer = Players.LocalPlayer;
	const playerGui = localPlayer ? localPlayer.FindFirstChildOfClass("PlayerGui") : undefined;
	if (playerGui !== undefined) {
		let bestFrame: GuiObject | undefined;
		let bestArea = 0;
		for (const desc of playerGui.GetDescendants()) {
			if (desc.IsA("ScrollingFrame") && desc.Visible && desc.ScrollingEnabled) {
				let visible = true;
				let ancestor: Instance | undefined = desc.Parent;
				while (ancestor !== undefined) {
					if (ancestor.IsA("GuiObject") && !ancestor.Visible) {
						visible = false;
						break;
					}
					if (ancestor.IsA("LayerCollector") && !ancestor.Enabled) {
						visible = false;
						break;
					}
					ancestor = ancestor.Parent;
				}
				if (visible) {
					const size = desc.AbsoluteSize;
					const area = size.X * size.Y;
					if (area > bestArea) {
						bestArea = area;
						bestFrame = desc;
					}
				}
			}
		}
		return bestFrame;
	}
	return undefined;
}

export function ResolveScrollTarget(): GuiObject | undefined {
	return GetScrollTarget();
}

export function BeginOverlayFocus() {
	const current = GuiService.SelectedObject;
	overlaySelectionStack.push({ target: current });
	overlayPreviousSelection = current;
	if (overlayFocusDepth === 0) {
		GuiService.GuiNavigationEnabled = false;
		GuiService.AutoSelectGuiEnabled = false;
		ClearSelection();
	}
	overlayFocusDepth += 1;
}

export function EndOverlayFocus() {
	if (overlayFocusDepth <= 0) {
		return;
	}
	overlayFocusDepth -= 1;
	const entry = overlaySelectionStack.pop();
	const restore = entry !== undefined ? entry.target : undefined;
	const size = overlaySelectionStack.size();
	overlayPreviousSelection = size > 0 ? overlaySelectionStack[size - 1].target : undefined;
	if (overlayFocusDepth === 0) {
		if (isConsoleMode) {
			GuiService.GuiNavigationEnabled = true;
			GuiService.AutoSelectGuiEnabled = true;
		} else {
			GuiService.GuiNavigationEnabled = previousNavigation;
			GuiService.AutoSelectGuiEnabled = previousAutoSelect;
		}
	}
	if (IsValidFocusTarget(restore)) {
		AssignSelection(restore);
	} else {
		ClearSelection();
	}
}

export function Init() {
	if (initialized) {
		return;
	}
	initialized = true;
	previousAutoSelect = GuiService.AutoSelectGuiEnabled;
	previousNavigation = GuiService.GuiNavigationEnabled;
	const syncGamepadMode = () => {
		isConsoleMode = GuiService.IsTenFootInterface() || UserInputService.PreferredInput === Enum.PreferredInput.Gamepad;
		if (isConsoleMode) {
			pcall(() => GamepadService.DisableGamepadCursor());
			GuiService.AutoSelectGuiEnabled = true;
			GuiService.GuiNavigationEnabled = true;
		} else {
			GuiService.AutoSelectGuiEnabled = previousAutoSelect;
			GuiService.GuiNavigationEnabled = previousNavigation;
		}
	};
	syncGamepadMode();
	preferredConnection = UserInputService.GetPropertyChangedSignal("PreferredInput").Connect(syncGamepadMode);
	connectedConnection = UserInputService.GamepadConnected.Connect(syncGamepadMode);
	disconnectedConnection = UserInputService.GamepadDisconnected.Connect(syncGamepadMode);

	inputConnection = UserInputService.InputBegan.Connect((input, gameProcessed) => {
		if (gameProcessed || input.UserInputType !== Enum.UserInputType.Gamepad1) {
			return;
		}
		const code = input.KeyCode;
		if (code === Enum.KeyCode.ButtonB && modalCloseCallback) {
			modalCloseCallback();
		} else if (code === Enum.KeyCode.ButtonY && quickVaultCallback) {
			quickVaultCallback();
		} else if (code === Enum.KeyCode.ButtonX && overchargeCallback) {
			overchargeCallback();
		} else if ((code === Enum.KeyCode.ButtonStart || code === Enum.KeyCode.ButtonSelect) && settingsCallback) {
			settingsCallback();
		} else if (code === Enum.KeyCode.ButtonL1 && tabCycleCallback) {
			tabCycleCallback(-1);
		} else if (code === Enum.KeyCode.ButtonR1 && tabCycleCallback) {
			tabCycleCallback(1);
		}
	});
}

export function Stop() {
	preferredConnection?.Disconnect();
	preferredConnection = undefined;
	inputConnection?.Disconnect();
	inputConnection = undefined;
	connectedConnection?.Disconnect();
	connectedConnection = undefined;
	disconnectedConnection?.Disconnect();
	disconnectedConnection = undefined;
	if (initialized) {
		GuiService.AutoSelectGuiEnabled = previousAutoSelect;
		GuiService.GuiNavigationEnabled = previousNavigation;
	}
	initialized = false;
	isConsoleMode = false;
	overlayFocusDepth = 0;
	overlayPreviousSelection = undefined;
	overlaySelectionStack.clear();
	tabCycleCallback = undefined;
	modalCloseCallback = undefined;
	quickVaultCallback = undefined;
	overchargeCallback = undefined;
	settingsCallback = undefined;
}

export function SetTabCycleCallback(callback: (delta: number) => void) {
	tabCycleCallback = callback;
}
export function SetModalCloseCallback(callback: () => void) {
	modalCloseCallback = callback;
}
export function SetQuickVaultCallback(callback: () => void) {
	quickVaultCallback = callback;
}
export function SetOverchargeCallback(callback: () => void) {
	overchargeCallback = callback;
}
export function SetSettingsCallback(callback: () => void) {
	settingsCallback = callback;
}
export function IsConsole(): boolean {
	return isConsoleMode;
}
