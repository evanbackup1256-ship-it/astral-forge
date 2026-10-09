--!strict
-- Vendored from the Roblox Creator Store asset 91404002163443 ("Sprite", an AnimationTrack-style
-- spritesheet animator; devforum.roblox.com/t/4538233). Kept as published; local edits are marked.
--[[
	The 
	
]]
------------------------- REFERENCES -------------------------
local Signal = require(script.Parent.Signal)

local AnimationTrack = {}
AnimationTrack.__index = AnimationTrack

type self = {
	---------------- MANDATORY ----------------
	Spritesheet : string,
	SpriteSize : Vector2,
	Columns : number,
	SpriteCount : number,
	
	---------------- OPTIONAL ----------------
	Priority : number,
	Framerate : number,
	Looped : boolean,
	FreezesOnEnd : boolean,
	CurrentFrame : IntValue,
	DebugId : string,
	Markers : {[number] : {
		Name : string,
		Parameter : any?
	}},
	
	---------------- READ ONLY----------------
	_MarkerSignals : {[string] : Signal.Signal<string?>},
	_Accumulated : number,
	_StartTime : number,
	
	_PlayTrack : Signal.Signal<>,
	_StopTrack : Signal.Signal<>,
	_Frozen : boolean,
	
	---------------- EVENTS ----------------
	Stopped : Signal.Signal<>,
	DidLoop : Signal.Signal<>,
}

export type ArrayConfig = {
	Spritesheet : string,
	SpriteSize : Vector2,
	Columns : number,
	SpriteCount : number,
	
	Priority : number?,
	Framerate : number?,
	Looped : boolean?,
	FreezesOnEnd : boolean?,
	CurrentFrame : IntValue?,
	DebugId : string?,
	
	Markers : {[number] : {
		Name : string,
		Parameter : any?
	}}
}

export type InstanceConfig = ImageLabel | ImageButton | Decal
export type AnimationTrack = typeof(setmetatable({} :: self, AnimationTrack))

------------------------- HELPER FUNCTIONS -------------------------
local function getConfigProperty(config : any, propertyName : string) : any
	if type(config) == "table" then
		return config[propertyName]
	else
		return config:GetAttribute(propertyName)
	end
end


------------------------- CLASS FUNCTIONS -------------------------
function AnimationTrack._new(config : InstanceConfig | ArrayConfig) : AnimationTrack
	local self = setmetatable({} :: self, AnimationTrack)

	if type(config) == "table" then
		self.Spritesheet = config.Spritesheet
	else
		if config:IsA("ImageLabel") or config:IsA("ImageButton") then
			self.Spritesheet = config.Image
		elseif config:IsA("Decal") then
			self.Spritesheet = config.ColorMap
		end
	end

	--- MANDATORY ---
	self.SpriteSize  	= getConfigProperty(config, "SpriteSize")
	self.Columns     	= getConfigProperty(config, "Columns")
	self.SpriteCount 	= getConfigProperty(config, "SpriteCount")

	--- OPTIONAL ---
	self.Priority      	= getConfigProperty(config, "Priority") or 0
	self.Framerate     	= getConfigProperty(config, "Framerate") or 12
	self.Looped        	= getConfigProperty(config, "Looped") or false
	self.FreezesOnEnd  	= getConfigProperty(config, "FreezesOnEnd") or false
	self.DebugId       	= getConfigProperty(config, "DebugId") or ""

	--- READ-ONLY ---
	self.Markers         = self:_GetMarkersFromConfig(config) or {}
	self._MarkerSignals  = {}
	self._Accumulated    = 0
	self._StartTime      = tick()
	self._PlayTrack      = Signal.new()
	self._StopTrack      = Signal.new()
	self.CurrentFrame    = Instance.new("IntValue")

	--- EVENTS ---
	self.Stopped  = Signal.new()
	self.DidLoop  = Signal.new()

	self:_Init()
	return self
end


function AnimationTrack._Init(self : AnimationTrack)
	self.CurrentFrame.Changed:Connect(function()
		self:_OnCurrentFrameChanged()
	end)
