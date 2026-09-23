-- Reactor (Anomaly) view — rewritten for clearer visual hierarchy and feedback while keeping
-- the underlying game loop identical to before: pulse the core to charge it, bank a full core
-- for a stabilization + reward, spend fragments on a temporary surge, tune which channel a
-- pulse strengthens, work shift-job directives for bonus rewards, and buy permanent protocol
-- upgrades. Every dispatch action, payload shape, and the state comparator at the bottom are
-- unchanged from the prior implementation — this only restructures how it's presented.
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Audio = require(script.Parent.Parent.audio).Audio
local useUnixDeadline = require(script.Parent.Parent.deadlines).useUnixDeadline
local _format = require(script.Parent.Parent.format)
local compactNumber = _format.compactNumber
local clockText = _format.clockText
local formatReward = _format.formatReward
local gteFlux = _format.gteFlux
local scaledCost = _format.scaledCost
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.Parent.input.GamepadNavigationService)
local FlatList = require(script.Parent.Parent.virtualizedList).FlatList
local _motion = require(script.Parent.Parent.motion)
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useFlash = _motion.useFlash
local useFlipperSpring = _motion.useFlipperSpring
local useGlowStroke = _motion.useGlowStroke
local usePulse = _motion.usePulse
local useStagger = _motion.useStagger
local useViewport = _motion.useViewport
local useWallClock = _motion.useWallClock
local _theme = require(script.Parent.Parent.theme)
local chromeFor = _theme.chromeFor
local darken = _theme.darken
local ensureContrast = _theme.ensureContrast
local Layout = _theme.Layout
local lighten = _theme.lighten
local Palette = _theme.Palette
local scrollTail = _theme.scrollTail
local surfaceGradient = _theme.surfaceGradient
local TapTarget = _theme.TapTarget
local PageScaffold = require(script.Parent.Parent.pageScaffold).PageScaffold
local _ui = require(script.Parent.Parent.ui)
local Badge = _ui.Badge
local Button = _ui.Button
local EmptyState = _ui.EmptyState
local measureWrappedTextHeight = _ui.measureWrappedTextHeight
local Meter = _ui.Meter
local Panel = _ui.Panel
local SectionLabel = _ui.SectionLabel
local Text = _ui.Text
local GAP = Layout.panelGap -- desktop-friendly section breathing room
local ACTION_FAILSAFE = 8
local CHANNEL_CARD_H = 84
local CHANNEL_CARD_MIN_W = 160
local CHANNEL_DECK_HEADER_H = 70
local SECTION_LABEL_H = 28
-- Shared by ChannelDeck (actual rendering) and ReactorConsole (PageScaffold section height)
-- so both always agree on how many rows the channel grid takes — computing this in two places
-- that could independently drift is exactly what caused the desktop dock/sidebar overlap bug
-- earlier, so there is deliberately only one formula for it.
local function channelGridCols(stack, width)
	return if stack then 1 else math.max(1, math.floor((width + GAP) / (CHANNEL_CARD_MIN_W + GAP)))
end
local function protocolCost(protocol, level)
	return scaledCost(protocol.BaseCost, protocol.CostScale, level)
end
local function sameReward(left, right)
	if left == right then
		return true
	end
	if left == nil or right == nil then
		return false
	end
	return left.Cash == right.Cash and left.CashMinutes == right.CashMinutes and left.Stardust == right.Stardust and left.Cores == right.Cores and left.Boost == right.Boost and left.Signals == right.Signals and left.CommandXP == right.CommandXP and left.StreakShield == right.StreakShield
end
-- A failsafe-armed action button: presses immediately show a "working" state, and re-arm
-- automatically if the server hasn't answered within ACTION_FAILSAFE seconds, so a dropped
-- response can never leave a control stuck looking busy forever. onResponse (optional) runs off
-- the SAME dispatch call the arming uses, so a caller that also wants to react to the response
-- (spawn a feedback pop, etc.) never has to fire a second, duplicate dispatch just to see it.
local function useArmedAction(resetKeys)
	local armed, setArmed = React.useState(false)
	React.useEffect(function()
		return setArmed(false)
	end, resetKeys)
	React.useEffect(function()
		if not armed then
			return nil
		end
		local failsafe = task.delay(ACTION_FAILSAFE, function()
			return setArmed(false)
		end)
		return function()
			return task.cancel(failsafe)
		end
	end, { armed })
	local run = function(dispatch, action, payload, guard, onResponse)
		if not guard or armed then
			return nil
		end
		setArmed(true)
		dispatch(action, payload, function(response)
			if not response.ok then
				setArmed(false)
			end
			local _result = onResponse
			if _result ~= nil then
				_result(response)
			end
		end)
	end
	return { armed, run }
end
-- Reactor-local feedback pops: floating text driven directly off each dispatch response
-- (accuracy, charge amount, stabilize reward, tier-ups), not a decorative idle loop — nothing
-- here plays unless a real server-confirmed event just happened. Kept local to this view rather
-- than routed through the app-wide EffectLayer/pop system, which isn't threaded into page props.
local reactorPopSeed = 0
-- A full-width sweep banner for the rarest reactor moment (a Core Tier level-up), separate from
-- the small floating pops since it deserves more presence — appears, holds, then slides away on
-- its own; the caller only ever sets it in response to a TiersGained > 0 dispatch response.
local function TierUpBanner(_param)
	local tier = _param.tier
	local onDone = _param.onDone
	local clock = useClock(true, 1, 1000, true)
	local doneRef = React.useRef(onDone)
	doneRef.current = onDone
	React.useEffect(function()
		local timeout = task.delay(2.2, function()
			return doneRef.current()
		end)
		return function()
			return task.cancel(timeout)
		end
	end, {})
	local enter = clock:map(function(seconds)
		return easeOutBack(math.clamp(seconds / 0.3, 0, 1))
	end)
	local exit = clock:map(function(seconds)
		return math.clamp((seconds - 1.8) / 0.4, 0, 1)
	end)
	local scaleAmount = React.joinBindings({
		enter = enter,
		exit = exit,
	}):map(function(_param_1)
		local inAmount = _param_1.enter
		local outAmount = _param_1.exit
		return inAmount * (1 - outAmount)
	end)
	local fade = React.joinBindings({
		enter = enter,
		exit = exit,
	}):map(function(_param_1)
		local inAmount = _param_1.enter
		local outAmount = _param_1.exit
		return 1 - math.min(inAmount, 1 - outAmount)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = fade:map(function(amount)
			return 0.28 + amount * 0.72
		end),
		BorderSizePixel = 0,
		ZIndex = 30,
	}, React.createElement(ScaleFromCenter, {
		scale = scaleAmount,
		zIndex = 31,
	}, React.createElement(Text, {
		value = "CORE TIER UP",
		size = 13,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0.5, -150, 0.5, -36),
		sizeConstraint = UDim2.fromOffset(300, 16),
		transparency = fade,
		zIndex = 31,
	}), React.createElement(Text, {
		value = `TIER {tier}`,
		size = 32,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.new(0.5, -150, 0.5, -8),
		sizeConstraint = UDim2.fromOffset(300, 40),
		transparency = fade,
		zIndex = 31,
	})))
end
local function useReactorPops()
	local pops, setPops = React.useState({})
	local spawn = function(text, color, options)
		reactorPopSeed += 1
		local id = reactorPopSeed
		local offsetX = (reactorPopSeed % 5 - 2) * 14
		setPops(function(current)
			local _array = {}
			local _length = #_array
			local _currentLength = #current
			table.move(current, 1, _currentLength, _length + 1, _array)
			_length += _currentLength
			local _object = {
				id = id,
				text = text,
			}
			local _left = "sub"
			local _result = options
			if _result ~= nil then
				_result = _result.sub
			end
			_object[_left] = _result
			_object.color = color
			local _left_1 = "big"
			local _result_1 = options
			if _result_1 ~= nil then
				_result_1 = _result_1.big
			end
			local _condition = _result_1
			if _condition == nil then
				_condition = false
			end
			_object[_left_1] = _condition
			_object.offsetX = offsetX
			_array[_length + 1] = _object
			local updated = _array
			local _result_2
			if #updated > 6 then
				-- ▼ ReadonlyArray.filter ▼
				local _newValue = {}
				local _callback = function(_, index)
					return index >= #updated - 6
				end
				local _length_1 = 0
				for _k, _v in updated do
					if _callback(_v, _k - 1, updated) == true then
						_length_1 += 1
						_newValue[_length_1] = _v
					end
				end
				-- ▲ ReadonlyArray.filter ▲
				_result_2 = _newValue
			else
				_result_2 = updated
			end
			return _result_2
		end)
		task.delay(1.1, function()
			return setPops(function(current)
				-- ▼ ReadonlyArray.filter ▼
				local _newValue = {}
				local _callback = function(pop)
					return pop.id ~= id
				end
				local _length = 0
				for _k, _v in current do
					if _callback(_v, _k - 1, current) == true then
						_length += 1
						_newValue[_length] = _v
					end
				end
				-- ▲ ReadonlyArray.filter ▲
				return _newValue
			end)
		end)
	end
	return { pops, spawn }
