--!strict
-- Ore outcrops in the sanctuary, and the Foundry upgrades bought with the ore.
--
-- Nodes are server parts with a hold-to-mine ProximityPrompt, so Roblox checks
-- the prompt distance itself and the server re-checks reach on trigger.
-- Nodes are shared scenery, but each player mines each one on their own
-- timer: the regrow time is tracked per player and the client dims a node it
-- has mined until it grows back (sanctuaryWorld.luau).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SanctuaryLayout = require(Shared:WaitForChild("SanctuaryLayout"))
local AssetKit = require(Shared:WaitForChild("AssetKit"))
local Vfx = require(Shared:WaitForChild("Vfx"))
local Modules = script.Parent.Parent:WaitForChild("Modules")
local OreMath = require(Modules:WaitForChild("OreMath"))
local Economy = require(Modules:WaitForChild("Economy"))
local ActionResponse = require(Modules:WaitForChild("ActionResponse"))

local NODE_TAG = "AF_OreNode"

local OreService = {}
OreService.__index = OreService

local function rgb(triple: { number }): Color3
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

local function oreType(id: string)
	for _, ore in GameConfig.Ore.Types do
		if ore.Id == id then
			return ore
		end
	end
	return nil
end

-- One outcrop: a rock seat with a cluster of leaning crystals, each a glassy
-- shell around a lit core, plus a soft light and drifting sparkles.
local function buildNode(parent: Instance, site, at: Vector3, seed: number): (Model, ProximityPrompt)
	local ore = oreType(site.Ore)
	local color = if ore then rgb(ore.Color) else Color3.new(1, 1, 1)
	local glowColor = if ore then rgb(ore.Glow) else Color3.new(1, 1, 1)
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = `OreNode_{site.Id}`
	model:SetAttribute("NodeId", site.Id)
	model:SetAttribute("Ore", site.Ore)
	pcall(function()
		(model :: any).ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)

	-- The rock the crystals grow from: a kit boulder when the model kit is
	-- loaded, a plain block otherwise.
	local seatFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-6, 6)))
	local seat: BasePart = AssetKit.make("RockB", Vector3.new(7, 2.6, 6), seatFrame, Color3.fromRGB(46, 46, 56), Enum.Material.Rock, true)
		or Instance.new("Part")
	if not seat:IsA("MeshPart") then
		seat.Size = Vector3.new(6.5, 2.2, 5.5)
		seat.CFrame = seatFrame
		seat.Color = Color3.fromRGB(46, 46, 56)
		seat.Material = Enum.Material.Rock
		;(seat :: Part).TopSurface = Enum.SurfaceType.Smooth
		;(seat :: Part).BottomSurface = Enum.SurfaceType.Smooth
	end
	seat.Name = "Seat"
	seat.Anchored = true
	seat.Parent = model
	model.PrimaryPart = seat

	local count = 5
	for k = 1, count do
		local angle = (k / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local height = if k == 1 then rng:NextNumber(4.6, 5.8) else rng:NextNumber(2.4, 4.2)
		local lean = if k == 1 then 4 else rng:NextNumber(14, 30)
		local foot = at + Vector3.new(math.cos(angle) * (if k == 1 then 0 else 1.3), 1.4, math.sin(angle) * (if k == 1 then 0 else 1.3))
		local frame = CFrame.new(foot) * CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, math.rad(-lean)) * CFrame.new(0, height / 2, 0)
		local width = if k == 1 then 1.7 else rng:NextNumber(1.0, 1.4)

		-- Faceted kit crystals when the model kit is loaded; blocks otherwise.
		-- The client grows and shrinks either kind the same way.
		local shell: BasePart = AssetKit.make("Crystal", Vector3.new(width, height, width), nil, nil, nil, false) or Instance.new("Part")
		shell.Name = "Crystal"
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.CastShadow = false
		shell.Size = Vector3.new(width, height, width)
		shell.CFrame = frame * CFrame.Angles(0, math.rad(45), 0)
		shell.Color = color
		shell.Material = Enum.Material.Glass
		shell.Transparency = 0.2
		shell.Reflectance = 0.12
		shell:SetAttribute("RestSize", shell.Size)
		shell.Parent = model

		local core: BasePart = AssetKit.make("Crystal", Vector3.new(width * 0.45, height * 0.82, width * 0.45), nil, nil, nil, false) or Instance.new("Part")
		core.Name = "Core"
		core.Anchored = true
		core.CanCollide = false
		core.CanQuery = false
		core.CanTouch = false
		core.CastShadow = false
		core.Size = Vector3.new(width * 0.45, height * 0.82, width * 0.45)
		core.CFrame = shell.CFrame
		core.Color = glowColor
		core.Material = Enum.Material.Neon
		core.Transparency = 0.15
		core:SetAttribute("RestSize", core.Size)
		core.Parent = model

		if k == 1 then
			local light = Instance.new("PointLight")
			light.Name = "Glow"
			light.Color = glowColor
			light.Brightness = 1.3
			light.Range = 14
			light.Shadows = false
			light.Parent = core
			-- Glints drifting off a ready outcrop (the client pauses them while
			-- it regrows), and a soft halo that marks it from across the plateau.
			local sparkle = Vfx.attach(core, "Motes", { Color = glowColor, Rate = 4, Speed = NumberRange.new(0.6, 1.6) })
			sparkle.Name = "Sparkle"
			local aura = Vfx.attach(core, "Halo", { Color = color, Size = NumberSequence.new(4, 4.6) })
			aura.Name = "Aura"
		end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MinePrompt"
	prompt.ActionText = "Mine"
	prompt.ObjectText = if ore then ore.Name else site.Ore
	prompt.HoldDuration = GameConfig.Ore.HoldSeconds
	prompt.MaxActivationDistance = GameConfig.Ore.PromptDistance
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NodeId", site.Id)
	prompt.Parent = seat

	CollectionService:AddTag(model, NODE_TAG)
	model.Parent = parent
	return model, prompt
