import { isConstrainedInput } from "../CoreKit/inputLayer";
import type { RequestFunction } from "../ClientNetwork";
import React from "@rbxts/react";
import { ClientLog, QualitySample, recordPerformanceTelemetry } from "../CoreKit/log";
import {
	boundsForMode,
	DeviceProfile,
	Governor,
	PerformanceMode,
	performanceModeFor,
	profileFor,
	tierForDevice,
	TIER_MAX,
	TierProfile,
} from "../../../Shared/AstralForge/Shared/AntilagGovernor";
import { setLive } from "./antilagState";

const RunService = game.GetService("RunService");
const Stats = game.GetService("Stats");
const UserInputService = game.GetService("UserInputService");

export function constrainedDevice(): boolean {
	if (isConstrainedInput()) {
		return true;
	}
	const [preferredOk, preferred] = pcall(() => UserInputService.PreferredInput);
	if (preferredOk && preferred !== undefined) {
		if (preferred === Enum.PreferredInput.Touch) {
			return true;
		}
		if (preferred === Enum.PreferredInput.Gamepad) {
			return true;
		}
	}
	return false;
}

const IS_CONSTRAINED = constrainedDevice();

type StatsItem = Instance & { GetValue(): number; GetValueString(): string };

export interface Telemetry extends QualitySample {
	fps: number;
	lowFps: number;
	frameTimeMs: number;
	p50FrameTimeMs: number;
	p95FrameTimeMs: number;
	p99FrameTimeMs: number;
	worstFrameMs: number;
	jankRatio: number;
	hitchScore: number;
	pingMs?: number;
	pingJitterMs?: number;
	sampledAt: number;
}

const DEFAULT_FRAME_MS = IS_CONSTRAINED ? 1000 / 48 : 1000 / 60;
const DEFAULT_TELEMETRY: Telemetry = {
	fps: IS_CONSTRAINED ? 48 : 60,
	lowFps: IS_CONSTRAINED ? 42 : 55,
	frameTimeMs: DEFAULT_FRAME_MS,
	p50FrameTimeMs: DEFAULT_FRAME_MS,
	p95FrameTimeMs: DEFAULT_FRAME_MS,
	p99FrameTimeMs: DEFAULT_FRAME_MS,
	worstFrameMs: DEFAULT_FRAME_MS,
	jankRatio: 0,
	hitchScore: 0,
	sampledAt: 0,
};

type TelemetryListener = (sample: Telemetry) => void;

const telemetryListeners = new Set<TelemetryListener>();
const pingHistory = new Array<number>();
let telemetryConnection: RBXScriptConnection | undefined;
let latestTelemetry = DEFAULT_TELEMETRY;
let cachedPingItem: StatsItem | undefined;
let latencyRemote: RequestFunction | undefined;
let latencyAction: string | undefined = "MeasureLatency";
let latencyWorker: thread | undefined;
const latencyProbeWorkers = new Set<thread>();
const latencyTimeoutWorkers = new Set<thread>();
let latencyGeneration = 0;
let lastRoundTripProbeAt = -math.huge;
const FRAME_RING = IS_CONSTRAINED ? 48 : 72;
const SAMPLE_SECONDS = IS_CONSTRAINED ? 0.48 : 0.32;
const frames = new Array<number>(FRAME_RING, 1 / 60);
const scratch = new Array<number>(FRAME_RING, 1 / 60);
let frameWrite = 0;
let frameFilled = 0;

function validPing(value: unknown): value is number {
	return typeIs(value, "number") && value === value && value >= 0 && value <= 10000;
}

function parsePingText(value: string): number | undefined {
	const [match] = value.match("([%d%.]+)");
	if (match === undefined) {
		return undefined;
	}
	const parsed = tonumber(match);
	return validPing(parsed) ? parsed : undefined;
}

function readStatsPing(item: StatsItem): number | undefined {
	const [valueOk, value] = pcall(() => item.GetValue());
	if (valueOk && validPing(value)) {
		return value;
	}
	const [textOk, text] = pcall(() => item.GetValueString());
	if (textOk && typeIs(text, "string")) {
		return parsePingText(text);
	}
	return undefined;
}

function enginePingMs(): number | undefined {
	if (cachedPingItem?.Parent !== undefined) {
		const value = readStatsPing(cachedPingItem);
		if (value !== undefined) {
			return value;
		}
		cachedPingItem = undefined;
	}
	const network = Stats.FindFirstChild("Network");
	const server = network?.FindFirstChild("ServerStatsItem");
	const item = server?.FindFirstChild("Data Ping") ?? Stats.FindFirstChild("Data Ping", true);
	if (item === undefined) {
		return undefined;
	}
	const statsItem = item as StatsItem;
	const value = readStatsPing(statsItem);
	if (value === undefined) {
		return undefined;
	}
	cachedPingItem = statsItem;
	return value;
}

