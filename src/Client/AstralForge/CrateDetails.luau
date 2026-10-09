--!strict
-- Purpose: modeled crate armor, fasteners, seals and family-specific hardware.
-- Owner: presentation. Dependencies: viewport model and existing skin palette.
-- Review: 2026-10-05.

local Details = {}

export type LidPiece = { part: BasePart, offset: CFrame }

local LEGACY_FAMILY: { [string]: string } = {
	Reactor = "Furnace",
	Solar = "Furnace",
	Molten = "Furnace",
	Glacier = "Lens",
	Prism = "Lens",
	Aurora = "Lens",
	Crystal = "Lens",
	Titan = "Armory",
	Obsidian = "Armory",
	Salvage = "Armory",
	Storm = "Core",
	Lunar = "Glyph",
	DeepSea = "Pressure",
	Chrono = "Glyph",
}

local BODY_MATERIAL: { [string]: Enum.Material } = {
	Armory = Enum.Material.DiamondPlate,
	Furnace = Enum.Material.Basalt,
	Garden = Enum.Material.Glass,
	Pressure = Enum.Material.Metal,
	Glyph = Enum.Material.Slate,
	Pod = Enum.Material.Foil,
	Lens = Enum.Material.Glass,
	Core = Enum.Material.Metal,
	Halo = Enum.Material.Marble,
}

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
	item.CastShadow = false
	item.Parent = model
	return item
end

local function cylinder(model: Model, name: string, length: number, diameter: number, frame: CFrame, color: Color3, material: Enum.Material): Part
	local item = part(model, name, Vector3.new(length, diameter, diameter), frame, color, material)
	item.Shape = Enum.PartType.Cylinder
	return item
end

function Details.family(skinId: string, declared: string?): string
	if type(declared) == "string" and BODY_MATERIAL[declared] ~= nil then
		return declared
	end
	return LEGACY_FAMILY[skinId] or "Armory"
end

function Details.bodyMaterial(family: string): Enum.Material
	return BODY_MATERIAL[family] or Enum.Material.SmoothPlastic
end

