local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Audio = require(script.Parent.Parent.audio).Audio
local formatReward = require(script.Parent.Parent.format).formatReward
local Icon = require(script.Parent.Parent.Icon).Icon
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _motion = require(script.Parent.Parent.motion)
local useFlipperSpring = _motion.useFlipperSpring
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local darken = _theme.darken
local TapTarget = _theme.TapTarget
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local Text = _ui.Text
local measureWrappedTextHeight = _ui.measureWrappedTextHeight
local ScriptedText = require(script.Parent.Parent.RichTextHost).ScriptedText
local LIST_HEADER = 72
local LIST_CARD = 124
local LIST_CARD_MOBILE = 132
local LIST_GAP = 10
local DETAIL_HEADER = 96
local FOOTER_HEIGHT = 84
local FOOTER_HEIGHT_MOBILE = 168
local BODY_PAD = 12
local BODY_TOP = DETAIL_HEADER + BODY_PAD
-- Was a crude character-count bucket (<=80 chars -> 38px, <=160 -> 58px, else 80px) that ignored
-- actual rendered width, font size, and real wrap points -- silently too short for a paragraph
-- full of long words that wrap early, or wasteful for one that happens to wrap late. Now measures
-- the real wrapped height at the paragraph's actual on-screen width via TextService, matching the
-- exact size/weight the <Text> below it renders with.
local function paragraphHeight(value, width, size)
	return math.max(20, measureWrappedTextHeight(value, width, size, Enum.FontWeight.Regular) + 4)
