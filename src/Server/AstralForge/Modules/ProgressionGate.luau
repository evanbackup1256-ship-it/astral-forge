--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(script.Parent:WaitForChild("Economy"))
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
	elseif kind == "Domain" then
		return math.max(0, tonumber(profile.Domain and profile.Domain.Rank) or 0)
	elseif kind == "Zone" then
		return profile.Zone
	elseif kind == "PlayTime" then
		return profile.Stats.PlayTime
	elseif kind == "AnomalyStabilizations" then
		return profile.Anomaly.Stabilizations
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
	local requiredZone = upgrade.RequiredZone or 1
	if profile.Zone < requiredZone then
		local zone = GameConfig.Zones[requiredZone]
		return "Reach " .. (zone and zone.Name or ("World " .. tostring(requiredZone)))
	end
	local requiredRebirths = upgrade.RequiredRebirths or 0
	if profile.Rebirths < requiredRebirths then
		return string.format("Complete %d rebirth%s", requiredRebirths, requiredRebirths == 1 and "" or "s")
	end
	if upgrade.PreviousId and (levels[upgrade.PreviousId] or 0) < (upgrade.PreviousLevel or 1) then
		local previous = Economy.GetMachine(upgrade.PreviousId) or Economy.GetResearch(upgrade.PreviousId)
		return string.format(
			"Raise %s to level %d",
			previous and previous.Name or upgrade.PreviousId,
			upgrade.PreviousLevel or 1
		)
	end
	return nil
end

return table.freeze(ProgressionGate)
