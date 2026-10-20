import React from "@rbxts/react";
import ReactRoblox from "@rbxts/react-roblox";

interface LuaObj {
	[key: string]: LuaObj;
	(...args: unknown[]): unknown;
}
interface Colon {
	[key: string]: (this: Colon, ...args: unknown[]) => unknown;
}
function colon(value: unknown): Colon {
	return value as Colon;
}
function luaProp(object: unknown, key: string): unknown {
	return (object as LuaObj)[key];
}
function luaIndex(object: unknown, index: unknown): unknown {
	return (object as LuaObj)[index as unknown as string];
}
function luaSet(object: unknown, key: string, value: unknown): void {
	(object as LuaObj)[key] = value as unknown as LuaObj;
}
function luaSetIndex(object: unknown, index: unknown, value: unknown): void {
	(object as LuaObj)[index as unknown as string] = value as unknown as LuaObj;
}
function luaCall(fn: unknown, ...args: unknown[]): unknown {
	return (fn as LuaObj)(...args);
}
function len(value: unknown): number {
	return (value as Array<unknown>).size();
}
function concat(left: unknown, right: unknown): string {
	return `${left}${right}`;
}
function luaTypeIs(value: unknown, typeName: string): boolean {
	return typeIs(value, typeName as never);
}
const reactLoose = React as unknown as Record<string, (...args: unknown[]) => unknown>;
interface LuaTableOps {
	insert: (list: unknown, a?: unknown, b?: unknown) => unknown;
	concat: (list: unknown, sep?: unknown, i?: unknown, j?: unknown) => unknown;
	find: (list: unknown, value: unknown, init?: unknown) => unknown;
	move: (src: unknown, a: unknown, b: unknown, t: unknown, dst?: unknown) => unknown;
	remove: (list: unknown, pos?: unknown) => unknown;
	unpack: (list: unknown, i?: unknown, j?: unknown) => unknown;
}
const luaTable = table as unknown as LuaTableOps;
function luaRequire(moduleScript: unknown): unknown {
	return require(moduleScript as ModuleScript) as unknown;
}
function instChild(parent: Instance, name: string): Instance {
	return (parent as unknown as Record<string, Instance>)[name];
}

const AstralForge = script.Parent!;

function kit(name: string, member: string): unknown {
	return luaCall(luaRequire(AstralForge.WaitForChild(name) as ModuleScript), member);
}
function mod(...names: string[]): unknown {
	let current: Instance = AstralForge;
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}
function modRel(ups: number, ...names: string[]): unknown {
	let current: Instance = script;
	for (let i = 0; i < ups; i++) {
		current = current.Parent!;
	}
	for (const name of names) {
		current = current.WaitForChild(name);
	}
	return luaRequire(current as ModuleScript);
}

const __defs: Record<string, () => unknown> = {};
const __cache: Record<string, { value: unknown }> = {};
const __loading: Record<string, boolean> = {};

function __load(name: string): unknown {
	const hit = __cache[name];
	if (hit !== undefined) {
		return hit.value;
	}
	const def = __defs[name];
	if (def === undefined) {
		error(`ReactHosts: unknown module ${tostring(name)}`, 2);
	}
	if (__loading[name]) {
		error(`ReactHosts: cyclic require of member ${name}`, 2);
	}
	__loading[name] = true;
	const [ok, value] = pcall(def) as LuaTuple<[unknown, unknown]>;
	delete __loading[name];
	if (ok !== true) {
		error(value, 0);
	}
	__cache[name] = { value };
	return value;
}

__defs["reactModules"] = () => {
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	function childOf(parent?: unknown, name?: unknown): unknown | undefined {
		if ((typeOf(parent) !== "Instance")) {
			return undefined;
		}
		return colon(parent).FindFirstChild(name);
		return undefined;
	}
	let include: unknown = luaCall(childOf, ReplicatedStorage, "rbxts_include");
	let importTsModule: unknown = undefined;
	{
			let importScript: unknown = luaCall(childOf, include, "TSImport");
			if (((importScript !== undefined) && colon(importScript).IsA("ModuleScript"))) {
				let ok: unknown;
				let loaded: unknown;
				[ok, loaded] = luaCall(pcall, require, importScript) as LuaTuple<[unknown, unknown]>;
				if ((ok && (luaTypeIs(loaded, "function")))) {
					importTsModule = loaded;
				}
			}
		}
	let packages: unknown = luaCall(childOf, luaCall(childOf, include, "node_modules"), "@rbxts");
	let hooksPackage: unknown = luaCall(childOf, packages, "pretty-react-hooks");
	let hooksRoot: unknown = luaCall(childOf, hooksPackage, "out");
	let loaded: unknown = {};
	function resolveHookScript(folder?: unknown): unknown | undefined {
		let hookRoot: unknown = luaCall(childOf, hooksRoot, folder);
		if ((hookRoot === undefined)) {
			return undefined;
		}
		if (colon(hookRoot).IsA("ModuleScript")) {
			return hookRoot;
		}
		let initScript: unknown = luaCall(childOf, hookRoot, "init");
		if (((initScript !== undefined) && colon(initScript).IsA("ModuleScript"))) {
			return initScript;
		}
		return undefined;
		return undefined;
	}
	function load(folder?: unknown): unknown | undefined {
		let existing: unknown = luaIndex(loaded, folder);
		if ((existing !== undefined)) {
			if ((existing === false)) {
				return undefined;
			}
			return existing;
		}
		let moduleScript: unknown = luaCall(resolveHookScript, folder);
		if (((moduleScript === undefined) || (importTsModule === undefined))) {
			luaSetIndex(loaded, folder, false);
			return undefined;
		}
		let ok: unknown;
		let pkg: unknown;
		[ok, pkg] = luaCall(pcall, importTsModule, moduleScript) as LuaTuple<[unknown, unknown]>;
		if (((!ok) || (!luaTypeIs(pkg, "table")))) {
			luaSetIndex(loaded, folder, false);
			return undefined;
		}
		luaSetIndex(loaded, folder, pkg);
		return pkg;
		return undefined;
	}
	function hookFunction(folder?: unknown, name?: unknown): unknown | undefined {
		let pkg: unknown = luaCall(load, folder);
		if ((!luaTypeIs(pkg, "table"))) {
			return undefined;
		}
		let fn: unknown = luaIndex(pkg, name);
		if ((!luaTypeIs(fn, "function"))) {
			return undefined;
		}
		return fn;
		return undefined;
	}
	function callable(callback?: unknown): unknown | undefined {
		let invoke: unknown = function(...args: unknown[]): unknown | undefined {
			if ((luaTypeIs(callback, "function"))) {
				return luaCall(callback, ...args);
			}
			return undefined;
			return undefined;
		};
		return luaCall(setmetatable, { run: invoke, flush: function(): unknown | undefined {

			return undefined;
		}, cancel: function(): unknown | undefined {

			return undefined;
		} }, { __call: function(_?: unknown, ...args: unknown[]): unknown | undefined {
			return luaCall(invoke, ...args);
			return undefined;
		} });
		return undefined;
	}
	function useLatestCallback(callback?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-latest-callback", "useLatestCallback");
		if ((fn === undefined)) {
			return luaCall(callable, callback);
		}
		return luaCall(fn, callback);
		return undefined;
	}
	function useDebounceCallback(callback?: unknown, options?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-debounce-callback", "useDebounceCallback");
		if ((fn === undefined)) {
			return luaCall(callable, callback);
		}
		return luaCall(fn, callback, options);
		return undefined;
	}
	function useDebounceState(initialState?: unknown, options?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-debounce-state", "useDebounceState");
		if ((fn === undefined)) {
			return $tuple(initialState, function(): unknown | undefined {

				return undefined;
			});
		}
		return luaCall(fn, initialState, options);
		return undefined;
	}
	function usePrevious(value?: unknown, predicate?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-previous", "usePrevious");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, value, predicate);
		return undefined;
	}
	function useMountEffect(callback?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-mount-effect", "useMountEffect");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, callback);
		return undefined;
	}
	function useUpdateEffect(effect?: unknown, dependencies?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-update-effect", "useUpdateEffect");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, effect, dependencies);
		return undefined;
	}
	function useUnmountEffect(callback?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-unmount-effect", "useUnmountEffect");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, callback);
		return undefined;
	}
	function useDeferEffect(callback?: unknown, dependencies?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-defer-effect", "useDeferEffect");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, callback, dependencies);
		return undefined;
	}
	function useEventListener(event?: unknown, listener?: unknown, options?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-event-listener", "useEventListener");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, event, listener, options);
		return undefined;
	}
	function useThrottleCallback(callback?: unknown, options?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-throttle-callback", "useThrottleCallback");
		if ((fn === undefined)) {
			return luaCall(callable, callback);
		}
		return luaCall(fn, callback, options);
		return undefined;
	}
	function useTimeout(callback?: unknown, delay?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-timeout", "useTimeout");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, callback, delay);
		return undefined;
	}
	function useInterval(callback?: unknown, delay?: unknown, options?: unknown): unknown | undefined {
		let fn: unknown = luaCall(hookFunction, "use-interval", "useInterval");
		if ((fn === undefined)) {
			return undefined;
		}
		return luaCall(fn, callback, delay, options);
		return undefined;
	}
	return { useLatestCallback: useLatestCallback, useDebounceCallback: useDebounceCallback, useDebounceState: useDebounceState, usePrevious: usePrevious, useMountEffect: useMountEffect, useUpdateEffect: useUpdateEffect, useUnmountEffect: useUnmountEffect, useDeferEffect: useDeferEffect, useEventListener: useEventListener, useThrottleCallback: useThrottleCallback, useTimeout: useTimeout, useInterval: useInterval };
};

