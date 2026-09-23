--!strict
-- Pure-module extract guards: MainGame actionCopy/boostIconKind + ServerServices
-- SocialBoost / ItemSalvage / OverchargeCombo / RankBracket / ActionFeatureMaps /
-- ActionResponse / GeneralBoardValue. Mirrors verify_serverservices_extract style.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local ActionCopy = require("../src/Client/AstralForge/actionCopy")
local BoostIconKind = require("../src/Client/AstralForge/boostIconKind")
local SocialBoost = require("../src/Server/AstralForge/Modules/SocialBoost")
local ItemSalvage = require("../src/Server/AstralForge/Modules/ItemSalvage")
local OverchargeCombo = require("../src/Server/AstralForge/Modules/OverchargeCombo")
local RankBracket = require("../src/Server/AstralForge/Modules/RankBracket")
local ActionFeatureMaps = require("../src/Server/AstralForge/Modules/ActionFeatureMaps")
local ActionResponse = require("../src/Server/AstralForge/Modules/ActionResponse")
local GeneralBoardValue = require("../src/Server/AstralForge/Modules/GeneralBoardValue")

-- --- ActionCopy ----------------------------------------------------------------
assert(ActionCopy.friendlyPlayerMessage(nil) == nil, "nil message")
assert(ActionCopy.friendlyPlayerMessage("") == nil, "empty message")
assert(
	ActionCopy.friendlyPlayerMessage("invalid action payload") == "That option isn't available.",
	"payload rewrite"
)
assert(
	ActionCopy.friendlyPlayerMessage("Action Rejected.") == "That move isn't available right now.",
	"case-insensitive rewrite"
)
assert(ActionCopy.friendlyPlayerMessage("Custom server text") == "Custom server text", "passthrough")
assert(ActionCopy.failureTitle("BuyMachine", true) == "Still locked", "gated title")
assert(ActionCopy.failureTitle("VerifyCreatorFollow", false) == "Follow", "follow title")
assert(ActionCopy.failureTitle("ClaimDaily", false) == "Couldn't claim", "claim prefix")
assert(ActionCopy.failureTitle("WeirdAction", false) == "Couldn't do that", "fallback title")
assert(
	ActionCopy.failureBody("BuyMachine", "invalid action payload") == "That station isn't available.",
	"action-specific body"
)
assert(
	ActionCopy.failureBody("UnknownThing", "invalid action payload.") == "That option isn't available.",
	"default body"
)
assert(ActionCopy.failureBody("RedeemCode", "Enter a code first.") == "Enter a code first.", "friendly passthrough")
local same = { ok = true, message = "ok", error = nil }
assert(ActionCopy.friendlyActionResponse(same) == same, "unchanged response identity")
local rewritten = ActionCopy.friendlyActionResponse({
	ok = false,
	message = "action rejected.",
	error = "invalid action payload",
})
assert(rewritten.message == "That move isn't available right now.", "response message rewrite")
assert(rewritten.error == "That option isn't available.", "response error rewrite")
assert(rewritten.ok == false, "response ok preserved")

-- --- BoostIconKind -------------------------------------------------------------
assert(BoostIconKind.of("DomainSurge") == "Domain", "domain boost icon")
assert(BoostIconKind.of("VaultSurge") == "Vault", "vault boost icon")
assert(BoostIconKind.of("Hyperdrive") == "World", "hyperdrive icon")
assert(BoostIconKind.of("Other") == "Reactor", "default icon")
assert(BoostIconKind.of(nil) == "Reactor", "nil icon")

-- --- SocialBoost ---------------------------------------------------------------
local socialCfg = {
	MaxBoostedFriends = 5,
	FriendProductionPerPlayer = 0.05,
	PremiumProductionBonus = 0.15,
}
local computed = SocialBoost.Compute(3, true, socialCfg)
assert(computed.FriendCount == 3 and computed.FriendLimit == 5, "friend clamp")
assert(math.abs(computed.FriendBonus - 0.15) < 1e-9 and math.abs(computed.PremiumBonus - 0.15) < 1e-9, "bonuses")
assert(math.abs(computed.Multiplier - 1.3) < 1e-9, "multiplier")
local capped = SocialBoost.Compute(99, false, socialCfg)
assert(capped.FriendCount == 5 and capped.Premium == false and capped.PremiumBonus == 0, "cap + no premium")
local profile = { SocialBoost = nil }
assert(SocialBoost.Apply(profile, 2, true, socialCfg) == true, "first apply changes")
assert(SocialBoost.Apply(profile, 2, true, socialCfg) == false, "same apply no change")
assert(math.abs(profile.SocialBoost.Multiplier - (1 + 0.1 + 0.15)) < 1e-9, "profile bag")

