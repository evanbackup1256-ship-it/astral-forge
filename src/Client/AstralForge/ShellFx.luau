local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local UserInputService = game:GetService("UserInputService")
local useAntilag = require(script.Parent.antilag).useAntilag
local GamepadNavigationService = require(script.Parent.input.GamepadNavigationService)
local _motion = require(script.Parent.motion)
local useClock = _motion.useClock
local useEntrance = _motion.useEntrance
local usePulse = _motion.usePulse
local Button = require(script.Parent.ui).Button
local Palette = require(script.Parent.theme).Palette
local darken = require(script.Parent.theme).darken
local lighten = require(script.Parent.theme).lighten

local CONFETTI_PIECES = { {
	x = -240,
	y = 12,
	size = 7,
	phase = 0.2,
	color = Palette.green,
}, {
	x = -208,
	y = 42,
	size = 5,
	phase = 1.1,
	color = Palette.cyan,
}, {
	x = -176,
	y = 4,
	size = 8,
	phase = 2.0,
	color = Palette.mango,
}, {
	x = -142,
	y = 28,
	size = 6,
	phase = 2.8,
	color = Palette.pink,
}, {
	x = -108,
	y = 66,
	size = 5,
	phase = 3.6,
	color = Palette.violet,
}, {
	x = -72,
	y = 16,
	size = 8,
	phase = 4.5,
	color = Palette.green,
}, {
	x = -34,
	y = 52,
	size = 6,
	phase = 5.4,
	color = Palette.cyan,
}, {
	x = 18,
	y = 8,
	size = 7,
	phase = 6.1,
	color = Palette.mango,
}, {
	x = 56,
	y = 58,
	size = 5,
	phase = 0.7,
	color = Palette.pink,
}, {
	x = 94,
	y = 20,
	size = 8,
	phase = 1.8,
	color = Palette.violet,
}, {
	x = 132,
	y = 74,
	size = 6,
	phase = 2.9,
	color = Palette.green,
}, {
	x = 168,
	y = 24,
	size = 5,
	phase = 3.8,
	color = Palette.cyan,
}, {
	x = 204,
	y = 50,
	size = 8,
	phase = 4.8,
	color = Palette.mango,
}, {
	x = 238,
	y = 10,
	size = 6,
	phase = 5.7,
	color = Palette.pink,
}, {
	x = -268,
	y = 34,
	size = 6,
	phase = 0.9,
	color = Palette.cyan,
}, {
	x = -224,
	y = 72,
	size = 8,
	phase = 2.4,
	color = Palette.violet,
}, {
	x = -158,
	y = 18,
	size = 5,
	phase = 4.1,
	color = Palette.green,
}, {
	x = -88,
	y = 82,
	size = 7,
	phase = 5.9,
	color = Palette.mango,
}, {
	x = -12,
	y = 34,
	size = 5,
	phase = 1.5,
	color = Palette.cream,
}, {
	x = 74,
	y = 78,
	size = 8,
	phase = 3.2,
	color = Palette.coral,
}, {
	x = 146,
	y = 36,
	size = 6,
	phase = 4.9,
	color = Palette.mint,
}, {
	x = 214,
	y = 86,
	size = 5,
	phase = 0.4,
	color = Palette.pink,
}, {
	x = 274,
	y = 26,
	size = 7,
	phase = 2.1,
	color = Palette.cyan,
}, {
	x = 112,
	y = 8,
	size = 6,
	phase = 5.1,
	color = Palette.cream,
} }
local function TradeReturnPill(_param)
	local stack = _param.stack
	local bottomPad = _param.bottomPad
	local reducedMotion = _param.reducedMotion
	local onReturn = _param.onReturn
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TradeReturnPill springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(reducedMotion)
	local pulse = usePulse(true, 1.35)
	local width = if stack then 176 else 198
	local height = if stack then 48 else 46
	local tradeReturnHostRef = React.useRef(nil)
	-- Gamepad: park Selection on BACK TO TRADE (FocusClaim prefers Claim-named hosts).
	React.useEffect(function()
		if not UserInputService.GamepadEnabled then
			return nil
		end
		local host = tradeReturnHostRef.current
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
	end, { onReturn })
	return React.createElement("frame", {
		Name = "TradeReturnClaim",
		ref = tradeReturnHostRef,
		Size = UDim2.fromOffset(width, height),
		-- FocusClaim BACK TO TRADE must not clip CTA overshoot.
		ClipsDescendants = false,
		Position = enter:map(function(amount)
			return UDim2.new(0.5, 0, 1, -(bottomPad + (if stack then 10 else 16) - math.round((1 - amount) * 22)))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(amount)
			return 1 + amount * 0.03
		end),
	}), React.createElement(Button, {
		text = "BACK TO TRADE",
		icon = "Visit",
		onClick = onReturn,
		sound = "open",
		color = Palette.mint,
		textColor = Palette.ink,
		size = UDim2.fromScale(1, 1),
		reducedMotion = reducedMotion,
		highlight = true,
	}))
