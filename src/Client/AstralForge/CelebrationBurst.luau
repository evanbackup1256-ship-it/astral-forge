local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local VectorIconFace = require(script.Parent.Icon).VectorIconFace
local _motion = require(script.Parent.motion)
local ScaleFromCenter = _motion.ScaleFromCenter
local useClock = _motion.useClock
local useViewport = _motion.useViewport
local _theme = require(script.Parent.theme)
local Palette = _theme.Palette
local darken = _theme.darken
local lighten = _theme.lighten
local STYLES = { {
	pattern = "AnvilStrike",
	accent = Palette.mango,
	secondary = Palette.cream,
	colors = { Palette.cream, Palette.mango, Palette.coral, Palette.cyan },
	duration = 1.95,
}, {
	pattern = "SparkCrown",
	accent = Palette.coral,
	secondary = Palette.mango,
	colors = { Palette.mango, Palette.coral, Palette.cream, Palette.mint },
	duration = 2.1,
}, {
	pattern = "AstralTemper",
	accent = Palette.violet,
	secondary = Palette.cyan,
	colors = { Palette.cream, Palette.violet, Palette.cyan, Palette.pink },
	duration = 2.2,
}, {
	pattern = "Starfall",
	accent = Palette.cyan,
	secondary = Palette.mint,
	colors = { Palette.white, Palette.cyan, Palette.mint, Palette.violet },
	duration = 2.15,
}, {
	pattern = "ShockRing",
	accent = Palette.mint,
	secondary = Palette.cyan,
	colors = { Palette.mint, Palette.cyan, Palette.cream, Palette.white },
	duration = 1.85,
}, {
	pattern = "HelixLift",
	accent = Palette.violet,
	secondary = Palette.pink,
	colors = { Palette.violet, Palette.pink, Palette.cyan, Palette.cream },
	duration = 2.25,
}, {
	pattern = "EmberWell",
	accent = Palette.coral,
	secondary = Palette.mango,
	colors = { Palette.coral, Palette.mango, Palette.cream, Palette.pink },
	duration = 2.05,
}, {
	pattern = "CoinBurst",
	accent = Palette.mango,
	secondary = Palette.cream,
	colors = { Palette.mango, Palette.cream, Palette.white, Palette.cyan },
	duration = 1.9,
}, {
	pattern = "LatticeCrack",
	accent = Palette.cyan,
	secondary = Palette.violet,
	colors = { Palette.cyan, Palette.violet, Palette.mint, Palette.cream },
	duration = 2.0,
}, {
	pattern = "NovaPulse",
	accent = Palette.white,
	secondary = Palette.cyan,
	colors = { Palette.white, Palette.cyan, Palette.mint, Palette.violet },
	duration = 1.8,
}, {
	pattern = "DriftMotes",
	accent = Palette.mint,
	secondary = Palette.cream,
	colors = { Palette.mint, Palette.cream, Palette.cyan, Palette.violet },
	duration = 2.3,
}, {
	pattern = "HammerArc",
	accent = Palette.mango,
	secondary = Palette.coral,
	colors = { Palette.mango, Palette.coral, Palette.cream, Palette.violet },
	duration = 1.88,
}, {
	pattern = "PrismSplit",
	accent = Palette.pink,
	secondary = Palette.cyan,
	colors = { Palette.pink, Palette.cyan, Palette.mango, Palette.mint },
	duration = 2.12,
}, {
	pattern = "VortexPull",
	accent = Palette.violet,
	secondary = Palette.mint,
	colors = { Palette.violet, Palette.mint, Palette.cyan, Palette.cream },
	duration = 2.08,
}, {
	pattern = "RibbonLash",
	accent = Palette.coral,
	secondary = Palette.pink,
	colors = { Palette.coral, Palette.pink, Palette.mango, Palette.cream },
	duration = 1.92,
}, {
	pattern = "OrbitBeads",
	accent = Palette.cyan,
	secondary = Palette.mango,
	colors = { Palette.cyan, Palette.mango, Palette.white, Palette.violet },
	duration = 2.18,
}, {
	pattern = "TideWash",
	accent = Palette.mint,
	secondary = Palette.blue,
	colors = { Palette.mint, Palette.cyan, Palette.blue, Palette.cream },
	duration = 2.05,
}, {
	pattern = "FlintSpray",
	accent = Palette.mango,
	secondary = Palette.white,
	colors = { Palette.mango, Palette.white, Palette.coral, Palette.cyan },
	duration = 1.78,
}, {
	pattern = "CrownFlare",
	accent = Palette.cream,
	secondary = Palette.mango,
	colors = { Palette.cream, Palette.mango, Palette.pink, Palette.violet },
	duration = 2.0,
}, {
	pattern = "PulseGrid",
	accent = Palette.cyan,
	secondary = Palette.mint,
	colors = { Palette.cyan, Palette.mint, Palette.white, Palette.violet },
	duration = 1.94,
} }
local MAX_PARTICLES = 18
local MINIMAL_DURATION = 1.05
local function noise(seed, index, salt)
	local raw = math.sin(seed * 0.019 + (index + 1) * 12.9898 + salt * 78.233) * 43758.5453
	return raw - math.floor(raw)
