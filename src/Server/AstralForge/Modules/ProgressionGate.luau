--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
local UpgradeCostReason = require(script.Parent:WaitForChild("UpgradeCostReason"))
local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local ProgressionGate = {}

function ProgressionGate.Progress(profile, kind: string): number
	if kind == "Always" then
		return math.huge
	elseif kind == "LifetimeCash" then
		return Economy.AsNumber(profile.LifetimeCash)
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

function ProgressionGate.IsFeatureUnlocked(profile, featureId: string): boolean
	local rule = GameConfig.Unlocks[featureId]
	return rule == nil or ProgressionGate.Progress(profile, rule.Kind) >= rule.Target
end

function ProgressionGate.FeatureStates(profile)
	local result = {}
	for id, rule in GameConfig.Unlocks do
		local progress = ProgressionGate.Progress(profile, rule.Kind)
		result[id] = {
			Unlocked = progress >= rule.Target,
			Progress = progress == math.huge and rule.Target or progress,
			Target = rule.Target,
			Requirement = rule.Requirement,
			Name = rule.Name,
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
