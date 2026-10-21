--!nocheck
-- Relic engraving: lines open at levels 10/25/50, rolls stay inside the rarity's range and never
-- repeat a kind, costs climb and locks raise them, only working relics pay, saves are repaired,
-- trades carry the lines intact, and EngravingPaused refuses new rolls. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures, checks = {}, 0
local function check(cond, label) checks += 1 if not cond then table.insert(failures, label) end end
local function near(a, b) return math.abs(a - b) < 1e-9 end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {} for k, x in v do out[k] = deepCopy(x) end return out
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local E = H.load("Shared/AstralForge/Shared/RelicEngraving")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
local TradeExchange = H.load("Server/AstralForge/Modules/TradeSuite")("TradeExchange")

local function seq(...)
	local values, i = { ... }, 0
	return function() i = i % #values + 1 return values[i] end
end

-- slots and ceilings
check(E.slotsAt(1) == 0 and E.slotsAt(10) == 1 and E.slotsAt(25) == 2 and E.slotsAt(50) == 3 and E.slotsAt(900) == 3, "slots open at 10/25/50")
check(near(E.ceilingFor("Tap", "Common"), 0.04) and near(E.ceilingFor("Tap", "Astral"), 0.04 * 2.4), "rarity scales the ceiling")
check(E.ceilingFor("Nope", "Common") == 0, "unknown kinds have no ceiling")

local DEF = { EssenceBase = 20, Rarity = "Rare" }

-- rolling
do
	local inst = { DefinitionId = "AutoRelay", Level = 5 }
	local wallet = { Essence = 10000, Starsteel = 50 }
	local ok, msg = E.roll(inst, DEF, 1, wallet, seq(0, 1))
	check(not ok and string.find(msg, "10") ~= nil and wallet.Essence == 10000, "below level 10 nothing happens")
	inst.Level = 30
	check(not E.roll(inst, DEF, 2, wallet, seq(0, 1)), "lines fill in order")
	check(not E.roll(inst, DEF, 3, wallet, seq(0, 1)), "line 3 waits for level 50")
	check(not E.roll(inst, DEF, 1.5, wallet, seq(0, 1)), "fractional lines are refused")
	local price = E.cost(DEF, nil)
	check(price.Essence == 60 and price.Starsteel == 3, "first roll costs 3x base Essence and rank Starsteel")
	ok = E.roll(inst, DEF, 1, wallet, seq(0, 1))
	check(ok and inst.Engraving.Lines[1].Kind == "Production", "first kind from the roll")
	check(near(inst.Engraving.Lines[1].Value, E.ceilingFor("Production", "Rare")), "a top roll hits the ceiling")
	check(wallet.Essence == 10000 - 60 and wallet.Starsteel == 47, "the roll is paid")
	ok = E.roll(inst, DEF, 2, wallet, seq(0, 0))
	check(ok and inst.Engraving.Lines[2].Kind == "Capacity", "a second line can't repeat the first kind")
	check(near(inst.Engraving.Lines[2].Value, E.ceilingFor("Capacity", "Rare") * 0.4), "a bottom roll is 40% of the ceiling")
	check(E.cost(DEF, inst.Engraving).Essence == math.floor(20 * 3 * 1.5), "costs climb with rolls")
	check(E.toggleLock(inst, "Rare", 1), "lock a line")
	check(E.cost(DEF, inst.Engraving).Essence == math.floor(20 * 3 * 1.5 * 2), "a lock doubles the reroll")
	check(not E.roll(inst, DEF, 1, wallet, seq(0, 1)), "a locked line can't be rerolled")
	local before = inst.Engraving.Lines[1].Value
	ok = E.roll(inst, DEF, 2, wallet, seq(0, 0.5))
	check(ok and inst.Engraving.Lines[1].Value == before and inst.Engraving.Lines[2].Kind ~= "Production", "rerolling one line leaves the locked one")
	local poor = { Essence = 1, Starsteel = 99 }
	ok, msg = E.roll(inst, DEF, 2, poor, seq(0, 1))
	check(not ok and string.find(msg, "Essence") ~= nil and poor.Essence == 1, "short on Essence")
	poor = { Essence = 99999, Starsteel = 0 }
	ok, msg = E.roll(inst, DEF, 2, poor, seq(0, 1))
	check(not ok and string.find(msg, "Starsteel") ~= nil and poor.Essence == 99999, "short on Starsteel")
	check(not E.toggleLock({ Level = 30 }, "Rare", 1), "nothing to lock on a blank relic")
end

