--!strict
-- Wave20 monolith split guards: NetworkPolicy (MainGame), PageBoardHeights +
-- PageReadyMath.AnomalyReady/OpsClaims (PageRouter), TelemetryMath + UtcClockMath
-- (ServerServices), EconomyEnvelopeMath grid/item/artifact thinning.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local NetworkPolicy = require("../src/Client/AstralForge/networkPolicy")
local PageBoardHeights = require("../src/Client/AstralForge/pageBoardHeights")
local PageReadyMath = require("../src/Client/AstralForge/pageReadyMath")
local InventoryMath = require("../src/Client/AstralForge/inventoryMath")
local TelemetryMath = require("../src/Server/AstralForge/Modules/TelemetryMath")
local UtcClockMath = require("../src/Server/AstralForge/Modules/UtcClockMath")
local EconomyEnvelopeMath = require("../src/Server/AstralForge/Modules/EconomyEnvelopeMath")
local DataSanitizeMath = require("../src/Server/AstralForge/Modules/DataSanitizeMath")

-- --- NetworkPolicy -------------------------------------------------------------
assert(NetworkPolicy.Cooldown("CollectVault") == 0.04, "collect cooldown")
assert(NetworkPolicy.Cooldown("MissingAction") == NetworkPolicy.DEFAULT_COOLDOWN, "default cooldown")
assert(NetworkPolicy.Timeout("GetState") == 8, "getstate timeout")
assert(NetworkPolicy.Timeout("BuyMachine") == NetworkPolicy.DEFAULT_TIMEOUT, "default timeout")
assert(NetworkPolicy.IsPipelined("Overcharge") == true, "pipelined overcharge")
assert(NetworkPolicy.IsPipelined("BuyMachine") == false, "serial buy")
assert(NetworkPolicy.IsOptimistic("CollectVault") == true, "optimistic collect")
assert(NetworkPolicy.IsOptimistic("OpenItemCrate") == false, "crate not optimistic")
assert(NetworkPolicy.RequestLimit(true) == 4 and NetworkPolicy.RequestLimit(false) == 2, "request limits")
assert(NetworkPolicy.IsCoolingDown(1.05, 1.0, 0.1) == true, "cooling down")
assert(NetworkPolicy.IsCoolingDown(1.2, 1.0, 0.1) == false, "cooled")
assert(NetworkPolicy.MAX_PHYSICAL_REQUESTS == 12, "max physical")

-- --- PageBoardHeights ----------------------------------------------------------
assert(PageBoardHeights.Machine(false) == 120, "machine desk")
assert(PageBoardHeights.Machine(true) == 188, "machine stack")
assert(PageBoardHeights.World(false) == 148 and PageBoardHeights.World(true) == 218, "world heights")
assert(PageBoardHeights.Visit(false) == 268 and PageBoardHeights.Visit(true) == 380, "visit heights")

-- --- PageReadyMath anomaly / ops ----------------------------------------------
assert(PageReadyMath.AnomalyReady(nil) == false, "nil anomaly")
assert(PageReadyMath.AnomalyReady({ Ready = true }) == true, "ready flag")
assert(PageReadyMath.AnomalyReady({
	Directives = {
		{ Claimed = false, Progress = 3, Target = 3 },
	},
}) == true, "met directive")
assert(PageReadyMath.AnomalyReady({
	Directives = {
		{ Claimed = true, Progress = 9, Target = 3 },
		{ Claimed = false, Progress = 1, Target = 5 },
	},
}) == false, "no ready directive")
assert(PageReadyMath.OpsClaims(2, 1, true, true) == 5, "ops claims sum")
assert(PageReadyMath.OpsClaims(0, 0, false, false) == 0, "ops claims empty")

-- --- TelemetryMath -------------------------------------------------------------
assert(TelemetryMath.Number(math.huge) == 0, "inf → 0")
assert(TelemetryMath.Number("12.5") == 12.5, "string number")
assert(TelemetryMath.Number(1e40) == TelemetryMath.FLOAT_MAX, "clamp high")
assert(TelemetryMath.SettingsFlags({
	ReducedMotion = true,
	UIEffects = true,
	SoundEffects = false,
	HideOtherPlots = true,
}) == bit32.bor(1, 2, 8), "settings flags")
local packed = TelemetryMath.Encode(3, { ReducedMotion = true }, 10, 20, 30, 40, 5, 6)
assert(buffer.len(packed) == TelemetryMath.BYTES, "telemetry bytes")
assert(buffer.readu8(packed, 0) == TelemetryMath.VERSION, "telemetry version")
assert(buffer.readu8(packed, 1) == 1, "reduced motion flag only")
assert(buffer.readu32(packed, 2) == 3, "revision")
assert(math.abs(buffer.readf32(packed, 6) - 10) < 1e-5, "cash f32")
assert(math.abs(buffer.readf32(packed, 26) - 6) < 1e-5, "stardust f32")

