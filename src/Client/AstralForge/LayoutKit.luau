--!nonstrict
--[=[
	LayoutKit: merged module suite.
	Members (8): layoutGeom, layoutGuardPlan, layoutSectionPlan, pageScaffold, pageScaffoldPlan, pageReadyMath, scrolling, virtualizedList.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("LayoutKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("LayoutKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: layoutGeom   (merged from layoutGeom.luau, 703 lines)
-- ======================================================================
__defs["layoutGeom"] = function()
-- Layout geometry. Pure numbers: vectors, rectangles, rotated boxes, UDim
-- evaluation, anchors, and a spatial hash. No Roblox instances.

local Geom = {}

local EPS = 1e-4
local INF = math.huge

type Vec2 = { x: number, y: number }
type Rect = { x0: number, y0: number, x1: number, y1: number }
type Insets = { l: number, t: number, r: number, b: number }
type UDim1 = { scale: number, offset: number }

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

type SpatialCell = { Rect }
type SpatialHash = {
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
end

-- ======================================================================
-- Module: layoutGuardPlan   (merged from layoutGuardPlan.luau, 83 lines)
-- ======================================================================
__defs["layoutGuardPlan"] = function()
-- Scheduling and thresholds for the layout guard (layoutGuard.luau).
--
-- The guard used to wake every two seconds and repair a slice of the tree, so
-- a label that overflowed after a page opened or a phone rotated could sit
-- broken for seconds. It now works every frame on a small budget:
--
--   * fresh work first -- anything just mounted or just repaired and awaiting
--     a check -- one frame after it appears, once the engine has measured it;
--   * a continuous background sweep over everything else, so a label whose
--     text grew is caught within about a second;
--   * a burst after a resize or rotation: a large budget for a dozen frames,
--     so the whole screen settles almost at once.
--
-- Pure numbers only, so scripts/verify_layout_realtime.luau can hold it to
-- its promises under Lune.

local Plan = {}

-- Per-frame budgets (instances inspected).
Plan.FRESH_PER_FRAME = 96
Plan.SWEEP_PER_FRAME = 48
Plan.BURST_PER_FRAME = 320
-- Frames of burst after a resize or rotation.
Plan.BURST_FRAMES = 12
-- A new instance waits this many frames so its AbsoluteSize is real.
Plan.SETTLE_FRAMES = 1
-- The sweep never restarts more often than this (a restart walks the tree).
Plan.MIN_SWEEP_SECONDS = 0.75
-- More fresh work than this and the rest rides the sweep instead.
Plan.FRESH_CAP = 4000
-- A repair that doesn't stick after this many tries is abandoned.
Plan.MAX_TRIES = 3
-- A resize smaller than this (either axis) is jitter, not a new layout.
Plan.RESIZE_SLOP = 8
-- On touch screens text below this size is raised when it still fits.
Plan.TOUCH_TEXT_FLOOR = 11
-- Text this small is decorative (glyph badges, tick marks); leave it alone.
Plan.TEXT_FLOOR_MIN_SOURCE = 7

type Budget = { fresh: number, sweep: number }

-- How much to inspect this frame.
function Plan.budget(burstFramesLeft: number, freshWaiting: number): Budget
	if burstFramesLeft > 0 then
		-- Everything gets the burst budget; fresh work goes first within it.
		local fresh = math.min(freshWaiting, Plan.BURST_PER_FRAME)
		return { fresh = fresh, sweep = Plan.BURST_PER_FRAME - fresh }
	end
	return { fresh = math.min(freshWaiting, Plan.FRESH_PER_FRAME), sweep = Plan.SWEEP_PER_FRAME }
end

-- Did the screen change enough to call for a fresh layout pass?
function Plan.resized(lastWidth: number, lastHeight: number, width: number, height: number): boolean
	if lastWidth < 0 or lastHeight < 0 then
		return true
	end
	local rotated = (lastWidth > lastHeight) ~= (width > height) and math.abs(width - height) > Plan.RESIZE_SLOP
	return rotated or math.abs(width - lastWidth) >= Plan.RESIZE_SLOP or math.abs(height - lastHeight) >= Plan.RESIZE_SLOP
end

-- The size to raise a touch-screen label to, or nil to leave it.
function Plan.textFloor(touch: boolean, textSize: number, scaled: boolean): number?
	if not touch or scaled then
		return nil
	end
	if textSize >= Plan.TOUCH_TEXT_FLOOR or textSize < Plan.TEXT_FLOOR_MIN_SOURCE then
		return nil
	end
	return Plan.TOUCH_TEXT_FLOOR
end

-- Frames for one full sweep of `count` instances at the steady budget.
function Plan.sweepFrames(count: number): number
	return math.max(1, math.ceil(math.max(0, count) / Plan.SWEEP_PER_FRAME))
end

-- Seconds before a changed label is caught, worst case, at `fps`.
function Plan.worstCatchSeconds(count: number, fps: number): number
	return math.max(Plan.MIN_SWEEP_SECONDS, Plan.sweepFrames(count) / math.max(1, fps))
end

return table.freeze(Plan)
end

-- ======================================================================
-- Module: layoutSectionPlan   (merged from layoutSectionPlan.luau, 189 lines)
-- ======================================================================
__defs["layoutSectionPlan"] = function()
-- Pure layout section planners for Overview bands and Workspace chrome.
-- No Roblox / React — PageRouter / MainGame and Lune verify scripts share
-- these so section heights stay testable without Studio. Behavior mirrors
-- the prior inline math; callers inject chrome/theme constants.

local LayoutSectionPlan = {}

type OverviewFlags = {
	stack: boolean,
	phone: boolean,
	landscapePhone: boolean,
	wideOverview: boolean,
	ultraOverview: boolean,
	rebirthVisible: boolean,
	domainVisible: boolean,
	countdownInPage: boolean,
	short: boolean,
	chromePanelGap: number,
	layoutPanelGap: number,
	fitHeight: number?,
}

type OverviewPlan = {
	heroH: number,
	rebirthH: number,
	domainH: number,
	notesH: number,
	opsH: number,
	metricCardH: number,
	metricsH: number,
	countdownH: number,
	sectionGap: number,
	topBandH: number,
	sectionCount: number,
	overviewTail: number,
	contentIntrinsic: number,
}

type WorkspaceFlags = {
	keyboardCompact: boolean,
	stack: boolean,
	landscape: boolean,
	workspaceHeaderH: number,
	layoutWorkspaceHeaderHeight: number,
	tapTarget: number,
	showNextGoal: boolean,
}

type WorkspacePlan = {
	headerHeight: number,
	unlockH: number,
}

function LayoutSectionPlan.planOverview(flags: OverviewFlags): OverviewPlan
	local stack = flags.stack == true
	local phone = flags.phone == true
	local landscapePhone = flags.landscapePhone == true
	local wideOverview = flags.wideOverview == true
	local ultraOverview = flags.ultraOverview == true
	local rebirthVisible = flags.rebirthVisible == true
	local domainVisible = flags.domainVisible == true
	local countdownInPage = flags.countdownInPage == true
	local short = flags.short == true and not stack
	local chromePanelGap = tonumber(flags.chromePanelGap) or 10
	local layoutPanelGap = tonumber(flags.layoutPanelGap) or 14

	local heroH = if landscapePhone
		then 176
		elseif phone then 272
		elseif short and wideOverview then 260
		elseif short then 248
		elseif ultraOverview then 268
		elseif wideOverview then 258
		else 248
	local rebirthH = if rebirthVisible
		then (if phone then (if landscapePhone then 248 else 300) else (if ultraOverview then 220 else 208))
		else 0
	local domainH = if domainVisible
		then (if phone then (if landscapePhone then 268 else 320) else (if ultraOverview then 236 else 224))
		else 0
	local notesH = if stack
		then (if landscapePhone then 132 else 168)
		elseif short then 168
		else (if ultraOverview then 160 else 148)
	-- Ops Pulse: phone uses a 2×2 claim grid so Collect stays above the fold.
	local opsH = if landscapePhone then 156 elseif stack then 196 else (if short or ultraOverview then 176 else 172)
	local metricCardH = if stack
		then (if landscapePhone then 72 else 92)
		elseif wideOverview then (if ultraOverview then 84 else 80)
		else 0
	local metricsH = if stack then metricCardH * 3 + 16 elseif wideOverview then heroH else 104
	local countdownH = if countdownInPage
		then (if stack then (if landscapePhone then 128 else 168) else (if ultraOverview then 152 else 140))
		else 0
	-- topBandH collapses hero+metrics into one row on wide PC; remaining sections still stack.
	local sectionGap = if stack
		then chromePanelGap
		elseif short then 10
		elseif ultraOverview then 18
		elseif wideOverview then 16
		else layoutPanelGap
	-- Short PC windows only have a few hundred pixels under the chrome. Pack the
	-- hero and the next-goal card into that budget so the fold lands on a gap
	-- instead of slicing a panel in half.
	local fitHeight = tonumber(flags.fitHeight)
	if short and wideOverview and fitHeight ~= nil and fitHeight > 0 then
		sectionGap = 8
		metricCardH = 72
		local heroFloor = 212
		local notesFloor = 146
		local pair = heroFloor + notesFloor + sectionGap
		if fitHeight <= pair then
			heroH = heroFloor
			notesH = math.max(140, notesFloor - (pair - fitHeight))
		else
			heroH = math.min(240, heroFloor + (fitHeight - pair))
			notesH = notesFloor
		end
		metricsH = heroH
	end
	local topBandH = if wideOverview then heroH else heroH + metricsH + sectionGap
	local sectionCount = 1
		+ 1
		+ 1
		+ (if countdownInPage then 1 else 0)
		+ (if rebirthVisible then 1 else 0)
		+ (if domainVisible then 1 else 0)
	local overviewTail = if landscapePhone then 48 elseif stack then 56 else (if ultraOverview then 48 else 40)
	local contentIntrinsic = topBandH
		+ notesH
		+ opsH
		+ countdownH
		+ rebirthH
		+ domainH
		+ sectionGap * math.max(0, sectionCount - 1)

	return {
		heroH = heroH,
		rebirthH = rebirthH,
		domainH = domainH,
		notesH = notesH,
		opsH = opsH,
		metricCardH = metricCardH,
		metricsH = metricsH,
		countdownH = countdownH,
		sectionGap = sectionGap,
		topBandH = topBandH,
		sectionCount = sectionCount,
		overviewTail = overviewTail,
		contentIntrinsic = contentIntrinsic,
	}
end

function LayoutSectionPlan.planWorkspace(flags: WorkspaceFlags): WorkspacePlan
	local keyboardCompact = flags.keyboardCompact == true
	local stack = flags.stack == true
	local landscape = flags.landscape == true
	local workspaceHeaderH = tonumber(flags.workspaceHeaderH) or 0
	local layoutWorkspaceHeaderHeight = tonumber(flags.layoutWorkspaceHeaderHeight) or 86
	local tapTarget = tonumber(flags.tapTarget) or 48
	local showNextGoal = flags.showNextGoal == true

	-- Phone stack uses MobileHeader for page chrome, so chrome.workspaceHeaderH is 0 and the
	-- Workspace title/collect strip must stay collapsed — otherwise we double-tax vertical
	-- space and first-screen CTAs fall below the fold. Keyboard-open with a zero plan header
	-- stays collapsed (MobileHeader + tab bar are already hidden in that mode).
	local headerHeight: number
	if keyboardCompact then
		headerHeight = if landscape or workspaceHeaderH <= 0 then 0 else tapTarget
	elseif stack then
		headerHeight = workspaceHeaderH
	else
		headerHeight = if workspaceHeaderH > 0 then workspaceHeaderH else layoutWorkspaceHeaderHeight
	end

	-- Next-goal strip: skip on landscape and whenever the workspace header itself is gone.
	local unlockH = 0
	if not keyboardCompact and not landscape and headerHeight > 0 and showNextGoal then
		unlockH = 32
	end

	return {
		headerHeight = headerHeight,
		unlockH = unlockH,
	}
end

return table.freeze(LayoutSectionPlan)
end

-- ======================================================================
-- Module: pageScaffold   (merged from pageScaffold.luau, 154 lines)
-- ======================================================================
__defs["pageScaffold"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Palette = require(script.Parent.CoreKit)("theme").Palette
local planFillHeight = __load("pageScaffoldPlan").planFillHeight
local planFittedHeights = __load("pageScaffoldPlan").planFittedHeights
local planOverflow = __load("pageScaffoldPlan").planOverflow
local PageScrollContext = __load("scrolling").PageScrollContext
local function SpringSection(props)
	return React.createElement("frame", {
		ref = props.frameRef,
		Size = UDim2.new(1, 0, 0, math.max(0, props.height)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ClipsDescendants = false,
	}, props.element)
end
-- PageScaffold — the one vertical-stack layout primitive pages should use instead of hand-
-- computed absolute bands. Every "mobile layout bug" class this project has hit (negative
-- heights from `Size = 1, -(a + b + c)`, action bars landing on top of lists, content that
-- can never be scrolled to) came from pages positioning fixed-height sections against the
-- viewport themselves. This component removes the entire class:
--
--   - Sections are declared as `fixed` (intrinsic pixel height) or `fill` (takes whatever
--     space is left over, never less than `minHeight`, and never less than an optional
--     intrinsic `height` content floor used by hostRef VirtualGrid lists).
--   - The scaffold measures its own rendered height, so it works identically in a page, an
--     overlay, or a drawer — no caller passes viewport math in.
--   - If the sections' minimum total exceeds the available space, the whole thing becomes a
--     scrolling flow. Content is always reachable; nothing ever goes negative or overlaps.
--
-- Usage mirrors how the desktop pages were already built (list of sections), so the same
-- structure now renders correctly at 1440x900 and at 568x320 with zero per-device math.
local function PageScaffold(_param)
	local sections = _param.sections
	local gap = _param.gap
	if gap == nil then
		gap = 10
	end
	local tailPad = _param.tailPad
	if tailPad == nil then
		tailPad = 8
	end
	local inset = _param.inset
	if inset == nil then
		inset = 0
	end
	local scrollBarThickness = _param.scrollBarThickness
	if scrollBarThickness == nil then
		scrollBarThickness = 3
	end
	local scrollBarColor = _param.scrollBarColor
	local size = _param.size
	if size == nil then
		size = UDim2.fromScale(1, 1)
	end
	local position = _param.position
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 1
	end
	-- Optional hostRef lets VirtualGrid / focus callers bind the same ScrollingFrame
	-- PageScaffold owns (Command-style lists) without a second outer scroll.
	local internalRef = React.useRef()
	local hostRef = _param.hostRef
	if hostRef == nil then
		hostRef = internalRef
	end
	local available, setAvailable = React.useState(0)
	React.useEffect(function()
		local host = hostRef.current
		if host == nil then
			return nil
		end
		local sync = function()
			local height = math.max(0, math.floor(host.AbsoluteSize.Y + 0.5))
			setAvailable(function(current)
				return if current == height then current else height
			end)
		end
		sync()
		local connection = host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(section)
		return section.fill == true
	end
	local _result
	for _i, _v in sections do
		if _callback(_v, _i - 1, sections) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	-- When the sections can't all fit (short phones, landscape), the page itself has to scroll.
	-- A list in the fill section then joins that scroll instead of nesting a second scroller:
	-- it reports its full content height here, and the fill section grows to hold it.
	local overflowing = planOverflow(sections, available, gap, tailPad)
	local fillContent, setFillContent = React.useState(0)
	local reportFill = React.useCallback(function(height)
		local rounded = math.max(0, math.ceil(height))
		setFillContent(function(current)
			return if current == rounded then current else rounded
		end)
	end, {})
	local fillSectionRef = React.useRef()
	local scrollContext = React.useMemo(function()
		return {
			hostRef = hostRef,
			sectionRef = fillSectionRef,
			overflowing = overflowing,
			report = reportFill,
		}
	end, { overflowing, hostRef })
	local planSections = sections
	if overflowing and fillContent > 0 then
		planSections = table.create(#sections)
		for index, section in sections do
			if section.fill == true then
				local grown = table.clone(section)
				grown.height = math.max(section.height or 0, fillContent)
				planSections[index] = grown
			else
				planSections[index] = section
			end
		end
	end
	local fittedHeights = planFittedHeights(planSections, available, gap, tailPad)
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap),
	})
	local _exp_1 = inset > 0 and React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, inset),
		PaddingRight = UDim.new(0, inset),
		PaddingTop = UDim.new(0, inset),
		PaddingBottom = UDim.new(0, inset),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#sections)
	local _callback_2 = function(section, index)
		local _attributes = {
			key = section.id,
		}
		local _result_3 = fittedHeights[index + 1]
		if _result_3 == nil then
			_result_3 = 0
		end
		_attributes.height = _result_3
		_attributes.layoutOrder = index
		_attributes.element = if section.fill == true
			then React.createElement(PageScrollContext.Provider, { value = scrollContext }, section.element)
			else section.element
		if section.fill == true then
			_attributes.frameRef = fillSectionRef
		end
		return React.createElement(SpringSection, _attributes)
	end
	for _k, _v in sections do
		_newValue[_k] = _callback_2(_v, _k - 1, sections)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("scrollingframe", {
		ref = hostRef,
		Size = size,
		Position = position,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = scrollBarThickness,
		ScrollBarImageColor3 = scrollBarColor or Palette.muted,
		ScrollBarImageTransparency = 0.42,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = zIndex,
	}, _exp, _exp_1, _newValue, tailPad > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, tailPad),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = #sections,
	}))
end
return {
	PageScaffold = PageScaffold,
	planFillHeight = planFillHeight,
}
end

-- ======================================================================
-- Module: pageScaffoldPlan   (merged from pageScaffoldPlan.luau, 86 lines)
-- ======================================================================
__defs["pageScaffoldPlan"] = function()
-- Pure PageScaffold fill planner for offline CI (no React / Roblox runtime).

local function planFillHeight(sections: { any }, availableHeight: number, gap: number?, tailPad: number?): number
	local resolvedGap = if gap == nil then 10 else gap
	local resolvedTail = if tailPad == nil then 8 else tailPad
	local fillSection = nil
	local fixedTotal = 0
	for _, section in sections do
		if section.fill == true then
			fillSection = section
		else
			local height = section.height
			if height == nil then
				height = 0
			end
			fixedTotal += height
		end
	end
	if fillSection == nil then
		return 0
	end
	local gapsTotal = resolvedGap * math.max(0, #sections - 1)
	local minHeight = fillSection.minHeight
	if minHeight == nil then
		minHeight = 120
	end
	-- Optional intrinsic `height` on a fill section is a content floor: VirtualGrid /
	-- hostRef lists need the section tall enough for every row, while still expanding
	-- into leftover viewport when the list is shorter than the pane.
	local contentFloor = fillSection.height
	if contentFloor == nil then
		contentFloor = 0
	end
	return math.max(minHeight, contentFloor, availableHeight - fixedTotal - gapsTotal - resolvedTail)
end

-- When only a short sliver of the next card would show, grow the last section that
-- fully fits so the fold lands on a gap. A large remainder stays scrollable content.
local function planFittedHeights(sections: { any }, availableHeight: number, gap: number?, tailPad: number?): { number }
	local resolvedGap = if gap == nil then 10 else gap
	local fillHeight = planFillHeight(sections, availableHeight, gap, tailPad)
	local heights = table.create(#sections)
	for index, section in sections do
		if section.fill == true then
			heights[index] = fillHeight
		else
			local height = section.height
			heights[index] = if height == nil then 0 else height
		end
	end
	if availableHeight <= 0 or #heights <= 1 then
		return heights
	end
	local cursor = 0
	local lastFit = 0
	for index, height in heights do
		if cursor + height > availableHeight then
			break
		end
		lastFit = index
		cursor += height
		if index < #heights then
			cursor += resolvedGap
		end
	end
	if lastFit == 0 or lastFit == #heights then
		return heights
	end
	local extra = availableHeight - cursor
	local nextHeight = heights[lastFit + 1]
	if nextHeight == nil then
		nextHeight = 0
	end
	-- 96 covers the layout test's 81px peek. Hundreds of leftover pixels are the
	-- next card, and folding them into the previous section leaves an empty panel.
	if extra > 0 and extra <= 96 and extra < nextHeight then
		heights[lastFit] += extra
	end
	return heights
end

-- True when the sections' minimum total (fixed heights, gaps, tail, and the fill section's
-- minHeight) doesn't fit, i.e. the scaffold itself has to scroll. It deliberately ignores how
-- tall a list in the fill section wants to be, so a list joining the page scroll can't flip it.
local function planOverflow(sections: { any }, availableHeight: number, gap: number?, tailPad: number?): boolean
	if availableHeight <= 0 then
		return false
	end
	local resolvedGap = if gap == nil then 10 else gap
	local resolvedTail = if tailPad == nil then 8 else tailPad
	local total = resolvedGap * math.max(0, #sections - 1) + resolvedTail
	local hasFill = false
	for _, section in sections do
		if section.fill == true then
			hasFill = true
			total += if section.minHeight == nil then 120 else section.minHeight
		else
			total += section.height or 0
		end
	end
	return hasFill and total > availableHeight + 0.5
end

return {
	planFillHeight = planFillHeight,
	planFittedHeights = planFittedHeights,
	planOverflow = planOverflow,
}
end

-- ======================================================================
-- Module: pageReadyMath   (merged from pageReadyMath.luau, 148 lines)
-- ======================================================================
__defs["pageReadyMath"] = function()
-- Pure PageRouter readiness / crew-snapshot helpers. No Roblox services —
-- Overview badges, Forge Path CTA readiness, and Crew roster equality can be
-- asserted under Lune without Studio. Partial quest/lab/forge bags must not throw.

local PageReadyMath = {}

function PageReadyMath.CountReadyQuests(quests: any): number
	local ready = 0
	if type(quests) ~= "table" then
		return 0
	end
	for _, quest in quests do
		if type(quest) == "table" and not quest.Claimed then
			local progress = tonumber(quest.Progress) or 0
			local target = tonumber(quest.Target) or 0
			if target > 0 and progress >= target then
				ready += 1
			end
		end
	end
	return ready
end

function PageReadyMath.CountReadyLabOrders(lab: any): number
	local ready = 0
	if type(lab) ~= "table" or type(lab.Orders) ~= "table" then
		return 0
	end
	for _, order in lab.Orders do
		if type(order) == "table" and not order.Claimed then
			local progress = tonumber(order.Progress) or 0
			local target = tonumber(order.Target) or 0
			if target > 0 and progress >= target then
				ready += 1
			end
		end
	end
	return ready
end

function PageReadyMath.ForgePathReady(state: any, config: any): boolean
	if type(state) ~= "table" then
		return false
	end
	local forgePath = state.ForgePath
	if type(forgePath) ~= "table" then
		return false
	end
	local steps = nil
	if type(config) == "table" and type(config.ForgePath) == "table" then
		steps = config.ForgePath.Steps
	end
	if type(steps) ~= "table" or #steps == 0 then
		return false
	end
	local claimed = {}
	local claimedSteps = forgePath.ClaimedSteps
	if type(claimedSteps) == "table" then
		for _, stepId in claimedSteps do
			claimed[stepId] = true
		end
	end
	local xp = tonumber(forgePath.XP) or 0
	for _, step in steps do
		if type(step) == "table" and claimed[step.Step] == nil then
			local unlocked = step.Step == 1 or claimed[step.Step - 1] ~= nil
			if unlocked then
				return xp >= (tonumber(step.XPCost) or 0)
			end
			return false
		end
	end
	return false
end

local CREW_KEYS = {
	"UserId",
	"Name",
	"DisplayName",
	"CurrentZone",
	"Rebirths",
	"Production",
	"LifetimeCash",
	"IsLocal",
	"CurrentPage",
}

function PageReadyMath.SameCrewSnapshot(left: any, right: any): boolean
	if type(left) ~= "table" or type(right) ~= "table" then
		return left == right
	end
	if #left ~= #right then
		return false
	end
	for index = 1, #left do
		local a = left[index]
		local b = right[index]
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		for _, key in CREW_KEYS do
			if a[key] ~= b[key] then
				return false
			end
		end
	end
	return true
end

-- Overview ops strip: anomaly pulse ready or any unclaimed met directive.
function PageReadyMath.AnomalyReady(anomaly: any): boolean
	if type(anomaly) ~= "table" then
		return false
	end
	if anomaly.Ready == true then
		return true
	end
	local directives = anomaly.Directives
	if type(directives) ~= "table" then
		return false
	end
	for _, directive in directives do
		if type(directive) == "table" and not directive.Claimed then
			local progress = tonumber(directive.Progress)
			local target = tonumber(directive.Target)
			if progress ~= nil and target ~= nil and progress >= target then
				return true
			end
		end
	end
	return false
end

-- Sum of ready mission/lab/path/anomaly claim badges on Overview ops rail.
function PageReadyMath.OpsClaims(missionsReady: any, labReady: any, pathReady: any, anomalyReady: any): number
	local total = math.max(0, math.floor(tonumber(missionsReady) or 0))
		+ math.max(0, math.floor(tonumber(labReady) or 0))
	if pathReady then
		total += 1
	end
	if anomalyReady then
		total += 1
	end
	return total
end

return table.freeze(PageReadyMath)
end

-- ======================================================================
-- Module: scrolling   (merged from scrolling.luau, 810 lines)
-- ======================================================================
__defs["scrolling"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local LayoutUtil = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].layoututil.src)
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local PACK_BREAKPOINTS = require(script.Parent.MotionKit)("flexbox").PACK_BREAKPOINTS
local installed = false
local scrollPreference = 0.6
local momentumPreference = 0.75
local titleFxHoldGeneration = 0
local titleFxHeld = false
local motions = {}
local motionCount = 0
local gamepadAxis = Vector2.zero
local lastScrollSound = -math.huge
local motionDriver
local globalConnections = {}
-- Touch/console: coast on Heartbeat at half rate so RenderStepped stays free
-- for layout/input. Desktop keeps RenderStepped for snappier mouse-wheel feel.
local CONSTRAINED_SCROLL = (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled)
-- Called on every CanvasPosition change (per frame during a fling) and every
-- impulse. It used to start a fresh task.delay each time; now it only moves a
-- deadline, and one watcher runs for the whole scroll.
local titleFxHoldUntil = 0
local function holdTitleFx()
	titleFxHoldUntil = os.clock() + 0.16
	if titleFxHeld then
		return
	end
	titleFxHeld = true
	pcall(function()
		return Workspace:SetAttribute("AF_TitleFxHold", true)
	end)
	titleFxHoldGeneration += 1
	local generation = titleFxHoldGeneration
	task.spawn(function()
		while generation == titleFxHoldGeneration and os.clock() < titleFxHoldUntil do
			task.wait(0.05)
		end
		if generation ~= titleFxHoldGeneration then
			return nil
		end
		titleFxHeld = false
		pcall(function()
			return Workspace:SetAttribute("AF_TitleFxHold", false)
		end)
	end)
end
local function disposeScrollPerformance()
	installed = false
	titleFxHoldGeneration += 1
	titleFxHeld = false
	pcall(function()
		return Workspace:SetAttribute("AF_TitleFxHold", false)
	end)
	for _, connection in globalConnections do
		connection:Disconnect()
	end
	table.clear(globalConnections)
	local _result = motionDriver
	if _result ~= nil then
		_result:Disconnect()
	end
	motionDriver = nil
	table.clear(motions)
	motionCount = 0
	gamepadAxis = Vector2.zero
end
local function setScrollSpeed(value)
	scrollPreference = math.clamp(value, 0, 1)
end
local function setScrollMomentum(value)
	momentumPreference = math.clamp(value, 0, 1)
end
local function scrollingAncestor(instance)
	local cursor = instance
	while cursor ~= nil do
		if cursor:IsA("ScrollingFrame") and cursor.Visible and cursor.ScrollingEnabled then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end
local function frameUnderPointer(pointer)
	if pointer == nil then
		pointer = UserInputService:GetMouseLocation()
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		return nil
	end
	local objects = playerGui:GetGuiObjectsAtPosition(math.floor(pointer.X), math.floor(pointer.Y))
	for _, object in objects do
		local frame = scrollingAncestor(object)
		if frame ~= nil then
			return frame
		end
	end
	return nil
end
-- GetGuiObjectsAtPosition wants coordinates in the same space GetMouseLocation reports, i.e. with
-- the topbar inset already subtracted. Raw InputObject.Position includes that inset, so hit tests
-- fed straight from an input event landed one topbar-height too low and picked the wrong frame
-- (or nothing at all) near the top of the screen.
local function frameUnderInput(position)
	local ok, topLeft = pcall(function()
		return GuiService:GetGuiInset()
	end)
	local inset = if ok and topLeft ~= nil and typeof(topLeft) == "Vector2" then topLeft else Vector2.zero
	return frameUnderPointer(Vector2.new(position.X - inset.X, position.Y - inset.Y))
end
-- Width of the band along each screen edge that the OS reserves for its own back/home gestures.
-- A touch that starts inside it belongs to the system, so the game must not also fling a list —
-- otherwise an edge-swipe-back both leaves the page and scrolls whatever was under the thumb.
local EDGE_GESTURE_BAND = 22
local function inSystemGestureZone(position)
	if not UserInputService.TouchEnabled then
		return false
	end
	local _viewport = Workspace.CurrentCamera
	if _viewport ~= nil then
		_viewport = _viewport.ViewportSize
	end
	local viewport = _viewport
	if viewport == nil then
		return false
	end
	if position.X <= EDGE_GESTURE_BAND or position.X >= viewport.X - EDGE_GESTURE_BAND then
		return true
	end
	-- The bottom band is the home-indicator swipe area, which every gesture-navigation phone
	-- reserves for itself.
	return position.Y >= viewport.Y - EDGE_GESTURE_BAND
end
local function bounds(frame)
	return Vector2.new(math.max(0, frame.AbsoluteCanvasSize.X - frame.AbsoluteWindowSize.X), math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y))
end
local function clampFor(frame, value)
	local maximum = bounds(frame)
	return Vector2.new(math.clamp(value.X, 0, maximum.X), math.clamp(value.Y, 0, maximum.Y))
end
-- Whether `delta` would still move `frame` (measured from where its current fling is heading).
local function canScrollToward(frame, delta)
	local maximum = bounds(frame)
	local motion = motions[frame]
	local from = if motion ~= nil then motion.target else frame.CanvasPosition
	if delta.Y ~= 0 then
		if maximum.Y <= 0.5 then
			return false
		end
		return if delta.Y < 0 then from.Y > 0.5 else from.Y < maximum.Y - 0.5
	end
	if delta.X ~= 0 then
		if maximum.X <= 0.5 then
			return false
		end
		return if delta.X < 0 then from.X > 0.5 else from.X < maximum.X - 0.5
	end
	return false
end
local ensureMotionDriver
local function targetFor(frame)
	local _frame = frame
	local existing = motions[_frame]
	if existing ~= nil then
		return existing
	end
	local created = {
		target = clampFor(frame, frame.CanvasPosition),
		lastTouched = os.clock(),
	}
	local _frame_1 = frame
	motions[_frame_1] = created
	motionCount += 1
	ensureMotionDriver()
	return created
end
local addImpulse
function ensureMotionDriver()
	if not installed then
		return nil
	end
	if motionDriver ~= nil then
		return nil
	end
	local frameSkip = 0
	local signal = if CONSTRAINED_SCROLL then RunService.Heartbeat else RunService.RenderStepped
	motionDriver = signal:Connect(function(deltaTime)
		-- Constrained: advance coast every other heartbeat (~30Hz).
		if CONSTRAINED_SCROLL then
			frameSkip += 1
			if frameSkip % 2 == 1 and gamepadAxis.Magnitude <= 0.16 then
				return nil
			end
		end
		local selectedFrame = scrollingAncestor(GuiService.SelectedObject)
		if selectedFrame ~= nil and gamepadAxis.Magnitude > 0.16 then
			local speed = 260 + scrollPreference * 220
			local _gamepadAxis = gamepadAxis
			local _arg0 = speed * math.min(deltaTime, 0.05)
			local delta = _gamepadAxis * _arg0
			if selectedFrame.ScrollingDirection == Enum.ScrollingDirection.X then
				delta = Vector2.new(delta.X, 0)
			elseif selectedFrame.ScrollingDirection == Enum.ScrollingDirection.Y then
				delta = Vector2.new(0, delta.Y)
			end
			addImpulse(selectedFrame, delta, false)
		end
		local response = 14 - momentumPreference * 5
		local alpha = 1 - math.exp(-response * math.min(deltaTime, 0.05))
		local now = os.clock()
		for frame, motion in motions do
			if frame.Parent == nil or not frame.Visible or not frame.ScrollingEnabled then
				motions[frame] = nil
				motionCount = math.max(0, motionCount - 1)
				continue
			end
			motion.target = clampFor(frame, motion.target)
			local current = frame.CanvasPosition
			local settledPosition = current:Lerp(motion.target, alpha)
			frame.CanvasPosition = settledPosition
			local _target = motion.target
			local _condition = (settledPosition - _target).Magnitude < 0.45
			if _condition then
				_condition = now - motion.lastTouched > 0.08
			end
			if _condition then
				frame.CanvasPosition = motion.target
				motions[frame] = nil
				motionCount = math.max(0, motionCount - 1)
			end
		end
		local _condition = motionCount <= 0
		if _condition then
			_condition = gamepadAxis.Magnitude <= 0.16
		end
		if _condition then
			local _result = motionDriver
			if _result ~= nil then
				_result:Disconnect()
			end
			motionDriver = nil
			motionCount = 0
		end
	end)
end
function addImpulse(frame, delta, audible)
	if audible == nil then
		audible = true
	end
	if not installed then
		return nil
	end
	holdTitleFx()
	local motion = targetFor(frame)
	local _exp = frame
	local _target = motion.target
	local _delta = delta
	motion.target = clampFor(_exp, _target + _delta)
	motion.lastTouched = os.clock()
	if audible and os.clock() - lastScrollSound >= 0.095 then
		lastScrollSound = os.clock()
		Audio:play("scroll", math.clamp(0.92 + delta.Magnitude / 900, 0.92, 1.16))
	end
end
local function revealSelection(selected)
	if not installed then
		return nil
	end
	local frame = scrollingAncestor(selected)
	if frame == nil or selected == nil then
		return nil
	end
	local windowOrigin = frame.AbsolutePosition
	local windowSize = frame.AbsoluteWindowSize
	local itemOrigin = selected.AbsolutePosition
	local itemSize = selected.AbsoluteSize
	local margin = 14
	local deltaX = 0
	local deltaY = 0
	if itemOrigin.X < windowOrigin.X + margin then
		deltaX = itemOrigin.X - (windowOrigin.X + margin)
	elseif itemOrigin.X + itemSize.X > windowOrigin.X + windowSize.X - margin then
		deltaX = itemOrigin.X + itemSize.X - (windowOrigin.X + windowSize.X - margin)
	end
	if itemOrigin.Y < windowOrigin.Y + margin then
		deltaY = itemOrigin.Y - (windowOrigin.Y + margin)
	elseif itemOrigin.Y + itemSize.Y > windowOrigin.Y + windowSize.Y - margin then
		deltaY = itemOrigin.Y + itemSize.Y - (windowOrigin.Y + windowSize.Y - margin)
	end
	if frame.ScrollingDirection == Enum.ScrollingDirection.X then
		deltaY = 0
	end
	if frame.ScrollingDirection == Enum.ScrollingDirection.Y then
		deltaX = 0
	end
	if math.abs(deltaX) > 0.5 or math.abs(deltaY) > 0.5 then
		addImpulse(frame, Vector2.new(deltaX, deltaY), false)
	end
end
local boundScrolls = {}
local function bindLayoutUtil(frame)
	local _frame = frame
	if boundScrolls[_frame] ~= nil then
		return nil
	end
	local _frame_1 = frame
	boundScrolls[_frame_1] = true
	local resizeConnection
	local apply = function()
		if frame.Parent == nil then
			return nil
		end
		local _result = resizeConnection
		if _result ~= nil then
			_result:Disconnect()
		end
		resizeConnection = nil
		local layout = frame:FindFirstChildWhichIsA("UIListLayout") or frame:FindFirstChildWhichIsA("UIGridLayout")
		if layout == nil then
			return nil
		end
		if layout:IsA("UIGridLayout") then
			pcall(function()
				return LayoutUtil.grid(layout, frame.AbsoluteSize)
			end)
		end
		local axis = if frame.ScrollingDirection == Enum.ScrollingDirection.X then Enum.AutomaticSize.X elseif frame.ScrollingDirection == Enum.ScrollingDirection.XY then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y
		local ok, connection = pcall(function()
			return LayoutUtil.resize(frame, layout, axis)
		end)
		if ok and connection ~= nil then
			resizeConnection = connection
		end
	end
	-- Mounting N rows fires ChildAdded N times in one frame; one deferred apply
	-- covers all of them (each apply re-finds the layout and reconnects resize).
	local applyScheduled = false
	local function scheduleApply()
		if applyScheduled then
			return
		end
		applyScheduled = true
		task.defer(function()
			applyScheduled = false
			apply()
		end)
	end
	scheduleApply()
	local added = frame.ChildAdded:Connect(scheduleApply)
	local scrolled = frame:GetPropertyChangedSignal("CanvasPosition"):Connect(holdTitleFx)
	frame.Destroying:Once(function()
		added:Disconnect()
		scrolled:Disconnect()
		local _result = resizeConnection
		if _result ~= nil then
			_result:Disconnect()
		end
		local _frame_2 = frame
		boundScrolls[_frame_2] = nil
	end)
end
local function watchPlayerGui(playerGui)
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("ScrollingFrame") then
			bindLayoutUtil(descendant)
		end
	end
	return playerGui.DescendantAdded:Connect(function(instance)
		if instance:IsA("ScrollingFrame") then
			bindLayoutUtil(instance)
		end
	end)
end
local function installScrollPerformance()
	if installed then
		return disposeScrollPerformance
	end
	installed = true
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui ~= nil then
		local _arg0 = watchPlayerGui(playerGui)
		table.insert(globalConnections, _arg0)
	else
		local _arg0 = Players.LocalPlayer.ChildAdded:Connect(function(child)
			if child:IsA("PlayerGui") then
				local _arg0_1 = watchPlayerGui(child)
				table.insert(globalConnections, _arg0_1)
			end
		end)
		table.insert(globalConnections, _arg0)
	end
	local _arg0 = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return nil
		end
		-- Nothing is coasting, so there is nothing to stop — skip the rest entirely. This is the
		-- common case for every tap on a phone and GetGuiObjectsAtPosition is not cheap.
		if motionCount <= 0 then
			return nil
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		-- A touch that starts on a system gesture edge is the OS's, not ours. Leave every list
		-- exactly as it is so an edge-swipe-back does not also drag the page underneath it.
		if input.UserInputType == Enum.UserInputType.Touch and inSystemGestureZone(position) then
			return nil
		end
		-- Stop the fling the finger actually landed on, not every fling in the game. Clearing the
		-- whole map meant a tap on one panel froze an unrelated list mid-scroll, and two nested
		-- surfaces (a horizontal carousel inside a vertical page) cancelled each other constantly.
		local frame = frameUnderInput(position)
		if frame ~= nil and motions[frame] ~= nil then
			motions[frame] = nil
			motionCount = math.max(0, motionCount - 1)
		end
	end)
	table.insert(globalConnections, _arg0)
	local _arg0_1 = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local direction = input.Position.Z
			if direction == 0 then
				return nil
			end
			task.defer(function()
				if not installed then
					return nil
				end
				local innermost = frameUnderPointer()
				if innermost == nil then
					return nil
				end
				local travel = 78 + scrollPreference * 110
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				-- Nested scrollers: the wheel goes to the innermost frame that can still move that way.
				-- A list that is too short to scroll, or already at its end, hands the wheel to the page
				-- around it instead of swallowing it.
				local frame = innermost
				while frame ~= nil do
					local horizontal = frame.ScrollingDirection == Enum.ScrollingDirection.X or (shift and frame.ScrollingDirection == Enum.ScrollingDirection.XY)
					local delta = if horizontal then Vector2.new(-direction * travel, 0) else Vector2.new(0, -direction * travel)
					if canScrollToward(frame, delta) then
						addImpulse(frame, delta)
						return nil
					end
					frame = scrollingAncestor(frame.Parent)
				end
			end)
			return nil
		end
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadAxis = Vector2.new(input.Position.X, -input.Position.Y)
			if gamepadAxis.Magnitude > 0.16 then
				ensureMotionDriver()
			end
		end
	end)
	table.insert(globalConnections, _arg0_1)
	local _arg0_2 = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			gamepadAxis = Vector2.zero
		end
	end)
	table.insert(globalConnections, _arg0_2)
	local _arg0_3 = GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		task.defer(function()
			if installed then
				revealSelection(GuiService.SelectedObject)
			end
		end)
	end)
	table.insert(globalConnections, _arg0_3)
	return disposeScrollPerformance
