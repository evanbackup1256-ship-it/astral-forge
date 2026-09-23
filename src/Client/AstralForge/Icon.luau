local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.antilag).useAntilag
local _motion = require(script.Parent.motion)
local useMotionSettings = _motion.useMotionSettings
local useRotation = _motion.useRotation
local Palette = require(script.Parent.theme).Palette
local VECTOR_ICON_ATLAS = "rbxassetid://139083324249955"
local GAME_ICON_ASSET = "rbxassetid://70683024193057"
local VECTOR_ICON_CELL = 128
local VECTOR_ICON_COLUMNS = 8
local VECTOR_ICON_INDEX = {
	Brand = 0,
	Flux = 1,
	Core = 2,
	Dust = 3,
	Forge = 4,
	Research = 5,
	Grid = 6,
	World = 7,
	Mission = 8,
	Milestone = 9,
	Leaderboard = 10,
	Crew = 11,
	Guild = 12,
	Wheel = 13,
	Games = 14,
	Credits = 15,
	Gift = 16,
	Guide = 17,
	Settings = 18,
	Close = 19,
	Menu = 20,
	Chevron = 21,
	Back = 22,
	Check = 23,
	StarGrid = 24,
	Command = 25,
	Anomaly = 26,
	Reactor = 27,
	Lab = 28,
	Loadout = 29,
	Artifact = 30,
	Vault = 31,
	Rebirth = 32,
	Hide = 33,
	Lock = 34,
	Story = 35,
	Mail = 36,
	Chat = 37,
	Shop = 38,
	Boost = 39,
	Jackpot = 40,
	Admin = 44,
	Pilot = 45,
	Overview = 46,
	Inventory = 47,
	Continuum = 48,
	Rewards = 49,
	Collect = 50,
	Overcharge = 51,
	Domain = 52,
	Search = 53,
	Pause = 54,
	Play = 55,
	Refresh = 56,
	Send = 57,
	Code = 58,
	Crate = 59,
	Calendar = 60,
	Timer = 61,
	Wave = 62,
	Visit = 63,
}
local function vectorIconDirection(kind)
	return if VECTOR_ICON_INDEX[kind] % 2 == 0 then -1 else 1
end
local function VectorIconFace(_param)
	local kind = _param.kind
	local color = _param.color
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local index = VECTOR_ICON_INDEX[kind]
	local column = index % VECTOR_ICON_COLUMNS
	local row = math.floor(index / VECTOR_ICON_COLUMNS)
	return React.createElement("imagelabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = VECTOR_ICON_ATLAS,
		ImageColor3 = color,
		ImageTransparency = transparency,
		ImageRectOffset = Vector2.new(column * VECTOR_ICON_CELL, row * VECTOR_ICON_CELL),
		ImageRectSize = Vector2.new(VECTOR_ICON_CELL, VECTOR_ICON_CELL),
		ScaleType = Enum.ScaleType.Stretch,
	})
end
local ITEM_ICONS = {
	IonCoupler = "Command",
	FluxLens = "Flux",
	CapacityCoil = "Vault",
	PulseInjector = "Anomaly",
	AutoRelay = "Grid",
	ChronoSeal = "Rebirth",
	CriticalPrism = "Artifact",
	StarDrive = "World",
	QuantumCatalyst = "Lab",
	VaultHeart = "Core",
	SingularityCore = "Brand",
	Omniframe = "Loadout",
}
local function itemIconKind(definitionId, slot)
	return ITEM_ICONS[definitionId] or (if slot == "Machine" then "Forge" else "Research")
end
local function prizeShapeFromReward(reward, rarity)
	if string.upper(rarity) == "MYTHIC" then
		return "jackpot"
	end
	local _result = reward
	if _result ~= nil then
		_result = _result.Boost
	end
	if _result ~= nil then
		return "boost"
	end
	local _result_1 = reward
	if _result_1 ~= nil then
		_result_1 = _result_1.Cores
	end
	local _condition = _result_1 ~= nil
	if _condition then
		local _condition_1 = reward.Cores
		if _condition_1 == nil then
			_condition_1 = 0
		end
		_condition = _condition_1 > 0
	end
	if _condition then
		return "core"
	end
	local _result_2 = reward
	if _result_2 ~= nil then
		_result_2 = _result_2.Stardust
	end
	local _condition_1 = _result_2 ~= nil
	if _condition_1 then
		local _condition_2 = reward.Stardust
		if _condition_2 == nil then
			_condition_2 = 0
		end
		_condition_1 = _condition_2 > 0
		if _condition_1 then
			_condition_1 = (reward.CashMinutes == nil or reward.CashMinutes == 0)
		end
	end
	if _condition_1 then
		return "dust"
	end
	return "flux"
end
local PRIZE_ICONS = {
	flux = "Flux",
	dust = "Dust",
	core = "Core",
	boost = "Boost",
	jackpot = "Jackpot",
}
local Icon
local function WheelPrizeViewport(_param)
	local color = _param.color
	local shape = _param.shape
	local size = _param.size
	if size == nil then
		size = 36
	end
	local spin = _param.spin
	if spin == nil then
		spin = true
	end
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(Icon, {
		kind = PRIZE_ICONS[shape],
		color = Palette.cream,
		accent = color,
		size = size,
		spin = spin,
	}))
end
local function GlyphFace(_param)
	local kind = _param.kind
	local color = _param.color
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	return React.createElement(VectorIconFace, {
		kind = kind,
		color = color,
		transparency = transparency,
	})
