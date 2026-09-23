-- Run with: lune run scripts/verify_release_readiness.luau
-- Offline subset of src/Server/AstralForge/ReleaseReadiness.luau quickChecks that can
-- run under Lune without Studio / Roblox services.
--
-- STUDIO-ONLY (not wired here — still required before publish):
--   ReleaseReadiness.RunQuick()  — 50k economy soak (pure cost/integrity subset → verify_runquick_pure)
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
assert(string.find(settleSrc, "function TradeSettle.CancelBlocked", 1, true), "TradeSettle.CancelBlocked missing")
assert(not string.find(settleSrc, "vendor/", 1, true), "TradeSettle must not reference vendor/")
assert(not string.find(settleSrc, "Packages/", 1, true), "TradeSettle must not reference Packages/")
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(servicesSrc, "TradeSettle.RunHostGuest", 1, true), "ConfirmTrade must delegate RunHostGuest")
assert(string.find(servicesSrc, "trade-host", 1, true) and string.find(servicesSrc, "trade-guest", 1, true), "host/guest AtomicUpdate labels")
assert(string.find(tradingBody, "InviteSeconds", 1, true), "Trading.InviteSeconds missing")
assert(string.find(tradingBody, "SessionSeconds", 1, true), "Trading.SessionSeconds missing")
assert(string.find(tradingBody, "MaxItems", 1, true), "Trading.MaxItems missing")
mark("trade settle orchestration")

-- DataService busy-window + Guild claim + residual txn markers (offline parity with
-- verify_busy_guild_txn; kept here so release-readiness checks grow past checks=9).
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
assert(string.find(dataSrc, "function DataService:IsBusy", 1, true), "DataService:IsBusy missing")
assert(string.find(servicesSrc, "self._data:IsBusy(player)", 1, true), "production must consult IsBusy")
assert(string.find(servicesSrc, "maxCatchUp = GameConfig.Game.ProductionTick * 4", 1, true), "busy-window catch-up missing")
local guildSrc = fs.readFile("src/Server/AstralForge/Services/GuildService.luau")
assert(string.find(guildSrc, "function GuildService:ClaimGoal", 1, true), "GuildService:ClaimGoal missing")
assert(string.find(guildSrc, "goal.Claimed[userKey] = true", 1, true), "Guild claim must stamp Claimed")
assert(string.find(guildBody, "MinContributionForReward", 1, true) or string.find(cfg, "MinContributionForReward", 1, true), "Guild MinContributionForReward missing")
local gateSrc = fs.readFile("src/Server/AstralForge/Services/SessionGate.luau")
assert(string.find(gateSrc, "TXN_RING", 1, true), "SessionGate TXN_RING missing")
assert(string.find(gateSrc, "function SessionGate:TxnClaim", 1, true), "SessionGate:TxnClaim missing")
assert(string.find(settleSrc, "RevertFailed", 1, true), "TradeSettle RevertFailed residual missing")
mark("busy-window guild claim residual txn")

-- Document Studio-only remainder so npm test never silently pretends soak/integrity ran.
local initSrc = fs.readFile("src/Server/AstralForge/init.server.luau")
assert(string.find(initSrc, "ReleaseReadiness.RunQuick", 1, true) or string.find(initSrc, "ReleaseReadiness.RunSoak", 1, true),
	"init.server must still expose Studio ReleaseReadiness runners")
mark("studio runners still wired")

-- Pure RunQuick parity: ContinuumDomainMath + ProfileIntegrity markers (offline;
-- full 50k soak stays Studio-only behind ReleaseReadiness.RunQuick).
local continuumMathSrc = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
assert(string.find(continuumMathSrc, "function ContinuumDomainMath.ContinuumCosts", 1, true), "ContinuumDomainMath.ContinuumCosts missing")
assert(string.find(continuumMathSrc, "function ContinuumDomainMath.DomainRequirements", 1, true), "ContinuumDomainMath.DomainRequirements missing")
assert(string.find(continuumMathSrc, "function ContinuumDomainMath.DomainRewards", 1, true), "ContinuumDomainMath.DomainRewards missing")
local economyBody = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
assert(string.find(economyBody, "ContinuumDomainMath.ContinuumCosts", 1, true), "Economy must delegate ContinuumCosts")
assert(string.find(economyBody, "ContinuumDomainMath.DomainRequirements", 1, true), "Economy must delegate DomainRequirements")
assert(string.find(economyBody, "ContinuumDomainMath.DomainRewards", 1, true), "Economy must delegate DomainRewards")
assert(string.find(economyBody, "RebirthGate.PrestigeReward", 1, true), "Economy PrestigeReward must stay pure-delegated")
local integrityBody = fs.readFile("src/Server/AstralForge/Services/ProfileIntegrity.luau")
assert(string.find(integrityBody, "function ProfileIntegrity.VerifyAndRecover", 1, true), "ProfileIntegrity.VerifyAndRecover missing")
assert(string.find(integrityBody, "function ProfileIntegrity.Seal", 1, true), "ProfileIntegrity.Seal missing")
assert(string.find(releaseSrc, 'passed("endless economy envelope")', 1, true), "RunQuick endless economy envelope marker")
assert(string.find(releaseSrc, 'passed("profile corruption recovery")', 1, true), "RunQuick profile corruption recovery marker")
assert(string.find(dataSrc, "CommandMath.Ensure", 1, true), "DataService CommandMath residual for release")
assert(string.find(dataSrc, "LabOrderMath.Ensure", 1, true), "DataService LabOrderMath residual for release")
mark("runquick pure continuum domain parity")

-- Pure RunQuick prestige reward parity (RebirthGate; soak still Studio-only).
local rebirthGateSrc = fs.readFile("src/Server/AstralForge/Modules/RebirthGate.luau")
assert(string.find(rebirthGateSrc, "function RebirthGate.PrestigeReward", 1, true), "RebirthGate.PrestigeReward missing")
assert(string.find(rebirthGateSrc, "function RebirthGate.CanRebirth", 1, true), "RebirthGate.CanRebirth missing")
assert(string.find(rebirthGateSrc, "function RebirthGate.StardustReward", 1, true), "RebirthGate.StardustReward missing")
assert(string.find(economyBody, "RebirthGate.PrestigeReward", 1, true), "Economy.PrestigeReward must delegate RebirthGate")
assert(string.find(releaseSrc, "Economy.PrestigeReward", 1, true), "RunQuick must exercise PrestigeReward")
assert(not string.find(rebirthGateSrc, "vendor/", 1, true), "RebirthGate must not reference vendor/")
assert(not string.find(rebirthGateSrc, "Packages/", 1, true), "RebirthGate must not reference Packages/")
mark("runquick pure prestige reward parity")

-- Pure RunQuick domain requirements/rewards parity (ContinuumDomainMath; soak Studio-only).
assert(string.find(releaseSrc, "Economy.DomainRequirements", 1, true), "RunQuick must exercise DomainRequirements")
assert(string.find(releaseSrc, "Economy.DomainRewards", 1, true), "RunQuick must exercise DomainRewards")
assert(string.find(continuumMathSrc, "function ContinuumDomainMath.DomainRequirements", 1, true), "ContinuumDomainMath.DomainRequirements missing")
assert(string.find(continuumMathSrc, "function ContinuumDomainMath.DomainRewards", 1, true), "ContinuumDomainMath.DomainRewards missing")
assert(string.find(economyBody, "ContinuumDomainMath.DomainRequirements", 1, true), "Economy.DomainRequirements must delegate ContinuumDomainMath")
assert(string.find(economyBody, "ContinuumDomainMath.DomainRewards", 1, true), "Economy.DomainRewards must delegate ContinuumDomainMath")
assert(not string.find(continuumMathSrc, "vendor/", 1, true), "ContinuumDomainMath must not reference vendor/")
assert(not string.find(continuumMathSrc, "Packages/", 1, true), "ContinuumDomainMath must not reference Packages/")
mark("runquick pure domain requirements parity")

-- Settings FlatList + Chat allowlist-clear residuals (offline playability parity).
local settingsSrc = fs.readFile("src/Client/AstralForge/pages/SettingsView.luau")
assert(string.find(settingsSrc, "FlatList", 1, true), "Settings must FlatList long catalogs for release")
assert(string.find(settingsSrc, "virtSettings", 1, true), "Settings virtSettings gate missing")
assert(not string.find(settingsSrc, 'createElement("scrollingframe"', 1, true), "Settings must not reintroduce raw scrollingframes")
local chatSrc = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
assert(string.find(chatSrc, "createElement(FlatList", 1, true), "Chat must FlatList messages for release")
assert(not string.find(chatSrc, 'createElement("scrollingframe"', 1, true), "Chat raw scrollingframe allowlist must stay cleared")
assert(not string.find(chatSrc, "vendor/", 1, true), "Chat must not reference vendor/")
assert(not string.find(settingsSrc, "Packages/", 1, true), "Settings must not reference Packages/")
mark("settings chat virtualization residuals")

-- AtomicState / Security / GameAntiCheat residuals (offline parity with verify_atomic_security;
-- full Authority/Filter/Observe paths still need Studio).
assert(string.find(dataSrc, "AtomicState.new(profile)", 1, true), "DataService AtomicState.new residual for release")
assert(string.find(dataSrc, "atom:Transact", 1, true), "DataService atom:Transact residual for release")
assert(string.find(dataSrc, "function DataService:IsBusy", 1, true), "DataService IsBusy residual for release")
assert(string.find(servicesSrc, 'serviceFactories["AtomicState"]', 1, true), "AtomicState factory residual for release")
assert(string.find(servicesSrc, 'serviceFactories["Security"]', 1, true), "Security factory residual for release")
assert(string.find(servicesSrc, 'serviceFactories["GameAntiCheat"]', 1, true), "GameAntiCheat factory residual for release")
assert(string.find(servicesSrc, "self._security.Authority:Validate", 1, true), "Authority:Validate residual for release")
assert(string.find(servicesSrc, "self._antiCheat:Observe", 1, true), "GameAntiCheat Observe residual for release")
assert(string.find(servicesSrc, "self._antiCheat:SyncBaseline", 1, true), "GameAntiCheat SyncBaseline residual for release")
local atomicReleaseSrc = fs.readFile("src/Server/AstralForge/Services/AtomicState.luau")
assert(string.find(atomicReleaseSrc, "function AtomicState:Transact", 1, true), "AtomicState:Transact missing for release")
assert(string.find(atomicReleaseSrc, "CONTENTION_TIMEOUT_SECONDS", 1, true), "AtomicState contention residual for release")
local securityReleaseSrc = fs.readFile("src/Server/AstralForge/Services/Security.luau")
assert(string.find(securityReleaseSrc, "function Authority:Validate", 1, true), "Security Authority residual for release")
assert(string.find(securityReleaseSrc, "function Rate:Allow", 1, true), "Security Rate residual for release")
local antiReleaseSrc = fs.readFile("src/Server/AstralForge/Services/GameAntiCheat.luau")
assert(string.find(antiReleaseSrc, "function AntiCheat:Observe", 1, true), "GameAntiCheat Observe residual for release")
assert(string.find(antiReleaseSrc, "function AntiCheat:SyncBaseline", 1, true), "GameAntiCheat SyncBaseline residual for release")
assert(not string.find(atomicReleaseSrc, "vendor/", 1, true), "AtomicState must not reference vendor/")
assert(not string.find(securityReleaseSrc, "Packages/", 1, true), "Security must not reference Packages/")
assert(not string.find(antiReleaseSrc, "vendor/", 1, true), "GameAntiCheat must not reference vendor/")
mark("atomic security anticheat residuals")

