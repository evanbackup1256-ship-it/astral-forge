// The shared animation scheduler. Timed tweens for UiCore run on MotionKit's one frame driver
// (subscribeContinuous), so a screen full of tweens costs one connection, and every tween uses the
// game's own easing curves and durations from motionTokens. Springs stay where they are
// (useFlipperSpring, usePresence); this is for the fixed-length moves: rises, fades, sweeps.
import React from "@rbxts/react";
import { subscribeContinuous } from "../MotionKit/motion";
import * as MotionTokens from "../MotionKit/motionTokens";
import type { DurationName, EaseName } from "./tokens";

export interface TweenSpec {
	from: number;
	to: number;
	/** seconds, or a duration token */
	duration: number | DurationName;
	ease?: EaseName | MotionTokens.Easing;
	delay?: number;
	onStep: (value: number) => void;
	onDone?: () => void;
}

interface Job {
	spec: TweenSpec;
	elapsed: number;
	length: number;
	ease: MotionTokens.Easing;
}

const jobs = new Set<Job>();
let release: (() => void) | undefined;

function step(dt: number) {
	for (const job of jobs) {
		job.elapsed += dt;
		const t = job.elapsed - (job.spec.delay ?? 0);
		if (t < 0) {
			continue;
		}
		const p = job.length <= 0 ? 1 : math.clamp(t / job.length, 0, 1);
		const s = job.spec;
		s.onStep(s.from + (s.to - s.from) * job.ease(p));
		if (p >= 1) {
			jobs.delete(job);
			s.onDone?.();
		}
	}
	if (jobs.size() === 0 && release !== undefined) {
		release();
		release = undefined;
	}
}

export function seconds(duration: number | DurationName): number {
	return typeIs(duration, "number") ? duration : MotionTokens.DURATION[duration];
}

function easing(ease: EaseName | MotionTokens.Easing | undefined): MotionTokens.Easing {
	if (ease === undefined) {
		return MotionTokens.EASE.standard;
	}
	return typeIs(ease, "function") ? ease : MotionTokens.EASE[ease];
}

/** Run a tween; returns a cancel function. Reduced motion callers pass duration 0. */
export function tween(spec: TweenSpec): () => void {
	const job: Job = { spec, elapsed: 0, length: seconds(spec.duration), ease: easing(spec.ease) };
	if (job.length <= 0 && (spec.delay ?? 0) <= 0) {
		spec.onStep(spec.to);
		spec.onDone?.();
		return () => {};
	}
	jobs.add(job);
	if (release === undefined) {
		release = subscribeContinuous(step);
	}
	return () => {
		jobs.delete(job);
	};
}

/** Delay for item `index` of a staggered entrance, capped like every list in the game. */
export function staggerDelay(index: number, stepSeconds = MotionTokens.STAGGER_STEP, capItems?: number): number {
	const i = capItems !== undefined ? math.min(index, capItems) : index;
	return capItems !== undefined ? i * stepSeconds : MotionTokens.stagger(i, stepSeconds);
}

/** A binding that tweens to `goal` whenever it changes. */
export function useTween(goal: number, duration: number | DurationName, ease?: EaseName, reduced = false): React.Binding<number> {
	const [value, setValue] = React.useBinding(goal);
	React.useEffect(() => {
		return tween({ from: value.getValue(), to: goal, duration: reduced ? 0 : duration, ease, onStep: setValue });
	}, [goal, reduced]);
	return value;
}

/** active tweens, for the dev overlay */
export function activeTweens(): number {
	return jobs.size();
}