end

function OreService.new(host)
	local self = setmetatable({}, OreService)
	self._host = host
	self._nodes = {}
	self._cooldowns = {}
	self._random = Random.new()
	return self
end

function OreService:Start()
	local folder = self._host.world:SanctuaryFolder()
	if folder == nil then
		warn("[Ore] the sanctuary world was not built; outcrops skipped")
		return
	end
	-- Wait (briefly, and only when one is uploaded) for the model kit, so the
	-- outcrops are built once with the right meshes.
	task.spawn(function()
		AssetKit.load(8)
		self:_buildNodes(folder)
	end)
end

function OreService:_buildNodes(folder: Instance)
	local nodes = Instance.new("Folder")
	nodes.Name = "OreNodes"
	nodes.Parent = folder
	for index, site in SanctuaryLayout.oreSites() do
		local at = self._host.world:SanctuaryPoint(site.Position)
		local model, prompt = buildNode(nodes, site, at, index * 7727)
		self._nodes[site.Id] = { Site = site, Position = at, Model = model }
		prompt.Triggered:Connect(function(player: Player)
			local ok, problem = pcall(function()
				self:Mine(player, site.Id)
			end)
			if not ok then
				warn(`[Ore] mine failed: {problem}`)
			end
		end)
	end
end

function OreService:_cooldownsFor(player: Player): { [string]: number }
	local bag = self._cooldowns[player]
	if bag == nil then
		bag = {}
		self._cooldowns[player] = bag
	end
	return bag
end

function OreService:Mine(player: Player, nodeId: string)
	local node = self._nodes[nodeId]
	local root = self._host.world:SanctuaryRoot(player)
	if node == nil or root == nil then
		return
	end
	if (root.Position - node.Position).Magnitude > GameConfig.Ore.ServerReach then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local cooldowns = self:_cooldownsFor(player)
	local readyAt = cooldowns[nodeId]
	if readyAt ~= nil and readyAt > now then
		-- Out of sync (a stale prompt): tell the client again.
		self._host:effect(player, { Type = "OreCooldowns", Nodes = { [nodeId] = readyAt } })
		return
	end
	local oreId = node.Site.Ore
	local mined = 0
	local result = self._host:mutate(player, function(profile)
		local bonus = Economy.OreEffect(profile, "OreYield")
		mined = OreMath.Yield(GameConfig.Ore, oreId, bonus, function(low, high)
			return self._random:NextInteger(low, high)
		end)
		if mined <= 0 then
			return ActionResponse.Error("Nothing to mine here.")
		end
		profile.Ore = OreMath.SanitizeBalances(profile.Ore, GameConfig.Ore)
		profile.Ore[oreId] += mined
		if type(profile.Stats) == "table" then
			profile.Stats.OreMined = (tonumber(profile.Stats.OreMined) or 0) + mined
		end
		return ActionResponse.Success(nil)
	end)
	if type(result) ~= "table" or result.ok ~= true then
		return
	end
	local nextReady = now + GameConfig.Ore.RegrowSeconds
	cooldowns[nodeId] = nextReady
	self._host:effect(player, {
		Type = "OreMined",
		NodeId = nodeId,
		Ore = oreId,
		Amount = mined,
		ReadyAt = nextReady,
	})
	self._host:pushState(player)
end

-- On entering the sanctuary: which nodes this player still has regrowing.
function OreService:SendCooldowns(player: Player)
	local now = Workspace:GetServerTimeNow()
	local pending = {}
	for nodeId, readyAt in self:_cooldownsFor(player) do
		if readyAt > now then
			pending[nodeId] = readyAt
		end
	end
	self._host:effect(player, { Type = "OreCooldowns", Nodes = pending })
end

function OreService:BuyUpgrade(player: Player, id: any)
	return self._host:mutate(player, function(profile)
		profile.Ore = OreMath.SanitizeBalances(profile.Ore, GameConfig.Ore)
		profile.OreUpgrades = OreMath.SanitizeLevels(profile.OreUpgrades, GameConfig.Ore)
		local ok, message = OreMath.Purchase(GameConfig.Ore, profile.Ore, profile.OreUpgrades, id)
		if not ok then
			return ActionResponse.Error(message)
		end
		return ActionResponse.Success(message, { UpgradeId = id })
	end)
end

function OreService:PublicState(profile)
	return OreMath.PublicState(profile.Ore, profile.OreUpgrades, GameConfig.Ore)
end

function OreService:Forget(player: Player)
	self._cooldowns[player] = nil
end

-- The CollectionService tag the client uses to find outcrops as they stream in.
OreService.NODE_TAG = NODE_TAG

return OreService
