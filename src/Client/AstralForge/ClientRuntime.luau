--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("ClientRuntime: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("ClientRuntime: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["assetPreloader"] = function()
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local seedAntilagFromBoot = require(script.Parent.MotionKit)("antilag").seedAntilagFromBoot
local AUDIO_ASSET_MANIFEST = require(script.Parent.AudioKit)("audio").AUDIO_ASSET_MANIFEST
local FORGE_ASSET_MANIFEST = require(script.Parent.ArtKit)("ForgeAnvil2D").FORGE_ASSET_MANIFEST
local _Icon = require(script.Parent.ArtKit)("Icon")
local GAME_ICON_ASSET = _Icon.GAME_ICON_ASSET
local VECTOR_ICON_ATLAS = _Icon.VECTOR_ICON_ATLAS
local ClientLog = require(script.Parent.CoreKit)("log").ClientLog
local MUSIC_ASSET_MANIFEST = require(script.Parent.AudioKit)("musicDirector").MUSIC_ASSET_MANIFEST
local PRELOAD_BATCH_SIZE = if UserInputService.TouchEnabled then 16 else 100
local PRELOAD_FAIL_OPEN_SECONDS = if UserInputService.TouchEnabled then 30 else 120
local MAX_STABILITY_SWEEPS = if UserInputService.TouchEnabled then 2 else 4
local REQUIRED_STABLE_SWEEPS = if UserInputService.TouchEnabled then 1 else 2
local STABILITY_SWEEP_SECONDS = 0.25
local FAILURE_RETRY_ROUNDS = 1
local GOTHAM_FONT_FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local _array = { VECTOR_ICON_ATLAS, GAME_ICON_ASSET }
local _length = #_array
local _aUDIO_ASSET_MANIFESTLength = #AUDIO_ASSET_MANIFEST
table.move(AUDIO_ASSET_MANIFEST, 1, _aUDIO_ASSET_MANIFESTLength, _length + 1, _array)
_length += _aUDIO_ASSET_MANIFESTLength
local _mUSIC_ASSET_MANIFESTLength = #MUSIC_ASSET_MANIFEST
table.move(MUSIC_ASSET_MANIFEST, 1, _mUSIC_ASSET_MANIFESTLength, _length + 1, _array)
_length += _mUSIC_ASSET_MANIFESTLength
local _fORGE_ASSET_MANIFESTLength = #FORGE_ASSET_MANIFEST
table.move(FORGE_ASSET_MANIFEST, 1, _fORGE_ASSET_MANIFESTLength, _length + 1, _array)
_length += _fORGE_ASSET_MANIFESTLength
_array[_length + 1] = GOTHAM_FONT_FAMILY
_array[_length + 2] = "rbxasset://fonts/families/BuilderSans.json"
_array[_length + 3] = "rbxasset://fonts/families/RobotoMono.json"
local STATIC_ASSET_MANIFEST = _array
local function carriesContent(instance)
	return instance:IsA("ImageLabel") or instance:IsA("ImageButton") or instance:IsA("ImageHandleAdornment") or instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") or instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("Sound") or instance:IsA("AudioPlayer") or instance:IsA("Animation") or instance:IsA("AnimationClip") or instance:IsA("MeshPart") or instance:IsA("SpecialMesh") or instance:IsA("UnionOperation") or instance:IsA("SurfaceAppearance") or instance:IsA("MaterialVariant") or instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") or instance:IsA("VideoFrame") or instance:IsA("VideoPlayer") or instance:IsA("Sky") or instance:IsA("Shirt") or instance:IsA("Pants") or instance:IsA("ShirtGraphic") or instance:IsA("CharacterMesh") or instance:IsA("Accessory") or instance:IsA("AccessoryDescription") or instance:IsA("BodyPartDescription") or instance:IsA("Tool") or instance:IsA("HumanoidDescription") or instance:IsA("WrapLayer") or instance:IsA("WrapTarget")
end
local function addContentId(contentId, seen, target)
	local _condition = contentId == ""
	if not _condition then
		local _seen = seen
		local _contentId = contentId
		_condition = _seen[_contentId] ~= nil
	end
	if _condition then
		return nil
	end
	local _seen = seen
	local _contentId = contentId
	_seen[_contentId] = true
	local _target = target
	local _contentId_1 = contentId
	table.insert(_target, _contentId_1)
end
local function collectStaticContent(seen, target)
	for _, contentId in STATIC_ASSET_MANIFEST do
		addContentId(contentId, seen, target)
	end
	for _, player in Players:GetPlayers() do
		local avatarSizes = if UserInputService.TouchEnabled then { { "AvatarHeadShot", 150 } } else { { "AvatarHeadShot", 150 }, { "AvatarBust", 420 } }
		for _1, _binding in avatarSizes do
			local kind = _binding[1]
			local size = _binding[2]
			addContentId(`rbxthumb://type={kind}&id={player.UserId}&w={size}&h={size}`, seen, target)
		end
	end
