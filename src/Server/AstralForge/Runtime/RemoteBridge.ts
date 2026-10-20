// Owns the wire folder the client binds to (request/state/toast/effect/shutdown remotes),
// the boot-failure attributes and the ordered shutdown list. Remote names and payloads are
// unchanged so existing clients keep working.
import { OnInit, Service } from "@flamework/core";
import ModuleLog = require("../ModuleLog");
import { Registry } from "./ServerRegistry";

const ReplicatedStorage = game.GetService("ReplicatedStorage");
const Workspace = game.GetService("Workspace");

interface ProtocolShape {
	FolderName: string;
	RequestName: string;
	StateName: string;
	ToastName: string;
	EffectName: string;
	ShutdownName: string;
}
interface GameConfigShape {
	Game: { DataVersion: unknown; Version: string; AutosaveSeconds: unknown };
}
interface SharedDataShape {
	ValidateMonetizationIds(this: void): Record<string, string[]>;
}

function requiredChild(parent: Instance, name: string, className: keyof Instances, timeout: number): Instance {
	const child = parent.WaitForChild(name, timeout) as Instance | undefined;
	if (child === undefined) {
		error(string.format("[AF/boot] %s did not appear under %s within %.0fs", name, parent.GetFullName(), timeout), 0);
	}
	if (!child.IsA(className)) {
		const got = child as Instance;
		error(string.format("[AF/boot] %s must be %s, got %s", got.GetFullName(), className, got.ClassName), 0);
	}
	return child;
}

function makeRemote(className: "RemoteEvent" | "RemoteFunction", name: string, parent: Folder): Instance {
	const remote = new Instance(className);
	remote.Name = name;
	remote.Archivable = false;
	remote.Parent = parent;
	return remote;
}

@Service({ loadOrder: 0 })
export class RemoteBridge implements OnInit {
	public gameConfig!: GameConfigShape;
	public folder!: Folder;
	public request!: RemoteFunction;
	public state!: RemoteEvent;
	public toast!: RemoteEvent;
	public effect!: RemoteEvent;
	public shutdown!: RemoteEvent;

	private shutdownRevision = 0;
	private startFailure?: string;
	private closers: [number, string, () => void][] = [];
	private closed = false;

	onInit() {
		ModuleLog.AttachTelemetry(Registry.ServerTelemetry);
		const astralRoot = requiredChild(ReplicatedStorage, "AstralForge", "Folder", 30) as Folder;
		const sharedRoot = requiredChild(astralRoot, "Shared", "Folder", 15) as Folder;
		const protocol = ModuleLog.Require(
			requiredChild(sharedRoot, "Protocol", "ModuleScript", 15) as ModuleScript,
			"shared protocol",
		) as ProtocolShape;
		this.gameConfig = ModuleLog.Require(
			requiredChild(sharedRoot, "GameConfig", "ModuleScript", 15) as ModuleScript,
			"game settings",
		) as GameConfigShape;
		const sharedData = ModuleLog.Require(
			requiredChild(sharedRoot, "SharedData", "ModuleScript", 15) as ModuleScript,
			"shared data",
		) as SharedDataShape;

		// Release guard: report every placeholder without interrupting server startup.
		const missingIdLines: string[] = [];
		for (const [category, keys] of pairs(sharedData.ValidateMonetizationIds())) {
			for (const [, key] of pairs(keys)) {
				missingIdLines.push(`${category}.${key}`);
			}
		}
		if (missingIdLines.size() > 0) {
			table.sort(missingIdLines);
			warn("[ASTRAL FORGE / RELEASE BLOCKER] Missing monetization IDs: " + missingIdLines.join(", "));
		}

		ReplicatedStorage.FindFirstChild(protocol.FolderName)?.Destroy();
		const folder = new Instance("Folder");
		folder.Name = protocol.FolderName;
		folder.Archivable = false;
		folder.SetAttribute("WireVersion", this.gameConfig.Game.DataVersion as AttributeValue);
		folder.SetAttribute("GameVersion", this.gameConfig.Game.Version);
		folder.SetAttribute("PlaceVersion", game.PlaceVersion);
		folder.SetAttribute("Ready", false);
		folder.SetAttribute("BootJob", game.JobId);
		folder.Parent = ReplicatedStorage;
		this.folder = folder;

		this.request = makeRemote("RemoteFunction", protocol.RequestName, folder) as RemoteFunction;
		this.state = makeRemote("RemoteEvent", protocol.StateName, folder) as RemoteEvent;
		this.toast = makeRemote("RemoteEvent", protocol.ToastName, folder) as RemoteEvent;
		this.effect = makeRemote("RemoteEvent", protocol.EffectName, folder) as RemoteEvent;
		this.shutdown = makeRemote("RemoteEvent", protocol.ShutdownName, folder) as RemoteEvent;
		this.request.OnServerInvoke = () => {
			return { ok: false, error: "The server is still starting. Please retry in a moment." };
		};
	}

	/** Runs a boot step; a failure is stamped on the wire folder and rethrown. */
	bootStep<T>(label: string, callback: () => T): T {
		const start = os.clock();
		const [ok, result] = xpcall(callback, (err: unknown) => debug.traceback(tostring(err)));
		if (!ok) {
			const problem = string.format("%s | %s", label, tostring(result));
			this.folder.SetAttribute("BootFailureStage", label);
			this.folder.SetAttribute("BootFailure", string.sub(problem, 1, 1000));
			error(result, 0);
		}
		ModuleLog.Info("BOOT", label, { ElapsedMs: math.floor((os.clock() - start) * 1000) });
		return result as T;
	}

	/** Start-phase step: a failure is recorded so the lifecycle service refuses to go Ready. */
	startStep(label: string, callback: () => void) {
		if (this.startFailure !== undefined) {
			return;
		}
		const [ok, problem] = pcall(() => this.bootStep(label, callback));
		if (!ok) {
			this.startFailure = tostring(problem);
		}
	}

	getStartFailure() {
		return this.startFailure;
	}

	/** Register a teardown; lower order closes first. */
	onClose(order: number, label: string, callback: () => void) {
		this.closers.push([order, label, callback]);
	}

	closeRuntime() {
		if (this.closed) {
			return;
		}
		this.closed = true;
		const ordered = [...this.closers];
		ordered.sort((a, b) => a[0] < b[0]);
		for (const [, label, callback] of ordered) {
			const [ok, problem] = xpcall(callback, (err: unknown) => debug.traceback(tostring(err)));
			if (!ok) {
				ModuleLog.Warn("Shutdown", string.format("%s failed - %s", label, tostring(problem)));
			}
		}
	}

	publishShutdown(phase: string, message: string) {
		this.shutdownRevision += 1;
		const startedAt = Workspace.GetServerTimeNow();
		this.folder.SetAttribute("ShutdownPhase", phase);
		this.folder.SetAttribute("ShutdownMessage", message);
		this.folder.SetAttribute("ShutdownStartedAt", startedAt);
		this.folder.SetAttribute("ShutdownRevision", this.shutdownRevision);
		this.folder.SetAttribute("ShuttingDown", true);
		this.shutdown.FireAllClients({
			Phase: phase,
			Message: message,
			StartedAt: startedAt,
			Revision: this.shutdownRevision,
		});
	}
}
