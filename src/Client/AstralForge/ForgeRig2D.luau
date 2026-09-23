local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local _motion = require(script.Parent.motion)
local easeInCubic = _motion.easeInCubic
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useSprScale = _motion.useSprScale
local Palette = require(script.Parent.theme).Palette
local ATLAS_SIZE = 1024
local CELL_HEIGHT = 512
local CELL_SIZE = Vector2.new(ATLAS_SIZE, CELL_HEIGHT)
local HAMMER_OFFSET = Vector2.zero
local ANVIL_OFFSET = Vector2.new(0, CELL_HEIGHT)
local ANVIL_HALF_SIZE = Vector2.new(ATLAS_SIZE / 2, CELL_HEIGHT)
local ANVIL_RIGHT_OFFSET = Vector2.new(ATLAS_SIZE / 2, CELL_HEIGHT)
local REGULAR_CONTACT = 0.7
local FINALE_CONTACT = 0.75
local HAMMER_WIDTH = 0.72
local HAMMER_HEIGHT = 0.36
local ANVIL_WIDTH = 0.74
local ANVIL_HEIGHT = 0.37
local HAMMER_ANCHOR_X = 0.92
local FORGE_RIG_LOOP_SECONDS = 2.05
local FORGE_RIG_ART_SCALE = 0.56
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function span(value, start, finish)
	return clamp01((value - start) / math.max(0.001, finish - start))
end
local function pulse(value, start, peak, finish)
	if value <= start or value >= finish then
		return 0
	end
	return if value <= peak then span(value, start, peak) else 1 - span(value, peak, finish)
end
local function dampedBounce(value, frequency, decay)
	if frequency == nil then
		frequency = 3.4
	end
	if decay == nil then
		decay = 6.2
	end
	local amount = clamp01(value)
	return math.exp(-decay * amount) * math.sin(amount * math.pi * frequency)
end
local function regularPose(progress)
	local value = clamp01(progress)
	local rotation = 12
	local pivotX = 1.04
	local pivotY = 0.28
	local stretch = 0
	local trail = 0
	local flex = 0
	if value < 0.18 then
		local idle = value / 0.18
		rotation = 12 + math.sin(idle * math.pi) * 2.8
		pivotX = 1.04 + math.sin(idle * math.pi * 2) * 0.002
		pivotY = 0.28 - math.sin(idle * math.pi) * 0.007
		flex = math.sin(idle * math.pi * 2) * 1.2
	elseif value < 0.43 then
		local amount = easeOutBack(span(value, 0.18, 0.43))
		rotation = 12 + amount * 36
		pivotX = 1.04 - amount * 0.045
		pivotY = 0.28 + amount * 0.03
		stretch = -0.032 * amount
		flex = -math.sin(clamp01(amount) * math.pi) * 8
	elseif value < 0.53 then
		local amount = span(value, 0.43, 0.53)
		rotation = 48 + math.sin(amount * math.pi) * 2.5
		pivotX = 0.995
		pivotY = 0.31 - amount * 0.04
		stretch = -0.032 + amount * 0.012
		flex = -math.sin(amount * math.pi) * 10
	elseif value < REGULAR_CONTACT then
		local amount = easeInCubic(span(value, 0.53, REGULAR_CONTACT))
		rotation = 48 - amount * 58
		pivotX = 0.995 + amount * 0.06
		pivotY = 0.27 - amount * 0.052
		stretch = amount * 0.082
		trail = easeOutCubic(amount)
		flex = math.sin(amount * math.pi) * 16
	else
		local recovery = span(value, REGULAR_CONTACT, 1)
		local settle = easeOutCubic(recovery)
		local bounce = dampedBounce(recovery, 3.6, 6.8)
		rotation = -10 + settle * 22 + bounce * 26
		pivotX = 1.05 - settle * 0.01 - bounce * 0.008
		pivotY = 0.22 + settle * 0.06 - bounce * 0.03
		stretch = -bounce * 0.035
		flex = -dampedBounce(recovery, 5.2, 5.6) * 16
	end
	local impact = pulse(value, REGULAR_CONTACT - 0.012, REGULAR_CONTACT + 0.02, REGULAR_CONTACT + 0.15)
	local recovery = span(value, REGULAR_CONTACT, 1)
	local anvilBounce = if value < REGULAR_CONTACT then 0 else dampedBounce(recovery, 4.1, 7.4)
	return {
		hammerPosition = UDim2.fromScale(pivotX, pivotY),
		hammerRotation = rotation,
		hammerScaleX = 1 - stretch * 0.35,
		hammerScaleY = 1 + stretch,
		anvilPosition = UDim2.fromScale(0.5, 0.64 + impact * 0.01 - anvilBounce * 0.006),
		anvilScaleX = 1 + impact * 0.065 - anvilBounce * 0.022,
		anvilScaleY = 1 - impact * 0.14 + anvilBounce * 0.045,
		impact = impact,
		trail = trail,
		flex = flex,
	}