end
local function isUiElement(instance)
	return instance:IsA("GuiObject") or instance:IsA("UIBase") or instance:IsA("LayerCollector") or carriesContent(instance)
end
local function collectMountedContent(seen, target, deepWorld)
	if deepWorld == nil then
		deepWorld = false
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local roots = { ReplicatedFirst, ReplicatedStorage, StarterGui, StarterPack, StarterPlayer, playerGui, SoundService, Lighting, MaterialService }
	for _, root in roots do
		if root == nil then
			continue
		end
		if not (seen[root] ~= nil) then
			seen[root] = true
			table.insert(target, root)
		end
		for _1, instance in root:GetDescendants() do
			if seen[instance] ~= nil or not isUiElement(instance) then
				continue
			end
			seen[instance] = true
			table.insert(target, instance)
		end
	end
	if not deepWorld then
		return nil
	end
	for _, instance in Workspace:GetDescendants() do
		if seen[instance] ~= nil or not carriesContent(instance) then
			continue
		end
		seen[instance] = true
		table.insert(target, instance)
	end
end
local harvestVisits = 0
local function harvestContentIds(value, seen, target, depth)
	if depth == nil then
		depth = 0
	end
	if depth > 8 or value == nil then
		return nil
	end
	harvestVisits += 1
	if harvestVisits % 4000 == 0 then
		RunService.Heartbeat:Wait()
	end
	local _value = value
	if type(_value) == "string" then
		if (string.find(value, "rbxasset")) ~= nil then
			addContentId(value, seen, target)
		end
		return nil
	end
	local _value_1 = value
	if not (type(_value_1) == "table") then
		return nil
	end
	for _, child in pairs(value) do
		if type(child) == "function" then
			continue
		end
		harvestContentIds(child, seen, target, depth + 1)
	end
end
local function collectConfigContent(seen, target)
	local _shared = ReplicatedStorage:FindFirstChild("AstralForge")
	if _shared ~= nil then
		_shared = _shared:FindFirstChild("Shared")
	end
	local shared = _shared
	local _module = shared
	if _module ~= nil then
		_module = _module:FindFirstChild("GameConfig")
	end
	local module = _module
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, config = pcall(function()
		return require(module)
	end)
	if not ok then
		return nil
	end
	for _, value in pairs(config) do
		harvestContentIds(value, seen, target)
	end
end
local function sampleFrameRate(seconds)
	if seconds == nil then
		seconds = 0.55
	end
	local started = os.clock()
	local frames = 0
	while os.clock() - started < seconds do
		RunService.Heartbeat:Wait()
		frames += 1
	end
	local elapsed = math.max(0.08, os.clock() - started)
	return frames / elapsed
