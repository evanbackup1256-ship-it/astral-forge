--!strict
-- Purpose: Astral Forge anti-cheat wrapper: velocity checks, payload validation, client-integrity signals, quarantine.
-- Owner: Astral Forge server security. Dependencies: GameAntiCheat, RemoteFirewall, SessionGate, GameConfig. Last-reviewed: 2026-10-05.

export type ForgeAntiCheat = {
	ValidatePayload: (self: ForgeAntiCheat, player: Player, action: string, payload: any) -> (boolean, string?),
	ObserveMutation: (self: ForgeAntiCheat, player: Player, profile: any) -> (boolean, string?),
	RecordIntegrity: (self: ForgeAntiCheat, player: Player, report: any) -> (boolean, string?),
	IsQuarantined: (self: ForgeAntiCheat, player: Player) -> boolean,
}

local ForgeAntiCheat = {}
ForgeAntiCheat.__index = ForgeAntiCheat

function ForgeAntiCheat.new(): ForgeAntiCheat
	local self = setmetatable({}, ForgeAntiCheat)
	return self :: any
end

function ForgeAntiCheat:ValidatePayload(_player: Player, _action: string, _payload: any): (boolean, string?)
	-- TODO: delegate to RemoteFirewall.validateActionPayload + custom Astral Forge schemas
	return true, nil
end

function ForgeAntiCheat:ObserveMutation(_player: Player, _profile: any): (boolean, string?)
	-- TODO: delegate to GameAntiCheat:Observe; return wouldReject + reason
	return false, nil
end

function ForgeAntiCheat:RecordIntegrity(_player: Player, _report: any): (boolean, string?)
	-- TODO: corroborate client integrity signals; never auto-punish on client report alone
	return true, nil
end

function ForgeAntiCheat:IsQuarantined(_player: Player): boolean
	-- TODO: query RemoteFirewall player state
	return false
end

return table.freeze(ForgeAntiCheat)
