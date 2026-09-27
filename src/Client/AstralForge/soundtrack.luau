--!strict
-- The game's soundtrack.
--
-- Astral Forge used to score every page separately: 30 views mapped onto 15
-- "beds", and changing page crossfaded the music. There are only four real
-- music files, so those beds were the same few tracks re-EQ'd and re-pitched,
-- and moving around the menus kept restarting and recolouring the music.
--
-- Now there is one soundtrack for the whole game. It plays its tracks in order,
-- each start to finish, and carries on whatever page is open; a track hands
-- over to the next with a long crossfade only when it reaches its end.
--
-- Pure data + math: no Roblox instances, so the sequencing is unit tested under
-- Lune (scripts/verify_soundtrack.luau). musicDirector.luau owns the Sounds.

export type Track = {
	name: string,
	asset: string,
	-- Loudness trim so every track sits at the same level.
	gain: number,
	-- Gentle mastering EQ in dB (EqualizerSoundEffect accepts -80..10). These
	-- only even the tracks out against each other; they do not recolour them.
	low: number,
	mid: number,
	high: number,
}

-- Played in this order, then round again. Atrium is the main theme, so it is
-- what the game opens on.
local TRACKS: { Track } = {
	{ name = "Atrium", asset = "rbxassetid://9038252619", gain = 0.84, low = 1.5, mid = 1, high = -1 },
	{ name = "Foundry", asset = "rbxassetid://5410086218", gain = 0.8, low = 2, mid = 0, high = -2 },
	{ name = "Orbit", asset = "rbxassetid://9046476113", gain = 0.78, low = 0, mid = 1.5, high = 0.5 },
	{ name = "Core", asset = "rbxassetid://9120386436", gain = 0.72, low = -1.5, mid = -0.5, high = 1.5 },
}

local Soundtrack = {}

-- Seconds two tracks overlap at a hand-over. Long, because this is a change of
-- song, not a UI transition.
Soundtrack.CROSSFADE_SECONDS = 4
-- Level of the music Sounds before track gain, music volume and ducking.
Soundtrack.BASE_VOLUME = 0.16
-- A track whose asset fails to load is skipped for this long, then retried.
Soundtrack.RETRY_SECONDS = 120

function Soundtrack.tracks(): { Track }
	return TRACKS
end

function Soundtrack.count(): number
	return #TRACKS
end

-- 1-based and wrapping, so callers can step past the end freely.
function Soundtrack.track(index: number): Track
	return TRACKS[((index - 1) % #TRACKS) + 1]
end

-- The track to play after `current`, skipping any that failed to load within
-- the last RETRY_SECONDS. Nil when nothing else is playable, in which case the
-- current track simply keeps looping.
function Soundtrack.nextIndex(current: number, failedAt: { [number]: number }, now: number): number?
	local count = #TRACKS
	for step = 1, count - 1 do
		local candidate = ((current - 1 + step) % count) + 1
		local failed = failedAt[candidate]
		if failed == nil or now - failed >= Soundtrack.RETRY_SECONDS then
			return candidate
		end
	end
	return nil
end

-- True once the playing track is within one crossfade of its end, in real
-- seconds (PlaybackSpeed stretches or shrinks the time that is left). A track
-- too short to hold a whole crossfade is left to loop.
function Soundtrack.shouldAdvance(timeLength: number, timePosition: number, playbackSpeed: number): boolean
	if timeLength <= Soundtrack.CROSSFADE_SECONDS * 2 then
		return false
	end
	local remaining = (timeLength - timePosition) / math.max(0.05, playbackSpeed)
	return remaining <= Soundtrack.CROSSFADE_SECONDS
end

-- Equal-power crossfade gains (outgoing, incoming), so the hand-over does not
-- dip in loudness halfway through.
function Soundtrack.fadeGains(alpha: number): (number, number)
	local t = math.clamp(alpha, 0, 1)
	return math.cos(t * math.pi * 0.5), math.sin(t * math.pi * 0.5)
end

-- Sound.Volume for a track at the given music mix and duck.
function Soundtrack.volume(track: Track, mix: number, duck: number): number
	return Soundtrack.BASE_VOLUME * track.gain * math.clamp(mix, 0, 1) * math.clamp(duck, 0, 1)
end

-- Every asset the soundtrack plays, for the preloader.
function Soundtrack.manifest(): { string }
	local assets = {}
	for _, track in TRACKS do
		table.insert(assets, track.asset)
	end
	return assets
end

return Soundtrack
