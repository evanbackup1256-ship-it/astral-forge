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

local fs = require("@lune/fs")
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
local manifest = readSource("src/Shared/AstralForge/Shared/AssetManifest.luau")
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
local audio = readSource("src/Client/AstralForge/audio.luau")
local sheet = readSource("src/Client/AstralForge/soundSheet.luau")
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
assert(cueCount >= 180, "the CUES scan found too few cues -- did the pattern drift?")
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
local ambience = readSource("src/Client/AstralForge/sanctuaryAmbience.luau")
for bed in string.gmatch(ambience, '= "(amb_[%w_]+)"') do
	assert(build.ambience.regions[bed] ~= nil, "ambience bed " .. bed .. " isn't in the ambience sheet")
end
assert(string.find(ambience, "Manifest.Ambience.Id <= 0", 1, true), "ambience stays silent until uploaded")

------------------------------------------------------------------------
-- 4. Models and effects
------------------------------------------------------------------------
local consumers = {
	"src/Server/AstralForge/Services/SanctuaryBuilder.luau",
	"src/Server/AstralForge/Services/OreService.luau",
	"src/Client/AstralForge/sanctuaryWorld.luau",
}
local vfxSource = readSource("src/Shared/AstralForge/Shared/Vfx.luau")
local presets: { [string]: boolean } = {}
local presetStart = string.find(vfxSource, "local PRESETS", 1, true)
for name in string.gmatch(string.sub(vfxSource, presetStart :: number), "\n\t(%w+) = {") do
	presets[name] = true
end
local kitUses, vfxUses = 0, 0
for _, path in consumers do
	local source = readSource(path)
	for name in string.gmatch(source, 'AssetKit%.%a+%("(%w+)"') do
		assert(kitNames[name], path .. " asks the kit for " .. name .. ", which it doesn't have")
		kitUses += 1
	end
	for name in string.gmatch(source, 'bossPart%("(%w+)"') do
		assert(kitNames[name], path .. " asks the kit for " .. name .. ", which it doesn't have")
		kitUses += 1
	end
	for name in string.gmatch(source, 'shape%([%w_]+, "(%w+)"') do
		assert(kitNames[name], path .. " asks the kit for " .. name .. ", which it doesn't have")
		kitUses += 1
	end
	for name in string.gmatch(source, 'Vfx%.attach%([^,]+, "(%w+)"') do
		assert(presets[name], path .. " uses unknown VFX preset " .. name)
		vfxUses += 1
	end
	for name in string.gmatch(source, 'Vfx%.burst%([^\n]-, "(%w+)", ') do
		assert(presets[name], path .. " bursts unknown VFX preset " .. name)
		vfxUses += 1
	end
end
assert(kitUses >= 15, "the kit scan found too few uses -- did the pattern drift?")
assert(vfxUses >= 15, "the VFX scan found too few uses -- did the pattern drift?")
-- Particle textures Roblox ships inside every client (content/textures/particles).
local SHIPPED = {
	"sparkles_main.dds", "fire_main.dds", "fire_sparks_main.dds", "smoke_main.dds", "forcefield_glow_main.dds",
	"forcefield_vortex_main.dds", "explosion01_core_main.dds", "explosion01_implosion_main.dds",
	"explosion01_shockwave_main.dds", "explosion01_smoke_main.dds",
}
local shipped: { [string]: boolean } = {}
for _, name in SHIPPED do
	shipped[name] = true
end
local textures = 0
for file in string.gmatch(vfxSource, 'TEX %.%. "([%w_%.]+)"') do
	assert(shipped[file], "Vfx uses " .. file .. ", which isn't a texture Roblox ships")
	textures += 1
end
assert(textures >= 8, "the texture scan found too few textures")
assert(not string.find(vfxSource, "rbxassetid://", 1, true), "Vfx must only use built-in textures (no uploads needed)")

------------------------------------------------------------------------
-- 5. Safety
------------------------------------------------------------------------
local buildPy = readSource("tools/assetgen/build.py")
assert(not string.find(buildPy, "import upload", 1, true), "a build must never upload anything")
local kit = readSource("src/Shared/AstralForge/Shared/AssetKit.luau")
assert(string.find(kit, "Manifest.Kit.Id == 0", 1, true), "with no kit, loading returns at once")
assert(string.find(kit, "pcall(function()\n\t\t\treturn InsertService:LoadAsset", 1, true), "a failed kit load must not throw")
local builder = readSource("src/Server/AstralForge/Services/SanctuaryBuilder.luau")
assert(string.find(builder, "local mesh = AssetKit.make(kitName", 1, true) and string.find(builder, "return fallback()", 1, true), "every kit mesh has a part fallback")
assert(string.find(sheet, "return Manifest.SoundSheet.Id > 0", 1, true), "the sheet is used only once uploaded")

print(
	string.format(
		"[INFO] [TEST] asset pipeline passed | %d cues -> %d voices, %d beds, %d models, %d kit uses, %d vfx uses, %d built-in textures",
		mapped,
		#ordered,
		(function()
			local n = 0
			for _ in build.ambience.regions do
				n += 1
			end
			return n
		end)(),
		(function()
			local n = 0
			for _ in kitNames do
				n += 1
			end
			return n
		end)(),
		kitUses,
		vfxUses,
		textures
	)
)
