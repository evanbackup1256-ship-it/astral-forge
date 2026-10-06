--!strict
-- Purpose: Provably-fair deterministic RNG for casino games.
-- Each player receives a server seed (kept secret). The server seed hash is
-- published so the player can verify the seed was not changed after the fact.
-- Outcomes for each round are derived from HMAC-like mixing of:
--   serverSeed : clientSeed : nonce
-- Dependencies: HttpService

local HttpService = game:GetService("HttpService")

local CasinoRng = {}

export type State = {
	ServerSeed: string,
	ServerSeedHash: string,
	ClientSeed: string,
	Nonce: number,
}

local function djb2Hash(input: string): number
	local hash = 5381
	for i = 1, #input do
		hash = bit32.bxor(hash * 33, string.byte(input, i))
	end
	return hash
end

-- Deterministically map an arbitrary string to a float in [0, 1).
local function hash01(input: string): number
	local h = djb2Hash(input)
	return (bit32.band(h, 0x7FFFFFFF) % 1_000_000_007) / 1_000_000_007
end

function CasinoRng.GenerateSeed(): string
	return HttpService:GenerateGUID(false)
end

function CasinoRng.HashSeed(seed: string): string
	return tostring(djb2Hash(seed))
end

function CasinoRng.New(serverSeed: string, clientSeed: string?, nonce: number?): State
	return {
		ServerSeed = serverSeed,
		ServerSeedHash = CasinoRng.HashSeed(serverSeed),
		ClientSeed = if clientSeed == nil then "" else clientSeed,
		Nonce = if nonce == nil then 0 else math.max(0, math.floor(nonce :: number)),
	}
end

function CasinoRng.Ensure(state: any): State
	if type(state) ~= "table" then
		return CasinoRng.New(CasinoRng.GenerateSeed())
	end
	local serverSeed = type(state.ServerSeed) == "string" and state.ServerSeed or CasinoRng.GenerateSeed()
	return {
		ServerSeed = serverSeed,
		ServerSeedHash = type(state.ServerSeedHash) == "string" and state.ServerSeedHash or CasinoRng.HashSeed(serverSeed),
		ClientSeed = if type(state.ClientSeed) == "string" then state.ClientSeed else "",
		Nonce = math.max(0, math.floor(tonumber(state.Nonce) or 0)),
	}
end

function CasinoRng.SetClientSeed(state: State, clientSeed: string): State
	state.ClientSeed = clientSeed
	return state
end

function CasinoRng.NextNumber(state: State): number
	state.Nonce += 1
	local input = state.ServerSeed .. ":" .. state.ClientSeed .. ":" .. tostring(state.Nonce)
	return hash01(input)
end

return table.freeze(CasinoRng)
