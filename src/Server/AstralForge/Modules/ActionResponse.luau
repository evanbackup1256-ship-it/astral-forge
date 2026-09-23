--!strict
-- Pure GameService action response builders. No Roblox services —
-- ServerServices and Lune verify scripts share this so ok/error envelopes
-- stay testable without Studio. Preserves prior mutation of `extra` tables.

local ActionResponse = {}

function ActionResponse.Error(message: string): { ok: boolean, error: string }
	return { ok = false, error = message }
end

function ActionResponse.Success(message: string?, extra: any): any
	local response = extra or {}
	response.ok = true
	response.message = message
	return response
end

return table.freeze(ActionResponse)
