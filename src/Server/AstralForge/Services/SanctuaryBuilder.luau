--!strict
-- Builds the sanctuary around the original forge deck: terrain islands for
-- every region, the sky bridges between them, waystones, and each region's
-- scenery. The map itself (where everything goes) is SanctuaryLayout; this
-- module only turns it into terrain, meshes and parts. Models come from the
-- generated kit (AssetKit) when it is uploaded, with part-built stand-ins
-- otherwise; effects use Roblox's built-in particle textures (Vfx).
--
-- Anything that should move (spinning crowns, bobbing shards, pulsing lights)
-- is tagged, not scripted here: the client animates tagged parts locally
-- (sanctuaryWorld.luau), which is smooth on every client and costs the server
-- and the network nothing.
--
-- Tags:  AF_Spin  (Speed attribute, degrees/s around Y; World = true spins a
--                  tilted part about the world's up axis)
--        AF_Bob   (Amplitude, Period attributes, studs / seconds)
--        AF_Pulse (a PointLight/Neon part that breathes)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("SanctuaryLayout"))
local AssetKit = require(Shared:WaitForChild("AssetKit"))
local Vfx = require(Shared:WaitForChild("Vfx"))

local Builder = {}

local ORIGIN = Vector3.new(Layout.ORIGIN.X, Layout.ORIGIN.Y, Layout.ORIGIN.Z)

local STONE = Color3.fromRGB(78, 86, 104)
local STONE_DARK = Color3.fromRGB(44, 48, 60)
local EDGE_LIGHT = Color3.fromRGB(150, 214, 255)
local LAMP = Color3.fromRGB(120, 210, 255)
local EMBER = Color3.fromRGB(255, 130, 60)
local EMBER_HOT = Color3.fromRGB(255, 196, 110)
local VOID = Color3.fromRGB(150, 104, 255)
local VOID_SOFT = Color3.fromRGB(206, 172, 255)
local STAR = Color3.fromRGB(140, 220, 255)
local RIFT = Color3.fromRGB(120, 90, 255)

-- Terrain tints: only the sanctuary uses terrain, so these are safe to set.
local MATERIAL_COLORS = {
	[Enum.Material.Slate] = Color3.fromRGB(64, 70, 86),
	[Enum.Material.Basalt] = Color3.fromRGB(52, 46, 48),
	[Enum.Material.Rock] = Color3.fromRGB(44, 46, 56),
	[Enum.Material.Glacier] = Color3.fromRGB(118, 92, 176),
	[Enum.Material.Limestone] = Color3.fromRGB(150, 168, 196),
	[Enum.Material.Asphalt] = Color3.fromRGB(38, 38, 50),
	[Enum.Material.CrackedLava] = Color3.fromRGB(255, 110, 50),
}

local function world(p: Layout.Point): Vector3
	return ORIGIN + Vector3.new(p.X, p.Y, p.Z)
