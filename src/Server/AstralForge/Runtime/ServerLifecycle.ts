// Last service to start: goes Ready, prints the security posture, wires Studio hooks and the
// soft-shutdown flow. If any start step failed the runtime is closed and the boot fails loudly.
import { T } from "../../../Shared/AstralForge/Shared/Locale";
import { OnStart, Service } from "@flamework/core";
import ModuleLog = require("../ModuleLog");
import { GameService } from "../Services/GameService";
import { DataService } from "../Services/DataService";
import { flushBeforeTeleport } from "./TeleportFlush";
import { RemoteBridge } from "./RemoteBridge";

const Players = game.GetService("Players");
const RunService = game.GetService("RunService");
const TeleportService = game.GetService("TeleportService");
const Workspace = game.GetService("Workspace");

// Runtime folder -> AstralForge server script (holds ServerConfig, PropKitLoader, ...).
const serverRoot = script.Parent!.Parent!;

function findPlayer(username: string): Player | undefined {
	const requested = string.lower(username);
	for (const player of Players.GetPlayers()) {
		if (string.lower(player.Name) === requested) {
			return player;
		}
	}
	return undefined;
}

function makeBindable(name: string, handler: (...args: unknown[]) => unknown): BindableFunction {
	const bindable = new Instance("BindableFunction");
	bindable.Name = name;
	bindable.OnInvoke = handler;
	bindable.Parent = serverRoot;
	return bindable;
}

@Service({ loadOrder: 10 })
export class ServerLifecycle implements OnStart {
	constructor(
		private readonly bridge: RemoteBridge,
		private readonly gameplay: GameService,
		private readonly data: DataService,
	) {}

	onStart() {
		const bridge = this.bridge;
		// OnStart runs each service on its own thread; wait for all of them, yielding or not.
		const failure = bridge.awaitStarts();
		if (failure !== undefined) {
			bridge.folder.SetAttribute("BootFailure", failure);
			bridge.closeRuntime();
			error(failure, 0);
		}
		ModuleLog.Info("BOOT", "runtime started");
		bridge.folder.SetAttribute("Ready", true);
		bridge.folder.SetAttribute("ReadyAt", Workspace.GetServerTimeNow());

		this.auditStudioBypasses();
		task.spawn(() => {
			const loader = require(serverRoot.WaitForChild("PropKitLoader") as ModuleScript) as {
				load: (this: void) => void;
			};
			const [ok, problem] = pcall(loader.load);
			if (!ok) {
				ModuleLog.Warn("PropKit", "prop kit loader failed: " + tostring(problem));
			}
		});
		ModuleLog.Debug("world", "ui-only server");
		ModuleLog.Debug("game", "saves and state running");
		ModuleLog.Debug("security", "request checks on");

		if (RunService.IsStudio()) {
			this.studioHooks();
		}
		game.BindToClose(() => this.softShutdown());
		ModuleLog.Once("server-ready", "server", "Astral Forge " + bridge.gameConfig.Game.Version + " is up");
	}

	// Single startup banner listing every Studio bypass and whether enforcement is actually active.
	private auditStudioBypasses() {
		const ServerConfig = require(serverRoot.WaitForChild("ServerConfig") as ModuleScript) as {
			AllowStudioAdmins: unknown;
			AllowStudioMemoryFallback: unknown;
			AllowStudioFollowVerification: unknown;
			GameAntiCheat: { EnforcementEnabled: unknown };
		};
		const isStudio = RunService.IsStudio();
		ModuleLog.Warn("SECURITY", "Studio bypass settings", {
			IsStudio: isStudio,
			AllowStudioAdmins: ServerConfig.AllowStudioAdmins,
			AllowStudioMemoryFallback: ServerConfig.AllowStudioMemoryFallback,
			AllowStudioFollowVerification: ServerConfig.AllowStudioFollowVerification,
			FirewallStudioPassThrough: isStudio,
			AntiCheatObservationalOnly: ServerConfig.GameAntiCheat.EnforcementEnabled === false,
			EnforcementActive: !isStudio,
		});
	}

