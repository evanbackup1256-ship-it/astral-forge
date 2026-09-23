local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local Lighting = game:GetService("Lighting")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local MainGame = require(script.MainGame).MainGame
local _antilag = require(script.antilag)
local AntilagProvider = _antilag.AntilagProvider
local watchPing = _antilag.watchPing
local _audio = require(script.audio)
local Audio = _audio.Audio
local hookGuiClicks = _audio.hookGuiClicks
local _BootScreen = require(script.BootScreen)
local BOOT_MOTION = _BootScreen.BOOT_MOTION
local BootScreen = _BootScreen.BootScreen
local _clientStore = require(script.clientStore)
local ClientActions = _clientStore.ClientActions
local ClientStoreProvider = _clientStore.ClientStoreProvider
local createClientStore = _clientStore.createClientStore
local destroyClientStore = _clientStore.destroyClientStore
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local DomainExpansionOverlay = require(script.DomainExpansionOverlay).DomainExpansionOverlay
local DomainSkillTree = require(script.DomainSkillTree).DomainSkillTree
local initializeClientFramework = require(script.frameworkBridge).initializeClientFramework
local _log = require(script.log)
local beginClientSession = _log.beginClientSession
local ClientLog = _log.ClientLog
local markBootComplete = _log.markBootComplete
local startPerformanceTelemetry = _log.startPerformanceTelemetry
local MotionSettingsContext = require(script.motion).MotionSettingsContext
local startEgooeHost = require(script.egooeHost).startEgooeHost
local installScrollPerformance = require(script.scrolling).installScrollPerformance
local configureInputPlatform = require(script.inputPlatform).configureInputPlatform
local startSession = require(script.session).startSession
local SoftShutdownScreen = require(script.SoftShutdownScreen).SoftShutdownScreen
local Palette = require(script.theme).Palette
local SCREEN_NAME = "AstralForgeStudioUI"
local REPLICATION_TIMEOUT = 15
local CHILD_TIMEOUT = 8
local stopInputPlatform = configureInputPlatform()
-- Fired once at boot so AutoLocalize'd text (see ui.tsx's Text/TextInput components) doesn't
-- stall its first translation lookup on the player's own request -- GetTranslatorForPlayerAsync
-- is a network round trip, and warming it here means it's already resolved by the time any
-- localized string actually renders.
task.spawn(function()
	pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(Players.LocalPlayer)
	end)