end
local function AmbientLayer(_param)
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — AmbientLayer clocks drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local strength = math.clamp(intensity, 0, 1)
	local enabled = not softMotion and antilag.allowAmbient and strength > 0.02
	local slow = useClock(enabled, 0.17)
	local breath = useClock(enabled, 0.09)
	local orbA = slow:map(function(phase)
		return UDim2.new(0, 130 + math.sin(phase) * 30, 0, 108 + math.cos(phase) * 20)
	end)
	local orbScale = breath:map(function(phase)
		return 1 + math.sin(phase) * 0.12 * antilag.glowScale * strength
	end)
	if not enabled then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromOffset(240, 240),
		Position = orbA,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1 - 0.03 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uiscale", {
		Scale = orbScale,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function ConfettiBurst(_param)
	local onDone = _param.onDone
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — ConfettiBurst skips particle clocks on soft tiers.
	local softMotion = antilag.tier <= 1 or not antilag.allowAmbient
	local confettiLive = antilag.allowConfetti and not softMotion
	local clock = useClock(confettiLive, 1, 1000, true)
	React.useEffect(function()
		if not confettiLive then
			onDone()
			return nil
		end
		local alive = true
		local completion = task.delay(2.15, function()
			if alive then
				onDone()
			end
		end)
		return function()
			alive = false
			task.cancel(completion)
		end
	end, { confettiLive, onDone })
	if not confettiLive then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local activeCount = math.clamp(math.floor(#CONFETTI_PIECES * math.clamp(intensity, 0, 1.5) * math.max(0.34, antilag.fxBudget)), 0, #CONFETTI_PIECES)
	if activeCount <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	local pieces = {}
	-- ▼ ReadonlyArray.forEach ▼
	local _callback = function(piece, index)
		if index < activeCount then
			local _piece = piece
			table.insert(pieces, _piece)
		end
	end
	for _k, _v in CONFETTI_PIECES do
		_callback(_v, _k - 1, CONFETTI_PIECES)
	end
	-- ▲ ReadonlyArray.forEach ▲
	local _exp = { 0, 1 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp)
	local _callback_1 = function(ring)
		return React.createElement("frame", {
			key = `confetti-ring-{ring}`,
			Size = clock:map(function(seconds)
				local t = math.clamp((seconds - ring * 0.08) / 0.52, 0, 1)
				return UDim2.fromOffset(24 + t * (170 + ring * 46), 24 + t * (170 + ring * 46))
			end),
			Position = UDim2.fromScale(0.5, 0.56),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 141,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 0 then Palette.mango else Palette.cyan,
			Thickness = if ring == 0 then 3 else 2,
			Transparency = clock:map(function(seconds)
				local t = math.clamp((seconds - ring * 0.08) / 0.52, 0, 1)
				return 0.14 + t * 0.86
			end),
		}))
	end
	for _k, _v in _exp do
		_newValue[_k] = _callback_1(_v, _k - 1, _exp)
	end
	-- ▲ ReadonlyArray.map ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#pieces)
	local _callback_2 = function(piece, index)
		local delay = (index % 5) * 0.035
		local ribbon = index % 3 == 0
		local progress = clock:map(function(seconds)
			return math.clamp((seconds - delay) / 1.92, 0, 1)
		end)
		local size = progress:map(function(t)
			local flip = 0.22 + math.abs(math.sin(t * math.pi * (3.5 + index % 3) + piece.phase)) * 0.78
			return UDim2.fromOffset(math.max(2, piece.size * flip), piece.size * (if ribbon then 3.2 else 1.75))
		end)
		local position = progress:map(function(t)
			local side = if index % 2 == 0 then -1 else 1
			local startX = 0.5 + side * 0.1
			local spread = piece.x / 590
			local x = startX + spread * (0.18 + t * 0.92) + math.sin(t * 13 + piece.phase) * 0.018
			local y = 0.58 - 1.62 * t + 2.06 * t * t + piece.y / 3200
			return UDim2.fromScale(x, y)
		end)
		local fade = progress:map(function(t)
			return if t <= 0 then 1 else math.clamp((t - 0.7) / 0.3, 0.04, 1)
		end)
		return React.createElement("frame", {
			key = index,
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = progress:map(function(t)
				return piece.phase * 31 + t * (if index % 2 == 0 then 760 else -680)
			end),
			BackgroundColor3 = piece.color,
			BackgroundTransparency = fade,
			BorderSizePixel = 0,
			ZIndex = 142 + index % 3,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, if ribbon then 1 else 2),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(lighten(piece.color, 0.34), darken(piece.color, 0.18)),
			Rotation = 90,
		}))
	end
	for _k, _v in pieces do
		_newValue_1[_k] = _callback_2(_v, _k - 1, pieces)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 140,
		Active = false,
	}, _newValue, _newValue_1)
end
return {
	TradeReturnPill = TradeReturnPill,
	AmbientLayer = AmbientLayer,
	ConfettiBurst = ConfettiBurst,
}
