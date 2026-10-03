--!strict

--[[

	Lop's RichText Module

	Written by @lopjoss

]]


--[[

	Paired markup tags (e.g. <font=...></font>) must have its tags wrap around the text of
	which you want it to apply its styling to.

	There are also self-enclosed markup tags (e.g. <br=2>), which you can just use loosely.

	Currently does not support the use of "<" outside of a tag.

	Demonstration of use:
	
		Today I crashed into a <effect=Stinky>garbage truck</effect>.
		<br=1><wait=2><anim=Wiggle>The driver was not happy.</anim>

	Supported markup tags:
	
		<anim=SlideFromTop></anim>
			
			The animation that plays when rendering text.
			Available animations: SlideFromTop, SlideFromBottom, Transparent, BounceFromTop, BounceFromBottom, Wiggle, None

		<animduration=2></animduration>
		
			The duration of the text animation.

		<animloop=true></animloop>
		
			Indicates whether the text animation should loop or not.
			
		<color=255,255,255></color> | <color=red></color>
		
			The color of the rendered text in r,g,b format. 
			Can make use of shortcuts, like red, green, blue, etc. instead of this format.
			Check the config module to see all those shortcuts.

		<font=rbxasset://fonts/families/Arial.json></font> | <font=rbxassetid://12187377099></font>
		
			The font used for the rendered text.
			This might add a slight delay when rendering due to it having to download a new font, so pre-rendering 
			the text before that is recommended (that is if you're sure the font hasn't been dowloaded already).
			Find fonts in the Creator Store or here: https://create.roblox.com/docs/reference/engine/datatypes/Font

		<italic=true></italic>
		
			Indicates whether the rendered text should be italic or not.
			
		<weight=Bold></weight>
		
			The font weight of the rendered text.
			All available font weights found at:
			https://create.roblox.com/docs/reference/engine/enums/FontWeight?utm_source=studio&utm_content=autocomplete

		<transparency=.25></transparency>
		
			The transparency of the rendered text.
			
		<size=16></size>
		
			The size of the rendered text in offset. Clamped between 0 and 100.
			Unaffected by any UIScale applied to the container.
			In case the container changes in absolute size, the size of the rendered
			text and the remaining text will be scaled proportionally.
			
		<effect=Shiny></effect>
		
			Visual effect applied to the rendered text.
			Available effects: Shiny, Shake, Rainbow, Stinky, None
			
		<typewriterinterval=.05></typewriterinterval>
		
			The interval in seconds between each rendered character.
			
		<typewritersoundid=1234567890></typewritersoundid>
		
			The asset ID of the sound that will be played when actively rendering text.
			Set the value to / to remove this.
			
		<wait=5>
		
			Pauses rendering for the specified time in seconds. Calling :PauseRender() will pause this wait, which
			will then resume when calling :ResumeRender().
			Does not require a closing tag.

		<br=2>
		
			Adds a line break for the specified amount.
			Does not require a closing tag.
	
	API:
	
		.new(container, properties)
	
			Creates and returns a new RichText object.

			container: GuiObject
			The GuiObject that will contain any rendered text. When it gets destroyed,
			the object will be automatically destroyed too.

			properties: properties?
			A dict which overrides the object's default properties with any properties it contains.
			Obtained from calling .newProperties().
		
		.newProperties()
		
			Returns an empty dict typed as properties.
		
		:UpdateProperties(properties)
		
			Overrides the object's properties with any properties from the given dict.
	
			properties: properties
			The dict, obtained from calling .newProperties().
		
		:Render(text, yield, wrapped, preRender)

			Renders the given text inside the object's container and applies the object's
			properties to it. Stops any previous render and clears its text.

			text: string
			The text (including its markup) that is going to be rendered.
	
			yield: boolean?
    		Indicates whether the render should yield the calling thread.
	
			wrapped: boolean?
			Indicates whether the rendered text should wrap inside the object's container.
			Defaults to true.
    
			preRender: boolean?
    		Indicates whether this call should be performed as a pre-render.
    		Pre-renders are instant (except when having to download any fonts or fetch text bounds) and don't
    		display anything visually.
			Can be used to get the rendered text's dimensions before the actual render.
			Or to download any new fonts in advance which would prevent possible delays during the
			actual render.
    
        :CompleteRender()
    	
    		Immediately completes rendering. (excluding pre-renders)
			
		:PauseRender()
		
			Pauses rendering. (excluding pre-renders)
			
		:ResumeRender()
		
			Resumes paused rendering.
			
		:GetRenderedDimensions()
		
			Returns the absolute size of all rendered text, including whitespace.

    	:Clear()
    	
    		Stops any rendering and clears any rendered text.
    		
    	:Destroy()
    	
    		Stops any rendering, clears any rendered text, and destroys the object.
    		
    	.onRenderEnded
    	
    		A BindableEvent that will fire when a render has completed or been cleared.
    		
    	.empty
    	
    		A boolean that indicates whether the object's container holds no visibly rendered text,
    		so excluding pre-rendered text.
    		
    	.rendering
    	
    		A boolean that indicates whether the object has an active render going, including pre-renders,
    		despite it possibly being paused.
    	
	TODO:
	- add image markup
	- :ChangeContainer method
	- change parser to recognize whole words with markup inside as one
	- add attributes to tags
	- mark, strikethrough, underline, and stroke markups
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local util = require(script:WaitForChild("Util"))
local types = require(script:WaitForChild("Types"))
local config = require(script:WaitForChild("Config"))
local assets = script:FindFirstChild("Assets")

local updater : {[GuiObject] : (deltaTime : number) -> ()} = {}

type markup = {
	format : (value : any, self : classType) -> types.properties,
	convert : (value : string, self : classType) -> any
}

type selfClosingMarkup = {
	utilize : (value : any, self : classType) -> (),
	convert : (value : string, self : classType) -> any
}

local selfClosingMarkups : {[string] : selfClosingMarkup} = {}
selfClosingMarkups.wait = {
	utilize = function(value : number, self : classType)
		if not self._preRender and not self._ignoreIntervals then
			self:_Yield(value)
		end
	end,
	convert = util.stringToNumber
}
selfClosingMarkups.br = {
	utilize = function(value : number, self : classType)
		for i = 1, value do
			self:_CreateNewRow()
		end
	end,
	convert = util.stringToNumber
}

local markups : {[string] : markup} = {}
markups.size = {
	format = function(value : number) return {Size = value} :: types.properties end,
	convert = function(value : string)		
		return math.clamp(util.stringToNumber(value), 0, 100)
	end,
}
markups.italic = {
	format = function(value : boolean) return {Italic = value} :: types.properties end,
	convert = util.stringToBoolean
}
markups.animduration = {
	format = function(value : number) return {AnimationDuration = value} :: types.properties end,
	convert = util.stringToNumber
}
markups.typewriterinterval = {
	format = function(value : number) return {TypewriterInterval = value} :: types.properties end,
	convert = util.stringToNumber
}
markups.typewritersoundid = {
	format = function(string_ : string?) return {TypewriterSoundId = string_} :: types.properties end,
	convert = function(value : string) : string?
		if value ~= "/" then
			return "rbxassetid://" .. value
		else 
			return nil
		end
	end,
}
markups.animloop = {
	format = function(value : boolean) return {AnimationLoop = value} :: types.properties end,
	convert = util.stringToBoolean
}
markups.transparency = {
	format = function(value : number) return {Transparency = value} :: types.properties end,
	convert = util.stringToNumber
}
markups.effect = {
	format = function(value : string) return {Effect = value} :: types.properties end,
	convert = function(value : string) : string
		for k in pairs(types.runtime.effects :: {[string] : boolean}) do
			if k == value then
				return value
			end
		end
		
		error(value .. " is not a valid effect", 0)
	end,
}
markups.font = {
	format = function(value : string) return {Font = value} :: types.properties end,
	convert = function(value : string, self : classType)
		return util.fetchTextBounds(self._id, ".", config.DEFAULT_PROPERTIES) and value
	end,
}
markups.weight = {
	format = function(value : Enum.FontWeight) return {Weight = value} :: types.properties end,
	convert = function(value : string)
		return util.stringToFontWeight(value)
	end
}
markups.anim = {
	format = function(value : string, self : classType)
		return {Animation = value} :: types.properties
	end,
	convert = function(value : string) : string
		for k in pairs(types.runtime.animations :: {[string] : boolean}) do
			if k == value then
				return value
			end
		end
		
		error(value .. " is not a valid animation", 0)
	end,
}
markups.color = {
	format = function(value : Color3) return {Color = value} :: types.properties end,
	convert = function(value : string)
		if config.COLOR_SHORTCUTS[value] then
			return config.COLOR_SHORTCUTS[value]
		end

		return util.stringToColor3(value)
	end
}

local RichText = {}
RichText.__index = RichText

export type classType = typeof(
	setmetatable(
		{} :: {
			_container : GuiObject?,
			_properties : types.properties,
			_id : number,
			_baseZIndex : number,
			_effectZIndex : number,
			
			_text : string,
			_layout : UIListLayout?,
			_wrapped : boolean,
			_renderProperties : types.properties,
			_renderTraceback : string,
			_preRender : boolean,
			_pausedRender : boolean,
			_contentFolder : Folder?,
			_containerDefaultAbsoluteSize : Vector2,
			_markupHistory : {[number] : {type : string, previous : types.properties}},
			_actionQueue : {[number] : () -> ()},
			_actionQueueIndex : number,
			_executionThread : thread,
			_ignoreIntervals : boolean,
			_currentRow : Frame?,
			_clearedEvent : BindableEvent?,
			_cachedTypewriterSound : Sound?,
			
			_animGroupIndex : number,

			_verticalOverflowWarn : boolean?,
			_horizontalOverflowWarn : boolean?,
			_nextTypewriterSfxTime : number?,
			_loadingTypewriterSfx : boolean?,
			
			empty : boolean,
			rendering : boolean,
			onRenderEnded : BindableEvent?,
		},
		RichText
	)
)

--[[
	Creates and returns a new RichText object.

	<strong>container</strong>: GuiObject
	The GuiObject that will contain any rendered text. When it gets destroyed, the object will be automatically destroyed too.

	<strong>properties</strong>: properties?
	A dict which overrides the object's default properties with any properties it contains.
	Obtained from calling <code>.newProperties()</code>.
]]
RichText.new = function(
	container : GuiObject,
	properties : types.properties?
) : classType
	local self = setmetatable(
		{
			_container = container,
			_properties = table.clone(config.DEFAULT_PROPERTIES),
			_id = os.clock(),
			_baseZIndex = container.ZIndex,
			_effectZIndex = container.ZIndex,
			
			empty = true,
			onRenderEnded = Instance.new("BindableEvent")
		},
		RichText
	) :: classType

	if properties then
		util.updateProperties(self._properties, properties)
	end
	
	local baseOffset = self._properties.ZIndexOffset or config.ZINDEX_OFFSET or 0
	local effectOffset = self._properties.EffectZIndexOffset or config.EFFECTZINDEX_OFFSET or 1

	self._baseZIndex = container.ZIndex + baseOffset
	self._effectZIndex = self._baseZIndex + effectOffset
	
	container.Destroying:Once(function()
		self:Destroy()
	end)

	return self
end

--[[
	Returns an empty dict typed as properties.
]]
RichText.newProperties = function()
	return {} :: types.properties
end

--[[
	Overrides the object's properties with any properties from the given dict.
	
	<strong>properties</strong>: properties?
	The dict, obtained from calling <code>.newProperties()</code>.
]]
function RichText:UpdateProperties(properties : types.properties)
	local self : classType = self
	
	util.updateProperties(self._properties, properties)
	
	if self._container then
		local baseOffset = self._properties.ZIndexOffset or config.ZINDEX_OFFSET or 0
		local effectOffset = self._properties.EffectZIndexOffset or config.EFFECTZINDEX_OFFSET or 1

		self._baseZIndex = self._container.ZIndex + baseOffset
		self._effectZIndex = self._baseZIndex + effectOffset
	end
end

--[[
    Renders the given text inside the object's container and applies the object's properties to it. Stops any previous render and clears its text.

	<strong>text</strong>: string
	The text (including its markup) that is going to be rendered.
	
	<strong>yield</strong>: boolean?
    Indicates whether the render should yield the calling thread.
	
	<strong>wrapped</strong>: boolean?
	Indicates whether the rendered text should wrap inside the object's container. Defaults to true.
    
	<strong>preRender</strong>: boolean?
    Indicates whether this call should be performed as a pre-render.
    Pre-renders are instant (except when having to download any fonts or fetch text bounds) and don't display anything visually.
	Can be used to get the rendered text's dimensions before the actual render. Or to download any new fonts in advance which would prevent possible delays during the actual render.
]]
function RichText:Render(
	text : string,
	yield : boolean?,
	wrapped : boolean?,
	preRender : boolean?
)
	local self : classType = self
	
	if self._container  then
		local source, line = debug.info(2, "sl")
		self._renderTraceback = string.format("Resulting from Render call at:\n%s Line %s", source, line)

		if self._container.AbsoluteSize.Magnitude ~= 0 then
			self:Clear()
			
			self.empty = preRender or false
			self.rendering = true
			
			self._verticalOverflowWarn = false
			self._horizontalOverflowWarn = false
			self._text = text
			self._renderProperties = table.clone(self._properties)
			self._preRender = preRender or false
			self._wrapped = wrapped or wrapped == nil and true
			self._pausedRender = false
			self._animGroupIndex = 0
			self._markupHistory = {}
			self._ignoreIntervals = false

			self._contentFolder = Instance.new("Folder", self._container)
			self._contentFolder.Name = "RichTextContent"

			self._containerDefaultAbsoluteSize = self._container.AbsoluteSize
			self._layout = Instance.new("UIListLayout", self._contentFolder)
			self._layout.VerticalAlignment = self._renderProperties.YAlign

			self:_CreateNewRow()
			self:_Parse()
			
			-- localizing event in case render gets called rapidly
			local clearedEvent = Instance.new("BindableEvent")
			
			self._clearedEvent = clearedEvent
			
			clearedEvent.Event:Once(function()
				clearedEvent:Destroy()
			end)

			self._executionThread = coroutine.create(function()
				for i, callback in ipairs(self._actionQueue) do
					self._actionQueueIndex = i

					callback()
				end

				self.rendering = false
				
				self.onRenderEnded:Fire()
			end)

			coroutine.resume(self._executionThread)

			if yield then
				self:_YieldWhile(function()
					return self.rendering
				end)
			end
		else
			warn("Object's container has an absolute size of 0, 0; cannot render\n" .. self._renderTraceback)
		end
	end
end

--[[
	Immediately completes rendering. (excluding pre-renders)
]]
function RichText:CompleteRender()
	local self : classType = self

	if not self._preRender then
		self:ResumeRender()

		self._ignoreIntervals = true
	end
end

--[[
	Pauses rendering. (excluding pre-renders)
]]
function RichText:PauseRender()
	local self : classType = self

	if 
		not self._pausedRender
		and not self._preRender 
	then
		self._pausedRender = true
	end
end

--[[
	Resumes paused rendering.
]]
function RichText:ResumeRender()
	local self : classType = self

	if 
		self._pausedRender
		and self._executionThread
		and coroutine.status(self._executionThread) == "suspended"
		and not self._preRender
	then
		self._pausedRender = false

		coroutine.resume(self._executionThread)
	end
end

--[[
	Returns the absolute size of all rendered text, including whitespace.
]]
function RichText:GetRenderedDimensions() : Vector2
	local self : classType = self
	
	if self.empty and not self._preRender then
		return Vector2.zero
	end
	
	local maxWidth = 0
	for _, row in ipairs(self._contentFolder:GetChildren()) do
		if row:IsA("Frame") then
			local layout : UIListLayout = row:FindFirstChildWhichIsA("UIListLayout")
			
			maxWidth = math.max(maxWidth, layout.AbsoluteContentSize.X)
		end
	end
	
	return Vector2.new(
		maxWidth,
		self._layout.AbsoluteContentSize.Y
	)
end

--[[
    Stops any rendering and clears any rendered text.
]]
function RichText:Clear()
	local self : classType = self

	if not self.empty or self._preRender then		
		if self.rendering then
			-- Render sets `rendering` before the thread, folder, and cleared
			-- event exist. A throw in between used to crash Clear and hide that error.
			if self._executionThread then
				coroutine.close(self._executionThread)
			end

			self.rendering = false
			
			if self.onRenderEnded then
				self.onRenderEnded:Fire()
			end
		end
		
		if self._contentFolder then
			self._contentFolder:Destroy()
			self._contentFolder = nil
		end
		
		if self._clearedEvent then
			self._clearedEvent:Fire()
		end
		
		self.empty = true
	end
end

--[[
	Stops any rendering, clears any rendered text, and destroys the object.
]]
function RichText:Destroy()
	local self : classType = self
	
	self:Clear()
	
	self._layout = nil
	self._currentRow = nil
	self._container = nil
	self._clearedEvent = nil
	
	if self.onRenderEnded then
		self.onRenderEnded:Destroy()
		self.onRenderEnded = nil
	end
	
	util.removeTextBoundsCache(self._id)
end

function RichText:_GetProportionalSize(size : number?) : number
	local self : classType = self
	
	return self._container and (size or self._renderProperties.Size) * (
		self._container.AbsoluteSize.Magnitude/self._containerDefaultAbsoluteSize.Magnitude
	)
end

function RichText:_CreateNewRow()
	local self : classType = self
	
	if not self._container then
		return
	end
	
	self._currentRow = Instance.new("Frame", self._contentFolder)
	self._currentRow.Name = "Row"
	self._currentRow.Size = UDim2.fromScale(1, 0)
	self._currentRow.BackgroundTransparency = 1
	self._currentRow.AutomaticSize = Enum.AutomaticSize.Y
	self._currentRow.ZIndex = self._baseZIndex
	
	local layout = Instance.new("UIListLayout", self._currentRow)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = self._renderProperties.XAlign
end

function RichText:_PrintString(str : string)
	local self : classType = self
	
	if not self._container then
		return
	end
		
	local isWhitespace = string.match(str, "%s")
	local row : Frame = self._currentRow
	
	-- calculating the width of the word
	-- in case it does not fit, should wrap, and isn't whitespace it starts a new row,
	-- and when occupying more than config.MAX_WORD_WIDTH_FRACTION of the current row
	-- it'll split the word before that
	local wordWidth = 0
	for i = 1, string.len(str) do
		local size = self:_GetProportionalSize()
		local dashWidth = util.fetchTextBounds(self._id, "-", self._renderProperties, size).X
		local characterWidth = util.fetchTextBounds(self._id, string.sub(str, i, i), self._renderProperties, size).X
		
		local totalWidth = ((row and util.getWidthOfChildren(row)) or 0)
			+ wordWidth
			+ characterWidth
			+ dashWidth
		
		if totalWidth <= self._container.AbsoluteSize.X or not self._wrapped then
			wordWidth += characterWidth
		else
			if wordWidth >= self._container.AbsoluteSize.X * config.MAX_WORD_WIDTH_FRACTION then
				self:_CreateNewRow()

				local remainder = string.sub(str, i, string.len(str)):gsub("^%s+", "")
				str = string.sub(str, 1, i-1) .. "-"

				table.insert(self._actionQueue, self._actionQueueIndex + 1, function(...)
					self:_PrintString(remainder)
				end)

				break
			elseif not isWhitespace then
				wordWidth += characterWidth
				
				self:_CreateNewRow()
				row = self._currentRow
			else -- should not print whitespace at the start of a new row
				self:_CreateNewRow()
				
				return
			end
		end
	end
	
	if 
		not self._verticalOverflowWarn
		and not self._preRender
		and self._layout.AbsoluteContentSize.Y - self._container.AbsoluteSize.Y >= .001
	then
		self._verticalOverflowWarn = true
		
		warn(
			"Text \"" .. string.sub(self._text, 1, config.DEBUG_OVERFLOW_MAX_TEXT_LENGTH)
				.. (#self._text > config.DEBUG_OVERFLOW_MAX_TEXT_LENGTH and "..." or "")
				.. "\" is vertically overflowing in its container\n"
				.. self._renderTraceback
		)
	end
	if 
		not self._horizontalOverflowWarn
		and not self._preRender
		and self._layout.AbsoluteContentSize.X - self._container.AbsoluteSize.X >= .001
	then
		self._horizontalOverflowWarn = true

		warn(
			"Text \"" .. string.sub(self._text, 1, config.DEBUG_OVERFLOW_MAX_TEXT_LENGTH)
				.. (#self._text > config.DEBUG_OVERFLOW_MAX_TEXT_LENGTH and "..." or "")
				.. "\" is horizontally overflowing in its container\n"
				.. self._renderTraceback
		)
	end

	for i = 1, string.len(str) do
		local size = self:_GetProportionalSize()
		local isWhitespace = string.match(str, "%s")
		local characterWidth = util.fetchTextBounds(self._id, string.sub(str, i, i), self._renderProperties, size).X
		
		local container = Instance.new("Frame", row)
		container.SizeConstraint = Enum.SizeConstraint.RelativeXX
		container.Size = UDim2.fromScale(characterWidth/row.AbsoluteSize.X, size/row.AbsoluteSize.X)
		container.Name = string.sub(str, i, i)
		container.BackgroundTransparency = 1
		container.ZIndex = self._baseZIndex
		
		if not self._preRender then
			local animContainer = Instance.new("Frame", container)
			animContainer.Name = "AnimationContainer"
			animContainer.Size = UDim2.fromScale(1, 1)
			animContainer.BackgroundTransparency = 1
			animContainer.ZIndex = self._baseZIndex

			local char = Instance.new("TextLabel", animContainer)
			char.Size = UDim2.fromScale(1, 1)
			char.BackgroundTransparency = 1
			char.Text = string.sub(str, i, i)
			char.TextColor3 = self._renderProperties.Color
			char.TextXAlignment = Enum.TextXAlignment.Left
			char.TextTransparency = self._renderProperties.Transparency
			char.FontFace = Font.new(
				self._renderProperties.Font,
				self._renderProperties.Weight,
				self._renderProperties.Italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal
			)
			char.ZIndex = self._baseZIndex + 2
			
			local constraint = Instance.new("UITextSizeConstraint", char)
			constraint.MinTextSize = size
			constraint.MaxTextSize = size
			
			local defaultSize = self._renderProperties.Size
			char:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				local size = self:_GetProportionalSize(defaultSize)
				constraint.MinTextSize = 0

				constraint.MaxTextSize = size
				constraint.MinTextSize = math.clamp(size, 0, 100)
			end)
			
			if not self._ignoreIntervals then
				self:_AnimateCharacter(animContainer, char)
			end
			self:_ApplyEffectToCharacter(char, char)

			local t = os.clock()
			
			if 
				self._renderProperties.TypewriterSoundId
				and not self._loadingTypewriterSfx
				and not self._ignoreIntervals
				and not isWhitespace
				and (
					not self._nextTypewriterSfxTime
						or t >= self._nextTypewriterSfxTime
				)
			then
				if not self._cachedTypewriterSound or self._cachedTypewriterSound.SoundId ~= self._renderProperties.TypewriterSoundId then
					if self._cachedTypewriterSound then
						self._cachedTypewriterSound:Destroy()
					end
					
					self._loadingTypewriterSfx = true

					local sound = Instance.new("Sound", script)
					sound.Volume = config.TYPEWRITER_SFX_VOLUME
					sound.SoundId = self._renderProperties.TypewriterSoundId
					
					self._cachedTypewriterSound = sound
					
					local function onLoaded()
						self._loadingTypewriterSfx = false
					end

					if not sound.IsLoaded then
						sound.Loaded:Once(onLoaded)
					else
						onLoaded()
					end
				else
					if self._cachedTypewriterSound.IsPlaying then
						self._cachedTypewriterSound:Stop()
					end
					
					self._cachedTypewriterSound:Play()
					
					self._nextTypewriterSfxTime = t + math.max(
						config.TYPEWRITER_SFX_INTERVAL,
						self._renderProperties.TypewriterInterval
					)
				end
			end

			if self._renderProperties.TypewriterInterval ~= 0 and not self._ignoreIntervals then
				self:_Yield(self._renderProperties.TypewriterInterval)
			end
			
			if self._pausedRender then
				coroutine.yield()
			end
		end
	end
end

function RichText:_Parse()
	local self : classType = self

	local i = 1
	local str = self._text
	local hist : {[number] : string} = {}
	
	self._actionQueue = {}

	while i <= #str do
		local char = string.sub(str, i, i)

		if char ~= "<" and not string.match(char, "%s") then
			-- captures string from i to a whitespace or "<" 
			local _, word, endPos = string.match(str, "()([^<%s]+)()", i)
			
			if word then
				table.insert(self._actionQueue, function()
					self:_PrintString(word)
				end)
			end

			i = endPos or #str
		elseif string.match(char, "%s") then
			table.insert(self._actionQueue, function()
				self:_PrintString(char)
			end)

			i += 1
		elseif char == "<" then
			if string.sub(str, i + 1, i + 1) ~= "/" then
				local _, typeEndPos = string.find(str, "=", i)
				local _, valueEndPos = string.find(str, ">", i)

				if valueEndPos then
					if typeEndPos and typeEndPos < valueEndPos and valueEndPos ~= typeEndPos + 1 then
						local type_ = string.lower(string.sub(str, i + 1, typeEndPos - 1))
						local value = string.sub(str, typeEndPos + 1, valueEndPos - 1)
						
						local markup = selfClosingMarkups[type_] or markups[type_]
						
						if markup then
							local success, convertedValue = pcall(markup.convert, value, self)

							if success then
								table.insert(hist, 1, type_)

								table.insert(self._actionQueue, function()
									self:_ApplyMarkup(type_, value)
								end)
							else
								warn("Failed to parse tag \"<" .. type_ .. "=" .. value .. ">\": " .. convertedValue :: string .. "\n" .. self._renderTraceback)
							end
						else
							warn("Failed to parse tag \"<" .. type_ .. "=" .. value .. ">\": not a valid tag\n" .. self._renderTraceback)
						end
					else
						warn("Failed to parse tag \"" .. string.sub(str, i, valueEndPos) .. "\": no assigned value found\n" .. self._renderTraceback)
					end

					i = valueEndPos + 1
				else
					local _, typeEndPos = string.find(str, "%s", i)
					warn("Failed to parse tag \"" .. string.sub(str, i, typeEndPos or #str) .. "\": no closing angle bracket found\n" .. self._renderTraceback)

					i = #str
				end
			else
				local _, typeEndPos = string.find(str, ">", i)

				if typeEndPos then
					local type_ = string.lower(string.sub(str, i + 2, typeEndPos - 1))

					if markups[type_] then
						for i, v in ipairs(hist) do
							if v == type_ then
								table.remove(hist, i)
								
								table.insert(self._actionQueue, function()
									self:_RemoveMarkup(type_)
								end)
								
								break
							elseif i == #hist then
								warn("Failed to parse tag \"</" .. type_ .. ">\": no opening tag found\n" .. self._renderTraceback)
							end
						end
					else
						warn("Failed to parse tag \"</" .. type_ .. ">\": not a valid tag\n" .. self._renderTraceback)
					end

					i = typeEndPos + 1
				else
					local _, typeEndPos = string.find(str, "%s", i)
					warn("Failed to parse tag \"" .. string.sub(str, i, typeEndPos or #str) .. "\": no closing angle bracket found\n" .. self._renderTraceback)

					i = #str
				end
			end
		end
	end
end

function RichText:_ApplyMarkup(type_ : string, value : string)
	local self : classType = self

	if markups[type_] then
		local markup = markups[type_]
		local convertedValue = markup.convert(value, self)
		
		local markupProperties = markup.format(convertedValue, self)
		local previous = util.updateProperties(self._renderProperties, markupProperties)

		table.insert(self._markupHistory, 1, {type = type_, previous = previous})
	elseif selfClosingMarkups[type_] then
		local markup = selfClosingMarkups[type_]
		local convertedValue = markup.convert(value, self)

		markup.utilize(convertedValue, self)
	end
end

function RichText:_RemoveMarkup(type_ : string)
	local self : classType = self

	for i, v in ipairs(self._markupHistory) do
		if v.type == type_ then
			util.updateProperties(self._renderProperties, v.previous)

			table.remove(self._markupHistory, i)
		end
	end
end

function RichText:_Yield(duration : number)
	local self : classType = self

	local last = os.clock()
	local elapsed = 0

	while elapsed < duration and not self._ignoreIntervals do
		RunService.RenderStepped:Wait()

		local time_ = os.clock()
		local delta = time_ - last
		last = time_
		
		if not self._pausedRender then
			elapsed += delta
		end
	end
end

function RichText:_YieldWhile(callback : () -> boolean)
	local self : classType = self

	while callback() and not self._ignoreIntervals do
		RunService.RenderStepped:Wait()
	end
end

function RichText:_AnimateCharacter(container : GuiObject, char : TextLabel)
	local self : classType = self

	if self._renderProperties.Animation ~= "None" then
		local size = self:_GetProportionalSize()
		local parent = container.Parent :: GuiObject
		
		if self._renderProperties.Animation == "SlideFromBottom" or self._renderProperties.Animation == "SlideFromTop" then			
			container.Position = self._renderProperties.Animation == "SlideFromBottom"
				and UDim2.fromScale(
					(size * config.ANIMATIONS.SLIDE_OFFSET_FACTOR) / parent.AbsoluteSize.X,
					(size * config.ANIMATIONS.SLIDE_OFFSET_FACTOR) / parent.AbsoluteSize.Y
				)
				or UDim2.fromScale(
					(size * config.ANIMATIONS.SLIDE_OFFSET_FACTOR) / parent.AbsoluteSize.X,
					(-size * config.ANIMATIONS.SLIDE_OFFSET_FACTOR) / parent.AbsoluteSize.Y
				)
			container.Rotation = self._renderProperties.Animation == "SlideFromBottom"
				and config.ANIMATIONS.SLIDE_ROTATION
				or -config.ANIMATIONS.SLIDE_ROTATION

			local tweenInfo = TweenInfo.new(
				self._renderProperties.AnimationDuration,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out,
				self._renderProperties.AnimationLoop and -1 or 0,
				self._renderProperties.AnimationLoop and true or false
			)

			local containerTween = TweenService:Create(
				container,
				tweenInfo,
				{Position = UDim2.fromScale(0, 0), Rotation = 0}
			)
			local charTween = TweenService:Create(
				char,
				tweenInfo,
				{TextTransparency = self._renderProperties.Transparency}
			)
			
			containerTween:Play()
			charTween:Play()
			
			self.onRenderEnded.Event:Once(function()
				containerTween:Cancel()
				charTween:Cancel()
				
				char.TextTransparency = self._renderProperties.Transparency
				container.Position = UDim2.fromScale(0, 0)
				container.Rotation = 0
			end)
		elseif self._renderProperties.Animation == "Transparent" then
			char.TextTransparency = config.ANIMATIONS.TRANSPARENT_STARTING_VAL

			local charTween = TweenService:Create(
				char,
				TweenInfo.new(
					self._renderProperties.AnimationDuration,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out,
					self._renderProperties.AnimationLoop and -1 or 0,
					self._renderProperties.AnimationLoop and true or false
				),
				{TextTransparency = self._renderProperties.Transparency}
			)
			
			charTween:Play()
			
			self.onRenderEnded.Event:Once(function()
				charTween:Cancel()
				
				char.TextTransparency = self._renderProperties.Transparency
			end)
		elseif self._renderProperties.Animation == "BounceFromTop" or self._renderProperties.Animation == "BounceFromBottom" then
			container.Position = self._renderProperties.Animation == "BounceFromTop"
				and UDim2.fromScale(0, (-size * config.ANIMATIONS.BOUNCE_OFFSET_FACTOR) / parent.AbsoluteSize.Y)
				or UDim2.fromScale(0, (size * config.ANIMATIONS.BOUNCE_OFFSET_FACTOR) / parent.AbsoluteSize.Y)

			local tweenInfo = TweenInfo.new(
				self._renderProperties.AnimationDuration,
				Enum.EasingStyle.Bounce,
				Enum.EasingDirection.Out,
				self._renderProperties.AnimationLoop and -1 or 0,
				self._renderProperties.AnimationLoop and true or false
			)

			local containerTween = TweenService:Create(
				container,
				tweenInfo,
				{Position = UDim2.fromScale(0, 0)}
			)
			local charTween = TweenService:Create(
				char,
				tweenInfo,
				{TextTransparency = self._renderProperties.Transparency}
			)
			
			containerTween:Play()
			charTween:Play()

			self.onRenderEnded.Event:Once(function()
				containerTween:Cancel()
				charTween:Cancel()
				
				char.TextTransparency = self._renderProperties.Transparency
				container.Position = UDim2.fromScale(0, 0)
			end)
		elseif self._renderProperties.Animation == "Wiggle" then
			local last = os.clock()
			local defaultPos = container.Position
			local duration = self._renderProperties.AnimationDuration
			local loop = self._renderProperties.AnimationLoop
			local index = self._animGroupIndex
			local containerSize = container.AbsoluteSize
			local parentSize = parent.AbsoluteSize
			
			local containerCon = container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				containerSize = container.AbsoluteSize
			end)
			local parentCon = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				parentSize = parent.AbsoluteSize
			end)
			
			updater[container] = function()
				debug.profilebegin("Wiggle Animation Markup")

				local time_ = os.clock()
				local elapsed = time_ - last
				local yOffset = math.sin(
					(time_ / (loop and duration or (1/config.ANIMATIONS.WIGGLE_OSC_FACTOR)) * math.pi * 2)
					+ (math.pi * 2 * config.ANIMATIONS.WIGGLE_OFFSET_FACTOR * index) -- offset between characters
				) 
					* (loop and 1 or (1 - (elapsed / duration))) -- fades out if not looping
					* config.ANIMATIONS.WIGGLE_BASE_AMPLITUDE
					* (containerSize.Y / config.REFERENCE_SIZE) -- scaling proportionally with size
				
				container.Position = defaultPos + UDim2.fromScale(0, yOffset/parentSize.Y)

				if (elapsed >= duration or not self.rendering) and not loop then
					container.Position = defaultPos
					
					updater[container] = nil
					
					containerCon:Disconnect()
					parentCon:Disconnect()
				end

				debug.profileend()
			end
			
			self._clearedEvent.Event:Once(function()
				updater[container] = nil
				
				containerCon:Disconnect()
				parentCon:Disconnect()
			end)

			self._animGroupIndex += 1
		end
	end
end

function RichText:_ApplyEffectToCharacter(container : GuiObject, char : TextLabel)
	local self : classType = self

	if self._renderProperties.Effect ~= "None" then
		local size = self:_GetProportionalSize()
		local parent = container.Parent :: GuiObject

		if self._renderProperties.Effect == "Shake" then
			local defaultPos = container.Position
			local containerSize = container.AbsoluteSize
			local parentSize = parent.AbsoluteSize
			
			container:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				containerSize = container.AbsoluteSize
			end)
			parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				parentSize = parent.AbsoluteSize
			end)
			
			updater[container] = function()
				debug.profilebegin("Shake Effect Markup")
				
				local offset = config.EFFECTS.SHAKE_MAX_OFFSET_FACTOR * containerSize.Y
				local yOffset = offset * math.random(-100, 100)/100
				local xOffset = offset * math.random(-100, 100)/100
				
				container.Position = defaultPos + UDim2.fromScale(xOffset/parent.AbsoluteSize.X, yOffset/parentSize.Y)

				debug.profileend()
			end
			
			self._clearedEvent.Event:Once(function()
				updater[container] = nil
			end)
		elseif self._renderProperties.Effect == "Rainbow" then
			updater[container] = function(dt)
				debug.profilebegin("Rainbow Effect Markup")

				char.TextColor3 = Color3.fromHSV((os.clock() * config.EFFECTS.RAINBOW_CYCLE_FACTOR) % 1, 1, 1)

				debug.profileend()
			end
			
			self._clearedEvent.Event:Once(function()
				updater[container] = nil
			end)
		elseif self._renderProperties.Effect == "Shiny"
			or self._renderProperties.Effect == "Stinky" then

			local effect : string = self._renderProperties.Effect
			local rate : number -- per second
			local chance : number

			if effect == "Shiny" then
				rate = config.EFFECTS.SHINY_RATE
				chance = config.EFFECTS.SHINY_CHANCE
			elseif effect == "Stinky" then
				rate = config.EFFECTS.STINKY_RATE
				chance = config.EFFECTS.STINKY_CHANCE
			end
			
			-- desyncing characters printed roughly at the same time
			local interval = 1 / rate
			local last = os.clock() - math.random() * interval
			
			updater[container] = function(dt)
				debug.profilebegin("Image Emitting Effect Markup")

				local c = os.clock()
				if c - last >= interval then
					last = c 

					if math.random()*100 <= chance then
						local image : ImageLabel
						local size : UDim2, rotation : number, lifetime : number

						if effect == "Shiny" then
							if assets and assets:FindFirstChild("Sparkle") then
								image = assets.Sparkle:Clone()
							end
							size = UDim2.fromScale(
								math.random(config.EFFECTS.SHINY_MIN_SIZE*100, config.EFFECTS.SHINY_MAX_SIZE*100)/100,
								math.random(config.EFFECTS.SHINY_MIN_SIZE*100, config.EFFECTS.SHINY_MAX_SIZE*100)/100
							)
							rotation = 0
							lifetime = math.random(
								config.EFFECTS.SHINY_MIN_LIFETIME,
								config.EFFECTS.SHINY_MAX_LIFETIME
							)/1000
						elseif effect == "Stinky" then
							if assets and assets:FindFirstChild("Smoke") then
								image = assets.Smoke:Clone()
								image.ImageColor3 = config.EFFECTS.STINKY_COLOR
								image.ImageTransparency = config.EFFECTS.STINKY_TRANSPARENCY
							end

							size = UDim2.fromScale(
								math.random(config.EFFECTS.STINKY_MIN_SIZE*100, config.EFFECTS.STINKY_MAX_SIZE*100)/100,
								math.random(config.EFFECTS.STINKY_MIN_SIZE*100, config.EFFECTS.STINKY_MAX_SIZE*100)/100
							)
							rotation = math.random(-config.EFFECTS.STINKY_MIN_ROTATION, config.EFFECTS.STINKY_MAX_ROTATION)
							lifetime = math.random(
								config.EFFECTS.STINKY_MIN_LIFETIME,
								config.EFFECTS.STINKY_MAX_LIFETIME
							)/1000
						end

						if image then
							image.Size = UDim2.fromScale(0, 0)
							image.Parent = char
							image.Position = UDim2.fromScale(math.random(), math.random())
							image.ZIndex = self._effectZIndex

							local tween = TweenService:Create(
								image,
								TweenInfo.new(lifetime/2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
								{Size = size, Rotation = rotation}
							)
							tween:Play()
							tween.Completed:Once(function()
								local tween = TweenService:Create(
									image,
									TweenInfo.new(lifetime/2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
									{Size = UDim2.fromScale(0, 0), Position = image.Position + UDim2.fromScale(0, 0.05)}
								)
								tween:Play()
								tween.Completed:Once(function()
									image:Destroy()
								end)
							end)
						end
					end
				end

				debug.profileend()
			end
			
			self._clearedEvent.Event:Once(function()
				updater[container] = nil
			end)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	debug.profilebegin("RichText Updater")
	
	for frame, callback in pairs(updater) do
		if updater[frame] then
			local success, errmsg : string? = pcall(callback, dt)

			if not success then
				warn("RichText updater callback error: " .. errmsg :: string)
			end
		end
	end

	debug.profileend()
end)

return RichText