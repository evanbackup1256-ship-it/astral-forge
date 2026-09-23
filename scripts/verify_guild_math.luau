--!strict
-- Pure-module extract guards: GuildMath (upgrade cost/effect, bonuses, contribution,
-- goal target, bank credit/debit). Mirrors verify_anomaly_pulse style.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")
local GuildMath = require("../src/Server/AstralForge/Modules/GuildMath")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label)
end

-- --- Finite / contribution ---------------------------------------------------
assert(GuildMath.FiniteNonNegative(nil) == 0, "nil → 0")
assert(GuildMath.FiniteNonNegative(-3) == 0, "negative → 0")
assert(GuildMath.FiniteNonNegative(math.huge) == 0, "inf → 0")
assert(GuildMath.FiniteNonNegative(12.5) == 12.5, "finite kept")

local okAmt, errAmt = GuildMath.NormalizeContributionAmount(0)
assert(okAmt == nil and errAmt ~= nil, "zero contribution rejected")
okAmt, errAmt = GuildMath.NormalizeContributionAmount(3.9)
assert(okAmt == 3 and errAmt == nil, "contribution floors")
okAmt, errAmt = GuildMath.NormalizeContributionAmount("x")
assert(okAmt == nil, "non-number contribution rejected")

-- --- Upgrade cost / effect ---------------------------------------------------
local flat = { BaseCost = 100, CostScale = 2, EffectPerLevel = 0.05 }
near(GuildMath.UpgradeCost(flat, 0), 100, "flat L0 cost")
near(GuildMath.UpgradeCost(flat, 2), 400, "flat L2 cost = base*scale^2")
near(GuildMath.UpgradeEffect(flat, 0), 0, "L0 effect 0")
near(GuildMath.UpgradeEffect(flat, 3), 0.15, "flat L3 effect")

local tiered = {
	BaseCost = 8_000,
	CostScale = 1.65,
	EffectPerLevel = 0.03,
	Tiers = {
		{ Name = "A", Effect = 0.03, Cost = 8_000 },
		{ Name = "B", Effect = 0.04, Cost = 26_000 },
		{ Name = "C", Effect = 0.05, Cost = 90_000 },
	},
}
near(GuildMath.UpgradeCost(tiered, 0), 8_000, "tier-1 purchase cost")
near(GuildMath.UpgradeCost(tiered, 1), 26_000, "tier-2 purchase cost")
near(GuildMath.UpgradeCost(tiered, 3), math.floor(8_000 * 1.65 ^ 3 + 0.5), "endless-tail cost after tiers")
near(GuildMath.UpgradeEffect(tiered, 2), 0.07, "named tiers cumulative")
near(GuildMath.UpgradeEffect(tiered, 5), 0.03 + 0.04 + 0.05 + 2 * 0.03, "tail after named")
assert(GuildMath.UpgradeTier(tiered, 2).Name == "B", "UpgradeTier index")
assert(GuildMath.UpgradeTier(tiered, 0) == nil, "UpgradeTier below range")

local brokenTier = {
	BaseCost = 10,
	CostScale = 2,
	EffectPerLevel = 0.1,
	Tiers = { { Name = "gap" }, { Name = "ok", Effect = 0.2, Cost = 50 } },
}
near(GuildMath.UpgradeEffect(brokenTier, 1), 0, "missing Effect treated as 0")
near(GuildMath.UpgradeCost(brokenTier, 0), 10, "missing Cost falls back to BaseCost")
near(GuildMath.UpgradeCost(brokenTier, 1), 50, "tier Cost when present")

-- --- Bonuses / goal target ---------------------------------------------------
local empty = GuildMath.EmptyBonuses()
assert(empty.Production == 0 and empty.Tap == 0, "empty bonuses")

local defs = {
	ProductionBoost = { BaseCost = 1, CostScale = 1, EffectPerLevel = 0.03, Bonus = "Production" },
	VaultBoost = {
		BaseCost = 1,
		CostScale = 1,
		EffectPerLevel = 0.05,
		Bonus = "Capacity",
		Tiers = { { Effect = 0.05 }, { Effect = 0.06 } },
	},
}
local bonuses = GuildMath.BonusesFromUpgrades({ ProductionBoost = 2, VaultBoost = 2 }, defs)
near(bonuses.Production, 0.06, "production bonus from levels")
near(bonuses.Capacity, 0.11, "capacity from named tiers")
assert(GuildMath.BonusesFromUpgrades(nil, defs).Production == 0, "nil upgrades → empty")

