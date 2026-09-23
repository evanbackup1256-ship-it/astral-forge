local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local recent = {}
local emitted = {}
local bootMilliseconds = 0
local bootOrigin = os.clock()
local function field(value)
	local sanitized = tostring(value):gsub("[\r\n|]", " ")
	return sanitized
end
local function formatLine(severity, scope, message, params)
	local paramsStr = ""
	if params ~= nil and type(params) == "table" then
		local pieces = {}
		local keys = {}
		for key in params do table.insert(keys, key) end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, key in keys do
			table.insert(pieces, `{field(key)}: {field(params[key])}`)
		end
		if #pieces > 0 then
			paramsStr = " | " .. table.concat(pieces, " | ")
		end
	end
	return `[{severity}] [{string.upper(field(scope))}] {field(message)}{paramsStr}`
end
local function available(key, seconds)
	local now = os.clock()
	local _key = key
	local previous = recent[_key]
	if previous ~= nil and now - previous < seconds then
		return false
	end
	local _key_1 = key
	recent[_key_1] = now
	return true
end
local function debugEnabled()
	return ReplicatedStorage:GetAttribute("AstralDebugLogs") == true
end
local ClientLog = {
	info = function(self, scope, message, params)
		print(formatLine("INFO", scope, message, params))
	end,
	warn = function(self, scope, message, params)
		warn(formatLine("WARN", scope, message, params))
	end,
	error = function(self, scope, message, params)
		warn(formatLine("ERROR", scope, message, params))
	end,
	fatal = function(self, scope, message, params)
		warn(formatLine("FATAL", scope, message, params))
	end,
	network = function(self, scope, message, params)
		print(formatLine("NETWORK", scope, message, params))
	end,
	debug = function(self, scope, message, params)
		if debugEnabled() then
			print(formatLine("INFO", scope, message, params))
		end
	end,
	once = function(self, key, scope, message, params)
		local _key = key
		if emitted[_key] ~= nil then
			return nil
		end
		local _key_1 = key
		emitted[_key_1] = true
		print(formatLine("INFO", scope, message, params))
	end,
	warnEvery = function(self, key, seconds, scope, message, params)
		if available(`warn:{key}`, seconds) then
			warn(formatLine("WARN", scope, message, params))
		end
	end,
	errorEvery = function(self, key, seconds, scope, message, params)
		if available(`err:{key}`, seconds) then
			warn(formatLine("ERROR", scope, message, params))
		end
	end,
}
local sharedQualitySample
local function beginClientSession()
	table.clear(recent)
	table.clear(emitted)
	bootMilliseconds = 0
	bootOrigin = os.clock()
	sharedQualitySample = nil
end
local function recordPerformanceTelemetry(sample)
	sharedQualitySample = sample
end
local function markBootComplete()
	if bootMilliseconds <= 0 then
		bootMilliseconds = math.floor((os.clock() - bootOrigin) * 1000 + 0.5)
	end
end
local function inputFamily()
	local preferred = UserInputService.PreferredInput
	if preferred == Enum.PreferredInput.Touch then
		return "touch"
	end
	if preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad then
		return "gamepad"
	end
	return "mouse"
end
local function startPerformanceTelemetry(request)
	local alive = true
	local reportInFlight = false
	local reportSerial = 0
	local requestWorker
	local requestTimeout
	local worker = task.spawn(function()
		task.wait(20)
		while alive do
			local sample = sharedQualitySample
			if sample ~= nil and sample.sampledAt > 0 then
				local _result = Workspace.CurrentCamera
				if _result ~= nil then
					_result = _result.ViewportSize
				end
				local _condition = _result
				if _condition == nil then
					_condition = Vector2.new(1, 1)
				end
				local viewport = _condition
				local _object = {
					FPS = math.clamp(sample.fps, 0, 360),
					P95Ms = math.clamp(sample.p95FrameTimeMs, 0, 1000),
					JankPct = math.clamp(sample.jankRatio, 0, 1),
				}
				local _left = "PingMs"
				local _condition_1 = sample.pingMs
				if _condition_1 == nil then
					_condition_1 = 0
				end
				_object[_left] = math.clamp(_condition_1, 0, 10000)
				_object.Width = math.max(1, math.floor(viewport.X))
				_object.Height = math.max(1, math.floor(viewport.Y))
				_object.BootMs = bootMilliseconds
				_object.Input = inputFamily()
				local payload = _object
				if not reportInFlight then
					reportInFlight = true
					local serial = reportSerial + 1
					reportSerial = serial
					requestWorker = task.defer(function()
						pcall(function()
							return request:InvokeServer("ReportPerformance", payload)
						end)
						if not alive or serial ~= reportSerial then
							return nil
						end
						requestWorker = nil
						if requestTimeout ~= nil then
							task.cancel(requestTimeout)
							requestTimeout = nil
						end
						reportInFlight = false
					end)
					requestTimeout = task.delay(6, function()
						requestTimeout = nil
						if not alive or serial ~= reportSerial or not reportInFlight then
							return nil
						end
						if requestWorker ~= nil then
							task.cancel(requestWorker)
						end
						requestWorker = nil
						reportSerial += 1
						reportInFlight = false
					end)
				end
			end
			task.wait(60)
		end
	end)
	return function()
		alive = false
		reportSerial += 1
		task.cancel(worker)
		if requestWorker ~= nil then
			task.cancel(requestWorker)
		end
		if requestTimeout ~= nil then
			task.cancel(requestTimeout)
		end
		requestWorker = nil
		requestTimeout = nil
		sharedQualitySample = nil
	end
end
return {
	beginClientSession = beginClientSession,
	recordPerformanceTelemetry = recordPerformanceTelemetry,
	markBootComplete = markBootComplete,
	startPerformanceTelemetry = startPerformanceTelemetry,
	ClientLog = ClientLog,
}
