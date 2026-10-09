--!nonstrict
-- Purpose: an animated elemental spritesheet (any of the 24 in Shared/ElementSprites) as a React
-- element, driven by Vendor/Sprite. Reduced motion shows a still frame.
-- Owner: presentation. Dependencies: Shared/ElementSprites, Vendor/Sprite. Review: 2026-10-08.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local astral = ReplicatedStorage:WaitForChild("AstralForge")
local ElementSprites = require(astral:WaitForChild("Shared"):WaitForChild("ElementSprites"))
local Sprite = require(astral:WaitForChild("Vendor"):WaitForChild("Sprite"))

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
		local sprite = Sprite.new(label)
		local track = sprite:LoadAnimation(ElementSprites.animation(props.element, props.framerate))
		trackRef.current = track
		track:Play()
		return function()
			trackRef.current = nil
			pcall(function()
				sprite:Destroy()
			end)
		end
	end, { props.element, animate })
	-- hover and focus speed the loop up without restarting it
	React.useEffect(function()
		local track = trackRef.current
		if track ~= nil and props.framerate ~= nil then
			track.Framerate = props.framerate
		end
	end, { props.framerate })
	if sheet == nil then
		return nil
	end
	local frame = ElementSprites.FRAME
	return h("imagelabel", {
		ref = ref,
		Name = "ElementFx",
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = sheet.Image,
		ImageRectSize = Vector2.new(frame, frame),
		-- a representative still (mid-loop) for reduced motion and the first frame before Sprite runs
		ImageRectOffset = Vector2.new(frame * 2, frame * 2),
		ImageColor3 = props.tint or Color3.new(1, 1, 1),
		ImageTransparency = props.transparency or 0,
		ScaleType = props.scaleType or Enum.ScaleType.Fit,
		ZIndex = props.zIndex,
	})
end

return {
	ElementFx = ElementFx,
	sheet = ElementSprites.sheet,
}
