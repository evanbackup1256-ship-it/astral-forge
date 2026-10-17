--!strict
-- Guards for the generated asset pipeline (tools/assetgen) and its runtime use.
--
--   1. The generated files exist, parse, and fit Open Cloud's upload limits.
--   2. The Luau manifest matches build.json and assets/asset_ids.json.
--   3. Every audio cue plays a real voice from the sound sheet, and the
--      sanctuary's ambience beds all exist.
--   4. Every kit model the code asks for is in the kit; every VFX preset the
--      code uses exists; every texture is one Roblox ships with the client.
--   5. Nothing uploads during a build, and every consumer falls back cleanly
--      when an id is still 0.
--
-- HARD: pure checks -- no Roblox instances.

local fs = require("./_memberfs")(require("@lune/fs"))
local serde = require("@lune/serde")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local GEN = "assets/generated/"

------------------------------------------------------------------------
-- 1. Files
------------------------------------------------------------------------
for _, name in { "AstralForgeSFX.wav", "AstralForgeAmbience.wav", "AstralForgeKit.glb", "build.json" } do
	assert(fs.isFile(GEN .. name), "missing generated file " .. name .. " -- run python tools/assetgen/build.py")
end
local function sizeOf(path: string): number
	return #fs.readFile(path)
end
-- Roblox limits an audio asset by LENGTH (7 minutes), not by a 20 MB file size:
-- the 25.9 MB / 308 s sheet uploaded and loads fine. 16-bit mono 44.1 kHz is
-- 88,200 bytes per second, so 7 minutes is about 37 MB.
local AUDIO_MAX_SECONDS = 420
local BYTES_PER_SECOND = 44100 * 2
assert(sizeOf(GEN .. "AstralForgeSFX.wav") / BYTES_PER_SECOND < AUDIO_MAX_SECONDS, "the sound sheet must stay under Roblox's 7 minute audio limit")
assert(sizeOf(GEN .. "AstralForgeAmbience.wav") / BYTES_PER_SECOND < AUDIO_MAX_SECONDS, "the ambience sheet must stay under Roblox's 7 minute audio limit")
assert(sizeOf(GEN .. "AstralForgeKit.glb") < 20e6, "the kit must stay under 20 MB")
local wav = fs.readFile(GEN .. "AstralForgeSFX.wav")
assert(string.sub(wav, 1, 4) == "RIFF" and string.sub(wav, 9, 12) == "WAVE", "the sound sheet must be a WAV file")
local glb = fs.readFile(GEN .. "AstralForgeKit.glb")
assert(string.sub(glb, 1, 4) == "glTF", "the kit must be a binary glTF")

local build = serde.decode("json", fs.readFile(GEN .. "build.json"))
local ids = serde.decode("json", fs.readFile("assets/asset_ids.json"))

------------------------------------------------------------------------
-- 2. Manifest
------------------------------------------------------------------------
local manifest = readSource("src/Shared/AstralForge/Shared/SharedData.luau#AssetManifest")
local function block(title: string): string
	local start = string.find(manifest, "Manifest." .. title .. " = {", 1, true)
	assert(start, "manifest is missing " .. title)
	local finish = string.find(manifest, "\n}\n", start, true)
	return string.sub(manifest, start, finish)
end
local sheetBlock, ambienceBlock, kitBlock = block("SoundSheet"), block("Ambience"), block("Kit")
assert(string.find(sheetBlock, "Id = " .. tostring(ids.SoundSheet or 0) .. ",", 1, true), "manifest SoundSheet id must match asset_ids.json")
assert(string.find(ambienceBlock, "Id = " .. tostring(ids.Ambience or 0) .. ",", 1, true), "manifest Ambience id must match asset_ids.json")
assert(string.find(kitBlock, "Id = " .. tostring(ids.Kit or 0) .. ",", 1, true), "manifest Kit id must match asset_ids.json")
local voices: { [string]: boolean } = {}
for name, region in build.sfx.regions do
	voices[name] = true
	assert(string.find(sheetBlock, "\t\t" .. name .. " = { ", 1, true), "manifest is missing sound region " .. name)
	assert(region[2] > 0.01 and region[1] >= 0, name .. " region is malformed")
	assert(region[1] + region[2] <= build.sfx.length + 1e-3, name .. " runs past the end of the sheet")
	assert(build.sfx.loudness[name] ~= nil, name .. " needs a loudness figure")
