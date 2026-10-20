// UI shell: tags the root ScreenGui, mirrors store and performance numbers onto it as
// attributes (for Studio debugging). Driven by Flamework's OnTick/OnRender/OnPhysics.
import { Controller, OnPhysics, OnRender, OnTick } from "@flamework/core";
import { currentAntilagInfo } from "../MotionKit/antilag";
import { getActiveClientStore } from "../CoreKit/clientStore";
import { ClientLog } from "../CoreKit/log";
import { UiRootHandle, UiRootRegistry } from "./UiRootRegistry";

const CollectionService = game.GetService("CollectionService");

export const UI_ROOT_TAG = "AstralForgeUiRoot";
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

@Controller({ loadOrder: 1 })
export class UiShellController implements OnTick, OnRender, OnPhysics {
	private diagnosticElapsed = 0;
	private renderElapsed = 0;
	private renderFrames = 0;
	private physicsElapsed = 0;
	private physicsFrames = 0;

	constructor(private readonly registry: UiRootRegistry) {}

	/** Registers the game's root ScreenGui with the shell (and so with the layout guard). */
	attach(root: Instance) {
		root.SetAttribute("AstralFrameworkBoot", "loading");
		if (!CollectionService.HasTag(root, UI_ROOT_TAG)) {
			CollectionService.AddTag(root, UI_ROOT_TAG);
		}
		const [ok, reason] = pcall(() => {
			attachRoot(root);
			this.registry.add(root);
		});
		if (!ok) {
			ClientLog.warn("framework", `ui shell didn't start: ${tostring(reason)}`);
			root.SetAttribute("AstralFrameworkBoot", "error");
			return;
		}
		ClientLog.once("framework-ready", "framework", `${root.Name} ready`);
		root.SetAttribute("AstralFrameworkBoot", "ready");
	}

	onTick(dt: number) {
		this.diagnosticElapsed += dt;
		if (this.diagnosticElapsed < DIAGNOSTIC_INTERVAL_SECONDS) {
			return;
		}
		this.diagnosticElapsed = 0;
		const [ok, reason] = pcall(() => {
			const root = this.registry.primary();
			const info = currentAntilagInfo();
			setAttribute(root, "AstralAntilagTier", info.tier);
			setAttribute(root, "AstralAntilagQuality", math.floor(info.quality * 100) / 100);
			setAttribute(root, "AstralFps", math.floor(info.fps));
			setAttribute(root, "AstralHitchScore", math.floor(info.hitchScore * 100) / 100);
		});
		if (!ok) {
			ClientLog.warnEvery("framework-diagnostics", 15, "framework", `diagnostics failed: ${tostring(reason)}`);
		}
	}

	onRender(dt: number) {
		this.renderElapsed += dt;
		this.renderFrames += 1;
		if (this.renderElapsed >= 0.5) {
			setAttribute(
				this.registry.primary(),
				"AstralRenderFps",
				math.floor(this.renderFrames / math.max(this.renderElapsed, 0.001)),
			);
			this.renderElapsed = 0;
			this.renderFrames = 0;
		}
	}

	onPhysics(dt: number) {
		this.physicsElapsed += dt;
		this.physicsFrames += 1;
		if (this.physicsElapsed >= 0.5) {
			setAttribute(
				this.registry.primary(),
				"AstralStepMs",
				math.floor((this.physicsElapsed / math.max(this.physicsFrames, 1)) * 1000),
			);
			this.physicsElapsed = 0;
			this.physicsFrames = 0;
		}
	}
}
