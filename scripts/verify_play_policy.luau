--!nocheck
-- PolicyService gating: paid random items (keys and relic caches bought with Stardust or Cores,
-- Robux products that hand out keys or spins) and trading, plus the crate odds the Shop shows.
-- The odds are checked against CrateRollResolver itself, so the sheet can't drift from the roll.
-- Run `npx rbxtsc` first.
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
local function near(a, b) return math.abs(a - b) < 1e-9 end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local PlayPolicy = H.load("Shared/AstralForge/Shared/PlayPolicy")
local CrateOdds = H.load("Shared/AstralForge/Shared/CrateOdds")
local CrateConfig = H.load("Shared/AstralForge/Shared/CrateConfig")
local Resolver = H.load("Server/AstralForge/Modules/CrateRollResolver")
local PolicyGate = H.load("Server/AstralForge/Services/PolicyGate")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local Monetization = H.load("Shared/AstralForge/Shared/SharedData/MonetizationConfig")
local SharedData = H.load("Shared/AstralForge/Shared/SharedData")

local OPEN = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
local CLOSED = { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }

-- --- reading PolicyService ----------------------------------------------------
local failed = PlayPolicy.fromPolicyInfo(false, "HTTP 500")
check(failed.PaidRandomItemsRestricted and not failed.PaidItemTradingAllowed and not failed.Known, "an error restricts")
check(PlayPolicy.fromPolicyInfo(true, nil).PaidRandomItemsRestricted, "no answer restricts")
local open = PlayPolicy.fromPolicyInfo(true, OPEN)
check(not open.PaidRandomItemsRestricted and open.PaidItemTradingAllowed and open.Known, "an open region is open")
local partial = PlayPolicy.fromPolicyInfo(true, { ArePaidRandomItemsRestricted = false })
check(not partial.PaidRandomItemsRestricted and not partial.PaidItemTradingAllowed, "a missing field is read restrictively")
check(PlayPolicy.fromPolicyInfo(true, { ArePaidRandomItemsRestricted = "no" }).PaidRandomItemsRestricted, "an odd field is read restrictively")

-- --- what counts as a paid random item -----------------------------------------
check(PlayPolicy.isPaidRandomOffer({ Kind = "Key", Currency = "Stardust", Price = 40 }), "key for Stardust")
check(PlayPolicy.isPaidRandomOffer({ Kind = "Cache", Currency = "Cores", Price = 8 }), "cache for Cores")
check(not PlayPolicy.isPaidRandomOffer({ Kind = "Key", Currency = "Stardust", Price = 0 }), "a free key isn't paid")
check(not PlayPolicy.isPaidRandomOffer({ Kind = "Key", Currency = "Cash", Price = 500 }), "key for Flux stays")
check(not PlayPolicy.isPaidRandomOffer({ Kind = "Essence", Currency = "Stardust", Price = 40 }), "essence isn't random")
check(not PlayPolicy.isPaidRandomOffer({ Kind = "Skin", Currency = "Cores", Price = 12 }), "skins aren't random")
check(PlayPolicy.isPaidRandomProduct({ Reward = { Keys = { ForgeCrate = 3 } } }), "a key product")
check(PlayPolicy.isPaidRandomProduct({ Reward = { FreeSpins = 5 } }), "a spin product")
check(not PlayPolicy.isPaidRandomProduct({ Reward = { Keys = {} } }), "an empty key table")
check(not PlayPolicy.isPaidRandomProduct({ Reward = { Stardust = 80 } }), "a currency product")
for _, product in Monetization.DevProducts do
	-- today's catalog sells none; this flags a new one so it gets a conscious look
	check(not PlayPolicy.isPaidRandomProduct(product), "dev product hands out a random item: " .. product.Key)
end
check(PlayPolicy.tradeBlocked(failed, "ConfirmTrade") ~= nil and PlayPolicy.tradeBlocked(failed, "CancelTrade") == nil, "cancel stays open")
check(PlayPolicy.tradeBlocked(failed, "GetTrade") == nil and PlayPolicy.tradeBlocked(open, "InviteTrade") == nil, "viewing stays open")

-- --- the server cache ------------------------------------------------------------
local calls = 0
local answers = {}
PolicyGate.SetLookupForTests(function(player)
	calls += 1
	local answer = answers[player.UserId]
	if answer == "error" then error("PolicyService is down") end
	return answer
end)
local a, b = H.player("Policy A"), H.player("Policy B")
answers[a.UserId], answers[b.UserId] = "error", OPEN
check(PolicyGate.Get(a).PaidRandomItemsRestricted and not PolicyGate.Get(a).PaidItemTradingAllowed, "failed lookup restricts")
check(not PolicyGate.Get(b).PaidRandomItemsRestricted, "open lookup")
local before = calls
PolicyGate.Get(b) PolicyGate.Get(b)
check(calls == before, "a known answer is cached")
answers[a.UserId] = OPEN
PolicyGate.Forget(a)
check(not PolicyGate.Get(a).PaidRandomItemsRestricted, "a fresh lookup replaces the fallback")

-- trade requests, both ways
answers[a.UserId], answers[b.UserId] = CLOSED, OPEN
PolicyGate.Forget(a) PolicyGate.Forget(b)
check(PolicyGate.TradeBlocked(a, "InviteTrade", { UserId = b.UserId }) == PlayPolicy.Copy.Trading, "restricted player can't invite")
check(PolicyGate.TradeBlocked(b, "InviteTrade", { UserId = a.UserId }) == PlayPolicy.Copy.TradingPartner, "nobody can invite a restricted player")
check(PolicyGate.TradeBlocked(a, "CancelTrade", {}) == nil, "restricted player can still leave a trade")
check(PolicyGate.TradeBlocked(b, "ConfirmTrade", {}) == nil, "open player confirms")

