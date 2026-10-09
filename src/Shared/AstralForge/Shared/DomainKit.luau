--!strict
-- Purpose: the uploaded Domain lattice gem kit (tools/assetgen/domain_kit.py) and which gem each
-- skill field wears. The server publishes the meshes as ReplicatedStorage.DomainKit.
-- Owner: presentation + asset pipeline. Dependencies: none. Review: 2026-10-08.

return table.freeze({
	Id = 86019113025827,
	-- cuts built table-up; the client tips them toward the camera so the table catches the light
	TableUp = table.freeze({ Brilliant = true, Emerald = true, Trillion = true, Marquise = true }),
	-- flat pieces rock back and forth instead of turning edge-on
	Sway = table.freeze({ Moon = true, Star = true, Halo = true }),
	Fields = table.freeze({
		Production = "Brilliant",
		Capacity = "Emerald",
		Tap = "Shard",
		Offline = "Moon",
		Luck = "Star",
		EchoCharge = "Halo",
		WorldDiscount = "Globe",
		RebirthYield = "Core",
		EssenceGain = "Pear",
		ContinuumDiscount = "Twist",
		Critical = "Trillion",
		ForgePathXP = "Cube",
		CommandXP = "Marquise",
	}),
})
