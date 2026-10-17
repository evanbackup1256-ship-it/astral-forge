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
BazaarMath.MARKET_OFFERS = 24
BazaarMath.RECEIPT_BUCKETS = 2

export type MarketOrder = {
	Game: string,
	Pick: string,
	Bucket: number,
	Quantity: number,
	UnitPrice: number | string,
	Currency: string,
	RequestId: string,
	Rotation: string,
}

function BazaarMath.ValidQuote(value: any): boolean
	if type(value) == "number" then
		return value == value and value > 0 and value < math.huge
	end
	if type(value) ~= "string" or #value > 40 then return false end
	local mantissa, exponent = value:match("^(%d*%.?%d+)[eE]([%+%-]?%d+)$")
	if mantissa and exponent then
		local m, e = tonumber(mantissa), tonumber(exponent)
		return m ~= nil and m > 0 and m < math.huge and e ~= nil and math.abs(e) < 1e18
	end
	if not value:match("^%d*%.?%d+$") then return false end
	local parsed = tonumber(value)
	return parsed ~= nil and parsed > 0 and parsed < math.huge
end

function BazaarMath.ReadOrder(payload: any): (MarketOrder?, string?)
	if type(payload) ~= "table" or payload.Game ~= "Market" then return nil, "Only the Black Market is open." end
	if type(payload.Pick) ~= "string" or #payload.Pick < 2 or #payload.Pick > 24 then return nil, "Choose a listed supply." end
	if type(payload.Bucket) ~= "number" or payload.Bucket ~= payload.Bucket or payload.Bucket < 0
		or payload.Bucket > 1e12 or payload.Bucket % 1 ~= 0 then return nil, "Review the shipment before buying." end
	if type(payload.Quantity) ~= "number" or payload.Quantity ~= payload.Quantity or payload.Quantity % 1 ~= 0
		or payload.Quantity < 1 or payload.Quantity > 8 then return nil, "Choose between 1 and 8 units." end
	if type(payload.RequestId) ~= "string" or #payload.RequestId < 8 or #payload.RequestId > 64 then
		return nil, "The order needs a valid request ID."
	end
	if payload.Currency ~= "Flux" or not BazaarMath.ValidQuote(payload.UnitPrice) then
		return nil, "Review the order's currency and price."
	end
	if type(payload.Rotation) ~= "string" or #payload.Rotation < 3 or #payload.Rotation > 64 then
		return nil, "Refresh the shipment before buying."
	end
	return {
		Game = "Market", Pick = payload.Pick, Bucket = payload.Bucket, Quantity = payload.Quantity,
		UnitPrice = payload.UnitPrice, Currency = "Flux", RequestId = payload.RequestId, Rotation = payload.Rotation,
	}, nil
