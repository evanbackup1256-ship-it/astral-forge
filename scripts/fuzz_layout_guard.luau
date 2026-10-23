--!nocheck
-- Property-based tests for the LayoutGuard math kernels. Each property is checked against a
-- slow but obviously-correct oracle on seeded random inputs, so a failure is reproducible.
--   rbxtsc && lune run scripts/fuzz_layout_guard.luau [seed] [rounds]
local process = require("@lune/process")
local Loader = require("./lg_loader")
local load, BASE = Loader.load, Loader.BASE

local G = load(BASE .. "/geom")
local C = load(BASE .. "/constraints")
local S = load(BASE .. "/spatial")
local M = load(BASE .. "/metrics")
local L = load(BASE .. "/layoutSim")
local Log = load(BASE .. "/logger")
local Heat = load(BASE .. "/heat")

local SEED = tonumber(process.args[1]) or 20261022
local ROUNDS = tonumber(process.args[2]) or 60
math.randomseed(SEED)

local function int(lo, hi)
	return math.random(lo, hi)
end
local function real(lo, hi)
	return lo + math.random() * (hi - lo)
end

local passed, failed = 0, 0
local failures = {}
local function property(name, fn)
	local okCount = 0
	for round = 1, ROUNDS do
		local ok, err = pcall(fn, round)
		if ok and err ~= false then
			okCount += 1
		else
			failed += 1
			table.insert(failures, string.format("%s (seed %d, round %d): %s", name, SEED, round, tostring(err)))
			break
		end
	end
	if okCount == ROUNDS then
		passed += 1
		print("ok   " .. name)
	else
		print("FAIL " .. name)
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6) * math.max(1, math.abs(a), math.abs(b))
end
local function assertf(cond, fmt, ...)
	if not cond then error(string.format(fmt, ...), 2) end
end

-- random integer rect inside [0, w) x [0, h); `big` mixes in a few large panels
local function randomRect(w, h, maxSide, big)
	local side = (big and math.random() < 0.1) and int(maxSide, maxSide * 6) or int(1, maxSide)
	local sideY = (big and math.random() < 0.1) and int(maxSide, maxSide * 6) or int(1, maxSide)
	local x0 = int(0, w - 1)
	local y0 = int(0, h - 1)
	return G.rect(x0, y0, x0 + side, y0 + sideY)
end
local function randomItems(n, w, h, maxSide, big)
	local items = {}
	for i = 1, n do items[i] = { id = i, rect = randomRect(w, h, maxSide, big) } end
	return items
end
local function pairKey(a, b)
	local x, y = a.id, b.id
	if x > y then x, y = y, x end
	return x .. ":" .. y
end
local function brutePairs(items)
	local set, count = {}, 0
	for i = 1, #items do
		for j = i + 1, #items do
			if G.intersects(items[i].rect, items[j].rect) then
				set[pairKey(items[i], items[j])] = true
				count += 1
			end
		end
	end
	return set, count
end
local function collect(run)
	local set, count, dup = {}, 0, nil
	run(function(a, b)
		local k = pairKey(a, b)
		if set[k] then dup = k end
		set[k] = true
		count += 1
	end)
	return set, count, dup
end
local function sameSet(a, b)
	for k in a do if not b[k] then return false, k end end
	for k in b do if not a[k] then return false, k end end
	return true
end

-- exact area of a union of integer rects by counting unit cells (the oracle for unionArea)
local function rasterUnion(rects, clip)
	local cells = {}
	local count = 0
	for _, r in rects do
		local x0, y0, x1, y1 = r.x0, r.y0, r.x1, r.y1
		if clip then
			x0, y0 = math.max(x0, clip.x0), math.max(y0, clip.y0)
			x1, y1 = math.min(x1, clip.x1), math.min(y1, clip.y1)
		end
		for x = x0, x1 - 1 do
			for y = y0, y1 - 1 do
				local k = x * 100003 + y
				if not cells[k] then
					cells[k] = true
					count += 1
				end
			end
		end
	end
	return count
end

------------------------------------------------------------------------------------------------
-- spatial index: every broad phase must report exactly the brute-force pair set, each pair once

