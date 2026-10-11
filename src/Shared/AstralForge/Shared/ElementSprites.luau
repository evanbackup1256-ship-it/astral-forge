--!strict
-- Purpose: elemental characters (build_characters.py) and their original animated auras, played with
-- Vendor/Sprite. Every 4096-square sheet contains 6 x 6 native frames of 682 px, looping seamlessly over 36 frames.
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
export type Sheet = { Image: string, AuraImage: string?, Color: Color3, Glow: Color3, Label: string }

local SHEETS: { [string]: Sheet } = {
	Fire = { Image = "rbxassetid://111447809671088", AuraImage = "rbxassetid://75976026803717", Color = Color3.fromRGB(255, 132, 46), Glow = Color3.fromRGB(255, 196, 96), Label = "FIRE" },
	Magma = { Image = "rbxassetid://81431803433973", AuraImage = "rbxassetid://127417954982692", Color = Color3.fromRGB(255, 96, 24), Glow = Color3.fromRGB(255, 190, 90), Label = "MAGMA" },
	Solar = { Image = "rbxassetid://97912556559157", AuraImage = "rbxassetid://139355283956152", Color = Color3.fromRGB(255, 170, 40), Glow = Color3.fromRGB(255, 226, 140), Label = "SOLAR" },
	Lightning = { Image = "rbxassetid://109191589432618", AuraImage = "rbxassetid://88673805033416", Color = Color3.fromRGB(120, 168, 255), Glow = Color3.fromRGB(214, 232, 255), Label = "STORM" },
	Plasma = { Image = "rbxassetid://70600792434328", AuraImage = "rbxassetid://135720362312706", Color = Color3.fromRGB(255, 110, 230), Glow = Color3.fromRGB(255, 210, 250), Label = "PLASMA" },
	Sonic = { Image = "rbxassetid://106277092479219", AuraImage = "rbxassetid://117070978419793", Color = Color3.fromRGB(90, 240, 200), Glow = Color3.fromRGB(200, 255, 238), Label = "SONIC" },
	Ice = { Image = "rbxassetid://98766042648831", AuraImage = "rbxassetid://129231182369214", Color = Color3.fromRGB(128, 214, 255), Glow = Color3.fromRGB(226, 248, 255), Label = "FROST" },
	Blizzard = { Image = "rbxassetid://121252939038235", AuraImage = "rbxassetid://83201051020045", Color = Color3.fromRGB(170, 215, 255), Glow = Color3.fromRGB(235, 248, 255), Label = "BLIZZARD" },
	Water = { Image = "rbxassetid://107002998982870", AuraImage = "rbxassetid://73443894351938", Color = Color3.fromRGB(56, 150, 255), Glow = Color3.fromRGB(170, 225, 255), Label = "TIDE" },
	Steam = { Image = "rbxassetid://90427768101130", AuraImage = "rbxassetid://103405037811070", Color = Color3.fromRGB(200, 214, 228), Glow = Color3.fromRGB(240, 246, 255), Label = "STEAM" },
	Wind = { Image = "rbxassetid://137764373699502", AuraImage = "rbxassetid://121274743923130", Color = Color3.fromRGB(170, 240, 220), Glow = Color3.fromRGB(230, 255, 248), Label = "GALE" },
	Sand = { Image = "rbxassetid://100820986507224", AuraImage = "rbxassetid://139581563905463", Color = Color3.fromRGB(226, 190, 120), Glow = Color3.fromRGB(255, 230, 170), Label = "SAND" },
	Earth = { Image = "rbxassetid://95963844787056", AuraImage = "rbxassetid://122858791536550", Color = Color3.fromRGB(206, 150, 82), Glow = Color3.fromRGB(255, 214, 140), Label = "EARTH" },
	Nature = { Image = "rbxassetid://81861665976747", AuraImage = "rbxassetid://74138078270385", Color = Color3.fromRGB(96, 210, 96), Glow = Color3.fromRGB(220, 255, 150), Label = "VERDANT" },
	Poison = { Image = "rbxassetid://97612321546573", AuraImage = "rbxassetid://132948266732245", Color = Color3.fromRGB(128, 228, 74), Glow = Color3.fromRGB(214, 255, 160), Label = "VENOM" },
	Blood = { Image = "rbxassetid://81268517658415", AuraImage = "rbxassetid://129638345849457", Color = Color3.fromRGB(220, 36, 52), Glow = Color3.fromRGB(255, 140, 140), Label = "BLOOD" },
	Void = { Image = "rbxassetid://72582361906677", AuraImage = "rbxassetid://105059923981820", Color = Color3.fromRGB(176, 92, 255), Glow = Color3.fromRGB(240, 190, 255), Label = "VOID" },
	Shadow = { Image = "rbxassetid://101114428813630", AuraImage = "rbxassetid://113400821734037", Color = Color3.fromRGB(150, 80, 230), Glow = Color3.fromRGB(220, 150, 255), Label = "SHADE" },
	Spirit = { Image = "rbxassetid://117631341522786", AuraImage = "rbxassetid://89291263140092", Color = Color3.fromRGB(120, 175, 255), Glow = Color3.fromRGB(215, 235, 255), Label = "SPIRIT" },
	Arcane = { Image = "rbxassetid://114670644832212", AuraImage = "rbxassetid://131564360744318", Color = Color3.fromRGB(110, 225, 255), Glow = Color3.fromRGB(255, 150, 240), Label = "ARCANE" },
	Radiance = { Image = "rbxassetid://104413303102728", AuraImage = "rbxassetid://96066433332861", Color = Color3.fromRGB(255, 214, 110), Glow = Color3.fromRGB(255, 244, 200), Label = "HOLY" },
	Prism = { Image = "rbxassetid://78150131426669", AuraImage = "rbxassetid://93759688256571", Color = Color3.fromRGB(190, 200, 255), Glow = Color3.fromRGB(255, 255, 255), Label = "PRISM" },
	Cosmic = { Image = "rbxassetid://82218031640477", AuraImage = "rbxassetid://123233648515802", Color = Color3.fromRGB(150, 130, 245), Glow = Color3.fromRGB(240, 220, 170), Label = "COSMIC" },
	Chrono = { Image = "rbxassetid://120547038955477", AuraImage = "rbxassetid://109164077592690", Color = Color3.fromRGB(240, 200, 110), Glow = Color3.fromRGB(170, 240, 255), Label = "CHRONO" },
	-- second wave (tools/spritegen/build_elements_ext.py): matter, sky, energy, life, mind
	Crystal = { Image = "rbxassetid://114088794082870", AuraImage = "rbxassetid://85653486652604", Color = Color3.fromRGB(176, 120, 255), Glow = Color3.fromRGB(236, 214, 255), Label = "CRYSTAL" },
	Steel = { Image = "rbxassetid://116386955230835", AuraImage = "rbxassetid://121048122298265", Color = Color3.fromRGB(170, 186, 204), Glow = Color3.fromRGB(236, 242, 250), Label = "STEEL" },
	Gold = { Image = "rbxassetid://106876258551836", AuraImage = "rbxassetid://75829326038387", Color = Color3.fromRGB(255, 196, 60), Glow = Color3.fromRGB(255, 236, 160), Label = "GILDED" },
	Amber = { Image = "rbxassetid://138670748201563", AuraImage = "rbxassetid://86616488471621", Color = Color3.fromRGB(240, 150, 40), Glow = Color3.fromRGB(255, 214, 130), Label = "AMBER" },
	Magnet = { Image = "rbxassetid://122165803838498", AuraImage = "rbxassetid://71975623647599", Color = Color3.fromRGB(230, 70, 90), Glow = Color3.fromRGB(130, 180, 255), Label = "MAGNET" },
	Gravity = { Image = "rbxassetid://97838200737949", AuraImage = "rbxassetid://71846469221496", Color = Color3.fromRGB(120, 90, 220), Glow = Color3.fromRGB(210, 190, 255), Label = "GRAVITY" },
	Nebula = { Image = "rbxassetid://75105287740671", AuraImage = "rbxassetid://89805335155299", Color = Color3.fromRGB(230, 110, 190), Glow = Color3.fromRGB(130, 230, 230), Label = "NEBULA" },
	Aurora = { Image = "rbxassetid://123216372415105", AuraImage = "rbxassetid://128165425037666", Color = Color3.fromRGB(90, 240, 170), Glow = Color3.fromRGB(200, 160, 255), Label = "AURORA" },
	Lunar = { Image = "rbxassetid://115143911781324", AuraImage = "rbxassetid://88606774613245", Color = Color3.fromRGB(196, 210, 240), Glow = Color3.fromRGB(245, 248, 255), Label = "LUNAR" },
	Comet = { Image = "rbxassetid://126346096372520", AuraImage = "rbxassetid://116086221045089", Color = Color3.fromRGB(120, 200, 255), Glow = Color3.fromRGB(240, 250, 255), Label = "COMET" },
	Eclipse = { Image = "rbxassetid://91246453929756", AuraImage = "rbxassetid://91462422412033", Color = Color3.fromRGB(250, 236, 210), Glow = Color3.fromRGB(255, 255, 255), Label = "ECLIPSE" },
	Starlight = { Image = "rbxassetid://74929493329686", AuraImage = "rbxassetid://70546963687596", Color = Color3.fromRGB(255, 236, 160), Glow = Color3.fromRGB(255, 252, 230), Label = "STARLIGHT" },
	Celestial = { Image = "rbxassetid://94662474602323", AuraImage = "rbxassetid://119516804604438", Color = Color3.fromRGB(110, 160, 255), Glow = Color3.fromRGB(255, 226, 150), Label = "CELESTIAL" },
	Tempest = { Image = "rbxassetid://119103916343585", AuraImage = "rbxassetid://135957868917787", Color = Color3.fromRGB(90, 140, 200), Glow = Color3.fromRGB(200, 230, 255), Label = "TEMPEST" },
	Rift = { Image = "rbxassetid://114213097855477", AuraImage = "rbxassetid://125939388500796", Color = Color3.fromRGB(220, 60, 255), Glow = Color3.fromRGB(120, 240, 255), Label = "RIFT" },
	Quantum = { Image = "rbxassetid://79050688694545", AuraImage = "rbxassetid://120814296458865", Color = Color3.fromRGB(80, 220, 255), Glow = Color3.fromRGB(220, 250, 255), Label = "QUANTUM" },
	Aether = { Image = "rbxassetid://85930930706504", AuraImage = "rbxassetid://113068955894142", Color = Color3.fromRGB(200, 230, 255), Glow = Color3.fromRGB(255, 250, 220), Label = "AETHER" },
	Glitch = { Image = "rbxassetid://72576241745145", AuraImage = "rbxassetid://80818500840586", Color = Color3.fromRGB(120, 255, 200), Glow = Color3.fromRGB(255, 90, 170), Label = "GLITCH" },
	Vital = { Image = "rbxassetid://111081003793468", AuraImage = "rbxassetid://98648302970918", Color = Color3.fromRGB(255, 80, 120), Glow = Color3.fromRGB(255, 200, 210), Label = "VITAL" },
	Neon = { Image = "rbxassetid://124125519181865", AuraImage = "rbxassetid://100379758242650", Color = Color3.fromRGB(255, 60, 200), Glow = Color3.fromRGB(90, 250, 255), Label = "NEON" },
	Hologram = { Image = "rbxassetid://73187081496632", AuraImage = "rbxassetid://75118498064865", Color = Color3.fromRGB(90, 230, 255), Glow = Color3.fromRGB(200, 250, 255), Label = "HOLO" },
	Thorn = { Image = "rbxassetid://89155019319236", AuraImage = "rbxassetid://92051415824932", Color = Color3.fromRGB(90, 200, 80), Glow = Color3.fromRGB(230, 60, 90), Label = "THORN" },
	Spore = { Image = "rbxassetid://135837291254305", AuraImage = "rbxassetid://136569081698512", Color = Color3.fromRGB(200, 230, 110), Glow = Color3.fromRGB(250, 255, 200), Label = "SPORE" },
	Bloom = { Image = "rbxassetid://108374547005567", AuraImage = "rbxassetid://104878672921031", Color = Color3.fromRGB(255, 150, 200), Glow = Color3.fromRGB(255, 230, 240), Label = "BLOOM" },
	Dream = { Image = "rbxassetid://121600607635020", AuraImage = "rbxassetid://108401326257307", Color = Color3.fromRGB(190, 140, 255), Glow = Color3.fromRGB(150, 240, 240), Label = "DREAM" },
	Feather = { Image = "rbxassetid://114025735294274", AuraImage = "rbxassetid://100678135005461", Color = Color3.fromRGB(240, 230, 210), Glow = Color3.fromRGB(255, 250, 240), Label = "PLUME" },
	Abyss = { Image = "rbxassetid://89502003377521", AuraImage = "rbxassetid://124972307990143", Color = Color3.fromRGB(40, 90, 170), Glow = Color3.fromRGB(110, 220, 230), Label = "ABYSS" },
	Smoke = { Image = "rbxassetid://97722437632410", AuraImage = "rbxassetid://114574867468789", Color = Color3.fromRGB(150, 150, 160), Glow = Color3.fromRGB(220, 220, 228), Label = "SMOKE" },
	Necrotic = { Image = "rbxassetid://133822306801477", AuraImage = "rbxassetid://131273690422408", Color = Color3.fromRGB(130, 230, 90), Glow = Color3.fromRGB(200, 255, 170), Label = "NECRO" },
	Rune = { Image = "rbxassetid://88923745117102", AuraImage = "rbxassetid://102990790708245", Color = Color3.fromRGB(255, 170, 60), Glow = Color3.fromRGB(255, 226, 160), Label = "RUNE" },
	Mirror = { Image = "rbxassetid://81422171953780", AuraImage = "rbxassetid://71473902613386", Color = Color3.fromRGB(210, 225, 240), Glow = Color3.fromRGB(255, 255, 255), Label = "MIRROR" },
	Ink = { Image = "rbxassetid://108035341281964", AuraImage = "rbxassetid://88272604991650", Color = Color3.fromRGB(70, 80, 120), Glow = Color3.fromRGB(170, 180, 230), Label = "INK" },
	Frostfire = { Image = "rbxassetid://79839048394513", AuraImage = "rbxassetid://88041958452929", Color = Color3.fromRGB(80, 190, 255), Glow = Color3.fromRGB(255, 150, 70), Label = "FROSTFIRE" },
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
function ElementSprites.animation(element: string, framerate: number?, aura: boolean?): any?
	local sheet = SHEETS[element]
	if sheet == nil then
		return nil
	end
	return {
		Spritesheet = if aura and sheet.AuraImage then sheet.AuraImage else sheet.Image,
		SpriteSize = Vector2.new(ElementSprites.FRAME, ElementSprites.FRAME),
		Columns = ElementSprites.COLUMNS,
		SpriteCount = ElementSprites.COUNT,
		Framerate = framerate or ElementSprites.FRAMERATE,
		Looped = true,
		DebugId = element,
	}
end

return table.freeze(ElementSprites)
