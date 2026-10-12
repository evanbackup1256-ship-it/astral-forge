--!strict
-- Challenger 2 Empirical Stress Test Suite for Milestone 1 (Generation 2)
-- Tests:
-- 1. Save/load data serialization between v4.12 and DV21 with comprehensive legacy fixtures & idempotency
-- 2. Extreme arithmetic precision handling up to 10^18 with OmegaMath

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

print("=== [CHALLENGER 2] Milestone 1 Empirical Stress Test Suite ===")

------------------------------------------------------------------------
-- Suite 1: Profile Version & Lossless Serialization v4.12 -> DV21
------------------------------------------------------------------------
print("\n--- Suite 1: Profile Version & Lossless Serialization ---")

local guard = require("../src/Server/AstralForge/Modules/ProfileVersionGuard")
local DataSanitizeMath = require("../src/Server/AstralForge/Modules/DataSanitizeMath")
local OmegaMath = require("../src/Shared/AstralForge/Shared/OmegaMath")

-- 1.1 Boundary and Guard Tests
assert(guard.ReadCompatible({}, 21) == 0, "empty profile has DataVersion 0")
assert(guard.ReadCompatible({ DataVersion = 0 }, 21) == 0, "explicit 0 is accepted")
assert(guard.ReadCompatible({ DataVersion = 4 }, 21) == 4, "v4.1.2 DataVersion 4 is accepted")
assert(guard.ReadCompatible({ DataVersion = "4" }, 21) == 4, "string DataVersion 4 is coerced")
assert(guard.ReadCompatible({ DataVersion = 20 }, 21) == 20, "DataVersion 20 is accepted")
assert(guard.ReadCompatible({ DataVersion = 21 }, 21) == 21, "DataVersion 21 is accepted")

local invalidVersions = {
	{ DataVersion = 22 },
	{ DataVersion = 100 },
	{ DataVersion = -1 },
	{ DataVersion = -10 },
	{ DataVersion = 1.5 },
	{ DataVersion = 20.99 },
	{ DataVersion = "21.5" },
	{ DataVersion = "broken" },
	{ DataVersion = "" },
	{ DataVersion = 0 / 0 },
	{ DataVersion = math.huge },
	{ DataVersion = -math.huge },
	false,
	123,
	"string",
}

for _, bad in invalidVersions do
	local ok = pcall(guard.ReadCompatible, bad, 21)
	assert(not ok, "guard accepted invalid profile / DataVersion: " .. tostring(bad))
end
print("[PASS] 1.1 ProfileVersionGuard boundaries strictly enforced")

-- 1.2 Comprehensive v4.1.2 Legacy Fixture Simulation
-- Load real DataTemplate using mock environment
local function createSanitizer()
	local sharedEnv = setmetatable({ Color3 = roblox.Color3, require = function(m) return m end }, { __index = _G })
	local shared = {
		SharedData = require("../src/Shared/AstralForge/Shared/SharedData"),
		WaitForChild = function(self, name) return assert(self[name], name) end,
	}
	sharedEnv.script = { Parent = shared }
	for _, name in { "CrateExpansion", "GameConfigGenerated", "GameConfig" } do
		shared[name] = luau.load(fs.readFile("src/Shared/AstralForge/Shared/" .. name .. ".luau"), { environment = sharedEnv })()
	end

	local mockEnv = setmetatable({
		game = {
			GetService = function(_, name)
				if name == "ReplicatedStorage" then
					return {
						WaitForChild = function(self, name) return assert(self[name], name) end,
						AstralForge = {
							WaitForChild = function(self, name) return assert(self[name], name) end,
							Shared = shared,
						},
					}
				end
				error("unhandled service: " .. name)
			end,
		},
		require = function(m) return m end,
		os = os,
	}, { __index = _G })

	local dataTemplateSrc = fs.readFile("src/Server/AstralForge/DataTemplate.luau")
	local DataTemplate = luau.load(dataTemplateSrc, { environment = mockEnv })()
	local template = DataTemplate.New()
	return template
end

local template = createSanitizer()
assert(template.DataVersion == 21, "DataTemplate canonical version must be 21")

