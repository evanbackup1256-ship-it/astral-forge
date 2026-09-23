--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

local ModuleLog = require(script:WaitForChild("ModuleLog"))
local Services = require(script:WaitForChild("Services"):WaitForChild("ServerServices"))

Players.CharacterAutoLoads = false

pcall(function()
	TextChatService.ChatVersion = Enum.ChatVersion.TextChatService
end)
pcall(function()
	TextChatService.CreateDefaultTextChannels = true
end)

local function requiredChild(parent: Instance, name: string, className: string, timeout: number): Instance
	local child = parent:WaitForChild(name, timeout)
	if child == nil then
		error(string.format("[AF/boot] %s did not appear under %s within %.0fs", name, parent:GetFullName(), timeout), 0)
	end
	if not child:IsA(className) then
		error(string.format("[AF/boot] %s must be %s, got %s", child:GetFullName(), className, child.ClassName), 0)
	end
	return child
end

local function makeRemote(className: "RemoteEvent" | "RemoteFunction", name: string, parent: Folder): Instance
	local remote = Instance.new(className)
	remote.Name = name
	remote.Archivable = false
	remote.Parent = parent
	return remote
end

local astralRoot = requiredChild(ReplicatedStorage, "AstralForge", "Folder", 30) :: Folder
local sharedRoot = requiredChild(astralRoot, "Shared", "Folder", 15) :: Folder
local Protocol = ModuleLog.Require(requiredChild(sharedRoot, "Protocol", "ModuleScript", 15) :: ModuleScript, "shared protocol")
local GameConfig = ModuleLog.Require(requiredChild(sharedRoot, "GameConfig", "ModuleScript", 15) :: ModuleScript, "game settings")

local priorBridge = ReplicatedStorage:FindFirstChild(Protocol.FolderName)
if priorBridge ~= nil then
	priorBridge:Destroy()
end

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = Protocol.FolderName
remoteFolder.Archivable = false
remoteFolder:SetAttribute("WireVersion", GameConfig.Game.DataVersion)
remoteFolder:SetAttribute("GameVersion", GameConfig.Game.Version)
remoteFolder:SetAttribute("PlaceVersion", game.PlaceVersion)
remoteFolder:SetAttribute("Ready", false)
remoteFolder:SetAttribute("BootJob", game.JobId)
remoteFolder.Parent = ReplicatedStorage

local request = makeRemote("RemoteFunction", Protocol.RequestName, remoteFolder) :: RemoteFunction
local state = makeRemote("RemoteEvent", Protocol.StateName, remoteFolder) :: RemoteEvent
local toast = makeRemote("RemoteEvent", Protocol.ToastName, remoteFolder) :: RemoteEvent
local effect = makeRemote("RemoteEvent", Protocol.EffectName, remoteFolder) :: RemoteEvent
local shutdown = makeRemote("RemoteEvent", Protocol.ShutdownName, remoteFolder) :: RemoteEvent

local shutdownRevision = 0
local function publishShutdown(phase: string, message: string)
	shutdownRevision += 1
	local startedAt = workspace:GetServerTimeNow()
	remoteFolder:SetAttribute("ShutdownPhase", phase)
	remoteFolder:SetAttribute("ShutdownMessage", message)
	remoteFolder:SetAttribute("ShutdownStartedAt", startedAt)
	remoteFolder:SetAttribute("ShutdownRevision", shutdownRevision)
	remoteFolder:SetAttribute("ShuttingDown", true)
	shutdown:FireAllClients({
		Phase = phase,
		Message = message,
		StartedAt = startedAt,
		Revision = shutdownRevision,
	})
end

request.OnServerInvoke = function()
	return { ok = false, error = "The server is still starting. Please retry in a moment." }
end

local function bootStep(label: string, callback: () -> any): any
	local ok, result = xpcall(callback, debug.traceback)
	if ok then
		return result
	end
	local problem = string.format("%s | %s", label, tostring(result))
	remoteFolder:SetAttribute("BootFailureStage", label)
	remoteFolder:SetAttribute("BootFailure", string.sub(problem, 1, 1000))
	error(result, 0)
end

local function timedRequire(label: string, loader: () -> any): any
	local start = os.clock()
	local result = bootStep(label, loader)
	ModuleLog.Info("BOOT", string.format("%s loaded", label), { ElapsedMs = math.floor((os.clock() - start) * 1000) })
	return result
end

local function timedBuild(label: string, builder: () -> any): any
	local start = os.clock()
	local result = bootStep(label, builder)
	ModuleLog.Info("BOOT", string.format("%s complete", label), { ElapsedMs = math.floor((os.clock() - start) * 1000) })
	return result
end

local DataService = timedRequire("player data module", function() return Services.DataService end)
local AdminService = timedRequire("administration module", function() return Services.AdminService end)
local GameService = timedRequire("gameplay module", function() return Services.GameService end)
local WorldService = timedRequire("world module", function() return Services.WorldService end)
local FluxSurgeService = timedRequire("flux surge module", function() return Services.FluxSurgeService end)
local Security = timedRequire("security module", function() return Services.Security end)
local CharacterIntegrity = timedRequire("integrity module", function() return Services.CharacterIntegrity end)

