// Memoised selectors. createSelector caches on the identity of each input, so a derived value is
// only rebuilt when one of the slices it reads actually changed.

export type Selector<S, T> = (state: S) => T;

export function createSelector<S, A, T>(input: Selector<S, A>, combine: (a: A) => T): Selector<S, T>;
export function createSelector<S, A, B, T>(inputs: [Selector<S, A>, Selector<S, B>], combine: (a: A, b: B) => T): Selector<S, T>;
export function createSelector<S, A, B, C, T>(
	inputs: [Selector<S, A>, Selector<S, B>, Selector<S, C>],
	combine: (a: A, b: B, c: C) => T,
): Selector<S, T>;
export function createSelector<S, T>(inputs: unknown, combine: (...args: Array<unknown>) => T): Selector<S, T> {
	const list = (typeIs(inputs, "function") ? [inputs] : inputs) as Array<Selector<S, unknown>>;
	let lastArgs: Array<unknown> | undefined;
	let lastValue: T;
	return (state: S) => {
		const args = list.map((selector) => selector(state));
		if (lastArgs !== undefined && lastArgs.size() === args.size()) {
			let same = true;
			for (let i = 0; i < args.size(); i++) {
				if (args[i] !== lastArgs[i]) {
					same = false;
					break;
				}
			}
			if (same) {
				return lastValue;
			}
		}
		lastArgs = args;
		lastValue = combine(...args);
		return lastValue;
	};
}

// One-level comparison for selectors that return a fresh table of stable fields.
export function shallowEqual<T>(left: T, right: T): boolean {
	if (left === right) {
		return true;
	}
	if (!typeIs(left, "table") || !typeIs(right, "table")) {
		return false;
	}
	const a = left as unknown as Record<string, unknown>;
	const b = right as unknown as Record<string, unknown>;
	for (const [key, value] of pairs(a)) {
		if (b[key] !== value) {
			return false;
		}
	}
	for (const [key] of pairs(b)) {
		if (a[key] === undefined) {
			return false;
		}
	}
	return true;
}
