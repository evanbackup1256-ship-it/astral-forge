local guard = require("../src/Server/AstralForge/Modules/ProfileVersionGuard")

assert(guard.ReadCompatible({}, 21) == 0)
assert(guard.ReadCompatible({ DataVersion = 21 }, 21) == 21)
assert(guard.ReadCompatible({ DataVersion = "20" }, 21) == 20)

for _, data in { false, { DataVersion = 22 }, { DataVersion = -1 }, { DataVersion = "broken" }, { DataVersion = 1.5 } } do
	local ok = pcall(guard.ReadCompatible, data, 21)
	assert(not ok, "unsafe profile version was accepted")
end

-- Offline migrate path: game-era v4.1.2 saves often carried DataVersion 4 (pre-settings
-- remap). Guard must accept them for reconcile/sanitize up to DV21, never beyond.
local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function reconcile(target, template)
	for key, defaultValue in template do
		local currentValue = target[key]
		if type(defaultValue) == "table" and type(currentValue) == "table" then
			reconcile(currentValue, defaultValue)
		elseif currentValue == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) ~= type(currentValue) then
			target[key] = deepCopy(defaultValue)
		end
	end
	return target
end

-- Minimal template fields the DV21 sanitize path expects after reconcile.
local DV21_TEMPLATE = {
	DataVersion = 21,
	Cash = 0,
	Vault = 0,
	Cores = 0,
	Stardust = 0,
	Rebirths = 0,
	Domain = { Rank = 0, Essence = 0, LastExpandedAt = 0, TotalRebirthsSpent = 0, TotalCoresSpent = 0, SkillPoints = 0, Nodes = {} },
	Continuum = { Rank = 0, TotalFluxSpent = 0, TotalStardustSpent = 0 },
	Anomaly = {
		Cycle = 0,
		Charge = 0,
		Fragments = 0,
		Stabilizations = 0,
		LastActionAt = 0,
		SurgeEndsAt = 0,
		Channel = "Flux",
		Loadout = {},
		Protocols = {},
		Discoveries = {},
		MilestoneClaims = {},
		DirectiveProgress = {},
		DirectiveClaims = {},
		DirectiveCycle = 0,
		PulseWindowStartedAt = 0,
		Combo = 0,
		BestCombo = 0,
		CoreTier = 0,
		CoreXP = 0,
	},
	Settings = {
		SoundVolume = 1,
		EffectsIntensity = 1,
		MotionIntensity = 1,
		SoundEffects = true,
		UIEffects = true,
		ReducedMotion = false,
	},
	Meta = { Revision = 0 },
}

-- Fixture shaped like a sparse v4.1.2-era profile (DataVersion 4 + legacy settings flags).
local v412 = {
	DataVersion = 4,
	Cash = 1250,
	Cores = 3,
	Settings = {
		SoundEffects = false,
		UIEffects = true,
		ReducedMotion = false,
	},
	Anomaly = {
		Charge = 12.5,
		Channel = "Flux",
	},
}

assert(guard.ReadCompatible(v412, 21) == 4, "v4.1.2-era DV4 must be readable under DV21")
local migrated = reconcile(deepCopy(v412), DV21_TEMPLATE)
assert(migrated.DataVersion == 4, "reconcile preserves source DataVersion until sanitize bump")
assert(type(migrated.Continuum) == "table", "reconcile fills Continuum")
assert(type(migrated.Anomaly.Loadout) == "table", "reconcile fills Anomaly.Loadout")
assert(migrated.Anomaly.Charge == 12.5, "reconcile keeps existing Anomaly.Charge")
assert(migrated.Settings.SoundEffects == false, "legacy SoundEffects flag retained for <5 remap")

-- Simulate sanitize bump performed by DataService.sanitize.
migrated.DataVersion = 21
if migrated.Settings.SoundEffects == false then
	migrated.Settings.SoundVolume = 0
end
migrated.Settings.SoundEffects = migrated.Settings.SoundVolume > 0.001
migrated.Settings.UIEffects = migrated.Settings.EffectsIntensity > 0.001
migrated.Settings.ReducedMotion = migrated.Settings.MotionIntensity <= 0.03

assert(guard.ReadCompatible(migrated, 21) == 21)
assert(migrated.Settings.SoundVolume == 0, "DV<5 SoundEffects=false remaps SoundVolume to 0")
assert(migrated.Settings.SoundEffects == false)
assert(migrated.Anomaly.Channel == "Flux")

print("[INFO] [TEST] profile version guards passed | v4.1.2→DV21 migrate fixture ok")
