// Flamework wiring for the UI shell. The flamework transformer is not part of this build, so the
// metadata it would emit (identifiers, parameters, implements, decorators) is written out by hand.
import { importTsModule } from "./vendor";
import { currentAntilagInfo } from "./MotionKit/antilag";
import { getActiveClientStore } from "./CoreKit/clientStore";
import { ClientLog } from "./CoreKit/log";
import "./layoutGuard";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const CollectionService = game.GetService("CollectionService");

type AttributeSetter = (this: void, self: unknown, name: string, value: unknown) => void;
interface Reflect {
	defineMetadata(this: void, target: object, key: string, value: unknown): void;
	decorate(this: void, target: object, id: string, decorator: unknown, args: unknown[]): void;
}
interface BaseComponentShape {
	instance: Instance;
}
type BaseComponentCtor = new (...args: unknown[]) => BaseComponentShape;
interface ComponentHandle {
	instance: Instance;
}
interface Components {
	onComponentAdded(callback: (component: ComponentHandle, root: Instance) => unknown, id: string): RBXScriptConnection;
	getAllComponents(id: string): ComponentHandle[];
}
interface TypeChecks {
	string: unknown;
	boolean: unknown;
	number: unknown;
	instanceIsA(this: void, className: string): unknown;
}
interface StoreState {
	navigation: { page: unknown };
	session?: { SnapshotId?: unknown };
}

const flamework = ReplicatedStorage.WaitForChild("rbxts_include").WaitForChild("node_modules").WaitForChild("@flamework");
const flameworkCore = flamework.WaitForChild("core").WaitForChild("out");
const flameworkComponents = flamework.WaitForChild("components").WaitForChild("out");
const _core = importTsModule<{
	Reflect: Reflect;
	Controller: unknown;
	Flamework: { ignite(this: void): void; resolveDependency(this: void, id: string): unknown };
}>(flameworkCore);
const _components = importTsModule<{ BaseComponent: BaseComponentCtor; Component: unknown }>(flameworkComponents);
const t = importTsModule<{ t: TypeChecks }>(flameworkCore.WaitForChild("prelude")).t;
const SYMBOL_ATTRIBUTE_SETTER = importTsModule<{ SYMBOL_ATTRIBUTE_SETTER: string }>(
	flameworkComponents.WaitForChild("baseComponent"),
).SYMBOL_ATTRIBUTE_SETTER;
const Reflect = _core.Reflect;
const BaseComponent = _components.BaseComponent;
const Component = _components.Component;
const Controller = _core.Controller;
const Flamework = _core.Flamework;

function setAttribute(target: object, name: string, value: unknown) {
	const setter = (target as unknown as Record<string, AttributeSetter>)[SYMBOL_ATTRIBUTE_SETTER];
	setter(target, name, value);
}

const UI_ROOT_TAG = "AstralForgeUiRoot";

class UiRootComponent extends BaseComponent {
	stateConnection?: { disconnect(): void };

	constructor(...args: unknown[]) {
		super(...args);
	}

	onStart() {
		const [ok, reason] = pcall(() => {
			const instance = this.instance as ScreenGui;
			instance.ResetOnSpawn = false;
			instance.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
			setAttribute(this, "AstralFramework", "1");
			setAttribute(this, "AstralFrameworkReady", true);
			const store = getActiveClientStore() as
				| {
						getState(): StoreState;
						changed: { connect(callback: (state: StoreState) => void): { disconnect(): void } };
				  }
				| undefined;
			if (store === undefined) {
				setAttribute(this, "AstralStateStatus", "store unavailable");
				return undefined;
			}
			const syncDebugState = (state: StoreState) => {
				setAttribute(this, "AstralRoute", state.navigation.page);
				setAttribute(this, "AstralSnapshot", state.session?.SnapshotId ?? -1);
				setAttribute(this, "AstralStateStatus", state.session === undefined ? "waiting for profile" : "live");
			};
			syncDebugState(store.getState());
			if (this.stateConnection !== undefined) {
				pcall(() => {
					this.stateConnection!.disconnect();
				});
				this.stateConnection = undefined;
			}
			const connection = store.changed.connect(syncDebugState);
			this.stateConnection = connection;
			const [bound, bindReason] = pcall(() => {
				this.instance.Destroying.Once(() => {
					pcall(() => {
						connection.disconnect();
					});
					this.stateConnection = undefined;
				});
			});
			if (!bound) {
				pcall(() => {
					connection.disconnect();
				});
				this.stateConnection = undefined;
				error(bindReason, 0);
			}
		});
		if (!ok) {
			ClientLog.warn("framework", `UiRootComponent onStart failed: ${tostring(reason)}`);
		}
	}
}
Reflect.defineMetadata(UiRootComponent, "identifier", "client/framework/init@UiRootComponent");
Reflect.defineMetadata(UiRootComponent, "flamework:implements", ["$:flamework@OnStart"]);
Reflect.decorate(UiRootComponent, "$c:components@Component", Component, [
	{
		tag: UI_ROOT_TAG,
		warningTimeout: 0,
		defaults: {
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
		},
		attributes: {
			AstralFramework: t.string,
			AstralFrameworkReady: t.boolean,
			AstralRoute: t.string,
			AstralSnapshot: t.number,
			AstralStateStatus: t.string,
			AstralAntilagTier: t.number,
			AstralAntilagQuality: t.number,
			AstralFps: t.number,
			AstralHitchScore: t.number,
			AstralRenderFps: t.number,
			AstralStepMs: t.number,
		},
		instanceGuard: t.instanceIsA("ScreenGui"),
	},
]);

