local exports = {}
local planMobileLayout = require(script.Parent.mobileLayout).planMobileLayout
local _mobileLayout = require(script.Parent.mobileLayout)
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
