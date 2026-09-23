-- Compiled with roblox-ts v3.0.0
local function hashCell(x, y)
	return bit32.bor(bit32.lshift(bit32.band(x, 0xffff), 16), bit32.band(y, 0xffff))
end
--* Constant-time average bucket lookup for large 2D perk and talent layouts. 
local O1LayoutSpatialGridHasher
do
	O1LayoutSpatialGridHasher = setmetatable({}, {
		__tostring = function()
			return "O1LayoutSpatialGridHasher"
		end,
	})
	O1LayoutSpatialGridHasher.__index = O1LayoutSpatialGridHasher
	function O1LayoutSpatialGridHasher.new(...)
		local self = setmetatable({}, O1LayoutSpatialGridHasher)
		return self:constructor(...) or self
	end
	function O1LayoutSpatialGridHasher:constructor(cellSize)
		self.cellSize = cellSize
		self.buckets = {}
		self.entries = {}
		local _arg0 = cellSize > 0
		assert(_arg0, "Spatial grid cellSize must be positive")
	end
	function O1LayoutSpatialGridHasher:coordinate(value)
		return math.floor(value / self.cellSize)
	end
	function O1LayoutSpatialGridHasher:set(id, x, y, value)
		self:delete(id)
		local entry = table.freeze({
			id = id,
			x = x,
			y = y,
			value = value,
		})
		local hash = hashCell(self:coordinate(x), self:coordinate(y))
		local bucket = self.buckets[hash]
		if not bucket then
			bucket = {}
			local _buckets = self.buckets
			local _bucket = bucket
			_buckets[hash] = _bucket
		end
		local _bucket = bucket
		local _id = id
		_bucket[_id] = entry
		local _entries = self.entries
		local _id_1 = id
		_entries[_id_1] = entry
	end
	function O1LayoutSpatialGridHasher:get(id)
		local _entries = self.entries
		local _id = id
		return _entries[_id]
	end
	function O1LayoutSpatialGridHasher:at(x, y)
		local _buckets = self.buckets
		local _arg0 = hashCell(self:coordinate(x), self:coordinate(y))
		return _buckets[_arg0]
	end
	function O1LayoutSpatialGridHasher:delete(id)
		local _entries = self.entries
		local _id = id
		local existing = _entries[_id]
		if not existing then
			return false
		end
		local hash = hashCell(self:coordinate(existing.x), self:coordinate(existing.y))
		local bucket = self.buckets[hash]
		local _result = bucket
		if _result ~= nil then
			local _id_1 = id
			_result[_id_1] = nil
		end
		local _result_1 = bucket
		if _result_1 ~= nil then
			_result_1 = next(_result_1) == nil
		end
		if _result_1 then
			self.buckets[hash] = nil
		end
		local _entries_1 = self.entries
		local _id_1 = id
		_entries_1[_id_1] = nil
		return true
	end
	function O1LayoutSpatialGridHasher:clear()
		table.clear(self.buckets)
		table.clear(self.entries)
	end
end
return {
	O1LayoutSpatialGridHasher = O1LayoutSpatialGridHasher,
}
