--!strict
-- Pure rules for the Rift Warden, the sanctuary's shared boss.
--
--   Dormant --(timer)--> Forming --(timer)--> Active --(health 0)--> Defeated --> Dormant
--                                                 \--(timer)------> Escaped  --> Dormant
--
-- No Roblox services and no clock of its own: every function takes `now`, and
-- randomness comes in as numbers, so RiftBossService and the Lune tests
-- (scripts/verify_sanctuary_world.luau) run exactly the same logic.

local RiftBossMath = {}

export type Phase = "Dormant" | "Forming" | "Active" | "Defeated" | "Escaped"

export type State = {
	Phase: Phase,
	EndsAt: number,
	Health: number,
	MaxHealth: number,
}

type BossConfig = {
	IntervalSeconds: number,
	FirstDelaySeconds: number,
	FormingSeconds: number,
	ActiveSeconds: number,
	OutroSeconds: number,
	BaseHealth: number,
	HealthPerFighter: number,
	BaseDamage: number,
	DamagePerLevel: number,
	CritChance: number,
	CritMultiplier: number,
	SlamIntervalMin: number,
	SlamIntervalMax: number,
	MinStrikesForReward: number,
	Rewards: { [string]: { Base: number, Share: number } },
}

function RiftBossMath.Initial(now: number, config: BossConfig): State
	return { Phase = "Dormant", EndsAt = now + config.FirstDelaySeconds, Health = 0, MaxHealth = 0 }
end

-- Health scales with the fighters present when it wakes, never below one.
function RiftBossMath.MaxHealth(fighters: number, config: BossConfig): number
	return config.BaseHealth + config.HealthPerFighter * math.max(1, math.floor(fighters))
end

-- One strike. `critRoll` is uniform in [0, 1).
function RiftBossMath.StrikeDamage(level: number, bonus: number, critRoll: number, config: BossConfig): (number, boolean)
	local base = config.BaseDamage + config.DamagePerLevel * math.max(1, math.floor(level))
	local crit = critRoll < config.CritChance
	local damage = base * (1 + math.max(0, bonus)) * (if crit then config.CritMultiplier else 1)
	return math.max(1, math.floor(damage + 0.5)), crit
end

-- Advance the phase machine to `now`. `fighters` is read only when the Warden
-- wakes. Returns the new state and the phase that was entered (nil if none).
function RiftBossMath.Step(state: State, now: number, fighters: number, config: BossConfig): (State, Phase?)
	local phase = state.Phase
	if phase == "Active" and state.Health <= 0 then
		return { Phase = "Defeated", EndsAt = now + config.OutroSeconds, Health = 0, MaxHealth = state.MaxHealth }, "Defeated"
	end
	if now < state.EndsAt then
		return state, nil
	end
	if phase == "Dormant" then
		return { Phase = "Forming", EndsAt = now + config.FormingSeconds, Health = 0, MaxHealth = 0 }, "Forming"
	elseif phase == "Forming" then
		local health = RiftBossMath.MaxHealth(fighters, config)
		return { Phase = "Active", EndsAt = now + config.ActiveSeconds, Health = health, MaxHealth = health }, "Active"
	elseif phase == "Active" then
		return { Phase = "Escaped", EndsAt = now + config.OutroSeconds, Health = state.Health, MaxHealth = state.MaxHealth }, "Escaped"
	end
	-- Defeated or Escaped: the outro is over.
	return { Phase = "Dormant", EndsAt = now + config.IntervalSeconds, Health = 0, MaxHealth = 0 }, "Dormant"
end

-- Apply damage. Health never goes below zero.
function RiftBossMath.Hit(state: State, damage: number): State
	return {
		Phase = state.Phase,
		EndsAt = state.EndsAt,
		Health = math.max(0, state.Health - math.max(0, damage)),
		MaxHealth = state.MaxHealth,
	}
end

-- Seconds until the next slam; `roll` is uniform in [0, 1).
function RiftBossMath.SlamDelay(roll: number, config: BossConfig): number
	return config.SlamIntervalMin + (config.SlamIntervalMax - config.SlamIntervalMin) * math.clamp(roll, 0, 1)
end

-- Which fighters a slam catches: horizontal distance to the centre within the
-- radius. `positions` maps an id to {X, Z}.
function RiftBossMath.SlamHits(centerX: number, centerZ: number, radius: number, positions: { [any]: { X: number, Z: number } }): { any }
	local hits = {}
	for id, position in positions do
		local dx, dz = position.X - centerX, position.Z - centerZ
		if dx * dx + dz * dz <= radius * radius then
			table.insert(hits, id)
		end
	end
	return hits
end

-- Rewards on defeat. `damage[id]` is damage dealt, `strikes[id]` strike count.
-- A fighter with fewer than MinStrikesForReward strikes gets nothing; the rest
-- get Base + Share x (their damage / all counted damage), rounded.
function RiftBossMath.Rewards(damage: { [any]: number }, strikes: { [any]: number }, config: BossConfig): { [any]: { [string]: number } }
	local counted = 0
	for id, dealt in damage do
		if (strikes[id] or 0) >= config.MinStrikesForReward then
			counted += math.max(0, dealt)
		end
	end
	local result = {}
	if counted <= 0 then
		return result
	end
	for id, dealt in damage do
		if (strikes[id] or 0) < config.MinStrikesForReward then
			continue
		end
		local share = math.max(0, dealt) / counted
		local bag = {}
		for currency, rule in config.Rewards do
			bag[currency] = math.floor(rule.Base + rule.Share * share + 0.5)
		end
		bag.Share = share
		result[id] = bag
	end
	return result
end

return table.freeze(RiftBossMath)
