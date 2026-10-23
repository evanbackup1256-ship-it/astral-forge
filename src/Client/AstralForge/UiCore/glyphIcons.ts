import IconManifest = require("../IconManifest");

/** True once the icon sheet has art for this id (tools/assetgen/icons.py, then upload). */
export function hasManifestIcon(name: string): boolean {
	return IconManifest.Icons[name] !== undefined;
}

/**
 * Text-glyph controls (−, +) move onto the icon sheet when the art exists, and keep the
 * plain glyph until then, so nothing changes before the regenerated sheet is uploaded.
 */
export function glyphButton(icon: "Minus" | "Plus", glyph: string): { text: string; icon?: string } {
	return hasManifestIcon(icon) ? { text: "", icon } : { text: glyph };
}
