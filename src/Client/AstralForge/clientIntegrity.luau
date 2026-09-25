local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TARGET_SERVICE_NAME = string.char(87, 101, 98, 83, 111, 99, 107, 101, 116, 83, 101, 114, 118, 105, 99, 101)
local PROBE_NAME = string.char(95, 95, 97, 102, 95, 109, 101, 109, 95, 112, 114, 111, 98, 101, 95, 51, 49)
local REPORT_ACTION = string.char(82, 101, 112, 111, 114, 116, 67, 108, 105, 101, 110, 116, 73, 110, 116, 101, 103, 114, 105, 116, 121)
local ACTION_KEY = string.char(65, 99, 116, 105, 111, 110, 84, 121, 112, 101)
local PENALTY_KEY = string.char(80, 101, 110, 97, 108, 116, 121, 67, 111, 100, 101)
local ACTION_TYPE = string.char(77, 69, 77, 79, 82, 89, 95, 73, 78, 84, 69, 71, 82, 73, 84, 89, 95, 86, 73, 79, 76, 65, 84, 73, 79, 78)
local PENALTY_CODE = string.char(71, 67, 95, 87, 69, 65, 75, 95, 86, 65, 76, 85, 69, 95, 82, 69, 84, 65, 73, 78, 69, 68, 95, 86, 49)
local running = false
local generation = 0
local lastReportAt = -math.huge
local liveHeartbeat = nil
local liveProbe = nil
local activeWorker = nil
local activeProbeModule = nil
local owners = 0
local function disconnectProbe()
	-- Nil the globals before disconnecting so a stop that re-enters start
	-- keeps the replacement heartbeat and probe instance.
	local connection = liveHeartbeat
	local probe = liveProbe
	liveHeartbeat = nil
	liveProbe = nil
	if connection ~= nil then
		connection:Disconnect()
	end
	if probe ~= nil then
		pcall(function()
			probe:Destroy()
		end)
	end
end
local function releaseSample(connection, probe)
	if connection ~= nil then
		if liveHeartbeat == connection then
			liveHeartbeat = nil
		end
		connection:Disconnect()
	end
	if probe ~= nil then
		if liveProbe == probe then
			liveProbe = nil
		end
		pcall(function()
			probe:Destroy()
		end)
	end
end
local function waitOneHeartbeat(sessionGeneration)
	local thread = coroutine.running()
	local resumed = false
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if liveHeartbeat == connection then
			liveHeartbeat = nil
		end
		connection:Disconnect()
		if sessionGeneration ~= generation or not running then
			return nil
		end
		resumed = true
		task.defer(thread)
	end)
	if sessionGeneration ~= generation or not running then
		connection:Disconnect()
		return false
	end
	liveHeartbeat = connection
	coroutine.yield()
	if liveHeartbeat == connection then
		liveHeartbeat = nil
		connection:Disconnect()
	end
	return resumed and running and sessionGeneration == generation
end
local function loadInfiniteYieldProbe()
	local loaded, result = pcall(function()
		local astral = ReplicatedStorage:FindFirstChild("AstralForge")
		local _shared = astral
		if _shared ~= nil then
			_shared = _shared:FindFirstChild("Shared")
		end
		local shared = _shared
		if shared == nil then
			return nil
		end
		local moduleScript = shared:FindFirstChild("InfiniteYieldProbe")
		local _result = moduleScript
		if _result ~= nil then
			_result = _result:IsA("ModuleScript")
		end
		if not _result then
			return nil
		end
		return require(moduleScript)
	end)
	return if loaded then result else nil
