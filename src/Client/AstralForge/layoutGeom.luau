--!strict
-- Layout geometry. Pure numbers: vectors, rectangles, rotated boxes, UDim
-- evaluation, anchors, and a spatial hash. No Roblox instances.

local Geom = {}

local EPS = 1e-4
local INF = math.huge

export type Vec2 = { x: number, y: number }
export type Rect = { x0: number, y0: number, x1: number, y1: number }
export type Insets = { l: number, t: number, r: number, b: number }
export type UDim1 = { scale: number, offset: number }

function Geom.eps(): number
	return EPS
end

function Geom.finite(value: number): boolean
	return value == value and value ~= INF and value ~= -INF
end

function Geom.clamp(value: number, lo: number, hi: number): number
	if hi < lo then
		lo, hi = hi, lo
	end
	if not Geom.finite(value) then
		return lo
	end
	if value < lo then
		return lo
	end
	if value > hi then
		return hi
	end
	return value
end

function Geom.lerp(a: number, b: number, t: number): number
	return a + (b - a) * Geom.clamp(t, 0, 1)
end

function Geom.inverseLerp(a: number, b: number, value: number): number
	local span = b - a
	if math.abs(span) < EPS then
		return 0
	end
	return Geom.clamp((value - a) / span, 0, 1)
end

function Geom.smoothstep(t: number): number
	local x = Geom.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

function Geom.smootherstep(t: number): number
	local x = Geom.clamp(t, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

function Geom.sign(value: number): number
	if value > EPS then
		return 1
	end
	if value < -EPS then
		return -1
	end
	return 0
end

function Geom.snap(value: number, step: number): number
	if step <= EPS then
		return value
	end
	return math.floor(value / step + 0.5) * step
end

function Geom.snapPixel(value: number): number
	return math.floor(value + 0.5)
end

function Geom.approach(current: number, target: number, maxDelta: number): number
	local delta = target - current
	if math.abs(delta) <= maxDelta then
		return target
	end
	return current + Geom.sign(delta) * maxDelta
end

function Geom.damp(current: number, target: number, rate: number): number
	local t = Geom.clamp(rate, 0, 1)
	return current + (target - current) * t
end

function Geom.vec(x: number, y: number): Vec2
	return { x = x, y = y }
end

function Geom.vadd(a: Vec2, b: Vec2): Vec2
	return { x = a.x + b.x, y = a.y + b.y }
end

function Geom.vsub(a: Vec2, b: Vec2): Vec2
	return { x = a.x - b.x, y = a.y - b.y }
end

function Geom.vmul(a: Vec2, s: number): Vec2
	return { x = a.x * s, y = a.y * s }
end

function Geom.vdot(a: Vec2, b: Vec2): number
	return a.x * b.x + a.y * b.y
end

function Geom.vcross(a: Vec2, b: Vec2): number
	return a.x * b.y - a.y * b.x
end

function Geom.vlen2(a: Vec2): number
	return a.x * a.x + a.y * a.y
end

function Geom.vlen(a: Vec2): number
	return math.sqrt(Geom.vlen2(a))
end

function Geom.vnorm(a: Vec2): Vec2
	local length = Geom.vlen(a)
	if length < EPS then
		return { x = 0, y = 0 }
	end
	return { x = a.x / length, y = a.y / length }
end

function Geom.vperp(a: Vec2): Vec2
	return { x = -a.y, y = a.x }
end

function Geom.vreflect(direction: Vec2, normal: Vec2): Vec2
	local n = Geom.vnorm(normal)
	local scale = 2 * Geom.vdot(direction, n)
	return Geom.vsub(direction, Geom.vmul(n, scale))
end

function Geom.vproject(a: Vec2, onto: Vec2): Vec2
	local denom = Geom.vlen2(onto)
	if denom < EPS then
		return { x = 0, y = 0 }
	end
	return Geom.vmul(onto, Geom.vdot(a, onto) / denom)
end

function Geom.vrotate(a: Vec2, radians: number): Vec2
	local c = math.cos(radians)
	local s = math.sin(radians)
	return { x = a.x * c - a.y * s, y = a.x * s + a.y * c }
end

function Geom.vlerp(a: Vec2, b: Vec2, t: number): Vec2
	return { x = Geom.lerp(a.x, b.x, t), y = Geom.lerp(a.y, b.y, t) }
end

function Geom.vmin(a: Vec2, b: Vec2): Vec2
	return { x = math.min(a.x, b.x), y = math.min(a.y, b.y) }
end

function Geom.vmax(a: Vec2, b: Vec2): Vec2
	return { x = math.max(a.x, b.x), y = math.max(a.y, b.y) }
end

function Geom.vfloor(a: Vec2): Vec2
	return { x = Geom.snapPixel(a.x), y = Geom.snapPixel(a.y) }
end

function Geom.rect(x0: number, y0: number, x1: number, y1: number): Rect
	if x1 < x0 then
		x0, x1 = x1, x0
	end
	if y1 < y0 then
		y0, y1 = y1, y0
	end
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

function Geom.rectFromPosSize(x: number, y: number, w: number, h: number): Rect
	return Geom.rect(x, y, x + math.max(0, w), y + math.max(0, h))
end

function Geom.rectFromCenter(cx: number, cy: number, w: number, h: number): Rect
	return Geom.rectFromPosSize(cx - w * 0.5, cy - h * 0.5, w, h)
end

function Geom.rectWidth(r: Rect): number
	return math.max(0, r.x1 - r.x0)
end

function Geom.rectHeight(r: Rect): number
	return math.max(0, r.y1 - r.y0)
end

function Geom.rectArea(r: Rect): number
	return Geom.rectWidth(r) * Geom.rectHeight(r)
end

function Geom.rectCenter(r: Rect): Vec2
	return { x = (r.x0 + r.x1) * 0.5, y = (r.y0 + r.y1) * 0.5 }
end

function Geom.rectContainsPoint(r: Rect, p: Vec2, slop: number?): boolean
	local pad = slop or 0
	return p.x >= r.x0 - pad and p.x <= r.x1 + pad and p.y >= r.y0 - pad and p.y <= r.y1 + pad
end

function Geom.rectContainsRect(outer: Rect, inner: Rect, slop: number?): boolean
	local pad = slop or 0
	return inner.x0 >= outer.x0 - pad and inner.y0 >= outer.y0 - pad and inner.x1 <= outer.x1 + pad and inner.y1 <= outer.y1 + pad
end

function Geom.rectIntersects(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

function Geom.rectIntersection(a: Rect, b: Rect): Rect?
	local x0 = math.max(a.x0, b.x0)
	local y0 = math.max(a.y0, b.y0)
	local x1 = math.min(a.x1, b.x1)
	local y1 = math.min(a.y1, b.y1)
	if x1 <= x0 or y1 <= y0 then
		return nil
	end
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

function Geom.rectUnion(a: Rect, b: Rect): Rect
	return {
		x0 = math.min(a.x0, b.x0),
		y0 = math.min(a.y0, b.y0),
		x1 = math.max(a.x1, b.x1),
		y1 = math.max(a.y1, b.y1),
	}
end

function Geom.rectInflate(r: Rect, px: number, py: number?): Rect
	local dy = if py == nil then px else py
	return { x0 = r.x0 - px, y0 = r.y0 - dy, x1 = r.x1 + px, y1 = r.y1 + dy }
end

function Geom.rectTranslate(r: Rect, dx: number, dy: number): Rect
	return { x0 = r.x0 + dx, y0 = r.y0 + dy, x1 = r.x1 + dx, y1 = r.y1 + dy }
end

function Geom.overlapWidth(a: Rect, b: Rect): number
	return math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0))