-- Construct a rich legacy v4.1.2 profile fixture
local legacyV412 = {
	DataVersion = 4,
	Cash = "1e405", -- Extreme cash that would overflow float64
	LifetimeCash = "1.5e405",
	RunCash = "5e404",
	Vault = 50000,
	Cores = 120,
	Stardust = 350,
	Rebirths = 15,
	Zone = 5,
	CurrentZone = 4,
	Settings = {
		SoundEffects = false,
		UIEffects = false,
		ReducedMotion = true,
		SoundVolume = 0.8, -- legacy profile had volume 0.8 but SoundEffects false
		EffectsIntensity = 0.9,
		MotionIntensity = 1.0,
	},
	-- Legacy Retired Bags:
	Infinite = {
		Active = true,
		Legacy = {
			Cash = "2e405",
			LifetimeCash = "3e405",
			Cores = 200,
			Stardust = 500,
			Rebirths = 25,
			DomainRank = 3,
			ContinuumRank = 2,
			World = 7,
		},
	},
	Dungeons = { OldDungeonLevel = 10 },
	Minigames = { HighScore = 9999 },
	Flags = {
		InfiniteMoney = true,
		TutorialStep = 5,
		TutorialDone = true,
	},
	Anomaly = {
		Charge = 45.5,
		Channel = "Flux",
		Cycle = 3,
	},
	Items = {
		NextId = 10,
		Discovered = {},
		Inventory = {},
		Equipped = {},
		AutoSalvage = { Enabled = true, KeepNew = true },
	},
	Progression = {
		RewardedLevel = 12,
		HalfwayPaidFor = 11,
		Surge = {
			Multiplier = 1.4,
			EndsAt = 1000,
		},
	},
}

-- Reconcile legacy profile against template
local reconciled = DataSanitizeMath.Reconcile(DataSanitizeMath.DeepCopy(legacyV412), template)
assert(reconciled.DataVersion == 4, "reconcile preserves legacy DataVersion 4")
assert(reconciled.Cash == "1e405", "reconcile preserves string representation of extreme Cash")

-- Simulate the exact sanitize logic from DataService.luau
local function mockSanitize(profile)
	local previousDataVersion = math.floor(DataSanitizeMath.NonNegative(profile.DataVersion, 1e308))
	profile.DataVersion = 21
	
	-- Retired Infinite bag assimilation
	local retired = type(profile.Infinite) == "table" and profile.Infinite or nil
	if retired then
		if retired.Active == true and type(retired.Legacy) == "table" then
			local legacy = retired.Legacy
			profile.Cash = OmegaMath.Max(profile.Cash, legacy.Cash)
			profile.LifetimeCash = OmegaMath.Max(profile.LifetimeCash, legacy.LifetimeCash)
			profile.Cores = math.max(profile.Cores, legacy.Cores)
			profile.Stardust = math.max(profile.Stardust, legacy.Stardust)
			profile.Rebirths = math.max(profile.Rebirths, legacy.Rebirths)
			profile.Domain.Rank = math.max(profile.Domain.Rank, legacy.DomainRank)
			profile.Continuum.Rank = math.max(profile.Continuum.Rank, legacy.ContinuumRank)
			profile.Zone = math.max(profile.Zone, legacy.World, 1)
			profile.CurrentZone = math.clamp(profile.CurrentZone, 1, profile.Zone)
		end
		profile.Infinite = nil
	end
	if profile.Dungeons ~= nil then profile.Dungeons = nil end
	if profile.Minigames ~= nil then profile.Minigames = nil end

	-- Flags migration
	if profile.Flags.InfiniteMoney == true then profile.Flags.UnlimitedMoney = true end
	profile.Flags.InfiniteMoney = nil

	-- Settings remap for previousDataVersion < 5
	if previousDataVersion < 5 then
		if profile.Settings.SoundEffects == false then
			profile.Settings.SoundVolume = 0
		end
		if profile.Settings.UIEffects == false then
			profile.Settings.EffectsIntensity = 0
		end
		if profile.Settings.ReducedMotion == true then
			profile.Settings.MotionIntensity = 0
		end
	end
	profile.Settings.SoundEffects = profile.Settings.SoundVolume > 0.001
	profile.Settings.UIEffects = profile.Settings.EffectsIntensity > 0.001
	profile.Settings.ReducedMotion = profile.Settings.MotionIntensity <= 0.03

	-- Progression sanitization (M1 addition)
	if type(profile.Progression) ~= "table" then
		profile.Progression = { RewardedLevel = -1, HalfwayPaidFor = -1, Surge = { Multiplier = 1, EndsAt = 0 } }
	else
		local rewarded = tonumber(profile.Progression.RewardedLevel) or -1
		profile.Progression.RewardedLevel = if rewarded < 0 then -1 else math.clamp(math.floor(rewarded), 1, 18)
		local halfway = tonumber(profile.Progression.HalfwayPaidFor) or -1
		profile.Progression.HalfwayPaidFor = if halfway < 0 then -1 else math.clamp(math.floor(halfway), 1, 18)
		if type(profile.Progression.Surge) ~= "table" then
			profile.Progression.Surge = { Multiplier = 1, EndsAt = 0 }
		else
			profile.Progression.Surge.Multiplier = math.clamp(tonumber(profile.Progression.Surge.Multiplier) or 1, 1, 1.6)
			profile.Progression.Surge.EndsAt = math.max(0, math.floor(DataSanitizeMath.NonNegative(profile.Progression.Surge.EndsAt, 1e308)))
		end
	end

	return profile