end)
local function DomainApp(props)
	local overlay = useClientSelector(function(state)
		return state.domain.overlay
	end)
	local busy = useClientSelector(function(state)
		return state.domain.busy
	end)
	local domainRank = useClientSelector(function(state)
		local _result = state.session
		if _result ~= nil then
			_result = _result.Domain
			if _result ~= nil then
				_result = _result.Rank
			end
		end
		local _condition = _result
		if _condition == nil then
			_condition = 0
		end
		return _condition
	end)
	local canExpand = useClientSelector(function(state)
		local _result = state.session
		if _result ~= nil then
			_result = _result.Domain
			if _result ~= nil then
				_result = _result.CanExpand
			end
		end
		return _result == true
	end)
	local dispatchStore = useClientDispatch()
	local open = React.useCallback(function()
		if busy then
			return nil
		end
		if domainRank > 0 and not canExpand then
			dispatchStore(ClientActions.setDomainOverlay({
				mode = "tree",
			}))
		else
			dispatchStore(ClientActions.setDomainOverlay({
				mode = "confirm",
			}))
		end
	end, { busy, canExpand, dispatchStore, domainRank })
	local render = React.useCallback(function(state, dispatch, children)
		local confirm = function()
			if busy then
				return nil
			end
			dispatchStore(ClientActions.setDomainBusy(true))
			dispatch("DomainExpansion", {}, function(response)
				dispatchStore(ClientActions.setDomainBusy(false))
				if not response.ok or response.DomainRank == nil then
					return nil
				end
				local _object = {
					mode = "result",
				}
				local _left = "result"
				local _object_1 = {
					rank = response.DomainRank,
				}
				local _left_1 = "essence"
				local _condition = response.DomainEssence
				if _condition == nil then
					_condition = 0
				end
				_object_1[_left_1] = _condition
				local _left_2 = "stardust"
				local _condition_1 = response.StardustReward
				if _condition_1 == nil then
					_condition_1 = 0
				end
				_object_1[_left_2] = _condition_1
				local _left_3 = "overflow"
				local _condition_2 = response.OverflowReward
				if _condition_2 == nil then
					_condition_2 = 0
				end
				_object_1[_left_3] = _condition_2
				local _left_4 = "freeSpins"
				local _condition_3 = response.FreeSpins
				if _condition_3 == nil then
					_condition_3 = 0
				end
				_object_1[_left_4] = _condition_3
				local _left_5 = "nextRebirths"
				local _condition_4 = response.NextRequiredRebirths
				if _condition_4 == nil then
					_condition_4 = 0
				end
				_object_1[_left_5] = _condition_4
				local _left_6 = "nextCores"
				local _condition_5 = response.NextRequiredCores
				if _condition_5 == nil then
					_condition_5 = 0
				end
				_object_1[_left_6] = _condition_5
				_object[_left] = _object_1
				dispatchStore(ClientActions.setDomainOverlay(_object))
			end)
		end
		return React.createElement(React.Fragment, nil, children, state.Domain ~= nil and overlay ~= nil and overlay.mode == "tree" and React.createElement(DomainSkillTree, {
			domain = state.Domain,
			dispatch = dispatch,
			reducedMotion = state.Settings.ReducedMotion == true,
			onClose = function()
				return dispatchStore(ClientActions.setDomainOverlay(nil))
			end,
		}), state.Domain ~= nil and overlay ~= nil and overlay.mode ~= "tree" and React.createElement(DomainExpansionOverlay, {
			key = overlay.mode,
			mode = overlay.mode,
			domain = state.Domain,
			currentRebirths = state.Rebirths,
			currentCores = state.Cores,
			result = if overlay.mode == "result" then overlay.result else nil,
			busy = busy,
			reducedMotion = state.Settings.ReducedMotion == true,
			onConfirm = confirm,
			onClose = function()
				if busy then
					return nil
				end
				local _condition = overlay.mode == "result"
				if _condition then
					local _result = state.Domain
					if _result ~= nil then
						_result = _result.Rank
					end
					local _condition_1 = _result
					if _condition_1 == nil then
						_condition_1 = 0
					end
					_condition = _condition_1 > 0
				end
				if _condition then
					dispatchStore(ClientActions.setDomainOverlay({
						mode = "tree",
					}))
				else
					dispatchStore(ClientActions.setDomainOverlay(nil))
				end
			end,
		}))
	end, { busy, dispatchStore, overlay })
	local domainUi = React.useMemo(function()
		return {
			open = open,
			active = overlay ~= nil,
			render = render,
		}
	end, { open, overlay, render })
	local _attributes = table.clone(props)
	setmetatable(_attributes, nil)
	_attributes.domainUi = domainUi
	return React.createElement(MainGame, _attributes)
end
local StableApp = React.memo(DomainApp)
local function StartupFailure(_param)
	local message = _param.message
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 500,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -32, 0, 190),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 501,
	}, React.createElement("uisizeconstraint", {
		MaxSize = Vector2.new(420, 190),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	}), React.createElement("uistroke", {
		Color = Palette.coral,
		Thickness = 2,
		Transparency = 0.22,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -36, 0, 24),
		Position = UDim2.fromOffset(18, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "STARTUP LINK LOST",
		TextColor3 = Palette.coral,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 502,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -42, 0, 70),
		Position = UDim2.fromOffset(21, 58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = message,
		TextColor3 = Palette.creamSoft,
		TextSize = 12,
		TextWrapped = true,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 502,
	}), React.createElement("textlabel", {
		Size = UDim2.new(1, -36, 0, 20),
		Position = UDim2.fromOffset(18, 149),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "REJOIN TO RETRY  //  CHECK SERVER OUTPUT IN STUDIO",
		TextColor3 = Palette.muted,
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.RobotoMono),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 502,
	})))
