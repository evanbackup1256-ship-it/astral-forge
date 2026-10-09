--!strict
-- Purpose: elemental spritesheets (tools/spritegen/build_elements.py) and how to play them with
-- Vendor/Sprite. Every sheet is 6 x 6 frames of 170 px, looping seamlessly over 36 frames.
-- Owner: presentation. Dependencies: none. Review: 2026-10-08.

export type Element =
	"Fire"
	| "Magma"
	| "Solar"
	| "Lightning"
	| "Plasma"
	| "Sonic"
	| "Ice"
	| "Blizzard"
	| "Water"
	| "Steam"
	| "Wind"
	| "Sand"
	| "Earth"
	| "Nature"
	| "Poison"
	| "Blood"
	| "Void"
	| "Shadow"
	| "Spirit"
	| "Arcane"
	| "Radiance"
	| "Prism"
	| "Cosmic"
	| "Chrono"
	| "Crystal"
	| "Steel"
	| "Gold"
	| "Amber"
	| "Magnet"
	| "Gravity"
	| "Nebula"
	| "Aurora"
	| "Lunar"
	| "Comet"
	| "Eclipse"
	| "Starlight"
	| "Celestial"
	| "Tempest"
	| "Rift"
	| "Quantum"
	| "Aether"
	| "Glitch"
	| "Vital"
	| "Neon"
	| "Hologram"
	| "Thorn"
	| "Spore"
	| "Bloom"
	| "Dream"
	| "Feather"
	| "Abyss"
	| "Smoke"
	| "Necrotic"
	| "Rune"
	| "Mirror"
	| "Ink"
	| "Frostfire"
export type Sheet = { Image: string, Color: Color3, Glow: Color3, Label: string }

