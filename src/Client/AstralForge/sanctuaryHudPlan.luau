--!strict
-- Where everything goes on screen while the player walks the sanctuary.
--
-- One pure function turns the safe-area size and input kind into pixel
-- rectangles for every piece of sanctuary UI: the navigation docks (or the
-- menu button that replaces them), the ore chips, the Warden bar, the strike
-- and recall buttons, the touch jump/run cluster, the thumbstick zone and the
-- sheets. The HUD, the curtain docks and the touch controls all read the same
-- plan, so they can never disagree about who owns a corner.
--
-- Rules the plan keeps at every size (scripts/verify_sanctuary_hud_plan.luau
-- sweeps hundreds of screens to hold it to them):
--   * every rectangle lies inside the safe area;
--   * no two interactive rectangles overlap, and none sits in the
--     thumbstick zone;
--   * touch targets are at least MIN_TAP pixels on both sides;
--   * the docks become a single menu button whenever a column of them would
--     not fit at a comfortable size.
--
-- Coordinates are pixels from the top-left of the CoreUISafeInsets area.
-- No Roblox services are used, so Lune can run it.

export type Rect = { x: number, y: number, w: number, h: number }

export type Input = {
	width: number,
	height: number,
	touch: boolean,
	-- Entries per dock column (both columns hold the same count).
	dockEntries: number?,
}

export type Plan = {
	width: number,
	height: number,
	touch: boolean,
	portrait: boolean,
	edge: number,
	gap: number,
	-- "columns": two vertical docks. "menu": one button opens a sheet.
	dockMode: string,
	dockButton: number,
	dockGap: number,
	dockLeft: Rect?,
	dockRight: Rect?,
	menuButton: Rect?,
	-- Ore chips and the Warden bar.
	ore: Rect,
	oreChip: number,
	oreCompact: boolean,
	warden: Rect,
	-- Buttons.
	strike: Rect,
	recall: Rect,
	jump: Rect?,
	run: Rect?,
	stickZone: Rect?,
	-- Transient, non-interactive.
	banner: Rect,
	hint: Rect?,
	-- Centered sheets (menu, waystone travel).
	sheet: Rect,
	sheetColumns: number,
	sheetRow: number,
	text: { title: number, body: number, label: number, number: number },
}

local Plan = {}

Plan.MIN_TAP = 44
Plan.ORE_KINDS = 3

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = math.floor(x), y = math.floor(y), w = math.max(0, math.floor(w)), h = math.max(0, math.floor(h)) }
end

local function clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

-- Do two rectangles share any area? Touching edges do not count.
function Plan.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function Plan.inside(inner: Rect, width: number, height: number): boolean
	return inner.x >= 0 and inner.y >= 0 and inner.x + inner.w <= width and inner.y + inner.h <= height
end

-- The interactive rectangles of a plan, by name, for overlap checks.
function Plan.interactive(plan: Plan): { [string]: Rect }
	local result: { [string]: Rect } = {
		ore = plan.ore,
		warden = plan.warden,
		strike = plan.strike,
		recall = plan.recall,
	}
	if plan.dockLeft ~= nil then
		result.dockLeft = plan.dockLeft
	end
	if plan.dockRight ~= nil then
		result.dockRight = plan.dockRight
	end
	if plan.menuButton ~= nil then
		result.menuButton = plan.menuButton
	end
	if plan.jump ~= nil then
		result.jump = plan.jump
	end
	if plan.run ~= nil then
		result.run = plan.run
	end
	return result
end

