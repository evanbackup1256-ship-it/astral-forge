-- Compiled with roblox-ts v3.0.0
--* Fixed-capacity object recycler. Luau cannot pin memory, so this is the allocation-free equivalent. 
local MemoryPinnedTableAllocator
do
	MemoryPinnedTableAllocator = setmetatable({}, {
		__tostring = function()
			return "MemoryPinnedTableAllocator"
		end,
	})
	MemoryPinnedTableAllocator.__index = MemoryPinnedTableAllocator
	function MemoryPinnedTableAllocator.new(...)
		local self = setmetatable({}, MemoryPinnedTableAllocator)
		return self:constructor(...) or self
	end
	function MemoryPinnedTableAllocator:constructor(capacity, factory, reset)
		self.reset = reset
		self.free = {}
		self.leased = {}
		local bounded = math.max(1, math.floor(capacity))
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < bounded) then
					break
				end
				local _free = self.free
				local _arg0 = factory(index)
				table.insert(_free, _arg0)
			end
		end
	end
	function MemoryPinnedTableAllocator:acquire()
		local _exp = self.free
		-- ▼ Array.pop ▼
		local _length = #_exp
		local _result = _exp[_length]
		_exp[_length] = nil
		-- ▲ Array.pop ▲
		local value = _result
		if value ~= nil then
			self.leased[value] = true
		end
		return value
	end
	function MemoryPinnedTableAllocator:release(value)
		local _leased = self.leased
		local _value = value
		-- ▼ Set.delete ▼
		local _valueExisted = _leased[_value] ~= nil
		_leased[_value] = nil
		-- ▲ Set.delete ▲
		if not _valueExisted then
			return false
		end
		self.reset(value)
		local _free = self.free
		local _value_1 = value
		table.insert(_free, _value_1)
		return true
	end
	function MemoryPinnedTableAllocator:releaseAll()
		for value in self.leased do
			self.reset(value)
			local _exp = self.free
			table.insert(_exp, value)
		end
		table.clear(self.leased)
	end
	function MemoryPinnedTableAllocator:available()
		return #self.free
	end
	function MemoryPinnedTableAllocator:active()
		-- ▼ ReadonlySet.size ▼
		local _size = 0
		for _ in self.leased do
			_size += 1
		end
		-- ▲ ReadonlySet.size ▲
		return _size
	end
end
return {
	MemoryPinnedTableAllocator = MemoryPinnedTableAllocator,
}
