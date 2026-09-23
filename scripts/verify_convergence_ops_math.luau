--!strict
-- Pure-module extract guards: ConvergenceOpsMath (event profile Ensure/Read,
-- phase/multiplier, tier claim readiness). HARD: DV<=21, PlatformBadges=0,
-- no vendor/Packages.

local fs = require("@lune/fs")

local ConvergenceOpsMath = require("../src/Server/AstralForge/Modules/ConvergenceOpsMath")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label)
end

------------------------------------------------------------------------
-- EnsureEventProfile — EventId-matched bags missing Contribution
------------------------------------------------------------------------
local freshProfile = {}
local ensured = ConvergenceOpsMath.EnsureEventProfile(freshProfile, "evt-A")
assert(ensured.EventId == "evt-A" and ensured.Contribution == 0, "nil LiveOps → empty event")
assert(type(ensured.Claimed) == "table", "nil LiveOps seeds Claimed")
assert(type(freshProfile.LiveOps.Convergence) == "table", "mutates profile.LiveOps.Convergence")

-- Evidence bug: EventId match with nil Contribution used to throw on += amount.
local nilContribution = {
	LiveOps = { Convergence = { EventId = "evt-A", Claimed = {} } },
}
local fixed = ConvergenceOpsMath.EnsureEventProfile(nilContribution, "evt-A")
assert(fixed.Contribution == 0, "EventId-matched nil Contribution → 0")
fixed.Contribution += 5
assert(fixed.Contribution == 5, "Contribution += after Ensure is safe")

local stringContrib = {
	LiveOps = { Convergence = { EventId = "evt-A", Contribution = "12.7", Claimed = nil } },
}
local coerced = ConvergenceOpsMath.EnsureEventProfile(stringContrib, "evt-A")
assert(coerced.Contribution == 12.7, "string Contribution coerced")
assert(type(coerced.Claimed) == "table", "nil Claimed rebuilt")

local rollover = ConvergenceOpsMath.EnsureEventProfile({
	LiveOps = { Convergence = { EventId = "old", Contribution = 99, Claimed = { ["1"] = true } } },
}, "evt-B")
assert(rollover.EventId == "evt-B" and rollover.Contribution == 0, "EventId mismatch reseeds")
assert(rollover.Claimed["1"] == nil, "EventId mismatch clears Claimed")

------------------------------------------------------------------------
-- ReadEventProfile — non-mutating snapshot
------------------------------------------------------------------------
local source = {
	LiveOps = { Convergence = { EventId = "evt-A", Contribution = 40, Claimed = { ["2"] = true } } },
}
local snapshot = ConvergenceOpsMath.ReadEventProfile(source, "evt-A")
assert(snapshot.Contribution == 40 and snapshot.Claimed["2"] == true, "read matches")
assert(ConvergenceOpsMath.ReadEventProfile(nil, "evt-A").Contribution == 0, "nil profile → empty")
assert(ConvergenceOpsMath.ReadEventProfile({ LiveOps = {} }, "evt-A").Contribution == 0, "missing Convergence")
assert(
	ConvergenceOpsMath.ReadEventProfile({
		LiveOps = { Convergence = { EventId = "other", Contribution = 9 } },
	}, "evt-A").Contribution == 0,
	"mismatched EventId → empty"
)
-- Read must not mutate
local before = source.LiveOps.Convergence.Contribution
ConvergenceOpsMath.ReadEventProfile(source, "evt-A")
assert(source.LiveOps.Convergence.Contribution == before, "Read must not mutate")

------------------------------------------------------------------------
-- EnsureRewardBags
------------------------------------------------------------------------
local bags = {}
ConvergenceOpsMath.EnsureRewardBags(bags)
assert(type(bags.Stats) == "table", "Stats rebuilt")
assert(type(bags.Command) == "table" and bags.Command.Signals == 0, "Command.Signals rebuilt")
assert(type(bags.BoostInventory) == "table", "BoostInventory rebuilt")

