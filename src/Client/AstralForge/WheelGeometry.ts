// Pure geometry for the UI-built prize wheel. No Roblox services, so Lune can verify it.
//
// Angles are degrees clockwise from the top pointer. Segment k (0-based) is centred at
// k * seg in wheel space, so a wheel rotation of 360 - k * seg puts segment k under the pointer.
//
// Rotated GuiObjects cannot clip, so wedges are not cut shapes. Each half of the wheel is an
// unrotated clip frame holding stacked half-disks (a circle with a hard UIGradient step).
// A half-disk at angle a shows [a, a + 180). Inside the right clip [0, 180) the stack is the
// segment under 0, then one half-disk per boundary in ascending order; the left clip [180, 360)
// does the same from 180. The last layer covering any angle is the segment that owns it.

interface Layer {
	angle: number;
	segment: number;
}
interface Plan {
	right: Layer[];
	left: Layer[];
}

function wrap(value: number): number {
	return ((value % 360) + 360) % 360;
}

function segmentSize(count: number): number {
	return 360 / math.max(1, count);
}

// Which segment sits at a screen angle for a given wheel rotation.
function segmentAt(count: number, rotation: number, screenAngle: number): number {
	const size = segmentSize(count);
	const wheelAngle = wrap(screenAngle - rotation + size / 2);
	return math.floor(wheelAngle / size) % math.max(1, count);
}

// Rotation that centres a segment under the pointer.
function rotationFor(count: number, segment: number): number {
	return wrap(360 - segment * segmentSize(count));
}

// Most layers either half can need: its base plus every boundary inside an open 180° span.
function slotsPerHalf(count: number): number {
	return 2 + math.floor(180 / segmentSize(count));
}

function half(count: number, rotation: number, start: number): Layer[] {
	const size = segmentSize(count);
	const layers: Layer[] = [{ angle: start, segment: segmentAt(count, rotation, start) }];
	if (count < 2) {
		return layers;
	}
	const boundaries: Layer[] = [];
	for (let segment = 0; segment <= count - 1; segment++) {
		// segment k starts at k * seg - seg / 2 in wheel space
		const angle = wrap(rotation + segment * size - size / 2);
		if (angle > start && angle < start + 180) {
			boundaries.push({ angle, segment });
		}
	}
	boundaries.sort((a, b) => a.angle < b.angle);
	for (const boundary of boundaries) {
		layers.push(boundary);
	}
	return layers;
}

function plan(count: number, rotation: number): Plan {
	const r = wrap(rotation);
	return { right: half(count, r, 0), left: half(count, r, 180) };
}

// What the stacked layers actually paint at a screen angle (used by tests and diagnostics).
function paintedAt(layout: Plan, screenAngle: number): number | undefined {
	const angle = wrap(screenAngle);
	const layers = angle < 180 ? layout.right : layout.left;
	let painted: number | undefined;
	for (const layer of layers) {
		if (layer.angle <= angle) {
			painted = layer.segment;
		}
	}
	return painted;
}

export = table.freeze({ segmentSize, segmentAt, rotationFor, slotsPerHalf, plan, paintedAt });
