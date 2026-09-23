local function taskMatchesFilter(task, filter)
	if filter == "Ready" then
		return not task.Claimed and task.Progress >= task.Target
	end
	if filter == "Active" then
		return not task.Claimed and task.Progress < task.Target
	end
	if filter == "Done" then
		return task.Claimed
	end
	return true
end
local function taskFilterCounts(tasks)
	local ready = 0
	local active = 0
	local done = 0
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(task)
		if task.Claimed then
			done += 1
		elseif task.Progress >= task.Target then
			ready += 1
		else
			active += 1
		end
	end
	for _k, _v in tasks do
		_callback(_v, _k - 1, tasks)
	end
	-- ▲ ReadonlyArray.forEach ▲
	return {
		All = #tasks,
		Ready = ready,
		Active = active,
		Done = done,
	}
end
return {
	taskMatchesFilter = taskMatchesFilter,
	taskFilterCounts = taskFilterCounts,
}
