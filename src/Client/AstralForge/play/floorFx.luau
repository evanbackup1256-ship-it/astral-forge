local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.Parent.antilag).useAntilag
local _motion = require(script.Parent.Parent.motion)
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local useClock = _motion.useClock
local _theme = require(script.Parent.Parent.theme)
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local surfaceGradient = _theme.surfaceGradient
local Text = require(script.Parent.Parent.ui).Text
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function ShockRing(_param)
	local trigger = _param.trigger
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local size = _param.size
	if size == nil then
		size = 280
	end
	local clock = useClock(trigger > 0 and not reducedMotion, 1, 1000, true)
	local _exp = { 0, 1, 2, 3 }
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#_exp)
	local _callback = function(ring)
		return React.createElement("frame", {
			key = ring,
			Size = clock:map(function(seconds)
				local t = clamp01((seconds - ring * 0.045) / 0.48)
				local grow = easeOutCubic(t)
				return UDim2.fromOffset(28 + grow * (size * 0.96 + ring * 22), 28 + grow * (size * 0.96 + ring * 22))
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 81,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring % 2 == 0 then color else Palette.cream,
			Thickness = if ring == 0 then 4 else 2,
			Transparency = clock:map(function(seconds)
				local t = clamp01((seconds - ring * 0.045) / 0.48)
				return 0.04 + t * 0.96
			end),
		}))
	end
	for _k, _v in _exp do
		_newValue[_k] = _callback(_v, _k - 1, _exp)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		key = `shock-{trigger}`,
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 80,
		Active = false,
	}, _newValue)
end
local Spark
local function SparkBurst(_param)
	local sparks = _param.sparks
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(4, math.min(antilag.maxPops * 2, 28))
	local _result
	if #sparks > max then
		-- ▼ ReadonlyArray.filter ▼
		local _newValue = {}
		local _callback = function(_, index)
			return index >= #sparks - max
		end
		local _length = 0
		for _k, _v in sparks do
			if _callback(_v, _k - 1, sparks) == true then
				_length += 1
				_newValue[_length] = _v
			end
		end
		-- ▲ ReadonlyArray.filter ▲
		_result = _newValue
	else
		_result = sparks
	end
	local visible = _result
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#visible)
	local _callback = function(spark)
		return React.createElement(Spark, {
			key = spark.id,
			spark = spark,
			reducedMotion = reducedMotion,
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
		ZIndex = 90,
		Active = false,
		ClipsDescendants = false,
	}, _newValue)
end
function Spark(_param)
	local spark = _param.spark
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local crumb = spark.kind == "strike" or spark.kind == "perfect" or spark.kind == "bank"
	local travel = if spark.kind == "perfect" then 118 elseif spark.kind == "bank" then 92 else 72
	local width = if crumb then (if spark.kind == "perfect" then 16 else 11) else 7
	local height = if crumb then (if spark.kind == "perfect" then 12 else 8) else 7
	local angle = (spark.id % 12) * 30 + spark.id * 7
	local position = clock:map(function(seconds)
		local t = easeOutCubic(clamp01(seconds / 0.62))
		local spread = (spark.id % 9 - 4) * 18
		local lift = t * travel
		local wobble = math.sin(seconds * 16 + spark.id) * (1 - t) * 14
		local _exp = UDim2.fromScale(spark.x, spark.y)
		local _arg0 = UDim2.fromOffset(spread * t + wobble, -lift + t * t * 28)
		return _exp + _arg0
	end)
	local fade = clock:map(function(seconds)
		return clamp01((seconds - 0.28) / 0.4)
	end)
	local scale = clock:map(function(seconds)
		return if reducedMotion then 1 else 0.4 + easeOutBack(clamp01(seconds / 0.14)) * 0.85
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(width, height),
		Position = position,
		Rotation = clock:map(function(seconds)
			return angle + seconds * (if spark.id % 2 == 0 then 220 else -260)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = spark.color,
		BackgroundTransparency = fade,
		BorderSizePixel = 0,
		ZIndex = 91,
	}, React.createElement("uiscale", {
		Scale = scale,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(if crumb then 0.45 else 1, if crumb then 3 else 0),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(spark.color, 0.38), darken(spark.color, 0.18)),
		Rotation = 90,
	}), React.createElement("uistroke", {
		Color = lighten(spark.color, 0.46),
		Thickness = 1,
		Transparency = fade:map(function(amount)
			return math.clamp(amount + 0.18, 0, 1)
		end),
	}))
end
local ClickPop
local function ClickPops(_param)
	local pops = _param.pops
	local reducedMotion = _param.reducedMotion
	local antilag = useAntilag()
	local max = math.max(3, math.min(antilag.maxPops, 10))
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
		return React.createElement(ClickPop, {
			key = pop.id,
			pop = pop,
			reducedMotion = reducedMotion,
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
		ZIndex = 96,
		Active = false,
		ClipsDescendants = false,
	}, _newValue)
end
function ClickPop(_param)
	local pop = _param.pop
	local reducedMotion = _param.reducedMotion
	local clock = useClock(true, 1, 1000, true)
	local size = if pop.critical then 34 else 24
	local position = clock:map(function(seconds)
		local t = easeOutCubic(clamp01(seconds / 0.78))
		local drift = math.sin(pop.id * 1.7) * 18 * t
		local _exp = UDim2.fromScale(pop.x, pop.y)
		local _arg0 = UDim2.fromOffset(drift, -t * (if pop.critical then 126 else 92))
		return _exp + _arg0
	end)
	local fade = clock:map(function(seconds)
		return clamp01((seconds - 0.36) / 0.42)
	end)
	local scale = clock:map(function(seconds)
		return if reducedMotion then 1 else 0.62 + easeOutBack(clamp01(seconds / 0.16)) * (if pop.critical then 0.62 else 0.46)
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(if pop.critical then 168 else 128, 40),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 97,
	}, React.createElement("uiscale", {
		Scale = scale,
	}), React.createElement(Text, {
		value = pop.text,
		size = size,
		color = pop.color,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.fromScale(1, 1),
		transparency = fade,
	}))
