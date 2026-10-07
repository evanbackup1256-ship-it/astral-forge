--!strict
-- Purpose: Named Astral Forge palette and accessibility variants; colors match the audited baseline.
-- Owner: Astral Forge presentation. Dependencies: Roblox Color3. Last-reviewed: 2026-10-05.

export type Palette = { [string]: Color3 }
export type AccessibilitySettings = { HighContrast: boolean, Colorblind: boolean }
export type AccessibilityPalettes = { Colorblind: Palette, HighContrast: Palette }
export type Theme = {
	Base: Palette,
	Accessibility: AccessibilityPalettes,
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
	newPalette = newPalette,
	applyAccessibility = applyAccessibility,
}
return table.freeze(theme)
