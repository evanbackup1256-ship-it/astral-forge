--!strict
-- Pure-module extract guards: AnomalyOpsMath (FindProtocol / ProtocolEffect /
-- ChargeTarget / SelectDirectives / ProtocolCost / RewardMultiplier).
-- Evidence: Fragments-only Anomaly bags threw on Discoveries/Protocols index;
-- AnomalyService.Ensure now rebuilds via ProfileBagMath before Pulse/Stabilize.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local AnomalyOpsMath = require("../src/Server/AstralForge/Modules/AnomalyOpsMath")
local ProfileBagMath = require("../src/Server/AstralForge/Modules/ProfileBagMath")

------------------------------------------------------------------------
-- FindProtocol
------------------------------------------------------------------------
assert(AnomalyOpsMath.FindProtocol(nil, "x") == nil, "nil list")
assert(AnomalyOpsMath.FindProtocol({ { Id = "A" }, { Id = "B" } }, "B").Id == "B", "find B")
assert(AnomalyOpsMath.FindProtocol({ { Id = "A" } }, "Z") == nil, "missing")

------------------------------------------------------------------------
-- ProtocolEffect
------------------------------------------------------------------------
local defs = {
	{ Id = "P1", EffectKind = "ChargeGain", EffectPerLevel = 0.1 },
	{ Id = "P2", EffectKind = "Reward", EffectPerLevel = 0.2 },
	{ Id = "P3", EffectKind = "ChargeGain", EffectPerLevel = 0.05 },
}
assert(AnomalyOpsMath.ProtocolEffect(nil, defs, "ChargeGain") == 0, "nil bag → 0")
assert(math.abs(AnomalyOpsMath.ProtocolEffect({ P1 = 2, P3 = 4 }, defs, "ChargeGain") - 0.4) < 1e-9, "charge sum")
assert(math.abs(AnomalyOpsMath.ProtocolEffect({ P2 = 3 }, defs, "Reward") - 0.6) < 1e-9, "reward sum")
assert(AnomalyOpsMath.ProtocolEffect({ P1 = 1 }, defs, "Missing") == 0, "unknown kind")

------------------------------------------------------------------------
-- CoreTierMaximumBonus / ChargeTarget
------------------------------------------------------------------------
local tiers = {
	{ Tier = 1, MaximumTargetBonus = 50 },
	{ Tier = 2, MaximumTargetBonus = 120 },
	{ Tier = 3, MaximumTargetBonus = 200 },
}
assert(AnomalyOpsMath.CoreTierMaximumBonus(0, tiers) == 0, "tier 0")
assert(AnomalyOpsMath.CoreTierMaximumBonus(2, tiers) == 120, "tier 2 bonus")
assert(AnomalyOpsMath.CoreTierMaximumBonus(9, tiers) == 200, "above max keeps last")
assert(AnomalyOpsMath.ChargeTarget(100, 22, 2500, 0, 0) == 100, "base target")
assert(AnomalyOpsMath.ChargeTarget(100, 22, 2500, 10, 50) == 320, "stabs + tier")
assert(AnomalyOpsMath.ChargeTarget(100, 22, 2500, 200, 0) == 2500, "clamps to max")
assert(AnomalyOpsMath.ChargeTarget(100, 22, 2500, nil, 0) == 100, "nil stabs")

------------------------------------------------------------------------
-- ProtocolCost / SelectDirectives / RewardMultiplier
------------------------------------------------------------------------
assert(AnomalyOpsMath.ProtocolCost({ BaseCost = 10, CostScale = 1.5 }, 0) == 10, "level 0 cost")
assert(AnomalyOpsMath.ProtocolCost({ BaseCost = 10, CostScale = 1.5 }, 2) == 23, "level 2 cost")
assert(AnomalyOpsMath.ProtocolCost({ BaseCost = 10, CostScale = 1.5 }, nil) == 10, "nil level")