end

function Geom.overlapHeight(a: Rect, b: Rect): number
	return math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0))
end

function Geom.overlapArea(a: Rect, b: Rect): number
	return Geom.overlapWidth(a, b) * Geom.overlapHeight(a, b)
end

function Geom.iou(a: Rect, b: Rect): number
	local inter = Geom.overlapArea(a, b)
	if inter <= 0 then
		return 0
	end
	local union = Geom.rectArea(a) + Geom.rectArea(b) - inter
	if union <= EPS then
		return 0
	end
	return inter / union
end

function Geom.coverage(inner: Rect, outer: Rect): number
	local area = Geom.rectArea(inner)
	if area <= EPS then
		return 0
	end
	return Geom.overlapArea(inner, outer) / area
end

-- How far `inner` sticks out of `outer` on each side. Positive means outside.
function Geom.overflow(inner: Rect, outer: Rect): Insets
	return {
		l = math.max(0, outer.x0 - inner.x0),
		t = math.max(0, outer.y0 - inner.y0),
		r = math.max(0, inner.x1 - outer.x1),
		b = math.max(0, inner.y1 - outer.y1),
	}
end

function Geom.overflowAmount(inner: Rect, outer: Rect): number
	local o = Geom.overflow(inner, outer)
	return o.l + o.t + o.r + o.b
end

function Geom.insets(l: number, t: number, r: number, b: number): Insets
	return { l = l, t = t, r = r, b = b }
