local SoundService = game:GetService("SoundService")
local ClientLog = require(script.Parent.log).ClientLog
local Soundtrack = require(script.Parent.soundtrack)

-- Plays the game's one soundtrack (see soundtrack.luau) on two decks. The
-- active deck plays the current track; the spare deck loads the next track in
-- the background, so a hand-over never waits on a download. Nothing here knows
-- which page is open -- pages have no say in the music.
--
-- One worker thread owns sequencing (hand-over point, crossfade, load
-- failures). The mix setters only touch volume and pause/resume, so there is a
-- single writer for which track plays where.
local MUSIC_ASSET_MANIFEST = Soundtrack.manifest()
local DECK_NAMES = { "SoundtrackA", "SoundtrackB" }
-- How often the worker checks the playing track for its hand-over point.
local POLL_SECONDS = 0.25
local FADE_STEP_SECONDS = 0.05
-- A track that has not loaded after this long is skipped (and retried later).
-- Generous: at boot the asset preloader is pulling thousands of assets over the
-- same connection, and a 6 MB track routinely needs more than 8 seconds then.
local LOAD_DEADLINE_SECONDS = 30

local activeDirector = nil

local function makeDeck(name, group)
	local sound = Instance.new("Sound")
	sound.Name = name
	-- Looped as a safety net: if a hand-over point is ever missed, the track
	-- repeats instead of going silent, and DidLoop triggers the hand-over.
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Name = "BedGlue"
	compressor.Threshold = -18
	compressor.Ratio = 2
	compressor.Attack = 0.02
	compressor.Release = 0.2
	compressor.Parent = sound
	local equalizer = Instance.new("EqualizerSoundEffect")
	equalizer.Name = "TrackTone"
	equalizer.Parent = sound
	return {
		sound = sound,
		equalizer = equalizer,
		trackIndex = nil,
		loadStarted = 0,
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
	function MusicDirector:constructor(group)
		self.group = group
		self.decks = { makeDeck(DECK_NAMES[1], group), makeDeck(DECK_NAMES[2], group) }
		self.active = 1
		self.trackIndex = 1
		self.fading = false
		self.fadeAlpha = 0
		self.loopedOver = false
		self.failedAt = {}
		self.mix = 1
		self.duck = 1
		self.audible = true
		self.started = false
		self.disposed = false
		self.connections = {}
	end
	function MusicDirector:isLive()
		return self.started and not self.disposed and self.audible and self.mix * self.duck > 0.001
	end
	function MusicDirector:spare()
		return if self.active == 1 then 2 else 1
	end
	function MusicDirector:loadDeck(deckIndex, trackIndex)
		local deck = self.decks[deckIndex]
		local track = Soundtrack.track(trackIndex)
		deck.sound:Stop()
		deck.sound.Volume = 0
		deck.trackIndex = trackIndex
		deck.loadStarted = os.clock()
		if deck.sound.SoundId ~= track.asset then
			deck.sound.SoundId = track.asset
		end
		deck.sound.PlaybackSpeed = 1
		deck.sound.TimePosition = 0
		deck.equalizer.LowGain = track.low
		deck.equalizer.MidGain = track.mid
		deck.equalizer.HighGain = track.high
	end
	-- Push the current mix onto the decks. During a hand-over the two decks
	-- share an equal-power crossfade; otherwise only the active deck sounds.
	function MusicDirector:applyVolumes()
		local activeDeck = self.decks[self.active]
		local spareDeck = self.decks[self:spare()]
		if not self:isLive() then
			activeDeck.sound.Volume = 0
			spareDeck.sound.Volume = 0
			return nil
		end
		local activeLevel = Soundtrack.volume(Soundtrack.track(activeDeck.trackIndex or self.trackIndex), self.mix, self.duck)
		if self.fading and spareDeck.trackIndex ~= nil then
			local outGain, inGain = Soundtrack.fadeGains(self.fadeAlpha)
			activeDeck.sound.Volume = activeLevel * outGain
			spareDeck.sound.Volume = Soundtrack.volume(Soundtrack.track(spareDeck.trackIndex), self.mix, self.duck) * inGain
		else
			activeDeck.sound.Volume = activeLevel
			spareDeck.sound.Volume = 0
		end
		return nil
	end
	-- Bring playback in line with the live state: sounding when audible, paused
	-- (keeping its place) when muted, hidden or switched off. Resume() rather
	-- than Play(): Play() restarts from the last script-set TimePosition, which
	-- would send a paused track back to its start.
	function MusicDirector:refresh()
		if self.disposed or not self.started then
			return nil
		end
		self:applyVolumes()
		local activeSound = self.decks[self.active].sound
		local spareSound = self.decks[self:spare()].sound
		if self:isLive() then
			if not activeSound.IsPlaying then
				activeSound:Resume()
			end
			if self.fading and not spareSound.IsPlaying then
				spareSound:Resume()
			end
		else
			if activeSound.IsPlaying then
				activeSound:Pause()
			end
			if spareSound.IsPlaying then
				spareSound:Pause()
			end
		end
		return nil
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
		self:loadDeck(self.active, self.trackIndex)
		for index, deck in self.decks do
			table.insert(self.connections, deck.sound.DidLoop:Connect(function()
				-- The hand-over point was missed (a long hitch, or a track too
				-- short to crossfade): move on at the loop instead.
				if index == self.active and not self.fading then
					self.loopedOver = true
				end
			end))
		end
		self:refresh()
		self.worker = task.spawn(function()
			while not self.disposed do
				task.wait(POLL_SECONDS)
				if self.disposed then
					break
				end
				-- One bad poll must not kill the worker, or the soundtrack would
				-- stop advancing for the rest of the session.
				local ok, problem = pcall(self.step, self)
				if not ok and not self.disposed then
					-- A failure mid-crossfade would otherwise leave `fading` set and
					-- block every later poll; drop back to the active deck.
					self.fading = false
					self.fadeAlpha = 0
					pcall(self.refresh, self)
					ClientLog:warnEvery("music-step", 30, "Audio", `soundtrack step failed: {tostring(problem)}`)
				end
			end
		end)
		return nil
	end
	function MusicDirector:markFailed(trackIndex)
		self.failedAt[trackIndex] = os.clock()
		local name = Soundtrack.track(trackIndex).name
		ClientLog:warnEvery(`music-load-{name}`, 30, "Audio", `{name} did not load; skipping it for now`)
	end
	-- The playing track never arrived: move straight on rather than sit silent.
	function MusicDirector:skipActive()
		self:markFailed(self.trackIndex)
		local nextIndex = Soundtrack.nextIndex(self.trackIndex, self.failedAt, os.clock())
		if nextIndex ~= nil then
			self.trackIndex = nextIndex
		end
		-- With nothing else playable this retries the same track from scratch.
		self:loadDeck(self.active, self.trackIndex)
		self:refresh()
		return nil
	end
	-- Load the next track into the spare deck well before it is needed.
	function MusicDirector:prepareSpare()
		local nextIndex = Soundtrack.nextIndex(self.trackIndex, self.failedAt, os.clock())
		if nextIndex == nil then
			return nil
		end
		local spareIndex = self:spare()
		local spare = self.decks[spareIndex]
		if spare.trackIndex ~= nextIndex then
			self:loadDeck(spareIndex, nextIndex)
			return nil
		end
		if not spare.sound.IsLoaded and os.clock() - spare.loadStarted >= LOAD_DEADLINE_SECONDS then
			-- The next track never arrived; mark it so the one after is lined up.
			self:markFailed(nextIndex)
			spare.trackIndex = nil
		end
		return nil
	end
	function MusicDirector:step()
		if not self:isLive() or self.fading then
			return nil
		end
		local deck = self.decks[self.active]
		local sound = deck.sound
		if not sound.IsLoaded then
			if os.clock() - deck.loadStarted >= LOAD_DEADLINE_SECONDS then
				self:skipActive()
			end
			return nil
		end
		if not sound.IsPlaying then
			sound:Resume()
		end
		self:prepareSpare()
		local due = self.loopedOver or Soundtrack.shouldAdvance(sound.TimeLength, sound.TimePosition, sound.PlaybackSpeed)
		self.loopedOver = false
		if due then
			self:handOver()
		end
		return nil
	end
	-- Crossfade from the playing track into the one waiting on the spare deck.
	-- Runs on the worker thread; the mix setters keep adjusting volume meanwhile.
	function MusicDirector:handOver()
		local spareIndex = self:spare()
		local spare = self.decks[spareIndex]
		local nextIndex = spare.trackIndex
		if nextIndex == nil or not spare.sound.IsLoaded then
			-- Still downloading: the current track plays on, and the hand-over
			-- happens on a later poll once the next one has arrived.
			return nil
		end
		self.fading = true
		self.fadeAlpha = 0
		spare.sound.TimePosition = 0
		self:refresh()
		local elapsed = 0
		while elapsed < Soundtrack.CROSSFADE_SECONDS do
			local dt = task.wait(FADE_STEP_SECONDS)
			if self.disposed then
				return nil
			end
			-- Only audible time counts, so muting mid-fade freezes the fade
			-- rather than finishing it silently.
			if self:isLive() then
				elapsed += dt
			end
			self.fadeAlpha = math.clamp(elapsed / Soundtrack.CROSSFADE_SECONDS, 0, 1)
			self:applyVolumes()
		end
		local outgoing = self.decks[self.active].sound
		outgoing:Stop()
		outgoing.Volume = 0
		self.active = spareIndex
		self.trackIndex = nextIndex
		self.fading = false
		self.fadeAlpha = 0
		self:refresh()
		ClientLog:debug("audio", `soundtrack: {Soundtrack.track(nextIndex).name}`)
		return nil
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
		self:refresh()
		return nil
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
		self:refresh()
		return nil
	end
	function MusicDirector:setAudible(audible)
		if self.disposed then
			return nil
		end
		self.audible = audible == true
		self:refresh()
		return nil
	end
	function MusicDirector:resume()
		self:refresh()
		return nil
	end
	function MusicDirector:currentTrack()
		return Soundtrack.track(self.trackIndex).name
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
		if self.worker ~= nil then
			pcall(task.cancel, self.worker)
			self.worker = nil
		end
		for _, connection in self.connections do
			connection:Disconnect()
		end
		table.clear(self.connections)
		for _, deck in self.decks do
			pcall(function()
				deck.sound:Destroy()
			end)
		end
		return nil
	end
end
return {
	DECK_NAMES = DECK_NAMES,
	MUSIC_ASSET_MANIFEST = MUSIC_ASSET_MANIFEST,
	MusicDirector = MusicDirector,
}
