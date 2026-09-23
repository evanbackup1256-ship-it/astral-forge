--!strict
-- Pure-module extract guards: CrateRoll / ShopGrantEligibility / CommandActionValidators.
-- Mirrors verify_anomaly_pulse style — require under Lune, assert behavior.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local CrateRoll = require("../src/Server/AstralForge/Modules/CrateRoll")
local ShopGrantEligibility = require("../src/Server/AstralForge/Modules/ShopGrantEligibility")
local CommandActionValidators = require("../src/Server/AstralForge/Modules/CommandActionValidators")

-- --- CrateRoll ---------------------------------------------------------------
assert(CrateRoll.MinimumRank(0, 10, 4) == 0, "pity before threshold → 0")
assert(CrateRoll.MinimumRank(9, 10, 4) == 4, "pity+1 hits threshold → pityRank")
assert(CrateRoll.MinimumRank(10, 10, 4) == 4, "pity past threshold stays")

local rarities = {
	Common = { Rank = 1 },
	Uncommon = { Rank = 2 },
	Rare = { Rank = 3 },
	Epic = { Rank = 4 },
	Legendary = { Rank = 5 },
	Mythic = { Rank = 6 },
}
local weights = { Common = 70, Uncommon = 20, Rare = 8, Epic = 2, Legendary = 0, Mythic = 0 }
assert(CrateRoll.TotalWeight(weights, rarities, 0) == 100, "full weight")
assert(CrateRoll.TotalWeight(weights, rarities, 3) == 10, "rare+ only")

assert(CrateRoll.SelectRarity(1, weights, rarities, 0, "Epic") == "Common", "low roll → common")
assert(CrateRoll.SelectRarity(71, weights, rarities, 0, "Epic") == "Uncommon", "mid roll → uncommon")
assert(CrateRoll.SelectRarity(91, weights, rarities, 0, "Epic") == "Rare", "high roll → rare")
assert(CrateRoll.SelectRarity(99, weights, rarities, 0, "Epic") == "Epic", "top roll → epic")
assert(CrateRoll.SelectRarity(1, weights, rarities, 3, "Epic") == "Rare", "pity floor skips common")