-- --- GameService purchase paths ---------------------------------------------------
local one = setmetatable({}, { __index = function() return function() return 1 end end })
local function service(profile, player)
	local data = { profile = profile }
	function data:Update(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if not (type(r) == "table" and r.ok == false) then self.profile = draft end
		return true, r
	end
	function data:AtomicUpdate(p, cb) return self:Update(p, cb) end
	function data:Get() return self.profile end
	function data:Save() return true end
	local fields = {
		_data = data, _runtime = { [player] = {} }, _running = true, _random = H.env.Random.new(9),
		_antiCheat = { Observe = function() return nil, false end },
		_convergence = one, _events = one, _crews = one, _fluxSurge = one,
		_syncLeaderstats = function() end, _pushState = function() end, _toastPlayer = function() end, _effect = H.Stub,
	}
	return setmetatable(fields, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end
local function rich()
	local p = DataTemplate.New()
	p.Stardust, p.Cores, p.Cash = 1e6, 1e6, 1e12
	return p
end

local paidKeys, flux = 0, 0
for _, offer in GameConfig.Items.ShopOffers do
	if PlayPolicy.isPaidRandomOffer(offer) then
		paidKeys += 1
		local s, data = service(rich(), a)
		local snapshot = deepCopy(data.profile)
		local r = s:_buyItemOffer(a, offer.Id)
		check(r.ok == false and r.error == PlayPolicy.Copy.PaidRandom, "restricted buy refused with the policy copy: " .. offer.Id)
		check(deepEqual(snapshot, data.profile), "a refused buy changes nothing: " .. offer.Id)
		local s2, data2 = service(rich(), b)
		check(s2:_buyItemOffer(b, offer.Id).ok == true, "open region buys: " .. offer.Id)
		check(data2.profile[offer.Currency] == 1e6 - offer.Price, "open buy charged once: " .. offer.Id)
	elseif offer.Kind == "Key" and offer.Price == 0 then
		local s = service(rich(), a)
		check(s:_buyItemOffer(a, offer.Id).ok == true, "free keys stay open when restricted: " .. offer.Id)
	elseif offer.Kind ~= "Item" and offer.Currency == "Cash" then
		flux += 1
		local s = service(rich(), a)
		check(s:_buyItemOffer(a, offer.Id).ok == true, "Flux offers stay open when restricted: " .. offer.Id)
	end
end
check(paidKeys > 0, "found Stardust or Cores key offers")

local ShopCatalog = SharedData("ShopCatalog")
local found = 0
local today = ShopCatalog.day(os.time())
-- the daily roll is per player, so look across fresh restricted players for paid random offers today
for _ = 1, 200 do
	if found >= 6 then break end
	local shopper = H.player()
	answers[shopper.UserId] = CLOSED
	for _, offer in ShopCatalog.roll(shopper.UserId, today, {}) do
		if PlayPolicy.isPaidRandomOffer(offer) then
			found += 1
			local s, data = service(rich(), shopper)
			local snapshot = deepCopy(data.profile)
			local r = s:_buyDailyOffer(shopper, offer.Slot)
			check(r.ok == false and r.error == PlayPolicy.Copy.PaidRandom, "restricted daily offer refused: " .. offer.Id .. " (" .. tostring(r.error) .. ")")
			check(deepEqual(snapshot, data.profile), "a refused daily offer changes nothing: " .. offer.Id)
		end
	end
end
check(found > 0, "found a paid random daily offer")

-- --- crate odds match the roll -------------------------------------------------------
local items = GameConfig.Items
local order = CrateConfig.RarityOrder
for _, crate in items.Crates do
	for _, pity in { 0, math.max(0, (crate.PityAfter or 1) - 1) } do
		local odds = CrateOdds.crateOdds(crate, items.Rarities, items.Definitions, order, pity)
		local total = 0
		for _, row in odds do
			total += row.chance
			local itemTotal = 0
			for _, item in row.items do itemTotal += item.chance end
			check(#row.items == 0 or near(itemTotal, row.chance), "item chances add up to the rarity: " .. crate.Id .. " " .. row.rarity)
		end
		check(near(total, 1), "odds add to 100%: " .. crate.Id .. " pity " .. pity)
		-- walk the resolver across its whole random range and count where each slice lands
		local steps = 20000
		local counts = {}
		local maximum
		for step = 0, steps - 1 do
			local function nextNumber(lo, hi)
				maximum = hi
				return lo + (hi - lo) * (step + 0.5) / steps
			end
			local _, rarity = Resolver.roll(crate, pity, items.Rarities, items.Definitions, function(d) return d.Rarity end,
				nextNumber, function(lo) return lo end, order, CrateConfig.MinimumRollInterval)
			counts[rarity] = (counts[rarity] or 0) + 1
		end
		for _, row in odds do
			local seen = (counts[row.rarity] or 0) / steps
			check(math.abs(seen - row.chance) <= 1 / steps + 1e-9, string.format("%s pity %d: %s shows %.5f, rolls %.5f", crate.Id, pity, row.rarity, row.chance, seen))
		end
	end
	local empty = CrateOdds.emptyRarities(crate, items.Rarities, items.Definitions, order)
	check(#empty == 0, crate.Id .. " can roll a rarity with no items: " .. table.concat(empty, ", "))
end

PolicyGate.SetLookupForTests(function() return OPEN end)

if #failures > 0 then
	error("play policy failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] play policy: %d checks (policy fallback, paid keys and caches, trade gating, crate odds vs the roll) passed", checks))