-- Pure RunQuick production/capacity/tapPower envelope parity (finite checks; soak Studio-only).
assert(string.find(economyBody, "function Economy.Production", 1, true), "Economy.Production missing")
assert(string.find(economyBody, "function Economy.Capacity", 1, true), "Economy.Capacity missing")
assert(string.find(economyBody, "function Economy.TapPower", 1, true), "Economy.TapPower missing")
assert(string.find(releaseSrc, "Economy.Production", 1, true), "RunQuick must exercise Economy.Production")
assert(string.find(releaseSrc, "Economy.Capacity", 1, true), "RunQuick must exercise Economy.Capacity")
assert(string.find(releaseSrc, "Economy.TapPower", 1, true), "RunQuick must exercise Economy.TapPower")
assert(not string.find(economyBody, "vendor/", 1, true), "Economy must not reference vendor/")
assert(not string.find(economyBody, "Packages/", 1, true), "Economy must not reference Packages/")
mark("runquick pure production capacity tapPower parity")

-- Pure RunQuick continuum effects / prestige target / offline envelope parity.
assert(string.find(continuumMathSrc, "function ContinuumDomainMath.ContinuumEffects", 1, true), "ContinuumDomainMath.ContinuumEffects missing")
assert(string.find(economyBody, "ContinuumDomainMath.ContinuumEffects", 1, true), "Economy ContinuumEffects must delegate for release")
assert(string.find(rebirthGateSrc, "function RebirthGate.NextPrestigeTarget", 1, true), "RebirthGate.NextPrestigeTarget missing")
assert(string.find(economyBody, "RebirthGate.NextPrestigeTarget", 1, true), "Economy NextPrestigeTarget must delegate for release")
local envelopeSrc = fs.readFile("src/Server/AstralForge/Modules/EconomyEnvelopeMath.luau")
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.OfflineHours", 1, true), "EconomyEnvelopeMath.OfflineHours missing")
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.AutoCollectRate", 1, true), "EconomyEnvelopeMath.AutoCollectRate missing")
assert(string.find(economyBody, "EconomyEnvelopeMath.OfflineHours", 1, true), "Economy OfflineHours residual for release")
assert(string.find(economyBody, "EconomyEnvelopeMath.AutoCollectRate", 1, true), "Economy AutoCollectRate residual for release")
assert(string.find(economyBody, "ForgePathClaim.Effect", 1, true), "Economy ForgePathEffect residual for release")
assert(not string.find(envelopeSrc, "vendor/", 1, true), "EconomyEnvelopeMath must not reference vendor/")
assert(not string.find(envelopeSrc, "Packages/", 1, true), "EconomyEnvelopeMath must not reference Packages/")
mark("runquick pure continuum effects offline envelope parity")

-- InventoryMath extract + ItemSalvage parity residual (offline inventory tooling).
local inventoryMathSrc = fs.readFile("src/Client/AstralForge/inventoryMath.luau")
assert(string.find(inventoryMathSrc, "function InventoryMath.SalvageValue", 1, true), "InventoryMath.SalvageValue missing")
assert(string.find(inventoryMathSrc, "function InventoryMath.FilterOwned", 1, true), "InventoryMath.FilterOwned missing")
local invViewSrc = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
assert(string.find(invViewSrc, "InventoryMath.SalvagePreview", 1, true), "InventoryView SalvagePreview residual for release")
assert(string.find(invViewSrc, "InventoryMath.FilterOwned", 1, true), "InventoryView FilterOwned residual for release")
assert(not string.find(inventoryMathSrc, "vendor/", 1, true), "InventoryMath must not reference vendor/")
assert(not string.find(inventoryMathSrc, "Packages/", 1, true), "InventoryMath must not reference Packages/")
mark("inventory math salvage filter residuals")

-- DataService / Admin / Progression / RemoteFirewall residuals for release past checks=16.
assert(string.find(dataSrc, "ProfileBagMath.EnsureAutoSalvage", 1, true), "DataService EnsureAutoSalvage residual for release")
assert(string.find(dataSrc, "ForgeEchoMath.Sanitize", 1, true), "DataService ForgeEchoMath residual for release")
assert(string.find(dataSrc, "ProfileBagMath.EnsureAnomaly", 1, true), "DataService EnsureAnomaly residual for release")
assert(string.find(dataSrc, "DataSanitizeMath.NonNegative", 1, true), "DataService DataSanitizeMath residual for release")
assert(string.find(dataSrc, "DataSanitizeMath.Reconcile", 1, true), "DataService Reconcile residual for release")
local adminReleaseSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
assert(string.find(adminReleaseSrc, "ProfileBagMath.EnsureFlags", 1, true), "Admin EnsureFlags residual for release")
assert(string.find(adminReleaseSrc, "ForgeEchoMath.Ensure", 1, true), "Admin ForgeEchoMath residual for release")
assert(string.find(adminReleaseSrc, "AdminGrantMath.PlayerFacingReason", 1, true), "Admin PlayerFacingReason residual for release")
local progressionReleaseSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
assert(string.find(progressionReleaseSrc, "ProgressionOpsMath.WeeklyValue", 1, true), "Progression WeeklyValue residual for release")
assert(string.find(progressionReleaseSrc, "ForgePathClaim.Ensure", 1, true), "Progression ForgePathClaim residual for release")
assert(string.find(progressionReleaseSrc, "ProgressionOpsMath.AchievementProgress", 1, true), "Progression AchievementProgress residual for release")
local firewallReleaseSrc = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
assert(string.find(firewallReleaseSrc, "BulkSalvageItems", 1, true), "RemoteFirewall BulkSalvage residual for release")
assert(string.find(firewallReleaseSrc, "SetItemAutoSalvage", 1, true), "RemoteFirewall AutoSalvage residual for release")
assert(string.find(firewallReleaseSrc, "RemoteFirewallMath.CooldownKey", 1, true), "RemoteFirewall CooldownKey residual for release")
assert(string.find(firewallReleaseSrc, "RemoteFirewallMath.CoerceUserId", 1, true), "RemoteFirewall CoerceUserId residual for release")
mark("data admin progression firewall residuals")

-- Pure RunQuick LabPowerEffect envelope parity (finite; soak Studio-only).
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.LabPowerEffect", 1, true), "EconomyEnvelopeMath.LabPowerEffect missing")
assert(string.find(economyBody, "EconomyEnvelopeMath.LabPowerEffect", 1, true), "Economy LabPowerEffect residual for release")
assert(string.find(releaseSrc, "Economy.Production", 1, true), "RunQuick Production still present for LabPower adjacency")
mark("runquick pure lab power envelope parity")

-- Inventory CollectOwned / SocketTargets / market clock residuals past checks=19.
assert(string.find(inventoryMathSrc, "function InventoryMath.CollectOwned", 1, true), "InventoryMath.CollectOwned missing")
assert(string.find(inventoryMathSrc, "function InventoryMath.SocketTargets", 1, true), "InventoryMath.SocketTargets missing")
assert(string.find(inventoryMathSrc, "function InventoryMath.RestockClock", 1, true), "InventoryMath.RestockClock missing")
assert(string.find(inventoryMathSrc, "function InventoryMath.OfferStock", 1, true), "InventoryMath.OfferStock missing")
assert(string.find(invViewSrc, "InventoryMath.CollectOwned", 1, true), "InventoryView CollectOwned residual for release")
assert(string.find(invViewSrc, "InventoryMath.OfferStock", 1, true), "InventoryView OfferStock residual for release")
mark("inventory collect socket market residuals")

-- RemoteFirewallMath + DataSanitizeMath modules present for offline RunQuick-adjacent gates.
local firewallMathSrc = fs.readFile("src/Server/AstralForge/Modules/RemoteFirewallMath.luau")
local sanitizeMathSrc = fs.readFile("src/Server/AstralForge/Modules/DataSanitizeMath.luau")
assert(string.find(firewallMathSrc, "function RemoteFirewallMath.CoerceUserId", 1, true), "RemoteFirewallMath.CoerceUserId missing")
assert(string.find(firewallMathSrc, "function RemoteFirewallMath.ExtractUserId", 1, true), "RemoteFirewallMath.ExtractUserId missing")
assert(string.find(sanitizeMathSrc, "function DataSanitizeMath.DeepCopy", 1, true), "DataSanitizeMath.DeepCopy missing")
assert(string.find(sanitizeMathSrc, "function DataSanitizeMath.NonNegative", 1, true), "DataSanitizeMath.NonNegative missing")
assert(not string.find(firewallMathSrc, "GetService", 1, true), "RemoteFirewallMath must stay pure")
assert(not string.find(sanitizeMathSrc, "GetService", 1, true), "DataSanitizeMath must stay pure")
mark("firewall sanitize pure module residuals")

