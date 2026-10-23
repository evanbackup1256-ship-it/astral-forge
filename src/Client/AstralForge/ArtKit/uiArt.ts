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

// Companion idle sheets live in Shared/ElementSprites.ts (COMPANIONS); that table is the one source.
