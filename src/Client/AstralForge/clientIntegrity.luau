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
local function sampleRetention()
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
	local parented = pcall(function()
		if probe == nil then
			return nil
		end
		probe.Parent = targetService
		RunService.Heartbeat:Wait()
		probe.Parent = nil
		probe:Destroy()
	end)
	if not parented and probe ~= nil then
		pcall(function()
			local _result = probe
			if _result ~= nil then
				_result = _result:Destroy()
			end
			return _result
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
local function start(dispatch)
	generation += 1
	local workerGeneration = generation
	running = true
	local infiniteYieldProbe = loadInfiniteYieldProbe()
	local _result = infiniteYieldProbe
	if _result ~= nil then
		_result:Start(function(actionType, penaltyCode)
			return reportExploitToFirewall(dispatch, actionType, penaltyCode)
		end)
	end
	local worker = task.spawn(function()
		local consecutiveRetentions = 0
		while running and workerGeneration == generation do
			local result = sampleRetention()
			if result == "retained" then
				consecutiveRetentions += 1
			elseif result == "clear" or result == "no_collection" then
				consecutiveRetentions = 0
			end
			if consecutiveRetentions >= 3 then
				reportExploitToFirewall(dispatch, ACTION_TYPE, PENALTY_CODE)
				running = false
				break
			end
		end
	end)
	return function()
		if workerGeneration ~= generation then
			return nil
		end
		running = false
		generation += 1
		pcall(function()
			return task.cancel(worker)
		end)
		local _result_1 = infiniteYieldProbe
		if _result_1 ~= nil then
			_result_1:Stop()
		end
	end
end
local function useClientIntegrityProbe(dispatch)
	React.useEffect(function()
		return start(dispatch)
	end, { dispatch })
end
return {
	reportExploitToFirewall = reportExploitToFirewall,
	useClientIntegrityProbe = useClientIntegrityProbe,
}
