--!nonstrict
local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)

return function(loadService)
	local Economy = require(script.Parent.Parent.Modules.EconomyMath)("Economy")
	local Math = require(script.Parent.Parent.Modules.BazaarMath)
	local Log = require(script.Parent.Parent.ModuleLog)
	local Progression = loadService("ProgressionService")
	local Service = {}
	local rollover
	local offerCounts = {}
	local nextOfferCount = Math.MARKET_OFFERS

	task.defer(function()
		local store = StoreAccess.data("AstralForgeBazaar")
		for attempt = 1, 3 do
			local ok, saved = pcall(function() return store:GetAsync("AF_LotteryRollover_v1") end)
			if ok then
				rollover = if type(saved) == "table" then saved else nil
				return
			end
			Log.Warn("BlackMarket", "Legacy prize recovery failed: " .. tostring(saved))
			if attempt < 3 then task.wait(attempt * 2) end
		end
	end)
	task.defer(function()
		local isStudio = false
		pcall(function()
			local rs = game:GetService("RunService")
			if rs and type(rs.IsStudio) == "function" then
				isStudio = rs:IsStudio()
			end
		end)
		if isStudio then
			return
		end
		local ok, snapshot = pcall(function() return game:GetService("ConfigService"):GetConfigAsync() end)
		if not ok then
			Log.Warn("BlackMarket", "Experience Config unavailable; using catalog defaults: " .. tostring(snapshot))
			return
		end
		local function read()
			local value = snapshot:GetValue("BlackMarketOfferCount")
			if value == nil then nextOfferCount = Math.MARKET_OFFERS; return end
			if type(value) ~= "number" or value ~= value or value < 12 or value > #Math.CATALOG or value % 1 ~= 0 then
				Log.Warn("BlackMarket", "BlackMarketOfferCount must be an integer from 12 to " .. #Math.CATALOG)
				return
			end
			nextOfferCount = value
		end
		read()
		snapshot.UpdateAvailable:Connect(function()
			local refreshed, err = pcall(function() snapshot:Refresh() end)
			if refreshed then read() else Log.Warn("BlackMarket", "Experience Config refresh failed: " .. tostring(err)) end
		end)
	end)
	local function countFor(bucket)
		if not offerCounts[bucket] then
			offerCounts[bucket] = nextOfferCount
			for key in offerCounts do if key < bucket - 1 then offerCounts[key] = nil end end
		end
		return offerCounts[bucket]
	end
	local function ensure(profile)
		profile.Bazaar = Math.Ensure(profile.Bazaar)
		return profile.Bazaar
	end
	local function price(profile, offer)
		return Economy.Max(1000, Economy.Floor(Economy.Mul(Economy.SteadyProduction(profile), offer.Seconds * (1 - offer.Discount))))
	end
	local function rolloverAt()
		local at = rollover and tonumber(rollover.SavedAt)
		return if at and at == at and at > 0 and at < math.huge then at else nil
	end
	local function ticketShare(userId)
		if not rollover or type(rollover.Tickets) ~= "table" then return 0 end
		local total, owned = 0, 0
		for id, raw in rollover.Tickets do
			local owner, tickets = tonumber(id), tonumber(raw)
			if owner and owner > 0 and owner < math.huge and owner % 1 == 0
				and tickets and tickets == tickets and tickets > 0 and tickets <= Math.LOTTERY_MAX_TICKETS and tickets % 1 == 0 then
				total += tickets
				if owner == userId then owned += tickets end
			end
		end
		if owned == 0 or total == 0 then return 0 end
		local pot = Math.Ensure({ Bank = { Balance = rollover.Pot } }).Bank.Balance
		return Economy.Mul(pot, owned / total)
	end
	function Service.NeedsRecovery(profile, userId)
		local bag = Math.Ensure(profile.Bazaar)
		if not bag.Contracts.Retired then return true end
		if Economy.Gt(bag.Bank.Balance, 0) or Economy.Gt(bag.Bank.Accrued, 0)
			or Economy.Gt(bag.Bank.Term.Principal, 0) or Economy.Gt(bag.Lottery.PendingPrize, 0) then return true end
		local savedAt = rolloverAt()
		if not savedAt then return false end
		if savedAt > bag.Market.RefundedTicketsAt and Economy.Gt(ticketShare(userId), 0) then return true end
		return type(rollover.Pending) == "table" and savedAt > bag.Market.RefundedRolloverAt
			and (rollover.Pending[userId] ~= nil or rollover.Pending[tostring(userId)] ~= nil)
	end
	function Service.Roll(profile, now, userId)
		local bag = ensure(profile)
		local bank, term = bag.Bank, bag.Bank.Term
		local interest = 0
		if bank.Since > 0 and Economy.Gt(bank.Balance, 0) then
			local cap = Economy.Max(1000, Economy.Mul(Economy.SteadyProduction(profile), Math.BANK.CapSeconds))
			interest = Economy.Mul(Economy.Min(bank.Balance, cap), Math.BANK.SavingsRate * Math.AccrualHours(now - bank.Since))
		end
		local principal = term.Principal
		local info = Math.TermById(term.Id)
		if info and now >= term.EndsAt then principal = Economy.Mul(principal, 1 + info.Rate * info.Hours) end
		local refund = Economy.Add(Economy.Add(bank.Balance, bank.Accrued), Economy.Add(interest, principal))
		refund = Economy.Add(refund, bag.Lottery.PendingPrize)
		local savedAt = rolloverAt()
		if rollover and type(rollover.Pending) == "table" and savedAt
			and savedAt > bag.Market.RefundedRolloverAt then
			local pending = rollover.Pending[userId] or rollover.Pending[tostring(userId)]
			if pending then refund = Economy.Add(refund, Math.Ensure({ Lottery = { PendingPrize = pending } }).Lottery.PendingPrize) end
			bag.Market.RefundedRolloverAt = savedAt
		end
		if savedAt and savedAt > bag.Market.RefundedTicketsAt then
			refund = Economy.Add(refund, ticketShare(userId))
			bag.Market.RefundedTicketsAt = savedAt
		end
		if Economy.Gt(refund, 0) then
			local credited = Economy.Add(profile.Cash, refund)
			if not Economy.Gt(credited, profile.Cash) then return false, "Your balance cannot represent the retired Bazaar refund. The claim is still owed." end
			profile.Cash = credited
			bag.Market.Refunded = Economy.Persist(Economy.Add(bag.Market.Refunded, refund))
		end
		if not bag.Contracts.Retired then
			if bag.Contracts.Day >= 0 then
				for _, contract in Math.ContractsFor(bag.Contracts.Day, userId) do
					if not bag.Contracts.Claimed[contract.Id]
						and bag.Counters[contract.Counter] - (bag.Contracts.Baseline[contract.Counter] or 0) >= contract.Target then
						Progression.ApplyReward(profile, contract.Reward, Economy.SteadyProduction(profile))
						bag.Contracts.Claimed[contract.Id] = true
					end
				end
			end
			bag.Contracts.Retired = true
		end
		bag.Bank = Math.Ensure(nil).Bank
		bag.Lottery.PendingPrize = 0
		return true, "Retired Bazaar balances and earned claims settled."
	end
	local function shelf(bag, bucket)
		-- Standing earned during a shipment only raises stock from the next shipment, so sold-out shelves stay sold out.
		local opening = bag.Counters.Deals
		if bag.Market.Bucket == bucket then
			for _, count in bag.Market.Bought do opening -= count end
		end
		local tier = Math.Reputation(math.max(0, opening))
		local offers = {}
		for _, offer in Math.Offers(bucket, countFor(bucket)) do
			offer.Stock += tier.Bonus
			table.insert(offers, offer)
		end
		local procured = Math.ProcuredOffer(bag.Market.Procure, bucket, offers)
		if procured then
			procured.Stock += tier.Bonus
			table.insert(offers, procured)
		end
		local rare = Math.RareOffer(bucket)
		if rare then table.insert(offers, rare) end
		return offers, tier
	end
	local function shelfOffer(bag, bucket, id)
		for _, offer in (shelf(bag, bucket)) do
			if offer.Id == id then return offer end
		end
		return nil
	end
	function Service.Play(profile, _random, payload, now, userId)
		local order, validationError = Math.ReadOrder(payload)
		if not order then return false, validationError end
		payload = order
		local bucket = Math.MarketBucket(now)
		local quantity = payload.Quantity
		local bag = ensure(profile)
		local market = bag.Market
		local previous = market.Receipts[payload.RequestId]
		if previous then
			if previous.Pick ~= payload.Pick or previous.Quantity ~= quantity or previous.Bucket ~= payload.Bucket
				or previous.Rotation ~= payload.Rotation then return false, "That request ID belongs to another order." end
			if previous.Bucket < bucket - Math.RECEIPT_BUCKETS + 1 then
				return false, "That order is outside the retry window. Check your purchase history."
			end
			return true, previous.Message, {
				Game = "Market", Pick = previous.Pick, Quantity = previous.Quantity, Left = previous.Left, Cost = previous.Cost, Replayed = true,
			}
		end
		if payload.Bucket ~= bucket then return false, "Stock refreshed. Review the new prices before buying." end
		local rotation = `{bucket}:{countFor(bucket)}`
		if payload.Rotation ~= rotation then return false, "This shipment changed. Refresh stock before buying." end
		local offer = shelfOffer(bag, bucket, payload.Pick)
		if not offer then return false, "That shipment is not on the current shelf." end
		local bought = if market.Bucket == bucket then market.Bought[offer.Id] or 0 else 0
		if bought + quantity > offer.Stock then return false, "Not enough stock left for that quantity." end
		local unitPrice = price(profile, offer)
		if not Economy.Gte(payload.UnitPrice, unitPrice) or not Economy.Gte(unitPrice, payload.UnitPrice) then
			return false, "The price changed with your production. Review the updated quote."
		end
		if offer.Reward.Essence and (profile.Domain and profile.Domain.Essence or 0) + offer.Reward.Essence * quantity > 1_000_000 then
			return false, "Your essence storage cannot hold that order."
		end
		local cost = Economy.Mul(unitPrice, quantity)
		if not Economy.Gte(profile.Cash, cost) then return false, "Not enough flux for that order." end
		if market.Bucket ~= bucket then market.Bucket, market.Bought = bucket, {} end
		for id, receipt in market.Receipts do
			if receipt.Bucket < bucket - Math.RECEIPT_BUCKETS + 1 then market.Receipts[id] = nil end
		end
		profile.Cash = Economy.Sub(profile.Cash, cost)
		local description
		for _ = 1, quantity do description = Progression.ApplyReward(profile, offer.Reward, Economy.SteadyProduction(profile)) end
		market.Bought[offer.Id] = bought + quantity
		if offer.Procured then market.Procure.Filled = bucket end
		bag.Counters.Deals = math.min(1e9, bag.Counters.Deals + quantity)
		local message = `{quantity} × {offer.Name}: {description} per unit.`
		market.Receipts[payload.RequestId] = {
			Pick = offer.Id, Quantity = quantity, Left = offer.Stock - bought - quantity, Cost = Economy.Persist(cost), Message = message,
			Bucket = bucket, Rotation = rotation,
		}
		table.insert(market.History, 1, {
			RequestId = payload.RequestId, Pick = offer.Id, Quantity = quantity, Cost = Economy.Persist(cost), At = now,
		})
		if #market.History > 50 then table.remove(market.History) end
		return true, message, {
			Game = "Market", Pick = offer.Id, Quantity = quantity, Left = offer.Stock - bought - quantity, Cost = Economy.Persist(cost),
		}
	end
	function Service.Procure(profile, payload, now)
		if type(payload) ~= "table" or type(payload.Id) ~= "string" then return false, "Choose a supply to request." end
		local bag = ensure(profile)
		local procure = bag.Market.Procure
		if payload.Id == "" then
			if procure.Id == "" then return false, "There is no open request to cancel." end
			bag.Market.Procure = { Id = "", Since = 0, Filled = 0 }
			return true, "Supply request cancelled."
		end
		local entry = Math.RegularById(payload.Id)
		if not entry then return false, "That supply cannot be requested." end
		local _, index = Math.Reputation(bag.Counters.Deals)
		if index < Math.PROCURE_TIER then
			return false, `Requests open at {Math.REPUTATION[Math.PROCURE_TIER].Name} standing.`
		end
		if procure.Id == entry.Id and procure.Filled == 0 then return false, "That request is already open." end
		bag.Market.Procure = { Id = entry.Id, Since = Math.MarketBucket(now), Filled = 0 }
		return true, `Request placed. {entry.Name} arrives with the next shipment.`
	end
	function Service.SetFavorite(profile, payload)
		if type(payload) ~= "table" or not Math.CatalogById(payload.Id) or type(payload.Saved) ~= "boolean" then
			return false, "Choose a valid supply to save."
		end
		local bag = ensure(profile)
		bag.Market.Saved[payload.Id] = if payload.Saved then true else nil
		return true, if payload.Saved then "Supply saved for future shipments." else "Supply removed from saved items."
	end
	function Service.State(profile, now, userId)
		local bag = ensure(profile)
		local bucket = Math.MarketBucket(now)
		local bought = if bag.Market.Bucket == bucket then bag.Market.Bought else {}
		local offers = {}
		local list, tier = shelf(bag, bucket)
		local merchant = Math.Merchant(bucket)
		local watched = {}
		for _, offer in list do
			local left = math.max(0, offer.Stock - (bought[offer.Id] or 0))
			table.insert(offers, {
				Id = offer.Id, Name = offer.Name, Category = offer.Category, Reward = offer.Reward,
				Discount = offer.Discount, Price = Economy.Persist(price(profile, offer)),
				Left = left, Stock = offer.Stock,
				Holdings = Math.Holdings(profile, offer.Reward),
				Rare = offer.Rare == true, Procured = offer.Procured == true,
				Featured = not offer.Rare and offer.Category == merchant.Favors,
			})
			if bag.Market.Saved[offer.Id] and left > 0 then table.insert(watched, offer.Name) end
		end
		local standing, tierIndex, nextTier = Math.Reputation(bag.Counters.Deals)
		local catalog = {}
		for _, entry in Math.CATALOG do
			table.insert(catalog, { Id = entry.Id, Name = entry.Name, Category = Math.Category(entry.Reward) })
		end
		local procure = bag.Market.Procure
		local procureEntry = Math.RegularById(procure.Id)
		local procureState = "None"
		if procureEntry then
			if procure.Filled > 0 and procure.Filled ~= bucket then procureState = "Filled"
			elseif bucket > procure.Since + Math.PROCURE_BUCKETS then procureState = "Expired"
			elseif bucket <= procure.Since then procureState = "Pending"
			else procureState = "Listed" end
		end
		local history = {}
		for _, entry in bag.Market.History do
			local record = table.clone(entry)
			record.Name = Math.CatalogById(entry.Pick).Name
			table.insert(history, record)
		end
		return { Market = {
			Offers = offers, Bucket = bucket, EndsAt = (bucket + 1) * Math.MARKET_SECONDS,
			CatalogSize = #Math.CATALOG, Refunded = bag.Market.Refunded,
			RecoveryPending = Service.NeedsRecovery(profile, userId),
			Rotation = `{bucket}:{countFor(bucket)}`,
			Saved = table.clone(bag.Market.Saved), History = history,
			Merchant = { Name = merchant.Name, Title = merchant.Title, Favors = merchant.Favors, Accent = merchant.Accent, Line = merchant.Line },
			Reputation = {
				Name = standing.Name, Index = tierIndex, Units = bag.Counters.Deals, Bonus = standing.Bonus, ShelfBonus = tier.Bonus,
				Next = if nextTier then nextTier.Name else nil, NextAt = if nextTier then nextTier.At else nil,
				ProcureTier = Math.REPUTATION[Math.PROCURE_TIER].Name, CanProcure = tierIndex >= Math.PROCURE_TIER,
			},
			Procure = {
				Id = procure.Id, Name = if procureEntry then procureEntry.Name else nil, State = procureState,
				Since = procure.Since, ExpiresAt = (procure.Since + Math.PROCURE_BUCKETS + 1) * Math.MARKET_SECONDS,
			},
			Catalog = catalog, Watched = watched,
		} }
	end
	return Service
end
