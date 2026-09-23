--!strict

return function()
	local Players = game:GetService("Players")
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))

	local FluxSurgeService = {}
	FluxSurgeService.__index = FluxSurgeService

	local FLUX_SURGE_INTERVAL = 20 * 60
	local FLUX_SURGE_DURATION = 60
	local FLUX_SURGE_MULTIPLIER = 2

	function FluxSurgeService.new(toastCallback: (Player, string, string, string) -> (), effectCallback: (Player, any) -> ())
		local self = setmetatable({}, FluxSurgeService)
		self._endsAt = 0
		self._accumulator = 0
		self._toast = toastCallback
		self._effect = effectCallback
		return self
	end

	function FluxSurgeService:Multiplier(now: number?): number
		return (self._endsAt > (now or os.time())) and FLUX_SURGE_MULTIPLIER or 1
	end

	function FluxSurgeService:EndsAt(): number
		return self._endsAt
	end

	function FluxSurgeService:Tick(deltaTime: number)
		local now = os.time()
		local wasActive = self._endsAt > now
		self._accumulator += deltaTime
		if not wasActive and self._accumulator >= FLUX_SURGE_INTERVAL then
			self._accumulator = 0
			self._endsAt = now + FLUX_SURGE_DURATION
			ModuleLog.Info("Flux Surge", "A server-wide Flux Surge has started!")
			for _, player in Players:GetPlayers() do
				self._toast(player, "Flux Surge!", "All production is doubled for 60 seconds!", "Special")
				self._effect(player, { Type = "FluxSurge", EndsAt = self._endsAt, Multiplier = FLUX_SURGE_MULTIPLIER })
			end
		elseif wasActive and self._endsAt <= now then
			ModuleLog.Info("Flux Surge", "The server-wide Flux Surge has ended.")
			for _, player in Players:GetPlayers() do
				self._toast(player, "Flux Surge ended", "Production returned to normal.", "Info")
			end
			self._endsAt = 0
		end
	end

	return FluxSurgeService
end
