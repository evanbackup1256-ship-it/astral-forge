--!strict
-- Guards for the cue voicing layer.
--
-- The whole game speaks through three sound files. Every cue aliases a hover
-- blip, a click or a confirm chime, so "purchase" and "menu click" were
-- literally the same audio at slightly different pitches -- that is why the mix
-- read as flat. audioVoicing gives each cue a family, and each family a full
-- voice (EQ curve, reverb space, drive, pitch, decay) so one source file can be
-- voiced as a hammer, a coin or a rift.
--
-- What this locks in:
--   1. Every voice is physically playable: EQ gains inside Roblox's -80..10,
--      pitches inside the engine's usable range, reverb/drive in range.
--   2. Families are actually distinct. Two families that measure the same are
--      a design bug -- the player hears one sound wearing two names.
--   3. Every cue in the audio cue table resolves to a real family, and every
--      family is reachable from at least one cue (no dead voices).
--   4. Layers reference a real source role and stay quieter than the main hit.
--   5. audio.luau actually applies the voice (pitch, gain, decay, EQ, reverb).
--
-- HARD: pure data + string checks. No Roblox instances, no vendor requires.

local fs = require("./_memberfs")(require("@lune/fs"))

local Voicing = require("../src/Client/AstralForge/AudioKit")("audioVoicing")

local audioSource = fs.readFile("src/Client/AstralForge/AudioKit.luau#audio")

------------------------------------------------------------------------
-- 1. Every voice is physically playable
------------------------------------------------------------------------
local families = Voicing.families()
local familyCount = 0
for name, voice in families do
	familyCount += 1
	for label, gain in { high = voice.high, mid = voice.mid, low = voice.low } do
		assert(
			gain >= -80 and gain <= 10,
			string.format("%s.%s = %g is outside EqualizerSoundEffect's -80..10", name, label, gain)
		)
	end
	-- audio.luau clamps playback speed to 0.28..2.1; a family pitch outside that
	-- is silently flattened back toward the source file it came from.
	assert(
		voice.pitch >= 0.28 and voice.pitch <= 2.1,
		string.format("%s.pitch = %g would be clamped away", name, voice.pitch)
	)
	assert(voice.reverbWet >= 0 and voice.reverbWet <= 1, name .. ".reverbWet out of 0..1")
	assert(voice.reverbDecay >= 0 and voice.reverbDecay <= 20, name .. ".reverbDecay out of range")
	assert(voice.drive >= 0 and voice.drive <= 1, name .. ".drive out of 0..1")
	assert(voice.decay > 0 and voice.decay <= 4, name .. ".decay out of range")
	assert(voice.gain > 0 and voice.gain <= 2, name .. ".gain out of range")
end
assert(familyCount >= 10, "expected a full family set, got " .. tostring(familyCount))
-- Keep the cleaner mix from drifting back to bright, distorted, long-tailed UI.
for name, voice in families do
	assert(voice.high <= 6, name .. " has excessive high-frequency boost")
	assert(voice.drive <= 0.07, name .. " has excessive distortion")
	assert(voice.reverbWet <= 0.17, name .. " has excessive reverb")
	assert(voice.decay <= 1.6, name .. " has an excessive release tail")
end
assert(string.find(audioSource, "paintCue(channel, cue, true)", 1, true), "sheet playback must apply its clean authored mix")

------------------------------------------------------------------------
-- 2. Families must be audibly distinct
--
-- Distance over the axes a listener actually resolves. The per-axis scaling
-- converts pitch/reverb/drive (0..1-ish) into the same rough units as the dB
-- gains, so no single axis dominates the metric.
------------------------------------------------------------------------
local function separation(a, b: typeof(({} :: any) :: any)): number
	local dh = a.high - b.high
	local dm = a.mid - b.mid
	local dl = a.low - b.low
	local dp = (a.pitch - b.pitch) * 40
	local dr = (a.reverbWet - b.reverbWet) * 40
	local dd = (a.drive - b.drive) * 30
	return math.sqrt(dh * dh + dm * dm + dl * dl + dp * dp + dr * dr + dd * dd)
end

local names: { string } = {}
for name in families do
	table.insert(names, name)
end
table.sort(names)

-- 8 is about the point where two voices stop being tellable apart on the same
-- source file. Neighbours are allowed to be close on purpose (social sits next
-- to interface by design), so this is a floor, not a target.
local MIN_SEPARATION = 8
local worst, worstA, worstB = math.huge, "", ""
for i = 1, #names do
	for j = i + 1, #names do
		local distance = separation(families[names[i]], families[names[j]])
		if distance < worst then
			worst, worstA, worstB = distance, names[i], names[j]
		end
	end
end
assert(
	worst >= MIN_SEPARATION,
	string.format(
		"families '%s' and '%s' are only %.1f apart -- one sound wearing two names",
		worstA,
		worstB,
		worst
	)
)

------------------------------------------------------------------------
-- 3. Cue coverage: every cue resolves, every family is used
------------------------------------------------------------------------
local cueBlock = string.match(audioSource, "local CUES = {(.-)\nlocal UI_CUES")
assert(cueBlock ~= nil, "could not isolate the CUES table from audio.luau")

