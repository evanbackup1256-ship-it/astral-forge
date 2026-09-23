--!strict
-- Pure-module extract guards: RemoteFirewallMath + DataSanitizeMath wiring.
-- Replaces inline coerce/extract/cooldown replicas in older residual gates.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local RemoteFirewallMath = require("../src/Server/AstralForge/Modules/RemoteFirewallMath")
local DataSanitizeMath = require("../src/Server/AstralForge/Modules/DataSanitizeMath")

------------------------------------------------------------------------
-- RemoteFirewallMath
------------------------------------------------------------------------
assert(RemoteFirewallMath.Integer(3) == true, "integer ok")
assert(RemoteFirewallMath.Integer(1.5) == false, "reject float")
assert(RemoteFirewallMath.SafeNumber(42) == true, "safe number")
assert(RemoteFirewallMath.SafeNumber(math.huge) == false, "reject inf")
assert(RemoteFirewallMath.CoerceUserId(42) == 42, "positive id ok")
assert(RemoteFirewallMath.CoerceUserId(" 99 ") == 99, "trimmed string id ok")
assert(RemoteFirewallMath.CoerceUserId(0) == nil, "zero rejected")
assert(RemoteFirewallMath.CoerceUserId(1.5) == nil, "non-integer rejected")
assert(RemoteFirewallMath.CoerceUserId(-3) == nil, "live negative rejected")
assert(RemoteFirewallMath.CoerceUserId(-3, true) == -3, "Studio negative allowed")
assert(RemoteFirewallMath.CoerceUserId("nope") == nil, "garbage string rejected")
assert(RemoteFirewallMath.ExtractUserId({ TargetUserId = 7 }) == 7, "TargetUserId extracted")
assert(RemoteFirewallMath.ExtractUserId({ userId = "8" }) == "8", "userId extracted")
assert(
	RemoteFirewallMath.CoerceUserId(RemoteFirewallMath.ExtractUserId({ UserId = "12" })) == 12,
	"coerce∘extract roundtrip"
)
assert(RemoteFirewallMath.CooldownKey("OpenItemCrate", nil) == "OpenItemCrate", "nil payload → action")
assert(RemoteFirewallMath.CooldownKey("OpenItemCrate", {}) == "OpenItemCrate", "empty payload → action")
assert(
	RemoteFirewallMath.CooldownKey("ToggleItemLock", { Uid = "abc", Level = 2 })
		== "ToggleItemLock:Uid=abc|Level=2",
	"cooldown key fields"
)
assert(RemoteFirewallMath.StringField({ Code = "HELLO" }, "Code", 1, 16) == true, "string field ok")
assert(RemoteFirewallMath.StringField({ Code = "" }, "Code", 1, 16) == false, "string field short")
assert(RemoteFirewallMath.NumberField({ Amount = 3 }, "Amount", 1, 10, true) == true, "number field ok")
assert(RemoteFirewallMath.NumberField({ Amount = 1.5 }, "Amount", 1, 10, true) == false, "number field int")
assert(
	RemoteFirewallMath.StringArrayField({ Uids = { "a", "bb" } }, "Uids", 4, 1, 8) == true,
	"string array ok"
)
assert(
	RemoteFirewallMath.StringArrayField({ Uids = { "a", "bb", "c", "d", "e" } }, "Uids", 4, 1, 8) == false,
	"string array over"
)

