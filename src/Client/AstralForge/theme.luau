local exports = {}
local planMobileLayout = require(script.Parent.mobileLayout).planMobileLayout
local _mobileLayout = require(script.Parent.mobileLayout)
exports.fitPanelHeight = _mobileLayout.fitPanelHeight
exports.fitTouchGridWidth = _mobileLayout.fitTouchGridWidth
exports.isMobileLandscape = _mobileLayout.isMobileLandscape
exports.moreDockHeight = _mobileLayout.moreDockHeight
exports.planMobileLayout = _mobileLayout.planMobileLayout
exports.scrollTail = _mobileLayout.scrollTail
-- Astral Forge brand chroma: cool voids with vivid forge accents so CTAs, tabs,
-- meters, and active chrome read clearly on PC without flattening into gray fog.
local Palette = {
	void = Color3.fromRGB(5, 7, 12),
	ink = Color3.fromRGB(9, 12, 19),
	night = Color3.fromRGB(13, 17, 26),
	panel = Color3.fromRGB(18, 23, 34),
	panelRaised = Color3.fromRGB(26, 33, 49),
	panelSoft = Color3.fromRGB(46, 58, 82),
	line = Color3.fromRGB(52, 66, 92),
	lineSoft = Color3.fromRGB(88, 108, 142),
	cream = Color3.fromRGB(248, 250, 255),
	creamSoft = Color3.fromRGB(214, 224, 238),
	muted = Color3.fromRGB(142, 160, 185),
	cyan = Color3.fromRGB(64, 224, 255),
	mint = Color3.fromRGB(80, 238, 180),
	coral = Color3.fromRGB(255, 98, 118),
	mango = Color3.fromRGB(255, 188, 56),
	violet = Color3.fromRGB(164, 124, 255),
	pink = Color3.fromRGB(245, 96, 184),
	blue = Color3.fromRGB(82, 162, 255),
	white = Color3.fromRGB(255, 255, 255),
	green = Color3.fromRGB(94, 234, 168),
	red = Color3.fromRGB(238, 74, 92),
	shadow = Color3.fromRGB(0, 0, 0),
	graphite = Color3.fromRGB(18, 23, 34),
	steel = Color3.fromRGB(192, 218, 242),
	steelBright = Color3.fromRGB(248, 250, 255),
	brass = Color3.fromRGB(245, 182, 68),
	brassDeep = Color3.fromRGB(128, 86, 28),
	ember = Color3.fromRGB(240, 80, 96),
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
		mutable.ink = Color3.fromRGB(1, 2, 3)
		mutable.night = Color3.fromRGB(5, 7, 9)
		mutable.panel = Color3.fromRGB(8, 11, 14)
		mutable.panelRaised = Color3.fromRGB(14, 18, 23)
		mutable.panelSoft = Color3.fromRGB(24, 30, 38)
		mutable.lineSoft = Color3.fromRGB(139, 153, 170)
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
	cardRadius = 12,
	buttonRadius = 9,
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
	panelShadow = 0.72,
	panelStrokeIdle = 0.48,
	panelStrokeHover = 0.22,
	buttonShadow = 0.5,
	railStrokeIdle = 0.72,
	railStrokeActive = 0.18,
	accentHairline = 0.08,
	meterTrack = 0.22,
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
	return mobileChrome(_exp, _exp_1, _exp_2, _exp_3, _exp_4, _condition, _condition_1, _condition_2, _condition_3, _condition_4)
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
	-- Clearer lift/sink so panels separate from the void without frosted-glass noise.
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, lighten(base, 0.068 * strength)),
		ColorSequenceKeypoint.new(0.16, lighten(base, 0.022 * strength)),
		ColorSequenceKeypoint.new(0.64, base),
		ColorSequenceKeypoint.new(1, darken(base, 0.1 * strength)),
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
exports.Palette = Palette
exports.Layout = Layout
exports.Chrome = Chrome
exports.Breakpoints = Breakpoints
exports.TapTarget = TapTarget
return exports
