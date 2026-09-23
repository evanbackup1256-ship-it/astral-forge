local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local SpriteClip2 = require(script.Parent.SpriteClip2).SpriteClip2
local _ForgeRig2D = require(script.Parent.ForgeRig2D)
local FORGE_RIG_ART_SCALE = _ForgeRig2D.FORGE_RIG_ART_SCALE
local FORGE_RIG_LOOP_SECONDS = _ForgeRig2D.FORGE_RIG_LOOP_SECONDS
local ForgeRig2D = _ForgeRig2D.ForgeRig2D
local _motion = require(script.Parent.motion)
local ScaleFromCenter = _motion.ScaleFromCenter
local useSprScale = _motion.useSprScale
local Palette = require(script.Parent.theme).Palette
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
			-- ▼ ReadonlyArray.map ▼
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
			-- ▲ ReadonlyArray.map ▲
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