end
local function normalizeShutdown(raw, fallbackRevision)
	local _raw = raw
	if not (type(_raw) == "table") then
		return nil
	end
	local payload = raw
	local revisionRaw = payload.Revision
	local revision = if type(revisionRaw) == "number" and revisionRaw == revisionRaw then math.max(0, math.floor(revisionRaw)) else fallbackRevision
	local _object = {
		revision = revision,
	}
	local _left = "state"
	local _object_1 = {}
	local _left_1 = "phase"
	local _condition = payload.Phase
	if _condition == nil then
		_condition = "Saving"
	end
	_object_1[_left_1] = string.sub(tostring(_condition), 1, 48)
	local _left_2 = "message"
	local _condition_1 = payload.Message
	if _condition_1 == nil then
		_condition_1 = "Saving your progress."
	end
	_object_1[_left_2] = string.sub(tostring(_condition_1), 1, 180)
	_object[_left] = _object_1
	return _object
end
local function ClientBootstrap(_param)
	local connection = _param.connection
	local failure = _param.failure
	local startedAt = _param.startedAt
	local shutdownLayer = _param.shutdownLayer
	local status = useClientSelector(function(state)
		return state.boot.status
	end)
	local bootVisible = useClientSelector(function(state)
		return state.boot.visible
	end)
	local dispatchStore = useClientDispatch()
	local shutdownState, setShutdownState = React.useState()
	local bridgeFailure, setBridgeFailure = React.useState()
	local shutdownRevision = React.useRef(0)
	local shutdownActive = React.useRef(false)
	React.useEffect(function()
		if connection == nil then
			return nil
		end
		local syncFailure = function()
			local problem = connection.remotes.Bridge:GetAttribute("BootFailure")
			if not (type(problem) == "string") or #problem == 0 then
				return nil
			end
			setBridgeFailure(string.sub(problem, 1, 240))
			pcall(function()
				return StarterGui:SetCore("TopbarEnabled", true)
			end)
		end
		local changed = connection.remotes.Bridge:GetAttributeChangedSignal("BootFailure"):Connect(syncFailure)
		syncFailure()
		return function()
			return changed:Disconnect()
		end
	end, { connection })
	React.useEffect(function()
		if connection == nil then
			return nil
		end
		local accept = function(raw)
			local normalized = normalizeShutdown(raw, shutdownRevision.current + 1)
			if normalized == nil or normalized.revision <= shutdownRevision.current then
				return nil
			end
			shutdownRevision.current = normalized.revision
			shutdownActive.current = true
			setShutdownState(normalized.state)
			pcall(function()
				return StarterGui:SetCore("TopbarEnabled", false)
			end)
		end
		local syncBridge = function()
			if connection.remotes.Bridge:GetAttribute("ShuttingDown") ~= true then
				return nil
			end
			accept({
				Phase = connection.remotes.Bridge:GetAttribute("ShutdownPhase"),
				Message = connection.remotes.Bridge:GetAttribute("ShutdownMessage"),
				Revision = connection.remotes.Bridge:GetAttribute("ShutdownRevision"),
			})
		end
		local eventConnection = connection.remotes.Shutdown.OnClientEvent:Connect(accept)
		local attributeConnection = connection.remotes.Bridge:GetAttributeChangedSignal("ShutdownRevision"):Connect(syncBridge)
		syncBridge()
		return function()
			eventConnection:Disconnect()
			attributeConnection:Disconnect()
		end
	end, { connection })
	local bootVisibleRef = React.useRef(bootVisible)
	bootVisibleRef.current = bootVisible
	local handleBootStatus = React.useCallback(function(statusNext)
		if bootVisibleRef.current then
			dispatchStore(ClientActions.setBootStatus(statusNext))
		end
	end, { dispatchStore })
	local finishBoot = React.useCallback(function()
		markBootComplete()
		bootVisibleRef.current = false
		dispatchStore(ClientActions.setBootVisible(false))
		if not shutdownActive.current then
			pcall(function()
				return StarterGui:SetCore("TopbarEnabled", true)
			end)
		end
	end, { dispatchStore })
	local _condition = failure
	if _condition == nil then
		_condition = bridgeFailure
	end
	local activeFailure = _condition
	if activeFailure ~= nil then
		return React.createElement(StartupFailure, {
			message = activeFailure,
		})
	end
	local _exp = connection ~= nil and React.createElement(StableApp, {
		key = "app",
		remotes = connection.remotes,
		config = connection.config,
		bootStartedAt = startedAt,
		externalBoot = true,
		externalAntilag = true,
		onBootStatus = handleBootStatus,
	})
	local _condition_1 = bootVisible
	if _condition_1 then
		local _attributes = {
			marks = status.marks,
			ready = status.ready,
			progress = status.progress,
		}
		local _result = connection
		if _result ~= nil then
			_result = _result.config.Game.Version
		end
		local _condition_2 = _result
		if _condition_2 == nil then
			_condition_2 = "3.5.0 PRE-ALPHA"
		end
		_attributes.version = _condition_2
		_attributes.reducedMotion = status.reducedMotion
		_attributes.startedAt = startedAt
		_attributes.assetsLoaded = status.assetsLoaded
		_attributes.assetsTotal = status.assetsTotal
		_attributes.modulesLoaded = status.modulesLoaded
		_attributes.modulesTotal = status.modulesTotal
		_attributes.onExitDone = finishBoot
		_condition_1 = React.createElement(MotionSettingsContext.Provider, {
			key = "boot",
			value = BOOT_MOTION,
		}, React.createElement(BootScreen, _attributes))
	end
	return React.createElement(AntilagProvider, nil, _exp, _condition_1, shutdownState ~= nil and ReactRoblox.createPortal(React.createElement(SoftShutdownScreen, {
		state = shutdownState,
		reducedMotion = status.reducedMotion,
	}), shutdownLayer))
