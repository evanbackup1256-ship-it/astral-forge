// Typed loader for the vendored @rbxts/lunit package: it ships inside rbxts_include at runtime
// but has no published typings, so the client tests describe the slice they use here. Assert's
// members are plain methods, so Assert.equal(...) emits the Assert:equal(...) the Luau expects.
interface AssertApi {
	equal(actual: unknown, expected: unknown, message?: unknown): void;
	notEqual(actual: unknown, expected: unknown, message?: unknown): void;
	deepEqual(actual: unknown, expected: unknown, message?: unknown): void;
	notDeepEqual(actual: unknown, expected: unknown, message?: unknown): void;
	"true"(actual: unknown, message?: unknown): void;
	"false"(actual: unknown, message?: unknown): void;
	undefined(actual: unknown, message?: unknown): void;
	notUndefined(actual: unknown, message?: unknown): void;
	greaterThan(actual: unknown, threshold: unknown, message?: unknown): void;
	greaterThanOrEqual(actual: unknown, threshold: unknown, message?: unknown): void;
	lessThan(actual: unknown, threshold: unknown, message?: unknown): void;
	lessThanOrEqual(actual: unknown, threshold: unknown, message?: unknown): void;
	between(actual: unknown, min: unknown, max: unknown, message?: unknown): void;
	approximately(actual: number, expected: number, epsilon?: number, message?: unknown): void;
	empty(array: ReadonlyArray<unknown>, message?: unknown): void;
	notEmpty(array: ReadonlyArray<unknown>, message?: unknown): void;
	contains(array: ReadonlyArray<unknown>, elementOrPredicate: unknown, message?: unknown): void;
	doesNotContain(array: ReadonlyArray<unknown>, elementOrPredicate: unknown, message?: unknown): void;
	match(actual: string, pattern: string, message?: unknown): void;
	throws(callback: () => unknown, message?: unknown): void;
	[key: string]: unknown;
}

type TestDecorator = (
	target: object,
	propertyKey: unknown,
	descriptor: TypedPropertyDescriptor<() => void>,
) => TypedPropertyDescriptor<() => void> | void;

interface TestRun {
	run(options?: unknown): unknown;
	[key: string]: unknown;
}
interface TestRunnerApi {
	new (): TestRun;
	fromClasses(classes: ReadonlyArray<unknown>): TestRun;
	[key: string]: unknown;
}
interface LunitApi {
	Assert: AssertApi;
	Test: TestDecorator;
	TestRunner: TestRunnerApi;
	[key: string]: unknown;
}

const lunit = require(
	game
		.GetService("ReplicatedStorage")
		.WaitForChild("rbxts_include")
		.WaitForChild("node_modules")
		.WaitForChild("@rbxts")
		.WaitForChild("lunit") as ModuleScript,
) as LunitApi;

export const Assert = lunit.Assert;
export const Test = lunit.Test;
export const TestRunner = lunit.TestRunner;