end

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value ~= nil then value else Enum.Material.Rock
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, mat: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function glow(p: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = p
	return light
end

local function tag(instance: Instance, name: string, attributes: { [string]: any }?)
	CollectionService:AddTag(instance, name)
	if attributes then
		for key, value in attributes do
			instance:SetAttribute(key, value)
		end
	end
end

------------------------------------------------------------------------
-- Terrain
------------------------------------------------------------------------

-- Plateau thickness, and the depth of each underside layer.
local PLATEAU_DEPTH = 12
local LAYER_HEIGHT = 14
local LAYER_STEP = 11
local UNDER_LAYERS = 6
-- Rim rocks and rim scenery stay this far (radians) from a bridge landing.
local LANDING_CLEAR = math.rad(26)

local function angleGap(a: number, b: number): number
	local d = (a - b) % (math.pi * 2)
	return math.min(d, math.pi * 2 - d)
end

-- Directions (radians, atan2(z, x)) in which bridges meet a region's rim.
local function landingAngles(region: Layout.Region): { number }
	if region.Id == "Heart" then
		local angles = {}
		for _, other in Layout.regions() do
			if other.Id ~= "Heart" then
				table.insert(angles, math.atan2(other.Center.Z - region.Center.Z, other.Center.X - region.Center.X))
			end
		end
		return angles
	end
	local _, dx, dz = Layout.landing(region)
	return { math.atan2(dz, dx) }
end

local function nearLanding(angle: number, landings: { number }): boolean
	for _, landing in landings do
		if angleGap(angle, landing) < LANDING_CLEAR then
			return true
		end
	end
	return false
end

-- One floating island: a flat plateau of `top` whose surface sits at the
-- region's height, a low rocky lip around the rim (open where bridges land),
-- and an underside of shrinking rock layers that taper to a point. Every fill
-- but the lip stays below the surface, so nothing ever bulges over the
-- plateau or the forge deck. Yields between layers so building the whole map
-- never stalls the server.
local function island(terrain: Terrain, center: Vector3, radius: number, top: Enum.Material, under: Enum.Material, seed: number, landings: { number })
	local rng = Random.new(seed)
	-- Underside: stacked discs, each narrower and lower, roughened with rocks.
	for k = 0, UNDER_LAYERS - 1 do
		local r = math.max(6, radius * (0.96 - 0.15 * k))
		local layerTop = -PLATEAU_DEPTH + 4 - k * LAYER_STEP
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, layerTop - LAYER_HEIGHT / 2, 0)), LAYER_HEIGHT, r, under)
		for _ = 1, 6 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local rock = rng:NextNumber(6, 12)
			local reach = math.max(0, r - rock * 0.5)
			-- Keep every rock's top at least 4 studs under the surface.
			local y = math.min(layerTop - LAYER_HEIGHT / 2 - rng:NextNumber(0, 8), -4 - rock)
			terrain:FillBall(center + Vector3.new(math.cos(angle) * reach, y, math.sin(angle) * reach), rock, under)
		end
		task.wait()
	end
	-- The point of the underside.
	local tip = radius * 0.1 + 4
	terrain:FillBall(center + Vector3.new(0, -PLATEAU_DEPTH + 4 - UNDER_LAYERS * LAYER_STEP - tip * 0.5, 0), tip, under)
	-- The walkable plateau.
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -PLATEAU_DEPTH / 2, 0)), PLATEAU_DEPTH, radius, top)
	-- A low lip of rock along the rim: at most ~2 studs proud of the surface,
	-- and never where a bridge lands.
	for k = 1, 14 do
		local angle = (k / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		if nearLanding(angle, landings) then
			continue
		end
		local rock = rng:NextNumber(5, 9)
		local reach = radius * rng:NextNumber(0.98, 1.03)
		terrain:FillBall(center + Vector3.new(math.cos(angle) * reach, -rock + rng:NextNumber(0.6, 2), math.sin(angle) * reach), rock, under)
	end
	task.wait()
end

-- Smaller rocks hanging below and around an island, out of reach.
local function islets(terrain: Terrain, center: Vector3, radius: number, top: Enum.Material, under: Enum.Material, seed: number)
	local rng = Random.new(seed)
	for k = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = radius + rng:NextNumber(40, 90)
		local depth = rng:NextNumber(34, 80)
		local r = rng:NextNumber(8, 17)
		local at = center + Vector3.new(math.cos(angle) * reach, -depth, math.sin(angle) * reach)
		terrain:FillBall(at + Vector3.new(0, -r * 0.5, 0), r, under)
		terrain:FillCylinder(CFrame.new(at + Vector3.new(0, -2, 0)), 4, r * 0.8, top)
	end
	task.wait()
end

function Builder.BuildTerrain()
	local terrain = Workspace.Terrain
	for mat, color in MATERIAL_COLORS do
		pcall(function()
			terrain:SetMaterialColor(mat, color)
		end)
	end
	for index, region in Layout.regions() do
		local center = world(region.Center)
		local top = material(region.Top)
		local under = material(region.Under)
		island(terrain, center, region.Radius, top, under, index * 7919, landingAngles(region))
		islets(terrain, center, region.Radius, top, under, index * 104729)
		if region.Id == "Emberreach" then
			-- Molten seams: lava patches flush with the plateau, clear of the
			-- ore rings and the landing.
			local rng = Random.new(31)
			local landings = landingAngles(region)
			for _ = 1, 9 do
				local angle = rng:NextNumber(0, math.pi * 2)
				if nearLanding(angle, landings) then
					continue
				end
				local reach = region.Radius * rng:NextNumber(0.52, 0.62)
				local size = rng:NextNumber(5, 9)
				terrain:FillCylinder(CFrame.new(center + Vector3.new(math.cos(angle) * reach, -1, math.sin(angle) * reach)), 2, size, Enum.Material.CrackedLava)
			end
			task.wait()
		elseif region.Id == "Spire" then
			-- The spire's stem: a column of rock hanging far below the plateau,
			-- every ball well under the surface.
			for k = 1, 6 do
				local r = region.Radius * (0.5 - 0.055 * k)
				terrain:FillBall(center + Vector3.new(0, -PLATEAU_DEPTH - r - k * 14, 0), r, under)
			end
			task.wait()
		end
	end
end

------------------------------------------------------------------------
-- Kit meshes and effects
------------------------------------------------------------------------

-- A kit mesh when the model kit is loaded (tools/assetgen), otherwise the
-- part-built fallback. Either way the result is parented and returned.
local function shape(parent: Instance, kitName: string, size: Vector3, cframe: CFrame, color: Color3, mat: Enum.Material, collide: boolean, fallback: () -> BasePart): BasePart
	local mesh = AssetKit.make(kitName, size, cframe, color, mat, collide)
	if mesh ~= nil then
		mesh.Parent = parent
		return mesh
	end
	return fallback()
end

-- An invisible volume that fills a region's air with drifting particles.
local function airborne(parent: Instance, name: string, center: Vector3, radius: number, preset: string, overrides: { [string]: any })
	local volume = part(parent, name, Vector3.new(radius * 1.5, 14, radius * 1.5), CFrame.new(center + Vector3.new(0, 9, 0)), Color3.new(), Enum.Material.SmoothPlastic, false)
	volume.Transparency = 1
	volume.CastShadow = false
	local emitter = Vfx.attach(volume, preset, overrides)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	return emitter
end

local function halo(p: BasePart, color: Color3, size: number)
	return Vfx.attach(p, "Halo", {
		Color = color,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size),
			NumberSequenceKeypoint.new(0.5, size * 1.12),
			NumberSequenceKeypoint.new(1, size),
		}),
	})
