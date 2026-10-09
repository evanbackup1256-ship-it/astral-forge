--!strict
-- Purpose: Client-side typed remote facade for Astral Forge actions: rate-limit awareness, request timeouts, idempotency, optimistic patches.
-- Owner: Astral Forge client boundary. Dependencies: Protocol, remotes.Request, NetworkPolicy, ClientActions. Last-reviewed: 2026-10-05.

export type RequestPayload = {
	action: string,
	payload: any,
	optimistic: boolean?,
	timeout: number?,
}

export type RequestResult = {
	ok: boolean,
	result: any?,
	error: string?,
}

export type ForgeService = {
	Request: (self: ForgeService, action: string, payload: any) -> RequestResult,
	RequestWithOptions: (self: ForgeService, options: RequestPayload) -> RequestResult,
	SetIdempotencyKey: (self: ForgeService, key: string) -> (),
}

local ForgeService = {}
ForgeService.__index = ForgeService

function ForgeService.new(): ForgeService
	local self = setmetatable({}, ForgeService)
	return self :: any
end

function ForgeService:Request(_action: string, _payload: any): RequestResult
	-- TODO: centralize the existing dispatch logic from UiCore MainGame
	return { ok = false, error = "not implemented" }
end

function ForgeService:RequestWithOptions(_options: RequestPayload): RequestResult
	-- TODO: apply optimistic patch, timeout, in-flight tracking
	return { ok = false, error = "not implemented" }
end

function ForgeService:SetIdempotencyKey(_key: string): ()
	-- TODO: set per-request TxnId / Gen / N
end

return table.freeze(ForgeService)
