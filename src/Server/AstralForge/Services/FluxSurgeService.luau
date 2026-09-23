--!strict

return function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

	local FluxSurgeService = {}
	FluxSurgeService.__index = FluxSurgeService

	local function surgeConfig()
		local config = GameConfig.FluxSurge
		return {
			Interval = math.max(60, math.floor(tonumber(config and config.IntervalSeconds) or (20 * 60))),
			Duration = math.max(10, math.floor(tonumber(config and config.DurationSeconds) or 60)),
			Multiplier = math.max(1, tonumber(config and config.Multiplier) or 2),
			ToastTitle = (config and config.ToastTitle) or "Flux Surge!",
			ToastBody = (config and config.ToastBody) or "All production is doubled for 60 seconds!",
			EndTitle = (config and config.EndTitle) or "Flux Surge ended",
			EndBody = (config and config.EndBody) or "Production returned to normal.",
		}
	end

	function FluxSurgeService.new(toastCallback: (Player, string, string, string) -> (), effectCallback: (Player, any) -> ())
		local self = setmetatable({}, FluxSurgeService)
		self._endsAt = 0
		self._accumulator = 0
		self._toast = toastCallback
		self._effect = effectCallback
		return self
	end

	function FluxSurgeService:Multiplier(now: number?): number
		local config = surgeConfig()
		return (self._endsAt > (now or os.time())) and config.Multiplier or 1
	end

	function FluxSurgeService:EndsAt(): number
		return self._endsAt
	end

	function FluxSurgeService:Active(now: number?): boolean
		return self._endsAt > (now or os.time())
	end

	function FluxSurgeService:State(now: number?)
		local timestamp = now or os.time()
		local config = surgeConfig()
		local active = self._endsAt > timestamp
		return {
			Active = active,
			EndsAt = self._endsAt,
			Multiplier = if active then config.Multiplier else 1,
			DurationSeconds = config.Duration,
			IntervalSeconds = config.Interval,
			-- Capacity never reads this multiplier — SteadyProduction only.
			AffectsCapacity = false,
		}
	end

	function FluxSurgeService:Tick(deltaTime: number)
		local now = os.time()
		local config = surgeConfig()
		local wasActive = self._endsAt > now
		self._accumulator += deltaTime
		if not wasActive and self._accumulator >= config.Interval then
			self._accumulator = 0
			self._endsAt = now + config.Duration
			ModuleLog.Info("Flux Surge", "A server-wide Flux Surge has started!")
			for _, player in Players:GetPlayers() do
				self._toast(player, config.ToastTitle, config.ToastBody, "Special")
				self._effect(player, {
					Type = "FluxSurge",
					EndsAt = self._endsAt,
					Multiplier = config.Multiplier,
					AffectsCapacity = false,
				})
			end
		elseif wasActive and self._endsAt <= now then
			ModuleLog.Info("Flux Surge", "The server-wide Flux Surge has ended.")
			for _, player in Players:GetPlayers() do
				self._toast(player, config.EndTitle, config.EndBody, "Info")
				self._effect(player, {
					Type = "FluxSurgeEnded",
					EndsAt = 0,
					Multiplier = 1,
					AffectsCapacity = false,
				})
			end
			self._endsAt = 0
		end
	end

	-- Cold / missing service fallback for client rails (wave49).
	function FluxSurgeService.IdleState()
		return {
			Active = false,
			Multiplier = 1,
			AffectsCapacity = false,
		}
	end

	return FluxSurgeService
end
