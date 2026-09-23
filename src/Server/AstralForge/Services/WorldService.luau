--!strict

local Players = game:GetService("Players")
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

	function WorldService.new()
		local self = setmetatable({}, WorldService)
		self._interactionHandler = nil
		self._plots = {}
		self._folder = nil
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
		if self._plots[player] then
			self:RemovePlot(player)
		end

		local index = 0
		for _, p in Players:GetPlayers() do
			if p == player then
				break
			end
			index += 1
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

	function WorldService:RemovePlot(player: Player)
		local plot = self._plots[player]
		if plot then
			plot:Destroy()
		end
		self._plots[player] = nil
	end

	return WorldService
end