property("sweepPairs == brute force", function()
	local items = randomItems(int(2, 120), 400, 300, 40, true)
	local want, wantCount = brutePairs(items)
	local got, gotCount, dup = collect(function(visit) S.sweepPairs(items, visit) end)
	assertf(dup == nil, "duplicate pair %s", tostring(dup))
	local same, k = sameSet(want, got)
	assertf(same, "pair set differs at %s (%d vs %d)", tostring(k), wantCount, gotCount)
end)

property("UniformGrid.pairs == brute force", function()
	local items = randomItems(int(2, 120), 400, 300, 30, false)
	local want = brutePairs(items)
	local grid = S.UniformGrid.new(int(8, 64))
	for _, item in items do grid:insert(item) end
	local got, _, dup = collect(function(visit) grid:pairs(visit) end)
	assertf(dup == nil, "duplicate pair %s", tostring(dup))
	local same, k = sameSet(want, got)
	assertf(same, "pair set differs at %s", tostring(k))
end)

property("choosePairs == brute force for every strategy", function(round)
	-- alternate sizes so brute (<24), grid (uniform) and sweep (mixed) all get exercised
	local n = (round % 3 == 0) and int(2, 23) or int(24, 160)
	local items = randomItems(n, 600, 400, 30, round % 3 == 2)
	local want = brutePairs(items)
	local got, _, dup = collect(function(visit) S.choosePairs(items, visit) end)
	assertf(dup == nil, "duplicate pair %s", tostring(dup))
	local same, k = sameSet(want, got)
	assertf(same, "pair set differs at %s", tostring(k))
end)

property("UniformGrid.query and RectIndex.query == linear scan", function()
	local items = randomItems(int(1, 100), 500, 500, 60, true)
	local grid = S.UniformGrid.new(32)
	for _, item in items do grid:insert(item) end
	local index = S.RectIndex.new(items)
	for _ = 1, 10 do
		local q = randomRect(500, 500, 120, false)
		local want = {}
		for _, item in items do
			if G.intersects(item.rect, q) then want[item.id] = true end
		end
		for label, hits in { grid = grid:query(q), index = index:query(q) } do
			local got = {}
			for _, h in hits do
				assertf(not got[h.id], "%s returned %d twice", label, h.id)
				got[h.id] = true
			end
			local same, k = sameSet(want, got)
			assertf(same, "%s query differs at id %s", label, tostring(k))
		end
	end
end)

