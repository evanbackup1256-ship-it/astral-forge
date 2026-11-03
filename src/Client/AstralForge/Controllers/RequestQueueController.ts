// The client request queue: grant fields and the wait for auth, per-signature busy latches,
// in-flight limits, cooldowns, timeouts and late replies. MainGame owns one queue per mount
// and supplies the UI side (feedback, notices, applying the reply) through RequestHooks.
import { Controller } from "@flamework/core";
import * as LogBook from "../../../Shared/AstralForge/Shared/LogBook";
import { ClientLog } from "../CoreKit/log";
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

// every request is counted and timed by action (client.request.<Action>), and a failure, a timeout or a
// slow answer says so: the picture of the client's traffic the server side builds in RequestTrace
function traceRequest(action: string, ok: boolean, raw: unknown, seconds: number, timedOut: boolean) {
	LogBook.count("client.request.total");
	LogBook.count(`client.request.${action}`);
	LogBook.timing(`client.request.${action}`, seconds);
	LogBook.timing("client.request.all", seconds);
	const ms = math.floor(seconds * 1000 + 0.5);
	if (timedOut) {
		ClientLog.warnEvery(`req-late:${action}`, 10, "net", `${action} answered after its timeout`, { ElapsedMs: ms });
		return;
	}
	if (!ok || !typeIs(raw, "table")) {
		LogBook.count("client.request.failed");
		ClientLog.warnEvery(`req-fail:${action}`, 10, "net", `${action} got no answer`, { Error: tostring(raw), ElapsedMs: ms });
		return;
	}
	if ((raw as { ok?: unknown }).ok === false) {
		LogBook.count("client.request.rejected");
		ClientLog.debug("net", `${action} rejected`, { Reason: (raw as { error?: unknown }).error, ElapsedMs: ms });
	} else {
		ClientLog.trace("net", `${action} ok`, { ElapsedMs: ms });
	}
	if (seconds >= 0.6) {
		ClientLog.warnEvery(`req-slow:${action}`, 20, "net", `${action} was slow`, { ElapsedMs: ms });
	}
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
				const authWait = task.delay(4, () => {
					hooks.timeouts.delete(authWait);
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
				// tracked with the request timeouts so an unmount cancels it
				hooks.timeouts.set(authWait, true);
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
		const tracedAt = os.clock();
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
			LogBook.count("client.request.timeout");
			ClientLog.warnEvery(`req-timeout:${action}`, 10, "net", `${action} timed out`, { Seconds: timeoutSeconds });
			releaseRequest();
			if (!hooks.alive() || !ownsControl) {
				return;
			}
			hooks.onTimeout(timeoutSeconds);
		});
		hooks.timeouts.set(requestTimeout, true);
		requestWorker = task.defer(() => {
			const [ok, raw] = pcall(() => hooks.invoke(value));
			traceRequest(action, ok, raw, os.clock() - tracedAt, requestTimedOut);
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
