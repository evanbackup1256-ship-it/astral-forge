// What a tooltip can say. Plain strings still work everywhere; the table form adds stats rows,
// before/after comparisons and key hints. Everything is optional except that a tip needs a title
// or a body to open.

/** One stat line: "Damage   1.2K". `delta` draws a signed change after the value. */
export interface TooltipStat {
	label: string;
	value: string | number;
	/** change against what is equipped / current: positive reads good unless `lowerIsBetter` */
	delta?: number;
	lowerIsBetter?: boolean;
	/** how the delta prints; defaults to a signed short number ("+12", "-3.5") */
	format?: (delta: number) => string;
	color?: Color3;
}

/** A key cap and what it does. `keys` may differ per input; missing devices hide the hint. */
export interface TooltipKey {
	label: string;
	keys: string | { keyboard?: string; gamepad?: string; touch?: string };
}

export interface TooltipData {
	title?: string;
	body?: string;
	hint?: string;
	accent?: Color3;
	stats?: ReadonlyArray<TooltipStat>;
	keys?: ReadonlyArray<TooltipKey>;
	/** preferred side; the layer flips and shifts from there */
	side?: TooltipSide;
}

export type TooltipContent = string | TooltipData;
export type TooltipSide = "top" | "bottom" | "right" | "left";
export type InputKind = "keyboard" | "gamepad" | "touch";

const filled = (text: string | undefined): text is string => text !== undefined && text !== "";

/** undefined when there is nothing worth opening a bubble for */
export function readContent(content: TooltipContent | undefined): TooltipData | undefined {
	if (content === undefined) {
		return undefined;
	}
	const data: TooltipData = typeIs(content, "string") ? { title: content } : content;
	return filled(data.title) || filled(data.body) || (data.stats !== undefined && data.stats.size() > 0) ? data : undefined;
}

export function hasText(text: string | undefined): text is string {
	return filled(text);
}

function shortNumber(value: number): string {
	const size = math.abs(value);
	const units: [number, string][] = [
		[1e12, "T"],
		[1e9, "B"],
		[1e6, "M"],
		[1e3, "K"],
	];
	for (const [step, unit] of units) {
		if (size >= step) {
			return `${string.format("%.1f", value / step).gsub("%.0$", "")[0]}${unit}`;
		}
	}
	return math.floor(value) === value ? tostring(value) : string.format("%.1f", value).gsub("%.0$", "")[0];
}

export function formatDelta(stat: TooltipStat): string | undefined {
	const delta = stat.delta;
	if (delta === undefined || delta !== delta || delta === 0) {
		return undefined;
	}
	if (stat.format !== undefined) {
		return stat.format(delta);
	}
	return `${delta > 0 ? "+" : "-"}${shortNumber(math.abs(delta))}`;
}

/** 1 better, -1 worse, 0 no change */
export function deltaTone(stat: TooltipStat): number {
	const delta = stat.delta ?? 0;
	if (delta === 0 || delta !== delta) {
		return 0;
	}
	const up = delta > 0 ? 1 : -1;
	return stat.lowerIsBetter === true ? -up : up;
}

export function keysFor(key: TooltipKey, input: InputKind): string | undefined {
	if (typeIs(key.keys, "string")) {
		return input === "touch" ? undefined : key.keys;
	}
	return key.keys[input];
}

export function statValue(value: string | number): string {
	return typeIs(value, "number") ? shortNumber(value) : value;
}

/** stable signature so an open tip only re-renders when what it says changed */
export function contentKey(data: TooltipData): string {
	let key = `${data.title ?? ""}\0${data.body ?? ""}\0${data.hint ?? ""}`;
	for (const stat of data.stats ?? []) {
		key += `\0${stat.label}=${stat.value}~${stat.delta ?? ""}`;
	}
	for (const k of data.keys ?? []) {
		key += `\0${k.label}`;
	}
	return key;
}
