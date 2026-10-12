--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("PagesProgress: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("PagesProgress: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["ResearchView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UpgradeTools = require(script.Parent.Parent.UpgradeTools)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _ui = require(script.Parent.Parent.UiCore)("ui")
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Button = _ui.Button
local Text = _ui.Text
local Meter = _ui.Meter
local Badge = _ui.Badge
local AmountToggle = _ui.AmountToggle
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local bulkCost = _format.bulkCost
local amountPayload = _format.amountPayload
local AppHelpers = require(script.Parent.Parent.CoreKit)("appNav").AppHelpers
local VirtualGrid = require(script.Parent.Parent.LayoutKit)("scrolling").VirtualGrid
local NODE_ROW_HEIGHT = 150
local NODE_ROW_HEIGHT_STACK = 190
local CONNECTOR_HEIGHT = 22
local function researchEffectLine(entry)
	local _condition = entry.config.BaseProduction
	if _condition == nil then
		_condition = 0
	end
	local production = _condition
	if production > 0 then
		return `+{compactNumber(production)} effect per level`
	end
	return entry.config.Description
end
local function ResearchConnector(_param)
	local active = _param.active
	local accent = _param.accent
	return React.createElement("frame", {
		Size = UDim2.new(0, 3, 0, CONNECTOR_HEIGHT),
		Position = UDim2.new(0, 25, 0, 0),
		BackgroundColor3 = if active then accent else Palette.line,
		BackgroundTransparency = if active then 0.15 else 0.65,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
end
local ResearchNode = React.memo(function(props)
	local _binding = props
	local entry = _binding.entry
	local reducedMotion = _binding.reducedMotion
	local softMotion = reducedMotion
	local index = _binding.index
	local onBuy = _binding.onBuy
	local stack = _binding.stack
	local buyAmount = _binding.buyAmount
	local cash = _binding.cash
	local reveal = useStagger(math.min(index, 6), reducedMotion, 0.02, 0.14)
	local accent = entry.config.Accent or entry.config.Color
	local maxed = entry.maxed
	local price = bulkCost(entry.config.BaseCost, entry.config.CostScale, entry.level, buyAmount, entry.config.MaxLevel, cash)
	local ready = entry.unlocked and not maxed and gteFlux(cash, price)
	local levelFrac = math.clamp(entry.level / math.max(1, entry.config.MaxLevel), 0, 1)
	local buyLabel = if not entry.unlocked then "LOCKED" elseif maxed then "MAXED" elseif ready then `BUY {compactNumber(price)}` else `NEED {compactNumber(price)}`
	local rowH = if stack then NODE_ROW_HEIGHT_STACK else NODE_ROW_HEIGHT
	local textReserve = if stack then 0 else -200
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, rowH + CONNECTOR_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, index > 0 and React.createElement(ResearchConnector, {
		active = entry.unlocked,
		accent = accent,
	}), React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		position = UDim2.fromOffset(0, CONNECTOR_HEIGHT),
		accent = if entry.unlocked then accent else Palette.lineSoft,
		background = Palette.panel,
		padding = 14,
		reveal = reveal,
		highlight = ready,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(IconTile, {
		kind = if entry.unlocked then "Research" else "Lock",
		accent = if entry.unlocked then accent else Palette.muted,
		size = 44,
		radius = 12,
		position = UDim2.fromOffset(0, 6),
		glow = maxed,
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = entry.config.Name,
		size = 16,
		color = if entry.unlocked then Palette.cream else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(56, 4),
		sizeConstraint = UDim2.new(1, textReserve, 0, 22),
	}), React.createElement(Text, {
		value = if entry.unlocked then researchEffectLine(entry) else entry.lockReason,
		size = 11,
		color = if entry.unlocked then Palette.creamSoft else accent,
		weight = if entry.unlocked then Enum.FontWeight.Regular else Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(56, 27),
		sizeConstraint = UDim2.new(1, textReserve, 0, 32),
	}), entry.unlocked and React.createElement(React.Fragment, nil, React.createElement(Text, {
		value = if maxed then `Level {compactNumber(entry.level)} · maxed` else `Level {compactNumber(entry.level)} / {compactNumber(entry.config.MaxLevel)}`,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(56, 62),
		sizeConstraint = UDim2.new(1, textReserve, 0, 14),
	}), React.createElement(Meter, {
		value = levelFrac,
		color = if maxed then Palette.mango else accent,
		reducedMotion = reducedMotion,
		position = UDim2.fromOffset(56, 80),
		size = UDim2.new(1, textReserve, 0, 6),
	})), if stack then (if maxed then React.createElement(Badge, {
		value = "MAXED",
		accent = Palette.mango,
		filled = true,
		position = UDim2.new(0, 0, 1, -TapTarget),
		size = UDim2.new(1, 0, 0, TapTarget),
	}) else React.createElement(Button, {
		text = buyLabel,
		icon = if entry.unlocked then "Flux" else "Lock",
		onClick = function()
			if not ready then
				return nil
			end
			return onBuy(entry.config.Id)
		end,
		color = if ready then accent else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = reducedMotion,
		disabled = not ready,
		highlight = ready,
	})) else (if maxed then React.createElement(Badge, {
		value = "MAXED",
		accent = Palette.mango,
		filled = true,
		position = UDim2.new(1, -140, 0, 24),
		size = UDim2.fromOffset(130, 32),
	}) else React.createElement(Button, {
		text = buyLabel,
		icon = if entry.unlocked then "Flux" else "Lock",
		onClick = function()
			if not ready then
				return nil
			end
			return onBuy(entry.config.Id)
		end,
		color = if ready then accent else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromOffset(130, 32),
		position = UDim2.new(1, -140, 0, 24),
		reducedMotion = reducedMotion,
		disabled = not ready,
		highlight = ready,
	}))))
end, function(prev, incoming)
	return prev.entry.config == incoming.entry.config and prev.entry.level == incoming.entry.level and prev.entry.price == incoming.entry.price and prev.entry.affordable == incoming.entry.affordable and prev.entry.maxed == incoming.entry.maxed and prev.entry.unlocked == incoming.entry.unlocked and prev.entry.lockReason == incoming.entry.lockReason and prev.buyAmount == incoming.buyAmount and prev.cash == incoming.cash and prev.reducedMotion == incoming.reducedMotion and prev.index == incoming.index and prev.onBuy == incoming.onBuy and prev.stack == incoming.stack
end)
local function ResearchView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
	local stack = chrome.contentStack
	local scrollRef = React.useRef()
	local buyAllHostRef = React.useRef(nil)
	local entries = React.useMemo(function()
		return AppHelpers:buildUpgradeEntries(config.Research, state.Research, state)
	end, { config.Research, state.Research, state.Zone, state.Rebirths })
	local _result = 0
	local _callback = function(sum, entry)
		return sum + (if entry.unlocked then 1 else 0)
	end
	for _i = 1, #entries do
		_result = _callback(_result, entries[_i], _i - 1, entries)
	end
	local unlockedCount = _result
	local _result_1 = 0
	local _callback_1 = function(sum, entry)
		return sum + (if entry.maxed then 1 else 0)
	end
	for _i = 1, #entries do
		_result_1 = _callback_1(_result_1, entries[_i], _i - 1, entries)
	end
	local maxedCount = _result_1
	local _callback_2 = function(entry)
		return entry.unlocked and not entry.maxed
	end
	local _result_2
	for _i, _v in entries do
		if _callback_2(_v, _i - 1, entries) == true then
			_result_2 = _v
			break
		end
	end
	local nextEntry = _result_2
	local query, setQuery = require(script.Parent.Parent.BrowseKit).useLinkedQuery("Research")
	local filter, setFilter = React.useState(if query ~= "" then "All" else "Available")
	local visible = UpgradeTools.Model.filter(entries, query, filter, buyAmount, state.Cash, require(script.Parent.Parent.BrowseKit).matches)
	local batch = UpgradeTools.useBatch(dispatch, "BuyResearch", visible, buyAmount, state.Cash)
	local onBuy = batch.buy
	local onBuyAll = batch.start
	local canBuyAll = batch.count > 0 and not batch.busy
	React.useEffect(function()
		local host = scrollRef.current
		if host then host.CanvasPosition = Vector2.zero end
	end, { query, filter })
	React.useEffect(function()
		if not canBuyAll or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = buyAllHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { canBuyAll, buyAmount, unlockedCount })
	local listGap = if stack then chrome.panelGap else Layout.panelGap
	local headerH = if stack then 208 else 128
	local researchGate = state.FeatureUnlocks
	if researchGate ~= nil then
		researchGate = researchGate.Research
	end
	local researchLocked = researchGate ~= nil and researchGate.Unlocked == false
	local chainCount = #visible
	local rowStride = (if stack then NODE_ROW_HEIGHT_STACK else NODE_ROW_HEIGHT) + CONNECTOR_HEIGHT
	local chainH = math.max(rowStride, chainCount * rowStride)
	return React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = listGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, 48),
		scrollBarColor = Palette.cyan,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero",
				height = headerH,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = Palette.cyan,
					background = Palette.panelRaised,
					padding = if stack then 14 else 16,
					reveal = enter,
					reducedMotion = softMotion,
					clips = false,
				}, React.createElement(IconTile, {
					kind = "Research",
					accent = Palette.cyan,
					size = if stack then 48 else 56,
					radius = 14,
					position = UDim2.fromOffset(0, if stack then 4 else 18),
					glow = true,
					spin = false,
					reducedMotion = softMotion,
				}), React.createElement(Text, {
					value = if researchLocked then "LOCKED UNTIL 100 FLUX" else "RESEARCH CHAIN",
					size = 10,
					color = Palette.cyan,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(if stack then 0 else 72, if stack then 60 else 0),
					sizeConstraint = UDim2.new(1, if stack then -8 else -332, 0, 16),
				}), React.createElement(Text, {
					value = if researchLocked then "Earn 100 Flux to begin research." else "Upgrades that survive rebirth.",
					size = if stack then 18 else 24,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					position = UDim2.fromOffset(if stack then 0 else 72, if stack then 78 else 18),
					sizeConstraint = UDim2.new(1, if stack then -8 else -332, 0, 32),
				}), React.createElement(Text, {
					value = `{unlockedCount} / {#entries} unlocked  ·  {maxedCount} maxed{if nextEntry ~= nil then `  ·  next: {nextEntry.config.Name}` else ""}`,
					size = 11,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(if stack then 0 else 72, if stack then 108 else 56),
					sizeConstraint = UDim2.new(1, if stack then -8 else -332, 0, 24),
				}), not stack and React.createElement(React.Fragment, nil, React.createElement(AmountToggle, {
					value = buyAmount,
					onChange = setBuyAmount,
					accent = Palette.cyan,
					position = UDim2.new(1, -240, 0, 16),
					size = UDim2.fromOffset(240, 32),
						reducedMotion = softMotion,
				}), React.createElement("frame", {
					Name = "ResearchBuyClaimActions",
					Size = UDim2.fromOffset(240, 32),
					Position = UDim2.new(1, -240, 0, 56),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = if canBuyAll then buyAllHostRef else nil,
				}, React.createElement(Button, {
					text = if batch.busy then batch.status else `BUY BATCH · {batch.count}`,
					icon = "Flux",
					onClick = onBuyAll,
					color = if canBuyAll then Palette.cyan else Palette.panelSoft,
					textColor = if canBuyAll then Palette.ink else Palette.muted,
					size = UDim2.fromScale(1, 1),
					reducedMotion = softMotion,
					disabled = not canBuyAll,
					highlight = canBuyAll,
				}))), stack and React.createElement(React.Fragment, nil, React.createElement(AmountToggle, {
					value = buyAmount,
					onChange = setBuyAmount,
					accent = Palette.cyan,
					position = UDim2.new(0, 0, 0, 132),
					size = UDim2.new(1, -104, 0, TapTarget),
						reducedMotion = softMotion,
				}), React.createElement("frame", {
					Name = "ResearchBuyClaimActions",
					Size = UDim2.fromOffset(96, TapTarget),
					Position = UDim2.new(1, -96, 0, 132),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
					ref = if canBuyAll then buyAllHostRef else nil,
				}, React.createElement(Button, {
					text = if batch.busy then "…" else `BUY {batch.count}`,
					icon = "Flux",
					onClick = onBuyAll,
					color = if canBuyAll then Palette.cyan else Palette.panelSoft,
					textColor = if canBuyAll then Palette.ink else Palette.muted,
					size = UDim2.fromScale(1, 1),
						reducedMotion = softMotion,
					disabled = not canBuyAll,
					highlight = canBuyAll,
				})))),
			},
			{
				id = "research-controls",
				height = if stack then 164 else 96,
				element = React.createElement(UpgradeTools.ResearchControls, { query = query, setQuery = setQuery, filter = filter, setFilter = setFilter, count = #visible, stack = stack, reducedMotion = softMotion, batch = batch }),
			},
			{
				id = "chain",
				height = chainH,
				element = if #visible == 0 then React.createElement(_ui.EmptyState, { title = "No matching research", body = "Try another search or choose All research.", icon = "Research", accent = Palette.cyan, reducedMotion = softMotion, size = UDim2.fromScale(1, 1) }) else React.createElement(VirtualGrid, {
					scrollRef = scrollRef,
					count = chainCount,
					columns = 1,
					cellHeight = rowStride,
					gap = 0,
					overscanRows = if softMotion then 0 elseif antilag.constrained then 1 else 2,
					itemKey = function(index)
						local entry = visible[index + 1]
						return if entry ~= nil then entry.config.Id else `node-{index}`
					end,
					renderItem = function(index)
						return React.createElement(ResearchNode, {
							entry = visible[index + 1],
							buyAmount = buyAmount,
							cash = state.Cash,
							reducedMotion = softMotion,
							index = index,
							onBuy = onBuy,
							stack = stack,
						})
					end,
				}),
			},
		},
	})