function Details.build(model: Model, body: BasePart, accent: Color3, skinId: string, declared: string?): ()
	local family = Details.family(skinId, declared)
	local size = body.Size
	local metal = accent:Lerp(Color3.new(0, 0, 0), 0.72)
	local trim = accent:Lerp(Color3.fromRGB(40, 36, 48), 0.55)
	local bright = accent:Lerp(Color3.new(1, 1, 1), 0.3)
	local halfWidth = size.X * 0.5
	local halfDepth = size.Z * 0.5
	local front = -halfDepth - 0.025
	local height = size.Y

	part(model, "Plinth", Vector3.new(size.X + 0.12, 0.08, size.Z + 0.12), CFrame.new(0, 0.04, 0), metal, Enum.Material.Metal)
	for _, y in { height * 0.14, height * 0.92 } do
		part(model, "Trim band", Vector3.new(size.X + 0.04, 0.05, size.Z + 0.04), CFrame.new(0, y, 0), trim, Enum.Material.Metal)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(model, "Corner post", Vector3.new(0.1, height * 0.94, 0.1),
				CFrame.new(sx * (halfWidth - 0.02), height * 0.5, sz * (halfDepth - 0.02)), metal, Enum.Material.Metal)
		end
		for _, fraction in { 0.18, 0.5, 0.82 } do
			local bolt = part(model, "Hex fastener", Vector3.new(0.055, 0.055, 0.045),
				CFrame.new(sx * (halfWidth - 0.04), height * fraction, front - 0.06), bright, Enum.Material.Metal)
			bolt.Shape = Enum.PartType.Ball
		end
	end
	part(model, "Seam light", Vector3.new(size.X * 0.84, 0.022, 0.02), CFrame.new(0, height * 0.97, front - 0.01), accent, Enum.Material.Neon)
	part(model, "Lock plate", Vector3.new(0.34, 0.3, 0.05), CFrame.new(0, height * 0.72, front - 0.02), metal, Enum.Material.Metal)
	part(model, "Lock status", Vector3.new(0.14, 0.04, 0.025), CFrame.new(0, height * 0.72, front - 0.05), accent, Enum.Material.Neon)

	if family == "Furnace" then
		for index = 1, 3 do
			local coil = cylinder(model, "Cooling pipe", height * 0.65, 0.1,
				CFrame.new(halfWidth + 0.08, height * 0.5, (index - 2) * size.Z * 0.25) * CFrame.Angles(0, 0, math.pi * 0.5), bright, Enum.Material.Metal)
			coil.Name = "Cooling pipe"
		end
		for index = 1, 4 do
			part(model, "Vent glow", Vector3.new(size.X * 0.14, 0.03, 0.02),
				CFrame.new(-size.X * 0.24, height * (0.28 + index * 0.08), front - 0.01), accent, Enum.Material.Neon)
		end
	elseif family == "Lens" or family == "Garden" then
		for index = 1, 3 do
			local crystal = part(model, if family == "Garden" then "Leaf pane" else "Cut crystal", Vector3.new(0.14, 0.3 + index * 0.07, 0.14),
				CFrame.new(halfWidth + 0.07, height * 0.42, (index - 2) * 0.24) * CFrame.Angles(0.15 * index, 0.4, 0.2), accent, Enum.Material.Glass)
			crystal.Transparency = 0.15
		end
		part(model, "Inner glow", Vector3.new(size.X * 0.7, height * 0.5, size.Z * 0.7), CFrame.new(0, height * 0.5, 0), accent, Enum.Material.Neon).Transparency = 0.55
	elseif family == "Pressure" then
		for _, sx in { -1, 1 } do
			cylinder(model, "Ballast tank", size.Z * 0.9, 0.26, CFrame.new(sx * (halfWidth + 0.12), height * 0.36, 0) * CFrame.Angles(0, math.pi * 0.5, 0), metal, Enum.Material.Metal)
			cylinder(model, "Tank ring", 0.04, 0.3, CFrame.new(sx * (halfWidth + 0.12), height * 0.36, 0) * CFrame.Angles(0, math.pi * 0.5, 0), accent, Enum.Material.Neon)
		end
		local gauge = cylinder(model, "Pressure gauge", 0.04, 0.22, CFrame.new(-size.X * 0.26, height * 0.5, front - 0.02) * CFrame.Angles(0, math.pi * 0.5, 0), bright, Enum.Material.Glass)
		gauge.Transparency = 0.2
	elseif family == "Glyph" then
		for index = 1, 5 do
			part(model, "Glyph stroke", Vector3.new(0.035, 0.12 + (index % 3) * 0.05, 0.02),
				CFrame.new(-size.X * 0.34 + index * 0.1, height * 0.45, front - 0.012) * CFrame.Angles(0, 0, (index % 2 - 0.5) * 0.7), accent, Enum.Material.Neon)
		end
	elseif family == "Pod" then
		for _, sx in { -1, 1 } do
			local fin = part(model, "Stabilizer fin", Vector3.new(0.05, height * 0.6, size.Z * 0.6),
				CFrame.new(sx * (halfWidth + 0.06), height * 0.42, 0) * CFrame.Angles(0, 0, sx * -0.18), bright, Enum.Material.Foil)
			fin.Name = "Stabilizer fin"
		end
		cylinder(model, "Thruster", 0.16, 0.36, CFrame.new(0, -0.02, 0) * CFrame.Angles(0, 0, math.pi * 0.5), metal, Enum.Material.Metal)
	elseif family == "Core" then
		local ring = cylinder(model, "Core ring", 0.05, height * 0.8, CFrame.new(0, height * 0.5, front - 0.03) * CFrame.Angles(0, math.pi * 0.5, 0), accent, Enum.Material.Neon)
		ring.Transparency = 0.1
		cylinder(model, "Core cap", 0.06, height * 0.5, CFrame.new(0, height * 0.5, front - 0.05) * CFrame.Angles(0, math.pi * 0.5, 0), metal, Enum.Material.Metal)
	elseif family == "Halo" then
		local halo = cylinder(model, "Halo ring", 0.03, size.X * 1.35, CFrame.new(0, height * 0.55, 0) * CFrame.Angles(0, 0, math.pi * 0.5), accent, Enum.Material.Neon)
		halo.Transparency = 0.25
		for _, sx in { -1, 1 } do
			part(model, "Gilt pillar", Vector3.new(0.12, height * 1.02, 0.12), CFrame.new(sx * (halfWidth + 0.02), height * 0.5, front + 0.04), bright, Enum.Material.Foil)
		end
	else
		for _, sx in { -1, 1 } do
			part(model, "Reinforced foot", Vector3.new(0.32, 0.12, size.Z * 1.1), CFrame.new(sx * size.X * 0.33, 0.05, 0), metal, Enum.Material.DiamondPlate)
			part(model, "Strap", Vector3.new(0.12, height * 0.9, size.Z + 0.06), CFrame.new(sx * size.X * 0.26, height * 0.5, 0), trim, Enum.Material.Metal)
		end
	end
