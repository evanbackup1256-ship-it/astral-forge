-- Run with: lune run scripts/verify_release_readiness.luau
-- Offline subset of src/Server/AstralForge/ReleaseReadiness.luau quickChecks that can
-- run under Lune without Studio / Roblox services.
--
-- STUDIO-ONLY (not wired here — still required before publish):
--   ReleaseReadiness.RunQuick()  — Economy cost envelope soak + ProfileIntegrity recovery
--   ReleaseReadiness.RunSoak()   — long Studio-only economy soak (IsStudio gated)
--   Live profile load/save with copied v4.12 + current fixtures (never live player data)
-- See README "Checks" for the Studio Device Simulator / Controller Emulator gate.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local releaseSrc = fs.readFile("src/Server/AstralForge/ReleaseReadiness.luau")
assert(not string.find(releaseSrc, "vendor/", 1, true), "ReleaseReadiness must not reference vendor/")
assert(not string.find(releaseSrc, "Packages/", 1, true), "ReleaseReadiness must not reference Packages/")
assert(string.find(releaseSrc, "function ReleaseReadiness.RunQuick", 1, true), "RunQuick must remain Studio entry")
assert(string.find(releaseSrc, "function ReleaseReadiness.RunSoak", 1, true), "RunSoak must remain Studio entry")
assert(string.find(releaseSrc, "RunService:IsStudio()", 1, true), "RunSoak must stay Studio-only")

local cfg = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(not string.find(cfg, "vendor/", 1, true), "GameConfig must not reference vendor/")
assert(not string.find(cfg, "Packages/", 1, true), "GameConfig must not reference Packages/")

local dv = tonumber(string.match(cfg, "DataVersion%s*=%s*(%d+)"))
assert(dv ~= nil and dv == 21, "DataVersion must remain 21")
local version = string.match(cfg, 'Version%s*=%s*"([^"]+)"')
assert(version ~= nil and version ~= "", "game version is missing")

local badges = string.match(cfg, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

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

-- Bare Id = "..." (not CrateId / PreviousId suffixes) + numeric Id = N for zones.
local function collectStringIds(body)
	local ids = {}
	for prefix, id in string.gmatch(body, "([^%w_])Id = \"([^\"]+)\"") do
		table.insert(ids, id)
	end
	return ids
end

local function collectNumericIds(body)
	local ids = {}
	for prefix, id in string.gmatch(body, "([^%w_])Id = (%d+)") do
		table.insert(ids, tonumber(id))
	end
	return ids
end

local function assertUnique(label, ids)
	local seen = {}
	for _, id in ids do
		local key = tostring(id)
		assert(not seen[key], label .. " duplicate Id " .. key)
		seen[key] = true
	end
	assert(#ids > 0, label .. " empty")
	return seen
end

local passed = {}
local function mark(name)
	table.insert(passed, name)
end

mark("version and data schema")

local function countKeys(map)
	local n = 0
	for _ in pairs(map) do
		n += 1
	end
	return n
end

local machineIds = assertUnique("machines", collectStringIds(extractSection(cfg, "\n\tMachines = {")))
local researchIds = assertUnique("research", collectStringIds(extractSection(cfg, "\n\tResearch = {")))
-- GridUpgrades is lazy-generated at runtime (empty table + attachLazyLoader); offline gate
-- only asserts the static empty seed + generator attach stay present.
assert(string.find(cfg, "GridUpgrades = {}", 1, true), "GridUpgrades static seed missing")
assert(string.find(cfg, "generateGridUpgrades", 1, true), "GridUpgrades generator missing")
local zoneIds = assertUnique("worlds", collectNumericIds(extractSection(cfg, "\n\tZones = {")))
assert(countKeys(zoneIds) >= 8, "zones must keep at least 8 worlds, got " .. tostring(countKeys(zoneIds)))

local itemsBody = extractSection(cfg, "\n\tItems = {")
local defIds = assertUnique("relic definitions", collectStringIds(extractSection(itemsBody, "Definitions = {")))
local crateIds = assertUnique("crates", collectStringIds(extractSection(itemsBody, "Crates = {")))
local shopIds = assertUnique("shop offers", collectStringIds(extractSection(itemsBody, "ShopOffers = {")))

local opsBody = extractSection(cfg, "\n\tOperations = {")
local artifactIds = assertUnique("artifacts", collectStringIds(extractSection(opsBody, "Artifacts = {")))
local expeditionIds = assertUnique("expeditions", collectStringIds(extractSection(opsBody, "Expeditions = {")))
local weeklyIds = assertUnique("weekly directives", collectStringIds(extractSection(opsBody, "WeeklyDirectives = {")))
mark("configuration identity")

-- PreviousId / ArtifactId / CrateId reference integrity (ReleaseReadiness.quickChecks subset).
for id in string.gmatch(extractSection(cfg, "\n\tMachines = {"), 'PreviousId = "([^"]+)"') do
	assert(machineIds[id], "machine PreviousId references missing " .. id)
end
for id in string.gmatch(extractSection(cfg, "\n\tResearch = {"), 'PreviousId = "([^"]+)"') do
	assert(researchIds[id], "research PreviousId references missing " .. id)
end
for id in string.gmatch(extractSection(opsBody, "Expeditions = {"), 'ArtifactId = "([^"]+)"') do
	assert(artifactIds[id], "expedition ArtifactId references missing " .. id)
end
for id in string.gmatch(extractSection(itemsBody, "ShopOffers = {"), 'CrateId = "([^"]+)"') do
	assert(crateIds[id], "shop offer CrateId references missing " .. id)
end

-- Boost keys referenced as Boost = "Id" must exist in Boosts.
local boostBody = extractSection(cfg, "\n\tBoosts = {")
local boostIds = {}
for name in string.gmatch(boostBody, "\n\t\t(%w+) = %{") do
	boostIds[name] = true
end
assert(next(boostIds) ~= nil, "Boosts empty")
for boost in string.gmatch(cfg, 'Boost = "([^"]+)"') do
	assert(boostIds[boost], "reward Boost references missing " .. boost)
end
mark("configuration references")

-- Document Studio-only remainder so npm test never silently pretends soak/integrity ran.
local initSrc = fs.readFile("src/Server/AstralForge/init.server.luau")
assert(string.find(initSrc, "ReleaseReadiness.RunQuick", 1, true) or string.find(initSrc, "ReleaseReadiness.RunSoak", 1, true),
	"init.server must still expose Studio ReleaseReadiness runners")
mark("studio runners still wired")

print(string.format(
	"[INFO] [TEST] release-readiness offline subset passed | checks=%d machines=%d research=%d zones=%d crates=%d artifacts=%d expeditions=%d weekly=%d shop=%d relics=%d",
	#passed,
	countKeys(machineIds),
	countKeys(researchIds),
	countKeys(zoneIds),
	countKeys(crateIds),
	countKeys(artifactIds),
	countKeys(expeditionIds),
	countKeys(weeklyIds),
	countKeys(shopIds),
	countKeys(defIds)
))
print("[INFO] [TEST] Studio-only remainder: ReleaseReadiness.RunQuick/RunSoak + Device Simulator (not claimed by npm test)")
