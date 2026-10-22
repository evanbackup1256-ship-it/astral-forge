--!nocheck
-- Crate RNG: streams are deterministic per seed and stay in range, integers are unbiased, seeds
-- differ per player, crate and open, a seeded roll replays exactly, the long-run rarity mix
-- matches the crate weights, and pity still forces its rarity. Run `npx rbxtsc` first.
local H = require("./_server_harness")
local R = H.load("Server/AstralForge/Modules/CrateRng")

-- determinism
local a, b = R.Stream.new(12345), R.Stream.new(12345)
for _ = 1, 1000 do assert(a:NextWord() == b:NextWord(), "same seed, same words") end
assert(a.Draws == 1000, "draws counted")
assert(R.Stream.new(1):NextWord() ~= R.Stream.new(2):NextWord(), "different seeds differ")
-- known first words pin the algorithm so a later edit can't silently change every replay
local s = R.Stream.new(0)
local first = s:NextWord()
assert(first >= 0 and first < 2^32 and first == math.floor(first), "a 32-bit word")

-- ranges
local st = R.Stream.new(99)
local buckets = { 0, 0, 0, 0, 0, 0 }
local N = 60000
for _ = 1, N do
	local x = st:NextNumber()
	assert(x >= 0 and x < 1, "unit range")
	local y = st:NextNumber(5, 7)
	assert(y >= 5 and y < 7, "bounded range")
	local i = st:NextInteger(1, 6)
	assert(i >= 1 and i <= 6 and i == math.floor(i), "integer range")
	buckets[i] += 1
end
for i = 1, 6 do
	assert(math.abs(buckets[i] / N - 1 / 6) < 0.01, "die face " .. i .. " is fair: " .. buckets[i])
end
assert(R.Stream.new(3):NextInteger(4, 4) == 4, "single value range")

-- seeds
local seen = {}
for user = 1, 50 do
	for counter = 1, 20 do
		local seed = R.SeedFor(777, user, "ForgeCrate", counter)
		assert(not seen[seed], "no seed collisions in a small grid")
		seen[seed] = true
	end
end
assert(R.SeedFor(777, 1, "A", 1) ~= R.SeedFor(778, 1, "A", 1), "the secret changes seeds")
assert(R.SeedFor(777, 1, "A", 1) ~= R.SeedFor(777, 1, "B", 1), "the crate changes seeds")
assert(R.SeedFor(777, 1, "A", 1) == R.SeedFor(777, 1, "A", 1), "seeds are stable")

-- rolls
local rarities = { Common = { Rank = 1 }, Rare = { Rank = 2 }, Epic = { Rank = 3 } }
local order = { "Common", "Rare", "Epic" }
local defs = { { Id = "c1", R = "Common" }, { Id = "c2", R = "Common" }, { Id = "r1", R = "Rare" }, { Id = "e1", R = "Epic" } }
local crate = { PityRarity = "Epic", PityAfter = 50, Weights = { Common = 70, Rare = 25, Epic = 5 } }
local function rarityOf(d) return d.R end
local one = R.Roll(4242, crate, 0, rarities, defs, rarityOf, order, 1e-6)
local two = R.Roll(4242, crate, 0, rarities, defs, rarityOf, order, 1e-6)
assert(one.Seed == 4242 and one.Draws == 2, "a roll records its seed and draws")
assert(one.Rarity == two.Rarity and one.Definition == two.Definition, "a seeded roll replays exactly")

local counts = { Common = 0, Rare = 0, Epic = 0 }
local M = 40000
for i = 1, M do
	local rec = R.Roll(R.SeedFor(1, 1, "odds", i), crate, 0, rarities, defs, rarityOf, order, 1e-6)
	counts[rec.Rarity] += 1
	assert(rec.Definition ~= nil and rec.Definition.R == rec.Rarity, "the drop matches its rarity")
end
assert(math.abs(counts.Common / M - 0.70) < 0.01, "common share " .. counts.Common)
assert(math.abs(counts.Rare / M - 0.25) < 0.01, "rare share " .. counts.Rare)
assert(math.abs(counts.Epic / M - 0.05) < 0.006, "epic share " .. counts.Epic)

for i = 1, 200 do
	local rec = R.Roll(i, crate, 49, rarities, defs, rarityOf, order, 1e-6)
	assert(rec.Rarity == "Epic" and rec.PityHit, "pity forces the pity rarity")
end

print("verify_crate_rng: ok")