end
return {
	ResearchView = ResearchView,
}
end

__defs["LabView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useFlash = _motion.useFlash
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local ORDER_HEIGHT = 168
local ORDER_HEIGHT_STACK = 224
local ORDER_GAP = Layout.panelGap
local CHANNEL_IDS = { "Production", "Storage", "Tap" }
local SCROLL_PAD = 36 + 16
local SECTION_LABEL_H = 28
local BTN_W = 176
local SCROLL_BAR = 4
local ROW_RIGHT = SCROLL_BAR + 10
local function OrderRow(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local order = _param.order
	local stack = _param.stack
	local ready = not state.Claimed and state.Progress >= state.Target
	local fill = meterFill(state.Progress, state.Target, state.Claimed or ready)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local reveal = useStagger(order, reducedMotion)
	local claimTrigger, setClaimTrigger = React.useState(0)
	local claimFlash = useFlash(claimTrigger, reducedMotion, 0.4)
	local fireClaim = function()
		if not ready then
			return nil
		end
		setClaimTrigger(function(value)
			return value + 1
		end)
		return dispatch("ClaimLabOrder", {
			Id = state.Id,
		})
	end
	local rowH = if stack then ORDER_HEIGHT_STACK else ORDER_HEIGHT
	local pad = if stack then 14 else Layout.cardPadding
	local contentH = rowH - pad * 2
	local btnReserve = if stack then TapTarget + 14 else 0
	local meterY = if stack then contentH - btnReserve - 8 else 118
	local progressY = meterY - 18
	local meterSize = if stack then UDim2.new(1, 0, 0, 8) else UDim2.new(1, -(BTN_W + ROW_RIGHT + 12), 0, 8)
	local textW = if stack then -(58 + 12) else -(BTN_W + 74 + ROW_RIGHT)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		accent = config.Color,
		background = Palette.panelRaised,
		padding = pad,
		layoutOrder = order,
		reveal = reveal,
		interactive = true,
		highlight = ready,
		reducedMotion = reducedMotion,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(0, if stack then 4 else 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = claimFlash:map(function(amount)
			return 1 + amount * 0.18
		end),
	}), React.createElement(IconTile, {
		kind = "Mission",
		accent = config.Color,
		size = 46,
		radius = 12,
		glow = ready,
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = config.Name,
		size = 17,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(58, 2),
		sizeConstraint = UDim2.new(1, textW, 0, 24),
	}), React.createElement(Text, {
		value = config.Description,
		size = if stack then 12 else 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(58, 28),
		sizeConstraint = UDim2.new(1, textW, 0, if stack then 36 else 28),
	}), React.createElement(Text, {
		value = formatReward(config.Reward),
		size = 11,
		color = config.Color,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(58, if stack then 68 else 60),
		sizeConstraint = UDim2.new(1, textW, 0, 16),
	}), React.createElement(Text, {
		value = `{compactNumber(state.Progress)} / {compactNumber(state.Target)}`,
		size = 11,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(0, progressY),
		sizeConstraint = UDim2.fromOffset(180, 16),
	}), React.createElement(Meter, {
		value = fill,
		color = config.Color,
		position = UDim2.fromOffset(0, meterY),
		size = meterSize,
		reducedMotion = reducedMotion,
		shimmer = ready or state.Claimed,
	}), if stack then React.createElement(Button, {
		text = if state.Claimed then "PAID" elseif ready then "COLLECT" else "IN PROGRESS",
		icon = "Gift",
		onClick = fireClaim,
		color = if ready then config.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 6)),
		disabled = not ready,
		reducedMotion = reducedMotion,
		highlight = ready,
	}) else React.createElement(Button, {
		text = if state.Claimed then "PAID" elseif ready then "COLLECT" else "IN PROGRESS",
		icon = "Gift",
		onClick = fireClaim,
		color = if ready then config.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.fromOffset(BTN_W, 48),
		position = UDim2.new(1, -(BTN_W + ROW_RIGHT), 0.5, -24),
		disabled = not ready,
		reducedMotion = reducedMotion,
		highlight = ready,
	}))
end
local POWER_ROW_H = 76
local POWER_ROW_H_STACK = 96
local POWER_ROW_STRIDE = 82
local POWER_ROW_STRIDE_STACK = 104
local POWER_ROW_START = 48
local POWER_BTN = 44
local function PowerRow(_param)
	local id = _param.id
	local config = _param.config
	local value = _param.value
	local effect = _param.effect
	local available = _param.available
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local y = _param.y
	local stack = _param.stack
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local rowH = if stack then POWER_ROW_H_STACK else POWER_ROW_H
	local badgeX = POWER_BTN + 94 + ROW_RIGHT
	local minusX = POWER_BTN * 2 + 100 + 8 + ROW_RIGHT
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowH),
		Position = UDim2.fromOffset(0, y),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = config.Color,
		Thickness = 1,
		Transparency = 0.68,
	}), React.createElement(IconTile, {
		kind = if id == "Production" then "Forge" elseif id == "Storage" then "Vault" else "Command",
		accent = config.Color,
		size = 38,
		radius = 10,
		position = UDim2.fromOffset(10, if stack then 10 else 15),
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = config.Name,
		size = 14,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(58, if stack then 8 else 10),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 20) else -(minusX + 12), 0, 21),
	}), React.createElement(Text, {
		value = `{config.Description}  /  +{math.floor(effect * 100)}% active`,
		size = if stack then 11 else 9,
		color = config.Color,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(58, if stack then 32 else 34),
		sizeConstraint = UDim2.new(1, if stack then -(58 + 20) else -(minusX + 12), 0, if stack then 28 else 17),
	}), if stack then React.createElement("frame", {
		Size = UDim2.new(1, -(20 + ROW_RIGHT), 0, POWER_BTN),
		Position = UDim2.new(0, 10, 1, -(POWER_BTN + 8)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}), React.createElement(Button, {
		text = "−",
		onClick = function()
			return dispatch("RouteLabPower", {
				Channel = id,
				Delta = -1,
			})
		end,
		color = Palette.panelSoft,
		textColor = if value > 0 then Palette.cream else Palette.muted,
		outline = true,
		size = UDim2.fromOffset(POWER_BTN, POWER_BTN),
		disabled = value <= 0,
		reducedMotion = reducedMotion,
	}), React.createElement(Badge, {
		value = `{value} CELLS`,
		accent = config.Color,
		filled = true,
		size = UDim2.fromOffset(86, 28),
	}), React.createElement(Button, {
		text = "+",
		onClick = function()
			return dispatch("RouteLabPower", {
				Channel = id,
				Delta = 1,
			})
		end,
		color = config.Color,
		textColor = Palette.ink,
		size = UDim2.fromOffset(POWER_BTN, POWER_BTN),
		disabled = available <= 0,
		reducedMotion = reducedMotion,
	})) else React.createElement(React.Fragment, nil, React.createElement(Button, {
		text = "−",
		onClick = function()
			return dispatch("RouteLabPower", {
				Channel = id,
				Delta = -1,
			})
		end,
		color = Palette.panelSoft,
		textColor = if value > 0 then Palette.cream else Palette.muted,
		outline = true,
		size = UDim2.fromOffset(POWER_BTN, POWER_BTN),
		position = UDim2.new(1, -minusX, 0.5, -POWER_BTN / 2),
		disabled = value <= 0,
		reducedMotion = reducedMotion,
	}), React.createElement(Badge, {
		value = `{value} CELLS`,
		accent = config.Color,
		filled = true,
		position = UDim2.new(1, -badgeX, 0.5, -14),
		size = UDim2.fromOffset(86, 28),
	}), React.createElement(Button, {
		text = "+",
		onClick = function()
			return dispatch("RouteLabPower", {
				Channel = id,
				Delta = 1,
			})
		end,
		color = config.Color,
		textColor = Palette.ink,
		size = UDim2.fromOffset(POWER_BTN, POWER_BTN),
		position = UDim2.new(1, -(ROW_RIGHT + POWER_BTN), 0.5, -POWER_BTN / 2),
		disabled = available <= 0,
		reducedMotion = reducedMotion,
	})))