function publishPingSample(value: number, roundTrip = false) {
	if (!validPing(value)) {
		return;
	}
	if (roundTrip) {
		if (os.clock() - lastRoundTripProbeAt > 6) {
			pingHistory.clear();
		}
		lastRoundTripProbeAt = os.clock();
	} else if (os.clock() - lastRoundTripProbeAt <= 6) {
		return;
	}
	pingHistory.push(value);
	while (pingHistory.size() > 7) {
		pingHistory.shift();
	}
}

function stopLatencyWorker() {
	latencyGeneration += 1;
	if (latencyWorker !== undefined) {
		task.cancel(latencyWorker);
		latencyWorker = undefined;
	}
	for (const worker of latencyProbeWorkers) {
		task.cancel(worker);
	}
	for (const worker of latencyTimeoutWorkers) {
		task.cancel(worker);
	}
	latencyProbeWorkers.clear();
	latencyTimeoutWorkers.clear();
}

function startLatencyWorker() {
	if (latencyWorker !== undefined || latencyRemote === undefined || telemetryListeners.size() === 0) {
		return;
	}
	const generation = latencyGeneration + 1;
	latencyGeneration = generation;
	latencyWorker = task.spawn(() => {
		task.wait(1.25);
		let probeSerial = 0;
		let probeInFlight = false;
		let outstandingProbes = 0;
		while (generation === latencyGeneration && telemetryListeners.size() > 0 && latencyRemote !== undefined) {
			const statsPing = enginePingMs();
			const needsFallback = statsPing === undefined || statsPing <= 0.5;
			if (!probeInFlight && needsFallback && outstandingProbes < 2) {
				const remote = latencyRemote;
				const action = latencyAction;
				const serial = probeSerial + 1;
				probeSerial = serial;
				probeInFlight = true;
				outstandingProbes += 1;
				const startedAt = os.clock();
				let timeoutWorker: thread | undefined;
				const probeWorker: thread = task.defer(() => {
					const [ok, response] = pcall(() => remote.invoke(action ?? "MeasureLatency").expect());
					latencyProbeWorkers.delete(probeWorker);
					if (timeoutWorker !== undefined && latencyTimeoutWorkers.has(timeoutWorker)) {
						latencyTimeoutWorkers.delete(timeoutWorker);
						task.cancel(timeoutWorker);
					}
					if (generation !== latencyGeneration) {
						return;
					}
					outstandingProbes = math.max(0, outstandingProbes - 1);
					if (serial !== probeSerial) {
						return;
					}
					probeInFlight = false;
					const elapsedMs = (os.clock() - startedAt) * 1000;
					if (ok && typeIs(response, "table") && (response as { ok?: boolean }).ok === true) {
						publishPingSample(elapsedMs, true);
					}
				});
				latencyProbeWorkers.add(probeWorker);
				const scheduledTimeout: thread = task.delay(4, () => {
					latencyTimeoutWorkers.delete(scheduledTimeout);
					if (generation !== latencyGeneration || serial !== probeSerial || !probeInFlight) {
						return;
					}
					probeSerial += 1;
					probeInFlight = false;
				});
				timeoutWorker = scheduledTimeout;
				latencyTimeoutWorkers.add(scheduledTimeout);
			}
			task.wait(needsFallback ? 2.5 : 5);
		}
		if (generation === latencyGeneration) {
			latencyWorker = undefined;
		}
	});
}

export function watchPing(remote: RequestFunction, action = "MeasureLatency"): () => void {
	let stopped = false;
	const disconnect = () => {
		if (stopped) {
			return;
		}
		stopped = true;
		if (latencyRemote !== remote || latencyAction !== action) {
			return;
		}
		stopLatencyWorker();
		latencyRemote = undefined;
		latencyAction = undefined;
	};
	if (latencyRemote !== remote || latencyAction !== action) {
		stopLatencyWorker();
		latencyRemote = remote;
		latencyAction = action;
		startLatencyWorker();
	}
	return disconnect;
}

function median(values: ReadonlyArray<number>): number | undefined {
	if (values.size() === 0) {
		return undefined;
	}
	const sorted = [...values];
	sorted.sort((a, b) => a < b);
	return sorted[math.floor((sorted.size() - 1) / 2)];
}