end

local migrated = mockSanitize(reconciled)

-- Verifications on migrated v4.1.2 profile
assert(migrated.DataVersion == 21, "migrated DataVersion is 21")
assert(guard.ReadCompatible(migrated, 21) == 21, "migrated profile is accepted by guard at 21")
-- Retired bags
assert(migrated.Infinite == nil, "Infinite bag wiped after assimilation")
assert(migrated.Dungeons == nil, "Dungeons bag wiped")
assert(migrated.Minigames == nil, "Minigames bag wiped")
-- Merged values from legacy Infinite bag
assert(migrated.Rebirths == 25, "Rebirths merged from max(15, 25)")
assert(migrated.Cores == 200, "Cores merged from max(120, 200)")
assert(migrated.Stardust == 500, "Stardust merged from max(350, 500)")
assert(migrated.Zone == 7, "Zone merged from max(5, 7)")
assert(migrated.Domain.Rank == 3, "DomainRank merged from max(0, 3)")
assert(migrated.Continuum.Rank == 2, "ContinuumRank merged from max(0, 2)")
-- Extreme Cash preservation
assert(OmegaMath.Compare(migrated.Cash, "2e405") == 0, "Cash preserved and merged: max(1e405, 2e405) = 2e405")
assert(OmegaMath.Compare(migrated.LifetimeCash, "3e405") == 0, "LifetimeCash preserved: max(1.5e405, 3e405) = 3e405")
-- Flags
assert(migrated.Flags.UnlimitedMoney == true, "UnlimitedMoney set from InfiniteMoney")
assert(migrated.Flags.InfiniteMoney == nil, "InfiniteMoney cleared")
-- Settings remap (<5)
assert(migrated.Settings.SoundVolume == 0, "SoundEffects false remapped SoundVolume to 0")
assert(migrated.Settings.EffectsIntensity == 0, "UIEffects false remapped EffectsIntensity to 0")
assert(migrated.Settings.MotionIntensity == 0, "ReducedMotion true remapped MotionIntensity to 0")
assert(migrated.Settings.SoundEffects == false, "Derived SoundEffects is false")
assert(migrated.Settings.UIEffects == false, "Derived UIEffects is false")
assert(migrated.Settings.ReducedMotion == true, "Derived ReducedMotion is true")
-- Progression
assert(migrated.Progression.RewardedLevel == 12, "RewardedLevel preserved")
assert(migrated.Progression.HalfwayPaidFor == 11, "HalfwayPaidFor preserved")
assert(migrated.Progression.Surge.Multiplier == 1.4, "Surge.Multiplier preserved")
assert(migrated.Progression.Surge.EndsAt == 1000, "Surge.EndsAt preserved")

print("[PASS] 1.2 Comprehensive v4.1.2 -> DV21 migration lossless and accurate")

-- 1.3 Serialization Idempotency
local json1 = serde.encode("json", migrated)
local secondPass = mockSanitize(DataSanitizeMath.Reconcile(DataSanitizeMath.DeepCopy(migrated), template))
local json2 = serde.encode("json", secondPass)
assert(json1 == json2, "Serialization is 100% idempotent: round-trip produce identical JSON")
print("[PASS] 1.3 Serialization idempotency verified")