------------------------------------------------------------------------
-- ProductionMultiplier / PhaseState / CanClaimTier
------------------------------------------------------------------------
local phases = {
	{ Target = 500, Name = "IGNITION", ProductionMultiplier = 1.02 },
	{ Target = 2_500, Name = "TEMPERED", ProductionMultiplier = 1.05 },
	{ Target = 10_000, Name = "RESONANT", ProductionMultiplier = 1.10 },
}
near(ConvergenceOpsMath.ProductionMultiplier(0, phases), 1, "below first → 1")
near(ConvergenceOpsMath.ProductionMultiplier(500, phases), 1.02, "ignition")
near(ConvergenceOpsMath.ProductionMultiplier(2_500, phases), 1.05, "tempered")
near(ConvergenceOpsMath.ProductionMultiplier(99_999, phases), 1.10, "resonant")
near(ConvergenceOpsMath.ProductionMultiplier(100, nil), 1, "nil phases → 1")

local idx, name, nextTarget = ConvergenceOpsMath.PhaseState(0, phases)
assert(idx == 0 and name == "HEATING" and nextTarget == 500, "heating phase")
idx, name, nextTarget = ConvergenceOpsMath.PhaseState(600, phases)
assert(idx == 1 and name == "IGNITION" and nextTarget == 2_500, "ignition next")
idx, name, nextTarget = ConvergenceOpsMath.PhaseState(12_000, phases)
assert(idx == 3 and name == "RESONANT" and nextTarget == 10_000, "final phase holds target")

assert(ConvergenceOpsMath.CanClaimTier(20, 20, {}, 1) == true, "ready unclaimed")
assert(ConvergenceOpsMath.CanClaimTier(19, 20, {}, 1) == false, "below required")
assert(ConvergenceOpsMath.CanClaimTier(99, 20, { ["1"] = true }, 1) == false, "already claimed")
assert(ConvergenceOpsMath.CanClaimTier(nil, 0, nil, 1) == true, "nil contribution + 0 required")

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local serviceSrc = fs.readFile("src/Server/AstralForge/Services/ConvergenceService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/ConvergenceOpsMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(serviceSrc, "ConvergenceOpsMath.EnsureEventProfile", 1, true), "Flush/Claim must EnsureEventProfile")
assert(string.find(serviceSrc, "ConvergenceOpsMath.ReadEventProfile", 1, true), "State must ReadEventProfile")
assert(string.find(serviceSrc, "ConvergenceOpsMath.ProductionMultiplier", 1, true), "Multiplier must delegate")
assert(string.find(serviceSrc, "ConvergenceOpsMath.PhaseState", 1, true), "State must PhaseState")
assert(string.find(serviceSrc, "ConvergenceOpsMath.CanClaimTier", 1, true), "State must CanClaimTier")
assert(string.find(serviceSrc, "ConvergenceOpsMath.EnsureRewardBags", 1, true), "Claim applyReward must EnsureRewardBags")
assert(not string.find(serviceSrc, "local function eventProfile", 1, true), "inline eventProfile must be removed")
assert(not string.find(serviceSrc, "local function readEventProfile", 1, true), "inline readEventProfile must be removed")

assert(string.find(configSrc, "Wave18ConvergenceOps", 1, true), "DV21 lab Wave18ConvergenceOps")
assert(string.find(configSrc, "Wave18ClaimClipsSoftMotion", 1, true), "DV21 lab Wave18ClaimClipsSoftMotion")
assert(string.find(configSrc, "Wave18ConvergenceCourier", 1, true), "DV21 achievement Wave18ConvergenceCourier")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
assert(tonumber(dv) == 21, "DataVersion must remain pinned at 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for badgeId, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. badgeId .. " must be 0")
end

for _, body in { serviceSrc, mathSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] ConvergenceOpsMath extract guards passed")
