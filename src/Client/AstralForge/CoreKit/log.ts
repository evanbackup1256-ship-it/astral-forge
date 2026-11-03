import type { RequestFunction } from "../ClientNetwork";
import * as LogBook from "../../../Shared/AstralForge/Shared/LogBook";
import * as LogFormat from "../../../Shared/AstralForge/Shared/LogFormat";
import * as LogPolicy from "../../../Shared/AstralForge/Shared/LogPolicy";
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");
const RunService = game.GetService("RunService");

type Severity = "TRACE" | "INFO" | "WARN" | "ERROR" | "FATAL" | "NETWORK" | "DEBUG";
type Params = Record<string, unknown> | undefined;

const recent = new Map<string, number>();
let recentCount = 0;
const emitted = new Set<string>();
let bootMilliseconds = 0;
let bootOrigin = os.clock();
const startedAt = os.clock();

function formatLine(severity: Severity, scope: unknown, message: unknown, params: Params): string {
	return LogFormat.formatLine(os.clock() - startedAt, severity, scope, message, params);
}

function available(key: string, seconds: number): boolean {
	const now = os.clock();
	const previous = recent.get(key);
	if (previous !== undefined && now - previous < seconds) {
		return false;
	}
	if (previous === undefined) {
		recentCount += 1;
		if (recentCount > 512) {
			recent.clear();
			recentCount = 1;
		}
	}
	recent.set(key, now);
	return true;
}

function debugEnabled(scope?: string): boolean {
	return LogPolicy.enabled("DEBUG", scope);
}

// the black box takes every line, printed or not, so an error can show what led up to it
function book(severity: Severity, scope: string, message: string, params: Params) {
	LogBook.record(severity, scope, message, params !== undefined ? LogFormat.formatFields(params) : "");
}

// an error line is followed by the few lines before it, once per scope per eight seconds
function context(scope: string) {
	if (available(`context:${scope}`, 8)) {
		for (const crumb of LogBook.breadcrumbs(6)) {
			warn("          . " + crumb);
		}
	}
}

export const ClientLog = {
	// below debug: recorded in the black box and never printed
	trace(scope: string, message: string, params?: Params) {
		book("TRACE", scope, message, params);
	},
	info(scope: string, message: string, params?: Params) {
		book("INFO", scope, message, params);
		if (!LogPolicy.enabled("INFO", scope)) return;
		print(formatLine("INFO", scope, message, params));
	},
	warn(scope: string, message: string, params?: Params) {
		book("WARN", scope, message, params);
		warn(formatLine("WARN", scope, message, params));
	},
	error(scope: string, message: string, params?: Params) {
		book("ERROR", scope, message, params);
		warn(formatLine("ERROR", scope, message, params));
		context(scope);
	},
	fatal(scope: string, message: string, params?: Params) {
		book("FATAL", scope, message, params);
		warn(formatLine("FATAL", scope, message, params));
		context(scope);
	},
	network(scope: string, message: string, params?: Params) {
		book("NETWORK", scope, message, params);
		print(formatLine("NETWORK", scope, message, params));
	},
	debug(scope: string, message: string, params?: Params) {
		book("DEBUG", scope, message, params);
		if (debugEnabled(scope)) {
			print(formatLine("DEBUG", scope, message, params));
		}
	},
	once(key: string, scope: string, message: string, params?: Params) {
		if (emitted.has(key)) {
			return;
		}
		emitted.add(key);
		book("INFO", scope, message, params);
		print(formatLine("INFO", scope, message, params));
	},
	warnEvery(key: string, seconds: number, scope: string, message: string, params?: Params) {
		book("WARN", scope, message, params);
		if (available(`warn:${key}`, seconds)) {
			warn(formatLine("WARN", scope, message, params));
		}
	},
	errorEvery(key: string, seconds: number, scope: string, message: string, params?: Params) {
		book("ERROR", scope, message, params);
		if (available(`err:${key}`, seconds)) {
			warn(formatLine("ERROR", scope, message, params));
			context(scope);
		}
	},
	count(key: string, amount?: number): number {
		return LogBook.count(key, amount ?? 1);
	},
	// times a piece of work: call the returned function when it is done (it returns the milliseconds).
	// The duration lands in the book as a timing; a slow one is logged at info, a normal one at debug.
	span(scope: string, name: string, params?: Params): (extra?: Params) => number {
		const started = os.clock();
		return (extra?: Params) => {
			const elapsed = os.clock() - started;
			LogBook.timing(`${string.lower(scope)}.${name}`, elapsed);
			const merged: Record<string, unknown> = {};
			if (params) for (const [key, value] of pairs(params)) merged[key as string] = value;
			if (extra) for (const [key, value] of pairs(extra)) merged[key as string] = value;
			merged.ElapsedMs = math.floor(elapsed * 1000 + 0.5);
			if (elapsed >= 0.25) {
				ClientLog.info(scope, `${name} took a while`, merged);
			} else {
				ClientLog.debug(scope, name, merged);
			}
			return elapsed * 1000;
		};
	},
	recent(limit?: number, minLevel?: string, scope?: string): string[] {
		const out: string[] = [];
		for (const entry of LogBook.recent(limit ?? 50, minLevel, scope)) {
			out.push(LogBook.formatEntry(entry));
		}
		return out;
	},
	// prints the summary and the last lines at info or above (from the command bar when something is off)
	dump(limit?: number): void {
		print("---- client log summary ----");
		for (const line of LogBook.summary(14)) {
			print(line);
		}
		print("---- recent lines ----");
		for (const line of ClientLog.recent(limit ?? 40, "info")) {
			print(line);
		}
	},
};