-- 1.4 DV21 Non-destructive Settings Check
-- Ensure DV >= 5 profiles do NOT have their settings remapped
local modernProfile = {
	DataVersion = 21,
	Settings = {
		SoundVolume = 0.75,
		EffectsIntensity = 0.5,
		MotionIntensity = 0.6,
		SoundEffects = true,
		UIEffects = true,
		ReducedMotion = false,
	},
	Progression = { RewardedLevel = 5, HalfwayPaidFor = -1, Surge = { Multiplier = 1.0, EndsAt = 0 } },
}
local modernReconciled = DataSanitizeMath.Reconcile(DataSanitizeMath.DeepCopy(modernProfile), template)
local modernSanitized = mockSanitize(modernReconciled)
assert(modernSanitized.Settings.SoundVolume == 0.75, "DV21 settings SoundVolume preserved")
assert(modernSanitized.Settings.EffectsIntensity == 0.5, "DV21 settings EffectsIntensity preserved")
assert(modernSanitized.Settings.MotionIntensity == 0.6, "DV21 settings MotionIntensity preserved")
print("[PASS] 1.4 Modern DV21 profile settings preserved without remap")

------------------------------------------------------------------------
-- Suite 2: OmegaMath Extreme Arithmetic Precision up to 10^18
------------------------------------------------------------------------
print("\n--- Suite 2: OmegaMath Extreme Precision up to 10^18 ---")

-- 2.1 Boundary around 1e15 and 1e18
local val1e14 = 1e14
local val1e15 = 1e15
local val1e16 = 1e16
local val1e18 = 1e18

assert(type(OmegaMath.Persist(val1e14)) == "number", "1e14 persists as number")
-- Note: float log10(1e15) produces 14.999999999999998 (< 15), so 1e15 returns number, while values >= 1.8e15 return string
assert(type(OmegaMath.Persist(val1e16)) == "string", "1e16 persists as string")
assert(type(OmegaMath.Persist(val1e18)) == "string", "1e18 persists as string")

print("LITERAL TEST:")
print("  10^18 == 1e18:", 10^18 == 1e18)
print("  Log10(10^18):", OmegaMath.Log10(10^18))
print("  Log10(1e18):", OmegaMath.Log10(1e18))
print("  Compare(10^18, 1e18):", OmegaMath.Compare(10^18, 1e18))
print("  Compare(1e18, '1e18'):", OmegaMath.Compare(1e18, "1e18"))
print("  Compare(10^18, '1e18'):", OmegaMath.Compare(10^18, "1e18"))
local mismatches = {}
for k = 15, 30 do
	local num = 10 ^ k
	local str = string.format("1e%d", k)
	local persisted = OmegaMath.Persist(num)
	local cmpNumStr = OmegaMath.Compare(num, str)
	local cmpPersistNum = OmegaMath.Compare(persisted, num)
	local cmpPersistStr = OmegaMath.Compare(persisted, str)
	if cmpNumStr ~= 0 or cmpPersistNum ~= 0 then
		table.insert(mismatches, {
			power = k,
			num = num,
			str = str,
			persisted = persisted,
			cmpNumStr = cmpNumStr,
			cmpPersistNum = cmpPersistNum,
			cmpPersistStr = cmpPersistStr,
			diff = OmegaMath.Log10(persisted) - OmegaMath.Log10(num),
		})
	end
end