end
local function breakpointColumns(width, fallback, breakpoints)
	if breakpoints == nil or #breakpoints == 0 then
		return fallback
	end
	local resolved = 1
	for _, point in breakpoints do
		if width >= point.minWidth then
			resolved = point.columns
		end
	end
	return resolved
end
local function AutoGrid(_param)
	local columns = _param.columns
	local cellHeight = _param.cellHeight
	local gap = _param.gap
	if gap == nil then
		gap = 8
	end
	local rowGap = _param.rowGap
	if rowGap == nil then
		rowGap = gap
	end
	local columnGap = _param.columnGap
	if columnGap == nil then
		columnGap = gap
	end
	local minColumns = _param.minColumns
	if minColumns == nil then
		minColumns = 1
	end
	local minCellWidth = _param.minCellWidth
	local maxCellWidth = _param.maxCellWidth
	local cellAspectRatio = _param.cellAspectRatio
	local breakpoints = _param.breakpoints
	local pack = _param.pack
	if pack == nil then
		pack = false
	end
	local horizontalAlignment = _param.horizontalAlignment
	if horizontalAlignment == nil then
		horizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local verticalAlignment = _param.verticalAlignment
	if verticalAlignment == nil then
		verticalAlignment = Enum.VerticalAlignment.Top
	end
	local startCorner = _param.startCorner
	if startCorner == nil then
		startCorner = Enum.StartCorner.TopLeft
	end
	local fillDirection = _param.fillDirection
	if fillDirection == nil then
		fillDirection = Enum.FillDirection.Horizontal
	end
	local sortOrder = _param.sortOrder
	if sortOrder == nil then
		sortOrder = Enum.SortOrder.LayoutOrder
	end
	local autoCanvas = _param.autoCanvas
	if autoCanvas == nil then
		autoCanvas = false
	end
	local canvasTail = _param.canvasTail
	if canvasTail == nil then
		canvasTail = 0
	end
	local onLayout = _param.onLayout
	local layoutRef = React.useRef()
	local callbackRef = React.useRef(onLayout)
	callbackRef.current = onLayout
	React.useEffect(function()
		local layout = layoutRef.current
		local _parent = layout
		if _parent ~= nil then
			_parent = _parent.Parent
		end
		local parent = _parent
		if layout == nil or parent == nil or not parent:IsA("GuiObject") then
			return nil
		end
		local alive = true
		local scheduled = false
		local previous = ""
		local sync = function()
			scheduled = false
			if not alive or layout.Parent == nil or parent.Parent == nil then
				return nil
			end
			local parentWidth = math.max(1, math.floor(parent.AbsoluteSize.X + 0.5))
			local preferred = breakpointColumns(parentWidth, columns, if pack then PACK_BREAKPOINTS else breakpoints)
			local widthDriven = if minCellWidth ~= nil then math.floor((parentWidth + columnGap) / math.max(1, minCellWidth + columnGap)) else preferred
			local maximumColumns = math.max(1, math.floor(columns))
			local minimumColumns = math.clamp(math.floor(minColumns), 1, maximumColumns)
			local count = math.clamp(math.min(preferred, widthDriven), minimumColumns, maximumColumns)
			local available = math.max(1, parentWidth - columnGap * (count - 1))
			local _condition = maxCellWidth
			if _condition == nil then
				_condition = math.huge
			end
			local resolvedWidth = math.max(1, math.floor(math.min(_condition, available / count)))
			local resolvedHeight = if cellAspectRatio ~= nil and cellAspectRatio > 0 then math.max(1, math.floor(resolvedWidth / cellAspectRatio + 0.5)) else math.max(1, math.floor(cellHeight))
			local signature = `{count}:{resolvedWidth}:{resolvedHeight}:{columnGap}:{rowGap}`
			if signature ~= previous then
				previous = signature
				layout.CellPadding = UDim2.fromOffset(columnGap, rowGap)
				layout.CellSize = UDim2.fromOffset(resolvedWidth, resolvedHeight)
				layout.FillDirectionMaxCells = count
				local _result = callbackRef.current
				if _result ~= nil then
					_result({
						columns = count,
						cellWidth = resolvedWidth,
						cellHeight = resolvedHeight,
						contentWidth = resolvedWidth * count + columnGap * (count - 1),
					})
				end
			end
			if autoCanvas and parent:IsA("ScrollingFrame") then
				local height = math.max(0, math.ceil(layout.AbsoluteContentSize.Y + canvasTail))
				if parent.CanvasSize.Y.Offset ~= height or parent.CanvasSize.Y.Scale ~= 0 then
					parent.CanvasSize = UDim2.new(parent.CanvasSize.X.Scale, parent.CanvasSize.X.Offset, 0, height)
				end
			end
		end
		local schedule = function()
			if scheduled then
				return nil
			end
			scheduled = true
			task.defer(sync)
		end
		sync()
		local sizeConnection = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(schedule)
		local contentConnection = layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(schedule)
		return function()
			alive = false
			sizeConnection:Disconnect()
			contentConnection:Disconnect()
		end
	end, { autoCanvas, breakpoints, canvasTail, cellAspectRatio, cellHeight, columnGap, columns, maxCellWidth, minCellWidth, minColumns, pack, rowGap })
	local count = math.max(1, math.floor(columns))
	return React.createElement("uigridlayout", {
		ref = layoutRef,
		CellSize = UDim2.new(1 / count, -(columnGap * (count - 1)) / count, 0, cellHeight),
		CellPadding = UDim2.fromOffset(columnGap, rowGap),
		FillDirection = fillDirection,
		FillDirectionMaxCells = count,
		HorizontalAlignment = horizontalAlignment,
		VerticalAlignment = verticalAlignment,
		StartCorner = startCorner,
		SortOrder = sortOrder,
	})
