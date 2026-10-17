-- Forge journal: chapters derived from saved lifetime stats on the Overview page.
local fs = require("@lune/fs")

local JourneyMath = require("../src/Client/AstralForge/CoreKit")("journeyMath")

local empty = JourneyMath.Build({})
assert(empty.Count == 0, "fresh save has no chapters")
assert(empty.Total == #JourneyMath.CHAPTERS, "total matches chapter list")
assert(empty.Next ~= nil, "fresh save has a next chapter")

local mid = JourneyMath.Build({
	Rebirths = 3,
	Domain = { Rank = 0 },
	Stats = { MachinesBought = 12, Taps = 820, OrdersCompleted = 4, PlayTime = 4 * 3600, CratesOpened = "bad" },
})
local doneIds = {}
for _, entry in mid.Done do
	doneIds[entry.Id] = true
	assert(entry.Progress == 1, "done entries are full")
end
assert(doneIds.spark and doneIds.hands and doneIds.reborn, "earned chapters written")
assert(not doneIds.orders and not doneIds.crates, "unearned chapters open")
assert(mid.Count == 3, "count matches done list")
local nextEntry = mid.Next :: any
assert(nextEntry.Id == "shift", "closest unfinished chapter is next")
assert(nextEntry.Have == 4 and nextEntry.Target == 5, "hours are scaled for display")

local full = JourneyMath.Build({
	Rebirths = 99,
	Domain = { Rank = 3 },
	Stats = {
		MachinesBought = 1e6, Taps = 1e6, OrdersCompleted = 1e6, CratesOpened = 1e6,
		ItemsSalvaged = 1e6, PlayTime = 1e9, WardenDefeats = 1e6,
	},
})
assert(full.Count == full.Total and full.Next == nil, "everything written")

local core = fs.readFile("src/Client/AstralForge/pages/PagesCore.luau")
assert(string.find(core, 'id = "journal"', 1, true), "Overview has a journal section")
assert(string.find(core, "JourneyMath.Build(state)", 1, true), "Overview builds the journal")

print("verify_journey OK")
