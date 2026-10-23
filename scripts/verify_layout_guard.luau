--!nocheck
-- Pure-function tests for LayoutGuard (src/Client/AstralForge/LayoutGuard), run under Lune
-- against the compiled output:  rbxtsc && lune run scripts/verify_layout_guard.luau
-- The stock _out_loader only maps out/Shared and out/Server, so this file carries a small loader
-- whose `script` objects are path proxies (script.Parent, WaitForChild) over out/Client.
local Loader = require("./lg_loader")
local load, BASE = Loader.load, Loader.BASE

local G = load(BASE .. "/geom")
local C = load(BASE .. "/constraints")
local L = load(BASE .. "/layoutSim")
local S = load(BASE .. "/spatial")
local M = load(BASE .. "/metrics")
local F = load(BASE .. "/fixtures")
local E = load(BASE .. "/engine")
local Log = load(BASE .. "/logger")
local Mx = load(BASE .. "/matrix")
local Rep = load(BASE .. "/report")
local Heat = load(BASE .. "/heat")
local R = load(BASE .. "/rules")
local Overlap = load(BASE .. "/rules/overlap")
local Clip = load(BASE .. "/rules/clipping")
local Text = load(BASE .. "/rules/text")
local Touch = load(BASE .. "/rules/touch")
local WS = load(BASE .. "/rules/whitespace")
local Align = load(BASE .. "/rules/alignment")
local Focus = load(BASE .. "/rules/focus")
local Scroll = load(BASE .. "/rules/scroll")

local passed, failed = 0, 0
local current = ""
local function check(cond, label)
	if cond then
		passed += 1
	else
		failed += 1
		print(("FAIL [%s] %s"):format(current, label))
	end
end
local function near(a, b, eps, label)
	check(math.abs(a - b) <= (eps or 1e-6), ("%s: %s vs %s"):format(label, tostring(a), tostring(b)))
end
local function section(name, fn)
	current = name
	local ok, err = pcall(fn)
	if not ok then
		failed += 1
		print(("ERROR [%s] %s"):format(name, tostring(err)))
	end
end

local function rect(x, y, w, h) return G.fromPosSize(x, y, w, h) end
local function approxMeasure(text, size, font, maxWidth) return L.approxMeasure(text, size, font, maxWidth) end
local function ctxFor(snap, rule, params)
	local config = E.defaultConfig(rule)
	for k, v in params or {} do config.params[k] = v end
	return {
		snap = snap,
		config = config,
		measure = approxMeasure,
		step = function() end,
		param = function(key, fallback) local v = config.params[key]; if v == nil then return fallback end return v end,
	}
end
local function runRule(rule, snap, params) return rule:run(ctxFor(snap, rule, params)) end

-- deterministic LCG for randomised cross-checks
local seed = 12345
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

---------------------------------------------------------------------------------------------
section("geom basics", function()
	local a, b = rect(0, 0, 10, 10), rect(5, 5, 10, 10)
	near(G.intersectionArea(a, b), 25, 0, "overlap area")
	check(G.intersects(a, b), "intersects")
	check(not G.intersects(a, rect(10, 0, 5, 5)), "touching edges do not intersect")
	near(G.overflowAmount(rect(-3, 0, 10, 10), a), 3, 0, "overflow amount")
	near(G.outsideShare(rect(5, 0, 10, 10), a), 0.5, 1e-9, "outside share")
	local v = G.nudgeInto(rect(-4, 12, 5, 5), rect(0, 0, 20, 15))
	near(v.x, 4, 0, "nudge x"); near(v.y, -2, 0, "nudge y")
	near(G.gap(rect(0, 0, 10, 10), rect(13, 14, 2, 2)), 5, 1e-9, "euclidean gap")
	local sep = G.separation(a, b)
	check(sep.x ~= 0 or sep.y ~= 0, "separation vector nonzero")
end)

section("geom union / subtract", function()
	near(G.unionArea({ rect(0, 0, 10, 10), rect(5, 5, 10, 10) }), 175, 1e-9, "union of two")
	near(G.unionArea({ rect(0, 0, 10, 10), rect(0, 0, 10, 10), rect(2, 2, 2, 2) }), 100, 1e-9, "duplicates and nested")
	near(G.unionArea({ rect(0, 0, 10, 10), rect(20, 0, 10, 10) }, rect(5, 0, 20, 10)), 100, 1e-9, "clipped union")
	local pieces = G.subtractAll(rect(0, 0, 10, 10), { rect(2, 2, 3, 3), rect(4, 4, 3, 3) })
	local total = 0
	for _, p in pieces do total += G.area(p) end
	near(total, 100 - G.unionArea({ rect(2, 2, 3, 3), rect(4, 4, 3, 3) }), 1e-9, "subtractAll = area - union")
	-- randomised: union by sweep equals area minus subtractAll remainder
	for _ = 1, 40 do
		local holes = {}
		for _ = 1, 6 do table.insert(holes, rect(rand() * 80, rand() * 80, 5 + rand() * 30, 5 + rand() * 30)) end
		local base = rect(0, 0, 100, 100)
		local rest = 0
		for _, p in G.subtractAll(base, holes) do rest += G.area(p) end
		near(G.unionArea(holes, base), 10000 - rest, 1e-6, "union vs subtract (random)")
	end
	near(G.coverage(rect(0, 0, 10, 10), { rect(0, 0, 5, 10) }), 0.5, 1e-9, "coverage")
end)

