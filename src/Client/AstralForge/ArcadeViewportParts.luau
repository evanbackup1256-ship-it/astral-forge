--!strict
-- Purpose: Shared geometry helpers for bespoke arcade previews.
-- Owner: Astral Forge presentation. Dependencies: CoreKit palette. Last-reviewed: 2026-10-07.

local Palette: { [string]: Color3 } = require(script.Parent.CoreKit)("theme").Palette

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	frame: CFrame,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.CFrame = frame
	part.Shape = shape or Enum.PartType.Block
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function slab(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	z: number,
	color: Color3,
	depth: number?
): Part
	return makePart(parent, name, Vector3.new(x, y, depth or 0.16), color, CFrame.new(0, 0, z))
end

local function sphere(
	parent: Instance,
	name: string,
	size: number,
	color: Color3,
	x: number,
	y: number,
	z: number
): Part
	return makePart(
		parent,
		name,
		Vector3.one * size,
		color,
		CFrame.new(x, y, z),
		Enum.PartType.Ball,
		Enum.Material.Neon
	)
end

local function disk(parent: Instance, name: string, radius: number, depth: number, color: Color3, z: number): Part
	return makePart(
		parent,
		name,
		Vector3.new(depth, radius * 2, radius * 2),
		color,
		CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0),
		Enum.PartType.Cylinder,
		Enum.Material.Metal
	)
end

local function addLine(parent: Instance, name: string, from: Vector3, to: Vector3, width: number, color: Color3): Part
	local delta = to - from
	local frame = CFrame.lookAt((from + to) * 0.5, to) * CFrame.Angles(0, math.pi / 2, 0)
	return makePart(
		parent,
		name,
		Vector3.new(delta.Magnitude, width, width),
		color,
		frame,
		Enum.PartType.Cylinder,
		Enum.Material.Neon
	)
end

local function chipStack(parent: Instance, x: number, y: number, count: number, color: Color3): ()
	for index = 1, count do
		local chip = slab(parent, `Chip_{x}_{index}`, 0.42, 0.09, 0.34 + index * 0.035, color, 0.08)
		chip.CFrame = CFrame.new(x, y + index * 0.1, 0.34 + index * 0.035)
	end
	local topper = sphere(parent, `ChipCore_{x}`, 0.12, Palette.cream, x, y + count * 0.1 + 0.08, 0.5)
	topper.Material = Enum.Material.SmoothPlastic
end

local function card(parent: Instance, name: string, x: number, y: number, z: number, tint: Color3, angle: number?): Part
	local frame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, angle or 0)
	local value = makePart(parent, name, Vector3.new(0.64, 0.9, 0.055), Palette.cream, frame)
	makePart(
		parent,
		name .. "_Pip",
		Vector3.new(0.12, 0.12, 0.025),
		tint,
		frame * CFrame.new(-0.17, 0.26, -0.045) * CFrame.Angles(0, 0, math.pi / 4)
	)
	return value
end

local function dice(parent: Instance, name: string, x: number, y: number, color: Color3, seed: number): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local cube = makePart(model, "IvoryDie", Vector3.new(0.72, 0.72, 0.72), color, CFrame.new(x, y, 0.65))
	local pipCount = math.clamp(seed, 1, 6)
	local offsets = {
		Vector2.new(0, 0),
		Vector2.new(-0.19, -0.19),
		Vector2.new(0.19, 0.19),
		Vector2.new(-0.19, 0.19),
		Vector2.new(0.19, -0.19),
		Vector2.new(-0.19, 0),
		Vector2.new(0.19, 0),
	}
	local patterns = {
		{ 1 },
		{ 2, 3 },
		{ 2, 1, 3 },
		{ 2, 3, 4, 5 },
		{ 2, 3, 4, 5, 1 },
		{ 2, 3, 4, 5, 6, 7 },
	}
	for _, index in patterns[pipCount] do
		local offset = offsets[index]
		makePart(
			model,
			"Pip",
			Vector3.new(0.105, 0.105, 0.025),
			Palette.ink,
			CFrame.new(x + offset.X, y + offset.Y, 0.28),
			Enum.PartType.Ball
		)
	end
	model.PrimaryPart = cube
	return model
end


return table.freeze({
	makePart = makePart,
	slab = slab,
	sphere = sphere,
	disk = disk,
	addLine = addLine,
	chipStack = chipStack,
	card = card,
	dice = dice,
})
