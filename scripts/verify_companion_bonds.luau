--!nocheck
-- Companion Bonds (v8 #3): bond XP curve, evolutions at ranks 3/6/10 stepping the share from 40%
-- to 70%, the trait offer and pick, save cleanup, the pause flag, bond travelling with the relic
-- through a trade copy, and the CompanionAct path through GameService. Run `npx rbxtsc` first.
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
local Bonds = H.load("Server/AstralForge/Services/Gameplay/CompanionBonds")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local DataService = H.load("Server/AstralForge/Services/DataService")
local TradeExchange = H.load("Server/AstralForge/Modules/TradeSuite")("TradeExchange")

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
		a = { DefinitionId = "IonCoupler", Level = 1, AcquiredAt = 1 },
		b = { DefinitionId = "CapacityCoil", Level = 1, AcquiredAt = 2 },
	}
	p.Items.Equipped = { [Companion.TARGET] = "a" }
	return p
end

-- curve and shares
check(Companion.rankForXP(0) == 1, "rank 1 at no XP")
check(Companion.rankForXP(Companion.RANK_XP[3]) == 3, "rank 3 at its threshold")
check(Companion.rankForXP(10 ^ 9) == Companion.MAX_RANK, "rank caps at 10")
check(near(Companion.shareFor(1), 0.4) and near(Companion.shareFor(2), 0.4), "40% before the first evolution")
check(near(Companion.shareFor(3), 0.5) and near(Companion.shareFor(6), 0.6) and near(Companion.shareFor(10), 0.7), "50/60/70% at ranks 3/6/10")
check(Companion.xpFor(10 / 60, 0, 0) == 1, "ten seconds online is one XP")
check(Companion.xpFor(100, 1000, 1000) == 40, "one pass is capped")

