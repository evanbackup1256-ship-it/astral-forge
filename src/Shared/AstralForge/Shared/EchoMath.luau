--!strict
-- Forge Echoes. Playing leaves a trace: collecting, overcharging, building and exploring each
-- fill their own track and together fill the charge. A full charge strikes three echoes shaped
-- by whatever you did most; keep one. Echoes have a trait (what they do), a tier (Faint, Clear,
-- Vivid, Perfect: how strongly) and, from Clear up, imprints (small extra bonuses). Up to four go
-- in your chord; a chord of one affinity is in Harmony, a matched pair is in Unison, four
-- different affinities make a Spectrum. Tune echoes with Stardust, fuse two of the same trait and
-- tier into the next tier, lock the ones you love, dismantle the rest into Resonance (better
-- strikes, rerolls). The journal remembers every trait and tier you have kept; a full row of a
-- trait is a permanent bonus. Pure: the server's rules and the screen's previews agree.

local EchoMath = {}

EchoMath.TRACKS = { "Collect", "Surge", "Build", "Explore" }
EchoMath.TRACK_AFFINITY = { Collect = "Industry", Surge = "Impulse", Build = "Craft", Explore = "Void" }
EchoMath.CHARGE_TARGET = 100
EchoMath.INVENTORY_LIMIT = 24
EchoMath.SLOT_CAPTURES = { 0, 3, 8, 20 }
EchoMath.MAX_LEVEL = 60
EchoMath.TUNE_BASE = 14
EchoMath.TUNE_SCALE = 1.16
EchoMath.REROLL_RESONANCE = 25
EchoMath.HARMONY = 0.15
EchoMath.UNISON = 0.10
EchoMath.SPECTRUM = 0.20
EchoMath.JOURNAL_BONUS = 0.03
EchoMath.IMPRINT_SHARE = 0.3

export type Trait = { Id: string, Name: string, Affinity: string, Effects: { { Kind: string, Base: number, PerLevel: number } }, Line: string }

-- two traits per affinity, each its own thing
EchoMath.TRAITS = table.freeze({
	{ Id = "FurnaceMemory", Name = "Furnace Memory", Affinity = "Industry", Line = "The forge remembers running hot.", Effects = { { Kind = "Production", Base = 0.045, PerLevel = 0.009 } } },
	{ Id = "DeepReservoir", Name = "Deep Reservoir", Affinity = "Industry", Line = "A vault that holds more than it looks.", Effects = { { Kind = "Capacity", Base = 0.08, PerLevel = 0.014 } } },
	{ Id = "StrikeGhost", Name = "Strike Ghost", Affinity = "Impulse", Line = "A second hammer lands with yours.", Effects = { { Kind = "Tap", Base = 0.07, PerLevel = 0.012 } } },
	{ Id = "LuckyAfterimage", Name = "Lucky Afterimage", Affinity = "Impulse", Line = "Some strikes split clean.", Effects = { { Kind = "Critical", Base = 0.009, PerLevel = 0.0015 } } },
	{ Id = "ClockworkEcho", Name = "Clockwork Echo", Affinity = "Craft", Line = "Machines bank on their own.", Effects = { { Kind = "Automation", Base = 0.018, PerLevel = 0.0025 } } },
	{ Id = "LatticeRecall", Name = "Lattice Recall", Affinity = "Craft", Line = "Every build makes room for the next.", Effects = { { Kind = "Capacity", Base = 0.04, PerLevel = 0.007 }, { Kind = "Production", Base = 0.02, PerLevel = 0.004 } } },
	{ Id = "NightShift", Name = "Night Shift", Affinity = "Void", Line = "Work carries on while you're away.", Effects = { { Kind = "Offline", Base = 0.035, PerLevel = 0.006 } } },
	{ Id = "VoidPulse", Name = "Void Pulse", Affinity = "Void", Line = "Strikes hit harder from nowhere.", Effects = { { Kind = "Tap", Base = 0.035, PerLevel = 0.006 }, { Kind = "Critical", Base = 0.005, PerLevel = 0.0008 } } },
})
local traitById: { [string]: any } = {}
for _, trait in EchoMath.TRAITS do
	traitById[trait.Id] = trait
end
function EchoMath.trait(id: string?): any
	return id and traitById[id] or nil
end
-- old ids that changed: Surge Mnemonic became Void Pulse
EchoMath.RENAMED = { SurgeMnemonic = "VoidPulse" }

