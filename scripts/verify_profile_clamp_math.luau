--!strict
-- Pure-module extract guards: ProfileClampMath.ClampProgressionNumbers.
-- Evidence: post-mutate Cash/Vault/Cores/Stats/Continuum bags with NaN /
-- negative / string scalars must clamp without throwing. HARD: DV<=21,
-- PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local ProfileClampMath = require("../src/Server/AstralForge/Modules/ProfileClampMath")

local function identityPersist(value: any): any
	local n = tonumber(value)
	if type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge then
		return n
	end
	return 0
end

------------------------------------------------------------------------
-- ClampProgressionNumbers
------------------------------------------------------------------------
assert(ProfileClampMath.ClampProgressionNumbers(nil, identityPersist, 1e6) == false, "nil profile")

local profile = {
	Cash = -12,
	Vault = "40",
	RunCash = math.huge,
	LifetimeCash = 0 / 0,
	Cores = "7",
	Stardust = -3,
	Rebirths = 5000,
	Stats = {
		Collected = -5,
		Taps = -2,
		PlayTime = math.huge,
	},
	Continuum = {
		TotalFluxSpent = -9,
		TotalStardustSpent = "11",
	},
}
assert(ProfileClampMath.ClampProgressionNumbers(profile, identityPersist, 1000) == true, "clamp ok")
assert(profile.Cash == 0, "negative cash → 0")
assert(profile.Vault == 40, "string vault")
assert(profile.RunCash == 0, "inf run → 0")
assert(profile.LifetimeCash == 0, "nan lifetime → 0")
assert(profile.Cores == 7, "string cores")
assert(profile.Stardust == 0, "neg stardust")
assert(profile.Rebirths == 1000, "clamp rebirth ceiling")
assert(profile.Stats.Collected == -5, "Collected stays Persist result (caller Persist may soft-clamp)")
assert(profile.Stats.Taps == 0, "neg taps")
assert(profile.Stats.PlayTime == 0, "inf play")
assert(profile.Continuum.TotalFluxSpent == -9, "TotalFluxSpent stays Persist result")
assert(profile.Continuum.TotalStardustSpent == 11, "string continuum stardust")

-- Partial profile (no Stats / Continuum) must not throw.
local partial = { Cash = 5, Cores = 1, Stardust = 2, Rebirths = 0 }
assert(ProfileClampMath.ClampProgressionNumbers(partial, identityPersist, 1e6) == true, "partial ok")
assert(partial.Cash == 5 and partial.Cores == 1, "partial preserved")

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
local clampSrc = fs.readFile("src/Server/AstralForge/Modules/ProfileClampMath.luau")
local ssSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(clampSrc, "function ProfileClampMath.ClampProgressionNumbers", 1, true), "ClampProgressionNumbers export")
assert(string.find(ssSrc, "ProfileClampMath.ClampProgressionNumbers", 1, true), "ServerServices Clamp residual")
assert(string.find(ssSrc, "Economy.Persist", 1, true), "ServerServices Persist inject")
assert(not string.find(clampSrc, "GetService", 1, true), "ProfileClampMath must stay pure")
assert(not string.find(clampSrc, "vendor/", 1, true), "no vendor/")
assert(not string.find(clampSrc, "Packages/", 1, true), "no Packages/")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

print("[INFO] [TEST] profile clamp math passed")
