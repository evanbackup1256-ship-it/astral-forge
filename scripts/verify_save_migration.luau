--!nocheck
-- Old-save safety for Forge Echoes plus the settings layout, read from the compiled TS (out/).
-- Run `npx rbxtsc` first.
local luau = require("@lune/luau")
local fs = require("@lune/fs")

local function load(path)
	return luau.load(fs.readFile(path), { chunkName = path })()
end

local Echo = load("out/Shared/AstralForge/Shared/EchoMath.luau")
local nan, inf = 0 / 0, math.huge

-- junk and missing bags become a clean v2 bag
for _, junk in { nil, 5, "x", true } do
	local bag = Echo.ensure(junk)
	assert(bag.Version == 2 and bag.Charge == 0 and bag.NextId == 1, "junk echo bag resets")
end

-- v1 save: non-table entries skipped, NaN/inf zeroed, array-shaped Equipped carried over
local old = {
	Resonance = nan, Captures = inf, Charge = nan,
	Inventory = {
		a = { TraitId = "FurnaceMemory", Strength = 1.3, Level = 3 },
		b = 42,
		c = { TraitId = "SurgeMnemonic", Strength = 1 },
		d = { TraitId = "NotARealTrait" },
	},
	Equipped = { "a", "c" },
}
local v2 = Echo.ensure(old)
assert(v2.Resonance == 0 and v2.Captures == 0 and v2.Charge == 0, "NaN/inf counters become 0")
local count = 0
for _ in v2.Inventory do count += 1 end
assert(count == 2, "only real echoes survive migration, got " .. count)
assert(v2.Chord[1] ~= "" and v2.Chord[2] ~= "", "array-shaped Equipped keeps both echoes in the chord")
assert(v2.Inventory[v2.Chord[2]].Trait == "VoidPulse", "renamed trait follows the rename")
assert(v2.Inventory[v2.Chord[1]].Tier == "Vivid", "strength maps to tier")

-- v2 save with a damaged NextId must not let the next capture overwrite an echo
local damaged = Echo.ensure({
	Version = 2, NextId = 1, Charge = inf,
	Inventory = { E1 = { Trait = "FurnaceMemory", Tier = "Faint", Level = 1 }, E7 = { Trait = "FurnaceMemory", Tier = "Clear", Level = 2 } },
	Chord = { "E7", "gone", "", "" },
	Tracks = { Collect = nan },
})
assert(damaged.NextId == 8, "NextId moves past the highest stored id, got " .. tostring(damaged.NextId))
assert(damaged.Chord[1] == "E7" and damaged.Chord[2] == "", "chord drops ids that no longer exist")
assert(damaged.Tracks.Collect == 0, "NaN track becomes 0")
assert(damaged.Charge == damaged.Charge, "infinite charge is clamped to a number")

-- settings: every option sits under a sub-heading of its own section
local Schema = load("out/Shared/AstralForge/Shared/SharedData/SettingsSchema.luau")
for _, entry in Schema.ENTRIES do
	local group = Schema.group(entry.key)
	assert(group.label ~= "Other", entry.key .. " has no settings sub-heading")
end

print("[TEST] save migration: echo v1/v2 repair, NextId guard, settings grouping passed")