end
--[[
	*
	 * Virtualizes a fixed-row-height grid (1..N columns) inside an existing ScrollingFrame:
	 * only mounts item instances whose row overlaps the visible viewport (+ overscanRows of
	 * slack on each side), instead of building every row's full subtree up front. Newly
	 * revealed rows mount one row-batch per heartbeat rather than all at once, so a big scroll
	 * jump (drag-to-bottom, PageDown) doesn't spike a single frame with dozens of instance
	 * creations. Positions itself absolutely (Position prop on the host frame) so it composes
	 * inside a page that lays out sections with a uilistlayout — the host's own Size still
	 * participates in that layout normally.
	 
]]
local function VirtualGrid(_param)
	local scrollRef = _param.scrollRef
	local count = _param.count
	local columns = _param.columns
	local cellHeight = _param.cellHeight
	local gap = _param.gap
	local overscanRows = _param.overscanRows
	if overscanRows == nil or overscanRows < 1 then
		-- One extra row stays mounted so a card that is half on screen is not
		-- unmounted and clipped while the page is still scrolling.
		overscanRows = 1
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local position = _param.position
	local itemKey = _param.itemKey
	local renderItem = _param.renderItem
	local hostRef = React.useRef()
	local rows = math.ceil(count / math.max(1, columns))
	local stride = cellHeight + gap
	local height = math.max(0, rows * cellHeight + math.max(0, rows - 1) * gap)
	local seedLast = if count <= 0 then -1 else math.min(count - 1, math.max(columns * 3, columns) - 1)
	local initial = {
		first = 0,
		last = seedLast,
	}
	local window, setWindow = React.useState(initial)
	local latest = React.useRef(initial)
	React.useEffect(function()
		local host = hostRef.current
		local scroll = scrollRef.current
		if host == nil or scroll == nil or count <= 0 then
			return nil
		end
		local alive = true
		local sync = function()
			if not alive or host.Parent == nil or scroll.Parent == nil then
				return nil
			end
			local viewportTop = scroll.AbsolutePosition.Y
			local viewportBottom = viewportTop + math.max(1, scroll.AbsoluteWindowSize.Y)
			local hostTop = host.AbsolutePosition.Y
			local hostBottom = hostTop + host.AbsoluteSize.Y
			local first = 0
			local last = -1
			if hostBottom >= viewportTop - stride * overscanRows and hostTop <= viewportBottom + stride * overscanRows then
				local firstRow = math.clamp(math.floor((viewportTop - hostTop) / stride) - overscanRows, 0, math.max(0, rows - 1))
				local lastRow = math.clamp(math.floor((viewportBottom - hostTop) / stride) + overscanRows, firstRow, math.max(0, rows - 1))
				first = firstRow * columns
				last = math.min(count - 1, (lastRow + 1) * columns - 1)
			end
			local previous = latest.current
			if previous.first == first and previous.last == last then
				return nil
			end
			local nextWindow = {
				first = first,
				last = last,
			}
			latest.current = nextWindow
			setWindow(nextWindow)
		end
		local connections = { scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(sync), scroll:GetPropertyChangedSignal("AbsolutePosition"):Connect(sync), scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(sync), host:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync) }
		task.defer(sync)
		return function()
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { cellHeight, columns, count, gap, overscanRows, rows, scrollRef, stride })
	local visible = {}
	-- The window state lags the list by a frame: when the list shrinks (a filter
	-- change, an item consumed) it can still point past the new end, and callers'
	-- itemKey/renderItem index into the shrunken list and throw.
	local windowLast = math.min(window.last, count - 1)
	if windowLast >= window.first then
		do
			local index = window.first
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index <= windowLast) then
					break
				end
				local row = math.floor(index / columns)
				local column = index % columns
				visible[itemKey(index)] = React.createElement("frame", {
					Size = UDim2.new(1 / columns, -(gap * (columns - 1)) / columns, 0, cellHeight),
					Position = UDim2.new(column / columns, (column * gap) / columns, 0, row * stride),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Active = false,
				}, renderItem(index))
			end
		end
	end
	return React.createElement("frame", {
		ref = hostRef,
		Size = UDim2.new(1, 0, 0, height),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		Active = false,
		ClipsDescendants = false,
	}, visible)