-- --- UtcClockMath --------------------------------------------------------------
assert(UtcClockMath.Day(0) == 0, "epoch day")
assert(UtcClockMath.Day(86_400) == 1, "day 1")
assert(UtcClockMath.NextMidnight(86_400 * 2 + 100) == 86_400 * 3, "next midnight")

-- --- EconomyEnvelopeMath grid / artifact / effect ------------------------------
local def = { BaseEffect = 0.1, LevelGrowth = 0.05 }
assert(math.abs(EconomyEnvelopeMath.EffectAtLevel(def, 3) - 0.1 * 1.1) < 1e-9, "effect at level")
assert(math.abs(EconomyEnvelopeMath.EffectAtLevel(def, 3) - InventoryMath.EffectAtLevel(def, 3)) < 1e-9, "inv parity")
assert(EconomyEnvelopeMath.ArtifactLevelEffect({ EffectKind = "Tap", EffectPerLevel = 0.02 }, { Level = 4 }, "Tap") == 0.08, "artifact")
assert(EconomyEnvelopeMath.ArtifactLevelEffect({ EffectKind = "Tap", EffectPerLevel = 0.02 }, { Level = 4 }, "Prod") == 0, "artifact miss")
local gridById = {
	A = { EffectKind = "GridCritical", EffectPerLevel = 0.01 },
	B = { EffectKind = "GridAutomation", EffectPerLevel = 0.02 },
}
assert(math.abs(EconomyEnvelopeMath.GridEffect({ A = 3, B = 2 }, gridById, "GridCritical") - 0.03) < 1e-9, "grid effect")

-- --- DataSanitizeMath DeepCopy residual (ServerServices copyDictionary) --------
local src = { a = 1, nested = { b = 2 } }
local copy = DataSanitizeMath.DeepCopy(src)
assert(copy.a == 1 and copy.nested.b == 2 and copy ~= src and copy.nested ~= src.nested, "deepcopy")

-- --- InventoryMath.RarityColor -------------------------------------------------
local colorFallback = "muted"
assert(InventoryMath.RarityColor({ Items = { Rarities = { Rare = { Color = "pink" } } } }, "Rare", colorFallback) == "pink", "rarity color")
assert(InventoryMath.RarityColor({}, "Rare", colorFallback) == colorFallback, "rarity fallback")

-- --- Source wiring + HARD constraints -----------------------------------------
local mainSrc = fs.readFile("src/Client/AstralForge/MainGame.luau")
local routerSrc = fs.readFile("src/Client/AstralForge/pages/PageRouter.luau")
local ssSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local econSrc = fs.readFile("src/Server/AstralForge/Modules/Economy.luau")
local invSrc = fs.readFile("src/Client/AstralForge/pages/InventoryView.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(mainSrc, "NetworkPolicy.Cooldown", 1, true), "MainGame NetworkPolicy.Cooldown")
assert(string.find(mainSrc, "NetworkPolicy.IsPipelined", 1, true), "MainGame IsPipelined")
assert(string.find(mainSrc, "require(script.Parent.networkPolicy)", 1, true), "MainGame require networkPolicy")
assert(string.find(routerSrc, "PageBoardHeights.Machine", 1, true), "PageRouter board heights")
assert(string.find(routerSrc, "PageReadyMath.AnomalyReady", 1, true), "PageRouter AnomalyReady")
local overviewSrc = fs.readFile("src/Client/AstralForge/pages/OverviewView.luau")
assert(string.find(overviewSrc, "PageReadyMath.OpsClaims", 1, true), "OverviewView OpsClaims")
assert(string.find(ssSrc, "TelemetryMath.Encode", 1, true), "ServerServices TelemetryMath")
assert(string.find(ssSrc, "UtcClockMath.Day", 1, true), "ServerServices UtcClockMath")
assert(string.find(ssSrc, "DataSanitizeMath.DeepCopy", 1, true), "ServerServices DeepCopy")
assert(string.find(econSrc, "EconomyEnvelopeMath.GridEffect", 1, true), "Economy GridEffect residual")
assert(
	string.find(econSrc, "EconomyEnvelopeMath.ItemEffect", 1, true) ~= nil
		or string.find(econSrc, "EconomyEnvelopeMath.EffectAtLevel", 1, true) ~= nil,
	"Economy EffectAtLevel residual"
)
assert(string.find(econSrc, "EconomyEnvelopeMath.ArtifactLevelEffect", 1, true), "Economy Artifact residual")
assert(string.find(invSrc, "InventoryMath.RarityColor", 1, true), "InventoryView RarityColor")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in {
	mainSrc,
	routerSrc,
	ssSrc,
	econSrc,
	invSrc,
	fs.readFile("src/Client/AstralForge/networkPolicy.luau"),
	fs.readFile("src/Client/AstralForge/pageBoardHeights.luau"),
	fs.readFile("src/Server/AstralForge/Modules/TelemetryMath.luau"),
	fs.readFile("src/Server/AstralForge/Modules/UtcClockMath.luau"),
} do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] wave20 monolith split pure checks passed")