end

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
	table.freeze({ Id = "dustsmall", Name = "Pocket Stardust", Reward = table.freeze({ Stardust = 12 }), Seconds = 1800 }),
	table.freeze({ Id = "dustbulk", Name = "Stardust Shipment", Reward = table.freeze({ Stardust = 300 }), Seconds = 40000 }),
	table.freeze({ Id = "corepair", Name = "Core Pair", Reward = table.freeze({ Cores = 2 }), Seconds = 18000 }),
	table.freeze({ Id = "corecase", Name = "Core Case", Reward = table.freeze({ Cores = 5 }), Seconds = 45000 }),
	table.freeze({ Id = "essencebag", Name = "Essence Satchel", Reward = table.freeze({ Essence = 15 }), Seconds = 17500 }),
	table.freeze({ Id = "essencecase", Name = "Essence Shipment", Reward = table.freeze({ Essence = 40 }), Seconds = 46500 }),
	table.freeze({ Id = "fragmentbag", Name = "Anomaly Fragments", Reward = table.freeze({ Fragments = 5 }), Seconds = 6000 }),
	table.freeze({ Id = "fragmentcase", Name = "Fragment Crate", Reward = table.freeze({ Fragments = 20 }), Seconds = 24000 }),
	table.freeze({ Id = "crystalkeys", Name = "Crystal Keys", Reward = table.freeze({ Keys = table.freeze({ CrystalCrate = 2 }) }), Seconds = 6000 }),
	table.freeze({ Id = "nebulakey", Name = "Nebula Key", Reward = table.freeze({ Keys = table.freeze({ NebulaCrate = 1 }) }), Seconds = 7000 }),
	table.freeze({ Id = "orbitkeys", Name = "Orbit Keys", Reward = table.freeze({ Keys = table.freeze({ OrbitCrate = 2 }) }), Seconds = 9000 }),
	table.freeze({ Id = "aetherkey", Name = "Aether Key", Reward = table.freeze({ Keys = table.freeze({ AetherCrate = 1 }) }), Seconds = 7500 }),
	table.freeze({ Id = "horizonkey", Name = "Horizon Key", Reward = table.freeze({ Keys = table.freeze({ HorizonCrate = 1 }) }), Seconds = 10000 }),
	table.freeze({ Id = "singularitykey", Name = "Singularity Key", Reward = table.freeze({ Keys = table.freeze({ SingularityCrate = 1 }) }), Seconds = 30000 }),
	table.freeze({ Id = "echokey", Name = "Echo Key", Reward = table.freeze({ Keys = table.freeze({ EchoCrate = 1 }) }), Seconds = 35000 }),
	table.freeze({ Id = "driftkey", Name = "Drift Key", Reward = table.freeze({ Keys = table.freeze({ DriftCrate = 1 }) }), Seconds = 30000 }),
	table.freeze({ Id = "signalpack", Name = "Signal Bundle", Reward = table.freeze({ Signals = 75 }), Seconds = 9600 }),
	table.freeze({ Id = "signalcase", Name = "Signal Shipment", Reward = table.freeze({ Signals = 200 }), Seconds = 25600 }),
	table.freeze({ Id = "commandnotes", Name = "Command Field Notes", Reward = table.freeze({ CommandXP = 50 }), Seconds = 6000 }),
	table.freeze({ Id = "commandcharts", Name = "Command Survey Log", Reward = table.freeze({ CommandXP = 150 }), Seconds = 18000 }),
	table.freeze({ Id = "shieldpair", Name = "Spare Streak Shields", Reward = table.freeze({ StreakShield = 2 }), Seconds = 5600 }),
	table.freeze({ Id = "spinsingle", Name = "Wheel Token", Reward = table.freeze({ FreeSpins = 1 }), Seconds = 1200 }),
	table.freeze({ Id = "spincase", Name = "Wheel Token Case", Reward = table.freeze({ FreeSpins = 6 }), Seconds = 7200 }),
	table.freeze({ Id = "forgekit", Name = "Forge Supply Kit", Reward = table.freeze({ Stardust = 20, Keys = table.freeze({ ForgeCrate = 2 }) }), Seconds = 5000 }),
})

function BazaarMath.Category(reward: any): string
	if reward.Keys then return "Keys" end
	if reward.Boost then return "Boosts" end
	if reward.Signals or reward.CommandXP or reward.StreakShield then return "Command" end
	if reward.FreeSpins then return "Tokens" end
	return "Resources"
end

BazaarMath.RARE = table.freeze({
	table.freeze({ Id = "rare_vaultcache", Name = "Sealed Vault Cache", Reward = table.freeze({ Cores = 6, Stardust = 120 }), Seconds = 60000 }),
	table.freeze({ Id = "rare_keyring", Name = "Singularity Key Ring", Reward = table.freeze({ Keys = table.freeze({ SingularityCrate = 2 }) }), Seconds = 52000 }),
	table.freeze({ Id = "rare_ledger", Name = "Quartermaster Ledger", Reward = table.freeze({ CommandXP = 400, Signals = 150 }), Seconds = 40000 }),
	table.freeze({ Id = "rare_essence", Name = "Pressurised Essence", Reward = table.freeze({ Essence = 90 }), Seconds = 90000 }),
	table.freeze({ Id = "rare_tokencrate", Name = "Wheel Token Crate", Reward = table.freeze({ FreeSpins = 12 }), Seconds = 13000 }),
	table.freeze({ Id = "rare_fragments", Name = "Anomaly Strongbox", Reward = table.freeze({ Fragments = 60 }), Seconds = 66000 }),
})
BazaarMath.RARE_CHANCE = 0.45
BazaarMath.RARE_DISCOUNT = 0.15

BazaarMath.MERCHANTS = table.freeze({
	table.freeze({ Id = "vess", Name = "Vess Calder", Title = "Salvage broker", Favors = "Resources", Accent = table.freeze({ 214, 160, 96 }),
		Line = "Everything on this table came off a wreck. None of it is sentimental." }),
	table.freeze({ Id = "orrin", Name = "Orrin Hale", Title = "Key cutter", Favors = "Keys", Accent = table.freeze({ 150, 190, 230 }),
		Line = "Bring me a lock and I'll tell you what it's hiding. Bring flux and I'll skip the story." }),
	table.freeze({ Id = "sable", Name = "Sable Rook", Title = "Signal runner", Favors = "Command", Accent = table.freeze({ 176, 140, 220 }),
		Line = "Quiet channels usually cost extra. This hour, they don't." }),
	table.freeze({ Id = "tamsin", Name = "Tamsin Ferro", Title = "Engine fixer", Favors = "Boosts", Accent = table.freeze({ 230, 120, 90 }),
		Line = "Runs hot, runs fast. Don't ask where the cells were before me." }),
	table.freeze({ Id = "pell", Name = "Pell Morrow", Title = "Token dealer", Favors = "Tokens", Accent = table.freeze({ 225, 140, 180 }),
		Line = "Spin it yourself. I only sell the chances." }),
})