-- --- ItemSalvage ---------------------------------------------------------------
assert(ItemSalvage.Value(1, 1) == 8, "common L1")
assert(ItemSalvage.Value(3, 2) == 2 * 2 * 8 + 2 * 2 * 3, "uncommon L3")
assert(ItemSalvage.Value(1, nil) == 8, "nil rank → 1")
assert(ItemSalvage.Value(nil, 4) == 128, "nil level → 1 → rank^2*8")

-- --- OverchargeCombo -----------------------------------------------------------
assert(OverchargeCombo.Window(1.8) == 1.8, "window passthrough")
assert(OverchargeCombo.Multiplier(0, 12, 0.045) == 1, "zero combo")
assert(OverchargeCombo.Multiplier(4, 12, 0.045) == 1 + 4 * 0.045, "mid combo")
assert(OverchargeCombo.Multiplier(99, 12, 0.045) == 1 + 12 * 0.045, "capped combo")
assert(OverchargeCombo.NextCombo(11, 12) == 12, "next at max")
assert(OverchargeCombo.NextCombo(12, 12) == 12, "stay at max")
assert(OverchargeCombo.Expired(1.9, 1.8) == true, "expired")
assert(OverchargeCombo.Expired(1.8, 1.8) == false, "not expired at boundary")

-- --- RankBracket ---------------------------------------------------------------
assert(RankBracket.Of(1) == 1, "top bracket")
assert(RankBracket.Of(2) == 3, "top-3")
assert(RankBracket.Of(10) == 10, "top-10")
assert(RankBracket.Of(25) == 25, "top-25")
assert(RankBracket.Of(26) == RankBracket.UNRANKED, "unranked")
assert(RankBracket.ShouldAnnounce(0, 1) == false, "unseeded")
assert(RankBracket.ShouldAnnounce(5, 8) == false, "rank worsened")
assert(RankBracket.ShouldAnnounce(5, 3) == true, "crossed into top-3")
assert(RankBracket.ShouldAnnounce(3, 2) == false, "same top-3 bracket")
assert(RankBracket.ShouldAnnounce(30, 20) == true, "crossed into top-25")
assert(RankBracket.ShouldAnnounce(2, 1) == true, "crossed into top-1")

-- --- ActionFeatureMaps ---------------------------------------------------------
assert(ActionFeatureMaps.AnomalyCharge("CollectVault") == 8, "collect charge")
assert(ActionFeatureMaps.AnomalyCharge("Rebirth") == 24, "rebirth charge")
assert(ActionFeatureMaps.AnomalyCharge("GetState") == nil, "no charge")
assert(ActionFeatureMaps.AnomalySignal("BuyMachine") == "Upgrade", "upgrade signal")
assert(ActionFeatureMaps.AnomalySignal("ClaimDaily") == "Reward", "reward signal")
assert(ActionFeatureMaps.FeatureId("VisitPlot") == "Crew", "crew feature")
assert(ActionFeatureMaps.FeatureId("PulseAnomaly") == "Anomaly", "anomaly feature")
assert(ActionFeatureMaps.FeatureId("BuyMachine") == nil, "buy machine not gated")

-- --- ActionResponse ------------------------------------------------------------
local err = ActionResponse.Error("Nope")
assert(err.ok == false and err.error == "Nope", "error envelope")
local extra = { Amount = 10 }
local okResp = ActionResponse.Success("Banked", extra)
assert(okResp.ok == true and okResp.message == "Banked" and okResp.Amount == 10, "success mutates extra")
assert(extra.ok == true, "extra table mutated in place")
local bare = ActionResponse.Success(nil)
assert(bare.ok == true and bare.message == nil, "bare success")

-- --- GeneralBoardValue ---------------------------------------------------------
local persist = function(value)
	return tonumber(value) or 0
end
local boardProfile = {
	LifetimeCash = 12345,
	Rebirths = 7.9,
	Stats = { PlayTime = 3600.2 },
	Stardust = 42,
	Cores = 9,
	Domain = { Rank = 3 },
	Zone = 4,
}
assert(GeneralBoardValue.Of(boardProfile, "Flux", persist) == 12345, "flux board")
assert(GeneralBoardValue.Of(boardProfile, "Rebirths", persist) == 7, "rebirths floor")
assert(GeneralBoardValue.Of(boardProfile, "PlayTime", persist) == 3600, "playtime")
assert(GeneralBoardValue.Of(boardProfile, "Dust", persist) == 42, "dust")
assert(GeneralBoardValue.Of(boardProfile, "Cores", persist) == 9, "cores")
assert(GeneralBoardValue.Of(boardProfile, "Domain", persist) == 3, "domain")
assert(GeneralBoardValue.Of(boardProfile, "Worlds", persist) == 4, "worlds")
assert(GeneralBoardValue.Of({}, "Worlds", persist) == 1, "worlds default")
assert(GeneralBoardValue.Of({}, "Unknown", persist) == 0, "unknown board")

