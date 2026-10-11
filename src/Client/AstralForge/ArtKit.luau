--!nonstrict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("ArtKit: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("ArtKit: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["Icon"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local useAntilag = require(script.Parent.MotionKit)("antilag").useAntilag
local _motion = require(script.Parent.MotionKit)("motion")
local useMotionSettings = _motion.useMotionSettings
local useRotation = _motion.useRotation
local useExitPresence = _motion.useExitPresence
local function fadeWithPresence(local_, presence)
	if type(local_) == "number" then
		return presence:map(function(shown)
			return math.clamp(local_ + (1 - shown), 0, 1)
		end)
	end
	return React.joinBindings({ local_, presence }):map(function(values)
		return math.clamp(values[1] + (1 - values[2]), 0, 1)
	end)
end
local Palette = require(script.Parent.CoreKit)("theme").Palette
local VECTOR_ICON_ATLAS = "rbxassetid://139083324249955"
local GAME_ICON_ASSET = "rbxassetid://77239367431949"
local WORDMARK_ASSET = "rbxassetid://75854849112049"
local COMPACT_MARK_ASSET = "rbxassetid://93834740732329"
local LOCKUP_ASSET = "rbxassetid://94028186779182"
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
local function vectorIconIndex(kind)
	if type(kind) == "string" then
		local index = VECTOR_ICON_INDEX[kind]
		if index ~= nil then
			return index
		end
	end
	return VECTOR_ICON_INDEX.Guide
end
local function vectorIconDirection(kind)
	return if vectorIconIndex(kind) % 2 == 0 then -1 else 1
end
local function VectorIconFace(_param)
	local kind = _param.kind
	local color = _param.color
	local transparency = _param.transparency
	if transparency == nil then
		transparency = 0
	end
	local presence = useExitPresence()
	local faded = React.useMemo(function()
		return fadeWithPresence(transparency, presence)
	end, { transparency, presence })
	local index = vectorIconIndex(kind)
	local column = index % VECTOR_ICON_COLUMNS
	local row = math.floor(index / VECTOR_ICON_COLUMNS)
	return React.createElement("imagelabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = VECTOR_ICON_ATLAS,
		ImageColor3 = color,
		ImageTransparency = faded,
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
local function rewardIconKind(reward)
	if reward.Cores then return "Core" end
	if reward.Stardust then return "Dust" end
	if reward.Boost then return "Boost" end
	if reward.FreeSpins then return "Wheel" end
	if reward.Keys then return "Crate" end
	if reward.CashMinutes then return "Flux" end
	if reward.Signals or reward.CommandXP then return "Command" end
	if reward.Essence then return "EchoForge" end
	return "Gift"
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
local Icon
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
	local orbitEnabled = iconScale > 0.02 and spin and animated and not scrollSafe
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
		return UDim2.fromScale(base + amount * 0.045, base - amount * 0.018)
	end)
	local visualPosition = hover:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return UDim2.new(0.5, direction * amount * 0.7, 0.5, -math.round(amount * 1.25))
	end)
	local rimPosition = hover:map(function(raw)
		local amount = math.clamp(raw, 0, 1)
		return UDim2.new(0.5, direction * (0.25 + amount * 0.65), 0.5, 0.25 + amount * 0.65)
	end)
	local rimTransparency = hover:map(function(raw)
		return 1 - math.clamp(raw, 0, 1) * 0.88
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
	rewardIconKind = rewardIconKind,
	prizeShapeFromReward = prizeShapeFromReward,
	PlayerMark = PlayerMark,
	Icon = Icon,
	VECTOR_ICON_ATLAS = VECTOR_ICON_ATLAS,
	GAME_ICON_ASSET = GAME_ICON_ASSET,
	WORDMARK_ASSET = WORDMARK_ASSET,
	LOCKUP_ASSET = LOCKUP_ASSET,
	COMPACT_MARK_ASSET = COMPACT_MARK_ASSET,
	VECTOR_ICON_CELL = VECTOR_ICON_CELL,
	VECTOR_ICON_COLUMNS = VECTOR_ICON_COLUMNS,
	VECTOR_ICON_INDEX = VECTOR_ICON_INDEX,
}
end

__defs["ForgeRig2D"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local RunService = game:GetService("RunService")
local _motion = require(script.Parent.MotionKit)("motion")
local easeInCubic = _motion.easeInCubic
local easeOutBack = _motion.easeOutBack
local easeOutCubic = _motion.easeOutCubic
local ScaleFromCenter = _motion.ScaleFromCenter
local useSprScale = _motion.useSprScale
local Palette = require(script.Parent.CoreKit)("theme").Palette
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
end

__defs["SpriteClip2"] = function()
local RunService = game:GetService("RunService")
local scheduled = {}
local schedulerConnection
local function stopSchedulerIfIdle()
	local _size = 0
	for _ in scheduled do
		_size += 1
	end
	local _condition = _size > 0
	if not _condition then
		_condition = schedulerConnection == nil
	end
	if _condition then
		return nil
	end
	schedulerConnection:Disconnect()
	schedulerConnection = nil
end
local function unschedule(sprite)
	local _sprite = sprite
	scheduled[_sprite] = nil
	stopSchedulerIfIdle()
end
local function ensureScheduler()
	if schedulerConnection ~= nil then
		return nil
	end
	schedulerConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local _callback = function(carried, sprite)
			if not sprite.isPlaying then
				local _sprite = sprite
				scheduled[_sprite] = nil
				return nil
			end
			local step = 1 / math.max(1, sprite.frameRate)
			local elapsed = carried + math.min(deltaTime, 0.25)
			local due = math.floor(elapsed / step)
			if due <= 0 then
				local _sprite = sprite
				scheduled[_sprite] = elapsed
				sprite:RenderSubframe(elapsed / step)
				return nil
			end
			local remainder = elapsed % step
			local advances = math.min(due, sprite.spriteCount)
			if advances <= 2 then
				do
					local index = 0
					local _shouldIncrement = false
					while true do
						if _shouldIncrement then
							index += 1
						else
							_shouldIncrement = true
						end
						if not (index < advances and sprite.isPlaying) then
							break
						end
						sprite:Advance()
					end
				end
			else
				sprite:AdvanceBy(advances)
			end
			if sprite.isPlaying then
				local _sprite = sprite
				scheduled[_sprite] = remainder
				sprite:RenderSubframe(remainder / step)
			else
				sprite:RenderSubframe(0)
			end
		end
		for _k, _v in scheduled do
			_callback(_v, _k, scheduled)
		end
		stopSchedulerIfIdle()
	end)
end
local function schedule(sprite)
	local _sprite = sprite
	scheduled[_sprite] = 0
	sprite:RenderSubframe(0)
	ensureScheduler()
end
local SpriteClipImageSprite
do
	SpriteClipImageSprite = setmetatable({}, {
		__tostring = function()
			return "SpriteClipImageSprite"
		end,
	})
	SpriteClipImageSprite.__index = SpriteClipImageSprite
	function SpriteClipImageSprite.new(...)
		local self = setmetatable({}, SpriteClipImageSprite)
		return self:constructor(...) or self
	end
	function SpriteClipImageSprite:constructor(props)
		self.isPlaying = false
		self.signals = {}
		self.destroyed = false
		self.adornee = props.adornee
		self.blendAdornee = props.blendAdornee
		self.spriteSheetId = props.spriteSheetId
		self.spriteSize = props.spriteSize
		self.spriteOffset = props.spriteOffset or Vector2.zero
		self.edgeOffset = props.edgeOffset or Vector2.zero
		self.spriteCount = math.max(1, math.floor(props.spriteCount))
		self.columnCount = math.max(1, math.floor(props.columnCount))
		self.frameRate = math.max(1, props.frameRate)
		self.isLooped = props.isLooped
		self.getOpacity = props.getOpacity
		local _condition = props.currentFrame
		if _condition == nil then
			_condition = 1
		end
		self.currentFrame = math.clamp(math.floor(_condition), 1, self.spriteCount)
		props.adornee.Image = self.spriteSheetId
		props.adornee.ImageRectSize = self.spriteSize
		self:applyFrame()
		self.destroyingConnection = props.adornee.Destroying:Connect(function()
			return self:Destroy()
		end)
		local _result = props.blendAdornee
		if _result ~= nil then
			_result = _result.Destroying:Connect(function()
				self.blendAdornee = nil
			end)
		end
		self.blendDestroyingConnection = _result
	end
	function SpriteClipImageSprite:fire(signal)
		local _signals = self.signals
		local _signal = signal
		local _result = _signals[_signal]
		if _result ~= nil then
			_result:Fire()
		end
	end
	function SpriteClipImageSprite:applyFrameTo(image, frame)
		if image == nil then
			return nil
		end
		local index = frame - 1
		local column = index % self.columnCount
		local row = math.floor(index / self.columnCount)
		image.Image = self.spriteSheetId
		image.ImageRectSize = self.spriteSize
		image.ImageRectOffset = Vector2.new(self.edgeOffset.X + column * (self.spriteSize.X + self.spriteOffset.X), self.edgeOffset.Y + row * (self.spriteSize.Y + self.spriteOffset.Y))
	end
	function SpriteClipImageSprite:applyFrame()
		self:applyFrameTo(self.adornee, self.currentFrame)
		local followingFrame = if self.currentFrame >= self.spriteCount then (if self.isLooped then 1 else self.spriteCount) else self.currentFrame + 1
		self:applyFrameTo(self.blendAdornee, followingFrame)
	end
	function SpriteClipImageSprite:RenderSubframe(alpha)
		local blend = self.blendAdornee
		local _result = self.getOpacity
		if _result ~= nil then
			_result = _result()
		end
		local _condition = _result
		if _condition == nil then
			_condition = 1
		end
		local opacity = math.clamp(_condition, 0, 1)
		if blend == nil then
			if self.adornee ~= nil then
				self.adornee.ImageTransparency = 1 - opacity
			end
			return nil
		end
		local raw = math.clamp((alpha - 0.68) / 0.32, 0, 1)
		local amount = raw * raw * (3 - 2 * raw)
		if self.adornee ~= nil then
			self.adornee.ImageTransparency = 1 - (1 - amount) * opacity
		end
		blend.ImageTransparency = 1 - amount * opacity
	end
	function SpriteClipImageSprite:Play(playFrom)
		if self.destroyed or self.isPlaying then
			return false
		end
		if playFrom ~= nil then
			self:SetFrame(playFrom)
		end
		self.isPlaying = true
		schedule(self)
		self:fire("PlayCalled")
		return true
	end
	function SpriteClipImageSprite:Pause()
		if not self.isPlaying then
			return false
		end
		self.isPlaying = false
		unschedule(self)
		self:RenderSubframe(0)
		self:fire("PauseCalled")
		return true
	end
	function SpriteClipImageSprite:Stop()
		local wasPlaying = self.isPlaying
		if wasPlaying then
			self.isPlaying = false
			unschedule(self)
		end
		if not self.destroyed then
			self:SetFrame(1)
		end
		self:RenderSubframe(0)
		if wasPlaying then
			self:fire("StopCalled")
		end
		return wasPlaying
	end
	function SpriteClipImageSprite:SetFrame(frame)
		if self.destroyed then
			return nil
		end
		local requestedFrame = math.floor(frame)
		if requestedFrame < 1 or requestedFrame > self.spriteCount then
			error(`Invalid SpriteClip frame {requestedFrame}; expected 1-{self.spriteCount}`)
		end
		local changed = requestedFrame ~= self.currentFrame
		self.currentFrame = requestedFrame
		self:applyFrame()
		if changed then
			self:fire("FrameChanged")
		end
		if requestedFrame == self.spriteCount then
			self:fire("FrameLast")
		end
	end
	function SpriteClipImageSprite:Advance()
		if self.destroyed then
			return nil
		end
		local followingFrame = self.currentFrame + 1
		if followingFrame <= self.spriteCount then
			self:SetFrame(followingFrame)
			return nil
		end
		if not self.isLooped then
			self:Pause()
			return nil
		end
		self:SetFrame(1)
		self:fire("Looped")
	end
	function SpriteClipImageSprite:AdvanceBy(steps)
		if self.destroyed or steps <= 0 then
			return nil
		end
		local amount = math.max(1, math.floor(steps))
		if not self.isLooped then
			local target = math.min(self.spriteCount, self.currentFrame + amount)
			self:SetFrame(target)
			if target >= self.spriteCount then
				self:Pause()
			end
			return nil
		end
		local zeroBased = self.currentFrame - 1 + amount
		local loops = math.floor(zeroBased / self.spriteCount)
		self:SetFrame(zeroBased % self.spriteCount + 1)
		if loops > 0 then
			self:fire("Looped")
		end
	end
	function SpriteClipImageSprite:GetSignal(signal)
		local _signals = self.signals
		local _signal = signal
		local bindable = _signals[_signal]
		if bindable == nil then
			bindable = Instance.new("BindableEvent")
			local _signals_1 = self.signals
			local _signal_1 = signal
			local _bindable = bindable
			_signals_1[_signal_1] = _bindable
		end
		return bindable.Event
	end
	function SpriteClipImageSprite:Destroy()
		if self.destroyed then
			return nil
		end
		self.isPlaying = false
		unschedule(self)
		local _result = self.destroyingConnection
		if _result ~= nil then
			_result:Disconnect()
		end
		self.destroyingConnection = nil
		local _result_1 = self.blendDestroyingConnection
		if _result_1 ~= nil then
			_result_1:Disconnect()
		end
		self.blendDestroyingConnection = nil
		self.adornee = nil
		self.blendAdornee = nil
		local _exp = self.signals
		local _callback = function(bindable)
			return bindable:Destroy()
		end
		for _k, _v in _exp do
			_callback(_v, _k, _exp)
		end
		table.clear(self.signals)
		self.destroyed = true
	end
end
local SpriteClip2 = {
	ImageSprite = {
		new = function(props)
			return SpriteClipImageSprite.new(props)
		end,
	},
}
return {
	SpriteClip2 = SpriteClip2,
}
end

__defs["ForgeAnvil2D"] = function()
local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local SpriteClip2 = __load("SpriteClip2").SpriteClip2
local _ForgeRig2D = __load("ForgeRig2D")
local FORGE_RIG_ART_SCALE = _ForgeRig2D.FORGE_RIG_ART_SCALE
local FORGE_RIG_LOOP_SECONDS = _ForgeRig2D.FORGE_RIG_LOOP_SECONDS
local ForgeRig2D = _ForgeRig2D.ForgeRig2D
local _motion = require(script.Parent.MotionKit)("motion")
local ScaleFromCenter = _motion.ScaleFromCenter
local useSprScale = _motion.useSprScale
local Palette = require(script.Parent.CoreKit)("theme").Palette
local STATIC_FORGE_IMAGE = "rbxassetid://112120837024079"
local FORGE_V9_SPRITE_SHEET_ASSET_ID = 121741065241026
local FORGE_V10_SPRITE_SHEET_ASSET_ID = 138110704320197
local FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID = 97397846255311
local FORGE_V11_PARTS_ATLAS_ASSET_ID = 104699600841724
local FORGE_ASSET_MANIFEST = { `rbxassetid://112120837024079`, `rbxassetid://{FORGE_V9_SPRITE_SHEET_ASSET_ID}`, `rbxassetid://{FORGE_V10_SPRITE_SHEET_ASSET_ID}`, `rbxassetid://{FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID}`, `rbxassetid://{FORGE_V11_PARTS_ATLAS_ASSET_ID}` }
local FORGE_SPRITE_SHEET_ASSET_ID = if FORGE_V10_SPRITE_SHEET_ASSET_ID > 0 then FORGE_V10_SPRITE_SHEET_ASSET_ID else FORGE_V9_SPRITE_SHEET_ASSET_ID
local FRAME_COUNT = 25
local COLUMN_COUNT = 5
local FRAME_RATE = 16
local IMPACT_FRAME = 15
local WINDUP_FRAME = 8
local SPARK_FRAME = 18
local FRAME_EDGE = 204
local FRAME_SIZE = Vector2.new(FRAME_EDGE, FRAME_EDGE)
local HALF_FRAME_SIZE = Vector2.new(FRAME_EDGE, FRAME_EDGE / 2)
local FORGE_LOOP_SECONDS = if FORGE_V11_PARTS_ATLAS_ASSET_ID > 0 then FORGE_RIG_LOOP_SECONDS else FRAME_COUNT / FRAME_RATE
local FORGE_FINALE_SECONDS = 2.15
local FORGE_FINALE_CONTACT = 18 / 24
local FORGE_ART_SCALE = if FORGE_V11_PARTS_ATLAS_ASSET_ID > 0 then FORGE_RIG_ART_SCALE else 0.84
local FINALE_IMPACT_END = 1
local function assetUri(id)
	return `rbxassetid://{id}`
end
local function clamp01(value)
	return math.clamp(value, 0, 1)
end
local function range(value, start, finish)
	return clamp01((value - start) / math.max(0.001, finish - start))
end
local function phasePulse(value, start, peak, finish)
	if value <= start or value >= finish then
		return 0
	end
	return if value <= peak then range(value, start, peak) else 1 - range(value, peak, finish)
end
local function smooth(value)
	local t = clamp01(value)
	return t * t * (3 - 2 * t)
end
local function easeInCubic(value)
	local t = clamp01(value)
	return t * t * t
end
local function hammerPose(value)
	local amount = clamp01(value)
	if amount <= 0.1 then
		local t = 1 - math.pow(1 - range(amount, 0, 0.1), 3)
		return {
			position = UDim2.fromScale(0.78 + t * 0.035, 0.255 - t * 0.055),
			rotation = -12 - 32 * t,
			scale = 0.96 - t * 0.055,
		}
	end
	if amount <= 0.54 then
		local t = smooth(range(amount, 0.1, 0.54))
		local arc = math.sin(t * math.pi)
		return {
			position = UDim2.fromScale(0.815 - arc * 0.12 - t * 0.055, 0.2 - arc * 0.15 + t * 0.005),
			rotation = -44 + t * 914,
			scale = 0.905 + arc * 0.16,
		}
	end
	if amount <= 0.62 then
		local t = smooth(range(amount, 0.54, 0.62))
		return {
			position = UDim2.fromScale(0.76 + t * 0.015, 0.205 - t * 0.018),
			rotation = 870 + t * 28,
			scale = 0.905 + t * 0.04,
		}
	end
	local t = easeInCubic(range(amount, 0.62, FORGE_FINALE_CONTACT))
	return {
		position = UDim2.fromScale(0.775 - t * 0.035, 0.187 + t * 0.22),
		rotation = 898 + t * 127,
		scale = 0.945 + t * 0.105,
	}
end
local function impactFrameOffset(amount)
	local frame = 15 + math.floor(range(amount, FORGE_FINALE_CONTACT, FINALE_IMPACT_END) * 10)
	local zeroBased = math.clamp(frame, 15, 25) - 1
	return Vector2.new((zeroBased % COLUMN_COUNT) * FRAME_SIZE.X, math.floor(zeroBased / COLUMN_COUNT) * FRAME_SIZE.Y)
end
local function finaleFrameOffset(amount)
	local zeroBased = math.clamp(math.floor(clamp01(amount) * (FRAME_COUNT - 1)), 0, FRAME_COUNT - 1)
	return Vector2.new((zeroBased % COLUMN_COUNT) * FRAME_SIZE.X, math.floor(zeroBased / COLUMN_COUNT) * FRAME_SIZE.Y)
end
local ForgeAnvil2DView
local function ForgeAnvil2D(props)
	if FORGE_V11_PARTS_ATLAS_ASSET_ID > 0 then
		local _attributes = table.clone(props)
		setmetatable(_attributes, nil)
		_attributes.atlasId = FORGE_V11_PARTS_ATLAS_ASSET_ID
		return React.createElement(ForgeRig2D, _attributes)
	end
	local _attributes = table.clone(props)
	setmetatable(_attributes, nil)
	return React.createElement(ForgeAnvil2DView, _attributes)
end
function ForgeAnvil2DView(_param)
	local size = _param.size
	local position = _param.position
	local reducedMotion = _param.reducedMotion
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
	local imageRef = React.useRef()
	local blendImageRef = React.useRef()
	local spriteRef = React.useRef()
	local windupRef = React.useRef(onWindup)
	local strikeRef = React.useRef(onStrike)
	local sparkRef = React.useRef(onSpark)
	local exitingRef = React.useRef(exiting)
	local fadeRef = React.useRef(fade)
	windupRef.current = onWindup
	strikeRef.current = onStrike
	sparkRef.current = onSpark
	exitingRef.current = exiting
	fadeRef.current = fade
	local spriteConfigured = FORGE_SPRITE_SHEET_ASSET_ID > 0
	local finaleConfigured = FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID > 0
	local artSprRef = useSprScale(1, reducedMotion, 0.9, 0.7, 7.5)
	React.useEffect(function()
		local image = imageRef.current
		local blendImage = blendImageRef.current
		if image == nil or blendImage == nil or not spriteConfigured then
			return nil
		end
		local sprite = SpriteClip2.ImageSprite.new({
			adornee = image,
			blendAdornee = blendImage,
			spriteSheetId = assetUri(FORGE_SPRITE_SHEET_ASSET_ID),
			currentFrame = 1,
			spriteSize = FRAME_SIZE,
			spriteOffset = Vector2.zero,
			edgeOffset = Vector2.zero,
			spriteCount = FRAME_COUNT,
			columnCount = COLUMN_COUNT,
			frameRate = FRAME_RATE,
			isLooped = true,
			getOpacity = function()
				return 1 - fadeRef.current:getValue()
			end,
		})
		spriteRef.current = sprite
		local impactConnection = sprite:GetSignal("FrameChanged"):Connect(function()
			if sprite.currentFrame == WINDUP_FRAME then
				local _result = windupRef.current
				if _result ~= nil then
					_result()
				end
			elseif sprite.currentFrame == IMPACT_FRAME then
				local _result = strikeRef.current
				if _result ~= nil then
					_result()
				end
			elseif sprite.currentFrame == SPARK_FRAME then
				local _result = sparkRef.current
				if _result ~= nil then
					_result()
				end
			end
		end)
		local lastFrameConnection = sprite:GetSignal("FrameLast"):Connect(function()
			if exitingRef.current then
				sprite:Pause()
			end
		end)
		if reducedMotion then
			sprite:SetFrame(1)
		else
			sprite:Play(1)
		end
		return function()
			impactConnection:Disconnect()
			lastFrameConnection:Disconnect()
			sprite:Destroy()
			if spriteRef.current == sprite then
				spriteRef.current = nil
			end
		end
	end, { reducedMotion, spriteConfigured })
	React.useEffect(function()
		if not finaleActive or reducedMotion then
			return nil
		end
		local regular = spriteRef.current
		local _result = regular
		if _result ~= nil then
			_result:Pause()
		end
		if imageRef.current ~= nil then
			imageRef.current.ImageTransparency = 1
		end
		if blendImageRef.current ~= nil then
			blendImageRef.current.ImageTransparency = 1
		end
	end, { finaleActive, reducedMotion })
	React.useEffect(function()
		if not exiting or reducedMotion or finaleActive then
			return nil
		end
		local sprite = spriteRef.current
		if sprite == nil then
			return nil
		end
		sprite:Stop()
		sprite:Play(math.max(1, IMPACT_FRAME - 4))
	end, { exiting, finaleActive, reducedMotion })
	local forgeImage = if spriteConfigured then assetUri(FORGE_SPRITE_SHEET_ASSET_ID) else STATIC_FORGE_IMAGE
	local finaleImage = assetUri(FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID)
	local artScale = FORGE_ART_SCALE
	local splitTransparency = finaleTimeline:map(function(amount)
		return if amount >= FORGE_FINALE_CONTACT then 1 else 0
	end)
	local impactTransparency = finaleTimeline:map(function(amount)
		return if amount >= FORGE_FINALE_CONTACT then 0 else 1
	end)
	local impactOffset = finaleTimeline:map(impactFrameOffset)
	local finaleOffset = finaleTimeline:map(finaleFrameOffset)
	local hammerPosition = finaleTimeline:map(function(amount)
		return hammerPose(amount).position
	end)
	local hammerRotation = finaleTimeline:map(function(amount)
		return hammerPose(amount).rotation
	end)
	local hammerScale = finaleTimeline:map(function(amount)
		return hammerPose(amount).scale
	end)
	local trailVisible = function(amount, index)
		local flight = phasePulse(amount, 0.1 + index * 0.01, 0.4, FORGE_FINALE_CONTACT)
		return clamp01(1 - flight * (0.22 - index * 0.035))
	end
	local _exp = React.createElement("uiaspectratioconstraint", {
		AspectRatio = 1,
		DominantAxis = Enum.DominantAxis.Height,
	})
	local _exp_1 = React.createElement("imagelabel", {
		ref = imageRef,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = forgeImage,
		ImageTransparency = if spriteConfigured then 0 else 1,
		ImageRectOffset = Vector2.zero,
		ImageRectSize = if spriteConfigured then FRAME_SIZE else Vector2.zero,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		Visible = not finaleActive,
		ZIndex = zIndex + 1,
	})
	local _exp_2 = spriteConfigured and React.createElement("imagelabel", {
		ref = blendImageRef,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = forgeImage,
		ImageTransparency = 1,
		ImageRectOffset = Vector2.zero,
		ImageRectSize = FRAME_SIZE,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		Visible = not finaleActive,
		ZIndex = zIndex + 2,
	})
	local _exp_3 = finaleActive and finaleConfigured and React.createElement("imagelabel", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = finaleImage,
		ImageRectOffset = finaleOffset,
		ImageRectSize = FRAME_SIZE,
		ScaleType = Enum.ScaleType.Fit,
		ResampleMode = Enum.ResamplerMode.Default,
		ImageTransparency = fade,
		ZIndex = zIndex + 9,
	})
	local _condition = finaleActive and not finaleConfigured
	if _condition then
		local _exp_4 = React.createElement("imagelabel", {
			Size = UDim2.fromScale(1, 0.5),
			Position = UDim2.fromScale(0.5, 0.75),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = forgeImage,
			ImageTransparency = splitTransparency,
			ImageRectOffset = Vector2.new(0, FRAME_EDGE / 2),
			ImageRectSize = HALF_FRAME_SIZE,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = zIndex + 3,
		})
		local _condition_1 = not reducedMotion
		if _condition_1 then
			local _exp_5 = { 2, 1, 0 }
			local _newValue = table.create(#_exp_5)
			local _callback = function(index)
				local lag = 0.017 + index * 0.016
				local trailPosition = finaleTimeline:map(function(amount)
					return hammerPose(math.max(0, amount - lag)).position
				end)
				local trailRotation = finaleTimeline:map(function(amount)
					return hammerPose(math.max(0, amount - lag)).rotation
				end)
				local trailScale = finaleTimeline:map(function(amount)
					return hammerPose(math.max(0, amount - lag)).scale * (1 + index * 0.018)
				end)
				return React.createElement("imagelabel", {
					key = `hammer-trail-{index}`,
					Size = UDim2.fromScale(1, 0.5),
					Position = trailPosition,
					Rotation = trailRotation,
					AnchorPoint = Vector2.new(0.82, 0.5),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = forgeImage,
					ImageColor3 = if index == 0 then Palette.cyan elseif index == 1 then Palette.coral else Palette.mango,
					ImageTransparency = finaleTimeline:map(function(amount)
						return trailVisible(amount, index)
					end),
					ImageRectOffset = Vector2.zero,
					ImageRectSize = HALF_FRAME_SIZE,
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = zIndex + 4 + index,
				}, React.createElement("uiscale", {
					Scale = trailScale,
				}))
			end
			for _k, _v in _exp_5 do
				_newValue[_k] = _callback(_v, _k - 1, _exp_5)
			end
			_condition_1 = _newValue
		end
		_condition = React.createElement(React.Fragment, nil, _exp_4, _condition_1, React.createElement("imagelabel", {
			Size = UDim2.fromScale(1, 0.5),
			Position = hammerPosition,
			Rotation = hammerRotation,
			AnchorPoint = Vector2.new(0.82, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = forgeImage,
			ImageTransparency = splitTransparency,
			ImageRectOffset = Vector2.zero,
			ImageRectSize = HALF_FRAME_SIZE,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = zIndex + 8,
		}, React.createElement("uiscale", {
			Scale = hammerScale,
		})), React.createElement("imagelabel", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = forgeImage,
			ImageTransparency = impactTransparency,
			ImageRectOffset = impactOffset,
			ImageRectSize = FRAME_SIZE,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = zIndex + 9,
		}))
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
		Size = UDim2.fromScale(artScale, artScale),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, React.createElement(ScaleFromCenter, {
		scaleRef = artSprRef,
		zIndex = zIndex,
	}, _exp, _exp_1, _exp_2, _exp_3, _condition)))
end
return {
	ForgeAnvil2D = ForgeAnvil2D,
	FORGE_V10_SPRITE_SHEET_ASSET_ID = FORGE_V10_SPRITE_SHEET_ASSET_ID,
	FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID = FORGE_V10_FINALE_SPRITE_SHEET_ASSET_ID,
	FORGE_V11_PARTS_ATLAS_ASSET_ID = FORGE_V11_PARTS_ATLAS_ASSET_ID,
	FORGE_ASSET_MANIFEST = FORGE_ASSET_MANIFEST,
	FORGE_SPRITE_SHEET_ASSET_ID = FORGE_SPRITE_SHEET_ASSET_ID,
	FORGE_LOOP_SECONDS = FORGE_LOOP_SECONDS,
	FORGE_FINALE_SECONDS = FORGE_FINALE_SECONDS,
	FORGE_FINALE_CONTACT = FORGE_FINALE_CONTACT,
	FORGE_ART_SCALE = FORGE_ART_SCALE,
}
end

local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
