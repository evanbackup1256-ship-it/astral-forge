local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local Audio = require(script.Parent.audio).Audio
local _format = require(script.Parent.format)
local asFlux = _format.asFlux
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local _motion = require(script.Parent.motion)
local composePresence = _motion.composePresence
local ScaleFromCenter = _motion.ScaleFromCenter
local useEntrance = _motion.useEntrance
local useExitTransition = _motion.useExitTransition
local useGlowStroke = _motion.useGlowStroke
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local NumberSpinnerHost = require(script.Parent.NumberSpinnerHost).NumberSpinnerHost
local _theme = require(script.Parent.theme)
local chromeFor = _theme.chromeFor
local Palette = _theme.Palette
local TapTarget = _theme.TapTarget
local _ui = require(script.Parent.ui)
local Button = _ui.Button
local IconTile = _ui.IconTile
local OverlayPresence = _ui.OverlayPresence
local Text = _ui.Text
local useGamepadAutofocus = _ui.useGamepadAutofocus
local function StatTile(_param)
	local label = _param.label
	local value = _param.value
	local color = _param.color
	local index = _param.index
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — OfflineRewardsOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local reveal = useStagger(index, softMotion, 0.07, 0.22)
	return React.createElement("frame", {
		Size = UDim2.new(0.25, -6, 1, 0),
		Position = UDim2.new(index * 0.25, if index == 0 then 0 else 6, 0, 0),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = reveal:map(function(amount)
			return 1 - amount
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement(Text, {
		value = label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(2, 8),
		sizeConstraint = UDim2.new(1, -4, 0, 14),
	}), React.createElement(Text, {
		value = value,
		size = if #value > 6 then 11 else 12,
		color = color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(2, 28),
		sizeConstraint = UDim2.new(1, -4, 0, 28),
	}))
end
local function OfflineRewardsOverlay(_param)
	local reward = _param.reward
	local seconds = _param.seconds
	local efficiency = _param.efficiency
	local capped = _param.capped
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — OfflineRewardsOverlay.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local effectsEnabled = _param.effectsEnabled
	local production = _param.production
	local awaySeconds = _param.awaySeconds
	local capHours = _param.capHours
	local vault = _param.vault
	local onCollect = _param.onCollect
	local onClose = _param.onClose
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.stack or viewport.width < 720
	local enter = useEntrance(softMotion)
	local _binding = useExitTransition(softMotion, 0.32)
	local leave = _binding[1]
	local closing = _binding[2]
	local beginExit = _binding[3]
	local motion = composePresence(enter, leave)
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
	end, {})
	local bankedSeconds = math.max(0, seconds)
	local _condition = awaySeconds
	if _condition == nil then
		_condition = bankedSeconds
	end
	local actualAway = math.max(bankedSeconds, _condition)
	local _condition_1 = capHours
	if _condition_1 == nil then
		_condition_1 = math.floor(bankedSeconds / 3600 + 0.49)
	end
	local hoursCap = math.max(1, _condition_1)
	local efficiencyPct = math.floor(math.clamp(efficiency, 0, 1) * 100 + 0.5)
	local rate = if production ~= nil then asFlux(production) else 0
	local missedSeconds = math.max(0, actualAway - bankedSeconds)
	local missed = if capped and rate > 0 then rate * efficiency * missedSeconds else 0
	local _condition_2 = vault
	if _condition_2 == nil then
		_condition_2 = 0
	end
	local vaultAmount = asFlux(_condition_2)
	local canBankVault = vaultAmount >= 0.01
	-- A haul big enough to matter (roughly an hour or more at the player's own rate) gets a
	-- stronger glow around the reward panel -- coming back to a small trickle and a huge bank
	-- both said "ALREADY IN YOUR CASH" identically before, with nothing to make a genuinely big
	-- welcome-back moment read as more exciting than a routine five-minute check-in.
	local rewardAmount = asFlux(reward)
	local bigHaul = rate > 0 and rewardAmount >= rate * 3600
	local rewardGlow = useGlowStroke(bigHaul, softMotion, 0.35, 0.15, 0.62, 1.6)
	local cardWidth = math.min(if stack then math.max(280, viewport.width - chrome.sideSafe * 2 - 20) else 560, 560)
	local cardHeight = math.min(if stack then 468 else 420, math.max(300, viewport.height - viewport.topInset - chrome.bottomSafe - 24))
	local finish = React.useCallback(function(bankVault)
		if closing then
			return nil
		end
		Audio:play(if bankVault then "offlineCollect" else "close")
		if bankVault then
			onCollect()
		end
		beginExit(onClose)
	end, { beginExit, closing, onClose, onCollect })
	React.useEffect(function()
		if bigHaul then
			Audio:playCelebration({ "offlineOpen", "discovery" }, 0.12)
		else
			Audio:play("offlineOpen")
		end
	end, {})
	local cardPosition = motion:map(function(amount)
		return UDim2.new(0.5, 0, 0.5, math.round((1 - amount) * 18))
	end)
	local cardScale = motion:map(function(amount)
		return 0.94 + amount * 0.06
	end)
	local scrim = motion:map(function(amount)
		return math.clamp(1 - amount * 0.78, 0.2, 1)
	end)
	local fade = motion:map(function(amount)
		return 1 - amount
	end)
	local _exp = {
		label = "AWAY",
		value = clockText(actualAway),
		color = Palette.cyan,
	}
	local _exp_1 = {
		label = "BANKED",
		value = clockText(bankedSeconds),
		color = Palette.mint,
	}
	local _exp_2 = {
		label = "EFFICIENCY",
		value = `{efficiencyPct}%`,
		color = Palette.violet,
	}
	local _object = {
		label = "RATE",
	}
	local _left = "value"
	local _result
	if rate > 0 then
		local _condition_3 = production
		if _condition_3 == nil then
			_condition_3 = 0
		end
		_result = `{compactNumber(_condition_3)}/s`
	else
		_result = "—"
	end
	_object[_left] = _result
	_object.color = Palette.mango
	local rows = { _exp, _exp_1, _exp_2, _object }
	local copy = if capped then `Offline earnings cap out at {hoursCap}h. {if missed > 0 then `About {compactNumber(missed)} flux was earned outside that window and missed.` else "Everything inside the window is already in your cash."}` else `Earned at {efficiencyPct}% efficiency for {clockText(bankedSeconds)}. That flux is already in your cash.`
	local _exp_3 = React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = scrim,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = true,
		Selectable = false,
		ZIndex = 460,
	})
	local _exp_4 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 18),
	})
	local _exp_5 = React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 2,
		Transparency = motion:map(function(amount)
			return 0.45 - amount * 0.28
		end),
	})
	local _exp_6 = React.createElement(IconTile, {
		kind = "Gift",
		accent = Palette.mint,
		size = if stack then 40 else 48,
		radius = 14,
		position = UDim2.fromOffset(0, 0),
		glow = effectsEnabled or bigHaul,
		spin = false,
		reducedMotion = softMotion,
	})
	local _exp_7 = React.createElement(Text, {
		value = "WELCOME BACK",
		size = 11,
		color = Palette.mint,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(56, 2),
		sizeConstraint = UDim2.new(1, -70, 0, 16),
	})
	local _exp_8 = React.createElement(Text, {
		value = "The forge kept running.",
		size = if stack then 18 else 22,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 14,
		position = UDim2.fromOffset(56, 20),
		sizeConstraint = UDim2.new(1, -70, 0, 28),
	})
	local _exp_9 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 86 else 96),
		Position = UDim2.fromOffset(0, 64),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 465,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 1.5,
		Transparency = rewardGlow,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}), React.createElement(Text, {
		value = "ALREADY IN YOUR CASH",
		size = 10,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(14, 10),
		sizeConstraint = UDim2.new(1, -28, 0, 14),
	}), React.createElement(NumberSpinnerHost, {
		value = rewardAmount,
		reducedMotion = softMotion,
		duration = 0.85,
		prefix = "+",
		extraSuffix = " FLUX",
		size = if stack then 24 else 30,
		color = Palette.mint,
		position = UDim2.fromOffset(14, 28),
		sizeConstraint = UDim2.fromOffset(0, 40),
		autoWidth = true,
		zIndex = 466,
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#rows)
	local _callback = function(row, index)
		return React.createElement(StatTile, {
			key = row.label,
			label = row.label,
			value = row.value,
			color = row.color,
			index = index,
			reducedMotion = softMotion,
		})
	end
	for _k, _v in rows do
		_newValue[_k] = _callback(_v, _k - 1, rows)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_10 = React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, if stack then 78 else 70),
		Position = UDim2.fromOffset(0, if stack then 162 else 172),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _newValue)
	local _exp_11 = React.createElement(Text, {
		value = copy,
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 40)),
		sizeConstraint = UDim2.new(1, 0, 0, 36),
	})
	local _result_1
	if canBankVault then
		local _attributes = {}
		local _condition_3 = vault
		if _condition_3 == nil then
			_condition_3 = 0
		end
		_attributes.text = `BANK VAULT  {compactNumber(_condition_3)}`
		_attributes.icon = "Collect"
		_attributes.onClick = function()
			return finish(true)
		end
		_attributes.color = Palette.mint
		_attributes.textColor = Palette.ink
		_attributes.size = UDim2.new(1, 0, 0, TapTarget)
		_attributes.position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 8))
		_attributes.reducedMotion = softMotion
		_attributes.disabled = closing
		_attributes.highlight = true
		_result_1 = React.createElement(Button, _attributes)
	else
		_result_1 = React.createElement(Button, {
			text = "CONTINUE",
			icon = "Collect",
			onClick = function()
				return finish(false)
			end,
			color = Palette.mint,
			textColor = Palette.ink,
			size = UDim2.new(1, 0, 0, TapTarget),
			position = UDim2.new(0, 0, 1, -(TapTarget * 2 + 8)),
			reducedMotion = softMotion,
			disabled = closing,
			highlight = true,
		})
	end
	return React.createElement(OverlayPresence, {
		amount = motion,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 460,
		Visible = motion:map(function(amount)
			return amount > 0.004
		end),
	}, _exp_3, React.createElement("frame", {
		ref = function(node)
			padFocus.current = node
			overlayHostRef.current = node
		end,
		Size = UDim2.fromOffset(cardWidth, cardHeight),
		Position = cardPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 461,
		Visible = motion:map(function(amount)
			return amount > 0.004
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = cardScale,
		zIndex = 461,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 462,
		ClipsDescendants = true,
	}, _exp_4, _exp_5, React.createElement("frame", {
		Size = UDim2.new(1, -28, 1, -28),
		Position = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 464,
	}, _exp_6, _exp_7, _exp_8, _exp_9, _exp_10, _exp_11, _result_1, React.createElement(Button, {
		text = if canBankVault then "KEEP VAULT" else "CLOSE",
		icon = "Close",
		onClick = function()
			return finish(false)
		end,
		color = Palette.panelSoft,
		textColor = Palette.cream,
		size = UDim2.new(1, 0, 0, TapTarget),
		position = UDim2.new(0, 0, 1, -TapTarget),
		reducedMotion = softMotion,
		disabled = closing,
	})))))))
end
return {
	OfflineRewardsOverlay = OfflineRewardsOverlay,
}
