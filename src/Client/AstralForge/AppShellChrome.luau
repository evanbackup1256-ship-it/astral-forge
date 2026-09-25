local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local reactModules = require(script.Parent.reactModules)
local useLatestCallback = reactModules.useLatestCallback
local notePage = require(script.Parent.vendorHost).notePage
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _MobileShell = require(script.Parent.MobileShell)
local MobileHeader = _MobileShell.MobileHeader
local MobileQuickActions = _MobileShell.MobileQuickActions
local MobileTabBar = _MobileShell.MobileTabBar
local _flexbox = require(script.Parent.flexbox)
local Flex = _flexbox.Flex
local FlexItem = _flexbox.FlexItem
local _effects = require(script.Parent.effects)
local EffectLayer = _effects.EffectLayer
local StarField = _effects.StarField
local CelebrationBurst = require(script.Parent.CelebrationBurst).CelebrationBurst
local ComboBadge = require(script.Parent.ComboBadge).ComboBadge
local _antilag = require(script.Parent.antilag)
local AntilagContext = _antilag.AntilagContext
local clampAntilagTier = _antilag.clampAntilagTier
local setAntilagPreference = _antilag.setAntilagPreference
local setAntilagScene = _antilag.setAntilagScene
local useAntilag = _antilag.useAntilag
local _motion = require(script.Parent.motion)
local beginUiTransition = _motion.beginUiTransition
local setClockBudget = _motion.setClockBudget
local setDecorativeMotionFrozen = _motion.setDecorativeMotionFrozen
local useFlipperSpring = _motion.useFlipperSpring
local useDynamicLayoutNumber = require(script.Parent.dynamicLayout).useDynamicLayoutNumber
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local Text = _ui.Text
local _theme = require(script.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local CreditsOverlay = require(script.Parent.pages.CreditsView).CreditsOverlay
local CrateRevealOverlay = require(script.Parent.pages.CrateRevealOverlay).CrateRevealOverlay
local PageContent = require(script.Parent.pages.PageRouter).PageContent
local PageFrame = require(script.Parent.reactHost).PageFrame
local useGameChat = require(script.Parent.chat).useGameChat
local _appNav = require(script.Parent.appNav)
local AppHelpers = _appNav.AppHelpers
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local _TopBarChrome = require(script.Parent.TopBarChrome)
local TopBar = _TopBarChrome.TopBar
local _ShellFx = require(script.Parent.ShellFx)
local TradeReturnPill = _ShellFx.TradeReturnPill
local AmbientLayer = _ShellFx.AmbientLayer
local ConfettiBurst = _ShellFx.ConfettiBurst
local _NavChrome = require(script.Parent.NavChrome)
local Navigation = _NavChrome.Navigation
local MoreDock = _NavChrome.MoreDock
local _WorkspaceChrome = require(script.Parent.WorkspaceChrome)
local Workspace = _WorkspaceChrome.Workspace
local ClientLog = require(script.Parent.log).ClientLog
local _session = require(script.Parent.session)
local setPresencePage = _session.setPresencePage
local Audio = require(script.Parent.audio).Audio
local SplitCurtain = require(script.Parent.sanctuaryChrome).SplitCurtain
local SanctuaryPresence = require(script.Parent.sanctuaryPresence)
local _onboarding = require(script.Parent.onboarding)
local ReleaseNotesModal = _onboarding.ReleaseNotesModal
local TutorialOverlay = _onboarding.TutorialOverlay
local _clientStore = require(script.Parent.clientStore)
local ClientActions = _clientStore.ClientActions
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local PlayerlistOverlay = require(script.Parent.PlayerlistOverlay).PlayerlistOverlay
local MobilePreviewGate = require(script.Parent.MobilePreviewGate).MobilePreviewGate
local OfflineRewardsOverlay = require(script.Parent.OfflineRewardsOverlay).OfflineRewardsOverlay
local FeedbackOverlay = require(script.Parent.FeedbackOverlay).FeedbackOverlay

local pausePassivePaints = {
	current = false,
}
local TUTORIAL_STEPS = { {
	title = "Machines earn while you play",
	goal = "See your vault",
	body = "Machines pour Flux into the vault. Collect it to get cash you can spend.",
	hint = "The big number is Flux stored right now.",
	controls = "Tap Continue  ·  Xbox: A",
	page = "Overview",
	watch = "vault",
}, {
	title = "Collect turns Flux into cash",
	goal = "Collect the vault",
	body = "Collect now. A full vault stops earning, so empty it often.",
	hint = "Tap Collect stored Flux on this page.",
	controls = "Keyboard: E   ·   Xbox: Y",
	page = "Overview",
	cta = "collect",
	ctaLabel = "Collect stored Flux",
	watch = "collect",
}, {
	title = "Buy a machine to earn more",
	goal = "Buy Stellar Core",
	body = "Buy Stellar Core in Workshop. Each level adds Flux per second.",
	hint = "If the button is grey, collect the vault first.",
	controls = "Xbox: A opens Workshop",
	page = "Workshop",
	cta = "workshop",
	ctaLabel = "Open Workshop",
	watch = "buy",
}, {
	title = "Buy several levels at once",
	goal = "Try x5 or Max",
	body = "x1 buys one level. x5 buys five. Max buys what you can afford.",
	hint = "Stay on x1 until the prices make sense.",
	controls = "Xbox: LT / RT changes the buy amount",
	page = "Workshop",
	watch = "amount",
}, {
	title = "Research stays after rebirth",
	goal = "Open Research",
	body = "Buy the lit bonuses in order. They stay when you rebirth.",
	hint = "If Research is locked, earn 100 Flux total, or skip — it opens after a little play.",
	controls = "Xbox: A opens Research",
	page = "Research",
	cta = "research",
	ctaLabel = "Open Research",
	watch = "research",
}, {
	title = "Rebirth trades machines for Cores",
	goal = "Read the rebirth panel",
	body = "Rebirth resets machines and pays Cores. Research stays. The next run is stronger.",
	hint = "Overview shows the Core payout before you confirm.",
	controls = "Tap Continue when you've read the panel",
	page = "Overview",
	watch = "rebirth",
}, {
	title = "Come back and collect",
	goal = "Finish the guide",
	body = "Collect, buy machines, research, rebirth. You keep earning while you're away.",
	hint = "Finishing pays a small Flux bonus. Replay this from Settings, then Guide.",
	controls = "Tap Finish  ·  Xbox: A",
	page = "Overview",
	watch = "finish",
} }
local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}
local function AppShell(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local addNotice = _param.addNotice
	local celebrate = _param.celebrate
	local confettiNonce = _param.confettiNonce
	local clearConfetti = _param.clearConfetti
	local pops = _param.pops
	local comboReadout = _param.comboReadout
	local visit = _param.visit
	local setVisit = _param.setVisit
	local openDomain = _param.openDomain
	local domainOverlayActive = _param.domainOverlayActive
	local setToastsSuppressed = _param.setToastsSuppressed
	local setPurchasePresentationActive = _param.setPurchasePresentationActive
	local crateReveal, setCrateReveal = React.useState()
	local pageHostRef = React.useRef(nil)
	local cinematicOpen = crateReveal ~= nil or domainOverlayActive
	React.useEffect(function()
		pausePassivePaints.current = cinematicOpen
		setDecorativeMotionFrozen(cinematicOpen)
		return function()
			pausePassivePaints.current = false
			setDecorativeMotionFrozen(false)
		end
	end, { cinematicOpen })
	React.useEffect(function()
		local _condition = state.Settings.PerformanceBias
		if _condition == nil then
			_condition = 0.5
		end
		setAntilagPreference(_condition)
	end, { state.Settings.PerformanceBias })
	local playerlistOpen, setPlayerlistOpen = React.useState(false)
	local feedbackOpen, setFeedbackOpen = React.useState(false)
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local drawerNav = chrome.stack or (not viewport.desktop and UserInputService.TouchEnabled and viewport.compact)
	local page = useClientSelector(function(client)
		return client.navigation.page
	end)
	local bootChromeVisible = useClientSelector(function(client)
		return client.boot.visible
	end)
	local dispatchStore = useClientDispatch()
	local setPage = React.useCallback(function(pageNext)
		return dispatchStore(ClientActions.navigate(pageNext))
	end, { dispatchStore })
	React.useEffect(function()
		setPresencePage(page)
	end, { page })
	local railOpen, setRailOpen = React.useState(not drawerNav)
	local previousDrawerNav = React.useRef(drawerNav)
	React.useEffect(function()
		if previousDrawerNav.current == drawerNav then
			return nil
		end
		previousDrawerNav.current = drawerNav
		setRailOpen(not drawerNav)
	end, { drawerNav })
	local arcadeBusy, setArcadeBusy = React.useState(false)
	local hidden, setHidden = React.useState(false)
	local sanctuaryOpen, setSanctuaryOpen = React.useState(false)
	local riftOpen, setRiftOpen = React.useState(false)
	local sanctuaryOpenRef = React.useRef(false)
	sanctuaryOpenRef.current = sanctuaryOpen
	local blockSanctuaryRef = React.useRef(false)
	local dispatchRef = React.useRef(dispatch)
	dispatchRef.current = dispatch
	React.useEffect(function()
		if not sanctuaryOpen then
			return nil
		end
		local call = function(action, payload, callback)
			return dispatchRef.current(action, payload, callback)
		end
		local token = SanctuaryPresence.enter(call, function()
			setRiftOpen(false)
			setSanctuaryOpen(false)
		end, function()
			setRiftOpen(false)
			setSanctuaryOpen(false)
		end, function()
			setRiftOpen(true)
		end)
		return function()
			setRiftOpen(false)
			SanctuaryPresence.leave(call, token)
		end
	end, { sanctuaryOpen })
	local buyAmount, setBuyAmount = React.useState(1)
	local chat = useGameChat(page == "Chat", true)
	local offlineReceiptKey = if state.Offline ~= nil and state.Offline.Seconds >= 30 then `{math.floor(state.Offline.Seconds)}:{compactNumber(state.Offline.Reward)}` else ""
	local dismissedOfflineKey, setDismissedOfflineKey = React.useState("")
	local offlineDismissed = offlineReceiptKey ~= "" and dismissedOfflineKey == offlineReceiptKey
	local _binding = (function()
		local _condition = state.Settings.UiDensity
		if _condition == nil then
			_condition = 0.55
		end
		local uiDensity = _condition
		local densityScale = 0.82 + uiDensity * 0.36
		local edgePad = math.max(8, chrome.sideSafe, math.floor(chrome.pagePadding * densityScale))
		-- The ScreenGui itself is CoreUISafeInsets; do not reserve the device/topbar
		-- cutout a second time inside the shell.
		local topPad = if chrome.stack then 6 else Layout.topbarClearance
		local _condition_1 = viewport.keyboardOpen and chrome.mobile
		if _condition_1 then
			local _condition_2 = state.Settings.MobileKeyboardCompact
			if _condition_2 == nil then
				_condition_2 = 1
			end
			_condition_1 = _condition_2 >= 0.5
		end
		local keyboardShellCompact = _condition_1
		local _result
		if keyboardShellCompact then
			_result = 0
		else
			local _result_1
			if chrome.stack then
				_result_1 = chrome.topbarRows
			else
				local _condition_2 = state.Settings.CompactTopBar
				if _condition_2 == nil then
					_condition_2 = 0
				end
				_result_1 = if _condition_2 >= 0.5 then math.max(52, chrome.topbarRows - 8) else chrome.topbarRows
			end
			_result = _result_1
		end
		local topbarHeight = _result
		-- Desktop secondary destinations live in the sidebar (includeSecondary). The old
		-- horizontal MoreDock row above the workspace was wasted chrome on PC/ultrawide.
		local moreAtBottom = chrome.stack
		local tabBarH = if keyboardShellCompact then 0 else chrome.tabBarH
		local shellTop = topPad + topbarHeight + chrome.panelGap
		local desktopDockTop = shellTop
		local desktopDockHeight = 0
		local _condition_2 = state.Settings.MobileQuickVisible
		if _condition_2 == nil then
			_condition_2 = 1
		end
		local mobileQuickEnabled = _condition_2 >= 0.5
		-- Overview already exposes Collect/Overcharge in its hero; keep the floating cluster
		-- on Workshop only so it does not cover Overview first-screen CTAs.
		local quickActionsVisible = mobileQuickEnabled and moreAtBottom and page == "Workshop" and not viewport.keyboardOpen and not arcadeBusy and crateReveal == nil and not railOpen
		local quickBottomOffset = tabBarH + 12
		local bottomPad = if keyboardShellCompact then 4 elseif moreAtBottom then (if quickActionsVisible then tabBarH + 76 + chrome.panelGap else tabBarH + chrome.panelGap) else math.max(8, math.floor(edgePad * 0.6))
		return {
			edgePad = edgePad,
			topPad = topPad,
			keyboardShellCompact = keyboardShellCompact,
			topbarHeight = topbarHeight,
			moreAtBottom = moreAtBottom,
			shellTop = shellTop,
			desktopDockTop = desktopDockTop,
			desktopDockHeight = desktopDockHeight,
			tabBarH = tabBarH,
			quickActionsVisible = quickActionsVisible,
			quickBottomOffset = quickBottomOffset,
			bottomPad = bottomPad,
		}
	end)()
	local edgePad = _binding.edgePad
	local topPad = _binding.topPad
	local keyboardShellCompact = _binding.keyboardShellCompact
	local topbarHeight = _binding.topbarHeight
	local moreAtBottom = _binding.moreAtBottom
	local shellTop = _binding.shellTop
	local desktopDockTop = _binding.desktopDockTop
	local desktopDockHeight = _binding.desktopDockHeight
	local tabBarH = _binding.tabBarH
	local quickActionsVisible = _binding.quickActionsVisible
	local quickBottomOffset = _binding.quickBottomOffset
	local bottomPad = _binding.bottomPad
	local reducedMotion = state.Settings.ReducedMotion == true
	local antilagShell = useAntilag()
	-- Canonical softMotion antilag gate — AppShell chrome springs drop on soft tiers.
	local softMotion = reducedMotion or antilagShell.tier <= 1 or not antilagShell.allowAmbient
	reducedMotion = softMotion
	local shellTopLive = useDynamicLayoutNumber(shellTop, softMotion)
	local topbarLive = useDynamicLayoutNumber(topbarHeight, softMotion)
	React.useEffect(function()
		Audio:setView(page, false)
	end, { page })
	local _condition = state.Settings.EffectsIntensity
	if _condition == nil then
		_condition = 1
	end
	local effectsScale = _condition
	local accent = AppHelpers:pageAccent(page)
	local _result = state.ActiveBoost
	if _result ~= nil then
		_result = _result.Id
	end
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = ""
	end
	local activeBoostId = _condition_1
	local _result_1 = state.ActiveBoost
	if _result_1 ~= nil then
		_result_1 = _result_1.EndsAt
	end
	local _condition_2 = _result_1
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local activeBoostEndsAt = _condition_2
	local activeBoostExpired, setActiveBoostExpired = React.useState(activeBoostEndsAt <= os.time())
	React.useEffect(function()
		local remaining = activeBoostEndsAt - os.time()
		setActiveBoostExpired(remaining <= 0)
		if activeBoostId == "" or remaining <= 0 then
			return nil
		end
		local expiry = task.delay(remaining + 0.05, function()
			return setActiveBoostExpired(true)
		end)
		return function()
			return task.cancel(expiry)
		end
	end, { activeBoostEndsAt, activeBoostId })
	local _result_2
	if not activeBoostExpired and activeBoostId ~= "" then
		local _result_3 = config.Boosts
		if _result_3 ~= nil then
			_result_3 = _result_3[activeBoostId]
		end
		_result_2 = _result_3
	else
		_result_2 = nil
	end
	local activeBoost = _result_2
	local wallClock = useWallClock(activeBoost ~= nil)
	local hideAmount = useFlipperSpring(if hidden then 1 else 0, softMotion, 620, 42)
	-- The v2 mobile shell (chrome.stack) never uses the drawer/rail system at all — it has its
	-- own fixed bottom tab bar (MobileTabBar) instead. The drawer/rail below only still applies
	-- to the non-stack "touch + compact" case (e.g. a touch tablet in a window too wide to
	-- count as `stack`), which keeps its own slide-out drawer.
	local mobileShell = chrome.stack
	local drawerWidth = math.min(Layout.sidebarWidth, math.max(248, viewport.width - edgePad * 2 - 36))
	local railTarget = if railOpen then (if drawerNav then drawerWidth else (if viewport.compact then Layout.sidebarCollapsedWidth else Layout.sidebarWidth)) else 0
	local railWidth = useFlipperSpring(if mobileShell then 0 else railTarget, softMotion, 900, 46)
	local drawerProgress = railWidth:map(function(width)
		return if drawerNav then math.clamp(width / math.max(drawerWidth, 1), 0, 1) else 0
	end)
	local drawerScrimTransparency = drawerProgress:map(function(amount)
		return 1 - amount * 0.58
	end)
	local drawerScrimVisible = drawerProgress:map(function(amount)
		return amount > 0.01
	end)
	local drawerPanelVisible = railWidth:map(function(width)
		return not drawerNav or width > 36
	end)
	local dockVisible = railWidth:map(function(width)
		return not drawerNav or width <= 4
	end)
	local workspaceOffset = railWidth:map(function(width)
		if drawerNav then
			return UDim2.fromOffset(0, 0)
		end
		return UDim2.new(0, if width > 1 then width + Layout.panelGap else 0, 0, 0)
	end)
	local workspaceSize = railWidth:map(function(width)
		if drawerNav then
			return UDim2.fromScale(1, 1)
		end
		return UDim2.new(1, -(if width > 1 then width + Layout.panelGap else 0), 1, 0)
	end)
	local _condition_3 = state.Flags.TutorialStep
	if _condition_3 == nil then
		_condition_3 = 1
	end
	local serverTutorialStep = math.clamp(math.floor(_condition_3), 1, #TUTORIAL_STEPS)
	local tutorialStep, setTutorialStep = React.useState(serverTutorialStep)
	local tutorialHold = React.useRef(0)
	React.useEffect(function()
		if tutorialHold.current > 0 and serverTutorialStep < tutorialHold.current and not state.Flags.TutorialDone then
			return nil
		end
		tutorialHold.current = 0
		setTutorialStep(serverTutorialStep)
	end, { serverTutorialStep, state.Flags.TutorialDone })
	local tutorial = TUTORIAL_STEPS[tutorialStep]
	local tutorialOpen = not state.Flags.TutorialDone and tutorial ~= nil
	local releaseClosedLocally, setReleaseClosedLocally = React.useState(false)
	React.useEffect(function()
		if state.Flags.LastSeenVersion == "" then
			setReleaseClosedLocally(false)
		end
	end, { state.Flags.LastSeenVersion })
	local showRelease = state.Flags.TutorialDone and state.Flags.LastSeenVersion ~= config.Game.Version and not releaseClosedLocally
	blockSanctuaryRef.current = tutorialOpen or showRelease or crateReveal ~= nil or domainOverlayActive
	local _condition_4 = offlineReceiptKey ~= "" and not offlineDismissed and state.Flags.TutorialDone
	if _condition_4 then
		local _result_3 = state.Offline
		if _result_3 ~= nil then
			_result_3 = _result_3.Reward
		end
		local _condition_5 = _result_3
		if _condition_5 == nil then
			_condition_5 = 0
		end
		_condition_4 = gteFlux(_condition_5, 0.01)
		if _condition_4 then
			_condition_4 = not showRelease and page ~= "Credits" and crateReveal == nil and not playerlistOpen and not feedbackOpen and not domainOverlayActive
		end
	end
	local offlineRewardsOpen = _condition_4
	local modalOwnsScreen = tutorialOpen or showRelease or page == "Credits" or crateReveal ~= nil or domainOverlayActive
	React.useEffect(function()
		setToastsSuppressed(modalOwnsScreen)
		return function()
			return setToastsSuppressed(false)
		end
	end, { modalOwnsScreen, setToastsSuppressed })
	reactModules.useEventListener(UserInputService.InputBegan, function(input, processed)
		if UserInputService:GetFocusedTextBox() ~= nil then
			return nil
		end
		if input.KeyCode == Enum.KeyCode.LeftAlt then
			setHidden(false)
			setSanctuaryOpen(function(current)
				if current then
					return false
				end
				if blockSanctuaryRef.current then
					return false
				end
				return true
			end)
			return nil
		end
		if processed or sanctuaryOpenRef.current then
			return nil
		end
		if input.KeyCode == Enum.KeyCode.Backquote then
			setHidden(function(current)
				return not current
			end)
		end
	end, {
		connected = not domainOverlayActive and not showRelease and not tutorialOpen,
	})
	local navigate = function(pageId)
		local entry = AppHelpers:pageEntry(pageId)
		if entry.disabled == true then
			Audio:play("locked")
			local _exp = `{entry.label} is closed`
			local _condition_5 = entry.disabledReason
			if _condition_5 == nil then
				_condition_5 = "Closed for now."
			end
			addNotice(_exp, _condition_5, "Info")
			return nil
		end
		local _exp = pageId
		local _result_3 = tutorial
		if _result_3 ~= nil then
			_result_3 = _result_3.page
		end
		if not AppHelpers:navUnlocked(state, _exp, _result_3) then
			local _lock = state.FeatureUnlocks
			if _lock ~= nil then
				_lock = _lock[pageId]
			end
			local lock = _lock
			Audio:play("locked")
			local _result_4 = lock
			if _result_4 ~= nil then
				_result_4 = _result_4.Name
			end
			local _condition_5 = _result_4
			if _condition_5 == nil then
				_condition_5 = pageId
			end
			local _exp_1 = `{_condition_5} is locked`
			local _result_5 = lock
			if _result_5 ~= nil then
				_result_5 = _result_5.Requirement
			end
			local _condition_6 = _result_5
			if _condition_6 == nil then
				_condition_6 = "Not unlocked yet."
			end
			if pageId == "Research" then
				_exp_1 = "Research unlocks later"
				_condition_6 = "Earn 100 Flux in total — collect your vault. Bonuses you buy here stay after rebirth."
			elseif pageId == "Workshop" then
				_exp_1 = "Workshop is where you buy machines"
				_condition_6 = "A machine earns Flux into your vault every second. Collect that, then buy the next level."
			end
			addNotice(_exp_1, _condition_6, "Info")
			return nil
		end
		Audio:setView(pageId)
		ClientLog:debug("nav", pageId)
		beginUiTransition(0.1)
		setPage(pageId)
		if drawerNav then
			setRailOpen(false)
		end
	end
	local navigationStateRef = React.useRef(state)
	navigationStateRef.current = state
	local _result_3 = tutorial
	if _result_3 ~= nil then
		_result_3 = _result_3.page
	end
	local tutorialPageRef = React.useRef(_result_3)
	local _result_4 = tutorial
	if _result_4 ~= nil then
		_result_4 = _result_4.page
	end
	tutorialPageRef.current = _result_4
	local navigateRef = React.useRef(navigate)
	navigateRef.current = navigate
	local navigateStable = useLatestCallback(function(pageId)
		notePage(pageId)
		return navigateRef.current(pageId)
	end)
	local openWorkshop = React.useCallback(function()
		return navigateRef.current("Workshop")
	end, {})
	local onWheelLand = React.useCallback(function()
		return celebrate()
	end, { celebrate })
	React.useEffect(function()
		local _condition_5 = state.Flags.TutorialDone
		if not _condition_5 then
			local _result_5 = tutorial
			if _result_5 ~= nil then
				_result_5 = _result_5.page
			end
			_condition_5 = _result_5 == nil
		end
		if _condition_5 then
			return nil
		end
		setHidden(false)
		setPage(if AppHelpers:navUnlocked(state, tutorial.page, tutorial.page) then tutorial.page else "Overview")
	end, { state.Flags.TutorialDone, tutorial })
	React.useEffect(function()
		local _condition_5 = page ~= "Trade"
		if _condition_5 then
			local _result_5 = tutorial
			if _result_5 ~= nil then
				_result_5 = _result_5.page
			end
			_condition_5 = not AppHelpers:navUnlocked(state, page, _result_5)
		end
		if _condition_5 then
			setPage("Overview")
		end
	end, { page, state.FeatureUnlocks, tutorial })
	local tradeFocusKey = React.useRef("")
	local _exp = function()
		local _sessionId = state.Trade
		if _sessionId ~= nil then
			_sessionId = _sessionId.Session
			if _sessionId ~= nil then
				_sessionId = _sessionId.Id
			end
		end
		local sessionId = _sessionId
		local _invite = state.Trade
		if _invite ~= nil then
			_invite = _invite.Invite
		end
		local invite = _invite
		local key = if sessionId ~= nil then `session:{sessionId}` elseif invite ~= nil then `invite:{invite.FromUserId}:{invite.ExpiresAt}` else ""
		if key == "" then
			tradeFocusKey.current = ""
			return nil
		end
		local fresh = key ~= tradeFocusKey.current
		if fresh then
			tradeFocusKey.current = key
			Audio:play(if sessionId ~= nil then "confirm" else "invite")
			if sessionId ~= nil then
				setHidden(false)
				setPlayerlistOpen(false)
				setFeedbackOpen(false)
				if drawerNav then
					setRailOpen(false)
				end
				setPage("Trade")
			end
		end
	end
	local _result_5 = state.Trade
	if _result_5 ~= nil then
		_result_5 = _result_5.Invite
		if _result_5 ~= nil then
			_result_5 = _result_5.ExpiresAt
		end
	end
	local _result_6 = state.Trade
	if _result_6 ~= nil then
		_result_6 = _result_6.Invite
		if _result_6 ~= nil then
			_result_6 = _result_6.FromUserId
		end
	end
	local _result_7 = state.Trade
	if _result_7 ~= nil then
		_result_7 = _result_7.Session
		if _result_7 ~= nil then
			_result_7 = _result_7.Id
		end
	end
	React.useEffect(_exp, { drawerNav, _result_5, _result_6, _result_7 })
	local tradeAwaySent = React.useRef(false)
	local _exp_1 = function()
		local _result_8 = state.Trade
		if _result_8 ~= nil then
			_result_8 = _result_8.Session
		end
		local live = _result_8 ~= nil
		if not live then
			tradeAwaySent.current = false
			return nil
		end
		local away = page ~= "Trade"
		if away == tradeAwaySent.current then
			return nil
		end
		tradeAwaySent.current = away
		dispatch("TradeViewAway", {
			Away = away,
		})
	end
	local _result_8 = state.Trade
	if _result_8 ~= nil then
		_result_8 = _result_8.Session
		if _result_8 ~= nil then
			_result_8 = _result_8.Id
		end
	end
	React.useEffect(_exp_1, { dispatch, page, _result_8 })
	React.useEffect(function()
		local player = Players.LocalPlayer
		local unfocusedAt = -math.huge
		local focused = true
		local mark = function(away)
			player:SetAttribute("AF_Away", away)
			player:SetAttribute("AF_AwayAt", if away then os.clock() else 0)
		end
		mark(false)
		local lost = UserInputService.WindowFocusReleased:Connect(function()
			focused = false
			unfocusedAt = os.clock()
		end)
		local gained = UserInputService.WindowFocused:Connect(function()
			focused = true
			mark(false)
		end)
		local menuOpen = GuiService.MenuOpened:Connect(function()
			focused = false
			unfocusedAt = os.clock()
		end)
		local menuClose = GuiService.MenuClosed:Connect(function()
			focused = true
			mark(false)
		end)
		local pulse = task.spawn(function()
			while true do
				task.wait(1)
				if not focused and os.clock() - unfocusedAt >= 20 then
					mark(true)
				end
			end
		end)
		return function()
			lost:Disconnect()
			gained:Disconnect()
			menuOpen:Disconnect()
			menuClose:Disconnect()
			task.cancel(pulse)
			mark(false)
		end
	end, {})
	React.useEffect(function()
		GuiService.AutoSelectGuiEnabled = true
		GuiService.GuiNavigationEnabled = true
		local BUY_STEPS = { 1, 5, 10, 25, 0 }
		local cycleBuy = function(dir)
			local index = (table.find(BUY_STEPS, buyAmount) or 0) - 1
			local at = if index >= 0 then index else 0
			local stepped = BUY_STEPS[(at + dir + #BUY_STEPS) % #BUY_STEPS + 1]
			setBuyAmount(stepped)
			Audio:play("tick")
		end
		local actionName = "AstralForgeNavigation"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState, input)
			if inputState ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			if UserInputService:GetFocusedTextBox() ~= nil then
				return Enum.ContextActionResult.Pass
			end
			if arcadeBusy then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and page == "Credits" then
				navigateRef.current("Overview")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and playerlistOpen then
				setPlayerlistOpen(false)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and feedbackOpen then
				setFeedbackOpen(false)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and showRelease then
				dispatch("DismissRelease")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB and tutorialOpen then
				if tutorialStep > 1 then
					dispatch("SetTutorialStep", {
						Step = tutorialStep - 1,
					})
				end
				return Enum.ContextActionResult.Sink
			end
			if crateReveal ~= nil or playerlistOpen or feedbackOpen or page == "Credits" or domainOverlayActive or showRelease or tutorialOpen then
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonB then
				if hidden then
					setHidden(false)
				elseif railOpen then
					setRailOpen(false)
				else
					setRailOpen(true)
				end
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonY then
				Audio:play("vaultBank")
				dispatch("CollectVault")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonX then
				Audio:play("reactorPulse")
				dispatch("Overcharge")
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonSelect then
				setHidden(function(current)
					return not current
				end)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonL2 then
				cycleBuy(-1)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonR2 then
				cycleBuy(1)
				return Enum.ContextActionResult.Sink
			end
			if input.KeyCode == Enum.KeyCode.ButtonStart then
				navigateRef.current("Settings")
				return Enum.ContextActionResult.Sink
			end
			local rail = AppHelpers:visibleNav(navigationStateRef.current, tutorialPageRef.current)
			if #rail == 0 then
				return Enum.ContextActionResult.Pass
			end
			-- ▼ ReadonlyArray.findIndex ▼
			local _callback = function(entry)
				return entry.id == page
			end
			local _result_9 = -1
			for _i, _v in rail do
				if _callback(_v, _i - 1, rail) == true then
					_result_9 = _i - 1
					break
				end
			end
			-- ▲ ReadonlyArray.findIndex ▲
			local index = math.max(0, _result_9)
			if input.KeyCode == Enum.KeyCode.ButtonL1 then
				navigateRef.current(rail[(index - 1 + #rail) % #rail + 1].id)
			elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
				navigateRef.current(rail[(index + 1) % #rail + 1].id)
			else
				return Enum.ContextActionResult.Pass
			end
			return Enum.ContextActionResult.Sink
		end, false, 2200, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonSelect, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonStart)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { arcadeBusy, buyAmount, crateReveal, dispatch, domainOverlayActive, feedbackOpen, hidden, page, playerlistOpen, railOpen, showRelease, tutorialOpen, tutorialStep })
	local gamepadActive, setGamepadActive = React.useState(false)
	React.useEffect(function()
		local isPad = function(inputType)
			return inputType == Enum.UserInputType.Gamepad1 or inputType == Enum.UserInputType.Gamepad2 or inputType == Enum.UserInputType.Gamepad3 or inputType == Enum.UserInputType.Gamepad4
		end
		local sync = function(inputType)
			return setGamepadActive(isPad(inputType))
		end
		sync(UserInputService:GetLastInputType())
		local connection = UserInputService.LastInputTypeChanged:Connect(sync)
		return function()
			return connection:Disconnect()
		end
	end, {})
	local sampledAntilag = useAntilag()
	local _condition_5 = state.Settings.PerformanceBias
	if _condition_5 == nil then
		_condition_5 = 0.5
	end
	local performanceBias = _condition_5
	local performanceTierCap = if performanceBias >= 0.88 then 1 elseif performanceBias >= 0.68 then 2 else 3
	local rootAntilag = React.useMemo(function()
		return clampAntilagTier(sampledAntilag, performanceTierCap)
	end, { performanceTierCap, sampledAntilag })
	local _condition_6 = state.Settings.BackgroundDetail
	if _condition_6 == nil then
		_condition_6 = 0.8
	end
	local backgroundDetail = _condition_6
	local _condition_7 = state.Settings.GlowIntensity
	if _condition_7 == nil then
		_condition_7 = 0.75
	end
	local glowIntensity = _condition_7
	local suppressBackground = backgroundDetail < 0.34 or not rootAntilag.allowAmbient
	local _condition_8 = state.Settings.ParticleDensity
	if _condition_8 == nil then
		_condition_8 = 0.75
	end
	local renderEffectsScale = effectsScale * _condition_8 * rootAntilag.fxBudget
	local _result_9
	if #pops > rootAntilag.maxPops then
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(_, index)
			return index >= #pops - rootAntilag.maxPops
		end
		local _length = 0
		for _k, _v in pops do
			if _callback(_v, _k - 1, pops) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		_result_9 = _newValue
	else
		_result_9 = pops
	end
	local visiblePops = _result_9
	local heavyPage = page == "Worlds" or page == "Anomaly" or page == "StarGrid"
	local quietPage = page == "Story" or page == "Chat" or page == "Mail" or page == "Credits" or page == "Leaderboards" or page == "Admin"
	local pageAntilag = React.useMemo(function()
		local _result_10
		if arcadeBusy then
			local _object = table.clone(rootAntilag)
			setmetatable(_object, nil)
			_object.allowConfetti = false
			_object.maxStars = 0
			_object.maxClocks = math.min(rootAntilag.maxClocks, 4)
			_result_10 = _object
		else
			local _result_11
			if heavyPage then
				local _object = table.clone(rootAntilag)
				setmetatable(_object, nil)
				_object.maxStars = 0
				_object.maxClocks = math.min(rootAntilag.maxClocks, if page == "Anomaly" then 8 else 4)
				_result_11 = _object
			else
				local _result_12
				if quietPage then
					local _object = table.clone(rootAntilag)
					setmetatable(_object, nil)
					_object.maxStars = math.min(rootAntilag.maxStars, 4)
					_result_12 = _object
				else
					_result_12 = rootAntilag
				end
				_result_11 = _result_12
			end
			_result_10 = _result_11
		end
		return _result_10
	end, { arcadeBusy, heavyPage, page, quietPage, rootAntilag })
	React.useEffect(function()
		local scene = if cinematicOpen then "cinematic" elseif arcadeBusy then "arcade" elseif heavyPage then "heavy" else "normal"
		setAntilagScene(scene)
		return function()
			return setAntilagScene("normal")
		end
	end, { arcadeBusy, cinematicOpen, heavyPage })
	React.useEffect(function()
		setClockBudget(pageAntilag.maxClocks)
		setDecorativeMotionFrozen(pageAntilag.tier <= 0 or pageAntilag.hitchScore >= 0.2 or pageAntilag.quality < 0.14)
	end, { pageAntilag.hitchScore, pageAntilag.maxClocks, pageAntilag.quality, pageAntilag.tier })
	local _exp_2 = React.createElement("uigradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Palette.void), ColorSequenceKeypoint.new(0.5, Palette.graphite), ColorSequenceKeypoint.new(1, Palette.void) }),
		Rotation = 112,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = hideAmount:map(function(amount)
			return math.clamp(0.8 + amount, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	local _condition_9 = state.Settings.BackgroundStars
	if _condition_9 == nil then
		_condition_9 = 1
	end
	local _condition_10 = _condition_9 >= 0.5
	if _condition_10 then
		_condition_10 = backgroundDetail >= 0.2 and React.createElement(StarField, {
			accent = accent,
			reducedMotion = softMotion or heavyPage or quietPage or arcadeBusy or backgroundDetail < 0.58,
		})
	end
	local _condition_11 = state.Settings.AmbientGlow
	if _condition_11 == nil then
		_condition_11 = 1
	end
	local _condition_12 = _condition_11 >= 0.5
	if _condition_12 then
		_condition_12 = not suppressBackground and React.createElement(AmbientLayer, {
			accent = accent,
			reducedMotion = softMotion or heavyPage or quietPage or arcadeBusy,
			intensity = glowIntensity,
		})
	end
	local _condition_13 = state.Settings.AmbientGlow
	if _condition_13 == nil then
		_condition_13 = 1
	end
	local _condition_14 = _condition_13 >= 0.5
	if _condition_14 then
		_condition_14 = glowIntensity > 0.02 and backgroundDetail >= 0.45 and React.createElement("frame", {
			Size = UDim2.fromOffset(620, 620),
			Position = UDim2.new(1, 170, 1, 90),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = accent,
			BackgroundTransparency = 1 - 0.035 * math.clamp(glowIntensity, 0, 1),
			BorderSizePixel = 0,
			Rotation = -12,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	local _condition_15 = state.Settings.AmbientGlow
	if _condition_15 == nil then
		_condition_15 = 1
	end
	local _condition_16 = _condition_15 >= 0.5
	if _condition_16 then
		_condition_16 = glowIntensity > 0.02 and backgroundDetail >= 0.7 and React.createElement("frame", {
			Size = UDim2.fromOffset(420, 420),
			Position = UDim2.new(0, -170, 0, -130),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cyan,
			BackgroundTransparency = 1 - 0.025 * math.clamp(glowIntensity, 0, 1),
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	local _exp_4 = not keyboardShellCompact and mobileShell and React.createElement(MobileHeader, {
		state = state,
		page = page,
		accent = accent,
		width = viewport.width,
		topPad = topPad,
		barHeight = topbarHeight,
		edgePad = edgePad,
		reducedMotion = softMotion,
		openPlayerlist = function()
			setFeedbackOpen(false)
			setPlayerlistOpen(true)
		end,
		openSanctuary = function()
			if blockSanctuaryRef.current then
				return nil
			end
			setHidden(false)
			setSanctuaryOpen(true)
		end,
	})
	local _condition_17 = not keyboardShellCompact and not mobileShell
	if _condition_17 then
		local _attributes = {
			state = state,
			page = page,
			railOpen = railOpen,
			toggleRail = function()
				setRailOpen(not railOpen)
			end,
			hideUI = function()
				return setHidden(true)
			end,
			tight = viewport.tight,
			width = viewport.width,
			topPad = topPad,
			barHeight = topbarHeight,
			barHeightMotion = topbarLive,
			edgePad = edgePad,
			reducedMotion = softMotion,
		}
		local _condition_18 = config.Release.CountdownAt
		if _condition_18 == nil then
			_condition_18 = 1789272000
		end
		_attributes.releaseAt = _condition_18
		_attributes.visit = visit
		_attributes.openPlayerlist = function()
			setFeedbackOpen(false)
			setPlayerlistOpen(true)
		end
		_attributes.openFeedback = function()
			setPlayerlistOpen(false)
			setFeedbackOpen(true)
		end
		_attributes.openSanctuary = function()
			if blockSanctuaryRef.current then
				return nil
			end
			setHidden(false)
			setSanctuaryOpen(true)
		end
		_condition_17 = React.createElement(TopBar, _attributes)
	end
	-- Desktop MoreDock removed: secondary nav is in the sidebar via includeSecondary.
	local _condition_18 = false
	local _exp_5 = React.createElement(React.Fragment, nil, _condition_10, _condition_12, _condition_14, _condition_16, _exp_4, _condition_17, _condition_18)
	local _exp_6 = React.createElement("frame", {
		Size = workspaceSize,
		Position = workspaceOffset,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement(AntilagContext.Provider, {
		value = pageAntilag,
	}, React.createElement(Workspace, {
		page = page,
		state = state,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
	}, React.createElement(PageFrame, {
		page = page,
		ref = pageHostRef,
	}, React.createElement(PageContent, {
		key = page,
		page = page,
		state = state,
		config = config,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		domainOverlayActive = domainOverlayActive,
		openWorkshop = openWorkshop,
		openDomain = openDomain,
		buyAmount = buyAmount,
		setBuyAmount = setBuyAmount,
		onWheelLand = onWheelLand,
		wallClock = wallClock,
		activeBoostExpired = activeBoostExpired,
		clearConfetti = clearConfetti,
		chat = chat,
		visit = visit,
		setVisit = setVisit,
		addNotice = addNotice,
		crateRevealActive = crateReveal ~= nil,
		setCrateReveal = setCrateReveal,
		navigate = navigateStable,
		setArcadeBusy = setArcadeBusy,
		setPurchasePresentationActive = setPurchasePresentationActive,
	})))))
	local _exp_7 = not mobileShell and drawerNav and React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = drawerScrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Active = drawerScrimVisible,
		Visible = drawerScrimVisible,
		ZIndex = 28,
		Event = {
			Activated = function()
				setRailOpen(false)
				Audio:play("close")
			end,
		},
	})
	local _condition_19 = not mobileShell
	if _condition_19 then
		local _attributes = {
			page = page,
			setPage = navigate,
			collapsed = not drawerNav and viewport.compact,
			width = railWidth,
			fixedWidth = if drawerNav then drawerWidth else nil,
			reducedMotion = softMotion,
			state = state,
			chatUnread = chat.unread,
		}
		local _result_10 = tutorial
		if _result_10 ~= nil then
			_result_10 = _result_10.page
		end
		_attributes.tutorialPage = _result_10
		_attributes.includeSecondary = true
		_attributes.fromMore = false
		_attributes.activeBoost = activeBoost
		_attributes.activeBoostEndsAt = activeBoostEndsAt
		_attributes.wallClock = wallClock
		_attributes.openBoosts = function()
			return navigate("Rewards")
		end
		_condition_19 = React.createElement("frame", {
			Size = if drawerNav then UDim2.new(0, drawerWidth, 1, 0) else railWidth:map(function(width)
				return UDim2.new(0, math.max(0, width), 1, 0)
			end),
			Position = if drawerNav then drawerProgress:map(function(amount)
				return UDim2.new(0, -drawerWidth * (1 - amount), 0, 0)
			end) else nil,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = if drawerNav then 30 else 10,
			ClipsDescendants = true,
			Visible = if drawerNav then drawerScrimVisible else drawerPanelVisible,
		}, React.createElement(Navigation, _attributes))
	end
	local gamepadReserve = if gamepadActive then 44 else 0
	local _exp_8 = React.createElement("frame", {
		Size = shellTopLive:map(function(top)
			return UDim2.new(1, -edgePad * 2, 1, -(top + bottomPad + gamepadReserve))
		end),
		Position = shellTopLive:map(function(top)
			return UDim2.fromOffset(edgePad, top)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_6, _exp_7, _condition_19)
	local _result_10 = state.Trade
	if _result_10 ~= nil then
		_result_10 = _result_10.Session
	end
	local _condition_20 = _result_10 ~= nil
	if _condition_20 then
		_condition_20 = page ~= "Trade" and React.createElement(TradeReturnPill, {
			stack = chrome.stack,
			bottomPad = bottomPad,
			reducedMotion = softMotion,
			onReturn = function()
				setHidden(false)
				setRailOpen(false)
				navigate("Trade")
			end,
		})
	end
	local _condition_21 = mobileShell
	if _condition_21 then
		local _attributes = {
			page = page,
			setPage = navigate,
			state = state,
			chatUnread = chat.unread,
		}
		local _result_11 = tutorial
		if _result_11 ~= nil then
			_result_11 = _result_11.page
		end
		_attributes.tutorialPage = _result_11
		_attributes.reducedMotion = reducedMotion
		_attributes.height = tabBarH
		_attributes.bottomSafe = chrome.bottomSafe
		_attributes.visible = not keyboardShellCompact
		_attributes.viewportHeight = viewport.height
		_attributes.moreCols = chrome.moreCols
		_attributes.moreCellH = chrome.moreCellH
		_condition_21 = React.createElement(MobileTabBar, _attributes)
	end
	local _exp_9 = mobileShell and quickActionsVisible and React.createElement(MobileQuickActions, {
		state = state,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		bottomOffset = quickBottomOffset,
		edgePad = edgePad,
	})
	local _exp_10 = not hidden and React.createElement(ComboBadge, {
		readout = comboReadout,
		reducedMotion = reducedMotion,
		position = UDim2.new(1, -18, 0, topPad + topbarHeight + 8),
		anchorPoint = Vector2.new(1, 0),
		zIndex = 65,
	})
	local _exp_11 = renderEffectsScale > 0.05 and React.createElement(EffectLayer, {
		pops = visiblePops,
	})
	local _condition_22 = confettiNonce > 0
	if _condition_22 then
		local _attributes = {
			key = confettiNonce,
			seed = confettiNonce,
			intensity = math.max(0.08, renderEffectsScale),
			reducedMotion = softMotion,
		}
		local _condition_23 = state.Settings.ConfettiEnabled
		if _condition_23 == nil then
			_condition_23 = 1
		end
		_attributes.particlesEnabled = _condition_23 >= 0.5
		_attributes.onDone = clearConfetti
		_condition_22 = React.createElement(CelebrationBurst, _attributes)
	end
	local _exp_12 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = hideAmount:map(function(amount)
			local base = UDim2.new(0, 0, amount * 1.05, 0)
			return base
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_5, _exp_8, React.createElement(React.Fragment, nil, _condition_20, _condition_21, _exp_9, _exp_10, _exp_11, _condition_22))
	local _exp_13 = React.createElement("frame", {
		Size = UDim2.fromOffset(186, 44),
		Position = hideAmount:map(function(amount)
			return UDim2.new(0, edgePad, 0, -64 + math.floor(amount * (topPad + 64)))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 200,
	}, React.createElement(Button, {
		text = "SHOW UI  ( ` )",
		icon = "Hide",
		onClick = function()
			return setHidden(false)
		end,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))
	local ownedMachines = 0
	local machineTable = state.Machines
	if type(machineTable) == "table" then
		for _, level in machineTable do
			local amount = level
			if type(amount) == "table" then
				amount = amount.Level or amount.level or 0
			end
			if type(amount) == "number" and amount > 0 then
				ownedMachines += 1
			end
		end
	end
	local _exp_14 = not state.Flags.TutorialDone and tutorial ~= nil and React.createElement(TutorialOverlay, {
		copy = tutorial,
		step = tutorialStep,
		count = #TUTORIAL_STEPS,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		reducedMotion = reducedMotion,
		live = {
			page = page,
			vault = compactNumber(state.Vault),
			vaultFlux = asFlux(state.Vault),
			production = compactNumber(state.Production),
			ownedMachines = ownedMachines,
			buyAmount = buyAmount,
		},
		ctaLabel = tutorial.ctaLabel,
		onCta = if tutorial.cta == "collect" then function()
			return dispatch("CollectVault")
		end elseif tutorial.cta == "workshop" then function()
			return navigate("Workshop")
		end elseif tutorial.cta == "research" then function()
			return navigate("Research")
		end else nil,
		onJump = function(n)
			local targetStep = math.clamp(math.floor(n), 1, #TUTORIAL_STEPS)
			tutorialHold.current = targetStep
			setTutorialStep(targetStep)
			dispatch("SetTutorialStep", {
				Step = targetStep,
			})
		end,
		onBack = function()
			local targetStep = math.max(1, tutorialStep - 1)
			tutorialHold.current = targetStep
			setTutorialStep(targetStep)
			dispatch("SetTutorialStep", {
				Step = targetStep,
			})
		end,
		onNext = function()
			if tutorialStep >= #TUTORIAL_STEPS then
				dispatch("CompleteTutorial")
			else
				local targetStep = tutorialStep + 1
				tutorialHold.current = targetStep
				setTutorialStep(targetStep)
				dispatch("SetTutorialStep", {
					Step = targetStep,
				})
			end
		end,
		onSkip = function()
			return dispatch("CompleteTutorial")
		end,
	})
	local _condition_23 = gamepadActive and not hidden and not tutorialOpen
	if _condition_23 then
		local _exp_15 = require(script.Parent.input.GamepadNavigationService).GetHintLabels()
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_15)
		local _callback = function(hint, index)
			return React.createElement(FlexItem, {
				key = hint,
				mode = "grow",
				minWidth = 88,
				minHeight = 22,
				layoutOrder = index,
			}, React.createElement(Text, {
				value = hint,
				size = 11,
				color = Palette.creamSoft,
				align = Enum.TextXAlignment.Center,
				fit = true,
				minSize = 9,
				sizeConstraint = UDim2.fromScale(1, 1),
			}))
		end
		for _k, _v in _exp_15 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_15)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_23 = React.createElement("frame", {
			Size = UDim2.new(1, -edgePad * 2, 0, 36),
			Position = UDim2.new(0, edgePad, 1, -(bottomPad + 36)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 180,
		}, React.createElement(Flex, {
			direction = "row",
			wrap = true,
			justify = "space-evenly",
			align = "center",
			gap = 10,
			size = UDim2.fromScale(1, 1),
			exact = true,
		}, _newValue))
	end
	local _exp_15 = showRelease and React.createElement(ReleaseNotesModal, {
		version = config.Game.Version,
		season = config.Release.Season,
		announcement = config.Release.Announcement,
		notes = config.Release.Notes,
		history = config.Release.History,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		reducedMotion = reducedMotion,
		onClose = function()
			setReleaseClosedLocally(true)
			dispatch("DismissRelease")
		end,
		onOpenMail = function()
			Audio:play("mail")
			setReleaseClosedLocally(true)
			dispatch("DismissRelease")
			setPage("Mail")
		end,
	})
	local _exp_16 = page == "Credits" and React.createElement(CreditsOverlay, {
		version = state.Game.Version,
		reducedMotion = reducedMotion,
		onClose = function()
			return navigate("Overview")
		end,
	})
	local _exp_17 = playerlistOpen and React.createElement(PlayerlistOverlay, {
		state = state,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		onClose = function()
			return setPlayerlistOpen(false)
		end,
		notify = function(title, body)
			return addNotice(title, body, "Info")
		end,
	})
	local _exp_18 = feedbackOpen and React.createElement(FeedbackOverlay, {
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		onClose = function()
			return setFeedbackOpen(false)
		end,
		notify = function(title, body)
			return addNotice(title, body, "Info")
		end,
	})
	local _condition_24 = offlineRewardsOpen
	if _condition_24 then
		local _attributes = {}
		local _result_11 = state.Offline
		if _result_11 ~= nil then
			_result_11 = _result_11.Reward
		end
		local _condition_25 = _result_11
		if _condition_25 == nil then
			_condition_25 = 0
		end
		_attributes.reward = _condition_25
		local _result_12 = state.Offline
		if _result_12 ~= nil then
			_result_12 = _result_12.Seconds
		end
		local _condition_26 = _result_12
		if _condition_26 == nil then
			_condition_26 = 0
		end
		_attributes.seconds = _condition_26
		local _result_13 = state.Offline
		if _result_13 ~= nil then
			_result_13 = _result_13.Efficiency
		end
		local _condition_27 = _result_13
		if _condition_27 == nil then
			_condition_27 = state.OfflineEfficiency
		end
		_attributes.efficiency = _condition_27
		local _result_14 = state.Offline
		if _result_14 ~= nil then
			_result_14 = _result_14.Capped
		end
		_attributes.capped = _result_14 == true
		local _result_15 = state.Offline
		if _result_15 ~= nil then
			_result_15 = _result_15.Production
		end
		local _condition_28 = _result_15
		if _condition_28 == nil then
			_condition_28 = state.Production
		end
		_attributes.production = _condition_28
		local _result_16 = state.Offline
		if _result_16 ~= nil then
			_result_16 = _result_16.AwaySeconds
		end
		_attributes.awaySeconds = _result_16
		local _result_17 = state.Offline
		if _result_17 ~= nil then
			_result_17 = _result_17.CapHours
		end
		local _condition_29 = _result_17
		if _condition_29 == nil then
			_condition_29 = state.OfflineHours
		end
		_attributes.capHours = _condition_29
		local _result_18 = state.Offline
		if _result_18 ~= nil then
			_result_18 = _result_18.Vault
		end
		local _condition_30 = _result_18
		if _condition_30 == nil then
			_condition_30 = state.Vault
		end
		_attributes.vault = _condition_30
		_attributes.reducedMotion = reducedMotion
		local _condition_31 = state.Settings.OfflineRewardEffects
		if _condition_31 == nil then
			_condition_31 = 1
		end
		_attributes.effectsEnabled = _condition_31 >= 0.5
		_attributes.onCollect = function()
			return dispatch("CollectVault")
		end
		_attributes.onClose = function()
			return setDismissedOfflineKey(offlineReceiptKey)
		end
		_condition_24 = React.createElement(OfflineRewardsOverlay, _attributes)
	end
	return React.createElement(AntilagContext.Provider, {
		value = rootAntilag,
	}, React.createElement(React.Fragment, nil, React.createElement(SplitCurtain, {
		open = riftOpen,
		reducedMotion = reducedMotion,
		onNavigate = function(pageId)
			setSanctuaryOpen(false)
			navigateStable(pageId)
		end,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = hideAmount,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = not arcadeBusy and crateReveal == nil,
	}, _exp_2, _exp_3, _exp_12, _exp_13, _exp_14, _condition_23, _exp_15, _exp_16, _exp_17, _exp_18, _condition_24, not bootChromeVisible and React.createElement(MobilePreviewGate, {
		ack = state.Settings.MobilePreviewAck,
		reducedMotion = reducedMotion,
		dispatch = dispatch,
	}))), crateReveal ~= nil and React.createElement(CrateRevealOverlay, {
		session = crateReveal,
		config = config,
		reducedMotion = reducedMotion,
		onClose = function()
			return setCrateReveal(nil)
		end,
	})))
end
local function Shell(props)
	local _attributes = table.clone(props)
	setmetatable(_attributes, nil)
	return React.createElement(AppShell, _attributes)
end

return {
	AppShell = AppShell,
	Shell = Shell,
	pausePassivePaints = pausePassivePaints,
}