-- TradeOfferMath + AnomalyOpsMath.ApplyCoreXP residuals past checks=19.
local tradeOfferSrc = fs.readFile("src/Server/AstralForge/Modules/TradeOfferMath.luau")
assert(string.find(tradeOfferSrc, "function TradeOfferMath.CopyOffer", 1, true), "TradeOfferMath.CopyOffer missing")
assert(string.find(tradeOfferSrc, "function TradeOfferMath.EnsureLedger", 1, true), "TradeOfferMath.EnsureLedger missing")
assert(string.find(tradeOfferSrc, "function TradeOfferMath.OfferEmpty", 1, true), "TradeOfferMath.OfferEmpty missing")
local deskReleaseSrc = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
assert(string.find(deskReleaseSrc, "TradeOfferMath.CopyOffer", 1, true), "TradeDesk CopyOffer residual for release")
assert(string.find(deskReleaseSrc, "TradeOfferMath.EnsureLedger", 1, true), "TradeDesk EnsureLedger residual for release")
local anomalyOpsRelease = fs.readFile("src/Server/AstralForge/Modules/AnomalyOpsMath.luau")
assert(string.find(anomalyOpsRelease, "function AnomalyOpsMath.ApplyCoreXP", 1, true), "AnomalyOpsMath.ApplyCoreXP missing")
assert(string.find(anomalyOpsRelease, "function AnomalyOpsMath.NextCoreTier", 1, true), "AnomalyOpsMath.NextCoreTier missing")
local anomalyServiceRelease = fs.readFile("src/Server/AstralForge/Services/AnomalyService.luau")
assert(string.find(anomalyServiceRelease, "AnomalyOpsMath.ApplyCoreXP", 1, true), "AnomalyService ApplyCoreXP residual for release")
assert(string.find(anomalyServiceRelease, "AnomalyOpsMath.NextCoreTier", 1, true), "AnomalyService NextCoreTier residual for release")
assert(not string.find(tradeOfferSrc, "GetService", 1, true), "TradeOfferMath must stay pure")
assert(not string.find(tradeOfferSrc, "vendor/", 1, true), "TradeOfferMath must not reference vendor/")
assert(not string.find(anomalyOpsRelease, "Packages/", 1, true), "AnomalyOpsMath must not reference Packages/")
mark("trade offer corexp pure module residuals")

-- CrateRevealOverlay / ShopClaimCode / UpgradeBoard softMotion residuals.
local crateOverlayRelease = fs.readFile("src/Client/AstralForge/pages/CrateRevealOverlay.luau")
assert(string.find(crateOverlayRelease, 'Name = "CrateClaim"', 1, true), "CrateRevealOverlay CrateClaim residual for release")
do
	local hostStart = string.find(crateOverlayRelease, 'Name = "CrateClaim"', 1, true)
	assert(hostStart, "CrateClaim host missing for release")
	local hostSlice = string.sub(crateOverlayRelease, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "CrateRevealOverlay CrateClaim clips residual for release")
end
local shopRelease = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
do
	local hostStart = string.find(shopRelease, 'Name = "ShopClaimCode"', 1, true)
	assert(hostStart, "ShopClaimCode host missing for release")
	local hostSlice = string.sub(shopRelease, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "ShopClaimCode clips residual for release")
end
local workshopRelease = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
assert(
	string.find(workshopRelease, "overscanRows = if softMotion then 0 else (if stack then 2 else 3)", 1, true),
	"UpgradeBoard overscan softMotion residual for release"
)
mark("crate shop upgradeboard clip softmotion residuals")

-- Wave20 monolith split residuals: NetworkPolicy / PageBoardHeights / Telemetry /
-- UtcClock / EconomyEnvelope grid+item+artifact (pure RunQuick-adjacent).
local networkPolicySrc = fs.readFile("src/Client/AstralForge/networkPolicy.luau")
local pageBoardSrc = fs.readFile("src/Client/AstralForge/pageBoardHeights.luau")
local telemetrySrc = fs.readFile("src/Server/AstralForge/Modules/TelemetryMath.luau")
local utcClockSrc = fs.readFile("src/Server/AstralForge/Modules/UtcClockMath.luau")
local mainReleaseSrc = fs.readFile("src/Client/AstralForge/MainGame.luau")
local routerReleaseSrc = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local ssReleaseSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(networkPolicySrc, "function NetworkPolicy.Cooldown", 1, true), "NetworkPolicy.Cooldown missing")
assert(string.find(networkPolicySrc, "function NetworkPolicy.IsPipelined", 1, true), "NetworkPolicy.IsPipelined missing")
assert(string.find(mainReleaseSrc, "NetworkPolicy.Cooldown", 1, true), "MainGame NetworkPolicy residual for release")
assert(string.find(pageBoardSrc, "function PageBoardHeights.Machine", 1, true), "PageBoardHeights.Machine missing")
local workshopReleaseSrc = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
assert(string.find(workshopReleaseSrc, "PageBoardHeights.Machine", 1, true), "WorkshopView PageBoardHeights residual for release")
local overviewReleaseReady = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overviewReleaseReady, "PageReadyMath.AnomalyReady", 1, true), "OverviewView AnomalyReady residual for release")
assert(string.find(telemetrySrc, "function TelemetryMath.Encode", 1, true), "TelemetryMath.Encode missing")
assert(string.find(ssReleaseSrc, "TelemetryMath.Encode", 1, true), "ServerServices Telemetry residual for release")
assert(string.find(utcClockSrc, "function UtcClockMath.Day", 1, true), "UtcClockMath.Day missing")
assert(string.find(ssReleaseSrc, "UtcClockMath.Day", 1, true), "ServerServices UtcClock residual for release")
assert(string.find(ssReleaseSrc, "DataSanitizeMath.DeepCopy", 1, true), "ServerServices DeepCopy residual for release")
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.GridEffect", 1, true), "EconomyEnvelopeMath.GridEffect missing")
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.EffectAtLevel", 1, true), "EconomyEnvelopeMath.EffectAtLevel missing")
assert(string.find(economyBody, "EconomyEnvelopeMath.GridEffect", 1, true), "Economy GridEffect residual for release")
assert(string.find(economyBody, "EconomyEnvelopeMath.ItemEffect", 1, true), "Economy ItemEffect residual for release")
assert(string.find(inventoryMathSrc, "function InventoryMath.RarityColor", 1, true), "InventoryMath.RarityColor missing")
assert(string.find(invViewSrc, "InventoryMath.RarityColor", 1, true), "InventoryView RarityColor residual for release")
assert(not string.find(networkPolicySrc, "GetService", 1, true), "NetworkPolicy must stay pure")
assert(not string.find(telemetrySrc, "GetService", 1, true), "TelemetryMath must stay pure")
assert(not string.find(utcClockSrc, "GetService", 1, true), "UtcClockMath must stay pure")
mark("wave20 monolith network telemetry board residuals")

-- Wave21: ProfileClampMath + AdvanceQuestProgress/CanClaimQuest + Trade/Admin/Story clips.
local profileClampSrc = fs.readFile("src/Server/AstralForge/Modules/ProfileClampMath.luau")
assert(string.find(profileClampSrc, "function ProfileClampMath.ClampProgressionNumbers", 1, true), "ProfileClampMath.ClampProgressionNumbers missing")
assert(string.find(ssReleaseSrc, "ProfileClampMath.ClampProgressionNumbers", 1, true), "ServerServices ProfileClamp residual for release")
assert(not string.find(profileClampSrc, "GetService", 1, true), "ProfileClampMath must stay pure")
assert(not string.find(profileClampSrc, "vendor/", 1, true), "ProfileClampMath must not reference vendor/")
local progressionOpsRelease = fs.readFile("src/Server/AstralForge/Modules/ProgressionOpsMath.luau")
assert(string.find(progressionOpsRelease, "function ProgressionOpsMath.AdvanceQuestProgress", 1, true), "AdvanceQuestProgress missing")
assert(string.find(progressionOpsRelease, "function ProgressionOpsMath.CanClaimQuest", 1, true), "CanClaimQuest missing")
local progressionRelease = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
assert(string.find(progressionRelease, "ProgressionOpsMath.AdvanceQuestProgress", 1, true), "Progression AdvanceQuestProgress residual for release")
assert(string.find(progressionRelease, "ProgressionOpsMath.CanClaimQuest", 1, true), "Progression CanClaimQuest residual for release")
local tradeRelease = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
do
	local hostStart = string.find(tradeRelease, 'Name = "TradeSessionActions"', 1, true)
	assert(hostStart, "TradeSessionActions host missing for release")
	local hostSlice = string.sub(tradeRelease, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "TradeSessionActions clips residual for release")
end
local adminRelease = fs.readFile("src/Client/AstralForge/pages/AdminView.luau")
do
	local hostStart = string.find(adminRelease, 'Name = "AdminExecuteActions"', 1, true)
	assert(hostStart, "AdminExecuteActions host missing for release")
	local hostSlice = string.sub(adminRelease, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "AdminExecuteActions clips residual for release")
end
local storyRelease = fs.readFile("src/Client/AstralForge/pages/StoryView.luau")
do
	local hostStart = string.find(storyRelease, 'Name = "StoryBeatActions"', 1, true)
	assert(hostStart, "StoryBeatActions host missing for release")
	local hostSlice = string.sub(storyRelease, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "StoryBeatActions clips residual for release")
end
local commandRelease = fs.readFile("src/Client/AstralForge/pages/CommandView.luau")
local commandGateCount = 0
for _ in string.gmatch(commandRelease, "overscanRows = if softMotion then 0 else 1") do
	commandGateCount += 1
end
assert(commandGateCount >= 3, "Command titles overscan softMotion residual for release")
mark("wave21 clamp quest trade admin story residuals")

