// Purpose: isolated serializable data stores for an explicitly enabled local Studio preview.
// Owner: persistence. Dependencies: caller-provided native accessor; no network access.
// Last-reviewed: 2026-10-06.

type Key = string | number;
type Value = string | number | boolean | Dictionary;
interface Dictionary { [key: string]: Value; [key: number]: Value; }

type KeyInfo = {
	Version: string;
	CreatedTime: number;
	UpdatedTime: number;
	GetMetadata(this: KeyInfo): Dictionary;
	GetUserIds(this: KeyInfo): number[];
};

type Transform = (
	value: Value | undefined,
	keyInfo: KeyInfo | undefined,
) => LuaTuple<[Value | undefined, number[] | undefined, Dictionary | undefined]>;

type KeyRow = { KeyName: string };
type KeyPages = {
	IsFinished: boolean;
	GetCurrentPage(this: KeyPages): KeyRow[];
	AdvanceToNextPageAsync(this: KeyPages): void;
};

type Store = {
	GetAsync(this: Store, key: string, options?: DataStoreGetOptions): LuaTuple<[Value | undefined, KeyInfo | undefined]>;
	SetAsync(
		this: Store,
		key: string,
		value: Value,
		users?: number[],
		options?: DataStoreSetOptions,
	): string;
	UpdateAsync(this: Store, key: string, transform: Transform): LuaTuple<[Value | undefined, KeyInfo | undefined]>;
	RemoveAsync(this: Store, key: string): LuaTuple<[Value | undefined, KeyInfo | undefined]>;
	ListKeysAsync(this: Store, prefix?: string, pageSize?: number): KeyPages;
};

type NativeOrPreview = GlobalDataStore | Store;

type Entry = {
	value: Value;
	users: number[];
	metadata: Dictionary;
	created: number;
	updated: number;
	revision: number;
};

type Budget = { nodes: number };

const stores: Record<string, Store> = {};
const MAX_DEPTH = 32;
const MAX_NODES = 50000;

function copy(value: Value, seen: Map<Dictionary, boolean>, budget: Budget, depth: number): Value {
	budget.nodes += 1;
	assert(depth <= MAX_DEPTH && budget.nodes <= MAX_NODES, "Preview value exceeds serialization budget");
	if (typeIs(value, "number")) {
		assert(value === value && math.abs(value) !== math.huge, "Preview values must be finite");
	}
	if (!typeIs(value, "table")) {
		assert(typeIs(value, "string") || typeIs(value, "number") || typeIs(value, "boolean"), "Invalid preview value");
		return value;
	}
	assert(!seen.get(value), "Cyclic preview value");
	seen.set(value, true);
	const output: Dictionary = {};
	for (const [childKey, child] of pairs(value)) {
		assert(typeIs(childKey, "string") || typeIs(childKey, "number"), "Invalid preview key");
		output[childKey] = copy(child, seen, budget, depth + 1);
	}
	seen.set(value, false);
	return output;
}

function clone(value: Value): Value {
	return copy(value, new Map(), { nodes: 0 }, 0);
}

function info(entry: Entry): KeyInfo {
	const metadata = clone(entry.metadata) as Dictionary;
	const users = table.clone(entry.users);
	return {
		Version: "preview-" + tostring(entry.revision),
		CreatedTime: entry.created,
		UpdatedTime: entry.updated,
		GetMetadata(this: KeyInfo): Dictionary {
			const result = clone(metadata) as Dictionary;
			return result;
		},
		GetUserIds(this: KeyInfo): number[] {
			return table.clone(users);
		},
	};
}

function newStore(): Store {
	const entries: Record<string, Entry> = {};
	function commit(key: string, value: Value, users: number[] | undefined, metadata: Dictionary | undefined): Entry {
		const old = entries[key];
		const now = os.time() * 1000;
		const storedMetadata = clone(metadata ?? (old ? old.metadata : {})) as Dictionary;
		const entry: Entry = {
			value: clone(value),
			users: table.clone(users ?? (old ? old.users : [])),
			metadata: storedMetadata,
			created: old ? old.created : now,
			updated: now,
			revision: old ? old.revision + 1 : 1,
		};
		entries[key] = entry;
		return entry;
	}
	return {
		ListKeysAsync(this: Store, prefix?: string, pageSize?: number): KeyPages {
			const filter = prefix ?? "";
			const size = pageSize ?? 50;
			assert(size >= 1 && size <= 100 && size % 1 === 0, "Invalid key page size");
			const names: string[] = [];
			for (const [key] of pairs(entries)) {
				if (string.sub(key, 1, filter.size()) === filter) {
					names.push(key);
				}
			}
			table.sort(names);
			let offset = 1;
			const pages: KeyPages = {
				IsFinished: names.size() <= size,
				GetCurrentPage(this: KeyPages): KeyRow[] {
					const rows: KeyRow[] = [];
					for (let index = offset; index <= math.min(names.size(), offset + size - 1); index++) {
						rows.push({ KeyName: names[index - 1] });
					}
					return rows;
				},
				AdvanceToNextPageAsync(this: KeyPages): void {
					if (this.IsFinished) {
						return;
					}
					offset += size;
					this.IsFinished = offset + size - 1 >= names.size();
				},
			};
			return pages;
		},

		GetAsync(this: Store, key: string, _options?: DataStoreGetOptions): LuaTuple<[Value | undefined, KeyInfo | undefined]> {
			const entry = entries[key];
			return $tuple(entry ? clone(entry.value) : undefined, entry ? info(entry) : undefined);
		},

		SetAsync(
			this: Store,
			key: string,
			value: Value,
			_users?: number[],
			options?: DataStoreSetOptions,
		): string {
			const metadata = options ? options.GetMetadata() : undefined;
			const entry = commit(key, value, _users, metadata as Dictionary | undefined);
			return info(entry).Version;
		},

		UpdateAsync(this: Store, key: string, transform: Transform): LuaTuple<[Value | undefined, KeyInfo | undefined]> {
			const old = entries[key];
			const taskThread = coroutine.create(transform);
			const [ok, r0, r1, r2] = coroutine.resume(
				taskThread,
				old ? clone(old.value) : undefined,
				old ? info(old) : undefined,
			) as unknown as LuaTuple<[boolean, unknown, unknown, unknown]>;
			const rest = [r0, r1, r2];
			if (coroutine.status(taskThread) !== "dead") {
				coroutine.close(taskThread);
				error("Preview store update transforms must not yield");
			}
			if (!ok) {
				error(tostring(rest[0]));
			}
			const value = rest[0] as Value | undefined;
			const users = rest[1] as number[] | undefined;
			const metadata = rest[2] as Dictionary | undefined;
			if (value === undefined) {
				return $tuple(undefined, undefined);
			}
			const entry = commit(key, value, users, metadata);
			return $tuple(clone(entry.value), info(entry));
		},

		RemoveAsync(this: Store, key: string): LuaTuple<[Value | undefined, KeyInfo | undefined]> {
			const old = entries[key];
			entries[key] = undefined as unknown as Entry;
			return $tuple(old ? clone(old.value) : undefined, old ? info(old) : undefined);
		},
	};
}

const Preview = {
	data(this: void, name: string, enabled: boolean, native: (name: string) => NativeOrPreview): NativeOrPreview {
		if (!enabled) {
			return native(name);
		}
		const existing = stores[name];
		if (existing) {
			return existing;
		}
		const created = newStore();
		stores[name] = created;
		return created;
	},
};

export = table.freeze(Preview);
