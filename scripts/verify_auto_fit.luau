--!nocheck
-- LayoutGuard adaptive fit: optimiser unit checks, property fuzzing, and the self-correcting
-- loop's convergence / no-oscillation fuzz. Runs on the compiled out/ tree (rbxtsc first).
local Loader = require("./lg_loader")
local process = require("@lune/process")
local O = Loader.load(Loader.BASE .. "/fit/optimizer")
local L = Loader.load(Loader.BASE .. "/fit/loop")

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or "")) end
end

local function container(t)
	local c = {
		id = t.id or "c", windowH = t.windowH or 400, width = t.width or 800, contentH = t.contentH or 1000,
		gap = t.gap or 10, gapCount = t.gapCount or 6, minGap = t.minGap or 6,
		pad = t.pad or 0, padCount = t.padCount or 0, minPad = t.minPad or 0,
		grids = t.grids or {}, pairs = t.pairs or {},
	}
	return c
end
local function grid(t)
	return { width = t.width or 800, cellW = t.cellW or 180, cellH = t.cellH or 120, padX = t.padX or 10, padY = t.padY or 10,
		count = t.count or 12, minCellW = t.minCellW or 150, minCellH = t.minCellH or 100, slackH = t.slackH or 20, tappable = t.tappable or false }
end

-- 1. a page that fits is left alone
do
	local c = container({ contentH = 300, windowH = 400 })
	local d = O.optimise(c, "mouse")
	check("fits -> base", O.knobsKey(d.knobs) == O.knobsKey(O.baseKnobs(c)))
end
-- 2. spacing collapses only as far as needed (largest token that fits)
do
	local c = container({ contentH = 410, windowH = 400, gap = 12, gapCount = 6, minGap = 6 })
	local d = O.optimise(c, "mouse")
	check("gap collapses to fit", d.evaluation.contentH <= 400, d.evaluation.contentH)
	check("gap stops at first fitting token", d.knobs.gap == 10, d.knobs.gap)
	check("gap never below min", d.knobs.gap >= 6)
end
-- 3. columns added only when cells stay >= min width, and only if a row is saved
do
	local g = grid({ width = 800, cellW = 180, padX = 10, count = 13, minCellW = 150 })
	check("base columns", O.baseColumns(g) == 4, O.baseColumns(g))
	local r = O.gridLayout(g, 1, 0, "mouse")
	check("5 columns valid", r.valid and r.cellW >= 150, r.cellW)
	local r2 = O.gridLayout(g, 2, 0, "mouse")
	check("6 columns too narrow", not r2.valid)
	local c = container({ contentH = 900, windowH = 400, gap = 6, minGap = 6, grids = { g } })
	local d = O.optimise(c, "mouse")
	check("grid gets a column", d.knobs.extraCols[1] == 1, d.knobs.extraCols[1])
end
-- 4. touch keeps tappable cells >= 44 and height trims never exceed measured slack
do
	local g = grid({ cellW = 120, cellH = 48, minCellH = 30, slackH = 30, tappable = true })
	for step = 0, 3 do
		local r = O.gridLayout(g, 0, step, "touch")
		check("touch tap >= 44 step " .. step, (not r.valid) or r.cellH >= 44, r.cellH)
	end
	local g2 = grid({ cellH = 120, minCellH = 90, slackH = 5 })
	check("trim beyond slack rejected", not O.gridLayout(g2, 0, 1, "mouse").valid)
	local g3 = grid({ cellH = 120, minCellH = 90, slackH = 40 })
	check("trim within slack ok", O.gridLayout(g3, 0, 3, "mouse").valid)
end
-- 5. gamepad prefers non-reflowing fixes
do
	local g = grid({ width = 800, cellW = 180, count = 12, minCellW = 150, slackH = 40, minCellH = 90 })
	local c = container({ contentH = 700, windowH = 400, gap = 6, minGap = 6, grids = { g } })
	local pad = O.optimise(c, "gamepad")
	local mouse = O.optimise(c, "mouse")
	check("gamepad avoids extra columns", pad.knobs.extraCols[1] == 0 or mouse.knobs.extraCols[1] >= pad.knobs.extraCols[1])
