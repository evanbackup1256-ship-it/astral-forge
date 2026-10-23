// Purpose: the 57 elemental companions plus the six named companions (Cinder to Voidmote) (tools/spritegen/companions), each an original character with its
// elemental light lit into its own frames, played with Vendor/Sprite. Every 4096-square sheet contains
// 6 x 6 native frames of 682 px, looping seamlessly over 36 frames.
// Owner: presentation. Dependencies: none. Review: 2026-10-08.

type Element =
	| "Fire"
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
	| "Frostfire";

interface Sheet {
	Image: string;
	Color: Color3;
	Glow: Color3;
	Label: string;
}

// Named companions: same 4096 sheet format (6 x 6 cells of 682 px, 36 frames, 24 fps), aura lit into the
// frames. Each borrows its element's colours so glows, trails and tints match the element it belongs to.
interface Companion extends Sheet {
	Name: string;
	Element: Element;
	Rarity: "Rare" | "Epic" | "Legendary" | "Mythic" | "Celestial";
}

const SHEETS: Record<string, Sheet> = table.freeze({
	Fire: table.freeze({ Image: "rbxassetid://103559340980670", Color: Color3.fromRGB(255, 132, 46), Glow: Color3.fromRGB(255, 196, 96), Label: "FIRE" }),
	Magma: table.freeze({ Image: "rbxassetid://136228071865089", Color: Color3.fromRGB(255, 96, 24), Glow: Color3.fromRGB(255, 190, 90), Label: "MAGMA" }),
	Solar: table.freeze({ Image: "rbxassetid://105208076927012", Color: Color3.fromRGB(255, 170, 40), Glow: Color3.fromRGB(255, 226, 140), Label: "SOLAR" }),
	Lightning: table.freeze({ Image: "rbxassetid://88421973804283", Color: Color3.fromRGB(120, 168, 255), Glow: Color3.fromRGB(214, 232, 255), Label: "STORM" }),
	Plasma: table.freeze({ Image: "rbxassetid://95337307481245", Color: Color3.fromRGB(255, 110, 230), Glow: Color3.fromRGB(255, 210, 250), Label: "PLASMA" }),
	Sonic: table.freeze({ Image: "rbxassetid://71940175994938", Color: Color3.fromRGB(90, 240, 200), Glow: Color3.fromRGB(200, 255, 238), Label: "SONIC" }),
	Ice: table.freeze({ Image: "rbxassetid://140564515768557", Color: Color3.fromRGB(128, 214, 255), Glow: Color3.fromRGB(226, 248, 255), Label: "FROST" }),
	Blizzard: table.freeze({ Image: "rbxassetid://140246345276851", Color: Color3.fromRGB(170, 215, 255), Glow: Color3.fromRGB(235, 248, 255), Label: "BLIZZARD" }),
	Water: table.freeze({ Image: "rbxassetid://120440899954864", Color: Color3.fromRGB(56, 150, 255), Glow: Color3.fromRGB(170, 225, 255), Label: "TIDE" }),
	Steam: table.freeze({ Image: "rbxassetid://124112094986306", Color: Color3.fromRGB(200, 214, 228), Glow: Color3.fromRGB(240, 246, 255), Label: "STEAM" }),
	Wind: table.freeze({ Image: "rbxassetid://124256621174881", Color: Color3.fromRGB(170, 240, 220), Glow: Color3.fromRGB(230, 255, 248), Label: "GALE" }),
	Sand: table.freeze({ Image: "rbxassetid://73003581488609", Color: Color3.fromRGB(226, 190, 120), Glow: Color3.fromRGB(255, 230, 170), Label: "SAND" }),
	Earth: table.freeze({ Image: "rbxassetid://108315651726917", Color: Color3.fromRGB(206, 150, 82), Glow: Color3.fromRGB(255, 214, 140), Label: "EARTH" }),
	Nature: table.freeze({ Image: "rbxassetid://136263960261392", Color: Color3.fromRGB(96, 210, 96), Glow: Color3.fromRGB(220, 255, 150), Label: "VERDANT" }),
	Poison: table.freeze({ Image: "rbxassetid://119141615859647", Color: Color3.fromRGB(128, 228, 74), Glow: Color3.fromRGB(214, 255, 160), Label: "VENOM" }),
	Blood: table.freeze({ Image: "rbxassetid://82635464008076", Color: Color3.fromRGB(220, 36, 52), Glow: Color3.fromRGB(255, 140, 140), Label: "BLOOD" }),
	Void: table.freeze({ Image: "rbxassetid://128019553858074", Color: Color3.fromRGB(176, 92, 255), Glow: Color3.fromRGB(240, 190, 255), Label: "VOID" }),
	Shadow: table.freeze({ Image: "rbxassetid://72352580755730", Color: Color3.fromRGB(150, 80, 230), Glow: Color3.fromRGB(220, 150, 255), Label: "SHADE" }),
	Spirit: table.freeze({ Image: "rbxassetid://100225646785252", Color: Color3.fromRGB(120, 175, 255), Glow: Color3.fromRGB(215, 235, 255), Label: "SPIRIT" }),
	Arcane: table.freeze({ Image: "rbxassetid://82821286149310", Color: Color3.fromRGB(110, 225, 255), Glow: Color3.fromRGB(255, 150, 240), Label: "ARCANE" }),
	Radiance: table.freeze({ Image: "rbxassetid://72869662401440", Color: Color3.fromRGB(255, 214, 110), Glow: Color3.fromRGB(255, 244, 200), Label: "HOLY" }),
	Prism: table.freeze({ Image: "rbxassetid://96093526087774", Color: Color3.fromRGB(190, 200, 255), Glow: Color3.fromRGB(255, 255, 255), Label: "PRISM" }),
	Cosmic: table.freeze({ Image: "rbxassetid://72841188051895", Color: Color3.fromRGB(150, 130, 245), Glow: Color3.fromRGB(240, 220, 170), Label: "COSMIC" }),
	Chrono: table.freeze({ Image: "rbxassetid://113321010137837", Color: Color3.fromRGB(240, 200, 110), Glow: Color3.fromRGB(170, 240, 255), Label: "CHRONO" }),
	// second wave: matter, sky, energy, life, mind
	Crystal: table.freeze({ Image: "rbxassetid://124140209834773", Color: Color3.fromRGB(176, 120, 255), Glow: Color3.fromRGB(236, 214, 255), Label: "CRYSTAL" }),
	Steel: table.freeze({ Image: "rbxassetid://133844285515149", Color: Color3.fromRGB(170, 186, 204), Glow: Color3.fromRGB(236, 242, 250), Label: "STEEL" }),
	Gold: table.freeze({ Image: "rbxassetid://113188059263005", Color: Color3.fromRGB(255, 196, 60), Glow: Color3.fromRGB(255, 236, 160), Label: "GILDED" }),
	Amber: table.freeze({ Image: "rbxassetid://121481191090012", Color: Color3.fromRGB(240, 150, 40), Glow: Color3.fromRGB(255, 214, 130), Label: "AMBER" }),
	Magnet: table.freeze({ Image: "rbxassetid://138033563150885", Color: Color3.fromRGB(230, 70, 90), Glow: Color3.fromRGB(130, 180, 255), Label: "MAGNET" }),
	Gravity: table.freeze({ Image: "rbxassetid://89008930887194", Color: Color3.fromRGB(120, 90, 220), Glow: Color3.fromRGB(210, 190, 255), Label: "GRAVITY" }),
	Nebula: table.freeze({ Image: "rbxassetid://92795523523050", Color: Color3.fromRGB(230, 110, 190), Glow: Color3.fromRGB(130, 230, 230), Label: "NEBULA" }),
	Aurora: table.freeze({ Image: "rbxassetid://89801477760443", Color: Color3.fromRGB(90, 240, 170), Glow: Color3.fromRGB(200, 160, 255), Label: "AURORA" }),
	Lunar: table.freeze({ Image: "rbxassetid://129560714847437", Color: Color3.fromRGB(196, 210, 240), Glow: Color3.fromRGB(245, 248, 255), Label: "LUNAR" }),
	Comet: table.freeze({ Image: "rbxassetid://96655617985846", Color: Color3.fromRGB(120, 200, 255), Glow: Color3.fromRGB(240, 250, 255), Label: "COMET" }),
	Eclipse: table.freeze({ Image: "rbxassetid://84763898664614", Color: Color3.fromRGB(250, 236, 210), Glow: Color3.fromRGB(255, 255, 255), Label: "ECLIPSE" }),
	Starlight: table.freeze({ Image: "rbxassetid://118112368463240", Color: Color3.fromRGB(255, 236, 160), Glow: Color3.fromRGB(255, 252, 230), Label: "STARLIGHT" }),
	Celestial: table.freeze({ Image: "rbxassetid://104801271795673", Color: Color3.fromRGB(110, 160, 255), Glow: Color3.fromRGB(255, 226, 150), Label: "CELESTIAL" }),
	Tempest: table.freeze({ Image: "rbxassetid://117811544655611", Color: Color3.fromRGB(90, 140, 200), Glow: Color3.fromRGB(200, 230, 255), Label: "TEMPEST" }),
	Rift: table.freeze({ Image: "rbxassetid://137614693641458", Color: Color3.fromRGB(220, 60, 255), Glow: Color3.fromRGB(120, 240, 255), Label: "RIFT" }),
	Quantum: table.freeze({ Image: "rbxassetid://134357195128570", Color: Color3.fromRGB(80, 220, 255), Glow: Color3.fromRGB(220, 250, 255), Label: "QUANTUM" }),
	Aether: table.freeze({ Image: "rbxassetid://75134837642470", Color: Color3.fromRGB(200, 230, 255), Glow: Color3.fromRGB(255, 250, 220), Label: "AETHER" }),
	Glitch: table.freeze({ Image: "rbxassetid://124509928671981", Color: Color3.fromRGB(120, 255, 200), Glow: Color3.fromRGB(255, 90, 170), Label: "GLITCH" }),
	Vital: table.freeze({ Image: "rbxassetid://105102439255721", Color: Color3.fromRGB(255, 80, 120), Glow: Color3.fromRGB(255, 200, 210), Label: "VITAL" }),
	Neon: table.freeze({ Image: "rbxassetid://101696418344609", Color: Color3.fromRGB(255, 60, 200), Glow: Color3.fromRGB(90, 250, 255), Label: "NEON" }),
	Hologram: table.freeze({ Image: "rbxassetid://131738215678265", Color: Color3.fromRGB(90, 230, 255), Glow: Color3.fromRGB(200, 250, 255), Label: "HOLO" }),
	Thorn: table.freeze({ Image: "rbxassetid://112122253552600", Color: Color3.fromRGB(90, 200, 80), Glow: Color3.fromRGB(230, 60, 90), Label: "THORN" }),
	Spore: table.freeze({ Image: "rbxassetid://100103082185058", Color: Color3.fromRGB(200, 230, 110), Glow: Color3.fromRGB(250, 255, 200), Label: "SPORE" }),
	Bloom: table.freeze({ Image: "rbxassetid://126420413961469", Color: Color3.fromRGB(255, 150, 200), Glow: Color3.fromRGB(255, 230, 240), Label: "BLOOM" }),
	Dream: table.freeze({ Image: "rbxassetid://76306812376311", Color: Color3.fromRGB(190, 140, 255), Glow: Color3.fromRGB(150, 240, 240), Label: "DREAM" }),
	Feather: table.freeze({ Image: "rbxassetid://86669100104116", Color: Color3.fromRGB(240, 230, 210), Glow: Color3.fromRGB(255, 250, 240), Label: "PLUME" }),
	Abyss: table.freeze({ Image: "rbxassetid://81491812550281", Color: Color3.fromRGB(40, 90, 170), Glow: Color3.fromRGB(110, 220, 230), Label: "ABYSS" }),
	Smoke: table.freeze({ Image: "rbxassetid://105883519911632", Color: Color3.fromRGB(150, 150, 160), Glow: Color3.fromRGB(220, 220, 228), Label: "SMOKE" }),
	Necrotic: table.freeze({ Image: "rbxassetid://85047016815719", Color: Color3.fromRGB(130, 230, 90), Glow: Color3.fromRGB(200, 255, 170), Label: "NECRO" }),
	Rune: table.freeze({ Image: "rbxassetid://89274334192386", Color: Color3.fromRGB(255, 170, 60), Glow: Color3.fromRGB(255, 226, 160), Label: "RUNE" }),
	Mirror: table.freeze({ Image: "rbxassetid://135536979183555", Color: Color3.fromRGB(210, 225, 240), Glow: Color3.fromRGB(255, 255, 255), Label: "MIRROR" }),
	Ink: table.freeze({ Image: "rbxassetid://74053721441984", Color: Color3.fromRGB(70, 80, 120), Glow: Color3.fromRGB(170, 180, 230), Label: "INK" }),
	Frostfire: table.freeze({ Image: "rbxassetid://96246143015158", Color: Color3.fromRGB(80, 190, 255), Glow: Color3.fromRGB(255, 150, 70), Label: "FROSTFIRE" }),
});

