local _lunit = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].lunit)
local Assert = _lunit.Assert
local Test = _lunit.Test
local _taskFilter = require(script.Parent.Parent.taskFilter)
local taskFilterCounts = _taskFilter.taskFilterCounts
local taskMatchesFilter = _taskFilter.taskMatchesFilter
local TaskFilterTests
do
	TaskFilterTests = setmetatable({}, {
		__tostring = function()
			return "TaskFilterTests"
		end,
	})
	TaskFilterTests.__index = TaskFilterTests
	function TaskFilterTests.new(...)
		local self = setmetatable({}, TaskFilterTests)
		return self:constructor(...) or self
	end
	function TaskFilterTests:constructor()
	end
	function TaskFilterTests:readyMatchesUnclaimedComplete()
		Assert["true"](Assert, taskMatchesFilter({
			Progress = 5,
			Target = 5,
			Claimed = false,
		}, "Ready"))
		Assert["false"](Assert, taskMatchesFilter({
			Progress = 5,
			Target = 5,
			Claimed = true,
		}, "Ready"))
		Assert["false"](Assert, taskMatchesFilter({
			Progress = 2,
			Target = 5,
			Claimed = false,
		}, "Ready"))
	end
	function TaskFilterTests:activeMatchesIncomplete()
		Assert["true"](Assert, taskMatchesFilter({
			Progress = 1,
			Target = 4,
			Claimed = false,
		}, "Active"))
		Assert["false"](Assert, taskMatchesFilter({
			Progress = 4,
			Target = 4,
			Claimed = false,
		}, "Active"))
	end
	function TaskFilterTests:doneMatchesClaimed()
		Assert["true"](Assert, taskMatchesFilter({
			Progress = 0,
			Target = 1,
			Claimed = true,
		}, "Done"))
		Assert["true"](Assert, taskMatchesFilter({
			Progress = 0,
			Target = 1,
			Claimed = false,
		}, "All"))
	end
	function TaskFilterTests:countsSplitBuckets()
		local counts = taskFilterCounts({ {
			Progress = 1,
			Target = 4,
			Claimed = false,
		}, {
			Progress = 4,
			Target = 4,
			Claimed = false,
		}, {
			Progress = 4,
			Target = 4,
			Claimed = true,
		} })
		Assert:equal(counts.All, 3)
		Assert:equal(counts.Active, 1)
		Assert:equal(counts.Ready, 1)
		Assert:equal(counts.Done, 1)
	end
	local _descriptor = Test(TaskFilterTests, "readyMatchesUnclaimedComplete", {
		value = TaskFilterTests.readyMatchesUnclaimedComplete,
	})
	if _descriptor then
		TaskFilterTests.readyMatchesUnclaimedComplete = _descriptor.value
	end
	local _descriptor_1 = Test(TaskFilterTests, "activeMatchesIncomplete", {
		value = TaskFilterTests.activeMatchesIncomplete,
	})
	if _descriptor_1 then
		TaskFilterTests.activeMatchesIncomplete = _descriptor_1.value
	end
	local _descriptor_2 = Test(TaskFilterTests, "doneMatchesClaimed", {
		value = TaskFilterTests.doneMatchesClaimed,
	})
	if _descriptor_2 then
		TaskFilterTests.doneMatchesClaimed = _descriptor_2.value
	end
	local _descriptor_3 = Test(TaskFilterTests, "countsSplitBuckets", {
		value = TaskFilterTests.countsSplitBuckets,
	})
	if _descriptor_3 then
		TaskFilterTests.countsSplitBuckets = _descriptor_3.value
	end
end
return TaskFilterTests
