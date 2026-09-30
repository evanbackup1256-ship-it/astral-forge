--!strict
-- Guards for the game's single soundtrack.
--
-- What these lock in:
--   1. There is one soundtrack. Pages have no music of their own: the director
--      has no theme API, and changing page never touches it.
--   2. The playlist is sound data: real, unique assets, gentle mastering, even
--      levels, and a manifest the preloader can use.
--   3. Sequencing: tracks play in order and loop round; a track that fails to
--      load is skipped and retried later; the hand-over lands one crossfade
--      before the end, in real seconds; the crossfade is equal-power.
--   4. The settings that only existed for per-page music are gone end to end.
--   5. Paused music resumes where it stopped (Resume, not Play).
--
-- HARD: pure math and string checks -- no Roblox instances, no vendor requires.

local fs = require("./_memberfs")(require("@lune/fs"))

local Soundtrack = require("../src/Client/AstralForge/AudioKit")("soundtrack")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local audioSource = readSource("src/Client/AstralForge/AudioKit.luau#audio")
local directorSource = readSource("src/Client/AstralForge/AudioKit.luau#musicDirector")
local settingsSource = readSource("src/Client/AstralForge/pages/PagesSystem.luau#SettingsView")
local mainSource = readSource("src/Client/AstralForge/UiCore.luau#MainGame")
local templateSource = readSource("src/Server/AstralForge/DataTemplate.luau")
local dataSource = readSource("src/Server/AstralForge/Services/DataService.luau")
local servicesSource = readSource("src/Server/AstralForge/Services/ServerServices.luau")

------------------------------------------------------------------------
-- 1. One soundtrack: no per-page music anywhere
------------------------------------------------------------------------
for _, perView in { "THEMES", "setTheme", "crossfadeTo", "bedForTheme", "currentTheme", "ViewMusic" } do
	assert(not string.find(directorSource, perView, 1, true), "musicDirector still has per-view music: " .. perView)
end
for _, perView in { "VIEW_STINGS", "resolvedMusicTheme", "setTheme(", "setCrossfade", "pageStingers" } do
	assert(not string.find(audioSource, perView, 1, true), "audio.luau still has per-view audio: " .. perView)
end
local setViewBody = string.match(audioSource, "function Mixer:setView%(page, playCue%)(.-)\n\tend\n")
assert(setViewBody ~= nil, "could not isolate Mixer:setView")
assert(
	not string.find(setViewBody :: string, "musicDirector", 1, true) and not string.find(setViewBody :: string, "syncMusicState", 1, true),
	"changing page must not touch the music"
)
assert(string.find(setViewBody :: string, "self:play(NAVIGATION_CUE)", 1, true), "every page change must use the one navigation cue")
assert(string.find(audioSource, 'local NAVIGATION_CUE = "tabSwitch"', 1, true), "the navigation cue must be tabSwitch")

-- The director must exist and be configured before it starts, so a player with
-- music off or the master muted never hears a blip at boot.
do
	local startBody = string.match(audioSource, "function Mixer:start%(%)(.-)\n\tend\n")
	assert(startBody ~= nil, "could not isolate Mixer:start")
	local assignAt = string.find(startBody :: string, "self.musicDirector = musicDirector", 1, true)
	local syncAt = string.find(startBody :: string, "self:syncMusicState()", 1, true)
	local startAt = string.find(startBody :: string, "musicDirector:start()", 1, true)
	assert(assignAt and syncAt and startAt, "Mixer:start must create, sync and start the director")
	assert((assignAt :: number) < (syncAt :: number) and (syncAt :: number) < (startAt :: number), "sync must run after assignment and before start")
end