end
local ClientRuntime
do
	ClientRuntime = setmetatable({}, {
		__tostring = function()
			return "ClientRuntime"
		end,
	})
	ClientRuntime.__index = ClientRuntime
	function ClientRuntime.new(...)
		local self = setmetatable({}, ClientRuntime)
		return self:constructor(...) or self
	end
	function ClientRuntime:constructor(playerGui)
		self.disposers = {}
		self.disposed = false
		self.playerGui = playerGui
		local staleScreen = playerGui:FindFirstChild(SCREEN_NAME)
		if staleScreen ~= nil and staleScreen:IsA("ScreenGui") then
			staleScreen:Destroy()
		end
		local staleShutdown = playerGui:FindFirstChild("AstralForgeShutdown")
		if staleShutdown ~= nil and staleShutdown:IsA("ScreenGui") then
			staleShutdown:Destroy()
		end
		local stopScrollPerformance = installScrollPerformance()
		local stopEgooe = startEgooeHost(playerGui)
		local _exp = self.disposers
		table.insert(_exp, function()
			stopScrollPerformance()
			stopEgooe()
		end)
		local screen = Instance.new("ScreenGui")
		screen.Name = SCREEN_NAME
		screen.ResetOnSpawn = false
		screen.IgnoreGuiInset = false
		screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		screen.ClipToDeviceSafeArea = true
		screen.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
		screen.DisplayOrder = 80
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screen.Parent = playerGui
		self.screen = screen
		local _disposers = self.disposers
		local _arg0 = hookGuiClicks(playerGui)
		table.insert(_disposers, _arg0)
		local shutdownLayer = Instance.new("ScreenGui")
		shutdownLayer.Name = "AstralForgeShutdown"
		shutdownLayer.ResetOnSpawn = false
		shutdownLayer.IgnoreGuiInset = false
		shutdownLayer.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		shutdownLayer.ClipToDeviceSafeArea = true
		shutdownLayer.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
		shutdownLayer.DisplayOrder = 260
		shutdownLayer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		shutdownLayer.Parent = playerGui
		self.shutdownLayer = shutdownLayer
		self.store = createClientStore()
		self.root = ReactRoblox.createRoot(screen)
		initializeClientFramework(screen)
		local destroying = screen.Destroying:Connect(function()
			return self:dispose()
		end)
		local _exp_1 = self.disposers
		table.insert(_exp_1, function()
			return destroying:Disconnect()
		end)
		local _exp_2 = self.disposers
		table.insert(_exp_2, function()
			return shutdownLayer:Destroy()
		end)
	end
	function ClientRuntime:addDisposer(disposer)
		if self.disposed then
			disposer()
			return nil
		end
		local _disposers = self.disposers
		local _disposer = disposer
		table.insert(_disposers, _disposer)
	end
	function ClientRuntime:render(element)
		if self.disposed then
			return nil
		end
		self.root:render(React.createElement(ClientStoreProvider, {
			store = self.store,
		}, element))
	end
	function ClientRuntime:dispose()
		if self.disposed then
			return nil
		end
		self.disposed = true
		pcall(function()
			return self.root:unmount()
		end)
		for index = #self.disposers - 1, 0, -1 do
			pcall(self.disposers[index + 1])
		end
		table.clear(self.disposers)
		local purchaseLayer = self.playerGui:FindFirstChild("AstralForgePurchase")
		if purchaseLayer ~= nil and purchaseLayer:IsA("ScreenGui") then
			purchaseLayer:Destroy()
		end
		destroyClientStore(self.store)
		Audio:dispose()
		pcall(function()
			return StarterGui:SetCore("TopbarEnabled", true)
		end)
	end
