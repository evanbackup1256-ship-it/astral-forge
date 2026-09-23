local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local Audio = require(script.Parent.Parent.audio).Audio
local _format = require(script.Parent.Parent.format)
local clockText = _format.clockText
local compactNumber = _format.compactNumber
local _Icon = require(script.Parent.Parent.Icon)
local Icon = _Icon.Icon
local WheelPrizeViewport = _Icon.WheelPrizeViewport
local prizeShapeFromReward = _Icon.prizeShapeFromReward
local InteractionFeedback = require(script.Parent.Parent.interaction).InteractionFeedback
local _motion = require(script.Parent.Parent.motion)
local useFlash = _motion.useFlash
local useGlowStroke = _motion.useGlowStroke
local useRotation = _motion.useRotation
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.theme)
local Layout = _theme.Layout
local Palette = _theme.Palette
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local lighten = _theme.lighten
local scrollTail = _theme.scrollTail
local surfaceGradient = _theme.surfaceGradient
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local Meter = _ui.Meter
local Panel = _ui.Panel
local Text = _ui.Text
local IMPACT_RAYS = { 0, 60, 120, 180, 240, 300 }
local RIM_NOTCHES = { 0, 45, 90, 135, 180, 225, 270, 315 }
local function motionEase(phase, alpha)
	local t = math.clamp(alpha, 0, 1)
	if phase == "launch" then
		return t * t
	end
	if phase == "coast" then
		return t
	end
	return 1 - math.pow(1 - t, 4.6)
end
local function positiveModulo(value, modulus)
	return ((value % modulus) + modulus) % modulus
