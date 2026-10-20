// Helpers shared by the server services: Luau truthiness, loose numbers, and typed kit lookups.

export function SharedFolder(): Instance {
	return game.GetService("ReplicatedStorage").WaitForChild("AstralForge").WaitForChild("Shared");
}

// Luau truthiness: only nil and false are falsy (0 and "" are truthy).
export function truthy<T>(value: T): value is Exclude<T, undefined | false> {
	return value !== undefined && (value as unknown) !== false;
}

export type Dict = Record<string, unknown>;

// A real, finite number (not NaN or +/-inf).
export function isFiniteNumber(value: unknown): value is number {
	return typeIs(value, "number") && value === value && value !== math.huge && value !== -math.huge;
}

// Deep copy of a Luau table (keys and values); non-tables are returned as-is.
export function deepCopy(value: unknown): unknown {
	if (!typeIs(value, "table")) return value;
	const result: Dict = {};
	for (const [key, child] of pairs(value)) {
		result[deepCopy(key) as string] = deepCopy(child);
	}
	return result;
}

export function isTable(value: unknown): value is Dict {
	return typeIs(value, "table");
}

// tonumber(x) that accepts any value, like Luau's.
export function num(value: unknown): number | undefined {
	return tonumber(value as string);
}

export interface ModuleLogApi {
	Info: (this: void, scope: string, message: string, params?: Dict) => void;
	Warn: (this: void, scope: string, message: string, params?: Dict) => void;
	Error: (this: void, scope: string, message: string, params?: Dict) => void;
	Fatal: (this: void, scope: string, message: string, params?: Dict) => void;
	Network: (this: void, scope: string, message: string, params?: Dict) => void;
	Debug: (this: void, scope: string, message: string, params?: Dict) => void;
	Once: (this: void, key: string, scope: string, message: string) => boolean;
	Every: (this: void, key: string, seconds: number, scope: string, message: string) => boolean;
	Player: (this: void, player: Player, message: string) => void;
	Require: (this: void, moduleScript: ModuleScript, label: string) => unknown;
	AttachTelemetry: (this: void, service: unknown) => void;
}

export type LoadService = (this: void, name: string) => unknown;

// require() of a ModuleScript found at runtime, typed by the caller.
export function req<T>(instance: Instance): T {
	return require(instance as ModuleScript) as T;
}

// A flux amount: a plain number, or "1.23e456" once it outgrows a double.
export type Flux = number | string;

// Dot-called members of the EconomyMath kit's "Economy" module.
export interface EconomyApi {
	Max: (this: void, a: unknown, b: unknown) => Flux;
	Min: (this: void, a: unknown, b: unknown) => Flux;
	Add: (this: void, a: unknown, b: unknown) => Flux;
	Sub: (this: void, a: unknown, b: unknown) => Flux;
	Mul: (this: void, a: unknown, b: unknown) => Flux;
	Div: (this: void, a: unknown, b: unknown) => Flux;
	Gt: (this: void, a: unknown, b: unknown) => boolean;
	Ge: (this: void, a: unknown, b: unknown) => boolean;
	Lt: (this: void, a: unknown, b: unknown) => boolean;
	Le: (this: void, a: unknown, b: unknown) => boolean;
	Eq: (this: void, a: unknown, b: unknown) => boolean;
	Capacity: (this: void, profile: unknown, now?: number) => Flux;
	Production: (this: void, profile: unknown, now?: number) => Flux;
	OfflineHours: (this: void, profile: unknown) => number;
	[member: string]: unknown;
}

export function economyKit(name: string): unknown {
	const kit = require(script.Parent!.Parent!.WaitForChild("Modules").WaitForChild("EconomyMath") as ModuleScript) as (
		this: void,
		member: string,
	) => unknown;
	return kit(name);
}

export function tradeSuiteKit(name: string): unknown {
	const kit = require(script.Parent!.Parent!.WaitForChild("Modules").WaitForChild("TradeSuite") as ModuleScript) as (
		this: void,
		member: string,
	) => unknown;
	return kit(name);
}

export function sharedDataKit(name: string): unknown {
	const kit = require(SharedFolder().WaitForChild("SharedData") as ModuleScript) as (this: void, member: string) => unknown;
	return kit(name);
}

export function d(value: unknown): Dict {
	return value as Dict;
}

