local SoundService = game:GetService("SoundService")
local ClientLog = require(script.Parent.log).ClientLog
local FALLBACK_BED = "rbxassetid://9046476113"
local GAME_BED = {
	name = "Metal Sci-Fi Universe",
	asset = "rbxassetid://9038252619",
	gain = 0.92,
	speed = 0.94,
	startAt = 0,
	low = 1.15,
	mid = 0.82,
	high = 0.9,
}
local ORBIT_BED = {
	name = "Orbit Drift",
	asset = "rbxassetid://9046476113",
	gain = 0.88,
	speed = 0.9,
	startAt = 0,
	low = 1.08,
	mid = 0.78,
	high = 0.96,
}
local FORGE_BED = {
	name = "Deep Forge",
	asset = "rbxassetid://5410086218",
	gain = 0.84,
	speed = 0.92,
	startAt = 0,
	low = 1.22,
	mid = 0.74,
	high = 0.86,
}
local CORE_IDLE = {
	name = "Core Idle",
	asset = "rbxassetid://9120386436",
	gain = 0.86,
	speed = 0.91,
	startAt = 0,
	low = 1.1,
	mid = 0.8,
	high = 0.94,
}
local NIGHT_SHIFT = {
	name = "Night Shift",
	asset = "rbxassetid://9046476113",
	gain = 0.8,
	speed = 0.84,
	startAt = 12,
	low = 1.28,
	mid = 0.7,
	high = 0.78,
}
local VAULT_HUM = {
	name = "Vault Hum",
	asset = "rbxassetid://9038252619",
	gain = 0.78,
	speed = 0.88,
	startAt = 24,
	low = 1.18,
	mid = 0.76,
	high = 0.84,
}
local SLAG_LINE = {
	name = "Slag Line",
	asset = "rbxassetid://5410086218",
	gain = 0.9,
	speed = 0.98,
	startAt = 8,
	low = 1.05,
	mid = 0.86,
	high = 0.92,
}
local ION_DRIFT = {
	name = "Ion Drift",
	asset = "rbxassetid://9120386436",
	gain = 0.74,
	speed = 0.8,
	startAt = 40,
	low = 0.92,
	mid = 0.7,
	high = 1.12,
}
local FOUNDRY_LOW = {
	name = "Foundry Low",
	asset = "rbxassetid://5410086218",
	gain = 0.82,
	speed = 0.86,
	startAt = 32,
	low = 1.34,
	mid = 0.68,
	high = 0.72,
}
local GRID_WASH = {
	name = "Grid Wash",
	asset = "rbxassetid://9038252619",
	gain = 0.88,
	speed = 1.02,
	startAt = 16,
	low = 0.96,
	mid = 0.9,
	high = 1.05,
}
local QUIET_DOCK = {
	name = "Quiet Dock",
	asset = "rbxassetid://9046476113",
	gain = 0.7,
	speed = 0.82,
	startAt = 48,
	low = 1.12,
	mid = 0.74,
	high = 0.88,
}
local OVERDRIVE = {
	name = "Overdrive",
	asset = "rbxassetid://5410086218",
	gain = 0.96,
	speed = 1.06,
	startAt = 4,
	low = 1.08,
	mid = 0.92,
	high = 1.0,
}
local ECHO_HALL = {
	name = "Echo Hall",
	asset = "rbxassetid://9120386436",
	gain = 0.76,
	speed = 0.76,
	startAt = 56,
	low = 1.02,
	mid = 0.66,
	high = 1.08,
}
local STAR_LANE = {
	name = "Star Lane",
	asset = "rbxassetid://9038252619",
	gain = 0.84,
	speed = 0.96,
	startAt = 20,
	low = 1.0,
	mid = 0.84,
	high = 0.98,
}
local COLD_ANVIL = {
	name = "Cold Anvil",
	asset = "rbxassetid://9046476113",
	gain = 0.8,
	speed = 0.78,
	startAt = 36,
	low = 1.24,
	mid = 0.72,
	high = 0.8,
}
local BEDS = { GAME_BED, ORBIT_BED, FORGE_BED, CORE_IDLE, NIGHT_SHIFT, VAULT_HUM, SLAG_LINE, ION_DRIFT, FOUNDRY_LOW, GRID_WASH, QUIET_DOCK, OVERDRIVE, ECHO_HALL, STAR_LANE, COLD_ANVIL }
local BED_SECONDS = 168
local THEMES = {
	Overview = GAME_BED,
	Workshop = FORGE_BED,
	Research = GAME_BED,
	StarGrid = ORBIT_BED,
	Echoes = ORBIT_BED,
	Continuum = ORBIT_BED,
	Convergence = ORBIT_BED,
	Lab = FORGE_BED,
	Anomaly = ORBIT_BED,
	Worlds = ORBIT_BED,
	Missions = GAME_BED,
	Milestones = GAME_BED,
	Wheel = GAME_BED,
	Rewards = GAME_BED,
	Boosts = GAME_BED,
	Command = GAME_BED,
	Story = GAME_BED,
	Mail = GAME_BED,
	Chat = GAME_BED,
	Crew = GAME_BED,
	Guild = GAME_BED,
	Leaderboards = GAME_BED,
	Credits = GAME_BED,
	Shop = GAME_BED,
	Inventory = GAME_BED,
	Trade = GAME_BED,
	Settings = GAME_BED,
	Admin = GAME_BED,
	ForgePath = FORGE_BED,
	boot = GAME_BED,
}
local MUSIC_ASSET_MANIFEST = { GAME_BED.asset, ORBIT_BED.asset, FORGE_BED.asset, FALLBACK_BED, CORE_IDLE.asset }
local BASE_VOLUME = 0.16
local FADE_STEP_SECONDS = 0.022
local LOAD_DEADLINE_SECONDS = 8
local function smoothstep(alpha)
	local t = math.clamp(alpha, 0, 1)
	return t * t * (3 - 2 * t)
