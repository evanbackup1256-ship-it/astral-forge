// The client request queue: grant fields and the wait for auth, per-signature busy latches,
// in-flight limits, cooldowns, timeouts and late replies. MainGame owns one queue per mount
// and supplies the UI side (feedback, notices, applying the reply) through RequestHooks.
import { Controller } from "@flamework/core";
import * as NetworkPolicy from "../CoreKit/networkPolicy";
import { GRANT_ACTIONS, adopt, attachGrantFields, isAuthed, whenAuthed } from "../CoreKit/session";

export interface RequestHooks {
	/** False once the owning screen unmounted; nothing reaches the UI after that. */
	alive: (this: void) => boolean;
	/** Sends the same request again once auth arrives. */
	retry: (this: void) => void;
	/** A refusal the player should see (status line for non-passive actions). */
	refuse: (this: void, message: string) => void;
	/** A quiet refusal, answered through the caller's callback. */
	reject: (this: void, message: string, uncertain?: boolean) => void;
	/** Instant feedback and optimistic state, just before the request goes out. */
	beforeSend: (this: void, value: Record<string, unknown>) => void;
	/** Calls the server and yields for the raw reply. */
	invoke: (this: void, value: Record<string, unknown>) => unknown;
	/** The request timed out while this request still owned its latch. */
	onTimeout: (this: void, seconds: number) => void;
	/** State carried by a reply that arrived after its timeout. */
	onLateState: (this: void, state: unknown) => void;
	/** The server call failed or answered with something that is not a response. */
	onNoAnswer: (this: void) => void;
	/** A well-formed response. */
	onResponse: (this: void, raw: Record<string, unknown>) => void;
	/** Running workers and timeouts, cancelled by the owner on unmount. */
	workers: Map<thread, true>;
	timeouts: Map<thread, true>;
}

export class RequestQueue {
	private busy: Record<string, number | undefined> = {};
	private inFlight: Record<string, number | undefined> = {};
	private inFlightTotal = 0;
	private requestSequence = 0;
	private sentAt: Record<string, number | undefined> = {};
	private sentAtCount = 0;

	/** Requests currently on the wire, across every signature. */
	inFlightCount(): number {
		return this.inFlightTotal;
	}