end
local function finalePose(progress)
	local value = clamp01(progress)
	local rotation = 12
	local pivotX = 1.04
	local pivotY = 0.28
	local stretch = 0
	local trail = 0
	local flex = 0
	if value < 0.16 then
		local amount = easeOutBack(span(value, 0, 0.16))
		rotation = 12 + amount * 58
		pivotX = 1.04 - amount * 0.07
		pivotY = 0.28 - amount * 0.06
		stretch = -amount * 0.025
		flex = -math.sin(clamp01(amount) * math.pi) * 9
	elseif value < 0.52 then
		local amount = easeOutCubic(span(value, 0.16, 0.52))
		local arc = math.sin(amount * math.pi)
		rotation = 70 + amount * 900
		pivotX = 0.97 - arc * 0.13 - amount * 0.025
		pivotY = 0.22 - arc * 0.15
		stretch = arc * 0.06
		trail = 0.62 + arc * 0.38
		flex = math.sin(amount * math.pi * 4) * 12
	elseif value < 0.64 then
		local amount = easeOutCubic(span(value, 0.52, 0.64))
		rotation = 970 + math.sin(amount * math.pi) * 14
		pivotX = 0.945 - amount * 0.008
		pivotY = 0.21 - amount * 0.09
		stretch = -0.025 + amount * 0.012
		trail = 0.45 - amount * 0.15
		flex = -math.sin(amount * math.pi) * 18
	elseif value < FINALE_CONTACT then
		local amount = easeInCubic(span(value, 0.64, FINALE_CONTACT))
		rotation = 970 - amount * 258
		pivotX = 0.937 + amount * 0.113
		pivotY = 0.12 + amount * 0.1
		stretch = amount * 0.2
		trail = 0.35 + amount * 0.65
		flex = math.sin(amount * math.pi) * 31
	else
		local recovery = span(value, FINALE_CONTACT, 1)
		local settle = easeOutCubic(recovery)
		local bounce = dampedBounce(recovery, 3.8, 6.8)
		rotation = 712 + settle * 22 + bounce * 31
		pivotX = 1.05 - settle * 0.01 - bounce * 0.008
		pivotY = 0.22 + settle * 0.06 - bounce * 0.035
		stretch = -bounce * 0.032
		flex = -dampedBounce(recovery, 5.4, 5.5) * 16
	end
	local impact = pulse(value, FINALE_CONTACT - 0.012, FINALE_CONTACT + 0.018, 0.93)
	local recovery = span(value, FINALE_CONTACT, 1)
	local anvilBounce = if value < FINALE_CONTACT then 0 else dampedBounce(recovery, 4.4, 7.2)
	return {
		hammerPosition = UDim2.fromScale(pivotX, pivotY),
		hammerRotation = rotation,
		hammerScaleX = 1 - stretch * 0.32,
		hammerScaleY = 1 + stretch,
		anvilPosition = UDim2.fromScale(0.5, 0.64 + impact * 0.023 - anvilBounce * 0.011),
		anvilScaleX = 1 + impact * 0.11 - anvilBounce * 0.028,
		anvilScaleY = 1 - impact * 0.22 + anvilBounce * 0.06,
		impact = impact,
		trail = trail,
		flex = flex,
	}
