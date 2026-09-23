--!strict
-- Offline port of ReleaseReadiness.RunQuick pure checks that do not need Studio:
--   1) Economy cost envelope (machine/research monotonic ScaledCost + Continuum/Domain)
--   2) ProfileIntegrity recovery markers (seal → corrupt → VerifyAndRecover)
-- Studio-only remainder (50k soak / RunSoak) stays behind ReleaseReadiness.RunQuick.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local UpgradeCostReason = require("../src/Server/AstralForge/Modules/UpgradeCostReason")
local ProfileIntegrity = require("../src/Server/AstralForge/Services/ProfileIntegrity")()

local cfg = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local releaseSrc = fs.readFile("src/Server/AstralForge/ReleaseReadiness.luau")
local integritySrc = fs.readFile("src/Server/AstralForge/Services/ProfileIntegrity.luau")

assert(not string.find(cfg, "vendor/", 1, true), "GameConfig must not reference vendor/")
assert(not string.find(cfg, "Packages/", 1, true), "GameConfig must not reference Packages/")
assert(not string.find(economySrc, "vendor/", 1, true), "Economy must not reference vendor/")
assert(not string.find(integritySrc, "Packages/", 1, true), "ProfileIntegrity must not reference Packages/")

local dv = tonumber(string.match(cfg, "DataVersion%s*=%s*(%d+)"))
assert(dv ~= nil and dv == 21, "DataVersion must remain 21")
local badges = string.match(cfg, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

-- RunQuick must keep naming the pure checks we mirror here.
assert(string.find(releaseSrc, 'passed("endless economy envelope")', 1, true), "RunQuick must still pass endless economy envelope")
assert(string.find(releaseSrc, 'passed("profile corruption recovery")', 1, true), "RunQuick must still pass profile corruption recovery")
assert(string.find(releaseSrc, "Economy.MachineCost", 1, true), "RunQuick must exercise Economy.MachineCost")
assert(string.find(releaseSrc, "Economy.ResearchCost", 1, true), "RunQuick must exercise Economy.ResearchCost")
assert(string.find(releaseSrc, "Economy.ContinuumCosts", 1, true), "RunQuick must exercise ContinuumCosts")
assert(string.find(releaseSrc, "ProfileIntegrity.VerifyAndRecover", 1, true), "RunQuick must VerifyAndRecover")
assert(string.find(economySrc, "function Economy.MachineCost", 1, true), "Economy.MachineCost missing")
assert(string.find(economySrc, "UpgradeCostReason.LevelCost", 1, true), "MachineCost must delegate UpgradeCostReason.LevelCost")

local function extractSection(src, startNeedle)
	local startPos = string.find(src, startNeedle, 1, true)
	assert(startPos, "missing section " .. startNeedle)
	local bodyStart = string.find(src, "{", startPos, true)
	local depth = 0
	local i = bodyStart
	while i <= #src do
		local ch = string.sub(src, i, i)
		if ch == "{" then
			depth += 1
		elseif ch == "}" then
			depth -= 1
			if depth == 0 then
				return string.sub(src, bodyStart + 1, i - 1)
			end
		end
		i += 1
	end
	error("unclosed section " .. startNeedle)
end

local function collectCostDefs(body)
	local defs = {}
	-- Match Id / BaseCost / CostScale within the same table entry window.
	for block in string.gmatch(body, "%{([%s%S]-)%},?") do
		local id = string.match(block, 'Id%s*=%s*"([^"]+)"')
		local baseText = string.match(block, "BaseCost%s*=%s*([%d_]+)")
		local scale = tonumber(string.match(block, "CostScale%s*=%s*([%d%.]+)"))
		local base = if baseText then tonumber((string.gsub(baseText, "_", ""))) else nil
		if id and base and scale then
			table.insert(defs, {
				Id = id,
				BaseCost = base,
				CostScale = scale,
			})
		end
	end
	return defs
end

local function assertMonotone(label, defs)
	assert(#defs > 0, label .. " cost defs empty")
	local levels = { 0, 1, 10, 100, 1000 }
	for _, def in defs do
		local previous = -1
		for _, level in levels do
			local cost = OmegaMath.ToNumber(UpgradeCostReason.LevelCost(OmegaMath, def, level))
			assert(cost == cost and cost ~= math.huge and cost ~= -math.huge, label .. " " .. def.Id .. " cost not finite at " .. tostring(level))
			assert(cost >= previous, label .. " " .. def.Id .. " cost regressed at level " .. tostring(level))
			previous = cost
		end
	end
end

local machines = collectCostDefs(extractSection(cfg, "\n\tMachines = {"))
local research = collectCostDefs(extractSection(cfg, "\n\tResearch = {"))
assertMonotone("machines", machines)
assertMonotone("research", research)

-- Continuum / Domain cost envelopes (mirror Economy formulas against GameConfig knobs).
local function parseNumber(text: string?): number?
	if text == nil then
		return nil
	end
	return tonumber((string.gsub(text, "_", "")))
end

local continuumBody = extractSection(cfg, "\n\tContinuum = {")
local domainBody = extractSection(cfg, "\n\tDomain = {")
local baseFlux = parseNumber(string.match(continuumBody, "BaseFluxCost%s*=%s*([%d_]+)"))
local fluxScale = parseNumber(string.match(continuumBody, "FluxCostScale%s*=%s*([%d%.]+)"))
local baseDust = parseNumber(string.match(continuumBody, "BaseStardustCost%s*=%s*([%d_]+)"))
local dustScale = parseNumber(string.match(continuumBody, "StardustCostScale%s*=%s*([%d%.]+)"))
assert(baseFlux and fluxScale and baseDust and dustScale, "Continuum cost knobs missing")

local baseRebirths = parseNumber(string.match(domainBody, "BaseRequiredRebirths%s*=%s*(%d+)"))
local rebirthsPer = parseNumber(string.match(domainBody, "RebirthsPerRank%s*=%s*(%d+)"))
local baseCores = parseNumber(string.match(domainBody, "BaseRequiredCores%s*=%s*([%d_]+)"))
local coreScale = parseNumber(string.match(domainBody, "CoreRequirementScale%s*=%s*([%d%.]+)"))
local baseEssence = parseNumber(string.match(domainBody, "BaseEssenceReward%s*=%s*(%d+)"))
local essencePer = parseNumber(string.match(domainBody, "EssencePerRank%s*=%s*(%d+)"))
local baseDomainDust = parseNumber(string.match(domainBody, "BaseStardustReward%s*=%s*([%d_]+)"))
local domainDustPer = parseNumber(string.match(domainBody, "StardustPerRank%s*=%s*(%d+)"))
assert(baseRebirths and rebirthsPer and baseCores and coreScale, "Domain requirement knobs missing")
assert(baseEssence and essencePer and baseDomainDust and domainDustPer, "Domain reward knobs missing")

local MAX_VALUE = 1e308
local function finiteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and math.abs(value) <= MAX_VALUE
end

local function isPersist(value: any): boolean
	if finiteNumber(value) then
		return true
	end
	-- OmegaMath persists oversized magnitudes as scientific strings.
	return type(value) == "string" and string.find(value, "^%-?%d") ~= nil
end

local prevFlux: any = 0
local prevDust: any = 0
for _, rank in { 0, 1, 10, 100, 10_000, 9_000_000_000_000_000 } do
	local flux = OmegaMath.Floor(OmegaMath.Mul(baseFlux, OmegaMath.BoundedPower(fluxScale, rank)))
	local dust = OmegaMath.Floor(OmegaMath.Mul(baseDust, OmegaMath.BoundedPower(dustScale, rank)))
	assert(isPersist(flux) and isPersist(dust), "Continuum cost overflow at rank " .. tostring(rank))
	assert(OmegaMath.Gte(flux, prevFlux) and OmegaMath.Gte(dust, prevDust), "Continuum costs must not regress")
	prevFlux = flux
	prevDust = dust

	local rebirths = math.floor(math.min(MAX_VALUE, baseRebirths + rank * rebirthsPer))
	local cores = OmegaMath.ScaledCost(baseCores, coreScale, rank)
	local essence = math.floor(math.min(MAX_VALUE, baseEssence + rank * essencePer))
	local domainDust = math.floor(math.min(MAX_VALUE, baseDomainDust + rank * domainDustPer))
	assert(finiteNumber(rebirths) and isPersist(cores), "Domain requirement overflow at rank " .. tostring(rank))
	assert(finiteNumber(essence) and finiteNumber(domainDust), "Domain reward overflow at rank " .. tostring(rank))
end

------------------------------------------------------------------------
-- ProfileIntegrity recovery (RunQuick "profile corruption recovery")
------------------------------------------------------------------------
assert(string.find(integritySrc, "function ProfileIntegrity.Record", 1, true), "ProfileIntegrity.Record missing")
assert(string.find(integritySrc, "function ProfileIntegrity.Seal", 1, true), "ProfileIntegrity.Seal missing")
assert(string.find(integritySrc, "function ProfileIntegrity.VerifyAndRecover", 1, true), "ProfileIntegrity.VerifyAndRecover missing")
assert(string.find(integritySrc, "no valid recovery entry", 1, true), "recovery marker missing")
assert(string.find(integritySrc, "JOURNAL_LIMIT", 1, true), "JOURNAL_LIMIT missing")

local profile = {
	Cash = 1250,
	Vault = 10,
	Cores = 2,
	Stardust = 5,
	Rebirths = 1,
	RunCash = 40,
	LifetimeCash = 2000,
	Zone = 1,
	CurrentZone = 1,
	Meta = { Revision = 0 },
}
ProfileIntegrity.Record(profile, "release-test", 0)
ProfileIntegrity.Seal(profile)
local expectedCash = profile.Cash
profile.Cash = math.huge
local healthy, message = ProfileIntegrity.VerifyAndRecover(profile)
assert(not healthy, "integrity journal must report recovery (not healthy)")
assert(profile.Cash == expectedCash, "integrity journal did not recover last known-good Cash")
assert(type(message) == "string" and string.find(message, "recovered", 1, true), "recovery message missing")

local malformed = {
	Cash = 0,
	Vault = 0,
	Cores = 0,
	Stardust = 0,
	Rebirths = 0,
	RunCash = 0,
	LifetimeCash = 0,
	Meta = { Revision = 0 },
	UnknownMigrationBranch = {},
}
local branch = malformed.UnknownMigrationBranch
for _ = 1, 24 do
	local child = {}
	branch.Next = child
	branch = child
end
local verifyOk, malformedHealthy = pcall(ProfileIntegrity.VerifyAndRecover, malformed)
assert(verifyOk, "malformed VerifyAndRecover threw: " .. tostring(malformedHealthy))
assert(not malformedHealthy, "malformed profile verification escaped its recovery boundary")

print(string.format(
	"[INFO] [TEST] runquick pure checks passed | machines=%d research=%d continuum+domain ok | integrity recovered",
	#machines,
	#research
))
print("[INFO] [TEST] Studio-only remainder: ReleaseReadiness.RunQuick 50k soak + RunSoak (not claimed by npm test)")
