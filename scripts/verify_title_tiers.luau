--!strict
-- Title rarity tiers & HyperText engine: every effect has a tier across all 5 tiers,
-- titles have zero background plates/underlays/fog/mark highlights, and Vendor.HyperText
-- drives all 37 title effects with 8 per-character animation modes and floating-point UIScale.
local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")

local host = fs.readFile("src/Client/AstralForge/ReactHosts.luau#HyperTextHost")
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
	assert(not string.find(host, forbidden, 1, true), "forbidden background effect found in HyperTextHost: " .. forbidden)
end

-- Verify HyperTextHost mounts Vendor.HyperText and uses all 8 per-character animation modes
for _, needle in {
	"local function loadHyperTextModule()",
	"local markups = mod.newMarkups()",
	"local rich = mod.new(host)",
	"rich:UpdateDefaultMarkups(markups)",
	"rich:Render(buildMarkup(kind, text, preview), false, false, false)",
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
	assert(string.find(host, needle, 1, true), "HyperTextHost missing required markup/wiring: " .. needle)
end

for dir in string.gmatch(host, "moveDir=(%a+)") do
	assert(dir == "left" or dir == "right", "HyperText gradient moveDir must be left or right, got " .. dir)
end

-- Verify Vendor.HyperText engine upgrades
local hyperInit = fs.readFile("src/Shared/AstralForge/Vendor/HyperText/init.luau")
assert(string.find(hyperInit, "local transformUpdaters", 1, true), "HyperText init must flush transformUpdaters every frame")
assert(not string.find(hyperInit, "ClipsDescendants = true", 1, true), "HyperText rows/containers must not clip per-character animations")

local applyAnim = fs.readFile("src/Shared/AstralForge/Vendor/HyperText/Internal/Helpers/ApplyAnimation.luau")
for _, needle in {
	"ensureCharScale",
	'FindFirstChildOfClass("UIScale")',
	'value == "orbit"',
	'value == "pendulum"',
	'value == "spiral"',
	'value == "pulsewave"',
} do
	assert(string.find(applyAnim, needle, 1, true), "ApplyAnimation missing revamped feature: " .. needle)
end

local page = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau")
assert(string.find(page, "string.upper(titleTier(props.fx))", 1, true), "title cards show the rarity tier")
assert(not string.find(page, "))} EFFECT`", 1, true), "generic EFFECT label removed")

print(`[TEST] title tiers & HyperText: {#kinds} effects across 5 tiers, 8 per-char anim modes, zero background effects`)