end
local function makeDeck(name, group)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "ViewColor"
	equalizer.Parent = sound
	return {
		sound = sound,
		equalizer = equalizer,
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
		self.crossfade = 0.62
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
		self.decks[outgoingIndex + 1].sound.Volume = if enabled then self.transitionFromUnit * self.mix * self.duck * (1 - self.transitionAlpha) else 0
		self.decks[incomingIndex + 1].sound.Volume = if enabled then self:targetVolume(self.theme) * self.transitionAlpha else 0
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
		local _positions = self.positions
		local _theme = theme
		local _condition = _positions[_theme]
		if _condition == nil then
			_condition = spec.startAt
		end
		local desired = _condition
		local seek = function()
			if token ~= self.transitionToken or self.theme ~= theme or deck.sound.Parent == nil then
				return nil
			end
			local length = deck.sound.TimeLength
			deck.sound.TimePosition = if length > 1 then desired % math.max(1, length - 0.25) else 0
		end
		local armFallback = function()
			if token ~= self.transitionToken or self.theme ~= theme or deck.sound.Parent == nil then
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
				if token ~= self.transitionToken then
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
			self:resume()
			return nil
		end
		self:crossfadeTo(theme, false)
	end
	function MusicDirector:crossfadeTo(theme, forceBed)
		if self.disposed then
			return nil
		end
		if not forceBed and self.theme == theme then
			self:resume()
			return nil
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
		self.transitionWorker = task.defer(function()
			local loadStartedAt = os.clock()
			while token == self.transitionToken and not incoming.IsLoaded and os.clock() - loadStartedAt < LOAD_DEADLINE_SECONDS do
				task.wait(0.08)
			end
			if token ~= self.transitionToken then
				return nil
			end
			if not incoming.IsLoaded then
				local _result = self.decks[incomingIndex + 1].loaded
				if _result ~= nil then
					_result:Disconnect()
				end
				self.decks[incomingIndex + 1].loaded = nil
				incoming:Stop()
				incoming.Volume = 0
				self.activeDeck = outgoingIndex
				self.theme = outgoingTheme or "Overview"
				self:clearTransition()
				outgoing.Volume = if self.audible then self:targetVolume(self.theme) else 0
				if self.audible and self.mix * self.duck > 0.001 and not outgoing.IsPlaying then
					outgoing:Play()
				end
				local bedName = self:bedForTheme(theme).name
				ClientLog:warnEvery(`music-load-{theme}`, 30, "Audio", `{bedName} will retry on the next visit`)
				return nil
			end
			local fadeSeconds = 0.18 + self.crossfade * 0.82
			local fadeSteps = math.clamp(math.floor(fadeSeconds / FADE_STEP_SECONDS + 0.5), 10, 46)
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
					if token ~= self.transitionToken then
						return nil
					end
					self.transitionAlpha = smoothstep(step / fadeSteps)
					self:applyTransitionMix()
					task.wait(FADE_STEP_SECONDS)
				end
			end
			if token ~= self.transitionToken then
				return nil
			end
			outgoing:Pause()
			outgoing.Volume = 0
			self.activeDeck = incomingIndex
			self:clearTransition()
			incoming.Volume = self:targetVolume(theme)
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