end
local function useWheelController(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local onLand = _param.onLand
	local antilag = useAntilag()
	local rewardCount = math.max(1, #config.Wheel.Rewards)
	local segment = 360 / rewardCount
	local phase, setPhase = React.useState("idle")
	local winner, setWinner = React.useState(-1)
	local failure, setFailure = React.useState()
	local launchNonce, setLaunchNonce = React.useState(0)
	local impactNonce, setImpactNonce = React.useState(0)
	local rotation, setRotation = React.useBinding(0)
	local pointerKick, setPointerKick = React.useBinding(0)
	local spinEnergy, setSpinEnergy = React.useBinding(0)
	local rotationValue = React.useRef(0)
	local pointerKickValue = React.useRef(0)
	local busy = React.useRef(false)
	local mounted = React.useRef(true)
	local token = React.useRef(0)
	local timeout = React.useRef()
	local pendingResult = React.useRef()
	local launchFinished = React.useRef(false)
	local beginBrakeRef = React.useRef(function()
		return nil
	end)
	local motor = React.useRef({
		active = false,
		phase = "launch",
		startValue = 0,
		targetValue = 0,
		startedAt = 0,
		duration = 1,
		lastSegment = 0,
		lastSoundAt = -math.huge,
	})
	local spinning = phase == "launch" or phase == "coast" or phase == "brake"
	local audioTicks = not reducedMotion and antilag.fxBudget > 0.22
	local audioTicksRef = React.useRef(audioTicks)
	audioTicksRef.current = audioTicks
	local startPlan = React.useCallback(function(targetValue, duration, nextPhase, onComplete)
		motor.current = {
			active = true,
			phase = nextPhase,
			startValue = rotationValue.current,
			targetValue = targetValue,
			startedAt = os.clock(),
			duration = math.max(0.05, duration),
			lastSegment = math.floor(rotationValue.current / segment),
			lastSoundAt = -math.huge,
			onComplete = onComplete,
		}
		setPhase(nextPhase)
	end, { segment })
	local completeLanding = React.useCallback(function(result, finalRotation)
		if not mounted.current or not busy.current then
			return nil
		end
		local normalized = positiveModulo(finalRotation, 360)
		rotationValue.current = normalized
		pointerKickValue.current = 0
		setRotation(normalized)
		setPointerKick(0)
		setSpinEnergy(0)
		setWinner(result.index)
		setImpactNonce(function(value)
			return value + 1
		end)
		setPhase("landed")
		busy.current = false
		pendingResult.current = nil
		Audio:play("wheelLand")
		InteractionFeedback.reward()
		local _result = onLand
		if _result ~= nil then
			_result(result.message)
		end
	end, { onLand, setPointerKick, setRotation, setSpinEnergy })
	local beginBrake = React.useCallback(function(result)
		if not mounted.current or not busy.current then
			return nil
		end
		local current = rotationValue.current
		local wanted = positiveModulo(360 - result.index * segment, 360)
		if reducedMotion then
			Audio:play("wheelBrake")
			completeLanding(result, wanted)
			return nil
		end
		local delta = positiveModulo(wanted - positiveModulo(current, 360), 360)
		local extra = if antilag.tier <= 1 then 720 else 1440
		local target = current + extra + delta
		Audio:play("wheelBrake")
		startPlan(target, if antilag.tier <= 1 then 2.45 else 3.35, "brake", function()
			return completeLanding(result, target)
		end)
	end, { antilag.tier, completeLanding, reducedMotion, segment, startPlan })
	beginBrakeRef.current = beginBrake
	React.useEffect(function()
		if not spinning then
			return nil
		end
		local previousValue = rotationValue.current
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			if pointerKickValue.current > 0 then
				pointerKickValue.current = math.max(0, pointerKickValue.current - deltaTime * 11.5)
				setPointerKick(pointerKickValue.current)
			end
			local plan = motor.current
			if not plan.active then
				return nil
			end
			local alpha = math.clamp((os.clock() - plan.startedAt) / plan.duration, 0, 1)
			local value = plan.startValue + (plan.targetValue - plan.startValue) * motionEase(plan.phase, alpha)
			rotationValue.current = value
			setRotation(value)
			local degreesPerSecond = math.abs(value - previousValue) / math.max(deltaTime, 1 / 240)
			previousValue = value
			local energy = if plan.phase == "brake" then math.clamp(degreesPerSecond / 1150, 0, 1) else math.clamp(degreesPerSecond / 1700, 0, 1)
			setSpinEnergy(energy)
			local currentSegment = math.floor(value / segment)
			if currentSegment ~= plan.lastSegment then
				plan.lastSegment = currentSegment
				pointerKickValue.current = if plan.phase == "brake" and alpha > 0.66 then 1 else 0.58
				setPointerKick(pointerKickValue.current)
				local now = os.clock()
				local minimumInterval = if plan.phase == "brake" then 0.045 + alpha * 0.115 else 0.052
				if audioTicksRef.current and now - plan.lastSoundAt >= minimumInterval then
					plan.lastSoundAt = now
					Audio:play(if plan.phase == "brake" and alpha > 0.65 then "wheelSlow" else "wheelTick", 0.92 + (1 - alpha) * 0.16)
				end
			end
			if alpha < 1 then
				return nil
			end
			plan.active = false
			local complete = plan.onComplete
			plan.onComplete = nil
			if complete ~= nil then
				complete()
				return nil
			end
			if plan.phase == "coast" then
				local result = pendingResult.current
				if result ~= nil then
					beginBrakeRef.current(result)
				else
					startPlan(rotationValue.current + (if reducedMotion then 0 else 1080), if reducedMotion then 0.08 else 1.45, "coast")
				end
			end
		end)
		return function()
			return connection:Disconnect()
		end
	end, { reducedMotion, segment, setPointerKick, setRotation, setSpinEnergy, spinning, startPlan })
	React.useEffect(function()
		return function()
			mounted.current = false
			busy.current = false
			token.current += 1
			motor.current.active = false
			motor.current.onComplete = nil
			if timeout.current ~= nil then
				task.cancel(timeout.current)
			end
		end
	end, {})
	local spin = function()
		if busy.current or not state.Wheel.CanSpin then
			return nil
		end
		busy.current = true
		local requestToken = token.current + 1
		token.current = requestToken
		pendingResult.current = nil
		launchFinished.current = false
		pointerKickValue.current = 0
		setPointerKick(0)
		setWinner(-1)
		setFailure(nil)
		setLaunchNonce(function(value)
			return value + 1
		end)
		Audio:play("wheelStart")
		InteractionFeedback.tap()
		if reducedMotion then
			launchFinished.current = true
			motor.current.active = false
			setPhase("coast")
		else
			startPlan(rotationValue.current + (if antilag.tier <= 1 then 720 else 1080), 0.72, "launch", function()
				launchFinished.current = true
				local result = pendingResult.current
				if result ~= nil then
					beginBrakeRef.current(result)
				else
					startPlan(rotationValue.current + 1080, 1.45, "coast")
				end
			end)
		end
		if timeout.current ~= nil then
			task.cancel(timeout.current)
		end
		timeout.current = task.delay(12, function()
			timeout.current = nil
			if not mounted.current or token.current ~= requestToken or not busy.current then
				return nil
			end
			token.current += 1
			busy.current = false
			pendingResult.current = nil
			motor.current.active = false
			pointerKickValue.current = 0
			setPointerKick(0)
			setSpinEnergy(0)
			setPhase("error")
			setFailure("That spin took too long. Check Rewards before trying again.")
			Audio:play("requestTimeout")
		end)
		dispatch("SpinWheel", {}, function(response)
			if not mounted.current or token.current ~= requestToken then
				return nil
			end
			if timeout.current ~= nil then
				task.cancel(timeout.current)
				timeout.current = nil
			end
			if not response.ok or response.PrizeIndex == nil then
				busy.current = false
				pendingResult.current = nil
				motor.current.active = false
				pointerKickValue.current = 0
				setPointerKick(0)
				setSpinEnergy(0)
				setPhase("error")
				local _condition = response.error
				if _condition == nil then
					_condition = "The draw could not be completed."
				end
				setFailure(_condition)
				Audio:play("error")
				return nil
			end
			local result = {
				index = math.clamp(math.floor(response.PrizeIndex) - 1, 0, rewardCount - 1),
				message = response.message,
			}
			pendingResult.current = result
			if launchFinished.current then
				beginBrakeRef.current(result)
			end
		end)
	end
	return {
		phase = phase,
		spinning = spinning,
		winner = winner,
		failure = failure,
		launchNonce = launchNonce,
		impactNonce = impactNonce,
		rotation = rotation,
		pointerKick = pointerKick,
		spinEnergy = spinEnergy,
		spin = spin,
	}
end
local function WheelBurst(_param)
	local flash = _param.flash
	local active = _param.active
	local accent = _param.accent
	local budget = _param.budget
	local launch = _param.launch
	if launch == nil then
		launch = false
	end
	local contained = _param.contained
	if contained == nil then
		contained = false
	end
	if not active then
		return React.createElement(React.Fragment)
	end
	local ringCount = if launch then (if budget >= 0.55 then 2 else 1) elseif budget >= 0.3 then 2 else 1
	local rings = {}
	for index = 0, ringCount - 1 do
		local _index = index
		table.insert(rings, _index)
	end
	local overscan = if contained then 0 else 80
	local _exp = not launch and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = flash:map(function(amount)
			return 1 - amount * (0.035 + budget * 0.025)
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#rings)
	local _callback = function(ring)
		return React.createElement("frame", {
			key = `ring-{ring}`,
			Size = flash:map(function(amount)
				local decay = 1 - amount
				local freeScale = 0.64 + ring * 0.14 + decay * (0.48 + ring * 0.14)
				local scale = if contained then math.min(0.96, 0.54 + ring * 0.08 + decay * (0.3 + ring * 0.05)) else freeScale
				return UDim2.fromScale(scale, scale)
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = ring * 17,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then Palette.cream else accent,
			Thickness = if ring == 0 then 2.2 else 1.25,
			Transparency = flash:map(function(amount)
				return 1 - amount * (0.58 - ring * 0.1)
			end),
		}))
	end
	for _k, _v in rings do
		_newValue[_k] = _callback(_v, _k - 1, rings)
	end
	-- ▲ ReadonlyArray.map ▲
	local _condition = not launch and budget >= 0.62
	if _condition then
		-- ▼ ReadonlyArray.map ▼
		local _newValue_1 = table.create(#IMPACT_RAYS)
		local _callback_1 = function(angle, index)
			return React.createElement("frame", {
				key = `ray-{angle}`,
				Size = flash:map(function(amount)
					return UDim2.new(0, ((if contained then 38 else 50) + index % 3 * (if contained then 10 else 16)) * (1 - amount), 0, 2)
				end),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				Rotation = angle + 5,
				BackgroundColor3 = if index % 3 == 0 then Palette.cream elseif index % 2 == 0 then accent else Palette.cyan,
				BackgroundTransparency = flash:map(function(amount)
					return 1 - amount * 0.48
				end),
				BorderSizePixel = 0,
			}, React.createElement("uigradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 1) }),
			}))
		end
		for _k, _v in IMPACT_RAYS do
			_newValue_1[_k] = _callback_1(_v, _k - 1, IMPACT_RAYS)
		end
		-- ▲ ReadonlyArray.map ▲
		_condition = _newValue_1
	end
	return React.createElement("frame", {
		Size = UDim2.new(1, overscan, 1, overscan),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 70,
	}, _exp, _newValue, _condition)
end
local function PrizeWheelMachine(_param)
	local rewards = _param.rewards
	local controller = _param.controller
	local diameter = _param.diameter
	local canSpin = _param.canSpin
	local reducedMotion = _param.reducedMotion
	local containedEffects = _param.containedEffects
	if containedEffects == nil then
		containedEffects = false
	end
	local antilag = useAntilag()
	local count = math.max(1, #rewards)
	local segment = 360 / count
	local innerDiameter = math.floor(diameter * 0.84)
	local compactMachine = diameter < 230
	local medallionSize = math.floor(math.clamp(diameter * 0.145, if compactMachine then 32 else 36, 54))
	local hubSize = math.floor(math.clamp(diameter * 0.225, if compactMachine then 58 else 66, 94))
	local orbitRadius = innerDiameter / 2 - medallionSize / 2 - 12
	local landing = useFlash(controller.impactNonce, reducedMotion, if antilag.tier < 1 then 0.34 else 0.56)
	local launch = useFlash(controller.launchNonce, reducedMotion, 0.58)
	-- Decorative hub glow + idle orbit only when ambient is allowed and antilag tier is 2+.
	local decorateOrbit = antilag.allowAmbient and antilag.tier >= 2
	local hubStroke = useGlowStroke(canSpin and not controller.spinning and decorateOrbit, reducedMotion or not decorateOrbit, 0.58, 0.12, 0.7, 1.8)
	local idleOrbit = useRotation(not reducedMotion and not controller.spinning and canSpin and decorateOrbit, 5.5)
	local reverseOrbit = idleOrbit:map(function(angle)
		return -angle * 0.62
	end)
	local carrierScale = React.joinBindings({
		landing = landing,
		launch = launch,
		energy = controller.spinEnergy,
	}):map(function(_param_1)
		local hit = _param_1.landing
		local start = _param_1.launch
		local energy = _param_1.energy
		return 1 + hit * (0.045 + antilag.fxBudget * 0.025) - start * 0.025 + energy * 0.012
	end)
	local carrierPosition = React.joinBindings({
		landing = landing,
		energy = controller.spinEnergy,
	}):map(function(_param_1)
		local hit = _param_1.landing
		local energy = _param_1.energy
		return UDim2.new(0.5, 0, 0.5, -math.round(energy * 2) + math.round(math.sin((1 - hit) * math.pi * 3) * hit * 3))
	end)
	local pointerScale = React.joinBindings({
		tick = controller.pointerKick,
		landing = landing,
	}):map(function(_param_1)
		local tick = _param_1.tick
		local hit = _param_1.landing
		return 1 + tick * 0.16 + hit * 0.22
	end)
	local pointerY = React.joinBindings({
		tick = controller.pointerKick,
		landing = landing,
	}):map(function(_param_1)
		local tick = _param_1.tick
		local hit = _param_1.landing
		return UDim2.new(0.5, 0, 0, -5 - tick * 4 - hit * 5)
	end)
	local wheelGlow = controller.spinEnergy:map(function(energy)
		return 0.95 - energy * 0.16 * antilag.glowScale
	end)
	local _exp = React.createElement(WheelBurst, {
		flash = launch,
		active = controller.launchNonce > 0 and not reducedMotion,
		accent = Palette.mango,
		budget = antilag.fxBudget,
		launch = true,
		contained = containedEffects,
	})
	local _attributes = {
		flash = landing,
		active = controller.impactNonce > 0 and not reducedMotion,
	}
	local _result = rewards[controller.winner + 1]
	if _result ~= nil then
		_result = _result.Color
	end
	local _condition = _result
	if _condition == nil then
		_condition = Palette.mango
	end
	_attributes.accent = _condition
	_attributes.budget = antilag.fxBudget
	_attributes.contained = containedEffects
	local _exp_1 = React.createElement(WheelBurst, _attributes)
	local _exp_2 = React.createElement("uiscale", {
		Scale = carrierScale,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(1, 22, 1, 22),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = idleOrbit,
		BackgroundColor3 = Palette.mango,
		BackgroundTransparency = wheelGlow,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(Palette.cyan, Palette.mango),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0.08) }),
	}))
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panel,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.72),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 2,
		Transparency = 0.2,
	}))
	local _exp_5 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_6 = React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 2,
		Transparency = 0.46,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#RIM_NOTCHES)
	local _callback = function(angle)
		return React.createElement("frame", {
			key = `rim-{angle}`,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = angle,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(if angle % 90 == 0 then 20 else 12, 4),
			Position = UDim2.new(0.5, 0, 0, -2),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = if angle % 90 == 0 then Palette.mango else Palette.creamSoft,
			BackgroundTransparency = 0.16,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})))
	end
	for _k, _v in RIM_NOTCHES do
		_newValue[_k] = _callback(_v, _k - 1, RIM_NOTCHES)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_7 = React.createElement("frame", {
		Size = UDim2.new(1, -14, 1, -14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = reverseOrbit,
		ZIndex = 2,
	}, _exp_5, _exp_6, _newValue)
	local _exp_8 = React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})
	local _exp_9 = React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(Palette.panel, 0.04), darken(Palette.ink, 0.22)),
		Rotation = 90,
	})
	local _exp_10 = React.createElement("uistroke", {
		Color = Palette.creamSoft,
		Thickness = 1,
		Transparency = 0.62,
	})
	local _exp_11 = React.createElement("frame", {
		Size = UDim2.fromScale(0.66, 0.66),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.66,
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#rewards)
	local _callback_1 = function(reward, index)
		return React.createElement("frame", {
			key = `divider-{reward.Id}`,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * segment - segment / 2,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement("frame", {
			Size = UDim2.fromOffset(2, orbitRadius - hubSize * 0.22),
			Position = UDim2.new(0.5, 0, 0.5, -(orbitRadius - hubSize * 0.22) / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = reward.Color,
			BackgroundTransparency = 0.58,
			BorderSizePixel = 0,
		}, React.createElement("uigradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		})))
	end
	for _k, _v in rewards do
		_newValue_1[_k] = _callback_1(_v, _k - 1, rewards)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_2 = table.create(#rewards)
	local _callback_2 = function(reward, index)
		local won = controller.winner == index
		local counterRotation = controller.rotation:map(function(turn)
			return -(turn + index * segment)
		end)
		return React.createElement("frame", {
			key = reward.Id,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = index * segment,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, React.createElement("frame", {
			Size = UDim2.new(0, medallionSize + 16, 0, 5),
			Position = UDim2.new(0.5, 0, 0.5, -orbitRadius - 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = reward.Color,
			BackgroundTransparency = if won then 0.02 else 0.26,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uigradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.24, 0), NumberSequenceKeypoint.new(0.76, 0), NumberSequenceKeypoint.new(1, 1) }),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(medallionSize, medallionSize),
			Position = UDim2.new(0.5, 0, 0.5, -orbitRadius),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = counterRotation,
			BackgroundColor3 = darken(reward.Color, 0.72):Lerp(Palette.panelRaised, 0.42),
			BorderSizePixel = 0,
			ClipsDescendants = false,
		}, won and React.createElement("uiscale", {
			Scale = landing:map(function(amount)
				return 1 + amount * 0.18
			end),
		}), React.createElement("uicorner", {
			CornerRadius = UDim.new(0, math.floor(medallionSize * 0.28)),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(Palette.panelRaised, 0.08), darken(Palette.panelRaised, 0.22)),
			Rotation = 90,
		}), React.createElement("uistroke", {
			Color = if won then Palette.cream else reward.Color,
			Thickness = if won then 2.5 else 1.25,
			Transparency = if won then 0.02 else 0.18,
		}), React.createElement("frame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, React.createElement(WheelPrizeViewport, {
			color = reward.Color,
			shape = prizeShapeFromReward(reward.Reward, reward.Rarity),
			size = medallionSize - 8,
			spin = won and not reducedMotion,
		}))))
	end
	for _k, _v in rewards do
		_newValue_2[_k] = _callback_2(_v, _k - 1, rewards)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp, _exp_1, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = carrierPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp_2, _exp_3, _exp_4, _exp_7, React.createElement("frame", {
		Size = UDim2.fromOffset(innerDiameter, innerDiameter),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = controller.rotation,
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 3,
	}, _exp_8, _exp_9, _exp_10, _exp_11, _newValue_1, _newValue_2), React.createElement("frame", {
		Size = UDim2.fromOffset(hubSize + 16, hubSize + 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.shadow,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 2,
		Transparency = 0.5,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(hubSize, hubSize),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
		ZIndex = 7,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.75),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = Palette.mango,
		Thickness = 3,
		Transparency = hubStroke,
	}), React.createElement(Icon, {
		kind = "Wheel",
		color = Palette.cream,
		accent = Palette.mango,
		size = math.floor(hubSize * 0.58),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		spin = controller.spinning,
		clipSafe = true,
		reducedMotion = reducedMotion,
	}))), React.createElement("frame", {
		Size = UDim2.fromOffset(38, 42),
		Position = pointerY,
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = pointerScale,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(28, 18),
		Position = UDim2.fromOffset(19, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.panelSoft,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 7),
	}), React.createElement("uistroke", {
		Color = Palette.creamSoft,
		Thickness = 1,
		Transparency = 0.28,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(19, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = Palette.mango,
		BorderSizePixel = 0,
		ZIndex = 91,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 5),
	}), React.createElement("uistroke", {
		Color = Palette.cream,
		Thickness = 2,
		Transparency = 0.08,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(7, 7),
		Position = UDim2.fromOffset(19, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ZIndex = 92,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))
end
local function WheelConsole(_param)
	local state = _param.state
	local config = _param.config
	local controller = _param.controller
	local onSpin = _param.onSpin
	local height = _param.height
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	if compact == nil then
		compact = false
	end
	local prize = if controller.winner >= 0 then config.Wheel.Rewards[controller.winner + 1] else nil
	local canSpin = state.Wheel.CanSpin == true
	local _condition = state.Wheel.PityMisses
	if _condition == nil then
		_condition = 0
	end
	local pityMisses = _condition
	local _condition_1 = state.Wheel.PityAfter
	if _condition_1 == nil then
		_condition_1 = config.Wheel.PityAfter
		if _condition_1 == nil then
			_condition_1 = 8
		end
	end
	local pityAfter = _condition_1
	local pityArmed = state.Wheel.PityArmed == true or pityMisses + 1 >= pityAfter
	local pityFill = if pityArmed then 1 else math.clamp(pityMisses / math.max(1, pityAfter), 0, 1)
	local now = useWallClock(not canSpin)
	local cooldown = now:map(function(timestamp)
		return `Ready again in {clockText(math.max(0, state.Wheel.ReadyAt - timestamp))}`
	end)
	local status = if controller.spinning then "SPINNING" elseif controller.failure ~= nil then "SPIN PAUSED" elseif prize ~= nil then "YOU WON" elseif canSpin then "READY TO SPIN" else "COOLING DOWN"
	local _result
	if controller.failure ~= nil then
		_result = "Connection interrupted"
	else
		local _result_1 = prize
		if _result_1 ~= nil then
			_result_1 = _result_1.Name
		end
		local _condition_2 = _result_1
		if _condition_2 == nil then
			_condition_2 = (if controller.spinning then "Forging your outcome" elseif canSpin then "Your daily draw is ready" else "The wheel is recharging")
		end
		_result = _condition_2
	end
	local title = _result
	local _condition_2 = controller.failure
	if _condition_2 == nil then
		local _result_1 = prize
		if _result_1 ~= nil then
			_result_1 = _result_1.ShortLabel
		end
		_condition_2 = _result_1
		if _condition_2 == nil then
			local _result_2
			if controller.spinning then
				_result_2 = (if compact then "Your prize is coming up." else "The wheel is slowing down. Watch the pointer.")
			else
				local _result_3
				if canSpin then
					local _condition_3 = state.Wheel.FreeSpins
					if _condition_3 == nil then
						_condition_3 = 0
					end
					_result_3 = (if _condition_3 > 0 then `{compactNumber(state.Wheel.FreeSpins)} free spin{if state.Wheel.FreeSpins == 1 then "" else "s"} ready.` elseif pityArmed then ((config.ClientPageGuides and config.ClientPageGuides.Wheel and config.ClientPageGuides.Wheel.PityArmed) or "Pity is armed — the next spin is weighted toward a better prize.") elseif compact then "Tap once to spin." else ((config.ClientPageGuides and config.ClientPageGuides.Wheel and config.ClientPageGuides.Wheel.Ready) or "Give it a spin and see what lands."))
				else
					_result_3 = cooldown
				end
				_result_2 = _result_3
			end
			_condition_2 = _result_2
		end
	end
	local detail = _condition_2
	local _result_1
	if controller.failure ~= nil then
		_result_1 = Palette.coral
	else
		local _result_2 = prize
		if _result_2 ~= nil then
			_result_2 = _result_2.Color
		end
		local _condition_3 = _result_2
		if _condition_3 == nil then
			_condition_3 = (if canSpin then Palette.mango else Palette.lineSoft)
		end
		_result_1 = _condition_3
	end
	local accent = _result_1
	local edge = if compact then 10 else 14
	local iconBox = if compact then 58 else 72
	local iconInset = if compact then 7 else 9
	local prizeIcon = if compact then 44 else 54
	local copyX = if compact then 78 else 98
	local copyRight = if compact then 88 else 112
	local statsTop = if compact then 92 else 106
	local statsHeight = if compact then 42 else 52
	local buttonHeight = if compact then 48 else 50
	local buttonBottom = if compact then 10 else 14
	local _exp = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	})
	local _exp_1 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panel, 0.62),
		Rotation = 90,
	})
	local _exp_2 = React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = 0.42,
	})
	local _exp_3 = React.createElement("frame", {
		Size = UDim2.new(0.46, 0, 0, 3),
		Position = UDim2.fromOffset(edge, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(1, 1) }),
	}))
	local _exp_4 = React.createElement("frame", {
		Size = UDim2.fromOffset(iconBox, iconBox),
		Position = UDim2.fromOffset(edge, if compact then 12 else 16),
		BackgroundColor3 = darken(accent, 0.76):Lerp(Palette.panelRaised, 0.42),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 14),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = if prize ~= nil then 2 else 1,
		Transparency = if prize ~= nil then 0.08 else 0.46,
	}), if prize ~= nil then React.createElement("frame", {
		Size = UDim2.fromOffset(prizeIcon, prizeIcon),
		Position = UDim2.fromOffset(iconInset, iconInset),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(WheelPrizeViewport, {
		color = prize.Color,
		shape = prizeShapeFromReward(prize.Reward, prize.Rarity),
		size = prizeIcon,
		spin = false,
	})) else React.createElement(Icon, {
		kind = "Wheel",
		color = Palette.cream,
		accent = Palette.mango,
		size = if compact then 40 else 48,
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		reducedMotion = reducedMotion,
		clipSafe = true,
	}))
	local _exp_5 = React.createElement(Badge, {
		value = status,
		accent = accent,
		filled = prize ~= nil or controller.failure ~= nil,
		position = UDim2.fromOffset(copyX, if compact then 12 else 16),
		size = UDim2.new(1, -copyRight, 0, if compact then 22 else 24),
	})
	local _attributes = {
		value = title,
		size = if compact then 15 else 18,
	}
	local _result_2
	if controller.failure ~= nil then
		_result_2 = Palette.coral
	else
		local _result_3 = prize
		if _result_3 ~= nil then
			_result_3 = _result_3.Color
		end
		local _condition_3 = _result_3
		if _condition_3 == nil then
			_condition_3 = Palette.cream
		end
		_result_2 = _condition_3
	end
	_attributes.color = _result_2
	_attributes.weight = Enum.FontWeight.Heavy
	_attributes.fit = true
	_attributes.minSize = if compact then 9 else 11
	_attributes.position = UDim2.fromOffset(copyX, if compact then 38 else 44)
	_attributes.sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 20 else 24)
	local _exp_6 = React.createElement(Text, _attributes)
	local _exp_7 = React.createElement(Text, {
		value = detail,
		size = if compact then 9 else 11,
		color = Palette.creamSoft,
		wrap = true,
		position = UDim2.fromOffset(copyX, if compact then 59 else 69),
		sizeConstraint = UDim2.new(1, -copyRight, 0, if compact then 28 else 36),
	})
	local _exp_8 = React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	})
	local _exp_9 = React.createElement("uistroke", {
		Color = Palette.lineSoft,
		Thickness = 1,
		Transparency = 0.64,
	})
	local _attributes_1 = {}
	local _condition_3 = state.Wheel.FreeSpins
	if _condition_3 == nil then
		_condition_3 = 0
	end
	_attributes_1.value = if _condition_3 > 0 then "FREE DRAWS" else "TOTAL DRAWS"
	_attributes_1.size = 12
	_attributes_1.color = Palette.muted
	_attributes_1.weight = Enum.FontWeight.Heavy
	_attributes_1.position = UDim2.fromOffset(10, 5)
	_attributes_1.sizeConstraint = UDim2.new(1, -20, 0, 15)
	local _exp_10 = React.createElement(Text, _attributes_1)
	local _attributes_2 = {}
	local _condition_4 = state.Wheel.FreeSpins
	if _condition_4 == nil then
		_condition_4 = 0
	end
	_attributes_2.value = compactNumber(if _condition_4 > 0 then state.Wheel.FreeSpins else state.Wheel.Spins)
	_attributes_2.size = if compact then 14 else 16
	_attributes_2.color = Palette.cream
	_attributes_2.weight = Enum.FontWeight.Heavy
	_attributes_2.position = UDim2.fromOffset(10, if compact then 21 else 23)
	_attributes_2.sizeConstraint = UDim2.new(1, -20, 0, if compact then 18 else 22)
	return React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Palette.ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, _exp, _exp_1, _exp_2, _exp_3, _exp_4, _exp_5, _exp_6, _exp_7, React.createElement("frame", {
		Size = UDim2.new(1, -edge * 2, 0, statsHeight),
		Position = UDim2.fromOffset(edge, statsTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("frame", {
		Size = UDim2.new(0.34, -5, 1, 0),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
	}, _exp_8, _exp_9, _exp_10, React.createElement(Text, _attributes_2)), React.createElement("frame", {
		Size = UDim2.new(0.66, -5, 1, 0),
		Position = UDim2.new(0.34, 5, 0, 0),
		BackgroundColor3 = Palette.panelRaised,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 9),
	}), React.createElement("uistroke", {
		Color = if pityArmed then Palette.mango else Palette.lineSoft,
		Thickness = 1,
		Transparency = if pityArmed then 0.28 else 0.64,
	}), React.createElement(Text, {
		value = if compact then "RARITY" else "RARITY PRESSURE",
		size = 12,
		color = if pityArmed then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		position = UDim2.fromOffset(10, 5),
		sizeConstraint = UDim2.new(0.65, -10, 0, 15),
	}), React.createElement(Text, {
		value = if pityArmed then "PRIMED" else `{pityMisses} / {pityAfter}`,
		size = 12,
		color = if pityArmed then Palette.mango else Palette.creamSoft,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		position = UDim2.new(0.65, 0, 0, 5),
		sizeConstraint = UDim2.new(0.35, -10, 0, 15),
	}), React.createElement(Meter, {
		value = pityFill,
		color = if pityArmed then Palette.mango else Palette.violet,
		reducedMotion = reducedMotion,
		shimmer = pityArmed,
		position = UDim2.fromOffset(10, if compact then 27 else 31),
		size = UDim2.new(1, -20, 0, if compact then 6 else 7),
	}))), React.createElement(Button, {
		text = if controller.spinning then "SPINNING" elseif canSpin then (if pityArmed then (if compact then "SPIN · PITY" else "SPIN · PITY ARMED") elseif compact then "SPIN WHEEL" else "SPIN PRIZE WHEEL") else "DRAW NOT READY",
		icon = "Wheel",
		onClick = onSpin,
		color = if canSpin and not controller.spinning then Palette.mango else Palette.panelSoft,
		textColor = if canSpin and not controller.spinning then Palette.ink else Palette.muted,
		size = UDim2.new(1, -edge * 2, 0, buttonHeight),
		position = UDim2.new(0, edge, 1, -(buttonHeight + buttonBottom)),
		reducedMotion = reducedMotion,
		disabled = controller.spinning or not canSpin,
		highlight = canSpin and not controller.spinning,
	}))
