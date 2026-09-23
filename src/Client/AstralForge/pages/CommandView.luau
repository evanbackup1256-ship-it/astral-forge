local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _AnimatedTitle = require(script.Parent.Parent.AnimatedTitle)
local AnimatedTitlePreview = _AnimatedTitle.AnimatedTitlePreview
local darkTitlePlate = _AnimatedTitle.darkTitlePlate
local titleFxAccent = _AnimatedTitle.titleFxAccent
local _scrolling = require(script.Parent.Parent.scrolling)
local AutoGrid = _scrolling.AutoGrid
local VirtualGrid = _scrolling.VirtualGrid
local _format = require(script.Parent.Parent.format)
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.motion)
local easeOutCubic = _motion.easeOutCubic
local useBoatTween = _motion.useBoatTween
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local fitPanelHeight = _theme.fitPanelHeight
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local function gridPanelHeight(headerH, rows, cellH, gap, pad)
	local safeRows = math.max(1, rows)
	local gridH = safeRows * cellH + math.max(0, safeRows - 1) * gap
	return pad * 2 + headerH + gridH
end
local TABS = { "Overview", "Expeditions", "Artifacts", "Season" }
local TITLE_FX_FALLBACKS = { "shimmer", "aurora", "pulse", "chrome", "wave", "glow" }
local TAB_LABEL = {
	Overview = "Overview",
	Expeditions = "Expeditions",
	Artifacts = "Artifacts",
	Season = "Rank Track",
}
local TAB_SHORT = {
	Overview = "Home",
	Expeditions = "Trips",
	Artifacts = "Relics",
	Season = "Rank",
}
-- ▼ ReadonlyArray.map ▼
local _newValue = table.create(#TABS)
local _callback = function(id)
	return {
		id = id,
		label = TAB_LABEL[id],
	}
end
for _k, _v in TABS do
	_newValue[_k] = _callback(_v, _k - 1, TABS)
end
-- ▲ ReadonlyArray.map ▲
local TAB_OPTIONS = _newValue
-- ▼ ReadonlyArray.map ▼
local _newValue_1 = table.create(#TABS)
local _callback_1 = function(id)
	return {
		id = id,
		label = TAB_SHORT[id],
	}
end
for _k, _v in TABS do
	_newValue_1[_k] = _callback_1(_v, _k - 1, TABS)
end
-- ▲ ReadonlyArray.map ▲
local TAB_OPTIONS_SHORT = _newValue_1
local TAB_TIPS = {
	Overview = "Commander rank, crew, weekly jobs, titles, and the signal shop.",
	Expeditions = "Send crews on timed trips for signals and loot.",
	Artifacts = "Equip and upgrade expedition relics.",
	Season = "Claim rank track tiers as you earn commander XP.",
}
local CREW_ROLES = { "Pilot", "Engineer", "Navigator" }
local function crewCost(base, level)
	return math.floor(base * math.pow(level, 1.55))
end
local function artifactEffect(artifact, level)
	if artifact.EffectKind == "OfflineHours" then
		return `+{string.format("%.1f", artifact.EffectPerLevel * level)}h offline`
	end
	return `+{string.format("%.0f", artifact.EffectPerLevel * level * 100)}% {artifact.EffectKind}`
end
local function artifactIcon(id)
	if id == "SolarLens" then
		return "Forge"
	end
	if id == "VaultPrism" then
		return "Vault"
	end
	if id == "PulsarCoil" then
		return "Overcharge"
	end
	if id == "EchoRelay" then
		return "Visit"
	end
	if id == "DroneCrown" then
		return "Grid"
	end
	if id == "CriticalShard" then
		return "Jackpot"
	end
	if id == "CoreStabilizer" then
		return "Core"
	end
	if id == "TimeCompass" then
		return "Timer"
	end
	if id == "MagnetarSeal" then
		return "Anomaly"
	end
	if id == "VoidKey" then
		return "Lock"
	end
	if id == "AuroraMap" then
		return "World"
	end
	if id == "CrownOfHours" then
		return "Milestone"
	end
	return "Artifact"
end
local function TabRail(_param)
	local active = _param.active
	local setActive = _param.setActive
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	return React.createElement(SegmentedTabs, {
		options = if stack then TAB_OPTIONS_SHORT else TAB_OPTIONS,
		value = active,
		onChange = setActive,
		accent = Palette.cyan,
		columns = #TABS,
		gap = 4,
		size = UDim2.new(1, 0, 0, if stack then 52 else 48),
		reducedMotion = reducedMotion,
	})
end
local function TabPane(_param)
	local tabKey = _param.tabKey
	local reducedMotion = _param.reducedMotion
	local children = _param.children
	local enter = useBoatTween(1, if reducedMotion then 0.01 else 0.2, reducedMotion, easeOutCubic, 0)
	return React.createElement("frame", {
		key = tabKey,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 20,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = enter:map(function(a)
			return UDim2.new(0, math.round((1 - math.clamp(a, 0, 1)) * 7), 0, 0)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	}), children))
end
local CommandTitleCard = React.memo(function(props)
	local accent = titleFxAccent(props.fx)
	local effectName = `{string.upper((string.gsub(props.fx, "-", " ")))} EFFECT`
	local equip = React.useCallback(function()
		return props.dispatch("EquipTitle", {
			Id = props.id,
		})
	end, { props.dispatch, props.id })
	local actionHeight = if props.stack then TapTarget else 36
	local actionSize = UDim2.new(1, -14, 0, actionHeight)
	local actionPosition = UDim2.new(0, 7, 1, -(actionHeight + 7))
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = if props.equipped then accent else Palette.lineSoft,
		Thickness = if props.equipped then 1.5 else 1,
		Transparency = if props.equipped then 0.16 else 0.42,
	})
	local _exp_2 = React.createElement(Text, {
		value = effectName,
		size = 9,
		minSize = 8,
		color = if props.unlocked then accent else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(8, 6),
		sizeConstraint = UDim2.new(1, -16, 0, 13),
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 21),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(AnimatedTitlePreview, {
		text = props.name,
		fx = props.fx,
		size = if props.stack then 17 else 15,
		reducedMotion = props.reducedMotion,
		transparency = if props.unlocked then 0 else 0.46,
	}))
	local _attributes = {}
	local _condition = props.description
	if _condition == nil then
		_condition = "Preview this title exactly as it appears in chat and your profile."
	end
	_attributes.value = _condition
	_attributes.size = 10
	_attributes.minSize = 9
	_attributes.color = if props.unlocked then Palette.creamSoft else Palette.muted
	_attributes.wrap = true
	_attributes.fit = false
	_attributes.align = Enum.TextXAlignment.Center
	_attributes.position = UDim2.fromOffset(9, 58)
	_attributes.sizeConstraint = UDim2.new(1, -18, 0, if props.stack then 27 else 23)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darkTitlePlate(props.fx),
		BackgroundTransparency = if props.equipped then 0.08 else 0.34,
		BorderSizePixel = 0,
		Active = false,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement(Text, _attributes), if props.unlocked and not props.equipped then React.createElement(Button, {
		text = "WEAR TITLE",
		icon = "Loadout",
		onClick = equip,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = actionSize,
		position = actionPosition,
		reducedMotion = props.reducedMotion,
	}) else React.createElement("frame", {
		Size = actionSize,
		Position = actionPosition,
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
		Active = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.buttonRadius),
	}), React.createElement("uistroke", {
		Color = if props.equipped then accent else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.58,
	}), React.createElement(Text, {
		value = if props.equipped then "EQUIPPED" else "LOCKED",
		size = 11,
		minSize = 9,
		color = if props.equipped then accent else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
	})))