end
local function semanticIconColor(kind)
	repeat
		local _fallthrough = false
		if kind == "Dust" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Forge" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Milestone" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Wheel" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Gift" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Shop" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Jackpot" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Collect" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Code" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Calendar" then
			return Palette.mango
		end
		if kind == "Core" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Research" then
			_fallthrough = true
		end
		if _fallthrough or kind == "StarGrid" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Anomaly" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Artifact" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Rebirth" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Continuum" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Inventory" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Crate" then
			return Palette.violet
		end
		if kind == "Close" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Hide" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Lock" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Admin" then
			return Palette.coral
		end
		if kind == "Check" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Crew" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Guild" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Games" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Boost" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Play" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Visit" then
			return Palette.mint
		end
		if kind == "Brand" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Mission" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Guide" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Settings" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Credits" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Story" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Lab" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Rewards" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Domain" then
			_fallthrough = true
		end
		if _fallthrough or kind == "Wave" then
			return Palette.pink
		end
		return Palette.cyan
	until true
end
local function coloredFace(kind, requested)
	return requested or semanticIconColor(kind)
end
local function PlayerMark(_param)
	local userId = _param.userId
	local accent = _param.accent
	local color = _param.color
	if color == nil then
		color = Palette.cream
	end
	local size = _param.size
	if size == nil then
		size = 28
	end
	local position = _param.position
	local anchorPoint = _param.anchorPoint
	local seed = math.abs(math.floor(userId))
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, React.createElement("frame", {
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.new(0.5, if seed % 2 == 0 then 1 else -1, 0.5, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(GlyphFace, {
		kind = "Pilot",
		color = color,
		transparency = 0.38,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, React.createElement(GlyphFace, {
		kind = "Pilot",
		color = accent,
	})))
end
function Icon(_param)
	local kind = _param.kind
	local color = _param.color
	local accent = _param.accent
	local size = _param.size
	if size == nil then
		size = 28
	end
	local spin = _param.spin
	if spin == nil then
		spin = true
	end
	local reducedMotion = _param.reducedMotion
	if reducedMotion == nil then
		reducedMotion = false
	end
	local hoverAmount = _param.hoverAmount
	local clipSafe = _param.clipSafe
	if clipSafe == nil then
		clipSafe = false
	end
	local position = _param.position
	local anchorPoint = _param.anchorPoint
	local antilag = useAntilag()
	local _binding = useMotionSettings()
	local viewportScale = _binding.viewportScale
	local iconScale = _binding.iconScale
	if iconScale == nil then
		iconScale = 1
	end
	local faceColor = color or coloredFace(kind, accent)
	local animated = kind == "Brand" or kind == "World" or kind == "Wheel" or kind == "StarGrid" or kind == "Anomaly" or kind == "Rebirth" or kind == "Flux" or kind == "Core" or kind == "Dust" or kind == "Boost" or kind == "Jackpot"
	local speed = if kind == "Brand" then 13 elseif kind == "Wheel" then 11 elseif kind == "Anomaly" then 7 elseif kind == "Rebirth" then 9 else 5
	local scrollSafe = clipSafe or hoverAmount ~= nil
	local orbitEnabled = iconScale > 0.02 and spin and animated and not reducedMotion and not scrollSafe
	local rotation = useRotation(orbitEnabled, speed * math.clamp(viewportScale * iconScale, 0, 2))
	local restingHover = React.useBinding(0)
	local hover = hoverAmount or restingHover
	local direction = vectorIconDirection(kind)
	local visualRotation = rotation:map(function(turn)
		return if orbitEnabled then turn else 0
	end)
	local visualSize = hover:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		local base = 0.94
		if reducedMotion then
			return UDim2.fromScale(base, base)
		end
		return UDim2.fromScale(base + amount * 0.045, base - amount * 0.018)
	end)
	local visualPosition = hover:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return if reducedMotion then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, direction * amount * 0.7, 0.5, -math.round(amount * 1.25))
	end)
	local rimPosition = hover:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return UDim2.new(0.5, direction * (0.25 + amount * 0.65), 0.5, 0.25 + amount * 0.65)
	end)
	local rimTransparency = hover:map(function(raw)
		return if reducedMotion then 1 else 1 - math.clamp(raw, 0, 1) * 0.88
	end)
	local showDepth = hoverAmount ~= nil and antilag.tier >= 2
	return React.createElement("frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = not scrollSafe,
	}, React.createElement("frame", {
		Size = visualSize,
		Position = visualPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = visualRotation,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = not scrollSafe,
	}, showDepth and React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		Position = rimPosition,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, React.createElement(GlyphFace, {
		kind = kind,
		color = Palette.cream,
		transparency = rimTransparency,
	})), React.createElement("frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, React.createElement(GlyphFace, {
		kind = kind,
		color = faceColor,
	}))))
end
return {
	VectorIconFace = VectorIconFace,
	itemIconKind = itemIconKind,
	prizeShapeFromReward = prizeShapeFromReward,
	WheelPrizeViewport = WheelPrizeViewport,
	PlayerMark = PlayerMark,
	Icon = Icon,
	VECTOR_ICON_ATLAS = VECTOR_ICON_ATLAS,
	GAME_ICON_ASSET = GAME_ICON_ASSET,
	VECTOR_ICON_CELL = VECTOR_ICON_CELL,
	VECTOR_ICON_COLUMNS = VECTOR_ICON_COLUMNS,
	VECTOR_ICON_INDEX = VECTOR_ICON_INDEX,
}
