--!nonstrict
-- Purpose: makes every player's equipped artifact visible in the world. Each character with an
-- artifact gets an orbiting shard, a particle wake, a light, and a nameplate with the element sprite,
-- name, rarity, and live effect. Equipping a new artifact plays a burst that everyone nearby sees.
-- Reads the EquippedArtifact* attributes replicated by GameService:_syncLeaderstats.
-- Owner: presentation. Dependencies: Shared/ElementSprites. Review: 2026-10-09.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ElementSprites = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ElementSprites"))
local Theme = require(ReplicatedStorage.AstralForge.Shared.ForgeTheme)

local ArtifactPresence = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local DRAW_DISTANCE = 140
local ATTRS = {
	"EquippedArtifact",
	"EquippedArtifactName",
	"EquippedArtifactElement",
	"EquippedArtifactRarity",
	"EquippedArtifactLevel",
	"EquippedArtifactColor",
	"EquippedArtifactEffect",
}
-- shard size, particle rate, orbit radius, and light range climb with rarity
local TIER = {
	COMMON = { shard = 0.35, rate = 4, radius = 2.4, light = 6, shards = 1 },
	UNCOMMON = { shard = 0.42, rate = 7, radius = 2.6, light = 8, shards = 1 },
	RARE = { shard = 0.5, rate = 11, radius = 2.8, light = 10, shards = 2 },
	EPIC = { shard = 0.58, rate = 16, radius = 3.0, light = 12, shards = 2 },
	LEGENDARY = { shard = 0.68, rate = 24, radius = 3.2, light = 15, shards = 3 },
	MYTHIC = { shard = 0.78, rate = 32, radius = 3.4, light = 18, shards = 3 },
}

local function tierOf(rarity)
	return TIER[string.upper(tostring(rarity or ""))] or TIER.COMMON
end

local function read(player)
	local id = player:GetAttribute("EquippedArtifact")
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local color = player:GetAttribute("EquippedArtifactColor")
	local level = player:GetAttribute("EquippedArtifactLevel")
	local name = player:GetAttribute("EquippedArtifactName")
	return {
		Id = id,
		Name = if type(name) == "string" and name ~= "" then name else id,
		Element = player:GetAttribute("EquippedArtifactElement"),
		Rarity = tostring(player:GetAttribute("EquippedArtifactRarity") or "COMMON"),
		Level = if type(level) == "number" then math.max(1, math.floor(level)) else 1,
		Color = if typeof(color) == "Color3" then color else Color3.fromRGB(240, 212, 140),
		Effect = player:GetAttribute("EquippedArtifactEffect"),
	}
end