end
local function faded(effectTransparency, masterFade)
	return clamp01(1 - (1 - effectTransparency) * (1 - masterFade))
end
local function ForgeRig2D(_param)
	local atlasId = _param.atlasId
	local size = _param.size
	local position = _param.position
	local reducedMotion = _param.reducedMotion
	local lowQuality = _param.lowQuality
	local exiting = _param.exiting
	if exiting == nil then
		exiting = false
	end
	local finaleActive = _param.finaleActive
	if finaleActive == nil then
		finaleActive = false
	end
	local finaleTimeline = _param.finaleTimeline
	local fade = _param.fade
	local onWindup = _param.onWindup
	local onStrike = _param.onStrike
	local onSpark = _param.onSpark
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 520
	end
	local regularTimeline, setRegularTimeline = React.useBinding(0)
	local windupRef = React.useRef(onWindup)
	local strikeRef = React.useRef(onStrike)
	local sparkRef = React.useRef(onSpark)
	windupRef.current = onWindup
	strikeRef.current = onStrike
	sparkRef.current = onSpark
	local entranceScale = useSprScale(1, reducedMotion, 0.78, 0.7, 6.8)
	React.useEffect(function()
		if reducedMotion or finaleActive or exiting then
			setRegularTimeline(0.04)
			return nil
		end
		local startedAt = os.clock()
		local priorCycle = -1
		local windupSent = false
		local strikeSent = false
		local sparkSent = false
		local connection = RunService.RenderStepped:Connect(function()
			local elapsed = math.max(0, os.clock() - startedAt)
			local cycle = math.floor(elapsed / FORGE_RIG_LOOP_SECONDS)
			local progress = (elapsed % FORGE_RIG_LOOP_SECONDS) / FORGE_RIG_LOOP_SECONDS
			if cycle ~= priorCycle then
				priorCycle = cycle
				windupSent = false
				strikeSent = false
				sparkSent = false
			end
			setRegularTimeline(progress)
			if not windupSent and progress >= 0.28 then
				windupSent = true
				local _result = windupRef.current
				if _result ~= nil then
					_result()
				end
			end
			if not strikeSent and progress >= REGULAR_CONTACT then
				strikeSent = true
				local _result = strikeRef.current
				if _result ~= nil then
					_result()
				end
			end
			if not sparkSent and progress >= REGULAR_CONTACT + 0.018 then
				sparkSent = true
				local _result = sparkRef.current
				if _result ~= nil then
					_result()
				end
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { exiting, finaleActive, reducedMotion, setRegularTimeline })
	local pose = React.joinBindings({
		regular = regularTimeline,
		finale = finaleTimeline,
	}):map(function(_param_1)
		local regular = _param_1.regular
		local finale = _param_1.finale
		return if finaleActive then finalePose(finale) else regularPose(regular)
	end)
	local atlas = `rbxassetid://{atlasId}`
	local hammerPosition = pose:map(function(value)
		return value.hammerPosition
	end)
	local anvilPosition = pose:map(function(value)
		return value.anvilPosition
	end)
	local anvilScaleX = pose:map(function(value)
		return value.anvilScaleX
	end)
	local anvilScaleY = pose:map(function(value)
		return value.anvilScaleY
	end)
	local hammerSize = pose:map(function(value)
		return UDim2.fromScale(HAMMER_WIDTH * value.hammerScaleX, HAMMER_HEIGHT * value.hammerScaleY * (1 + math.abs(value.flex) * 0.0015))
	end)
	local silhouetteRotation = pose:map(function(value)
		return value.hammerRotation + value.flex * 0.16
	end)
	local anvilSize = React.joinBindings({
		x = anvilScaleX,
		y = anvilScaleY,
	}):map(function(_param_1)
		local x = _param_1.x
		local y = _param_1.y
		return UDim2.fromScale(ANVIL_WIDTH * x, ANVIL_HEIGHT * y)
	end)
	local anvilHalfSize = React.joinBindings({
		x = anvilScaleX,
		y = anvilScaleY,
	}):map(function(_param_1)
		local x = _param_1.x
		local y = _param_1.y
		return UDim2.fromScale(ANVIL_WIDTH * x * 0.5, ANVIL_HEIGHT * y)
	end)
	local splitAmount = finaleTimeline:map(function(amount)
		return if finaleActive then easeOutCubic(span(amount, FINALE_CONTACT, 0.97)) else 0
	end)
	local leftAnvilPosition = React.joinBindings({
		pose = pose,
		split = splitAmount,
	}):map(function(_param_1)
		local value = _param_1.pose
		local split = _param_1.split
		return UDim2.new(value.anvilPosition.X.Scale - ANVIL_WIDTH * value.anvilScaleX * 0.25 - split * 0.14, value.anvilPosition.X.Offset, value.anvilPosition.Y.Scale + split * split * 0.12, value.anvilPosition.Y.Offset)
	end)
	local rightAnvilPosition = React.joinBindings({
		pose = pose,
		split = splitAmount,
	}):map(function(_param_1)
		local value = _param_1.pose
		local split = _param_1.split
		return UDim2.new(value.anvilPosition.X.Scale + ANVIL_WIDTH * value.anvilScaleX * 0.25 + split * 0.14, value.anvilPosition.X.Offset, value.anvilPosition.Y.Scale + split * split * 0.12, value.anvilPosition.Y.Offset)
	end)
	local leftAnvilRotation = splitAmount:map(function(amount)
		return -amount * 22
	end)
	local rightAnvilRotation = splitAmount:map(function(amount)
		return amount * 22
	end)
	local fractureTransparency = React.joinBindings({
		split = splitAmount,
		fade = fade,
	}):map(function(_param_1)
		local split = _param_1.split
		local leaving = _param_1.fade
		return faded(1 - pulse(split, 0, 0.08, 0.72) * 0.94, leaving)
	end)
	local impactSize = pose:map(function(value)
		return UDim2.fromScale(0.11 + value.impact * 0.3, 0.11 + value.impact * 0.3)
	end)
	local impactTransparency = React.joinBindings({
		pose = pose,
		fade = fade,
	}):map(function(_param_1)
		local value = _param_1.pose
		local leaving = _param_1.fade
		return faded(1 - value.impact * 0.82, leaving)
	end)
	local shadowSize = pose:map(function(value)
		return UDim2.fromScale(0.48 + value.impact * 0.05, 0.045 - value.impact * 0.012)
	end)
	local _exp = React.createElement("uiaspectratioconstraint", {
		AspectRatio = 1,
		DominantAxis = Enum.DominantAxis.Height,
	})
	local _exp_1 = React.createElement("frame", {
		Size = shadowSize,
		Position = UDim2.fromScale(0.5, 0.815),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cyan,
		BackgroundTransparency = fade:map(function(leaving)
			return faded(0.87, leaving)
		end),
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_2 = React.createElement("frame", {
		Size = impactSize,
		Position = UDim2.fromScale(0.5, 0.47),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 2.5,
		Transparency = impactTransparency,
	}))
	local _exp_3 = if not finaleActive then React.createElement("imagelabel", {
		Size = anvilSize,
		Position = anvilPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = atlas,
		ImageRectOffset = ANVIL_OFFSET,
		ImageRectSize = CELL_SIZE,
		ImageTransparency = fade,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		ZIndex = zIndex + 3,
	}, React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(1, 1),
	})) else React.createElement(React.Fragment, nil, React.createElement("imagelabel", {
		Size = anvilHalfSize,
		Position = leftAnvilPosition,
		Rotation = leftAnvilRotation,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = atlas,
		ImageRectOffset = ANVIL_OFFSET,
		ImageRectSize = ANVIL_HALF_SIZE,
		ImageTransparency = fade,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		ZIndex = zIndex + 3,
	}), React.createElement("imagelabel", {
		Size = anvilHalfSize,
		Position = rightAnvilPosition,
		Rotation = rightAnvilRotation,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = atlas,
		ImageRectOffset = ANVIL_RIGHT_OFFSET,
		ImageRectSize = ANVIL_HALF_SIZE,
		ImageTransparency = fade,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		ZIndex = zIndex + 3,
	}), React.createElement("frame", {
		Size = UDim2.fromScale(0.012, ANVIL_HEIGHT * 0.58),
		Position = anvilPosition,
		AnchorPoint = Vector2.new(0.5, 0.34),
		Rotation = 7,
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = fractureTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex + 6,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.cream, Palette.mango),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(0.42, 0), NumberSequenceKeypoint.new(1, 0.9) }),
		Rotation = 90,
	})))
	local _condition = not reducedMotion and not lowQuality
	if _condition then
		local _exp_4 = (if finaleActive then { 0, 1, 2, 3 } else { 0, 1 })
		-- ▼ ReadonlyArray.map ▼
		local _newValue = table.create(#_exp_4)
		local _callback = function(index)
			local lag = 0.024 + index * 0.028
			local trailPose = React.joinBindings({
				regular = regularTimeline,
				finale = finaleTimeline,
			}):map(function(_param_1)
				local regular = _param_1.regular
				local finale = _param_1.finale
				return if finaleActive then finalePose(math.max(0, finale - lag)) else regularPose(math.max(0, regular - lag))
			end)
			local ribbonPosition = trailPose:map(function(value)
				local angle = math.rad(value.hammerRotation)
				local lever = HAMMER_WIDTH * value.hammerScaleX * (HAMMER_ANCHOR_X - 0.36)
				return UDim2.fromScale(value.hammerPosition.X.Scale - math.cos(angle) * lever, value.hammerPosition.Y.Scale - math.sin(angle) * lever)
			end)
			local ribbonSize = trailPose:map(function(value)
				return UDim2.fromScale(0.012 + value.trail * (0.012 - index * 0.0015), 0.06 + value.trail * (0.17 - index * 0.018))
			end)
			local transparency = React.joinBindings({
				pose = trailPose,
				fade = fade,
			}):map(function(_param_1)
				local value = _param_1.pose
				local leaving = _param_1.fade
				return faded(0.98 - value.trail * (0.36 - index * 0.055), leaving)
			end)
			return React.createElement("frame", {
				key = `forge-motion-ribbon-{index}`,
				Size = ribbonSize,
				Position = ribbonPosition,
				Rotation = trailPose:map(function(value)
					return value.hammerRotation + 90
				end),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if index % 3 == 0 then Palette.cream elseif index % 2 == 0 then Palette.violet else Palette.cyan,
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
				ZIndex = zIndex + 4 + index,
			}, React.createElement("uicorner", {
				CornerRadius = UDim.new(1, 0),
			}), React.createElement("uigradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.25), NumberSequenceKeypoint.new(1, 1) }),
				Rotation = 90,
			}))
		end
		for _k, _v in _exp_4 do
			_newValue[_k] = _callback(_v, _k - 1, _exp_4)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = _newValue
	end
	return React.createElement("frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(FORGE_RIG_ART_SCALE, FORGE_RIG_ART_SCALE),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
	}, React.createElement(ScaleFromCenter, {
		scaleRef = entranceScale,
		zIndex = zIndex,
	}, _exp, _exp_1, _exp_2, _exp_3, _condition, React.createElement("imagelabel", {
		Size = hammerSize,
		Position = hammerPosition,
		Rotation = silhouetteRotation,
		AnchorPoint = Vector2.new(HAMMER_ANCHOR_X, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = atlas,
		ImageRectOffset = HAMMER_OFFSET,
		ImageRectSize = CELL_SIZE,
		ImageTransparency = fade,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		ZIndex = zIndex + 8,
	}, React.createElement("uisizeconstraint", {
		MinSize = Vector2.new(1, 1),
	})))))
end
return {
	ForgeRig2D = ForgeRig2D,
	FORGE_RIG_LOOP_SECONDS = FORGE_RIG_LOOP_SECONDS,
	FORGE_RIG_ART_SCALE = FORGE_RIG_ART_SCALE,
}
