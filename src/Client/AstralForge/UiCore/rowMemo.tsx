import React from "@rbxts/react";
import { countRowRedraw } from "./devRedrawCounter";

// Row memo helpers (B29/B31 approach for list rows).
// sameValue: by value for plain tables (row data like a quest or a reward), == otherwise
// (Color3/UDim2/Vector2 already compare by value in Luau). Depth-capped; past the cap it
// falls back to reference, which can only cause an extra redraw.
export function sameValue(a: unknown, b: unknown, depth = 0): boolean {
	if (a === b) return true;
	if (!typeIs(a, "table") || !typeIs(b, "table") || depth >= 4) return false;
	const ta = a as Record<string, unknown>;
	const tb = b as Record<string, unknown>;
	for (const [key, value] of pairs(ta)) {
		if (!sameValue(value, tb[key as string], depth + 1)) return false;
	}
	for (const [key] of pairs(tb)) {
		if (ta[key as string] === undefined) return false;
	}
	return true;
}

type Props = Record<string, unknown>;

// Memoise a row whose callbacks are fresh closures each parent render.
// The outer wrapper always renders (no host instances, just a ref write) and passes the memoised
// row stable trampolines that call the latest callback, so a click always runs exactly what the
// parent passed this render. `same` decides redraws from the data props only.
export function memoRow<P extends object>(
	impl: (props: P) => React.Element | undefined,
	callbackKeys: ReadonlyArray<keyof P & string>,
	same: (prev: P, incoming: P) => boolean,
): (props: P) => React.Element {
	const inner = React.memo(impl as unknown as React.FunctionComponent<P>, (prev, incoming) => same(prev as P, incoming as P));
	return (props: P) => {
		const latest = React.useRef(props);
		latest.current = props;
		const stable = React.useMemo(() => {
			const out: Props = {};
			for (const key of callbackKeys) {
				out[key] = (...args: unknown[]) => {
					const fn = (latest.current as Props)[key] as ((...a: unknown[]) => unknown) | undefined;
					if (fn !== undefined) return fn(...args);
				};
			}
			return out;
		}, []);
		const passed: Props = {};
		for (const [key, value] of pairs(props as Props)) passed[key as string] = value;
		for (const key of callbackKeys) {
			// keep "no callback" meaning the same as before
			if ((props as Props)[key] !== undefined) passed[key] = stable[key];
		}
		return React.createElement(inner as unknown as React.FunctionComponent<Props>, passed) as unknown as React.Element;
	};
}

// compare the listed props with sameValue
export function sameFields<P extends object>(keys: ReadonlyArray<keyof P & string>) {
	return (prev: P, incoming: P): boolean => {
		for (const key of keys) {
			if (!sameValue((prev as Props)[key], (incoming as Props)[key])) return false;
		}
		return true;
	};
}

// wrap a row so each real render (memo miss) shows on the dev redraw counter as `row:<name>`
export function counted<P>(name: string, impl: (props: P) => React.Element | undefined): (props: P) => React.Element | undefined {
	const label = `row:${name}`;
	return (props: P) => {
		countRowRedraw(label);
		return impl(props);
	};
}
