export interface Feel {
	frequency: number;
	dampingRatio: number;
}

export const FREQUENCY_MIN = 1.35;
export const FREQUENCY_MAX = 8.5;
export const DAMPING_MIN = 0.76;
export const DAMPING_MAX = 1.0;

export function responseScale(intensity: number): number {
	return 0.9 + math.clamp(intensity, 0, 1) * 0.2;
}

export function feel(stiffness: number, damping: number): Feel {
	const frequency = math.clamp(stiffness / 130, FREQUENCY_MIN, FREQUENCY_MAX);
	const raw = damping / 52;
	const ratio = math.clamp(0.76 + (raw - 0.6) * 0.6, DAMPING_MIN, DAMPING_MAX);
	return { frequency, dampingRatio: ratio };
}

export const SPRING = table.freeze({
	snap: table.freeze({ stiffness: 1000, damping: 44 }),
	smooth: table.freeze({ stiffness: 620, damping: 48 }),
	gentle: table.freeze({ stiffness: 420, damping: 52 }),
	settle: table.freeze({ stiffness: 360, damping: 52 }),
	bouncy: table.freeze({ stiffness: 560, damping: 22 }),
});

export function overshoot(spring: Feel): number {
	const z = spring.dampingRatio;
	if (z >= 1) {
		return 0;
	}
	return math.exp((-z * math.pi) / math.sqrt(1 - z * z));
}

export function step(x: number, v: number, goal: number, spring: Feel, dt: number): LuaTuple<[number, number]> {
	const z = spring.dampingRatio;
	const w = spring.frequency * math.pi * 2;
	const offset = x - goal;
	const decay = math.exp(-z * w * dt);
	if (z >= 1) {
		const nx = (offset * (1 + w * dt) + v * dt) * decay + goal;
		const nv = (v * (1 - w * dt) - offset * (w * w * dt)) * decay;
		return $tuple(nx, nv);
	}
	const c = math.sqrt(1 - z * z);
	const i = math.cos(w * c * dt);
	const j = math.sin(w * c * dt);
	const nx = (offset * (i + (z * j) / c) + (v * j) / (w * c)) * decay + goal;
	const nv = (v * (i - (z * j) / c) - offset * ((j / c) * w)) * decay;
	return $tuple(nx, nv);
}

export type Easing = (x: number) => number;

export function bezier(x1: number, y1: number, x2: number, y2: number): Easing {
	const sample = (a1: number, a2: number, t: number) => {
		const u = 1 - t;
		return 3 * u * u * t * a1 + 3 * u * t * t * a2 + t * t * t;
	};
	const slope = (a1: number, a2: number, t: number) => {
		const u = 1 - t;
		return 3 * u * u * a1 + 6 * u * t * (a2 - a1) + 3 * t * t * (1 - a2);
	};
	return (x) => {
		if (x <= 0) {
			return 0;
		}
		if (x >= 1) {
			return 1;
		}
		let t = x;
		for (let n = 1; n <= 8; n++) {
			const err = sample(x1, x2, t) - x;
			if (math.abs(err) < 1e-5) {
				return sample(y1, y2, t);
			}
			const d = slope(x1, x2, t);
			if (math.abs(d) < 1e-6) {
				break;
			}
			t -= err / d;
		}
		let lo = 0;
		let hi = 1;
		t = x;
		for (let n = 1; n <= 24; n++) {
			const value = sample(x1, x2, t);
			if (math.abs(value - x) < 1e-5) {
				break;
			}
			if (value < x) {
				lo = t;
			} else {
				hi = t;
			}
			t = (lo + hi) / 2;
		}
		return sample(y1, y2, t);
	};
}

export const EASE = table.freeze({
	standard: bezier(0.2, 0, 0, 1),
	decelerate: bezier(0.05, 0.7, 0.1, 1),
	accelerate: bezier(0.3, 0, 0.8, 0.15),
	emphasized: bezier(0.2, 0, 0, 1),
	smoothInOut: bezier(0.45, 0, 0.55, 1),
	linear: (x: number) => math.clamp(x, 0, 1),
});

