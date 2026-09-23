--!strict
-- Pure item-shop stock / buy / studio-grant eligibility. No Roblox services —
-- ServerServices and Lune verify scripts share this so offer stock refresh and
-- purchase gates can be tested without Studio. Profile currency mutation and
-- Marketplace receipts stay with the caller; offer lists and clocks are injected.

local ShopGrantEligibility = {}

export type OfferLike = {
	Id: string,
	Kind: string?,
	Name: string?,
	Currency: string?,
	Price: number?,
	StockMax: number?,
	DailyRefresh: boolean?,
	DailyRestock: number?,
}

export type ShopState = {
	Day: number?,
	Stock: { [string]: number }?,
	Purchased: { [string]: boolean }?,
}

function ShopGrantEligibility.StockMax(offer: OfferLike): number
	local stockMax = offer.StockMax
	if type(stockMax) == "number" and stockMax > 0 then
		return math.floor(stockMax)
	end
	return 1
end

-- Keys-only / missing Inventory bags (Studio fixtures) must count as empty —
-- callers that pass profile.Items.Inventory without Ensure must not throw.
function ShopGrantEligibility.InventoryCount(inventory: any): number
	if type(inventory) ~= "table" then
		return 0
	end
	local count = 0
	for _ in inventory do
		count += 1
	end
	return count
end

function ShopGrantEligibility.RemainingStock(stockValue: any, stockMax: number): number
	local remaining = stockValue
	if type(remaining) ~= "number" then
		remaining = stockMax
	end
	return math.clamp(math.floor(remaining), 0, stockMax)
end

-- Studio-only grant surface (money / wheel / product keys). Callers keep error copy.
function ShopGrantEligibility.StudioGrantAllowed(isStudio: boolean): boolean
	return isStudio == true
end

-- Clamp free-wheel studio grant size (matches GrantStudioWheelSpins).
function ShopGrantEligibility.ClampWheelGrant(amount: any): number
	return math.clamp(math.floor(tonumber(amount) or 100), 1, 500)
end

-- Buy-offer gate without mutating profile. formatShortage builds the currency message.
function ShopGrantEligibility.EvaluateBuy(
	offer: OfferLike,
	remaining: number,
	inventoryCount: number,
	inventoryLimit: number,
	balance: any,
	formatShortage: (need: number, currency: string) -> string
): (boolean, string?)
	if remaining <= 0 then
		if offer.DailyRefresh == true then
			return false, "That daily offer is sold out. Come back after refresh."
		end
		return false, "That market offer is sold out."
	end
	if offer.Kind == "Item" and inventoryCount >= inventoryLimit then
		return false, "Your item inventory is full. Salvage something first."
	end
	local price = tonumber(offer.Price) or 0
	local have = if type(balance) == "number" then balance else nil
	if have == nil or have < price then
		local currency = offer.Currency or "Cash"
		return false, formatShortage(math.max(0, price - (have or 0)), currency)
	end
	if offer.Kind ~= "Key" and offer.Kind ~= "Essence" and offer.Kind ~= "Item" then
		return false, "That market offer is misconfigured."
	end
	return true, nil
end

-- Ensure Stock/Purchased tables exist, clamp values, and daily-refresh when day rolls.
-- Mutates `shop` in place. Returns whether anything changed.
-- Nil shop (Items without Shop nest) is a no-op — callers must ProfileBagMath.EnsureItems first.
function ShopGrantEligibility.EnsureShop(shop: any, offers: { OfferLike }, utcDay: number): boolean
	if type(shop) ~= "table" then
		return false
	end
	if type(shop.Stock) ~= "table" then
		shop.Stock = {}
	end
	if type(shop.Purchased) ~= "table" then
		shop.Purchased = {}
	end
	local stock = shop.Stock :: { [string]: number }
	local purchased = shop.Purchased :: { [string]: boolean }
	local day = math.floor(utcDay)
	local changed = false

	for _, offer in offers do
		local stockMax = ShopGrantEligibility.StockMax(offer)
		local current = stock[offer.Id]
		if type(current) ~= "number" then
			if purchased[offer.Id] == true then
				stock[offer.Id] = 0
			else
				stock[offer.Id] = stockMax
			end
			changed = true
		else
			local clamped = math.clamp(math.floor(current), 0, stockMax)
			if clamped ~= current then
				stock[offer.Id] = clamped
				changed = true
			end
		end
	end

	if shop.Day == day then
		return changed
	end

	shop.Day = day
	shop.Purchased = {}
	purchased = shop.Purchased
	for _, offer in offers do
		local stockMax = ShopGrantEligibility.StockMax(offer)
		if offer.DailyRefresh == true then
			stock[offer.Id] = stockMax
		else
			local restock = type(offer.DailyRestock) == "number" and math.max(0, math.floor(offer.DailyRestock)) or 0
			local current = stock[offer.Id] or 0
			stock[offer.Id] = math.min(stockMax, current + restock)
		end
	end
	return true
end

return table.freeze(ShopGrantEligibility)
