const ReplicatedStorage = game.GetService("ReplicatedStorage");

interface TelemetryLike {
	RecordLog(this: void, category: string): void;
}

// Injected at boot by init.server.luau to avoid a circular require between
// ModuleLog and the service registry.
let telemetry: TelemetryLike | undefined = undefined;

const recent: Record<string, number> = {};
const emitted: Record<string, boolean> = {};


const LEVEL_COLUMN: Record<string, string> = {
	INFO: "info ",
	WARN: "warn ",
	ERROR: "error",
	FATAL: "fatal",
	NETWORK: "net  ",
};
const SCOPE_COLUMN_WIDTH = 12;
const startedAt = os.clock();

function field(value: unknown): string {
	const [sanitized] = string.gsub(tostring(value), "[\r\n]+", " ");
	return sanitized;
}

function formatValue(value: unknown): string {
	if (typeIs(value, "number")) {
		if (value !== value) {
			return "nan";
		}
		if (value === math.huge || value === -math.huge) {
			return value > 0 ? "inf" : "-inf";
		}
		if (value === math.floor(value) && math.abs(value) < 1e15) {
			return string.format("%d", value);
		}
		return string.format("%.3g", value);
	}
	if (typeIs(value, "boolean")) {
		return tostring(value);
	}
	const text = field(value);
	const [match] = text.find("[%s=\"]");
	if (text === "" || match !== undefined) {
		const [escaped] = string.gsub(text, '"', "'");
		return '"' + escaped + '"';
	}
	return text;
}

function formatPair(key: unknown, value: unknown): string {
	let name = field(key);
	name = string.lower(string.sub(name, 1, 1)) + string.sub(name, 2);
	if (typeIs(value, "number") && string.sub(name, -2) === "Ms" && name.size() > 2) {
		return string.sub(name, 1, -3) + "=" + formatValue(value) + "ms";
	}
	return name + "=" + formatValue(value);
}

function formatLine(severity: string, scope: string, message: string, params?: Record<string, unknown>): string {
	let pairsText = "";
	if (params !== undefined && typeIs(params, "table")) {
		const keys: string[] = [];
		for (const key of pairs(params)) {
			keys.push(tostring(key));
		}
		table.sort(keys, (a, b) => tostring(a) < tostring(b));
		const pieces: string[] = table.create(keys.size());
		for (const key of keys) {
			pieces.push(formatPair(key, params[key]));
		}
		if (pieces.size() > 0) {
			pairsText = "  " + pieces.join(" ");
		}
	}
	let scopeText = string.lower(field(scope));
	if (scopeText.size() < SCOPE_COLUMN_WIDTH) {
		scopeText += string.rep(" ", SCOPE_COLUMN_WIDTH - scopeText.size());
	}
	return string.format(
		"%8.3f  %s  %s  %s%s",
		os.clock() - startedAt,
		LEVEL_COLUMN[severity] ?? string.lower(severity),
		scopeText,
		field(message),
		pairsText,
	);
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
			print(formatLine("INFO", scope, message, params));
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
