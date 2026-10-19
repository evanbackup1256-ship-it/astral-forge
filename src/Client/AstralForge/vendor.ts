// Packages that are vendored as Luau with no TypeScript typings. Each is loaded from the same
// instance the Luau code requires, with just enough of its API typed for our use.

const scope = game
	.GetService("ReplicatedStorage")
	.WaitForChild("rbxts_include")
	.WaitForChild("node_modules")
	.WaitForChild("@rbxts");

function vendored<T>(name: string): T {
	return require(scope.WaitForChild(name) as ModuleScript) as T;
}

// ---------- rodux ----------
export interface RoduxConnection {
	disconnect(): void;
}
export interface RoduxStore<S, A> {
	getState(): S;
	dispatch(action: A): A;
	destruct(): void;
	changed: { connect(callback: (nextState: S, previousState: S) => void): RoduxConnection };
}
export interface Rodux {
	Store: { new: <S, A>(reducer: (state: S | undefined, action: A) => S, initialState?: S) => RoduxStore<S, A> };
}
export const Rodux = vendored<Rodux>("rodux");

// ---------- flipper ----------
export interface FlipperGoal {
	_targetValue: number;
	_frequency?: number;
	_dampingRatio?: number;
}
export interface FlipperSingleMotor {
	onStep(callback: (value: number) => void): unknown;
	onComplete(callback: () => void): unknown;
	getValue(): number;
	setGoal(goal: FlipperGoal): void;
	step(deltaTime: number): boolean;
	stop(): void;
	destroy(): void;
}
export interface Flipper {
	SingleMotor: { new: (initial: number, useImplicitConnections?: boolean) => FlipperSingleMotor };
	Spring: { new: (target: number, options: { frequency: number; dampingRatio: number }) => FlipperGoal };
	Instant: { new: (target: number) => FlipperGoal };
}
export const Flipper = vendored<Flipper>("flipper");

// ---------- spr ----------
export interface Spr {
	target(this: void, instance: Instance, dampingRatio: number, frequency: number, properties: Record<string, unknown>): void;
	stop(this: void, instance: Instance, property?: string): void;
}
export function loadSpr(): Spr {
	return require(scope.WaitForChild("spr").WaitForChild("spr") as ModuleScript) as Spr;
}

// ---------- react-ripple ----------
export interface RippleMotion {
	setGoal(goal: number, options?: { frequency?: number; dampingRatio?: number }): void;
}
export interface ReactRipple {
	useSpring(this: void, initial: number, options: { start?: boolean; frequency?: number; dampingRatio?: number }): LuaTuple<[unknown, RippleMotion]>;
}
export function loadReactRipple(): ReactRipple {
	return require(scope.WaitForChild("react-ripple").WaitForChild("src") as ModuleScript) as ReactRipple;
}

// ---------- TSImport (packages published as roblox-ts output) ----------
export function importTsModule<T>(module: Instance): T {
	const importer = require(scope.Parent!.Parent!.WaitForChild("TSImport") as ModuleScript) as (target: Instance) => T;
	return importer(module);
}

export function vendoredTs<T>(name: string): T {
	return importTsModule<T>(scope.WaitForChild(name));
}
