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
local _MobileShell = require(script.Parent.MobileShell)
local MobileHeader = _MobileShell.MobileHeader
local MobileQuickActions = _MobileShell.MobileQuickActions
local MobileTabBar = _MobileShell.MobileTabBar
local _flexbox = require(script.Parent.flexbox)
local Flex = _flexbox.Flex
local FlexItem = _flexbox.FlexItem
local _interaction = require(script.Parent.interaction)
local setHapticIntensity = _interaction.setHapticIntensity
local usesDesktopStructure = _interaction.usesDesktopStructure
local Icon = require(script.Parent.Icon).Icon
local _effects = require(script.Parent.effects)
local EffectLayer = _effects.EffectLayer
local POP_SECONDS = _effects.POP_SECONDS
local StarField = _effects.StarField
local CelebrationBurst = require(script.Parent.CelebrationBurst).CelebrationBurst
local ComboBadge = require(script.Parent.ComboBadge).ComboBadge
local AutoScale = require(script.Parent.autoScale).AutoScale
local _antilag = require(script.Parent.antilag)
local AntilagContext = _antilag.AntilagContext
local AntilagProvider = _antilag.AntilagProvider
local clampAntilagTier = _antilag.clampAntilagTier
local setAntilagPreference = _antilag.setAntilagPreference
local setAntilagScene = _antilag.setAntilagScene
local useAntilag = _antilag.useAntilag
local usePerformanceTelemetry = _antilag.usePerformanceTelemetry
local _motion = require(script.Parent.motion)
local beginUiTransition = _motion.beginUiTransition
local EntranceMotionSuppressedContext = _motion.EntranceMotionSuppressedContext
local MotionSettingsContext = _motion.MotionSettingsContext
local setClockBudget = _motion.setClockBudget
local setDecorativeMotionFrozen = _motion.setDecorativeMotionFrozen
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useGlowStroke = _motion.useGlowStroke
local usePulse = _motion.usePulse
local useTokenEntrance = _motion.useTokenEntrance
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local ToastRail = require(script.Parent.notifications).ToastRail
local _ui = require(script.Parent.ui)
local acquireDropdownPortal = _ui.acquireDropdownPortal
local Button = _ui.Button
local ButtonShimmer = _ui.ButtonShimmer
local CountBadge = _ui.CountBadge
local IconTile = _ui.IconTile
local LogoLockup = _ui.LogoLockup
local meterFill = _ui.meterFill
local ScrollEdgeFade = _ui.ScrollEdgeFade
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local releaseDropdownPortal = _ui.releaseDropdownPortal
local subscribeInputCancellation = _ui.subscribeInputCancellation
local useButtonChrome = _ui.useButtonChrome
local NumberSpinnerHost = require(script.Parent.NumberSpinnerHost).NumberSpinnerHost
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
local CreditsOverlay = require(script.Parent.pages.CreditsView).CreditsOverlay
local CrateRevealOverlay = require(script.Parent.pages.CrateRevealOverlay).CrateRevealOverlay
local PageContent = require(script.Parent.pages.PageRouter).PageContent
local _AdminPrankOverlay = require(script.Parent.AdminPrankOverlay)
local AdminPrankOverlay = _AdminPrankOverlay.AdminPrankOverlay
local HudPrankStage = _AdminPrankOverlay.HudPrankStage
local useGameChat = require(script.Parent.chat).useGameChat
local _appNav = require(script.Parent.appNav)
local AppHelpers = _appNav.AppHelpers
local MORE_NAV = _appNav.MORE_NAV
local PRIMARY_NAV = _appNav.PRIMARY_NAV
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
local _onboarding = require(script.Parent.onboarding)
local ReleaseNotesModal = _onboarding.ReleaseNotesModal
local TutorialOverlay = _onboarding.TutorialOverlay
local _scrolling = require(script.Parent.scrolling)
local setScrollMomentum = _scrolling.setScrollMomentum
local setScrollSpeed = _scrolling.setScrollSpeed
local _clientStore = require(script.Parent.clientStore)
local ClientActions = _clientStore.ClientActions
local useClientDispatch = _clientStore.useClientDispatch
local useClientSelector = _clientStore.useClientSelector
local preloadMountedGame = require(script.Parent.assetPreloader).preloadMountedGame
local useClientIntegrityProbe = require(script.Parent.clientIntegrity).useClientIntegrityProbe
local PlayerlistOverlay = require(script.Parent.PlayerlistOverlay).PlayerlistOverlay
local MobilePreviewGate = require(script.Parent.MobilePreviewGate).MobilePreviewGate
local OfflineRewardsOverlay = require(script.Parent.OfflineRewardsOverlay).OfflineRewardsOverlay
local FeedbackOverlay = require(script.Parent.FeedbackOverlay).FeedbackOverlay
local PLAYER_COPY = {
	["that request could not be validated."] = "That didn't go through. Try again.",
	["the server is still finishing an earlier request."] = "Still working on your last tap.",
	["the connection is busy. try again in a moment."] = "Things are a little busy. Try again in a moment.",
	["the server took too long. try again."] = "That took too long. Try again.",
	["the server did not answer that click."] = "That tap didn't go through. Try again.",
	["action rejected."] = "That move isn't available right now.",
	["malformed admin request."] = "Check the command fields and try again.",
	["invalid action payload"] = "That option isn't available.",
	["invalid action payload."] = "That option isn't available.",
	["the forge encountered an error. please try again."] = "Something went wrong. Please try again.",
	["the forge returned an invalid response. please try again."] = "That didn't go through. Please try again.",
	["request rejected."] = "That move isn't available right now.",
	["payload is required"] = "That option isn't available.",
	["payload must be a table"] = "That option isn't available.",
	["this action does not accept a payload"] = "That option isn't available.",
	["invalid expedition"] = "Pick an expedition first.",
	["invalid artifact"] = "Choose an artifact first.",
	["invalid signal offer"] = "That signal offer isn't available.",
	["invalid title selection"] = "Choose a title to wear.",
	["invalid boost selection"] = "Choose a boost to activate.",
	["invalid shop offer"] = "That shop offer isn't available.",
	["invalid protocol"] = "That protocol isn't available.",
	["invalid reactor channel"] = "Pick a reactor channel.",
	["invalid story chapter"] = "That chapter isn't available.",
	["invalid mail"] = "That message isn't available.",
	["invalid guild upgrade"] = "That guild upgrade isn't available.",
	["invalid follow verification payload"] = "Couldn't check that follow.",
	["invalid code payload"] = "Enter a code first.",
	["invalid upgrade payload"] = "Choose an upgrade and try again.",
	["invalid claim payload"] = "That reward isn't ready to claim.",
	["invalid reward payload"] = "That reward isn't ready to claim.",
	["invalid progression payload"] = "That level isn't ready yet.",
	["invalid world payload"] = "That world isn't available yet.",
}
local INTERNAL_PAYLOAD_COPY = {
	["invalid action payload"] = true,
	["invalid action payload."] = true,
	["payload is required"] = true,
	["payload must be a table"] = true,
	["this action does not accept a payload"] = true,
	["that option isn't available."] = true,
	["that option isn't available"] = true,
	["check that choice and try again."] = true,
	["check that choice and try again"] = true,
	["that request could not be validated."] = true,
	["that request could not be validated"] = true,
	["that didn't go through. try again."] = true,
	["that didn't go through. try again"] = true,
}
local function friendlyPlayerMessage(value)
	if value == nil or #value == 0 then
		return nil
	end
	local _condition = PLAYER_COPY[value]
	if _condition == nil then
		_condition = PLAYER_COPY[string.lower(value)]
	end
	local exact = _condition
	if exact ~= nil then
		return exact
	end
	return value
end
-- Every failed action used to collapse onto one of two titles ("Couldn't do that" /
-- "Still locked") regardless of what was actually attempted, so the small, genuinely
-- varied body text underneath read as "always the same thing" — the big unchanging
-- title dominated. This derives a title from the action's own name/verb instead, so a
-- failed claim, purchase, equip, and trade action each get a title that matches what the
-- player was actually doing.
local FAILURE_TITLE_PREFIXES = { { "Claim", "Couldn't claim" }, { "Buy", "Couldn't buy" }, { "Upgrade", "Couldn't upgrade" }, { "Unlock", "Couldn't unlock" }, { "Equip", "Couldn't equip" }, { "Unequip", "Couldn't unequip" }, { "Salvage", "Couldn't salvage" }, { "Set", "Couldn't update" }, { "Toggle", "Couldn't update" }, { "Start", "Couldn't start" }, { "Launch", "Couldn't launch" }, { "Join", "Couldn't join" }, { "Leave", "Couldn't leave" }, { "Create", "Couldn't create" }, { "Invite", "Couldn't invite" }, { "Respond", "Trade issue" }, { "Confirm", "Trade issue" }, { "Cancel", "Trade issue" }, { "Update", "Trade issue" }, { "Contribute", "Couldn't contribute" }, { "Kick", "Couldn't remove them" }, { "Report", "Couldn't send that" }, { "Redeem", "Couldn't redeem" }, { "Spin", "Couldn't spin" }, { "Select", "Couldn't travel" }, { "Route", "Couldn't route power" }, { "Stabilize", "Couldn't stabilize" }, { "Pulse", "Couldn't pulse" }, { "Capture", "Couldn't capture" }, { "Dismantle", "Couldn't dismantle" }, { "Open", "Couldn't open" }, { "Read", "Couldn't open" }, { "Delete", "Couldn't delete" }, { "Rebirth", "Couldn't rebirth" }, { "Verify", "Follow" } }
local function failureTitle(action, gated)
	if gated then
		return "Still locked"
	end
	if action == "VerifyCreatorFollow" then
		return "Follow"
	end
	for _, _binding in FAILURE_TITLE_PREFIXES do
		local prefix = _binding[1]
		local title = _binding[2]
		if string.sub(action, 1, #prefix) == prefix then
			return title
		end
	end
	return "Couldn't do that"
end
local FAILURE_BODY_BY_ACTION = {
	LaunchExpedition = "Pick an expedition first.",
	ClaimExpedition = "That expedition isn't back yet.",
	EquipArtifact = "Choose an artifact to equip.",
	UpgradeArtifact = "Choose an artifact to upgrade.",
	BuySignalOffer = "That signal offer isn't available.",
	EquipTitle = "Choose a title to wear.",
	ActivateBoost = "Choose a boost to activate.",
	BuyItemOffer = "That shop offer isn't available.",
	BuyAnomalyProtocol = "That protocol isn't available.",
	SetAnomalyChannel = "Pick a reactor channel.",
	ReadStoryChapter = "That chapter isn't available.",
	ClaimStoryChapter = "That chapter isn't ready to claim.",
	ReadMail = "That message isn't available.",
	ClaimMail = "That mail isn't ready to claim.",
	DeleteMail = "That message isn't available.",
	BuyGuildUpgrade = "That guild upgrade isn't available.",
	BuyMachine = "That station isn't available.",
	BuyResearch = "That research isn't available.",
	Overcharge = "That station isn't ready to overcharge.",
	CollectVault = "Nothing to collect yet.",
	Rebirth = "You aren't ready to rebirth yet.",
	VerifyCreatorFollow = "Couldn't check that follow.",
	RedeemCode = "Enter a code first.",
}
local function failureBody(action, raw)
	local lowered = string.lower(raw)
	if INTERNAL_PAYLOAD_COPY[lowered] ~= nil then
		local _condition = FAILURE_BODY_BY_ACTION[action]
		if _condition == nil then
			_condition = "That option isn't available."
		end
		return _condition
	end
	local _condition = friendlyPlayerMessage(raw)
	if _condition == nil then
		_condition = raw
	end
	return _condition
end
local function TradeReturnPill(_param)
	local stack = _param.stack
	local bottomPad = _param.bottomPad
	local reducedMotion = _param.reducedMotion
	local onReturn = _param.onReturn
	local enter = useEntrance(reducedMotion)
	local pulse = usePulse(not reducedMotion, 1.35)
	local width = if stack then 176 else 198
	local height = if stack then 48 else 46
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = enter:map(function(amount)
			return UDim2.new(0.5, 0, 1, -(bottomPad + (if stack then 10 else 16) - math.round((1 - amount) * 22)))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(amount)
			return 1 + amount * 0.03
		end),
	}), React.createElement(Button, {
		text = "BACK TO TRADE",
		icon = "Visit",
		onClick = onReturn,
		sound = "open",
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
	}))