end
local function WheelView(props)
	local _binding = props
	local state = _binding.state
	local config = _binding.config
	local reducedMotion = _binding.reducedMotion
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local antilag = useAntilag()
	local controller = useWheelController(props)
	local rewards = config.Wheel.Rewards
	local landscape = chrome.landscape or (viewport.width > viewport.height * 1.35 and viewport.height < 680)
	local shortLandscape = landscape and viewport.width >= 480 and viewport.width < 900 and viewport.height <= 430
	local split = shortLandscape or (not chrome.contentStack and viewport.width >= 720)
	local narrowPortrait = not landscape and viewport.width <= 360
	local widthCap = if shortLandscape then viewport.width * 0.4 - 18 elseif split then viewport.width * (if landscape then 0.43 else 0.48) - 54 else viewport.width - 58
	local heightCap = if shortLandscape then viewport.height - 105 elseif landscape then viewport.height - 250 elseif split then viewport.height - 390 else viewport.height - 300
	local wheelDiameter = math.floor(if shortLandscape then math.clamp(math.min(widthCap, heightCap), 190, 220) else math.clamp(math.min(widthCap, heightCap), if chrome.contentStack then 226 else 264, if split then 410 else 340))
	local headerH = if shortLandscape then 52 elseif narrowPortrait then 78 elseif chrome.contentStack then 66 else 60
	local consoleH = if shortLandscape then 198 elseif chrome.contentStack then 230 else 232
	local stageH = if split then math.max(wheelDiameter, consoleH) else wheelDiameter + 16 + consoleH
	local panelH = headerH + stageH + Layout.cardPadding * 2
	local headerReveal = useStagger(0, reducedMotion)
	local _result
	if controller.winner >= 0 then
		local _result_1 = rewards[controller.winner + 1]
		if _result_1 ~= nil then
			_result_1 = _result_1.Color
		end
		local _condition = _result_1
		if _condition == nil then
			_condition = Palette.mango
		end
		_result = _condition
	else
		_result = Palette.mango
	end
	local accent = _result
	local headline = if narrowPortrait then "Spin it. Win something." else "Your next prize is one spin away."
	local descriptor = if narrowPortrait then `{#rewards} prizes / rare-win protection` else `{#rewards} prizes  /  better odds after every miss`
	local containedEffects = chrome.portrait or shortLandscape or viewport.width <= 420 or (landscape and viewport.height <= 480)
	return React.createElement(PageScaffold, {
		gap = 0,
		tailPad = scrollTail(chrome.stack, chrome.bottomSafe, 40),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = {
			{
				id = "wheel",
				height = panelH,
				element = React.createElement(Panel, {
					size = UDim2.fromScale(1, 1),
					accent = accent,
					background = Palette.panelRaised,
					padding = Layout.cardPadding,
					reveal = headerReveal,
					clips = false,
				}, React.createElement(Text, {
					value = "PRIZE WHEEL",
					size = if shortLandscape then 9 else 10,
					color = Palette.mango,
					weight = Enum.FontWeight.Heavy,
					fit = false,
					sizeConstraint = UDim2.new(1, 0, 0, if shortLandscape then 14 else 16),
				}), React.createElement(Text, {
					value = headline,
					size = if shortLandscape then 16 elseif chrome.contentStack then 18 else 21,
					color = Palette.cream,
					weight = Enum.FontWeight.Heavy,
					fit = true,
					minSize = if narrowPortrait then 10 else 15,
					wrap = narrowPortrait,
					position = UDim2.fromOffset(0, if shortLandscape then 14 else 18),
					sizeConstraint = UDim2.new(1, 0, 0, if narrowPortrait then 36 elseif shortLandscape then 22 else 28),
				}), React.createElement(Text, {
					value = descriptor,
					size = if narrowPortrait then 9 else 10,
					color = Palette.muted,
					fit = not narrowPortrait,
					wrap = narrowPortrait,
					position = UDim2.fromOffset(0, if narrowPortrait then 57 elseif shortLandscape then 36 else 46),
					sizeConstraint = UDim2.new(1, 0, 0, if narrowPortrait then 18 else 16),
				}), React.createElement("frame", {
					Size = UDim2.fromOffset(wheelDiameter, wheelDiameter),
					Position = if split then UDim2.new(0.25, 0, 0, headerH + stageH / 2) else UDim2.new(0.5, 0, 0, headerH),
					AnchorPoint = if split then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ClipsDescendants = false,
				}, React.createElement(PrizeWheelMachine, {
					rewards = rewards,
					controller = controller,
					diameter = wheelDiameter,
					canSpin = state.Wheel.CanSpin == true,
					reducedMotion = reducedMotion,
					containedEffects = containedEffects,
				})), React.createElement("frame", {
					Size = if split then UDim2.new(0.48, -10, 0, consoleH) else UDim2.new(1, 0, 0, consoleH),
					Position = if split then UDim2.new(0.52, 10, 0, headerH + (stageH - consoleH) / 2) else UDim2.fromOffset(0, headerH + wheelDiameter + 16),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, React.createElement(WheelConsole, {
					state = state,
					config = config,
					controller = controller,
					onSpin = controller.spin,
					height = consoleH,
					reducedMotion = reducedMotion,
					compact = shortLandscape,
				}))),
			},
		},
	})
end
return {
	WheelView = WheelView,
}
