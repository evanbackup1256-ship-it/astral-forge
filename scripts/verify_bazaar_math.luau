--!strict
-- Astral Bazaar rules: the market's hourly stock is deterministic and well-formed, the lottery draw is fair
-- and weighted by tickets, contracts are stable per player and day, and the saved bag rebuilds from garbage.

local BazaarMath = require("../src/Server/AstralForge/Modules/BazaarMath")

-- --- black market ------------------------------------------------------------
for bucket = 0, 400 do
	local offers = BazaarMath.Offers(bucket)
	assert(#offers == BazaarMath.MARKET_OFFERS and #offers >= 24, "at least 24 shipments every hour")
	local seen: { [string]: boolean } = {}
	for _, offer in offers do
		assert(not seen[offer.Id], "no deal appears twice in an hour")
		seen[offer.Id] = true
		assert(offer.Discount >= 0.2 and offer.Discount <= 0.45, "discount between 20% and 45%")
		assert(offer.Stock >= 2 and offer.Stock <= 8, "stock between 2 and 8")
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

-- --- lottery -----------------------------------------------------------------
assert(BazaarMath.LotteryDraw({}, 0.5) == nil and BazaarMath.LotteryDraw({ [1] = 0 }, 0.5) == nil, "no tickets, no winner")
assert(BazaarMath.LotteryDraw({ [7] = 3 }, 0.99) == 7, "a lone holder always wins")
local counts: { [number]: number } = { 0, 0, 0 }
local tickets = { [1] = 1, [2] = 3, [3] = 6 }
for step = 0, 9999 do
	local winner = BazaarMath.LotteryDraw(tickets, step / 10000) :: number
	counts[winner] += 1
end
assert(counts[1] == 1000 and counts[2] == 3000 and counts[3] == 6000, "a draw is weighted exactly by tickets")
assert(BazaarMath.LotteryBucket(299) == 0 and BazaarMath.LotteryBucket(300) == 1, "lottery rounds")

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
	Contracts = { Day = 3, Baseline = { Deals = -1 }, Claimed = { deals = true, fake = true } },
	Counters = { Deals = math.huge, Tickets = -9 },
})
assert(dirty.Bank.Balance == 0 and dirty.Bank.Accrued == 0 and dirty.Bank.Term.Id == "" and dirty.Bank.Term.Principal == 0, "bank fields rebuild")
assert(BazaarMath.Ensure({ Bank = { Balance = "1.5e400" } }).Bank.Balance == "1.5e400", "a huge saved balance survives")
assert(BazaarMath.Ensure({ Bank = { Balance = "inf" } }).Bank.Balance == "inf", "an inf balance survives")
assert(dirty.Market.Bought.overdrive == 20 and dirty.Market.Bought[5] == nil, "market stock counts clamp")
assert(dirty.Contracts.Claimed.deals == true and dirty.Contracts.Claimed.fake == nil, "claims keep only real contracts")
assert(dirty.Counters.Deals == 0 and dirty.Counters.Tickets == 0, "non-finite counters become zero")

print("[TEST] bazaar math guards passed | market stock, bank terms, lottery weights, contracts, bag rebuild")
