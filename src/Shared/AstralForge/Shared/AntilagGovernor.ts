// Purpose: the antilag governor. Decides which performance tier the UI runs at from frame-time windows, and
// says what each tier switches off. Pure (no Roblox services) so scripts/verify_antilag.luau can drive it
// with made-up frames.
// Owner: Astral Forge presentation. Last-reviewed: 2026-10-31 (antilag revamp).
//
// Tiers: 3 full, 2 trimmed, 1 lean, 0 minimal. The governor drops FAST (one bad window is enough, two tiers
// on a collapse) and climbs SLOWLY: a tier is only regained after a stretch of clean windows, and every time
// it drops soon after a climb the stretch doubles (flap protection) until things have been calm for a while.

export const TIER_MIN = 0;
export const TIER_MAX = 3;

/** One measured window of frames (the last ~second, refreshed several times a second). */
export interface FrameWindow {
	fps: number;
	p95Ms: number;
	p99Ms: number;
	worstMs: number;
	/** share of frames over the jank line, 0..1 */
	jank: number;
	/** share of frames over the hitch line, 0..1 */
	hitch: number;
}

/** Everything a tier switches on or off. Numbers shrink with the tier; booleans turn off. */
export interface TierProfile {
	tier: number;
	/** 0..1, kept for the older callers that think in a quality score */
	quality: number;
	fxBudget: number;
	particleBudget: number;
	glowScale: number;
	allowAmbient: boolean;
	allowConfetti: boolean;
	skipEntrance: boolean;
	maxClocks: number;
	maxPops: number;
	maxStars: number;
	/** how often decorative clocks (shimmers, drifting stars, pulses) are allowed to tick */
	clockHz: number;
	/** the dark second copy behind every Text */
	textShadows: boolean;
	/** button and panel shimmer sweeps, idle glints */
	shimmer: boolean;
	/** panels and page sections rising into place */
	entrance: boolean;
	/** live 3D viewports (avatars) */
	viewports: boolean;
	/** multiplies spring stiffness so springs settle sooner and stop costing frames */
	springGain: number;
	/** milliseconds per frame the layout guard may use */
	layoutBudgetMs: number;
	/** multiplies the gap between passive state repaints */
	paintScale: number;
}

const PROFILES: ReadonlyArray<TierProfile> = table.freeze([
	table.freeze({
		tier: 0, quality: 0.1, fxBudget: 0.04, particleBudget: 0, glowScale: 0.05,
		allowAmbient: false, allowConfetti: false, skipEntrance: true, maxClocks: 2, maxPops: 1, maxStars: 0,
		clockHz: 8, textShadows: false, shimmer: false, entrance: false, viewports: false,
		springGain: 3.4, layoutBudgetMs: 0.08, paintScale: 3.2,
	}),
	table.freeze({
		tier: 1, quality: 0.32, fxBudget: 0.2, particleBudget: 2, glowScale: 0.3,
		allowAmbient: false, allowConfetti: false, skipEntrance: true, maxClocks: 3, maxPops: 1, maxStars: 0,
		clockHz: 16, textShadows: false, shimmer: false, entrance: false, viewports: false,
		springGain: 2, layoutBudgetMs: 0.2, paintScale: 2,
	}),
	table.freeze({
		tier: 2, quality: 0.6, fxBudget: 0.5, particleBudget: 6, glowScale: 0.6,
		allowAmbient: true, allowConfetti: true, skipEntrance: false, maxClocks: 6, maxPops: 2, maxStars: 2,
		clockHz: 30, textShadows: true, shimmer: true, entrance: true, viewports: true,
		springGain: 1.15, layoutBudgetMs: 0.35, paintScale: 1.25,
	}),
	table.freeze({
		tier: 3, quality: 0.92, fxBudget: 0.8, particleBudget: 12, glowScale: 0.86,
		allowAmbient: true, allowConfetti: true, skipEntrance: false, maxClocks: 10, maxPops: 4, maxStars: 5,
		clockHz: 60, textShadows: true, shimmer: true, entrance: true, viewports: true,
		springGain: 1, layoutBudgetMs: 0.5, paintScale: 1,
	}),
]);

export function profileFor(tier: number, constrained = false): TierProfile {
	const base = PROFILES[math.clamp(math.floor(tier), TIER_MIN, TIER_MAX)];
	if (!constrained) {
		return base;
	}
	// phones and pads: fewer particles, slower ambient clocks, smaller budgets at every tier
	return {
		...base,
		fxBudget: base.fxBudget * 0.7,
		particleBudget: math.floor(base.particleBudget * 0.6),
		glowScale: base.glowScale * 0.8,
		maxClocks: math.max(2, base.maxClocks - 2),
		maxStars: math.floor(base.maxStars * 0.6),
		clockHz: math.min(base.clockHz, 30),
		layoutBudgetMs: base.layoutBudgetMs * 0.8,
	};
}

