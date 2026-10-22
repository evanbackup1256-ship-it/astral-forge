// Purpose: one small clock for everything that runs on a calendar (limited events today, any
// future timed rotation). A window is live for StartsAt <= now < EndsAt, in unix seconds UTC.
// Owner: live ops. Dependencies: none, so it runs under Lune tests and on both sides.

export interface TimedWindow {
	StartsAt: number;
	EndsAt: number;
}

export type WindowPhase = "upcoming" | "live" | "ended";

export function phaseOf(window: TimedWindow, now: number): WindowPhase {
	if (now < window.StartsAt) {
		return "upcoming";
	}
	return now < window.EndsAt ? "live" : "ended";
}

/** The first window that is live at `now`, if any. Windows are expected not to overlap. */
export function liveAt<T extends TimedWindow>(windows: readonly T[], now: number): T | undefined {
	return windows.find((window) => phaseOf(window, now) === "live");
}

/** The soonest window that has not started yet. */
export function nextAfter<T extends TimedWindow>(windows: readonly T[], now: number): T | undefined {
	let best: T | undefined;
	for (const window of windows) {
		if (window.StartsAt > now && (best === undefined || window.StartsAt < best.StartsAt)) {
			best = window;
		}
	}
	return best;
}
