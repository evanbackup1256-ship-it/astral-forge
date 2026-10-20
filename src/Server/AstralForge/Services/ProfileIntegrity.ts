// Profile checksum envelope and journal (pure functions over a profile table).
import { deepCopy, Dict, isFiniteNumber, isTable, num } from "./LuaInterop";

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
		const snapshot = criticalSnapshot(profile);
		const entry: Dict = {
			Id: string.format("%d:%d", os.time(), math.max(0, math.floor(revision ?? 0))),
			At: os.time(),
			Revision: math.max(0, math.floor(revision ?? 0)),
			Label: (label !== "" ? label : "mutation").sub(1, 64),
			Snapshot: snapshot,
			Hash: ProfileIntegrity.Hash(snapshot),
		};
		transactions.push(entry);
		while (transactions.size() > JOURNAL_LIMIT) transactions.shift();
		return entry;
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
		for (let index = journal.size(); index >= 1; index--) {
			const entry = journal[index - 1];
			if (isTable(entry) && isTable(entry.Snapshot) && typeIs(entry.Hash, "string")) {
				const [snapshotOk, snapshotHash] = pcall(ProfileIntegrity.Hash, entry.Snapshot);
				if (snapshotOk && snapshotHash === entry.Hash) {
					applyCriticalSnapshot(profile, entry.Snapshot);
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
		const [sealed] = pcall(ProfileIntegrity.Seal, profile);
		if (!sealed) {
			return $tuple(false, "integrity mismatch; profile structure requires schema recovery");
		}
		return $tuple(false, "integrity mismatch; no valid recovery entry");
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