local SHEETS: { [string]: Sheet } = {
	Fire = { Image = "rbxassetid://75483558840366", Color = Color3.fromRGB(255, 132, 46), Glow = Color3.fromRGB(255, 196, 96), Label = "FIRE" },
	Magma = { Image = "rbxassetid://88245666774645", Color = Color3.fromRGB(255, 96, 24), Glow = Color3.fromRGB(255, 190, 90), Label = "MAGMA" },
	Solar = { Image = "rbxassetid://114835185216477", Color = Color3.fromRGB(255, 170, 40), Glow = Color3.fromRGB(255, 226, 140), Label = "SOLAR" },
	Lightning = { Image = "rbxassetid://72260739853681", Color = Color3.fromRGB(120, 168, 255), Glow = Color3.fromRGB(214, 232, 255), Label = "STORM" },
	Plasma = { Image = "rbxassetid://84876984885182", Color = Color3.fromRGB(255, 110, 230), Glow = Color3.fromRGB(255, 210, 250), Label = "PLASMA" },
	Sonic = { Image = "rbxassetid://97287179133685", Color = Color3.fromRGB(90, 240, 200), Glow = Color3.fromRGB(200, 255, 238), Label = "SONIC" },
	Ice = { Image = "rbxassetid://102817518005842", Color = Color3.fromRGB(128, 214, 255), Glow = Color3.fromRGB(226, 248, 255), Label = "FROST" },
	Blizzard = { Image = "rbxassetid://124049936437821", Color = Color3.fromRGB(170, 215, 255), Glow = Color3.fromRGB(235, 248, 255), Label = "BLIZZARD" },
	Water = { Image = "rbxassetid://106801487878343", Color = Color3.fromRGB(56, 150, 255), Glow = Color3.fromRGB(170, 225, 255), Label = "TIDE" },
	Steam = { Image = "rbxassetid://108697596791496", Color = Color3.fromRGB(200, 214, 228), Glow = Color3.fromRGB(240, 246, 255), Label = "STEAM" },
	Wind = { Image = "rbxassetid://85357421786831", Color = Color3.fromRGB(170, 240, 220), Glow = Color3.fromRGB(230, 255, 248), Label = "GALE" },
	Sand = { Image = "rbxassetid://95063100132524", Color = Color3.fromRGB(226, 190, 120), Glow = Color3.fromRGB(255, 230, 170), Label = "SAND" },
	Earth = { Image = "rbxassetid://103188275524922", Color = Color3.fromRGB(206, 150, 82), Glow = Color3.fromRGB(255, 214, 140), Label = "EARTH" },
	Nature = { Image = "rbxassetid://117124220242677", Color = Color3.fromRGB(96, 210, 96), Glow = Color3.fromRGB(220, 255, 150), Label = "VERDANT" },
	Poison = { Image = "rbxassetid://83632321910323", Color = Color3.fromRGB(128, 228, 74), Glow = Color3.fromRGB(214, 255, 160), Label = "VENOM" },
	Blood = { Image = "rbxassetid://95330566970635", Color = Color3.fromRGB(220, 36, 52), Glow = Color3.fromRGB(255, 140, 140), Label = "BLOOD" },
	Void = { Image = "rbxassetid://83618150855370", Color = Color3.fromRGB(176, 92, 255), Glow = Color3.fromRGB(240, 190, 255), Label = "VOID" },
	Shadow = { Image = "rbxassetid://130327983556875", Color = Color3.fromRGB(150, 80, 230), Glow = Color3.fromRGB(220, 150, 255), Label = "SHADE" },
	Spirit = { Image = "rbxassetid://121879440121165", Color = Color3.fromRGB(120, 175, 255), Glow = Color3.fromRGB(215, 235, 255), Label = "SPIRIT" },
	Arcane = { Image = "rbxassetid://110558103034252", Color = Color3.fromRGB(110, 225, 255), Glow = Color3.fromRGB(255, 150, 240), Label = "ARCANE" },
	Radiance = { Image = "rbxassetid://96906517979827", Color = Color3.fromRGB(255, 214, 110), Glow = Color3.fromRGB(255, 244, 200), Label = "HOLY" },
	Prism = { Image = "rbxassetid://74092226431191", Color = Color3.fromRGB(190, 200, 255), Glow = Color3.fromRGB(255, 255, 255), Label = "PRISM" },
	Cosmic = { Image = "rbxassetid://77205186818949", Color = Color3.fromRGB(150, 130, 245), Glow = Color3.fromRGB(240, 220, 170), Label = "COSMIC" },
	Chrono = { Image = "rbxassetid://95809344559793", Color = Color3.fromRGB(240, 200, 110), Glow = Color3.fromRGB(170, 240, 255), Label = "CHRONO" },
	-- second wave (tools/spritegen/build_elements_ext.py): matter, sky, energy, life, mind
	Crystal = { Image = "rbxassetid://96046133054718", Color = Color3.fromRGB(176, 120, 255), Glow = Color3.fromRGB(236, 214, 255), Label = "CRYSTAL" },
	Steel = { Image = "rbxassetid://80302358090554", Color = Color3.fromRGB(170, 186, 204), Glow = Color3.fromRGB(236, 242, 250), Label = "STEEL" },
	Gold = { Image = "rbxassetid://112679140367505", Color = Color3.fromRGB(255, 196, 60), Glow = Color3.fromRGB(255, 236, 160), Label = "GILDED" },
	Amber = { Image = "rbxassetid://107462893282824", Color = Color3.fromRGB(240, 150, 40), Glow = Color3.fromRGB(255, 214, 130), Label = "AMBER" },
	Magnet = { Image = "rbxassetid://133296105133123", Color = Color3.fromRGB(230, 70, 90), Glow = Color3.fromRGB(130, 180, 255), Label = "MAGNET" },
	Gravity = { Image = "rbxassetid://128725210922561", Color = Color3.fromRGB(120, 90, 220), Glow = Color3.fromRGB(210, 190, 255), Label = "GRAVITY" },
	Nebula = { Image = "rbxassetid://94261579757705", Color = Color3.fromRGB(230, 110, 190), Glow = Color3.fromRGB(130, 230, 230), Label = "NEBULA" },
	Aurora = { Image = "rbxassetid://75791662096656", Color = Color3.fromRGB(90, 240, 170), Glow = Color3.fromRGB(200, 160, 255), Label = "AURORA" },
	Lunar = { Image = "rbxassetid://98034470919188", Color = Color3.fromRGB(196, 210, 240), Glow = Color3.fromRGB(245, 248, 255), Label = "LUNAR" },
	Comet = { Image = "rbxassetid://112192365618672", Color = Color3.fromRGB(120, 200, 255), Glow = Color3.fromRGB(240, 250, 255), Label = "COMET" },
	Eclipse = { Image = "rbxassetid://95799988924548", Color = Color3.fromRGB(250, 236, 210), Glow = Color3.fromRGB(255, 255, 255), Label = "ECLIPSE" },
	Starlight = { Image = "rbxassetid://102171518978963", Color = Color3.fromRGB(255, 236, 160), Glow = Color3.fromRGB(255, 252, 230), Label = "STARLIGHT" },
	Celestial = { Image = "rbxassetid://118140528196719", Color = Color3.fromRGB(110, 160, 255), Glow = Color3.fromRGB(255, 226, 150), Label = "CELESTIAL" },
	Tempest = { Image = "rbxassetid://91888201918230", Color = Color3.fromRGB(90, 140, 200), Glow = Color3.fromRGB(200, 230, 255), Label = "TEMPEST" },
	Rift = { Image = "rbxassetid://79762590606315", Color = Color3.fromRGB(220, 60, 255), Glow = Color3.fromRGB(120, 240, 255), Label = "RIFT" },
	Quantum = { Image = "rbxassetid://82118083981634", Color = Color3.fromRGB(80, 220, 255), Glow = Color3.fromRGB(220, 250, 255), Label = "QUANTUM" },
	Aether = { Image = "rbxassetid://100248414305255", Color = Color3.fromRGB(200, 230, 255), Glow = Color3.fromRGB(255, 250, 220), Label = "AETHER" },
	Glitch = { Image = "rbxassetid://95716429378917", Color = Color3.fromRGB(120, 255, 200), Glow = Color3.fromRGB(255, 90, 170), Label = "GLITCH" },
	Vital = { Image = "rbxassetid://74946674129075", Color = Color3.fromRGB(255, 80, 120), Glow = Color3.fromRGB(255, 200, 210), Label = "VITAL" },
	Neon = { Image = "rbxassetid://72421452945346", Color = Color3.fromRGB(255, 60, 200), Glow = Color3.fromRGB(90, 250, 255), Label = "NEON" },
	Hologram = { Image = "rbxassetid://113693014358710", Color = Color3.fromRGB(90, 230, 255), Glow = Color3.fromRGB(200, 250, 255), Label = "HOLO" },
	Thorn = { Image = "rbxassetid://97372328991663", Color = Color3.fromRGB(90, 200, 80), Glow = Color3.fromRGB(230, 60, 90), Label = "THORN" },
	Spore = { Image = "rbxassetid://107532560849415", Color = Color3.fromRGB(200, 230, 110), Glow = Color3.fromRGB(250, 255, 200), Label = "SPORE" },
	Bloom = { Image = "rbxassetid://78703571821368", Color = Color3.fromRGB(255, 150, 200), Glow = Color3.fromRGB(255, 230, 240), Label = "BLOOM" },
	Dream = { Image = "rbxassetid://84649860615969", Color = Color3.fromRGB(190, 140, 255), Glow = Color3.fromRGB(150, 240, 240), Label = "DREAM" },
	Feather = { Image = "rbxassetid://75081027527443", Color = Color3.fromRGB(240, 230, 210), Glow = Color3.fromRGB(255, 250, 240), Label = "PLUME" },
	Abyss = { Image = "rbxassetid://137601033400779", Color = Color3.fromRGB(40, 90, 170), Glow = Color3.fromRGB(110, 220, 230), Label = "ABYSS" },
	Smoke = { Image = "rbxassetid://89981065319910", Color = Color3.fromRGB(150, 150, 160), Glow = Color3.fromRGB(220, 220, 228), Label = "SMOKE" },
	Necrotic = { Image = "rbxassetid://74633842822192", Color = Color3.fromRGB(130, 230, 90), Glow = Color3.fromRGB(200, 255, 170), Label = "NECRO" },
	Rune = { Image = "rbxassetid://104937327116876", Color = Color3.fromRGB(255, 170, 60), Glow = Color3.fromRGB(255, 226, 160), Label = "RUNE" },
	Mirror = { Image = "rbxassetid://117676430093332", Color = Color3.fromRGB(210, 225, 240), Glow = Color3.fromRGB(255, 255, 255), Label = "MIRROR" },
	Ink = { Image = "rbxassetid://110744726408388", Color = Color3.fromRGB(70, 80, 120), Glow = Color3.fromRGB(170, 180, 230), Label = "INK" },
	Frostfire = { Image = "rbxassetid://107920326762785", Color = Color3.fromRGB(80, 190, 255), Glow = Color3.fromRGB(255, 150, 70), Label = "FROSTFIRE" },
}

