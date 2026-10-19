// Purpose: named limits and rarity ordering used by the server crate pipeline.
// Owner: gameplay. Dependencies: none. Last-reviewed: 2026-10-07.

export = table.freeze({
	// Preserve the existing one-at-a-time and five-at-a-time opening controls.
	OpenCounts: table.freeze([1, 5]),
	// A nonzero random interval keeps empty catalogs from passing an invalid range.
	MinimumRollInterval: 0.001,
	RarityOrder: table.freeze(["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial", "Astral"]),
});