------------------------------------------------------------------------
-- DataSanitizeMath
------------------------------------------------------------------------
assert(DataSanitizeMath.NonNegative(-3) == 0, "nonneg clamps floor")
assert(DataSanitizeMath.NonNegative(math.huge) == 0, "nonneg rejects inf")
assert(DataSanitizeMath.NonNegative(12.5) == 12.5, "nonneg keeps finite")
assert(DataSanitizeMath.NonNegative(99, 10) == 10, "nonneg ceiling")
local nested = DataSanitizeMath.DeepCopy({ a = { b = 1 } })
assert(nested.a.b == 1 and nested.a ~= nil, "deepcopy nested")
nested.a.b = 9
local src = { a = { b = 1 } }
local copy = DataSanitizeMath.DeepCopy(src)
assert(copy.a.b == 1 and src.a.b == 1 and copy.a ~= src.a, "deepcopy isolates")
local target = { Cash = "1e3", Cores = nil, Bag = { X = 1 } }
DataSanitizeMath.Reconcile(target, { Cash = 0, Cores = 2, Bag = { X = 0, Y = 3 }, Extra = 4 })
assert(target.Cash == "1e3", "reconcile keeps Omega string over number template")
assert(target.Cores == 2, "reconcile fills nil")
assert(target.Bag.Y == 3 and target.Bag.X == 1, "reconcile nested fill")
assert(target.Extra == 4, "reconcile top-level fill")

------------------------------------------------------------------------
-- Service wiring residuals
------------------------------------------------------------------------
local firewallSrc = fs.readFile("src/Server/AstralForge/Services/RemoteFirewall.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(firewallSrc, "RemoteFirewallMath.CoerceUserId", 1, true), "Firewall CoerceUserId residual")
assert(string.find(firewallSrc, "RemoteFirewallMath.ExtractUserId", 1, true), "Firewall ExtractUserId residual")
assert(string.find(firewallSrc, "RemoteFirewallMath.CooldownKey", 1, true), "Firewall CooldownKey residual")
assert(string.find(firewallSrc, "RemoteFirewallMath.StringField", 1, true), "Firewall StringField residual")
assert(string.find(firewallSrc, "RemoteFirewallMath.NumberField", 1, true), "Firewall NumberField residual")
assert(string.find(firewallSrc, "RemoteFirewallMath.Inspect", 1, true), "Firewall Inspect residual")
assert(string.find(firewallSrc, "BulkSalvageItems", 1, true), "Firewall BulkSalvage residual")
assert(string.find(firewallSrc, "SetItemAutoSalvage", 1, true), "Firewall AutoSalvage residual")
assert(string.find(dataSrc, "DataSanitizeMath.DeepCopy", 1, true), "DataService DeepCopy residual")
assert(string.find(dataSrc, "DataSanitizeMath.Reconcile", 1, true), "DataService Reconcile residual")
assert(string.find(dataSrc, "DataSanitizeMath.NonNegative", 1, true), "DataService NonNegative residual")
assert(string.find(dataSrc, "DataSanitizeMath.ClampLevelBag", 1, true), "DataService ClampLevelBag residual")
assert(string.find(dataSrc, "ProfileBagMath.EnsureAutoSalvage", 1, true), "DataService EnsureAutoSalvage residual")
assert(string.find(dataSrc, "ForgeEchoMath.Ensure", 1, true) or string.find(dataSrc, "ForgeEchoMath.Sanitize", 1, true), "DataService ForgeEcho residual")

assert(string.find(fs.readFile("src/Server/AstralForge/Modules/RemoteFirewallMath.luau"), "function RemoteFirewallMath.Inspect", 1, true), "Inspect exported")
assert(string.find(fs.readFile("src/Server/AstralForge/Modules/DataSanitizeMath.luau"), "function DataSanitizeMath.ClampLevelBag", 1, true), "ClampLevelBag exported")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
for _, body in {
	firewallSrc,
	dataSrc,
	fs.readFile("src/Server/AstralForge/Modules/RemoteFirewallMath.luau"),
	fs.readFile("src/Server/AstralForge/Modules/DataSanitizeMath.luau"),
} do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(
	not string.find(fs.readFile("src/Server/AstralForge/Modules/RemoteFirewallMath.luau"), "GetService", 1, true),
	"RemoteFirewallMath must stay pure"
)
assert(
	not string.find(fs.readFile("src/Server/AstralForge/Modules/DataSanitizeMath.luau"), "GetService", 1, true),
	"DataSanitizeMath must stay pure"
)

print("[INFO] [TEST] RemoteFirewallMath + DataSanitizeMath extract guards passed")
