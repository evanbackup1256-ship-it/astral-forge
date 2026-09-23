--!strict
-- Pure-module extract guards: AnomalyPulseScore (pulse window / sweet-zone / combo).
-- Mirrors verify_progression_lab style — require under Lune, assert behavior.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local AnomalyPulseScore = require("../src/Server/AstralForge/Modules/AnomalyPulseScore")

local function near(actual: number, expected: number, label: string)
	assert(math.abs(actual - expected) < 1e-9, label)
end

-- --- Window / sweet-zone -----------------------------------------------------
local period = 1.6
local sweet = 0.22
local started = 1000.0

assert(AnomalyPulseScore.IsAccurate(1000.1, 0, period, sweet) == false, "no window → miss")
assert(AnomalyPulseScore.IsAccurate(1000.1, nil, period, sweet) == false, "nil startedAt → miss")
assert(AnomalyPulseScore.IsAccurate(1000.1, "x", period, sweet) == false, "non-number → miss")

-- Tail sweet zone: elapsed >= period - period*sweet = 1.6 * 0.78 = 1.248
assert(AnomalyPulseScore.IsAccurate(started + 1.0, started, period, sweet) == false, "mid-window miss")
assert(AnomalyPulseScore.IsAccurate(started + 1.247, started, period, sweet) == false, "just before sweet miss")
assert(AnomalyPulseScore.IsAccurate(started + 1.248, started, period, sweet) == true, "sweet edge hit")
assert(AnomalyPulseScore.IsAccurate(started + 1.5, started, period, sweet) == true, "deep sweet hit")

-- Wrap: elapsed = (started+period+0.1 - started) % period = 0.1 → miss
assert(AnomalyPulseScore.IsAccurate(started + period + 0.1, started, period, sweet) == false, "post-wrap miss")
-- Wrap into sweet: elapsed = 1.3
assert(AnomalyPulseScore.IsAccurate(started + period + 1.3, started, period, sweet) == true, "post-wrap sweet")

near(AnomalyPulseScore.Elapsed(started + 0.4, started, period), 0.4, "elapsed mid")
near(AnomalyPulseScore.Fraction(started + 0.8, started, period), 0.5, "fraction half")
near(AnomalyPulseScore.Fraction(started + 0.05, started, 0.05), 0.5, "fraction clamps period to 0.1")

-- --- Combo / bonuses ---------------------------------------------------------
assert(AnomalyPulseScore.NextCombo(0, false, 20) == 0, "miss from 0 stays 0")
assert(AnomalyPulseScore.NextCombo(7, false, 20) == 0, "miss resets combo")
assert(AnomalyPulseScore.NextCombo(0, true, 20) == 1, "first hit → 1")
assert(AnomalyPulseScore.NextCombo(19, true, 20) == 20, "cap at max")
assert(AnomalyPulseScore.NextCombo(20, true, 20) == 20, "already max stays")
assert(AnomalyPulseScore.NextCombo(nil, true, 20) == 1, "nil combo → 1 on hit")

assert(AnomalyPulseScore.NextBestCombo(5, 3) == 5, "best keeps higher")
assert(AnomalyPulseScore.NextBestCombo(5, 9) == 9, "best rises")
assert(AnomalyPulseScore.NextBestCombo(nil, 4) == 4, "nil best → combo")

-- ComboBonus: 1 + min(1, combo * 0.03); soft-cap at 2x (combo >= ceil(1/0.03)=34, but max is 20)
near(AnomalyPulseScore.ComboBonus(0, 0.03), 1.0, "combo 0 → 1x")
near(AnomalyPulseScore.ComboBonus(10, 0.03), 1.3, "combo 10 → 1.3x")
near(AnomalyPulseScore.ComboBonus(20, 0.03), 1.6, "combo 20 → 1.6x")
near(AnomalyPulseScore.ComboBonus(100, 0.03), 2.0, "soft-cap at 2x")

near(AnomalyPulseScore.AccuracyBonus(false, 0.75), 1.0, "miss accuracy → 1x")
near(AnomalyPulseScore.AccuracyBonus(true, 0.75), 1.75, "hit accuracy → 1.75x")

near(AnomalyPulseScore.ScoreMultiplier(10, true, 0.03, 0.75), 1.3 * 1.75, "combined hit")
near(AnomalyPulseScore.ScoreMultiplier(0, false, 0.03, 0.75), 1.0, "combined miss")

-- --- Source wiring + HARD constraints ----------------------------------------
local serviceSrc = fs.readFile("src/Server/AstralForge/Services/AnomalyService.luau")
local scoreSrc = fs.readFile("src/Server/AstralForge/Modules/AnomalyPulseScore.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(serviceSrc, "AnomalyPulseScore.IsAccurate", 1, true), "AnomalyService must delegate IsAccurate")
assert(string.find(serviceSrc, "AnomalyPulseScore.NextCombo", 1, true), "AnomalyService must delegate NextCombo")
assert(string.find(serviceSrc, "AnomalyPulseScore.ComboBonus", 1, true), "AnomalyService must delegate ComboBonus")
assert(string.find(serviceSrc, "AnomalyPulseScore.AccuracyBonus", 1, true), "AnomalyService must delegate AccuracyBonus")
assert(not string.find(serviceSrc, "local function pulseAccuracy", 1, true), "inline pulseAccuracy must be removed")

local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, body in { serviceSrc, scoreSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end
assert(not string.find(scoreSrc, "GetService", 1, true), "AnomalyPulseScore must stay pure")

print("[INFO] [TEST] anomaly pulse extract passed | AnomalyPulseScore")
