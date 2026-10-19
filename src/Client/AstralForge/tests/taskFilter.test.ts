import { taskFilterCounts, taskMatchesFilter } from "../CoreKit/taskFilter";
import { Assert, Test } from "./lunit";

class TaskFilterTests {
	@Test
	readyMatchesUnclaimedComplete() {
		Assert.true(
			taskMatchesFilter(
				{
					Progress: 5,
					Target: 5,
					Claimed: false,
				},
				"Ready",
			),
		);
		Assert.false(
			taskMatchesFilter(
				{
					Progress: 5,
					Target: 5,
					Claimed: true,
				},
				"Ready",
			),
		);
		Assert.false(
			taskMatchesFilter(
				{
					Progress: 2,
					Target: 5,
					Claimed: false,
				},
				"Ready",
			),
		);
	}
	@Test
	activeMatchesIncomplete() {
		Assert.true(
			taskMatchesFilter(
				{
					Progress: 1,
					Target: 4,
					Claimed: false,
				},
				"Active",
			),
		);
		Assert.false(
			taskMatchesFilter(
				{
					Progress: 4,
					Target: 4,
					Claimed: false,
				},
				"Active",
			),
		);
	}
	@Test
	doneMatchesClaimed() {
		Assert.true(
			taskMatchesFilter(
				{
					Progress: 0,
					Target: 1,
					Claimed: true,
				},
				"Done",
			),
		);
		Assert.true(
			taskMatchesFilter(
				{
					Progress: 0,
					Target: 1,
					Claimed: false,
				},
				"All",
			),
		);
	}
	@Test
	countsSplitBuckets() {
		const counts = taskFilterCounts([
			{
				Progress: 1,
				Target: 4,
				Claimed: false,
			},
			{
				Progress: 4,
				Target: 4,
				Claimed: false,
			},
			{
				Progress: 4,
				Target: 4,
				Claimed: true,
			},
		]);
		Assert.equal(counts.All, 3);
		Assert.equal(counts.Active, 1);
		Assert.equal(counts.Ready, 1);
		Assert.equal(counts.Done, 1);
	}
}
export = TaskFilterTests;
