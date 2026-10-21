--!nocheck
-- Companion relics: any relic can ride in the companion slot for a share of its effect as a
-- global bonus. Covers the bonus math, equip/swap/detach through GameService, Equip Best leaving
-- the companion alone, save cleanup, and the trade guard treating a companion as equipped.
-- Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local Companion = H.load("Shared/AstralForge/Shared/CompanionRelic")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")
local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
local TradeOfferMath = H.load("Server/AstralForge/Modules/TradeSuite")("TradeOfferMath")

local function near(a, b) return math.abs(a - b) < 1e-9 end

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end

local function profileWith()
	local p = DataTemplate.New()
	p.Items.Inventory = {
		a = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 1 },   -- Production, Machine, 0.03
		b = { DefinitionId = "CapacityCoil", Level = 3, Stars = 2, AcquiredAt = 2 }, -- Capacity, 0.05, growth 0.24
	}
	p.Items.Equipped = {}
	return p
end

-- bonus math
do
	local p = profileWith()
	check(Companion.bonus(p.Items, "Production") == 0, "empty slot gives nothing")
	check(Companion.describe(p.Items) == nil, "empty slot describes as nothing")
	p.Items.Equipped[Companion.TARGET] = "a"
	check(near(Companion.bonus(p.Items, "Production"), 0.03 * Companion.SHARE), "level 1 companion gives its share")
	check(Companion.bonus(p.Items, "Capacity") == 0, "only its own kind")
	p.Items.Equipped[Companion.TARGET] = "b"
	local expected = 0.05 * (1 + 0.24 * 2) * (1 + 0.25 * 2) * Companion.SHARE
	check(near(Companion.bonus(p.Items, "Capacity"), expected), "level and stars count")
	check(Companion.describe(p.Items).Name == "Capacity Coil", "describe names it")
	check(near(Economy.ItemEffect(p, "Capacity", "Research"), expected), "research-wide lookups include the companion")
	check(Economy.ItemEffect(p, "Capacity", "Machine") == 0, "machine lookups don't")
	check(TradeOfferMath.ItemEquipped(p, "b") == true, "a companion can't be traded away")
	p.Items.Equipped[Companion.TARGET] = "gone"
	Companion.sanitize(p.Items)
	check(p.Items.Equipped[Companion.TARGET] == nil, "a stale companion is cleared")
end

-- saves keep it, and drop it only when it points at nothing
do
	local p = profileWith()
	p.Items.Equipped[Companion.TARGET] = "b"
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	check(clean.Items.Equipped[Companion.TARGET] == "b", "a saved companion survives load")
	p.Items.Equipped[Companion.TARGET] = "missing"
	clean = DataService.normalizeStoredProfile(deepCopy(p))
	check(clean.Items.Equipped[Companion.TARGET] == nil, "a missing companion is dropped on load")
end

-- through GameService
local function service(profile, player)
	local data = { profile = profile }
	function data:AtomicUpdate(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if type(r) == "table" and r.ok == false then return false, r end
		self.profile = draft
		return true, r
	end
	function data:Get() return self.profile end
	return setmetatable({
		_data = data, _runtime = { [player] = {} }, _running = true,
		_toastPlayer = function() end,
		_queueStatePush = function() end,
	}, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end

do
	local player = H.player("Companion owner")
	local s, data = service(profileWith(), player)
	local r = s:_equipItem(player, "b", Companion.TARGET)
	check(r and r.ok, "any relic can be the companion")
	check(data.profile.Items.Equipped[Companion.TARGET] == "b", "it's stored in the companion slot")
	r = s:_equipItem(player, "a", Companion.TARGET)
	check(r and r.ok and data.profile.Items.Equipped[Companion.TARGET] == "a", "a second pick swaps it")
	r = s:_equipItem(player, "a", "Machine:StellarCore")
	check(r and r.ok, "the companion can be socketed")
	check(data.profile.Items.Equipped[Companion.TARGET] == nil, "socketing it frees the companion slot")
	check(data.profile.Items.Equipped["Machine:StellarCore"] == "a", "and it lands in the socket")

	s:_equipItem(player, "b", Companion.TARGET)
	data.profile.Items.Equipped["Machine:StellarCore"] = nil
	r = s:_equipBestItems(player)
	check(r and r.ok, "equip best runs")
	check(data.profile.Items.Equipped[Companion.TARGET] == "b", "equip best leaves the companion in place")
	for target, uid in data.profile.Items.Equipped do
		check(target == Companion.TARGET or uid ~= "b", "equip best doesn't socket the companion as well")
	end
	r = s:_unequipItem(player, Companion.TARGET)
	check(r and r.ok and data.profile.Items.Equipped[Companion.TARGET] == nil, "detaching sends it home")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("companion relics: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] companion relics: %d checks (bonus math, slot swaps, equip best, saves, trade guard) passed", checks))
