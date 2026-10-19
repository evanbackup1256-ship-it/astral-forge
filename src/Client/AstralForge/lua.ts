import React from "@rbxts/react";

// Luau truthiness: only nil and false are falsy. roblox-ts treats 0, "" and NaN as falsy too,
// so code ported from Luau uses this wherever a value may be a number or a string.
export function truthy<T>(value: T): value is Exclude<T, undefined | false> {
	return value !== undefined && (value as unknown) !== false;
}

export type Dict = Record<string, unknown>;

export function isTable(value: unknown): value is Dict {
	return typeIs(value, "table");
}

// ---------- React binding helpers (added for the UiCore port) ----------
// A prop that may be a plain value or a React binding of it.
export type Bindable<T> = T | React.Binding<T>;

// React.joinBindings over an array, typed as a tuple: joinTuple(a, b).map(([x, y]) => ...).
// Same runtime call as Luau's React.joinBindings({ a, b }).
export function joinTuple<T extends unknown[]>(...bindings: { [K in keyof T]: React.Binding<T[K]> }): React.Binding<T> {
	return React.joinBindings(bindings as unknown as ReadonlyArray<React.Binding<unknown>>) as unknown as React.Binding<T>;
}
// Instance Name as a JSX prop (react-roblox applies it, but the typings omit it): <frame {...named("X")} />
export function named(name: string): object {
	return { Name: name };
}

// Shared/OmegaMath (big-number currency math), as the client calls it. Values are numbers or encoded strings.
export type OmegaValue = number | string;
export interface OmegaMathApi {
	Gt(this: void, a: unknown, b: unknown): boolean;
	Gte(this: void, a: unknown, b: unknown): boolean;
	Lt(this: void, a: unknown, b: unknown): boolean;
	Lte(this: void, a: unknown, b: unknown): boolean;
	Compare(this: void, a: unknown, b: unknown): number;
	ToNumber(this: void, value: unknown): number;
	Add(this: void, a: unknown, b: unknown): OmegaValue;
	Sub(this: void, a: unknown, b: unknown): OmegaValue;
	Mul(this: void, a: unknown, b: unknown): OmegaValue;
	Div(this: void, a: unknown, b: unknown): OmegaValue;
	Pow(this: void, a: unknown, b: unknown): OmegaValue;
	Max(this: void, a: unknown, b: unknown): OmegaValue;
	Min(this: void, a: unknown, b: unknown): OmegaValue;
	Floor(this: void, value: unknown): OmegaValue;
	Log10(this: void, value: unknown): number;
	GeometricSum(this: void, base: unknown, scale: unknown, level: number, count: number): OmegaValue;
	ScaledCost(this: void, base: unknown, scale: unknown, level: number): OmegaValue;
	AffordableCount(this: void, base: unknown, scale: unknown, level: number, cash: unknown, remaining: number): number;
	[key: string]: unknown;
}