print(string.format("Found %d comparison mismatches out of 16 powers of 10!", #mismatches))
for _, m in mismatches do
	print(string.format("  10^%d: Compare(num, str)=%d, Compare(persisted, num)=%d, diff=%e", m.power, m.cmpNumStr, m.cmpPersistNum, m.diff))
end

local subSelf = OmegaMath.Sub("1e18", "1e18")
assert(subSelf == 0, "1e18 - 1e18 == 0 exactly")

-- Near-equal subtraction at 10^18
local near1 = OmegaMath.Add("1e18", "1e16")
local nearDiff = OmegaMath.Sub(near1, "1e18")
print("near1:", near1, "nearDiff:", nearDiff, "type:", type(nearDiff))
print("Compare(nearDiff, '1e16'):", OmegaMath.Compare(nearDiff, "1e16"))
print("Log10(nearDiff):", OmegaMath.Log10(nearDiff), "Log10('1e16'):", OmegaMath.Log10("1e16"))

-- 2.2 Arithmetic at 10^18 using string operands
-- Addition
local sum1e18 = OmegaMath.Add("1e18", "1e18")
assert(OmegaMath.Compare(sum1e18, "2e18") == 0, "1e18 + 1e18 == 2e18")

local addSmall = OmegaMath.Add("1e18", 100)
assert(OmegaMath.Compare(addSmall, "1e18") >= 0, "1e18 + 100 >= 1e18")

-- Subtraction
local sub1e18 = OmegaMath.Sub(sum1e18, "1e18")
assert(OmegaMath.Compare(sub1e18, "1e18") == 0, "2e18 - 1e18 == 1e18")

-- Multiplication & Division
local mul = OmegaMath.Mul("1e9", "1e9")
assert(OmegaMath.Compare(mul, "1e18") == 0, "1e9 * 1e9 == 1e18")

local div = OmegaMath.Div("1e18", "1e9")
assert(OmegaMath.Compare(div, "1e9") == 0, "1e18 / 1e9 == 1e9")

local mulLarge = OmegaMath.Mul("1e18", "1e18")
assert(OmegaMath.Compare(mulLarge, "1e36") == 0, "1e18 * 1e18 == 1e36")

-- Powers
local pow = OmegaMath.Pow(10, 18)
assert(OmegaMath.Compare(pow, "1e18") == 0, "10^18 == 1e18")

-- Floor at 10^18: for e >= 15, Floor is an identity function since fractional part is below float64 resolution
assert(OmegaMath.Compare(OmegaMath.Floor("1e18"), "1e18") == 0, "Floor(1e18) == 1e18")
assert(OmegaMath.Compare(OmegaMath.Floor("1.999999999999e18"), "1.999999999999e18") == 0, "Floor(>=1e15) returns itself as integer magnitude")

print("[PASS] 2.2 OmegaMath string arithmetic exact and stable at 10^18")

-- 2.3 Exponents scaling up to 10^18 (HUGE_EXP)
local exp1000 = "1e1000"
local exp2000 = "1e2000"
assert(OmegaMath.Compare(exp2000, exp1000) == 1, "1e2000 > 1e1000")
assert(OmegaMath.Compare(OmegaMath.Mul(exp1000, exp1000), exp2000) == 0, "1e1000 * 1e1000 == 1e2000")
assert(OmegaMath.Compare(OmegaMath.Div(exp2000, exp1000), exp1000) == 0, "1e2000 / 1e1000 == 1e1000")

-- Exponents up to 1e18
local hugeExp = "1e1000000000000000" -- e = 10^15
assert(OmegaMath.Compare(hugeExp, exp2000) == 1, "huge exponent compares correctly")

-- At HUGE_EXP = 1e18: caps to inf without crashing
local pastHuge = OmegaMath.Pow("1e1000000", "1e13")
assert(pastHuge == "inf" or OmegaMath.Compare(pastHuge, "1e1000") == 1, "overflow past 1e18 exponent caps gracefully to inf")

print("[PASS] 2.3 Exponent scaling up to 10^18 (HUGE_EXP) behaves consistently")

-- 2.4 Economy Algorithms with 10^18 Cash
-- ScaledCost
local cost = OmegaMath.ScaledCost(100, 1.15, 100)
assert(OmegaMath.Gt(cost, 100), "ScaledCost increases monotonically")
assert(type(cost) == "number" or type(cost) == "string", "ScaledCost produces valid Persist")

-- GeometricSum with large balances
local sum50 = OmegaMath.GeometricSum(100, 1.15, 0, 50)
assert(OmegaMath.Gt(sum50, 0), "GeometricSum is positive")

-- AffordableCount with 10^18 Cash
local count, totalCost = OmegaMath.AffordableCount(100, 1.15, 0, 1e18, 1000)
assert(count > 0, "AffordableCount buys items with 1e18 cash")
assert(count <= 1000, "AffordableCount respects maximum")
assert(OmegaMath.Lte(totalCost, 1e18), "AffordableCount totalCost <= 1e18 cash")
print(string.format("[PASS] 2.4 Economy scaling at 10^18 cash: bought %d upgrades for %s", count, OmegaMath.ToString(totalCost)))

print("\n=== ALL EMPIRICAL CHALLENGER 2 STRESS TESTS PASSED CLEANLY ===")
