import FormatTests = require("./format.test");
import ShimmerTests = require("./shimmer.test");
import TaskFilterTests = require("./taskFilter.test");
import VirtualizedListTests = require("./virtualizedList.test");
import { TestRunner } from "./lunit";

function runAstralForgeClientTests() {
	return TestRunner.fromClasses([FormatTests, TaskFilterTests, VirtualizedListTests, ShimmerTests]).run();
}
export = { runAstralForgeClientTests };
