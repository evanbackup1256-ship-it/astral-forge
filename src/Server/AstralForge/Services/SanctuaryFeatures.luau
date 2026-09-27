--!strict
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
local ProgressionGate = require(Modules:WaitForChild("ProgressionGate"))
local ActionResponse = require(Modules:WaitForChild("ActionResponse"))
local OreService = require(script.Parent:WaitForChild("OreService"))
local RiftBossService = require(script.Parent:WaitForChild("RiftBossService"))

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
