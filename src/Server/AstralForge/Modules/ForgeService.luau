--!strict
-- Purpose: Server-side Astral Forge remote request dispatcher: validation, rate limits, session gate, idempotency, action routing.
-- Owner: Astral Forge server boundary. Dependencies: Protocol, SecurityServices, SessionGate, RemoteFirewall, ForgeRollResolver, ForgePersistence, ForgeAnalytics, ForgeAntiCheat. Last-reviewed: 2026-10-05.

export type ForgeService = {
	Start: (self: ForgeService) -> (),
	Stop: (self: ForgeService) -> (),
	HandleRequest: (self: ForgeService, player: Player, action: string, payload: any) -> any,
}

local ForgeService = {}
ForgeService.__index = ForgeService

function ForgeService.new(): ForgeService
	local self = setmetatable({}, ForgeService)
	-- TODO: inject dependencies and bind RemoteFunction.OnServerInvoke
	return self :: any
end

function ForgeService:Start(): ()
	-- TODO: wire OnServerInvoke through authority -> firewall -> session -> txn -> handler
end

function ForgeService:Stop(): ()
	-- TODO: disconnect remote binding
end

function ForgeService:HandleRequest(_player: Player, _action: string, _payload: any): any
	-- TODO: return typed response table { ok, error, ... }
	return { ok = false, error = "ForgeService not yet implemented." }
end

return table.freeze(ForgeService)