end
local function MailRow(_param)
	local item = _param.item
	local active = _param.active
	local unread = _param.unread
	local cardH = _param.cardH
	local stack = _param.stack
	local reducedMotion = _param.reducedMotion
	local layoutOrder = _param.layoutOrder
	local onChoose = _param.onChoose
	local reveal = useStagger(layoutOrder, reducedMotion)
	return React.createElement("imagebutton", {
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, -4, 0, cardH),
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BackgroundColor3 = if active then item.Color:Lerp(Palette.panelRaised, 0.82) else Palette.panelRaised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = true,
		ClipsDescendants = false,
		Event = {
			Activated = function()
				return onChoose(item.Id)
			end,
			MouseEnter = function()
				return Audio:play("hover")
			end,
			SelectionGained = function()
				return Audio:play("hover")
			end,
		},
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if active or unread then item.Color else Palette.lineSoft,
		Thickness = 1,
		Transparency = if active then 0.16 elseif unread then 0.38 else 0.7,
	}), unread and React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -18),
		Position = UDim2.fromOffset(0, 9),
		BackgroundColor3 = item.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(TapTarget, TapTarget),
		Position = UDim2.fromOffset(12, math.floor((cardH - TapTarget) / 2)),
		BackgroundColor3 = item.Color,
		BackgroundTransparency = if unread then 0.08 else 0.8,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement(Icon, {
		kind = "Mail",
		color = if unread then Palette.ink else Palette.creamSoft,
		accent = item.Color,
		size = 26,
		position = UDim2.fromOffset(11, 11),
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -80, 1, -16),
		Position = UDim2.fromOffset(72, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = item.Subject,
		size = if stack then 15 else 14,
		color = Palette.cream,
		weight = if unread then Enum.FontWeight.Heavy else Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		sizeConstraint = UDim2.new(1, -14, 0, 22),
	}), React.createElement(Text, {
		value = item.Sender,
		size = 13,
		color = item.Color,
		weight = Enum.FontWeight.Bold,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(0, 26),
		sizeConstraint = UDim2.new(1, -14, 0, 18),
	}), React.createElement(Text, {
		value = item.Preview,
		size = 12,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 48),
		sizeConstraint = UDim2.new(1, -10, 0, 52),
	})), unread and React.createElement("frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(1, -18, 0, 14),
		BackgroundColor3 = item.Color,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function MailboxView(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local mountedRef = React.useRef(true)
	React.useEffect(function()
		return function()
			mountedRef.current = false
		end
	end, {})
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local stack = chrome.contentStack
	local mobileRoute = chrome.mobile
	local compactChrome = chrome.landscape or viewport.keyboardOpen or viewport.height < 700
	local listHeaderH = if compactChrome then 56 else LIST_HEADER
	local detailHeaderH = if compactChrome then 56 else DETAIL_HEADER
	local detailBodyTop = detailHeaderH + BODY_PAD
	local cardH = if stack then LIST_CARD_MOBILE else LIST_CARD
	local footerH = if stack then FOOTER_HEIGHT_MOBILE else FOOTER_HEIGHT
	local rowStride = cardH + LIST_GAP
	local _result = state.Mailbox
	if _result ~= nil then
		_result = _result.Messages
	end
	local _condition = _result
	if _condition == nil then
		_condition = {}
	end
	local messages = _condition
	local inboxRows = {}
	for _, mailState in messages do
		local mailDef
		for _, value in config.Mail do
			if value.Id == mailState.Id then
				mailDef = value
				break
			end
		end
		if mailDef ~= nil then
			table.insert(inboxRows, {
				Id = mailDef.Id,
				item = mailDef,
				mailState = mailState,
			})
		end
	end
	local _result_1 = state.Mailbox
	if _result_1 ~= nil then
		_result_1 = _result_1.Unread
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 0
	end
	local unreadCount = _condition_1
	-- ▼ ReadonlyArray.reduce ▼
	local _result_2 = 0
	local _callback = function(count, item)
		return count + (if item.Claimed then 0 else 1)
	end
	for _i = 1, #messages do
		_result_2 = _callback(_result_2, messages[_i], _i - 1, messages)
	end
	-- ▲ ReadonlyArray.reduce ▲
	local claimableCount = _result_2
	local _result_3 = messages[1]
	if _result_3 ~= nil then
		_result_3 = _result_3.Id
	end
	local _condition_2 = _result_3
	if _condition_2 == nil then
		_condition_2 = ""
	end
	local firstId = _condition_2
	local selectedId, setSelectedId = React.useState(if mobileRoute then "" else firstId)
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(item)
		return item.Id == selectedId
	end
	local _result_4
	for _i, _v in messages do
		if _callback_1(_v, _i - 1, messages) == true then
			_result_4 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local explicitSelection = _result_4
	local selectedState = explicitSelection or (if mobileRoute then nil else messages[1])
	local _exp = config.Mail
	-- ▼ ReadonlyArray.find ▼
	local _callback_2 = function(item)
		local _exp_1 = item.Id
		local _result_5 = selectedState
		if _result_5 ~= nil then
			_result_5 = _result_5.Id
		end
		return _exp_1 == _result_5
	end
	local _result_5
	for _i, _v in _exp do
		if _callback_2(_v, _i - 1, _exp) == true then
			_result_5 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local message = _result_5
	-- Matches detailPane's own Size formula below exactly (mobileRoute/stack: full width;
	-- otherwise 0.66 scale minus the 7px gap) so the measured height reflects the real width the
	-- paragraph actually wraps at, then subtracts the Text element's own -8 offset inset.
	local detailPaneWidth = if mobileRoute or stack then viewport.width else viewport.width * 0.66 - 7
	local paragraphWidth = math.max(40, detailPaneWidth - 8)
	local bodyTextSize = if stack then 16 else 15
	local _result_6 = message
	if _result_6 ~= nil then
		local _exp_1 = _result_6.Body
		-- ▼ ReadonlyArray.reduce ▼
		local _result_7 = 0
		local _callback_3 = function(total, paragraph)
			return total + paragraphHeight(paragraph, paragraphWidth, bodyTextSize)
		end
		for _i = 1, #_exp_1 do
			_result_7 = _callback_3(_result_7, _exp_1[_i], _i - 1, _exp_1)
		end
		-- ▲ ReadonlyArray.reduce ▲
		_result_6 = _result_7
	end
	local _condition_3 = _result_6
	if _condition_3 == nil then
		_condition_3 = 0
	end
	local bodyHeight = _condition_3
	local bodyGaps = if message ~= nil then math.max(0, #message.Body - 1) * 8 else 0
	local detailCanvas = bodyHeight + bodyGaps + BODY_PAD + footerH + 8
	local _result_7 = selectedState
	if _result_7 ~= nil then
		_result_7 = _result_7.Claimed
	end
	local claimed = _result_7 == true
	local inboxEmpty = #inboxRows == 0
	local showMobileDetail = mobileRoute and explicitSelection ~= nil
	-- Mobile swaps the whole list<->detail pane on tap instead of showing both side by side; a
	-- flat Visible toggle snapped between them with no transition at all. Slide+fade both panes
	-- off one spring keyed on the same boolean so they cross-fade instead of popping.
	local detailReveal = useFlipperSpring(if showMobileDetail then 1 else 0, reducedMotion, 720, 40)
	local _exp_1 = function()
		if not explicitSelection or explicitSelection.Read then
			return nil
		end
		dispatch("ReadMail", {
			Id = explicitSelection.Id,
		})
	end
	local _result_8 = explicitSelection
	if _result_8 ~= nil then
		_result_8 = _result_8.Id
	end
	local _result_9 = explicitSelection
	if _result_9 ~= nil then
		_result_9 = _result_9.Read
	end
	React.useEffect(_exp_1, { _result_8, _result_9 })
	local choose = function(id)
		if id == selectedId then
			return nil
		end
		Audio:play("mailRead")
		setSelectedId(id)
	end
	local listPanePosition = if mobileRoute then detailReveal:map(function(amount)
		return UDim2.new(-math.clamp(amount, 0, 1), 0, 0, 0)
	end) else nil
	local _exp_2 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_3 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.36,
	})
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, listHeaderH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(14, math.floor((listHeaderH - 36) / 2)),
		BackgroundColor3 = darken(Palette.cyan, 0.7),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Icon, {
		kind = "Mail",
		color = Palette.cream,
		accent = Palette.cyan,
		size = 24,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		reducedMotion = reducedMotion,
	})), React.createElement(Text, {
		value = "INBOX",
		size = 11,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(60, 14),
		sizeConstraint = UDim2.new(1, -180, 0, 18),
	}), React.createElement(Text, {
		value = if inboxEmpty then "No letters" else `{#inboxRows} letter{if #inboxRows == 1 then "" else "s"}`,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(60, 34),
		sizeConstraint = UDim2.new(1, -180, 0, 24),
	}), if claimableCount > 0 then React.createElement(Button, {
		text = if compactChrome then "CLAIM ALL" else `CLAIM ALL ({claimableCount})`,
		icon = "Gift",
		onClick = function()
			return dispatch("ClaimAllMail", {})
		end,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromOffset(if compactChrome then 108 else 132, TapTarget),
		position = UDim2.new(1, -(if compactChrome then 116 else 140), 0.5, -TapTarget / 2),
		reducedMotion = reducedMotion,
		highlight = true,
	}) else React.createElement(Badge, {
		value = if unreadCount > 0 then `{unreadCount} NEW` else "CAUGHT UP",
		accent = if unreadCount > 0 then Palette.coral else Palette.mint,
		filled = unreadCount > 0,
		position = UDim2.new(1, -118, 0.5, -13),
		size = UDim2.fromOffset(106, 26),
	}))
	local _result_10
	if inboxEmpty then
		_result_10 = React.createElement("frame", {
			Size = UDim2.new(1, -16, 1, -(listHeaderH + 12)),
			Position = UDim2.fromOffset(8, listHeaderH + 2),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(EmptyState, {
			icon = "Mail",
			title = "Tray empty",
			body = "Patch notes and gifts land here.",
			accent = Palette.cyan,
			size = UDim2.fromScale(1, 1),
			titleSize = 20,
			bodySize = 15,
			iconSize = 52,
			reducedMotion = reducedMotion,
		}))
	else
		local _result_11 = selectedState
		if _result_11 ~= nil then
			_result_11 = _result_11.Id
		end
		local selectedRowId = _result_11
		_result_10 = React.createElement(FlatList, {
			data = inboxRows,
			itemHeight = rowStride,
			headerHeight = 0,
			footerHeight = TapTarget + 8,
			overscan = if antilag.tier <= 1 or antilag.constrained then 1 else 2,
			canvasTail = 4,
			Size = UDim2.new(1, -20, 1, -(listHeaderH + 10)),
			Position = UDim2.fromOffset(10, listHeaderH),
			scrollBarColor = Palette.cyan,
			scrollBarThickness = 3,
			scrollBarTransparency = 0.28,
			keyExtractor = function(row)
				return row.Id
			end,
			renderItem = function(_param_1)
				local row = _param_1.item
				return React.createElement(MailRow, {
					item = row.item,
					active = row.Id == selectedRowId,
					unread = not row.mailState.Read,
					cardH = cardH,
					stack = stack,
					reducedMotion = reducedMotion,
					layoutOrder = 0,
					onChoose = choose,
				})
			end,
			ListFooterComponent = React.createElement("frame", {
				Size = UDim2.new(1, -4, 0, TapTarget),
				Position = UDim2.fromOffset(0, #inboxRows * rowStride + 4),
				BackgroundColor3 = Palette.panelRaised,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(0, 10),
			}), React.createElement(Text, {
				value = if #inboxRows == 1 then "Caught up" else "End of inbox",
				size = 13,
				color = Palette.muted,
				weight = Enum.FontWeight.Bold,
				align = Enum.TextXAlignment.Center,
				fit = false,
				sizeConstraint = UDim2.fromScale(1, 1),
			})),
		})
	end
	local listPane = React.createElement("frame", {
		Size = if mobileRoute then UDim2.fromScale(1, 1) elseif stack then UDim2.new(1, 0, 0.38, -4) else UDim2.new(0.34, -7, 1, 0),
		Position = listPanePosition,
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp_2, _exp_3, _exp_4, _result_10)
	local detailPanePosition = if mobileRoute then detailReveal:map(function(amount)
		return UDim2.new(1 - math.clamp(amount, 0, 1), 0, 0, 0)
	end) elseif stack then UDim2.new(0, 0, 0.38, 4) else UDim2.new(0.34, 7, 0, 0)
	local _exp_5 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _attributes = {}
	local _result_11 = message
	if _result_11 ~= nil then
		_result_11 = _result_11.Color
	end
	local _condition_4 = _result_11
	if _condition_4 == nil then
		_condition_4 = Palette.lineSoft
	end
	_attributes.Color = _condition_4
	_attributes.Thickness = 1
	_attributes.Transparency = 0.45
	local _exp_6 = React.createElement("uistroke", _attributes)
	local _exp_7 = message == nil and React.createElement("frame", {
		Size = UDim2.new(1, -40, 1, -40),
		Position = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(EmptyState, {
		icon = "Mail",
		title = "Inbox empty",
		body = "Patch notes, letters, and gifts land here.",
		accent = Palette.cyan,
		size = UDim2.fromScale(1, 1),
		titleSize = 24,
		bodySize = 16,
		iconSize = 64,
		reducedMotion = reducedMotion,
	}))
	local _condition_5 = message ~= nil
	if _condition_5 then
		local _exp_8 = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, detailHeaderH),
			BackgroundColor3 = message.Color,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = 5,
		}, mobileRoute and React.createElement(Button, {
			text = "",
			icon = "Back",
			onClick = function()
				return setSelectedId("")
			end,
			color = Palette.panelSoft,
			textColor = message.Color,
			outline = true,
			size = UDim2.fromOffset(TapTarget, TapTarget),
			position = UDim2.fromOffset(8, math.floor((detailHeaderH - TapTarget) / 2)),
			reducedMotion = reducedMotion,
			zIndex = 8,
		}), not mobileRoute and React.createElement(Icon, {
			kind = "Mail",
			color = Palette.cream,
			accent = message.Color,
			size = 42,
			position = UDim2.fromOffset(18, math.floor((detailHeaderH - 42) / 2)),
			reducedMotion = reducedMotion,
		}), React.createElement(Text, {
			value = message.Subject,
			size = if compactChrome then 16 elseif stack then 18 else 20,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			minSize = 12,
			position = UDim2.fromOffset(if mobileRoute then 66 else 74, if compactChrome then 7 else 18),
			sizeConstraint = UDim2.new(1, if mobileRoute then -78 else -94, 0, if compactChrome then 22 else 30),
		}), React.createElement(Text, {
			value = `From {message.Sender}`,
			size = if compactChrome then 11 else 13,
			color = message.Color,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 9,
			position = UDim2.fromOffset(if mobileRoute then 66 else 74, if compactChrome then 30 else 54),
			sizeConstraint = UDim2.new(1, if mobileRoute then -78 elseif stack then -24 else -220, 0, 18),
		}), not stack and React.createElement(Text, {
			value = message.Date,
			size = 12,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			align = Enum.TextXAlignment.Right,
			position = UDim2.new(1, -200, 0, 56),
			sizeConstraint = UDim2.fromOffset(180, 16),
		}))
		local _exp_9 = React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
		local _exp_10 = message.Body
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_10)
		local _callback_3 = function(paragraph, index)
			return if index == 0 then React.createElement(ScriptedText, {
				key = `{message.Id}:0`,
				layoutOrder = 0,
				text = paragraph,
				width = paragraphWidth,
				height = paragraphHeight(paragraph, paragraphWidth, bodyTextSize),
				size = bodyTextSize,
				color = Palette.creamSoft,
				weight = Enum.FontWeight.SemiBold,
				typewriterInterval = 0.012,
				reducedMotion = reducedMotion,
			}) else React.createElement(Text, {
				key = index,
				layoutOrder = index,
				value = paragraph,
				size = bodyTextSize,
				color = Palette.creamSoft,
				wrap = true,
				weight = Enum.FontWeight.Regular,
				sizeConstraint = UDim2.new(1, -8, 0, paragraphHeight(paragraph, paragraphWidth, bodyTextSize)),
			})
		end
		for _k, _v in _exp_10 do
			_newValue[_k] = _callback_3(_v, _k - 1, _exp_10)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition_5 = React.createElement(React.Fragment, nil, _exp_8, React.createElement("scrollingframe", {
			key = message.Id,
			Size = UDim2.new(1, -40, 1, -(detailBodyTop + BODY_PAD)),
			Position = UDim2.fromOffset(20, detailBodyTop),
			CanvasPosition = Vector2.zero,
			CanvasSize = UDim2.new(0, 0, 0, detailCanvas),
			AutomaticCanvasSize = Enum.AutomaticSize.None,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = message.Color,
			ScrollBarImageTransparency = 0.18,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			ClipsDescendants = true,
			Active = true,
			Selectable = false,
			ZIndex = 2,
		}, _exp_9, _newValue, React.createElement("frame", {
			key = "footer",
			LayoutOrder = #message.Body + 1,
			Size = UDim2.new(1, -4, 0, footerH),
			BackgroundColor3 = Palette.panel,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			Color = Palette.lineSoft,
			Thickness = 1,
			Transparency = 0.58,
		}), React.createElement(Icon, {
			kind = "Gift",
			color = Palette.cream,
			accent = message.Color,
			size = 30,
			position = UDim2.fromOffset(14, 20),
			reducedMotion = reducedMotion,
		}), React.createElement(Text, {
			value = "ATTACHMENT",
			size = 12,
			color = message.Color,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			position = UDim2.fromOffset(56, 14),
			sizeConstraint = UDim2.new(1, if stack then -(56 + 20) else -300, 0, 16),
		}), React.createElement(Text, {
			value = formatReward(message.Attachment),
			size = 14,
			color = Palette.cream,
			weight = Enum.FontWeight.Bold,
			fit = true,
			minSize = 10,
			position = UDim2.fromOffset(56, 34),
			sizeConstraint = UDim2.new(1, if stack then -(56 + 20) else -300, 0, 22),
		}), if stack then React.createElement("frame", {
			Size = UDim2.new(1, -16, 0, TapTarget * 2 + 8),
			Position = UDim2.new(0, 8, 1, -(TapTarget * 2 + 18)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, chrome.controlGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement(Button, {
			text = if claimed then "COLLECTED" else "CLAIM",
			icon = "Gift",
			onClick = function()
				return dispatch("ClaimMail", {
					Id = message.Id,
				})
			end,
			color = if claimed then Palette.panelSoft else message.Color,
			textColor = if claimed then Palette.muted else Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			disabled = claimed,
			reducedMotion = reducedMotion,
			highlight = not claimed,
		}), React.createElement(Button, {
			text = "ARCHIVE",
			icon = "Close",
			onClick = function()
				return dispatch("DeleteMail", {
					Id = message.Id,
				}, function(response)
					if mountedRef.current and response.ok then
						setSelectedId("")
					end
				end)
			end,
			color = Palette.coral,
			textColor = if claimed then Palette.cream else Palette.muted,
			outline = true,
			size = UDim2.new(1, 0, 0, TapTarget),
			disabled = not claimed,
			reducedMotion = reducedMotion,
		})) else React.createElement("frame", {
			Size = UDim2.fromOffset(0, TapTarget),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, React.createElement("uilistlayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, Layout.controlGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}), React.createElement(Button, {
			text = if claimed then "COLLECTED" else "CLAIM",
			icon = "Gift",
			onClick = function()
				return dispatch("ClaimMail", {
					Id = message.Id,
				})
			end,
			color = if claimed then Palette.panelSoft else message.Color,
			textColor = if claimed then Palette.muted else Palette.ink,
			size = UDim2.fromOffset(0, TapTarget),
			hug = true,
			disabled = claimed,
			reducedMotion = reducedMotion,
			highlight = not claimed,
		}), React.createElement(Button, {
			text = "ARCHIVE",
			icon = "Close",
			onClick = function()
				return dispatch("DeleteMail", {
					Id = message.Id,
				}, function(response)
					if mountedRef.current and response.ok then
						setSelectedId("")
					end
				end)
			end,
			color = Palette.coral,
			textColor = if claimed then Palette.cream else Palette.muted,
			outline = true,
			size = UDim2.fromOffset(0, TapTarget),
			hug = true,
			disabled = not claimed,
			reducedMotion = reducedMotion,
		})))))
	end
	local detailPane = React.createElement("frame", {
		Size = if mobileRoute then UDim2.fromScale(1, 1) elseif stack then UDim2.new(1, 0, 0.62, -4) else UDim2.new(0.66, -7, 1, 0),
		Position = detailPanePosition,
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp_5, _exp_6, _exp_7, _condition_5)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, listPane, detailPane)
end
return {
	MailboxView = MailboxView,
}