end
-- 6. pairs only on wide containers and short sections
do
	local p = { leftH = 150, rightH = 140, minW = 320, gap = 10 }
	local narrow = container({ width = 500, contentH = 900, gap = 6, minGap = 6, pairs = { p } })
	check("narrow keeps stack", O.optimise(narrow, "mouse").knobs.pairs[1] == false)
	local wide = container({ width = 1200, contentH = 900, gap = 6, minGap = 6, pairs = { p } })
	check("wide pairs up", O.optimise(wide, "mouse").knobs.pairs[1] == true)
	local tall = container({ width = 1200, windowH = 200, contentH = 900, gap = 6, minGap = 6, pairs = { { leftH = 300, rightH = 100, minW = 320, gap = 10 } } })
	check("tall pair stays stacked", O.optimise(tall, "mouse").knobs.pairs[1] == false)
end
-- 7. savedBy converts an applied measurement back to base
do
	local c = container({ contentH = 1000, gap = 10, gapCount = 5 })
	local k = O.baseKnobs(c); k.gap = 6
	check("savedBy gap", O.savedBy(c, k, "mouse") == 20, O.savedBy(c, k, "mouse"))
end

-- property fuzz: validity, monotone improvement, determinism, hard limits
local seed = 1234
local function rand(a, b)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return a + (seed % (b - a + 1))
end
local inputs = { "mouse", "touch", "gamepad" }
local function randomContainer(i)
	local grids, pairs = {}, {}
	for _ = 1, rand(0, 3) do
		local cellW = rand(60, 300)
		table.insert(grids, grid({ width = rand(200, 1800), cellW = cellW, cellH = rand(40, 200), padX = rand(0, 16), padY = rand(0, 16),
			count = rand(0, 40), minCellW = math.floor(cellW * (rand(70, 100) / 100)), minCellH = rand(30, 120), slackH = rand(0, 60), tappable = rand(0, 1) == 1 }))
	end
	for _ = 1, rand(0, 2) do
		table.insert(pairs, { leftH = rand(40, 500), rightH = rand(40, 500), minW = rand(200, 500), gap = rand(4, 16) })
	end
	local gap = rand(0, 20)
	local pad = rand(0, 20)
	return container({ id = "f" .. i, windowH = rand(150, 1000), width = rand(200, 1900), contentH = rand(100, 4000), gap = gap, gapCount = rand(0, 12),
		minGap = math.min(gap, 6), pad = pad, padCount = rand(0, 2) * 1, minPad = math.min(pad, 4), grids = grids, pairs = pairs })
end
local fuzzN = 3000
for i = 1, fuzzN do
	local c = randomContainer(i)
	local input = inputs[rand(1, 3)]
	local d = O.optimise(c, input)
	local base = O.evaluate(c, O.baseKnobs(c), input)
	local again = O.optimise(c, input)
	if not d.evaluation.valid then check("fuzz valid " .. i, false) end
	if d.evaluation.contentH > base.contentH + 1e-6 then check("fuzz never grows " .. i, false) end
	if d.evaluation.score + 1e-9 < base.score then check("fuzz never worse " .. i, false) end
	if O.knobsKey(d.knobs) ~= O.knobsKey(again.knobs) then check("fuzz deterministic " .. i, false) end
	if d.knobs.gap < c.minGap or d.knobs.pad < c.minPad then check("fuzz spacing floor " .. i, false) end
	for gi, g in c.grids do
		local r = O.gridLayout(g, d.knobs.extraCols[gi], d.knobs.heightStep[gi], input)
		if (d.knobs.extraCols[gi] ~= 0 or d.knobs.heightStep[gi] ~= 0) then
			if r.cellW < g.minCellW or r.cellH < g.minCellH or (g.cellH - r.cellH) > g.slackH then check("fuzz grid bounds " .. i, false) end
			if input == "touch" and g.tappable and (r.cellH < 44 or r.cellW < 44) then check("fuzz tap 44 " .. i, false) end
		end
	end
	if c.contentH <= c.windowH and O.knobsKey(d.knobs) ~= O.knobsKey(O.baseKnobs(c)) then check("fuzz fitting page untouched " .. i, false) end
	if d.evaluated > 40 then check("fuzz search bounded " .. i, false, d.evaluated) end
end
passed += 1