__defs["vendorHost"] = () => {
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	function childOf(parent?: unknown, name?: unknown): unknown | undefined {
		if ((typeOf(parent) !== "Instance")) {
			return undefined;
		}
		return colon(parent).FindFirstChild(name);
		return undefined;
	}
	function requireChild(parent?: unknown, name?: unknown): unknown | undefined {
		let child: unknown = luaCall(childOf, parent, name);
		if (((child === undefined) || (!colon(child).IsA("ModuleScript")))) {
			return undefined;
		}
		let ok: unknown;
		let loaded: unknown;
		[ok, loaded] = luaCall(pcall, require, child) as LuaTuple<[unknown, unknown]>;
		if (((!ok) || (!luaTypeIs(loaded, "table")))) {
			return undefined;
		}
		return loaded;
		return undefined;
	}
	function moduleScript(parent?: unknown, name?: unknown): unknown | undefined {
		let child: unknown = luaCall(childOf, parent, name);
		if ((child === undefined)) {
			return undefined;
		}
		if (colon(child).IsA("ModuleScript")) {
			return child;
		}
		let initScript: unknown = luaCall(childOf, child, "init");
		if (((initScript !== undefined) && colon(initScript).IsA("ModuleScript"))) {
			return initScript;
		}
		return undefined;
		return undefined;
	}
	let include: unknown = luaCall(childOf, ReplicatedStorage, "rbxts_include");
	let nodes: unknown = luaCall(childOf, luaCall(childOf, include, "node_modules"), "@rbxts");
	let importScript: unknown = luaCall(childOf, include, "TSImport");
	let importTsModule: unknown = undefined;
	if (((importScript !== undefined) && colon(importScript).IsA("ModuleScript"))) {
		let ok: unknown;
		let loaded: unknown;
		[ok, loaded] = luaCall(pcall, require, importScript) as LuaTuple<[unknown, unknown]>;
		if ((ok && (luaTypeIs(loaded, "function")))) {
			importTsModule = loaded;
		}
	}
	let servicesModule: unknown = luaCall(requireChild, nodes, "services");
	let Players: unknown = colon(game).GetService("Players");
	if (((servicesModule !== undefined) && (luaProp(servicesModule, "Players") !== undefined))) {
		Players = luaProp(servicesModule, "Players");
	}
	let maidModule: unknown = luaCall(requireChild, luaCall(childOf, nodes, "maid"), "Maid");
	let signalModule: unknown = luaCall(requireChild, luaCall(childOf, nodes, "lemon-signal"), "src");
	let Signal: unknown = undefined;
	if ((signalModule !== undefined)) {
		let candidate: unknown = luaProp(signalModule, "Signal");
		if ((candidate === undefined)) {
			candidate = luaProp(signalModule, "default");
		}
		if ((luaTypeIs(candidate, "table"))) {
			Signal = candidate;
		}
	}
	let matterModule: unknown = luaCall(requireChild, luaCall(childOf, nodes, "matter"), "lib");
	let PageVisit: unknown = undefined;
	let world: unknown = undefined;
	let session: unknown = undefined;
	luaCall(pcall, function(): unknown | undefined {
		if (((((matterModule === undefined) || (!luaTypeIs(luaProp(matterModule, "component"), "function"))) || (!luaTypeIs(luaProp(matterModule, "World"), "table"))) || (!luaTypeIs(luaProp(luaProp(matterModule, "World"), "new"), "function")))) {
			return undefined;
		}
		let visit: unknown = luaCall(luaProp(matterModule, "component"), "PageVisit");
		let nextWorld: unknown = luaCall(luaProp(luaProp(matterModule, "World"), "new"));
		let nextSession: unknown = colon(nextWorld).spawn(luaCall(visit, { page: "Overview", at: 0 }));
		PageVisit = visit;
		world = nextWorld;
		session = nextSession;
		return undefined;
	});
	let maid: unknown = undefined;
	luaCall(pcall, function(): unknown | undefined {
		if (((maidModule !== undefined) && (luaTypeIs(luaProp(maidModule, "new"), "function")))) {
			maid = luaCall(luaProp(maidModule, "new"));
		}
		return undefined;
	});
	let navigated: unknown = undefined;
	luaCall(pcall, function(): unknown | undefined {
		if (((Signal !== undefined) && (luaTypeIs(luaProp(Signal, "new"), "function")))) {
			navigated = luaCall(luaProp(Signal, "new"));
		}
		return undefined;
	});
	luaCall(pcall, function(): unknown | undefined {
		if ((((maid !== undefined) && (navigated !== undefined)) && (luaTypeIs(luaProp(maid, "GiveTask"), "function")))) {
			colon(maid).GiveTask(navigated);
		}
		return undefined;
	});
	let journalState: unknown = undefined;
	let journalReady: unknown = false;
	let debouncePage: unknown = undefined;
	let journalScript: unknown = luaCall(moduleScript, luaCall(childOf, nodes, "action-journal"), "out");
	if (((journalScript !== undefined) && (luaTypeIs(importTsModule, "function")))) {
		let loadedJournal: unknown;
		let journalPkg: unknown;
		[loadedJournal, journalPkg] = luaCall(pcall, importTsModule, journalScript) as LuaTuple<[unknown, unknown]>;
		if ((((((loadedJournal && (luaTypeIs(journalPkg, "table"))) && (luaTypeIs(luaProp(journalPkg, "StateManager"), "table"))) && (luaTypeIs(luaProp(journalPkg, "ActionJournal"), "table"))) && (luaTypeIs(luaProp(luaProp(journalPkg, "StateManager"), "new"), "function"))) && (luaTypeIs(luaProp(luaProp(journalPkg, "ActionJournal"), "new"), "function")))) {
			luaCall(pcall, function(): unknown | undefined {
				let state: unknown = luaCall(luaProp(luaProp(journalPkg, "StateManager"), "new"), { page: "Overview" });
				luaCall(luaProp(luaProp(journalPkg, "ActionJournal"), "new"), state, { mode: 0, historySize: 32 });
				journalState = state;
				journalReady = true;
				return undefined;
			});
		}
	}
	function authorName(): unknown | undefined {
		let ok: unknown;
		let name: unknown;
		[ok, name] = luaCall(pcall, function(): unknown | undefined {
			let player: unknown = luaProp(Players, "LocalPlayer");
			if ((player !== undefined)) {
				return luaProp(player, "Name");
			}
			return undefined;
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		if (((ok && (luaTypeIs(name, "string"))) && (name !== ""))) {
			return name;
		}
		return "player";
		return undefined;
	}
	function record(pageId?: unknown): unknown | undefined {
		if (((journalReady && (journalState !== undefined)) && (luaTypeIs(luaProp(journalState, "setPath"), "function")))) {
			luaCall(pcall, function(): unknown | undefined {
				colon(journalState).setPath("page", pageId, luaCall(authorName));
				return undefined;
			});
		}
		if (((((world !== undefined) && (session !== undefined)) && (PageVisit !== undefined)) && (luaTypeIs(luaProp(world, "insert"), "function")))) {
			luaCall(pcall, function(): unknown | undefined {
				colon(world).insert(session, luaCall(PageVisit, { page: pageId, at: luaCall(luaProp(os, "clock")) }));
				return undefined;
			});
		}
		if (((navigated !== undefined) && (luaTypeIs(luaProp(navigated, "Fire"), "function")))) {
			luaCall(pcall, function(): unknown | undefined {
				colon(navigated).Fire(pageId);
				return undefined;
			});
		}
		return undefined;
	}
	let timersScript: unknown = luaCall(moduleScript, luaCall(childOf, nodes, "set-timeout"), "out");
	if (((timersScript !== undefined) && (luaTypeIs(importTsModule, "function")))) {
		let loadedTimers: unknown;
		let timers: unknown;
		[loadedTimers, timers] = luaCall(pcall, importTsModule, timersScript) as LuaTuple<[unknown, unknown]>;
		if (((loadedTimers && (luaTypeIs(timers, "table"))) && (luaTypeIs(luaProp(timers, "debounce"), "function")))) {
			luaCall(pcall, function(): unknown | undefined {
				debouncePage = luaCall(luaProp(timers, "debounce"), record, 0.12, { leading: true, trailing: false });
				return undefined;
			});
		}
	}
	function notePage(pageId?: unknown): unknown | undefined {
		if (((!luaTypeIs(pageId, "string")) || (pageId === ""))) {
			return undefined;
		}
		if ((debouncePage !== undefined)) {
			let ok: unknown = luaCall(pcall, debouncePage, pageId);
			if (ok) {
				return undefined;
			}
		}
		luaCall(record, pageId);
		return undefined;
	}
	function shutdown(): unknown | undefined {
		luaCall(pcall, function(): unknown | undefined {
			if (((debouncePage !== undefined) && (luaProp(debouncePage, "cancel") !== undefined))) {
				luaCall(luaProp(debouncePage, "cancel"));
			}
			return undefined;
		});
		luaCall(pcall, function(): unknown | undefined {
			if (((maid !== undefined) && (luaTypeIs(luaProp(maid, "DoCleaning"), "function")))) {
				colon(maid).DoCleaning();
			} else if (((navigated !== undefined) && (luaTypeIs(luaProp(navigated, "Destroy"), "function")))) {
				colon(navigated).Destroy();
			}
			return undefined;
		});
		debouncePage = undefined;
		journalReady = false;
		journalState = undefined;
		navigated = undefined;
		maid = undefined;
		return undefined;
	}
	return { notePage: notePage, shutdown: shutdown };
};

__defs["reactHost"] = () => {
	let reactModules: unknown = __load("reactModules");
	let notePage: unknown = luaProp(__load("vendorHost"), "notePage");
	let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
	let Palette: unknown = luaProp(kit("CoreKit", "theme"), "Palette");
	let PageHostContext: unknown = reactLoose.createContext({ page: "", retry: function(): unknown | undefined {

		return undefined;
	} });
	function onPageRender(id?: unknown, _phase?: unknown, actualDuration?: unknown): unknown | undefined {
		if (((!luaTypeIs(actualDuration, "number")) || ((actualDuration as unknown as number) < (20 as unknown as number)))) {
			return undefined;
		}
		colon(ClientLog).warnEvery(`react-slow-${id}`, 10, "React", `${id} commit took ${luaCall(luaProp(math, "floor"), actualDuration)}ms`);
		return undefined;
	}
	let PagePending: unknown = colon(luaProp(React, "PureComponent")).extend("PagePending");
	luaSet(PagePending, "render", function(self_: unknown): unknown | undefined {
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "ink"), BackgroundTransparency: 0.15, BorderSizePixel: 0 }, reactLoose.createElement("textlabel", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, Text: "Loading", TextColor3: luaProp(Palette, "cream"), TextSize: 16, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center") }));
		return undefined;
	});
	function CrashNotice(props?: unknown): unknown | undefined {
		let host: unknown = reactLoose.useContext(PageHostContext);
		let transparency: unknown;
		let setTransparency: unknown;
		[transparency, setTransparency] = reactLoose.useBinding(1) as LuaTuple<[unknown, unknown]>;
		let pressed: unknown;
		let setPressed: unknown;
		[pressed, setPressed] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		reactLoose.useDebugValue(luaProp(props, "message"));
		luaCall(luaProp(reactModules, "useMountEffect"), function(): unknown | undefined {
			luaCall(setTransparency, 0);
			return undefined;
		});
		luaCall(luaProp(reactModules, "useTimeout"), function(): unknown | undefined {
			luaCall(setPressed, false);
			return undefined;
		}, (pressed ? 0.45 : undefined));
		let retry: unknown = reactLoose.useCallback(function(): unknown | undefined {
			luaCall(setPressed, true);
			if ((luaProp(props, "onRetry") !== undefined)) {
				luaCall(luaProp(props, "onRetry"));
			} else {
				luaCall(luaProp(host, "retry"));
			}
			return undefined;
		}, [host, luaProp(props, "onRetry")]);
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundColor3: luaProp(Palette, "ink"), BackgroundTransparency: 0.08, BorderSizePixel: 0 }, reactLoose.createElement("textlabel", { Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, -32, 0, 48), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0.5, -36), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0.5), BackgroundTransparency: 1, Text: "This screen hit an error. You can open it again.", TextColor3: luaProp(Palette, "cream"), TextTransparency: transparency, TextSize: 16, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), TextWrapped: true, TextXAlignment: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center") }), reactLoose.createElement("textbutton", { Size: luaCall(luaProp(UDim2, "fromOffset"), 140, 36), Position: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0, 0.5, 28), AnchorPoint: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(0.5, 0), BackgroundColor3: (pressed ? luaProp(Palette, "panelSoft") : luaProp(Palette, "cyan")), BorderSizePixel: 0, AutoButtonColor: false, Text: "TRY AGAIN", TextColor3: luaProp(Palette, "ink"), TextSize: 14, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold")), Event: { Activated: retry } }, reactLoose.createElement("uicorner", { CornerRadius: new (UDim as unknown as new (...args: unknown[]) => unknown)(0, 8) })));
		return undefined;
	}
	let PageErrorBoundary: unknown = colon(luaProp(React, "Component")).extend("PageErrorBoundary");
	luaSet(PageErrorBoundary, "init", function(self_: unknown): unknown | undefined {
		luaSet(self_, "state", { failed: false, message: "" });
		return undefined;
	});
	luaSet(PageErrorBoundary, "getDerivedStateFromError", function(err?: unknown): unknown | undefined {
		return { failed: true, message: luaCall(tostring, err) };
		return undefined;
	});
	luaSet(PageErrorBoundary, "componentDidCatch", function(self_: unknown, err?: unknown, info?: unknown): unknown | undefined {
		let page: unknown = (luaProp(luaProp(self_, "props"), "page") || "AppShell");
		let stack: unknown = (((luaTypeIs(info, "table")) && (luaTypeIs(luaProp(info, "componentStack"), "string"))) ? luaProp(info, "componentStack") : "");
		colon(ClientLog).warnEvery(`react-page-${page}`, 5, "React", `${page}: ${luaCall(tostring, err)}${stack}`);
		return undefined;
	});
	luaSet(PageErrorBoundary, "render", function(self_: unknown): unknown | undefined {
		if (luaProp(luaProp(self_, "state"), "failed")) {
			return reactLoose.createElement(CrashNotice, { message: luaProp(luaProp(self_, "state"), "message"), onRetry: function(): unknown | undefined {
				colon(self_).setState({ failed: false, message: "" });
				return undefined;
			} });
		}
		return luaProp(luaProp(self_, "props"), "children");
		return undefined;
	});
	let PageFrame: unknown = reactLoose.memo(reactLoose.forwardRef(function(props?: unknown, ref?: unknown): unknown | undefined {
		let page: unknown = luaProp(props, "page");
		if ((page === undefined)) {
			page = "";
		}
		let retryCount: unknown;
		let bumpRetry: unknown;
		[retryCount, bumpRetry] = reactLoose.useReducer(function(count?: unknown): unknown | undefined {
			return ((count as unknown as number) + (1 as unknown as number));
			return undefined;
		}, 0) as LuaTuple<[unknown, unknown]>;
		let seenPage: unknown = reactLoose.useRef(page);
		let previousPage: unknown = luaCall(luaProp(reactModules, "usePrevious"), page);
		reactLoose.useDebugValue((((previousPage !== undefined) && (previousPage !== "")) ? `${previousPage} -> ${page}` : page));
		reactLoose.useLayoutEffect(function(): unknown | undefined {
			luaSet(seenPage, "current", page);
			return function(): unknown | undefined {
				luaSet(seenPage, "current", "");
				return undefined;
			};
			return undefined;
		}, [page]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((page === "")) {
				return undefined;
			}
			luaCall(notePage, page);
			let pending: unknown = true;
			let trailing: unknown = luaCall(luaProp(task, "delay"), 0.12, function(): unknown | undefined {
				pending = false;
				luaCall(notePage, page);
				return undefined;
			});
			return function(): unknown | undefined {
				if (pending) {
					luaCall(luaProp(task, "cancel"), trailing);
				}
				return undefined;
			};
			return undefined;
		}, [page]);
		reactLoose.useImperativeHandle(ref, function(): unknown | undefined {
			return { retry: bumpRetry, page: function(): unknown | undefined {
				return luaProp(seenPage, "current");
				return undefined;
			} };
			return undefined;
		}, [bumpRetry]);
		let contextValue: unknown = reactLoose.useMemo(function(): unknown | undefined {
			return { page: page, retry: bumpRetry };
			return undefined;
		}, [page, bumpRetry]);
		let child: unknown = reactLoose.useMemo(function(): unknown | undefined {
			let only: unknown = luaCall(luaProp(luaProp(React, "Children"), "only"), luaProp(props, "children"));
			if ((!luaCall(luaProp(React, "isValidElement"), only))) {
				return only;
			}
			return reactLoose.cloneElement(only, { key: `${page}:${retryCount}` });
			return undefined;
		}, [luaProp(props, "children"), page, retryCount]);
		return reactLoose.createElement(luaProp(PageHostContext, "Provider"), { value: contextValue }, reactLoose.createElement(luaProp(React, "Suspense"), { fallback: reactLoose.createElement(PagePending) }, reactLoose.createElement(PageErrorBoundary, { key: `${page}:${retryCount}`, page: page }, reactLoose.createElement(luaProp(React, "Profiler"), { id: ((page !== "") ? page : "Game"), onRender: onPageRender }, child))));
		return undefined;
	}));
	return { PageFrame: PageFrame, PageErrorBoundary: PageErrorBoundary, PagePending: PagePending };
};