BazaarMath.REPUTATION = table.freeze({
	table.freeze({ Name = "Stranger", At = 0, Bonus = 0 }),
	table.freeze({ Name = "Regular", At = 10, Bonus = 1 }),
	table.freeze({ Name = "Trusted", At = 40, Bonus = 2 }),
	table.freeze({ Name = "Insider", At = 120, Bonus = 3 }),
})
BazaarMath.PROCURE_TIER = 2
BazaarMath.PROCURE_BUCKETS = 24
BazaarMath.PROCURE_DISCOUNT = 0.2
BazaarMath.PROCURE_STOCK = 2

function BazaarMath.Reputation(units: any): (any, number, any)
	local n = tonumber(units) or 0
	local index = 1
	for i, tier in BazaarMath.REPUTATION do
		if n >= tier.At then index = i end
	end
	return BazaarMath.REPUTATION[index], index, BazaarMath.REPUTATION[index + 1]
end

function BazaarMath.CatalogById(id: any): any
	for _, entry in BazaarMath.CATALOG do
		if entry.Id == id then return entry end
	end
	for _, entry in BazaarMath.RARE do
		if entry.Id == id then return entry end
	end
	return nil
end

function BazaarMath.RegularById(id: any): any
	for _, entry in BazaarMath.CATALOG do
		if entry.Id == id then return entry end
	end
	return nil
end

function BazaarMath.Holdings(profile: any, reward: any): { any }
	local rows = {}
	local function add(label: string, amount: any)
		table.insert(rows, { Label = label, Count = amount or 0 })
	end
	if reward.Stardust then add("Stardust", profile.Stardust) end
	if reward.Cores then add("Cores", profile.Cores) end
	if reward.Essence then add("Domain essence", profile.Domain and profile.Domain.Essence) end
	if reward.Fragments then add("Anomaly fragments", profile.Anomaly and profile.Anomaly.Fragments) end
	if reward.FreeSpins then add("Wheel tokens", profile.Wheel and profile.Wheel.FreeSpins) end
	if reward.Signals then add("Signals", profile.Command and profile.Command.Signals) end
	if reward.CommandXP then add("Command XP", profile.Command and profile.Command.XP) end
	if reward.StreakShield then add("Streak shields", profile.Command and profile.Command.StreakShields) end
	if reward.Boost then add("Stored boost cells", profile.BoostInventory and profile.BoostInventory[reward.Boost]) end
	if reward.Keys then
		for crate in reward.Keys do
			add(crate:gsub("Crate$", "") .. " keys", profile.Items and profile.Items.Keys and profile.Items.Keys[crate])
		end
	end
	return rows
end

local function hash01(n: number): number
	local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
	return x - math.floor(x)
end

function BazaarMath.MarketBucket(now: number): number
	return math.floor(now / BazaarMath.MARKET_SECONDS)
end