end
local function ReactorPop(_param)
	local pop = _param.pop
	local clock = useClock(true, 1, 1000, true)
	local rise = clock:map(function(seconds)
		local progress = easeOutCubic(math.clamp(seconds / 1.1, 0, 1))
		return UDim2.new(0.5, pop.offsetX, 0.5, -math.floor(progress * (if pop.big then 90 else 60)))
	end)
	local fade = clock:map(function(seconds)
		return math.clamp((seconds - 0.55) / 0.45, 0, 1)
	end)
	local scale = clock:map(function(seconds)
		return 0.6 + easeOutBack(math.clamp(seconds / 0.18, 0, 1)) * 0.4
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(220, 50),
		Position = rise,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 12,
	}, React.createElement(Text, {
		value = pop.text,
		size = if pop.big then 24 else 17,
		color = pop.color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		transparency = fade,
		zIndex = 12,
	}), pop.sub ~= nil and React.createElement(Text, {
		value = pop.sub,
		size = 10,
		color = lighten(pop.color, 0.3),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, if pop.big then 26 else 20),
		sizeConstraint = UDim2.new(1, 0, 0, 14),
		transparency = fade,
		zIndex = 12,
	})))
end
local function StatPill(_param)
	local label = _param.label
	local value = _param.value
	local accent = _param.accent
	return React.createElement("frame", {
		Size = UDim2.fromOffset(84, 44),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 1,
		Transparency = 0.62,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), React.createElement(Text, {
		value = label,
		size = 9,
		color = Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 7,
		position = UDim2.fromOffset(6, 6),
		sizeConstraint = UDim2.new(1, -12, 0, 12),
	}), React.createElement(Text, {
		value = value,
		size = 16,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 11,
		position = UDim2.fromOffset(6, 20),
		sizeConstraint = UDim2.new(1, -12, 0, 20),
	}))
end
-- A small dot that travels around the outer ring marking the timing window, purely as a
-- client-side prediction of the exact same math the server independently recomputes on every
-- PulseAnomaly call. The server never trusts anything this implies about timing -- it works out
-- accuracy itself from its own clock and its own record of when the current window started.
-- This is cosmetic guidance for the player, not an input to anything the server checks.
--
-- Rides along the ring itself (radius tied to the frame it's placed in) rather than a
-- center-pivoted needle, so it can never visually extend past the ring's own bounds regardless
-- of the core's size.
local function PulseWindowNeedle(_param)
	local accent = _param.accent
	local startedAt = _param.startedAt
	local periodSeconds = _param.periodSeconds
	local sweetZone = _param.sweetZone
	local animate = _param.animate
	local period = math.max(0.1, periodSeconds)
	local anchor = if type(startedAt) == "number" then startedAt else 0
	-- Drive the needle from Workspace:GetServerTimeNow so client prediction stays
	-- locked to the same Roblox-synced clock the server stamps into PulseWindowStartedAt.
	local heartbeat = useClock(animate, 1, 1000, true)
	local fraction = heartbeat:map(function()
		local elapsed = (Workspace:GetServerTimeNow() - anchor) % period
		return elapsed / period
	end)
	local inSweetZone = fraction:map(function(value)
		return value >= 1 - sweetZone
	end)
	local dotPosition = fraction:map(function(value)
		local rad = value * math.pi * 2 - math.pi / 2
		return UDim2.new(0.5 + math.cos(rad) * 0.5, 0, 0.5 + math.sin(rad) * 0.5, 0)
	end)
	local sweetZoneDeg = sweetZone * 360
	local cuePulse = usePulse(animate, 2.4)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = -90 - sweetZoneDeg,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.mint,
		Thickness = 4,
		Transparency = inSweetZone:map(function(hit)
			return if hit then 0.12 else 0.38
		end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1 - sweetZoneDeg / 360, 1), NumberSequenceKeypoint.new(1, 0.05) }),
	})))), React.createElement("frame", {
		Size = UDim2.fromOffset(13, 13),
		Position = dotPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = inSweetZone:map(function(hit)
			return if hit then Palette.mint else Palette.cream
		end),
		BorderSizePixel = 0,
		ZIndex = 7,
	}, React.createElement("uiscale", {
		Scale = inSweetZone:map(function(hit)
			return if hit then 1.35 else 1
		end),
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1.7, 1.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = inSweetZone:map(function(hit)
			return if hit then Palette.mint else accent
		end),
		BackgroundTransparency = inSweetZone:map(function(hit)
			return if hit then 0.4 else 0.72
		end),
		BorderSizePixel = 0,
		ZIndex = 6,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))), React.createElement("frame", {
		Size = UDim2.fromOffset(72, 18),
		Position = UDim2.new(0.5, 0, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = inSweetZone:map(function(hit)
			return if hit then 0.15 else 0.55
		end),
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 6),
	}), React.createElement("uiscale", {
		Scale = React.joinBindings({ hit = inSweetZone, pulse = cuePulse }):map(function(values)
			if values.hit then
				return 1 + values.pulse * 0.06
			end
			return 1
		end),
	}), React.createElement(Text, {
		value = inSweetZone:map(function(hit)
			return if hit then "HIT NOW" else "WAIT"
		end),
		size = 10,
		color = inSweetZone:map(function(hit)
			return if hit then Palette.mint else Palette.muted
		end),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = true,
		minSize = 8,
		position = UDim2.fromOffset(2, 1),
		sizeConstraint = UDim2.new(1, -4, 1, -2),
		zIndex = 9,
	})))