__defs["HyperTextHost"] = () => {
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
	let _theme: unknown = kit("CoreKit", "theme");
	let darken: unknown = luaProp(_theme, "darken");
	let lighten: unknown = luaProp(_theme, "lighten");
	let Palette: unknown = luaProp(_theme, "Palette");
	let TITLE_FX_KINDS: unknown = ["wave", "fire", "ice", "glitch", "galaxy", "rainbow", "glow", "neon", "sparkle", "shake", "pulse", "gradient-shift", "holographic", "void", "plasma", "chrome", "ember", "frost", "aurora", "matrix", "static", "bounce-in", "blur-resolve", "shimmer", "toxic", "solar", "ocean", "candy", "voltage", "prism", "phantom", "eclipse", "nebula", "molten", "circuit", "comet", "starforge"];
	let _set: unknown = {};
	for (const [_, _v] of pairs((TITLE_FX_KINDS) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
		luaSetIndex(_set, _v, true);
	}
	let FX_SET: unknown = _set;
	function parseFx(fx?: unknown): unknown | undefined {
		if (((fx === undefined) || (fx === ""))) {
			return undefined;
		}
		let key: unknown = luaCall(luaProp(string, "lower"), fx);
		return ((luaIndex(FX_SET, key) !== undefined) ? key : undefined);
		return undefined;
	}
	let FX_ACCENT: unknown = { wave: luaProp(Palette, "cyan"), fire: luaProp(Palette, "mango"), ice: luaProp(Palette, "cyan"), glitch: luaProp(Palette, "pink"), galaxy: luaProp(Palette, "violet"), rainbow: luaCall(luaProp(Color3, "fromRGB"), 255, 170, 60), glow: luaCall(lighten, luaProp(Palette, "cream"), 0.1), neon: luaProp(Palette, "mint"), sparkle: luaProp(Palette, "mango"), shake: luaProp(Palette, "coral"), pulse: luaProp(Palette, "violet"), ["gradient-shift" as never]: luaProp(Palette, "blue"), holographic: luaProp(Palette, "cyan"), "void": luaProp(Palette, "violet"), plasma: luaProp(Palette, "pink"), chrome: luaProp(Palette, "creamSoft"), ember: luaProp(Palette, "coral"), frost: luaCall(luaProp(Color3, "fromRGB"), 180, 220, 255), aurora: luaProp(Palette, "mint"), matrix: luaProp(Palette, "green"), "static": luaProp(Palette, "cream"), ["bounce-in" as never]: luaProp(Palette, "mango"), ["blur-resolve" as never]: luaProp(Palette, "cream"), shimmer: luaProp(Palette, "creamSoft"), toxic: luaCall(luaProp(Color3, "fromRGB"), 120, 255, 40), solar: luaProp(Palette, "mango"), ocean: luaProp(Palette, "blue"), candy: luaProp(Palette, "pink"), voltage: luaProp(Palette, "cyan"), prism: luaProp(Palette, "pink"), phantom: luaProp(Palette, "violet"), eclipse: luaCall(luaProp(Color3, "fromRGB"), 255, 214, 140), nebula: luaProp(Palette, "violet"), molten: luaCall(luaProp(Color3, "fromRGB"), 255, 120, 40), circuit: luaProp(Palette, "mint"), comet: luaProp(Palette, "cyan"), starforge: luaCall(luaProp(Color3, "fromRGB"), 255, 226, 150) };
	function titleFxAccent(fx?: unknown): unknown | undefined {
		let kind: unknown = luaCall(parseFx, fx);
		return ((kind !== undefined) ? luaIndex(FX_ACCENT, kind) : luaProp(Palette, "creamSoft"));
		return undefined;
	}
	function darkTitlePlate(fx?: unknown): unknown | undefined {
		return luaCall(darken, luaCall(titleFxAccent, fx), 0.82);
		return undefined;
	}
	let TITLE_TIER: unknown = { wave: "Common", shake: "Common", pulse: "Common", "static": "Common", ["bounce-in" as never]: "Common", ["blur-resolve" as never]: "Common", glow: "Common", shimmer: "Common", ice: "Rare", frost: "Rare", ember: "Rare", neon: "Rare", matrix: "Rare", candy: "Rare", ocean: "Rare", toxic: "Rare", sparkle: "Rare", ["gradient-shift" as never]: "Rare", chrome: "Rare", fire: "Epic", glitch: "Epic", aurora: "Epic", voltage: "Epic", holographic: "Epic", plasma: "Epic", phantom: "Epic", circuit: "Epic", rainbow: "Epic", galaxy: "Legendary", "void": "Legendary", solar: "Legendary", molten: "Legendary", comet: "Legendary", eclipse: "Legendary", prism: "Legendary", nebula: "Legendary", starforge: "Mythic" };
	function titleTier(fx?: unknown): unknown | undefined {
		let kind: unknown = luaCall(parseFx, fx);
		return ((kind !== undefined) ? (luaIndex(TITLE_TIER, kind) || "Common") : "Common");
		return undefined;
	}
	function colorTag(color?: unknown): unknown | undefined {
		return `${luaCall(luaProp(math, "round"), ((luaProp(color, "R") as unknown as number) * (255 as unknown as number)))},${luaCall(luaProp(math, "round"), ((luaProp(color, "G") as unknown as number) * (255 as unknown as number)))},${luaCall(luaProp(math, "round"), ((luaProp(color, "B") as unknown as number) * (255 as unknown as number)))}`;
		return undefined;
	}
	function safeText(value?: unknown): unknown | undefined {
		let cleaned: unknown = (luaCall(luaProp(string, "gsub"), value, "<", "("));
		cleaned = (luaCall(luaProp(string, "gsub"), cleaned, ">", ")"));
		return cleaned;
		return undefined;
	}
	let REVEAL_STAGGER: unknown = 0.015;
	function buildKindMarkup(kind?: unknown, body?: unknown): unknown | undefined {
		let accent: unknown = luaIndex(FX_ACCENT, kind);
		do {
			if ((kind === "wave")) {
				return `<anim=wiggle freq=1.35 amp=.34 offset=.16 rot=true loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 12, 42, 68))} offset=.05,.18 trans=.35><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 16, 48, 72))} thickness=.04 trans=.18><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "blue"))} individual=true moveDir=right moveSpeed=.65><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 45, 165, 225))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 195, 248, 255))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=false moveDir=right moveSpeed=.55 rot=12>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "ocean")) {
				return `<anim=orbit freq=1.1 amp=.24 offset=.2 rot=true loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 8, 24, 54))} offset=.06,.22 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 14, 44, 92))} thickness=.042 trans=.15><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 20, 75, 155))};${luaCall(colorTag, luaProp(Palette, "blue"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 175, 240, 255))} individual=false moveDir=left moveSpeed=.38 rot=16>${body}</gradient></stroke></shadow></anim>`;
			}
			if ((kind === "aurora")) {
				return `<anim=spiral freq=1.15 amp=.28 offset=.18 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "mint"))} rate=.42 chance=38 lifetime=.55,1.05 startSize=.14,.24 endSize=0,0 velY=-.25,.25 velX=-.25,.25><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 18, 12, 42))} offset=.05,.2 trans=.32><stroke=true color=${luaCall(colorTag, luaProp(Palette, "mint"))} thickness=.04 trans=.2><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "pink"))} individual=true moveDir=right moveSpeed=.6><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "pink"))} individual=false moveDir=right moveSpeed=.45 spacing=.12 rot=18>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "fire")) {
				return `<anim=bounce dir=up offset=.26 exp=1.7 loop=true><shake=true maxOffset=.016 maxRot=1.8 loop=true freq=6 dur=0><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 200, 80))} rate=.85 chance=55 lifetime=.35,.68 startSize=.2,.34 endSize=0,0 velY=-1.1,-.55 startPosY=.1,.35 rotVel=-45,45><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 58, 10, 4))} offset=.04,.22 trans=.25><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 82, 18, 6))} thickness=.045><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "coral"))};${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 240, 130))} individual=true moveDir=right moveSpeed=.85><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 62, 16))};${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 238, 125))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 95, 24))} individual=true moveDir=right moveSpeed=.65 rot=85>${body}</gradient></strokeGradient></stroke></shadow></shiny></shake></anim>`;
			}
			if ((kind === "ember")) {
				return `<anim=pendulum freq=1.4 amp=.28 offset=.22 rot=true loop=true><shake=true maxOffset=.012 maxRot=1.4 loop=true freq=4 dur=0><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 140, 55))} rate=.5 chance=44 lifetime=.55,1.05 startSize=.16,.26 endSize=0,0 velY=-.65,-.2 startPosY=-.1,.2 accelY=-.3,-.1><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 44, 10, 4))} offset=.05,.2 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 58, 14, 6))} thickness=.042><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 190, 42, 14))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 118, 42))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 214, 115))} individual=false moveDir=right moveSpeed=.48 rot=88>${body}</gradient></stroke></shadow></shiny></shake></anim>`;
			}
			if ((kind === "solar")) {
				return `<anim=pulsewave freq=1.55 amp=.32 offset=.16 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 244, 170))} rate=.6 chance=42 lifetime=.45,.85 startSize=.2,.34 endSize=0,0 velY=-.38,.38 velX=-.38,.38><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 78, 32, 6))} offset=.06,.24 trans=.25><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 110, 48, 8))} thickness=.048><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 210, 75))} individual=false moveDir=right moveSpeed=.75><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 200, 60))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 252, 218))};${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 140, 32))} individual=false moveDir=right moveSpeed=.62 rot=78>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "ice")) {
				return `<anim=slide dir=down offset=.22 rot=-5 loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.45 chance=40 lifetime=.45,.85 startSize=.14,.24 endSize=0,0 velY=.18,.52 velX=-.18,.18><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 18, 52, 88))} offset=.05,.2 trans=.3><stroke=true color=${luaCall(colorTag, luaProp(Palette, "white"))} thickness=.048 trans=.12><strokeGradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 110, 195, 255))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=true moveDir=right moveSpeed=.55><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 115, 198, 255))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 160, 232, 255))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 85, 175, 245))} individual=true moveDir=right moveSpeed=.42 rot=-16>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "frost")) {
				return `<anim=pendulum freq=1.05 amp=.22 offset=.2 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.38 chance=36 lifetime=.6,1.1 startSize=.14,.22 endSize=0,0 velY=-.12,.22><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 24, 58, 96))} offset=.05,.18 trans=.32><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 225, 244, 255))} thickness=.042 trans=.16><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 160, 212, 255))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 200, 238, 255))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 130, 190, 245))} individual=false moveDir=right moveSpeed=.36 rot=-12>${body}</gradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "glitch")) {
				return `<decode=true dur=.16 freq=7 loop=true><shake=true maxOffset=.042 maxRot=3.4 loop=true freq=9 dur=0><shadow=true color=${luaCall(colorTag, luaProp(Palette, "cyan"))} offset=-.08,.14 trans=.22><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 22, 4, 38))} thickness=.045><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=true moveDir=left moveSpeed=1.35><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "violet"))} individual=true moveDir=left moveSpeed=1.15>${body}</gradient></strokeGradient></stroke></shadow></shake></decode>`;
			}
			if ((kind === "static")) {
				return `<shake=true maxOffset=.024 maxRot=1.8 loop=true freq=12 dur=0><decode=true dur=.12 freq=9 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 24, 34, 48))} offset=.05,.16 trans=.35><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 28, 36, 46))} thickness=.04><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "creamSoft"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 150, 185, 220))};${luaCall(colorTag, luaProp(Palette, "cream"))} individual=true moveDir=right moveSpeed=1.05 rot=90>${body}</gradient></stroke></shadow></decode></shake>`;
			}
			if ((kind === "voltage")) {
				return `<anim=pulsewave freq=2.2 amp=.28 offset=.14 rot=true loop=true><shake=true maxOffset=.026 maxRot=4.2 loop=true freq=11 dur=0><shiny=true color=${luaCall(colorTag, luaProp(Palette, "cyan"))} rate=.6 chance=46 lifetime=.25,.48 startSize=.16,.26 endSize=0,0 velX=-.85,.85 velY=-.45,.45><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 10, 38, 74))} offset=.05,.2 trans=.26><stroke=true color=${luaCall(colorTag, luaProp(Palette, "white"))} thickness=.042><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "blue"))} moveDir=right moveSpeed=1.2 individual=false><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 105, 185, 255))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=true moveDir=right moveSpeed=.95 rot=12>${body}</gradient></strokeGradient></stroke></shadow></shiny></shake></anim>`;
			}
			if ((kind === "shake")) {
				return `<shake=true maxOffset=.048 maxRot=5.5 loop=true freq=8 dur=0 fade=false><shiny=true color=${luaCall(colorTag, luaProp(Palette, "mango"))} rate=.5 chance=40 lifetime=.3,.58 startSize=.16,.28 endSize=0,0 velY=-.7,-.22 velX=-.5,.5><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 48, 12, 8))} offset=.05,.18 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 56, 14, 10))} thickness=.042><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "coral"))};${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 215, 130))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 92, 48))} individual=true moveDir=right moveSpeed=.75>${body}</gradient></stroke></shadow></shiny></shake>`;
			}
			if ((kind === "galaxy")) {
				return `<anim=orbit freq=.95 amp=.32 offset=.22 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 230, 218, 255))} rate=.6 chance=48 lifetime=.5,1 startSize=.16,.28 endSize=0,0 velY=-.28,.28 velX=-.35,.35><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 20, 8, 42))} offset=.06,.26 trans=.25><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 38, 14, 68))} thickness=.046 trans=.14><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=true moveDir=right moveSpeed=.65><rainbow=true freq=.28 offset=.18>${body}</rainbow></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "prism")) {
				return `<anim=spiral freq=1.35 amp=.3 offset=.16 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.5 chance=42 lifetime=.4,.8 startSize=.15,.25 endSize=0,0 velY=-.3,.3 velX=-.3,.3><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 32, 14, 52))} offset=.06,.22 trans=.28><stroke=true color=${luaCall(colorTag, luaProp(Palette, "white"))} thickness=.045><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaProp(Palette, "violet"))} individual=true moveDir=right moveSpeed=.85><rainbow=true freq=.55 offset=.12>${body}</rainbow></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "holographic")) {
				return `<italic=true><anim=wiggle freq=1.45 amp=.26 offset=.18 rot=true loop=true><shadow=true color=${luaCall(colorTag, luaProp(Palette, "pink"))} offset=-.06,.16 trans=.32><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 18, 46, 62))} thickness=.04><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=true moveDir=left moveSpeed=.95><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=true moveDir=left moveSpeed=.95 rot=-18>${body}</gradient></strokeGradient></stroke></shadow></anim></italic>`;
			}
			if ((kind === "gradient-shift")) {
				return `<anim=pulsewave freq=1.2 amp=.22 offset=.18 rot=false loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 14, 22, 48))} offset=.05,.18 trans=.32><stroke=true color=${luaCall(colorTag, luaProp(Palette, "white"))} thickness=.038 trans=.35><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "blue"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=false moveDir=right moveSpeed=.55><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "blue"))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=false moveDir=right moveSpeed=.48 spacing=.1 rot=15>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "candy")) {
				return `<anim=bounce dir=up offset=.38 exp=1.85 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 58, 16, 42))} offset=.05,.2 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 72, 20, 52))} thickness=.042><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cream"))};${luaCall(colorTag, luaProp(Palette, "mint"))} individual=true moveDir=right moveSpeed=.6><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cream"))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "mint"))} individual=true moveDir=right moveSpeed=.45 rot=10>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "rainbow")) {
				return `<anim=wiggle freq=1.5 amp=.32 offset=.16 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.48 chance=40 lifetime=.4,.78 startSize=.14,.24 endSize=0,0 velY=-.45,-.12 velX=-.28,.28><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 24, 14, 42))} offset=.05,.2 trans=.3><stroke=true color=${luaCall(colorTag, luaProp(Palette, "white"))} thickness=.04 trans=.28><rainbow=true freq=.65 offset=.15>${body}</rainbow></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "toxic")) {
				return `<anim=spiral freq=1.4 amp=.26 offset=.2 rot=true loop=true><shake=true maxOffset=.016 maxRot=1.2 loop=true freq=5 dur=0><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 165, 255, 75))} rate=.48 chance=42 lifetime=.45,.85 startSize=.15,.25 endSize=0,0 velY=-.55,-.15 velX=-.25,.25><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 10, 32, 6))} offset=.05,.2 trans=.28><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 14, 38, 8))} thickness=.044><strokeGradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 95, 245, 38))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 210, 255, 115))};${luaCall(colorTag, luaProp(Palette, "mint"))} individual=true moveDir=right moveSpeed=.75><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 95, 245, 38))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 210, 255, 115))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 52, 188, 26))};${luaCall(colorTag, luaProp(Palette, "mint"))} individual=true moveDir=right moveSpeed=.58 rot=84>${body}</gradient></strokeGradient></stroke></shadow></shiny></shake></anim>`;
			}
			if ((kind === "matrix")) {
				return `<italic=true><anim=slide dir=down offset=.18 rot=0 loop=true><decode=true dur=.22 freq=6 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 4, 22, 8))} offset=.04,.18 trans=.28><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 6, 28, 10))} thickness=.042><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 85, 255, 125))};${luaCall(colorTag, luaProp(Palette, "green"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 195, 255, 205))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 24, 150, 54))} individual=true moveDir=right moveSpeed=.95 rot=90>${body}</gradient></stroke></shadow></decode></anim></italic>`;
			}
			if ((kind === "glow")) {
				return `<anim=pulsewave freq=1.25 amp=.24 offset=.18 rot=false loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.48 chance=42 lifetime=.5,.95 startSize=.16,.26 endSize=0,0 velY=-.32,.32 velX=-.32,.32><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 88, 62, 18))} offset=.04,.18 trans=.32><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 236, 190))} thickness=.055 trans=.16><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 252, 230))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 224, 155))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=false moveDir=right moveSpeed=.46 rot=22>${body}</gradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "neon")) {
				return `<anim=pulsewave freq=1.65 amp=.28 offset=.15 rot=true loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 6, 42, 32))} offset=.05,.2 trans=.26><stroke=true color=${luaCall(colorTag, luaProp(Palette, "mint"))} thickness=.052><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=false moveDir=right moveSpeed=.8><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 215, 255, 242))};${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=false moveDir=right moveSpeed=.58 rot=8>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "sparkle")) {
				return `<anim=bounce dir=up offset=.18 exp=1.35 loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.88 chance=58 lifetime=.38,.72 startSize=.18,.3 endSize=0,0 velY=-.85,-.35 velX=-.45,.45 startPosY=-.18,.18 rotVel=-80,80><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 62, 34, 8))} offset=.05,.18 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 76, 44, 10))} thickness=.04 trans=.22><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 236, 152))};${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 192, 82))} individual=false moveDir=right moveSpeed=.64 rot=14>${body}</gradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "shimmer")) {
				return `<anim=wiggle freq=1.15 amp=.2 offset=.16 rot=false loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.36 chance=34 lifetime=.45,.85 startSize=.14,.22 endSize=0,0 velY=-.25,.25 velX=-.25,.25><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 28, 34, 46))} offset=.04,.16 trans=.36><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 42, 50, 64))} thickness=.036 trans=.24><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "creamSoft"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 210, 232, 255))};${luaCall(colorTag, luaProp(Palette, "cream"))} individual=false moveDir=right moveSpeed=.65 rot=18>${body}</gradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "pulse")) {
				return `<anim=grow startScale=.82 exp=1.25 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 24, 10, 46))} offset=.05,.2 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(lighten, luaProp(Palette, "violet"), 0.3))} thickness=.045 trans=.18><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=true moveDir=right moveSpeed=.65><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "violet"))} individual=false moveDir=right moveSpeed=.48 spacing=.14>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "void")) {
				return `<anim=orbit freq=.85 amp=.36 offset=.24 rot=true loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 8, 0, 18))} offset=.08,.32 trans=.18><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 18, 6, 32))} thickness=.058><strokeGradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 185, 115, 255))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 48, 12, 82))};${luaCall(colorTag, luaProp(Palette, "violet"))} individual=true moveDir=left moveSpeed=.55><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 170, 95, 250))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 58, 18, 98))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 220, 165, 255))} individual=false moveDir=right moveSpeed=.38 rot=42>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "plasma")) {
				return `<anim=spiral freq=1.65 amp=.32 offset=.16 rot=true loop=true><shake=true maxOffset=.024 maxRot=2.4 loop=true freq=8 dur=0><shiny=true color=${luaCall(colorTag, luaProp(Palette, "pink"))} rate=.68 chance=44 lifetime=.3,.55 startSize=.18,.3 endSize=0,0 velX=-.75,.75 velY=-.48,.48><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 44, 10, 40))} offset=.05,.2 trans=.26><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 52, 12, 48))} thickness=.044><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "coral"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=true moveDir=right moveSpeed=1.05 rot=16>${body}</gradient></stroke></shadow></shiny></shake></anim>`;
			}
			if ((kind === "chrome")) {
				return `<anim=pendulum freq=1.2 amp=.2 offset=.18 rot=true loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 32, 36, 44))} offset=.06,.22 trans=.35><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 28, 32, 40))} thickness=.042><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 110, 120, 138))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=false moveDir=right moveSpeed=.65><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "muted"))};${luaCall(colorTag, luaProp(Palette, "creamSoft"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "creamSoft"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 90, 96, 108))} individual=false moveDir=right moveSpeed=.52 rot=78>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
			}
			if ((kind === "phantom")) {
				return `<italic=true><anim=orbit freq=.92 amp=.28 offset=.22 rot=true loop=true><trans=.12 tweenDur=1.2 tweenFrom=.48 loopTween=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 22, 8, 38))} offset=.07,.26 trans=.28><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 30, 10, 48))} thickness=.04><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 175, 135, 255))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 232, 218, 255))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 125, 195, 255))} individual=false moveDir=right moveSpeed=.34 rot=82>${body}</gradient></stroke></shadow></trans></anim></italic>`;
			}
			if ((kind === "eclipse")) {
				return `<anim=pulsewave freq=1.15 amp=.3 offset=.18 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 224, 150))} rate=.44 chance=38 lifetime=.5,.95 startSize=.16,.26 endSize=0,0 velX=-.32,.32 velY=-.32,.32><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 175, 70))} offset=.04,.18 trans=.28><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 214, 140))} thickness=.058><strokeGradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 155, 55))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 248, 215))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 155, 55))} individual=false moveDir=right moveSpeed=.45><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 36, 24, 52))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 78, 52, 96))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 214, 140))} individual=false moveDir=right moveSpeed=.36 rot=24>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "nebula")) {
				return `<anim=spiral freq=.95 amp=.32 offset=.22 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 185, 240))} rate=.46 chance=40 lifetime=.55,1.05 startSize=.15,.26 endSize=0,0 velX=-.28,.28 velY=-.28,.28><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 18, 8, 38))} offset=.06,.24 trans=.26><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 26, 10, 48))} thickness=.044><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=true moveDir=left moveSpeed=.55><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaProp(Palette, "violet"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 85, 120, 255))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 165, 235))} individual=false moveDir=left moveSpeed=.32 spacing=.16 rot=26>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "molten")) {
				return `<anim=bounce dir=down offset=.16 exp=2.0 loop=true><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 200, 90))} rate=.48 chance=40 lifetime=.55,1.0 startSize=.16,.26 endSize=0,0 velY=.35,.85 startPosY=.25,.45 accelY=.5,.9><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 54, 10, 4))} offset=.05,.22 trans=.24><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 52, 10, 4))} thickness=.048><strokeGradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 118, 36))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 230, 125))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 185, 36, 10))} individual=true moveDir=right moveSpeed=.6><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 155, 26, 8))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 120, 40))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 230, 125))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 235, 68, 16))} individual=false moveDir=right moveSpeed=.52 rot=86>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "circuit")) {
				return `<anim=pulsewave freq=1.8 amp=.22 offset=.14 rot=false loop=true><decode=true dur=.22 freq=6 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 6, 28, 22))} offset=.05,.18 trans=.28><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 10, 40, 30))} thickness=.042><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))} individual=true moveDir=right moveSpeed=1.1><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "mint"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 24, 150, 112))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 205, 255, 238))};${luaCall(colorTag, luaProp(Palette, "cyan"))} individual=true moveDir=right moveSpeed=1.2>${body}</gradient></strokeGradient></stroke></shadow></decode></anim>`;
			}
			if ((kind === "comet")) {
				return `<italic=true><anim=slide dir=up offset=.2 rot=-4 loop=true><shiny=true color=${luaCall(colorTag, luaProp(Palette, "white"))} rate=.68 chance=50 lifetime=.38,.75 startSize=.16,.28 endSize=0,0 velX=-1.35,-.75 velY=-.1,.1><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 12, 32, 74))} offset=-.08,.18 trans=.26><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 14, 34, 78))} thickness=.044><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "blue"))} individual=false moveDir=right moveSpeed=.95><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 48, 102, 215))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 165, 235, 255))} individual=false moveDir=right moveSpeed=.88 rot=-8>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim></italic>`;
			}
			if ((kind === "starforge")) {
				return `<anim=pulsewave freq=1.65 amp=.38 offset=.15 rot=true loop=true><shiny=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 244, 195))} rate=.85 chance=56 lifetime=.42,.88 startSize=.2,.34 endSize=0,0 velX=-.5,.5 velY=-.6,-.12 rotVel=-90,90><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 64, 28, 12))} offset=.06,.26 trans=.2><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 224, 150))} thickness=.052><strokeGradient=true colors=${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "pink"))} individual=true moveDir=right moveSpeed=.75><gradient=true colors=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 196, 88))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 252, 228))};${luaCall(colorTag, luaProp(Palette, "cyan"))};${luaCall(colorTag, luaProp(Palette, "pink"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 196, 88))} individual=false moveDir=right moveSpeed=.68 rot=20>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
			}
			if ((kind === "bounce-in")) {
				return `<anim=bounce dir=up offset=.42 exp=1.55 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 54, 24, 6))} offset=.05,.2 trans=.3><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 68, 34, 8))} thickness=.04><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "mango"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 255, 236, 165))};${luaCall(colorTag, luaProp(Palette, "coral"))} individual=true moveDir=right moveSpeed=.75 rot=90>${body}</gradient></stroke></shadow></anim>`;
			}
			if ((kind === "blur-resolve")) {
				return `<anim=grow startScale=.86 exp=1.35 loop=true><decode=true dur=.16 freq=7 loop=true><shadow=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 26, 32, 42))} offset=.05,.18 trans=.32><stroke=true color=${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 38, 44, 54))} thickness=.04><gradient=true colors=${luaCall(colorTag, luaProp(Palette, "cream"))};${luaCall(colorTag, luaProp(Palette, "white"))};${luaCall(colorTag, luaCall(luaProp(Color3, "fromRGB"), 190, 220, 255))};${luaCall(colorTag, luaProp(Palette, "creamSoft"))} individual=false moveDir=right moveSpeed=.52>${body}</gradient></stroke></shadow></decode></anim>`;
			}
			return `<color=${luaCall(colorTag, accent)}>${body}</color>`;
		} while (!(true));
		return undefined;
	}
	function buildMarkup(kind?: unknown, text?: unknown, preview?: unknown): unknown | undefined {
		let body: unknown = luaCall(safeText, text);
		let step: unknown = (preview ? REVEAL_STAGGER : 0);
		return `<interval=${step}>${luaCall(buildKindMarkup, kind, body)}</interval>`;
		return undefined;
	}
	let cachedModule: unknown;
	let loadFailed: unknown = false;
	let pendingWarned: unknown = false;
	function resolveModuleScript(node?: unknown): unknown | undefined {
		if (colon(node).IsA("ModuleScript")) {
			return node;
		}
		let initChild: unknown = colon(node).FindFirstChild("init");
		if (((initChild !== undefined) && colon(initChild).IsA("ModuleScript"))) {
			return initChild;
		}
		return undefined;
		return undefined;
	}
	function loadHyperTextModule(): unknown | undefined {
		if ((cachedModule !== undefined)) {
			return cachedModule;
		}
		if (loadFailed) {
			return undefined;
		}
		let astral: unknown = colon(ReplicatedStorage).FindFirstChild("AstralForge");
		let _vendor: unknown = astral;
		if ((_vendor !== undefined)) {
			_vendor = colon(_vendor).FindFirstChild("Vendor");
		}
		let vendor: unknown = _vendor;
		let _node: unknown = vendor;
		if ((_node !== undefined)) {
			_node = colon(_node).FindFirstChild("HyperText");
		}
		let node: unknown = _node;
		if ((node === undefined)) {
			if ((!pendingWarned)) {
				pendingWarned = true;
				colon(ClientLog).warnEvery("hypertext-root", 15, "hypertext", "ReplicatedStorage.AstralForge.Vendor.HyperText is not replicated yet");
			}
			return undefined;
		}
		let moduleScript: unknown = luaCall(resolveModuleScript, node);
		if ((moduleScript === undefined)) {
			colon(ClientLog).warn("hypertext", `HyperText is a ${luaProp(node, "ClassName")}, not a ModuleScript`);
			loadFailed = true;
			return undefined;
		}
		let ok: unknown;
		let result: unknown;
		[ok, result] = luaCall(pcall, function(): unknown | undefined {
			return luaRequire(moduleScript);
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		let _condition: unknown = ((!ok) || (result === undefined));
		if ((!_condition)) {
			let _new: unknown = luaProp(result, "new");
			_condition = (((luaTypeIs(_new, "function"))) !== true);
		}
		if (_condition) {
			colon(ClientLog).warn("hypertext", `couldn't load HyperText: ${luaCall(tostring, result)}`);
			loadFailed = true;
			return undefined;
		}
		cachedModule = result;
		pendingWarned = false;
		return cachedModule;
		return undefined;
	}
	function AnimatedTitle(_param?: unknown): unknown | undefined {
		let text: unknown = (luaProp(_param, "text") || "");
		let fx: unknown = luaProp(_param, "fx");
		let size: unknown = (luaProp(_param, "size") || 13);
		let reducedMotion: unknown = (luaProp(_param, "reducedMotion") === true);
		let position: unknown = (luaProp(_param, "position") || luaCall(luaProp(UDim2, "fromOffset"), 0, 0));
		let sizeConstraint: unknown = (luaProp(_param, "sizeConstraint") || new (UDim2 as unknown as new (...args: unknown[]) => unknown)(1, 0, 0, ((size as unknown as number) + (4 as unknown as number))));
		let transparency: unknown = (luaProp(_param, "transparency") || 0);
		let align: unknown = (luaProp(_param, "align") || luaProp(luaProp(Enum, "TextXAlignment"), "Left"));
		let preview: unknown = (luaProp(_param, "preview") === true);
		let kind: unknown = luaCall(parseFx, fx);
		let accent: unknown = ((kind !== undefined) ? luaIndex(FX_ACCENT, kind) : luaProp(Palette, "creamSoft"));
		let live: unknown = (((kind !== undefined) && (!reducedMotion)) && (text !== ""));
		let hostRef: unknown = reactLoose.useRef();
		let ready: unknown;
		let setReady: unknown;
		[ready, setReady] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let horizAlign: unknown = ((align === luaProp(luaProp(Enum, "TextXAlignment"), "Center")) ? luaProp(luaProp(Enum, "HorizontalAlignment"), "Center") : ((align === luaProp(luaProp(Enum, "TextXAlignment"), "Right")) ? luaProp(luaProp(Enum, "HorizontalAlignment"), "Right") : luaProp(luaProp(Enum, "HorizontalAlignment"), "Left")));
		reactLoose.useEffect(function(): unknown | undefined {
			luaCall(setReady, false);
			if ((!live)) {
				return undefined;
			}
			let host: unknown = luaProp(hostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let mod: unknown = luaCall(loadHyperTextModule);
			if ((mod === undefined)) {
				return undefined;
			}
			colon(host).ClearAllChildren();
			let instance: unknown = undefined;
			let sizeConn: unknown = undefined;
			let rendered: unknown = false;
			function runRender(): unknown | undefined {
				if ((rendered || (luaProp(host, "Parent") === undefined))) {
					return;
				}
				if ((((luaProp(luaProp(host, "AbsoluteSize"), "X") as unknown as number) <= (0 as unknown as number)) || ((luaProp(luaProp(host, "AbsoluteSize"), "Y") as unknown as number) <= (0 as unknown as number)))) {
					return;
				}
				rendered = true;
				if ((sizeConn !== undefined)) {
					colon(sizeConn).Disconnect();
					sizeConn = undefined;
				}
				let ok: unknown;
				let err: unknown;
				[ok, err] = luaCall(pcall, function(): unknown | undefined {
					let markups: unknown = luaCall(luaProp(mod, "newMarkups"));
					luaSet(luaProp(markups, "font"), "value", "rbxasset://fonts/families/BuilderSans.json");
					luaSet(luaProp(markups, "weight"), "value", luaProp(luaProp(Enum, "FontWeight"), "ExtraBold"));
					luaSet(luaProp(markups, "size"), "value", size);
					luaSet(luaProp(markups, "color"), "value", accent);
					luaSet(luaProp(markups, "trans"), "value", transparency);
					luaSet(luaProp(markups, "horizontalAlignment"), "value", horizAlign);
					luaSet(luaProp(markups, "verticalAlignment"), "value", luaProp(luaProp(Enum, "VerticalAlignment"), "Center"));
					luaSet(luaProp(markups, "ZIndex"), "value", 2);
					luaSet(luaProp(markups, "interval"), "value", (preview ? REVEAL_STAGGER : 0));
					luaSet(luaProp(markups, "anim"), "value", luaProp(mod, "DELETE"));
					let rich: unknown = luaCall(luaProp(mod, "new"), host);
					colon(rich).UpdateDefaultMarkups(markups);
					colon(rich).Render(luaCall(buildMarkup, kind, text, preview), false, false, false);
					instance = rich;
					return undefined;
				}) as LuaTuple<[unknown, unknown]>;
				if ((!ok)) {
					colon(ClientLog).warnEvery(`hypertext-${kind}`, 10, "hypertext", `render failed for ${kind}: ${luaCall(tostring, err)}`);
					colon(host).ClearAllChildren();
					return;
				}
				luaCall(setReady, true);
				return undefined;
			}
			luaCall(runRender);
			if ((!rendered)) {
				sizeConn = colon(colon(host).GetPropertyChangedSignal("AbsoluteSize")).Connect(runRender);
			}
			return function(): unknown | undefined {
				rendered = true;
				if ((sizeConn !== undefined)) {
					colon(sizeConn).Disconnect();
					sizeConn = undefined;
				}
				luaCall(setReady, false);
				luaCall(pcall, function(): unknown | undefined {
					if (((instance !== undefined) && (luaTypeIs(luaProp(instance, "Destroy"), "function")))) {
						colon(instance).Destroy();
					}
					colon(host).ClearAllChildren();
					return undefined;
				});
				return undefined;
			};
			return undefined;
		}, [live, kind, text, size, transparency, horizAlign, preview]);
		return reactLoose.createElement("frame", { Size: sizeConstraint, Position: position, BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: 2, ClipsDescendants: false }, reactLoose.createElement("frame", { ref: hostRef, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, Visible: live, ZIndex: 2 }), (((!live) || (!ready)) ? reactLoose.createElement("textlabel", { Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, Text: text, TextColor3: accent, TextSize: size, TextTransparency: transparency, FontFace: luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold")), TextXAlignment: align, TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center"), TextTruncate: luaProp(luaProp(Enum, "TextTruncate"), "AtEnd"), TextScaled: true, ZIndex: 2 }, reactLoose.createElement("uitextsizeconstraint", { MinTextSize: luaCall(luaProp(math, "max"), 9, ((size as unknown as number) - (4 as unknown as number))), MaxTextSize: size })) : undefined));
		return undefined;
	}
	function AnimatedTitlePreview(_param?: unknown): unknown | undefined {
		let text: unknown = luaProp(_param, "text");
		let fx: unknown = luaProp(_param, "fx");
		let size: unknown = (luaProp(_param, "size") || 15);
		let reducedMotion: unknown = (luaProp(_param, "reducedMotion") === true);
		let transparency: unknown = (luaProp(_param, "transparency") || 0);
		let preview: unknown = (luaProp(_param, "preview") === true);
		return reactLoose.createElement(AnimatedTitle, { text: text, fx: fx, size: size, reducedMotion: reducedMotion, transparency: transparency, align: luaProp(luaProp(Enum, "TextXAlignment"), "Center"), preview: preview });
		return undefined;
	}
	return { parseFx: parseFx, titleFxAccent: titleFxAccent, darkTitlePlate: darkTitlePlate, titleTier: titleTier, AnimatedTitle: AnimatedTitle, AnimatedTitlePreview: AnimatedTitlePreview, TITLE_FX_KINDS: TITLE_FX_KINDS };
};

