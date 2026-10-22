import type { RequestFunction } from "../ClientNetwork";
import * as LogFormat from "../../../Shared/AstralForge/Shared/LogFormat";
import * as LogPolicy from "../../../Shared/AstralForge/Shared/LogPolicy";
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

type Severity = "INFO" | "WARN" | "ERROR" | "FATAL" | "NETWORK" | "DEBUG";
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

export const ClientLog = {
	info(scope: string, message: string, params?: Params) {
		if (!LogPolicy.enabled("INFO", scope)) return;
		print(formatLine("INFO", scope, message, params));
	},
	warn(scope: string, message: string, params?: Params) {
		warn(formatLine("WARN", scope, message, params));
	},
	error(scope: string, message: string, params?: Params) {
		warn(formatLine("ERROR", scope, message, params));
	},
	fatal(scope: string, message: string, params?: Params) {
		warn(formatLine("FATAL", scope, message, params));
	},
	network(scope: string, message: string, params?: Params) {
		print(formatLine("NETWORK", scope, message, params));
	},
	debug(scope: string, message: string, params?: Params) {
		if (debugEnabled(scope)) {
			print(formatLine("DEBUG", scope, message, params));
		}
	},
	once(key: string, scope: string, message: string, params?: Params) {
		if (emitted.has(key)) {
			return;
		}
		emitted.add(key);
		print(formatLine("INFO", scope, message, params));
	},
	warnEvery(key: string, seconds: number, scope: string, message: string, params?: Params) {
		if (available(`warn:${key}`, seconds)) {
			warn(formatLine("WARN", scope, message, params));
		}
	},
	errorEvery(key: string, seconds: number, scope: string, message: string, params?: Params) {
		if (available(`err:${key}`, seconds)) {
			warn(formatLine("ERROR", scope, message, params));
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

export function beginClientSession() {
	recent.clear();
	emitted.clear();
	bootMilliseconds = 0;
	bootOrigin = os.clock();
	sharedQualitySample = undefined;
}

export function recordPerformanceTelemetry(sample: QualitySample) {
	sharedQualitySample = sample;
}

export function markBootComplete() {
	if (bootMilliseconds <= 0) {
		bootMilliseconds = math.floor((os.clock() - bootOrigin) * 1000 + 0.5);
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
