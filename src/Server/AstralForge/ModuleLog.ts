import * as LogFormat from "../../Shared/AstralForge/Shared/LogFormat";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

interface TelemetryLike {
	RecordLog(this: void, category: string): void;
}

// Injected at boot by RemoteBridge (AttachTelemetry) so ModuleLog does not import
// the ServerTelemetry service directly.
let telemetry: TelemetryLike | undefined = undefined;

const recent: Record<string, number> = {};
const emitted: Record<string, boolean> = {};


const startedAt = os.clock();

function formatLine(severity: string, scope: string, message: string, params?: Record<string, unknown>): string {
	return LogFormat.formatLine(os.clock() - startedAt, severity, scope, message, params);
}

function debugEnabled(): boolean {
	return ReplicatedStorage.GetAttribute("AstralDebugLogs") === true;
}

const ModuleLog = {
	AttachTelemetry(this: void, service: TelemetryLike): void {
		telemetry = service;
	},

	Info(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		if (telemetry) telemetry.RecordLog("Info");
		print(formatLine("INFO", scope, message, params));
	},

	Warn(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		if (telemetry) telemetry.RecordLog("Warning");
		warn(formatLine("WARN", scope, message, params));
	},

	Error(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		if (telemetry) telemetry.RecordLog("Error");
		warn(formatLine("ERROR", scope, message, params));
	},

	Fatal(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		if (telemetry) telemetry.RecordLog("Fatal");
		warn(formatLine("FATAL", scope, message, params));
	},

	Network(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		if (telemetry) telemetry.RecordLog("Network");
		print(formatLine("NETWORK", scope, message, params));
	},

	Debug(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		if (debugEnabled()) {
			if (telemetry) telemetry.RecordLog("Debug");
			print(formatLine("DEBUG", scope, message, params));
		}
	},

	Once(this: void, key: string, scope: string, message: string): boolean {
		if (emitted[key]) {
			return false;
		}
		emitted[key] = true;
		ModuleLog.Info(scope, message);
		return true;
	},

	Every(this: void, key: string, seconds: number, scope: string, message: string): boolean {
		const now = os.clock();
		const previous = recent[key];
		if (previous !== undefined && now - previous < seconds) {
			return false;
		}
		recent[key] = now;
		ModuleLog.Warn(scope, message);
		return true;
	},

	Player(this: void, player: Player, message: string): void {
		ModuleLog.Info("PLAYER", message, { Player: player.Name, UserId: player.UserId });
	},

	Require(this: void, moduleScript: ModuleScript, label: string): unknown {
		const started = os.clock();
		const [ok, result] = pcall(() => require(moduleScript) as unknown);
		const elapsed = os.clock() - started;
		if (!ok) {
			ModuleLog.Error("BOOT", string.format("%s failed", label), {
				ElapsedMs: math.floor(elapsed * 1000),
				Error: tostring(result),
			});
			error(result);
		}
		if (elapsed >= 0.15) {
			ModuleLog.Info("BOOT", string.format("%s loaded", label), { ElapsedMs: math.floor(elapsed * 1000) });
		} else {
			ModuleLog.Debug("BOOT", string.format("%s loaded", label), { ElapsedMs: math.floor(elapsed * 1000) });
		}
		return result;
	},
};

export = table.freeze(ModuleLog);
