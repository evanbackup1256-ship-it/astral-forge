--!strict

return function()
	local MemoryStoreService = game:GetService("MemoryStoreService")
	local MessagingService = game:GetService("MessagingService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local LiveOps = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("LiveOpsConfig"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))

	local ConvergenceService = {}
	ConvergenceService.__index = ConvergenceService

	local MAP_NAME = "AF_Convergence_v1"
	local TOPIC = "AF_ConvergenceChanged_v1"
	local SHUTDOWN_FLUSH_SECONDS = 2.5

	local function eventProfile(profile, eventId: string)
		profile.LiveOps = type(profile.LiveOps) == "table" and profile.LiveOps or {}
		local current = profile.LiveOps.Convergence
		if type(current) ~= "table" or current.EventId ~= eventId then
			current = { EventId = eventId, Contribution = 0, Claimed = {} }
			profile.LiveOps.Convergence = current
		end
		current.Claimed = type(current.Claimed) == "table" and current.Claimed or {}
		return current
	end

	local function readEventProfile(profile, eventId: string)
		local liveOps = type(profile.LiveOps) == "table" and profile.LiveOps or nil
		local current = liveOps and liveOps.Convergence or nil
		if type(current) ~= "table" or current.EventId ~= eventId then
			return { EventId = eventId, Contribution = 0, Claimed = {} }
		end
		return {
			EventId = eventId,
			Contribution = math.max(0, tonumber(current.Contribution) or 0),
			Claimed = type(current.Claimed) == "table" and current.Claimed or {},
		}
	end

	local function applyReward(profile, reward)
		local cash = math.max(0, tonumber(reward.Cash) or 0)
		local OmegaMath = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
		profile.Cash = OmegaMath.Add(profile.Cash, cash)
		profile.RunCash = OmegaMath.Add(profile.RunCash, cash)
		profile.LifetimeCash = OmegaMath.Add(profile.LifetimeCash, cash)
		profile.Stats.Collected = OmegaMath.Add(profile.Stats.Collected, cash)
		profile.Stardust += math.max(0, tonumber(reward.Stardust) or 0)
		profile.Cores += math.max(0, tonumber(reward.Cores) or 0)
		if reward.Signals then profile.Command.Signals += math.max(0, tonumber(reward.Signals) or 0) end
		if reward.Boost and profile.BoostInventory[reward.Boost] ~= nil then
			profile.BoostInventory[reward.Boost] += 1
		end
	end

	function ConvergenceService.new(dataService)
		return setmetatable({
			_data = dataService,
			_map = MemoryStoreService:GetHashMap(MAP_NAME),
			_pending = {},
			_pendingGlobal = 0,
			_global = 0,
			_eventId = "",
			_running = false,
			_subscription = nil,
			_worker = nil,
		}, ConvergenceService)
	end

	function ConvergenceService:_manifest()
		local manifest = LiveOps.CurrentConvergence(os.time())
		if self._eventId ~= manifest.EventId then
			self._eventId = manifest.EventId
			self._global = 0
			self._pending = {}
			self._pendingGlobal = 0
		end
		return manifest
	end

	function ConvergenceService:RecordAction(player: Player, action: string)
		self:_manifest()
		local amount = LiveOps.Convergence.ContributionByAction[action]
		if type(amount) ~= "number" or amount <= 0 then return end
		self._pending[player] = (self._pending[player] or 0) + amount
		self._pendingGlobal += amount
	end

	function ConvergenceService:FlushPlayer(player: Player)

		local manifest = self:_manifest()
		local amount = self._pending[player] or 0
		if amount <= 0 then return true end
		self._pending[player] = 0
		local ok = self._data:AtomicUpdate(player, function(profile)
			local state = eventProfile(profile, manifest.EventId)
			state.Contribution += amount
		end, true, "convergence")
		if not ok then self._pending[player] = (self._pending[player] or 0) + amount end
		return ok
	end

	function ConvergenceService:_flushGlobal()

		local manifest = self:_manifest()
		local amount = self._pendingGlobal
		if amount <= 0 then return end
		self._pendingGlobal = 0
		local expiry = math.max(60, manifest.EndsAt - os.time() + 86_400)
		local ok, total = pcall(function()
			return self._map:UpdateAsync(manifest.EventId, function(previous)
				return math.max(0, tonumber(previous) or 0) + amount
			end, expiry)
		end)
		if ok and type(total) == "number" then
			self._global = total
			pcall(function() MessagingService:PublishAsync(TOPIC, { EventId = manifest.EventId, Total = total }) end)
		else
			self._pendingGlobal += amount
			ModuleLog.Every("convergence-flush", 30, "LiveOps", tostring(total))
		end
	end

	function ConvergenceService:_refresh()
		local manifest = self:_manifest()
		local ok, total = pcall(function() return self._map:GetAsync(manifest.EventId) end)
		if ok then self._global = math.max(self._global, tonumber(total) or 0) end
	end

	function ConvergenceService:Multiplier(): number
		local multiplier = 1
		local total = self._global + self._pendingGlobal
		for _, phase in LiveOps.Convergence.GlobalPhases do
			if total >= phase.Target then multiplier = phase.ProductionMultiplier else break end
		end
		return multiplier
	end

	function ConvergenceService:State(player: Player, profile)
		local manifest = self:_manifest()

		local saved = readEventProfile(profile, manifest.EventId)
		local personal = saved.Contribution + (self._pending[player] or 0)
		local total = self._global + self._pendingGlobal
		local phaseIndex, phaseName, nextTarget = 0, "HEATING", LiveOps.Convergence.GlobalPhases[1].Target
		for index, phase in LiveOps.Convergence.GlobalPhases do
			if total >= phase.Target then
				phaseIndex, phaseName = index, phase.Name
				nextTarget = LiveOps.Convergence.GlobalPhases[index + 1] and LiveOps.Convergence.GlobalPhases[index + 1].Target or phase.Target
			else nextTarget = phase.Target; break end
		end
		local tiers = {}
		for index, tier in LiveOps.Convergence.PersonalTiers do
			tiers[index] = {
				Tier = index, Required = tier.Required, Reward = tier.Reward,
				Claimed = saved.Claimed[tostring(index)] == true,
				CanClaim = personal >= tier.Required and saved.Claimed[tostring(index)] ~= true,
			}
		end
		return {
			EventId = manifest.EventId, Name = manifest.Name, StartsAt = manifest.StartsAt, EndsAt = manifest.EndsAt,
			GlobalContribution = total, GlobalTarget = nextTarget,
			Phase = phaseIndex, PhaseName = phaseName, ProductionMultiplier = self:Multiplier(),
			PersonalContribution = personal, Tiers = tiers,
		}
	end

	function ConvergenceService:Claim(player: Player, rawTier: any)

		if not self:FlushPlayer(player) then
			return { ok = false, error = "The convergence is busy. Try again." }
		end
		local tierIndex = math.floor(tonumber(rawTier) or 0)
		local tier = LiveOps.Convergence.PersonalTiers[tierIndex]
		if not tier then return { ok = false, error = "That convergence reward does not exist." } end
		local manifest = self:_manifest()
		local ok, result = self._data:AtomicUpdate(player, function(profile)
			local state = eventProfile(profile, manifest.EventId)
			local key = tostring(tierIndex)
			if state.Claimed[key] then return { ok = false, error = "That reward was already claimed." } end
			if state.Contribution < tier.Required then return { ok = false, error = "Keep forging to unlock this reward." } end
			state.Claimed[key] = true
			applyReward(profile, tier.Reward)
			return { ok = true, message = "Convergence reward claimed.", Reward = tier.Reward }
		end, true, "convergence-claim")
		if not ok then return { ok = false, error = "The convergence is busy. Try again." } end
		return result
	end

	function ConvergenceService:Start()
		if self._running then return end
		self._running = true
		local ok, subscription = pcall(function()
			return MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" and data.EventId == self:_manifest().EventId then
					self._global = math.max(self._global, tonumber(data.Total) or 0)
				end
			end)
		end)
		if ok then self._subscription = subscription end
		self._worker = task.spawn(function()
			while self._running do
				task.wait(15)

				if not self._running then break end
				for _, player in Players:GetPlayers() do self:FlushPlayer(player) end
				self:_flushGlobal()
				self:_refresh()
			end
			self._worker = nil
		end)
	end

	function ConvergenceService:PlayerRemoving(player: Player)

		local deadline = os.clock() + 6
		local flushed = self:FlushPlayer(player)
		while not flushed and self._data:Get(player) ~= nil and os.clock() < deadline do
			task.wait(0.1)
			flushed = self:FlushPlayer(player)
		end
		if not flushed and (self._pending[player] or 0) > 0 then
			ModuleLog.Warn("LiveOps", string.format("could not flush %s contribution before leave", player.Name))
		end
		self._pending[player] = nil
	end

	function ConvergenceService:Stop()
		self._running = false
		if self._worker then
			task.cancel(self._worker)
			self._worker = nil
		end

		local deadline = os.clock() + SHUTDOWN_FLUSH_SECONDS
		for _, player in Players:GetPlayers() do
			if os.clock() >= deadline then
				ModuleLog.Warn("LiveOps", "ran out of time flushing contributions")
				break
			end
			self:FlushPlayer(player)
		end
		if self._pendingGlobal > 0 and os.clock() < deadline then
			local finished = false
			local worker = task.spawn(function()
				self:_flushGlobal()
				finished = true
			end)
			while not finished and os.clock() < deadline do task.wait() end
			if not finished then
				pcall(task.cancel, worker)
				ModuleLog.Warn("LiveOps", "skipped the convergence write — shutdown is already late")
			end
		end
		if self._subscription then self._subscription:Disconnect(); self._subscription = nil end
	end

	return ConvergenceService
end