end
local function ComboBadgeHot(_param)
	local size = _param.size
	local combo = _param.combo
	local animate = _param.animate
	local heat = math.clamp(combo / 12, 0, 1)
	local color = Palette.mint:Lerp(Palette.mango, heat)
	local pulse = usePulse(animate and combo >= 5, 1.1 + heat * 1.6)
	local badgeScale = pulse:map(function(amount)
		return 1 + heat * 0.06 * amount
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(math.floor(size * 0.5), 22),
		Position = UDim2.new(0.5, 0, 0, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement("uiscale", {
		Scale = badgeScale,
	}), React.createElement(Badge, {
		value = `COMBO x{combo}`,
		accent = color,
		filled = true,
		size = UDim2.fromScale(1, 1),
	}))
end
-- The reactor core: bigger and more dynamic than the old fixed dial, with a spinning ring that
-- speeds up as charge fills and a distinct visual state for "ready to bank" vs "charging".
local function ReactorCore(_param)
	local size = _param.size
	local accent = _param.accent
	local charge = _param.charge
	local ready = _param.ready
	local animate = _param.animate
	local decorate = _param.decorate
	if decorate == nil then
		decorate = animate
	end
	local motionAmount = _param.motionAmount
	local pulseWindowStartedAt = _param.pulseWindowStartedAt
	local pulseWindowSeconds = _param.pulseWindowSeconds
	local pulseWindowSweetZone = _param.pulseWindowSweetZone
	local combo = _param.combo
	-- Spin/ready pulse are decorative; pulse-window needle stays on `animate` for gameplay timing.
	local spin = useClock(decorate, 0.1 + charge * 0.42 + motionAmount * 0.22, 360, true)
	local readyGlow = useGlowStroke(ready, not decorate, 0.22, 0.14, 0.42, 1.5)
	local pulse = usePulse(ready and decorate, 1.65)
	local core = math.floor(size * 0.56)
	local ringInset = math.floor(size * 0.06)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(amount)
			return if ready then 1 + amount * 0.018 else 1
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2,
		Transparency = readyGlow,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})), React.createElement("frame", {
		Size = UDim2.new(1, -ringInset * 2, 1, -ringInset * 2),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Rotation = spin,
		ClipsDescendants = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = accent,
		Thickness = 2.5,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 0.15) }),
	})))), React.createElement("frame", {
		Size = UDim2.fromOffset(core, core),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 3,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(accent, 0.2), darken(accent, 0.28)),
		Rotation = 130,
	}), React.createElement(Text, {
		value = if ready then "READY" else `{math.floor(charge * 100 + 0.5)}%`,
		size = math.floor(core * 0.24),
		color = ensureContrast(accent, Palette.ink),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 4,
	})), not ready and React.createElement("frame", {
		Size = UDim2.new(1, -ringInset * 2, 1, -ringInset * 2),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(PulseWindowNeedle, {
		accent = accent,
		startedAt = pulseWindowStartedAt,
		periodSeconds = pulseWindowSeconds,
		sweetZone = pulseWindowSweetZone,
		animate = animate,
	})), combo <= 0 and React.createElement("frame", {
		Size = UDim2.fromOffset(math.floor(size * 0.66), 22),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, React.createElement(Badge, {
		value = "LIVE",
		accent = accent,
		filled = true,
		size = UDim2.fromScale(1, 1),
	})), combo > 0 and React.createElement(ComboBadgeHot, {
		size = size,
		combo = combo,
		animate = decorate,
	}))
end
-- slotIndex is 1-based when the channel is currently slotted (shown as a numbered badge so
-- players can see which of their up-to-LoadoutSlots picks each card is), or undefined when not
-- slotted. atCapacity disables tapping an unslotted card once the loadout is already full,
-- rather than silently no-opping — the button greys out so it reads as "full" not "broken."
local function ChannelCard(_param)
	local id = _param.id
	local name = _param.name
	local detail = _param.detail
	local color = _param.color
	local slotIndex = _param.slotIndex
	local atCapacity = _param.atCapacity
	local onToggle = _param.onToggle
	local width = _param.width
	local selected = slotIndex ~= nil
	local disabled = not selected and atCapacity
	local hovered, setHovered = React.useState(false)
	local antilag = useAntilag()
	-- Channel cards mount several springs; snap when ambient motion is cut.
	local emphasis = useFlipperSpring(if selected then 1 elseif hovered then 0.4 else 0, not antilag.allowAmbient, 420, 32)
	return React.createElement("frame", {
		Size = width,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement("imagebutton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = not disabled,
		Event = {
			MouseEnter = function()
				setHovered(true)
				Audio:play("hover")
			end,
			MouseLeave = function()
				return setHovered(false)
			end,
			Activated = function()
				if disabled then
					return nil
				end
				Audio:play(if selected then "toggleOff" else "toggleOn")
				onToggle()
			end,
		},
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = emphasis:map(function(amount)
			return Palette.panel:Lerp(darken(color, 0.55), math.clamp(amount, 0, 1))
		end),
		BackgroundTransparency = if disabled then 0.35 else 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 10),
	}), React.createElement("uistroke", {
		Color = color,
		Thickness = if selected then 1.5 else 1,
		Transparency = emphasis:map(function(amount)
			return (if disabled then 0.85 else 0.72) - math.clamp(amount, 0, 1) * 0.42
		end),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(3, 24),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = color,
		BackgroundTransparency = emphasis:map(function(amount)
			return 1 - math.clamp(amount, 0, 1)
		end),
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement(Text, {
		value = name,
		size = 13,
		color = if disabled then Palette.muted else Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		minSize = 10,
		position = UDim2.fromOffset(12, 8),
		sizeConstraint = UDim2.new(1, -34, 0, 18),
	}), React.createElement(Text, {
		value = detail,
		size = 10,
		color = if disabled then Palette.muted else Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(12, 28),
		sizeConstraint = UDim2.new(1, -20, 0, 44),
	}), selected and React.createElement("frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, -10, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement(Text, {
		value = tostring(slotIndex),
		size = 12,
		color = ensureContrast(color, Palette.ink),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
		zIndex = 3,
	})))))
end
-- Replaces the old single-Channel selection with a loadout: up to config.LoadoutSlots channels
-- active simultaneously, each still applying its own effect (summed server-side). Tapping a
-- slotted channel unslots it; tapping an empty one adds it to the end of the loadout (rejected
-- server-side, and the button disables client-side too, once the loadout is already full).
local function LoadoutDeck(_param)
	local anomaly = _param.anomaly
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local stack = _param.stack
	local width = _param.width
	local order = _param.order
	local channels = {}
	for id, channel in pairs(config.Channels) do
		local _arg0 = {
			id = id,
			name = channel.Name,
			detail = channel.Description,
			color = channel.Color,
		}
		table.insert(channels, _arg0)
	end
	table.sort(channels, function(left, right)
		return left.id < right.id
	end)
	local _condition = config.LoadoutSlots
	if _condition == nil then
		_condition = 3
	end
	local slots = _condition
	local serverLoadout = anomaly.Loadout or (if anomaly.Channel ~= nil then { anomaly.Channel } else {})
	-- SetAnomalyLoadout has a 0.3s server cooldown, but toggling channels is a multi-click
	-- interaction (picking up to 3 of them in quick succession) -- dispatching on every click let
	-- a normal fast tap sequence outrun the cooldown, each rejection logging a firewall warning
	-- with nothing telling the player why their later clicks did nothing. Track the loadout
	-- locally so every click updates instantly, and debounce the actual dispatch to one call that
	-- carries whatever the loadout looks like once clicking settles down, the same pattern
	-- TradeView's queueOffer already uses for the same class of problem.
	local draftLoadout, setDraftLoadout = React.useState(nil)
	local flushRef = React.useRef(nil)
	React.useEffect(function()
		return function()
			if flushRef.current ~= nil then
				task.cancel(flushRef.current)
			end
		end
	end, {})
	local loadout = draftLoadout or serverLoadout
	local atCapacity = #loadout >= slots
	local toggle = function(channelId)
		local _channelId = channelId
		local index = (table.find(loadout, _channelId) or 0) - 1
		local nextLoadout
		if index >= 0 then
			-- ▼ ReadonlyArray.filter ▼
			local _newValue = {}
			local _callback = function(entry)
				return entry ~= channelId
			end
			local _length = 0
			for _k, _v in loadout do
				if _callback(_v, _k - 1, loadout) == true then
					_length += 1
					_newValue[_length] = _v
				end
			end
			-- ▲ ReadonlyArray.filter ▲
			nextLoadout = _newValue
		else
			if atCapacity then
				return nil
			end
			local _array = {}
			local _length = #_array
			local _loadoutLength = #loadout
			table.move(loadout, 1, _loadoutLength, _length + 1, _array)
			_length += _loadoutLength
			_array[_length + 1] = channelId
			nextLoadout = _array
		end
		setDraftLoadout(nextLoadout)
		if flushRef.current ~= nil then
			task.cancel(flushRef.current)
		end
		flushRef.current = task.delay(0.32, function()
			flushRef.current = nil
			dispatch("SetAnomalyLoadout", {
				Loadout = nextLoadout,
			}, function()
				return setDraftLoadout(nil)
			end)
		end)
	end
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(channel)
		return channel.id == loadout[1]
	end
	local _result
	for _i, _v in channels do
		if _callback(_v, _i - 1, channels) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _result_1 = _result
	if _result_1 ~= nil then
		_result_1 = _result_1.color
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = Palette.cyan
	end
	local accentColor = _condition_1
	-- Columns are derived from the panel's actual available width (min card width ~150px)
	-- instead of a hardcoded count, so cards never get squeezed into a row narrower than they
	-- need — the exact class of bug that made the old Workshop grid cards overlap their own
	-- buttons once the card was narrower than the layout assumed.
	local cols = channelGridCols(stack, width)
	local cardWidth = UDim2.new(1 / cols, if cols > 1 then -(GAP * (cols - 1)) / cols else 0, 0, CHANNEL_CARD_H)
	local rows = math.ceil(#channels / cols)
	local railHeight = rows * CHANNEL_CARD_H + math.max(0, rows - 1) * GAP
	local height = CHANNEL_DECK_HEADER_H + railHeight
	local _exp = React.createElement(Text, {
		value = "REACTOR TUNING",
		size = 10,
		color = Palette.cyan,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(0, 200, 0, 15),
	})
	local _exp_1 = React.createElement(Text, {
		value = `{#loadout} / {slots} SLOTTED`,
		size = 9,
		color = if atCapacity then Palette.mango else Palette.muted,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Right,
		fit = false,
		position = UDim2.new(1, -100, 0, 0),
		sizeConstraint = UDim2.new(0, 100, 0, 15),
	})
	local _exp_2 = React.createElement(Text, {
		value = "Slot up to 3 channels — each keeps its own bonus while active.",
		size = 12,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 18),
	})
	local _exp_3 = React.createElement("uigridlayout", {
		CellSize = cardWidth,
		CellPadding = UDim2.new(0, GAP, 0, GAP),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = cols,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#channels)
	local _callback_1 = function(channel)
		local _id = channel.id
		local slotIndex = (table.find(loadout, _id) or 0) - 1
		return React.createElement(ChannelCard, {
			key = channel.id,
			id = channel.id,
			name = channel.name,
			detail = channel.detail,
			color = channel.color,
			slotIndex = if slotIndex >= 0 then slotIndex + 1 else nil,
			atCapacity = atCapacity,
			onToggle = function()
				return toggle(channel.id)
			end,
			width = UDim2.fromScale(1, 1),
		})
	end
	for _k, _v in channels do
		_newValue[_k] = _callback_1(_v, _k - 1, channels)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = accentColor,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = order,
		clips = false,
	}, _exp, _exp_1, _exp_2, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, railHeight),
		Position = UDim2.fromOffset(0, CHANNEL_DECK_HEADER_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp_3, _newValue))