/** the tier a boot-time frame rate measurement starts the session at */
export function tierForBootFps(fps: number, constrained: boolean): number {
	const tier = fps < 22 ? 0 : fps < 38 ? 1 : fps < 54 ? 2 : 3;
	return constrained ? math.min(tier, 2) : tier;
}

/** What the loading screen measures in its tuning second. */
export interface DeviceProfile {
	fps: number;
	p95Ms: number;
	pingMs: number;
	memoryMb: number;
	/** the player's Roblox graphics slider, 1..10, or 0 when it is on Automatic */
	graphics: number;
	constrained: boolean;
}

export function tierForDevice(device: DeviceProfile): number {
	let tier = tierForBootFps(device.fps, device.constrained);
	if (device.p95Ms > 45) {
		tier -= 1;
	}
	if (device.memoryMb > (device.constrained ? 1500 : 3200)) {
		tier -= 1;
	}
	if (device.pingMs > 280) {
		tier = math.min(tier, 2);
	}
	if (device.graphics > 0) {
		tier = math.min(tier, device.graphics <= 3 ? 1 : device.graphics <= 6 ? 2 : TIER_MAX);
	}
	return math.clamp(tier, TIER_MIN, TIER_MAX);
}

export type PerformanceMode = "auto" | "good" | "bad" | "potato";

/** PerformanceBias is saved as a number: Good 0, Auto 0.5, Bad 0.75, Potato 1 */
export function performanceModeFor(bias: number): PerformanceMode {
	return bias >= 0.88 ? "potato" : bias >= 0.62 ? "bad" : bias <= 0.12 ? "good" : "auto";
}

export interface ModeBounds {
	ceiling: number;
	floor: number;
	/** start at the ceiling instead of the measured tier */
	trustCeiling: boolean;
}

export function boundsForMode(mode: PerformanceMode): ModeBounds {
	if (mode === "potato") {
		return { ceiling: TIER_MIN, floor: TIER_MIN, trustCeiling: true };
	}
	if (mode === "bad") {
		return { ceiling: 1, floor: TIER_MIN, trustCeiling: true };
	}
	if (mode === "good") {
		return { ceiling: TIER_MAX, floor: 1, trustCeiling: true };
	}
	return { ceiling: TIER_MAX, floor: TIER_MIN, trustCeiling: false };
}

export function ceilingForPreference(bias: number): number {
	return boundsForMode(performanceModeFor(bias)).ceiling;
}

export interface Verdict {
	tier: number;
	changed: boolean;
	panic: boolean;
	reason?: string;
}

interface Limits {
	fpsBad: number;
	fpsGood: number;
	p95Bad: number;
	p95Good: number;
	hitchBad: number;
	hitchGood: number;
}

const DESKTOP: Limits = { fpsBad: 40, fpsGood: 55, p95Bad: 34, p95Good: 21, hitchBad: 0.14, hitchGood: 0.04 };
const TOUCH: Limits = { fpsBad: 30, fpsGood: 42, p95Bad: 48, p95Good: 30, hitchBad: 0.18, hitchGood: 0.06 };

// seconds of clean windows needed before climbing from tier n to n + 1 (scaled by the flap backoff)
const CLIMB_AFTER = [5, 8, 12];
const DROP_GAP = 0.6;
const HOLD_AFTER_DROP = 2.5;
const HOLD_AFTER_PANIC = 5;
const FLAP_WINDOW = 25;
// drops closer together than this are one slow spell, however many tiers it costs
const INCIDENT_GAP = 4;
const CALM_AFTER = 60;
const MAX_BACKOFF = 8;

export class Governor {
	tier: number;
	ceiling = TIER_MAX;
	floor = TIER_MIN;
	pinned: number | undefined = undefined;
	backoff = 1;
	private readonly limits: Limits;
	private lastChangeAt = -math.huge;
	private lastDropAt = -math.huge;
	private lastRiseAt = -math.huge;
	private holdUntil = 0;
	private graceUntil = 0;
	/** seconds of clean running banked toward the next climb: it grows on good windows, drains slowly on middling ones, empties on bad ones */
	cleanTime = 0;
	/** the last window's verdict, for the debug readout */
	lastHealth = "-";
	private lastAt: number | undefined = undefined;
	private calmMark = 0;

	constructor(constrained: boolean, startTier: number) {
		this.limits = constrained ? TOUCH : DESKTOP;
		this.tier = math.clamp(math.floor(startTier), TIER_MIN, TIER_MAX);
	}

	setCeiling(ceiling: number) {
		this.ceiling = math.clamp(math.floor(ceiling), TIER_MIN, TIER_MAX);
	}