end
local function LabViewReady(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local lab = state.Lab
	local antilag = useAntilag()
	local softMotion = reducedMotion
	local now = useWallClock(true)
	local headerReveal = useStagger(0, softMotion)
	local ordersReveal = useStagger(1, softMotion)
	local claimReveal = useStagger(2, softMotion)
	local boardReveal = useStagger(3, softMotion)
	local labSoft = reducedMotion or ordersReveal == nil or claimReveal == nil or boardReveal == nil
	local labClaimHostRef = React.useRef(nil)
	local resetText = now:map(function(timestamp)
		return `New orders in {clockText(lab.ResetAt - timestamp)}`
	end)
	local orderConfigs = {}
	for _, entry in config.Lab.Orders do
		local _id = entry.Id
		orderConfigs[_id] = entry
	end
	local readyOrders = 0
	for _, order in lab.Orders do
		if not order.Claimed and order.Progress >= order.Target then
			readyOrders += 1
		end
	end
	local claimAllOrders = function()
		for _, order in lab.Orders do
			if not order.Claimed and order.Progress >= order.Target then
				dispatch("ClaimLabOrder", { Id = order.Id })
			end
		end
	end
	React.useEffect(function()
		if readyOrders <= 0 or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = labClaimHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { readyOrders })
	local guide = if config.ClientPageGuides ~= nil then config.ClientPageGuides.Lab else nil
	local orderH = if stack then ORDER_HEIGHT_STACK else ORDER_HEIGHT
	local orderBlock = if #lab.Orders > 0 then #lab.Orders * orderH + math.max(0, #lab.Orders - 1) * ORDER_GAP else 160
	local powerStride = if stack then POWER_ROW_STRIDE_STACK else POWER_ROW_STRIDE
	local powerBoardH = POWER_ROW_START + #CHANNEL_IDS * powerStride + 10 + 28
	local heroHeight = if stack then (if chrome.landscape then 156 else 188) else 168
	local _exp_2 = not stack and React.createElement(IconTile, {
		kind = "Lab",
		accent = Palette.mint,
		size = 52,
		radius = 14,
		position = UDim2.fromOffset(0, 10),
		spin = false,
		glow = true,
		reducedMotion = softMotion,
	})
	local _result
	if stack then
		local _exp_3 = React.createElement(Text, {
			value = resetText,
			size = 12,
			color = Palette.mint,
			weight = Enum.FontWeight.Bold,
			fit = false,
			sizeConstraint = UDim2.new(1, -8, 0, 18),
		})
		local _exp_4 = React.createElement(Text, {
			value = "Clear today's jobs, then dump spare cells into output, vault, or taps.",
			size = 12,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(0, 24),
			sizeConstraint = UDim2.new(1, -8, 0, if chrome.landscape then 28 else 40),
		})
		local _exp_5 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
		})
		local _attributes = {}
		local _exp_6 = lab.Orders
		local _newValue = {}
		local _callback = function(order)
			return order.Claimed
		end
		local _length = 0
		for _k, _v in _exp_6 do
			if _callback(_v, _k - 1, _exp_6) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		_attributes.value = `{#_newValue} / {#lab.Orders} PAID`
		_attributes.accent = Palette.mint
		_attributes.filled = true
		_attributes.size = UDim2.fromOffset(120, 26)
		_result = React.createElement(React.Fragment, nil, _exp_3, _exp_4, React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.new(0, 0, 1, -36),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, _exp_5, React.createElement(Badge, _attributes), React.createElement(Badge, {
			value = `{lab.AvailableCells} FREE`,
			accent = Palette.mango,
			size = UDim2.fromOffset(100, 24),
		})))
	else
		local _exp_3 = React.createElement(Text, {
			value = "WORKSHOP LAB",
			size = 10,
			color = Palette.mint,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(68, 0),
			sizeConstraint = UDim2.new(1, -(270 + ROW_RIGHT), 0, 16),
		})
		local _exp_4 = React.createElement(Text, {
			value = "Orders and power cells.",
			size = 22,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(68, 16),
			sizeConstraint = UDim2.new(1, -(270 + ROW_RIGHT), 0, 30),
		})
		local _exp_5 = React.createElement(Text, {
			value = "Clear today's jobs, then dump spare cells into output, vault, or taps.",
			size = 10,
			color = Palette.creamSoft,
			wrap = true,
			position = UDim2.fromOffset(68, 46),
			sizeConstraint = UDim2.new(1, -(270 + ROW_RIGHT), 0, 26),
		})
		local _exp_6 = React.createElement(Text, {
			value = resetText,
			size = 11,
			color = Palette.mint,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(68, 80),
			sizeConstraint = UDim2.new(1, -(270 + ROW_RIGHT), 0, 18),
		})
		local _attributes = {}
		local _exp_7 = lab.Orders
		local _newValue = {}
		local _callback = function(order)
			return order.Claimed
		end
		local _length = 0
		for _k, _v in _exp_7 do
			if _callback(_v, _k - 1, _exp_7) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		_attributes.value = `{#_newValue} / {#lab.Orders} PAID`
		_attributes.accent = Palette.mint
		_attributes.filled = true
		_attributes.position = UDim2.new(1, -(156 + ROW_RIGHT), 0, 12)
		_attributes.size = UDim2.fromOffset(148, 26)
		_result = React.createElement(React.Fragment, nil, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement(Badge, _attributes), React.createElement(Badge, {
			value = `{lab.AvailableCells} FREE CELLS`,
			accent = Palette.mango,
			position = UDim2.new(1, -(156 + ROW_RIGHT), 0, 46),
			size = UDim2.fromOffset(148, 24),
		}), readyOrders > 0 and React.createElement("frame", {
			Name = "LabClaimActions",
			Size = UDim2.fromOffset(148, 36),
			Position = UDim2.new(1, -(156 + ROW_RIGHT), 0, 78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = labClaimHostRef,
		}, React.createElement(Button, {
			text = `CLAIM ALL · {readyOrders}`,
			icon = "Gift",
			onClick = claimAllOrders,
			color = Palette.mint,
			textColor = Palette.ink,
			size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
			highlight = true,
		})))
	end
	local _exp_3 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = 16,
		reveal = if reducedMotion then boardReveal else headerReveal,
		highlight = not labSoft,
		reducedMotion = softMotion,
		clips = false,
	}, _exp_2, _result)
	local _exp_4 = React.createElement(SectionLabel, {
		value = "TODAY'S ORDERS",
		color = Palette.mint,
	})
	local orderBrowse = require(script.Parent.Parent.BrowseKit).useBrowse({
		id = "Lab",
		items = lab.Orders or {},
		text = function(orderState)
			local orderConfig = orderConfigs[orderState.Id]
			return { if orderConfig then orderConfig.Name else orderState.Id, if orderConfig then orderConfig.Description else nil }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Ready", label = "Ready", test = function(o)
				return (not o.Claimed and (tonumber(o.Target) or 0) > 0 and (tonumber(o.Progress) or 0) >= (tonumber(o.Target) or 0))
			end },
			{ id = "Running", label = "In progress", test = function(o)
				return not o.Claimed and not (not o.Claimed and (tonumber(o.Target) or 0) > 0 and (tonumber(o.Progress) or 0) >= (tonumber(o.Target) or 0))
			end },
			{ id = "Claimed", label = "Claimed", test = function(o)
				return o.Claimed == true
			end },
		},
	})
	local _exp_5 = orderBrowse.results
	orderBlock = if #_exp_5 > 0 then #_exp_5 * orderH + math.max(0, #_exp_5 - 1) * ORDER_GAP else 160
	local _newValue = table.create(#_exp_5)
	local _callback = function(orderState, index)
		local _id = orderState.Id
		local orderConfig = orderConfigs[_id]
		return orderConfig ~= nil and React.createElement(OrderRow, {
			key = orderState.Id,
			state = orderState,
			config = orderConfig,
			dispatch = dispatch,
			reducedMotion = softMotion,
			order = index,
			stack = stack,
		})
	end
	for _k, _v in _exp_5 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_5)
	end
	local orderStride = orderH + ORDER_GAP
	local virtOrders = #_exp_5 >= 6
	local ordersBlock = if #lab.Orders == 0 then React.createElement(EmptyState, {
		icon = "Lab",
		title = "No orders yet",
		body = (guide and guide.EmptyOrders) or "Orders refresh at the lab reset clock.",
		accent = Palette.mint,
		reducedMotion = reducedMotion,
	}) elseif #_exp_5 == 0 then React.createElement(require(script.Parent.Parent.BrowseKit).NoResults, {
		browse = orderBrowse,
		noun = "orders",
		icon = "Lab",
		accent = Palette.mint,
		reducedMotion = softMotion,
		compact = true,
		size = UDim2.fromScale(1, 1),
	}) elseif virtOrders then React.createElement(FlatList, {
		data = _exp_5,
		itemHeight = orderStride,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.mint,
		scrollBarThickness = SCROLL_BAR,
		keyExtractor = function(orderState)
			return orderState.Id
		end,
		renderItem = function(_param_1)
			local orderState = _param_1.item
			local index = _param_1.index
			local orderConfig = orderConfigs[orderState.Id]
			if orderConfig == nil then
				return nil
			end
			return React.createElement(OrderRow, {
				state = orderState,
				config = orderConfig,
				dispatch = dispatch,
					reducedMotion = softMotion,
				order = index,
				stack = stack,
			})
		end,
	}) else React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ORDER_GAP),
	}), _newValue)
	local _exp_6 = React.createElement(SectionLabel, {
		value = "POWER BOARD",
		color = Palette.mango,
	})
	local _exp_7 = React.createElement(Text, {
		value = "Move cells whenever you like.",
		size = if stack then 16 else 17,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, if stack then -8 else -(220 + ROW_RIGHT), 0, 24),
	})
	local _exp_8 = React.createElement(Text, {
		value = "Bonuses change immediately. One new cell unlocks every eight rebirths.",
		size = if stack then 11 else 10,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 24),
		sizeConstraint = UDim2.new(1, if stack then -8 else -(220 + ROW_RIGHT), 0, if stack then 32 else 16),
	})
	local _exp_9 = not stack and React.createElement(React.Fragment, nil, React.createElement(Badge, {
		value = `{lab.TotalCells} TOTAL`,
		accent = Palette.mango,
		filled = true,
		position = UDim2.new(1, -(196 + ROW_RIGHT), 0, 3),
		size = UDim2.fromOffset(92, 26),
	}), React.createElement(Badge, {
		value = `{lab.AvailableCells} FREE`,
		accent = Palette.mint,
		position = UDim2.new(1, -(94 + ROW_RIGHT), 0, 3),
		size = UDim2.fromOffset(94, 26),
	}))
	local _newValue_1 = table.create(#CHANNEL_IDS)
	local _callback_1 = function(id, index)
		local channel = config.Lab.Power.Channels[id]
		local _condition = channel ~= nil
		if _condition then
			local _attributes = {
				key = id,
				id = id,
				config = channel,
			}
			local _condition_1 = lab.Routing[id]
			if _condition_1 == nil then
				_condition_1 = 0
			end
			_attributes.value = _condition_1
			local _condition_2 = lab.Effects[id]
			if _condition_2 == nil then
				_condition_2 = 0
			end
			_attributes.effect = _condition_2
			_attributes.available = lab.AvailableCells
			_attributes.dispatch = dispatch
			_attributes.reducedMotion = reducedMotion
			_attributes.y = POWER_ROW_START + index * powerStride
			_attributes.stack = stack
			_condition = React.createElement(PowerRow, _attributes)
		end
		return _condition
	end
	for _k, _v in CHANNEL_IDS do
		_newValue_1[_k] = _callback_1(_v, _k - 1, CHANNEL_IDS)
	end
	return React.createElement(PageScaffold, {
		gap = ORDER_GAP,
		tailPad = scrollTail(stack, chrome.bottomSafe, SCROLL_PAD),
		scrollBarColor = Palette.lineSoft,
		scrollBarThickness = SCROLL_BAR,
		sections = {
			{
				id = "hero",
				height = heroHeight,
				element = _exp_3,
			},
			{
				id = "orders-label",
				height = SECTION_LABEL_H,
				element = _exp_4,
			},
			{
				id = "orders-filter",
				height = if #lab.Orders > 2 then require(script.Parent.Parent.BrowseKit).CHIP_H else 0,
				element = #lab.Orders > 2 and React.createElement(require(script.Parent.Parent.BrowseKit).ChipRow, {
					options = orderBrowse.categories,
					value = orderBrowse.category,
					onChange = orderBrowse.setCategory,
					counts = orderBrowse.counts,
					accent = Palette.mint,
				}) or nil,
			},
			{
				id = "orders",
				height = if virtOrders then math.min(orderBlock, orderStride * 4) else orderBlock,
				element = ordersBlock,
			},
			{
				id = "power-label",
				height = SECTION_LABEL_H,
				element = _exp_6,
			},
			{
				id = "power",
				height = powerBoardH,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = Palette.mango,
					background = Palette.panelRaised,
					padding = if stack then 14 else Layout.cardPadding,
					clips = false,
				}, _exp_7, _exp_8, _exp_9, _newValue_1),
			},
		},
	})
end
local function LabView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local lab = state.Lab
	local antilag = useAntilag()
	local softMotion = reducedMotion
	local now = useWallClock(true)
	local headerReveal = useStagger(0, softMotion)
	local ordersReveal = useStagger(1, softMotion)
	local claimReveal = useStagger(2, softMotion)
	local boardReveal = useStagger(3, softMotion)
	local labSoft = reducedMotion or ordersReveal == nil or claimReveal == nil or boardReveal == nil
	local labClaimHostRef = React.useRef(nil)
	if lab == nil then
		return React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 160),
			accent = Palette.mint,
			background = Palette.panelRaised,
			padding = 20,
		}, React.createElement(Text, {
			value = "Loading the Lab...",
			size = 15,
			color = Palette.creamSoft,
			wrap = true,
		}))
	end
	return React.createElement(LabViewReady, _param)
end
return {
	LabView = LabView,
}
end

__defs["WorkshopView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UpgradeTools = require(script.Parent.Parent.UpgradeTools)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local AmountToggle = _ui.AmountToggle
local Badge = _ui.Badge
local Button = _ui.Button
local Dropdown = _ui.Dropdown
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local SearchField = _ui.SearchField
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.CoreKit)("format")
local amountPayload = _format.amountPayload
local bulkCost = _format.bulkCost
local compactNumber = _format.compactNumber
local compareFlux = _format.compareFlux
local gteFlux = _format.gteFlux
local VirtualGrid = require(script.Parent.Parent.LayoutKit)("scrolling").VirtualGrid
local AppHelpers = require(script.Parent.Parent.CoreKit)("appNav").AppHelpers
local PageBoardHeights = require(script.Parent.Parent.CoreKit)("pageBoardHeights")

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
	local lockShort = _param.lockShort
	if lockShort == nil then
		lockShort = ""
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local rowH = PageBoardHeights.Machine(stack)
	local price = bulkCost(machine.BaseCost, machine.CostScale, level, buyAmount, machine.MaxLevel, cash)
	local maxed = level >= machine.MaxLevel
	local ready = unlocked and gteFlux(cash, price) and not maxed
	local accent = machine.Accent or machine.Color
	local running = level > 0
	local flow = useClock(running, 0.55, 1)
	local buyLabel = if not unlocked then (if lockShort ~= "" then lockShort else "Locked") elseif maxed then "Maxed" elseif ready then (if level < 1 then "Buy this" else "Buy level") else `Need {compactNumber(price)} Flux`
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
			_result_1 = if level < 1 then `+{compactNumber(_condition_1)} Flux/sec once bought` else `{compactNumber(_condition_1)} Flux/sec · level {compactNumber(level)}`
		else
			_result_1 = if maxed then `Level {compactNumber(level)} · maxed` else `Level {compactNumber(level)} · next {compactNumber(price)}`
		end
		_result = _result_1
	end
	local rateLine = _result
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
		reducedMotion = softMotion,
	}, React.createElement(IconTile, {
		kind = if unlocked then ((machine.Icon) or "Forge") else "Lock",
		accent = if unlocked then machine.Color else Palette.muted,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 6 else 16),
		spin = false,
		reducedMotion = softMotion,
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
		fit = true,
		minSize = 9,
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
		disabled = not ready,
		highlight = ready,
	})))