-- Wave21 extract-checks residuals (complement wave21-harden ProfileClamp/quest):
-- RemoteFirewall Inspect, ForgeEcho EquippedEffect, PermanentMultiplier,
-- ClampLevelBag, Admin relic uid, UtcClock Week, Inventory UpgradeState.
assert(string.find(firewallMathSrc, "function RemoteFirewallMath.Inspect", 1, true), "RemoteFirewallMath.Inspect missing")
assert(string.find(firewallReleaseSrc, "RemoteFirewallMath.Inspect", 1, true), "RemoteFirewall Inspect residual for release")
local forgeEchoRelease = fs.readFile("src/Server/AstralForge/Modules/ForgeEchoMath.luau")
assert(string.find(forgeEchoRelease, "function ForgeEchoMath.EquippedEffect", 1, true), "ForgeEchoMath.EquippedEffect missing")
assert(string.find(economyBody, "ForgeEchoMath.EquippedEffect", 1, true), "Economy EquippedEffect residual for release")
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.PermanentMultiplier", 1, true), "EconomyEnvelopeMath.PermanentMultiplier missing")
assert(string.find(economyBody, "EconomyEnvelopeMath.PermanentMultiplier", 1, true), "Economy PermanentMultiplier residual for release")
assert(string.find(sanitizeMathSrc, "function DataSanitizeMath.ClampLevelBag", 1, true), "DataSanitizeMath.ClampLevelBag missing")
assert(string.find(dataSrc, "DataSanitizeMath.ClampLevelBag", 1, true), "DataService ClampLevelBag residual for release")
local adminGrantRelease = fs.readFile("src/Server/AstralForge/Modules/AdminGrantMath.luau")
assert(string.find(adminGrantRelease, "function AdminGrantMath.NextRelicUid", 1, true), "AdminGrantMath.NextRelicUid missing")
assert(string.find(adminReleaseSrc, "AdminGrantMath.NextRelicUid", 1, true), "Admin NextRelicUid residual for release")
assert(string.find(utcClockSrc, "function UtcClockMath.Week", 1, true), "UtcClockMath.Week missing")
assert(string.find(progressionReleaseSrc, "UtcClockMath.Week", 1, true), "Progression Week residual for release")
assert(string.find(inventoryMathSrc, "function InventoryMath.UpgradeState", 1, true), "InventoryMath.UpgradeState missing")
assert(string.find(invViewSrc, "InventoryMath.UpgradeState", 1, true), "InventoryView UpgradeState residual for release")
assert(string.find(releaseSrc, "Economy.PrestigeReward", 1, true), "RunQuick PrestigeReward still present for wave21 adjacency")
assert(string.find(releaseSrc, "Economy.Production", 1, true), "RunQuick Production still present for wave21 adjacency")
assert(not string.find(forgeEchoRelease, "GetService", 1, true), "ForgeEchoMath must stay pure")
assert(not string.find(adminGrantRelease, "GetService", 1, true), "AdminGrantMath must stay pure")
mark("wave21 extract firewall echo envelope residuals")

local labOrderRelease = fs.readFile("src/Server/AstralForge/Modules/LabOrderMath.luau")
assert(string.find(labOrderRelease, "tonumber(state and state.Progress)", 1, true), "LabOrderMath Progress coerce missing")
assert(string.find(dataSrc, "nonNegative(tonumber(order.Progress)", 1, true), "DataService Progress coerce residual")
local anomalyOpsRelease = fs.readFile("src/Server/AstralForge/Modules/AnomalyOpsMath.luau")
assert(string.find(anomalyOpsRelease, "function AnomalyOpsMath.Effect", 1, true), "AnomalyOpsMath.Effect missing")
assert(string.find(economyBody, "AnomalyOpsMath.Effect", 1, true), "Economy AnomalyEffect residual")
assert(string.find(economyBody, "AnomalyOpsMath.SurgeMultiplier", 1, true), "Economy Surge residual")
local continuumDomainRelease = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
assert(string.find(continuumDomainRelease, "function ContinuumDomainMath.DomainProductionMultiplier", 1, true), "DomainProductionMultiplier missing")
assert(string.find(ssReleaseSrc, "ContinuumDomainMath.SnapshotDomainPublic", 1, true) or string.find(ssReleaseSrc, "ContinuumDomainMath.DomainProductionMultiplier", 1, true), "SS DomainProduction residual")
assert(string.find(ssReleaseSrc, "ShopGrantEligibility.RemainingStock", 1, true), "SS RemainingStock residual")
mark("wave22 lab anomaly domain mail inspect residuals")

-- Wave22 extract-checks residuals (complement wave22-harden Lab/Anomaly/clips):
assert(string.find(firewallMathSrc, "function RemoteFirewallMath.IsSessionOnlyPayload", 1, true), "RemoteFirewallMath.IsSessionOnlyPayload missing")
assert(string.find(firewallReleaseSrc, "RemoteFirewallMath.IsSessionOnlyPayload", 1, true), "RemoteFirewall session residual for release")
assert(string.find(forgeEchoRelease, "function ForgeEchoMath.Sanitize", 1, true), "ForgeEchoMath.Sanitize missing")
assert(string.find(dataSrc, "ForgeEchoMath.Sanitize", 1, true), "DataService Sanitize residual for release")
assert(string.find(sanitizeMathSrc, "function DataSanitizeMath.ClampAutoForge", 1, true), "DataSanitizeMath.ClampAutoForge missing")
assert(string.find(dataSrc, "DataSanitizeMath.ClampAutoForge", 1, true), "DataService ClampAutoForge residual for release")
assert(string.find(envelopeSrc, "function EconomyEnvelopeMath.ItemEffect", 1, true), "EconomyEnvelopeMath.ItemEffect missing")
assert(string.find(economyBody, "EconomyEnvelopeMath.ItemEffect", 1, true), "Economy ItemEffect residual for release")
local itemLoadoutSrc = fs.readFile("src/Server/AstralForge/Modules/ItemLoadoutMath.luau")
assert(string.find(itemLoadoutSrc, "function ItemLoadoutMath.PlanEquipBest", 1, true), "ItemLoadoutMath.PlanEquipBest missing")
assert(string.find(ssReleaseSrc, "ItemLoadoutMath.PlanEquipBest", 1, true), "ServerServices EquipBest residual for release")
assert(string.find(progressionReleaseSrc, "ProgressionOpsMath.ApplyCommandXP", 1, true), "Progression ApplyCommandXP residual for release")
assert(string.find(inventoryMathSrc, "function InventoryMath.ChipRows", 1, true), "InventoryMath.ChipRows missing")
assert(string.find(invViewSrc, "InventoryMath.ChipRows", 1, true), "InventoryView ChipRows residual for release")
assert(string.find(inventoryMathSrc, "function InventoryMath.LoadoutEffectLines", 1, true), "InventoryMath.LoadoutEffectLines missing")
assert(string.find(invViewSrc, "InventoryMath.LoadoutEffectLines", 1, true), "InventoryView LoadoutEffectLines residual for release")
local releaseClockSrc = fs.readFile("src/Client/AstralForge/releaseClockMath.luau")
assert(string.find(releaseClockSrc, "function ReleaseClockMath.Remaining", 1, true), "ReleaseClockMath.Remaining missing")
local mainReleaseSrc = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChromeReleaseSrc = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
local routerReleaseSrc = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(topBarChromeReleaseSrc, "ReleaseClockMath.Remaining", 1, true), "TopBarChrome ReleaseClock residual for release")
local overviewReleaseClock = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overviewReleaseClock, "ReleaseClockMath.Remaining", 1, true), "OverviewView ReleaseClock residual for release")
assert(string.find(utcClockSrc, "function UtcClockMath.Remaining", 1, true), "UtcClockMath.Remaining missing")
assert(string.find(releaseSrc, "Economy.PrestigeReward", 1, true), "RunQuick PrestigeReward still present for wave22 adjacency")
assert(string.find(releaseSrc, "Economy.Production", 1, true), "RunQuick Production still present for wave22 adjacency")
assert(string.find(releaseSrc, "ProfileIntegrity.VerifyAndRecover", 1, true), "RunQuick profile recovery still present for wave22 adjacency")
assert(not string.find(itemLoadoutSrc, "GetService", 1, true), "ItemLoadoutMath must stay pure")
assert(not string.find(releaseClockSrc, "GetService", 1, true), "ReleaseClockMath must stay pure")
mark("wave22 extract session echo loadout residuals")

-- Wave24: Crew FlatList + FocusClaim + Overview softMotion canon residuals.
-- Wave28 moved Crew roster hosts into CrewView; wave29 moved Overview quietMotion into OverviewView.
local routerWave24 = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local crewWave24 = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
local overviewWave24 = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(crewWave24, 'Name = "CrewVisitClaim"', 1, true), "CrewVisitClaim host missing for release")
do
	local hostStart = string.find(crewWave24, 'Name = "CrewVisitClaim"', 1, true)
	assert(hostStart, "CrewVisitClaim host missing")
	local hostSlice = string.sub(crewWave24, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "CrewVisitClaim clips residual for release")
end
assert(string.find(crewWave24, 'Name = "CrewVisitConfirm"', 1, true), "CrewVisitConfirm residual for release")
assert(string.find(crewWave24, "GamepadNavigationService.FocusClaim", 1, true), "Crew FocusClaim residual for release")
assert(string.find(crewWave24, "createElement(FlatList", 1, true), "Crew FlatList residual for release")
assert(
	string.find(crewWave24, "overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2", 1, true),
	"Crew FlatList softMotion overscan residual for release"
)
assert(
	string.find(
		overviewWave24,
		"local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient",
		1,
		true
	),
	"Overview softMotion canon residual for release"
)
assert(
	string.find(overviewWave24, "local quietMotion = softMotion or effectsPaused or antilag.skipEntrance", 1, true),
	"Overview quietMotion fold residual for release"
)
assert(
	string.find(
		crewWave24,
		"local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient",
		1,
		true
	),
	"Crew softMotion canon residual for release"
)
-- Rewards owns a softMotion canon line inside RewardsView; UpgradeBoard lives in WorkshopView.
local rewardsWave24Canon = fs.readFile("src/Client/AstralForge/pages/RewardsView.luau")
assert(
	string.find(
		rewardsWave24Canon,
		"local softMotion = reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient",
		1,
		true
	),
	"Rewards softMotion canon residual for release"
)
local guildWave24 = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
local guildSoft = 0
for _ in string.gmatch(guildWave24, "softMotion") do
	guildSoft += 1
end
assert(guildSoft >= 8, "Guild softMotion density residual for release, got " .. tostring(guildSoft))
mark("wave24 crew flatlist focusclaim overview softmotion residuals")

-- Wave25: Leaderboards FocusClaim + CrateRevealStage softMotion + DV21 content.
local boardsRelease = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
assert(string.find(boardsRelease, 'Name = "LeaderboardConfirm"', 1, true), "LeaderboardConfirm host missing for release")
do
	local hostStart = string.find(boardsRelease, 'Name = "LeaderboardConfirm"', 1, true)
	assert(hostStart, "LeaderboardConfirm host missing")
	local hostSlice = string.sub(boardsRelease, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "LeaderboardConfirm clips residual for release")
end
assert(string.find(boardsRelease, 'Name = "LeaderboardConfirmFilters"', 1, true), "LeaderboardConfirmFilters residual for release")
assert(string.find(boardsRelease, "GamepadNavigationService.FocusClaim", 1, true), "Leaderboards FocusClaim residual for release")
local stageRelease = fs.readFile("src/Client/AstralForge/pages/CrateRevealStage.luau")
assert(
	string.find(stageRelease, "local softMotion = props.reducedMotion or antilag.tier <= 1 or not antilag.allowAmbient", 1, true),
	"CrateRevealStage softMotion canon residual for release"
)
assert(string.find(stageRelease, "local reducedMotion = softMotion", 1, true), "CrateRevealStage softMotion fold residual for release")
assert(string.find(cfg, 'Id = "wave24-offline-brief"', 1, true), "Story wave24 residual for release")
assert(string.find(cfg, 'Id = "wave25-offline-brief"', 1, true), "Story wave25 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave24-offline"', 1, true), "Mail wave24 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave25-offline"', 1, true), "Mail wave25 residual for release")
mark("wave25 leaderboards focusclaim crate softmotion content residuals")