class UiRuntimeController {
	announced = new Set<Instance>();
	primaryRoot?: ComponentHandle;
	ready = false;
	addedConnection?: RBXScriptConnection;

	constructor(private components: Components) {}

	onInit() {
		const [ok, reason] = pcall(() => {
			this.ready = false;
		});
		if (!ok) {
			ClientLog.warn("framework", `UiRuntimeController onInit failed: ${tostring(reason)}`);
		}
	}

	primary() {
		return this.primaryRoot;
	}

	onStart() {
		const [ok, reason] = pcall(() => {
			this.ready = true;
			if (this.addedConnection !== undefined) {
				pcall(() => {
					this.addedConnection!.Disconnect();
				});
				this.addedConnection = undefined;
			}
			const announced = this.announced;
			const announce = (root: Instance) => {
				if (announced.has(root)) {
					return undefined;
				}
				announced.add(root);
				root.Destroying.Once(() => announced.delete(root));
				ClientLog.once("framework-ready", "framework", `${root.Name} ready`);
			};
			this.addedConnection = this.components.onComponentAdded((component, root) => {
				const [addedOk, addedReason] = pcall(() => {
					if (this.primaryRoot === undefined) {
						this.primaryRoot = component;
					}
					return announce(root);
				});
				if (!addedOk) {
					ClientLog.warn("framework", `UiRuntimeController component add failed: ${tostring(addedReason)}`);
				}
			}, "client/framework/init@UiRootComponent");
			for (const component of this.components.getAllComponents("client/framework/init@UiRootComponent")) {
				if (this.primaryRoot === undefined) {
					this.primaryRoot = component;
				}
				announce(component.instance);
			}
		});
		if (!ok) {
			ClientLog.warn("framework", `UiRuntimeController onStart failed: ${tostring(reason)}`);
		}
	}
}
Reflect.defineMetadata(UiRuntimeController, "identifier", "client/framework/init@UiRuntimeController");
Reflect.defineMetadata(UiRuntimeController, "flamework:parameters", ["$c:components@Components"]);
Reflect.defineMetadata(UiRuntimeController, "flamework:implements", ["$:flamework@OnInit", "$:flamework@OnStart"]);
Reflect.decorate(UiRuntimeController, "$:flamework@Controller", Controller, [{ loadOrder: -100 }]);

const DIAGNOSTIC_INTERVAL_SECONDS = 1;

class DiagnosticsController {
	elapsed = 0;
	booted = false;
	addedConnection?: RBXScriptConnection;
	target?: ComponentHandle;

	constructor(
		private components: Components,
		private runtime: UiRuntimeController | undefined,
	) {}

	onInit() {
		const [ok, reason] = pcall(() => {
			this.booted = true;
		});
		if (!ok) {
			ClientLog.warn("framework", `DiagnosticsController onInit failed: ${tostring(reason)}`);
		}
	}

	onStart() {
		const [ok, reason] = pcall(() => {
			if (this.addedConnection !== undefined) {
				pcall(() => {
					this.addedConnection!.Disconnect();
				});
				this.addedConnection = undefined;
			}
			this.addedConnection = this.components.onComponentAdded((component) => {
				this.target = component;
				return this.target;
			}, "client/framework/init@UiRootComponent");
			const existing = this.components.getAllComponents("client/framework/init@UiRootComponent")[0];
			if (existing !== undefined) {
				this.target = existing;
			}
		});
		if (!ok) {
			ClientLog.warn("framework", `DiagnosticsController onStart failed: ${tostring(reason)}`);
		}
	}