local ElementSprites = {
	FRAME = 170,
	COLUMNS = 6,
	COUNT = 36,
	FRAMERATE = 24,
	-- grouped by family: heat, energy, cold, air and ground, life and decay, the beyond, then the
	-- second wave (matter, sky, energy, life, mind)
	ORDER = table.freeze({
		"Fire", "Magma", "Solar", "Lightning", "Plasma", "Sonic", "Ice", "Blizzard", "Water", "Steam", "Wind", "Sand",
		"Earth", "Nature", "Poison", "Blood", "Void", "Shadow", "Spirit", "Arcane", "Radiance", "Prism", "Cosmic", "Chrono",
		"Crystal", "Steel", "Gold", "Amber", "Magnet", "Gravity", "Nebula", "Aurora", "Lunar", "Comet", "Eclipse",
		"Starlight", "Celestial", "Tempest", "Rift", "Quantum", "Aether", "Glitch", "Vital", "Neon", "Hologram", "Thorn",
		"Spore", "Bloom", "Dream", "Feather", "Abyss", "Smoke", "Necrotic", "Rune", "Mirror", "Ink", "Frostfire",
	}),
}

function ElementSprites.sheet(element: string?): Sheet?
	return if element then SHEETS[element] else nil
end

-- the Sprite library's ArrayConfig for one element
function ElementSprites.animation(element: string, framerate: number?): any?
	local sheet = SHEETS[element]
	if sheet == nil then
		return nil
	end
	return {
		Spritesheet = sheet.Image,
		SpriteSize = Vector2.new(ElementSprites.FRAME, ElementSprites.FRAME),
		Columns = ElementSprites.COLUMNS,
		SpriteCount = ElementSprites.COUNT,
		Framerate = framerate or ElementSprites.FRAMERATE,
		Looped = true,
		DebugId = element,
	}
end

return table.freeze(ElementSprites)
