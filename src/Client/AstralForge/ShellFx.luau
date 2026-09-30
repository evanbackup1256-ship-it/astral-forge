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
local Fx = require(script.Parent.vfxMath)

-- Confetti: paper pieces, generated once. Each is thrown from one of two
-- cannons under the reward, slowed hard by the air, and left to flutter down.
local CONFETTI_COLORS = { Palette.green, Palette.cyan, Palette.mango, Palette.pink, Palette.violet, Palette.cream }
local CONFETTI_COUNT = 44
local CONFETTI_PIECES = {}
for index = 1, CONFETTI_COUNT do
	local side = if index % 2 == 0 then -1 else 1
	CONFETTI_PIECES[index] = {
		side = side,
		-- Up and a little inward from each cannon.
		angle = -math.pi / 2 - side * math.rad(8 + Fx.hash(index, 1) * 34),
		speed = 640 + Fx.hash(index, 2) * 560,
		size = 5 + math.floor(Fx.hash(index, 3) * 4),
		spin = 5 + Fx.hash(index, 4) * 9,
		sway = 12 + Fx.hash(index, 5) * 24,
		phase = Fx.hash(index, 6) * math.pi * 2,
		ribbon = index % 3 == 0,
		delay = (index % 6) * 0.018,
		color = CONFETTI_COLORS[(index - 1) % #CONFETTI_COLORS + 1],
	}
end
local CONFETTI_GRAVITY = 760
local CONFETTI_DRAG = 3.2
local CONFETTI_LIFE = 1.95

local function TradeReturnPill(_param)
	local stack = _param.stack
	local bottomPad = _param.bottomPad
	local reducedMotion = _param.reducedMotion
	local onReturn = _param.onReturn
	local antilag = useAntilag()
	-- Canonical softMotion antilag gate — TradeReturnPill springs drop on soft tiers.
	local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient
	reducedMotion = softMotion
	local enter = useEntrance(softMotion)
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
			pcall(task.cancel, selectJob)
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
		reducedMotion = softMotion,
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
	local strength = math.clamp(intensity, 0, 1)
	local enabled = not reducedMotion and antilag.allowAmbient and strength > 0.02
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
	local confettiLive = antilag.allowConfetti == true
	local clock = useClock(confettiLive, if softMotion then 1.4 else 1, 1000, true)
	local confettiSpan = if softMotion then 1.35 else 2.15
	local onDoneRef = React.useRef(onDone)
	onDoneRef.current = onDone
	local spanRef = React.useRef(confettiSpan)
	spanRef.current = confettiSpan
	React.useEffect(function()
		if not confettiLive then
			local finish = onDoneRef.current
			if finish ~= nil then
				finish()
			end
			return nil
		end
		local alive = true
		local completion = task.delay(spanRef.current, function()
			if alive then
				local finish = onDoneRef.current
				if finish ~= nil then
					finish()
				end
			end
		end)
		return function()
			alive = false
			pcall(task.cancel, completion)
		end
	end, { confettiLive })
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
				-- Bursts out fast and slows, like the forge's shock rings.
				local grow = Fx.ring(seconds - ring * 0.08, 0.6)
				local d = 24 + grow * (190 + ring * 52)
				return UDim2.fromOffset(d, d)
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
			Thickness = clock:map(function(seconds)
				local _, thin = Fx.ring(seconds - ring * 0.08, 0.6)
				return 1 + thin * (if ring == 0 then 3.5 else 2.5)
			end),
			Transparency = clock:map(function(seconds)
				local _, _, fade = Fx.ring(seconds - ring * 0.08, 0.6)
				return 0.1 + fade * 0.9
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
		local origin = UDim2.fromScale(0.5 + piece.side * 0.12, 0.66)
		local function age(seconds: number): number
			return math.max(0, seconds - piece.delay)
		end
		-- How face-on the paper is as it tumbles (0 = edge-on, 1 = flat).
		local function flip(t: number): number
			return math.abs(math.cos(t * piece.spin + piece.phase))
		end
		return React.createElement("frame", {
			key = index,
			Size = clock:map(function(seconds)
				local long = piece.size * (if piece.ribbon then 3 else 1.6)
				return UDim2.fromOffset(math.max(1.5, piece.size * (0.18 + 0.82 * flip(age(seconds)))), long)
			end),
			Position = clock:map(function(seconds)
				local t = age(seconds)
				local dx, dy = Fx.ballistic(t, piece.angle, piece.speed, CONFETTI_GRAVITY, CONFETTI_DRAG)
				-- Flutter grows as the paper slows and starts to fall.
				local flutter = math.sin(t * 2.6 + piece.phase) * piece.sway * math.clamp(t / 0.6, 0, 1)
				return origin + UDim2.fromOffset(dx + flutter, dy)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = clock:map(function(seconds)
				local t = age(seconds)
				return math.deg(piece.phase) + t * (if index % 2 == 0 then 210 else -190) + math.sin(t * 3 + piece.phase) * 18
			end),
			-- Paper catches the light when it turns face-on.
			BackgroundColor3 = clock:map(function(seconds)
				return piece.color:Lerp(lighten(piece.color, 0.4), flip(age(seconds)))
			end),
			BackgroundTransparency = clock:map(function(seconds)
				if seconds < piece.delay then
					return 1
				end
				return Fx.fade(age(seconds), CONFETTI_LIFE, 0.7)
			end),
			BorderSizePixel = 0,
			ZIndex = 142 + index % 3,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, if piece.ribbon then 1 else 2),
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