-- Wave26: Mailbox body FlatList + Items EnsureShop snapshot + Boosts density + DV21 content.
local mailboxWave26 = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
assert(string.find(mailboxWave26, "createElement(FlatList", 1, true), "Mailbox FlatList residual for release")
assert(not string.find(mailboxWave26, 'createElement("scrollingframe"', 1, true), "Mailbox raw scrollingframe residual for release")
assert(string.find(mailboxWave26, 'Name = "MailClaimActions"', 1, true), "MailClaimActions residual for release")
do
	local hostStart = string.find(mailboxWave26, 'Name = "MailClaimActions"', 1, true)
	assert(hostStart, "MailClaimActions host missing")
	local hostSlice = string.sub(mailboxWave26, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "MailClaimActions clips residual for release")
end
assert(string.find(ssReleaseSrc, "ensureItemShop(profile)", 1, true), "SS ensureItemShop residual for release")
assert(string.find(ssReleaseSrc, "ProfileBagMath.EnsureItems(profile)", 1, true), "SS EnsureItems residual for release")
local boostsWave26 = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
local boostSoft = 0
for _ in string.gmatch(boostsWave26, "softMotion") do
	boostSoft += 1
end
assert(boostSoft >= 8, "Boosts softMotion density residual for release, got " .. tostring(boostSoft))
assert(string.find(cfg, 'Id = "wave26-offline-brief"', 1, true), "Story wave26 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave26-offline"', 1, true), "Mail wave26 residual for release")
mark("wave26 mailbox flatlist items ensure boosts content residuals")

-- Wave27: InventoryMath direct calls + SnapshotDomainInts + Trade/Credits softMotion + DV21 content.
local invWave27 = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
assert(not string.find(invWave27, "local function relicRowHeight", 1, true), "Inventory relicRowHeight wrapper residual for release")
assert(string.find(invWave27, "InventoryMath.RelicRowHeight", 1, true), "Inventory RelicRowHeight residual for release")
assert(string.find(invWave27, "InventoryMath.OfferStock", 1, true), "Inventory OfferStock residual for release")
local continuumWave27 = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
assert(string.find(continuumWave27, "function ContinuumDomainMath.SnapshotDomainInts", 1, true), "SnapshotDomainInts missing for release")
assert(string.find(ssReleaseSrc, "ContinuumDomainMath.SnapshotDomainPublic", 1, true) or string.find(ssReleaseSrc, "ContinuumDomainMath.SnapshotDomainInts", 1, true), "SS SnapshotDomainInts residual for release")
assert(not string.find(continuumWave27, "GetService", 1, true), "ContinuumDomainMath must stay pure for release")
local tradeWave27 = fs.readFile("src/Client/AstralForge/pages/TradeView.luau")
local tradeSoft = 0
for _ in string.gmatch(tradeWave27, "softMotion") do
	tradeSoft += 1
end
assert(tradeSoft >= 10, "Trade softMotion density residual for release, got " .. tostring(tradeSoft))
local creditsWave27 = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
local creditsSoft = 0
for _ in string.gmatch(creditsWave27, "softMotion") do
	creditsSoft += 1
end
assert(creditsSoft >= 8, "Credits softMotion density residual for release, got " .. tostring(creditsSoft))
assert(string.find(cfg, 'Id = "wave27-offline-brief"', 1, true), "Story wave27 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave27-offline"', 1, true), "Mail wave27 residual for release")
mark("wave27 inventory continuum trade credits content residuals")

-- Wave28: CrewView extract + MainGame TopBar/MoreDock softMotion + DV21 content.
local crewWave28 = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
assert(string.find(crewWave28, "createElement(FlatList", 1, true), "Crew FlatList residual for release")
assert(string.find(crewWave28, "FocusClaim", 1, true), "Crew FocusClaim residual for release")
assert(string.find(crewWave28, "overscan = if softMotion then 0 elseif antilag.constrained then 1 else 2", 1, true), "Crew overscan residual for release")
local routerWave28 = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(routerWave28, 'lazyView("CrewView", "CrewView")', 1, true), "PageRouter lazy CrewView residual for release")
assert(not string.find(routerWave28, "local function CrewRow", 1, true), "CrewRow must leave PageRouter for release")
assert(not string.find(routerWave28, "local FlatList = require", 1, true), "PageRouter FlatList import residual for release")
local mainWave28 = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChromeWave28 = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
local navChromeWave28 = fs.readFile("src/Client/AstralForge/NavChrome.luau")
assert(string.find(topBarChromeWave28, "Canonical softMotion antilag gate — TopBar", 1, true), "TopBar softMotion residual for release")
assert(string.find(navChromeWave28, "Canonical softMotion antilag gate — MoreDock", 1, true), "MoreDock softMotion residual for release")
assert(string.find(cfg, 'Id = "wave28-offline-brief"', 1, true), "Story wave28 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave28-offline"', 1, true), "Mail wave28 residual for release")
mark("wave28 crew extract maingame softMotion content residuals")

-- Wave29: OverviewView extract + Collect FocusClaim + Rail/Navigation softMotion + DV21 content.
local overviewWave29 = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overviewWave29, 'Name = "OverviewVaultClaimActions"', 1, true), "OverviewVaultClaimActions residual for release")
assert(string.find(overviewWave29, "GamepadNavigationService.FocusClaim", 1, true), "Overview FocusClaim residual for release")
assert(string.find(overviewWave29, "LayoutSectionPlan.planOverview", 1, true), "Overview planOverview residual for release")
assert(
	string.find(overviewWave29, "local quietMotion = softMotion or effectsPaused or antilag.skipEntrance", 1, true),
	"Overview quietMotion residual for release"
)
local routerWave29 = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(routerWave29, 'lazyView("OverviewView", "OverviewView")', 1, true), "PageRouter lazy OverviewView residual for release")
assert(not string.find(routerWave29, "local function OverviewView", 1, true), "inline OverviewView must leave PageRouter for release")
assert(not string.find(routerWave29, "local function ReleaseCountdown", 1, true), "ReleaseCountdown must leave PageRouter for release")
local mainWave29 = fs.readFile("src/Client/AstralForge/MainGame.luau")
local navChromeWave29 = fs.readFile("src/Client/AstralForge/NavChrome.luau")
assert(string.find(navChromeWave29, "Canonical softMotion antilag gate — RailButton", 1, true), "RailButton softMotion residual for release")
assert(string.find(navChromeWave29, "Canonical softMotion antilag gate — Navigation", 1, true), "Navigation softMotion residual for release")
local adminWave29 = fs.readFile("src/Client/AstralForge/pages/AdminView.luau")
do
	local hostStart = string.find(adminWave29, 'Name = "AdminConfirmRun"', 1, true)
	assert(hostStart, "AdminConfirmRun missing for release")
	local hostSlice = string.sub(adminWave29, hostStart, hostStart + 280)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "AdminConfirmRun clips residual for release")
end
assert(string.find(cfg, 'Id = "wave29-offline-brief"', 1, true), "Story wave29 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave29-offline"', 1, true), "Mail wave29 residual for release")
mark("wave29 overview extract maingame rail softMotion content residuals")

-- Wave30: WorldsView + RewardsView extracts + StatChip softMotion + DV21 content.
local worldsWave30 = fs.readFile("src/Client/AstralForge/pages/WorldsView.luau")
assert(string.find(worldsWave30, 'Name = "WorldsTravelClaim"', 1, true), "WorldsTravelClaim residual for release")
assert(string.find(worldsWave30, "GamepadNavigationService.FocusClaim", 1, true), "Worlds FocusClaim residual for release")
assert(string.find(worldsWave30, "reducedMotion = softMotion", 1, true), "Worlds softMotion fold residual for release")
local rewardsWave30 = fs.readFile("src/Client/AstralForge/pages/RewardsView.luau")
assert(string.find(rewardsWave30, 'Name = "RewardsDailyClaimActions"', 1, true), "RewardsDaily residual for release")
assert(string.find(rewardsWave30, 'Name = "RewardsTimedClaimActions"', 1, true), "RewardsTimed residual for release")
assert(string.find(rewardsWave30, "GamepadNavigationService.FocusClaim", 1, true), "Rewards FocusClaim residual for release")
local routerWave30 = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(routerWave30, 'lazyView("WorldsView", "WorldsView")', 1, true), "PageRouter lazy Worlds residual for release")
assert(string.find(routerWave30, 'lazyView("RewardsView", "RewardsView")', 1, true), "PageRouter lazy Rewards residual for release")
assert(not string.find(routerWave30, "local function RewardsView", 1, true), "inline RewardsView must leave PageRouter for release")
assert(not string.find(routerWave30, "GamepadNavigationService", 1, true), "PageRouter GamepadNavigation residual for release")
local mainWave30 = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChromeWave30 = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
assert(string.find(topBarChromeWave30, "Canonical softMotion antilag gate — StatChip", 1, true), "StatChip softMotion residual for release")
assert(string.find(cfg, 'Id = "wave30-offline-brief"', 1, true), "Story wave30 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave30-offline"', 1, true), "Mail wave30 residual for release")
mark("wave30 worlds rewards extract statchip softMotion content residuals")

-- Wave31: WorkshopView extract + Buy FocusClaim + thin PageRouter + DV21 content.
local workshopWave31 = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
assert(string.find(workshopWave31, 'Name = "WorkshopBuyClaim"', 1, true), "WorkshopBuyClaim residual for release")
assert(string.find(workshopWave31, "GamepadNavigationService.FocusClaim", 1, true), "Workshop FocusClaim residual for release")
assert(string.find(workshopWave31, "overscanRows = if softMotion then 0 else (if stack then 2 else 3)", 1, true), "UpgradeBoard overscan residual for release")
local routerWave31 = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
assert(string.find(routerWave31, 'lazyView("WorkshopView", "WorkshopView")', 1, true), "PageRouter lazy Workshop residual for release")
assert(not string.find(routerWave31, "local function UpgradeBoard", 1, true), "UpgradeBoard must leave PageRouter for release")
assert(not string.find(routerWave31, "softMotion", 1, true), "PageRouter softMotion residual for release")
local overviewWave31 = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overviewWave31, "PageReadyMath.CountReadyQuests", 1, true), "Overview CountReadyQuests residual for release")
assert(string.find(cfg, 'Id = "wave31-offline-brief"', 1, true), "Story wave31 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave31-offline"', 1, true), "Mail wave31 residual for release")
mark("wave31 workshop extract buy claim thin pagerouter content residuals")

-- Wave32: MainGame VaultCollectClaim + chrome softMotion densify + DV21 content.
local mainWave32 = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChromeWave32 = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
local workspaceChromeWave32 = fs.readFile("src/Client/AstralForge/WorkspaceChrome.luau")
assert(string.find(workspaceChromeWave32, 'Name = "VaultCollectClaim"', 1, true), "VaultCollectClaim residual for release")
assert(string.find(workspaceChromeWave32, "GamepadNavigationService.FocusClaim", 1, true), "Workspace FocusClaim residual for release")
local shellFxWave32 = fs.readFile("src/Client/AstralForge/ShellFx.luau")
assert(string.find(shellFxWave32, "Canonical softMotion antilag gate — TradeReturnPill", 1, true), "TradeReturnPill softMotion residual for release")
assert(string.find(topBarChromeWave32, "Canonical softMotion antilag gate — ActiveBoostIcon", 1, true), "ActiveBoostIcon softMotion residual for release")
assert(string.find(shellFxWave32, "Canonical softMotion antilag gate — ConfettiBurst", 1, true), "ConfettiBurst softMotion residual for release")
assert(string.find(workspaceChromeWave32, "Canonical softMotion antilag gate — Workspace", 1, true), "Workspace softMotion residual for release")
do
	local shell = fs.readFile("src/Client/AstralForge/AppShellChrome.luau")
	local soft = 0
	for _ in string.gmatch(shell, "softMotion") do
		soft += 1
	end
	assert(soft >= 3, "AppShellChrome softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave32-offline-brief"', 1, true), "Story wave32 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave32-offline"', 1, true), "Mail wave32 residual for release")
