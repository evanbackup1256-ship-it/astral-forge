--!nocheck
-- The Reaches rules: regions open by rebirths, outcrops are laid out inside their region and never stacked,
-- node ids round-trip and reject junk, the Warden scales with the server, strikes and crits are bounded, and the
-- spoils go only to real fighters with the top striker's bonus. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

local R = H.load("Shared/AstralForge/Shared/Reaches")

-- regions
check(#R.REGIONS == 3, "three regions")
local ember, hollows, spire = R.region("Emberreach"), R.region("Hollows"), R.region("Spire")
check(ember and hollows and spire, "regions found by id")
check(R.region("Nowhere") == nil, "unknown region is nil")
check(R.REGIONS[1].MinRebirths <= R.REGIONS[2].MinRebirths and R.REGIONS[2].MinRebirths <= R.REGIONS[3].MinRebirths, "regions open in order")
check(R.regionOpen(ember, 0), "Emberreach open from the start")
check(not R.regionOpen(hollows, 0) and R.regionOpen(hollows, 1), "Hollows opens at 1 rebirth")
check(not R.regionOpen(spire, 2) and R.regionOpen(spire, 3), "Spire opens at 3 rebirths")
check(not R.regionOpen(spire, "junk"), "junk rebirths count as none")

-- node ids: every outcrop of every region round-trips
for _, entry in R.REGIONS do
	for i = 1, R.NODES_PER_REGION do
		local back, at = R.parseNodeId(R.nodeId(entry, i))
		check(back == entry and at == i, entry.Id .. " outcrop " .. i .. " round-trips")
	end
end
local entry, index = R.parseNodeId(R.nodeId(ember, 3))
check(entry == ember and index == 3, "node id round-trips")
check(R.parseNodeId("Emberreach:0") == nil, "index 0 rejected")
check(R.parseNodeId("Emberreach:99") == nil, "index past the end rejected")
check(R.parseNodeId("Mars:1") == nil, "unknown region rejected")
check(R.parseNodeId(42) == nil, "non-string rejected")
check(R.parseNodeId(string.rep("a", 40) .. ":1") == nil, "overlong id rejected")

-- the Warden
check(R.wardenMaxHp(1) == R.WARDEN.BaseHp + R.WARDEN.PerPlayerHp, "solo Warden hp")
check(R.wardenMaxHp(0) == R.wardenMaxHp(1), "an empty server counts as one player")
check(R.wardenMaxHp(10) > R.wardenMaxHp(2), "more players, more hp")
local dmg, crit = R.strikeDamage(0, 0.99)
check(dmg == 1 and crit == false, "a plain strike deals 1")
dmg, crit = R.strikeDamage(0, 0)
check(dmg == R.WARDEN.CritMultiplier and crit == true, "a critical strike triples")
dmg = R.strikeDamage(1.2, 0.99)
check(math.abs(dmg - 2.2) < 1e-9, "Starsteel Edge adds to every strike")
dmg = R.strikeDamage(-5, 0.99)
check(dmg == 1, "a negative bonus never lowers a strike")

-- spoils
local damage, strikes = {}, {}
damage[1] = 60; strikes[1] = 30
damage[2] = 30; strikes[2] = 15
damage[3] = 10; strikes[3] = 2 -- too few strikes
damage[4] = 0.5; strikes[4] = 3
local spoils = R.spoils(damage, strikes)
check(spoils[1] and spoils[1].Top == true, "the top striker is marked")
check(spoils[2] and spoils[2].Top == false, "others aren't top")
check(spoils[3] == nil, "fewer than three strikes earns nothing")
check(spoils[4] and spoils[4].Starsteel >= 2, "a small share still earns the minimum")
check(spoils[1].Starsteel > spoils[2].Starsteel, "more damage, more Starsteel")
check(spoils[1].Starsteel <= 15, "Starsteel is capped")
check(spoils[1].Stardust > spoils[2].Stardust, "more damage, more Stardust")
local empty = R.spoils({}, {})
check(next(empty) == nil, "no fight, no spoils")

if #failures > 0 then
	error(("[TEST] reaches: %d of %d checks failed:\n  %s"):format(#failures, checks, table.concat(failures, "\n  ")))
end
print(("[TEST] reaches: %d checks (regions, node ids, warden hp, strikes, spoils) passed"):format(checks))