end
local function ComboBanner(_param)
	local combo = _param.combo
	local heat = _param.heat
	local perfect = _param.perfect
	local reducedMotion = _param.reducedMotion
	local pulse = useClock(not reducedMotion and combo > 1, 1.05)
	local accent = if perfect then Palette.mango elseif heat > 0.82 then Palette.coral else Palette.brass
	if combo <= 1 then
		return React.createElement("frame", {
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(240, 52),
		Position = UDim2.fromScale(0.5, 0.145),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 70,
	}, React.createElement("uiscale", {
		Scale = pulse:map(function(phase)
			return 1 + math.sin(phase) * (if perfect then 0.055 else 0.028)
		end),
	}), React.createElement(Text, {
		value = if perfect then "CRIT" else "STREAK",
		size = 11,
		color = accent,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		sizeConstraint = UDim2.new(1, 0, 0, 14),
	}), React.createElement(Text, {
		value = `x{combo}`,
		size = if combo >= 10 then 30 else 26,
		color = Palette.cream,
		weight = Enum.FontWeight.Heavy,
		align = Enum.TextXAlignment.Center,
		fit = false,
		position = UDim2.fromOffset(0, 14),
		sizeConstraint = UDim2.new(1, 0, 0, 32),
	}))
end
local function HeatHaze(_param)
	local heat = _param.heat
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion and heat > 0.12, 0.22)
	local strength = math.clamp(heat, 0, 1)
	if strength <= 0.02 then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		})
	end
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.new(1.08, 0, 0.42, 0),
		Position = clock:map(function(phase)
			return UDim2.new(-0.04 + math.sin(phase) * 0.02, 0, 0.48 + math.cos(phase * 0.7) * 0.012, 0)
		end),
		BackgroundColor3 = Palette.ember,
		BackgroundTransparency = 1 - 0.07 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 90,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(420, 420),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 1 - 0.05 * strength,
		BorderSizePixel = 0,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function FluxRiver(_param)
	local stations = _param.stations
	local reducedMotion = _param.reducedMotion
	local accent = _param.accent
	local clock = useClock(not reducedMotion, 0.55)
	-- ▼ ReadonlyArray.map ▼
	local _newValue = table.create(#stations)
	local _callback = function(station, index)
		return if station.live then React.createElement("frame", {
			key = `river-{index}`,
			Size = UDim2.fromOffset(3, 3),
			Position = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				local x = station.x + (0.5 - station.x) * t
				local y = station.y + (0.58 - station.y) * t - math.sin(t * math.pi) * 0.04
				return UDim2.fromScale(x, y)
			end),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = station.color,
			BackgroundTransparency = clock:map(function(phase)
				local t = (phase * 0.35 + index * 0.17) % 1
				return 0.15 + (1 - math.sin(t * math.pi)) * 0.7
			end),
			BorderSizePixel = 0,
			ZIndex = 7,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})) else nil
	end
	for _k, _v in stations do
		_newValue[_k] = _callback(_v, _k - 1, stations)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 6,
		Active = false,
	}, _newValue, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromOffset(8 + math.sin(phase) * 3, 8 + math.sin(phase) * 3)
		end),
		Position = UDim2.fromScale(0.5, 0.58),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function WorldHaze(_param)
	local color = _param.color
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.07)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Active = false,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.void,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, React.createElement("uigradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Palette.void), ColorSequenceKeypoint.new(0.42, darken(color, 0.82)), ColorSequenceKeypoint.new(1, Palette.ink) }),
		Rotation = 118,
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(720, 720),
		Position = clock:map(function(phase)
			return UDim2.new(1, 90 + math.sin(phase) * 28, 1, 50 + math.cos(phase * 0.7) * 20)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromOffset(460, 460),
		Position = UDim2.new(0, -90, 0, -70),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.brass,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.new(1, 0, 0, 160),
		Position = UDim2.new(0, 0, 1, -160),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement("uigradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.12) }),
		Rotation = 90,
	})))
end
local function CoreAura(_param)
	local color = _param.color
	local heat = _param.heat
	local squash = _param.squash
	local reducedMotion = _param.reducedMotion
	local clock = useClock(not reducedMotion, 0.16)
	local glow = math.clamp(0.16 + heat * 0.22, 0.16, 0.4)
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 18,
		Active = false,
	}, React.createElement("frame", {
		Size = clock:map(function(phase)
			return UDim2.fromScale(0.72 + math.sin(phase) * 0.03, 0.72 + math.sin(phase) * 0.03)
		end),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 1 - glow,
		BorderSizePixel = 0,
		ZIndex = 18,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.cream,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 19,
	}, React.createElement("uiscale", {
		Scale = squash,
	}), React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("uigradient", {
		Color = surfaceGradient(lighten(color, 0.2), 0.8),
		Rotation = 90,
	})))
end
return {
	ShockRing = ShockRing,
	SparkBurst = SparkBurst,
	ClickPops = ClickPops,
	ComboBanner = ComboBanner,
	HeatHaze = HeatHaze,
	FluxRiver = FluxRiver,
	WorldHaze = WorldHaze,
	CoreAura = CoreAura,
}
