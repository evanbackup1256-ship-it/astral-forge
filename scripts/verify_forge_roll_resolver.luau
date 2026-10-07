--!strict

local Resolver = require("../src/Server/AstralForge/Modules/CrateRollResolver")
local CrateConfig = require("../src/Shared/AstralForge/Shared/CrateConfig")
local CrateRoll = require("../src/Server/AstralForge/Modules/EconomyMath")("CrateRoll")

type Definition = { Id: string, Rarity: string }

local rarities = {
	Common = { Rank = 1 },
	Rare = { Rank = 3 },
	Legendary = { Rank = 5 },
}

local definitions: { Definition } = {
	{ Id = "common-a", Rarity = "Common" },
	{ Id = "common-b", Rarity = "Common" },
	{ Id = "rare-a", Rarity = "Rare" },
	{ Id = "legendary-a", Rarity = "Legendary" },
}

local crate = {
	PityAfter = 3,
	PityRarity = "Legendary",
	Weights = { Common = 70, Rare = 25, Legendary = 5 },
}

local function checkParity(pity: number, rollFraction: number, indexValue: number)
	local nextNumber = function(_low: number, _high: number): number
		return _low + (_high - _low) * rollFraction
	end
	local nextInteger = function(_low: number, _high: number): number
		return indexValue
	end
	local expectedItem, expectedRarity, expectedPity =
		CrateRoll.Roll(crate, pity, rarities, definitions, nextNumber, nextInteger)
	local actualItem, actualRarity, actualPity = Resolver.roll(
		crate,
		pity,
		rarities,
		definitions,
		function(definition: Definition): string
			return definition.Rarity
		end,
		nextNumber,
		nextInteger,
		CrateConfig.RarityOrder,
		CrateConfig.MinimumRollInterval
	)
	assert(actualRarity == expectedRarity)
	assert(actualPity == expectedPity)
	assert(if actualItem then expectedItem ~= nil and actualItem.Id == expectedItem.Id else expectedItem == nil)
end

for _, pity in { 0, 1, 2 } do
	for _, value in { 0, 0.01, 0.69999, 0.7, 0.94999, 0.95, 0.99999, 1 } do
		checkParity(pity, value, 1)
		checkParity(pity, value, 2)
	end
end

local ok = pcall(function()
	Resolver.roll(
		{ PityAfter = 1, PityRarity = "Legendary", Weights = { Common = -1 } },
		0,
		rarities,
		definitions,
		function(definition: Definition): string
			return definition.Rarity
		end,
		function(_low: number, _high: number): number
			return 0
		end,
		function(_low: number, _high: number): number
			return 1
		end,
		CrateConfig.RarityOrder,
		CrateConfig.MinimumRollInterval
	)
end)
assert(not ok, "negative weights must be rejected before the roll mutates player state")

print("[TEST] Forge roll selection matches the established valid-input behavior and rejects invalid weights")
