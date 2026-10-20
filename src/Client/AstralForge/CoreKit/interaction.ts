const HapticService = game.GetService("HapticService");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

let hapticIntensity = 1;
const motorGenerations = new Map<Enum.UserInputType, number>();
const GAMEPAD_INPUTS: Enum.UserInputType[] = [
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
];
const RUMBLE_MOTORS = [Enum.VibrationMotor.Small, Enum.VibrationMotor.Large];
const vibrationSupport = new Map<Enum.UserInputType, Enum.VibrationMotor[]>();

function isGamepadInput(input: Enum.UserInputType): boolean {
	return GAMEPAD_INPUTS.includes(input);
}

let gamepadWatchInstalled = false;
function watchGamepads() {
	if (gamepadWatchInstalled) {
		return;
	}
	gamepadWatchInstalled = true;
	UserInputService.GamepadConnected.Connect((pad) => {
		vibrationSupport.delete(pad);
	});
	UserInputService.GamepadDisconnected.Connect((pad) => {
		vibrationSupport.delete(pad);
		motorGenerations.delete(pad);
	});
}

function motorsFor(input: Enum.UserInputType): Enum.VibrationMotor[] {
	const cached = vibrationSupport.get(input);
	if (cached !== undefined) {
		return cached;
	}
	watchGamepads();
	const [vibrationOk, vibrationSupported] = pcall(() => HapticService.IsVibrationSupported(input));
	let resolved = new Array<Enum.VibrationMotor>();
	if (vibrationOk && vibrationSupported === true) {
		const usable = new Array<Enum.VibrationMotor>();
		for (const motor of RUMBLE_MOTORS) {
			const [motorOk, motorSupported] = pcall(() => HapticService.IsMotorSupported(input, motor));
			if (motorOk && motorSupported === true) {
				usable.push(motor);
			}
		}
		resolved = usable;
	}
	vibrationSupport.set(input, resolved);
	return resolved;
}

function supportsVibration(input: Enum.UserInputType): boolean {
	return motorsFor(input).size() > 0;
}

function hapticTarget(): Enum.UserInputType | undefined {
	const last = UserInputService.GetLastInputType();
	// phones that expose a touch motor get the same feedback as a pad; the rest stay silent
	if (last === Enum.UserInputType.Touch) {
		return supportsVibration(last) ? last : undefined;
	}
	if (isGamepadInput(last)) {
		return supportsVibration(last) ? last : undefined;
	}
	if (!UserInputService.GamepadEnabled) {
		return undefined;
	}
	const [ok, connected] = pcall(() => UserInputService.GetConnectedGamepads());
	if (!ok || connected === undefined) {
		return undefined;
	}
	for (const pad of connected) {
		if (supportsVibration(pad)) {
			return pad;
		}
	}
	return undefined;
}

export function setHapticIntensity(value: number) {
	hapticIntensity = math.clamp(value, 0, 1);
	if (hapticIntensity <= 0.02) {
		for (const [input] of motorGenerations) {
			for (const motor of motorsFor(input)) {
				pcall(() => HapticService.SetMotor(input, motor, 0));
			}
		}
		motorGenerations.clear();
	}
}

function safePulse(input: Enum.UserInputType, strength: number, seconds: number) {
	if (hapticIntensity <= 0.02) {
		return;
	}
	const motors = motorsFor(input);
	if (motors.size() === 0) {
		return;
	}
	const level = math.clamp(strength * hapticIntensity, 0, 1);
	let startedAny = false;
	for (const motor of motors) {
		const [startOk] = pcall(() => HapticService.SetMotor(input, motor, level));
		if (startOk) {
			startedAny = true;
		}
	}
	if (!startedAny) {
		return;
	}
	const generation = (motorGenerations.get(input) ?? 0) + 1;
	motorGenerations.set(input, generation);
	task.delay(math.max(0.01, seconds), () => {
		if (motorGenerations.get(input) !== generation) {
			return;
		}
		motorGenerations.delete(input);
		for (const motor of motors) {
			pcall(() => HapticService.SetMotor(input, motor, 0));
		}
	});
}

function pulse(strength: number, seconds: number) {
	if (hapticIntensity <= 0.02) {
		return;
	}
	const input = hapticTarget();
	if (input === undefined) {
		return;
	}
	task.defer(() => safePulse(input, strength, seconds));
}

let lastDesktopResult: boolean | undefined;
export function usesDesktopStructure(width?: number, height?: number): boolean {
	const hasPointerHardware = UserInputService.KeyboardEnabled || UserInputService.MouseEnabled;
	const preferred = UserInputService.PreferredInput;
	const touch = UserInputService.TouchEnabled;

	const camera = Workspace.CurrentCamera;
	const viewport = camera !== undefined ? camera.ViewportSize : new Vector2(1280, 720);
	const screenWidth = width !== undefined ? width : viewport.X;
	const screenHeight = height !== undefined ? height : viewport.Y;

	let result = false;
	if (screenWidth >= 840 && screenHeight >= 500) {
		if (!touch) {
			if (preferred === Enum.PreferredInput.KeyboardAndMouse) {
				result = true;
			} else if (preferred === Enum.PreferredInput.Gamepad || preferred === Enum.PreferredInput.MicroGamepad) {
				result = true;
			} else {
				result = hasPointerHardware;
			}
		} else {
			if (preferred === Enum.PreferredInput.Gamepad || preferred === Enum.PreferredInput.MicroGamepad) {
				result = true;
			} else {
				result = screenWidth >= 1100 && screenHeight >= 650;
			}
		}
	}

	if (lastDesktopResult !== undefined && result !== lastDesktopResult) {
		if (lastDesktopResult) {
			if (screenWidth < 780 || screenHeight < 470) {
				lastDesktopResult = false;
			} else {
				return lastDesktopResult;
			}
		} else {
			if (screenWidth >= 840 && screenHeight >= 500) {
				lastDesktopResult = true;
			} else {
				return lastDesktopResult;
			}
		}
	}
	lastDesktopResult = result;
	return result;
}

export function isTouchDevice(): boolean {
	return UserInputService.TouchEnabled && !usesDesktopStructure();
}

export function isGamepadDevice(): boolean {
	const preferred = UserInputService.PreferredInput;
	return preferred === Enum.PreferredInput.Gamepad || preferred === Enum.PreferredInput.MicroGamepad;
}

export const InteractionFeedback = {
	tap: () => pulse(0.22, 0.045),
	tick: () => pulse(0.1, 0.025),
	reward: () => pulse(0.5, 0.11),
	confirm: () => pulse(0.32, 0.06),
	// a refused press: two short low knocks, softer than a reward so it reads as "no", not "yes"
	fail: () => {
		pulse(0.18, 0.04);
		task.delay(0.09, () => pulse(0.18, 0.04));
	},
};