EchoMath.KINDS = { "Production", "Capacity", "Tap", "Critical", "Automation", "Offline" }
local KIND_BASE = { Production = 0.045, Capacity = 0.08, Tap = 0.07, Critical = 0.009, Automation = 0.018, Offline = 0.035 }
local KIND_PER_LEVEL = { Production = 0.009, Capacity = 0.014, Tap = 0.012, Critical = 0.0015, Automation = 0.0025, Offline = 0.006 }

EchoMath.TIERS = { "Faint", "Clear", "Vivid", "Perfect" }
EchoMath.TIER_POWER = { Faint = 0.85, Clear = 1, Vivid = 1.2, Perfect = 1.5 }
EchoMath.TIER_IMPRINTS = { Faint = 0, Clear = 1, Vivid = 1, Perfect = 2 }
local TIER_INDEX = { Faint = 1, Clear = 2, Vivid = 3, Perfect = 4 }
function EchoMath.tierIndex(tier: string?): number
	return TIER_INDEX[tier or ""] or 1
end
function EchoMath.nextTier(tier: string?): string?
	return EchoMath.TIERS[EchoMath.tierIndex(tier) + 1]
end

------------------------------------------------------------------------------------------------
-- the bag
------------------------------------------------------------------------------------------------
local function int(v: any, min: number?): number
	return math.max(min or 0, math.floor(tonumber(v) or 0))
end
function EchoMath.blank()
	return {
		Version = 2,
		Charge = 0,
		Tracks = { Collect = 0, Surge = 0, Build = 0, Explore = 0 },
		Resonance = 0,
		Captures = 0,
		NextId = 1,
		Draft = { Choices = {}, Rerolled = false },
		Inventory = {},
		Chord = { "", "", "", "" },
		Journal = {},
	}
end

-- an old echo (trait, level, strength 0.75..1.5) becomes a new one
local function migrateEcho(old)
	local traitId = EchoMath.RENAMED[old.TraitId] or old.TraitId
	if traitById[traitId] == nil then
		return nil
	end
	local strength = tonumber(old.Strength) or 1
	local tier = if strength >= 1.25 then "Vivid" elseif strength >= 1.08 then "Clear" else "Faint"
	return { Trait = traitId, Tier = tier, Level = math.clamp(int(old.Level, 1), 1, EchoMath.MAX_LEVEL), Imprints = {}, Locked = false, At = int(old.CapturedAt) }
end

function EchoMath.ensure(bag: any)
	if type(bag) ~= "table" then
		return EchoMath.blank()
	end
	if bag.Version ~= 2 then
		-- the old echoes: keep every echo, the chord and the resonance; drop the waiting draft
		local fresh = EchoMath.blank()
		fresh.Resonance = int(bag.Resonance)
		fresh.Captures = int(bag.Captures)
		fresh.Charge = math.clamp(tonumber(bag.Charge) or 0, 0, EchoMath.CHARGE_TARGET)
		local nextId = 1
		local remap = {}
		for uid, old in (type(bag.Inventory) == "table" and bag.Inventory or {}) do
			local echo = migrateEcho(old)
			if echo then
				local id = "E" .. nextId
				nextId += 1
				fresh.Inventory[id] = echo
				remap[uid] = id
				fresh.Journal[echo.Trait] = math.max(fresh.Journal[echo.Trait] or 0, EchoMath.tierIndex(echo.Tier))
			end
		end
		fresh.NextId = nextId
		if type(bag.Equipped) == "table" then
			for slot = 1, 3 do
				local uid = bag.Equipped[tostring(slot)]
				if uid and remap[uid] then
					fresh.Chord[slot] = remap[uid]
				end
			end
		end
		return fresh
	end
	bag.Charge = math.clamp(tonumber(bag.Charge) or 0, 0, EchoMath.CHARGE_TARGET)
	bag.Tracks = type(bag.Tracks) == "table" and bag.Tracks or { Collect = 0, Surge = 0, Build = 0, Explore = 0 }
	for _, track in EchoMath.TRACKS do
		bag.Tracks[track] = math.max(0, tonumber(bag.Tracks[track]) or 0)
	end
	bag.Resonance = int(bag.Resonance)
	bag.Captures = int(bag.Captures)
	bag.NextId = int(bag.NextId, 1)
	bag.Draft = type(bag.Draft) == "table" and bag.Draft or { Choices = {}, Rerolled = false }
	bag.Draft.Choices = type(bag.Draft.Choices) == "table" and bag.Draft.Choices or {}
	bag.Inventory = type(bag.Inventory) == "table" and bag.Inventory or {}
	for uid, echo in bag.Inventory do
		if type(echo) ~= "table" or traitById[echo.Trait] == nil or TIER_INDEX[echo.Tier] == nil then
			bag.Inventory[uid] = nil
		else
			echo.Level = math.clamp(int(echo.Level, 1), 1, EchoMath.MAX_LEVEL)
			echo.Imprints = type(echo.Imprints) == "table" and echo.Imprints or {}
			echo.Locked = echo.Locked == true
		end
	end
	bag.Chord = type(bag.Chord) == "table" and bag.Chord or { "", "", "", "" }
	for slot = 1, 4 do
		local uid = bag.Chord[slot]
		bag.Chord[slot] = if type(uid) == "string" and bag.Inventory[uid] then uid else ""
	end
	bag.Journal = type(bag.Journal) == "table" and bag.Journal or {}
	return bag
