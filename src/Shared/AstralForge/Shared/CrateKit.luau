--!strict
-- Uploaded Blender kit; the server validates all body/lid pairs before exposing it.
return table.freeze({
	Id = 88755990794383,
	TextureOverrides = table.freeze({
		Crate_Classic_Body = 72350144126150,
		Crate_Frost_Body = 117772155065961,
		Crate_Molten_Body = 116049081200129,
	}),
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
	-- Built by tools/cratebuild/build_expansion.py (assets/generated/crates/CrateKitExpansion.glb),
	-- uploaded with tools/cratebuild/upload_expansion.py.
	Expansions = table.freeze({
		table.freeze({
			Id = 78427750379265,
			Skins = table.freeze({ "Cinder", "Verdant", "Tidal", "Runic", "Comet", "Mirage", "Quasar", "Bastion", "Eclipse", "Nova", "Halo" }),
		}),
	}),
})