export interface QualitySample {
	sampledAt: number;
	fps: number;
	p95FrameTimeMs: number;
	jankRatio: number;
	pingMs?: number;
}

let sharedQualitySample: QualitySample | undefined;
let diagnosticsStarted = false;

// session-long watchers: the opening banner, every Lua error into the book, hitch counting, a health
// line a minute, and the book itself readable from ReplicatedStorage.AstralForgeLogs:Invoke()
function startDiagnostics() {
	if (diagnosticsStarted) {
		return;
	}
	diagnosticsStarted = true;
	const Stats = game.GetService("Stats");
	const ScriptContext = game.GetService("ScriptContext");
	const ReplicatedStorage = game.GetService("ReplicatedStorage");
	const camera = Workspace.CurrentCamera;
	const viewport = camera !== undefined ? camera.ViewportSize : new Vector2(0, 0);
	ClientLog.info("session", "client session", {
		Studio: RunService.IsStudio(),
		Input: inputFamily(),
		Touch: UserInputService.TouchEnabled,
		Gamepad: UserInputService.GamepadEnabled,
		Keyboard: UserInputService.KeyboardEnabled,
		Width: math.floor(viewport.X),
		Height: math.floor(viewport.Y),
		MemoryMb: math.floor(Stats.GetTotalMemoryUsageMb()),
	});
	ScriptContext.Error.Connect((message, trace, culprit) => {
		LogBook.count("client.luaerrors");
		const key = string.sub(tostring(message), 1, 80);
		const [firstLine] = string.match(tostring(trace), "([^\n]*)");
		ClientLog.errorEvery(`lua:${key}`, 6, "lua", tostring(message), {
			Script: culprit !== undefined ? culprit.GetFullName() : "?",
			At: firstLine ?? "",
		});
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
			LogBook.count("client.hitch.severe");
			ClientLog.warnEvery("hitch:severe", 10, "perf", "severe hitch", { FrameMs: math.floor(dt * 1000) });
		} else if (dt > 0.15) {
			LogBook.count("client.hitch");
			if (LogPolicy.throttle("hitch:minor", 15) !== undefined) {
				ClientLog.debug("perf", "hitch", { FrameMs: math.floor(dt * 1000) });
			}
		}
	});
	task.spawn(() => {
		while (true) {
			task.wait(60);
			const sample = sharedQualitySample;
			const slow = LogBook.timingOf("client.request.all")?.slow ?? 0;
			ClientLog.info("health", "client health", {
				AvgFps: frames > 0 ? math.floor(frames / math.max(0.001, total)) : 0,
				WorstFrameMs: math.floor(worst * 1000),
				P95Ms: sample !== undefined ? math.floor(sample.p95FrameTimeMs) : 0,
				PingMs: sample !== undefined ? math.floor(sample.pingMs ?? 0) : 0,
				MemoryMb: math.floor(Stats.GetTotalMemoryUsageMb()),
				Requests: LogBook.counter("client.request.total"),
				Failed: LogBook.counter("client.request.failed"),
				TimedOut: LogBook.counter("client.request.timeout"),
				SlowRequests: slow,
				Hitches: LogBook.counter("client.hitch") + LogBook.counter("client.hitch.severe"),
				Errors: LogBook.counter("log.error") + LogBook.counter("client.luaerrors"),
				Warnings: LogBook.counter("log.warn"),
			});
			worst = 0;
			frames = 0;
			total = 0;
		}
	});
	const endpoint = new Instance("BindableFunction");
	endpoint.Name = "AstralForgeLogs";
	endpoint.OnInvoke = () => ({ Snapshot: LogBook.snapshot(), Recent: ClientLog.recent(80, "debug") });
	endpoint.Parent = ReplicatedStorage;
}

