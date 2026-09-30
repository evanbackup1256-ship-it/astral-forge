--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local SanctuaryLayout = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SanctuaryLayout"))
local SanctuaryBuilder = require(script.Parent:WaitForChild("SanctuaryBuilder"))

-- Seconds of movement grace a server teleport grants (CharacterIntegrity reads it).
local TELEPORT_GRACE_SECONDS = 2
-- Waystone travel: how close you must stand, and how often you can go.
local WAYSTONE_REACH = 18
local TRAVEL_COOLDOWN = 2
local RECALL_COOLDOWN = 8

return function()
	local WorldService = {}
	WorldService.__index = WorldService

	local PLOT_SIZE_X = 72
	local PLOT_SIZE_Z = 56
	local PLOT_SPACING_X = 96
	local PLOT_SPACING_Z = 80
	local BASE_Y = 64

	local function createBasePlate(name: string): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = true
		part.Size = Vector3.new(PLOT_SIZE_X, 4, PLOT_SIZE_Z)
		part.Position = Vector3.zero
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		return part
	end

	local function attachCollectPrompt(part: Part, player: Player, handler: any)
		local existing = part:FindFirstChild("CollectPrompt")
		if existing then
			existing:Destroy()
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CollectPrompt"
		prompt.ActionText = "Collect Flux"
		prompt.ObjectText = "Forge"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 18
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Enabled = true
		prompt.Parent = part
		prompt.Triggered:Connect(function(triggerPlayer: Player)
			if triggerPlayer ~= player then
				return
			end
			if type(handler) == "function" then
				handler(player, "Collect", {})
			end
		end)
		return prompt
	end

	local SANCTUARY_ORIGIN = Vector3.new(1680, 248, -220)
	local PATH = Color3.fromRGB(88, 98, 120)
	local DECK = Color3.fromRGB(61, 70, 88)
	local DARK = Color3.fromRGB(34, 40, 52)
	local ROCK = Color3.fromRGB(50, 54, 64)
	local LIP = Color3.fromRGB(73, 82, 100)
	local CYAN = Color3.fromRGB(64, 224, 255)
	local MINT = Color3.fromRGB(80, 238, 180)

	local function sanctuaryPart(parent: Instance, className: string, name: string, size: Vector3, center: Vector3, yaw: number, color: Color3, material: Enum.Material, collide: boolean): BasePart
		local part = Instance.new(className) :: BasePart
		part.Name = name
		part.Anchored = true
		part.CanCollide = collide
		part.Size = size
		part.Color = color
		part.Material = material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(SANCTUARY_ORIGIN + center) * CFrame.Angles(0, math.rad(yaw), 0)
		part.Parent = parent
		return part
	end

	local function topPart(parent: Instance, className: string, name: string, size: Vector3, top: Vector3, yaw: number, color: Color3, material: Enum.Material, collide: boolean): BasePart
		local center = Vector3.new(top.X, top.Y - size.Y * 0.5, top.Z)
		return sanctuaryPart(parent, className, name, size, center, yaw, color, material, collide)
	end

	local function uprightCylinder(parent: Instance, name: string, diameter: number, height: number, center: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Anchored = true
		part.CanCollide = collide
		part.Size = Vector3.new(height, diameter, diameter)
		part.Color = color
		part.Material = material
		part.CFrame = CFrame.new(SANCTUARY_ORIGIN + center) * CFrame.Angles(0, 0, math.rad(90))
		part.Parent = parent
		return part
	end

	local function sanctuaryBall(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Anchored = true
		part.CanCollide = collide
		part.Size = Vector3.new(diameter, diameter, diameter)
		part.Color = color
		part.Material = material
		part.CFrame = CFrame.new(SANCTUARY_ORIGIN + center)
		part.Parent = parent
		return part
	end

	local function buildSanctuary(folder: Folder): (CFrame, number)
		local model = Instance.new("Model")
		model.Name = "Sanctuary"
		model.Parent = folder

		-- Layout, south (spawn) to north (altar):
		--   a broken causeway of floating slabs -> a wide ring terrace -> the
		--   altar on a raised dais at the north end, ringed by standing stones.
		-- The overlook camera sits ~24 studs behind spawn and ~14 up, so the
		-- south approach stays low and nothing tall blocks the establishing shot.

		------------------------------------------------------------------
		-- Causeway: floating slabs with real gaps, so the walk in has rhythm.
		------------------------------------------------------------------
		topPart(model, "Part", "CausewayStart", Vector3.new(16, 3.2, 14), Vector3.new(0, 0, 30), 2, PATH, Enum.Material.Slate, true)
		topPart(model, "Part", "CausewayA", Vector3.new(11, 2.8, 9), Vector3.new(-3.2, 0.25, 21), -7, PATH, Enum.Material.Slate, true)
		topPart(model, "Part", "CausewayB", Vector3.new(10, 2.8, 8), Vector3.new(3.6, 0.55, 14.5), 9, PATH, Enum.Material.Cobblestone, true)
		topPart(model, "Part", "CausewayC", Vector3.new(12, 2.8, 9), Vector3.new(-1.4, 0.85, 8), -4, PATH, Enum.Material.Slate, true)
		-- Two drifting stones off the causeway: optional footing, and they give
		-- the void beneath a sense of depth.
		topPart(model, "Part", "DriftEast", Vector3.new(5, 1.8, 4.5), Vector3.new(11.5, -1.2, 18), 16, ROCK, Enum.Material.Rock, true)
		topPart(model, "Part", "DriftWest", Vector3.new(4.4, 1.6, 4), Vector3.new(-11.8, -2.4, 12.5), -22, ROCK, Enum.Material.Rock, true)

		------------------------------------------------------------------
		-- Terrace: the main ring the player actually walks on.
		------------------------------------------------------------------
		topPart(model, "Part", "Terrace", Vector3.new(34, 3.4, 30), Vector3.new(0, 1.2, -3), 0, DECK, Enum.Material.Basalt, true)
		topPart(model, "Part", "TerraceWest", Vector3.new(12, 3.4, 16), Vector3.new(-20, 1.2, -2), 6, DECK, Enum.Material.Basalt, true)
		topPart(model, "Part", "TerraceEast", Vector3.new(12, 3.4, 16), Vector3.new(20, 1.2, -4), -6, DECK, Enum.Material.Basalt, true)
		-- Cantilevered overlooks: nothing under the outer edge, which is what
		-- makes standing on them feel precarious.
		topPart(model, "Part", "OverlookWest", Vector3.new(13, 0.8, 11), Vector3.new(-28.5, 0.9, 2), 12, LIP, Enum.Material.Slate, true)
		topPart(model, "Part", "OverlookEast", Vector3.new(12, 0.8, 10), Vector3.new(28, 0.9, -9), -14, LIP, Enum.Material.Slate, true)

		-- Keel: the underside mass. Without this the terrace reads as a decal.
		topPart(model, "Part", "Keel", Vector3.new(30, 14, 26), Vector3.new(0, -2.2, -3), 0, DARK, Enum.Material.Basalt, true)
		topPart(model, "Part", "KeelWest", Vector3.new(13, 10, 14), Vector3.new(-18, -3.6, -1), 8, DARK, Enum.Material.Rock, true)
		topPart(model, "Part", "KeelEast", Vector3.new(13, 10, 14), Vector3.new(18, -3.8, -4), -8, DARK, Enum.Material.Rock, true)
		topPart(model, "Part", "KeelTail", Vector3.new(14, 8, 16), Vector3.new(0, -4.2, 20), 3, DARK, Enum.Material.Rock, true)
		topPart(model, "Part", "KeelSpike", Vector3.new(7, 16, 7), Vector3.new(-2, -9, -6), 18, DARK, Enum.Material.Basalt, false)

		------------------------------------------------------------------
		-- Dais and altar at the north end.
		------------------------------------------------------------------
		local daisTop = 4.2
		topPart(model, "Part", "Dais", Vector3.new(20, 3, 16), Vector3.new(0, daisTop, -16), 0, DECK, Enum.Material.Basalt, true)
		topPart(model, "Part", "DaisStep", Vector3.new(24, 1.5, 4), Vector3.new(0, 2.7, -7.5), 0, LIP, Enum.Material.Slate, true)

		-- Standing stones ringing the dais. Staggered heights and yaws so the
		-- ring reads as carved rather than as a turntable of identical props.
		-- { x, z, height, yaw, base }: base is the surface the stone stands on.
		-- The dais spans x -10..10, z -24..-8; the flanking pair sit past its
		-- edge, so they root on the terrace (and run taller to keep their tops).
		local terraceTop = 1.2
		local stoneRing = {
			{ -8.5, -22.5, 7.5, 14, daisTop },
			{ 0.5, -22.8, 9.5, -8, daisTop },
			{ 9, -22, 8.2, 22, daisTop },
			{ -11.5, -14, 6.4 + daisTop - terraceTop, -18, terraceTop },
			{ 11.5, -13, 6.8 + daisTop - terraceTop, 9, terraceTop },
		}
		for index, stone in stoneRing do
			local height = stone[3]
			local base = stone[5]
			topPart(
				model,
				"Part",
				`Stone{index}`,
				Vector3.new(2.6, height, 2.2),
				Vector3.new(stone[1], base + height, stone[2]),
				stone[4],
				ROCK,
				Enum.Material.Rock,
				true
			)
			-- A lit band near the top of each stone, so the ring glows at night.
			local band = topPart(
				model,
				"Part",
				`StoneGlow{index}`,
				Vector3.new(2.75, 0.35, 2.35),
				Vector3.new(stone[1], base + height - 1.1, stone[2]),
				stone[4],
				CYAN,
				Enum.Material.Neon,
				false
			)
			band.Transparency = 0.25
			band.CastShadow = false
		end

		-- The rift crack running up the dais into the altar. It stops at the
		-- dais's south edge (z = -8) so it never overhangs the lower step.
		local crack = topPart(model, "Part", "RiftCrack", Vector3.new(0.45, 0.18, 9), Vector3.new(0, daisTop + 0.02, -12.5), 0, CYAN, Enum.Material.Neon, false)
		crack.Transparency = 0.3
		crack.CastShadow = false

		uprightCylinder(model, "AltarPlinth", 6.5, 1.3, Vector3.new(0, daisTop + 0.65, -17), DECK, Enum.Material.Basalt, true)
		uprightCylinder(model, "AltarCup", 4.2, 0.5, Vector3.new(0, daisTop + 1.55, -17), DARK, Enum.Material.Slate, true)
		local flame = sanctuaryBall(model, "AltarFlame", 1.9, Vector3.new(0, daisTop + 2.5, -17), MINT, Enum.Material.Neon, false)
		flame.Transparency = 0.18
		flame.CastShadow = false
		local flameLight = Instance.new("PointLight")
		flameLight.Color = CYAN
		flameLight.Brightness = 2.2
		flameLight.Range = 42
		flameLight.Shadows = false
		flameLight.Parent = flame

		-- Halo above the flame: reads from across the terrace and marks the altar
		-- as the objective without needing a UI arrow.
		local halo = topPart(model, "Part", "AltarHalo", Vector3.new(7.5, 0.22, 7.5), Vector3.new(0, daisTop + 5.4, -17), 0, CYAN, Enum.Material.Neon, false)
		halo.Transparency = 0.62
		halo.CastShadow = false

		-- Lamps along the causeway so the walk in is lit and readable.
		local lamps = { { -6.5, 24 }, { 6.5, 17 }, { -6, 9 }, { 13, -2 }, { -13, -4 } }
		for index, lamp in lamps do
			uprightCylinder(model, `LampPost{index}`, 0.7, 4.6, Vector3.new(lamp[1], 2.3, lamp[2]), DARK, Enum.Material.Metal, false)
			local bulb = sanctuaryBall(model, `LampBulb{index}`, 1.1, Vector3.new(lamp[1], 4.9, lamp[2]), CYAN, Enum.Material.Neon, false)
			bulb.Transparency = 0.24
			bulb.CastShadow = false
			local light = Instance.new("PointLight")
			light.Color = CYAN
			light.Brightness = 1.1
			light.Range = 20
			light.Shadows = false
			light.Parent = bulb
		end

		-- Scatter: small rocks break up the flat deck silhouette.
		-- { x, z, width, height, depth, surface }: surface is the top of the slab
		-- underneath (terrace 1.2, CausewayA 0.25, CausewayB 0.55) so each rock
		-- rests on the ground instead of hovering above it.
		local scatter = {
			{ 14.5, -1.5, 2.2, 1.1, 1.9, terraceTop },
			{ -15.5, 1.5, 1.8, 0.9, 1.6, terraceTop },
			{ 6, 13, 1.6, 0.8, 1.4, 0.55 },
			{ -6, 19.5, 1.4, 0.7, 1.3, 0.25 },
			{ 17, -10, 2.4, 1.2, 2.1, terraceTop },
			{ -17.5, -9, 2, 1, 1.8, terraceTop },
		}
		for index, rock in scatter do
			topPart(
				model,
				"Part",
				`Scatter{index}`,
				Vector3.new(rock[3], rock[4], rock[5]),
				Vector3.new(rock[1], rock[6] + rock[4], rock[2]),
				index * 37 % 90 - 45,
				ROCK,
				Enum.Material.Rock,
				false
			)
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SanctuaryClose"
		prompt.ActionText = "Seal the rift"
		prompt.ObjectText = "Forge altar"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 16
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Parent = flame

		-- SpawnLocation so LoadCharacter does not drop the avatar at the origin.
		-- The part name stays Spawn. It sits on the causeway's first slab, facing
		-- the altar, so entering the rift always frames the walk north.
		local spawn = sanctuaryPart(model, "SpawnLocation", "Spawn", Vector3.new(6, 1, 6), Vector3.new(0, 3.3, 30), 0, DECK, Enum.Material.SmoothPlastic, false)
		spawn.Transparency = 1
		spawn.CanQuery = false
		spawn.CanTouch = false
		if spawn:IsA("SpawnLocation") then
			spawn.Neutral = true
			spawn.Duration = 0
			spawn.AllowTeamChangeOnTouch = false
			spawn.Enabled = true
		end
		local look = SANCTUARY_ORIGIN + Vector3.new(0, daisTop + 2.5, -17)
		spawn.CFrame = CFrame.lookAt(spawn.Position, look)

		return spawn.CFrame, SANCTUARY_ORIGIN.Y
	end

	function WorldService.new()
		local self = setmetatable({}, WorldService)
		self._interactionHandler = nil
		self._plots = {}
		self._plotIndex = {}
		self._folder = nil
		self._sanctuary = {}
		self._charConns = {}
		self._spawn = nil
		self._spawnPart = nil
		self._originY = 0
		self._heartbeat = nil
		self._playerRemoving = nil
		self._loadQueue = {}
		self._loadError = {}
		self._loaderAlive = false
		self._enterGen = {}
		self._brokenSince = {}
		self._loading = {}
		return self
	end

	function WorldService:Start()
		local oldWorld = workspace:FindFirstChild("AstralForgeWorld")
		if oldWorld then
			oldWorld:Destroy()
		end

		local folder = Instance.new("Folder")
		folder.Name = "AstralForgeWorld"
		folder.Parent = workspace
		self._folder = folder

		local base = Instance.new("Part")
		base.Name = "WorldBase"
		base.Anchored = true
		base.CanCollide = true
		base.Size = Vector3.new(2048, 8, 2048)
		base.Position = Vector3.new(0, BASE_Y - 6, 0)
		base.Material = Enum.Material.Slate
		base.Color = Color3.fromRGB(28, 30, 36)
		base.TopSurface = Enum.SurfaceType.Smooth
		base.BottomSurface = Enum.SurfaceType.Smooth
		base.Parent = folder
		self._spawn, self._originY = buildSanctuary(folder)
		-- The wider sanctuary: terrain islands, sky bridges, waystones, scenery.
		local expanse = Instance.new("Folder")
		expanse.Name = "SanctuaryWorld"
		expanse.Parent = folder
		self._expanse = expanse
		SanctuaryBuilder.Build(expanse)
		local sanctuaryModel = folder:FindFirstChild("Sanctuary")
		local spawnPart = sanctuaryModel and sanctuaryModel:FindFirstChild("Spawn")
		if spawnPart ~= nil and spawnPart:IsA("BasePart") then
			self._spawnPart = spawnPart
		end
		self:_ensureCharacterLoader()
		if self._heartbeat then
			self._heartbeat:Disconnect()
		end
		if self._playerRemoving then
			self._playerRemoving:Disconnect()
		end
		self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
			self._sanctuary[player] = nil
			self._enterGen[player] = nil
			self._brokenSince[player] = nil
			self._loading[player] = nil
			self._loadError[player] = nil
			if self._travelAt then self._travelAt[player] = nil end
			local conn = self._charConns[player]
			if conn then
				conn:Disconnect()
				self._charConns[player] = nil
			end
		end)
		self._heartbeat = RunService.Heartbeat:Connect(function()
			if next(self._sanctuary) == nil then
				return
			end
			local now = os.clock()
			for player in self._sanctuary do
				if player.Parent ~= Players then
					continue
				end
				if self._loading[player] == true then
					-- A long LoadCharacter must not inherit the empty-avatar timer.
					self._brokenSince[player] = nil
					continue
				end
				local character = player.Character
				local root = nil
				if character ~= nil and character.Parent ~= nil then
					local found = character:FindFirstChild("HumanoidRootPart")
					if found ~= nil and found:IsA("BasePart") then
						root = found
					end
				end
				local broken = character == nil or character.Parent == nil or root == nil
				if broken then
					-- A fresh LoadCharacter has no root for a moment. Only replace an avatar that stays empty.
					local since = self._brokenSince[player]
					if since == nil then
						self._brokenSince[player] = now
					elseif now - since > 3 then
						self._brokenSince[player] = now
						self:_queueCharacterLoad(player, true)
					end
				else
					self._brokenSince[player] = nil
					-- Fell off the world: back to the nearest waystone, not the start.
					if root.Position.Y < self._originY - SanctuaryLayout.KILL_DEPTH then
						self:_recoverFall(player, root)
					end
				end
			end
		end)
	end

	function WorldService:SetInteractionHandler(handler)
		self._interactionHandler = handler
	end

	local function gridPosition(index: number): Vector3
		local n = index + 1
		local cols = 8
		local row = math.floor((n - 1) / cols)
		local col = (n - 1) % cols
		local x = (col - (cols - 1) / 2) * PLOT_SPACING_X
		local z = row * PLOT_SPACING_Z
		return Vector3.new(x, BASE_Y, z)
	end

	local machineById = {}
	for _, machine in GameConfig.Machines do
		if machine.Id then
			machineById[machine.Id] = machine
		end
	end

	local function clearMachineVisuals(model)
		local existing = model:FindFirstChild("Machines")
		if existing then
			existing:Destroy()
		end
	end

	local function renderMachineVisuals(model: Model, base: Part, profile)
		clearMachineVisuals(model)
		local machines = type(profile) == "table" and profile.Machines
		if type(machines) ~= "table" then
			return
		end

		local container = Instance.new("Folder")
		container.Name = "Machines"
		container.Parent = model

		local basePos = base.CFrame.Position
		local count = 0
		for machineId, level in machines do
			if type(level) ~= "number" or level <= 0 then
				continue
			end
			local machine = machineById[machineId]
			if not machine then
				continue
			end
			count += 1
			local col = (count - 1) % 4
			local row = math.floor((count - 1) / 4)
			local offset = Vector3.new((col - 1.5) * 12, 4, -8 + row * 12)
			local size = math.clamp(3 + math.log10(level + 1) * 0.8, 3, 8)

			local part = Instance.new("Part")
			part.Name = machineId
			part.Anchored = true
			part.CanCollide = false
			part.Size = Vector3.new(size, size, size)
			part.CFrame = CFrame.new(basePos + offset)
			part.Color = if typeof(machine.Color) == "Color3" then machine.Color else Color3.fromRGB(200, 200, 200)
			part.Material = Enum.Material.Neon
			part.Transparency = 0.15
			part.Parent = container
		end
	end

	local function clearScenery(model)
		local existing = model:FindFirstChild("Scenery")
		if existing then
			existing:Destroy()
		end
	end

	local function addRock(parent: Instance, position: Vector3, color: Color3, size: Vector3)
		local part = Instance.new("Part")
		part.Name = "Rock"
		part.Anchored = true
		part.CanCollide = false
		part.Size = size
		part.CFrame = CFrame.new(position)
		part.Color = color
		part.Material = Enum.Material.Rock
		part.Transparency = 0.25
		part.Parent = parent
		return part
	end

	local function addCrystal(parent: Instance, position: Vector3, color: Color3, height: number)
		local part = Instance.new("Part")
		part.Name = "Crystal"
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(3, height, 3)
		part.CFrame = CFrame.new(position)
		part.Color = color
		part.Material = Enum.Material.Neon
		part.Transparency = 0.3
		part.Parent = parent
		return part
	end

	local function addRing(parent: Instance, center: Vector3, color: Color3)
		local ring = Instance.new("Part")
		ring.Name = "HeatRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.Size = Vector3.new(18, 0.8, 18)
		ring.CFrame = CFrame.new(center + Vector3.new(0, 2, 0))
		ring.Color = color
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.5
		ring.Shape = Enum.PartType.Cylinder
		ring.Parent = parent
		return ring
	end

	local function addOrb(parent: Instance, position: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name = "EnergyOrb"
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.new(3, 3, 3)
		part.Shape = Enum.PartType.Ball
		part.CFrame = CFrame.new(position)
		part.Color = color
		part.Material = Enum.Material.Neon
		part.Transparency = 0.4
		part.Parent = parent
		return part
	end

	local function zoneColor(zoneId: number): Color3
		local palette = {
			Color3.fromRGB(68, 190, 255),
			Color3.fromRGB(167, 106, 255),
			Color3.fromRGB(255, 172, 66),
			Color3.fromRGB(81, 246, 207),
			Color3.fromRGB(255, 84, 117),
			Color3.fromRGB(120, 196, 255),
			Color3.fromRGB(255, 210, 96),
			Color3.fromRGB(255, 88, 196),
			Color3.fromRGB(76, 255, 194),
			Color3.fromRGB(175, 119, 255),
		}
		return palette[((zoneId - 1) % #palette) + 1] or palette[1]
	end

	local function renderZoneScenery(model: Model, base: Part, zoneId: number)
		clearScenery(model)
		local container = Instance.new("Folder")
		container.Name = "Scenery"
		container.Parent = model

		local center = base.CFrame.Position
		local color = zoneColor(zoneId)
		local radius = math.max(PLOT_SIZE_X, PLOT_SIZE_Z) * 0.8

		if zoneId == 1 then
			for i = 1, 4 do
				local angle = (i - 1) * math.pi * 0.5
				local pos = center + Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius)
				addRock(container, pos, Color3.fromRGB(120, 130, 150), Vector3.new(5, 5, 5))
			end
		elseif zoneId == 2 then
			for i = 1, 5 do
				local angle = (i - 1) * math.pi * 0.4
				local pos = center + Vector3.new(math.cos(angle) * radius, 4, math.sin(angle) * radius)
				addCrystal(container, pos, color, 8 + i * 2)
			end
		elseif zoneId == 3 then
			for i = 1, 3 do
				local angle = (i - 1) * math.pi * 0.33
				local pos = center + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)
				addRing(container, pos, color)
			end
		elseif zoneId == 4 then
			for i = 1, 4 do
				local angle = (i - 1) * math.pi * 0.5
				local pos = center + Vector3.new(math.cos(angle) * radius, 8, math.sin(angle) * radius)
				addOrb(container, pos, color)
			end
		else
			for i = 1, 4 do
				local angle = (i - 1) * math.pi * 0.5 + zoneId * 0.4
				local pos = center + Vector3.new(math.cos(angle) * radius, 6 + (i % 2) * 4, math.sin(angle) * radius)
				addOrb(container, pos, color)
			end
		end
	end

	function WorldService:CreatePlot(player: Player, profile)
		if not self._folder then
			return nil
		end
		local keptIndex = self._plotIndex[player]
		if self._plots[player] then
			self:RemovePlot(player, true)
		end

		local index = keptIndex
		if index == nil then
			local used = {}
			for _, occupied in self._plotIndex do
				used[occupied] = true
			end
			index = 0
			while used[index] do
				index += 1
			end
			self._plotIndex[player] = index
		end

		local model = Instance.new("Model")
		model.Name = "Plot_" .. player.Name

		local base = createBasePlate("Base")
		base.Parent = model
		model.PrimaryPart = base

		local profileZone = type(profile) == "table" and tonumber(profile.Zone) or 1
		local rebirths = type(profile) == "table" and tonumber(profile.Rebirths) or 0
		local domainRank = type(profile) == "table" and type(profile.Domain) == "table" and tonumber(profile.Domain.Rank) or 0

		local color = zoneColor(profileZone)
		if rebirths > 0 then
			color = color:Lerp(Color3.fromRGB(255, 255, 255), math.min(0.3, rebirths * 0.02))
		end
		base.Color = color

		local position = gridPosition(index)
		base.CFrame = CFrame.new(position)

		if domainRank > 0 then
			local pillar = Instance.new("Part")
			pillar.Name = "DomainPillar"
			pillar.Anchored = true
			pillar.CanCollide = false
			pillar.Size = Vector3.new(6, 8 + domainRank * 2, 6)
			pillar.CFrame = CFrame.new(position + Vector3.new(0, 6 + domainRank, 0))
			pillar.Color = Color3.fromRGB(255, 88, 196)
			pillar.Material = Enum.Material.Neon
			pillar.Transparency = 0.4
			pillar.Parent = model
		end

		renderMachineVisuals(model, base, profile)
		renderZoneScenery(model, base, profileZone)
		attachCollectPrompt(base, player, self._interactionHandler)

		model.Parent = self._folder
		self._plots[player] = model
		return model
	end

	function WorldService:RefreshPlot(player: Player, profile)
		local plot = self._plots[player]
		if not plot then
			return
		end
		local base = plot:FindFirstChild("Base") :: Part
		if not base then
			return
		end

		local profileZone = type(profile) == "table" and tonumber(profile.Zone) or 1
		local rebirths = type(profile) == "table" and tonumber(profile.Rebirths) or 0
		local domainRank = type(profile) == "table" and type(profile.Domain) == "table" and tonumber(profile.Domain.Rank) or 0

		local color = zoneColor(profileZone)
		if rebirths > 0 then
			color = color:Lerp(Color3.fromRGB(255, 255, 255), math.min(0.3, rebirths * 0.02))
		end
		base.Color = color

		local existingPillar = plot:FindFirstChild("DomainPillar")
		if existingPillar then
			existingPillar:Destroy()
		end

		if domainRank > 0 then
			local pillar = Instance.new("Part")
			pillar.Name = "DomainPillar"
			pillar.Anchored = true
			pillar.CanCollide = false
			pillar.Size = Vector3.new(6, 8 + domainRank * 2, 6)
			pillar.CFrame = base.CFrame * CFrame.new(0, 6 + domainRank, 0)
			pillar.Color = Color3.fromRGB(255, 88, 196)
			pillar.Material = Enum.Material.Neon
			pillar.Transparency = 0.4
			pillar.Parent = plot
		end

		renderMachineVisuals(plot, base, profile)
		renderZoneScenery(plot, base, profileZone)
	end

	function WorldService:TeleportToPlot(player: Player)
		if self._sanctuary[player] == true then
			return
		end
		local plot = self._plots[player]
		if not plot then
			return
		end
		local base = plot.PrimaryPart
		if not base then
			return
		end
		local character = player.Character
		if not character then
			return
		end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not humanoidRootPart then
			return
		end
		humanoidRootPart.CFrame = CFrame.new(base.Position + Vector3.new(0, 8, 0))
	end

	function WorldService:GetPlotPosition(player: Player): Vector3
		local plot = self._plots[player]
		if plot and plot.PrimaryPart then
			return plot.PrimaryPart.Position
		end
		return Vector3.zero
	end

	function WorldService:RemovePlot(player: Player, keepSlot: boolean?)
		local plot = self._plots[player]
		if plot then
			plot:Destroy()
		end
		self._plots[player] = nil
		if not keepSlot then
			self._plotIndex[player] = nil
		end
	end

	function WorldService:_spawnCFrame(player: Player): CFrame
		local slot = (player.UserId % 4) - 1.5
		return (self._spawn :: CFrame) * CFrame.new(slot * 3.5, 0, 0)
	end

	function WorldService:_placeCharacter(player: Player): boolean
		if typeof(self._spawn) ~= "CFrame" then
			return false
		end
		local character = player.Character
		if character == nil then
			return false
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return false
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			humanoid.JumpHeight = 7.2
			if humanoid:GetAttribute("AF_SanctuaryDied") ~= true then
				humanoid:SetAttribute("AF_SanctuaryDied", true)
				humanoid.Died:Connect(function()
					task.delay(0.85, function()
						if self._sanctuary[player] ~= true or player.Parent ~= Players then
							return
						end
						self:_queueCharacterLoad(player, true)
					end)
				end)
			end
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = self:_spawnCFrame(player)
		return true
	end

	function WorldService:_watchSanctuary(player: Player)
		if self._charConns[player] then
			return
		end
		self._charConns[player] = player.CharacterAdded:Connect(function()
			if self._sanctuary[player] ~= true then
				return
			end
			task.defer(function()
				if self._sanctuary[player] == true and player.Parent == Players then
					self:_placeCharacter(player)
				end
			end)
		end)
	end

	function WorldService:_awaitSanctuaryPlace(player: Player): boolean
		local deadline = os.clock() + 6
		while self._sanctuary[player] == true and player.Parent == Players and os.clock() < deadline do
			if self:_placeCharacter(player) then
				return true
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if character ~= nil and root == nil then
				local remaining = deadline - os.clock()
				if remaining <= 0 then
					break
				end
				character:WaitForChild("HumanoidRootPart", remaining)
			else
				task.wait(0.05)
			end
		end
		if self._sanctuary[player] == true and player.Parent == Players then
			return self:_placeCharacter(player)
		end
		return false
	end

	function WorldService:_bindSanctuaryFocus(player: Player)
		local focus = self._spawnPart
		if typeof(focus) ~= "Instance" or not focus:IsA("BasePart") or focus.Parent == nil then
			return
		end
		player.ReplicationFocus = focus
		if focus:IsA("SpawnLocation") then
			player.RespawnLocation = focus
		end
	end

	function WorldService:_queueCharacterLoad(player: Player, replaceBroken: boolean?)
		if player.Parent ~= Players or self._sanctuary[player] ~= true then
			return
		end
		for _, queued in self._loadQueue do
			if queued == player then
				return
			end
		end
		if replaceBroken == true then
			local character = player.Character
			if character ~= nil and character.Parent ~= nil then
				character:Destroy()
			end
			player.Character = nil
		end
		table.insert(self._loadQueue, player)
	end

	function WorldService:_ensureCharacterLoader()
		if self._loaderAlive == true then
			return
		end
		self._loaderAlive = true
		-- This thread is started with the world, not from a remote callback.
		-- LoadCharacter yields, and doing that on OnServerInvoke (even via
		-- task.spawn from the invoke) aborts with "Callbacks cannot yield"
		-- and leaves an empty character that has no HumanoidRootPart.
		task.spawn(function()
			while self._loaderAlive == true do
				local player = table.remove(self._loadQueue, 1)
				if player == nil then
					task.wait(0.05)
				else
					local stepOk, stepErr = pcall(function()
						if player.Parent ~= Players or self._sanctuary[player] ~= true then
							return
						end
						self:_bindSanctuaryFocus(player)
						local character = player.Character
						local rooted = false
						if character ~= nil and character.Parent ~= nil then
							local root = character:FindFirstChild("HumanoidRootPart")
							rooted = root ~= nil and root:IsA("BasePart")
						end
						if rooted then
							self:_placeCharacter(player)
							return
						end
						-- An avatar that is still assembling has no root yet.
						-- Destroying it here is what left the rift with no character.
						-- Heartbeat replaces one that stays empty.
						if character ~= nil then
							return
						end
						self._loading[player] = true
						self._brokenSince[player] = nil
						local loaded, loadErr = pcall(function()
							player:LoadCharacter()
						end)
						if loaded and self._sanctuary[player] == true then
							self:_placeCharacter(player)
						elseif not loaded then
							self._loadError[player] = tostring(loadErr)
						end
						self._loading[player] = nil
					end)
					if player ~= nil then
						self._loading[player] = nil
					end
					if not stepOk then
						self._loadError[player] = tostring(stepErr)
						warn(string.format("[Sanctuary] loader %s", tostring(stepErr)))
					end
				end
			end
		end)
	end

	function WorldService:EnterSanctuary(player: Player): (boolean, CFrame?, boolean)
		if typeof(self._spawn) ~= "CFrame" then
			warn("[Sanctuary] enter failed — spawn was not built")
			return false, nil, false
		end
		self._enterGen[player] = (self._enterGen[player] or 0) + 1
		local generation = self._enterGen[player]
		self._sanctuary[player] = true
		self._loadError[player] = nil
		self._brokenSince[player] = nil
		self:_bindSanctuaryFocus(player)
		self:_watchSanctuary(player)
		self:_ensureCharacterLoader()
		self:_queueCharacterLoad(player, false)

		local deadline = os.clock() + 12
		while player.Parent == Players and self._sanctuary[player] == true and self._enterGen[player] == generation and os.clock() < deadline do
			if self:_placeCharacter(player) then
				local placed = self:_spawnCFrame(player)
				task.spawn(function()
					pcall(function()
						player:RequestStreamAroundAsync(placed.Position, 5)
					end)
				end)
				-- Streaming followed the spawn while the avatar loaded. The world is
				-- far bigger than the deck now, so hand focus back to the character
				-- or distant regions would never stream in as the player walks.
				pcall(function()
					player.ReplicationFocus = nil
				end)
				return true, placed, false
			end
			task.wait(0.05)
		end
		-- A close or a newer enter owns the player. Do not answer with the rift error.
		if self._enterGen[player] ~= generation or self._sanctuary[player] ~= true then
			return false, nil, true
		end
		local why = self._loadError[player]
		if why == nil then
			why = "character never gained a HumanoidRootPart"
		end
		warn(string.format("[Sanctuary] enter failed — %s", why))
		self:LeaveSanctuary(player)
		return false, nil, false
	end

	function WorldService:IsInSanctuary(player: Player): boolean
		return self._sanctuary[player] == true
	end

	-- The live HumanoidRootPart of a player standing in the sanctuary, or nil.
	function WorldService:SanctuaryRoot(player: Player): BasePart?
		if self._sanctuary[player] ~= true then
			return nil
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			return root
		end
		return nil
	end

	-- Everyone currently standing in the sanctuary with a live character.
	function WorldService:SanctuaryPlayers(): { Player }
		local list = {}
		for player in self._sanctuary do
			if player.Parent == Players and self:SanctuaryRoot(player) ~= nil then
				table.insert(list, player)
			end
		end
		return list
	end

	function WorldService:SanctuaryFolder(): Instance?
		return self._expanse
	end

	-- A sanctuary-local point as a world position.
	function WorldService:SanctuaryPoint(p): Vector3
		return SANCTUARY_ORIGIN + Vector3.new(p.X, p.Y, p.Z)
	end

	-- Move a character on the server: grant a moment of movement grace first so
	-- CharacterIntegrity doesn't read the jump as a teleport exploit, then pre-
	-- stream the destination.
	function WorldService:_teleport(player: Player, root: BasePart, target: CFrame)
		local character = player.Character
		if character ~= nil then
			character:SetAttribute("AF_MovementGraceUntil", Workspace:GetServerTimeNow() + TELEPORT_GRACE_SECONDS)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if character ~= nil then
			character:PivotTo(target)
		else
			root.CFrame = target
		end
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(target.Position, 3)
			end)
		end)
	end

	-- Where a traveller arrives at a waystone: beside it, facing into its region.
	local function arrivalCFrame(stoneId: string): CFrame?
		local stone = SanctuaryLayout.waystone(stoneId)
		if stone == nil then
			return nil
		end
		local region = SanctuaryLayout.region(stone.Region)
		local at = SANCTUARY_ORIGIN + Vector3.new(stone.Position.X, stone.Position.Y, stone.Position.Z)
		local toward = if region ~= nil
			then SANCTUARY_ORIGIN + Vector3.new(region.Center.X, stone.Position.Y, region.Center.Z)
			else at + Vector3.new(0, 0, -1)
		local flat = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z)
		local dir = if flat.Magnitude > 0.5 then flat.Unit else Vector3.new(0, 0, -1)
		local stand = at + dir * 6 + Vector3.new(0, 4, 0)
		return CFrame.lookAt(stand, stand + dir)
	end

	-- A fall is close to straight down, so the waystone nearest the fall point
	-- (on the ground plane) is the one nearest where the player stepped off.
	function WorldService:_recoverFall(player: Player, root: BasePart)
		local fell = root.Position - SANCTUARY_ORIGIN
		local stone = SanctuaryLayout.nearestWaystone({ X = fell.X, Y = fell.Y, Z = fell.Z })
		local target = arrivalCFrame(stone.Id)
		if target == nil then
			self:_placeCharacter(player)
			return
		end
		self:_teleport(player, root, target)
	end

	-- Travel from a waystone to another, or `recall` to the Forge Heart from
	-- anywhere. Validated here: the client only asks.
	function WorldService:TravelWaystone(player: Player, targetId: any, recall: boolean): (boolean, string)
		local root = self:SanctuaryRoot(player)
		if root == nil then
			return false, "Step into the sanctuary first."
		end
		self._travelAt = self._travelAt or {}
		local now = os.clock()
		local last = self._travelAt[player] or -math.huge
		local cooldown = if recall then RECALL_COOLDOWN else TRAVEL_COOLDOWN
		if now - last < cooldown then
			return false, "The waystones are still settling."
		end
		local destination = if recall then "Heart" elseif type(targetId) == "string" then targetId else ""
		local target = arrivalCFrame(destination)
		if target == nil then
			return false, "That waystone doesn't exist."
		end
		if not recall then
			local here = root.Position - SANCTUARY_ORIGIN
			local nearest = SanctuaryLayout.nearestWaystone({ X = here.X, Y = here.Y, Z = here.Z })
			local offset = Vector3.new(nearest.Position.X - here.X, 0, nearest.Position.Z - here.Z)
			if offset.Magnitude > WAYSTONE_REACH or math.abs(nearest.Position.Y - here.Y) > 14 then
				return false, "Stand at a waystone to travel."
			end
		end
		self._travelAt[player] = now
		self:_teleport(player, root, target)
		local stone = SanctuaryLayout.waystone(destination)
		return true, if stone ~= nil then stone.Name else destination
	end

	function WorldService:LeaveSanctuary(player: Player)
		self._sanctuary[player] = nil
		self._enterGen[player] = (self._enterGen[player] or 0) + 1
		self._brokenSince[player] = nil
		self._loading[player] = nil
		pcall(function()
			player.ReplicationFocus = nil
			player.RespawnLocation = nil
		end)
		local conn = self._charConns[player]
		if conn then
			conn:Disconnect()
			self._charConns[player] = nil
		end
		local character = player.Character
		if character == nil or character.Parent == nil then
			player.Character = nil
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
		character:Destroy()
	end

	return WorldService
end