local cueNames: { string } = {}
for key in string.gmatch(cueBlock :: string, "\n\t([%a][%w]*) = {") do
	table.insert(cueNames, key)
end
assert(#cueNames > 150, "expected the full cue table, got " .. tostring(#cueNames))

local usedFamilies: { [string]: boolean } = {}
for _, cue in cueNames do
	local family = Voicing.familyOf(cue)
	assert(families[family] ~= nil, "cue '" .. cue .. "' maps to unknown family '" .. family .. "'")
	usedFamilies[family] = true
	-- voiceFor must never return nil, whatever the cue.
	assert(Voicing.voiceFor(cue) ~= nil, "no voice for cue " .. cue)
end
-- An unreachable family is dead tuning that will drift out of sync silently.
for _, name in names do
	assert(usedFamilies[name], "family '" .. name .. "' is not used by any cue")
end
-- An unknown cue must still get a usable voice rather than erroring.
assert(Voicing.voiceFor("this_cue_does_not_exist") ~= nil, "unknown cues need a fallback voice")
assert(Voicing.familyOf("this_cue_does_not_exist") == "interface", "fallback should be neutral")

-- Spot-check the fiction: the cues that define each family's identity must
-- actually land in it, or a later edit could quietly re-file them.
local EXPECTED: { [string]: string } = {
	hover = "chrome",
	click = "interface",
	purchase = "currency",
	reward = "reward",
	domainImpact = "arcane",
	salvageCrunch = "forge",
	error = "denial",
	chatReceive = "social",
	reactorPulse = "reactor",
	bootFinaleBang = "ceremony",
	wheelTick = "chrome",
	page = "motion",
}
for cue, family in EXPECTED do
	assert(
		Voicing.familyOf(cue) == family,
		string.format("cue '%s' should be voiced as '%s', got '%s'", cue, family, Voicing.familyOf(cue))
	)
end

------------------------------------------------------------------------
-- 4. Layers
------------------------------------------------------------------------
local VALID_SOURCES = { hover = true, click = true, confirm = true }
local layerCount = 0
for cue, layer in Voicing.layers() do
	layerCount += 1
	assert(VALID_SOURCES[layer.source], "layer on '" .. cue .. "' names unknown source " .. layer.source)
	-- A layer is a garnish. Louder than the main hit and it becomes an echo.
	assert(layer.volume > 0 and layer.volume < 0.75, "layer on '" .. cue .. "' is too loud to blend")
	-- Beyond ~80ms the ear separates it into a second sound.
	assert(layer.delay >= 0 and layer.delay <= 0.08, "layer on '" .. cue .. "' would read as an echo")
	assert(layer.pitch >= 0.28 and layer.pitch <= 2.1, "layer on '" .. cue .. "' pitch would be clamped")
	-- Layered cues must be real cues.
	local known = false
	for _, name in cueNames do
		if name == cue then
			known = true
			break
		end
	end
	assert(known, "layer targets unknown cue '" .. cue .. "'")
end
assert(layerCount > 0, "expected some layered cues")

------------------------------------------------------------------------
-- 5. audio.luau actually applies the voicing
------------------------------------------------------------------------
assert(
	string.find(audioSource, "local Voicing = __load(\"audioVoicing\")", 1, true),
	"audio.luau must require the voicing table"
)
-- Pitch, gain and decay all have to reach the Sound, or the families are inert.
assert(string.find(audioSource, "voice.pitch", 1, true), "family pitch must reach PlaybackSpeed")
assert(string.find(audioSource, "voice.gain", 1, true), "family gain must reach Volume")
assert(string.find(audioSource, "familyDecay", 1, true), "family decay must shape the release")
-- The EQ/reverb/drive painting.
assert(string.find(audioSource, "ReverbSoundEffect", 1, true), "reverb is what places a cue in a space")
assert(string.find(audioSource, "DistortionSoundEffect", 1, true), "drive is what gives metal its grain")
assert(string.find(audioSource, "Voicing.clampGain", 1, true), "EQ gains must be clamped to Roblox's range")
-- The old flat per-cue EQ ladder must be gone, or two systems fight over tone.
assert(not string.find(audioSource, "local function cueTone", 1, true), "the old cueTone ladder should be gone")
-- Volume must agree in all three places it is computed, or the release fade and
-- the volume slider jump relative to the initial hit.
local gainSites = 0
for _ in string.gmatch(audioSource, "Voicing%.voiceFor%([%w_.]+%)%.gain") do
	gainSites += 1
end
assert(gainSites >= 2, "family gain must also be applied on release fade and volume changes")
-- The clamp has to admit the deep families, or arcane/ceremony flatten out.
assert(
	string.find(audioSource, "0.28, 2.1", 1, true),
	"playback clamp must span the deep families' pitch range"
)

print(
	string.format(
		"[INFO] [TEST] audio voicing guards passed | %d families over %d cues, %d layered, closest pair %s/%s at %.1f",
		familyCount,
		#cueNames,
		layerCount,
		worstA,
		worstB,
		worst
	)
)
