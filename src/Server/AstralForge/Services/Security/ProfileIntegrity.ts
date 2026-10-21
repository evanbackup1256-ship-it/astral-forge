// Profile checksum envelope and journal (pure functions over a profile table).
import { T } from "../../../../Shared/AstralForge/Shared/Locale";
import { deepCopy, Dict, isFiniteNumber, isTable, num } from "../LuaInterop";

const MOD_ADLER = 65521;
const JOURNAL_LIMIT = 12;
const MAX_NODES = 24000;
const ALGORITHM = "AFX-ADLER32-V1";


// Keys sort by type name first (boolean < number < string < anything else), then by value
// (numbers numerically, everything else by tostring). Strings and numbers - nearly every key -
// are sorted with the built-in comparison, which gives the same order far faster than a Lua
// comparator on big bags like the 6,000-node star grid.
function byText(left: unknown, right: unknown): boolean {
	return tostring(left) < tostring(right);
}
function orderedKeys(source: Dict): unknown[] {
	const numbers: defined[] = [];
	const strings: defined[] = [];
	let others: defined[] | undefined = undefined;
	for (const [key] of pairs(source)) {
		const kind = typeOf(key);
		if (kind === "string") {
			strings.push(key);
		} else if (kind === "number") {
			numbers.push(key);
		} else {
			others = others ?? [];
			others.push(key);
		}
	}
	numbers.sort();
	strings.sort();
	if (others === undefined) {
		for (const key of strings) numbers.push(key);
		return numbers;
	}
	const rest = others;
	rest.sort((left, right) => {
		const leftType = typeOf(left);
		const rightType = typeOf(right);
		if (leftType !== rightType) return leftType < rightType;
		return byText(left, right);
	});
	const keys: defined[] = [];
	for (const key of rest) if (typeOf(key) < "number") keys.push(key);
	for (const key of numbers) keys.push(key);
	for (const key of rest) if (typeOf(key) > "number" && typeOf(key) < "string") keys.push(key);
	for (const key of strings) keys.push(key);
	for (const key of rest) if (typeOf(key) > "string") keys.push(key);
	return keys;
}

// Adler-32 over the canonical text. Bytes are read eight at a time and the sums are reduced once
// per batch: every intermediate stays an exact integer far below 2^53, so the result is the
// same as reducing after every byte.
function feed(state: { A: number; B: number; Nodes: number }, text: string) {
	let a = state.A;
	let b = state.B;
	const length = text.size();
	let index = 1;
	while (index + 7 <= length) {
		const [c1, c2, c3, c4, c5, c6, c7, c8] = text.byte(index, index + 7);
		a += c1;
		b += a;
		a += c2;
		b += a;
		a += c3;
		b += a;
		a += c4;
		b += a;
		a += c5;
		b += a;
		a += c6;
		b += a;
		a += c7;
		b += a;
		a += c8;
		b += a;
		a %= MOD_ADLER;
		b %= MOD_ADLER;
		index += 8;
	}
	while (index <= length) {
		a = (a + text.byte(index)[0]) % MOD_ADLER;
		b = (b + a) % MOD_ADLER;
		index += 1;
	}
	state.A = a;
	state.B = b;
}

// the path is only needed for an error message, so it is kept as a stack of keys and joined on failure
function pathText(stack: string[]): string {
	return stack.size() === 0 ? "?" : stack.join("");
}

function digestValue(
	state: { A: number; B: number; Nodes: number },
	value: unknown,
	depth: number,
	parentKey: string | undefined,
	stack: string[],
) {
	state.Nodes += 1;
	if (state.Nodes > MAX_NODES || depth > 18) {
		error("profile exceeds integrity traversal budget");
	}
	const kind = typeOf(value);
	if (kind === "nil") feed(state, "n;");
	else if (kind === "boolean") feed(state, value === true ? "b1;" : "b0;");
	else if (kind === "number") {
		if (!isFiniteNumber(value)) error("profile contains a non-finite number at " + pathText(stack));
		feed(state, "d" + string.format("%.17g", value as number) + ";");
	} else if (kind === "string") {
		const text = value as string;
		feed(state, "s" + tostring(text.size()) + ":" + text + ";");
	} else if (kind === "table") {
		feed(state, "{");
		const isMeta = parentKey === "Meta";
		const top = stack.size();
		const bag = value as Dict;
		for (const key of orderedKeys(bag)) {
			const excluded = isMeta && (key === "Integrity" || key === "Transactions");
			if (!excluded) {
				stack[top] = "<key>";
				digestValue(state, key, depth + 1, undefined, stack);
				stack[top] = "." + tostring(key);
				digestValue(
					state,
					bag[key as string],
					depth + 1,
					typeIs(key, "string") ? key : undefined,
					stack,
				);
			}
		}
		stack.remove(top);
		feed(state, "}");
	} else {
		error("profile contains unsupported value type " + kind);
	}
}