end
local function friendlyActionResponse(response)
	local message = friendlyPlayerMessage(response.message)
	local friendlyError = friendlyPlayerMessage(response.error)
	if message == response.message and friendlyError == response.error then
		return response
	end
	local _object = table.clone(response)
	setmetatable(_object, nil)
	_object.message = message
	_object.error = friendlyError
	return _object
end
local pausePassivePaints = {
	current = false,
}
local TUTORIAL_STEPS = { {
	title = "This is your forge",
	goal = "Look at the vault",
	body = "Machines make Flux on their own. It piles up in the Vault until you cash it out. A full vault stops making money.",
	hint = "The green number is what you've stored.",
	controls = "Tap CONTINUE  ·  Xbox: A",
	page = "Overview",
}, {
	title = "Cash it out",
	goal = "Collect the vault",
	body = "Collect turns stored Flux into cash you can spend. Empty it often — a full vault wastes production.",
	hint = "Use COLLECT VAULT below, or the green Collect button on this page.",
	controls = "Keyboard: E   ·   Xbox: Y",
	page = "Overview",
	cta = "collect",
	ctaLabel = "COLLECT VAULT",
}, {
	title = "Buy a machine",
	goal = "Buy Stellar Core",
	body = "Open Workshop and buy Stellar Core. That's your first income. Each level makes more Flux per second.",
	hint = "If Buy is grey, collect the vault first, then come back.",
	controls = "Xbox: A opens Workshop",
	page = "Workshop",
	cta = "workshop",
	ctaLabel = "OPEN WORKSHOP",
}, {
	title = "Buy faster",
	goal = "Try x5 or MAX",
	body = "x1 buys one level. x5 buys five. MAX spends what you can afford and never overspends.",
	hint = "Stay on x1 until prices make sense.",
	controls = "Xbox: LT / RT changes buy amount",
	page = "Workshop",
}, {
	title = "Research never resets",
	goal = "Open Research",
	body = "Research bonuses survive rebirth. Buy the lit nodes in order. Grey nodes tell you what's missing.",
	hint = "If Research is locked, skip this — it unlocks after a little play.",
	controls = "Xbox: A opens Research",
	page = "Research",
	cta = "research",
	ctaLabel = "OPEN RESEARCH",
}, {
	title = "Rebirth for cores",
	goal = "Read the rebirth panel",
	body = "When you're ready, rebirth trades this run's machines for Cores. Research, relics, and Stardust stay. Cores make the next run stronger.",
	hint = "Don't rush it. Overview shows the payout before you confirm.",
	controls = "Tap CONTINUE when you've read the panel",
	page = "Overview",
}, {
	title = "You're set",
	goal = "Finish the guide",
	body = "That's the loop: collect, buy machines, research, rebirth. Everything else unlocks as you play. Replay this anytime from Settings → GUIDE.",
	hint = "You get a small Flux bonus for finishing.",
	controls = "Tap FINISH  ·  Xbox: A",
	page = "Overview",
} }
local SHELL_CHROME = {
	railGutter = 18,
	topbarControl = 48,
	topbarControlGap = 12,
}
local NETWORK = {
	actionCooldowns = {
		GetState = 0.24,
		GetPlayers = 0.28,
		GetPlayerMirror = 0.28,
		VisitPlot = 0.52,
		LeavePlot = 0.35,
		NudgeCrew = 2.7,
		ReportPresence = 1.6,
		CollectVault = 0.04,
		Overcharge = 0.05,
		PulseAnomaly = 0.05,
		SpinWheel = 1.4,
		OpenItemCrate = 0.24,
		UpgradeContinuum = 0.4,
		CaptureEcho = 1.2,
		ClaimEcho = 0.48,
		EquipEcho = 0.24,
		UpgradeEcho = 0.3,
		DismantleEcho = 0.6,
		SetAutoForge = 0.28,
		SetItemAutoSalvage = 0.2,
		BulkSalvageItems = 0.35,
		SetSetting = 0.18,
		SetMobileLayout = 0.35,
		SetTutorialStep = 0.18,
		ClaimLabOrder = 0.18,
		RouteLabPower = 0.12,
		ReadStoryChapter = 0.18,
		ClaimStoryChapter = 0.18,
		ReadMail = 0.18,
		ClaimMail = 0.18,
		ClaimAllMail = 0.75,
		DeleteMail = 0.18,
		RedeemCode = 1.5,
		SyncShop = 1.3,
		StudioGrantProduct = 0.45,
		GetTrade = 0.2,
		InviteTrade = 0.7,
		RespondTrade = 0.28,
		UpdateTradeOffer = 0.08,
		SetTradeReady = 0.12,
		ConfirmTrade = 0.28,
		CancelTrade = 0.2,
		TradeViewAway = 0.2,
		DomainExpansion = 5.2,
		ClaimConvergenceReward = 0.45,
		GetLeaderboard = 1.1,
		GetGuildLeaderboard = 1.1,
		GetAdminState = 0.9,
		ReportClientIntegrity = 30.5,
		AdminExecute = 0.9,
		CreateGuild = 2.1,
		JoinGuild = 1.1,
		GetGuild = 0.32,
		KickGuildMember = 0.6,
		SetGuildRole = 0.6,
		ContributeGuild = 0.45,
		BuyGuildUpgrade = 0.8,
		LeaveGuild = 1.1,
	},
	requestTimeouts = {
		GetState = 8,
		GetPlayers = 8,
		GetPlayerMirror = 8,
		GetGuild = 8,
		GetGuildLeaderboard = 8,
		GetLeaderboard = 8,
		GetAdminState = 8,
	},
	defaultRequestTimeout = 15,
	maxPhysicalRequests = 12,
	pipelinedActions = {
		["Overcharge"] = true,
		["PulseAnomaly"] = true,
		["CollectVault"] = true,
		["RouteLabPower"] = true,
		["SetAutoForge"] = true,
		["SetAnomalyChannel"] = true,
		["SetSetting"] = true,
		["SetMobileLayout"] = true,
		["SetTutorialStep"] = true,
		["ReplayTutorial"] = true,
		["DismissRelease"] = true,
		["OpenRelease"] = true,
		["ReadStoryChapter"] = true,
		["ReadMail"] = true,
		["SelectZone"] = true,
		["UpdateTradeOffer"] = true,
		["SetTradeReady"] = true,
		["ConfirmTrade"] = true,
		["CancelTrade"] = true,
		["RespondTrade"] = true,
		["TradeViewAway"] = true,
		["SetItemAutoSalvage"] = true,
		["ReportPresence"] = true,
	},
	optimisticActions = {
		["CollectVault"] = true,
		["Overcharge"] = true,
		["RouteLabPower"] = true,
		["SetAutoForge"] = true,
		["SetAnomalyChannel"] = true,
		["SetSetting"] = true,
		["SetMobileLayout"] = true,
		["SetTutorialStep"] = true,
		["CompleteTutorial"] = true,
		["ReplayTutorial"] = true,
		["DismissRelease"] = true,
		["OpenRelease"] = true,
		["ReadStoryChapter"] = true,
		["ReadMail"] = true,
		["SelectZone"] = true,
		["EquipTitle"] = true,
		["ReportPresence"] = true,
	},
}
local CONFETTI_PIECES = { {
	x = -240,
	y = 12,
	size = 7,
	phase = 0.2,
	color = Palette.green,
}, {
	x = -208,
	y = 42,
	size = 5,
	phase = 1.1,
	color = Palette.cyan,
}, {
	x = -176,
	y = 4,
	size = 8,
	phase = 2.0,
	color = Palette.mango,
}, {
	x = -142,
	y = 28,
	size = 6,
	phase = 2.8,
	color = Palette.pink,
}, {
	x = -108,
	y = 66,
	size = 5,
	phase = 3.6,
	color = Palette.violet,
}, {
	x = -72,
	y = 16,
	size = 8,
	phase = 4.5,
	color = Palette.green,
}, {
	x = -34,
	y = 52,
	size = 6,
	phase = 5.4,
	color = Palette.cyan,
}, {
	x = 18,
	y = 8,
	size = 7,
	phase = 6.1,
	color = Palette.mango,
}, {
	x = 56,
	y = 58,
	size = 5,
	phase = 0.7,
	color = Palette.pink,
}, {
	x = 94,
	y = 20,
	size = 8,
	phase = 1.8,
	color = Palette.violet,
}, {
	x = 132,
	y = 74,
	size = 6,
	phase = 2.9,
	color = Palette.green,
}, {
	x = 168,
	y = 24,
	size = 5,
	phase = 3.8,
	color = Palette.cyan,
}, {
	x = 204,
	y = 50,
	size = 8,
	phase = 4.8,
	color = Palette.mango,
}, {
	x = 238,
	y = 10,
	size = 6,
	phase = 5.7,
	color = Palette.pink,
}, {
	x = -268,
	y = 34,
	size = 6,
	phase = 0.9,
	color = Palette.cyan,
}, {
	x = -224,
	y = 72,
	size = 8,
	phase = 2.4,
	color = Palette.violet,
}, {
	x = -158,
	y = 18,
	size = 5,
	phase = 4.1,
	color = Palette.green,
}, {
	x = -88,
	y = 82,
	size = 7,
	phase = 5.9,
	color = Palette.mango,
}, {
	x = -12,
	y = 34,
	size = 5,
	phase = 1.5,
	color = Palette.cream,
}, {
	x = 74,
	y = 78,
	size = 8,
	phase = 3.2,
	color = Palette.coral,
}, {
	x = 146,
	y = 36,
	size = 6,
	phase = 4.9,
	color = Palette.mint,
}, {
	x = 214,
	y = 86,
	size = 5,
	phase = 0.4,
	color = Palette.pink,
}, {
	x = 274,
	y = 26,
	size = 7,
	phase = 2.1,
	color = Palette.cyan,
}, {
	x = 112,
	y = 8,
	size = 6,
	phase = 5.1,
	color = Palette.cream,
} }
local function AmbientLayer(_param)
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	local strength = math.clamp(intensity, 0, 1)
	local enabled = not reducedMotion and antilag.allowAmbient and strength > 0.02
	local slow = useClock(enabled, 0.17)
	local breath = useClock(enabled, 0.09)
	local orbA = slow:map(function(phase)
		return UDim2.new(0, 130 + math.sin(phase) * 30, 0, 108 + math.cos(phase) * 20)
	end)
	local orbScale = breath:map(function(phase)
		return 1 + math.sin(phase) * 0.12 * antilag.glowScale * strength
	end)
	if not enabled then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(240, 240),
		Position = orbA,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1 - 0.03 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = orbScale,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function ConfettiBurst(_param)
	local onDone = _param.onDone
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	local clock = useClock(antilag.allowConfetti, 1, 1000, true)
	React.useEffect(function()
		if not antilag.allowConfetti then
			onDone()
			return nil
		end
		local alive = true
		local completion = task.delay(2.15, function()
			if alive then
				onDone()
			end
		end)
		return function()
			alive = false
			task.cancel(completion)
		end
	end, { antilag.allowConfetti, onDone })
	if not antilag.allowConfetti then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local activeCount = math.clamp(math.floor(#CONFETTI_PIECES * math.clamp(intensity, 0, 1.5) * math.max(0.34, antilag.fxBudget)), 0, #CONFETTI_PIECES)
	if activeCount <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local pieces = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(piece, index)
		if index < activeCount then
			local _piece = piece
			table.insert(pieces, _piece)
		end
	end
	for _k, _v in CONFETTI_PIECES do
		_callback(_v, _k - 1, CONFETTI_PIECES)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local _exp = { 0, 1 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp)
	local _callback_1 = function(ring)
		return React.createElement("frame", {
			key = `confetti-ring-{ring}`,
			Size = clock:map(function(seconds)
				local t = math.clamp((seconds - ring * 0.08) / 0.52, 0, 1)
				return UDim2.fromOffset(24 + t * (170 + ring * 46), 24 + t * (170 + ring * 46))
			end),
			Position = UDim2.fromScale(0.5, 0.56),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 141,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 0 then Palette.mango else Palette.cyan,
			Thickness = if ring == 0 then 3 else 2,
			Transparency = clock:map(function(seconds)
				local t = math.clamp((seconds - ring * 0.08) / 0.52, 0, 1)
				return 0.14 + t * 0.86
			end),
		}))
	end
	for _k, _v in _exp do
		_newValue[_k] = _callback_1(_v, _k - 1, _exp)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#pieces)
	local _callback_2 = function(piece, index)
		local delay = (index % 5) * 0.035
		local ribbon = index % 3 == 0
		local progress = clock:map(function(seconds)
			return math.clamp((seconds - delay) / 1.92, 0, 1)
		end)
		local size = progress:map(function(t)
			local flip = 0.22 + math.abs(math.sin(t * math.pi * (3.5 + index % 3) + piece.phase)) * 0.78
			return UDim2.fromOffset(math.max(2, piece.size * flip), piece.size * (if ribbon then 3.2 else 1.75))
		end)
		local position = progress:map(function(t)
			local side = if index % 2 == 0 then -1 else 1
			local startX = 0.5 + side * 0.1
			local spread = piece.x / 590
			local x = startX + spread * (0.18 + t * 0.92) + math.sin(t * 13 + piece.phase) * 0.018
			local y = 0.58 - 1.62 * t + 2.06 * t * t + piece.y / 3200
			return UDim2.fromScale(x, y)
		end)
		local fade = progress:map(function(t)
			return if t <= 0 then 1 else math.clamp((t - 0.7) / 0.3, 0.04, 1)
		end)
		return React.createElement("frame", {
			key = index,
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = progress:map(function(t)
				return piece.phase * 31 + t * (if index % 2 == 0 then 760 else -680)
			end),
			BackgroundColor3 = piece.color,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			ZIndex = 142 + index % 3,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, if ribbon then 1 else 2),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(piece.color, 0.34), darken(piece.color, 0.18)),
			Rotation = 90,
		}))
	end
	for _k, _v in pieces do
		_newValue_1[_k] = _callback_2(_v, _k - 1, pieces)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 140,
		Active = false,
	}, _newValue, _newValue_1)
