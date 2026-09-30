--!nocheck
-- Guards for the boss roster: config shape and the pure attack/phase rules.
--
--   1. Roster: three distinct bosses, each with a kind, theme, phases and attacks.
--   2. Phases: thresholds descend and map health to a phase number.
--   3. Attack picking: weighted, gated by phase, deterministic for a given roll.
--   4. Ring and sweep geometry, including the safe gaps.
--   5. Every boss can be beaten by one level-1 fighter before it escapes.

local SanctuaryConfig = require("../src/Shared/AstralForge/Shared/SharedData")("SanctuaryConfig")
local Layout = require("../src/Shared/AstralForge/Shared/SharedData")("SanctuaryLayout")
local RiftBossMath = require("../src/Server/AstralForge/Modules/EconomyMath")("RiftBossMath")
local fs = require("@lune/fs")

local function check(condition: boolean, message: string)
	if not condition then
		error("rift boss roster: " .. message, 0)
	end
end

local roster = SanctuaryConfig.RiftBosses
check(#roster == 3, "expected 3 bosses, got " .. #roster)
check(roster[1] == SanctuaryConfig.RiftBoss, "the Warden must lead the roster")

local kinds = {}
for index, boss in roster do
	local label = boss.Name or ("boss " .. index)
	check(type(boss.Kind) == "string" and not kinds[boss.Kind], label .. ": kind missing or duplicated")
	kinds[boss.Kind] = true
	check(type(boss.Title) == "string" and #boss.Title > 0, label .. ": no title")
	for _, key in { "Primary", "Hot", "Alert" } do
		local colour = boss.Theme and boss.Theme[key]
		check(colour ~= nil and #colour == 3, label .. ": theme " .. key .. " must be {r, g, b}")
		for _, channel in colour do
			check(channel >= 0 and channel <= 255, label .. ": theme channel out of range")
		end
	end
	check(#boss.Attacks > 0, label .. ": no attacks")
	check(#boss.PhaseDelayScale == #boss.Phases + 1, label .. ": one delay scale per phase")
	local previous = 1
	for _, threshold in boss.Phases do
		check(threshold > 0 and threshold < previous, label .. ": phase thresholds must descend inside (0, 1)")
		previous = threshold
	end
	check(RiftBossMath.PickAttack(boss.Attacks, 1, 0) ~= nil, label .. ": nothing unlocked in phase 1")
	for _, attack in boss.Attacks do
		check((attack.MinPhase or 1) <= #boss.Phases + 1, label .. ": attack gated behind a phase that never comes")
		check((attack.Weight or 1) > 0, label .. ": non-positive weight")
	end
end

-- Phases
local phases = { 0.66, 0.33 }
check(RiftBossMath.PhaseIndex(1000, 1000, phases) == 1, "full health is phase 1")
check(RiftBossMath.PhaseIndex(660, 1000, phases) == 2, "at the first threshold is phase 2")
check(RiftBossMath.PhaseIndex(330, 1000, phases) == 3, "at the second threshold is phase 3")
check(RiftBossMath.PhaseIndex(0, 1000, phases) == 3, "empty stays phase 3")
check(RiftBossMath.PhaseIndex(0, 0, phases) == 1, "no max health is phase 1")
check(RiftBossMath.NextBoss(1, 3) == 2 and RiftBossMath.NextBoss(3, 3) == 1, "roster wraps")
check(RiftBossMath.NextBoss(1, 0) == 1, "empty roster is safe")
check(RiftBossMath.PhaseDelayScale(1, { 1, 0.8, 0.62 }) == 1, "delay scale phase 1")
check(RiftBossMath.PhaseDelayScale(9, { 1, 0.8, 0.62 }) == 0.62, "delay scale holds the last entry")

-- Attack picking
local attacks = {
	{ Kind = "A", Weight = 1 },
	{ Kind = "B", Weight = 1, MinPhase = 2 },
	{ Kind = "C", Weight = 2, MinPhase = 3 },
}
check(RiftBossMath.PickAttack(attacks, 1, 0.99).Kind == "A", "phase 1 only unlocks A")
check(RiftBossMath.PickAttack(attacks, 2, 0.1).Kind == "A", "phase 2 low roll picks A")
check(RiftBossMath.PickAttack(attacks, 2, 0.9).Kind == "B", "phase 2 high roll picks B")
check(RiftBossMath.PickAttack(attacks, 3, 0.99).Kind == "C", "phase 3 weight reaches C")
check(RiftBossMath.PickAttack(attacks, 3, 1).Kind == "C", "a roll of exactly 1 is clamped")
check(RiftBossMath.PickAttack({ { Kind = "X", MinPhase = 5 } }, 1, 0) == nil, "locked attacks are never picked")

-- Rings: the band is hit, the gaps are not
local positions = {
	inside = { X = 10, Z = 0 },
	onRing = { X = 16, Z = 0 },
	edge = { X = 18.75, Z = 0 },
	gap = { X = 26, Z = 0 },
	outside = { X = 60, Z = 0 },
}
local function set(list)
	local seen = {}
	for _, id in list do
		seen[id] = true
	end
	return seen
end
local ring = set(RiftBossMath.RingHits(0, 0, 16, 5.5, positions))
check(ring.onRing and ring.edge, "ring band hits")
check(not ring.inside and not ring.gap and not ring.outside, "ring safe ground is safe")

-- Sweeps
local speed = 0.85
check(RiftBossMath.SweepAngleAt(1, speed, 2) == 1 + speed * 2, "sweep advances with time")
check(RiftBossMath.SweepAngleAt(1, speed, -3) == 1, "sweep never runs backwards in time")
check(RiftBossMath.SweepCovers(10, 0, 0, 0.2, 84), "beam covers its own heading")
check(not RiftBossMath.SweepCovers(10, 0, math.pi / 2, 0.2, 84), "beam misses a right angle away")
check(not RiftBossMath.SweepCovers(100, 0, 0, 0.2, 84), "beam stops at its range")
check(RiftBossMath.SweepCovers(10, -0.5, 2 * math.pi, 0.2, 84), "angles wrap round a full turn")
check(RiftBossMath.SweepCovers(-10, 0.5, math.pi, 0.2, 84), "angles wrap across pi")
check(RiftBossMath.SweepCovers(0, 0, 1, 0.2, 84), "standing on the boss is always hit")
local beam = set(RiftBossMath.SweepHits(0, 0, 0, 0.17, 84, {
	ahead = { X = 30, Z = 1 },
	behind = { X = -30, Z = 0 },
	far = { X = 200, Z = 0 },
}))
check(beam.ahead and not beam.behind and not beam.far, "sweep hits only fighters in the beam")

-- Islands: every boss fights somewhere real, and the new ones sit clear of the map.
local function flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end
local audioSource = string.gsub(fs.readFile("src/Client/AstralForge/AudioKit.luau"), "\r\n", "\n")
local BEATS = { "Forming", "Awake", "Charge", "Land", "Phase", "Defeat", "Escape" }
local islands = {}
for _, boss in roster do
	local label = boss.Name
	local place = Layout.region(boss.Island)
	check(place ~= nil, label .. ": island " .. tostring(boss.Island) .. " is not in the layout")
	check(not islands[boss.Island], label .. ": shares an island")
	islands[boss.Island] = true
	check(type(boss.Approach) == "string" and #boss.Approach > 0, label .. ": no approach line")
	for _, beat in BEATS do
		local cue = boss.Cues[beat]
		check(type(cue) == "string", label .. ": no " .. beat .. " cue")
		check(string.find(audioSource, "\n\t" .. cue .. " = {", 1, true) ~= nil, label .. ": cue " .. cue .. " is not defined in AudioKit")
	end
	check(type(boss.Music.Bed) == "string" and boss.Music.Pitch > 0 and boss.Music.Level > 0 and boss.Music.Level <= 1, label .. ": bad music profile")
	local arena = Layout.arena(boss.Island)
	for _, attack in boss.Attacks do
		local p = attack.Params
		if attack.Kind == "Rings" then
			local outermost = p.FirstRadius + (p.Count - 1) * p.Gap + p.Width / 2
			check(outermost <= arena.Radius, label .. ": outer ring leaves the arena")
		end
	end
end
check(#Layout.isles() == 2, "expected two boss islands")
for _, isle in Layout.isles() do
	check(flat(isle.Center, { X = 0, Z = 0 }) + isle.Radius <= Layout.WORLD_RADIUS, isle.Id .. ": outside the world")
	for _, region in Layout.regions() do
		check(flat(isle.Center, region.Center) > isle.Radius + region.Radius + 20, isle.Id .. ": too close to " .. region.Id)
	end
	for _, other in Layout.isles() do
		if other.Id ~= isle.Id then
			check(flat(isle.Center, other.Center) > isle.Radius + other.Radius + 20, isle.Id .. ": too close to " .. other.Id)
		end
	end
	check(Layout.regionAt(isle.Center).Id == isle.Id, isle.Id .. ": regionAt does not find it")
end
local maw = Layout.region("Riftmaw")
for _, bridge in Layout.isleBridges() do
	check(math.abs(flat(bridge.From, maw.Center) - (maw.Radius - 6)) < 0.5, bridge.Region .. ": bridge does not start on the Riftmaw rim")
	local isle = Layout.region(bridge.Region)
	check(math.abs(flat(bridge.To, isle.Center) - (isle.Radius - 4)) < 0.5, bridge.Region .. ": bridge does not land on the island rim")
	local points = Layout.bridgePoints(bridge, 14)
	for i = 1, #points - 1 do
		local run = flat(points[i], points[i + 1])
		check(run < 20, bridge.Region .. ": gap in the bridge")
		check(math.abs(points[i + 1].Y - points[i].Y) / math.max(run, 0.1) < 0.4, bridge.Region .. ": bridge too steep")
	end
end
-- Beatable: one level-1 fighter, no crits, striking once a second, inside the active window
for _, boss in roster do
	local health = RiftBossMath.MaxHealth(1, boss)
	local damage = RiftBossMath.StrikeDamage(1, 0, 0.99, boss)
	check(health / damage <= boss.ActiveSeconds, (boss.Name or "boss") .. ": a lone level-1 fighter cannot win in time")
end

print("[TEST] rift boss roster guards passed | " .. #roster .. " bosses")
