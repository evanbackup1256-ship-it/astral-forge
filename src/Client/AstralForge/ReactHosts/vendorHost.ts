// Page-visit bookkeeping through vendored packages (matter, maid, lemon-signal, action-journal,
// set-timeout). Each is optional: a missing package just drops that sink.
const ReplicatedStorage = game.GetService("ReplicatedStorage");

type Fn = (...args: unknown[]) => unknown;
type Table = Record<string, unknown>;

function childOf(parent: unknown, name: string): Instance | undefined {
	if (!typeIs(parent, "Instance")) {
		return undefined;
	}
	return parent.FindFirstChild(name);
}

function requireChild(parent: unknown, name: string): Table | undefined {
	const child = childOf(parent, name);
	if (child === undefined || !child.IsA("ModuleScript")) {
		return undefined;
	}
	const [ok, loadedValue] = pcall(require, child);
	if (!ok || !typeIs(loadedValue, "table")) {
		return undefined;
	}
	return loadedValue as Table;
}

function moduleScript(parent: unknown, name: string): ModuleScript | undefined {
	const child = childOf(parent, name);
	if (child === undefined) {
		return undefined;
	}
	if (child.IsA("ModuleScript")) {
		return child;
	}
	const initScript = childOf(child, "init");
	if (initScript !== undefined && initScript.IsA("ModuleScript")) {
		return initScript;
	}
	return undefined;
}

const include = childOf(ReplicatedStorage, "rbxts_include");
const nodes = childOf(childOf(include, "node_modules"), "@rbxts");
const importScript = childOf(include, "TSImport");
let importTsModule: Fn | undefined;
if (importScript !== undefined && importScript.IsA("ModuleScript")) {
	const [ok, loadedValue] = pcall(require, importScript);
	if (ok && typeIs(loadedValue, "function")) {
		importTsModule = loadedValue as Fn;
	}
}

const servicesModule = requireChild(nodes, "services");
let Players: { LocalPlayer?: Player } = game.GetService("Players");
if (servicesModule !== undefined && servicesModule.Players !== undefined) {
	Players = servicesModule.Players as { LocalPlayer?: Player };
}

const maidModule = requireChild(childOf(nodes, "maid"), "Maid");
const signalModule = requireChild(childOf(nodes, "lemon-signal"), "src");
let Signal: Table | undefined;
if (signalModule !== undefined) {
	let candidate = signalModule.Signal;
	if (candidate === undefined) {
		candidate = signalModule.default;
	}
	if (typeIs(candidate, "table")) {
		Signal = candidate as Table;
	}
}
const matterModule = requireChild(childOf(nodes, "matter"), "lib");

interface MatterWorld {
	spawn(component: unknown): unknown;
	insert?: unknown;
}

let PageVisit: Fn | undefined;
let world: MatterWorld | undefined;
let session: unknown;
pcall(() => {
	const worldClass = matterModule?.World as Table | undefined;
	if (
		matterModule === undefined ||
		!typeIs(matterModule.component, "function") ||
		!typeIs(worldClass, "table") ||
		!typeIs(worldClass.new, "function")
	) {
		return undefined;
	}
	const visit = (matterModule.component as Fn)("PageVisit") as Fn;
	const nextWorld = (worldClass.new as Fn)() as MatterWorld;
	const nextSession = nextWorld.spawn(visit({ page: "Overview", at: 0 }));
	PageVisit = visit;
	world = nextWorld;
	session = nextSession;
});

interface Maid {
	GiveTask?: unknown;
	DoCleaning?: unknown;
}
interface NavSignal {
	Fire?: unknown;
	Destroy?: unknown;
}

let maid: Maid | undefined;
pcall(() => {
	if (maidModule !== undefined && typeIs(maidModule.new, "function")) {
		maid = (maidModule.new as Fn)() as Maid;
	}
});
let navigated: NavSignal | undefined;
pcall(() => {
	if (Signal !== undefined && typeIs(Signal.new, "function")) {
		navigated = (Signal.new as Fn)() as NavSignal;
	}
});
pcall(() => {
	if (maid !== undefined && navigated !== undefined && typeIs(maid.GiveTask, "function")) {
		(maid as { GiveTask(task: unknown): void }).GiveTask(navigated);
	}
});

