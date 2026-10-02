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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SanctuaryLayout = require(Shared:WaitForChild("SharedData"))("SanctuaryLayout")
local Modules = script.Parent.Parent:WaitForChild("Modules")
local RiftBossMath = require(Modules:WaitForChild("EconomyMath"))("RiftBossMath")
local BossSanctuaryConfig = require(Shared:WaitForChild("SharedData"))("SanctuaryConfig")
local InsertService = game:GetService("InsertService")
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
	-- Start anywhere in the rotation so the first fight after a server starts varies.
	self._bossIndex = Random.new():NextInteger(1, #self._roster)
	self._config = self._roster[self._bossIndex]
	self._state = RiftBossMath.Initial(Workspace:GetServerTimeNow(), self._config)
	self._damage = {}
	self._strikes = {}
	self._lastStrike = {}
	self._dazedUntil = {}
	self._adds = {}
	self._nextAddId = 1
	-- Behaviour: who stands still (anchor, since), a queued combo, enrage, and recent burst damage.
	self._idle = {}
	self._comboQueue = {}
	self._enraged = false
	self._activeAt = 0
	self._burst = {}
	self._breakUntil = 0
	self._breakCooldownUntil = 0
	self._nextUltimateAt = math.huge
	self._finalStandDone = false
	self._phaseIndex = 1
	self._nextAttackAt = math.huge
	-- Attacks in flight. Each is { Kind, At, ... } and resolves when `now` passes At.
	self._events = {}
	self._random = Random.new()
	self._running = false
	return self
end

-- Where the boss stands: the arena's floor plus however far it has walked. Attacks start from here.
function RiftBossService:_bossFloor(): Vector3
	local center = self:_arena()
	local walk = self._walk or Vector3.zero
	return Vector3.new(center.X + walk.X, center.Y, center.Z + walk.Z)
end

-- Bosses walk. WalkSpeed (studs/s) and StandOff (how close it likes to get) come from the boss's config;
-- a boss with no WalkSpeed stays put. It plants its feet while an attack is going on, then closes on
-- whoever it wants next; with nobody to chase it paces the arena.
function RiftBossService:_walkStep(now: number, dt: number, inArena: { [Player]: Vector3 })
	local config = self._config
	local speed = config.WalkSpeed or 0
	local walk = self._walk or Vector3.zero
	local moving = 0
	if speed > 0 and self._state.Phase == "Active" and not self._attacking and #self._events == 0 and now >= self._breakUntil then
		local center, _, radius = self:_arena()
		local limit = radius * 0.6
		local goal: Vector3? = nil
		local standOff = config.StandOff or 22
		-- Stay on one fighter for a few seconds; re-picking every tick (the ranking has a random term) made
		-- the boss swing between two fighters instead of walking to either.
		local chosen = self._walkTarget
		if chosen == nil or now >= (self._walkRepickAt or 0) or inArena[chosen] == nil then
			chosen = nil
			local targets = self:_targets(inArena, 0.4)
			if targets[1] ~= nil then
				local best = math.huge
				for player, position in inArena do
					local gap = (position - targets[1]).Magnitude
					if gap < best then
						best, chosen = gap, player
					end
				end
			end
			self._walkTarget, self._walkRepickAt = chosen, now + 4
		end
		local goalPoint: Vector3? = if chosen ~= nil then inArena[chosen] else nil
		local floor = Vector3.new(center.X + walk.X, 0, center.Z + walk.Z)
		if goalPoint ~= nil then
			local toward = Vector3.new(goalPoint.X - floor.X, 0, goalPoint.Z - floor.Z)
			local distance = toward.Magnitude
			if distance > standOff + 3 then
				goal = floor + toward.Unit * math.min(distance - standOff, speed * 1.5)
			elseif distance < standOff * 0.55 and distance > 0.5 then
				goal = floor - toward.Unit * speed * 0.8
				speed *= 0.6
			end
		else
			-- nobody to chase: pace round the arena
			if self._patrolAt == nil or now >= self._patrolAt then
				local angle = self._random:NextNumber() * math.pi * 2
				self._patrol = Vector3.new(math.cos(angle), 0, math.sin(angle)) * limit * (0.4 + 0.6 * self._random:NextNumber())
				self._patrolAt = now + 6 + self._random:NextNumber() * 4
			end
			local patrol: Vector3 = self._patrol
			local toward = Vector3.new(center.X + patrol.X - floor.X, 0, center.Z + patrol.Z - floor.Z)
			if toward.Magnitude > 3 then
				goal = floor + toward.Unit * speed
				speed *= 0.7
			end
		end
		if goal ~= nil then
			local step = Vector3.new(goal.X - floor.X, 0, goal.Z - floor.Z)
			local reach = speed * dt
			if step.Magnitude > reach then
				step = step.Unit * reach
			end
			local nextWalk = walk + step
			if nextWalk.Magnitude > limit then
				nextWalk = nextWalk.Unit * limit
			end
			moving = (nextWalk - walk).Magnitude / math.max(dt, 1e-3)
			walk = nextWalk
		end
	end
	self._walk = walk
	local model = self._model
	if model ~= nil then
		local center, hover = self:_arena()
		model:PivotTo(CFrame.new(hover.X + walk.X, hover.Y, hover.Z + walk.Z))
		model:SetAttribute("BossSpeed", moving)
		model:SetAttribute("BossFloorY", center.Y)
	end
end
function RiftBossService:_arena()
	local arena = SanctuaryLayout.arena(self._config.Island)
	return self._host.world:SanctuaryPoint(arena.Center), self._host.world:SanctuaryPoint(arena.Hover), arena.Radius
end

-- The bosses' VFX meshes (built in Blender, uploaded as one model): load it once and
-- publish the pieces under their own names for every client to clone from.
local VFX_MESHES = {
	"W_RiftTear", "W_VoidClaw", "W_SealGlyph", "C_NoteRing", "C_TuningSpear", "C_ResonanceSpiral",
	"R_FlameCrown", "R_EmberSpike", "R_FireSpiral", "S_FeatherBlade", "S_HaloSpikes", "S_BoltZig",
	"I_CrystalCluster", "I_Snowflake", "I_SpikeFan", "K_Crescent", "K_SwordRain", "K_RuneRing",
}

function RiftBossService:_loadVfxKit()
	local kit = BossSanctuaryConfig.BossVfxKit
	if type(kit) ~= "table" or type(kit.Id) ~= "number" or kit.Id <= 0 or ReplicatedStorage:FindFirstChild("BossVfxKit") ~= nil then
		return
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(kit.Id)
	end)
	if not ok or typeof(result) ~= "Instance" then
		warn(`[RiftBoss] couldn't load the boss VFX kit {kit.Id}: {result}. The game owner must own the asset.`)
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BossVfxKit"
	for _, item in result:GetDescendants() do
		if not item:IsA("MeshPart") then
			continue
		end
		for _, name in VFX_MESHES do
			if string.sub(item.Name, 1, #name) == name and folder:FindFirstChild(name) == nil then
				local copy = item:Clone()
				copy.Name = name
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.Parent = folder
				break
			end
		end
	end
	folder.Parent = ReplicatedStorage
	result:Destroy()
end
-- The Blender-built boss bodies: one uploaded model per boss, its textured pieces published
-- together under ReplicatedStorage.BossBodyKit (names like "Knight_hips").
function RiftBossService:_loadBodyKit()
	local kit = BossSanctuaryConfig.BossBodyKit
	if type(kit) ~= "table" or next(kit) == nil or ReplicatedStorage:FindFirstChild("BossBodyKit") ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BossBodyKit"
	for kind, id in kit do
		if type(id) ~= "number" or id <= 0 then
			continue
		end
		local ok, result = false, nil :: any
		for attempt = 1, 4 do -- Roblox answers 502 now and then; try again
			ok, result = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if ok and typeof(result) == "Instance" then
				break
			end
			task.wait(2 * attempt)
		end
		if not ok or typeof(result) ~= "Instance" then
			warn(`[RiftBoss] couldn't load the {kind} body {id}: {result}. The game owner must own the asset.`)
			continue
		end
		for _, item in result:GetDescendants() do
			if item:IsA("MeshPart") and string.sub(item.Name, 1, #kind + 1) == kind .. "_" and folder:FindFirstChild(item.Name) == nil then
				local copy = item:Clone()
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.Parent = folder
			end
		end
		result:Destroy()
	end
	folder.Parent = ReplicatedStorage
end
function RiftBossService:Start()
	-- Live servers too: an admin (ServerConfig.AdminUserIds) types /boss <kind|all|stop> in chat; the client sends it here.
	local admin = Instance.new("RemoteEvent")
	admin.Name = "BossAdminCommand"
	admin.Parent = ReplicatedStorage
	admin.OnServerEvent:Connect(function(player, text)
		local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
		local allowed = ServerConfig.AdminUserIds[player.UserId] ~= nil
			or (RunService:IsStudio() and ServerConfig.AllowStudioAdmins == true)
		if not allowed or type(text) ~= "string" or #text > 40 then
			return
		end
		local word = string.lower(text)
		if word == "stop" then
			self._chain = nil
			self:_announce("Boss chain stopped", "The rotation resumes as normal.", false)
			return
		end
		if word == "all" then
			self._chain = { Index = 1 }
			self._adminForce = self._roster[1].Kind
			self:_announce("Every boss, one after another", "Starting with " .. self._roster[1].Name .. ".", false)
			return
		end
		for _, candidate in self._roster do
			if string.lower(candidate.Kind) == word or string.lower(candidate.Name) == word then
				self._chain = nil
				self._adminForce = candidate.Kind
				self:_announce(`{candidate.Name} summoned`, "It answers an admin's call.", false)
				return
			end
		end
	end)
	-- Tell the client who may see the boss panel (the server still re-checks on every command).
	local function mark(player: Player)
		local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
		if ServerConfig.AdminUserIds[player.UserId] ~= nil or (RunService:IsStudio() and ServerConfig.AllowStudioAdmins == true) then
			player:SetAttribute("BossAdmin", true)
		end
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	if RunService:IsStudio() then
		-- Studio only: lets the command bar (which runs on the client while playing) set RiftBossForce / RiftBossDemo.
		local bridge = Instance.new("RemoteEvent")
		bridge.Name = "BossStudioCommand"
		bridge.Parent = ReplicatedStorage
		bridge.OnServerEvent:Connect(function(_player, name, value)
			if (name == "RiftBossForce" or name == "RiftBossDemo") and type(value) == "string" and #value < 40 then
				Workspace:SetAttribute(name, value)
			end
		end)
	end
	task.spawn(function()
		self:_loadVfxKit()
		self:_loadBodyKit()
	end)
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

-- Put the boss's anchor over its own island's arena.
function RiftBossService:_moveToArena()
	local model = self._model
	if model ~= nil and model.PrimaryPart ~= nil then
		local _, hover = self:_arena()
		model:PivotTo(CFrame.new(hover))
		model:SetAttribute("BossSpeed", 0)
		model:SetAttribute("BossFloorY", self:_arena().Y)
	end
	self._walk = Vector3.zero
	self._patrolAt = nil
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
	model:SetAttribute("BossIsland", config.Island)
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

-- Studio only: workspace:SetAttribute("RiftBossForce", "Choir") (or "Warden", "Regent")
-- summons that boss now, skipping the wait, so a fight can be seen without sitting through
-- the 9-minute rotation. Ignored on live servers.
function RiftBossService:_forced(now: number)
	local kind = self._adminForce
	self._adminForce = nil
	if kind == nil then
		if not RunService:IsStudio() then
			return
		end
		kind = Workspace:GetAttribute("RiftBossForce")
		if type(kind) ~= "string" then
			return
		end
		Workspace:SetAttribute("RiftBossForce", nil)
	end
	for index, candidate in self._roster do
		if candidate.Kind == kind then
			self._bossIndex = index
			self._config = candidate
			self:_moveToArena()
			table.clear(self._events)
			self._attacking = false
			self._state = { Phase = "Dormant", EndsAt = now, Health = 0, MaxHealth = 0 }
			return
		end
	end
end

-- Studio only: workspace:SetAttribute("RiftBossDemo", "All") (or one boss kind) walks the boss(es) through every
-- attack and every ultimate one at a time, a pause between, so each can be watched on its own. The move now
-- playing is in workspace attribute RiftBossDemoNow and shown as a toast. Set it to "Stop" to end it.
local DEMO_PAUSE_SECONDS = 5
function RiftBossService:_demoMoves(config)
	local moves = {}
	for index, attack in config.Attacks do
		local gate = if (attack.MinPhase or 1) > 1 then ` (phase {attack.MinPhase}+)` else ""
		table.insert(moves, { Label = `move {index}: {attack.Kind}{gate}`, Attack = attack })
	end
	local names = {}
	for name, def in config.Ultimates or {} do
		if def.Chain == nil then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for _, name in names do
		local def = config.Ultimates[name]
		table.insert(moves, { Label = `ULTIMATE: {name}`, Attack = { Kind = def.Kind, Params = def.Params, Weight = 1, Ultimate = name } })
	end
	return moves
end

function RiftBossService:_demo(now: number, inArena: { [Player]: Vector3 })
	if not RunService:IsStudio() then
		return
	end
	local request = Workspace:GetAttribute("RiftBossDemo")
	if type(request) == "string" then
		Workspace:SetAttribute("RiftBossDemo", nil)
		if request == "Stop" then
			self._demoRun = nil
			Workspace:SetAttribute("RiftBossDemoNow", nil)
			self._state = { Phase = "Dormant", EndsAt = now, Health = 0, MaxHealth = 0 }
			return
		end
		local queue = {}
		for _, candidate in self._roster do
			if request == "All" or candidate.Kind == request then
				table.insert(queue, candidate)
			end
		end
		if #queue == 0 then
			return
		end
		self._demoRun = { Queue = queue, Boss = 0, Moves = {}, Move = 0, IdleSince = nil, Started = false }
	end
	local run = self._demoRun
	if run == nil then
		return
	end
	-- hold the fight open and the boss healthy; only the scripted moves are played
	self._nextAttackAt = math.huge
	self._nextUltimateAt = math.huge
	self._activeAt = now
	table.clear(self._comboQueue)
	local state = self._state
	if state.Phase == "Active" and state.MaxHealth > 0 then
		self._state = { Phase = "Active", EndsAt = now + 3600, Health = state.MaxHealth, MaxHealth = state.MaxHealth }
		self._phaseIndex = 3
	end
	if run.Boss == 0 or (run.Move >= #run.Moves and run.Started and #self._events == 0 and not self._attacking and #self._adds == 0 and now - (run.IdleSince or now) >= DEMO_PAUSE_SECONDS) then
		run.Boss += 1
		if run.Boss > #run.Queue then
			self._demoRun = nil
			Workspace:SetAttribute("RiftBossDemoNow", "demo finished")
			self:_announce("Boss demo finished", "Every move of every boss has been shown.", false)
			self._state = { Phase = "Dormant", EndsAt = now, Health = 0, MaxHealth = 0 }
			return
		end
		local config = run.Queue[run.Boss]
		for index, candidate in self._roster do
			if candidate == config then
				self._bossIndex = index
			end
		end
		self._config = config
		self:_moveToArena()
		table.clear(self._events)
		table.clear(self._adds)
		self._attacking = false
		self._state = { Phase = "Dormant", EndsAt = now, Health = 0, MaxHealth = 0 }
		run.Moves = self:_demoMoves(config)
		run.Move = 0
		run.IdleSince = nil
		run.Started = false
		Workspace:SetAttribute("RiftBossDemoNow", `{config.Name}: waking`)
		return
	end
	if state.Phase ~= "Active" then
		return
	end
	run.Started = true
	if #self._events > 0 or self._attacking or #self._adds > 0 then
		run.IdleSince = nil
		return
	end
	if run.IdleSince == nil then
		run.IdleSince = now
		return
	end
	if now - run.IdleSince < DEMO_PAUSE_SECONDS or run.Move >= #run.Moves then
		return
	end
	run.Move += 1
	local move = run.Moves[run.Move]
	local config = self._config
	local label = `{config.Name} - {move.Label} ({run.Move}/{#run.Moves})`
	Workspace:SetAttribute("RiftBossDemoNow", label)
	self:_announce(config.Name, move.Label, false)
	run.IdleSince = nil
	self._attacking = true
	self:_begin(move.Attack, now, inArena)
end
-- /boss all: when one boss ends, the next in the roster is summoned at once, until the last one.
function RiftBossService:_chainNext()
	local chain = self._chain
	if chain == nil then
		return
	end
	chain.Index += 1
	local nextBoss = self._roster[chain.Index]
	if nextBoss == nil then
		self._chain = nil
		self:_announce("That was every boss", "The rotation resumes as normal.", false)
		return
	end
	self._adminForce = nextBoss.Kind
end

function RiftBossService:_step()
	local now = Workspace:GetServerTimeNow()
	self:_forced(now)
	local present, inArena = self:_fighters()
	self:_demo(now, inArena)
	local state, entered = RiftBossMath.Step(self._state, now, #present, self._config)
	self._state = state
	if entered == "Dormant" then
		-- The roster rotates: the next appearance is the next boss in the list.
		self._bossIndex = RiftBossMath.NextBoss(self._bossIndex, #self._roster)
		self._config = self._roster[self._bossIndex]
		self:_moveToArena()
		table.clear(self._events)
		table.clear(self._adds)
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
			`It wakes in under a minute. {self._config.Approach}`,
			false
		)
	elseif entered == "Active" then
		self._phaseIndex = 1
		self._attacking = false
		self._enraged = false
		self._activeAt = now
		table.clear(self._comboQueue)
		table.clear(self._burst)
		self._breakUntil = 0
		self._breakCooldownUntil = 0
		self._finalStandDone = false
		self._nextUltimateAt = now + (self._config.UltimateEvery or math.huge)
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
		table.clear(self._adds)
		self:_rewardFighters()
		self:_chainNext()
	elseif entered == "Escaped" then
		table.clear(self._events)
		table.clear(self._adds)
		self:_announce(`{self._config.Name} escaped`, "It slipped back into the rift. It will return.", true)
		self:_chainNext()
	end
	if state.Phase == "Active" then
		self:_phases(now)
		self:_track(now, inArena)
		self:_enrage(now)
		self:_ultimates(now)
		self:_stepAdds(now, inArena)
		self:_walkStep(now, STEP_SECONDS, inArena)
		self:_attacks(now, inArena)
	end
	self:_publish()
end

-- Seconds to wait before the next attack, shortened as the fight goes on.
function RiftBossService:_attackDelay(_now: number): number
	local config = self._config
	local fighters = #self._host.world:SanctuaryPlayers()
	return RiftBossMath.SlamDelay(self._random:NextNumber(), config)
		* RiftBossMath.PhaseDelayScale(self._phaseIndex, config.PhaseDelayScale)
		* RiftBossMath.DelayScaleForFighters(fighters)
		* (if self._enraged then 0.62 else 1)
end

-- Who has stood still, and for how long: a fighter who has not moved more than a few studs for a
-- while becomes a favourite target, so camping in one spot is not a strategy.
function RiftBossService:_track(now: number, inArena: { [Player]: Vector3 })
	for player, position in inArena do
		local entry = self._idle[player]
		if entry == nil or (Vector3.new(position.X - entry.X, 0, position.Z - entry.Z)).Magnitude > 6 then
			self._idle[player] = { X = position.X, Z = position.Z, Since = now }
		end
	end
	for player in self._idle do
		if inArena[player] == nil then
			self._idle[player] = nil
		end
	end
end

-- A fight that drags on while the boss is still healthy enrages it once: a short warning, then
-- shorter waits and more chained attacks until it falls.
function RiftBossService:_enrage(now: number)
	if self._enraged then
		return
	end
	local state = self._state
	local fraction = if state.MaxHealth > 0 then state.Health / state.MaxHealth else 0
	if RiftBossMath.Enraged(now - self._activeAt, self._config.ActiveSeconds, fraction) then
		self._enraged = true
		self._nextAttackAt = math.max(self._nextAttackAt, now + 2)
		self:_broadcast({ Type = "RiftBossEnrage", Kind = self._config.Kind, Name = self._config.Name }, true)
	end
end

-- ULTIMATES (mega bosses). A boss's Ultimates table names set pieces built from the ordinary attack
-- kinds with heavier parameters. They are queued, never rolled: at phase changes (PhaseUltimates), every
-- UltimateEvery seconds from phase 3, and once as a last stand (FinalStand) when it is nearly beaten.
function RiftBossService:_queueUltimate(name: string, front: boolean?)
	local def = self._config.Ultimates and self._config.Ultimates[name]
	if def == nil then
		return
	end
	if def.Chain ~= nil then
		for index, link in def.Chain do
			self:_queueUltimate(link, front and index == 1)
		end
		return
	end
	local attack = { Kind = def.Kind, Params = def.Params, Weight = 1, Ultimate = name }
	if front then
		table.insert(self._comboQueue, 1, attack)
	else
		table.insert(self._comboQueue, attack)
	end
end

function RiftBossService:_ultimates(now: number)
	local config = self._config
	if config.Ultimates == nil then
		return
	end
	local state = self._state
	local fraction = if state.MaxHealth > 0 then state.Health / state.MaxHealth else 1
	if config.FinalStand ~= nil and not self._finalStandDone and fraction < 0.1 then
		self._finalStandDone = true
		table.clear(self._comboQueue)
		self:_queueUltimate(config.FinalStand)
		return
	end
	if self._phaseIndex >= 3 and now >= self._nextUltimateAt and #self._comboQueue == 0 and #self._events == 0 and not self._attacking then
		local roster = config.UltimateRoster or {}
		if #roster > 0 then
			self:_queueUltimate(roster[self._random:NextInteger(1, #roster)])
		end
		self._nextUltimateAt = now + (config.UltimateEvery or 40) * (if self._enraged then 0.7 else 1)
	end
end
-- After an attack is chosen it may queue its follow-up from the boss's combo table.
function RiftBossService:_queueCombo(attack)
	local config = self._config
	local follow = RiftBossMath.ComboNext(config.Combos, attack.Kind, self._phaseIndex, self._random:NextNumber(), if self._enraged then 1.5 else 1)
	if follow == nil then
		return
	end
	for _, candidate in config.Attacks do
		if candidate.Kind == follow and (candidate.MinPhase or 1) <= self._phaseIndex then
			table.insert(self._comboQueue, candidate)
			return
		end
	end
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
	-- Each new phase calls reinforcements: right after the breather it summons, if it can.
	for _, candidate in config.Attacks do
		if candidate.Kind == "Summon" and (candidate.MinPhase or 1) <= phase then
			table.insert(self._comboQueue, 1, candidate)
			break
		end
	end
	-- A mega boss answers each phase with an ultimate (before the reinforcements).
	local phaseUltimate = config.PhaseUltimates and config.PhaseUltimates[phase]
	if phaseUltimate ~= nil then
		self:_queueUltimate(phaseUltimate, true)
	end
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
		-- A chained follow-up comes almost at once; otherwise the usual breather.
		self._nextAttackAt = now + (if #self._comboQueue > 0 then 0.55 else self:_attackDelay(now))
		return
	end
	if now < self._nextAttackAt or now < self._breakUntil then
		return
	end
	local attack
	if #self._comboQueue > 0 then
		attack = table.remove(self._comboQueue, 1)
	else
		attack = RiftBossMath.PickAttack(self._config.Attacks, self._phaseIndex, self._random:NextNumber())
		if attack ~= nil then
			self:_queueCombo(attack)
		end
	end
	if attack == nil then
		self._nextAttackAt = now + self:_attackDelay(now)
		return
	end
	self._attacking = true
	self:_begin(attack, now, inArena)
end

-- Fighters to aim at, most wanted first: whoever has done the most damage, anyone standing still,
-- and a little chance. Positions are led by the fighter's own velocity so a telegraph lands
-- where they are heading (`lead` seconds ahead), not where they were.
function RiftBossService:_targets(inArena: { [Player]: Vector3 }, lead: number?): { Vector3 }
	local now = Workspace:GetServerTimeNow()
	local total = 0
	for _, amount in self._damage do
		total += amount
	end
	local entries = {}
	for player, position in inArena do
		local share = if total > 0 then (self._damage[player.UserId] or 0) / total else 0
		local idle = self._idle[player]
		local score = RiftBossMath.TargetScore(share, if idle ~= nil then now - idle.Since else 0, self._random:NextNumber())
		table.insert(entries, { Id = player, Score = score })
	end
	local targets = {}
	for _, player in RiftBossMath.RankTargets(entries) do
		local position = inArena[player]
		local root = self._host.world:SanctuaryRoot(player)
		local velocity = if root ~= nil then root.AssemblyLinearVelocity else Vector3.zero
		local x, z = RiftBossMath.LeadPosition(position.X, position.Z, velocity.X, velocity.Z, lead or 0, 14)
		table.insert(targets, Vector3.new(x, position.Y, z))
	end
	return targets
end
function RiftBossService:_slamAt(aim: Vector3, floorY: number, detonateAt: number, radius: number?, element: string?)
	local config = self._config
	local center = { X = aim.X, Y = floorY, Z = aim.Z }
	local size = radius or config.SlamRadius
	table.insert(self._events, { Kind = "Slam", At = detonateAt, Center = center, Radius = size, Element = element })
	self:_broadcast({
		Type = "RiftBossSlam",
		BossKind = config.Kind,
		Center = center,
		Radius = size,
		DetonateAt = detonateAt,
		Element = element,
	}, true)
end

-- Adds (the boss's summoned wisps) circle the arena on a path both sides can compute from the
-- spawn message alone, so nothing streams. Where is add `add` at server time `t`?
local function addPosition(add, t: number): Vector3
	local angle = add.Angle + add.Speed * (t - add.StartAt)
	return Vector3.new(add.Center.X + math.cos(angle) * add.Orbit, add.Center.Y + add.Height, add.Center.Z + math.sin(angle) * add.Orbit)
end

function RiftBossService:_summon(params, now: number, center: Vector3)
	local config = self._config
	local fuseAt = now + params.FuseSeconds
	local spawned = {}
	local base = self._random:NextNumber() * math.pi * 2
	for index = 1, params.Count do
		local add = {
			Id = self._nextAddId,
			Angle = base + (index - 1) / params.Count * math.pi * 2,
			Speed = params.OrbitSpeed * (if index % 2 == 0 then -1 else 1),
			Orbit = params.Orbit * (0.65 + 0.35 * ((index % 3) / 2)),
			Height = 4 + (index % 2) * 3,
			Center = center,
			StartAt = now,
			FuseAt = fuseAt,
			Health = params.Health,
			BlastRadius = params.BlastRadius,
			Element = params.Element,
		}
		self._nextAddId += 1
		table.insert(self._adds, add)
		table.insert(spawned, { Id = add.Id, Angle = add.Angle, Speed = add.Speed, Orbit = add.Orbit, Height = add.Height })
	end
	self:_broadcast({
		Type = "RiftBossAdds",
		BossKind = config.Kind,
		Center = center,
		StartAt = now,
		FuseAt = fuseAt,
		Health = params.Health,
		BlastRadius = params.BlastRadius,
		Element = params.Element,
		Adds = spawned,
	}, true)
end

-- Adds that reach their fuse blow up where they are; anyone close is staggered.
function RiftBossService:_stepAdds(now: number, inArena: { [Player]: Vector3 })
	local adds = self._adds
	local index = 1
	while index <= #adds do
		local add = adds[index]
		if now >= add.FuseAt then
			local at = addPosition(add, add.FuseAt)
			for player, position in inArena do
				if (Vector3.new(position.X - at.X, 0, position.Z - at.Z)).Magnitude <= add.BlastRadius then
					self:_daze(player, now, add.Center)
				end
			end
			self:_broadcast({ Type = "RiftBossAddBlast", BossKind = self._config.Kind, Id = add.Id, At = at, Radius = add.BlastRadius, Element = add.Element }, true)
			table.remove(adds, index)
		else
			index += 1
		end
	end
end

-- The add nearest a fighter, if one is within reach of their blade.
function RiftBossService:_addNear(position: Vector3, now: number)
	local best, bestDistance = nil, 18
	for _, add in self._adds do
		local distance = (addPosition(add, now) - position).Magnitude
		if distance < bestDistance then
			best, bestDistance = add, distance
		end
	end
	return best
end

function RiftBossService:_begin(attack, now: number, inArena: { [Player]: Vector3 })
	local config = self._config
	local center = self:_bossFloor()
	local params = attack.Params or {}
	local telegraph = params.TelegraphSeconds or config.SlamTelegraphSeconds
	local targets = self:_targets(inArena, telegraph * 0.45)
	-- Tell clients which move this is: the boss winds up and speaks accordingly.
	self:_broadcast({ Type = "RiftBossAttack", BossKind = config.Kind, Attack = attack.Kind }, true)
	if attack.Ultimate ~= nil then
		self:_broadcast({ Type = "RiftBossUltimate", BossKind = config.Kind, Name = attack.Ultimate, Seconds = telegraph }, true)
	end
	if attack.Kind == "Slam" then
		self:_slamAt(targets[1] or center, center.Y, now + telegraph, nil, params.Element)
	elseif attack.Kind == "TwinSlam" then
		-- Two fighters marked at once; with only one present the second lands beside them.
		local first = targets[1] or center
		local second = targets[2]
		if second == nil then
			local angle = self._random:NextNumber() * math.pi * 2
			second = Vector3.new(first.X + math.cos(angle) * 16, first.Y, first.Z + math.sin(angle) * 16)
		end
		self:_slamAt(first, center.Y, now + telegraph, nil, params.Element)
		self:_slamAt(second, center.Y, now + telegraph + 0.45, nil, params.Element)
	elseif attack.Kind == "Meteors" then
		-- Fire from the sky across the whole arena: every other one lands on a fighter, the rest
		-- anywhere, so standing still in a gap is not safe either.
		local _, _, arenaRadius = self:_arena()
		for shot = 1, params.Count do
			local aim
			local target = targets[(shot - 1) % math.max(1, #targets) + 1]
			if shot % 2 == 1 and target ~= nil then
				aim = target
			else
				local angle = self._random:NextNumber() * math.pi * 2
				local distance = math.sqrt(self._random:NextNumber()) * arenaRadius * 0.9
				aim = Vector3.new(center.X + math.cos(angle) * distance, center.Y, center.Z + math.sin(angle) * distance)
			end
			self:_slamAt(aim, center.Y, now + telegraph + (shot - 1) * params.StepSeconds, config.SlamRadius * params.RadiusScale, params.Element)
		end
	elseif attack.Kind == "Cage" then
		-- A ring of blows closes round a fighter; the ground inside the ring is safe, so the
		-- answer is to stay put (or slip out between two of them before they land).
		local aim = targets[1] or center
		for spoke = 1, params.Count do
			local angle = (spoke - 1) / params.Count * math.pi * 2 + self._random:NextNumber() * 0.4
			local point = Vector3.new(aim.X + math.cos(angle) * params.Distance, aim.Y, aim.Z + math.sin(angle) * params.Distance)
			self:_slamAt(point, center.Y, now + telegraph, config.SlamRadius * params.RadiusScale, params.Element)
		end
	elseif attack.Kind == "Fissure" then
		-- A line of blows races out from the boss toward a fighter.
		local aim = targets[1] or center
		local direction = Vector3.new(aim.X - center.X, 0, aim.Z - center.Z)
		direction = if direction.Magnitude > 1 then direction.Unit else Vector3.xAxis
		for step = 1, params.Count do
			local point = center + direction * (params.FirstDistance + (step - 1) * params.Gap)
			self:_slamAt(point, center.Y, now + telegraph + (step - 1) * params.StepSeconds, config.SlamRadius * params.RadiusScale, params.Element)
		end
	elseif attack.Kind == "Starburst" then
		-- Blows bloom outward in rings of points: a few near the boss, then more further out.
		local offset = self._random:NextNumber() * math.pi * 2
		for ring = 1, params.Rings do
			local points = params.Points * ring
			for point = 1, points do
				local angle = offset + (point - 1) / points * math.pi * 2 + ring * 0.25
				local distance = params.FirstDistance + (ring - 1) * params.Gap
				local spot = Vector3.new(center.X + math.cos(angle) * distance, center.Y, center.Z + math.sin(angle) * distance)
				self:_slamAt(spot, center.Y, now + telegraph + (ring - 1) * params.StepSeconds, config.SlamRadius * params.RadiusScale, params.Element)
			end
		end	elseif attack.Kind == "Summon" then
		-- Wisps rise from the floor; cut them down before their fuse runs out.
		table.insert(self._events, { Kind = "Summon", At = now + telegraph, Params = params, Center = center })
		self:_broadcast({ Type = "RiftBossSummonCall", BossKind = config.Kind, Center = center, Element = params.Element, At = now + telegraph }, true)	elseif attack.Kind == "Rings" then
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
	elseif attack.Kind == "EchoSlam" then
		-- The same spot struck again and again, each blow wider than the last.
		local aim = targets[1] or center
		for hit = 1, params.Hits do
			self:_slamAt(aim, center.Y, now + telegraph + (hit - 1) * params.StepSeconds, config.SlamRadius * params.Growth ^ (hit - 1))
		end
	elseif attack.Kind == "Volley" then
		-- A run of small slams, one fighter after another (the list wraps round if short).
		for shot = 1, params.Count do
			local target = targets[(shot - 1) % math.max(1, #targets) + 1] or center
			local angle = self._random:NextNumber() * math.pi * 2
			local spread = self._random:NextNumber() * params.Scatter
			local aim = Vector3.new(target.X + math.cos(angle) * spread, target.Y, target.Z + math.sin(angle) * spread)
			self:_slamAt(aim, center.Y, now + telegraph + (shot - 1) * params.StepSeconds, config.SlamRadius * params.RadiusScale, params.Element)
		end
	elseif attack.Kind == "Lances" then
		local angles = RiftBossMath.LanceAngles(params.Count, self._random:NextNumber() * math.pi * 2)
		local fireAt = now + telegraph
		table.insert(self._events, {
			Kind = "Lance",
			At = fireAt,
			Angles = angles,
			HalfWidth = params.HalfWidth,
			Range = params.Range,
			Center = center,
		})
		self:_broadcast({
			Type = "RiftBossLances",
			BossKind = config.Kind,
			Center = center,
			Angles = angles,
			HalfWidth = params.HalfWidth,
			Range = params.Range,
			FireAt = fireAt,
		}, true)
	elseif attack.Kind == "GravityWell" then
		-- Opens under a fighter, drags everyone toward it, then the core detonates.
		local aim = targets[1] or center
		local at = { X = aim.X, Y = center.Y, Z = aim.Z }
		local pullFrom = now + telegraph
		local detonateAt = pullFrom + params.PullSeconds
		table.insert(self._events, { Kind = "Well", At = detonateAt, Center = at, Core = params.Core })
		self:_broadcast({
			Type = "RiftBossWell",
			BossKind = config.Kind,
			Center = at,
			Radius = params.Radius,
			Core = params.Core,
			Strength = params.Strength,
			PullFrom = pullFrom,
			DetonateAt = detonateAt,
		}, true)
	elseif attack.Kind == "Dissonance" then
		-- The whole arena hurts except a few safe pockets.
		local _, _, arenaRadius = self:_arena()
		local relative = RiftBossMath.SafeZones(params.Zones, arenaRadius, params.ZoneRadius, self._random:NextNumber(), self._random:NextNumber())
		local zones = {}
		for _, zone in relative do
			table.insert(zones, { X = center.X + zone.X, Z = center.Z + zone.Z })
		end
		local detonateAt = now + telegraph
		table.insert(self._events, { Kind = "Dissonance", At = detonateAt, Center = center, Zones = zones, Radius = params.ZoneRadius })
		self:_broadcast({
			Type = "RiftBossDissonance",
			BossKind = config.Kind,
			Center = center,
			ArenaRadius = arenaRadius,
			Zones = zones,
			ZoneRadius = params.ZoneRadius,
			DetonateAt = detonateAt,
		}, true)
	elseif attack.Kind == "Wall" then
		-- A wall of flame crosses the arena along a random heading with one gap in it.
		local angle = self._random:NextNumber() * math.pi * 2
		local gapCenter = (self._random:NextNumber() * 2 - 1) * params.Range * 0.55
		local beginAt = now + telegraph
		local endAt = beginAt + params.Range * 2 / params.Speed
		table.insert(self._events, {
			Kind = "Wall",
			At = beginAt,
			EndAt = endAt,
			Center = center,
			Angle = angle,
			Speed = params.Speed,
			Half = params.Half,
			Range = params.Range,
			GapCenter = gapCenter,
			GapHalf = params.GapHalf,
		})
		self:_broadcast({
			Type = "RiftBossWall",
			BossKind = config.Kind,
			Center = center,
			Angle = angle,
			Speed = params.Speed,
			Half = params.Half,
			Range = params.Range,
			GapCenter = gapCenter,
			GapHalf = params.GapHalf,
			BeginAt = beginAt,
			EndAt = endAt,
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
		self:_broadcast({ Type = "RiftBossSlamLand", BossKind = config.Kind, Center = event.Center, Radius = event.Radius, Element = event.Element }, true)
		return true
	elseif event.Kind == "Summon" then
		self:_summon(event.Params, now, event.Center)
		return true
	elseif event.Kind == "Ring" then
		local center = self:_bossFloor()
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
	elseif event.Kind == "Lance" then
		for _, player in RiftBossMath.LanceHits(event.Center.X, event.Center.Z, event.Angles, event.HalfWidth, event.Range, flatPositions(inArena)) do
			self:_daze(player, now, event.Center)
		end
		return true
	elseif event.Kind == "Well" then
		for _, player in RiftBossMath.SlamHits(event.Center.X, event.Center.Z, event.Core, flatPositions(inArena)) do
			self:_daze(player, now, event.Center)
		end
		self:_broadcast({ Type = "RiftBossSlamLand", BossKind = config.Kind, Center = event.Center, Radius = event.Core }, true)
		return true
	elseif event.Kind == "Dissonance" then
		for _, player in RiftBossMath.OutsideZones(event.Zones, event.Radius, flatPositions(inArena)) do
			self:_daze(player, now, event.Center)
		end
		self:_broadcast({ Type = "RiftBossDissonanceLand", BossKind = config.Kind, Center = event.Center }, true)
		return true
	elseif event.Kind == "Wall" then
		-- Test the stretch the wall covered since the last look, so a slow step cannot skip a fighter.
		local along = -event.Range + event.Speed * (math.min(now, event.EndAt) - event.At)
		local previous = event.LastAlong or along
		event.LastAlong = along
		local hits = RiftBossMath.WallHits(
			event.Center.X,
			event.Center.Z,
			event.Angle,
			(along + previous) / 2,
			event.Half + math.abs(along - previous) / 2,
			event.GapCenter,
			event.GapHalf,
			event.Range,
			flatPositions(inArena)
		)
		for _, player in hits do
			self:_daze(player, now, event.Center)
		end
		return now >= event.EndAt
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
	local center = self:_bossFloor()
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
	-- While its poise is broken the boss takes half again as much.
	if now < self._breakUntil then
		damage = math.floor(damage * 1.5 + 0.5)
	end
	-- A wisp within reach of the blade takes the blow instead of the boss.
	local add = self:_addNear(root.Position, now)
	if add ~= nil then
		add.Health -= damage
		local down = add.Health <= 0
		if down then
			table.remove(self._adds, table.find(self._adds, add))
			self:_broadcast({ Type = "RiftBossAddDown", BossKind = config.Kind, Id = add.Id, At = addPosition(add, now), Element = add.Element }, true)
		end
		return ActionResponse.Success(nil, {
			Damage = damage,
			Crit = crit,
			Health = self._state.Health,
			MaxHealth = self._state.MaxHealth,
			Add = true,
		})
	end
	self._state = RiftBossMath.Hit(self._state, damage)
	-- Heavy burst damage inside a few seconds breaks its poise: it reels, its attacks stop for a
	-- moment and it is vulnerable (coordinated fighters are rewarded; it cannot be spammed).
	table.insert(self._burst, { At = now, Damage = damage })
	while #self._burst > 0 and now - self._burst[1].At > 4 do
		table.remove(self._burst, 1)
	end
	if now >= self._breakCooldownUntil and RiftBossMath.PoiseBroken(self._burst, now, 4, self._state.MaxHealth, 0.07) then
		self._breakUntil = now + 2.4
		self._breakCooldownUntil = now + 14
		self._nextAttackAt = math.max(self._nextAttackAt, now + 2.6)
		table.clear(self._comboQueue)
		table.clear(self._burst)
		self:_broadcast({ Type = "RiftBossBreak", Kind = config.Kind, Name = config.Name, Seconds = 2.4 }, true)
	end
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
	self._idle[player] = nil
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
local SanctuaryConfig = require(Shared:WaitForChild("SharedData"))("SanctuaryConfig")

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
	if region.Id == "Riftmaw" then
		-- The hub bridge, and one to each boss island.
		local _, dx, dz = Layout.landing(region)
		local angles = { math.atan2(dz, dx) }
		for _, isle in Layout.isles() do
			table.insert(angles, math.atan2(isle.Center.Z - region.Center.Z, isle.Center.X - region.Center.X))
		end
		return angles
	end
	if string.find(region.Id, "Isle$") ~= nil then
		local _, dx, dz = Layout.isleLanding(region)
		return { math.atan2(dz, dx) }
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
	for index, isle in Layout.isles() do
		local center = world(isle.Center)
		local landings = landingAngles(isle)
		island(terrain, center, isle.Radius, material(isle.Top), material(isle.Under), 4001 + index * 7919, landings)
		if isle.Id == "RegentIsle" then
			-- Lava seams between the dais and the rim, clear of the landing.
			local rng = Random.new(77)
			for _ = 1, 10 do
				local angle = rng:NextNumber(0, math.pi * 2)
				if nearLanding(angle, landings) then
					continue
				end
				local reach = isle.Radius * rng:NextNumber(0.5, 0.7)
				terrain:FillCylinder(CFrame.new(center + Vector3.new(math.cos(angle) * reach, -1, math.sin(angle) * reach)), 2, rng:NextNumber(4, 8), Enum.Material.CrackedLava)
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
	local all = table.clone(Layout.bridges())
	for _, bridge in Layout.isleBridges() do
		table.insert(all, bridge)
	end
	for _, bridge in all do
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

local function triple(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function bossConfigFor(island: string): any
	for _, boss in SanctuaryConfig.RiftBosses do
		if boss.Island == island then
			return boss
		end
	end
	return SanctuaryConfig.RiftBoss
end

-- A ring of neon dashes lying on the floor.
local function floorRing(parent: Instance, center: Vector3, radius: number, width: number, color: Color3, transparency: number)
	local segments = math.max(24, math.floor(radius * 0.95))
	for k = 1, segments do
		local angle = (k / segments) * math.pi * 2
		local at = center + Vector3.new(math.cos(angle) * radius, 0.08, math.sin(angle) * radius)
		local dash = part(parent, "Rune", Vector3.new(width, 0.15, radius * math.pi * 2 / segments * 0.7), CFrame.lookAt(at, center) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Neon, false)
		dash.Transparency = transparency
		dash.CastShadow = false
	end
end

-- A flat round slab (Roblox cylinders lie along X, so it is turned upright).
local function disc(parent: Instance, name: string, at: Vector3, radius: number, height: number, color: Color3, mat: Enum.Material, collide: boolean?): Part
	local slab = part(parent, name, Vector3.new(height, radius * 2, radius * 2), CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, mat, collide)
	slab.Shape = Enum.PartType.Cylinder
	return slab
end

-- Each boss's arena is dressed in its own colours and shapes, but they share a skeleton:
-- a floor pattern, a seal, and pillars whose rift tethers light while it fights.
--   Warden  violet rune ring, basalt pillars
--   Choir   the floor is engraved with the three rings its attack sends out, glass pillars
--   Regent  eight spokes out from the seal (the beam's clock), obsidian spires with flame
function Builder.BuildArena(parent: Instance, island: string?)
	local boss = bossConfigFor(island or "Riftmaw")
	local kind = boss.Kind
	local accent, hot = triple(boss.Theme.Primary), triple(boss.Theme.Hot)
	local arena = Layout.arena(island)
	local center = world(arena.Center)
	floorRing(parent, center, arena.Radius - 8, 0.5, accent, 0.3)
	if kind == "Choir" then
		for _, radius in { 16, 36, 56 } do
			floorRing(parent, center, radius, 0.45, hot, 0.45)
		end
	elseif kind == "Regent" then
		local length = arena.Radius - 18
		for k = 1, 8 do
			local angle = (k / 8) * math.pi * 2
			local mid = 8 + length / 2
			local spoke = part(parent, "Spoke", Vector3.new(length, 0.15, 0.5), CFrame.new(center + Vector3.new(math.cos(angle) * mid, 0.08, math.sin(angle) * mid)) * CFrame.Angles(0, -angle, 0), accent, Enum.Material.Neon, false)
			spoke.Transparency = 0.45
			spoke.CastShadow = false
		end
	end
	local seal = part(parent, "Seal", Vector3.new(0.2, 26, 26), CFrame.new(center + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), accent, Enum.Material.Neon, false)
	seal.Shape = Enum.PartType.Cylinder
	seal.Transparency = 0.7
	seal.CastShadow = false
	tag(seal, "AF_Pulse", { Period = if kind == "Regent" then 2.4 else 3.6 })
	-- A slow vortex over the seal, and where the rift tethers meet.
	local eye = part(parent, "RiftEye", Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), accent, Enum.Material.SmoothPlastic, false)
	eye.Transparency = 1
	Vfx.attach(eye, "Swirl", { Color = accent, Color2 = hot, Size = NumberSequence.new(22, 26) })
	local hub = Instance.new("Attachment")
	hub.Name = "TetherHub"
	hub.Position = Vector3.new(0, 24, 0)
	hub.Parent = seal
	-- Pillars ringing the arena, each topped with light of the boss's colour.
	local count = if kind == "Choir" then 7 elseif kind == "Regent" then 6 elseif kind == "Seraph" then 5 elseif kind == "Rime" then 9 elseif kind == "Knight" then 4 elseif kind == "Astraeon" then 12 else 8
	local pillarColor = if kind == "Choir" then Color3.fromRGB(96, 150, 190) elseif kind == "Regent" then Color3.fromRGB(28, 22, 26) elseif kind == "Seraph" then Color3.fromRGB(70, 84, 120) elseif kind == "Rime" then Color3.fromRGB(170, 214, 240) elseif kind == "Knight" then Color3.fromRGB(22, 18, 34) else Color3.fromRGB(40, 40, 54)
	local pillarMaterial = if kind == "Choir" or kind == "Rime" then Enum.Material.Glass elseif kind == "Seraph" then Enum.Material.Metal else Enum.Material.Basalt
	for k = 1, count do
		local angle = (k / count) * math.pi * 2 + math.pi / count
		local at = center + Vector3.new(math.cos(angle) * arena.PillarRadius, 0, math.sin(angle) * arena.PillarRadius)
		local pillarSize = AssetKit.sized("ArenaPillar", 1.05)
		local useKit = AssetKit.has("ArenaPillar")
		local height = if useKit then pillarSize.Y else 26
		if kind == "Choir" then
			height += 10
			pillarSize = Vector3.new(pillarSize.X * 0.7, height, pillarSize.Z * 0.7)
		elseif kind == "Regent" then
			height += 4
		elseif kind == "Seraph" then
			height += 14
		elseif kind == "Knight" then
			height += 8
		end
		local column = shape(parent, "ArenaPillar", pillarSize, CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, 0), pillarColor, pillarMaterial, true, function()
			return part(parent, "Pillar", Vector3.new(if kind == "Choir" then 3 else 5, height, if kind == "Choir" then 3 else 5), CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, 0), pillarColor, pillarMaterial)
		end)
		column.Name = "Pillar"
		column.CastShadow = true
		if kind == "Choir" or kind == "Rime" then
			column.Transparency = 0.25
		end
		local capAt = CFrame.new(at + Vector3.new(0, height + 2.5, 0))
		local cap = shape(parent, "Star", Vector3.new(3.2, 3.2, 3.2), capAt, accent, Enum.Material.Neon, false, function()
			return part(parent, "PillarLight", Vector3.new(3, 3, 3), capAt * CFrame.Angles(math.rad(45), 0, math.rad(45)), accent, Enum.Material.Neon, false)
		end)
		cap.Name = "PillarLight"
		cap.Transparency = 0.1
		cap.CastShadow = false
		glow(cap, accent, 1.8, 34)
		halo(cap, accent, 7)
		tag(cap, "AF_Spin", { Speed = if kind == "Regent" then 55 else 30 })
		tag(cap, "AF_Pulse", { Period = if kind == "Choir" then 1.6 else 2.8 })
		if kind == "Regent" then
			local flame = Instance.new("Fire")
			flame.Color = accent
			flame.SecondaryColor = hot
			flame.Size = 9
			flame.Heat = 12
			flame.Parent = cap
		end
		-- Rift tethers from every pillar to the seal; the client lights the ones that
		-- belong to whichever boss is forming or fighting.
		local from = Instance.new("Attachment")
		from.Name = "Tether"
		from.Parent = cap
		local beam = Vfx.beam(from, hub, "Tether", { Color = accent, Color2 = hot })
		beam.Enabled = false
		tag(beam, "AF_RiftTether", { BossKind = kind })
	end
end

-- The Hall of the Hollow Choir: a conductor's podium under floating shards of singing glass.
local function choirIsle(parent: Instance, center: Vector3, radius: number, landings: { number })
	local cyan, white = Color3.fromRGB(86, 200, 255), Color3.fromRGB(214, 244, 255)
	for tier = 1, 3 do
		local slab = disc(parent, "Podium", center, 11 - tier * 2.4, tier * 0.9, if tier == 3 then white else Color3.fromRGB(70, 96, 132), if tier == 3 then Enum.Material.Neon else Enum.Material.Glass, true)
		slab.Transparency = if tier == 3 then 0.35 else 0.15
		slab.CastShadow = false
	end
	for k = 1, 16 do
		local angle = (k / 16) * math.pi * 2 + k * 0.37
		local reach = radius * (0.3 + (k % 5) * 0.11)
		local lift = 10 + (k % 4) * 5
		local shard = part(parent, "GlassShard", Vector3.new(1.6, 6 + (k % 3) * 2, 1.6), CFrame.new(center + Vector3.new(math.cos(angle) * reach, lift, math.sin(angle) * reach)) * CFrame.Angles(math.rad(20 * (k % 3)), angle, math.rad(45)), cyan, Enum.Material.Neon, false)
		shard.Transparency = 0.35
		shard.CastShadow = false
		tag(shard, "AF_Bob", { Amplitude = 1 + (k % 3) * 0.6, Period = 3 + (k % 4) })
		tag(shard, "AF_Spin", { Speed = 18 + k * 2 })
		if k % 4 == 0 then
			glow(shard, cyan, 1.2, 24)
		end
	end
	for k = 1, 8 do
		local angle = (k / 8) * math.pi * 2
		lamp(parent, center + Vector3.new(math.cos(angle) * radius * 0.92, 0, math.sin(angle) * radius * 0.92))
	end
	airborne(parent, "ChoirAir", center, radius, "Motes", { Color = cyan, Rate = 7 })
	boulders(parent, center, radius, landings, Color3.fromRGB(96, 118, 150), 511)
end

-- The Cinderthrone: braziers round a dais, and a throne of obsidian spires on the far side.
local function regentIsle(parent: Instance, center: Vector3, radius: number, landings: { number })
	local ember, flameHot = Color3.fromRGB(255, 132, 48), Color3.fromRGB(255, 226, 170)
	local obsidian = Color3.fromRGB(26, 22, 26)
	for tier = 1, 3 do
		local slab = disc(parent, "Dais", center, 12 - tier * 2.6, tier * 0.8, if tier == 3 then ember else obsidian, if tier == 3 then Enum.Material.CrackedLava else Enum.Material.Basalt, true)
		slab.CastShadow = false
	end
	-- Braziers, skipping the side the bridge arrives on.
	for k = 1, 10 do
		local angle = (k / 10) * math.pi * 2
		if nearLanding(angle, landings) then
			continue
		end
		local at = center + Vector3.new(math.cos(angle) * radius * 0.8, 0, math.sin(angle) * radius * 0.8)
		local bowl = disc(parent, "BrazierBowl", at, 2.2, 3, obsidian, Enum.Material.Basalt, true)
		local flame = Instance.new("Fire")
		flame.Color = ember
		flame.SecondaryColor = flameHot
		flame.Size = 8
		flame.Heat = 10
		flame.Parent = bowl
		glow(bowl, ember, 2, 38)
		tag(bowl, "AF_Pulse", { Period = 1.9 + (k % 3) * 0.4 })
	end
	-- The throne: a fan of spires on the side opposite the landing, tallest in the middle.
	local away = (landings[1] or 0) + math.pi
	for k = -3, 3 do
		local angle = away + k * 0.17
		local height = 30 - math.abs(k) * 5
		local base = center + Vector3.new(math.cos(angle) * radius * 0.86, 0, math.sin(angle) * radius * 0.86)
		local spire = part(parent, "ThroneSpire", Vector3.new(3.4, height, 3.4), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, math.rad(k * 3)), obsidian, Enum.Material.Basalt)
		spire.CastShadow = true
		local tip = part(parent, "ThroneGlow", Vector3.new(1.4, 1.4, 1.4), CFrame.new(base + Vector3.new(0, height + 0.8, 0)), ember, Enum.Material.Neon, false)
		tip.Shape = Enum.PartType.Ball
		tip.CastShadow = false
		if math.abs(k) <= 1 then
			local flame = Instance.new("Fire")
			flame.Color = ember
			flame.SecondaryColor = flameHot
			flame.Size = 12
			flame.Heat = 14
			flame.Parent = tip
		end
		tag(tip, "AF_Pulse", { Period = 2.2 })
	end
	airborne(parent, "CinderAir", center, radius, "Rising", { Color = ember, Rate = 9, Speed = NumberRange.new(2, 5) })
	boulders(parent, center, radius, landings, Color3.fromRGB(58, 40, 40), 523)
end

-- The three later boss islands share one dressing, tinted and arranged per boss: a stepped
-- dais, a ring of standing stones lit in the boss's colour, drifting motes, and boulders.
local function bossIsle(parent: Instance, center: Vector3, radius: number, landings: { number }, style: { Accent: Color3, Dark: Color3, Dais: Enum.Material, Air: string, Seed: number, Stones: number, Spikes: boolean })
	for tier = 1, 3 do
		local slab = disc(parent, "Dais", center, 12 - tier * 2.6, tier * 0.8, if tier == 3 then style.Accent else style.Dark, if tier == 3 then Enum.Material.Neon else style.Dais, true)
		slab.Transparency = if tier == 3 then 0.5 else 0
		slab.CastShadow = false
	end
	for k = 1, style.Stones do
		local angle = (k / style.Stones) * math.pi * 2
		if nearLanding(angle, landings) then
			continue
		end
		local height = 9 + (k % 3) * 4
		local base = center + Vector3.new(math.cos(angle) * radius * 0.78, 0, math.sin(angle) * radius * 0.78)
		local stone = part(parent, "StandingStone", Vector3.new(3, height, 3), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, angle, math.rad(if style.Spikes then (k % 2) * 6 else 0)), style.Dark, style.Dais)
		stone.CastShadow = true
		local tip = part(parent, "StoneGlow", Vector3.new(1.3, 1.3, 1.3), CFrame.new(base + Vector3.new(0, height + 0.9, 0)), style.Accent, Enum.Material.Neon, false)
		tip.Shape = Enum.PartType.Ball
		tip.CastShadow = false
		glow(tip, style.Accent, 1.6, 30)
		tag(tip, "AF_Pulse", { Period = 1.8 + (k % 3) * 0.5 })
	end
	airborne(parent, "BossAir", center, radius, style.Air, { Color = style.Accent, Rate = 7 })
	boulders(parent, center, radius, landings, style.Dark, style.Seed)
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
	for _, isle in Layout.isles() do
		local center = world(isle.Center)
		local model = Instance.new("Model")
		model.Name = `Region_{isle.Id}`
		model:SetAttribute("RegionId", isle.Id)
		model.Parent = scenery
		local landings = landingAngles(isle)
		if isle.Id == "ChoirIsle" then
			choirIsle(model, center, isle.Radius, landings)
		elseif isle.Id == "RegentIsle" then
			regentIsle(model, center, isle.Radius, landings)
		elseif isle.Id == "StormIsle" then
			bossIsle(model, center, isle.Radius, landings, { Accent = Color3.fromRGB(96, 168, 255), Dark = Color3.fromRGB(58, 66, 92), Dais = Enum.Material.Slate, Air = "Spark", Seed = 611, Stones = 9, Spikes = true })
		elseif isle.Id == "RimeIsle" then
			bossIsle(model, center, isle.Radius, landings, { Accent = Color3.fromRGB(150, 222, 255), Dark = Color3.fromRGB(150, 196, 226), Dais = Enum.Material.Ice, Air = "Motes", Seed = 613, Stones = 12, Spikes = true })
		elseif isle.Id == "AstraIsle" then
			bossIsle(model, center, isle.Radius, landings, { Accent = Color3.fromRGB(255, 214, 120), Dark = Color3.fromRGB(190, 176, 150), Dais = Enum.Material.Marble, Air = "Embers", Seed = 619, Stones = 14, Spikes = true })
		else
			bossIsle(model, center, isle.Radius, landings, { Accent = Color3.fromRGB(150, 100, 255), Dark = Color3.fromRGB(24, 20, 36), Dais = Enum.Material.Basalt, Air = "Rising", Seed = 617, Stones = 8, Spikes = false })
		end
		Builder.BuildArena(model, isle.Id)
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
