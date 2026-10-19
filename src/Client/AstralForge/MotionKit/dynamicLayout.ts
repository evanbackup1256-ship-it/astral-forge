import React from "@rbxts/react";
import { useFlipperSpring } from "./motion";

export const LAYOUT_STIFFNESS = 520;
export const LAYOUT_DAMPING = 46;

export function useDynamicLayoutNumber(goal: number, _reducedMotion?: boolean): React.Binding<number> {
	return useFlipperSpring(goal, false, LAYOUT_STIFFNESS, LAYOUT_DAMPING);
}