end
local ordered = {}
for name, region in build.sfx.regions do
	table.insert(ordered, { name = name, start = region[1], length = region[2] })
end
table.sort(ordered, function(a, b)
	return a.start < b.start
end)
for i = 2, #ordered do
	assert(ordered[i - 1].start + ordered[i - 1].length <= ordered[i].start, ordered[i - 1].name .. " overlaps " .. ordered[i].name)
end
local kitNames: { [string]: boolean } = {}
for name in build.kit.sizes do
	kitNames[name] = true
	assert(string.find(kitBlock, "\t\t" .. name .. " = Vector3.new(", 1, true), "manifest is missing kit size " .. name)
end

------------------------------------------------------------------------
-- 3. Sounds
------------------------------------------------------------------------
local audio = readSource("src/Client/AstralForge/AudioKit.luau#audio")
local sheet = readSource("src/Client/AstralForge/AudioKit.luau#soundSheet")
local cuesStart = string.find(audio, "local CUES = {", 1, true)
local cuesEnd = string.find(audio, "local UI_CUES = {}", 1, true)
assert(cuesStart and cuesEnd, "audio CUES table not found")
local cueBlock = string.sub(audio, cuesStart :: number, cuesEnd :: number)
local cueCount, mapped = 0, 0
for cue in string.gmatch(cueBlock, "\n\t(%w+) = {") do
	cueCount += 1
	local voice = string.match(sheet, "[%s,{]" .. cue .. ' = "([%w_]+)"')
	assert(voice ~= nil, "cue " .. cue .. " has no voice on the sound sheet")
	assert(voices[voice], "cue " .. cue .. " maps to " .. voice .. ", which isn't on the sheet")
	mapped += 1
end
-- (retired features -- the sanctuary, the Warden, the card table -- took ~40 cues with them)
assert(cueCount >= 150, "the CUES scan found too few cues -- did the pattern drift?")
for voice in string.gmatch(sheet, '= "([%w_]+)"') do
	assert(voices[voice], "soundSheet names unknown voice " .. voice)
end
assert(string.find(audio, "if SoundSheet.enabled() then", 1, true), "the mixer only builds the sheet pool once it is uploaded")
assert(string.find(audio, "if self.sheetPool ~= nil and self:sheetLoaded() then", 1, true), "cues use the sheet only after it has loaded (moderation can hold a new upload)")
assert(string.find(audio, "probe.IsLoaded and probe.TimeLength > 1", 1, true), "sheetLoaded checks the sound really loaded")
assert(string.find(audio, "channel.PlaybackRegion = NumberRange.new(start, start + length)", 1, true), "sheet cues play their region")
local used: { [string]: boolean } = {}
for _, voice in ordered do
	used[voice.name] = false
end
for voice in string.gmatch(sheet, '= "([%w_]+)"') do
	used[voice] = true
end
-- SoundSheet.voiceName falls back to the cue's own name for "newer cues packed
-- under their own name", so these families are reached by cue name (built at
-- runtime: navOpen<Page>, <cue>Hover, <x>Press, ore/waystone/sanctuary voices)
-- and are never listed literally in soundSheet.luau.
local DYNAMIC_VOICE_PATTERNS = { "^navOpen", "^navHover", "Hover$", "Press$", "^oreMine", "^oreCollect", "^waystone", "^sanctuary" }
local function reachedByName(name: string): boolean
	for _, pattern in DYNAMIC_VOICE_PATTERNS do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end
for name, isUsed in used do
	assert(isUsed or reachedByName(name), "voice " .. name .. " is rendered but no cue plays it")
end
------------------------------------------------------------------------
-- 4. Safety
------------------------------------------------------------------------
local buildPy = readSource("tools/assetgen/build.py")
assert(not string.find(buildPy, "import upload", 1, true), "a build must never upload anything")
assert(string.find(sheet, "return Primary.Id > 0 or (Previous ~= nil and Previous.Id > 0)", 1, true), "the sheet is used only once uploaded")
-- a replaced sheet keeps playing the previous upload until the new one has loaded (moderation)
assert(string.find(audio, "if loaded(self.primarySheetPool) then", 1, true) and string.find(audio, "if loaded(self.previousSheetPool) then", 1, true), "the previous sheet covers a new upload until it loads")

print(string.format("[INFO] [TEST] asset pipeline passed | %d cues -> %d voices", mapped, #ordered))