function BazaarMath.Offers(bucket: number, limit: number?): { any }
	local pool = {}
	for index in BazaarMath.CATALOG do
		table.insert(pool, index)
	end
	for i = #pool, 2, -1 do
		local j = math.floor(hash01(bucket * 31 + i) * i) + 1
		pool[i], pool[j] = pool[j], pool[i]
	end
	local offers = {}
	for slot = 1, math.min(limit or BazaarMath.MARKET_OFFERS, #pool) do
		local entry = BazaarMath.CATALOG[pool[slot]]
		table.insert(offers, {
			Id = entry.Id,
			Name = entry.Name,
			Reward = entry.Reward,
			Category = BazaarMath.Category(entry.Reward),
			Seconds = entry.Seconds,
			Discount = 0.2 + 0.25 * hash01(bucket * 17 + slot),
			Stock = 2 + math.floor(hash01(bucket * 53 + slot) * 7),
		})
	end
	return offers
end

function BazaarMath.OfferById(bucket: number, id: any, limit: number?): any
	for _, offer in BazaarMath.Offers(bucket, limit) do
		if offer.Id == id then
			return offer
		end
	end
	return nil
end

function BazaarMath.Merchant(bucket: number): any
	return BazaarMath.MERCHANTS[math.floor(hash01(bucket * 7 + 11) * #BazaarMath.MERCHANTS) + 1]
end

function BazaarMath.RareOffer(bucket: number): any
	if hash01(bucket * 13 + 5) >= BazaarMath.RARE_CHANCE then return nil end
	local entry = BazaarMath.RARE[math.floor(hash01(bucket * 29 + 3) * #BazaarMath.RARE) + 1]
	return {
		Id = entry.Id, Name = entry.Name, Reward = entry.Reward, Category = "Rare", Seconds = entry.Seconds,
		Discount = BazaarMath.RARE_DISCOUNT, Stock = 1, Rare = true,
	}
end

function BazaarMath.ProcuredOffer(procure: any, bucket: number, regular: { any }): any
	if type(procure) ~= "table" or type(procure.Id) ~= "string" or procure.Id == "" then return nil end
	if bucket <= procure.Since or bucket > procure.Since + BazaarMath.PROCURE_BUCKETS then return nil end
	if procure.Filled > 0 and procure.Filled ~= bucket then return nil end
	for _, offer in regular do
		if offer.Id == procure.Id then return nil end
	end
	local entry = BazaarMath.RegularById(procure.Id)
	if not entry then return nil end
	return {
		Id = entry.Id, Name = entry.Name, Reward = entry.Reward, Category = BazaarMath.Category(entry.Reward),
		Seconds = entry.Seconds, Discount = BazaarMath.PROCURE_DISCOUNT, Stock = BazaarMath.PROCURE_STOCK, Procured = true,
	}
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
	local procure = if type(market.Procure) == "table" then market.Procure else {}
	local bought = {}
	if type(market.Bought) == "table" then
		for id, amount in market.Bought do
			if type(id) == "string" and #id <= 24 then
				bought[id] = count(amount, 20)
			end
		end
	end
	local baseline, claimed = {}, {}
	local saved, history = {}, {}
	if type(market.Saved) == "table" then
		for id, selected in market.Saved do
			if selected == true and BazaarMath.CatalogById(id) then saved[id] = true end
		end
	end
	if type(market.History) == "table" then
		for _, entry in ipairs(market.History) do
			if #history >= 50 then break end
			if type(entry) == "table" and BazaarMath.CatalogById(entry.Pick)
				and type(entry.RequestId) == "string" and #entry.RequestId >= 8 and #entry.RequestId <= 64
				and count(entry.Quantity, 8) >= 1 then
				table.insert(history, {
					RequestId = entry.RequestId, Pick = entry.Pick, Quantity = count(entry.Quantity, 8),
					Cost = persist(entry.Cost), At = count(entry.At, 1e12),
				})
			end
		end
	end
	local receipts = {}
	if type(market.Receipts) == "table" then
		local ids = {}
		for id, receipt in market.Receipts do
			if type(id) == "string" and type(receipt) == "table" then table.insert(ids, id) end
		end
		table.sort(ids, function(a, b)
			local left = count(market.Receipts[a].Bucket or market.Bucket, 1e12)
			local right = count(market.Receipts[b].Bucket or market.Bucket, 1e12)
			return if left == right then a < b else left > right
		end)
		local length = 0
		for _, id in ids do
			if length >= #BazaarMath.CATALOG * 8 * BazaarMath.RECEIPT_BUCKETS then break end
			local receipt = market.Receipts[id]
			if type(id) == "string" and #id >= 8 and #id <= 64 and type(receipt) == "table"
				and type(receipt.Pick) == "string" and #receipt.Pick <= 24 and type(receipt.Message) == "string"
				and count(receipt.Quantity, 8) >= 1 then
				receipts[id] = {
					Pick = receipt.Pick, Quantity = count(receipt.Quantity, 8),
					Cost = persist(receipt.Cost), Left = count(receipt.Left, 12), Message = receipt.Message:sub(1, 512),
					Bucket = count(receipt.Bucket or market.Bucket, 1e12),
					Rotation = if type(receipt.Rotation) == "string" then receipt.Rotation:sub(1, 64) else "",
				}
				length += 1
			end
		end
	end
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
		Market = {
			Bucket = math.floor(tonumber(market.Bucket) or -1), Bought = bought,
			Refunded = persist(market.Refunded),
			RefundedRolloverAt = count(market.RefundedRolloverAt, 1e12),
			RefundedTicketsAt = count(market.RefundedTicketsAt, 1e12),
			Receipts = receipts,
			Saved = saved, History = history,
			Procure = {
				Id = if type(procure.Id) == "string" and BazaarMath.RegularById(procure.Id) then procure.Id else "",
				Since = count(procure.Since, 1e12), Filled = count(procure.Filled, 1e12),
			},
		},
		Lottery = { PendingPrize = persist(if type(source.Lottery) == "table" then source.Lottery.PendingPrize else 0) },
		Contracts = { Day = math.floor(tonumber(contracts.Day) or -1), Baseline = baseline, Claimed = claimed, Retired = contracts.Retired == true },
		Counters = clean,
	}
end

return table.freeze(BazaarMath)