end
local function configureUiOnlyWorkspace()
	local lighting = Lighting
	local previous = {
		globalShadows = lighting.GlobalShadows,
		brightness = lighting.Brightness,
		ambient = lighting.Ambient,
		outdoorAmbient = lighting.OutdoorAmbient,
		environmentDiffuse = lighting.EnvironmentDiffuseScale,
		environmentSpecular = lighting.EnvironmentSpecularScale,
		fogEnd = lighting.FogEnd,
		clockTime = lighting.ClockTime,
	}
	local parked = Instance.new("Folder")
	parked.Name = "AF_ParkedLighting"
	pcall(function()
		lighting.GlobalShadows = false
		lighting.Brightness = 1
		lighting.Ambient = Color3.fromRGB(18, 20, 32)
		lighting.OutdoorAmbient = Color3.fromRGB(18, 20, 32)
		lighting.EnvironmentDiffuseScale = 0
		lighting.EnvironmentSpecularScale = 0
		lighting.FogEnd = 1000000
		lighting.ClockTime = 0
	end)
	pcall(function()
		lighting.Technology = Enum.Technology.Compatibility
	end)
	for _, child in lighting:GetChildren() do
		if child:IsA("PostEffect") then
			child.Enabled = false
		elseif child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("Clouds") then
			child.Parent = parked
		end
	end
	local camera = Workspace.CurrentCamera
	local _previousCameraType = camera
	if _previousCameraType ~= nil then
		_previousCameraType = _previousCameraType.CameraType
	end
	local previousCameraType = _previousCameraType
	local _previousSubject = camera
	if _previousSubject ~= nil then
		_previousSubject = _previousSubject.CameraSubject
	end
	local previousSubject = _previousSubject
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CameraSubject = nil
	end
	local muteScripts
	muteScripts = function(instance)
		if instance == nil then
			return nil
		end
		if instance:IsA("BaseScript") then
			instance.Disabled = true
		end
		for _, child in instance:GetChildren() do
			muteScripts(child)
		end
	end
	local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	if playerScripts ~= nil then
		muteScripts(playerScripts:FindFirstChild("PlayerModule"))
		muteScripts(playerScripts:FindFirstChild("RbxCharacterSounds"))
	end
	return function()
		pcall(function()
			lighting.GlobalShadows = previous.globalShadows
			lighting.Brightness = previous.brightness
			lighting.Ambient = previous.ambient
			lighting.OutdoorAmbient = previous.outdoorAmbient
			lighting.EnvironmentDiffuseScale = previous.environmentDiffuse
			lighting.EnvironmentSpecularScale = previous.environmentSpecular
			lighting.FogEnd = previous.fogEnd
			lighting.ClockTime = previous.clockTime
		end)
		for _, child in parked:GetChildren() do
			child.Parent = lighting
		end
		parked:Destroy()
		if camera ~= nil then
			if previousCameraType ~= nil then
				camera.CameraType = previousCameraType
			end
			camera.CameraSubject = previousSubject
		end
	end