end
local CHIP_TIPS = {
	FLUX = {
		title = "Flux",
		body = "Spendable cash from your vault. Bank production, then buy machines and research.",
	},
	DUST = {
		title = "Stardust",
		body = "Premium dust from rebirths and rewards. Spend it on Star Grid routes.",
	},
	CORES = {
		title = "Astral cores",
		body = "Permanent rebirth currency. Multiplies future runs and unlocks prestige tech.",
	},
}
local function StatChip(_param)
	local label = _param.label
	local value = _param.value
	local icon = _param.icon
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local velocity = _param.velocity
	if velocity == nil then
		velocity = 0
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local tall = _param.tall
	if tall == nil then
		tall = false
	end
	local reactiveFlash = _param.reactiveFlash
	if reactiveFlash == nil then
		reactiveFlash = true
	end
	local placeholder = _param.placeholder
	local showLabel = _param.showLabel
	if showLabel == nil then
		showLabel = true
	end
	local animateValue = _param.animateValue
	if animateValue == nil then
		animateValue = true
	end
	local gains, setGains = React.useState(0)
	local previous = React.useRef(value)
	React.useEffect(function()
		if reactiveFlash and asFlux(value) > asFlux(previous.current) then
			setGains(function(current)
				return current + 1
			end)
		end
		previous.current = value
	end, { value, reactiveFlash })
	local flash = useFlash(gains, reducedMotion)
	local chipH = if tall then TapTarget else 54
	local iconSize = if tall then 32 else 28
	local valueSize = if tall then 17 else 16
	local tip = CHIP_TIPS[label]
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = flash:map(function(amount)
			return Palette.lineSoft:Lerp(accent, amount)
		end),
		Thickness = 1,
		Transparency = flash:map(function(amount)
			return 0.56 - amount * 0.5
		end),
	})
	local _exp_3 = React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, if tall then 10 else 9),
		PaddingRight = UDim.new(0, if tall then 12 else 11),
		PaddingTop = UDim.new(0, if tall then 6 else 8),
		PaddingBottom = UDim.new(0, if tall then 6 else 8),
	})
	local _exp_4 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = true,
	}, React.createElement(IconTile, {
		kind = icon,
		accent = accent,
		size = iconSize,
		radius = 99,
	}))
	local _exp_6 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 0),
	})
	local _exp_7 = showLabel and React.createElement("textlabel", {
		Size = UDim2.new(0, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = label,
		TextColor3 = ensureContrast(Palette.panel, accent),
		TextSize = 12,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 1,
	})
	local _result
	if placeholder ~= nil or not animateValue or type(value) == "string" then
		local _attributes = {
			Size = UDim2.fromOffset(valueSize, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}
		local _condition = placeholder
		if _condition == nil then
			_condition = compactNumber(value)
		end
		_attributes.Text = _condition
		_attributes.TextColor3 = ensureContrast(Palette.panel, Palette.cream)
		_attributes.TextSize = valueSize
		_attributes.FontFace = Font.fromEnum(Enum.Font.RobotoMono)
		_attributes.TextXAlignment = Enum.TextXAlignment.Left
		_attributes.TextYAlignment = Enum.TextYAlignment.Center
		_attributes.LayoutOrder = 2
		_result = React.createElement("textlabel", _attributes)
	else
		_result = React.createElement(NumberSpinnerHost, {
			value = value,
			velocity = asFlux(velocity),
			reducedMotion = reducedMotion,
			duration = 0.55,
			size = valueSize,
			color = ensureContrast(Palette.panel, Palette.cream),
			autoWidth = true,
			sizeConstraint = UDim2.fromOffset(0, 20),
			layoutOrder = 2,
			zIndex = 3,
		})
	end
	local chip = React.createElement("frame", {
		Size = UDim2.fromOffset(0, chipH),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, React.createElement("frame", {
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		ClipsDescendants = false,
	}, _exp_6, _exp_7, _result))
	return React.createElement("frame", {
		Size = UDim2.fromOffset(0, chipH + 2),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
		ClipsDescendants = false,
	}, React.createElement("uipadding", {
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingTop = UDim.new(0, 1),
		PaddingBottom = UDim.new(0, 1),
	}), chip)
end
local function PerformanceStats(_param)
	local tall = _param.tall
	if tall == nil then
		tall = false
	end
	local reducedMotion = _param.reducedMotion
	local showFps = _param.showFps
	if showFps == nil then
		showFps = true
	end
	local showPing = _param.showPing
	if showPing == nil then
		showPing = true
	end
	local telemetry = usePerformanceTelemetry()
	local fps = math.max(0, math.floor(telemetry.fps + 0.5))
	local ping = if telemetry.pingMs ~= nil then math.max(0, math.floor(telemetry.pingMs + 0.5)) else nil
	local fpsAccent = if fps >= 54 then Palette.mint elseif fps >= 38 then Palette.mango else Palette.coral
	local pingAccent = if ping == nil then Palette.muted elseif ping <= 85 then Palette.mint elseif ping <= 165 then Palette.mango else Palette.coral
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	})
	local _exp_1 = showFps and React.createElement(StatChip, {
		label = "FPS",
		value = fps,
		icon = "Timer",
		accent = fpsAccent,
		reducedMotion = reducedMotion,
		reactiveFlash = false,
		animateValue = false,
		placeholder = `{fps}`,
		tall = tall,
		layoutOrder = 1,
	})
	local _condition = showPing
	if _condition then
		local _attributes = {
			label = "PING",
		}
		local _condition_1 = ping
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_attributes.value = _condition_1
		_attributes.icon = "Wave"
		_attributes.accent = pingAccent
		_attributes.reducedMotion = reducedMotion
		_attributes.reactiveFlash = false
		_attributes.animateValue = false
		_attributes.placeholder = if ping == nil then "—" else `{ping}`
		_attributes.tall = tall
		_attributes.layoutOrder = 2
		_condition = React.createElement(StatChip, _attributes)
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(0, if tall then TapTarget else 50),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _condition)
end
local function boostIconKind(boostId)
	if boostId == "DomainSurge" then
		return "Domain"
	end
	if boostId == "VaultSurge" then
		return "Vault"
	end
	if boostId == "Hyperdrive" then
		return "World"
	end
	return "Reactor"
end
local function ActiveBoostIcon(_param)
	local boost = _param.boost
	local endsAt = _param.endsAt
	local now = _param.now
	local open = _param.open
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local remaining = now:map(function(timestamp)
		return clockText(math.max(0, endsAt - timestamp))
	end)
	local fraction = now:map(function(timestamp)
		return math.clamp((endsAt - timestamp) / math.max(1, boost.Duration), 0, 1)
	end)
	local chrome = useButtonChrome(open, reducedMotion, false, "boostOpen", true)
	local reveal = useEntrance(reducedMotion)
	local radius = if compact then 11 else 12
	local visualScale = React.joinBindings({
		press = chrome.touchScale,
		reveal = reveal,
	}):map(function(_param_1)
		local press = _param_1.press
		local amount = _param_1.reveal
		return press * (0.94 + math.clamp(amount, 0, 1) * 0.06)
	end)
	local visualPosition = React.joinBindings({
		offset = chrome.offsetY,
		reveal = reveal,
	}):map(function(_param_1)
		local offset = _param_1.offset
		local amount = _param_1.reveal
		return UDim2.new(0.5, 0, 0.5, math.round(offset + (1 - math.clamp(amount, 0, 1)) * 6))
	end)
	local hoverFill = chrome.hoverAmount:map(function(amount)
		return Palette.panelRaised:Lerp(darken(boost.Color, 0.72), math.clamp(amount, 0, 1) * 0.24)
	end)
	local runningLow, setRunningLow = React.useState(function()
		return endsAt - os.time() <= boost.Duration * 0.15
	end)
	React.useEffect(function()
		local threshold = boost.Duration * 0.15
		local remainingSeconds = endsAt - os.time()
		local shouldRunLow = remainingSeconds <= threshold
		setRunningLow(shouldRunLow)
		if shouldRunLow then
			return nil
		end
		local timer = task.delay(math.max(0, remainingSeconds - threshold), function()
			return setRunningLow(true)
		end)
		return function()
			return task.cancel(timer)
		end
	end, { boost.Duration, endsAt })
	local urgentStroke = useGlowStroke(runningLow, reducedMotion, 0.5, 0.15, 0.65, 2.4)
	local strokeTransparency = React.joinBindings({
		hover = chrome.hoverAmount,
		glow = urgentStroke,
	}):map(function(_param_1)
		local hover = _param_1.hover
		local glow = _param_1.glow
		return math.min(0.5 - hover * 0.22, glow)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = visualPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = visualScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundColor3 = hoverFill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.5),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 3 else 4, if compact then 34 else 38),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = boost.Color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = chrome.hoverAmount:map(function(amount)
			return 1 - amount * 0.1
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		idle = true,
		zIndex = 2,
		radius = radius,
	}), React.createElement(IconTile, {
		kind = boostIconKind(boost.Id),
		accent = boost.Color,
		size = if compact then 34 else 40,
		radius = if compact then 9 else 10,
		position = if compact then UDim2.new(0.5, -17, 0, 4) else UDim2.fromOffset(9, 8),
		spin = chrome.hovered and not reducedMotion,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
		zIndex = 3,
	}), if compact then React.createElement(Text, {
		value = remaining,
		size = 10,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 5, 1, -19),
		sizeConstraint = UDim2.new(1, -10, 0, 13),
		zIndex = 4,
	}) else React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = "ACTIVE BOOST",
		size = 9,
		color = boost.Color,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, -128, 0, 13),
		zIndex = 4,
	}), React.createElement(Text, {
		value = boost.Name,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(60, 20),
		sizeConstraint = UDim2.new(1, -128, 0, 18),
		zIndex = 4,
	}), React.createElement(Text, {
		value = remaining,
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 10,
		position = UDim2.new(1, -64, 0, 18),
		sizeConstraint = UDim2.fromOffset(54, 18),
		zIndex = 4,
	}), React.createElement(Text, {
		value = AppHelpers:boostEffectText(boost),
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(60, 38),
		sizeConstraint = UDim2.new(1, -72, 0, 13),
		zIndex = 4,
	})), React.createElement("frame", {
		Size = if compact then UDim2.new(1, -12, 0, 3) else UDim2.new(1, -69, 0, 3),
		Position = if compact then UDim2.new(0, 6, 1, -6) else UDim2.new(0, 60, 1, -7),
		BackgroundColor3 = Palette.lineSoft,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fraction:map(function(amount)
			return UDim2.new(amount, 0, 1, 0)
		end),
		BackgroundColor3 = boost.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))), React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, -3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = boost.Color,
		Thickness = 1,
		Transparency = strokeTransparency,
	})))))
