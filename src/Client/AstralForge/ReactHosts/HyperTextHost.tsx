import React from "@rbxts/react";
import { ClientLog } from "../CoreKit/log";
import { darken, lighten, Palette } from "../CoreKit/theme";
import { markupNumber } from "./hyperTextMarkup";

const ReplicatedStorage = game.GetService("ReplicatedStorage");

const TITLE_FX_KINDS = [
	"wave",
	"fire",
	"ice",
	"glitch",
	"galaxy",
	"rainbow",
	"glow",
	"neon",
	"sparkle",
	"shake",
	"pulse",
	"gradient-shift",
	"holographic",
	"void",
	"plasma",
	"chrome",
	"ember",
	"frost",
	"aurora",
	"matrix",
	"static",
	"bounce-in",
	"blur-resolve",
	"shimmer",
	"toxic",
	"solar",
	"ocean",
	"candy",
	"voltage",
	"prism",
	"phantom",
	"eclipse",
	"nebula",
	"molten",
	"circuit",
	"comet",
	"starforge",
];
const FX_SET = new Set<string>();
for (const kind of TITLE_FX_KINDS) {
	FX_SET.add(kind);
}

function parseFx(fx: unknown): string | undefined {
	if (fx === undefined || fx === "") {
		return undefined;
	}
	const key = string.lower(fx as string);
	return FX_SET.has(key) ? key : undefined;
}

const FX_ACCENT: Record<string, Color3> = {
	wave: Palette.cyan,
	fire: Palette.mango,
	ice: Palette.cyan,
	glitch: Palette.pink,
	galaxy: Palette.violet,
	rainbow: Color3.fromRGB(255, 170, 60),
	glow: lighten(Palette.cream, 0.1),
	neon: Palette.mint,
	sparkle: Palette.mango,
	shake: Palette.coral,
	pulse: Palette.violet,
	["gradient-shift"]: Palette.blue,
	holographic: Palette.cyan,
	void: Palette.violet,
	plasma: Palette.pink,
	chrome: Palette.creamSoft,
	ember: Palette.coral,
	frost: Color3.fromRGB(180, 220, 255),
	aurora: Palette.mint,
	matrix: Palette.green,
	static: Palette.cream,
	["bounce-in"]: Palette.mango,
	["blur-resolve"]: Palette.cream,
	shimmer: Palette.creamSoft,
	toxic: Color3.fromRGB(120, 255, 40),
	solar: Palette.mango,
	ocean: Palette.blue,
	candy: Palette.pink,
	voltage: Palette.cyan,
	prism: Palette.pink,
	phantom: Palette.violet,
	eclipse: Color3.fromRGB(255, 214, 140),
	nebula: Palette.violet,
	molten: Color3.fromRGB(255, 120, 40),
	circuit: Palette.mint,
	comet: Palette.cyan,
	starforge: Color3.fromRGB(255, 226, 150),
};

function titleFxAccent(fx: unknown): Color3 {
	const kind = parseFx(fx);
	return kind !== undefined ? FX_ACCENT[kind] : Palette.creamSoft;
}

function darkTitlePlate(fx: unknown): Color3 {
	return darken(titleFxAccent(fx), 0.82);
}

const TITLE_TIER: Record<string, string | undefined> = {
	wave: "Common",
	shake: "Common",
	pulse: "Common",
	static: "Common",
	["bounce-in"]: "Common",
	["blur-resolve"]: "Common",
	glow: "Common",
	shimmer: "Common",
	ice: "Rare",
	frost: "Rare",
	ember: "Rare",
	neon: "Rare",
	matrix: "Rare",
	candy: "Rare",
	ocean: "Rare",
	toxic: "Rare",
	sparkle: "Rare",
	["gradient-shift"]: "Rare",
	chrome: "Rare",
	fire: "Epic",
	glitch: "Epic",
	aurora: "Epic",
	voltage: "Epic",
	holographic: "Epic",
	plasma: "Epic",
	phantom: "Epic",
	circuit: "Epic",
	rainbow: "Epic",
	galaxy: "Legendary",
	void: "Legendary",
	solar: "Legendary",
	molten: "Legendary",
	comet: "Legendary",
	eclipse: "Legendary",
	prism: "Legendary",
	nebula: "Legendary",
	starforge: "Mythic",
};

function titleTier(fx: unknown): string {
	const kind = parseFx(fx);
	return kind !== undefined ? TITLE_TIER[kind] ?? "Common" : "Common";
}

function colorTag(color: Color3): string {
	return `${math.round(color.R * 255)},${math.round(color.G * 255)},${math.round(color.B * 255)}`;
}

function safeText(value: string): string {
	let cleaned = string.gsub(value, "<", "(")[0];
	cleaned = string.gsub(cleaned, ">", ")")[0];
	return cleaned;
}

const REVEAL_STAGGER = 0.015;

