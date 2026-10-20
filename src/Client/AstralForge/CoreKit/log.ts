import type { RequestFunction } from "../ClientNetwork";
const ReplicatedStorage = game.GetService("ReplicatedStorage");
const UserInputService = game.GetService("UserInputService");
const Workspace = game.GetService("Workspace");

type Severity = "INFO" | "WARN" | "ERROR" | "FATAL" | "NETWORK";
type Params = Record<string, unknown> | undefined;

const recent = new Map<string, number>();
let recentCount = 0;
const emitted = new Set<string>();
let bootMilliseconds = 0;
let bootOrigin = os.clock();
const LEVEL_COLUMN: Record<Severity, string> = { INFO: "info ", WARN: "warn ", ERROR: "error", FATAL: "fatal", NETWORK: "net  " };
const SCOPE_COLUMN_WIDTH = 12;
const startedAt = os.clock();

function field(value: unknown): string {
	const [sanitized] = tostring(value).gsub("[\r\n]+", " ");
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
			return "%d".format(value);
		}
		return "%.3g".format(value);
	}
	if (typeIs(value, "boolean")) {
		return tostring(value);
	}
	const text = field(value);
	if (text === "" || text.find('[%s="]')[0] !== undefined) {
		return '"' + text.gsub('"', "'")[0] + '"';
	}
	return text;
}

function formatPair(key: unknown, value: unknown): string {
	let name = field(key);
	name = name.sub(1, 1).lower() + name.sub(2);
	if (typeIs(value, "number") && name.sub(-2) === "Ms" && name.size() > 2) {
		return name.sub(1, -3) + "=" + formatValue(value) + "ms";
	}
	return name + "=" + formatValue(value);
}

function formatLine(severity: Severity, scope: unknown, message: unknown, params: Params): string {
	let pairsText = "";
	if (params !== undefined && typeIs(params, "table")) {
		const keys = new Array<defined>();
		for (const [key] of pairs(params)) {
			keys.push(key);
		}
		keys.sort((a, b) => tostring(a) < tostring(b));
		const pieces = new Array<string>(keys.size());
		for (const key of keys) {
			pieces.push(formatPair(key, (params as Record<string, unknown>)[key as string]));
		}
		if (pieces.size() > 0) {
			pairsText = "  " + pieces.join(" ");
		}
	}
	let scopeText = field(scope).lower();
	if (scopeText.size() < SCOPE_COLUMN_WIDTH) {
		scopeText += " ".rep(SCOPE_COLUMN_WIDTH - scopeText.size());
	}
	return "%8.3f  %s  %s  %s%s".format(os.clock() - startedAt, LEVEL_COLUMN[severity] ?? severity.lower(), scopeText, field(message), pairsText);
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

function debugEnabled(): boolean {
	return ReplicatedStorage.GetAttribute("AstralDebugLogs") === true;
}

export const ClientLog = {
	info(scope: string, message: string, params?: Params) {
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
		if (debugEnabled()) {
			print(formatLine("INFO", scope, message, params));
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
