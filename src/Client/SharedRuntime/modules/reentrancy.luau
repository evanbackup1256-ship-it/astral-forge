-- Compiled with roblox-ts v3.0.0
--* Per-Actor named lock. Cross-Actor state remains message-owned as required by Parallel Luau. 
local ParallelTaskReentrancyLock
do
	ParallelTaskReentrancyLock = setmetatable({}, {
		__tostring = function()
			return "ParallelTaskReentrancyLock"
		end,
	})
	ParallelTaskReentrancyLock.__index = ParallelTaskReentrancyLock
	function ParallelTaskReentrancyLock.new(...)
		local self = setmetatable({}, ParallelTaskReentrancyLock)
		return self:constructor(...) or self
	end
	function ParallelTaskReentrancyLock:constructor()
		self.active = {}
	end
	function ParallelTaskReentrancyLock:enter(key)
		local _active = self.active
		local _key = key
		if _active[_key] ~= nil then
			return false
		end
		local _active_1 = self.active
		local _key_1 = key
		_active_1[_key_1] = true
		return true
	end
	function ParallelTaskReentrancyLock:leave(key)
		local _active = self.active
		local _key = key
		_active[_key] = nil
	end
	function ParallelTaskReentrancyLock:run(key, callback)
		if not self:enter(key) then
			return false, nil
		end
		local ok, result = pcall(callback)
		self:leave(key)
		if not ok then
			error(result)
		end
		return true, result
	end
	function ParallelTaskReentrancyLock:clear()
		table.clear(self.active)
	end
end
return {
	ParallelTaskReentrancyLock = ParallelTaskReentrancyLock,
}