end

------------------------------------------------------------------------
-- Bridges
------------------------------------------------------------------------

local function lamp(parent: Instance, base: Vector3)
	local height = AssetKit.sized("Lantern", 1)
	local useKit = AssetKit.has("Lantern")
	shape(parent, "Lantern", height, CFrame.new(base + Vector3.new(0, height.Y / 2, 0)), STONE_DARK, Enum.Material.Metal, false, function()
		return part(parent, "LampPost", Vector3.new(0.6, 6, 0.6), CFrame.new(base + Vector3.new(0, 3, 0)), STONE_DARK, Enum.Material.Metal, false)
	end)
	local bulbAt = base + Vector3.new(0, if useKit then 5.85 else 6.4, 0)
	local bulb = part(parent, "LampGlow", Vector3.new(0.8, 0.8, 0.8), CFrame.new(bulbAt), LAMP, Enum.Material.Neon, false)
	bulb.Shape = Enum.PartType.Ball
	bulb.Transparency = 0.1
	bulb.CastShadow = false
	glow(bulb, LAMP, 1.1, 22)
	halo(bulb, LAMP, 2.6)
	tag(bulb, "AF_Pulse", { Period = 3.2 })
end

function Builder.BuildBridges(folder: Instance)
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = folder
	for _, bridge in Layout.bridges() do
		local model = Instance.new("Model")
		model.Name = `Bridge_{bridge.Region}`
		model.Parent = bridges
		local points = Layout.bridgePoints(bridge, 14)
		for index = 1, #points - 1 do
			local a, b = world(points[index]), world(points[index + 1])
			local length = (b - a).Magnitude
			-- Surface along the path; the slab hangs 0.7 below it.
			local frame = CFrame.lookAt((a + b) / 2, b)
			local deck = shape(model, "BridgeDeck", Vector3.new(bridge.Width, 1.4, length + 1.4), frame * CFrame.new(0, -0.7, 0), STONE, Enum.Material.Slate, true, function()
				return part(model, "Deck", Vector3.new(bridge.Width, 1.4, length + 1.4), frame * CFrame.new(0, -0.7, 0), STONE, Enum.Material.Slate)
			end)
			deck.Name = "Deck"
			deck.CastShadow = true
			for _, side in { -1, 1 } do
				local edge = part(model, "EdgeLight", Vector3.new(0.25, 0.2, length + 1.2), frame * CFrame.new(side * (bridge.Width / 2 - 0.3), 0.06, 0), EDGE_LIGHT, Enum.Material.Neon, false)
				edge.Transparency = 0.45
				edge.CastShadow = false
			end
			if index % 3 == 0 then
				local side = if (index // 3) % 2 == 0 then 1 else -1
				lamp(model, (frame * CFrame.new(side * (bridge.Width / 2 - 0.9), 0, 0)).Position)
			end
		end
	end
end

------------------------------------------------------------------------
-- Waystones
------------------------------------------------------------------------

function Builder.BuildWaystones(folder: Instance)
	local stones = Instance.new("Folder")
	stones.Name = "Waystones"
	stones.Parent = folder
	for _, stone in Layout.waystones() do
		local base = world(stone.Position)
		local model = Instance.new("Model")
		model.Name = `Waystone_{stone.Id}`
		model:SetAttribute("WaystoneId", stone.Id)
		model.Parent = stones
		local plinthSize = AssetKit.sized("Plinth", 1)
		shape(model, "Plinth", plinthSize, CFrame.new(base + Vector3.new(0, plinthSize.Y / 2, 0)), STONE_DARK, Enum.Material.Basalt, true, function()
			local p = part(model, "Plinth", Vector3.new(1.4, 7, 7), CFrame.new(base + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), STONE_DARK, Enum.Material.Basalt)
			p.Shape = Enum.PartType.Cylinder
			return p
		end)
		local obeliskSize = AssetKit.sized("Obelisk", 1.5)
		local useKit = AssetKit.has("Obelisk")
		local obeliskBase = if useKit then 1.35 else 1.3
		local pillar = shape(model, "Obelisk", obeliskSize, CFrame.new(base + Vector3.new(0, obeliskBase + obeliskSize.Y / 2, 0)) * CFrame.Angles(0, math.rad(45), 0), STONE, Enum.Material.Slate, true, function()
			return part(model, "Pillar", Vector3.new(2.4, 9, 2.4), CFrame.new(base + Vector3.new(0, 5.8, 0)) * CFrame.Angles(0, math.rad(45), 0), STONE, Enum.Material.Slate)
		end)
		pillar.Name = "Pillar"
		pillar.CastShadow = true
		local top = if useKit then obeliskBase + obeliskSize.Y else 10.3
		-- A glowing band around the stone, and a star turning above it.
		local band = shape(model, "Halo", Vector3.new(2.9, 0.25, 2.9), CFrame.new(base + Vector3.new(0, top * 0.62, 0)), LAMP, Enum.Material.Neon, false, function()
			return part(model, "Rune", Vector3.new(2.6, 0.35, 2.6), CFrame.new(base + Vector3.new(0, 7.4, 0)) * CFrame.Angles(0, math.rad(45), 0), LAMP, Enum.Material.Neon, false)
		end)
		band.Name = "Rune"
		band.Transparency = 0.2
		band.CastShadow = false
		tag(band, "AF_Pulse", { Period = 2.4 })
		local shardAt = CFrame.new(base + Vector3.new(0, top + 2.2, 0))
		local shard = shape(model, "Star", Vector3.new(1.8, 1.8, 1.8), shardAt, LAMP, Enum.Material.Neon, false, function()
			return part(model, "Shard", Vector3.new(1.6, 2.6, 1.6), shardAt * CFrame.Angles(0, 0, math.rad(45)), LAMP, Enum.Material.Neon, false)
		end)
		shard.Name = "Shard"
		shard.Transparency = 0.05
		shard.CastShadow = false
		glow(shard, LAMP, 1.6, 26)
		halo(shard, LAMP, 5)
		tag(shard, "AF_Spin", { Speed = 40 })
		tag(shard, "AF_Bob", { Amplitude = 0.6, Period = 3 })
		-- Motes rising off the plinth.
		local plinthTop = part(model, "Motes", Vector3.new(4, 0.2, 4), CFrame.new(base + Vector3.new(0, 1.5, 0)), LAMP, Enum.Material.SmoothPlastic, false)
		plinthTop.Transparency = 1
		local rising = Vfx.attach(plinthTop, "Rising", { Color = LAMP, Rate = 3, Speed = NumberRange.new(1.5, 3) })
		rising.Shape = Enum.ParticleEmitterShape.Box
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "WaystonePrompt"
		prompt.ActionText = "Travel"
		prompt.ObjectText = stone.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("WaystoneId", stone.Id)
		prompt.Parent = pillar
	end
end

------------------------------------------------------------------------
-- Region scenery
------------------------------------------------------------------------

local ROCKS = { "RockA", "RockB", "RockC" }

-- Weathered boulders along a region's rim (model kit only: blocky stand-ins
-- would look worse than none).
local function boulders(parent: Instance, center: Vector3, radius: number, landings: { number }, color: Color3, seed: number)
	if not AssetKit.has("RockA") then
		return
	end
	local rng = Random.new(seed)
	for k = 1, 16 do
		local angle = (k / 16) * math.pi * 2 + rng:NextNumber(-0.18, 0.18)
		if nearLanding(angle, landings) then
			continue
		end
		local name = ROCKS[rng:NextInteger(1, #ROCKS)]
		local size = AssetKit.sized(name, rng:NextNumber(2.2, 5.2))
		local reach = radius * rng:NextNumber(0.9, 0.99)
		local at = center + Vector3.new(math.cos(angle) * reach, size.Y * 0.2, math.sin(angle) * reach)
		local rock = AssetKit.make(name, size, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-8, 8))), color, Enum.Material.Rock, true)
		if rock ~= nil then
			rock.Name = "Boulder"
			rock.CastShadow = true
			rock.Parent = parent
		end
	end