end

function Geom.insetRect(r: Rect, pad: Insets): Rect
	local x0 = r.x0 + pad.l
	local y0 = r.y0 + pad.t
	local x1 = r.x1 - pad.r
	local y1 = r.y1 - pad.b
	if x1 < x0 then
		local mid = (x0 + x1) * 0.5
		x0, x1 = mid, mid
	end
	if y1 < y0 then
		local mid = (y0 + y1) * 0.5
		y0, y1 = mid, mid
	end
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

function Geom.udim(scale: number, offset: number, axis: number): number
	if not Geom.finite(scale) then
		scale = 0
	end
	if not Geom.finite(offset) then
		offset = 0
	end
	return scale * axis + offset
end

function Geom.splitUDim(pixels: number, axis: number, preferScale: boolean): UDim1
	if axis <= EPS or not preferScale then
		return { scale = 0, offset = pixels }
	end
	local scale = pixels / axis
	return { scale = scale, offset = 0 }
end

-- Move a top-left rect so it sits inside `box`, shrinking if it is larger.
-- Anchor is the point that should stay put when the size changes (0..1).
function Geom.fitRect(rect: Rect, box: Rect, anchorX: number, anchorY: number, minW: number, minH: number): Rect
	local boxW = Geom.rectWidth(box)
	local boxH = Geom.rectHeight(box)
	local w = Geom.clamp(Geom.rectWidth(rect), math.min(minW, boxW), boxW)
	local h = Geom.clamp(Geom.rectHeight(rect), math.min(minH, boxH), boxH)
	local ax = Geom.clamp(anchorX, 0, 1)
	local ay = Geom.clamp(anchorY, 0, 1)
	local anchorPx = rect.x0 + Geom.rectWidth(rect) * ax
	local anchorPy = rect.y0 + Geom.rectHeight(rect) * ay
	local x = anchorPx - w * ax
	local y = anchorPy - h * ay
	x = Geom.clamp(x, box.x0, box.x1 - w)
	y = Geom.clamp(y, box.y0, box.y1 - h)
	return Geom.rectFromPosSize(x, y, w, h)
end

-- Minimum translation that pushes `mover` out of `blocker`.
-- The vector is applied to mover. Nil when they do not overlap.
function Geom.separation(mover: Rect, blocker: Rect): Vec2?
	local iw = Geom.overlapWidth(mover, blocker)
	local ih = Geom.overlapHeight(mover, blocker)
	if iw <= EPS or ih <= EPS then
		return nil
	end
	local mc = Geom.rectCenter(mover)
	local bc = Geom.rectCenter(blocker)
	if iw < ih then
		local dir = if mc.x >= bc.x then 1 else -1
		return { x = dir * iw, y = 0 }
	end
	local dir = if mc.y >= bc.y then 1 else -1
	return { x = 0, y = dir * ih }
end

function Geom.corners(r: Rect): { Vec2 }
	return {
		{ x = r.x0, y = r.y0 },
		{ x = r.x1, y = r.y0 },
		{ x = r.x1, y = r.y1 },
		{ x = r.x0, y = r.y1 },
	}
end

function Geom.rotateCorners(r: Rect, radians: number): { Vec2 }
	local c = Geom.rectCenter(r)
	local out = {}
	for index, corner in Geom.corners(r) do
		local rel = Geom.vsub(corner, c)
		out[index] = Geom.vadd(c, Geom.vrotate(rel, radians))
	end
	return out
end

local function projectPolygon(points: { Vec2 }, axis: Vec2)
	local minV = INF
	local maxV = -INF
	for _, point in points do
		local d = Geom.vdot(point, axis)
		if d < minV then
			minV = d
		end
		if d > maxV then
			maxV = d
		end
	end
	return minV, maxV
end

