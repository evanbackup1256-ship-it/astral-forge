// a clear slide: far enough that the direction of the change reads, short enough that the page never
// seems to travel. It settles over ENTER_SECONDS on the page-entrance spring.
export const SLIDE_DESKTOP = 22;
export const SLIDE_PHONE = 30;
export const ENTER_SECONDS = 0.26;
export const SOFT_SCALE = 0.45;
export const VEIL_PEAK = 0.68;
const VEIL_POWER = 2.4;

function clamp01(value: unknown): number {
	if (!typeIs(value, "number") || value !== value) {
		return 1;
	}
	return math.clamp(value, 0, 1);
}

function indexOf(order: ReadonlyArray<string> | undefined, id: string | undefined): number | undefined {
	if (order === undefined || id === undefined) {
		return undefined;
	}
	const index = order.indexOf(id);
	return index >= 0 ? index : undefined;
}

export function direction(fromPage: string | undefined, toPage: string | undefined, order?: ReadonlyArray<string>): 1 | -1 {
	const from = indexOf(order, fromPage);
	const to = indexOf(order, toPage);
	if (from === undefined || to === undefined || from === to) {
		return 1;
	}
	return to > from ? 1 : -1;
}

// A jump across the nav sweeps farther than a step to the next page: 1x for a neighbour, then 12% more
// for every page skipped, up to 1.6x. Missing or unknown pages count as a neighbour.
export function span(fromPage: string | undefined, toPage: string | undefined, order?: ReadonlyArray<string>): number {
	const from = indexOf(order, fromPage);
	const to = indexOf(order, toPage);
	if (from === undefined || to === undefined) {
		return 1;
	}
	return math.clamp(1 + (math.abs(to - from) - 1) * 0.12, 1, 1.6);
}

export function distance(phone: boolean, soft?: boolean): number {
	const base = phone ? SLIDE_PHONE : SLIDE_DESKTOP;
	return soft ? math.floor(base * SOFT_SCALE + 0.5) : base;
}

export function offset(amount: unknown, dir: number, axis: "x" | "y", travel?: number): LuaTuple<[number, number]> {
	const t = clamp01(amount);
	const remaining = (1 - t) * (dir === -1 ? -1 : 1) * (travel ?? SLIDE_DESKTOP);
	const px = math.round(remaining);
	if (axis === "x") {
		return $tuple(px, 0);
	}
	return $tuple(0, px);
}

export function veilTransparency(amount: unknown): number {
	const t = clamp01(amount);
	return 1 - VEIL_PEAK * (1 - t) ** VEIL_POWER;
}
