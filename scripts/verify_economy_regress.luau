--!strict
-- Regression guards for economy/admin dead-field + nil-safe progression bags.
-- Evidence targets (master tip regressions):
--   1) Admin FillVault read profile.Capacity (never persisted) → silent no-op
--   2) Admin online list read profile.Production (EncodeState-only) → RATE always 0
--   3) Economy.ForgePathEffect / Totals crashed on partial Machines/Research/ClaimedSteps
--   4) DataService sanitize omitted ForgePath while every other bag was hardened
-- HARD: no vendor/Packages; string + pure logic only (no Roblox runtime).

local fs = require("@lune/fs")

local adminSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local gateSrc = fs.readFile("src/Server/AstralForge/Modules/ProgressionGate.luau")
local upgradeSrc = fs.readFile("src/Server/AstralForge/Modules/UpgradeCostReason.luau")
local forgeClaimSrc = fs.readFile("src/Server/AstralForge/Modules/ForgePathClaim.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

-- --- Admin dead fields -------------------------------------------------------
assert(
	string.find(adminSrc, "profile.Vault = profile.Capacity", 1, true) == nil,
	"FillVault must not read profile.Capacity (computed-only; was a silent no-op)"
)
assert(
	string.find(adminSrc, "profile.Vault = Economy.Capacity(profile)", 1, true) ~= nil,
	"FillVault must assign Economy.Capacity(profile)"
)
assert(
	string.find(adminSrc, "Production = profile.Production", 1, true) == nil,
	"Admin online list must not read profile.Production (always nil on profile)"
)
assert(
	string.find(adminSrc, "Production = Economy.Production(profile)", 1, true) ~= nil,
	"Admin online list must project Economy.Production(profile)"
)
assert(
	string.find(adminSrc, "Capacity = Economy.Capacity(profile)", 1, true) ~= nil,
	"Admin online list must project Economy.Capacity(profile) for FillVault vault/cap"
)
assert(
	string.find(adminSrc, 'WaitForChild("Economy")', 1, true) ~= nil,
	"AdminService must require Economy module"
)

-- --- Economy nil-safety ------------------------------------------------------
assert(
	string.find(economySrc, 'type(claimed) ~= "table"', 1, true) ~= nil,
	"ForgePathEffect must nil-guard ClaimedSteps"
)
assert(
	string.find(economySrc, 'type(machines) ~= "table"', 1, true) ~= nil,
	"TotalMachineLevels must nil-guard Machines"
)
assert(
	string.find(economySrc, 'type(research) ~= "table"', 1, true) ~= nil,
	"TotalResearchLevels / researchLevel must nil-guard Research"
)
assert(
	string.find(economySrc, 'slot == "Machine" and type(machines) == "table"', 1, true) ~= nil,
	"ItemEffect must nil-guard Machines before indexing"
)

-- Pure replica of ForgePathEffect nil-guards (must stay aligned with Economy.luau).
local function forgePathEffect(profile: any, effectKind: string, steps: { any }): number
	local forgePath = profile and profile.ForgePath
	if forgePath == nil then
		return 0
	end
	local claimed = forgePath.ClaimedSteps
	if type(claimed) ~= "table" then
		return 0
	end
	local total = 0
	for stepKey in claimed do
		local stepIndex = tonumber(stepKey)
		local step = stepIndex and steps[stepIndex]
		if step and step.EffectKind == effectKind then
			total += step.EffectAmount
		end
	end
	return total / 100
end

local fakeSteps = {
	{ EffectKind = "Production", EffectAmount = 10 },
	{ EffectKind = "Capacity", EffectAmount = 20 },
}
assert(forgePathEffect({ ForgePath = nil }, "Production", fakeSteps) == 0, "nil ForgePath → 0")
assert(forgePathEffect({ ForgePath = { XP = 9 } }, "Production", fakeSteps) == 0, "missing ClaimedSteps → 0")
assert(
	forgePathEffect({ ForgePath = { ClaimedSteps = { ["1"] = true } } }, "Production", fakeSteps) == 0.1,
	"claimed step 1 Production effect"
)
assert(forgePathEffect({ ForgePath = { ClaimedSteps = { ["1"] = true } } }, "Tap", fakeSteps) == 0, "wrong kind → 0")

local function totalLevels(bag: any): number
	if type(bag) ~= "table" then
		return 0
	end
	local total = 0
	for _, value in bag do
		if type(value) == "number" then
			total += value
		end
	end
	return total
end
assert(totalLevels(nil) == 0, "nil bag levels → 0")
assert(totalLevels({ A = 2, B = 3 }) == 5, "sum levels")

-- --- DataService / ProgressionService ForgePath harden -----------------------
assert(
	string.find(dataSrc, "profile.ForgePath", 1, true) ~= nil,
	"DataService sanitize must handle ForgePath"
)
assert(
	string.find(dataSrc, "ClaimedSteps", 1, true) ~= nil,
	"DataService sanitize must ensure ForgePath.ClaimedSteps"
)
assert(
	string.find(progressionSrc, "ForgePathClaim.Ensure", 1, true) ~= nil,
	"ensureForgePath must delegate to ForgePathClaim.Ensure"
)
assert(
	string.find(forgeClaimSrc, 'type(forgePath.ClaimedSteps) ~= "table"', 1, true) ~= nil,
	"ForgePathClaim.Ensure must fill missing ClaimedSteps on partial bags"
)
assert(
	string.find(upgradeSrc, "tonumber(profile.Zone)", 1, true) ~= nil,
	"UpgradeCostReason must tonumber Zone (nil-safe)"
)
assert(
	string.find(upgradeSrc, "tonumber(profile.Rebirths)", 1, true) ~= nil,
	"UpgradeCostReason must tonumber Rebirths (nil-safe)"
)
assert(
	string.find(gateSrc, "UpgradeCostReason.Evaluate", 1, true) ~= nil,
	"ProgressionGate.UpgradeReason must delegate to UpgradeCostReason.Evaluate"
)

-- --- AchievementProgress / Admin anomaly grant desync -------------------------
-- Evidence:
--   1) Domain expand zeroes profile.Rebirths while TotalRebirthsSpent accumulates —
--      AchievementProgress used to return only live Rebirths → TenRebirths regresses.
--   2) Admin GrantAnomalyStabilizations bumped Anomaly.Stabilizations only; Stats lagged
--      so weekly AnomalyStabilizations + achievement ledgers stayed at 0 after grants.
--   3) Partial Stats bags crashed AchievementProgress / currentWeeklyValue / Lab ClaimOrder.
assert(
	string.find(progressionSrc, "TotalRebirthsSpent", 1, true) ~= nil,
	"AchievementProgress Rebirths must include Domain.TotalRebirthsSpent"
)
assert(
	string.find(progressionSrc, "anomaly and anomaly.Stabilizations", 1, true) ~= nil
		or string.find(progressionSrc, "anomaly.Stabilizations", 1, true) ~= nil,
	"AchievementProgress AnomalyStabilizations must prefer Anomaly bag"
)
assert(
	string.find(progressionSrc, "tonumber(stats and stats.PlayTime)", 1, true) ~= nil,
	"AchievementProgress PlayTime must nil-safe Stats"
)
assert(
	string.find(progressionSrc, "tonumber(command and command.ExpeditionsCompleted)", 1, true) ~= nil,
	"currentWeeklyValue Expeditions must nil-safe Command"
)
assert(
	string.find(adminSrc, "GrantAnomalyStabilizations", 1, true) ~= nil,
	"Admin GrantAnomalyStabilizations must exist"
)
assert(
	string.find(adminSrc, "Stats.AnomalyStabilizations", 1, true) ~= nil,
	"Admin GrantAnomalyStabilizations must sync Stats.AnomalyStabilizations"
)