end
local function TopbarReleaseCountdown(_param)
	local releaseAt = _param.releaseAt
	local width = _param.width
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local Workspace = game:GetService("Workspace")
	local function syncedNow()
		local ok, value = pcall(function()
			return Workspace:GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return math.floor(value)
		end
		return os.time()
	end
	local now, setNow = React.useState(syncedNow())
	React.useEffect(function()
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(0.5)
				if alive then
					setNow(syncedNow())
				end
			end
		end)
		return function()
			alive = false
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, {})
	local remaining = math.max(0, releaseAt - now)
	local live = remaining <= 0
	local slam, setSlam = React.useState(0)
	local wasLive = React.useRef(live)
	React.useEffect(function()
		if live and not wasLive.current then
			wasLive.current = true
			setSlam(function(n)
				return n + 1
			end)
			if not reducedMotion then
				Audio:play("prestige")
				Audio:play("bootFinaleBang")
			end
		end
		if not live then
			wasLive.current = false
		end
	end, { live, reducedMotion })
	local pulse = usePulse(live and not reducedMotion, 2.4)
	local flash = useFlash(slam, reducedMotion, 1.05)
	local orbit = useClock(live and not reducedMotion, 0.7, 1, true)
	local days = math.floor(remaining / 86400)
	local hours = math.floor(remaining / 3600) % 24
	local minutes = math.floor(remaining / 60) % 60
	local seconds = remaining % 60
	local pair = function(value)
		return if value < 10 then `0{value}` else tostring(value)
	end
	local values = if live then { {
		value = "LIVE",
		unit = "NOW",
		color = Palette.mint,
	} } else { {
		value = tostring(days),
		unit = "DAYS",
		color = Palette.cyan,
	}, {
		value = pair(hours),
		unit = "HRS",
		color = Palette.violet,
	}, {
		value = pair(minutes),
		unit = "MIN",
		color = Palette.pink,
	}, {
		value = pair(seconds),
		unit = "SEC",
		color = Palette.mango,
	} }
	local labelW = if live then (if width >= 360 then 96 else 82) elseif width >= 360 then 104 else 88
	local strokeColor = if live then Palette.mint else Palette.cyan
	local strokeTransparency = if live then pulse:map(function(amount)
		return 0.08 + (1 - amount) * 0.38
	end) else 0.5
	local fillWash = if live then pulse:map(function(amount)
		return 0.82 - amount * 0.28
	end) else 1
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = strokeColor,
		Thickness = if live then 1.6 else 1,
		Transparency = strokeTransparency,
	})
	local _exp_2 = live and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mint,
		BackgroundTransparency = fillWash,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}))
	local _condition = live and not reducedMotion
	if _condition then
		local _exp_3 = { 0, 1, 2, 3, 4, 5 }
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_3)
		local _callback = function(index)
			return React.createElement("frame", {
				key = index,
				Size = flash:map(function(amount)
					return UDim2.fromOffset(3 + math.floor(amount * 3), 3 + math.floor(amount * 3))
				end),
				Position = orbit:map(function(turn)
					local angle = turn * math.pi * 2 + index * (math.pi / 3)
					return UDim2.new(0.72, math.floor(math.cos(angle) * 34), 0.5, math.floor(math.sin(angle) * 16))
				end),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if index % 2 == 0 then Palette.mint else Palette.cyan,
				BackgroundTransparency = pulse:map(function(amount)
					return 0.12 + (1 - amount) * 0.55
				end),
				BorderSizePixel = 0,
				ZIndex = 2,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}))
		end
		for _k, _v in _exp_3 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_3)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, _newValue)
	end
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromOffset(9, 11),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Icon, {
		kind = "Calendar",
		color = Palette.cream,
		accent = if live then Palette.mint else Palette.cyan,
		size = 26,
		spin = live and not reducedMotion,
	}))
	local _exp_4 = React.createElement(Text, {
		value = if live then "LAUNCH" else "NEXT",
		size = 10,
		color = if live then Palette.mint else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(40, 7),
		sizeConstraint = UDim2.fromOffset(labelW - 42, 14),
		zIndex = 3,
	})
	local _exp_5 = React.createElement(Text, {
		value = if live then "LIVE" else "UPDATE",
		size = 10,
		minSize = 8,
		color = if live then Palette.cream else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(40, 23),
		sizeConstraint = UDim2.fromOffset(labelW - 42, 15),
		zIndex = 3,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0, 1, 1, -16),
		Position = UDim2.fromOffset(labelW, 8),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.36,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	local _exp_7 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#values)
	local _callback = function(entry, index)
		return React.createElement("frame", {
			key = entry.unit,
			Size = UDim2.new(1 / #values, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
		}, index > 0 and React.createElement("frame", {
			Size = UDim2.fromOffset(1, 22),
			Position = UDim2.new(0, 0, 0.5, -11),
			BackgroundColor3 = Palette.lineSoft,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}), React.createElement("textlabel", {
			Size = UDim2.new(1, -4, 0, 21),
			Position = UDim2.fromOffset(2, 3),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = entry.value,
			TextColor3 = entry.color,
			TextSize = if live then 18 else 14,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansExtraBold),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = false,
			ZIndex = 3,
		}), React.createElement(Text, {
			value = entry.unit,
			size = 8,
			minSize = 7,
			color = if live then Palette.mint else Palette.muted,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromOffset(2, 25),
			sizeConstraint = UDim2.new(1, -4, 0, 11),
			zIndex = 3,
		}))
	end
	for _k, _v in values do
		_newValue[_k] = _callback(_v, _k - 1, values)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _condition, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.new(1, -(labelW + 7), 1, -6),
		Position = UDim2.fromOffset(labelW + 5, 3),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _exp_7, _newValue))
