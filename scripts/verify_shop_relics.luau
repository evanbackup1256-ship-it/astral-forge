--!strict
-- The Shop and the relic system (SharedData#ShopCatalog, SharedData#RelicSystem, GameConfig.Items):
--  * Celestial and Astral sit above Mythic everywhere rarities are ordered, and every crate can drop
--    them, rarely: never more than ~1% Celestial / ~0.12% Astral, never zero;
--  * the Daily Shop roll is deterministic per (player, day), changes day to day, has distinct offers,
--    leaves owned skins out, discounts the deal slot, and only names crates, boosts and skins that exist;
--  * fusion keeps the socketed/strongest copy, consumes the weakest spare, respects locks and the star cap;
--  * star multipliers and the Codex bonus agree between the shared rules and the economy;
--  * the actions are wired end to end (protocol, firewall, client allowlist, server handlers, snapshot).

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Expansion = require("../src/Shared/AstralForge/Shared/CrateExpansion")
local function member(path: string, name: string): any
	local environment = setmetatable({
		script = { Parent = { CrateExpansion = "CrateExpansion" } },
		require = function(dependency)
			assert(dependency == "CrateExpansion", "Unexpected dependency")
			return Expansion
		end,
	}, { __index = getfenv(0) })
	return luau.load(fs.readFile(path .. "#" .. name), { chunkName = name, environment = environment })()
end
local Shop = member("src/Shared/AstralForge/Shared/SharedData.luau", "ShopCatalog")
local Relics = member("src/Shared/AstralForge/Shared/SharedData.luau", "RelicSystem")
local Envelope = require("../src/Server/AstralForge/Modules/EconomyMath")("EconomyEnvelopeMath")
local CrateRoll = require("../src/Server/AstralForge/Modules/EconomyMath")("CrateRoll")
local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

-- Rarity order
for index, rarity in Relics.ORDER do
	assert(CrateRoll.RARITY_ORDER[index] == rarity, "crate roll order must match the relic order at " .. rarity)
end
assert(Relics.ORDER[7] == "Celestial" and Relics.ORDER[8] == "Astral", "Celestial then Astral above Mythic")
assert(string.find(config, "Celestial = { Rank = 7", 1, true) and string.find(config, "Astral = { Rank = 8", 1, true), "ranks 7 and 8")

-- Definitions per rarity (read from GameConfig's source)
local definitions = {}
for id, rarity in string.gmatch(config, 'Id = "(%w+)",%s*\n%s*Name = "[^"]+",%s*\n%s*Description = "[^"]+",%s*\n%s*Slot = "%a+",%s*\n[^\n]-Rarity = "(%a+)"') do
	table.insert(definitions, { Id = id, Rarity = rarity })
end
for id, rarity in string.gmatch(config, 'Id = "(%w+)",%s*\n%s*Name = "[^"]+",%s*\n%s*Description = "[^"]+",%s*\n%s*Slot = "%a+",%s*\n%s*Targets = %b{},%s*\n%s*Rarity = "(%a+)"') do
	table.insert(definitions, { Id = id, Rarity = rarity })
end
local count = { Celestial = 0, Astral = 0 }
for _, definition in definitions do
	count[definition.Rarity] = (count[definition.Rarity] or 0) + 1
end
assert(count.Celestial >= 3 and count.Astral >= 2, "there must be Celestial and Astral relics to find")

-- Crate odds: every crate can drop both, rarely
local crates = 0
for crateId, weights in string.gmatch(config, 'Id = "(%w+Crate)",%s*Name = "[^"]+",%s*Description = "[^"]+",%s*PityAfter = %d+,%s*PityRarity = "%a+",%s*Color = Color3.fromRGB%(%s*%d+,%s*%d+,%s*%d+%s*%),%s*Weights = (%b{})') do
	crates += 1
	local parsed = {}
	for rarity, weight in string.gmatch(weights, "(%a+) = ([%d%.]+)") do
		parsed[rarity] = tonumber(weight)
	end
	local odds = {}
	for _, row in Relics.odds(parsed) do
		odds[row.rarity] = row.chance
	end
	assert(odds.Celestial and odds.Celestial > 0 and odds.Celestial <= 0.01, crateId .. " Celestial chance out of range: " .. tostring(odds.Celestial))
	assert(odds.Astral and odds.Astral > 0 and odds.Astral <= 0.0012, crateId .. " Astral chance out of range: " .. tostring(odds.Astral))
	assert(odds.Astral < odds.Celestial, crateId .. " Astral must be rarer than Celestial")
end
assert(crates >= 9, "every crate checked, got " .. crates)
assert(Relics.chanceText(0.00005) == "1 in 20,000", "tiny chances read as 1 in N, got " .. Relics.chanceText(0.00005))
assert(Relics.chanceText(0.004) == "0.40%" and Relics.chanceText(0.25) == "25.0%", "percent formatting")

-- Daily Shop roll
local a = Shop.roll(1234567, 20000)
local b = Shop.roll(1234567, 20000)
local c = Shop.roll(1234567, 20001)
local d = Shop.roll(7654321, 20000)
assert(#a == Shop.SLOTS, "a full day of offers")
local same, differs, differsPlayer = true, false, false
local seen = {}
for index, offer in a do
	same = same and b[index].Id == offer.Id and b[index].Price == offer.Price
	differs = differs or c[index].Id ~= offer.Id
	differsPlayer = differsPlayer or d[index].Id ~= offer.Id
	assert(not seen[offer.Id], "offers are distinct within a day")
	seen[offer.Id] = true
	assert(offer.Slot == index and (offer.Currency == "Stardust" or offer.Currency == "Cores"), "slot and currency")
	assert(type(offer.Price) == "number" and offer.Price >= 1, "a real price")
	assert(offer.Deal == (index == 1), "only slot 1 is the deal")
end
assert(same, "the same player and day roll the same shop")
assert(differs and differsPlayer, "the shop changes by day and by player")
local deal = a[1]
local base = if deal.Kind == "Skin" then Shop.skin(deal.SkinId).Price.Amount else (function()
	for _, entry in Shop.POOL do
		if entry.Id == deal.Id then
			return entry.Price
		end
	end
	return 0
end)()
assert(deal.Price == math.max(1, math.floor(base * (1 - Shop.DEAL_DISCOUNT) + 0.5)), "the deal is discounted")
-- owned skins never show
local allSkins = {}
for _, skin in Shop.SKINS do
	allSkins[skin.Id] = true
end
for day = 19000, 19400 do
	for _, offer in Shop.roll(42, day, allSkins) do
		assert(offer.Kind ~= "Skin", "owned skins must not be offered")
	end
end
assert(Shop.remaining({ Slot = 2, Stock = 2 }, { ["2"] = 1 }) == 1 and Shop.remaining({ Slot = 2, Stock = 2 }, { ["2"] = 5 }) == 0, "stock counts down")
for _, entry in Shop.POOL do
	if entry.Kind == "Key" then
		assert(string.find(config, 'Id = "' .. entry.CrateId .. '"', 1, true), entry.Id .. " names an unknown crate")
	elseif entry.Kind == "Boost" then
		assert(string.find(config, "\n\t\t" .. entry.BoostId .. " = {", 1, true), entry.Id .. " names an unknown boost")
	elseif entry.Kind == "Skin" then
		assert(Shop.skin(entry.SkinId) ~= nil, entry.Id .. " names an unknown skin")
	elseif entry.Kind == "Cache" then
		assert(count[entry.Rarity] ~= nil and count[entry.Rarity] > 0, entry.Id .. " caches a rarity with no relics")
	end
end
assert(Shop.skin(Shop.DEFAULT_SKIN).Default == true, "Classic is the free default")

-- Fusion
local inventory = {
	A = { DefinitionId = "IonCoupler", Level = 3, Stars = 1 },
	B = { DefinitionId = "IonCoupler", Level = 9 },
	C = { DefinitionId = "IonCoupler", Level = 1 },
	D = { DefinitionId = "FluxLens", Level = 1 },
}
local target, fodder = Relics.fusionPair(inventory, { ["Machine:Forge"] = "B" }, "IonCoupler")
assert(target == "B" and fodder == "C", "the socketed copy keeps the result, the weakest spare goes, got " .. tostring(target) .. "/" .. tostring(fodder))
inventory.C.Locked = true
target, fodder = Relics.fusionPair(inventory, { ["Machine:Forge"] = "B" }, "IonCoupler")
assert(target == "B" and fodder == "A", "locked copies are never consumed")
local stars, level = Relics.fuse({ Stars = 1, Level = 2 }, { Stars = 2, Level = 7 })
assert(stars == 4 and level == 7, "fusing adds one star plus the spare's stars and keeps the better level")
assert(select(1, Relics.fuse({ Stars = 4 }, { Stars = 3 })) == 5, "stars cap at five")
local none, _, why = Relics.fusionPair({ X = { DefinitionId = "FluxLens", Level = 1, Stars = 5 }, Y = { DefinitionId = "FluxLens", Level = 1 } }, {}, "FluxLens")
assert(none == nil and why ~= nil, "a five-star relic can't take more")
assert(Relics.fusionPair({ D = inventory.D }, {}, "FluxLens") == nil, "one copy can't fuse")

-- Parity with the economy
for n = -1, 7 do
	assert(math.abs(Relics.starMultiplier({ MaxStars = 5, StarBonus = 0.25 }, n) - Envelope.StarMultiplier(n)) < 1e-9, "star multiplier parity at " .. n)
end
assert(Envelope.StarMultiplier(nil) == 1 and Envelope.StarMultiplier(0 / 0) == 1, "no stars, no change")
local items = { Definitions = definitions, CodexBonus = { Common = 0.01, Celestial = 0.06 } }
local discovered = {}
for _, definition in definitions do
	if definition.Rarity == "Common" or definition.Rarity == "Celestial" then
		discovered[definition.Id] = true
	end
end
local _, sharedBonus = Relics.codex(discovered, items)
assert(math.abs(sharedBonus - 0.07) < 1e-9, "completing Common and Celestial pays both, got " .. sharedBonus)
assert(math.abs(Envelope.CodexBonus(discovered, definitions, items.CodexBonus) - sharedBonus) < 1e-9, "codex parity with the economy")
assert(Envelope.CodexBonus({}, definitions, items.CodexBonus) == 0, "nothing found, no bonus")

-- Wiring
local protocol = fs.readFile("src/Shared/AstralForge/Shared/Protocol.luau")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local client = fs.readFile("src/Client/AstralForge/CoreKit.luau")
for _, action in { "BuyDailyOffer", "BuyCrateSkin", "EquipCrateSkin", "FuseRelics" } do
	assert(string.find(protocol, action .. ' = "' .. action .. '"', 1, true), action .. " in Protocol")
	assert(string.find(firewall, "Protocol.Actions." .. action, 1, true), action .. " in the firewall")
	assert(string.find(server, "Protocol.Actions." .. action .. " then", 1, true), action .. " dispatched by the server")
	assert(string.find(client, '["' .. action .. '"] = true', 1, true), action .. " allowed by the client")
end
assert(string.find(server, "ShopCatalog.roll(player.UserId, day, shop.Owned)", 1, true), "the server re-rolls the day's shop to validate a buy")
-- The roll leaves out the skins owned when the day began, so a mid-day skin buy can't reshuffle it.
do
	local Bag = require("../src/Server/AstralForge/Modules/ProfileBagMath")
	local profile = { Cosmetics = { CrateSkins = { Classic = true }, CrateSkin = "Classic" } }
	local shop = Bag.EnsureDailyShop(profile, 20000, profile.Cosmetics.CrateSkins)
	local before = Shop.roll(99, 20000, shop.Owned)
	profile.Cosmetics.CrateSkins.Crystal = true
	profile.Cosmetics.CrateSkins.Frost = true
	shop = Bag.EnsureDailyShop(profile, 20000, profile.Cosmetics.CrateSkins)
	assert(shop.Owned.Crystal == nil, "the day's owned-skin snapshot is fixed")
	local after = Shop.roll(99, 20000, shop.Owned)
	for index, offer in before do
		assert(after[index].Id == offer.Id, "a mid-day skin buy must not reshuffle the Daily Shop")
	end
	shop = Bag.EnsureDailyShop(profile, 20001, profile.Cosmetics.CrateSkins)
	assert(shop.Owned.Crystal == true and next(shop.Bought) == nil, "a new day re-snapshots and resets purchases")
	assert(string.find(fs.readFile("src/Client/AstralForge/pages/PagesShop.luau#StoreFront"), "ShopCatalog.roll(", 1, true), "the storefront shows the same roll")
end
assert(string.find(server, "DailyShop = {", 1, true) and string.find(server, "Cosmetics = {", 1, true) and string.find(server, "CodexBonus = Economy.CodexBonus(profile)", 1, true), "the snapshot carries the shop, cosmetics and codex")
local template = fs.readFile("src/Server/AstralForge/DataTemplate.luau")
assert(string.find(template, "DailyShop = { Day = -1, Bought = {} }", 1, true) and string.find(template, 'CrateSkin = "Classic"', 1, true), "new save bags have template defaults")
local data = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
assert(string.find(data, "instance.Stars", 1, true) and string.find(data, "EnsureCosmetics", 1, true), "stars and cosmetics are sanitized on load")

print("verify_shop_relics: ok")