-- repair
do
	local inst = { Level = 26, Engraving = { Rolls = -4, Lines = {
		{ Kind = "Tap", Value = 99 },
		{ Kind = "Tap", Value = 0.01 },
		{ Kind = "Bogus", Value = 0.01 },
		{ Kind = "Offline", Value = 0 / 0 },
		{ Kind = "Offline", Value = 0.02, Locked = true },
		{ Kind = "Critical", Value = 0.001 },
	} } }
	E.sanitize(inst, "Common")
	local lines = inst.Engraving.Lines
	check(#lines == 2, "no more lines than the level allows")
	check(lines[1].Kind == "Tap" and near(lines[1].Value, 0.04), "values clamp to the ceiling")
	check(lines[2].Kind == "Offline" and lines[2].Locked == true, "repeats, junk and NaN are dropped, locks kept")
	check(inst.Engraving.Rolls == 0, "bad roll counts reset")
	local blank = { Level = 60, Engraving = "x" }
	E.sanitize(blank, "Common")
	check(blank.Engraving == nil, "a wrong-typed engraving is removed")
end

-- only working relics pay
local function profileWith()
	local p = DataTemplate.New()
	p.Items.Inventory = {
		a = { DefinitionId = "CapacityCoil", Level = 30, AcquiredAt = 1, Engraving = { Rolls = 2, Lines = { { Kind = "Tap", Value = 0.03 }, { Kind = "Offline", Value = 0.02 } } } },
		b = { DefinitionId = "IonCoupler", Level = 12, AcquiredAt = 2, Engraving = { Rolls = 1, Lines = { { Kind = "Tap", Value = 0.01 } } } },
	}
	p.Items.Equipped = {}
	p.Items.Essence = 5000
	p.Ore.Starsteel = 20
	return p
end
do
	local p = profileWith()
	check(E.bonus(p.Items, "Tap") == 0, "relics in the bag pay nothing")
	p.Items.Equipped["Research:Storage"] = "a"
	p.Items.Equipped["Companion:1"] = "b"
	check(near(E.bonus(p.Items, "Tap"), 0.04), "socketed and companion relics both pay")
	p.Items.Equipped["Research:Other"] = "a"
	check(near(E.bonus(p.Items, "Tap"), 0.04), "a relic is counted once")
	local without = deepCopy(p)
	without.Items.Inventory.a.Engraving = nil
	check(near(Economy.ItemEffect(p, "Offline", "Research") - Economy.ItemEffect(without, "Offline", "Research"), 0.02),
		"research-wide lookups include engraving")
	check(Economy.ItemEffect(p, "Tap", "Machine") == 0, "per-machine lookups don't")
end

-- saves and trades keep lines intact
do
	local p = profileWith()
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local lines = clean.Items.Inventory.a.Engraving.Lines
	check(#lines == 2 and lines[1].Kind == "Tap" and near(lines[1].Value, 0.03), "engraving survives a load")
	local copy = TradeExchange.CopyItemInstance(p.Items.Inventory.a)
	check(copy.Engraving.Lines[1].Kind == "Tap", "a traded relic carries its lines")
	copy.Engraving.Lines[1].Value = 0
	check(near(p.Items.Inventory.a.Engraving.Lines[1].Value, 0.03), "the copy shares nothing with the original")
end

-- through GameService
local function service(p, player)
	local data = { profile = p }
	function data:AtomicUpdate(_, cb)
		local draft = deepCopy(self.profile)
		local r = cb(draft)
		if type(r) == "table" and r.ok == false then return false, r end
		self.profile = draft
		return true, r
	end
	function data:Get() return self.profile end
	return setmetatable({
		_data = data, _runtime = { [player] = {} }, _running = true, _random = { NextNumber = function() return 0.5 end },
		_toastPlayer = function() end, _queueStatePush = function() end,
	}, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end
do
	local player = H.player("Engraver")
	local s, data = service(profileWith(), player)
	local r = s:_engraveRelic(player, { Uid = "b", Op = "Roll", Line = 1 })
	check(r and r.ok, "reroll through the service")
	local inst = data.profile.Items.Inventory.b
	check(#inst.Engraving.Lines == 1 and inst.Engraving.Rolls == 2, "the line is rewritten and counted")
	check(data.profile.Items.Essence < 5000 and data.profile.Ore.Starsteel == 19, "Essence and Starsteel are spent")
	r = s:_engraveRelic(player, { Uid = "b", Op = "Lock", Line = 1 })
	check(r and r.ok and data.profile.Items.Inventory.b.Engraving.Lines[1].Locked == true, "lock through the service")
	r = s:_engraveRelic(player, { Uid = "zzz", Op = "Roll", Line = 1 })
	check(r and not r.ok, "someone else's relic is refused")
	HotFlags.Set("EngravingPaused", true, os.time() + 30)
	local essence = data.profile.Items.Essence
	r = s:_engraveRelic(player, { Uid = "a", Op = "Roll", Line = 1 })
	check(r and not r.ok and data.profile.Items.Essence == essence, "paused engraving spends nothing")
	HotFlags.Set("EngravingPaused", false, os.time() + 40)
	r = s:_engraveRelic(player, { Uid = "a", Op = "Roll", Line = 2 })
	check(r and r.ok, "unpaused engraving works again")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("relic engraving: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] relic engraving: %d checks (slots, rolls, costs, locks, repair, trades, pause flag) passed", checks))
