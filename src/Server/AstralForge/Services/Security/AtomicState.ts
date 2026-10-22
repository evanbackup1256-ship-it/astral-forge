// Per-player profile cell with revisioned, rollback-safe updates (a value class, one per player).
import { Dict, isTable } from "../LuaInterop";

const CONTENTION_TIMEOUT_SECONDS = 2;
const CONTENTION_POLL_SECONDS = 0.03;

// deep copy for rollback; the native shallow copy does the bulk of the work at each level, so
// only nested tables cost a Lua call (profiles hold thousands of plain number entries)
function clone(value: unknown): unknown {
	if (!typeIs(value, "table")) {
		return value;
	}
	const result = table.clone(value as Dict);
	if (getmetatable(result) !== undefined) {
		setmetatable(result, undefined);
	}
	for (const [key, child] of pairs(value)) {
		if (typeIs(child, "table")) {
			result[key as string] = clone(child);
		}
	}
	return result;
}


// ---- structural diffs (rewrite 04) ----------------------------------------------------------
// Transact used to deep-copy the whole profile for every update. Now each cell keeps a private
// working mirror (one deep copy per session, kept in step by diff walks). A transaction runs on
// the mirror; on commit the new value is built from the mirror by structural sharing: every
// subtree that did not change is the committed value's own table, and only the changed paths get
// new tables. The committed value is never written, so a commit still never writes through to
// the old value, and a rollback leaves it untouched with every table identity kept.

function same(a: unknown, b: unknown): boolean {
	// NaN never equals itself; treat two NaNs as the same leaf
	return a === b || (a !== a && b !== b);
}

// Make `mirror` structurally equal to `value` in place, reusing the mirror's tables where it can.
// A mirror table reached twice (the callback aliased it) is replaced by a fresh copy.
function syncInto(mirror: Dict, value: Dict, seen: Set<unknown>): void {
	seen.add(mirror);
	for (const [key] of pairs(mirror)) {
		if (rawget(value, key) === undefined) {
			mirror[key as string] = undefined;
		}
	}
	for (const [key, child] of pairs(value)) {
		const current = rawget(mirror, key) as unknown;
		if (typeIs(child, "table")) {
			if (typeIs(current, "table") && !seen.has(current) && !table.isfrozen(current as object) && getmetatable(current) === undefined) {
				syncInto(current as Dict, child as Dict, seen);
			} else {
				mirror[key as string] = clone(child);
			}
		} else if (!same(current, child)) {
			mirror[key as string] = child;
		}
	}
}

// Register every table under `node` in `seen`, splitting aliased and frozen children in place.
function dealias(node: Dict, seen: Set<unknown>): void {
	seen.add(node);
	for (const [key, child] of pairs(node)) {
		if (typeIs(child, "table")) {
			let target = child as Dict;
			if (seen.has(target) || table.isfrozen(target)) {
				target = clone(target) as Dict;
				node[key as string] = target;
			}
			dealias(target, seen);
		}
	}
}

// The committed value for `draft`, sharing every unchanged subtree with `base`. Returns `base`
// itself when nothing under it changed. Aliased draft tables are split in the draft first so the
// mirror keeps the tree shape a deep copy would have.
function share(base: unknown, draft: unknown, seen: Set<unknown>): unknown {
	if (!typeIs(draft, "table")) {
		return draft;
	}
	if (!typeIs(base, "table") || getmetatable(draft) !== undefined) {
		dealias(draft as Dict, seen);
		return clone(draft);
	}
	seen.add(draft);
	const baseTable = base as Dict;
	const draftTable = draft as Dict;
	let out: Dict | undefined;
	for (const [key, child] of pairs(draftTable)) {
		let node = child as unknown;
		// split aliases, and thaw frozen tables a callback put in (a deep copy would have)
		if (typeIs(node, "table") && (seen.has(node) || table.isfrozen(node as object))) {
			node = clone(node);
			draftTable[key as string] = node;
		}
		const before = rawget(baseTable, key) as unknown;
		const after = share(before, node, seen);
		if (!same(after, before)) {
			if (out === undefined) out = table.clone(baseTable);
			out[key as string] = after;
		}
	}
	for (const [key] of pairs(baseTable)) {
		if (rawget(draftTable, key) === undefined) {
			if (out === undefined) out = table.clone(baseTable);
			out[key as string] = undefined;
		}
	}
	return out ?? base;
}

