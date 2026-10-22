--!strict
-- Title rarity tiers & looks: every effect has a tier across all 5 tiers, titles have zero
-- background plates/underlays/fog/mark highlights, and all 37 looks render through FancyText
-- (UiCore/titleFx) with the 8 per-character animation modes and a per-character UIScale.
local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")

local host = fs.readFile("src/Client/AstralForge/ReactHosts.luau#TitleLooks")
local kinds = luau.load("return " .. assert(host:match("local TITLE_FX_KINDS = (%b{})")))() :: { string }
local tiers = luau.load("return " .. assert(host:match("local TITLE_TIER = (%b{})")))() :: { [string]: string }
local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

local used = {}
local mapped = 0
for _, kind in kinds do
	local tier = tiers[kind]
	assert(tier ~= nil and RANK[tier] ~= nil, "title effect has no tier: " .. kind)
	used[tier] = true
end
for kind in tiers do
	assert(table.find(kinds, kind), "tier mapped for an unknown effect: " .. kind)
	mapped += 1
end
assert(mapped == #kinds, "every effect is tiered exactly once")
for tier in RANK do
	assert(used[tier], "tier is never used: " .. tier)
end

-- Verify zero background effects on titles
for _, forbidden in {
	"TitleTierUnderlay",
	"KineticTitleCanvas",
	"<fog=",
	"<mark=",
} do
	assert(not string.find(host, forbidden, 1, true), "forbidden background effect found in TitleLooks: " .. forbidden)
end

-- Verify TitleLooks registers each look with FancyText and keeps every authored layer
for _, needle in {
	"TitleFx.register(kind, prefix, still)",
	"FancyTitle",
	"ClipsDescendants = false",
	"<anim=wiggle",
	"<anim=bounce",
	"<anim=slide",
	"<anim=grow",
	"<anim=orbit",
	"<anim=pendulum",
	"<anim=spiral",
	"<anim=pulsewave",
	"<strokeGradient=true",
	"<shadow=true",
	"<rainbow=true",
	"<decode=true",
	"<shake=true",
} do
	assert(string.find(host, needle, 1, true), "TitleLooks missing required markup/wiring: " .. needle)
end

for dir in string.gmatch(host, "moveDir=(%a+)") do
	assert(dir == "left" or dir == "right", "title gradient moveDir must be left or right, got " .. dir)
end

-- Verify the FancyText title effect keeps the per-character animation modes and layers
local titleFx = fs.readFile("src/Client/AstralForge/UiCore/titleFx.ts")
for _, needle in {
	'new Instance("UIScale")',
	'anim.kind === "wiggle"',
	'anim.kind === "orbit"',
	'anim.kind === "pendulum"',
	'anim.kind === "spiral"',
	'anim.kind === "pulsewave"',
	'anim.kind === "slide"',
	'anim.kind === "bounce"',
	'anim.kind === "grow"',
	'new Instance("UIStroke")',
	'new Instance("UIGradient")',
	"look.shake",
	"look.decode",
	"look.sparks",
	"look.rainbow",
	"RenderStepped.Connect(step)",
	"driver.Disconnect()",
} do
	assert(string.find(titleFx, needle, 1, true), "titleFx missing: " .. needle)
end

local page = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau")
assert(string.find(page, "string.upper(titleTier(props.fx))", 1, true), "title cards show the rarity tier")
assert(not string.find(page, "))} EFFECT`", 1, true), "generic EFFECT label removed")

print(`[TEST] title tiers & looks: {#kinds} effects across 5 tiers, 8 per-char anim modes, zero background effects`)