export const DURATION = table.freeze({
	instant: 0.08,
	quick: 0.14,
	standard: 0.22,
	emphasized: 0.34,
	slow: 0.5,
	ceremony: 0.9,
});

export function exitSeconds(entrance: number): number {
	return math.clamp(entrance * 0.65, 0.1, 0.22);
}

export function entranceSpring(duration: number, soft?: boolean): LuaTuple<[number, number]> {
	const span = typeIs(duration, "number") && duration === duration ? math.clamp(duration, 0.08, 0.5) : 0.22;
	const frequency = math.clamp(4 / (2 * math.pi * span), FREQUENCY_MIN, FREQUENCY_MAX);
	return $tuple(frequency * 130 * (soft ? 0.82 : 1), 52);
}

export const STAGGER_STEP = 0.028;
export const STAGGER_CAP = 0.16;
export function stagger(index: number, stepSize?: number): number {
	const s = stepSize ?? STAGGER_STEP;
	const i = math.max(0, index);
	return math.min(STAGGER_CAP, s * i ** 1.12);
}

export const fx = {
	ballistic(this: void, t: number, angle: number, speed: number, g: number, k: number): LuaTuple<[number, number]> {
		const vx0 = math.cos(angle) * speed;
		const vy0 = math.sin(angle) * speed;
		if (k < 1e-4) {
			return $tuple(vx0 * t, vy0 * t + 0.5 * g * t * t);
		}
		const decay = 1 - math.exp(-k * t);
		const x = (vx0 / k) * decay;
		const terminal = g / k;
		const y = terminal * t + ((vy0 - terminal) / k) * decay;
		return $tuple(x, y);
	},
	velocity(this: void, t: number, angle: number, speed: number, g: number, k: number): LuaTuple<[number, number]> {
		const vx0 = math.cos(angle) * speed;
		const vy0 = math.sin(angle) * speed;
		if (k < 1e-4) {
			return $tuple(vx0, vy0 + g * t);
		}
		const e = math.exp(-k * t);
		const terminal = g / k;
		return $tuple(vx0 * e, terminal + (vy0 - terminal) * e);
	},
	stretch(this: void, speed: number): number {
		return 1 + math.clamp(speed / 260, 0, 2.2);
	},
	fade(this: void, t: number, life: number, hold?: number): number {
		const start = life * (hold ?? 0.35);
		if (t <= start) {
			return 0;
		}
		return EASE.accelerate(math.clamp((t - start) / math.max(1e-3, life - start), 0, 1));
	},
	heat(this: void, t: number, cool: number): number {
		return 1 - EASE.decelerate(math.clamp(t / math.max(1e-3, cool), 0, 1));
	},
	ring(this: void, t: number, life: number): LuaTuple<[number, number, number]> {
		const x = math.clamp(t / math.max(1e-3, life), 0, 1);
		const grow = EASE.decelerate(x);
		const thickness = 1 - x;
		const transparency = EASE.accelerate(math.clamp((x - 0.15) / 0.85, 0, 1));
		return $tuple(grow, thickness, transparency);
	},
	popScale(this: void, t: number, rise: number, amount: number): number {
		const x = math.clamp(t / math.max(1e-3, rise), 0, 1);
		const c1 = 1.4;
		const c3 = c1 + 1;
		const back = 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2;
		return 1 - amount + amount * back;
	},
	hash(this: void, id: number, salt?: number): number {
		const v = math.sin((id + (salt ?? 0) * 101.37) * 12.9898) * 43758.5453;
		return v - math.floor(v);
	},
};

/** Single switch for icon movement game-wide (ArtKit/Icon and every icon wrapper). Off: icons never bob, spin, pulse or wiggle. */
export const ICON_MOTION = false;
