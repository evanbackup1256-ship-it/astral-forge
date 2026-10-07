--!strict
-- Purpose: Portable SHA-256 and HMAC-SHA-256 for reproducible roll commitments and transcripts.
-- Owner: Astral Forge integrity. Dependencies: Luau bit32/string/table. Last-reviewed: 2026-10-05.
-- Algorithm constants and word operations follow FIPS 180-4; HMAC follows RFC 2104/4231.
export type Words = { number }
export type Bytes = { string }
export type HashAPI = {
	bytes: (message: string) -> string,
	hex: (message: string) -> string,
	hmacBytes: (key: string, message: string) -> string,
	hmacHex: (key: string, message: string) -> string,
}

local WORD_MODULUS = 4294967296 -- SHA-256 arithmetic uses unsigned 32-bit words.
local BLOCK_BYTES = 64 -- SHA-256/HMAC block size, fixed by the standard.
local LENGTH_BYTES = 8 -- SHA-256's final message bit length occupies 64 bits.
local INNER_PAD = 54 -- HMAC inner-pad byte, fixed by RFC 2104.
local OUTER_PAD = 92 -- HMAC outer-pad byte, fixed by RFC 2104.
local INITIAL: Words = {
	1779033703,
	3144134277,
	1013904242,
	2773480762,
	1359893119,
	2600822924,
	528734635,
	1541459225,
}
-- Fractional cube roots of the first 64 primes, represented as decimal unsigned words.
local ROUND: Words = {
	1116352408,
	1899447441,
	3049323471,
	3921009573,
	961987163,
	1508970993,
	2453635748,
	2870763221,
	3624381080,
	310598401,
	607225278,
	1426881987,
	1925078388,
	2162078206,
	2614888103,
	3248222580,
	3835390401,
	4022224774,
	264347078,
	604807628,
	770255983,
	1249150122,
	1555081692,
	1996064986,
	2554220882,
	2821834349,
	2952996808,
	3210313671,
	3336571891,
	3584528711,
	113926993,
	338241895,
	666307205,
	773529912,
	1294757372,
	1396182291,
	1695183700,
	1986661051,
	2177026350,
	2456956037,
	2730485921,
	2820302411,
	3259730800,
	3345764771,
	3516065817,
	3600352804,
	4094571909,
	275423344,
	430227734,
	506948616,
	659060556,
	883997877,
	958139571,
	1322822218,
	1537002063,
	1747873779,
	1955562222,
	2024104815,
	2227730452,
	2361852424,
	2428436474,
	2756734187,
	3204031479,
	3329325298,
}
table.freeze(INITIAL)
table.freeze(ROUND)

local function wordBytes(value: number): string
	return string.char(
		bit32.band(bit32.rshift(value, 24), 255),
		bit32.band(bit32.rshift(value, 16), 255),
		bit32.band(bit32.rshift(value, 8), 255),
		bit32.band(value, 255)
	)
end

local function wordAt(message: string, index: number): number
	local a, b, c, d = string.byte(message, index, index + 3)
	return a * 16777216 + b * 65536 + c * 256 + d
end

local function add(a: number, b: number, c: number?, d: number?, e: number?): number
	return (a + b + (c or 0) + (d or 0) + (e or 0)) % WORD_MODULUS
end

local function bytes(message: string): string
	local bitLength = #message * 8
	assert(bitLength < 9007199254740992, "SHA-256 input exceeds exact length representation")
	local padding = (BLOCK_BYTES - LENGTH_BYTES - 1 - #message % BLOCK_BYTES) % BLOCK_BYTES
	local padded = message
		.. string.char(128)
		.. string.rep(string.char(0), padding)
		.. wordBytes(math.floor(bitLength / WORD_MODULUS))
		.. wordBytes(bitLength % WORD_MODULUS)
	local hash: Words = table.clone(INITIAL)
	local schedule: Words = table.create(64, 0)
	for start = 1, #padded, BLOCK_BYTES do
		for index = 1, 16 do
			schedule[index] = wordAt(padded, start + (index - 1) * 4)
		end
		for index = 17, 64 do
			local previous, recent = schedule[index - 15], schedule[index - 2]
			local lower = bit32.bxor(bit32.rrotate(previous, 7), bit32.rrotate(previous, 18), bit32.rshift(previous, 3))
			local upper = bit32.bxor(bit32.rrotate(recent, 17), bit32.rrotate(recent, 19), bit32.rshift(recent, 10))
			schedule[index] = add(schedule[index - 16], lower, schedule[index - 7], upper)
		end
		local a, b, c, d = hash[1], hash[2], hash[3], hash[4]
		local e, f, g, h = hash[5], hash[6], hash[7], hash[8]
		for index = 1, 64 do
			local upper = bit32.bxor(bit32.rrotate(e, 6), bit32.rrotate(e, 11), bit32.rrotate(e, 25))
			local choice = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
			local first = add(h, upper, choice, ROUND[index], schedule[index])
			local lower = bit32.bxor(bit32.rrotate(a, 2), bit32.rrotate(a, 13), bit32.rrotate(a, 22))
			local majority = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
			local second = add(lower, majority)
			h, g, f, e, d, c, b, a = g, f, e, add(d, first), c, b, a, add(first, second)
		end
		hash[1], hash[2], hash[3], hash[4] = add(hash[1], a), add(hash[2], b), add(hash[3], c), add(hash[4], d)
		hash[5], hash[6], hash[7], hash[8] = add(hash[5], e), add(hash[6], f), add(hash[7], g), add(hash[8], h)
	end
	local result: Bytes = {}
	for _, word in hash do
		table.insert(result, wordBytes(word))
	end
	return table.concat(result)
end

local function toHex(value: string): string
	local output: Bytes = {}
	for index = 1, #value do
		output[index] = string.format("%02x", string.byte(value, index))
	end
	return table.concat(output)
end

local function hex(message: string): string
	return toHex(bytes(message))
end

local function hmacBytes(key: string, message: string): string
	local normalized = if #key > BLOCK_BYTES then bytes(key) else key
	normalized ..= string.rep(string.char(0), BLOCK_BYTES - #normalized)
	local inner: Bytes = {}
	local outer: Bytes = {}
	for index = 1, BLOCK_BYTES do
		local byte = string.byte(normalized, index)
		inner[index] = string.char(bit32.bxor(byte, INNER_PAD))
		outer[index] = string.char(bit32.bxor(byte, OUTER_PAD))
	end
	return bytes(table.concat(outer) .. bytes(table.concat(inner) .. message))
end

local function hmacHex(key: string, message: string): string
	return toHex(hmacBytes(key, message))
end

local api: HashAPI = { bytes = bytes, hex = hex, hmacBytes = hmacBytes, hmacHex = hmacHex }
return table.freeze(api)
