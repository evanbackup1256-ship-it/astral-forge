// The one typed token source for UiCore. Every value here is the existing value from CoreKit/theme,
// MotionKit/motionTokens and the surface metrics, gathered in one place so new code reads
// `Tokens.space.md` instead of picking from three files. Nothing is redefined: change a value at
// its origin and it shows up here.
import { Bevel, Breakpoints, Chrome, Elevation, Layout, Pad, Palette, Radius, Space, StrokeWidth, TapTarget, TypeScale } from "../CoreKit/theme";
import * as MotionTokens from "../MotionKit/motionTokens";
import { REVEAL_RISE } from "../MotionKit/motion";
import { SurfaceMetrics, SurfaceType } from "./surface";

export const Tokens = {
	/** live table: applyAccessibilityTheme recolors it in place */
	palette: Palette,
	space: Space,
	pad: Pad,
	radius: Radius,
	stroke: StrokeWidth,
	type: TypeScale,
	bevel: Bevel,
	elevation: Elevation,
	chrome: Chrome,
	layout: Layout,
	breakpoints: Breakpoints,
	tapTarget: TapTarget,
	surface: SurfaceMetrics,
	surfaceType: SurfaceType,
	motion: {
		ease: MotionTokens.EASE,
		duration: MotionTokens.DURATION,
		spring: MotionTokens.SPRING,
		staggerStep: MotionTokens.STAGGER_STEP,
		staggerCap: MotionTokens.STAGGER_CAP,
		revealRise: REVEAL_RISE,
		/** StackBlocks rise (ui3/0006): 0.055s apart, at most 8 waiting, 0.45s, 22px */
		stackRise: { stagger: 0.055, cap: 8, duration: 0.45, drop: 22 },
	},
} as const;

export type ThemeTokens = typeof Tokens;
export type SpaceToken = keyof typeof Space;
export type RadiusToken = keyof typeof Radius;
export type PaletteColor = keyof typeof Palette;
export type EaseName = keyof typeof MotionTokens.EASE;
export type DurationName = keyof typeof MotionTokens.DURATION;

/** a space token or raw pixels */
export function space(value: SpaceToken | number): number {
	return typeIs(value, "number") ? value : Space[value];
}

export function radius(value: RadiusToken | number): number {
	return typeIs(value, "number") ? value : Radius[value];
}