local dataService = timedBuild("player data construction", function() return DataService.new() end)
local adminService = timedBuild("administration construction", function() return AdminService.new(dataService) end)
local worldService = timedBuild("world construction", function() return WorldService.new() end)
local gameService
local fluxSurgeService = timedBuild("flux surge construction", function()
	return FluxSurgeService.new(
		function(player, title, body, kind)
			if gameService then
				gameService:_toastPlayer(player, title, body, kind)
			end
		end,
		function(player, payload)
			if gameService then
				gameService._effect:FireClient(player, payload)
			end
		end
	)
end)
local securityPipeline = timedBuild("security construction", function() return Security.new() end)
local characterIntegrity = timedBuild("integrity construction", function() return CharacterIntegrity.new() end)
gameService = timedBuild("gameplay construction", function() return GameService.new(dataService, worldService, fluxSurgeService, {
	Request = request,
	State = state,
	Toast = toast,
	Effect = effect,
	Security = securityPipeline,
	Admin = adminService,
}) end)

local runtimeClosed = false
local function closeRuntime()
	if runtimeClosed then
		return
	end
	runtimeClosed = true
	local operations = {
		{ "character integrity", function() characterIntegrity:Destroy() end },
		{ "security pipeline", function() securityPipeline:Destroy() end },
		{ "game service", function() gameService:Shutdown() end },
		{ "data service", function() dataService:Shutdown() end },
	}
	for _, operation in operations do
		local ok, problem = xpcall(operation[2] :: () -> (), debug.traceback)
		if not ok then
			ModuleLog.Warn("Shutdown", string.format("%s failed - %s", operation[1] :: string, tostring(problem)))
		end
	end
end

local function startRuntime()
	local start = os.clock()
	local function step(label, fn)
		local t = os.clock()
		fn()
		ModuleLog.Info("BOOT", label, { ElapsedMs = math.floor((os.clock() - t) * 1000) })
	end
	step("security start", function() securityPipeline:Start() end)
	step("integrity start", function() characterIntegrity:Start() end)
	step("world start", function() worldService:Start() end)
	step("game start", function() gameService:Start() end)
	step("autosave start", function() dataService:StartAutosave(GameConfig.Game.AutosaveSeconds) end)
	ModuleLog.Info("BOOT", "runtime started", { ElapsedMs = math.floor((os.clock() - start) * 1000) })
end

local started, startProblem = xpcall(startRuntime, debug.traceback)
if not started then
	remoteFolder:SetAttribute("BootFailure", tostring(startProblem))
	closeRuntime()
	error(startProblem, 0)
end

remoteFolder:SetAttribute("Ready", true)
remoteFolder:SetAttribute("ReadyAt", workspace:GetServerTimeNow())
ModuleLog.Debug("world", "ui-only server")
ModuleLog.Debug("game", "saves and state running")
ModuleLog.Debug("security", "request checks on")

local function findPlayer(username: string): Player?
	local requested = string.lower(username)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == requested then
			return player
		end
	end
	return nil
end

local function makeBindable(name: string, handler: (...any) -> any): BindableFunction
	local bindable = Instance.new("BindableFunction")
	bindable.Name = name
	bindable.OnInvoke = handler
	bindable.Parent = script
	return bindable
end

if RunService:IsStudio() then
	local ReleaseReadiness = ModuleLog.Require(script.ReleaseReadiness, "release tests")
	makeBindable("StudioReleaseAudit", function(minutes)
		if type(minutes) == "number" and minutes > 0 then
			return ReleaseReadiness.RunSoak(minutes)
		end
		return ReleaseReadiness.RunQuick()
	end)
	makeBindable("StudioAdmin", function(action, username, amount)
		if action ~= "GrantUnlimitedMoney" and action ~= "ShowRelease" and action ~= "GrantWheelSpins" then
			return { ok = false, message = "Unknown Studio admin action: " .. tostring(action) }
		end
		if type(username) ~= "string" or username == "" then
			return { ok = false, message = "Provide the username of a player in this test server." }
		end
		local target = findPlayer(username)
		if target == nil then
			return { ok = false, message = username .. " is not in this test server." }
		end
		if action == "ShowRelease" then
			local ok, message = gameService:ShowRelease(target)
			return { ok = ok, message = message }
		end
		if action == "GrantWheelSpins" then
			local ok, message, total = gameService:GrantStudioWheelSpins(target, amount)
			return { ok = ok, message = message, amount = total }
		end
		local ok, message, cash = gameService:GrantStudioMoney(target)
		return { ok = ok, message = message, amount = cash }
	end)
	local studioSoftShutdown = makeBindable("StudioSoftShutdown", function()
		publishShutdown("Saving", "Tempering a fresh test server. Your progress is safe.")
		return true
	end)
	studioSoftShutdown.Name = "StudioSoftShutdown"
end

game:BindToClose(function()
	local production = not RunService:IsStudio()
	publishShutdown("Saving", production
		and "Securing your forge before the server refreshes."
		or "Tempering a fresh test server. Your progress is safe.")
	closeRuntime()
	if not production then
		return
	end
	local remainingPlayers = Players:GetPlayers()
	if #remainingPlayers == 0 then
		return
	end
	publishShutdown("Teleporting", "Progress saved. Opening a fresh forge now.")
	task.wait(0.2)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		SoftShutdown = true,
		FromJob = game.JobId,
		Version = GameConfig.Game.Version,
	})
	local ok, issue = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, remainingPlayers, options)
	end)
	options:Destroy()
	if not ok then
		publishShutdown("Waiting", "Roblox is reconnecting this server. Hold tight.")
		ModuleLog.Warn("Shutdown", "group teleport deferred to Roblox - " .. tostring(issue))
	end
end)

ModuleLog.Once("server-ready", "server", "Astral Forge " .. GameConfig.Game.Version .. " is up")
