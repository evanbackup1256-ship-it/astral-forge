// Purpose: an auditable record of every currency movement on a player's profile.
// Each committed transaction diffs the wallet before and after, writes one entry per currency that
// moved, and chains the entries with a running hash so a gap, an edit or a reordering shows up in
// Audit. Changes that happened outside a recorded transaction (tick income, admin edits) are
// written as "untracked" entries the next time the wallet is seen, so the chain never silently
// skips a balance. The book lives in server memory only: nothing here touches the save shape.
// Owner: economy. Dependencies: a big-number math table (OmegaMath) passed in by the caller.

type Persist = number | string;
type Dict = Record<string, unknown>;

export interface LedgerMath {
	Sub(this: void, a: unknown, b: unknown): Persist;
	Persist(this: void, value: unknown): Persist;
}

export interface LedgerEntry {
	Seq: number;
	At: number;
	Reason: string;
	Currency: string;
	Before: Persist;
	After: Persist;
	Delta: Persist;
	Hash: number;
}

export type WalletSnapshot = Record<string, Persist>;

// Wallet paths: a dot means a nested table on the profile. Order is the entry order inside a transaction.
const CURRENCIES = ["Cash", "Vault", "Cores", "Stardust", "Ore.Emberite", "Ore.Voidglass", "Ore.Starsteel"];
const DEFAULT_CAPACITY = 256;
export const UNTRACKED = "untracked";

function read(profile: Dict, path: string): unknown {
	let node: unknown = profile;
	for (const part of path.split(".")) {
		if (!typeIs(node, "table")) {
			return undefined;
		}
		node = (node as Dict)[part];
	}
	return node;
}

function key(value: Persist): string {
	return typeIs(value, "number") ? string.format("%.17g", value) : value;
}

// FNV-1a over the entry text, kept in 32 bits with exact 16-bit split multiplies.
function mix(hash: number, text: string): number {
	let h = hash;
	for (const i of $range(1, text.size())) {
		h = bit32.bxor(h, string.byte(text, i)[0]);
		// h * 16777619 mod 2^32 == h * 0x193 + (h << 24); both terms stay exact in a double
		h = (h * 0x193 + bit32.lshift(h, 24)) % 4294967296;
	}
	return h;
}

export const SEED_HASH = 0x811c9dc5;

export function EntryHash(previous: number, entry: Omit<LedgerEntry, "Hash">): number {
	return mix(
		previous,
		`${entry.Seq}|${entry.At}|${entry.Reason}|${entry.Currency}|${key(entry.Before)}|${key(entry.After)}|${key(entry.Delta)}`,
	);
}

export function Snapshot(profile: unknown, num: LedgerMath): WalletSnapshot {
	const out: WalletSnapshot = {};
	if (!typeIs(profile, "table")) {
		return out;
	}
	for (const currency of CURRENCIES) {
		const value = read(profile as Dict, currency);
		if (typeIs(value, "number") || typeIs(value, "string")) {
			out[currency] = num.Persist(value);
		}
	}
	return out;
}

export class Book {
	readonly Capacity: number;
	private entries: LedgerEntry[] = [];
	private seq = 0;
	private head = SEED_HASH;
	// the hash and balances just before the oldest kept entry, so Audit still works after trimming
	private baseHash = SEED_HASH;
	private baseBalances: WalletSnapshot = {};
	private balances: WalletSnapshot = {};

	constructor(capacity?: number) {
		this.Capacity = math.max(8, math.floor(capacity ?? DEFAULT_CAPACITY));
	}

	private push(at: number, reason: string, currency: string, before: Persist, after: Persist, num: LedgerMath) {
		this.seq += 1;
		const partial = { Seq: this.seq, At: at, Reason: reason, Currency: currency, Before: before, After: after, Delta: num.Sub(after, before) };
		const entry: LedgerEntry = { ...partial, Hash: EntryHash(this.head, partial) };
		this.head = entry.Hash;
		this.balances[currency] = after;
		this.entries.push(entry);
		while (this.entries.size() > this.Capacity) {
			const dropped = this.entries.shift()!;
			this.baseHash = dropped.Hash;
			this.baseBalances[dropped.Currency] = dropped.After;
		}
		return entry;
	}

