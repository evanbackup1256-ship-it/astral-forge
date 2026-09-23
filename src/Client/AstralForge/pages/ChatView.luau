local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local _AnimatedTitle = require(script.Parent.Parent.AnimatedTitle)
local AnimatedTitle = _AnimatedTitle.AnimatedTitle
local titleFxAccent = _AnimatedTitle.titleFxAccent
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local Audio = require(script.Parent.Parent.audio).Audio
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local _Icon = require(script.Parent.Parent.Icon)
local Icon = _Icon.Icon
local PlayerMark = _Icon.PlayerMark
local _motion = require(script.Parent.Parent.motion)
local useFlipperSpring = _motion.useFlipperSpring
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local Layout = _theme.Layout
local darken = _theme.darken
local lighten = _theme.lighten
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Text = _ui.Text
local useVirtualizedList = require(script.Parent.Parent.virtualizedList).useVirtualizedList
local ROW_HEIGHT = 98
local CARD_H = 90
local SYSTEM_CARD_H = 66
local STATUS_HEIGHT = 64
local BANNER_HEIGHT = 52
local INPUT_HEIGHT = 60
local GAP = Layout.stackGap
local SIDE_INSET = 12
local STATUS_RESERVE = 128
local NEAR_BOTTOM = 96
local TAG_COLORS = { Palette.cyan, Palette.mint, Palette.violet, Palette.mango, Palette.pink, Palette.blue }
local function userColor(userId)
	return TAG_COLORS[math.abs(userId) % #TAG_COLORS + 1]
end
local function useMessageEntrance(animate, reducedMotion)
	local shouldAnimate = React.useRef(animate and not reducedMotion)
	local live, setLive = React.useState(not shouldAnimate.current)
	React.useEffect(function()
		if not shouldAnimate.current then
			setLive(true)
			return nil
		end
		setLive(false)
		local job = task.defer(function()
			return setLive(true)
		end)
		return function()
			return task.cancel(job)
		end
	end, {})
	return useFlipperSpring(if live then 1 else 0, reducedMotion, 780, 38)
end
local function MessageRow(_param)
	local message = _param.message
	local position = _param.position
	local reducedMotion = _param.reducedMotion
	local bodySize = _param.bodySize
	local animate = _param.animate
	local rowHeight = _param.rowHeight
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	local enter = useMessageEntrance(animate, softMotion)
	local accent = if message.system then Palette.mango else userColor(message.userId)
	local pulse = usePulse(not message.system and not softMotion and antilag.tier >= 2, 2.4 + math.abs(message.userId % 5) * 0.14)
	local fade = enter:map(function(amount)
		return 1 - amount
	end)
	local cardY = if message.system then math.floor((rowHeight - SYSTEM_CARD_H) / 2) else 4
	local cardH = if message.system then SYSTEM_CARD_H else math.max(CARD_H, rowHeight - 8)
	if message.system then
		return React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, rowHeight),
			Position = position,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("frame", {
			Size = UDim2.new(1, -4, 0, cardH),
			Position = enter:map(function(amount)
				return UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 8))
			end),
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Palette.panelRaised,
			BackgroundTransparency = fade:map(function(amount)
				return 0.08 + amount * 0.92
			end),
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uiscale", {
			Scale = enter:map(function(amount)
				return 0.97 + amount * 0.03
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 12),
		}), React.createElement("uistroke", {
			Color = accent,
			Thickness = 1,
			Transparency = fade:map(function(amount)
				return 0.42 + amount * 0.58
			end),
		}), React.createElement("frame", {
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = accent,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 2),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(38, 38),
			Position = UDim2.fromOffset(14, 14),
			BackgroundColor3 = darken(accent, 0.62),
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 10),
		}), React.createElement(Icon, {
			kind = "Chat",
			color = Palette.ink,
			accent = accent,
			size = 22,
			position = UDim2.fromOffset(8, 8),
			spin = false,
		})), React.createElement(Text, {
			value = "GAME MESSAGE",
			size = 12,
			color = accent,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(64, 12),
			sizeConstraint = UDim2.new(1, -78, 0, 16),
			transparency = fade,
		}), React.createElement(Text, {
			value = message.text,
			size = bodySize,
			color = Palette.cream,
			weight = Enum.FontWeight.Medium,
			wrap = true,
			position = UDim2.fromOffset(64, 32),
			sizeConstraint = UDim2.new(1, -78, 0, 28),
			transparency = fade,
		})))
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.new(1, -4, 0, cardH),
		Position = enter:map(function(amount)
			return UDim2.fromOffset(math.round((1 - amount) * 14), cardY + math.round((1 - amount) * 10))
		end),
		BackgroundColor3 = if message.localPlayer then darken(accent, 0.88) else Palette.panel,
		BackgroundTransparency = fade:map(function(amount)
			return 0.04 + amount * 0.96
		end),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uiscale", {
		Scale = enter:map(function(amount)
			return 0.97 + amount * 0.03
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = fade:map(function(amount)
			return (if message.localPlayer then 0.32 else 0.58) + amount * 0.42
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(12, 17),
		BackgroundColor3 = darken(accent, 0.5),
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = pulse:map(function(amount)
			return 0.2 + amount * 0.4
		end),
	}), React.createElement(PlayerMark, {
		userId = message.userId,
		color = Palette.ink,
		accent = accent,
		size = 26,
		position = UDim2.fromOffset(8, 8),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Palette.green,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.ink,
		Thickness = 1,
	}))), React.createElement(Text, {
		value = message.displayName,
		size = 15,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(66, 8),
		sizeConstraint = UDim2.new(1, -(STATUS_RESERVE + 72), 0, 18),
		transparency = fade,
	}), if message.titleName ~= nil then React.createElement(AnimatedTitle, {
		text = message.titleName,
		fx = message.titleFx,
		size = 12,
		reducedMotion = reducedMotion,
		inline = true,
		position = UDim2.fromOffset(66, 28),
		sizeConstraint = UDim2.new(1, -(STATUS_RESERVE + 72), 0, 18),
		transparency = fade,
	}) else React.createElement(Text, {
		value = `@{message.username}`,
		size = 12,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(66, 28),
		sizeConstraint = UDim2.new(1, -80, 0, 16),
		transparency = fade,
	}), React.createElement(Badge, {
		value = if message.localPlayer then "YOU" else `WORLD {message.world}`,
		accent = if message.titleFx ~= nil then titleFxAccent(message.titleFx) else accent,
		filled = true,
		position = UDim2.new(1, -72, 0, 10),
		size = UDim2.fromOffset(62, 26),
	}), message.titleName ~= nil and React.createElement(Text, {
		value = `@{message.username}`,
		size = 11,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(66, 46),
		sizeConstraint = UDim2.new(1, -80, 0, 14),
		transparency = fade,
	}), React.createElement(Text, {
		value = message.text,
		size = bodySize + 1,
		color = Palette.cream,
		weight = Enum.FontWeight.Medium,
		wrap = true,
		position = UDim2.fromOffset(66, if message.titleName ~= nil then 62 else 48),
		sizeConstraint = UDim2.new(1, -78, 0, math.max(if message.titleName ~= nil then 26 else 34, cardH - (if message.titleName ~= nil then 70 else 56))),
		transparency = fade,
	})))