end

local function emberreach(parent: Instance, center: Vector3, radius: number, landings: { number })
	local rng = Random.new(211)
	-- Basalt columns around the rim (the bridge landing stays open).
	for k = 1, 9 do
		local angle = (k / 9) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		if nearLanding(angle, landings) then
			continue
		end
		local reach = radius * rng:NextNumber(0.86, 0.97)
		local height = rng:NextNumber(14, 30)
		local yaw = rng:NextNumber(0, math.pi)
		local columnSize = AssetKit.sized("BasaltCluster", height / 4)
		local useKit = AssetKit.has("BasaltCluster")
		local at = center + Vector3.new(math.cos(angle) * reach, (if useKit then columnSize.Y else height) / 2 - 1, math.sin(angle) * reach)
		local spire = shape(parent, "BasaltCluster", columnSize, CFrame.new(at) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(46, 40, 42), Enum.Material.Basalt, true, function()
			return part(parent, "Spire", Vector3.new(rng:NextNumber(4, 7), height, rng:NextNumber(4, 7)), CFrame.new(at) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), yaw, math.rad(rng:NextNumber(-8, 8))), Color3.fromRGB(46, 40, 42), Enum.Material.Basalt)
		end)
		spire.Name = "Spire"
		spire.CastShadow = true
	end
	-- Lava vents: glowing cracks breathing fire, smoke and embers.
	for k = 1, 6 do
		local angle = (k / 6) * math.pi * 2 + 0.4
		if nearLanding(angle, landings) then
			continue
		end
		local reach = radius * (if k % 2 == 0 then 0.3 else 0.62)
		local at = center + Vector3.new(math.cos(angle) * reach, 0.05, math.sin(angle) * reach)
		local vent = part(parent, "Vent", Vector3.new(6, 0.3, 1.6), CFrame.new(at) * CFrame.Angles(0, angle, 0), EMBER, Enum.Material.Neon, false)
		vent.Transparency = 0.1
		vent.CastShadow = false
		glow(vent, EMBER, 2, 20)
		tag(vent, "AF_Pulse", { Period = 1.8 })
		Vfx.attach(vent, "Flame", { Color = EMBER_HOT, Color2 = EMBER, Rate = 9 })
		Vfx.attach(vent, "Smoke", { Color = Color3.fromRGB(60, 44, 40) })
		Vfx.attach(vent, "Embers", { Color = EMBER_HOT, Rate = 4 })
	end
	-- Embers drifting through the whole region.
	airborne(parent, "EmberAir", center, radius, "Embers", { Color = EMBER_HOT, Color2 = EMBER, Rate = 7, Speed = NumberRange.new(0.5, 1.5) })
	boulders(parent, center, radius, landings, Color3.fromRGB(58, 50, 50), 212)
