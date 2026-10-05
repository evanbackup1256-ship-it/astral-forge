--!nocheck
-- Callback transport with a synchronous latch, stale-response guard and cancellation.
return function(dispatch, schedule, changed)
	local Queue = { busy = false, completed = 0, total = 0, status = "", generation = 0 }
	function Queue.cancel()
		Queue.generation += 1
		Queue.busy = false
	end
	function Queue.start(action, orders)
		if Queue.busy or #orders == 0 then
			return false
		end
		Queue.generation += 1
		local generation = Queue.generation
		Queue.busy, Queue.completed, Queue.total = true, 0, #orders
		local function finish(message)
			if generation ~= Queue.generation then
				return
			end
			Queue.generation += 1
			Queue.busy, Queue.status = false, message
			changed()
		end
		local function nextOrder(index)
			if generation ~= Queue.generation then
				return
			end
			if index > #orders then
				finish(`Bought {Queue.completed} upgrades`)
				return
			end
			Queue.status = `Buying {index}/{#orders}`
			changed()
			local replied = false
			-- Timeouts release the local latch; an outstanding server request is never retried.
			schedule(12, function()
				if not replied and generation == Queue.generation then
					replied = true
					finish(`Paused after {Queue.completed}; refresh before buying again`)
				end
			end)
			local ok = pcall(
				dispatch,
				action,
				{ Id = orders[index].Id, Amount = orders[index].Amount },
				function(response)
					if replied or generation ~= Queue.generation then
						return
					end
					replied = true
					if type(response) ~= "table" or response.ok ~= true then
						finish(`Stopped after {Queue.completed}; budget or unlock changed`)
						return
					end
					Queue.completed += 1
					schedule(0.12, function()
						nextOrder(index + 1)
					end)
				end
			)
			if not ok then
				replied = true
				finish(`Stopped after {Queue.completed}; connection interrupted`)
			end
		end
		nextOrder(1)
		return true
	end
	return Queue
end