function buildKindMarkup(kind: string, body: string): string {
	const accent = FX_ACCENT[kind];
	if (kind === "wave") {
		return `<anim=wiggle freq=1.35 amp=.34 offset=.16 rot=true loop=true><shadow=true color=${colorTag(Color3.fromRGB(12, 42, 68))} offset=.05,.18 trans=.35><stroke=true color=${colorTag(Color3.fromRGB(16, 48, 72))} thickness=.04 trans=.18><strokeGradient=true colors=${colorTag(Palette.cyan)};${colorTag(Palette.white)};${colorTag(Palette.blue)} individual=true moveDir=right moveSpeed=.65><gradient=true colors=${colorTag(Color3.fromRGB(45, 165, 225))};${colorTag(Palette.cyan)};${colorTag(Color3.fromRGB(195, 248, 255))};${colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.55 rot=12>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "ocean") {
		return `<anim=orbit freq=1.1 amp=.24 offset=.2 rot=true loop=true><shadow=true color=${colorTag(Color3.fromRGB(8, 24, 54))} offset=.06,.22 trans=.3><stroke=true color=${colorTag(Color3.fromRGB(14, 44, 92))} thickness=.042 trans=.15><gradient=true colors=${colorTag(Color3.fromRGB(20, 75, 155))};${colorTag(Palette.blue)};${colorTag(Palette.cyan)};${colorTag(Color3.fromRGB(175, 240, 255))} individual=false moveDir=left moveSpeed=.38 rot=16>${body}</gradient></stroke></shadow></anim>`;
	}
	if (kind === "aurora") {
		return `<anim=spiral freq=1.15 amp=.28 offset=.18 rot=true loop=true><shiny=true color=${colorTag(Palette.mint)} rate=.42 chance=38 lifetime=.55,1.05 startSize=.14,.24 endSize=0,0 velY=-.25,.25 velX=-.25,.25><shadow=true color=${colorTag(Color3.fromRGB(18, 12, 42))} offset=.05,.2 trans=.32><stroke=true color=${colorTag(Palette.mint)} thickness=.04 trans=.2><strokeGradient=true colors=${colorTag(Palette.mint)};${colorTag(Palette.cyan)};${colorTag(Palette.pink)} individual=true moveDir=right moveSpeed=.6><gradient=true colors=${colorTag(Palette.mint)};${colorTag(Palette.cyan)};${colorTag(Palette.violet)};${colorTag(Palette.pink)} individual=false moveDir=right moveSpeed=.45 spacing=.12 rot=18>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "fire") {
		return `<anim=bounce dir=up offset=.26 exp=1.7 loop=true><shake=true maxOffset=.016 maxRot=1.8 loop=true freq=6 dur=0><shiny=true color=${colorTag(Color3.fromRGB(255, 200, 80))} rate=.85 chance=55 lifetime=.35,.68 startSize=.2,.34 endSize=0,0 velY=-1.1,-.55 startPosY=.1,.35 rotVel=-45,45><shadow=true color=${colorTag(Color3.fromRGB(58, 10, 4))} offset=.04,.22 trans=.25><stroke=true color=${colorTag(Color3.fromRGB(82, 18, 6))} thickness=.045><strokeGradient=true colors=${colorTag(Palette.coral)};${colorTag(Palette.mango)};${colorTag(Color3.fromRGB(255, 240, 130))} individual=true moveDir=right moveSpeed=.85><gradient=true colors=${colorTag(Color3.fromRGB(255, 62, 16))};${colorTag(Palette.mango)};${colorTag(Color3.fromRGB(255, 238, 125))};${colorTag(Color3.fromRGB(255, 95, 24))} individual=true moveDir=right moveSpeed=.65 rot=85>${body}</gradient></strokeGradient></stroke></shadow></shiny></shake></anim>`;
	}
	if (kind === "ember") {
		return `<anim=pendulum freq=1.4 amp=.28 offset=.22 rot=true loop=true><shake=true maxOffset=.012 maxRot=1.4 loop=true freq=4 dur=0><shiny=true color=${colorTag(Color3.fromRGB(255, 140, 55))} rate=.5 chance=44 lifetime=.55,1.05 startSize=.16,.26 endSize=0,0 velY=-.65,-.2 startPosY=-.1,.2 accelY=-.3,-.1><shadow=true color=${colorTag(Color3.fromRGB(44, 10, 4))} offset=.05,.2 trans=.3><stroke=true color=${colorTag(Color3.fromRGB(58, 14, 6))} thickness=.042><gradient=true colors=${colorTag(Color3.fromRGB(190, 42, 14))};${colorTag(Color3.fromRGB(255, 118, 42))};${colorTag(Color3.fromRGB(255, 214, 115))} individual=false moveDir=right moveSpeed=.48 rot=88>${body}</gradient></stroke></shadow></shiny></shake></anim>`;
	}
	if (kind === "solar") {
		return `<anim=pulsewave freq=1.55 amp=.32 offset=.16 rot=true loop=true><shiny=true color=${colorTag(Color3.fromRGB(255, 244, 170))} rate=.6 chance=42 lifetime=.45,.85 startSize=.2,.34 endSize=0,0 velY=-.38,.38 velX=-.38,.38><shadow=true color=${colorTag(Color3.fromRGB(78, 32, 6))} offset=.06,.24 trans=.25><stroke=true color=${colorTag(Color3.fromRGB(110, 48, 8))} thickness=.048><strokeGradient=true colors=${colorTag(Palette.mango)};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(255, 210, 75))} individual=false moveDir=right moveSpeed=.75><gradient=true colors=${colorTag(Color3.fromRGB(255, 200, 60))};${colorTag(Color3.fromRGB(255, 252, 218))};${colorTag(Palette.mango)};${colorTag(Color3.fromRGB(255, 140, 32))} individual=false moveDir=right moveSpeed=.62 rot=78>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "ice") {
		return `<anim=slide dir=down offset=.22 rot=-5 loop=true><shiny=true color=${colorTag(Palette.white)} rate=.45 chance=40 lifetime=.45,.85 startSize=.14,.24 endSize=0,0 velY=.18,.52 velX=-.18,.18><shadow=true color=${colorTag(Color3.fromRGB(18, 52, 88))} offset=.05,.2 trans=.3><stroke=true color=${colorTag(Palette.white)} thickness=.048 trans=.12><strokeGradient=true colors=${colorTag(Color3.fromRGB(110, 195, 255))};${colorTag(Palette.white)};${colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=.55><gradient=true colors=${colorTag(Color3.fromRGB(115, 198, 255))};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(160, 232, 255))};${colorTag(Color3.fromRGB(85, 175, 245))} individual=true moveDir=right moveSpeed=.42 rot=-16>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "frost") {
		return `<anim=pendulum freq=1.05 amp=.22 offset=.2 rot=true loop=true><shiny=true color=${colorTag(Palette.white)} rate=.38 chance=36 lifetime=.6,1.1 startSize=.14,.22 endSize=0,0 velY=-.12,.22><shadow=true color=${colorTag(Color3.fromRGB(24, 58, 96))} offset=.05,.18 trans=.32><stroke=true color=${colorTag(Color3.fromRGB(225, 244, 255))} thickness=.042 trans=.16><gradient=true colors=${colorTag(Color3.fromRGB(160, 212, 255))};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(200, 238, 255))};${colorTag(Color3.fromRGB(130, 190, 245))} individual=false moveDir=right moveSpeed=.36 rot=-12>${body}</gradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "glitch") {
		return `<decode=true dur=.16 freq=7 loop=true><shake=true maxOffset=.042 maxRot=3.4 loop=true freq=9 dur=0><shadow=true color=${colorTag(Palette.cyan)} offset=-.08,.14 trans=.22><stroke=true color=${colorTag(Color3.fromRGB(22, 4, 38))} thickness=.045><strokeGradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.cyan)};${colorTag(Palette.white)} individual=true moveDir=left moveSpeed=1.35><gradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.cyan)};${colorTag(Palette.white)};${colorTag(Palette.violet)} individual=true moveDir=left moveSpeed=1.15>${body}</gradient></strokeGradient></stroke></shadow></shake></decode>`;
	}
	if (kind === "static") {
		return `<shake=true maxOffset=.024 maxRot=1.8 loop=true freq=12 dur=0><decode=true dur=.12 freq=9 loop=true><shadow=true color=${colorTag(Color3.fromRGB(24, 34, 48))} offset=.05,.16 trans=.35><stroke=true color=${colorTag(Color3.fromRGB(28, 36, 46))} thickness=.04><gradient=true colors=${colorTag(Palette.creamSoft)};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(150, 185, 220))};${colorTag(Palette.cream)} individual=true moveDir=right moveSpeed=1.05 rot=90>${body}</gradient></stroke></shadow></decode></shake>`;
	}
	if (kind === "voltage") {
		return `<anim=pulsewave freq=2.2 amp=.28 offset=.14 rot=true loop=true><shake=true maxOffset=.026 maxRot=4.2 loop=true freq=11 dur=0><shiny=true color=${colorTag(Palette.cyan)} rate=.6 chance=46 lifetime=.25,.48 startSize=.16,.26 endSize=0,0 velX=-.85,.85 velY=-.45,.45><shadow=true color=${colorTag(Color3.fromRGB(10, 38, 74))} offset=.05,.2 trans=.26><stroke=true color=${colorTag(Palette.white)} thickness=.042><strokeGradient=true colors=${colorTag(Palette.cyan)};${colorTag(Palette.white)};${colorTag(Palette.blue)} moveDir=right moveSpeed=1.2 individual=false><gradient=true colors=${colorTag(Palette.white)};${colorTag(Palette.cyan)};${colorTag(Color3.fromRGB(105, 185, 255))};${colorTag(Palette.white)} individual=true moveDir=right moveSpeed=.95 rot=12>${body}</gradient></strokeGradient></stroke></shadow></shiny></shake></anim>`;
	}
	if (kind === "shake") {
		return `<shake=true maxOffset=.048 maxRot=5.5 loop=true freq=8 dur=0 fade=false><shiny=true color=${colorTag(Palette.mango)} rate=.5 chance=40 lifetime=.3,.58 startSize=.16,.28 endSize=0,0 velY=-.7,-.22 velX=-.5,.5><shadow=true color=${colorTag(Color3.fromRGB(48, 12, 8))} offset=.05,.18 trans=.3><stroke=true color=${colorTag(Color3.fromRGB(56, 14, 10))} thickness=.042><gradient=true colors=${colorTag(Palette.coral)};${colorTag(Palette.mango)};${colorTag(Color3.fromRGB(255, 215, 130))};${colorTag(Color3.fromRGB(255, 92, 48))} individual=true moveDir=right moveSpeed=.75>${body}</gradient></stroke></shadow></shiny></shake>`;
	}
	if (kind === "galaxy") {
		return `<anim=orbit freq=.95 amp=.32 offset=.22 rot=true loop=true><shiny=true color=${colorTag(Color3.fromRGB(230, 218, 255))} rate=.6 chance=48 lifetime=.5,1 startSize=.16,.28 endSize=0,0 velY=-.28,.28 velX=-.35,.35><shadow=true color=${colorTag(Color3.fromRGB(20, 8, 42))} offset=.06,.26 trans=.25><stroke=true color=${colorTag(Color3.fromRGB(38, 14, 68))} thickness=.046 trans=.14><strokeGradient=true colors=${colorTag(Palette.violet)};${colorTag(Palette.pink)};${colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=.65><rainbow=true freq=.28 offset=.18>${body}</rainbow></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "prism") {
		return `<anim=spiral freq=1.35 amp=.3 offset=.16 rot=true loop=true><shiny=true color=${colorTag(Palette.white)} rate=.5 chance=42 lifetime=.4,.8 startSize=.15,.25 endSize=0,0 velY=-.3,.3 velX=-.3,.3><shadow=true color=${colorTag(Color3.fromRGB(32, 14, 52))} offset=.06,.22 trans=.28><stroke=true color=${colorTag(Palette.white)} thickness=.045><strokeGradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.cyan)};${colorTag(Palette.mango)};${colorTag(Palette.violet)} individual=true moveDir=right moveSpeed=.85><rainbow=true freq=.55 offset=.12>${body}</rainbow></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "holographic") {
		return `<italic=true><anim=wiggle freq=1.45 amp=.26 offset=.18 rot=true loop=true><shadow=true color=${colorTag(Palette.pink)} offset=-.06,.16 trans=.32><stroke=true color=${colorTag(Color3.fromRGB(18, 46, 62))} thickness=.04><strokeGradient=true colors=${colorTag(Palette.cyan)};${colorTag(Palette.pink)};${colorTag(Palette.white)} individual=true moveDir=left moveSpeed=.95><gradient=true colors=${colorTag(Palette.cyan)};${colorTag(Palette.pink)};${colorTag(Palette.mint)};${colorTag(Palette.white)} individual=true moveDir=left moveSpeed=.95 rot=-18>${body}</gradient></strokeGradient></stroke></shadow></anim></italic>`;
	}
	if (kind === "gradient-shift") {
		return `<anim=pulsewave freq=1.2 amp=.22 offset=.18 rot=false loop=true><shadow=true color=${colorTag(Color3.fromRGB(14, 22, 48))} offset=.05,.18 trans=.32><stroke=true color=${colorTag(Palette.white)} thickness=.038 trans=.35><strokeGradient=true colors=${colorTag(Palette.blue)};${colorTag(Palette.pink)};${colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.55><gradient=true colors=${colorTag(Palette.blue)};${colorTag(Palette.violet)};${colorTag(Palette.pink)};${colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.48 spacing=.1 rot=15>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "candy") {
		return `<anim=bounce dir=up offset=.38 exp=1.85 loop=true><shadow=true color=${colorTag(Color3.fromRGB(58, 16, 42))} offset=.05,.2 trans=.3><stroke=true color=${colorTag(Color3.fromRGB(72, 20, 52))} thickness=.042><strokeGradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.cream)};${colorTag(Palette.mint)} individual=true moveDir=right moveSpeed=.6><gradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.cream)};${colorTag(Palette.violet)};${colorTag(Palette.mint)} individual=true moveDir=right moveSpeed=.45 rot=10>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "rainbow") {
		return `<anim=wiggle freq=1.5 amp=.32 offset=.16 rot=true loop=true><shiny=true color=${colorTag(Palette.white)} rate=.48 chance=40 lifetime=.4,.78 startSize=.14,.24 endSize=0,0 velY=-.45,-.12 velX=-.28,.28><shadow=true color=${colorTag(Color3.fromRGB(24, 14, 42))} offset=.05,.2 trans=.3><stroke=true color=${colorTag(Palette.white)} thickness=.04 trans=.28><rainbow=true freq=.65 offset=.15>${body}</rainbow></stroke></shadow></shiny></anim>`;
	}
	if (kind === "toxic") {
		return `<anim=spiral freq=1.4 amp=.26 offset=.2 rot=true loop=true><shake=true maxOffset=.016 maxRot=1.2 loop=true freq=5 dur=0><shiny=true color=${colorTag(Color3.fromRGB(165, 255, 75))} rate=.48 chance=42 lifetime=.45,.85 startSize=.15,.25 endSize=0,0 velY=-.55,-.15 velX=-.25,.25><shadow=true color=${colorTag(Color3.fromRGB(10, 32, 6))} offset=.05,.2 trans=.28><stroke=true color=${colorTag(Color3.fromRGB(14, 38, 8))} thickness=.044><strokeGradient=true colors=${colorTag(Color3.fromRGB(95, 245, 38))};${colorTag(Color3.fromRGB(210, 255, 115))};${colorTag(Palette.mint)} individual=true moveDir=right moveSpeed=.75><gradient=true colors=${colorTag(Color3.fromRGB(95, 245, 38))};${colorTag(Color3.fromRGB(210, 255, 115))};${colorTag(Color3.fromRGB(52, 188, 26))};${colorTag(Palette.mint)} individual=true moveDir=right moveSpeed=.58 rot=84>${body}</gradient></strokeGradient></stroke></shadow></shiny></shake></anim>`;
	}
	if (kind === "matrix") {
		return `<italic=true><anim=slide dir=down offset=.18 rot=0 loop=true><decode=true dur=.22 freq=6 loop=true><shadow=true color=${colorTag(Color3.fromRGB(4, 22, 8))} offset=.04,.18 trans=.28><stroke=true color=${colorTag(Color3.fromRGB(6, 28, 10))} thickness=.042><gradient=true colors=${colorTag(Color3.fromRGB(85, 255, 125))};${colorTag(Palette.green)};${colorTag(Color3.fromRGB(195, 255, 205))};${colorTag(Color3.fromRGB(24, 150, 54))} individual=true moveDir=right moveSpeed=.95 rot=90>${body}</gradient></stroke></shadow></decode></anim></italic>`;
	}
	if (kind === "glow") {
		return `<anim=pulsewave freq=1.25 amp=.24 offset=.18 rot=false loop=true><shiny=true color=${colorTag(Palette.white)} rate=.48 chance=42 lifetime=.5,.95 startSize=.16,.26 endSize=0,0 velY=-.32,.32 velX=-.32,.32><shadow=true color=${colorTag(Color3.fromRGB(88, 62, 18))} offset=.04,.18 trans=.32><stroke=true color=${colorTag(Color3.fromRGB(255, 236, 190))} thickness=.055 trans=.16><gradient=true colors=${colorTag(Color3.fromRGB(255, 252, 230))};${colorTag(Color3.fromRGB(255, 224, 155))};${colorTag(Palette.white)} individual=false moveDir=right moveSpeed=.46 rot=22>${body}</gradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "neon") {
		return `<anim=pulsewave freq=1.65 amp=.28 offset=.15 rot=true loop=true><shadow=true color=${colorTag(Color3.fromRGB(6, 42, 32))} offset=.05,.2 trans=.26><stroke=true color=${colorTag(Palette.mint)} thickness=.052><strokeGradient=true colors=${colorTag(Palette.mint)};${colorTag(Palette.white)};${colorTag(Palette.cyan)} individual=false moveDir=right moveSpeed=.8><gradient=true colors=${colorTag(Color3.fromRGB(215, 255, 242))};${colorTag(Palette.mint)};${colorTag(Palette.cyan)};${colorTag(Palette.white)} individual=false moveDir=right moveSpeed=.58 rot=8>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "sparkle") {
		return `<anim=bounce dir=up offset=.18 exp=1.35 loop=true><shiny=true color=${colorTag(Palette.white)} rate=.88 chance=58 lifetime=.38,.72 startSize=.18,.3 endSize=0,0 velY=-.85,-.35 velX=-.45,.45 startPosY=-.18,.18 rotVel=-80,80><shadow=true color=${colorTag(Color3.fromRGB(62, 34, 8))} offset=.05,.18 trans=.3><stroke=true color=${colorTag(Color3.fromRGB(76, 44, 10))} thickness=.04 trans=.22><gradient=true colors=${colorTag(Color3.fromRGB(255, 236, 152))};${colorTag(Palette.mango)};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(255, 192, 82))} individual=false moveDir=right moveSpeed=.64 rot=14>${body}</gradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "shimmer") {
		return `<anim=wiggle freq=1.15 amp=.2 offset=.16 rot=false loop=true><shiny=true color=${colorTag(Palette.white)} rate=.36 chance=34 lifetime=.45,.85 startSize=.14,.22 endSize=0,0 velY=-.25,.25 velX=-.25,.25><shadow=true color=${colorTag(Color3.fromRGB(28, 34, 46))} offset=.04,.16 trans=.36><stroke=true color=${colorTag(Color3.fromRGB(42, 50, 64))} thickness=.036 trans=.24><gradient=true colors=${colorTag(Palette.creamSoft)};${colorTag(Palette.white)};${colorTag( Color3.fromRGB(210, 232, 255))};${colorTag(Palette.cream)} individual=false moveDir=right moveSpeed=.65 rot=18>${body}</gradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "pulse") {
		return `<anim=grow startScale=.82 exp=1.25 loop=true><shadow=true color=${colorTag(Color3.fromRGB(24, 10, 46))} offset=.05,.2 trans=.3><stroke=true color=${colorTag(lighten(Palette.violet, 0.3))} thickness=.045 trans=.18><strokeGradient=true colors=${colorTag(Palette.violet)};${colorTag(Palette.pink)};${colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=.65><gradient=true colors=${colorTag(Palette.violet)};${colorTag(Palette.pink)};${colorTag(Palette.cyan)};${colorTag(Palette.violet)} individual=false moveDir=right moveSpeed=.48 spacing=.14>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "void") {
		return `<anim=orbit freq=.85 amp=.36 offset=.24 rot=true loop=true><shadow=true color=${colorTag(Color3.fromRGB(8, 0, 18))} offset=.08,.32 trans=.18><stroke=true color=${colorTag(Color3.fromRGB(18, 6, 32))} thickness=.058><strokeGradient=true colors=${colorTag(Color3.fromRGB(185, 115, 255))};${colorTag(Color3.fromRGB(48, 12, 82))};${colorTag(Palette.violet)} individual=true moveDir=left moveSpeed=.55><gradient=true colors=${colorTag(Color3.fromRGB(170, 95, 250))};${colorTag(Color3.fromRGB(58, 18, 98))};${colorTag(Palette.violet)};${colorTag(Color3.fromRGB(220, 165, 255))} individual=false moveDir=right moveSpeed=.38 rot=42>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "plasma") {
		return `<anim=spiral freq=1.65 amp=.32 offset=.16 rot=true loop=true><shake=true maxOffset=.024 maxRot=2.4 loop=true freq=8 dur=0><shiny=true color=${colorTag(Palette.pink)} rate=.68 chance=44 lifetime=.3,.55 startSize=.18,.3 endSize=0,0 velX=-.75,.75 velY=-.48,.48><shadow=true color=${colorTag(Color3.fromRGB(44, 10, 40))} offset=.05,.2 trans=.26><stroke=true color=${colorTag(Color3.fromRGB(52, 12, 48))} thickness=.044><gradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.violet)};${colorTag(Palette.coral)};${colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=1.05 rot=16>${body}</gradient></stroke></shadow></shiny></shake></anim>`;
	}
	if (kind === "chrome") {
		return `<anim=pendulum freq=1.2 amp=.2 offset=.18 rot=true loop=true><shadow=true color=${colorTag(Color3.fromRGB(32, 36, 44))} offset=.06,.22 trans=.35><stroke=true color=${colorTag(Color3.fromRGB(28, 32, 40))} thickness=.042><strokeGradient=true colors=${colorTag(Palette.white)};${colorTag(Color3.fromRGB(110, 120, 138))};${colorTag(Palette.white)} individual=false moveDir=right moveSpeed=.65><gradient=true colors=${colorTag(Palette.muted)};${colorTag(Palette.creamSoft)};${colorTag(Palette.white)};${colorTag(Palette.creamSoft)};${colorTag(Color3.fromRGB(90, 96, 108))} individual=false moveDir=right moveSpeed=.52 rot=78>${body}</gradient></strokeGradient></stroke></shadow></anim>`;
	}
	if (kind === "phantom") {
		return `<italic=true><anim=orbit freq=.92 amp=.28 offset=.22 rot=true loop=true><trans=.12 tweenDur=1.2 tweenFrom=.48 loopTween=true><shadow=true color=${colorTag(Color3.fromRGB(22, 8, 38))} offset=.07,.26 trans=.28><stroke=true color=${colorTag(Color3.fromRGB(30, 10, 48))} thickness=.04><gradient=true colors=${colorTag(Color3.fromRGB(175, 135, 255))};${colorTag(Color3.fromRGB(232, 218, 255))};${colorTag(Palette.violet)};${colorTag(Color3.fromRGB(125, 195, 255))} individual=false moveDir=right moveSpeed=.34 rot=82>${body}</gradient></stroke></shadow></trans></anim></italic>`;
	}
	if (kind === "eclipse") {
		return `<anim=pulsewave freq=1.15 amp=.3 offset=.18 rot=true loop=true><shiny=true color=${colorTag(Color3.fromRGB(255, 224, 150))} rate=.44 chance=38 lifetime=.5,.95 startSize=.16,.26 endSize=0,0 velX=-.32,.32 velY=-.32,.32><shadow=true color=${colorTag(Color3.fromRGB(255, 175, 70))} offset=.04,.18 trans=.28><stroke=true color=${colorTag(Color3.fromRGB(255, 214, 140))} thickness=.058><strokeGradient=true colors=${colorTag(Color3.fromRGB(255, 155, 55))};${colorTag(Color3.fromRGB(255, 248, 215))};${colorTag(Color3.fromRGB(255, 155, 55))} individual=false moveDir=right moveSpeed=.45><gradient=true colors=${colorTag(Color3.fromRGB(36, 24, 52))};${colorTag(Color3.fromRGB(78, 52, 96))};${colorTag(Color3.fromRGB(255, 214, 140))} individual=false moveDir=right moveSpeed=.36 rot=24>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "nebula") {
		return `<anim=spiral freq=.95 amp=.32 offset=.22 rot=true loop=true><shiny=true color=${colorTag(Color3.fromRGB(255, 185, 240))} rate=.46 chance=40 lifetime=.55,1.05 startSize=.15,.26 endSize=0,0 velX=-.28,.28 velY=-.28,.28><shadow=true color=${colorTag(Color3.fromRGB(18, 8, 38))} offset=.06,.24 trans=.26><stroke=true color=${colorTag(Color3.fromRGB(26, 10, 48))} thickness=.044><strokeGradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.violet)};${colorTag(Palette.cyan)} individual=true moveDir=left moveSpeed=.55><gradient=true colors=${colorTag(Palette.pink)};${colorTag(Palette.violet)};${colorTag(Color3.fromRGB(85, 120, 255))};${colorTag(Color3.fromRGB(255, 165, 235))} individual=false moveDir=left moveSpeed=.32 spacing=.16 rot=26>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "molten") {
		return `<anim=bounce dir=down offset=.16 exp=2.0 loop=true><shiny=true color=${colorTag(Color3.fromRGB(255, 200, 90))} rate=.48 chance=40 lifetime=.55,1.0 startSize=.16,.26 endSize=0,0 velY=.35,.85 startPosY=.25,.45 accelY=.5,.9><shadow=true color=${colorTag(Color3.fromRGB(54, 10, 4))} offset=.05,.22 trans=.24><stroke=true color=${colorTag(Color3.fromRGB(52, 10, 4))} thickness=.048><strokeGradient=true colors=${colorTag(Color3.fromRGB(255, 118, 36))};${colorTag(Color3.fromRGB(255, 230, 125))};${colorTag(Color3.fromRGB(185, 36, 10))} individual=true moveDir=right moveSpeed=.6><gradient=true colors=${colorTag(Color3.fromRGB(155, 26, 8))};${colorTag(Color3.fromRGB(255, 120, 40))};${colorTag(Color3.fromRGB(255, 230, 125))};${colorTag(Color3.fromRGB(235, 68, 16))} individual=false moveDir=right moveSpeed=.52 rot=86>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "circuit") {
		return `<anim=pulsewave freq=1.8 amp=.22 offset=.14 rot=false loop=true><decode=true dur=.22 freq=6 loop=true><shadow=true color=${colorTag(Color3.fromRGB(6, 28, 22))} offset=.05,.18 trans=.28><stroke=true color=${colorTag(Color3.fromRGB(10, 40, 30))} thickness=.042><strokeGradient=true colors=${colorTag(Palette.mint)};${colorTag(Palette.cyan)};${colorTag(Palette.white)} individual=true moveDir=right moveSpeed=1.1><gradient=true colors=${colorTag(Palette.mint)};${colorTag(Color3.fromRGB(24, 150, 112))};${colorTag(Color3.fromRGB(205, 255, 238))};${colorTag(Palette.cyan)} individual=true moveDir=right moveSpeed=1.2>${body}</gradient></strokeGradient></stroke></shadow></decode></anim>`;
	}
	if (kind === "comet") {
		return `<italic=true><anim=slide dir=up offset=.2 rot=-4 loop=true><shiny=true color=${colorTag(Palette.white)} rate=.68 chance=50 lifetime=.38,.75 startSize=.16,.28 endSize=0,0 velX=-1.35,-.75 velY=-.1,.1><shadow=true color=${colorTag(Color3.fromRGB(12, 32, 74))} offset=-.08,.18 trans=.26><stroke=true color=${colorTag(Color3.fromRGB(14, 34, 78))} thickness=.044><strokeGradient=true colors=${colorTag(Palette.cyan)};${colorTag(Palette.white)};${colorTag(Palette.blue)} individual=false moveDir=right moveSpeed=.95><gradient=true colors=${colorTag(Color3.fromRGB(48, 102, 215))};${colorTag(Palette.cyan)};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(165, 235, 255))} individual=false moveDir=right moveSpeed=.88 rot=-8>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim></italic>`;
	}
	if (kind === "starforge") {
		return `<anim=pulsewave freq=1.65 amp=.38 offset=.15 rot=true loop=true><shiny=true color=${colorTag(Color3.fromRGB(255, 244, 195))} rate=.85 chance=56 lifetime=.42,.88 startSize=.2,.34 endSize=0,0 velX=-.5,.5 velY=-.6,-.12 rotVel=-90,90><shadow=true color=${colorTag(Color3.fromRGB(64, 28, 12))} offset=.06,.26 trans=.2><stroke=true color=${colorTag(Color3.fromRGB(255, 224, 150))} thickness=.052><strokeGradient=true colors=${colorTag(Palette.mango)};${colorTag(Palette.white)};${colorTag(Palette.cyan)};${colorTag(Palette.pink)} individual=true moveDir=right moveSpeed=.75><gradient=true colors=${colorTag(Color3.fromRGB(255, 196, 88))};${colorTag(Color3.fromRGB(255, 252, 228))};${colorTag(Palette.cyan)};${colorTag(Palette.pink)};${colorTag(Color3.fromRGB(255, 196, 88))} individual=false moveDir=right moveSpeed=.68 rot=20>${body}</gradient></strokeGradient></stroke></shadow></shiny></anim>`;
	}
	if (kind === "bounce-in") {
		return `<anim=bounce dir=up offset=.42 exp=1.55 loop=true><shadow=true color=${colorTag(Color3.fromRGB(54, 24, 6))} offset=.05,.2 trans=.3><stroke=true color=${colorTag(Color3.fromRGB(68, 34, 8))} thickness=.04><gradient=true colors=${colorTag(Palette.mango)};${colorTag(Color3.fromRGB(255, 236, 165))};${colorTag(Palette.coral)} individual=true moveDir=right moveSpeed=.75 rot=90>${body}</gradient></stroke></shadow></anim>`;
	}
	if (kind === "blur-resolve") {
		return `<anim=grow startScale=.86 exp=1.35 loop=true><decode=true dur=.16 freq=7 loop=true><shadow=true color=${colorTag(Color3.fromRGB(26, 32, 42))} offset=.05,.18 trans=.32><stroke=true color=${colorTag(Color3.fromRGB(38, 44, 54))} thickness=.04><gradient=true colors=${colorTag(Palette.cream)};${colorTag(Palette.white)};${colorTag(Color3.fromRGB(190, 220, 255))};${colorTag(Palette.creamSoft)} individual=false moveDir=right moveSpeed=.52>${body}</gradient></stroke></shadow></decode></anim>`;
	}
		return `<color=${colorTag(accent)}>${body}</color>`;
	return `<color=${colorTag(accent)}>${body}</color>`;
}