end
local OVERDRIVE_BAR_H = 108
-- A server-wide (not per-player) meter: every player's pulses and stabilizations on this
-- server add to the same bar. Filling it grants everyone a timed production bonus. Purely
-- informational on the client -- the server tracks and validates the actual meter, this just
-- renders whatever AnomalyState.Overdrive currently says.
local function OverdriveBar(_param)
	local overdrive = _param.overdrive
	local order = _param.order
	local _result = overdrive
	if _result ~= nil then
		_result = _result.Active
	end
	local timer = useWallClock(_result == true)
	if overdrive == nil then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			LayoutOrder = order,
		})
	end
	local fill = math.clamp(overdrive.Charge / math.max(1, overdrive.Target), 0, 1)
	local accent = if overdrive.Active then Palette.mango else Palette.mint
	local remaining = timer:map(function(seconds)
		return clockText(math.max(0, overdrive.BonusEndsAt - seconds))
	end)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, OVERDRIVE_BAR_H),
		accent = accent,
		background = Palette.panelRaised,
		padding = 14,
		layoutOrder = order,
		highlight = overdrive.Active,
		clips = false,
	}, React.createElement(Text, {
		value = "SERVER OVERDRIVE",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 2),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Text, {
		value = if overdrive.Active then remaining:map(function(label)
			return `ACTIVE · {label} LEFT · ×{string.format("%.2f", overdrive.Multiplier)} PRODUCTION SERVER-WIDE`
		end) else "Everyone's pulses and stabilizations fill this bar together.",
		size = 11,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, 20),
		sizeConstraint = UDim2.new(1, 0, 0, 28),
	}), React.createElement(Meter, {
		value = fill,
		color = accent,
		position = UDim2.fromOffset(0, 52),
		size = UDim2.new(1, 0, 0, 8),
		shimmer = overdrive.Active,
	}), React.createElement(Text, {
		value = if overdrive.Active then "OVERDRIVE!" else `{compactNumber(overdrive.Charge)} / {compactNumber(overdrive.Target)}`,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		position = UDim2.fromOffset(0, 64),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}))
end
local function coreTierDescription(nextTier)
	return if nextTier ~= nil then `Raises the charge ceiling and adds +{string.format("%.0f", nextTier.PassiveProduction * 100)}% passive production.` else "Maximum Core Tier reached."
end
-- Was a fixed 84px guess that only fit the description at its shortest real value (a 0% or
-- single-digit passive bonus) -- a longer bonus string, or the same string on a narrower phone
-- column, wraps to a second line the fixed box never accounted for, pushing the meter and XP
-- line below the panel's own bottom edge instead of growing the panel to fit. Shared by
-- CoreTierStrip (actual rendering) and ReactorConsole (canvas-height estimate) for the same
-- reason channelGridCols is shared above -- two independently-guessed heights is how the
-- dock/sidebar overlap bug happened before.
local function coreTierStripHeight(nextTier, width)
	local textWidth = math.max(40, width - 28)
	local descH = math.max(16, measureWrappedTextHeight(coreTierDescription(nextTier), textWidth, 11, Enum.FontWeight.Regular))
	local meterY = 20 + descH + 12
	return if nextTier ~= nil then meterY + 12 + 16 + 10 else meterY - 4 + 16 + 10
end
local function CoreTierStrip(_param)
	local tier = _param.tier
	local xp = _param.xp
	local nextTier = _param.nextTier
	local order = _param.order
	local width = _param.width
	local height = _param.height
	local fill = if nextTier ~= nil then math.clamp(xp / math.max(1, nextTier.RequiredXP), 0, 1) else 1
	local description = coreTierDescription(nextTier)
	local textWidth = math.max(40, width - 28)
	local descH = math.max(16, measureWrappedTextHeight(description, textWidth, 11, Enum.FontWeight.Regular))
	local descY = 20
	local meterY = descY + descH + 12
	local xpY = meterY + 12
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = Palette.violet,
		background = Palette.panel,
		padding = 14,
		layoutOrder = order,
		clips = false,
	}, React.createElement(Text, {
		value = `CORE TIER {tier}`,
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(0, 200, 0, 15),
	}), React.createElement(Text, {
		value = description,
		size = 11,
		color = Palette.creamSoft,
		wrap = true,
		fit = false,
		position = UDim2.fromOffset(0, descY),
		sizeConstraint = UDim2.new(1, 0, 0, descH),
	}), if nextTier ~= nil then React.createElement(React.Fragment, nil, React.createElement(Meter, {
		value = fill,
		color = Palette.violet,
		position = UDim2.fromOffset(0, meterY),
		size = UDim2.new(1, 0, 0, 8),
	}), React.createElement(Text, {
		value = `{compactNumber(xp)} / {compactNumber(nextTier.RequiredXP)} core XP`,
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, xpY),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	})) else React.createElement(Text, {
		value = `{compactNumber(xp)} core XP banked`,
		size = 10,
		color = Palette.violet,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, meterY - 4),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}))
end
local function DirectiveRow(_param)
	local directive = _param.directive
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local order = _param.order
	local stack = _param.stack
	local ready = not directive.Claimed and directive.Progress >= directive.Target
	local _binding = useArmedAction({ directive.Claimed })
	local armed = _binding[1]
	local run = _binding[2]
	local accent = directive.Color or Palette.mango
	local height = if stack then 184 else 156
	local collect = function()
		return run(dispatch, "ClaimAnomalyDirective", {
			Id = directive.Id,
		}, ready and not armed)
	end
	local _exp = ready and not armed and React.createElement("frame", {
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(-4, -4),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 20,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
	local _exp_1 = React.createElement(Text, {
		value = directive.Name,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 22),
	})
	local _attributes = {}
	local _condition = directive.Description
	if _condition == nil then
		_condition = "Finish this before the signal changes."
	end
	_attributes.value = _condition
	_attributes.size = 11
	_attributes.color = Palette.muted
	_attributes.wrap = true
	_attributes.position = UDim2.fromOffset(0, 27)
	_attributes.sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 34)
	local _exp_2 = React.createElement(Text, _attributes)
	local _attributes_1 = {}
	local _exp_3 = compactNumber(directive.Progress)
	local _exp_4 = compactNumber(directive.Target)
	local _condition_1 = directive.Fragments
	if _condition_1 == nil then
		_condition_1 = 0
	end
	_attributes_1.value = `{_exp_3} / {_exp_4}  ·  {_condition_1} fragments`
	_attributes_1.size = 12
	_attributes_1.color = accent
	_attributes_1.weight = Enum.FontWeight.Bold
	_attributes_1.fit = false
	_attributes_1.position = UDim2.fromOffset(0, if stack then 66 else 64)
	_attributes_1.sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 18)
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = accent,
		background = Palette.panel,
		padding = 14,
		layoutOrder = order,
		interactive = true,
		highlight = ready and not armed,
		reducedMotion = reducedMotion,
		clips = false,
	}, _exp, _exp_1, _exp_2, React.createElement(Text, _attributes_1), React.createElement(Meter, {
		value = math.clamp(directive.Progress / math.max(1, directive.Target), 0, 1),
		color = accent,
		position = UDim2.fromOffset(0, if stack then 90 else 88),
		size = UDim2.new(1, if stack then 0 else -220, 0, 7),
		reducedMotion = reducedMotion,
		shimmer = ready,
	}), formatReward(directive.Reward) ~= "" and React.createElement(Text, {
		value = formatReward(directive.Reward),
		size = 12,
		color = Palette.creamSoft,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 108 else 104),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 18),
	}), React.createElement(Button, {
		text = if directive.Claimed then "COLLECTED" elseif armed then "COLLECTING" elseif ready then "COLLECT" else "IN PROGRESS",
		icon = "Mission",
		onClick = collect,
		sound = if ready then "missionClaim" else "locked",
		color = if ready and not armed then accent else Palette.panelSoft,
		textColor = if ready and not armed then Palette.ink else Palette.muted,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(198, 44),
		position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -198, 0.5, -22),
		disabled = not ready or armed,
		reducedMotion = reducedMotion,
		highlight = ready and not armed,
	}))