end
local function configureRobloxUi(playerGui)
	local orientation = playerGui.ScreenOrientation
	local coreTypes = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Chat }
	local coreStates = {}
	for _, coreType in coreTypes do
		pcall(function()
			local _arg1 = StarterGui:GetCoreGuiEnabled(coreType)
			coreStates[coreType] = _arg1
			return coreStates
		end)
	end
	local chatWindow = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local chatInput = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	local _chatWindowEnabled = chatWindow
	if _chatWindowEnabled ~= nil then
		_chatWindowEnabled = _chatWindowEnabled.Enabled
	end
	local chatWindowEnabled = _chatWindowEnabled
	local _chatInputEnabled = chatInput
	if _chatInputEnabled ~= nil then
		_chatInputEnabled = _chatInputEnabled.Enabled
	end
	local chatInputEnabled = _chatInputEnabled
	local _bubblesEnabled = bubbles
	if _bubblesEnabled ~= nil then
		_bubblesEnabled = _bubblesEnabled.Enabled
	end
	local bubblesEnabled = _bubblesEnabled
	local mobileTouch = UserInputService.TouchEnabled and (UserInputService.PreferredInput == Enum.PreferredInput.Touch or (not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled))
	if mobileTouch then
		pcall(function()
			playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		end)
	end
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
		for _, coreType in coreTypes do
			StarterGui:SetCoreGuiEnabled(coreType, false)
		end
		if chatWindow then
			chatWindow.Enabled = false
		end
		if chatInput then
			chatInput.Enabled = false
		end
		if bubbles then
			bubbles.Enabled = false
		end
	end)
	pcall(function()
		local gui = StarterGui
		local clipEnum = Enum.ClipsDescendantsSupportsRotation
		local _result = clipEnum
		if _result ~= nil then
			_result = _result.Enabled
		end
		if _result ~= nil then
			gui.ClipsDescendantsSupportsRotation = clipEnum.Enabled
		end
	end)
	return function()
		pcall(function()
			playerGui.ScreenOrientation = orientation
		end)
		pcall(function()
			return StarterGui:SetCore("TopbarEnabled", true)
		end)
		for coreType, enabled in coreStates do
			pcall(function()
				return StarterGui:SetCoreGuiEnabled(coreType, enabled)
			end)
		end
		if chatWindow ~= nil and chatWindowEnabled ~= nil then
			pcall(function()
				chatWindow.Enabled = chatWindowEnabled
			end)
		end
		if chatInput ~= nil and chatInputEnabled ~= nil then
			pcall(function()
				chatInput.Enabled = chatInputEnabled
			end)
		end
		if bubbles ~= nil and bubblesEnabled ~= nil then
			pcall(function()
				bubbles.Enabled = bubblesEnabled
			end)
		end
	end
end
beginClientSession()
ClientLog:debug("boot", "client started")
local clientStartedAt = os.clock()
local function bootLog(stage: string)
	ClientLog:info("BOOT", stage, { ElapsedMs = math.floor((os.clock() - clientStartedAt) * 1000) })
end
local playerGuiInstance = Players.LocalPlayer:WaitForChild("PlayerGui", REPLICATION_TIMEOUT)
if playerGuiInstance == nil or not playerGuiInstance:IsA("PlayerGui") then
	error("[AF/startup] PlayerGui was unavailable", 0)
end
local playerGui = playerGuiInstance
bootLog("playerGui acquired")
local runtime = ClientRuntime.new(playerGui)
bootLog("runtime created")
local restoreRobloxUi = configureRobloxUi(playerGui)
runtime:addDisposer(restoreRobloxUi)
runtime:addDisposer(stopInputPlatform)
runtime:addDisposer(configureUiOnlyWorkspace())
Audio:setScene("boot")
runtime:render(React.createElement(ClientBootstrap, {
	startedAt = clientStartedAt,
	shutdownLayer = runtime.shutdownLayer,
}))
local failBootstrap = function(message)
	ClientLog:warn("Startup", message)
	restoreRobloxUi()
	runtime:render(React.createElement(ClientBootstrap, {
		startedAt = clientStartedAt,
		failure = message,
		shutdownLayer = runtime.shutdownLayer,
	}))
	task.wait()
	error(`[AF/startup] {message}`, 0)
