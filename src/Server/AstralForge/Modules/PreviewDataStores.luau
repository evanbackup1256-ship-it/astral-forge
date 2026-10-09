--!strict
-- Purpose: isolated serializable data stores for an explicitly enabled local Studio preview.
-- Owner: persistence. Dependencies: caller-provided native accessor; no network access.
-- Last-reviewed: 2026-10-06.

export type Key = string | number
export type Value = string | number | boolean | { [Key]: Value }
export type Dictionary = { [Key]: Value }
export type KeyInfo = {
	Version: string,
	CreatedTime: number,
	UpdatedTime: number,
	GetMetadata: (self: KeyInfo) -> Dictionary,
	GetUserIds: (self: KeyInfo) -> { number },
}
export type Transform = (Value?, KeyInfo?) -> (Value?, { number }?, Dictionary?)
export type KeyRow = { KeyName: string }
export type KeyPages = {
	IsFinished: boolean,
	GetCurrentPage: (self: KeyPages) -> { KeyRow },
	AdvanceToNextPageAsync: (self: KeyPages) -> (),
}
export type Store = {
	GetAsync: (self: Store, key: string, options: DataStoreGetOptions?) -> (Value?, KeyInfo?),
	SetAsync: (self: Store, key: string, value: Value, users: { number }?, options: DataStoreSetOptions?) -> string,
	UpdateAsync: (self: Store, key: string, transform: Transform) -> (Value?, KeyInfo?),
	RemoveAsync: (self: Store, key: string) -> (Value?, KeyInfo?),
	ListKeysAsync: (self: Store, prefix: string?, pageSize: number?) -> KeyPages,
}
export type NativeOrPreview = GlobalDataStore | Store
type Entry =
	{ value: Value, users: { number }, metadata: Dictionary, created: number, updated: number, revision: number }
type Budget = { nodes: number }

local Preview = {}
local stores: { [string]: Store } = {}
local MAX_DEPTH = 32
local MAX_NODES = 50000

local function copy(value: Value, seen: { [Dictionary]: boolean }, budget: Budget, depth: number): Value
	budget.nodes += 1
	assert(depth <= MAX_DEPTH and budget.nodes <= MAX_NODES, "Preview value exceeds serialization budget")
	if type(value) == "number" then
		assert(value == value and math.abs(value) ~= math.huge, "Preview values must be finite")
	end
	if type(value) ~= "table" then
		assert(type(value) == "string" or type(value) == "number" or type(value) == "boolean", "Invalid preview value")
		return value
	end
	assert(not seen[value], "Cyclic preview value")
	seen[value] = true
	local output: Dictionary = {}
	for key, child in value do
		assert(type(key) == "string" or type(key) == "number", "Invalid preview key")
		output[key] = copy(child, seen, budget, depth + 1)
	end
	seen[value] = nil
	return output
end

local function clone(value: Value): Value
	return copy(value, {}, { nodes = 0 }, 0)
end

local function info(entry: Entry): KeyInfo
	local metadata = clone(entry.metadata)
	assert(type(metadata) == "table")
	local users = table.clone(entry.users)
	return {
		Version = "preview-" .. tostring(entry.revision),
		CreatedTime = entry.created,
		UpdatedTime = entry.updated,
		GetMetadata = function(_self: KeyInfo): Dictionary
			local result = clone(metadata)
			assert(type(result) == "table")
			return result
		end,
		GetUserIds = function(_self: KeyInfo): { number }
			return table.clone(users)
		end,
	}
end

local function newStore(): Store
	local entries: { [string]: Entry } = {}
	local function commit(key: string, value: Value, users: { number }?, metadata: Dictionary?): Entry
		local old = entries[key]
		local now = os.time() * 1000
		local storedMetadata = clone(metadata or (old and old.metadata) or {})
		assert(type(storedMetadata) == "table")
		local entry: Entry = {
			value = clone(value),
			users = table.clone(users or (old and old.users) or {}),
			metadata = storedMetadata,
			created = if old then old.created else now,
			updated = now,
			revision = if old then old.revision + 1 else 1,
		}
		entries[key] = entry
		return entry
	end
	return {
		ListKeysAsync = function(_self: Store, prefix: string?, pageSize: number?): KeyPages
			local filter = prefix or ""
			local size = pageSize or 50
			assert(size >= 1 and size <= 100 and size % 1 == 0, "Invalid key page size")
			local names: { string } = {}
			for key in entries do
				if string.sub(key, 1, #filter) == filter then
					names[#names + 1] = key
				end
			end
			table.sort(names)
			local offset = 1
			local pages: KeyPages
			pages = {
				IsFinished = #names <= size,
				GetCurrentPage = function(_pages: KeyPages): { KeyRow }
					local rows: { KeyRow } = {}
					for index = offset, math.min(#names, offset + size - 1) do
						rows[#rows + 1] = { KeyName = names[index] }
					end
					return rows
				end,
				AdvanceToNextPageAsync = function(self: KeyPages): ()
					if self.IsFinished then
						return
					end
					offset += size
					self.IsFinished = offset + size - 1 >= #names
				end,
			}
			return pages
		end,
		GetAsync = function(_self: Store, key: string, _options: DataStoreGetOptions?): (Value?, KeyInfo?)
			local entry = entries[key]
			return if entry then clone(entry.value) else nil, if entry then info(entry) else nil
		end,
		SetAsync = function(
			_self: Store,
			key: string,
			value: Value,
			users: { number }?,
			options: DataStoreSetOptions?
		): string
			local metadata = if options then options:GetMetadata() else nil
			local entry = commit(key, value, users, metadata)
			return info(entry).Version
		end,
		UpdateAsync = function(_self: Store, key: string, transform: Transform): (Value?, KeyInfo?)
			local old = entries[key]
			local taskThread = coroutine.create(transform)
			local ok: boolean
			local value: Value?
			local users: { number }?
			local metadata: Dictionary?
			ok, value, users, metadata =
				coroutine.resume(taskThread, if old then clone(old.value) else nil, if old then info(old) else nil)
			if coroutine.status(taskThread) ~= "dead" then
				coroutine.close(taskThread)
				error("Preview store update transforms must not yield")
			end
			if not ok then
				error(tostring(value))
			end
			if value == nil then
				return nil, nil
			end
			local entry = commit(key, value, users, metadata)
			return clone(entry.value), info(entry)
		end,
		RemoveAsync = function(_self: Store, key: string): (Value?, KeyInfo?)
			local old = entries[key]
			entries[key] = nil
			return if old then clone(old.value) else nil, if old then info(old) else nil
		end,
	}
end

function Preview.data(name: string, enabled: boolean, native: (string) -> NativeOrPreview): NativeOrPreview
	if not enabled then
		return native(name)
	end
	local existing = stores[name]
	if existing then
		return existing
	end
	local created = newStore()
	stores[name] = created
	return created
end

return table.freeze(Preview)
