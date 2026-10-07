--!strict
-- Astral Bazaar rules: hourly stock is deterministic, contracts are stable per player and day,
-- legacy lottery data is preserved without an active route or payout, and saved bags rebuild safely.

local fs = require("./_memberfs")(require("@lune/fs"))

local BazaarMath = require("../src/Server/AstralForge/Modules/BazaarMath")

-- --- black market ------------------------------------------------------------
for bucket = 0, 400 do
	local offers = BazaarMath.Offers(bucket)
	assert(#offers == BazaarMath.MARKET_OFFERS, "four deals every hour")
	local seen: { [string]: boolean } = {}
	for _, offer in offers do
		assert(not seen[offer.Id], "no deal appears twice in an hour")
		seen[offer.Id] = true
		assert(offer.Discount >= 0.2 and offer.Discount <= 0.45, "discount between 20% and 45%")
		assert(offer.Stock >= 1 and offer.Stock <= 3, "stock between 1 and 3")
		assert(offer.Seconds > 0 and type(offer.Reward) == "table", "a priced reward")
	end
end
local a, b = BazaarMath.Offers(77), BazaarMath.Offers(77)
for index = 1, #a do
	assert(a[index].Id == b[index].Id and a[index].Stock == b[index].Stock, "the same hour sells the same stock to everyone")
end
local differs = false
for bucket = 1, 50 do
	if BazaarMath.Offers(bucket)[1].Id ~= BazaarMath.Offers(0)[1].Id then
		differs = true
	end
end
assert(differs, "the stock changes from hour to hour")
assert(BazaarMath.OfferById(77, a[2].Id) ~= nil and BazaarMath.OfferById(77, "nope") == nil, "offer lookup")
assert(BazaarMath.MarketBucket(3599) == 0 and BazaarMath.MarketBucket(3600) == 1, "market hours")

-- --- bank --------------------------------------------------------------------
assert(BazaarMath.AccrualHours(-5) == 0 and BazaarMath.AccrualHours(7200) == 2, "interest hours")
assert(BazaarMath.AccrualHours(1e9) == BazaarMath.BANK.MaxAccrualHours, "interest stops building after a day")
assert(BazaarMath.TermById("T6").Hours == 6 and BazaarMath.TermById("T9") == nil, "terms")
for _, term in BazaarMath.BANK.Terms do
	assert(term.Rate > BazaarMath.BANK.SavingsRate, "a locked term pays more than savings")
end

-- The public Bazaar exposes no ticket purchase, draw, or chance-based currency payout.
local service = fs.readFile("src/Server/AstralForge/Services/BazaarService.luau")
local firewall = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local page = fs.readFile("src/Client/AstralForge/pages/PagesBazaar.luau")
assert(BazaarMath.LotteryDraw == nil and BazaarMath.LotteryBucket == nil, "lottery math must not ship")
assert(not string.find(service, "lotteryAct", 1, true), "lottery service path must not ship")
assert(not string.find(firewall, 'gameName ~= "Lottery"', 1, true), "remote firewall must reject lottery actions")
assert(not string.find(page, 'label = "Lottery"', 1, true), "public Bazaar must not advertise lottery")

-- --- contracts ---------------------------------------------------------------
for day = 0, 60 do
	local list = BazaarMath.ContractsFor(day, 1234)
	assert(#list == BazaarMath.CONTRACTS_PER_DAY, "three contracts a day")
	local seen: { [string]: boolean } = {}
	for _, contract in list do
		assert(not seen[contract.Id], "no contract twice in a day")
		seen[contract.Id] = true
	end
end
assert(BazaarMath.ContractsFor(5, 99)[1].Id == BazaarMath.ContractsFor(5, 99)[1].Id, "stable for a player and day")
for _, contract in BazaarMath.CONTRACTS do
	local known = false
	for _, name in BazaarMath.COUNTERS do
		known = known or name == contract.Counter
	end
	assert(known and contract.Target > 0, "every contract names a real counter")
end

-- --- the saved bag -----------------------------------------------------------
local clean = BazaarMath.Ensure(nil)
assert(clean.Bank.Balance == 0 and clean.Bank.Term.Id == "" and clean.Market.Bucket == -1 and clean.Contracts.Day == -1, "nil becomes a fresh bag")
for _, name in BazaarMath.COUNTERS do
	assert(clean.Counters[name] == 0, "every counter starts at zero")
end
local dirty = BazaarMath.Ensure({
	Bank = { Balance = "garbage", Accrued = math.huge, Since = "x", Term = { Id = "T99", Principal = -4, EndsAt = 0 / 0 } },
	Market = { Bucket = "x", Bought = { overdrive = 999, [5] = 1 } },
	Lottery = { PendingPrize = 12345 },
	Contracts = { Day = 3, Baseline = { Rounds = -1 }, Claimed = { rounds = true, fake = true } },
	Counters = { Rounds = math.huge, Wins = -9 },
})
assert(dirty.Bank.Balance == 0 and dirty.Bank.Accrued == 0 and dirty.Bank.Term.Id == "" and dirty.Bank.Term.Principal == 0, "bank fields rebuild")
assert(BazaarMath.Ensure({ Bank = { Balance = "1.5e400" } }).Bank.Balance == "1.5e400", "a huge saved balance survives")
assert(BazaarMath.Ensure({ Bank = { Balance = "inf" } }).Bank.Balance == "inf", "an inf balance survives")
assert(dirty.Market.Bought.overdrive == 20 and dirty.Market.Bought[5] == nil, "market stock counts clamp")
assert(dirty.Contracts.Claimed.rounds == true and dirty.Contracts.Claimed.fake == nil, "claims keep only real contracts")
assert(dirty.Counters.Rounds == 0 and dirty.Counters.Wins == 0, "non-finite counters become zero")
assert(dirty.Lottery.PendingPrize == 12345, "legacy records remain intact while no longer payable")

print("[TEST] bazaar math guards passed | market stock, bank terms, wager route removal, contracts, legacy preservation")
