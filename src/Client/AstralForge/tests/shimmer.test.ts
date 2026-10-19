import * as ShimmerMath from "../MotionKit/shimmer";
import { Assert } from "./lunit";

class ShimmerTests {
	offsetCentersAtHalfPhase() {
		const mid = ShimmerMath.offset(0.5, 2);
		Assert.equal(mid.X, 0);
		Assert.equal(mid.Y, 0);
	}

	offsetSpansTravel() {
		const start = ShimmerMath.offset(0, 2);
		const finish = ShimmerMath.offset(1, 2);
		Assert.equal(start.X, -1);
		Assert.equal(finish.X, -1);
		const almost = ShimmerMath.offset(0.999, 2);
		Assert.true(almost.X > 0.9);
	}

	offsetHandlesNaNAndLag() {
		const nan = ShimmerMath.offset(0 / 0, 2);
		Assert.equal(nan.X, -1);
		const lagged = ShimmerMath.offset(0.5, 2, 0.25);
		Assert.equal(lagged.X, -0.5);
	}

	surfaceStrengthRespectsIdleAndScale() {
		Assert.equal(ShimmerMath.surfaceStrength(0, false, 1), 0);
		const idle = ShimmerMath.surfaceStrength(0, true, 1);
		Assert.true(idle > 0 && idle <= 0.2);
		const hover = ShimmerMath.surfaceStrength(1, false, 1);
		Assert.true(hover > idle && hover <= 0.5);
		const off = ShimmerMath.surfaceStrength(1, true, 0);
		Assert.equal(off, 0);
	}

	shouldShowGatesAntilag() {
		Assert.true(ShimmerMath.shouldShow(0, true, 1) === true);
		Assert.true(ShimmerMath.shouldShow(0, false, 1) === false);
		Assert.true(ShimmerMath.shouldShow(1, false, 0.01) === false);
		Assert.true(ShimmerMath.shouldShow(0.2, false, 1) === true);
	}

	wantTrailRespectsScaleAndOptOut() {
		Assert.true(ShimmerMath.wantTrail(1) === true);
		Assert.true(ShimmerMath.wantTrail(0.2) === false);
		Assert.true(ShimmerMath.wantTrail(1, false) === false);
		Assert.true(ShimmerMath.wantTrail(0.3, true) === true);
	}

	sweepSpeedScalesWithSettings() {
		const full = ShimmerMath.sweepSpeed(1);
		const low = ShimmerMath.sweepSpeed(0.2);
		Assert.true(full > low);
		Assert.true(low >= ShimmerMath.SWEEP_SPEED * 0.5);
	}
}
export = ShimmerTests;
