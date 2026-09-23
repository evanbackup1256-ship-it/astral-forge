--!strict
-- Pure-module extract guards: WheelMath (Ensure / Snapshot / BuildPool / Pick /
-- pity). Mirrors verify_forge_echo_math style.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.
-- Evidence: ApplyReward FreeSpins seeds Wheel={FreeSpins=N} without LastSpinAt —
-- WheelState did `nil + cooldown` and SpinWheel crashed before the spin.

local fs = require("@lune/fs")

local WheelMath = require("../src/Server/AstralForge/Modules/WheelMath")

-- --- Ensure -------------------------------------------------------------------
local fresh = WheelMath.Ensure(nil)
assert(fresh.LastSpinAt == 0 and fresh.Spins == 0 and fresh.PityMisses == 0 and fresh.FreeSpins == 0, "nil → empty bag")
local partial = WheelMath.Ensure({ FreeSpins = 2 })
assert(partial.FreeSpins == 2 and partial.LastSpinAt == 0 and partial.Spins == 0, "FreeSpins-only bag fills LastSpinAt")
assert(partial.PityMisses == 0, "FreeSpins-only bag fills PityMisses")
local same = WheelMath.Ensure(partial)
assert(same == partial, "Ensure mutates in place when table provided")
assert(WheelMath.Ensure({ FreeSpins = -3 }).FreeSpins == 0, "negative FreeSpins clamped")
assert(WheelMath.Ensure({ LastSpinAt = 1.9 }).LastSpinAt == 1, "LastSpinAt floored")

-- --- Rarity / pity ------------------------------------------------------------
assert(WheelMath.RarityRank("RARE") == 3, "RARE rank")
assert(WheelMath.RarityRank("mythic") == 6, "case-insensitive mythic")
assert(WheelMath.RarityRank(nil) == 1, "nil rarity → COMMON floor")
assert(WheelMath.RarityRank("nope") == 1, "unknown rarity → 1")
assert(WheelMath.NextPityMisses(4, 3, 3) == 0, "floor hit clears pity")
assert(WheelMath.NextPityMisses(4, 2, 3) == 5, "below floor increments")
assert(WheelMath.NextPityMisses(nil, 1, 3) == 1, "nil misses → 1")

-- --- Snapshot -----------------------------------------------------------------
local snap = WheelMath.Snapshot(1000, WheelMath.Ensure({ LastSpinAt = 100, FreeSpins = 0 }), 200, 8)
assert(snap.CanSpin == true and snap.ReadyAt == 1000, "cooldown elapsed → ready")
assert(snap.PityArmed == false and snap.PityAfter == 8, "pity not armed")
local armed = WheelMath.Snapshot(50, WheelMath.Ensure({ LastSpinAt = 100, FreeSpins = 0, PityMisses = 7 }), 200, 8)
assert(armed.CanSpin == false and armed.ReadyAt == 300, "on cooldown → not ready")
assert(armed.PityArmed == true, "7 misses + 1 >= 8 arms pity")
local free = WheelMath.Snapshot(50, WheelMath.Ensure({ LastSpinAt = 100, FreeSpins = 1 }), 200, 8)
assert(free.CanSpin == true and free.ReadyAt == 50, "free spin bypasses cooldown")

-- --- Pool / pick --------------------------------------------------------------
local rewards = {
	{ Id = "a", Name = "A", Rarity = "COMMON", Weight = 10, Reward = {} },
	{ Id = "b", Name = "B", Rarity = "RARE", Weight = 5, Reward = {} },
	{ Id = "c", Name = "C", Rarity = "EPIC", Weight = 1, Reward = {} },
}
local pool, total = WheelMath.BuildPool(rewards, false, 3)
assert(#pool == 3 and total == 16, "unfiltered pool")
local pityPool, pityTotal = WheelMath.BuildPool(rewards, true, 3)
assert(#pityPool == 2 and pityTotal == 6, "pity floor RARE+")
local full, fullTotal = WheelMath.FullPool(rewards)
assert(#full == 3 and fullTotal == 16, "FullPool ignores pity")
local first = WheelMath.PickEntry(pool, total, 0.1)
assert(first ~= nil and first.Index == 1, "low roll → first")
local last = WheelMath.PickEntry(pool, total, 16)
assert(last ~= nil and last.Index == 3, "max roll → last")
assert(WheelMath.PickEntry({}, 0, 0) == nil, "empty pool → nil")

-- --- Source wiring + HARD constraints ----------------------------------------
local progressionSrc = fs.readFile("src/Server/AstralForge/Services/ProgressionService.luau")
local mathSrc = fs.readFile("src/Server/AstralForge/Modules/WheelMath.luau")
local adminSrc = fs.readFile("src/Server/AstralForge/Services/AdminService.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(progressionSrc, "WheelMath.Ensure", 1, true), "ProgressionService must delegate Ensure")
assert(string.find(progressionSrc, "WheelMath.Snapshot", 1, true), "ProgressionService must delegate Snapshot")
assert(string.find(progressionSrc, "WheelMath.BuildPool", 1, true), "ProgressionService must delegate BuildPool")
assert(string.find(progressionSrc, "WheelMath.PickEntry", 1, true), "ProgressionService must delegate PickEntry")
assert(string.find(progressionSrc, "WheelMath.NextPityMisses", 1, true), "ProgressionService must delegate NextPityMisses")
assert(string.find(progressionSrc, "ensureWheel", 1, true), "ProgressionService must nil-safe via ensureWheel")
assert(string.find(progressionSrc, "profile.Wheel.LastSpinAt + GameConfig.Wheel.CooldownSeconds", 1, true) == nil, "WheelState must not raw-add LastSpinAt")
assert(string.find(progressionSrc, "local WHEEL_RARITY_RANK", 1, true) == nil, "inline WHEEL_RARITY_RANK must be removed")
assert(
	string.find(adminSrc, 'command == "ResetWheelCooldown"', 1, true) ~= nil
		and string.find(adminSrc, 'type(profile.Wheel) ~= "table"', 1, true) ~= nil,
	"Admin ResetWheelCooldown must nil-safe Wheel"
)
assert(
	string.find(adminSrc, 'command == "ResetDailyClaim"', 1, true) ~= nil
		and string.find(adminSrc, 'type(profile.Daily) ~= "table"', 1, true) ~= nil,
	"Admin ResetDailyClaim must nil-safe Daily"
)

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for badgeId, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. badgeId .. " must be 0")
end

for _, body in { progressionSrc, mathSrc, adminSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] WheelMath extract guards passed")
