local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReactRoblox = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"]["react-roblox"])
local ContextActionService = game:GetService("ContextActionService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local WorkspaceService = game:GetService("Workspace")
local _interaction = require(script.Parent.interaction)
local setHapticIntensity = _interaction.setHapticIntensity
local usesDesktopStructure = _interaction.usesDesktopStructure
local Icon = require(script.Parent.Icon).Icon
local _effects = require(script.Parent.effects)
local EffectLayer = _effects.EffectLayer
local POP_SECONDS = _effects.POP_SECONDS
local StarField = _effects.StarField
local AutoScale = require(script.Parent.autoScale).AutoScale
local _antilag = require(script.Parent.antilag)
local AntilagContext = _antilag.AntilagContext
local AntilagProvider = _antilag.AntilagProvider
local clampAntilagTier = _antilag.clampAntilagTier
local setAntilagPreference = _antilag.setAntilagPreference
local setAntilagScene = _antilag.setAntilagScene
local useAntilag = _antilag.useAntilag
local _motion = require(script.Parent.motion)
local beginUiTransition = _motion.beginUiTransition
local EntranceMotionSuppressedContext = _motion.EntranceMotionSuppressedContext
local MotionSettingsContext = _motion.MotionSettingsContext
local setClockBudget = _motion.setClockBudget
local setDecorativeMotionFrozen = _motion.setDecorativeMotionFrozen
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useTokenEntrance = _motion.useTokenEntrance
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local ToastRail = require(script.Parent.notifications).ToastRail
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local IconTile = _ui.IconTile
local meterFill = _ui.meterFill
local ScrollEdgeFade = _ui.ScrollEdgeFade
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local subscribeInputCancellation = _ui.subscribeInputCancellation
local useButtonChrome = _ui.useButtonChrome
local _theme = require(script.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local applyAccessibilityTheme = _theme.applyAccessibilityTheme
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local lighten = _theme.lighten
local moreDockHeight = _theme.moreDockHeight
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local gteFlux = _format.gteFlux
local _AdminPrankOverlay = require(script.Parent.AdminPrankOverlay)
local AdminPrankOverlay = _AdminPrankOverlay.AdminPrankOverlay
local HudPrankStage = _AdminPrankOverlay.HudPrankStage
local ActionCopy = require(script.Parent.actionCopy)
local _appNav = require(script.Parent.appNav)
local AppHelpers = _appNav.AppHelpers
local NetworkPolicy = require(script.Parent.networkPolicy)
local ClientLog = require(script.Parent.log).ClientLog
local _session = require(script.Parent.session)
local GRANT_ACTIONS = _session.GRANT_ACTIONS
local adopt = _session.adopt
local attachGrantFields = _session.attachGrantFields
local isAuthed = _session.isAuthed
local setPresencePage = _session.setPresencePage
local whenAuthed = _session.whenAuthed
local Audio = require(script.Parent.audio).Audio
local Boot = require(script.Parent.BootScreen)
local InteractionFeedback = require(script.Parent.interaction).InteractionFeedback
local _scrolling = require(script.Parent.scrolling)
local setScrollMomentum = _scrolling.setScrollMomentum
local setScrollSpeed = _scrolling.setScrollSpeed
local _clientStore = require(script.Parent.clientStore)
local ClientActions = _clientStore.ClientActions
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local preloadMountedGame = require(script.Parent.assetPreloader).preloadMountedGame
local useClientIntegrityProbe = require(script.Parent.clientIntegrity).useClientIntegrityProbe
-- Action toast copy (friendlyPlayerMessage / failureTitle / failureBody /
-- friendlyActionResponse) lives in actionCopy — Lune-tested, behavior unchanged.
local friendlyPlayerMessage = ActionCopy.friendlyPlayerMessage
local failureTitle = ActionCopy.failureTitle
local failureBody = ActionCopy.failureBody
local friendlyActionResponse = ActionCopy.friendlyActionResponse
local _AppShellChrome = require(script.Parent.AppShellChrome)
local Shell = _AppShellChrome.Shell
local pausePassivePaints = _AppShellChrome.pausePassivePaints
local function MainGame(_param)
	local remotes = _param.remotes
	local config = _param.config
	local bootStartedAt = _param.bootStartedAt
	local externalBoot = _param.externalBoot
	if externalBoot == nil then
		externalBoot = false
	end
	local externalAntilag = _param.externalAntilag
	if externalAntilag == nil then
		externalAntilag = false
	end
	-- Dead cleanup hook from an earlier font-preloading implementation. No-op until the
	-- surrounding boot effect is rewritten, so React unmount doesn't call nil.
	local destroyFontSamples = function()
		return nil
	end
	local onBootStatus = _param.onBootStatus
	local domainUi = _param.domainUi
	local appAlive = React.useRef(true)
	local requestWorkers = React.useRef({})
	local requestTimeouts = React.useRef({})
	local deferredJobs = React.useRef({})
	React.useEffect(function()
		return function()
			appAlive.current = false
			for worker in requestWorkers.current do
				pcall(function()
					return task.cancel(worker)
				end)
			end
			for timeout in requestTimeouts.current do
				pcall(function()
					return task.cancel(timeout)
				end)
			end
			for job in deferredJobs.current do
				pcall(function()
					return task.cancel(job)
				end)
			end
			table.clear(requestWorkers.current)
			table.clear(requestTimeouts.current)
			table.clear(deferredJobs.current)
		end
	end, {})
	local state = useClientSelector(function(client)
		return client.session
	end)
	local visit = useClientSelector(function(client)
		return client.visit
	end)
	local _exp = function()
		local _result = state
		if _result ~= nil then
			_result = _result.Settings.HighContrast
		end
		local _condition = _result
		if _condition == nil then
			_condition = 0
		end
		local _exp_1 = _condition >= 0.5
		local _result_1 = state
		if _result_1 ~= nil then
			_result_1 = _result_1.Settings.ColorblindMode
		end
		local _condition_1 = _result_1
		if _condition_1 == nil then
			_condition_1 = 0
		end
		applyAccessibilityTheme(_exp_1, _condition_1 >= 0.5)
	end
	local _result = state
	if _result ~= nil then
		_result = _result.Settings.ColorblindMode
	end
	local _result_1 = state
	if _result_1 ~= nil then
		_result_1 = _result_1.Settings.HighContrast
	end
	React.useEffect(_exp, { _result, _result_1 })
	local dispatchStore = useClientDispatch()
	local setVisit = React.useCallback(function(visitNext)
		return dispatchStore(ClientActions.setVisit(visitNext))
	end, { dispatchStore })
	local notices, setNotices = React.useState({})
	-- Radix's toast pattern pauses auto-dismiss while the pointer is over a toast — the
	-- dismiss timer below is scheduled once per notice, so this tracks which ones are
	-- currently hovered and the timer re-checks it instead of dismissing outright.
	local hoveredNotices = React.useRef({})
	local noticeTimers = React.useRef({})
	local noticesLive = React.useRef({})
	noticesLive.current = notices
	local setNoticeHovered = React.useCallback(function(id, hovered)
		if hovered then
			local _current = hoveredNotices.current
			local _id = id
			_current[_id] = true
		else
			local _current = hoveredNotices.current
			local _id = id
			_current[_id] = nil
		end
	end, {})
	local toastsSuppressed, setToastsSuppressed = React.useState(false)
	local purchasePresentationActive = React.useRef(false)
	local setPurchasePresentationActive = React.useCallback(function(active)
		purchasePresentationActive.current = active
	end, {})
	local confettiNonce, setConfettiNonce = React.useState(0)
	local celebrationSeed = React.useRef(math.random(1, 100000))
	local bootVisible, setBootVisible = React.useState(not externalBoot)
	local shellMounted, setShellMounted = React.useState(not externalBoot)
	local shellMountedRef = React.useRef(shellMounted)
	shellMountedRef.current = shellMounted
	local bootMarks, setBootMarks = React.useState({
		bridge = true,
		remotes = remotes.Request ~= nil and remotes.State ~= nil and remotes.Toast ~= nil and remotes.Effect ~= nil,
		state = false,
		audio = false,
		assets = false,
		fonts = false,
		modules = false,
		shell = false,
		mail = false,
		research = false,
		forge = false,
		trade = false,
		boosts = false,
		settings = false,
		mobile = false,
	})
	local assetProgress, setAssetProgress = React.useState({
		loaded = 0,
		total = 0,
	})
	local onBootExitDone = React.useCallback(function()
		return setBootVisible(false)
	end, {})
	local markBoot = React.useCallback(function(key)
		setBootMarks(function(current)
			local _result_2
			if current[key] then
				_result_2 = current
			else
				local _object = table.clone(current)
				setmetatable(_object, nil)
				_object[key] = true
				_result_2 = _object
			end
			return _result_2
		end)
	end, {})
	local bootReady = Boot.bootChecklistReady(bootMarks)
	local bootFill = Boot.bootProgress(bootMarks)
	local _result_2 = state
	if _result_2 ~= nil then
		_result_2 = _result_2.Settings.ReducedMotion
	end
	local bootReducedMotion = _result_2 == true
	React.useEffect(function()
		local assetShare = if assetProgress.total > 0 then math.clamp(assetProgress.loaded / assetProgress.total, 0, 1) elseif bootMarks.assets then 1 else 0
		local _result_3 = onBootStatus
		if _result_3 ~= nil then
			_result_3({
				marks = bootMarks,
				ready = bootReady,
				progress = bootFill * 0.55 + assetShare * 0.45,
				reducedMotion = bootReducedMotion,
				assetsLoaded = assetProgress.loaded,
				assetsTotal = assetProgress.total,
			})
		end
	end, { assetProgress.loaded, assetProgress.total, bootFill, bootMarks, bootReady, bootReducedMotion, onBootStatus })
	local adminPrank, setAdminPrank = React.useState()
	local pops, setPops = React.useState({})
	local popId = React.useRef(0)
	local comboReadout, setComboReadout = React.useState()
	local lastComboTier = React.useRef(0)
	local noticeId = React.useRef(0)
	local lastNotice = React.useRef({
		signature = "",
		at = 0,
	})
	local busy = React.useRef({})
	local inFlight = React.useRef({})
	local inFlightTotal = React.useRef(0)
	local requestSequence = React.useRef(0)
	local sentAt = React.useRef({})
	local latestSnapshot = React.useRef(-1)
	local latestRevision = React.useRef(-1)
	local lastTradeEpoch = React.useRef(-1)
	local lastSnapshotPaintAt = React.useRef(-math.huge)
	local loggedFirstSnapshot = React.useRef(false)
	local streakToastSent = React.useRef(false)
	local acceptState = React.useCallback(function(rawSnapshot)
		local _rawSnapshot = rawSnapshot
		if not (type(_rawSnapshot) == "table") then
			ClientLog:warnEvery("state-envelope", 10, "UI", "ignored a bad state packet")
			return false
		end
		local candidate = rawSnapshot
		local numericKeys = { "Revision", "SnapshotId", "ServerTime", "Cores", "Stardust", "Rebirths", "Zone", "CurrentZone" }
		local persistKeys = { "Cash", "Vault", "RunCash", "LifetimeCash", "Production", "Capacity" }
		local tableKeys = { "Game", "Machines", "Research", "Wheel", "Daily", "TimedRewards", "Quests", "Settings", "Flags" }
		local isFiniteNumber = function(value)
			local _value = value
			local _condition = type(_value) == "number"
			if _condition then
				_condition = value == value and value ~= math.huge and value ~= -math.huge
			end
			return _condition
		end
		local isPersist = function(value)
			if isFiniteNumber(value) then
				return value >= 0
			end
			local _value = value
			local _condition = not (type(_value) == "string")
			if not _condition then
				_condition = #value == 0
			end
			if _condition then
				return false
			end
			local lower = string.lower(value)
			if lower == "inf" or lower == "infinity" then
				return true
			end
			return (string.match(value, "^[%+%-]?%d+%.?%d*[eE][%+%-]?%d+$")) ~= nil or tonumber(value) ~= nil
		end
		-- ▼ ReadonlyArray.every ▼
		local _result_3 = true
		local _callback = function(key)
			return isFiniteNumber(candidate[key])
		end
		for _k, _v in numericKeys do
			if not _callback(_v, _k - 1, numericKeys) then
				_result_3 = false
				break
			end
		end
		-- ▲ ReadonlyArray.every ▲
		local validNumbers = _result_3
		-- ▼ ReadonlyArray.every ▼
		local _result_4 = true
		local _callback_1 = function(key)
			return isPersist(candidate[key])
		end
		for _k, _v in persistKeys do
			if not _callback_1(_v, _k - 1, persistKeys) then
				_result_4 = false
				break
			end
		end
		-- ▲ ReadonlyArray.every ▲
		local validPersist = _result_4
		-- ▼ ReadonlyArray.every ▼
		local _result_5 = true
		local _callback_2 = function(key)
			local _arg0 = candidate[key]
			return type(_arg0) == "table"
		end
		for _k, _v in tableKeys do
			if not _callback_2(_v, _k - 1, tableKeys) then
				_result_5 = false
				break
			end
		end
		-- ▲ ReadonlyArray.every ▲
		local validTables = _result_5
		if not validNumbers or not validPersist or not validTables or (candidate.Revision) < 0 or (candidate.SnapshotId) < 0 then
			ClientLog:warnEvery("state-envelope", 10, "UI", "ignored an incomplete snapshot")
			return false
		end
		local snapshot = rawSnapshot
		if snapshot.Revision < latestRevision.current then
			return true
		end
		if snapshot.Revision == latestRevision.current and snapshot.SnapshotId < latestSnapshot.current then
			return true
		end
		if snapshot.Revision > latestRevision.current then
			latestSnapshot.current = snapshot.SnapshotId
		else
			latestSnapshot.current = math.max(latestSnapshot.current, snapshot.SnapshotId)
		end
		local now = os.clock()
		local revisionChanged = snapshot.Revision > latestRevision.current
		local _result_6 = snapshot.Trade
		if _result_6 ~= nil then
			_result_6 = _result_6.Epoch
		end
		local _condition = _result_6
		if _condition == nil then
			_condition = -1
		end
		local tradeEpoch = _condition
		local tradeHot = tradeEpoch ~= lastTradeEpoch.current
		if tradeHot then
			lastTradeEpoch.current = tradeEpoch
		end
		local passivePaintInterval = if UserInputService.TouchEnabled then 0.7 else 0.45
		if pausePassivePaints.current and not revisionChanged and not tradeHot then
			return true
		end
		if latestRevision.current >= 0 and not revisionChanged and not tradeHot and now - lastSnapshotPaintAt.current < passivePaintInterval then
			return true
		end
		latestRevision.current = math.max(latestRevision.current, snapshot.Revision)
		lastSnapshotPaintAt.current = now
		dispatchStore(ClientActions.setSnapshot(snapshot))
		if not loggedFirstSnapshot.current then
			loggedFirstSnapshot.current = true
			ClientLog:once("profile-ready", "profile", `loaded world {snapshot.CurrentZone}`)
		end
		return true
	end, { dispatchStore })
	local dismissNotice = React.useCallback(function(id)
		setNotices(function(current)
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(notice)
				return notice.id ~= id
			end
			local _length = 0
			for _k, _v in current do
				if _callback(_v, _k - 1, current) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			return _newValue
		end)
	end, {})
	local _result_3 = state
	if _result_3 ~= nil then
		_result_3 = _result_3.Settings.ToastDensity
	end
	local _condition = _result_3
	if _condition == nil then
		_condition = 0.55
	end
	local toastDensityRef = React.useRef(_condition)
	local _result_4 = state
	if _result_4 ~= nil then
		_result_4 = _result_4.Settings.ToastDensity
	end
	local _condition_1 = _result_4
	if _condition_1 == nil then
		_condition_1 = 0.55
	end
	toastDensityRef.current = _condition_1
	local _result_5 = state
	if _result_5 ~= nil then
		_result_5 = _result_5.Settings.NotificationDuration
	end
	local _condition_2 = _result_5
	if _condition_2 == nil then
		_condition_2 = 0.55
	end
	local notificationDurationRef = React.useRef(_condition_2)
	local _result_6 = state
	if _result_6 ~= nil then
		_result_6 = _result_6.Settings.NotificationDuration
	end
	local _condition_3 = _result_6
	if _condition_3 == nil then
		_condition_3 = 0.55
	end
	notificationDurationRef.current = _condition_3
	local addNotice = React.useCallback(function(title, body, tone, playSound)
		if tone == nil then
			tone = "Info"
		end
		if playSound == nil then
			playSound = true
		end
		local _condition_4 = friendlyPlayerMessage(body)
		if _condition_4 == nil then
			_condition_4 = body
		end
		body = _condition_4
		local normalizedTitle = if title == "Boost online" then "Boost on" elseif title == "Rebirth" then "Rebirth done" elseif title == "Order paid" then "Claimed" elseif title == "Studio grant" then "Purchase test" else title
		local signature = `{normalizedTitle}|{body}|{tone}`
		local now = os.clock()
		if lastNotice.current.signature == signature and now - lastNotice.current.at < 0.55 then
			return nil
		end
		lastNotice.current = {
			signature = signature,
			at = now,
		}
		local lifetime = 2.8 + notificationDurationRef.current * 4.4
		local maxNotices = math.clamp(math.floor(2 + toastDensityRef.current * 3 + 0.5), 2, 5)
		local _exp_1 = noticesLive.current
		-- ▼ ReadonlyArray.find ▼
		local _callback = function(notice)
			return notice.leaving ~= true and notice.title == normalizedTitle and notice.body == body
		end
		local _result_7
		for _i, _v in _exp_1 do
			if _callback(_v, _i - 1, _exp_1) == true then
				_result_7 = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local matching = _result_7
		local dismissId = if matching ~= nil then matching.id else noticeId.current + 1
		if matching == nil then
			noticeId.current = dismissId
		end
		local priorTimer = noticeTimers.current[dismissId]
		if priorTimer ~= nil then
			pcall(function()
				return task.cancel(priorTimer)
			end)
			deferredJobs.current[priorTimer] = nil
			noticeTimers.current[dismissId] = nil
		end
		setNotices(function(current)
			local _array = {}
			local _length = #_array
			table.move(current, 1, #current, _length + 1, _array)
			local updated = _array
			-- ▼ ReadonlyArray.findIndex ▼
			local _callback_1 = function(notice)
				return notice.id == dismissId and notice.leaving ~= true
			end
			local _result_8 = -1
			for _i, _v in updated do
				if _callback_1(_v, _i - 1, updated) == true then
					_result_8 = _i - 1
					break
				end
			end
			-- ▲ ReadonlyArray.findIndex ▲
			local index = _result_8
			if index >= 0 then
				local existing = updated[index + 1]
				local _object = table.clone(existing)
				setmetatable(_object, nil)
				_object.body = body
				_object.tone = tone
				_object.lifetime = lifetime
				_object.sound = false
				local _left = "count"
				local _condition_5 = existing.count
				if _condition_5 == nil then
					_condition_5 = 1
				end
				_object[_left] = _condition_5 + 1
				updated[index + 1] = _object
			else
				local _arg0 = {
					id = dismissId,
					title = normalizedTitle,
					body = body,
					tone = tone,
					lifetime = lifetime,
					sound = playSound,
					count = 1,
				}
				table.insert(updated, _arg0)
			end
			while #updated > maxNotices do
				-- ▼ ReadonlyArray.find ▼
				local _callback_2 = function(notice)
					return notice.leaving ~= true and notice.id ~= dismissId
				end
				local _result_9
				for _i, _v in updated do
					if _callback_2(_v, _i - 1, updated) == true then
						_result_9 = _v
						break
					end
				end
				-- ▲ ReadonlyArray.find ▲
				local _condition_5 = _result_9
				if _condition_5 == nil then
					_condition_5 = updated[1]
				end
				local oldest = _condition_5
				if oldest == nil then
					break
				end
				local _current = noticeTimers.current
				local _id = oldest.id
				local oldTimer = _current[_id]
				if oldTimer ~= nil then
					pcall(function()
						return task.cancel(oldTimer)
					end)
					deferredJobs.current[oldTimer] = nil
					local _current_1 = noticeTimers.current
					local _id_1 = oldest.id
					_current_1[_id_1] = nil
				end
				local _arg0 = (table.find(updated, oldest) or 0) - 1
				table.remove(updated, _arg0 + 1)
			end
			return updated
		end)
		local tryDismiss
		tryDismiss = function()
			local job = noticeTimers.current[dismissId]
			if job ~= nil then
				deferredJobs.current[job] = nil
			end
			noticeTimers.current[dismissId] = nil
			if not appAlive.current then
				return nil
			end
			if hoveredNotices.current[dismissId] ~= nil then
				local wait = task.delay(0.45, tryDismiss)
				noticeTimers.current[dismissId] = wait
				deferredJobs.current[wait] = true
				return nil
			end
			dismissNotice(dismissId)
		end
		local job = task.delay(lifetime, tryDismiss)
		noticeTimers.current[dismissId] = job
		deferredJobs.current[job] = true
	end, { dismissNotice })
	local celebrate = React.useCallback(function()
		celebrationSeed.current += math.random(1, 3)
		setConfettiNonce(celebrationSeed.current)
	end, {})
	local clearConfetti = React.useCallback(function(expectedSeed)
		setConfettiNonce(function(current)
			return if expectedSeed == nil or current == expectedSeed then 0 else current
		end)
	end, {})
	local addPop = React.useCallback(function(text, color, critical)
		local id = popId.current + 1
		popId.current = id
		setPops(function(current)
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			_array[_length + 1] = {
				id = id,
				text = text,
				color = color,
				critical = critical,
				offset = math.random(-90, 90),
			}
			local updated = _array
			while #updated > 12 do
				table.remove(updated, 1)
			end
			return updated
		end)
		local job
		job = task.delay(POP_SECONDS, function()
			local _current = deferredJobs.current
			local _job = job
			_current[_job] = nil
			if appAlive.current then
				setPops(function(current)
					local found = false
					for _, pop in current do
						if pop.id == id then
							found = true
							break
						end
					end
					if not found then
						return current
					end
					local _newValue = {}
					for _, pop in current do
						if pop.id ~= id then
							table.insert(_newValue, pop)
						end
					end
					return _newValue
				end)
			end
		end)
		local _current = deferredJobs.current
		local _job = job
		_current[_job] = true
	end, {})
	-- Cosmetic-only combo mirror: `combo`/`comboMultiplier` here are never computed
	-- client-side, only copied from whichever server payload just arrived (per-tap
	-- effect/RemoteFunction data, or the decay-aware snapshot as a resync fallback).
	local applyComboReadout = React.useCallback(function(combo, comboMultiplier, comboMax, comboWindow)
		if combo <= 0 then
			return nil
		end
		setComboReadout({
			combo = combo,
			comboMultiplier = comboMultiplier,
			comboMax = comboMax,
			comboWindow = comboWindow,
			updatedAt = os.clock(),
		})
	end, {})
	local _exp_1 = function(response, action, callback)
		local _action = action
		if GRANT_ACTIONS[_action] ~= nil then
			adopt(response)
		end
		local rawError = response.error
		response = friendlyActionResponse(response)
		if response.State then
			acceptState(response.State)
		end
		if action == "LeaveGuild" and response.ok then
			dispatchStore(ClientActions.patchSession({
				Guild = nil,
				GuildBonuses = {
					Production = 0,
					Capacity = 0,
					Offline = 0,
					Automation = 0,
					Tap = 0,
				},
			}))
		elseif response.Guild ~= nil then
			local guild = response.Guild
			dispatchStore(ClientActions.patchSession({
				Guild = if guild.Id == "" then nil else guild,
			}))
		end
		local _result_7 = callback
		if _result_7 ~= nil then
			_result_7(response)
		end
		if not response.ok then
			local _condition_4 = response.error
			if _condition_4 == nil then
				_condition_4 = "Try again in a moment."
			end
			local detail = _condition_4
			local _condition_5 = rawError
			if _condition_5 == nil then
				_condition_5 = detail
			end
			local lowered = string.lower(_condition_5)
			local expectedBusy = (action == "Overcharge" and (string.find(lowered, "cooling", 1, true)) ~= nil) or (string.find(lowered, "still working", 1, true)) ~= nil or (string.find(lowered, "slow down", 1, true)) ~= nil
			if expectedBusy then
				return nil
			end
			-- Log the server's raw error, not the player-friendly rewrite -- friendlyActionResponse
			-- already overwrote response.error above, so logging that instead of rawError meant
			-- the dev console showed the SAME friendly copy the player saw in the toast, with no
			-- way to tell what the server actually rejected without cross-referencing server logs.
			local _exp_2 = action
			local _condition_6 = rawError
			if _condition_6 == nil then
				_condition_6 = detail
			end
			ClientLog:warn("action", `{_exp_2} failed — {_condition_6}`)
			if AppHelpers:isPassiveRequest(action) then
				return nil
			end
			local gated = (string.find(string.lower(detail), "unlock", 1, true)) ~= nil
			local _exp_3 = failureTitle(action, gated)
			local _exp_4 = action
			local _condition_7 = rawError
			if _condition_7 == nil then
				_condition_7 = detail
			end
			addNotice(_exp_3, failureBody(_exp_4, _condition_7), "Info", false)
			return nil
		end
		local machinePurchase = action == "BuyMachine"
		local progressionPurchase = action == "BuyResearch" or action == "BuyGridUpgrade" or action == "BuyAnomalyProtocol" or action == "UpgradeContinuum" or action == "UpgradeArtifact" or action == "UpgradeCrew" or action == "BuyGuildUpgrade" or action == "UpgradeItem"
		local purchase = machinePurchase or progressionPurchase or action == "BuySignalOffer" or action == "BuyItemOffer"
		local reward = action == "ClaimDaily" or action == "ClaimTimedReward" or action == "ClaimQuest" or action == "ClaimAchievement" or action == "ClaimLabOrder" or action == "ClaimCommanderReward" or action == "ClaimWeeklyDirective" or action == "ClaimSeasonTier" or action == "ClaimExpedition" or action == "ClaimConvergenceReward" or action == "ClaimAnomalyDirective" or action == "ClaimAnomalyMilestone" or action == "ClaimForgePathStep"
		if purchase then
			Audio:play(if machinePurchase then "machineInstall" elseif progressionPurchase then "researchUnlock" else "purchase")
			if action == "BuySignalOffer" or action == "BuyItemOffer" then
				local _condition_4 = response.message
				if _condition_4 == nil then
					_condition_4 = "Purchase complete."
				end
				addNotice("Bought", _condition_4, "Success")
			elseif machinePurchase then
				local _condition_4 = response.message
				if _condition_4 == nil then
					_condition_4 = "Station tuned."
				end
				addNotice("Upgraded", _condition_4, "Success", false)
			elseif progressionPurchase then
				local _condition_4 = response.message
				if _condition_4 == nil then
					_condition_4 = "Level increased."
				end
				addNotice("Upgraded", _condition_4, "Success", false)
			end
		elseif reward then
			local _condition_4 = action == "ClaimForgePathStep"
			if _condition_4 then
				local _result_8 = response.State
				if _result_8 ~= nil then
					_result_8 = _result_8.ForgePath
				end
				_condition_4 = _result_8 ~= nil
				if _condition_4 then
					local _exp_2 = response.State.ForgePath.ClaimedSteps
					-- ▼ ReadonlyArray.reduce ▼
					local _result_9 = 0
					local _callback = function(max, step)
						return math.max(max, step)
					end
					for _i = 1, #_exp_2 do
						_result_9 = _callback(_result_9, _exp_2[_i], _i - 1, _exp_2)
					end
					-- ▲ ReadonlyArray.reduce ▲
					_condition_4 = _result_9 % 5 == 0
				end
			end
			local forgePathMajorStep = _condition_4
			if forgePathMajorStep then
				Audio:playCelebration({ "researchUnlock", "discovery", "reward" }, 0.08)
			else
				Audio:play(if action == "ClaimDaily" then "dailyClaim" elseif action == "ClaimTimedReward" then "timedClaim" elseif action == "ClaimAchievement" then "achievementClaim" elseif action == "ClaimSeasonTier" or action == "ClaimConvergenceReward" then "seasonClaim" elseif action == "ClaimExpedition" then "expeditionReturn" elseif action == "ClaimForgePathStep" then "researchUnlock" else "missionClaim")
			end
			InteractionFeedback.reward()
			celebrate()
		elseif action == "ContributeGuild" then
			Audio:play("guildDeposit")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Contribution deposited."
			end
			addNotice("Guild bank", _condition_4, "Success")
		elseif action == "CreateGuild" then
			Audio:play("guildCreate")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Your hall is open."
			end
			addNotice("Guild chartered", _condition_4, "Special")
		elseif action == "JoinGuild" then
			Audio:play("guildJoin")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "You're in."
			end
			addNotice("Guild", _condition_4, "Success")
		elseif action == "LeaveGuild" then
			Audio:play("guildLeave")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Left the guild."
			end
			addNotice("Guild", _condition_4, "Info")
		elseif action == "DisbandGuild" then
			Audio:play("guildLeave")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "The guild is gone."
			end
			addNotice("Guild disbanded", _condition_4, "Info")
		elseif action == "KickGuildMember" then
			Audio:play("memberRemove")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "They're out of the guild."
			end
			addNotice("Crew removed", _condition_4, "Info")
		elseif action == "SetGuildRole" then
			Audio:play("roleChange")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Role changed."
			end
			addNotice("Role updated", _condition_4, "Success")
		elseif action == "SalvageItem" then
			Audio:play("salvage")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Dust recovered."
			end
			addNotice("Salvaged", _condition_4, "Success")
		elseif action == "CaptureEcho" then
			Audio:play("echoCapture")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Got three echoes."
			end
			addNotice("Pattern captured", _condition_4, "Special")
		elseif action == "ClaimEcho" then
			Audio:play("echoClaim")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "EquipEcho" then
			Audio:play("echoEquip")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Loadout updated."
			end
			addNotice("Echo linked", _condition_4, "Info")
		elseif action == "UpgradeEcho" then
			Audio:play("echoTune")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "It's stronger now."
			end
			addNotice("Echo tuned", _condition_4, "Success")
		elseif action == "DismantleEcho" then
			Audio:play("echoDismantle")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Resonance recovered."
			end
			addNotice("Memory released", _condition_4, "Info")
		elseif action == "LaunchExpedition" then
			Audio:play("expeditionLaunch")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "They're out."
			end
			addNotice("Expedition", _condition_4, "Success")
		elseif action == "EquipArtifact" then
			Audio:play("itemLink")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Loadout updated."
			end
			addNotice("Equipped", _condition_4, "Info")
		elseif action == "EquipTitle" then
			Audio:play("itemLink")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Title updated."
			end
			addNotice("Title equipped", _condition_4, "Success", false)
		elseif action == "ClaimStoryChapter" then
			Audio:play("unlock")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "ClaimMail" or action == "ClaimAllMail" then
			Audio:play("mailClaim")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "RedeemCode" then
			Audio:play("codeReward")
			InteractionFeedback.reward()
			celebrate()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Reward claimed."
			end
			addNotice("Code claimed", _condition_4, "Special")
		elseif action == "VerifyCreatorFollow" then
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = ""
			end
			local already = (string.find(string.lower(_condition_4), "already", 1, true)) ~= nil
			if not already then
				Audio:play("codeReward")
				InteractionFeedback.reward()
				celebrate()
			end
			local _condition_5 = response.message
			if _condition_5 == nil then
				_condition_5 = "Thanks for following."
			end
			addNotice("Follow reward", _condition_5, if already then "Info" else "Special")
		elseif action == "StudioGrantProduct" then
			Audio:play("purchase")
		elseif action == "AdminExecute" then
			Audio:play("confirm")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Done."
			end
			addNotice("Change applied", _condition_4, "Success")
		elseif action == "InviteTrade" then
			Audio:play("invite")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Invite sent."
			end
			addNotice("Trade invite", _condition_4, "Info")
		elseif action == "RespondTrade" then
			Audio:play("confirm")
		elseif action == "ConfirmTrade" then
			Audio:play("purchase")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Trade finished."
			end
			addNotice("Trade", _condition_4, "Success")
		elseif action == "CancelTrade" then
			Audio:play("close")
		elseif action == "SpinWheel" then
		elseif action == "OpenItemCrate" then
			local _result_8 = response.Rolls
			if _result_8 ~= nil then
				_result_8 = #_result_8
			end
			local _condition_4 = _result_8
			if _condition_4 == nil then
				_condition_4 = 0
			end
			if _condition_4 == 0 then
				celebrate()
			end
		elseif action == "RouteLabPower" then
			Audio:play("labRoute")
		elseif action == "SetAutoForge" then
			Audio:play("autoForge")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Auto-forge set."
			end
			addNotice("Auto-Forge", _condition_4, "Info")
		elseif action == "SetAnomalyChannel" then
			Audio:play("toggleOn")
		elseif action == "ActivateAnomalySurge" then
			Audio:play("reactorSurge")
		elseif action == "DeleteMail" then
			Audio:play("close")
		elseif action == "DomainExpansion" then
			Audio:play("domainImpact")
			local rewardJob
			rewardJob = task.delay(0.2, function()
				deferredJobs.current[rewardJob] = nil
				if appAlive.current then
					Audio:playCelebration({ "domainReward", "discovery" }, 0.1)
				end
			end)
			deferredJobs.current[rewardJob] = true
			InteractionFeedback.reward()
			celebrate()
		elseif action == "Rebirth" then
			Audio:play("rebirthCharge")
			local bloomJob
			bloomJob = task.delay(0.18, function()
				deferredJobs.current[bloomJob] = nil
				if appAlive.current then
					Audio:playCelebration({ "prestige", "rebirthBloom", "discovery" }, 0.09)
				end
			end)
			deferredJobs.current[bloomJob] = true
			InteractionFeedback.reward()
			celebrate()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "The forge starts over, stronger."
			end
			addNotice("Rebirth done", _condition_4, "Special")
		elseif action == "SetSetting" then
			if response.message ~= nil and response.message ~= "Setting updated." then
				addNotice("Preset on", response.message, "Success")
			end
		elseif action == "SetMobileLayout" then
		elseif action == "ActivateBoost" then
			Audio:play("boostActivate")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Timer started."
			end
			addNotice("Boost on", _condition_4, "Success")
		elseif action == "UnlockZone" then
			Audio:play("zoneUnlock")
			InteractionFeedback.reward()
			celebrate()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "A new world is open."
			end
			addNotice("World unlocked", _condition_4, "Special", false)
		elseif action == "NudgeCrew" then
			Audio:play("crewNudge")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "They’ll see it."
			end
			addNotice("Waved", _condition_4, "Info")
		elseif action == "VisitPlot" then
			Audio:play("travel")
			if response.Visit then
				setVisit(response.Visit)
			end
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "You're in their shop."
			end
			addNotice("Visiting", _condition_4, "Info")
		elseif action == "LeavePlot" then
			Audio:play("close")
			setVisit(nil)
		elseif action == "SelectZone" then
			Audio:play("zoneSelect")
		elseif action == "EquipItem" then
			Audio:play("itemLink")
		elseif action == "UnequipItem" then
			Audio:play("itemUnlink")
		elseif action == "EquipBestItems" then
			Audio:play("itemLink")
			InteractionFeedback.tap()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Best relics equipped."
			end
			addNotice("Loadout optimized", _condition_4, "Success", false)
		elseif action == "BulkSalvageItems" then
			Audio:play("salvage")
			InteractionFeedback.tap()
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Relics broken down."
			end
			addNotice("Salvaged", _condition_4, "Success", false)
		elseif action == "ToggleItemLock" then
			Audio:play("toggleOn")
			local _condition_4 = response.message
			if _condition_4 == nil then
				_condition_4 = "Lock updated."
			end
			addNotice("Relic", _condition_4, "Info", false)
		elseif action == "StabilizeAnomaly" then
			Audio:play("reactorStabilize")
			InteractionFeedback.reward()
			celebrate()
		elseif action == "CompleteTutorial" then
			InteractionFeedback.reward()
			celebrate()
		elseif action == "CollectVault" then
			Audio:play("vaultDeposit")
			InteractionFeedback.reward()
			InteractionFeedback.confirm()
			celebrate()
		elseif action == "Overcharge" then
			if response.Combo ~= nil and response.ComboMultiplier ~= nil then
				local _exp_2 = response.Combo
				local _exp_3 = response.ComboMultiplier
				local _condition_4 = response.ComboMax
				if _condition_4 == nil then
					_condition_4 = 12
				end
				local _condition_5 = response.ComboWindow
				if _condition_5 == nil then
					_condition_5 = 1.8
				end
				applyComboReadout(_exp_2, _exp_3, _condition_4, _condition_5)
			end
		elseif action == "PulseAnomaly" then
			Audio:play("reactorPulse")
		elseif action == "ClaimAnomalyDirective" or action == "ClaimAnomalyMilestone" then
			Audio:play("collect")
			InteractionFeedback.reward()
		elseif response.message ~= nil and action ~= "Overcharge" and action ~= "ActivateBoost" and action ~= "RouteLabPower" and action ~= "SetTutorialStep" and action ~= "ReplayTutorial" and action ~= "DismissRelease" and action ~= "OpenRelease" and action ~= "ReadStoryChapter" and action ~= "ReadMail" and action ~= "SetSetting" and action ~= "SetMobileLayout" and action ~= "VisitPlot" and action ~= "LeavePlot" and action ~= "SyncShop" and action ~= "GetPlayers" and action ~= "GetLeaderboard" and action ~= "GetGuildLeaderboard" and action ~= "GetTrade" and action ~= "UpdateTradeOffer" and action ~= "SetTradeReady" and action ~= "VerifyCreatorFollow" and action ~= "RedeemCode" then
			addNotice("Done", response.message, "Info")
		end
	end
	local _result_7 = state
	if _result_7 ~= nil then
		_result_7 = _result_7.Settings.ReducedMotion
	end
	local applyResponse = React.useCallback(_exp_1, { acceptState, addNotice, applyComboReadout, celebrate, dispatchStore, setVisit, _result_7 })
	local dispatch
	dispatch = React.useCallback(function(action, payload, callback)
		if payload == nil then
			payload = {}
		end
		local _payload = payload
		local value = if type(_payload) == "table" then payload else {}
		local signature = AppHelpers:actionSignature(action, value)
		local pipelined = NetworkPolicy.IsPipelined(action)
		local reject = function(message)
			local _result_8 = callback
			if _result_8 ~= nil then
				_result_8({
					ok = false,
					error = message,
				})
			end
		end
		local _action_1 = action
		if GRANT_ACTIONS[_action_1] ~= nil then
			if not isAuthed() then
				whenAuthed(function()
					return dispatch(action, payload, callback)
				end)
				return nil
			end
			attachGrantFields(value)
		end
		if not pipelined and busy.current[signature] ~= nil then
			reject("Already working on that.")
			return nil
		end
		local _condition_4 = inFlight.current[signature]
		if _condition_4 == nil then
			_condition_4 = 0
		end
		local activeRequests = _condition_4
		local requestLimit = NetworkPolicy.RequestLimit(pipelined)
		if activeRequests >= requestLimit then
			reject("Still working on your last tap.")
			return nil
		end
		if inFlightTotal.current >= NetworkPolicy.MAX_PHYSICAL_REQUESTS then
			reject("The connection is busy. Try again in a moment.")
			return nil
		end
		local now = os.clock()
		local cooldown = NetworkPolicy.Cooldown(action)
		local previous = sentAt.current[signature]
		if previous ~= nil and NetworkPolicy.IsCoolingDown(now, previous, cooldown) then
			reject("Slow down a sec.")
			return nil
		end
		sentAt.current[signature] = now
		-- ▼ ReadonlyMap.size ▼
		local _size = 0
		for _ in sentAt.current do
			_size += 1
		end
		-- ▲ ReadonlyMap.size ▲
		if _size > 256 then
			for key, timestamp in sentAt.current do
				if now - timestamp > 60 then
					sentAt.current[key] = nil
				end
			end
		end
		-- ▼ ReadonlyMap.size ▼
		local _size_1 = 0
		for _ in sentAt.current do
			_size_1 += 1
		end
		-- ▲ ReadonlyMap.size ▲
		if _size_1 > 384 then
			for key in sentAt.current do
				sentAt.current[key] = nil
				-- ▼ ReadonlyMap.size ▼
				local _size_2 = 0
				for _ in sentAt.current do
					_size_2 += 1
				end
				-- ▲ ReadonlyMap.size ▲
				if _size_2 <= 256 then
					break
				end
			end
		end
		if NetworkPolicy.IsOptimistic(action) then
			dispatchStore(ClientActions.applyOptimistic(action, value, config.Game.Version))
		end
		if action == "Overcharge" or action == "PulseAnomaly" then
			Audio:play("reactorPulse")
		elseif action == "CollectVault" then
			Audio:play("vaultBank")
		end
		local requestToken = requestSequence.current + 1
		requestSequence.current = requestToken
		local _current = inFlight.current
		local _arg1 = activeRequests + 1
		_current[signature] = _arg1
		inFlightTotal.current += 1
		if not pipelined then
			busy.current[signature] = requestToken
		end
		local requestTimedOut = false
		local requestReleased = false
		local releaseRequest = function()
			if requestReleased then
				return nil
			end
			requestReleased = true
			local _condition_6 = inFlight.current[signature]
			if _condition_6 == nil then
				_condition_6 = 1
			end
			local remaining = _condition_6 - 1
			if remaining > 0 then
				inFlight.current[signature] = remaining
			else
				inFlight.current[signature] = nil
			end
			inFlightTotal.current = math.max(0, inFlightTotal.current - 1)
		end
		local requestTimeout
		local requestWorker
		local timeoutSeconds = NetworkPolicy.Timeout(action)
		requestTimeout = task.delay(timeoutSeconds, function()
			if requestTimeout ~= nil then
				local _current_1 = requestTimeouts.current
				local _requestTimeout = requestTimeout
				_current_1[_requestTimeout] = nil
			end
			requestTimeout = nil
			local ownsControl = pipelined or busy.current[signature] == requestToken
			if not pipelined and ownsControl then
				busy.current[signature] = nil
			end
			requestTimedOut = true
			if requestWorker ~= nil then
				local _current_1 = requestWorkers.current
				local _requestWorker = requestWorker
				_current_1[_requestWorker] = nil
				pcall(function()
					return task.cancel(requestWorker)
				end)
				requestWorker = nil
			end
			releaseRequest()
			if not appAlive.current or not ownsControl then
				return nil
			end
			ClientLog:warnEvery(`timeout:{action}`, 8, "UI", `{action} timed out after {timeoutSeconds}s`)
			addNotice("Connection hiccup", "That action timed out. You can try it again now.", "Info", false)
			reject("That took too long. Try again.")
		end)
		local _current_1 = requestTimeouts.current
		local _requestTimeout = requestTimeout
		_current_1[_requestTimeout] = true
		requestWorker = task.defer(function()
			local ok, raw = pcall(function()
				return remotes.Request:InvokeServer(action, value)
			end)
			if requestWorker ~= nil then
				local _current_2 = requestWorkers.current
				local _requestWorker = requestWorker
				_current_2[_requestWorker] = nil
			end
			requestWorker = nil
			if requestTimeout ~= nil then
				task.cancel(requestTimeout)
				local _current_2 = requestTimeouts.current
				local _requestTimeout_1 = requestTimeout
				_current_2[_requestTimeout_1] = nil
				requestTimeout = nil
			end
			if not pipelined and busy.current[signature] == requestToken then
				busy.current[signature] = nil
			end
			releaseRequest()
			if not appAlive.current then
				return nil
			end
			if requestTimedOut then
				return nil
			end
			local _condition_7 = not ok or not (type(raw) == "table")
			if not _condition_7 then
				local _ok = raw.ok
				_condition_7 = not (type(_ok) == "boolean")
			end
			if _condition_7 then
				ClientLog:warnEvery(`request:{action}`, 5, "UI", `{action} got no answer`)
				addNotice("Connection hiccup", "That tap didn't go through. Try again.", "Info", false)
				reject("That tap didn't go through. Try again.")
				return nil
			end
			applyResponse(raw, action, callback)
		end)
		local _current_2 = requestWorkers.current
		local _requestWorker = requestWorker
		_current_2[_requestWorker] = true
	end, { addNotice, applyResponse, config.Game.Version, dispatchStore, remotes })
	useClientIntegrityProbe(dispatch)
	local _exp_2 = function()
		if state == nil or streakToastSent.current then
			return nil
		end
		if state.Daily.CanClaim == true and state.Daily.Streak >= 1 then
			streakToastSent.current = true
			local day = state.Daily.Streak
			addNotice("Daily streak", if day > 1 then `Day {day} is ready — claim it in Rewards.` else "Today’s daily is ready in Rewards.", "Special")
		end
		-- `state` is recreated on every tick (production, cash, etc.); keying off it
		-- here would re-run this effect continuously for no benefit since the actual
		-- trigger is the daily-streak flag, which changes far less often.
	end
	local _result_8 = state
	if _result_8 ~= nil then
		_result_8 = _result_8.Daily.CanClaim
	end
	local _result_9 = state
	if _result_9 ~= nil then
		_result_9 = _result_9.Daily.Streak
	end
	React.useEffect(_exp_2, { addNotice, _result_8, _result_9 })
	-- Resync-only fallback: the state snapshot's `Overcharge` block already has the
	-- server's window-decay applied at read time, so on first sight of a live combo
	-- (e.g. right after a reconnect, before any fresh per-tap data has arrived) it's
	-- safe to adopt directly. Per-tap effect/RemoteFunction data always wins once it
	-- starts arriving, since it is strictly fresher than a coalesced snapshot.
	local _exp_3 = function()
		local _snapshotCombo = state
		if _snapshotCombo ~= nil then
			_snapshotCombo = _snapshotCombo.Overcharge
		end
		local snapshotCombo = _snapshotCombo
		if snapshotCombo == nil or snapshotCombo.Combo <= 0 or comboReadout ~= nil then
			return nil
		end
		setComboReadout({
			combo = snapshotCombo.Combo,
			comboMultiplier = snapshotCombo.ComboMultiplier,
			comboMax = snapshotCombo.ComboMax,
			comboWindow = snapshotCombo.ComboWindow,
			updatedAt = os.clock(),
		})
	end
	local _result_10 = state
	if _result_10 ~= nil then
		_result_10 = _result_10.Overcharge
	end
	React.useEffect(_exp_3, { comboReadout, _result_10 })
	React.useEffect(function()
		local alive = true
		local fontWorker
		local fontTimeout
		local moduleWorker
		local stateWorker
		local cancelWorker = function(worker)
			if worker ~= nil then
				pcall(function()
					return task.cancel(worker)
				end)
			end
		end
		local stateConnection = remotes.State.OnClientEvent:Connect(function(snapshot)
			local _condition_4 = not alive
			if not _condition_4 then
				local _snapshot = snapshot
				_condition_4 = not (type(_snapshot) == "table")
			end
			if _condition_4 then
				return nil
			end
			if not acceptState(snapshot) then
				return nil
			end
			markBoot("bridge")
			markBoot("state")
		end)
		local toastConnection = remotes.Toast.OnClientEvent:Connect(function(payload)
			local _condition_4 = not alive
			if not _condition_4 then
				local _payload = payload
				_condition_4 = not (type(_payload) == "table")
			end
			if _condition_4 then
				return nil
			end
			local value = payload
			local tone = (value.Tone) or "Info"
			local _condition_5 = value.Title
			if _condition_5 == nil then
				_condition_5 = "Update"
			end
			local _exp_4 = tostring(_condition_5)
			local _condition_6 = value.Body
			if _condition_6 == nil then
				_condition_6 = "Something changed."
			end
			addNotice(_exp_4, tostring(_condition_6), tone)
		end)
		local effectConnection = remotes.Effect.OnClientEvent:Connect(function(payload)
			local _condition_4 = not alive
			if not _condition_4 then
				local _payload = payload
				_condition_4 = not (type(_payload) == "table")
			end
			if _condition_4 then
				return nil
			end
			local value = payload
			local _condition_5 = value.Type
			if _condition_5 == nil then
				_condition_5 = ""
			end
			local kind = tostring(_condition_5)
			local _amount = value.Amount
			local amount = if type(_amount) == "number" then value.Amount else 0
			if kind == "Collect" and amount > 0 then
				addPop(`+{compactNumber(amount)}`, Palette.green, false)
			elseif kind == "Overcharge" and amount > 0 then
				addPop(`+{compactNumber(amount)}`, if value.Critical == true then Palette.mango else Palette.cyan, value.Critical == true)
				local _combo = value.Combo
				local combo = if type(_combo) == "number" then value.Combo else nil
				local _comboMultiplier = value.ComboMultiplier
				local comboMultiplier = if type(_comboMultiplier) == "number" then value.ComboMultiplier else nil
				if combo ~= nil and comboMultiplier ~= nil then
					local _comboMax = value.ComboMax
					local comboMax = if type(_comboMax) == "number" then value.ComboMax else 12
					local _comboWindow = value.ComboWindow
					applyComboReadout(combo, comboMultiplier, comboMax, if type(_comboWindow) == "number" then value.ComboWindow else 1.8)
					if combo <= 1 then
						lastComboTier.current = 0
					end
					local tier = math.floor((combo / math.max(1, comboMax)) * 4)
					if tier > lastComboTier.current and combo < comboMax then
						Audio:play("tick")
					elseif combo >= comboMax and lastComboTier.current < 4 then
						Audio:play("unlock")
					end
					lastComboTier.current = if combo >= comboMax then 4 else tier
				end
			elseif kind == "FeatureUnlocked" and not purchasePresentationActive.current then
				Audio:play("unlock")
				InteractionFeedback.reward()
				celebrate()
			elseif kind == "AnomalyPulse" then
				Audio:play("reactor")
			elseif kind == "AnomalyReady" then
				Audio:play("reactorReady")
			elseif kind == "AnomalyStabilized" then
				Audio:play("discovery")
			elseif kind == "ItemLinked" then
				Audio:play("equip")
			else
				local _condition_6 = kind == "VisitUpdate"
				if _condition_6 then
					local _visit = value.Visit
					_condition_6 = type(_visit) == "table"
				end
				if _condition_6 then
					setVisit(value.Visit)
				elseif kind == "VisitEnded" then
					setVisit(nil)
				elseif kind == "CrewNudge" then
					Audio:play("crewNudge")
					InteractionFeedback.tap()
					local _condition_7 = value.FromName
					if _condition_7 == nil then
						_condition_7 = "Someone"
					end
					local from = tostring(_condition_7)
					addNotice("Crew nudge", `{from} waved at you.`, "Special")
				elseif kind == "DomainExpansion" and tonumber(value.UserId) ~= Players.LocalPlayer.UserId then
					Audio:play("domainImpact")
					local _condition_7 = tonumber(value.Rank)
					if _condition_7 == nil then
						_condition_7 = 1
					end
					addNotice("Domain nearby", `Someone opened Domain {math.floor(_condition_7)}.`, "Special")
				elseif kind == "AdminPrank" then
					local _condition_7 = value.Kind
					if _condition_7 == nil then
						_condition_7 = "Jumpscare"
					end
					local prankKind = tostring(_condition_7)
					local _condition_8 = tonumber(value.Duration)
					if _condition_8 == nil then
						_condition_8 = 6
					end
					local duration = math.clamp(_condition_8, 2, 20)
					local _condition_9 = value.Caption
					if _condition_9 == nil then
						_condition_9 = ""
					end
					local caption = tostring(_condition_9)
					setAdminPrank({
						kind = prankKind,
						endsAt = os.clock() + duration,
						caption = caption,
					})
					Audio:play("adminExecute")
				end
			end
		end)
		markBoot("remotes")
		Audio:start()
		Audio:whenWarm(function()
			if alive then
				markBoot("audio")
			end
		end)
		local fontFaces = { Font.fromEnum(Enum.Font.BuilderSans), Font.fromEnum(Enum.Font.BuilderSansMedium), Font.fromEnum(Enum.Font.BuilderSansBold), Font.fromEnum(Enum.Font.BuilderSansExtraBold), Font.fromEnum(Enum.Font.RobotoMono), Font.fromEnum(Enum.Font.Code), Font.new("rbxasset://fonts/families/GothamSSm.json") }
		local fontFinished = false
		fontWorker = task.spawn(function()
			pcall(function()
				return ContentProvider:PreloadAsync(fontFaces)
			end)
			if fontFinished then
				return nil
			end
			fontFinished = true
			if alive then
				markBoot("fonts")
			end
		end)
		fontTimeout = task.delay(6, function()
			if fontFinished then
				return nil
			end
			fontFinished = true
			cancelWorker(fontWorker)
			fontWorker = nil
			destroyFontSamples()
			if alive then
				markBoot("fonts")
			end
		end)
		moduleWorker = task.spawn(function()
			local deadline = os.clock() + Boot.BOOT_MODULE_TIMEOUT
			local waitChild = function(parent, name, budget)
				local left = math.max(0.05, deadline - os.clock())
				return parent:WaitForChild(name, math.min(budget, left))
			end
			pcall(function()
				local astral = waitChild(ReplicatedStorage, "AstralForge", 4)
				if astral ~= nil then
					waitChild(astral, "Shared", 3)
					local shared = astral:FindFirstChild("Shared")
					if shared ~= nil then
						local spinner = waitChild(shared, "NumberSpinner", 3)
						if spinner ~= nil and spinner:IsA("ModuleScript") then
							pcall(function()
								return require(spinner)
							end)
						end
					end
					local vendor = astral:FindFirstChild("Vendor") or waitChild(astral, "Vendor", 2)
					if vendor ~= nil then
						local vendorSpinner = vendor:FindFirstChild("NumberSpinner")
						if vendorSpinner ~= nil and vendorSpinner:IsA("ModuleScript") then
							pcall(function()
								return require(vendorSpinner)
							end)
						end
					end
				end
				local playerScripts = Players.LocalPlayer:FindFirstChild("PlayerScripts") or Players.LocalPlayer:WaitForChild("PlayerScripts", math.max(0.1, deadline - os.clock()))
				if playerScripts ~= nil then
					waitChild(playerScripts, "AstralForge", 3)
				end
				pcall(function()
					local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
					if starterScripts ~= nil then
						starterScripts:FindFirstChild("AstralForge")
					end
				end)
			end)
			if alive then
				markBoot("modules")
			end
		end)
		stateWorker = task.spawn(function()
			local attempt = 0
			local lastConnectNotice = 0
			while alive and latestSnapshot.current < 0 do
				local bridgeReady = remotes.Bridge:GetAttribute("Ready") == true
				if bridgeReady then
					markBoot("bridge")
				end
				if bridgeReady then
					local ok, raw = pcall(function()
						return remotes.Request:InvokeServer("GetState", {})
					end)
					if alive and ok and type(raw) == "table" then
						local response = raw
						if response.State and acceptState(response.State) then
							markBoot("state")
							break
						end
					end
				end
				attempt += 1
				-- The boot screen force-exits at 20s in production even without state, so a
				-- save that is still loading (session lock, datastore retry) renders as a
				-- dead UI unless we say something. Surface it once, then keep polling.
				if alive and attempt >= 20 and os.clock() - lastConnectNotice > 30 then
					lastConnectNotice = os.clock()
					addNotice("Still connecting", "Your save is taking longer than usual to load — if Astral Forge is open on another device or Studio session, close it.", "Info", false)
				end
				task.wait(math.min(0.2 + attempt * 0.08, 1.5))
			end
			if alive and remotes.Bridge:GetAttribute("Ready") == true then
				markBoot("bridge")
			end
		end)
		return function()
			alive = false
			fontFinished = true
			cancelWorker(fontWorker)
			cancelWorker(fontTimeout)
			cancelWorker(moduleWorker)
			cancelWorker(stateWorker)
			destroyFontSamples()
			stateConnection:Disconnect()
			toastConnection:Disconnect()
			effectConnection:Disconnect()
		end
	end, { acceptState, addNotice, addPop, applyComboReadout, celebrate, markBoot, remotes })
	local stateLoaded = state ~= nil
	React.useEffect(function()
		if not stateLoaded then
			return nil
		end
		local connection
		local token = task.defer(function()
			setShellMounted(true)
			local frames = 0
			connection = RunService.Heartbeat:Connect(function()
				frames += 1
				if frames < 2 then
					return nil
				end
				local _result_11 = connection
				if _result_11 ~= nil then
					_result_11:Disconnect()
				end
				connection = nil
				markBoot("shell")
				-- Every page reads directly off the single state/config payload that
				-- gated stateLoaded above — there's no separate per-page async fetch,
				-- so once the shell itself is up, every page's data is already there.
				markBoot("mail")
				markBoot("research")
				markBoot("forge")
				markBoot("trade")
				markBoot("boosts")
				markBoot("settings")
				markBoot("mobile")
			end)
		end)
		return function()
			task.cancel(token)
			local _result_11 = connection
			if _result_11 ~= nil then
				_result_11:Disconnect()
			end
		end
	end, { markBoot, stateLoaded })
	React.useEffect(function()
		return preloadMountedGame(function()
			return markBoot("assets")
		end, function(loaded, total)
			return setAssetProgress({
				loaded = loaded,
				total = total,
			})
		end, function()
			return shellMountedRef.current
		end)
	end, { markBoot })
	local _exp_4 = function()
		Audio:start()
		local _object = {}
		local _left = "UiVolume"
		local _result_11 = state
		if _result_11 ~= nil then
			_result_11 = _result_11.Settings.UiVolume
		end
		_object[_left] = _result_11
		local _left_1 = "GameplayVolume"
		local _result_12 = state
		if _result_12 ~= nil then
			_result_12 = _result_12.Settings.GameplayVolume
		end
		_object[_left_1] = _result_12
		local _left_2 = "RewardVolume"
		local _result_13 = state
		if _result_13 ~= nil then
			_result_13 = _result_13.Settings.RewardVolume
		end
		_object[_left_2] = _result_13
		local _left_3 = "AmbientVolume"
		local _result_14 = state
		if _result_14 ~= nil then
			_result_14 = _result_14.Settings.AmbientVolume
		end
		_object[_left_3] = _result_14
		local _left_4 = "HoverSounds"
		local _result_15 = state
		if _result_15 ~= nil then
			_result_15 = _result_15.Settings.HoverSounds
		end
		_object[_left_4] = _result_15
		local _left_5 = "NotificationSounds"
		local _result_16 = state
		if _result_16 ~= nil then
			_result_16 = _result_16.Settings.NotificationSounds
		end
		_object[_left_5] = _result_16
		local _left_6 = "PageMusic"
		local _result_17 = state
		if _result_17 ~= nil then
			_result_17 = _result_17.Settings.PageMusic
		end
		_object[_left_6] = _result_17
		local _left_7 = "MusicCrossfade"
		local _result_18 = state
		if _result_18 ~= nil then
			_result_18 = _result_18.Settings.MusicCrossfade
		end
		_object[_left_7] = _result_18
		local _left_8 = "SoundVariation"
		local _result_19 = state
		if _result_19 ~= nil then
			_result_19 = _result_19.Settings.SoundVariation
		end
		_object[_left_8] = _result_19
		local _left_9 = "PageStingers"
		local _result_20 = state
		if _result_20 ~= nil then
			_result_20 = _result_20.Settings.PageStingers
		end
		_object[_left_9] = _result_20
		Audio:configurePreferences(_object)
		local _result_21 = state
		if _result_21 ~= nil then
			_result_21 = _result_21.Settings.SoundVolume
		end
		local _condition_4 = _result_21
		if _condition_4 == nil then
			_condition_4 = 0.75
		end
		Audio:setVolume(_condition_4)
		local _result_22 = state
		if _result_22 ~= nil then
			_result_22 = _result_22.Settings.MusicVolume
		end
		local _condition_5 = _result_22
		if _condition_5 == nil then
			_condition_5 = 1
		end
		Audio:setMusicVolume(_condition_5)
		local _result_23 = state
		if _result_23 ~= nil then
			_result_23 = _result_23.Settings.SfxVolume
		end
		local _condition_6 = _result_23
		if _condition_6 == nil then
			_condition_6 = 1
		end
		Audio:setSfxVolume(_condition_6)
	end
	local _result_11 = state
	if _result_11 ~= nil then
		_result_11 = _result_11.Settings.AmbientVolume
	end
	local _result_12 = state
	if _result_12 ~= nil then
		_result_12 = _result_12.Settings.GameplayVolume
	end
	local _result_13 = state
	if _result_13 ~= nil then
		_result_13 = _result_13.Settings.HoverSounds
	end
	local _result_14 = state
	if _result_14 ~= nil then
		_result_14 = _result_14.Settings.MusicCrossfade
	end
	local _result_15 = state
	if _result_15 ~= nil then
		_result_15 = _result_15.Settings.SoundVariation
	end
	local _result_16 = state
	if _result_16 ~= nil then
		_result_16 = _result_16.Settings.PageStingers
	end
	local _result_17 = state
	if _result_17 ~= nil then
		_result_17 = _result_17.Settings.MusicVolume
	end
	local _result_18 = state
	if _result_18 ~= nil then
		_result_18 = _result_18.Settings.NotificationSounds
	end
	local _result_19 = state
	if _result_19 ~= nil then
		_result_19 = _result_19.Settings.PageMusic
	end
	local _result_20 = state
	if _result_20 ~= nil then
		_result_20 = _result_20.Settings.RewardVolume
	end
	local _result_21 = state
	if _result_21 ~= nil then
		_result_21 = _result_21.Settings.SfxVolume
	end
	local _result_22 = state
	if _result_22 ~= nil then
		_result_22 = _result_22.Settings.SoundVolume
	end
	local _result_23 = state
	if _result_23 ~= nil then
		_result_23 = _result_23.Settings.UiVolume
	end
	React.useEffect(_exp_4, { _result_11, _result_12, _result_13, _result_14, _result_15, _result_16, _result_17, _result_18, _result_19, _result_20, _result_21, _result_22, _result_23 })
	local _exp_5 = function()
		local _result_24 = state
		if _result_24 ~= nil then
			_result_24 = _result_24.Settings.ScrollSpeed
		end
		local _condition_4 = _result_24
		if _condition_4 == nil then
			_condition_4 = 0.65
		end
		setScrollSpeed(_condition_4)
		local _result_25 = state
		if _result_25 ~= nil then
			_result_25 = _result_25.Settings.ScrollMomentum
		end
		local _condition_5 = _result_25
		if _condition_5 == nil then
			_condition_5 = 0.75
		end
		setScrollMomentum(_condition_5)
		local _result_26 = state
		if _result_26 ~= nil then
			_result_26 = _result_26.Settings.HapticIntensity
		end
		local _condition_6 = _result_26
		if _condition_6 == nil then
			_condition_6 = 0.65
		end
		setHapticIntensity(_condition_6)
	end
	local _result_24 = state
	if _result_24 ~= nil then
		_result_24 = _result_24.Settings.HapticIntensity
	end
	local _result_25 = state
	if _result_25 ~= nil then
		_result_25 = _result_25.Settings.ScrollMomentum
	end
	local _result_26 = state
	if _result_26 ~= nil then
		_result_26 = _result_26.Settings.ScrollSpeed
	end
	React.useEffect(_exp_5, { _result_24, _result_25, _result_26 })
	local _result_27 = state
	if _result_27 ~= nil then
		_result_27 = _result_27.Settings.MotionIntensity
	end
	local _condition_4 = _result_27
	if _condition_4 == nil then
		_condition_4 = 1
	end
	local motionIntensity = _condition_4
	local _result_28 = state
	if _result_28 ~= nil then
		_result_28 = _result_28.Settings.ViewportSpeed
	end
	local _condition_5 = _result_28
	if _condition_5 == nil then
		_condition_5 = 1
	end
	local viewportSpeed = _condition_5
	-- This runs above <AutoScale> (it builds the shellContent AutoScale then wraps), so there is
	-- no scaled ViewportScaleContext available yet here — useViewport() at this exact point would
	-- only ever hit its own raw-camera fallback (desktop: KeyboardEnabled || MouseEnabled, with no
	-- touch or screen-size check at all, always true in Roblox Studio's device emulator). Calling
	-- usesDesktopStructure() directly with the real camera size at least matches the same
	-- touch-aware logic AutoScale itself uses internally, instead of two different guesses
	-- disagreeing about the same device.
	local _result_29 = WorkspaceService.CurrentCamera
	if _result_29 ~= nil then
		_result_29 = _result_29.ViewportSize
	end
	local _condition_6 = _result_29
	if _condition_6 == nil then
		_condition_6 = Vector2.new(1280, 720)
	end
	local rawViewportSize = _condition_6
	local isTouchUiHere = not usesDesktopStructure(rawViewportSize.X, rawViewportSize.Y) and UserInputService.TouchEnabled
	local _result_30
	if isTouchUiHere then
		local _result_31 = state
		if _result_31 ~= nil then
			_result_31 = _result_31.Settings.MobileTextScale
		end
		local _condition_7 = _result_31
		if _condition_7 == nil then
			_condition_7 = 0.5
		end
		_result_30 = 0.92 + _condition_7 * 0.34
	else
		local _result_31 = state
		if _result_31 ~= nil then
			_result_31 = _result_31.Settings.DesktopTextScale
		end
		local _condition_7 = _result_31
		if _condition_7 == nil then
			_condition_7 = 0.5
		end
		_result_30 = 0.96 + _condition_7 * 0.2
	end
	local textScale = _result_30
	local _exp_6 = function()
		local _object = {
			motionScale = motionIntensity,
			viewportScale = viewportSpeed,
			textScale = textScale,
		}
		local _left = "shimmerScale"
		local _result_31 = state
		if _result_31 ~= nil then
			_result_31 = _result_31.Settings.ButtonShimmers
		end
		local _condition_7 = _result_31
		if _condition_7 == nil then
			_condition_7 = 1
		end
		local _result_32
		if _condition_7 >= 0.5 then
			local _result_33 = state
			if _result_33 ~= nil then
				_result_33 = _result_33.Settings.ShimmerIntensity
			end
			local _condition_8 = _result_33
			if _condition_8 == nil then
				_condition_8 = 0.8
			end
			_result_32 = _condition_8
		else
			_result_32 = 0
		end
		_object[_left] = _result_32
		local _left_1 = "panelHoverScale"
		local _result_33 = state
		if _result_33 ~= nil then
			_result_33 = _result_33.Settings.PanelHover
		end
		local _condition_8 = _result_33
		if _condition_8 == nil then
			_condition_8 = 1
		end
		_object[_left_1] = if _condition_8 >= 0.5 then 1 else 0
		local _left_2 = "panelEntranceScale"
		local _result_34 = state
		if _result_34 ~= nil then
			_result_34 = _result_34.Settings.PanelEntrances
		end
		local _condition_9 = _result_34
		if _condition_9 == nil then
			_condition_9 = 1
		end
		_object[_left_2] = if _condition_9 >= 0.5 then 1 else 0
		local _left_3 = "titleScale"
		local _result_35 = state
		if _result_35 ~= nil then
			_result_35 = _result_35.Settings.AnimatedTitles
		end
		local _condition_10 = _result_35
		if _condition_10 == nil then
			_condition_10 = 1
		end
		_object[_left_3] = if _condition_10 >= 0.5 then 1 else 0
		local _left_4 = "iconScale"
		local _result_36 = state
		if _result_36 ~= nil then
			_result_36 = _result_36.Settings.IconAnimations
		end
		local _condition_11 = _result_36
		if _condition_11 == nil then
			_condition_11 = 1
		end
		_object[_left_4] = if _condition_11 >= 0.5 then 1 else 0
		local _left_5 = "numberScale"
		local _result_37 = state
		if _result_37 ~= nil then
			_result_37 = _result_37.Settings.NumberAnimations
		end
		local _condition_12 = _result_37
		if _condition_12 == nil then
			_condition_12 = 1
		end
		_object[_left_5] = if _condition_12 >= 0.5 then 1 else 0
		local _left_6 = "boldText"
		local _result_38 = state
		if _result_38 ~= nil then
			_result_38 = _result_38.Settings.BoldText
		end
		local _condition_13 = _result_38
		if _condition_13 == nil then
			_condition_13 = 0
		end
		_object[_left_6] = _condition_13
		return _object
	end
	local _result_31 = state
	if _result_31 ~= nil then
		_result_31 = _result_31.Settings.AnimatedTitles
	end
	local _result_32 = state
	if _result_32 ~= nil then
		_result_32 = _result_32.Settings.BoldText
	end
	local _result_33 = state
	if _result_33 ~= nil then
		_result_33 = _result_33.Settings.ButtonShimmers
	end
	local _result_34 = state
	if _result_34 ~= nil then
		_result_34 = _result_34.Settings.IconAnimations
	end
	local _result_35 = state
	if _result_35 ~= nil then
		_result_35 = _result_35.Settings.NumberAnimations
	end
	local _result_36 = state
	if _result_36 ~= nil then
		_result_36 = _result_36.Settings.PanelEntrances
	end
	local _result_37 = state
	if _result_37 ~= nil then
		_result_37 = _result_37.Settings.PanelHover
	end
	local _result_38 = state
	if _result_38 ~= nil then
		_result_38 = _result_38.Settings.ShimmerIntensity
	end
	local motionSettings = React.useMemo(_exp_6, { motionIntensity, _result_31, _result_32, _result_33, _result_34, _result_35, _result_36, _result_37, _result_38, textScale, viewportSpeed })
	local touchUi = isTouchUiHere
	local _condition_7 = not touchUi
	if not _condition_7 then
		local _result_39 = state
		if _result_39 ~= nil then
			_result_39 = _result_39.Settings.MobileToastVisible
		end
		local _condition_8 = _result_39
		if _condition_8 == nil then
			_condition_8 = 1
		end
		_condition_7 = _condition_8 >= 0.5
	end
	local mobileToastsVisible = _condition_7
	local _condition_8 = state ~= nil and shellMounted
	if _condition_8 then
		local _attributes = {
			state = state,
			config = config,
			dispatch = dispatch,
			addNotice = addNotice,
			celebrate = celebrate,
			confettiNonce = confettiNonce,
			clearConfetti = clearConfetti,
			pops = pops,
			comboReadout = comboReadout,
			visit = visit,
			setVisit = setVisit,
		}
		local _result_39 = domainUi
		if _result_39 ~= nil then
			_result_39 = _result_39.open
		end
		local _condition_9 = _result_39
		if _condition_9 == nil then
			_condition_9 = (function()
				return nil
			end)
		end
		_attributes.openDomain = _condition_9
		local _result_40 = domainUi
		if _result_40 ~= nil then
			_result_40 = _result_40.active
		end
		_attributes.domainOverlayActive = _result_40 == true
		_attributes.setToastsSuppressed = setToastsSuppressed
		_attributes.setPurchasePresentationActive = setPurchasePresentationActive
		local _exp_7 = React.createElement(Shell, _attributes)
		local _attributes_1 = {
			notices = if mobileToastsVisible and not toastsSuppressed then notices else {},
			remove = dismissNotice,
			setHovered = setNoticeHovered,
			reducedMotion = state.Settings.ReducedMotion == true,
			density = toastDensityRef.current,
		}
		local _result_41
		if touchUi then
			local _object = {}
			local _left = "x"
			local _condition_10 = state.Settings.MobileToastX
			if _condition_10 == nil then
				_condition_10 = 0.84
			end
			_object[_left] = _condition_10
			local _left_1 = "y"
			local _condition_11 = state.Settings.MobileToastY
			if _condition_11 == nil then
				_condition_11 = 0.27
			end
			_object[_left_1] = _condition_11
			local _left_2 = "scale"
			local _condition_12 = state.Settings.MobileToastScale
			if _condition_12 == nil then
				_condition_12 = state.Settings.MobileHudScale
				if _condition_12 == nil then
					_condition_12 = 0.5
				end
			end
			_object[_left_2] = _condition_12
			local _left_3 = "opacity"
			local _condition_13 = state.Settings.ReducedTransparency
			if _condition_13 == nil then
				_condition_13 = 0
			end
			local _result_42
			if _condition_13 >= 0.5 then
				_result_42 = 1
			else
				local _condition_14 = state.Settings.MobileToastOpacity
				if _condition_14 == nil then
					_condition_14 = state.Settings.MobileHudOpacity
					if _condition_14 == nil then
						_condition_14 = 0.85
					end
				end
				_result_42 = _condition_14
			end
			_object[_left_3] = _result_42
			_result_41 = _object
		else
			_result_41 = nil
		end
		_attributes_1.mobileLayout = _result_41
		_condition_8 = React.createElement(React.Fragment, nil, _exp_7, React.createElement(ToastRail, _attributes_1))
	end
	local shellContent = _condition_8
	-- The domain overlays must render inside the same AutoScale layout frame as the shell.
	-- AutoScale is what publishes ViewportScaleContext, and it insets/centres its child frame
	-- (maxShellWidth clamp + safe-area insets). Rendering the overlays as siblings *outside* it
	-- left them parented to the raw full-screen frame while useViewport() fell back to raw camera
	-- pixels — so every centre-relative offset they computed was measured against a different
	-- coordinate space than the one they were actually laid out in.
	local domainContent = if state ~= nil and shellMounted then React.createElement(AutoScale, nil, if domainUi ~= nil then domainUi.render(state, dispatch, shellContent) else shellContent) else shellContent
	local _attributes = {
		prank = adminPrank,
	}
	local _result_39 = state
	if _result_39 ~= nil then
		_result_39 = _result_39.Settings.ReducedMotion
	end
	_attributes.reducedMotion = _result_39 == true
	local _exp_7 = React.createElement(HudPrankStage, _attributes, domainContent)
	local _condition_9 = adminPrank ~= nil
	if _condition_9 then
		local _attributes_1 = {
			prank = adminPrank,
		}
		local _result_40 = state
		if _result_40 ~= nil then
			_result_40 = _result_40.Settings.ReducedMotion
		end
		_attributes_1.reducedMotion = _result_40 == true
		_attributes_1.onClose = function()
			return setAdminPrank(nil)
		end
		_condition_9 = React.createElement(AdminPrankOverlay, _attributes_1)
	end
	local _condition_10 = not externalBoot and bootVisible
	if _condition_10 then
		local _attributes_1 = {
			marks = bootMarks,
			ready = bootReady,
			progress = bootFill,
			version = config.Game.Version,
		}
		local _result_40 = state
		if _result_40 ~= nil then
			_result_40 = _result_40.Settings.ReducedMotion
		end
		_attributes_1.reducedMotion = _result_40 == true
		_attributes_1.startedAt = bootStartedAt
		_attributes_1.onExitDone = onBootExitDone
		_condition_10 = React.createElement(MotionSettingsContext.Provider, {
			value = Boot.BOOT_MOTION,
		}, React.createElement(Boot.BootScreen, _attributes_1))
	end
	local content = React.createElement(MotionSettingsContext.Provider, {
		value = motionSettings,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
	}, _exp_7, _condition_9, _condition_10))
	return if externalAntilag then content else React.createElement(AntilagProvider, nil, content)
end
return {
	MainGame = MainGame,
}