-- XP, evolution and the trait pick
do
	local p = profileWith()
	local base = Companion.bonus(p.Items, "Production")
	check(near(base, 0.03 * 0.4), "an unbonded companion gives the old 40%")
	check(Companion.addBondXP(p.Items, 50) == 0, "a plain gain reports 0")
	check(p.Items.Inventory.a.Bond.XP == 50 and p.Items.Inventory.a.Bond.Rank == 1, "XP is stored on the relic")
	local evolved = Companion.addBondXP(p.Items, Companion.RANK_XP[3])
	check(evolved == 3, "crossing rank 3 reports the evolution")
	local d = Companion.describe(p.Items)
	check(d.Rank == 3 and d.Suffix == "Bonded", "rank 3 carries the first suffix")
	check(near(Companion.bonus(p.Items, "Production"), 0.03 * 0.5), "rank 3 pays 50%")
	check(d.Offer ~= nil and #d.Offer == 2 and d.Offer[1].Id ~= d.Offer[2].Id, "two different traits are offered")
	local ok = Companion.pickTrait(p.Items, "NotATrait")
	check(not ok, "an unoffered trait is refused")
	local pick = d.Offer[1]
	ok = Companion.pickTrait(p.Items, pick.Id)
	check(ok, "an offered trait is taken")
	check(p.Items.Inventory.a.Bond.Trait == pick.Id and p.Items.Inventory.a.Bond.Offer == nil, "the trait is saved and the offer closes")
	check(not Companion.pickTrait(p.Items, d.Offer[2].Id), "a closed offer can't be picked again")
	local kindBonus = Companion.bonus(p.Items, pick.Kind)
	check(kindBonus >= pick.Amount - 1e-9, "the trait adds to its kind")
	Companion.addBondXP(p.Items, 10 ^ 9)
	check(p.Items.Inventory.a.Bond.Rank == 10 and near(Companion.describe(p.Items).Share, 0.7), "rank 10 is the 70% top")
	check(Companion.addBondXP(p.Items, 5) == nil, "a maxed bond stops changing")
	local offer = Companion.describe(p.Items).Offer
	check(offer ~= nil and offer[1].Id ~= pick.Id and offer[2].Id ~= pick.Id, "a later evolution offers traits other than the current one")
	-- detached companions keep their bond but give nothing
	p.Items.Equipped[Companion.TARGET] = nil
	check(Companion.bonus(p.Items, "Production") == 0, "no companion, no share or trait")
	check(p.Items.Inventory.a.Bond.Rank == 10, "the bond stays on the relic")
end

-- saves: junk is clamped, an empty bond is dropped, a real one survives load unchanged
do
	local p = profileWith()
	p.Items.Inventory.a.Bond = { XP = Companion.RANK_XP[6], Rank = 99, Trait = "Scout", Offer = { "Hoarder", "Hoarder" } }
	p.Items.Inventory.b.Bond = { XP = 0 / 0 }
	local clean = DataService.normalizeStoredProfile(deepCopy(p))
	local bond = clean.Items.Inventory.a.Bond
	check(bond.Rank == 6 and bond.Trait == "Scout" and bond.Offer == nil, "rank is recomputed and a broken offer dropped")
	check(clean.Items.Inventory.b.Bond == nil, "an empty bond is dropped")
	local again = DataService.normalizeStoredProfile(deepCopy(clean))
	check(again.Items.Inventory.a.Bond.XP == bond.XP and again.Items.Inventory.a.Bond.Rank == 6, "loading twice changes nothing")
	local untouched = DataService.normalizeStoredProfile(deepCopy(profileWith()))
	check(untouched.Items.Inventory.a.Bond == nil, "a relic that never bonded saves as before")
	local copy = TradeExchange.CopyItemInstance(bond and clean.Items.Inventory.a)
	check(copy.Bond ~= nil and copy.Bond.XP == bond.XP and copy.Bond ~= bond, "the bond travels with a traded relic")
end

-- the runtime counters, settle and the pause flag
do
	local p = profileWith()
	local runtime = { BondAt = 100 }
	for _ = 1, 20 do Bonds.Record(runtime, "Overcharge") end
	Bonds.Record(runtime, "OpenItemCrate")
	Bonds.Record(runtime, "CollectVault")
	check(runtime.BondTaps == 20 and runtime.BondCrates == 1, "taps and crates are counted")
	local changed = Bonds.Settle(runtime, p, 160)
	check(changed and p.Items.Inventory.a.Bond.XP == 6 + 4 + 4, "a minute, 20 taps and a crate bank 14 XP")
	check(runtime.BondTaps == 0 and runtime.BondCrates == 0 and runtime.BondAt == 160, "counters reset after banking")
	local before = p.Items.Inventory.a.Bond.XP
	Bonds.Settle(runtime, p, 160 + 3600)
	check(p.Items.Inventory.a.Bond.XP - before == 6, "a long gap counts as a minute at most")
	HotFlags.Reset()
	check(HotFlags.Set("CompanionBondsPaused", true), "the pause flag exists")
	before = p.Items.Inventory.a.Bond.XP
	Bonds.Record(runtime, "Overcharge")
	changed = Bonds.Settle(runtime, p, 160 + 3700)
	check(not changed and p.Items.Inventory.a.Bond.XP == before, "paused bonds gain nothing")
	check(not Bonds.Act(p, { Op = "PickTrait", Trait = "Scout" }), "paused bonds refuse trait picks")
	HotFlags.Reset()
end

-- CompanionAct through GameService
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
	local player = H.player("Bond owner")
	local p = profileWith()
	Companion.addBondXP(p.Items, Companion.RANK_XP[3])
	local s, data = service(p, player)
	local offer = Companion.describe(data.profile.Items).Offer
	local r = s:_companionAct(player, { Op = "PickTrait", Trait = "Nope" })
	check(r and r.ok == false, "GameService refuses an unoffered trait")
	r = s:_companionAct(player, { Op = "PickTrait", Trait = offer[2].Id })
	check(r and r.ok and data.profile.Items.Inventory.a.Bond.Trait == offer[2].Id, "GameService saves the pick")
end

if #failures > 0 then
	for _, f in failures do print("[FAIL] " .. f) end
	error(string.format("companion bonds: %d of %d checks failed", #failures, checks))
end
print(string.format("[TEST] companion bonds: %d checks (curve, evolutions, trait pick, saves, trade copy, pause, CompanionAct) passed", checks))
