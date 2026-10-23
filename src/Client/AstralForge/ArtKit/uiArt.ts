import { art } from "../../../Shared/AstralForge/Shared/UiArt";
// Purpose: asset ids for the 2026-10 UI revamp art (page headers, companion sheets).
// Uploaded 2026-10-22 with tools/assetgen/upload.py; the source PNGs are exported from the design SVGs.

/** 1024x120 page header strips, placed behind a hero title with ScaleType Crop */
export const HEADER_ART = {
	ascension: art("rbxassetid://106300584464828"),
	companions: art("rbxassetid://75520061387345"),
	crates: art("rbxassetid://71586073946515"),
	forge: art("rbxassetid://112579218626393"),
	journal: art("rbxassetid://84327795355564"),
	market: art("rbxassetid://140571630022360"),
	ranks: art("rbxassetid://110034657498031"),
	rebirth: art("rbxassetid://140703475465390"),
	vault: art("rbxassetid://114592875107751"),
	worlds: art("rbxassetid://132104599653570"),
};

export type HeaderArtName = keyof typeof HEADER_ART;

// Companion idle sheets live in Shared/ElementSprites.ts (COMPANIONS); that table is the one source.
