--!strict
-- Uploaded Blender kit; the server validates all body/lid pairs before exposing it.
-- Keep the baked GLB material maps as the source of truth. Standalone image overrides
-- previously failed delivery for three body meshes and replaced valid embedded maps.
return table.freeze({
	Id = 88755990794383,
	Skins = table.freeze({
		"Classic",
		"Crystal",
		"Frost",
		"Molten",
		"Nebula",
		"Void",
		"Gilded",
		"Celestial",
		"Salvage",
		"Reactor",
		"Glacier",
		"Solar",
		"Storm",
		"Lunar",
		"DeepSea",
		"Prism",
		"Obsidian",
		"Chrono",
		"Aurora",
		"Titan",
	}),
})