end

function EchoMath.count(inventory: any): number
	local n = 0
	for _ in (type(inventory) == "table" and inventory or {}) do
		n += 1
	end
	return n
end
function EchoMath.slots(captures: number): number
	local slots = 1
	for index, need in EchoMath.SLOT_CAPTURES do
		if captures >= need then
			slots = index
		end
	end
	return slots
end

------------------------------------------------------------------------------------------------
-- recording and striking
------------------------------------------------------------------------------------------------
-- returns how much charge it added; `boost` is the Domain lattice's faster-echo bonus
function EchoMath.record(bag, track: string, weight: number, boost: number?): number
	if EchoMath.TRACK_AFFINITY[track] == nil or #bag.Draft.Choices > 0 then
		return 0
	end
	local w = math.clamp(tonumber(weight) or 0, 0, 14) * (1 + math.max(0, boost or 0))
	if w <= 0 then
		return 0
	end
	bag.Tracks[track] = math.min(1e9, bag.Tracks[track] + w)
	local before = bag.Charge
	bag.Charge = math.min(EchoMath.CHARGE_TARGET, bag.Charge + w)
	return bag.Charge - before
end

function EchoMath.dominant(tracks: any): (string, string)
	local best, bestValue = "Collect", -1
	for _, track in EchoMath.TRACKS do
		local v = tonumber(tracks and tracks[track]) or 0
		if v > bestValue then
			best, bestValue = track, v
		end
	end
	return best, EchoMath.TRACK_AFFINITY[best]
end

-- tier odds: resonance nudges them up (capped)
function EchoMath.tierOdds(resonance: number)
	local lift = math.min(0.12, math.sqrt(math.max(0, resonance)) * 0.004)
	return { Faint = math.max(0.2, 0.5 - lift * 2), Clear = 0.32, Vivid = 0.14 + lift, Perfect = 0.04 + lift }
end
function EchoMath.rollTier(resonance: number, roll: number): string
	local odds = EchoMath.tierOdds(resonance)
	local total = odds.Faint + odds.Clear + odds.Vivid + odds.Perfect
	local at = roll * total
	for _, tier in EchoMath.TIERS do
		at -= odds[tier]
		if at < 0 then
			return tier
		end
	end
	return "Faint"
end

