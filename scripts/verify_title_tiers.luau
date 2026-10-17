--!strict
-- Title rarity tiers: every effect has exactly one tier, all five tiers are used, the treatments
-- scale with tier, one shared 30 Hz clock drives them, and reduced motion keeps them still.
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

for _, needle in {
	"local function useTierClock(active)",
	"tierConnection = RunService.Heartbeat:Connect",
	"if sinceTick >= 1 / 30 then",
	"tierConnection:Disconnect()",
	"local animate = props.animate == true and rank >= 3",
	"children.sheen",
	'children["spark" .. index]',
	"React.createElement(TitleTierUnderlay, {",
	"animate = live,",
} do
	assert(string.find(host, needle, 1, true), "tier treatment wiring missing: " .. needle)
end
local _, connects = string.gsub(host, "Heartbeat:Connect", "")
assert(connects == 1, "tier treatments share one Heartbeat connection, got " .. connects)

for dir in string.gmatch(host, "moveDir=(%a+)") do
	assert(dir == "left" or dir == "right", "HyperText gradient moveDir must be left or right, got " .. dir)
end

local page = fs.readFile("src/Client/AstralForge/pages/PagesSystem.luau")
assert(string.find(page, "string.upper(titleTier(props.fx))", 1, true), "title cards show the rarity tier")
assert(not string.find(page, "))} EFFECT`", 1, true), "generic EFFECT label removed")

print(`[TEST] title tiers: {#kinds} effects across 5 tiers, one shared clock, reduced-motion still`)
