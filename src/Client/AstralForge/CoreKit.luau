--!nonstrict
--[=[
	CoreKit: merged module suite.
	Members (25): log, theme, mobileLayout, format, session, types, noticeMath, deadlines, boostIconKind, releaseClockMath, vaultCollectEligibility, inputPlatform, networkPolicy, actionCopy, pageBoardHeights, taskFilter, snapshotEnvelopeMath, inventoryMath, adminFields, clientStore, interaction, navRouteTable, appNav, GamepadNavigationService, TouchGestureService.

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
	if def == nil then error("CoreKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("CoreKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: log   (merged from log.luau, 209 lines)
-- ======================================================================
__defs["log"] = function()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local recent = {}
local recentCount = 0
local emitted = {}
local bootMilliseconds = 0
local bootOrigin = os.clock()
-- One line per event, same shape on client and server:
--   "  12.480  info   boot        runtime started  elapsed=31ms"
-- seconds since this script context started, a fixed-width level, a lowercase scope
-- column, the message, then key=value pairs (sorted; *Ms keys print as durations).
local LEVEL_COLUMN = { INFO = "info ", WARN = "warn ", ERROR = "error", FATAL = "fatal", NETWORK = "net  " }
local SCOPE_COLUMN_WIDTH = 12
local startedAt = os.clock()
local function field(value)
	local sanitized = tostring(value):gsub("[\r\n]+", " ")
	return sanitized
end
local function formatValue(value)
	local kind = typeof(value)
	if kind == "number" then
		if value ~= value then
			return "nan"
		end
		if value == math.huge or value == -math.huge then
			return if value > 0 then "inf" else "-inf"
		end
		if value == math.floor(value) and math.abs(value) < 1e15 then
			return string.format("%d", value)
		end
		return string.format("%.3g", value)
	end
	if kind == "boolean" then
		return tostring(value)
	end
	local text = field(value)
	if text == "" or string.find(text, "[%s=\"]") then
		return '"' .. string.gsub(text, '"', "'") .. '"'
	end
	return text
end
local function formatPair(key, value)
	local name = field(key)
	name = string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)
	if typeof(value) == "number" and string.sub(name, -2) == "Ms" and #name > 2 then
		return string.sub(name, 1, -3) .. "=" .. formatValue(value) .. "ms"
	end
	return name .. "=" .. formatValue(value)
end
local function formatLine(severity, scope, message, params)
	local pairsText = ""
	if params ~= nil and type(params) == "table" then
		local keys = {}
		for key in params do
			table.insert(keys, key)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		local pieces = table.create(#keys)
		for _, key in keys do
			table.insert(pieces, formatPair(key, params[key]))
		end
		if #pieces > 0 then
			pairsText = "  " .. table.concat(pieces, " ")
		end
	end
	local scopeText = string.lower(field(scope))
	if #scopeText < SCOPE_COLUMN_WIDTH then
		scopeText ..= string.rep(" ", SCOPE_COLUMN_WIDTH - #scopeText)
	end
	return string.format("%8.3f  %s  %s  %s%s", os.clock() - startedAt, LEVEL_COLUMN[severity] or string.lower(severity), scopeText, field(message), pairsText)
end
local function available(key, seconds)
	local now = os.clock()
	local _key = key
	local previous = recent[_key]
	if previous ~= nil and now - previous < seconds then
		return false
	end
	-- Keys can embed instance paths, so the table would otherwise only ever grow.
	if previous == nil then
		recentCount += 1
		if recentCount > 512 then
			table.clear(recent)
			recentCount = 1
		end
	end
	recent[key] = now
	return true
end
local function debugEnabled()
	return ReplicatedStorage:GetAttribute("AstralDebugLogs") == true
end
local ClientLog = {
	info = function(self, scope, message, params)
		print(formatLine("INFO", scope, message, params))
	end,
	warn = function(self, scope, message, params)
		warn(formatLine("WARN", scope, message, params))
	end,
	error = function(self, scope, message, params)
		warn(formatLine("ERROR", scope, message, params))
	end,
	fatal = function(self, scope, message, params)
		warn(formatLine("FATAL", scope, message, params))
	end,
	network = function(self, scope, message, params)
		print(formatLine("NETWORK", scope, message, params))
	end,
	debug = function(self, scope, message, params)
		if debugEnabled() then
			print(formatLine("INFO", scope, message, params))
		end
	end,
	once = function(self, key, scope, message, params)
		local _key = key
		if emitted[_key] ~= nil then
			return nil
		end
		local _key_1 = key
		emitted[_key_1] = true
		print(formatLine("INFO", scope, message, params))
	end,
	warnEvery = function(self, key, seconds, scope, message, params)
		if available(`warn:{key}`, seconds) then
			warn(formatLine("WARN", scope, message, params))
		end
	end,
	errorEvery = function(self, key, seconds, scope, message, params)
		if available(`err:{key}`, seconds) then
			warn(formatLine("ERROR", scope, message, params))
		end
	end,
}
local sharedQualitySample
local function beginClientSession()
	table.clear(recent)
	table.clear(emitted)
	bootMilliseconds = 0
	bootOrigin = os.clock()
	sharedQualitySample = nil
end
local function recordPerformanceTelemetry(sample)
	sharedQualitySample = sample
end
local function markBootComplete()
	if bootMilliseconds <= 0 then
		bootMilliseconds = math.floor((os.clock() - bootOrigin) * 1000 + 0.5)
	end
end
local function inputFamily()
	local preferred = UserInputService.PreferredInput
	if preferred == Enum.PreferredInput.Touch then
		return "touch"
	end
	if preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
		return "gamepad"
	end
	return "mouse"
end
local function startPerformanceTelemetry(request)
	local alive = true
	local reportInFlight = false
	local reportSerial = 0
	local requestWorker
	local requestTimeout
	local worker = task.spawn(function()
		task.wait(20)
		while alive do
			local sample = sharedQualitySample
			if sample ~= nil and sample.sampledAt > 0 then
				local _result = Workspace.CurrentCamera
				if _result ~= nil then
					_result = _result.ViewportSize
				end
				local _condition = _result
				if _condition == nil then
					_condition = Vector2.new(1, 1)
				end
				local viewport = _condition
				local _object = {
					FPS = math.clamp(sample.fps, 0, 360),
					P95Ms = math.clamp(sample.p95FrameTimeMs, 0, 1000),
					JankPct = math.clamp(sample.jankRatio, 0, 1),
				}
				local _left = "PingMs"
				local _condition_1 = sample.pingMs
				if _condition_1 == nil then
					_condition_1 = 0
				end
				_object[_left] = math.clamp(_condition_1, 0, 10000)
				_object.Width = math.max(1, math.floor(viewport.X))
				_object.Height = math.max(1, math.floor(viewport.Y))
				_object.BootMs = bootMilliseconds
				_object.Input = inputFamily()
				local payload = _object
				if not reportInFlight then
					reportInFlight = true
					local serial = reportSerial + 1
					reportSerial = serial
					requestWorker = task.defer(function()
						pcall(function()
							return request:InvokeServer("ReportPerformance", payload)
						end)
						if not alive or serial ~= reportSerial then
							return nil
						end
						requestWorker = nil
						if requestTimeout ~= nil then
							task.cancel(requestTimeout)
							requestTimeout = nil
						end
						reportInFlight = false
					end)
					requestTimeout = task.delay(6, function()
						requestTimeout = nil
						if not alive or serial ~= reportSerial or not reportInFlight then
							return nil
						end
						if requestWorker ~= nil then
							task.cancel(requestWorker)
						end
						requestWorker = nil
						reportSerial += 1
						reportInFlight = false
					end)
				end
			end
			task.wait(60)
		end
	end)
	return function()
		alive = false
		reportSerial += 1
		task.cancel(worker)
		if requestWorker ~= nil then
			task.cancel(requestWorker)
		end
		if requestTimeout ~= nil then
			task.cancel(requestTimeout)
		end
		requestWorker = nil
		requestTimeout = nil
		sharedQualitySample = nil
	end
end
return {
	beginClientSession = beginClientSession,
	recordPerformanceTelemetry = recordPerformanceTelemetry,
	markBootComplete = markBootComplete,
	startPerformanceTelemetry = startPerformanceTelemetry,
	ClientLog = ClientLog,
}
end

-- ======================================================================
-- Module: theme   (merged from theme.luau, 323 lines)
-- ======================================================================
__defs["theme"] = function()
local exports = {}
local planMobileLayout = __load("mobileLayout").planMobileLayout
local _mobileLayout = __load("mobileLayout")
exports.fitPanelHeight = _mobileLayout.fitPanelHeight
exports.fitTouchGridWidth = _mobileLayout.fitTouchGridWidth
exports.isMobileLandscape = _mobileLayout.isMobileLandscape
exports.moreDockHeight = _mobileLayout.moreDockHeight
exports.planMobileLayout = _mobileLayout.planMobileLayout
exports.scrollTail = _mobileLayout.scrollTail
-- Astral Forge "molten forge" chroma: warm charcoal-plum surfaces with brass and
-- ember heat, cut by cool cyan/mint signal colours. The surfaces are warm so
-- accents (CTAs, tabs, meters, active chrome) glow against them instead of
-- sitting on a cold blue wash; semantic colours (success, danger) stay readable.
local Palette = {
	void = Color3.fromRGB(8, 6, 10),
	ink = Color3.fromRGB(12, 9, 14),
	night = Color3.fromRGB(19, 14, 20),
	panel = Color3.fromRGB(27, 21, 29),
	panelRaised = Color3.fromRGB(39, 31, 42),
	panelSoft = Color3.fromRGB(62, 49, 66),
	line = Color3.fromRGB(74, 58, 80),
	lineSoft = Color3.fromRGB(132, 110, 142),
	cream = Color3.fromRGB(252, 247, 240),
	creamSoft = Color3.fromRGB(230, 220, 212),
	muted = Color3.fromRGB(178, 160, 166),
	cyan = Color3.fromRGB(70, 218, 242),
	mint = Color3.fromRGB(86, 236, 178),
	coral = Color3.fromRGB(255, 104, 112),
	mango = Color3.fromRGB(255, 184, 52),
	violet = Color3.fromRGB(178, 134, 255),
	pink = Color3.fromRGB(250, 104, 178),
	blue = Color3.fromRGB(96, 166, 255),
	white = Color3.fromRGB(255, 255, 255),
	green = Color3.fromRGB(98, 232, 164),
	red = Color3.fromRGB(240, 78, 88),
	shadow = Color3.fromRGB(0, 0, 0),
	graphite = Color3.fromRGB(22, 17, 25),
	steel = Color3.fromRGB(204, 214, 234),
	steelBright = Color3.fromRGB(252, 247, 240),
	brass = Color3.fromRGB(250, 190, 72),
	brassDeep = Color3.fromRGB(140, 92, 30),
	ember = Color3.fromRGB(244, 92, 84),
}
local ACCESSIBLE_BASE = {
	void = Palette.void,
	ink = Palette.ink,
	night = Palette.night,
	panel = Palette.panel,
	panelRaised = Palette.panelRaised,
	panelSoft = Palette.panelSoft,
	line = Palette.line,
	lineSoft = Palette.lineSoft,
	cream = Palette.cream,
	creamSoft = Palette.creamSoft,
	muted = Palette.muted,
	cyan = Palette.cyan,
	mint = Palette.mint,
	coral = Palette.coral,
	mango = Palette.mango,
	violet = Palette.violet,
	pink = Palette.pink,
	blue = Palette.blue,
	green = Palette.green,
	red = Palette.red,
}
local accessibilitySignature = ""
local function applyAccessibilityTheme(highContrast, colorblind)
	local signature = `{highContrast}:{colorblind}`
	if signature == accessibilitySignature then
		return nil
	end
	accessibilitySignature = signature
	local mutable = Palette
	for key, value in pairs(ACCESSIBLE_BASE) do
		mutable[key] = value
	end
	if colorblind then
		mutable.green = Color3.fromRGB(86, 180, 233)
		mutable.mint = Color3.fromRGB(86, 180, 233)
		mutable.red = Color3.fromRGB(230, 159, 0)
		mutable.coral = Color3.fromRGB(230, 159, 0)
		mutable.pink = Color3.fromRGB(204, 121, 167)
		mutable.violet = Color3.fromRGB(0, 158, 115)
	end
	if highContrast then
		mutable.void = Color3.fromRGB(0, 0, 0)
		mutable.ink = Color3.fromRGB(3, 2, 3)
		mutable.night = Color3.fromRGB(8, 6, 8)
		mutable.panel = Color3.fromRGB(13, 10, 14)
		mutable.panelRaised = Color3.fromRGB(21, 16, 23)
		mutable.panelSoft = Color3.fromRGB(36, 28, 40)
		mutable.lineSoft = Color3.fromRGB(160, 142, 168)
		mutable.cream = Color3.fromRGB(255, 255, 255)
		mutable.creamSoft = Color3.fromRGB(235, 240, 246)
		mutable.muted = Color3.fromRGB(190, 199, 210)
	end
end
local Layout = {
	-- Desktop breathing room: denser "too clean" chrome made sections hard to scan.
	pagePadding = 18,
	topbarClearance = 6,
	minTopInset = 36,
	panelGap = 14,
	stackGap = 12,
	controlGap = 14,
	lineGap = 10,
	cardPadding = 18,
	cardRadius = 16,
	buttonRadius = 11,
	topbarHeight = 74,
	sidebarWidth = 268,
	sidebarCollapsedWidth = 78,
	rightRailWidth = 296,
	contentMinWidth = 620,
	contentInset = 18,
	workspaceHeaderHeight = 86,
	-- Soft cap for readable page columns on ultrawide; shell still spans the monitor.
	contentMaxWidth = 1680,
	maxShellWidth = 3440,
	referenceWidth = 1920,
	referenceHeight = 1080,
	minScale = 0.75,
	maxScale = 1,
	chromeScale = 1,
}
-- Shared chrome opacities — lower = more visible strokes/shadows/accents.
local Chrome = {
	panelShadow = 0.7,
	panelStrokeIdle = 0.3,
	panelStrokeHover = 0.05,
	buttonShadow = 0.58,
	railStrokeIdle = 0.42,
	railStrokeActive = 0.08,
	accentHairline = 0.02,
	meterTrack = 0.16,
}
local Breakpoints = {
	tight = 840,
	compact = 1100,
	short = 740,
}
local TapTarget = 48
local function mobileChrome(compact, tight, short, width, height, bottomInset, sideInset, desktop, orientationWidth, orientationHeight)
	if short == nil then
		short = false
	end
	if width == nil then
		width = 1280
	end
	if height == nil then
		height = 720
	end
	if bottomInset == nil then
		bottomInset = 0
	end
	if sideInset == nil then
		sideInset = 0
	end
	if desktop == nil then
		desktop = false
	end
	if orientationWidth == nil then
		orientationWidth = width
	end
	if orientationHeight == nil then
		orientationHeight = height
	end
	local plan = planMobileLayout({
		width = width,
		height = height,
		compact = compact,
		tight = tight,
		short = short,
		bottomInset = bottomInset,
		sideInset = sideInset,
		desktop = desktop,
		orientationWidth = orientationWidth,
		orientationHeight = orientationHeight,
	})
	return {
		mobile = plan.mobile,
		stack = plan.stack,
		contentStack = plan.contentStack,
		landscape = plan.landscape,
		portrait = plan.portrait,
		tablet = plan.tablet,
		compact = compact,
		tight = tight,
		short = short,
		pagePadding = plan.pagePadding,
		contentInset = plan.contentInset,
		cardPadding = plan.cardPadding,
		panelGap = plan.panelGap,
		controlGap = plan.controlGap,
		railRow = plan.railRow,
		railCollapsedRow = plan.railCollapsedRow,
		railGap = plan.railGap,
		bodyText = plan.bodyText,
		labelText = plan.labelText,
		titleText = plan.titleText,
		bottomSafe = plan.bottomSafe,
		sideSafe = plan.sideSafe,
		topbarRows = plan.topbarRows,
		moreCols = plan.moreCols,
		moreCellH = plan.moreCellH,
		moreDockH = plan.moreDockH,
		workspaceHeaderH = plan.workspaceHeaderH,
		quickBarH = plan.quickBarH,
		contentBudget = plan.contentBudget,
		tabBarH = plan.tabBarH,
		tabBarSlots = plan.tabBarSlots,
	}
end
local function chromeFor(viewport)
	local _exp = viewport.compact
	local _exp_1 = viewport.tight
	local _exp_2 = viewport.short
	local _exp_3 = viewport.width
	local _exp_4 = viewport.height
	local _condition = viewport.bottomInset
	if _condition == nil then
		_condition = 0
	end
	local _condition_1 = viewport.sideInset
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local _condition_2 = viewport.desktop
	if _condition_2 == nil then
		_condition_2 = false
	end
	local _condition_3 = viewport.screenWidth
	if _condition_3 == nil then
		_condition_3 = viewport.width
	end
	local _condition_4 = viewport.screenHeight
	if _condition_4 == nil then
		_condition_4 = viewport.height
	end
	local chrome = mobileChrome(_exp, _exp_1, _exp_2, _exp_3, _exp_4, _condition, _condition_1, _condition_2, _condition_3, _condition_4)
	chrome.tenFoot = viewport.tenFoot == true
	return chrome
end
local function lighten(color, amount)
	return color:Lerp(Palette.white, math.clamp(amount, 0, 1))
end
local function darken(color, amount)
	return color:Lerp(Palette.shadow, math.clamp(amount, 0, 1))
end
local function linearChannel(channel)
	return if channel <= 0.04045 then channel / 12.92 else math.pow((channel + 0.055) / 1.055, 2.4)
end
local function relativeLuminance(color)
	return linearChannel(color.R) * 0.2126 + linearChannel(color.G) * 0.7152 + linearChannel(color.B) * 0.0722
end
local function contrastRatio(first, second)
	local a = relativeLuminance(first)
	local b = relativeLuminance(second)
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end
local function contrastOn(background)
	if relativeLuminance(background) < 0.45 then
		return Palette.cream
	end
	return if contrastRatio(background, Palette.ink) >= contrastRatio(background, Palette.cream) then Palette.ink else Palette.cream
end
local function ensureContrast(background, preferred, minimum)
	if minimum == nil then
		minimum = 4.5
	end
	if contrastRatio(background, preferred) >= minimum then
		return preferred
	end
	if relativeLuminance(background) < 0.45 then
		local lifted = preferred:Lerp(Palette.cream, 0.62)
		if contrastRatio(background, lifted) >= minimum then
			return lifted
		end
		return Palette.cream
	end
	local sunk = preferred:Lerp(Palette.ink, 0.62)
	if contrastRatio(background, sunk) >= minimum then
		return sunk
	end
	return contrastOn(background)
end
local function surfaceGradient(base, strength)
	if strength == nil then
		strength = 1
	end
	-- Layered forge glass: a warm lift at the top edge, then a deeper sink into the dark.
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, lighten(base, 0.15 * strength)),
		ColorSequenceKeypoint.new(0.12, lighten(base, 0.05 * strength)),
		ColorSequenceKeypoint.new(0.55, base),
		ColorSequenceKeypoint.new(1, darken(base, 0.27 * strength)),
	})
end
local function strokeGradient(color)
	-- Directional edge: the top of a stroke reads brighter than the bottom.
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, lighten(color, 0.58)),
		ColorSequenceKeypoint.new(0.42, color),
		ColorSequenceKeypoint.new(1, darken(color, 0.62)),
	})
end
exports.applyAccessibilityTheme = applyAccessibilityTheme
exports.mobileChrome = mobileChrome
exports.chromeFor = chromeFor
exports.lighten = lighten
exports.darken = darken
exports.relativeLuminance = relativeLuminance
exports.contrastRatio = contrastRatio
exports.contrastOn = contrastOn
exports.ensureContrast = ensureContrast
exports.surfaceGradient = surfaceGradient
exports.strokeGradient = strokeGradient
exports.Palette = Palette
exports.Layout = Layout
exports.Chrome = Chrome
exports.Breakpoints = Breakpoints
exports.TapTarget = TapTarget
return exports
end

-- ======================================================================
-- Module: mobileLayout   (merged from mobileLayout.luau, 230 lines)
-- ======================================================================
__defs["mobileLayout"] = function()
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
--   - "desktop"  full sidebar shell; short windows use a denser top bar and workspace header
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
	-- Extra clearance past bottomSafe so last-row CTAs clear the tab bar, home
	-- indicator, and Workshop floating quick-action cluster without dead zones.
	return base + math.max(bottomSafe, 12) + 28
