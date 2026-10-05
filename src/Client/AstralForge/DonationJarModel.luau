--!nonstrict
local Palette = require(script.Parent.CoreKit)("theme").Palette

local JarModel = {}

local function createPart(parent, size, color, transform, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.CFrame = transform
	part.Material = material or Enum.Material.Metal
	part.Shape = shape or Enum.PartType.Block
	part.Parent = parent
	return part
end

local function createDisc(parent, radius, thickness, color, transform)
	return createPart(
		parent,
		Vector3.new(thickness, radius * 2, radius * 2),
		color,
		transform * CFrame.Angles(0, 0, math.pi / 2),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end

local function createRing(parent, radius, height, thickness, color, material)
	for segment = 0, 31 do
		local angle = segment * math.tau / 32
		createPart(
			parent,
			Vector3.new(radius * math.tau / 32 + 0.025, thickness, 0.08),
			color,
			CFrame.new(math.sin(angle) * radius, height, math.cos(angle) * radius) * CFrame.Angles(0, angle, 0),
			material
		)
	end
end

local function createCoin(parent, index)
	local coin = Instance.new("Model")
	coin.Name = "ForgeCoin"
	coin.Parent = parent
	coin.WorldPivot = CFrame.identity

	local coinColor = if index % 6 == 0 then Palette.cyan else Color3.fromRGB(226, 169, 67)
	local edge = createDisc(coin, 0.22, 0.07, coinColor, CFrame.identity)
	edge.Reflectance = 0.2
	createDisc(coin, 0.175, 0.075, coinColor:Lerp(Palette.cream, 0.16), CFrame.identity)
	createPart(
		coin,
		Vector3.new(0.09, 0.012, 0.09),
		Palette.cream,
		CFrame.new(0, 0.045, 0) * CFrame.Angles(0, math.pi / 4, 0)
	)
	return coin
end

function JarModel.build(world)
	local body = Instance.new("Model")
	body.Name = "CrystalDonationJar"
	body.Parent = world
	body.WorldPivot = CFrame.identity

	-- A shaped glass body, rather than a straight cylinder with a flat cap.
	local silhouette = {
		{ -1.35, 0.78 },
		{ -1.15, 0.98 },
		{ 0.72, 0.98 },
		{ 1.02, 0.83 },
		{ 1.22, 0.68 },
	}
	for layer = 1, #silhouette - 1 do
		local lower = silhouette[layer]
		local upper = silhouette[layer + 1]
		local radius = (lower[2] + upper[2]) / 2
		local verticalSpan = upper[1] - lower[1]
		local radiusChange = upper[2] - lower[2]
		local panelHeight = math.sqrt(verticalSpan ^ 2 + radiusChange ^ 2)

		for segment = 0, 31 do
			local angle = segment * math.tau / 32
			local panel = createPart(
				body,
				Vector3.new(radius * math.tau / 32 + 0.01, panelHeight, 0.025),
				Color3.fromRGB(175, 231, 242),
				CFrame.new(math.sin(angle) * radius, (lower[1] + upper[1]) / 2, math.cos(angle) * radius)
					* CFrame.Angles(0, angle, 0)
					* CFrame.Angles(math.atan2(radiusChange, verticalSpan), 0, 0),
				Enum.Material.Glass
			)
			panel.Transparency = if segment % 8 == 0 then 0.63 else 0.89
		end
	end

	createDisc(body, 0.85, 0.13, Palette.steel, CFrame.new(0, -1.4, 0))
	createDisc(body, 0.74, 0.08, Palette.panelRaised, CFrame.new(0, -1.49, 0))
	createRing(body, 0.83, -1.31, 0.065, Palette.mango)
	createRing(body, 0.7, 1.23, 0.13, Palette.steel)
	createRing(body, 0.71, 1.3, 0.045, Palette.mango)
	createRing(body, 0.86, -1.46, 0.025, Palette.cyan, Enum.Material.Neon)

	for index = 1, 28 do
		local angle = index * 2.39996
		local radius = 0.69 * math.sqrt((index % 9) / 9)
		local coin = createCoin(body, index)
		coin:PivotTo(
			CFrame.new(math.cos(angle) * radius, -1.2 + math.floor(index / 8) * 0.15, math.sin(angle) * radius)
				* CFrame.Angles(0.08 * (index % 3), angle, 0.07)
		)
	end

	local falling = {}
	for index = 1, 16 do
		local coin = createCoin(world, index)
		table.insert(falling, coin)
	end

	local sparks = {}
	for index = 1, 12 do
		local spark = createPart(
			world,
			Vector3.one * 0.055,
			if index % 2 == 0 then Palette.mango else Palette.cyan,
			CFrame.identity,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		table.insert(sparks, spark)
	end

	return {
		update = function(progress)
			local impulse = math.sin(progress * math.pi)
			body:PivotTo(CFrame.Angles(0, 0, math.sin(progress * 34) * 0.025 * impulse))

			for index, coin in falling do
				local travel = math.clamp(progress * 2.8 - (index - 1) * 0.085, 0, 1)
				local shown = travel > 0 and travel < 1
				for _, coinPart in coin:GetChildren() do
					coinPart.Transparency = if shown then 0 else 1
				end
				local spread = math.sin(travel * math.pi) * (0.18 + index % 3 * 0.1)
				coin:PivotTo(
					CFrame.new(spread * math.sin(index * 2.4), 3.6 - travel ^ 2 * 4.5, spread * math.cos(index * 2.4))
						* CFrame.Angles(travel * math.tau * 2, index, travel * 0.5)
				)
			end

			for index, spark in sparks do
				local angle = index * math.tau / #sparks + progress * math.tau
				local radius = 0.75 + impulse * 0.85
				spark.CFrame =
					CFrame.new(math.sin(angle) * radius, 1 + impulse * math.sin(index), math.cos(angle) * radius)
				spark.Transparency = 1 - impulse * 0.85
			end
		end,
	}
end

return JarModel
