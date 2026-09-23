--!strict

return function()
	type Timing = {
		Count: number,
		Failures: number,
		TotalMs: number,
		MaximumMs: number,
		LastMs: number,
	}

	local Telemetry = {}
	local startedAt = os.clock()
	local remoteAccepted = 0
	local remoteRejected = 0
	local integrityReports = 0
	local logs = { Info = 0, Warning = 0, Debug = 0 }
	local rejectionReasons: { [string]: number } = {}
	local timings: { [string]: Timing } = {}
	local activeSessions: { [number]: number } = {}
	local sessionsStarted = 0
	local sessionsEnded = 0
	local totalSessionSeconds = 0
	local clientQuality = { Samples = 0, TotalFPS = 0, TotalP95Ms = 0, TotalPingMs = 0, TotalBootMs = 0, TotalJank = 0, WorstP95Ms = 0 }

	local function timingFor(name: string): Timing
		local timing = timings[name]
		if not timing then
			timing = { Count = 0, Failures = 0, TotalMs = 0, MaximumMs = 0, LastMs = 0 }
			timings[name] = timing
		end
		return timing
	end

	function Telemetry.RecordLog(level: string): ()
		if level == "Info" then logs.Info += 1
		elseif level == "Warning" then logs.Warning += 1
		elseif level == "Debug" then logs.Debug += 1 end
	end

	function Telemetry.RecordRemote(accepted: boolean, reason: string?): ()
		if accepted then
			remoteAccepted += 1
			return
		end
		remoteRejected += 1
		local key = string.sub(reason or "unspecified", 1, 64)
		rejectionReasons[key] = (rejectionReasons[key] or 0) + 1
	end

	function Telemetry.RecordIntegrityReport(): ()
		integrityReports += 1
	end

	function Telemetry.RecordPlayerJoined(userId: number): ()
		if activeSessions[userId] then return end
		activeSessions[userId] = os.clock()
		sessionsStarted += 1
	end

	function Telemetry.RecordPlayerLeft(userId: number): ()
		local joinedAt = activeSessions[userId]
		if not joinedAt then return end
		activeSessions[userId] = nil
		sessionsEnded += 1
		totalSessionSeconds += math.max(0, os.clock() - joinedAt)
	end

	function Telemetry.Observe(name: string, seconds: number, succeeded: boolean): ()
		local milliseconds = math.max(0, seconds) * 1000
		local timing = timingFor(name)
		timing.Count += 1
		if not succeeded then timing.Failures += 1 end
		timing.TotalMs += milliseconds
		timing.MaximumMs = math.max(timing.MaximumMs, milliseconds)
		timing.LastMs = milliseconds
	end

	function Telemetry.RecordClientPerformance(sample): ()
		clientQuality.Samples += 1
		clientQuality.TotalFPS += math.clamp(tonumber(sample.FPS) or 0, 0, 360)
		clientQuality.TotalP95Ms += math.clamp(tonumber(sample.P95Ms) or 0, 0, 1000)
		clientQuality.TotalPingMs += math.clamp(tonumber(sample.PingMs) or 0, 0, 10_000)
		clientQuality.TotalBootMs += math.clamp(tonumber(sample.BootMs) or 0, 0, 120_000)
		clientQuality.TotalJank += math.clamp(tonumber(sample.JankPct) or 0, 0, 1)
		clientQuality.WorstP95Ms = math.max(clientQuality.WorstP95Ms, tonumber(sample.P95Ms) or 0)
	end

	function Telemetry.Snapshot()
		local reasonList = {}
		for reason, count in rejectionReasons do
			table.insert(reasonList, { Reason = reason, Count = count })
		end
		table.sort(reasonList, function(left, right)
			if left.Count == right.Count then return left.Reason < right.Reason end
			return left.Count > right.Count
		end)
		while #reasonList > 6 do table.remove(reasonList) end

		local timingList = {}
		for name, timing in timings do
			table.insert(timingList, {
				Name = name,
				Count = timing.Count,
				Failures = timing.Failures,
				AverageMs = timing.Count > 0 and timing.TotalMs / timing.Count or 0,
				MaximumMs = timing.MaximumMs,
				LastMs = timing.LastMs,
			})
		end
		table.sort(timingList, function(left, right) return left.Name < right.Name end)

		local total = remoteAccepted + remoteRejected
		local samples = clientQuality.Samples
		return {
			UptimeSeconds = math.max(0, os.clock() - startedAt),
			RemoteAccepted = remoteAccepted,
			RemoteRejected = remoteRejected,
			RemoteRejectRate = total > 0 and remoteRejected / total or 0,
			IntegrityReports = integrityReports,
			SessionsStarted = sessionsStarted,
			SessionsEnded = sessionsEnded,
			ActiveSessions = sessionsStarted - sessionsEnded,
			AverageSessionSeconds = sessionsEnded > 0 and totalSessionSeconds / sessionsEnded or 0,
			Logs = table.clone(logs),
			TopRejections = reasonList,
			Timings = timingList,
			ClientPerformance = {
				Samples = samples,
				AverageFPS = samples > 0 and clientQuality.TotalFPS / samples or 0,
				AverageP95Ms = samples > 0 and clientQuality.TotalP95Ms / samples or 0,
				AveragePingMs = samples > 0 and clientQuality.TotalPingMs / samples or 0,
				AverageBootMs = samples > 0 and clientQuality.TotalBootMs / samples or 0,
				AverageJankPct = samples > 0 and clientQuality.TotalJank / samples or 0,
				WorstP95Ms = clientQuality.WorstP95Ms,
			},
		}
	end

	function Telemetry.ResetForTests(): ()
		startedAt = os.clock()
		remoteAccepted = 0
		remoteRejected = 0
		integrityReports = 0
		sessionsStarted = 0
		sessionsEnded = 0
		totalSessionSeconds = 0
		logs = { Info = 0, Warning = 0, Debug = 0 }
		table.clear(rejectionReasons)
		table.clear(timings)
		table.clear(activeSessions)
		clientQuality = { Samples = 0, TotalFPS = 0, TotalP95Ms = 0, TotalPingMs = 0, TotalBootMs = 0, TotalJank = 0, WorstP95Ms = 0 }
	end

	return table.freeze(Telemetry)
end
