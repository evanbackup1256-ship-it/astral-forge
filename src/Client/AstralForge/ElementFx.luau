--!nonstrict
-- Purpose: an animated elemental companion (any of the 57 in Shared/ElementSprites) as a React
-- element, driven by the shared visibility-budgeted companion clock. Each companion's elemental
-- light is lit into its own frames, so this is one image layer with nothing played behind it.
-- Reduced motion shows a still frame.

local React = require(game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].react)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local astral = ReplicatedStorage:WaitForChild("AstralForge")
local ElementSprites = require(astral:WaitForChild("Shared"):WaitForChild("ElementSprites"))
local Playback = require(script.Parent.CompanionPlayback)
local useFlash = require(script.Parent.MotionKit)("motion").useFlash

local h = React.createElement

-- Reactions: a short spring on the companion itself. `t` runs 1 -> 0 as the reaction settles.
local REACTIONS = {
	select = { duration = 0.45, scale = function(t) return 1 + 0.14 * t end, rotation = function() return 0 end },
	reveal = { duration = 0.9, scale = function(t) return 1 - 0.4 * t end, rotation = function(t) return -14 * t end },
	equip = { duration = 0.6, scale = function(t) return 1 + 0.2 * t end, rotation = function(t) return 7 * t end },
	mastery = { duration = 1.2, scale = function(t) return 1 + 0.12 * t end, rotation = function(t) return 360 * t end },
}

-- Plays `reaction` each time `reactionKey` changes after mount (never on first render).
local function useReaction(reactionKey, reducedMotion)
	local nonce, setNonce = React.useState(0)
	local seen = React.useRef(reactionKey)
	React.useEffect(function()
		if seen.current ~= reactionKey then
			seen.current = reactionKey
			if not reducedMotion then
				setNonce(function(value) return value + 1 end)
			end
		end
	end, { reactionKey, reducedMotion })
	return nonce
end

-- props: element, size, position, anchorPoint, transparency, tint, zIndex, framerate, reducedMotion, still,
-- reaction ("select" | "reveal" | "equip" | "mastery") with reactionKey (a change plays it),
-- scaleType (Fit by default; Stretch lets a caller squash the sheet, e.g. a sigil lying on the ground)
local function ElementFx(props)
	local ref = React.useRef(nil)
	local trackRef = React.useRef(nil)
	local sheet = ElementSprites.sheet(props.element)
	local animate = sheet ~= nil and not props.reducedMotion and not props.still
	local reaction = REACTIONS[props.reaction or ""]
	local nonce = useReaction(props.reactionKey, props.reducedMotion == true)
	local pulse = useFlash(nonce, props.reducedMotion == true, if reaction then reaction.duration else 0.45)
	React.useEffect(function()
		local label = ref.current
		if label == nil or not animate then
			return nil
		end
		local animation = ElementSprites.animation(props.element, props.framerate)
		local track = Playback.register(label, animation.Columns, animation.SpriteCount, animation.SpriteSize, animation.Framerate)
		trackRef.current = track
		return function()
			trackRef.current = nil
			track.release()
		end
	end, { props.element, animate })
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
	local reacting = reaction ~= nil and not props.reducedMotion
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
		-- the first loop frame: the reduced-motion still, and what shows before playback starts
		ImageRectOffset = Vector2.new(0, 0),
		ImageColor3 = props.tint or Color3.new(1, 1, 1),
		ImageTransparency = props.transparency or 0,
		ScaleType = props.scaleType or Enum.ScaleType.Fit,
		ZIndex = props.zIndex,
		Rotation = if reacting then pulse:map(reaction.rotation) else 0,
	}, reacting and h("uiscale", { Scale = pulse:map(reaction.scale) }) or nil)
end

return {
	ElementFx = ElementFx,
	sheet = ElementSprites.sheet,
}
