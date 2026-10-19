import ModuleLog = require("./ModuleLog");

const Players = game.GetService("Players");
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const RunService = game.GetService("RunService");
const TeleportService = game.GetService("TeleportService");
const TextChatService = game.GetService("TextChatService");
const Workspace = game.GetService("Workspace");

// Services stay Luau-shaped tables; only the members this boot script touches are typed.
interface GameServiceLike {
	_effect: RemoteEvent;
	_toastPlayer(player: Player, title: unknown, body: unknown, kind: unknown): void;
	_snapshot(player: Player): unknown;
	Start(): void;
	Shutdown(): void;
	ShowRelease(player: Player): LuaTuple<[boolean, unknown]>;
	GrantStudioWheelSpins(player: Player, amount: unknown): LuaTuple<[boolean, unknown, unknown]>;
	GrantStudioMoney(player: Player): LuaTuple<[boolean, unknown, unknown]>;
}
interface Startable {
	Start(): void;
	Destroy(): void;
}
interface DataServiceLike {
	Shutdown(): void;
	StartAutosave(seconds: unknown): void;
}
interface ServicesShape {
	ServerTelemetry: Parameters<typeof ModuleLog.AttachTelemetry>[0];
	DataService: { new: (this: void) => DataServiceLike };
	AdminService: { new: (this: void, dataService: DataServiceLike) => unknown };
	GameService: {
		new: (
			this: void,
			dataService: DataServiceLike,
			worldService: unknown,
			fluxSurgeService: unknown,
			remotes: Record<string, unknown>,
		) => GameServiceLike;
	};
	WorldService: { new: (this: void) => Startable };
	FluxSurgeService: {
		new: (
			this: void,
			toast: (player: Player, title: unknown, body: unknown, kind: unknown) => void,
			effect: (player: Player, payload: unknown) => void,
		) => unknown;
	};
	Security: { new: (this: void) => Startable };
	CharacterIntegrity: { new: (this: void) => Startable };
}

const Services = require(
	script.WaitForChild("Services").WaitForChild("ServerServices") as ModuleScript,
) as ServicesShape;
ModuleLog.AttachTelemetry(Services.ServerTelemetry);

Players.CharacterAutoLoads = false;

pcall(() => {
	(TextChatService as unknown as { ChatVersion: Enum.ChatVersion }).ChatVersion = Enum.ChatVersion.TextChatService;
});
pcall(() => {
	(TextChatService as unknown as { CreateDefaultTextChannels: boolean }).CreateDefaultTextChannels = true;
});

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

const astralRoot = requiredChild(ReplicatedStorage, "AstralForge", "Folder", 30) as Folder;
const sharedRoot = requiredChild(astralRoot, "Shared", "Folder", 15) as Folder;
const Protocol = ModuleLog.Require(
	requiredChild(sharedRoot, "Protocol", "ModuleScript", 15) as ModuleScript,
	"shared protocol",
) as ProtocolShape;
const GameConfig = ModuleLog.Require(
	requiredChild(sharedRoot, "GameConfig", "ModuleScript", 15) as ModuleScript,
	"game settings",
) as GameConfigShape;
const SharedData = ModuleLog.Require(
	requiredChild(sharedRoot, "SharedData", "ModuleScript", 15) as ModuleScript,
	"shared data",
) as SharedDataShape;

// Release guard: report every placeholder without interrupting server startup.
const missingMonetization = SharedData.ValidateMonetizationIds();
const missingIdLines: string[] = [];
for (const [category, keys] of pairs(missingMonetization)) {
	for (const [, key] of pairs(keys)) {
		missingIdLines.push(`${category}.${key}`);
	}
}
if (missingIdLines.size() > 0) {
	table.sort(missingIdLines);
	warn("[ASTRAL FORGE / RELEASE BLOCKER] Missing monetization IDs: " + missingIdLines.join(", "));
}

const priorBridge = ReplicatedStorage.FindFirstChild(Protocol.FolderName);
if (priorBridge !== undefined) {
	priorBridge.Destroy();
}

const remoteFolder = new Instance("Folder");
remoteFolder.Name = Protocol.FolderName;
remoteFolder.Archivable = false;
remoteFolder.SetAttribute("WireVersion", GameConfig.Game.DataVersion as AttributeValue);
remoteFolder.SetAttribute("GameVersion", GameConfig.Game.Version);
remoteFolder.SetAttribute("PlaceVersion", game.PlaceVersion);
remoteFolder.SetAttribute("Ready", false);
remoteFolder.SetAttribute("BootJob", game.JobId);
remoteFolder.Parent = ReplicatedStorage;