local defs = {
	{ Id = "A", Rarity = "Common" },
	{ Id = "B", Rarity = "Rare" },
	{ Id = "C", Rarity = "Rare" },
}
local candidates = CrateRoll.Candidates(defs, "Rare")
assert(#candidates == 2 and candidates[1].Id == "B", "rare candidates")
assert(CrateRoll.PickCandidate(candidates, 2).Id == "C", "pick index 2")
assert(CrateRoll.PickCandidate({}, 1) == nil, "empty candidates")

local rolledDef, rolledRarity, pityHit = CrateRoll.Roll(
	{ PityRarity = "Rare", PityAfter = 10, Weights = weights },
	9,
	rarities,
	defs,
	function()
		return 0.5
	end,
	function()
		return 1
	end
)
assert(rolledDef and rolledDef.Id == "B", "pity roll picks first rare")
assert(rolledRarity == "Rare" and pityHit == true, "rare at pity floor hits")

local count, countErr = CrateRoll.NormalizeOpenCount(nil)
assert(count == 1 and countErr == nil, "nil count → 1")
count, countErr = CrateRoll.NormalizeOpenCount(5)
assert(count == 5 and countErr == nil, "five ok")
count, countErr = CrateRoll.NormalizeOpenCount(3)
assert(count == nil and type(countErr) == "string", "three rejected")

assert(
	CrateRoll.GuaranteedRecycle(weights, true, false, {
		Common = true,
		Uncommon = true,
		Rare = true,
		Epic = true,
	}) == true,
	"all salvage"
)
assert(CrateRoll.GuaranteedRecycle(weights, true, false, { Common = true }) == false, "missing rarity")
assert(
	CrateRoll.GuaranteedRecycle(weights, true, true, {
		Common = true,
		Uncommon = true,
		Rare = true,
		Epic = true,
	}) == false,
	"keepNew blocks"
)
assert(CrateRoll.RequiredSlots(5, true) == 0, "recycle → 0 slots")
assert(CrateRoll.RequiredSlots(5, false) == 5, "keep → count slots")

-- --- ShopGrantEligibility ----------------------------------------------------
assert(ShopGrantEligibility.StockMax({ Id = "x", StockMax = 3 }) == 3, "stock max")
assert(ShopGrantEligibility.StockMax({ Id = "x" }) == 1, "default stock 1")
assert(ShopGrantEligibility.StockMax({ Id = "x", StockMax = 0 }) == 1, "zero → 1")
assert(ShopGrantEligibility.InventoryCount({ a = 1, b = 2 }) == 2, "inventory count")
assert(ShopGrantEligibility.RemainingStock(nil, 4) == 4, "nil stock → max")
assert(ShopGrantEligibility.RemainingStock(9.7, 4) == 4, "clamp to max")
assert(ShopGrantEligibility.RemainingStock(-2, 4) == 0, "clamp to 0")

assert(ShopGrantEligibility.StudioGrantAllowed(true) == true, "studio ok")
assert(ShopGrantEligibility.StudioGrantAllowed(false) == false, "live blocked")
assert(ShopGrantEligibility.ClampWheelGrant(nil) == 100, "wheel default")
assert(ShopGrantEligibility.ClampWheelGrant(999) == 500, "wheel cap")
assert(ShopGrantEligibility.ClampWheelGrant(0) == 1, "wheel floor")

local offer = { Id = "o1", Kind = "Key", Name = "Pack", Currency = "Cash", Price = 50, DailyRefresh = true }
local ok, reason = ShopGrantEligibility.EvaluateBuy(offer, 0, 0, 10, 100, function(n, c)
	return string.format("need %s %s", tostring(n), c)
end)
assert(ok == false and reason and string.find(reason, "daily", 1, true), "daily sold out")

ok, reason = ShopGrantEligibility.EvaluateBuy(
	{ Id = "o2", Kind = "Item", Price = 10, Currency = "Cash" },
	1,
	10,
	10,
	100,
	function()
		return "x"
	end
)
assert(ok == false and reason and string.find(reason, "full", 1, true), "inventory full")

ok, reason = ShopGrantEligibility.EvaluateBuy(offer, 1, 0, 10, 20, function(n, c)
	return string.format("need %d %s", n, c)
end)
assert(ok == false and reason == "need 30 Cash", "currency short")

ok, reason = ShopGrantEligibility.EvaluateBuy(offer, 1, 0, 10, 50, function()
	return "x"
end)
assert(ok == true and reason == nil, "eligible buy")

local shop: any = { Day = 9, Stock = { daily = 0, persist = 0 }, Purchased = {} }
local offers = {
	{ Id = "daily", StockMax = 2, DailyRefresh = true },
	{ Id = "persist", StockMax = 5, DailyRestock = 1 },
}
assert(ShopGrantEligibility.EnsureShop(shop, offers, 10) == true, "day roll changes")
assert(shop.Day == 10 and shop.Stock.daily == 2 and shop.Stock.persist == 1, "restocked")
shop.Stock.persist = 3
assert(ShopGrantEligibility.EnsureShop(shop, offers, 10) == false, "same day no-op")
shop.Purchased.persist = true
shop.Stock.persist = nil
assert(ShopGrantEligibility.EnsureShop(shop, offers, 10) == true, "missing stock filled")
assert(shop.Stock.persist == 0, "purchased → 0 stock")

-- --- CommandActionValidators -------------------------------------------------
assert(CommandActionValidators.IsValidAction("CollectVault") == true, "string action")
assert(CommandActionValidators.IsValidAction(nil) == false, "nil action")
assert(CommandActionValidators.IsValidAction("") == false, "empty action")
assert(CommandActionValidators.IsReadOnly("GetState") == true, "GetState read-only")
assert(CommandActionValidators.IsReadOnly("CollectVault") == false, "CollectVault mutates")
assert(CommandActionValidators.RequiresHighValueNonce("OpenItemCrate") == true, "crate high-value")
assert(CommandActionValidators.RequiresHighValueNonce("BuyMachine") == false, "buy not high-value")
assert(CommandActionValidators.IsDeferredSnapshot("Overcharge") == true, "overcharge deferred")
assert(CommandActionValidators.IsDeferredSnapshot("CollectVault") == false, "collect not deferred")

local highValueCount = 0
for _ in CommandActionValidators.HIGH_VALUE_GRANT do
	highValueCount += 1
end
assert(highValueCount == 7, "seven high-value grants")

-- --- Source wiring + HARD constraints ----------------------------------------
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local crateSrc = fs.readFile("src/Server/AstralForge/Modules/CrateRoll.luau")
local shopSrc = fs.readFile("src/Server/AstralForge/Modules/ShopGrantEligibility.luau")
local cmdSrc = fs.readFile("src/Server/AstralForge/Modules/CommandActionValidators.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(servicesSrc, "CrateRoll.Roll", 1, true), "ServerServices must delegate CrateRoll.Roll")
assert(string.find(servicesSrc, "CrateRoll.NormalizeOpenCount", 1, true), "ServerServices must normalize open count")
assert(string.find(servicesSrc, "ShopGrantEligibility.EnsureShop", 1, true), "ServerServices must EnsureShop")
assert(string.find(servicesSrc, "ShopGrantEligibility.EvaluateBuy", 1, true), "ServerServices must EvaluateBuy")
assert(string.find(servicesSrc, "CommandActionValidators.IsReadOnly", 1, true), "ServerServices must IsReadOnly")
assert(
	string.find(servicesSrc, "CommandActionValidators.RequiresHighValueNonce", 1, true),
	"ServerServices must RequiresHighValueNonce"
)
assert(not string.find(servicesSrc, "local HIGH_VALUE_GRANT_ACTIONS = {", 1, true), "inline HIGH_VALUE table must be removed")
assert(string.find(servicesSrc, "ShopGrantEligibility.StockMax", 1, true), "stock max delegates")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { servicesSrc, crateSrc, shopSrc, cmdSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
for _, body in { crateSrc, shopSrc, cmdSrc } do
	assert(not string.find(body, "GetService", 1, true), "pure modules must not call GetService")
end

print("[INFO] [TEST] serverservices extract passed | CrateRoll+ShopGrantEligibility+CommandActionValidators")
