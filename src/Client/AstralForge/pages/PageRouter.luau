local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _flexbox = require(script.Parent.Parent.flexbox)
local Flex = _flexbox.Flex
local FlexItem = _flexbox.FlexItem
local PlayerMark = require(script.Parent.Parent.Icon).PlayerMark
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.Parent.motion)
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.ui)
local AmountToggle = _ui.AmountToggle
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local SCROLL_EDGE = _ui.SCROLL_EDGE
local ScrollPads = _ui.ScrollPads
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local SearchField = _ui.SearchField
local ShimmerText = _ui.ShimmerText
local Text = _ui.Text
local NumberSpinnerHost = require(script.Parent.Parent.NumberSpinnerHost).NumberSpinnerHost
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.format)
local amountPayload = _format.amountPayload
local asFlux = _format.asFlux
local bulkCost = _format.bulkCost
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local compareFlux = _format.compareFlux
local formatReward = _format.formatReward
local gteFlux = _format.gteFlux
local VirtualGrid = require(script.Parent.Parent.scrolling).VirtualGrid
local Audio = require(script.Parent.Parent.audio).Audio
local function lazyView(moduleName, exportName)
	local component
	return function(props)
		if component == nil then
			component = require(script.Parent[moduleName])[exportName]
		end
		return React.createElement(component, props)
	end
end
local MissionsView = lazyView("MissionsView", "MissionsView")
local MilestonesView = lazyView("MilestonesView", "MilestonesView")
local AnomalyView = lazyView("AnomalyView", "AnomalyView")
local LabView = lazyView("LabView", "LabView")
local StoryView = lazyView("StoryView", "StoryView")
local StarGridView = lazyView("StarGridView", "StarGridView")
local CommandView = lazyView("CommandView", "CommandView")
local MailboxView = lazyView("MailboxView", "MailboxView")
local ChatView = lazyView("ChatView", "ChatView")
local ShopView = lazyView("ShopView", "ShopView")
local InventoryView = lazyView("InventoryView", "InventoryView")
local GuildView = lazyView("GuildView", "GuildView")
local LeaderboardsView = lazyView("LeaderboardsView", "LeaderboardsView")
local TradeView = lazyView("TradeView", "TradeView")
local SettingsView = lazyView("SettingsView", "SettingsView")
local ContinuumView = lazyView("ContinuumView", "ContinuumView")
local ConvergenceView = lazyView("ConvergenceView", "ConvergenceView")
local AdminView = lazyView("AdminView", "AdminView")
local RebirthPanel = lazyView("RebirthPanel", "RebirthPanel")
local EchoForgeView = lazyView("EchoForgeView", "EchoForgeView")
local CinematicWheelView = lazyView("WheelView", "WheelView")
local ForgePathView = lazyView("ForgePathView", "ForgePathView")
local ResearchView = lazyView("ResearchView", "ResearchView")
local BoostsView = lazyView("BoostsView", "BoostsView")
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local LayoutSectionPlan = require(script.Parent.Parent.layoutSectionPlan)
local VaultCollectEligibility = require(script.Parent.Parent.vaultCollectEligibility)
local PageReadyMath = require(script.Parent.Parent.pageReadyMath)
local PageBoardHeights = require(script.Parent.Parent.pageBoardHeights)
local ReleaseClockMath = require(script.Parent.Parent.releaseClockMath)
local function Metric(_param)
	local label = _param.label
	local value = _param.value
	local detail = _param.detail
	local accent = _param.accent
	local size = _param.size
	if size == nil then
		size = UDim2.new(1, 0, 0, 92)
	end
	local layoutOrder = _param.layoutOrder
	if layoutOrder == nil then
		layoutOrder = 0
	end
	local reveal = _param.reveal
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	return React.createElement(Panel, {
		size = size,
		background = Palette.panelRaised,
		padding = if compact then 10 else 14,
		layoutOrder = layoutOrder,
		reveal = reveal,
	}, React.createElement(Text, {
		value = label,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = value,
		size = if compact then 18 else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, if compact then 16 else 19),
		sizeConstraint = UDim2.new(1, 0, 0, if compact then 22 else 32),
	}), React.createElement(Text, {
		value = detail,
		size = if compact then 9 else 10,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, if compact then 40 else 56),
		sizeConstraint = UDim2.new(1, 0, 0, if compact then 14 else 17),
	}))