end
-- The page scroll context: PageScaffold hands it to the element in its fill section so a list
-- there can tell when the page itself has to scroll (its sections don't fit the viewport). In
-- that case the list stops scrolling on its own and lets the page be the only scroller.
local PageScrollContext = React.createContext(nil)
-- `hostRef` (optional): when set, the list does not scroll itself. Its rows are windowed against
-- the host ScrollingFrame instead, by where the list sits inside the host's visible area.
local function useVirtualWindow(count, stride, topOffset, overscan, hostRef)
	if overscan == nil then
		-- Constrained devices mount fewer offscreen rows; one row of slack is enough
		-- and cuts React mounts during fast flings roughly in half vs overscan=2.
		overscan = if CONSTRAINED_SCROLL then 1 else 2
	end
	overscan = math.max(1, overscan)
	local frame = React.useRef()
	local initial = {
		first = 0,
		last = math.min(math.max(0, count - 1), if CONSTRAINED_SCROLL then 6 else 10),
	}
	local window, setWindow = React.useState(initial)
	local latest = React.useRef(initial)
	React.useEffect(function()
		local scrolling = frame.current
		if not scrolling then
			return nil
		end
		local scheduled = false
		local alive = true
		local host = if hostRef ~= nil then hostRef.current else nil
		local sync = function()
			scheduled = false
			if not alive then
				return nil
			end
			if count <= 0 then
				local empty = {
					first = 0,
					last = -1,
				}
				latest.current = empty
				setWindow(empty)
				return nil
			end
			local top, height
			if host ~= nil and host.Parent ~= nil then
				-- How far the list's own top has scrolled above the host's visible top.
				top = host.AbsolutePosition.Y - scrolling.AbsolutePosition.Y
				height = math.max(1, host.AbsoluteWindowSize.Y)
			else
				top = scrolling.CanvasPosition.Y
				height = math.max(1, scrolling.AbsoluteWindowSize.Y)
			end
			local first = math.clamp(math.floor((top - topOffset) / stride) - overscan, 0, count - 1)
			local last = math.clamp(math.ceil((top + height - topOffset) / stride) + overscan, first, count - 1)
			local previous = latest.current
			if previous.first == first and previous.last == last then
				return nil
			end
			local range = {
				first = first,
				last = last,
			}
			latest.current = range
			setWindow(range)
		end
		-- Coalesce CanvasPosition storms from flings into one defer per frame.
		local schedule = function()
			if scheduled then
				return nil
			end
			scheduled = true
			task.defer(sync)
		end
		sync()
		local source = host or scrolling
		local moved = source:GetPropertyChangedSignal("CanvasPosition"):Connect(schedule)
		local resized = source:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(schedule)
		local shifted = if host ~= nil then scrolling:GetPropertyChangedSignal("AbsolutePosition"):Connect(schedule) else nil
		return function()
			alive = false
			moved:Disconnect()
			resized:Disconnect()
			if shifted ~= nil then
				shifted:Disconnect()
			end
		end
	end, { count, overscan, stride, topOffset, hostRef or false })
	return {
		frame = frame,
		first = window.first,
		last = window.last,
	}
end
return {
	disposeScrollPerformance = disposeScrollPerformance,
	setScrollSpeed = setScrollSpeed,
	setScrollMomentum = setScrollMomentum,
	installScrollPerformance = installScrollPerformance,
	AutoGrid = AutoGrid,
	VirtualGrid = VirtualGrid,
	useVirtualWindow = useVirtualWindow,
	PageScrollContext = PageScrollContext,
}
end

-- ======================================================================
-- Module: virtualizedList   (merged from virtualizedList.luau, 198 lines)
-- ======================================================================
__defs["virtualizedList"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useVirtualWindow = __load("scrolling").useVirtualWindow
local PageScrollContext = __load("scrolling").PageScrollContext
local Palette = require(script.Parent.CoreKit)("theme").Palette
local function virtualRange(count, stride, topOffset, scrollY, viewHeight, overscan)
	if overscan == nil then
		overscan = 2
	end
	if count <= 0 or stride <= 0 then
		return {
			first = 0,
			last = -1,
		}
	end
	local height = math.max(1, viewHeight)
	local first = math.clamp(math.floor((scrollY - topOffset) / stride) - overscan, 0, count - 1)
	local last = math.clamp(math.ceil((scrollY + height - topOffset) / stride) + overscan, first, count - 1)
	return {
		first = first,
		last = last,
	}
end
local function useVirtualizedList(count, itemHeight, headerHeight, overscan)
	if headerHeight == nil then
		headerHeight = 0
	end
	-- nil overscan lets useVirtualWindow pick the constrained-aware default.
	return useVirtualWindow(count, itemHeight, headerHeight, overscan)
end
local function resolveKey(item, index, extractor)
	if extractor ~= nil then
		return extractor(item, index)
	end
	local record = item
	local _id = record.Id
	local _condition = type(_id) == "string"
	if _condition then
		_condition = #record.Id > 0
	end
	if _condition then
		return record.Id
	end
	local _id_1 = record.id
	local _condition_1 = type(_id_1) == "string"
	if _condition_1 then
		_condition_1 = #record.id > 0
	end
	if _condition_1 then
		return record.id
	end
	local _uid = record.uid
	local _condition_2 = type(_uid) == "string"
	if _condition_2 then
		_condition_2 = #record.uid > 0
	end
	if _condition_2 then
		return record.uid
	end
	return tostring(index)
end
local VirtualRow
local function VirtualizedList(props)
	local data = props.data
	local itemHeight = math.max(1, props.itemHeight)
	local _condition = props.headerHeight
	if _condition == nil then
		_condition = 0
	end
	local headerHeight = math.max(0, _condition)
	local _condition_1 = props.footerHeight
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local footerHeight = math.max(0, _condition_1)
	-- Pass nil through so scrolling.useVirtualWindow can apply the constrained
	-- overscan=1 default instead of forcing desktop overscan=2 on phones.
	local overscan = props.overscan
	local count = #data
	-- Inside a page that has to scroll, a list in the page's fill section joins the page's scroll
	-- (one scroller) instead of nesting a second one. `embedded = false` opts out.
	local scrollHost = React.useContext(PageScrollContext)
	local autoEmbed = scrollHost ~= nil and scrollHost.overflowing == true and props.embedded ~= false
	local embedded = props.embedded == true or autoEmbed
	local hostRef = if embedded and scrollHost ~= nil then scrollHost.hostRef else nil
	local window = useVirtualWindow(count, itemHeight, headerHeight, overscan, hostRef)
	-- Embedded with a known host: still windowed (against the page's scroll). Embedded without
	-- one (an explicit embedded list outside a fill section): every row is mounted.
	local windowed = not embedded or hostRef ~= nil
	local rangeFirst = if windowed then window.first else 0
	local rangeLast = if windowed then window.last else count - 1
	local ownedRef = React.useRef()
	local bindRef = function(frame)
		ownedRef.current = frame
		window.frame.current = frame
		-- LayoutGuardAllowDisabledScroll is an attribute, not a property. Passing
		-- it in the props table makes the renderer assign a real member and throw
		-- at mount, so it has to be set here. It tells the layout guard that this
		-- frame's ScrollingEnabled = false is deliberate (the page scaffold owns
		-- the scroll) rather than a defect to repair.
		if frame ~= nil then
			frame:SetAttribute("LayoutGuardAllowDisabledScroll", embedded)
		end
		if props.frameRef ~= nil then
			(props.frameRef).current = frame
		end
	end
	local rows = {}
	do
		local index = rangeFirst
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index <= rangeLast) then
				break
			end
			local item = data[index + 1]
			if item == nil then
				continue
			end
			local _arg0 = React.createElement(VirtualRow, {
				key = resolveKey(item, index, props.keyExtractor),
				index = index,
				height = itemHeight,
				top = headerHeight + index * itemHeight,
			}, props.renderItem({
				item = item,
				index = index,
			}))
			table.insert(rows, _arg0)
		end
	end
	local _exp = headerHeight + math.max(count, if count == 0 and props.ListEmptyComponent ~= nil then 1 else 0) * (if count > 0 then itemHeight else 0) + footerHeight
	local _condition_3 = props.canvasTail
	if _condition_3 == nil then
		_condition_3 = 0
	end
	local canvasH = _exp + _condition_3
	local _exp_1 = headerHeight + (if count == 0 and props.ListEmptyComponent ~= nil then 150 else 0) + footerHeight
	local _condition_4 = props.canvasTail
	if _condition_4 == nil then
		_condition_4 = 0
	end
	local emptyCanvas = _exp_1 + _condition_4
	local reportedHeight = if count > 0 then canvasH else emptyCanvas
	-- The section has to hold whatever sits above the list (a card header) and the gap the list
	-- originally left below itself, not just the rows.
	local trailing = 0
	local declaredSize = props.Size
	if typeof(declaredSize) == "UDim2" and declaredSize.Y.Scale >= 0.999 then
		local declaredPosition = props.Position
		local positionOffset = if typeof(declaredPosition) == "UDim2" then declaredPosition.Y.Offset else 0
		trailing = math.max(0, -declaredSize.Y.Offset - positionOffset)
	end
	React.useEffect(function()
		if not autoEmbed or scrollHost == nil or scrollHost.report == nil then
			return nil
		end
		local lastReport = -1
		local push = function()
			local frame = ownedRef.current
			local section = if scrollHost.sectionRef ~= nil then scrollHost.sectionRef.current else nil
			local lead = 0
			if frame ~= nil and section ~= nil then
				lead = math.max(0, frame.AbsolutePosition.Y - section.AbsolutePosition.Y)
			end
			local total = math.ceil(lead + reportedHeight + trailing + 4)
			if total ~= lastReport then
				lastReport = total
				scrollHost.report(total)
			end
		end
		push()
		local frame = ownedRef.current
		local moved = if frame ~= nil then frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(push) else nil
		return function()
			if moved ~= nil then
				moved:Disconnect()
			end
		end
	end, { autoEmbed, reportedHeight, trailing })
	local _attributes = {
		ref = bindRef,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromOffset(0, 0),
		CanvasSize = UDim2.new(0, 0, 0, if count > 0 then canvasH else emptyCanvas),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	local _condition_5 = props.scrollBarThickness
	if _condition_5 == nil then
		_condition_5 = 3
	end
	_attributes.ScrollBarThickness = _condition_5
	_attributes.ScrollBarImageColor3 = props.scrollBarColor or Palette.cyan
	local _condition_6 = props.scrollBarTransparency
	if _condition_6 == nil then
		_condition_6 = 0.28
	end
	_attributes.ScrollBarImageTransparency = _condition_6
	_attributes.ClipsDescendants = true
	_attributes.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	_attributes.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	_attributes.Active = not embedded
	if embedded then
		-- The page scaffold is the only scroller. An inner ScrollingFrame steals
		-- the wheel and fights that parent.
		_attributes.ScrollingEnabled = false
		_attributes.ScrollBarThickness = 0
		_attributes.ClipsDescendants = false
		_attributes.Size = UDim2.new(1, 0, 0, if count > 0 then canvasH else emptyCanvas)
	end
	_attributes.Selectable = false
	_attributes.ZIndex = props.ZIndex
	_attributes.LayoutOrder = props.layoutOrder
	return React.createElement("scrollingframe", _attributes, props.ListHeaderComponent, count == 0 and props.ListEmptyComponent, rows, props.ListFooterComponent)
end
function VirtualRow(_param)
	local height = _param.height
	local top = _param.top
	local children = _param.children
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.fromOffset(0, top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end
local function FlatList(props)
	local _attributes = table.clone(props)
	setmetatable(_attributes, nil)
	return React.createElement(VirtualizedList, _attributes)
end
return {
	virtualRange = virtualRange,
	useVirtualizedList = useVirtualizedList,
	VirtualizedList = VirtualizedList,
	FlatList = FlatList,
}
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		-- The boot loader reads the member list to warm every member up front.
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