function revisionOf(value: unknown): number {
	if (isTable(value) && isTable(value.Meta) && typeIs(value.Meta.Revision, "number")) {
		return math.max(0, math.floor(value.Meta.Revision));
	}
	return 0;
}

class AtomicState {
	private _value: unknown;
	private _revision: number;
	private _busy = false;
	// private working copy for Transact; undefined until first needed, stale after anything that
	// changed _value without going through it (TransactInPlace, Replace, a rollback)
	private _mirror: Dict | undefined = undefined;
	private _mirrorStale = false;

	constructor(initial: unknown) {
		this._value = initial;
		this._revision = revisionOf(initial);
	}

	Read(): LuaTuple<[unknown, number]> {
		this._revision = math.max(this._revision, revisionOf(this._value));
		return $tuple(this._value, this._revision);
	}

	IsBusy(): boolean {
		return this._busy === true;
	}

	Transact(
		callback: (this: void, draft: unknown, revision: number) => unknown,
		incrementRevision?: boolean,
	): LuaTuple<[boolean, unknown, number]> {
		const deadline = os.clock() + CONTENTION_TIMEOUT_SECONDS;
		while (this._busy && os.clock() < deadline) {
			task.wait(CONTENTION_POLL_SECONDS);
		}
		if (this._busy) {
			return $tuple(false, "state transaction already in progress", this._revision);
		}
		this._revision = math.max(this._revision, revisionOf(this._value));
		this._busy = true;
		const base = this._value;
		if (!isTable(base)) {
			return this._transactCopy(callback, incrementRevision);
		}
		const [mirrorOk, mirrorProblem] = pcall(() => {
			if (this._mirror === undefined) {
				this._mirror = clone(base) as Dict;
			} else if (this._mirrorStale) {
				syncInto(this._mirror, base as Dict, new Set());
			}
			this._mirrorStale = false;
		});
		if (!mirrorOk) {
			this._mirror = undefined;
			this._busy = false;
			return $tuple(false, mirrorProblem, this._revision);
		}
		const draft = this._mirror!;
		const [ok, result] = pcall(callback, draft, this._revision + 1);
		const shouldCommit = ok && !(isTable(result) && result.ok === false);
		if (shouldCommit) {
			if (incrementRevision !== false) {
				this._revision += 1;
				if (isTable(draft.Meta)) {
					draft.Meta.Revision = this._revision;
				}
			}
			const [shareOk, committed] = pcall(share, base, draft, new Set());
			if (!shareOk) {
				this._mirrorStale = true;
				this._busy = false;
				return $tuple(false, committed, this._revision);
			}
			this._value = committed;
		} else {
			// the mirror holds the failed edits; bring it back to the committed value lazily
			this._mirrorStale = true;
		}
		this._busy = false;
		if (!ok) {
			return $tuple(false, result, this._revision);
		}
		return $tuple(true, result, this._revision);
	}

	// Non-table values (and the busy lock already held): the original copy-then-swap path.
	private _transactCopy(
		callback: (this: void, draft: unknown, revision: number) => unknown,
		incrementRevision?: boolean,
	): LuaTuple<[boolean, unknown, number]> {
		const [cloneOk, draft] = pcall(clone, this._value);
		if (!cloneOk) {
			this._busy = false;
			return $tuple(false, draft, this._revision);
		}
		const [ok, result] = pcall(callback, draft, this._revision + 1);
		const shouldCommit = ok && !(isTable(result) && result.ok === false);
		if (shouldCommit) {
			if (incrementRevision !== false) {
				this._revision += 1;
				if (isTable(draft) && isTable(draft.Meta)) {
					draft.Meta.Revision = this._revision;
				}
			}
			this._value = draft;
			this._mirror = undefined;
		}
		this._busy = false;
		if (!ok) {
			return $tuple(false, result, this._revision);
		}
		return $tuple(true, result, this._revision);
	}

