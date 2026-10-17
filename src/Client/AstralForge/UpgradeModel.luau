--!nocheck
-- Pure purchasing/read-model logic. Currency stays in OmegaMath at every tier.
return function(Math)
	local Model = {}
	-- a price only depends on the item, its level and how many: boards re-quote every row on each
	-- cash tick, so the geometric sums are remembered per item (weak, so old configs fall away)
	local costMemo = setmetatable({}, { __mode = "k" })
	local function costOf(item, level, count)
		local byItem = costMemo[item]
		if byItem == nil or byItem.size > 256 then
			byItem = { size = 0 }
			costMemo[item] = byItem
		end
		local key = `{level}:{count}`
		local cost = byItem[key]
		if cost == nil then
			cost = if count > 0 then Math.GeometricSum(item.BaseCost, item.CostScale, level, count) else Math.ScaledCost(item.BaseCost, item.CostScale, level)
			byItem[key] = cost
			byItem.size += 1
		end
		return cost
	end
	function Model.quote(entry, amount, cash)
		local item = entry.config
		local remaining = math.max(0, item.MaxLevel - entry.level)
		local count = if amount == 0 then Math.AffordableCount(item.BaseCost, item.CostScale, entry.level, cash, remaining) else math.min(amount, 50, remaining)
		local cost = costOf(item, entry.level, count)
		return { count = count, cost = cost, ready = entry.unlocked and not entry.maxed and count > 0 and Math.Gte(cash, cost) }
	end
	function Model.returnScore(entry)
		-- Marginal raw production from the same level/growth formula as the server.
		-- Global and machine-specific bonuses are intentionally excluded from this comparison.
		local item = entry.config
		local gain = Math.Mul(item.BaseProduction or 0, 1 + 2 * (item.Growth or 0) * entry.level)
		return if Math.Gt(gain, 0) then Math.Log10(gain) - Math.Log10(entry.price) else -math.huge
	end
	function Model.gainScore(entry)
		local gain = Math.Mul(entry.config.BaseProduction or 0, 1 + 2 * (entry.config.Growth or 0) * entry.level)
		return if Math.Gt(gain, 0) then Math.Log10(gain) else -math.huge
	end
	function Model.plan(entries, amount, cash)
		local function quoteOrder(entry, budget)
			local quote = Model.quote(entry, amount, budget)
			-- Explicit numeric amounts have the same 50-level ceiling as the server.
			-- This prevents Max's shared-budget quote from promising unaccepted levels.
			if quote.count > 50 then
				quote.count = 50
				quote.cost = Math.GeometricSum(entry.config.BaseCost, entry.config.CostScale, entry.level, 50)
			end
			return quote
		end
		local candidates = {}
		for _, entry in entries do
			if Model.quote(entry, amount, cash).ready then table.insert(candidates, entry) end
		end
		-- Bound a click to 24 requests. Max divides the budget rather than exhausting it on row one.
		local orders, remaining = {}, cash
		local limit = math.min(24, #candidates)
		for index = 1, limit do
			local entry = candidates[index]
			local budget = if amount == 0 then Math.Div(remaining, limit - index + 1) else remaining
			local quote = quoteOrder(entry, budget)
			if quote.ready then
				table.insert(orders, { Id = entry.config.Id, Amount = quote.count, Cost = quote.cost })
				remaining = Math.Max(0, Math.Sub(remaining, quote.cost))
			end
		end
		-- A costly first row can fail its share even though it is affordable overall.
		if #orders == 0 and #candidates > 0 then
			local quote = quoteOrder(candidates[1], cash)
			table.insert(orders, { Id = candidates[1].config.Id, Amount = quote.count, Cost = quote.cost })
			remaining = Math.Max(0, Math.Sub(cash, quote.cost))
		end
		return orders, remaining
	end
	-- `matcher(query, name, description)` swaps in fuzzy matching; plain substring otherwise.
	function Model.filter(entries, query, filter, amount, cash, matcher)
		local visible = {}
		local needle = string.lower(string.match(query or "", "^%s*(.-)%s*$"))
		for _, entry in entries do
			local keep = if filter == "Affordable" then Model.quote(entry, amount, cash).ready elseif filter == "Owned" then entry.level > 0 elseif filter == "Next" then not entry.unlocked elseif filter == "Available" then entry.unlocked and not entry.maxed else true
			local found = needle == ""
			if not found then
				if matcher ~= nil then
					found = matcher(needle, entry.config.Name, entry.config.Description)
				else
					local haystack = string.lower(entry.config.Name .. " " .. (entry.config.Description or ""))
					found = string.find(haystack, needle, 1, true) ~= nil
				end
			end
			if keep and found then table.insert(visible, entry) end
		end
		return visible
	end
	return Model
end
