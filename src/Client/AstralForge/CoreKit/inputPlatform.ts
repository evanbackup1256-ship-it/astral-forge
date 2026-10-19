import { vendoredTs } from "../vendor";
import * as GamepadNavigationService from "./GamepadNavigationService";
import * as TouchGestureService from "./TouchGestureService";

const UserInputService = game.GetService("UserInputService");

interface ThreeA {
	Input: { setMethods(this: void, methods: unknown[]): void };
	InputMethod: { Touchscreen: unknown; Gamepad: unknown; KeyboardMouse: unknown };
}

let configured = false;

export function configureInputPlatform(): () => void {
	if (configured) {
		return () => {};
	}
	const { Input, InputMethod } = vendoredTs<ThreeA>("3a");
	const methods = UserInputService.TouchEnabled
		? [InputMethod.Touchscreen]
		: UserInputService.GamepadEnabled
			? [InputMethod.Gamepad]
			: [InputMethod.KeyboardMouse];
	const [ok, problem] = pcall(() => Input.setMethods(methods));
	if (!ok) {
		warn("[ERROR] [INPUT] setMethods failed | Error: " + tostring(problem));
	}
	TouchGestureService.Init();
	GamepadNavigationService.Init();
	configured = true;
	return () => {
		TouchGestureService.Stop();
		GamepadNavigationService.Stop();
		configured = false;
	};
}