end
local planCache = nil
local planKey = {
	width = false,
	height = false,
	compact = false,
	tight = false,
	short = false,
	desktop = false,
	orientationWidth = false,
	orientationHeight = false,
	bottomInset = false,
	sideInset = false,
}
local function quantize(value)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(value + 0.5)
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
	width = quantize(width)
	height = quantize(height)
	orientationWidth = quantize(orientationWidth)
	orientationHeight = quantize(orientationHeight)
	bottomInset = quantize(bottomInset)
	sideInset = quantize(sideInset)
	compact = compact == true
	tight = tight == true
	short = short == true
	desktop = desktop == true
	if planCache ~= nil and planKey.width == width and planKey.height == height and planKey.compact == compact and planKey.tight == tight and planKey.short == short and planKey.desktop == desktop and planKey.orientationWidth == orientationWidth and planKey.orientationHeight == orientationHeight and planKey.bottomInset == bottomInset and planKey.sideInset == sideInset then
		return planCache
	end
	local narrow = orientationWidth < 840 or orientationHeight < 500
	local mobile = narrow or (not desktop and (compact or tight or short))
	local stack = narrow or (not desktop and (tight or (compact and short) or (compact and orientationHeight <= orientationWidth * 1.05 and orientationWidth < 980)))
	local physicallyShortSurface = not desktop and stack and orientationHeight < 420
	local landscape = not desktop and (isMobileLandscape(orientationWidth, orientationHeight, compact, tight) or physicallyShortSurface)
	local portrait = stack and not landscape
	local phone = stack
	local tablet = phone and width >= 700 and not landscape
	-- Header shrinks in landscape (vertical room is scarce) and grows slightly on tablets
	-- (more breathing room, still touch-first). Short desktop windows (Studio, laptops)
	-- use a denser top bar so page content is not pushed under the fold.
	local shortDesktop = desktop and (short or orientationHeight < 740)
	local topbarRows = if not phone then (if shortDesktop then 56 else 74) elseif landscape then 34 elseif tablet then 52 else 46
	local bottomSafe = if landscape then math.max(10, bottomInset) elseif phone then math.max(bottomInset, 6) else math.max(8, bottomInset)
	-- Tablet and desktop tiers still honour a reported side inset (a notched
	-- tablet in landscape, a TV overscan margin); it is zero when the ScreenGui
	-- has already consumed the safe area.
	local sideSafe = if landscape then math.max(sideInset, 16) elseif phone then math.max(sideInset, 12) else math.max(0, sideInset)
	-- Phone keeps touch-first insets; desktop gets breathing room so sections separate clearly.
	local panelGap = if landscape then 8 elseif phone then 12 elseif shortDesktop then 10 else 14
	local pagePadding = if landscape then 8 elseif phone then (if tablet then 16 else 12) elseif shortDesktop or compact then 14 else 18
	local contentInset = if landscape then 8 elseif phone then (if tablet then 16 else 12) elseif shortDesktop or compact then 14 else 18
	-- MobileShell already renders MobileHeader with the page title/chips. A second Workspace
	-- header on phone duplicates chrome and eats the content budget — keep it at 0 whenever
	-- the bottom-tab phone shell is active. Desktop keeps a readable workspace header.
	local workspaceHeaderH = if phone then 0 elseif shortDesktop then 62 else 86
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
	planKey.width = width
	planKey.height = height
	planKey.compact = compact
	planKey.tight = tight
	planKey.short = short
	planKey.desktop = desktop
	planKey.orientationWidth = orientationWidth
	planKey.orientationHeight = orientationHeight
	planKey.bottomInset = bottomInset
	planKey.sideInset = sideInset
	planCache = {
		mobile = mobile,
		stack = stack,
		contentStack = stack,
		landscape = landscape,
		portrait = portrait,
		tablet = tablet,
		pagePadding = pagePadding,
		contentInset = contentInset,
		cardPadding = if landscape then 12 elseif phone then (if tablet then 16 else 14) elseif shortDesktop then 14 else 18,
		panelGap = panelGap,
		controlGap = if landscape then 8 elseif phone then 10 else 14,
		-- Desktop sidebar rows are taller so labels stay readable; phone stays thumb-sized.
		railRow = if landscape then 52 elseif phone then 60 elseif shortDesktop or compact then 52 else 64,
		railCollapsedRow = if landscape then 48 elseif phone then 54 elseif shortDesktop or compact then 48 else 56,
		railGap = if phone then 8 elseif compact then 10 else 12,
		bodyText = if landscape then 14 elseif phone then 15 else 16,
		labelText = if landscape then 12 elseif phone then 13 else 14,
		titleText = if landscape then 17 elseif phone then (if tablet then 20 else 18) elseif shortDesktop then 24 else 26,
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
	return planCache
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
end

-- ======================================================================
-- Module: format   (merged from format.luau, 400 lines)
-- ======================================================================
__defs["format"] = function()
local LN10 = math.log(10)
local compactNumber
local function formatReward(reward)
	if not reward then
		return ""
	end
	local parts = {}
	if reward.Cash ~= nil and reward.Cash > 0 then
		local _arg0 = `{compactNumber(reward.Cash)} flux`
		table.insert(parts, _arg0)
	end
	if reward.CashMinutes ~= nil and reward.CashMinutes > 0 then
		local _arg0 = `{compactNumber(reward.CashMinutes)} min of flux`
		table.insert(parts, _arg0)
	end
	if reward.Stardust ~= nil and reward.Stardust > 0 then
		local _arg0 = `{compactNumber(reward.Stardust)} stardust`
		table.insert(parts, _arg0)
	end
	if reward.Cores ~= nil and reward.Cores > 0 then
		local _arg0 = `{compactNumber(reward.Cores)} cores`
		table.insert(parts, _arg0)
	end
	if reward.Signals ~= nil and reward.Signals > 0 then
		local _arg0 = `{compactNumber(reward.Signals)} signals`
		table.insert(parts, _arg0)
	end
	if reward.CommandXP ~= nil and reward.CommandXP > 0 then
		local _arg0 = `{compactNumber(reward.CommandXP)} command XP`
		table.insert(parts, _arg0)
	end
	if reward.StreakShield ~= nil and reward.StreakShield > 0 then
		local _arg0 = `{reward.StreakShield} streak shield`
		table.insert(parts, _arg0)
	end
	local essenceAmount = 0
	if reward.Essence ~= nil and reward.Essence > 0 then
		essenceAmount += reward.Essence
	end
	if reward.DomainEssence ~= nil and reward.DomainEssence > 0 then
		essenceAmount += reward.DomainEssence
	end
	if essenceAmount > 0 then
		table.insert(parts, `{compactNumber(essenceAmount)} domain essence`)
	end
	if reward.Fragments ~= nil and reward.Fragments > 0 then
		table.insert(parts, `{compactNumber(reward.Fragments)} fragments`)
	end
	if reward.FreeSpins ~= nil and reward.FreeSpins > 0 then
		local spinLabel = if reward.FreeSpins == 1 then "free spin" else "free spins"
		table.insert(parts, `{compactNumber(reward.FreeSpins)} {spinLabel}`)
	end
	if type(reward.Keys) == "table" then
		for crateId, amount in reward.Keys do
			if type(crateId) == "string" and type(amount) == "number" and amount > 0 then
				table.insert(parts, `{compactNumber(amount)} {crateId}`)
			end
		end
	end
	if reward.Boost ~= nil then
		local _boost = reward.Boost
		table.insert(parts, _boost)
	end
	if #parts == 0 then
		return ""
	end
	local text = "+" .. parts[1]
	for index = 1, #parts - 1 do
		text ..= `, +{parts[index + 1]}`
	end
	return text
end
local NUMBER_SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "UVg", "DVg", "TVg", "QaVg", "QiVg", "SxVg", "SpVg", "OcVg", "NoVg", "Tg", "UTg", "DTg", "TTg", "QaTg", "QiTg", "SxTg", "SpTg", "OcTg", "Millinillion", "Googol", "Googolchime", "DuoGoogol", "Googolthrong", "Googolchoir", "Googolwell", "Googolcascade", "Googolspire", "Googolmarch", "Googolreign", "Googolcourt", "Googolhost", "Googolvast", "Googoldeep", "Googolpeak", "Googolcrown", "Googolheart", "Googolwake", "Googolzenith", "Googolapex", "Megaminx", "Gigaminx", "Teraminx", "Petaminx", "Examinx", "Zettaminx", "Yottaminx", "Ronnaminx", "Quettaminx", "Ultraminx", "Hyperminx", "Omniminx", "Alphaminx", "Omegaminx", "Prismaminx", "Stellaminx", "Voidminx", "Astraminx", "Infiminx", "Transminx", "Skewes", "Moser", "Graham", "TREE", "SSCG", "Loader", "Rayo", "BusyBeaver", "Xi", "Omega", "Inaccessible", "Mahlo", "Supercompact", "Huge", "RankIntoRank", "Berkeley", "Reinhardt", "Absolute", "Finality", "Boundless", "Apex", "Horizon", "Zenith", "Nadir", "Helix", "Quasar", "Pulsar", "Nebula", "Singularity", "Eventide", "Eon", "Aeon", "Continuum", "Lattice", "Axiom", "Paragon", "Astral", "Forgepeak" }
local function suffixForGroup(group)
	if group <= 0 then
		return ""
	end
	local index = math.min(group, #NUMBER_SUFFIXES) - 1
	return NUMBER_SUFFIXES[index + 1]
end
local LAST_NAMED_LOG10 = #NUMBER_SUFFIXES * 3
-- Three significant figures are shown, so 999.996 prints as "1000". Values that round up to a
-- full thousand must move to the next suffix instead ("1.00M", never "1000K").
local function roundsToThousand(absolute)
	local decimals = if absolute >= 100 then 0 elseif absolute >= 10 then 1 else 2
	return (tonumber(string.format("%." .. decimals .. "f", absolute)) or 0) >= 1000
end
local function formatFromLog10(log10, sign)
	if sign == nil then
		sign = 1
	end
	if log10 ~= log10 or log10 == -math.huge then
		return "0"
	end
	if log10 < 3 then
		local numeric = sign * 10 ^ math.max(0, log10)
		if math.abs(numeric) < 999.5 then
			return string.format("%.0f", numeric)
		end
	end
	if log10 >= LAST_NAMED_LOG10 then
		local exponent = math.floor(log10)
		local mantissa = 10 ^ (log10 - exponent)
		return string.format("%s%.2fe%d", if sign < 0 then "-" else "", mantissa, exponent)
	end
	local group = math.clamp(math.floor(log10 / 3), 1, #NUMBER_SUFFIXES)
	local scaled = sign * 10 ^ (log10 - group * 3)
	if (math.abs(scaled) >= 1000 or roundsToThousand(math.abs(scaled))) and group < #NUMBER_SUFFIXES then
		group += 1
		scaled /= 1000
	end
	local suffix = suffixForGroup(group)
	local absolute = math.abs(scaled)
	if absolute >= 100 then
		return string.format("%.0f%s", scaled, suffix)
	end
	if absolute >= 10 then
		local text = string.format("%.1f", scaled)
		if math.abs(tonumber(text) or 0) >= 100 then
			text = string.format("%.0f", scaled)
		end
		return text .. suffix
	end
	local text = string.format("%.2f", scaled)
	if math.abs(tonumber(text) or 0) >= 10 then
		text = string.format("%.1f", scaled)
	end
	return text .. suffix
end
local function scaleForDisplay(value)
	local absolute = math.abs(value)
	if absolute ~= absolute or absolute == 0 then
		return {
			scaled = 0,
			suffix = "",
		}
	end
	if absolute == math.huge then
		return {
			scaled = 1,
			suffix = "e308+",
		}
	end
	if absolute < 1000 then
		return {
			scaled = value,
			suffix = "",
		}
	end
	local log10 = math.log10(absolute)
	if log10 >= LAST_NAMED_LOG10 then
		return {
			scaled = 10 ^ (log10 - math.floor(log10)),
			suffix = `e{math.floor(log10)}`,
		}
	end
	local group = math.clamp(math.floor(log10 / 3), 1, #NUMBER_SUFFIXES)
	local scaled = value / 1000 ^ group
	if (math.abs(scaled) >= 1000 or roundsToThousand(math.abs(scaled))) and group < #NUMBER_SUFFIXES then
		group += 1
		scaled /= 1000
	end
	return {
		scaled = scaled,
		suffix = suffixForGroup(group),
	}
end
local log10Flux
local function asFlux(value)
	local _value = value
	if type(_value) == "number" then
		return if value == value then value else 0
	end
	local parsed = tonumber(value)
	if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
		return parsed
	end
	local log = log10Flux(value)
	if log == -math.huge then
		return 0
	end
	if log >= 308 then
		return 1e308
	end
	if log <= -308 then
		return 0
	end
	return 10 ^ log
end
function log10Flux(value)
	local _value = value
	if type(_value) == "number" then
		if value ~= value or value == 0 then
			return -math.huge
		end
		if value < 0 then
			return -math.huge
		end
		if value == math.huge then
			return 1e6
		end
		return math.log10(value)
	end
	local parsed = tonumber(value)
	if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
		return log10Flux(parsed)
	end
	local mantissaText, exponentText = string.match(value, "([%+%-]?%d*%.?%d+)[eE]([%+%-]?%d+)")
	if mantissaText ~= nil and exponentText ~= nil then
		local _condition = tonumber(mantissaText)
		if _condition == nil then
			_condition = 1
		end
		local mantissa = _condition
		local _condition_1 = tonumber(exponentText)
		if _condition_1 == nil then
			_condition_1 = 0
		end
		local exponent = _condition_1
		if mantissa <= 0 then
			return -math.huge
		end
		return math.log(mantissa) / LN10 + exponent
	end
	if string.lower(value) == "inf" or string.lower(value) == "infinity" then
		return 1e6
	end
	return -math.huge
end
local function fromLog10(log10)
	if log10 ~= log10 or log10 == -math.huge then
		return 0
	end
	if log10 < 308 then
		local numeric = 10 ^ log10
		if numeric == numeric and numeric ~= math.huge then
			return numeric
		end
	end
	local exponent = math.floor(log10)
	local mantissa = 10 ^ (log10 - exponent)
	return string.format("%.12fe%d", mantissa, exponent)
end
local function compareFlux(left, right)
	local a = log10Flux(left)
	local b = log10Flux(right)
	if a < b then
		return -1
	end
	if a > b then
		return 1
	end
	return 0
end
local function gteFlux(left, right)
	return compareFlux(left, right) >= 0
end
local function levelCapLabel(maxLevel)
	if maxLevel >= 1000000000 then
		return "∞"
	end
	return compactNumber(maxLevel)
end
function compactNumber(value)
	local _value = value
	if type(_value) == "string" then
		local parsed = tonumber(value)
		if parsed ~= nil and parsed == parsed and parsed ~= math.huge and parsed ~= -math.huge then
			return compactNumber(parsed)
		end
		return formatFromLog10(log10Flux(value))
	end
	local _value_1 = value
	local _condition = not (type(_value_1) == "number")
	if not _condition then
		_condition = value ~= value
	end
	if _condition then
		return "0"
	end
	if value == 0 then
		return "0"
	end
	if math.abs(value) < 999.5 and value ~= math.huge and value ~= -math.huge then
		return string.format("%.0f", value)
	end
	return formatFromLog10(log10Flux(math.abs(value)), if value < 0 then -1 else 1)
end
local function compactSpinParts(value)
	local _value = value
	if type(_value) == "string" then
		local parsed = tonumber(value)
		if parsed ~= nil and parsed == parsed and parsed ~= math.huge then
			return compactSpinParts(parsed)
		end
		return {
			value = 1,
			suffix = compactNumber(value),
			decimals = 0,
		}
	end
	local _value_1 = value
	local _condition = not (type(_value_1) == "number")
	if not _condition then
		_condition = value ~= value
	end
	if _condition then
		return {
			value = 0,
			suffix = "",
			decimals = 0,
		}
	end
	local parts = scaleForDisplay(value)
	if parts.suffix == "" then
		return {
			value = math.floor(value + (if value >= 0 then 0.5 else -0.5)),
			suffix = "",
			decimals = 0,
		}
	end
	local decimals = if math.abs(parts.scaled) >= 100 then 0 elseif math.abs(parts.scaled) >= 10 then 1 else 2
	local factor = 10 ^ decimals
	local rounded = math.floor(parts.scaled * factor + (if parts.scaled >= 0 then 0.5 else -0.5)) / factor
	return {
		value = rounded,
		suffix = parts.suffix,
		decimals = decimals,
	}
end
local function clockText(seconds)
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor(total % 3600 / 60)
	local remaining = total % 60
	return if hours > 0 then string.format("%02d:%02d:%02d", hours, minutes, remaining) else string.format("%02d:%02d", minutes, remaining)
end
local function scaledCost(base, scale, level)
	local safeBase = math.max(1e-12, base)
	local safeScale = math.max(1e-12, scale)
	local exponent = math.log(safeBase) + math.max(0, level) * math.log(safeScale)
	if exponent < math.log(1e308) then
		return math.floor(math.exp(exponent) + 0.5)
	end
	return fromLog10(exponent / LN10)
end
local function geometricSum(base, scale, level, count)
	if count <= 0 then
		return 0
	end
	if count == 1 then
		return scaledCost(base, scale, level)
	end
	local safeBase = math.max(1e-12, base)
	local safeScale = math.max(1e-12, scale)
	if math.abs(safeScale - 1) < 1e-12 then
		local one = scaledCost(safeBase, safeScale, level)
		local logTotal = log10Flux(one) + math.log(count) / LN10
		return fromLog10(logTotal)
	end
	local lnScale = math.log(safeScale)
	local nLnScale = count * lnScale
	local logDiff = if nLnScale < math.log(1e300) then math.log(math.max(1e-12, safeScale ^ count - 1)) else nLnScale
	local logTotal = math.log(safeBase) + math.max(0, level) * lnScale + logDiff - math.log(math.max(1e-12, safeScale - 1))
	if logTotal < math.log(1e308) then
		return math.floor(math.exp(logTotal) + 0.5)
	end
	return fromLog10(logTotal / LN10)
end
local function maxAffordableLevels(base, scale, level, remaining, cash)
	if remaining <= 0 then
		return 0
	end
	if compareFlux(scaledCost(base, scale, level), cash) > 0 then
		return 0
	end
	local low = 1
	local high = remaining
	while low < high do
		local mid = low + math.floor((high - low + 1) / 2)
		if compareFlux(geometricSum(base, scale, level, mid), cash) <= 0 then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end
local function bulkCost(base, scale, level, amount, maxLevel, cash)
	local remaining = math.max(0, maxLevel - level)
	if amount == 0 then
		if cash == nil then
			return scaledCost(base, scale, level)
		end
		local count = maxAffordableLevels(base, scale, level, remaining, cash)
		return if count <= 0 then scaledCost(base, scale, level) else geometricSum(base, scale, level, count)
	end
	return geometricSum(base, scale, level, math.min(amount, remaining))
end
local function amountPayload(amount)
	return if amount == 0 then "Max" else amount
end
return {
	formatReward = formatReward,
	asFlux = asFlux,
	log10Flux = log10Flux,
	compareFlux = compareFlux,
	gteFlux = gteFlux,
	levelCapLabel = levelCapLabel,
	compactNumber = compactNumber,
	compactSpinParts = compactSpinParts,
	clockText = clockText,
	scaledCost = scaledCost,
	bulkCost = bulkCost,
	amountPayload = amountPayload,
}
end

-- ======================================================================
-- Module: session   (merged from session.luau, 287 lines)
-- ======================================================================
__defs["session"] = function()
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ClientLog = __load("log").ClientLog
local BEAT_INTERVAL_MIN = 8
local BEAT_INTERVAL_MAX = 12
-- Actions that mutate player-owned state and require an authenticated session (matching gen)
-- before the server will run them. Kept as its own set instead of leaning on the server's
-- internal read/write split so a hole here is visible in review rather than inherited silently.
local GRANT_ACTIONS = {
	["CollectVault"] = true,
	["Overcharge"] = true,
	["BuyMachine"] = true,
	["BuyResearch"] = true,
	["BuyGridUpgrade"] = true,
	["UnlockZone"] = true,
	["SelectZone"] = true,
	["Rebirth"] = true,
	["DomainExpansion"] = true,
	["UnlockDomainNode"] = true,
	["UpgradeContinuum"] = true,
	["CaptureEcho"] = true,
	["ClaimEcho"] = true,
	["EquipEcho"] = true,
	["UpgradeEcho"] = true,
	["DismantleEcho"] = true,
	["ClaimQuest"] = true,
	["ClaimAchievement"] = true,
	["ClaimDaily"] = true,
	["ClaimTimedReward"] = true,
	["SpinWheel"] = true,
	["CasinoPlay"] = true,
	["BazaarPlay"] = true,
	["LaunchExpedition"] = true,
	["ClaimExpedition"] = true,
	["EquipArtifact"] = true,
	["UpgradeArtifact"] = true,
	["UpgradeCrew"] = true,
	["ClaimCommanderReward"] = true,
	["ClaimWeeklyDirective"] = true,
	["ClaimSeasonTier"] = true,
	["ClaimForgePathStep"] = true,
	["BuySignalOffer"] = true,
	["RedeemCode"] = true,
	["VerifyCreatorFollow"] = true,
	["StudioGrantProduct"] = true,
	["ActivateBoost"] = true,
	["BuyItemOffer"] = true,
	["OpenItemCrate"] = true,
	["EquipItem"] = true,
	["UnequipItem"] = true,
	["UpgradeItem"] = true,
	["SalvageItem"] = true,
	["BulkSalvageItems"] = true,
	["EquipBestItems"] = true,
	["ClaimStoryChapter"] = true,
	["ClaimMail"] = true,
	["ClaimAllMail"] = true,
	["PulseAnomaly"] = true,
	["StabilizeAnomaly"] = true,
	["BuyAnomalyProtocol"] = true,
	["ActivateAnomalySurge"] = true,
	["ClaimAnomalyMilestone"] = true,
	["ClaimAnomalyDirective"] = true,
	["ClaimLabOrder"] = true,
	["RouteLabPower"] = true,
	["CreateGuild"] = true,
	["JoinGuild"] = true,
	["LeaveGuild"] = true,
	["DisbandGuild"] = true,
	["KickGuildMember"] = true,
	["SetGuildRole"] = true,
	["ContributeGuild"] = true,
	["BuyGuildUpgrade"] = true,
	["ClaimGuildGoal"] = true,
	["AdminExecute"] = true,
	["ClaimConvergenceReward"] = true,
	["ConfirmTrade"] = true,
	["UpdateTradeOffer"] = true,
	["InviteTrade"] = true,
	["RespondTrade"] = true,
	["SetTradeReady"] = true,
	["CancelTrade"] = true,
	["CompleteTutorial"] = true,
	["DeleteMail"] = true,
	["DismissRelease"] = true,
	["EquipTitle"] = true,
	["OpenRelease"] = true,
	["ReadMail"] = true,
	["ReadStoryChapter"] = true,
	["SetAnomalyChannel"] = true,
	["SetAnomalyLoadout"] = true,
	["SetAutoForge"] = true,
	["SetItemAutoSalvage"] = true,
	["SetMobileLayout"] = true,
	["SetSetting"] = true,
	["SyncShop"] = true,
	["ToggleItemLock"] = true,
}
local gen = 0
local nonce = ""
local auth = RunService:IsStudio()
local helloDone = false
local nextBeatId = 1
local stopped = true
local presencePage = "Overview"
local lastPresenceAt = -1e9
local authWaiters = {}
local PRESENCE_TIMEOUT_SECONDS = 5
local MAX_PRESENCE_IN_FLIGHT = 2
local presenceSerial = 0
local presenceInFlight = 0
local sessionToken = 0
local function setPresencePage(page)
	presencePage = page
end
local function flushAuthWaiters()
	if not auth then
		return nil
	end
	local queued = {}
	for _, waiter in authWaiters do
		table.insert(queued, waiter)
	end
	while #authWaiters > 0 do
		authWaiters[#authWaiters] = nil
	end
	for _, waiter in queued do
		waiter()
	end
end
local function whenAuthed(run)
	if auth then
		run()
		return nil
	end
	local _run = run
	table.insert(authWaiters, _run)
end
local function isAuthed()
	return auth
end
local function makeTxnId()
	return string.sub(HttpService:GenerateGUID(false), 1, 40)
end
-- Grant payloads attach these two fields so the server's SessionGate can verify the request
-- carries the live gen (and, for high-value actions, the live nonce) instead of trusting the
-- action name alone.
local function attachGrantFields(payload)
	payload.Gen = gen
	payload.N = nonce
	if type(payload.TxnId) ~= "string" or payload.TxnId == "" then
		payload.TxnId = makeTxnId()
	end
	return payload
end
local function adopt(response)
	if response.Gen == nil or response.Gen < gen then
		return nil
	end
	if response.N == nil then
		return nil
	end
	gen = response.Gen
	nonce = response.N
	if response.Auth ~= nil then
		auth = response.Auth
	end
end
local function startSession(remotes)
	stopped = false
	helloDone = false
	lastPresenceAt = -1e9
	sessionToken += 1
	local token = sessionToken
	local worker
	local beatOnce = function(force)
		local now = os.clock()
		if not force and now - lastPresenceAt < 1.7 then
			return nil
		end
		if presenceInFlight >= MAX_PRESENCE_IN_FLIGHT then
			-- A previous InvokeServer is still hung. Keep the beat loop moving so the next pass can retry.
			return "retry"
		end
		lastPresenceAt = now
		local payload = {
			Page = presencePage,
		}
		if helloDone then
			payload.Gen = gen
			payload.Id = nextBeatId
			payload.N = nonce
			nextBeatId += 1
		end
		presenceSerial += 1
		local serial = presenceSerial
		presenceInFlight += 1
		local finished = false
		local ok = false
		local raw = nil
		task.spawn(function()
			local callOk, callRaw = pcall(function()
				return remotes.Request:InvokeServer("ReportPresence", payload)
			end)
			presenceInFlight = math.max(0, presenceInFlight - 1)
			if serial ~= presenceSerial or token ~= sessionToken or stopped then
				return nil
			end
			ok = callOk
			raw = callRaw
			finished = true
		end)
		local started = os.clock()
		while not finished and not stopped and token == sessionToken and os.clock() - started < PRESENCE_TIMEOUT_SECONDS do
			task.wait(0.05)
		end
		if stopped or token ~= sessionToken then
			return nil
		end
		if not finished then
			presenceSerial += 1
			lastPresenceAt = -1e9
			ClientLog:warnEvery("presence-beat", 15, "auth", "presence beat timed out")
			return "retry"
		end
		if not ok or not (type(raw) == "table") then
			lastPresenceAt = -1e9
			ClientLog:warnEvery("presence-beat", 15, "auth", if ok then "presence beat returned no session" else tostring(raw))
			return "retry"
		end
		local response = raw
		if response.ok ~= true then
			lastPresenceAt = -1e9
			ClientLog:warnEvery("presence-reject", 15, "auth", tostring(response.error or "presence rejected"))
			return "retry"
		end
		local wasAuthed = auth
		adopt(response)
		if not helloDone then
			helloDone = true
			ClientLog:debug("auth", `hello ok gen={gen}`)
		elseif not wasAuthed and auth then
			ClientLog:debug("auth", `beat ok gen={gen}`)
		end
		if auth then
			flushAuthWaiters()
		end
		return "ok"
	end
	worker = task.spawn(function()
		local outcome = beatOnce(true)
		if not stopped then
			outcome = beatOnce(true)
		end
		while not stopped do
			-- A timed-out or rejected beat retries on the short interval. A hung
			-- InvokeServer must not sit on this thread, or auth never recovers.
			local retrySoon = outcome == "retry" or not auth
			local interval = if retrySoon then 2 else BEAT_INTERVAL_MIN + math.random() * (BEAT_INTERVAL_MAX - BEAT_INTERVAL_MIN)
			task.wait(interval)
			if stopped then
				break
			end
			outcome = beatOnce(false)
		end
	end)
	return function()
		stopped = true
		if worker ~= nil then
			pcall(function()
				return task.cancel(worker)
			end)
			worker = nil
		end
	end
end
return {
	setPresencePage = setPresencePage,
	whenAuthed = whenAuthed,
	isAuthed = isAuthed,
	attachGrantFields = attachGrantFields,
	adopt = adopt,
	startSession = startSession,
	makeTxnId = makeTxnId,
	GRANT_ACTIONS = GRANT_ACTIONS,
}
end

-- ======================================================================
-- Module: types   (merged from types.luau, 56 lines)
-- ======================================================================
__defs["types"] = function()
-- ============================================================
-- FORGE PATH — DISPLAY METADATA ONLY
-- ============================================================
-- Authoritative step list lives in Shared GameConfig.ForgePath.Steps.
-- This module only maps EffectKind → icons/colors/labels for the client UI.

local FORGE_PATH_EFFECT_DISPLAY = {
	Production = { label = "Output", unit = "%", noun = "production", icon = "Forge", color = Color3.fromRGB(242, 96, 112) },
	TapPower = { label = "Strike", unit = "%", noun = "tap power", icon = "Overcharge", color = Color3.fromRGB(241, 177, 65) },
	Capacity = { label = "Reserve", unit = "%", noun = "vault capacity", icon = "Vault", color = Color3.fromRGB(145, 112, 238) },
	CriticalChance = { label = "Precision", unit = "%", noun = "critical chance", icon = "Jackpot", color = Color3.fromRGB(90, 205, 232) },
	AutoCollect = { label = "Auto", unit = "%", noun = "auto-collect rate", icon = "Vault", color = Color3.fromRGB(145, 112, 238) },
	Offline = { label = "Idle", unit = "%", noun = "offline income", icon = "Timer", color = Color3.fromRGB(90, 205, 232) },
	CriticalMultiplier = { label = "Impact", unit = "%", noun = "critical multiplier", icon = "Jackpot", color = Color3.fromRGB(241, 177, 65) },
	RebirthMultiplier = { label = "Cycle", unit = "%", noun = "rebirth multiplier", icon = "Rebirth", color = Color3.fromRGB(224, 94, 170) },
}

local FALLBACK_DISPLAY = { label = "Bonus", unit = "%", noun = "bonus", icon = "Forge", color = Color3.fromRGB(145, 112, 238) }

local function forgePathEffectDisplay(effectKind)
	return FORGE_PATH_EFFECT_DISPLAY[effectKind] or FALLBACK_DISPLAY
end

local function decorateForgePathStep(step)
	local display = forgePathEffectDisplay(step.EffectKind)
	return {
		Step = step.Step,
		XPCost = step.XPCost,
		EffectKind = step.EffectKind,
		EffectAmount = step.EffectAmount,
		Reward = step.Reward,
		Icon = display.icon,
		Color = display.color,
		Noun = display.noun,
		Label = display.label,
		Unit = display.unit,
	}
end

local function decorateForgePathSteps(steps)
	if steps == nil then
		return {}
	end
	local decorated = table.create(#steps)
	for index, step in steps do
		decorated[index] = decorateForgePathStep(step)
	end
	return decorated
end

return {
	FORGE_PATH_EFFECT_DISPLAY = FORGE_PATH_EFFECT_DISPLAY,
	forgePathEffectDisplay = forgePathEffectDisplay,
	decorateForgePathStep = decorateForgePathStep,
	decorateForgePathSteps = decorateForgePathSteps,
}
end

-- ======================================================================
-- Module: noticeMath   (merged from noticeMath.luau, 39 lines)
-- ======================================================================
__defs["noticeMath"] = function()
-- Pure toast/notice helpers split out of MainGame. No Roblox services.

local NoticeMath = {}

function NoticeMath.NormalizeTitle(title: any): string
	local text = if type(title) == "string" then title else tostring(title)
	if text == "Boost online" then
		return "Boost on"
	elseif text == "Rebirth" then
		return "Rebirth done"
	elseif text == "Order paid" then
		return "Claimed"
	elseif text == "Studio grant" then
		return "Purchase test"
	end
	return text
end

function NoticeMath.Signature(title: string, body: any, tone: any): string
	return `{title}|{body}|{tone}`
end

function NoticeMath.ShouldDedupe(lastSignature: string, lastAt: number, signature: string, now: number, window: number?): boolean
	local gap = if type(window) == "number" then window else 0.55
	return lastSignature == signature and (now - lastAt) < gap
end

function NoticeMath.Lifetime(notificationDuration: number): number
	local duration = tonumber(notificationDuration) or 0
	return 2.8 + duration * 4.4
end

function NoticeMath.MaxNotices(toastDensity: number): number
	local density = tonumber(toastDensity) or 0
	return math.clamp(math.floor(2 + density * 3 + 0.5), 2, 5)
end

return table.freeze(NoticeMath)
end

-- ======================================================================
-- Module: deadlines   (merged from deadlines.luau, 37 lines)
-- ======================================================================
__defs["deadlines"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Workspace = game:GetService("Workspace")
local function unixNow()
	return Workspace:GetServerTimeNow()
end
local function useUnixDeadline(deadline)
	local active, setActive = React.useState(function()
		return type(deadline) == "number" and deadline > unixNow()
	end)
	React.useEffect(function()
		if type(deadline) ~= "number" then
			setActive(false)
			return nil
		end
		local remaining = deadline - unixNow()
		if remaining ~= remaining or remaining <= 0 then
			setActive(false)
			return nil
		end
		setActive(true)
		local alive = true
		local worker = task.delay(remaining + 0.05, function()
			if alive then
				setActive(false)
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, worker)
		end
	end, { deadline })
	return active
end
return {
	unixNow = unixNow,
	useUnixDeadline = useUnixDeadline,
}
end

-- ======================================================================
-- Module: boostIconKind   (merged from boostIconKind.luau, 21 lines)
-- ======================================================================
__defs["boostIconKind"] = function()
-- Pure boost-id → icon-kind mapping for ActiveBoost chrome. No Roblox
-- services — MainGame and Lune verify scripts share this so icon routing
-- stays testable without Studio.

local BoostIconKind = {}

function BoostIconKind.of(boostId: any): string
	if boostId == "DomainSurge" then
		return "Domain"
	end
	if boostId == "VaultSurge" then
		return "Vault"
	end
	if boostId == "Hyperdrive" then
		return "World"
	end
	return "Reactor"
end

return table.freeze(BoostIconKind)
end

-- ======================================================================
-- Module: releaseClockMath   (merged from releaseClockMath.luau, 18 lines)
-- ======================================================================
__defs["releaseClockMath"] = function()
-- Pure release-countdown helpers for MainGame / PageRouter topbar + Overview.
-- No Roblox services — remaining/live gates stay Lune-testable. Server time
-- injection stays with the caller (Workspace:GetServerTimeNow / os.time).

local ReleaseClockMath = {}

-- Seconds remaining until `deadline` (unix). Never negative.
function ReleaseClockMath.Remaining(deadline: any, now: any): number
	return math.max(0, (tonumber(deadline) or 0) - (tonumber(now) or 0))
end

-- True when the deadline has elapsed (remaining == 0).
function ReleaseClockMath.IsLive(deadline: any, now: any): boolean
	return ReleaseClockMath.Remaining(deadline, now) <= 0
end

return table.freeze(ReleaseClockMath)
end

-- ======================================================================
-- Module: vaultCollectEligibility   (merged from vaultCollectEligibility.luau, 30 lines)
-- ======================================================================
__defs["vaultCollectEligibility"] = function()
-- Pure vault-collect eligibility thresholds shared by Overview, VaultPill,
-- and Workspace. No Roblox services — Lune verify scripts exercise these
-- without Studio. Callers pass already-normalized flux numbers (asFlux).

local VaultCollectEligibility = {}

-- Minimum vault flux before Collect is enabled (matches prior inline 0.01).
VaultCollectEligibility.MIN_COLLECTABLE = 0.01
-- Fill ratio that highlights the collect CTA as urgent.
VaultCollectEligibility.NEAR_FULL = 0.85
-- Fill ratio treated as a full / wasting-production vault.
VaultCollectEligibility.FULL = 0.99

function VaultCollectEligibility.isEligible(vaultFlux: number): boolean
	local amount = tonumber(vaultFlux) or 0
	return amount >= VaultCollectEligibility.MIN_COLLECTABLE
end

function VaultCollectEligibility.isNearFull(fill: number): boolean
	local ratio = tonumber(fill) or 0
	return ratio >= VaultCollectEligibility.NEAR_FULL
end

function VaultCollectEligibility.isFull(fill: number): boolean
	local ratio = tonumber(fill) or 0
	return ratio >= VaultCollectEligibility.FULL
end

return table.freeze(VaultCollectEligibility)
end

-- ======================================================================
-- Module: inputPlatform   (merged from inputPlatform.luau, 31 lines)
-- ======================================================================
__defs["inputPlatform"] = function()
local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local _3a = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["3a"])
local Input = _3a.Input
local InputMethod = _3a.InputMethod
local UserInputService = game:GetService("UserInputService")
local TouchGestureService = __load("TouchGestureService")
local GamepadNavigationService = __load("GamepadNavigationService")
local configured = false
local function configureInputPlatform()
	if configured then
		return function() end
	end
	local methods = if UserInputService.TouchEnabled then { InputMethod.Touchscreen } elseif UserInputService.GamepadEnabled then { InputMethod.Gamepad } else { InputMethod.KeyboardMouse }
	local ok, problem = pcall(function()
		return Input.setMethods(methods)
	end)
	if not ok then
		warn("[ERROR] [INPUT] setMethods failed | Error: " .. tostring(problem))
	end
	TouchGestureService.Init()
	GamepadNavigationService.Init()
	configured = true
	return function()
		TouchGestureService.Stop()
		GamepadNavigationService.Stop()
		configured = false
	end
end
return {
	configureInputPlatform = configureInputPlatform,
}
end

-- ======================================================================
-- Module: networkPolicy   (merged from networkPolicy.luau, 170 lines)
-- ======================================================================
__defs["networkPolicy"] = function()
-- Pure MainGame remote dispatch policy: cooldowns, timeouts, pipeline /
-- optimistic allowlists. No Roblox services — MainGame and Lune verify scripts
-- share this so client request gating stays testable without Studio.

local NetworkPolicy = {}

NetworkPolicy.DEFAULT_COOLDOWN = 0.1
NetworkPolicy.DEFAULT_TIMEOUT = 15
NetworkPolicy.MAX_PHYSICAL_REQUESTS = 12
NetworkPolicy.PIPELINE_REQUEST_LIMIT = 4
NetworkPolicy.SERIAL_REQUEST_LIMIT = 2

NetworkPolicy.ACTION_COOLDOWNS = {
	GetState = 0.24,
	GetPlayers = 0.28,
	GetPlayerMirror = 0.28,
	VisitPlot = 0.52,
	LeavePlot = 0.35,
	NudgeCrew = 2.7,
	ReportPresence = 1.6,
	CollectVault = 0.04,
	Overcharge = 0.05,
	PulseAnomaly = 0.05,
	SpinWheel = 1.4,
	CasinoPlay = 0.4,
	BazaarPlay = 0.35,
	OpenItemCrate = 0.24,
	UpgradeContinuum = 0.4,
	CaptureEcho = 1.2,
	ClaimEcho = 0.48,
	EquipEcho = 0.24,
	UpgradeEcho = 0.3,
	DismantleEcho = 0.6,
	SetAutoForge = 0.28,
	SetItemAutoSalvage = 0.2,
	BulkSalvageItems = 0.35,
	SetSetting = 0.18,
	SetMobileLayout = 0.35,
	SetTutorialStep = 0.18,
	ClaimLabOrder = 0.18,
	RouteLabPower = 0.12,
	ReadStoryChapter = 0.18,
	ClaimStoryChapter = 0.18,
	ReadMail = 0.18,
	ClaimMail = 0.18,
	ClaimAllMail = 0.75,
	DeleteMail = 0.18,
	RedeemCode = 1.5,
	SyncShop = 1.3,
	StudioGrantProduct = 0.45,
	GetTrade = 0.2,
	InviteTrade = 0.7,
	RespondTrade = 0.28,
	UpdateTradeOffer = 0.08,
	SetTradeReady = 0.12,
	ConfirmTrade = 0.28,
	CancelTrade = 0.2,
	TradeViewAway = 0.2,
	DomainExpansion = 5.2,
	ClaimConvergenceReward = 0.45,
	GetLeaderboard = 1.1,
	GetGuildLeaderboard = 1.1,
	GetAdminState = 0.9,
	ReportClientIntegrity = 30.5,
	AdminExecute = 0.9,
	CreateGuild = 2.1,
	JoinGuild = 1.1,
	GetGuild = 0.32,
	KickGuildMember = 0.6,
	SetGuildRole = 0.6,
	ContributeGuild = 0.45,
	BuyGuildUpgrade = 0.8,
	LeaveGuild = 1.1,
}

NetworkPolicy.REQUEST_TIMEOUTS = {
	GetState = 8,
	GetPlayers = 8,
	GetPlayerMirror = 8,
	GetGuild = 8,
	GetGuildLeaderboard = 8,
	GetLeaderboard = 8,
	GetAdminState = 8,
}

NetworkPolicy.PIPELINED_ACTIONS = {
	["Overcharge"] = true,
	["PulseAnomaly"] = true,
	["CollectVault"] = true,
	["RouteLabPower"] = true,
	["SetAutoForge"] = true,
	["SetAnomalyChannel"] = true,
	["SetSetting"] = true,
	["SetMobileLayout"] = true,
	["SetTutorialStep"] = true,
	["ReplayTutorial"] = true,
	["DismissRelease"] = true,
	["OpenRelease"] = true,
	["ReadStoryChapter"] = true,
	["ReadMail"] = true,
	["SelectZone"] = true,
	["UpdateTradeOffer"] = true,
	["SetTradeReady"] = true,
	["ConfirmTrade"] = true,
	["CancelTrade"] = true,
	["RespondTrade"] = true,
	["TradeViewAway"] = true,
	["SetItemAutoSalvage"] = true,
	["ReportPresence"] = true,
}

NetworkPolicy.OPTIMISTIC_ACTIONS = {
	["CollectVault"] = true,
	["Overcharge"] = true,
	["RouteLabPower"] = true,
	["SetAutoForge"] = true,
	["SetAnomalyChannel"] = true,
	["SetSetting"] = true,
	["SetMobileLayout"] = true,
	["SetTutorialStep"] = true,
	["CompleteTutorial"] = true,
	["ReplayTutorial"] = true,
	["DismissRelease"] = true,
	["OpenRelease"] = true,
	["ReadStoryChapter"] = true,
	["ReadMail"] = true,
	["SelectZone"] = true,
	["EquipTitle"] = true,
	["ReportPresence"] = true,
}

function NetworkPolicy.Cooldown(action: any): number
	if type(action) ~= "string" then
		return NetworkPolicy.DEFAULT_COOLDOWN
	end
	local value = NetworkPolicy.ACTION_COOLDOWNS[action]
	return if type(value) == "number" then value else NetworkPolicy.DEFAULT_COOLDOWN
end

function NetworkPolicy.Timeout(action: any): number
	if type(action) ~= "string" then
		return NetworkPolicy.DEFAULT_TIMEOUT
	end
	local value = NetworkPolicy.REQUEST_TIMEOUTS[action]
	return if type(value) == "number" then value else NetworkPolicy.DEFAULT_TIMEOUT
end

function NetworkPolicy.IsPipelined(action: any): boolean
	return type(action) == "string" and NetworkPolicy.PIPELINED_ACTIONS[action] == true
end

function NetworkPolicy.IsOptimistic(action: any): boolean
	return type(action) == "string" and NetworkPolicy.OPTIMISTIC_ACTIONS[action] == true
end

function NetworkPolicy.RequestLimit(pipelined: boolean?): number
	return if pipelined then NetworkPolicy.PIPELINE_REQUEST_LIMIT else NetworkPolicy.SERIAL_REQUEST_LIMIT
end

-- True when `now - previous` is still inside the cooldown window.
function NetworkPolicy.IsCoolingDown(now: any, previous: any, cooldown: any): boolean
	local clock = tonumber(now)
	local last = tonumber(previous)
	local window = tonumber(cooldown)
	if clock == nil or last == nil or window == nil then
		return false
	end
	return clock - last < window
end

return table.freeze(NetworkPolicy)
end

-- ======================================================================
-- Module: actionCopy   (merged from actionCopy.luau, 185 lines)
-- ======================================================================
__defs["actionCopy"] = function()
-- Pure player-facing action copy helpers. No Roblox services — MainGame and
-- Lune verify scripts share this so failure titles / friendly rewrites stay
-- testable without Studio. Toast/UI wiring stays with the caller.

local ActionCopy = {}

ActionCopy.PLAYER_COPY = {
	["that request could not be validated."] = "That didn't go through. Try again.",
	["the server is still finishing an earlier request."] = "Still working on your last tap.",
	["the connection is busy. try again in a moment."] = "Things are a little busy. Try again in a moment.",
	["the server took too long. try again."] = "That took too long. Try again.",
	["the server did not answer that click."] = "That tap didn't go through. Try again.",
	["action rejected."] = "That move isn't available right now.",
	["malformed admin request."] = "Check the command fields and try again.",
	["invalid action payload"] = "That option isn't available.",
	["invalid action payload."] = "That option isn't available.",
	["the forge encountered an error. please try again."] = "Something went wrong. Please try again.",
	["the forge returned an invalid response. please try again."] = "That didn't go through. Please try again.",
	["request rejected."] = "That move isn't available right now.",
	["payload is required"] = "That option isn't available.",
	["payload must be a table"] = "That option isn't available.",
	["this action does not accept a payload"] = "That option isn't available.",
	["invalid expedition"] = "Pick an expedition first.",
	["invalid artifact"] = "Choose an artifact first.",
	["invalid signal offer"] = "That signal offer isn't available.",
	["invalid title selection"] = "Choose a title to wear.",
	["invalid boost selection"] = "Choose a boost to activate.",
	["invalid shop offer"] = "That shop offer isn't available.",
	["invalid protocol"] = "That protocol isn't available.",
	["invalid reactor channel"] = "Pick a reactor channel.",
	["invalid story chapter"] = "That chapter isn't available.",
	["invalid mail"] = "That message isn't available.",
	["invalid guild upgrade"] = "That guild upgrade isn't available.",
	["invalid follow verification payload"] = "Couldn't check that follow.",
	["invalid code payload"] = "Enter a code first.",
	["invalid upgrade payload"] = "Choose an upgrade and try again.",
	["invalid claim payload"] = "That reward isn't ready to claim.",
	["invalid reward payload"] = "That reward isn't ready to claim.",
	["invalid progression payload"] = "That level isn't ready yet.",
	["invalid world payload"] = "That world isn't available yet.",
}

ActionCopy.INTERNAL_PAYLOAD_COPY = {
	["invalid action payload"] = true,
	["invalid action payload."] = true,
	["payload is required"] = true,
	["payload must be a table"] = true,
	["this action does not accept a payload"] = true,
	["that option isn't available."] = true,
	["that option isn't available"] = true,
	["check that choice and try again."] = true,
	["check that choice and try again"] = true,
	["that request could not be validated."] = true,
	["that request could not be validated"] = true,
	["that didn't go through. try again."] = true,
	["that didn't go through. try again"] = true,
}

-- Prefix → toast title for failed actions (first match wins).
ActionCopy.FAILURE_TITLE_PREFIXES = {
	{ "Claim", "Couldn't claim" },
	{ "Buy", "Couldn't buy" },
	{ "Upgrade", "Couldn't upgrade" },
	{ "Unlock", "Couldn't unlock" },
	{ "Equip", "Couldn't equip" },
	{ "Unequip", "Couldn't unequip" },
	{ "Salvage", "Couldn't salvage" },
	{ "Set", "Couldn't update" },
	{ "Toggle", "Couldn't update" },
	{ "Start", "Couldn't start" },
	{ "Launch", "Couldn't launch" },
	{ "Join", "Couldn't join" },
	{ "Leave", "Couldn't leave" },
	{ "Create", "Couldn't create" },
	{ "Invite", "Couldn't invite" },
	{ "Respond", "Trade issue" },
	{ "Confirm", "Trade issue" },
	{ "Cancel", "Trade issue" },
	{ "Update", "Trade issue" },
	{ "Contribute", "Couldn't contribute" },
	{ "Kick", "Couldn't remove them" },
	{ "Report", "Couldn't send that" },
	{ "Redeem", "Couldn't redeem" },
	{ "Spin", "Couldn't spin" },
	{ "Select", "Couldn't travel" },
	{ "Route", "Couldn't route power" },
	{ "Stabilize", "Couldn't stabilize" },
	{ "Pulse", "Couldn't pulse" },
	{ "Capture", "Couldn't capture" },
	{ "Dismantle", "Couldn't dismantle" },
	{ "Open", "Couldn't open" },
	{ "Read", "Couldn't open" },
	{ "Delete", "Couldn't delete" },
	{ "Rebirth", "Couldn't rebirth" },
	{ "Verify", "Follow" },
}

ActionCopy.FAILURE_BODY_BY_ACTION = {
	LaunchExpedition = "Pick an expedition first.",
	ClaimExpedition = "That expedition isn't back yet.",
	EquipArtifact = "Choose an artifact to equip.",
	UpgradeArtifact = "Choose an artifact to upgrade.",
	BuySignalOffer = "That signal offer isn't available.",
	EquipTitle = "Choose a title to wear.",
	ActivateBoost = "Choose a boost to activate.",
	BuyItemOffer = "That shop offer isn't available.",
	BuyAnomalyProtocol = "That protocol isn't available.",
	SetAnomalyChannel = "Pick a reactor channel.",
	ReadStoryChapter = "That chapter isn't available.",
	ClaimStoryChapter = "That chapter isn't ready to claim.",
	ReadMail = "That message isn't available.",
	ClaimMail = "That mail isn't ready to claim.",
	DeleteMail = "That message isn't available.",
	BuyGuildUpgrade = "That guild upgrade isn't available.",
	BuyMachine = "That station isn't available.",
	BuyResearch = "That research isn't available.",
	Overcharge = "That station isn't ready to overcharge.",
	CollectVault = "Nothing to collect yet.",
	Rebirth = "You aren't ready to rebirth yet.",
	VerifyCreatorFollow = "Couldn't check that follow.",
	RedeemCode = "Enter a code first.",
}

function ActionCopy.friendlyPlayerMessage(value: any): string?
	if value == nil or #value == 0 then
		return nil
	end
	local exact = ActionCopy.PLAYER_COPY[value]
	if exact == nil then
		exact = ActionCopy.PLAYER_COPY[string.lower(value)]
	end
	if exact ~= nil then
		return exact
	end
	return value
end

function ActionCopy.failureTitle(action: string, gated: boolean?): string
	if gated then
		return "Still locked"
	end
	if action == "VerifyCreatorFollow" then
		return "Follow"
	end
	for _, binding in ActionCopy.FAILURE_TITLE_PREFIXES do
		local prefix = binding[1]
		local title = binding[2]
		if string.sub(action, 1, #prefix) == prefix then
			return title
		end
	end
	return "Couldn't do that"
end

function ActionCopy.failureBody(action: string, raw: string): string
	local lowered = string.lower(raw)
	if ActionCopy.INTERNAL_PAYLOAD_COPY[lowered] ~= nil then
		local mapped = ActionCopy.FAILURE_BODY_BY_ACTION[action]
		if mapped == nil then
			mapped = "That option isn't available."
		end
		return mapped
	end
	local friendly = ActionCopy.friendlyPlayerMessage(raw)
	if friendly == nil then
		friendly = raw
	end
	return friendly
end

function ActionCopy.friendlyActionResponse(response: any): any
	local message = ActionCopy.friendlyPlayerMessage(response.message)
	local friendlyError = ActionCopy.friendlyPlayerMessage(response.error)
	if message == response.message and friendlyError == response.error then
		return response
	end
	local cloned = table.clone(response)
	setmetatable(cloned, nil)
	cloned.message = message
	cloned.error = friendlyError
	return cloned
end

return table.freeze(ActionCopy)
end

-- ======================================================================
-- Module: pageBoardHeights   (merged from pageBoardHeights.luau, 27 lines)
-- ======================================================================
__defs["pageBoardHeights"] = function()
-- Pure PageRouter board row heights (machine / world / visit). No Roblox
-- services — PageRouter and Lune verify scripts share this so VirtualGrid
-- budgets stay testable without Studio.

local PageBoardHeights = {}

PageBoardHeights.MACHINE = 120
PageBoardHeights.MACHINE_STACK = 188
PageBoardHeights.WORLD = 148
PageBoardHeights.WORLD_STACK = 218
PageBoardHeights.VISIT = 268
PageBoardHeights.VISIT_STACK = 380

function PageBoardHeights.Machine(stack: boolean?): number
	return if stack then PageBoardHeights.MACHINE_STACK else PageBoardHeights.MACHINE
end

function PageBoardHeights.World(stack: boolean?): number
	return if stack then PageBoardHeights.WORLD_STACK else PageBoardHeights.WORLD
end

function PageBoardHeights.Visit(stack: boolean?): number
	return if stack then PageBoardHeights.VISIT_STACK else PageBoardHeights.VISIT
end

return table.freeze(PageBoardHeights)
end

-- ======================================================================
-- Module: taskFilter   (merged from taskFilter.luau, 41 lines)
-- ======================================================================
__defs["taskFilter"] = function()
local function taskMatchesFilter(task, filter)
	if filter == "Ready" then
		return not task.Claimed and task.Progress >= task.Target
	end
	if filter == "Active" then
		return not task.Claimed and task.Progress < task.Target
	end
	if filter == "Done" then
		return task.Claimed
	end
	return true
end
local function taskFilterCounts(tasks)
	local ready = 0
	local active = 0
	local done = 0
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(task)
		if task.Claimed then
			done += 1
		elseif task.Progress >= task.Target then
			ready += 1
		else
			active += 1
		end
	end
	for _k, _v in tasks do
		_callback(_v, _k - 1, tasks)
	end
	-- ▲ ReadonlyArray.forEach ▲
	return {
		All = #tasks,
		Ready = ready,
		Active = active,
		Done = done,
	}
end
return {
	taskMatchesFilter = taskMatchesFilter,
	taskFilterCounts = taskFilterCounts,
}
end

-- ======================================================================
-- Module: snapshotEnvelopeMath   (merged from snapshotEnvelopeMath.luau, 61 lines)
-- ======================================================================
__defs["snapshotEnvelopeMath"] = function()
-- Pure snapshot envelope validators split out of MainGame. No Roblox services.

local SnapshotEnvelopeMath = {}

local NUMERIC_KEYS = { "Revision", "SnapshotId", "ServerTime", "Cores", "Stardust", "Rebirths", "Zone", "CurrentZone" }
local PERSIST_KEYS = { "Cash", "Vault", "RunCash", "LifetimeCash", "Production", "Capacity" }
local TABLE_KEYS = { "Game", "Machines", "Research", "Wheel", "Daily", "TimedRewards", "Quests", "Settings", "Flags" }

function SnapshotEnvelopeMath.IsFiniteNumber(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	return value == value and value ~= math.huge and value ~= -math.huge
end

function SnapshotEnvelopeMath.IsPersist(value: any): boolean
	if SnapshotEnvelopeMath.IsFiniteNumber(value) then
		return value >= 0
	end
	if type(value) ~= "string" or #value == 0 then
		return false
	end
	local lower = string.lower(value)
	if lower == "inf" or lower == "infinity" then
		return true
	end
	return (string.match(value, "^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+$")) ~= nil or tonumber(value) ~= nil
end

function SnapshotEnvelopeMath.IsValidEnvelope(candidate: any): boolean
	if type(candidate) ~= "table" then
		return false
	end
	for _, key in NUMERIC_KEYS do
		if not SnapshotEnvelopeMath.IsFiniteNumber(candidate[key]) then
			return false
		end
	end
	for _, key in PERSIST_KEYS do
		if not SnapshotEnvelopeMath.IsPersist(candidate[key]) then
			return false
		end
	end
	for _, key in TABLE_KEYS do
		if type(candidate[key]) ~= "table" then
			return false
		end
	end
	local revision = candidate.Revision
	local snapshotId = candidate.SnapshotId
	if type(revision) ~= "number" or revision < 0 then
		return false
	end
	if type(snapshotId) ~= "number" or snapshotId < 0 then
		return false
	end
	return true
end

return table.freeze(SnapshotEnvelopeMath)
end

-- ======================================================================
-- Module: inventoryMath   (merged from inventoryMath.luau, 397 lines)
-- ======================================================================
__defs["inventoryMath"] = function()
-- Pure inventory relic helpers: effect/upgrade/salvage math, socket labels,
-- filter/sort/search, auto-salvage signatures. No Roblox services — InventoryView
-- and Lune verify scripts share this so bag tooling stays testable without Studio.
-- Salvage Value matches Server ItemSalvage.Value (rank^2*8 + max(0,level-1)*rank*3).

local InventoryMath = {}

InventoryMath.AUTO_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

InventoryMath.ROW_H = 112
InventoryMath.ROW_H_STACK = 132

function InventoryMath.RelicRowHeight(stack: boolean): number
	return if stack then InventoryMath.ROW_H_STACK else InventoryMath.ROW_H
end

function InventoryMath.RarityRank(config: any, rarity: any): number
	local items = type(config) == "table" and config.Items or nil
	local rarities = type(items) == "table" and items.Rarities or nil
	local entry = type(rarities) == "table" and rarities[rarity] or nil
	local rank = type(entry) == "table" and entry.Rank or nil
	return if type(rank) == "number" then rank else 0
end

function InventoryMath.EffectAtLevel(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = if type(level) == "number" then level else 1
	-- Keep formula identical to EconomyEnvelopeMath.EffectAtLevel (verify parity).
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

-- Color3 (or fallback) for a rarity entry. Fallback is caller-supplied so this
-- stays free of theme / Roblox Color3 defaults under Lune.
function InventoryMath.RarityColor(config: any, rarity: any, fallback: any): any
	local items = type(config) == "table" and config.Items or nil
	local rarities = type(items) == "table" and items.Rarities or nil
	local entry = type(rarities) == "table" and rarities[rarity] or nil
	local color = type(entry) == "table" and entry.Color or nil
	if color ~= nil then
		return color
	end
	return fallback
end

function InventoryMath.EffectLabel(definition: any, level: any): string
	local pct = math.floor(InventoryMath.EffectAtLevel(definition, level) * 1000 + 0.5) / 10
	local kind = if type(definition) == "table" and type(definition.EffectKind) == "string"
		then definition.EffectKind
		else "Effect"
	return `+{pct}% {kind}`
end

function InventoryMath.UpgradeCost(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.EssenceBase) or 0
	local safeLevel = if type(level) == "number" then level else 1
	return math.floor(base * 1.55 ^ math.max(0, safeLevel - 1))
end

-- Matches ItemSalvage.Value — keep formulas in lockstep via verify_inventory_math.
function InventoryMath.SalvageValue(level: any, rarityRank: any): number
	local rank = if type(rarityRank) == "number" then rarityRank else 1
	local safeLevel = if type(level) == "number" then level else 1
	return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3
end

function InventoryMath.SalvagePreview(config: any, definition: any, level: any): number
	local rarity = type(definition) == "table" and definition.Rarity or nil
	return InventoryMath.SalvageValue(level, InventoryMath.RarityRank(config, rarity))
end

function InventoryMath.SocketLabel(target: any): string
	if type(target) ~= "string" then
		return tostring(target)
	end
	local parts = string.split(target, ":")
	return if #parts >= 2 then `{parts[1]} / {parts[2]}` else target
end

function InventoryMath.FilterOwned(list: any, filter: any): { any }
	if type(list) ~= "table" then
		return {}
	end
	if filter == "All" or filter == nil then
		return list
	end
	local out = {}
	for _, item in list do
		if type(item) ~= "table" then
			continue
		end
		local keep = false
		if filter == "Equipped" then
			keep = item.equippedOn ~= nil
		elseif filter == "Unequipped" then
			keep = item.equippedOn == nil
		elseif filter == "Protected" then
			keep = type(item.instance) == "table" and item.instance.Locked == true
		elseif type(item.definition) == "table" then
			keep = item.definition.Slot == filter
		end
		if keep then
			table.insert(out, item)
		end
	end
	return out
end

function InventoryMath.SearchOwned(list: any, query: any, rarity: any): { any }
	if type(list) ~= "table" then
		return {}
	end
	local needle = string.gsub(string.lower(tostring(query or "")), "^%s*(.-)%s*$", "%1")
	local rarityFilter = if rarity == nil then "Any" else rarity
	local out = {}
	for _, item in list do
		if type(item) ~= "table" or type(item.definition) ~= "table" then
			continue
		end
		if rarityFilter ~= "Any" and item.definition.Rarity ~= rarityFilter then
			continue
		end
		if needle == "" then
			table.insert(out, item)
			continue
		end
		local haystack = string.lower(
			`{item.definition.Name or ""} {item.definition.Description or ""} {item.definition.EffectKind or ""} {item.uid or ""}`
		)
		if string.find(haystack, needle, 1, true) ~= nil then
			table.insert(out, item)
		end
	end
	return out
end

function InventoryMath.SortOwned(list: any, config: any, sort: any): { any }
	if type(list) ~= "table" then
		return {}
	end
	local copy = {}
	table.move(list, 1, #list, 1, copy)
	table.sort(copy, function(a, b)
		if type(a) ~= "table" or type(b) ~= "table" then
			return false
		end
		local aDef = a.definition
		local bDef = b.definition
		local aInst = a.instance
		local bInst = b.instance
		if type(aDef) ~= "table" or type(bDef) ~= "table" or type(aInst) ~= "table" or type(bInst) ~= "table" then
			return false
		end
		if sort == "Level" then
			if aInst.Level ~= bInst.Level then
				return aInst.Level > bInst.Level
			end
			return (aDef.Name or "") < (bDef.Name or "")
		end
		if sort == "Name" then
			return (aDef.Name or "") < (bDef.Name or "")
		end
		if sort == "Newest" then
			if aInst.AcquiredAt ~= bInst.AcquiredAt then
				return (aInst.AcquiredAt or 0) > (bInst.AcquiredAt or 0)
			end
			return tostring(a.uid or "") > tostring(b.uid or "")
		end
		if sort == "Power" then
			local pa = InventoryMath.EffectAtLevel(aDef, aInst.Level)
			local pb = InventoryMath.EffectAtLevel(bDef, bInst.Level)
			if pa ~= pb then
				return pa > pb
			end
			return InventoryMath.RarityRank(config, aDef.Rarity) > InventoryMath.RarityRank(config, bDef.Rarity)
		end
		local ra = InventoryMath.RarityRank(config, aDef.Rarity)
		local rb = InventoryMath.RarityRank(config, bDef.Rarity)
		if ra ~= rb then
			return ra > rb
		end
		if aInst.Level ~= bInst.Level then
			return aInst.Level > bInst.Level
		end
		return (aDef.Name or "") < (bDef.Name or "")
	end)
	return copy
end

function InventoryMath.AutoSalvageSignature(rules: any, rarities: { string }?): string
	local bag = if type(rules) == "table" then rules else {}
	local rarityList = rarities or InventoryMath.AUTO_RARITIES
	local active = {}
	local rarityBag = type(bag.Rarities) == "table" and bag.Rarities or {}
	for _, rarity in rarityList do
		if rarity ~= "Any" and rarityBag[rarity] == true then
			table.insert(active, rarity)
		end
	end
	return `{if bag.Enabled then 1 else 0}:{if bag.KeepNew then 1 else 0}:{table.concat(active, ",")}`
end

-- Build owned-item rows from Items.Inventory + Definitions (+ Equipped map).
function InventoryMath.CollectOwned(state: any, config: any): { any }
	local items = type(state) == "table" and state.Items or nil
	local definitions = type(config) == "table" and config.Items and config.Items.Definitions or nil
	if type(items) ~= "table" or type(definitions) ~= "table" then
		return {}
	end
	local inventory = items.Inventory
	if type(inventory) ~= "table" then
		return {}
	end
	local byId = {}
	for _, definition in definitions do
		if type(definition) == "table" and type(definition.Id) == "string" then
			byId[definition.Id] = definition
		end
	end
	local equippedByUid = {}
	if type(items.Equipped) == "table" then
		for target, uid in pairs(items.Equipped) do
			if type(uid) == "string" then
				equippedByUid[uid] = target
			end
		end
	end
	local owned = {}
	for uid, instance in pairs(inventory) do
		if type(uid) ~= "string" or type(instance) ~= "table" then
			continue
		end
		local definition = byId[instance.DefinitionId]
		if definition == nil then
			continue
		end
		table.insert(owned, {
			uid = uid,
			instance = instance,
			definition = definition,
			equippedOn = equippedByUid[uid],
		})
	end
	return owned
end

-- Socket targets for a relic definition given owned Machines/Research levels.
function InventoryMath.SocketTargets(state: any, config: any, definition: any): { any }
	local out = {}
	if type(definition) ~= "table" or type(config) ~= "table" or type(state) ~= "table" then
		return out
	end
	local function pushUpgrade(upgrades: any, slot: string, owned: any)
		if type(upgrades) ~= "table" or type(owned) ~= "table" then
			return
		end
		for _, upgrade in upgrades do
			if type(upgrade) ~= "table" or type(upgrade.Id) ~= "string" then
				continue
			end
			local level = owned[upgrade.Id]
			if type(level) ~= "number" or level < 1 then
				continue
			end
			local targets = definition.Targets
			if type(targets) == "table" and (table.find(targets, upgrade.Id) or 0) - 1 < 0 then
				continue
			end
			table.insert(out, {
				id = `{slot}:{upgrade.Id}`,
				label = upgrade.Name,
			})
		end
	end
	if definition.Slot == "Machine" then
		pushUpgrade(config.Machines, "Machine", state.Machines)
	else
		pushUpgrade(config.Research, "Research", state.Research)
	end
	return out
end

function InventoryMath.RestockClock(seconds: any): string
	local total = math.max(0, math.floor(tonumber(seconds) or 0))
	if total <= 0 then
		return "READY"
	end
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	if minutes > 0 then
		return `{minutes}m`
	end
	return `{total}s`
end

function InventoryMath.OfferStock(offer: any): { stock: number, stockMax: number, soldOut: boolean, daily: boolean }
	if type(offer) ~= "table" then
		return { stock = 0, stockMax = 1, soldOut = true, daily = false }
	end
	local stockMax = math.max(1, tonumber(offer.StockMax) or 1)
	local defaultStock = if offer.Purchased == true then 0 else stockMax
	local stock = math.clamp(tonumber(offer.Stock) or defaultStock, 0, stockMax)
	return {
		stock = stock,
		stockMax = stockMax,
		soldOut = stock <= 0,
		daily = offer.DailyRefresh == true,
	}
end

InventoryMath.INSPECT_PAD = 14
InventoryMath.INSPECT_BTN_GAP = 8
InventoryMath.INSPECT_FOOTER_H = 18
InventoryMath.ACTION_BTN = 56

function InventoryMath.InspectSocketBlock(equipped: any, targetCount: any, chipRows: any, stack: boolean?, tapTarget: number?): number
	local stacked = stack == true
	if equipped then
		return 20
	end
	local targets = math.max(0, math.floor(tonumber(targetCount) or 0))
	if targets > 0 then
		local rowH = if stacked then (tonumber(tapTarget) or 48) + 6 else 42
		return 18 + math.max(0, math.floor(tonumber(chipRows) or 0)) * rowH
	end
	return 28
end

function InventoryMath.InspectActionsHeight(stack: boolean?): number
	return if stack == true
		then InventoryMath.ACTION_BTN * 2 + InventoryMath.INSPECT_BTN_GAP
		else InventoryMath.ACTION_BTN
end

function InventoryMath.InspectPanelHeight(socketBlock: any, stack: boolean?): number
	return InventoryMath.INSPECT_PAD * 2
		+ math.max(0, tonumber(socketBlock) or 0)
		+ InventoryMath.INSPECT_BTN_GAP
		+ InventoryMath.InspectActionsHeight(stack)
		+ InventoryMath.INSPECT_BTN_GAP
		+ InventoryMath.INSPECT_FOOTER_H
end


-- Detail-panel upgrade affordability. Returns canUpgrade, maxed.
function InventoryMath.UpgradeState(level: any, maxLevel: any, essence: any, cost: any): (boolean, boolean)
	local safeLevel = math.max(0, math.floor(tonumber(level) or 0))
	local safeMax = math.max(0, math.floor(tonumber(maxLevel) or 0))
	local maxed = safeMax > 0 and safeLevel >= safeMax
	local canUpgrade = not maxed and (tonumber(essence) or 0) >= (tonumber(cost) or 0)
	return canUpgrade, maxed
end

-- Chip grid row count for socket target lists (stack → 2 cols, desk → 3).
function InventoryMath.ChipRows(targetCount: any, stack: boolean?): number
	local targets = math.max(0, math.floor(tonumber(targetCount) or 0))
	if targets <= 0 then
		return 0
	end
	local cols = if stack == true then 2 else 3
	return math.max(1, math.ceil(targets / cols))
end

InventoryMath.LOADOUT_EFFECT_KEYS = table.freeze({
	{ id = "Production", label = "Production" },
	{ id = "Capacity", label = "Vault" },
	{ id = "Tap", label = "Overcharge" },
	{ id = "Critical", label = "Critical" },
	{ id = "Automation", label = "Auto" },
	{ id = "Offline", label = "Offline" },
})

-- Loadout board effect strip values from Items.Effects (nil-safe → 0).
function InventoryMath.LoadoutEffectLines(effects: any): { { id: string, label: string, value: number } }
	local bag = if type(effects) == "table" then effects else {}
	local lines = {}
	for _, entry in InventoryMath.LOADOUT_EFFECT_KEYS do
		table.insert(lines, {
			id = entry.id,
			label = entry.label,
			value = tonumber(bag[entry.id]) or 0,
		})
	end
	return lines
end

return table.freeze(InventoryMath)
end

-- ======================================================================
-- Module: adminFields   (merged from adminFields.luau, 511 lines)
-- ======================================================================
__defs["adminFields"] = function()
local ADMIN_REASONS = { {
	id = "Owner gameplay administration",
	label = "Owner gameplay administration",
}, {
	id = "Balance correction",
	label = "Balance correction",
}, {
	id = "Playtest grant",
	label = "Playtest grant",
}, {
	id = "Troll / joke",
	label = "Troll / joke",
}, {
	id = "Moderation action",
	label = "Moderation action",
}, {
	id = "Player request",
	label = "Player request",
}, {
	id = "Bug recovery",
	label = "Bug recovery",
}, {
	id = "Trade settle recovery",
	label = "Trade settle recovery",
} }
local KICK_REASONS = { {
	id = "You were kicked from this Astral Forge server by an administrator.",
	label = "Admin removal",
}, {
	id = "You were kicked for exploiting or using unauthorized software.",
	label = "Exploiting",
}, {
	id = "You were kicked for harassment or inappropriate behavior.",
	label = "Harassment",
}, {
	id = "You were kicked for spamming or disrupting other players.",
	label = "Spamming",
}, {
	id = "You were kicked for evading a previous punishment.",
	label = "Ban evasion",
}, {
	id = "You were kicked while this session is under review.",
	label = "Under review",
} }
local SERVER_BAN_REASONS = { {
	id = "You are banned from this Astral Forge server.",
	label = "Server ban",
}, {
	id = "You are banned from this server for exploiting or using unauthorized software.",
	label = "Exploiting",
}, {
	id = "You are banned from this server for harassment or inappropriate behavior.",
	label = "Harassment",
}, {
	id = "You are banned from this server for spamming or disrupting other players.",
	label = "Spamming",
}, {
	id = "You are banned from this server for evading a previous punishment.",
	label = "Ban evasion",
} }
local GLOBAL_BAN_REASONS = { {
	id = "You are banned from Astral Forge.",
	label = "Experience ban",
}, {
	id = "You are banned from Astral Forge for exploiting or using unauthorized software.",
	label = "Exploiting",
}, {
	id = "You are banned from Astral Forge for harassment or inappropriate behavior.",
	label = "Harassment",
}, {
	id = "You are banned from Astral Forge for spamming or disrupting other players.",
	label = "Spamming",
}, {
	id = "You are banned from Astral Forge for evading a previous punishment.",
	label = "Ban evasion",
} }
local function reasonsFor(command, category)
	if command == "Kick" then
		return KICK_REASONS
	end
	if command == "ServerBan" then
		return SERVER_BAN_REASONS
	end
	if command == "GlobalBan" then
		return GLOBAL_BAN_REASONS
	end
	local preferred = if category == "Troll" then "Troll / joke" elseif category == "Moderation" then "Moderation action" elseif category == "Resets" then "Owner gameplay administration" else "Playtest grant"
	local ranked = {}
	for _, entry in ADMIN_REASONS do
		if entry.id == preferred then
			table.insert(ranked, entry)
		end
	end
	for _, entry in ADMIN_REASONS do
		if entry.id ~= preferred then
			table.insert(ranked, entry)
		end
	end
	return ranked
end
local NONE = {
	amountLabel = "",
	optionLabel = "",
	amountChoices = {},
	optionChoices = {},
	defaultAmount = "1",
	defaultOption = "",
	usesAmount = false,
	usesOption = false,
	overridesTarget = false,
}
local function pick(id, label, icon)
	return if icon ~= nil then {
		id = id,
		label = label,
		icon = icon,
	} else {
		id = id,
		label = label,
	}
end
local function amountList(values, suffix, icon)
	local choices = {}
	for _, value in values do
		local _arg0 = pick(value, `{value} {suffix}`, icon)
		table.insert(choices, _arg0)
	end
	return choices
end
local function namedAmounts(entries, icon)
	local choices = {}
	for _, entry in entries do
		local _arg0 = pick(entry.id, entry.label, icon)
		table.insert(choices, _arg0)
	end
	return choices
end
local FLUX = namedAmounts({ {
	id = "1000",
	label = "1,000 flux",
}, {
	id = "10000",
	label = "10,000 flux",
}, {
	id = "100000",
	label = "100,000 flux",
}, {
	id = "1000000",
	label = "1 million flux",
}, {
	id = "1000000000",
	label = "1 billion flux",
}, {
	id = "1e12",
	label = "1 trillion flux",
}, {
	id = "1e15",
	label = "1 quadrillion flux",
}, {
	id = "1e308",
	label = "MAX flux",
} }, "Flux")
local CORES = namedAmounts({ {
	id = "1",
	label = "1 core",
}, {
	id = "10",
	label = "10 cores",
}, {
	id = "25",
	label = "25 cores",
}, {
	id = "100",
	label = "100 cores",
}, {
	id = "1000",
	label = "1,000 cores",
}, {
	id = "10000",
	label = "10,000 cores",
} }, "Core")
local DUST = namedAmounts({ {
	id = "100",
	label = "100 stardust",
}, {
	id = "1000",
	label = "1,000 stardust",
}, {
	id = "10000",
	label = "10,000 stardust",
}, {
	id = "100000",
	label = "100,000 stardust",
}, {
	id = "1000000",
	label = "1 million stardust",
} }, "Dust")
local COUNTS = amountList({ "1", "5", "10", "25", "50", "100" }, "")
local KEYS = amountList({ "1", "5", "10", "25", "50", "100" }, "keys", "Crate")
local RELICS = amountList({ "1", "2", "3", "5", "10" }, "relics", "Inventory")
local XP = namedAmounts({ {
	id = "100",
	label = "100 XP",
}, {
	id = "1000",
	label = "1,000 XP",
}, {
	id = "10000",
	label = "10,000 XP",
}, {
	id = "100000",
	label = "100,000 XP",
}, {
	id = "1000000",
	label = "1 million XP",
} }, "StarGrid")
local REBIRTHS = namedAmounts({ {
	id = "1",
	label = "1 rebirth",
}, {
	id = "5",
	label = "5 rebirths",
}, {
	id = "10",
	label = "10 rebirths",
}, {
	id = "25",
	label = "25 rebirths",
}, {
	id = "100",
	label = "100 rebirths",
}, {
	id = "1000",
	label = "1,000 rebirths",
} }, "Rebirth")
local DURATION = namedAmounts({ {
	id = "3",
	label = "3 seconds",
}, {
	id = "6",
	label = "6 seconds",
}, {
	id = "10",
	label = "10 seconds",
}, {
	id = "15",
	label = "15 seconds",
}, {
	id = "20",
	label = "20 seconds",
} }, "Timer")
local SERVER_BAN = namedAmounts({ {
	id = "0",
	label = "This server session",
}, {
	id = "600",
	label = "10 minutes",
}, {
	id = "3600",
	label = "1 hour",
}, {
	id = "21600",
	label = "6 hours",
}, {
	id = "86400",
	label = "24 hours",
}, {
	id = "604800",
	label = "7 days",
} }, "Lock")
local GLOBAL_BAN = namedAmounts({ {
	id = "86400",
	label = "1 day",
}, {
	id = "259200",
	label = "3 days",
}, {
	id = "604800",
	label = "7 days",
}, {
	id = "1209600",
	label = "14 days",
}, {
	id = "2592000",
	label = "30 days",
}, {
	id = "Permanent",
	label = "Permanent",
} }, "Lock")
local CLOWNS = { pick("CLOWN", "CLOWN"), pick("JESTER", "JESTER"), pick("HONK", "HONK"), pick("GOOFBALL", "GOOFBALL"), pick("ADMIN'S FAVORITE", "ADMIN'S FAVORITE") }
local FALLBACK_CRATES = { pick("ForgeCrate", "Forge Crate", "Crate"), pick("CrystalCrate", "Crystal Crate", "Crate"), pick("HorizonCrate", "Horizon Crate", "Crate"), pick("NebulaCrate", "Nebula Crate", "Crate"), pick("OrbitCrate", "Orbit Crate", "Crate"), pick("SingularityCrate", "Singularity Crate", "Crate"), pick("EchoCrate", "Echo Crate", "Crate") }
local FALLBACK_BOOSTS = { pick("DomainSurge", "Domain Surge", "Boost"), pick("Overdrive", "Overdrive", "Boost"), pick("Hyperdrive", "Hyperdrive", "Boost"), pick("VaultSurge", "Vault Surge", "Boost") }
local function pack(amountChoices, amountLabel, optionChoices, optionLabel, overridesTarget)
	if overridesTarget == nil then
		overridesTarget = false
	end
	local _object = {
		amountLabel = amountLabel,
	}
	local _left = "optionLabel"
	local _condition = optionLabel
	if _condition == nil then
		_condition = ""
	end
	_object[_left] = _condition
	_object.amountChoices = amountChoices
	_object.optionChoices = optionChoices or {}
	local _left_1 = "defaultAmount"
	local _result = amountChoices[1]
	if _result ~= nil then
		_result = _result.id
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = "1"
	end
	_object[_left_1] = _condition_1
	local _left_2 = "defaultOption"
	local _result_1 = optionChoices
	if _result_1 ~= nil then
		_result_1 = _result_1[1]
		if _result_1 ~= nil then
			_result_1 = _result_1.id
		end
	end
	local _condition_2 = _result_1
	if _condition_2 == nil then
		_condition_2 = ""
	end
	_object[_left_2] = _condition_2
	_object.usesAmount = #amountChoices > 0
	local _left_3 = "usesOption"
	local _result_2 = optionChoices
	if _result_2 ~= nil then
		_result_2 = #_result_2
	end
	local _condition_3 = _result_2
	if _condition_3 == nil then
		_condition_3 = 0
	end
	_object[_left_3] = _condition_3 > 0
	_object.overridesTarget = overridesTarget
	return _object
end
local function crateChoices(config)
	local _crates = config
	if _crates ~= nil then
		_crates = _crates.Items
		if _crates ~= nil then
			_crates = _crates.Crates
		end
	end
	local crates = _crates
	if crates == nil or #crates == 0 then
		return FALLBACK_CRATES
	end
	local choices = {}
	for _, crate in crates do
		local _arg0 = pick(crate.Id, crate.Name, "Crate")
		table.insert(choices, _arg0)
	end
	return choices
end
local function boostChoices(config)
	local _boosts = config
	if _boosts ~= nil then
		_boosts = _boosts.Boosts
	end
	local boosts = _boosts
	if boosts == nil then
		return FALLBACK_BOOSTS
	end
	local choices = {}
	for id, boost in pairs(boosts) do
		local _arg0 = pick(id, boost.Name, "Boost")
		table.insert(choices, _arg0)
	end
	if #choices == 0 then
		return FALLBACK_BOOSTS
	end
	return choices
end
local function relicChoices(config)
	local _definitions = config
	if _definitions ~= nil then
		_definitions = _definitions.Items
		if _definitions ~= nil then
			_definitions = _definitions.Definitions
		end
	end
	local definitions = _definitions
	if definitions == nil or #definitions == 0 then
		return { pick("IonCoupler", "Ion Coupler", "Inventory") }
	end
	local choices = {}
	for _, definition in definitions do
		local _arg0 = pick(definition.Id, definition.Name, "Inventory")
		table.insert(choices, _arg0)
	end
	return choices
end
local function zoneChoices(config)
	local _zones = config
	if _zones ~= nil then
		_zones = _zones.Zones
	end
	local zones = _zones
	if zones == nil or #zones == 0 then
		return namedAmounts({ {
			id = "1",
			label = "World 1",
		}, {
			id = "2",
			label = "World 2",
		}, {
			id = "3",
			label = "World 3",
		} }, "World")
	end
	local choices = {}
	for _, zone in zones do
		local _arg0 = pick(tostring(zone.Id), zone.Name, "World")
		table.insert(choices, _arg0)
	end
	return choices
end
local function banChoices(banned)
	local choices = {}
	for _, entry in banned do
		local window = if entry.Until < 0 then "permanent" elseif entry.Until == 0 then "this server" else "timed"
		local _arg0 = {
			id = tostring(entry.UserId),
			label = `{entry.Name}  ·  {entry.Scope} {window}`,
			icon = "Lock",
		}
		table.insert(choices, _arg0)
	end
	return choices
end
local function fieldsFor(command, config, banned)
	if command == "GrantFlux" then
		return pack(FLUX, "How much flux")
	end
	if command == "GrantCores" or command == "SetCores" then
		return pack(CORES, "How many cores")
	end
	if command == "GrantStardust" or command == "SetStardust" then
		return pack(DUST, "How much stardust")
	end
	if command == "GrantRebirths" or command == "SetRebirths" then
		return pack(REBIRTHS, "How many rebirths")
	end
	if command == "GrantDomainEssence" or command == "GrantItemEssence" or command == "GrantAnomalyFragments" or command == "GrantSignals" or command == "GrantStreakShields" or command == "GrantContinuumRanks" or command == "GrantAnomalyCharge" or command == "GrantAnomalyStabilizations" or command == "GrantFreeSpins" or command == "GrantAllCrateKeys" or command == "GrantAllBoosts" or command == "GrantSkillPoints" or command == "GrantEchoCharge" then
		return pack(COUNTS, "How many")
	end
	if command == "GrantCommandXP" or command == "GrantSeasonXP" then
		return pack(XP, "How much XP")
	end
	if command == "SetDomainRank" then
		return pack(amountList({ "0", "1", "5", "10", "25", "50" }, "rank", "Domain"), "Domain rank")
	end
	if command == "GrantEverything" then
		return pack(namedAmounts({ {
			id = "1000",
			label = "Starter owner bundle",
		}, {
			id = "1000000",
			label = "Large owner bundle",
		}, {
			id = "1e12",
			label = "Massive owner bundle",
		} }, "Gift"), "Bundle size")
	end
	if command == "GrantCrateKeys" or command == "GrantPity" then
		return pack(KEYS, "How many", crateChoices(config), "Which crate")
	end
	if command == "GrantBoost" then
		return pack(COUNTS, "How many", boostChoices(config), "Which boost")
	end
	if command == "GrantRelic" then
		return pack(RELICS, "How many", relicChoices(config), "Which relic")
	end
	if command == "SetZone" then
		return pack(zoneChoices(config), "Unlock through")
	end
	if command == "ClownTitle" then
		return pack(DURATION, "How long", CLOWNS, "Splash text")
	end
	if command == "Blind" or command == "Jumpscare" or command == "ConfettiStorm" or command == "LoadingForever" or command == "BlueScreen" or command == "LowBattery" or command == "UpdateForced" or (string.find(command, "Hud")) ~= nil or (string.find(command, "Fake")) ~= nil then
		return pack(DURATION, "How long")
	end
	if command == "Kick" then
		return NONE
	end
	if command == "ServerBan" then
		return pack(SERVER_BAN, "How long")
	end
	if command == "GlobalBan" then
		return pack(GLOBAL_BAN, "How long")
	end
	if command == "Unban" then
		local choices = banChoices(banned or {})
		return pack(choices, "Who to unban", nil, nil, true)
	end
	return NONE
end
return {
	reasonsFor = reasonsFor,
	fieldsFor = fieldsFor,
	ADMIN_REASONS = ADMIN_REASONS,
}
end

-- ======================================================================
-- Module: clientStore   (merged from clientStore.luau, 746 lines)
-- ======================================================================
__defs["clientStore"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Rodux = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].rodux)
local EMPTY_BOOT_STATUS = {
	marks = {
		bridge = false,
		remotes = false,
		state = false,
		audio = false,
		assets = false,
		fonts = false,
		modules = false,
		shell = false,
		mail = false,
		research = false,
		forge = false,
		trade = false,
		boosts = false,
		settings = false,
		mobile = false,
	},
	ready = false,
	progress = 0,
	reducedMotion = false,
}
local INITIAL_STATE = {
	navigation = {
		page = "Overview",
	},
	boot = {
		status = EMPTY_BOOT_STATUS,
		visible = true,
	},
	domain = {
		busy = false,
	},
}
local function optimisticSession(session, action, payload, gameVersion)
	if session == nil then
		return nil
	end
	if action == "SetSetting" then
		local _object = table.clone(session.Settings)
		setmetatable(_object, nil)
		local settings = _object
		local batch = payload.Values
		if type(batch) == "table" then
			for key, value in pairs(batch) do
				if type(value) == "number" then
					settings[key] = math.clamp(value, 0, 1)
				end
			end
			local _object_1 = table.clone(session)
			setmetatable(_object_1, nil)
			_object_1.Settings = settings
			return _object_1
		end
		local _key = payload.Key
		local _condition = type(_key) == "string"
		if _condition then
			local _value = payload.Value
			_condition = type(_value) == "number"
		end
		if _condition then
			settings[payload.Key] = payload.Value
			local _object_1 = table.clone(session)
			setmetatable(_object_1, nil)
			_object_1.Settings = settings
			return _object_1
		end
	end
	local _condition = action == "SetMobileLayout"
	if _condition then
		local _values = payload.Values
		_condition = type(_values) == "table"
	end
	if _condition then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Settings"
		local _object_1 = table.clone(session.Settings)
		setmetatable(_object_1, nil)
		for _k, _v in (payload.Values) do
			_object_1[_k] = _v
		end
		_object[_left] = _object_1
		return _object
	end
	local _condition_1 = action == "SetTutorialStep"
	if _condition_1 then
		local _step = payload.Step
		_condition_1 = type(_step) == "number"
	end
	if _condition_1 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.TutorialStep = math.max(1, math.floor(payload.Step))
		_object[_left] = _object_1
		return _object
	end
	if action == "ReplayTutorial" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.TutorialDone = false
		_object_1.TutorialStep = 1
		_object[_left] = _object_1
		return _object
	end
	if action == "CompleteTutorial" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.TutorialDone = true
		_object[_left] = _object_1
		return _object
	end
	if action == "DismissRelease" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		local _left_1 = "LastSeenVersion"
		local _condition_2 = gameVersion
		if _condition_2 == nil then
			_condition_2 = session.Game.Version
		end
		_object_1[_left_1] = _condition_2
		_object[_left] = _object_1
		return _object
	end
	if action == "OpenRelease" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Flags"
		local _object_1 = table.clone(session.Flags)
		setmetatable(_object_1, nil)
		_object_1.LastSeenVersion = ""
		_object[_left] = _object_1
		return _object
	end
	local _condition_2 = action == "ReadStoryChapter"
	if _condition_2 then
		local _id = payload.Id
		_condition_2 = type(_id) == "string"
		if _condition_2 then
			_condition_2 = session.Story ~= nil
		end
	end
	if _condition_2 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Story"
		local _exp = session.Story
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(chapter)
			local _result
			if chapter.Id == payload.Id then
				local _object_1 = table.clone(chapter)
				setmetatable(_object_1, nil)
				_object_1.Read = true
				_result = _object_1
			else
				_result = chapter
			end
			return _result
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		_object[_left] = _newValue
		return _object
	end
	local _condition_3 = action == "ReadMail"
	if _condition_3 then
		local _id = payload.Id
		_condition_3 = type(_id) == "string"
		if _condition_3 then
			_condition_3 = session.Mailbox ~= nil
		end
	end
	if _condition_3 then
		local newlyRead = false
		local _exp = session.Mailbox.Messages
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(message)
			if message.Id ~= payload.Id or message.Read then
				return message
			end
			newlyRead = true
			local _object = table.clone(message)
			setmetatable(_object, nil)
			_object.Read = true
			return _object
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local messages = _newValue
		local _object = table.clone(session)
		setmetatable(_object, nil)
		_object.Mailbox = {
			Messages = messages,
			Unread = math.max(0, session.Mailbox.Unread - (if newlyRead then 1 else 0)),
		}
		return _object
	end
	local _condition_4 = action == "SetAutoForge" and session.AutoForge ~= nil
	if _condition_4 then
		local _enabled = payload.Enabled
		_condition_4 = type(_enabled) == "boolean"
		if _condition_4 then
			local _machineId = payload.MachineId
			_condition_4 = type(_machineId) == "string"
			if _condition_4 then
				local _reserve = payload.Reserve
				_condition_4 = type(_reserve) == "number"
			end
		end
	end
	if _condition_4 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "AutoForge"
		local _object_1 = table.clone(session.AutoForge)
		setmetatable(_object_1, nil)
		_object_1.Enabled = payload.Enabled
		_object_1.MachineId = payload.MachineId
		_object_1.Reserve = payload.Reserve
		_object[_left] = _object_1
		return _object
	end
	local _condition_5 = action == "RouteLabPower" and session.Lab ~= nil
	if _condition_5 then
		local _channel = payload.Channel
		_condition_5 = type(_channel) == "string"
		if _condition_5 then
			local _delta = payload.Delta
			_condition_5 = type(_delta) == "number"
		end
	end
	if _condition_5 then
		local _object = table.clone(session.Lab.Routing)
		setmetatable(_object, nil)
		local routing = _object
		local _condition_6 = routing[payload.Channel]
		if _condition_6 == nil then
			_condition_6 = 0
		end
		local current = _condition_6
		local wanted = math.floor(payload.Delta)
		local actual = if wanted > 0 then math.min(wanted, session.Lab.AvailableCells) else -math.min(-wanted, current)
		routing[payload.Channel] = math.max(0, current + actual)
		local _object_1 = table.clone(session)
		setmetatable(_object_1, nil)
		local _left = "Lab"
		local _object_2 = table.clone(session.Lab)
		setmetatable(_object_2, nil)
		_object_2.Routing = routing
		_object_2.AvailableCells = math.clamp(session.Lab.AvailableCells - actual, 0, session.Lab.TotalCells)
		_object_1[_left] = _object_2
		return _object_1
	end
	local _condition_6 = action == "SetAnomalyChannel" and session.Anomaly ~= nil
	if _condition_6 then
		local _id = payload.Id
		_condition_6 = type(_id) == "string"
	end
	if _condition_6 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Anomaly"
		local _object_1 = table.clone(session.Anomaly)
		setmetatable(_object_1, nil)
		_object_1.Channel = payload.Id
		_object[_left] = _object_1
		return _object
	end
	local _condition_7 = action == "ClaimAnomalyDirective" and session.Anomaly ~= nil
	if _condition_7 then
		local _id = payload.Id
		_condition_7 = type(_id) == "string"
	end
	if _condition_7 then
		local changed = false
		local _exp = session.Anomaly.Directives
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(directive)
			if directive.Id ~= payload.Id or directive.Claimed or directive.Progress < directive.Target then
				return directive
			end
			changed = true
			local _object = table.clone(directive)
			setmetatable(_object, nil)
			_object.Claimed = true
			return _object
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local directives = _newValue
		local _result
		if changed then
			local _object = table.clone(session)
			setmetatable(_object, nil)
			local _left = "Anomaly"
			local _object_1 = table.clone(session.Anomaly)
			setmetatable(_object_1, nil)
			_object_1.Directives = directives
			_object[_left] = _object_1
			_result = _object
		else
			_result = session
		end
		return _result
	end
	local _condition_8 = action == "ClaimAnomalyMilestone" and session.Anomaly ~= nil
	if _condition_8 then
		local _tier = payload.Tier
		_condition_8 = type(_tier) == "number"
	end
	if _condition_8 then
		local anomaly = session.Anomaly
		local changed = false
		local _exp = anomaly.Milestones
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp)
		local _callback = function(milestone)
			if milestone.Tier ~= payload.Tier or milestone.Claimed or anomaly.Stabilizations < milestone.Required then
				return milestone
			end
			changed = true
			local _object = table.clone(milestone)
			setmetatable(_object, nil)
			_object.Claimed = true
			return _object
		end
		for _k, _v in _exp do
			_newValue[_k] = _callback(_v, _k - 1, _exp)
		end
		-- ▲ ReadonlyArray.map ▲
		local milestones = _newValue
		local _result
		if changed then
			local _object = table.clone(session)
			setmetatable(_object, nil)
			local _left = "Anomaly"
			local _object_1 = table.clone(anomaly)
			setmetatable(_object_1, nil)
			_object_1.Milestones = milestones
			_object[_left] = _object_1
			_result = _object
		else
			_result = session
		end
		return _result
	end
	if action == "CollectVault" then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		_object.Vault = 0
		return _object
	end
	local _condition_9 = action == "SelectZone"
	if _condition_9 then
		local _id = payload.Id
		_condition_9 = type(_id) == "number"
	end
	if _condition_9 then
		local _object = table.clone(session)
		setmetatable(_object, nil)
		_object.CurrentZone = math.max(1, math.floor(payload.Id))
		return _object
	end
	local _condition_10 = action == "EquipTitle"
	if _condition_10 then
		local _id = payload.Id
		_condition_10 = type(_id) == "string"
		if _condition_10 then
			_condition_10 = session.Command ~= nil
		end
	end
	if _condition_10 then
		local _exp = session.Command.Titles
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(title)
			return title.Id == payload.Id
		end
		local _result
		for _i, _v in _exp do
			if _callback(_v, _i - 1, _exp) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local selected = _result
		if selected == nil or not selected.Unlocked or selected.Equipped then
			return session
		end
		local _object = table.clone(session)
		setmetatable(_object, nil)
		local _left = "Command"
		local _object_1 = table.clone(session.Command)
		setmetatable(_object_1, nil)
		local _left_1 = "Titles"
		local _exp_1 = session.Command.Titles
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_1)
		local _callback_1 = function(title)
			local _object_2 = table.clone(title)
			setmetatable(_object_2, nil)
			_object_2.Equipped = title.Id == payload.Id
			return _object_2
		end
		for _k, _v in _exp_1 do
			_newValue[_k] = _callback_1(_v, _k - 1, _exp_1)
		end
		-- ▲ ReadonlyArray.map ▲
		_object_1[_left_1] = _newValue
		_object[_left] = _object_1
		return _object
	end
	return session
end
local function clientReducer(state, action)
	if state == nil then
		state = INITIAL_STATE
	end
	local _exp = action.type
	repeat
		if _exp == "session/snapshot" then
			if state.session ~= nil then
				if action.snapshot.Revision < state.session.Revision then
					return state
				end
				if action.snapshot.Revision == state.session.Revision and action.snapshot.SnapshotId < state.session.SnapshotId then
					return state
				end
			end
			local _object = table.clone(state)
			setmetatable(_object, nil)
			_object.session = action.snapshot
			_object.visit = action.snapshot.Visit
			return _object
		end
		if _exp == "session/patch" then
			if state.session == nil then
				return state
			end
			-- Reject stale patches that carry an older Revision/SnapshotId than the live
			-- session (e.g. LeaveGuild cleanup arriving after a newer pushState snapshot).
			local patch = action.patch
			if type(patch) == "table" then
				local patchRevision = tonumber(patch.Revision)
				local patchSnapshot = tonumber(patch.SnapshotId)
				if patchRevision ~= nil and patchRevision < state.session.Revision then
					return state
				end
				if
					patchRevision ~= nil
					and patchRevision == state.session.Revision
					and patchSnapshot ~= nil
					and patchSnapshot < state.session.SnapshotId
				then
					return state
				end
			end
			local _object = table.clone(state)
			setmetatable(_object, nil)
			local _left = "session"
			local _object_1 = table.clone(state.session)
			setmetatable(_object_1, nil)
			for _k, _v in action.patch do
				_object_1[_k] = _v
			end
			_object[_left] = _object_1
			return _object
		end
		if _exp == "session/optimistic" then
			local session = optimisticSession(state.session, action.action, action.payload, action.gameVersion)
			local _result
			if session == state.session then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				_object.session = session
				_result = _object
			end
			return _result
		end
		if _exp == "session/visit" then
			local _result
			if state.visit == action.visit then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				_object.visit = action.visit
				_result = _object
			end
			return _result
		end
		if _exp == "navigation/open" then
			local _result
			if state.navigation.page == action.page then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				_object.navigation = {
					page = action.page,
				}
				_result = _object
			end
			return _result
		end
		if _exp == "boot/status" then
			local _result
			if state.boot.status == action.status then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "boot"
				local _object_1 = table.clone(state.boot)
				setmetatable(_object_1, nil)
				_object_1.status = action.status
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "boot/visible" then
			local _result
			if state.boot.visible == action.visible then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "boot"
				local _object_1 = table.clone(state.boot)
				setmetatable(_object_1, nil)
				_object_1.visible = action.visible
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "domain/overlay" then
			local _result
			if state.domain.overlay == action.overlay then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "domain"
				local _object_1 = table.clone(state.domain)
				setmetatable(_object_1, nil)
				_object_1.overlay = action.overlay
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "domain/busy" then
			local _result
			if state.domain.busy == action.busy then
				_result = state
			else
				local _object = table.clone(state)
				setmetatable(_object, nil)
				local _left = "domain"
				local _object_1 = table.clone(state.domain)
				setmetatable(_object_1, nil)
				_object_1.busy = action.busy
				_object[_left] = _object_1
				_result = _object
			end
			return _result
		end
		if _exp == "runtime/reset" then
			return INITIAL_STATE
		end
		return state
	until true
end
local activeClientStore
local ClientActions = {
	setSnapshot = function(snapshot)
		return {
			type = "session/snapshot",
			snapshot = snapshot,
		}
	end,
	patchSession = function(patch)
		return {
			type = "session/patch",
			patch = patch,
		}
	end,
	applyOptimistic = function(action, payload, gameVersion)
		return {
			type = "session/optimistic",
			action = action,
			payload = payload,
			gameVersion = gameVersion,
		}
	end,
	setVisit = function(visit)
		return {
			type = "session/visit",
			visit = visit,
		}
	end,
	navigate = function(page)
		return {
			type = "navigation/open",
			page = page,
		}
	end,
	setBootStatus = function(status)
		return {
			type = "boot/status",
			status = status,
		}
	end,
	setBootVisible = function(visible)
		return {
			type = "boot/visible",
			visible = visible,
		}
	end,
	setDomainOverlay = function(overlay)
		return {
			type = "domain/overlay",
			overlay = overlay,
		}
	end,
	setDomainBusy = function(busy)
		return {
			type = "domain/busy",
			busy = busy,
		}
	end,
	reset = function()
		return {
			type = "runtime/reset",
		}
	end,
}
local function createClientStore()
	local _result = activeClientStore
	if _result ~= nil then
		_result:destruct()
	end
	activeClientStore = Rodux.Store.new(clientReducer, INITIAL_STATE)
	return activeClientStore
end
local function getActiveClientStore()
	return activeClientStore
end
local function destroyClientStore(store)
	if activeClientStore == store then
		activeClientStore = nil
	end
	store:destruct()
end
local ClientStoreContext = React.createContext(nil)
local function ClientStoreProvider(_param)
	local store = _param.store
	local children = _param.children
	return React.createElement(ClientStoreContext.Provider, {
		value = store,
	}, children)
end
local function useClientStore()
	local store = React.useContext(ClientStoreContext)
	if store == nil then
		error("ClientStoreProvider is missing", 2)
	end
	return store
end
local function useClientDispatch()
	local store = useClientStore()
	return React.useCallback(function(action)
		return store:dispatch(action)
	end, { store })
end
local function useClientSelector(selector, equal)
	if equal == nil then
		equal = function(left, right)
			return left == right
		end
	end
	local store = useClientStore()
	local selectorRef = React.useRef(selector)
	local equalRef = React.useRef(equal)
	selectorRef.current = selector
	equalRef.current = equal
	local selected, setSelected = React.useState(function()
		return selector(store:getState())
	end)
	local selectedRef = React.useRef(selected)
	selectedRef.current = selected
	React.useEffect(function()
		local sync = function(nextState)
			local selectedNext = selectorRef.current(nextState)
			if equalRef.current(selectedRef.current, selectedNext) then
				return nil
			end
			selectedRef.current = selectedNext
			setSelected(selectedNext)
		end
		sync(store:getState())
		local connection = store.changed:connect(sync)
		return function()
			return connection:disconnect()
		end
	end, { store })
	return selected
end
return {
	createClientStore = createClientStore,
	getActiveClientStore = getActiveClientStore,
	destroyClientStore = destroyClientStore,
	ClientStoreProvider = ClientStoreProvider,
	useClientStore = useClientStore,
	useClientDispatch = useClientDispatch,
	useClientSelector = useClientSelector,
	ClientActions = ClientActions,
}
end

-- ======================================================================
-- Module: interaction   (merged from interaction.luau, 252 lines)
-- ======================================================================
__defs["interaction"] = function()
local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local hapticIntensity = 1
local motorGenerations = {}
-- HapticService only ever addresses gamepads. GetLastInputType returns Touch on a phone and
-- Keyboard/MouseButton1 on a desktop, and none of those are vibration targets — so routing
-- feedback through "whatever was last pressed" meant every haptic call died in a pcall, including
-- for players holding a controller on mobile. Resolve an actually-connected gamepad instead.
local GAMEPAD_INPUTS = { Enum.UserInputType.Gamepad1, Enum.UserInputType.Gamepad2, Enum.UserInputType.Gamepad3, Enum.UserInputType.Gamepad4 }
-- IsVibrationSupported is a round trip per call and the answer only changes when a controller is
-- plugged in or out, so cache it and drop the cache on those events.
-- Cache the actual usable motor set, not a single boolean. A controller's dual-motor rumble
-- (the classic Xbox-style Small/Large pair) doesn't guarantee both motors report supported on
-- every platform — hard-requiring one specific motor risks silently disabling haptics on
-- hardware that can vibrate through the other one. Drive whichever motors are actually there.
local RUMBLE_MOTORS = { Enum.VibrationMotor.Small, Enum.VibrationMotor.Large }
local vibrationSupport = {}
local function isGamepadInput(input)
	for _, candidate in GAMEPAD_INPUTS do
		if candidate == input then
			return true
		end
	end
	return false
end
local gamepadWatchInstalled = false
local function watchGamepads()
	if gamepadWatchInstalled then
		return nil
	end
	gamepadWatchInstalled = true
	UserInputService.GamepadConnected:Connect(function(pad)
		local _pad = pad
		-- ▼ Map.delete ▼
		local _valueExisted = vibrationSupport[_pad] ~= nil
		vibrationSupport[_pad] = nil
		-- ▲ Map.delete ▲
		return _valueExisted
	end)
	UserInputService.GamepadDisconnected:Connect(function(pad)
		local _pad = pad
		vibrationSupport[_pad] = nil
		local _pad_1 = pad
		motorGenerations[_pad_1] = nil
	end)
end
local function motorsFor(input)
	local _input = input
	local cached = vibrationSupport[_input]
	if cached ~= nil then
		return cached
	end
	watchGamepads()
	local vibrationOk, vibrationSupported = pcall(function()
		return HapticService:IsVibrationSupported(input)
	end)
	local resolved = {}
	if vibrationOk and vibrationSupported == true then
		local usable = {}
		for _, motor in RUMBLE_MOTORS do
			local motorOk, motorSupported = pcall(function()
				return HapticService:IsMotorSupported(input, motor)
			end)
			if motorOk and motorSupported == true then
				table.insert(usable, motor)
			end
		end
		resolved = usable
	end
	local _input_1 = input
	local _resolved = resolved
	vibrationSupport[_input_1] = _resolved
	return resolved
end
local function supportsVibration(input)
	return #motorsFor(input) > 0
end
-- The gamepad that should receive feedback: the one the player last actually used when that is a
-- gamepad, otherwise the first connected pad that can vibrate. Undefined means "no haptics here",
-- which is the normal answer on a bare touchscreen.
local function hapticTarget()
	local last = UserInputService:GetLastInputType()
	if isGamepadInput(last) then
		return if supportsVibration(last) then last else nil
	end
	-- Only pay for the connected-gamepad scan when a pad is actually attached — on a plain phone
	-- or a mouse-and-keyboard desktop this short-circuits before any service round trip.
	if not UserInputService.GamepadEnabled then
		return nil
	end
	local ok, connected = pcall(function()
		return UserInputService:GetConnectedGamepads()
	end)
	if not ok or connected == nil then
		return nil
	end
	for _, pad in connected do
		if supportsVibration(pad) then
			return pad
		end
	end
	return nil
end
local function setHapticIntensity(value)
	hapticIntensity = math.clamp(value, 0, 1)
	if hapticIntensity <= 0.02 then
		for input in motorGenerations do
			for _, motor in motorsFor(input) do
				pcall(function()
					return HapticService:SetMotor(input, motor, 0)
				end)
			end
		end
		table.clear(motorGenerations)
	end
end
local function safePulse(input, strength, seconds)
	if hapticIntensity <= 0.02 then
		return nil
	end
	local motors = motorsFor(input)
	if #motors == 0 then
		return nil
	end
	local level = math.clamp(strength * hapticIntensity, 0, 1)
	local startedAny = false
	for _, motor in motors do
		local startOk = pcall(function()
			return HapticService:SetMotor(input, motor, level)
		end)
		if startOk then
			startedAny = true
		end
	end
	if not startedAny then
		return nil
	end
	local _input = input
	local _condition = motorGenerations[_input]
	if _condition == nil then
		_condition = 0
	end
	local generation = _condition + 1
	local _input_1 = input
	motorGenerations[_input_1] = generation
	task.delay(math.max(0.01, seconds), function()
		local _input_2 = input
		if motorGenerations[_input_2] ~= generation then
			return nil
		end
		local _input_3 = input
		motorGenerations[_input_3] = nil
		for _, motor in motors do
			pcall(function()
				return HapticService:SetMotor(input, motor, 0)
			end)
		end
	end)
end
local function pulse(strength, seconds)
	if hapticIntensity <= 0.02 then
		return nil
	end
	local input = hapticTarget()
	if input == nil then
		return nil
	end
	task.defer(function()
		return safePulse(input, strength, seconds)
	end)
end
local lastDesktopResult = nil
local function usesDesktopStructure(width, height)
	local hasPointerHardware = UserInputService.KeyboardEnabled or UserInputService.MouseEnabled
	local preferred = UserInputService.PreferredInput
	local touch = UserInputService.TouchEnabled

	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local screenWidth = if width ~= nil then width else viewport.X
	local screenHeight = if height ~= nil then height else viewport.Y

	-- Strict physical screen boundary: anything under 840px wide or 500px tall cannot fit a desktop sidebar
	local result = false
	if screenWidth >= 840 and screenHeight >= 500 then
		if not touch then
			if preferred == Enum.PreferredInput.KeyboardAndMouse then
				result = true
			elseif preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
				result = true
			else
				result = hasPointerHardware
			end
		else
			if preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
				result = true
			else
				result = screenWidth >= 1100 and screenHeight >= 650
			end
		end
	end

	-- Hysteresis: avoid flipping the entire UI when the window hovers near the boundary.
	if lastDesktopResult ~= nil and result ~= lastDesktopResult then
		if lastDesktopResult then
			-- currently desktop -> mobile; require a bigger drop to switch
			if screenWidth < 780 or screenHeight < 470 then
				lastDesktopResult = false
			else
				return lastDesktopResult
			end
		else
			-- currently mobile -> desktop; require a clear jump to switch
			if screenWidth >= 840 and screenHeight >= 500 then
				lastDesktopResult = true
			else
				return lastDesktopResult
			end
		end
	end
	lastDesktopResult = result
	return result
end
local function isTouchDevice()
	return UserInputService.TouchEnabled and not usesDesktopStructure()
end
local function isGamepadDevice()
	local preferred = UserInputService.PreferredInput
	return preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad
end
local InteractionFeedback = {
	tap = function()
		return pulse(0.22, 0.045)
	end,
	tick = function()
		return pulse(0.1, 0.025)
	end,
	reward = function()
		return pulse(0.5, 0.11)
	end,
	confirm = function()
		return pulse(0.32, 0.06)
	end,
}
return {
	setHapticIntensity = setHapticIntensity,
	usesDesktopStructure = usesDesktopStructure,
	isTouchDevice = isTouchDevice,
	isGamepadDevice = isGamepadDevice,
	InteractionFeedback = InteractionFeedback,
}
end

-- ======================================================================
-- Module: navRouteTable   (merged from navRouteTable.luau, 137 lines)
-- ======================================================================
__defs["navRouteTable"] = function()
-- Pure nav route tables (ids / labels / icons). Accent colors stay in appNav
-- so this module has no theme / Color3 dependency and can be required under
-- Lune. PRIMARY + MORE match the shell rail; PAGE_ROUTES are the PageRouter
-- dispatch keys (Credits is nav-only / special chrome).

local NavRouteTable = {}

type RouteDef = {
	id: string,
	label: string,
	eyebrow: string,
	icon: string,
	accentKey: string,
}

local PRIMARY_ROUTES: { RouteDef } = {
	{ id = "Overview", label = "Overview", eyebrow = "Your vault", icon = "Overview", accentKey = "green" },
	{ id = "Workshop", label = "Workshop", eyebrow = "Buy machines", icon = "Forge", accentKey = "coral" },
	{ id = "Inventory", label = "Inventory", eyebrow = "Relics", icon = "Inventory", accentKey = "violet" },
	{ id = "Research", label = "Research", eyebrow = "Permanent bonuses", icon = "Research", accentKey = "cyan" },
	{ id = "Shop", label = "Shop", eyebrow = "Packs", icon = "Shop", accentKey = "mango" },
	{ id = "Settings", label = "Settings", eyebrow = "Options", icon = "Settings", accentKey = "violet" },
}

local MORE_ROUTES: { RouteDef } = {
	-- Grouped by what the player is doing: daily loops, progression, goals, social, meta.
	{ id = "Missions", label = "Missions", eyebrow = "Jobs", icon = "Mission", accentKey = "cyan" },
	{ id = "Rewards", label = "Rewards", eyebrow = "Dailies", icon = "Rewards", accentKey = "pink" },
	{ id = "Wheel", label = "Wheel", eyebrow = "Spin", icon = "Wheel", accentKey = "mango" },
	{ id = "Casino", label = "Casino", eyebrow = "Take a chance", icon = "Jackpot", accentKey = "coral" },
	{ id = "Bazaar", label = "Bazaar", eyebrow = "Bank and deals", icon = "Shop", accentKey = "mint" },
	{ id = "Boosts", label = "Boosts", eyebrow = "Power up", icon = "Boost", accentKey = "pink" },
	{ id = "Worlds", label = "Worlds", eyebrow = "Zones", icon = "World", accentKey = "mint" },
	{ id = "Lab", label = "Lab", eyebrow = "Orders", icon = "Lab", accentKey = "mint" },
	{ id = "Anomaly", label = "Shift Plan", eyebrow = "Do this", icon = "Reactor", accentKey = "pink" },
	{ id = "Continuum", label = "Next Rank", eyebrow = "Plan", icon = "Continuum", accentKey = "pink" },
	{ id = "StarGrid", label = "Star Grid", eyebrow = "Dust", icon = "StarGrid", accentKey = "mango" },
	{ id = "Echoes", label = "Echoes", eyebrow = "Keep", icon = "Wave", accentKey = "cyan" },
	{ id = "ForgePath", label = "Forge Path", eyebrow = "Upgrades", icon = "Forge", accentKey = "violet" },
	{ id = "Milestones", label = "Milestones", eyebrow = "Goals", icon = "Milestone", accentKey = "mango" },
	{ id = "Story", label = "Story", eyebrow = "Read", icon = "Story", accentKey = "mint" },
	{ id = "Command", label = "Command", eyebrow = "Crew", icon = "Command", accentKey = "cyan" },
	{ id = "Convergence", label = "Converge", eyebrow = "Co-op", icon = "Domain", accentKey = "mango" },
	{ id = "Guild", label = "Guild", eyebrow = "Hall", icon = "Crew", accentKey = "violet" },
	{ id = "Crew", label = "Crew", eyebrow = "Online", icon = "Crew", accentKey = "blue" },
	{ id = "Chat", label = "Chat", eyebrow = "Talk", icon = "Chat", accentKey = "mint" },
	{ id = "Mail", label = "Mail", eyebrow = "Inbox", icon = "Mail", accentKey = "cyan" },
	{ id = "Trade", label = "Trade", eyebrow = "Swap", icon = "Send", accentKey = "mint" },
	{ id = "Leaderboards", label = "Ranks", eyebrow = "Top 25", icon = "Leaderboard", accentKey = "cyan" },
	{ id = "Credits", label = "Credits", eyebrow = "About", icon = "Credits", accentKey = "violet" },
	{ id = "Admin", label = "Admin", eyebrow = "Owner", icon = "Admin", accentKey = "coral" },
}

-- PageRouter PageContentInner dispatch keys (Credits / Chat / Admin use special chrome).
local PAGE_ROUTES: { string } = {
	"Overview",
	"Workshop",
	"Research",
	"StarGrid",
	"Echoes",
	"Continuum",
	"Convergence",
	"Lab",
	"Anomaly",
	"Worlds",
	"Missions",
	"Milestones",
	"Wheel",
	"Casino",
	"Bazaar",
	"Rewards",
	"Boosts",
	"Command",
	"Story",
	"Mail",
	"Chat",
	"Crew",
	"Guild",
	"Leaderboards",
	"Shop",
	"Inventory",
	"Trade",
	"Settings",
	"Admin",
	"ForgePath",
}

-- Sections of the desktop rail. Every nav route sits in exactly one group, so
-- grouping hides nothing: a closed group still shows its badge total.
type NavGroup = { key: string, label: string, routes: { string } }

local NAV_GROUPS: { NavGroup } = {
	{ key = "Home", label = "Home", routes = { "Overview", "Workshop", "Inventory", "Research", "Shop" } },
	{ key = "Daily", label = "Daily", routes = { "Missions", "Rewards", "Boosts", "Milestones", "Wheel" } },
	{ key = "Progress", label = "Progress", routes = { "Worlds", "Lab", "Anomaly", "Continuum", "StarGrid", "Echoes", "ForgePath", "Story" } },
	{ key = "Games", label = "Games & Deals", routes = { "Casino", "Bazaar" } },
	{ key = "Social", label = "Social", routes = { "Command", "Convergence", "Guild", "Crew", "Chat", "Mail", "Trade", "Leaderboards" } },
	{ key = "System", label = "System", routes = { "Settings", "Credits", "Admin" } },
}

local GROUP_OF: { [string]: string } = {}
for _, group in NAV_GROUPS do
	for _, id in group.routes do
		GROUP_OF[id] = group.key
	end
	table.freeze(group.routes)
	table.freeze(group)
end

local function indexById(routes: { RouteDef }): { [string]: RouteDef }
	local map = {}
	for _, route in routes do
		map[route.id] = route
	end
	return map
end

local PRIMARY_BY_ID = indexById(PRIMARY_ROUTES)
local MORE_BY_ID = indexById(MORE_ROUTES)
local ALL_BY_ID: { [string]: RouteDef } = {}
for id, route in PRIMARY_BY_ID do
	ALL_BY_ID[id] = route
end
for id, route in MORE_BY_ID do
	ALL_BY_ID[id] = route
end

local PAGE_SET: { [string]: boolean } = {}
for _, id in PAGE_ROUTES do
	PAGE_SET[id] = true
end

NavRouteTable.PRIMARY_ROUTES = table.freeze(PRIMARY_ROUTES)
NavRouteTable.MORE_ROUTES = table.freeze(MORE_ROUTES)
NavRouteTable.PAGE_ROUTES = table.freeze(PAGE_ROUTES)
NavRouteTable.NAV_GROUPS = table.freeze(NAV_GROUPS)

-- The rail group a page lives in (nil for pages that are not nav routes).
function NavRouteTable.groupOf(pageId: string): string?
	return GROUP_OF[pageId]
end

function NavRouteTable.find(pageId: string): RouteDef?
	return ALL_BY_ID[pageId]
end

function NavRouteTable.isNavRoute(pageId: string): boolean
	return ALL_BY_ID[pageId] ~= nil
end

function NavRouteTable.isPageRoute(pageId: string): boolean
	return PAGE_SET[pageId] == true
end

function NavRouteTable.allNavIds(): { string }
	local ids = table.create(#PRIMARY_ROUTES + #MORE_ROUTES)
	for _, route in PRIMARY_ROUTES do
		table.insert(ids, route.id)
	end
	for _, route in MORE_ROUTES do
		table.insert(ids, route.id)
	end
	return ids
end

return table.freeze(NavRouteTable)
end

-- ======================================================================
-- Module: appNav   (merged from appNav.luau, 495 lines)
-- ======================================================================
__defs["appNav"] = function()
-- appNav.ts
local scaledCost = __load("format").scaledCost
local gteFlux = __load("format").gteFlux
local Palette = __load("theme").Palette
local NavRouteTable = __load("navRouteTable")

local function withAccent(route)
	local accent = Palette[route.accentKey]
	if accent == nil then
		accent = Palette.green
	end
	return {
		id = route.id,
		label = route.label,
		eyebrow = route.eyebrow,
		icon = route.icon,
		accent = accent,
	}
end

local PRIMARY_NAV = table.create(#NavRouteTable.PRIMARY_ROUTES)
for index, route in NavRouteTable.PRIMARY_ROUTES do
	PRIMARY_NAV[index] = withAccent(route)
end
local MORE_NAV = table.create(#NavRouteTable.MORE_ROUTES)
for index, route in NavRouteTable.MORE_ROUTES do
	MORE_NAV[index] = withAccent(route)
end
local _array = {}
local _length = #_array
local _pRIMARY_NAVLength = #PRIMARY_NAV
table.move(PRIMARY_NAV, 1, _pRIMARY_NAVLength, _length + 1, _array)
_length += _pRIMARY_NAVLength
table.move(MORE_NAV, 1, #MORE_NAV, _length + 1, _array)
local NAV = _array
local AppHelpers
AppHelpers = {
	isPassiveRequest = function(self, action)
		local _condition = string.sub(action, 1, 3) == "Get"
		if not _condition then
			local _action = action
			_condition = table.find({ "SyncShop", "MeasureLatency", "ReportClientIntegrity", "ReportPerformance" }, _action) ~= nil
		end
		return _condition
	end,
	actionSignature = function(self, action, value)
		local fields = { "Id", "Key", "Index", "Code", "Channel", "Target", "Uid", "ChoiceId", "Slot", "Tier", "Level", "Role", "UserId", "MachineId" }
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(f)
			return value[f] ~= nil
		end
		local _length_1 = 0
		for _k, _v in fields do
			if _callback(_v, _k - 1, fields) == true then
				_length_1 += 1
				_newValue[_length_1] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#_newValue)
		local _callback_1 = function(f)
			return `{f}={tostring(value[f])}`
		end
		for _k, _v in _newValue do
			_newValue_1[_k] = _callback_1(_v, _k - 1, _newValue)
		end
		-- ▲ ReadonlyArray.map ▲
		local parts = _newValue_1
		return `{action}:{table.concat(parts, "|")}`
	end,
	pageAccent = function(self, page)
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(e)
			return e.id == page
		end
		local _result
		for _i, _v in NAV do
			if _callback(_v, _i - 1, NAV) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local entry = _result
		return if entry then entry.accent else Palette.green
	end,
	pageEntry = function(self, page)
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(e)
			return e.id == page
		end
		local _result
		for _i, _v in NAV do
			if _callback(_v, _i - 1, NAV) == true then
				_result = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local _condition = _result
		if not _condition then
			_condition = NAV[1]
		end
		return _condition
	end,
	boostEffectText = function(self, boost)
		if boost.Multiplier ~= nil and boost.CapacityMultiplier ~= nil then
			return `{boost.Multiplier}x output + {boost.CapacityMultiplier}x vault`
		end
		if boost.Multiplier ~= nil then
			return `{boost.Multiplier}x output`
		end
		if boost.CapacityMultiplier ~= nil then
			return `{boost.CapacityMultiplier}x vault capacity`
		end
		return "Temporary production perk"
	end,
	featureUnlocked = function(self, state, featureId)
		local _unlock = state.FeatureUnlocks
		if _unlock ~= nil then
			_unlock = _unlock[featureId]
		end
		local unlock = _unlock
		local _result = unlock
		if _result ~= nil then
			_result = _result.Unlocked
		end
		return _result ~= false
	end,
	navUnlocked = function(self, state, pageId, tutorialPage)
		if pageId == "Trade" then
			return true
		end
		local entry = AppHelpers:pageEntry(pageId)
		if entry.disabled then
			return false
		end
		local _lock = state.FeatureUnlocks
		if _lock ~= nil then
			_lock = _lock[pageId]
		end
		local lock = _lock
		local _result = lock
		if _result ~= nil then
			_result = _result.Unlocked
		end
		local unlocked = _result ~= false
		local _result_1 = state.Flags
		if _result_1 ~= nil then
			_result_1 = _result_1.TutorialDone
		end
		local _condition = _result_1 ~= true
		if _condition then
			_condition = tutorialPage == pageId
		end
		local tutorialOverride = _condition
		return unlocked or tutorialOverride
	end,
	filterNav = function(self, entries, state, tutorialPage)
		local visible = {}
		local seen = {}
		for _, entry in entries do
			local id = entry.id
			if seen[id] ~= nil then
				continue
			end
			local _condition = id == "Admin"
			if _condition then
				local _result = state.Admin
				if _result ~= nil then
					_result = _result.Access
				end
				_condition = _result ~= true
			end
			if _condition then
				continue
			end
			local _lock = state.FeatureUnlocks
			if _lock ~= nil then
				_lock = _lock[id]
			end
			local lock = _lock
			local _result = state.Flags
			if _result ~= nil then
				_result = _result.TutorialDone
			end
			local _condition_1 = _result ~= true
			if _condition_1 then
				_condition_1 = tutorialPage == id
			end
			local tutorialOverride = _condition_1
			local unlocked = id == "Trade"
			if not unlocked then
				local _result_1 = lock
				if _result_1 ~= nil then
					_result_1 = _result_1.Unlocked
				end
				unlocked = _result_1 ~= false
				if not unlocked then
					unlocked = tutorialOverride
				end
			end
			if unlocked then
				seen[id] = true
				table.insert(visible, entry)
			end
		end
		return visible
	end,
	visibleNav = function(self, state, tutorialPage)
		local _array_1 = {}
		local _length_1 = #_array_1
		local _pRIMARY_NAVLength_1 = #PRIMARY_NAV
		table.move(PRIMARY_NAV, 1, _pRIMARY_NAVLength_1, _length_1 + 1, _array_1)
		_length_1 += _pRIMARY_NAVLength_1
		table.move(MORE_NAV, 1, #MORE_NAV, _length_1 + 1, _array_1)
		return AppHelpers:filterNav(_array_1, state, tutorialPage)
	end,
	navBadge = function(self, entry, state, chatUnread)
		local id = entry.id
		if id == "Trade" then
			local _result = state.Trade
			if _result ~= nil then
				_result = _result.Invite
			end
			return if _result then 1 else 0
		end
		if id == "Inventory" then
			local _keys = state.Items
			if _keys ~= nil then
				_keys = _keys.Keys
			end
			local keys = _keys
			if not keys then
				return 0
			end
			local count = 0
			for _, value in pairs(keys) do
				if type(value) == "number" and value > 0 then
					count += 1
				end
			end
			return count
		end
		if id == "Chat" then
			return chatUnread
		end
		if id == "Mail" then
			local _result = state.Mailbox
			if _result ~= nil then
				_result = _result.Unread
			end
			local _condition = _result
			if _condition == nil then
				_condition = 0
			end
			return _condition
		end
		if id == "Echoes" then
			local echoes = state.ForgeEchoes
			local _result = echoes
			if _result ~= nil then
				_result = _result.Ready
			end
			if _result == true then
				return 1
			end
			local _result_1 = echoes
			if _result_1 ~= nil then
				_result_1 = _result_1.Choices
				if _result_1 ~= nil then
					_result_1 = #_result_1
				end
			end
			local _condition = _result_1
			if _condition == nil then
				_condition = 0
			end
			local choiceCount = _condition
			return if choiceCount > 0 then 1 else 0
		end
		if id == "Convergence" then
			local _result = state.Convergence
			if _result ~= nil then
				_result = _result.Tiers
			end
			local _condition = _result
			if _condition == nil then
				_condition = {}
			end
			local tiers = _condition
			local count = 0
			for _, tier in tiers do
				if tier.CanClaim then
					count += 1
				end
			end
			return count
		end
		if id == "Story" then
			local claimable = 0
			local unreadTeaser = 0
			local chapters = state.Story or {}
			for _, chapter in chapters do
				if not chapter.Unlocked then
					continue
				end
				if chapter.Read and not chapter.Claimed then
					claimable += 1
				elseif not chapter.Read and unreadTeaser == 0 then
					unreadTeaser = 1
				end
			end
			return claimable + unreadTeaser
		end
		if id == "Command" then
			local cmd = state.Command
			if not cmd then
				return 0
			end
			local count = if #cmd.ClaimableCommanderLevels > 0 then 1 else 0
			for _, directive in cmd.Weekly do
				if not directive.Claimed and directive.Progress >= directive.Target then
					count += 1
				end
			end
			if cmd.ActiveExpedition and cmd.ActiveExpedition.Id ~= "" and os.time() >= cmd.ActiveExpedition.EndsAt then
				count += 1
			end
			return count
		end
		return 0
	end,
	worldWindow = {
		chunk = 5,
		maxMounted = 15,
	},
	formatWorldMultiplier = function(self, value)
		local rounded = math.floor(value * 100 + 0.5) / 100
		if rounded % 1 == 0 then
			return tostring(math.floor(rounded))
		end
		if (rounded * 10) % 1 == 0 then
			return string.format("%.1f", rounded)
		end
		return string.format("%.2f", rounded)
	end,
	worldWindowAround = function(self, currentIdx, total, count)
		if count == nil then
			count = 5
		end
		if total <= 0 then
			return {
				start = 0,
				count = 0,
			}
		end
		local size = math.clamp(count, 1, math.min(total, 15))
		local start = math.clamp(currentIdx - math.floor((size - 1) / 2), 0, math.max(0, total - size))
		return {
			start = start,
			count = size,
		}
	end,
	trimFarLockedUpgrades = function(self, entries)
		local out = {}
		local lockedShown = 0
		for _, entry in entries do
			if entry.unlocked or entry.level > 0 then
				table.insert(out, entry)
			elseif lockedShown < 12 then
				table.insert(out, entry)
				lockedShown += 1
			end
		end
		return out
	end,
	buildUpgradeEntries = function(self, configs, levels, state, _buyAmount, limit)
		local names = {}
		for _, item in configs do
			local _id = item.Id
			local _name = item.Name
			names[_id] = _name
		end
		local entries = {}
		for index = 0, #configs - 1 do
			if limit ~= nil and index >= limit then
				break
			end
			local item = configs[index + 1]
			local _condition = levels[item.Id]
			if _condition == nil then
				_condition = 0
			end
			local level = _condition
			local price = scaledCost(item.BaseCost, item.CostScale, level)
			local maxed = level >= item.MaxLevel
			local lockReason = ""
			local lockShort = ""
			local _condition_1 = item.RequiredZone
			if _condition_1 == nil then
				_condition_1 = 1
			end
			local requiredZone = _condition_1
			local zone = state.Zone
			if type(zone) ~= "number" then
				zone = 0
			end
			if zone < requiredZone then
				lockReason = `Reach World {requiredZone}`
			else
				local _condition_2 = item.RequiredRebirths
				if _condition_2 == nil then
					_condition_2 = 0
				end
				local requiredRebirths = _condition_2
				local rebirths = state.Rebirths
				if type(rebirths) ~= "number" then
					rebirths = 0
				end
				if rebirths < requiredRebirths then
					lockReason = `Complete {requiredRebirths} rebirth{if requiredRebirths == 1 then "" else "s"}`
				elseif item.PreviousId ~= nil then
					local _condition_3 = levels[item.PreviousId]
					if _condition_3 == nil then
						_condition_3 = 0
					end
					local prevLevel = _condition_3
					local _condition_4 = item.PreviousLevel
					if _condition_4 == nil then
						_condition_4 = 1
					end
					local needLevel = _condition_4
					if prevLevel < needLevel then
						local _previousId = item.PreviousId
						local _condition_5 = names[_previousId]
						if _condition_5 == nil then
							_condition_5 = item.PreviousId
						end
						local prevName = _condition_5
						lockReason = `Get {prevName} to level {needLevel}. You have {prevLevel}.`
						lockShort = `Need level {needLevel}`
					end
				end
			end
			local unlocked = lockReason == ""
			local _arg0 = {
				config = item,
				level = level,
				price = price,
				maxed = maxed,
				unlocked = unlocked,
				lockReason = lockReason,
				lockShort = lockShort,
				affordable = unlocked and not maxed and gteFlux(state.Cash, price),
				order = index,
			}
			table.insert(entries, _arg0)
		end
		return entries
	end,
	reserveId = function(self, value)
		if value >= 0.625 then
			return "HIGH"
		end
		if value >= 0.375 then
			return "HALF"
		end
		if value >= 0.125 then
			return "SAFE"
		end
		return "NONE"
	end,
	reserveValue = function(self, id)
		if id == "HIGH" then
			return 0.75
		end
		if id == "HALF" then
			return 0.5
		end
		if id == "SAFE" then
			return 0.25
		end
		return 0
	end,
}
return {
	PRIMARY_NAV = PRIMARY_NAV,
	MORE_NAV = MORE_NAV,
	NAV = NAV,
	NAV_GROUPS = NavRouteTable.NAV_GROUPS,
	navGroupOf = NavRouteTable.groupOf,
	AppHelpers = AppHelpers,
}
end

-- ======================================================================
-- Module: GamepadNavigationService   (merged from input/GamepadNavigationService.luau, 276 lines)
-- ======================================================================
__defs["GamepadNavigationService"] = function()
-- Controller navigation and TV-safe layout support. Console compliance still
-- requires Studio/physical-device validation.
-- Ten-foot shells already own the side nav; this service only wires focus,
-- shortcuts, and shared hint copy for overlays / bottom chrome.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

local GamepadNavigationService = {}
GamepadNavigationService.__index = GamepadNavigationService

local TV_SAFE_MARGIN_RATIO = 0.08
local isConsoleMode = false
local inputConnection: RBXScriptConnection? = nil
local connectedConnection: RBXScriptConnection? = nil
local disconnectedConnection: RBXScriptConnection? = nil
local initialized = false
local previousAutoSelect = false
local previousNavigation = false
local overlayFocusDepth = 0
local overlayPreviousSelection: GuiObject? = nil

local tabCycleCallback: ((delta: number) -> ())? = nil
local modalCloseCallback: (() -> ())? = nil
local quickVaultCallback: (() -> ())? = nil
local overchargeCallback: (() -> ())? = nil
local settingsCallback: (() -> ())? = nil

local CONTROLLER_HINTS = {
	{ id = "pages", label = "LB / RB pages" },
	{ id = "vault", label = "Y vault" },
	{ id = "overcharge", label = "X overcharge" },
	{ id = "buy", label = "LT / RT buy ×" },
	{ id = "back", label = "B back" },
	{ id = "hide", label = "View hide" },
	{ id = "settings", label = "Start settings" },
}

local TUTORIAL_HINTS = {
	{ id = "confirm", label = "A confirm" },
	{ id = "back", label = "B back" },
}

-- README checklist: crate reveal claim must be D-pad/A reachable.
local CRATE_HINTS = {
	{ id = "confirm", label = "A claim / skip" },
	{ id = "back", label = "B claim / skip" },
}

function GamepadNavigationService.GetTVSafeInsets(viewportSize: Vector2): { top: number, bottom: number, left: number, right: number }
	local marginX = math.floor(viewportSize.X * TV_SAFE_MARGIN_RATIO)
	local marginY = math.floor(viewportSize.Y * TV_SAFE_MARGIN_RATIO)
	return { top = marginY, bottom = marginY, left = marginX, right = marginX }
end

function GamepadNavigationService.GetHints(kind: string?): { { id: string, label: string } }
	if kind == "tutorial" then
		return TUTORIAL_HINTS
	end
	if kind == "crate" then
		return CRATE_HINTS
	end
	return CONTROLLER_HINTS
end

function GamepadNavigationService.GetHintLabels(kind: string?): { string }
	local source = GamepadNavigationService.GetHints(kind)
	local labels = table.create(#source)
	for index, entry in source do
		labels[index] = entry.label
	end
	return labels
end

function GamepadNavigationService.IsValidFocusTarget(object: Instance?): boolean
	if object == nil or not object:IsA("GuiObject") then
		return false
	end
	local gui = object :: GuiObject
	if not gui.Visible or gui.AbsoluteSize.X < 2 or gui.AbsoluteSize.Y < 2 then
		return false
	end
	if gui:IsA("GuiButton") then
		local button = gui :: GuiButton
		if not button.Selectable or not button.Active then
			return false
		end
	elseif not gui.Selectable then
		return false
	end
	local current: Instance? = gui
	while current ~= nil do
		if current:IsA("GuiObject") and (current :: GuiObject).Visible == false then
			return false
		end
		current = current.Parent
	end
	return true
end

function GamepadNavigationService.AssignSelection(object: Instance?)
	if not GamepadNavigationService.IsValidFocusTarget(object) then
		return false
	end
	local ok = pcall(function()
		GuiService.SelectedObject = object :: GuiObject
	end)
	return ok
end

function GamepadNavigationService.ClearSelection()
	pcall(function()
		GuiService.SelectedObject = nil
	end)
end

-- Claim / skip / ready / confirm / buy path for overlays and session CTAs: enable Gui
-- navigation and park Selection on the highest-priority valid GuiButton under `root`.
-- Priority prefers commit actions (claim/confirm/buy) over staging (ready) or dismiss.
function GamepadNavigationService.FocusClaim(root: Instance?): GuiObject?
	if not UserInputService.GamepadEnabled then
		return nil
	end
	if root == nil or root.Parent == nil then
		return nil
	end
	GuiService.GuiNavigationEnabled = true
	GuiService.AutoSelectGuiEnabled = true
	local TAG_PRIORITY = {
		claim = 1,
		confirm = 1,
		buy = 2,
		dismiss = 2,
		continue = 2,
		ready = 3,
		skip = 4,
	}
	local function tagScore(instance: Instance): number?
		local current: Instance? = instance
		local best: number? = nil
		while current ~= nil and current ~= root do
			local name = string.lower(current.Name)
			for tag, rank in TAG_PRIORITY do
				if string.find(name, tag, 1, true) then
					if best == nil or rank < best then
						best = rank
					end
				end
			end
			current = current.Parent
		end
		return best
	end
	local preferred: GuiObject? = nil
	local preferredScore = math.huge
	local fallback: GuiObject? = nil
	for _, child in root:GetDescendants() do
		if child:IsA("GuiButton") and GamepadNavigationService.IsValidFocusTarget(child) then
			local score = tagScore(child)
			if score ~= nil and score < preferredScore then
				preferred = child
				preferredScore = score
			elseif fallback == nil then
				fallback = child
			end
		end
	end
	local target = preferred or fallback
	if target ~= nil then
		GamepadNavigationService.AssignSelection(target)
	end
	return target
end

-- Begin a modal overlay focus session (crate reveal, empty reveal). Call EndOverlayFocus on exit.
function GamepadNavigationService.BeginOverlayFocus()
	if overlayFocusDepth == 0 then
		overlayPreviousSelection = GuiService.SelectedObject
		GuiService.GuiNavigationEnabled = false
		GuiService.AutoSelectGuiEnabled = false
		GamepadNavigationService.ClearSelection()
	end
	overlayFocusDepth += 1
end

function GamepadNavigationService.EndOverlayFocus()
	if overlayFocusDepth <= 0 then
		return
	end
	overlayFocusDepth -= 1
	if overlayFocusDepth > 0 then
		return
	end
	local restore = overlayPreviousSelection
	overlayPreviousSelection = nil
	if isConsoleMode then
		GuiService.GuiNavigationEnabled = true
		GuiService.AutoSelectGuiEnabled = true
	else
		GuiService.GuiNavigationEnabled = previousNavigation
		GuiService.AutoSelectGuiEnabled = previousAutoSelect
	end
	if GamepadNavigationService.IsValidFocusTarget(restore) then
		GamepadNavigationService.AssignSelection(restore)
	else
		GamepadNavigationService.ClearSelection()
	end
end

function GamepadNavigationService.Init()
	if initialized then return end
	initialized = true
	previousAutoSelect = GuiService.AutoSelectGuiEnabled
	previousNavigation = GuiService.GuiNavigationEnabled
	local function syncGamepadMode()
		isConsoleMode = UserInputService.GamepadEnabled
		if isConsoleMode then
			GamepadService:DisableGamepadCursor()
			GuiService.AutoSelectGuiEnabled = true
			GuiService.GuiNavigationEnabled = true
		else
			GuiService.AutoSelectGuiEnabled = previousAutoSelect
			GuiService.GuiNavigationEnabled = previousNavigation
		end
	end
	syncGamepadMode()
	connectedConnection = UserInputService.GamepadConnected:Connect(syncGamepadMode)
	disconnectedConnection = UserInputService.GamepadDisconnected:Connect(syncGamepadMode)

	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.Gamepad1 then return end
		local code = input.KeyCode
		if code == Enum.KeyCode.ButtonB and modalCloseCallback then
			modalCloseCallback()
		elseif code == Enum.KeyCode.ButtonY and quickVaultCallback then
			quickVaultCallback()
		elseif code == Enum.KeyCode.ButtonX and overchargeCallback then
			overchargeCallback()
		elseif (code == Enum.KeyCode.ButtonStart or code == Enum.KeyCode.ButtonSelect) and settingsCallback then
			settingsCallback()
		elseif code == Enum.KeyCode.ButtonL1 and tabCycleCallback then
			tabCycleCallback(-1)
		elseif code == Enum.KeyCode.ButtonR1 and tabCycleCallback then
			tabCycleCallback(1)
		end
	end)
end

function GamepadNavigationService.Stop()
	if inputConnection then inputConnection:Disconnect(); inputConnection = nil end
	if connectedConnection then connectedConnection:Disconnect(); connectedConnection = nil end
	if disconnectedConnection then disconnectedConnection:Disconnect(); disconnectedConnection = nil end
	if initialized then
		GuiService.AutoSelectGuiEnabled = previousAutoSelect
		GuiService.GuiNavigationEnabled = previousNavigation
	end
	initialized = false
	isConsoleMode = false
	overlayFocusDepth = 0
	overlayPreviousSelection = nil
	tabCycleCallback = nil
	modalCloseCallback = nil
	quickVaultCallback = nil
	overchargeCallback = nil
	settingsCallback = nil
end

function GamepadNavigationService.SetTabCycleCallback(callback: (delta: number) -> ()) tabCycleCallback = callback end
function GamepadNavigationService.SetModalCloseCallback(callback: () -> ()) modalCloseCallback = callback end
function GamepadNavigationService.SetQuickVaultCallback(callback: () -> ()) quickVaultCallback = callback end
function GamepadNavigationService.SetOverchargeCallback(callback: () -> ()) overchargeCallback = callback end
function GamepadNavigationService.SetSettingsCallback(callback: () -> ()) settingsCallback = callback end
function GamepadNavigationService.IsConsole(): boolean return isConsoleMode end
return GamepadNavigationService
end

-- ======================================================================
-- Module: TouchGestureService   (merged from input/TouchGestureService.luau, 472 lines)
-- ======================================================================
__defs["TouchGestureService"] = function()
--[=[
	[INPUT] Astral Forge Engine v5.0+ Touch & Gesture Engine
	Omni-platform touch architecture featuring:
	- Multi-touch pointer lifecycle management
	- Pinch-to-zoom & two-finger twist detection
	- Velocity-based directional swipe & flick analysis
	- Dynamic Virtual Thumbstick (anchors dynamically under thumb)
	- "Fat-Finger" forgiveness with distance-to-center hit resolution
]=]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

type TouchPointer = {
	id: number,
	startPos: Vector2,
	currentPos: Vector2,
	previousPos: Vector2,
	velocity: Vector2,
	startTime: number,
	lastUpdateTime: number,
	isConsumed: boolean,
}

type GestureEvent = "Tap" | "DoubleTap" | "LongPress" | "Swipe" | "Pinch" | "ThumbstickMove"

type SwipeData = {
	direction: Vector2,
	distance: number,
	velocity: Vector2,
	isFlick: boolean,
}

type PinchData = {
	center: Vector2,
	scaleDelta: number,
	rotationDelta: number,
	distance: number,
}

type ThumbstickData = {
	origin: Vector2,
	current: Vector2,
	direction: Vector2,
	magnitude: number, -- 0 to 1
	active: boolean,
}

local TouchGestureService = {}
TouchGestureService.__index = TouchGestureService

-- Configuration constants
local MIN_SWIPE_DISTANCE = 40 -- Minimum pixels for swipe
local FLICK_VELOCITY_THRESHOLD = 800 -- Pixels/sec
local PINCH_MIN_TOUCH_DIST = 16
local THUMBSTICK_RADIUS = 64
local THUMBSTICK_DEADZONE = 0.12
local FAT_FINGER_EXPANSION_PX = 14 -- Hitbox padding beyond visual border
local TAP_MAX_DURATION = 0.35
local TAP_MAX_TRAVEL = 12

local activeTouches: { [InputObject]: TouchPointer } = {}
local pointerIdCounter = 0
local listeners: { [GestureEvent]: { (any) -> () } } = {
	Tap = {},
	DoubleTap = {},
	LongPress = {},
	Swipe = {},
	Pinch = {},
	ThumbstickMove = {},
}

-- Dynamic Virtual Thumbstick state
local thumbstickState: ThumbstickData = {
	origin = Vector2.zero,
	current = Vector2.zero,
	direction = Vector2.zero,
	magnitude = 0,
	active = false,
}
local thumbstickTouch: InputObject? = nil

-- Registered Fat-Finger Hitbox Targets
type HitTarget = {
	id: string,
	gui: GuiObject,
	priority: number,
	callback: () -> (),
	customExpansion: number?,
}
local registeredTargets: { HitTarget } = {}
local inputConnections: { RBXScriptConnection } = {}
local initialized = false

local function isVisible(gui: GuiObject): boolean
	local ancestor: Instance? = gui
	while ancestor do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return true
end

local function toGuiPosition(rawPosition: Vector2): Vector2
	-- InputObject.Position includes the GUI inset; PlayerGui hit tests and
	-- GuiObject.AbsolutePosition use the inset-adjusted coordinate space.
	local ok, topLeft = pcall(function() return GuiService:GetGuiInset() end)
	return if ok and typeof(topLeft) == "Vector2" then rawPosition - topLeft else rawPosition
end

local function isPointUnclipped(gui: GuiObject, position: Vector2): boolean
	local ancestor: Instance? = gui.Parent
	while ancestor do
		if ancestor:IsA("GuiObject") and ancestor.ClipsDescendants then
			local origin = ancestor.AbsolutePosition
			local size = ancestor.AbsoluteSize
			if position.X < origin.X or position.X > origin.X + size.X
				or position.Y < origin.Y or position.Y > origin.Y + size.Y then
				return false
			end
		end
		ancestor = ancestor.Parent
	end
	return true
end

local function isOnInteractiveGui(position: Vector2): boolean
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	for _, gui in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if gui:IsA("GuiButton") and isVisible(gui) then
			return true
		end
	end
	return false
end

--[=[
	Helper: Emit gesture events to registered listeners
]=]
local function emit(event: GestureEvent, payload: any)
	local list = listeners[event]
	if list then
		for _, handler in list do
			task.spawn(handler, payload)
		end
	end
end

--[=[
	Evaluates registered UI elements using distance-weighted "Fat-Finger" expansion.
	Returns true if a target was successfully engaged.
]=]
function TouchGestureService.ResolveFatFingerHit(screenPosition: Vector2): boolean
	-- Native GuiButton.Activated owns touches within a visible button. Assistance only
	-- handles the extra margin; otherwise a tap can purchase or claim twice.
	if isOnInteractiveGui(screenPosition) then
		return false
	end
	local bestTarget: HitTarget? = nil
	local bestScore = math.huge

	for _, target in registeredTargets do
		if not target.gui.Parent or not isVisible(target.gui) or not isPointUnclipped(target.gui, screenPosition) then
			continue
		end

		local absPos = target.gui.AbsolutePosition
		local absSize = target.gui.AbsoluteSize
		local expansion = target.customExpansion or FAT_FINGER_EXPANSION_PX

		-- Calculate expanded AABB
		local minX = absPos.X - expansion
		local maxX = absPos.X + absSize.X + expansion
		local minY = absPos.Y - expansion
		local maxY = absPos.Y + absSize.Y + expansion

		if screenPosition.X >= minX and screenPosition.X <= maxX and screenPosition.Y >= minY and screenPosition.Y <= maxY then
			-- Calculate Euclidean distance to element center
			local center = absPos + (absSize * 0.5)
			local dist = (screenPosition - center).Magnitude
			local score = dist - (target.priority * 20) -- Higher priority shifts score favorable

			if score < bestScore then
				bestScore = score
				bestTarget = target
			end
		end
	end

	if bestTarget then
		task.spawn(bestTarget.callback)
		return true
	end
	return false
end

--[=[
	Register a UI element for fat-finger touch assist.
]=]
function TouchGestureService.RegisterTouchTarget(id: string, gui: GuiObject, callback: () -> (), priority: number?, customExpansion: number?)
	for idx, t in registeredTargets do
		if t.id == id then
			registeredTargets[idx] = {
				id = id,
				gui = gui,
				priority = priority or 1,
				callback = callback,
				customExpansion = customExpansion,
			}
			return
		end
	end

	table.insert(registeredTargets, {
		id = id,
		gui = gui,
		priority = priority or 1,
		callback = callback,
		customExpansion = customExpansion,
	})
end

function TouchGestureService.UnregisterTouchTarget(id: string)
	for idx, t in registeredTargets do
		if t.id == id then
			table.remove(registeredTargets, idx)
			break
		end
	end
end

function TouchGestureService.IsNearRegisteredTarget(position: Vector2): boolean
	for _, target in registeredTargets do
		if target.gui.Parent and isVisible(target.gui) and isPointUnclipped(target.gui, position) then
			local origin = target.gui.AbsolutePosition
			local size = target.gui.AbsoluteSize
			local margin = target.customExpansion or FAT_FINGER_EXPANSION_PX
			if position.X >= origin.X - margin and position.X <= origin.X + size.X + margin
				and position.Y >= origin.Y - margin and position.Y <= origin.Y + size.Y + margin then
				return true
			end
		end
	end
	return false
end

--[=[
	Calculates pinch metrics across two active touch points.
]=]
local function evaluatePinch(p1: TouchPointer, p2: TouchPointer)
	local curDist = (p1.currentPos - p2.currentPos).Magnitude
	local prevDist = (p1.previousPos - p2.previousPos).Magnitude
	if prevDist < PINCH_MIN_TOUCH_DIST then
		return
	end

	local scaleDelta = curDist / prevDist
	local center = (p1.currentPos + p2.currentPos) * 0.5

	local curVec = p1.currentPos - p2.currentPos
	local prevVec = p1.previousPos - p2.previousPos
	local curAngle = math.atan2(curVec.Y, curVec.X)
	local prevAngle = math.atan2(prevVec.Y, prevVec.X)
	local rotDelta = curAngle - prevAngle

	local pinchPayload: PinchData = {
		center = center,
		scaleDelta = scaleDelta,
		rotationDelta = rotDelta,
		distance = curDist,
	}
	emit("Pinch", pinchPayload)
end

--[=[
	Initializes input listeners for the multi-touch lifecycle.
]=]
function TouchGestureService.Init()
	if initialized or not UserInputService.TouchEnabled then
		return
	end
	initialized = true

	-- InputBegan
	local beganConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		pointerIdCounter += 1
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local now = os.clock()

		local pointer: TouchPointer = {
			id = pointerIdCounter,
			startPos = pos,
			currentPos = pos,
			previousPos = pos,
			velocity = Vector2.zero,
			startTime = now,
			lastUpdateTime = now,
			isConsumed = gameProcessed or isOnInteractiveGui(toGuiPosition(pos)),
		}
		activeTouches[input] = pointer

		-- Dynamic Virtual Thumbstick initialization:
		-- If touch originates in bottom-left quadrant (X < 45% screen width, Y > 50% screen height)
		-- and thumbstick is currently idle, anchor the joystick center dynamically right here!
		local cam = workspace.CurrentCamera
		local vSize = if cam then cam.ViewportSize else Vector2.new(1000, 800)
		if not pointer.isConsumed and not TouchGestureService.IsNearRegisteredTarget(toGuiPosition(pos)) and not thumbstickState.active and pos.X < (vSize.X * 0.45) and pos.Y > (vSize.Y * 0.50) then
			thumbstickTouch = input
			thumbstickState.active = true
			thumbstickState.origin = pos
			thumbstickState.current = pos
			thumbstickState.direction = Vector2.zero
			thumbstickState.magnitude = 0
			emit("ThumbstickMove", thumbstickState)
		end
	end)
	table.insert(inputConnections, beganConnection)

	-- InputChanged
	local changedConnection = UserInputService.InputChanged:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pointer = activeTouches[input]
		if not pointer then
			return
		end

		local newPos = Vector2.new(input.Position.X, input.Position.Y)
		local now = os.clock()
		local dt = math.max(0.001, now - pointer.lastUpdateTime)

		pointer.velocity = (newPos - pointer.currentPos) / dt
		pointer.previousPos = pointer.currentPos
		pointer.currentPos = newPos
		pointer.lastUpdateTime = now

		-- Dynamic Virtual Thumbstick tracking
		if input == thumbstickTouch and thumbstickState.active then
			local delta = newPos - thumbstickState.origin
			local rawMag = delta.Magnitude
			local clampedDist = math.min(rawMag, THUMBSTICK_RADIUS)
			local unitDir = if rawMag > 0.001 then (delta / rawMag) else Vector2.zero

			-- Apply deadzone filter
			local normalized = clampedDist / THUMBSTICK_RADIUS
			local filteredMag = 0
			if normalized > THUMBSTICK_DEADZONE then
				filteredMag = (normalized - THUMBSTICK_DEADZONE) / (1 - THUMBSTICK_DEADZONE)
			end

			thumbstickState.current = thumbstickState.origin + (unitDir * clampedDist)
			thumbstickState.direction = unitDir
			thumbstickState.magnitude = filteredMag
			emit("ThumbstickMove", thumbstickState)
		end

		-- Multi-touch gesture processing: Two-finger pinch
		local touches = {}
		for touchInput, ptr in activeTouches do
			if not ptr.isConsumed and touchInput ~= thumbstickTouch then
				table.insert(touches, ptr)
			end
		end
		if #touches == 2 then
			evaluatePinch(touches[1], touches[2])
		end
	end)
	table.insert(inputConnections, changedConnection)

	-- InputEnded
	local endedConnection = UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local pointer = activeTouches[input]
		if not pointer then
			return
		end

		local now = os.clock()
		local duration = now - pointer.startTime
		local travel = (pointer.currentPos - pointer.startPos).Magnitude

		-- Thumbstick release
		local wasThumbstick = input == thumbstickTouch
		if wasThumbstick then
			thumbstickTouch = nil
			thumbstickState.active = false
			thumbstickState.direction = Vector2.zero
			thumbstickState.magnitude = 0
			emit("ThumbstickMove", thumbstickState)
		end

		-- Tap / Fat-finger assistance
		if not pointer.isConsumed and not wasThumbstick and duration <= TAP_MAX_DURATION and travel <= TAP_MAX_TRAVEL then
			local handled = TouchGestureService.ResolveFatFingerHit(toGuiPosition(pointer.currentPos))
			if not handled then
				emit("Tap", pointer.currentPos)
			end
		-- Swipe analysis
		elseif not pointer.isConsumed and not wasThumbstick and travel >= MIN_SWIPE_DISTANCE then
			local dir = (pointer.currentPos - pointer.startPos).Unit
			local speed = pointer.velocity.Magnitude
			local isFlick = speed >= FLICK_VELOCITY_THRESHOLD

			local swipe: SwipeData = {
				direction = dir,
				distance = travel,
				velocity = pointer.velocity,
				isFlick = isFlick,
			}
			emit("Swipe", swipe)
		end

		activeTouches[input] = nil
	end)
	table.insert(inputConnections, endedConnection)
end

function TouchGestureService.Stop()
	for _, connection in inputConnections do
		connection:Disconnect()
	end
	table.clear(inputConnections)
	table.clear(activeTouches)
	table.clear(registeredTargets)
	thumbstickTouch = nil
	thumbstickState.active = false
	thumbstickState.direction = Vector2.zero
	thumbstickState.magnitude = 0
	initialized = false
end

--[=[
	Subscribes to gesture events.
]=]
function TouchGestureService.On(event: GestureEvent, callback: (any) -> ()): () -> ()
	local list = listeners[event]
	if list then
		table.insert(list, callback)
		return function()
			local idx = table.find(list, callback)
			if idx then
				table.remove(list, idx)
			end
		end
	end
	return function() end
end

function TouchGestureService.GetThumbstickState(): ThumbstickData
	return thumbstickState
end

return TouchGestureService
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
