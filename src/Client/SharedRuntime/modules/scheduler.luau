-- Compiled with roblox-ts v3.0.0
local ParallelTaskReentrancyLock = require(script.Parent.reentrancy).ParallelTaskReentrancyLock
--* Bounded pure-compute queue. It enters Parallel Luau only when hosted by an Actor. 
local AsynchronousActorScheduler
do
	AsynchronousActorScheduler = setmetatable({}, {
		__tostring = function()
			return "AsynchronousActorScheduler"
		end,
	})
	AsynchronousActorScheduler.__index = AsynchronousActorScheduler
	function AsynchronousActorScheduler.new(...)
		local self = setmetatable({}, AsynchronousActorScheduler)
		return self:constructor(...) or self
	end
	function AsynchronousActorScheduler:constructor(batchSize)
		if batchSize == nil then
			batchSize = 8
		end
		self.batchSize = batchSize
		self.queue = {}
		self.parallel = script:GetActor() ~= nil
		self.lock = ParallelTaskReentrancyLock.new()
		self.draining = false
		self.destroyed = false
	end
	function AsynchronousActorScheduler:schedule(job)
		if self.destroyed then
			return false
		end
		local _queue = self.queue
		local _job = job
		table.insert(_queue, _job)
		if not self.draining then
			self.draining = true
			task.defer(function()
				return self:drain()
			end)
		end
		return true
	end
	function AsynchronousActorScheduler:drain()
		if self.destroyed then
			return nil
		end
		if not self.lock:enter("drain") then
			return nil
		end
		local processed = 0
		while processed < self.batchSize and #self.queue > 0 do
			local job = table.remove(self.queue, 1)
			if not job then
				break
			end
			if self.parallel then
				task.desynchronize()
			end
			local ok, result = pcall(job.compute)
			if self.parallel then
				task.synchronize()
			end
			if ok then
				job.complete(result)
			else
				local _result = job.failed
				if _result ~= nil then
					_result(result)
				end
			end
			processed += 1
		end
		self.lock:leave("drain")
		if #self.queue > 0 then
			task.defer(function()
				return self:drain()
			end)
		else
			self.draining = false
		end
	end
	function AsynchronousActorScheduler:destroy()
		self.destroyed = true
		table.clear(self.queue)
		self.lock:clear()
		self.draining = false
	end
end
local economyScheduler = AsynchronousActorScheduler.new(6)
return {
	AsynchronousActorScheduler = AsynchronousActorScheduler,
	economyScheduler = economyScheduler,
}
