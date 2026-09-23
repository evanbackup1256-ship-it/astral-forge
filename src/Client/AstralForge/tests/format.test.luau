local _lunit = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].lunit)
local Assert = _lunit.Assert
local Test = _lunit.Test
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local compactSpinParts = _format.compactSpinParts
local formatReward = _format.formatReward
local gteFlux = _format.gteFlux
local scaledCost = _format.scaledCost
local FormatTests
do
	FormatTests = setmetatable({}, {
		__tostring = function()
			return "FormatTests"
		end,
	})
	FormatTests.__index = FormatTests
	function FormatTests.new(...)
		local self = setmetatable({}, FormatTests)
		return self:constructor(...) or self
	end
	function FormatTests:constructor()
	end
	function FormatTests:compactNumberKeepsSmallValues()
		Assert:equal(compactNumber(0), "0")
		Assert:equal(compactNumber(999), "999")
	end
	function FormatTests:compactNumberUsesSuffixes()
		Assert:equal(compactNumber(1200), "1.20K")
		Assert:equal(compactNumber(15000), "15.0K")
		Assert:equal(compactNumber(1500000), "1.50M")
	end
	function FormatTests:compactNumberHandlesNaN()
		Assert:equal(compactNumber(0 / 0), "0")
	end
	function FormatTests:compactNumberNamesDeepScales()
		Assert:equal(compactNumber(1e63), "1.00Vg")
		Assert["true"](Assert, (string.find(compactNumber(1e120), "Millinillion", 1, true)) ~= nil)
		Assert["true"](Assert, (string.find(compactNumber(1e123), "Googol", 1, true)) ~= nil)
		Assert["true"](Assert, (string.find(compactNumber(1e183), "minx", 1, true)) ~= nil)
		Assert["true"](Assert, (string.find(compactNumber(1e243), "Skewes", 1, true)) ~= nil)
	end
	function FormatTests:compactNumberFormatsOmegaPersist()
		Assert["true"](Assert, (string.find(compactNumber("1.23e400"), "e400", 1, true)) ~= nil or (string.find(compactNumber("1.23e400"), "Boundless", 1, true)) ~= nil or (string.find(compactNumber("1.23e400"), "Horizon", 1, true)) ~= nil)
		Assert["true"](Assert, gteFlux("1e400", "9e399"))
		Assert["true"](Assert, not gteFlux("1e300", "1e400"))
	end
	function FormatTests:scaledCostSurvivesDoubleLimit()
		local cost = scaledCost(10, 1.15, 8000)
		Assert["true"](Assert, type(cost) == "string" or (type(cost) == "number" and cost == cost))
		if type(cost) == "string" then
			Assert["true"](Assert, (string.find(cost, "e", 1, true)) ~= nil)
		end
	end
	function FormatTests:compactSpinPartsSplitsMantissa()
		local parts = compactSpinParts(15000)
		Assert:equal(parts.suffix, "K")
		Assert:approximately(parts.value, 15, 0.01)
	end
	function FormatTests:formatRewardJoinsParts()
		Assert:equal(formatReward(nil), "")
		Assert:equal(formatReward({
			Cash = 250,
			Stardust = 5,
		}), "+250 flux, +5 stardust")
	end
	local _descriptor = Test(FormatTests, "compactNumberKeepsSmallValues", {
		value = FormatTests.compactNumberKeepsSmallValues,
	})
	if _descriptor then
		FormatTests.compactNumberKeepsSmallValues = _descriptor.value
	end
	local _descriptor_1 = Test(FormatTests, "compactNumberUsesSuffixes", {
		value = FormatTests.compactNumberUsesSuffixes,
	})
	if _descriptor_1 then
		FormatTests.compactNumberUsesSuffixes = _descriptor_1.value
	end
	local _descriptor_2 = Test(FormatTests, "compactNumberHandlesNaN", {
		value = FormatTests.compactNumberHandlesNaN,
	})
	if _descriptor_2 then
		FormatTests.compactNumberHandlesNaN = _descriptor_2.value
	end
	local _descriptor_3 = Test(FormatTests, "compactNumberNamesDeepScales", {
		value = FormatTests.compactNumberNamesDeepScales,
	})
	if _descriptor_3 then
		FormatTests.compactNumberNamesDeepScales = _descriptor_3.value
	end
	local _descriptor_4 = Test(FormatTests, "compactNumberFormatsOmegaPersist", {
		value = FormatTests.compactNumberFormatsOmegaPersist,
	})
	if _descriptor_4 then
		FormatTests.compactNumberFormatsOmegaPersist = _descriptor_4.value
	end
	local _descriptor_5 = Test(FormatTests, "scaledCostSurvivesDoubleLimit", {
		value = FormatTests.scaledCostSurvivesDoubleLimit,
	})
	if _descriptor_5 then
		FormatTests.scaledCostSurvivesDoubleLimit = _descriptor_5.value
	end
	local _descriptor_6 = Test(FormatTests, "compactSpinPartsSplitsMantissa", {
		value = FormatTests.compactSpinPartsSplitsMantissa,
	})
	if _descriptor_6 then
		FormatTests.compactSpinPartsSplitsMantissa = _descriptor_6.value
	end
	local _descriptor_7 = Test(FormatTests, "formatRewardJoinsParts", {
		value = FormatTests.formatRewardJoinsParts,
	})
	if _descriptor_7 then
		FormatTests.formatRewardJoinsParts = _descriptor_7.value
	end
end
return FormatTests
