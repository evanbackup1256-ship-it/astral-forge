export const DEFAULT_TRAVEL = 2.4;
export const TRAIL_LAG = 0.035;
export const TRAIL_MIN_SCALE = 0.85;
export const SWEEP_SHARE = 0.6;

export function bell(halfWidth: number, peak: number, samples: number): NumberSequence {
	const points = [new NumberSequenceKeypoint(0, 1)];
	const low = 0.5 - halfWidth;
	points.push(new NumberSequenceKeypoint(low, 1));
	for (let i = 1; i <= samples - 1; i++) {
		const u = i / samples;
		const x = low + u * halfWidth * 2;
		const lit = (1 - math.cos(u * math.pi * 2)) * 0.5;
		points.push(new NumberSequenceKeypoint(x, 1 - (1 - peak) * lit));
	}
	points.push(new NumberSequenceKeypoint(0.5 + halfWidth, 1));
	points.push(new NumberSequenceKeypoint(1, 1));
	return new NumberSequence(points);
}

// 16 samples: the band's falloff reads as a curve, not a row of steps
export const GLINT = bell(0.17, 0.08, 16);
export const TRAIL = bell(0.3, 0.7, 16);

export const SWEEP_SPEED = 0.42;
export const ROTATION = 20;

export function clamp01(value: unknown): number {
	if (!typeIs(value, "number") || value !== value) {
		return 0;
	}
	if (value <= 0) {
		return 0;
	}
	if (value >= 1) {
		return 1;
	}
	return value;
}

export function sweepProgress(phase: unknown): number {
	let t = typeIs(phase, "number") && phase === phase ? phase : 0;
	t = t % 1;
	if (t < 0) {
		t += 1;
	}
	// quintic smootherstep: zero speed and zero acceleration at both ends, so the glint glides on
	// and off instead of snapping to a constant robotic speed
	const u = math.min(t / SWEEP_SHARE, 1);
	return u * u * u * (u * (u * 6 - 15) + 10);
}

export function offset(phase: unknown, travel: unknown = DEFAULT_TRAVEL, lag?: unknown): Vector2 {
	const span = typeIs(travel, "number") && travel === travel && travel > 0 ? travel : DEFAULT_TRAVEL;
	let t = typeIs(phase, "number") && phase === phase ? phase : 0;
	if (typeIs(lag, "number") && lag === lag) {
		t -= lag;
	}
	return new Vector2(sweepProgress(t) * span - span * 0.5, 0);
}

function scaleOf(shimmerScale: unknown): number {
	return clamp01(typeIs(shimmerScale, "number") ? shimmerScale : 1);
}

export function sweepSpeed(shimmerScale?: unknown): number {
	return SWEEP_SPEED * math.clamp(0.55 + scaleOf(shimmerScale) * 0.45, 0.55, 1);
}

export function surfaceStrength(hoverAmount: unknown, idle: boolean | undefined, shimmerScale?: unknown): number {
	const hoverStrength = clamp01(hoverAmount) * 0.4;
	const idleStrength = idle ? 0.12 : 0;
	return math.clamp(math.max(hoverStrength, idleStrength) * scaleOf(shimmerScale), 0, 0.5);
}

export function surfaceTransparency(hoverAmount: unknown, idle: boolean | undefined, shimmerScale?: unknown): number {
	return 1 - surfaceStrength(hoverAmount, idle, shimmerScale);
}

export function shouldShow(hoverAmount: unknown, idle: boolean | undefined, shimmerScale?: unknown): boolean {
	if (scaleOf(shimmerScale) <= 0.02) {
		return false;
	}
	if (idle) {
		return true;
	}
	return clamp01(hoverAmount) > 0.02;
}

export function wantTrail(shimmerScale: unknown, trailOpt?: boolean): boolean {
	if (trailOpt === false) {
		return false;
	}
	if (trailOpt === true) {
		return scaleOf(shimmerScale) > 0.02;
	}
	return scaleOf(shimmerScale) >= TRAIL_MIN_SCALE;
}
