--!strict
-- Pure-module extract guards: AdminGrantMath + ContinuumDomainMath + service
-- residual markers on DataService / ProgressionService / AdminService.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local AdminGrantMath = require("../src/Server/AstralForge/Modules/AdminGrantMath")
local ContinuumDomainMath = require("../src/Server/AstralForge/Modules/ContinuumDomainMath")

------------------------------------------------------------------------
-- AdminGrantMath
------------------------------------------------------------------------
assert(AdminGrantMath.Finite(3) == true, "finite number")
assert(AdminGrantMath.Finite(math.huge) == false, "reject +inf")
assert(AdminGrantMath.Finite("3") == false, "reject string")
assert(AdminGrantMath.BoundedAmount(12, nil, 100) == 12, "amount ok")
assert(AdminGrantMath.BoundedAmount("7", nil, 100) == 7, "string amount")
assert(AdminGrantMath.BoundedAmount(nil, 5, 100) == 5, "fallback")
assert(AdminGrantMath.BoundedAmount(0, nil, 100) == nil, "zero rejected")
assert(AdminGrantMath.BoundedAmount(-2, nil, 100) == nil, "negative rejected")
assert(AdminGrantMath.BoundedAmount(1e100, nil, 50) == 50, "clamps to max")
assert(AdminGrantMath.BoundedAmount(math.huge, nil, 50) == nil, "inf amount rejected")
assert(AdminGrantMath.CleanText("  hi\nthere  ", 8) == "hi there", "clean+cap")
assert(AdminGrantMath.CleanText(nil, 10) == "", "non-string → empty")
assert(AdminGrantMath.CommandDanger({ Category = "Economy" }) == "quick", "economy quick")
assert(AdminGrantMath.CommandDanger({ Category = "Moderation" }) == "arm", "mod arm")
assert(AdminGrantMath.CommandDanger({ Danger = "critical", Category = "Troll" }) == "critical", "explicit Danger")
assert(AdminGrantMath.CommandDanger(nil) == "quick", "nil → quick")
assert(
	AdminGrantMath.PlayerFacingReason("Kick", "Custom note", nil) == "Custom note",
	"player-facing keeps custom"
)
assert(
	AdminGrantMath.PlayerFacingReason("ServerBan", "Playtest grant", nil)
		== "You are banned from this Astral Forge server.",
	"audit-only ServerBan fallback"
)
assert(
	AdminGrantMath.PlayerFacingReason("GlobalBan", "Bug recovery", nil) == "You are banned from Astral Forge.",
	"audit-only GlobalBan fallback"
)
assert(
	AdminGrantMath.PlayerFacingReason("Kick", "Owner gameplay administration", nil)
		== "You were kicked from this Astral Forge server by an administrator.",
	"audit-only kick fallback"
)
assert(AdminGrantMath.AUDIT_ONLY_REASONS["Trade settle recovery"] == true, "audit reason table")

------------------------------------------------------------------------
-- ContinuumDomainMath (RunQuick endless economy envelope parity)
------------------------------------------------------------------------
local continuum = {
	BaseFluxCost = 1000,
	FluxCostScale = 1.15,
	BaseStardustCost = 10,
	StardustCostScale = 1.1,
}
local domain = {
	BaseRequiredRebirths = 1,
	RebirthsPerRank = 2,
	BaseRequiredCores = 5,
	CoreRequirementScale = 1.2,
	BaseEssenceReward = 3,
	EssencePerRank = 1,
	BaseStardustReward = 20,
	StardustPerRank = 4,
}
local prevFlux: any = 0
local prevDust: any = 0
for _, rank in { 0, 1, 10, 100 } do
	local flux, dust = ContinuumDomainMath.ContinuumCosts(OmegaMath, continuum, rank)
	assert(OmegaMath.Gte(flux, prevFlux) and OmegaMath.Gte(dust, prevDust), "continuum must not regress")
	prevFlux = flux
	prevDust = dust
	local rebirths, cores = ContinuumDomainMath.DomainRequirements(OmegaMath, domain, rank)
	local essence, domainDust = ContinuumDomainMath.DomainRewards(domain, rank)
	assert(type(rebirths) == "number" and type(cores) == "number", "domain requirements numeric")
	assert(type(essence) == "number" and type(domainDust) == "number", "domain rewards numeric")
	assert(rebirths == domain.BaseRequiredRebirths + rank * domain.RebirthsPerRank, "rebirths formula")
	assert(essence == domain.BaseEssenceReward + rank * domain.EssencePerRank, "essence formula")
