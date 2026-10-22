import * as LogFormat from "../../Shared/AstralForge/Shared/LogFormat";
import * as LogPolicy from "../../Shared/AstralForge/Shared/LogPolicy";

interface TelemetryLike {
	RecordLog(this: void, category: string): void;
}

// Injected at boot by RemoteBridge (AttachTelemetry) so ModuleLog does not import
// the ServerTelemetry service directly.
let telemetry: TelemetryLike | undefined = undefined;

const emitted: Record<string, boolean> = {};

const startedAt = os.clock();

function formatLine(severity: string, scope: string, message: string, params?: Record<string, unknown>): string {
	return LogFormat.formatLine(os.clock() - startedAt, severity, scope, message, params);
}

type Params = Record<string, unknown> | undefined;

const TELEMETRY_CATEGORY: Record<string, string> = {
	INFO: "Info",
	WARN: "Warning",
	ERROR: "Error",
	FATAL: "Fatal",
	NETWORK: "Network",
	DEBUG: "Debug",
};

// every level goes through here: policy check, telemetry count, then print or warn
function emit(severity: string, scope: string, message: string, params: Params): void {
	if (!LogPolicy.enabled(severity, scope)) {
		return;
	}
	if (telemetry) telemetry.RecordLog(TELEMETRY_CATEGORY[severity] ?? "Info");
	const line = formatLine(severity, scope, message, params);
	if (LogPolicy.levelOf(severity) === "warn" || LogPolicy.levelOf(severity) === "error" || LogPolicy.levelOf(severity) === "fatal") {
		warn(line);
	} else {
		print(line);
	}
}

function withDropped(params: Params, dropped: number): Params {
	if (dropped <= 0) {
		return params;
	}
	const merged: Record<string, unknown> = {};
	if (params) {
		for (const [key, value] of pairs(params)) merged[key as string] = value;
	}
	merged.Dropped = dropped;
	return merged;
}

const ModuleLog = {
	AttachTelemetry(this: void, service: TelemetryLike): void {
		telemetry = service;
	},

	Info(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("INFO", scope, message, params);
	},

	Warn(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("WARN", scope, message, params);
	},

	Error(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("ERROR", scope, message, params);
	},

	Fatal(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("FATAL", scope, message, params);
	},

	Network(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("NETWORK", scope, message, params);
	},

	Debug(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("DEBUG", scope, message, params);
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
		const dropped = LogPolicy.throttle(key, seconds);
		if (dropped === undefined) {
			return false;
		}
		emit("WARN", scope, message, withDropped(undefined, dropped));
		return true;
	},

	// one line in every `rate` for a key; printed lines carry dropped=N for the ones skipped
	Sampled(this: void, key: string, rate: number, scope: string, message: string, params?: Record<string, unknown>): boolean {
		const dropped = LogPolicy.sample(key, rate);
		if (dropped === undefined) {
			return false;
		}
		emit("INFO", scope, message, withDropped(params, dropped));
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
