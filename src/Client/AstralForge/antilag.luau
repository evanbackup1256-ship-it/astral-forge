local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local _log = require(script.Parent.log)
local ClientLog = _log.ClientLog
local recordPerformanceTelemetry = _log.recordPerformanceTelemetry
local _motion = require(script.Parent.motion)
local setClockBudget = _motion.setClockBudget
local setContinuousMotionRate = _motion.setContinuousMotionRate
local setHitchMotionFrozen = _motion.setHitchMotionFrozen
local DEFAULT_TELEMETRY = {
	fps = if UserInputService.TouchEnabled then 48 else 60,
	lowFps = if UserInputService.TouchEnabled then 42 else 55,
	frameTimeMs = if UserInputService.TouchEnabled then 1000 / 48 else 1000 / 60,
	p50FrameTimeMs = if UserInputService.TouchEnabled then 1000 / 48 else 1000 / 60,
	p95FrameTimeMs = if UserInputService.TouchEnabled then 1000 / 48 else 1000 / 60,
	p99FrameTimeMs = if UserInputService.TouchEnabled then 1000 / 48 else 1000 / 60,
	jankRatio = 0,
	hitchScore = 0,
	sampledAt = 0,
}
local telemetryListeners = {}
local pingHistory = {}
local telemetryConnection
local latestTelemetry = DEFAULT_TELEMETRY
local cachedPingItem
local latencyRemote
local latencyAction = "MeasureLatency"
local latencyWorker
local latencyProbeWorkers = {}
local latencyTimeoutWorkers = {}
local latencyGeneration = 0
local lastRoundTripProbeAt = -math.huge
local FRAME_RING = 72
local SAMPLE_SECONDS = 0.32
local frames = table.create(FRAME_RING)
local scratch = table.create(FRAME_RING)
for index = 0, FRAME_RING - 1 do
	frames[index + 1] = 1 / 60
	scratch[index + 1] = 1 / 60
end
local frameWrite = 0
local frameFilled = 0
local liveScene = "normal"
local livePreference = if UserInputService.TouchEnabled then 0.58 else 0.42
local sceneListeners = {}
local function validPing(value)
	local _value = value
	local _condition = type(_value) == "number"
	if _condition then
		_condition = value == value and value >= 0 and value <= 10000
	end
	return _condition
end
local function parsePingText(value)
	local match = string.match(value, "([%d%.]+)")
	if match == nil then
		return nil
	end
	local parsed = tonumber(match)
	return if validPing(parsed) then parsed else nil
end
local function readStatsPing(item)
	local valueOk, value = pcall(function()
		return item.GetValue()
	end)
	if valueOk and validPing(value) then
		return value
	end
	if item.GetValueString ~= nil then
		local textOk, text = pcall(function()
			return item.GetValueString()
		end)
		if textOk and type(text) == "string" then
			return parsePingText(text)
		end
	end
	return nil
end
local function enginePingMs()
	local _result = cachedPingItem
	if _result ~= nil then
		_result = _result.Parent
	end
	if _result ~= nil then
		local value = readStatsPing(cachedPingItem)
		if value ~= nil then
			return value
		end
		cachedPingItem = nil
	end
	local network = Stats:FindFirstChild("Network")
	local _server = network
	if _server ~= nil then
		_server = _server:FindFirstChild("ServerStatsItem")
	end
	local server = _server
	local _result_1 = server
	if _result_1 ~= nil then
		_result_1 = _result_1:FindFirstChild("Data Ping")
	end
	local _condition = _result_1
	if _condition == nil then
		_condition = Stats:FindFirstChild("Data Ping", true)
	end
	local item = _condition
	if item == nil then
		return nil
	end
	local statsItem = item
	local value = readStatsPing(statsItem)
	if value == nil then
		return nil
	end
	cachedPingItem = statsItem
	return value
end
local function publishPingSample(value, roundTrip)
	if roundTrip == nil then
		roundTrip = false
	end
	if not validPing(value) then
		return nil
	end
	if roundTrip then
		if os.clock() - lastRoundTripProbeAt > 6 then
			table.clear(pingHistory)
		end
		lastRoundTripProbeAt = os.clock()
	elseif os.clock() - lastRoundTripProbeAt <= 6 then
		return nil
	end
	local _value = value
	table.insert(pingHistory, _value)
	while #pingHistory > 7 do
		table.remove(pingHistory, 1)
	end
