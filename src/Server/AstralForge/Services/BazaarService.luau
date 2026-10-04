--!strict

return function(loadService: (string) -> any)
	local Players = game:GetService("Players")

	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local BazaarMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("BazaarMath"))
	local ProgressionService = loadService("ProgressionService")

	local BazaarService = {}

	local DAY = 86400
	local DEPOSIT_SHARES = { 0.1, 0.25, 0.5, 1 }
	local WITHDRAW_SHARES = { 0.25, 0.5, 1 }
	local TICKET_BATCH = { 1, 5, 20 }

	local lottery = { Bucket = -1, Tickets = {} :: { [number]: number }, Pot = 0 :: any, Last = nil :: any, Pending = {} :: { [number]: any } }

	local function day(now: number): number
		return math.floor(now / DAY)
	end

	local function ensure(profile): any
		profile.Bazaar = BazaarMath.Ensure(profile.Bazaar)
		return profile.Bazaar
	end

	local function take(profile, amount: any): boolean
		if not Economy.Gte(profile.Cash, amount) then
			return false
		end
		profile.Cash = Economy.Sub(profile.Cash, amount)
		return true
	end

	local function bump(bazaar, counter: string, amount: number?)
		bazaar.Counters[counter] = math.min(1e9, bazaar.Counters[counter] + (amount or 1))
	end

	local function production(profile): any
		return Economy.SteadyProduction(profile)
	end

	local function bankCap(profile): any
		return Economy.Max(1000, Economy.Mul(production(profile), BazaarMath.BANK.CapSeconds))
	end

	local function accrue(profile, bazaar, now: number)
		local bank = bazaar.Bank
		if bank.Since <= 0 then
			bank.Since = now
			return
		end
		local hours = BazaarMath.AccrualHours(now - bank.Since)
		bank.Since = now
		if hours <= 0 or not Economy.Gt(bank.Balance, 0) then
			return
		end
		local base = Economy.Min(bank.Balance, bankCap(profile))
		bank.Accrued = Economy.Persist(Economy.Add(bank.Accrued, Economy.Mul(base, BazaarMath.BANK.SavingsRate * hours)))
	end

	local function contractsFor(profile, bazaar, now: number, userId: number)
		local contracts = bazaar.Contracts
		if contracts.Day ~= day(now) then
			contracts.Day, contracts.Claimed = day(now), {}
			contracts.Baseline = {}
			for _, name in BazaarMath.COUNTERS do
				contracts.Baseline[name] = 0
			end
			local casino = profile.Casino
			contracts.Baseline.Rounds = if type(casino) == "table" then math.floor(tonumber(casino.Played) or 0) else 0
			contracts.Baseline.Wins = if type(casino) == "table" then math.floor(tonumber(casino.Won) or 0) else 0
			for _, name in { "Deals", "Deposits", "Tickets", "Interest" } do
				contracts.Baseline[name] = bazaar.Counters[name]
			end
		end
		return BazaarMath.ContractsFor(contracts.Day, userId)
	end

	local function currentOf(profile, bazaar, counter: string): number
		local casino = profile.Casino
		if counter == "Rounds" then
			return if type(casino) == "table" then math.floor(tonumber(casino.Played) or 0) else 0
		elseif counter == "Wins" then
			return if type(casino) == "table" then math.floor(tonumber(casino.Won) or 0) else 0
		end
		return bazaar.Counters[counter]
	end

	local function present(userId: number): boolean
		return Players:GetPlayerByUserId(userId) ~= nil
	end

	local function lotteryTick(now: number, random: Random?)
		local bucket = BazaarMath.LotteryBucket(now)
		if lottery.Bucket < 0 then
			lottery.Bucket = bucket
			return
		end
		if bucket <= lottery.Bucket then
			return
		end
		local entries: { [number]: number } = {}
		for userId, count in lottery.Tickets do
			if present(userId) then
				entries[userId] = count
			end
		end
		local roll = if random ~= nil then random:NextNumber() else math.random()
		local winner = BazaarMath.LotteryDraw(entries, roll)
		if winner ~= nil and Economy.Gt(lottery.Pot, 0) then
			local prize = Economy.Floor(Economy.Mul(lottery.Pot, 1 - BazaarMath.LOTTERY_RAKE))
			lottery.Pending[winner] = Economy.Add(lottery.Pending[winner] or 0, prize)
			local who = Players:GetPlayerByUserId(winner)
			lottery.Last = { Winner = if who then who.DisplayName else "Someone", UserId = winner, Prize = Economy.Persist(prize), Bucket = lottery.Bucket }
			lottery.Pot = 0
		end
		lottery.Tickets = {}
		lottery.Bucket = bucket
	end

	local function ticketPrice(profile): any
		return Economy.Max(100, Economy.Floor(Economy.Mul(profile.Cash, BazaarMath.LOTTERY_TICKET_SHARE)))
	end

	local function myTickets(userId: number): number
		return lottery.Tickets[userId] or 0
	end

	local function bankAct(profile, bazaar, payload, now: number): (boolean, string, any?)
		local bank = bazaar.Bank
		accrue(profile, bazaar, now)
		local op = payload.Op
		if op == "Deposit" then
			local share = DEPOSIT_SHARES[tonumber(payload.Tier) or 0]
			if share == nil then
				return false, "Pick how much to deposit."
			end
			local amount = Economy.Floor(Economy.Mul(profile.Cash, share))
			if not Economy.Gt(amount, 0) or not take(profile, amount) then
				return false, "Nothing to deposit."
			end
			bank.Balance = Economy.Persist(Economy.Add(bank.Balance, amount))
			bump(bazaar, "Deposits")
			return true, "Deposited.", { Game = "Bank", Amount = Economy.Persist(amount) }
		elseif op == "Withdraw" then
			local share = WITHDRAW_SHARES[tonumber(payload.Tier) or 0]
			if share == nil then
				return false, "Pick how much to withdraw."
			end
			local amount = Economy.Floor(Economy.Mul(bank.Balance, share))
			if not Economy.Gt(amount, 0) then
				return false, "Your savings are empty."
			end
			bank.Balance = Economy.Persist(Economy.Sub(bank.Balance, amount))
			profile.Cash = Economy.Add(profile.Cash, amount)
			return true, "Withdrawn.", { Game = "Bank", Amount = Economy.Persist(amount) }
		elseif op == "Collect" then
			if not Economy.Gt(bank.Accrued, 0) then
				return false, "No interest to collect yet."
			end
			local amount = Economy.Floor(bank.Accrued)
			if not Economy.Gt(amount, 0) then
				return false, "No interest to collect yet."
			end
			bank.Accrued = 0
			profile.Cash = Economy.Add(profile.Cash, amount)
			bump(bazaar, "Interest")
			return true, "Interest collected.", { Game = "Bank", Amount = Economy.Persist(amount), Interest = true }
		elseif op == "Term" then
			local term = BazaarMath.TermById(payload.Term)
			local share = DEPOSIT_SHARES[tonumber(payload.Tier) or 0]
			if term == nil or share == nil then
				return false, "Pick a term and an amount."
			end
			if bank.Term.Id ~= "" then
				return false, "You already have a term deposit open."
			end
			local amount = Economy.Floor(Economy.Mul(profile.Cash, share))
			if not Economy.Gt(amount, 0) or not take(profile, amount) then
				return false, "Nothing to lock away."
			end
			bank.Term = { Id = term.Id, Principal = Economy.Persist(amount), EndsAt = now + term.Hours * 3600 }
			bump(bazaar, "Deposits")
			return true, `Locked for {term.Hours} hour{if term.Hours == 1 then "" else "s"}.`, { Game = "Bank", Amount = Economy.Persist(amount) }
		elseif op == "Redeem" or op == "Break" then
			local open = bank.Term
			local term = BazaarMath.TermById(open.Id)
			if term == nil then
				return false, "You have no term deposit."
			end
			local matured = now >= open.EndsAt
			if op == "Redeem" and not matured then
				return false, "That term has not matured yet."
			end
			local payout = open.Principal
			if matured then
				local interest = Economy.Floor(Economy.Mul(Economy.Min(open.Principal, bankCap(profile)), term.Rate * term.Hours))
				payout = Economy.Add(open.Principal, interest)
			end
			profile.Cash = Economy.Add(profile.Cash, payout)
			bank.Term = { Id = "", Principal = 0, EndsAt = 0 }
			if matured then
				bump(bazaar, "Interest")
			end
			return true, if matured then "Term paid out." else "Term broken: principal returned, no interest.", { Game = "Bank", Amount = Economy.Persist(payout), Interest = matured }
		end
		return false, "Unknown bank move."
	end

	local function marketAct(profile, bazaar, payload, now: number): (boolean, string, any?)
		local market = bazaar.Market
		local bucket = BazaarMath.MarketBucket(now)
		if market.Bucket ~= bucket then
			market.Bucket, market.Bought = bucket, {}
		end
		local offer = BazaarMath.OfferById(bucket, payload.Pick)
		if offer == nil then
			return false, "That deal is not on offer this hour."
		end
		local bought = market.Bought[offer.Id] or 0
		if bought >= offer.Stock then
			return false, "Sold out for this hour."
		end
		local price = Economy.Max(1000, Economy.Floor(Economy.Mul(production(profile), offer.Seconds * (1 - offer.Discount))))
		if not take(profile, price) then
			return false, "Not enough flux."
		end
		local message = ProgressionService.ApplyReward(profile, offer.Reward, production(profile))
		market.Bought[offer.Id] = bought + 1
		bump(bazaar, "Deals")
		return true, `{offer.Name}: {message}`, { Game = "Market", Pick = offer.Id, Cost = Economy.Persist(price) }
	end

	local function lotteryAct(profile, bazaar, payload, now: number, random: Random, userId: number): (boolean, string, any?)
		lotteryTick(now, random)
		local op = payload.Op
		if op == "Prize" then
			local pending = lottery.Pending[userId]
			if pending == nil or not Economy.Gt(pending, 0) then
				return false, "No prize waiting."
			end
			lottery.Pending[userId] = nil
			profile.Cash = Economy.Add(profile.Cash, pending)
			return true, "Prize collected.", { Game = "Lottery", Amount = Economy.Persist(pending), Prize = true }
		end
		local count = TICKET_BATCH[tonumber(payload.Tier) or 0]
		if count == nil then
			return false, "Pick how many tickets."
		end
		local have = myTickets(userId)
		count = math.min(count, BazaarMath.LOTTERY_MAX_TICKETS - have)
		if count <= 0 then
			return false, "You hold the most tickets allowed this draw."
		end
		local each = ticketPrice(profile)
		local total = Economy.Mul(each, count)
		if not take(profile, total) then
			return false, "Not enough flux for those tickets."
		end
		lottery.Tickets[userId] = have + count
		lottery.Pot = Economy.Add(lottery.Pot, total)
		bump(bazaar, "Tickets", count)
		return true, `Bought {count} ticket{if count == 1 then "" else "s"}.`, { Game = "Lottery", Count = count }
	end

	local function contractAct(profile, bazaar, payload, now: number, userId: number): (boolean, string, any?)
		local list = contractsFor(profile, bazaar, now, userId)
		local contract
		for _, entry in list do
			if entry.Id == payload.Pick then
				contract = entry
			end
		end
		if contract == nil then
			return false, "That contract is not on your board today."
		end
		if bazaar.Contracts.Claimed[contract.Id] then
			return false, "Already claimed."
		end
		local progress = currentOf(profile, bazaar, contract.Counter) - (bazaar.Contracts.Baseline[contract.Counter] or 0)
		if progress < contract.Target then
			return false, "That contract is not finished."
		end
		bazaar.Contracts.Claimed[contract.Id] = true
		local message = ProgressionService.ApplyReward(profile, contract.Reward, production(profile))
		return true, `{contract.Name}: {message}`, { Game = "Contracts", Pick = contract.Id }
	end

	function BazaarService.Roll(profile, now: number, userId: number)
		contractsFor(profile, ensure(profile), now, userId)
	end

	function BazaarService.Play(profile, random: Random, payload: any, now: number, userId: number): (boolean, string, any?)
		if type(payload) ~= "table" or type(payload.Game) ~= "string" then
			return false, "Pick a counter.", nil
		end
		local bazaar = ensure(profile)
		local gameName = payload.Game
		if gameName == "Bank" then
			return bankAct(profile, bazaar, payload, now)
		elseif gameName == "Market" then
			return marketAct(profile, bazaar, payload, now)
		elseif gameName == "Lottery" then
			return lotteryAct(profile, bazaar, payload, now, random, userId)
		elseif gameName == "Contracts" then
			return contractAct(profile, bazaar, payload, now, userId)
		end
		return false, "Unknown counter.", nil
	end

	function BazaarService.State(profile, now: number, userId: number): any
		local bazaar = ensure(profile)
		lotteryTick(now, nil)
		local ghost = { Since = bazaar.Bank.Since, Balance = bazaar.Bank.Balance, Accrued = bazaar.Bank.Accrued }
		if ghost.Since > 0 and Economy.Gt(ghost.Balance, 0) then
			local hours = BazaarMath.AccrualHours(now - ghost.Since)
			ghost.Accrued = Economy.Persist(Economy.Add(ghost.Accrued, Economy.Mul(Economy.Min(ghost.Balance, bankCap(profile)), BazaarMath.BANK.SavingsRate * hours)))
		end
		local term = bazaar.Bank.Term
		local termInfo = BazaarMath.TermById(term.Id)
		local bucket = BazaarMath.MarketBucket(now)
		local bought = if bazaar.Market.Bucket == bucket then bazaar.Market.Bought else {}
		local offers = {}
		for _, offer in BazaarMath.Offers(bucket) do
			local price = Economy.Max(1000, Economy.Floor(Economy.Mul(production(profile), offer.Seconds * (1 - offer.Discount))))
			table.insert(offers, { Id = offer.Id, Name = offer.Name, Reward = offer.Reward, Discount = offer.Discount, Price = Economy.Persist(price), Left = offer.Stock - (bought[offer.Id] or 0), Stock = offer.Stock })
		end
		local baseline = if bazaar.Contracts.Day == day(now) then bazaar.Contracts.Baseline else nil
		local contracts = {}
		for _, entry in BazaarMath.ContractsFor(day(now), userId) do
			local start = if baseline then (baseline[entry.Counter] or 0) else currentOf(profile, bazaar, entry.Counter)
			local progress = math.clamp(currentOf(profile, bazaar, entry.Counter) - start, 0, entry.Target)
			local claimed = bazaar.Contracts.Day == day(now) and bazaar.Contracts.Claimed[entry.Id] == true
			table.insert(contracts, { Id = entry.Id, Name = entry.Name, Text = entry.Text, Target = entry.Target, Progress = progress, Reward = entry.Reward, Claimed = claimed, Claimable = not claimed and progress >= entry.Target })
		end
		local pending = lottery.Pending[userId]
		return {
			Bank = {
				Balance = bazaar.Bank.Balance,
				Accrued = ghost.Accrued,
				Rate = BazaarMath.BANK.SavingsRate,
				Cap = Economy.Persist(bankCap(profile)),
				Terms = BazaarMath.BANK.Terms,
				Term = { Id = term.Id, Principal = term.Principal, EndsAt = term.EndsAt, Hours = if termInfo then termInfo.Hours else 0, Rate = if termInfo then termInfo.Rate else 0, Matured = termInfo ~= nil and now >= term.EndsAt },
			},
			Market = { Offers = offers, EndsAt = (bucket + 1) * BazaarMath.MARKET_SECONDS },
			Lottery = {
				Pot = Economy.Persist(lottery.Pot),
				Mine = myTickets(userId),
				Max = BazaarMath.LOTTERY_MAX_TICKETS,
				Price = Economy.Persist(ticketPrice(profile)),
				NextAt = (BazaarMath.LotteryBucket(now) + 1) * BazaarMath.LOTTERY_SECONDS,
				Last = lottery.Last,
				Prize = if pending ~= nil then Economy.Persist(pending) else 0,
			},
			Contracts = contracts,
		}
	end

	return BazaarService
end
