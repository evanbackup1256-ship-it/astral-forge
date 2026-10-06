local TestRunner = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].lunit).TestRunner
local FormatTests = require(script.Parent["format.test"])
local TaskFilterTests = require(script.Parent["taskFilter.test"])
local VirtualizedListTests = require(script.Parent["virtualizedList.test"])
local ShimmerTests = require(script.Parent["shimmer.test"])
local function runAstralForgeClientTests()
	return TestRunner:fromClasses({ FormatTests, TaskFilterTests, VirtualizedListTests, ShimmerTests }):run()
end
return {
	runAstralForgeClientTests = runAstralForgeClientTests,
}
