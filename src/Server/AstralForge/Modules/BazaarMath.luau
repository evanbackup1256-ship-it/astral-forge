--!strict

local BazaarMath = {}

BazaarMath.BANK = table.freeze({
	SavingsRate = 0.03,
	CapSeconds = 7200,
	MaxAccrualHours = 24,
	Terms = table.freeze({
		table.freeze({ Id = "T1", Hours = 1, Rate = 0.04 }),
		table.freeze({ Id = "T6", Hours = 6, Rate = 0.05 }),
		table.freeze({ Id = "T24", Hours = 24, Rate = 0.06 }),
	}),
})

function BazaarMath.TermById(id: any): any
	for _, term in BazaarMath.BANK.Terms do
		if term.Id == id then
			return term
		end
	end
	return nil
end

function BazaarMath.AccrualHours(elapsed: number): number
	return math.clamp(elapsed / 3600, 0, BazaarMath.BANK.MaxAccrualHours)
end

BazaarMath.MARKET_SECONDS = 3600
BazaarMath.MARKET_OFFERS = 4

BazaarMath.CATALOG = table.freeze({
	table.freeze({ Id = "overdrive", Name = "Overdrive Cell", Reward = table.freeze({ Boost = "Overdrive" }), Seconds = 2400 }),
	table.freeze({ Id = "vaultsurge", Name = "Vault Surge Cell", Reward = table.freeze({ Boost = "VaultSurge" }), Seconds = 2400 }),
	table.freeze({ Id = "hyperdrive", Name = "Hyperdrive Cell", Reward = table.freeze({ Boost = "Hyperdrive" }), Seconds = 4200 }),
	table.freeze({ Id = "domainsurge", Name = "Domain Surge Cell", Reward = table.freeze({ Boost = "DomainSurge" }), Seconds = 5400 }),
	table.freeze({ Id = "stardust", Name = "Stardust Pouch", Reward = table.freeze({ Stardust = 40 }), Seconds = 6000 }),
	table.freeze({ Id = "stardustbig", Name = "Stardust Crate", Reward = table.freeze({ Stardust = 150 }), Seconds = 20000 }),
	table.freeze({ Id = "core", Name = "Loose Core", Reward = table.freeze({ Cores = 1 }), Seconds = 9000 }),
	table.freeze({ Id = "spins", Name = "Wheel Tokens", Reward = table.freeze({ FreeSpins = 3 }), Seconds = 3600 }),
	table.freeze({ Id = "keys", Name = "Forge Keys", Reward = table.freeze({ Keys = table.freeze({ ForgeCrate = 3 }) }), Seconds = 3000 }),
	table.freeze({ Id = "essence", Name = "Domain Essence", Reward = table.freeze({ Essence = 6 }), Seconds = 7000 }),
	table.freeze({ Id = "signals", Name = "Signal Burst", Reward = table.freeze({ Signals = 25 }), Seconds = 3200 }),
	table.freeze({ Id = "shield", Name = "Streak Shield", Reward = table.freeze({ StreakShield = 1 }), Seconds = 2800 }),
})