end

local function hollows(parent: Instance, center: Vector3, radius: number, landings: { number })
	local rng = Random.new(307)
	-- Towering voidglass formations leaning outward (the bridge landing stays open).
	for k = 1, 8 do
		local angle = (k / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		if nearLanding(angle, landings) then
			continue
		end
		local reach = radius * rng:NextNumber(0.84, 0.95)
		local root = center + Vector3.new(math.cos(angle) * reach, -1, math.sin(angle) * reach)
		if AssetKit.has("VoidSpire") then
			local size = AssetKit.sized("VoidSpire", rng:NextNumber(2.6, 4.2))
			local frame = CFrame.new(root + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-10, 10)))
			local formation = AssetKit.make("VoidSpire", size, frame, VOID, Enum.Material.Glass, true)
			if formation ~= nil then
				formation.Name = "Voidglass"
				formation.Transparency = 0.18
				formation.Reflectance = 0.15
				formation.Parent = parent
				local heart = AssetKit.make("VoidSpire", size * 0.55, frame, VOID_SOFT, Enum.Material.Neon, false)
				if heart ~= nil then
					heart.Name = "VoidCore"
					heart.Transparency = 0.3
					heart.CastShadow = false
					heart.Parent = parent
					glow(heart, VOID, 1.4, 26)
					tag(heart, "AF_Pulse", { Period = 4.2 })
				end
			end
			continue
		end
		for c = 1, 3 do
			local height = rng:NextNumber(12, 28) * (if c == 1 then 1 else 0.6)
			local lean = CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-22, 22)))
			local crystal = part(parent, "Voidglass", Vector3.new(2.6, height, 2.6), CFrame.new(root) * lean * CFrame.new(0, height / 2, 0), VOID, Enum.Material.Glass)
			crystal.Transparency = 0.25
			crystal.Reflectance = 0.15
			local core = part(parent, "VoidCore", Vector3.new(0.9, height * 0.8, 0.9), crystal.CFrame, VOID_SOFT, Enum.Material.Neon, false)
			core.Transparency = 0.35
			core.CastShadow = false
			if c == 1 then
				glow(core, VOID, 1.4, 22)
				tag(core, "AF_Pulse", { Period = 4.2 })
			end
		end
	end
	-- Shards drifting above the plateau.
	for k = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local reach = radius * rng:NextNumber(0.2, 0.8)
		local at = CFrame.new(center + Vector3.new(math.cos(angle) * reach, rng:NextNumber(9, 20), math.sin(angle) * reach))
		local shard = shape(parent, "CrystalShard", AssetKit.sized("CrystalShard", 1.2), at, VOID_SOFT, Enum.Material.Neon, false, function()
			return part(parent, "DriftShard", Vector3.new(1, 2.4, 1), at * CFrame.Angles(0, 0, math.rad(45)), VOID_SOFT, Enum.Material.Neon, false)
		end)
		shard.Name = "DriftShard"
		shard.Transparency = 0.2
		shard.CastShadow = false
		tag(shard, "AF_Spin", { Speed = rng:NextNumber(18, 50) })
		tag(shard, "AF_Bob", { Amplitude = rng:NextNumber(0.8, 2), Period = rng:NextNumber(3, 6) })
	end
	airborne(parent, "VoidAir", center, radius, "Motes", { Color = VOID_SOFT, Color2 = VOID, Rate = 9 })
	boulders(parent, center, radius, landings, Color3.fromRGB(70, 62, 96), 308)
