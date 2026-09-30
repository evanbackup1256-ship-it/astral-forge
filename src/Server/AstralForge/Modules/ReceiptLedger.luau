--!strict
-- Bounded real-money receipt dedup ledger.
--
-- profile.Receipts historically grew one entry per lifetime purchase with no
-- pruning anywhere. A long-tenured / high-spending profile therefore accreted
-- Receipts entries without bound until the full-profile hash in ProfileIntegrity
-- crossed its traversal budget, at which point Seal() started throwing — silently
-- breaking every future save and then rejecting the player's next login. The more
-- someone spent, the sooner they were locked out.
--
-- Roblox only re-delivers a PurchaseId until the receipt is granted and saved, so
-- remembering the most recent N purchase keys is sufficient for dedup; the oldest
-- keys are purchases granted long ago that will never be re-delivered, so evicting
-- them cannot cause a double-grant.
--
-- Pure and Lune-testable: no Roblox services, the clock is injected as `now`.

local ReceiptLedger = {}

-- 256 keys is far more than any realistic in-flight retry count, yet only ~513
-- integrity nodes — three orders of magnitude under ProfileIntegrity's budget.
local DEFAULT_MAX = 256

local function stampOf(value: any): number
	-- Legacy entries were stored as `true`; treat them as the oldest so they are
	-- the first evicted (they are, in fact, the oldest purchases).
	return if type(value) == "number" then value else 0
end

-- Evict oldest-by-tick entries until at most `cap` remain. Returns the number of
-- entries removed. Only does work when the map is over the cap.
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

-- Record a purchase key. Returns (receipts, alreadyProcessed). A fresh key is
-- stamped with `now` and the map is pruned back under `cap`; an existing key is
-- reported as already processed without mutating the map.
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