	send(action: string, payload: Record<string, unknown>, signature: string, hooks: RequestHooks): void {
		let value = typeIs(payload, "table") ? payload : {};
		const pipelined = NetworkPolicy.IsPipelined(action);
		if (!hooks.alive()) {
			return;
		}
		if (GRANT_ACTIONS[action] !== undefined) {
			if (!isAuthed()) {
				let settled = false;
				whenAuthed(() => {
					if (settled || !hooks.alive()) {
						return;
					}
					settled = true;
					hooks.retry();
				});
				task.delay(4, () => {
					if (settled || !hooks.alive()) {
						return;
					}
					settled = true;
					if (isAuthed()) {
						hooks.retry();
						return;
					}
					hooks.refuse("Still connecting. Give it a second and try again.");
				});
				return;
			}
			value = table.clone(value);
			attachGrantFields(value);
		}
		if (!pipelined && this.busy[signature] !== undefined) {
			hooks.reject("Already working on that.");
			return;
		}
		const activeRequests = this.inFlight[signature] ?? 0;
		const requestLimit = NetworkPolicy.RequestLimit(pipelined);
		if (activeRequests >= requestLimit) {
			hooks.reject("Still working on your last tap.");
			return;
		}
		if (this.inFlightTotal >= NetworkPolicy.MAX_PHYSICAL_REQUESTS) {
			hooks.refuse("Lots going on right now. Try that again in a moment.");
			return;
		}
		const now = os.clock();
		const cooldown = NetworkPolicy.Cooldown(action);
		const previous = this.sentAt[signature];
		if (previous !== undefined && NetworkPolicy.IsCoolingDown(now, previous, cooldown)) {
			hooks.reject("Slow down a sec.");
			return;
		}
		if (previous === undefined) {
			this.sentAtCount += 1;
		}
		this.sentAt[signature] = now;
		if (this.sentAtCount > 256) {
			this.pruneSentAt(now);
		}
		hooks.beforeSend(value);
		const requestToken = this.requestSequence + 1;
		this.requestSequence = requestToken;
		this.inFlight[signature] = activeRequests + 1;
		this.inFlightTotal += 1;
		if (!pipelined) {
			this.busy[signature] = requestToken;
		}
		let requestTimedOut = false;
		let requestReleased = false;
		const releaseRequest = () => {
			if (requestReleased) {
				return;
			}
			requestReleased = true;
			const remaining = (this.inFlight[signature] ?? 1) - 1;
			if (remaining > 0) {
				this.inFlight[signature] = remaining;
			} else {
				this.inFlight[signature] = undefined;
			}
			this.inFlightTotal = math.max(0, this.inFlightTotal - 1);
		};
		let requestTimeout: thread | undefined;
		let requestWorker: thread | undefined;
		const timeoutSeconds = NetworkPolicy.Timeout(action);
		requestTimeout = task.delay(timeoutSeconds, () => {
			if (requestTimeout !== undefined) {
				hooks.timeouts.delete(requestTimeout);
			}
			requestTimeout = undefined;
			const ownsControl = pipelined || this.busy[signature] === requestToken;
			if (!pipelined && ownsControl) {
				this.busy[signature] = undefined;
			}
			requestTimedOut = true;
			releaseRequest();
			if (!hooks.alive() || !ownsControl) {
				return;
			}
			hooks.onTimeout(timeoutSeconds);
		});
		hooks.timeouts.set(requestTimeout, true);
		requestWorker = task.defer(() => {
			const [ok, raw] = pcall(() => hooks.invoke(value));
			if (requestWorker !== undefined) {
				hooks.workers.delete(requestWorker);
			}
			requestWorker = undefined;
			if (requestTimeout !== undefined) {
				task.cancel(requestTimeout);
				hooks.timeouts.delete(requestTimeout);
				requestTimeout = undefined;
			}
			if (!pipelined && this.busy[signature] === requestToken) {
				this.busy[signature] = undefined;
			}
			releaseRequest();
			if (!hooks.alive()) {
				return;
			}
			if (requestTimedOut) {
				if (ok && typeIs(raw, "table")) {
					const lateResponse = raw as { State?: unknown };
					if (GRANT_ACTIONS[action] !== undefined) {
						adopt(lateResponse as never);
					}
					if (lateResponse.State !== undefined) {
						hooks.onLateState(lateResponse.State);
					}
				}
				return;
			}
			if (!ok || !typeIs(raw, "table") || !typeIs((raw as { ok?: unknown }).ok, "boolean")) {
				hooks.onNoAnswer();
				return;
			}
			hooks.onResponse(raw as Record<string, unknown>);
		});
		hooks.workers.set(requestWorker, true);
	}

	private pruneSentAt(now: number) {
		let remaining = 0;
		for (const [key, timestamp] of pairs(this.sentAt)) {
			if (now - (timestamp as number) > 60) {
				this.sentAt[key as string] = undefined;
			} else {
				remaining += 1;
			}
		}
		if (remaining > 384) {
			// Evict oldest timestamps first so unrelated action signatures do not
			// lose their cooldowns arbitrarily.
			const entries: Array<{ key: string; timestamp: number }> = [];
			for (const [key, timestamp] of pairs(this.sentAt)) {
				entries.push({ key: key as string, timestamp: timestamp as number });
			}
			entries.sort((a, b) => a.timestamp < b.timestamp);
			const target = remaining - 256;
			for (let i = 0; i < target; i++) {
				this.sentAt[entries[i].key] = undefined;
			}
			remaining -= target;
		}
		this.sentAtCount = remaining;
	}
}

@Controller({ loadOrder: 1 })
export class RequestQueueController {
	/** A fresh queue for one mounted game screen; its latches and cooldowns die with it. */
	createQueue(): RequestQueue {
		return new RequestQueue();
	}
}
