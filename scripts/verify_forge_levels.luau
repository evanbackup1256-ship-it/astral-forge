--!strict
-- Guards for Forge Levels, the single progression ladder.
--
-- What these lock in:
--   1. The ladder is well formed: levels 1..N in order, one plain goal each,
--      tiers in order, and every goal measured by a number that never goes
--      down (so nothing re-locks after a rebirth).
--   2. Everything progression-gated opens at a level: every gated feature,
--      every nav page, every server-gated action.
--   3. A player's level is the HIGHEST goal they meet, so a veteran whose
--      early counters are stale still lands on the right level.
--   4. No regression: anyone who met an old unlock rule still has that
--      feature. The rules below are the pre-ladder GameConfig.Unlocks.
--   5. Domain opens at the rebirth count its first expansion costs. The old
--      rule required a domain rank of 1 -- which only the expansion itself
--      grants -- so the first expansion was refused for everyone.
--   6. The server, the snapshot and the client all read the ladder.
--
-- HARD: pure checks -- no Roblox instances, no vendor requires.

local fs = require("./_memberfs")(require("@lune/fs"))

local ForgeLevels = require("../src/Shared/AstralForge/Shared/SharedData")("ForgeLevels")
local ActionFeatureMaps = require("../src/Server/AstralForge/Modules/ProfileMath")("ActionFeatureMaps")

local function readSource(path: string): string
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end

local configSource = readSource("src/Shared/AstralForge/Shared/GameConfig.luau")
local gateSource = readSource("src/Server/AstralForge/Modules/EconomyMath.luau#ProgressionGate")
local servicesSource = readSource("src/Server/AstralForge/Services/ServerServices.luau")
local echoSource = readSource("src/Server/AstralForge/Services/CoreServices.luau#ForgeEchoService")
local navSource = readSource("src/Client/AstralForge/CoreKit.luau#navRouteTable")
local workspaceSource = readSource("src/Client/AstralForge/UiCore.luau#WorkspaceChrome")
local shellSource = readSource("src/Client/AstralForge/UiCore.luau#AppShellChrome")
local mainSource = readSource("src/Client/AstralForge/UiCore.luau#MainGame")
local overviewSource = readSource("src/Client/AstralForge/pages/PagesCore.luau#OverviewView")

local ladder = ForgeLevels.ladder()
local tiers = ForgeLevels.tiers()

