--!strict

return function()


	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))

	local include = ReplicatedStorage:FindFirstChild("rbxts_include")
	assert(include, "Matter requires ReplicatedStorage.rbxts_include")
	local nodeModules = include:FindFirstChild("node_modules")
	assert(nodeModules, "Matter requires the replicated node_modules folder")
	local rbxts = nodeModules:FindFirstChild("@rbxts")
	assert(rbxts, "Matter requires the replicated @rbxts folder")
	local matterPackage = rbxts:FindFirstChild("matter")
	assert(matterPackage, "@rbxts/matter is not replicated; run npm install and restart Rojo")
	local matterModule = matterPackage:FindFirstChild("lib")
	assert(matterModule and matterModule:IsA("ModuleScript"), "@rbxts/matter/lib is not a ModuleScript")

	local Matter = ModuleLog.Require(matterModule, "Matter ECS")

	local PlayerComponent = Matter.component("AstralForge.Player")
	local RuntimeComponent = Matter.component("AstralForge.Runtime")

	local function playerProductionSystem(world: any, service: any): ()
		local deltaTime = Matter.useDeltaTime()
		for _entity, playerState, runtimeState in world:query(PlayerComponent, RuntimeComponent) do
			service:_tickPlayer(playerState.Value, runtimeState.Value, deltaTime)
		end
	end

	local playerProduction = {
		system = playerProductionSystem,
		priority = 5,
	}

	local MatterRuntime = {}
	MatterRuntime.__index = MatterRuntime

	function MatterRuntime.new(service: any)
		local self = setmetatable({}, MatterRuntime)
		self.World = Matter.World.new()
		self._service = service
		self._stepEvent = Instance.new("BindableEvent")
		self._loop = Matter.Loop.new(self.World, service)
		self._loop.trackErrors = false
		self._connections = nil
		self._scheduled = false
		return self
	end

	function MatterRuntime:SpawnPlayer(player: Player, runtime: any, _profile: any): number
		return self.World:spawn(
			PlayerComponent({ Value = player }),
			RuntimeComponent({ Value = runtime })
		)
	end

	function MatterRuntime:Despawn(entity: number): ()
		if self.World:contains(entity) then
			self.World:despawn(entity)
		end
	end

	function MatterRuntime:Start(): ()
		if self._connections then
			return
		end
		if not self._scheduled then
			self._loop:scheduleSystems({ playerProduction })
			self._scheduled = true
		end
		self._connections = self._loop:begin({
			default = self._stepEvent.Event,
		})
		ModuleLog.Info("tick", "5 Hz loop started")
	end

	function MatterRuntime:Step(): ()
		if self._connections then
			self._stepEvent:Fire()
		end
	end

	function MatterRuntime:Stop(): ()
		if self._connections then
			for _, connection in self._connections do
				connection:Disconnect()
			end
			table.clear(self._connections)
			self._connections = nil
		end
		self.World:clear()
	end

	return table.freeze(MatterRuntime)
end
