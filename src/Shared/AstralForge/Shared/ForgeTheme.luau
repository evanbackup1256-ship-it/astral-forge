--!strict
-- Purpose: Named Astral Forge palette and accessibility variants; colors match the audited baseline.
-- Owner: Astral Forge presentation. Dependencies: Roblox Color3. Last-reviewed: 2026-10-05.

export type Palette = { [string]: Color3 }
export type NamedPalette = { [string]: string }
export type AccessibilitySettings = { HighContrast: boolean, Colorblind: boolean }
export type AccessibilityPalettes = { Colorblind: Palette, HighContrast: Palette }
export type RarityPalette = { [string]: Color3 }
export type FeaturePalette = NamedPalette
export type StatPalette = NamedPalette
export type FxPalette = Palette
export type ViewportLightPalette = {
	Ambient: Color3,
	LightColor: Color3,
	FallbackAmbient: Color3,
	FallbackLight: Color3,
}
export type BootPalette = {
	dim: Color3,
	bar: Color3,
	textBright: Color3,
	textDim: Color3,
	textFaint: Color3,
}
export type Theme = {
	Base: Palette,
	Accessibility: AccessibilityPalettes,
	Feature: FeaturePalette,
	Tier: NamedPalette,
	Rarity: RarityPalette,
	Fx: FxPalette,
	ViewportLight: ViewportLightPalette,
	Stat: StatPalette,
	Boot: BootPalette,
	newPalette: () -> Palette,
	applyAccessibility: (palette: Palette, settings: AccessibilitySettings) -> (),
}

local base: Palette = {
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
local accessibility: AccessibilityPalettes = {
	Colorblind = {
		green = Color3.fromRGB(86, 180, 233),
		mint = Color3.fromRGB(86, 180, 233),
		red = Color3.fromRGB(230, 159, 0),
		coral = Color3.fromRGB(230, 159, 0),
		pink = Color3.fromRGB(204, 121, 167),
		violet = Color3.fromRGB(0, 158, 115),
	},
	HighContrast = {
		void = Color3.fromRGB(0, 0, 0),
		ink = Color3.fromRGB(3, 2, 3),
		night = Color3.fromRGB(8, 6, 8),
		panel = Color3.fromRGB(13, 10, 14),
		panelRaised = Color3.fromRGB(21, 16, 23),
		panelSoft = Color3.fromRGB(36, 28, 40),
		lineSoft = Color3.fromRGB(160, 142, 168),
		cream = Color3.fromRGB(255, 255, 255),
		creamSoft = Color3.fromRGB(235, 240, 246),
		muted = Color3.fromRGB(190, 199, 210),
	},
}
table.freeze(base)
table.freeze(accessibility.Colorblind)
table.freeze(accessibility.HighContrast)
table.freeze(accessibility)

-- Semantic feature-to-base-color mapping. Keep color names here, literal RGBs in Base.
local feature: FeaturePalette = table.freeze({
	flux = "cyan",
	dust = "mango",
	essence = "violet",
	cores = "pink",
	season = "mango",
	guild = "violet",
	expedition = "green",
	artifact = "violet",
	echo = "mango",
	milestone = "cyan",
	anomaly = "violet",
	continuum = "blue",
	starGrid = "mango",
	wheel = "mango",
	convergence = "mint",
})

local tier: NamedPalette = table.freeze({
	Beginner = "mint",
	Apprentice = "cyan",
	Journeyman = "blue",
	Expert = "violet",
	Master = "mango",
	Legend = "pink",
})

local rarity: RarityPalette = table.freeze({
	Common = Color3.fromRGB(200, 196, 188),
	Rare = Color3.fromRGB(110, 190, 255),
	Epic = Color3.fromRGB(190, 120, 255),
	Legendary = Color3.fromRGB(255, 190, 70),
	Mythic = Color3.fromRGB(255, 110, 150),
	Celestial = Color3.fromRGB(190, 248, 255),
	Astral = Color3.fromRGB(255, 200, 240),
})

-- FX, viewport, and one-off accents that do not fit the base palette.
local fx: FxPalette = table.freeze({
	bulbWarm = Color3.fromRGB(255, 236, 190),
	bulbGold = Color3.fromRGB(255, 186, 72),
	bulbOff = Color3.fromRGB(70, 44, 30),
	alertBlue = Color3.fromRGB(0, 94, 184),
	alertBlueText = Color3.fromRGB(190, 220, 255),
	petLine = Color3.fromRGB(74, 36, 18),
	emberTail = Color3.fromRGB(232, 150, 120),
	editBounds = Color3.fromRGB(72, 190, 255),
	wheelDark = Color3.fromRGB(13, 10, 20),
})

local viewportLight: ViewportLightPalette = table.freeze({
	Ambient = Color3.fromRGB(200, 194, 206),
	LightColor = Color3.fromRGB(205, 198, 186),
	FallbackAmbient = Color3.fromRGB(150, 140, 165),
	FallbackLight = Color3.fromRGB(255, 244, 224),
})

local stat: StatPalette = table.freeze({
	Production = "coral",
	TapPower = "mango",
	Capacity = "violet",
	CriticalChance = "cyan",
	AutoCollect = "violet",
	Offline = "cyan",
	CriticalMultiplier = "mango",
	RebirthMultiplier = "pink",
})

local boot: BootPalette = table.freeze({
	dim = Color3.fromRGB(14, 10, 17),
	bar = Color3.fromRGB(46, 36, 50),
	textBright = Color3.fromRGB(190, 174, 178),
	textDim = Color3.fromRGB(140, 122, 128),
	textFaint = Color3.fromRGB(108, 92, 100),
})

local function newPalette(): Palette
	return table.clone(base)
end

local function applyAccessibility(palette: Palette, settings: AccessibilitySettings): ()
	for name, color in base do
		palette[name] = color
	end
	if settings.Colorblind then
		for name, color in accessibility.Colorblind do
			palette[name] = color
		end
	end
	if settings.HighContrast then
		for name, color in accessibility.HighContrast do
			palette[name] = color
		end
	end
end

local theme: Theme = {
	Base = base,
	Accessibility = accessibility,
	Feature = feature,
	Tier = tier,
	Rarity = rarity,
	Fx = fx,
	ViewportLight = viewportLight,
	Stat = stat,
	Boot = boot,
	newPalette = newPalette,
	applyAccessibility = applyAccessibility,
}
return table.freeze(theme)
