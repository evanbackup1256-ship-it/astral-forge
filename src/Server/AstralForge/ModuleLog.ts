import * as LogBook from "../../Shared/AstralForge/Shared/LogBook";
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

// every level goes through here: the black box always records, then policy decides whether it prints
function emit(severity: string, scope: string, message: string, params: Params): void {
	LogBook.record(severity, scope, message, params !== undefined ? LogFormat.formatFields(params) : "");
	if (severity === "TRACE" || !LogPolicy.enabled(severity, scope)) {
		return;
	}
	if (telemetry) telemetry.RecordLog(TELEMETRY_CATEGORY[severity] ?? "Info");
	const line = formatLine(severity, scope, message, params);
	if (LogPolicy.levelOf(severity) === "warn" || LogPolicy.levelOf(severity) === "error" || LogPolicy.levelOf(severity) === "fatal") {
		warn(line);
		// an error carries what led up to it, once per scope per few seconds
		if (severity === "ERROR" || severity === "FATAL") {
			const gate = LogPolicy.throttle(`context:${scope}`, 8);
			if (gate !== undefined) {
				for (const crumb of LogBook.breadcrumbs(6)) {
					warn("          . " + crumb);
				}
			}
		}
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

let diagnosticsStarted = false;

const ModuleLog = {
	AttachTelemetry(this: void, service: TelemetryLike): void {
		telemetry = service;
	},

	// below debug: recorded in the black box, never printed. For high-volume detail worth having in a dump.
	Trace(this: void, scope: string, message: string, params?: Record<string, unknown>): void {
		emit("TRACE", scope, message, params);
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

	// a slow-operation warning, at most one line per key per window; the drops are counted on the next line
	Slow(this: void, key: string, seconds: number, scope: string, message: string, params?: Record<string, unknown>): boolean {
		const dropped = LogPolicy.throttle(key, seconds);
		if (dropped === undefined) {
			return false;
		}
		emit("WARN", scope, message, withDropped(params, dropped));
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

	Count(this: void, key: string, amount?: number): number {
		return LogBook.count(key, amount ?? 1);
	},

	// times a piece of work: call the returned function when it is done (it returns the milliseconds). The
	// duration is recorded as a timing; a slow one is logged at info, a normal one at debug.
	Span(this: void, scope: string, name: string, params?: Record<string, unknown>): (extra?: Record<string, unknown>) => number {
		const started = os.clock();
		return (extra?: Record<string, unknown>) => {
			const elapsed = os.clock() - started;
			LogBook.timing(`${string.lower(scope)}.${name}`, elapsed);
			const merged: Record<string, unknown> = {};
			if (params) for (const [key, value] of pairs(params)) merged[key as string] = value;
			if (extra) for (const [key, value] of pairs(extra)) merged[key as string] = value;
			merged.ElapsedMs = math.floor(elapsed * 1000 + 0.5);
			if (elapsed >= 0.25) {
				ModuleLog.Info(scope, `${name} took a while`, merged);
			} else {
				ModuleLog.Debug(scope, name, merged);
			}
			return elapsed * 1000;
		};
	},

	Require(this: void, moduleScript: ModuleScript, label: string): unknown {
		const started = os.clock();
		const [ok, result] = pcall(() => require(moduleScript) as unknown);
		const elapsed = os.clock() - started;
		LogBook.timing("boot.require", elapsed);
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

	// the black box: recent lines (oldest first), the counters and timings, and a text summary for a console
	Recent(this: void, limit?: number, minLevel?: string, scope?: string): string[] {
		const out: string[] = [];
		for (const entry of LogBook.recent(limit ?? 50, minLevel, scope)) {
			out.push(LogBook.formatEntry(entry));
		}
		return out;
	},

	Snapshot(this: void): LogBook.Snapshot {
		return LogBook.snapshot();
	},

	// prints the summary and the last lines at info or above (call from the command bar when something is off)
	Dump(this: void, limit?: number): void {
		print("---- server log summary ----");
		for (const line of LogBook.summary(14)) {
			print(line);
		}
		print("---- recent lines ----");
		for (const line of ModuleLog.Recent(limit ?? 40, "info")) {
			print(line);
		}
	},

	// session-long watchers: one health line a minute, hitch counting, and every Lua error into the book
	StartDiagnostics(this: void): void {
		if (diagnosticsStarted) {
			return;
		}
		diagnosticsStarted = true;
		const RunService = game.GetService("RunService");
		const Players = game.GetService("Players");
		const Stats = game.GetService("Stats");
		const ScriptContext = game.GetService("ScriptContext");
		const ServerStorage = game.GetService("ServerStorage");
		ModuleLog.Info("session", "server session", {
			Studio: RunService.IsStudio(),
			PlaceId: game.PlaceId,
			JobId: RunService.IsStudio() ? "studio" : game.JobId,
			MaxPlayers: Players.MaxPlayers,
			MemoryMb: math.floor(Stats.GetTotalMemoryUsageMb()),
		});
		ScriptContext.Error.Connect((message, trace, culprit) => {
			LogBook.count("server.luaerrors");
			const key = string.sub(tostring(message), 1, 80);
			const gate = LogPolicy.throttle(`lua:${key}`, 6);
			if (gate !== undefined) {
				const [firstLine] = string.match(tostring(trace), "([^\n]*)");
				ModuleLog.Error("lua", tostring(message), { Script: culprit !== undefined ? culprit.GetFullName() : "?", At: firstLine ?? "", Dropped: gate });
			}
		});
		let worst = 0;
		let frames = 0;
		let total = 0;
		RunService.Heartbeat.Connect((dt) => {
			frames += 1;
			total += dt;
			if (dt > worst) {
				worst = dt;
			}
			if (dt > 0.5) {
				LogBook.count("server.hitch.severe");
				ModuleLog.Slow("hitch:severe", 10, "perf", "server hitch", { FrameMs: math.floor(dt * 1000) });
			} else if (dt > 0.15) {
				LogBook.count("server.hitch");
			}
		});
		task.spawn(() => {
			while (true) {
				task.wait(60);
				const requests = LogBook.counter("server.request.total");
				const slow = LogBook.timingOf("server.request.all")?.slow ?? 0;
				ModuleLog.Info("health", "server health", {
					Players: Players.GetPlayers().size(),
					AvgFps: frames > 0 ? math.floor(frames / math.max(0.001, total)) : 0,
					WorstFrameMs: math.floor(worst * 1000),
					MemoryMb: math.floor(Stats.GetTotalMemoryUsageMb()),
					Requests: requests,
					Rejected: LogBook.counter("server.request.rejected"),
					Threw: LogBook.counter("server.request.threw"),
					SlowRequests: slow,
					Errors: LogBook.counter("log.error") + LogBook.counter("server.luaerrors"),
					Warnings: LogBook.counter("log.warn"),
				});
				worst = 0;
				frames = 0;
				total = 0;
			}
		});
		// readable from the command bar or a test driver: ServerStorage.AstralForgeLogs:Invoke()
		const endpoint = new Instance("BindableFunction");
		endpoint.Name = "AstralForgeLogs";
		endpoint.OnInvoke = () => ({ Snapshot: LogBook.snapshot(), Recent: ModuleLog.Recent(80, "debug") });
		endpoint.Parent = ServerStorage;
	},
};

export = table.freeze(ModuleLog);