// Companion sheets were uploaded as Decals: draw the image the server resolved (Shared/UiArt,
// attribute UiArt_<id>). Kept import-free so the sprite tests can load this module on its own.
function art(url: string): string {
	const [ok, resolved] = pcall(() => {
		const [digits] = string.match(url, "%d+$");
		return game.GetService("ReplicatedStorage").GetAttribute("UiArt_" + tostring(digits));
	});
	return ok && typeIs(resolved, "string") && resolved !== "" ? resolved : url;
}

function companion(name: string, element: Element, rarity: Companion["Rarity"], image: string): Companion {
	const base = SHEETS[element];
	return table.freeze({ Image: image, Color: base.Color, Glow: base.Glow, Label: string.upper(name), Name: name, Element: element, Rarity: rarity });
}

const COMPANIONS: Record<string, Companion> = table.freeze({
	Cinder: companion("Cinder", "Fire", "Rare", art("rbxassetid://96721820700576")),
	Frostlet: companion("Frostlet", "Ice", "Rare", art("rbxassetid://102982024064892")),
	Tidepup: companion("Tidepup", "Water", "Epic", art("rbxassetid://112367869722042")),
	BrassOwl: companion("Brass Owl", "Gold", "Legendary", art("rbxassetid://92141659344017")),
	Lumen: companion("Lumen", "Starlight", "Mythic", art("rbxassetid://125440001868646")),
	Voidmote: companion("Voidmote", "Void", "Celestial", art("rbxassetid://111706636066465")),
});