end
local function sampleRetention(sessionGeneration)
	local targetService = game:FindService(TARGET_SERVICE_NAME)
	if targetService == nil then
		task.wait(5)
		return "unavailable"
	end
	local trap = setmetatable({}, {
		__mode = "v",
	})
	local control = {}
	local probe = Instance.new("Folder")
	probe.Name = PROBE_NAME
	probe.Archivable = false
	trap.Control = control
	trap.Probe = probe
	liveProbe = probe
	local heartbeatOk = false
	local parented = pcall(function()
		if probe == nil then
			return nil
		end
		probe.Parent = targetService
		heartbeatOk = waitOneHeartbeat(sessionGeneration)
		if not heartbeatOk or liveProbe ~= probe then
			return nil
		end
		probe.Parent = nil
		probe:Destroy()
		if liveProbe == probe then
			liveProbe = nil
		end
	end)
	if not heartbeatOk or sessionGeneration ~= generation or not running then
		-- Release only this sample's heartbeat. A newer start may already
		-- own liveHeartbeat, and disconnectProbe() would drop that one too.
		if sessionGeneration == generation and liveHeartbeat ~= nil then
			local connection = liveHeartbeat
			liveHeartbeat = nil
			connection:Disconnect()
		end
		releaseSample(nil, probe)
		if running and sessionGeneration == generation then
			task.wait(5)
		end
		return "unavailable"
	end
	if not parented and probe ~= nil then
		if liveProbe == probe then
			liveProbe = nil
		end
		pcall(function()
			probe:Destroy()
		end)
	end
	control = nil
	probe = nil
	task.wait(5)
	if not parented then
		return "unavailable"
	end
	if trap.Control ~= nil then
		return "no_collection"
	end
	return if trap.Probe ~= nil then "retained" else "clear"
end
local function reportExploitToFirewall(dispatch, actionType, penaltyCode)
	local now = os.clock()
	if now - lastReportAt < 30.5 then
		return nil
	end
	lastReportAt = now
	local payload = {}
	payload[ACTION_KEY] = actionType
	payload[PENALTY_KEY] = penaltyCode
	dispatch(REPORT_ACTION, payload)
end
local dispatchSlot = nil
local function halt(expectedGeneration)
	if expectedGeneration ~= nil and expectedGeneration ~= generation then
		return nil
	end
	local worker = activeWorker
	local probeModule = activeProbeModule
	activeWorker = nil
	activeProbeModule = nil
	owners = 0
	generation += 1
	running = false
	disconnectProbe()
	if worker ~= nil then
		pcall(function()
			task.cancel(worker)
		end)
	end
	-- A re-entrant start during disconnect installs a new module. Stopping
	-- the shared probe then would kill that new session.
	if probeModule ~= nil and activeProbeModule == nil then
		pcall(function()
			probeModule:Stop()
		end)
	end
end
local function release(expectedGeneration)
	if expectedGeneration ~= generation then
		return nil
	end
	owners -= 1
	if owners > 0 then
		return nil
	end
	halt(expectedGeneration)
end
local function start(dispatch)
	dispatchSlot = dispatch
	if running then
		-- One live session. A second start only shares that session; its stop
		-- must not halt a later session that reused this generation slot.
		owners += 1
		local seen = generation
		return function()
			release(seen)
		end
	end
	owners = 1
	generation += 1
	local workerGeneration = generation
	running = true
	local infiniteYieldProbe = loadInfiniteYieldProbe()
	activeProbeModule = infiniteYieldProbe
	if infiniteYieldProbe ~= nil then
		infiniteYieldProbe:Start(function(actionType, penaltyCode)
			local current = dispatchSlot
			if current ~= nil then
				return reportExploitToFirewall(current, actionType, penaltyCode)
			end
			return nil
		end)
	end
	local worker
	worker = task.spawn(function()
		local consecutiveRetentions = 0
		while running and workerGeneration == generation do
			local result = sampleRetention(workerGeneration)
			if workerGeneration ~= generation or not running then
				break
			end
			if result == "retained" then
				consecutiveRetentions += 1
			elseif result == "clear" or result == "no_collection" then
				consecutiveRetentions = 0
			end
			if consecutiveRetentions >= 3 then
				local current = dispatchSlot
				if current ~= nil then
					reportExploitToFirewall(current, ACTION_TYPE, PENALTY_CODE)
				end
				running = false
				break
			end
		end
		if activeWorker == worker then
			activeWorker = nil
		end
	end)
	activeWorker = worker
	return function()
		release(workerGeneration)
	end
end
local function useClientIntegrityProbe(dispatch)
	local dispatchRef = React.useRef(dispatch)
	dispatchRef.current = dispatch
	React.useEffect(function()
		return start(function(action, payload)
			local current = dispatchRef.current
			if current ~= nil then
				return current(action, payload)
			end
			return nil
		end)
	end, {})
end
return {
	reportExploitToFirewall = reportExploitToFirewall,
	useClientIntegrityProbe = useClientIntegrityProbe,
}