function medianAbsoluteDeviation(values: ReadonlyArray<number>, center: number | undefined): number | undefined {
	if (values.size() === 0 || center === undefined) {
		return undefined;
	}
	return median(values.map((value) => math.abs(value - center)));
}

function sortScratch(count: number) {
	for (let index = 1; index < count; index++) {
		const value = scratch[index];
		let slot = index;
		while (slot > 0 && scratch[slot - 1] > value) {
			scratch[slot] = scratch[slot - 1];
			slot -= 1;
		}
		scratch[slot] = value;
	}
}

function percentile(count: number, p: number): number {
	if (count <= 0) {
		return 1 / 60;
	}
	const index = math.clamp(math.floor((count - 1) * p + 0.5), 0, count - 1);
	return scratch[index];
}

let lastGuardSweepAt = 0;

function trimWorkers(workers: Set<thread>) {
	if (workers.size() <= 6) {
		return;
	}
	let index = 0;
	for (const worker of [...workers]) {
		if (index >= 6) {
			workers.delete(worker);
			pcall(() => task.cancel(worker));
		}
		index += 1;
	}
}

function sweepRuntimeGuards() {
	const now = os.clock();
	if (now - lastGuardSweepAt < 4) {
		return;
	}
	lastGuardSweepAt = now;
	while (pingHistory.size() > 7) {
		pingHistory.shift();
	}
	trimWorkers(latencyProbeWorkers);
	trimWorkers(latencyTimeoutWorkers);
	if (cachedPingItem !== undefined && cachedPingItem.Parent === undefined) {
		cachedPingItem = undefined;
	}
}

function startTelemetry() {
	if (telemetryConnection !== undefined) {
		return;
	}
	let elapsed = 0;
	const tight = constrainedDevice();
	const sampleSeconds = tight ? 0.48 : SAMPLE_SECONDS;
	const jankThreshold = tight ? 1 / 30 : 1 / 36;
	const hitchThreshold = tight ? 0.04 : 0.032;
	const signal = tight ? RunService.Heartbeat : RunService.RenderStepped;
	telemetryConnection = signal.Connect((deltaTime: number) => {
		const clamped = math.clamp(deltaTime, 0.001, 0.12);
		frames[frameWrite] = clamped;
		frameWrite = (frameWrite + 1) % FRAME_RING;
		if (frameFilled < FRAME_RING) {
			frameFilled += 1;
		}
		elapsed += clamped;
		if (elapsed < sampleSeconds) {
			return;
		}
		elapsed = 0;
		const count = frameFilled;
		for (let index = 0; index < count; index++) {
			const ring = (frameWrite - count + index + FRAME_RING) % FRAME_RING;
			scratch[index] = frames[ring];
		}
		sortScratch(count);
		let total = 0;
		let jankFrames = 0;
		let hitchFrames = 0;
		for (let index = 0; index < count; index++) {
			const time = scratch[index];
			total += time;
			if (time > jankThreshold) {
				jankFrames += 1;
			}
			if (time > hitchThreshold) {
				hitchFrames += 1;
			}
		}
		const mean = total / math.max(count, 1);
		const rawFps = 1 / math.max(mean, 0.001);
		const p50 = percentile(count, 0.5);
		const p95 = percentile(count, 0.95);
		const p99 = percentile(count, 0.99);
		const livePing = enginePingMs();
		if (livePing !== undefined) {
			publishPingSample(livePing);
		}
		const stablePing = median(pingHistory);
		latestTelemetry = {
			fps: rawFps,
			lowFps: math.min(rawFps, 1 / math.max(p95, 1 / 240)),
			frameTimeMs: mean * 1000,
			p50FrameTimeMs: p50 * 1000,
			p95FrameTimeMs: p95 * 1000,
			p99FrameTimeMs: p99 * 1000,
			worstFrameMs: scratch[count - 1] * 1000,
			jankRatio: jankFrames / math.max(count, 1),
			hitchScore: hitchFrames / math.max(count, 1),
			pingMs: stablePing,
			pingJitterMs: medianAbsoluteDeviation(pingHistory, stablePing),
			sampledAt: os.clock(),
		};
		recordPerformanceTelemetry(latestTelemetry);
		sweepRuntimeGuards();
		for (const listener of telemetryListeners) {
			listener(latestTelemetry);
		}
	});
}

function stopTelemetryIfIdle() {
	if (telemetryListeners.size() > 0 || telemetryConnection === undefined) {
		return;
	}
	telemetryConnection.Disconnect();
	telemetryConnection = undefined;
}

