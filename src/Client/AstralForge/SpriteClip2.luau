local RunService = game:GetService("RunService")
local scheduled = {}
local schedulerConnection
local function stopSchedulerIfIdle()
	-- ▼ ReadonlyMap.size ▼
	local _size = 0
	for _ in scheduled do
		_size += 1
	end
	-- ▲ ReadonlyMap.size ▲
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
		-- ▼ ReadonlyMap.forEach ▼
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
		-- ▲ ReadonlyMap.forEach ▲
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
		-- ▼ ReadonlyMap.forEach ▼
		local _callback = function(bindable)
			return bindable:Destroy()
		end
		for _k, _v in _exp do
			_callback(_v, _k, _exp)
		end
		-- ▲ ReadonlyMap.forEach ▲
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
