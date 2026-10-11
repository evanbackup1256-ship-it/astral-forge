--!strict
-- Completed-trade history and pre-confirm warnings. Pure: the server records entries inside the
-- same atomic save that applies each side of a trade; the client shows them on the Trade page.

local TradeHistory = {}

TradeHistory.LIMIT = 15

local CURRENCIES = {
	{ key = "Cash", label = "flux" },
	{ key = "Stardust", label = "dust" },
	{ key = "Cores", label = "cores" },
	{ key = "Signals", label = "signals" },
	{ key = "Essence", label = "essence" },
}

local function positive(value: any): boolean
	if type(value) == "number" then
		return value == value and value > 0
	end
	-- big-number flux values arrive as tables; anything non-zero counts
	return type(value) == "table" and next(value) ~= nil and tostring(value) ~= "0"
end

local function countMap(map: any): number
	local total = 0
	if type(map) == "table" then
		for _, count in map do
			if type(count) == "number" and count > 0 then total += count end
		end
	end
	return total
end

-- True when an offer carries nothing at all.
function TradeHistory.isEmpty(offer: any): boolean
	if type(offer) ~= "table" then return true end
	for _, currency in CURRENCIES do
		if positive(offer[currency.key]) then return false end
	end
	return countMap(offer.Boosts) == 0 and countMap(offer.Keys) == 0
		and (type(offer.ItemIds) ~= "table" or #offer.ItemIds == 0)
end

-- "1.2K flux, 30 dust, 2 boosts, Ember Crown". `format` renders a currency amount.
function TradeHistory.summarize(offer: any, itemNames: { string }?, format: ((any) -> string)?): string
	if type(offer) ~= "table" then return "nothing" end
	local render = format or function(value) return tostring(value) end
	local parts = {}
	for _, currency in CURRENCIES do
		if positive(offer[currency.key]) then
			table.insert(parts, `{render(offer[currency.key])} {currency.label}`)
		end
	end
	local boosts, keys = countMap(offer.Boosts), countMap(offer.Keys)
	if boosts > 0 then table.insert(parts, `{boosts} boost{if boosts == 1 then "" else "s"}`) end
	if keys > 0 then table.insert(parts, `{keys} key{if keys == 1 then "" else "s"}`) end
	local names = itemNames or {}
	for index = 1, math.min(#names, 3) do
		table.insert(parts, names[index])
	end
	if #names > 3 then
		table.insert(parts, `{#names - 3} more item{if #names - 3 == 1 then "" else "s"}`)
	end
	return if #parts == 0 then "nothing" else table.concat(parts, ", ")
end

export type Entry = { Id: string, At: number, PartnerId: number, Partner: string, Gave: string, Got: string }

-- Adds an entry newest-first, once per trade id, keeping at most LIMIT.
function TradeHistory.record(trade: any, entry: Entry)
	if type(trade) ~= "table" then return end
	local list = if type(trade.History) == "table" then trade.History else {}
	for index = #list, 1, -1 do
		if type(list[index]) ~= "table" or list[index].Id == entry.Id then table.remove(list, index) end
	end
	table.insert(list, 1, entry)
	while #list > TradeHistory.LIMIT do table.remove(list) end
	trade.History = list
end

-- Drops an entry again when its side of the trade is reverted.
function TradeHistory.remove(trade: any, id: string)
	if type(trade) ~= "table" or type(trade.History) ~= "table" then return end
	for index = #trade.History, 1, -1 do
		local entry = trade.History[index]
		if type(entry) == "table" and entry.Id == id then table.remove(trade.History, index) end
	end
end

-- A clean copy for the client: only well-formed entries, bounded strings.
function TradeHistory.public(trade: any): { Entry }
	local out = {}
	if type(trade) ~= "table" or type(trade.History) ~= "table" then return out end
	for _, entry in trade.History do
		if type(entry) == "table" and type(entry.Id) == "string" and type(entry.At) == "number"
			and type(entry.Partner) == "string" and type(entry.Gave) == "string" and type(entry.Got) == "string" then
			table.insert(out, {
				Id = entry.Id, At = entry.At, PartnerId = tonumber(entry.PartnerId) or 0,
				Partner = string.sub(entry.Partner, 1, 40), Gave = string.sub(entry.Gave, 1, 160), Got = string.sub(entry.Got, 1, 160),
			})
			if #out >= TradeHistory.LIMIT then break end
		end
	end
	return out
end

-- Warnings shown above Confirm. They never block a trade; they make one-sided offers obvious.
function TradeHistory.warnings(mine: any, theirs: any): { string }
	local out = {}
	local giving, getting = not TradeHistory.isEmpty(mine), not TradeHistory.isEmpty(theirs)
	if giving and not getting then
		table.insert(out, "You get nothing back in this trade. Only confirm if it's a gift.")
	elseif getting and not giving then
		table.insert(out, "You're not giving anything. Your partner is offering a gift.")
	end
	local myItems = if type(mine) == "table" and type(mine.ItemIds) == "table" then #mine.ItemIds else 0
	local theirItems = if type(theirs) == "table" and type(theirs.ItemIds) == "table" then #theirs.ItemIds else 0
	if myItems >= 3 and theirItems == 0 then
		table.insert(out, `You're giving {myItems} items and getting none. Check the other side before you confirm.`)
	end
	return out
end

return table.freeze(TradeHistory)