end
local function TopBar(_param)
	local state = _param.state
	local page = _param.page
	local railOpen = _param.railOpen
	local toggleRail = _param.toggleRail
	local hideUI = _param.hideUI
	local tight = _param.tight
	local width = _param.width
	local topPad = _param.topPad
	local barHeight = _param.barHeight
	local edgePad = _param.edgePad
	local reducedMotion = _param.reducedMotion
	local releaseAt = _param.releaseAt
	local visit = _param.visit
	local openPlayerlist = _param.openPlayerlist
	local openFeedback = _param.openFeedback
	local accent = AppHelpers:pageAccent(page)
	local shortRow = barHeight <= 54 and width < 980
	local micro = barHeight <= 54 and width < 620
	local stacked = barHeight > Layout.topbarHeight
	local chipWidthEstimate = if stacked then 128 elseif micro then 132 else 140
	local logoCompact = tight or stacked or barHeight <= Layout.topbarHeight
	local logoWidth = if micro then 40 elseif stacked then 148 elseif shortRow then 146 elseif logoCompact then 172 else 228
	local pageTitleW = 0
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	local visitPill = if not stacked and visit ~= nil then {
		label = `AT {string.upper(visit.DisplayName)}`,
		accent = Palette.blue,
	} elseif not stacked and visitorsHere > 0 then {
		label = if visitorsHere == 1 then "1 VISITOR" else `{visitorsHere} VISITORS`,
		accent = Palette.mango,
	} else nil
	local allChips = {}
	if AppHelpers:featureUnlocked(state, "Rebirth") then
		local _arg0 = {
			label = "CORES",
			value = state.Cores,
			icon = "Core",
			accent = Palette.violet,
		}
		table.insert(allChips, _arg0)
	end
	if AppHelpers:featureUnlocked(state, "StarGrid") then
		local _arg0 = {
			label = "DUST",
			value = state.Stardust,
			icon = "Dust",
			accent = Palette.mango,
		}
		table.insert(allChips, _arg0)
	end
	local _arg0 = {
		label = "FLUX",
		value = state.Cash,
		icon = "Flux",
		accent = Palette.cyan,
	}
	table.insert(allChips, _arg0)
	local visitPillWidth = if visitPill ~= nil then (if tight then 124 else 156) else 0
	-- Was hardcoded to 0 (dead space between the logo and the resource chips, with the
	-- countdown component fully built but never shown). Room only exists for it on a real
	-- single-row desktop bar -- stacked/short/micro layouts already spend every pixel on the
	-- logo, chips, and controls.
	local countdownW = if not stacked and not shortRow and not micro and width >= 900 then 200 else 0
	local _condition_1 = state.Settings.ShowFps
	if _condition_1 == nil then
		_condition_1 = 1
	end
	local _exp = (if _condition_1 >= 0.5 then 1 else 0)
	local _condition_2 = state.Settings.ShowPing
	if _condition_2 == nil then
		_condition_2 = 1
	end
	local performanceCount = _exp + (if _condition_2 >= 0.5 then 1 else 0)
	local fullPerformanceW = if micro or performanceCount == 0 then 0 elseif performanceCount == 1 then (if stacked then 100 else 90) elseif stacked then 192 else 172
	local performanceGap = 10
	local playerControlGap = if shortRow then 6 else 8
	local playerControlW = if micro or stacked or width < 980 then SHELL_CHROME.topbarControl else 110
	local feedbackControlGap = if shortRow then 6 else 8
	local showFeedbackControl = not (stacked and width < 360)
	local feedbackControlW = if not showFeedbackControl then 0 elseif micro or stacked or width < 1480 then SHELL_CHROME.topbarControl else 116
	local controlsW = SHELL_CHROME.topbarControl + playerControlGap + playerControlW + (if showFeedbackControl then feedbackControlGap + feedbackControlW else 0)
	local fixedSingleRow = edgePad * 2 + (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) + controlsW + 12 + (if visitPillWidth > 0 then visitPillWidth + 6 else 0) + (if countdownW > 0 then countdownW + 10 else 0)
	local minimumResourceRoom = if #allChips > 0 then chipWidthEstimate + 6 else 0
	local performanceW = if not stacked and fullPerformanceW > 0 and width - fixedSingleRow - fullPerformanceW - performanceGap < minimumResourceRoom then 0 else fullPerformanceW
	local spare = if stacked then width - edgePad * 2 - 24 - performanceW - performanceGap else width - edgePad * 2 - (logoWidth + 14 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap) - (if pageTitleW > 0 then pageTitleW + 10 else 0) - controlsW - 12 - (if visitPillWidth > 0 then visitPillWidth + 6 else 0) - performanceW - performanceGap - (if countdownW > 0 then countdownW + 10 else 0)
	local fitCount = if stacked then math.clamp(math.floor((spare + 6) / (chipWidthEstimate + 6)), 1, math.min(2, #allChips)) else math.clamp(math.floor((spare + 6) / (chipWidthEstimate + 6)), 0, #allChips)
	local chips = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(chip, index)
		if index >= #allChips - fitCount then
			local _chip = chip
			table.insert(chips, _chip)
		end
	end
	for _k, _v in allChips do
		_callback(_v, _k - 1, allChips)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local controlsRight = edgePad + 4
	local hasRightCluster = not stacked and (#chips > 0 or visitPill ~= nil or performanceW > 0)
	local row1H = if stacked then 62 else barHeight
	local logoH = if stacked then 52 else math.min(56, math.max(40, barHeight - 16))
	local logoY = if stacked then 6 else math.max(4, math.floor((row1H - logoH) / 2))
	local chipRowH = if stacked then TapTarget else 50
	local _exp_1 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_2 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	})
	local _exp_3 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.52,
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromOffset(72, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.new(1, -36, 0, 1),
		Position = UDim2.fromOffset(18, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0.95,
		BorderSizePixel = 0,
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		Position = UDim2.fromOffset(12, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = if railOpen then "Close" else "Menu",
		onClick = toggleRail,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	}))
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.fromOffset(logoWidth, logoH),
		Position = UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap, logoY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(LogoLockup, {
		compact = logoCompact,
		micro = micro,
		accent = accent,
		reducedMotion = reducedMotion,
	}))
	local _exp_8 = countdownW > 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(countdownW, 48),
		Position = UDim2.fromOffset(12 + SHELL_CHROME.topbarControl + SHELL_CHROME.topbarControlGap + logoWidth + 14, math.floor((row1H - 48) / 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, React.createElement(TopbarReleaseCountdown, {
		releaseAt = releaseAt,
		width = countdownW,
		reducedMotion = reducedMotion,
	}))
	local _condition_3 = hasRightCluster
	if _condition_3 then
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		})
		local _condition_4 = performanceW > 0
		if _condition_4 then
			local _attributes = {
				tall = false,
				reducedMotion = reducedMotion,
			}
			local _condition_5 = state.Settings.ShowFps
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showFps = _condition_5 >= 0.5
			local _condition_6 = state.Settings.ShowPing
			if _condition_6 == nil then
				_condition_6 = 1
			end
			_attributes.showPing = _condition_6 >= 0.5
			_condition_4 = React.createElement(PerformanceStats, _attributes)
		end
		local _exp_10 = visitPill ~= nil and React.createElement("frame", {
			Size = UDim2.fromOffset(visitPillWidth, TapTarget),
			LayoutOrder = 10,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(Button, {
			text = visitPill.label,
			icon = "Crew",
			onClick = openPlayerlist,
			color = Palette.panelSoft,
			textColor = visitPill.accent,
			outline = true,
			size = UDim2.fromScale(1, 1),
			reducedMotion = reducedMotion,
		}))
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
			local _attributes = {
				key = chip.label,
				layoutOrder = 20 + index,
				label = chip.label,
				value = chip.value,
				icon = chip.icon,
				accent = chip.accent,
				reducedMotion = reducedMotion,
				velocity = if chip.label == "FLUX" then state.Production else 0,
			}
			local _condition_5 = state.Settings.ShowResourceLabels
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showLabel = _condition_5 >= 0.5
			return React.createElement(StatChip, _attributes)
		end
		for _k, _v in chips do
			_newValue[_k] = _callback_1(_v, _k - 1, chips)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_3 = React.createElement("frame", {
			Size = UDim2.fromOffset(0, chipRowH + 4),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(controlsW + controlsRight + 12), 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = false,
		}, _exp_9, _condition_4, _exp_10, _newValue)
	end
	local _condition_4 = stacked
	if _condition_4 then
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#chips)
		local _callback_1 = function(chip, index)
			local _attributes = {
				key = chip.label,
				layoutOrder = index + 1,
				label = chip.label,
				value = chip.value,
				icon = chip.icon,
				accent = chip.accent,
				reducedMotion = reducedMotion,
				velocity = if chip.label == "FLUX" then state.Production else 0,
				tall = true,
			}
			local _condition_5 = state.Settings.ShowResourceLabels
			if _condition_5 == nil then
				_condition_5 = 1
			end
			_attributes.showLabel = _condition_5 >= 0.5
			return React.createElement(StatChip, _attributes)
		end
		for _k, _v in chips do
			_newValue[_k] = _callback_1(_v, _k - 1, chips)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_4 = React.createElement("frame", {
			Size = UDim2.new(1, -(24 + (if performanceW > 0 then performanceW + performanceGap else 0)), 0, TapTarget + 6),
			Position = UDim2.fromOffset(12, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 22,
			ClipsDescendants = false,
		}, _exp_9, _newValue)
	end
	local _condition_5 = stacked and performanceW > 0
	if _condition_5 then
		local _attributes = {
			tall = true,
			reducedMotion = reducedMotion,
		}
		local _condition_6 = state.Settings.ShowFps
		if _condition_6 == nil then
			_condition_6 = 1
		end
		_attributes.showFps = _condition_6 >= 0.5
		local _condition_7 = state.Settings.ShowPing
		if _condition_7 == nil then
			_condition_7 = 1
		end
		_attributes.showPing = _condition_7 >= 0.5
		_condition_5 = React.createElement("frame", {
			Size = UDim2.fromOffset(performanceW, TapTarget),
			Position = UDim2.new(1, -(performanceW + 12), 0, row1H + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 23,
			ClipsDescendants = true,
		}, React.createElement(PerformanceStats, _attributes))
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, -edgePad * 2, 0, barHeight),
		Position = UDim2.fromOffset(edgePad, topPad),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = false,
	}, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, _exp_8, _condition_3, _condition_4, _condition_5, React.createElement("frame", {
		Size = UDim2.fromOffset(SHELL_CHROME.topbarControl, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = "",
		icon = "Hide",
		onClick = hideUI,
		color = Palette.panelSoft,
		textColor = accent,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(playerControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if playerControlW > SHELL_CHROME.topbarControl then "PLAYERS" else "",
		icon = "Pilot",
		onClick = openPlayerlist,
		color = Palette.panelSoft,
		textColor = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), showFeedbackControl and React.createElement("frame", {
		Size = UDim2.fromOffset(feedbackControlW, SHELL_CHROME.topbarControl),
		Position = UDim2.new(1, -(SHELL_CHROME.topbarControl + controlsRight + playerControlGap + playerControlW + feedbackControlGap + feedbackControlW), 0, math.floor((row1H - SHELL_CHROME.topbarControl) / 2)),
		BackgroundTransparency = 1,
		ZIndex = 22,
	}, React.createElement(Button, {
		text = if feedbackControlW > SHELL_CHROME.topbarControl then "FEEDBACK" else "",
		icon = "Chat",
		onClick = openFeedback,
		color = Palette.panelSoft,
		textColor = Palette.mint,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})))
end
local function RailButton(_param)
	local entry = _param.entry
	local active = _param.active
	local collapsed = _param.collapsed
	local onClick = _param.onClick
	local layoutOrder = _param.layoutOrder
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local rowHeight = _param.rowHeight
	local bodySize = _param.bodySize
	local viewport = useViewport()
	local touchChrome = viewport.compact or viewport.tight
	local disabled = entry.disabled == true
	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)
	local hoveredRef = React.useRef(false)
	local emphasis = useFlipperSpring(if not disabled and active then 1 elseif not disabled and hovered then 0.4 else 0, reducedMotion, 360, 28)
	local iconHover = useFlipperSpring(if not disabled and hovered then 1 else 0, reducedMotion, 520, 34)
	local press = useFlipperSpring(if pressed and not reducedMotion then 1 else 0, reducedMotion, 620, 36)
	local fill = emphasis:map(function(raw)
		return if disabled then Palette.panelRaised else Palette.panel:Lerp(Palette.panelSoft, math.clamp(raw, 0, 1))
	end)
	local fillTransparency = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return 0.34 - amount * 0.34
	end)
	local strokeTransparency = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return math.clamp(0.82 - amount * 0.62, 0.18, 0.85)
	end)
	local markerSize = emphasis:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return UDim2.new(0, 3, 1, -18 - math.round((1 - amount) * 16))
	end)
	local tileFill = emphasis:map(function(raw)
		return if disabled then Palette.panelSoft else Palette.panelRaised:Lerp(darken(entry.accent, 0.52), math.clamp(raw, 0, 1))
	end)
	local ringTransparency = emphasis:map(function(raw)
		return math.clamp(0.78 - math.clamp(raw, 0, 1) * 0.7, 0.05, 0.82)
	end)
	local labelColor = emphasis:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local eyebrowColor = emphasis:map(function(raw)
		return if disabled then Palette.muted else Palette.muted:Lerp(entry.accent, math.clamp(raw, 0, 1))
	end)
	local pressWash = press:map(function(amount)
		return if touchChrome then math.clamp(1 - amount * 0.22, 0.78, 1) else 1
	end)
	local pressScale = press:map(function(amount)
		return if touchChrome then 1 - amount * 0.055 else 1
	end)
	local iconSize = if collapsed then 34 else 30
	local iconX = if collapsed then math.floor((Layout.sidebarCollapsedWidth - SHELL_CHROME.railGutter * 2 - iconSize) / 2) else 12
	local markHover = function()
		if disabled then
			return nil
		end
		if hoveredRef.current then
			return nil
		end
		hoveredRef.current = true
		setHovered(true)
		Audio:play("hover")
	end
	local clearHover = function()
		hoveredRef.current = false
		setHovered(false)
		setPressed(false)
	end
	React.useEffect(function()
		return subscribeInputCancellation(function()
			hoveredRef.current = false
			setHovered(false)
			setPressed(false)
		end)
	end, {})
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		Event = {
			Activated = function()
				local audioMarker = Audio:captureIntent()
				onClick()
				if not disabled then
					Audio:playIfUnclaimed(audioMarker, "tabSwitch")
				end
				InteractionFeedback.tap()
			end,
			MouseEnter = function()
				return markHover()
			end,
			MouseLeave = function()
				return clearHover()
			end,
			SelectionGained = function()
				return markHover()
			end,
			SelectionLost = function()
				return clearHover()
			end,
			InputBegan = function(_b, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setPressed(true)
				end
			end,
			InputEnded = function()
				return setPressed(false)
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = pressScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -4, 1, -2),
		Position = press:map(function(amount)
			return UDim2.new(0, 2, 0, 1 + math.round(amount * (if touchChrome then 2 else 1)))
		end),
		BackgroundColor3 = fill,
		BackgroundTransparency = fillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.7),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = entry.accent,
		Thickness = 1,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), touchChrome and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = lighten(entry.accent, 0.35),
		BackgroundTransparency = pressWash,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	})), React.createElement("frame", {
		Size = markerSize,
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = entry.accent,
		BackgroundTransparency = emphasis:map(function(amount)
			return if amount < 0.08 then 1 else 0.75 - amount * 0.75
		end),
		BorderSizePixel = 0,
		Visible = emphasis:map(function(amount)
			return amount >= 0.08
		end),
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = UDim2.new(0, iconX, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = tileFill,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = entry.accent,
		Thickness = 1,
		Transparency = ringTransparency,
	}), React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft elseif active then lighten(entry.accent, 0.42) else Palette.muted,
		size = iconSize,
		spin = not disabled and hovered,
		hoverAmount = iconHover,
		reducedMotion = reducedMotion,
	})), not collapsed and React.createElement(Text, {
		value = entry.label,
		size = bodySize,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(56, 10),
		sizeConstraint = UDim2.new(1, -66, 0, 22),
	}), not collapsed and React.createElement(Text, {
		value = entry.eyebrow,
		size = 10,
		color = eyebrowColor,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(56, 34),
		sizeConstraint = UDim2.new(1, -66, 0, 18),
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 12,
	})))))