__defs["RichTextHost"] = () => {
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
	let Palette: unknown = luaProp(kit("CoreKit", "theme"), "Palette");
	let cachedModule: unknown;
	let loadFailed: unknown = false;
	let pendingWarned: unknown = false;
	function resolveModuleScript(node?: unknown): unknown | undefined {
		if (colon(node).IsA("ModuleScript")) {
			return node;
		}
		let initChild: unknown = colon(node).FindFirstChild("init");
		if (((initChild !== undefined) && colon(initChild).IsA("ModuleScript"))) {
			return initChild;
		}
		return undefined;
		return undefined;
	}
	function loadRichTextModule(): unknown | undefined {
		if ((cachedModule !== undefined)) {
			return cachedModule;
		}
		if (loadFailed) {
			return undefined;
		}
		let astral: unknown = colon(ReplicatedStorage).FindFirstChild("AstralForge");
		let _vendor: unknown = astral;
		if ((_vendor !== undefined)) {
			_vendor = colon(_vendor).FindFirstChild("Vendor");
		}
		let vendor: unknown = _vendor;
		let _node: unknown = vendor;
		if ((_node !== undefined)) {
			_node = colon(_node).FindFirstChild("RichText");
		}
		let node: unknown = _node;
		if ((node === undefined)) {
			if ((!pendingWarned)) {
				pendingWarned = true;
				colon(ClientLog).warnEvery("richtext-root", 15, "richtext", "ReplicatedStorage.AstralForge.Vendor.RichText is not replicated yet");
			}
			return undefined;
		}
		let moduleScript: unknown = luaCall(resolveModuleScript, node);
		if ((moduleScript === undefined)) {
			colon(ClientLog).warn("richtext", `RichText is a ${luaProp(node, "ClassName")}, not a ModuleScript`);
			loadFailed = true;
			return undefined;
		}
		let ok: unknown;
		let result: unknown;
		[ok, result] = luaCall(pcall, function(): unknown | undefined {
			return luaRequire(moduleScript);
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		let _condition: unknown = ((!ok) || (result === undefined));
		if ((!_condition)) {
			let _new: unknown = luaProp(result, "new");
			_condition = (((luaTypeIs(_new, "function"))) !== true);
		}
		if (_condition) {
			colon(ClientLog).warn("richtext", `couldn't load RichText: ${luaCall(tostring, result)}`);
			loadFailed = true;
			return undefined;
		}
		cachedModule = result;
		pendingWarned = false;
		return cachedModule;
		return undefined;
	}
	function ScriptedText(_param?: unknown): unknown | undefined {
		let text: unknown = luaProp(_param, "text");
		let width: unknown = luaProp(_param, "width");
		let height: unknown = luaProp(_param, "height");
		let size: unknown = luaProp(_param, "size");
		if ((size === undefined)) {
			size = 15;
		}
		let color: unknown = luaProp(_param, "color");
		if ((color === undefined)) {
			color = luaProp(Palette, "creamSoft");
		}
		let weight: unknown = luaProp(_param, "weight");
		if ((weight === undefined)) {
			weight = luaProp(luaProp(Enum, "FontWeight"), "Medium");
		}
		let italic: unknown = luaProp(_param, "italic");
		if ((italic === undefined)) {
			italic = false;
		}
		let align: unknown = luaProp(_param, "align");
		if ((align === undefined)) {
			align = luaProp(luaProp(Enum, "HorizontalAlignment"), "Left");
		}
		let typewriterInterval: unknown = luaProp(_param, "typewriterInterval");
		if ((typewriterInterval === undefined)) {
			typewriterInterval = 0.015;
		}
		let typewriterSoundId: unknown = luaProp(_param, "typewriterSoundId");
		let animation: unknown = luaProp(_param, "animation");
		if ((animation === undefined)) {
			animation = "None";
		}
		let animationDuration: unknown = luaProp(_param, "animationDuration");
		if ((animationDuration === undefined)) {
			animationDuration = 0.125;
		}
		let effect: unknown = luaProp(_param, "effect");
		if ((effect === undefined)) {
			effect = "None";
		}
		let reducedMotion: unknown = luaProp(_param, "reducedMotion");
		if ((reducedMotion === undefined)) {
			reducedMotion = false;
		}
		let position: unknown = luaProp(_param, "position");
		let zIndex: unknown = luaProp(_param, "zIndex");
		if ((zIndex === undefined)) {
			zIndex = 1;
		}
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		if ((layoutOrder === undefined)) {
			layoutOrder = 0;
		}
		let renderKey: unknown = luaProp(_param, "renderKey");
		let onRenderEnded: unknown = luaProp(_param, "onRenderEnded");
		let hostRef: unknown = reactLoose.useRef();
		let richRef: unknown = reactLoose.useRef();
		let fallbackRef: unknown = reactLoose.useRef();
		let live: unknown;
		let setLive: unknown;
		[live, setLive] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let destroy: unknown = reactLoose.useCallback(function(): unknown | undefined {
			let rich: unknown = luaProp(richRef, "current");
			luaSet(richRef, "current", undefined);
			if ((rich !== undefined)) {
				luaCall(pcall, function(): unknown | undefined {
					colon(rich).Destroy();
					return undefined;
				});
			}
			luaCall(setLive, false);
			return undefined;
		}, {});
		reactLoose.useEffect(function(): unknown | undefined {
			if ((reducedMotion || (text === ""))) {
				luaCall(destroy);
				return undefined;
			}
			let cancelled: unknown = false;
			let attempts: unknown = 0;
			let retryJob: unknown;
			let tryMount: unknown;
			tryMount = function(): unknown | undefined {
				if (cancelled) {
					return undefined;
				}
				attempts = ((attempts as unknown as number) + (1 as unknown as number));
				let host: unknown = luaProp(hostRef, "current");
				let mod: unknown = luaCall(loadRichTextModule);
				if (((host === undefined) || (mod === undefined))) {
					if (((attempts as unknown as number) < (50 as unknown as number))) {
						retryJob = luaCall(luaProp(task, "delay"), 0.1, tryMount);
					}
					return undefined;
				}
				let fallback: unknown = luaProp(fallbackRef, "current");
				if ((fallback !== undefined)) {
					luaSet(fallback, "Visible", false);
				}
				let rich: unknown = luaCall(luaProp(mod, "new"), host, { Color: color, Size: size, XAlign: align, YAlign: luaProp(luaProp(Enum, "VerticalAlignment"), "Top"), TypewriterInterval: typewriterInterval, TypewriterSoundId: typewriterSoundId, Animation: animation, AnimationDuration: animationDuration, AnimationLoop: false, Effect: effect, Weight: weight, Italic: italic, Transparency: 0 });
				luaSet(richRef, "current", rich);
				luaCall(setLive, true);
				if (((onRenderEnded !== undefined) && (luaProp(rich, "onRenderEnded") !== undefined))) {
					colon(luaProp(luaProp(rich, "onRenderEnded"), "Event")).Once(function(): unknown | undefined {
						if ((!cancelled)) {
							luaCall(onRenderEnded);
						}
						return undefined;
					});
				}
				colon(rich).Render(text, false, true, false);
				return undefined;
			};
			let mountJob: unknown = luaCall(luaProp(task, "defer"), tryMount);
			return function(): unknown | undefined {
				cancelled = true;
				luaCall(pcall, luaProp(task, "cancel"), mountJob);
				if ((retryJob !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), retryJob);
				}
				luaCall(destroy);
				return undefined;
			};
			return undefined;
		}, [renderKey, reducedMotion, text, destroy]);
		let showFallback: unknown = ((reducedMotion || (!live)) || (text === ""));
		return reactLoose.createElement("frame", { Size: luaCall(luaProp(UDim2, "fromOffset"), width, height), Position: position, BackgroundTransparency: 1, BorderSizePixel: 0, ZIndex: zIndex, LayoutOrder: layoutOrder, ClipsDescendants: false }, reactLoose.createElement("frame", { ref: hostRef, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ZIndex: ((zIndex as unknown as number) + (1 as unknown as number)) }), (showFallback && reactLoose.createElement("textlabel", { ref: fallbackRef, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, Text: text, TextColor3: color, TextSize: size, FontFace: luaCall(luaProp(Font, "fromEnum"), ((weight === luaProp(luaProp(Enum, "FontWeight"), "Heavy")) ? luaProp(luaProp(Enum, "Font"), "BuilderSansExtraBold") : ((weight === luaProp(luaProp(Enum, "FontWeight"), "Bold")) ? luaProp(luaProp(Enum, "Font"), "BuilderSansBold") : luaProp(luaProp(Enum, "Font"), "BuilderSansMedium")))), TextXAlignment: ((align === luaProp(luaProp(Enum, "HorizontalAlignment"), "Center")) ? luaProp(luaProp(Enum, "TextXAlignment"), "Center") : ((align === luaProp(luaProp(Enum, "HorizontalAlignment"), "Right")) ? luaProp(luaProp(Enum, "TextXAlignment"), "Right") : luaProp(luaProp(Enum, "TextXAlignment"), "Left"))), TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Top"), TextWrapped: true, LineHeight: 1.12, ZIndex: zIndex })));
		return undefined;
	}
	return { ScriptedText: ScriptedText };
};

__defs["NumberSpinnerHost"] = () => {
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let compactSpinParts: unknown = luaProp(kit("CoreKit", "format"), "compactSpinParts");
	let ClientLog: unknown = luaProp(kit("CoreKit", "log"), "ClientLog");
	let useMotionSettings: unknown = luaProp(kit("MotionKit", "motion"), "useMotionSettings");
	let _theme: unknown = kit("CoreKit", "theme");
	let Palette: unknown = luaProp(_theme, "Palette");
	let lighten: unknown = luaProp(_theme, "lighten");
	let AUTO_WIDTH_PAD: unknown = 4;
	function estimateLabelWidth(text?: unknown, textSize?: unknown): unknown | undefined {
		return ((luaCall(luaProp(math, "max"), 4, luaCall(luaProp(math, "ceil"), ((((len(text) as unknown as number) * (textSize as unknown as number)) as unknown as number) * (0.7 as unknown as number)))) as unknown as number) + (AUTO_WIDTH_PAD as unknown as number));
		return undefined;
	}
	// Builder Sans digits are even-width, so values roll cleanly without the gappy look of a monospace dot
	let SPINNER_FONT: unknown = luaCall(luaProp(Font, "fromEnum"), luaProp(luaProp(Enum, "Font"), "BuilderSansBold"));
	function findSpinnerLayout(host?: unknown): unknown | undefined {
		for (const [_, child] of pairs((colon(host).GetChildren()) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (((!colon(child).IsA("GuiObject")) || (luaProp(child, "Name") === "NumberSpinnerGuide"))) {
				continue;
			}
			let layout: unknown = colon(child).FindFirstChildOfClass("UIListLayout");
			if ((layout !== undefined)) {
				return layout;
			}
		}
		return undefined;
		return undefined;
	}
	function hugSpinnerContent(host?: unknown): unknown | undefined {
		for (const [_, child] of pairs((colon(host).GetChildren()) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			if (((!colon(child).IsA("GuiObject")) || (luaProp(child, "Name") === "NumberSpinnerGuide"))) {
				continue;
			}
			let layout: unknown = colon(child).FindFirstChildOfClass("UIListLayout");
			if ((layout === undefined)) {
				continue;
			}
			if ((luaProp(child, "AutomaticSize") !== luaProp(luaProp(Enum, "AutomaticSize"), "X"))) {
				luaSet(child, "AutomaticSize", luaProp(luaProp(Enum, "AutomaticSize"), "X"));
			}
			let hug: unknown = new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0);
			if ((luaProp(child, "Size") !== hug)) {
				luaSet(child, "Size", hug);
			}
			if ((!luaProp(child, "ClipsDescendants"))) {
				luaSet(child, "ClipsDescendants", true);
			}
			return layout;
		}
		return undefined;
		return undefined;
	}
	let SPINNER_RS_PATH: unknown = "ReplicatedStorage.AstralForge.Shared.NumberSpinner";
	let cachedModule: unknown;
	let loadFailed: unknown = false;
	let pendingWarned: unknown = false;
	function resolveModuleScript(node?: unknown): unknown | undefined {
		if (colon(node).IsA("ModuleScript")) {
			return node;
		}
		let initChild: unknown = colon(node).FindFirstChild("init");
		if (((initChild !== undefined) && colon(initChild).IsA("ModuleScript"))) {
			return initChild;
		}
		return undefined;
		return undefined;
	}
	function childNames(parent?: unknown): unknown | undefined {
		let names: unknown = {};
		for (const [_, child] of pairs((colon(parent).GetChildren()) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			let _name: unknown = luaProp(child, "Name");
			luaTable.insert(names, _name);
		}
		return (((len(names) as unknown as number) > (0 as unknown as number)) ? luaTable.concat(names, ", ") : "(none)");
		return undefined;
	}
	function loadModule(): unknown | undefined {
		if ((cachedModule !== undefined)) {
			return cachedModule;
		}
		if (loadFailed) {
			return undefined;
		}
		let astral: unknown = colon(ReplicatedStorage).FindFirstChild("AstralForge");
		if ((astral === undefined)) {
			if ((!pendingWarned)) {
				pendingWarned = true;
				colon(ClientLog).warnEvery("spinner-root", 15, "spinner", `${SPINNER_RS_PATH} is not replicated`);
			}
			return undefined;
		}
		let sharedFolder: unknown = colon(astral).FindFirstChild("Shared");
		if ((sharedFolder === undefined)) {
			if ((!pendingWarned)) {
				pendingWarned = true;
				colon(ClientLog).warnEvery("spinner-shared", 15, "spinner", `Shared folder missing (have ${luaCall(childNames, astral)})`);
			}
			return undefined;
		}
		let node: unknown = colon(sharedFolder).FindFirstChild("NumberSpinner");
		if ((node === undefined)) {
			if ((!pendingWarned)) {
				pendingWarned = true;
				colon(ClientLog).warnEvery("spinner-module", 15, "spinner", `NumberSpinner missing (have ${luaCall(childNames, sharedFolder)})`);
			}
			return undefined;
		}
		let moduleScript: unknown = luaCall(resolveModuleScript, node);
		if ((moduleScript === undefined)) {
			colon(ClientLog).warn("spinner", `NumberSpinner is a ${luaProp(node, "ClassName")}, not a ModuleScript`);
			loadFailed = true;
			return undefined;
		}
		let ok: unknown;
		let result: unknown;
		[ok, result] = luaCall(pcall, function(): unknown | undefined {
			return luaRequire(moduleScript);
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		if (((!ok) || (result === undefined))) {
			colon(ClientLog).warn("spinner", `couldn't load NumberSpinner: ${luaCall(tostring, result)}`);
			loadFailed = true;
			return undefined;
		}
		let _new: unknown = luaProp(result, "new");
		if ((((luaTypeIs(_new, "function"))) !== true)) {
			colon(ClientLog).warn("spinner", "loaded module has no constructor");
			loadFailed = true;
			return undefined;
		}
		cachedModule = result;
		pendingWarned = false;
		return cachedModule;
		return undefined;
	}
	function sanitizeValue(value?: unknown, decimals?: unknown): unknown | undefined {
		let _value: unknown = value;
		let _condition: unknown = (!((luaTypeIs(_value, "number"))));
		if ((!_condition)) {
			_condition = (((value !== value) || (value === luaProp(math, "huge"))) || (value === (-(luaProp(math, "huge") as unknown as number))));
		}
		if (_condition) {
			return 0;
		}
		let capped: unknown = luaCall(luaProp(math, "clamp"), value, -1e100, 1e100);
		if (((decimals as unknown as number) <= (0 as unknown as number))) {
			return luaCall(luaProp(math, "floor"), ((capped as unknown as number) + (((((capped as unknown as number) >= (0 as unknown as number)) ? 0.5 : -0.5)) as unknown as number)));
		}
		let factor: unknown = ((10 as unknown as number) ** (decimals as unknown as number));
		return ((luaCall(luaProp(math, "floor"), ((((capped as unknown as number) * (factor as unknown as number)) as unknown as number) + (((((capped as unknown as number) >= (0 as unknown as number)) ? 0.5 : -0.5)) as unknown as number))) as unknown as number) / (factor as unknown as number));
		return undefined;
	}
	function spinDisplay(raw?: unknown, extraSuffix?: unknown, spacedSuffix?: unknown): unknown | undefined {
		let parts: unknown = luaCall(compactSpinParts, raw);
		let lead: unknown = ((spacedSuffix && (luaProp(parts, "suffix") !== "")) ? " " : "");
		return { value: luaProp(parts, "value"), suffix: `${lead}${luaProp(parts, "suffix")}${extraSuffix}`, decimals: luaProp(parts, "decimals"), band: luaProp(parts, "suffix") };
		return undefined;
	}
	function formatRawLabel(value?: unknown, prefix?: unknown, extraSuffix?: unknown, spacedSuffix?: unknown): unknown | undefined {
		let display: unknown = luaCall(spinDisplay, value, extraSuffix, spacedSuffix);
		let amount: unknown = luaCall(sanitizeValue, luaProp(display, "value"), luaProp(display, "decimals"));
		let abs: unknown = luaCall(luaProp(math, "abs"), amount);
		let body: unknown = luaCall(luaProp(string, "format"), (((luaProp(display, "decimals") as unknown as number) <= (0 as unknown as number)) ? "%.0f" : ((luaProp(display, "decimals") === 1) ? "%.1f" : "%.2f")), abs);
		return `${prefix}${(((amount as unknown as number) < (0 as unknown as number)) ? "-" : "")}${body}${luaProp(display, "suffix")}`;
		return undefined;
	}
	function applyChrome(spinner?: unknown, opts?: unknown): unknown | undefined {
		if ((luaProp(spinner, "Duration") !== luaProp(opts, "duration"))) {
			luaSet(spinner, "Duration", luaProp(opts, "duration"));
		}
		if ((luaProp(spinner, "Decimals") !== luaProp(opts, "decimals"))) {
			luaSet(spinner, "Decimals", luaProp(opts, "decimals"));
		}
		luaSet(spinner, "Prefix", luaProp(opts, "prefix"));
		luaSet(spinner, "Suffix", luaProp(opts, "suffix"));
		luaSet(spinner, "TextSize", luaProp(opts, "size"));
		luaSet(spinner, "TextColor3", luaProp(opts, "color"));
		luaSet(spinner, "TextStrokeTransparency", 1);
		luaSet(spinner, "TextStrokeColor3", luaCall(luaProp(Color3, "fromRGB"), 0, 0, 0));
		luaSet(spinner, "FontFace", SPINNER_FONT);
		luaSet(spinner, "TextXAlignment", luaProp(opts, "align"));
		luaSet(spinner, "Commas", false);
		luaSet(spinner, "ClipsDescendants", true);
		return undefined;
	}
	// Digit cells follow the spinner font's real advance. Builder Sans Bold digits measure 0.51 em
	// ("0" is 7.2px at 14), so a 0.52 em cell sits each digit snugly; the old 10px default cell left
	// visible gaps ("1 3.7"). NumberSpinner builds digit frames after Value changes, so every new
	// digit is sized as it is added, not only the ones present when Value was set.
	function digitCellWidth(spinner?: unknown, scale?: unknown): unknown | undefined {
		let base: unknown = luaCall(luaProp(math, "max"), 5, luaCall(luaProp(math, "ceil"), ((luaProp(spinner, "TextSize") as unknown as number) * (0.52 as unknown as number))));
		return luaCall(luaProp(math, "max"), 5, luaCall(luaProp(math, "floor"), ((((base as unknown as number) * (luaCall(luaProp(math, "clamp"), (scale || 1), 0.65, 1.15) as unknown as number)) as unknown as number) + (0.5 as unknown as number))));
		return undefined;
	}
	function sizeDigit(child?: unknown, width?: unknown): unknown | undefined {
		if ((colon(child).IsA("Frame") && (luaProp(child, "Name") === "digit"))) {
			let nextSize: unknown = luaCall(luaProp(UDim2, "fromOffset"), width, luaProp(luaProp(luaProp(child, "Size"), "Y"), "Offset"));
			if ((luaProp(child, "Size") !== nextSize)) {
				luaSet(child, "Size", nextSize);
			}
		}
		return undefined;
	}
	// the spinner is a library object, not an Instance, so its cell width lives here
	let digitWidths: unknown = luaCall(setmetatable, {}, { __mode: "k" });
	function setDigitTracking(spinner?: unknown, scale?: unknown, gap?: unknown): unknown | undefined {
		let padding: unknown = new (UDim as unknown as new (...args: unknown[]) => unknown)(0, luaCall(luaProp(math, "clamp"), luaCall(luaProp(math, "floor"), (gap || 0)), -3, 6));
		if ((luaProp(luaProp(spinner, "Layout"), "Padding") !== padding)) {
			luaSet(luaProp(spinner, "Layout"), "Padding", padding);
		}
		let width: unknown = luaCall(digitCellWidth, spinner, scale);
		let watching: unknown = (luaIndex(digitWidths, spinner) !== undefined);
		luaSetIndex(digitWidths, spinner, width);
		for (const [_, child] of pairs((colon(luaProp(spinner, "Frame")).GetChildren()) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
			luaCall(sizeDigit, child, width);
		}
		if ((!watching)) {
			colon(luaProp(luaProp(spinner, "Frame"), "ChildAdded")).Connect(function(child?: unknown): unknown | undefined {
				luaCall(luaProp(task, "defer"), function(): unknown | undefined {
					let current: unknown = luaIndex(digitWidths, spinner);
					if (((luaTypeIs(current, "number")) && (luaProp(child, "Parent") !== undefined))) {
						luaCall(sizeDigit, child, current);
					}
					return undefined;
				});
				return undefined;
			});
		}
		return undefined;
	}
	function rollDurationForJump(base?: unknown, fromRaw?: unknown, toRaw?: unknown, fromBand?: unknown, toBand?: unknown, motionScale?: unknown): unknown | undefined {
		let scale: unknown = luaCall(luaProp(math, "clamp"), ((motionScale === undefined) ? 1 : motionScale), 0.35, 1.35);
		if ((fromBand !== toBand)) {
			return ((0.04 as unknown as number) * (scale as unknown as number));
		}
		let jump: unknown = luaCall(luaProp(math, "abs"), ((toRaw as unknown as number) - (fromRaw as unknown as number)));
		let magnitude: unknown = luaCall(luaProp(math, "log10"), luaCall(luaProp(math, "max"), 1, jump));
		let rel: unknown = (((fromRaw as unknown as number) > (0 as unknown as number)) ? ((jump as unknown as number) / (fromRaw as unknown as number)) : jump);
		if ((((magnitude as unknown as number) >= (6 as unknown as number)) || ((rel as unknown as number) >= (0.35 as unknown as number)))) {
			return ((0.08 as unknown as number) * (scale as unknown as number));
		}
		if ((((magnitude as unknown as number) >= (4 as unknown as number)) || ((rel as unknown as number) >= (0.12 as unknown as number)))) {
			return ((0.16 as unknown as number) * (scale as unknown as number));
		}
		let fromParts: unknown = luaCall(compactSpinParts, fromRaw);
		let toParts: unknown = luaCall(compactSpinParts, toRaw);
		let mantJump: unknown = luaCall(luaProp(math, "abs"), ((luaProp(toParts, "value") as unknown as number) - (luaProp(fromParts, "value") as unknown as number)));
		if (((mantJump as unknown as number) >= (50 as unknown as number))) {
			return ((0.14 as unknown as number) * (scale as unknown as number));
		}
		if (((mantJump as unknown as number) >= (8 as unknown as number))) {
			return ((0.24 as unknown as number) * (scale as unknown as number));
		}
		return luaCall(luaProp(math, "clamp"), ((((base as unknown as number) * (0.62 as unknown as number)) as unknown as number) * (scale as unknown as number)), 0.26, 0.33);
		return undefined;
	}
	let VELOCITY_TICK_HZ: unknown = 5;
	let VELOCITY_TICK_DT: unknown = ((1 as unknown as number) / (VELOCITY_TICK_HZ as unknown as number));
	let velocitySteps: unknown = {};
	let velocityStepCount: unknown = 0;
	let velocityWorker: unknown = undefined;
	function registerVelocityStep(step?: unknown): unknown | undefined {
		luaSetIndex(velocitySteps, step, true);
		velocityStepCount = ((velocityStepCount as unknown as number) + (1 as unknown as number));
		if ((velocityWorker === undefined)) {
			velocityWorker = luaCall(luaProp(task, "spawn"), function(): unknown | undefined {
				while (((velocityStepCount as unknown as number) > (0 as unknown as number))) {
					luaCall(luaProp(task, "wait"), VELOCITY_TICK_DT);
					for (const [step] of pairs((velocitySteps) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
						luaCall(pcall, step);
					}
				}
				velocityWorker = undefined;
				return undefined;
			});
		}
		return function(): unknown | undefined {
			if (luaIndex(velocitySteps, step)) {
				luaSetIndex(velocitySteps, step, undefined);
				velocityStepCount = ((velocityStepCount as unknown as number) - (1 as unknown as number));
			}
			return undefined;
		};
		return undefined;
	}
	let VELOCITY_ROLL: unknown = 0.07;
	function NumberSpinnerHost(_param?: unknown): unknown | undefined {
		let value: unknown = luaProp(_param, "value");
		let requestedReducedMotion: unknown = luaProp(_param, "reducedMotion");
		if ((requestedReducedMotion === undefined)) {
			requestedReducedMotion = false;
		}
		let duration: unknown = luaProp(_param, "duration");
		if ((duration === undefined)) {
			duration = 0.78;
		}
		let prefix: unknown = luaProp(_param, "prefix");
		if ((prefix === undefined)) {
			prefix = "";
		}
		let extraSuffix: unknown = luaProp(_param, "extraSuffix");
		if ((extraSuffix === undefined)) {
			extraSuffix = "";
		}
		let spacedSuffix: unknown = luaProp(_param, "spacedSuffix");
		if ((spacedSuffix === undefined)) {
			spacedSuffix = false;
		}
		let _decimals: unknown = luaProp(_param, "decimals");
		if ((_decimals === undefined)) {
			_decimals = 0;
		}
		let velocity: unknown = luaProp(_param, "velocity");
		if ((velocity === undefined)) {
			velocity = 0;
		}
		let size: unknown = luaProp(_param, "size");
		if ((size === undefined)) {
			size = 16;
		}
		let color: unknown = luaProp(_param, "color");
		if ((color === undefined)) {
			color = luaProp(Palette, "white");
		}
		let align: unknown = luaProp(_param, "align");
		if ((align === undefined)) {
			align = luaProp(luaProp(Enum, "TextXAlignment"), "Left");
		}
		let position: unknown = luaProp(_param, "position");
		let sizeConstraint: unknown = luaProp(_param, "sizeConstraint");
		if ((sizeConstraint === undefined)) {
			sizeConstraint = luaCall(luaProp(UDim2, "fromScale"), 1, 1);
		}
		let autoWidth: unknown = luaProp(_param, "autoWidth");
		if ((autoWidth === undefined)) {
			autoWidth = false;
		}
		let digitWidthScale: unknown = luaProp(_param, "digitWidthScale");
		if ((digitWidthScale === undefined)) {
			digitWidthScale = 1;
		}
		let digitGap: unknown = luaProp(_param, "digitGap");
		if ((digitGap === undefined)) {
			digitGap = 0;
		}
		let zIndex: unknown = luaProp(_param, "zIndex");
		if ((zIndex === undefined)) {
			zIndex = 1;
		}
		let layoutOrder: unknown = luaProp(_param, "layoutOrder");
		if ((layoutOrder === undefined)) {
			layoutOrder = 0;
		}
		let _binding: unknown = luaCall(useMotionSettings);
		let numberScale: unknown = luaProp(_binding, "numberScale");
		if ((numberScale === undefined)) {
			numberScale = 1;
		}
		let motionScale: unknown = luaProp(_binding, "motionScale");
		if ((motionScale === undefined)) {
			motionScale = 1;
		}
		let reducedMotion: unknown = (requestedReducedMotion || ((numberScale as unknown as number) <= (0.02 as unknown as number)));
		let hostRef: unknown = reactLoose.useRef();
		let spinnerRef: unknown = reactLoose.useRef();
		let guideRef: unknown = reactLoose.useRef();
		let fallbackRef: unknown = reactLoose.useRef();
		let lastRawRef: unknown = reactLoose.useRef(undefined);
		let lastBandRef: unknown = reactLoose.useRef("");
		let lastMantissaRef: unknown = reactLoose.useRef(undefined);
		let targetRef: unknown = reactLoose.useRef(value);
		let velocityRef: unknown = reactLoose.useRef(velocity);
		let autoWidthRef: unknown = reactLoose.useRef(autoWidth);
		let styleRef: unknown = reactLoose.useRef({ duration: duration, prefix: prefix, extraSuffix: extraSuffix, spacedSuffix: spacedSuffix, size: size, color: color, align: align, digitWidthScale: digitWidthScale, digitGap: digitGap });
		let velocitySnapRef: unknown = reactLoose.useRef(false);
		let pulseResetRef: unknown = reactLoose.useRef();
		let motionScaleRef: unknown = reactLoose.useRef(motionScale);
		luaSet(motionScaleRef, "current", motionScale);
		let live: unknown;
		let setLive: unknown;
		[live, setLive] = reactLoose.useState(false) as LuaTuple<[unknown, unknown]>;
		let label: unknown = luaCall(formatRawLabel, value, prefix, extraSuffix, spacedSuffix);
		let contentWidth: unknown;
		let setContentWidth: unknown;
		[contentWidth, setContentWidth] = reactLoose.useState(function(): unknown | undefined {
			return luaCall(estimateLabelWidth, label, size);
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		let contentWidthRef: unknown = reactLoose.useRef(contentWidth);
		let quietChromeRef: unknown = reactLoose.useRef({ size: undefined, color: undefined, align: undefined, prefix: undefined, suffix: undefined });
		luaSet(targetRef, "current", value);
		luaSet(velocityRef, "current", velocity);
		luaSet(autoWidthRef, "current", autoWidth);
		luaSet(styleRef, "current", { duration: duration, prefix: prefix, extraSuffix: extraSuffix, spacedSuffix: spacedSuffix, size: size, color: color, align: align, digitWidthScale: digitWidthScale, digitGap: digitGap });
		let pulseAccent: unknown = reactLoose.useCallback(function(spinner?: unknown, base?: unknown): unknown | undefined {
			if ((luaProp(pulseResetRef, "current") !== undefined)) {
				luaCall(pcall, luaProp(task, "cancel"), luaProp(pulseResetRef, "current"));
			}
			luaSet(spinner, "TextColor3", luaCall(lighten, base, 0.48));
			luaSet(pulseResetRef, "current", luaCall(luaProp(task, "delay"), 0.18, function(): unknown | undefined {
				luaSet(pulseResetRef, "current", undefined);
				if ((luaProp(spinnerRef, "current") !== spinner)) {
					return undefined;
				}
				luaSet(spinner, "TextColor3", luaProp(luaProp(styleRef, "current"), "color"));
				return undefined;
			}));
			return undefined;
		}, {});
		let destroySpinner: unknown = reactLoose.useCallback(function(): unknown | undefined {
			if ((luaProp(pulseResetRef, "current") !== undefined)) {
				luaCall(pcall, luaProp(task, "cancel"), luaProp(pulseResetRef, "current"));
				luaSet(pulseResetRef, "current", undefined);
			}
			let spinner: unknown = luaProp(spinnerRef, "current");
			luaSet(spinnerRef, "current", undefined);
			luaSet(lastRawRef, "current", undefined);
			luaSet(lastMantissaRef, "current", undefined);
			luaSet(lastBandRef, "current", "");
			if ((spinner !== undefined)) {
				let frame: unknown = luaProp(spinner, "Frame");
				let destroyed: unknown = luaCall(pcall, function(): unknown | undefined {
					colon(spinner).Destroy();
					return undefined;
				});
				if (((!destroyed) && (typeOf(frame) === "Instance"))) {
					luaCall(pcall, function(): unknown | undefined {
						colon(frame).Destroy();
						return undefined;
					});
				}
			}
			let guide: unknown = luaProp(guideRef, "current");
			if ((guide !== undefined)) {
				colon(guide).Destroy();
				luaSet(guideRef, "current", undefined);
			}
			let fallback: unknown = luaProp(fallbackRef, "current");
			if ((fallback !== undefined)) {
				luaSet(fallback, "Visible", true);
				luaSet(fallback, "TextTransparency", 0);
			}
			luaCall(setLive, false);
			return undefined;
		}, {});
		let pushDisplay: unknown = reactLoose.useCallback(function(spinner?: unknown, raw?: unknown, roll?: unknown, pulse?: unknown): unknown | undefined {
			let style: unknown = luaProp(styleRef, "current");
			let display: unknown = luaCall(spinDisplay, raw, luaProp(style, "extraSuffix"), luaProp(style, "spacedSuffix"));
			let mantissa: unknown = luaCall(sanitizeValue, luaProp(display, "value"), luaProp(display, "decimals"));
			let prevMantissa: unknown = luaProp(lastMantissaRef, "current");
			let bandChanged: unknown = (luaProp(lastBandRef, "current") !== luaProp(display, "band"));
			luaSet(lastRawRef, "current", raw);
			if (((prevMantissa === mantissa) && (!bandChanged))) {
				let quiet: unknown = luaProp(quietChromeRef, "current");
				if ((luaProp(quiet, "size") !== luaProp(style, "size"))) {
					luaSet(spinner, "TextSize", luaProp(style, "size"));
					luaSet(quiet, "size", luaProp(style, "size"));
				}
				if ((luaProp(quiet, "color") !== luaProp(style, "color"))) {
					luaSet(spinner, "TextColor3", luaProp(style, "color"));
					luaSet(quiet, "color", luaProp(style, "color"));
				}
				if ((luaProp(quiet, "align") !== luaProp(style, "align"))) {
					luaSet(spinner, "TextXAlignment", luaProp(style, "align"));
					luaSet(quiet, "align", luaProp(style, "align"));
				}
				if ((luaProp(quiet, "prefix") !== luaProp(style, "prefix"))) {
					luaSet(spinner, "Prefix", luaProp(style, "prefix"));
					luaSet(quiet, "prefix", luaProp(style, "prefix"));
				}
				if ((luaProp(quiet, "suffix") !== luaProp(display, "suffix"))) {
					luaSet(spinner, "Suffix", luaProp(display, "suffix"));
					luaSet(quiet, "suffix", luaProp(display, "suffix"));
				}
				return undefined;
			}
			luaCall(applyChrome, spinner, { duration: roll, decimals: luaProp(display, "decimals"), prefix: luaProp(style, "prefix"), suffix: luaProp(display, "suffix"), size: luaProp(style, "size"), color: luaProp(style, "color"), align: luaProp(style, "align") });
			luaSet(lastBandRef, "current", luaProp(display, "band"));
			luaSet(luaProp(quietChromeRef, "current"), "size", luaProp(style, "size"));
			luaSet(luaProp(quietChromeRef, "current"), "color", luaProp(style, "color"));
			luaSet(luaProp(quietChromeRef, "current"), "align", luaProp(style, "align"));
			luaSet(luaProp(quietChromeRef, "current"), "prefix", luaProp(style, "prefix"));
			luaSet(luaProp(quietChromeRef, "current"), "suffix", luaProp(display, "suffix"));
			luaSet(spinner, "Value", mantissa);
			luaCall(setDigitTracking, spinner, luaProp(style, "digitWidthScale"), luaProp(style, "digitGap"));
			luaSet(lastMantissaRef, "current", mantissa);
			if ((pulse && (prevMantissa !== undefined))) {
				luaCall(pulseAccent, spinner, luaProp(style, "color"));
			}
			return undefined;
		}, [pulseAccent]);
		let ensureSpinner: unknown = reactLoose.useCallback(function(): unknown | undefined {
			if (reducedMotion) {
				return undefined;
			}
			let existing: unknown = luaProp(spinnerRef, "current");
			let existingFrame: unknown = ((existing !== undefined) ? luaProp(existing, "Frame") : undefined);
			if (((typeOf(existingFrame) === "Instance") && (luaProp(existingFrame, "Parent") !== undefined))) {
				return existing;
			}
			luaCall(destroySpinner);
			let host: unknown = luaProp(hostRef, "current");
			let mod: unknown = luaCall(loadModule);
			if (((host === undefined) || (mod === undefined))) {
				return undefined;
			}
			let fallback: unknown = luaProp(fallbackRef, "current");
			if ((fallback !== undefined)) {
				luaSet(fallback, "Visible", false);
				luaSet(fallback, "TextTransparency", 1);
			}
			for (const [_, child] of pairs((colon(host).GetChildren()) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
				if (((luaProp(child, "Name") === "NumberSpinnerGuide") || (luaCall(luaProp(string, "sub"), luaProp(child, "Name"), 1, 8) === "Spinner_"))) {
					colon(child).Destroy();
				}
			}
			let style: unknown = luaProp(styleRef, "current");
			// The spinner takes over a guide label of its own. It must not be the fallback label:
			// the fallback is hidden once the spinner runs, and anything inside it would vanish too.
			let guide: unknown = new (Instance as unknown as new (...args: unknown[]) => unknown)("TextLabel");
			luaSet(guide, "Name", "NumberSpinnerGuide");
			luaSet(guide, "BackgroundTransparency", 1);
			luaSet(guide, "BorderSizePixel", 0);
			luaSet(guide, "Size", (luaProp(autoWidthRef, "current") ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0) : luaCall(luaProp(UDim2, "fromScale"), 1, 1)));
			luaSet(guide, "AutomaticSize", (luaProp(autoWidthRef, "current") ? luaProp(luaProp(Enum, "AutomaticSize"), "X") : luaProp(luaProp(Enum, "AutomaticSize"), "None")));
			luaSet(guide, "FontFace", SPINNER_FONT);
			luaSet(guide, "TextSize", luaProp(style, "size"));
			luaSet(guide, "TextColor3", luaProp(style, "color"));
			luaSet(guide, "TextXAlignment", luaProp(style, "align"));
			luaSet(guide, "TextYAlignment", luaProp(luaProp(Enum, "TextYAlignment"), "Center"));
			luaSet(guide, "TextScaled", false);
			luaSet(guide, "TextStrokeTransparency", 1);
			luaSet(guide, "TextStrokeColor3", luaCall(luaProp(Color3, "fromRGB"), 0, 0, 0));
			luaSet(guide, "Text", "");
			luaSet(guide, "Parent", host);
			luaSet(guideRef, "current", guide);
			let spinner: unknown = ((luaProp(mod, "fromGuiObject") !== undefined) ? luaCall(luaProp(mod, "fromGuiObject"), guide) : undefined);
			if ((spinner === undefined)) {
				spinner = luaCall(luaProp(mod, "new"));
				luaSet(spinner, "Parent", host);
				luaSet(spinner, "Size", (luaProp(autoWidthRef, "current") ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0) : luaCall(luaProp(UDim2, "fromScale"), 1, 1)));
				luaSet(spinner, "Position", luaCall(luaProp(UDim2, "fromScale"), 0, 0));
				luaSet(spinner, "BackgroundTransparency", 1);
				luaSet(spinner, "FontFace", luaProp(guide, "FontFace"));
				luaSet(guide, "Visible", false);
			}
			if (luaProp(autoWidthRef, "current")) {
				luaSet(spinner, "AutomaticSize", luaProp(luaProp(Enum, "AutomaticSize"), "X"));
				luaSet(spinner, "Size", new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0));
				luaSet(spinner, "ClipsDescendants", true);
				luaCall(hugSpinnerContent, host);
			}
			let initialRaw: unknown = luaProp(targetRef, "current");
			let display: unknown = luaCall(spinDisplay, initialRaw, luaProp(style, "extraSuffix"), luaProp(style, "spacedSuffix"));
			luaCall(applyChrome, spinner, { duration: 0.08, decimals: luaProp(display, "decimals"), prefix: luaProp(style, "prefix"), suffix: luaProp(display, "suffix"), size: luaProp(style, "size"), color: luaProp(style, "color"), align: luaProp(style, "align") });
			let mantissa: unknown = luaCall(sanitizeValue, luaProp(display, "value"), luaProp(display, "decimals"));
			luaSet(spinner, "Value", mantissa);
			luaCall(setDigitTracking, spinner, luaProp(style, "digitWidthScale"), luaProp(style, "digitGap"));
			luaSet(lastRawRef, "current", initialRaw);
			luaSet(lastBandRef, "current", luaProp(display, "band"));
			luaSet(lastMantissaRef, "current", mantissa);
			luaSet(spinnerRef, "current", spinner);
			luaCall(setLive, true);
			return spinner;
			return undefined;
		}, [destroySpinner, reducedMotion]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (reducedMotion) {
				luaCall(destroySpinner);
				return undefined;
			}
			let cancelled: unknown = false;
			let attempts: unknown = 0;
			let retryJob: unknown;
			let tryMount: unknown;
			tryMount = function(): unknown | undefined {
				if (cancelled) {
					return undefined;
				}
				attempts = ((attempts as unknown as number) + (1 as unknown as number));
				if (((luaCall(ensureSpinner) === undefined) && ((attempts as unknown as number) < (100 as unknown as number)))) {
					retryJob = luaCall(luaProp(task, "delay"), 0.1, tryMount);
				}
				return undefined;
			};
			let mountJob: unknown = luaCall(luaProp(task, "defer"), tryMount);
			return function(): unknown | undefined {
				cancelled = true;
				if ((mountJob !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), mountJob);
				}
				if ((retryJob !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), retryJob);
				}
				mountJob = undefined;
				retryJob = undefined;
				luaCall(destroySpinner);
				return undefined;
			};
			return undefined;
		}, [destroySpinner, ensureSpinner, reducedMotion]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (reducedMotion) {
				return undefined;
			}
			let spinner: unknown = luaCall(ensureSpinner);
			if ((spinner === undefined)) {
				return undefined;
			}
			let style: unknown = luaProp(styleRef, "current");
			let previous: unknown = luaProp(lastRawRef, "current");
			let producing: unknown = ((luaProp(velocityRef, "current") as unknown as number) > (0 as unknown as number));
			if ((producing && (previous !== undefined))) {
				let jump: unknown = luaCall(luaProp(math, "abs"), ((value as unknown as number) - (previous as unknown as number)));
				if ((((jump as unknown as number) > (0 as unknown as number)) && ((jump as unknown as number) < (luaCall(luaProp(math, "max"), 3, ((luaProp(velocityRef, "current") as unknown as number) * (0.35 as unknown as number))) as unknown as number)))) {
					return undefined;
				}
			}
			let fromBand: unknown = ((previous !== undefined) ? luaProp(luaCall(spinDisplay, previous, luaProp(style, "extraSuffix"), luaProp(style, "spacedSuffix")), "band") : "");
			let toBand: unknown = luaProp(luaCall(spinDisplay, value, luaProp(style, "extraSuffix"), luaProp(style, "spacedSuffix")), "band");
			let roll: unknown = ((previous !== undefined) ? luaCall(rollDurationForJump, luaProp(style, "duration"), previous, value, fromBand, toBand, luaProp(motionScaleRef, "current")) : 0.08);
			luaSet(velocitySnapRef, "current", false);
			let jump: unknown = ((previous !== undefined) ? luaCall(luaProp(math, "abs"), ((value as unknown as number) - (previous as unknown as number))) : 0);
			let shouldPulse: unknown = ((previous !== undefined) && ((jump as unknown as number) >= (luaCall(luaProp(math, "max"), 18, ((((luaCall(luaProp(math, "abs"), previous) as unknown as number) * (0.03 as unknown as number)) as unknown as number) + (1 as unknown as number))) as unknown as number)));
			luaCall(pushDisplay, spinner, value, roll, shouldPulse);
			return undefined;
		}, [align, color, duration, ensureSpinner, extraSuffix, prefix, pushDisplay, reducedMotion, size, value]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((((!live) || reducedMotion) || ((velocity as unknown as number) <= (0 as unknown as number)))) {
				return undefined;
			}
			let alive: unknown = true;
			let _condition: unknown = luaProp(lastRawRef, "current");
			if ((_condition === undefined)) {
				_condition = luaProp(targetRef, "current");
			}
			let displayRaw: unknown = _condition;
			let previousAt: unknown = luaCall(luaProp(os, "clock"));
			function step(): unknown | undefined {
				{
						if ((!alive)) {
							return;
						}
						let now: unknown = luaCall(luaProp(os, "clock"));
						let dt: unknown = luaCall(luaProp(math, "min"), 1, ((now as unknown as number) - (previousAt as unknown as number)));
						previousAt = now;
						let spinner: unknown = luaCall(ensureSpinner);
						if ((spinner === undefined)) {
							return;
						}
						let server: unknown = luaProp(targetRef, "current");
						let rate: unknown = luaCall(luaProp(math, "max"), 0, luaProp(velocityRef, "current"));
						if (((server as unknown as number) > (displayRaw as unknown as number))) {
							displayRaw = server;
						}
						displayRaw = ((displayRaw as unknown as number) + (((rate as unknown as number) * (dt as unknown as number)) as unknown as number));
						let ceiling: unknown = ((server as unknown as number) + (((rate as unknown as number) * (2 as unknown as number)) as unknown as number));
						if (((displayRaw as unknown as number) > (ceiling as unknown as number))) {
							displayRaw = ceiling;
						}
						let style: unknown = luaProp(styleRef, "current");
						let compact: unknown = luaCall(spinDisplay, displayRaw, luaProp(style, "extraSuffix"), luaProp(style, "spacedSuffix"));
						let mantissa: unknown = luaCall(sanitizeValue, luaProp(compact, "value"), luaProp(compact, "decimals"));
						if (((mantissa === luaProp(lastMantissaRef, "current")) && (luaProp(compact, "band") === luaProp(lastBandRef, "current")))) {
							luaSet(lastRawRef, "current", displayRaw);
							return;
						}
						let bandChanged: unknown = (luaProp(lastBandRef, "current") !== luaProp(compact, "band"));
						let roll: unknown = (bandChanged ? 0.03 : VELOCITY_ROLL);
						if (((!luaProp(velocitySnapRef, "current")) || bandChanged)) {
							luaSet(velocitySnapRef, "current", true);
						}
						luaCall(applyChrome, spinner, { duration: roll, decimals: luaProp(compact, "decimals"), prefix: luaProp(style, "prefix"), suffix: luaProp(compact, "suffix"), size: luaProp(style, "size"), color: luaProp(style, "color"), align: luaProp(style, "align") });
						luaSet(spinner, "Value", mantissa);
						luaSet(lastRawRef, "current", displayRaw);
						luaSet(lastBandRef, "current", luaProp(compact, "band"));
						luaSet(lastMantissaRef, "current", mantissa);
					}
				return undefined;
			}
			let unregister: unknown = luaCall(registerVelocityStep, step);
			return function(): unknown | undefined {
				alive = false;
				luaCall(unregister);
				return undefined;
			};
			return undefined;
		}, [ensureSpinner, live, reducedMotion, velocity]);
		reactLoose.useEffect(function(): unknown | undefined {
			if ((!autoWidth)) {
				return undefined;
			}
			if ((reducedMotion || (!live))) {
				let estimated: unknown = luaCall(estimateLabelWidth, label, size);
				luaSet(contentWidthRef, "current", estimated);
				luaCall(setContentWidth, estimated);
				return undefined;
			}
			let host: unknown = luaProp(hostRef, "current");
			if ((host === undefined)) {
				return undefined;
			}
			let connections: unknown = {};
			let boundLayout: unknown;
			let layoutConnection: unknown;
			let settleJob: unknown;
			let cancelled: unknown = false;
			let sync: unknown;
			sync = function(): unknown | undefined {
				if (cancelled) {
					return undefined;
				}
				let layout: unknown = (luaCall(hugSpinnerContent, host) || luaCall(findSpinnerLayout, host));
				if ((layout === undefined)) {
					return undefined;
				}
				if ((boundLayout !== layout)) {
					let _result: unknown = layoutConnection;
					if ((_result !== undefined)) {
						colon(_result).Disconnect();
					}
					boundLayout = layout;
					layoutConnection = colon(colon(layout).GetPropertyChangedSignal("AbsoluteContentSize")).Connect(sync);
				}
				let measured: unknown = ((luaCall(luaProp(math, "ceil"), luaProp(luaProp(layout, "AbsoluteContentSize"), "X")) as unknown as number) + (AUTO_WIDTH_PAD as unknown as number));
				if ((((measured as unknown as number) > (AUTO_WIDTH_PAD as unknown as number)) && ((measured as unknown as number) > (luaProp(contentWidthRef, "current") as unknown as number)))) {
					luaSet(contentWidthRef, "current", measured);
					luaCall(setContentWidth, measured);
				}
				if ((settleJob !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), settleJob);
				}
				settleJob = luaCall(luaProp(task, "delay"), 0.24, function(): unknown | undefined {
					settleJob = undefined;
					if ((cancelled || (boundLayout === undefined))) {
						return undefined;
					}
					let settled: unknown = ((luaCall(luaProp(math, "ceil"), luaProp(luaProp(boundLayout, "AbsoluteContentSize"), "X")) as unknown as number) + (AUTO_WIDTH_PAD as unknown as number));
					if ((((settled as unknown as number) > (AUTO_WIDTH_PAD as unknown as number)) && (settled !== luaProp(contentWidthRef, "current")))) {
						luaSet(contentWidthRef, "current", settled);
						luaCall(setContentWidth, settled);
					}
					return undefined;
				});
				return undefined;
			};
			luaCall(sync);
			let _arg0: unknown = colon(luaProp(host, "ChildAdded")).Connect(sync);
			luaTable.insert(connections, _arg0);
			return function(): unknown | undefined {
				cancelled = true;
				if ((settleJob !== undefined)) {
					luaCall(pcall, luaProp(task, "cancel"), settleJob);
				}
				let _result: unknown = layoutConnection;
				if ((_result !== undefined)) {
					colon(_result).Disconnect();
				}
				for (const [_, connection] of pairs((connections) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					colon(connection).Disconnect();
				}
				return undefined;
			};
			return undefined;
		}, [autoWidth, live, reducedMotion, size]);
		reactLoose.useEffect(function(): unknown | undefined {
			if (((!autoWidth) || (((!reducedMotion) && live)))) {
				return undefined;
			}
			let estimated: unknown = luaCall(estimateLabelWidth, label, size);
			luaSet(contentWidthRef, "current", estimated);
			luaCall(setContentWidth, estimated);
			return undefined;
		}, [autoWidth, label, live, reducedMotion, size]);
		let height: unknown = (((luaProp(luaProp(sizeConstraint, "Y"), "Offset") as unknown as number) > (0 as unknown as number)) ? luaProp(luaProp(sizeConstraint, "Y"), "Offset") : ((size as unknown as number) + (8 as unknown as number)));
		let frameSize: unknown = (autoWidth ? luaCall(luaProp(UDim2, "fromOffset"), luaCall(luaProp(math, "max"), 1, contentWidth), height) : sizeConstraint);
		let hostSize: unknown = (autoWidth ? new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0) : luaCall(luaProp(UDim2, "fromScale"), 1, 1));
		return reactLoose.createElement("frame", { Size: frameSize, Position: position, BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ZIndex: zIndex, LayoutOrder: layoutOrder }, reactLoose.createElement("frame", { ref: hostRef, Size: hostSize, AutomaticSize: (autoWidth ? luaProp(luaProp(Enum, "AutomaticSize"), "X") : luaProp(luaProp(Enum, "AutomaticSize"), "None")), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: false, ZIndex: ((zIndex as unknown as number) + (1 as unknown as number)) }), (((reducedMotion || (!live))) && ((autoWidth ? reactLoose.createElement("textlabel", { ref: fallbackRef, Size: new (UDim2 as unknown as new (...args: unknown[]) => unknown)(0, 0, 1, 0), AutomaticSize: luaProp(luaProp(Enum, "AutomaticSize"), "X"), BackgroundTransparency: 1, BorderSizePixel: 0, Text: label, TextColor3: color, TextSize: size, FontFace: SPINNER_FONT, TextXAlignment: align, TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center"), TextStrokeTransparency: 1, ZIndex: zIndex }) : reactLoose.createElement("textlabel", { ref: fallbackRef, Size: luaCall(luaProp(UDim2, "fromScale"), 1, 1), BackgroundTransparency: 1, BorderSizePixel: 0, ClipsDescendants: true, Text: label, TextColor3: color, TextSize: size, FontFace: SPINNER_FONT, TextXAlignment: align, TextYAlignment: luaProp(luaProp(Enum, "TextYAlignment"), "Center"), TextScaled: true, TextTruncate: luaProp(luaProp(Enum, "TextTruncate"), "AtEnd"), TextStrokeTransparency: 1, ZIndex: zIndex }, reactLoose.createElement("uitextsizeconstraint", { MinTextSize: luaCall(luaProp(math, "min"), 10, luaCall(luaProp(math, "max"), 1, size)), MaxTextSize: luaCall(luaProp(math, "max"), size, 1) }))))));
		return undefined;
	}
	return { NumberSpinnerHost: NumberSpinnerHost };
};

__defs["egooeHost"] = () => {
	let Players: unknown = colon(game).GetService("Players");
	let ReplicatedStorage: unknown = colon(game).GetService("ReplicatedStorage");
	let RunService: unknown = colon(game).GetService("RunService");
	let Stats: unknown = colon(game).GetService("Stats");
	let UserInputService: unknown = colon(game).GetService("UserInputService");
	let HOST_NAME: unknown = "AstralForgeEgooE";
	function loadEgooe(): unknown | undefined {
		let include: unknown = colon(ReplicatedStorage).FindFirstChild("rbxts_include");
		let _modules: unknown = include;
		if ((_modules !== undefined)) {
			_modules = colon(_modules).FindFirstChild("node_modules");
		}
		let modules: unknown = _modules;
		let _scope: unknown = modules;
		if ((_scope !== undefined)) {
			_scope = colon(_scope).FindFirstChild("@rbxts");
		}
		let scope: unknown = _scope;
		let _pack: unknown = scope;
		if ((_pack !== undefined)) {
			_pack = colon(_pack).FindFirstChild("egooe");
		}
		let pack: unknown = _pack;
		let _out: unknown = pack;
		if ((_out !== undefined)) {
			_out = colon(_out).FindFirstChild("out");
		}
		let out: unknown = _out;
		if (((out === undefined) || (!colon(out).IsA("ModuleScript")))) {
			return undefined;
		}
		let ok: unknown;
		let loaded: unknown;
		[ok, loaded] = luaCall(pcall, function(): unknown | undefined {
			return luaRequire(out);
			return undefined;
		}) as LuaTuple<[unknown, unknown]>;
		if ((!ok)) {
			luaCall(warn, `[WARN] [EGOOE] couldn't load studio overlay: ${luaCall(tostring, loaded)}`);
			return undefined;
		}
		return loaded;
		return undefined;
	}
	function startEgooeHost(playerGui?: unknown): unknown | undefined {
		if ((!colon(RunService).IsStudio())) {
			return function(): unknown | undefined {
				return undefined;
				return undefined;
			};
		}
		let hostGui: unknown = (playerGui || colon(luaProp(Players, "LocalPlayer")).FindFirstChildOfClass("PlayerGui"));
		if ((hostGui === undefined)) {
			return function(): unknown | undefined {
				return undefined;
				return undefined;
			};
		}
		let stale: unknown = colon(hostGui).FindFirstChild(HOST_NAME);
		if ((stale !== undefined)) {
			colon(stale).Destroy();
		}
		let layer: unknown = new (Instance as unknown as new (...args: unknown[]) => unknown)("ScreenGui");
		luaSet(layer, "Name", HOST_NAME);
		luaSet(layer, "ResetOnSpawn", false);
		luaSet(layer, "IgnoreGuiInset", true);
		luaSet(layer, "DisplayOrder", 240);
		luaSet(layer, "ZIndexBehavior", luaProp(luaProp(Enum, "ZIndexBehavior"), "Sibling"));
		luaSet(layer, "Parent", hostGui);
		let api: unknown;
		let node: unknown;
		let open: unknown = false;
		let showDemo: unknown = false;
		let frames: unknown = 0;
		let fps: unknown = 60;
		let sampleAt: unknown = luaCall(luaProp(os, "clock"));
		let heartbeat: unknown;
		let paint: unknown = function(dt?: unknown): unknown | undefined {
			if ((api === undefined)) {
				return undefined;
			}
			frames = ((frames as unknown as number) + (1 as unknown as number));
			let now: unknown = luaCall(luaProp(os, "clock"));
			if (((((now as unknown as number) - (sampleAt as unknown as number)) as unknown as number) >= (0.4 as unknown as number))) {
				fps = ((frames as unknown as number) / (luaCall(luaProp(math, "max"), 0.001, ((now as unknown as number) - (sampleAt as unknown as number))) as unknown as number));
				frames = 0;
				sampleAt = now;
			}
			let player: unknown = luaProp(Players, "LocalPlayer");
			luaCall(luaProp(api, "start"), node, function(): unknown | undefined {
				if ((!open)) {
					return undefined;
				}
				let handle: unknown = luaCall(luaProp(api, "window"), { title: "Astral Forge", closable: true, minimizable: true, movable: true, resizable: true, size: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(340, 300), position: new (Vector2 as unknown as new (...args: unknown[]) => unknown)(18, 86) }, function(): unknown | undefined {
					luaCall(luaProp(api, "heading"), "Studio debug");
					luaCall(luaProp(api, "separator"));
					luaCall(luaProp(api, "label"), `FPS     ${luaCall(luaProp(string, "format"), "%.0f", fps)}  (${luaCall(luaProp(string, "format"), "%.1f", ((dt as unknown as number) * (1000 as unknown as number)))} ms)`);
					luaCall(luaProp(api, "label"), `Player  ${luaProp(player, "Name")}  (${luaProp(player, "UserId")})`);
					luaCall(luaProp(api, "label"), `Mem     ${luaCall(luaProp(string, "format"), "%.1f", colon(Stats).GetTotalMemoryUsageMb())} MB`);
					luaCall(luaProp(api, "label"), `Inst    ${luaProp(Stats, "InstanceCount")}`);
					luaCall(luaProp(api, "space"));
					luaCall(luaProp(api, "label"), "F8 toggles this overlay. It is not the game UI.");
					luaCall(luaProp(api, "separator"));
					let gallery: unknown = luaCall(luaProp(api, "checkbox"), "Widget gallery", { checked: showDemo });
					if (colon(gallery).clicked()) {
						showDemo = (!showDemo);
					}
					if (colon(luaCall(luaProp(api, "button"), "Close overlay")).clicked()) {
						open = false;
					}
					return undefined;
				});
				if (colon(handle).closed()) {
					open = false;
				}
				if (showDemo) {
					luaCall(luaProp(api, "demoWindow"));
				}
				return undefined;
			});
			return undefined;
		};
		let ensureHeartbeat: unknown = function(): unknown | undefined {
			if ((heartbeat !== undefined)) {
				return undefined;
			}
			heartbeat = colon(luaProp(RunService, "Heartbeat")).Connect(paint);
			return undefined;
		};
		let stopHeartbeat: unknown = function(): unknown | undefined {
			let _result: unknown = heartbeat;
			if ((_result !== undefined)) {
				colon(_result).Disconnect();
			}
			heartbeat = undefined;
			return undefined;
		};
		let setOpen: unknown = function(shouldOpen?: unknown): unknown | undefined {
			if ((shouldOpen && (api === undefined))) {
				api = luaCall(loadEgooe);
				if ((api === undefined)) {
					return undefined;
				}
				node = luaCall(luaProp(api, "new"), layer);
			}
			open = (shouldOpen && (api !== undefined));
			if (open) {
				luaCall(ensureHeartbeat);
			} else {
				luaCall(stopHeartbeat);
				for (const [_, child] of pairs((colon(layer).GetChildren()) as object) as IterableFunction<LuaTuple<[unknown, unknown]>>) {
					colon(child).Destroy();
				}
			}
			return undefined;
		};
		let input: unknown = colon(luaProp(UserInputService, "InputBegan")).Connect(function(inputObject?: unknown, processed?: unknown): unknown | undefined {
			if (processed) {
				return undefined;
			}
			if ((luaProp(inputObject, "KeyCode") !== luaProp(luaProp(Enum, "KeyCode"), "F8"))) {
				return undefined;
			}
			luaCall(setOpen, (!open));
			return undefined;
		});
		return function(): unknown | undefined {
			colon(input).Disconnect();
			luaCall(stopHeartbeat);
			colon(layer).Destroy();
			return undefined;
		};
		return undefined;
	}
	return { startEgooeHost: startEgooeHost };
};

__defs["AnimatedTitle"] = () => {
	let exports_: unknown = {};
	let _HyperTextHost: unknown = __load("HyperTextHost");
	luaSet(exports_, "AnimatedTitle", luaProp(_HyperTextHost, "AnimatedTitle"));
	luaSet(exports_, "AnimatedTitlePreview", luaProp(_HyperTextHost, "AnimatedTitlePreview"));
	luaSet(exports_, "darkTitlePlate", luaProp(_HyperTextHost, "darkTitlePlate"));
	luaSet(exports_, "titleTier", luaProp(_HyperTextHost, "titleTier"));
	luaSet(exports_, "parseFx", luaProp(_HyperTextHost, "parseFx"));
	luaSet(exports_, "titleFxAccent", luaProp(_HyperTextHost, "titleFxAccent"));
	luaSet(exports_, "TITLE_FX_KINDS", luaProp(_HyperTextHost, "TITLE_FX_KINDS"));
	return exports_;
};


const __members: string[] = [];
for (const [name] of pairs(__defs)) {
	__members.push(name);
}
__members.sort();
table.freeze(__members);

type ReactHostsCallable = ((name: string) => unknown) & { readonly __members: string[]; readonly [name: string]: unknown };
const ReactHosts = setmetatable(
	{},
	{
		__call: (_self: unknown, name: string): unknown => {
			return __load(name);
		},
		__index: (_self: unknown, name: string): unknown => {
			if (name === "__members") {
				return __members;
			}
			return __load(name);
		},
	} as LuaMetatable<object>,
) as unknown as ReactHostsCallable;

export = ReactHosts;