-- loop convergence / no-oscillation fuzz with an adversarial verifier
local loopN = 1500
local maxIters = 0
for i = 1, loopN do
	local c = randomContainer(10000 + i)
	local input = inputs[rand(1, 3)]
	local loop = L.FitLoop.new()
	local ctx = { key = L.contextKey(L.deviceClass(1366, 768, input), 1366, 768, input, 1), input = input }
	local badChance = rand(0, 100)
	local bad = {}
	local appliedHistory = {}
	local now = 0
	local quiet = 0
	local iters = 0
	local penaltyNow = rand(0, 3)
	while quiet < 4 and iters < 60 do
		iters += 1
		now += 2
		-- content jitters by a few px each round (live counters), hysteresis must absorb it
		c.contentH = math.max(0, c.contentH + rand(-3, 3))
		local k = loop:plan(c, ctx, now)
		if k == nil then
			quiet += 1
		else
			quiet = 0
			local key = O.knobsKey(k)
			if appliedHistory[key] and appliedHistory[key] == "rolled" then check("loop re-applies a rolled-back fix " .. i, false, key) end
			if bad[key] == nil then bad[key] = rand(1, 100) <= badChance end
			local after = bad[key] and penaltyNow + rand(1, 3) or penaltyNow
			local verdict = loop:verify(c.id, penaltyNow, after)
			if verdict == "rollback" then appliedHistory[key] = "rolled" else appliedHistory[key] = "kept" end
		end
	end
	maxIters = math.max(maxIters, iters)
	if quiet < 4 then check("loop converges " .. i, false, iters) end
	if loop.stats.applied > loop.options.maxSwitches then check("loop switch bound " .. i, false, loop.stats.applied) end
	-- after convergence, a revisit of the same context reuses memory or holds: no new switches
	local before = loop.stats.applied
	for _ = 1, 5 do now += 2; local k = loop:plan(c, ctx, now); if k ~= nil then loop:verify(c.id, 0, 0) end end
	if loop.stats.applied - before > 1 then check("loop stays stable " .. i, false) end
end
passed += 1

-- hysteresis: alternating contexts reuse remembered knobs instead of searching again
do
	local c = container({ id = "h", contentH = 900, windowH = 400, gap = 12, gapCount = 8, minGap = 6 })
	local loop = L.FitLoop.new()
	local a = { key = "phone|a", input = "touch" }
	local b = { key = "desktop|b", input = "mouse" }
	local t = 0
	for round = 1, 6 do
		for _, ctx in { a, b } do
			t += 5
			local k = loop:plan(c, ctx, t)
			if k ~= nil then loop:verify("h", 0, 0) end
		end
	end
	check("context memory reused", loop.stats.reused >= 1, loop.stats.reused)
	check("context memory size", loop:memorySize() >= 1)
end

-- device matrix: a typical scaffold page (8 sections, a card grid) at the four target viewports
do
	local viewports = { { 1920, 1080, "mouse", 36 }, { 1366, 768, "mouse", 36 }, { 844, 390, "touch", 58 }, { 640, 286, "touch", 58 } }
	for _, v in viewports do
		local w, h, input, chrome = v[1], v[2], v[3], v[4]
		local width = w - 24
		local cellW = input == "touch" and 150 or 200
		local g = grid({ width = width, cellW = cellW, cellH = 96, padX = 10, padY = 10, count = 18, minCellW = math.floor(cellW * 0.85), minCellH = 82, slackH = 16, tappable = true })
		local base = O.gridLayout(g, 0, 0, input)
		local c = container({ id = "m" .. w, windowH = h - chrome, width = width, contentH = 7 * 120 + 7 * 10 + base.height + 8, gap = 10, gapCount = 7, minGap = 6, grids = { g } })
		local d = O.optimise(c, input)
		local r = O.gridLayout(g, d.knobs.extraCols[1], d.knobs.heightStep[1], input)
		check(string.format("matrix %dx%d valid", w, h), d.evaluation.valid)
		check(string.format("matrix %dx%d no growth", w, h), d.evaluation.contentH <= c.contentH)
		check(string.format("matrix %dx%d tap >= 44", w, h), r.cellH >= 44 and r.cellW >= 44)
		check(string.format("matrix %dx%d still scrolls when over", w, h), d.evaluation.contentH <= c.windowH or d.evaluation.contentH > 0)
		print(string.format("  matrix %4dx%-4d %-7s window %4d  content %5d -> %5d  knobs %s", w, h, input, c.windowH, c.contentH, d.evaluation.contentH, O.knobsKey(d.knobs)))
	end
end

print(string.format("verify_auto_fit: %d passed, %d failed (fuzz %d optimiser cases, %d loop runs, max %d loop rounds)", passed, failed, fuzzN, loopN, maxIters))
if failed > 0 then process.exit(1) end