-- Pure replica of AchievementProgress Rebirths + AnomalyStabilizations nil-guards.
local function achievementRebirths(profile: any): number
	local current = math.max(0, math.floor(tonumber(profile.Rebirths) or 0))
	local spent = 0
	if type(profile.Domain) == "table" then
		spent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0))
	end
	return current + spent
end
local function achievementStabilizations(profile: any): number
	local anomaly = profile.Anomaly
	local fromAnomaly = tonumber(anomaly and anomaly.Stabilizations)
	if fromAnomaly ~= nil then
		return math.max(0, math.floor(fromAnomaly))
	end
	local stats = profile.Stats
	return math.max(0, math.floor(tonumber(stats and stats.AnomalyStabilizations) or 0))
end
assert(achievementRebirths({ Rebirths = 0, Domain = { TotalRebirthsSpent = 12 } }) == 12, "spent rebirths count")
assert(achievementRebirths({ Rebirths = 3, Domain = { TotalRebirthsSpent = 10 } }) == 13, "live+spent rebirths")
assert(achievementRebirths({ Rebirths = nil, Domain = nil }) == 0, "nil rebirth bags → 0")
assert(achievementStabilizations({ Anomaly = { Stabilizations = 7 }, Stats = { AnomalyStabilizations = 0 } }) == 7, "prefer Anomaly bag")
assert(achievementStabilizations({ Anomaly = nil, Stats = nil }) == 0, "nil anomaly/stats → 0")

local labSrc = fs.readFile("src/Server/AstralForge/Services/LabService.luau")
assert(
	string.find(labSrc, 'type(profile.Stats) ~= "table"', 1, true) ~= nil,
	"LabService.ClaimOrder must nil-safe Stats before OrdersCompleted bump"
)

-- --- HARD constraints still hold ---------------------------------------------
local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
-- Do not couple these modules to vendor/Packages (tree may exist; we must not reference it).
for _, body in { adminSrc, economySrc, dataSrc, progressionSrc, gateSrc, upgradeSrc, forgeClaimSrc, labSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] economy/admin regress guards passed | FillVault+Production+ForgePath+AchievementProgress nil-safe")