export function beginClientSession() {
	recent.clear();
	emitted.clear();
	bootMilliseconds = 0;
	bootOrigin = os.clock();
	sharedQualitySample = undefined;
	startDiagnostics();
}

export function recordPerformanceTelemetry(sample: QualitySample) {
	sharedQualitySample = sample;
}

export function markBootComplete() {
	if (bootMilliseconds <= 0) {
		bootMilliseconds = math.floor((os.clock() - bootOrigin) * 1000 + 0.5);
		LogBook.timing("boot.total", bootMilliseconds / 1000);
		ClientLog.info("boot", "boot complete", { ElapsedMs: bootMilliseconds });
	}
}

function inputFamily(): "touch" | "gamepad" | "mouse" {
	const preferred = UserInputService.PreferredInput;
	if (preferred === Enum.PreferredInput.Touch) {
		return "touch";
	}
	if (preferred === Enum.PreferredInput.Gamepad || preferred === Enum.PreferredInput.MicroGamepad) {
		return "gamepad";
	}
	return "mouse";
}

export function startPerformanceTelemetry(request: RequestFunction) {
	let alive = true;
	let reportInFlight = false;
	let reportSerial = 0;
	let requestWorker: thread | undefined;
	let requestTimeout: thread | undefined;
	const worker = task.spawn(() => {
		task.wait(20);
		while (alive) {
			const sample = sharedQualitySample;
			if (sample !== undefined && sample.sampledAt > 0) {
				const viewport = Workspace.CurrentCamera?.ViewportSize ?? new Vector2(1, 1);
				const payload = {
					FPS: math.clamp(sample.fps, 0, 360),
					P95Ms: math.clamp(sample.p95FrameTimeMs, 0, 1000),
					JankPct: math.clamp(sample.jankRatio, 0, 1),
					PingMs: math.clamp(sample.pingMs ?? 0, 0, 10000),
					Width: math.max(1, math.floor(viewport.X)),
					Height: math.max(1, math.floor(viewport.Y)),
					BootMs: bootMilliseconds,
					Input: inputFamily(),
				};
				if (!reportInFlight) {
					reportInFlight = true;
					const serial = reportSerial + 1;
					reportSerial = serial;
					requestWorker = task.defer(() => {
						pcall(() => request.invoke("ReportPerformance", payload).expect());
						if (!alive || serial !== reportSerial) {
							return;
						}
						requestWorker = undefined;
						if (requestTimeout !== undefined) {
							task.cancel(requestTimeout);
							requestTimeout = undefined;
						}
						reportInFlight = false;
					});
					requestTimeout = task.delay(6, () => {
						requestTimeout = undefined;
						if (!alive || serial !== reportSerial || !reportInFlight) {
							return;
						}
						if (requestWorker !== undefined) {
							task.cancel(requestWorker);
						}
						requestWorker = undefined;
						reportSerial += 1;
						reportInFlight = false;
					});
				}
			}
			task.wait(60);
		}
	});
	return () => {
		alive = false;
		reportSerial += 1;
		task.cancel(worker);
		if (requestWorker !== undefined) {
			task.cancel(requestWorker);
		}
		if (requestTimeout !== undefined) {
			task.cancel(requestTimeout);
		}
		requestWorker = undefined;
		requestTimeout = undefined;
		sharedQualitySample = undefined;
	};
}
