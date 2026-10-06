--!strict

local ReceiptLedger = {}

local DEFAULT_MAX = 256

local function stampOf(value: any): number
	return if type(value) == "number" then value else 0
end

function ReceiptLedger.Prune(receipts: any, cap: number?): number
	if type(receipts) ~= "table" then
		return 0
	end
	local limit = math.max(0, math.floor(tonumber(cap) or DEFAULT_MAX))
	local count = 0
	for _ in receipts do
		count += 1
	end
	if count <= limit then
		return 0
	end
	local ordered = {}
	for key, value in receipts do
		table.insert(ordered, { key = key, stamp = stampOf(value) })
	end
	table.sort(ordered, function(a, b)
		if a.stamp == b.stamp then
			return tostring(a.key) < tostring(b.key)
		end
		return a.stamp < b.stamp
	end)
	local removeCount = count - limit
	for index = 1, removeCount do
		receipts[ordered[index].key] = nil
	end
	return removeCount
end

function ReceiptLedger.Record(receipts: any, purchaseKey: string, now: number, cap: number?): (any, boolean)
	if type(receipts) ~= "table" then
		receipts = {}
	end
	if receipts[purchaseKey] ~= nil then
		return receipts, true
	end
	receipts[purchaseKey] = if type(now) == "number" and now == now then now else 0
	ReceiptLedger.Prune(receipts, cap)
	return receipts, false
end

return table.freeze(ReceiptLedger)
