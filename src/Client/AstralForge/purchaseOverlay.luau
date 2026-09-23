local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Audio = require(script.Parent.audio).Audio
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local Icon = require(script.Parent.Icon).Icon
local _motion = require(script.Parent.motion)
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useBoatTween = _motion.useBoatTween
local useClock = _motion.useClock
local useExitTransition = _motion.useExitTransition
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local darken = _theme.darken
local Palette = _theme.Palette
local surfaceGradient = _theme.surfaceGradient
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local PURCHASE_RESULT_HOLD = 2.2
local PURCHASE_RESULT_HOLD_REDUCED = 1.65
local PURCHASE_PENDING_FAILSAFE = 45
local DOT_COLORS = { Palette.mango, Palette.cyan, Palette.mint }
local function ForgeDot(_param)
	local index = _param.index
	local clock = _param.clock
	local morph = _param.morph
	local reducedMotion = _param.reducedMotion
	local color = DOT_COLORS[index + 1]
	local x = (index - 1) * 26
	local position = React.joinBindings({ clock, morph }):map(function(values)
		local wave = if reducedMotion then 0 else math.pow((math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.5, 1.6)
		return UDim2.new(0.5, math.round(x * (1 - values[2])), 0.5, math.round(9 - wave * 18))
	end)
	local scale = React.joinBindings({ clock, morph }):map(function(values)
		local pulse = if reducedMotion then 1 else 0.82 + (math.sin(values[1] * math.pi * 2 - index * 0.82) + 1) * 0.13
		return math.max(0.05, pulse * (1 - values[2]))
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 414,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BackgroundTransparency = morph:map(function(amount)
			return math.clamp(amount * 1.2, 0, 1)
		end),
		BorderSizePixel = 0,
		ZIndex = 414,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.white,
		Thickness = 1,
		Transparency = 0.42,
	}), React.createElement("frame", {
		Size = UDim2.new(1.35, 0, 0, 3),
		Position = UDim2.new(0.5, 0, 1, 9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = darken(color, 0.28),
		BackgroundTransparency = 0.54,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))))
end
local function ResultGlyph(_param)
	local phase = _param.phase
	local amount = _param.amount
	local accent = _param.accent
	local kind = if phase == "success" then "Check" else "Close"
	return React.createElement("frame", {
		Size = UDim2.fromOffset(78, 78),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement(ScaleFromCenter, {
		scale = amount:map(function(value)
			return 0.24 + value * 0.76
		end),
		zIndex = 415,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = darken(accent, 0.78),
		BackgroundTransparency = amount:map(function(value)
			return 1 - value * 0.22
		end),
		BorderSizePixel = 0,
		ZIndex = 415,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = amount:map(function(value)
			return 1 - value * 0.92
		end),
	}), React.createElement(Icon, {
		kind = kind,
		color = Palette.cream,
		accent = accent,
		size = 54,
		spin = false,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	}))))
