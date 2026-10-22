// One place that answers "what is the player using?" for mouse, touch and gamepad.
// Hardware flags come from UserInputService; the active kind follows the last input and is
// shared by every subscriber through a single LastInputTypeChanged connection, made on first use.

const UserInputService = game.GetService("UserInputService");

export type InputKind = "Mouse" | "Touch" | "Gamepad";

const GAMEPADS = new Set<Enum.UserInputType>([
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
	Enum.UserInputType.Gamepad5,
	Enum.UserInputType.Gamepad6,
	Enum.UserInputType.Gamepad7,
	Enum.UserInputType.Gamepad8,
]);

export function isGamepadInput(inputType: Enum.UserInputType): boolean {
	return GAMEPADS.has(inputType);
}

// Inputs that say nothing about the device (focus, text, accelerometer) return undefined.
export function kindOf(inputType: Enum.UserInputType): InputKind | undefined {
	if (inputType === Enum.UserInputType.Touch) {
		return "Touch";
	}
	if (GAMEPADS.has(inputType)) {
		return "Gamepad";
	}
	if (
		inputType === Enum.UserInputType.Keyboard ||
		inputType === Enum.UserInputType.MouseMovement ||
		inputType === Enum.UserInputType.MouseButton1 ||
		inputType === Enum.UserInputType.MouseButton2 ||
		inputType === Enum.UserInputType.MouseButton3 ||
		inputType === Enum.UserInputType.MouseWheel
	) {
		return "Mouse";
	}
	return undefined;
}

export const Hardware = {
	touch: () => UserInputService.TouchEnabled,
	mouse: () => UserInputService.MouseEnabled,
	keyboard: () => UserInputService.KeyboardEnabled,
	gamepad: () => UserInputService.GamepadEnabled,
};

// a phone or tablet with no pointer attached
export function isTouchOnly(): boolean {
	return UserInputService.TouchEnabled && !UserInputService.MouseEnabled;
}

// a console or a pad-only PC: a gamepad and neither keyboard nor mouse
export function isPadOnly(): boolean {
	return UserInputService.GamepadEnabled && !UserInputService.KeyboardEnabled && !UserInputService.MouseEnabled;
}

// Touch-only or pad-only hardware, where scrolling and hit areas should be more forgiving.
export function isConstrainedInput(): boolean {
	return isTouchOnly() || isPadOnly();
}

function startingKind(): InputKind {
	const fromLast = kindOf(UserInputService.GetLastInputType());
	if (fromLast !== undefined) {
		return fromLast;
	}
	if (UserInputService.TouchEnabled) {
		return "Touch";
	}
	return isPadOnly() ? "Gamepad" : "Mouse";
}

let active: InputKind | undefined;
let watcher: RBXScriptConnection | undefined;
const listeners = new Set<(kind: InputKind) => void>();

function watch() {
	if (watcher !== undefined) {
		return;
	}
	watcher = UserInputService.LastInputTypeChanged.Connect((inputType) => {
		const kind = kindOf(inputType);
		if (kind === undefined || kind === active) {
			return;
		}
		active = kind;
		for (const listener of listeners) {
			task.spawn(listener, kind);
		}
	});
}

export function activeKind(): InputKind {
	if (active === undefined) {
		active = startingKind();
	}
	watch();
	return active;
}

export function lastInputIsGamepad(): boolean {
	return isGamepadInput(UserInputService.GetLastInputType());
}

export function onKindChanged(listener: (kind: InputKind) => void): () => void {
	activeKind();
	listeners.add(listener);
	return () => listeners.delete(listener);
}

export function stopInputLayer() {
	watcher?.Disconnect();
	watcher = undefined;
	active = undefined;
	listeners.clear();
}
