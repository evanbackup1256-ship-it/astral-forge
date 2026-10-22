// Offline progress: what a player earned while away.
//
// Pure and deterministic. No services, no clock, no profile access: the caller passes the times,
// the limits and a sampler that reports production and efficiency at a moment. That keeps it
// testable in Lune and lets the server and the client preview share one implementation.
//
// The away window is clamped to the cap, then cut into segments at every anomaly cycle edge and
// at the moments a boost or surge ends, since production is flat inside each piece. Each segment
// is sampled once at its midpoint.

export interface OfflineLimits {
	/** longest away time that pays, in seconds */
	maxSeconds: number;
	/** shorter absences pay nothing */
	minSeconds: number;
	/** anomaly cycle length; production can change on every edge */
	cycleSeconds: number;
	/** when the active boost ends (0 when none) */
	boostEndsAt: number;
	/** when the anomaly surge ends (0 when none) */
	surgeEndsAt: number;
}

export interface OfflineSegment {
	from: number;
	to: number;
	/** the moment the segment is sampled at (its midpoint) */
	at: number;
}

export interface OfflineWindow {
	/** seconds that pay, after the cap */
	elapsed: number;
	/** true when the player was away longer than the cap */
	capped: boolean;
	/** empty when elapsed is under minSeconds */
	segments: OfflineSegment[];
}

export interface OfflineSample<T> {
	production: T;
	efficiency: number;
}

export interface OfflineNumeric<T> {
	zero: T;
	add: (this: void, a: T, b: T) => T;
	scale: (this: void, value: T, factor: number) => T;
}

export interface OfflineResult<T> {
	reward: T;
	elapsed: number;
	/** time-weighted average efficiency over the paid window */
	efficiency: number;
	capped: boolean;
}

/** Cut the away window into flat-production segments. */
export function planWindow(startedAt: number, endedAt: number, limits: OfflineLimits): OfflineWindow {
	const away = math.max(0, endedAt - startedAt);
	const maximum = math.max(0, limits.maxSeconds);
	const elapsed = math.min(away, maximum);
	const capped = away > maximum;
	if (elapsed <= 0 || elapsed < limits.minSeconds) {
		return { elapsed, capped, segments: [] };
	}

	const from = startedAt;
	const to = startedAt + elapsed;
	const edges: number[] = [from, to];
	const cycle = math.max(1, limits.cycleSeconds);
	for (let edge = (math.floor(from / cycle) + 1) * cycle; edge < to; edge += cycle) {
		edges.push(edge);
	}
	for (const edge of [limits.boostEndsAt, limits.surgeEndsAt]) {
		if (edge > from && edge < to) {
			edges.push(edge);
		}
	}
	table.sort(edges, (a, b) => a < b);

	const segments: OfflineSegment[] = [];
	for (let i = 0; i < edges.size() - 1; i++) {
		const left = edges[i];
		const right = edges[i + 1];
		if (right > left) {
			segments.push({ from: left, to: right, at: left + (right - left) * 0.5 });
		}
	}
	return { elapsed, capped, segments };
}

/** Sum production x efficiency x duration over every segment. */
export function project<T>(
	startedAt: number,
	endedAt: number,
	limits: OfflineLimits,
	sampleAt: (this: void, at: number) => OfflineSample<T>,
	numeric: OfflineNumeric<T>,
): OfflineResult<T> {
	const window = planWindow(startedAt, endedAt, limits);
	let reward = numeric.zero;
	let weighted = 0;
	for (const segment of window.segments) {
		const duration = segment.to - segment.from;
		const sample = sampleAt(segment.at);
		const efficiency = math.max(0, sample.efficiency);
		reward = numeric.add(reward, numeric.scale(sample.production, efficiency * duration));
		weighted += efficiency * duration;
	}
	const paid = window.segments.size() > 0;
	return {
		reward,
		elapsed: window.elapsed,
		efficiency: paid ? weighted / window.elapsed : 0,
		capped: window.capped,
	};
}

/** Short away-time label used in toasts: 45s, 12m, 3h. */
export function formatAway(seconds: number): string {
	if (seconds >= 3600) {
		return string.format("%.0fh", seconds / 3600);
	}
	if (seconds >= 60) {
		return string.format("%.0fm", seconds / 60);
	}
	return string.format("%.0fs", math.max(0, seconds));
}
