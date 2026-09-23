local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local _motion = require(script.Parent.motion)
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local loadCanvasDraw = _motion.loadCanvasDraw
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local Text = require(script.Parent.ui).Text
local POP_SECONDS = 1.15
local function Pop(_param)
	local pop = _param.pop
	local clock = useClock(true, 1, 1000, true)
	local size = if pop.critical then 30 else 22
	local travel = if pop.critical then 190 else 140
	local rise = clock:map(function(seconds)
		local progress = easeOutCubic(math.clamp(seconds / POP_SECONDS, 0, 1))
		return UDim2.new(0.5, pop.offset, 1, -70 - math.floor(progress * travel))
	end)
	local fade = clock:map(function(seconds)
		return math.clamp((seconds - 0.5) / 0.6, 0, 1)
	end)
	local scale = clock:map(function(seconds)
		return 0.72 + easeOutBack(math.clamp(seconds / 0.2, 0, 1)) * 0.28
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(240, 40),
		Position = rise,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 150,
	}, React.createElement(ScaleFromCenter, {
		scale = scale,
		zIndex = 150,
	}, React.createElement(Text, {
		value = pop.text,
		size = size,
		color = pop.color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		transparency = fade,
		zIndex = 151,
	}), pop.critical and React.createElement(Text, {
		value = "CRITICAL",
		size = 11,
		color = lighten(pop.color, 0.4),
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		position = UDim2.fromOffset(0, 22),
		sizeConstraint = UDim2.new(1, 0, 0, 16),
		transparency = fade,
		zIndex = 151,
	})))
end
local function EffectLayer(_param)
	local pops = _param.pops
	local antilag = useAntilag()
	local max = math.max(1, math.min(antilag.maxPops, math.floor(12 * antilag.fxBudget)))
	local _result
	if #pops > max then
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(_, index)
			return index >= #pops - max
		end
		local _length = 0
		for _k, _v in pops do
			if _callback(_v, _k - 1, pops) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		_result = _newValue
	else
		_result = pops
	end
	local visible = _result
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#visible)
	local _callback = function(pop)
		return React.createElement(Pop, {
			key = pop.id,
			pop = pop,
		})
	end
	for _k, _v in visible do
		_newValue[_k] = _callback(_v, _k - 1, visible)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 150,
		Active = false,
		ClipsDescendants = true,
	}, _newValue)
end
local STARS = { {
	x = 0.08,
	y = 0.18,
	size = 2,
	phase = 0.4,
}, {
	x = 0.17,
	y = 0.72,
	size = 3,
	phase = 2.1,
}, {
	x = 0.31,
	y = 0.34,
	size = 2,
	phase = 4.0,
}, {
	x = 0.44,
	y = 0.86,
	size = 2,
	phase = 1.3,
}, {
	x = 0.58,
	y = 0.22,
	size = 3,
	phase = 5.2,
}, {
	x = 0.69,
	y = 0.62,
	size = 2,
	phase = 3.1,
}, {
	x = 0.79,
	y = 0.14,
	size = 2,
	phase = 0.9,
}, {
	x = 0.88,
	y = 0.78,
	size = 3,
	phase = 2.7,
}, {
	x = 0.94,
	y = 0.42,
	size = 2,
	phase = 4.6,
}, {
	x = 0.24,
	y = 0.52,
	size = 2,
	phase = 5.8,
}, {
	x = 0.52,
	y = 0.48,
	size = 2,
	phase = 1.7,
}, {
	x = 0.12,
	y = 0.9,
	size = 2,
	phase = 3.4,
} }
local function StarField(_param)
	local accent = _param.accent
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local enabled = not reducedMotion and antilag.tier > 0 and antilag.maxStars > 0 and antilag.allowAmbient
	local clock = useClock(enabled, if antilag.constrained then 0.7 else 1.1)
	local starCap = if antilag.constrained then math.min(antilag.maxStars, 3) else antilag.maxStars
	local budgeted = math.clamp(math.floor(#STARS * antilag.fxBudget), 0, #STARS)
	local count = if enabled then math.clamp(math.min(budgeted, starCap), 0, #STARS) else 0
	if count <= 0 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			ClipsDescendants = true,
		})
	end
	local glow = antilag.glowScale
	-- Only iterate the live prefix — building #STARS nil slots every render was
	-- free work on every antilag context push.
	local children = table.create(count)
	for index = 0, count - 1 do
		local star = STARS[index + 1]
		children[index + 1] = React.createElement("frame", {
			key = index,
			Size = UDim2.fromOffset(star.size, star.size),
			Position = UDim2.fromScale(star.x, star.y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if index % 3 == 0 then accent else Palette.creamSoft,
			BackgroundTransparency = clock:map(function(phase)
				return 0.62 + math.sin(phase + star.phase) * 0.3 * glow
			end),
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}))
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		ClipsDescendants = true,
	}, children)