function subscribeTelemetry(listener: TelemetryListener): () => void {
	telemetryListeners.add(listener);
	listener(latestTelemetry);
	startTelemetry();
	startLatencyWorker();
	return () => {
		telemetryListeners.delete(listener);
		stopTelemetryIfIdle();
		if (telemetryListeners.size() === 0) {
			stopLatencyWorker();
		}
	};
}

export function usePerformanceTelemetry(): Telemetry {
	const [sample, setSample] = React.useState(latestTelemetry);
	React.useEffect(() => subscribeTelemetry((latest) => setSample(latest)), []);
	return sample;
}

export interface AntilagInfo extends TierProfile {
	fps: number;
	pressure: number;
	hitchScore: number;
	constrained: boolean;
	/** window in the background, UI hidden: decorative work is stopped */
	suspended: boolean;
}

// ---- the engine -------------------------------------------------------------------------------------
// One governor for the whole client. Providers only subscribe to what it publishes; the telemetry loop runs
// while at least one provider is mounted. The governor drops a tier on the first bad window and climbs back
// only after a long clean stretch (see Shared/AntilagGovernor).

const governor = new Governor(IS_CONSTRAINED, IS_CONSTRAINED ? 1 : 2);
let ceilingPreference = TIER_MAX;
let ceilingScene = TIER_MAX;
const suspendKeys = new Set<string>();
const infoListeners = new Set<(info: AntilagInfo) => void>();

function applyCeiling() {
	const device = IS_CONSTRAINED ? 2 : TIER_MAX;
	governor.setCeiling(math.min(device, ceilingPreference, ceilingScene));
}
applyCeiling();

function buildInfo(fps: number, hitchScore: number): AntilagInfo {
	const profile = profileFor(governor.tier, IS_CONSTRAINED);
	return {
		...profile,
		fps,
		pressure: math.clamp(1 - governor.tier / TIER_MAX + hitchScore * 0.5, 0, 1),
		hitchScore: math.clamp(hitchScore, 0, 1),
		constrained: IS_CONSTRAINED,
		suspended: suspendKeys.size() > 0,
	};
}

const DEFAULT_INFO = buildInfo(IS_CONSTRAINED ? 48 : 60, 0);
export const AntilagContext = React.createContext<AntilagInfo>(DEFAULT_INFO);
let latestAntilagInfo: AntilagInfo = DEFAULT_INFO;
setLive(DEFAULT_INFO, DEFAULT_INFO.suspended);

function publish(info: AntilagInfo) {
	latestAntilagInfo = info;
	setLive(info, info.suspended);
	for (const listener of infoListeners) {
		listener(info);
	}
}

function evaluate(sample: Telemetry) {
	const before = governor.tier;
	const verdict = governor.update(
		{
			fps: sample.fps,
			p95Ms: sample.p95FrameTimeMs,
			p99Ms: sample.p99FrameTimeMs,
			worstMs: sample.worstFrameMs,
			jank: sample.jankRatio,
			hitch: sample.hitchScore,
		},
		os.clock(),
	);
	if (RunService.IsStudio()) {
		// Studio readout of what the governor is thinking (read it with execute_luau)
		game.GetService("ReplicatedStorage").SetAttribute(
			"AstralAntilagDebug",
			`tier ${governor.tier} ${governor.lastHealth} clean ${math.floor(governor.cleanTime * 10) / 10}s backoff ${governor.backoff} fps ${math.floor(sample.fps)} p95 ${math.floor(sample.p95FrameTimeMs)}ms`,
		);
	}
	if (!verdict.changed && governor.tier === latestAntilagInfo.tier) {
		return;
	}
	publish(buildInfo(sample.fps, sample.hitchScore));
	ClientLog.info("perf", `antilag tier ${before} -> ${verdict.tier}`, {
		Reason: verdict.reason ?? "",
		Fps: math.floor(sample.fps),
		P95Ms: math.floor(sample.p95FrameTimeMs),
		Panic: verdict.panic,
		Backoff: governor.backoff,
	});
}

/** Holds the UI quiet while `key` is set: the window is in the background, or the interface is hidden. */
export function setAntilagSuspended(key: string, on: boolean) {
	const had = suspendKeys.has(key);
	if (on === had) {
		return;
	}
	if (on) {
		suspendKeys.add(key);
	} else {
		suspendKeys.delete(key);
		// frames right after a resume are long ones that say nothing about the hardware
		governor.grace(os.clock() + 2.5);
	}
	publish(buildInfo(latestAntilagInfo.fps, latestAntilagInfo.hitchScore));
}

export function setAntilagScene(scene: string) {
	// the scene never raises the tier, it only lowers the ceiling the governor may climb to
	ceilingScene = scene === "normal" ? TIER_MAX : 2;
	applyCeiling();
	evaluate(latestTelemetry);
}

