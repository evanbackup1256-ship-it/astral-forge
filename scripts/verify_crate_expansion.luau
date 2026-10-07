--!strict
local Expansion = require("../src/Shared/AstralForge/Shared/CrateExpansion")
local originals = {}
for index = 1, 9 do
	originals[index] = { Id = tostring(index), Color = index, Weights = { Rare = 50, Epic = 50 } }
end
local items = { Crates = originals, ShopOffers = {} }
Expansion.extendItems(items)
assert(#items.Crates == 21 and #items.ShopOffers == 12)
local ids = {}
local validPityRarities = { Rare = true, Epic = true, Legendary = true }
for index = 10, #items.Crates do
	local crate = items.Crates[index]
	assert(not ids[crate.Id])
	ids[crate.Id] = true
	assert(crate.PityAfter >= 5 and crate.Weights ~= originals[1].Weights)
	assert(validPityRarities[crate.PityRarity] == true, "new crate pity rarity must match the rarity catalog's casing")
	local offer = items.ShopOffers[index - 9]
	assert(offer.CrateId == crate.Id and offer.Price > 0 and offer.StockMax == 3)
end
local skins = Expansion.extendSkins({
	{ Id = "Classic", Default = true, Accent = { 1, 2, 3 }, Glow = { 4, 5, 6 }, Blurb = "Iron", Vfx = "embers" },
})
assert(#skins == 13)
assert(Expansion.openBonus(nil, skins[2], 1) == 0)
local cosmetics = { CrateSkins = { Salvage = true } }
assert(Expansion.openBonus(cosmetics, skins[2], 1) == 4)
assert(Expansion.openBonus(cosmetics, skins[2], 5) == 20)
assert(Expansion.openBonus(cosmetics, skins[2], 100) == 0)
assert(Expansion.openBonus(cosmetics, skins[3], 1) == 0)
assert(Expansion.openBonus(cosmetics, { Id = "Salvage", EssencePerOpen = math.huge }, 1) == 0)
assert(Expansion.openBonus(cosmetics, { Id = "Salvage", EssencePerOpen = 0 / 0 }, 1) == 0)
print("[TEST] 12 crates, purchasable keys, 12 skins and bounded owned-skin bonuses passed")