-- --- Wiring + HARD gates -------------------------------------------------------
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local mainSrc = fs.readFile("src/Client/AstralForge/MainGame.luau")
local topBarChromeSrc = fs.readFile("src/Client/AstralForge/TopBarChrome.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(mainSrc, 'require(script.Parent.actionCopy)', 1, true), "MainGame requires actionCopy")
assert(string.find(topBarChromeSrc, 'require(script.Parent.boostIconKind)', 1, true), "TopBarChrome requires boostIconKind")
assert(string.find(mainSrc, "ActionCopy.friendlyPlayerMessage", 1, true), "MainGame wires friendlyPlayerMessage")
assert(string.find(topBarChromeSrc, "BoostIconKind.of", 1, true), "TopBarChrome wires BoostIconKind")
assert(not string.find(mainSrc, 'local PLAYER_COPY = {', 1, true), "inline PLAYER_COPY removed")
assert(not string.find(mainSrc, "local FAILURE_TITLE_PREFIXES = {", 1, true), "inline FAILURE_TITLE_PREFIXES removed")

assert(string.find(servicesSrc, 'WaitForChild("SocialBoost")', 1, true), "ServerServices requires SocialBoost")
assert(string.find(servicesSrc, 'WaitForChild("ItemSalvage")', 1, true), "ServerServices requires ItemSalvage")
assert(string.find(servicesSrc, 'WaitForChild("OverchargeCombo")', 1, true), "ServerServices requires OverchargeCombo")
assert(string.find(servicesSrc, 'WaitForChild("RankBracket")', 1, true), "ServerServices requires RankBracket")
assert(string.find(servicesSrc, 'WaitForChild("ActionFeatureMaps")', 1, true), "ServerServices requires ActionFeatureMaps")
assert(string.find(servicesSrc, 'WaitForChild("ActionResponse")', 1, true), "ServerServices requires ActionResponse")
assert(string.find(servicesSrc, 'WaitForChild("GeneralBoardValue")', 1, true), "ServerServices requires GeneralBoardValue")
assert(string.find(servicesSrc, "SocialBoost.Apply", 1, true), "delegates SocialBoost.Apply")
assert(string.find(servicesSrc, "ItemSalvage.Value", 1, true), "delegates ItemSalvage.Value")
assert(string.find(servicesSrc, "OverchargeCombo.Multiplier", 1, true), "delegates OverchargeCombo")
assert(string.find(servicesSrc, "RankBracket.ShouldAnnounce", 1, true), "delegates RankBracket")
assert(string.find(servicesSrc, "ActionFeatureMaps.ANOMALY_CHARGE", 1, true), "uses ANOMALY_CHARGE")
assert(string.find(servicesSrc, "ActionResponse.Error", 1, true), "delegates ActionResponse.Error")
assert(string.find(servicesSrc, "GeneralBoardValue.Of", 1, true), "delegates GeneralBoardValue.Of")
assert(not string.find(servicesSrc, "local anomalyChargeByAction = {", 1, true), "inline anomaly charge removed")
assert(not string.find(servicesSrc, "local featureByAction = {", 1, true), "inline feature map removed")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

local pureFiles = {
	"src/Client/AstralForge/actionCopy.luau",
	"src/Client/AstralForge/boostIconKind.luau",
	"src/Server/AstralForge/Modules/SocialBoost.luau",
	"src/Server/AstralForge/Modules/ItemSalvage.luau",
	"src/Server/AstralForge/Modules/OverchargeCombo.luau",
	"src/Server/AstralForge/Modules/RankBracket.luau",
	"src/Server/AstralForge/Modules/ActionFeatureMaps.luau",
	"src/Server/AstralForge/Modules/ActionResponse.luau",
	"src/Server/AstralForge/Modules/GeneralBoardValue.luau",
}
for _, path in pureFiles do
	local body = fs.readFile(path)
	assert(not string.find(body, "vendor/", 1, true), path .. " must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), path .. " must not reference Packages/")
	assert(not string.find(body, "GetService", 1, true), path .. " must not call GetService")
end
for _, body in { servicesSrc, mainSrc } do
	assert(not string.find(body, "vendor/", 1, true), "callers must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "callers must not reference Packages/")
end

print(
	"[INFO] [TEST] split-maingame-ss extract passed | ActionCopy+BoostIconKind+SocialBoost+ItemSalvage+OverchargeCombo+RankBracket+ActionFeatureMaps+ActionResponse+GeneralBoardValue"
)
