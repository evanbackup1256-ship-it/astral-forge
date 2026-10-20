import type { RequestFunction } from "../ClientNetwork";
import React from "@rbxts/react";
import { ClientLog, QualitySample, recordPerformanceTelemetry } from "../CoreKit/log";
import { setClockBudget, setContinuousMotionRate } from "./motion";

const RunService = game.GetService("RunService");
const Stats = game.GetService("Stats");
const UserInputService = game.GetService("UserInputService");

export function constrainedDevice(): boolean {
	if (UserInputService.TouchEnabled && !UserInputService.MouseEnabled) {
		return true;
	}
	if (UserInputService.GamepadEnabled && !UserInputService.KeyboardEnabled && !UserInputService.MouseEnabled) {
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
let liveScene = "normal";
let livePreference = IS_CONSTRAINED ? 0.62 : 0.42;
const sceneListeners = new Array<() => void>();

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
type BootSeedListener = (quality: number, fps: number) => void;
const bootSeedListeners = new Array<BootSeedListener>();

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
	if (bootSeedListeners.size() > 8) {
		while (bootSeedListeners.size() > 4) {
			bootSeedListeners.shift();
		}
	}
	if (sceneListeners.size() > 8) {
		while (sceneListeners.size() > 4) {
			sceneListeners.shift();
		}
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

export interface AntilagInfo {
	fps: number;
	tier: number;
	quality: number;
	pressure: number;
	hitchScore: number;
	frameBudgetMs: number;
	fxBudget: number;
	particleBudget: number;
	titleGlyphLimit: number;
	renderRate: number;
	glowScale: number;
	allowAmbient: boolean;
	allowConfetti: boolean;
	skipEntrance: boolean;
	freezeIcons: boolean;
	maxClocks: number;
	maxPops: number;
	maxStars: number;
	constrained: boolean;
}

function infoFromQuality(quality: number, fps: number, pressure: number, hitchScore: number): AntilagInfo {
	const q = math.clamp(quality, 0, 1);
	const tight = IS_CONSTRAINED;
	const qEff = tight ? math.min(q, 0.78) : q;
	const tier = qEff < 0.2 ? 0 : qEff < 0.44 ? 1 : qEff < 0.7 ? 2 : 3;
	const fxBudget = math.clamp(0.05 + qEff * (tight ? 0.28 : 0.34) + qEff * qEff * (tight ? 0.12 : 0.18), 0.05, tight ? 0.52 : 0.7);
	const renderRate = math.clamp(math.floor((tight ? 12 : 16) + qEff * (tight ? 28 : 34) + 0.5), tight ? 12 : 16, tight ? 42 : 56);
	return {
		fps,
		tier,
		quality: q,
		pressure: math.clamp(pressure, 0, 1),
		hitchScore: math.clamp(hitchScore, 0, 1),
		frameBudgetMs: 1000 / renderRate,
		fxBudget,
		particleBudget: math.clamp(math.floor(1 + (tight ? 8 : 12) * qEff + 0.5), 1, tight ? 9 : 14),
		titleGlyphLimit: tight ? 12 : 18,
		renderRate,
		glowScale: math.clamp(0.08 + qEff * (tight ? 0.52 : 0.72), 0.08, tight ? 0.62 : 0.86),
		allowAmbient: true,
		allowConfetti: qEff >= (tight ? 0.42 : 0.34),
		skipEntrance: false,
		freezeIcons: false,
		maxClocks: math.clamp(math.floor((tight ? 2 : 3) + (tight ? 6 : 8) * qEff + 0.5), tight ? 2 : 3, tight ? 8 : 12),
		maxPops: math.clamp(math.floor(1 + (tight ? 2 : 3) * qEff + 0.5), 1, tight ? 3 : 4),
		maxStars: qEff < (tight ? 0.5 : 0.42) ? 0 : math.clamp(math.floor(qEff * (tight ? 3.5 : 5) + 0.5), 1, tight ? 3 : 5),
		constrained: tight,
	};
}

function tierCeiling(tier: number): number {
	if (tier === 0) {
		return 0.18;
	}
	if (tier === 1) {
		return 0.4;
	}
	if (tier === 2) {
		return 0.66;
	}
	return 1;
}

const DEFAULT_INFO = infoFromQuality(IS_CONSTRAINED ? 0.55 : 0.88, IS_CONSTRAINED ? 48 : 60, 0.2, 0);
export const AntilagContext = React.createContext<AntilagInfo>(DEFAULT_INFO);
let bootSeededQuality: number | undefined;
let bootSeededFps: number | undefined;

function sceneLoad(scene: string): number {
	if (scene === "cinematic") {
		return 0.38;
	}
	if (scene === "arcade") {
		return 0.28;
	}
	if (scene === "heavy") {
		return 0.16;
	}
	return 0;
}

function applyMotionRate(info: AntilagInfo) {
	const floor = IS_CONSTRAINED ? 18 : 24;
	const boost = IS_CONSTRAINED ? 32 : 40;
	const rate = info.tier >= 2 ? math.max(info.renderRate, boost) : math.max(floor, info.renderRate);
	setContinuousMotionRate(rate);
	setClockBudget(info.maxClocks);
}

export function setAntilagScene(scene: string) {
	if (liveScene === scene) {
		return;
	}
	liveScene = scene;
	for (const listener of sceneListeners) {
		listener();
	}
}

export function setAntilagPreference(bias: number) {
	const preferred = math.clamp(bias, 0, 1);
	if (math.abs(preferred - livePreference) < 0.01) {
		return;
	}
	livePreference = preferred;
	for (const listener of sceneListeners) {
		listener();
	}
}

export function seedAntilagFromBoot(fps: number): number {
	const measured = math.clamp(fps, 8, 120);
	bootSeededFps = measured;
	const raw = math.clamp((measured - 16) / 44, 0.12, 1);
	const motionFloor = IS_CONSTRAINED ? 0.4 : 0.48;
	const seeded = math.max(raw, motionFloor);
	const quality = IS_CONSTRAINED ? math.min(seeded, 0.74) : seeded;
	bootSeededQuality = quality;
	for (const listener of bootSeedListeners) {
		listener(quality, measured);
	}
	return quality < 0.2 ? 0 : quality < 0.44 ? 1 : quality < 0.7 ? 2 : 3;
}

export function clampAntilagTier(info: AntilagInfo, maxTier: number): AntilagInfo {
	if (info.tier <= maxTier) {
		return info;
	}
	return infoFromQuality(math.min(info.quality, tierCeiling(maxTier)), info.fps, info.pressure, info.hitchScore);
}

function scoreWindow(sample: Telemetry): number {
	const targetFps = IS_CONSTRAINED ? 45 : 58;
	const fpsScore = math.clamp(sample.fps / targetFps, 0, 1.15);
	const p95Score = math.clamp(1 - (sample.p95FrameTimeMs - (IS_CONSTRAINED ? 20 : 16)) / 48, 0, 1);
	const p99Score = math.clamp(1 - (sample.p99FrameTimeMs - (IS_CONSTRAINED ? 28 : 20)) / 70, 0, 1);
	const jankScore = 1 - math.clamp(sample.jankRatio * (IS_CONSTRAINED ? 1.4 : 1.7), 0, 1);
	const hitchPenalty = math.clamp(sample.hitchScore * (IS_CONSTRAINED ? 2.4 : 2.1), 0, 1);
	const pingPenalty = sample.pingMs !== undefined && sample.pingMs > 180 ? math.clamp((sample.pingMs - 180) / 500, 0, 0.16) : 0;
	const blended = fpsScore * 0.3 + p95Score * 0.28 + p99Score * 0.18 + jankScore * 0.24;
	return math.clamp(blended - hitchPenalty * 0.62 - pingPenalty, 0, 1);
}

let latestAntilagInfo: AntilagInfo = DEFAULT_INFO;

export function AntilagProvider(props: { children?: React.ReactNode }) {
	const startingQuality = bootSeededQuality ?? (IS_CONSTRAINED ? 0.55 : 0.88);
	const startingFps = bootSeededFps ?? (IS_CONSTRAINED ? 48 : 60);
	const [info, setInfo] = React.useState(() => infoFromQuality(startingQuality, startingFps, 0.2, 0));
	const infoRef = React.useRef(info);
	infoRef.current = info;
	latestAntilagInfo = info;

	React.useEffect(() => {
		const apply: BootSeedListener = (quality, fps) => {
			const seeded = infoFromQuality(quality, fps, 1 - quality, 0);
			infoRef.current = seeded;
			setInfo(seeded);
			applyMotionRate(seeded);
		};
		if (bootSeededQuality !== undefined) {
			apply(bootSeededQuality, bootSeededFps ?? 60);
		}
		bootSeedListeners.push(apply);
		return () => {
			const index = bootSeedListeners.indexOf(apply);
			if (index >= 0) {
				bootSeedListeners.remove(index);
			}
		};
	}, []);

	React.useEffect(() => {
		applyMotionRate(info);
		return () => setContinuousMotionRate(60);
	}, [info.renderRate, info.tier]);

	React.useEffect(() => {
		let quality = startingQuality;
		let lastLoggedTier = infoRef.current.tier;
		const TIER_DEBOUNCE_SECONDS = 1.5;
		const QUALITY_FLOOR = IS_CONSTRAINED ? 0.22 : 0.46;
		const SUSTAINED_BAD_SAMPLES = 3;
		const MAX_DROP = 0.24;
		let badSamples = 0;
		let pendingTier = lastLoggedTier;
		let pendingTierSince = os.clock();
		let lastRiseAt = 0;
		let lastDropAt = 0;
		let slope = 0;
		let previousScore = quality;
		let holdUntil = 0;
		let hitchStrikes = 0;
		let hitchHoldUntil = 0;
		const evaluateStartedAt = os.clock();
		const evaluate = (sample: Telemetry) => {
			const raw = scoreWindow(sample);
			slope = slope * 0.55 + (raw - previousScore) * 0.45;
			previousScore = raw;
			const scene = sceneLoad(liveScene);
			const prefer = livePreference * 0.48;
			const touchCeil = IS_CONSTRAINED ? 0.82 : 1;
			let target = math.clamp(raw - scene - prefer, 0.08, touchCeil);
			const now = os.clock();
			const warming = now - evaluateStartedAt < 1;
			if (warming) {
				target = math.max(target, quality);
			}
			const collapsed = !warming && (sample.fps < 40 || sample.p95FrameTimeMs >= 32);
			if (collapsed) {
				badSamples += 1;
				hitchStrikes += 1;
				hitchHoldUntil = now + 1.8;
			} else {
				badSamples = 0;
				hitchStrikes = math.max(0, hitchStrikes - 1);
				if (now >= hitchHoldUntil && sample.hitchScore < 0.05 && sample.fps >= 50) {
					hitchHoldUntil = now;
				}
			}
			if (sample.fps < 50 && !warming) {
				target = math.min(target, 0.22 + (sample.fps / 50) * 0.4);
			}
			if (warming) {
				target = math.max(target, quality);
			}
			const falling = target < quality - 0.02;
			const rising = target > quality + 0.05;
			if (falling && badSamples >= SUSTAINED_BAD_SAMPLES && now - lastDropAt >= 2) {
				quality = math.max(target, quality - MAX_DROP);
				lastDropAt = now;
				holdUntil = now + 3;
				badSamples = 0;
			} else if (rising && now >= holdUntil && now - lastDropAt >= 2.2 && now - lastRiseAt >= 1.1) {
				quality += (target - quality) * 0.08;
				lastRiseAt = now;
			} else if (!falling) {
				quality += (target - quality) * 0.02;
			}
			quality = math.clamp(quality, QUALITY_FLOOR, touchCeil);
			const pressure = math.clamp(1 - raw + scene + prefer, 0, 1);
			const scored = infoFromQuality(quality, sample.fps, pressure, sample.hitchScore);
			const published = infoRef.current;
			if (scored.tier === published.tier) {
				pendingTier = published.tier;
				pendingTierSince = now;
				applyMotionRate(scored);
				return;
			}
			if (pendingTier !== scored.tier) {
				pendingTier = scored.tier;
				pendingTierSince = now;
			}
			if (now - pendingTierSince < TIER_DEBOUNCE_SECONDS) {
				return;
			}
			applyMotionRate(scored);
			latestAntilagInfo = scored;
			infoRef.current = scored;
			setInfo(scored);
			if (scored.tier !== lastLoggedTier) {
				lastLoggedTier = scored.tier;
				ClientLog.debug("perf", `${math.floor(sample.fps)} fps, quality ${"%.2f".format(quality)}`);
			}
		};
		const onScene = () => evaluate(latestTelemetry);
		sceneListeners.push(onScene);
		const stop = subscribeTelemetry(evaluate);
		return () => {
			stop();
			const index = sceneListeners.indexOf(onScene);
			if (index >= 0) {
				sceneListeners.remove(index);
			}
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