end
local function PurchaseOverlay(_param)
	local phase = _param.phase
	local reducedMotion = _param.reducedMotion
	local detail = _param.detail
	local onDismiss = _param.onDismiss
	local visible = phase ~= "hidden"
	local result = phase == "success" or phase == "fail"
	local show = useBoatTween(if visible then 1 else 0, if visible then 0.25 else 0.18, reducedMotion, easeOutCubic, 0)
	local card = useBoatTween(if visible then 1 else 0, if visible then 0.34 else 0.15, reducedMotion, easeOutBack, 0)
	local _binding = useExitTransition(reducedMotion, 0.32, phase == "hidden")
	local exitAmount = _binding[1]
	local exiting = _binding[2]
	local beginExit = _binding[3]
	local morph = useFlipperSpring(if result then 1 else 0, reducedMotion, 500, 30)
	local clock = useClock(phase == "pending" and not reducedMotion, 1.4, 1)
	local viewport = useViewport()
	local nonce, setNonce = React.useState(0)
	local dismissRef = React.useRef(onDismiss)
	local dismissStarted = React.useRef(false)
	local overlayHostRef = React.useRef(nil)
	dismissRef.current = onDismiss
	local previousPhase = React.useRef("hidden")
	React.useEffect(function()
		if phase == previousPhase.current then
			return nil
		end
		previousPhase.current = phase
		if phase == "success" then
			Audio:play("purchaseResult")
		elseif phase == "fail" then
			Audio:play("error")
		end
	end, { phase })
	React.useEffect(function()
		if result then
			setNonce(function(value)
				return value + 1
			end)
		end
	end, { phase, result })
	local flash = useFlash(nonce, reducedMotion, if phase == "fail" then 0.62 else 0.48)
	local dismiss = React.useCallback(function()
		if not result or exiting or dismissStarted.current then
			return nil
		end
		dismissStarted.current = true
		Audio:play("purchaseExit")
		beginExit(function()
			local _result = dismissRef.current
			if _result ~= nil then
				_result = _result()
			end
			return _result
		end)
	end, { beginExit, exiting, result })
	React.useEffect(function()
		if phase == "pending" or phase == "hidden" then
			dismissStarted.current = false
		end
	end, { phase })
	React.useEffect(function()
		if not result then
			return nil
		end
		local worker = task.delay(if reducedMotion then PURCHASE_RESULT_HOLD_REDUCED else PURCHASE_RESULT_HOLD, dismiss)
		return function()
			return task.cancel(worker)
		end
	end, { dismiss, phase, reducedMotion, result })
	React.useEffect(function()
		if phase == "hidden" then
			GamepadNavigationService.EndOverlayFocus()
			return nil
		end
		GamepadNavigationService.BeginOverlayFocus()
		return function()
			GamepadNavigationService.EndOverlayFocus()
		end
	end, { phase })
	React.useEffect(function()
		if not result or not UserInputService.GamepadEnabled then
			return nil
		end
		local host = overlayHostRef.current
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
	end, { phase, result })
	local accent = if phase == "fail" then Palette.coral elseif phase == "success" then Palette.mint else Palette.mango
	local title = if phase == "pending" then "BUYING..." elseif phase == "success" then "BOUGHT" else "COULDN'T BUY"
	local _result
	if phase == "pending" then
		_result = "Waiting on Roblox checkout"
	else
		local _result_1
		if phase == "success" then
			_result_1 = "It's in your account now"
		else
			local _condition = detail
			if _condition == nil then
				_condition = "You weren't charged"
			end
			_result_1 = _condition
		end
		_result = _result_1
	end
	local detailText = _result
	local shortLandscape = viewport.height < 430 and viewport.width > viewport.height * 1.14
	local sideSafe = math.max(viewport.sideInset, 8)
	local topSafe = math.max(viewport.topInset, 8)
	local bottomSafe = math.max(viewport.bottomInset, 8)
	local safeHeight = math.max(184, viewport.height - topSafe - bottomSafe)
	local availableWidth = math.max(280, viewport.width - (sideSafe + 12) * 2)
	local cardWidth = math.min(if shortLandscape then 540 else 430, availableWidth)
	local cardHeight = if shortLandscape then math.clamp(safeHeight - 16, 184, 218) else math.clamp(safeHeight - 20, 232, 272)
	local compactVertical = not shortLandscape and cardHeight < 260
	local centerY = topSafe + safeHeight * 0.5
	local presence = React.joinBindings({ show, card, exitAmount }):map(function(values)
		return math.min(values[1], values[2], values[3])
	end)
	local cardTravel = 22
	local cardPosition = presence:map(function(amount)
		return UDim2.fromOffset(math.floor(viewport.width * 0.5), math.floor(centerY + (1 - amount) * cardTravel))
	end)
	local cardScale = React.joinBindings({ presence, flash }):map(function(values)
		return 0.94 + math.clamp(values[1], 0, 1) * 0.06 + values[2] * 0.025
	end)
	local orbSize = if shortLandscape then math.min(106, cardHeight - 32) elseif compactVertical then 104 else 118
	local orbPosition = if shortLandscape then UDim2.fromOffset(20, math.floor(cardHeight * 0.5)) else UDim2.new(0.5, 0, 0, 24)
	local orbAnchor = if shortLandscape then Vector2.new(0, 0.5) else Vector2.new(0.5, 0)
	local copyLeft = if shortLandscape then orbSize + 42 else 18
	local copyWidth = if shortLandscape then -(copyLeft + 20) else -36
	local titleY = if shortLandscape then math.max(28, math.floor(cardHeight * 0.5) - 44) elseif compactVertical then 136 else 158
	local detailY = if shortLandscape then titleY + 32 elseif compactVertical then titleY + 28 else 188
	local railLeft = if shortLandscape then copyLeft else 26
	local railBottom = if shortLandscape then 28 elseif compactVertical then 29 else 38
	local _exp = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = presence:map(function(amount)
			return 1 - amount * 0.68
		end),
		BorderSizePixel = 0,
		ZIndex = 400,
	})
	local _exp_1 = React.createElement("imagebutton", {
		Name = "PurchaseDismissBackdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "",
		AutoButtonColor = false,
		Active = visible and not exiting,
		Selectable = false,
		Modal = visible,
		ZIndex = 401,
		Event = {
			Activated = function()
				if result and not exiting then
					dismiss()
				end
			end,
		},
	})
	local _exp_2 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 4),
		Position = UDim2.fromOffset(0, 5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		ZIndex = 405,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	}))
	local _exp_3 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 22),
	})
	local _exp_4 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.62),
		Rotation = 90,
	})
	local _exp_5 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = presence:map(function(amount)
			return 1 - amount * 0.8
		end),
	})
	local _exp_6 = React.createElement("frame", {
		Size = UDim2.new(0.56, 0, 0, 3),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 407,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_7 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_8 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.5,
	})
	local _exp_9 = { 0, 1, 2 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp_9)
	local _callback = function(index)
		return React.createElement(ForgeDot, {
			key = index,
			index = index,
			clock = clock,
			morph = morph,
			reducedMotion = reducedMotion,
		})
	end
	for _k, _v in _exp_9 do
		_newValue[_k] = _callback(_v, _k - 1, _exp_9)
	end
	-- ▲ ReadonlyArray.map ▲
	local content = React.createElement(OverlayPresence, {
		amount = presence,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
		Active = presence:map(function(amount)
			return amount > 0.02 and not exiting
		end),
		Visible = presence:map(function(amount)
			return amount > 0.005
		end),
		ClipsDescendants = false,
		Event = {
			InputBegan = function(_frame, input)
				if result and not exiting and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
					dismiss()
				end
			end,
		},
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 405,
		ClipsDescendants = false,
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 405,
	}, _exp_2, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 406,
	}, _exp_3, _exp_4, _exp_5, _exp_6, React.createElement("frame", {
		Size = UDim2.fromOffset(orbSize, orbSize),
		Position = orbPosition,
		AnchorPoint = orbAnchor,
		BackgroundColor3 = darken(accent, 0.86),
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 410,
	}, _exp_7, _exp_8, _newValue, phase == "success" and React.createElement(ResultGlyph, {
		phase = "success",
		amount = morph,
		accent = accent,
	}), phase == "fail" and React.createElement(ResultGlyph, {
		phase = "fail",
		amount = morph,
		accent = accent,
	})), React.createElement(Text, {
		value = title,
		size = if shortLandscape then 15 else 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(copyLeft, titleY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 26),
		zIndex = 410,
	}), React.createElement(Text, {
		value = detailText,
		size = 11,
		color = Palette.creamSoft,
		align = if shortLandscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(copyLeft, detailY),
		sizeConstraint = UDim2.new(1, copyWidth, 0, 28),
		zIndex = 410,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -(railLeft + (if shortLandscape then 20 else 26)), 0, 3),
		Position = UDim2.new(0, railLeft, 1, -railBottom),
		BackgroundColor3 = Palette.lineSoft,
		BackgroundTransparency = 0.52,
		BorderSizePixel = 0,
		ZIndex = 409,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = if phase == "pending" then clock:map(function(time)
			return UDim2.new(0.22, 0, 1, 0)
		end) else UDim2.fromScale(1, 1),
		Position = if phase == "pending" then clock:map(function(time)
			return UDim2.new((time * 1.25) % 1, 0, 0, 0)
		end) else UDim2.fromScale(0, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.white, accent),
	}))), result and React.createElement("frame", {
		Name = "PurchaseContinue",
		Size = UDim2.new(1, -(copyLeft + (if shortLandscape then 20 else 26)), 0, 36),
		Position = UDim2.new(0, copyLeft, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 412,
	}, React.createElement(Button, {
		text = "CONTINUE",
		onClick = dismiss,
		color = accent,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
		selectable = true,
		zIndex = 412,
	})))))))
	return React.createElement("frame", {
		ref = overlayHostRef,
		Name = "PurchaseOverlayHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 400,
	}, content)
end
return {
	PurchaseOverlay = PurchaseOverlay,
	PURCHASE_RESULT_HOLD = PURCHASE_RESULT_HOLD,
	PURCHASE_RESULT_HOLD_REDUCED = PURCHASE_RESULT_HOLD_REDUCED,
	PURCHASE_PENDING_FAILSAFE = PURCHASE_PENDING_FAILSAFE,
}