end

local function spire(parent: Instance, center: Vector3, radius: number, landings: { number })
	-- A tall tapering column with starsteel veins and a crown above it.
	local levels = 7
	for k = 0, levels - 1 do
		local w = 14 - k * 1.5
		local block = part(parent, "SpireStone", Vector3.new(w, 11, w), CFrame.new(center + Vector3.new(0, 5.5 + k * 10.5, 0)) * CFrame.Angles(0, math.rad(k * 13), 0), Color3.fromRGB(96, 110, 136), Enum.Material.Slate)
		block.CastShadow = true
		local vein = part(parent, "SpireVein", Vector3.new(w + 0.3, 0.4, w + 0.3), CFrame.new(center + Vector3.new(0, 10.8 + k * 10.5, 0)) * CFrame.Angles(0, math.rad(k * 13), 0), STAR, Enum.Material.Neon, false)
		vein.Transparency = 0.25
		vein.CastShadow = false
	end
	local crownAt = center + Vector3.new(0, 5.5 + levels * 10.5 + 8, 0)
	local crown = shape(parent, "Star", Vector3.new(6, 6, 6), CFrame.new(crownAt), STAR, Enum.Material.Neon, false, function()
		return part(parent, "Crown", Vector3.new(5, 7, 5), CFrame.new(crownAt) * CFrame.Angles(0, 0, math.rad(45)), STAR, Enum.Material.Neon, false)
	end)
	crown.Name = "Crown"
	crown.Transparency = 0.05
	crown.CastShadow = false
	glow(crown, STAR, 3, 60)
	halo(crown, STAR, 16)
	Vfx.attach(crown, "Motes", { Color = STAR, Rate = 6, Speed = NumberRange.new(1, 3) })
	tag(crown, "AF_Spin", { Speed = 22 })
	tag(crown, "AF_Bob", { Amplitude = 1.2, Period = 5 })
	for k = 1, 3 do
		local diameter = 12 + k * 4
		local tilt = CFrame.Angles(math.rad(60 + k * 12), math.rad(k * 50), 0)
		local ring = shape(parent, "Halo", Vector3.new(diameter, 0.5, diameter), CFrame.new(crownAt) * tilt, STAR, Enum.Material.Neon, false, function()
			local fallback = part(parent, "CrownRing", Vector3.new(0.4, diameter, diameter), CFrame.new(crownAt) * CFrame.Angles(math.rad(90), 0, 0), STAR, Enum.Material.Neon, false)
			fallback.Shape = Enum.PartType.Cylinder
			return fallback
		end)
		ring.Name = "CrownRing"
		ring.Transparency = if AssetKit.has("Halo") then 0.45 else 0.82
		ring.CastShadow = false
		-- Tilted rings turn about the world's up axis, not their own.
		tag(ring, "AF_Spin", { Speed = (if k % 2 == 0 then -1 else 1) * (12 + k * 6), World = true })
	end
	-- Lanterns around the plateau edge.
	for k = 1, 8 do
		local angle = (k / 8) * math.pi * 2
		lamp(parent, center + Vector3.new(math.cos(angle) * radius * 0.92, 0, math.sin(angle) * radius * 0.92))
	end
	airborne(parent, "StarAir", center, radius, "Motes", { Color = STAR, Rate = 5 })
	boulders(parent, center, radius, landings, Color3.fromRGB(128, 140, 164), 350)
