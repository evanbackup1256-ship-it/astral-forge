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
assert(string.find(adminSrc, "Stats.AnomalyStabilizations", 1, true), "Admin GrantAnomalyStabilizations must sync Stats")
assert(string.find(adminSrc, "Zone = profile.Zone", 1, true), "Admin online Zone watermark residual")

assert(string.find(dataSrc, "CommandMath.Ensure", 1, true), "DataService must Ensure Command")
assert(string.find(dataSrc, "LabOrderMath.Ensure", 1, true), "DataService must Ensure Lab")
assert(string.find(dataSrc, "function DataService:IsBusy", 1, true), "DataService IsBusy residual")
assert(string.find(dataSrc, "profile.Continuum", 1, true), "DataService Continuum sanitize residual")
assert(string.find(dataSrc, "profile.Domain", 1, true), "DataService Domain sanitize residual")

assert(string.find(progressionSrc, "CommandMath.Ensure", 1, true), "Progression must Ensure Command")
assert(string.find(progressionSrc, "ensureStats", 1, true), "Progression Stats residual")
assert(string.find(progressionSrc, "TotalRebirthsSpent", 1, true), "Progression achievement residual")
assert(string.find(progressionSrc, "WheelMath.Ensure", 1, true), "Progression Wheel residual")

assert(string.find(economySrc, "ContinuumDomainMath.ContinuumCosts", 1, true), "Economy must delegate ContinuumCosts")
assert(string.find(economySrc, "ContinuumDomainMath.DomainRequirements", 1, true), "Economy must delegate DomainRequirements")
assert(string.find(economySrc, "ContinuumDomainMath.DomainRewards", 1, true), "Economy must delegate DomainRewards")

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