local function hash01(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

function BazaarMath.MarketBucket(now: number): number
	return math.floor(now / BazaarMath.MARKET_SECONDS)
end

function BazaarMath.Offers(bucket: number): { any }
	local pool = {}
	for index in BazaarMath.CATALOG do
		table.insert(pool, index)
	end
	for i = #pool, 2, -1 do
		local j = math.floor(hash01(bucket * 31 + i) * i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end
	local offers = {}
	for slot = 1, math.min(BazaarMath.MARKET_OFFERS, #pool) do
		local entry = BazaarMath.CATALOG[pool[slot]]
		table.insert(offers, {
			Id = entry.Id,
			Name = entry.Name,
			Reward = entry.Reward,
			Seconds = entry.Seconds,
			Discount = 0.2 + 0.25 * hash01(bucket * 17 + slot),
			Stock = 1 + math.floor(hash01(bucket * 53 + slot) * 3),
		})
	end
	return offers
end

function BazaarMath.OfferById(bucket: number, id: any): any
	for _, offer in BazaarMath.Offers(bucket) do
		if offer.Id == id then
			return offer
		end
	end
	return nil
end

BazaarMath.LOTTERY_SECONDS = 300
BazaarMath.LOTTERY_RAKE = 0.1
BazaarMath.LOTTERY_MAX_TICKETS = 20

BazaarMath.LOTTERY_TICKET_SHARE = 0.01

function BazaarMath.LotteryDraw(tickets: { [number]: number }, roll: number): number?
	local total = 0
	local ids = {}
	for userId, count in tickets do
		if count > 0 then
			total += count
			table.insert(ids, userId)
		end
	end
	if total <= 0 then
		return nil
	end
	table.sort(ids)
	local target = math.clamp(roll, 0, 0.9999999) * total
	for _, userId in ids do
		target -= tickets[userId]
		if target < 0 then
			return userId
		end
	end
	return ids[#ids]
end

function BazaarMath.LotteryBucket(now: number): number
	return math.floor(now / BazaarMath.LOTTERY_SECONDS)
end

BazaarMath.CONTRACTS = table.freeze({
	table.freeze({ Id = "deals", Name = "Haggler", Text = "Buy black market deals", Counter = "Deals", Target = 2, Reward = table.freeze({ CashMinutes = 12, Stardust = 8 }) }),
	table.freeze({ Id = "deposits", Name = "Saver", Text = "Make bank deposits", Counter = "Deposits", Target = 2, Reward = table.freeze({ CashMinutes = 6, Stardust = 5 }) }),
	table.freeze({ Id = "tickets", Name = "Gambler", Text = "Buy lottery tickets", Counter = "Tickets", Target = 5, Reward = table.freeze({ CashMinutes = 8, FreeSpins = 1 }) }),
	table.freeze({ Id = "interest", Name = "Collector", Text = "Collect bank interest", Counter = "Interest", Target = 3, Reward = table.freeze({ CashMinutes = 7, Stardust = 6 }) }),
})
BazaarMath.CONTRACTS_PER_DAY = 3
BazaarMath.COUNTERS = table.freeze({ "Deals", "Deposits", "Tickets", "Interest" })

function BazaarMath.ContractsFor(day: number, userId: number): { any }
	local pool = {}
	for index in BazaarMath.CONTRACTS do
		table.insert(pool, index)
	end
	for i = #pool, 2, -1 do
		local j = math.floor(hash01(day * 19 + userId * 0.37 + i) * i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end
	local list = {}
	for slot = 1, BazaarMath.CONTRACTS_PER_DAY do
		table.insert(list, BazaarMath.CONTRACTS[pool[slot]])
	end
	return list
end

function BazaarMath.ContractById(id: any): any
	for _, contract in BazaarMath.CONTRACTS do
		if contract.Id == id then
			return contract
		end
	end
	return nil
end

local function count(value: any, ceiling: number?): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.clamp(math.floor(n), 0, ceiling or 1e9)
end

local function persist(value: any): number | string
	if type(value) == "string" and #value <= 40 and (value == "inf" or (string.match(value, "^[%d%.eE%+]+$") ~= nil and tonumber(value) ~= nil)) then
		return value
	end
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge or n < 0 then
		return 0
	end
	return n
end

function BazaarMath.Ensure(bag: any): any
	local source = if type(bag) == "table" then bag else {}
	local bank = if type(source.Bank) == "table" then source.Bank else {}
	local term = if type(bank.Term) == "table" then bank.Term else {}
	local market = if type(source.Market) == "table" then source.Market else {}
	local contracts = if type(source.Contracts) == "table" then source.Contracts else {}
	local counters = if type(source.Counters) == "table" then source.Counters else {}
	local bought = {}
	if type(market.Bought) == "table" then
		for id, amount in market.Bought do
			if type(id) == "string" and #id <= 24 then
				bought[id] = count(amount, 20)
			end
		end
	end
	local baseline, claimed = {}, {}
	if type(contracts.Baseline) == "table" then
		for _, name in BazaarMath.COUNTERS do
			baseline[name] = count(contracts.Baseline[name])
		end
	end
	if type(contracts.Claimed) == "table" then
		for id in contracts.Claimed do
			if BazaarMath.ContractById(id) ~= nil then
				claimed[id] = true
			end
		end
	end
	local clean = {}
	for _, name in BazaarMath.COUNTERS do
		clean[name] = count(counters[name])
	end
	return {
		Bank = {
			Balance = persist(bank.Balance),
			Accrued = persist(bank.Accrued),
			Since = math.floor(tonumber(bank.Since) or 0),
			Term = {
				Id = if BazaarMath.TermById(term.Id) ~= nil then term.Id else "",
				Principal = persist(term.Principal),
				EndsAt = math.floor(tonumber(term.EndsAt) or 0),
			},
		},
		Market = { Bucket = math.floor(tonumber(market.Bucket) or -1), Bought = bought },
		Lottery = { PendingPrize = persist(if type(source.Lottery) == "table" then source.Lottery.PendingPrize else 0) },
		Contracts = { Day = math.floor(tonumber(contracts.Day) or -1), Baseline = baseline, Claimed = claimed },
		Counters = clean,
	}
end

return table.freeze(BazaarMath)
