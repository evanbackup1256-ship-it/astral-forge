--!strict
-- Pure-module extract guards: TradeOfferMath (EmptyOffer / CopyOffer / OfferEmpty /
-- BoostTotal / KeyTotal / EnsureLedger / ItemEquipped / CountInventory).
-- Evidence: TradeDesk inlined offer coerce + daily ledger; string/nil bags and
-- empty-offer Ready checks needed Lune coverage without Studio.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local TradeOfferMath = require("../src/Server/AstralForge/Modules/TradeOfferMath")
local TradeExchange = require("../src/Server/AstralForge/Modules/TradeExchange")

local CURRENCIES = TradeExchange.CURRENCIES
local BOOST_IDS = TradeExchange.BOOST_IDS
local KEY_IDS = TradeExchange.KEY_IDS

------------------------------------------------------------------------
-- EmptyOffer / CopyOffer
------------------------------------------------------------------------
local empty = TradeOfferMath.EmptyOffer(BOOST_IDS, KEY_IDS)
assert(empty.Cash == 0 and empty.Stardust == 0, "empty currencies")
assert(empty.Boosts.Overdrive == 0 and empty.Keys.ForgeCrate == 0, "empty boost/key")
assert(#empty.ItemIds == 0, "empty items")

local copied = TradeOfferMath.CopyOffer({
	Cash = 12.7,
	Stardust = -3,
	Boosts = { Overdrive = 2.4, Afterburner = "x" },
	Keys = { ForgeCrate = 1 },
	ItemIds = { "a", "a", "", 9, "b" },
	Items = { { Uid = "a", DefinitionId = "RelicA", Name = "Alpha" } },
}, CURRENCIES, BOOST_IDS, KEY_IDS)
assert(copied.Cash == 12 and copied.Stardust == 0, "coerce cash/stardust")
assert(copied.Boosts.Overdrive == 2 and copied.Boosts.Afterburner == 0, "coerce boosts")
assert(copied.Keys.ForgeCrate == 1, "coerce keys")
assert(#copied.ItemIds == 2 and copied.ItemIds[1] == "a" and copied.ItemIds[2] == "b", "dedupe items")
assert(copied.Items[1].Name == "Alpha", "stamp rows kept")
assert(TradeOfferMath.CopyOffer(nil, CURRENCIES, BOOST_IDS, KEY_IDS).Cash == 0, "nil → empty")

------------------------------------------------------------------------
-- OfferEmpty / BoostTotal / KeyTotal
------------------------------------------------------------------------
assert(TradeOfferMath.OfferEmpty(empty, CURRENCIES, BOOST_IDS, KEY_IDS) == true, "empty is empty")
assert(TradeOfferMath.OfferEmpty(copied, CURRENCIES, BOOST_IDS, KEY_IDS) == false, "copied not empty")
assert(TradeOfferMath.OfferEmpty(nil, CURRENCIES, BOOST_IDS, KEY_IDS) == true, "nil offer empty")
assert(TradeOfferMath.BoostTotal(copied, BOOST_IDS) == 2, "boost total")
assert(TradeOfferMath.BoostTotal(nil, BOOST_IDS) == 0, "nil boost total")
assert(TradeOfferMath.KeyTotal(copied, KEY_IDS) == 1, "key total")
assert(TradeOfferMath.KeyTotal({ Keys = {} }, KEY_IDS) == 0, "empty keys")

------------------------------------------------------------------------
-- EnsureLedger / ItemEquipped / CountInventory
------------------------------------------------------------------------
local profile = {}
TradeOfferMath.EnsureLedger(profile, 1_700_000_000)
assert(type(profile.Trade) == "table", "Trade bag")
assert(type(profile.Trade.Sent) == "table", "Sent bag")
local day = profile.Trade.Day
profile.Trade.Completed = 3
profile.Trade.Sent.Cash = 99
TradeOfferMath.EnsureLedger(profile, 1_700_000_000)
assert(profile.Trade.Completed == 3 and profile.Trade.Sent.Cash == 99, "same day keeps ledger")
-- Force a day roll by rewriting Day backward.
profile.Trade.Day = day - 1
TradeOfferMath.EnsureLedger(profile, 1_700_000_000)
assert(profile.Trade.Completed == 0 and profile.Trade.Sent.Cash == 0, "day roll resets")
assert(profile.Trade.Day == day, "day restored")

assert(TradeOfferMath.ItemEquipped({ Items = { Equipped = { "u1", "u2" } } }, "u2") == true, "equipped")
assert(TradeOfferMath.ItemEquipped({ Items = { Equipped = { "u1" } } }, "u9") == false, "not equipped")
assert(TradeOfferMath.ItemEquipped({}, "u1") == false, "nil bags")
assert(TradeOfferMath.CountInventory({ Items = { Inventory = { a = {}, b = {} } } }) == 2, "count")
assert(TradeOfferMath.CountInventory({}) == 0, "nil inventory")

------------------------------------------------------------------------
-- Wire + HARD constraints
------------------------------------------------------------------------
local deskSrc = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/TradeOfferMath.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(string.find(deskSrc, "TradeOfferMath.CopyOffer", 1, true), "TradeDesk CopyOffer wire")
assert(string.find(deskSrc, "TradeOfferMath.EnsureLedger", 1, true), "TradeDesk EnsureLedger wire")
assert(string.find(deskSrc, "TradeOfferMath.OfferEmpty", 1, true), "TradeDesk OfferEmpty wire")
assert(string.find(deskSrc, "TradeOfferMath.BoostTotal", 1, true), "TradeDesk BoostTotal wire")
assert(not string.find(mathSrc, "GetService", 1, true), "TradeOfferMath must stay pure")
assert(not string.find(mathSrc, "vendor/", 1, true), "no vendor/")
assert(not string.find(mathSrc, "Packages/", 1, true), "no Packages/")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

assert(string.find(configSrc, "Wave20TradeOfferCoreXP", 1, true), "DV21 lab Wave20TradeOfferCoreXP")
assert(string.find(configSrc, "Wave20ClaimClipsSoftMotion", 1, true), "DV21 lab Wave20ClaimClipsSoftMotion")
assert(string.find(configSrc, "Wave20TradeCourier", 1, true), "DV21 achievement Wave20TradeCourier")
assert(string.find(configSrc, "wave20-harden-brief", 1, true), "DV21 story wave20")
assert(string.find(configSrc, "update-5-1-wave20-harden", 1, true), "DV21 mail wave20")

print("[INFO] [TEST] TradeOfferMath extract + TradeDesk wire + DV21 append passed")
