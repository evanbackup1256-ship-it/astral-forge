--!strict
-- Pure guild upgrade cost/effect, bonus aggregation, contribution amount
-- normalization, goal target sizing, and bank afford checks. No Roblox
-- services — GuildService and Lune verify scripts share this so hall math
-- can be tested without Studio. Datastore / membership / Omega cash mutation
-- stay with the caller; definitions are injected.

local GuildMath = {}

GuildMath.MAX_NUMBER = 1e308
GuildMath.BONUS_KEYS = { "Production", "Capacity", "Offline", "Automation", "Tap" }

export type UpgradeDefinition = {
	BaseCost: number,
	CostScale: number,
	EffectPerLevel: number,
	MaxLevel: number?,
	Currency: string?,
	Bonus: string?,
	Tiers: { { Name: string?, Effect: number?, Cost: number? } }?,
}

function GuildMath.FiniteNonNegative(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(value, 0, GuildMath.MAX_NUMBER)
end

-- Tier unlocked by buying level `level` (1-indexed named tiers).
function GuildMath.UpgradeTier(definition: UpgradeDefinition, level: number): any
	local tiers = definition.Tiers
	if type(tiers) ~= "table" then
		return nil
	end
	if level < 1 or level > #tiers then
		return nil
	end
	return tiers[level]
end

-- `level` is the current level; the purchase being priced is level + 1.
function GuildMath.UpgradeCost(definition: UpgradeDefinition, level: number): number
	local tier = GuildMath.UpgradeTier(definition, level + 1)
	if tier and type(tier.Cost) == "number" then
		return math.floor(tier.Cost + 0.5)
	end
	return math.floor(definition.BaseCost * definition.CostScale ^ math.max(0, level) + 0.5)
end

-- Cumulative named-tier effects, then endless EffectPerLevel tail.
function GuildMath.UpgradeEffect(definition: UpgradeDefinition, level: number): number
	local safeLevel = math.max(0, math.floor(level))
	if safeLevel <= 0 then
		return 0
	end
	local tiers = definition.Tiers
	if type(tiers) ~= "table" then
		return safeLevel * definition.EffectPerLevel
	end
	local total = 0
	local named = math.min(safeLevel, #tiers)
	for index = 1, named do
		local tier = tiers[index]
		total += (type(tier) == "table" and type(tier.Effect) == "number") and tier.Effect or 0
	end
	if safeLevel > named then
		total += (safeLevel - named) * definition.EffectPerLevel
	end
	return total
end

function GuildMath.EmptyBonuses(): { [string]: number }
	local result = {}
	for _, key in GuildMath.BONUS_KEYS do
		result[key] = 0
	end
	return result
end

-- Sum upgrade effects into bonus keys, soft-capped at 1.0 per key.
function GuildMath.BonusesFromUpgrades(
	upgrades: { [string]: any }?,
	upgradeDefs: { [string]: UpgradeDefinition }
): { [string]: number }
	local result = GuildMath.EmptyBonuses()
	if type(upgrades) ~= "table" then
		return result
	end
	for id, level in upgrades do
		local definition = upgradeDefs[id]
		if definition and type(level) == "number" then
			local key = definition.Bonus
			if key ~= nil and result[key] ~= nil then
				result[key] = math.min(1, result[key] + GuildMath.UpgradeEffect(definition, level))
			end
		end
	end
	return result
end

-- Co-op goal target scales with roster size beyond the founder.
function GuildMath.GoalTarget(baseTarget: number, targetPerMember: number, members: number): number
	return math.max(
		1,
		math.floor(baseTarget + targetPerMember * math.max(0, members - 1) + 0.5)
	)
end

-- Contribution amount gate shared by ContributeBank. Returns floor(amount) or nil + reason.
function GuildMath.NormalizeContributionAmount(amount: any): (number?, string?)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge or amount < 1 or amount > GuildMath.MAX_NUMBER then
		return nil, "Pick a positive contribution amount."
	end
	return math.floor(amount), nil
end

-- Bank affordability: Cash uses injected OmegaMath.Gte/not Lt; Dust is numeric.
function GuildMath.CanAffordBank(omegaMath: any, currency: string, bank: any, cost: number): boolean
	if currency == "Cash" then
		return not omegaMath.Lt(bank or 0, cost)
	end
	return (tonumber(bank) or 0) >= cost
end

-- Credit bank for a contribution. Cash goes through OmegaMath.Add; Dust clamps.
function GuildMath.CreditBank(omegaMath: any, currency: string, bank: any, amount: number): any
	if currency == "Cash" then
		return omegaMath.Add(bank or 0, amount)
	end
	return math.min(GuildMath.MAX_NUMBER, GuildMath.FiniteNonNegative(bank) + amount)
end

-- Debit bank for an upgrade purchase. Returns nextBank or nil when unaffordable.
function GuildMath.DebitBank(omegaMath: any, currency: string, bank: any, cost: number): any?
	if not GuildMath.CanAffordBank(omegaMath, currency, bank, cost) then
		return nil
	end
	if currency == "Cash" then
		return omegaMath.Sub(bank or 0, cost)
	end
	return (tonumber(bank) or 0) - cost
end

function GuildMath.AddClamped(current: any, amount: number): number
	return math.min(GuildMath.MAX_NUMBER, GuildMath.FiniteNonNegative(current) + amount)
end

-- Fallback public hall bag when GetCachedPublic misses (wave47).
function GuildMath.EmptyHall(membership: any)
	local tag = type(membership) == "table" and type(membership.Tag) == "string" and membership.Tag or ""
	local guildId = type(membership) == "table" and membership.Id or ""
	return {
		Id = guildId,
		Name = "Guild Hall",
		Tag = tag,
		Level = 1,
		XP = 0,
		Activity = 0,
		BankCash = 0,
		BankDust = 0,
		Members = {},
		Upgrades = {},
		CreatedAt = 0,
		OwnerUserId = 0,
	}
end

-- Snapshot Guild bag for client rails: nil when not joined, cached public, or empty hall.
function GuildMath.SnapshotPublic(membership: any, publicGuild: any): any
	local guildId = type(membership) == "table" and membership.Id or ""
	if guildId == "" then
		return nil
	end
	if publicGuild ~= nil then
		return publicGuild
	end
	return GuildMath.EmptyHall(membership)
end

return table.freeze(GuildMath)
