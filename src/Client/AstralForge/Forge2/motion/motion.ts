// Forge2's motion entry points. Springs, staggers, pops and glints come straight from MotionKit;
// screen tracks go through the same MotionFX (ScreenFx) presets as the old client, and game-feel
// bursts through JuiceFx, all at full strength. MotionKit's settings context still decides how
// soft things feel, so the player's Graphics settings keep working unchanged.
import React from "@rbxts/react";
import { useSpring } from "../../MotionKit/motion";
import { MotionFX as ScreenTracks } from "../../UiCore/screenFx";
import Juice = require("../../JuiceFx");

export const MotionFX = {
	/** a named screen track stack ("confirm", "success", "error", "warning", "milestone", "modeSwitch") */
	play(name: string) {
		pcall(() => ScreenTracks.play(name, 1));
	},
};

export const Burst = {
	gain(text: string, color: Color3, icon?: string) {
		pcall(() => {
			Juice.number(text, color, { icon, big: true });
			Juice.coins("FLUX", color, "Flux", 10);
			Juice.burst(undefined, color, 1);
		});
	},
	spark(color: Color3, scale = 0.7) {
		pcall(() => Juice.burst(undefined, color, scale));
	},
};

/** Mount-on-open with a sprung exit: stays mounted until the close spring has played out. */
export function usePresenceOf(open: boolean, closeSeconds = 0.25): LuaTuple<[React.Binding<number>, boolean]> {
	const amount = useSpring(open ? 1 : 0, false, 260, 24, 0);
	const [mounted, setMounted] = React.useState(open);
	React.useEffect(() => {
		if (open) {
			setMounted(true);
			return undefined;
		}
		const job = task.delay(closeSeconds, () => setMounted(false));
		return () => {
			pcall(task.cancel, job);
		};
	}, [open]);
	return $tuple(amount, mounted || open);
}