end
local function stopLatencyWorker()
	latencyGeneration += 1
	if latencyWorker ~= nil then
		task.cancel(latencyWorker)
		latencyWorker = nil
	end
	for worker in latencyProbeWorkers do
		task.cancel(worker)
	end
	for worker in latencyTimeoutWorkers do
		task.cancel(worker)
	end
	table.clear(latencyProbeWorkers)
	table.clear(latencyTimeoutWorkers)
end
local function startLatencyWorker()
	local _condition = latencyWorker ~= nil or latencyRemote == nil
	if not _condition then
		-- ▼ ReadonlySet.size ▼
		local _size = 0
		for _ in telemetryListeners do
			_size += 1
		end
		-- ▲ ReadonlySet.size ▲
		_condition = _size == 0
	end
	if _condition then
		return nil
	end
	local generation = latencyGeneration + 1
	latencyGeneration = generation
	latencyWorker = task.spawn(function()
		task.wait(1.25)
		local probeSerial = 0
		local probeInFlight = false
		local outstandingProbes = 0
		while true do
			local _condition_1 = generation == latencyGeneration
			if _condition_1 then
				-- ▼ ReadonlySet.size ▼
				local _size = 0
				for _ in telemetryListeners do
					_size += 1
				end
				-- ▲ ReadonlySet.size ▲
				_condition_1 = _size > 0
				if _condition_1 then
					_condition_1 = latencyRemote ~= nil
				end
			end
			if not _condition_1 then
				break
			end
			local statsPing = enginePingMs()
			local needsFallback = statsPing == nil or statsPing <= 0.5
			if not probeInFlight and needsFallback and outstandingProbes < 2 then
				local remote = latencyRemote
				local serial = probeSerial + 1
				probeSerial = serial
				probeInFlight = true
				outstandingProbes += 1
				local startedAt = os.clock()
				local probeWorker
				local timeoutWorker
				probeWorker = task.defer(function()
					local ok, response = pcall(function()
						return remote:InvokeServer(latencyAction)
					end)
					local _probeWorker = probeWorker
					latencyProbeWorkers[_probeWorker] = nil
					local _timeoutWorker = timeoutWorker
					if latencyTimeoutWorkers[_timeoutWorker] ~= nil then
						local _timeoutWorker_1 = timeoutWorker
						latencyTimeoutWorkers[_timeoutWorker_1] = nil
						task.cancel(timeoutWorker)
					end
					if generation ~= latencyGeneration then
						return nil
					end
					outstandingProbes = math.max(0, outstandingProbes - 1)
					if serial ~= probeSerial then
						return nil
					end
					probeInFlight = false
					local elapsedMs = (os.clock() - startedAt) * 1000
					if ok and type(response) == "table" and response.ok == true then
						publishPingSample(elapsedMs, true)
					end
				end)
				local _probeWorker = probeWorker
				latencyProbeWorkers[_probeWorker] = true
				timeoutWorker = task.delay(4, function()
					local _timeoutWorker = timeoutWorker
					latencyTimeoutWorkers[_timeoutWorker] = nil
					if generation ~= latencyGeneration or serial ~= probeSerial or not probeInFlight then
						return nil
					end
					probeSerial += 1
					probeInFlight = false
				end)
				local _timeoutWorker = timeoutWorker
				latencyTimeoutWorkers[_timeoutWorker] = true
			end
			task.wait(if needsFallback then 2.5 else 5)
		end
		if generation == latencyGeneration then
			latencyWorker = nil
		end
	end)
end
local function watchPing(remote, action)
	if action == nil then
		action = "MeasureLatency"
	end
	if latencyRemote == remote and latencyAction == action then
		return nil
	end
	stopLatencyWorker()
	latencyRemote = remote
	latencyAction = action
	startLatencyWorker()