function criticalSnapshot(profile: Dict): Dict {
	const items = isTable(profile.Items) ? profile.Items : undefined;
	const anomaly = isTable(profile.Anomaly) ? profile.Anomaly : undefined;
	return {
		Cash: profile.Cash,
		Vault: profile.Vault,
		Cores: profile.Cores,
		Stardust: profile.Stardust,
		Rebirths: profile.Rebirths,
		RunCash: profile.RunCash,
		LifetimeCash: profile.LifetimeCash,
		Zone: profile.Zone,
		CurrentZone: profile.CurrentZone,
		Domain: deepCopy(profile.Domain),
		Continuum: deepCopy(profile.Continuum),
		Machines: deepCopy(profile.Machines),
		Research: deepCopy(profile.Research),
		GridUpgrades: deepCopy(profile.GridUpgrades),
		BoostInventory: deepCopy(profile.BoostInventory),
		Items: {
			NextId: items !== undefined ? (items.NextId ?? 1) : 1,
			Essence: items !== undefined ? (items.Essence ?? 0) : 0,
			Keys: deepCopy(items !== undefined ? (items.Keys ?? {}) : {}),
		},
		Anomaly: {
			Fragments: anomaly !== undefined ? (anomaly.Fragments ?? 0) : 0,
			Stabilizations: anomaly !== undefined ? (anomaly.Stabilizations ?? 0) : 0,
		},
	};
}

function applyCriticalSnapshot(profile: Dict, snapshot: Dict) {
	for (const key of [
		"Cash",
		"Vault",
		"Cores",
		"Stardust",
		"Rebirths",
		"RunCash",
		"LifetimeCash",
		"Zone",
		"CurrentZone",
		"Domain",
		"Continuum",
		"Machines",
		"Research",
		"GridUpgrades",
		"BoostInventory",
	]) {
		if (snapshot[key] !== undefined) profile[key] = deepCopy(snapshot[key]);
	}
	if (isTable(snapshot.Items) && isTable(profile.Items)) {
		const snapshotItems = snapshot.Items;
		const profileItems = profile.Items;
		profileItems.NextId = snapshotItems.NextId ?? profileItems.NextId;
		profileItems.Essence = snapshotItems.Essence ?? profileItems.Essence;
		profileItems.Keys = deepCopy(snapshotItems.Keys ?? profileItems.Keys);
	}
	if (isTable(snapshot.Anomaly) && isTable(profile.Anomaly)) {
		const snapshotAnomaly = snapshot.Anomaly;
		const profileAnomaly = profile.Anomaly;
		profileAnomaly.Fragments = snapshotAnomaly.Fragments ?? profileAnomaly.Fragments;
		profileAnomaly.Stabilizations = snapshotAnomaly.Stabilizations ?? profileAnomaly.Stabilizations;
	}
}

// ---- compact journal --------------------------------------------------------------------
// Each journal entry used to carry full copies of the big bags (a maxed star grid alone is
// ~200 KB), so 12 entries made Meta ~2.4 MB. Entries now keep their scalars inline and store each
// big bag as a delta against the next newer entry; the newest entry in a *stored* save is an
// anchor meaning "same as this save's own top-level field" (Record runs on the snapshot that is
// written). In memory the newest entry is always full. Every entry keeps its original Hash over
// the full resolved snapshot, plus CoreHash over the scalars so a save whose big bag is damaged
// can still recover its currencies.
const BULKY = ["Domain", "Continuum", "Machines", "Research", "GridUpgrades", "BoostInventory"];
const ANCHOR = "$anchor";
const DELTA = "$delta";

