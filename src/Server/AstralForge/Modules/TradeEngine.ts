// Purpose: the trade table as an explicit state machine with an escrow of what was agreed.
// States: Open -> Confirming -> Settling -> Settled, with Settling -> Open on a clean revert,
// Settling -> RevertFailed when a revert could not commit, and any live state -> Cancelled.
// When settling starts the two offers are copied into an escrow and fingerprinted; the settle
// code reads the escrow, never the live offers, and any change to the live offers while settling
// is caught by Verify. Release clears the escrow when the table goes back to Open.
// Owner: trading. Dependencies: none (pure; works on the existing TradeSession table).

export type TradeState = "Open" | "Confirming" | "Settling" | "Settled" | "RevertFailed" | "Cancelled";

const TRANSITIONS: Record<TradeState, ReadonlyArray<TradeState>> = {
	Open: ["Open", "Confirming", "Settling", "Cancelled"],
	Confirming: ["Confirming", "Open", "Settling", "Cancelled"],
	Settling: ["Open", "Settled", "RevertFailed"],
	RevertFailed: ["RevertFailed", "Cancelled"],
	Settled: [],
	Cancelled: [],
};

export interface Escrow {
	Host: number;
	Guest: number;
	Offers: Record<number, unknown>;
	Fingerprint: string;
	LockedAt: number;
}

export interface EngineSession {
	Host: number;
	Guest: number;
	Status: string;
	Offers: Record<number, unknown>;
	Escrow?: Escrow;
	History?: Array<{ From: string; To: string; At: number }>;
	[key: string]: unknown;
}

const HISTORY_LIMIT = 32;

export function IsState(value: unknown): value is TradeState {
	return typeIs(value, "string") && TRANSITIONS[value as TradeState] !== undefined;
}

export function Can(from: unknown, to: TradeState): boolean {
	if (!IsState(from)) {
		return false;
	}
	return TRANSITIONS[from].includes(to);
}

export function IsFinal(state: unknown): boolean {
	return IsState(state) && TRANSITIONS[state].size() === 0;
}

// Moves the session to a new state. An illegal move leaves the session untouched and returns false
// with a reason, so callers can refuse the request instead of corrupting the table.
export function Move(session: EngineSession, to: TradeState, at?: number): LuaTuple<[boolean, string | undefined]> {
	const from = session.Status;
	if (!Can(from, to)) {
		return $tuple(false, `illegal trade move ${tostring(from)} -> ${to}`);
	}
	if (from !== to) {
		const history = session.History ?? [];
		history.push({ From: from, To: to, At: at ?? os.time() });
		while (history.size() > HISTORY_LIMIT) {
			history.shift();
		}
		session.History = history;
	}
	session.Status = to;
	return $tuple(true, undefined);
}

function deepCopy(value: unknown): unknown {
	if (!typeIs(value, "table")) {
		return value;
	}
	const out: Record<string | number, unknown> = {};
	for (const [k, v] of pairs(value as Record<string | number, unknown>)) {
		out[k] = deepCopy(v);
	}
	return out;
}

// A stable text form of a value: keys sorted, so equal offers always print the same.
export function Fingerprint(value: unknown): string {
	if (!typeIs(value, "table")) {
		return typeIs(value, "string") ? string.format("%q", value) : tostring(value);
	}
	const keys: Array<string | number> = [];
	for (const [k] of pairs(value as Record<string | number, unknown>)) {
		keys.push(k as string | number);
	}
	keys.sort((a, b) => {
		const ta = typeOf(a);
		const tb = typeOf(b);
		return ta !== tb ? ta < tb : tostring(a) < tostring(b);
	});
	const parts: string[] = [];
	for (const k of keys) {
		parts.push(`${tostring(k)}=${Fingerprint((value as Record<string | number, unknown>)[k])}`);
	}
	return `{${parts.join(",")}}`;
}

// Copies both offers into the escrow. Call right after moving to Settling.
export function Lock(session: EngineSession, at?: number): Escrow {
	const offers: Record<number, unknown> = {
		[session.Host]: deepCopy(session.Offers[session.Host]),
		[session.Guest]: deepCopy(session.Offers[session.Guest]),
	};
	const escrow: Escrow = {
		Host: session.Host,
		Guest: session.Guest,
		Offers: offers,
		Fingerprint: Fingerprint(offers),
		LockedAt: at ?? os.time(),
	};
	session.Escrow = escrow;
	return escrow;
}

// True when the escrow is intact and the live offers still match it.
export function Verify(session: EngineSession): LuaTuple<[boolean, string | undefined]> {
	const escrow = session.Escrow;
	if (escrow === undefined) {
		return $tuple(false, "no escrow");
	}
	if (Fingerprint(escrow.Offers) !== escrow.Fingerprint) {
		return $tuple(false, "escrow was changed");
	}
	const live: Record<number, unknown> = {
		[session.Host]: session.Offers[session.Host],
		[session.Guest]: session.Offers[session.Guest],
	};
	if (Fingerprint(live) !== escrow.Fingerprint) {
		return $tuple(false, "offers changed after locking");
	}
	return $tuple(true, undefined);
}

// What one side gives, as locked in escrow.
export function Given(session: EngineSession, userId: number): unknown {
	return session.Escrow?.Offers[userId];
}

export function Release(session: EngineSession) {
	session.Escrow = undefined;
}
