--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local ProfileMath = require("../src/Server/AstralForge/Modules/ProfileMath")
local GeneralBoardValue = ProfileMath("GeneralBoardValue")

local definitions = {
	{ Id = "SecretSignal", Name = "Secret Signal", Description = "A hidden milestone.", Kind = "Signal", Target = 5, Hidden = true, Reward = {} },
	{ Id = "SecretForge", Name = "Secret Forge", Description = "Another hidden milestone.", Kind = "Forge", Target = 8, Hidden = true, Reward = {} },
	{ Id = "PublicGoal", Name = "Public Goal", Description = "An ordinary milestone.", Kind = "Public", Target = 3, Reward = {} },
}

local source = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau"):gsub("\r\n", "\n")
local methodStart = assert(string.find(source, "\t\tfunction ProgressionService.AchievementStates(profile)", 1, true))
local methodStop = assert(string.find(source, "\n\t\tfunction ProgressionService.ClaimAchievement", methodStart, true))
local achievementStatesSource = string.sub(source, methodStart, methodStop - 1)
local harness = [[
local GameConfig = { Achievements = definitions }
local ProgressionService = {
	AchievementProgress = function(profile, kind)
		return profile.Progress[kind] or 0
	end,
}
local function copyReward(reward)
	return table.clone(reward)
end
]] .. achievementStatesSource .. [[
return ProgressionService.AchievementStates
]]
local AchievementStates = luau.load(harness, {
	environment = { definitions = definitions },
})()

local profile = {
	Achievements = { SecretForge = true, PublicGoal = true },
	Progress = { Signal = 4, Forge = 1, Public = 1 },
}
local first = AchievementStates(profile)
assert(#first == 2, "unearned hidden achievements stay undisclosed")
assert(first[1].Id == "SecretForge" and first[1].Claimed, "a claimed secret remains visible in the milestone list")
assert(first[2].Id == "PublicGoal" and first[2].Hidden ~= true, "ordinary achievements remain visible")

profile.Progress.Signal = 5
local revealed = AchievementStates(profile)
assert(#revealed == 3, "a completed secret is revealed so it can be claimed")
assert(revealed[1].Id == "SecretSignal" and revealed[1].Hidden == true and not revealed[1].Claimed)

local function persist(value)
	return tonumber(value) or 0
end
assert(
	GeneralBoardValue.Of(profile, "HiddenSecrets", persist, definitions) == 1,
	"the board counts claimed hidden achievements only"
)
profile.Achievements.SecretSignal = true
assert(GeneralBoardValue.Of(profile, "HiddenSecrets", persist, definitions) == 2, "new secret claims advance the saved score")

local gameConfig = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
for _, id in { "EventHorizon", "ForgeApex", "StoryArchivist" } do
	local start = assert(string.find(gameConfig, `Id = "{id}"`, 1, true), `missing secret definition {id}`)
	local finish = string.find(gameConfig, "\n\t\t},", start, true) or (#gameConfig + 1)
	assert(string.find(string.sub(gameConfig, start, finish), "Hidden = true", 1, true), `{id} is not marked hidden`)
end
local quickFind = fs.readFile("src/Client/AstralForge/QuickFind.luau")
assert(quickFind:find("revealedMilestones[entry.key]", 1, true), "Quick Find can leak undiscovered secret names")
assert(quickFind:find('for _, achievement in state.Achievements or {} do', 1, true), "Quick Find does not use server reveal state")

print("verify_hidden_ranks: hidden reveal, legacy claims and server-authoritative secret score passed")
