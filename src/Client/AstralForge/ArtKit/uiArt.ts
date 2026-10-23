import { art } from "../../../Shared/AstralForge/Shared/UiArt";
// Purpose: asset ids for the 2026-10 UI revamp art (page headers, companion sheets).
// Uploaded 2026-10-22 with tools/assetgen/upload.py; the source PNGs are exported from the design SVGs.

/** 1024x120 page header strips, placed behind a hero title with ScaleType Crop */
export const HEADER_ART = {
	ascension: art("rbxassetid://82657390275902"),
	companions: art("rbxassetid://72852035944524"),
	crates: art("rbxassetid://132832534777726"),
	forge: art("rbxassetid://129306695928995"),
	journal: art("rbxassetid://140334966513714"),
	market: art("rbxassetid://91615259534204"),
	ranks: art("rbxassetid://79586395880216"),
	rebirth: art("rbxassetid://77379807257881"),
	vault: art("rbxassetid://73472877278952"),
	worlds: art("rbxassetid://132294712138207"),
};

export type HeaderArtName = keyof typeof HEADER_ART;

// Companion idle sheets live in Shared/ElementSprites.ts (COMPANIONS); that table is the one source.
