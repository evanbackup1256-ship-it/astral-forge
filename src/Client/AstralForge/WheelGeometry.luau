--!strict
-- Pure geometry for the UI-built prize wheel. No Roblox services, so Lune can verify it.
--
-- Angles are degrees clockwise from the top pointer. Segment k (0-based) is centred at
-- k * seg in wheel space, so a wheel rotation of 360 - k * seg puts segment k under the pointer.
--
-- Rotated GuiObjects cannot clip, so wedges are not cut shapes. Each half of the wheel is an
-- unrotated clip frame holding stacked half-disks (a circle with a hard UIGradient step).
-- A half-disk at angle a shows [a, a + 180). Inside the right clip [0, 180) the stack is the
-- segment under 0, then one half-disk per boundary in ascending order; the left clip [180, 360)
-- does the same from 180. The last layer covering any angle is the segment that owns it.

local WheelGeometry = {}

export type Layer = { angle: number, segment: number }
export type Plan = { right: { Layer }, left: { Layer } }

local function wrap(value: number): number
	return ((value % 360) + 360) % 360
end

function WheelGeometry.segmentSize(count: number): number
	return 360 / math.max(1, count)
end

-- Which segment sits at a screen angle for a given wheel rotation.
function WheelGeometry.segmentAt(count: number, rotation: number, screenAngle: number): number
	local size = WheelGeometry.segmentSize(count)
	local wheelAngle = wrap(screenAngle - rotation + size / 2)
	return math.floor(wheelAngle / size) % math.max(1, count)
end

-- Rotation that centres a segment under the pointer.
function WheelGeometry.rotationFor(count: number, segment: number): number
	return wrap(360 - segment * WheelGeometry.segmentSize(count))
end

-- Most layers either half can need: its base plus every boundary inside an open 180° span.
function WheelGeometry.slotsPerHalf(count: number): number
	return 2 + math.floor(180 / WheelGeometry.segmentSize(count))
end

local function half(count: number, rotation: number, start: number): { Layer }
	local size = WheelGeometry.segmentSize(count)
	local layers: { Layer } = { { angle = start, segment = WheelGeometry.segmentAt(count, rotation, start) } }
	if count < 2 then
		return layers
	end
	local boundaries = {}
	for segment = 0, count - 1 do
		-- segment k starts at k * seg - seg / 2 in wheel space
		local angle = wrap(rotation + segment * size - size / 2)
		if angle > start and angle < start + 180 then
			table.insert(boundaries, { angle = angle, segment = segment })
		end
	end
	table.sort(boundaries, function(a, b)
		return a.angle < b.angle
	end)
	for _, boundary in boundaries do
		table.insert(layers, boundary)
	end
	return layers
end

function WheelGeometry.plan(count: number, rotation: number): Plan
	local r = wrap(rotation)
	return { right = half(count, r, 0), left = half(count, r, 180) }
end

-- What the stacked layers actually paint at a screen angle (used by tests and diagnostics).
function WheelGeometry.paintedAt(plan: Plan, screenAngle: number): number?
	local angle = wrap(screenAngle)
	local layers = if angle < 180 then plan.right else plan.left
	local painted = nil
	for _, layer in layers do
		if layer.angle <= angle then
			painted = layer.segment
		end
	end
	return painted
end

return table.freeze(WheelGeometry)
