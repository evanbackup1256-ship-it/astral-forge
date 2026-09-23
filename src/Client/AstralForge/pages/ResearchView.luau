local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _ui = require(script.Parent.Parent.ui)
local IconTile = _ui.IconTile
local Panel = _ui.Panel
local Button = _ui.Button
local Text = _ui.Text
local Meter = _ui.Meter
local Badge = _ui.Badge
local AmountToggle = _ui.AmountToggle
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Layout = _theme.Layout
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local gteFlux = _format.gteFlux
local amountPayload = _format.amountPayload
local AppHelpers = require(script.Parent.Parent.appNav).AppHelpers
local VirtualGrid = require(script.Parent.Parent.scrolling).VirtualGrid
-- Icon + name/desc + effect line + level meter + buy button all need to fit inside the
-- padded content area (row height minus 2x the Panel's 14px padding). Desktop puts the buy
-- button/badge in its own 130px-wide right column (position 1,-140), leaving the name/desc/
-- effect/meter text a `1, -200` reservation that's still comfortably wide on any real desktop
-- window. Mobile has no such column -- name text used to keep that identical -200 reservation
-- completely unconditionally, which left as little as ~24px of actual width for the node's name
-- on a 320px phone (56px icon offset + 200px reservation already exceeds a 320px screen once
-- panel padding is subtracted). Mobile now gets a taller row with the buy control moved to a
-- full-width bar under the text instead of squeezed into the same fixed right column.
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
	local index = _binding.index
	local onBuy = _binding.onBuy
	local stack = _binding.stack
	local reveal = useStagger(math.min(index, 6), reducedMotion, 0.02, 0.14)
	local accent = entry.config.Accent or entry.config.Color
	local maxed = entry.maxed
	local ready = entry.unlocked and entry.affordable and not maxed
	local levelFrac = math.clamp(entry.level / math.max(1, entry.config.MaxLevel), 0, 1)
	local buyLabel = if not entry.unlocked then "LOCKED" elseif maxed then "MAXED" elseif ready then `BUY {compactNumber(entry.price)}` else `NEED {compactNumber(entry.price)}`
	local rowH = if stack then NODE_ROW_HEIGHT_STACK else NODE_ROW_HEIGHT
	local textReserve = if stack then 0 else -200
	-- Every row reserves CONNECTOR_HEIGHT at its top so the row stride stays uniform for
	-- VirtualGrid (which requires a fixed cellHeight) — row 0 just leaves that reserved
	-- space empty instead of omitting it, since a shorter first row would desync the
	-- virtualizer's row-index math from actual pixel offsets.
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
	return prev.entry.config == incoming.entry.config and prev.entry.level == incoming.entry.level and prev.entry.price == incoming.entry.price and prev.entry.affordable == incoming.entry.affordable and prev.entry.maxed == incoming.entry.maxed and prev.entry.unlocked == incoming.entry.unlocked and prev.entry.lockReason == incoming.entry.lockReason and prev.buyAmount == incoming.buyAmount and prev.reducedMotion == incoming.reducedMotion and prev.index == incoming.index and prev.onBuy == incoming.onBuy and prev.stack == incoming.stack
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
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local stack = chrome.contentStack
	local scrollRef = React.useRef()
	local buyAllHostRef = React.useRef(nil)
	local entries = React.useMemo(function()
		return AppHelpers:buildUpgradeEntries(config.Research, state.Research, state)
	end, { config.Research, state.Research, state.Zone, state.Rebirths })
	-- ▼ ReadonlyArray.reduce ▼
	local _result = 0
	local _callback = function(sum, entry)
		return sum + (if entry.unlocked then 1 else 0)
	end
	for _i = 1, #entries do
		_result = _callback(_result, entries[_i], _i - 1, entries)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local unlockedCount = _result
	-- ▼ ReadonlyArray.reduce ▼
	local _result_1 = 0
	local _callback_1 = function(sum, entry)
		return sum + (if entry.maxed then 1 else 0)
	end
	for _i = 1, #entries do
		_result_1 = _callback_1(_result_1, entries[_i], _i - 1, entries)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local maxedCount = _result_1
	-- ▼ ReadonlyArray.find ▼
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
	-- ▲ ReadonlyArray.find ▲
	local nextEntry = _result_2
	local onBuy = React.useCallback(function(id)
		return dispatch("BuyResearch", {
			Id = id,
			Amount = amountPayload(buyAmount),
		})
	end, { dispatch, buyAmount })
	local onBuyAll = function()
		-- ▼ ReadonlyArray.forEach ▼
		local _callback_3 = function(entry)
			if entry.unlocked and not entry.maxed and gteFlux(state.Cash, entry.price) then
				dispatch("BuyResearch", {
					Id = entry.config.Id,
					Amount = "Max",
				})
			end
		end
		for _k, _v in entries do
			_callback_3(_v, _k - 1, entries)
		end
		-- ▲ ReadonlyArray.forEach ▲
	end
	-- Gamepad: park Selection on BUY ALL when any research line is affordable.
	local canBuyAll = nextEntry ~= nil and gteFlux(state.Cash, nextEntry.price)
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
			task.cancel(selectJob)
		end
	end, { canBuyAll, buyAmount, unlockedCount })
	local headerReveal = useStagger(0, softMotion)
	local listGap = if stack then chrome.panelGap else Layout.panelGap
	-- Stack mode header padding is 14, and the AmountToggle row sits at y=132 with height
	-- TapTarget(48), ending at 180 — needs 180 + 28 = 208. Non-stack ends its content at
	-- y=88 (56 label offset + 32 line height) with padding 16, needing 88 + 32 = 120; the
	-- side controls (BUY ALL button ends at 56+32=88) fit the same bound.
	local headerH = if stack then 208 else 128
	local chainCount = #entries
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
					reveal = headerReveal,
					clips = false,
				}, React.createElement(IconTile, {
					kind = "Research",
					accent = Palette.cyan,
					size = if stack then 48 else 56,
					radius = 14,
					position = UDim2.fromOffset(0, if stack then 4 else 18),
					glow = true,
					spin = false,
					reducedMotion = reducedMotion,
				}), React.createElement(Text, {
					value = "RESEARCH CHAIN",
					size = 10,
					color = Palette.cyan,
					weight = Enum.FontWeight.Heavy,
					position = UDim2.fromOffset(if stack then 0 else 72, if stack then 60 else 0),
					sizeConstraint = UDim2.new(1, if stack then -8 else -260, 0, 16),
				}), React.createElement(Text, {
					value = "Permanent upgrades. They stick through rebirths.",
					size = if stack then 18 else 24,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					position = UDim2.fromOffset(if stack then 0 else 72, if stack then 78 else 18),
					sizeConstraint = UDim2.new(1, if stack then -8 else -260, 0, 32),
				}), React.createElement(Text, {
					value = `{unlockedCount} / {#entries} unlocked  ·  {maxedCount} maxed{if nextEntry ~= nil then `  ·  next: {nextEntry.config.Name}` else ""}`,
					size = 11,
					color = Palette.creamSoft,
					wrap = true,
					position = UDim2.fromOffset(if stack then 0 else 72, if stack then 108 else 56),
					sizeConstraint = UDim2.new(1, if stack then -8 else -260, 0, 24),
				}), not stack and React.createElement(React.Fragment, nil, React.createElement(AmountToggle, {
					value = buyAmount,
					onChange = setBuyAmount,
					accent = Palette.cyan,
					position = UDim2.new(1, -240, 0, 16),
					size = UDim2.fromOffset(240, 32),
					reducedMotion = reducedMotion,
				}), React.createElement("frame", {
					-- FocusClaim prefers Buy-named hosts for research bulk purchase.
					Name = "ResearchBuyClaimActions",
					Size = UDim2.fromOffset(240, 32),
					Position = UDim2.new(1, -240, 0, 56),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ref = if canBuyAll then buyAllHostRef else nil,
				}, React.createElement(Button, {
					text = "BUY ALL AFFORDABLE",
					icon = "Flux",
					onClick = onBuyAll,
					color = Palette.cyan,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					highlight = true,
				}))), stack and React.createElement(React.Fragment, nil, React.createElement(AmountToggle, {
					value = buyAmount,
					onChange = setBuyAmount,
					accent = Palette.cyan,
					position = UDim2.new(0, 0, 0, 132),
					size = UDim2.new(1, -(TapTarget + 8), 0, TapTarget),
					reducedMotion = reducedMotion,
				}), React.createElement("frame", {
					Name = "ResearchBuyClaimActions",
					Size = UDim2.fromOffset(TapTarget, TapTarget),
					Position = UDim2.new(1, -TapTarget, 0, 132),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ref = if canBuyAll then buyAllHostRef else nil,
				}, React.createElement(Button, {
					text = "ALL",
					icon = "Flux",
					onClick = onBuyAll,
					color = Palette.cyan,
					textColor = Palette.ink,
					size = UDim2.fromScale(1, 1),
					reducedMotion = reducedMotion,
					highlight = true,
				})))),
			},
			{
				id = "chain",
				height = chainH,
				element = React.createElement(VirtualGrid, {
					scrollRef = scrollRef,
					count = chainCount,
					columns = 1,
					cellHeight = rowStride,
					gap = 0,
					overscanRows = 2,
					itemKey = function(index)
						return entries[index + 1].config.Id
					end,
					renderItem = function(index)
						return React.createElement(ResearchNode, {
							entry = entries[index + 1],
							buyAmount = buyAmount,
							reducedMotion = reducedMotion,
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