function isAnchor(value: unknown): boolean {
	return isTable(value) && (value as Dict)[ANCHOR] === 1;
}
function isDelta(value: unknown): boolean {
	return isTable(value) && (value as Dict)[DELTA] === 1;
}
function deepEqual(a: unknown, b: unknown): boolean {
	if (a === b) return true;
	if (!isTable(a) || !isTable(b)) return false;
	for (const [k, v] of pairs(a as object)) {
		if (!deepEqual(v, (b as Dict)[k as string])) return false;
	}
	for (const [k] of pairs(b as object)) {
		if ((a as Dict)[k as string] === undefined) return false;
	}
	return true;
}
/** Delta that turns `newer` into `older` (pairs and key lists, so it stays a valid JSON array). */
function diff(newer: unknown, older: unknown): Dict {
	const set: defined[][] = [];
	const unset: defined[] = [];
	const from = (isTable(newer) ? newer : {}) as Dict;
	const to = (isTable(older) ? older : {}) as Dict;
	for (const key of orderedKeys(to)) {
		const value = to[key as string];
		if (!deepEqual(value, from[key as string])) set.push([key as defined, deepCopy(value) as defined]);
	}
	for (const key of orderedKeys(from)) {
		if (to[key as string] === undefined) unset.push(key as defined);
	}
	return { [DELTA]: 1, Set: set, Unset: unset };
}
function applyDelta(base: unknown, delta: Dict): Dict {
	const out = (isTable(base) ? deepCopy(base) : {}) as Dict;
	for (const pair of (delta.Set ?? []) as unknown[][]) {
		if (typeIs(pair, "table")) out[pair[0] as string] = deepCopy(pair[1]);
	}
	for (const key of (delta.Unset ?? []) as unknown[]) out[key as string] = undefined;
	return out;
}
function coreOf(snapshot: Dict): Dict {
	const core = table.clone(snapshot) as Dict;
	for (const field of BULKY) core[field] = undefined;
	return core;
}
/** Full snapshots for every entry (same order as the journal); anchors resolve from `anchor`. */
function resolveJournal(journal: unknown[], anchor: Dict | undefined): Array<Dict | undefined> {
	const out: Array<Dict | undefined> = [];
	let newer: Dict | undefined = undefined;
	for (let index = journal.size(); index >= 1; index--) {
		const entry = journal[index - 1];
		if (!isTable(entry) || !isTable(entry.Snapshot)) {
			out[index - 1] = undefined;
			continue;
		}
		const snapshot = table.clone(entry.Snapshot as Dict) as Dict;
		for (const field of BULKY) {
			const value = snapshot[field];
			if (isAnchor(value)) {
				snapshot[field] = anchor !== undefined ? deepCopy(anchor[field]) : undefined;
			} else if (isDelta(value)) {
				snapshot[field] = newer !== undefined && newer[field] !== undefined ? applyDelta(newer[field], value as Dict) : undefined;
			}
		}
		out[index - 1] = snapshot;
		newer = snapshot;
	}
	return out;
}
function entryValid(entry: Dict, resolved: Dict | undefined): boolean {
	if (resolved === undefined || !typeIs(entry.Hash, "string")) return false;
	const [ok, hash] = pcall(() => ProfileIntegrity.Hash(resolved));
	return ok && hash === entry.Hash;
}
function coreValid(entry: Dict, resolved: Dict | undefined): boolean {
	if (resolved === undefined || !typeIs(entry.CoreHash, "string")) return false;
	const [ok, hash] = pcall(() => ProfileIntegrity.Hash(coreOf(resolved)));
	return ok && hash === entry.CoreHash;
}

