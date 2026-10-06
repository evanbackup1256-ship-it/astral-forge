--!strict
-- Forge Level rewards (SharedData#LevelRewards) and their server wiring:
--  * every level pays flux, stardust and a Forge Surge; later levels pay more,
--  * the surge stacks with a cap, mastery grows per level,
--  * old saves are caught up without back-pay, halfway pays once per level,
--  * ETA text, and Economy/ServerServices/DataTemplate use it all.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Rewards = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#LevelRewards"), { chunkName = "LevelRewards" })() :: any
local Levels = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#ForgeLevels"), { chunkName = "ForgeLevels" })() :: any

local previous = nil
for _, def in Levels.ladder() do
	local reward = Rewards.forLevel(def.Level, def.Tier)
	assert(reward.FluxSeconds > 0 and reward.MinFlux > 0 and reward.Stardust > 0, "level " .. def.Level .. " pays something")
	assert(reward.SurgeMultiplier > 1 and reward.SurgeMultiplier <= Rewards.SURGE_MAX_MULTIPLIER, "surge in range")
	assert(reward.SurgeSeconds > 0 and reward.SurgeSeconds <= 900, "surge length in range")
	if previous ~= nil then
		assert(reward.FluxSeconds >= previous.FluxSeconds and reward.Stardust >= previous.Stardust, "later levels pay at least as much")
	end
	previous = reward
end
assert(Rewards.mastery(1) == 0 and math.abs(Rewards.mastery(18) - 0.34) < 1e-9, "mastery: +2% per level past 1")

-- Surge stacking
local now = 1000
local surge = Rewards.mergeSurge(nil, now, 1.25, 300)
assert(surge.Multiplier == 1.25 and surge.EndsAt == 1300, "first surge")
surge = Rewards.mergeSurge(surge, now + 100, 1.3, 300)
assert(surge.Multiplier == 1.3 and surge.EndsAt == 1600, "time adds on, stronger multiplier wins")
surge = Rewards.mergeSurge(surge, now, 1.1, 5000)
assert(surge.EndsAt == now + Rewards.SURGE_CAP_SECONDS and surge.Multiplier == 1.3, "capped, weaker multiplier doesn't lower it")
assert(Rewards.surgeMultiplier(surge, now) == 1.3 and Rewards.surgeMultiplier(surge, surge.EndsAt) == 1, "surge ends")
assert(Rewards.surgeMultiplier({ Multiplier = 99, EndsAt = now + 10 }, now) == Rewards.SURGE_MAX_MULTIPLIER, "tampered multipliers clamp")

-- Owed levels
local owed, settled = Rewards.owed(-1, 12)
assert(#owed == 0 and settled == 12, "an old save is caught up without back-pay")
owed, settled = Rewards.owed(4, 7)
assert(#owed == 3 and owed[1] == 5 and owed[3] == 7 and settled == 7, "levels 5-7 owed")
owed, settled = Rewards.owed(7, 7)
assert(#owed == 0 and settled == 7, "nothing owed twice")
owed, settled = Rewards.owed(9, 7)
assert(#owed == 0 and settled == 9, "never goes backwards")

-- Halfway
assert(Rewards.halfwayDue(4, 5, 50, 100), "half way to 5 pays")
assert(not Rewards.halfwayDue(4, 5, 49, 100), "not before half")
assert(not Rewards.halfwayDue(5, 5, 90, 100), "only once per level")
assert(not Rewards.halfwayDue(-1, 5, 90, 100), "uninitialised saves don't pay")
assert(not Rewards.halfwayDue(4, nil, 90, 100), "no next level, no checkpoint")

-- ETA
assert(Rewards.eta("LifetimeCash", 600, 10) == 60, "eta")
assert(Rewards.eta("Rebirths", 1, 10) == nil and Rewards.eta("LifetimeCash", 10, 0) == nil, "no eta when it can't be known")
assert(Rewards.etaText(30) == "30s" and Rewards.etaText(125) == "2m" and Rewards.etaText(3 * 3600 + 300) == "3h 5m" and Rewards.etaText(200000) == "2d", "eta text")

-- Wiring
local economy = fs.readFile("src/Server/AstralForge/Modules/EconomyMath.luau#Economy")
assert(string.find(economy, "LevelRewards.mastery(", 1, true) and string.find(economy, "LevelRewards.surgeMultiplier(progression.Surge", 1, true), "production includes mastery and surge")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "function GameService:_settleProgression", 1, true), "server settles rewards")
assert(string.find(server, 'Type = "LevelReward"', 1, true) and string.find(server, 'Type = "LevelHalfway"', 1, true), "server announces them")
local template = fs.readFile("src/Server/AstralForge/DataTemplate.luau")
assert(string.find(template, "RewardedLevel = -1", 1, true), "new saves start uninitialised")
local shell = fs.readFile("src/Client/AstralForge/UiCore.luau#levelMoments")
assert(string.find(shell, "local function LevelCard", 1, true) and string.find(shell, "local function SurgeChip", 1, true), "client shows the card and the surge")

print("verify_level_rewards: ok")