end

------------------------------------------------------------------------
-- Service residual wiring markers
------------------------------------------------------------------------
local adminSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(adminSrc, "AdminGrantMath.BoundedAmount", 1, true), "Admin must delegate BoundedAmount")
assert(string.find(adminSrc, "AdminGrantMath.CleanText", 1, true), "Admin must delegate CleanText")
assert(string.find(adminSrc, "AdminGrantMath.CommandDanger", 1, true), "Admin must delegate CommandDanger")
assert(string.find(adminSrc, "AdminGrantMath.PlayerFacingReason", 1, true), "Admin must delegate PlayerFacingReason")
assert(string.find(adminSrc, "AdminGrantMath.AUDIT_ONLY_REASONS", 1, true), "Admin AUDIT_ONLY_REASONS residual")
assert(
	string.find(adminSrc, "Stats.AnomalyStabilizations", 1, true)
		or string.find(adminSrc, 'BumpStat(profile, "AnomalyStabilizations"', 1, true),
	"Admin GrantAnomalyStabilizations must sync Stats"
)
assert(string.find(adminSrc, "Zone = profile.Zone", 1, true), "Admin online Zone watermark residual")
assert(string.find(adminSrc, "GrantDomainEssence", 1, true), "Admin GrantDomainEssence residual")
assert(
	string.find(adminSrc, "profile.Continuum.Rank", 1, true)
		or string.find(adminSrc, "EnsureContinuum", 1, true),
	"Admin Continuum.Rank residual"
)
assert(
	string.find(adminSrc, "profile.Domain.Essence", 1, true)
		or string.find(adminSrc, "EnsureDomain", 1, true),
	"Admin Domain.Essence residual"
)
assert(string.find(adminSrc, "ProfileBagMath.EnsureAnomaly", 1, true), "Admin EnsureAnomaly residual")
assert(string.find(adminSrc, "ProfileBagMath.EnsureBoostInventory", 1, true), "Admin EnsureBoostInventory residual")
assert(string.find(adminSrc, "WheelMath.Ensure", 1, true), "Admin WheelMath.Ensure residual")
assert(string.find(adminSrc, "CommandMath.Ensure", 1, true), "Admin CommandMath.Ensure residual")
assert(string.find(adminSrc, "ForgeEchoMath.Ensure", 1, true), "Admin ForgeEchoMath.Ensure residual")
assert(string.find(adminSrc, "ProfileBagMath.EnsureFlags", 1, true), "Admin EnsureFlags residual")
assert(string.find(adminSrc, "ProfileBagMath.BumpStat", 1, true), "Admin BumpStat residual")
assert(
	not string.find(adminSrc, "if profile.ForgeEchoes then profile.ForgeEchoes.Charge", 1, true),
	"Admin GrantEchoCharge must not silent-noop"
)
assert(
	not string.find(adminSrc, "if profile.Command and profile.Command.Crew then", 1, true),
	"Admin MaxCrew must Ensure before Crew"
)