const ProfileIntegrity = {
	Hash(this: void, value: unknown): string {
		const state = { A: 1, B: 0, Nodes: 0 };
		digestValue(state, value, 0, undefined, []);
		return string.format("%08x", state.B * 65536 + state.A);
	},

	EnsureEnvelope(this: void, profile: Dict): Dict {
		profile.Meta = isTable(profile.Meta) ? profile.Meta : {};
		const meta = profile.Meta as Dict;
		meta.Integrity = isTable(meta.Integrity)
			? meta.Integrity
			: {
					Algorithm: ALGORITHM,
					Hash: "",
					SealedRevision: 0,
					SealedAt: 0,
				};
		meta.Transactions = isTable(meta.Transactions) ? meta.Transactions : {};
		return profile;
	},

	Seal(this: void, profile: Dict): string {
		ProfileIntegrity.EnsureEnvelope(profile);
		const meta = profile.Meta as Dict;
		const hash = ProfileIntegrity.Hash(profile);
		meta.Integrity = {
			Algorithm: ALGORITHM,
			Hash: hash,
			SealedRevision: math.max(0, math.floor(num(meta.Revision) ?? 0)),
			SealedAt: os.time(),
		};
		return hash;
	},

	Record(this: void, profile: Dict, label: string, revision?: number): Dict {
		ProfileIntegrity.EnsureEnvelope(profile);
		const meta = profile.Meta as Dict;
		const transactions = meta.Transactions as defined[];
		ProfileIntegrity.PrepareJournal(profile);
		const snapshot = criticalSnapshot(profile);
		const entry: Dict = {
			Id: string.format("%d:%d", os.time(), math.max(0, math.floor(revision ?? 0))),
			At: os.time(),
			Revision: math.max(0, math.floor(revision ?? 0)),
			Label: (label !== "" ? label : "mutation").sub(1, 64),
			Snapshot: snapshot,
			Hash: ProfileIntegrity.Hash(snapshot),
			CoreHash: ProfileIntegrity.Hash(coreOf(snapshot)),
		};
		// the previous newest entry (full in memory) becomes a delta against this one
		const previous = transactions[transactions.size() - 1] as Dict | undefined;
		if (isTable(previous) && isTable(previous.Snapshot)) {
			const prior = previous.Snapshot as Dict;
			for (const field of BULKY) {
				if (prior[field] !== undefined && !isDelta(prior[field]) && !isAnchor(prior[field])) {
					prior[field] = diff(snapshot[field], prior[field]);
				}
			}
		}
		transactions.push(entry);
		while (transactions.size() > JOURNAL_LIMIT) transactions.shift();
		return entry;
	},

	/**
	 * Load/sanitize step (also the migration for saves written before the compact journal):
	 * expands an anchored newest entry from the profile's own fields, turns every older full
	 * entry into a delta against the next newer one, and adds CoreHash to entries that verify.
	 * Lossless: every entry still resolves to exactly the snapshot it held.
	 */
	PrepareJournal(this: void, profile: Dict): void {
		ProfileIntegrity.EnsureEnvelope(profile);
		const journal = (profile.Meta as Dict).Transactions as unknown[];
		if (!typeIs(journal, "table") || journal.size() === 0) return;
		let needed = false;
		for (let index = 1; index <= journal.size(); index++) {
			const entry = journal[index - 1];
			if (!isTable(entry) || !isTable(entry.Snapshot)) continue;
			const newest = index === journal.size();
			if (entry.CoreHash === undefined) needed = true;
			for (const field of BULKY) {
				const value = (entry.Snapshot as Dict)[field];
				if (newest ? isAnchor(value) || isDelta(value) : value !== undefined && !isDelta(value)) needed = true;
			}
		}
		if (!needed) return;
		const resolved = resolveJournal(journal, profile);
		for (let index = journal.size(); index >= 1; index--) {
			const entry = journal[index - 1];
			const full = resolved[index - 1];
			if (!isTable(entry) || full === undefined) continue;
			if (entry.CoreHash === undefined) {
				// "" marks an entry that was checked and does not verify, so it is not re-hashed every save
				entry.CoreHash = entryValid(entry, full) ? ProfileIntegrity.Hash(coreOf(full)) : "";
			}
			const stored = entry.Snapshot as Dict;
			const newer = index < journal.size() ? resolved[index] : undefined;
			for (const field of BULKY) {
				if (full[field] === undefined) {
					stored[field] = undefined;
				} else if (newer === undefined) {
					stored[field] = full[field];
				} else if (newer[field] !== undefined) {
					stored[field] = diff(newer[field], full[field]);
				}
			}
		}
	},

	/**
	 * Save step, after Record on the snapshot being written: the newest entry's big bags are the
	 * snapshot's own top-level fields, so store an anchor instead of a second copy.
	 */
	CompactForSave(this: void, snapshot: Dict): void {
		const journal = (isTable(snapshot.Meta) ? (snapshot.Meta as Dict).Transactions : undefined) as unknown[] | undefined;
		if (!typeIs(journal, "table") || journal.size() === 0) return;
		const newest = journal[journal.size() - 1];
		if (!isTable(newest) || !isTable(newest.Snapshot)) return;
		const stored = newest.Snapshot as Dict;
		for (const field of BULKY) {
			if (stored[field] !== undefined && !isAnchor(stored[field]) && deepEqual(stored[field], snapshot[field])) {
				stored[field] = { [ANCHOR]: 1 };
			}
		}
	},

	/** Full snapshot of every journal entry (oldest first), resolving deltas and anchors. */
	ResolveJournal(this: void, profile: Dict): Array<Dict | undefined> {
		ProfileIntegrity.EnsureEnvelope(profile);
		return resolveJournal((profile.Meta as Dict).Transactions as unknown[], profile);
	},

	VerifyAndRecover(this: void, profile: Dict): LuaTuple<[boolean, string]> {
		ProfileIntegrity.EnsureEnvelope(profile);
		const meta = profile.Meta as Dict;
		const envelope = meta.Integrity as Dict;
		if (
			envelope.Algorithm !== ALGORITHM ||
			!typeIs(envelope.Hash, "string") ||
			envelope.Hash === ""
		) {
			const [sealed] = pcall(ProfileIntegrity.Seal, profile);
			if (!sealed) {
				return $tuple(false, "legacy profile structure is invalid; schema recovery required");
			}
			return $tuple(true, "sealed legacy profile");
		}
		const [ok, current] = pcall(ProfileIntegrity.Hash, profile);
		if (ok && current === envelope.Hash) return $tuple(true, "verified");

		const journal = meta.Transactions as unknown[];
		const resolvedJournal = resolveJournal(journal, profile);
		for (let pass = 1; pass <= 2; pass++) {
		for (let index = journal.size(); index >= 1; index--) {
			const entry = journal[index - 1];
			const full = resolvedJournal[index - 1];
			// pass 1: an entry that fully verifies; pass 2: currencies only, when a big bag was damaged
			const usable = isTable(entry) && (pass === 1 ? entryValid(entry, full) : coreValid(entry, full));
			if (isTable(entry) && usable && full !== undefined) {
				{
					applyCriticalSnapshot(profile, pass === 1 ? full : coreOf(full));
					const [sealed] = pcall(ProfileIntegrity.Seal, profile);
					if (!sealed) {
						return $tuple(
							false,
							"transaction recovered critical state; schema recovery still required",
						);
					}
					return $tuple(
						false,
						"recovered critical state from transaction " + tostring(entry.Id),
					);
				}
			}
		}
		}
		const [sealed] = pcall(ProfileIntegrity.Seal, profile);
		if (!sealed) {
			return $tuple(false, "integrity mismatch; profile structure requires schema recovery");
		}
		return $tuple(false, "integrity mismatch; no valid recovery entry");
	},

	/** The recovery journal, newest first, for the admin player lookup. */
	Journal(this: void, profile: Dict): Dict[] {
		ProfileIntegrity.EnsureEnvelope(profile);
		const journal = (profile.Meta as Dict).Transactions as unknown[];
		const resolvedJournal = resolveJournal(journal, profile);
		const out: Dict[] = [];
		for (let index = journal.size(); index >= 1; index--) {
			const entry = journal[index - 1];
			if (isTable(entry) && isTable(entry.Snapshot)) {
				const valid = entryValid(entry, resolvedJournal[index - 1]);
				out.push({
					Id: entry.Id,
					At: entry.At,
					Revision: entry.Revision,
					Label: entry.Label,
					Cash: entry.Snapshot.Cash,
					Cores: entry.Snapshot.Cores,
					Stardust: entry.Snapshot.Stardust,
					Rebirths: entry.Snapshot.Rebirths,
					Valid: valid,
				});
			}
		}
		return out;
	},

	/**
	 * Admin rollback: puts the critical state (currencies, levels, keys, boosts) back to a
	 * journal entry. Only an entry whose snapshot still matches its hash is used.
	 */
	Restore(this: void, profile: Dict, entryId: string): LuaTuple<[boolean, string]> {
		ProfileIntegrity.EnsureEnvelope(profile);
		const journal = (profile.Meta as Dict).Transactions as unknown[];
		const resolvedJournal = resolveJournal(journal, profile);
		for (let index = 1; index <= journal.size(); index++) {
			const entry = journal[index - 1];
			if (isTable(entry) && entry.Id === entryId) {
				if (!isTable(entry.Snapshot) || !typeIs(entry.Hash, "string")) {
					return $tuple(false, T("ProfileIntegrity.ThatJournalEntryHasNo"));
				}
				const full = resolvedJournal[index - 1];
				if (!entryValid(entry, full)) {
					return $tuple(false, T("ProfileIntegrity.ThatJournalEntryFailedIts"));
				}
				applyCriticalSnapshot(profile, full!);
				return $tuple(true, T("ProfileIntegrity.RestoredCriticalStateFromS", entryId, tostring(entry.Label)));
			}
		}
		return $tuple(false, T("ProfileIntegrity.NoJournalEntryWithThat"));
	},

	Status(this: void, profile: Dict): Dict {
		ProfileIntegrity.EnsureEnvelope(profile);
		const meta = profile.Meta as Dict;
		const envelope = meta.Integrity as Dict;
		const transactions = meta.Transactions as unknown[];
		return {
			Algorithm: envelope.Algorithm,
			Hash: envelope.Hash,
			SealedRevision: envelope.SealedRevision,
			SealedAt: envelope.SealedAt,
			JournalDepth: transactions.size(),
		};
	},
};

export = table.freeze(ProfileIntegrity);
