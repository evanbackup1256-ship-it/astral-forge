-- Mobile layout engine (v2). Ground-up rewrite of the mobile sizing/breakpoint math.
--
-- The old system computed a single sprawling "plan" object shared by a rail-collapse-into-
-- drawer navigation pattern, a floating draggable quick bar, and a floating draggable "more"
-- dock, with every dimension keyed off `stack`/`landscape`/`tablet` flags threaded through
-- dozens of call sites. This version targets a single, fixed navigation pattern for touch/
-- narrow devices instead: a bottom tab bar. That eliminates the entire class of "nav container
-- mid-animation gets the wrong size" bugs the old drawer had, because nothing about the tab
-- bar's size ever animates — it's a constant height computed once from the viewport.
--
-- Three tiers only, chosen from raw viewport geometry:
--   - "bar"      phone/narrow portrait or short-landscape: bottom tab bar, compact header
--   - "tablet"   wide enough for a comfortable side rail but still touch-first
--   - "desktop"  unchanged, full sidebar shell (this module does not size desktop chrome)
local TAP_TARGET = 48
local MORE_COUNT = 10
-- Modern phones in landscape are often ≥900px wide, so do not gate on compact/tight
-- (those flags key off width and wrongly force landscape phones into portrait tablet chrome).
local function isMobileLandscape(width, height, _compact, _tight)
	return width > height and height < 700
end
local function fitPanelHeight(desired, budget, minH, maxShare)
	if minH == nil then
		minH = 96
	end
	if maxShare == nil then
		maxShare = 0.55
	end
	local cap = math.max(minH, math.floor(budget * maxShare))
	return math.clamp(desired, minH, cap)
end
local function moreDockHeight(stack, count, cols, cellH, gap)
	if count == nil then
		count = MORE_COUNT
	end
	if cols == nil then
		cols = 4
	end
	if cellH == nil then
		cellH = TAP_TARGET
	end
	if gap == nil then
		gap = 6
	end
	if not stack then
		return TAP_TARGET + 8
	end
	local safeCols = math.max(1, cols)
	local rows = math.max(1, math.ceil(math.max(1, count) / safeCols))
	return rows * (cellH + math.clamp(gap, 2, 12)) + 18
end
local function fitTouchGridWidth(viewportWidth, edgePad, sideSafe, cols, gap, scale)
	local available = math.max(180, viewportWidth - math.max(edgePad, sideSafe) * 2)
	local minimum = math.max(1, cols) * (TAP_TARGET + math.max(0, gap)) + 10
	return math.min(available, math.max(minimum, available * math.clamp(scale, 0, 1)))
end
local function scrollTail(stack, bottomSafe, base)
	if base == nil then
		base = 40
	end
	if not stack then
		return base
	end
	return base + math.max(bottomSafe, 12) + 16