end
local function easeOutCubic(value)
	local inverse = 1 - math.clamp(value, 0, 1)
	return 1 - inverse * inverse * inverse
end
local function styleForSeed(seed)
	return STYLES[math.abs(math.floor(seed)) % #STYLES + 1]
end
local function shapeForRoll(roll)
	if roll < 0.28 then
		return "Spark"
	end
	if roll < 0.46 then
		return "Star"
	end
	if roll < 0.62 then
		return "Shard"
	end
	if roll < 0.76 then
		return "Ember"
	end
	if roll < 0.88 then
		return "Coin"
	end
	return "Needle"
end
local function makeParticles(seed, style)
	local particles = {}
	for index = 0, MAX_PARTICLES - 1 do
		local _arg0 = {
			shape = shapeForRoll(noise(seed, index, 1)),
			lane = noise(seed, index, 2) * 2 - 1,
			phase = noise(seed, index, 3) * math.pi * 2,
			energy = noise(seed, index, 4),
			delay = noise(seed, index, 5) * 0.1 + (index % 4) * 0.018,
			size = 5 + math.floor(noise(seed, index, 6) * 6),
			spin = (noise(seed, index, 7) * 2 - 1) * (280 + noise(seed, index, 8) * 520),
			color = style.colors[index % #style.colors + 1],
		}
		table.insert(particles, _arg0)
	end
	return particles
end
local function positionFor(pattern, particle, progress, index)
	local travel = easeOutCubic(progress)
	if pattern == "SparkCrown" then
		local spread = particle.lane * (0.12 + travel * (0.35 + particle.energy * 0.16))
		local lift = progress * (0.72 + particle.energy * 0.34)
		local gravity = progress * progress * (0.42 + particle.energy * 0.24)
		return UDim2.fromScale(0.5 + spread + math.sin(progress * 8 + particle.phase) * 0.012, 0.58 - lift + gravity)
	end
	if pattern == "AstralTemper" or pattern == "OrbitBeads" or pattern == "VortexPull" then
		local direction = if index % 2 == 0 then 1 else -1
		local spin = if pattern == "VortexPull" then -1.8 else 1.1
		local angle = particle.phase + progress * direction * (spin + particle.energy * 0.9)
		local radius = if pattern == "VortexPull" then 0.32 - travel * (0.22 + particle.energy * 0.1) else 0.035 + travel * (0.28 + particle.energy * 0.2)
		return UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.54 + math.sin(angle) * radius * 0.72 - progress * 0.05)
	end
	if pattern == "Starfall" or pattern == "DriftMotes" or pattern == "TideWash" then
		local drift = if pattern == "TideWash" then math.sin(progress * 3 + particle.phase) * 0.08 else 0
		local x = 0.5 + particle.lane * 0.5 + math.sin(progress * 7 + particle.phase) * (0.01 + particle.energy * 0.018) + drift
		local y = -0.06 - particle.energy * 0.12 + progress * (0.82 + particle.energy * 0.28)
		return UDim2.fromScale(x, y)
	end
	if pattern == "HelixLift" or pattern == "CrownFlare" then
		local angle = particle.phase + progress * 4.2
		local radius = 0.04 + (1 - progress) * (0.22 + particle.energy * 0.12)
		return UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.62 - travel * (0.42 + particle.energy * 0.18))
	end
	if pattern == "EmberWell" or pattern == "FlintSpray" then
		local spread = particle.lane * (0.08 + travel * 0.4)
		return UDim2.fromScale(0.5 + spread, 0.62 - travel * 0.18 + progress * progress * 0.38)
	end
	if pattern == "CoinBurst" or pattern == "NovaPulse" or pattern == "ShockRing" or pattern == "PulseGrid" then
		local angle = particle.phase + (if pattern == "PulseGrid" then math.floor(index / 4) * 0.4 else 0)
		local distance = travel * (0.18 + particle.energy * 0.28)
		return UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.5 + math.sin(angle) * distance * 0.7)
	end
	if pattern == "HammerArc" or pattern == "RibbonLash" then
		local arc = -0.9 + travel * 1.8
		return UDim2.fromScale(0.5 + particle.lane * 0.28 + math.cos(arc) * 0.16, 0.48 + math.sin(arc) * 0.22 + progress * 0.12)
	end
	if pattern == "PrismSplit" or pattern == "LatticeCrack" then
		local col = (index % 5) - 2
		local row = math.floor(index / 5) - 1
		return UDim2.fromScale(0.5 + col * 0.07 * travel, 0.48 + row * 0.08 * travel + progress * 0.06)
	end
	local angle = -math.pi + (particle.phase / (math.pi * 2)) * math.pi
	local distance = travel * (0.26 + particle.energy * 0.32)
	local x = 0.5 + math.cos(angle) * distance
	local y = 0.55 + math.sin(angle) * distance * 0.82 + progress * progress * (0.12 + particle.energy * 0.08)
	return UDim2.fromScale(x, y)
