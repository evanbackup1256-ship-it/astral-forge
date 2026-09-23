--!strict
-- Pure fortune-wheel bag ensure / readiness snapshot / pity pool helpers.
-- No Roblox services — ProgressionService and Lune verify scripts share this so
-- FreeSpins-only bags and pity floors can be tested without Studio. Random rolls
-- and ApplyReward mutation stay with the caller; reward tables are injected.

local WheelMath = {}

WheelMath.RARITY_RANK = {
	COMMON = 1,
	UNCOMMON = 2,
	RARE = 3,
	EPIC = 4,
	LEGENDARY = 5,
	MYTHIC = 6,
}

export type WheelBag = {
	LastSpinAt: number,
	Spins: number,
	PityMisses: number,
	FreeSpins: number,
}

export type PoolEntry = {
	Index: number,
	Prize: any,
	Weight: number,
}

-- ApplyReward FreeSpins may seed Wheel={FreeSpins=N} without LastSpinAt/Spins/
-- PityMisses — WheelState / SpinWheel must rebuild before arithmetic.
function WheelMath.Ensure(wheel: any): WheelBag
	if type(wheel) ~= "table" then
		return {
			LastSpinAt = 0,
			Spins = 0,
			PityMisses = 0,
			FreeSpins = 0,
		}
	end
	wheel.LastSpinAt = math.max(0, math.floor(tonumber(wheel.LastSpinAt) or 0))
	wheel.Spins = math.max(0, math.floor(tonumber(wheel.Spins) or 0))
	wheel.PityMisses = math.max(0, math.floor(tonumber(wheel.PityMisses) or 0))
	wheel.FreeSpins = math.max(0, math.floor(tonumber(wheel.FreeSpins) or 0))
	return wheel :: WheelBag
end

function WheelMath.RarityRank(rarity: any): number
	return WheelMath.RARITY_RANK[string.upper(tostring(rarity or ""))] or 1
end

-- Readiness snapshot for client WheelState. Mutates nothing; callers Ensure first.
function WheelMath.Snapshot(
	now: number,
	wheel: WheelBag,
	cooldownSeconds: number,
	pityAfter: number
): {
	CanSpin: boolean,
	ReadyAt: number,
	Spins: number,
	FreeSpins: number,
	PityMisses: number,
	PityAfter: number,
	PityArmed: boolean,
}
	local safeCooldown = math.max(0, math.floor(tonumber(cooldownSeconds) or 0))
	local safePityAfter = math.max(1, math.floor(tonumber(pityAfter) or 8))
	local readyAt = wheel.LastSpinAt + safeCooldown
	local freeSpins = wheel.FreeSpins
	local pityMisses = wheel.PityMisses
	local cooldownReady = now >= readyAt
	return {
		CanSpin = freeSpins > 0 or cooldownReady,
		ReadyAt = if freeSpins > 0 then now else math.max(now, readyAt),
		Spins = wheel.Spins,
		FreeSpins = freeSpins,
		PityMisses = pityMisses,
		PityAfter = safePityAfter,
		PityArmed = pityMisses + 1 >= safePityAfter,
	}
end

-- Pity-filtered weight pool. When forcePity empties the pool, callers fall back
-- to the unfiltered rewards table (mirrors former SpinWheel behavior).
function WheelMath.BuildPool(
	rewards: { any },
	forcePity: boolean,
	floorRank: number
): ({ PoolEntry }, number)
	local pool: { PoolEntry } = {}
	local totalWeight = 0
	for index, prize in rewards do
		local rank = WheelMath.RarityRank(prize.Rarity)
		if not forcePity or rank >= floorRank then
			local weight = math.max(0, tonumber(prize.Weight) or 0)
			table.insert(pool, { Index = index, Prize = prize, Weight = weight })
			totalWeight += weight
		end
	end
	return pool, totalWeight
end

function WheelMath.FullPool(rewards: { any }): ({ PoolEntry }, number)
	return WheelMath.BuildPool(rewards, false, 1)
end

-- Weighted pick. `roll` is in [0, totalWeight]; empty pool → nil.
function WheelMath.PickEntry(pool: { PoolEntry }, totalWeight: number, roll: number): PoolEntry?
	if #pool == 0 or totalWeight <= 0 then
		return nil
	end
	local selected = pool[#pool]
	local cursor = 0
	for _, entry in pool do
		cursor += entry.Weight
		if roll <= cursor then
			selected = entry
			break
		end
	end
	return selected
end

-- After a spin: clear pity on floor+ hit, else increment.
function WheelMath.NextPityMisses(pityMisses: any, selectedRank: number, floorRank: number): number
	if selectedRank >= floorRank then
		return 0
	end
	return math.max(0, math.floor(tonumber(pityMisses) or 0)) + 1
end

return table.freeze(WheelMath)
