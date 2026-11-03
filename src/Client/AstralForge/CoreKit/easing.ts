// Small shared curves. No imports, so any kit (motion, overlays, art) can use them without a cycle.

/** `value` held to 0..1. */
export const clamp01 = (value: number) => math.clamp(value, 0, 1);

/** Cubic ease-out over 0..1 (input clamped): fast start, soft landing. */
export const easeOut = (t: number) => 1 - (1 - clamp01(t)) ** 3;
