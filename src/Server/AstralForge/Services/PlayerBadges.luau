--!strict

return function()
	local BadgeService = game:GetService("BadgeService")
	local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))

	local PlayerBadges = {}
	PlayerBadges.__index = PlayerBadges

	function PlayerBadges.new()
		return setmetatable({ _attempted = {}, _alive = true, _workers = {} }, PlayerBadges)
	end

	function PlayerBadges:_award(player: Player, key: string)
		local badgeId = GameConfig.PlatformBadges[key]
		if type(badgeId) ~= "number" or badgeId <= 0 then return end
		local playerAttempts = self._attempted[player]
		if not playerAttempts then playerAttempts = {}; self._attempted[player] = playerAttempts end
		if playerAttempts[key] then return end
		playerAttempts[key] = true
		local token = {}
		local worker = task.defer(function()
			if not self._alive then
				self._workers[token] = nil
				return
			end
			local ok, awarded = pcall(function() return BadgeService:AwardBadgeAsync(player.UserId, badgeId) end)
			if self._alive and (not ok or awarded ~= true) then
				playerAttempts[key] = nil
				ModuleLog.Every("badge:" .. key, 60, "Badges", ok and "platform declined badge award" or tostring(awarded))
			end
			self._workers[token] = nil
		end)
		self._workers[token] = worker
	end

	function PlayerBadges:Evaluate(player: Player, profile, action: string?)
		local collected = profile.Stats and profile.Stats.Collected
		if type(collected) == "number" and collected > 0 then self:_award(player, "FirstCollect")
		elseif type(collected) == "string" and collected ~= "" and collected ~= "0" then self:_award(player, "FirstCollect") end
		if (tonumber(profile.Stats and profile.Stats.MachinesBought) or 0) > 0 then self:_award(player, "FirstMachine") end
		if (tonumber(profile.Rebirths) or 0) > 0 then self:_award(player, "FirstRebirth") end
		if (tonumber(profile.Zone) or 0) >= 5 then self:_award(player, "WorldFive") end
		if type(profile.Domain) == "table" and (tonumber(profile.Domain.Rank) or 0) > 0 then self:_award(player, "DomainExpansion") end
		if action == "ClaimConvergenceReward" then self:_award(player, "Convergence") end
	end

	function PlayerBadges:Forget(player: Player) self._attempted[player] = nil end

	function PlayerBadges:Destroy()
		if not self._alive then return end
		self._alive = false
		for _, worker in self._workers do
			pcall(task.cancel, worker)
		end
		table.clear(self._workers)
		table.clear(self._attempted)
	end

	return PlayerBadges
end