end)
local function CommandView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onSectionChange = _param.onSectionChange
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — fold into reducedMotion so TabPane boat tweens,
	-- meters, and claim CTAs all snap when tier<=1 or ambient is off (parity with Shop/Trade).
	-- Canonical softMotion antilag gate — CommandView.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local claimHostRef = React.useRef(nil)
	local stack = chrome.contentStack
	local ops = config.Operations
	local command = state.Command
	local tab, setTab = React.useState("Overview")
	local now, setNow = React.useState(os.time())
	local scrollRef = React.useRef()
	React.useEffect(function()
		if tab ~= "Expeditions" then
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				task.wait(1)
				setNow(os.time())
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { tab })
	React.useEffect(function()
		local frame = scrollRef.current
		if frame then
			frame.CanvasPosition = Vector2.new(0, 0)
		end
	end, { tab })
	if not ops or not command then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, React.createElement(Text, {
			value = "Loading your crew…",
			size = 16,
			color = Palette.muted,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.fromScale(1, 1),
		}))
	end
	local titlesEnabled = ops.TitlesEnabled ~= false
	local maxed = command.Level >= ops.MaxCommanderLevel
	local levelProgress = if maxed then 1 else meterFill(command.XP - command.LevelFloorXP, math.max(1, command.NextLevelXP - command.LevelFloorXP))
	local nextClaim = command.ClaimableCommanderLevels[1]
	local active = command.ActiveExpedition
	local _result = active
	if _result ~= nil then
		_result = _result.Id
	end
	local _condition = _result
	if _condition == nil then
		_condition = ""
	end
	local activeId = _condition
	local _result_1 = active
	if _result_1 ~= nil then
		_result_1 = _result_1.EndsAt
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local activeEnds = _condition_1
	local _result_2 = active
	if _result_2 ~= nil then
		_result_2 = _result_2.StartedAt
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local activeStarted = _condition_2
	local expeditionReady = activeId ~= "" and now >= activeEnds
	local expeditionProgress = if activeId == "" then 0 else math.clamp((now - activeStarted) / math.max(1, activeEnds - activeStarted), 0, 1)
	local statusLine = if activeId == "" then "Launch an unlocked adventure below." elseif expeditionReady then "Crew is home — collect rewards." else `Back in {clockText(math.max(0, activeEnds - now))}`
	local claimLabel = if activeId == "" then "Choose below" elseif expeditionReady then "COLLECT" else clockText(math.max(0, activeEnds - now))
	local firstReadyWeeklyId = nil
	if type(command.Weekly) == "table" then
		for _, directive in command.Weekly do
			if not directive.Claimed and directive.Progress >= directive.Target then
				firstReadyWeeklyId = directive.Id
				break
			end
		end
	end
	local firstReadySeasonTier = nil
	if type(ops.SeasonTiers) == "table" and type(command.SeasonClaims) == "table" then
		for _, tier in ops.SeasonTiers do
			local claimed = command.SeasonClaims[tostring(tier.Tier)] == true
			local unlocked = command.SeasonXP >= tier.RequiredXP
			if unlocked and not claimed then
				firstReadySeasonTier = tier.Tier
				break
			end
		end
	end
	-- Gamepad: park Selection on the highest-priority Command claim CTA for the active tab.
	local commandClaimReady = (tab == "Overview" and (nextClaim ~= nil or firstReadyWeeklyId ~= nil))
		or (tab == "Expeditions" and expeditionReady)
		or (tab == "Season" and firstReadySeasonTier ~= nil)
	React.useEffect(function()
		if not commandClaimReady or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = claimHostRef.current
		if host == nil then
			return nil
		end
		local selectJob = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			task.cancel(selectJob)
		end
	end, { tab, nextClaim, firstReadyWeeklyId, expeditionReady, firstReadySeasonTier, commandClaimReady })
	local _exp = ops.Expeditions
	-- ▼ ReadonlyArray.find ▼
	local _callback_2 = function(item)
		return item.Id == activeId
	end
	local _result_3
	for _i, _v in _exp do
		if _callback_2(_v, _i - 1, _exp) == true then
			_result_3 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local activeConfig = _result_3
	local _exp_1 = ops.Artifacts
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_2 = {}
	local _callback_3 = function(artifact)
		return command.Artifacts[artifact.Id] ~= nil
	end
	local _length = 0
	for _k, _v in _exp_1 do
		if _callback_3(_v, _k - 1, _exp_1) == true then
			_length += 1
			_newValue_2[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local ownedArtifacts = #_newValue_2
	local _exp_2 = ops.SeasonTiers
	-- ▼ ReadonlyArray.find ▼
	local _callback_4 = function(tier)
		return command.SeasonClaims[tostring(tier.Tier)] ~= true
	end
	local _result_4
	for _i, _v in _exp_2 do
		if _callback_4(_v, _i - 1, _exp_2) == true then
			_result_4 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local nextTier = _result_4
	local seasonFill = if nextTier then meterFill(command.SeasonXP, math.max(1, nextTier.RequiredXP)) else 1
	local seasonStatus = if nextTier then if command.SeasonXP >= nextTier.RequiredXP then `Gift {nextTier.Tier} is ready` else `{compactNumber(nextTier.RequiredXP - command.SeasonXP)} XP to gift {nextTier.Tier}` else "All season gifts claimed"
	local budget = chrome.contentBudget
	local panelPad = 14
	local gridGap = 8
	local heroH = if stack then 156 else fitPanelHeight(168, budget, 168, if chrome.landscape then 0.4 else 0.5)
	local crewCols = if stack then 1 else 3
	local crewCellH = if stack then 108 else 120
	local crewRows = math.max(1, math.ceil(#CREW_ROLES / crewCols))
	local crewH = gridPanelHeight(54, crewRows, crewCellH, gridGap, panelPad)
	local weeklyItemH = if stack then 148 else 92
	local weeklyStride = if stack then 156 else 100
	local weeklyCount = math.max(1, #command.Weekly)
	local weeklyH = panelPad * 2 + 36 + (weeklyCount - 1) * weeklyStride + weeklyItemH
	local titleCols = if stack then 1 else 4
	local titleCellH = if stack then 142 else 126
	local titleRows = math.max(1, math.ceil(math.max(1, #command.Titles) / titleCols))
	local titlesH = if titlesEnabled then gridPanelHeight(52, titleRows, titleCellH, gridGap, panelPad) else 112
	local shopCols = if stack then 2 else 4
	local shopCellH = if stack then 150 else 160
	local shopRows = math.max(1, math.ceil(math.max(1, #command.Shop) / shopCols))
	local shopH = gridPanelHeight(36, shopRows, shopCellH, gridGap, panelPad)
	local masteryCols = if stack then 2 else 3
	local masteryCellH = 64
	local masteryRows = math.max(1, math.ceil(math.max(1, #config.Machines) / masteryCols))
	local masteryH = gridPanelHeight(36, masteryRows, masteryCellH, gridGap, panelPad)
	local expeditionHeroH = fitPanelHeight(if stack then 180 else 140, budget, 120, 0.4)
	local expeditionRowH = if stack then 168 else 132
	local artifactHeroH = 110
	local artifactRowH = if stack then 180 else 140
	local seasonHeroH = 130
	local seasonRowH = if stack then 148 else 112
	local heroInfoWidth = if stack then -100 else -(114 + 210 + 14)
	local tabContent = 0
	local listContent = 0
	local tabHeroH = 0
	if tab == "Overview" then
		tabContent = heroH + crewH + weeklyH + titlesH + shopH + masteryH + Layout.panelGap * 5
	elseif tab == "Expeditions" then
		tabHeroH = expeditionHeroH
		listContent = #ops.Expeditions * expeditionRowH + math.max(0, #ops.Expeditions - 1) * Layout.panelGap
	elseif tab == "Artifacts" then
		tabHeroH = artifactHeroH
		listContent = #ops.Artifacts * artifactRowH + math.max(0, #ops.Artifacts - 1) * Layout.panelGap
	else
		tabHeroH = seasonHeroH
		listContent = #ops.SeasonTiers * seasonRowH + math.max(0, #ops.SeasonTiers - 1) * Layout.panelGap
	end
	local headerH = 56
	local tabsH = if stack then 52 else 48
	local commandTail = scrollTail(stack, chrome.bottomSafe, if stack then 72 else 48)
	local useFillList = tab ~= "Overview"
	local order = 0
	local nextOrder = function()
		order += 1
		return order
	end
	local changeTab = function(nextTab)
		if nextTab == tab then
			return nil
		end
		local _result_5 = onSectionChange
		if _result_5 ~= nil then
			_result_5()
		end
		setTab(nextTab)
	end
	local _exp_3 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Layout.panelGap),
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, React.createElement(SectionLabel, {
		value = ops.SeasonName,
		color = Palette.cyan,
	}), React.createElement(Text, {
		value = "Deep Space Command",
		size = if stack then 24 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}))
	local _exp_5 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, React.createElement(TabRail, {
		active = tab,
		setActive = changeTab,
		reducedMotion = softMotion,
		stack = stack,
	}))
	local _condition_3 = tab == "Overview"
	if _condition_3 then
		local _exp_6 = React.createElement("frame", {
			Size = UDim2.fromOffset(if stack then 72 else 96, if stack then 72 else 96),
			BackgroundColor3 = Palette.ink,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 14),
		}), React.createElement("uistroke", {
			Color = Palette.cyan,
			Thickness = 2,
			Transparency = 0.25,
		}), React.createElement(Text, {
			value = string.format("%02d", command.Level),
			size = if stack then 28 else 36,
			color = Palette.cyan,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			align = Enum.TextXAlignment.Center,
			sizeConstraint = UDim2.new(1, 0, 0.7, 0),
		}), React.createElement(Text, {
			value = "LVL",
			size = 11,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			align = Enum.TextXAlignment.Center,
			position = UDim2.fromScale(0, 0.68),
			sizeConstraint = UDim2.new(1, 0, 0.28, 0),
		}))
		local _attributes = {}
		local _condition_4 = command.Rank
		if _condition_4 == nil then
			_condition_4 = "Commander"
		end
		_attributes.value = _condition_4
		_attributes.size = if stack then 18 else 22
		_attributes.color = Palette.cream
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.fit = false
		_attributes.position = UDim2.fromOffset(if stack then 88 else 114, 4)
		_attributes.sizeConstraint = UDim2.new(1, heroInfoWidth, 0, 28)
		local _exp_7 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, heroH),
			accent = Palette.cyan,
			background = Palette.panelRaised,
			padding = 16,
			layoutOrder = nextOrder(),
			reducedMotion = softMotion,
		}, _exp_6, React.createElement(Text, _attributes), React.createElement(Text, {
			value = if maxed then "Top rank" else `{compactNumber(math.max(0, command.NextLevelXP - command.XP))} XP to next`,
			size = 12,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(if stack then 88 else 114, 36),
			sizeConstraint = UDim2.new(1, heroInfoWidth, 0, 18),
		}), React.createElement(Meter, {
			value = levelProgress,
			color = Palette.cyan,
			reducedMotion = softMotion,
			position = UDim2.fromOffset(if stack then 88 else 114, 60),
			size = UDim2.new(1, heroInfoWidth, 0, 8),
		}), React.createElement(Text, {
			value = `{compactNumber(command.Signals)} signals  ·  {compactNumber(command.ExpeditionsCompleted)} trips  ·  {compactNumber(command.StreakShields)} shields`,
			size = 12,
			color = Palette.creamSoft,
			fit = false,
			position = UDim2.fromOffset(0, if stack then 100 else 112),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		}), React.createElement("frame", {
			-- FocusClaim prefers Claim-named hosts; commander rank gift is the Overview primary CTA.
			Name = "CommandClaimActions",
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(210, 46),
			Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -210, 0, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = if nextClaim ~= nil then claimHostRef else nil,
		}, React.createElement(Button, {
			text = if nextClaim ~= nil then `Claim level {nextClaim}` else "Rank gifts complete",
			icon = "Gift",
			onClick = function()
				if nextClaim ~= nil then
					dispatch("ClaimCommanderReward", {
						Level = nextClaim,
					})
				end
			end,
			color = Palette.cyan,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = nextClaim == nil,
			reducedMotion = softMotion,
			highlight = nextClaim ~= nil,
		})))
		local _exp_8 = React.createElement(Text, {
			value = "Crew",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		})
		local _exp_9 = React.createElement(Text, {
			value = "Spend signals to level Pilot, Engineer, and Navigator.",
			size = 12,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(0, 28),
			sizeConstraint = UDim2.new(1, 0, 0, 18),
		})
		local _exp_10 = React.createElement(AutoGrid, {
			columns = crewCols,
			cellHeight = crewCellH,
			rowGap = gridGap,
			columnGap = gridGap,
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue_3 = table.create(#CREW_ROLES)
		local _callback_5 = function(roleId, index)
			local role = ops.Crew[roleId]
			if not role then
				return nil
			end
			local _condition_5 = command.Crew[roleId]
			if _condition_5 == nil then
				_condition_5 = 1
			end
			local level = _condition_5
			local cost = crewCost(role.BaseCost, level)
			local maxRole = level >= role.MaxLevel
			local can = not maxRole and command.Signals >= cost
			return React.createElement("frame", {
				key = roleId,
				BackgroundColor3 = Palette.panelRaised,
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement("uistroke", {
				Color = role.Color,
				Thickness = 1,
				Transparency = 0.4,
			}), React.createElement(Text, {
				value = role.Name,
				size = 13,
				color = role.Color,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(10, 8),
				sizeConstraint = UDim2.new(1, -20, 0, 18),
			}), React.createElement(Text, {
				value = if role.MaxLevel >= 1000000000 then `Lv {compactNumber(level)}` else `Lv {compactNumber(level)} / {compactNumber(role.MaxLevel)}`,
				size = 11,
				color = Palette.creamSoft,
				fit = false,
				position = UDim2.fromOffset(10, 30),
				sizeConstraint = UDim2.new(1, -20, 0, 16),
			}), React.createElement(Button, {
				text = if maxRole then "MAX" else `{compactNumber(cost)} sig`,
				onClick = function()
					return dispatch("UpgradeCrew", {
						Role = roleId,
					})
				end,
				color = role.Color,
				textColor = Palette.ink,
				size = UDim2.new(1, -20, 0, if stack then TapTarget else 36),
				position = UDim2.new(0, 10, 1, -(if stack then TapTarget + 8 else 44)),
				disabled = not can,
				reducedMotion = softMotion,
				highlight = can,
			}))
		end
		for _k, _v in CREW_ROLES do
			_newValue_3[_k] = _callback_5(_v, _k - 1, CREW_ROLES)
		end
		-- ▲ ReadonlyArray.map ▲
		local _exp_11 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, crewH),
			accent = Palette.mango,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = softMotion,
		}, _exp_8, _exp_9, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, crewRows * crewCellH + math.max(0, crewRows - 1) * gridGap),
			Position = UDim2.fromOffset(0, 54),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
		}, _exp_10, _newValue_3))
		local _exp_12 = React.createElement(Text, {
			value = "Weekly jobs",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		})
		-- VirtualGrid long Weekly catalogs so Overview never map-mounts every directive.
		local _exp_13 = React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #command.Weekly,
			columns = 1,
			cellHeight = weeklyItemH,
			gap = weeklyStride - weeklyItemH,
			overscanRows = if softMotion then 0 else 1,
			position = UDim2.fromOffset(0, 36),
			itemKey = function(index)
				local directive = command.Weekly[index + 1]
				return if directive ~= nil then directive.Id else `weekly-{index}`
			end,
			renderItem = function(index)
				local directive = command.Weekly[index + 1]
				if directive == nil then
					return nil
				end
				local ready = not directive.Claimed and directive.Progress >= directive.Target
				local rewardLine = formatReward(directive.Reward)
				local _exp_14 = React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 10),
				})
				local _exp_15 = React.createElement("uistroke", {
					Color = if ready then Palette.green else Palette.lineSoft,
					Thickness = 1,
					Transparency = 0.45,
				})
				local _exp_16 = React.createElement(Text, {
					value = directive.Name,
					size = 13,
					color = if ready then Palette.green else Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					position = UDim2.fromOffset(12, 8),
					sizeConstraint = UDim2.new(1, if stack then -24 else -156, 0, 18),
				})
				local _attributes_1 = {}
				local _condition_5 = directive.Description
				if _condition_5 == nil then
					_condition_5 = ""
				end
				_attributes_1.value = _condition_5
				_attributes_1.size = 11
				_attributes_1.color = Palette.muted
				_attributes_1.fit = false
				_attributes_1.position = UDim2.fromOffset(12, 28)
				_attributes_1.sizeConstraint = UDim2.new(1, if stack then -24 else -156, 0, 16)
				return React.createElement("frame", {
					Size = UDim2.new(1, 0, 0, weeklyItemH),
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
				}, _exp_14, _exp_15, _exp_16, React.createElement(Text, _attributes_1), React.createElement(Text, {
					value = if rewardLine ~= "" then rewardLine else `{compactNumber(directive.Progress)} / {compactNumber(directive.Target)}`,
					size = 10,
					color = Palette.creamSoft,
					wrap = true,
					fit = false,
					position = UDim2.fromOffset(12, 46),
					sizeConstraint = UDim2.new(1, if stack then -24 else -156, 0, 28),
				}), React.createElement(Meter, {
					value = meterFill(directive.Progress, directive.Target, directive.Claimed or ready),
					color = Palette.green,
					reducedMotion = softMotion,
					position = UDim2.fromOffset(12, if stack then 78 else 76),
					size = UDim2.new(1, if stack then -24 else -156, 0, 7),
				}), if stack then React.createElement("frame", {
					-- FocusClaim prefers Claim-named hosts; weekly CLAIM is the Overview job CTA.
					Name = "CommandClaimActions",
					Size = UDim2.new(1, -24, 0, TapTarget),
					Position = UDim2.new(0, 12, 1, -(TapTarget + 8)),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = if ready and nextClaim == nil and directive.Id == firstReadyWeeklyId then claimHostRef else nil,
				}, React.createElement(Button, {
					text = if directive.Claimed then "DONE" elseif ready then "CLAIM" else "OPEN",
					onClick = function()
						return dispatch("ClaimWeeklyDirective", {
							Id = directive.Id,
						})
					end,
					color = Palette.green,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					disabled = directive.Claimed or not ready,
					reducedMotion = softMotion,
					highlight = ready,
				})) else React.createElement("frame", {
					Name = "CommandClaimActions",
					Size = UDim2.fromOffset(140, 44),
					Position = UDim2.new(1, -150, 0.5, -22),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = if ready and nextClaim == nil and directive.Id == firstReadyWeeklyId then claimHostRef else nil,
				}, React.createElement(Button, {
					text = if directive.Claimed then "DONE" elseif ready then "CLAIM" else "OPEN",
					onClick = function()
						return dispatch("ClaimWeeklyDirective", {
							Id = directive.Id,
						})
					end,
					color = Palette.green,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					disabled = directive.Claimed or not ready,
					reducedMotion = softMotion,
					highlight = ready,
				})))
			end,
		})
		local _exp_14 = React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, weeklyH),
			accent = Palette.green,
			background = Palette.panel,
			padding = 14,
			layoutOrder = nextOrder(),
			reducedMotion = softMotion,
			clips = false,
		}, _exp_12, _exp_13)
		local _exp_15 = React.createElement(Text, {
			value = "Title wardrobe",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, -164, 0, 24),
		})
		local _result_5
		if titlesEnabled then
			_result_5 = React.createElement(React.Fragment, nil, React.createElement(Text, {
				value = "Every card is a live preview of the name, motion, shine, and color you will wear.",
				size = 11,
				color = Palette.muted,
				fit = false,
				position = UDim2.fromOffset(0, 26),
				sizeConstraint = UDim2.new(1, 0, 0, 18),
			}), React.createElement(VirtualGrid, {
				scrollRef = scrollRef,
				count = #command.Titles,
				columns = titleCols,
				cellHeight = titleCellH,
				gap = gridGap,
				overscanRows = if softMotion then 0 else 1,
				position = UDim2.fromOffset(0, 52),
				itemKey = function(index)
					local title = command.Titles[index + 1]
					return if title ~= nil then title.Id else `title-{index}`
				end,
				renderItem = function(index)
					local title = command.Titles[index + 1]
					if title == nil then
						return nil
					end
					local _condition_5 = title.Fx
					if _condition_5 == nil then
						_condition_5 = TITLE_FX_FALLBACKS[index % #TITLE_FX_FALLBACKS + 1]
					end
					local titleFx = _condition_5
					return React.createElement(CommandTitleCard, {
						id = title.Id,
						name = title.Name,
						description = title.Description,
						unlocked = title.Unlocked,
						equipped = title.Equipped,
						fx = titleFx,
						stack = stack,
						reducedMotion = reducedMotion,
						dispatch = dispatch,
					})
				end,
			}))
		else
			local _exp_16 = React.createElement(Badge, {
				value = "TEMPORARILY CLOSED",
				accent = Palette.muted,
				size = UDim2.fromOffset(152, 26),
				position = UDim2.new(1, -152, 0, 0),
			})
			local _attributes_1 = {}
			local _condition_5 = ops.TitleStatus
			if _condition_5 == nil then
				_condition_5 = "Titles are temporarily unavailable."
			end
			_attributes_1.value = _condition_5
			_attributes_1.size = 12
			_attributes_1.color = Palette.muted
			_attributes_1.wrap = true
			_attributes_1.fit = false
			_attributes_1.position = UDim2.fromOffset(0, 36)
			_attributes_1.sizeConstraint = UDim2.new(1, 0, 0, 44)
			_result_5 = React.createElement(React.Fragment, nil, _exp_16, React.createElement(Text, _attributes_1))
		end
		_condition_3 = React.createElement(TabPane, {
			tabKey = "Overview",
			reducedMotion = reducedMotion,
		}, _exp_7, _exp_11, _exp_14, React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, titlesH),
			accent = if titlesEnabled then Palette.violet else Palette.muted,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, _exp_15, _result_5), React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, shopH),
			accent = Palette.mango,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, React.createElement(Text, {
			value = `Signal shop · {compactNumber(command.Signals)} ready`,
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		}), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #command.Shop,
			columns = shopCols,
			cellHeight = shopCellH,
			gap = gridGap,
			position = UDim2.fromOffset(0, 36),
			itemKey = function(index)
				local offer = command.Shop[index + 1]
				return if offer ~= nil then offer.Id else `shop-{index}`
			end,
			renderItem = function(index)
				local offer = command.Shop[index + 1]
				if offer == nil then
					return nil
				end
				local can = not offer.Purchased and command.Signals >= offer.Price
				return React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
					Active = false,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 10),
				}), React.createElement("uistroke", {
					Color = offer.Color,
					Thickness = 1,
					Transparency = 0.35,
				}), React.createElement(Text, {
					value = offer.Name,
					size = 12,
					color = offer.Color,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(8, 8),
					sizeConstraint = UDim2.new(1, -16, 0, 20),
				}), React.createElement(Text, {
					value = formatReward(offer.Reward),
					size = 11,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(8, 34),
					sizeConstraint = UDim2.new(1, -16, 0, 40),
				}), React.createElement(Button, {
					text = if offer.Purchased then "BOUGHT" else `{offer.Price} sig`,
					onClick = function()
						return dispatch("BuySignalOffer", {
							Id = offer.Id,
						})
					end,
					color = offer.Color,
					textColor = Palette.ink,
					size = UDim2.new(1, -16, 0, if stack then TapTarget else 40),
					position = UDim2.new(0, 8, 1, -(if stack then TapTarget + 8 else 48)),
					disabled = not can,
					reducedMotion = reducedMotion,
					highlight = can,
				}))
			end,
		})), React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, masteryH),
			accent = Palette.blue,
			background = Palette.panel,
			padding = panelPad,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, React.createElement(Text, {
			value = "Machine mastery",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 24),
		}), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #config.Machines,
			columns = masteryCols,
			cellHeight = masteryCellH,
			gap = gridGap,
			position = UDim2.fromOffset(0, 36),
			itemKey = function(index)
				local machine = config.Machines[index + 1]
				return if machine ~= nil then machine.Id else `machine-{index}`
			end,
			renderItem = function(index)
				local machine = config.Machines[index + 1]
				if machine == nil then
					return nil
				end
				local _condition_5 = command.MachineMastery[machine.Id]
				if _condition_5 == nil then
					_condition_5 = 0
				end
				local mastery = _condition_5
				local rank = math.floor(math.sqrt(mastery))
				local nextRank = math.pow(rank + 1, 2)
				local fill = if rank >= 99 then 1 else (mastery - rank * rank) / math.max(1, nextRank - rank * rank)
				return React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BorderSizePixel = 0,
					Active = false,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(0, 10),
				}), React.createElement(Text, {
					value = machine.Name,
					size = 12,
					color = Palette.cream,
					weight = Enum.FontWeight.Bold,
					fit = true,
					minSize = 9,
					position = UDim2.fromOffset(8, 6),
					sizeConstraint = UDim2.new(1, -70, 0, 18),
				}), React.createElement(Badge, {
					value = `RANK {rank}`,
					accent = machine.Color,
					filled = true,
					position = UDim2.new(1, -58, 0, 6),
					size = UDim2.fromOffset(48, 20),
				}), React.createElement(Meter, {
					value = fill,
					color = machine.Color,
					reducedMotion = reducedMotion,
					position = UDim2.fromOffset(8, 34),
					size = UDim2.new(1, -16, 0, 6),
				}), React.createElement(Text, {
					value = `{compactNumber(mastery)} built`,
					size = 10,
					color = Palette.muted,
					fit = false,
					position = UDim2.fromOffset(8, 44),
					sizeConstraint = UDim2.new(1, -16, 0, 14),
				}))
			end,
		})))
	end
	local _condition_4 = tab == "Expeditions"
	if _condition_4 then
		local _exp_6 = React.createElement(Text, {
			value = "Active trip",
			size = 12,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			sizeConstraint = UDim2.new(1, 0, 0, 16),
		})
		local _attributes = {}
		local _result_5 = activeConfig
		if _result_5 ~= nil then
			_result_5 = _result_5.Name
		end
		local _condition_5 = _result_5
		if _condition_5 == nil then
			_condition_5 = "No trip underway"
		end
		_attributes.value = _condition_5
		_attributes.size = if stack then 18 else 22
		_attributes.color = if expeditionReady then Palette.green else Palette.cream
		_attributes.weight = Enum.FontWeight.Heavy
		_attributes.fit = false
		_attributes.position = UDim2.fromOffset(0, 22)
		_attributes.sizeConstraint = UDim2.new(1, if stack then 0 else -230, 0, 28)
		_condition_4 = React.createElement(TabPane, {
			tabKey = "Expeditions",
			reducedMotion = reducedMotion,
		}, React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, expeditionHeroH),
			accent = if expeditionReady then Palette.green else Palette.cyan,
			background = Palette.panelRaised,
			padding = 14,
			layoutOrder = nextOrder(),
			reducedMotion = reducedMotion,
		}, _exp_6, React.createElement(Text, _attributes), React.createElement(Text, {
			value = statusLine,
			size = 12,
			color = Palette.muted,
			fit = false,
			position = UDim2.fromOffset(0, 54),
			sizeConstraint = UDim2.new(1, if stack then 0 else -230, 0, 18),
		}), React.createElement(Meter, {
			value = expeditionProgress,
			color = if expeditionReady then Palette.green else Palette.cyan,
			reducedMotion = reducedMotion,
			position = UDim2.fromOffset(0, 80),
			size = UDim2.new(1, if stack then 0 else -230, 0, 8),
		}), React.createElement("frame", {
			-- FocusClaim prefers Claim-named hosts; COLLECT is the expedition claim CTA.
			Name = "CommandClaimActions",
			Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(210, 48),
			Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -210, 0.5, -24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = if expeditionReady then claimHostRef else nil,
		}, React.createElement(Button, {
			text = claimLabel,
			icon = "Gift",
			onClick = function()
				return dispatch("ClaimExpedition")
			end,
			color = Palette.green,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			disabled = not expeditionReady,
			reducedMotion = reducedMotion,
			highlight = expeditionReady,
		}))), React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #ops.Expeditions,
			columns = 1,
			cellHeight = expeditionRowH,
			gap = Layout.panelGap,
			overscanRows = if softMotion then 0 else 1,
			layoutOrder = nextOrder(),
			itemKey = function(index)
				local expedition = ops.Expeditions[index + 1]
				return if expedition ~= nil then expedition.Id else `expedition-{index}`
			end,
			renderItem = function(index)
				local expedition = ops.Expeditions[index + 1]
				if expedition == nil then
					return nil
				end
				local locked = command.Level < expedition.RequiredLevel
				local busy = activeId ~= ""
				local can = not locked and not busy
				local _attributes_1 = {}
				local _condition_6 = expedition.ArtifactId
				if _condition_6 == nil then
					_condition_6 = expedition.Id
				end
				_attributes_1.kind = artifactIcon(_condition_6)
				_attributes_1.accent = expedition.Color
				_attributes_1.size = 46
				_attributes_1.radius = 12
				_attributes_1.position = UDim2.fromOffset(0, if stack then 6 else 18)
				_attributes_1.reducedMotion = reducedMotion
				return React.createElement(Panel, {
					size = UDim2.new(1, 0, 0, expeditionRowH),
					accent = expedition.Color,
					background = Palette.panel,
					padding = 14,
					interactive = true,
					highlight = can,
					reducedMotion = reducedMotion,
				}, React.createElement(IconTile, _attributes_1), React.createElement(Text, {
					value = `Lv {expedition.RequiredLevel}  ·  {clockText(expedition.Duration)}`,
					size = 11,
					color = expedition.Color,
					weight = Enum.FontWeight.Bold,
					fit = false,
					position = UDim2.fromOffset(58, 4),
					sizeConstraint = UDim2.new(1, if stack then -70 else -224, 0, 16),
				}), React.createElement(Text, {
					value = expedition.Name,
					size = 17,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					position = UDim2.fromOffset(58, 24),
					sizeConstraint = UDim2.new(1, if stack then -70 else -224, 0, 24),
				}), React.createElement(Text, {
					value = `{formatReward(expedition.Reward)}  ·  {string.format("%.0f", expedition.ArtifactChance * 100)}% relic`,
					size = 11,
					color = Palette.muted,
					wrap = true,
					fit = false,
					position = UDim2.fromOffset(58, 52),
					sizeConstraint = UDim2.new(1, if stack then -70 else -224, 0, 28),
				}), React.createElement(Button, {
					text = if locked then `Need lv {expedition.RequiredLevel}` elseif busy then "Crew away" else "LAUNCH",
					onClick = function()
						return dispatch("LaunchExpedition", {
							Id = expedition.Id,
						})
					end,
					color = expedition.Color,
					textColor = Palette.ink,
					size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(200, 46),
					position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -210, 0.5, -23),
					disabled = not can,
					reducedMotion = reducedMotion,
					highlight = can,
				}))
			end,
		}))
	end
	local bodyPane = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
	}, _exp_3, _condition_3, _condition_4, tab == "Artifacts" and React.createElement(TabPane, {
		tabKey = "Artifacts",
		reducedMotion = reducedMotion,
	}, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, artifactHeroH),
		accent = Palette.violet,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = nextOrder(),
		reducedMotion = reducedMotion,
	}, React.createElement(Text, {
		value = `Relics  {ownedArtifacts}/{#ops.Artifacts}`,
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = "Equip one relic. Duplicates add spark fragments for upgrades.",
		size = 12,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Meter, {
		value = ownedArtifacts / math.max(1, #ops.Artifacts),
		color = Palette.violet,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, 68),
		size = UDim2.new(1, 0, 0, 8),
	})), React.createElement(VirtualGrid, {
		scrollRef = scrollRef,
		count = #ops.Artifacts,
		columns = 1,
		cellHeight = artifactRowH,
		gap = Layout.panelGap,
		layoutOrder = nextOrder(),
		itemKey = function(index)
			local artifact = ops.Artifacts[index + 1]
			return if artifact ~= nil then artifact.Id else `artifact-{index}`
		end,
		renderItem = function(index)
			local artifact = ops.Artifacts[index + 1]
			if artifact == nil then
				return nil
			end
			local owned = command.Artifacts[artifact.Id]
			local equipped = command.EquippedArtifact == artifact.Id
			local fragmentCost = if owned then 4 + owned.Level * 2 else 0
			local dustCost = if owned then 8 * owned.Level else 0
			local canUpgrade = owned ~= nil and owned.Level < 10 and owned.Fragments >= fragmentCost and state.Stardust >= dustCost
			return React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, artifactRowH),
				accent = if owned then artifact.Color else Palette.lineSoft,
				background = if owned then Palette.panel else Palette.panelSoft,
				padding = 14,
				reducedMotion = reducedMotion,
			}, React.createElement(IconTile, {
				kind = artifactIcon(artifact.Id),
				accent = if owned then artifact.Color else Palette.muted,
				size = 46,
				radius = 12,
				position = UDim2.fromOffset(0, if stack then 6 else 18),
				reducedMotion = reducedMotion,
			}), React.createElement(Text, {
				value = if owned then `{artifact.Rarity}  ·  Lv {owned.Level}/10` else artifact.Rarity,
				size = 11,
				color = if owned then artifact.Color else Palette.muted,
				weight = Enum.FontWeight.Bold,
				fit = false,
				position = UDim2.fromOffset(58, 4),
				sizeConstraint = UDim2.new(1, if stack then -70 else -286, 0, 16),
			}), React.createElement(Text, {
				value = if owned then artifact.Name else "Mystery relic",
				size = 17,
				color = Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(58, 24),
				sizeConstraint = UDim2.new(1, if stack then -70 else -286, 0, 24),
			}), React.createElement(Text, {
				value = if owned then `{artifactEffect(artifact, owned.Level)}  ·  {owned.Fragments}/{fragmentCost} sparks` else "Finish its expedition to discover it.",
				size = 11,
				color = Palette.muted,
				fit = false,
				position = UDim2.fromOffset(58, 52),
				sizeConstraint = UDim2.new(1, if stack then -70 else -286, 0, 18),
			}), React.createElement("frame", {
				Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(260, 46),
				Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 8)) else UDim2.new(1, -270, 0.5, -23),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = if equipped then "IN USE" else "EQUIP",
				onClick = function()
					return dispatch("EquipArtifact", {
						Id = artifact.Id,
					})
				end,
				color = artifact.Color,
				textColor = Palette.ink,
				size = UDim2.new(0.5, -4, 1, 0),
				disabled = not owned or equipped,
				reducedMotion = reducedMotion,
			}), React.createElement(Button, {
				text = if not owned then "—" elseif owned.Level >= 10 then "MAX" else `{dustCost} dust`,
				onClick = function()
					return dispatch("UpgradeArtifact", {
						Id = artifact.Id,
					})
				end,
				color = Palette.mango,
				textColor = Palette.ink,
				size = UDim2.new(0.5, -4, 1, 0),
				position = UDim2.new(0.5, 4, 0, 0),
				disabled = not canUpgrade,
				reducedMotion = reducedMotion,
				highlight = canUpgrade,
			})))
		end,
	})), tab == "Season" and React.createElement(TabPane, {
		tabKey = "Season",
		reducedMotion = reducedMotion,
	}, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, seasonHeroH),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = nextOrder(),
		reducedMotion = reducedMotion,
	}, React.createElement(Text, {
		value = ops.SeasonName,
		size = 22,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Text, {
		value = `{compactNumber(command.SeasonXP)} season XP · {#ops.SeasonTiers} gifts`,
		size = 12,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(0, 36),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Meter, {
		value = seasonFill,
		color = Palette.mango,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, 64),
		size = UDim2.new(1, 0, 0, 9),
	}), React.createElement(Text, {
		value = seasonStatus,
		size = 12,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 82),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), React.createElement(VirtualGrid, {
		scrollRef = scrollRef,
		count = #ops.SeasonTiers,
		columns = 1,
		cellHeight = seasonRowH,
		gap = Layout.panelGap,
		overscanRows = if softMotion then 0 else 1,
		layoutOrder = nextOrder(),
		itemKey = function(index)
			local tier = ops.SeasonTiers[index + 1]
			return if tier ~= nil then tostring(tier.Tier) else `tier-{index}`
		end,
		renderItem = function(index)
			local tier = ops.SeasonTiers[index + 1]
			if tier == nil then
				return nil
			end
			local unlocked = command.SeasonXP >= tier.RequiredXP
			local claimed = command.SeasonClaims[tostring(tier.Tier)] == true
			local major = tier.Tier % 5 == 0
			local progressLabel = if claimed then "COLLECTED" elseif unlocked then "READY TO OPEN" else `{compactNumber(math.min(command.SeasonXP, tier.RequiredXP))} / {compactNumber(tier.RequiredXP)} XP`
			return React.createElement(Panel, {
				size = UDim2.new(1, 0, 0, seasonRowH),
				accent = if major then Palette.mango elseif unlocked then Palette.green else Palette.lineSoft,
				background = if major then Palette.panelRaised else Palette.panel,
				padding = 12,
				reducedMotion = reducedMotion,
			}, React.createElement("frame", {
				Size = UDim2.fromOffset(56, 56),
				BackgroundColor3 = if claimed then Palette.green elseif unlocked then Palette.mango else Palette.panelSoft,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement(Text, {
				value = string.format("%02d", tier.Tier),
				size = 20,
				color = if claimed or unlocked then Palette.ink else Palette.muted,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				align = Enum.TextXAlignment.Center,
				sizeConstraint = UDim2.fromScale(1, 1),
			})), React.createElement(Text, {
				value = if major then "Major gift" else "Rank gift",
				size = 14,
				color = if major then Palette.mango else Palette.cream,
				weight = Enum.FontWeight.Heavy,
				fit = false,
				position = UDim2.fromOffset(72, 8),
				sizeConstraint = UDim2.new(1, if stack then -(72 + 24) else -250, 0, 20),
			}), React.createElement(Text, {
				value = formatReward(tier.Reward),
				size = 12,
				color = Palette.muted,
				wrap = true,
				fit = false,
				position = UDim2.fromOffset(72, 32),
				sizeConstraint = UDim2.new(1, if stack then -(72 + 24) else -250, 0, 28),
			}), React.createElement(Meter, {
				value = meterFill(command.SeasonXP, tier.RequiredXP, claimed or unlocked),
				color = if major then Palette.mango else Palette.green,
				reducedMotion = reducedMotion,
				position = UDim2.fromOffset(72, if stack then 64 else 72),
				size = UDim2.new(1, if stack then -84 else -250, 0, 7),
			}), if stack then React.createElement("frame", {
				Name = "CommandClaimActions",
				Size = UDim2.new(1, -24, 0, TapTarget),
				Position = UDim2.new(0, 12, 1, -(TapTarget + 8)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ref = if unlocked and not claimed and tier.Tier == firstReadySeasonTier then claimHostRef else nil,
			}, React.createElement(Button, {
				text = if claimed then "CLAIMED" elseif unlocked then "OPEN" else "LOCKED",
				onClick = function()
					return dispatch("ClaimSeasonTier", {
						Tier = tier.Tier,
					})
				end,
				color = if major then Palette.mango else Palette.green,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				disabled = claimed or not unlocked,
				reducedMotion = reducedMotion,
				highlight = unlocked and not claimed,
			})) else React.createElement(React.Fragment, nil, React.createElement(Text, {
				value = progressLabel,
				size = 11,
				color = if unlocked then Palette.green else Palette.muted,
				fit = false,
				position = UDim2.fromOffset(72, 54),
				sizeConstraint = UDim2.new(1, -250, 0, 16),
			}), React.createElement("frame", {
				Name = "CommandClaimActions",
				Size = UDim2.fromOffset(150, 44),
				Position = UDim2.new(1, -158, 0.5, -22),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = false,
				ref = if unlocked and not claimed and tier.Tier == firstReadySeasonTier then claimHostRef else nil,
			}, React.createElement(Button, {
				text = if claimed then "CLAIMED" elseif unlocked then "OPEN" else "LOCKED",
				onClick = function()
					return dispatch("ClaimSeasonTier", {
						Tier = tier.Tier,
					})
				end,
				color = if major then Palette.mango else Palette.green,
				textColor = Palette.ink,
				size = UDim2.fromScale(1, 1),
				disabled = claimed or not unlocked,
				reducedMotion = reducedMotion,
				highlight = unlocked and not claimed,
			}))))
		end,
	})))
	-- Fill body expands into leftover viewport when the tab is short; intrinsic height
	-- (content floor) keeps hostRef VirtualGrid rows reachable when the list is long.
	local bodyIntrinsic = if useFillList then tabHeroH + listContent + Layout.panelGap else tabContent
	return React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = Layout.panelGap,
		tailPad = commandTail,
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = headerH,
				element = _exp_4,
			},
			{
				id = "tabs",
				height = tabsH,
				element = _exp_5,
			},
			{
				id = "body",
				fill = true,
				minHeight = 200,
				height = bodyIntrinsic,
				element = bodyPane,
			},
		},
	})
end
return {
	CommandView = CommandView,
}