local function edgeAxes(points: { Vec2 }): { Vec2 }
	local axes = {}
	for index = 1, #points do
		local a = points[index]
		local b = points[index % #points + 1]
		local edge = Geom.vsub(b, a)
		local normal = Geom.vnorm(Geom.vperp(edge))
		if Geom.vlen2(normal) > EPS then
			table.insert(axes, normal)
		end
	end
	return axes
end

-- Separating-axis overlap for two convex polygons. Returns the minimum
-- translation that pushes `a` out of `b`, or nil if they are disjoint.
function Geom.satMTV(aPoints: { Vec2 }, bPoints: { Vec2 }): Vec2?
	local axes = edgeAxes(aPoints)
	for _, axis in edgeAxes(bPoints) do
		table.insert(axes, axis)
	end
	local best = INF
	local bestAxis: Vec2? = nil
	for _, axis in axes do
		local a0, a1 = projectPolygon(aPoints, axis)
		local b0, b1 = projectPolygon(bPoints, axis)
		local overlap = math.min(a1, b1) - math.max(a0, b0)
		if overlap <= EPS then
			return nil
		end
		if overlap < best then
			best = overlap
			bestAxis = axis
		end
	end
	if bestAxis == nil then
		return nil
	end
	local ac = { x = 0, y = 0 }
	local bc = { x = 0, y = 0 }
	for _, point in aPoints do
		ac = Geom.vadd(ac, point)
	end
	for _, point in bPoints do
		bc = Geom.vadd(bc, point)
	end
	ac = Geom.vmul(ac, 1 / math.max(1, #aPoints))
	bc = Geom.vmul(bc, 1 / math.max(1, #bPoints))
	local direction = Geom.vsub(ac, bc)
	if Geom.vdot(direction, bestAxis) < 0 then
		bestAxis = Geom.vmul(bestAxis, -1)
	end
	return Geom.vmul(Geom.vnorm(bestAxis), best)
end

function Geom.obbMTV(a: Rect, aRot: number, b: Rect, bRot: number): Vec2?
	if math.abs(aRot) < EPS and math.abs(bRot) < EPS then
		return Geom.separation(a, b)
	end
	return Geom.satMTV(Geom.rotateCorners(a, aRot), Geom.rotateCorners(b, bRot))
end

export type SpatialCell = { Rect }
export type SpatialHash = {
	cell: number,
	buckets: { [string]: { number } },
}

function Geom.spatial(cell: number): SpatialHash
	return { cell = math.max(8, cell), buckets = {} }
end

local function cellKey(ix: number, iy: number): string
	return tostring(ix) .. ":" .. tostring(iy)
end

function Geom.spatialInsert(hash: SpatialHash, index: number, r: Rect)
	local cell = hash.cell
	local x0 = math.floor(r.x0 / cell)
	local y0 = math.floor(r.y0 / cell)
	local x1 = math.floor(r.x1 / cell)
	local y1 = math.floor(r.y1 / cell)
	for ix = x0, x1 do
		for iy = y0, y1 do
			local key = cellKey(ix, iy)
			local bucket = hash.buckets[key]
			if bucket == nil then
				bucket = {}
				hash.buckets[key] = bucket
			end
			table.insert(bucket, index)
		end
	end
end

function Geom.spatialQuery(hash: SpatialHash, r: Rect): { number }
	local seen = {}
	local hits = {}
	local cell = hash.cell
	local x0 = math.floor(r.x0 / cell)
	local y0 = math.floor(r.y0 / cell)
	local x1 = math.floor(r.x1 / cell)
	local y1 = math.floor(r.y1 / cell)
	for ix = x0, x1 do
		for iy = y0, y1 do
			local bucket = hash.buckets[cellKey(ix, iy)]
			if bucket ~= nil then
				for _, index in bucket do
					if not seen[index] then
						seen[index] = true
						table.insert(hits, index)
					end
				end
			end
		end
	end
	return hits
end

-- Sweep-and-prune on X, then test Y. Returns unique pairs (i < j).
function Geom.sweepPairs(rects: { Rect }): { { number } }
	local order = table.create(#rects)
	for index = 1, #rects do
		order[index] = index
	end
	table.sort(order, function(a, b)
		return rects[a].x0 < rects[b].x0
	end)
	local pairs = {}
	local active: { number } = {}
	for _, index in order do
		local rect = rects[index]
		local nextActive = {}
		for _, other in active do
			local orect = rects[other]
			if orect.x1 > rect.x0 then
				table.insert(nextActive, other)
				if Geom.overlapHeight(rect, orect) > EPS then
					local lo = math.min(index, other)
					local hi = math.max(index, other)
					table.insert(pairs, { lo, hi })
				end
			end
		end
		table.insert(nextActive, index)
		active = nextActive
	end
	return pairs
end

-- Reading-order key: top band first, then left to right. Band height is the
-- median item height so a tall card does not pull an entire column together.
function Geom.readingOrder(rects: { Rect }, band: number): { number }
	local order = table.create(#rects)
	for index = 1, #rects do
		order[index] = index
	end
	table.sort(order, function(a, b)
		local ra = rects[a]
		local rb = rects[b]
		local bandA = math.floor(ra.y0 / math.max(8, band))
		local bandB = math.floor(rb.y0 / math.max(8, band))
		if bandA ~= bandB then
			return bandA < bandB
		end
		if math.abs(ra.x0 - rb.x0) > EPS then
			return ra.x0 < rb.x0
		end
		return a < b
	end)
	return order
end

function Geom.rowBands(rects: { Rect }, slack: number): { { number } }
	local order = Geom.readingOrder(rects, 1)
	local rows: { { number } } = {}
	local current: { number } = {}
	local bandBottom = -INF
	for _, index in order do
		local rect = rects[index]
		if #current == 0 or rect.y0 <= bandBottom + slack then
			table.insert(current, index)
			bandBottom = math.max(bandBottom, rect.y1)
		else
			table.insert(rows, current)
			current = { index }
			bandBottom = rect.y1
		end
	end
	if #current > 0 then
		table.insert(rows, current)
	end
	return rows
end

-- Spread items in a row so gaps are at least `gap`, keeping the row's left
-- edge. Returns new x positions keyed by index. Items that do not fit are
-- compressed down toward minW.
function Geom.packRow(rects: { Rect }, indexes: { number }, gap: number, minW: number, rightLimit: number): { [number]: number }
	local placed: { [number]: number } = {}
	if #indexes == 0 then
		return placed
	end
	local cursor = rects[indexes[1]].x0
	local total = gap * math.max(0, #indexes - 1)
	for _, index in indexes do
		total += math.max(minW, Geom.rectWidth(rects[index]))
	end
	local available = rightLimit - cursor
	local scale = 1
	if total > available and total > EPS then
		scale = math.max(0.45, available / total)
	end
	for _, index in indexes do
		local width = math.max(minW, Geom.rectWidth(rects[index]) * scale)
		if cursor + width > rightLimit and cursor > rects[indexes[1]].x0 then
			width = math.max(minW, rightLimit - cursor)
		end
		placed[index] = cursor
		cursor += width + gap
	end
	return placed
end

function Geom.packColumn(rects: { Rect }, indexes: { number }, gap: number, minH: number, bottomLimit: number): { [number]: number }
	local placed: { [number]: number } = {}
	if #indexes == 0 then
		return placed
	end
	local cursor = rects[indexes[1]].y0
	for _, index in indexes do
		local height = math.max(minH, Geom.rectHeight(rects[index]))
		if cursor + height > bottomLimit and cursor > rects[indexes[1]].y0 then
			height = math.max(minH * 0.5, bottomLimit - cursor)
		end
		placed[index] = cursor
		cursor += height + gap
	end
	return placed
end

-- Binary search a uniform scale so `text` of design size fits in the box.
-- `measure(size) -> width, height` is supplied by the caller (live text or a stub).
function Geom.fitTextScale(boxW: number, boxH: number, design: number, minSize: number, maxSize: number, measure: (number) -> (number, number)): number
	local lo = math.max(1, minSize)
	local hi = math.max(lo, math.min(maxSize, design))
	if boxW <= 1 or boxH <= 1 then
		return lo
	end
	local best = lo
	for _ = 1, 12 do
		local mid = (lo + hi) * 0.5
		local w, h = measure(mid)
		if w <= boxW + 0.5 and h <= boxH + 0.5 then
			best = mid
			lo = mid
		else
			hi = mid
		end
		if hi - lo < 0.25 then
			break
		end
	end
	return best
end

-- Gauss-Seidel step: move `value` toward `target` but never more than `limit`
-- and never in a way that increases a recorded residual.
function Geom.projectScalar(value: number, target: number, limit: number, residual: number): (number, number)
	local delta = Geom.clamp(target - value, -limit, limit)
	local nextValue = value + delta
	local nextResidual = math.abs(target - nextValue)
	if nextResidual > residual + EPS and residual < INF / 2 then
		nextValue = Geom.damp(value, target, 0.35)
		nextResidual = math.abs(target - nextValue)
	end
	return nextValue, nextResidual
end

function Geom.anchorTopLeft(anchorX: number, anchorY: number, x: number, y: number, w: number, h: number): Vec2
	return { x = x - w * anchorX, y = y - h * anchorY }
end

function Geom.topLeftToAnchor(anchorX: number, anchorY: number, x: number, y: number, w: number, h: number): Vec2
	return { x = x + w * anchorX, y = y + h * anchorY }
end

-- Convert an absolute top-left delta into a Position offset delta, compensating
-- for the way Roblox shifts the top-left when Size changes around AnchorPoint.
function Geom.offsetDelta(anchorX: number, anchorY: number, dx: number, dy: number, dw: number, dh: number): Vec2
	return {
		x = dx + anchorX * dw,
		y = dy + anchorY * dh,
	}
end

return Geom
