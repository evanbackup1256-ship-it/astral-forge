// pretty-react-hooks, loaded defensively: every hook falls back to a no-op (or a plain callable)
// when the package is missing, so pages never fail to render over a vendored helper.
const ReplicatedStorage = game.GetService("ReplicatedStorage");

type Fn = (...args: unknown[]) => unknown;

function childOf(parent: unknown, name: string): Instance | undefined {
	if (!typeIs(parent, "Instance")) {
		return undefined;
	}
	return parent.FindFirstChild(name);
}

const include = childOf(ReplicatedStorage, "rbxts_include");
let importTsModule: ((module: Instance) => unknown) | undefined;
{
	const importScript = childOf(include, "TSImport");
	if (importScript !== undefined && importScript.IsA("ModuleScript")) {
		const [ok, loadedFn] = pcall(require, importScript);
		if (ok && typeIs(loadedFn, "function")) {
			importTsModule = loadedFn as (module: Instance) => unknown;
		}
	}
}
const packages = childOf(childOf(include, "node_modules"), "@rbxts");
const hooksPackage = childOf(packages, "pretty-react-hooks");
const hooksRoot = childOf(hooksPackage, "out");
const loaded = new Map<string, Record<string, unknown> | false>();

function resolveHookScript(folder: string): ModuleScript | undefined {
	const hookRoot = childOf(hooksRoot, folder);
	if (hookRoot === undefined) {
		return undefined;
	}
	if (hookRoot.IsA("ModuleScript")) {
		return hookRoot;
	}
	const initScript = childOf(hookRoot, "init");
	if (initScript !== undefined && initScript.IsA("ModuleScript")) {
		return initScript;
	}
	return undefined;
}

function load(folder: string): Record<string, unknown> | undefined {
	const existing = loaded.get(folder);
	if (existing !== undefined) {
		if (existing === false) {
			return undefined;
		}
		return existing;
	}
	const moduleScript = resolveHookScript(folder);
	if (moduleScript === undefined || importTsModule === undefined) {
		loaded.set(folder, false);
		return undefined;
	}
	const [ok, pkg] = pcall(importTsModule, moduleScript);
	if (!ok || !typeIs(pkg, "table")) {
		loaded.set(folder, false);
		return undefined;
	}
	loaded.set(folder, pkg as Record<string, unknown>);
	return pkg as Record<string, unknown>;
}

function hookFunction(folder: string, name: string): Fn | undefined {
	const pkg = load(folder);
	if (!typeIs(pkg, "table")) {
		return undefined;
	}
	const fn = pkg[name];
	if (!typeIs(fn, "function")) {
		return undefined;
	}
	return fn as Fn;
}

function callable(callback: unknown): unknown {
	const invoke = (...args: unknown[]) => {
		if (typeIs(callback, "function")) {
			return (callback as Fn)(...args);
		}
		return undefined;
	};
	return setmetatable(
		{
			run: invoke,
			flush: () => {},
			cancel: () => {},
		},
		{
			__call: (_self: unknown, ...args: unknown[]) => invoke(...args),
		} as LuaMetatable<object>,
	);
}

function useLatestCallback(callback: unknown): unknown {
	const fn = hookFunction("use-latest-callback", "useLatestCallback");
	if (fn === undefined) {
		return callable(callback);
	}
	return fn(callback);
}

function useDebounceCallback(callback: unknown, options?: unknown): unknown {
	const fn = hookFunction("use-debounce-callback", "useDebounceCallback");
	if (fn === undefined) {
		return callable(callback);
	}
	return fn(callback, options);
}

function useDebounceState(initialState: unknown, options?: unknown): LuaTuple<[unknown, unknown]> {
	const fn = hookFunction("use-debounce-state", "useDebounceState");
	if (fn === undefined) {
		return $tuple(initialState, () => {});
	}
	return (fn as (...args: unknown[]) => LuaTuple<[unknown, unknown]>)(initialState, options);
}

function usePrevious(value: unknown, predicate?: unknown): unknown {
	const fn = hookFunction("use-previous", "usePrevious");
	if (fn === undefined) {
		return undefined;
	}
	return fn(value, predicate);
}

function useMountEffect(callback: () => void): unknown {
	const fn = hookFunction("use-mount-effect", "useMountEffect");
	if (fn === undefined) {
		return undefined;
	}
	return fn(callback);
}

function useUpdateEffect(effect: unknown, dependencies?: unknown): unknown {
	const fn = hookFunction("use-update-effect", "useUpdateEffect");
	if (fn === undefined) {
		return undefined;
	}
	return fn(effect, dependencies);
}

function useUnmountEffect(callback: unknown): unknown {
	const fn = hookFunction("use-unmount-effect", "useUnmountEffect");
	if (fn === undefined) {
		return undefined;
	}
	return fn(callback);
}

function useDeferEffect(callback: unknown, dependencies?: unknown): unknown {
	const fn = hookFunction("use-defer-effect", "useDeferEffect");
	if (fn === undefined) {
		return undefined;
	}
	return fn(callback, dependencies);
}

function useEventListener(event: unknown, listener: unknown, options?: unknown): unknown {
	const fn = hookFunction("use-event-listener", "useEventListener");
	if (fn === undefined) {
		return undefined;
	}
	return fn(event, listener, options);
}

function useThrottleCallback(callback: unknown, options?: unknown): unknown {
	const fn = hookFunction("use-throttle-callback", "useThrottleCallback");
	if (fn === undefined) {
		return callable(callback);
	}
	return fn(callback, options);
}

function useTimeout(callback: () => void, delay?: number): unknown {
	const fn = hookFunction("use-timeout", "useTimeout");
	if (fn === undefined) {
		return undefined;
	}
	return fn(callback, delay);
}

function useInterval(callback: unknown, delay?: number, options?: unknown): unknown {
	const fn = hookFunction("use-interval", "useInterval");
	if (fn === undefined) {
		return undefined;
	}
	return fn(callback, delay, options);
}

export {
	useLatestCallback,
	useDebounceCallback,
	useDebounceState,
	usePrevious,
	useMountEffect,
	useUpdateEffect,
	useUnmountEffect,
	useDeferEffect,
	useEventListener,
	useThrottleCallback,
	useTimeout,
	useInterval,
};
