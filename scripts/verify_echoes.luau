--!strict
-- Forge Echoes (Shared/EchoMath): migration, recording, strikes, tiers, imprints, the chord's
-- bonuses, the journal, totals, and the server/client wiring.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local E = luau.load(fs.readFile("src/Shared/AstralForge/Shared/EchoMath.luau"), { chunkName = "EchoMath" })() :: any

local function near(a, b, label)
	assert(math.abs(a - b) < 1e-9, `{label}: {a} vs {b}`)
end
local seq = 0
local function rand()
	seq = (seq * 9301 + 49297) % 233280
	return seq / 233280
end

-- traits: two per affinity, every kind covered
local perAffinity = {}
for _, trait in E.TRAITS do
	perAffinity[trait.Affinity] = (perAffinity[trait.Affinity] or 0) + 1
end
for _, affinity in { "Industry", "Impulse", "Craft", "Void" } do
	assert(perAffinity[affinity] == 2, affinity .. " has two traits")
end

-- an old save keeps its echoes, its chord and its resonance
local old = {
	Charge = 40, Resonance = 33, Captures = 9,
	Inventory = {
		E7 = { TraitId = "FurnaceMemory", Level = 12, Strength = 1.3 },
		E8 = { TraitId = "SurgeMnemonic", Level = 3, Strength = 1.0 },
		Bad = { TraitId = "Gone", Level = 1 },
	},
	Equipped = { ["1"] = "E7", ["2"] = "E8", ["3"] = "" },
	Draft = { Id = "D1", Choices = { { TraitId = "StrikeGhost" } } },
}
local bag = E.ensure(old)
assert(bag.Version == 2 and bag.Resonance == 33 and bag.Captures == 9 and bag.Charge == 40, "scalars kept")
assert(E.count(bag.Inventory) == 2, "real echoes kept, unknown dropped")
local kept = bag.Inventory[bag.Chord[1]]
assert(kept.Trait == "FurnaceMemory" and kept.Tier == "Vivid" and kept.Level == 12, "strength becomes a tier")
assert(bag.Inventory[bag.Chord[2]].Trait == "VoidPulse", "renamed trait follows")
assert(#bag.Draft.Choices == 0, "the old draft is dropped")
assert(bag.Journal.FurnaceMemory == 3, "the journal remembers what was kept")

-- recording: four tracks, capped weight, the lattice speeds it up, a waiting draft pauses it
local fresh = E.ensure(nil)
assert(E.record(fresh, "Collect", 10) == 10 and fresh.Tracks.Collect == 10, "collect records")
assert(E.record(fresh, "Surge", 100) == 14, "weight is capped")
near(E.record(fresh, "Build", 10, 0.2), 12, "Bellows speeds the charge")
assert(E.record(fresh, "Nope", 5) == 0, "unknown tracks ignored")
fresh.Charge = 99
assert(E.record(fresh, "Explore", 14) == 1 and fresh.Charge == E.CHARGE_TARGET, "charge caps at full")

-- strikes: three different traits, the first from your strongest track
fresh.Tracks = { Collect = 1, Surge = 50, Build = 2, Explore = 0 }
for _ = 1, 30 do
	local choices = E.strike(fresh, rand)
	assert(#choices == 3, "three echoes")
	assert(E.trait(choices[1].Trait).Affinity == "Impulse", "the first follows what you did most")
	local seen = {}
	for _, c in choices do
		assert(not seen[c.Trait], "no repeats in a strike")
		seen[c.Trait] = true
		assert(#c.Imprints == E.TIER_IMPRINTS[c.Tier], "imprints follow the tier")
	end
end
-- resonance improves the odds
assert(E.tierOdds(10000).Perfect > E.tierOdds(0).Perfect, "resonance lifts the odds")
assert(E.rollTier(0, 0) == "Faint" and E.rollTier(0, 0.999) == "Perfect", "the roll covers every tier")

-- effects, the chord and the journal
local a = { Trait = "FurnaceMemory", Tier = "Clear", Level = 1, Imprints = {} }
near(E.effects(a).Production, 0.045, "a clear level 1 echo")
local perfect = { Trait = "FurnaceMemory", Tier = "Perfect", Level = 11, Imprints = { "Offline" } }
near(E.effects(perfect).Production, (0.045 + 0.009 * 10) * 1.5, "tier and level")
near(E.effects(perfect).Offline, (0.035 + 0.006 * 10) * 0.3, "imprints add a little")
local harmony = E.chordBonuses({ { Trait = "FurnaceMemory" }, { Trait = "DeepReservoir" } })
assert(harmony.Harmony and not harmony.Unison and not harmony.Spectrum, "one affinity is harmony")
local unison = E.chordBonuses({ { Trait = "StrikeGhost" }, { Trait = "StrikeGhost" } })
assert(unison.Unison and unison.Harmony, "a matched pair is unison (and harmony)")
local spectrum = E.chordBonuses({ { Trait = "FurnaceMemory" }, { Trait = "StrikeGhost" }, { Trait = "ClockworkEcho" }, { Trait = "NightShift" } })
assert(spectrum.Spectrum and not spectrum.Harmony, "four affinities are a spectrum")
near(E.chordMultiplier(spectrum), 1.2, "spectrum bonus")
local journal = { FurnaceMemory = 4, LatticeRecall = 4 }
near(E.journalBonus(journal, "Production"), 0.06, "full journal rows are permanent")
near(E.journalBonus(journal, "Capacity"), 0.03, "per kind")

local chordBag = E.ensure(nil)
chordBag.Captures = 0
chordBag.Inventory = { E1 = { Trait = "FurnaceMemory", Tier = "Clear", Level = 1, Imprints = {}, Locked = false }, E2 = { Trait = "DeepReservoir", Tier = "Clear", Level = 1, Imprints = {}, Locked = false } }
chordBag.Chord = { "E1", "E2", "", "" }
near(E.total(chordBag, "Production"), 0.045, "only open slots count")
chordBag.Captures = 3
near(E.total(chordBag, "Production"), 0.045 * 1.15, "two slots, harmony")
assert(E.slots(0) == 1 and E.slots(3) == 2 and E.slots(8) == 3 and E.slots(20) == 4, "slots open with captures")
assert(E.total({ Charge = 1 }, "Production") == 0, "an unmigrated bag adds nothing")
assert(E.tuneCost(1) == 14 and E.tuneCost(10) > E.tuneCost(9), "tuning costs climb")
assert(E.nextTier("Vivid") == "Perfect" and E.nextTier("Perfect") == nil, "fusing climbs to Perfect")
assert(E.dismantleResonance({ Level = 3, Tier = "Vivid" }) == 5 + 12 + 20, "dismantling pays by level and tier")

-- wiring
local service = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau")
for _, op in { "Strike", "Reroll", "Keep", "Slot", "Tune", "Fuse", "Lock", "Dismantle" } do
	assert(service:find(`op == "{op}"`, 1, true), "the service handles " .. op)
end
assert(service:find('Economy.DomainTreeBonus(profile, "EchoCharge")', 1, true), "the Bellows bonus finally applies")
local economy = fs.readFile("src/Server/AstralForge/Modules/EconomyMath.luau")
assert(economy:find("return EchoMath.total(profile.ForgeEchoes, effectKind)", 1, true), "the economy reads the chord")
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(server:find("function GameService:_echoAct", 1, true) and not server:find("_captureEcho", 1, true), "one echo action")
assert(not fs.isFile("src/Server/AstralForge/Modules/ForgeEchoMath.luau"), "the old math is gone")
print("[TEST] echoes: migration, recording, strikes, tiers, imprints, chord, journal and wiring passed")
