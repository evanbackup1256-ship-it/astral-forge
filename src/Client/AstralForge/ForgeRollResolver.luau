--!strict
-- Purpose: Client-side visual resolution of server-authoritative Astral Forge rolls: wheel spin, crate reveal, anomaly pulse feedback.
-- Owner: Astral Forge client presentation. Dependencies: ForgeConfig, MotionKit. Last-reviewed: 2026-10-05.

export type AnimationPlan = {
	duration: number,
	keyframes: { [number]: any },
	completed: boolean,
}

export type ForgeRollResolver = {
	PlanWheelSpin: (self: ForgeRollResolver, winnerIndex: number, reducedMotion: boolean) -> AnimationPlan,
	PlanCrateReveal: (self: ForgeRollResolver, rarity: string, reducedMotion: boolean) -> AnimationPlan,
	PlanAnomalyPulse: (self: ForgeRollResolver, accurate: boolean, combo: number) -> AnimationPlan,
}

local ForgeRollResolver = {}
ForgeRollResolver.__index = ForgeRollResolver

function ForgeRollResolver.new(): ForgeRollResolver
	local self = setmetatable({}, ForgeRollResolver)
	return self :: any
end

function ForgeRollResolver:PlanWheelSpin(_winnerIndex: number, _reducedMotion: boolean): AnimationPlan
	-- TODO: consume ForgeConfig.Wheel and produce a deterministic kinematic plan
	return { duration = 0, keyframes = {}, completed = true }
end

function ForgeRollResolver:PlanCrateReveal(_rarity: string, _reducedMotion: boolean): AnimationPlan
	-- TODO: produce prismFx / crateModel reveal plan
	return { duration = 0, keyframes = {}, completed = true }
end

function ForgeRollResolver:PlanAnomalyPulse(_accurate: boolean, _combo: number): AnimationPlan
	-- TODO: produce pulse feedback plan
	return { duration = 0, keyframes = {}, completed = true }
end

return table.freeze(ForgeRollResolver)