assert(string.find(dataSrc, "CommandMath.Ensure", 1, true), "DataService must Ensure Command")
assert(string.find(dataSrc, "LabOrderMath.Ensure", 1, true), "DataService must Ensure Lab")
assert(string.find(dataSrc, "ForgeEchoMath.Ensure", 1, true), "DataService ForgeEchoMath.Ensure residual")
assert(string.find(dataSrc, "function DataService:IsBusy", 1, true), "DataService IsBusy residual")
assert(string.find(dataSrc, "profile.Continuum", 1, true), "DataService Continuum sanitize residual")
assert(string.find(dataSrc, "profile.Domain", 1, true), "DataService Domain sanitize residual")
assert(string.find(dataSrc, "ProfileIntegrity.EnsureEnvelope", 1, true), "DataService ProfileIntegrity envelope residual")
assert(string.find(dataSrc, "LabOrderMath.NormalizeRouting", 1, true), "DataService Lab routing residual")
assert(string.find(dataSrc, "TotalRebirthsSpent", 1, true), "DataService Domain TotalRebirthsSpent residual")
assert(string.find(dataSrc, "profile.ForgePath", 1, true), "DataService ForgePath sanitize residual")
assert(string.find(dataSrc, "profile.Anomaly", 1, true), "DataService Anomaly sanitize residual")

assert(string.find(dataSrc, "ProfileBagMath.EnsureItems", 1, true), "DataService EnsureItems residual")
assert(string.find(dataSrc, "ProfileBagMath.EnsureDomain", 1, true), "DataService EnsureDomain residual")
assert(string.find(dataSrc, "ProfileBagMath.EnsureContinuum", 1, true), "DataService EnsureContinuum residual")
assert(string.find(dataSrc, "ProfileBagMath.EnsureAnomaly", 1, true), "DataService EnsureAnomaly residual")
assert(string.find(fs.readFile("src/Server/AstralForge/Services/AnomalyService.luau"), "AnomalyOpsMath.ChargeTarget", 1, true), "AnomalyService ChargeTarget residual")
assert(string.find(fs.readFile("src/Server/AstralForge/Services/AnomalyService.luau"), "ProfileBagMath.EnsureAnomaly", 1, true), "AnomalyService EnsureAnomaly residual")
assert(
	string.find(fs.readFile("src/Server/AstralForge/Services/ConvergenceService.luau"), "ConvergenceOpsMath.EnsureEventProfile", 1, true),
	"ConvergenceService EnsureEventProfile residual"
)
assert(
	string.find(fs.readFile("src/Server/AstralForge/Services/ConvergenceService.luau"), "ConvergenceOpsMath.EnsureRewardBags", 1, true),
	"ConvergenceService EnsureRewardBags residual"
)
assert(
	string.find(fs.readFile("src/Server/AstralForge/Services/GuildService.luau"), "GuildGoalMath.EnsureGoal", 1, true),
	"GuildService EnsureGoal residual"
)
assert(
	string.find(fs.readFile("src/Server/AstralForge/Services/GuildService.luau"), "GuildGoalMath.CanClaimGoal", 1, true),
	"GuildService CanClaimGoal residual"
)

assert(string.find(progressionSrc, "CommandMath.Ensure", 1, true), "Progression must Ensure Command")
assert(string.find(progressionSrc, "ensureStats", 1, true), "Progression Stats residual")
assert(string.find(progressionSrc, "ProgressionOpsMath.AchievementProgress", 1, true), "Progression AchievementProgress residual")
local progressionOpsSrc = fs.readFile("src/Server/AstralForge/Modules/ProgressionOpsMath.luau")
assert(string.find(progressionOpsSrc, "TotalRebirthsSpent", 1, true), "Progression achievement residual")
assert(string.find(progressionSrc, "WheelMath.Ensure", 1, true), "Progression Wheel residual")
assert(string.find(progressionSrc, "EnsureQuests", 1, true), "Progression EnsureQuests residual")
assert(string.find(progressionSrc, "EnsureTimedRewards", 1, true), "Progression EnsureTimedRewards residual")
assert(string.find(progressionSrc, "ForgePathClaim.Ensure", 1, true), "Progression ForgePath residual")
assert(string.find(progressionOpsSrc, "AnomalyStabilizations", 1, true), "Progression AnomalyStabilizations residual")
assert(string.find(progressionSrc, "ProfileBagMath.EnsureBoostInventory", 1, true), "Progression BoostInventory residual")
assert(string.find(progressionSrc, "ProfileBagMath.EnsureDomain", 1, true), "Progression EnsureDomain residual")
assert(string.find(progressionSrc, "ProfileBagMath.EnsureDaily", 1, true), "Progression EnsureDaily residual")
assert(string.find(progressionSrc, "ProfileBagMath.BumpStat", 1, true), "Progression BumpStat residual")