end
local function planMobileLayout(input)
	local _binding = input
	local width = _binding.width
	local height = _binding.height
	local compact = _binding.compact
	local tight = _binding.tight
	local short = _binding.short
	local _condition = input.orientationWidth
	if _condition == nil then
		_condition = width
	end
	local orientationWidth = _condition
	local _condition_1 = input.orientationHeight
	if _condition_1 == nil then
		_condition_1 = height
	end
	local orientationHeight = _condition_1
	local _condition_2 = input.desktop
	if _condition_2 == nil then
		_condition_2 = false
	end
	local desktop = _condition_2
	local _condition_3 = input.bottomInset
	if _condition_3 == nil then
		_condition_3 = 0
	end
	local bottomInset = math.max(0, _condition_3)
	local _condition_4 = input.sideInset
	if _condition_4 == nil then
		_condition_4 = 0
	end
	local sideInset = _condition_4
	local narrow = orientationWidth < 840 or orientationHeight < 500
	local mobile = narrow or (not desktop and (compact or tight or short))
	local stack = narrow or (not desktop and (tight or (compact and short) or (compact and orientationHeight <= orientationWidth * 1.05 and orientationWidth < 980)))
	local physicallyShortSurface = not desktop and stack and orientationHeight < 420
	local landscape = not desktop and (isMobileLandscape(orientationWidth, orientationHeight, compact, tight) or physicallyShortSurface)
	local portrait = stack and not landscape
	local phone = stack
	local tablet = phone and width >= 700 and not landscape
	-- Header shrinks in landscape (vertical room is scarce) and grows slightly on tablets
	-- (more breathing room, still touch-first). PC gets a taller topbar so controls stay scannable.
	local topbarRows = if not phone then 74 elseif landscape then 36 elseif tablet then 52 else 48
	local bottomSafe = if landscape then math.max(10, bottomInset) elseif phone then math.max(bottomInset, 6) else math.max(8, bottomInset)
	local sideSafe = if landscape then math.max(sideInset, 16) elseif phone then math.max(sideInset, 12) else 0
	-- Phone keeps touch-first insets; desktop gets breathing room so sections separate clearly.
	local panelGap = if landscape then 8 elseif phone then 12 else 14
	local pagePadding = if landscape then 10 elseif phone then (if tablet then 16 else 14) elseif compact then 16 else 18
	local contentInset = if landscape then 10 elseif phone then (if tablet then 16 else 14) elseif compact then 16 else 18
	-- MobileShell already renders MobileHeader with the page title/chips. A second Workspace
	-- header on phone duplicates chrome and eats the content budget — keep it at 0 whenever
	-- the bottom-tab phone shell is active. Desktop keeps a readable workspace header.
	local workspaceHeaderH = if phone then 0 else 86
	-- Bottom tab bar: fixed-height strip. Core height is always ≥ TAP_TARGET so each tab
	-- remains thumbable; landscape stays at the floor, tablet gets a little more room.
	-- Height never animates, so it cannot render mid-transition.
	local tabBarCore = if landscape then TAP_TARGET elseif tablet then 56 else 52
	local tabBarH = if phone then tabBarCore + bottomSafe else 0
	-- How many destinations fit across the bar before a "More" tab is needed to hold the rest.
	-- A tab needs roughly 64px of comfortable tap width; reserve one slot for "More" whenever
	-- there's more content than fits.
	local tabBarSlots = if phone then math.max(3, math.min(6, math.floor((width - sideSafe * 2) / 64))) else 0
	-- "More" sheet grid (opened from the tab bar's overflow tab) reuses the old dock-height
	-- math since it's still a grid of buttons, just presented as a bottom sheet instead of a
	-- floating draggable dock.
	local moreCols = if landscape then 5 else 4
	local moreCellH = if landscape then 50 elseif tablet then 58 else 54
	local moreDockH = if phone then moreDockHeight(true, 8, moreCols, moreCellH, if landscape then 6 else 8) else 0
	local quickBarH = 0
	local chromeReserve = topbarRows + (if phone then tabBarH + panelGap else 20) + workspaceHeaderH
	-- A hard 208px floor overflowed short landscape screens: chrome + content
	-- could exceed the actual safe height before the page even mounted.
	local contentBudget = math.max(1, height - chromeReserve - 4)
	return {
		mobile = mobile,
		stack = stack,
		contentStack = stack,
		landscape = landscape,
		portrait = portrait,
		tablet = tablet,
		pagePadding = pagePadding,
		contentInset = contentInset,
		cardPadding = if landscape then 12 elseif phone then (if tablet then 16 else 14) else 18,
		panelGap = panelGap,
		controlGap = if landscape then 8 elseif phone then 10 else 14,
		-- Desktop sidebar rows are taller so labels stay readable; phone stays thumb-sized.
		railRow = if landscape then 52 elseif phone then 60 elseif compact then 60 else 64,
		railCollapsedRow = if landscape then 48 elseif phone then 54 elseif compact then 54 else 56,
		railGap = if phone then 8 elseif compact then 10 else 12,
		bodyText = if landscape then 13 elseif phone then 14 else 14,
		labelText = if landscape then 11 elseif phone then 13 else 12,
		titleText = if landscape then 16 elseif phone then (if tablet then 20 else 18) else 26,
		bottomSafe = bottomSafe,
		sideSafe = sideSafe,
		topbarRows = topbarRows,
		moreCols = moreCols,
		moreCellH = moreCellH,
		moreDockH = moreDockH,
		workspaceHeaderH = workspaceHeaderH,
		quickBarH = quickBarH,
		contentBudget = contentBudget,
		tabBarH = tabBarH,
		tabBarSlots = tabBarSlots,
	}
end
local EDIT_BOUNDS = Color3.fromRGB(72, 190, 255)
return {
	isMobileLandscape = isMobileLandscape,
	fitPanelHeight = fitPanelHeight,
	moreDockHeight = moreDockHeight,
	fitTouchGridWidth = fitTouchGridWidth,
	scrollTail = scrollTail,
	planMobileLayout = planMobileLayout,
	EDIT_BOUNDS = EDIT_BOUNDS,
}