end
local requiredChild = function(parent, name, className, timeout, message)
	local child = parent:WaitForChild(name, timeout)
	if child == nil or not child:IsA(className) then
		return failBootstrap(message)
	end
	return child
end
local function loadModule(moduleScript, label)
	local ok, result = pcall(function()
		return require(moduleScript)
	end)
	if not ok then
		return failBootstrap(`{label} failed to load: {tostring(result)}`)
	end
	return result
end
local astralRoot = requiredChild(ReplicatedStorage, "AstralForge", "Folder", REPLICATION_TIMEOUT, "AstralForge did not replicate within 15 seconds.")
local sharedRoot = requiredChild(astralRoot, "Shared", "Folder", CHILD_TIMEOUT, "Shared client modules did not replicate within 8 seconds.")
local protocolScript = requiredChild(sharedRoot, "Protocol", "ModuleScript", CHILD_TIMEOUT, "Protocol module is missing or has the wrong class.")
local configScript = requiredChild(sharedRoot, "GameConfig", "ModuleScript", CHILD_TIMEOUT, "GameConfig module is missing or has the wrong class.")
local protocol = loadModule(protocolScript, "Protocol")
local config = loadModule(configScript, "GameConfig")
for _, name in { protocol.FolderName, protocol.RequestName, protocol.StateName, protocol.ToastName, protocol.EffectName, protocol.ShutdownName } do
	if not (type(name) == "string") or #name < 1 or #name > 64 then
		failBootstrap("Protocol contains an invalid bridge name.")
	end
end
pcall(function()
	local spinner = sharedRoot:FindFirstChild("NumberSpinner")
	if spinner ~= nil and spinner:IsA("ModuleScript") then
		require(spinner)
	end
end)
pcall(function()
	local _spinner = astralRoot:FindFirstChild("Vendor")
	if _spinner ~= nil then
		_spinner = _spinner:FindFirstChild("NumberSpinner")
	end
	local spinner = _spinner
	if spinner ~= nil and spinner:IsA("ModuleScript") then
		require(spinner)
	end
end)
local bridge = requiredChild(ReplicatedStorage, protocol.FolderName, "Folder", REPLICATION_TIMEOUT, "Server bridge was not published within 15 seconds. Check the first Server error.")
local remotes = {
	Bridge = bridge,
	Request = requiredChild(bridge, protocol.RequestName, "RemoteFunction", 5, "Server request remote is missing or has the wrong class."),
	State = requiredChild(bridge, protocol.StateName, "RemoteEvent", 5, "Server state remote is missing or has the wrong class."),
	Toast = requiredChild(bridge, protocol.ToastName, "RemoteEvent", 5, "Server toast remote is missing or has the wrong class."),
	Effect = requiredChild(bridge, protocol.EffectName, "RemoteEvent", 5, "Server effect remote is missing or has the wrong class."),
	Shutdown = requiredChild(bridge, protocol.ShutdownName, "RemoteEvent", 5, "Server shutdown remote is missing or has the wrong class."),
}
local stopPerformanceTelemetry = startPerformanceTelemetry(remotes.Request)
runtime:addDisposer(stopPerformanceTelemetry)
runtime:addDisposer(startSession(remotes))
watchPing(remotes.Request, "MeasureLatency")
ClientLog:debug("net", `connected to {config.Game.Version}`)
runtime:render(React.createElement(ClientBootstrap, {
	startedAt = clientStartedAt,
	connection = {
		remotes = remotes,
		config = config,
	},
	shutdownLayer = runtime.shutdownLayer,
}))
ClientLog:once("ui-ready", "ui", `{config.Game.Version} ui is up`)
