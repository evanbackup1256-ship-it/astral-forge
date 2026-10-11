--!nonstrict
-- Purpose: an animated elemental spritesheet (any of the 57 in Shared/ElementSprites) as a React
-- element, driven by the shared visibility-budgeted companion clock.
-- Reduced motion shows a still frame.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local astral = ReplicatedStorage:WaitForChild("AstralForge")
local ElementSprites = require(astral:WaitForChild("Shared"):WaitForChild("ElementSprites"))
local Playback = require(script.Parent.CompanionPlayback)

local h = React.createElement

-- props: element, size, position, anchorPoint, transparency, tint, zIndex, framerate, reducedMotion, still,
-- scaleType (Fit by default; Stretch lets a caller squash the sheet, e.g. a sigil lying on the ground)
local function ElementFx(props)
	local ref = React.useRef(nil)
	local trackRef = React.useRef(nil)
	local sheet = ElementSprites.sheet(props.element)
	local animate = sheet ~= nil and not props.reducedMotion and not props.still
	React.useEffect(function()
		local label = ref.current
		if label == nil or not animate then
			return nil
		end
		local animation = ElementSprites.animation(props.element, props.framerate, props.auraLayer)
		local track = Playback.register(label, animation.Columns, animation.SpriteCount, animation.SpriteSize, animation.Framerate)
		trackRef.current = track
		return function()
			trackRef.current = nil
			track.release()
		end
	end, { props.element, animate, props.auraLayer })
	-- hover and focus speed the loop up without restarting it
	React.useEffect(function()
		local track = trackRef.current
		if track ~= nil then
			track.setRate(props.framerate or ElementSprites.FRAMERATE)
		end
	end, { props.framerate })
	if sheet == nil then
		return nil
	end
	local frame = ElementSprites.FRAME
	local face = {
		ref = ref,
		Name = "ElementFx",
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = if props.auraLayer then sheet.AuraImage or sheet.Image else sheet.Image,
		ImageRectSize = Vector2.new(frame, frame),
		-- a representative still (mid-loop) for reduced motion and the first frame before Sprite runs
		ImageRectOffset = Vector2.new(frame * 2, frame * 2),
		ImageColor3 = props.tint or Color3.new(1, 1, 1),
		ImageTransparency = props.transparency or 0,
		ScaleType = props.scaleType or Enum.ScaleType.Fit,
		ZIndex = props.zIndex,
	}
	if props.auraLayer or props.aura == false or sheet.AuraImage == nil then
		return h("imagelabel", face)
	end
	face.Size = UDim2.fromScale(1, 1)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.ZIndex = (props.zIndex or 1) + 1
	return h("frame", {
		Name = "ElementCompanion",
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = props.zIndex,
	}, h(ElementFx, {
		element = props.element, auraLayer = true,
		size = UDim2.fromScale(1.38, 1.38), position = UDim2.fromScale(0.5, 0.5),
		transparency = 0.52 + (props.transparency or 0) * 0.48,
		reducedMotion = props.reducedMotion, still = props.still,
		framerate = props.framerate, zIndex = props.zIndex or 1,
	}), h("imagelabel", face))
end

return {
	ElementFx = ElementFx,
	sheet = ElementSprites.sheet,
}