end
local function preloadMountedGame(onComplete, onProgress, shellReady)
	local cancelled = false
	local bootMarked = false
	local worker
	local watchdog
	local function markBootReady()
		if bootMarked then
			return nil
		end
		bootMarked = true
		onComplete()
	end
	worker = task.defer(function()
		local startedAt = os.clock()
		local seenInstances = {}
		local seenContentIds = {}
		local queue = {}
		collectStaticContent(seenContentIds, queue)
		collectConfigContent(seenContentIds, queue)
		collectMountedContent(seenInstances, queue, true)
		local warmupTotal = 0
		local _result = onProgress
		if _result ~= nil then
			_result(0, math.max(1, #queue + warmupTotal))
		end
		local measured = sampleFrameRate(if UserInputService.TouchEnabled then 0.25 else 0.35)
		seedAntilagFromBoot(measured)
		local loaded = 0
		local failedBatches = 0
		local failedAssets = 0
		local failedContentIds = {}
		local function drain(items)
			do
				local offset = 0
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						offset += PRELOAD_BATCH_SIZE
					else
						_shouldIncrement = true
					end
					if not (offset < #items and not cancelled) then
						break
					end
					local batch = {}
					do
						local index = offset
						local _shouldIncrement_1 = false
						while true do
							if _shouldIncrement_1 then
								index += 1
							else
								_shouldIncrement_1 = true
							end
							if not (index < math.min(#items, offset + PRELOAD_BATCH_SIZE)) then
								break
							end
							local item = items[index + 1]
							if item == nil then
								continue
							end
							if type(item) == "string" or item.Parent ~= nil then
								table.insert(batch, item)
							end
						end
					end
					local ok, preloadErr = pcall(function()
						return ContentProvider:PreloadAsync(batch, function(contentId, status)
							if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
								failedAssets += 1
								if contentId ~= "" then
									local _failedContentIds = failedContentIds
									local _contentId = contentId
									_failedContentIds[_contentId] = true
								end
							elseif status == Enum.AssetFetchStatus.Success and contentId ~= "" then
								local _failedContentIds = failedContentIds
								local _contentId = contentId
								_failedContentIds[_contentId] = nil
							end
						end)
					end)
					if cancelled then
						break
					end
					if not ok then
						failedBatches += 1
						ClientLog:warnEvery("preload-batch", 10, "Assets", tostring(preloadErr))
					end
					loaded += #batch
					local _result_1 = onProgress
					if _result_1 ~= nil then
						_result_1(loaded, math.max(#queue + warmupTotal, loaded))
					end
					RunService.Heartbeat:Wait()
				end
			end
		end
		drain(queue)
		while not cancelled and shellReady ~= nil and not shellReady() and os.clock() - startedAt < PRELOAD_FAIL_OPEN_SECONDS do
			RunService.Heartbeat:Wait()
		end
		local stableSweeps = 0
		do
			local sweep = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					sweep += 1
				else
					_shouldIncrement = true
				end
				if not (sweep < MAX_STABILITY_SWEEPS and stableSweeps < REQUIRED_STABLE_SWEEPS and not cancelled) then
					break
				end
				task.wait(STABILITY_SWEEP_SECONDS)
				local late = {}
				collectStaticContent(seenContentIds, late)
				collectMountedContent(seenInstances, late, not UserInputService.TouchEnabled and sweep >= 2)
				if #late == 0 then
					stableSweeps += 1
				else
					stableSweeps = 0
					drain(late)
				end
			end
		end
		do
			local round = 0
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					round += 1
				else
					_shouldIncrement = true
				end
				local _condition = round < FAILURE_RETRY_ROUNDS
				if _condition then
					local _size = 0
					for _ in failedContentIds do
						_size += 1
					end
					_condition = _size > 0
					if _condition then
						_condition = not cancelled
					end
				end
				if not _condition then
					break
				end
				local retry = {}
				local _callback = function(contentId)
					local _contentId = contentId
					table.insert(retry, _contentId)
					return #retry
				end
				for _v in failedContentIds do
					_callback(_v, _v, failedContentIds)
				end
				failedContentIds = {}
				drain(retry)
			end
		end
		if cancelled then
			return nil
		end
		if failedBatches > 0 or failedAssets > 0 then
			ClientLog:warn("Assets", `{failedAssets} assets and {failedBatches} batches will stream on demand`)
		end
		markBootReady()
		if watchdog ~= nil then
			task.cancel(watchdog)
			watchdog = nil
		end
		ClientLog:once("asset-preload-ready", "assets", `{loaded} assets ready in {string.format("%.2f", os.clock() - startedAt)}s`)
		worker = nil
	end)
	watchdog = task.delay(PRELOAD_FAIL_OPEN_SECONDS, function()
		watchdog = nil
		if not cancelled then
			ClientLog:warn("Assets", "complete preload deadline reached; unresolved assets will stream on demand")
			markBootReady()
			if worker ~= nil then
				task.cancel(worker)
				worker = nil
			end
		end
	end)
	return function()
		cancelled = true
		if worker ~= nil then
			task.cancel(worker)
		end
		if watchdog ~= nil then
			task.cancel(watchdog)
		end
		worker = nil
		watchdog = nil
	end
end
local MODULE_FRAME_BUDGET = if UserInputService.TouchEnabled then 0.006 else 0.008
local function collectModuleScripts(root, seen, list)
	if root == nil or seen[root] ~= nil then
		return nil
	end
	seen[root] = true
	if root:IsA("ModuleScript") then
		table.insert(list, root)
	end
	for _, child in root:GetDescendants() do
		if child:IsA("ModuleScript") and seen[child] == nil then
			seen[child] = true
			table.insert(list, child)
		end
	end
end
local function skipWarmModule(moduleScript)
	local name = moduleScript.Name
	if name == "TestBootstrap" or string.sub(name, -5) == ".spec" or string.sub(name, -5) == ".test" then
		return true
	end
	local fullName = moduleScript:GetFullName()
	if string.find(fullName, "FlameworkRuntime", 1, true) ~= nil then
		return true
	end
	if string.find(fullName, "node_modules", 1, true) ~= nil then
		return true
	end
	if string.find(fullName, ".tests", 1, true) ~= nil then
		return true
	end
	return false
end
local function warmClientModules(onProgress)
	local seen = {}
	local modules = {}
	local replicated = ReplicatedStorage
	collectModuleScripts(replicated:FindFirstChild("AstralForge"), seen, modules)
	local playerScripts = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")
	if playerScripts ~= nil then
		collectModuleScripts(playerScripts:FindFirstChild("AstralForge"), seen, modules)
		collectModuleScripts(playerScripts:FindFirstChild("SharedRuntime"), seen, modules)
	end
	local total = #modules
	local loaded = 0
	local lastReport = 0
	if onProgress ~= nil then
		onProgress(0, math.max(total, 1))
	end
	local members = {}
	local function queueMembers(suite)
		local ok, names = pcall(function()
			return suite.__members
		end)
		if not ok or type(names) ~= "table" then
			return nil
		end
		for _, name in names do
			table.insert(members, { suite = suite, name = name })
		end
		total += #names
	end
	local index = 1
	local memberIndex = 1
	while index <= #modules or memberIndex <= #members do
		local sliceStarted = os.clock()
		while index <= #modules and os.clock() - sliceStarted < MODULE_FRAME_BUDGET do
			local moduleScript = modules[index]
			index += 1
			if moduleScript.Parent ~= nil and not skipWarmModule(moduleScript) then
				local ok, exports = pcall(require, moduleScript)
				if ok and type(exports) == "table" then
					queueMembers(exports)
				end
			end
			loaded += 1
		end
		while index > #modules and memberIndex <= #members and os.clock() - sliceStarted < MODULE_FRAME_BUDGET do
			local entry = members[memberIndex]
			memberIndex += 1
			pcall(entry.suite, entry.name)
			loaded += 1
		end
		local now = os.clock()
		if onProgress ~= nil and (loaded >= total or now - lastReport >= 0.12) then
			lastReport = now
			onProgress(loaded, total)
		end
		RunService.Heartbeat:Wait()
	end
	ClientLog:once("module-warm-ready", "modules", `{#modules} modules and {#members} suite members warm`)
	return loaded, total
end
return {
	preloadMountedGame = preloadMountedGame,
	warmClientModules = warmClientModules,
}
end

__defs["clientIntegrity"] = function()
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
end

__defs["chat"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Audio = require(script.Parent.AudioKit)("audio").Audio
local ChatText = require(script.Parent.CoreKit)("chatText")
local sharedRoot = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local ChatRules = require(sharedRoot:WaitForChild("ChatRules"))
local Protocol = require(sharedRoot:WaitForChild("Protocol"))
local MAX_MESSAGES = 200
local MAX_INPUT = ChatRules.MAX_INPUT
local TAB_KEYS = { "global", "server", "crew", "friends", "whispers" }
local CHANNEL_LABEL = { global = "global chat", server = "this server", crew = "your crew", friends = "friends here" }
local function readTitleAttrs(player)
	if player == nil then
		return {}
	end
	local titleId = player:GetAttribute("EquippedTitle")
	local titleName = player:GetAttribute("EquippedTitleName")
	local titleFx = player:GetAttribute("EquippedTitleFx")
	local artifactName = player:GetAttribute("EquippedArtifactName")
	local artifactElement = player:GetAttribute("EquippedArtifactElement")
	local artifactColor = player:GetAttribute("EquippedArtifactColor")
	local hasArtifact = type(player:GetAttribute("EquippedArtifact")) == "string" and player:GetAttribute("EquippedArtifact") ~= ""
	return {
		titleId = if type(titleId) == "string" and titleId ~= "" then titleId else nil,
		titleName = if type(titleName) == "string" and titleName ~= "" then titleName else nil,
		titleFx = if type(titleFx) == "string" and titleFx ~= "" then titleFx else nil,
		artifactName = if hasArtifact and type(artifactName) == "string" and artifactName ~= "" then artifactName else nil,
		artifactElement = if hasArtifact and type(artifactElement) == "string" and artifactElement ~= "" then artifactElement else nil,
		artifactColor = if hasArtifact and typeof(artifactColor) == "Color3" then artifactColor else nil,
	}
end
local systemSerial = 0
local function systemMessage(text)
	systemSerial += 1
	return {
		id = `system-{systemSerial}-{os.clock()}`,
		userId = 0,
		username = "System",
		displayName = "System",
		text = text,
		at = os.time(),
		world = 0,
		channel = "system",
		localPlayer = false,
		system = true,
	}
end
local function pushTrimmed(current, incoming)
	local updated = table.clone(current)
	table.insert(updated, incoming)
	while #updated > MAX_MESSAGES do
		table.remove(updated, 1)
	end
	return updated
end
local function statusError(status)
	if status == Enum.TextChatMessageStatus.Floodchecked then
		return "Slow down, chat is rate limited."
	end
	if status == Enum.TextChatMessageStatus.MessageTooLong then
		return "Message is too long."
	end
	if status == Enum.TextChatMessageStatus.TextFilterFailed then
		return "Roblox chat filters blocked that message."
	end
	if status == Enum.TextChatMessageStatus.InvalidPrivacySettings then
		return "Chat is unavailable for this account."
	end
	if status == Enum.TextChatMessageStatus.InvalidTextChannelPermissions then
		return "You can't send on this channel."
	end
	return "Message not sent."
end
local function rosterOf(selfId)
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.UserId ~= selfId then
			table.insert(list, { userId = player.UserId, name = player.Name, displayName = player.DisplayName })
		end
	end
	return list
end
local function buildRecord(userId, text, channel, peerId, id)
	local player = Players:GetPlayerByUserId(userId)
	local title = readTitleAttrs(player)
	local zone = if player ~= nil then player:GetAttribute("CurrentZone") else nil
	return {
		id = id,
		userId = userId,
		username = if player ~= nil then player.Name else `Player{userId}`,
		displayName = if player ~= nil then player.DisplayName else `Player {userId}`,
		text = text,
		world = if type(zone) == "number" then zone else 1,
		channel = channel,
		peerId = peerId,
		localPlayer = userId == Players.LocalPlayer.UserId,
		at = os.time(),
		-- someone else @mentioning you gets highlighted and a stronger sound
		mention = userId ~= Players.LocalPlayer.UserId and ChatRules.mentions(text, Players.LocalPlayer.Name, Players.LocalPlayer.DisplayName),
		titleId = title.titleId,
		titleName = title.titleName,
		titleFx = title.titleFx,
		artifactName = title.artifactName,
		artifactElement = title.artifactElement,
		artifactColor = title.artifactColor,
	}
end
local function emptyUnread()
	return { global = 0, server = 0, crew = 0, friends = 0, whispers = 0 }
end
local function useGameChat(active, enabled, dispatch, settings)
	if enabled == nil then
		enabled = true
	end
	local selfId = Players.LocalPlayer.UserId
	local messages, setMessages = React.useState({})
	local unreadByTab, setUnreadByTab = React.useState(emptyUnread)
	local connected, setConnected = React.useState(false)
	local tab, setTabState = React.useState("all")
	local peer, setPeerState = React.useState(nil)
	local whispers, setWhispers = React.useState({})
	local muted, setMuted = React.useState({})
	local channelsRef = React.useRef({ server = nil, friends = nil, crew = {}, whisper = {} })
	local pendingRef = React.useRef({})
	local seenRef = React.useRef({ ids = {}, order = {} })
	local lastWhisperRef = React.useRef(nil)
	local activeRef = React.useRef(active)
	local tabRef = React.useRef(tab)
	local peerRef = React.useRef(peer)
	local mutedRef = React.useRef(muted)
	local dispatchRef = React.useRef(dispatch)
	local aliveRef = React.useRef(true)
	local settingsRef = React.useRef(settings)
	settingsRef.current = settings
	local sendWorkers = React.useRef({})
	activeRef.current = active
	tabRef.current = tab
	peerRef.current = peer
	mutedRef.current = muted
	dispatchRef.current = dispatch
	local clearSeen = React.useCallback(function(which, peerId)
		setUnreadByTab(function(current)
			if which == "all" then
				return emptyUnread()
			end
			if current[which] == nil or current[which] == 0 then
				return current
			end
			local nextValue = table.clone(current)
			nextValue[which] = 0
			return nextValue
		end)
		if which == "whispers" or which == "all" then
			setWhispers(function(current)
				local changed = false
				local nextValue = {}
				for index, entry in current do
					if entry.unread > 0 and (peerId == nil or entry.userId == peerId) then
						local copy = table.clone(entry)
						copy.unread = 0
						nextValue[index] = copy
						changed = true
					else
						nextValue[index] = entry
					end
				end
				return if changed then nextValue else current
			end)
		end
	end, {})
	React.useEffect(function()
		if active then
			clearSeen(tab, if tab == "whispers" then peer else nil)
		end
	end, { active, tab, peer })
	local note = React.useCallback(function(text)
		setMessages(function(current)
			return pushTrimmed(current, systemMessage(text))
		end)
	end, {})
	local touchWhisper = React.useCallback(function(peerId, text, incoming)
		setWhispers(function(current)
			local nextValue = {}
			local found = nil
			for _, entry in current do
				if entry.userId == peerId then
					found = table.clone(entry)
				else
					table.insert(nextValue, entry)
				end
			end
			if found == nil then
				local player = Players:GetPlayerByUserId(peerId)
				found = {
					userId = peerId,
					name = if player ~= nil then player.Name else `Player{peerId}`,
					displayName = if player ~= nil then player.DisplayName else `Player {peerId}`,
					unread = 0,
					lastText = "",
				}
			end
			if text ~= nil then
				found.lastText = text
			end
			found.online = channelsRef.current.whisper[peerId] ~= nil
			if incoming then
				local looking = activeRef.current and tabRef.current == "whispers" and peerRef.current == peerId
				if not looking then
					found.unread = math.min(99, found.unread + 1)
				end
			end
			table.insert(nextValue, 1, found)
			return nextValue
		end)
	end, {})
	local ingestRecord = React.useCallback(function(record, quiet)
		local seen = seenRef.current
		if seen.ids[record.id] then
			return nil
		end
		seen.ids[record.id] = true
		table.insert(seen.order, record.id)
		if #seen.order > MAX_MESSAGES * 2 then
			seen.ids[table.remove(seen.order, 1)] = nil
		end
		setMessages(function(current)
			return pushTrimmed(current, record)
		end)
		local tabKey = if record.channel == "whisper" then "whispers" else record.channel
		if record.channel == "whisper" and record.peerId ~= nil then
			touchWhisper(record.peerId, record.text, not record.localPlayer)
			if not record.localPlayer then
				lastWhisperRef.current = record.peerId
			end
		end
		if record.localPlayer or quiet or mutedRef.current[record.userId] then
			return nil
		end
		local prefs = settingsRef.current
		if type(prefs) ~= "table" or prefs.ChatSounds == nil or prefs.ChatSounds >= 0.5 then
			Audio:play(if record.mention then "notification" else "chatReceive")
		end
		local seeing = activeRef.current and (tabRef.current == "all" or tabRef.current == tabKey)
		if record.channel == "whisper" and tabRef.current == "whispers" then
			seeing = activeRef.current and peerRef.current == record.peerId
		end
		if not seeing then
			setUnreadByTab(function(current)
				local nextValue = table.clone(current)
				nextValue[tabKey] = math.min(99, (nextValue[tabKey] or 0) + 1)
				return nextValue
			end)
		end
	end, {})
	local sendOn = React.useCallback(function(target, text, done)
		Audio:play("chatSend")
		local worker
		worker = task.defer(function()
			local ok, result = pcall(function()
				return target:SendAsync(text)
			end)
			if worker ~= nil then
				sendWorkers.current[worker] = nil
			end
			worker = nil
			if not aliveRef.current then
				return nil
			end
			if not ok then
				if done then
					done(false, "Roblox could not send this message. Check your chat privacy settings and try again.")
				end
				return nil
			end
			if result == nil then
				if done then
					done(false, "Roblox did not confirm the message. Try again.")
				end
				return nil
			end
			if result.Status ~= Enum.TextChatMessageStatus.Success then
				local name = tostring(result.Status)
				if string.find(name, "Sending") == nil and string.find(name, "Pending") == nil then
					if done then
						done(false, statusError(result.Status))
					end
					return nil
				end
			end
			if done then
				done(true)
			end
		end)
		sendWorkers.current[worker] = true
	end, {})
	React.useEffect(function()
		if not enabled then
			setConnected(false)
			setMessages({ systemMessage("Chat is disabled in this experience.") })
			return nil
		end
		aliveRef.current = true
		local alive = true
		local connections = {}
		local channelConnections = {}
		local function track(connection)
			table.insert(connections, connection)
			return connection
		end
		local function ingestText(message, channel, peerId)
			if not alive or message.TextSource == nil or message.Status ~= Enum.TextChatMessageStatus.Success then
				return nil
			end
			local userId = message.TextSource.UserId
			local id = if message.MessageId ~= "" then message.MessageId else `{userId}-{os.clock()}`
			ingestRecord(buildRecord(userId, message.Text, channel, peerId, id), false)
		end
		local function attach(candidate)
			if not alive or not candidate:IsA("TextChannel") or channelConnections[candidate] ~= nil then
				return nil
			end
			local name = candidate.Name
			local refs = channelsRef.current
			if name == ChatRules.SERVER_CHANNEL then
				refs.server = candidate
				channelConnections[candidate] = candidate.MessageReceived:Connect(function(message)
					ingestText(message, "server", nil)
				end)
				setConnected(true)
			elseif name == ChatRules.FRIENDS_CHANNEL then
				refs.friends = candidate
				channelConnections[candidate] = candidate.MessageReceived:Connect(function(message)
					ingestText(message, "friends", nil)
				end)
			elseif ChatRules.isCrewChannel(name) then
				-- every crew channel replicates; only members receive its messages, and sending
				-- picks the channel named for this player's own crew
				refs.crew[name] = candidate
				channelConnections[candidate] = candidate.MessageReceived:Connect(function(message)
					ingestText(message, "crew", nil)
				end)
			else
				local peerId = ChatRules.whisperPeer(name, selfId)
				if peerId == nil then
					return nil
				end
				refs.whisper[peerId] = candidate
				channelConnections[candidate] = candidate.MessageReceived:Connect(function(message)
					ingestText(message, "whisper", peerId)
				end)
				touchWhisper(peerId, nil, false)
				local pending = pendingRef.current[peerId]
				pendingRef.current[peerId] = nil
				if type(pending) == "table" and pending.text ~= nil then
					sendOn(candidate, pending.text, pending.done)
				end
			end
		end
		local function detach(candidate)
			local connection = channelConnections[candidate]
			if connection == nil then
				return nil
			end
			connection:Disconnect()
			channelConnections[candidate] = nil
			local refs = channelsRef.current
			if refs.server == candidate then
				refs.server = nil
				setConnected(false)
			elseif refs.friends == candidate then
				refs.friends = nil
			elseif refs.crew[candidate.Name] == candidate then
				refs.crew[candidate.Name] = nil
			else
				for peerId, channel in refs.whisper do
					if channel == candidate then
						refs.whisper[peerId] = nil
						touchWhisper(peerId, nil, false)
					end
				end
			end
		end
		local effect = nil
		pcall(function()
			effect = ReplicatedStorage:FindFirstChild(Protocol.FolderName)
			effect = if effect ~= nil then effect:FindFirstChild(Protocol.EffectName) else nil
		end)
		local function onEffect(payload)
			if not alive or type(payload) ~= "table" or payload.Type ~= "ChatGlobal" or type(payload.Messages) ~= "table" then
				return nil
			end
			for _, entry in payload.Messages do
				if type(entry) == "table" and type(entry.UserId) == "number" and type(entry.Text) == "string" then
					local record = buildRecord(entry.UserId, entry.Text, "global", nil, `g-{tostring(entry.Id)}`)
					if type(entry.Name) == "string" then
						record.username = entry.Name
					end
					if type(entry.Display) == "string" then
						record.displayName = entry.Display
					end
					record.remote = Players:GetPlayerByUserId(entry.UserId) == nil
					if type(entry.At) == "number" then
						record.at = entry.At
					end
					ingestRecord(record, payload.Backlog == true)
				end
			end
		end
		if effect ~= nil and effect:IsA("RemoteEvent") then
			track(effect.OnClientEvent:Connect(onEffect))
		end
		setMessages({ systemMessage("Chat is connecting. This can take a moment on slower devices.") })
		local connectWorker = task.spawn(function()
			local channels = TextChatService:WaitForChild("TextChannels", 30)
			if not alive then
				return nil
			end
			if channels == nil then
				setConnected(false)
				note("Roblox chat did not start. Rejoin, then check Privacy > Communication if it still fails.")
				return nil
			end
			track(channels.ChildAdded:Connect(attach))
			track(channels.ChildRemoved:Connect(detach))
			for _, child in channels:GetChildren() do
				attach(child)
			end
			if channelsRef.current.server == nil then
				local general = channels:WaitForChild(ChatRules.SERVER_CHANNEL, 30)
				if general == nil and alive then
					note("Roblox chat is unavailable. Rejoin, then check Privacy > Communication if it still fails.")
					return nil
				end
			end
			if alive then
				note("Chat is ready. Roblox filters every message. Type / to see shortcuts.")
			end
		end)
		return function()
			alive = false
			aliveRef.current = false
			pcall(task.cancel, connectWorker)
			for worker in sendWorkers.current do
				pcall(task.cancel, worker)
			end
			table.clear(sendWorkers.current)
			for _, connection in connections do
				connection:Disconnect()
			end
			for _, connection in channelConnections do
				connection:Disconnect()
			end
			channelsRef.current = { server = nil, friends = nil, crew = {}, whisper = {} }
		end
	end, { enabled })
	local setTab = React.useCallback(function(nextTab)
		if table.find(ChatRules.CHANNELS, nextTab) == nil then
			return nil
		end
		setTabState(nextTab)
	end, {})
	local setPeer = React.useCallback(function(userId)
		setPeerState(userId)
		if userId ~= nil then
			setTabState("whispers")
		end
	end, {})
	local openWhisper = React.useCallback(function(userId, text, done)
		if type(userId) ~= "number" or userId == selfId then
			if done then
				done(false, "Pick another player to whisper.")
			end
			return nil
		end
		setPeerState(userId)
		setTabState("whispers")
		touchWhisper(userId, nil, false)
		local existing = channelsRef.current.whisper[userId]
		if existing ~= nil then
			if text ~= nil then
				sendOn(existing, text, done)
			elseif done then
				done(true)
			end
			return nil
		end
		local run = dispatchRef.current
		if run == nil then
			if done then
				done(false, "Whispers are still starting.")
			end
			return nil
		end
		pendingRef.current[userId] = { text = text, done = done }
		run("ChatOpenWhisper", { UserId = userId }, function(response)
			if type(response) ~= "table" or response.ok == false then
				local pending = pendingRef.current[userId]
				pendingRef.current[userId] = nil
				local reason = if type(response) == "table" and type(response.error) == "string" then response.error else "Could not open that whisper."
				if pending ~= nil and pending.done ~= nil then
					pending.done(false, reason)
				elseif text == nil then
					note(reason)
				end
				return nil
			end
			-- the channel may have replicated before the reply landed
			local ready = channelsRef.current.whisper[userId]
			local pending = pendingRef.current[userId]
			if ready ~= nil and pending ~= nil then
				pendingRef.current[userId] = nil
				if pending.text ~= nil then
					sendOn(ready, pending.text, pending.done)
				elseif pending.done ~= nil then
					pending.done(true)
				end
			elseif pending ~= nil and pending.text == nil then
				pendingRef.current[userId] = nil
				if pending.done ~= nil then
					pending.done(true)
				end
			end
		end)
	end, {})
	local sendGlobal = React.useCallback(function(text, done)
		local run = dispatchRef.current
		if run == nil then
			if done then
				done(false, "Global chat is still starting.")
			end
			return nil
		end
		Audio:play("chatSend")
		run("ChatGlobal", { Text = text }, function(response)
			if type(response) == "table" and response.ok ~= false then
				if done then
					done(true)
				end
			elseif done then
				done(false, if type(response) == "table" and type(response.error) == "string" then response.error else "Global chat did not take that message.")
			end
		end)
	end, {})
	local setMute = React.useCallback(function(userId, value)
		setMuted(function(current)
			local nextValue = table.clone(current)
			nextValue[userId] = if value then true else nil
			return nextValue
		end)
	end, {})
	local sendTo = function(where, text, done)
		local refs = channelsRef.current
		if where == "global" then
			sendGlobal(text, done)
		elseif where == "crew" then
			local mine = require(script.Parent.CrewStore).get().crew
			local channel = mine and refs.crew[mine.Channel]
			if channel == nil then
				if done then
					done(false, "Join a crew on the Crew page to use crew chat.")
				end
				return nil
			end
			sendOn(channel, text, done)
		elseif where == "friends" then
			if refs.friends == nil then
				if done then
					done(false, "Friends chat is still connecting.")
				end
				return nil
			end
			sendOn(refs.friends, text, done)
		elseif where == "whispers" then
			local target = peerRef.current
			if target == nil then
				if done then
					done(false, "Pick a conversation, or type /w name message.")
				end
				return nil
			end
			openWhisper(target, text, done)
		else
			if refs.server == nil then
				if done then
					done(false, "Chat is still connecting.")
				end
				return nil
			end
			sendOn(refs.server, text, done)
		end
	end
	local send = React.useCallback(function(raw, done)
		if not enabled then
			if done then
				done(false, "Chat is disabled in this experience.")
			end
			return nil
		end
		local command = ChatRules.parse(ChatText.limit(raw, MAX_INPUT + 40))
		local kind = command.kind
		local finish = function(ok, reason)
			if done then
				done(ok, reason)
			end
		end
		if kind == "empty" then
			finish(false, "Type a message first.")
		elseif kind == "say" then
			sendTo(tabRef.current, ChatText.limit(command.body, MAX_INPUT), done)
		elseif kind == "clear" then
			setMessages({ systemMessage("Messages on this device were cleared.") })
			finish(true)
		elseif kind == "help" then
			local lines = {}
			for _, info in ChatRules.COMMANDS do
				table.insert(lines, info.usage)
			end
			note("Shortcuts: " .. table.concat(lines, "  ·  ") .. ". Search supports from:name and in:global.")
			finish(true)
		elseif kind == "w" then
			local found = ChatRules.findPlayer(command.target, rosterOf(selfId))
			if found == nil then
				finish(false, if command.target == nil then "Who should get it? /w name message" else `No one here matches "{command.target}".`)
				return nil
			end
			openWhisper(found.userId, if command.body ~= nil then ChatText.limit(command.body, MAX_INPUT) else nil, done)
		elseif kind == "r" then
			local target = lastWhisperRef.current
			if target == nil then
				finish(false, "No whisper to reply to yet.")
				return nil
			end
			if command.body == nil then
				setPeer(target)
				finish(true)
				return nil
			end
			openWhisper(target, ChatText.limit(command.body, MAX_INPUT), done)
		elseif kind == "g" or kind == "s" or kind == "f" or kind == "c" then
			local where = if kind == "g" then "global" elseif kind == "s" then "server" elseif kind == "c" then "crew" else "friends"
			if command.body == nil then
				setTabState(where)
				finish(true)
				return nil
			end
			sendTo(where, ChatText.limit(command.body, MAX_INPUT), done)
		elseif kind == "mute" or kind == "unmute" then
			local found = ChatRules.findPlayer(command.target, rosterOf(selfId))
			if found == nil then
				finish(false, if command.target == nil then `Who? /{kind} name` else `No one here matches "{command.target}".`)
				return nil
			end
			setMute(found.userId, kind == "mute")
			note(if kind == "mute" then `{found.displayName} is muted on this device.` else `{found.displayName} can be heard again.`)
			finish(true)
		else
			finish(false, "Unknown shortcut. Type /help to see the list.")
		end
	end, { enabled })
	local clear = React.useCallback(function()
		setMessages({ systemMessage("Messages on this device were cleared.") })
	end, {})
	local suggest = React.useCallback(function(draft)
		return ChatRules.suggest(draft, rosterOf(selfId), 5)
	end, {})
	local unread = 0
	for _, key in TAB_KEYS do
		unread += unreadByTab[key] or 0
	end
	local visible = messages
	if next(muted) ~= nil then
		visible = {}
		for _, record in messages do
			if not muted[record.userId] then
				table.insert(visible, record)
			end
		end
	end
	local peerName = nil
	if peer ~= nil then
		for _, entry in whispers do
			if entry.userId == peer then
				peerName = entry.displayName
			end
		end
	end
	local placeholder = if tab == "whispers" then (if peerName ~= nil then `Whisper {peerName}...` else "Type /w name to start a whisper")
		elseif tab == "global" then `Message every server (one every {ChatRules.GLOBAL_COOLDOWN}s)...`
		else `Message {CHANNEL_LABEL[tab] or "this server"}... (/ for shortcuts)`
	return {
		messages = visible,
		unread = unread,
		unreadByTab = unreadByTab,
		connected = connected,
		tab = tab,
		setTab = setTab,
		peer = peer,
		setPeer = setPeer,
		whispers = whispers,
		muted = muted,
		setMute = setMute,
		openWhisper = openWhisper,
		send = send,
		clear = clear,
		suggest = suggest,
		placeholder = placeholder,
		-- Social settings the page applies: global chat in the All tab, and message text size
		showGlobal = type(settings) ~= "table" or settings.ChatShowGlobal == nil or settings.ChatShowGlobal >= 0.5,
		textScale = if type(settings) == "table" and type(settings.ChatTextSize) == "number" then 0.85 + settings.ChatTextSize * 0.45 else 1.075,
	}
end
return {
	useGameChat = useGameChat,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
