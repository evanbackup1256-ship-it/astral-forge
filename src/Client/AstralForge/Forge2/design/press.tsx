// The current client's press feel, shared by Forge2 pressables. This is not a re-creation: it runs
// the same useButtonChrome hook (hover/press springs, offset dip, touch scale, tilt, impact flash,
// focus ring, idle + LIVE shimmer timing) and draws the same ButtonShimmer and impact layers as
// UiCore's Button, so timing and easing are identical by construction.
import React from "@rbxts/react";
import { buttonAudioCue } from "../../AudioKit/audio";
import { ButtonChrome, ButtonShimmer, useButtonChrome } from "../../UiCore/ui";

export type Press = ButtonChrome;

/** `sound` "auto" picks the cue from the label, as the old Button does. */
export function usePress(onPress: () => void, disabled: boolean, opts?: { idle?: boolean; sound?: string | false; label?: string; shimmer?: boolean }): Press {
	const sound = opts?.sound ?? "auto";
	const resolved = sound === "auto" ? buttonAudioCue(opts?.label ?? "") : sound;
	return useButtonChrome(onPress, false, disabled, resolved, opts?.shimmer !== false, opts?.idle === true, opts?.label ?? "");
}

/** Host events with an extra hover callback layered on (hover/selection), old chrome first. */
export function pressEvents<T extends GuiButton>(press: Press, onHover?: (on: boolean) => void): React.InstanceEvent<T> {
	const base = press.events as unknown as Record<string, ((rbx: T, ...args: unknown[]) => void) | undefined>;
	if (onHover === undefined) return base as unknown as React.InstanceEvent<T>;
	const wrap = (key: string, on: boolean) => (rbx: T, ...args: unknown[]) => {
		base[key]?.(rbx, ...args);
		onHover(on);
	};
	return {
		...base,
		MouseEnter: wrap("MouseEnter", true),
		MouseLeave: wrap("MouseLeave", false),
		SelectionGained: wrap("SelectionGained", true),
		SelectionLost: wrap("SelectionLost", false),
	} as unknown as React.InstanceEvent<T>;
}

/** Shimmer sweep + impact flash + impact ring, exactly as layered inside the old Button surface. */
export function PressLayers(props: { press: Press; radius: number; color: Color3; idle?: boolean; zIndex?: number }) {
	const { press, radius } = props;
	const z = props.zIndex ?? 2;
	if (!press.active) return undefined;
	return (
		<>
			<ButtonShimmer hoverAmount={press.hoverAmount} shimmer={press.shimmer} live={press.shimmerLive} idle={props.idle === true} zIndex={z} radius={radius} />
			<frame
				Size={UDim2.fromScale(1, 1)}
				BackgroundColor3={Color3.fromRGB(255, 255, 255)}
				BackgroundTransparency={press.impact.map((amount) => math.clamp(1 - amount * 0.48, 0.52, 1))}
				BorderSizePixel={0}
				Active={false}
				ZIndex={z + 2}
				Visible={press.impact.map((amount) => amount > 0.05)}
			>
				<uicorner CornerRadius={new UDim(0, radius)} />
			</frame>
			<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} BorderSizePixel={0} Active={false} ZIndex={z + 3} Visible={press.impact.map((amount) => amount > 0.03)}>
				<uicorner CornerRadius={new UDim(0, radius)} />
				<uistroke
					ApplyStrokeMode={Enum.ApplyStrokeMode.Border}
					Color={props.color}
					Thickness={press.impact.map((amount) => 1 + amount * 2)}
					Transparency={press.impact.map((amount) => math.clamp(1 - amount * 0.78, 0.18, 1))}
				/>
			</frame>
		</>
	);
}

/** Old focus ring: cream, 4px, fades in on gamepad focus (same mapping as UiCore Button). */
export function FocusRing(props: { press: Press; radius: number; color: Color3 }) {
	return (
		<frame Size={UDim2.fromScale(1, 1)} BackgroundTransparency={1} Active={false} ZIndex={9}>
			<uicorner CornerRadius={new UDim(0, props.radius)} />
			<uistroke Color={props.color} Thickness={4} Transparency={props.press.focusRing.map((amount) => 1 - amount * 0.98)} />
		</frame>
	);
}
