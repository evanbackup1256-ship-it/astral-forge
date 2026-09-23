local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.audio).Audio
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local MOBILE_PREVIEW_ACK = 1
local DISCLAIMER = "Phone and tablet are still a preview. Some pages overlap, clip, or miss buttons — especially in short landscape.\n\nThis is not the finished mobile game. Trade, inventory, shop, and the top bar can still crash into each other. Some taps are too small. The keyboard and home bar are best-effort. Mid-range Androids may hitch on crates and celebrations.\n\nBugs are expected. Your save is still on the server. Hit Feedback if something blocks you. Desktop is the supported way to play."
local function MobilePreviewGate(_param)
	local ack = _param.ack
	local reducedMotion = _param.reducedMotion
	local dispatch = _param.dispatch
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local touchDevice = not viewport.desktop and UserInputService.TouchEnabled
	local checked, setChecked = React.useState(false)
	local dismissed, setDismissed = React.useState(false)
	local enter = useEntrance(reducedMotion)
	local _binding = useExitTransition(reducedMotion)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
	local short = viewport.height < 500
	local side = math.max(16, chrome.sideSafe + 12)
	local top = math.max(18, viewport.topInset + 12)
	local bottom = math.max(18, chrome.bottomSafe + 12)
	local boxWidth = math.min(viewport.width - side * 2, 720)
	local boxHeight = math.min(viewport.height - top - bottom, if short then viewport.height - top - bottom else 620)
	local fade = motion:map(function(amount)
		return 1 - math.clamp(amount, 0, 1)
	end)
	local scrim = motion:map(function(amount)
		return math.clamp(1 - amount * 0.94, 0.06, 1)
	end)
	local lift = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - math.clamp(amount, 0, 1)) * 18))
	end)
	local close = function()
		if not checked or closing then
			return nil
		end
		Audio:play("confirm")
		dispatch("SetSetting", {
			Key = "MobilePreviewAck",
			Value = MOBILE_PREVIEW_ACK,
		})
		beginExit(function()
			return setDismissed(true)
		end)
	end
	local _condition = not touchDevice or dismissed
	if not _condition then
		local _condition_1 = ack
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_condition = _condition_1 >= MOBILE_PREVIEW_ACK
	end
	if _condition then
		return React.createElement(React.Fragment)
	end
	local toggle = function()
		Audio:play("tick")
		setChecked(function(current)
			return not current
		end)
	end
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrim,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 900,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(boxWidth, boxHeight),
		Position = lift,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.night,
		BorderSizePixel = 0,
		ZIndex = 901,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 16),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = Palette.mango,
		Thickness = 2,
		Transparency = 0.18,
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.night, Palette.ink),
		Rotation = 90,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(92, 3),
		Position = UDim2.fromOffset(22, 0),
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 902,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = "MOBILE PREVIEW",
		size = 12,
		color = Palette.mango,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(22, 16),
		sizeConstraint = UDim2.new(1, -44, 0, 16),
		transparency = fade,
		zIndex = 902,
	}), React.createElement(Text, {
		value = "Mobile is in development",
		size = if short then 22 else 28,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		wrap = true,
		position = UDim2.fromOffset(22, 36),
		sizeConstraint = UDim2.new(1, -44, 0, if short then 36 else 40),
		transparency = fade,
		zIndex = 902,
	}), React.createElement(Text, {
		value = "Expect bugs. This is not the finished phone game.",
		size = 14,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(22, if short then 74 else 82),
		sizeConstraint = UDim2.new(1, -44, 0, 36),
		transparency = fade,
		zIndex = 902,
	}), React.createElement("scrollingframe", {
		Size = UDim2.new(1, -44, 1, if short then -196 else -214),
		Position = UDim2.fromOffset(22, if short then 114 else 126),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Palette.mango,
		ScrollBarImageTransparency = 0.28,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ClipsDescendants = true,
		Active = true,
		Selectable = false,
		ZIndex = 902,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uipadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}), React.createElement(Text, {
		value = DISCLAIMER,
		size = 13,
		color = Palette.creamSoft,
		wrap = true,
		sizeConstraint = UDim2.new(1, 0, 0, 420),
		zIndex = 903,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -44, 0, TapTarget),
		Position = UDim2.new(0, 22, 1, -(TapTarget * 2 + 20)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 902,
	}, React.createElement(Button, {
		text = "",
		onClick = toggle,
		color = if checked then darken(Palette.mango, 0.55) else Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		zIndex = 903,
		outline = not checked,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(12, 13),
		BackgroundColor3 = if checked then Palette.mango else Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 904,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}), React.createElement("uistroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Color = if checked then Palette.mango else Palette.lineSoft,
		Thickness = 1,
	}), checked and React.createElement(Text, {
		value = "✓",
		size = 16,
		color = Palette.ink,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 905,
	})), React.createElement(Text, {
		value = "I understand mobile is unfinished and I may hit bugs.",
		size = 13,
		color = Palette.cream,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		position = UDim2.fromOffset(44, 4),
		sizeConstraint = UDim2.new(1, -56, 1, -8),
		zIndex = 904,
	}))), React.createElement(Button, {
		text = "CONTINUE",
		onClick = close,
		color = if checked then Palette.mango else Palette.panelSoft,
		textColor = if checked then Palette.ink else Palette.muted,
		size = UDim2.new(1, -44, 0, TapTarget),
		position = UDim2.new(0, 22, 1, -(TapTarget + 12)),
		disabled = not checked or closing,
		reducedMotion = reducedMotion,
		highlight = checked,
		zIndex = 903,
	}))))
end
return {
	MobilePreviewGate = MobilePreviewGate,
	MOBILE_PREVIEW_ACK = MOBILE_PREVIEW_ACK,
}