local function lighten(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function shardPart(color, size)
	local part = Instance.new("Part")
	part.Name = "ArtifactShard"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(size, size * 1.7, size)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function nameplate(info, adornee)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ArtifactPlate"
	gui.Adornee = adornee
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Size = UDim2.fromOffset(190, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.ResetOnSpawn = false

	local sheet = ElementSprites.sheet(info.Element)
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromOffset(40, 40)
	glyph.Position = UDim2.fromOffset(0, 3)
	glyph.ImageColor3 = lighten(info.Color, 0.15)
	if sheet ~= nil then
		glyph.Image = sheet.Image
		glyph.ImageRectSize = Vector2.new(ElementSprites.FRAME, ElementSprites.FRAME)
		glyph.ImageRectOffset = Vector2.new(0, 0)
	end
	glyph.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(44, 4)
	title.Size = UDim2.new(1, -44, 0, 20)
	title.FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = lighten(info.Color, 0.25)
	title.TextStrokeColor3 = Theme.Base.void
	title.TextStrokeTransparency = 0.35
	title.Text = string.upper(info.Name)
	title.Parent = gui

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(44, 25)
	detail.Size = UDim2.new(1, -44, 0, 15)
	detail.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	detail.TextScaled = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextColor3 = Theme.Base.creamSoft
	detail.TextStrokeColor3 = Theme.Base.void
	detail.TextStrokeTransparency = 0.45
	local effect = if type(info.Effect) == "string" and info.Effect ~= "" then ` · {info.Effect}` else ""
	detail.Text = `{string.upper(info.Rarity)} LV{info.Level}{effect}`
	detail.Parent = gui
	return gui, glyph, sheet ~= nil
end

function ArtifactPresence.attach()
	local folder = Instance.new("Folder")
	folder.Name = "ArtifactPresence"
	folder.Parent = workspace

	local rigs = {}
	local watchers = {}
	local connections = {}
	local spriteClock = 0
	local spriteFrame = 0
	local alive = true
	local refreshJobs = {}

	local function clearRig(player)
		local rig = rigs[player]
		if rig == nil then
			return
		end
		rigs[player] = nil
		for _, instance in rig.instances do
			instance:Destroy()
		end
	end

	local function burst(rig)
		local root = rig.root
		if root == nil or root.Parent == nil then
			return
		end
		rig.emitter:Emit(40)
		local ring = Instance.new("Part")
		ring.Name = "ArtifactEquipRing"
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = rig.color
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.15, 2, 2)
		ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.15
		ring.Parent = folder
		local grow = TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		TweenService:Create(ring, grow, { Size = Vector3.new(0.05, 14, 14), Transparency = 1 }):Play()
		local flare = rig.light
		local base = flare.Brightness
		flare.Brightness = base * 4
		TweenService:Create(flare, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = base }):Play()
		task.delay(0.8, function()
			ring:Destroy()
		end)
	end

	local function buildRig(player, announce)
		if not alive or watchers[player] == nil then
			return
		end
		clearRig(player)
		local info = read(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local head = character and character:FindFirstChild("Head")
		if info == nil or root == nil then
			return
		end
		local tier = tierOf(info.Rarity)
		local rig = {
			id = info.Id,
			root = root,
			color = info.Color,
			radius = tier.radius,
			phase = (player.UserId % 97) / 97 * math.pi * 2,
			shards = {},
			instances = {},
		}

		for index = 1, tier.shards do
			local shard = shardPart(lighten(info.Color, 0.1 * (index - 1)), tier.shard * (1 - (index - 1) * 0.22))
			shard.CFrame = root.CFrame
			shard.Parent = folder
			table.insert(rig.shards, shard)
			table.insert(rig.instances, shard)
		end
		local lead = rig.shards[1]
		local light = Instance.new("PointLight")
		light.Color = info.Color
		light.Range = tier.light
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = lead
		rig.light = light

		local trail0 = Instance.new("Attachment")
		trail0.Position = Vector3.new(0, tier.shard * 0.8, 0)
		trail0.Parent = lead
		local trail1 = Instance.new("Attachment")
		trail1.Position = Vector3.new(0, -tier.shard * 0.8, 0)
		trail1.Parent = lead
		local trail = Instance.new("Trail")
		trail.Attachment0 = trail0
		trail.Attachment1 = trail1
		trail.Color = ColorSequence.new(lighten(info.Color, 0.3), info.Color)
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Lifetime = 0.35
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = lead
		rig.trail = trail

		local anchor = Instance.new("Attachment")
		anchor.Name = "ArtifactAura"
		anchor.Position = Vector3.new(0, -0.6, 0)
		anchor.Parent = root
		table.insert(rig.instances, anchor)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(lighten(info.Color, 0.35), info.Color)
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Rate = tier.rate
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Speed = NumberRange.new(0.6, 1.8)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 1.4, 0)
		emitter.Drag = 1.5
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.32),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.15, 1)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.Shape = Enum.ParticleEmitterShape.Cylinder
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emitter.Parent = anchor
		rig.emitter = emitter

		local plate, glyph, animated = nameplate(info, head or root)
		plate.Parent = folder
		table.insert(rig.instances, plate)
		rig.glyph = if animated then glyph else nil

		rigs[player] = rig
		if announce then
			burst(rig)
		end
	end

	local function watch(player)
		local list = {}
		watchers[player] = list
		local lastId = player:GetAttribute("EquippedArtifact")
		local function refresh(announce)
			local pending = refreshJobs[player]
			if pending ~= nil then
				pending.announce = pending.announce or announce
				return
			end
			pending = { announce = announce }
			refreshJobs[player] = pending
			pending.job = task.defer(function()
				refreshJobs[player] = nil
				buildRig(player, pending.announce)
			end)
		end
		-- EquippedArtifact is written last on the server, so the other fields are already current
		table.insert(list, player:GetAttributeChangedSignal("EquippedArtifact"):Connect(function()
			local nextId = player:GetAttribute("EquippedArtifact")
			local changed = nextId ~= lastId and type(nextId) == "string" and nextId ~= ""
			lastId = nextId
			refresh(changed)
		end))
		for _, attr in ATTRS do
			if attr ~= "EquippedArtifact" then
				table.insert(list, player:GetAttributeChangedSignal(attr):Connect(function()
					local rig = rigs[player]
					if rig ~= nil and rig.id == player:GetAttribute("EquippedArtifact") then
						refresh(false)
					end
				end))
			end
		end
		table.insert(list, player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 5)
			if alive and player.Parent ~= nil and player.Character == character then
				buildRig(player, false)
			end
		end))
		table.insert(list, player.CharacterRemoving:Connect(function()
			clearRig(player)
		end))
		if player.Character ~= nil then
			local character = player.Character
			task.spawn(function()
				character:WaitForChild("HumanoidRootPart", 10)
				if alive and player.Character == character then
					buildRig(player, false)
				end
			end)
		end
	end

	local function unwatch(player)
		local pending = refreshJobs[player]
		if pending ~= nil then
			task.cancel(pending.job)
			refreshJobs[player] = nil
		end
		clearRig(player)
		local list = watchers[player]
		watchers[player] = nil
		if list ~= nil then
			for _, connection in list do
				connection:Disconnect()
			end
		end
	end

	for _, player in Players:GetPlayers() do
		watch(player)
	end
	table.insert(connections, Players.PlayerAdded:Connect(watch))
	table.insert(connections, Players.PlayerRemoving:Connect(unwatch))

	local frameStep = 1 / ElementSprites.FRAMERATE
	local grid = ElementSprites.FRAME
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local eye = if camera ~= nil then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		spriteClock += dt
		local advance = false
		if spriteClock >= frameStep then
			spriteClock %= frameStep
			spriteFrame = (spriteFrame + 1) % ElementSprites.COUNT
			advance = true
		end
		local offset = Vector2.new((spriteFrame % 6) * grid, math.floor(spriteFrame / 6) * grid)
		for _, rig in rigs do
			local root = rig.root
			if root ~= nil and root.Parent ~= nil then
				local center = root.Position
				local near = (center - eye).Magnitude <= DRAW_DISTANCE
				rig.emitter.Enabled = near
				rig.trail.Enabled = near
				rig.light.Enabled = near
				local count = #rig.shards
				for index, shard in rig.shards do
					if near then
						local angle = now * (1.6 - index * 0.25) + rig.phase + (index - 1) * (math.pi * 2 / count)
						local bob = math.sin(now * 2.1 + index + rig.phase) * 0.35
						local radius = rig.radius - (index - 1) * 0.45
						local spot = center + Vector3.new(math.cos(angle) * radius, 0.9 + bob + (index - 1) * 0.5, math.sin(angle) * radius)
						shard.CFrame = CFrame.new(spot) * CFrame.Angles(now * 1.3, now * 2.2 + index, 0)
						shard.Transparency = 0
					else
						shard.Transparency = 1
					end
				end
				if advance and near and rig.glyph ~= nil then
					rig.glyph.ImageRectOffset = offset
				end
			end
		end
	end))

	return function()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, player in Players:GetPlayers() do
			unwatch(player)
		end
		for player in watchers do
			unwatch(player)
		end
		folder:Destroy()
	end
end

return ArtifactPresence