	private studioHooks() {
		const liveGame = this.gameplay;
		const snapshotHook = new Instance("BindableFunction");
		snapshotHook.Name = "AstralForgeStudioSnapshot";
		snapshotHook.OnInvoke = (player?: Player) => {
			const target = player ?? Players.GetPlayers()[0];
			return target !== undefined ? liveGame._snapshot(target) : undefined;
		};
		snapshotHook.Parent = game.GetService("ServerStorage");

		const ReleaseReadiness = ModuleLog.Require(
			serverRoot.FindFirstChild("ReleaseReadiness") as ModuleScript,
			"release tests",
		) as {
			RunSoak: (this: void, minutes: number) => unknown;
			RunQuick: (this: void) => unknown;
		};
		makeBindable("StudioReleaseAudit", (minutes) => {
			if (typeIs(minutes, "number") && minutes > 0) {
				return ReleaseReadiness.RunSoak(minutes);
			}
			return ReleaseReadiness.RunQuick();
		});
		makeBindable("StudioAdmin", (action, username, amount) => {
			if (action !== "GrantUnlimitedMoney" && action !== "ShowRelease" && action !== "GrantWheelSpins") {
				return { ok: false, message: T("ServerLifecycle.UnknownStudioAdminActionS", tostring(action)) };
			}
			if (!typeIs(username, "string") || username === "") {
				return { ok: false, message: T("ServerLifecycle.ProvideTheUsernameOfA") };
			}
			const target = findPlayer(username);
			if (target === undefined) {
				return { ok: false, message: username + " is not in this test server." };
			}
			if (action === "ShowRelease") {
				const [ok, message] = liveGame.ShowRelease(target);
				return { ok: ok, message: message };
			}
			if (action === "GrantWheelSpins") {
				const [ok, message, total] = liveGame.GrantStudioWheelSpins(target, amount);
				return { ok: ok, message: message, amount: total };
			}
			const [ok, message, cash] = liveGame.GrantStudioMoney(target);
			return { ok: ok, message: message, amount: cash };
		});
		makeBindable("StudioSoftShutdown", () => {
			this.bridge.publishShutdown("Saving", T("Shutdown.StudioSaving"));
			return true;
		});
	}

	private softShutdown() {
		const bridge = this.bridge;
		const production = !RunService.IsStudio();
		bridge.publishShutdown(
			"Saving",
			production
				? T("Shutdown.Saving")
				: T("Shutdown.StudioSaving"),
		);
		bridge.closeRuntime();
		if (!production) {
			return;
		}
		// only teleport players whose save session this server has released (see TeleportFlush)
		const flushed = flushBeforeTeleport(Players.GetPlayers(), {
			held: (player) => this.data.Get(player) !== undefined,
			release: (player) => this.data.Save(player, true),
		});
		if (flushed.held.size() > 0) {
			ModuleLog.Warn("Shutdown", string.format("%d player(s) kept here until their save is released", flushed.held.size()));
		}
		const remainingPlayers = flushed.ready;
		if (remainingPlayers.size() === 0) {
			return;
		}
		bridge.publishShutdown("Teleporting", T("Shutdown.Teleporting"));
		task.wait(0.2);
		const options = new Instance("TeleportOptions");
		options.SetTeleportData({
			SoftShutdown: true,
			FromJob: game.JobId,
			Version: bridge.gameConfig.Game.Version,
		});
		const [ok, issue] = pcall(() => {
			TeleportService.TeleportAsync(game.PlaceId, remainingPlayers, options);
		});
		options.Destroy();
		if (!ok) {
			bridge.publishShutdown("Waiting", T("Shutdown.Waiting"));
			ModuleLog.Warn("Shutdown", "group teleport failed, leaving players to Roblox: " + tostring(issue));
		}
	}
}
