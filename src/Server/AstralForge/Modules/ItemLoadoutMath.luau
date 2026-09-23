--!strict
-- Pure EquipBest loadout planner. No Roblox services — ServerServices and Lune
-- verify scripts share BuildTargets / PlanEquipBest so socket greedy assignment
-- stays testable without Studio. Catalog ownership gates stay with the caller.

local ItemLoadoutMath = {}

-- True when a relic definition can occupy `target` (Slot + optional Targets list).
function ItemLoadoutMath.IsCompatible(definition: any, target: any): boolean
	if type(definition) ~= "table" or type(target) ~= "table" then
		return false
	end
	if definition.Slot ~= target.Slot then
		return false
	end
	local targets = definition.Targets
	if type(targets) ~= "table" then
		return true
	end
	for _, allowed in targets do
		if allowed == target.TargetId then
			return true
		end
	end
	return false
end

-- Effect power used to rank EquipBest candidates (matches EffectAtLevel formula).
function ItemLoadoutMath.CandidatePower(definition: any, level: any): number
	if type(definition) ~= "table" then
		return 0
	end
	local base = tonumber(definition.BaseEffect) or 0
	local growth = tonumber(definition.LevelGrowth) or 0
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	return base * (1 + growth * math.max(0, safeLevel - 1))
end

-- Open sockets from owned Machines/Research (≥1). Catalog lists are id→def or arrays.
function ItemLoadoutMath.BuildTargets(machinesCatalog: any, researchCatalog: any, machineLevels: any, researchLevels: any): { any }
	local targets = {}
	local machines = if type(machineLevels) == "table" then machineLevels else {}
	local research = if type(researchLevels) == "table" then researchLevels else {}
	if type(machinesCatalog) == "table" then
		for _, machine in machinesCatalog do
			if type(machine) == "table" and type(machine.Id) == "string" then
				if (tonumber(machines[machine.Id]) or 0) >= 1 then
					table.insert(targets, {
						Id = "Machine:" .. machine.Id,
						Slot = "Machine",
						TargetId = machine.Id,
					})
				end
			end
		end
	end
	if type(researchCatalog) == "table" then
		for _, entry in researchCatalog do
			if type(entry) == "table" and type(entry.Id) == "string" then
				if (tonumber(research[entry.Id]) or 0) >= 1 then
					table.insert(targets, {
						Id = "Research:" .. entry.Id,
						Slot = "Research",
						TargetId = entry.Id,
					})
				end
			end
		end
	end
	return targets
end

local function rarityRank(rarities: any, rarity: any): number
	if type(rarities) ~= "table" then
		return 0
	end
	local entry = rarities[rarity]
	if type(entry) == "table" then
		return tonumber(entry.Rank) or 0
	end
	return tonumber(entry) or 0
end

-- Greedy best-fit: scarcest sockets first, strongest compatible relic wins.
-- Returns nextEquipped map, equippedCount, changed vs currentEquipped.
function ItemLoadoutMath.PlanEquipBest(
	targets: any,
	candidates: any,
	rarities: any,
	currentEquipped: any
): ({ [string]: string }, number, number)
	local socketList = if type(targets) == "table" then table.clone(targets) else {}
	local relicList = if type(candidates) == "table" then table.clone(candidates) else {}
	table.sort(relicList, function(a, b)
		local aPower = tonumber(a and a.Power) or 0
		local bPower = tonumber(b and b.Power) or 0
		if aPower ~= bPower then
			return aPower > bPower
		end
		local aRank = rarityRank(rarities, a and a.Definition and a.Definition.Rarity)
		local bRank = rarityRank(rarities, b and b.Definition and b.Definition.Rarity)
		if aRank ~= bRank then
			return aRank > bRank
		end
		local aLevel = tonumber(a and a.Instance and a.Instance.Level) or 0
		local bLevel = tonumber(b and b.Instance and b.Instance.Level) or 0
		if aLevel ~= bLevel then
			return aLevel > bLevel
		end
		return tostring(a and a.Uid) < tostring(b and b.Uid)
	end)

	local function compatibleCount(target): number
		local count = 0
		for _, candidate in relicList do
			if ItemLoadoutMath.IsCompatible(candidate.Definition, target) then
				count += 1
			end
		end
		return count
	end
	table.sort(socketList, function(a, b)
		local aCount = compatibleCount(a)
		local bCount = compatibleCount(b)
		if aCount ~= bCount then
			return aCount < bCount
		end
		return tostring(a.Id) < tostring(b.Id)
	end)

	local nextEquipped: { [string]: string } = {}
	local used = {}
	local equippedCount = 0
	for _, target in socketList do
		for _, candidate in relicList do
			if not used[candidate.Uid] and ItemLoadoutMath.IsCompatible(candidate.Definition, target) then
				nextEquipped[target.Id] = candidate.Uid
				used[candidate.Uid] = true
				equippedCount += 1
				break
			end
		end
	end

	local current = if type(currentEquipped) == "table" then currentEquipped else {}
	local changed = 0
	for target, uid in nextEquipped do
		if current[target] ~= uid then
			changed += 1
		end
	end
	for target in current do
		if not nextEquipped[target] then
			changed += 1
		end
	end
	return nextEquipped, equippedCount, changed
end

-- Aggregated item effect multipliers for client rails (wave49).
function ItemLoadoutMath.EffectsPublic(profile, Economy)
	return {
		Production = Economy.ItemEffect(profile, "Production"),
		Capacity = Economy.ItemEffect(profile, "Capacity"),
		Tap = Economy.ItemEffect(profile, "Tap"),
		Critical = Economy.ItemEffect(profile, "Critical"),
		Automation = Economy.ItemEffect(profile, "Automation"),
		Offline = Economy.ItemEffect(profile, "Offline"),
	}
end

return table.freeze(ItemLoadoutMath)
