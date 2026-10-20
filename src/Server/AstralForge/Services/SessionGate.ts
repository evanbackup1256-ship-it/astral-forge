// Per-player session generation/nonce rotation and transaction grants for mutating requests.
import { Service } from "@flamework/core";

const HttpService = game.GetService("HttpService");
const RunService = game.GetService("RunService");

const ROTATE_EVERY_BEATS = 8;
const ROTATE_EVERY_SEC = 24;
const GRACE_SEC = 2.5;
const UNAUTH_AFTER = 45;
const LATE_BEAT_STRIKE_SEC = 8;
const TXN_RING = 64;

interface Session {
	gen: number;
	nonce: string;
	prevNonce?: string;
	issued: number;
	lastRotate: number;
	lastBeat: number;
	lastBeatId: number;
	beatsSinceRotate: number;
	auth: boolean;
	txns: Record<string, unknown>;
	txnOrder: string[];
}

function newNonce(): string {
	return HttpService.GenerateGUID(false);
}

function rotate(session: Session) {
	session.prevNonce = session.nonce;
	session.nonce = newNonce();
	session.gen += 1;
	session.lastRotate = os.clock();
	session.beatsSinceRotate = 0;
}

const TXN_PENDING = { __txn: "pending" };

@Service({ loadOrder: 1 })
export class SessionGate {
	private _sessions = new Map<Player, Session>();

	private _get(player: Player): Session {
		const existing = this._sessions.get(player);
		if (existing !== undefined) {
			return existing;
		}
		const now = os.clock();
		const created: Session = {
			gen: 1,
			nonce: newNonce(),
			prevNonce: undefined,
			issued: now,
			lastRotate: now,
			lastBeat: now,
			lastBeatId: 0,
			beatsSinceRotate: 0,
			auth: false,
			txns: {},
			txnOrder: [],
		};
		this._sessions.set(player, created);
		return created;
	}

	Hello(player: Player): LuaTuple<[number, string]> {
		const session = this._get(player);
		return $tuple(session.gen, session.nonce);
	}

	Beat(
		player: Player,
		gen: unknown,
		id: unknown,
		n: unknown,
	): LuaTuple<[boolean, string | undefined, number | undefined, string | undefined]> {
		if (RunService.IsStudio()) {
			const session = this._get(player);
			session.auth = true;
			return $tuple(true, undefined, session.gen, session.nonce);
		}
		const session = this._get(player);
		const now = os.clock();
		if (!typeIs(gen, "number") || !typeIs(id, "number") || !typeIs(n, "string")) {
			return $tuple(false, "malformed beat", session.gen, session.nonce);
		}

		const inGrace = session.prevNonce !== undefined && now - session.lastRotate < GRACE_SEC;
		const genOk = gen === session.gen || (inGrace && gen === session.gen - 1);
		if (!genOk) {
			return $tuple(false, "gen mismatch", session.gen, session.nonce);
		}
		const nonceOk =
			n === session.nonce || (inGrace && gen === session.gen - 1 && n === session.prevNonce);
		if (!nonceOk) {
			return $tuple(false, "nonce mismatch", session.gen, session.nonce);
		}
		if (id <= session.lastBeatId) {
			return $tuple(false, "replay", session.gen, session.nonce);
		}

		const late = now - session.lastBeat;
		session.lastBeat = now;
		session.lastBeatId = id;
		session.beatsSinceRotate += 1;
		session.auth = true;

		if (late > UNAUTH_AFTER) {
			session.auth = false;
		}

		if (
			session.prevNonce === undefined ||
			session.beatsSinceRotate >= ROTATE_EVERY_BEATS ||
			now - session.lastRotate >= ROTATE_EVERY_SEC
		) {
			rotate(session);
		}

		if (late > LATE_BEAT_STRIKE_SEC) {
			return $tuple(session.auth, "late", session.gen, session.nonce);
		}
		return $tuple(session.auth, undefined, session.gen, session.nonce);
	}

	CheckGrant(
		player: Player,
		gen: unknown,
		n: unknown,
		requireNonce: boolean,
	): LuaTuple<[boolean, string | undefined]> {
		if (RunService.IsStudio()) {
			const session = this._get(player);
			session.auth = true;
			session.lastBeat = os.clock();
			return $tuple(true, undefined);
		}
		const session = this._sessions.get(player);
		if (session === undefined) {
			return $tuple(false, "no session");
		}
		const now = os.clock();
		if (!session.auth || now - session.lastBeat > UNAUTH_AFTER) {
			return $tuple(false, "unauth");
		}
		const inGrace = session.prevNonce !== undefined && now - session.lastRotate < GRACE_SEC;
		const genOk =
			typeIs(gen, "number") && (gen === session.gen || (inGrace && gen === session.gen - 1));
		if (!genOk) {
			return $tuple(false, "gen mismatch");
		}
		if (requireNonce) {
			const nonceOk =
				typeIs(n, "string") &&
				(n === session.nonce ||
					(inGrace && gen === session.gen - 1 && n === session.prevNonce));
			if (!nonceOk) {
				return $tuple(false, "nonce mismatch");
			}
		}
		return $tuple(true, undefined);
	}

	TxnLookup(player: Player, txnId: string): LuaTuple<[boolean, unknown]> {
		const session = this._get(player);
		const stored = session.txns[txnId];
		if (stored === undefined || stored === TXN_PENDING) {
			return $tuple(false, undefined);
		}
		return $tuple(true, stored);
	}

	TxnClaim(player: Player, txnId: string): LuaTuple<[string, unknown]> {
		const session = this._get(player);
		const stored = session.txns[txnId];
		if (stored === TXN_PENDING) {
			return $tuple("busy", undefined);
		}
		if (stored !== undefined) {
			return $tuple("done", stored);
		}
		session.txnOrder.push(txnId);
		if (session.txnOrder.size() > TXN_RING) {
			const oldest = session.txnOrder.shift();
			if (oldest !== undefined) {
				delete session.txns[oldest];
			}
		}
		session.txns[txnId] = TXN_PENDING;
		return $tuple("new", undefined);
	}

	TxnStore(player: Player, txnId: string, result: unknown) {
		const session = this._get(player);
		if (session.txns[txnId] === undefined) {
			session.txnOrder.push(txnId);
			if (session.txnOrder.size() > TXN_RING) {
				const oldest = session.txnOrder.shift();
				if (oldest !== undefined) {
					delete session.txns[oldest];
				}
			}
		}
		session.txns[txnId] = result;
	}

	TxnRelease(player: Player, txnId: string) {
		const session = this._get(player);
		if (session.txns[txnId] === TXN_PENDING) {
			delete session.txns[txnId];
			for (const [index, id] of pairs(session.txnOrder)) {
				if (id === txnId) {
					session.txnOrder.remove(index - 1);
					break;
				}
			}
		}
	}

	Peek(player: Player): LuaTuple<[number | undefined, string | undefined]> {
		const session = this._sessions.get(player);
		if (session === undefined) {
			return $tuple(undefined, undefined);
		}
		return $tuple(session.gen, session.nonce);
	}

	Forget(player: Player) {
		this._sessions.delete(player);
	}
}