end

function Builder.BuildArena(parent: Instance)
	local arena = Layout.arena()
	local center = world(arena.Center)
	-- The rune ring on the arena floor.
	local segments = 48
	for k = 1, segments do
		local angle = (k / segments) * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * (arena.Radius - 8), 0.08, math.sin(angle) * (arena.Radius - 8))
		local rune = part(parent, "Rune", Vector3.new(0.5, 0.15, (arena.Radius - 8) * math.pi * 2 / segments * 0.7), CFrame.lookAt(at, center) * CFrame.Angles(0, math.rad(90), 0), RIFT, Enum.Material.Neon, false)
		rune.Transparency = 0.3
		rune.CastShadow = false
	end
	local seal = part(parent, "Seal", Vector3.new(0.2, 26, 26), CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), RIFT, Enum.Material.Neon, false)
	seal.Shape = Enum.PartType.Cylinder
	seal.Transparency = 0.7
	seal.CastShadow = false
	tag(seal, "AF_Pulse", { Period = 3.6 })
	-- A slow vortex over the seal, and where the rift tethers meet.
	local eye = part(parent, "RiftEye", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), RIFT, Enum.Material.SmoothPlastic, false)
	eye.Transparency = 1
	Vfx.attach(eye, "Swirl", { Color = RIFT, Color2 = VOID_SOFT, Size = NumberSequence.new(22, 26) })
	local hub = Instance.new("Attachment")
	hub.Name = "TetherHub"
	hub.Position = Vector3.new(0, 24, 0)
	hub.Parent = seal
	-- Pillars ringing the arena, each topped with rift light.
	for k = 1, 8 do
		local angle = (k / 8) * math.pi * 2 + math.pi / 8
		local at = center + Vector3.new(math.cos(angle) * arena.PillarRadius, 0, math.sin(angle) * arena.PillarRadius)
		local pillarSize = AssetKit.sized("ArenaPillar", 1.05)
		local useKit = AssetKit.has("ArenaPillar")
		local height = if useKit then pillarSize.Y else 26
		local column = shape(parent, "ArenaPillar", pillarSize, CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, 0), Color3.fromRGB(40, 40, 54), Enum.Material.Basalt, true, function()
			return part(parent, "Pillar", Vector3.new(5, 26, 5), CFrame.new(at + Vector3.new(0, 13, 0)) * CFrame.Angles(0, angle, 0), Color3.fromRGB(40, 40, 54), Enum.Material.Basalt)
		end)
		column.Name = "Pillar"
		column.CastShadow = true
		local capAt = CFrame.new(at + Vector3.new(0, height + 2.5, 0))
		local cap = shape(parent, "Star", Vector3.new(3.2, 3.2, 3.2), capAt, RIFT, Enum.Material.Neon, false, function()
			return part(parent, "PillarLight", Vector3.new(3, 3, 3), capAt * CFrame.Angles(math.rad(45), 0, math.rad(45)), RIFT, Enum.Material.Neon, false)
		end)
		cap.Name = "PillarLight"
		cap.Transparency = 0.1
		cap.CastShadow = false
		glow(cap, RIFT, 1.8, 34)
		halo(cap, RIFT, 7)
		tag(cap, "AF_Spin", { Speed = 30 })
		tag(cap, "AF_Pulse", { Period = 2.8 })
		-- Rift tethers from every pillar to the seal; the client lights them
		-- while the Warden is forming or fighting.
		local from = Instance.new("Attachment")
		from.Name = "Tether"
		from.Parent = cap
		local beam = Vfx.beam(from, hub, "Tether", { Color = RIFT, Color2 = VOID_SOFT })
		beam.Enabled = false
		tag(beam, "AF_RiftTether")
	end