end
local SORT_OPTIONS = { {
	id = "Return",
	label = "Best level return",
}, {
	id = "Default",
	label = "Tier order",
}, {
	id = "Cheapest",
	label = "Cheapest first",
}, {
	id = "Output",
	label = "Biggest level gain",
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
	local featurePanel = _param.featurePanel
	local featurePanelHeight = _param.featurePanelHeight
	if featurePanelHeight == nil then
		featurePanelHeight = 0
	end
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local workshopHostReveal = useStagger(4, softMotion)
	local workshopBuyHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = workshopBuyHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { buyAmount, #entries })
	local query, setQuery = require(script.Parent.Parent.BrowseKit).useLinkedQuery("Workshop")
	local sort, setSort = React.useState("Default")
	local filter, setFilter = React.useState("All")
	local headerReveal = useStagger(0, softMotion)
	local controlsReveal = useStagger(1, softMotion)
	local featureReveal = useStagger(2, softMotion)
	local gridReveal = useStagger(3, softMotion)
	local cash = state.Cash
	local canBuy = function(entry)
		return UpgradeTools.Model.quote(entry, buyAmount, cash).ready
	end
	local _result = 0
	local _callback = function(total, entry)
		return total + (if canBuy(entry) then 1 else 0)
	end
	for _i = 1, #entries do
		_result = _callback(_result, entries[_i], _i - 1, entries)
	end
	local affordableCount = _result
	local _result_1 = 0
	local _callback_1 = function(total, entry)
		return total + (if entry.level > 0 then 1 else 0)
	end
	for _i = 1, #entries do
		_result_1 = _callback_1(_result_1, entries[_i], _i - 1, entries)
	end
	local ownedCount = _result_1
	local near = AppHelpers:trimFarLockedUpgrades(entries)
	local _result_2 = 0
	local _callback_2 = function(total, entry)
		return total + (if not entry.unlocked then 1 else 0)
	end
	for _i = 1, #near do
		_result_2 = _callback_2(_result_2, near[_i], _i - 1, near)
	end
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
	local needle = string.lower(string.match(query, "^%s*(.-)%s*$"))
	local pool = if needle ~= "" then entries else near
	local visible = {}
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
		if needle ~= "" and not require(script.Parent.Parent.BrowseKit).matches(needle, entry.config.Name, entry.config.Description) then
			return nil
		end
		local _entry = entry
		table.insert(visible, _entry)
	end
	for _k, _v in pool do
		_callback_3(_v, _k - 1, pool)
	end
	table.sort(visible, function(left, right)
		if sort == "Return" then
			local leftRank = if canBuy(left) then 0 elseif left.unlocked and not left.maxed then 1 else 2
			local rightRank = if canBuy(right) then 0 elseif right.unlocked and not right.maxed then 1 else 2
			if leftRank ~= rightRank then return leftRank < rightRank end
			local a, b = UpgradeTools.Model.returnScore(left), UpgradeTools.Model.returnScore(right)
			if a ~= b then return a > b end
		elseif sort == "Cheapest" then
			local comparison = compareFlux(UpgradeTools.Model.quote(left, buyAmount, cash).cost, UpgradeTools.Model.quote(right, buyAmount, cash).cost)
			if comparison ~= 0 then return comparison < 0 end
		elseif sort == "Output" then
			local a = UpgradeTools.Model.gainScore(left)
			local b = UpgradeTools.Model.gainScore(right)
			if a ~= b then return a > b end
		elseif sort == "Level" and left.level ~= right.level then return left.level > right.level end
		return left.order < right.order
	end)
	local batch = UpgradeTools.useBatch(_param.dispatch, "BuyMachine", visible, buyAmount, cash)
	local onBuy = batch.buy
	local onBuyAll = batch.start
	local stack = chrome.contentStack
	local touchLayout = chrome.mobile
	local searchW = 252
	local sortW = 176
	local filterW = 176
	local controlGap = 12
	local controlsWrap = not stack and viewport.width < 900
	local stackControlsY = if chrome.landscape then 40 else 56
	local headerHeight = if chrome.landscape and stack then 136 elseif stack then 268 else (if controlsWrap then 232 else 188)
	local rowH = PageBoardHeights.Machine(stack)
	local gap = if stack then chrome.panelGap else Layout.panelGap
	local columns = if stack then 1 elseif viewport.width >= 2200 then 4 elseif viewport.width >= 1400 then 3 elseif viewport.width >= 900 then 2 else 1
	local columnWidth = UDim2.new(1 / columns, -(gap * (columns - 1)) / columns, 0, rowH)
	local gridRows = math.ceil(math.max(1, #visible) / columns)
	local machinesBlock = if #visible == 0 then 150 else (gridRows * rowH + math.max(0, gridRows - 1) * gap)
	local machineScrollTail = if stack then scrollTail(stack, chrome.bottomSafe, if chrome.landscape then 52 else 80) else scrollTail(stack, chrome.bottomSafe, 28)
	local scrollRef = React.useRef()
	React.useEffect(function()
		local host = scrollRef.current
		if host then host.CanvasPosition = Vector2.zero end
	end, { query, sort, filter })
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
		sizeConstraint = UDim2.new(1, if stack then -8 else -248, 0, if stack then 20 else 34),
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
		text = if batch.busy then batch.status elseif batch.count > 0 then `Buy batch · {batch.count}` else "Nothing to buy yet",
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
		disabled = batch.count <= 0 or batch.busy or onBuyAll == nil,
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
		text = if batch.busy then batch.status elseif batch.count > 0 then `Buy batch · {batch.count}` else "Nothing to buy",
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
		disabled = batch.count <= 0 or batch.busy or onBuyAll == nil,
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
		title = if needle ~= "" or filter ~= "All" then "Nothing matches" elseif filter == "Affordable" then "Can't afford a machine yet" else "No machines to show",
		body = if needle ~= "" then "Clear the search to see the machines again." elseif filter == "Affordable" then "Collect Flux on Overview, then come back to buy the next machine." elseif filter ~= "All" then "Switch the filter back to Near unlocks." else "Buy a machine to start earning Flux into your vault.",
		accent = accent,
		size = UDim2.fromScale(1, 1),
	}), filter == "Affordable" and affordableCount == 0 and React.createElement(Button, {
		text = "Show next machines",
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
				local entry = visible[index + 1]
				return if entry ~= nil then entry.config.Id else `machine-{index}`
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
					lockShort = entry.lockShort,
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
			id = "purchase-plan",
			height = 128,
			element = React.createElement(UpgradeTools.Planner, { entries = visible, amount = buyAmount, cash = cash, batch = batch, accent = accent }),
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
	return React.createElement("frame", {
		Name = "WorkshopBuyClaim",
		ref = workshopBuyHostRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.cyan,
		background = Palette.panel,
		padding = 0,
		reveal = workshopHostReveal,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = gap,
		tailPad = machineScrollTail,
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = sections,
	})))
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
	local softMotion = reducedMotion
	reducedMotion = softMotion
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
		reducedMotion = softMotion,
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
		_attributes.reducedMotion = softMotion
	_attributes.zIndex = 54
	return React.createElement(Panel, {
		size = UDim2.new(1, -4, 0, height),
		accent = Palette.mango,
		background = darken(Palette.mango, 0.9),
		padding = 14,
		layoutOrder = 1,
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
		highlight = not queue.Enabled,
		zIndex = 27,
	})))
end
local function listedFluxPerSec(machine): number
	local base = if type(machine) == "table" then machine.BaseProduction else nil
	if type(base) ~= "number" or base <= 0 then
		return 0
	end
	return base
end
local function WorkshopView(_param)
	local state = _param.state
	local config = _param.config
	local machines = if config ~= nil and type(config.Machines) == "table" then config.Machines else {}
	local dispatch = _param.dispatch
	local buyAmount = _param.buyAmount
	local setBuyAmount = _param.setBuyAmount
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chainStack = chromeFor(viewport).contentStack
	local stellarLevel = state.Machines.StellarCore
	if stellarLevel == nil then
		stellarLevel = 0
	end
	local firstMachine = stellarLevel < 1
	local chainLine = nil
	if not firstMachine then
		local names = {}
		for _, machine in machines do
			if type(machine) == "table" and type(machine.Id) == "string" then
				names[machine.Id] = if type(machine.Name) == "string" then machine.Name else machine.Id
			end
		end
		for _, machine in machines do
			if type(machine) ~= "table" or type(machine.PreviousId) ~= "string" then
				continue
			end
			local needLevel = machine.PreviousLevel
			if type(needLevel) ~= "number" then
				needLevel = 1
			end
			local haveLevel = state.Machines[machine.PreviousId]
			if type(haveLevel) ~= "number" then
				haveLevel = 0
			end
			local rebirthsNeed = machine.RequiredRebirths
			if type(rebirthsNeed) ~= "number" then
				rebirthsNeed = 0
			end
			local zoneNeed = machine.RequiredZone
			if type(zoneNeed) ~= "number" then
				zoneNeed = 1
			end
			local rebirthsHave = state.Rebirths
			if type(rebirthsHave) ~= "number" then
				rebirthsHave = 0
			end
			local zoneHave = state.Zone
			if type(zoneHave) ~= "number" then
				zoneHave = 1
			end
			local machineName = if type(machine.Name) == "string" then machine.Name else machine.Id
			local rate = listedFluxPerSec(machine)
			local earns = if rate > 0 then ` earns {compactNumber(rate)} Flux/sec` else ""
			local rateBit = if rate > 0 then ` +{compactNumber(rate)}/sec` else ""
			if rebirthsHave < rebirthsNeed then
				chainLine = if chainStack
					then `{machineName}{rateBit}. {rebirthsHave}/{rebirthsNeed} rebirths.`
					else `{machineName}{earns}. Needs {rebirthsNeed} rebirth{if rebirthsNeed == 1 then "" else "s"}. You have {rebirthsHave}.`
				break
			elseif zoneHave < zoneNeed then
				chainLine = if chainStack
					then `{machineName}{rateBit}. World {zoneHave}/{zoneNeed}.`
					else `{machineName}{earns}. Needs world {zoneNeed}. You are on world {zoneHave}.`
				break
			elseif haveLevel < needLevel then
				local prevName = names[machine.PreviousId]
				if prevName == nil then
					prevName = machine.PreviousId
				end
				chainLine = if chainStack
					then `Next: {machineName}{rateBit}. {prevName} {haveLevel}/{needLevel}.`
					elseif rate > 0
					then `Next: {machineName} earns {compactNumber(rate)} Flux/sec. Get {prevName} to level {needLevel}. You have {haveLevel}.`
					else `Next: {machineName}. Get {prevName} to level {needLevel}. You have {haveLevel}.`
				break
			end
		end
	end
	local entries = React.useMemo(function()
		return AppHelpers:buildUpgradeEntries(machines, state.Machines, state)
	end, { machines, state.Machines, state.Zone, state.Rebirths })
	local featureHeight = if chromeFor(viewport).landscape then 128 elseif chromeFor(viewport).stack then 188 else 168
	return React.createElement(UpgradeBoard, {
		title = if firstMachine then "Buy a machine" else "More hands. Less waiting.",
		eyebrow = if firstMachine then "EARNS FLUX" else "BUILD QUEUE",
		blurb = if firstMachine then "A machine earns Flux into your vault every second." elseif chainLine ~= nil then chainLine else "More machines = more flux, even while you're AFK.",
		accent = Palette.coral,
		entries = entries,
		state = state,
		buyAmount = buyAmount,
		setBuyAmount = setBuyAmount,
		reducedMotion = reducedMotion,
		dispatch = dispatch,
		featurePanelHeight = featureHeight,
		featurePanel = React.createElement(AutoForgePanel, {
			state = state,
			machines = machines,
			dispatch = dispatch,
			reducedMotion = reducedMotion,
			height = featureHeight,
		}),
	})
end
return {
	WorkshopView = WorkshopView,
}
end

__defs["ForgePathView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local _ui = require(script.Parent.Parent.UiCore)("ui")
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Button = _ui.Button
local Text = _ui.Text
local Meter = _ui.Meter
local Badge = _ui.Badge
local EmptyState = _ui.EmptyState
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local decorateForgePathSteps = require(script.Parent.Parent.CoreKit)("types").decorateForgePathSteps
local Browse = require(script.Parent.Parent.BrowseKit)
local STEP_ROW_HEIGHT = 168
local STEP_ROW_HEIGHT_STACK = 224
local SPOTLIGHT_H = 148
local SPOTLIGHT_H_STACK = 188
local EMPTY_FORGE_PATH = { ClaimedSteps = {}, XP = 0 }
local function pageGuide(config)
	local guides = config and config.ClientPageGuides
	return if guides ~= nil then guides.ForgePath else nil
end
local function effectLabel(step)
	local noun = step.Noun
	if noun == nil or noun == "" then
		local names = {
			Production = "production", TapPower = "tap power", Capacity = "vault capacity",
			CriticalChance = "critical chance", AutoCollect = "auto-collect rate", Offline = "offline income",
			CriticalMultiplier = "critical multiplier", RebirthMultiplier = "rebirth multiplier",
		}
		noun = names[step.EffectKind] or step.EffectKind
	end
	return `+{step.EffectAmount}% {noun}`
end
local function rewardChips(reward, accent)
	local chips = {}
	if (reward.Cash or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Cash)} flux`, icon = "Flux" }) end
	if (reward.Stardust or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Stardust)} dust`, icon = "Dust" }) end
	if (reward.Cores or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Cores)} cores`, icon = "Core" }) end
	if (reward.Essence or 0) > 0 then table.insert(chips, { label = `{compactNumber(reward.Essence)} essence`, icon = "StarGrid" }) end
	if reward.Boost ~= nil then table.insert(chips, { label = reward.Boost, icon = "Boost" }) end
	local nodes = table.create(#chips)
	for index, chip in chips do
		nodes[index] = React.createElement("frame", {
			key = index, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = darken(accent, 0.55), BorderSizePixel = 0, LayoutOrder = index, ClipsDescendants = false,
		}, React.createElement("uicorner", { CornerRadius = UDim.new(0, 7) }), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(darken(accent, 0.5), 0.06), darken(accent, 0.2)), Rotation = 90,
		}), React.createElement("uipadding", {
			PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		}), React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
		}), React.createElement("frame", {
			Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 0, ClipsDescendants = true,
		}, React.createElement(Icon, { kind = chip.icon, color = Palette.cream, accent = accent, size = 16, spin = false, clipSafe = true })), React.createElement("textlabel", {
			Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, BorderSizePixel = 0,
			Text = chip.label, TextColor3 = Palette.cream, TextSize = 11, FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = 1,
		}))
	end
	return nodes
end
local function ForgePathRow(_param)
	local step, claimed, unlockedForClaim, affordable, xp = _param.step, _param.claimed, _param.unlockedForClaim, _param.affordable, _param.xp
	local onClaim, reducedMotion, index, stack = _param.onClaim, _param.reducedMotion, _param.index, _param.stack
	local softMotion = reducedMotion
	local reveal = useStagger(index, reducedMotion, 0.015, 0.12)
	local ready = not claimed and unlockedForClaim and affordable
	local locked = not claimed and not unlockedForClaim
	local accent = if claimed then Palette.muted elseif ready then step.Color else Palette.mango
	local progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1)
	local statusText = if claimed then "CLAIMED" elseif locked then "CLAIM THE PREVIOUS STEP FIRST" else `{compactNumber(math.min(xp, step.XPCost))} / {compactNumber(step.XPCost)} XP`
	local rowH = if stack then STEP_ROW_HEIGHT_STACK else STEP_ROW_HEIGHT
	local textW = if stack then -48 else -200
	return React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, rowH), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = index, ClipsDescendants = false,
	}, React.createElement(Panel, {
		size = UDim2.fromScale(1, 1), accent = accent, background = Palette.panel, padding = 12, reveal = reveal, highlight = ready, reducedMotion = reducedMotion, clips = false,
	}, React.createElement(IconTile, { kind = step.Icon, accent = if claimed then Palette.muted else step.Color, size = 38, radius = 10, position = UDim2.fromOffset(0, 4), spin = false, reducedMotion = reducedMotion }),
	React.createElement(Text, { value = `STEP {step.Step}`, size = 10, color = if claimed then Palette.muted else step.Color, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(48, 2), sizeConstraint = UDim2.new(1, textW, 0, 16) }),
	React.createElement(Text, { value = effectLabel(step), size = 14, color = if claimed then Palette.muted else Palette.cream, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(48, 20), sizeConstraint = UDim2.new(1, textW, 0, 20) }),
	React.createElement(Text, { value = formatReward(step.Reward), size = 10, color = Palette.mango, weight = Enum.FontWeight.Bold, wrap = true, position = UDim2.fromOffset(48, 42), sizeConstraint = UDim2.new(1, textW, 0, 16) }),
	React.createElement("frame", { Size = UDim2.new(1, textW, 0, 26), Position = UDim2.fromOffset(48, 60), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false },
		React.createElement("uilistlayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
		rewardChips(step.Reward, if claimed then Palette.muted else step.Color)),
	React.createElement(Meter, { value = if claimed then 1 else progressFrac, color = accent, reducedMotion = reducedMotion, shimmer = ready, position = UDim2.fromOffset(0, if stack then 98 else 104), size = UDim2.new(1, if stack then 0 else -200, 0, 8) }),
	React.createElement(Text, { value = statusText, size = 10, color = if ready then step.Color else Palette.muted, weight = Enum.FontWeight.Bold, fit = false, position = UDim2.fromOffset(0, if stack then 112 else 118), sizeConstraint = UDim2.new(1, if stack then 0 else -200, 0, 16) }),
	if stack then (if claimed then React.createElement(Badge, { value = "CLAIMED", accent = Palette.muted, filled = true, size = UDim2.new(1, 0, 0, TapTarget), position = UDim2.new(0, 0, 1, -TapTarget) })
		else React.createElement(Button, { text = if ready then "CLAIM STEP" elseif locked then "LOCKED" else "NEED XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.new(1, 0, 0, TapTarget), position = UDim2.new(0, 0, 1, -TapTarget), reducedMotion = reducedMotion, disabled = not ready, highlight = ready }))
	else (if claimed then React.createElement(Badge, { value = "CLAIMED", accent = Palette.muted, filled = true, position = UDim2.new(1, -150, 0, 26), size = UDim2.fromOffset(140, 32) })
		else React.createElement(Button, { text = if ready then "CLAIM" elseif locked then "LOCKED" else "NEED XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.fromOffset(140, 32), position = UDim2.new(1, -150, 0, 26), reducedMotion = reducedMotion, disabled = not ready, highlight = ready }))))
end
local function SpotlightPanel(_param)
	local step, xp, ready, complete, guide = _param.step, _param.xp, _param.ready, _param.complete, _param.guide
	local onClaim, reducedMotion, stack = _param.onClaim, _param.reducedMotion, _param.stack
	local softMotion = reducedMotion
	local claimHostRef = React.useRef(nil)
	React.useEffect(function()
		if not ready or complete or step == nil or not UserInputService.GamepadEnabled then
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
			pcall(task.cancel, selectJob)
		end
	end, { ready, complete, if step ~= nil then step.Step else 0 })
	if complete then
		return React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.mint, background = Palette.panelRaised, padding = if stack then 14 else 16, clips = false },
			React.createElement(EmptyState, { icon = "Check", title = "Forge Path complete", body = (guide and guide.Complete) or "Path cleared. Permanent bonuses stay through rebirth.", accent = Palette.mint, compact = true, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion }))
	end
	if step == nil then
		return React.createElement(Panel, { size = UDim2.fromScale(1, 1), accent = Palette.violet, background = Palette.panelRaised, padding = if stack then 14 else 16, clips = false },
			React.createElement(EmptyState, { icon = "Forge", title = "No steps configured", body = "Forge Path steps come from GameConfig.", accent = Palette.violet, compact = true, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion }))
	end
	local progressFrac = math.clamp(xp / math.max(1, step.XPCost), 0, 1)
	local needXp = not ready and xp < step.XPCost
	return React.createElement(Panel, {
		size = UDim2.fromScale(1, 1), accent = if ready then step.Color else Palette.violet, background = Palette.panelRaised,
		padding = if stack then 14 else 16, highlight = ready, reducedMotion = reducedMotion, clips = false,
	}, React.createElement(Text, { value = if ready then "READY TO CLAIM" else "NEXT STEP", size = 10, color = if ready then step.Color else Palette.violet, weight = Enum.FontWeight.Heavy, sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 16) }),
	React.createElement(Text, { value = `Step {step.Step} · {effectLabel(step)}`, size = if stack then 18 else 22, color = Palette.cream, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(0, 18), sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 28) }),
	React.createElement(Text, { value = if needXp then ((guide and guide.NeedXp) or "Bank flux to earn Forge Path XP.") else formatReward(step.Reward), size = 11, color = if needXp then Palette.creamSoft else Palette.mango, wrap = true, position = UDim2.fromOffset(0, 50), sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 32) }),
	React.createElement(Meter, { value = progressFrac, color = if ready then step.Color else Palette.violet, reducedMotion = reducedMotion, shimmer = ready, position = UDim2.fromOffset(0, if stack then 96 else 92), size = UDim2.new(1, if stack then 0 else -180, 0, 8) }),
	React.createElement(Text, { value = `{compactNumber(math.min(xp, step.XPCost))} / {compactNumber(step.XPCost)} XP`, size = 10, color = Palette.muted, weight = Enum.FontWeight.Bold, position = UDim2.fromOffset(0, if stack then 110 else 106), sizeConstraint = UDim2.new(1, if stack then 0 else -180, 0, 16) }),
	if stack then React.createElement("frame", { Name = "ForgePathClaimActions", Size = UDim2.new(1, 0, 0, TapTarget), Position = UDim2.new(0, 0, 1, -TapTarget), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, ref = claimHostRef },
		React.createElement(Button, { text = if ready then "CLAIM NOW" else "NEED MORE XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion, disabled = not ready, highlight = ready }))
	else React.createElement("frame", { Name = "ForgePathClaimActions", Size = UDim2.fromOffset(160, TapTarget), Position = UDim2.new(1, -160, 0.5, -TapTarget / 2), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false, ref = claimHostRef },
		React.createElement(Button, { text = if ready then "CLAIM NOW" else "NEED XP", icon = "Check", onClick = function() return onClaim(step.Step) end, color = if ready then step.Color else Palette.panelSoft, textColor = if ready then Palette.ink else Palette.muted, size = UDim2.fromScale(1, 1), reducedMotion = reducedMotion, disabled = not ready, highlight = ready })))
end
local function ForgePathViewComponent(_param)
	local state, config, dispatch, reducedMotion = _param.state, _param.config, _param.dispatch, _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local forgePath = state.ForgePath or EMPTY_FORGE_PATH
	local guide = pageGuide(config)
	local steps = React.useMemo(function()
		local raw = if config ~= nil and config.ForgePath ~= nil then config.ForgePath.Steps else nil
		return decorateForgePathSteps(raw)
	end, { config })
	local claimedSet = {}
	for _, stepId in forgePath.ClaimedSteps do claimedSet[stepId] = true end
	local claimedCount, totalCount = #forgePath.ClaimedSteps, #steps
	local nextStep, nextReady = nil, false
	for _, step in steps do
		if claimedSet[step.Step] == nil then
			local unlocked = step.Step == 1 or claimedSet[step.Step - 1] ~= nil
			if unlocked then nextStep = step; nextReady = forgePath.XP >= step.XPCost; break end
		end
	end
	local pathComplete = totalCount > 0 and claimedCount >= totalCount
	local onClaim = function(step) return dispatch("ClaimForgePathStep", { Step = step }) end
	local headerReveal = useStagger(0, softMotion)
	local listGap = if stack then chrome.panelGap else Layout.panelGap
	local headerH = if stack then 148 else 128
	local spotlightH = if stack then SPOTLIGHT_H_STACK else SPOTLIGHT_H
	local stepRowHeight = if stack then STEP_ROW_HEIGHT_STACK else STEP_ROW_HEIGHT
	local stepsBlockH = if totalCount == 0 then 160 else totalCount * stepRowHeight + math.max(0, totalCount - 1) * listGap
	local progressFrac = if totalCount > 0 then claimedCount / totalCount else 0
	local heroBlurb = (guide and guide.HeroBlurb) or "One track. Every step pays out."
	local stepStride = stepRowHeight + listGap
	local browse = Browse.useBrowse({
		id = "ForgePath",
		items = steps,
		text = function(step)
			return { effectLabel(step), formatReward(step.Reward), `step {step.Step}`, step.EffectKind }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Upcoming", label = "Upcoming", test = function(step)
				return claimedSet[step.Step] == nil
			end },
			{ id = "Claimed", label = "Claimed", test = function(step)
				return claimedSet[step.Step] ~= nil
			end },
		},
	})
	local stepsElement = if totalCount > 0 and #browse.results == 0 then React.createElement(Browse.NoResults, {
		browse = browse,
		noun = "steps",
		icon = "Forge",
		accent = Palette.violet,
		reducedMotion = softMotion,
		size = UDim2.fromScale(1, 1),
	}) elseif totalCount == 0 then React.createElement(EmptyState, {
		icon = "Forge",
		title = "Forge Path offline",
		body = "Steps load from GameConfig.ForgePath.Steps.",
		accent = Palette.violet,
		reducedMotion = softMotion,
	}) else React.createElement(FlatList, {
		data = browse.results,
		itemHeight = stepStride,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		keyExtractor = function(step)
			return step.Step
		end,
		renderItem = function(_param_1)
			local step = _param_1.item
			local index = _param_1.index
			return React.createElement(ForgePathRow, {
				step = step,
				claimed = claimedSet[step.Step] ~= nil,
				unlockedForClaim = step.Step == 1 or claimedSet[step.Step - 1] ~= nil,
				affordable = forgePath.XP >= step.XPCost,
				xp = forgePath.XP,
				onClaim = onClaim,
				reducedMotion = reducedMotion,
				index = index + 1,
				stack = stack,
			})
		end,
	})
	return React.createElement(PageScaffold, {
		gap = listGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, 48),
		scrollBarColor = Palette.violet,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero",
				height = headerH,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1), accent = Palette.violet, background = Palette.panelRaised, padding = if stack then 14 else 16,
					reveal = headerReveal, clips = false,
				}, React.createElement(IconTile, { kind = "Forge", accent = Palette.violet, size = if stack then 48 else 56, radius = 14, position = UDim2.fromOffset(0, if stack then 4 else 18), glow = true, spin = false, reducedMotion = softMotion }),
				React.createElement(Text, { value = "FORGE PATH", size = 10, color = Palette.violet, weight = Enum.FontWeight.Heavy, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 60 else 0), sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 16) }),
				React.createElement(Text, { value = heroBlurb, size = if stack then 16 else 18, color = Palette.cream, weight = Enum.FontWeight.Heavy, fit = false, wrap = true, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 78 else 16), sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 44) }),
				React.createElement(Meter, { value = progressFrac, color = Palette.violet, reducedMotion = softMotion, shimmer = nextReady, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 114 else 56), size = UDim2.new(1, if stack then -8 else -220, 0, 8) }),
				React.createElement(Text, { value = `{claimedCount} / {totalCount} steps claimed  ·  {compactNumber(forgePath.XP)} XP banked`, size = 11, color = Palette.creamSoft, wrap = true, position = UDim2.fromOffset(if stack then 0 else 72, if stack then 126 else 70), sizeConstraint = UDim2.new(1, if stack then -8 else -220, 0, 24) }),
				not stack and React.createElement("frame", { Size = UDim2.new(0, 200, 0, 40), Position = UDim2.new(1, -200, 0.5, -20), BackgroundTransparency = 1, BorderSizePixel = 0 },
					React.createElement(Text, { value = `{compactNumber(forgePath.XP)}`, size = 26, color = Palette.violet, weight = Enum.FontWeight.Heavy, fit = true, position = UDim2.fromOffset(0, 0), sizeConstraint = UDim2.new(1, 0, 0, 32) }),
					React.createElement(Text, { value = "FORGE XP", size = 10, color = Palette.muted, weight = Enum.FontWeight.Bold, fit = true, position = UDim2.fromOffset(0, 34), sizeConstraint = UDim2.new(1, 0, 0, 14) }))),
			},
			{
				id = "spotlight",
				height = spotlightH,
				element = React.createElement(SpotlightPanel, { step = nextStep, xp = forgePath.XP, ready = nextReady, complete = pathComplete, guide = guide, onClaim = onClaim, reducedMotion = reducedMotion, stack = stack }),
			},
			{
				id = "browse",
				height = Browse.barHeight(stack, true),
				element = React.createElement(Browse.BrowseBar, {
					browse = browse,
					placeholder = "Search steps by reward or bonus",
					accent = Palette.violet,
					stack = stack,
					reducedMotion = softMotion,
					zIndex = 30,
				}),
			},
			{
				id = "steps",
				fill = true,
				minHeight = math.max(160, stepStride * 2),
				element = stepsElement,
			},
		},
	})
end
local ForgePathView = React.memo(ForgePathViewComponent, function(previous, incoming)
	local prevXp = previous.state.ForgePath and previous.state.ForgePath.XP
	local nextXp = incoming.state.ForgePath and incoming.state.ForgePath.XP
	local prevClaimed = previous.state.ForgePath and #previous.state.ForgePath.ClaimedSteps
	local nextClaimed = incoming.state.ForgePath and #incoming.state.ForgePath.ClaimedSteps
	local prevSteps = previous.config and previous.config.ForgePath and previous.config.ForgePath.Steps
	local nextSteps = incoming.config and incoming.config.ForgePath and incoming.config.ForgePath.Steps
	return previous.dispatch == incoming.dispatch and previous.reducedMotion == incoming.reducedMotion and prevXp == nextXp and prevClaimed == nextClaimed and prevSteps == nextSteps
end)
return { ForgePathView = ForgePathView }
end

__defs["ContinuumView"] = function()
return { ContinuumView = require(script.Parent.Parent.PlanningViews).NextPlan }
end

__defs["ConvergenceView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useEntrance = _motion.useEntrance
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local SECTION_LABEL_H = 28
local function ConvergenceViewReady(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local event = state.Convergence
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local now = useWallClock(event ~= nil)
	local enter = useEntrance(softMotion)
	local reveal = useStagger(0, softMotion)
	local revealTiers = useStagger(1, softMotion)
	local revealClaim = useStagger(2, softMotion)
	local revealHero = useStagger(3, softMotion)
	local revealFill = useStagger(4, softMotion)
	local convergenceSoft = softMotion or revealHero == nil or revealFill == nil
	local globalFill = math.clamp(event.GlobalContribution / math.max(1, event.GlobalTarget), 0, 1)
	local tiers = event.Tiers or {}
	local heroHeight = if stack then 226 else 198
	local tierHeight = if stack then 154 else 94
	local pageGap = 12
	local tiersH = if #tiers > 0 then #tiers * tierHeight + math.max(0, #tiers - 1) * pageGap else 0
	local claimHostRef = React.useRef(nil)
	local firstClaimTier = nil
	for _, tier in tiers do
		if tier.CanClaim then
			firstClaimTier = tier.Tier
			break
		end
	end
	React.useEffect(function()
		if firstClaimTier == nil or not UserInputService.GamepadEnabled then
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
			pcall(task.cancel, selectJob)
		end
	end, { firstClaimTier, event.EventId })
	local _exp_2 = React.createElement(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = Palette.mango,
		background = Palette.panelRaised,
		padding = 16,
		reveal = reveal,
		reducedMotion = softMotion,
		clips = false,
	}, React.createElement(Text, {
		value = "WEEKLY COOPERATIVE EVENT",
		size = 10,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, -120, 0, 16),
	}), React.createElement(Text, {
		value = event.Name,
		size = if stack then 25 else 31,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 18,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, -8, 0, 42),
	}), React.createElement(Text, {
		value = "Everyone contributes to the same weekly forge. Finish each phase together to unlock a global production boost.",
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 68),
		sizeConstraint = UDim2.new(1, -8, 0, 38),
	}), React.createElement(Badge, {
		value = event.PhaseName,
		accent = Palette.mango,
		filled = true,
		position = UDim2.new(0, 0, 1, -68),
		size = UDim2.fromOffset(112, 28),
	}), React.createElement(Text, {
		value = now:map(function(timestamp)
			return `{clockText(math.max(0, event.EndsAt - timestamp))} LEFT`
		end),
		size = 10,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(1, -150, 1, -68),
		sizeConstraint = UDim2.fromOffset(150, 28),
	}), React.createElement(Meter, {
		value = globalFill,
		color = Palette.mango,
		position = UDim2.new(0, 0, 1, -28),
		size = UDim2.new(1, 0, 0, 9),
		reducedMotion = softMotion,
		shimmer = true,
	}), React.createElement(Text, {
		value = `{compactNumber(event.GlobalContribution)} / {compactNumber(event.GlobalTarget)}  •  {string.format("%.2fx", event.ProductionMultiplier)} PRODUCTION`,
		size = 10,
		color = Palette.creamSoft,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 0, 1, -18),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	}))
	local _newValue = table.create(#tiers)
	local _callback = function(tier, index)
		local progress = math.clamp(event.PersonalContribution / math.max(1, tier.Required), 0, 1)
		local buttonColor = if tier.CanClaim then Palette.mint elseif tier.Claimed then Palette.panelSoft else Palette.violet
		local tierReveal = if tier.CanClaim then revealClaim else revealTiers
		return React.createElement(Panel, {
			key = `tier-{tier.Tier}`,
			size = UDim2.new(1, 0, 0, tierHeight),
			accent = if tier.CanClaim then Palette.mint else Palette.violet,
			padding = 13,
			layoutOrder = index,
			reveal = tierReveal,
			interactive = tier.CanClaim,
			reducedMotion = softMotion,
			clips = false,
		}, React.createElement(Text, {
			value = `TIER {tier.Tier}  •  {compactNumber(event.PersonalContribution)} / {compactNumber(tier.Required)}`,
			size = 11,
			color = if tier.CanClaim then Palette.mint else Palette.creamSoft,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 8,
			sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 19),
		}), React.createElement(Text, {
			value = formatReward(tier.Reward),
			size = 10,
			color = Palette.muted,
			fit = true,
			minSize = 8,
			position = UDim2.fromOffset(0, 25),
			sizeConstraint = UDim2.new(1, if stack then 0 else -170, 0, 18),
		}), React.createElement(Meter, {
			value = progress,
			color = if tier.CanClaim then Palette.mint else Palette.violet,
			position = if stack then UDim2.fromOffset(0, 54) else UDim2.new(0, 0, 1, -12),
			size = UDim2.new(1, if stack then 0 else -170, 0, 6),
			reducedMotion = softMotion,
			shimmer = tier.CanClaim and not softMotion,
		}), React.createElement("frame", {
			Name = "ConvergenceClaimActions",
			Size = if stack then UDim2.new(1, 0, 0, 48) else UDim2.fromOffset(150, 48),
			Position = if stack then UDim2.new(0, 0, 1, -48) else UDim2.new(1, -150, 0.5, -24),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ref = if tier.Tier == firstClaimTier then claimHostRef else nil,
		}, React.createElement(Button, {
			text = if tier.Claimed then "CLAIMED" elseif tier.CanClaim then "CLAIM" else "LOCKED",
			icon = if tier.Claimed then "Check" else "Gift",
			onClick = function()
				if tier.CanClaim then
					dispatch("ClaimConvergenceReward", {
						Tier = tier.Tier,
					})
				end
			end,
			color = buttonColor,
			textColor = if tier.CanClaim then Palette.ink else Palette.creamSoft,
			disabled = not tier.CanClaim,
			size = UDim2.fromScale(1, 1),
			reducedMotion = softMotion,
			highlight = tier.CanClaim and not softMotion,
		})))
	end
	for _k, _v in tiers do
		_newValue[_k] = _callback(_v, _k - 1, tiers)
	end
	local sections = {
		{
			id = "hero",
			height = heroHeight,
			element = _exp_2,
		},
		{
			id = "tiers-label",
			height = SECTION_LABEL_H,
			element = React.createElement(SectionLabel, {
				value = "YOUR CONTRIBUTION REWARDS",
				color = Palette.violet,
			}),
		},
	}
	if tiersH > 0 then
		table.insert(sections, {
			id = "tiers",
			height = tiersH,
			element = React.createElement("frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, React.createElement("uilistlayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, pageGap),
			}), _newValue),
		})
	end
	return React.createElement(PageScaffold, {
		gap = pageGap,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 80),
		scrollBarColor = Palette.mango,
		scrollBarThickness = 4,
		sections = sections,
	})
end
local function ConvergenceView(_param)
	local state = _param.state
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local event = state.Convergence
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local now = useWallClock(event ~= nil)
	local enter = useEntrance(softMotion)
	local reveal = useStagger(0, softMotion)
	local revealTiers = useStagger(1, softMotion)
	local revealClaim = useStagger(2, softMotion)
	local revealHero = useStagger(3, softMotion)
	local revealFill = useStagger(4, softMotion)
	local convergenceSoft = softMotion or revealHero == nil or revealFill == nil
	if event == nil then
		return React.createElement(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = Palette.mango,
			padding = 22,
			reveal = if softMotion then revealHero else enter,
			highlight = not convergenceSoft,
			reducedMotion = softMotion,
		}, React.createElement(Text, {
			value = "FORGE CONVERGENCE",
			size = 26,
			weight = Enum.FontWeight.Heavy,
		}), React.createElement(Text, {
			value = "Getting this week's shared forge ready…",
			size = 12,
			color = Palette.muted,
			position = UDim2.fromOffset(0, 42),
			sizeConstraint = UDim2.new(1, 0, 0, 30),
		}))
	end
	return React.createElement(ConvergenceViewReady, _param)
end
return {
	ConvergenceView = ConvergenceView,
}
end

__defs["BoostsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useClock = _motion.useClock
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local Icon = require(script.Parent.Parent.ArtKit)("Icon").Icon
local Audio = require(script.Parent.Parent.AudioKit)("audio").Audio
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local FlatList = require(script.Parent.Parent.LayoutKit)("virtualizedList").FlatList
local _format = require(script.Parent.Parent.CoreKit)("format")
local clockText = _format.clockText
local compactNumber = _format.compactNumber

local Browse = require(script.Parent.Parent.BrowseKit)
local h = React.createElement
local GAP = 10
local TICKS = 36
local CARD_H = 196

local function boostIconKind(boostId)
	if boostId == "DomainSurge" then
		return "Domain"
	elseif boostId == "VaultSurge" or boostId == "StarforgeFlow" or boostId == "VaultTide" then
		return "Vault"
	elseif boostId == "Hyperdrive" then
		return "World"
	end
	return "Reactor"
end

local function headline(boost)
	local production = tonumber(boost.Multiplier)
	local vault = tonumber(boost.CapacityMultiplier)
	if production ~= nil and vault ~= nil then
		return `{production}x`, `PRODUCTION · {vault}x VAULT`
	elseif production ~= nil then
		return `{production}x`, "PRODUCTION"
	elseif vault ~= nil then
		return `{vault}x`, "VAULT"
	end
	return "+", "SPECIAL"
end

-- How much a boost is worth: extra production-minutes it adds (vault boosts count at a third).
local function value(boost)
	local production = (tonumber(boost.Multiplier) or 1) - 1
	local vault = ((tonumber(boost.CapacityMultiplier) or 1) - 1) / 3
	return (production + vault) * (tonumber(boost.Duration) or 0)
end

local function Gauge(props)
	local fraction = props.fraction
	local accent = props.accent
	local size = props.size
	local spin = props.spin
	local ticks = {}
	for index = 0, TICKS - 1 do
		local threshold = index / TICKS
		ticks[`t{index}`] = h("frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * (360 / TICKS),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, h("frame", {
			Size = UDim2.fromOffset(4, math.max(8, math.floor(size * 0.09))),
			Position = UDim2.fromScale(0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = accent,
			BackgroundTransparency = fraction:map(function(f)
				return if threshold < f then 0.05 else 0.82
			end),
			BorderSizePixel = 0,
		}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))
	end
	return h("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, h("frame", {
		Size = UDim2.fromScale(0.78, 0.78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(accent, 0.78),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.35,
	}, h("uigradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), accent),
		Rotation = spin,
	}))), ticks, h("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, props.children))
end

local function ActiveReactor(props)
	local boost = props.boost
	local endsAt = props.endsAt
	local now = props.now
	local softMotion = props.softMotion
	local stack = props.stack
	local accent = boost.Color or Palette.pink
	local spin = useClock(not softMotion, 40, 360, false)
	local fraction = now:map(function(t)
		return math.clamp((endsAt - t) / math.max(1, boost.Duration), 0, 1)
	end)
	local big, small = headline(boost)
	local gaugeSize = if stack then 132 else 150
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 16,
		highlight = true,
		reducedMotion = softMotion,
		clips = false,
	}, h(Gauge, {
		fraction = fraction,
		accent = accent,
		size = gaugeSize,
		spin = spin,
		position = if stack then UDim2.new(0.5, 0, 0, 0) else UDim2.fromOffset(0, 0),
		anchorPoint = if stack then Vector2.new(0.5, 0) else nil,
	}, h(Text, {
		value = big,
		size = math.floor(gaugeSize * 0.22),
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 0.5, -math.floor(gaugeSize * 0.17)),
		sizeConstraint = UDim2.new(1, 0, 0, math.floor(gaugeSize * 0.24)),
	}), h(Text, {
		value = now:map(function(t)
			return clockText(math.max(0, endsAt - t))
		end),
		size = 12,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0, 0, 0.5, math.floor(gaugeSize * 0.08)),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})), h("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 96) else UDim2.new(1, -(gaugeSize + 20), 1, 0),
		Position = if stack then UDim2.fromOffset(0, gaugeSize + 10) else UDim2.fromOffset(gaugeSize + 20, 0),
		BackgroundTransparency = 1,
	}, h(Badge, {
		value = "RUNNING",
		accent = accent,
		filled = true,
		size = UDim2.fromOffset(96, 22),
	}), h(Text, {
		value = boost.Name,
		size = if stack then 22 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 30),
	}), h(Text, {
		value = `{big} {string.lower(small)}  ·  {boost.Description}`,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(0, 60),
		sizeConstraint = UDim2.new(1, 0, 0, 34),
	}), not stack and h("frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -14),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) }), h("frame", {
		Size = fraction:map(function(f)
			return UDim2.fromScale(f, 1)
		end),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(1, 0) })))))
end

local function IdleBay(props)
	local pick = props.pick
	local softMotion = props.softMotion
	local stack = props.stack
	if pick == nil then
		return h(Panel, {
			size = UDim2.fromScale(1, 1),
			accent = Palette.muted,
			background = Palette.panelRaised,
			padding = 16,
			clips = false,
		}, h(IconTile, {
			kind = "Boost",
			accent = Palette.muted,
			size = 48,
			radius = 14,
			spin = false,
		}), h(Text, {
			value = "The boost bay is empty",
			size = 18,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			position = UDim2.fromOffset(62, 4),
			sizeConstraint = UDim2.new(1, -62, 0, 24),
		}), h(Text, {
			value = "Win boosts from the prize wheel, daily rewards and the Shop's Daily offers.",
			size = 12,
			color = Palette.muted,
			wrap = true,
			position = UDim2.fromOffset(62, 32),
			sizeConstraint = UDim2.new(1, -62, 0, 34),
		}))
	end
	local accent = pick.boost.Color or Palette.pink
	local big, small = headline(pick.boost)
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = 16,
		highlight = true,
		reducedMotion = softMotion,
		clips = false,
	}, h(Text, {
		value = "NOTHING RUNNING · BEST PICK",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), h(IconTile, {
		kind = boostIconKind(pick.boost.Id),
		accent = accent,
		size = if stack then 52 else 64,
		radius = 16,
		glow = true,
		position = UDim2.fromOffset(0, 22),
		reducedMotion = softMotion,
	}), h(Text, {
		value = pick.boost.Name,
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(if stack then 64 else 78, 24),
		sizeConstraint = UDim2.new(1, if stack then -64 else -(78 + 220), 0, 28),
	}), h(Text, {
		value = `{big} {string.lower(small)} for {clockText(pick.boost.Duration)}  ·  {compactNumber(pick.owned)} stored`,
		size = 12,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(if stack then 64 else 78, 54),
		sizeConstraint = UDim2.new(1, if stack then -64 else -(78 + 220), 0, 32),
	}), h("frame", {
		Name = "BoostClaimActions",
		Size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(200, TapTarget),
		Position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -200, 0.5, -TapTarget / 2 + 8),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ref = props.activateHostRef,
	}, h(Button, {
		text = `FIRE {string.upper(pick.boost.Name)}`,
		icon = "Boost",
		onClick = function()
			Audio:play("boostActivate")
			props.dispatch("ActivateBoost", { Id = pick.boost.Id })
		end,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		highlight = true,
		reducedMotion = softMotion,
	})))
end

local function StatTile(props)
	return h("frame", {
		BackgroundColor3 = darken(props.accent, 0.78),
		BorderSizePixel = 0,
		LayoutOrder = props.order,
	}, h("uicorner", { CornerRadius = UDim.new(0, 12) }), h("uistroke", {
		Color = props.accent,
		Transparency = 0.6,
	}), h(Text, {
		value = props.value,
		size = 18,
		color = lighten(props.accent, 0.12),
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(12, 8),
		sizeConstraint = UDim2.new(1, -24, 0, 24),
	}), h(Text, {
		value = props.label,
		size = 10,
		color = props.accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(12, 34),
		sizeConstraint = UDim2.new(1, -24, 0, 14),
	}))
end

local function BoostCard(props)
	local boost = props.boost
	local owned = props.owned
	local softMotion = props.softMotion
	local reveal = useStagger(props.index, softMotion)
	local ready = owned > 0 and props.canActivate
	local accent = boost.Color or Palette.pink
	local shown = if owned > 0 then accent else Palette.muted
	local big, small = headline(boost)
	return h(Panel, {
		size = UDim2.fromScale(1, 1),
		accent = shown,
		background = Palette.panelRaised,
		padding = 0,
		reveal = reveal,
		interactive = true,
		highlight = ready,
		reducedMotion = softMotion,
		clips = false,
	}, h("frame", {
		Name = "Band",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = darken(shown, if owned > 0 then 0.45 else 0.75),
		BorderSizePixel = 0,
	}, h("uicorner", { CornerRadius = UDim.new(0, Layout.cardRadius or 14) }), h("uigradient", {
		Color = ColorSequence.new(darken(shown, 0.3), darken(shown, 0.75)),
		Rotation = 20,
	}), h(Icon, {
		kind = boostIconKind(boost.Id),
		color = Palette.cream,
		accent = shown,
		size = 30,
		position = UDim2.fromOffset(14, 14),
		spin = false,
	}), h(Text, {
		value = big,
		size = 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0, 0, 0, 6),
		sizeConstraint = UDim2.new(1, -14, 0, 30),
	}), h(Text, {
		value = small,
		size = 10,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = true,
		minSize = 8,
		position = UDim2.new(0, 56, 0, 36),
		sizeConstraint = UDim2.new(1, -70, 0, 14),
	})), h(Text, {
		value = boost.Name,
		size = 16,
		color = if owned > 0 then Palette.cream else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(14, 66),
		sizeConstraint = UDim2.new(1, -110, 0, 20),
	}), h(Badge, {
		value = if owned > 0 then `×{compactNumber(owned)}` else "NONE",
		accent = if owned > 0 then accent else Palette.lineSoft,
		filled = owned > 0,
		size = UDim2.fromOffset(84, 20),
		position = UDim2.new(1, -98, 0, 66),
	}), h(Text, {
		value = boost.Description,
		size = 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(14, 90),
		sizeConstraint = UDim2.new(1, -28, 0, 30),
	}), h(Text, {
		value = `Lasts {clockText(boost.Duration)}`,
		size = 11,
		color = shown,
		weight = Enum.FontWeight.Bold,
		position = UDim2.fromOffset(14, 120),
		sizeConstraint = UDim2.new(1, -28, 0, 16),
	}), h("frame", {
		Name = "BoostClaimActions",
		Size = UDim2.new(1, -28, 0, TapTarget),
		Position = UDim2.new(0, 14, 1, -(TapTarget + 12)),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ref = if ready and props.focus then props.activateHostRef else nil,
	}, h(Button, {
		text = if owned <= 0 then "NONE STORED" elseif props.canActivate then "ACTIVATE" else props.busyText,
		icon = if ready then "Boost" else "Lock",
		onClick = function()
			Audio:play("boostActivate")
			props.dispatch("ActivateBoost", { Id = boost.Id })
		end,
		color = if ready then accent else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.muted,
		size = UDim2.fromScale(1, 1),
		disabled = not ready,
		highlight = ready,
		reducedMotion = softMotion,
	})))
end

local function BoostsView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local antilag = useAntilag()
	local columns = if stack then 1 elseif viewport.width >= 1280 then 3 else 2
	local activateHostRef = React.useRef(nil)
	local now = useWallClock(true)
	local inventory = state.BoostInventory or {}
	local all = {}
	for _, definition in pairs(config.Boosts or {}) do
		table.insert(all, definition)
	end
	local activeId = (state.ActiveBoost and state.ActiveBoost.Id) or ""
	local activeEndsAt = (state.ActiveBoost and tonumber(state.ActiveBoost.EndsAt)) or 0
	local boostRunning = activeId ~= "" and activeEndsAt > workspace:GetServerTimeNow()
	local activeBoost = if boostRunning then (config.Boosts or {})[activeId] else nil
	local stored, types, bankedSeconds, bestMult = 0, 0, 0, 1
	local pick = nil
	for _, boost in all do
		local owned = math.max(0, math.floor(tonumber(inventory[boost.Id]) or 0))
		stored += owned
		if owned > 0 then
			types += 1
			bankedSeconds += owned * (tonumber(boost.Duration) or 0)
			bestMult = math.max(bestMult, tonumber(boost.Multiplier) or 1)
			if pick == nil or value(boost) > value(pick.boost) then
				pick = { boost = boost, owned = owned }
			end
		end
	end
	table.sort(all, function(a, b)
		local ao = (tonumber(inventory[a.Id]) or 0) > 0
		local bo = (tonumber(inventory[b.Id]) or 0) > 0
		if ao ~= bo then
			return ao
		end
		if value(a) ~= value(b) then
			return value(a) > value(b)
		end
		return a.Id < b.Id
	end)
	local browse = Browse.useBrowse({
		id = "Boosts",
		items = all,
		textKey = activeId,
		text = function(boost)
			return { boost.Name, boost.Description, headline(boost) }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Owned", label = "Owned", test = function(boost)
				return (tonumber(inventory[boost.Id]) or 0) > 0
			end },
			{ id = "Production", label = "Production", test = function(boost)
				return tonumber(boost.Multiplier) ~= nil
			end },
			{ id = "Vault", label = "Vault", test = function(boost)
				return tonumber(boost.CapacityMultiplier) ~= nil
			end },
		},
		sorts = {
			{ id = "Recommended", label = "Owned first" },
			{ id = "Strongest", label = "Strongest", compare = function(a, b)
				return (tonumber(a.Multiplier) or tonumber(a.CapacityMultiplier) or 1) > (tonumber(b.Multiplier) or tonumber(b.CapacityMultiplier) or 1)
			end },
			{ id = "Longest", label = "Longest", compare = function(a, b)
				return (tonumber(a.Duration) or 0) > (tonumber(b.Duration) or 0)
			end },
			{ id = "Name", label = "A to Z", compare = function(a, b)
				return tostring(a.Name) < tostring(b.Name)
			end },
		},
	})
	local filter = browse.category
	local boosts = browse.results
	local focusId = if not boostRunning and pick ~= nil then pick.boost.Id else nil
	React.useEffect(function()
		if focusId == nil or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = activateHostRef.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent ~= nil then
				GamepadNavigationService.FocusClaim(host)
			end
		end)
		return function()
			pcall(task.cancel, job)
		end
	end, { focusId, boostRunning, filter })
	local busyText = if activeBoost ~= nil then `{string.upper(activeBoost.Name)} RUNNING` else "ONE AT A TIME"
	local heroH = if activeBoost ~= nil then (if stack then 260 else 182) else (if stack then 190 else 132)
	local statsH = if stack then 128 else 60
	local rowStride = CARD_H + GAP
	local rows = {}
	local index = 1
	while index <= #boosts do
		local row = { Id = `boost-row-{filter}-{index}`, cells = {} }
		for _ = 1, columns do
			local boost = boosts[index]
			if boost == nil then
				break
			end
			table.insert(row.cells, { boost = boost, order = index - 1 })
			index += 1
		end
		table.insert(rows, row)
	end
	local gridH = math.max(rowStride, #rows * rowStride)
	local statTiles = {
		Layout = h("uigridlayout", {
			CellSize = UDim2.new(if stack then 0.5 else 0.25, -8, 0, 56),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Stored = h(StatTile, { label = "STORED", value = compactNumber(stored), accent = Palette.pink, order = 1 }),
		Types = h(StatTile, { label = "TYPES OWNED", value = `{types} / {#all}`, accent = Palette.cyan, order = 2 }),
		Banked = h(StatTile, { label = "BOOST TIME BANKED", value = `{compactNumber(math.floor(bankedSeconds / 3600))}h`, accent = Palette.mango, order = 3 }),
		Best = h(StatTile, { label = "BEST MULTIPLIER", value = `{bestMult}x`, accent = Palette.mint, order = 4 }),
	}
	local grid = if #boosts == 0 then h(Browse.NoResults, {
		browse = browse,
		noun = "boosts",
		icon = "Boost",
		filteredTitle = if filter == "Owned" then "Nothing stored" else nil,
		filteredBody = if filter == "Owned" then "Win boosts from the prize wheel and daily rewards." else nil,
		accent = Palette.cyan,
		reducedMotion = softMotion,
		size = UDim2.new(1, 0, 0, 220),
	}) else React.createElement(FlatList, {
		data = rows,
		itemHeight = rowStride,
		overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2,
		canvasTail = 8,
		embedded = true,
		Size = UDim2.new(1, 0, 0, gridH),
		scrollBarColor = Palette.pink,
		scrollBarThickness = 3,
		keyExtractor = function(row)
			return row.Id
		end,
		renderItem = function(item)
			local row = item.item
			local cells = {
				Layout = h("uigridlayout", {
					CellSize = UDim2.new(1 / columns, -math.ceil(GAP * (columns - 1) / columns), 0, CARD_H),
					CellPadding = UDim2.fromOffset(GAP, GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			for cellIndex, cell in row.cells do
				cells[cell.boost.Id] = h("frame", {
					BackgroundTransparency = 1,
					LayoutOrder = cellIndex,
				}, h(BoostCard, {
					boost = cell.boost,
					owned = math.max(0, math.floor(tonumber(inventory[cell.boost.Id]) or 0)),
					canActivate = not boostRunning,
					busyText = busyText,
					dispatch = dispatch,
					softMotion = softMotion,
					index = cell.order,
					focus = false,
					activateHostRef = activateHostRef,
				}))
			end
			return h("frame", {
				Size = UDim2.new(1, 0, 0, CARD_H),
				BackgroundTransparency = 1,
			}, cells)
		end,
	})
	return React.createElement(PageScaffold, {
		gap = if stack then 12 else Layout.panelGap,
		tailPad = scrollTail(stack, chrome.bottomSafe, if stack then 56 else 48),
		scrollBarColor = Palette.pink,
		scrollBarThickness = 4,
		sections = {
			{
				id = "hero",
				height = heroH,
				element = if activeBoost ~= nil then h(ActiveReactor, {
					boost = activeBoost,
					endsAt = activeEndsAt,
					now = now,
					softMotion = softMotion,
					stack = stack,
				}) else h(IdleBay, {
					pick = pick,
					dispatch = dispatch,
					softMotion = softMotion,
					stack = stack,
					activateHostRef = activateHostRef,
				}),
			},
			{
				id = "stats",
				height = statsH,
				element = h("frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, statTiles),
			},
			{
				id = "filters",
				height = Browse.barHeight(stack, true),
				element = h(Browse.BrowseBar, {
					browse = browse,
					placeholder = "Search boosts",
					accent = Palette.pink,
					stack = stack,
					reducedMotion = softMotion,
					zIndex = 30,
				}),
			},
			{
				id = "grid",
				height = if #boosts == 0 then 220 else gridH,
				element = grid,
			},
		},
	})
end

return {
	BoostsView = BoostsView,
}
end

__defs["WorldsView"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.Parent.MotionKit)("antilag").useAntilag
local GamepadNavigationService = require(script.Parent.Parent.CoreKit)("GamepadNavigationService")
local _motion = require(script.Parent.Parent.MotionKit)("motion")
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _ui = require(script.Parent.Parent.UiCore)("ui")
local Badge = _ui.Badge
local Button = _ui.Button
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Text = _ui.Text
local PageScaffold = require(script.Parent.Parent.LayoutKit)("pageScaffold").PageScaffold
local _theme = require(script.Parent.Parent.CoreKit)("theme")
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local _format = require(script.Parent.Parent.CoreKit)("format")
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local AppHelpers = require(script.Parent.Parent.CoreKit)("appNav").AppHelpers
local PageBoardHeights = require(script.Parent.Parent.CoreKit)("pageBoardHeights")
local Browse = require(script.Parent.Parent.BrowseKit)
local WORLD_SCAN = 600
local WORLD_RESULTS = 60

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
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local skipMotion = softMotion or layoutOrder > 4 or antilag.skipEntrance
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
		reducedMotion = softMotion,
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
		reducedMotion = softMotion,
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
	local softMotion = reducedMotion
	reducedMotion = softMotion
	local boardReveal = useStagger(0, softMotion)
	local travelReveal = useStagger(1, softMotion)
	local headerReveal = boardReveal
	local worldsHostRef = React.useRef(nil)
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = worldsHostRef.current
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
			pcall(task.cancel, selectJob)
		end
	end, { state.CurrentZone, state.Zone })
	local barH = Browse.barHeight(stack, true)
	local headerHeight = (if stack then 168 else 112) + barH + 10
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
	local worldTail = scrollTail(stack, chrome.bottomSafe, 40)
	local function resolveZone(id)
		return if config.ResolveZone ~= nil then config.ResolveZone(id) else config.Zones[id]
	end
	-- search covers the newest WORLD_SCAN worlds you can see (owned plus the next stops)
	local zoneItems = React.useMemo(function()
		local list = {}
		for id = math.max(1, total - WORLD_SCAN + 1), total do
			local zone = resolveZone(id)
			if zone ~= nil then
				table.insert(list, zone)
			end
		end
		return list
	end, { total })
	local browse = Browse.useBrowse({
		id = "Worlds",
		items = zoneItems,
		text = function(zone)
			return { zone.Name, zone.Tagline, table.concat(zone.Features or {}, " "), zone.Description, `world {zone.Id}` }
		end,
		categories = {
			{ id = "All", label = "All" },
			{ id = "Owned", label = "Owned", test = function(zone)
				return state.Zone >= zone.Id
			end },
			{ id = "Locked", label = "Next stops", test = function(zone)
				return state.Zone < zone.Id
			end },
			{ id = "Current", label = "Current", test = function(zone)
				return state.CurrentZone == zone.Id
			end },
		},
		sorts = {
			{ id = "Order", label = "World order" },
			{ id = "Newest", label = "Newest first", compare = function(a, b)
				return a.Id > b.Id
			end },
			{ id = "Multiplier", label = "Best multiplier", compare = function(a, b)
				return (tonumber(a.Multiplier) or 0) > (tonumber(b.Multiplier) or 0)
			end },
			{ id = "Name", label = "A to Z", compare = function(a, b)
				return tostring(a.Name) < tostring(b.Name)
			end },
		},
	})
	local browsing = browse.filtered or browse.sort ~= "Order"
	local function worldRow(zone, localOrder)
		local unlocked = state.Zone >= zone.Id
		local rebirthOk = state.Rebirths >= zone.RequiredRebirths
		local coresOk = state.Cores >= zone.CoreCost
		local cashOk = gteFlux(state.Cash, zone.Cost)
		local canUnlock = not unlocked and zone.Id == state.Zone + 1 and rebirthOk and coresOk and cashOk
		return React.createElement(WorldRow, {
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
	end
	local rows = {}
	if browsing then
		for order, zone in browse.results do
			if order > WORLD_RESULTS then
				break
			end
			table.insert(rows, worldRow(zone, order))
		end
		shownCount = #rows
		canShowMore = false
	else
		for index = range.start, rangeEnd - 1 do
			local zone = resolveZone(index + 1)
			if zone ~= nil then
				table.insert(rows, worldRow(zone, index - range.start + 1))
			end
		end
	end
	local gridRows = math.ceil(math.max(1, shownCount) / worldColumns)
	local rowsHeight = math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap)
	if browsing and #rows == 0 then
		rows = { React.createElement(Browse.NoResults, {
			key = "none",
			browse = browse,
			noun = "worlds",
			icon = "World",
			accent = Palette.mint,
			reducedMotion = softMotion,
			size = UDim2.new(1, 0, 0, rowHeight),
		}) }
	end
	local rowsBlock = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, math.max(rowHeight, gridRows * (rowHeight + rowGap) - rowGap)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
	}, (if worldColumns > 1 then React.createElement("uigridlayout", {
		CellSize = UDim2.new(1 / worldColumns, -math.ceil(rowGap * (worldColumns - 1) / worldColumns), 0, rowHeight),
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
		reducedMotion = softMotion,
		highlight = not softMotion and travelReveal ~= nil,
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
		onClick = function()
			browse.reset()
			browse.setSort("Order")
			jumpToCurrent()
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, 42),
		hug = true,
		reducedMotion = softMotion,
	})), stack and React.createElement(Button, {
		text = "FIND CURRENT",
		icon = "Search",
		onClick = function()
			browse.reset()
			browse.setSort("Order")
			jumpToCurrent()
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -(TapTarget + 8 + barH + 10)),
		reducedMotion = softMotion,
	}), React.createElement(Browse.BrowseBar, {
		browse = browse,
		placeholder = "Search worlds by name or feature",
		accent = Palette.mint,
		stack = stack,
		reducedMotion = softMotion,
		position = UDim2.new(0, 0, 1, -barH),
		zIndex = 30,
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
				reducedMotion = softMotion,
				outline = true,
			})),
		})
	end
	return React.createElement("frame", {
		ref = worldsHostRef,
		Name = "WorldsTravelClaim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(PageScaffold, {
		hostRef = scrollRef,
		gap = rowGap,
		tailPad = worldTail + listPad,
		scrollBarColor = Palette.mint,
		scrollBarThickness = 4,
		sections = sections,
	}))
end
return {
	WorldsView = WorldsView,
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
