// Purpose: asset ids for the 2026-10 UI revamp art (page headers, companion sheets).
// Uploaded 2026-10-22 with tools/assetgen/upload.py; the source PNGs are exported from the design SVGs.

/** 1024x120 page header strips, placed behind a hero title with ScaleType Crop */
export const HEADER_ART = {
	ascension: "rbxassetid://82657390275902",
	companions: "rbxassetid://72852035944524",
	crates: "rbxassetid://132832534777726",
	forge: "rbxassetid://129306695928995",
	journal: "rbxassetid://140334966513714",
	market: "rbxassetid://91615259534204",
	ranks: "rbxassetid://79586395880216",
	rebirth: "rbxassetid://77379807257881",
	vault: "rbxassetid://73472877278952",
	worlds: "rbxassetid://132294712138207",
} as const;

export type HeaderArtName = keyof typeof HEADER_ART;

/** companion idle sheets: 1024px, 6x6 grid, 36 frames at 24 fps (same timing as the element sheets) */
export const COMPANION_SHEETS = {
	Cinder: "rbxassetid://96721820700576",
	Frostlet: "rbxassetid://102982024064892",
	Tidepup: "rbxassetid://112367869722042",
	BrassOwl: "rbxassetid://92141659344017",
	Lumen: "rbxassetid://125440001868646",
	Voidmote: "rbxassetid://111706636066465",
} as const;

export type CompanionSheetName = keyof typeof COMPANION_SHEETS;

export const COMPANION_SHEET_GRID = { columns: 6, count: 36, frameRate: 24, frame: 1024 / 6 } as const;
