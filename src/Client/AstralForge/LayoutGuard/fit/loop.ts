// Self-correcting fit loop: a pure state machine around the optimiser.
//
//   plan(container, ctx, now)  -> knobs to apply now, or undefined to leave the layout alone
//   verify(id, penaltyBefore, penaltyAfter, now)  -> "keep" | "rollback" after the next scan
//
// Behaviour
//   - learns: knobs that verified clean are remembered per context key (device class, screen
//     bucket, input kind, UI scale); revisiting a context reuses them without searching.
//   - self-corrects: a fix that makes the measured penalty (clipping, overlap, text overflow,
//     small tap targets) worse is rolled back and banned for that context.
//   - hysteresis: a new decision must beat the applied one by `margin`, and a container can't
//     switch again within `cooldown` seconds unless its context changed. Bans make A -> B -> A
//     cycles impossible: a rolled-back candidate is never offered again in that context.
//   - bounded: at most `maxSwitches` switches per container per context.
import { Decision, FitContainer, FitKnobs, InputKind, baseKnobs, cloneKnobs, evaluate, knobsKey, optimise, sameKnobs } from "./optimizer";

export interface FitContext {
	key: string;
	input: InputKind;
}

export interface LoopOptions {
	margin: number;
	cooldown: number;
	maxSwitches: number;
}

export const DEFAULT_LOOP: LoopOptions = { margin: 0.02, cooldown: 1.5, maxSwitches: 6 };

export type Verdict = "keep" | "rollback" | "none";

interface Entry {
	ctx: string;
	applied: FitKnobs;
	previous: FitKnobs | undefined;
	pending: boolean;
	lastSwitch: number;
	switches: number;
}

export interface LoopStats {
	plans: number;
	applied: number;
	kept: number;
	rolledBack: number;
	reused: number;
	held: number;
}

export function contextKey(deviceClass: string, width: number, height: number, input: InputKind, uiScale: number): string {
	// 40px buckets so tiny resizes (window drag, keyboard) don't count as a new screen
	return `${deviceClass}|${math.floor(width / 40)}x${math.floor(height / 40)}|${input}|${math.floor(uiScale * 20 + 0.5)}`;
}

export function deviceClass(width: number, height: number, input: InputKind): string {
	const short = math.min(width, height);
	if (input === "gamepad") return "console";
	if (input === "touch") return short < 500 ? "phone" : "tablet";
	return width >= 1600 ? "desktop-wide" : "desktop";
}

export class FitLoop {
	readonly stats: LoopStats = { plans: 0, applied: 0, kept: 0, rolledBack: 0, reused: 0, held: 0 };
	private entries = new Map<string, Entry>();
	private bans = new Map<string, Set<string>>();
	private memory = new Map<string, string>();
	private memoryKnobs = new Map<string, FitKnobs>();

	constructor(readonly options: LoopOptions = DEFAULT_LOOP) {}

	private banSet(id: string, ctx: string): Set<string> {
		const k = id + "@" + ctx;
		let s = this.bans.get(k);
		if (s === undefined) {
			s = new Set();
			this.bans.set(k, s);
		}
		return s;
	}

	applied(id: string): FitKnobs | undefined {
		return this.entries.get(id)?.applied;
	}

	isPending(id: string): boolean {
		return this.entries.get(id)?.pending === true;
	}

	/** decide what to apply for this container now; undefined = keep the current layout */
	plan(c: FitContainer, ctx: FitContext, now: number): FitKnobs | undefined {
		this.stats.plans += 1;
		let entry = this.entries.get(c.id);
		const ctxChanged = entry === undefined || entry.ctx !== ctx.key;
		if (entry !== undefined && entry.pending) return undefined;
		if (entry === undefined || ctxChanged) {
			entry = { ctx: ctx.key, applied: entry?.applied ?? baseKnobs(c), previous: undefined, pending: false, lastSwitch: -math.huge, switches: 0 };
			this.entries.set(c.id, entry);
		}
		if (!ctxChanged && now - entry.lastSwitch < this.options.cooldown) {
			this.stats.held += 1;
			return undefined;
		}
		if (entry.switches >= this.options.maxSwitches) {
			this.stats.held += 1;
			return undefined;
		}
		const bans = this.banSet(c.id, ctx.key);
		const memKey = c.id + "@" + ctx.key;
		let target: FitKnobs;
		const remembered = this.memoryKnobs.get(memKey);
		if (remembered !== undefined && !bans.has(knobsKey(remembered)) && evaluate(c, remembered, ctx.input).valid) {
			target = remembered;
			this.stats.reused += 1;
		} else {
			const d: Decision = optimise(c, ctx.input, bans);
			target = d.knobs;
		}
		const current = evaluate(c, entry.applied, ctx.input);
		const candidate = evaluate(c, target, ctx.input);
		if (sameKnobs(target, entry.applied)) return undefined;
		// hysteresis: an invalid current layout (content or context changed) must be left; otherwise
		// the new one has to be clearly better
		if (current.valid && candidate.score < current.score + this.options.margin) {
			this.stats.held += 1;
			return undefined;
		}
		entry.previous = entry.applied;
		entry.applied = cloneKnobs(target);
		entry.pending = true;
		entry.lastSwitch = now;
		entry.switches += 1;
		this.stats.applied += 1;
		return entry.applied;
	}

	/**
	 * Called after the scan that follows an apply. Penalties come from the real measured layout.
	 * Returns "rollback" with the knobs to restore through `restore()`.
	 */
	verify(id: string, penaltyBefore: number, penaltyAfter: number): Verdict {
		const entry = this.entries.get(id);
		if (entry === undefined || !entry.pending) return "none";
		entry.pending = false;
		if (penaltyAfter > penaltyBefore) {
			this.banSet(id, entry.ctx).add(knobsKey(entry.applied));
			entry.applied = entry.previous ?? entry.applied;
			entry.previous = undefined;
			this.stats.rolledBack += 1;
			return "rollback";
		}
		this.memoryKnobs.set(id + "@" + entry.ctx, cloneKnobs(entry.applied));
		this.memory.set(id + "@" + entry.ctx, knobsKey(entry.applied));
		this.stats.kept += 1;
		return "keep";
	}

	/** knobs a rollback should restore */
	restore(id: string): FitKnobs | undefined {
		return this.entries.get(id)?.applied;
	}

	forget(id: string) {
		this.entries.delete(id);
	}

	/** remembered good settings, serialisable for the optional client-side setting */
	exportMemory(): Map<string, string> {
		return this.memory;
	}

	memorySize(): number {
		return this.memory.size();
	}

	reset() {
		this.entries.clear();
		this.bans.clear();
		this.memory.clear();
		this.memoryKnobs.clear();
	}
}
