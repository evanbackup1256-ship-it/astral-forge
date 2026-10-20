// UI shell runtime: tags the root ScreenGui, mirrors store and performance numbers onto it as
// attributes (for Studio debugging), and runs the layout guard. Plain TS: controllers are made
// once and driven straight off RunService, in a fixed order.
import { currentAntilagInfo } from "./MotionKit/antilag";
import { getActiveClientStore } from "./CoreKit/clientStore";
import { ClientLog } from "./CoreKit/log";
import LayoutGuard = require("./layoutGuard");

const CollectionService = game.GetService("CollectionService");
const RunService = game.GetService("RunService");

const UI_ROOT_TAG = "AstralForgeUiRoot";
const DIAGNOSTIC_INTERVAL_SECONDS = 1;

const ATTRIBUTE_DEFAULTS: Record<string, AttributeValue> = {
	AstralFramework: "0",
	AstralFrameworkReady: false,
	AstralRoute: "",
	AstralSnapshot: -1,
	AstralStateStatus: "starting",
	AstralAntilagTier: 3,
	AstralAntilagQuality: 1,
	AstralFps: 60,
	AstralHitchScore: 0,
	AstralRenderFps: 60,
	AstralStepMs: 16,
};

interface StoreState {
	navigation: { page: unknown };
	session?: { SnapshotId?: unknown };
}
interface ClientStoreLike {
	getState(): StoreState;
	changed: { connect(callback: (state: StoreState) => void): { disconnect(): void } };
}

interface UiRootHandle {
	instance: GuiObject;
}

/** Tracks the UI roots and tells listeners when one is added. */
class UiRootRegistry {
	private roots: UiRootHandle[] = [];
	private listeners: Array<(root: UiRootHandle) => unknown> = [];

	add(instance: Instance): UiRootHandle {
		for (const existing of this.roots) {
			if (existing.instance === instance) {
				return existing;
			}
		}
		const handle: UiRootHandle = { instance: instance as GuiObject };
		this.roots.push(handle);
		instance.Destroying.Once(() => {
			const index = this.roots.indexOf(handle);
			if (index !== -1) {
				this.roots.remove(index);
			}
		});
		for (const listener of this.listeners) {
			const [ok, reason] = pcall(listener, handle);
			if (!ok) {
				ClientLog.warn("framework", `ui root listener failed: ${tostring(reason)}`);
			}
		}
		return handle;
	}

	// the layout guard listens for roots through these two
	onComponentAdded(callback: (root: UiRootHandle) => unknown, _id?: string): void {
		this.listeners.push(callback);
	}

	getAllComponents(_id?: string): UiRootHandle[] {
		return [...this.roots];
	}

	primary(): UiRootHandle | undefined {
		for (const root of this.roots) {
			if (root.instance.Parent !== undefined) {
				return root;
			}
		}
		return undefined;
	}
}

function setAttribute(root: UiRootHandle | undefined, name: string, value: unknown) {
	if (root !== undefined && root.instance.Parent !== undefined) {
		root.instance.SetAttribute(name, value as AttributeValue);
	}
}

function attachRoot(instance: Instance) {
	if (instance.IsA("ScreenGui")) {
		instance.ResetOnSpawn = false;
		instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	}
	for (const [name, value] of pairs(ATTRIBUTE_DEFAULTS)) {
		if (instance.GetAttribute(name) === undefined) {
			instance.SetAttribute(name, value);
		}
	}
	instance.SetAttribute("AstralFramework", "1");
	instance.SetAttribute("AstralFrameworkReady", true);
	const store = getActiveClientStore() as ClientStoreLike | undefined;
	if (store === undefined) {
		instance.SetAttribute("AstralStateStatus", "store unavailable");
		return;
	}
	const sync = (state: StoreState) => {
		instance.SetAttribute("AstralRoute", tostring(state.navigation.page ?? ""));
		const snapshotId = state.session?.SnapshotId;
		instance.SetAttribute("AstralSnapshot", typeIs(snapshotId, "number") ? snapshotId : -1);
		instance.SetAttribute("AstralStateStatus", state.session === undefined ? "waiting for profile" : "live");
	};
	sync(store.getState());
	const connection = store.changed.connect(sync);
	instance.Destroying.Once(() => connection.disconnect());
}

const registry = new UiRootRegistry();
const layoutGuard = new LayoutGuard.LayoutGuardController(registry, registry);

let started = false;
let diagnosticElapsed = 0;
let renderElapsed = 0;
let renderFrames = 0;
let physicsElapsed = 0;
let physicsFrames = 0;

function guarded(label: string, run: () => void) {
	const [ok, reason] = pcall(run);
	if (!ok) {
		ClientLog.warnEvery(`framework-${label}`, 15, "framework", `${label} failed: ${tostring(reason)}`);
	}
}

function start() {
	started = true;
	guarded("layout guard init", () => layoutGuard.onInit());
	guarded("layout guard start", () => layoutGuard.onStart());
	RunService.Heartbeat.Connect((dt) => {
		guarded("diagnostics", () => {
			diagnosticElapsed += dt;
			if (diagnosticElapsed < DIAGNOSTIC_INTERVAL_SECONDS) {
				return;
			}
			diagnosticElapsed = 0;
			const root = registry.primary();
			const info = currentAntilagInfo();
			setAttribute(root, "AstralAntilagTier", info.tier);
			setAttribute(root, "AstralAntilagQuality", math.floor(info.quality * 100) / 100);
			setAttribute(root, "AstralFps", math.floor(info.fps));
			setAttribute(root, "AstralHitchScore", math.floor(info.hitchScore * 100) / 100);
		});
		guarded("layout guard tick", () => layoutGuard.onTick(dt));
	});
	RunService.RenderStepped.Connect((dt) => {
		renderElapsed += dt;
		renderFrames += 1;
		if (renderElapsed >= 0.5) {
			setAttribute(registry.primary(), "AstralRenderFps", math.floor(renderFrames / math.max(renderElapsed, 0.001)));
			renderElapsed = 0;
			renderFrames = 0;
		}
	});
	RunService.Stepped.Connect((_time, dt) => {
		physicsElapsed += dt;
		physicsFrames += 1;
		if (physicsElapsed >= 0.5) {
			setAttribute(registry.primary(), "AstralStepMs", math.floor((physicsElapsed / math.max(physicsFrames, 1)) * 1000));
			physicsElapsed = 0;
			physicsFrames = 0;
		}
	});
}

function initializeClientFramework(root: Instance) {
	root.SetAttribute("AstralFrameworkBoot", "loading");
	if (!CollectionService.HasTag(root, UI_ROOT_TAG)) {
		CollectionService.AddTag(root, UI_ROOT_TAG);
	}
	const [ok, reason] = pcall(() => {
		attachRoot(root);
		registry.add(root);
		if (!started) {
			start();
		}
	});
	if (!ok) {
		ClientLog.warn("framework", `ui shell didn't start: ${tostring(reason)}`);
		root.SetAttribute("AstralFrameworkBoot", "error");
		return;
	}
	ClientLog.once("framework-ready", "framework", `${root.Name} ready`);
	root.SetAttribute("AstralFrameworkBoot", "ready");
}

export = {
	initializeClientFramework,
	UI_ROOT_TAG,
};