	setFloor(floor: number) {
		this.floor = math.clamp(math.floor(floor), TIER_MIN, TIER_MAX);
	}

	setPin(tier: number | undefined) {
		this.pinned = tier === undefined ? undefined : math.clamp(math.floor(tier), TIER_MIN, TIER_MAX);
	}

	/** windows measured before `endsAt` are ignored: loading, a resume from the background, a window resize */
	grace(endsAt: number) {
		this.graceUntil = math.max(this.graceUntil, endsAt);
		this.cleanTime = 0;
	}

	/** jump to a tier (boot measurement); the climb clock starts over */
	force(tier: number, now: number) {
		this.tier = math.clamp(math.floor(tier), TIER_MIN, TIER_MAX);
		this.cleanTime = 0;
		this.lastChangeAt = now;
		this.holdUntil = now + 1;
	}

	private classify(window: FrameWindow): "bad" | "good" | "mid" {
		const limits = this.limits;
		if (window.fps < limits.fpsBad || window.p95Ms > limits.p95Bad || window.hitch > limits.hitchBad) {
			return "bad";
		}
		if (window.fps >= limits.fpsGood && window.p95Ms <= limits.p95Good && window.hitch <= limits.hitchGood && window.worstMs < 120) {
			return "good";
		}
		return "mid";
	}

	private move(target: number, now: number): boolean {
		const clamped = math.clamp(target, math.max(TIER_MIN, this.floor), math.min(TIER_MAX, this.ceiling));
		if (clamped === this.tier) {
			return false;
		}
		this.tier = clamped;
		this.lastChangeAt = now;
		return true;
	}

	update(window: FrameWindow, now: number): Verdict {
		const elapsed = this.lastAt === undefined ? 0 : math.clamp(now - this.lastAt, 0, 1);
		this.lastAt = now;
		if (this.pinned !== undefined) {
			const changed = this.tier !== this.pinned;
			this.tier = this.pinned;
			return { tier: this.tier, changed, panic: false, reason: changed ? "pinned" : undefined };
		}
		// a lowered ceiling (Speed priority, a heavy scene) applies at once
		if (this.tier > this.ceiling) {
			this.move(this.ceiling, now);
			this.cleanTime = 0;
			return { tier: this.tier, changed: true, panic: false, reason: "ceiling" };
		}
		if (now < this.graceUntil) {
			return { tier: this.tier, changed: false, panic: false };
		}
		// long calm stretches forgive past flapping
		if (now - math.max(this.lastDropAt, this.lastRiseAt, this.calmMark) > CALM_AFTER && this.backoff > 1) {
			this.backoff = math.max(1, this.backoff / 2);
			this.calmMark = now;
		}
		const panic = window.fps < 20 || window.worstMs >= 300;
		if (panic) {
			this.lastHealth = "panic";
			this.cleanTime = 0;
			this.holdUntil = now + HOLD_AFTER_PANIC;
			const changed = this.move(this.tier - 2, now);
			if (changed) {
				this.noteDrop(now);
			}
			return { tier: this.tier, changed, panic: true, reason: changed ? "panic" : undefined };
		}
		const health = this.classify(window);
		this.lastHealth = health;
		if (health === "bad") {
			this.cleanTime = 0;
			if (this.tier > math.max(TIER_MIN, this.floor) && now - this.lastChangeAt >= DROP_GAP) {
				this.move(this.tier - 1, now);
				this.holdUntil = now + HOLD_AFTER_DROP;
				this.noteDrop(now);
				return { tier: this.tier, changed: true, panic: false, reason: "slow frames" };
			}
			return { tier: this.tier, changed: false, panic: false };
		}
		if (health === "mid") {
			// a window that is merely OK costs some banked time, it does not wipe it (real devices jitter)
			this.cleanTime = math.max(0, this.cleanTime - elapsed * 0.6);
			return { tier: this.tier, changed: false, panic: false };
		}
		this.cleanTime += elapsed;
		const ceiling = math.min(TIER_MAX, this.ceiling);
		if (this.tier < ceiling && now >= this.holdUntil) {
			const need = CLIMB_AFTER[this.tier] * this.backoff;
			if (this.cleanTime >= need) {
				this.move(this.tier + 1, now);
				this.lastRiseAt = now;
				this.cleanTime = 0;
				return { tier: this.tier, changed: true, panic: false, reason: "steady" };
			}
		}
		return { tier: this.tier, changed: false, panic: false };
	}

	private noteDrop(now: number) {
		// only the first drop of a spell, soon after a climb, counts as flapping
		if (now - this.lastDropAt > INCIDENT_GAP && now - this.lastRiseAt <= FLAP_WINDOW) {
			this.backoff = math.min(MAX_BACKOFF, this.backoff * 2);
		}
		this.lastDropAt = now;
	}
}