end
local MORE_BTN_W = 172
local function MoreDockButton(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local fill = _param.fill
	local disabled = entry.disabled == true
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	local selection = useFlipperSpring(if active and not disabled then 1 else 0, reducedMotion, 420, 32)
	local radius = 9
	local iconSize = if fill then 22 else 28
	local iconX = if fill then 7 else 9
	local textX = if fill then 38 else 49
	local fillColor = chrome.hoverAmount:map(function(amount)
		return if disabled then Palette.panelRaised else Palette.panel:Lerp(Palette.panelSoft, math.clamp(amount, 0, 1) * 0.6)
	end)
	-- On the desktop row, idle buttons carry no card surface at all -- with 20+ of these in one
	-- strip, giving every one its own border/fill turned the dock into a wall of identical boxes.
	-- Only the active page or whatever the pointer is currently over gets a card; everything else
	-- sits flat on the dock's own background, so the row reads as one toolbar with a highlight
	-- instead of a row of tiles. The mobile "More" sheet (fill=true) is a small deliberate grid,
	-- not a crowded strip, so it keeps a visible card on every cell -- that's what makes each
	-- touch target legible there.
	local cardTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		if fill then
			return 0
		end
		local selected = math.clamp(raw, 0, 1)
		local hoverAmount = math.clamp(hovered, 0, 1)
		return math.clamp(1 - selected * 0.94 - hoverAmount * 0.55, 0.06, 1)
	end)
	local activeFillTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1) * 0.78
	end)
	local strokeTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		local selected = math.clamp(raw, 0, 1)
		if fill then
			return math.clamp(0.72 - math.clamp(hovered, 0, 1) * 0.32 - selected * 0.48, 0.18, 0.76)
		end
		return math.clamp(1 - math.clamp(hovered, 0, 1) * 0.55 - selected * 0.82, 0.18, 1)
	end)
	local iconPosition = selection:map(function(raw)
		local selected = math.clamp(raw, 0, 1)
		return if fill then UDim2.new(0.5, 0, 0, 3 - math.round(selected * 2)) else UDim2.new(0, iconX, 0.5, -math.round(selected))
	end)
	local iconFill = selection:map(function(raw)
		return if disabled then Palette.panelSoft else Palette.panelRaised:Lerp(darken(entry.accent, 0.64), math.clamp(raw, 0, 1))
	end)
	-- Idle rows on the desktop strip keep a mostly-transparent icon tile so 20+ buttons in one row
	-- don't read as a wall of solid squares; hovering or being the active page fills the tile back
	-- in, which is what actually needs to draw the eye. The mobile grid keeps its icon tile solid.
	local iconFillTransparency = React.joinBindings({
		selection = selection,
		hover = chrome.hoverAmount,
	}):map(function(_param_1)
		local raw = _param_1.selection
		local hovered = _param_1.hover
		if disabled then
			return 0.35
		end
		if fill then
			return 0
		end
		local selected = math.clamp(raw, 0, 1)
		local hoverAmount = math.clamp(hovered, 0, 1)
		return math.clamp(0.62 - hoverAmount * 0.5 - selected * 0.62, 0, 0.62)
	end)
	local labelColor = selection:map(function(raw)
		return if disabled then Palette.muted else Palette.creamSoft:Lerp(Palette.cream, math.clamp(raw, 0, 1))
	end)
	local underlineSize = selection:map(function(raw)
		return UDim2.new(0.46 * math.clamp(raw, 0, 1), 0, 0, 2)
	end)
	local underlineTransparency = selection:map(function(raw)
		return 1 - math.clamp(raw, 0, 1)
	end)
	return React.createElement("frame", {
		Size = if fill then UDim2.fromScale(1, 1) else UDim2.fromOffset(MORE_BTN_W, TapTarget),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		ZIndex = 56,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 57,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = chrome.touchScale,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundColor3 = fillColor,
		BackgroundTransparency = cardTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 57,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.55),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = entry.accent,
		Thickness = 1,
		Transparency = strokeTransparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(entry.accent, 0.68),
		BackgroundTransparency = activeFillTransparency,
		BorderSizePixel = 0,
		ZIndex = 57,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, radius),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 58,
	}, React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		zIndex = 58,
		radius = radius,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(iconSize, iconSize),
		Position = iconPosition,
		AnchorPoint = if fill then Vector2.new(0.5, 0) else Vector2.new(0, 0.5),
		BackgroundColor3 = iconFill,
		BackgroundTransparency = iconFillTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 59,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = iconSize,
		spin = not disabled and chrome.hovered,
		hoverAmount = chrome.hoverAmount,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = entry.label,
		size = if fill then 11 else 12,
		color = labelColor,
		weight = Enum.FontWeight.Heavy,
		align = if fill then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		fit = true,
		minSize = if fill then 9 else 10,
		position = if fill then UDim2.fromOffset(2, if fill then 26 else 4) else UDim2.fromOffset(textX, 12),
		sizeConstraint = if fill then UDim2.new(1, -4, 0, 16) else UDim2.new(1, -(textX + 6), 0, 22),
		zIndex = 59,
	}), React.createElement("frame", {
		Size = underlineSize,
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = lighten(entry.accent, 0.48),
		BackgroundTransparency = underlineTransparency,
		BorderSizePixel = 0,
		ZIndex = 60,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 58,
		compact = true,
	}), not fill and React.createElement("frame", {
		Size = UDim2.new(0, 1, 1, -18),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 56,
	}))
