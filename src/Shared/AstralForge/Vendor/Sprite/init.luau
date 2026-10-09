--!strict
-- Vendored from the Roblox Creator Store asset 91404002163443 ("Sprite", an AnimationTrack-style
-- spritesheet animator; devforum.roblox.com/t/4538233). Kept as published; local edits are marked.
-- Sprite Class V1.0.0
--[[
	This module is to help with easily animating 2d spritesheets 
	and works similar to how Roblox structures AnimationTracks 
	and Animation objects.

	Organize spritesheets with the sprite template attached to this script.
	Add your image to the sprite template and then fill out the attributes.
	
	You can also add markers by putting IntValues inside the spritesheet.
	Assign the IntValue value to the frame number, and the name of the
	IntValue is the name of your marker.
	
	For instance, this will make an AnimationTrack with markers on
	the first and third frame of your animation.
	Spritesheet (ImageLabel)
	| Footstep (Value = 1)
	| Footstep (Value = 3)

		- SPRITESHEET ATTRIBUTES ----------------------------
			Columns: 		Number of images in a horizontal row
			Framerate: 		The number of frames per second in the animation
			FreezesOnEnd: 	Toggle whether you want the animation to keep the 
							last frame once it's done.
							WARNING: You will have to manually call :Stop()
							once frozen.
			Looped: 		Toggle whether you want the animation to loop
			Priority: 		Same as Priority in native Roblox's AnimationTrack.
							Animation tracks with higher priority display over
							other animations with lower priority.
			SpriteCount: 	Total number of images in the sprite
			SpriteSize:		Size of one sprite in the spritesheet
							(NOT THE ENTIRE SPRITESHEET IMAGE SIZE)
						
		- SPRITE WORKFLOW ------------------------------------
			Sprite.new(adornee) 	
			- Returns a new sprite instance attached 
			to the given adornee.
									
			sprite:LoadAnimation(spritesheet) 
			- Returns an AnimationTrack object.
			
			sprite:Destroy() 
			- Destroys the sprite instance and clears
			the animation cache.


	- RESTRICTIONS --------------------------------------
	- Spritesheets may not have any row or column padding.
	- Spritesheets may not have a size over 1024x1024 due to Roblox compression
	- Adornees are limited to ImageLabels and ImageButtons

	- EXAMPLE CODE --------------------------------------
	local character = script.Parent
	local adornee : ImageLabel = character:FindFirstChild("Adornee", true)
	local characterSprite = Sprite.new(adornee)

	local runSpritesheet = script.Animations.Run
	local runAnimationTrack = characterSprite:LoadAnimation(runSpritesheet)
	runAnimationTrack.Looped = true
	runAnimationTrack:Play()

	runAnimationTrack:GetMarkerReachedSignal("Footstep"):Connect(function()
		local footstepSound = character:FindFirstChild("Footstep", true)
		footstepSound:Play()
	end)
]]

------------------------- SERVICES -------------------------
local RunService = game:GetService("RunService")

------------------------- REFERENCES -------------------------
local Signal = require(script.Signal)
local AnimationTrack = require(script.AnimationTrack)

local Sprite = {}
Sprite.__index = Sprite

--[[
	Setting the __mode to "k" means any reference to sprites
	are weak and aren't looked at when it comes to checking
	if a sprite should be garbage collected. Though we remove
	the key in :Destroy() it's fair to be on the safe side :)
]]
Sprite.Sprites = {}
setmetatable(Sprite.Sprites, {__mode = "k"})

type AdorneeType = ImageLabel | ImageButton
type self = {
	Adornee : AdorneeType,
	AnimationTracks : {AnimationTrack},

	RunConnection : RBXScriptConnection,
	OnCurrentTrackChanged : Signal.Signal<AnimationTrack>,
	CurrentTrack : AnimationTrack,
}

export type Sprite = typeof(setmetatable({} :: self, Sprite))
export type AnimationTrack = AnimationTrack.AnimationTrack

------------------------- CLASS FUNCTIONS -------------------------
--[[
	Returns a new Sprite from the given adornee.
]]
function Sprite.new(adornee : AdorneeType) : Sprite
	local self = setmetatable({} :: self, Sprite)

	if Sprite.Sprites[adornee] then
		return Sprite.Sprites[adornee]
	end

	self.Adornee = adornee
	self.AnimationTracks = {}
	self.OnCurrentTrackChanged = Signal.new()
	Sprite.Sprites[adornee] = self

	self:_Init()
	
	return self
end


