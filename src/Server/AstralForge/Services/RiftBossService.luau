--!strict
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
local SanctuaryLayout = require(Shared:WaitForChild("SanctuaryLayout"))
local Modules = script.Parent.Parent:WaitForChild("Modules")
local RiftBossMath = require(Modules:WaitForChild("RiftBossMath"))
local OreMath = require(Modules:WaitForChild("OreMath"))
local Economy = require(Modules:WaitForChild("Economy"))
local ActionResponse = require(Modules:WaitForChild("ActionResponse"))
local ProfileBagMath = require(Modules:WaitForChild("ProfileBagMath"))

local STEP_SECONDS = 0.25

local RiftBossService = {}
RiftBossService.__index = RiftBossService

function RiftBossService.new(host)
	local self = setmetatable({}, RiftBossService)
	self._host = host
	self._config = GameConfig.RiftBoss
	self._state = RiftBossMath.Initial(Workspace:GetServerTimeNow(), self._config)
	self._damage = {}
	self._strikes = {}
	self._lastStrike = {}
	self._dazedUntil = {}
	self._nextSlamAt = math.huge
	self._pendingSlam = nil
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
	if entered == "Forming" then
		table.clear(self._damage)
		table.clear(self._strikes)
		table.clear(self._dazedUntil)
		self._pendingSlam = nil
		self:_announce(
			`{self._config.Name} is forming`,
			"It wakes in the Riftmaw in under a minute. Open the rift and head south to fight it.",
			false
		)
	elseif entered == "Active" then
		self._nextSlamAt = now + RiftBossMath.SlamDelay(self._random:NextNumber(), self._config)
		self._pendingSlam = nil
		self:_broadcast({ Type = "RiftBossAwake" }, true)
	elseif entered == "Defeated" then
		self._pendingSlam = nil
		self:_rewardFighters()
	elseif entered == "Escaped" then
		self._pendingSlam = nil
		self:_announce(`{self._config.Name} escaped`, "It slipped back into the rift. It will return.", true)
	end
	if state.Phase == "Active" then
		self:_slams(now, inArena)
	end
	self:_publish()
end

-- A slam: telegraph a ring on the floor under a fighter, then stagger anyone
-- still inside when it lands.
function RiftBossService:_slams(now: number, inArena: { [Player]: Vector3 })
	local pending = self._pendingSlam
	if pending ~= nil then
		if now < pending.DetonateAt then
			return
		end
		local positions = {}
		for player, position in inArena do
			positions[player] = { X = position.X, Z = position.Z }
		end
		local hits = RiftBossMath.SlamHits(pending.Center.X, pending.Center.Z, self._config.SlamRadius, positions)
		for _, player in hits do
			self._dazedUntil[player] = now + self._config.DazeSeconds
			self._host:effect(player, {
				Type = "RiftBossStagger",
				Center = pending.Center,
				Daze = self._config.DazeSeconds,
			})
		end
		self:_broadcast({
			Type = "RiftBossSlamLand",
			Center = pending.Center,
			Radius = self._config.SlamRadius,
		}, true)
		self._pendingSlam = nil
		self._nextSlamAt = now + RiftBossMath.SlamDelay(self._random:NextNumber(), self._config)
		return
	end
	if now < self._nextSlamAt then
		return
	end
	local center = self:_arena()
	local targets = {}
	for _, position in inArena do
		table.insert(targets, position)
	end
	local aim = if #targets > 0 then targets[self._random:NextInteger(1, #targets)] else center
	local slamAt = { X = aim.X, Y = center.Y, Z = aim.Z }
	self._pendingSlam = { Center = slamAt, DetonateAt = now + self._config.SlamTelegraphSeconds }
	self:_broadcast({
		Type = "RiftBossSlam",
		Center = slamAt,
		Radius = self._config.SlamRadius,
		DetonateAt = now + self._config.SlamTelegraphSeconds,
	}, true)
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
			self._host:effect(player, { Type = "RiftBossDefeated", Share = bag.Share })
			self._host:pushState(player)
		end
	end
	-- Everyone who watched gets the moment, reward or not.
	self:_broadcast({ Type = "RiftBossFell" }, true)
end

function RiftBossService:Forget(player: Player)
	self._lastStrike[player] = nil
	self._dazedUntil[player] = nil
end

return RiftBossService