section("geom rotated boxes", function()
	local sq = rect(0, 0, 10, 10)
	local o0 = G.obbFromRect(sq, 0)
	local o45 = G.obbFromRect(sq, 45)
	near(G.obbArea(o45), 100, 1e-6, "rotation keeps area")
	near(G.obbIntersectionArea(o0, o0), 100, 1e-6, "self intersection")
	near(G.obbIntersectionArea(o0, o45), 2 * (math.sqrt(2) - 1) * 100, 1e-6, "square vs 45deg octagon")
	check(not G.obbIntersects(o0, G.obbFromRect(rect(15, 0, 10, 10), 45)), "SAT separates")
	check(G.obbIntersects(o0, G.obbFromRect(rect(9, 0, 10, 10), 45)), "SAT overlap")
	local b = G.obbBounds(o45)
	near(G.width(b), 10 * math.sqrt(2), 1e-6, "rotated bounds")
end)

section("constraints", function()
	local s = C.resolveSize(C.udim2(0.5, 10, 0, 40), 200, 100)
	near(s.x, 110, 0, "scale+offset x"); near(s.y, 40, 0, "offset y")
	local xx = C.resolveSize(C.udim2(0.5, 0, 0.5, 0), 200, 100, "XX")
	near(xx.y, 100, 0, "SizeConstraint XX uses width for Y")
	local tl = C.topLeftFromAnchor({ x = 100, y = 50 }, { x = 0.5, y = 1 }, { x = 40, y = 20 })
	near(tl.x, 80, 0, "anchor x"); near(tl.y, 30, 0, "anchor y")
	local fit = C.applyAspect({ x = 200, y = 50 }, { ratio = 2, aspectType = "FitWithinMaxSize", dominant = "Width" }, 400, 400)
	near(fit.x, 100, 1e-9, "aspect fit shrinks width"); near(fit.y, 50, 1e-9, "aspect fit keeps height")
	local cl = C.clampSize({ x = 10, y = 500 }, { minX = 20, minY = 0, maxX = math.huge, maxY = 300 })
	near(cl.x, 20, 0, "min clamp"); near(cl.y, 300, 0, "max clamp")
	local pad = C.resolvePadding({ left = C.udim(0.1, 0), top = C.udim(0, 4), right = C.udim(0, 0), bottom = C.udim(0, 0) }, 200, 100)
	near(pad.left, 20, 1e-9, "padding scale"); near(pad.top, 4, 0, "padding offset")
	local placed = C.placeElement({ position = C.udim2(0.5, 0, 0.5, 0), size = C.udim2(0, 20, 0, 10), anchor = { x = 0.5, y = 0.5 } }, rect(0, 0, 100, 100))
	near(placed.x0, 40, 0, "placeElement centred x"); near(placed.y0, 45, 0, "placeElement centred y")
	near(C.clampTextSize(30, 8, 24), 24, 0, "UITextSizeConstraint")
end)

section("layoutSim list / grid / flex", function()
	local kids = {}
	for i = 1, 3 do table.insert(kids, L.vnode(i, "Row" .. i, { size = C.udim2(1, 0, 0, 30) }, {}, { layoutOrder = i })) end
	local root = L.vnode(0, "List", { size = C.udim2(0, 200, 0, 200) }, kids, { layout = L.defaultList({ padding = C.udim(0, 5) }), padding = { left = C.udim(0, 10), top = C.udim(0, 10), right = C.udim(0, 10), bottom = C.udim(0, 0) } })
	-- the resolve root stands for the ScreenGui and fills the viewport
	local res = L.resolve(L.vnode(-1, "Layer", { size = C.fromScale(1, 1) }, { root }), rect(0, 0, 800, 600))
	local r3 = res.rects[3]
	near(r3.y0, 10 + 2 * 35, 1e-9, "third row y"); near(r3.x0, 10, 1e-9, "padding left"); near(G.width(r3), 180, 1e-9, "scale width inside padding")
	near(res.contentSize[0].y, 100, 1e-9, "AbsoluteContentSize")

	local cells = {}
	for i = 1, 5 do table.insert(cells, L.vnode(10 + i, "Cell" .. i, {}, {}, { layoutOrder = i })) end
	local grid = L.vnode(10, "Grid", { size = C.udim2(0, 230, 0, 300) }, cells, { layout = L.defaultGrid({ cellSize = C.udim2(0, 100, 0, 50), cellPadding = C.udim2(0, 10, 0, 10) }) })
	local g = L.resolve(L.vnode(-1, "Layer", { size = C.fromScale(1, 1) }, { grid }), rect(0, 0, 800, 600))
	near(g.rects[13].x0, 0, 1e-9, "grid wraps third cell to col 0"); near(g.rects[13].y0, 60, 1e-9, "third cell row 1")
	near(g.rects[12].x0, 110, 1e-9, "second cell col 1")

	local d = L.distributeFlex({ 50, 50 }, { 1, 3 }, { 1, 1 }, 40)
	near(d[1], 60, 1e-9, "flex grow 1:3 (a)"); near(d[2], 80, 1e-9, "flex grow 1:3 (b)")
	local sh = L.distributeFlex({ 100, 20 }, { 0, 0 }, { 1, 1 }, -60)
	near(sh[1] + sh[2], 60, 1e-6, "shrink conserves total"); check(sh[2] >= 0, "shrink never negative")
	local sd = L.spaceDistribution("SpaceBetween", 30, 4)
	local lead, gap = sd[1], sd[2]
	near(lead, 0, 0, "space-between lead"); near(gap, 10, 1e-9, "space-between gap")
end)