function Plan.compute(input: Input): Plan
	local width = math.max(200, math.floor(input.width))
	local height = math.max(200, math.floor(input.height))
	local touch = input.touch == true
	local entries = math.max(1, input.dockEntries or 6)
	local short = math.min(width, height)
	local portrait = height > width
	local edge = clamp(math.floor(short * 0.03), 10, 24)
	local gap = clamp(math.floor(short * 0.018), 6, 12)
	local tap = if touch then Plan.MIN_TAP else 36

	local text = {
		title = clamp(math.floor(short * 0.05), 20, 34),
		body = clamp(math.floor(short * 0.03), 13, 17),
		label = clamp(math.floor(short * 0.024), 11, 14),
		number = clamp(math.floor(short * 0.034), 14, 20),
	}

	-- The top strip holds, left to right: the menu button (menu mode), the
	-- recall button (touch), the Warden bar, the ore chips.
	local stripH = math.max(tap, clamp(math.floor(short * 0.075), 36, 48))
	local top = edge

	-- Touch cluster first: it owns the bottom-right corner on touch screens.
	local jump: Rect? = nil
	local run: Rect? = nil
	local clusterTop = height - edge
	if touch then
		local jumpSize = clamp(math.floor(short * 0.19), 64, 96)
		local runSize = math.max(Plan.MIN_TAP, math.floor(jumpSize * 0.74))
		local j = rect(width - edge - jumpSize, height - edge - jumpSize, jumpSize, jumpSize)
		local r = rect(j.x - math.floor(gap * 1.5) - runSize, height - edge - runSize - math.floor(jumpSize * 0.35), runSize, runSize)
		jump, run = j, r
		clusterTop = math.min(j.y, r.y)
	end

	-- Strike: the big action. On touch it sits above the jump button, in the
	-- thumb's arc; with a mouse or gamepad it is a wide pill at bottom center.
	local strike: Rect
	if touch then
		local j = jump :: Rect
		local size = math.max(Plan.MIN_TAP, math.floor(j.w * 0.96))
		strike = rect(j.x + j.w - size, clusterTop - gap * 2 - size, size, size)
	else
		local w = clamp(math.floor(width * 0.2), 160, 260)
		local h = clamp(math.floor(short * 0.07), 44, 56)
		strike = rect((width - w) / 2, height - edge - h, w, h)
	end

	-- Recall. Touch: a square beside the menu button, so the lower-left stays
	-- free for the thumbstick. Mouse/gamepad: a pill at the bottom-left.
	local recallW = if touch then stripH else math.max(tap, clamp(math.floor(short * 0.2), 96, 132))
	local recallH = if touch then stripH else math.max(tap, clamp(math.floor(short * 0.06), 36, 44))
	local menuSize = math.max(tap, clamp(math.floor(short * 0.075), 40, 52))

	local dockGap = clamp(math.floor(short * 0.014), 8, 14)
	local dockButton = 0
	local dockLeft: Rect? = nil
	local dockRight: Rect? = nil
	local menuButton: Rect? = nil
	local recall = rect(0, 0, recallW, recallH)
	local ore = rect(0, 0, 0, 0)
	local warden = rect(0, 0, 0, 0)
	local chip = 0
	local oreCompact = false
	local wardenH = clamp(math.floor(short * 0.085), 44, 58)

	-- Lays out the top strip from `leftEdge` (the first free x) and returns
	-- the lowest y the top rows reach.
	local function placeTop(leftEdge: number): number
		local chipGap = math.max(4, math.floor(gap * 0.6))
		chip = clamp(math.floor(width * 0.085), 60, 112)
		oreCompact = false
		local room = width - edge - leftEdge
		if chip * Plan.ORE_KINDS + chipGap * (Plan.ORE_KINDS - 1) > room then
			chip = math.floor((room - chipGap * (Plan.ORE_KINDS - 1)) / Plan.ORE_KINDS)
		end
		if chip < 72 then
			oreCompact = true
		end
		local oreW = chip * Plan.ORE_KINDS + chipGap * (Plan.ORE_KINDS - 1)
		ore = rect(width - edge - oreW, top, oreW, stripH)
		-- The Warden bar: centred between the left group and the chips when it
		-- fits with room to breathe, otherwise its own row beneath the strip.
		local between = ore.x - gap - leftEdge
		if between >= 260 then
			-- Centred on the screen, and only nudged aside when it would touch
			-- the menu/recall group or the ore chips.
			local w = math.min(520, between)
			local x = math.clamp((width - w) / 2, leftEdge, ore.x - gap - w)
			warden = rect(x, top, w, math.max(stripH, wardenH))
		else
			local w = math.min(520, width - 2 * edge)
			warden = rect((width - w) / 2, top + stripH + gap, w, wardenH)
		end
		return math.max(ore.y + ore.h, warden.y + warden.h)
	end

	local function menuMode(): number
		dockLeft, dockRight = nil, nil
		dockButton = menuSize
		menuButton = rect(edge, top, menuSize, stripH)
		local leftEdge = edge + menuSize + gap
		if touch then
			recall = rect(leftEdge, top, recallW, recallH)
			leftEdge = recall.x + recall.w + gap
		end
		return placeTop(leftEdge)
	end

	-- Docks: two columns when they fit comfortably (and never on touch, where
	-- the edges belong to thumbs), otherwise one menu button.
	local dockMode = "menu"
	local topOccupied: number
	if touch then
		topOccupied = menuMode()
	else
		topOccupied = placeTop(edge)
		local bandTop = topOccupied + gap
		local bandBottom = height - edge - math.max(strike.h, recallH) - gap
		local band = bandBottom - bandTop
		local button = math.min(64, math.floor((band - dockGap * (entries - 1)) / entries))
		local centerRoom = width - 2 * (edge + button + gap)
		if button >= 46 and centerRoom >= math.max(360, strike.w + 2 * (recallW + gap)) then
			dockMode = "columns"
			dockButton = button
			local columnH = button * entries + dockGap * (entries - 1)
			local y = bandTop + math.floor((band - columnH) / 2)
			dockLeft = rect(edge, y, button, columnH)
			dockRight = rect(width - edge - button, y, button, columnH)
		else
			topOccupied = menuMode()
		end
	end

	if not touch then
		recall = rect(edge, height - edge - recallH, recallW, recallH)
		-- A narrow window: the centred strike pill would cover recall, so it
		-- moves to the bottom-right; narrower still, recall steps up a row.
		if Plan.overlaps(strike, recall) then
			strike = rect(width - edge - strike.w, strike.y, strike.w, strike.h)
			if Plan.overlaps(strike, recall) then
				recall = rect(edge, strike.y - gap - recallH, recallW, recallH)
			end
		end
	end

	-- Strike must never climb into the top rows on a short touch screen: shrink
	-- it into the space above the cluster, or else set it left of run.
	if touch and strike.y < topOccupied + gap then
		local j = jump :: Rect
		local r = run :: Rect
		local size = math.min(math.floor(j.w * 0.96), clusterTop - gap * 2 - (topOccupied + gap))
		if size >= Plan.MIN_TAP then
			strike = rect(j.x + j.w - size, clusterTop - gap * 2 - size, size, size)
		else
			size = math.max(Plan.MIN_TAP, math.min(j.w, r.x - gap - math.floor(width * 0.5)))
			strike = rect(r.x - gap - size, height - edge - size, size, size)
		end
	end

	-- Thumbstick zone: the lower-left, below the top rows and clear of the
	-- right-hand cluster.
	local stickZone: Rect? = nil
	if touch then
		local zoneTop = topOccupied + gap
		local right = math.floor(width * 0.5)
		for _, other in { run :: Rect, strike } do
			if other.x < right and other.y + other.h > zoneTop then
				right = math.min(right, other.x - gap)
			end
		end
		stickZone = rect(0, zoneTop, math.max(0, right), height - zoneTop)
	end

	-- Region banner: the upper third, never interactive.
	local bannerW = math.min(width - 2 * edge, 560)
	local bannerH = text.title * 2 + 24
	local bannerY = math.min(math.max(topOccupied + gap, math.floor(height * 0.2)), height - bannerH - edge)
	local banner = rect((width - bannerW) / 2, math.max(0, bannerY), bannerW, bannerH)

	-- The key hint row, mouse/keyboard only: bottom-right, dropped if crowded.
	local hint: Rect? = nil
	if not touch then
		local w = clamp(math.floor(width * 0.24), 180, 320)
		local h = text.label + 12
		local candidate = rect(width - edge - w, height - edge - h, w, h)
		local clear = not Plan.overlaps(candidate, strike) and not Plan.overlaps(candidate, recall)
		if dockRight ~= nil and Plan.overlaps(candidate, dockRight) then
			clear = false
		end
		if clear then
			hint = candidate
		end
	end

	-- Sheets: centered, capped, and clear of the notch area by the edge margin.
	local sheetW = math.min(width - 2 * edge, 560)
	local sheetH = math.min(height - 2 * edge, 520)
	local sheet = rect((width - sheetW) / 2, (height - sheetH) / 2, sheetW, sheetH)
	local sheetColumns = if sheetW >= 520 then 4 elseif sheetW >= 380 then 3 else 2
	local sheetRow = math.max(tap, clamp(math.floor(short * 0.1), 48, 64))

	return {
		width = width,
		height = height,
		touch = touch,
		portrait = portrait,
		edge = edge,
		gap = gap,
		dockMode = dockMode,
		dockButton = dockButton,
		dockGap = dockGap,
		dockLeft = dockLeft,
		dockRight = dockRight,
		menuButton = menuButton,
		ore = ore,
		oreChip = chip,
		oreCompact = oreCompact,
		warden = warden,
		strike = strike,
		recall = recall,
		jump = jump,
		run = run,
		stickZone = stickZone,
		banner = banner,
		hint = hint,
		sheet = sheet,
		sheetColumns = sheetColumns,
		sheetRow = sheetRow,
		text = text,
	}
end

-- UDim2 helpers for the plan's rectangles (Roblox only).
function Plan.position(r: Rect): UDim2
	return UDim2.fromOffset(r.x, r.y)
end

function Plan.size(r: Rect): UDim2
	return UDim2.fromOffset(r.w, r.h)
end

return Plan
