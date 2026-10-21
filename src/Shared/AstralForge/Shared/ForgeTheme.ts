// Purpose: Named Astral Forge palette and accessibility variants; colors match the audited baseline.
// Owner: Astral Forge presentation. Dependencies: Roblox Color3. Last-reviewed: 2026-10-21 (revamp r1a: calmer neutrals, softened accents).

export type Palette = Record<string, Color3>;
export type NamedPalette = Record<string, string>;
export interface AccessibilitySettings {
	HighContrast: boolean;
	Colorblind: boolean;
}
export interface AccessibilityPalettes {
	Colorblind: Palette;
	HighContrast: Palette;
}
export type RarityPalette = Record<string, Color3>;
export type FeaturePalette = NamedPalette;
export type StatPalette = NamedPalette;
export type FxPalette = Palette;
export interface BootPalette {
	dim: Color3;
	bar: Color3;
	textBright: Color3;
	textDim: Color3;
	textFaint: Color3;
}

const rgb = (r: number, g: number, b: number) => Color3.fromRGB(r, g, b);

export const Base: Palette = table.freeze({
	void: rgb(10, 10, 12),
	ink: rgb(14, 14, 16),
	night: rgb(20, 19, 22),
	panel: rgb(28, 27, 31),
	panelRaised: rgb(38, 37, 42),
	panelSoft: rgb(56, 54, 61),
	line: rgb(66, 63, 71),
	lineSoft: rgb(116, 111, 122),
	cream: rgb(244, 240, 233),
	creamSoft: rgb(214, 208, 200),
	// 170/163/158 keeps muted copy at 4.5:1 on panelSoft (164/157/152 measured 4.45)
	muted: rgb(170, 163, 158),
	cyan: rgb(98, 200, 222),
	mint: rgb(112, 212, 168),
	coral: rgb(236, 112, 108),
	mango: rgb(238, 178, 76),
	violet: rgb(166, 140, 232),
	pink: rgb(226, 118, 170),
	blue: rgb(108, 160, 236),
	white: rgb(255, 255, 255),
	green: rgb(110, 208, 154),
	// 236/104/106: error text holds 4.5:1 on raised cards (226/88/90 was 4.18)
	red: rgb(236, 104, 106),
	shadow: rgb(0, 0, 0),
	graphite: rgb(23, 22, 26),
	steel: rgb(204, 214, 234),
	steelBright: rgb(244, 240, 233),
	brass: rgb(232, 184, 88),
	brassDeep: rgb(140, 92, 30),
	ember: rgb(244, 92, 84),
});

export const Accessibility: AccessibilityPalettes = table.freeze({
	Colorblind: table.freeze({
		green: rgb(86, 180, 233),
		mint: rgb(86, 180, 233),
		red: rgb(230, 159, 0),
		coral: rgb(230, 159, 0),
		pink: rgb(204, 121, 167),
		// Okabe-Ito green, lifted so it still reads 4.5:1 on panelRaised
		violet: rgb(0, 184, 134),
	}),
	HighContrast: table.freeze({
		void: rgb(0, 0, 0),
		ink: rgb(3, 2, 3),
		night: rgb(8, 6, 8),
		panel: rgb(13, 10, 14),
		panelRaised: rgb(21, 16, 23),
		panelSoft: rgb(36, 28, 40),
		lineSoft: rgb(160, 142, 168),
		cream: rgb(255, 255, 255),
		creamSoft: rgb(235, 240, 246),
		muted: rgb(190, 199, 210),
	}),
});

// Semantic feature-to-base-color mapping. Keep color names here, literal RGBs in Base.
export const Feature: FeaturePalette = table.freeze({
	flux: "cyan",
	dust: "mango",
	essence: "violet",
	cores: "pink",
	season: "mango",
	guild: "violet",
	expedition: "green",
	artifact: "violet",
	echo: "mango",
	milestone: "cyan",
	anomaly: "violet",
	continuum: "blue",
	starGrid: "mango",
	wheel: "mango",
	convergence: "mint",
});

export const Tier: NamedPalette = table.freeze({
	Beginner: "mint",
	Apprentice: "cyan",
	Journeyman: "blue",
	Expert: "violet",
	Master: "mango",
	Legend: "pink",
});

export const Rarity: RarityPalette = table.freeze({
	Common: rgb(200, 196, 188),
	Rare: rgb(110, 190, 255),
	Epic: rgb(190, 120, 255),
	Legendary: rgb(255, 190, 70),
	Mythic: rgb(255, 110, 150),
	Celestial: rgb(190, 248, 255),
	Astral: rgb(255, 200, 240),
});

// FX, viewport, and one-off accents that do not fit the base palette.
export const Fx: FxPalette = table.freeze({
	bulbWarm: rgb(255, 236, 190),
	bulbGold: rgb(255, 186, 72),
	bulbOff: rgb(70, 44, 30),
	alertBlue: rgb(0, 94, 184),
	alertBlueText: rgb(190, 220, 255),
	petLine: rgb(74, 36, 18),
	emberTail: rgb(232, 150, 120),
	editBounds: rgb(72, 190, 255),
	wheelDark: rgb(13, 10, 20),
});

export const Stat: StatPalette = table.freeze({
	Production: "coral",
	TapPower: "mango",
	Capacity: "violet",
	CriticalChance: "cyan",
	AutoCollect: "violet",
	Offline: "cyan",
	CriticalMultiplier: "mango",
	RebirthMultiplier: "pink",
});

export const Boot: BootPalette = table.freeze({
	dim: rgb(14, 14, 16),
	bar: rgb(44, 42, 48),
	textBright: rgb(200, 194, 186),
	textDim: rgb(142, 136, 130),
	textFaint: rgb(106, 101, 98),
});

export function newPalette(): Palette {
	return table.clone(Base);
}

export function applyAccessibility(palette: Palette, settings: AccessibilitySettings): void {
	for (const [name, color] of pairs(Base)) {
		palette[name] = color;
	}
	if (settings.Colorblind) {
		for (const [name, color] of pairs(Accessibility.Colorblind)) {
			palette[name] = color;
		}
	}
	if (settings.HighContrast) {
		for (const [name, color] of pairs(Accessibility.HighContrast)) {
			palette[name] = color;
		}
	}
}
