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
local seedAntilagFromBoot = require(script.Parent.antilag).seedAntilagFromBoot
local AUDIO_ASSET_MANIFEST = require(script.Parent.audio).AUDIO_ASSET_MANIFEST
local FORGE_ASSET_MANIFEST = require(script.Parent.ForgeAnvil2D).FORGE_ASSET_MANIFEST
local _Icon = require(script.Parent.Icon)
local GAME_ICON_ASSET = _Icon.GAME_ICON_ASSET
local VECTOR_ICON_ATLAS = _Icon.VECTOR_ICON_ATLAS
local ClientLog = require(script.Parent.log).ClientLog
local MUSIC_ASSET_MANIFEST = require(script.Parent.musicDirector).MUSIC_ASSET_MANIFEST
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
local function harvestContentIds(value, seen, target, depth)
	if depth == nil then
		depth = 0
	end
	if depth > 8 or value == nil then
		return nil
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
local HEAVY_GENERATED_KEYS = {
	Machines = true,
	Research = true,
	Zones = true,
	GridUpgrades = true,
}
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
	for key, value in pairs(config) do
		if not HEAVY_GENERATED_KEYS[key] then
			harvestContentIds(value, seen, target)
		end
	end
	if config.Operations then
		for key, value in pairs(config.Operations) do
			if key ~= "SeasonTiers" then
				harvestContentIds(value, seen, target)
			end
		end
	end
	if config.Anomalies then
		for key, value in pairs(config.Anomalies) do
			if key ~= "Milestones" then
				harvestContentIds(value, seen, target)
			end
		end
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
		-- Atlas tint/size variants and sprite frames share the same underlying asset ID.
		-- Preloading thousands of temporary UI instances bought no network coverage.
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
		-- Stay on the loading screen until the stability sweeps finish. The game
		-- then opens with those assets already resident instead of hitching in.
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
					-- ▼ ReadonlySet.size ▼
					local _size = 0
					for _ in failedContentIds do
						_size += 1
					end
					-- ▲ ReadonlySet.size ▲
					_condition = _size > 0
					if _condition then
						_condition = not cancelled
					end
				end
				if not _condition then
					break
				end
				local retry = {}
				-- ▼ ReadonlySet.forEach ▼
				local _callback = function(contentId)
					local _contentId = contentId
					table.insert(retry, _contentId)
					return #retry
				end
				for _v in failedContentIds do
					_callback(_v, _v, failedContentIds)
				end
				-- ▲ ReadonlySet.forEach ▲
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
	-- Compiled roblox-ts packages read their runtime from _G[script]. A raw require
	-- leaves that nil, prints "attempt to index nil with 'import'", and caches the
	-- module as failed for the rest of the session.
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
	local index = 1
	while index <= total do
		local sliceStarted = os.clock()
		while index <= total and os.clock() - sliceStarted < MODULE_FRAME_BUDGET do
			local moduleScript = modules[index]
			index += 1
			if moduleScript.Parent ~= nil and not skipWarmModule(moduleScript) then
				pcall(require, moduleScript)
			end
			loaded += 1
		end
		local now = os.clock()
		if onProgress ~= nil and (index > total or now - lastReport >= 0.12) then
			lastReport = now
			onProgress(loaded, total)
		end
		RunService.Heartbeat:Wait()
	end
	ClientLog:once("module-warm-ready", "modules", `{loaded} modules warm in client, vendor, and packages`)
	return loaded, total
end
return {
	preloadMountedGame = preloadMountedGame,
	warmClientModules = warmClientModules,
}