end
local function ProtocolRow(_param)
	local protocol = _param.protocol
	local level = _param.level
	local fragments = _param.fragments
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local order = _param.order
	local stack = _param.stack
	local cost = protocolCost(protocol, level)
	-- MaxLevel on reactor protocols is ENDLESS_LEVEL_CAP (9 quadrillion) -- these are meant to
	-- keep leveling forever, not cap out. level/MaxLevel against a 9-quadrillion denominator is
	-- indistinguishable from 0 no matter how many levels a player actually owns, so the meter
	-- never visibly moved and the badge showed a meaningless 9-quadrillion "max." Progress here
	-- is fragments saved toward the NEXT level's cost instead, which is the only ceiling that
	-- actually exists for an endless upgrade.
	local maxed = level >= protocol.MaxLevel
	local _binding = useArmedAction({ level, fragments })
	local armed = _binding[1]
	local run = _binding[2]
	local affordable = gteFlux(fragments, cost) and not maxed and not armed
	local height = if stack then 168 else 132
	local _result
	if type(cost) == "number" then
		_result = cost
	else
		local _condition = tonumber(cost)
		if _condition == nil then
			_condition = 1
		end
		_result = _condition
	end
	local costNumber = _result
	local progress = if maxed then 1 else math.clamp(fragments / math.max(1, costNumber), 0, 1)
	local tune = function()
		return run(dispatch, "BuyAnomalyProtocol", {
			Id = protocol.Id,
		}, affordable)
	end
	return React.createElement(Panel, {
		size = UDim2.new(1, 0, 0, height),
		accent = protocol.Color,
		background = Palette.panel,
		padding = 14,
		layoutOrder = order,
		interactive = not maxed,
		highlight = affordable,
		reducedMotion = reducedMotion,
		clips = false,
	}, React.createElement(Text, {
		value = protocol.Name,
		size = 16,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		fit = true,
		position = UDim2.fromOffset(0, 0),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 22),
	}), React.createElement(Text, {
		value = protocol.Description,
		size = 11,
		color = Palette.muted,
		wrap = true,
		position = UDim2.fromOffset(0, 27),
		sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 34),
	}), React.createElement(Badge, {
		value = `LEVEL {level}`,
		accent = protocol.Color,
		filled = true,
		position = UDim2.fromOffset(0, if stack then 68 else 72),
		size = UDim2.fromOffset(90, 24),
	}), React.createElement(Meter, {
		value = progress,
		color = protocol.Color,
		position = UDim2.fromOffset(0, if stack then 96 else 100),
		size = UDim2.new(1, if stack then 0 else -220, 0, 5),
		reducedMotion = reducedMotion,
		shimmer = affordable,
	}), React.createElement(Text, {
		value = if maxed then "Fully tuned" else `{compactNumber(fragments)} / {compactNumber(cost)} fragments to level up`,
		size = 11,
		color = if affordable then protocol.Color else Palette.muted,
		weight = Enum.FontWeight.Bold,
		fit = true,
		position = UDim2.fromOffset(0, if stack then 106 else 110),
		sizeConstraint = UDim2.new(1, if stack then 0 else -230, 0, 20),
	}), React.createElement(Button, {
		text = if maxed then "MAX LEVEL" elseif armed then "TUNING" elseif affordable then "TUNE UP" else `NEED {compactNumber(cost)}`,
		icon = "Research",
		onClick = tune,
		sound = if affordable then "researchUnlock" else "locked",
		color = if affordable then protocol.Color else Palette.panelSoft,
		textColor = if affordable then Palette.ink else Palette.muted,
		size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(198, 44),
		position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -198, 0.5, -22),
		disabled = not affordable,
		reducedMotion = reducedMotion,
		highlight = affordable,
	}))
