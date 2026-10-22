// Purpose: Named Astral Forge palette and accessibility variants; colors match the audited baseline.
// Owner: Astral Forge presentation. Dependencies: Roblox Color3. Last-reviewed: 2026-10-21 (uirevamp 01 "Night Iron": cool iron neutrals, parchment text, brass lead accent).

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
	void: rgb(8, 9, 14),
	ink: rgb(11, 12, 18),
	night: rgb(16, 17, 25),
	panel: rgb(23, 24, 34),
	panelRaised: rgb(32, 33, 46),
	panelSoft: rgb(47, 48, 65),
	line: rgb(60, 62, 82),
	lineSoft: rgb(110, 112, 138),
	cream: rgb(246, 238, 224),
	creamSoft: rgb(218, 209, 194),
	// muted is checked at 4.5:1 on panelSoft by verify_mobile_matrix; keep it there when retuning
	muted: rgb(178, 172, 182),
	cyan: rgb(96, 206, 222),
	mint: rgb(120, 214, 170),
	coral: rgb(238, 116, 100),
	mango: rgb(242, 176, 72),
	violet: rgb(170, 146, 240),
	pink: rgb(232, 122, 172),
	blue: rgb(112, 164, 240),
	white: rgb(255, 255, 255),
	green: rgb(116, 210, 152),
	// 236/104/106: error text holds 4.5:1 on raised cards (226/88/90 was 4.18)
	red: rgb(240, 108, 104),
	shadow: rgb(0, 0, 0),
	graphite: rgb(19, 20, 29),
	steel: rgb(200, 210, 232),
	steelBright: rgb(246, 238, 224),
	brass: rgb(236, 182, 92),
	brassDeep: rgb(138, 90, 34),
	ember: rgb(246, 104, 72),
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
	dim: rgb(11, 12, 18),
	bar: rgb(40, 41, 56),
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