local directives = {
	{ Id = "D1", TargetMin = 10, TargetMax = 20 },
	{ Id = "D2", TargetMin = 5, TargetMax = 15 },
	{ Id = "D3", TargetMin = 8, TargetMax = 12 },
}
local selected = AnomalyOpsMath.SelectDirectives(0, directives, 2)
assert(#selected == 2, "two slots")
assert(selected[1].Definition.Id ~= nil and selected[1].Target >= 1, "slot1 target")
assert(AnomalyOpsMath.SelectDirectives(0, {}, 3)[1] == nil, "empty defs")
assert(AnomalyOpsMath.SelectDirectives(0, nil, 3)[1] == nil, "nil defs")

assert(math.abs(AnomalyOpsMath.RewardMultiplier(1.2, 0.5, 0.1) - (1.2 * 1.5 * 1.1)) < 1e-9, "full multiply")
assert(AnomalyOpsMath.RewardMultiplier(1, 0, nil) == 1, "no channel")

------------------------------------------------------------------------
-- EnsureAnomaly Discoveries rebuild (evidence: Stabilize cloned nil Discoveries)
------------------------------------------------------------------------
local rebuilt = ProfileBagMath.EnsureAnomaly({ Anomaly = { Fragments = 9 } })
assert(rebuilt.Fragments == 9, "keep fragments")
assert(type(rebuilt.Protocols) == "table", "Protocols")
assert(type(rebuilt.Discoveries) == "table", "Discoveries rebuild")
assert(type(rebuilt.DirectiveProgress) == "table", "DirectiveProgress rebuild")
assert(type(rebuilt.DirectiveClaims) == "table", "DirectiveClaims rebuild")
assert(type(rebuilt.MilestoneClaims) == "table", "MilestoneClaims rebuild")
assert(ProfileBagMath.EnsureAnomaly({}).Discoveries ~= nil, "nil Anomaly → Discoveries")

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local serviceSrc = fs.readFile("src/Server/AstralForge/Services/AnomalyService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/AnomalyOpsMath.luau")
local bagSrc = fs.readFile("src/Server/AstralForge/Modules/ProfileBagMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(serviceSrc, "AnomalyOpsMath.FindProtocol", 1, true), "FindProtocol wire")
assert(string.find(serviceSrc, "AnomalyOpsMath.ProtocolEffect", 1, true), "ProtocolEffect wire")
assert(string.find(serviceSrc, "AnomalyOpsMath.ChargeTarget", 1, true), "ChargeTarget wire")
assert(string.find(serviceSrc, "AnomalyOpsMath.SelectDirectives", 1, true), "SelectDirectives wire")
assert(string.find(serviceSrc, "AnomalyOpsMath.ProtocolCost", 1, true), "ProtocolCost wire")
assert(string.find(serviceSrc, "AnomalyOpsMath.RewardMultiplier", 1, true), "RewardMultiplier wire")
assert(string.find(serviceSrc, "ProfileBagMath.EnsureAnomaly", 1, true), "EnsureAnomaly wire")
assert(string.find(serviceSrc, "ProfileBagMath.BumpStat", 1, true), "BumpStat wire")
assert(string.find(bagSrc, "Discoveries = {}", 1, true), "EnsureAnomaly seeds Discoveries")
assert(string.find(bagSrc, "MilestoneClaims", 1, true), "EnsureAnomaly seeds MilestoneClaims")
assert(not string.find(mathSrc, "GetService", 1, true), "AnomalyOpsMath must stay pure")
assert(not string.find(mathSrc, "vendor/", 1, true), "no vendor/")
assert(not string.find(mathSrc, "Packages/", 1, true), "no Packages/")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

assert(string.find(configSrc, "Wave16AnomalyOps", 1, true), "DV21 lab Wave16AnomalyOps")
assert(string.find(configSrc, "Wave16ClaimClipsSoftMotion", 1, true), "DV21 lab Wave16ClaimClipsSoftMotion")
assert(string.find(configSrc, "Wave16AnomalyCourier", 1, true), "DV21 achievement Wave16AnomalyCourier")
assert(string.find(configSrc, "wave16-harden-brief", 1, true), "DV21 story wave16")
assert(string.find(configSrc, "update-5-1-wave16-harden", 1, true), "DV21 mail wave16")

print("[INFO] [TEST] AnomalyOpsMath extract + Fragments-only EnsureAnomaly + DV21 append passed")
