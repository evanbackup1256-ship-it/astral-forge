--!strict
-- Purpose: isolated ordered leaderboards for explicitly allowed unpublished Studio previews.
-- Owner: persistence. Dependencies: a caller-provided native store accessor.
-- Last-reviewed: 2026-10-06.

export type Row = { key: string, value: number }
export type Pages = {
	IsFinished: boolean,
	GetCurrentPage: (self: Pages) -> { Row },
	AdvanceToNextPageAsync: (self: Pages) -> (),
}
export type Ordered = {
	SetAsync: (self: Ordered, key: string, value: number) -> (),
	GetAsync: (self: Ordered, key: string) -> number?,
	GetSortedAsync: (self: Ordered, ascending: boolean, pageSize: number, minimum: number?, maximum: number?) -> Pages,
}
export type Store = OrderedDataStore | Ordered

local PreviewStores = {}
local stores: { [string]: Ordered } = {}

function PreviewStores.enabled(isStudio: boolean, universeId: number, allowMemory: boolean): boolean
	return isStudio and universeId == 0 and allowMemory
end

local function copyRows(rows: { Row }, start: number, pageSize: number): { Row }
	local output: { Row } = {}
	for index = start, math.min(#rows, start + pageSize - 1) do
		local row = rows[index]
		output[#output + 1] = { key = row.key, value = row.value }
	end
	return output
end

local function newStore(): Ordered
	local values: { [string]: number } = {}
	local store: Ordered
	store = {
		SetAsync = function(_self: Ordered, key: string, value: number): ()
			assert(value == value and math.abs(value) ~= math.huge, "Preview leaderboard value must be finite")
			values[key] = value
		end,
		GetAsync = function(_self: Ordered, key: string): number?
			return values[key]
		end,
		GetSortedAsync = function(
			_self: Ordered,
			ascending: boolean,
			pageSize: number,
			minimum: number?,
			maximum: number?
		): Pages
			assert(pageSize >= 1 and pageSize <= 100 and pageSize % 1 == 0, "Invalid leaderboard page size")
			local rows: { Row } = {}
			for key, value in values do
				if (minimum == nil or value >= minimum) and (maximum == nil or value <= maximum) then
					rows[#rows + 1] = { key = key, value = value }
				end
			end
			table.sort(rows, function(left: Row, right: Row): boolean
				if left.value == right.value then
					return left.key < right.key
				end
				return if ascending then left.value < right.value else left.value > right.value
			end)
			local offset = 1
			local pages: Pages
			pages = {
				IsFinished = #rows <= pageSize,
				GetCurrentPage = function(_pages: Pages): { Row }
					return copyRows(rows, offset, pageSize)
				end,
				AdvanceToNextPageAsync = function(self: Pages): ()
					if self.IsFinished then
						return
					end
					offset += pageSize
					self.IsFinished = offset + pageSize - 1 >= #rows
				end,
			}
			return pages
		end,
	}
	return store
end

function PreviewStores.ordered(name: string, preview: boolean, native: (string) -> Store): Store
	if not preview then
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

return table.freeze(PreviewStores)
