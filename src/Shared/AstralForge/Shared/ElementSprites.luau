--!strict
-- Purpose: the 57 elemental companions (tools/spritegen/companions), each an original character with its
-- elemental light lit into its own frames, played with Vendor/Sprite. Every 4096-square sheet contains
-- 6 x 6 native frames of 682 px, looping seamlessly over 36 frames.
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
	Fire = { Image = "rbxassetid://103559340980670", Color = Color3.fromRGB(255, 132, 46), Glow = Color3.fromRGB(255, 196, 96), Label = "FIRE" },
	Magma = { Image = "rbxassetid://136228071865089", Color = Color3.fromRGB(255, 96, 24), Glow = Color3.fromRGB(255, 190, 90), Label = "MAGMA" },
	Solar = { Image = "rbxassetid://105208076927012", Color = Color3.fromRGB(255, 170, 40), Glow = Color3.fromRGB(255, 226, 140), Label = "SOLAR" },
	Lightning = { Image = "rbxassetid://88421973804283", Color = Color3.fromRGB(120, 168, 255), Glow = Color3.fromRGB(214, 232, 255), Label = "STORM" },
	Plasma = { Image = "rbxassetid://95337307481245", Color = Color3.fromRGB(255, 110, 230), Glow = Color3.fromRGB(255, 210, 250), Label = "PLASMA" },
	Sonic = { Image = "rbxassetid://71940175994938", Color = Color3.fromRGB(90, 240, 200), Glow = Color3.fromRGB(200, 255, 238), Label = "SONIC" },
	Ice = { Image = "rbxassetid://140564515768557", Color = Color3.fromRGB(128, 214, 255), Glow = Color3.fromRGB(226, 248, 255), Label = "FROST" },
	Blizzard = { Image = "rbxassetid://140246345276851", Color = Color3.fromRGB(170, 215, 255), Glow = Color3.fromRGB(235, 248, 255), Label = "BLIZZARD" },
	Water = { Image = "rbxassetid://120440899954864", Color = Color3.fromRGB(56, 150, 255), Glow = Color3.fromRGB(170, 225, 255), Label = "TIDE" },
	Steam = { Image = "rbxassetid://124112094986306", Color = Color3.fromRGB(200, 214, 228), Glow = Color3.fromRGB(240, 246, 255), Label = "STEAM" },
	Wind = { Image = "rbxassetid://124256621174881", Color = Color3.fromRGB(170, 240, 220), Glow = Color3.fromRGB(230, 255, 248), Label = "GALE" },
	Sand = { Image = "rbxassetid://73003581488609", Color = Color3.fromRGB(226, 190, 120), Glow = Color3.fromRGB(255, 230, 170), Label = "SAND" },
	Earth = { Image = "rbxassetid://108315651726917", Color = Color3.fromRGB(206, 150, 82), Glow = Color3.fromRGB(255, 214, 140), Label = "EARTH" },
	Nature = { Image = "rbxassetid://136263960261392", Color = Color3.fromRGB(96, 210, 96), Glow = Color3.fromRGB(220, 255, 150), Label = "VERDANT" },
	Poison = { Image = "rbxassetid://119141615859647", Color = Color3.fromRGB(128, 228, 74), Glow = Color3.fromRGB(214, 255, 160), Label = "VENOM" },
	Blood = { Image = "rbxassetid://82635464008076", Color = Color3.fromRGB(220, 36, 52), Glow = Color3.fromRGB(255, 140, 140), Label = "BLOOD" },
	Void = { Image = "rbxassetid://128019553858074", Color = Color3.fromRGB(176, 92, 255), Glow = Color3.fromRGB(240, 190, 255), Label = "VOID" },
	Shadow = { Image = "rbxassetid://72352580755730", Color = Color3.fromRGB(150, 80, 230), Glow = Color3.fromRGB(220, 150, 255), Label = "SHADE" },
	Spirit = { Image = "rbxassetid://100225646785252", Color = Color3.fromRGB(120, 175, 255), Glow = Color3.fromRGB(215, 235, 255), Label = "SPIRIT" },
	Arcane = { Image = "rbxassetid://82821286149310", Color = Color3.fromRGB(110, 225, 255), Glow = Color3.fromRGB(255, 150, 240), Label = "ARCANE" },
	Radiance = { Image = "rbxassetid://72869662401440", Color = Color3.fromRGB(255, 214, 110), Glow = Color3.fromRGB(255, 244, 200), Label = "HOLY" },
	Prism = { Image = "rbxassetid://96093526087774", Color = Color3.fromRGB(190, 200, 255), Glow = Color3.fromRGB(255, 255, 255), Label = "PRISM" },
	Cosmic = { Image = "rbxassetid://72841188051895", Color = Color3.fromRGB(150, 130, 245), Glow = Color3.fromRGB(240, 220, 170), Label = "COSMIC" },
	Chrono = { Image = "rbxassetid://113321010137837", Color = Color3.fromRGB(240, 200, 110), Glow = Color3.fromRGB(170, 240, 255), Label = "CHRONO" },
	-- second wave: matter, sky, energy, life, mind
	Crystal = { Image = "rbxassetid://124140209834773", Color = Color3.fromRGB(176, 120, 255), Glow = Color3.fromRGB(236, 214, 255), Label = "CRYSTAL" },
	Steel = { Image = "rbxassetid://133844285515149", Color = Color3.fromRGB(170, 186, 204), Glow = Color3.fromRGB(236, 242, 250), Label = "STEEL" },
	Gold = { Image = "rbxassetid://113188059263005", Color = Color3.fromRGB(255, 196, 60), Glow = Color3.fromRGB(255, 236, 160), Label = "GILDED" },
	Amber = { Image = "rbxassetid://121481191090012", Color = Color3.fromRGB(240, 150, 40), Glow = Color3.fromRGB(255, 214, 130), Label = "AMBER" },
	Magnet = { Image = "rbxassetid://138033563150885", Color = Color3.fromRGB(230, 70, 90), Glow = Color3.fromRGB(130, 180, 255), Label = "MAGNET" },
	Gravity = { Image = "rbxassetid://89008930887194", Color = Color3.fromRGB(120, 90, 220), Glow = Color3.fromRGB(210, 190, 255), Label = "GRAVITY" },
	Nebula = { Image = "rbxassetid://92795523523050", Color = Color3.fromRGB(230, 110, 190), Glow = Color3.fromRGB(130, 230, 230), Label = "NEBULA" },
	Aurora = { Image = "rbxassetid://89801477760443", Color = Color3.fromRGB(90, 240, 170), Glow = Color3.fromRGB(200, 160, 255), Label = "AURORA" },
	Lunar = { Image = "rbxassetid://129560714847437", Color = Color3.fromRGB(196, 210, 240), Glow = Color3.fromRGB(245, 248, 255), Label = "LUNAR" },
	Comet = { Image = "rbxassetid://96655617985846", Color = Color3.fromRGB(120, 200, 255), Glow = Color3.fromRGB(240, 250, 255), Label = "COMET" },
	Eclipse = { Image = "rbxassetid://84763898664614", Color = Color3.fromRGB(250, 236, 210), Glow = Color3.fromRGB(255, 255, 255), Label = "ECLIPSE" },
	Starlight = { Image = "rbxassetid://118112368463240", Color = Color3.fromRGB(255, 236, 160), Glow = Color3.fromRGB(255, 252, 230), Label = "STARLIGHT" },
	Celestial = { Image = "rbxassetid://104801271795673", Color = Color3.fromRGB(110, 160, 255), Glow = Color3.fromRGB(255, 226, 150), Label = "CELESTIAL" },
	Tempest = { Image = "rbxassetid://117811544655611", Color = Color3.fromRGB(90, 140, 200), Glow = Color3.fromRGB(200, 230, 255), Label = "TEMPEST" },
	Rift = { Image = "rbxassetid://137614693641458", Color = Color3.fromRGB(220, 60, 255), Glow = Color3.fromRGB(120, 240, 255), Label = "RIFT" },
	Quantum = { Image = "rbxassetid://134357195128570", Color = Color3.fromRGB(80, 220, 255), Glow = Color3.fromRGB(220, 250, 255), Label = "QUANTUM" },
	Aether = { Image = "rbxassetid://75134837642470", Color = Color3.fromRGB(200, 230, 255), Glow = Color3.fromRGB(255, 250, 220), Label = "AETHER" },
	Glitch = { Image = "rbxassetid://124509928671981", Color = Color3.fromRGB(120, 255, 200), Glow = Color3.fromRGB(255, 90, 170), Label = "GLITCH" },
	Vital = { Image = "rbxassetid://105102439255721", Color = Color3.fromRGB(255, 80, 120), Glow = Color3.fromRGB(255, 200, 210), Label = "VITAL" },
	Neon = { Image = "rbxassetid://101696418344609", Color = Color3.fromRGB(255, 60, 200), Glow = Color3.fromRGB(90, 250, 255), Label = "NEON" },
	Hologram = { Image = "rbxassetid://131738215678265", Color = Color3.fromRGB(90, 230, 255), Glow = Color3.fromRGB(200, 250, 255), Label = "HOLO" },
	Thorn = { Image = "rbxassetid://112122253552600", Color = Color3.fromRGB(90, 200, 80), Glow = Color3.fromRGB(230, 60, 90), Label = "THORN" },
	Spore = { Image = "rbxassetid://100103082185058", Color = Color3.fromRGB(200, 230, 110), Glow = Color3.fromRGB(250, 255, 200), Label = "SPORE" },
	Bloom = { Image = "rbxassetid://126420413961469", Color = Color3.fromRGB(255, 150, 200), Glow = Color3.fromRGB(255, 230, 240), Label = "BLOOM" },
	Dream = { Image = "rbxassetid://76306812376311", Color = Color3.fromRGB(190, 140, 255), Glow = Color3.fromRGB(150, 240, 240), Label = "DREAM" },
	Feather = { Image = "rbxassetid://86669100104116", Color = Color3.fromRGB(240, 230, 210), Glow = Color3.fromRGB(255, 250, 240), Label = "PLUME" },
	Abyss = { Image = "rbxassetid://81491812550281", Color = Color3.fromRGB(40, 90, 170), Glow = Color3.fromRGB(110, 220, 230), Label = "ABYSS" },
	Smoke = { Image = "rbxassetid://105883519911632", Color = Color3.fromRGB(150, 150, 160), Glow = Color3.fromRGB(220, 220, 228), Label = "SMOKE" },
	Necrotic = { Image = "rbxassetid://85047016815719", Color = Color3.fromRGB(130, 230, 90), Glow = Color3.fromRGB(200, 255, 170), Label = "NECRO" },
	Rune = { Image = "rbxassetid://89274334192386", Color = Color3.fromRGB(255, 170, 60), Glow = Color3.fromRGB(255, 226, 160), Label = "RUNE" },
	Mirror = { Image = "rbxassetid://135536979183555", Color = Color3.fromRGB(210, 225, 240), Glow = Color3.fromRGB(255, 255, 255), Label = "MIRROR" },
	Ink = { Image = "rbxassetid://74053721441984", Color = Color3.fromRGB(70, 80, 120), Glow = Color3.fromRGB(170, 180, 230), Label = "INK" },
	Frostfire = { Image = "rbxassetid://96246143015158", Color = Color3.fromRGB(80, 190, 255), Glow = Color3.fromRGB(255, 150, 70), Label = "FROSTFIRE" },
}

local ElementSprites = {
	-- ImageLabel crops use the 1024-square delivered UI image, not the uploaded source pixels.
	SOURCE_FRAME = 682,
	SOURCE_EDGE = 4096,
	UI_EDGE = 1024,
	FRAME = 682 * 1024 / 4096,
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
