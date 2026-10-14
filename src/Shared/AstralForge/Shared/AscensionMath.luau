--!strict
-- Ascension: the last reset layer, above Domain. It never caps.
--
--   ascend   : needs a Domain rank that rises with every ascension. Resets the Domain (rank, essence,
--              tree), rebirths, cores and the current run. Research, relics, artifacts, Continuum stay.
--   pays     : Aether, more the further past the requirement you go, and +1 Ascension rank, which is
--              a permanent production multiplier.
--   sigils   : six upgrades bought with Aether, each with no level cap.
--   harmony  : the lowest level among all six sigils. Every sigil acts that many levels higher, so
--              raising all six together beats pumping one.
--
-- Pure: OmegaMath is passed in so the server, the client and Lune share one set of numbers.

local AscensionMath = {} :: any

export type Sigil = {
	Id: string,
	Name: string,
	Effect: string, -- what it multiplies
	Line: string, -- one plain sentence for the card
	Per: number, -- multiplier per effective level
	BaseCost: number,
	Growth: number,
}

AscensionMath.SIGILS = table.freeze({
	table.freeze({ Id = "Sol", Name = "Sol", Effect = "Production", Line = "Multiplies all flux production.", Per = 1.2, BaseCost = 1, Growth = 1.6 }),
	table.freeze({ Id = "Bastion", Name = "Bastion", Effect = "Capacity", Line = "Multiplies vault capacity.", Per = 1.15, BaseCost = 1, Growth = 1.55 }),
	table.freeze({ Id = "Strike", Name = "Strike", Effect = "Tap", Line = "Multiplies overcharge power.", Per = 1.25, BaseCost = 1, Growth = 1.5 }),
	table.freeze({ Id = "Ember", Name = "Ember", Effect = "Cores", Line = "Multiplies cores from every rebirth.", Per = 1.3, BaseCost = 2, Growth = 1.65 }),
	table.freeze({ Id = "Crown", Name = "Crown", Effect = "Essence", Line = "Multiplies Domain essence from every expansion.", Per = 1.2, BaseCost = 2, Growth = 1.7 }),
	table.freeze({ Id = "Lodestar", Name = "Lodestar", Effect = "Aether", Line = "Multiplies Aether from every ascension.", Per = 1.1, BaseCost = 3, Growth = 1.8 }),
})
local BY_ID: { [string]: Sigil } = {}
for _, sigil in AscensionMath.SIGILS do
	BY_ID[sigil.Id] = sigil
end

AscensionMath.RANK_EXPONENT = 1.5 -- production x (1 + rank) ^ 1.5

export type State = { Rank: number, Aether: any, TotalAether: any, Sigils: { [string]: number }, LastAscendedAt: number }