end

function Builder.BuildScenery(folder: Instance)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = folder
	for _, region in Layout.regions() do
		local center = world(region.Center)
		local model = Instance.new("Model")
		model.Name = `Region_{region.Id}`
		model:SetAttribute("RegionId", region.Id)
		model.Parent = scenery
		local landings = landingAngles(region)
		if region.Id == "Emberreach" then
			emberreach(model, center, region.Radius, landings)
		elseif region.Id == "Hollows" then
			hollows(model, center, region.Radius, landings)
		elseif region.Id == "Spire" then
			spire(model, center, region.Radius, landings)
		elseif region.Id == "Riftmaw" then
			Builder.BuildArena(model)
			boulders(model, center, region.Radius, landings, Color3.fromRGB(52, 50, 64), 404)
		else
			boulders(model, center, region.Radius, landings, Color3.fromRGB(70, 76, 92), 101)
		end
	end
end

-- The kit loads first (at most a few seconds, and not at all when none is
-- uploaded), then everything but terrain is built at once (parts are cheap);
-- terrain fills yield between islands. Each piece is built on its own guard:
-- a failure in one (say, scenery) is logged and the rest of the sanctuary --
-- and the game -- carries on.
function Builder.Build(folder: Instance)
	task.spawn(function()
		AssetKit.load(8)
		local steps: { { name: string, run: (Instance) -> () } } = {
			{ name = "bridges", run = Builder.BuildBridges },
			{ name = "waystones", run = Builder.BuildWaystones },
			{ name = "scenery", run = Builder.BuildScenery },
		}
		for _, step in steps do
			local ok, problem = pcall(step.run, folder)
			if not ok then
				warn(`[Sanctuary] {step.name} build failed: {problem}`)
			end
		end
		local ok, problem = pcall(Builder.BuildTerrain)
		if not ok then
			warn(`[Sanctuary] terrain build failed: {problem}`)
		end
	end)
end

return Builder
