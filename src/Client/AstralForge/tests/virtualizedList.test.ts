import { kitMember } from "../pages/luauKits";
import { Assert, Test } from "./lunit";

interface VirtualRange {
	first: number;
	last: number;
}
const { virtualRange } = kitMember<{
	virtualRange: (this: void, count: number, stride: number, topOffset: number, scrollY: number, viewHeight: number, overscan: number) => VirtualRange;
}>("LayoutKit", "virtualizedList");

class VirtualizedListTests {
	@Test
	emptyListHasNoRows() {
		const range = virtualRange(0, 80, 0, 0, 400, 2);
		Assert.equal(range.first, 0);
		Assert.equal(range.last, -1);
	}
	@Test
	firstPageIncludesOverscan() {
		const range = virtualRange(100, 80, 0, 0, 400, 2);
		Assert.equal(range.first, 0);
		Assert.equal(range.last, 7);
	}
	@Test
	scrolledWindowClampsToCount() {
		const range = virtualRange(10, 80, 0, 10000, 400, 2);
		Assert.equal(range.first, 9);
		Assert.equal(range.last, 9);
	}
	@Test
	headerOffsetShiftsIndices() {
		const range = virtualRange(50, 100, 200, 200, 300, 1);
		Assert.equal(range.first, 0);
		Assert.equal(range.last, 4);
	}
}
export = VirtualizedListTests;