end


function AnimationTrack._GetMarkersFromConfig(self : AnimationTrack, config : InstanceConfig | ArrayConfig)
	if type(config) == "table" then
		return config.Markers
	end
	
	local children = config:GetChildren()
	local markers = {}

	for _, child in children do
		if child:IsA("IntValue") then
			local markerName = child.Name
			local markerFrame = child.Value

			markers[markerFrame] = {
				Name = markerName,
				Parameter = child:GetAttribute("Parameter") 
			}
		end
	end

	return markers
end


function AnimationTrack._OnCurrentFrameChanged(self : AnimationTrack) 
	-------- handle markers
	local currentFrame = self.CurrentFrame
	local marker = self.Markers[currentFrame.Value]
	if marker then
		local markerSignal = self._MarkerSignals[marker.Name]
		if markerSignal then markerSignal:Fire(marker.Parameter) end
	end

	-------- reaches end?
	if currentFrame.Value >= self.SpriteCount then
		if self.FreezesOnEnd then
			currentFrame.Value = self.SpriteCount - 1
			self._Frozen = true
			return
		end

		if not self.Looped then
			self:Stop()
			return
		end

		currentFrame.Value = 0
		self.DidLoop:Fire()
	end
end

--[[
	Plays the AnimationTrack on the sprite.
]]
function AnimationTrack.Play(self : AnimationTrack)
	-- check if already ended or frozen
	if not self._PlayTrack then
		warn(`Attempted to play an already destroyed animation track: {self}`)
		return
	end
	
	if self._Frozen then
		self._Frozen = false
		self.CurrentFrame.Value = 0
	end

	self._PlayTrack:Fire()
end

--[[
	Stops the AnimationTrack.
]]
function AnimationTrack.Stop(self : AnimationTrack)
	if not self._StopTrack then
		warn(`Attempted to stop an already destroyed animation track: {self}`)
		return
	end
	
	self._StopTrack:Fire()
end


function AnimationTrack._Update(self : AnimationTrack, deltaTime : number)
	self._Accumulated += deltaTime
	local framerateInterval = 1 / self.Framerate
	
	if self._Accumulated >= framerateInterval then
		self._Accumulated = 0
		
		if self._Frozen then
			return
		end
		
		self.CurrentFrame.Value += 1
	end
end

--[[
	Returns a Signal that fires when the animation 
	reaches a marker with the same name as the given name.
]]
function AnimationTrack.GetMarkerReachedSignal(self : AnimationTrack, markerName : string) : Signal.Signal<string?>
	local signal : Signal.Signal<string?> = self._MarkerSignals[markerName] or Signal.new()
	self._MarkerSignals[markerName] = signal
	
	return signal
end

--[[
	Changes the spritesheet of the AnimationTrack.
	Can either take in an ID or an instance with
	a Texture or Image property.
]]
function AnimationTrack.ChangeSpritesheet(self : AnimationTrack, texture : InstanceConfig | string)
	if typeof(texture) == "Instance" then
		if texture:IsA("Decal") then
			self.Spritesheet = texture.ColorMap
		elseif texture:IsA("ImageLabel") or texture:IsA("ImageButton") then
			self.Spritesheet = texture.Image
		end
	elseif type(texture) == "string" then
		self.Spritesheet = texture
	end
end


function AnimationTrack.__tostring(self : AnimationTrack)
	return `AnimationTrack<{self.DebugId or self.Spritesheet}>`
end

--[[
	Destroys the AnimationTrack.
]]
function AnimationTrack.Destroy(self : AnimationTrack)
	for _, signal in self._MarkerSignals do
		signal:DisconnectAll()
	end
	
	self.Stopped:DisconnectAll()
	self.DidLoop:DisconnectAll()
	self._PlayTrack:DisconnectAll()
	self._StopTrack:DisconnectAll()
	self.CurrentFrame:Destroy()
	
	table.clear(self)
	table.freeze(self)
end



return AnimationTrack