const request = makeRemote("RemoteFunction", Protocol.RequestName, remoteFolder) as RemoteFunction;
const state = makeRemote("RemoteEvent", Protocol.StateName, remoteFolder) as RemoteEvent;
const toast = makeRemote("RemoteEvent", Protocol.ToastName, remoteFolder) as RemoteEvent;
const effect = makeRemote("RemoteEvent", Protocol.EffectName, remoteFolder) as RemoteEvent;
const shutdown = makeRemote("RemoteEvent", Protocol.ShutdownName, remoteFolder) as RemoteEvent;

let shutdownRevision = 0;
function publishShutdown(phase: string, message: string) {
	shutdownRevision += 1;
	const startedAt = Workspace.GetServerTimeNow();
	remoteFolder.SetAttribute("ShutdownPhase", phase);
	remoteFolder.SetAttribute("ShutdownMessage", message);
	remoteFolder.SetAttribute("ShutdownStartedAt", startedAt);
	remoteFolder.SetAttribute("ShutdownRevision", shutdownRevision);
	remoteFolder.SetAttribute("ShuttingDown", true);
	shutdown.FireAllClients({
		Phase: phase,
		Message: message,
		StartedAt: startedAt,
		Revision: shutdownRevision,
	});
}

request.OnServerInvoke = () => {
	return { ok: false, error: "The server is still starting. Please retry in a moment." };
};

function bootStep<T>(label: string, callback: () => T): T {
	const [ok, result] = xpcall(callback, (err: unknown) => debug.traceback(tostring(err)));
	if (ok) {
		return result as T;
	}
	const problem = string.format("%s | %s", label, tostring(result));
	remoteFolder.SetAttribute("BootFailureStage", label);
	remoteFolder.SetAttribute("BootFailure", string.sub(problem, 1, 1000));
	error(result, 0);
}

function timedRequire<T>(label: string, loader: () => T): T {
	const start = os.clock();
	const result = bootStep(label, loader);
	ModuleLog.Info("BOOT", string.format("%s loaded", label), { ElapsedMs: math.floor((os.clock() - start) * 1000) });
	return result;
}

function timedBuild<T>(label: string, builder: () => T): T {
	const start = os.clock();
	const result = bootStep(label, builder);
	ModuleLog.Info("BOOT", string.format("%s complete", label), { ElapsedMs: math.floor((os.clock() - start) * 1000) });
	return result;
}

const DataService = timedRequire("player data module", () => Services.DataService);
const AdminService = timedRequire("administration module", () => Services.AdminService);
const GameService = timedRequire("gameplay module", () => Services.GameService);
const WorldService = timedRequire("world module", () => Services.WorldService);
const FluxSurgeService = timedRequire("flux surge module", () => Services.FluxSurgeService);
const Security = timedRequire("security module", () => Services.Security);
const CharacterIntegrity = timedRequire("integrity module", () => Services.CharacterIntegrity);

const dataService = timedBuild("player data construction", () => DataService.new());
const adminService = timedBuild("administration construction", () => AdminService.new(dataService));
const worldService = timedBuild("world construction", () => WorldService.new());
let gameService: GameServiceLike | undefined;
const fluxSurgeService = timedBuild("flux surge construction", () => {
	return FluxSurgeService.new(
		(player, title, body, kind) => {
			if (gameService) {
				gameService._toastPlayer(player, title, body, kind);
			}
		},
		(player, payload) => {
			if (gameService) {
				gameService._effect.FireClient(player, payload);
			}
		},
	);
});
const securityPipeline = timedBuild("security construction", () => Security.new());
const characterIntegrity = timedBuild("integrity construction", () => CharacterIntegrity.new());
gameService = timedBuild("gameplay construction", () =>
	GameService.new(dataService, worldService, fluxSurgeService, {
		Request: request,
		State: state,
		Toast: toast,
		Effect: effect,
		Security: securityPipeline,
		Admin: adminService,
	}),
);
const liveGame = gameService;

if (RunService.IsStudio()) {
	const snapshotHook = new Instance("BindableFunction");
	snapshotHook.Name = "AstralForgeStudioSnapshot";
	snapshotHook.OnInvoke = (player?: Player) => {
		const target = player ?? Players.GetPlayers()[0];
		return target !== undefined ? liveGame._snapshot(target) : undefined;
	};
	snapshotHook.Parent = game.GetService("ServerStorage");
}

let runtimeClosed = false;
function closeRuntime() {
	if (runtimeClosed) {
		return;
	}
	runtimeClosed = true;
	const operations: [string, () => void][] = [
		["character integrity", () => characterIntegrity.Destroy()],
		["security pipeline", () => securityPipeline.Destroy()],
		["game service", () => liveGame.Shutdown()],
		["data service", () => dataService.Shutdown()],
	];
	for (const operation of operations) {
		const [ok, problem] = xpcall(operation[1], (err: unknown) => debug.traceback(tostring(err)));
		if (!ok) {
			ModuleLog.Warn("Shutdown", string.format("%s failed - %s", operation[0], tostring(problem)));
		}
	}
}

