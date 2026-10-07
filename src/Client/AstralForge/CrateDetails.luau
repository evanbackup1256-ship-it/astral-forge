--!strict
-- Purpose: modeled crate armor, fasteners, seals and distinctive hardware.
-- Owner: presentation. Dependencies: viewport model and existing skin palette.
-- Review: 2026-10-05.

local Details = {}

local function part(
	model: Model,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = frame
	item.Color = color
	item.Material = material
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.Parent = model
	return item
end

function Details.build(model: Model, body: BasePart, accent: Color3, skinId: string): ()
	local size = body.Size
	local metal = accent:Lerp(Color3.new(0, 0, 0), 0.72)
	local bright = accent:Lerp(Color3.new(1, 1, 1), 0.3)
	local halfWidth = size.X * 0.5
	local front = -size.Z * 0.5 - 0.025
	local height = size.Y

	for _, side in { -1, 1 } do
		part(
			model,
			"Corner armor",
			Vector3.new(0.12, height * 0.88, 0.16),
			CFrame.new(side * (halfWidth - 0.04), height * 0.5, front),
			metal,
			Enum.Material.Metal
		)
		for _, fraction in { 0.18, 0.5, 0.82 } do
			local bolt = part(
				model,
				"Hex fastener",
				Vector3.new(0.055, 0.055, 0.045),
				CFrame.new(side * (halfWidth - 0.04), height * fraction, front - 0.09),
				bright,
				Enum.Material.Metal
			)
			bolt.Shape = Enum.PartType.Ball
		end
	end

	for index = 1, 5 do
		part(
			model,
			"Vent recess",
			Vector3.new(size.X * 0.16, 0.025, 0.03),
			CFrame.new(-size.X * 0.22, height * (0.3 + index * 0.075), front),
			metal,
			Enum.Material.Metal
		)
	end
	part(
		model,
		"Inset faceplate",
		Vector3.new(size.X * 0.32, height * 0.52, 0.04),
		CFrame.new(size.X * 0.2, height * 0.5, front),
		metal,
		Enum.Material.Metal
	)
	part(
		model,
		"Lock status",
		Vector3.new(0.05, height * 0.3, 0.025),
		CFrame.new(size.X * 0.2, height * 0.5, front - 0.035),
		accent,
		Enum.Material.Neon
	)

	if skinId == "Reactor" or skinId == "Solar" or skinId == "Molten" then
		for index = 1, 3 do
			local coil = part(
				model,
				"Cooling pipe",
				Vector3.new(0.11, height * 0.65, 0.11),
				CFrame.new(halfWidth + 0.09, height * 0.5, (index - 2) * size.Z * 0.25),
				bright,
				Enum.Material.Metal
			)
			coil.Shape = Enum.PartType.Cylinder
			coil.CFrame *= CFrame.Angles(0, 0, math.pi * 0.5)
		end
	elseif skinId == "Glacier" or skinId == "Prism" or skinId == "Aurora" or skinId == "Crystal" then
		for index = 1, 3 do
			local crystal = part(
				model,
				"Cut crystal",
				Vector3.new(0.14, 0.3 + index * 0.07, 0.14),
				CFrame.new(halfWidth + 0.07, height * 0.42, (index - 2) * 0.24),
				accent,
				Enum.Material.Glass
			)
			crystal.CFrame *= CFrame.Angles(0.15 * index, 0.4, 0.2)
		end
	elseif skinId == "Titan" or skinId == "Obsidian" or skinId == "Salvage" then
		for _, side in { -1, 1 } do
			part(
				model,
				"Reinforced foot",
				Vector3.new(0.32, 0.12, size.Z * 1.1),
				CFrame.new(side * size.X * 0.33, 0.05, 0),
				metal,
				Enum.Material.DiamondPlate
			)
		end
	else
		local ring = part(
			model,
			"Instrument dial",
			Vector3.new(0.035, 0.3, 0.3),
			CFrame.new(halfWidth + 0.035, height * 0.6, 0),
			bright,
			Enum.Material.Metal
		)
		ring.Shape = Enum.PartType.Cylinder
	end
end

return table.freeze(Details)