end
local function ReleaseCountdown(_param)
	local releaseAt = _param.releaseAt
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local layoutOrder = _param.layoutOrder
	local viewport = useViewport()
	local antilag = useAntilag()
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
	local remaining = ReleaseClockMath.Remaining(releaseAt, now)
	local live = ReleaseClockMath.IsLive(releaseAt, now)
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
	-- Live wash/orbit are decorative; keep them on high tier only so Overview stays calm under load.
	local animateLive = live and not reducedMotion and antilag.allowAmbient
	local pulse = usePulse(animateLive, 2.15)
	local flash = useFlash(slam, reducedMotion, 1.2)
	local orbit = useClock(animateLive and antilag.tier >= 2, 0.48, 1, true)
	local values = { {
		label = "DAYS",
		value = math.floor(remaining / 86400),
		color = Palette.cyan,
	}, {
		label = "HOURS",
		value = math.floor(remaining / 3600) % 24,
		color = Palette.violet,
	}, {
		label = "MINUTES",
		value = math.floor(remaining / 60) % 60,
		color = Palette.pink,
	}, {
		label = "SECONDS",
		value = remaining % 60,
		color = Palette.mango,
	} }
	local railBelowCopy = stack or viewport.width < 1080
	local height = if live then (if railBelowCopy then 170 else 148) elseif railBelowCopy then 162 else 132
	local railTop = if live then (if railBelowCopy then 78 else 36) elseif railBelowCopy then 68 else 28
	local railLeft = if live then 0 elseif railBelowCopy then 0 else 360
	local accent = if live then Palette.mint else Palette.cyan
	local wash = if live then pulse:map(function(amount)
		return 0.88 - amount * 0.22
	end) else 1
	local _exp = live and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mint,
		BackgroundTransparency = wash,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}))
	local _exp_1 = React.createElement(IconTile, {
		kind = "Calendar",
		accent = accent,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, 2),
		glow = live,
		spin = live and not reducedMotion,
		reducedMotion = reducedMotion,
	})
	local _exp_2 = React.createElement(Text, {
		value = if live then "LAUNCH" else "RELEASE COUNTDOWN",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(58, 2),
		sizeConstraint = UDim2.new(1, if railBelowCopy then -58 else -420, 0, 16),
	})
	local _exp_3 = React.createElement(Text, {
		value = if live then "Astral Forge is now live." else "Official launch is August 31, 2026.",
		size = if railBelowCopy then 17 else 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 13,
		position = UDim2.fromOffset(58, 21),
		sizeConstraint = UDim2.new(1, if railBelowCopy then -58 else -420, 0, 28),
	})
	local _result
	if live then
		local _condition = not reducedMotion
		if _condition then
			local _exp_4 = { 0, 1, 2, 3, 4, 5, 6, 7 }
			-- ▼ ReadonlyArray.map ▼
			local _newValue = table.create(#_exp_4)
			local _callback = function(index)
				return React.createElement("frame", {
					key = index,
					Size = flash:map(function(amount)
						return UDim2.fromOffset(5 + math.floor(amount * 6), 5 + math.floor(amount * 6))
					end),
					Position = orbit:map(function(turn)
						local angle = turn * math.pi * 2 + index * (math.pi / 4)
						local radius = 86 + math.sin(turn * math.pi * 2 + index) * 10
						return UDim2.new(0.5, math.floor(math.cos(angle) * radius), 0.5, math.floor(math.sin(angle) * 22))
					end),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = if index % 2 == 0 then Palette.mint else Palette.cyan,
					BackgroundTransparency = pulse:map(function(amount)
						return 0.08 + (1 - amount) * 0.5
					end),
					BorderSizePixel = 0,
					ZIndex = 4,
				}, React.createElement("uicorner", {
					CornerRadius = UDim.new(1, 0),
				}))
			end
			for _k, _v in _exp_4 do
				_newValue[_k] = _callback(_v, _k - 1, _exp_4)
			end
			-- ▲ ReadonlyArray.map ▲
			_condition = _newValue
		end
		_result = React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, _condition, React.createElement("frame", {
			Size = UDim2.new(0.62, 0, 1, -4),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, React.createElement("uiscale", {
			Scale = flash:map(function(amount)
				return 1 + amount * 0.28
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = Palette.mint,
			Thickness = flash:map(function(amount)
				return 1.2 + amount * 2.4
			end),
			Transparency = pulse:map(function(amount)
				return 0.08 + (1 - amount) * 0.32
			end),
		}), React.createElement(ShimmerText, {
			value = "LIVE",
			size = if stack then 26 else 32,
			color = Palette.mint,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 16,
			sizeConstraint = UDim2.fromScale(1, 1),
			enabled = not reducedMotion,
			periodSeconds = 1.6,
			reducedMotion = reducedMotion,
		})))
	else
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#values)
		local _callback = function(entry, index)
			return React.createElement("frame", {
				key = entry.label,
				Size = UDim2.new(0.25, -6, 1, 0),
				Position = UDim2.new(index * 0.25, if index == 0 then 0 else 6, 0, 0),
				BackgroundColor3 = Palette.ink,
				BackgroundTransparency = 0.04,
				BorderSizePixel = 0,
				ClipsDescendants = false,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement("uigradient", {
				Color = surfaceGradient(Palette.ink, 0.8),
				Rotation = 90,
			}), React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = entry.color,
				Thickness = 1,
				Transparency = 0.42,
			}), React.createElement("frame", {
				Size = UDim2.new(0.42, 0, 0, 2),
				Position = UDim2.new(0.29, 0, 0, 0),
				BackgroundColor3 = entry.color,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			})), React.createElement(NumberSpinnerHost, {
				value = entry.value,
				reducedMotion = reducedMotion,
				duration = 0.36,
				size = if stack then 20 else 24,
				color = entry.color,
				align = Enum.TextXAlignment.Center,
				position = UDim2.fromOffset(0, 5),
				sizeConstraint = UDim2.new(1, 0, 0, 30),
			}), React.createElement(Text, {
				value = entry.label,
				size = 10,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.Heavy,
				align = Enum.TextXAlignment.Center,
				fit = false,
				position = UDim2.new(0, 0, 1, -22),
				sizeConstraint = UDim2.new(1, 0, 0, 16),
			}))
		end
		for _k, _v in values do
			_newValue[_k] = _callback(_v, _k - 1, values)
		end
		-- ▲ ReadonlyArray.map ▲
		_result = _newValue
	end
	return React.createElement(Panel, {
		layoutOrder = layoutOrder,
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = Palette.panelRaised,
		padding = 16,
		reducedMotion = reducedMotion,
		highlight = live,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("frame", {
		Size = UDim2.new(1, -railLeft, 0, if railBelowCopy then 58 else 68),
		Position = UDim2.fromOffset(railLeft, railTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _result))
end

local function countReadyQuests(quests)
	return PageReadyMath.CountReadyQuests(quests)
end
local function countReadyLabOrders(lab)
	return PageReadyMath.CountReadyLabOrders(lab)
end
local function forgePathReady(state, config)
	return PageReadyMath.ForgePathReady(state, config)
end
local function anomalyReadyFrom(anomaly)
	return PageReadyMath.AnomalyReady(anomaly)
end
local function OverviewView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local effectsPaused = _param.effectsPaused
	local openWorkshop = _param.openWorkshop
	local openDomain = _param.openDomain
	local releaseAt = _param.releaseAt
	local navigate = _param.navigate
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Drop entrance/stagger springs when antilag already wants skipEntrance or
	-- ambient motion is off — Overview mounts several stagger clocks at once.
	local quietMotion = reducedMotion or effectsPaused or antilag.skipEntrance or not antilag.allowAmbient
	local softMotion = quietMotion or antilag.tier <= 1
	local stack = chrome.contentStack
	local phone = chrome.stack
	local canCollect = VaultCollectEligibility.isEligible(asFlux(state.Vault))
	local canRebirth = gteFlux(state.PrestigeReward, 1)
	local target = asFlux(state.NextPrestigeTarget)
	local progress = if canRebirth then 1 else meterFill(asFlux(state.RunCash), math.max(1, target))
	local vaultFill = meterFill(asFlux(state.Vault), asFlux(state.Capacity))
	local vaultFull = VaultCollectEligibility.isFull(vaultFill)
	local vaultNearFull = VaultCollectEligibility.isNearFull(vaultFill)
	local _condition = state.CapacitySeconds
	if _condition == nil then
		_condition = 0
	end
	local vaultSeconds = _condition
	local rebirthVisible = AppHelpers:featureUnlocked(state, "Rebirth")
	local domainVisible = AppHelpers:featureUnlocked(state, "Domain")
	local heroReveal = useStagger(0, quietMotion)
	local metricsReveal = useStagger(1, quietMotion)
	local rebirthReveal = useStagger(2, quietMotion)
	local domainReveal = useStagger(3, quietMotion)
	local notesReveal = useStagger(4, quietMotion)
	local opsReveal = useStagger(5, quietMotion)
	local collectTrigger, setCollectTrigger = React.useState(0)
	local collectFlash = useFlash(collectTrigger, softMotion, 0.42)
	local fireCollect = function()
		if not canCollect then
			return nil
		end
		setCollectTrigger(function(value)
			return value + 1
		end)
		return dispatch("CollectVault")
	end
	local missionsReady = countReadyQuests(state.Quests)
	local labReady = countReadyLabOrders(state.Lab)
	local pathReady = forgePathReady(state, config)
	local anomalyReady = anomalyReadyFrom(state.Anomaly)
	local opsClaims = PageReadyMath.OpsClaims(missionsReady, labReady, pathReady, anomalyReady)
	local opsGuide = if config ~= nil and config.ClientPageGuides ~= nil then config.ClientPageGuides.Overview else nil
	local overchargeTrigger, setOverchargeTrigger = React.useState(0)
	local overchargeReadyAt, setOverchargeReadyAt = React.useState(0)
	local overchargeLeft, setOverchargeLeft = React.useState(0)
	local overchargeFlash = useFlash(overchargeTrigger, softMotion, 0.3)
	React.useEffect(function()
		if overchargeReadyAt <= 0 then
			setOverchargeLeft(0)
			return nil
		end
		local alive = true
		local worker = task.spawn(function()
			while alive do
				local left = math.max(0, overchargeReadyAt - os.clock())
				setOverchargeLeft(left)
				if left <= 0 then
					break
				end
				task.wait(0.05)
			end
		end)
		return function()
			alive = false
			task.cancel(worker)
		end
	end, { overchargeReadyAt })
	local fireOvercharge = function()
		if os.clock() < overchargeReadyAt then
			return nil
		end
		Audio:play("reactorPulse")
		setOverchargeTrigger(function(value)
			return value + 1
		end)
		setOverchargeReadyAt(os.clock() + 0.45)
		setOverchargeLeft(0.45)
		dispatch("Overcharge")
	end
	local overchargeLabel = if overchargeLeft > 0.02 then `WAIT {string.format("%.1f", overchargeLeft)}s` else "OVERCHARGE"
	local landscapePhone = phone and chrome.landscape
	-- Wide PC: vault hero sits beside the metrics column instead of stacking full-width bands.
	local wideOverview = not stack and viewport.width >= 1180
	local ultraOverview = not stack and viewport.width >= 1680
	-- Portrait stacks CTAs under the vault readout; landscape puts them side-by-side so both
	-- stay above the fold on ~320–390px-tall screens. Desktop keeps the right-rail CTA column.
	local countdownInPage = type(releaseAt) == "number" and releaseAt > (function()
		local ok, value = pcall(function()
			return game:GetService("Workspace"):GetServerTimeNow()
		end)
		if ok and type(value) == "number" then
			return value
		end
		return os.time()
	end)()
	local overviewPlan = LayoutSectionPlan.planOverview({
		stack = stack,
		phone = phone,
		landscapePhone = landscapePhone,
		wideOverview = wideOverview,
		ultraOverview = ultraOverview,
		rebirthVisible = rebirthVisible,
		domainVisible = domainVisible,
		countdownInPage = countdownInPage,
		chromePanelGap = chrome.panelGap,
		layoutPanelGap = Layout.panelGap,
	})
	local heroH = overviewPlan.heroH
	local rebirthH = overviewPlan.rebirthH
	local domainH = overviewPlan.domainH
	local notesH = overviewPlan.notesH
	local opsH = overviewPlan.opsH
	local metricCardH = overviewPlan.metricCardH
	local metricsH = overviewPlan.metricsH
	local countdownH = overviewPlan.countdownH
	local sectionGap = overviewPlan.sectionGap
	local topBandH = overviewPlan.topBandH
	local overviewTail = overviewPlan.overviewTail
	local columnMax = if stack then math.huge else Layout.contentMaxWidth
	local columnPad = if not stack and viewport.width >= Layout.contentMaxWidth + 80 then 12 else 0
	local ctaH = TapTarget
	local heroReadoutH = if landscapePhone then 108 elseif phone then 168 else 0
	local phoneCtaBlockH = if landscapePhone then ctaH + 8 else ctaH * 2 + 12
	local opsButtonRows = if stack then 2 else 1
	local opsButtonH = TapTarget * opsButtonRows + (if stack then 8 else 0)
	local domain = state.Domain or {
		Rank = 0,
		Essence = 0,
		LastExpandedAt = 0,
		TotalRebirthsSpent = 0,
		TotalCoresSpent = 0,
		RequiredRebirths = 10,
		RequiredCores = 25,
		CanExpand = false,
		EssenceReward = 3,
		StardustReward = 250,
		ProductionMultiplier = 1,
		CapacityMultiplier = 1,
		OfflineBonus = 0,
		SkillPoints = 0,
		Nodes = {},
	}
	local domainProgress = math.min(math.clamp(asFlux(state.Rebirths) / math.max(1, asFlux(domain.RequiredRebirths)), 0, 1), math.clamp(asFlux(state.Cores) / math.max(1, asFlux(domain.RequiredCores)), 0, 1))
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -columnPad * 2, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uisizeconstraint", {
		MaxSize = Vector2.new(columnMax, math.huge),
	}), React.createElement(PageScaffold, {
		gap = sectionGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, overviewTail),
		scrollBarColor = Palette.green,
		scrollBarThickness = 4,
		sections = {
			{
				id = "top",
				height = topBandH,
				element = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = if wideOverview then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, if wideOverview then (if ultraOverview then 16 else 12) else sectionGap),
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}), React.createElement(Panel, {
		layoutOrder = 0,
		size = if wideOverview then UDim2.new(0.62, -6, 1, 0) else UDim2.new(1, 0, 0, heroH),
		accent = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		background = Palette.panelRaised,
		padding = if stack then chrome.cardPadding elseif ultraOverview then 22 else 20,
		reveal = heroReveal,
		highlight = vaultFill >= 0.99 and not effectsPaused,
		reducedMotion = quietMotion,
		clips = false,
	}, React.createElement("uigradient", {
		Color = surfaceGradient(if vaultFill >= 0.99 then Palette.mango else Palette.green, 0.94),
		Rotation = 62,
	}), React.createElement("frame", {
		Size = if phone then UDim2.new(1, 0, 0, heroReadoutH) else UDim2.new(1, -246, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}, React.createElement(Text, {
		value = "CURRENT RUN",
		size = 10,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = compactNumber(state.Vault),
		size = if landscapePhone then 32 elseif stack then 38 else 46,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 22,
		position = UDim2.fromOffset(0, if landscapePhone then 12 else 18),
		sizeConstraint = UDim2.new(1, 0, 0, if landscapePhone then 36 else 54),
	}), React.createElement(Text, {
		value = `of {compactNumber(state.Capacity)} vault capacity`,
		size = if stack then chrome.labelText else 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, if landscapePhone then 46 elseif stack then 70 else 74),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), React.createElement(Meter, {
		value = vaultFill,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.green,
		reducedMotion = quietMotion,
		shimmer = vaultFill >= 0.99 and not effectsPaused,
		position = UDim2.fromOffset(0, if landscapePhone then 66 elseif stack then 96 else 100),
		size = UDim2.new(1, 0, 0, 10),
	}), React.createElement(Text, {
		value = if vaultFill >= 0.99 then "Vault full — production is being wasted." else `{compactNumber(state.Production)} flux / sec flowing in`,
		size = if stack then chrome.labelText else 11,
		color = if vaultFill >= 0.99 then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(0, if landscapePhone then 80 elseif stack then 112 else 116),
		sizeConstraint = UDim2.new(1, 0, 0, if landscapePhone then 22 else 28),
	})), if phone then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, phoneCtaBlockH),
		Position = UDim2.new(0, 0, 1, -(phoneCtaBlockH + 4)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = if landscapePhone then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}), React.createElement(Button, {
		text = if landscapePhone then "COLLECT" else "COLLECT VAULT",
		icon = "Collect",
		onClick = fireCollect,
		color = Palette.green,
		textColor = Palette.ink,
		size = if landscapePhone then UDim2.new(0.5, -4, 0, ctaH) else UDim2.new(1, 0, 0, ctaH),
		reducedMotion = softMotion,
		disabled = not canCollect,
		highlight = vaultFill >= 0.85,
	}), React.createElement(Button, {
		text = overchargeLabel,
		icon = "Overcharge",
		onClick = fireOvercharge,
		sound = "reactorPulse",
		color = if overchargeLeft > 0.02 then Palette.panelSoft else Palette.mango,
		textColor = if overchargeLeft > 0.02 then Palette.muted else Palette.ink,
		size = if landscapePhone then UDim2.new(0.5, -4, 0, ctaH) else UDim2.new(1, 0, 0, ctaH),
		reducedMotion = softMotion,
		disabled = overchargeLeft > 0.02,
	}), not landscapePhone and React.createElement(Meter, {
		value = if overchargeLeft > 0 then 1 - overchargeLeft / 0.45 else 1,
		color = Palette.mango,
		reducedMotion = quietMotion,
		position = UDim2.new(0, 0, 1, -4),
		size = UDim2.new(1, 0, 0, 4),
	}), React.createElement("frame", {
		Size = React.joinBindings({ collectFlash, overchargeFlash }):map(function(values)
			local amount = math.max(values[1], values[2])
			return UDim2.new(amount, 0, 0, 2)
		end),
		Position = UDim2.new(0.5, 0, 1, -2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = React.joinBindings({ collectFlash, overchargeFlash }):map(function(values)
			return 1 - math.max(values[1], values[2])
		end),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))) else React.createElement("frame", {
		Size = UDim2.fromOffset(230, 168),
		Position = UDim2.new(1, -230, 0, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, Layout.controlGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "COLLECT VAULT",
		icon = "Collect",
		onClick = fireCollect,
		color = Palette.green,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, ctaH),
		reducedMotion = softMotion,
		disabled = not canCollect,
		highlight = vaultFill >= 0.85,
	}), React.createElement(Button, {
		text = overchargeLabel,
		icon = "Overcharge",
		onClick = fireOvercharge,
		sound = "reactorPulse",
		color = if overchargeLeft > 0.02 then Palette.panelSoft else Palette.mango,
		textColor = if overchargeLeft > 0.02 then Palette.muted else Palette.ink,
		size = UDim2.new(1, 0, 0, ctaH),
		reducedMotion = softMotion,
		disabled = overchargeLeft > 0.02,
	}), React.createElement(Meter, {
		value = if overchargeLeft > 0 then 1 - overchargeLeft / 0.45 else 1,
		color = Palette.mango,
		reducedMotion = quietMotion,
		size = UDim2.new(1, 0, 0, 4),
	}), React.createElement(Text, {
		value = if overchargeLeft > 0.02 then `Ready in {string.format("%.1f", overchargeLeft)}s` else "Tap for a quick vault burst",
		size = 10,
		color = if overchargeLeft > 0.02 then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		align = Enum.TextXAlignment.Center,
	}), React.createElement("frame", {
		Size = collectFlash:map(function(amount)
			return UDim2.new(amount, 0, 0, 2)
		end),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = collectFlash:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))), React.createElement(Flex, {
		direction = if wideOverview or stack then "column" else "row",
		wrap = false,
		justify = "fill",
		align = "stretch",
		gap = if stack then 10 elseif ultraOverview then 12 elseif wideOverview then 8 else 12,
		size = if wideOverview then UDim2.new(0.38, -6, 1, 0) else UDim2.new(1, 0, 0, metricsH),
		layoutOrder = 1,
		exact = true,
	}, React.createElement(FlexItem, {
		mode = "fill",
		minWidth = if stack then 160 else 160,
		minHeight = if stack then metricCardH elseif wideOverview then metricCardH else 72,
		layoutOrder = 0,
	}, React.createElement(Metric, {
		label = "LIVE OUTPUT",
		value = `{compactNumber(state.Production)} / sec`,
		detail = `{compactNumber(state.RawProduction)} base`,
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		compact = stack,
		reveal = metricsReveal,
	})), React.createElement(FlexItem, {
		mode = "fill",
		minWidth = if stack then 160 else 180,
		minHeight = if stack then metricCardH elseif wideOverview then metricCardH else 72,
		layoutOrder = 1,
	}, React.createElement(Metric, {
		label = "BANKED FLUX",
		value = compactNumber(state.Cash),
		detail = `{compactNumber(state.RunCash)} this run`,
		accent = Palette.mango,
		size = UDim2.fromScale(1, 1),
		compact = stack,
		reveal = metricsReveal,
	})), React.createElement(FlexItem, {
		mode = "fill",
		minWidth = if stack then 160 else 180,
		minHeight = if stack then metricCardH elseif wideOverview then metricCardH else 72,
		layoutOrder = 2,
	}, React.createElement(Metric, {
		label = "LONG-TERM",
		value = `{compactNumber(state.PermanentMultiplier)}x`,
		detail = `{compactNumber(state.Rebirths)} resets`,
		accent = Palette.violet,
		size = UDim2.fromScale(1, 1),
		compact = stack,
		reveal = metricsReveal,
	})))),
			},
			{
				id = "notes",
				height = notesH,
				element = React.createElement(Panel, {
		layoutOrder = 2,
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = if stack then chrome.cardPadding elseif ultraOverview then 20 else 18,
		reveal = notesReveal,
		clips = false,
	}, (function()
		local title = "Push toward rebirth"
		local body = `Auto-collect {math.floor(math.clamp(state.AutoCollectRate, 0, 1) * 100 + 0.5)}% · offline {math.floor(state.OfflineHours + 0.5)}h · vault holds {clockText(vaultSeconds)}.`
		local meter = progress
		local accent = Palette.cyan
		local cta = ""
		local ctaAction
		local statValue = `{math.floor(progress * 100 + 0.5)}%`
		local statLabel = "TO REBIRTH"
		if vaultFill >= 0.99 then
			title = "Bank the vault"
			body = "You're wasting production while the vault is full. Collect, then buy more machines."
			meter = 1
			accent = Palette.mango
			cta = "COLLECT VAULT"
			ctaAction = function()
				return dispatch("CollectVault")
			end
			statValue = "FULL"
			statLabel = "VAULT"
		else
			local _condition_1 = state.Machines.StellarCore
			if _condition_1 == nil then
				_condition_1 = 0
			end
			if _condition_1 < 1 then
				title = "Buy Stellar Core"
				body = "Open Workshop and buy your first machine — income starts there."
				meter = 0.08
				cta = "OPEN WORKSHOP"
				ctaAction = openWorkshop
				statValue = "0"
				statLabel = "MACHINES"
			else
				local _condition_2 = state.Research.Efficiency
				if _condition_2 == nil then
					_condition_2 = 0
				end
				if _condition_2 < 3 then
					title = "Research Efficiency to 3"
					body = "Research is permanent. Raise Quantum Efficiency to unlock Storage."
					local _condition_3 = state.Research.Efficiency
					if _condition_3 == nil then
						_condition_3 = 0
					end
					meter = math.clamp(_condition_3 / 3, 0, 1)
					cta = "OPEN RESEARCH"
					ctaAction = function()
						local _result = navigate
						if _result ~= nil then
							_result = _result("Research")
						end
						return _result
					end
					local _condition_4 = state.Research.Efficiency
					if _condition_4 == nil then
						_condition_4 = 0
					end
					statValue = `{_condition_4}/3`
					statLabel = "EFFICIENCY"
				else
					local _condition_3 = state.Research.Storage
					if _condition_3 == nil then
						_condition_3 = 0
					end
					if _condition_3 < 3 then
						title = "Research Storage to 3"
						body = "Dimensional Storage grows the vault so you can AFK longer."
						local _condition_4 = state.Research.Storage
						if _condition_4 == nil then
							_condition_4 = 0
						end
						meter = math.clamp(_condition_4 / 3, 0, 1)
						cta = "OPEN RESEARCH"
						ctaAction = function()
							local _result = navigate
							if _result ~= nil then
								_result = _result("Research")
							end
							return _result
						end
						local _condition_5 = state.Research.Storage
						if _condition_5 == nil then
							_condition_5 = 0
						end
						statValue = `{_condition_5}/3`
						statLabel = "STORAGE"
					else
						local _condition_4 = state.Research.Offline
						if _condition_4 == nil then
							_condition_4 = 0
						end
						if _condition_4 < 1 then
							title = "Unlock Deep-Space Relay"
							body = "Buy Deep-Space Relay next — it unlocks after Storage 3, before Overcharge."
							meter = 0.15
							cta = "OPEN RESEARCH"
							ctaAction = function()
								local _result = navigate
								if _result ~= nil then
									_result = _result("Research")
								end
								return _result
							end
							statValue = "NEXT"
							statLabel = "RELAY"
						else
							local _condition_5 = state.Research.Overcharge
							if _condition_5 == nil then
								_condition_5 = 0
							end
							if _condition_5 < 1 then
								title = "Unlock Overcharge Coil"
								body = "Overcharge Coil boosts taps. It's next in the research chain."
								meter = 0.2
								cta = "OPEN RESEARCH"
								ctaAction = function()
									local _result = navigate
									if _result ~= nil then
										_result = _result("Research")
									end
									return _result
								end
								statValue = "NEXT"
								statLabel = "COIL"
							elseif canRebirth then
								title = "Rebirth for cores"
								body = `Reset this run's machines. Keep research. Bank {compactNumber(state.PrestigeReward)} cores from the panel below.`
								meter = 1
								accent = Palette.pink
								statValue = `+{compactNumber(state.PrestigeReward)}`
								statLabel = "CORES READY"
							elseif progress < 0.45 then
								title = "Grow run flux"
								body = "Buy machines, bank often, and clear missions. Overview tracks rebirth progress."
								cta = "OPEN WORKSHOP"
								ctaAction = openWorkshop
								statValue = `{math.floor(progress * 100 + 0.5)}%`
								statLabel = "TO REBIRTH"
							end
						end
					end
				end
			end
		end
		local copyLeft = if stack then 0 else 48
		local copyWidth = if stack then 0 else -220
		local action = ctaAction
		local showCta = not stack and cta ~= "" and action ~= nil
		return React.createElement(React.Fragment, nil, not stack and React.createElement(IconTile, {
			kind = "Milestone",
			accent = accent,
			size = 34,
			radius = 10,
			position = UDim2.fromOffset(0, 0),
			spin = false,
			reducedMotion = quietMotion,
		}), React.createElement(Text, {
			value = "NEXT GOAL",
			size = 10,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(copyLeft, if stack then 0 else 2),
			sizeConstraint = UDim2.new(1, copyWidth - copyLeft, 0, 16),
		}), React.createElement(Text, {
			value = title,
			size = if stack then 19 else 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 14,
			position = UDim2.fromOffset(copyLeft, 22),
			sizeConstraint = UDim2.new(1, copyWidth - copyLeft, 0, 28),
		}), React.createElement(Text, {
			value = body,
			size = if stack then chrome.labelText else 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(copyLeft, 52),
			sizeConstraint = UDim2.new(1, copyWidth - copyLeft, 0, if stack then 48 else 36),
		}), React.createElement(Meter, {
			value = meter,
			color = accent,
			reducedMotion = quietMotion,
			shimmer = meter >= 0.99 and not effectsPaused,
			position = UDim2.fromOffset(copyLeft, if stack then notesH - (if cta ~= "" then TapTarget + 28 else 28) else notesH - 40),
			size = UDim2.new(1, copyWidth - copyLeft, 0, 8),
		}), not stack and React.createElement("frame", {
			Size = UDim2.fromOffset(196, 108),
			Position = UDim2.new(1, -196, 0, 4),
			BackgroundColor3 = Palette.ink,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
			Color = accent,
			Thickness = 1,
			Transparency = 0.55,
		}), React.createElement(Text, {
			value = statValue,
			size = 22,
			color = accent,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = true,
			minSize = 14,
			position = UDim2.fromOffset(8, if showCta then 8 else 24),
			sizeConstraint = UDim2.new(1, -16, 0, 32),
		}), React.createElement(Text, {
			value = statLabel,
			size = 10,
			color = Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			align = Enum.TextXAlignment.Center,
			fit = false,
			position = UDim2.fromOffset(8, if showCta then 40 else 58),
			sizeConstraint = UDim2.new(1, -16, 0, 16),
		}), showCta and action ~= nil and React.createElement(Button, {
			text = cta,
			onClick = action,
			color = accent,
			textColor = Palette.ink,
			size = UDim2.new(1, -16, 0, 36),
			position = UDim2.fromOffset(8, 64),
			reducedMotion = reducedMotion,
			highlight = meter >= 0.99,
		})), stack and cta ~= "" and action ~= nil and React.createElement(Button, {
			text = cta,
			onClick = action,
			color = accent,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -TapTarget),
			reducedMotion = reducedMotion,
			highlight = meter >= 0.99,
		}))
	end)()),
			},
			{
				id = "ops",
				height = opsH,
				element = React.createElement(Panel, {
		layoutOrder = 3,
		size = UDim2.fromScale(1, 1),
		accent = if opsClaims > 0 then Palette.green else Palette.cyan,
		background = Palette.panel,
		padding = if stack then chrome.cardPadding else 16,
		reveal = opsReveal,
		highlight = opsClaims > 0 and not effectsPaused,
		reducedMotion = quietMotion,
		clips = false,
	}, React.createElement(Text, {
		value = (opsGuide and opsGuide.OpsTitle) or "OPS PULSE",
		size = 10,
		color = if opsClaims > 0 then Palette.green else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = if opsClaims > 0 then `{opsClaims} ready to claim` else ((opsGuide and opsGuide.EmptyClaims) or "Nothing ready to claim — keep forging."),
		size = if stack then 17 else 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 24),
	}), React.createElement(Text, {
		value = (opsGuide and opsGuide.OpsBody) or "Claims waiting across Missions, Lab, Forge Path, and Anomaly.",
		size = if stack then chrome.labelText else 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 46),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, opsButtonH),
		Position = UDim2.new(0, 0, 1, -opsButtonH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalFlex = Enum.UIFlexAlignment.Fill,
		VerticalFlex = Enum.UIFlexAlignment.Fill,
		Wraps = stack,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = if missionsReady > 0 then `MISSIONS · {missionsReady}` else "MISSIONS",
		icon = "Mission",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Missions")
			end
			return _result
		end,
		color = if missionsReady > 0 then Palette.cyan else Palette.panelSoft,
		textColor = if missionsReady > 0 then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = missionsReady > 0,
		layoutOrder = 0,
	}), React.createElement(Button, {
		text = if labReady > 0 then `LAB · {labReady}` else "LAB",
		icon = "Lab",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Lab")
			end
			return _result
		end,
		color = if labReady > 0 then Palette.mint else Palette.panelSoft,
		textColor = if labReady > 0 then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = labReady > 0,
		layoutOrder = 1,
	}), React.createElement(Button, {
		text = if pathReady then "FORGE PATH · READY" else "FORGE PATH",
		icon = "Forge",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("ForgePath")
			end
			return _result
		end,
		color = if pathReady then Palette.violet else Palette.panelSoft,
		textColor = if pathReady then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = pathReady,
		layoutOrder = 2,
	}), React.createElement(Button, {
		text = if anomalyReady then "ANOMALY · READY" else "ANOMALY",
		icon = "Anomaly",
		onClick = function()
			local _result = navigate
			if _result ~= nil then
				_result = _result("Anomaly")
			end
			return _result
		end,
		color = if anomalyReady then Palette.pink else Palette.panelSoft,
		textColor = if anomalyReady then Palette.ink else Palette.creamSoft,
		size = if stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.25, -6, 0, TapTarget),
		reducedMotion = reducedMotion,
		highlight = anomalyReady,
		layoutOrder = 3,
	}))),
			},
			{
				id = "countdown",
				height = if countdownInPage then countdownH else 0,
				element = if countdownInPage then React.createElement(ReleaseCountdown, {
					releaseAt = releaseAt,
					reducedMotion = reducedMotion,
					stack = stack,
					layoutOrder = 6,
				}) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}),
			},
			{
				id = "rebirth",
				height = if rebirthVisible then rebirthH else 0,
				element = if rebirthVisible then React.createElement(RebirthPanel, {
					state = state,
					dispatch = dispatch,
					reducedMotion = reducedMotion,
					effectsPaused = effectsPaused,
					height = rebirthH,
					reveal = rebirthReveal,
					openWorkshop = openWorkshop,
					layoutOrder = 4,
				}) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}),
			},
			{
				id = "domain",
				height = if domainVisible then domainH else 0,
				element = if domainVisible then React.createElement(Panel, {
		layoutOrder = 5,
		size = UDim2.fromScale(1, 1),
		accent = Palette.pink,
		background = darken(Palette.violet, 0.9),
		padding = if stack then chrome.cardPadding else 18,
		reveal = domainReveal,
		highlight = domain.CanExpand and not effectsPaused,
		reducedMotion = quietMotion,
		clips = false,
	}, React.createElement("uigradient", {
		Color = surfaceGradient(Palette.violet, 0.88),
		Rotation = 62,
	}), React.createElement(IconTile, {
		kind = "World",
		accent = if domain.CanExpand then Palette.pink else Palette.violet,
		size = if phone then 54 else 62,
		radius = 16,
		position = UDim2.fromOffset(0, if phone then 4 else 18),
		glow = domain.CanExpand and not effectsPaused,
		spin = domain.CanExpand and not effectsPaused,
		reducedMotion = quietMotion,
	}), React.createElement("frame", {
		Size = if phone then UDim2.new(1, -68, 0, 132) else UDim2.new(1, -290, 1, 0),
		Position = UDim2.fromOffset(if phone then 66 else 80, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = `DOMAIN RANK {domain.Rank}`,
		size = 10,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = "Spend this run to rank Domain.",
		size = if phone then 20 else 23,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 34),
	}), React.createElement(Text, {
		value = "Costs rebirths and cores. This run's machines and worlds reset. Research, relics, and Stardust stay.",
		size = if phone then chrome.labelText else 11,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 60),
		sizeConstraint = UDim2.new(1, 0, 0, if phone then 58 else 44),
	}), not phone and React.createElement(Text, {
		value = `Permanent: {compactNumber(domain.ProductionMultiplier)}x production  /  {compactNumber(domain.CapacityMultiplier)}x vault time  /  +{math.floor(domain.OfflineBonus * 100 + 0.5)}% offline`,
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 112),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), if phone then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 186),
		Position = UDim2.new(0, 0, 1, -190),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Text, {
		value = `{compactNumber(state.Rebirths)} / {compactNumber(domain.RequiredRebirths)} rebirths`,
		size = chrome.labelText,
		color = if state.Rebirths >= domain.RequiredRebirths then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Cores)} / {compactNumber(domain.RequiredCores)} astral cores`,
		size = chrome.labelText,
		color = if state.Cores >= domain.RequiredCores then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = domainProgress,
		color = Palette.pink,
		reducedMotion = quietMotion,
		shimmer = domain.CanExpand and not effectsPaused,
		position = UDim2.fromOffset(0, 40),
		size = UDim2.new(1, 0, 0, 8),
	}), React.createElement(Text, {
		value = `Next: +{domain.EssenceReward} essence  ·  +{compactNumber(domain.StardustReward)} stardust`,
		size = chrome.labelText,
		color = Palette.mango,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Button, {
		text = if domain.CanExpand then "OPEN DOMAIN GATE" else "VIEW DOMAIN",
		icon = "Domain",
		onClick = openDomain,
		color = if domain.CanExpand then Palette.pink else Palette.panelSoft,
		textColor = if domain.CanExpand then Palette.ink else Palette.cream,
		outline = not domain.CanExpand,
		size = UDim2.new(1, 0, 0, ctaH),
		position = UDim2.new(0, 0, 1, -ctaH),
		reducedMotion = reducedMotion,
		highlight = domain.CanExpand,
	})) else React.createElement("frame", {
		Size = UDim2.fromOffset(270, 188),
		Position = UDim2.new(1, -270, 0, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement(Badge, {
		value = `{compactNumber(domain.Essence)} DOMAIN ESSENCE`,
		accent = Palette.pink,
		filled = true,
		position = UDim2.fromOffset(0, 0),
		size = UDim2.new(1, 0, 0, 26),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Rebirths)} / {compactNumber(domain.RequiredRebirths)} rebirths`,
		size = 10,
		color = if state.Rebirths >= domain.RequiredRebirths then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 34),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Cores)} / {compactNumber(domain.RequiredCores)} astral cores`,
		size = 10,
		color = if state.Cores >= domain.RequiredCores then Palette.green else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 52),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = domainProgress,
		color = Palette.pink,
		reducedMotion = quietMotion,
		shimmer = domain.CanExpand and not effectsPaused,
		position = UDim2.fromOffset(0, 74),
		size = UDim2.new(1, 0, 0, 8),
	}), React.createElement(Button, {
		text = if domain.CanExpand then "OPEN DOMAIN GATE" else "VIEW REQUIREMENTS",
		icon = "Domain",
		onClick = openDomain,
		color = if domain.CanExpand then Palette.pink else Palette.panelSoft,
		textColor = if domain.CanExpand then Palette.ink else Palette.cream,
		outline = not domain.CanExpand,
		size = UDim2.new(1, 0, 0, ctaH),
		position = UDim2.fromOffset(0, 96),
		reducedMotion = reducedMotion,
		highlight = domain.CanExpand,
	}))) else React.createElement("frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}),
			},
		},
	})))
end

local function MachineRow(_param)
	local machine = _param.machine
	local level = _param.level
	local cash = _param.cash
	local buyAmount = _param.buyAmount
	local reducedMotion = _param.reducedMotion
	local onBuy = _param.onBuy
	local y = _param.y
	local x = _param.x
	local width = _param.width
	local unlocked = _param.unlocked
	local lockReason = _param.lockReason
	local antilag = useAntilag()
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local rowH = PageBoardHeights.Machine(stack)
	local price = bulkCost(machine.BaseCost, machine.CostScale, level, buyAmount, machine.MaxLevel, cash)
	local maxed = level >= machine.MaxLevel
	local ready = unlocked and gteFlux(cash, price) and not maxed
	local accent = machine.Accent or machine.Color
	local running = level > 0
	local flow = useClock(running and not reducedMotion and antilag.allowAmbient and antilag.tier >= 2, 0.55, 1)
	local buyLabel = if not unlocked then "LOCKED" elseif maxed then "MAXED" elseif ready then "BUY" else `NEED  {compactNumber(price)}`
	local _condition = machine.BaseProduction
	if _condition == nil then
		_condition = 0
	end
	local hasOutput = _condition > 0
	local _result
	if not unlocked then
		_result = lockReason
	else
		local _result_1
		if hasOutput then
			local _condition_1 = machine.BaseProduction
			if _condition_1 == nil then
				_condition_1 = 0
			end
			_result_1 = `{compactNumber(_condition_1)} flux / sec base · Lv {compactNumber(level)}`
		else
			_result_1 = if maxed then `Level {compactNumber(level)} · maxed` else `Level {compactNumber(level)} · next {compactNumber(price)}`
		end
		_result = _result_1
	end
	local rateLine = _result
	-- Non-stack cards used to reserve a fixed 210px for the text block and float a fixed
	-- 150px-wide button 158px from the right edge, sized for a full-width single-column row.
	-- A multi-column grid (this same component, used at 1/2 or 1/3 the row width once the
	-- viewport is wide enough) squeezes the card well under that fixed budget, so the text
	-- block and button no longer fit side by side and started overlapping. Below this width
	-- threshold, stack the button under the text instead of beside it, the same pattern the
	-- stack layout already uses correctly, rather than assuming there's always ≥360px to work
	-- with.
	local cardWidth = if width ~= nil then width.X.Offset + (width.X.Scale * viewport.width) else viewport.width
	local buttonBesideText = not stack and cardWidth >= 360
	local absolute = y ~= nil or x ~= nil
	local layoutY = if y == nil then 0 else y
	return React.createElement("frame", {
		Size = if absolute then (width or UDim2.new(1, 0, 0, rowH)) else UDim2.fromScale(1, 1),
		Position = if x ~= nil then UDim2.new(x.X.Scale, x.X.Offset, 0, layoutY) else UDim2.fromOffset(0, layoutY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panel,
		padding = if stack then chrome.cardPadding else 14,
		interactive = true,
		reducedMotion = true,
	}, React.createElement(IconTile, {
		kind = if unlocked then ((machine.Icon) or "Forge") else "Lock",
		accent = if unlocked then machine.Color else Palette.muted,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 6 else 16),
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = if buttonBesideText then UDim2.new(1, -210, 1, -4) elseif stack then UDim2.new(1, -60, 0, 78) else UDim2.new(1, -60, 0, 78),
		Position = UDim2.fromOffset(58, if stack or not buttonBesideText then 2 else 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = machine.Name,
		size = if stack then 17 else 16,
		color = if unlocked then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		sizeConstraint = UDim2.new(1, -4, 0, 22),
	}), React.createElement(Text, {
		value = if unlocked then machine.Description else lockReason,
		size = if stack then chrome.labelText else 11,
		color = if unlocked then Palette.muted else machine.Color,
		weight = if unlocked then Enum.FontWeight.Regular else Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, -4, 0, if stack then 42 else 34),
	}), unlocked and React.createElement(Text, {
		value = rateLine,
		size = if stack then chrome.labelText else 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 72 else 64),
		sizeConstraint = UDim2.new(1, -4, 0, 16),
	}), running and buttonBesideText and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.fromOffset(0, 84),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.new(0.28, 0, 1, 0),
		Position = flow:map(function(phase)
			return UDim2.new(phase * 1.4 - 0.32, 0, 0, 0)
		end),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }),
	})))), if not ready and unlocked and not maxed then React.createElement(Button, {
		text = buyLabel,
		icon = "Flux",
		onClick = onBuy,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		size = if buttonBesideText then UDim2.fromOffset(150, TapTarget) else UDim2.new(1, 0, 0, TapTarget),
		position = if buttonBesideText then UDim2.new(1, -158, 0.5, -TapTarget / 2) else UDim2.new(0, 0, 1, -(TapTarget + 4)),
		reducedMotion = reducedMotion,
		disabled = true,
		highlight = false,
	}) else React.createElement(Button, {
		text = buyLabel,
		icon = if unlocked then "Flux" else "Lock",
		onClick = onBuy,
		color = if ready then machine.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = if buttonBesideText then UDim2.fromOffset(150, TapTarget) else UDim2.new(1, 0, 0, TapTarget),
		position = if buttonBesideText then UDim2.new(1, -158, 0.5, -TapTarget / 2) else UDim2.new(0, 0, 1, -(TapTarget + 4)),
		reducedMotion = reducedMotion,
		disabled = not ready,
		highlight = ready,
	})))
end
local SORT_OPTIONS = { {
	id = "Default",
	label = "Tier order",
}, {
	id = "Cheapest",
	label = "Cheapest first",
}, {
	id = "Output",
	label = "Highest output",
}, {
	id = "Level",
	label = "Highest level",
} }
local function UpgradeBoard(_param)
	local title = _param.title
	local eyebrow = _param.eyebrow
	local blurb = _param.blurb
	local accent = _param.accent
	local entries = _param.entries
	local state = _param.state
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local onBuy = _param.onBuy
	local onBuyAll = _param.onBuyAll
	local featurePanel = _param.featurePanel
	local featurePanelHeight = _param.featurePanelHeight
	if featurePanelHeight == nil then
		featurePanelHeight = 0
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — VirtualGrid overscan must drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local query, setQuery = React.useState("")
	local sort, setSort = React.useState("Default")
	local filter, setFilter = React.useState("All")
	local headerReveal = useStagger(0, softMotion)
	local cash = state.Cash
	local canBuy = function(entry)
		return entry.unlocked and not entry.maxed and gteFlux(cash, entry.price)
	end
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback = function(total, entry)
		return total + (if canBuy(entry) then 1 else 0)
	end
	for _i = 1, #entries do
		_result = _callback(_result, entries[_i], _i - 1, entries)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local affordableCount = _result
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_1 = function(total, entry)
		return total + (if entry.level > 0 then 1 else 0)
	end
	for _i = 1, #entries do
		_result_1 = _callback_1(_result_1, entries[_i], _i - 1, entries)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local ownedCount = _result_1
	local near = AppHelpers:trimFarLockedUpgrades(entries)
	-- ▼ ReadonlyArray.reduce ▼
	local _result_2 = 0
	local _callback_2 = function(total, entry)
		return total + (if not entry.unlocked then 1 else 0)
	end
	for _i = 1, #near do
		_result_2 = _callback_2(_result_2, near[_i], _i - 1, near)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local nextCount = _result_2
	local filterOptions = { {
		id = "All",
		label = "Near unlocks",
		count = #near,
	}, {
		id = "Affordable",
		label = "Can afford",
		count = affordableCount,
	}, {
		id = "Owned",
		label = "Owned",
		count = ownedCount,
	}, {
		id = "Next",
		label = "Coming up",
		count = nextCount,
	} }
	local needle = string.lower(query)
	local pool = if needle ~= "" then entries else near
	local visible = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback_3 = function(entry)
		if filter == "Affordable" and not canBuy(entry) then
			return nil
		end
		if filter == "Owned" and entry.level <= 0 then
			return nil
		end
		if filter == "Next" and entry.unlocked then
			return nil
		end
		if needle ~= "" then
			local haystack = string.lower((entry.config.Name .. " " .. entry.config.Description))
			local found = string.find(haystack, needle, 1, true)
			if found == nil then
				return nil
			end
		end
		local _entry = entry
		table.insert(visible, _entry)
	end
	for _k, _v in pool do
		_callback_3(_v, _k - 1, pool)
	end
	-- ▲ ReadonlyArray.forEach ▲
	table.sort(visible, function(left, right)
		if sort == "Cheapest" then
			return compareFlux(left.price, right.price) < 0
		end
		if sort == "Output" then
			local _condition = right.config.BaseProduction
			if _condition == nil then
				_condition = 0
			end
			local _condition_1 = left.config.BaseProduction
			if _condition_1 == nil then
				_condition_1 = 0
			end
			return _condition < _condition_1
		end
		if sort == "Level" then
			return right.level < left.level
		end
		return left.order < right.order
	end)
	local stack = chrome.contentStack
	local touchLayout = chrome.mobile
	local searchW = 252
	local sortW = 176
	local filterW = 176
	local controlGap = 12
	local controlsWrap = not stack and viewport.width < 900
	-- Portrait: title + Buy All + search/filters. Landscape: Buy All only.
	-- Keep machines above the fold — every 20px of header is a lost buy CTA.
	local stackControlsY = if chrome.landscape then 40 else 56
	local headerHeight = if chrome.landscape and stack then 92 elseif stack then 168 else (if controlsWrap then 184 else 156)
	local rowH = PageBoardHeights.Machine(stack)
	local gap = if stack then chrome.panelGap else Layout.panelGap
	local columns = if stack then 1 elseif viewport.width >= 2200 then 4 elseif viewport.width >= 1400 then 3 elseif viewport.width >= 900 then 2 else 1
	local rowStride = rowH + gap
	local columnWidth = UDim2.new(1 / columns, -(gap * (columns - 1)) / columns, 0, rowH)
	local gridRows = math.ceil(math.max(1, #visible) / columns)
	-- Machines come first so buy CTAs stay above the fold; AutoForge sits below the grid.
	local machinesBlock = if #visible == 0 then 150 else (gridRows * rowH + math.max(0, gridRows - 1) * gap)
	-- Extra mobile scroll tail so the floating vault/tap cluster never covers the last Buy button.
	local machineScrollTail = if stack then scrollTail(stack, chrome.bottomSafe, if chrome.landscape then 52 else 80) else scrollTail(stack, chrome.bottomSafe, 28)
	local scrollRef = React.useRef()
	local controlH = TapTarget
	local desktopControlH = if touchLayout then TapTarget else 40
	local controlsY = if controlsWrap then 98 else 100
	local sortX = searchW + controlGap
	local filterX = sortX + sortW + controlGap
	local wrapRowY = controlsY + desktopControlH + 6
	local stackCompact = stack and chrome.landscape
	local stackSearchY = stackControlsY + controlH + 6
	local stackFilterY = stackControlsY + (controlH + 6) * 2
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = if stack then chrome.cardPadding else 14,
		reveal = headerReveal,
		zIndex = 30,
		clips = false,
	}, React.createElement(Text, {
		value = eyebrow,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 14 else 18),
	}), React.createElement(Text, {
		value = title,
		size = if stack then (if stackCompact then 18 else 20) else 24,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 14 else 16),
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 26 else 30),
	}), not stackCompact and React.createElement(Text, {
		value = blurb,
		size = if stack then chrome.labelText else 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, if stack then 42 else 46),
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 20 else 20),
	}), not stack and React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = compactNumber(state.Production) .. " / sec",
		size = 14,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.new(1, -236, 0, 2),
		sizeConstraint = UDim2.new(0, 228, 0, 18),
		align = Enum.TextXAlignment.Right,
	}), React.createElement(AmountToggle, {
		value = buyAmount,
		onChange = setBuyAmount,
		accent = accent,
		position = UDim2.new(1, -236, 0, 22),
		size = UDim2.fromOffset(228, desktopControlH),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if affordableCount > 0 then `BUY ALL  ·  {affordableCount}` else "BUY ALL",
		icon = "Flux",
		onClick = function()
			local _result_3 = onBuyAll
			if _result_3 ~= nil then
				_result_3 = _result_3()
			end
			return _result_3
		end,
		color = if affordableCount > 0 then accent else Palette.panelSoft,
		textColor = if affordableCount > 0 then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(228, 30),
		position = UDim2.new(1, -236, 0, 66),
		disabled = affordableCount <= 0 or onBuyAll == nil,
		reducedMotion = reducedMotion,
		highlight = affordableCount > 0,
	}), React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = accent,
		placeholder = "Search upgrades",
		position = UDim2.fromOffset(0, controlsY),
		size = UDim2.fromOffset(searchW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 31,
	}), if controlsWrap then React.createElement(React.Fragment, nil, React.createElement(Dropdown, {
		options = SORT_OPTIONS,
		value = sort,
		onChange = setSort,
		accent = accent,
		position = UDim2.fromOffset(0, wrapRowY),
		size = UDim2.fromOffset(sortW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 44,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = accent,
		position = UDim2.fromOffset(sortW + controlGap, wrapRowY),
		size = UDim2.fromOffset(filterW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 42,
	})) else React.createElement(React.Fragment, nil, React.createElement(Dropdown, {
		options = SORT_OPTIONS,
		value = sort,
		onChange = setSort,
		accent = accent,
		position = UDim2.fromOffset(sortX, controlsY),
		size = UDim2.fromOffset(sortW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 44,
	}), React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = accent,
		position = UDim2.fromOffset(filterX, controlsY),
		size = UDim2.fromOffset(filterW, desktopControlH),
		reducedMotion = reducedMotion,
		zIndex = 42,
	}))), stack and React.createElement(React.Fragment, nil, React.createElement(AmountToggle, {
		value = buyAmount,
		onChange = setBuyAmount,
		accent = accent,
		position = UDim2.new(0, 0, 0, stackControlsY),
		size = UDim2.new(0.62, -6, 0, controlH),
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = "BUY ALL",
		icon = "Flux",
		onClick = function()
			local _result_3 = onBuyAll
			if _result_3 ~= nil then
				_result_3 = _result_3()
			end
			return _result_3
		end,
		color = if affordableCount > 0 then accent else Palette.panelSoft,
		textColor = if affordableCount > 0 then Palette.ink else Palette.muted,
		size = UDim2.new(0.38, -6, 0, controlH),
		position = UDim2.new(0.62, 6, 0, stackControlsY),
		disabled = affordableCount <= 0 or onBuyAll == nil,
		reducedMotion = reducedMotion,
		highlight = affordableCount > 0,
	}), not stackCompact and React.createElement(SearchField, {
		value = query,
		onChange = setQuery,
		accent = accent,
		placeholder = "Search upgrades",
		position = UDim2.new(0, 0, 0, stackSearchY),
		size = UDim2.new(1, 0, 0, controlH),
		reducedMotion = reducedMotion,
		zIndex = 31,
	}), not stackCompact and React.createElement(Dropdown, {
		options = SORT_OPTIONS,
		value = sort,
		onChange = setSort,
		accent = accent,
		position = UDim2.new(0, 0, 0, stackFilterY),
		size = UDim2.new(0.5, -4, 0, controlH),
		reducedMotion = reducedMotion,
		zIndex = 44,
	}), not stackCompact and React.createElement(Dropdown, {
		options = filterOptions,
		value = filter,
		onChange = setFilter,
		accent = accent,
		position = UDim2.new(0.5, 4, 0, stackFilterY),
		size = UDim2.new(0.5, -4, 0, controlH),
		reducedMotion = reducedMotion,
		zIndex = 42,
	})))
	local machinesElement
	if #visible == 0 then
		machinesElement = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(EmptyState, {
		icon = "Forge",
		title = if needle ~= "" or filter ~= "All" then "Nothing matches" elseif filter == "Affordable" then "Can't afford anything yet" else "No upgrades to show",
		body = if needle ~= "" then "Clear the search to see the board again." elseif filter == "Affordable" then "Bank the vault, then come back for the next machine." elseif filter ~= "All" then "Switch the filter back to Near unlocks." else "Unlock the next machine to fill this board.",
		accent = accent,
		size = UDim2.fromScale(1, 1),
	}), filter == "Affordable" and affordableCount == 0 and React.createElement(Button, {
		text = "SHOW NEAR UNLOCKS",
		icon = "Forge",
		onClick = function()
			setFilter("All")
		end,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		reducedMotion = reducedMotion,
		highlight = true,
	}))
	else
		machinesElement = React.createElement(VirtualGrid, {
			scrollRef = scrollRef,
			count = #visible,
			columns = columns,
			cellHeight = rowH,
			gap = gap,
			overscanRows = if softMotion then 0 else (if stack then 2 else 3),
			itemKey = function(index)
				return visible[index + 1].config.Id
			end,
			renderItem = function(index)
				local entry = visible[index + 1]
				return React.createElement(MachineRow, {
					machine = entry.config,
					level = entry.level,
					cash = state.Cash,
					buyAmount = buyAmount,
					reducedMotion = reducedMotion,
					onBuy = function()
						return onBuy(entry.config.Id)
					end,
					width = columnWidth,
					unlocked = entry.unlocked,
					lockReason = entry.lockReason,
				})
			end,
		})
	end
	local sections = {
		{
			id = "header",
			height = headerHeight,
			element = headerPanel,
		},
		{
			id = "machines",
			height = machinesBlock,
			element = machinesElement,
		},
	}
	if featurePanel ~= nil then
		table.insert(sections, {
			id = "autoforge",
			height = featurePanelHeight,
			element = featurePanel,
		})
	end
	return React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = gap,
		tailPad = machineScrollTail,
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = sections,
	})
end

local AUTO_FORGE_RESERVES = { {
	id = "NONE",
	label = "No reserve",
}, {
	id = "SAFE",
	label = "Keep 25%",
}, {
	id = "HALF",
	label = "Keep 50%",
}, {
	id = "HIGH",
	label = "Keep 75%",
} }
local function AutoForgePanel(_param)
	local state = _param.state
	local machines = _param.machines
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local height = _param.height
	local viewport = useViewport()
	local stack = chromeFor(viewport).stack
	local _condition = state.AutoForge
	if _condition == nil then
		local _object = {
			Enabled = false,
		}
		local _left = "MachineId"
		local _result = machines[1]
		if _result ~= nil then
			_result = _result.Id
		end
		local _condition_1 = _result
		if _condition_1 == nil then
			_condition_1 = "StellarCore"
		end
		_object[_left] = _condition_1
		_object.Reserve = 0.25
		_object.Bought = 0
		_condition = _object
	end
	local queue = _condition
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(machine)
		return machine.Id == queue.MachineId
	end
	local _result
	for _i, _v in machines do
		if _callback(_v, _i - 1, machines) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition_1 = _result
	if _condition_1 == nil then
		_condition_1 = machines[1]
	end
	local target = _condition_1
	local machineOptions = (function()
		local options = {}
		local seen = {}
		local push = function(machine)
			local _id = machine.Id
			if seen[_id] ~= nil then
				return nil
			end
			local _id_1 = machine.Id
			seen[_id_1] = true
			local _arg0 = {
				id = machine.Id,
				label = machine.Name,
			}
			table.insert(options, _arg0)
		end
		-- ▼ ReadonlyArray.find ▼
		local _callback_1 = function(machine)
			return machine.Id == queue.MachineId
		end
		local _result_1
		for _i, _v in machines do
			if _callback_1(_v, _i - 1, machines) == true then
				_result_1 = _v
				break
			end
		end
		-- ▲ ReadonlyArray.find ▲
		local current = _result_1
		if current ~= nil then
			push(current)
		end
		do
			local index = #machines - 1
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					index -= 1
				else
					_shouldIncrement = true
				end
				if not (index >= 0 and #options < 24) then
					break
				end
				local machine = machines[index + 1]
				local _condition_2 = state.Machines[machine.Id]
				if _condition_2 == nil then
					_condition_2 = 0
				end
				if _condition_2 > 0 then
					push(machine)
				end
			end
		end
		for _, machine in machines do
			if #options >= 40 then
				break
			end
			local _exp = state.Zone
			local _condition_2 = machine.RequiredZone
			if _condition_2 == nil then
				_condition_2 = 1
			end
			if _exp < _condition_2 then
				continue
			end
			local _exp_1 = state.Rebirths
			local _condition_3 = machine.RequiredRebirths
			if _condition_3 == nil then
				_condition_3 = 0
			end
			if _exp_1 < _condition_3 then
				continue
			end
			local _condition_4 = machine.PreviousId ~= nil
			if _condition_4 then
				local _condition_5 = state.Machines[machine.PreviousId]
				if _condition_5 == nil then
					_condition_5 = 0
				end
				local _condition_6 = machine.PreviousLevel
				if _condition_6 == nil then
					_condition_6 = 1
				end
				_condition_4 = _condition_5 < _condition_6
			end
			if _condition_4 then
				continue
			end
			push(machine)
		end
		return options
	end)()
	local _result_1
	if target ~= nil then
		local _condition_2 = state.Machines[target.Id]
		if _condition_2 == nil then
			_condition_2 = 0
		end
		_result_1 = _condition_2
	else
		_result_1 = 0
	end
	local level = _result_1
	local nextCost = if target ~= nil and level < target.MaxLevel then bulkCost(target.BaseCost, target.CostScale, level, 1, target.MaxLevel) else 0
	local _condition_2 = target ~= nil
	if _condition_2 then
		local _exp = state.Zone
		local _condition_3 = target.RequiredZone
		if _condition_3 == nil then
			_condition_3 = 1
		end
		local _condition_4 = _exp < _condition_3
		if not _condition_4 then
			local _exp_1 = state.Rebirths
			local _condition_5 = target.RequiredRebirths
			if _condition_5 == nil then
				_condition_5 = 0
			end
			_condition_4 = _exp_1 < _condition_5
			if not _condition_4 then
				local _condition_6 = target.PreviousId ~= nil
				if _condition_6 then
					local _condition_7 = state.Machines[target.PreviousId]
					if _condition_7 == nil then
						_condition_7 = 0
					end
					local _condition_8 = target.PreviousLevel
					if _condition_8 == nil then
						_condition_8 = 1
					end
					_condition_6 = _condition_7 < _condition_8
				end
				_condition_4 = _condition_6
			end
		end
		_condition_2 = _condition_4
	end
	local targetLocked = _condition_2
	local waiting = not targetLocked and target ~= nil and level < target.MaxLevel and not gteFlux(state.Cash, nextCost)
	local status = if not queue.Enabled then "PAUSED" elseif target == nil or level >= target.MaxLevel then "TARGET COMPLETE" elseif targetLocked then "WAITING FOR UNLOCK" elseif waiting then `WAITING FOR {compactNumber(nextCost)} FLUX` else "NEXT LEVEL QUEUED"
	local _result_2
	if not queue.Enabled then
		_result_2 = "PAUSED"
	else
		local _result_3
		if targetLocked then
			_result_3 = "LOCKED"
		else
			local _result_4
			if waiting then
				_result_4 = "WAITING"
			else
				local _condition_3 = target == nil
				if not _condition_3 then
					local _condition_4 = target.MaxLevel
					if _condition_4 == nil then
						_condition_4 = 0
					end
					_condition_3 = level >= _condition_4
				end
				_result_4 = if _condition_3 then "DONE" else "LIVE"
			end
			_result_3 = _result_4
		end
		_result_2 = _result_3
	end
	local badgeStatus = _result_2
	local apply = function(enabled, machineId, reserve)
		if machineId == nil then
			machineId = queue.MachineId
		end
		if reserve == nil then
			reserve = queue.Reserve
		end
		return dispatch("SetAutoForge", {
			Enabled = enabled,
			MachineId = machineId,
			Reserve = reserve,
		})
	end
	local controlY = if stack then 124 else 102
	local machineW = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(270, 42)
	local reserveW = if stack then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.fromOffset(174, 42)
	local buttonW = if stack then UDim2.new(0.5, -5, 0, TapTarget) else UDim2.fromOffset(158, 42)
	local _exp = React.createElement(IconTile, {
		kind = "Forge",
		accent = if queue.Enabled then Palette.mango else Palette.muted,
		size = 48,
		radius = 12,
		position = UDim2.fromOffset(0, 0),
		spin = queue.Enabled,
		reducedMotion = reducedMotion,
	})
	local _exp_1 = React.createElement(Text, {
		value = "AUTO-FORGE",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(62, 0),
		sizeConstraint = UDim2.new(1, if stack then -168 else -220, 0, 16),
	})
	local _exp_2 = React.createElement(Text, {
		value = "Your production queue",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(62, 16),
		sizeConstraint = UDim2.new(1, if stack then -168 else -220, 0, 24),
	})
	local _exp_3 = React.createElement(Text, {
		value = if stack then "Buys one level at a time and never spends your reserve." else "Pick a machine. Auto-Forge buys one affordable level at a time and leaves your saved flux alone.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(62, 42),
		sizeConstraint = UDim2.new(1, if stack then -168 else -70, 0, if stack then 36 else 28),
	})
	local _exp_4 = React.createElement(Badge, {
		value = if stack then badgeStatus else status,
		accent = if queue.Enabled then Palette.mint else Palette.muted,
		position = if stack then UDim2.new(1, -92, 0, 0) else UDim2.new(1, -210, 0, 4),
		size = if stack then UDim2.fromOffset(88, 24) else UDim2.fromOffset(200, 22),
	})
	local _exp_5 = not stack and React.createElement(Text, {
		value = `{compactNumber(queue.Bought)} AUTO LEVELS`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -210, 0, 30),
		sizeConstraint = UDim2.new(0, 210, 0, 16),
	})
	local _attributes = {
		options = machineOptions,
	}
	local _result_3 = target
	if _result_3 ~= nil then
		_result_3 = _result_3.Id
	end
	local _condition_3 = _result_3
	if _condition_3 == nil then
		local _result_4 = machineOptions[1]
		if _result_4 ~= nil then
			_result_4 = _result_4.id
		end
		_condition_3 = _result_4
		if _condition_3 == nil then
			_condition_3 = "StellarCore"
		end
	end
	_attributes.value = _condition_3
	_attributes.onChange = function(id)
		return apply(queue.Enabled, id, queue.Reserve)
	end
	_attributes.accent = Palette.mango
	_attributes.label = "TARGET MACHINE"
	_attributes.position = UDim2.fromOffset(0, controlY)
	_attributes.size = machineW
	_attributes.reducedMotion = reducedMotion
	_attributes.zIndex = 54
	return React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, height),
		accent = Palette.mango,
		background = darken(Palette.mango, 0.9),
		padding = 14,
		layoutOrder = 1,
		reducedMotion = reducedMotion,
		zIndex = 24,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, React.createElement(Dropdown, _attributes), React.createElement(Dropdown, {
		options = AUTO_FORGE_RESERVES,
		value = AppHelpers:reserveId(queue.Reserve),
		onChange = function(id)
			return apply(queue.Enabled, queue.MachineId, AppHelpers:reserveValue(id))
		end,
		accent = Palette.cyan,
		label = "FLUX RESERVE",
		position = if stack then UDim2.fromOffset(0, controlY + TapTarget + 26) else UDim2.fromOffset(282, controlY),
		size = reserveW,
		reducedMotion = reducedMotion,
		zIndex = 52,
	}), React.createElement("frame", {
		Size = buttonW,
		Position = if stack then UDim2.new(0.5, 5, 0, controlY + TapTarget + 26) else UDim2.fromOffset(468, controlY),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 26,
	}, React.createElement(Button, {
		text = if queue.Enabled then "PAUSE QUEUE" else "START QUEUE",
		icon = if queue.Enabled then "Pause" else "Play",
		onClick = function()
			return apply(not queue.Enabled)
		end,
		color = if queue.Enabled then Palette.panelSoft else Palette.mango,
		textColor = if queue.Enabled then Palette.cream else Palette.ink,
		outline = queue.Enabled,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = not queue.Enabled,
		zIndex = 27,
	})))
end
local function WorkshopView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local entries = React.useMemo(function()
		return AppHelpers:buildUpgradeEntries(config.Machines, state.Machines, state)
	end, { config.Machines, state.Machines, state.Zone, state.Rebirths })
	local featureHeight = if chromeFor(viewport).landscape then 128 elseif chromeFor(viewport).stack then 188 else 168
	return React.createElement(UpgradeBoard, {
		title = "More hands. Less waiting.",
		eyebrow = "BUILD QUEUE",
		blurb = "More machines = more flux, even while you're AFK.",
		accent = Palette.coral,
		entries = entries,
		state = state,
		buyAmount = buyAmount,
		setBuyAmount = setBuyAmount,
		reducedMotion = reducedMotion,
		onBuy = function(id)
			return dispatch("BuyMachine", {
				Id = id,
				Amount = amountPayload(buyAmount),
			})
		end,
		onBuyAll = function()
			-- ▼ ReadonlyArray.forEach ▼
			local _callback = function(entry)
				if entry.unlocked and not entry.maxed and gteFlux(state.Cash, entry.price) then
					dispatch("BuyMachine", {
						Id = entry.config.Id,
						Amount = "Max",
					})
				end
			end
			for _k, _v in entries do
				_callback(_v, _k - 1, entries)
			end
			-- ▲ ReadonlyArray.forEach ▲
		end,
		featurePanelHeight = featureHeight,
		featurePanel = React.createElement(AutoForgePanel, {
			state = state,
			machines = config.Machines,
			dispatch = dispatch,
			reducedMotion = reducedMotion,
			height = featureHeight,
		}),
	})
end
local function WorldRow(_param)
	local zone = _param.zone
	local current = _param.current
	local unlocked = _param.unlocked
	local canUnlock = _param.canUnlock
	local onSelect = _param.onSelect
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local cashOk = _param.cashOk
	local coresOk = _param.coresOk
	local rebirthOk = _param.rebirthOk
	local antilag = useAntilag()
	local skipMotion = reducedMotion or layoutOrder > 4 or antilag.skipEntrance or not antilag.allowAmbient
	local reveal = useStagger(math.min(layoutOrder, 4), skipMotion, 0.02, 0.14)
	local _condition = zone.Features[1]
	if _condition == nil then
		_condition = zone.Description
	end
	local feature = _condition
	local actionable = current or unlocked or canUnlock
	local costBits = {}
	if not unlocked and not current then
		if zone.RequiredRebirths > 0 then
			local _arg0 = `{zone.RequiredRebirths} rebirth{if zone.RequiredRebirths == 1 then "" else "s"}`
			table.insert(costBits, _arg0)
		end
		if zone.CoreCost > 0 then
			local _arg0 = `{compactNumber(zone.CoreCost)} cores`
			table.insert(costBits, _arg0)
		end
		if gteFlux(zone.Cost, 0.01) then
			local _arg0 = `{compactNumber(zone.Cost)} flux`
			table.insert(costBits, _arg0)
		end
	end
	local costLine = if #costBits > 0 then table.concat(costBits, " · ") else nil
	local missing = if not unlocked and not current then (if not rebirthOk then `{zone.RequiredRebirths} rebirths` elseif not coresOk then `{compactNumber(zone.CoreCost)} cores` elseif not cashOk then `{compactNumber(zone.Cost)} flux` else nil) else nil
	local cta = if current then "CURRENT" elseif unlocked then "ENTER" elseif canUnlock then "UNLOCK" elseif missing ~= nil then string.upper(missing) else "LOCKED"
	local btnColor = if current then Palette.green elseif unlocked then Palette.green elseif canUnlock then Palette.mango else Palette.panelSoft
	local btnText = if (current or unlocked or canUnlock) then Palette.ink else Palette.muted
	local rowH = PageBoardHeights.World(stack)
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, rowH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = zone.Color,
		background = if current then zone.DarkColor:Lerp(Palette.panelRaised, 0.45) else Palette.panel,
		padding = if stack then 16 else 18,
		reveal = reveal,
		interactive = not current,
		highlight = current,
		reducedMotion = skipMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = "World",
		accent = zone.Color,
		size = if stack then 48 else 56,
		radius = 14,
		position = UDim2.fromOffset(0, if stack then 12 else 30),
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement("frame", {
		Size = if stack then UDim2.new(1, -64, 0, 126) else UDim2.new(1, -200, 1, -6),
		Position = UDim2.fromOffset(if stack then 60 else 72, if stack then 4 else 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = zone.Name,
		size = if stack then 18 else 19,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 26),
	}), React.createElement(Text, {
		value = zone.Tagline,
		size = if stack then 13 else 11,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 30),
		sizeConstraint = UDim2.new(1, 0, 0, 20),
	}), React.createElement(Text, {
		value = `{feature}  ·  {AppHelpers:formatWorldMultiplier(zone.Multiplier)}x`,
		size = if stack then 13 else 11,
		color = zone.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 56),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}), costLine ~= nil and React.createElement(Text, {
		value = if canUnlock then `Cost {costLine}` else `Needs {costLine}`,
		size = 10,
		color = if canUnlock then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 78),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), current and React.createElement(Badge, {
		value = "CURRENT WORLD",
		accent = zone.Color,
		filled = true,
		position = UDim2.fromOffset(0, if costLine ~= nil then 98 else 84),
		size = UDim2.fromOffset(136, 26),
	})), React.createElement(Button, {
		text = cta,
		icon = "World",
		onClick = onSelect,
		color = btnColor,
		textColor = btnText,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, TapTarget),
		position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -166, 0.5, -TapTarget / 2),
		reducedMotion = reducedMotion,
		disabled = not actionable or current,
		highlight = actionable and not current,
		zIndex = 12,
	})))
end
local function WorldsView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local quietMotion = reducedMotion or antilag.skipEntrance or not antilag.allowAmbient
	local headerReveal = useStagger(0, quietMotion)
	local headerHeight = if stack then 168 else 112
	local rowHeight = PageBoardHeights.World(stack)
	local rowGap = if stack then chrome.panelGap else Layout.panelGap
	local worldColumns = if stack then 1 elseif viewport.width >= 1700 then 3 elseif viewport.width >= 1100 then 2 else 1
	local listPad = Layout.stackGap * 2
	local _condition = config.MaxZone
	if _condition == nil then
		_condition = #config.Zones
	end
	local catalogTotal = _condition
	local total = if catalogTotal > 0 then math.clamp(state.Zone + 2, 1, catalogTotal) else 0
	local currentIdx = math.clamp(state.CurrentZone - 1, 0, math.max(0, total - 1))
	local range, setRange = React.useState(function()
		return AppHelpers:worldWindowAround(currentIdx, total)
	end)
	local scrollRef = React.useRef()
	React.useEffect(function()
		setRange(function(prev)
			local stop = prev.start + prev.count
			if currentIdx >= prev.start and currentIdx < stop then
				return prev
			end
			return AppHelpers:worldWindowAround(currentIdx, total, AppHelpers.worldWindow.chunk)
		end)
	end, { currentIdx, total })
	local rangeEnd = math.min(total, range.start + range.count)
	local shownCount = math.max(0, rangeEnd - range.start)
	local remainingBelow = math.max(0, total - rangeEnd)
	local remainingAbove = range.start
	local canShowMore = remainingBelow > 0 or remainingAbove > 0
	local showMore = function()
		setRange(function(prev)
			local stop = math.min(total, prev.start + prev.count)
			if stop < total then
				if prev.count >= AppHelpers.worldWindow.maxMounted then
					local nextStart = math.min(math.max(0, total - AppHelpers.worldWindow.maxMounted), prev.start + AppHelpers.worldWindow.chunk)
					return {
						start = nextStart,
						count = math.min(AppHelpers.worldWindow.maxMounted, total - nextStart),
					}
				end
				return {
					start = prev.start,
					count = math.min(AppHelpers.worldWindow.maxMounted, total - prev.start, prev.count + AppHelpers.worldWindow.chunk),
				}
			end
			if prev.start > 0 then
				if prev.count >= AppHelpers.worldWindow.maxMounted then
					local nextStart = math.max(0, prev.start - AppHelpers.worldWindow.chunk)
					return {
						start = nextStart,
						count = math.min(AppHelpers.worldWindow.maxMounted, total - nextStart),
					}
				end
				local grow = math.min(AppHelpers.worldWindow.chunk, prev.start, AppHelpers.worldWindow.maxMounted - prev.count)
				return {
					start = prev.start - grow,
					count = prev.count + grow,
				}
			end
			return prev
		end)
	end
	local jumpToCurrent = function()
		local focused = AppHelpers:worldWindowAround(currentIdx, total, AppHelpers.worldWindow.chunk)
		setRange(focused)
		task.defer(function()
			local scrolling = scrollRef.current
			if not scrolling then
				return nil
			end
			local localIndex = math.clamp(currentIdx - focused.start, 0, math.max(0, focused.count - 1))
			scrolling.CanvasPosition = Vector2.new(0, math.max(0, headerHeight + rowGap + localIndex * (rowHeight + rowGap) - 40))
		end)
	end
	local moreLabel = if remainingBelow > 0 then `SHOW MORE  ({remainingBelow} left)` elseif remainingAbove > 0 then `SHOW EARLIER  ({remainingAbove})` else "SHOW MORE"
	local gridRows = math.ceil(math.max(1, shownCount) / worldColumns)
	local rowsHeight = math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap)
	local worldTail = scrollTail(stack, chrome.bottomSafe, 40)
	local rows = {}
	do
		local index = range.start
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index < rangeEnd) then
				break
			end
			local zone = if config.ResolveZone ~= nil then config.ResolveZone(index + 1) else config.Zones[index + 1]
			if zone == nil then
				continue
			end
			local unlocked = state.Zone >= zone.Id
			local rebirthOk = state.Rebirths >= zone.RequiredRebirths
			local coresOk = state.Cores >= zone.CoreCost
			local cashOk = gteFlux(state.Cash, zone.Cost)
			local canUnlock = not unlocked and zone.Id == state.Zone + 1 and rebirthOk and coresOk and cashOk
			local localOrder = index - range.start + 1
			local _arg0 = React.createElement(WorldRow, {
				key = zone.Id,
				zone = zone,
				current = state.CurrentZone == zone.Id,
				unlocked = unlocked,
				canUnlock = canUnlock,
				cashOk = cashOk,
				coresOk = coresOk,
				rebirthOk = rebirthOk,
				reducedMotion = reducedMotion,
				onSelect = function()
					return dispatch(if unlocked then "SelectZone" else "UnlockZone", {
						Id = zone.Id,
					})
				end,
				layoutOrder = localOrder,
				stack = stack,
			})
			table.insert(rows, _arg0)
		end
	end
	local rowsBlock = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, (if worldColumns > 1 then React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / worldColumns, -math.floor(rowGap * (worldColumns - 1) / worldColumns), 0, rowHeight),
		CellPadding = UDim2.fromOffset(rowGap, rowGap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = worldColumns,
	}) else React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, rowGap),
	})), rows)
	local sections = {
		{
			id = "header",
			height = headerHeight,
			element = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = if stack then 16 else 14,
		reveal = headerReveal,
		layoutOrder = 0,
		clips = false,
	}, React.createElement(Text, {
		value = "SCENE SELECT",
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 18),
	}), React.createElement(Text, {
		value = "Pick a world.",
		size = if stack then chrome.titleText else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 30),
	}), React.createElement(Text, {
		value = "Travel to ones you own, or unlock the next stop.",
		size = if stack then chrome.labelText else 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 56),
		sizeConstraint = UDim2.new(1, if stack then -8 else -320, 0, 36),
	}), not stack and React.createElement("frame", {
		Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Badge, {
		value = `{state.Zone} / {catalogTotal}`,
		accent = Palette.mint,
		size = UDim2.fromOffset(118, 28),
	}), React.createElement(Button, {
		text = "FIND CURRENT",
		icon = "Search",
		onClick = jumpToCurrent,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, 42),
		hug = true,
		reducedMotion = reducedMotion,
	})), stack and React.createElement(Button, {
		text = "FIND CURRENT",
		icon = "Search",
		onClick = jumpToCurrent,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8)),
		reducedMotion = reducedMotion,
	})),
		},
		{
			id = "rows",
			height = rowsHeight,
			element = rowsBlock,
		},
	}
	if canShowMore then
		table.insert(sections, {
			id = "more",
			height = TapTarget + 8,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement(Button, {
				text = moreLabel,
				icon = "Chevron",
				onClick = showMore,
				color = Palette.panelSoft,
				textColor = Palette.cream,
				size = UDim2.new(1, 0, 0, TapTarget),
				reducedMotion = reducedMotion,
				outline = true,
			})),
		})
	end
	return React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = rowGap,
		tailPad = worldTail + listPad,
		scrollBarColor = Palette.mint,
		scrollBarThickness = 4,
		sections = sections,
	})
end
local function RewardChargeRail(_param)
	local value = _param.value
	local accent = _param.accent
	local ready = _param.ready
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local size = _param.size
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local progress = useFlipperSpring(math.clamp(value, 0, 1), softMotion, 420, 32)
	local emphasis = useFlipperSpring(if ready then 1 else 0, softMotion, 460, 32)
	local fillSize = progress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 1, 0)
	end)
	local markerPosition = progress:map(function(amount)
		return UDim2.new(math.clamp(amount, 0, 1), 0, 0.5, 0)
	end)
	local markerScale = emphasis:map(function(amount)
		return 0.78 + math.clamp(amount, 0, 1) * 0.22
	end)
	return React.createElement("frame", {
		Size = size,
		Position = position,
		BackgroundColor3 = Palette.panelSoft,
		BackgroundTransparency = 0.22,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = fillSize,
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(accent, 0.18), lighten(accent, 0.3)),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = markerPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = if ready then Palette.cream else accent,
		BackgroundTransparency = progress:map(function(amount)
			return if amount > 0.025 then 0 else 1
		end),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uiscale", {
		Scale = markerScale,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = emphasis:map(function(amount)
			return 0.68 - math.clamp(amount, 0, 1) * 0.46
		end),
	})))
end
local function TimedRewardQueue(_param)
	local entries = _param.entries
	local played = _param.played
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local pending = {}
	for _, entry in entries do
		if not entry.Claimed and #pending < 3 then
			table.insert(pending, entry)
		end
	end
	local reveal = useStagger(3, reducedMotion)
	local _exp = React.createElement(Text, {
		value = "COMING UP",
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})
	local _exp_1 = #pending == 0 and React.createElement(Text, {
		value = "Today's playtime drops are all collected.",
		size = 13,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, 27),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	})
	local _condition = #pending > 0
	if _condition then
		local _exp_2 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#pending)
		local _callback = function(entry, index)
			local ready = played >= entry.Seconds
			local accent = if ready then Palette.mint else Palette.cyan
			local _exp_3 = React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 8),
			})
			local _exp_4 = React.createElement("uistroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				LineJoinMode = Enum.LineJoinMode.Round,
				Color = accent,
				Thickness = 1,
				Transparency = if ready then 0.34 else 0.76,
			})
			local _exp_5 = React.createElement(Text, {
				value = if ready then "READY" else `IN {clockText(entry.Seconds - played)}`,
				size = 9,
				color = accent,
				weight = Enum.FontWeight.Heavy,
				fit = true,
				position = UDim2.fromOffset(10, 5),
				sizeConstraint = UDim2.new(1, -20, 0, 14),
			})
			local _attributes = {}
			local _condition_1 = formatReward(entry.Reward)
			if not (_condition_1 ~= "" and _condition_1) then
				_condition_1 = "Mystery parcel"
			end
			_attributes.value = _condition_1
			_attributes.size = 10
			_attributes.color = Palette.creamSoft
			_attributes.weight = Enum.FontWeight.Bold
			_attributes.fit = true
			_attributes.position = UDim2.fromOffset(10, 23)
			_attributes.sizeConstraint = UDim2.new(1, -20, 0, 20)
			return React.createElement("frame", {
				key = entry.Index,
				Size = UDim2.new(0.333, -6, 1, 0),
				LayoutOrder = index,
				BackgroundColor3 = if ready then Palette.panelRaised else Palette.panelSoft,
				BorderSizePixel = 0,
			}, _exp_3, _exp_4, _exp_5, React.createElement(Text, _attributes), React.createElement(RewardChargeRail, {
				value = played / math.max(1, entry.Seconds),
				accent = accent,
				ready = ready,
				reducedMotion = reducedMotion,
				position = UDim2.new(0, 8, 1, -4),
				size = UDim2.new(1, -16, 0, 3),
			}))
		end
		for _k, _v in pending do
			_newValue[_k] = _callback(_v, _k - 1, pending)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 52),
			Position = UDim2.fromOffset(0, 24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, _exp_2, _newValue)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, 104),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 14,
		layoutOrder = layoutOrder,
		reveal = reveal,
	}, _exp, _exp_1, _condition)
end
local function RewardsView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local dailyReady = state.Daily.CanClaim == true
	local timedEntries = state.TimedRewards.Rewards or {}
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		return not entry.Claimed
	end
	local _result
	for _i, _v in timedEntries do
		if _callback(_v, _i - 1, timedEntries) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local nextTimed = _result
	local _condition = state.TimedRewards.PlaySeconds
	if _condition == nil then
		_condition = 0
	end
	local played = _condition
	local timedReady = nextTimed ~= nil and played >= nextTimed.Seconds
	local timedProgress = if nextTimed ~= nil then math.clamp(played / math.max(1, nextTimed.Seconds), 0, 1) else 1
	local dailyReward = state.Daily.Rewards[state.Daily.RewardIndex]
	local headerReveal = useStagger(0, softMotion)
	local dailyReveal = useStagger(1, softMotion)
	local timedReveal = useStagger(2, softMotion)
	local rewardCardH = if stack then 172 else 110
	local rewardsTail = scrollTail(stack, chrome.bottomSafe, 48)
	local rewardsClaimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on Daily Claim or Timed CLAIM (FocusClaim prefers Claim-named hosts).
	local rewardsClaimReady = dailyReady or timedReady
	React.useEffect(function()
		if not rewardsClaimReady or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = rewardsClaimHostRef.current
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
	end, { dailyReady, timedReady, rewardsClaimReady })
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.pink,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = 0,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(Text, {
		value = "REWARDS",
		size = 10,
		color = Palette.pink,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, -120, 0, 14),
	}), React.createElement(Text, {
		value = "Dailies and playtime drops. Boosts moved to their own page.",
		size = 20,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 18),
		sizeConstraint = UDim2.new(1, -16, 0, 28),
	}))
	local _exp_3 = React.createElement(IconTile, {
		kind = "Calendar",
		accent = if dailyReady then Palette.mint else Palette.panelSoft,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = dailyReady,
		reducedMotion = softMotion,
	})
	local _exp_4 = React.createElement(Text, {
		value = "Daily parcel",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 23),
	})
	local _attributes = {}
	local _condition_1 = formatReward(dailyReward)
	if not (_condition_1 ~= "" and _condition_1) then
		_condition_1 = (if dailyReady then "Ready to open" else "Already collected today")
	end
	_attributes.value = _condition_1
	_attributes.size = 11
	_attributes.color = Palette.muted
	_attributes.wrap = true
	_attributes.position = UDim2.fromOffset(60, 32)
	_attributes.sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 20)
	local dailyPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 1,
		reveal = dailyReveal,
		highlight = dailyReady,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_3, _exp_4, React.createElement(Text, _attributes), React.createElement(Text, {
		value = "Streak " .. tostring(state.Daily.Streak) .. "  ·  next at " .. tostring(state.Daily.NextStreak),
		size = 10,
		color = Palette.mint,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(60, 56),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 16),
	}), React.createElement(RewardChargeRail, {
		value = 1,
		accent = if dailyReady then Palette.mint else Palette.lineSoft,
		ready = dailyReady,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(if stack then 0 else 60, if stack then 80 else 76),
		size = UDim2.new(1, if stack then 0 else -230, 0, 5),
	}), React.createElement("frame", {
		Name = "RewardsDailyClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, 44),
		Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -150, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = if dailyReady then rewardsClaimHostRef else nil,
	}, React.createElement(Button, {
		text = if dailyReady then "Claim" else "Claimed",
		icon = "Calendar",
		onClick = function()
			return dispatch("ClaimDaily")
		end,
		color = if dailyReady then Palette.mint else Palette.panelSoft,
		textColor = if dailyReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not dailyReady,
		highlight = dailyReady,
	})))
	local _exp_6 = React.createElement(IconTile, {
		kind = "Timer",
		accent = if timedReady then Palette.violet else Palette.panelSoft,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 18),
		glow = timedReady,
		reducedMotion = softMotion,
	})
	local _exp_7 = React.createElement(Text, {
		value = "Timed drop",
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(60, 6),
		sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 23),
	})
	local _attributes_1 = {}
	local _result_1
	if nextTimed ~= nil then
		local _condition_2 = formatReward(nextTimed.Reward)
		if not (_condition_2 ~= "" and _condition_2) then
			_condition_2 = (if timedReady then "Ready to collect" else clockText(played) .. " of " .. clockText(nextTimed.Seconds) .. " played")
		end
		_result_1 = _condition_2
	else
		_result_1 = "All caught up"
	end
	_attributes_1.value = _result_1
	_attributes_1.size = 10
	_attributes_1.color = Palette.muted
	_attributes_1.fit = true
	_attributes_1.position = UDim2.fromOffset(60, 32)
	_attributes_1.sizeConstraint = UDim2.new(1, if stack then -60 else -230, 0, 17)
	local timedPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.violet,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 2,
		reveal = timedReveal,
		highlight = timedReady,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_6, _exp_7, React.createElement(Text, _attributes_1), React.createElement(RewardChargeRail, {
		value = timedProgress,
		accent = if timedReady then Palette.violet else Palette.cyan,
		ready = timedReady,
		reducedMotion = softMotion,
		position = UDim2.fromOffset(if stack then 0 else 60, if stack then 76 else 58),
		size = UDim2.new(1, if stack then 0 else -230, 0, 6),
	}), React.createElement("frame", {
		Name = "RewardsTimedClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(150, 44),
		Position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -150, 0.5, -22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		-- Prefer Daily Claim when both ready; otherwise park on Timed CLAIM.
		ref = if timedReady and not dailyReady then rewardsClaimHostRef else nil,
	}, React.createElement(Button, {
		text = if timedReady then "CLAIM" else "CHARGING",
		icon = "Timer",
		onClick = function()
			if nextTimed ~= nil then
				dispatch("ClaimTimedReward", {
					Index = nextTimed.Index,
				})
			end
		end,
		color = if timedReady then Palette.violet else Palette.panelSoft,
		textColor = if timedReady then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		reducedMotion = softMotion,
		disabled = not timedReady,
		highlight = timedReady,
	})))
	local queuePanel =  React.createElement(TimedRewardQueue, {
		entries = timedEntries,
		played = played,
		reducedMotion = softMotion,
		layoutOrder = 3,
	})
	return React.createElement(PageScaffold, {
		gap = 12,
		tailPad = rewardsTail,
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = {
			{
				id = "header",
				height = 72,
				element = headerPanel,
			},
			{
				id = "daily",
				height = rewardCardH,
				element = dailyPanel,
			},
			{
				id = "timed",
				height = rewardCardH,
				element = timedPanel,
			},
			{
				id = "queue",
				height = 104,
				element = queuePanel,
			},
		},
	})
end
local function CrewRow(_param)
	local player = _param.player
	local visiting = _param.visiting
	local visitorsHere = _param.visitorsHere
	local onVisit = _param.onVisit
	local onNudge = _param.onNudge
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(math.min(layoutOrder, 8), reducedMotion)
	local accent = if player.IsLocal then Palette.green else Palette.blue
	local rowH = if stack then (if player.IsLocal then 118 else 158) else 100
	local pad = if stack then 14 else 12
	local _exp = React.createElement("frame", {
		Size = UDim2.fromOffset(if stack then 48 else 44, if stack then 48 else 44),
		Position = UDim2.fromOffset(0, if stack then 8 else 14),
		BackgroundColor3 = darken(accent, 0.62),
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.12), darken(accent, 0.48)),
		Rotation = 120,
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = accent,
		Thickness = 1,
		Transparency = 0.32,
	}), React.createElement(PlayerMark, {
		userId = player.UserId,
		color = Palette.ink,
		accent = accent,
		size = if stack then 42 else 38,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))
	local _exp_1 = React.createElement(Text, {
		value = if player.IsLocal then "YOU" else player.DisplayName,
		size = if stack then 17 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(58, 2),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -280, 0, 22),
	})
	local _exp_2 = React.createElement(Text, {
		value = `World {player.CurrentZone}`,
		size = if stack then 12 else 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(58, 28),
		sizeConstraint = UDim2.fromOffset(80, 16),
	})
	local _exp_3 = React.createElement(Text, {
		value = `{compactNumber(player.Production)} /s`,
		size = if stack then 12 else 10,
		color = Palette.muted,
		fit = false,
		position = UDim2.fromOffset(144, 28),
		sizeConstraint = UDim2.new(1, -160, 0, 16),
	})
	local _condition = not player.IsLocal
	if _condition then
		local _attributes = {}
		local _condition_1 = player.CurrentPage
		if _condition_1 == nil then
			_condition_1 = "Overview"
		end
		_attributes.value = `Browsing {AppHelpers:pageEntry(_condition_1).label}`
		_attributes.size = if stack then 11 else 9
		_attributes.color = if player.PresenceAge ~= nil and player.PresenceAge >= 0 and player.PresenceAge < 12 then Palette.mint else Palette.muted
		_attributes.weight = Enum.FontWeight.Bold
		_attributes.fit = true
		_attributes.minSize = 8
		_attributes.position = UDim2.fromOffset(58, if stack then 52 else 56)
		_attributes.sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -16, 0, 16)
		_condition = React.createElement(Text, _attributes)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, rowH),
		accent = accent,
		background = if visiting then Palette.panelRaised else Palette.panel,
		padding = pad,
		layoutOrder = layoutOrder,
		reveal = reveal,
		interactive = not player.IsLocal,
		highlight = visiting,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, _condition, if player.IsLocal then React.createElement(Text, {
		value = if visitorsHere > 0 then `{visitorsHere} visiting your shop` else `{player.Rebirths} resets`,
		size = if stack then 12 else 10,
		color = if visitorsHere > 0 then Palette.mango else accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(58, if stack then 52 else 56),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 16) else -16, 0, 18),
	}) elseif stack then React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, TapTarget),
		Position = UDim2.new(0, 0, 1, -(TapTarget + 2)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = "WAVE",
		icon = "Wave",
		onClick = onNudge,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(0.5, -4, 0, TapTarget),
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Button, {
		text = if visiting then "HERE" else "VISIT",
		icon = "Visit",
		onClick = onVisit,
		color = if visiting then Palette.green else Palette.blue,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		disabled = visiting,
		highlight = visiting,
	}))) else React.createElement("frame", {
		Size = UDim2.fromOffset(0, TapTarget),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}), React.createElement(Button, {
		text = "WAVE",
		icon = "Wave",
		onClick = onNudge,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
	}), React.createElement(Button, {
		text = if visiting then "HERE" else "VISIT",
		icon = "Visit",
		onClick = onVisit,
		color = if visiting then Palette.green else Palette.blue,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, TapTarget),
		hug = true,
		reducedMotion = reducedMotion,
		disabled = visiting,
		highlight = visiting,
	})))
end
local function VisitPanel(_param)
	local visit = _param.visit
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local stack = _param.stack
	local reveal = useStagger(0, reducedMotion)
	local vaultFill = meterFill(asFlux(visit.Vault), asFlux(visit.Capacity))
	local machineBits = {}
	for id, level in pairs(visit.Machines) do
		if #machineBits < 4 then
			local _arg0 = `{id} {level}`
			table.insert(machineBits, _arg0)
		end
	end
	local lineWord = if visit.MachineKinds == 1 then "line" else "lines"
	local machineLine = if #machineBits > 0 then `{visit.MachineKinds} {lineWord} · {machineBits[1]}{if machineBits[2] ~= nil then `  ·  {machineBits[2]}` else ""}{if machineBits[3] ~= nil then `  ·  {machineBits[3]}` else ""}` else "No machines built yet"
	local _exp = React.createElement(Text, {
		value = "VISITING",
		size = 10,
		color = Palette.blue,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 16),
	})
	local _exp_1 = React.createElement(Text, {
		value = visit.DisplayName,
		size = 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 30),
	})
	local _exp_2 = React.createElement(Text, {
		value = `World {visit.CurrentZone}  ·  {visit.Rebirths} resets  ·  live`,
		size = 11,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, if stack then 0 else -160, 0, 18),
	})
	local _exp_3 = React.createElement(Button, {
		text = "LEAVE",
		icon = "Close",
		onClick = function()
			return dispatch("LeavePlot")
		end,
		color = Palette.panelSoft,
		textColor = Palette.creamSoft,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(120, 40),
		position = if stack then UDim2.new(0, 0, 1, -(TapTarget + 4)) else UDim2.new(1, -120, 0, 12),
		reducedMotion = reducedMotion,
	})
	local _exp_4 = { {
		label = "FLUX / SEC",
		value = visit.Production,
		color = Palette.green,
	}, {
		label = "BALANCE",
		value = visit.Cash,
		color = Palette.cream,
	}, {
		label = "CORES",
		value = visit.Cores,
		color = Palette.violet,
	}, {
		label = "STARDUST",
		value = visit.Stardust,
		color = Palette.cyan,
	} }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_4)
	local _callback = function(stat, index)
		return React.createElement("frame", {
			key = stat.label,
			Size = if stack then UDim2.new(0.5, -4, 0, 72) else UDim2.new(0.25, -6, 1, 0),
			Position = if stack then UDim2.new(if index % 2 == 0 then 0 else 0.5, if index % 2 == 0 then 0 else 4, 0, if index < 2 then 0 else 80) else UDim2.new(index * 0.25, if index == 0 then 0 else 2, 0, 0),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement(Text, {
			value = stat.label,
			size = 9,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(10, 10),
			sizeConstraint = UDim2.new(1, -20, 0, 14),
		}), React.createElement(NumberSpinnerHost, {
			value = asFlux(stat.value),
			reducedMotion = reducedMotion,
			duration = 0.4,
			size = 16,
			color = stat.color,
			position = UDim2.fromOffset(10, 32),
			sizeConstraint = UDim2.new(1, -20, 0, 24),
		}))
	end
	for _k, _v in _exp_4 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_4)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, PageBoardHeights.Visit(stack)),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = 16,
		layoutOrder = layoutOrder,
		reveal = reveal,
		highlight = true,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, _exp_3, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 152 else 72),
		Position = UDim2.fromOffset(0, if stack then 76 else 86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue), React.createElement(Text, {
		value = `Vault {compactNumber(visit.Vault)} / {compactNumber(visit.Capacity)}`,
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 238 else 170),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = vaultFill,
		color = Palette.blue,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(0, if stack then 258 else 192),
		size = UDim2.new(1, 0, 0, 7),
	}), React.createElement(Text, {
		value = machineLine,
		size = 10,
		color = Palette.creamSoft,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, if stack then 274 else 210),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}))
end
local function sameCrewSnapshot(left, right)
	return PageReadyMath.SameCrewSnapshot(left, right)
end
local function CrewView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local visit = _param.visit
	local setVisit = _param.setVisit
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local players, setPlayers = React.useState({})
	local mountedRef = React.useRef(true)
	local visitAttemptRef = React.useRef(0)
	React.useEffect(function()
		return function()
			mountedRef.current = false
			visitAttemptRef.current += 1
		end
	end, {})
	local refresh = React.useCallback(function()
		return dispatch("GetPlayers", {}, function(response)
			if not mountedRef.current or not response.ok then
				return nil
			end
			local raw = response.Players or {}
			local cleaned = {}
			for _, entry in raw do
				local _userId = entry.UserId
				local id = if type(_userId) == "number" then math.floor(entry.UserId) else tonumber(tostring(entry.UserId))
				if id == nil or id ~= id or id == 0 then
					continue
				end
				local _object = table.clone(entry)
				setmetatable(_object, nil)
				_object.UserId = id
				table.insert(cleaned, _object)
			end
			setPlayers(function(current)
				return if sameCrewSnapshot(current, cleaned) then current else cleaned
			end)
		end)
	end, { dispatch })
	React.useEffect(function()
		refresh()
	end, { refresh })
	React.useEffect(function()
		local joined = Players.PlayerAdded:Connect(refresh)
		local left = Players.PlayerRemoving:Connect(refresh)
		return function()
			joined:Disconnect()
			left:Disconnect()
		end
	end, { refresh })
	React.useEffect(function()
		local worker = task.spawn(function()
			while true do
				task.wait(4)
				refresh()
			end
		end)
		return function()
			pcall(function()
				return task.cancel(worker)
			end)
		end
	end, { refresh })
	local _visitUserId = visit
	if _visitUserId ~= nil then
		_visitUserId = _visitUserId.UserId
	end
	local visitUserId = _visitUserId
	local coerceCrewId = function(raw)
		local _raw = raw
		local _result
		if type(_raw) == "number" then
			_result = raw
		else
			local _raw_1 = raw
			_result = if type(_raw_1) == "string" then tonumber(raw) else nil
		end
		local asNumber = _result
		if asNumber == nil or asNumber ~= asNumber then
			return nil
		end
		local id = math.floor(asNumber + (if asNumber >= 0 then 1e-9 else -1e-9))
		if id == 0 then
			return nil
		end
		return id
	end
	local startVisit = function(userId)
		local id = coerceCrewId(userId)
		if id == nil then
			return nil
		end
		local attempt = visitAttemptRef.current + 1
		visitAttemptRef.current = attempt
		dispatch("VisitPlot", {
			UserId = id,
			userId = id,
		}, function(response)
			if not mountedRef.current or visitAttemptRef.current ~= attempt then
				return nil
			end
			if not response.ok then
				return nil
			end
			if response.Visit then
				setVisit(response.Visit)
			else
				local _result = response.State
				if _result ~= nil then
					_result = _result.Visit
				end
				if _result then
					setVisit(response.State.Visit)
				end
			end
		end)
	end
	local nudgeCrew = function(userId)
		local id = coerceCrewId(userId)
		if id == nil then
			return nil
		end
		dispatch("NudgeCrew", {
			UserId = id,
			userId = id,
		})
	end
	local headerReveal = useStagger(0, reducedMotion)
	local _result = state.Visitors
	if _result ~= nil then
		_result = #_result
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local visitorsHere = _condition
	local rowStride = if stack then 176 else 124
	local headerH = if stack then 130 else 112
	local listGap = if visit ~= nil then math.max(chrome.panelGap, 18) else math.max(chrome.panelGap, 12)
	local visitBlock = if visit ~= nil then PageBoardHeights.Visit(stack) else 0
	local crewTail = scrollTail(stack, chrome.bottomSafe, 48)
	local headerPanel = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.blue,
		background = Palette.panelRaised,
		padding = chrome.cardPadding,
		layoutOrder = 0,
		reveal = headerReveal,
		clips = false,
	}, React.createElement(Text, {
		value = "CREW ROSTER",
		size = 10,
		color = Palette.blue,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -160, 0, 18),
	}), React.createElement(Text, {
		value = "Crew on this server",
		size = if stack then 20 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, if stack then -8 else -190, 0, 30),
	}), React.createElement(Text, {
		value = if visitorsHere > 0 then `{visitorsHere} visiting your forge. Pick someone below to visit or send a wave.` else "See what everyone's up to live, visit a forge, or send a wave. Invites and friend boosts live in Playerlist.",
		size = chrome.labelText,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 54),
		sizeConstraint = UDim2.new(1, if stack then -8 else -190, 0, 38),
	}), React.createElement(Button, {
		text = if stack then "REFRESH" else "REFRESH CREW",
		icon = "Refresh",
		onClick = refresh,
		sound = "tick",
		color = Palette.blue,
		textColor = Palette.ink,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(170, 44),
		position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -170, 0, 24),
		reducedMotion = reducedMotion,
	}))
	local visitPanel = visit ~= nil and React.createElement(VisitPanel, {
		visit = visit,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		layoutOrder = 1,
		stack = stack,
	})
	local emptyPanel = #players == 0 and React.createElement(EmptyState, {
		icon = "Crew",
		title = "No one else is on shift",
		body = "Crew shows up here once someone else is online with you.",
		accent = Palette.blue,
		layoutOrder = 2,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#players)
	local _callback = function(player, index)
		return React.createElement(CrewRow, {
			key = player.UserId,
			player = player,
			visiting = visitUserId == player.UserId,
			visitorsHere = if player.IsLocal then visitorsHere else 0,
			onVisit = function()
				return startVisit(player.UserId)
			end,
			onNudge = function()
				return nudgeCrew(player.UserId)
			end,
			reducedMotion = reducedMotion,
			layoutOrder = index + 3,
			stack = stack,
		})
	end
	for _k, _v in players do
		_newValue[_k] = _callback(_v, _k - 1, players)
	end
	-- ▲ ReadonlyArray.map ▲
	local sections = {
		{
			id = "header",
			height = headerH,
			element = headerPanel,
		},
	}
	if visitPanel then
		table.insert(sections, {
			id = "visit",
			height = PageBoardHeights.Visit(stack),
			element = visitPanel,
		})
	end
	if emptyPanel then
		table.insert(sections, {
			id = "empty",
			height = 180,
			element = emptyPanel,
		})
	end
	for index, row in _newValue do
		table.insert(sections, {
			id = "crew-" .. tostring(index),
			height = rowStride,
			element = row,
		})
	end
	return React.createElement(PageScaffold, {
		gap = listGap,
		tailPad = crewTail,
		scrollBarColor = Palette.blue,
		scrollBarThickness = 4,
		sections = sections,
	})
end
local function PageContentInner(props)
	local _binding = props
	local page = _binding.page
	local state = _binding.state
	local config = _binding.config
	local dispatch = _binding.dispatch
	local reducedMotion = _binding.reducedMotion
	repeat
		if page == "Overview" then
			local _attributes = {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				effectsPaused = props.domainOverlayActive,
				openWorkshop = props.openWorkshop,
				openDomain = props.openDomain,
			}
			local _condition = config.Release.CountdownAt
			if _condition == nil then
				_condition = 1789272000
			end
			_attributes.releaseAt = _condition
			_attributes.navigate = props.navigate
			return React.createElement(OverviewView, _attributes)
		end
		if page == "Workshop" then
			return React.createElement(WorkshopView, {
				state = state,
				config = config,
				dispatch = dispatch,
				buyAmount = props.buyAmount,
				setBuyAmount = props.setBuyAmount,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Research" then
			return React.createElement(ResearchView, {
				state = state,
				config = config,
				dispatch = dispatch,
				buyAmount = props.buyAmount,
				setBuyAmount = props.setBuyAmount,
				reducedMotion = reducedMotion,
			})
		end
		if page == "StarGrid" then
			return React.createElement(StarGridView, {
				state = state,
				config = config,
				dispatch = dispatch,
				buyAmount = props.buyAmount,
				setBuyAmount = props.setBuyAmount,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Echoes" then
			return React.createElement(EchoForgeView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Continuum" then
			return React.createElement(ContinuumView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Convergence" then
			return React.createElement(ConvergenceView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Lab" then
			return React.createElement(LabView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Anomaly" then
			return React.createElement(AnomalyView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Worlds" then
			return React.createElement(WorldsView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Missions" then
			return React.createElement(MissionsView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Milestones" then
			return React.createElement(MilestonesView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Wheel" then
			return React.createElement(CinematicWheelView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				onLand = props.onWheelLand,
			})
		end
		if page == "Rewards" then
			return React.createElement(RewardsView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Boosts" then
			return React.createElement(BoostsView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Command" then
			return React.createElement(CommandView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				onSectionChange = props.clearConfetti,
			})
		end
		if page == "Story" then
			return React.createElement(StoryView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Mail" then
			return React.createElement(MailboxView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Chat" then
			return React.createElement(ChatView, {
				chat = props.chat,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Crew" then
			return React.createElement(CrewView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				visit = props.visit,
				setVisit = props.setVisit,
			})
		end
		if page == "Guild" then
			return React.createElement(GuildView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Leaderboards" then
			return React.createElement(LeaderboardsView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Shop" then
			return React.createElement(ShopView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				onPurchasePresentationChange = props.setPurchasePresentationActive,
			})
		end
		if page == "Inventory" then
			return React.createElement(InventoryView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				crateRevealActive = props.crateRevealActive,
				onCrateReveal = props.setCrateReveal,
				openShop = function()
					return props.navigate("Shop")
				end,
			})
		end
		if page == "Trade" then
			return React.createElement(TradeView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Settings" then
			return React.createElement(SettingsView, {
				state = state,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "Admin" then
			return React.createElement(AdminView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		if page == "ForgePath" then
			return React.createElement(ForgePathView, {
				state = state,
				config = config,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
			})
		end
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	until true
end
local PageContent = React.memo(PageContentInner)
return {
	PageContent = PageContent,
}