local function whole(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

function AscensionMath.sigil(id: string): Sigil?
	return BY_ID[id]
end

-- A clean state from whatever the save holds.
function AscensionMath.sanitize(raw: any, OmegaMath: any): State
	local source = if type(raw) == "table" then raw else {}
	local sigils = {}
	if type(source.Sigils) == "table" then
		for id, level in source.Sigils do
			if type(id) == "string" and BY_ID[id] ~= nil then
				sigils[id] = whole(level)
			end
		end
	end
	local function amount(value: any): any
		local ok, persisted = pcall(OmegaMath.Persist, value or 0)
		if not ok or OmegaMath.Lt(persisted, 0) then
			return 0
		end
		return persisted
	end
	return {
		Rank = whole(source.Rank),
		Aether = amount(source.Aether),
		TotalAether = amount(source.TotalAether),
		Sigils = sigils,
		LastAscendedAt = whole(source.LastAscendedAt),
	}
end

-- Domain rank needed for the (n+1)th ascension. Rises forever.
function AscensionMath.requiredDomainRank(rank: number): number
	local n = math.max(0, math.floor(rank))
	return math.floor(25 + 15 * n + 2 * n ^ 1.6)
end

function AscensionMath.harmony(state: State): number
	local lowest = math.huge
	for _, sigil in AscensionMath.SIGILS do
		lowest = math.min(lowest, state.Sigils[sigil.Id] or 0)
	end
	return if lowest == math.huge then 0 else lowest
end

-- The level a sigil acts at: its own level plus harmony (zero when unbought: harmony lifts only
-- sigils you have started).
function AscensionMath.effectiveLevel(state: State, id: string): number
	local level = state.Sigils[id] or 0
	if level <= 0 then
		return 0
	end
	return level + AscensionMath.harmony(state)
end

function AscensionMath.sigilMultiplier(state: State, id: string, OmegaMath: any): any
	local sigil = BY_ID[id]
	if sigil == nil then
		return 1
	end
	return OmegaMath.Pow(sigil.Per, AscensionMath.effectiveLevel(state, id))
end

function AscensionMath.sigilCost(id: string, level: number, OmegaMath: any): any
	local sigil = BY_ID[id]
	assert(sigil, "unknown sigil " .. tostring(id))
	-- + level keeps cheap early levels strictly rising (ScaledCost floors 1.0 and 1.6 to the same 1)
	local n = math.max(0, math.floor(level))
	return OmegaMath.Add(OmegaMath.ScaledCost(sigil.BaseCost, sigil.Growth, n), n)
end

-- Multiplier for one effect kind: Production also gets the Ascension rank.
function AscensionMath.effect(state: State, kind: string, OmegaMath: any): any
	local total: any = 1
	for _, sigil in AscensionMath.SIGILS do
		if sigil.Effect == kind then
			total = OmegaMath.Mul(total, AscensionMath.sigilMultiplier(state, sigil.Id, OmegaMath))
		end
	end
	if kind == "Production" and state.Rank > 0 then
		total = OmegaMath.Mul(total, OmegaMath.Pow(1 + state.Rank, AscensionMath.RANK_EXPONENT))
	end
	return total
end

-- Aether for ascending at `domainRank` with `rank` ascensions done. Going past the requirement pays
-- more; Lodestar multiplies it. Nil when the requirement isn't met.
function AscensionMath.aetherGain(state: State, domainRank: number, OmegaMath: any): any?
	local required = AscensionMath.requiredDomainRank(state.Rank)
	local reached = math.max(0, math.floor(domainRank))
	if reached < required then
		return nil
	end
	local base = math.floor((reached / required) ^ 1.5 * (3 + state.Rank))
	return OmegaMath.Floor(OmegaMath.Mul(math.max(1, base), AscensionMath.effect(state, "Aether", OmegaMath)))
end

-- Buy one level of a sigil; returns (newState, cost) or (nil, reason).
function AscensionMath.buy(state: State, id: string, OmegaMath: any): (State?, any)
	local sigil = BY_ID[id]
	if sigil == nil then
		return nil, "That sigil doesn't exist."
	end
	local level = state.Sigils[id] or 0
	local cost = AscensionMath.sigilCost(id, level, OmegaMath)
	if OmegaMath.Lt(state.Aether, cost) then
		return nil, `You need {OmegaMath.ToString(OmegaMath.Sub(cost, state.Aether))} more Aether.`
	end
	local nextSigils = table.clone(state.Sigils)
	nextSigils[id] = level + 1
	return {
		Rank = state.Rank,
		Aether = OmegaMath.Sub(state.Aether, cost),
		TotalAether = state.TotalAether,
		Sigils = nextSigils,
		LastAscendedAt = state.LastAscendedAt,
	}, cost
end

-- The ascension itself (state side only; the caller resets the rest of the profile).
function AscensionMath.ascend(state: State, domainRank: number, now: number, OmegaMath: any): (State?, any)
	local gain = AscensionMath.aetherGain(state, domainRank, OmegaMath)
	if gain == nil then
		return nil, `Reach Domain rank {AscensionMath.requiredDomainRank(state.Rank)} to ascend.`
	end
	return {
		Rank = state.Rank + 1,
		Aether = OmegaMath.Add(state.Aether, gain),
		TotalAether = OmegaMath.Add(state.TotalAether, gain),
		Sigils = table.clone(state.Sigils),
		LastAscendedAt = math.max(0, math.floor(now)),
	}, gain
end

return table.freeze(AscensionMath)