-- imprints: small extra effects of a different kind than the trait's own
function EchoMath.rollImprints(trait, tier: string, rand: () -> number)
	local imprints = {}
	local own = {}
	for _, e in trait.Effects do
		own[e.Kind] = true
	end
	local options = {}
	for _, kind in EchoMath.KINDS do
		if not own[kind] then
			table.insert(options, kind)
		end
	end
	for _ = 1, EchoMath.TIER_IMPRINTS[tier] do
		if #options == 0 then
			break
		end
		local pick = math.clamp(math.floor(rand() * #options) + 1, 1, #options)
		table.insert(imprints, options[pick])
		table.remove(options, pick)
	end
	return imprints
end

-- three echoes for a full charge: the first always from your dominant affinity
function EchoMath.strike(bag, rand: () -> number)
	local _, affinity = EchoMath.dominant(bag.Tracks)
	local preferred, pool = {}, {}
	for _, trait in EchoMath.TRAITS do
		table.insert(pool, trait)
		if trait.Affinity == affinity then
			table.insert(preferred, trait)
		end
	end
	local picked, used = {}, {}
	local first = preferred[math.clamp(math.floor(rand() * #preferred) + 1, 1, #preferred)]
	table.insert(picked, first)
	used[first.Id] = true
	while #picked < 3 do
		local trait = pool[math.clamp(math.floor(rand() * #pool) + 1, 1, #pool)]
		if not used[trait.Id] then
			used[trait.Id] = true
			table.insert(picked, trait)
		end
	end
	local choices = {}
	for _, trait in picked do
		local tier = EchoMath.rollTier(bag.Resonance, rand())
		table.insert(choices, { Trait = trait.Id, Tier = tier, Level = 1, Imprints = EchoMath.rollImprints(trait, tier, rand), Locked = false })
	end
	return choices
end

------------------------------------------------------------------------------------------------
-- what an echo does
------------------------------------------------------------------------------------------------
function EchoMath.effects(echo): { [string]: number }
	local out = {}
	local trait = traitById[echo.Trait]
	if trait == nil then
		return out
	end
	local level = math.clamp(int(echo.Level, 1), 1, EchoMath.MAX_LEVEL)
	local power = EchoMath.TIER_POWER[echo.Tier] or 1
	for _, e in trait.Effects do
		out[e.Kind] = (out[e.Kind] or 0) + (e.Base + e.PerLevel * (level - 1)) * power
	end
	for _, kind in (echo.Imprints or {}) do
		if KIND_BASE[kind] then
			out[kind] = (out[kind] or 0) + (KIND_BASE[kind] + KIND_PER_LEVEL[kind] * (level - 1)) * EchoMath.IMPRINT_SHARE
		end
	end
	return out
end

-- the chord's bonuses: Harmony (2+ echoes, one affinity), Unison (a pair of one trait), Spectrum (4 affinities)
function EchoMath.chordBonuses(echoes: { any })
	local affinities, traits = {}, {}
	local n = 0
	for _, echo in echoes do
		local trait = traitById[echo.Trait]
		if trait then
			n += 1
			affinities[trait.Affinity] = (affinities[trait.Affinity] or 0) + 1
			traits[echo.Trait] = (traits[echo.Trait] or 0) + 1
		end
	end
	local affinityCount = 0
	for _ in affinities do
		affinityCount += 1
	end
	local unison = false
	for _, c in traits do
		if c >= 2 then
			unison = true
		end
	end
	return {
		Harmony = n >= 2 and affinityCount == 1,
		Unison = unison,
		Spectrum = n >= 4 and affinityCount == 4,
	}
end
function EchoMath.chordMultiplier(bonuses): number
	return 1 + (if bonuses.Harmony then EchoMath.HARMONY else 0) + (if bonuses.Unison then EchoMath.UNISON else 0) + (if bonuses.Spectrum then EchoMath.SPECTRUM else 0)
end

-- a journal row is complete when every tier of that trait has been kept
function EchoMath.journalBonus(journal: any, kind: string): number
	local total = 0
	for _, trait in EchoMath.TRAITS do
		if (tonumber(journal and journal[trait.Id]) or 0) >= #EchoMath.TIERS then
			for _, e in trait.Effects do
				if e.Kind == kind then
					total += EchoMath.JOURNAL_BONUS
				end
			end
		end
	end
	return total
end

-- the whole bonus of one kind: the chord's echoes, its bonuses, and the journal
function EchoMath.total(bag: any, kind: string): number
	if type(bag) ~= "table" or bag.Version ~= 2 then
		return 0
	end
	local slots = EchoMath.slots(int(bag.Captures))
	local chord = {}
	for slot = 1, slots do
		local uid = bag.Chord and bag.Chord[slot]
		local echo = uid and uid ~= "" and bag.Inventory and bag.Inventory[uid]
		if echo then
			table.insert(chord, echo)
		end
	end
	local sum = 0
	for _, echo in chord do
		sum += EchoMath.effects(echo)[kind] or 0
	end
	return sum * EchoMath.chordMultiplier(EchoMath.chordBonuses(chord)) + EchoMath.journalBonus(bag.Journal, kind)
end

function EchoMath.tuneCost(level: number): number
	return math.floor(EchoMath.TUNE_BASE * EchoMath.TUNE_SCALE ^ (math.max(1, level) - 1) + 0.5)
end
function EchoMath.dismantleResonance(echo): number
	return 5 + int(echo.Level, 1) * 4 + (EchoMath.tierIndex(echo.Tier) - 1) * 10
end

return table.freeze(EchoMath)
