import React from "@rbxts/react";
// Shared helpers for the page views ported from the pre-migration Luau.

export interface LuaObj {
	[key: string]: LuaObj;
	(...args: unknown[]): unknown;
}
export interface Colon {
	[key: string]: (this: Colon, ...args: unknown[]) => unknown;
}
export function colon(value: unknown): Colon {
	return value as Colon;
}
export function luaProp(object: unknown, key: string): unknown {
	// A missing row is nil. Indexing it throws; the Luau views treated that as absent.
	const kind = typeOf(object);
	if (kind === "nil" || kind === "number" || kind === "boolean") {
		return undefined;
	}
	return (object as LuaObj)[key];
}
export function luaIndex(object: unknown, index: unknown): unknown {
	const kind = typeOf(object);
	if (kind === "nil" || kind === "number" || kind === "boolean") {
		return undefined;
	}
	return (object as LuaObj)[index as unknown as string];
}
export function luaSet(object: unknown, key: string, value: unknown): void {
	(object as LuaObj)[key] = value as unknown as LuaObj;
}
export function luaSetIndex(object: unknown, index: unknown, value: unknown): void {
	(object as LuaObj)[index as unknown as string] = value as unknown as LuaObj;
}
export function luaCall(fn: unknown, ...args: unknown[]): unknown {
	return (fn as LuaObj)(...args);
}
export function len(value: unknown): number {
	return (value as Array<unknown>).size();
}
export function concat(left: unknown, right: unknown): string {
	return `${left}${right}`;
}
export function luaTruthy(value: unknown): boolean {
	// Luau truthiness: only nil and false are falsy (0 and "" are truthy).
	return value !== undefined && value !== false;
}
export function luaTypeIs(value: unknown, typeName: string): boolean {
	return typeIs(value, typeName as never);
}
export const reactLoose = React as unknown as Record<string, (...args: unknown[]) => unknown>;
export interface LuaTableOps {
	insert: (list: unknown, a?: unknown, b?: unknown) => unknown;
	concat: (list: unknown, sep?: unknown, i?: unknown, j?: unknown) => unknown;
	find: (list: unknown, value: unknown, init?: unknown) => unknown;
	move: (src: unknown, a: unknown, b: unknown, t: unknown, dst?: unknown) => unknown;
	remove: (list: unknown, pos?: unknown) => unknown;
	unpack: (list: unknown, i?: unknown, j?: unknown) => unknown;
}
export const luaTable = table as unknown as LuaTableOps;

// Module loading shared by the ported views (they all sit in this folder, so script-relative
// paths resolve the same from here).
const AstralForge = script.Parent!.Parent!.Parent!;
export function luaRequire(moduleScript: unknown): unknown {
	return require(moduleScript as ModuleScript) as unknown;
}
export function instChild(parent: Instance, name: string): Instance {
	return (parent as unknown as Record<string, Instance>)[name];
}
export function kit(name: string, member: string): unknown {
	return luaCall(luaRequire(AstralForge.WaitForChild(name) as ModuleScript), member);
}
export function mod(...names: string[]): unknown {
	let current: Instance = AstralForge;
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}

/** Stable: items matching `pinned` move to the front, everything else keeps its order. */
export function pinFirst(list: unknown[] | undefined, pinned: (item: unknown) => boolean): unknown[] {
	const front: defined[] = [];
	const rest: defined[] = [];
	for (const item of (list ?? []) as defined[]) {
		(pinned(item) ? front : rest).push(item);
	}
	for (const item of rest) {
		front.push(item);
	}
	return front;
}
