--!nocheck
-- GameService shop/purchase handlers, run from the compiled TS (out/) through scripts/_server_harness
-- with a fake service self: developer-product receipts (idempotent on retry, retry after a failed
-- save, unknown products), market/daily/skin offers (invalid ids, insufficient funds, stock and
-- double-purchase, rollback on refusal, Omega-string Cash), gamepass sync idempotence. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local Monetization = H.load("Shared/AstralForge/Shared/SharedData/MonetizationConfig")

local one = setmetatable({}, { __index = function() return function() return 1 end end })
local function service(profile)
	local player = H.player()
	local data = { profile = profile, saveOk = true }
	function data:Update(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if not (type(r) == "table" and r.ok == false) then self.profile = draft end
		return true, r
	end
	function data:AtomicUpdate(p, cb) return self:Update(p, cb) end
	function data:Get() return self.profile end
	function data:Save() return self.saveOk end
	local fields = {
		_data = data, _runtime = { [player] = {} }, _running = true, _random = H.env.Random.new(3),
		_antiCheat = { Observe = function() return nil, false end },
		_convergence = one, _events = one, _crews = one, _fluxSurge = one,
		_syncLeaderstats = function() end, _pushState = function() end, _toastPlayer = function() end, _effect = H.Stub,
	}
	local s = setmetatable(fields, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end })
	return s, player, data
end

-- receipts
local productCount = 0
for _, product in Monetization.DevProducts do
	productCount += 1
	local s, player, data = service(DataTemplate.New())
	local pid = product.ProductId
	local function receipt(id) return s:_processReceipt({ PlayerId = player.UserId, ProductId = pid, PurchaseId = id }) end
	local function snap() local c = deepCopy(data.profile) c.Receipts = nil c.ReceiptLedger = nil return c end
	local base = snap()
	check(receipt("R1") == "ProductPurchaseDecision.PurchaseGranted", "receipt granted")
	local afterOne = snap()
	check(not deepEqual(base, afterOne), "receipt changed the profile")
	check(receipt("R1") == "ProductPurchaseDecision.PurchaseGranted", "repeat receipt acknowledged")
	check(deepEqual(afterOne, snap()), "repeat receipt grants nothing")
	data.saveOk = false
	check(receipt("R2") == "ProductPurchaseDecision.NotProcessedYet", "failed save defers receipt")
	local afterDeferred = snap()
	data.saveOk = true
	for _ = 1, 3 do check(receipt("R2") == "ProductPurchaseDecision.PurchaseGranted", "retry acknowledged") end
	check(deepEqual(afterDeferred, snap()), "retries after a failed save grant once")
	check(receipt("R3") == "ProductPurchaseDecision.PurchaseGranted", "fresh receipt granted")
	check(not deepEqual(afterDeferred, snap()), "fresh receipt grants again")
	local beforeBad = snap()
	check(s:_processReceipt({ PlayerId = player.UserId, ProductId = 1, PurchaseId = "R4" }) == "ProductPurchaseDecision.NotProcessedYet", "unknown product not granted")
	check(s:_processReceipt({ PlayerId = player.UserId + 999, ProductId = pid, PurchaseId = "R5" }) == "ProductPurchaseDecision.NotProcessedYet", "absent player not granted")
	check(deepEqual(beforeBad, snap()), "bad receipts change nothing")
end

-- market offers
local function offersWhere(pred)
	local out = {}
	for _, o in GameConfig.Items.ShopOffers do if pred(o) then table.insert(out, o) end end
	return out
end
for _, bad in { "nope", 5, nil, {}, "" } do
	local s, player, data = service(DataTemplate.New())
	local before = deepCopy(data.profile)
	local r = s:_buyItemOffer(player, bad)
	check(r.ok == false and deepEqual(before, data.profile), "invalid offer id refused: " .. tostring(bad))
