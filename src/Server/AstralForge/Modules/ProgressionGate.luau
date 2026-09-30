--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local UpgradeCostReason = require(script.Parent:WaitForChild("UpgradeCostReason"))
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local ForgeLevels = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ForgeLevels"))

local ProgressionGate = {}

function ProgressionGate.Progress(profile, kind: string): number
	if kind == "Always" then
		return math.huge
	elseif kind == "Level" then
		return ProgressionGate.Level(profile)
	elseif kind == "LifetimeCash" then
		return Economy.AsNumber(profile.LifetimeCash)
	elseif kind == "MachinesBought" then
		-- Lifetime machine levels bought, which (unlike MachineLevels) survives
		-- rebirth. A profile older than the counter can read low, so it never
		-- counts for less than the machine levels owned right now.
		local stats = profile.Stats
		local bought = math.max(0, math.floor(tonumber(stats and stats.MachinesBought) or 0))
		return math.max(bought, Economy.TotalMachineLevels(profile))
	elseif kind == "MachineLevels" then
		return Economy.TotalMachineLevels(profile)
	elseif kind == "ResearchLevels" then
		return Economy.TotalResearchLevels(profile)
	elseif kind == "Rebirths" then
		local current = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
		local spent = 0
		if type(profile.Domain) == "table" then
			spent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0))
		end
		return current + spent
	elseif kind == "Domain" or kind == "DomainRank" then
		return math.max(0, tonumber(profile.Domain and profile.Domain.Rank) or 0)
	elseif kind == "Zone" then
		return math.max(0, math.floor(tonumber(profile.Zone) or 0))
	elseif kind == "PlayTime" then
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.PlayTime) or 0))
	elseif kind == "AnomalyStabilizations" then
		local anomaly = profile.Anomaly
		local fromAnomaly = tonumber(anomaly and anomaly.Stabilizations)
		if fromAnomaly ~= nil then
			return math.max(0, math.floor(fromAnomaly))
		end
		local stats = profile.Stats
		return math.max(0, math.floor(tonumber(stats and stats.AnomalyStabilizations) or 0))
	elseif kind == "ForgePathSteps" then
		local claimed = 0
		local forgePath = profile.ForgePath
		if type(forgePath) == "table" and type(forgePath.ClaimedSteps) == "table" then
			for _ in forgePath.ClaimedSteps do
				claimed += 1
			end
		end
		return claimed
	end
	return 0
end

function ProgressionGate.Meets(profile, requirement): boolean
	if not requirement then
		return true
	end
	return ProgressionGate.Progress(profile, requirement.Kind) >= requirement.Target
end

-- The player's Forge Level: the highest level of the ladder whose goal they
-- meet (ForgeLevels). Level goals never use the "Level" kind, so this cannot
-- recurse.
function ProgressionGate.Level(profile): number
	return ForgeLevels.levelFor(function(kind: string): number
		return ProgressionGate.Progress(profile, kind)
	end)
end

-- Level, tier and the next goal with its progress, for the state snapshot.
function ProgressionGate.LevelState(profile)
	return ForgeLevels.snapshot(function(kind: string): number
		return ProgressionGate.Progress(profile, kind)
	end)
end

function ProgressionGate.IsFeatureUnlocked(profile, featureId: string): boolean
	local rule = GameConfig.Unlocks[featureId]
	return rule == nil or ProgressionGate.Progress(profile, rule.Kind) >= rule.Target
end

function ProgressionGate.FeatureStates(profile)
	local result = {}
	-- Nearly every rule is level-gated: work the level out once, not per rule.
	local level = ProgressionGate.Level(profile)
	for id, rule in GameConfig.Unlocks do
		local progress = if rule.Kind == "Level" then level else ProgressionGate.Progress(profile, rule.Kind)
		result[id] = {
			Unlocked = progress >= rule.Target,
			Progress = progress == math.huge and rule.Target or progress,
			Target = rule.Target,
			Requirement = rule.Requirement,
			Name = rule.Name,
			-- The level that opens this feature (nil for Admin's owner rule).
			Level = if rule.Kind == "Level" then rule.Target else nil,
		}
	end
	return result
end

function ProgressionGate.UpgradeReason(profile, upgrade, levels): string?
	return UpgradeCostReason.Evaluate(profile, upgrade, levels, function(requiredZone: number): string?
		local zone = GameConfig.Zones[requiredZone]
		return zone and zone.Name
	end, function(previousId: string): string?
		local previous = Economy.GetMachine(previousId) or Economy.GetResearch(previousId)
		return previous and previous.Name
	end)
end

return table.freeze(ProgressionGate)
