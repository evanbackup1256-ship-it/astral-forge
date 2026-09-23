--!strict
-- Wave22 harden: LabOrderMath string Progress/Target coerce, AnomalyOpsMath
-- Effect/SurgeMultiplier, ContinuumDomainMath DomainProductionMultiplier,
-- MailClaim/Inspect SOCKET/UPGRADE clips, Rebirth softMotion density.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local LabOrderMath = require("../src/Server/AstralForge/Modules/LabOrderMath")
local AnomalyOpsMath = require("../src/Server/AstralForge/Modules/AnomalyOpsMath")
local ContinuumDomainMath = require("../src/Server/AstralForge/Modules/ContinuumDomainMath")

assert(LabOrderMath.IsReady({ Id = "A", Progress = "9", Target = "10", Claimed = false }) == false, "string 9/10 not ready")
assert(LabOrderMath.IsReady({ Id = "A", Progress = "10", Target = "10", Claimed = false }) == true, "string 10/10 ready")
local orders = { { Id = "A", Progress = "9", Target = "10", Claimed = false } }
local byId = { A = { Id = "A", Kind = "Tap", BaseTarget = 10 } }
assert(LabOrderMath.ApplyProgress(orders, byId, "Tap", 1) == true, "string progress applies")
assert(orders[1].Progress == 10, "A coerced to 10")
assert(select(1, LabOrderMath.TryClaim(orders, byId, "A")) == true, "claim ok")

local protocols = { { Id = "P1", EffectKind = "Production", EffectPerLevel = 0.1 } }
local channels = { Alpha = { EffectKind = "Production", EffectAmount = 0.2 } }
local types = { { EffectKind = "Production", EffectAmount = 0.05 } }
local coreTiers = { { Tier = 1, PassiveProduction = 0.02 }, { Tier = 2, PassiveProduction = 0.03 } }
local state = { Protocols = { P1 = 2 }, Loadout = { "Alpha" }, CoreTier = 2, SurgeEndsAt = "9999999999" }
assert(math.abs(AnomalyOpsMath.Effect(state, "Production", protocols, channels, types, 86_400, 0, coreTiers) - 0.5) < 1e-9, "effect sum")
assert(AnomalyOpsMath.SurgeMultiplier(state, 100, 2.5) == 2.5, "string SurgeEndsAt active")
assert(AnomalyOpsMath.SurgeMultiplier({ SurgeEndsAt = "50" }, 100, 2.5) == 1, "expired")

assert(math.abs(ContinuumDomainMath.DomainProductionMultiplier(2, 100, 0.01, 0.001, 1_000_000, 0.05) - 1.17) < 1e-9, "domain production")
assert(math.abs(ContinuumDomainMath.DomainProductionMultiplier(0, 2_000_000, 0, 0.001, 1_000_000, 0) - 1001) < 1e-9, "essence soft-cap")
assert(math.abs(ContinuumDomainMath.DomainRankBonus(4, 0.05, 0.1) - 0.3) < 1e-9, "rank bonus")

local labMathSrc = fs.readFile("src/Server/AstralForge/Modules/LabOrderMath.luau")
local anomalySrc = fs.readFile("src/Server/AstralForge/Modules/AnomalyOpsMath.luau")
local continuumSrc = fs.readFile("src/Server/AstralForge/Modules/ContinuumDomainMath.luau")
local economySrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local ssSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local mailboxSrc = fs.readFile("src/Client/AstralForge/pages/MailboxView.luau")
local invSrc = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local rebirthSrc = fs.readFile("src/Client/AstralForge/pages/RebirthPanel.luau")

assert(string.find(labMathSrc, "tonumber(state and state.Progress)", 1, true), "LabOrderMath Progress tonumber")
assert(string.find(dataSrc, "nonNegative(tonumber(order.Progress)", 1, true), "DataService Progress coerce")
assert(string.find(economySrc, "AnomalyOpsMath.Effect", 1, true), "Economy Effect")
assert(string.find(economySrc, "AnomalyOpsMath.SurgeMultiplier", 1, true), "Economy Surge")
assert(string.find(ssSrc, "ContinuumDomainMath.DomainProductionMultiplier", 1, true), "SS DomainProduction")
assert(string.find(ssSrc, "ShopGrantEligibility.RemainingStock", 1, true), "SS RemainingStock")
assert(string.find(anomalySrc, "function AnomalyOpsMath.Effect", 1, true), "Effect fn")
assert(string.find(continuumSrc, "function ContinuumDomainMath.DomainProductionMultiplier", 1, true), "DomainProduction fn")

do
	local hostStart = string.find(mailboxSrc, 'Name = "MailClaim"', 1, true)
	assert(hostStart, "MailClaim missing")
	assert(string.find(string.sub(mailboxSrc, hostStart, hostStart + 280), "ClipsDescendants = false", 1, true), "MailClaim clips")
end
do
	local hostStart = string.find(invSrc, 'Name = "InspectSocketClaim"', 1, true)
	assert(hostStart and string.find(string.sub(invSrc, hostStart, hostStart + 280), "ClipsDescendants = false", 1, true), "InspectSocket clips")
end
local softUses = 0
for _ in string.gmatch(rebirthSrc, "softMotion") do softUses += 1 end
assert(softUses >= 8, "Rebirth softMotion density " .. tostring(softUses))

for _, src in { labMathSrc, anomalySrc, continuumSrc, economySrc, dataSrc, ssSrc } do
	assert(not string.find(src, "vendor/", 1, true) and not string.find(src, "Packages/", 1, true), "no vendor/Packages")
end
assert(not string.find(labMathSrc, "GetService", 1, true), "LabOrderMath must stay pure")
assert(not string.find(anomalySrc, "GetService", 1, true), "AnomalyOpsMath must stay pure")
assert(not string.find(continuumSrc, "GetService", 1, true), "ContinuumDomainMath must stay pure")

assert(tonumber(string.match(configSrc, "DataVersion%s*=%s*(%d+)")) == 21, "DV21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges)
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id)
end
assert(string.find(configSrc, "Wave22LabOrderProgress", 1, true))
assert(string.find(configSrc, "Wave22ClaimClipsSoftMotion", 1, true))
assert(string.find(configSrc, "Wave22LabCourier", 1, true))
assert(string.find(configSrc, "wave22-harden-brief", 1, true))
assert(string.find(configSrc, "update-5-1-wave22-harden", 1, true))

print("[INFO] [TEST] wave22 harden LabOrder Progress + Anomaly Effect/Surge + DomainProduction + clips passed")