------------------------------------------------------------------------
-- 2. Playlist data
------------------------------------------------------------------------
local tracks = Soundtrack.tracks()
assert(Soundtrack.count() == #tracks and #tracks >= 2, "the soundtrack needs at least two tracks")
local seenAssets: { [string]: boolean } = {}
local seenNames: { [string]: boolean } = {}
for index, track in tracks do
	assert(string.match(track.asset, "^rbxassetid://%d+$") ~= nil, "track " .. track.name .. " has a malformed asset id")
	assert(not seenAssets[track.asset], "track asset repeated: " .. track.asset)
	assert(not seenNames[track.name], "track name repeated: " .. track.name)
	seenAssets[track.asset] = true
	seenNames[track.name] = true
	assert(track.gain > 0 and track.gain <= 1.2, "track gain out of range: " .. track.name)
	for _, band in { track.low, track.mid, track.high } do
		-- Gentle: the EQ evens tracks out, it does not recolour them the way
		-- the old per-view beds did (those ran from -8 to +7.5 dB).
		assert(math.abs(band) <= 3, "track EQ must stay gentle (within 3 dB): " .. track.name)
	end
	assert(Soundtrack.track(index) == track, "track(i) must return the i-th track")
end
assert(Soundtrack.track(#tracks + 1) == tracks[1], "track() must wrap past the end")

local manifest = Soundtrack.manifest()
assert(#manifest == #tracks, "the preload manifest must cover every track")
for _, asset in manifest do
	assert(seenAssets[asset], "manifest lists an asset that is not a track: " .. asset)
end
assert(
	string.find(directorSource, "local MUSIC_ASSET_MANIFEST = Soundtrack.manifest()", 1, true),
	"the preloader's music manifest must come from the soundtrack"
)

------------------------------------------------------------------------
-- 3. Sequencing
------------------------------------------------------------------------
-- In order, and round again.
do
	local order = {}
	local current = 1
	for _ = 1, #tracks * 2 do
		table.insert(order, current)
		current = Soundtrack.nextIndex(current, {}, 0) :: number
	end
	for step, index in order do
		assert(index == ((step - 1) % #tracks) + 1, "tracks must play in playlist order and loop round")
	end
end

-- A failed track is skipped, retried after RETRY_SECONDS, and when nothing
-- else is playable the current track just keeps going.
do
	local now = 1000
	assert(Soundtrack.nextIndex(1, { [2] = now }, now) == 3, "a track that failed to load must be skipped")
	assert(
		Soundtrack.nextIndex(1, { [2] = now }, now + Soundtrack.RETRY_SECONDS) == 2,
		"a failed track must be retried once RETRY_SECONDS have passed"
	)
	local allOthersFailed = {}
	for index = 2, #tracks do
		allOthersFailed[index] = now
	end
	assert(Soundtrack.nextIndex(1, allOthersFailed, now) == nil, "with nothing else playable the current track keeps looping")
end

-- The hand-over lands one crossfade before the end, in real seconds.
do
	local fade = Soundtrack.CROSSFADE_SECONDS
	assert(not Soundtrack.shouldAdvance(180, 10, 1), "a track must not hand over near its start")
	assert(not Soundtrack.shouldAdvance(180, 180 - fade - 0.5, 1), "a track must play until one crossfade from its end")
	assert(Soundtrack.shouldAdvance(180, 180 - fade + 0.1, 1), "a track must hand over inside the last crossfade")
	-- Half speed doubles the real time left, so the same position is not due yet.
	assert(not Soundtrack.shouldAdvance(180, 180 - fade + 0.1, 0.5), "PlaybackSpeed must scale the time left")
	assert(not Soundtrack.shouldAdvance(fade * 2, fade * 2 - 0.1, 1), "a track too short to crossfade is left to loop")
	assert(not Soundtrack.shouldAdvance(0, 0, 1), "an unloaded track (TimeLength 0) must not hand over")
end

-- Equal-power crossfade: full at the ends, no loudness dip in the middle.
do
	local outStart, inStart = Soundtrack.fadeGains(0)
	local outEnd, inEnd = Soundtrack.fadeGains(1)
	assert(outStart == 1 and inStart == 0, "a crossfade must start on the outgoing track")
	assert(math.abs(outEnd) < 1e-9 and math.abs(inEnd - 1) < 1e-9, "a crossfade must end on the incoming track")
	for step = 0, 20 do
		local outGain, inGain = Soundtrack.fadeGains(step / 20)
		assert(math.abs(outGain * outGain + inGain * inGain - 1) < 1e-9, "the crossfade must be equal-power")
	end
end

-- Volume follows mix and duck, and never exceeds the base level.
do
	local track = tracks[1]
	assert(Soundtrack.volume(track, 0, 1) == 0, "music volume 0 must be silent")
	assert(Soundtrack.volume(track, 1, 0.5) < Soundtrack.volume(track, 1, 1), "ducking must lower the music")
	assert(Soundtrack.volume(track, 2, 2) <= Soundtrack.BASE_VOLUME, "mix and duck must clamp")
end

-- Behavioural model: a session of several full cycles. Poll like the director
-- (every 0.25s), hand over when due, and check every track plays in turn for
-- (nearly) its whole length.
do
	local lengths = { 150, 95, 180, 120 }
	assert(#lengths >= #tracks, "model needs a length per track")
	local POLL = 0.25
	local fade = Soundtrack.CROSSFADE_SECONDS
	local current, position, clock = 1, 0, 0
	local played = { 1 }
	local playedFor: { number } = {}
	local startedAt = 0
	while #played <= #tracks * 3 and clock < 5000 do
		clock += POLL
		position += POLL
		if Soundtrack.shouldAdvance(lengths[current], position, 1) then
			table.insert(playedFor, clock - startedAt)
			-- The crossfade itself: the outgoing track plays out under it.
			clock += fade
			current = Soundtrack.nextIndex(current, {}, clock) :: number
			position = fade
			startedAt = clock - fade
			table.insert(played, current)
		end
	end
	for step, index in played do
		assert(index == ((step - 1) % #tracks) + 1, "the session must walk the playlist in order")
	end
	for step, seconds in playedFor do
		local length = lengths[((step - 1) % #tracks) + 1]
		assert(seconds >= length - fade - POLL * 2, "a track was cut short: " .. tostring(seconds) .. "s of " .. tostring(length))
	end
end

------------------------------------------------------------------------
-- 4. Per-page music settings are gone end to end
------------------------------------------------------------------------
for _, setting in { "MusicCrossfade", "PageStingers" } do
	for label, source in {
		SettingsView = settingsSource,
		MainGame = mainSource,
		audio = audioSource,
		DataTemplate = templateSource,
		DataService = dataSource,
		ServerServices = servicesSource,
	} do
		assert(not string.find(source, setting, 1, true), label .. " still references the removed setting " .. setting)
	end
end
-- The music on/off toggle stays, under its saved key, so players keep their choice.
assert(string.find(settingsSource, 'id = "PageMusic"', 1, true), "the Background music toggle must stay")
assert(string.find(servicesSource, "PageMusic = true", 1, true), "the server must still accept the music toggle")

------------------------------------------------------------------------
-- 5. Paused music resumes where it stopped
------------------------------------------------------------------------
-- Sound:Play() restarts from the last script-set TimePosition, so resuming
-- with it would send a paused track back to its start.
assert(not string.find(directorSource, ":Play()", 1, true), "the director must resume with :Resume(), never :Play()")
assert(string.find(directorSource, "activeSound:Resume()", 1, true), "the active deck must resume in place")

print(
	string.format(
		"[INFO] [TEST] soundtrack guards passed | %d tracks, %.0fs equal-power hand-over, no per-page music",
		#tracks,
		Soundtrack.CROSSFADE_SECONDS
	)
)
