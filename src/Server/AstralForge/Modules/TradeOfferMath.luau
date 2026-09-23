--!strict
-- Pure trade-offer shaping + daily ledger helpers. No Roblox services —
-- TradeDesk and Lune verify scripts share EmptyOffer / CopyOffer / OfferEmpty /
-- BoostTotal / KeyTotal / EnsureLedger / ItemEquipped / CountInventory so
-- offer validation stays testable without Studio. StampItems (name lookup)
-- and datastore session writes stay with the caller; currency / boost / key
-- id lists are injected from TradeExchange.

local TradeOfferMath = {}

export type OfferBag = {
	Cash: number,
	Stardust: number,
	Cores: number,
	Signals: number,
	Essence: number,
	Boosts: { [string]: number },
	Keys: { [string]: number },
	ItemIds: { string },
	Items: { any }?,
}

local function utcDay(now: number): number
	local date = os.date("!*t", now)
	return date.year * 1000 + date.yday
end

function TradeOfferMath.EmptyOffer(boostIds: { string }, keyIds: { string }): OfferBag
	local boosts: { [string]: number } = {}
	for _, id in boostIds do
		boosts[id] = 0
	end
	local keys: { [string]: number } = {}
	for _, id in keyIds do
		keys[id] = 0
	end
	return {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boosts = boosts,
		Keys = keys,
		ItemIds = {},
	}
end

-- Coerce a raw client offer into a finite, de-duped bag. Nil / non-table → empty.
function TradeOfferMath.CopyOffer(
	offer: any,
	currencies: { string },
	boostIds: { string },
	keyIds: { string }
): OfferBag
	local nextOffer = TradeOfferMath.EmptyOffer(boostIds, keyIds)
	if type(offer) ~= "table" then
		return nextOffer
	end
	for _, key in currencies do
		nextOffer[key] = math.max(0, math.floor(tonumber(offer[key]) or 0))
	end
	if type(offer.Boosts) == "table" then
		for _, id in boostIds do
			nextOffer.Boosts[id] = math.max(0, math.floor(tonumber(offer.Boosts[id]) or 0))
		end
	end
	if type(offer.Keys) == "table" then
		for _, id in keyIds do
			nextOffer.Keys[id] = math.max(0, math.floor(tonumber(offer.Keys[id]) or 0))
		end
	end
	if type(offer.ItemIds) == "table" then
		local seen = {}
		for _, uid in offer.ItemIds do
			if type(uid) == "string" and uid ~= "" and not seen[uid] then
				seen[uid] = true
				table.insert(nextOffer.ItemIds, uid)
			end
		end
	end
	if type(offer.Items) == "table" then
		nextOffer.Items = {}
		for _, row in offer.Items do
			if type(row) == "table" and type(row.Uid) == "string" then
				table.insert(nextOffer.Items, {
					Uid = row.Uid,
					DefinitionId = type(row.DefinitionId) == "string" and row.DefinitionId or "",
					Name = type(row.Name) == "string" and row.Name or "Relic",
				})
			end
		end
	end
	return nextOffer
end

function TradeOfferMath.OfferEmpty(offer: any, currencies: { string }, boostIds: { string }, keyIds: { string }): boolean
	if type(offer) ~= "table" then
		return true
	end
	for _, key in currencies do
		if (tonumber(offer[key]) or 0) > 0 then
			return false
		end
	end
	local boosts = offer.Boosts
	if type(boosts) == "table" then
		for _, id in boostIds do
			if (tonumber(boosts[id]) or 0) > 0 then
				return false
			end
		end
	end
	local keys = offer.Keys
	if type(keys) == "table" then
		for _, id in keyIds do
			if (tonumber(keys[id]) or 0) > 0 then
				return false
			end
		end
	end
	local itemIds = offer.ItemIds
	return type(itemIds) ~= "table" or #itemIds == 0
end

function TradeOfferMath.BoostTotal(offer: any, boostIds: { string }): number
	local total = 0
	if type(offer) ~= "table" or type(offer.Boosts) ~= "table" then
		return 0
	end
	for _, id in boostIds do
		total += math.max(0, math.floor(tonumber(offer.Boosts[id]) or 0))
	end
	return total
end

function TradeOfferMath.KeyTotal(offer: any, keyIds: { string }): number
	local total = 0
	if type(offer) ~= "table" or type(offer.Keys) ~= "table" then
		return 0
	end
	for _, id in keyIds do
		total += math.max(0, math.floor(tonumber(offer.Keys[id]) or 0))
	end
	return total
end

-- Reset daily Sent/Completed when the UTC day rolls; rebuild nil Trade bags.
function TradeOfferMath.EnsureLedger(profile: any, now: number)
	if type(profile) ~= "table" then
		return
	end
	if type(profile.Trade) ~= "table" then
		profile.Trade = { Day = -1, Completed = 0, Sent = {} }
	end
	local day = utcDay(now)
	local emptySent = {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boost = 0,
		Keys = 0,
		Items = 0,
	}
	if profile.Trade.Day ~= day then
		profile.Trade.Day = day
		profile.Trade.Completed = 0
		profile.Trade.Sent = emptySent
	end
	if type(profile.Trade.Sent) ~= "table" then
		profile.Trade.Sent = emptySent
	end
end

function TradeOfferMath.ItemEquipped(profile: any, uid: string): boolean
	if type(uid) ~= "string" or uid == "" then
		return false
	end
	if type(profile) ~= "table" or type(profile.Items) ~= "table" or type(profile.Items.Equipped) ~= "table" then
		return false
	end
	for _, equipped in profile.Items.Equipped do
		if equipped == uid then
			return true
		end
	end
	return false
end

function TradeOfferMath.CountInventory(profile: any): number
	local count = 0
	if type(profile) == "table" and profile.Items and type(profile.Items.Inventory) == "table" then
		for _ in profile.Items.Inventory do
			count += 1
		end
	end
	return count
end

return table.freeze(TradeOfferMath)
