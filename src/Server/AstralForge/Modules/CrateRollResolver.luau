--!strict
-- Purpose: server-owned crate rarity, pity and definition selection with typed inputs.
-- Owner: gameplay. Dependencies: caller-provided random functions and rarity order.
-- Last-reviewed: 2026-10-07.

export type Crate = { PityRarity: string, PityAfter: number, Weights: { [string]: number } }
export type Rarity = { Rank: number }
export type RandomNumber = (number, number) -> number
export type RandomInteger = (number, number) -> number

local Resolver = {}

local function finite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

function Resolver.roll<T>(
	crate: Crate,
	pity: number,
	rarities: { [string]: Rarity },
	definitions: { T },
	rarityOf: (T) -> string,
	nextNumber: RandomNumber,
	nextInteger: RandomInteger,
	order: { string },
	minimumInterval: number
): (T?, string, boolean)
	assert(finite(pity) and finite(crate.PityAfter), "Invalid crate pity state")
	assert(finite(minimumInterval) and minimumInterval > 0, "Invalid crate roll interval")
	local pityDefinition = rarities[crate.PityRarity]
	local pityRank = if pityDefinition then pityDefinition.Rank else 0
	local minimumRank = if math.max(0, math.floor(pity)) + 1 >= math.max(0, math.floor(crate.PityAfter))
		then math.max(0, math.floor(pityRank))
		else 0
	local total = 0
	for rarity, weight in crate.Weights do
		assert(finite(weight) and weight >= 0, "Invalid crate rarity weight")
		local definition = rarities[rarity]
		if definition and definition.Rank >= minimumRank then
			total += weight
		end
	end
	assert(finite(total), "Crate rarity weights overflowed")
	local maximum = math.max(total, minimumInterval)
	local remaining = nextNumber(0, maximum)
	assert(finite(remaining) and remaining >= 0 and remaining <= maximum, "Invalid crate random result")
	local selected = crate.PityRarity
	for _, rarity in order do
		local definition = rarities[rarity]
		local weight = crate.Weights[rarity] or 0
		if definition and definition.Rank >= minimumRank and weight > 0 then
			remaining -= weight
			if remaining <= 0 then
				selected = rarity
				break
			end
		end
	end
	local candidates: { T } = {}
	for _, definition in definitions do
		if rarityOf(definition) == selected then
			candidates[#candidates + 1] = definition
		end
	end
	local index = nextInteger(1, math.max(1, #candidates))
	assert(finite(index), "Invalid crate candidate index")
	if #candidates == 0 then
		return nil, selected, false
	end
	index = math.clamp(math.floor(index), 1, #candidates)
	local selectedDefinition = rarities[selected]
	local selectedRank = if selectedDefinition then selectedDefinition.Rank else 0
	return candidates[index], selected, selectedRank >= pityRank
end

return table.freeze(Resolver)