let activeMode: PerformanceMode | undefined;
let measuredTier: number | undefined;

export function setAntilagPreference(bias: number) {
	const mode = performanceModeFor(math.clamp(bias, 0, 1));
	if (mode === activeMode) {
		return;
	}
	activeMode = mode;
	const bounds = boundsForMode(mode);
	ceilingPreference = bounds.ceiling;
	applyCeiling();
	governor.setFloor(math.min(bounds.floor, governor.ceiling));
	const start = bounds.trustCeiling ? governor.ceiling : math.min(measuredTier ?? governor.tier, governor.ceiling);
	if (start !== governor.tier) {
		governor.force(start, os.clock());
	}
	evaluate(latestTelemetry);
	publish(buildInfo(latestAntilagInfo.fps, latestAntilagInfo.hitchScore));
}

export function seedAntilagFromDevice(device: DeviceProfile): number {
	const tier = tierForDevice({ ...device, fps: math.clamp(device.fps, 8, 120), constrained: IS_CONSTRAINED });
	measuredTier = tier;
	const start = activeMode !== undefined && boundsForMode(activeMode).trustCeiling ? governor.ceiling : tier;
	governor.force(math.clamp(start, governor.floor, governor.ceiling), os.clock());
	// the loading screen closing and the whole interface mounting is a few long frames, not the hardware
	governor.grace(os.clock() + 9);
	publish(buildInfo(device.fps, 0));
	return governor.tier;
}

export function clampAntilagTier(info: AntilagInfo, maxTier: number): AntilagInfo {
	if (info.tier <= maxTier) {
		return info;
	}
	return { ...info, ...profileFor(maxTier, info.constrained) };
}

let providerCount = 0;
let engineStop: (() => void) | undefined;

function startEngine() {
	const stops = new Array<() => void>();
	// the first mount of the whole interface is one long stall that says nothing about the machine
	governor.grace(os.clock() + 6);
	stops.push(subscribeTelemetry(evaluate));
	if (!RunService.IsStudio()) {
		// a backgrounded window keeps nothing animating
		const released = UserInputService.WindowFocusReleased.Connect(() => setAntilagSuspended("focus", true));
		const focused = UserInputService.WindowFocused.Connect(() => setAntilagSuspended("focus", false));
		stops.push(() => {
			released.Disconnect();
			focused.Disconnect();
		});
	} else {
		// Studio only: ReplicatedStorage.AstralDevAntilag = 0..3 pins a tier (anything else frees it), and
		// AstralDevLag = N burns N ms of every frame, so the governor can be watched reacting to a slow machine
		const storage = game.GetService("ReplicatedStorage");
		const apply = () => {
			const pin = storage.GetAttribute("AstralDevAntilag");
			governor.setPin(typeIs(pin, "number") && pin >= 0 && pin <= TIER_MAX ? pin : undefined);
			evaluate(latestTelemetry);
		};
		apply();
		const pinned = storage.GetAttributeChangedSignal("AstralDevAntilag").Connect(apply);
		const burn = RunService.RenderStepped.Connect(() => {
			const ms = storage.GetAttribute("AstralDevLag");
			if (typeIs(ms, "number") && ms > 0) {
				const stopAt = os.clock() + ms / 1000;
				while (os.clock() < stopAt) {
					// busy on purpose
				}
			}
		});
		stops.push(() => {
			pinned.Disconnect();
			burn.Disconnect();
		});
	}
	engineStop = () => {
		for (const stop of stops) {
			stop();
		}
	};
}

function acquireEngine(): () => void {
	providerCount += 1;
	if (providerCount === 1) {
		startEngine();
	}
	let released = false;
	return () => {
		if (released) {
			return;
		}
		released = true;
		providerCount = math.max(0, providerCount - 1);
		if (providerCount === 0 && engineStop !== undefined) {
			engineStop();
			engineStop = undefined;
		}
	};
}

export function AntilagProvider(props: { children?: React.ReactNode }) {
	const [info, setInfo] = React.useState<AntilagInfo>(latestAntilagInfo);
	React.useEffect(() => {
		const release = acquireEngine();
		infoListeners.add(setInfo);
		setInfo(latestAntilagInfo);
		return () => {
			infoListeners.delete(setInfo);
			release();
		};
	}, []);
	return <AntilagContext.Provider value={info}>{props.children}</AntilagContext.Provider>;
}

export function currentAntilagInfo(): AntilagInfo {
	return latestAntilagInfo;
}

export function useAntilag(): AntilagInfo {
	return React.useContext(AntilagContext);
}