end
local function ReactorConsole(_param)
	local anomaly = _param.anomaly
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	local motionAmount = _param.motionAmount
	local viewport = useViewport()
	local chrome = chromeFor(viewport)
	local stack = chrome.contentStack
	local phoneLandscape = stack and chrome.landscape
	local compactLandscape = not stack and chrome.landscape and viewport.height < 500
	local antilag = useAntilag()
	local skipEntrance = reducedMotion or antilag.skipEntrance
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local anomalyClaimHostRef = React.useRef(nil)
	-- Gamepad: park Selection on PULSE/BANK/SURGE strip.
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = anomalyClaimHostRef.current
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
	end, { anomaly.Ready, anomaly.TypeId })
	-- Cycle/surge countdowns stay live (gameplay timers). Decorative ring spin gates below.
	local timer = useWallClock(true)
	-- Needle/combo stay playable whenever motion is allowed; ring spin needs ambient + tier 2+.
	local animateCore = not reducedMotion and motionAmount > 0.03
	local decorateCore = animateCore and not softMotion
	local _exp = config.Types
	-- ▼ ReadonlyArray.find ▼
	local _callback = function(entry)
		return entry.Id == anomaly.TypeId
	end
	local _result
	for _i, _v in _exp do
		if _callback(_v, _i - 1, _exp) == true then
			_result = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local _condition = _result
	if _condition == nil then
		_condition = config.Types[1]
	end
	local activeType = _condition
	local _result_1 = activeType
	if _result_1 ~= nil then
		_result_1 = _result_1.Color
	end
	local _condition_1 = _result_1
	if _condition_1 == nil then
		_condition_1 = Palette.pink
	end
	local accent = _condition_1
	local charge = math.clamp(anomaly.Charge / math.max(1, anomaly.Target), 0, 1)
	local isSurging = useUnixDeadline(anomaly.SurgeEndsAt)
	local _binding = useArmedAction({ isSurging, anomaly.SurgeEndsAt })
	local surgeArmed = _binding[1]
	local runSurge = _binding[2]
	local _binding_1 = useArmedAction({ anomaly.Ready })
	local stabilizeArmed = _binding_1[1]
	local runStabilize = _binding_1[2]
	local canSurge = anomaly.Fragments >= config.SurgeCost and not isSurging and not surgeArmed
	local canStabilize = anomaly.Ready and not stabilizeArmed
	local cycleText = timer:map(function(timestamp)
		return `{clockText(math.max(0, anomaly.EndsAt - timestamp))} left in this signal`
	end)
	local surgeText = timer:map(function(timestamp)
		return if anomaly.SurgeEndsAt > timestamp then `SURGE  {clockText(anomaly.SurgeEndsAt - timestamp)}` elseif surgeArmed then "SURGE" else `SURGE  {config.SurgeCost}`
	end)
	local requestSurge = function()
		return runSurge(dispatch, "ActivateAnomalySurge", {}, canSurge)
	end
	-- Every effect below is fired directly from a dispatch response, never from a decorative
	-- loop -- nothing plays unless the server just confirmed a real pulse, stabilize, tier-up,
	-- or Overdrive trigger happened.
	local _binding_2 = useReactorPops()
	local pops = _binding_2[1]
	local spawnPop = _binding_2[2]
	local pulsePunch, setPulsePunch = React.useState(0)
	-- useFlash decays 1 -> 0 on its own every frame once triggered and settles back at exactly
	-- 0 -- unlike a UIScale mutated directly (scale.Scale = 1.14), which has no spring goal to
	-- return to once set that way and just stays there forever, which is what actually made the
	-- core balloon up on the first pulse and never come back down.
	local punchFlash = useFlash(pulsePunch, softMotion, 0.32)
	local coreScale = punchFlash:map(function(amount)
		return 1 + amount * 0.14
	end)
	local missFlash, setMissFlash = React.useState(0)
	local missGlow = useGlowStroke(missFlash > 0, reducedMotion, 0, 0.18, 0.72, 3.2)
	local tierUpBanner, setTierUpBanner = React.useState()
	local overdriveFlash, setOverdriveFlash = React.useState(0)
	React.useEffect(function()
		if missFlash == 0 then
			return nil
		end
		local timeout = task.delay(0.5, function()
			return setMissFlash(0)
		end)
		return function()
			return task.cancel(timeout)
		end
	end, { missFlash })
	React.useEffect(function()
		if overdriveFlash == 0 then
			return nil
		end
		spawnPop("SERVER OVERDRIVE!", Palette.mango, {
			sub = "Everyone's production surges",
			big = true,
		})
	end, { overdriveFlash })
	local requestPulse = function()
		dispatch("PulseAnomaly", {}, function(response)
			if not response.ok then
				return nil
			end
			setPulsePunch(function(current)
				return current + 1
			end)
			local _condition_2 = response.Amount
			if _condition_2 == nil then
				_condition_2 = 0
			end
			local amount = _condition_2
			if response.Accurate then
				spawnPop(`+{compactNumber(amount)}`, Palette.mint, {
					sub = "PERFECT!",
					big = true,
				})
			else
				spawnPop(`+{compactNumber(amount)}`, accent)
				local _condition_3 = anomaly.Combo
				if _condition_3 == nil then
					_condition_3 = 0
				end
				if _condition_3 > 2 then
					setMissFlash(function(current)
						return current + 1
					end)
				end
			end
			if response.OverdriveTriggered then
				setOverdriveFlash(function(current)
					return current + 1
				end)
			end
		end)
	end
	local requestStabilize = function()
		runStabilize(dispatch, "StabilizeAnomaly", {}, canStabilize, function(response)
			if not response.ok then
				return nil
			end
			local rewardBits = {}
			local _result_2 = response.Reward
			if _result_2 ~= nil then
				_result_2 = _result_2.Stardust
			end
			if _result_2 ~= nil then
				local _arg0 = `+{compactNumber(response.Reward.Stardust)} dust`
				table.insert(rewardBits, _arg0)
			end
			local _result_3 = response.Reward
			if _result_3 ~= nil then
				_result_3 = _result_3.Cores
			end
			if _result_3 ~= nil then
				local _arg0 = `+{compactNumber(response.Reward.Cores)} cores`
				table.insert(rewardBits, _arg0)
			end
			local _condition_2 = response.Fragments
			if _condition_2 == nil then
				_condition_2 = 0
			end
			local _exp_1 = `+{compactNumber(_condition_2)} FRAGMENTS`
			local _exp_2 = Palette.mango
			local _object = {}
			local _left = "sub"
			local _condition_3 = table.concat(rewardBits, "  ·  ")
			if not (_condition_3 ~= "" and _condition_3) then
				_condition_3 = nil
			end
			_object[_left] = _condition_3
			_object.big = true
			spawnPop(_exp_1, _exp_2, _object)
			local _condition_4 = response.TiersGained
			if _condition_4 == nil then
				_condition_4 = 0
			end
			local _condition_5 = _condition_4 > 0
			if _condition_5 then
				_condition_5 = response.CoreTier ~= nil
			end
			if _condition_5 then
				setTierUpBanner({
					id = os.clock(),
					tier = response.CoreTier,
				})
			end
			if response.OverdriveTriggered then
				setOverdriveFlash(function(current)
					return current + 1
				end)
			end
		end)
	end
	-- Core Tiers replaced Milestones as the reactor's ongoing reward ladder; any Milestones a
	-- player already earned stay claimable, but the panel only shows while one is actually
	-- outstanding instead of sticking around forever showing "COLLECTED" once they're all done.
	local _exp_1 = anomaly.Milestones
	-- ▼ ReadonlyArray.find ▼
	local _callback_1 = function(entry)
		return not entry.Claimed
	end
	local _result_2
	for _i, _v in _exp_1 do
		if _callback_1(_v, _i - 1, _exp_1) == true then
			_result_2 = _v
			break
		end
	end
	-- ▲ ReadonlyArray.find ▲
	local milestone = _result_2
	local milestoneReady = milestone ~= nil and anomaly.Stabilizations >= milestone.Required
	local _result_3 = milestone
	if _result_3 ~= nil then
		_result_3 = _result_3.Claimed
	end
	local _result_4 = milestone
	if _result_4 ~= nil then
		_result_4 = _result_4.Tier
	end
	local _binding_3 = useArmedAction({ _result_3, _result_4 })
	local milestoneArmed = _binding_3[1]
	local runMilestone = _binding_3[2]
	local claimMilestone = function()
		if milestone ~= nil then
			runMilestone(dispatch, "ClaimAnomalyMilestone", {
				Tier = milestone.Tier,
			}, milestoneReady)
		end
	end
	local dialSize = if phoneLandscape then 112 elseif stack then 156 elseif compactLandscape then 132 else 188
	-- Explicit running-offset layout for the hero panel instead of independently guessed
	-- constants for each row, so the dial/detail/stat/action rows can never end up overlapping
	-- each other the way a taller dial size silently would with fixed offsets.
	local heroTitleH = if phoneLandscape then 60 else 76
	local dialTop = heroTitleH
	local dialBottom = dialTop + dialSize
	local detailH = 60
	local statsH = if phoneLandscape then 36 else 44
	local actionH = if phoneLandscape then TapTarget elseif stack then TapTarget * 2 + 8 else TapTarget
	local heroContentBottom = if stack then dialBottom + (if phoneLandscape then 8 else 14) + (if phoneLandscape then 64 else 88) + 12 + statsH else math.max(dialBottom, dialTop + detailH) + 12 + statsH
	local heroH = heroContentBottom + 16 + actionH
	local statsTop = if stack then dialBottom + (if phoneLandscape then 8 else 14) + (if phoneLandscape then 64 else 88) + 12 else math.max(dialBottom, dialTop + detailH) + 12
	local channelCount = (function()
		local count = 0
		for _id in pairs(config.Channels) do
			count += 1
		end
		return count
	end)()
	local contentWidth = if stack then viewport.width else viewport.width - Layout.sidebarWidth - Layout.panelGap * 3
	local channelCols = channelGridCols(stack, contentWidth)
	local channelRows = math.ceil(channelCount / channelCols)
	local channelRailH = channelRows * CHANNEL_CARD_H + math.max(0, channelRows - 1) * GAP
	local channelH = CHANNEL_DECK_HEADER_H + channelRailH
	local milestoneH = if stack then 154 else 118
	local overdriveReserve = if anomaly.Overdrive ~= nil then OVERDRIVE_BAR_H else 0
	local coreTierStripH = coreTierStripHeight(anomaly.NextCoreTier, contentWidth)
	local anomalyTail = if phoneLandscape then 48 elseif stack then 56 else 40
	local dirRowH = if stack then 184 else 156
	local protoRowH = if stack then 168 else 132
	local order = 0
	local heroReveal = useStagger(0, skipEntrance)
	local _attributes = {
		size = UDim2.fromScale(1, 1),
		accent = accent,
		background = Palette.panelRaised,
		padding = if stack then 14 else 20,
	}
	local _original = order
	order += 1
	_attributes.layoutOrder = _original
	_attributes.reveal = heroReveal
	_attributes.highlight = true
	_attributes.reducedMotion = reducedMotion
	_attributes.clips = false
	local _exp_4 = React.createElement("uigradient", {
		Color = surfaceGradient(Palette.panelRaised, 0.6),
		Rotation = 90,
	})
	local _exp_5 = React.createElement(Text, {
		value = "LIVE REACTOR",
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 15),
	})
	local _attributes_1 = {}
	local _result_5 = activeType
	if _result_5 ~= nil then
		_result_5 = _result_5.Name
	end
	local _condition_2 = _result_5
	if _condition_2 == nil then
		_condition_2 = "Next anomaly incoming"
	end
	_attributes_1.value = _condition_2
	_attributes_1.size = if stack then 21 else 24
	_attributes_1.color = Palette.cream
	_attributes_1.weight = Enum.FontWeight.Heavy
	_attributes_1.fit = true
	_attributes_1.minSize = 15
	_attributes_1.position = UDim2.fromOffset(0, 20)
	_attributes_1.sizeConstraint = UDim2.new(1, 0, 0, 32)
	local _exp_6 = React.createElement(Text, _attributes_1)
	local _exp_7 = React.createElement(Text, {
		value = cycleText,
		size = 10,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, 56),
		sizeConstraint = UDim2.new(1, 0, 0, 15),
	})
	local _attributes_2 = {
		size = dialSize,
		accent = accent,
		charge = charge,
		ready = anomaly.Ready,
		animate = animateCore,
		decorate = decorateCore,
		motionAmount = motionAmount,
	}
	local _condition_3 = anomaly.PulseWindowStartedAt
	if _condition_3 == nil then
		_condition_3 = 0
	end
	_attributes_2.pulseWindowStartedAt = _condition_3
	local _condition_4 = anomaly.PulseWindowSeconds
	if _condition_4 == nil then
		_condition_4 = 1.6
	end
	_attributes_2.pulseWindowSeconds = _condition_4
	local _condition_5 = anomaly.PulseWindowSweetZone
	if _condition_5 == nil then
		_condition_5 = 0.22
	end
	_attributes_2.pulseWindowSweetZone = _condition_5
	local _condition_6 = anomaly.Combo
	if _condition_6 == nil then
		_condition_6 = 0
	end
	_attributes_2.combo = _condition_6
	local _exp_8 = React.createElement(ScaleFromCenter, {
		scale = coreScale,
	}, React.createElement(ReactorCore, _attributes_2))
	local _exp_9 = missFlash > 0 and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uistroke", {
		Color = Palette.coral,
		Thickness = 3,
		Transparency = missGlow,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}))
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#pops)
	local _callback_2 = function(pop)
		return React.createElement(ReactorPop, {
			key = pop.id,
			pop = pop,
		})
	end
	for _k, _v in pops do
		_newValue[_k] = _callback_2(_v, _k - 1, pops)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_10 = React.createElement("frame", {
		Size = UDim2.fromOffset(dialSize, dialSize),
		Position = if stack then UDim2.new(0.5, -dialSize / 2, 0, dialTop) else UDim2.fromOffset(0, dialTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
	}, _exp_8, _exp_9, React.createElement("frame", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, _newValue))
	local _exp_11 = React.createElement("frame", {
		Size = if stack then UDim2.new(1, 0, 0, 88) else UDim2.new(1, -(dialSize + 20), 0, detailH),
		Position = if stack then UDim2.fromOffset(0, dialBottom + 14) else UDim2.fromOffset(dialSize + 20, dialTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Text, {
		value = if anomaly.Ready then "Charge full — bank the yield." else "Pulse when the mint arc lights — HIT NOW means perfect.",
		size = if stack then 14 else 16,
		color = Palette.creamSoft,
		weight = Enum.FontWeight.Bold,
		wrap = true,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, if stack then 36 else 22),
	}), React.createElement(Text, {
		value = `{compactNumber(math.min(anomaly.Charge, anomaly.Target))} / {compactNumber(anomaly.Target)} charge`,
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Bold,
		fit = false,
		position = UDim2.fromOffset(0, if stack then 38 else 24),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
	}), React.createElement(Meter, {
		value = charge,
		color = accent,
		position = UDim2.fromOffset(0, if stack then 56 else 42),
		size = UDim2.new(1, 0, 0, 8),
		reducedMotion = reducedMotion,
		shimmer = anomaly.Ready,
	}))
	local _exp_12 = React.createElement("uilistlayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local _exp_13 = React.createElement(StatPill, {
		label = "BANKED",
		value = compactNumber(anomaly.Stabilizations),
		accent = Palette.mint,
	})
	local _attributes_3 = {
		label = "YIELD",
	}
	local _condition_7 = anomaly.RewardMultiplier
	if _condition_7 == nil then
		_condition_7 = 1
	end
	_attributes_3.value = `×{string.format("%.2f", _condition_7)}`
	_attributes_3.accent = Palette.mango
	local _exp_14 = React.createElement(StatPill, _attributes_3)
	local _exp_15 = React.createElement(StatPill, {
		label = "SHARDS",
		value = compactNumber(anomaly.Fragments),
		accent = Palette.violet,
	})
	local _attributes_4 = {
		label = "BEST COMBO",
	}
	local _condition_8 = anomaly.BestCombo
	if _condition_8 == nil then
		_condition_8 = 0
	end
	_attributes_4.value = `×{_condition_8}`
	_attributes_4.accent = accent
	local _exp_16 = React.createElement(Panel, _attributes, _exp_4, _exp_5, _exp_6, _exp_7, _exp_10, _exp_11, React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, statsH),
		Position = UDim2.fromOffset(0, statsTop),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, _exp_12, _exp_13, _exp_14, _exp_15, React.createElement(StatPill, _attributes_4)), React.createElement("frame", {
		Name = "AnomalyClaimActions",
		Size = UDim2.new(1, 0, 0, actionH),
		Position = UDim2.new(0, 0, 1, -actionH),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ref = anomalyClaimHostRef,
	}, React.createElement(Button, {
		text = "PULSE",
		icon = "Anomaly",
		onClick = requestPulse,
		sound = "reactorPulse",
		color = accent,
		textColor = ensureContrast(accent, Palette.ink),
		size = if phoneLandscape then UDim2.new(1 / 3, -4, 1, 0) elseif stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.32, -5, 1, 0),
		reducedMotion = softMotion,
		highlight = not anomaly.Ready,
	}), React.createElement(Button, {
		text = if stabilizeArmed then "BANKING" elseif anomaly.Ready then "BANK" else "CHARGING",
		icon = "Vault",
		onClick = requestStabilize,
		sound = if canStabilize then "collect" else "locked",
		color = if canStabilize then Palette.mint else Palette.panelSoft,
		textColor = if canStabilize then Palette.ink else Palette.muted,
		size = if phoneLandscape then UDim2.new(1 / 3, -4, 1, 0) elseif stack then UDim2.new(0.5, -4, 0, TapTarget) else UDim2.new(0.36, -6, 1, 0),
		position = if phoneLandscape then UDim2.new(1 / 3, 2, 0, 0) elseif stack then UDim2.new(0.5, 4, 0, 0) else UDim2.new(0.32, 5, 0, 0),
		disabled = not canStabilize,
		reducedMotion = softMotion,
		highlight = canStabilize,
	}), React.createElement(Button, {
		text = if surgeArmed then "SURGING" else surgeText,
		icon = "Command",
		onClick = requestSurge,
		sound = "reactorSurge",
		color = if isSurging then Palette.violet elseif canSurge then Palette.mango else Palette.panelSoft,
		textColor = if isSurging or canSurge then Palette.ink else Palette.muted,
		size = if phoneLandscape then UDim2.new(1 / 3, -4, 1, 0) elseif stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.new(0.32, -5, 1, 0),
		position = if phoneLandscape then UDim2.new(2 / 3, 4, 0, 0) elseif stack then UDim2.new(0, 0, 0, TapTarget + 8) else UDim2.new(0.68, 5, 0, 0),
		disabled = not canSurge,
		reducedMotion = softMotion,
		highlight = canSurge,
	})), tierUpBanner ~= nil and React.createElement(TierUpBanner, {
		key = tierUpBanner.id,
		tier = tierUpBanner.tier,
		onDone = function()
			return setTierUpBanner(nil)
		end,
	}))
	local _attributes_5 = {
		overdrive = anomaly.Overdrive,
	}
	local _original_1 = order
	order += 1
	_attributes_5.order = _original_1
	local _exp_17 = React.createElement(OverdriveBar, _attributes_5)
	local _attributes_6 = {
		anomaly = anomaly,
		config = config,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
		stack = stack,
		width = contentWidth,
	}
	local _original_2 = order
	order += 1
	_attributes_6.order = _original_2
	local _exp_18 = React.createElement(LoadoutDeck, _attributes_6)
	local _attributes_7 = {}
	local _condition_9 = anomaly.CoreTier
	if _condition_9 == nil then
		_condition_9 = 0
	end
	_attributes_7.tier = _condition_9
	local _condition_10 = anomaly.CoreXP
	if _condition_10 == nil then
		_condition_10 = 0
	end
	_attributes_7.xp = _condition_10
	_attributes_7.nextTier = anomaly.NextCoreTier
	local _original_3 = order
	order += 1
	_attributes_7.order = _original_3
	_attributes_7.width = contentWidth
	_attributes_7.height = coreTierStripH
	local _exp_19 = React.createElement(CoreTierStrip, _attributes_7)
	local _condition_11 = milestone ~= nil
	if _condition_11 then
		local _attributes_8 = {
			size = UDim2.fromScale(1, 1),
			accent = Palette.mango,
			background = Palette.panel,
			padding = 14,
		}
		local _original_4 = order
		order += 1
		_attributes_8.layoutOrder = _original_4
		_attributes_8.highlight = milestoneReady and not milestoneArmed
		_attributes_8.reducedMotion = reducedMotion
		_attributes_8.clips = false
		_condition_11 = React.createElement(Panel, _attributes_8, React.createElement(Text, {
			value = `STABILIZATION MARK {milestone.Tier}`,
			size = 10,
			color = Palette.mango,
			weight = Enum.FontWeight.Heavy,
			fit = false,
			sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 15),
		}), React.createElement(Text, {
			value = formatReward(milestone.Reward),
			size = 15,
			color = Palette.cream,
			weight = Enum.FontWeight.Heavy,
			fit = true,
			position = UDim2.fromOffset(0, 21),
			sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 23),
		}), React.createElement(Text, {
			value = `{compactNumber(anomaly.Stabilizations)} / {compactNumber(milestone.Required)}`,
			size = 10,
			color = Palette.muted,
			weight = Enum.FontWeight.Bold,
			fit = false,
			position = UDim2.fromOffset(0, 50),
			sizeConstraint = UDim2.new(1, if stack then 0 else -220, 0, 16),
		}), React.createElement(Meter, {
			value = math.clamp(anomaly.Stabilizations / math.max(1, milestone.Required), 0, 1),
			color = Palette.mango,
			position = UDim2.fromOffset(0, 72),
			size = UDim2.new(1, if stack then 0 else -220, 0, 8),
			reducedMotion = reducedMotion,
			shimmer = milestoneReady,
		}), React.createElement(Button, {
			text = if milestone.Claimed then "COLLECTED" elseif milestoneArmed then "COLLECTING" elseif milestoneReady then "COLLECT MARK" else "LOCKED",
			icon = "Gift",
			onClick = claimMilestone,
			sound = if milestoneReady then "missionClaim" else "locked",
			color = if milestoneReady and not milestoneArmed then Palette.mango else Palette.panelSoft,
			textColor = if milestoneReady and not milestoneArmed then Palette.ink else Palette.muted,
			size = if stack then UDim2.new(1, 0, 0, TapTarget) else UDim2.fromOffset(198, 44),
			position = if stack then UDim2.new(0, 0, 1, -TapTarget) else UDim2.new(1, -198, 0.5, -22),
			disabled = not milestoneReady or milestoneArmed,
			reducedMotion = reducedMotion,
			highlight = milestoneReady and not milestoneArmed,
		}))
	end
	local _attributes_8 = {
		value = "SHIFT JOBS",
		color = accent,
	}
	local _original_4 = order
	order += 1
	_attributes_8.layoutOrder = _original_4
	local _exp_20 = React.createElement(SectionLabel, _attributes_8)
	local listStride = math.max(dirRowH, protoRowH, 120, SECTION_LABEL_H) + GAP
	local listData = {}
	if #anomaly.Directives == 0 then
		table.insert(listData, {
			Id = "empty-directives",
			kind = "empty-directives",
		})
	else
		for _, directive in anomaly.Directives do
			table.insert(listData, {
				Id = directive.Id,
				kind = "directive",
				directive = directive,
			})
		end
	end
	table.insert(listData, {
		Id = "protocols-label",
		kind = "protocols-label",
	})
	for _, protocol in config.Protocols do
		table.insert(listData, {
			Id = protocol.Id,
			kind = "protocol",
			protocol = protocol,
		})
	end
	local jobsList = React.createElement(FlatList, {
		data = listData,
		itemHeight = listStride,
		headerHeight = 0,
		overscan = if softMotion then 0 else (if antilag.tier <= 1 or antilag.constrained then 1 else 2),
		canvasTail = 8,
		Size = UDim2.fromScale(1, 1),
		scrollBarColor = accent,
		scrollBarThickness = 3,
		scrollBarTransparency = 0.28,
		keyExtractor = function(entry)
			return entry.Id
		end,
		renderItem = function(_param_1)
			local entry = _param_1.item
			if entry.kind == "empty-directives" then
				return React.createElement(EmptyState, {
					icon = "Mission",
					title = "No jobs right now",
					body = "More jobs arrive with the next anomaly.",
					accent = accent,
					layoutOrder = 0,
				})
			elseif entry.kind == "protocols-label" then
				return React.createElement(SectionLabel, {
					value = "PERMANENT TUNING",
					color = Palette.violet,
					layoutOrder = 0,
				})
			elseif entry.kind == "directive" then
				return React.createElement(DirectiveRow, {
					directive = entry.directive,
					dispatch = dispatch,
					reducedMotion = reducedMotion,
					order = 0,
					stack = stack,
				})
			end
			local level = anomaly.Protocols[entry.protocol.Id]
			if level == nil then
				level = 0
			end
			return React.createElement(ProtocolRow, {
				protocol = entry.protocol,
				level = level,
				fragments = anomaly.Fragments,
				dispatch = dispatch,
				reducedMotion = reducedMotion,
				order = 0,
				stack = stack,
			})
		end,
	})
	local sections = {
		{
			id = "hero",
			height = heroH,
			element = _exp_16,
		},
	}
	if overdriveReserve > 0 then
		table.insert(sections, {
			id = "overdrive",
			height = OVERDRIVE_BAR_H,
			element = _exp_17,
		})
	end
	table.insert(sections, {
		id = "channels",
		height = channelH,
		element = _exp_18,
	})
	table.insert(sections, {
		id = "core-tier",
		height = coreTierStripH,
		element = _exp_19,
	})
	if milestone ~= nil and _condition_11 then
		table.insert(sections, {
			id = "milestone",
			height = milestoneH,
			element = _condition_11,
		})
	end
	table.insert(sections, {
		id = "jobs-label",
		height = SECTION_LABEL_H,
		element = _exp_20,
	})
	table.insert(sections, {
		id = "jobs-tuning",
		fill = true,
		minHeight = math.max(180, listStride * 2),
		element = jobsList,
	})
	return React.createElement(PageScaffold, {
		gap = GAP,
		tailPad = scrollTail(stack, chrome.bottomSafe, anomalyTail),
		scrollBarColor = accent,
		scrollBarThickness = 4,
		sections = sections,
	})
