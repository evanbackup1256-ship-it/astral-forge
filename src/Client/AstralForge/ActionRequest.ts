import { truthy } from "./lua";

// One action in flight; callbacks cannot update a disposed or superseded screen.

interface ActionReply {
	ok?: unknown;
	message?: string;
	error?: string;
	[key: string]: unknown;
}

interface ActionRequestHandle {
	busy: boolean;
	status: string;
	generation: number;
	alive: boolean;
	dispose(this: void): void;
	run(this: void, action: unknown, payload: unknown, callback?: (reply: ActionReply) => void): boolean;
}

export = (
	dispatch: (action: unknown, payload: unknown, finish: (reply: unknown) => void) => void,
	schedule: (seconds: number, callback: () => void) => void,
	changed: () => void,
): ActionRequestHandle => {
	const Request = { busy: false, status: "", generation: 0, alive: true } as ActionRequestHandle;
	Request.dispose = () => {
		Request.alive = false;
		Request.generation += 1;
		Request.busy = false;
	};
	Request.run = (action, payload, callback) => {
		if (Request.busy || !Request.alive) {
			return false;
		}
		Request.busy = true;
		Request.generation += 1;
		Request.status = "Working…";
		const generation = Request.generation;
		changed();
		const finish = (raw: unknown) => {
			if (!Request.alive || generation !== Request.generation || !Request.busy) {
				return;
			}
			Request.busy = false;
			Request.generation += 1;
			const reply: ActionReply = typeIs(raw, "table")
				? (raw as ActionReply)
				: { ok: false, error: "No response. Refresh before trying again." };
			Request.status =
				reply.ok === true
					? reply.message ?? "Done."
					: reply.error ?? reply.message ?? "Request failed. Try again.";
			changed();
			if (callback) {
				callback(reply);
			}
		};
		schedule(12, () => finish(undefined));
		const [ok] = pcall(dispatch, action, truthy(payload) ? payload : {}, finish);
		if (!ok) {
			finish({ ok: false, error: "Connection interrupted. Try again." });
		}
		return true;
	};
	return Request;
};