function startRuntime() {
	const start = os.clock();
	const step = (label: string, fn: () => void) => {
		const t = os.clock();
		fn();
		ModuleLog.Info("BOOT", label, { ElapsedMs: math.floor((os.clock() - t) * 1000) });
	};
	step("security start", () => securityPipeline.Start());
	step("integrity start", () => characterIntegrity.Start());
	step("world start", () => worldService.Start());
	step("game start", () => liveGame.Start());
	step("autosave start", () => dataService.StartAutosave(GameConfig.Game.AutosaveSeconds));
	ModuleLog.Info("BOOT", "runtime started", { ElapsedMs: math.floor((os.clock() - start) * 1000) });
}

const [started, startProblem] = xpcall(startRuntime, (err: unknown) => debug.traceback(tostring(err)));
if (!started) {
	remoteFolder.SetAttribute("BootFailure", tostring(startProblem));
	closeRuntime();
	error(startProblem, 0);
}

remoteFolder.SetAttribute("Ready", true);
remoteFolder.SetAttribute("ReadyAt", Workspace.GetServerTimeNow());

// Single startup banner listing every Studio bypass and whether enforcement is actually active.
// Production behavior is unchanged; this only surfaces the current security posture.
{
	const ServerConfig = require(script.WaitForChild("ServerConfig") as ModuleScript) as {
		AllowStudioAdmins: unknown;
		AllowStudioMemoryFallback: unknown;
		AllowStudioFollowVerification: unknown;
		GameAntiCheat: { EnforcementEnabled: unknown };
	};
	const isStudio = RunService.IsStudio();
	ModuleLog.Warn("SECURITY", "Studio bypass audit", {
		IsStudio: isStudio,
		AllowStudioAdmins: ServerConfig.AllowStudioAdmins,
		AllowStudioMemoryFallback: ServerConfig.AllowStudioMemoryFallback,
		AllowStudioFollowVerification: ServerConfig.AllowStudioFollowVerification,
		FirewallStudioPassThrough: isStudio,
		AntiCheatObservationalOnly: ServerConfig.GameAntiCheat.EnforcementEnabled === false,
		EnforcementActive: !isStudio,
	});
}

task.spawn(() => {
	const [ok, problem] = pcall(
		(require(script.WaitForChild("PropKitLoader") as ModuleScript) as { load: (this: void) => void }).load,
	);
	if (!ok) {
		ModuleLog.Warn("PropKit", "kit loader failed - " + tostring(problem));
	}
});
ModuleLog.Debug("world", "ui-only server");
ModuleLog.Debug("game", "saves and state running");
ModuleLog.Debug("security", "request checks on");

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
	bindable.Parent = script;
	return bindable;
}

if (RunService.IsStudio()) {
	const ReleaseReadiness = ModuleLog.Require(
		script.FindFirstChild("ReleaseReadiness") as ModuleScript,
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
			return { ok: false, message: "Unknown Studio admin action: " + tostring(action) };
		}
		if (!typeIs(username, "string") || username === "") {
			return { ok: false, message: "Provide the username of a player in this test server." };
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
	const studioSoftShutdown = makeBindable("StudioSoftShutdown", () => {
		publishShutdown("Saving", "Tempering a fresh test server. Your progress is safe.");
		return true;
	});
	studioSoftShutdown.Name = "StudioSoftShutdown";
}

game.BindToClose(() => {
	const production = !RunService.IsStudio();
	publishShutdown(
		"Saving",
		production
			? "Securing your forge before the server refreshes."
			: "Tempering a fresh test server. Your progress is safe.",
	);
	closeRuntime();
	if (!production) {
		return;
	}
	const remainingPlayers = Players.GetPlayers();
	if (remainingPlayers.size() === 0) {
		return;
	}
	publishShutdown("Teleporting", "Progress saved. Opening a fresh forge now.");
	task.wait(0.2);
	const options = new Instance("TeleportOptions");
	options.SetTeleportData({
		SoftShutdown: true,
		FromJob: game.JobId,
		Version: GameConfig.Game.Version,
	});
	const [ok, issue] = pcall(() => {
		TeleportService.TeleportAsync(game.PlaceId, remainingPlayers, options);
	});
	options.Destroy();
	if (!ok) {
		publishShutdown("Waiting", "Roblox is reconnecting this server. Hold tight.");
		ModuleLog.Warn("Shutdown", "group teleport deferred to Roblox - " + tostring(issue));
	}
});

ModuleLog.Once("server-ready", "server", "Astral Forge " + GameConfig.Game.Version + " is up");
