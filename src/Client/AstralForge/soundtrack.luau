--!strict
-- The game's soundtrack.
--
-- One playlist for the whole game (pages never pick music). Tracks play in
-- order start-to-finish with a long equal-power crossfade at each hand-over.
--
-- Beds are themed as a dark-cyber forge cycle:
--   ForgePulse      — idle foundry pulse (tense synth meters)
--   SanctuaryDrift  — voidglass tension under the walkable world
--   AstralOrbit     — cooler astral drift between peaks
--   BossSurge       — frenetic intensity for the Warden / spectacle peaks
--
-- Pure data + math: no Roblox instances. Sequenced by musicDirector.luau;
-- unit-tested under Lune (scripts/verify_soundtrack.luau).

export type Track = {
	name: string,
	asset: string,
	-- Loudness trim so every track sits at the same level.
	gain: number,
	-- Gentle mastering EQ in dB (equalizerSoundEffect accepts -80..10). These
	-- only even the tracks out against each other; they do not recolour them.
	low: number,
	mid: number,
	high: number,
}

-- Original beds rendered by tools/assetgen/soundtrack_gen.py and uploaded
-- with tools/assetgen/upload_soundtrack.py. New audio stays silent until
-- Roblox moderation clears it; musicDirector skips a track that fails to load.
local TRACKS: { Track } = {
	{ name = "ForgePulse", asset = "rbxassetid://79059492969495", gain = 0.82, low = 2, mid = 0.5, high = -1.5 },
	{ name = "SanctuaryDrift", asset = "rbxassetid://130740395926509", gain = 0.74, low = 0, mid = 0.8, high = 0.8 },
	{ name = "AstralOrbit", asset = "rbxassetid://137908904057491", gain = 0.78, low = 0, mid = 1, high = 1 },
	{ name = "BossSurge", asset = "rbxassetid://109017004194379", gain = 0.72, low = 1.5, mid = 0, high = -2 },
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