function Sprite._Init(self : Sprite)
	self.Adornee.Destroying:Once(function()
		self:Destroy()
	end)

	self.RunConnection = RunService.PreRender:Connect(function(deltaTime : number)
		self:_Render()
		self:_UpdateAnimationTracks(deltaTime)
	end)
end


function Sprite.__tostring(self : Sprite)
	return self.Adornee and self.Adornee:GetFullName() or "Sprite(nil)"
end

--[[
	Returns an adornee's corresponding sprite if it has been made. 
]]
function Sprite.GetSpriteFromAdornee(adornee : ImageLabel | ImageButton) : Sprite
	assert(adornee, "Adornee is nil or not specified")
	return Sprite.Sprites[adornee]
end

--[[
	Returns all sprite tracks that has the specified DebugId.
]]
function Sprite.GetTracksWithDebugId(self : Sprite, debugId : string) : {AnimationTrack}
	local tracks = {}
	for _, track in self.AnimationTracks do
		if track.DebugId == debugId then
			table.insert(tracks, track)
		end
	end
	
	return tracks
end

--[[
	Returns an AnimationTrack from an AnimationTrack config.
]]
function Sprite.LoadAnimation(self : Sprite, config : AnimationTrack.ArrayConfig | AnimationTrack.InstanceConfig)
	assert(config, `Cannot load animation for {self.Adornee:GetFullName()} with config {config}`)
	
	local newTrack = AnimationTrack._new(config)
	
	newTrack._PlayTrack:Connect(function()
		if not table.find(self.AnimationTracks, newTrack) then
			table.insert(self.AnimationTracks, newTrack)
		end
	end)

	newTrack._StopTrack:Connect(function()
		self:_StopTrack(newTrack)
	end)

	return newTrack
end

--[[
	Stops all AnimationTracks.
]]
function Sprite.StopAllAnimations(self : Sprite)
	for _, track : AnimationTrack in self.AnimationTracks do
		self:_StopTrack(track)
	end
end


function Sprite._StopTrack(self : Sprite, animationTrack : AnimationTrack)
	local tableIndex = table.find(self.AnimationTracks, animationTrack)
	assert(tableIndex, `Could not find animation track {animationTrack.DebugId or animationTrack} in sprite {self}`)

	table.remove(self.AnimationTracks, tableIndex)

	animationTrack.Stopped:Fire()
	animationTrack:Destroy()
end


function Sprite._GetHighestPriorityAnimationTrack(self : Sprite) : AnimationTrack?
	local highestPriorityTrack : AnimationTrack? = nil

	local model = self.Adornee:FindFirstAncestorWhichIsA("Model")

	for _, track : AnimationTrack in self.AnimationTracks do
		if highestPriorityTrack == nil then
			highestPriorityTrack = track
		end

		if track.Priority
			and highestPriorityTrack ~= nil
			and track.Priority >= highestPriorityTrack.Priority 
			and track._StartTime > highestPriorityTrack._StartTime then
			highestPriorityTrack = track
		end
	end

	return highestPriorityTrack
end


function Sprite._UpdateAnimationTracks(self : Sprite, deltaTime : number)
	for _, track : AnimationTrack in self.AnimationTracks do
		track:_Update(deltaTime)
	end
end


function Sprite._Render(self : Sprite)
	local animationTrack = self:_GetHighestPriorityAnimationTrack()

	if animationTrack ~= self.CurrentTrack then
		self.CurrentTrack = animationTrack
		self.OnCurrentTrackChanged:Fire(animationTrack)
	end

	if not animationTrack then
		return
	end

	local adornee = self.Adornee

	local spritesheetImage = animationTrack.Spritesheet
	local framerate = animationTrack.Framerate
	local currentFrame = animationTrack.CurrentFrame
	local spriteSize = animationTrack.SpriteSize

	adornee.Image = animationTrack.Spritesheet
	adornee.ImageRectSize = spriteSize
	adornee.ImageRectOffset = Vector2.new(
		spriteSize.X * (currentFrame.Value % animationTrack.Columns),
		spriteSize.Y * math.floor(currentFrame.Value / animationTrack.Columns)
	)
end

--[[
	Destroys the Sprite and its corresponding AnimationTracks.
]]
function Sprite.Destroy(self : Sprite)
	-- LOCAL EDIT (Astral Forge): idempotent. React unmount destroys the sprite, then the adornee's
	-- Destroying handler calls this again on the cleared table.
	if self.Adornee == nil then
		return
	end
	self:StopAllAnimations()

	Sprite.Sprites[self.Adornee] = nil

	self.RunConnection:Disconnect()
	self.OnCurrentTrackChanged:DisconnectAll()

	table.clear(self)
	table.freeze(self)
end


return Sprite
