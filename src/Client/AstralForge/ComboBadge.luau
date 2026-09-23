local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local Icon = require(script.Parent.Icon).Icon
local _motion = require(script.Parent.motion)
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local useGlowStroke = _motion.useGlowStroke
local useOptionalFlipperSpring = _motion.useOptionalFlipperSpring
local usePulse = _motion.usePulse
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local lighten = _theme.lighten
local _ui = require(script.Parent.ui)
local Stroke = _ui.Stroke
local Text = _ui.Text
--[[
	*
	 * Cosmetic-only combo readout for the Overcharge tap loop. The server is the sole
	 * authority on `Combo` / `ComboMultiplier` — this component only ever mirrors values
	 * it is handed (per-tap effect/RemoteFunction data, or the decay-aware state snapshot
	 * as a resync fallback) and layers a client-side countdown purely to decide when to
	 * fade the badge out if the player stops tapping before the next server update arrives.
	 
]]
-- Continuous cyan -> pink -> coral -> mango ramp instead of comboAccent's old hard steps, so the
-- badge's color visibly eases as the streak climbs instead of jumping between four fixed colors.
local HEAT_STOPS = { Palette.cyan, Palette.pink, Palette.coral, Palette.mango }
local function heatColor(ratio)
	local t = math.clamp(ratio, 0, 1) * (#HEAT_STOPS - 1)
	local index = math.min(#HEAT_STOPS - 2, math.floor(t))
	return HEAT_STOPS[index + 1]:Lerp(HEAT_STOPS[index + 2], t - index)
end
-- Thin decay-countdown ring around the icon: a real read of how long the streak has left before
-- it expires, not just decoration. Reuses the same startedAt-anchored useClock sweep technique as
-- the reactor's PulseWindowNeedle (motion.ts's useClock always loops, so a "one countdown, not a
-- repeating sweep" ring is built by driving Visible off the remaining-time fraction directly).
local function DecayRing(_param)
	local accent = _param.accent
	local updatedAt = _param.updatedAt
	local windowSeconds = _param.windowSeconds
	local animate = _param.animate
	local anchorOffset = os.clock() - updatedAt
	local sweep = useClock(animate, 1 / math.max(0.1, windowSeconds), 1, true)
	local remaining = sweep:map(function(raw)
		return math.clamp(1 - ((raw + anchorOffset / windowSeconds) % 1), 0, 1)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = -90,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Transparency = remaining:map(function(fraction)
			-- NumberSequence throws if keypoints aren't strictly increasing in time. Clamping
			-- each bound independently (the original approach) let the second keypoint land
			-- past the third once `fraction` got close enough to 1 -- clamp them jointly
			-- instead so the ordering holds for every possible fraction, including 0 and 1.
			local edge = math.clamp(fraction, 0.001, 0.998)
			return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(edge, 0.05), NumberSequenceKeypoint.new(edge + 0.001, 1), NumberSequenceKeypoint.new(1, 1) })
		end),
	})))