end
local function median(values)
	if #values == 0 then
		return nil
	end
	local _array = {}
	local _length = #_array
	table.move(values, 1, #values, _length + 1, _array)
	table.sort(_array, function(a, b)
		return a < b
	end)
	local sorted = _array
	return sorted[math.floor((#sorted - 1) / 2) + 1]
end
local function medianAbsoluteDeviation(values, center)
	if #values == 0 or center == nil then
		return nil
	end
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#values)
	local _callback = function(value)
		return math.abs(value - center)
	end
	for _k, _v in values do
		_newValue[_k] = _callback(_v, _k - 1, values)
	end
	-- ▲ ReadonlyArray.map ▲
	local deviations = _newValue
	return median(deviations)
end
-- Sorts only the first `count` slots in place — the tail of the ring holds the 1/60
-- placeholder values and must stay out of the percentile reads. With ~20 samples per window
-- this is a couple hundred comparisons at 3Hz, not worth a fancier partial sort.
local function sortScratch(count)
	do
		local index = 1
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < count) then
				break
			end
			local value = scratch[index + 1]
			local slot = index
			while slot > 0 and scratch[slot] > value do
				scratch[slot + 1] = scratch[slot]
				slot -= 1
			end
			scratch[slot + 1] = value
		end
	end
end
local function percentile(count, p)
	if count <= 0 then
		return 1 / 60
	end
	local index = math.clamp(math.floor((count - 1) * p + 0.5), 0, count - 1)
	return scratch[index + 1]
end
local lastGuardSweepAt = 0
local bootSeedListeners
local function sweepRuntimeGuards()
	local now = os.clock()
	if now - lastGuardSweepAt < 4 then
		return nil
	end
	lastGuardSweepAt = now
	while #pingHistory > 7 do
		table.remove(pingHistory, 1)
	end
	-- Trim overflow workers directly off the sets instead of copying them into throw-away
	-- arrays every sweep — this guard runs forever and the copies were pure garbage.
	local trimWorkers = function(workers)
		-- ▼ ReadonlySet.size ▼
		local _size = 0
		for _ in workers do
			_size += 1
		end
		-- ▲ ReadonlySet.size ▲
		if _size <= 6 then
			return nil
		end
		local index = 0
		for worker in workers do
			if index >= 6 then
				workers[worker] = nil
				pcall(function()
					return task.cancel(worker)
				end)
			end
			index += 1
		end
	end
	trimWorkers(latencyProbeWorkers)
	trimWorkers(latencyTimeoutWorkers)
	if cachedPingItem ~= nil and cachedPingItem.Parent == nil then
		cachedPingItem = nil
	end
	if #bootSeedListeners > 8 then
		while #bootSeedListeners > 4 do
			table.remove(bootSeedListeners, 1)
		end
	end
	if #sceneListeners > 8 then
		while #sceneListeners > 4 do
			table.remove(sceneListeners, 1)
		end
	end
end
local function startTelemetry()
	if telemetryConnection ~= nil then
		return nil
	end
	local elapsed = 0
	telemetryConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local clamped = math.clamp(deltaTime, 0.001, 0.12)
		frames[frameWrite + 1] = clamped
		frameWrite = (frameWrite + 1) % FRAME_RING
		if frameFilled < FRAME_RING then
			frameFilled += 1
		end
		elapsed += clamped
		if elapsed < SAMPLE_SECONDS then
			return nil
		end
		elapsed = 0
		local count = frameFilled
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < count) then
					break
				end
				local ring = (frameWrite - count + index + FRAME_RING) % FRAME_RING
				scratch[index + 1] = frames[ring + 1]
			end
		end
		sortScratch(count)
		local total = 0
		local jankFrames = 0
		local hitchFrames = 0
		do
			local index = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index += 1
				else
					_shouldIncrement = true
				end
				if not (index < count) then
					break
				end
				local time = scratch[index + 1]
				total += time
				if time > 1 / 36 then
					jankFrames += 1
				end
				if time > 0.032 then
					hitchFrames += 1
				end
			end
		end
		local mean = total / math.max(count, 1)
		local rawFps = 1 / math.max(mean, 0.001)
		local p50 = percentile(count, 0.5)
		local p95 = percentile(count, 0.95)
		local p99 = percentile(count, 0.99)
		local livePing = enginePingMs()
		if livePing ~= nil then
			publishPingSample(livePing)
		end
		local stablePing = median(pingHistory)
		latestTelemetry = {
			fps = rawFps,
			lowFps = math.min(rawFps, 1 / math.max(p95, 1 / 240)),
			frameTimeMs = mean * 1000,
			p50FrameTimeMs = p50 * 1000,
			p95FrameTimeMs = p95 * 1000,
			p99FrameTimeMs = p99 * 1000,
			jankRatio = jankFrames / math.max(count, 1),
			hitchScore = hitchFrames / math.max(count, 1),
			pingMs = stablePing,
			pingJitterMs = medianAbsoluteDeviation(pingHistory, stablePing),
			sampledAt = os.clock(),
		}
		recordPerformanceTelemetry(latestTelemetry)
		sweepRuntimeGuards()
		for listener in telemetryListeners do
			listener(latestTelemetry)
		end
	end)
end
local function stopTelemetryIfIdle()
	-- ▼ ReadonlySet.size ▼
	local _size = 0
	for _ in telemetryListeners do
		_size += 1
	end
	-- ▲ ReadonlySet.size ▲
	local _condition = _size > 0
	if not _condition then
		_condition = telemetryConnection == nil
	end
	if _condition then
		return nil
	end
	telemetryConnection:Disconnect()
	telemetryConnection = nil
end
local function subscribeTelemetry(listener)
	local _listener = listener
	telemetryListeners[_listener] = true
	listener(latestTelemetry)
	startTelemetry()
	startLatencyWorker()
	return function()
		local _listener_1 = listener
		telemetryListeners[_listener_1] = nil
		stopTelemetryIfIdle()
		-- ▼ ReadonlySet.size ▼
		local _size = 0
		for _ in telemetryListeners do
			_size += 1
		end
		-- ▲ ReadonlySet.size ▲
		if _size == 0 then
			stopLatencyWorker()
		end
	end
end
local function usePerformanceTelemetry()
	local sample, setSample = React.useState(latestTelemetry)
	React.useEffect(function()
		return subscribeTelemetry(setSample)
	end, {})
	return sample
end
local function infoFromQuality(quality, fps, pressure, hitchScore)
	local q = math.clamp(quality, 0, 1)
	local tier = if q < 0.2 then 0 elseif q < 0.44 then 1 elseif q < 0.7 then 2 else 3
	local fxBudget = math.clamp(0.05 + q * 0.42 + q * q * 0.28, 0.05, 0.86)
	local renderRate = math.clamp(math.floor(16 + q * 34 + 0.5), 16, 56)
	return {
		fps = fps,
		tier = tier,
		quality = q,
		pressure = math.clamp(pressure, 0, 1),
		hitchScore = math.clamp(hitchScore, 0, 1),
		frameBudgetMs = 1000 / renderRate,
		fxBudget = fxBudget,
		particleBudget = math.clamp(math.floor(1 + 12 * q + 0.5), 1, 14),
		titleGlyphLimit = 18,
		renderRate = renderRate,
		glowScale = math.clamp(0.1 + q * 0.72, 0.1, 0.86),
		allowAmbient = q >= 0.58,
		allowConfetti = q >= 0.34,
		skipEntrance = false,
		freezeIcons = false,
		maxClocks = math.clamp(math.floor(4 + 12 * q + 0.5), 4, 16),
		maxPops = math.clamp(math.floor(1 + 3 * q + 0.5), 1, 4),
		maxStars = if q < 0.42 then 0 else math.clamp(math.floor(q * 5 + 0.5), 1, 5),
	}
end
local function tierCeiling(tier)
	if tier == 0 then
		return 0.18
	end
	if tier == 1 then
		return 0.4
	end
	if tier == 2 then
		return 0.66
	end
	return 1
end
local DEFAULT_INFO = infoFromQuality(if UserInputService.TouchEnabled then 0.62 else 0.88, if UserInputService.TouchEnabled then 50 else 60, 0.2, 0)
local AntilagContext = React.createContext(DEFAULT_INFO)
local bootSeededQuality
local bootSeededFps
bootSeedListeners = {}
local function sceneLoad(scene)
	if scene == "cinematic" then
		return 0.38
	end
	if scene == "arcade" then
		return 0.28
	end
	if scene == "heavy" then
		return 0.16
	end
	return 0
end
local function applyMotionRate(info)
	local rate = if info.tier >= 2 then math.max(info.renderRate, 40) else math.max(24, info.renderRate)
	setContinuousMotionRate(rate)
	setClockBudget(info.maxClocks)
end
local function setAntilagScene(scene)
	if liveScene == scene then
		return nil
	end
	liveScene = scene
	for _, listener in sceneListeners do
		listener()
	end
end
local function setAntilagPreference(bias)
	local preferred = math.clamp(bias, 0, 1)
	if math.abs(preferred - livePreference) < 0.01 then
		return nil
	end
	livePreference = preferred
	for _, listener in sceneListeners do
		listener()
	end
end
local function seedAntilagFromBoot(fps)
	local measured = math.clamp(fps, 8, 120)
	bootSeededFps = measured
	local raw = math.clamp((measured - 16) / 44, 0.12, 1)
	bootSeededQuality = if UserInputService.TouchEnabled then math.min(raw, 0.82) else raw
	for _, listener in bootSeedListeners do
		listener(bootSeededQuality, measured)
	end
	return if bootSeededQuality < 0.2 then 0 elseif bootSeededQuality < 0.44 then 1 elseif bootSeededQuality < 0.7 then 2 else 3
end
local function clampAntilagTier(info, maxTier)
	if info.tier <= maxTier then
		return info
	end
	return infoFromQuality(math.min(info.quality, tierCeiling(maxTier)), info.fps, info.pressure, info.hitchScore)
end
-- Two tiers of "did the budgets actually change" gates. Discrete fields (tier, budgets that
-- mount/unmount or re-configure visual systems) must push through React context immediately.
-- Continuous fields (fxBudget/glowScale) only feed amplitude/scale bindings, and during a slow
-- quality drift they changed every sample — re-rendering the entire game tree ~3 times a
-- second for a cosmetic fade. They now update at most ~1Hz and only past a coarse threshold.
local function discreteBudgetsChanged(left, right)
	return left.tier ~= right.tier or left.freezeIcons ~= right.freezeIcons or left.allowAmbient ~= right.allowAmbient or left.skipEntrance ~= right.skipEntrance or left.allowConfetti ~= right.allowConfetti or left.maxStars ~= right.maxStars or left.maxPops ~= right.maxPops or math.abs(left.maxClocks - right.maxClocks) >= 3 or left.particleBudget ~= right.particleBudget or left.titleGlyphLimit ~= right.titleGlyphLimit
end
local function continuousBudgetsChanged(left, right)
	return math.abs(left.fxBudget - right.fxBudget) >= 0.2 or math.abs(left.glowScale - right.glowScale) >= 0.25
end
local function scoreWindow(sample)
	local targetFps = if UserInputService.TouchEnabled then 48 else 58
	local fpsScore = math.clamp(sample.fps / targetFps, 0, 1.15)
	local p95Score = math.clamp(1 - (sample.p95FrameTimeMs - 16) / 48, 0, 1)
	local p99Score = math.clamp(1 - (sample.p99FrameTimeMs - 20) / 70, 0, 1)
	local jankScore = 1 - math.clamp(sample.jankRatio * 1.7, 0, 1)
	local hitchPenalty = math.clamp(sample.hitchScore * 2.1, 0, 1)
	local pingPenalty = if sample.pingMs ~= nil and sample.pingMs > 180 then math.clamp((sample.pingMs - 180) / 500, 0, 0.16) else 0
	local blended = fpsScore * 0.3 + p95Score * 0.28 + p99Score * 0.18 + jankScore * 0.24
	return math.clamp(blended - hitchPenalty * 0.62 - pingPenalty, 0, 1)
end
local latestAntilagInfo
local function AntilagProvider(_param)
	local children = _param.children
	local _condition = bootSeededQuality
	if _condition == nil then
		_condition = (if UserInputService.TouchEnabled then 0.62 else 0.88)
	end
	local startingQuality = _condition
	local _condition_1 = bootSeededFps
	if _condition_1 == nil then
		_condition_1 = (if UserInputService.TouchEnabled then 50 else 60)
	end
	local startingFps = _condition_1
	local info, setInfo = React.useState(function()
		return infoFromQuality(startingQuality, startingFps, 0.2, 0)
	end)
	local infoRef = React.useRef(info)
	infoRef.current = info
	latestAntilagInfo = info
	React.useEffect(function()
		local apply = function(quality, fps)
			local seeded = infoFromQuality(quality, fps, 1 - quality, 0)
			infoRef.current = seeded
			setInfo(seeded)
			applyMotionRate(seeded)
		end
		if bootSeededQuality ~= nil then
			local _exp = bootSeededQuality
			local _condition_2 = bootSeededFps
			if _condition_2 == nil then
				_condition_2 = 60
			end
			apply(_exp, _condition_2)
		end
		table.insert(bootSeedListeners, apply)
		return function()
			local index = (table.find(bootSeedListeners, apply) or 0) - 1
			if index >= 0 then
				table.remove(bootSeedListeners, index + 1)
			end
		end
	end, {})
	React.useEffect(function()
		applyMotionRate(info)
		return function()
			return setContinuousMotionRate(60)
		end
	end, { info.renderRate, info.tier })
	React.useEffect(function()
		local quality = startingQuality
		local lastLoggedTier = infoRef.current.tier
		local lastContinuousPushAt = 0
		local lastRiseAt = 0
		local lastDropAt = 0
		local slope = 0
		local previousScore = quality
		local holdUntil = 0
		local hitchStrikes = 0
		local hitchHoldUntil = 0
		local evaluate = function(sample)
			local raw = scoreWindow(sample)
			slope = slope * 0.55 + (raw - previousScore) * 0.45
			previousScore = raw
			local scene = sceneLoad(liveScene)
			local prefer = livePreference * 0.48
			local touchCeil = if UserInputService.TouchEnabled then 0.9 else 1
			local target = math.clamp(raw - scene - prefer, 0.08, touchCeil)
			local now = os.clock()
			local spiked = sample.hitchScore >= 0.16 or sample.p99FrameTimeMs >= 56
			local collapsed = sample.fps < 22 or sample.p95FrameTimeMs >= 48
			if spiked or collapsed then
				hitchStrikes += 1
				hitchHoldUntil = now + (if collapsed then 0.7 else 0.32)
				setHitchMotionFrozen(true)
				if collapsed and hitchStrikes >= 2 then
					target = math.min(target, 0.18)
					holdUntil = now + 1.1
				elseif hitchStrikes >= 3 then
					target = math.min(target, math.max(0.28, quality - 0.14))
					holdUntil = now + 0.7
				end
			else
				hitchStrikes = math.max(0, hitchStrikes - 1)
				if now >= hitchHoldUntil and sample.hitchScore < 0.07 then
					setHitchMotionFrozen(false)
				end
			end
			if slope < -0.04 then
				target = math.max(0.1, target - 0.08)
			end
			local falling = target < quality - 0.02
			local rising = target > quality + 0.05
			if falling then
				local alpha = if collapsed then 0.55 else 0.28
				quality += (target - quality) * alpha
				lastDropAt = now
			elseif rising and now >= holdUntil and now - lastDropAt >= 1.6 and now - lastRiseAt >= 0.7 then
				quality += (target - quality) * 0.06
				lastRiseAt = now
			else
				quality += (target - quality) * 0.02
			end
			quality = math.clamp(quality, 0.08, touchCeil)
			local pressure = math.clamp(1 - raw + scene + prefer, 0, 1)
			local scored = infoFromQuality(quality, sample.fps, pressure, sample.hitchScore)
			applyMotionRate(scored)
			-- Keep the module mirror (and all non-React consumers) always fresh, but only
			-- push through React context on real budget edges — see discrete/continuous
			-- split above. This is the difference between a couple of re-renders per minute
			-- and ~180 full-tree re-renders per minute during quality drift.
			latestAntilagInfo = scored
			local discrete = discreteBudgetsChanged(infoRef.current, scored)
			local continuous = continuousBudgetsChanged(infoRef.current, scored)
			local pushAt = os.clock()
			if discrete or (continuous and pushAt - lastContinuousPushAt >= 1.1) then
				lastContinuousPushAt = pushAt
				infoRef.current = scored
				setInfo(scored)
				if scored.tier ~= lastLoggedTier then
					lastLoggedTier = scored.tier
					ClientLog:debug("perf", `{math.floor(sample.fps)} fps, quality {string.format("%.2f", quality)}`)
				end
			end
		end
		local onScene = function()
			return evaluate(latestTelemetry)
		end
		table.insert(sceneListeners, onScene)
		local stop = subscribeTelemetry(evaluate)
		return function()
			stop()
			local index = (table.find(sceneListeners, onScene) or 0) - 1
			if index >= 0 then
				table.remove(sceneListeners, index + 1)
			end
		end
	end, {})
	return React.createElement(AntilagContext.Provider, {
		value = info,
	}, children)
end
latestAntilagInfo = DEFAULT_INFO
-- A module-level mirror of AntilagProvider's current info, for the handful of call sites
-- outside the React tree that want a read-only snapshot (Studio/debug attributes via
-- UiRootComponent) without having to be a descendant of AntilagContext.Provider — the
-- provider is a true singleton in this app, so "the latest value it computed" is
-- unambiguous. Never write to this from outside AntilagProvider.
local function currentAntilagInfo()
	return latestAntilagInfo
end
local function useAntilag()
	return React.useContext(AntilagContext)
end
return {
	watchPing = watchPing,
	usePerformanceTelemetry = usePerformanceTelemetry,
	setAntilagScene = setAntilagScene,
	setAntilagPreference = setAntilagPreference,
	seedAntilagFromBoot = seedAntilagFromBoot,
	clampAntilagTier = clampAntilagTier,
	AntilagProvider = AntilagProvider,
	currentAntilagInfo = currentAntilagInfo,
	useAntilag = useAntilag,
	AntilagContext = AntilagContext,
}