end
local function ChatView(_param)
	local chat = _param.chat
	local reducedMotion = _param.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local bodySize = if chrome.mobile then 16 else 15
	local rowHeight = if chrome.mobile then 144 else ROW_HEIGHT
	local condensed = chrome.landscape or viewport.keyboardOpen or viewport.height < 700
	local showStatus = not condensed
	local showBanner = not condensed and viewport.height >= 760
	local chromeGap = if condensed then 6 else GAP
	local inputHeight = if condensed then 52 else INPUT_HEIGHT
	local statusHeight = if showStatus then STATUS_HEIGHT else 0
	local scrollTop = statusHeight + (if showStatus then chromeGap else 0)
	local bottomChrome = inputHeight + chromeGap + (if showBanner then BANNER_HEIGHT + chromeGap else 0)
	local scrollChrome = scrollTop + bottomChrome
	local draft, setDraft = React.useState("")
	local failure, setFailure = React.useState("")
	local viewHeight, setViewHeight = React.useState(0)
	local input = React.useRef()
	local stickBottom = React.useRef(true)
	local lastCount = React.useRef(0)
	local sendAttempt = React.useRef(0)
	local chatClaimHostRef = React.useRef(nil)
	local headerReveal = useStagger(0, reducedMotion)
	React.useEffect(function()
		return function()
			sendAttempt.current += 1
		end
	end, {})
	local enteredIds = React.useRef({})
	local count = #chat.messages
	local stackH = math.max(0, count) * rowHeight
	local topPad = if viewHeight > 0 then math.max(0, viewHeight - stackH) else 0
	local canvasH = math.max(viewHeight, stackH + topPad, 1)
	local window = useVirtualizedList(count, rowHeight, topPad, 4)
	local rendered = {}
	do
		local index = window.first
		local _shouldIncrement = false
		while true do
			if _shouldIncrement then
				index += 1
			else
				_shouldIncrement = true
			end
			if not (index <= window.last) then
				break
			end
			local message = chat.messages[index + 1]
			if message == nil then
				continue
			end
			local _current = enteredIds.current
			local _id = message.id
			local animate = not (_current[_id] ~= nil)
			if animate then
				local _current_1 = enteredIds.current
				local _id_1 = message.id
				_current_1[_id_1] = true
			end
			local _arg0 = {
				message = message,
				index = index,
				animate = animate,
			}
			table.insert(rendered, _arg0)
		end
	end
	-- chat.messages is capped at MAX_MESSAGES and evicts from the front, but this Set only
	-- ever grew — over a long session it silently accumulated one entry per message ever
	-- seen. Drop anything no longer in the live list so it stays bounded to the same size.
	-- ▼ ReadonlySet.size ▼
	local _size = 0
	for _ in enteredIds.current do
		_size += 1
	end
	-- ▲ ReadonlySet.size ▲
	if _size > count + 8 then
		local live = {}
		for _, message in chat.messages do
			local _id = message.id
			live[_id] = true
		end
		enteredIds.current = live
	end
	local scrollToBottom = React.useCallback(function(force)
		task.defer(function()
			local frame = window.frame.current
			if not frame then
				return nil
			end
			if force ~= true and not stickBottom.current then
				return nil
			end
			local bottom = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			frame.CanvasPosition = Vector2.new(0, bottom)
			stickBottom.current = true
		end)
	end, { window.frame })
	React.useEffect(function()
		local frame = window.frame.current
		if not frame then
			return nil
		end
		local syncSize = function()
			return setViewHeight(math.max(0, frame.AbsoluteWindowSize.Y))
		end
		syncSize()
		local sizeConn = frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(syncSize)
		local scrollConn = frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			local maxY = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteWindowSize.Y)
			stickBottom.current = frame.CanvasPosition.Y >= maxY - NEAR_BOTTOM
		end)
		return function()
			sizeConn:Disconnect()
			scrollConn:Disconnect()
		end
	end, { window.frame })
	React.useEffect(function()
		if count > lastCount.current then
			scrollToBottom()
		end
		lastCount.current = count
	end, { count, scrollToBottom })
	React.useEffect(function()
		scrollToBottom(true)
	end, { scrollToBottom })
	local submit = function()
		local box = input.current
		local outgoing = if box ~= nil then box.Text else draft
		if (string.gsub(outgoing, "%s", "")) == "" then
			return nil
		end
		local attempt = sendAttempt.current + 1
		sendAttempt.current = attempt
		setFailure("")
		setDraft("")
		if box ~= nil then
			box.Text = ""
			task.defer(function()
				if input.current == box then
					box:CaptureFocus()
				end
			end)
		end
		stickBottom.current = true
		chat.send(outgoing, function(ok, reason)
			if attempt ~= sendAttempt.current then
				return nil
			end
			if ok then
				setFailure("")
				scrollToBottom(true)
			else
				local restore = input.current
				if restore ~= nil then
					if (string.gsub(restore.Text, "%s", "")) == "" then
						restore.Text = outgoing
						setDraft(outgoing)
					end
				else
					setDraft(function(current)
						return if (string.gsub(current, "%s", "")) == "" then outgoing else current
					end)
				end
				local _condition = reason
				if _condition == nil then
					_condition = "Message not sent."
				end
				setFailure(_condition)
			end
		end)
	end
	local canSend = chat.connected and (string.gsub(draft, "%s", "")) ~= ""
	-- Gamepad: park Selection on SEND (FocusClaim prefers Claim-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = chatClaimHostRef.current
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
	end, { condensed, canSend })
	local statusLabel = if chat.connected then "ONLINE" else "CONNECTING"
	local statusAccent = if chat.connected then Palette.green else Palette.mango
	local bannerY = -(inputHeight + chromeGap + BANNER_HEIGHT + chromeGap)
	local inputY = -(inputHeight + chromeGap)
	local placeholder = if failure ~= "" then failure else "Say something... (/help)"
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.cardRadius),
	})
	local _exp_1 = React.createElement("uistroke", {
		Color = Palette.cyan,
		Thickness = 1,
		Transparency = 0.55,
	})
	local _exp_2 = showStatus and React.createElement("frame", {
		Size = UDim2.new(1, -SIDE_INSET * 2, 0, STATUS_HEIGHT),
		Position = UDim2.fromOffset(SIDE_INSET, 0),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.5,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = Palette.cyan,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.fromOffset(14, 11),
		BackgroundColor3 = darken(Palette.cyan, 0.72),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.cyan, 0.15), darken(Palette.cyan, 0.45)),
		Rotation = 120,
	}), React.createElement(Icon, {
		kind = "Chat",
		color = Palette.ink,
		accent = Palette.cyan,
		size = 26,
		position = UDim2.fromOffset(8, 8),
		spin = false,
		reducedMotion = reducedMotion,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -(STATUS_RESERVE + 68), 0, 48),
		Position = UDim2.fromOffset(68, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement(Text, {
		value = "Chat",
		size = 18,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 24),
		transparency = headerReveal:map(function(amount)
			return 1 - amount
		end),
	}), React.createElement(Text, {
		value = `{count} log{if count == 1 then "" else "s"}  ·  Roblox-filtered`,
		size = 13,
		color = Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 28),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})), React.createElement(Badge, {
		value = statusLabel,
		accent = statusAccent,
		filled = true,
		position = UDim2.new(1, -(STATUS_RESERVE - 4), 0.5, -13),
		size = UDim2.fromOffset(STATUS_RESERVE - 16, 26),
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#rendered)
	local _callback = function(_param_1)
		local message = _param_1.message
		local index = _param_1.index
		local animate = _param_1.animate
		return React.createElement(MessageRow, {
			key = message.id,
			message = message,
			position = UDim2.fromOffset(0, topPad + index * rowHeight),
			reducedMotion = reducedMotion,
			bodySize = bodySize,
			animate = animate,
			rowHeight = rowHeight,
		})
	end
	for _k, _v in rendered do
		_newValue[_k] = _callback(_v, _k - 1, rendered)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, React.createElement("scrollingframe", {
		ref = window.frame,
		Size = UDim2.new(1, -SIDE_INSET * 2, 1, -scrollChrome),
		Position = UDim2.fromOffset(SIDE_INSET, scrollTop),
		CanvasSize = UDim2.new(0, 0, 0, canvasH),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingEnabled = true,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Palette.cyan,
		ScrollBarImageTransparency = 0.12,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 10,
	}, _newValue), showBanner and React.createElement("frame", {
		Size = UDim2.new(1, -SIDE_INSET * 2, 0, BANNER_HEIGHT),
		Position = UDim2.new(0, SIDE_INSET, 1, bannerY),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, Layout.cardRadius),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 1,
		Transparency = 0.32,
	}), React.createElement("frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 2),
	})), React.createElement(Icon, {
		kind = "Forge",
		color = Palette.ink,
		accent = Palette.mango,
		size = 24,
		position = UDim2.fromOffset(14, 14),
		spin = false,
		reducedMotion = reducedMotion,
	}), React.createElement(Text, {
		value = "KEEP IT CLEAN",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(48, 8),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
	}), React.createElement(Text, {
		value = "Roblox filters messages. Type /help for shortcuts.",
		size = 13,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(48, 28),
		sizeConstraint = UDim2.new(1, -60, 0, 16),
	})), React.createElement("frame", {
		Size = UDim2.new(1, -SIDE_INSET * 2, 0, inputHeight),
		Position = UDim2.new(0, SIDE_INSET, 1, inputY),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		Color = if failure ~= "" then Palette.coral else Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.45,
	}), React.createElement("textbox", {
		ref = input,
		Size = UDim2.new(1, -148, 1, -14),
		Position = UDim2.fromOffset(14, 7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Text = draft,
		PlaceholderText = placeholder,
		PlaceholderColor3 = if failure ~= "" then Palette.coral else Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 16,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextScaled = false,
		MultiLine = false,
		TextEditable = true,
		MaxVisibleGraphemes = 160,
		Change = {
			Text = function(box)
				return setDraft(string.sub(box.Text, 1, 160))
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
			FocusLost = function(_box, enterPressed)
				if enterPressed then
					submit()
				end
			end,
		},
	}), React.createElement("frame", {
		Name = "ChatClaimActions",
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = chatClaimHostRef,
	}, React.createElement(Button, {
		text = "SEND",
		icon = "Send",
		onClick = submit,
		color = Palette.cyan,
		textColor = Palette.ink,
		size = UDim2.fromOffset(0, 48),
		hug = true,
		disabled = not canSend,
		reducedMotion = reducedMotion,
		highlight = canSend,
	}))))
end
return {
	ChatView = ChatView,
}
