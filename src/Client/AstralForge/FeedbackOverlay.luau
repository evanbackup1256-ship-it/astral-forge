local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Audio = require(script.Parent.audio).Audio
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local IconTile = _ui.IconTile
local OverlayPresence = _ui.OverlayPresence
local SegmentedTabs = _ui.SegmentedTabs
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local CATEGORIES = { "Bug", "Suggestion", "Balance", "Other" }
local function FeedbackOverlay(_param)
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — FeedbackOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local onClose = _param.onClose
	local notify = _param.notify
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local narrow = viewport.width < 620
	local compact = chrome.stack or narrow or viewport.height < 560
	local keyboardCompact = viewport.keyboardOpen or viewport.height < 240
	local wideShort = not narrow and viewport.height < 560
	local category, setCategory = React.useState("Bug")
	local message, setMessage = React.useState("")
	local sending, setSending = React.useState(false)
	local sent, setSent = React.useState(false)
	local mountedRef = React.useRef(true)
	React.useEffect(function()
		Audio:play("modalOpen")
		return function()
			mountedRef.current = false
		end
	end, {})
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local side = chrome.sideSafe + 16
	local width = math.min(if compact then viewport.width - side * 2 else 620, 620)
	local safeHeight = math.max(1, viewport.height - viewport.topInset - chrome.bottomSafe - 16)
	local height = math.min(if keyboardCompact then 210 elseif wideShort then 286 elseif compact then 420 else 448, safeHeight)
	local contentHeight = math.max(1, height - 28)
	local headerH = if keyboardCompact then 46 elseif compact then 64 else 72
	local categoryTop = headerH + (if keyboardCompact then 0 else 8)
	local categoryColumns = if narrow then 2 else 4
	local categoryH = if keyboardCompact then 0 elseif categoryColumns == 2 then 96 else 44
	local editorTop = categoryTop + categoryH + (if keyboardCompact then 6 else 10)
	local footerH = TapTarget + (if keyboardCompact then 4 else 14)
	local editorH = math.max(44, contentHeight - editorTop - footerH - 8)
	local trimmed = (string.gsub((string.gsub(message, "^%s+", "")), "%s+$", ""))
	local canSend = not sending and not sent and #trimmed >= 8
	local close = React.useCallback(function()
		if closing or sending then
			return nil
		end
		Audio:play("close")
		beginExit(onClose)
	end, { beginExit, closing, onClose, sending })
	React.useEffect(function()
		local actionName = "AstralForgeFeedbackClose"
		ContextActionService:BindActionAtPriority(actionName, function(_name, inputState)
			if inputState == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, 2400, Enum.KeyCode.ButtonB)
		return function()
			return ContextActionService:UnbindAction(actionName)
		end
	end, { close })
	React.useEffect(function()
		if not sent then
			return nil
		end
		local token = task.delay(2.4, function()
			if mountedRef.current and not closing then
				beginExit(onClose)
			end
		end)
		return function()
			return task.cancel(token)
		end
	end, { beginExit, closing, onClose, sent })
	local submit = React.useCallback(function()
		if not canSend then
			return nil
		end
		setSending(true)
		Audio:play("chatSend")
		dispatch("SubmitFeedback", {
			Category = category,
			Message = trimmed,
		}, function(response)
			if not mountedRef.current then
				return nil
			end
			setSending(false)
			if not response.ok then
				local _condition = response.error
				if _condition == nil then
					_condition = response.message
					if _condition == nil then
						_condition = "Please try again in a moment."
					end
				end
				notify("Couldn't send feedback", _condition)
				Audio:play("noticeError")
				return nil
			end
			setSent(true)
			Audio:play("reward")
			notify("Feedback sent", "Thanks for helping make the game better.")
		end)
	end, { canSend, category, dispatch, notify, trimmed })
	local padFocus = useGamepadAutofocus(true)
	local overlayHostRef = React.useRef(nil)
	React.useEffect(function()
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, {})
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current or padFocus.current
		if host == nil then
			return nil
		end
		local job = task.defer(function()
			if host.Parent == nil then
				return
			end
			GamepadNavigationService.FocusClaim(host)
		end)
		return function()
			task.cancel(job)
		end
	end, { sent })
	local cardTravel = 16
	local cardPosition = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * cardTravel))
	end)
	local scrimTransparency = motion:map(function(amount)
		return 1 - amount * 0.72
	end)
	local fade = motion:map(function(amount)
		return 1 - amount
	end)
	local cardScale = motion:map(function(amount)
		return 0.92 + amount * 0.08
	end)
	local _exp = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrimTransparency,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 470,
	})
	local _exp_1 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 471,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	}))
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 472,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if sent then Palette.mint else Palette.cyan,
		Thickness = 2,
		Transparency = motion:map(function(amount)
			return 0.55 - amount * 0.4
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(64, 2),
		Position = UDim2.fromOffset(20, 0),
		BackgroundColor3 = if sent then Palette.mint else Palette.cyan,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
	local _exp_3 = not keyboardCompact and React.createElement(IconTile, {
		kind = if sent then "Check" else "Chat",
		accent = if sent then Palette.mint else Palette.cyan,
		size = if compact then 44 else 50,
		radius = 14,
		filled = sent,
		reducedMotion = softMotion,
	})
	local _exp_4 = not keyboardCompact and React.createElement(Text, {
		value = if sent then "THANK YOU" else "FEEDBACK",
		size = 11,
		color = if sent then Palette.mint else Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(if compact then 56 else 62, 0),
		sizeConstraint = UDim2.new(1, -116, 0, 16),
		zIndex = 474,
	})
	local _exp_5 = React.createElement(Text, {
		value = if sent then "Got it. Thanks." elseif keyboardCompact then "Send feedback" else "What's bugging you?",
		size = if keyboardCompact then 18 elseif compact then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 15,
		position = UDim2.fromOffset(if keyboardCompact then 0 elseif compact then 56 else 62, if keyboardCompact then 3 else 18),
		sizeConstraint = UDim2.new(1, if keyboardCompact then -(TapTarget + 10) else -116, 0, 28),
		zIndex = 474,
	})
	local _exp_6 = React.createElement(Button, {
		text = "",
		icon = "Close",
		onClick = close,
		color = Palette.ink,
		textColor = Palette.coral,
		size = UDim2.fromOffset(TapTarget, TapTarget),
		position = UDim2.new(1, -TapTarget, 0, 0),
		reducedMotion = softMotion,
		disabled = sending or closing,
	})
	local _condition = not sent and not keyboardCompact
	if _condition then
		local _attributes = {}
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#CATEGORIES)
		local _callback = function(choice)
			return {
				id = choice,
				label = string.upper(choice),
				accent = Palette.cyan,
			}
		end
		for _k, _v in CATEGORIES do
			_newValue[_k] = _callback(_v, _k - 1, CATEGORIES)
		end
		-- ▲ ReadonlyArray.map ▲
		_attributes.options = _newValue
		_attributes.value = category
		_attributes.onChange = function(id)
			return setCategory(id)
		end
		_attributes.accent = Palette.cyan
		_attributes.sound = "tabSwitch"
		_attributes.columns = categoryColumns
		_attributes.gap = 6
		_attributes.size = UDim2.fromScale(1, 1)
		_attributes.reducedMotion = softMotion
		_attributes.zIndex = 475
		_condition = React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, categoryH),
			Position = UDim2.fromOffset(0, categoryTop),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 474,
		}, React.createElement(SegmentedTabs, _attributes))
	end
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 470,
		Visible = motion:map(function(amount)
			return amount > 0.003
		end),
	}, _exp, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromOffset(width, height),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 471,
		Visible = motion:map(function(amount)
			return amount > 0.002
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 471,
	}, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, -32, 1, -28),
		Position = UDim2.fromOffset(16, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 473,
	}, _exp_3, _exp_4, _exp_5, _exp_6, _condition, not sent and React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, editorH),
		Position = UDim2.fromOffset(0, editorTop),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 474,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.45,
	}), React.createElement("textbox", {
		Size = UDim2.new(1, -24, 1, -38),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = message,
		PlaceholderText = "What happened, or what should we add? (8+ characters)",
		PlaceholderColor3 = Palette.muted,
		TextColor3 = Palette.cream,
		TextSize = 15,
		FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		MultiLine = true,
		ClearTextOnFocus = false,
		TextEditable = not sending,
		MaxVisibleGraphemes = 600,
		ZIndex = 475,
		Change = {
			Text = function(box)
				return setMessage(string.sub(box.Text, 1, 600))
			end,
		},
		Event = {
			Focused = function()
				return Audio:play("inputFocus")
			end,
		},
	}), React.createElement(Text, {
		value = if #trimmed < 8 then `{math.max(0, 8 - #trimmed)} more to send  ·  {#message} / 600` else `{#message} / 600`,
		size = 11,
		color = if #trimmed < 8 then Palette.mango elseif #message >= 580 then Palette.mango else Palette.muted,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(0, 12, 1, -26),
		sizeConstraint = UDim2.new(1, -24, 0, 16),
		zIndex = 475,
	})), if sent then React.createElement(Button, {
		text = "DONE",
		icon = "Check",
		onClick = close,
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = softMotion,
		highlight = true,
	}) else React.createElement(Button, {
		text = if sending then "SENDING..." elseif #trimmed < 8 then "WRITE A LITTLE MORE" else "SEND FEEDBACK",
		icon = "Send",
		onClick = submit,
		color = if canSend then Palette.cyan else Palette.panelSoft,
		textColor = if canSend then Palette.ink else Palette.muted,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		disabled = not canSend,
		reducedMotion = softMotion,
		highlight = canSend,
	}))))))
end
return {
	FeedbackOverlay = FeedbackOverlay,
}
