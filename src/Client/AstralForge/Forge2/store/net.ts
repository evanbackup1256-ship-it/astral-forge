// The only Forge2 file that touches the wire. Same remotes, action names and payloads as the old
// client (Shared/Network.ts + Protocol.Actions), so the current server runs unchanged against it.
import type { ClientNetwork } from "../../ClientNetwork";
import type { Session } from "../../state";
import * as ActionCopy from "../../CoreKit/actionCopy";
import { AppHelpers } from "../../CoreKit/appNav";
import * as NetworkPolicy from "../../CoreKit/networkPolicy";
import { applyOptimistic } from "../../CoreKit/store/optimistic";
import * as SnapshotEnvelopeMath from "../../CoreKit/snapshotEnvelopeMath";
import { ForgeStore, Tone } from "./store";

export interface Reply {
	ok?: boolean;
	error?: string;
	message?: string;
	State?: Session;
	[key: string]: unknown;
}

export type Request = (action: string, payload?: Record<string, unknown>, onReply?: (reply: Reply) => void) => void;

const TONES: Record<string, Tone> = { Info: "Info", Success: "Success", Warning: "Warning", Special: "Special" };

export class ForgeNet {
	private cache: Record<string, unknown> = {};
	private lastAccepted?: Session;
	private lastSent: Record<string, number> = {};
	private connections: Array<{ Disconnect(): void }> = [];
	private alive = true;

	constructor(
		private store: ForgeStore,
		private network: ClientNetwork,
		private bridge: Folder,
		private version: string,
	) {}

	/** Takes one snapshot push; false when it was rejected (bad envelope or a missing reused section). */
	accept(raw: unknown): boolean {
		if (!typeIs(raw, "table")) return false;
		const snapshot = raw as Record<string, unknown>;
		const reused = snapshot.Reused;
		if (reused !== undefined) {
			if (!typeIs(reused, "table")) return false;
			const current = this.store.get().session as Record<string, unknown> | undefined;
			for (const key of reused as string[]) {
				const kept = this.cache[key] ?? current?.[key];
				if (kept === undefined) return false;
				snapshot[key] = kept;
			}
			snapshot.Reused = undefined;
		}
		for (const [key, value] of pairs(snapshot)) {
			if (typeIs(value, "table")) this.cache[key as string] = value;
		}
		if (!SnapshotEnvelopeMath.IsValidEnvelope(snapshot)) return false;
		const session = snapshot as unknown as Session;
		const state = this.store.get();
		if (session.Revision < state.revision) return true;
		if (session.Revision === state.revision && session.SnapshotId < state.snapshotId) return true;
		this.lastAccepted = session;
		this.store.update(() => ({ session, revision: session.Revision, snapshotId: session.SnapshotId }));
		return true;
	}

	start() {
		const events = this.network.events;
		this.connections.push(events.state.connect((snapshot) => this.accept(snapshot)));
		this.connections.push(
			events.toast.connect((payload) => {
				if (!typeIs(payload, "table")) return;
				const value = payload as { Tone?: string; Title?: unknown; Body?: unknown };
				this.store.toast(tostring(value.Title ?? "Update"), tostring(value.Body ?? ""), TONES[value.Tone ?? ""] ?? "Info");
			}),
		);
		this.connections.push(
			events.effect.connect((payload) => {
				if (!typeIs(payload, "table")) return;
				this.store.update((state) => ({ effectTick: state.effectTick + 1, lastEffect: payload as Record<string, unknown> }));
			}),
		);
		this.connections.push(
			events.shutdown.connect((packet) => {
				this.store.update(() => ({ shutdown: tostring(packet.Message ?? "The server is restarting.") }));
			}),
		);
		task.spawn(() => this.bootLoop());
	}

	private bootLoop() {
		let attempt = 0;
		while (this.alive && this.store.get().revision < 0) {
			if (this.bridge.GetAttribute("Ready") === true) {
				const [ok, raw] = pcall(() => this.network.functions.request.invoke("GetState", {}).expect());
				if (ok && typeIs(raw, "table") && this.accept((raw as Reply).State)) break;
			}
			attempt += 1;
			if (attempt === 20) {
				this.store.toast("Still connecting", "Your save is taking longer than usual. Close the game on any other device.", "Info");
			}
			task.wait(math.min(0.2 + attempt * 0.08, 1.5));
		}
	}

	readonly request: Request = (action, payload = {}, onReply) => {
		const now = os.clock();
		const signature = AppHelpers.actionSignature(action, payload);
		if (NetworkPolicy.IsCoolingDown(now, this.lastSent[signature], NetworkPolicy.Cooldown(action))) return;
		this.lastSent[signature] = now;
		const optimistic = NetworkPolicy.IsOptimistic(action);
		if (optimistic) {
			const guessed = applyOptimistic(this.store.get().session, action, payload, this.version);
			if (guessed !== undefined) this.store.update(() => ({ session: guessed }));
		}
		this.store.update((state) => ({ busy: { ...state.busy, [action]: true } }));
		task.spawn(() => {
			const [ok, raw] = pcall(() => this.network.functions.request.invoke(action, payload).expect());
			this.store.update((state) => {
				const busy = table.clone(state.busy) as Record<string, boolean>;
				delete busy[action];
				return { busy };
			});
			if (!ok || !typeIs(raw, "table")) {
				this.rollback(optimistic);
				if (!AppHelpers.isPassiveRequest(action)) this.store.toast("Connection hiccup", "That didn't go through. Try again.", "Warning");
				return;
			}
			const admin = action.sub(1, 5) === "Admin" || action === "GetAdminState";
			const reply = (admin ? raw : ActionCopy.friendlyActionResponse(raw as ActionCopy.ActionResponse)) as Reply;
			if (reply.State !== undefined) this.accept(reply.State);
			if (reply.ok !== true) {
				if (reply.State === undefined) this.rollback(optimistic);
				const detail = reply.error ?? "Try again in a moment.";
				const lowered = (reply.error ?? "").lower();
				const busy = lowered.find("cooling", 1, true)[0] !== undefined || lowered.find("slow down", 1, true)[0] !== undefined;
				if (!busy && !AppHelpers.isPassiveRequest(action)) {
					const gated = detail.lower().find("unlock", 1, true)[0] !== undefined;
					this.store.toast(ActionCopy.failureTitle(action, gated), ActionCopy.failureBody(action, detail), "Warning");
				}
			}
			if (onReply !== undefined) pcall(onReply, reply);
		});
	};

	private rollback(optimistic: boolean) {
		const accepted = this.lastAccepted;
		if (optimistic && accepted !== undefined) this.store.update(() => ({ session: accepted }));
	}

	stop() {
		this.alive = false;
		for (const connection of this.connections) pcall(() => connection.Disconnect());
		this.connections.clear();
	}
}
