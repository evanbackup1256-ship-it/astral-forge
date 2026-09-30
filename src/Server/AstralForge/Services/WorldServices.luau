--!strict
--[=[
	WorldServices: merged module suite.
	Members (5): OreService, RiftBossService, SanctuaryBuilder, SanctuaryFeatures, WorldService.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("WorldServices: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("WorldServices: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: OreService   (merged from OreService.luau, 285 lines)
-- ======================================================================
__defs["OreService"] = function()
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
local SanctuaryLayout = require(Shared:WaitForChild("SharedData"))("SanctuaryLayout")
local AssetKit = require(Shared:WaitForChild("SharedData"))("AssetKit")
local Vfx = require(Shared:WaitForChild("SharedData"))("Vfx")
local Modules = script.Parent.Parent:WaitForChild("Modules")
local OreMath = require(Modules:WaitForChild("OreMath"))
local Economy = require(Modules:WaitForChild("EconomyMath"))("Economy")
local ActionResponse = require(Modules:WaitForChild("ProfileMath"))("ActionResponse")
local ProfileBagMath = require(Modules:WaitForChild("ProfileBagMath"))

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
	-- Reserve the node before mutate() can yield, so a second request that lands while this one
	-- waits on the profile sees the cooldown instead of mining the same node twice.
	local nextReady = now + GameConfig.Ore.RegrowSeconds
	cooldowns[nodeId] = nextReady
	local result = self._host:mutate(player, function(profile)
		local bonus = Economy.OreEffect(profile, "OreYield")
		mined = OreMath.Yield(GameConfig.Ore, oreId, bonus, function(low, high)
			return self._random:NextInteger(low, high)
		end)
		if mined <= 0 then
			return ActionResponse.Error("Nothing to mine here.")
		end
		profile.Ore = OreMath.SanitizeBalances(profile.Ore, GameConfig.Ore)
		profile.Ore[oreId] = ProfileBagMath.AddFinite(profile.Ore[oreId], mined)
		ProfileBagMath.BumpStat(profile, "OreMined", mined)
		return ActionResponse.Success(nil)
	end)
	if type(result) ~= "table" or result.ok ~= true then
		cooldowns[nodeId] = readyAt
		return
	end
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
end

-- ======================================================================
-- Module: RiftBossService   (merged from RiftBossService.luau, 306 lines)
-- ======================================================================
__defs["RiftBossService"] = function()
-- The Rift Warden: a shared boss that forms in the Riftmaw every few minutes.
--
-- The server owns only the truth: phase, health, strikes, slams and rewards.
-- It publishes them as attributes on one small anchor model (streamed to every
-- client in the sanctuary) and as effects for moment-to-moment events. The
-- Warden's body, its animation and every visual effect are built on the
-- client (sanctuaryWorld.luau), so the fight looks smooth at any frame rate
-- and costs no replication.
--
-- The rules themselves live in RiftBossMath (pure, unit tested).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SanctuaryLayout = require(Shared:WaitForChild("SharedData"))("SanctuaryLayout")
local Modules = script.Parent.Parent:WaitForChild("Modules")
local RiftBossMath = require(Modules:WaitForChild("EconomyMath"))("RiftBossMath")
local OreMath = require(Modules:WaitForChild("OreMath"))
local Economy = require(Modules:WaitForChild("EconomyMath"))("Economy")
local ActionResponse = require(Modules:WaitForChild("ProfileMath"))("ActionResponse")
local ProfileBagMath = require(Modules:WaitForChild("ProfileBagMath"))

local STEP_SECONDS = 0.25
-- Quiet time after a phase change before the boss attacks again.
local PHASE_BREATHER_SECONDS = 3

local RiftBossService = {}
RiftBossService.__index = RiftBossService

function RiftBossService.new(host)
	local self = setmetatable({}, RiftBossService)
	self._host = host
	self._roster = GameConfig.RiftBosses
	self._bossIndex = 1
	self._config = self._roster[1]
	self._state = RiftBossMath.Initial(Workspace:GetServerTimeNow(), self._config)
	self._damage = {}
	self._strikes = {}
	self._lastStrike = {}
	self._dazedUntil = {}
	self._phaseIndex = 1
	self._nextAttackAt = math.huge
	-- Attacks in flight. Each is { Kind, At, ... } and resolves when `now` passes At.
	self._events = {}
	self._random = Random.new()
	self._running = false
	return self
end

function RiftBossService:_arena()
	local arena = SanctuaryLayout.arena()
	return self._host.world:SanctuaryPoint(arena.Center), self._host.world:SanctuaryPoint(arena.Hover), arena.Radius
end

function RiftBossService:Start()
	local folder = self._host.world:SanctuaryFolder()
	if folder == nil then
		warn("[RiftBoss] the sanctuary world was not built; the Warden will not appear")
		return
	end
	local _, hover = self:_arena()
	local model = Instance.new("Model")
	model.Name = "RiftWarden"
	pcall(function()
		(model :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(hover)
	anchor.Parent = model
	model.PrimaryPart = anchor
	model:SetAttribute("BossName", self._config.Name)
	model.Parent = folder
	self._model = model
	self:_publish()
	self._running = true
	task.spawn(function()
		while self._running do
			task.wait(STEP_SECONDS)
			local ok, problem = pcall(function()
				self:_step()
			end)
			if not ok then
				warn(`[RiftBoss] step failed: {problem}`)
			end
		end
	end)
end

function RiftBossService:Stop()
	self._running = false
end

function RiftBossService:_publish()
	local model = self._model
	if model == nil then
		return
	end
	local state = self._state
	local config = self._config
	model:SetAttribute("BossName", config.Name)
	model:SetAttribute("BossKind", config.Kind)
	model:SetAttribute("BossTitle", config.Title)
	model:SetAttribute("BossPhase", self._phaseIndex)
	model:SetAttribute("Phase", state.Phase)
	model:SetAttribute("EndsAt", state.EndsAt)
	model:SetAttribute("Health", state.Health)
	model:SetAttribute("MaxHealth", state.MaxHealth)
end

-- Everyone in the sanctuary, and everyone standing in the arena.
function RiftBossService:_fighters(): ({ Player }, { [Player]: Vector3 })
	local center, _, radius = self:_arena()
	local present = self._host.world:SanctuaryPlayers()
	local inArena = {}
	for _, player in present do
		local root = self._host.world:SanctuaryRoot(player)
		if root ~= nil then
			local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			if offset.Magnitude <= radius + 8 then
				inArena[player] = root.Position
			end
		end
	end
	return present, inArena
end

function RiftBossService:_broadcast(payload, onlySanctuary: boolean)
	local targets = if onlySanctuary then self._host.world:SanctuaryPlayers() else Players:GetPlayers()
	for _, player in targets do
		self._host:effect(player, payload)
	end
end

function RiftBossService:_announce(title: string, body: string, onlySanctuary: boolean)
	local targets = if onlySanctuary then self._host.world:SanctuaryPlayers() else Players:GetPlayers()
	for _, player in targets do
		self._host:toast(player, title, body, "Special")
	end
end

function RiftBossService:_step()
	local now = Workspace:GetServerTimeNow()
	local present, inArena = self:_fighters()
	local state, entered = RiftBossMath.Step(self._state, now, #present, self._config)
	self._state = state
	if entered == "Dormant" then
		-- The roster rotates: the next appearance is the next boss in the list.
		self._bossIndex = RiftBossMath.NextBoss(self._bossIndex, #self._roster)
		self._config = self._roster[self._bossIndex]
		table.clear(self._events)
		self._attacking = false
	elseif entered == "Forming" then
		table.clear(self._damage)
		table.clear(self._strikes)
		table.clear(self._dazedUntil)
		table.clear(self._events)
		self._phaseIndex = 1
		self._attacking = false
		self:_announce(
			`{self._config.Name} is forming`,
			"It wakes in the Riftmaw in under a minute. Open the rift and head south to fight it.",
			false
		)
	elseif entered == "Active" then
		self._phaseIndex = 1
		self._attacking = false
		self._nextAttackAt = now + self:_attackDelay(now)
		table.clear(self._events)
		self:_broadcast({
			Type = "RiftBossAwake",
			Kind = self._config.Kind,
			Name = self._config.Name,
			Title = self._config.Title,
		}, true)
	elseif entered == "Defeated" then
		table.clear(self._events)
		self:_rewardFighters()
	elseif entered == "Escaped" then
		table.clear(self._events)
		self:_announce(`{self._config.Name} escaped`, "It slipped back into the rift. It will return.", true)
	end
	if state.Phase == "Active" then
		self:_phases(now)
		self:_attacks(now, inArena)
	end
	self:_publish()
end

-- Seconds to wait before the next attack, shortened as the fight goes on.
function RiftBossService:_attackDelay(_now: number): number
	local config = self._config
	return RiftBossMath.SlamDelay(self._random:NextNumber(), config)
		* RiftBossMath.PhaseDelayScale(self._phaseIndex, config.PhaseDelayScale)
end

-- Crossing a health threshold announces the next phase and gives everyone a breather
-- before the boss starts on its harder moves.
function RiftBossService:_phases(now: number)
	local config = self._config
	local phase = RiftBossMath.PhaseIndex(self._state.Health, self._state.MaxHealth, config.Phases)
	if phase <= self._phaseIndex then
		return
	end
	self._phaseIndex = phase
	self._nextAttackAt = math.max(self._nextAttackAt, now + PHASE_BREATHER_SECONDS)
	self:_broadcast({ Type = "RiftBossPhase", Kind = config.Kind, Name = config.Name, Phase = phase, Breather = PHASE_BREATHER_SECONDS }, true)
end

-- Stagger a fighter unless they already are (so overlapping attacks cannot chain-stun).
function RiftBossService:_daze(player: Player, now: number, center: Vector3)
	if (self._dazedUntil[player] or 0) > now then
		return
	end
	self._dazedUntil[player] = now + self._config.DazeSeconds
	self._host:effect(player, {
		Type = "RiftBossStagger",
		Center = center,
		Daze = self._config.DazeSeconds,
	})
end

local function flatPositions(inArena: { [Player]: Vector3 })
	local positions = {}
	for player, position in inArena do
		positions[player] = { X = position.X, Z = position.Z }
	end
	return positions
end

-- Attack scheduler: resolve whatever is in flight, and when nothing is, pick the next
-- attack (weighted, gated by phase) once the wait is over.
function RiftBossService:_attacks(now: number, inArena: { [Player]: Vector3 })
	local events = self._events
	local index = 1
	while index <= #events do
		local event = events[index]
		if self:_resolve(event, now, inArena) then
			table.remove(events, index)
		else
			index += 1
		end
	end
	if #events > 0 then
		return
	end
	if self._attacking then
		self._attacking = false
		self._nextAttackAt = now + self:_attackDelay(now)
		return
	end
	if now < self._nextAttackAt then
		return
	end
	local attack = RiftBossMath.PickAttack(self._config.Attacks, self._phaseIndex, self._random:NextNumber())
	if attack == nil then
		self._nextAttackAt = now + self:_attackDelay(now)
		return
	end
	self._attacking = true
	self:_begin(attack, now, inArena)
end

-- Fighters to aim at, in a stable random order.
function RiftBossService:_targets(inArena: { [Player]: Vector3 }): { Vector3 }
	local targets = {}
	for _, position in inArena do
		table.insert(targets, position)
	end
	for i = #targets, 2, -1 do
		local j = self._random:NextInteger(1, i)
		targets[i], targets[j] = targets[j], targets[i]
	end
	return targets
end

function RiftBossService:_slamAt(aim: Vector3, floorY: number, detonateAt: number)
	local config = self._config
	local center = { X = aim.X, Y = floorY, Z = aim.Z }
	table.insert(self._events, { Kind = "Slam", At = detonateAt, Center = center, Radius = config.SlamRadius })
	self:_broadcast({
		Type = "RiftBossSlam",
		BossKind = config.Kind,
		Center = center,
		Radius = config.SlamRadius,
		DetonateAt = detonateAt,
	}, true)
end

function RiftBossService:_begin(attack, now: number, inArena: { [Player]: Vector3 })
	local config = self._config
	local center = self:_arena()
	local targets = self:_targets(inArena)
	local params = attack.Params or {}
	local telegraph = params.TelegraphSeconds or config.SlamTelegraphSeconds
	if attack.Kind == "Slam" then
		self:_slamAt(targets[1] or center, center.Y, now + telegraph)
	elseif attack.Kind == "TwinSlam" then
		-- Two fighters marked at once; with only one present the second lands beside them.
		local first = targets[1] or center
		local second = targets[2]
		if second == nil then
			local angle = self._random:NextNumber() * math.pi * 2
			second = Vector3.new(first.X + math.cos(angle) * 16, first.Y, first.Z + math.sin(angle) * 16)
		end
		self:_slamAt(first, center.Y, now + telegraph)
		self:_slamAt(second, center.Y, now + telegraph + 0.45)
	elseif attack.Kind == "Rings" then
		local first = now + telegraph
		for ring = 1, params.Count do
			table.insert(self._events, {
				Kind = "Ring",
				At = first + (ring - 1) * params.StepSeconds,
				Radius = params.FirstRadius + (ring - 1) * params.Gap,
				Width = params.Width,
				Index = ring,
			})
		end
		self:_broadcast({
			Type = "RiftBossRings",
			BossKind = config.Kind,
			Center = center,
			Count = params.Count,
			FirstRadius = params.FirstRadius,
			Gap = params.Gap,
			Width = params.Width,
			StepSeconds = params.StepSeconds,
			DetonateAt = first,
		}, true)
	elseif attack.Kind == "Sweep" then
		local aim = targets[1] or center
		local direction = if self._random:NextNumber() < 0.5 then -1 else 1
		local heading = math.atan2(aim.Z - center.Z, aim.X - center.X)
		local speed = direction * params.Speed
		-- Start behind the target so there is time to see it coming.
		local startAngle = heading - direction * 1.1
		local beginAt = now + telegraph
		local endAt = beginAt + params.Seconds
		table.insert(self._events, {
			Kind = "Sweep",
			At = beginAt,
			EndAt = endAt,
			Start = startAngle,
			Speed = speed,
			HalfWidth = params.HalfWidth,
			Range = params.Range,
			Center = center,
		})
		self:_broadcast({
			Type = "RiftBossSweep",
			BossKind = config.Kind,
			Center = center,
			StartAngle = startAngle,
			Speed = speed,
			HalfWidth = params.HalfWidth,
			Range = params.Range,
			BeginAt = beginAt,
			EndAt = endAt,
		}, true)
	end
end

-- Returns true once the event is finished and can be dropped.
function RiftBossService:_resolve(event, now: number, inArena: { [Player]: Vector3 }): boolean
	if now < event.At then
		return false
	end
	local config = self._config
	if event.Kind == "Slam" then
		local hits = RiftBossMath.SlamHits(event.Center.X, event.Center.Z, event.Radius, flatPositions(inArena))
		for _, player in hits do
			self:_daze(player, now, event.Center)
		end
		self:_broadcast({ Type = "RiftBossSlamLand", BossKind = config.Kind, Center = event.Center, Radius = event.Radius }, true)
		return true
	elseif event.Kind == "Ring" then
		local center = self:_arena()
		local hits = RiftBossMath.RingHits(center.X, center.Z, event.Radius, event.Width, flatPositions(inArena))
		for _, player in hits do
			self:_daze(player, now, center)
		end
		self:_broadcast({
			Type = "RiftBossRingLand",
			BossKind = config.Kind,
			Center = center,
			Radius = event.Radius,
			Width = event.Width,
			Index = event.Index,
		}, true)
		return true
	elseif event.Kind == "Sweep" then
		local angle = RiftBossMath.SweepAngleAt(event.Start, event.Speed, math.min(now, event.EndAt) - event.At)
		local hits = RiftBossMath.SweepHits(
			event.Center.X,
			event.Center.Z,
			angle,
			event.HalfWidth,
			event.Range,
			flatPositions(inArena)
		)
		for _, player in hits do
			self:_daze(player, now, event.Center)
		end
		return now >= event.EndAt
	end
	return true
end

function RiftBossService:Strike(player: Player)
	local config = self._config
	if self._state.Phase ~= "Active" then
		return ActionResponse.Error(`{config.Name} isn't here right now.`)
	end
	local root = self._host.world:SanctuaryRoot(player)
	if root == nil then
		return ActionResponse.Error("Step into the sanctuary first.")
	end
	local center = self:_arena()
	local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	if offset.Magnitude > config.StrikeRange then
		return ActionResponse.Error(`Get closer to {config.Name}.`)
	end
	local now = Workspace:GetServerTimeNow()
	if (self._dazedUntil[player] or 0) > now then
		return ActionResponse.Error("You're staggered.")
	end
	if now - (self._lastStrike[player] or -math.huge) < config.StrikeCooldown then
		return ActionResponse.Error("Too fast.")
	end
	self._lastStrike[player] = now
	local profile = self._host.data:Get(player)
	if profile == nil then
		return ActionResponse.Error("Your profile is still loading.")
	end
	local level = self._host:level(profile)
	local bonus = Economy.OreEffect(profile, "BossDamage")
	local damage, crit = RiftBossMath.StrikeDamage(level, bonus, self._random:NextNumber(), config)
	self._state = RiftBossMath.Hit(self._state, damage)
	local userId = player.UserId
	self._damage[userId] = (self._damage[userId] or 0) + damage
	self._strikes[userId] = (self._strikes[userId] or 0) + 1
	self:_publish()
	return ActionResponse.Success(nil, {
		Damage = damage,
		Crit = crit,
		Health = self._state.Health,
		MaxHealth = self._state.MaxHealth,
	})
end

function RiftBossService:_rewardFighters()
	local config = self._config
	local rewards = RiftBossMath.Rewards(self._damage, self._strikes, config)
	for userId, bag in rewards do
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			continue
		end
		local lines = {}
		local result = self._host:mutate(player, function(profile)
			profile.Ore = OreMath.SanitizeBalances(profile.Ore, GameConfig.Ore)
			for currency in config.Rewards do
				local amount = bag[currency] or 0
				if amount <= 0 then
					continue
				end
				if currency == "Stardust" then
					profile.Stardust = ProfileBagMath.AddFinite(profile.Stardust, amount)
				elseif profile.Ore[currency] ~= nil then
					profile.Ore[currency] = ProfileBagMath.AddFinite(profile.Ore[currency], amount)
				end
				table.insert(lines, `+{amount} {currency}`)
			end
			ProfileBagMath.BumpStat(profile, "WardenDefeats", 1)
			return ActionResponse.Success(nil)
		end)
		if type(result) == "table" and result.ok == true then
			table.sort(lines)
			self._host:toast(player, `{config.Name} defeated`, table.concat(lines, "  ·  "), "Special")
			self._host:effect(player, { Type = "RiftBossDefeated", Name = config.Name, Share = bag.Share })
			self._host:pushState(player)
		end
	end
	-- Everyone who watched gets the moment, reward or not.
	self:_broadcast({ Type = "RiftBossFell", Kind = config.Kind, Name = config.Name }, true)
end

function RiftBossService:Forget(player: Player)
	self._lastStrike[player] = nil
	self._dazedUntil[player] = nil
end

return RiftBossService
end

-- ======================================================================
-- Module: SanctuaryBuilder   (merged from SanctuaryBuilder.luau, 675 lines)
-- ======================================================================
__defs["SanctuaryBuilder"] = function()
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
local Layout = require(Shared:WaitForChild("SharedData"))("SanctuaryLayout")
local AssetKit = require(Shared:WaitForChild("SharedData"))("AssetKit")
local Vfx = require(Shared:WaitForChild("SharedData"))("Vfx")

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
-- Mid-tones, not near-blacks: under moonlight anything darker reads as a
-- flat silhouette with no shape.
local MATERIAL_COLORS = {
	[Enum.Material.Slate] = Color3.fromRGB(98, 106, 132),
	[Enum.Material.Basalt] = Color3.fromRGB(88, 74, 78),
	[Enum.Material.Rock] = Color3.fromRGB(88, 90, 110),
	[Enum.Material.Glacier] = Color3.fromRGB(146, 118, 206),
	[Enum.Material.Limestone] = Color3.fromRGB(172, 188, 216),
	[Enum.Material.Asphalt] = Color3.fromRGB(74, 70, 98),
	[Enum.Material.CrackedLava] = Color3.fromRGB(255, 120, 60),
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

-- Terrain

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

-- Kit meshes and effects

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

-- Bridges

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

-- Waystones

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

-- Region scenery

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
end

-- ======================================================================
-- Module: SanctuaryFeatures   (merged from SanctuaryFeatures.luau, 95 lines)
-- ======================================================================
__defs["SanctuaryFeatures"] = function()
-- The sanctuary's gameplay features behind one door: ore outcrops and the
-- Foundry (OreService), the Rift Warden (RiftBossService) and waystone travel
-- (WorldService). GameService holds a single SanctuaryFeatures and forwards
-- to it, so its own (very large) factory only grows by one local.
--
-- The services talk to the game through a narrow host table instead of
-- reaching into GameService: world, profile data, a mutation, a toast, an
-- effect, a state push, and a player's Forge Level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("Protocol"))
local Modules = script.Parent.Parent:WaitForChild("Modules")
local ProgressionGate = require(Modules:WaitForChild("EconomyMath"))("ProgressionGate")
local ActionResponse = require(Modules:WaitForChild("ProfileMath"))("ActionResponse")
local OreService = __load("OreService")
local RiftBossService = __load("RiftBossService")

local SanctuaryFeatures = {}
SanctuaryFeatures.__index = SanctuaryFeatures

function SanctuaryFeatures.new(gameService)
	local self = setmetatable({}, SanctuaryFeatures)
	self._game = gameService
	local host = {
		world = gameService._world,
		data = gameService._data,
	}
	function host:mutate(player: Player, callback)
		return gameService:_mutate(player, callback)
	end
	function host:toast(player: Player, title: string, body: string, tone: string?)
		gameService:_toastPlayer(player, title, body, tone)
	end
	function host:effect(player: Player, payload)
		if player.Parent ~= nil then
			gameService._effect:FireClient(player, payload)
		end
	end
	function host:pushState(player: Player)
		gameService:_pushState(player)
	end
	function host:level(profile): number
		return ProgressionGate.Level(profile)
	end
	self._host = host
	self.Ore = OreService.new(host)
	self.Boss = RiftBossService.new(host)
	return self
end

function SanctuaryFeatures:Start()
	self.Ore:Start()
	self.Boss:Start()
end

function SanctuaryFeatures:Stop()
	self.Boss:Stop()
end

-- Called once a player's avatar stands in the sanctuary.
function SanctuaryFeatures:OnEntered(player: Player)
	self.Ore:SendCooldowns(player)
end

function SanctuaryFeatures:Forget(player: Player)
	self.Ore:Forget(player)
	self.Boss:Forget(player)
end

-- The Foundry block of the state snapshot.
function SanctuaryFeatures:OreState(profile)
	return self.Ore:PublicState(profile)
end

-- Handle a sanctuary action, or return nil if it isn't one.
function SanctuaryFeatures:Handle(player: Player, action: string, payload: any)
	if action == Protocol.Actions.BuyOreUpgrade then
		return self.Ore:BuyUpgrade(player, payload and payload.Id)
	elseif action == Protocol.Actions.StrikeRiftBoss then
		return self.Boss:Strike(player)
	elseif action == Protocol.Actions.TravelWaystone then
		local recall = type(payload) == "table" and payload.Recall == true
		local ok, message = self._host.world:TravelWaystone(player, payload and payload.To, recall)
		if not ok then
			return ActionResponse.Error(message)
		end
		self._host:effect(player, { Type = "WaystoneArrived", Name = message })
		return ActionResponse.Success(nil, { Destination = message })
	end
	return nil
end

return SanctuaryFeatures
end

-- ======================================================================
-- Module: WorldService   (merged from WorldService.luau, 1137 lines)
-- ======================================================================
__defs["WorldService"] = function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local SanctuaryLayout = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("SanctuaryLayout")
local SanctuaryBuilder = __load("SanctuaryBuilder")

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

		-- Causeway: floating slabs with real gaps, so the walk in has rhythm.
		topPart(model, "Part", "CausewayStart", Vector3.new(16, 3.2, 14), Vector3.new(0, 0, 30), 2, PATH, Enum.Material.Slate, true)
		topPart(model, "Part", "CausewayA", Vector3.new(11, 2.8, 9), Vector3.new(-3.2, 0.25, 21), -7, PATH, Enum.Material.Slate, true)
		topPart(model, "Part", "CausewayB", Vector3.new(10, 2.8, 8), Vector3.new(3.6, 0.55, 14.5), 9, PATH, Enum.Material.Cobblestone, true)
		topPart(model, "Part", "CausewayC", Vector3.new(12, 2.8, 9), Vector3.new(-1.4, 0.85, 8), -4, PATH, Enum.Material.Slate, true)
		-- Two drifting stones off the causeway: optional footing, and they give
		-- the void beneath a sense of depth.
		topPart(model, "Part", "DriftEast", Vector3.new(5, 1.8, 4.5), Vector3.new(11.5, -1.2, 18), 16, ROCK, Enum.Material.Rock, true)
		topPart(model, "Part", "DriftWest", Vector3.new(4.4, 1.6, 4), Vector3.new(-11.8, -2.4, 12.5), -22, ROCK, Enum.Material.Rock, true)

		-- Terrace: the main ring the player actually walks on.
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

		-- Dais and altar at the north end.
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
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		return __load(name)
	end,
})