end
local function AnomalyViewComponent(_param)
	local state = _param.state
	local config = _param.config
	local dispatch = _param.dispatch
	local reducedMotion = _param.reducedMotion
	if state.Anomaly == nil or config.Anomalies == nil then
		return React.createElement(EmptyState, {
			icon = "Anomaly",
			title = "Reactor resting",
			body = ((config.ClientPageGuides and config.ClientPageGuides.Anomaly and config.ClientPageGuides.Anomaly.EmptyDirectives) or "Come back when the next anomaly begins."),
			accent = Palette.pink,
		})
	end
	local _attributes = {
		anomaly = state.Anomaly,
		config = config.Anomalies,
		dispatch = dispatch,
		reducedMotion = reducedMotion,
	}
	local _condition = state.Settings.ReactorMotion
	if _condition == nil then
		_condition = 0.8
	end
	_attributes.motionAmount = math.clamp(_condition, 0, 1)
	return React.createElement(ReactorConsole, _attributes)
end
local function sameNumberMap(left, right)
	if left == right then
		return true
	end
	local leftCount = 0
	local rightCount = 0
	for key, value in pairs(left) do
		leftCount += 1
		if right[key] ~= value then
			return false
		end
	end
	for _key in pairs(right) do
		rightCount += 1
	end
	return leftCount == rightCount