property("IntervalTreap overlapping == naive list under insert/remove", function()
	local t = S.IntervalTreap.new()
	local live = {}
	local nextId = 0
	for _ = 1, 80 do
		if #live > 0 and math.random() < 0.35 then
			local i = int(1, #live)
			local victim = table.remove(live, i)
			assertf(t:remove(victim.lo, victim.id), "remove failed for id %d", victim.id)
		else
			nextId += 1
			local lo = int(0, 200)
			local iv = { lo = lo, hi = lo + int(1, 40), id = nextId }
			t:insert(iv.lo, iv.hi, iv.id)
			table.insert(live, iv)
		end
		assertf(t:size() == #live, "size %d vs %d", t:size(), #live)
		local qlo = int(-10, 220)
		local qhi = qlo + int(0, 30)
		local want = {}
		for _, iv in live do
			if iv.lo < qhi and qlo < iv.hi then want[iv.id] = true end
		end
		local got = {}
		for _, id in t:overlapping(qlo, qhi) do got[id] = true end
		local same, k = sameSet(want, got)
		assertf(same, "query [%d,%d] differs at id %s", qlo, qhi, tostring(k))
	end
	assertf(not t:remove(-999, -1), "removing a missing interval must fail")
end)

------------------------------------------------------------------------------------------------
-- rect algebra

property("intersect / intersectionArea are symmetric and bounded", function()
	local a, b = randomRect(200, 200, 80), randomRect(200, 200, 80)
	local ab, ba = G.intersectionArea(a, b), G.intersectionArea(b, a)
	assertf(ab == ba, "asymmetric %f vs %f", ab, ba)
	assertf(ab <= math.min(G.area(a), G.area(b)), "intersection larger than an operand")
	assertf((ab > 0) == G.intersects(a, b), "intersects disagrees with area %f", ab)
	assertf(G.area(G.intersect(a, b)) == ab, "intersect rect area mismatch")
	local u = G.bounds(a, b)
	assertf(G.contains(u, a) and G.contains(u, b), "bounds does not contain operands")
end)

property("subtract pieces are disjoint and conserve area", function()
	local a, b = randomRect(100, 100, 60), randomRect(100, 100, 60)
	local pieces = G.subtract(a, b)
	local total = 0
	for i, p in pieces do
		total += G.area(p)
		assertf(G.contains(a, p), "piece outside the minuend")
		assertf(G.intersectionArea(p, b) == 0, "piece overlaps the hole")
		for j = i + 1, #pieces do
			assertf(G.intersectionArea(p, pieces[j]) == 0, "pieces %d and %d overlap", i, j)
		end
	end
	local want = G.area(a) - G.intersectionArea(a, b)
	assertf(near(total, want), "area %f vs %f", total, want)
end)

property("subtractAll + unionArea agree with the raster oracle", function()
	local base = G.rect(0, 0, 60, 60)
	local holes = {}
	for i = 1, int(0, 8) do holes[i] = randomRect(70, 70, 30) end
	local free = 0
	for _, p in G.subtractAll(base, holes) do free += G.area(p) end
	local covered = rasterUnion(holes, base)
	assertf(near(free, 3600 - covered), "subtractAll free %f vs %d", free, 3600 - covered)
	assertf(near(G.unionArea(holes, base), covered), "clipped unionArea %f vs %d", G.unionArea(holes, base), covered)
end)

property("unionArea == raster cell count", function()
	local rects = {}
	for i = 1, int(1, 14) do rects[i] = randomRect(80, 80, 35) end
	local want = rasterUnion(rects)
	local got = G.unionArea(rects)
	assertf(near(got, want), "unionArea %f vs %d", got, want)
	local cov = G.coverage(G.rect(0, 0, 80, 80), rects)
	assertf(cov >= 0 and cov <= 1 + 1e-9, "coverage out of range %f", cov)
end)

property("inset/outset round trip and overflow measures", function()
	local r = G.rect(int(0, 50), int(0, 50), int(100, 200), int(100, 200))
	local i = { left = int(0, 20), top = int(0, 20), right = int(0, 20), bottom = int(0, 20) }
	assertf(G.equals(G.outset(G.inset(r, i), i), r, 1e-9), "outset(inset(r)) ~= r")
	local inner = randomRect(300, 300, 120)
	local o = G.overflow(inner, r)
	local amount = G.overflowAmount(inner, r)
	assertf(amount >= 0, "negative overflow")
	assertf((amount == 0) == G.contains(r, inner), "overflowAmount disagrees with contains")
	local share = G.outsideShare(inner, r)
	assertf(share >= -1e-9 and share <= 1 + 1e-9, "outsideShare out of range")
	-- nudging an element that fits makes it fully contained
	if G.width(inner) <= G.width(r) and G.height(inner) <= G.height(r) then
		local d = G.nudgeInto(inner, r)
		assertf(G.contains(r, G.translate(inner, d.x, d.y), 1e-6), "nudgeInto did not fit (%f,%f)", d.x, d.y)
	end
	assertf(o.left >= 0 and o.top >= 0 and o.right >= 0 and o.bottom >= 0, "overflow insets negative")
end)

property("gap is zero iff rects touch or overlap; separation clears the overlap", function()
	local a, b = randomRect(150, 150, 50), randomRect(150, 150, 50)
	local gp = G.gap(a, b)
	assertf(gp >= 0, "negative gap")
	if G.intersects(a, b) then
		assertf(gp == 0, "overlapping rects with gap %f", gp)
		local s = G.separation(a, b)
		-- separation is the minimum translation for `a`
		local moved = G.translate(a, s.x, s.y)
		assertf(G.intersectionArea(moved, b) <= 1e-6, "separation left overlap %f", G.intersectionArea(moved, b))
	end
end)

------------------------------------------------------------------------------------------------
-- oriented boxes

property("OBB at 0 degrees matches the AABB kernels", function()
	local a, b = randomRect(200, 200, 80), randomRect(200, 200, 80)
	local oa, ob = G.obbFromRect(a, 0), G.obbFromRect(b, 0)
	assertf(G.obbIntersects(oa, ob) == G.intersects(a, b), "obbIntersects disagrees")
	assertf(near(G.obbIntersectionArea(oa, ob), G.intersectionArea(a, b), 1e-6), "obb area %f vs %f",
		G.obbIntersectionArea(oa, ob), G.intersectionArea(a, b))
	assertf(G.equals(G.obbBounds(oa), a, 1e-6), "obbBounds at 0 degrees changed the rect")
end)

property("OBB area, corners and bounds are rotation-consistent", function()
	local r = randomRect(200, 200, 80)
	local deg = real(-180, 180)
	local o = G.obbFromRect(r, deg)
	local corners = G.obbCorners(o)
	assertf(#corners == 4, "expected 4 corners")
	assertf(near(G.obbArea(o), G.area(r), 1e-6), "obbArea changed under rotation")
	assertf(near(math.abs(G.polygonArea(corners)), G.area(r), 1e-6), "corner polygon area %f", G.polygonArea(corners))
	local bb = G.obbBounds(o)
	for _, p in corners do
		assertf(G.containsPoint(G.outset(bb, { left = 1e-6, top = 1e-6, right = 1e-6, bottom = 1e-6 }), p.x, p.y), "corner outside bounds")
	end
	-- self-intersection area is the whole box; a far-away box intersects nothing
	assertf(near(G.obbIntersectionArea(o, o), G.area(r), 1e-5), "self overlap %f", G.obbIntersectionArea(o, o))
	local far = G.obbFromRect(G.translate(r, 1000, 1000), deg)
	assertf(not G.obbIntersects(o, far) and G.obbIntersectionArea(o, far) == 0, "far boxes intersect")
end)

property("SAT agrees with clipped polygon area", function()
	local a = G.obbFromRect(randomRect(120, 120, 60), real(0, 90))
	local b = G.obbFromRect(randomRect(120, 120, 60), real(0, 90))
	local area = G.obbIntersectionArea(a, b)
	local sat = G.obbIntersects(a, b)
	-- touching boxes can be SAT-positive with zero area; the reverse must never happen
	assertf(not (area > 1e-6 and not sat), "positive area %f but SAT says separated", area)
	assertf(area <= math.min(G.obbArea(a), G.obbArea(b)) + 1e-6, "overlap larger than a box")
end)

property("rotatePoint preserves distance to the pivot", function()
	local p = { x = real(-100, 100), y = real(-100, 100) }
	local pivot = { x = real(-50, 50), y = real(-50, 50) }
	local q = G.rotatePoint(p, pivot, real(-math.pi, math.pi))
	local d0 = math.sqrt((p.x - pivot.x) ^ 2 + (p.y - pivot.y) ^ 2)
	local d1 = math.sqrt((q.x - pivot.x) ^ 2 + (q.y - pivot.y) ^ 2)
	assertf(near(d0, d1, 1e-9), "distance %f -> %f", d0, d1)
end)

------------------------------------------------------------------------------------------------
-- statistics and ordering

local function bruteInversions(order)
	local n = 0
	for i = 1, #order do
		for j = i + 1, #order do
			if order[i] > order[j] then n += 1 end
		end
	end
	return n
end
local function bruteLis(values)
	local best, dp = 0, {}
	for i = 1, #values do
		dp[i] = 1
		for j = 1, i - 1 do
			if values[j] < values[i] then dp[i] = math.max(dp[i], dp[j] + 1) end
		end
		best = math.max(best, dp[i])
	end
	return best
end
local function shuffled(n)
	local t = {}
	for i = 1, n do t[i] = i end
	for i = n, 2, -1 do
		local j = int(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

property("inversions (merge count) == O(n^2) count", function()
	local order = shuffled(int(1, 60))
	assertf(M.inversions(order) == bruteInversions(order), "inversions mismatch")
	local k = M.kendallDistance(order)
	assertf(k >= 0 and k <= 1, "kendall out of range %f", k)
end)

property("kendallDistance is 0 for sorted and 1 for reversed", function()
	local n = int(2, 40)
	local up, down = {}, {}
	for i = 1, n do up[i] = i; down[i] = n - i + 1 end
	assertf(M.kendallDistance(up) == 0, "sorted not 0")
	assertf(near(M.kendallDistance(down), 1), "reversed not 1")
end)

property("lisLength == O(n^2) DP", function()
	local values = {}
	for i = 1, int(0, 50) do values[i] = int(1, 30) end
	assertf(M.lisLength(values) == bruteLis(values), "lis %d vs %d", M.lisLength(values), bruteLis(values))
end)

property("quantile is monotone and bracketed; mean/variance identities", function()
	local values = {}
	for i = 1, int(1, 50) do values[i] = real(-100, 100) end
	local lo, hi = math.huge, -math.huge
	for _, v in values do lo = math.min(lo, v); hi = math.max(hi, v) end
	local prev = -math.huge
	for q = 0, 1, 0.125 do
		local x = M.quantile(values, q)
		assertf(x >= prev - 1e-9 and x >= lo - 1e-9 and x <= hi + 1e-9, "quantile not monotone at %f", q)
		prev = x
	end
	local m = M.mean(values)
	local sq = 0
	for _, v in values do sq += (v - m) ^ 2 end
	assertf(near(M.variance(values), sq / #values, 1e-6) or near(M.variance(values), sq / math.max(1, #values - 1), 1e-6),
		"variance is neither population nor sample variance")
	assertf(near(M.stddev(values) ^ 2, M.variance(values), 1e-6), "stddev^2 ~= variance")
	assertf(M.mad(values) >= 0, "negative MAD")
	local positives = {}
	for i, v in values do positives[i] = math.abs(v) + 1 end
	local g = M.gini(positives)
	assertf(g >= -1e-9 and g < 1, "gini out of range %f", g)
end)

property("clusterByGap partitions sorted values with gaps above tolerance", function()
	local values = {}
	for i = 1, int(1, 40) do values[i] = int(0, 300) end
	local tol = int(1, 12)
	local clusters = M.clusterByGap(values, tol)
	local total = 0
	for _, c in clusters do total += #c.members end
	assertf(total == #values, "clusters hold %d of %d values", total, #values)
	-- adjacent clusters are separated by more than the tolerance
	local sorted = M.sortedCopy(values)
	local breaks = 0
	for i = 2, #sorted do
		if sorted[i] - sorted[i - 1] > tol then breaks += 1 end
	end
	assertf(#clusters == breaks + 1, "%d clusters but %d breaks", #clusters, breaks)
end)

property("kmeans1d is optimal: withinSS never increases with k and beats random splits", function()
	local values = {}
	for i = 1, int(3, 30) do values[i] = real(0, 100) end
	local prev = math.huge
	for k = 1, math.min(5, #values) do
		local groups = M.kmeans1d(values, k)
		local n = 0
		for _, g in groups do n += #g end
		assertf(n == #values, "k=%d lost values", k)
		local w = M.withinSS(groups)
		assertf(w <= prev + 1e-6, "withinSS rose at k=%d (%f > %f)", k, w, prev)
		prev = w
		-- any contiguous split of the sorted values into k parts is no better than the DP optimum
		local sorted = M.sortedCopy(values)
		local cuts = {}
		for c = 1, k - 1 do cuts[c] = int(1, #sorted - 1) end
		table.sort(cuts)
		local parts, start = {}, 1
		for _, c in cuts do
			if c >= start then
				table.insert(parts, table.move(sorted, start, c, 1, {}))
				start = c + 1
			end
		end
		table.insert(parts, table.move(sorted, start, #sorted, 1, {}))
		assertf(w <= M.withinSS(parts) + 1e-6, "DP %f worse than a random split %f", w, M.withinSS(parts))
	end
end)

property("mergeSpans / coveredLength / freeBands partition the axis", function()
	local spans = {}
	for i = 1, int(0, 12) do
		local lo = int(0, 180)
		spans[i] = { lo = lo, hi = lo + int(1, 30) }
	end
	local merged = M.mergeSpans(spans)
	for i = 2, #merged do
		assertf(merged[i].lo > merged[i - 1].hi, "merged spans overlap or touch")
	end
	local covered = M.coveredLength(spans, 0, 200)
	local cells = 0
	for x = 0, 199 do
		for _, s in spans do
			if s.lo <= x and x + 1 <= s.hi then cells += 1; break end
		end
	end
	assertf(near(covered, cells), "covered %f vs %d", covered, cells)
	local free = 0
	for _, b in M.freeBands(spans, 0, 200, 0) do free += b.hi - b.lo end
	assertf(near(free + covered, 200), "free %f + covered %f ~= 200", free, covered)
end)

property("largestEmptyRect stays inside the container and clear of content", function()
	local container = G.rect(0, 0, 240, 160)
	local rects = {}
	for i = 1, int(0, 10) do rects[i] = randomRect(240, 160, 60) end
	local raster = M.rasterize(container, rects, 4096)
	local fill = M.rasterFill(raster)
	assertf(fill >= 0 and fill <= 1, "fill out of range %f", fill)
	local e = M.largestEmptyRect(raster)
	if G.area(e) > 0 then
		assertf(G.contains(container, e, 1e-6), "empty rect leaves the container")
		-- raster cells are coarse: allow one cell of bleed around content
		local cw = 240 / raster.cols
		local ch = 160 / raster.rows
		for _, r in rects do
			local shrunk = G.inset(r, { left = cw, top = ch, right = cw, bottom = ch })
			assertf(G.width(shrunk) <= 0 or G.height(shrunk) <= 0 or G.intersectionArea(e, shrunk) == 0,
				"empty rect overlaps content")
		end
	end
end)

------------------------------------------------------------------------------------------------
-- constraints and layout emulation

property("anchor helpers are inverses and placeElement honours Scale+Offset", function()
	local content = G.rect(int(0, 100), int(0, 100), int(300, 900), int(300, 700))
	local spec = {
		position = C.udim2(real(0, 1), int(-50, 50), real(0, 1), int(-50, 50)),
		size = C.udim2(real(0, 0.5), int(0, 80), real(0, 0.5), int(0, 80)),
		anchor = { x = real(0, 1), y = real(0, 1) },
	}
	local r = C.placeElement(spec, content)
	local pw, ph = G.width(content), G.height(content)
	assertf(near(G.width(r), spec.size.xs * pw + spec.size.xo, 1e-9), "width ignores Scale+Offset")
	local ax = content.x0 + spec.position.xs * pw + spec.position.xo
	assertf(near(r.x0 + spec.anchor.x * G.width(r), ax, 1e-9), "anchor point not at Position")
	local back = C.offsetForTopLeft(spec, content, { x = r.x0, y = r.y0 }, { x = G.width(r), y = G.height(r) })
	assertf(math.abs(back.xo - spec.position.xo) <= 0.5 and math.abs(back.yo - spec.position.yo) <= 0.5,
		"offsetForTopLeft did not recover the offset")
	local tl = { x = real(0, 100), y = real(0, 100) }
	local size = { x = real(1, 100), y = real(1, 100) }
	local a = C.anchorWorld(tl, spec.anchor, size)
	local tl2 = C.topLeftFromAnchor(a, spec.anchor, size)
	assertf(near(tl.x, tl2.x, 1e-9) and near(tl.y, tl2.y, 1e-9), "anchor round trip failed")
end)

property("clampSize respects limits and MinSize wins over MaxSize", function()
	local limits = { minX = int(0, 100), minY = int(0, 100), maxX = int(0, 200), maxY = int(0, 200) }
	local s = C.clampSize({ x = real(0, 300), y = real(0, 300) }, limits)
	assertf(s.x >= limits.minX - 1e-9 and s.y >= limits.minY - 1e-9, "below MinSize")
	if limits.maxX >= limits.minX then assertf(s.x <= limits.maxX + 1e-9, "above MaxSize.X") end
	if limits.maxY >= limits.minY then assertf(s.y <= limits.maxY + 1e-9, "above MaxSize.Y") end
end)

property("applyAspect yields the requested ratio and FitWithinMaxSize never grows", function()
	local ratio = real(0.25, 4)
	local size = { x = real(10, 400), y = real(10, 400) }
	for _, kind in { "FitWithinMaxSize", "ScaleWithParentSize" } do
		for _, dominant in { "Width", "Height" } do
			local out = C.applyAspect(size, { ratio = ratio, aspectType = kind, dominant = dominant }, 800, 600)
			assertf(near(out.x / out.y, ratio, 1e-6), "%s/%s ratio %f vs %f", kind, dominant, out.x / out.y, ratio)
			if kind == "FitWithinMaxSize" then
				assertf(out.x <= size.x + 1e-6 and out.y <= size.y + 1e-6, "FitWithinMaxSize grew the box")
			end
		end
	end
end)

property("resolveSize with RelativeXX/YY uses one parent axis", function()
	local size = C.udim2(real(0, 1), int(0, 50), real(0, 1), int(0, 50))
	local pw, ph = int(100, 900), int(100, 900)
	local xx = C.resolveSize(size, pw, ph, "XX")
	local yy = C.resolveSize(size, pw, ph, "YY")
	assertf(near(xx.y, size.ys * pw + size.yo, 1e-9), "XX must scale Y by parent width")
	assertf(near(yy.x, size.xs * ph + size.xo, 1e-9), "YY must scale X by parent height")
end)

property("vertical list children are stacked in order with the padding gap", function()
	local kids = {}
	local count = int(1, 8)
	local gap = int(0, 12)
	for i = 1, count do
		kids[i] = L.vnode(i, string.format("Item%02d", i), { size = C.udim2(0, int(20, 120), 0, int(10, 60)) }, {})
		kids[i].layoutOrder = i
	end
	local list = L.vnode(0, "List", { size = C.fromOffset(300, 2000) }, kids)
	list.layout = { kind = "list", fill = "Vertical", padding = C.udim(0, gap), sortByName = false }
	local res = L.resolve(L.vnode(-1, "Layer", { size = C.fromScale(1, 1) }, { list }), G.rect(0, 0, 800, 2400))
	local prev = nil
	for i = 1, count do
		local r = res.rects[i]
		assertf(r ~= nil, "child %d not placed", i)
		if prev then
			assertf(near(r.y0 - prev.y1, gap, 1e-6), "gap %f vs %d at child %d", r.y0 - prev.y1, gap, i)
		end
		prev = r
	end
end)

------------------------------------------------------------------------------------------------
-- logger budget and heatmap

property("TokenBucket never admits more than capacity + rate * elapsed", function()
	local capacity, rate = int(1, 8), real(0.05, 2)
	local bucket = Log.TokenBucket.new(capacity, rate, 0)
	local now, admitted = 0, 0
	for _ = 1, 200 do
		now += real(0, 0.5)
		if bucket:take(now, 1) then admitted += 1 end
		assertf(bucket:available(now) <= capacity + 1e-9, "bucket overfilled")
	end
	assertf(admitted <= capacity + rate * now + 1e-6, "admitted %d > %f", admitted, capacity + rate * now)
end)

property("heatmap intensities stay in [0,1] and boxBlur conserves mass away from edges", function()
	local spots = {}
	for i = 1, int(1, 10) do spots[i] = { rect = randomRect(480, 320, 100), weight = real(0.1, 1) } end
	local h = Heat.heatmap(480, 320, spots, 48, 1)
	for i = 0, h.cols * h.rows - 1 do -- intensity takes the 0-based cell index of the TS source
		local v = Heat.intensity(h, i)
		assertf(v >= 0 and v <= 1 + 1e-9, "intensity %f out of range", v)
	end
	local cols, rows = 9, 9
	local values = table.create(cols * rows, 0)
	values[5 * cols - 4] = 9 -- centre cell (row 5, col 5)
	local blurred = Heat.boxBlur(values, cols, rows)
	local mass = 0
	for _, v in blurred do mass += v end
	assertf(near(mass, 9, 1e-6), "blur changed interior mass to %f", mass)
	local c = Heat.ramp(real(0, 1))
	for _, ch in c do assertf(ch >= 0 and ch <= 1, "ramp channel out of range") end
end)

print(string.format("fuzz_layout_guard: %d properties passed, %d failed (seed %d, %d rounds)", passed, failed, SEED, ROUNDS))
for _, f in failures do print("  " .. f) end
if failed > 0 then error("layout guard properties failed") end
