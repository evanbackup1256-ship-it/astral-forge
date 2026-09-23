--!strict

return function(loadService: (string) -> any)
	local AnalyticsService = game:GetService("AnalyticsService")
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local ServerTelemetry = loadService("ServerTelemetry")

	local PlayerAnalytics = {}
	PlayerAnalytics.__index = PlayerAnalytics

	local PROGRESSION_ACTIONS = {
		Rebirth = "Rebirth",
		DomainExpansion = "DomainExpansion",
		UnlockZone = "World",
	}

	local CUSTOM_ACTIONS = {
		CollectVault = true, BuyMachine = true, BuyResearch = true, OpenItemCrate = true,
		ClaimConvergenceReward = true,
	}

	local function emit(key: string, callback: () -> ())
		local ok, issue = pcall(callback)
		if not ok then ModuleLog.Every("analytics:" .. key, 60, "Analytics", tostring(issue)) end
	end

	function PlayerAnalytics.new()
		return setmetatable({ _lastPerformance = {}, _seenActions = {}, _joinedAt = {} }, PlayerAnalytics)
	end

	function PlayerAnalytics:PlayerJoined(player: Player, profile)
		self._joinedAt[player] = os.clock()
		emit("session", function()
			AnalyticsService:LogCustomEvent(player, "AF_SessionStart", profile.Stats.Joins, {
				world = tostring(profile.CurrentZone),
				first_session = profile.Stats.Joins <= 1 and "true" or "false",
			})
		end)
	end

	function PlayerAnalytics:PlayerLeft(player: Player, profile)
		local duration = math.max(0, math.floor(os.clock() - (self._joinedAt[player] or os.clock())))
		emit("session-end", function()
			AnalyticsService:LogCustomEvent(player, "AF_SessionEnd", duration, {
				world = tostring(profile.CurrentZone),
				rebirths = tostring(math.floor(profile.Rebirths)),
			})
		end)
	end

	function PlayerAnalytics:RecordAction(player: Player, action: string, profile, elapsedMs: number)
		local progression = PROGRESSION_ACTIONS[action]
		if progression then
				emit("progression:" .. action, function()
				local level = action == "DomainExpansion" and profile.Domain.Rank
					or action == "UnlockZone" and profile.CurrentZone
					or profile.Rebirths
				local safeLevel = math.max(1, math.floor(level or 1))
				AnalyticsService:LogProgressionEvent(
					player,
					progression,
					Enum.AnalyticsProgressionType.Complete,
					safeLevel,
					progression .. " " .. tostring(safeLevel)
				)
			end)
		end
		if action == "SetTutorialStep" or action == "CompleteTutorial" then
			emit("onboarding", function()
				-- Must match TUTORIAL_STEPS.size() in src_ts/client/MainGame.tsx. Previously
				-- clamped to 10 here, which reported every step from 11-15 (and "complete") as
				-- funnel step 10 -- collapsing the back half of the tutorial into a single
				-- indistinguishable bucket in analytics.
				local step = action == "CompleteTutorial" and 16 or math.clamp(profile.Flags.TutorialStep, 1, 15)
				AnalyticsService:LogOnboardingFunnelStepEvent(player, step, action == "CompleteTutorial" and "First Shift complete" or "First Shift")
			end)
		elseif CUSTOM_ACTIONS[action] then
			local seen = self._seenActions[player]
			if not seen then seen = {}; self._seenActions[player] = seen end
			if seen[action] then return end
			seen[action] = true
			emit("action:" .. action, function()
				AnalyticsService:LogCustomEvent(player, "AF_" .. action, 1, {
					world = tostring(profile.CurrentZone),
					latency_band = elapsedMs >= 500 and "slow" or elapsedMs >= 180 and "warm" or "fast",
				})
			end)
		end
	end

	function PlayerAnalytics:RecordPerformance(player: Player, payload): boolean
		local now = os.clock()
		if now - (self._lastPerformance[player] or 0) < 45 then return true end
		self._lastPerformance[player] = now
		ServerTelemetry.RecordClientPerformance(payload)
		emit("performance", function()
			AnalyticsService:LogCustomEvent(player, "AF_ClientPerformance", payload.FPS, {
				p95_ms = string.format("%.1f", payload.P95Ms),
				ping_ms = tostring(math.floor(payload.PingMs)),
				input = payload.Input,
			})
		end)
		return true
	end

	function PlayerAnalytics:Forget(player: Player)
		self._lastPerformance[player] = nil
		self._seenActions[player] = nil
		self._joinedAt[player] = nil
	end

	return PlayerAnalytics
end
