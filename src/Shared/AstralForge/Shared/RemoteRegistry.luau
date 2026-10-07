--!strict
-- Purpose: Typed, sealed request schemas for new server routes; malformed and extra fields are rejected.
-- Owner: Astral Forge networking. Dependencies: ArcadeTypes/ArcadeConfig. Last-reviewed: 2026-10-05.
local Types = require("./ArcadeTypes")
local Config = require("./ArcadeConfig")
export type WireValue = nil | boolean | number | string | { [string | number]: WireValue }
export type TableValue = { [string | number]: WireValue }
export type RouteLimit = { Cost: number, Cooldown: number }
export type API = {
	arcade: (payload: WireValue) -> (Types.Request?, string?),
	readOnly: (payload: WireValue) -> (boolean, string?),
	limits: { [string]: RouteLimit },
}
local MAX_INTEGER = 9007199254740991 -- Numeric wire representation must remain exact.
local ALLOWED: { [string]: boolean } = {
	RequestId = true,
	Game = true,
	Action = true,
	Commitment = true,
	ClientSeed = true,
	Nonce = true,
	RoundId = true,
	Version = true,
	Choice = true,
	Picks = true,
	Risk = true,
	Gen = true,
	N = true,
	TxnId = true,
}
local AUTH_FIELDS: { [string]: boolean } = { Gen = true, N = true, TxnId = true }
local ACTIONS: { [string]: boolean } =
	{ Start = true, Hit = true, Stand = true, Draw = true, Stop = true, Reveal = true, Place = true }

local function text(value: WireValue, minimum: number, maximum: number): string?
	if type(value) ~= "string" or #value < minimum or #value > maximum or value:find("%c") then
		return nil
	end
	return value
end

local function integer(value: WireValue, minimum: number, maximum: number): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < minimum or value > maximum then
		return nil
	end
	return value
end

local function picks(value: WireValue): Types.Numbers?
	if type(value) ~= "table" then
		return nil
	end
	local values: Types.Numbers = {}
	local count = 0
	for key, entry in value do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 10 then
			return nil
		end
		local number = integer(entry, 1, Config.KenoNumbers)
		if not number then
			return nil
		end
		count += 1
		values[key] = number
	end
	if count ~= #values then
		return nil
	end
	for index = 1, count do
		if values[index] == nil then
			return nil
		end
	end
	return values
end

local function envelope(payload: TableValue): boolean
	if payload.Gen == nil and payload.N == nil and payload.TxnId == nil then
		return true
	end
	return integer(payload.Gen, 0, MAX_INTEGER) ~= nil
		and type(payload.N) == "string"
		and #payload.N <= 80
		and text(payload.TxnId, 1, 64) ~= nil
end

local function readOnly(payload: WireValue): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "Expected a state request."
	end
	for key in payload do
		if type(key) ~= "string" or not AUTH_FIELDS[key] then
			return false, "Unexpected state request field."
		end
	end
	if not envelope(payload) then
		return false, "Invalid authentication envelope."
	end
	return true, nil
end

local function arcade(payload: WireValue): (Types.Request?, string?)
	if type(payload) ~= "table" then
		return nil, "Expected an arcade request."
	end
	for key in payload do
		if type(key) ~= "string" or not ALLOWED[key] then
			return nil, "Unexpected arcade request field."
		end
	end
	if not envelope(payload) then
		return nil, "Invalid authentication envelope."
	end
	local requestId = text(payload.RequestId, 12, 64)
	local action = text(payload.Action, 1, 12)
	if not requestId or not requestId:match("^[%w%-_]+$") or not action or not ACTIONS[action] then
		return nil, "Invalid request ID or action."
	end
	local game: Types.GameId? = nil
	for _, entry in Config.Games do
		if entry.Id == payload.Game then
			game = entry.Id
		end
	end
	if not game then
		return nil, "Unknown arcade game."
	end
	local request: Types.Request = { RequestId = requestId, Game = game, Action = action }
	if action == "Start" then
		request.Commitment = text(payload.Commitment, 64, 64)
		request.ClientSeed = text(payload.ClientSeed, 1, 64)
		request.Nonce = integer(payload.Nonce, 0, MAX_INTEGER - 1)
		if
			not request.Commitment
			or not request.Commitment:match("^[0-9a-f]+$")
			or not request.ClientSeed
			or request.Nonce == nil
		then
			return nil, "A valid published commitment, client seed and nonce are required."
		end
		if payload.RoundId ~= nil or payload.Version ~= nil then
			return nil, "Round-start requests cannot target an existing round."
		end
	else
		request.RoundId = text(payload.RoundId, 1, 64)
		request.Version = integer(payload.Version, 1, MAX_INTEGER)
		if not request.RoundId or not request.Version then
			return nil, "Round ID and version are required."
		end
		if payload.Commitment ~= nil or payload.ClientSeed ~= nil or payload.Nonce ~= nil then
			return nil, "Existing-round actions cannot replace their seed."
		end
	end
	if payload.Choice ~= nil then
		if type(payload.Choice) == "string" then
			if
				game ~= "CoinFlip"
				or (payload.Choice ~= "Heads" and payload.Choice ~= "Tails" and payload.Choice ~= "Edge")
			then
				return nil, "Invalid choice."
			end
			request.Choice = payload.Choice
		else
			request.Choice = integer(payload.Choice, 0, Config.KenoNumbers)
			if request.Choice == nil then
				return nil, "Invalid numeric choice."
			end
		end
	end
	if payload.Picks ~= nil then
		request.Picks = picks(payload.Picks)
		if not request.Picks then
			return nil, "Invalid pick positions."
		end
	end
	if payload.Risk ~= nil then
		request.Risk = integer(payload.Risk, 1, 12)
		if not request.Risk or game ~= "Mines" or action ~= "Start" then
			return nil, "Invalid survey risk."
		end
	end
	return request, nil
end

local limits: { [string]: RouteLimit } =
	{ ArcadePlay = { Cost = 1, Cooldown = 0.2 }, GetArcade = { Cost = 0.4, Cooldown = 0.5 } }
for _, limit in limits do
	table.freeze(limit)
end
local api: API = { arcade = arcade, readOnly = readOnly, limits = table.freeze(limits) }
return table.freeze(api)
