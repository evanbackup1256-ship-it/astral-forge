local _lunit = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].lunit)
local Assert = _lunit.Assert
local Test = _lunit.Test
local virtualRange = require(script.Parent.Parent.virtualizedList).virtualRange
local VirtualizedListTests
do
	VirtualizedListTests = setmetatable({}, {
		__tostring = function()
			return "VirtualizedListTests"
		end,
	})
	VirtualizedListTests.__index = VirtualizedListTests
	function VirtualizedListTests.new(...)
		local self = setmetatable({}, VirtualizedListTests)
		return self:constructor(...) or self
	end
	function VirtualizedListTests:constructor()
	end
	function VirtualizedListTests:emptyListHasNoRows()
		local range = virtualRange(0, 80, 0, 0, 400, 2)
		Assert:equal(range.first, 0)
		Assert:equal(range.last, -1)
	end
	function VirtualizedListTests:firstPageIncludesOverscan()
		local range = virtualRange(100, 80, 0, 0, 400, 2)
		Assert:equal(range.first, 0)
		Assert:equal(range.last, 7)
	end
	function VirtualizedListTests:scrolledWindowClampsToCount()
		local range = virtualRange(10, 80, 0, 10000, 400, 2)
		Assert:equal(range.first, 9)
		Assert:equal(range.last, 9)
	end
	function VirtualizedListTests:headerOffsetShiftsIndices()
		local range = virtualRange(50, 100, 200, 200, 300, 1)
		Assert:equal(range.first, 0)
		Assert:equal(range.last, 4)
	end
	local _descriptor = Test(VirtualizedListTests, "emptyListHasNoRows", {
		value = VirtualizedListTests.emptyListHasNoRows,
	})
	if _descriptor then
		VirtualizedListTests.emptyListHasNoRows = _descriptor.value
	end
	local _descriptor_1 = Test(VirtualizedListTests, "firstPageIncludesOverscan", {
		value = VirtualizedListTests.firstPageIncludesOverscan,
	})
	if _descriptor_1 then
		VirtualizedListTests.firstPageIncludesOverscan = _descriptor_1.value
	end
	local _descriptor_2 = Test(VirtualizedListTests, "scrolledWindowClampsToCount", {
		value = VirtualizedListTests.scrolledWindowClampsToCount,
	})
	if _descriptor_2 then
		VirtualizedListTests.scrolledWindowClampsToCount = _descriptor_2.value
	end
	local _descriptor_3 = Test(VirtualizedListTests, "headerOffsetShiftsIndices", {
		value = VirtualizedListTests.headerOffsetShiftsIndices,
	})
	if _descriptor_3 then
		VirtualizedListTests.headerOffsetShiftsIndices = _descriptor_3.value
	end
end
return VirtualizedListTests