end
local function sizeFor(shape, base, progress)
	local arrival = math.clamp(progress / 0.08, 0, 1)
	local pulse = 0.9 + math.sin(progress * math.pi * 5) * 0.1
	if shape == "Spark" then
		return UDim2.fromOffset(math.max(1, base * (3.3 - progress * 1.5) * arrival), math.max(2, base * 0.3 * arrival))
	end
	if shape == "Star" then
		return UDim2.fromOffset(math.max(1, base * 1.25 * pulse * arrival), math.max(1, base * 1.25 * pulse * arrival))
	end
	if shape == "Shard" then
		return UDim2.fromOffset(math.max(1, base * 0.72 * arrival), math.max(1, base * 1.45 * arrival))
	end
	return UDim2.fromOffset(math.max(1, base * 0.72 * pulse * arrival), math.max(1, base * 0.72 * pulse * arrival))
end
local function ForgeParticle(_param)
	local style = _param.style
	local particle = _param.particle
	local index = _param.index
	local time = _param.time
	local duration = _param.duration
	local detailed = _param.detailed
	local motion = time:map(function(seconds)
		local progress = math.clamp((seconds - particle.delay) / math.max(0.2, duration - 0.2 - particle.delay), 0, 1)
		local arrival = math.clamp(progress / 0.07, 0, 1)
		local departure = math.clamp((progress - 0.68) / 0.32, 0, 1)
		local visibility = arrival * (1 - departure)
		local rotation = if style.pattern == "Starfall" then 24 + particle.lane * 20 + progress * particle.spin * 0.18 else particle.phase * 57.2958 + progress * particle.spin
		return {
			position = positionFor(style.pattern, particle, progress, index),
			rotation = rotation,
			size = sizeFor(particle.shape, particle.size, progress),
			transparency = 1 - visibility,
			glowTransparency = math.clamp(1 - visibility * 0.34, 0.66, 1),
		}
	end)
	local position = motion:map(function(value)
		return value.position
	end)
	local rotation = motion:map(function(value)
		return value.rotation
	end)
	local size = motion:map(function(value)
		return value.size
	end)
	local transparency = motion:map(function(value)
		return value.transparency
	end)
	local glowTransparency = motion:map(function(value)
		return value.glowTransparency
	end)
	local zIndex = 146 + index % 3
	if particle.shape == "Star" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, detailed and React.createElement("frame", {
			Size = UDim2.fromScale(2.2, 2.2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = particle.color,
			BackgroundTransparency = glowTransparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(0, 3),
		})), React.createElement("frame", {
			Size = UDim2.new(0, 2, 1, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})), React.createElement("frame", {
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})), React.createElement("frame", {
			Size = UDim2.fromOffset(3, 3),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}))
	end
	if particle.shape == "Coin" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = Palette.cream,
			Thickness = 1,
			Transparency = glowTransparency,
		}), React.createElement("frame", {
			Size = UDim2.fromScale(0.42, 0.42),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Palette.cream,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})))
	end
	if particle.shape == "Needle" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.white, particle.color),
			Rotation = 90,
		}))
	end
	if particle.shape == "Ember" then
		return React.createElement("frame", {
			Size = size,
			Position = position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = rotation,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = zIndex,
		}, detailed and React.createElement("frame", {
			Size = UDim2.fromScale(2.8, 2.8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = glowTransparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		})), React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = particle.color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uigradient", {
			Color = ColorSequence.new(Palette.cream, particle.color),
			Rotation = 90,
		})))
	end
	return React.createElement("frame", {
		Size = size,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = rotation,
		BackgroundColor3 = particle.color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = zIndex,
	}, React.createElement("uicorner", {
		CornerRadius = if particle.shape == "Spark" then UDim.new(1, 0) else UDim.new(0, 2),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(lighten(particle.color, 0.42), darken(particle.color, 0.25)),
		Rotation = if particle.shape == "Spark" then 0 else 90,
	}), detailed and React.createElement("frame", {
		Size = if particle.shape == "Spark" then UDim2.new(0, 3, 2.4, 0) else UDim2.fromScale(2.1, 2.1),
		Position = if particle.shape == "Spark" then UDim2.fromScale(0.08, 0.5) else UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = particle.color,
		BackgroundTransparency = glowTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex - 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})), React.createElement("frame", {
		Size = if particle.shape == "Spark" then UDim2.new(0, 3, 1, 0) else UDim2.new(1, -2, 0, 2),
		Position = if particle.shape == "Spark" then UDim2.fromScale(0.08, 0.5) else UDim2.fromScale(0.5, 0.24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = zIndex + 1,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	})))