end
local offers = offersWhere(function(o) return o.Kind ~= "Item" end)
check(#offers > 0, "found market offers")
for _, offer in offers do
	local s, player, data = service(DataTemplate.New())
	local p = data.profile
	p.Stardust, p.Cores, p.Cash = 0, 0, 0
	local before = deepCopy(p)
	if offer.Price > 0 then
		local r = s:_buyItemOffer(player, offer.Id)
		check(r.ok == false and deepEqual(before, data.profile), "broke player refused: " .. offer.Id)
	end
	data.profile[offer.Currency] = offer.Price * 100
	local bought = 0
	for _ = 1, 10 do
		local res = s:_buyItemOffer(player, offer.Id)
		if res.ok then bought += 1 end
	end
	local stockMax = offer.Stock or offer.StockMax or 1
	check(bought == stockMax, "stock enforced across repeat buys: " .. offer.Id)
	check(data.profile[offer.Currency] == offer.Price * 100 - bought * offer.Price, "charged once per buy: " .. offer.Id)
end
do -- Cash above 1e15 is stored as an Omega string
	local offer = offersWhere(function(o) return o.Currency == "Cash" and o.Kind ~= "Item" end)[1]
	if offer then
		local Economy = H.load("Shared/AstralForge/Shared/OmegaMath")
		local s, player, data = service(DataTemplate.New())
		data.profile.Cash = (Economy.New or function(v) return v end)(1e30)
		local cash = data.profile.Cash
		local r = s:_buyItemOffer(player, offer.Id)
		check(r.ok == true, "rich player can buy a Cash offer (" .. tostring(r.error) .. ")")
		check(data.profile.Cash ~= nil and tostring(data.profile.Cash) ~= tostring(0), "Omega Cash survives a purchase")
		check(type(cash) ~= "number" or r.ok, "Omega Cash representation")
	end
end

-- daily offers
for _, slot in { 0, -1, 0 / 0, math.huge, 99, "1", nil } do
	local s, player, data = service(DataTemplate.New())
	data.profile.Stardust = 10 ^ 9
	local before = deepCopy(data.profile)
	local r = s:_buyDailyOffer(player, slot)
	check(r.ok == false, "invalid daily slot refused: " .. tostring(slot))
	check(before.Stardust == data.profile.Stardust and before.Cores == data.profile.Cores, "invalid daily slot charges nothing: " .. tostring(slot))
end
do
	local s, player, data = service(DataTemplate.New())
	data.profile.Stardust, data.profile.Cores = 0, 0
	local before = deepCopy(data.profile)
	for slot = 1, 8 do
		local r = s:_buyDailyOffer(player, slot)
		if r.ok then check(false, "broke player bought daily slot " .. slot) end
	end
	check(data.profile.Stardust == 0 and data.profile.Cores == 0 and before.Stats ~= nil and deepEqual(before.Stats, data.profile.Stats), "broke daily buys roll back")
	data.profile.Stardust, data.profile.Cores = 10 ^ 9, 10 ^ 9
	for slot = 1, 8 do
		local n = 0
		for _ = 1, 20 do if s:_buyDailyOffer(player, slot).ok then n += 1 end end
		check(n < 20, "daily slot " .. slot .. " is limited")
	end
end

-- crate skins
do
	local s, player, data = service(DataTemplate.New())
	for _, bad in { "nope", 3, nil } do
		check(s:_buyCrateSkin(player, bad).ok == false, "invalid skin refused: " .. tostring(bad))
	end
end

-- gamepass sync
do
	local s, player, data = service(DataTemplate.New())
	check(s:_syncShop(player).ok == true, "pass sync ok")
	local first = deepCopy(data.profile)
	check(s:_syncShop(player).ok == true and deepEqual(first, data.profile), "pass sync idempotent")
	s._running = false
	check(s:_syncShop(player).ok == false, "pass sync refused when stopped")
	s._running = true
	check(s:_studioGrantProduct(player, "anything").ok == false, "studio grants refused outside Studio")
end

if #failures > 0 then
	error("server shop failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] server shop: %d checks (receipts, market, daily, skins, pass sync) passed (%d products)", checks, productCount))
