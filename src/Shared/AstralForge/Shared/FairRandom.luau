--!strict
-- Purpose: Reproducible, domain-separated HMAC roll streams and seed-commitment verification.
-- Owner: Astral Forge integrity. Dependencies: ProofHash. Last-reviewed: 2026-10-05.
-- This verifies transcripts; it does not certify the caller's seed entropy or prevent a dishonest seed provider.
export type Proof = {
	Algorithm: string,
	Commitment: string,
	ClientSeed: string,
	Nonce: number,
	Domain: string,
}
export type Reveal = Proof & { ServerSeed: string }
export type Stream = {
	uint32: () -> number,
	unit: () -> number,
	integer: (minimum: number, maximum: number) -> number,
	drawCount: () -> number,
}
export type API = {
	Algorithm: string,
	commitment: (serverSeed: string) -> string,
	proof: (serverSeed: string, clientSeed: string, nonce: number, domain: string) -> Proof,
	verifyCommitment: (reveal: Reveal) -> boolean,
	create: (serverSeed: string, clientSeed: string, nonce: number, domain: string) -> Stream,
}
export type HashProvider = {
	hex: (message: string) -> string,
	hmacBytes: (key: string, message: string) -> string,
}

return function(Hash: HashProvider): API
	local ALGORITHM = "AF-HMAC-SHA256-v1"
	local WORD_MODULUS = 4294967296 -- Exact count of possible 32-bit digest words.
	local MAX_NONCE = 9007199254740991 -- Highest exactly represented integer in the numeric wire format.

	local function validate(serverSeed: string, clientSeed: string, nonce: number, domain: string): ()
		assert(#serverSeed >= 32 and #serverSeed <= 256, "server seed must contain 32–256 bytes")
		assert(#clientSeed >= 1 and #clientSeed <= 64, "client seed must contain 1–64 bytes")
		assert(nonce == nonce and nonce >= 0 and nonce <= MAX_NONCE and nonce % 1 == 0, "invalid roll nonce")
		assert(#domain >= 1 and #domain <= 48 and domain:match("^[%w._%-]+$") ~= nil, "invalid roll domain")
	end

	local function commitment(serverSeed: string): string
		assert(#serverSeed >= 32 and #serverSeed <= 256, "invalid server seed")
		return Hash.hex(serverSeed)
	end

	local function proof(serverSeed: string, clientSeed: string, nonce: number, domain: string): Proof
		validate(serverSeed, clientSeed, nonce, domain)
		return {
			Algorithm = ALGORITHM,
			Commitment = commitment(serverSeed),
			ClientSeed = clientSeed,
			Nonce = nonce,
			Domain = domain,
		}
	end

	local function verifyCommitment(reveal: Reveal): boolean
		if reveal.Algorithm ~= ALGORITHM or #reveal.ServerSeed < 32 or #reveal.ServerSeed > 256 then
			return false
		end
		return Hash.hex(reveal.ServerSeed) == reveal.Commitment
	end

	local function create(serverSeed: string, clientSeed: string, nonce: number, domain: string): Stream
		validate(serverSeed, clientSeed, nonce, domain)
		-- Length-prefixed byte strings prevent ambiguous client-seed/domain concatenations.
		local prefix = string.format("v1:%d:%s:%d:%s:%.0f:", #domain, domain, #clientSeed, clientSeed, nonce)
		local block = 0
		local cursor = 33 -- A digest contains 32 bytes; refill before the first draw.
		local digest = ""
		local draws = 0
		local function uint32(): number
			if cursor > #digest then
				digest = Hash.hmacBytes(serverSeed, prefix .. tostring(block))
				block += 1
				cursor = 1
			end
			local a, b, c, d = string.byte(digest, cursor, cursor + 3)
			cursor += 4
			draws += 1
			return a * 16777216 + b * 65536 + c * 256 + d
		end
		local function unit(): number
			return uint32() / WORD_MODULUS
		end
		local function integer(minimum: number, maximum: number): number
			assert(
				minimum == minimum and maximum == maximum and minimum % 1 == 0 and maximum % 1 == 0,
				"integer bounds required"
			)
			assert(minimum >= -2147483648 and maximum <= 4294967295 and maximum >= minimum, "invalid draw bounds")
			local span = maximum - minimum + 1
			assert(span <= WORD_MODULUS, "draw span exceeds digest word size")
			local limit = WORD_MODULUS - WORD_MODULUS % span
			local value = uint32()
			while value >= limit do
				value = uint32()
			end
			return minimum + value % span
		end
		local function drawCount(): number
			return draws
		end
		local stream: Stream = { uint32 = uint32, unit = unit, integer = integer, drawCount = drawCount }
		return table.freeze(stream)
	end

	local api: API = {
		Algorithm = ALGORITHM,
		commitment = commitment,
		proof = proof,
		verifyCommitment = verifyCommitment,
		create = create,
	}
	return table.freeze(api)
end