function buildMarkup(kind: string, text: string, preview: boolean): string {
	const body = safeText(text);
	const step = preview ? REVEAL_STAGGER : 0;
	return `<interval=${step}>${buildKindMarkup(kind, body)}</interval>`;
}

interface MarkupValue {
	value: unknown;
}
interface HyperTextInstance {
	UpdateDefaultMarkups(markups: unknown): void;
	Render(text: string, a: boolean, b: boolean, c: boolean): void;
	Destroy?: unknown;
}
interface HyperTextModule {
	new: (this: void, host: Instance) => HyperTextInstance;
	newMarkups: (this: void) => Record<string, MarkupValue>;
	DELETE: unknown;
}

let cachedModule: HyperTextModule | undefined;
let loadFailed = false;
let pendingWarned = false;

function resolveModuleScript(node: Instance): ModuleScript | undefined {
	if (node.IsA("ModuleScript")) {
		return node;
	}
	const initChild = node.FindFirstChild("init");
	if (initChild !== undefined && initChild.IsA("ModuleScript")) {
		return initChild;
	}
	return undefined;
}

function loadHyperTextModule(): HyperTextModule | undefined {
	if (cachedModule !== undefined) {
		return cachedModule;
	}
	if (loadFailed) {
		return undefined;
	}
	const astral = ReplicatedStorage.FindFirstChild("AstralForge");
	const vendor = astral?.FindFirstChild("Vendor");
	const node = vendor?.FindFirstChild("HyperText");
	if (node === undefined) {
		if (!pendingWarned) {
			pendingWarned = true;
			ClientLog.warnEvery(
				"hypertext-root",
				15,
				"hypertext",
				"ReplicatedStorage.AstralForge.Vendor.HyperText is not replicated yet",
			);
		}
		return undefined;
	}
	const moduleScript = resolveModuleScript(node);
	if (moduleScript === undefined) {
		ClientLog.warn("hypertext", `HyperText is a ${node.ClassName}, not a ModuleScript`);
		loadFailed = true;
		return undefined;
	}
	const [ok, result] = pcall(() => require(moduleScript));
	if (!ok || result === undefined || !typeIs((result as { new?: unknown }).new, "function")) {
		ClientLog.warn("hypertext", `couldn't load HyperText: ${tostring(result)}`);
		loadFailed = true;
		return undefined;
	}
	cachedModule = result as HyperTextModule;
	pendingWarned = false;
	return cachedModule;
}