const ElementSprites = {
	// ImageLabel crops use the 1024-square delivered UI image, not the uploaded source pixels.
	SOURCE_FRAME: 682,
	SOURCE_EDGE: 4096,
	UI_EDGE: 1024,
	FRAME: 682 * 1024 / 4096,
	COLUMNS: 6,
	COUNT: 36,
	FRAMERATE: 24,
	// grouped by family: heat, energy, cold, air and ground, life and decay, the beyond, then the
	// second wave (matter, sky, energy, life, mind)
	ORDER: table.freeze([
		"Fire",
		"Magma",
		"Solar",
		"Lightning",
		"Plasma",
		"Sonic",
		"Ice",
		"Blizzard",
		"Water",
		"Steam",
		"Wind",
		"Sand",
		"Earth",
		"Nature",
		"Poison",
		"Blood",
		"Void",
		"Shadow",
		"Spirit",
		"Arcane",
		"Radiance",
		"Prism",
		"Cosmic",
		"Chrono",
		"Crystal",
		"Steel",
		"Gold",
		"Amber",
		"Magnet",
		"Gravity",
		"Nebula",
		"Aurora",
		"Lunar",
		"Comet",
		"Eclipse",
		"Starlight",
		"Celestial",
		"Tempest",
		"Rift",
		"Quantum",
		"Aether",
		"Glitch",
		"Vital",
		"Neon",
		"Hologram",
		"Thorn",
		"Spore",
		"Bloom",
		"Dream",
		"Feather",
		"Abyss",
		"Smoke",
		"Necrotic",
		"Rune",
		"Mirror",
		"Ink",
		"Frostfire",
	]) as ReadonlyArray<Element>,
	// named companions, by rarity
	COMPANION_ORDER: table.freeze(["Cinder", "Frostlet", "Tidepup", "BrassOwl", "Lumen", "Voidmote"]) as ReadonlyArray<string>,
};

// accepts an element key or a named companion key
function sheet(element: string | undefined): Sheet | undefined {
	return element ? (SHEETS[element] ?? COMPANIONS[element]) : undefined;
}

function companionInfo(key: string | undefined): Companion | undefined {
	return key ? COMPANIONS[key] : undefined;
}

// the Sprite library's ArrayConfig for one element
function animation(element: string, framerate?: number): Record<string, unknown> | undefined {
	const s = sheet(element);
	if (s === undefined) {
		return undefined;
	}
	return {
		Spritesheet: s.Image,
		SpriteSize: new Vector2(ElementSprites.FRAME, ElementSprites.FRAME),
		Columns: ElementSprites.COLUMNS,
		SpriteCount: ElementSprites.COUNT,
		Framerate: framerate ?? ElementSprites.FRAMERATE,
		Looped: true,
		DebugId: element,
	};
}

const Module = {
	...ElementSprites,
	sheet,
	animation,
	companion: companionInfo,
};

export = table.freeze(Module);
