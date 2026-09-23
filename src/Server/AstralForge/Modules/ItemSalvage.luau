--!strict
-- Pure item-salvage essence formula. No Roblox services — ServerServices and
-- Lune verify scripts share this so salvage payouts stay testable without
-- Studio. Rarity lookup stays with the caller; pass Rank.

local ItemSalvage = {}

-- Matches prior inline: rank^2 * 8 + max(0, level-1) * rank * 3
function ItemSalvage.Value(level: any, rarityRank: any): number
	local rank = if type(rarityRank) == "number" then rarityRank else 1
	local safeLevel = if type(level) == "number" then level else 1
	return rank * rank * 8 + math.max(0, safeLevel - 1) * rank * 3
end

return table.freeze(ItemSalvage)