end
local function ComboBadge(_param)
	local readout = _param.readout
	local reducedMotion = _param.reducedMotion
	local position = _param.position
	local anchorPoint = _param.anchorPoint
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 65
	end
	local antilag = useAntilag()
	local visible, setVisible = React.useState(false)
	React.useEffect(function()
		if readout == nil or readout.combo <= 0 then
			setVisible(false)
			return nil
		end
		setVisible(true)
		local expiresIn = math.max(0.05, readout.comboWindow - (os.clock() - readout.updatedAt)) + readout.comboWindow * 0.35
		local timer = task.delay(expiresIn, function()
			return setVisible(false)
		end)
		return function()
			return task.cancel(timer)
		end
	end, { readout })
	local _result = readout
	if _result ~= nil then
		_result = _result.combo
	end
	local _condition = _result
	if _condition == nil then
		_condition = 0
	end
	local combo = _condition
	local _result_1 = readout
	if _result_1 ~= nil then
		_result_1 = _result_1.comboMax
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = 12
	end
	local comboMax = math.max(1, _condition_1)
	local _result_2 = readout
	if _result_2 ~= nil then
		_result_2 = _result_2.comboMultiplier
	end
	local _condition_2 = _result_2
	if _condition_2 == nil then
		_condition_2 = 1
	end
	local multiplier = _condition_2
	local ratio = math.clamp(combo / comboMax, 0, 1)
	local maxed = combo >= comboMax
	local accent = heatColor(ratio)
	local everVisible, setEverVisible = React.useState(false)
	React.useEffect(function()
		if visible then
			setEverVisible(true)
		end
	end, { visible })
	-- Punches the icon and stat text on every combo increment (not just on show/hide), so each
	-- successful tap reads as a distinct beat instead of the badge only ever animating in once
	-- and then sitting static while the number underneath silently climbs.
	local tapPunch, setTapPunch = React.useState(0)
	local lastCombo = React.useRef(0)
	React.useEffect(function()
		if combo > lastCombo.current then
			setTapPunch(function(current)
				return current + 1
			end)
		end
		lastCombo.current = combo
	end, { combo })
	local punch = useFlash(tapPunch, reducedMotion, 0.28)
	local presence = useOptionalFlipperSpring(if visible then 1 else 0, everVisible, reducedMotion, 580, 32)
	local intensitySpring = useOptionalFlipperSpring(ratio, visible, reducedMotion, 380, 28)
	-- Maxed glow breathes slowly; punch carries the beat hierarchy.
	local glow = useGlowStroke(maxed and visible and antilag.allowAmbient, reducedMotion, 0.42, 0.22, 0.5, if maxed then 1.6 else 1.2)
	local maxPulse = usePulse(maxed and visible and not reducedMotion, 1.7)
	local scale = React.useMemo(function()
		return React.joinBindings({ presence, intensitySpring, punch }):map(function(values)
			return 0.72 + values[1] * 0.28 + values[2] * 0.05 + values[3] * 0.14
		end)
	end, { presence, intensitySpring, punch })
	local iconScale = React.useMemo(function()
		return punch:map(function(amount)
			return 1 + amount * 0.28
		end)
	end, { punch })
	local rise = React.useMemo(function()
		return presence:map(function(amount)
			return math.round((1 - amount) * 18)
		end)
	end, { presence })
	local fade = React.useMemo(function()
		return presence:map(function(amount)
			return 1 - amount
		end)
	end, { presence })
	if not everVisible then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(96, 40),
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Active = presence:map(function(amount)
			return amount > 0.01
		end),
		Visible = presence:map(function(amount)
			return amount > 0.01
		end),
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = zIndex,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = rise:map(function(offset)
			return UDim2.fromOffset(0, offset)
		end),
		BackgroundColor3 = darken(accent, 0.58),
		BackgroundTransparency = fade:map(function(amount)
			return math.clamp(0.12 + amount * 0.88, 0, 1)
		end),
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	}), React.createElement(Stroke, {
		color = if maxed then Palette.mango else accent,
		thickness = if maxed then 2 else 1.4,
		transparency = if maxed then glow else fade:map(function(amount)
			return math.clamp(0.28 + amount * 0.72, 0, 1)
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.fromOffset(6, 6),
		BackgroundColor3 = darken(accent, 0.3),
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), not maxed and readout ~= nil and visible and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(-2, -2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uisizeconstraint", {
		MaxSize = Vector2.new(32, 32),
	}), React.createElement(DecayRing, {
		accent = accent,
		updatedAt = readout.updatedAt,
		windowSeconds = readout.comboWindow,
		animate = not reducedMotion and antilag.allowAmbient,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 8),
	}), React.createElement(ScaleFromCenter, {
		scale = iconScale,
		zIndex = zIndex + 1,
	}, React.createElement(Icon, {
		kind = "Overcharge",
		color = Palette.cream,
		accent = accent,
		size = 17,
		spin = false,
		reducedMotion = reducedMotion,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})))), React.createElement(Text, {
		value = `×{math.floor(combo)}`,
		size = if maxed then 19 else 16,
		color = ensureContrast(darken(accent, 0.58), if maxed then lighten(Palette.mango, 0.3) else Palette.cream),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Left,
		fit = true,
		minSize = 12,
		position = UDim2.fromOffset(40, 4),
		sizeConstraint = UDim2.new(1, -46, 0, 20),
		transparency = fade,
		zIndex = zIndex + 1,
	}), React.createElement(Text, {
		value = if maxed then "MAXED" else `{string.format("%.2f", multiplier)}x`,
		size = 10,
		color = ensureContrast(darken(accent, 0.58), if maxed then Palette.mango else accent),
		weight = Enum.FontWeight.Bold,
		align = Enum.TextXAlignment.Left,
		fit = true,
		minSize = 9,
		position = UDim2.fromOffset(40, 22),
		sizeConstraint = UDim2.new(1, -46, 0, 14),
		transparency = fade,
		zIndex = zIndex + 1,
	}), maxed and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = maxPulse:map(function(amount)
			return 0.9 - amount * 0.06
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex - 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 12),
	})))))
end
return {
	ComboBadge = ComboBadge,
}