	// Writes the wallet diff of one committed transaction. Returns the entries it wrote.
	Record(reason: string, before: WalletSnapshot, after: WalletSnapshot, at: number, num: LedgerMath): LedgerEntry[] {
		const written: LedgerEntry[] = [];
		const label = reason !== "" ? reason : UNTRACKED;
		for (const currency of CURRENCIES) {
			const start = before[currency];
			const finish = after[currency];
			if (start === undefined || finish === undefined) {
				continue;
			}
			const known = this.balances[currency];
			if (known === undefined) {
				this.balances[currency] = start;
				this.baseBalances[currency] = this.baseBalances[currency] ?? start;
			} else if (key(known) !== key(start)) {
				written.push(this.push(at, UNTRACKED, currency, known, start, num));
			}
			if (key(start) !== key(finish)) {
				written.push(this.push(at, label, currency, start, finish, num));
			}
		}
		return written;
	}

	Entries(): ReadonlyArray<LedgerEntry> {
		return this.entries;
	}

	Balance(currency: string): Persist | undefined {
		return this.balances[currency];
	}

	// Walks the kept entries: every hash must chain, sequence numbers must be consecutive and each
	// currency's Before must equal its previous After. Returns ok plus the first problem found.
	Audit(): LuaTuple<[boolean, string | undefined]> {
		let previous = this.baseHash;
		let expectedSeq = this.entries.size() > 0 ? this.entries[0].Seq : 0;
		const running: Record<string, string> = {};
		for (const [currency, value] of pairs(this.baseBalances)) {
			running[currency] = key(value);
		}
		for (const entry of this.entries) {
			if (entry.Seq !== expectedSeq) {
				return $tuple(false, `sequence gap at ${entry.Seq}`);
			}
			expectedSeq += 1;
			const partial = { Seq: entry.Seq, At: entry.At, Reason: entry.Reason, Currency: entry.Currency, Before: entry.Before, After: entry.After, Delta: entry.Delta };
			if (EntryHash(previous, partial) !== entry.Hash) {
				return $tuple(false, `hash mismatch at ${entry.Seq}`);
			}
			previous = entry.Hash;
			const last = running[entry.Currency];
			if (last !== undefined && last !== key(entry.Before)) {
				return $tuple(false, `balance break at ${entry.Seq} (${entry.Currency})`);
			}
			running[entry.Currency] = key(entry.After);
		}
		if (previous !== this.head) {
			return $tuple(false, "head does not match the last entry");
		}
		return $tuple(true, undefined);
	}

	// Net movement per currency for one reason, for summaries and admin views.
	Totals(num: { Add(this: void, a: unknown, b: unknown): Persist }, reason?: string): Record<string, Persist> {
		const totals: Record<string, Persist> = {};
		for (const entry of this.entries) {
			if (reason === undefined || entry.Reason === reason) {
				totals[entry.Currency] = num.Add(totals[entry.Currency] ?? 0, entry.Delta);
			}
		}
		return totals;
	}
}

// One book per player, created on first use and dropped when the player leaves.
export class Ledgers {
	private books = new Map<number, Book>();
	constructor(private readonly capacity?: number) {}

	For(userId: number): Book {
		let book = this.books.get(userId);
		if (!book) {
			book = new Book(this.capacity);
			this.books.set(userId, book);
		}
		return book;
	}

	Has(userId: number): boolean {
		return this.books.has(userId);
	}

	Drop(userId: number) {
		this.books.delete(userId);
	}
}

export const Currencies: ReadonlyArray<string> = CURRENCIES;