end
-- Desktop equivalent of the mobile MoreSheet: a small grid popover anchored below the dock,
-- opened from a "MORE" trigger instead of always occupying screen width. Rendered through the
-- shared dropdown portal (a top-level ScreenGui) rather than nested under the dock's own frame,
-- since the dock's ancestor shell clips descendants to its own small strip -- anything drawn
-- inside that tree past the dock's bounds would be invisible. Closes on picking a page, Escape,
-- or clicking anywhere outside the panel.
local MoreCell
local function MoreDockPopover(_param)
	local entries = _param.entries
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local anchor = _param.anchor
	local onClose = _param.onClose
	local viewport = useViewport()
	local portalLayer = React.useState(acquireDropdownPortal)
	React.useEffect(function()
		return function()
			return releaseDropdownPortal()
		end
	end, {})
	local panelRef = React.useRef()
	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
				onClose()
				return nil
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return nil
			end
			local panel = panelRef.current
			if panel == nil then
				return nil
			end
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local origin = panel.AbsolutePosition
			local extent = panel.AbsoluteSize
			local inside = point.X >= origin.X and point.X <= origin.X + extent.X and point.Y >= origin.Y and point.Y <= origin.Y + extent.Y
			if not inside then
				onClose()
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { onClose })
	local visible = AppHelpers:filterNav(entries, state, tutorialPage)
	local cols = math.min(5, math.max(3, math.ceil(math.sqrt(#visible))))
	local cellW = 132
	local cellH = 68
	local gap = 8
	local rows = math.max(1, math.ceil(#visible / cols))
	local panelW = cols * cellW + (cols - 1) * gap + 20
	local panelH = rows * cellH + (rows - 1) * gap + 56
	local clampedX = math.clamp(anchor.right - panelW, 10, math.max(10, viewport.width - panelW - 10))
	local clampedY = math.min(anchor.top, math.max(10, viewport.height - panelH - 10))
	local reveal = useFlipperSpring(1, reducedMotion, 780, 44)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_1 = React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = reveal:map(function(amount)
			return math.clamp(1 - amount * 0.38, 0.4, 1)
		end),
	})
	local _exp_2 = React.createElement(Text, {
		value = "MORE",
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 8),
		sizeConstraint = UDim2.new(1, -20, 0, 14),
		transparency = reveal:map(function(amount)
			return 1 - amount
		end),
	})
	local _exp_3 = React.createElement("uigridlayout", {
		CellSize = UDim2.fromOffset(cellW, cellH),
		CellPadding = UDim2.new(0, gap, 0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#visible)
	local _callback = function(entry, index)
		return React.createElement(MoreCell, {
			key = entry.id,
			entry = entry,
			active = page == entry.id,
			onClick = function()
				setPage(entry.id)
				onClose()
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		})
	end
	for _k, _v in visible do
		_newValue[_k] = _callback(_v, _k - 1, visible)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(React.Fragment, nil, ReactRoblox.createPortal(React.createElement("frame", {
		ref = panelRef,
		Size = UDim2.fromOffset(panelW, panelH),
		Position = reveal:map(function(amount)
			return UDim2.fromOffset(clampedX, clampedY + math.round((1 - math.clamp(amount, 0, 1)) * 10))
		end),
		BackgroundColor3 = Palette.night,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - math.clamp(amount, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 220,
		ClipsDescendants = true,
		Visible = reveal:map(function(amount)
			return amount > 0.01
		end),
	}, _exp, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, -20, 1, -34),
		Position = UDim2.fromOffset(10, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 221,
	}, _exp_3, _newValue)), portalLayer))
end
function MoreCell(_param)
	local entry = _param.entry
	local active = _param.active
	local onClick = _param.onClick
	local reducedMotion = _param.reducedMotion
	local badge = _param.badge
	if badge == nil then
		badge = 0
	end
	local layoutOrder = _param.layoutOrder
	local disabled = entry.disabled == true
	local chrome = useButtonChrome(onClick, reducedMotion, disabled, "tabSwitch", true)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ZIndex = 93,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		ZIndex = 94,
		Event = chrome.events,
	}, React.createElement("frame", {
		Size = chrome.surfaceSize,
		Position = chrome.offsetY:map(function(amount)
			return UDim2.new(0.5, 0, 0.5, math.round(amount))
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if active then darken(entry.accent, 0.7) else Palette.panelRaised,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ZIndex = 95,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if active then entry.accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.35 else 0.7,
	}), React.createElement(ButtonShimmer, {
		hoverAmount = chrome.hoverAmount,
		shimmer = chrome.shimmer,
		zIndex = 95,
		radius = 12,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 96,
	}, React.createElement(Icon, {
		kind = entry.icon,
		color = if disabled then Palette.muted else Palette.creamSoft,
		accent = if disabled then Palette.lineSoft else entry.accent,
		size = 22,
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = entry.label,
		size = 10,
		color = if disabled then Palette.muted else Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(2, 36),
		sizeConstraint = UDim2.new(1, -4, 0, 26),
		zIndex = 96,
	}), badge > 0 and React.createElement(CountBadge, {
		count = badge,
		zIndex = 97,
		compact = true,
	}))))
end
local function MoreDock(_param)
	local page = _param.page
	local setPage = _param.setPage
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local stack = _param.stack
	local cols = _param.cols
	local cellH = _param.cellH
	local opacity = _param.opacity
	if opacity == nil then
		opacity = 1
	end
	local spacing = _param.spacing
	if spacing == nil then
		spacing = 0.5
	end
	local entries = _param.entries
	local viewport = useViewport()
	local more = AppHelpers:filterNav(entries, state, tutorialPage)
	local gridGap = 3 + math.floor(math.clamp(spacing, 0, 1) * 5)
	local height = moreDockHeight(stack, #more, cols, cellH, gridGap)
	-- These hooks back the desktop-only MORE popover, but must still run unconditionally on
	-- every render (including the mobile `stack` branch below) -- React requires the same
	-- hooks in the same order on every call, regardless of which branch's JSX gets returned.
	local moreMenuOpen, setMoreMenuOpen = React.useState(false)
	local moreTriggerRef = React.useRef()
	local popoverAnchor, setPopoverAnchor = React.useState()
	if stack then
		local _exp = React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 14),
		})
		local _exp_1 = React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.65,
		})
		local _exp_2 = React.createElement("uigridlayout", {
			CellSize = UDim2.new(1 / cols, -gridGap, 0, cellH),
			CellPadding = UDim2.new(0, gridGap, 0, gridGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = cols,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#more)
		local _callback = function(entry, index)
			return React.createElement(MoreDockButton, {
				key = entry.id,
				entry = entry,
				active = page == entry.id,
				onClick = function()
					return setPage(entry.id)
				end,
				reducedMotion = reducedMotion,
				badge = AppHelpers:navBadge(entry, state, chatUnread),
				layoutOrder = index,
				fill = true,
			})
		end
		for _k, _v in more do
			_newValue[_k] = _callback(_v, _k - 1, more)
		end
		-- ▲ ReadonlyArray.map ▲
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, height),
			BackgroundColor3 = Palette.night,
			BackgroundTransparency = math.clamp(1 - opacity, 0, 0.48),
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Active = false,
			ZIndex = 55,
		}, _exp, _exp_1, React.createElement("frame", {
			Size = UDim2.new(1, -10, 1, -12),
			Position = UDim2.fromOffset(5, 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 56,
		}, _exp_2, _newValue))
	end
	-- Only as many entries as comfortably fit get a permanent slot on the bar; the rest live
	-- behind a "MORE" trigger opened on demand (MoreDockPopover), same idea as the mobile tab
	-- bar's overflow sheet. One slot is reserved for the trigger whenever there's overflow.
	local visibleCount = math.clamp(math.floor((viewport.width - 32) / (MORE_BTN_W + 4)), 1, 7)
	local needsMore = #more > visibleCount
	local primaryCount = if needsMore then math.max(1, visibleCount - 1) else visibleCount
	local primary = {}
	local overflow = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(entry, index)
		if index < primaryCount then
			local _entry = entry
			table.insert(primary, _entry)
		else
			local _overflow = overflow
			local _entry = entry
			table.insert(_overflow, _entry)
		end
	end
	for _k, _v in more do
		_callback(_v, _k - 1, more)
	end
	-- ▲ ReadonlyArray.forEach ▲
	-- Keep the active page visible on the bar even if it would otherwise land in overflow --
	-- swap it in for the last primary slot (and move the displaced entry into overflow) so the
	-- current page is never hidden behind the MORE trigger.
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(entry)
		return entry.id == page
	end
	local _result
	for _i, _v in overflow do
		if _callback_1(_v, _i - 1, overflow) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local activeInOverflow = _result
	if activeInOverflow ~= nil and #primary > 0 then
		local displaced = primary[#primary]
		primary[#primary] = activeInOverflow
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback_2 = function(entry)
			return entry.id ~= activeInOverflow.id
		end
		local _length = 0
		for _k, _v in overflow do
			if _callback_2(_v, _k - 1, overflow) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		overflow = _newValue
		if displaced ~= nil then
			table.insert(overflow, 1, displaced)
		end
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_2 = function(sum, entry)
		return sum + AppHelpers:navBadge(entry, state, chatUnread)
	end
	for _i = 1, #overflow do
		_result_1 = _callback_2(_result_1, overflow[_i], _i - 1, overflow)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local overflowBadgeTotal = _result_1
	local moreTriggerActive = moreMenuOpen or activeInOverflow ~= nil
	local toggleMoreMenu = function()
		if not moreMenuOpen then
			local trigger = moreTriggerRef.current
			if trigger ~= nil then
				local origin = trigger.AbsolutePosition
				local extent = trigger.AbsoluteSize
				setPopoverAnchor({
					right = origin.X + extent.X,
					top = origin.Y + extent.Y + 6,
				})
			end
		end
		setMoreMenuOpen(function(current)
			return not current
		end)
	end
	local canvasW = math.max(#primary * (MORE_BTN_W + 4) - 4, 1)
	local dockW = math.min(viewport.width - 16, #primary * (MORE_BTN_W + 4) - 4)
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	local _exp_2 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#primary)
	local _callback_3 = function(entry, index)
		return React.createElement(MoreDockButton, {
			key = entry.id,
			entry = entry,
			active = page == entry.id,
			onClick = function()
				return setPage(entry.id)
			end,
			reducedMotion = reducedMotion,
			badge = AppHelpers:navBadge(entry, state, chatUnread),
			layoutOrder = index,
		})
	end
	for _k, _v in primary do
		_newValue[_k] = _callback_3(_v, _k - 1, primary)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Active = false,
		ZIndex = 55,
	}, _exp, _exp_1, React.createElement("scrollingframe", {
		Size = UDim2.new(0, dockW, 1, -8),
		Position = UDim2.new(0.5, -math.floor(dockW / 2) - (if needsMore then (MORE_BTN_W + 4) / 2 else 0), 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, canvasW, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		ScrollingEnabled = true,
		Active = true,
		Selectable = false,
		ClipsDescendants = true,
		ZIndex = 56,
	}, _exp_2, _newValue), needsMore and React.createElement("frame", {
		ref = moreTriggerRef,
		Size = UDim2.fromOffset(MORE_BTN_W, TapTarget),
		Position = UDim2.new(1, -(MORE_BTN_W + 6), 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 57,
	}, React.createElement(MoreDockButton, {
		entry = {
			id = "Overview",
			label = "MORE",
			eyebrow = "",
			icon = "Menu",
			accent = Palette.muted,
		},
		active = moreTriggerActive,
		onClick = toggleMoreMenu,
		reducedMotion = reducedMotion,
		badge = overflowBadgeTotal,
		layoutOrder = #primary,
	})), moreMenuOpen and popoverAnchor ~= nil and React.createElement(MoreDockPopover, {
		entries = overflow,
		page = page,
		setPage = function(chosen)
			setPage(chosen)
			setMoreMenuOpen(false)
		end,
		reducedMotion = reducedMotion,
		state = state,
		chatUnread = chatUnread,
		tutorialPage = tutorialPage,
		anchor = popoverAnchor,
		onClose = function()
			return setMoreMenuOpen(false)
		end,
	}))
end
local function Navigation(_param)
	local page = _param.page
	local setPage = _param.setPage
	local collapsed = _param.collapsed
	local width = _param.width
	local fixedWidth = _param.fixedWidth
	local reducedMotion = _param.reducedMotion
	local state = _param.state
	local chatUnread = _param.chatUnread
	local tutorialPage = _param.tutorialPage
	local includeSecondary = _param.includeSecondary
	if includeSecondary == nil then
		includeSecondary = false
	end
	local fromMore = _param.fromMore
	if fromMore == nil then
		fromMore = false
	end
	local activeBoost = _param.activeBoost
	local activeBoostEndsAt = _param.activeBoostEndsAt
	if activeBoostEndsAt == nil then
		activeBoostEndsAt = 0
	end
	local wallClock = _param.wallClock
	local openBoosts = _param.openBoosts
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local rowHeight = if collapsed then chrome.railCollapsedRow else chrome.railRow
	local primaryEntries = if fromMore then {} else AppHelpers:filterNav(PRIMARY_NAV, state, tutorialPage)
	local secondaryEntries = if fromMore then AppHelpers:filterNav(MORE_NAV, state, tutorialPage) elseif includeSecondary then AppHelpers:filterNav(MORE_NAV, state, tutorialPage) else {}
	local showSecondarySection = includeSecondary and not fromMore and #secondaryEntries > 0 and not collapsed
	local sectionH = if showSecondarySection then 22 else 0
	local railCount = if fromMore then #secondaryEntries else (#primaryEntries + #secondaryEntries)
	local canvasHeight = math.max(1, railCount) * (rowHeight + chrome.railGap) - chrome.railGap + Layout.stackGap * 2 + sectionH
	local headerHeight = if collapsed then 12 else 48
	local showBoost = activeBoost ~= nil and not chrome.mobile and page ~= "Rewards" and wallClock ~= nil and openBoosts ~= nil
	local boostHeight = if showBoost then (if collapsed then 62 else 64) else 0
	local boostReserve = if showBoost then boostHeight + SHELL_CHROME.railGutter * 2 else 0
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.5),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.68,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	local _exp_3 = not collapsed and React.createElement("frame", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2), 0, 28),
		Position = UDim2.fromOffset(SHELL_CHROME.railGutter, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = AppHelpers:pageAccent(page),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = "Forge",
		size = 10,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(18, 0),
		sizeConstraint = UDim2.new(0.58, -18, 1, 0),
	}))
	local _exp_4 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, chrome.railGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local railChildren = {}
	local appendRail = function(entries, orderBase)
		local _callback = function(entry, index)
			table.insert(railChildren, React.createElement(RailButton, {
				key = entry.id,
				entry = entry,
				active = page == entry.id,
				collapsed = collapsed,
				onClick = function()
					return setPage(entry.id)
				end,
				layoutOrder = orderBase + index,
				reducedMotion = reducedMotion,
				rowHeight = rowHeight,
				bodySize = chrome.bodyText,
				badge = AppHelpers:navBadge(entry, state, chatUnread),
			}))
		end
		for _k, _v in entries do
			_callback(_v, _k - 1, entries)
		end
		return orderBase + #entries
	end
	local layoutCursor = 0
	if fromMore then
		appendRail(secondaryEntries, 0)
	else
		layoutCursor = appendRail(primaryEntries, 0)
		if showSecondarySection then
			table.insert(railChildren, React.createElement("frame", {
				key = "nav-more-section",
				Size = UDim2.new(1, 0, 0, sectionH),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = layoutCursor,
			}, React.createElement(Text, {
				value = "MORE",
				size = 9,
				color = Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(8, 4),
				sizeConstraint = UDim2.new(1, -12, 1, -4),
			})))
			layoutCursor += 1
		end
		if includeSecondary then
			appendRail(secondaryEntries, layoutCursor)
		end
	end
	return React.createElement("frame", {
		Size = if fixedWidth ~= nil then UDim2.fromScale(1, 1) else width:map(function(value)
			return UDim2.new(0, math.max(0, value), 1, 0)
		end),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 10,
		ClipsDescendants = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("scrollingframe", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2 + 4), 1, -(headerHeight + SHELL_CHROME.railGutter + boostReserve)),
		Position = UDim2.fromOffset(SHELL_CHROME.railGutter, headerHeight),
		CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
	}, _exp_4, railChildren), showBoost and React.createElement("frame", {
		Size = UDim2.new(1, -(SHELL_CHROME.railGutter * 2), 0, boostHeight),
		Position = UDim2.new(0, SHELL_CHROME.railGutter, 1, -(boostHeight + SHELL_CHROME.railGutter)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, React.createElement(ActiveBoostIcon, {
		boost = activeBoost,
		endsAt = activeBoostEndsAt,
		now = wallClock,
		open = openBoosts,
		reducedMotion = reducedMotion,
		compact = collapsed,
	})))
end
local function VaultPill(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local top = _param.top
	if top == nil then
		top = 8
	end
	local fill = meterFill(asFlux(state.Vault), asFlux(state.Capacity))
	local ready = asFlux(state.Vault) >= 0.01
	local full = fill >= 0.99
	local bar = if full then Palette.mango else accent
	-- This number updates on every production tick for the whole session, so it can't afford a
	-- continuously-running tween -- instead, a brief flash on genuine gains via useFlash (a
	-- short spring that settles and goes idle) gives it a felt reaction without any per-tick
	-- motor cost between updates.
	local gains, setGains = React.useState(0)
	local previousVault = React.useRef(state.Vault)
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	React.useEffect(function()
		if asFlux(state.Vault) > asFlux(previousVault.current) then
			setGains(function(current)
				return current + 1
			end)
		end
		previousVault.current = state.Vault
	end, { state.Vault })
	local vaultFlash = useFlash(gains, softMotion, 0.5)
	local vaultTextColor = vaultFlash:map(function(amount)
		return ensureContrast(Palette.panelRaised, if ready then Palette.cream else Palette.muted):Lerp(bar, amount * 0.7)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(248, 52),
		Position = UDim2.new(1, -316, 0, top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 22,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 13),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if full then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = if full then 0.35 else 0.72,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = darken(bar, 0.62),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(Icon, {
		kind = "Vault",
		color = Palette.cream,
		accent = bar,
		size = 18,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})), React.createElement(Text, {
		value = compactNumber(state.Vault),
		size = 15,
		color = vaultTextColor,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(50, 7),
		sizeConstraint = UDim2.new(1, -62, 0, 20),
	}), React.createElement(Text, {
		value = `of {compactNumber(state.Capacity)}`,
		size = 11,
		color = ensureContrast(Palette.panelRaised, Palette.muted),
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(50, 26),
		sizeConstraint = UDim2.new(1, -62, 0, 14),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -20, 0, 4),
		Position = UDim2.new(0, 10, 1, -8),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(math.clamp(fill, 0.02, 1), 0, 1, 0),
		BackgroundColor3 = bar,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function NextUnlockStrip(_param)
	local state = _param.state
	local reducedMotion = _param.reducedMotion
	local goal = AppHelpers:nextUnlock(state)
	local fill = if goal ~= nil then meterFill(goal.Progress, goal.Target) else 1
	local accent = if goal ~= nil then Palette.cyan else Palette.mint
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uigradient", {
		Color = surfaceGradient(Palette.night, 0.7),
		Rotation = 90,
	}), React.createElement(Text, {
		value = if goal ~= nil then "NEXT UNLOCK" else "FORGE OPEN",
		size = 9,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(12, 0),
		sizeConstraint = UDim2.new(0, 96, 1, 0),
	}), React.createElement(Text, {
		value = if goal ~= nil then goal.Name else "Every feature unlocked",
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(112, 0),
		sizeConstraint = UDim2.new(0.42, -112, 1, 0),
	}), React.createElement(Text, {
		value = if goal ~= nil then goal.Requirement else "Keep pushing worlds and ranks.",
		size = 11,
		color = Palette.creamSoft,
		fit = true,
		minSize = 10,
		position = UDim2.new(0.42, 8, 0, 0),
		sizeConstraint = UDim2.new(0.58, -20, 1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(1, -24, 0, 4),
		Position = UDim2.new(0, 12, 1, -5),
		BackgroundColor3 = Palette.line,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(math.clamp(fill, 0.03, 1), 0, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.28), accent),
	}))))