	onTick(dt: number) {
		const [ok, reason] = pcall(() => {
			this.elapsed += dt;
			if (this.elapsed < DIAGNOSTIC_INTERVAL_SECONDS) {
				return undefined;
			}
			this.elapsed = 0;
			let target = this.target;
			if ((target === undefined || target.instance.Parent === undefined) && this.runtime !== undefined) {
				target = this.runtime.primary();
				this.target = target;
			}
			if (target === undefined || target.instance.Parent === undefined) {
				return undefined;
			}
			const info = currentAntilagInfo();
			setAttribute(target, "AstralAntilagTier", info.tier);
			setAttribute(target, "AstralAntilagQuality", math.floor(info.quality * 100) / 100);
			setAttribute(target, "AstralFps", math.floor(info.fps));
			setAttribute(target, "AstralHitchScore", math.floor(info.hitchScore * 100) / 100);
		});
		if (!ok) {
			ClientLog.warnEvery("diagnostics-tick", 15, "framework", `DiagnosticsController onTick failed: ${tostring(reason)}`);
		}
	}
}
Reflect.defineMetadata(DiagnosticsController, "identifier", "client/framework/init@DiagnosticsController");
Reflect.defineMetadata(DiagnosticsController, "flamework:parameters", [
	"$c:components@Components",
	"client/framework/init@UiRuntimeController",
]);
Reflect.defineMetadata(DiagnosticsController, "flamework:implements", [
	"$:flamework@OnInit",
	"$:flamework@OnStart",
	"$:flamework@OnTick",
]);
Reflect.decorate(DiagnosticsController, "$:flamework@Controller", Controller, [{ loadOrder: 10 }]);

class ShellClockController {
	renderElapsed = 0;
	renderFrames = 0;
	physicsElapsed = 0;
	physicsFrames = 0;

	constructor(private runtime: UiRuntimeController) {}

	onInit() {
		const [ok, reason] = pcall(() => {
			this.renderElapsed = 0;
			this.physicsElapsed = 0;
		});
		if (!ok) {
			ClientLog.warn("framework", `ShellClockController onInit failed: ${tostring(reason)}`);
		}
	}

	publish(name: string, value: unknown) {
		const root = this.runtime.primary();
		if (root === undefined || root.instance.Parent === undefined) {
			return undefined;
		}
		setAttribute(root, name, value);
	}

	onRender(dt: number) {
		const [ok, reason] = pcall(() => {
			this.renderElapsed += dt;
			this.renderFrames += 1;
			if (this.renderElapsed < 0.5) {
				return undefined;
			}
			const fps = math.floor(this.renderFrames / math.max(this.renderElapsed, 0.001));
			this.renderElapsed = 0;
			this.renderFrames = 0;
			this.publish("AstralRenderFps", fps);
		});
		if (!ok) {
			ClientLog.warnEvery("shell-render", 15, "framework", `ShellClockController onRender failed: ${tostring(reason)}`);
		}
	}

	onPhysics(dt: number) {
		const [ok, reason] = pcall(() => {
			this.physicsElapsed += dt;
			this.physicsFrames += 1;
			if (this.physicsElapsed < 0.5) {
				return undefined;
			}
			const ms = math.floor((this.physicsElapsed / math.max(this.physicsFrames, 1)) * 1000);
			this.physicsElapsed = 0;
			this.physicsFrames = 0;
			this.publish("AstralStepMs", ms);
		});
		if (!ok) {
			ClientLog.warnEvery("shell-physics", 15, "framework", `ShellClockController onPhysics failed: ${tostring(reason)}`);
		}
	}
}
Reflect.defineMetadata(ShellClockController, "identifier", "client/framework/init@ShellClockController");
Reflect.defineMetadata(ShellClockController, "flamework:parameters", ["client/framework/init@UiRuntimeController"]);
Reflect.defineMetadata(ShellClockController, "flamework:implements", [
	"$:flamework@OnInit",
	"$:flamework@OnRender",
	"$:flamework@OnPhysics",
]);
Reflect.decorate(ShellClockController, "$:flamework@Controller", Controller, [{ loadOrder: 20 }]);

let initialized = false;
let igniteFailed = false;

function initializeClientFramework(root: Instance) {
	root.SetAttribute("AstralFrameworkBoot", "loading");
	if (!CollectionService.HasTag(root, UI_ROOT_TAG)) {
		CollectionService.AddTag(root, UI_ROOT_TAG);
	}
	if (!initialized) {
		initialized = true;
		const [ok, reason] = pcall(() => {
			Flamework.ignite();
			Flamework.resolveDependency("client/framework/init@UiRuntimeController");
			Flamework.resolveDependency("client/framework/init@ShellClockController");
		});
		if (!ok) {
			igniteFailed = true;
			ClientLog.warn("framework", `framework didn't start: ${tostring(reason)}`);
			root.SetAttribute("AstralFrameworkBoot", "error");
			return undefined;
		}
	}
	if (igniteFailed) {
		root.SetAttribute("AstralFrameworkBoot", "error");
		return undefined;
	}
	root.SetAttribute("AstralFrameworkBoot", "ready");
}

export = {
	initializeClientFramework,
	UI_ROOT_TAG,
	UiRootComponent,
	UiRuntimeController,
	DiagnosticsController,
	ShellClockController,
};
