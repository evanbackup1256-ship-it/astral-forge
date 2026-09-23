--!strict
-- Pure-module extract guards: ProfileBagMath + PageReadyMath.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local ProfileBagMath = require("../src/Server/AstralForge/Modules/ProfileBagMath")
local PageReadyMath = require("../src/Client/AstralForge/pageReadyMath")

------------------------------------------------------------------------
-- ProfileBagMath
------------------------------------------------------------------------
local profile: any = {}
assert(ProfileBagMath.EnsureStats(profile) == profile.Stats, "EnsureStats creates")
assert(type(profile.Stats) == "table", "Stats table")
assert(ProfileBagMath.BumpStat(profile, "Taps", 3) == 3, "bump 3")
assert(ProfileBagMath.BumpStat(profile, "Taps", nil) == 4, "bump default 1")
assert(ProfileBagMath.BumpStat({ Stats = nil }, "Joins", 2) == 2, "nil Stats rebuild")

local daily = ProfileBagMath.EnsureDaily({})
assert(daily.LastClaimDay == -1 and daily.Streak == 0, "daily defaults")
local dirtyDaily = ProfileBagMath.EnsureDaily({ Daily = { LastClaimDay = "2", Streak = -4 } })
assert(dirtyDaily.LastClaimDay == 2 and dirtyDaily.Streak == 0, "daily sanitize")

local quests = ProfileBagMath.EnsureQuests({})
assert(quests.Day == -1 and type(quests.Items) == "table", "quests defaults")
local keysOnlyQuests = ProfileBagMath.EnsureQuests({ Quests = { Day = 3 } })
assert(type(keysOnlyQuests.Items) == "table", "quests Items rebuild")

local timed = ProfileBagMath.EnsureTimedRewards({})
assert(timed.Day == -1 and type(timed.Claimed) == "table", "timed defaults")

local keys = ProfileBagMath.EnsureItemKeys({})
assert(type(keys) == "table", "keys bag")
local items = ProfileBagMath.EnsureItems({ Items = { Keys = { CommonCrate = 1 } } })
assert(type(items.Inventory) == "table" and items.Keys.CommonCrate == 1, "Items rebuild keeps Keys")
assert(items.Essence == 0 and type(items.Pity) == "table", "Essence/Pity present")
assert(type(items.Shop) == "table" and type(items.Shop.Stock) == "table", "Shop nest present")
local auto = ProfileBagMath.EnsureAutoSalvage({ Items = { Keys = {} } })
assert(auto.Enabled == false and type(auto.Rarities) == "table", "AutoSalvage rebuild")

local boost = ProfileBagMath.EnsureActiveBoost({})
assert(boost.Id == "" and boost.EndsAt == 0, "active boost defaults")
local inv = ProfileBagMath.EnsureBoostInventory({})
inv.Overdrive = 2
assert(ProfileBagMath.EnsureBoostInventory({ BoostInventory = inv }).Overdrive == 2, "boost inv passthrough")

local flags = ProfileBagMath.EnsureFlags({})
flags.UnlimitedMoney = true
assert(flags.UnlimitedMoney == true, "flags")

local domain = ProfileBagMath.EnsureDomain({})
assert(domain.Rank == 0 and type(domain.Nodes) == "table", "domain defaults")
local anomaly = ProfileBagMath.EnsureAnomaly({ Anomaly = { Fragments = 9 } })
assert(anomaly.Fragments == 9 and type(anomaly.Protocols) == "table", "anomaly Protocols rebuild")
local continuum = ProfileBagMath.EnsureContinuum({})
assert(continuum.Rank == 0, "continuum defaults")