	// Fast path for hot, small updates (the 0.5s production tick): the callback edits the live
	// value in place instead of a deep copy of the whole profile, under the same busy lock.
	// Rollback state is kept only for what such a callback can touch: the root's own fields
	// (scalars and which table each key points at), a shallow copy of each `shallowKeys`
	// section, and a deep copy of each `deepKeys` section. On a throw or an { ok = false }
	// result all of those are put back; tables keep their identity when nothing failed.
	TransactInPlace(
		callback: (this: void, draft: unknown, revision: number) => unknown,
		deepKeys: ReadonlyArray<string>,
		shallowKeys: ReadonlyArray<string>,
		incrementRevision?: boolean,
	): LuaTuple<[boolean, unknown, number]> {
		const deadline = os.clock() + CONTENTION_TIMEOUT_SECONDS;
		while (this._busy && os.clock() < deadline) {
			task.wait(CONTENTION_POLL_SECONDS);
		}
		if (this._busy) {
			return $tuple(false, "state transaction already in progress", this._revision);
		}
		const live = this._value;
		if (!isTable(live)) {
			return this.Transact(callback, incrementRevision);
		}
		this._revision = math.max(this._revision, revisionOf(live));
		this._busy = true;
		const root = live as Record<string, unknown>;
		const [backupOk, backup] = pcall(() => {
			const rootCopy = table.clone(root);
			const deep: Record<string, unknown> = {};
			for (const key of deepKeys) {
				deep[key] = clone(root[key]);
			}
			const shallow: Record<string, Record<string, unknown> | undefined> = {};
			for (const key of shallowKeys) {
				const section = root[key];
				shallow[key] = isTable(section) ? table.clone(section as Record<string, unknown>) : undefined;
			}
			return { rootCopy, deep, shallow };
		});
		if (!backupOk) {
			this._busy = false;
			return $tuple(false, backup, this._revision);
		}
		const [ok, result] = pcall(callback, live, this._revision + 1);
		const shouldCommit = ok && !(isTable(result) && result.ok === false);
		// the live value changed in place; the Transact mirror re-syncs by diff on next use
		this._mirrorStale = true;
		if (shouldCommit) {
			if (incrementRevision !== false) {
				this._revision += 1;
				if (isTable(root.Meta)) {
					(root.Meta as Record<string, unknown>).Revision = this._revision;
				}
			}
		} else {
			const saved = backup as {
				rootCopy: Record<string, unknown>;
				deep: Record<string, unknown>;
				shallow: Record<string, Record<string, unknown> | undefined>;
			};
			for (const [key] of pairs(root)) {
				if (rawget(saved.rootCopy, key) === undefined) {
					root[key as string] = undefined;
				}
			}
			for (const [key, value] of pairs(saved.rootCopy)) {
				root[key as string] = value;
			}
			for (const key of shallowKeys) {
				const before = saved.shallow[key];
				const section = root[key];
				if (before !== undefined && isTable(section)) {
					const target = section as Record<string, unknown>;
					for (const [field] of pairs(target)) {
						if (rawget(before, field) === undefined) {
							target[field as string] = undefined;
						}
					}
					for (const [field, value] of pairs(before)) {
						target[field as string] = value;
					}
				}
			}
			for (const key of deepKeys) {
				root[key] = saved.deep[key];
			}
		}
		this._busy = false;
		if (!ok) {
			return $tuple(false, result, this._revision);
		}
		return $tuple(true, result, this._revision);
	}

	Replace(value: unknown, revision?: number): boolean {
		if (this._busy) {
			return false;
		}
		this._value = value;
		this._mirrorStale = true;
		this._revision = math.max(this._revision, revision ?? this._revision);
		return true;
	}
}

export = AtomicState;
