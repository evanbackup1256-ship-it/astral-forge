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
	string.find(economySrc, "ForgePathClaim.Effect", 1, true) ~= nil
		or string.find(economySrc, 'type(claimed) ~= "table"', 1, true) ~= nil,
	"ForgePathEffect must nil-guard ClaimedSteps via ForgePathClaim.Effect"
)
assert(
	string.find(economySrc, "EconomyEnvelopeMath.SumNumericLevels", 1, true) ~= nil
		or string.find(economySrc, 'type(machines) ~= "table"', 1, true) ~= nil,
	"TotalMachineLevels must nil-guard Machines via EconomyEnvelopeMath"
)
assert(
	string.find(economySrc, "EconomyEnvelopeMath.SumNumericLevels", 1, true) ~= nil
		or string.find(economySrc, 'type(research) ~= "table"', 1, true) ~= nil,
	"TotalResearchLevels / researchLevel must nil-guard Research"
)
assert(
	string.find(economySrc, 'slot == "Machine" and type(machines) == "table"', 1, true) ~= nil,
	"ItemEffect must nil-guard Machines before indexing"
)

-- Pure ForgePathClaim.Effect nil-guards (must stay aligned with Economy.luau).
local ForgePathClaim = require("../src/Server/AstralForge/Modules/ForgePathClaim")
local EconomyEnvelopeMath = require("../src/Server/AstralForge/Modules/EconomyEnvelopeMath")
local function forgePathEffect(profile: any, effectKind: string, steps: { any }): number
	local forgePath = profile and profile.ForgePath
	if forgePath == nil then
		return 0
	end
	return ForgePathClaim.Effect(forgePath.ClaimedSteps, steps, effectKind)
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

assert(EconomyEnvelopeMath.SumNumericLevels(nil) == 0, "nil bag levels → 0")
assert(EconomyEnvelopeMath.SumNumericLevels({ A = 2, B = 3 }) == 5, "sum levels")