end
local function Workspace(_param)
	local page = _param.page
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local keyboardCompact = viewport.keyboardOpen
	local _condition = chrome.stack
	if _condition then
		local _condition_1 = state.Settings.MobileCompactHeaders
		if _condition_1 == nil then
			_condition_1 = 1
		end
		_condition = _condition_1 >= 0.5
	end
	local mobileHeaderCompact = _condition
	local accent = AppHelpers:pageAccent(page)
	local entry = AppHelpers:pageEntry(page)
	local enter = useTokenEntrance(page, reducedMotion, 0.2)
	local entranceLock, setEntranceLock = React.useState({
		page = page,
		suppress = false,
	})
	local suppressEntrance = entranceLock.page == page and entranceLock.suppress
	React.useEffect(function()
		setEntranceLock({
			page = page,
			suppress = false,
		})
		local job = task.delay(0.34, function()
			return setEntranceLock({
				page = page,
				suppress = true,
			})
		end)
		return function()
			return task.cancel(job)
		end
	end, { page })
	local inset = if keyboardCompact then 6 elseif chrome.stack then chrome.contentInset else Layout.contentInset
	-- Phone stack uses MobileHeader for page chrome, so chrome.workspaceHeaderH is 0 and the
	-- Workspace title/collect strip must stay collapsed — otherwise we double-tax vertical
	-- space and first-screen CTAs fall below the fold. Keyboard-open with a zero plan header
	-- stays collapsed (MobileHeader + tab bar are already hidden in that mode).
	local headerHeight
	if keyboardCompact then
		headerHeight = if chrome.landscape or chrome.workspaceHeaderH <= 0 then 0 else TapTarget
	elseif chrome.stack then
		headerHeight = chrome.workspaceHeaderH
	else
		headerHeight = Layout.workspaceHeaderHeight
	end
	-- Next-goal strip: skip on landscape and whenever the workspace header itself is gone.
	local _result
	if keyboardCompact or chrome.landscape or headerHeight <= 0 then
		_result = 0
	else
		local _condition_1 = state.Settings.ShowNextGoal
		if _condition_1 == nil then
			_condition_1 = 1
		end
		_result = if _condition_1 >= 0.5 then 32 else 0
	end
	local unlockH = _result
	local vaultBtn = if chrome.stack then TapTarget else 44
	local ready = asFlux(state.Vault) >= 0.01
	local contentPosition = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		local lift = math.round((1 - t) * 12)
		return UDim2.new(0, inset, 0, headerHeight + unlockH + inset + lift)
	end)
	local revealFade = enter:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local contentFade = enter:map(function(amount)
		local t = math.clamp(amount, 0, 1)
		return (1 - t) * 0.4
	end)
	local titleLeft = if keyboardCompact then 54 elseif chrome.stack then 66 else 84
	-- Desktop reserves room for the right-side VaultPill (248px wide, anchored at -316): the
	-- title block must stop before it. -392 used to run 8px into the pill; -344 keeps a 6px
	-- clearance on every desktop width.
	local titleReserve = if keyboardCompact then -(titleLeft + vaultBtn + 18) else (if chrome.stack then -(vaultBtn + 18) elseif chrome.tight then -(vaultBtn + 28) else -344) - (titleLeft - (if chrome.stack then 14 else 22))
	local titleBlockH = if keyboardCompact then 32 elseif chrome.landscape then 28 elseif chrome.stack then 36 else 72
	local headerIconSize = if keyboardCompact then 28 elseif chrome.landscape then 28 elseif chrome.stack then 32 else 48
	local headerTitleY = if keyboardCompact then 6 elseif chrome.landscape then 10 elseif chrome.stack then 12 else math.max(10, math.floor((headerHeight - titleBlockH) / 2))
	local vaultPillY = math.max(8, math.floor((headerHeight - 52) / 2))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 5,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.58,
	}), headerHeight > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 20,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.58),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = darken(Palette.panel, 0.24),
		BorderSizePixel = 0,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(78, 2),
		Position = UDim2.fromOffset(18, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(0.68, 0.18), NumberSequenceKeypoint.new(1, 1) }),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(headerIconSize, headerIconSize),
		Position = enter:map(function(amount)
			return UDim2.fromOffset((if keyboardCompact then 8 elseif chrome.stack then 14 else 20) - math.round((1 - math.clamp(amount, 0, 1)) * 10), math.floor((headerHeight - headerIconSize) / 2))
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	}, React.createElement(IconTile, {
		kind = entry.icon,
		accent = accent,
		size = headerIconSize,
		radius = 12,
		spin = false,
		reducedMotion = reducedMotion,
		zIndex = 4,
	})), React.createElement("frame", {
		Size = UDim2.new(1, titleReserve, 0, titleBlockH),
		Position = UDim2.fromOffset(titleLeft, headerTitleY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, React.createElement(ShimmerText, {
		value = if entry.label == "Games" then "Mini Games" elseif entry.label == "Ranks" then "Leaderboards" else entry.label,
		size = if chrome.stack then chrome.titleText else 26,
		color = ensureContrast(Palette.panel, Palette.cream),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 16,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 6), 0, if chrome.landscape then 4 else 2)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.landscape then 28 elseif chrome.stack then 28 else 34),
		reducedMotion = reducedMotion,
		enabled = not reducedMotion,
		periodSeconds = 4.2,
	}), not keyboardCompact and not mobileHeaderCompact and not chrome.landscape and React.createElement(Text, {
		value = if page == "Overview" then `World {state.CurrentZone}  /  {compactNumber(state.Production)}/s` else entry.eyebrow,
		size = if chrome.stack then chrome.labelText else 12,
		color = ensureContrast(Palette.panel, accent),
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = enter:map(function(amount)
			return UDim2.new(0, math.round((1 - math.clamp(amount, 0, 1)) * 10), 0, if chrome.stack then 32 else 40)
		end),
		sizeConstraint = UDim2.new(1, 0, 0, if chrome.stack then 32 else 28),
		transparency = revealFade,
	})), not chrome.stack and React.createElement(VaultPill, {
		state = state,
		reducedMotion = reducedMotion,
		accent = accent,
		top = vaultPillY,
	}), React.createElement(Button, {
		text = "",
		icon = "Collect",
		onClick = function()
			return dispatch("CollectVault")
		end,
		color = if ready then accent else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(vaultBtn, vaultBtn),
		position = UDim2.new(1, -(vaultBtn + 14), 0, math.floor((headerHeight - vaultBtn) / 2)),
		disabled = not ready,
		reducedMotion = reducedMotion,
		highlight = asFlux(state.Vault) >= asFlux(state.Capacity) * 0.85,
		zIndex = 22,
	})), unlockH > 0 and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, unlockH),
		Position = UDim2.fromOffset(0, headerHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement(NextUnlockStrip, {
		state = state,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -inset * 2, 1, -(headerHeight + unlockH + inset * 2)),
		Position = contentPosition,
		BackgroundTransparency = contentFade,
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, React.createElement(EntranceMotionSuppressedContext.Provider, {
		value = suppressEntrance,
	}, children), React.createElement(ScrollEdgeFade, {
		color = Palette.ink,
		height = if chrome.stack then 18 else 16,
		zIndex = 200,
	})))
end
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
				_result_1 = if _condition_2 >= 0.5 then math.max(52, Layout.topbarHeight - 8) else Layout.topbarHeight
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
	local hideAmount = useFlipperSpring(if hidden then 1 else 0, reducedMotion, 620, 42)
	-- The v2 mobile shell (chrome.stack) never uses the drawer/rail system at all — it has its
	-- own fixed bottom tab bar (MobileTabBar) instead. The drawer/rail below only still applies
	-- to the non-stack "touch + compact" case (e.g. a touch tablet in a window too wide to
	-- count as `stack`), which keeps its own slide-out drawer.
	local mobileShell = chrome.stack
	local drawerWidth = math.min(Layout.sidebarWidth, math.max(248, viewport.width - edgePad * 2 - 36))
	local railTarget = if railOpen then (if drawerNav then drawerWidth else (if viewport.compact then Layout.sidebarCollapsedWidth else Layout.sidebarWidth)) else 0
	local railWidth = useFlipperSpring(if mobileShell then 0 else railTarget, reducedMotion, 900, 46)
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
	React.useEffect(function()
		if domainOverlayActive or showRelease or tutorialOpen then
			return nil
		end
		local connection = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or UserInputService:GetFocusedTextBox() ~= nil then
				return nil
			end
			if input.KeyCode == Enum.KeyCode.Backquote then
				setHidden(function(current)
					return not current
				end)
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { domainOverlayActive, showRelease, tutorialOpen })
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
	local navigateStable = React.useCallback(function(pageId)
		return navigateRef.current(pageId)
	end, {})
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
			reducedMotion = reducedMotion or heavyPage or quietPage or arcadeBusy or backgroundDetail < 0.58,
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
			reducedMotion = reducedMotion or heavyPage or quietPage or arcadeBusy,
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
		reducedMotion = reducedMotion,
		openPlayerlist = function()
			setFeedbackOpen(false)
			setPlayerlistOpen(true)
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
			edgePad = edgePad,
			reducedMotion = reducedMotion,
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
	}))))
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
			reducedMotion = reducedMotion,
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
		Size = UDim2.new(1, -edgePad * 2, 1, -(shellTop + bottomPad + gamepadReserve)),
		Position = UDim2.fromOffset(edgePad, shellTop),
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
			reducedMotion = reducedMotion,
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
			reducedMotion = reducedMotion,
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
	local _exp_14 = not state.Flags.TutorialDone and tutorial ~= nil and React.createElement(TutorialOverlay, {
		copy = tutorial,
		step = tutorialStep,
		count = #TUTORIAL_STEPS,
		viewportWidth = viewport.width,
		viewportHeight = viewport.height,
		reducedMotion = reducedMotion,
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
	}, React.createElement(React.Fragment, nil, React.createElement("frame", {
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
	})), crateReveal ~= nil and React.createElement(CrateRevealOverlay, {
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
		local _pipelinedActions = NETWORK.pipelinedActions
		local _action = action
		local pipelined = _pipelinedActions[_action] ~= nil
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
		local requestLimit = if pipelined then 4 else 2
		if activeRequests >= requestLimit then
			reject("Still working on your last tap.")
			return nil
		end
		if inFlightTotal.current >= NETWORK.maxPhysicalRequests then
			reject("The connection is busy. Try again in a moment.")
			return nil
		end
		local now = os.clock()
		local _condition_5 = NETWORK.actionCooldowns[action]
		if _condition_5 == nil then
			_condition_5 = 0.1
		end
		local cooldown = _condition_5
		local previous = sentAt.current[signature]
		if previous ~= nil and now - previous < cooldown then
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
		local _optimisticActions = NETWORK.optimisticActions
		local _action_2 = action
		if _optimisticActions[_action_2] ~= nil then
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
		local _condition_6 = NETWORK.requestTimeouts[action]
		if _condition_6 == nil then
			_condition_6 = NETWORK.defaultRequestTimeout
		end
		local timeoutSeconds = _condition_6
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
