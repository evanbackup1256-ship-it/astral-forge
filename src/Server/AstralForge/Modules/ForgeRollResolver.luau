--!strict
-- Purpose: Server-side RNG and state-machine resolution for Astral Forge rolls: anomaly pulse, echoes, wheel, expedition artifacts.
-- Owner: Astral Forge server logic. Dependencies: GameConfig, AnomalyPulseScore, WheelMath, ForgeEchoMath. Last-reviewed: 2026-10-05.

export type RollOutcome = {
	ok: boolean,
	result: any?,
	error: string?,
}

export type ForgeRollResolver = {
	ResolvePulse: (self: ForgeRollResolver, profile: any, now: number) -> RollOutcome,
	ResolveCaptureEcho: (self: ForgeRollResolver, profile: any) -> RollOutcome,
	ResolveSpinWheel: (self: ForgeRollResolver, profile: any, freeSpin: boolean) -> RollOutcome,
	ResolveExpeditionArtifact: (self: ForgeRollResolver, profile: any, expeditionId: string) -> RollOutcome,
}

local ForgeRollResolver = {}
ForgeRollResolver.__index = ForgeRollResolver

function ForgeRollResolver.new(): ForgeRollResolver
	local self = setmetatable({}, ForgeRollResolver)
	-- TODO: seed random source deterministically per server
	return self :: any
end

function ForgeRollResolver:ResolvePulse(_profile: any, _now: number): RollOutcome
	-- TODO: move AnomalyService.Pulse resolution here
	return { ok = false, error = "not implemented" }
end

function ForgeRollResolver:ResolveCaptureEcho(_profile: any): RollOutcome
	-- TODO: move ForgeEchoService.Capture resolution here
	return { ok = false, error = "not implemented" }
end

function ForgeRollResolver:ResolveSpinWheel(_profile: any, _freeSpin: boolean): RollOutcome
	-- TODO: move ProgressionService.SpinWheel resolution here
	return { ok = false, error = "not implemented" }
end

function ForgeRollResolver:ResolveExpeditionArtifact(_profile: any, _expeditionId: string): RollOutcome
	-- TODO: deterministic artifact roll with server nonce
	return { ok = false, error = "not implemented" }
end

return table.freeze(ForgeRollResolver)