section("spatial index", function()
	for trial = 1, 6 do
		local items = {}
		local n = trial * 20
		for i = 1, n do
			table.insert(items, { id = i, rect = rect(rand() * 1000, rand() * 600, 10 + rand() * 120, 10 + rand() * 80) })
		end
		local brute = 0
		for i = 1, n do for j = i + 1, n do if G.intersects(items[i].rect, items[j].rect) then brute += 1 end end end
		local seen = {}
		local count = 0
		S.choosePairs(items, function(a, b)
			local key = math.min(a.id, b.id) .. ":" .. math.max(a.id, b.id)
			check(seen[key] == nil, "pair reported once")
			seen[key] = true
			if G.intersects(a.rect, b.rect) then count += 1 end
		end)
		check(count == brute, ("choosePairs finds all %d overlaps (got %d, n=%d)"):format(brute, count, n))
		local sweep = 0
		S.sweepPairs(items, function(a, b) if G.intersects(a.rect, b.rect) then sweep += 1 end end)
		check(sweep == brute, "sweep-and-prune agrees")
		local grid = S.UniformGrid.new(96)
		for _, it in items do grid:insert(it) end
		local gc = 0
		grid:pairs(function(a, b) if G.intersects(a.rect, b.rect) then gc += 1 end end)
		check(gc == brute, "uniform grid agrees")
	end
	local t = S.IntervalTreap.new()
	for i = 1, 200 do t:insert(i, i + 5, i) end
	local hits = t:overlapping(50, 52)
	-- open intervals: [i, i+5] meets [50, 52] for i = 46..51
	check(#hits == 6, "treap stabbing query (" .. #hits .. ")")
	check(t:height() < 40, "treap stays shallow")
	t:remove(50, 50)
	check(#t:overlapping(50, 52) == 5, "treap remove")
	local idx = S.RectIndex.new({ { id = 1, rect = rect(0, 0, 10, 10) }, { id = 2, rect = rect(20, 20, 10, 10) } })
	check(#idx:at(5, 5) == 1 and #idx:at(15, 15) == 0, "RectIndex point query")
end)

section("metrics", function()
	near(M.median({ 5, 1, 3 }), 3, 0, "median")
	near(M.quantile({ 1, 2, 3, 4 }, 0.5), 2.5, 1e-9, "quantile interpolates")
	near(M.gini({ 1, 1, 1, 1 }), 0, 1e-9, "gini equal")
	check(M.gini({ 0, 0, 0, 10 }) > 0.7, "gini concentrated")
	near(M.kendallDistance({ 0, 1, 2, 3 }), 0, 0, "kendall sorted")
	near(M.kendallDistance({ 3, 2, 1, 0 }), 1, 1e-9, "kendall reversed")
	near(M.inversions({ 2, 0, 1 }), 2, 0, "inversions")
	near(M.lisLength({ 3, 1, 2, 5, 4 }), 3, 0, "LIS")
	local clusters = M.clusterByGap({ 10, 11, 12, 50, 51, 100 }, 2)
	check(#clusters == 3, "cluster by gap count")
	local groups = M.kmeans1d({ 1, 2, 3, 20, 21, 22, 50 }, 3)
	check(#groups == 3 and #groups[1] == 3 and #groups[3] == 1, "optimal 1-D k-means")
	check(M.bestK({ 1, 2, 3, 20, 21, 22, 50, 51 }, 5) == 3, "bestK elbow")
	local merged = M.mergeSpans({ { lo = 0, hi = 10 }, { lo = 5, hi = 15 }, { lo = 30, hi = 40 } })
	check(#merged == 2 and merged[1].hi == 15, "merge spans")
	local bands = M.freeBands(merged, 0, 40, 10)
	check(#bands == 1 and bands[1].lo == 15 and bands[1].hi == 30, "free bands")
	local raster = M.rasterize(rect(0, 0, 100, 100), { rect(0, 0, 100, 40) }, 400)
	near(M.rasterFill(raster), 0.4, 0.03, "raster fill")
	local empty = M.largestEmptyRect(raster)
	near(G.area(empty), 6000, 400, "largest empty rect")
	local bal = M.columnBalance({ 600, 200 })
	near(bal.ratio, 3, 1e-9, "column ratio"); near(bal.deadSpace, 400, 1e-9, "dead space")
end)

---------------------------------------------------------------------------------------------
-- Spam regressions from the live log

local VP = F.viewport(1280, 720)

section("BuffIsland 12px outside parent (floating ancestor)", function()
	local function specs(floating)
		return {
			{ name = "TopBar", rect = rect(0, 0, 1280, 60), drawn = true },
			{ name = "BuffIsland", parent = "TopBar", rect = rect(500, 0, 280, 72), floating = floating, drawn = true },
			{ name = "BuffChip", parent = "BuffIsland", rect = rect(510, 30, 60, 54), interactive = true },
		}
	end
	local exempt = runRule(Clip.OutOfParent, F.build(specs(true), VP))
	check(#exempt == 0, "floating island content is exempt (got " .. #exempt .. ")")
	local flagged = runRule(Clip.OutOfParent, F.build(specs(false), VP))
	check(#flagged == 1, "same geometry without LayoutFloating is reported")
end)

section("Inventory inspect overlay is not a collision", function()
	local specs = {
		{ name = "Inventory", rect = rect(100, 100, 600, 500), drawn = true },
		{ name = "Grid", parent = "Inventory", rect = rect(110, 110, 580, 480) },
		{ name = "Slot1", parent = "Grid", rect = rect(120, 120, 80, 80), interactive = true },
		{ name = "Slot2", parent = "Grid", rect = rect(210, 120, 80, 80), interactive = true },
		{ name = "Inspect", parent = "Inventory", rect = rect(110, 110, 300, 300), drawn = true, zIndex = 5 },
		{ name = "Equip", parent = "Inspect", rect = rect(130, 130, 120, 50), interactive = true, zIndex = 5 },
	}
	local found = runRule(Overlap.ActionCollision, F.build(specs, VP))
	check(#found == 0, "slots hidden under the inspect panel are not collisions (got " .. #found .. ")")
	local bare = {
		{ name = "Panel", rect = rect(0, 0, 600, 400), drawn = true },
		{ name = "A", parent = "Panel", rect = rect(10, 10, 100, 40), interactive = true },
		{ name = "B", parent = "Panel", rect = rect(60, 10, 100, 40), interactive = true },
	}
	local hit = runRule(Overlap.ActionCollision, F.build(bare, VP))
	check(#hit == 1 and hit[1].metrics.ratio > 0.4, "real sibling overlap is reported")
	check(hit[1].hint ~= nil, "collision carries a fix hint")
end)

section("ActionCollision exemptions (motion, floating, ancestry, rotation)", function()
	local moving = {
		{ name = "Overview", rect = rect(0, 0, 600, 400), drawn = true, inMotion = true },
		{ name = "A", parent = "Overview", rect = rect(10, 10, 100, 40), interactive = true },
		{ name = "B", parent = "Overview", rect = rect(60, 10, 100, 40), interactive = true },
	}
	check(#runRule(Overlap.ActionCollision, F.build(moving, VP)) == 0, "LayoutInMotion subtree skipped")
	local floatPair = {
		{ name = "Page", rect = rect(0, 0, 600, 400), drawn = true },
		{ name = "A", parent = "Page", rect = rect(10, 10, 100, 40), interactive = true },
		{ name = "Island", parent = "Page", rect = rect(0, 0, 300, 60), floating = true },
		{ name = "B", parent = "Island", rect = rect(60, 10, 100, 40), interactive = true },
	}
	check(#runRule(Overlap.ActionCollision, F.build(floatPair, VP)) == 0, "different floating roots skipped")
	local nested = {
		{ name = "Card", rect = rect(0, 0, 200, 100), interactive = true },
		{ name = "Buy", parent = "Card", rect = rect(10, 10, 80, 40), interactive = true },
	}
	check(#runRule(Overlap.ActionCollision, F.build(nested, VP)) == 0, "ancestor/descendant skipped")
	local rotated = {
		{ name = "P", rect = rect(0, 0, 600, 400) },
		{ name = "A", parent = "P", rect = rect(100, 100, 40, 40), interactive = true, rotation = 45 },
		{ name = "B", parent = "P", rect = rect(132, 132, 40, 40), interactive = true, rotation = 45 },
	}
	check(#runRule(Overlap.ActionCollision, F.build(rotated, VP), { minOverlapPx = 1 }) == 0, "rotated corners that only touch AABBs are not collisions")
end)

section("Tracker confirmation kills transient spam", function()
	local tracker = E.Tracker.new()
	local function snapAt(x)
		return F.build({
			{ name = "P", rect = rect(0, 0, 600, 400) },
			{ name = "A", parent = "P", rect = rect(x, 10, 100, 40), interactive = true },
			{ name = "B", parent = "P", rect = rect(x + 50, 10, 100, 40), interactive = true },
		}, VP)
	end
	local function scan(snap, t)
		local found = runRule(Overlap.ActionCollision, snap)
		return tracker:update(found, snap, t, function(id) return snap.byId[id].path end)
	end
	-- tween: rect moves every scan -> never confirmed
	local logged = 0
	for i = 0, 5 do logged += #scan(snapAt(10 + i * 20), i * 0.5).toLog end
	check(logged == 0, "moving pair never logs")
	-- settles: confirms on the next scan that is >= 0.4s later
	local s = snapAt(200)
	local r1 = scan(s, 10)
	check(#r1.toLog == 0 and r1.pending == 1, "first stable sighting pending")
	local r2 = scan(s, 10.2)
	check(#r2.toLog == 0, "too soon to confirm")
	local r3 = scan(s, 10.6)
	check(#r3.toLog == 1, "confirmed after two stable scans")
	local r4 = scan(s, 11.2)
	check(#r4.toLog == 0 and #r4.active == 1, "not re-logged while unchanged")
	local clean = F.build({ { name = "P", rect = rect(0, 0, 600, 400) } }, VP)
	local r5 = tracker:update({}, clean, 12, function() return "?" end)
	check(#r5.resolved == 1, "resolution reported")
end)

section("GroupedLogger groups and rate-limits", function()
	local lines = {}
	local logger = Log.GroupedLogger.new(function(level, line) table.insert(lines, line) end, 0, 3, 0.1, 30)
	local findings = {}
	for i = 1, 12 do
		table.insert(findings, { rule = "TouchTarget", node = i, severity = 0.5, level = "warn", message = "small", signature = "TouchTarget|Inv.Slot#" })
	end
	logger:emit(findings, function(id) return "Inv.Slot" .. id end, 0)
	check(#lines == 1 and lines[1]:find("x12") ~= nil, "12 slots -> one line x12")
	local many = {}
	for i = 1, 10 do table.insert(many, { rule = "R" .. i, node = i, severity = 0.4, level = "warn", message = "m", signature = "R" .. i }) end
	logger:emit(many, function() return "p" end, 1)
	check(#lines <= 4, "bucket caps burst (" .. #lines .. " lines)")
	check(logger:pending() > 0, "held-back groups counted")
	logger:flushSummary(40)
	check(lines[#lines]:find("held back") ~= nil, "summary line emitted at window end")
	local bucket = Log.TokenBucket.new(2, 1, 0)
	check(bucket:take(0) and bucket:take(0) and not bucket:take(0), "token bucket burst")
	check(bucket:take(1.01), "token bucket refill")
end)

---------------------------------------------------------------------------------------------
-- Individual rules

section("ClippedContent / ViewportOverflow / SafeArea", function()
	local snap = F.build({
		{ name = "Card", rect = rect(0, 0, 200, 100), clips = true, drawn = true },
		{ name = "Btn", parent = "Card", rect = rect(150, 10, 100, 40), interactive = true },
	}, VP)
	local c = runRule(Clip.ClippedContent, snap)
	check(#c == 1 and math.abs(c[1].metrics.hidden - 0.5) < 1e-6, "half-clipped button")
	local off = runRule(Touch.ViewportOverflow, F.build({ { name = "B", rect = rect(1250, 10, 60, 40), interactive = true } }, VP))
	check(#off == 1 and off[1].hint ~= nil, "off-screen button with hint")
	local notch = F.viewport(844, 390, { deviceInsets = { left = 47, right = 47, top = 0, bottom = 21 }, touch = true })
	local sa = runRule(Touch.SafeArea, F.build({ { name = "Menu", rect = rect(10, 100, 60, 60), interactive = true } }, notch))
	check(#sa == 1, "button under the notch")
	local ok = runRule(Touch.SafeArea, F.build({ { name = "Menu", rect = rect(60, 100, 60, 60), interactive = true } }, notch))
	check(#ok == 0, "button inside the safe area")
end)

section("Occlusion", function()
	local snap = F.build({
		{ name = "Root", rect = rect(0, 0, 800, 600) },
		{ name = "Btn", parent = "Root", rect = rect(100, 100, 100, 50), interactive = true },
		{ name = "Toast", parent = "Root", rect = rect(150, 80, 200, 100), drawn = true, zIndex = 3 },
	}, VP)
	local o = runRule(Clip.Occlusion, snap)
	check(#o == 1 and math.abs(o[1].metrics.covered - 0.5) < 1e-6, "half covered by a toast")
	local modal = F.build({
		{ name = "Root", rect = rect(0, 0, 800, 600) },
		{ name = "Btn", parent = "Root", rect = rect(100, 100, 100, 50), interactive = true },
		{ name = "Modal", parent = "Root", rect = rect(0, 0, 800, 600), drawn = true, zIndex = 9 },
	}, VP)
	check(#runRule(Clip.Occlusion, modal) == 0, "full modal coverage is intentional")
end)

section("Text rules", function()
	local snap = F.build({
		{ name = "Title", rect = rect(0, 0, 60, 20), text = { text = "Legendary Sword of Ages", size = 18, fits = false } },
		{ name = "Fine", rect = rect(0, 30, 400, 30), text = { text = "Ok", size = 18 } },
		{ name = "Dots", rect = rect(0, 60, 40, 20), text = { text = "Very long label", size = 18, fits = false, truncate = true } },
	}, VP)
	local t = runRule(Text.TextOverflow, snap)
	check(#t == 1 and t[1].metrics.overflowX > 0, "overflowing title found, truncated skipped")
	check(Text.visibleText("<b>Hi</b> &amp; you", true) == "Hi & you", "rich text stripped")
	local touchVp = F.viewport(844, 390, { touch = true })
	local small = runRule(Text.TextTooSmall, F.build({ { name = "Tiny", rect = rect(0, 0, 100, 20), text = { text = "x", size = 14, scaled = true, bounds = { x = 10, y = 8 } } } }, touchVp))
	check(#small == 1, "scaled text collapsed to 8px on touch")
	local overlapText = F.build({
		{ name = "P", rect = rect(0, 0, 400, 200) },
		{ name = "L1", parent = "P", rect = rect(10, 10, 200, 20), text = { text = "Hello there", size = 14, bounds = { x = 150, y = 16 } } },
		{ name = "L2", parent = "P", rect = rect(100, 12, 200, 20), text = { text = "Overlapping", size = 14, bounds = { x = 150, y = 16 } } },
	}, VP)
	check(#runRule(Overlap.ContentOverlap, overlapText) == 1, "text-on-text collision")
end)

section("Touch targets", function()
	local touchVp = F.viewport(844, 390, { touch = true })
	local snap = F.build({
		{ name = "Big", rect = rect(0, 0, 48, 48), interactive = true },
		{ name = "Mid", rect = rect(100, 0, 30, 30), interactive = true },
		{ name = "Tiny", rect = rect(200, 0, 16, 16), interactive = true },
		{ name = "Tiny2", rect = rect(220, 0, 16, 16), interactive = true },
	}, touchVp)
	local t = runRule(Touch.TouchTarget, snap)
	local byName = {}
	for _, f in t do byName[snap.byId[f.node].name] = f end
	check(byName.Big == nil, "44+ ok")
	check(byName.Mid ~= nil and byName.Mid.level ~= "error", "30px warns softly")
	check(byName.Tiny ~= nil and byName.Tiny.level == "error", "crowded 16px is an error (no 2.5.8 spacing)")
	check(#runRule(Touch.TouchTarget, F.build({ { name = "Mid", rect = rect(0, 0, 30, 30), interactive = true } }, VP)) == 0, "desktop skipped")
	check(#runRule(Touch.TargetSpacing, snap) >= 1, "tiny targets 4px apart")
end)

section("Whitespace rules", function()
	local snap = F.build({
		{ name = "Panel", rect = rect(0, 0, 400, 600), drawn = true, whitespace = "Overview" },
		{ name = "Top", parent = "Panel", rect = rect(0, 0, 400, 100), drawn = true },
		{ name = "Mid", parent = "Panel", rect = rect(0, 110, 400, 50), drawn = true },
		{ name = "Bottom", parent = "Panel", rect = rect(0, 500, 400, 100), drawn = true },
	}, VP)
	local bands = runRule(WS.EmptyBand, snap)
	check(#bands == 1 and math.abs(G.height(bands[1].rect) - 340) < 1e-6, "340px interior empty row")
	check(bands[1].message:find("Overview") ~= nil, "uses the registered whitespace label")
	local sparse = F.build({
		{ name = "Panel", rect = rect(0, 0, 500, 500), drawn = true, whitespace = "Sparse" },
		{ name = "A", parent = "Panel", rect = rect(0, 0, 50, 50), drawn = true },
		{ name = "B", parent = "Panel", rect = rect(60, 0, 50, 50), drawn = true },
	}, VP)
	check(#runRule(WS.LowFill, sparse) == 1, "low fill panel")
	local cols = F.build({
		{ name = "Split", rect = rect(0, 0, 800, 700), drawn = true, whitespace = "SplitColumns" },
		{ name = "Left", parent = "Split", rect = rect(0, 0, 390, 700) },
		{ name = "L1", parent = "Left", rect = rect(0, 0, 390, 650), drawn = true },
		{ name = "Right", parent = "Split", rect = rect(410, 0, 390, 700) },
		{ name = "R1", parent = "Right", rect = rect(410, 0, 390, 200), drawn = true },
	}, VP)
	local ci = runRule(WS.ColumnImbalance, cols)
	check(#ci == 1 and ci[1].metrics.deadSpace > 400, "uneven columns")
end)

section("Alignment and gutters", function()
	local snap = F.build({
		{ name = "P", rect = rect(0, 0, 600, 600) },
		{ name = "A", parent = "P", rect = rect(20, 20, 200, 40), drawn = true },
		{ name = "B", parent = "P", rect = rect(20, 80, 200, 40), drawn = true },
		{ name = "C", parent = "P", rect = rect(22, 140, 200, 40), drawn = true },
	}, VP)
	local m = runRule(Align.Misalignment, snap)
	check(#m == 1 and snap.byId[m[1].node].name == "C", "2px near miss found on C")
	check(m[1].hint:find("left") ~= nil, "hint says move left")
	local gut = F.build({
		{ name = "Row", rect = rect(0, 0, 800, 100) },
		{ name = "A", parent = "Row", rect = rect(0, 0, 100, 50), drawn = true },
		{ name = "B", parent = "Row", rect = rect(110, 0, 100, 50), drawn = true },
		{ name = "C", parent = "Row", rect = rect(220, 0, 100, 50), drawn = true },
		{ name = "D", parent = "Row", rect = rect(350, 0, 100, 50), drawn = true },
	}, VP)
	local g = runRule(Align.GutterInconsistency, gut)
	check(#g == 1 and snap and g[1].metrics.median == 10, "30px gap among 10px gutters")
	local listOwned = F.build({
		{ name = "List", rect = rect(0, 0, 600, 600), layout = "list" },
		{ name = "A", parent = "List", rect = rect(20, 20, 200, 40), drawn = true },
		{ name = "B", parent = "List", rect = rect(20, 80, 200, 40), drawn = true },
		{ name = "C", parent = "List", rect = rect(22, 140, 200, 40), drawn = true },
	}, VP)
	check(#runRule(Align.Misalignment, listOwned) == 0, "layout-owned children skipped")
end)

section("Gamepad focus", function()
	local pad = F.viewport(1280, 720, { gamepad = true })
	local snap = F.build({
		{ name = "Root", rect = rect(0, 0, 1280, 720) },
		{ name = "A", parent = "Root", rect = rect(100, 100, 100, 40), interactive = true, selectionOrder = 3 },
		{ name = "B", parent = "Root", rect = rect(300, 100, 100, 40), interactive = true, selectionOrder = 2 },
		{ name = "C", parent = "Root", rect = rect(100, 300, 100, 40), interactive = true, selectionOrder = 1 },
	}, pad)
	local first = Focus.initialSelection({ snap.byId[1], snap.byId[2], snap.byId[3] })
	check(first.name == "C", "lowest SelectionOrder wins")
	local tie = Focus.initialSelection({
		{ selectionOrder = 0, rect = rect(300, 100, 10, 10), name = "right" },
		{ selectionOrder = 0, rect = rect(100, 100, 10, 10), name = "left" },
		{ selectionOrder = 0, rect = rect(0, 200, 10, 10), name = "lower" },
	})
	check(tie.name == "left", "tie -> top-most then left-most")
	check(#runRule(Focus.FocusOrder, snap) == 1, "reversed SelectionOrder flagged")
	check(#runRule(Focus.FocusOrder, F.build({ { name = "A", rect = rect(0, 0, 50, 50), interactive = true, selectionOrder = 1 } }, VP)) == 0, "no gamepad -> skipped")
	check(#runRule(Focus.FocusUnreachable, snap) == 0, "grid is fully reachable")
	snap.byId[3].nextSelection.up = -2
	check(#runRule(Focus.FocusDeadLink, snap) == 1, "dead NextSelectionUp")
	-- B can only be left via an explicit link that points back to itself: an island
	local island = F.build({
		{ name = "Root", rect = rect(0, 0, 1280, 720) },
		{ name = "A", parent = "Root", rect = rect(100, 100, 100, 40), interactive = true },
		{ name = "B", parent = "Root", rect = rect(300, 100, 100, 40), interactive = true },
	}, pad)
	island.byId[1].nextSelection.right = 1
	check(#runRule(Focus.FocusUnreachable, island) == 1, "explicit link hides B")
end)

section("Scroll and geometry", function()
	local snap = F.build({ { name = "List", kind = "scroll", rect = rect(0, 0, 300, 400) } }, VP)
	local n = snap.byId[0]
	n.scroll = { canvas = { x = 300, y = 600 }, window = { x = 300, y = 400 }, canvasPos = { x = 0, y = 0 }, scrollX = false, scrollY = true, enabled = true, automatic = false, content = { x = 300, y = 900 } }
	local c = runRule(Scroll.CanvasOverflow, snap)
	check(#c == 1 and c[1].metrics.overY == 300, "300px past CanvasSize")
	n.scroll.enabled = false
	check(#runRule(Scroll.DisabledScroll, snap) == 1, "disabled overflowing scroller")
	local bad = F.build({ { name = "NaN", rect = { x0 = 0 / 0, y0 = 0, x1 = 10, y1 = 10 } } }, VP)
	check(#runRule(Scroll.InvalidGeometry, bad) == 1, "NaN rect")
end)

section("Suppression attributes", function()
	local specs = {
		{ name = "Panel", rect = rect(0, 0, 600, 400), drawn = true, suppress = { "ActionCollision" } },
		{ name = "A", parent = "Panel", rect = rect(10, 10, 100, 40), interactive = true },
		{ name = "B", parent = "Panel", rect = rect(60, 10, 100, 40), interactive = true },
	}
	check(#runRule(Overlap.ActionCollision, F.build(specs, VP)) == 0, "LayoutGuardSuppress on an ancestor")
	specs[1].suppress = { "*" }
	check(#runRule(Overlap.ActionCollision, F.build(specs, VP)) == 0, "LayoutGuardIgnore (*)")
end)

---------------------------------------------------------------------------------------------
-- Engine, config, matrix, report

section("parseConfig", function()
	local parsed = E.parseConfig("ActionCollision=off, TouchTarget.recommendedPx=48, EmptyBand.minSeverity=0.3, SmallTouchTarget.minimumPx=20, Bogus=on, TouchTarget.nope=1")
	local configs, errors = parsed[1], parsed[2]
	local ac, tt, eb = nil, nil, nil
	for id, c in configs do
		if id == "ActionCollision" then ac = c elseif id == "TouchTarget" then tt = c elseif id == "EmptyBand" then eb = c end
	end
	check(ac.enabled == false, "rule disabled")
	check(tt.params.recommendedPx == 48, "param override")
	check(tt.params.minimumPx == 20, "legacy id maps to new rule")
	check(eb.minSeverity == 0.3, "minSeverity override")
	check(#errors == 2, "unknown rule and key reported (" .. #errors .. ")")
end)

section("runRules isolates failures and honours profiles", function()
	local snap = F.build({ { name = "B", rect = rect(1250, 10, 60, 40), interactive = true } }, VP)
	local configs = E.parseConfig("")[1]
	local boom = { id = "Boom", title = "", profile = "lite", defaults = {}, run = function(_self) error("kaput") end }
	local rules = { boom, R.RULE_BY_ID.ViewportOverflow, R.RULE_BY_ID.EmptyBand }
	local ran = E.runRules(snap, configs, "lite", approxMeasure, function() end, nil, rules)
	local findings, stats = ran[1], ran[2]
	check(#stats.failures == 1, "failing rule reported")
	check(#findings == 1 and findings[1].rule == "ViewportOverflow", "other rules still ran")
	check(stats.rules == 2, "full-profile rule skipped in lite")
	check(#R.RULES >= 23, "registry has every rule (" .. #R.RULES .. ")")
end)

section("inSample is deterministic and near the rate", function()
	local hits = 0
	for uid = 1, 20000 do if E.inSample(uid * 7919, 0.02) then hits += 1 end end
	check(hits > 250 and hits < 550, "about 2% sampled (" .. hits .. ")")
	check(E.inSample(42, 0.5) == E.inSample(42, 0.5), "stable per user")
	check(not E.inSample(42, 0) and E.inSample(42, 1), "rate bounds")
end)

section("Device matrix", function()
	local rowKids = {}
	for i = 1, 6 do table.insert(rowKids, L.vnode(i, "Action" .. i, { size = C.udim2(0, 120, 0, 40) }, {}, { layoutOrder = i })) end
	local bar = L.vnode(0, "Bar", { size = C.udim2(1, 0, 0, 40) }, rowKids, { layout = L.defaultList({ fill = "Horizontal" }) })
	local root = L.vnode(-1, "Layer", { size = C.fromScale(1, 1) }, { bar })
	-- template snapshot with matching ids (0 = bar, 1..6 = actions)
	local specs = { { name = "Bar", rect = rect(0, 0, 1280, 40) } }
	for i = 1, 6 do table.insert(specs, { name = "Action" .. i, parent = "Bar", rect = rect((i - 1) * 120, 0, 120, 40), interactive = true }) end
	local template = F.build(specs, VP)
	local results = Mx.runMatrix(template, { { layer = 0, root = root, ignoreInset = true } }, function(s)
		return runRule(Touch.ViewportOverflow, s)
	end, approxMeasure)
	check(#results == 11, "eleven phones")
	local se
	for _, r in results do if r.device == "iPhone SE" then se = r end end
	check(se and #se.findings >= 1, "720px bar overflows the 667px iPhone SE")
	local summary = Mx.summarizeMatrix(results)
	check(#summary >= 1 and summary[1].message:find("phones") ~= nil, "folded per signature with device count")
	check(summary[1].rule:sub(1, 13) == "DeviceMatrix:", "matrix rule prefix")
end)

section("Report and heatmap", function()
	local snap = F.build({
		{ name = "Panel", rect = rect(0, 0, 600, 400), drawn = true },
		{ name = "A", parent = "Panel", rect = rect(10, 10, 100, 40), interactive = true },
		{ name = "B", parent = "Panel", rect = rect(60, 10, 100, 40), interactive = true },
	}, VP)
	local found = runRule(Overlap.ActionCollision, snap)
	local active = {}
	for _, f in found do table.insert(active, { finding = f }) end
	local pathOf = function(id) return snap.byId[id].path end
	local report = Rep.buildReport(snap, active, {}, "full", { scans = 1 }, pathOf)
	check(report.totals.error + report.totals.warn + report.totals.info == 1, "totals")
	check(report.score < 100 and report.score > 0, "score drops (" .. report.score .. ")")
	check(Rep.reportText(report):find("ActionCollision") ~= nil, "text rendering")
	check(Rep.scoreOf({}) == 100, "clean = 100")
	local h = Heat.heatmap(480, 240, { { rect = rect(0, 0, 48, 48), weight = 1 } }, 48, 1)
	check(h.cols == 10 and h.rows == 5, "heat grid dims")
	check(Heat.intensity(h, 0) == 1 and Heat.intensity(h, 9) == 0, "heat peaks at the spot")
end)

print(("verify_layout_guard: %d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("layout guard tests failed")
end
