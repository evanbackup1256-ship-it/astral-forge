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

-- Envelope / identity extras beyond the ReleaseReadiness.quickChecks core four.
local achievementIds = assertUnique("achievements", collectStringIds(extractSection(cfg, "\n\tAchievements = {")))
local mailIds = assertUnique("mail", collectStringIds(extractSection(cfg, "\n\tMail = {")))
local storyIds = assertUnique("story", collectStringIds(extractSection(cfg, "\n\tStory = {")))
assert(countKeys(achievementIds) >= 8, "achievements must keep a release catalog, got " .. tostring(countKeys(achievementIds)))
assert(countKeys(mailIds) >= 4, "mail must keep dock notes, got " .. tostring(countKeys(mailIds)))
assert(countKeys(storyIds) >= 4, "story beats must stay catalogued, got " .. tostring(countKeys(storyIds)))
mark("content envelopes")

local tradingBody = extractSection(cfg, "\n\tTrading = {")
assert(string.find(tradingBody, "DailyTrades", 1, true), "Trading.DailyTrades missing")
assert(string.find(tradingBody, "ConfirmSeconds", 1, true), "Trading.ConfirmSeconds missing")
assert(string.find(tradingBody, "PerTrade", 1, true), "Trading.PerTrade envelope missing")
assert(string.find(tradingBody, "Daily", 1, true), "Trading.Daily envelope missing")
local guildBody = extractSection(cfg, "\n\tGuild = {")
assert(string.find(guildBody, "Upgrades", 1, true), "Guild.Upgrades missing")
assert(string.find(guildBody, "MaxMembers", 1, true) or string.find(guildBody, "MemberCap", 1, true) or string.find(guildBody, "Capacity", 1, true), "Guild member capacity knob missing")
mark("trading and guild envelopes")

local firewallBody = extractSection(cfg, "\n\tRemoteFirewall = {")
assert(string.find(firewallBody, "Overrides", 1, true), "RemoteFirewall.Overrides missing")
assert(string.find(firewallBody, "ActivateBoost", 1, true), "RemoteFirewall must rate-limit ActivateBoost")
assert(string.find(firewallBody, "PulseAnomaly", 1, true), "RemoteFirewall must rate-limit PulseAnomaly")
assert(countKeys(boostIds) >= 8, "Boosts catalog must stay release-sized, got " .. tostring(countKeys(boostIds)))
mark("firewall and boost envelopes")

-- Progression / ops envelopes that release soaks exercise but quickChecks skip.
local continuumBody = extractSection(cfg, "\n\tContinuum = {")
assert(string.find(continuumBody, "BaseFluxCost", 1, true), "Continuum.BaseFluxCost missing")
assert(string.find(continuumBody, "MaxRank", 1, true), "Continuum.MaxRank missing")
assert(string.find(continuumBody, "MilestoneEvery", 1, true), "Continuum.MilestoneEvery missing")
local labBody = extractSection(cfg, "\n\tLab = {")
assert(string.find(labBody, "Orders", 1, true) or string.find(labBody, "Power", 1, true) or string.find(labBody, "Slots", 1, true), "Lab progression knobs missing")
local forgePathBody = extractSection(cfg, "\n\tForgePath = {")
assert(string.find(forgePathBody, "Steps", 1, true) or string.find(forgePathBody, "Tracks", 1, true) or string.find(forgePathBody, "XP", 1, true), "ForgePath envelope missing")
local wheelBody = extractSection(cfg, "\n\tWheel = {")
assert(string.find(wheelBody, "Rewards", 1, true) or string.find(wheelBody, "Segments", 1, true) or string.find(wheelBody, "Cost", 1, true), "Wheel envelope missing")
mark("progression envelopes")

-- Trade settle orchestration extract must stay Lune-wired for host→guest AtomicUpdate.
local settleSrc = fs.readFile("src/Server/AstralForge/Modules/TradeSettle.luau")
assert(string.find(settleSrc, "function TradeSettle.RunHostGuest", 1, true), "TradeSettle.RunHostGuest missing")
assert(string.find(settleSrc, "function TradeSettle.IsCommitOk", 1, true), "TradeSettle.IsCommitOk missing")
assert(not string.find(settleSrc, "vendor/", 1, true), "TradeSettle must not reference vendor/")
assert(not string.find(settleSrc, "Packages/", 1, true), "TradeSettle must not reference Packages/")
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(servicesSrc, "TradeSettle.RunHostGuest", 1, true), "ConfirmTrade must delegate RunHostGuest")
assert(string.find(servicesSrc, "trade-host", 1, true) and string.find(servicesSrc, "trade-guest", 1, true), "host/guest AtomicUpdate labels")
assert(string.find(tradingBody, "InviteSeconds", 1, true), "Trading.InviteSeconds missing")
assert(string.find(tradingBody, "SessionSeconds", 1, true), "Trading.SessionSeconds missing")
assert(string.find(tradingBody, "MaxItems", 1, true), "Trading.MaxItems missing")
mark("trade settle orchestration")

-- Document Studio-only remainder so npm test never silently pretends soak/integrity ran.
local initSrc = fs.readFile("src/Server/AstralForge/init.server.luau")
assert(string.find(initSrc, "ReleaseReadiness.RunQuick", 1, true) or string.find(initSrc, "ReleaseReadiness.RunSoak", 1, true),
	"init.server must still expose Studio ReleaseReadiness runners")
mark("studio runners still wired")

assert(#passed > 7, "release-readiness offline subset must stay beyond checks=7, got " .. tostring(#passed))

print(string.format(
	"[INFO] [TEST] release-readiness offline subset passed | checks=%d machines=%d research=%d zones=%d crates=%d artifacts=%d expeditions=%d weekly=%d shop=%d relics=%d achievements=%d mail=%d story=%d boosts=%d",
	#passed,
	countKeys(machineIds),
	countKeys(researchIds),
	countKeys(zoneIds),
	countKeys(crateIds),
	countKeys(artifactIds),
	countKeys(expeditionIds),
	countKeys(weeklyIds),
	countKeys(shopIds),
	countKeys(defIds),
	countKeys(achievementIds),
	countKeys(mailIds),
	countKeys(storyIds),
	countKeys(boostIds)
))
print("[INFO] [TEST] Studio-only remainder: ReleaseReadiness.RunQuick/RunSoak + Device Simulator (not claimed by npm test)")
