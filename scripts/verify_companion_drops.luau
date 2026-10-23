--!nocheck
-- Companion crate drops: the table matches the chosen rarities, a hit is always a companion not yet
-- owned, draws above the pool miss, the owned set starts empty on old saves, the client copy only
-- carries known keys, and the long-run hit rate matches the listed chances. Run rbxtsc first.
local H = require("./_server_harness")
local D = H.load("Shared/AstralForge/Shared/CompanionDrops")

local want = { Cinder = "Rare", Frostlet = "Rare", Tidepup = "Epic", BrassOwl = "Legendary", Lumen = "Mythic", Voidmote = "Celestial" }
local seen = 0
for _, drop in D.COMPANION_DROPS do
	assert(want[drop.Key] == drop.Rarity, "rarity for " .. drop.Key)
	assert(drop.Chance > 0 and drop.Chance <= 0.05, "small chance for " .. drop.Key)
	seen += 1
end
assert(seen == 6, "six companions")

-- old save: no field, created empty
local profile = {}
local owned = D.ensureOwned(profile)
assert(next(owned) == nil and profile.Companions == owned, "optional field defaults to empty")
assert(D.ensureOwned(profile) == owned, "same table on the second call")

-- no entry for the rarity, or a draw above the pool, misses
assert(D.rollCompanion("Common", {}, function() return 0 end) == nil, "no Common entries")
assert(D.rollCompanion("Rare", {}, function() return 0.999 end) == nil, "high draw misses")
-- draw 0 hits the first Rare; owning it moves the hit to the second; owning both leaves nothing
assert(D.rollCompanion("Rare", {}, function() return 0 end) == "Cinder", "first Rare")
assert(D.rollCompanion("Rare", { Cinder = true }, function() return 0 end) == "Frostlet", "skips owned")
assert(D.rollCompanion("Rare", { Cinder = true, Frostlet = true }, function() return 0 end) == nil, "all owned")
assert(D.rollCompanion("Celestial", {}, function() return 0.01 end) == "Voidmote", "Celestial entry")

-- client copy: only known keys set to true
local pub = D.publicOwned({ Cinder = true, Lumen = false, Bogus = true })
assert(pub.Cinder == true and pub.Lumen == nil and pub.Bogus == nil, "public copy filters")
assert(next(D.publicOwned(nil)) == nil, "nil save is empty")

-- long run: Epic hit rate close to the listed chance
local state = 7
local function nextUnit()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
local hits, N = 0, 400000
for _ = 1, N do
	if D.rollCompanion("Epic", {}, nextUnit) then hits += 1 end
end
local rate = hits / N
assert(math.abs(rate - 0.005) < 0.0007, "Epic rate " .. rate)

print(`[TEST] companion drops: 6 entries, owned skip, save default, rate {string.format("%.4f", rate)}`)
