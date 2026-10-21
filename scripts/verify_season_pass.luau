--!strict
-- Season Pass lane: premium rewards derive from the tier, the save bag gains PremiumClaims by
-- default, and the claim action is wired end to end.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function load(path: string, name: string): any
	return (luau.load(fs.readFile(path), { debugName = name }) :: any)()
end
local P = load("out/Shared/AstralForge/Shared/SeasonPremium.luau", "SeasonPremium")
assert(P.PassKey == "SeasonPass")
for tier = 1, 300 do
	local r = P.Reward(tier)
	assert(type(r) == "table" and next(r) ~= nil, "empty premium reward at tier " .. tier)
	if tier % 10 == 0 then
		assert((r.Cores or 0) >= 1 and r.Boost == "Hyperdrive", "tier " .. tier .. " should pay cores")
	elseif tier % 5 == 0 then
		assert(r.Keys and r.Keys.ForgeCrate == 1, "tier " .. tier .. " should pay a crate key")
	else
		assert(r.Cores == nil and r.Keys == nil, "small tiers stay small")
	end
end

local C = load("out/Server/AstralForge/Modules/CommandMath.luau", "CommandMath")
local fresh = C.Ensure(nil, "S1")
assert(type(fresh.PremiumClaims) == "table", "new bags get PremiumClaims")
local old = C.Ensure({ XP = 10, SeasonId = "S1", SeasonClaims = { ["1"] = true } }, "S1")
assert(type(old.PremiumClaims) == "table" and old.SeasonClaims["1"] == true, "old saves keep claims and gain PremiumClaims")

local function has(path: string, needle: string)
	assert(fs.readFile(path):find(needle, 1, true), path .. " is missing " .. needle)
end
has("src/Server/AstralForge/DataTemplate.ts", "PremiumClaims: {}")
has("src/Shared/AstralForge/Shared/Protocol.ts", 'ClaimSeasonPremium: "ClaimSeasonPremium"')
has("src/Server/AstralForge/Services/GameService.ts", "Protocol.Actions.ClaimSeasonPremium")
has("src/Server/AstralForge/Services/Security/RemoteFirewall.ts", "Protocol.Actions.ClaimSeasonPremium")
has("src/Server/AstralForge/Services/Gameplay/Progression.ts", "command.PremiumClaims = {}")
has("src/Shared/AstralForge/Shared/SharedData/MonetizationConfig.ts", 'Key: "SeasonPass"')
print("verify_season_pass: ok")
