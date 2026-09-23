--!strict
-- Pure upgrade lock-reason + geometric cost helpers. No Roblox services —
-- ProgressionGate / Economy and Lune verify scripts share this so buy-gate
-- and cost math can be tested without Studio.

local UpgradeCostReason = {}

export type UpgradeLike = {
	RequiredZone: number?,
	RequiredRebirths: number?,
	PreviousId: string?,
	PreviousLevel: number?,
	BaseCost: number?,
	CostScale: number?,
}

export type CostDef = {
	BaseCost: number,
	CostScale: number,
}

function UpgradeCostReason.LevelCost(omegaMath, def: CostDef?, currentLevel: number): any
	if not def then
		return math.huge
	end
	return omegaMath.ScaledCost(def.BaseCost, def.CostScale, currentLevel)
end

function UpgradeCostReason.BulkCost(omegaMath, def: CostDef?, currentLevel: number, count: number): any
	if not def then
		return math.huge
	end
	return omegaMath.GeometricSum(def.BaseCost, def.CostScale, currentLevel, count)
end

function UpgradeCostReason.AffordableLevels(
	omegaMath,
	def: CostDef?,
	currentLevel: number,
	currency: any,
	maximum: number
): (number, any)
	if not def then
		return 0, 0
	end
	return omegaMath.AffordableCount(def.BaseCost, def.CostScale, currentLevel, currency, maximum)
end

-- zoneNameForIndex(requiredZone) -> string?
-- previousNameForId(previousId) -> string?
function UpgradeCostReason.Evaluate(
	profile,
	upgrade: UpgradeLike,
	levels,
	zoneNameForIndex: (number) -> string?,
	previousNameForId: (string) -> string?
): string?
	local requiredZone = upgrade.RequiredZone or 1
	local zoneOwned = math.max(0, math.floor(tonumber(profile.Zone) or 0))
	if zoneOwned < requiredZone then
		local zoneName = zoneNameForIndex(requiredZone)
		return "Reach " .. (zoneName or ("World " .. tostring(requiredZone)))
	end
	local requiredRebirths = upgrade.RequiredRebirths or 0
	local rebirths = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
	if rebirths < requiredRebirths then
		return string.format("Complete %d rebirth%s", requiredRebirths, requiredRebirths == 1 and "" or "s")
	end
	if upgrade.PreviousId and (levels[upgrade.PreviousId] or 0) < (upgrade.PreviousLevel or 1) then
		local previousName = previousNameForId(upgrade.PreviousId)
		return string.format(
			"Raise %s to level %d",
			previousName or upgrade.PreviousId,
			upgrade.PreviousLevel or 1
		)
	end
	return nil
end

return table.freeze(UpgradeCostReason)
