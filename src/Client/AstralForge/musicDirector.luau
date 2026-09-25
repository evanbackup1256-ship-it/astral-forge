local SoundService = game:GetService("SoundService")
local ClientLog = require(script.Parent.log).ClientLog
local FALLBACK_BED = "rbxassetid://9046476113"
local GAME_BED = {
	name = "Atrium",
	asset = "rbxassetid://9038252619",
	gain = 0.84,
	speed = 1,
	startAt = 0,
	low = 2.2,
	mid = 1.6,
	high = -1.2,
	glue = 1.7,
	glueThreshold = -18,
}
local ORBIT_BED = {
	name = "Orbit",
	asset = "rbxassetid://9046476113",
	gain = 0.78,
	speed = 0.97,
	startAt = 0,
	low = -0.5,
	mid = 2.2,
	high = 0.6,
}
local FORGE_BED = {
	name = "Foundry",
	asset = "rbxassetid://5410086218",
	gain = 0.8,
	speed = 0.95,
	startAt = 0,
	low = 5.5,
	mid = 0.2,
	high = -6.5,
	glue = 3.4,
	glueThreshold = -13,
}
local CORE_IDLE = {
	name = "Core",
	asset = "rbxassetid://9120386436",
	gain = 0.72,
	speed = 1.04,
	startAt = 0,
	low = -8,
	mid = -2.4,
	high = 7.5,
	glue = 1.5,
	glueThreshold = -22,
}
local NIGHT_SHIFT = {
	name = "Night",
	asset = "rbxassetid://9046476113",
	gain = 0.7,
	speed = 0.92,
	startAt = 18,
	low = 3.5,
	mid = -3,
	high = -4,
}
local VAULT_HUM = {
	name = "Vault",
	asset = "rbxassetid://9038252619",
	gain = 0.72,
	speed = 0.93,
	startAt = 28,
	low = 4.5,
	mid = -2.5,
	high = -5,
}
local SLAG_LINE = {
	name = "Line",
	asset = "rbxassetid://5410086218",
	gain = 0.8,
	speed = 1.05,
	startAt = 10,
	low = -2.5,
	mid = 3.2,
	high = 2.5,
}
local ION_DRIFT = {
	name = "Ion",
	asset = "rbxassetid://9120386436",
	gain = 0.74,
	speed = 0.96,
	startAt = 36,
	low = 1.5,
	mid = -3.5,
	high = 1.5,
}
local FOUNDRY_LOW = {
	name = "Anvil",
	asset = "rbxassetid://5410086218",
	gain = 0.76,
	speed = 0.91,
	startAt = 22,
	low = 2.5,
	mid = -1.5,
	high = -2.5,
}
local GRID_WASH = {
	name = "Market",
	asset = "rbxassetid://9038252619",
	gain = 0.8,
	speed = 1.05,
	startAt = 14,
	low = -3.5,
	mid = 0.4,
	high = 4.5,
}
local QUIET_DOCK = {
	name = "Dock",
	asset = "rbxassetid://9046476113",
	gain = 0.58,
	speed = 0.98,
	startAt = 44,
	low = -1,
	mid = -0.5,
	high = -2,
}
local OVERDRIVE = {
	name = "Prize",
	asset = "rbxassetid://5410086218",
	gain = 0.88,
	speed = 1.06,
	startAt = 6,
	low = -4.5,
	mid = 0.8,
	high = 6,
}
local ECHO_HALL = {
	name = "Hall",
	asset = "rbxassetid://9120386436",
	gain = 0.72,
	speed = 0.94,
	startAt = 48,
	low = -1,
	mid = 2.5,
	high = -1.5,
}
local STAR_LANE = {
	name = "Lane",
	asset = "rbxassetid://9038252619",
	gain = 0.78,
	speed = 1.01,
	startAt = 20,
	low = -1.5,
	mid = -1.5,
	high = 3.2,
}
local COLD_ANVIL = {
	name = "Shift",
	asset = "rbxassetid://9046476113",
	gain = 0.74,
	speed = 0.96,
	startAt = 32,
	low = 0.5,
	mid = 1.5,
	high = -2.5,
}
local BEDS = { GAME_BED, ORBIT_BED, FORGE_BED, CORE_IDLE, NIGHT_SHIFT, VAULT_HUM, SLAG_LINE, ION_DRIFT, FOUNDRY_LOW, GRID_WASH, QUIET_DOCK, OVERDRIVE, ECHO_HALL, STAR_LANE, COLD_ANVIL }
local BED_SECONDS = 168
local THEMES = {
	Overview = GAME_BED,
	Workshop = FORGE_BED,
	Research = CORE_IDLE,
	StarGrid = ORBIT_BED,
	Echoes = ECHO_HALL,
	Continuum = ION_DRIFT,
	Convergence = ORBIT_BED,
	Lab = FORGE_BED,
	Anomaly = NIGHT_SHIFT,
	Worlds = STAR_LANE,
	Missions = GAME_BED,
	Milestones = VAULT_HUM,
	Wheel = OVERDRIVE,
	Rewards = OVERDRIVE,
	Boosts = SLAG_LINE,
	Command = GAME_BED,
	Story = ECHO_HALL,
	Mail = STAR_LANE,
	Chat = QUIET_DOCK,
	Crew = STAR_LANE,
	Guild = VAULT_HUM,
	Leaderboards = GRID_WASH,
	Credits = QUIET_DOCK,
	Shop = GRID_WASH,
	Inventory = VAULT_HUM,
	Trade = GRID_WASH,
	Settings = QUIET_DOCK,
	Admin = QUIET_DOCK,
	ForgePath = FOUNDRY_LOW,
	boot = GAME_BED,
}
local MUSIC_ASSET_MANIFEST = { GAME_BED.asset, ORBIT_BED.asset, FORGE_BED.asset, FALLBACK_BED, CORE_IDLE.asset }
local BASE_VOLUME = 0.16
local FADE_STEP_SECONDS = 0.02
local LOAD_DEADLINE_SECONDS = 8
local function smoothstep(alpha)
	local t = math.clamp(alpha, 0, 1)
	return t * t * (3 - 2 * t)