end
local function RewardReceipt(_param)
	local style = _param.style
	local time = _param.time
	local duration = _param.duration
	local reducedMotion = _param.reducedMotion
	local compact = _param.compact
	local motion = time:map(function(seconds)
		local arrival = math.clamp(seconds / 0.2, 0, 1)
		local departure = math.clamp((seconds - duration * 0.72) / math.max(0.18, duration * 0.25), 0, 1)
		local settle = easeOutCubic(arrival)
		return {
			scale = if reducedMotion then 1 else 0.78 + settle * 0.25 - departure * 0.08,
			transparency = math.clamp(1 - arrival + departure, 0, 1),
			rotation = if reducedMotion then 0 else (1 - settle) * -5 + math.sin(arrival * math.pi) * 1.5,
			y = math.round((1 - settle) * 28 - departure * 34),
		}
	end)
	local receiptW = if compact then 236 else 306
	local receiptH = if compact then 70 else 84
	local transparency = motion:map(function(value)
		return value.transparency
	end)
	return React.createElement("frame", {
		Size = UDim2.fromOffset(receiptW, receiptH),
		Position = motion:map(function(value)
			return UDim2.new(0.5, 0, if compact then 0.16 else 0.2, value.y)
		end),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = motion:map(function(value)
			return value.rotation
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 151,
	}, React.createElement(ScaleFromCenter, {
		scale = motion:map(function(value)
			return value.scale
		end),
		zIndex = 151,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.panelRaised,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 151,
		ClipsDescendants = true,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 13),
	}), React.createElement("uistroke", {
		Color = style.accent,
		Thickness = 2,
		Transparency = motion:map(function(value)
			return math.clamp(value.transparency + 0.1, 0, 1)
		end),
	}), React.createElement("uigradient", {
		Color = ColorSequence.new(darken(style.accent, 0.74), Palette.panelRaised),
		Rotation = 18,
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 48 else 58, if compact then 48 else 58),
		Position = UDim2.fromOffset(if compact then 11 else 13, if compact then 11 else 13),
		BackgroundColor3 = darken(style.accent, 0.5),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 153,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(0, 11),
	}), React.createElement("uistroke", {
		Color = style.accent,
		Thickness = 1.5,
		Transparency = motion:map(function(value)
			return math.clamp(value.transparency + 0.16, 0, 1)
		end),
	}), React.createElement("frame", {
		Size = UDim2.fromOffset(if compact then 24 else 30, if compact then 24 else 30),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 154,
		Visible = motion:map(function(value)
			return value.transparency < 0.98
		end),
	}, React.createElement(VectorIconFace, {
		kind = "Check",
		color = Palette.cream,
		transparency = transparency,
	}))), React.createElement("textlabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "REWARD CLAIMED",
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		TextSize = if compact then 15 else 19,
		TextColor3 = Palette.cream,
		TextTransparency = transparency,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(if compact then 70 else 84, if compact then 10 else 14),
		Size = UDim2.new(1, if compact then -78 else -94, 0, if compact then 22 else 26),
		ZIndex = 154,
	}), React.createElement("textlabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "DELIVERED TO YOUR FORGE",
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		TextSize = 12,
		TextColor3 = style.accent,
		TextTransparency = transparency,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(if compact then 70 else 84, if compact then 34 else 43),
		Size = UDim2.new(1, if compact then -78 else -94, 0, 18),
		ZIndex = 154,
	}), React.createElement("frame", {
		Size = UDim2.new(1, -24, 0, 3),
		Position = UDim2.new(0.5, 0, 1, -7),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Palette.line,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 154,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}), React.createElement("frame", {
		Size = time:map(function(seconds)
			return UDim2.new(math.clamp(seconds / math.max(0.1, duration), 0, 1), 0, 1, 0)
		end),
		BackgroundColor3 = style.accent,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = 155,
	}, React.createElement("uicorner", {
		CornerRadius = UDim.new(1, 0),
	}))))))
