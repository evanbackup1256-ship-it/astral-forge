--!nocheck
-- Server gameplay rules, read from the compiled TS (out/) through scripts/_server_harness:
-- trading (offer validation, exchange conservation, revert, relic re-keying), crate rolls
-- (weights, pity, roll edges) against the real crate config, research cost math, and the
-- rebirth ledger (quote, carry, close, vows, keepsakes). Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not deepEqual(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[k] = deepCopy(x) end
	return out
end

local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local DataTemplate = H.load("Server/AstralForge/DataTemplate")
local Suite = H.load("Server/AstralForge/Modules/TradeSuite")

---------------------------------------------------------------- trading
local Exchange = Suite.TradeExchange
local OfferMath = Suite.TradeOfferMath
local RequestMath = Suite.TradeRequestMath
local Omega = H.load("Shared/AstralForge/Shared/OmegaMath")
local CUR, BOOSTS, KEYS = Exchange.CURRENCIES, Exchange.BOOST_IDS, Exchange.KEY_IDS
local firstDef = GameConfig.Items.Definitions[1].Id

local function trader(cash)
	local p = DataTemplate.New()
	p.Cash = cash or 1e6
	p.Stardust = 1000
	p.Cores = 50
	p.Rebirths = 5
	p.Items.Inventory = {}
	p.Items.Essence = 40
	p.Items.NextId = 1
	return p
end
local function relic(p, uid, extra)
	local r = { DefinitionId = firstDef, Level = 3, AcquiredAt = 1 }
	for k, v in extra or {} do r[k] = v end
	p.Items.Inventory[uid] = r
	return r
end

-- junk offers become clean, non-negative integer bags
for label, raw in { string = "x", number = 5, negative = { Cash = -5, Stardust = -1 }, nan = { Cash = 0 / 0 }, frac = { Cash = 2.7 },
	badLists = { Boosts = "x", Keys = 5, ItemIds = { 1, true, "", "IT1", "IT1" } } } do
	local offer = OfferMath.CopyOffer(raw, CUR, BOOSTS, KEYS)
	local clean = true
	for _, key in CUR do
		local v = offer[key]
		if type(v) ~= "number" or v ~= v or v < 0 or v % 1 ~= 0 then clean = false end
	end
	for _, id in BOOSTS do if offer.Boosts[id] ~= 0 then clean = false end end
	check(clean, "junk offer normalized: " .. label)
	if label == "badLists" then check(#offer.ItemIds == 1 and offer.ItemIds[1] == "IT1", "item ids deduped, junk dropped") end
	if label == "frac" then check(offer.Cash == 2, "fractional amounts floored") end
end
check(OfferMath.OfferEmpty(OfferMath.EmptyOffer(BOOSTS, KEYS), CUR, BOOSTS, KEYS), "empty offer is empty")
check(not OfferMath.OfferEmpty({ ItemIds = { "IT1" } }, CUR, BOOSTS, KEYS), "an item makes an offer non-empty")
local req = RequestMath.Normalize({ ItemIds = { "a", "a", "b", string.rep("x", 49) }, Cash = 1e300, Stardust = -3 }, { Items = 2, Cash = 500, Stardust = 9 }, CUR)
check(#req.ItemIds == 2 and req.Cash == 500 and req.Stardust == nil, "trade request caps and drops bad amounts")

-- a full trade through the desk, then the exchange applied and reverted
local desk = Suite.TradeDesk.new()
local now = os.time()
local A, B = H.player("TA"), H.player("TB")
local pa, pb = trader(), trader()
relic(pa, "IT0000001")
relic(pa, "IT0000002", { Locked = true })
relic(pa, "IT0000003")
pa.Items.Equipped = { Weapon = "IT0000003" }
pa.Items.NextId = 4
relic(pb, "IT0000001", { Level = 9 }) -- same uid on the other side: must never be overwritten
pb.Items.NextId = 2
check(desk:Invite(A, pa, A.UserId, now) == false, "cannot trade with yourself")
check(desk:Invite(A, pa, B.UserId, now) == true, "invite")
check(desk:Respond(B, pb, true, now) == true, "accept")
check(desk:UpdateOffer(A, pa, { Cash = 2e6 }, now) == false, "cannot offer more Flux than owned")
check(desk:UpdateOffer(A, pa, { ItemIds = { "IT0000002" } }, now) == false, "locked relic refused")
check(desk:UpdateOffer(A, pa, { ItemIds = { "IT0000003" } }, now) == false, "equipped relic refused")
check(desk:UpdateOffer(A, pa, { ItemIds = { "IT9999999" } }, now) == false, "missing relic refused")
local caps = GameConfig.Trading.PerTrade
check(desk:UpdateOffer(A, pa, { Stardust = caps.Stardust + 1 }, now) == false or caps.Stardust + 1 > pa.Stardust, "per-trade cap")
check(desk:SetReady(A, pa, true, now) == false, "cannot ready with nothing on the table")
check(desk:UpdateOffer(A, pa, { Cash = 500, ItemIds = { "IT0000001" } }, now) == true, "host offer")
check(desk:UpdateOffer(B, pb, { Stardust = 20, Essence = 5 }, now) == true, "guest offer")
check(desk:Confirm(A, now) == false, "confirm needs both ready")
desk:SetReady(A, pa, true, now)
desk:SetReady(B, pb, true, now)
desk:Confirm(A, now)
local session = desk:SessionFor(A.UserId)
check(desk:TryBeginSettle(session) == false, "settle needs both confirmations")
desk:Confirm(B, now)
check(desk:Plan(session, pa, pb, now + 3600) == nil, "expired confirm window refuses to settle")
check(desk:TryBeginSettle(session) == true and desk:TryBeginSettle(session) == false, "settle begins once")
local okCancel = desk:Cancel(A)
check(desk:SessionFor(A.UserId) ~= nil, "cannot cancel while settling")
local plan = desk:Plan(session, pa, pb, now)
check(plan ~= nil, "plan built")
local beforeA, beforeB = deepCopy(pa), deepCopy(pb)
local errA = desk:ApplyExchange(pa, plan.HostOffer, plan.GuestOffer, plan.HostItems, plan.GuestItems, now)
local errB = desk:ApplyExchange(pb, plan.GuestOffer, plan.HostOffer, plan.GuestItems, plan.HostItems, now)
check(errA == nil and errB == nil, "both sides apply")
check(Omega.ToNumber(pa.Cash) + Omega.ToNumber(pb.Cash) == 2e6, "Flux conserved")
check(pa.Stardust + pb.Stardust == 2000 and pa.Items.Essence + pb.Items.Essence == 80, "Stardust and Essence conserved")
check(pa.Items.Inventory.IT0000001 == nil, "relic left the giver")
check(pb.Items.Inventory.IT0000001 ~= nil and pb.Items.Inventory.IT0000001.Level == 9, "receiver's own relic with the same uid untouched")
local received
for uid, r in pb.Items.Inventory do if uid ~= "IT0000001" then received = r end end
check(received ~= nil and received.Level == 3 and received.DefinitionId == firstDef, "relic arrived under a new uid")
check(received ~= nil and received.NewUid == nil, "received relic carries no trade bookkeeping")
check(pa.Trade.Completed == 1 and pa.Trade.Sent.Cash == 500 and pa.Trade.Sent.Items == 1, "ledger counts the trade")
-- revert both sides: profiles go back exactly
desk:RevertExchange(pa, plan.HostOffer, plan.GuestOffer, plan.HostItems, plan.GuestItems, now)
desk:RevertExchange(pb, plan.GuestOffer, plan.HostOffer, plan.GuestItems, plan.HostItems, now)
pb.Items.NextId = beforeB.Items.NextId -- uids are never reused, so only the counter moves
check(deepEqual(pa, beforeA), "host revert restores the profile exactly")
check(deepEqual(pb, beforeB), "guest revert restores the profile exactly")
-- a stale relic counter never lets an incoming relic overwrite one already owned
do
	local giver, taker = trader(), trader()
	relic(giver, "IT0000001")
	relic(taker, "IT0000001", { Level = 7 })
	relic(taker, "IT0000002", { Level = 8 })
	taker.Items.NextId = 0
	local give = OfferMath.CopyOffer({ ItemIds = { "IT0000001" } }, CUR, BOOSTS, KEYS)
	local items = Exchange.SnapshotOfferItems(give, giver)
	local err = desk:ApplyExchange(taker, OfferMath.EmptyOffer(BOOSTS, KEYS), give, {}, items, now)
	local count = 0
	for _ in taker.Items.Inventory do count += 1 end
	check(err == nil and count == 3 and taker.Items.Inventory.IT0000001.Level == 7 and taker.Items.Inventory.IT0000002.Level == 8,
		"stale NextId: incoming relic gets a free uid")
end
-- daily limits survive across trades and reset on a new UTC day
do
	local p = trader()
	OfferMath.EnsureLedger(p, now)
	p.Trade.Sent.Stardust = GameConfig.Trading.Daily.Stardust
	local reason = desk:_validateOffer(p, OfferMath.CopyOffer({ Stardust = 1 }, CUR, BOOSTS, KEYS), now, false)
	check(type(reason) == "string", "daily Stardust limit")
	OfferMath.EnsureLedger(p, now + 86400)
	check(p.Trade.Sent.Stardust == 0 and p.Trade.Completed == 0, "ledger resets on a new day")
end

---------------------------------------------------------------- crates
local Crates = H.load("Server/AstralForge/Modules/CrateRollResolver")
local CrateConfig = H.load("Shared/AstralForge/Shared/CrateConfig")
local rarities, defs = GameConfig.Items.Rarities, GameConfig.Items.Definitions
local order = CrateConfig.RarityOrder
local inOrder = {}
for _, r in order do inOrder[r] = true end
local crateCount = 0
for crateId, crate in GameConfig.Items.Crates do
	crateCount += 1
	for rarity, weight in crate.Weights do
		check(inOrder[rarity] == true, "crate " .. tostring(crateId) .. " weight for a rarity outside the roll order: " .. rarity)
		check(rarities[rarity] ~= nil, "crate " .. tostring(crateId) .. " weight for an unknown rarity: " .. rarity)
		check(type(weight) == "number" and weight >= 0, "crate weight sane: " .. tostring(crateId))
	end
	local function roll(pity, r, i)
		return Crates.roll(crate, pity, rarities, defs, function(d) return d.Rarity end,
			function(lo, hi) return lo + (hi - lo) * r end, function(lo, hi) return math.clamp(i, lo, hi) end,
			order, CrateConfig.MinimumRollInterval)
	end
	for _, r in { 0, 0.5, 1 } do
		local def, rarity = roll(0, r, 1)
		check(def ~= nil and def.Rarity == rarity, "roll " .. r .. " lands on a real relic: " .. tostring(crateId))
		check((crate.Weights[rarity] or 0) > 0 or rarity == crate.PityRarity, "roll never lands on a zero-weight rarity: " .. tostring(crateId))
	end
	local pityRank = rarities[crate.PityRarity] and rarities[crate.PityRarity].Rank or 0
	for _, r in { 0, 0.3, 0.99 } do
		local _, rarity, hit = roll(crate.PityAfter - 1, r, 1)
		check(rarities[rarity].Rank >= pityRank and hit == true, "pity guarantees its rarity: " .. tostring(crateId))
	end
	check(pcall(roll, 0 / 0, 0, 1) == false, "NaN pity refused")
end
check(crateCount > 0, "crates configured")

---------------------------------------------------------------- research costs
local Economy = H.load("Server/AstralForge/Modules/EconomyMath")("Economy")
for _, def in GameConfig.Research do
	for _, level in { 0, 3, 17 } do
		local sum = 0
		for i = 0, 4 do sum += Omega.ToNumber(Economy.ResearchCost(def.Id, level + i)) end
		local bulk = Omega.ToNumber(Economy.ResearchBulkCost(def.Id, level, 5))
		check(math.abs(bulk - sum) <= math.max(1, sum * 1e-9), "bulk research cost is the sum of levels: " .. def.Id)
		local count = Economy.AffordableResearchLevels(def.Id, level, bulk, 1000)
		check(count == 5, "exact budget buys exactly the bulk count: " .. def.Id .. " got " .. tostring(count))
		local short = Economy.AffordableResearchLevels(def.Id, level, Omega.Mul(Economy.ResearchCost(def.Id, level), 1 - 1e-9), 1000)
		check(short == 0, "one short buys nothing: " .. def.Id)
	end
end
check(Economy.ResearchCost("NoSuchResearch", 0) == math.huge and Economy.AffordableResearchLevels("NoSuchResearch", 0, 1e300, 10) == 0, "unknown research costs infinity and buys nothing")

---------------------------------------------------------------- rebirth ledger
local Rebirth = H.load("Shared/AstralForge/Shared/RebirthMath")
do
	local bag = Rebirth.ensure(nil, 1000, 0)
	check(bag.Lifetime == 0 and bag.Vow == "" and bag.RunStartedAt == 1000, "fresh ledger")
	local junk = Rebirth.ensure({ Lifetime = "x", Runs = "y", Keep = 5, Stars = 1, Kept = true }, 1000, 3)
	check(junk.Lifetime == 3 and type(junk.Runs) == "table" and type(junk.Keep) == "table", "junk ledger repaired")
	local q = Rebirth.quote(bag, { Cores = 10, Stardust = 7 }, {})
	check(q.Cores >= 10 and q.Stardust >= 7 and q.Kept == false, "plain quote pays the base")
	check(Rebirth.quote(bag, { Cores = 0, Stardust = 0 }, {}).Cores == 1, "a rebirth always pays at least one core")
	local vowId = Rebirth.VOWS[1].Id
	check(Rebirth.swear(bag, vowId, 1000 + Rebirth.VOW_GRACE) == true, "vow inside the grace window")
	check(Rebirth.swear(bag, vowId, 1001 + Rebirth.VOW_GRACE) == false, "vow after the grace window refused")
	check(Rebirth.swear(bag, "NoSuchVow", 1000) == false, "unknown vow refused")
	check(Rebirth.setKeep(bag, { "A", "B" }) and #bag.Keep <= Rebirth.keepSlots(bag.Lifetime), "keepsakes capped by slots")
	local entry = Rebirth.close(bag, q, 1600, "NoSuchVow", nil)
	check(entry.N == 1 and entry.Seconds == 600 and bag.Lifetime == 1 and bag.Vow == "", "close logs the run, drops an unknown vow")
	check(bag.BestCores == q.Cores and bag.FastestSeconds == 600, "best and fastest tracked")
	for i = 1, Rebirth.LOG_LIMIT + 5 do Rebirth.close(bag, q, 1600 + i, nil, nil) end
	check(#bag.Runs == Rebirth.LOG_LIMIT, "run log capped")
	bag.Lifetime = 10 ^ 6
	local machine = GameConfig.Machines[1].Id
	Rebirth.setKeep(bag, { machine, machine, "Nope" })
	local carried = Rebirth.carry(bag, { [machine] = 10 ^ 9, Nope = 5 }, 1e6, 100, function(id) return id ~= "Nope" end)
	check(carried.Machines[machine] ~= nil and carried.Machines[machine] <= Rebirth.KEEP_CAP, "kept machine level capped")
	check(carried.Machines.Nope == nil and carried.Machines.StellarCore >= 1, "disallowed keepsake dropped, core kept")
	check(type(carried.Cash) == "number" and carried.Cash >= 100 and carried.Cash == carried.Cash, "carried Flux sane")
end

if #failures > 0 then
	error("server gameplay failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] server gameplay: %d checks (trading, %d crates, research costs, rebirth ledger) passed", checks, crateCount))