assert(string.find(progressionSrc, "ProgressionOpsMath.WeeklyValue", 1, true), "Progression WeeklyValue residual")
assert(string.find(progressionSrc, "ProgressionOpsMath.CommanderReward", 1, true), "Progression CommanderReward residual")
assert(string.find(progressionSrc, "ProgressionOpsMath.TitleUnlocked", 1, true), "Progression TitleUnlocked residual")
assert(string.find(progressionSrc, "ProgressionOpsMath.FindById", 1, true), "Progression FindById residual")

assert(string.find(economySrc, "ContinuumDomainMath.ContinuumCosts", 1, true), "Economy must delegate ContinuumCosts")
assert(string.find(economySrc, "ContinuumDomainMath.DomainRequirements", 1, true), "Economy must delegate DomainRequirements")
assert(string.find(economySrc, "ContinuumDomainMath.DomainRewards", 1, true), "Economy must delegate DomainRewards")
assert(string.find(economySrc, "RebirthGate.PrestigeReward", 1, true), "Economy PrestigeReward must stay pure-delegated")
assert(string.find(economySrc, "ContinuumDomainMath.ContinuumEffects", 1, true), "Economy ContinuumEffects residual")
assert(string.find(economySrc, "ForgePathClaim.Effect", 1, true), "Economy ForgePathClaim.Effect residual")
assert(string.find(economySrc, "RebirthGate.NextPrestigeTarget", 1, true), "Economy NextPrestigeTarget residual")
assert(string.find(economySrc, "EconomyEnvelopeMath.OfflineHours", 1, true), "Economy OfflineHours residual")

assert(string.find(dataSrc, "ProfileBagMath.EnsureAutoSalvage", 1, true), "DataService EnsureAutoSalvage residual")
assert(string.find(dataSrc, "WheelMath.Ensure", 1, true) or string.find(dataSrc, 'type(profile.Wheel) ~= "table"', 1, true), "DataService Wheel residual")
assert(string.find(adminSrc, "ProfileBagMath.EnsureActiveBoost", 1, true), "Admin EnsureActiveBoost residual")
assert(string.find(adminSrc, "ProfileBagMath.EnsureContinuum", 1, true), "Admin EnsureContinuum residual")
assert(string.find(adminSrc, "ProfileBagMath.EnsureItemKeys", 1, true), "Admin EnsureItemKeys residual")
assert(string.find(adminSrc, "ProfileBagMath.EnsureDaily", 1, true), "Admin EnsureDaily residual")
assert(string.find(progressionSrc, "ProfileBagMath.EnsureItemKeys", 1, true), "Progression EnsureItemKeys residual")
assert(string.find(progressionSrc, "ProfileBagMath.EnsureQuests", 1, true) or string.find(progressionSrc, "EnsureQuests", 1, true), "Progression EnsureQuests residual")
assert(string.find(progressionSrc, "ForgePathClaim.Ensure", 1, true), "Progression ForgePathClaim residual")

local firewallSrc = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(string.find(firewallSrc, "BulkSalvageItems", 1, true), "RemoteFirewall BulkSalvageItems residual")
assert(string.find(firewallSrc, "SetItemAutoSalvage", 1, true), "RemoteFirewall SetItemAutoSalvage residual")
assert(string.find(firewallSrc, "local function cooldownKey", 1, true), "RemoteFirewall cooldownKey residual")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
for _, body in { adminSrc, dataSrc, progressionSrc, economySrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] AdminGrantMath + ContinuumDomainMath + service residual gates passed")
