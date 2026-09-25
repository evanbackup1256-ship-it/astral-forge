--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

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

		-- One walk ribbon at Y=0, then a single step onto an irregular dais.
		-- The south approach stays low: the overlook camera sits ~24 studs behind spawn and ~14 up.
		topPart(model, "Part", "PathSouth", Vector3.new(12, 3.2, 20), Vector3.new(2.4, 0, 19), 8, PATH, Enum.Material.Slate, true)
		topPart(model, "Part", "PathMid", Vector3.new(18, 3.2, 16), Vector3.new(-0.8, 0, 9), -6, PATH, Enum.Material.Slate, true)
		topPart(model, "Part", "PathApron", Vector3.new(22, 3.2, 12), Vector3.new(0.6, 0, 2.2), 3, PATH, Enum.Material.Cobblestone, true)
		topPart(model, "Part", "PathFlake", Vector3.new(7, 3.2, 6), Vector3.new(6.5, 0, 15), 18, PATH, Enum.Material.Slate, true)

		topPart(model, "Part", "Dais", Vector3.new(22, 3.4, 16), Vector3.new(-0.6, 1.45, -4.6), -7, DECK, Enum.Material.Basalt, true)
		topPart(model, "Part", "DaisShoulder", Vector3.new(13, 3.4, 11), Vector3.new(-8.4, 1.45, -1.2), 15, DECK, Enum.Material.Basalt, true)
		topPart(model, "Part", "DaisNose", Vector3.new(10, 3.4, 9), Vector3.new(7.2, 1.45, -8.6), -16, DECK, Enum.Material.Slate, true)

		-- West lip overlaps the shoulder, then cantilevers with nothing under the outer edge.
		topPart(model, "Part", "HangLip", Vector3.new(12, 0.7, 14), Vector3.new(-16.2, 1.02, -1.6), 11, LIP, Enum.Material.Slate, true)
		topPart(model, "Part", "LipRoot", Vector3.new(5, 3.2, 7), Vector3.new(-11.2, 0.15, -1.4), 11, DARK, Enum.Material.Basalt, true)

		topPart(model, "Part", "Keel", Vector3.new(16, 9, 20), Vector3.new(0.4, -0.6, 5), -4, DARK, Enum.Material.Basalt, true)
		topPart(model, "Part", "KeelWest", Vector3.new(10, 7, 12), Vector3.new(-6.5, -1.4, -2.5), 12, DARK, Enum.Material.Rock, true)
		topPart(model, "Part", "KeelTail", Vector3.new(9, 6, 11), Vector3.new(2.8, -1.2, 17), 7, DARK, Enum.Material.Rock, true)
		topPart(model, "Part", "KeelNose", Vector3.new(8, 5, 8), Vector3.new(5.5, -1.6, -7), -14, DARK, Enum.Material.Basalt, true)

		topPart(model, "Part", "EastLedge", Vector3.new(9, 2.6, 13), Vector3.new(13.4, 0.15, -0.4), 9, DECK, Enum.Material.Rock, true)
		topPart(model, "Part", "RockEast", Vector3.new(5.4, 3.1, 4.4), Vector3.new(14.2, 3.25, -3.6), 22, ROCK, Enum.Material.Rock, true)
		topPart(model, "Part", "RockEastLow", Vector3.new(3.6, 2.1, 3.2), Vector3.new(16.1, 2.25, 1.4), -28, ROCK, Enum.Material.Slate, true)
		topPart(model, "WedgePart", "WedgeEast", Vector3.new(4.2, 2.2, 5.2), Vector3.new(11.4, 2.35, 2.2), -18, ROCK, Enum.Material.Rock, true)
		topPart(model, "Part", "RockNorth", Vector3.new(5.6, 3.2, 4.6), Vector3.new(-3.4, 4.65, -12.4), -24, ROCK, Enum.Material.Rock, true)
		topPart(model, "WedgePart", "WedgeNorth", Vector3.new(4.4, 2.4, 5), Vector3.new(2.2, 3.6, -12.8), 20, ROCK, Enum.Material.Slate, true)
		topPart(model, "Part", "RockShoulder", Vector3.new(3.4, 2.2, 3.2), Vector3.new(-11.6, 3.55, 3.2), 36, ROCK, Enum.Material.Rock, true)

		topPart(model, "Part", "PebbleA", Vector3.new(1.6, 0.7, 1.4), Vector3.new(8.4, 0.35, 12.6), 14, ROCK, Enum.Material.Rock, false)
		topPart(model, "Part", "PebbleB", Vector3.new(1.3, 0.6, 1.2), Vector3.new(-6.2, 0.3, 13.4), -20, ROCK, Enum.Material.Rock, false)
		topPart(model, "Part", "PebbleC", Vector3.new(1.5, 0.8, 1.3), Vector3.new(15.2, 0.55, 3.6), 8, ROCK, Enum.Material.Rock, false)
		topPart(model, "Part", "PebbleD", Vector3.new(1.2, 0.5, 1.1), Vector3.new(-14.8, 1.28, 2.4), 16, LIP, Enum.Material.Rock, false)

		local crack = topPart(model, "Part", "RiftCrack", Vector3.new(0.35, 0.16, 6.5), Vector3.new(0.3, 1.54, -2.2), -7, CYAN, Enum.Material.Neon, false)
		crack.Transparency = 0.32
		crack.CastShadow = false

		-- One lamp: stone cup, a single flame, no pillar stack.
		local daisTop = 1.45
		uprightCylinder(model, "AltarPlinth", 5, 1.05, Vector3.new(0.5, daisTop + 0.52, -3.1), DECK, Enum.Material.Basalt, true)
		uprightCylinder(model, "AltarCup", 3.2, 0.42, Vector3.new(0.5, daisTop + 1.26, -3.1), DARK, Enum.Material.Slate, true)
		local flame = sanctuaryBall(model, "AltarFlame", 1.45, Vector3.new(0.5, daisTop + 1.95, -3.1), MINT, Enum.Material.Neon, false)
		flame.Transparency = 0.22
		flame.CastShadow = false
		local flameLight = Instance.new("PointLight")
		flameLight.Color = CYAN
		flameLight.Brightness = 1.15
		flameLight.Range = 22
		flameLight.Shadows = false
		flameLight.Parent = flame

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SanctuaryClose"
		prompt.ActionText = "Seal the rift"
		prompt.ObjectText = "Forge altar"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 14
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Parent = flame

		-- SpawnLocation so LoadCharacter does not drop the avatar at the origin.
		-- The part name stays Spawn. No extra spire.
		local spawn = sanctuaryPart(model, "SpawnLocation", "Spawn", Vector3.new(6, 1, 6), Vector3.new(0, 3.5, 7), 0, DECK, Enum.Material.SmoothPlastic, false)
		spawn.Transparency = 1
		spawn.CanQuery = false
		spawn.CanTouch = false
		if spawn:IsA("SpawnLocation") then
			spawn.Neutral = true
			spawn.Duration = 0
			spawn.AllowTeamChangeOnTouch = false
			spawn.Enabled = true
		end
		local look = SANCTUARY_ORIGIN + Vector3.new(0.5, daisTop + 1.95, -3.1)
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
					if root.Position.Y < self._originY - 40 then
						self:_placeCharacter(player)
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
			part.Color = if type(machine.Color) == "Color3" then machine.Color else Color3.fromRGB(200, 200, 200)
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