------------------------------------------------------------------------
-- PageReadyMath
------------------------------------------------------------------------
assert(PageReadyMath.CountReadyQuests(nil) == 0, "nil quests")
assert(PageReadyMath.CountReadyQuests({}) == 0, "empty quests")
assert(
	PageReadyMath.CountReadyQuests({
		{ Claimed = false, Progress = 5, Target = 5 },
		{ Claimed = true, Progress = 9, Target = 5 },
		{ Claimed = false, Progress = nil, Target = 3 },
		"bad",
	}) == 1,
	"ready quests nil-safe"
)
assert(PageReadyMath.CountReadyLabOrders(nil) == 0, "nil lab")
assert(PageReadyMath.CountReadyLabOrders({ Orders = nil }) == 0, "nil orders")
assert(
	PageReadyMath.CountReadyLabOrders({
		Orders = {
			{ Claimed = false, Progress = 2, Target = 2 },
			{ Claimed = false, Progress = 1, Target = 4 },
		},
	}) == 1,
	"ready lab orders"
)
assert(PageReadyMath.ForgePathReady(nil, nil) == false, "nil forge state")
assert(PageReadyMath.ForgePathReady({ ForgePath = { XP = 10 } }, { ForgePath = { Steps = {} } }) == false, "empty steps")
assert(
	PageReadyMath.ForgePathReady({
		ForgePath = { XP = 100, ClaimedSteps = {} },
	}, {
		ForgePath = { Steps = { { Step = 1, XPCost = 50 }, { Step = 2, XPCost = 200 } } },
	}) == true,
	"step 1 ready"
)
assert(
	PageReadyMath.ForgePathReady({
		ForgePath = { XP = 10, ClaimedSteps = { 1 } },
	}, {
		ForgePath = { Steps = { { Step = 1, XPCost = 50 }, { Step = 2, XPCost = 200 } } },
	}) == false,
	"step 2 not ready"
)
assert(PageReadyMath.SameCrewSnapshot({}, {}) == true, "empty crew equal")
assert(PageReadyMath.SameCrewSnapshot(nil, nil) == true, "nil crew equal")
assert(
	PageReadyMath.SameCrewSnapshot({
		{ UserId = 1, Name = "a", DisplayName = "A", CurrentZone = 1, Rebirths = 0, Production = 1, LifetimeCash = 0, IsLocal = true, CurrentPage = "Home" },
	}, {
		{ UserId = 1, Name = "a", DisplayName = "A", CurrentZone = 1, Rebirths = 0, Production = 1, LifetimeCash = 0, IsLocal = true, CurrentPage = "Home" },
	}) == true,
	"crew match"
)
assert(
	PageReadyMath.SameCrewSnapshot({
		{ UserId = 1, Name = "a", DisplayName = "A", CurrentZone = 1, Rebirths = 0, Production = 1, LifetimeCash = 0, IsLocal = true, CurrentPage = "Home" },
	}, {
		{ UserId = 2, Name = "a", DisplayName = "A", CurrentZone = 1, Rebirths = 0, Production = 1, LifetimeCash = 0, IsLocal = true, CurrentPage = "Home" },
	}) == false,
	"crew mismatch"
)

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local adminSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
local routerSrc = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local bagSrc = fs.readFile("src/Server/AstralForge/Modules/ProfileBagMath.luau")
local readySrc = fs.readFile("src/Client/AstralForge/pageReadyMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(progressionSrc, "ProfileBagMath.EnsureStats", 1, true), "Progression must use ProfileBagMath.EnsureStats")
assert(string.find(progressionSrc, "ProfileBagMath.BumpStat", 1, true), "Progression must use ProfileBagMath.BumpStat")
assert(string.find(servicesSrc, "ProfileBagMath.EnsureActiveBoost", 1, true), "ServerServices must use EnsureActiveBoost")
assert(string.find(servicesSrc, "ProfileBagMath.EnsureItems", 1, true), "ServerServices market/crate must EnsureItems")
assert(string.find(servicesSrc, "ProfileBagMath.EnsureAutoSalvage", 1, true), "ServerServices crate must EnsureAutoSalvage")
assert(string.find(servicesSrc, "CommandMath.Ensure", 1, true), "ServerServices mastery must CommandMath.Ensure")
assert(string.find(adminSrc, "ProfileBagMath.EnsureItems", 1, true), "Admin must EnsureItems on relic/essence paths")
assert(string.find(adminSrc, "ProfileBagMath.BumpStat", 1, true), "Admin GrantRelic must BumpStat")
assert(string.find(adminSrc, "CommandMath.Ensure", 1, true), "Admin GrantSignals must CommandMath.Ensure")
assert(string.find(adminSrc, "WheelMath.Ensure", 1, true), "Admin GrantFreeSpins must WheelMath.Ensure")
assert(string.find(routerSrc, "PageReadyMath.CountReadyQuests", 1, true), "PageRouter must use PageReadyMath")
assert(string.find(routerSrc, "PageReadyMath.ForgePathReady", 1, true), "PageRouter must use ForgePathReady")
assert(string.find(routerSrc, "PageReadyMath.SameCrewSnapshot", 1, true), "PageRouter must use SameCrewSnapshot")

-- Evidence: Admin GrantItemEssence / GrantSignals used to raw-index partial bags.
assert(string.find(adminSrc, "profile.Items.Essence +=", 1, true) == nil, "GrantItemEssence must not raw-index Items.Essence")
assert(string.find(adminSrc, "profile.Command.Signals +=", 1, true) == nil or string.find(adminSrc, "CommandMath.Ensure", 1, true), "GrantSignals must Ensure before Signals+")
assert(string.find(adminSrc, "for crateId in profile.Items.Keys do profile.Items.Keys[crateId] = 0 end", 1, true) == nil, "DrainKeys must not raw-iterate Items.Keys")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { bagSrc, readySrc, progressionSrc, servicesSrc, adminSrc, routerSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(bagSrc, "GetService", 1, true), "ProfileBagMath must stay pure")
assert(not string.find(readySrc, "GetService", 1, true), "pageReadyMath must stay pure")

print("[INFO] [TEST] profile bag + page ready math extract guards passed")
