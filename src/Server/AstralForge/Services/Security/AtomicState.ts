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
		this._revision = math.max(this._revision, revision ?? this._revision);
		return true;
	}
}

export = AtomicState;