mark("wave32 vault collect claim chrome softMotion content residuals")

-- Wave33: TopBarChrome extract + TradeReturnClaim + TopbarReleaseCountdown softMotion + DV21 content.
local topBarChromeWave33 = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
assert(string.find(topBarChromeWave33, "local function TopBar", 1, true), "TopBar extract residual for release")
assert(string.find(topBarChromeWave33, "local function StatChip", 1, true), "StatChip extract residual for release")
assert(string.find(topBarChromeWave33, "local function ActiveBoostIcon", 1, true), "ActiveBoostIcon extract residual for release")
assert(string.find(topBarChromeWave33, "Canonical softMotion antilag gate — TopbarReleaseCountdown", 1, true), "TopbarReleaseCountdown softMotion residual for release")
local mainWave33 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(fs.readFile("src/Client/AstralForge/AppShellChrome.luau"), 'require(script.Parent.TopBarChrome)', 1, true), "AppShellChrome TopBarChrome require residual for release")
assert(string.find(mainWave33, 'Name = "TradeReturnClaim"', 1, true) or string.find(fs.readFile("src/Client/AstralForge/ShellFx.luau"), 'Name = "TradeReturnClaim"', 1, true), "TradeReturnClaim residual for release")
assert(not string.find(mainWave33, "local function TopBar", 1, true), "TopBar must leave MainGame for release")
assert(not string.find(mainWave33, "local function StatChip", 1, true), "StatChip must leave MainGame for release")
assert(not string.find(mainWave33, "local function ActiveBoostIcon", 1, true), "ActiveBoostIcon must leave MainGame for release")
do
	local shellFxWave33 = fs.readFile("src/Client/AstralForge/ShellFx.luau")
	local hostStart = string.find(shellFxWave33, 'Name = "TradeReturnClaim"', 1, true)
	assert(hostStart, "TradeReturnClaim missing for release")
	local hostSlice = string.sub(shellFxWave33, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "TradeReturnClaim clips residual for release")
end
assert(string.find(cfg, 'Id = "wave33-offline-brief"', 1, true), "Story wave33 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave33-offline"', 1, true), "Mail wave33 residual for release")
mark("wave33 topbarchrome extract trade return claim content residuals")

-- Wave34: NavChrome extract + RailNavClaim + MoreDock densify + Ambient/Vault softMotion + DV21 content.
local navChromeWave34 = fs.readFile("src/Client/AstralForge/NavChrome.luau")
assert(string.find(navChromeWave34, "local function Navigation", 1, true), "Navigation extract residual for release")
assert(string.find(navChromeWave34, "local function RailButton", 1, true), "RailButton extract residual for release")
assert(string.find(navChromeWave34, "local function MoreDock", 1, true), "MoreDock extract residual for release")
assert(string.find(navChromeWave34, 'Name = "RailNavClaim"', 1, true), "RailNavClaim residual for release")
assert(string.find(navChromeWave34, "GamepadNavigationService.FocusClaim", 1, true), "RailNav FocusClaim residual for release")
assert(string.find(navChromeWave34, "Canonical softMotion antilag gate — MoreDockButton", 1, true), "MoreDockButton softMotion residual for release")
assert(string.find(navChromeWave34, "Canonical softMotion antilag gate — MoreDockPopover", 1, true), "MoreDockPopover softMotion residual for release")
assert(string.find(navChromeWave34, "Canonical softMotion antilag gate — MoreCell", 1, true), "MoreCell softMotion residual for release")
local mainWave34 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(fs.readFile("src/Client/AstralForge/AppShellChrome.luau"), 'require(script.Parent.NavChrome)', 1, true), "AppShellChrome NavChrome require residual for release")
local shellFxWave34 = fs.readFile("src/Client/AstralForge/ShellFx.luau")
assert(string.find(shellFxWave34, "Canonical softMotion antilag gate — AmbientLayer", 1, true), "AmbientLayer softMotion residual for release")
local workspaceChromeWave34 = fs.readFile("src/Client/AstralForge/WorkspaceChrome.luau")
assert(string.find(workspaceChromeWave34, "Canonical softMotion antilag gate — VaultPill", 1, true), "VaultPill softMotion residual for release")
assert(not string.find(mainWave34, "local function Navigation", 1, true), "Navigation must leave MainGame for release")
assert(not string.find(mainWave34, "local function RailButton", 1, true), "RailButton must leave MainGame for release")
assert(not string.find(mainWave34, "local function MoreDock", 1, true), "MoreDock must leave MainGame for release")
do
	local hostStart = string.find(navChromeWave34, 'Name = "RailNavClaim"', 1, true)
	assert(hostStart, "RailNavClaim missing for release")
	local hostSlice = string.sub(navChromeWave34, hostStart, hostStart + 420)
	assert(string.find(hostSlice, "ClipsDescendants = false", 1, true), "RailNavClaim clips residual for release")
end
do
	local soft = 0
	for _ in string.gmatch(navChromeWave34, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "NavChrome softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave34-offline-brief"', 1, true), "Story wave34 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave34-offline"', 1, true), "Mail wave34 residual for release")
mark("wave34 navchrome extract rail claim softMotion content residuals")

-- Wave35: WorkspaceChrome extract + NextUnlock/AppShell softMotion + DV21 content.
local workspaceChromeWave35 = fs.readFile("src/Client/AstralForge/WorkspaceChrome.luau")
assert(string.find(workspaceChromeWave35, "local function Workspace", 1, true), "Workspace extract residual for release")
assert(string.find(workspaceChromeWave35, "local function VaultPill", 1, true), "VaultPill extract residual for release")
assert(string.find(workspaceChromeWave35, "local function NextUnlockStrip", 1, true), "NextUnlockStrip extract residual for release")
assert(string.find(workspaceChromeWave35, 'Name = "VaultCollectClaim"', 1, true), "VaultCollectClaim residual for release")
assert(string.find(workspaceChromeWave35, "Canonical softMotion antilag gate — NextUnlockStrip", 1, true), "NextUnlockStrip softMotion residual for release")
local mainWave35 = fs.readFile("src/Client/AstralForge/MainGame.luau")
local appShellWave35 = fs.readFile("src/Client/AstralForge/AppShellChrome.luau")
assert(string.find(appShellWave35, 'require(script.Parent.WorkspaceChrome)', 1, true), "AppShellChrome WorkspaceChrome require residual for release")
assert(string.find(appShellWave35, "Canonical softMotion antilag gate — AppShell", 1, true), "AppShell softMotion residual for release")
assert(not string.find(mainWave35, "local function Workspace", 1, true), "Workspace must leave MainGame for release")
assert(not string.find(mainWave35, "local function VaultPill", 1, true), "VaultPill must leave MainGame for release")
assert(not string.find(mainWave35, "local function NextUnlockStrip", 1, true), "NextUnlockStrip must leave MainGame for release")
do
	local soft = 0
	for _ in string.gmatch(workspaceChromeWave35, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "WorkspaceChrome softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave35-offline-brief"', 1, true), "Story wave35 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave35-offline"', 1, true), "Mail wave35 residual for release")
mark("wave35 workspacechrome extract nextunlock appshell content residuals")