------------------------------------------------------------------------
-- 1. Ladder shape
------------------------------------------------------------------------
assert(#ladder >= 10, "the ladder needs enough levels to pace the game")
local tierIndex: { [string]: number } = {}
for index, tier in tiers do
	tierIndex[tier] = index
	assert(ForgeLevels.tierBlurb(tier) ~= "", "tier " .. tier .. " needs a one-line description")
end
local tiersUsed: { [string]: boolean } = {}
local lastTier = 0
local lastTargetByKind: { [string]: number } = {}
local seenFeature: { [string]: number } = {}
for index, def in ladder do
	assert(def.Level == index, "levels must be numbered 1..N in order, got " .. tostring(def.Level) .. " at " .. tostring(index))
	local tierAt = tierIndex[def.Tier]
	assert(tierAt ~= nil, "level " .. index .. " has an unknown tier: " .. tostring(def.Tier))
	assert(tierAt >= lastTier, "tiers must climb in order (level " .. index .. " steps back to " .. def.Tier .. ")")
	lastTier = tierAt
	tiersUsed[def.Tier] = true
	if index == 1 then
		assert(def.Goal == nil, "level 1 is where everyone starts -- it has no goal")
	else
		local goal = def.Goal
		assert(goal ~= nil, "level " .. index .. " needs a goal")
		assert(ForgeLevels.LIFETIME_KINDS[goal.Kind], "level " .. index .. " goal uses " .. goal.Kind .. ", which can go down (re-locking features)")
		assert(goal.Target > 0, "level " .. index .. " goal target must be positive")
		assert(#goal.Text >= 8, "level " .. index .. " goal needs plain-language text")
		local previous = lastTargetByKind[goal.Kind]
		assert(previous == nil or goal.Target > previous, "level " .. index .. " must be harder than every earlier " .. goal.Kind .. " goal")
		lastTargetByKind[goal.Kind] = goal.Target
	end
	for _, featureId in def.Unlocks do
		assert(seenFeature[featureId] == nil, featureId .. " is listed at two levels")
		seenFeature[featureId] = def.Level
	end
end
for _, tier in tiers do
	assert(tiersUsed[tier], "tier " .. tier .. " has no levels")
end
assert(ForgeLevels.requirementText(6) == "Reach Level 6 (" .. ladder[6].Tier .. ")", "requirement text format changed")

------------------------------------------------------------------------
-- 2. Everything progression-gated opens at a level
------------------------------------------------------------------------
local unlockBlock = string.match(configSource, "\n\tUnlocks = {\n(.-)\n\t},\n")
assert(unlockBlock ~= nil, "could not isolate GameConfig.Unlocks")
local configFeatures: { [string]: boolean } = {}
for featureId in string.gmatch(unlockBlock :: string, "\n?\t\t(%w+) = {") do
	configFeatures[featureId] = true
end
assert(configFeatures.Research and configFeatures.Admin, "GameConfig.Unlocks parse looks wrong")
for featureId in configFeatures do
	if featureId ~= "Admin" then
		assert(seenFeature[featureId] ~= nil, featureId .. " is gated in GameConfig but on no level")
	end
end
for featureId in seenFeature do
	assert(configFeatures[featureId], featureId .. " is on the ladder but has no GameConfig.Unlocks name")
end
assert(not string.find(unlockBlock :: string, "LifetimeCash", 1, true), "Unlocks must not carry hand-written gates -- the ladder sets them")
assert(
	string.find(configSource, "for featureId, step in ForgeLevels.unlockLevels() do", 1, true)
		and string.find(configSource, 'rule.Requirement = if goal ~= nil then goal.Text else ""', 1, true),
	"every gate derives from its milestone and is described by that milestone's goal, never a level"
)

for routeId in string.gmatch(navSource, 'id = "(%w+)"') do
	if routeId ~= "Admin" then
		assert(seenFeature[routeId] ~= nil, "nav page " .. routeId .. " bypasses the level ladder")
	end
end
for action, featureId in ActionFeatureMaps.FEATURE do
	assert(seenFeature[featureId] ~= nil, "server action " .. action .. " is gated by " .. featureId .. ", which is on no level")
end

------------------------------------------------------------------------
-- 3. Level = highest goal met
------------------------------------------------------------------------
local function lookup(values: { [string]: number }): (string) -> number
	return function(kind: string): number
		return values[kind] or 0
	end
end
local function levelOf(values: { [string]: number }): number
	return ForgeLevels.levelFor(lookup(values))
end

assert(levelOf({}) == 1, "a new player is level 1")
assert(levelOf({ LifetimeCash = 99 }) == 1, "a goal is not met one short")
assert(levelOf({ LifetimeCash = 100 }) == 2, "earning 100 flux reaches level 2")
-- A veteran whose machine counter predates the stat still lands high.
local firstRebirthLevel = 0
for _, def in ladder do
	if def.Goal and def.Goal.Kind == "Rebirths" and def.Goal.Target == 1 then
		firstRebirthLevel = def.Level
	end
end
assert(firstRebirthLevel > 0, "the ladder needs a first-rebirth level")
assert(levelOf({ Rebirths = 1 }) == firstRebirthLevel, "a rebirth alone must place a player at the first-rebirth level")
assert(levelOf({ Domain = 1000 }) == #ladder, "the top goal reaches the top level")

-- Raising any single number never lowers the level.
for kind in ForgeLevels.LIFETIME_KINDS do
	local previous = 1
	for _, amount in { 0, 1, 2, 3, 5, 10, 15, 100, 250, 500, 1000, 2500, 5000, 75000, 1e9 } do
		local level = levelOf({ [kind] = amount, LifetimeCash = 50 })
		assert(level >= previous, "raising " .. kind .. " lowered the level")
		previous = level
	end
end

-- The snapshot's next goal is always the unmet goal of the next level.
for _, values in {
	{},
	{ LifetimeCash = 420 },
	{ LifetimeCash = 5000, MachinesBought = 3 },
	{ Rebirths = 4, LifetimeCash = 1e12 },
	{ Domain = 2, Rebirths = 40 },
} do
	local snapshot = ForgeLevels.snapshot(lookup(values))
	assert(snapshot.Max == #ladder, "snapshot must report the ladder size")
	assert(snapshot.Tier == ladder[snapshot.Level].Tier, "snapshot tier must match its level")
	local nextStep = snapshot.Next
	assert(nextStep ~= nil, "below the top there is always a next goal")
	assert(nextStep.Level == snapshot.Level + 1, "the next goal is the next level's")
	assert(nextStep.Progress < nextStep.Target, "the next goal can never already be met")
	assert(#nextStep.Unlocks == #ladder[nextStep.Level].Unlocks, "the next goal must list what it opens")
end
assert(ForgeLevels.snapshot(lookup({ Domain = 1000 })).Next == nil, "the top level has no next goal")

------------------------------------------------------------------------
-- 4. No regression against the old unlock rules
------------------------------------------------------------------------
-- The pre-ladder GameConfig.Unlocks. A player who met one of these must still
-- have that feature: set ONLY that metric to its old target and check the
-- level reaches the feature. MachineLevels maps to MachinesBought, which is
-- never below the machine levels owned.
local LEGACY = {
	{ "Research", "LifetimeCash", 100 },
	{ "Mail", "LifetimeCash", 250 },
	{ "Rewards", "LifetimeCash", 500 },
	{ "Story", "MachineLevels", 5 },
	{ "Missions", "LifetimeCash", 1_000 },
	{ "Worlds", "LifetimeCash", 2_500 },
	{ "Shop", "LifetimeCash", 2_500 },
	{ "StarGrid", "LifetimeCash", 5_000 },
	{ "Milestones", "MachineLevels", 15 },
	{ "Rebirth", "LifetimeCash", 75_000 },
	{ "Anomaly", "Rebirths", 1 },
	{ "Crew", "Rebirths", 1 },
	{ "Trade", "Rebirths", 1 },
	{ "Command", "Rebirths", 1 },
	{ "Lab", "Rebirths", 2 },
	{ "Echoes", "Rebirths", 3 },
	{ "Convergence", "Rebirths", 3 },
	{ "Continuum", "Rebirths", 5 },
	{ "Domain", "Domain", 1 },
}
-- Deliberately later than before, all within a new player's first minutes:
-- these used to be open from the start (or after a short play timer) and now
-- arrive one or two at a time so the first screen stays simple.
local INTENTIONALLY_STAGED = {
	Inventory = true,
	Leaderboards = true,
	Guild = true,
	Boosts = true,
	ForgePath = true,
	Wheel = true,
	Credits = true,
}
for _, rule in LEGACY do
	local featureId, kind, target = rule[1], rule[2], rule[3]
	local metric = if kind == "MachineLevels" then "MachinesBought" else kind
	local reached = levelOf({ [metric] = target })
	local needed = seenFeature[featureId]
	assert(needed ~= nil, featureId .. " vanished from the ladder")
	assert(
		reached >= needed,
		string.format("%s: a player who met the old rule (%s %d) is only level %d but it opens at %d", featureId, kind, target, reached, needed)
	)
end
for featureId in INTENTIONALLY_STAGED do
	assert(seenFeature[featureId] ~= nil and seenFeature[featureId] <= 8, featureId .. " must still open in the first tiers")
end

------------------------------------------------------------------------
-- 5. Domain opens when the first expansion is affordable
------------------------------------------------------------------------
local baseRebirths = tonumber(string.match(configSource, "BaseRequiredRebirths = (%d+)"))
assert(baseRebirths ~= nil, "could not read Domain.BaseRequiredRebirths")
local domainLevel = ladder[seenFeature.Domain]
assert(domainLevel.Goal ~= nil and domainLevel.Goal.Kind ~= "Domain", "Domain cannot require the domain rank only it grants")
assert(
	domainLevel.Goal.Kind == "Rebirths" and domainLevel.Goal.Target == baseRebirths,
	"Domain must open at exactly the rebirths its first expansion costs"
)

------------------------------------------------------------------------
-- 6. Server, snapshot and client all read the ladder
------------------------------------------------------------------------
assert(string.find(gateSource, 'kind == "Level"', 1, true), "ProgressionGate must measure the Level kind")
assert(string.find(gateSource, 'kind == "MachinesBought"', 1, true), "ProgressionGate must measure lifetime machine levels")
assert(string.find(gateSource, "local level = ProgressionGate.Level(profile)", 1, true), "FeatureStates must work the level out once")
assert(string.find(servicesSource, "Level = levelState,", 1, true), "the state snapshot must carry the level")
assert(string.find(servicesSource, 'Type = "LevelUp"', 1, true), "levelling up must reach the client")
assert(string.find(echoSource, 'ProgressionGate.IsFeatureUnlocked(profile, "Echoes")', 1, true), "echo charging must follow the Echoes gate")
assert(not string.find(echoSource, "Unlocks.Echoes.Target", 1, true), "echo charging must not read the gate target as a rebirth count")
assert(string.find(workspaceSource, "readLevelState(state)", 1, true), "the level bar must read the level snapshot")
assert(string.find(shellSource, "React.createElement(LevelRoadmap", 1, true), "the level roadmap must be reachable")
assert(string.find(mainSource, 'kind == "LevelUp"', 1, true), "the client must celebrate a level-up")
assert(string.find(overviewSource, "push(levelGoalLine(state))", 1, true), "the Overview goal card must lead with the level goal")
assert(not string.find(overviewSource, "LADDER_UNLOCKS", 1, true), "the old raw unlock ladder must be gone")

print(
	string.format(
		"[INFO] [TEST] forge levels passed | %d levels in %d tiers, %d features gated, %d legacy rules kept, Domain opens at %d rebirths",
		#ladder,
		#tiers,
		(function()
			local count = 0
			for _ in seenFeature do
				count += 1
			end
			return count
		end)(),
		#LEGACY,
		baseRebirths :: number
	)
)