end
local activeDirector = nil
local function makeDeck(name, group)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Name = "BedGlue"
	compressor.Threshold = -16
	compressor.Ratio = 2.6
	compressor.Attack = 0.02
	compressor.Release = 0.16
	compressor.Parent = sound
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "ViewColor"
	equalizer.Parent = sound
	return {
		sound = sound,
		equalizer = equalizer,
		compressor = compressor,
	}
end
local MusicDirector
do
	MusicDirector = setmetatable({}, {
		__tostring = function()
			return "MusicDirector"
		end,
	})
	MusicDirector.__index = MusicDirector
	function MusicDirector.new(...)
		local self = setmetatable({}, MusicDirector)
		return self:constructor(...) or self
	end
	function MusicDirector:constructor(group, initialTheme)
		if initialTheme == nil then
			initialTheme = "Overview"
		end
		self.group = group
		self.deckThemes = table.create(2)
		self.positions = {}
		self.activeDeck = 0
		self.mix = 1
		self.duck = 1
		self.crossfade = 0.7
		self.audible = true
		self.started = false
		self.transitionToken = 0
		self.transitionAlpha = 0
		self.transitionFromUnit = 0
		self.disposed = false
		self.bedIndex = 0
		self.rotateBed = false
		self.theme = initialTheme
		self.decks = { makeDeck("ViewMusicA", group), makeDeck("ViewMusicB", group) }
	end
	function MusicDirector:currentBed()
		return BEDS[self.bedIndex + 1] or GAME_BED
	end
	function MusicDirector:bedForTheme(theme)
		if theme == "boot" then
			return GAME_BED
		end
		local mapped = THEMES[theme]
		if mapped ~= nil then
			return mapped
		end
		return self:currentBed()
	end
	function MusicDirector:resolveBed(theme, preferRotated)
		if preferRotated then
			return self:currentBed()
		end
		return self:bedForTheme(theme)
	end
	function MusicDirector:targetVolume(theme)
		if theme == nil then
			theme = self.theme
		end
		local bed = self:bedForTheme(theme)
		return BASE_VOLUME * bed.gain * self.mix * self.duck
	end
	function MusicDirector:clearTransition()
		self.transitionOutgoing = nil
		self.transitionIncoming = nil
		self.transitionAlpha = 0
		self.transitionFromUnit = 0
	end
	function MusicDirector:applyTransitionMix()
		local outgoingIndex = self.transitionOutgoing
		local incomingIndex = self.transitionIncoming
		if outgoingIndex == nil or incomingIndex == nil then
			return false
		end
		local enabled = self.audible and self.mix * self.duck > 0.001
		local fade = math.clamp(self.transitionAlpha, 0, 1)
		local outCurve = math.cos(fade * math.pi * 0.5)
		local inCurve = math.sin(fade * math.pi * 0.5)
		self.decks[outgoingIndex + 1].sound.Volume = if enabled then self.transitionFromUnit * self.mix * self.duck * outCurve else 0
		self.decks[incomingIndex + 1].sound.Volume = if enabled then self:targetVolume(self.theme) * inCurve else 0
		return true
	end
	function MusicDirector:resumeTransition()
		local outgoingIndex = self.transitionOutgoing
		local incomingIndex = self.transitionIncoming
		if outgoingIndex == nil or incomingIndex == nil then
			return false
		end
		if not self.audible or self.mix * self.duck <= 0.001 then
			return true
		end
		local outgoing = self.decks[outgoingIndex + 1].sound
		local incoming = self.decks[incomingIndex + 1].sound
		if self.transitionAlpha < 1 and not outgoing.IsPlaying then
			outgoing:Play()
		end
		if not incoming.IsPlaying then
			incoming:Play()
		end
		self:applyTransitionMix()
		return true
	end
	function MusicDirector:configure(index, theme, token)
		local deck = self.decks[index + 1]
		local spec = self:resolveBed(theme, self.rotateBed)
		self.deckThemes[index + 1] = theme
		deck.bed = spec
		deck.loadToken = (deck.loadToken or 0) + 1
		local loadToken = deck.loadToken
		local _result = deck.loaded
		if _result ~= nil then
			_result:Disconnect()
		end
		deck.loaded = nil
		deck.sound:Stop()
		deck.sound.SoundId = spec.asset
		deck.sound.PlaybackSpeed = spec.speed
		deck.sound.Volume = 0
		deck.equalizer.LowGain = spec.low
		deck.equalizer.MidGain = spec.mid
		deck.equalizer.HighGain = spec.high
		local glue = deck.compressor
		if glue ~= nil then
			glue.Ratio = if spec.glue ~= nil then spec.glue else 2.6
			glue.Threshold = if spec.glueThreshold ~= nil then spec.glueThreshold else -16
		end
		local _positions = self.positions
		local _theme = theme
		local _condition = _positions[_theme]
		if _condition == nil then
			_condition = spec.startAt
		end
		local desired = _condition
		local seek = function()
			if loadToken ~= deck.loadToken or token ~= self.transitionToken or self.disposed or deck.sound.Parent == nil then
				return nil
			end
			local length = deck.sound.TimeLength
			deck.sound.TimePosition = if length > 1 then desired % math.max(1, length - 0.25) else 0
		end
		local armFallback = function()
			if loadToken ~= deck.loadToken or token ~= self.transitionToken or self.disposed or deck.sound.Parent == nil then
				return nil
			end
			if deck.sound.TimeLength > 0.2 then
				return nil
			end
			if deck.sound.SoundId == FALLBACK_BED then
				return nil
			end
			deck.sound.SoundId = FALLBACK_BED
			if self.audible and self.mix * self.duck > 0.001 and not deck.sound.IsPlaying then
				deck.sound:Play()
			end
		end
		if deck.sound.IsLoaded then
			seek()
			armFallback()
		else
			deck.loaded = deck.sound.Loaded:Connect(function()
				local _result_1 = deck.loaded
				if _result_1 ~= nil then
					_result_1:Disconnect()
				end
				deck.loaded = nil
				seek()
				armFallback()
			end)
			task.delay(2.4, function()
				if loadToken ~= deck.loadToken or token ~= self.transitionToken or self.disposed then
					return nil
				end
				armFallback()
			end)
		end
	end
	function MusicDirector:start()
		if self.started or self.disposed then
			return nil
		end
		if activeDirector ~= nil and activeDirector ~= self and not activeDirector.disposed then
			activeDirector:dispose()
		end
		activeDirector = self
		self.started = true
		self.rotateBed = false
		self:clearTransition()
		self.transitionToken += 1
		local token = self.transitionToken
		local deckIndex = self.activeDeck
		self:configure(deckIndex, self.theme, token)
		local active = self.decks[deckIndex + 1].sound
		active.Volume = self:targetVolume()
		self.startDelay = task.delay(0.08, function()
			self.startDelay = nil
			if token ~= self.transitionToken or deckIndex ~= self.activeDeck or active.Parent == nil then
				return nil
			end
			if self.audible and self.mix * self.duck > 0.001 and not active.IsPlaying then
				active:Play()
			end
		end)
		self:startRotation()
	end
	function MusicDirector:startRotation()
		if self.rotateWorker ~= nil then
			return nil
		end
		self.rotateWorker = task.spawn(function()
			while not self.disposed do
				task.wait(BED_SECONDS)
				if self.disposed then
					break
				end
				if self.theme == "boot" then
					continue
				end
				if self.transitionIncoming ~= nil and not self.rotateBed then
					continue
				end
				self.bedIndex = (self.bedIndex + 1) % #BEDS
				self:crossfadeTo(self.theme, true)
			end
		end)
	end
	function MusicDirector:setTheme(theme)
		if self.disposed then
			return nil
		end
		if not self.started then
			self:start()
		end
		if self.theme == theme then
			return nil
		end
		self:crossfadeTo(theme, false)
	end
	function MusicDirector:crossfadeTo(theme, forceBed)
		if self.disposed then
			return nil
		end
		local preferRotated = forceBed == true
		if not preferRotated and self.theme == theme then
			return nil
		end
		local nextBed = self:resolveBed(theme, preferRotated)
		local fadingIn = self.transitionIncoming
		local fadingOut = self.transitionOutgoing
		if fadingIn ~= nil and fadingOut ~= nil then
			local incomingDeck = self.decks[fadingIn + 1]
			local outgoingDeck = self.decks[fadingOut + 1]
			if incomingDeck.bed == nextBed then
				self.theme = theme
				self.rotateBed = preferRotated
				self.deckThemes[fadingIn + 1] = theme
				return nil
			end
			if outgoingDeck.bed == nextBed then
				local incomingSound = incomingDeck.sound
				local incomingTheme = self.deckThemes[fadingIn + 1]
				if incomingTheme ~= nil and incomingSound.TimePosition > 0 then
					self.positions[incomingTheme] = incomingSound.TimePosition
				end
				if self.transitionWorker ~= nil then
					pcall(function()
						return task.cancel(self.transitionWorker)
					end)
				end
				self.transitionWorker = nil
				local _pending = incomingDeck.loaded
				if _pending ~= nil then
					_pending:Disconnect()
				end
				incomingDeck.loaded = nil
				incomingDeck.loadToken = (incomingDeck.loadToken or 0) + 1
				incomingSound:Stop()
				incomingSound.Volume = 0
				self.activeDeck = fadingOut
				self.theme = theme
				self.rotateBed = false
				self.deckThemes[fadingOut + 1] = theme
				self:clearTransition()
				local outgoingSound = outgoingDeck.sound
				outgoingSound.Volume = if self.audible then self:targetVolume(theme) else 0
				if self.audible and self.mix * self.duck > 0.001 then
					if not outgoingSound.IsPlaying then
						outgoingSound:Play()
					end
				else
					outgoingSound:Pause()
				end
				return nil
			end
			self.theme = theme
			self.rotateBed = preferRotated
			self.transitionLoadStamp = os.clock()
			self:configure(fadingIn, theme, self.transitionToken)
			local incoming = incomingDeck.sound
			if self.audible and self.mix * self.duck > 0.001 and not incoming.IsPlaying then
				incoming:Play()
			end
			self:applyTransitionMix()
			return nil
		end
		if not preferRotated then
			local activeDeck = self.decks[self.activeDeck + 1]
			if activeDeck.bed == nextBed then
				self.theme = theme
				self.deckThemes[self.activeDeck + 1] = theme
				return nil
			end
		end
		local first = self.decks[1].sound
		local second = self.decks[2].sound
		local outgoingIndex = if second.Volume > first.Volume then 1 elseif first.Volume > second.Volume then 0 else self.activeDeck
		local incomingIndex = if outgoingIndex == 0 then 1 else 0
		local outgoing = self.decks[outgoingIndex + 1].sound
		local outgoingTheme = self.deckThemes[outgoingIndex + 1]
		if outgoingTheme ~= nil and outgoing.TimePosition > 0 then
			local _positions = self.positions
			local _timePosition = outgoing.TimePosition
			_positions[outgoingTheme] = _timePosition
		end
		self.theme = theme
		self.rotateBed = forceBed == true
		self.activeDeck = outgoingIndex
		self.transitionToken += 1
		local token = self.transitionToken
		if self.transitionWorker ~= nil then
			pcall(function()
				return task.cancel(self.transitionWorker)
			end)
		end
		self.transitionWorker = nil
		self:configure(incomingIndex, theme, token)
		local incoming = self.decks[incomingIndex + 1].sound
		if self.audible and self.mix * self.duck > 0.001 and not incoming.IsPlaying then
			incoming:Play()
		end
		self.transitionOutgoing = outgoingIndex
		self.transitionIncoming = incomingIndex
		self.transitionAlpha = 0
		local outgoingGain = self:bedForTheme(outgoingTheme or "Overview").gain
		self.transitionFromUnit = if self.mix * self.duck > 0.001 and outgoing.Volume > 0.0001 then outgoing.Volume / math.max(0.0001, self.mix * self.duck) else BASE_VOLUME * outgoingGain
		self:applyTransitionMix()
		self.transitionLoadStamp = os.clock()
		self.transitionWorker = task.defer(function()
			if self.transitionLoadStamp == nil then
				self.transitionLoadStamp = os.clock()
			end
			while token == self.transitionToken and self.transitionIncoming == incomingIndex and not incoming.IsLoaded and os.clock() - self.transitionLoadStamp < LOAD_DEADLINE_SECONDS do
				task.wait(0.08)
			end
			if token ~= self.transitionToken or self.transitionIncoming ~= incomingIndex then
				return nil
			end
			if not incoming.IsLoaded then
				local _result = self.decks[incomingIndex + 1].loaded
				if _result ~= nil then
					_result:Disconnect()
				end
				self.decks[incomingIndex + 1].loaded = nil
				self.decks[incomingIndex + 1].loadToken = (self.decks[incomingIndex + 1].loadToken or 0) + 1
				incoming:Stop()
				incoming.Volume = 0
				local failedTheme = self.theme
				self.activeDeck = outgoingIndex
				self.theme = outgoingTheme or "Overview"
				self:clearTransition()
				outgoing.Volume = if self.audible then self:targetVolume(self.theme) else 0
				if self.audible and self.mix * self.duck > 0.001 and not outgoing.IsPlaying then
					outgoing:Play()
				end
				local bedName = self:bedForTheme(failedTheme).name
				ClientLog:warnEvery(`music-load-{failedTheme}`, 30, "Audio", `{bedName} will retry on the next visit`)
				return nil
			end
			local fadeSeconds = 0.1 + self.crossfade * 0.42
			local fadeSteps = math.clamp(math.floor(fadeSeconds / FADE_STEP_SECONDS + 0.5), 6, 24)
			do
				local step = 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						step += 1
					else
						_shouldIncrement = true
					end
					if not (step <= fadeSteps) then
						break
					end
					if token ~= self.transitionToken or self.transitionIncoming ~= incomingIndex then
						return nil
					end
					if not incoming.IsLoaded then
						if os.clock() - self.transitionLoadStamp >= LOAD_DEADLINE_SECONDS then
							break
						end
						task.wait(0.08)
						_shouldIncrement = false
						continue
					end
					self.transitionAlpha = smoothstep(step / fadeSteps)
					self:applyTransitionMix()
					task.wait(FADE_STEP_SECONDS)
				end
			end
			while token == self.transitionToken and self.transitionIncoming == incomingIndex and not incoming.IsLoaded and os.clock() - self.transitionLoadStamp < LOAD_DEADLINE_SECONDS do
				task.wait(0.08)
			end
			if token ~= self.transitionToken or self.transitionIncoming ~= incomingIndex then
				return nil
			end
			if not incoming.IsLoaded then
				local _result = self.decks[incomingIndex + 1].loaded
				if _result ~= nil then
					_result:Disconnect()
				end
				self.decks[incomingIndex + 1].loaded = nil
				self.decks[incomingIndex + 1].loadToken = (self.decks[incomingIndex + 1].loadToken or 0) + 1
				incoming:Stop()
				incoming.Volume = 0
				local failedTheme = self.theme
				self.activeDeck = outgoingIndex
				self.theme = outgoingTheme or "Overview"
				self:clearTransition()
				outgoing.Volume = if self.audible then self:targetVolume(self.theme) else 0
				if self.audible and self.mix * self.duck > 0.001 and not outgoing.IsPlaying then
					outgoing:Play()
				end
				local bedName = self:bedForTheme(failedTheme).name
				ClientLog:warnEvery(`music-load-{failedTheme}`, 30, "Audio", `{bedName} will retry on the next visit`)
				return nil
			end
			outgoing:Pause()
			outgoing.Volume = 0
			self.activeDeck = incomingIndex
			self:clearTransition()
			incoming.Volume = self:targetVolume(self.theme)
			if not self.audible or self.mix * self.duck <= 0.001 then
				incoming:Pause()
			elseif not incoming.IsPlaying then
				incoming:Play()
			end
			self.transitionWorker = nil
		end)
	end
	function MusicDirector:setMix(value)
		if self.disposed then
			return nil
		end
		local nextMix = math.clamp(value, 0, 1)
		if math.abs(nextMix - self.mix) <= 0.0005 then
			return nil
		end
		self.mix = nextMix
		if not self.started then
			return nil
		end
		if self:applyTransitionMix() then
			if self.mix * self.duck <= 0.001 then
				for _, deck in self.decks do
					deck.sound:Pause()
				end
			else
				self:resumeTransition()
			end
			return nil
		end
		local active = self.decks[self.activeDeck + 1].sound
		active.Volume = if self.audible then self:targetVolume() else 0
		for index = 0, #self.decks - 1 do
			if index ~= self.activeDeck then
				self.decks[index + 1].sound.Volume = 0
				self.decks[index + 1].sound:Pause()
			end
		end
		if self.mix * self.duck <= 0.001 then
			active:Pause()
		else
			self:resume()
		end
	end
	function MusicDirector:setDuck(value)
		if self.disposed then
			return nil
		end
		local nextDuck = math.clamp(value, 0, 1)
		if math.abs(nextDuck - self.duck) <= 0.0005 then
			return nil
		end
		self.duck = nextDuck
		if not self.started then
			return nil
		end
		if self:applyTransitionMix() then
			if self.mix * self.duck <= 0.001 then
				for _, deck in self.decks do
					deck.sound:Pause()
				end
			else
				self:resumeTransition()
			end
			return nil
		end
		local active = self.decks[self.activeDeck + 1].sound
		active.Volume = if self.audible then self:targetVolume() else 0
		if self.mix * self.duck <= 0.001 then
			active:Pause()
		elseif self.audible then
			self:resume()
		end
	end
	function MusicDirector:setCrossfade(value)
		self.crossfade = math.clamp(value, 0, 1)
	end
	function MusicDirector:setAudible(audible)
		if self.disposed then
			return nil
		end
		if self.audible == audible then
			if audible then
				self:resume()
			end
			return nil
		end
		self.audible = audible
		if not audible then
			for _, deck in self.decks do
				deck.sound.Volume = 0
				deck.sound:Pause()
			end
			return nil
		end
		if self:resumeTransition() then
			return nil
		end
		if self.deckThemes[self.activeDeck + 1] ~= self.theme then
			self.rotateBed = false
			self:configure(self.activeDeck, self.theme, self.transitionToken)
		end
		self:resume()
	end
	function MusicDirector:resume()
		if self.disposed or not self.started or not self.audible or self.mix * self.duck <= 0.001 then
			return nil
		end
		if self:resumeTransition() then
			return nil
		end
		local active = self.decks[self.activeDeck + 1].sound
		active.Volume = self:targetVolume()
		if not active.IsPlaying then
			active:Play()
		end
	end
	function MusicDirector:currentTheme()
		return self.theme
	end
	function MusicDirector:dispose()
		if self.disposed then
			return nil
		end
		self.disposed = true
		self.started = false
		if activeDirector == self then
			activeDirector = nil
		end
		self.transitionToken += 1
		self:clearTransition()
		if self.startDelay ~= nil then
			pcall(function()
				return task.cancel(self.startDelay)
			end)
		end
		if self.transitionWorker ~= nil then
			pcall(function()
				return task.cancel(self.transitionWorker)
			end)
		end
		if self.rotateWorker ~= nil then
			pcall(function()
				return task.cancel(self.rotateWorker)
			end)
		end
		self.startDelay = nil
		self.transitionWorker = nil
		self.rotateWorker = nil
		for _, deck in self.decks do
			local _result = deck.loaded
			if _result ~= nil then
				_result:Disconnect()
			end
			deck.loaded = nil
			pcall(function()
				return deck.sound:Destroy()
			end)
		end
	end
end
return {
	MUSIC_ASSET_MANIFEST = MUSIC_ASSET_MANIFEST,
	MusicDirector = MusicDirector,
}