end
local function sameAnomaly(left, right)
	if left == right then
		return true
	end
	if left == nil or right == nil then
		return false
	end
	if left.Cycle ~= right.Cycle or left.TypeId ~= right.TypeId or left.EndsAt ~= right.EndsAt or left.Charge ~= right.Charge or left.Target ~= right.Target or left.Ready ~= right.Ready or left.Phase ~= right.Phase or left.Fragments ~= right.Fragments or left.Stabilizations ~= right.Stabilizations or left.SurgeEndsAt ~= right.SurgeEndsAt or left.Channel ~= right.Channel or left.ChargeMultiplier ~= right.ChargeMultiplier or left.RewardMultiplier ~= right.RewardMultiplier or left.Combo ~= right.Combo or left.BestCombo ~= right.BestCombo or left.CoreTier ~= right.CoreTier or left.CoreXP ~= right.CoreXP or not sameNumberMap(left.Protocols, right.Protocols) or #left.Milestones ~= #right.Milestones or #left.Directives ~= #right.Directives then
		return false
	end
	for index = 0, #left.Milestones - 1 do
		local before = left.Milestones[index + 1]
		local after = right.Milestones[index + 1]
		if before == nil or after == nil or before.Tier ~= after.Tier or before.Required ~= after.Required or before.Claimed ~= after.Claimed or not sameReward(before.Reward, after.Reward) then
			return false
		end
	end
	for index = 0, #left.Directives - 1 do
		local before = left.Directives[index + 1]
		local after = right.Directives[index + 1]
		if before == nil or after == nil or before.Id ~= after.Id or before.Name ~= after.Name or before.Description ~= after.Description or before.Kind ~= after.Kind or before.Target ~= after.Target or before.Progress ~= after.Progress or before.Claimed ~= after.Claimed or before.Fragments ~= after.Fragments or not sameReward(before.Reward, after.Reward) then
			return false
		end
	end
	return true
end
local AnomalyView = React.memo(AnomalyViewComponent, function(previous, incoming)
	return previous.config == incoming.config and previous.dispatch == incoming.dispatch and previous.reducedMotion == incoming.reducedMotion and previous.state.Settings.ReactorMotion == incoming.state.Settings.ReactorMotion and sameAnomaly(previous.state.Anomaly, incoming.state.Anomaly)
end)
return {
	AnomalyView = AnomalyView,
}
