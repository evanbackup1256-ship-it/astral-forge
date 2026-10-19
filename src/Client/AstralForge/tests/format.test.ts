import { compactNumber, compactSpinParts, formatReward, gteFlux, scaledCost } from "../CoreKit/format";
import { Assert, Test } from "./lunit";

class FormatTests {
	@Test
	compactNumberKeepsSmallValues() {
		Assert.equal(compactNumber(0), "0");
		Assert.equal(compactNumber(999), "999");
	}
	@Test
	compactNumberUsesSuffixes() {
		Assert.equal(compactNumber(1200), "1.20K");
		Assert.equal(compactNumber(15000), "15.0K");
		Assert.equal(compactNumber(1500000), "1.50M");
	}
	@Test
	compactNumberHandlesNaN() {
		Assert.equal(compactNumber(0 / 0), "0");
	}
	@Test
	compactNumberNamesDeepScales() {
		Assert.equal(compactNumber(1e63), "1.00Vg");
		Assert.true(string.find(compactNumber(1e120), "Millinillion", 1, true)[0] !== undefined);
		Assert.true(string.find(compactNumber(1e123), "Googol", 1, true)[0] !== undefined);
		Assert.true(string.find(compactNumber(1e183), "minx", 1, true)[0] !== undefined);
		Assert.true(string.find(compactNumber(1e243), "Skewes", 1, true)[0] !== undefined);
	}
	@Test
	compactNumberFormatsOmegaPersist() {
		Assert.true(
			string.find(compactNumber("1.23e400"), "e400", 1, true)[0] !== undefined ||
				string.find(compactNumber("1.23e400"), "Boundless", 1, true)[0] !== undefined ||
				string.find(compactNumber("1.23e400"), "Horizon", 1, true)[0] !== undefined,
		);
		Assert.true(gteFlux("1e400", "9e399"));
		Assert.true(!gteFlux("1e300", "1e400"));
	}
	@Test
	scaledCostSurvivesDoubleLimit() {
		const cost = scaledCost(10, 1.15, 8000);
		Assert.true(typeIs(cost, "string") || (typeIs(cost, "number") && cost === cost));
		if (typeIs(cost, "string")) {
			Assert.true(string.find(cost, "e", 1, true)[0] !== undefined);
		}
	}
	@Test
	compactSpinPartsSplitsMantissa() {
		const parts = compactSpinParts(15000);
		Assert.equal(parts.suffix, "K");
		Assert.approximately(parts.value, 15, 0.01);
	}
	@Test
	formatRewardJoinsParts() {
		Assert.equal(formatReward(undefined), "");
		Assert.equal(
			formatReward({
				Cash: 250,
				Stardust: 5,
			}),
			"+250 flux, +5 stardust",
		);
	}
}
export = FormatTests;