end
local function CelebrationBurst(_param)
	local seed = _param.seed
	local intensity = _param.intensity
	if intensity == nil then
		intensity = 1
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local particlesEnabled = _param.particlesEnabled
	if particlesEnabled == nil then
		particlesEnabled = true
	end
	local onDone = _param.onDone
	local antilag = useAntilag()
	local viewport = useViewport()
	local style = React.useMemo(function()
		return styleForSeed(seed)
	end, { seed })
	local specs = React.useMemo(function()
		return makeParticles(seed, style)
	end, { seed, style })
	local visible = intensity > 0.02
	local minimal = reducedMotion or not particlesEnabled
	local duration = if minimal then MINIMAL_DURATION else style.duration
	local time = useClock(visible, 1, 1000, true)
	local onDoneRef = React.useRef(onDone)
	onDoneRef.current = onDone
	React.useEffect(function()
		if not visible then
			local completion = task.defer(function()
				return onDoneRef.current(seed)
			end)
			return function()
				return task.cancel(completion)
			end
		end
		local completion = task.delay(duration + 0.06, function()
			return onDoneRef.current(seed)
		end)
		return function()
			return task.cancel(completion)
		end
	end, { duration, seed, visible })
	if not visible then
		return React.createElement("frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
		})
	end
	local mobileCap = if viewport.compact or viewport.tight then 8 else 12
	local desired = math.floor(MAX_PARTICLES * math.clamp(intensity, 0.12, 1))
	local budgetCap = if minimal then 0 else math.max(4, antilag.particleBudget)
	local activeCount = math.clamp(math.min(desired, budgetCap, mobileCap), 0, MAX_PARTICLES)
	-- ▼ ReadonlyArray.filter ▼
	local _newValue = {}
	local _callback = function(_, index)
		return index < activeCount
	end
	local _length = 0
	for _k, _v in specs do
		if _callback(_v, _k - 1, specs) == true then
			_length += 1
			_newValue[_length] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	local particles = _newValue
	local detailed = not minimal and antilag.quality >= 0.72 and activeCount <= 10 and not (viewport.compact or viewport.tight)
	local impact = time:map(function(seconds)
		return easeOutCubic(math.clamp(seconds / 0.36, 0, 1))
	end)
	local rayCount = if minimal then 0 elseif antilag.quality >= 0.62 then 4 elseif antilag.quality >= 0.28 then 2 else 0
	local rays = if rayCount == 4 then { 0, 90, 180, 270 } elseif rayCount == 2 then { 0, 180 } else {}
	-- ▼ ReadonlyArray.map ▼
	local _newValue_1 = table.create(#rays)
	local _callback_1 = function(angle, index)
		return React.createElement("frame", {
			key = `forge-ray-{angle}`,
			Size = impact:map(function(value)
				return UDim2.fromOffset(value * (if viewport.compact then 72 else 120 + index % 2 * 24), 2)
			end),
			Position = UDim2.fromScale(0.5, if viewport.compact or viewport.tight then 0.16 else 0.2),
			AnchorPoint = Vector2.new(0, 0.5),
			Rotation = angle,
			BackgroundColor3 = if index % 3 == 0 then Palette.cream elseif index % 2 == 0 then style.accent else style.secondary,
			BackgroundTransparency = time:map(function(seconds)
				return math.clamp(0.62 + seconds * 2.1, 0.62, 1)
			end),
			BorderSizePixel = 0,
			ZIndex = 142,
		}, React.createElement("uigradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.04), NumberSequenceKeypoint.new(1, 1) }),
		}))
	end
	for _k, _v in rays do
		_newValue_1[_k] = _callback_1(_v, _k - 1, rays)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp = { 0, 1 }
	-- ▼ ReadonlyArray.filter ▼
	local _newValue_2 = {}
	local _callback_2 = function(ring)
		return not minimal or ring == 0
	end
	local _length_1 = 0
	for _k, _v in _exp do
		if _callback_2(_v, _k - 1, _exp) == true then
			_length_1 += 1
			_newValue_2[_length_1] = _v
		end
	end
	-- ▲ ReadonlyArray.filter ▲
	-- ▼ ReadonlyArray.map ▼
	local _newValue_3 = table.create(#_newValue_2)
	local _callback_3 = function(ring)
		return React.createElement("frame", {
			key = `forge-ring-{ring}`,
			Size = impact:map(function(value)
				local delayed = math.clamp((value - ring * 0.14) / math.max(0.01, 1 - ring * 0.14), 0, 1)
				local diameter = (if viewport.compact then 18 else 24) + delayed * ((if viewport.compact then 104 else 152) + ring * (if viewport.compact then 44 else 68))
				return UDim2.fromOffset(diameter, diameter)
			end),
			Position = UDim2.fromScale(0.5, if viewport.compact or viewport.tight then 0.16 else 0.2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 141,
		}, React.createElement("uicorner", {
			CornerRadius = UDim.new(1, 0),
		}), React.createElement("uistroke", {
			Color = if ring == 1 then style.secondary else style.accent,
			Thickness = if minimal then 1 else 1.8 - ring * 0.3,
			Transparency = impact:map(function(value)
				return math.clamp(0.48 + value * 0.52 + ring * 0.05, 0, 1)
			end),
		}))
	end
	for _k, _v in _newValue_2 do
		_newValue_3[_k] = _callback_3(_v, _k - 1, _newValue_2)
	end
	-- ▲ ReadonlyArray.map ▲
	local _exp_1 = React.createElement(RewardReceipt, {
		style = style,
		time = time,
		duration = duration,
		reducedMotion = reducedMotion,
		compact = viewport.compact or viewport.tight,
	})
	-- ▼ ReadonlyArray.map ▼
	local _newValue_4 = table.create(#particles)
	local _callback_4 = function(particle, index)
		return React.createElement(ForgeParticle, {
			key = `{style.pattern}-{index}`,
			style = style,
			particle = particle,
			index = index,
			time = time,
			duration = duration,
			detailed = detailed,
		})
	end
	for _k, _v in particles do
		_newValue_4[_k] = _callback_4(_v, _k - 1, particles)
	end
	-- ▲ ReadonlyArray.map ▲
	return React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 140,
		Active = false,
	}, _newValue_1, _newValue_3, _exp_1, _newValue_4)
end
return {
	CelebrationBurst = CelebrationBurst,
}
