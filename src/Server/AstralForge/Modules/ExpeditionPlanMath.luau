--!strict

-- Purpose: validate and resolve the server-owned consequences of a planned expedition route.
-- Owner: Astral Forge progression systems.
-- Dependencies: none.
-- Last reviewed: 2026-10-07.

local ExpeditionPlanMath = {}

export type Plan = {
	Name: string,
	Description: string,
	SignalCost: number,
	DurationScale: number,
	RewardScale: number,
	ArtifactChanceBonus: number,
}

export type PlanSnapshot = {
	Id: string,
	SignalCost: number,
	RewardScale: number,
	ArtifactChanceBonus: number,
}

export type Reward = {
	CashMinutes: number?,
	Stardust: number?,
	Signals: number?,
	CommandXP: number?,
	Cores: number?,
}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function nonNegativeInteger(value: number): number
	if not finite(value) then
		return 0
	end
	return math.max(0, math.floor(value))
end

function ExpeditionPlanMath.Resolve(plans: { [string]: Plan }, id: string): Plan?
	local plan = plans[id]
	if plan == nil then
		return nil
	end
	if
		not finite(plan.SignalCost)
		or plan.SignalCost < 0
		or not finite(plan.DurationScale)
		or plan.DurationScale < 0.35
		or plan.DurationScale > 2
		or not finite(plan.RewardScale)
		or plan.RewardScale < 0.5
		or plan.RewardScale > 2
		or not finite(plan.ArtifactChanceBonus)
		or math.abs(plan.ArtifactChanceBonus) > 0.5
	then
		return nil
	end
	return plan
end

function ExpeditionPlanMath.Quote(availableSignals: number, plan: Plan): (boolean, number, number)
	local available = nonNegativeInteger(availableSignals)
	local cost = nonNegativeInteger(plan.SignalCost)
	return available >= cost, cost, math.max(0, available - cost)
end

function ExpeditionPlanMath.Snapshot(id: string, plan: Plan): PlanSnapshot
	return {
		Id = id,
		SignalCost = nonNegativeInteger(plan.SignalCost),
		RewardScale = if finite(plan.RewardScale) then math.clamp(plan.RewardScale, 0.5, 2) else 1,
		ArtifactChanceBonus = if finite(plan.ArtifactChanceBonus)
			then math.clamp(plan.ArtifactChanceBonus, -0.5, 0.5)
			else 0,
	}
end

function ExpeditionPlanMath.MigrateSnapshot(value: any): PlanSnapshot
	if type(value) ~= "table" then
		return ExpeditionPlanMath.Snapshot("Standard", {
			Name = "Direct route",
			Description = "",
			SignalCost = 0,
			DurationScale = 1,
			RewardScale = 1,
			ArtifactChanceBonus = 0,
		})
	end
	return {
		Id = if type(value.Id) == "string" and #value.Id <= 40 then value.Id else "Standard",
		SignalCost = nonNegativeInteger(tonumber(value.SignalCost) or 0),
		RewardScale = if finite(tonumber(value.RewardScale) or 0)
			then math.clamp(tonumber(value.RewardScale) or 1, 0.5, 2)
			else 1,
		ArtifactChanceBonus = if finite(tonumber(value.ArtifactChanceBonus) or 0)
			then math.clamp(tonumber(value.ArtifactChanceBonus) or 0, -0.5, 0.5)
			else 0,
	}
end

function ExpeditionPlanMath.Duration(baseDuration: number, pilotLevel: number, plan: Plan): number
	local safeBase = if finite(baseDuration) then math.max(10, baseDuration) else 10
	local safePilot = math.max(1, nonNegativeInteger(pilotLevel))
	local pilotScale = math.max(0.35, 1 - (safePilot - 1) * 0.05)
	return math.max(10, math.floor(safeBase * pilotScale * plan.DurationScale))
end

function ExpeditionPlanMath.ScaleReward(reward: Reward, engineerLevel: number, plan: Plan): Reward
	local result: Reward = table.clone(reward)
	local engineerScale = 1 + (math.max(1, nonNegativeInteger(engineerLevel)) - 1) * 0.08
	local fields: { "CashMinutes" | "Stardust" | "Signals" | "CommandXP" | "Cores" } = {
		"CashMinutes",
		"Stardust",
		"Signals",
		"CommandXP",
		"Cores",
	}
	for _, field in fields do
		local amount = result[field]
		if amount ~= nil then
			local specialistScale = if field == "CashMinutes" or field == "Stardust" or field == "Signals"
				then engineerScale
				else 1
			result[field] = math.max(0, math.floor(amount * plan.RewardScale * specialistScale))
		end
	end
	return result
end

function ExpeditionPlanMath.ArtifactChance(baseChance: number, navigatorLevel: number, plan: Plan): number
	local base = if finite(baseChance) then baseChance else 0
	local navigatorBonus = (math.max(1, nonNegativeInteger(navigatorLevel)) - 1) * 0.03
	return math.clamp(base + navigatorBonus + plan.ArtifactChanceBonus, 0, 0.95)
end

return table.freeze(ExpeditionPlanMath)