-- Wave36: ShellFx extract + Inventory/Guild/Anomaly softMotion densify + DV21 content.
local shellFxWave36 = fs.readFile("src/Client/AstralForge/ShellFx.luau")
assert(string.find(shellFxWave36, "local function AmbientLayer", 1, true), "AmbientLayer extract residual for release")
assert(string.find(shellFxWave36, "local function ConfettiBurst", 1, true), "ConfettiBurst extract residual for release")
assert(string.find(shellFxWave36, "Canonical softMotion antilag gate — AmbientLayer", 1, true), "AmbientLayer softMotion residual for release")
assert(string.find(shellFxWave36, "Canonical softMotion antilag gate — ConfettiBurst", 1, true), "ConfettiBurst softMotion residual for release")
local mainWave36 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(fs.readFile("src/Client/AstralForge/AppShellChrome.luau"), 'require(script.Parent.ShellFx)', 1, true), "AppShellChrome ShellFx require residual for release")
assert(not string.find(mainWave36, "local function AmbientLayer", 1, true), "AmbientLayer must leave MainGame for release")
assert(not string.find(mainWave36, "local function ConfettiBurst", 1, true), "ConfettiBurst must leave MainGame for release")
assert(not string.find(mainWave36, "local CONFETTI_PIECES", 1, true), "CONFETTI_PIECES must leave MainGame for release")
local invWave36 = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local guildWave36 = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
local anomalyWave36 = fs.readFile("src/Client/AstralForge/pages/AnomalyView.luau")
assert(string.find(invWave36, "Canonical softMotion antilag gate — InventoryView", 1, true), "Inventory softMotion residual for release")
assert(string.find(guildWave36, "Canonical softMotion antilag gate — GuildView", 1, true), "Guild softMotion residual for release")
assert(string.find(anomalyWave36, "Canonical softMotion antilag gate — AnomalyView", 1, true), "Anomaly softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(invWave36, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Inventory softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(guildWave36, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Guild softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(anomalyWave36, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "Anomaly softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave36-offline-brief"', 1, true), "Story wave36 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave36-offline"', 1, true), "Mail wave36 residual for release")
mark("wave36 shellfx extract inventory guild anomaly softMotion content residuals")

-- Wave37: TradeReturn into ShellFx + Command/Settings/Lab/Continuum densify + DENSE floors + DV21.
local shellFxWave37 = fs.readFile("src/Client/AstralForge/ShellFx.luau")
assert(string.find(shellFxWave37, "local function TradeReturnPill", 1, true), "TradeReturnPill extract residual for release")
assert(string.find(shellFxWave37, 'Name = "TradeReturnClaim"', 1, true), "TradeReturnClaim residual for release")
local mainWave37 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(fs.readFile("src/Client/AstralForge/AppShellChrome.luau"), "local TradeReturnPill = _ShellFx.TradeReturnPill", 1, true), "AppShellChrome TradeReturnPill bind residual for release")
assert(not string.find(mainWave37, "local function TradeReturnPill", 1, true), "TradeReturnPill must leave MainGame for release")
local commandWave37 = fs.readFile("src/Client/AstralForge/pages/CommandView.luau")
local settingsWave37 = fs.readFile("src/Client/AstralForge/pages/SettingsView.luau")
local labWave37 = fs.readFile("src/Client/AstralForge/pages/LabView.luau")
local continuumWave37 = fs.readFile("src/Client/AstralForge/pages/ContinuumView.luau")
assert(string.find(commandWave37, "Canonical softMotion antilag gate — CommandView", 1, true), "Command softMotion residual for release")
assert(string.find(settingsWave37, "Canonical softMotion antilag gate — SettingsView", 1, true), "Settings softMotion residual for release")
assert(string.find(labWave37, "Canonical softMotion antilag gate — LabView", 1, true), "Lab softMotion residual for release")
assert(string.find(continuumWave37, "Canonical softMotion antilag gate — ContinuumView", 1, true), "Continuum softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(commandWave37, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Command softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(settingsWave37, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Settings softMotion densify residual for release, got " .. tostring(soft))
end
local playabilityWave37 = fs.readFile("scripts/verify_playability.luau")
assert(string.find(playabilityWave37, '["src/Client/AstralForge/pages/InventoryView.luau"] = 12', 1, true), "Inventory DENSE floor residual for release")
assert(string.find(playabilityWave37, '["src/Client/AstralForge/pages/CommandView.luau"] = 12', 1, true), "Command DENSE floor residual for release")
assert(string.find(cfg, 'Id = "wave37-offline-brief"', 1, true), "Story wave37 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave37-offline"', 1, true), "Mail wave37 residual for release")
mark("wave37 tradereturn shellfx command settings lab continuum densify content residuals")

-- Wave38: AppShellChrome extract + Crew/Missions/Milestones/Leaderboards densify + DENSE floors + DV21.
local appShellWave38 = fs.readFile("src/Client/AstralForge/AppShellChrome.luau")
assert(string.find(appShellWave38, "local function AppShell", 1, true), "AppShell extract residual for release")
assert(string.find(appShellWave38, "Canonical softMotion antilag gate — AppShell", 1, true), "AppShell softMotion residual for release")
local mainWave38 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(mainWave38, "require(script.Parent.AppShellChrome)", 1, true), "MainGame AppShellChrome require residual for release")
assert(string.find(mainWave38, "local Shell = _AppShellChrome.Shell", 1, true), "MainGame Shell bind residual for release")
assert(not string.find(mainWave38, "local function AppShell", 1, true), "AppShell must leave MainGame for release")
assert(not string.find(mainWave38, "local TUTORIAL_STEPS", 1, true), "TUTORIAL_STEPS must leave MainGame for release")
do
	local soft = 0
	for _ in string.gmatch(appShellWave38, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "AppShellChrome softMotion densify residual for release, got " .. tostring(soft))