-- Soft-cap at 1.0
local capped = GuildMath.BonusesFromUpgrades({ ProductionBoost = 100 }, {
	ProductionBoost = { BaseCost = 1, CostScale = 1, EffectPerLevel = 0.5, Bonus = "Production" },
})
near(capped.Production, 1.0, "bonus soft-cap 1.0")

assert(GuildMath.GoalTarget(250_000, 120_000, 1) == 250_000, "solo goal = base")
assert(GuildMath.GoalTarget(250_000, 120_000, 3) == 490_000, "two extra members")
assert(GuildMath.GoalTarget(10, 0, 0) == 10, "zero members still max(1, base)")

-- --- Bank credit / debit / afford --------------------------------------------
assert(GuildMath.CanAffordBank(OmegaMath, "Cash", 100, 50) == true, "cash afford")
assert(GuildMath.CanAffordBank(OmegaMath, "Cash", 40, 50) == false, "cash short")
assert(GuildMath.CanAffordBank(OmegaMath, "Dust", 12, 12) == true, "dust exact")
assert(GuildMath.CanAffordBank(OmegaMath, "Dust", 11, 12) == false, "dust short")

near(OmegaMath.ToNumber(GuildMath.CreditBank(OmegaMath, "Cash", 100, 25)), 125, "cash credit")
near(GuildMath.CreditBank(OmegaMath, "Dust", 10, 5) :: number, 15, "dust credit")

local debited = GuildMath.DebitBank(OmegaMath, "Cash", 100, 40)
assert(debited ~= nil and OmegaMath.ToNumber(debited) == 60, "cash debit")
assert(GuildMath.DebitBank(OmegaMath, "Cash", 10, 40) == nil, "cash debit refuse")
assert(GuildMath.DebitBank(OmegaMath, "Dust", 20, 5) == 15, "dust debit")
assert(GuildMath.DebitBank(OmegaMath, "Dust", 4, 5) == nil, "dust debit refuse")

near(GuildMath.AddClamped(10, 5), 15, "add clamped")
near(GuildMath.AddClamped(nil, 3), 3, "add from nil")

-- --- Source wiring + HARD constraints ----------------------------------------
local serviceSrc = fs.readFile("src/Server/AstralForge/Services/GuildService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/GuildMath.luau")
local viewSrc = fs.readFile("src/Client/AstralForge/pages/GuildView.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(serviceSrc, "GuildMath.UpgradeCost", 1, true), "GuildService must delegate UpgradeCost")
assert(string.find(serviceSrc, "GuildMath.UpgradeEffect", 1, true), "GuildService must delegate UpgradeEffect")
assert(string.find(serviceSrc, "GuildMath.NormalizeContributionAmount", 1, true), "GuildService must normalize contributions")
assert(string.find(serviceSrc, "GuildMath.CanAffordBank", 1, true), "GuildService must use CanAffordBank")
assert(string.find(serviceSrc, "GuildMath.CreditBank", 1, true), "GuildService must CreditBank")
assert(string.find(serviceSrc, "GuildMath.DebitBank", 1, true), "GuildService must DebitBank")
assert(string.find(serviceSrc, "GuildMath.GoalTarget", 1, true), "GuildService must use GoalTarget")
assert(string.find(serviceSrc, "blockedFull", 1, true), "JoinByTag must surface full-guild message")
assert(not string.find(serviceSrc, "local function upgradeTier", 1, true), "inline upgradeTier must be removed")
assert(not string.find(serviceSrc, "GUILD_BONUS_KEYS", 1, true), "inline GUILD_BONUS_KEYS must be removed")

-- Client: Cash bank can be Omega string — raw `>=` breaks; gteFlux required.
assert(string.find(viewSrc, "gteFlux(bank, cost)", 1, true), "GuildView must gteFlux bank vs cost")
assert(not string.find(viewSrc, "bank >= cost", 1, true), "GuildView must not raw-compare bank")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { serviceSrc, mathSrc, viewSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(mathSrc, "GetService", 1, true), "GuildMath must stay pure")

print("[INFO] [TEST] guild math extract passed | GuildMath")
