local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _format = require(script.Parent.Parent.format)
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local formatReward = _format.formatReward
local _motion = require(script.Parent.Parent.motion)
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local scrollTail = _theme.scrollTail
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local IconTile = _ui.IconTile
local Meter = _ui.Meter
local meterFill = _ui.meterFill
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local SCROLL_EDGE = _ui.SCROLL_EDGE
local ORDER_HEIGHT = 156
local ORDER_HEIGHT_STACK = 224
local ORDER_GAP = Layout.panelGap
local CHANNEL_IDS = { "Production", "Storage", "Tap" }
local SCROLL_PAD = 28 + 16
local BTN_W = 168
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
	local reveal = useStagger(order, reducedMotion)
	local rowH = if stack then ORDER_HEIGHT_STACK else ORDER_HEIGHT
	local pad = if stack then 14 else 16
	local contentH = rowH - pad * 2
	local btnReserve = if stack then TapTarget + 14 else 0
	local meterY = if stack then contentH - btnReserve - 8 else 112
	local progressY = meterY - 18
	local meterSize = if stack then UDim2.new(1, 0, 0, 8) else UDim2.new(1, -(BTN_W + ROW_RIGHT + 12), 0, 8)
	local textW = if stack then -(58 + 12) else -(BTN_W + 74 + ROW_RIGHT)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, rowH),
		accent = config.Color,
		background = Palette.panel,
		padding = pad,
		layoutOrder = order,
		reveal = reveal,
		interactive = true,
		highlight = ready,
		reducedMotion = reducedMotion,
	}, React.createElement(IconTile, {
		kind = "Mission",
		accent = config.Color,
		size = 46,
		radius = 12,
		position = UDim2.fromOffset(0, if stack then 4 else 10),
		glow = ready,
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
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
		fit = false,
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
		onClick = function()
			return dispatch("ClaimLabOrder", {
				Id = state.Id,
			})
		end,
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
		onClick = function()
			return dispatch("ClaimLabOrder", {
				Id = state.Id,
			})
		end,
		color = if ready then config.Color else Palette.panelSoft,
		textColor = if ready then Palette.ink else Palette.creamSoft,
		size = UDim2.fromOffset(BTN_W, 46),
		position = UDim2.new(1, -(BTN_W + ROW_RIGHT), 0.5, -23),
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
	local half = POWER_BTN / 2
	local rowH = if stack then POWER_ROW_H_STACK else POWER_ROW_H
	local plusX = POWER_BTN + ROW_RIGHT
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
	local quietMotion = reducedMotion or antilag.skipEntrance or not antilag.allowAmbient
	local now = useWallClock(true)
	local headerReveal = useStagger(0, quietMotion)
	if lab == nil then
		return React.createElement(Panel, {
			size = UDim2.new(1, 0, 0, 160),
			accent = Palette.mint,
			background = Palette.panelRaised,
			padding = 20,
		}, React.createElement(Text, {
			value = "Lab's still loading — hang on a sec.",
			size = 15,
			color = Palette.creamSoft,
			wrap = true,
		}))
	end
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
	local guide = if config.ClientPageGuides ~= nil then config.ClientPageGuides.Lab else nil
	local orderH = if stack then ORDER_HEIGHT_STACK else ORDER_HEIGHT
	local orderBlock = if #lab.Orders > 0 then #lab.Orders * (orderH + ORDER_GAP) else 160
	local powerStride = if stack then POWER_ROW_STRIDE_STACK else POWER_ROW_STRIDE
	local powerBoardH = POWER_ROW_START + #CHANNEL_IDS * powerStride + 10 + 28
	local heroHeight = if stack then (if chrome.landscape then 168 else 196) else 156
	local canvasHeight = heroHeight + ORDER_GAP + 18 + orderBlock + 18 + powerBoardH + scrollTail(stack, chrome.bottomSafe, SCROLL_PAD) + SCROLL_EDGE
	local _exp = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ORDER_GAP),
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, SCROLL_EDGE),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = -100000,
	})
	local _exp_2 = not stack and React.createElement(IconTile, {
		kind = "Lab",
		accent = Palette.mint,
		size = 52,
		radius = 14,
		position = UDim2.fromOffset(0, 10),
		spin = false,
		glow = true,
		reducedMotion = reducedMotion,
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
		-- ▼ ReadonlyArray.filter ▼
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
		-- ▲ ReadonlyArray.filter ▲
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
		-- ▼ ReadonlyArray.filter ▼
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
		-- ▲ ReadonlyArray.filter ▲
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
		}), readyOrders > 0 and React.createElement(Button, {
			text = `CLAIM ALL · {readyOrders}`,
			icon = "Gift",
			onClick = claimAllOrders,
			color = Palette.mint,
			textColor = Palette.ink,
			size = UDim2.fromOffset(148, 36),
			position = UDim2.new(1, -(156 + ROW_RIGHT), 0, 78),
			reducedMotion = reducedMotion,
			highlight = true,
		}))
	end
	local _exp_3 = React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, heroHeight),
		accent = Palette.mint,
		background = Palette.panelRaised,
		padding = 16,
		layoutOrder = 0,
		reveal = headerReveal,
		clips = false,
	}, _exp_2, _result)
	local _exp_4 = React.createElement(SectionLabel, {
		value = "TODAY'S ORDERS",
		color = Palette.mint,
		layoutOrder = 1,
	})
	local _exp_5 = lab.Orders
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_5)
	local _callback = function(orderState, index)
		local _id = orderState.Id
		local orderConfig = orderConfigs[_id]
		return orderConfig ~= nil and React.createElement(OrderRow, {
			key = orderState.Id,
			state = orderState,
			config = orderConfig,
			dispatch = dispatch,
			reducedMotion = reducedMotion,
			order = index + 2,
			stack = stack,
		})
	end
	for _k, _v in _exp_5 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_5)
	end
	-- ▲ ReadonlyArray.map ▲
	local ordersBlock = if #lab.Orders == 0 then React.createElement(EmptyState, {
		icon = "Lab",
		title = "No orders yet",
		body = (guide and guide.EmptyOrders) or "Orders refresh at the lab reset clock.",
		accent = Palette.mint,
		layoutOrder = 2,
		reducedMotion = reducedMotion,
	}) else _newValue
	local _exp_6 = React.createElement(SectionLabel, {
		value = "POWER BOARD",
		color = Palette.mango,
		layoutOrder = 20,
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
	-- ▼ ReadonlyArray.map ▼
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
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("scrollingframe", {
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = SCROLL_BAR,
		ScrollBarImageColor3 = Palette.lineSoft,
		ScrollBarImageTransparency = 0.28,
		ClipsDescendants = true,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Active = true,
		Selectable = false,
	}, _exp, _exp_1, _exp_3, _exp_4, ordersBlock, _exp_6, React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, powerBoardH),
		accent = Palette.mango,
		background = Palette.panel,
		padding = 14,
		layoutOrder = 21,
		clips = false,
	}, _exp_7, _exp_8, _exp_9, _newValue_1), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, SCROLL_PAD),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 99,
	}))
end
return {
	LabView = LabView,
}