end

function Details.buildLid(model: Model, lid: BasePart, accent: Color3, skinId: string, declared: string?): { LidPiece }
	local family = Details.family(skinId, declared)
	local size = lid.Size
	local metal = accent:Lerp(Color3.new(0, 0, 0), 0.7)
	local bright = accent:Lerp(Color3.new(1, 1, 1), 0.35)
	local pieces: { LidPiece } = {}
	local function add(name: string, partSize: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?)
		local item = part(model, name, partSize, lid.CFrame * offset, color, material)
		if shape then
			item.Shape = shape
		end
		table.insert(pieces, { part = item, offset = offset })
		return item
	end
	add("Lid rim", Vector3.new(size.X + 0.05, 0.05, size.Z + 0.05), CFrame.new(0, -size.Y * 0.5 + 0.03, 0), metal, Enum.Material.Metal)
	add("Lid ridge", Vector3.new(size.X * 0.9, 0.06, 0.12), CFrame.new(0, size.Y * 0.5 + 0.02, 0), bright, Enum.Material.Metal)
	add("Lid seam", Vector3.new(size.X * 0.7, 0.02, 0.02), CFrame.new(0, size.Y * 0.5 + 0.055, 0), accent, Enum.Material.Neon)
	add("Latch", Vector3.new(0.2, 0.18, 0.05), CFrame.new(0, -size.Y * 0.2, -size.Z * 0.5 - 0.03), metal, Enum.Material.Metal)
	if family == "Halo" or family == "Core" then
		add("Crown gem", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, size.Y * 0.5 + 0.13, 0) * CFrame.Angles(math.pi * 0.25, 0, math.pi * 0.25), accent, Enum.Material.Neon)
	elseif family == "Lens" or family == "Garden" then
		local dome = add("Glass dome", Vector3.new(size.X * 0.5, size.X * 0.5, size.X * 0.5), CFrame.new(0, size.Y * 0.5, 0), accent, Enum.Material.Glass, Enum.PartType.Ball)
		dome.Transparency = 0.45
	elseif family == "Furnace" then
		add("Chimney", Vector3.new(0.12, 0.16, 0.16), CFrame.new(size.X * 0.3, size.Y * 0.5 + 0.08, 0) * CFrame.Angles(0, 0, math.pi * 0.5), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif family == "Pod" or family == "Pressure" then
		for _, sx in { -1, 1 } do
			add("Valve", Vector3.new(0.06, 0.12, 0.12), CFrame.new(sx * size.X * 0.32, size.Y * 0.5 + 0.03, 0) * CFrame.Angles(0, 0, math.pi * 0.5), bright, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	return pieces
end

return table.freeze(Details)