end
local ENERGY_FIELD_RESOLUTION = Vector2.new(48, 28)
local function CanvasEnergyField(_param)
	local time = _param.time
	local enabled = _param.enabled
	local reducedMotion = _param.reducedMotion
	local zIndex = _param.zIndex
	if zIndex == nil then
		zIndex = 712
	end
	local host = React.useRef()
	local renderCanvas = React.useRef(enabled and not reducedMotion).current
	React.useEffect(function()
		if not renderCanvas or host.current == nil then
			return nil
		end
		local module = loadCanvasDraw()
		if module == nil then
			return nil
		end
		local canvas = module.new(host.current, ENERGY_FIELD_RESOLUTION, Palette.void, false)
		canvas.AutoUpdate = false
		canvas.OutputWarnings = false
		local center = Vector2.new((ENERGY_FIELD_RESOLUTION.X + 1) * 0.5, (ENERGY_FIELD_RESOLUTION.Y + 1) * 0.5)
		do
			local y = 1
			local _shouldIncrement = false
			while true do
				if _shouldIncrement then
					y += 1
				else
					_shouldIncrement = true
				end
				if not (y <= ENERGY_FIELD_RESOLUTION.Y) then
					break
				end
				do
					local x = 1
					local _shouldIncrement_1 = false
					while true do
						if _shouldIncrement_1 then
							x += 1
						else
							_shouldIncrement_1 = true
						end
						if not (x <= ENERGY_FIELD_RESOLUTION.X) then
							break
						end
						local dx = (x - center.X) / ENERGY_FIELD_RESOLUTION.X
						local dy = (y - center.Y) / ENERGY_FIELD_RESOLUTION.Y
						local distance = math.sqrt(dx * dx + dy * dy)
						local ribbon = math.max(0, 1 - math.abs(distance - 0.23) * 13)
						local cross = math.max(0, 1 - math.abs(dx * 0.65 + dy) * 18) * math.max(0, 1 - distance * 2.2)
						local energy = math.clamp(ribbon * 0.42 + cross * 0.28, 0, 1)
						canvas:SetPixel(x, y, darken(Palette.violet:Lerp(Palette.cyan, math.clamp(x / ENERGY_FIELD_RESOLUTION.X, 0, 1)), 0.86 - energy * 0.28))
					end
				end
			end
		end
		canvas:DrawCircle(center, 7, darken(Palette.pink, 0.36), false)
		canvas:DrawCircle(center, 11, darken(Palette.cyan, 0.54), false)
		canvas:DrawLine(Vector2.new(7, 22), Vector2.new(41, 6), darken(Palette.violet, 0.42), 1)
		canvas:Update()
		return function()
			return canvas:DestroyCanvas()
		end
	end, { renderCanvas })
	return React.createElement("frame", {
		ref = host,
		Size = UDim2.fromScale(0.88, 0.88),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = time:map(function(value)
			return if reducedMotion then 0 else value * -3.4
		end),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))
end
return {
	EffectLayer = EffectLayer,
	StarField = StarField,
	CanvasEnergyField = CanvasEnergyField,
	POP_SECONDS = POP_SECONDS,
}