interface JournalState {
	setPath?: unknown;
}

let journalState: JournalState | undefined;
let journalReady = false;
let debouncePage: unknown;

const journalScript = moduleScript(childOf(nodes, "action-journal"), "out");
if (journalScript !== undefined && typeIs(importTsModule, "function")) {
	const [loadedJournal, rawPkg] = pcall(importTsModule, journalScript);
	const journalPkg = rawPkg as { StateManager?: Table; ActionJournal?: Table } | undefined;
	if (
		loadedJournal &&
		typeIs(journalPkg, "table") &&
		typeIs(journalPkg.StateManager, "table") &&
		typeIs(journalPkg.ActionJournal, "table") &&
		typeIs(journalPkg.StateManager.new, "function") &&
		typeIs(journalPkg.ActionJournal.new, "function")
	) {
		pcall(() => {
			const state = (journalPkg.StateManager!.new as Fn)({ page: "Overview" }) as JournalState;
			(journalPkg.ActionJournal!.new as Fn)(state, { mode: 0, historySize: 32 });
			journalState = state;
			journalReady = true;
		});
	}
}

function authorName(): string {
	const [ok, name] = pcall(() => {
		const player = Players.LocalPlayer;
		if (player !== undefined) {
			return player.Name;
		}
		return undefined;
	});
	if (ok && typeIs(name, "string") && name !== "") {
		return name;
	}
	return "player";
}

function record(pageId: string) {
	if (journalReady && journalState !== undefined && typeIs(journalState.setPath, "function")) {
		const state = journalState as { setPath(path: string, value: unknown, author: string): void };
		pcall(() => {
			state.setPath("page", pageId, authorName());
		});
	}
	if (world !== undefined && session !== undefined && PageVisit !== undefined && typeIs(world.insert, "function")) {
		const target = world as { insert(entity: unknown, component: unknown): void };
		const visit = PageVisit;
		pcall(() => {
			target.insert(session, visit({ page: pageId, at: os.clock() }));
		});
	}
	if (navigated !== undefined && typeIs(navigated.Fire, "function")) {
		const signal = navigated as { Fire(value: unknown): void };
		pcall(() => {
			signal.Fire(pageId);
		});
	}
}

const timersScript = moduleScript(childOf(nodes, "set-timeout"), "out");
if (timersScript !== undefined && typeIs(importTsModule, "function")) {
	const [loadedTimers, timers] = pcall(importTsModule, timersScript);
	if (loadedTimers && typeIs(timers, "table") && typeIs((timers as Table).debounce, "function")) {
		pcall(() => {
			debouncePage = ((timers as Table).debounce as Fn)(record, 0.12, { leading: true, trailing: false });
		});
	}
}

function notePage(pageId: unknown) {
	if (!typeIs(pageId, "string") || pageId === "") {
		return undefined;
	}
	if (debouncePage !== undefined) {
		const [ok] = pcall(debouncePage as Fn, pageId);
		if (ok) {
			return undefined;
		}
	}
	record(pageId);
}

function shutdown() {
	pcall(() => {
		const debounced = debouncePage as { cancel?: Fn } | undefined;
		if (debounced !== undefined && debounced.cancel !== undefined) {
			debounced.cancel();
		}
	});
	pcall(() => {
		if (maid !== undefined && typeIs(maid.DoCleaning, "function")) {
			(maid as { DoCleaning(): void }).DoCleaning();
		} else if (navigated !== undefined && typeIs(navigated.Destroy, "function")) {
			(navigated as { Destroy(): void }).Destroy();
		}
	});
	debouncePage = undefined;
	journalReady = false;
	journalState = undefined;
	navigated = undefined;
	maid = undefined;
}

export { notePage, shutdown };
