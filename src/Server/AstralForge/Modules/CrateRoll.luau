--!strict
-- Pure crate pity / weighted rarity / drop selection. No Roblox services —
-- ServerServices and Lune verify scripts share this so open-count gates and
-- pity rolls can be tested without Studio. RNG and inventory mutation stay
-- with the caller; rarity tables and definitions are injected.

local CrateRoll = {}

CrateRoll.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

export type CrateLike = {
	PityRarity: string,
	PityAfter: number,
	Weights: { [string]: number },
}

export type RarityData = {
	Rank: number,
}

-- Pity floor: once pity+1 reaches PityAfter, only rarities at/above pityRank roll.
function CrateRoll.MinimumRank(pity: number, pityAfter: number, pityRank: number): number
	local safePity = math.max(0, math.floor(tonumber(pity) or 0))
	local after = math.max(0, math.floor(tonumber(pityAfter) or 0))
	local rank = math.max(0, math.floor(tonumber(pityRank) or 0))
	return if safePity + 1 >= after then rank else 0
end

function CrateRoll.TotalWeight(
	weights: { [string]: number },
	rarities: { [string]: RarityData },
	minimumRank: number
): number
	local total = 0
	for rarity, weight in weights do
		local data = rarities[rarity]
		if data and data.Rank >= minimumRank then
			total += weight
		end
	end
	return total
end

-- Walk rarity order subtracting weights; returns selected rarity name.
function CrateRoll.SelectRarity(
	roll: number,
	weights: { [string]: number },
	rarities: { [string]: RarityData },
	minimumRank: number,
	pityRarityFallback: string,
	order: { string }?
): string
	local remaining = roll
	local selected = pityRarityFallback
	local walk = order or CrateRoll.RARITY_ORDER
	for _, rarity in walk do
		local data = rarities[rarity]
		local weight = weights[rarity] or 0
		if data and data.Rank >= minimumRank and weight > 0 then
			remaining -= weight
			if remaining <= 0 then
				selected = rarity
				break
			end
		end
	end
	return selected
end

-- Collect definitions matching rarity, then pick by 1-based index.
function CrateRoll.Candidates(definitions: { any }, selectedRarity: string): { any }
	local candidates = {}
	for _, definition in definitions do
		if definition.Rarity == selectedRarity then
			table.insert(candidates, definition)
		end
	end
	return candidates
end

function CrateRoll.PickCandidate(candidates: { any }, index: number): any?
	if #candidates < 1 then
		return nil
	end
	local safeIndex = math.clamp(math.floor(index), 1, #candidates)
	return candidates[safeIndex]
end

-- Full roll: returns definition, rarity, pityHit. nextNumber/nextInteger inject RNG.
function CrateRoll.Roll(
	crate: CrateLike,
	pity: number,
	rarities: { [string]: RarityData },
	definitions: { any },
	nextNumber: (number, number) -> number,
	nextInteger: (number, number) -> number
): (any?, string, boolean)
	local pityData = rarities[crate.PityRarity]
	local pityRank = pityData and pityData.Rank or 0
	local minimumRank = CrateRoll.MinimumRank(pity, crate.PityAfter, pityRank)
	local totalWeight = CrateRoll.TotalWeight(crate.Weights, rarities, minimumRank)
	local roll = nextNumber(0, math.max(totalWeight, 0.001))
	local selectedRarity = CrateRoll.SelectRarity(
		roll,
		crate.Weights,
		rarities,
		minimumRank,
		crate.PityRarity
	)
	local candidates = CrateRoll.Candidates(definitions, selectedRarity)
	local selected = CrateRoll.PickCandidate(candidates, nextInteger(1, math.max(1, #candidates)))
	local selectedRank = rarities[selectedRarity] and rarities[selectedRarity].Rank or 0
	local pityHit = selectedRank >= pityRank
	if not selected then
		return nil, selectedRarity, false
	end
	return selected, selectedRarity, pityHit
end

-- Open count: only 1 or 5. Non-number → 1. Other numbers → nil + error.
function CrateRoll.NormalizeOpenCount(rawCount: any): (number?, string?)
	local count = if type(rawCount) == "number" then math.clamp(math.floor(rawCount), 1, 5) else 1
	if count ~= 1 and count ~= 5 then
		return nil, "Crates can be opened one or five at a time."
	end
	return count, nil
end

-- True when every positive-weight rarity is marked for auto-salvage and KeepNew is off.
function CrateRoll.GuaranteedRecycle(
	weights: { [string]: number },
	autoEnabled: boolean,
	keepNew: any,
	rarityRules: { [string]: boolean }
): boolean
	if not autoEnabled or keepNew ~= false then
		return false
	end
	for rarity, weight in weights do
		if weight > 0 and rarityRules[rarity] ~= true then
			return false
		end
	end
	return true
end

function CrateRoll.RequiredSlots(count: number, guaranteedRecycle: boolean): number
	return if guaranteedRecycle then 0 else math.max(0, math.floor(count))
end

return table.freeze(CrateRoll)