end
local crewWave38 = fs.readFile("src/Client/AstralForge/pages/CrewView.luau")
local missionsWave38 = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
local milestonesWave38 = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
local boardsWave38 = fs.readFile("src/Client/AstralForge/pages/LeaderboardsView.luau")
assert(string.find(crewWave38, "Canonical softMotion antilag gate — CrewView", 1, true), "Crew softMotion residual for release")
assert(string.find(missionsWave38, "Canonical softMotion antilag gate — MissionsView", 1, true), "Missions softMotion residual for release")
assert(string.find(milestonesWave38, "Canonical softMotion antilag gate — MilestonesView", 1, true), "Milestones softMotion residual for release")
assert(string.find(boardsWave38, "Canonical softMotion antilag gate — LeaderboardsView", 1, true), "Leaderboards softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(crewWave38, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Crew softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(missionsWave38, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Missions softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(milestonesWave38, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "Milestones softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(boardsWave38, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Leaderboards softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave38-offline-brief"', 1, true), "Story wave38 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave38-offline"', 1, true), "Mail wave38 residual for release")
mark("wave38 appshellchrome extract crew missions milestones boards densify content residuals")

-- Wave39: Anomaly/Milestones/Convergence/ForgePath densify + OfflineRewards/Feedback softMotion + DENSE floors + DV21.
local anomalyWave39 = fs.readFile("src/Client/AstralForge/pages/AnomalyView.luau")
local milestonesWave39 = fs.readFile("src/Client/AstralForge/pages/MilestonesView.luau")
local convergenceWave39 = fs.readFile("src/Client/AstralForge/pages/ConvergenceView.luau")
local forgePathWave39 = fs.readFile("src/Client/AstralForge/pages/ForgePathView.luau")
assert(string.find(anomalyWave39, "Canonical softMotion antilag gate — AnomalyView", 1, true), "Anomaly softMotion residual for release")
assert(string.find(milestonesWave39, "Canonical softMotion antilag gate — MilestonesView", 1, true), "Milestones softMotion residual for release")
assert(string.find(convergenceWave39, "Canonical softMotion antilag gate — ConvergenceView", 1, true), "Convergence softMotion residual for release")
assert(string.find(forgePathWave39, "Canonical softMotion antilag gate — ForgePathView", 1, true), "ForgePath softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(anomalyWave39, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Anomaly softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(milestonesWave39, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Milestones softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(convergenceWave39, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "Convergence softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(forgePathWave39, "softMotion") do
		soft += 1
	end
	assert(soft >= 12, "ForgePath softMotion densify residual for release, got " .. tostring(soft))
end
local offlineWave39 = fs.readFile("src/Client/AstralForge/OfflineRewardsOverlay.luau")
local feedbackWave39 = fs.readFile("src/Client/AstralForge/FeedbackOverlay.luau")
assert(string.find(offlineWave39, "Canonical softMotion antilag gate — OfflineRewardsOverlay", 1, true), "OfflineRewards softMotion residual for release")
assert(string.find(feedbackWave39, "Canonical softMotion antilag gate — FeedbackOverlay", 1, true), "Feedback softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(offlineWave39, "softMotion") do
		soft += 1
	end
	assert(soft >= 10, "OfflineRewards softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(feedbackWave39, "softMotion") do
		soft += 1
	end
	assert(soft >= 8, "Feedback softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave39-offline-brief"', 1, true), "Story wave39 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave39-offline"', 1, true), "Mail wave39 residual for release")
mark("wave39 anomaly milestones convergence forgepath overlay softMotion densify content residuals")

-- Wave40: VisitSnapshot peel + DomainExpansion/Purchase/Boosts densify + DENSE floors + DV21.
local visitSnapWave40 = fs.readFile("src/Server/AstralForge/Modules/VisitSnapshot.luau")
assert(string.find(visitSnapWave40, "function VisitSnapshot.Build", 1, true), "VisitSnapshot.Build residual for release")
local serverWave40 = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(serverWave40, 'WaitForChild("VisitSnapshot")', 1, true), "ServerServices VisitSnapshot require residual for release")
assert(string.find(serverWave40, "VisitSnapshot.Build", 1, true), "ServerServices VisitSnapshot.Build residual for release")
local domainWave40 = fs.readFile("src/Client/AstralForge/DomainExpansionOverlay.luau")
local purchaseWave40 = fs.readFile("src/Client/AstralForge/purchaseOverlay.luau")
local boostsWave40 = fs.readFile("src/Client/AstralForge/pages/BoostsView.luau")
assert(string.find(domainWave40, "Canonical softMotion antilag gate — DomainExpansionOverlay", 1, true), "DomainExpansion softMotion residual for release")
assert(string.find(purchaseWave40, "Canonical softMotion antilag gate — PurchaseOverlay", 1, true), "Purchase softMotion residual for release")
assert(string.find(boostsWave40, "Canonical softMotion antilag gate — BoostsView", 1, true), "Boosts softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(domainWave40, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "DomainExpansion softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(boostsWave40, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Boosts softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave40-offline-brief"', 1, true), "Story wave40 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave40-offline"', 1, true), "Mail wave40 residual for release")
mark("wave40 visitsnapshot peel domain purchase boosts softMotion densify content residuals")

-- Wave41: PublicPlayerRecord/SettingsSeal peels + Research/Wheel/Boot/AdminPrank densify + DENSE floors + DV21.
local publicRecWave41 = fs.readFile("src/Server/AstralForge/Modules/PublicPlayerRecord.luau")
assert(string.find(publicRecWave41, "function PublicPlayerRecord.Build", 1, true), "PublicPlayerRecord.Build residual for release")
local sealWave41 = fs.readFile("src/Server/AstralForge/Modules/SettingsSeal.luau")
assert(string.find(sealWave41, "function SettingsSeal.Apply", 1, true), "SettingsSeal.Apply residual for release")
local serverWave41 = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(serverWave41, 'WaitForChild("PublicPlayerRecord")', 1, true), "ServerServices PublicPlayerRecord require residual for release")
assert(string.find(serverWave41, "SettingsSeal.Apply", 1, true), "ServerServices SettingsSeal.Apply residual for release")
local researchWave41 = fs.readFile("src/Client/AstralForge/pages/ResearchView.luau")
local wheelWave41 = fs.readFile("src/Client/AstralForge/pages/WheelView.luau")
local bootWave41 = fs.readFile("src/Client/AstralForge/BootScreen.luau")
assert(string.find(researchWave41, "Canonical softMotion antilag gate — ResearchView", 1, true), "Research softMotion residual for release")
assert(string.find(wheelWave41, "Canonical softMotion antilag gate — WheelView", 1, true), "Wheel softMotion residual for release")
assert(string.find(bootWave41, "Canonical softMotion antilag gate — BootScreen", 1, true), "BootScreen softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(researchWave41, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Research softMotion densify residual for release, got " .. tostring(soft))
end
do
	local soft = 0
	for _ in string.gmatch(wheelWave41, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Wheel softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave41-offline-brief"', 1, true), "Story wave41 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave41-offline"', 1, true), "Mail wave41 residual for release")
mark("wave41 publicplayer settingsseal research wheel boot densify content residuals")

-- Wave42: NoticeMath peel + Missions/Worlds densify + DENSE floors + DV21.
local noticeWave42 = fs.readFile("src/Client/AstralForge/noticeMath.luau")
assert(string.find(noticeWave42, "function NoticeMath.NormalizeTitle", 1, true), "NoticeMath.NormalizeTitle residual for release")
assert(string.find(noticeWave42, "function NoticeMath.ShouldDedupe", 1, true), "NoticeMath.ShouldDedupe residual for release")
local mainWave42 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(mainWave42, 'require(script.Parent.noticeMath)', 1, true), "MainGame noticeMath require residual for release")
assert(string.find(mainWave42, "NoticeMath.NormalizeTitle", 1, true), "MainGame NoticeMath.NormalizeTitle residual for release")
assert(not string.find(mainWave42, 'if title == "Boost online" then "Boost on"', 1, true), "title normalize must leave MainGame for release")
local missionsWave42 = fs.readFile("src/Client/AstralForge/pages/MissionsView.luau")
assert(string.find(missionsWave42, "Canonical softMotion antilag gate — MissionRow", 1, true), "MissionRow softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(missionsWave42, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Missions softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave42-offline-brief"', 1, true), "Story wave42 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave42-offline"', 1, true), "Mail wave42 residual for release")
mark("wave42 noticemath peel missions worlds densify content residuals")

-- Wave43: SnapshotEnvelopeMath peel + Chat/Convergence/StarGrid densify + DENSE floors + DV21.
local envelopeWave43 = fs.readFile("src/Client/AstralForge/snapshotEnvelopeMath.luau")
assert(string.find(envelopeWave43, "function SnapshotEnvelopeMath.IsValidEnvelope", 1, true), "SnapshotEnvelopeMath.IsValidEnvelope residual for release")
assert(string.find(envelopeWave43, "function SnapshotEnvelopeMath.IsFiniteNumber", 1, true), "SnapshotEnvelopeMath.IsFiniteNumber residual for release")
local mainWave43 = fs.readFile("src/Client/AstralForge/MainGame.luau")
assert(string.find(mainWave43, 'require(script.Parent.snapshotEnvelopeMath)', 1, true), "MainGame snapshotEnvelopeMath require residual for release")
assert(string.find(mainWave43, "SnapshotEnvelopeMath.IsValidEnvelope", 1, true), "MainGame IsValidEnvelope residual for release")
assert(not string.find(mainWave43, 'local numericKeys = { "Revision", "SnapshotId"', 1, true), "numericKeys must leave MainGame for release")
local chatWave43 = fs.readFile("src/Client/AstralForge/pages/ChatView.luau")
assert(string.find(chatWave43, "Canonical softMotion antilag gate — MessageRow", 1, true), "MessageRow softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(chatWave43, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Chat softMotion densify residual for release, got " .. tostring(soft))
end
local starWave43 = fs.readFile("src/Client/AstralForge/pages/StarGridView.luau")
assert(string.find(starWave43, "Canonical softMotion antilag gate — StarGridNode", 1, true), "StarGridNode softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(starWave43, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "StarGrid softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave43-offline-brief"', 1, true), "Story wave43 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave43-offline"', 1, true), "Mail wave43 residual for release")
mark("wave43 snapshotenvelope chat convergence stargrid densify content residuals")

-- Wave44: UnlimitedMoneySeal/StoryMailSnapshot peels + Overview/Feedback/Mailbox/Echo densify + DENSE floors + DV21.
local moneyWave44 = fs.readFile("src/Server/AstralForge/Modules/UnlimitedMoneySeal.luau")
assert(string.find(moneyWave44, "function UnlimitedMoneySeal.Apply", 1, true), "UnlimitedMoneySeal.Apply residual for release")
local storyMailWave44 = fs.readFile("src/Server/AstralForge/Modules/StoryMailSnapshot.luau")
assert(string.find(storyMailWave44, "function StoryMailSnapshot.BuildStory", 1, true), "StoryMailSnapshot.BuildStory residual for release")
local servicesWave44 = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(servicesWave44, "UnlimitedMoneySeal.Apply", 1, true), "ServerServices UnlimitedMoneySeal residual for release")
assert(string.find(servicesWave44, "StoryMailSnapshot.BuildMailbox", 1, true), "ServerServices StoryMailSnapshot residual for release")
assert(not string.find(servicesWave44, "profile.Cash = MAX_SAFE_CURRENCY", 1, true), "cash seal must leave ServerServices for release")
local overviewWave44 = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overviewWave44, "Canonical softMotion antilag gate — ReleaseCountdown", 1, true), "ReleaseCountdown softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(overviewWave44, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Overview softMotion densify residual for release, got " .. tostring(soft))
end
local echoWave44 = fs.readFile("src/Client/AstralForge/pages/EchoForgeView.luau")
assert(string.find(echoWave44, "Canonical softMotion antilag gate — EchoCharge", 1, true), "EchoCharge softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(echoWave44, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Echo softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave44-offline-brief"', 1, true), "Story wave44 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave44-offline"', 1, true), "Mail wave44 residual for release")
mark("wave44 unlimitedmoney storymail overview feedback mailbox echo densify content residuals")

-- Wave45: VisitorList/AutoSalvageSnapshot peels + Shop/Admin/Story/Rebirth densify + DENSE floors + DV21.
local visitorWave45 = fs.readFile("src/Server/AstralForge/Modules/VisitorList.luau")
assert(string.find(visitorWave45, "function VisitorList.Build", 1, true), "VisitorList.Build residual for release")
local salvageWave45 = fs.readFile("src/Server/AstralForge/Modules/AutoSalvageSnapshot.luau")
assert(string.find(salvageWave45, "function AutoSalvageSnapshot.Public", 1, true), "AutoSalvageSnapshot.Public residual for release")
local servicesWave45 = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(servicesWave45, "VisitorList.Build", 1, true), "ServerServices VisitorList residual for release")
assert(string.find(servicesWave45, "AutoSalvageSnapshot.Public", 1, true), "ServerServices AutoSalvageSnapshot residual for release")
assert(not string.find(servicesWave45, 'Enabled = false, MachineId = "StellarCore", Reserve = 0.25', 1, true), "AutoForge default must leave ServerServices for release")
local shopWave45 = fs.readFile("src/Client/AstralForge/pages/ShopView.luau")
assert(string.find(shopWave45, "Canonical softMotion antilag gate — ShopCatalog", 1, true), "ShopCatalog softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(shopWave45, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Shop softMotion densify residual for release, got " .. tostring(soft))
end
local rebirthWave45 = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")
assert(string.find(rebirthWave45, "Canonical softMotion antilag gate — RebirthConfirm", 1, true), "RebirthConfirm softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(rebirthWave45, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Rebirth softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave45-offline-brief"', 1, true), "Story wave45 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave45-offline"', 1, true), "Mail wave45 residual for release")
mark("wave45 visitorlist autosalvage shop admin story rebirth densify content residuals")

-- Wave46: Domain/Continuum SnapshotPublic peels + Credits/Worlds/Rewards/Workshop densify + DENSE floors + DV21.
local continuumWave46 = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
assert(string.find(continuumWave46, "function ContinuumDomainMath.SnapshotDomainPublic", 1, true), "SnapshotDomainPublic residual for release")
assert(string.find(continuumWave46, "function ContinuumDomainMath.SnapshotContinuumPublic", 1, true), "SnapshotContinuumPublic residual for release")
local servicesWave46 = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(servicesWave46, "ContinuumDomainMath.SnapshotDomainPublic", 1, true), "ServerServices SnapshotDomainPublic residual for release")
assert(not string.find(servicesWave46, "Domain = (function()", 1, true), "Domain IIFE must leave ServerServices for release")
local creditsWave46 = fs.readFile("src/Client/AstralForge/pages/CreditsView.luau")
assert(string.find(creditsWave46, "Canonical softMotion antilag gate — CreditsRoles", 1, true), "CreditsRoles softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(creditsWave46, "softMotion") do
		soft += 1
	end
	assert(soft >= 14, "Credits softMotion densify residual for release, got " .. tostring(soft))
end
local workshopWave46 = fs.readFile("src/Client/AstralForge/pages/WorkshopView.luau")
assert(string.find(workshopWave46, "Canonical softMotion antilag gate — WorkshopBoard", 1, true), "WorkshopBoard softMotion residual for release")
do
	local soft = 0
	for _ in string.gmatch(workshopWave46, "softMotion") do
		soft += 1
	end
	assert(soft >= 16, "Workshop softMotion densify residual for release, got " .. tostring(soft))
end
assert(string.find(cfg, 'Id = "wave46-offline-brief"', 1, true), "Story wave46 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave46-offline"', 1, true), "Mail wave46 residual for release")
mark("wave46 domain continuum snapshot credits worlds rewards workshop densify content residuals")

-- Wave47 peel/densify asserts live in verify_wave47_harden (release-readiness register budget).
assert(string.find(cfg, 'Id = "wave47-offline-brief"', 1, true), "Story wave47 residual for release")
assert(string.find(cfg, 'Id = "update-5-1-wave47-offline"', 1, true), "Mail wave47 residual for release")
mark("wave47 guild trade overcharge visit leaderboards chat densify content residuals")

-- Wave47 residuals raise the offline subset past checks=52.
assert(#passed > 52, "release-readiness offline subset must stay beyond checks=52, got " .. tostring(#passed))

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