assert(
	string.find(forgeClaimSrc, "function ForgePathClaim.Effect", 1, true) ~= nil,
	"ForgePathClaim.Effect must exist for Economy.ForgePathEffect"
)

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
--   4) Admin online WORLD published CurrentZone (visit) as Zone → unlock watermark lagged
--      whenever a player stood in an earlier world (SetZone / Discord use profile.Zone).
--   5) Convergence applyReward indexed profile.Stats / Command / BoostInventory without
--      guards — partial bags threw mid-claim; boost rewards silently dropped when the
--      inventory key was absent.
assert(
	string.find(progressionSrc, "ProgressionOpsMath.AchievementProgress", 1, true) ~= nil,
	"AchievementProgress must delegate ProgressionOpsMath"
)
local progressionOpsSrc = fs.readFile("src/Server/AstralForge/Modules/ProgressionOpsMath.luau")
assert(
	string.find(progressionOpsSrc, "TotalRebirthsSpent", 1, true) ~= nil,
	"AchievementProgress Rebirths must include Domain.TotalRebirthsSpent"
)
assert(
	string.find(progressionOpsSrc, "anomaly and anomaly.Stabilizations", 1, true) ~= nil
		or string.find(progressionOpsSrc, "anomaly.Stabilizations", 1, true) ~= nil,
	"AchievementProgress AnomalyStabilizations must prefer Anomaly bag"
)
assert(
	string.find(progressionOpsSrc, "tonumber(stats and stats.PlayTime)", 1, true) ~= nil,
	"AchievementProgress PlayTime must nil-safe Stats"
)
assert(
	string.find(progressionOpsSrc, "tonumber(command and command.ExpeditionsCompleted)", 1, true) ~= nil
		or string.find(progressionSrc, "ProgressionOpsMath.WeeklyValue", 1, true) ~= nil,
	"currentWeeklyValue Expeditions must nil-safe Command"
)
assert(
	string.find(adminSrc, "GrantAnomalyStabilizations", 1, true) ~= nil,
	"Admin GrantAnomalyStabilizations must exist"
)
assert(
	string.find(adminSrc, "Stats.AnomalyStabilizations", 1, true) ~= nil
		or string.find(adminSrc, 'BumpStat(profile, "AnomalyStabilizations"', 1, true) ~= nil,
	"Admin GrantAnomalyStabilizations must sync Stats.AnomalyStabilizations"
)
assert(
	string.find(adminSrc, "Zone = profile.Zone", 1, true) ~= nil,
	"Admin online list must publish unlock watermark profile.Zone"
)
assert(
	string.find(adminSrc, "\tZone = profile.CurrentZone", 1, true) == nil,
	"Admin online Zone must not be CurrentZone (visit location)"
)
assert(
	string.find(adminSrc, "CurrentZone = profile.CurrentZone", 1, true) ~= nil,
	"Admin online list may still expose CurrentZone separately for visit clarity"
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
assert(
	string.find(labSrc, "Stats.PowerMoves", 1, true) ~= nil,
	"LabService.RoutePower must bump Stats.PowerMoves"
)
assert(
	string.find(labSrc, "tonumber(profile.Stats.PowerMoves)", 1, true) ~= nil,
	"LabService.RoutePower must tonumber PowerMoves (nil-safe)"
)

local convergenceSrc = fs.readFile("src/Server/AstralForge/Services/ConvergenceService.luau")
assert(
	string.find(convergenceSrc, "ConvergenceOpsMath.EnsureRewardBags", 1, true) ~= nil,
	"Convergence applyReward must EnsureRewardBags before Collected/Signals/Boost bumps"
)
assert(
	string.find(convergenceSrc, "ConvergenceOpsMath.EnsureEventProfile", 1, true) ~= nil,
	"Convergence Flush/Claim must EnsureEventProfile before Contribution bump"
)
assert(
	string.find(convergenceSrc, "profile.BoostInventory[reward.Boost] ~= nil", 1, true) == nil,
	"Convergence must not silently drop boost rewards when the inventory key is absent"
)

local anomalySrc = fs.readFile("src/Server/AstralForge/Services/AnomalyService.luau")
assert(
	string.find(anomalySrc, "bumpAnomalyStat", 1, true) ~= nil,
	"AnomalyService must nil-safe Stats bumps via bumpAnomalyStat"
)
assert(
	string.find(anomalySrc, 'type(profile.Stats) ~= "table"', 1, true) ~= nil
		or string.find(anomalySrc, "ProfileBagMath.BumpStat", 1, true) ~= nil,
	"AnomalyService bumpAnomalyStat must nil-safe Stats"
)
assert(
	string.find(anomalySrc, 'profile.Stats.AnomalyPulses += 1', 1, true) == nil,
	"AnomalyService must not raw-increment Stats.AnomalyPulses"
)
assert(
	string.find(anomalySrc, 'profile.Stats.AnomalyStabilizations += 1', 1, true) == nil,
	"AnomalyService must not raw-increment Stats.AnomalyStabilizations"
)

assert(
	string.find(progressionSrc, "ensureCommand", 1, true) ~= nil,
	"ProgressionService.ApplyReward must nil-safe Command via ensureCommand"
)
assert(
	string.find(progressionSrc, 'type(profile.BoostInventory) ~= "table"', 1, true) ~= nil
		or string.find(progressionSrc, "ProfileBagMath.EnsureBoostInventory", 1, true) ~= nil,
	"ProgressionService.ApplyReward must nil-safe BoostInventory"
)
assert(
	string.find(progressionSrc, 'type(profile.Anomaly) ~= "table"', 1, true) ~= nil
		or string.find(progressionSrc, "ProfileBagMath.EnsureAnomaly", 1, true) ~= nil,
	"ProgressionService.ApplyReward must nil-safe Anomaly before Fragments"
)
assert(
	string.find(progressionSrc, "profile.Stardust = (tonumber(profile.Stardust) or 0)", 1, true) ~= nil,
	"ProgressionService.ApplyReward must tonumber Stardust"
)

-- --- Progression claim Stats + Admin GrantRelic nil-safety ---------------------
-- Evidence: ClaimWeeklyDirective / BuySignalOffer / ClaimExpedition / ClaimSeasonTier
-- raw-indexed profile.Stats.* — partial Studio fixtures (Stats = nil) threw before
-- ApplyReward. Admin createRelic did the same for Stats.ItemsFound.
assert(
	string.find(progressionSrc, "bumpStat", 1, true) ~= nil
		or string.find(progressionSrc, "ensureStats", 1, true) ~= nil,
	"Progression claim paths must nil-safe Stats via ensureStats/bumpStat"
)
assert(
	string.find(progressionSrc, 'type(profile.Stats) ~= "table"', 1, true) ~= nil
		or string.find(progressionSrc, "ProfileBagMath.EnsureStats", 1, true) ~= nil,
	"Progression ensureStats must nil-safe Stats"
)
assert(
	string.find(progressionSrc, 'profile.Stats.WeeklyClaimed = (profile.Stats.WeeklyClaimed or 0) + 1', 1, true) == nil,
	"ClaimWeeklyDirective must not raw-index Stats.WeeklyClaimed"
)
assert(
	string.find(progressionSrc, 'profile.Stats.Expeditions = (profile.Stats.Expeditions or 0) + 1', 1, true) == nil,
	"ClaimExpedition must not raw-index Stats.Expeditions"
)
assert(
	string.find(progressionSrc, 'profile.Stats.SeasonTiers = (profile.Stats.SeasonTiers or 0) + 1', 1, true) == nil,
	"ClaimSeasonTier must not raw-index Stats.SeasonTiers"
)
assert(
	string.find(progressionSrc, 'profile.Stats.ShopPurchases = (profile.Stats.ShopPurchases or 0) + 1', 1, true) == nil,
	"BuySignalOffer must not raw-index Stats.ShopPurchases"
)
assert(
	string.find(progressionOpsSrc, 'kind == "Expeditions"', 1, true) ~= nil,
	"AchievementProgress must track Expeditions kind"
)
assert(
	string.find(adminSrc, "Stats.ItemsFound", 1, true) ~= nil
		or string.find(adminSrc, 'BumpStat(profile, "ItemsFound"', 1, true) ~= nil,
	"Admin createRelic must bump Stats.ItemsFound"
)
assert(
	string.find(adminSrc, 'type(profile.Stats) ~= "table"', 1, true) ~= nil
		or string.find(adminSrc, "ProfileBagMath.BumpStat", 1, true) ~= nil,
	"Admin createRelic must nil-safe Stats before ItemsFound bump"
)
assert(
	string.find(adminSrc, "profile.Stats.ItemsFound += 1", 1, true) == nil,
	"Admin createRelic must not raw-increment Stats.ItemsFound"
)

-- --- ApplyReward Keys + ClaimDaily + GameService Stats nil-safety -------------
-- Evidence: WeeklyRelics Grant Keys via ApplyReward — profile.Items.Keys raw index
-- threw on partial Items bags. ClaimDaily raw-indexed Command.StreakShields /
-- Daily.* — Studio fixtures without those bags crashed before ApplyReward.
-- GameService collect/tap/crate/continuum/production raw Stats increments threw
-- the same way; ActivateBoost raw ActiveBoost/BoostInventory likewise.
assert(
	string.find(progressionSrc, "ensureItemKeys", 1, true) ~= nil,
	"ProgressionService.ApplyReward must nil-safe Items.Keys via ensureItemKeys"
)
assert(
	string.find(progressionSrc, "profile.Items.Keys[crateId] = (profile.Items.Keys[crateId] or 0)", 1, true) == nil,
	"ApplyReward must not raw-index profile.Items.Keys"
)
assert(
	string.find(progressionSrc, "ensureDaily", 1, true) ~= nil,
	"ProgressionService.ClaimDaily must nil-safe Daily via ensureDaily"
)
assert(
	string.find(progressionSrc, "profile.Command.StreakShields > 0", 1, true) == nil,
	"ClaimDaily must not raw-compare Command.StreakShields"
)

local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(
	string.find(servicesSrc, "bumpStat", 1, true) ~= nil
		and string.find(servicesSrc, "ensureStats", 1, true) ~= nil,
	"GameService must nil-safe Stats via ensureStats/bumpStat"
)
assert(
	string.find(servicesSrc, "profile.Stats.Taps += 1", 1, true) == nil,
	"Overcharge must not raw-increment Stats.Taps"
)
assert(
	string.find(servicesSrc, "profile.Stats.CratesOpened += count", 1, true) == nil,
	"OpenCrate must not raw-increment Stats.CratesOpened"
)
assert(
	string.find(servicesSrc, "ensureActiveBoost", 1, true) ~= nil,
	"ActivateBoost / production tick must nil-safe ActiveBoost"
)
assert(
	string.find(servicesSrc, "ensureBoostInventory", 1, true) ~= nil,
	"ActivateBoost must nil-safe BoostInventory"
)
assert(
	string.find(servicesSrc, "profile.ActiveBoost.EndsAt > os.time()", 1, true) == nil,
	"ActivateBoost must not raw-index ActiveBoost.EndsAt"
)

-- --- Economy bag + Achievements + Admin Items nil-safety (wave10) ------------
-- Evidence: ApplyReward Keys seeds Items={Keys={}} without Equipped/Inventory —
-- ItemEffect threw during Production. ApplyReward Fragments seeds Anomaly=
-- {Fragments=0} without Protocols — AnomalyEffect threw. ensureCommand omits
-- Artifacts/MachineMastery — ArtifactEffect/MasteryMultiplier threw.
-- ClaimAchievement / AchievementStates raw-indexed profile.Achievements.
-- Admin createRelic raw-indexed Items.Inventory on Keys-only bags.
assert(
	string.find(economySrc, 'type(equipped) ~= "table" or type(inventory) ~= "table"', 1, true) ~= nil,
	"ItemEffect must nil-guard Equipped/Inventory tables"
)
assert(
	string.find(economySrc, 'type(command.Artifacts) ~= "table"', 1, true) ~= nil,
	"ArtifactEffect must nil-guard Command.Artifacts"
)
assert(
	string.find(economySrc, "EconomyEnvelopeMath.MasteryMultiplier", 1, true) ~= nil
		or string.find(economySrc, 'type(mastery) ~= "table"', 1, true) ~= nil,
	"MasteryMultiplier must nil-guard MachineMastery"
)
assert(
	string.find(economySrc, "local protocols = state.Protocols", 1, true) ~= nil
		and string.find(economySrc, 'type(protocols) == "table"', 1, true) ~= nil,
	"AnomalyEffect must nil-guard Protocols"
)
assert(
	string.find(economySrc, "state.Protocols[protocol.Id]", 1, true) == nil,
	"AnomalyEffect must not raw-index state.Protocols"
)
assert(
	string.find(progressionSrc, 'type(profile.Achievements) ~= "table"', 1, true) ~= nil,
	"ClaimAchievement must nil-safe Achievements"
)
assert(
	string.find(progressionSrc, "profile.Achievements[achievement.Id] == true", 1, true) == nil,
	"AchievementStates must not raw-index Achievements"
)
assert(
	string.find(adminSrc, 'type(profile.Items.Inventory) ~= "table"', 1, true) ~= nil
		or string.find(adminSrc, "ProfileBagMath.EnsureItems", 1, true) ~= nil,
	"Admin createRelic must nil-safe Items.Inventory"
)

local analyticsSrc = fs.readFile("src/Server/AstralForge/Services/PlayerAnalytics.luau")
assert(
	string.find(analyticsSrc, "profile.Stats and profile.Stats.Joins", 1, true) ~= nil,
	"PlayerAnalytics session start must nil-safe Stats.Joins"
)
assert(
	string.find(analyticsSrc, "profile.Stats.Joins,", 1, true) == nil,
	"PlayerAnalytics must not raw-pass Stats.Joins"
)

-- --- Quests / TimedRewards + sanitize rebuild after ApplyReward (wave11) ------
-- Evidence: ApplyReward Keys seeds Items={Keys={}} — post-claim sanitize threw on
-- Items.Shop / Inventory. ApplyReward Fragments seeds Anomaly={Fragments=0} —
-- sanitize threw iterating nil Protocols. FreeSpins seeds Wheel={FreeSpins=0}.
-- EnsureQuests / EnsureTimedRewards / Progress / ClaimQuest raw-indexed missing bags.
assert(
	(
		string.find(dataSrc, 'type(profile.Items) ~= "table"', 1, true) ~= nil
		and string.find(dataSrc, 'type(profile.Items.Shop) ~= "table"', 1, true) ~= nil
	)
		or string.find(dataSrc, "ProfileBagMath.EnsureItems", 1, true) ~= nil,
	"DataService sanitize must rebuild Keys-only Items before Shop access"
)
assert(
	string.find(dataSrc, 'type(profile.Anomaly.Protocols) ~= "table"', 1, true) ~= nil
		or string.find(dataSrc, "ProfileBagMath.EnsureAnomaly", 1, true) ~= nil,
	"DataService sanitize must rebuild Fragments-only Anomaly.Protocols"
)
assert(
	string.find(dataSrc, 'type(profile.Wheel) ~= "table"', 1, true) ~= nil,
	"DataService sanitize must rebuild FreeSpins-only Wheel"
)
assert(
	string.find(dataSrc, 'type(profile.Quests) ~= "table"', 1, true) ~= nil,
	"DataService sanitize must harden Quests bag"
)
assert(
	string.find(dataSrc, 'type(profile.TimedRewards) ~= "table"', 1, true) ~= nil,
	"DataService sanitize must harden TimedRewards bag"
)
assert(
	string.find(progressionSrc, "ensureQuests", 1, true) ~= nil,
	"ProgressionService must nil-safe Quests via ensureQuests"
)
assert(
	string.find(progressionSrc, "profile.Quests.Day == day and #profile.Quests.Items > 0", 1, true) == nil,
	"EnsureQuests must not raw-index Quests.Day/Items"
)
assert(
	string.find(progressionSrc, "ensureTimedRewardsBag", 1, true) ~= nil,
	"ProgressionService must nil-safe TimedRewards via ensureTimedRewardsBag"
)
assert(
	string.find(progressionSrc, "profile.TimedRewards.Day == day", 1, true) == nil,
	"EnsureTimedRewards must not raw-compare TimedRewards.Day"
)
assert(
	string.find(adminSrc, 'type(profile.BoostInventory) ~= "table"', 1, true) ~= nil
		or string.find(adminSrc, "ProfileBagMath.EnsureBoostInventory", 1, true) ~= nil,
	"Admin GrantBoost must nil-safe BoostInventory"
)
assert(
	string.find(adminSrc, 'type(profile.Command.Artifacts) ~= "table"', 1, true) ~= nil
		or string.find(adminSrc, "CommandMath.Ensure", 1, true) ~= nil,
	"Admin DiscoverArts must nil-safe Command.Artifacts"
)

-- --- WheelMath extract + FreeSpins SpinWheel nil-safety (wave12) --------------
-- Evidence: ApplyReward FreeSpins seeds Wheel={FreeSpins=N} without LastSpinAt —
-- WheelState did `profile.Wheel.LastSpinAt + Cooldown` (nil+number throw) and
-- SpinWheel crashed before the spin. Admin ResetWheelCooldown / ResetDailyClaim
-- raw-indexed missing bags on Studio fixtures.
assert(
	string.find(progressionSrc, "WheelMath.Ensure", 1, true) ~= nil
		and string.find(progressionSrc, "ensureWheel", 1, true) ~= nil,
	"ProgressionService must nil-safe Wheel via WheelMath.Ensure / ensureWheel"
)
assert(
	string.find(progressionSrc, "profile.Wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds", 1, true) == nil,
	"WheelState / SpinWheel must not raw-add LastSpinAt on partial bags"
)
assert(
	string.find(progressionSrc, "local WHEEL_RARITY_RANK", 1, true) == nil,
	"inline WHEEL_RARITY_RANK must move to WheelMath"
)
assert(
	string.find(adminSrc, 'type(profile.Wheel) ~= "table"', 1, true) ~= nil
		or string.find(adminSrc, "WheelMath.Ensure", 1, true) ~= nil,
	"Admin ResetWheelCooldown must nil-safe Wheel"
)
assert(
	string.find(adminSrc, 'type(profile.Daily) ~= "table"', 1, true) ~= nil
		or string.find(adminSrc, "ProfileBagMath.EnsureDaily", 1, true) ~= nil,
	"Admin ResetDailyClaim must nil-safe Daily"
)

-- --- CommandMath extract + Signals-only Command / Lab sanitize (wave13) ------
-- Evidence: ApplyReward Signals seeds Command={Signals=N} without Crew/Artifacts —
-- sanitize iterated nil Crew/MachineMastery/Artifacts. Studio fixtures omitting Lab
-- crashed sanitize on Orders/Routing. MailClaimActions ClipsDescendants=true buried
-- CLAIM on short phones (same class as Continuum/crate CLAIM clips).
assert(
	string.find(progressionSrc, "CommandMath.Ensure", 1, true) ~= nil
		and string.find(progressionSrc, "ensureCommand", 1, true) ~= nil,
	"ProgressionService must nil-safe Command via CommandMath.Ensure / ensureCommand"
)
assert(
	string.find(progressionSrc, 'profile.Command = { XP = 0, SeasonXP = 0, Signals = 0, StreakShields = 0 }', 1, true) == nil,
	"thin Signals-only ensureCommand seed must be removed"
)
assert(
	string.find(dataSrc, "CommandMath.Ensure", 1, true) ~= nil,
	"DataService sanitize must rebuild Signals-only Command"
)
assert(
	string.find(dataSrc, "LabOrderMath.Ensure", 1, true) ~= nil
		and string.find(dataSrc, "LabOrderMath.NormalizeRouting", 1, true) ~= nil,
	"DataService sanitize must rebuild + normalize Lab bags"
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
for _, body in { adminSrc, economySrc, dataSrc, progressionSrc, gateSrc, upgradeSrc, forgeClaimSrc, labSrc, convergenceSrc, anomalySrc, servicesSrc, analyticsSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] economy/admin regress guards passed | FillVault+Production+ForgePath+AchievementProgress+AdminZone+Convergence+Anomaly+ApplyReward+ClaimStats+KeysDaily+GameServiceStats+EconomyBags+Achievements+QuestsTimed+SanitizeBags+WheelMath+CommandMath nil-safe")

-- --- Admin grant bag Ensures (wave14) ----------------------------------------
-- Evidence: GrantDomainEssence/GrantSignals/GrantItemEssence/GrantFreeSpins/
-- DrainKeys raw-indexed Domain/Command/Items/Wheel on Keys-only Studio fixtures.
assert(
	string.find(adminSrc, "ProfileBagMath.EnsureDomain", 1, true) ~= nil,
	"Admin GrantDomainEssence must ProfileBagMath.EnsureDomain"
)
assert(
	string.find(adminSrc, "CommandMath.Ensure", 1, true) ~= nil,
	"Admin GrantSignals must CommandMath.Ensure"
)
assert(
	string.find(adminSrc, "ProfileBagMath.EnsureItems", 1, true) ~= nil,
	"Admin GrantItemEssence must EnsureItems"
)
assert(
	string.find(adminSrc, "WheelMath.Ensure", 1, true) ~= nil,
	"Admin GrantFreeSpins must WheelMath.Ensure"
)
assert(
	string.find(adminSrc, "ProfileBagMath.EnsureItemKeys", 1, true) ~= nil,
	"Admin DrainKeys/GrantCrateKeys must EnsureItemKeys"
)
assert(
	string.find(adminSrc, "profile.Items.Essence +=", 1, true) == nil,
	"GrantItemEssence must not raw-index Items.Essence"
)
assert(
	string.find(progressionSrc, "ProfileBagMath.EnsureStats", 1, true) ~= nil,
	"Progression must delegate EnsureStats to ProfileBagMath"
)
print("[INFO] [TEST] wave14 Admin/Progression ProfileBagMath grant guards passed")
