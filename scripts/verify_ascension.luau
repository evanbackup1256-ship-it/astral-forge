--!strict
-- Ascension: infinite final layer above Domain, paid in Aether, spent on six uncapped sigils.
local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local A = require("../src/Shared/AstralForge/Shared/AscensionMath")

-- requirement rises forever and never repeats
local last = -1
for rank = 0, 400 do
	local required = A.requiredDomainRank(rank)
	assert(required > last, "each ascension needs a higher Domain rank")
	last = required
end
assert(A.requiredDomainRank(0) == 25, "the first ascension needs Domain rank 25")

-- sanitize: junk in, clean state out
local clean = A.sanitize({ Rank = -3, Aether = "nan", Sigils = { Sol = 2.7, Bogus = 9 } }, OmegaMath)
assert(clean.Rank == 0 and clean.Sigils.Sol == 2 and clean.Sigils.Bogus == nil, "sanitize clamps and drops unknown sigils")
assert(A.sanitize(nil, OmegaMath).Rank == 0, "missing state is a fresh one")

-- gain: none below the requirement, more the further past it
local fresh = A.sanitize({}, OmegaMath)
assert(A.aetherGain(fresh, 24, OmegaMath) == nil, "below the requirement there is no gain")
local atReq = A.aetherGain(fresh, 25, OmegaMath)
local past = A.aetherGain(fresh, 60, OmegaMath)
assert(atReq ~= nil and OmegaMath.Gte(atReq, 1), "meeting the requirement pays at least 1 Aether")
assert(past ~= nil and OmegaMath.Gt(past, atReq), "going further past it pays more")

-- ascend: rank +1, Aether added, sigils kept
local ascended, gained = A.ascend(fresh, 30, 100, OmegaMath)
assert(ascended ~= nil and ascended.Rank == 1 and OmegaMath.Gt(ascended.Aether, 0), "ascending adds a rank and Aether")
assert(OmegaMath.Lte(gained, ascended.TotalAether), "lifetime Aether records the gain")
local refused, why = A.ascend(fresh, 3, 100, OmegaMath)
assert(refused == nil and string.find(why, "Domain rank 25", 1, true), "refusal names the rank needed")

-- milestones survive the reset: best Domain rank and the rebirths given up are kept
local kept = A.ascend(fresh, 40, 100, OmegaMath, 12)
assert(kept ~= nil and kept.BestDomainRank == 40 and kept.RebirthsSpent == 12, "ascending records the Domain rank and rebirths it reset")
local again = A.buy(A.sanitize({ Aether = 50, BestDomainRank = 40, RebirthsSpent = 12 }, OmegaMath), "Sol", OmegaMath)
assert(again ~= nil and again.BestDomainRank == 40 and again.RebirthsSpent == 12, "buying a sigil keeps the milestone record")
assert(A.sanitize({ Rank = 2 }, OmegaMath).BestDomainRank >= A.requiredDomainRank(1), "older saves that ascended are backfilled")
do
	local fs = require("@lune/fs")
	local gate = fs.readFile("src/Server/AstralForge/Modules/EconomyMath.luau")
	assert(string.find(gate, "ascension.BestDomainRank", 1, true) and string.find(gate, "ascension.RebirthsSpent", 1, true),
		"milestone progress counts what an ascension reset, or Ascension would lock itself")
end

-- buying: costs rise, refuses when short, never caps
local rich = A.sanitize({ Aether = 100 }, OmegaMath)
local previousCost = 0
for level = 0, 60 do
	local cost = A.sigilCost("Sol", level, OmegaMath)
	assert(OmegaMath.Gt(cost, previousCost), "every level costs more than the last")
	previousCost = cost
end
local bought = A.buy(rich, "Sol", OmegaMath)
assert(bought ~= nil and bought.Sigils.Sol == 1 and OmegaMath.Lt(bought.Aether, rich.Aether), "buying spends Aether")
local poor, need = A.buy(A.sanitize({}, OmegaMath), "Sol", OmegaMath)
assert(poor == nil and string.find(need, "more Aether", 1, true), "buying with too little Aether is refused")
assert(A.buy(rich, "Nope", OmegaMath) == nil, "unknown sigils are refused")
local deep = A.sanitize({ Sigils = { Sol = 5000 } }, OmegaMath)
assert(OmegaMath.Gt(A.sigilMultiplier(deep, "Sol", OmegaMath), 1e300), "very high levels keep working past double range")

-- harmony: the lowest level of all six lifts every started sigil
local lopsided = A.sanitize({ Sigils = { Sol = 10 } }, OmegaMath)
assert(A.harmony(lopsided) == 0 and A.effectiveLevel(lopsided, "Sol") == 10, "one sigil alone gets no harmony")
local even = A.sanitize({ Sigils = { Sol = 4, Bastion = 4, Strike = 4, Ember = 4, Crown = 4, Lodestar = 4 } }, OmegaMath)
assert(A.harmony(even) == 4 and A.effectiveLevel(even, "Sol") == 8, "six at level 4 each act at level 8")
assert(OmegaMath.Gt(A.effect(even, "Production", OmegaMath), A.effect(A.sanitize({ Sigils = { Sol = 4 } }, OmegaMath), "Production", OmegaMath)),
	"balancing all six beats one alone at the same level")

-- rank multiplies production, uncapped
local ranked = A.sanitize({ Rank = 10 }, OmegaMath)
assert(OmegaMath.Gt(A.effect(ranked, "Production", OmegaMath), 30), "ten ascensions multiply production over 30x")
assert(A.effect(fresh, "Production", OmegaMath) == 1, "no ascension, no change")

-- wiring: every server file that calls AscensionMath has OmegaMath bound (a missing local broke GetState)
do
	local fs = require("@lune/fs")
	for _, path in { "src/Server/AstralForge/Services/ServerServices.luau", "src/Server/AstralForge/Services/DataService.luau", "src/Server/AstralForge/Modules/EconomyMath.luau" } do
		local src = fs.readFile(path)
		if string.find(src, "AscensionMath.", 1, true) then
			assert(string.find(src, "local OmegaMath = require(", 1, true), path .. " uses AscensionMath without binding OmegaMath")
		end
	end
end
print("[TEST] ascension: rising requirement, Aether gain, ascend, uncapped sigils, harmony passed")