interface AnimatedTitleProps {
	text?: string;
	fx?: string;
	size?: number;
	reducedMotion?: boolean;
	position?: UDim2;
	sizeConstraint?: UDim2;
	// May be a binding (chat rows fade in); HyperText itself only ever gets a number.
	transparency?: number | React.Binding<number>;
	align?: Enum.TextXAlignment;
	preview?: boolean;
}

function AnimatedTitle(props: AnimatedTitleProps) {
	const text = props.text ?? "";
	const fx = props.fx;
	const size = props.size ?? 13;
	const reducedMotion = props.reducedMotion === true;
	const position = props.position ?? UDim2.fromOffset(0, 0);
	const sizeConstraint = props.sizeConstraint ?? new UDim2(1, 0, 0, size + 4);
	const transparency = props.transparency ?? 0;
	const fadeBinding = typeIs(transparency, "number") ? undefined : transparency;
	// Bindings resolve to 0 (where every fade ends) so the render effect keys on a
	// stable number instead of a fresh binding object each parent render.
	const markupTrans = fadeBinding === undefined ? markupNumber(transparency, 0) : 0;
	const align = props.align ?? Enum.TextXAlignment.Left;
	const preview = props.preview === true;
	const kind = parseFx(fx);
	const accent = kind !== undefined ? FX_ACCENT[kind] : Palette.creamSoft;
	const live = kind !== undefined && !reducedMotion && text !== "";
	const hostRef = React.useRef<Frame>();
	const [ready, setReady] = React.useState(false);
	const horizAlign =
		align === Enum.TextXAlignment.Center
			? Enum.HorizontalAlignment.Center
			: align === Enum.TextXAlignment.Right
				? Enum.HorizontalAlignment.Right
				: Enum.HorizontalAlignment.Left;
	React.useEffect(() => {
		setReady(false);
		if (!live) {
			return undefined;
		}
		const host = hostRef.current;
		if (host === undefined) {
			return undefined;
		}
		const mod = loadHyperTextModule();
		if (mod === undefined) {
			return undefined;
		}
		host.ClearAllChildren();
		let instance: HyperTextInstance | undefined;
		let sizeConn: RBXScriptConnection | undefined;
		let rendered = false;
		const runRender = () => {
			if (rendered || host.Parent === undefined) {
				return;
			}
			if (host.AbsoluteSize.X <= 0 || host.AbsoluteSize.Y <= 0) {
				return;
			}
			rendered = true;
			if (sizeConn !== undefined) {
				sizeConn.Disconnect();
				sizeConn = undefined;
			}
			const [ok, err] = pcall(() => {
				const markups = mod.newMarkups();
				markups.font.value = "rbxasset://fonts/families/BuilderSans.json";
				markups.weight.value = Enum.FontWeight.ExtraBold;
				markups.size.value = markupNumber(size, 13);
				markups.color.value = accent;
				markups.trans.value = markupNumber(markupTrans, 0);
				markups.horizontalAlignment.value = horizAlign;
				markups.verticalAlignment.value = Enum.VerticalAlignment.Center;
				markups.ZIndex.value = 2;
				markups.interval.value = preview ? REVEAL_STAGGER : 0;
				markups.anim.value = mod.DELETE;
				const rich = mod.new(host);
				rich.UpdateDefaultMarkups(markups);
				rich.Render(buildMarkup(kind!, text, preview), false, false, false);
				instance = rich;
			});
			if (!ok) {
				ClientLog.warnEvery(`hypertext-${kind}`, 10, "hypertext", `render failed for ${kind}: ${tostring(err)}`);
				host.ClearAllChildren();
				return;
			}
			setReady(true);
		};
		runRender();
		if (!rendered) {
			sizeConn = host.GetPropertyChangedSignal("AbsoluteSize").Connect(runRender);
		}
		return () => {
			rendered = true;
			if (sizeConn !== undefined) {
				sizeConn.Disconnect();
				sizeConn = undefined;
			}
			setReady(false);
			pcall(() => {
				if (instance !== undefined && typeIs(instance.Destroy, "function")) {
					(instance as unknown as { Destroy(): void }).Destroy();
				}
				host.ClearAllChildren();
			});
		};
	}, [live, kind, text, size, markupTrans, horizAlign, preview]);
	return (
		<frame
			Size={sizeConstraint}
			Position={position}
			BackgroundTransparency={1}
			BorderSizePixel={0}
			ZIndex={2}
			ClipsDescendants={false}
		>
			<frame
				ref={hostRef}
				Size={UDim2.fromScale(1, 1)}
				BackgroundTransparency={1}
				BorderSizePixel={0}
				ClipsDescendants={false}
				Visible={fadeBinding === undefined ? live : fadeBinding.map((amount) => live && amount < 0.5)}
				ZIndex={2}
			/>
			{!live || !ready ? (
				<textlabel
					Size={UDim2.fromScale(1, 1)}
					BackgroundTransparency={1}
					BorderSizePixel={0}
					Text={text}
					TextColor3={accent}
					TextSize={size}
					TextTransparency={transparency}
					FontFace={Font.fromEnum(Enum.Font.BuilderSansExtraBold)}
					TextXAlignment={align}
					TextYAlignment={Enum.TextYAlignment.Center}
					TextTruncate={Enum.TextTruncate.AtEnd}
					TextScaled={true}
					ZIndex={2}
				>
					<uitextsizeconstraint MinTextSize={math.max(9, size - 4)} MaxTextSize={size} />
				</textlabel>
			) : undefined}
		</frame>
	);
}

function AnimatedTitlePreview(props: {
	text?: string;
	fx?: string;
	size?: number;
	reducedMotion?: boolean;
	transparency?: number;
	preview?: boolean;
}) {
	return (
		<AnimatedTitle
			text={props.text}
			fx={props.fx}
			size={props.size ?? 15}
			reducedMotion={props.reducedMotion === true}
			transparency={props.transparency ?? 0}
			align={Enum.TextXAlignment.Center}
			preview={props.preview === true}
		/>
	);
}

export { parseFx, titleFxAccent, darkTitlePlate, titleTier, AnimatedTitle, AnimatedTitlePreview, TITLE_FX_KINDS };
