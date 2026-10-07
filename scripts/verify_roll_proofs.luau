--!strict
-- Purpose: Independently cross-check roll hashes, HMAC streams, seed commitments and bounded sampling.
-- Owner: Astral Forge verification. Dependencies: ProofHash/FairRandom, Lune fs/serde. Last-reviewed: 2026-10-05.
local Hash = require("../src/Shared/AstralForge/Shared/ProofHash")
local Fair = require("../src/Shared/AstralForge/Shared/FairRandom")(Hash)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
type Vector = { MessageHex: string, KeyHex: string, Sha256: string, Hmac256: string }
type Fixtures = { Vectors: { Vector } }

local function decode(value: string): string
	return (value:gsub("..", function(pair: string): string
		return string.char(assert(tonumber(pair, 16)))
	end))
end

local fixtures: Fixtures = serde.decode("json", fs.readFile("audit/fixtures/proof-hash-vectors.json"))
for index, vector in fixtures.Vectors do
	local message, key = decode(vector.MessageHex), decode(vector.KeyHex)
	assert(Hash.hex(message) == vector.Sha256, "SHA-256 vector " .. tostring(index))
	assert(Hash.hmacHex(key, message) == vector.Hmac256, "HMAC-SHA256 vector " .. tostring(index))
	assert(#Hash.bytes(message) == 32 and #Hash.hmacBytes(key, message) == 32)
end
assert(Hash.hex(string.rep("a", 1000000)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")

local secret = string.rep("server-secret-", 4)
local first = Fair.create(secret, "client:seed🌌", 42, "Forge.Roll")
local repeatStream = Fair.create(secret, "client:seed🌌", 42, "Forge.Roll")
local changed = Fair.create(secret, "client:seed🌌", 43, "Forge.Roll")
local otherGame = Fair.create(secret, "client:seed🌌", 42, "Arcade.Dice")
local firstWord = first.uint32()
assert(firstWord == repeatStream.uint32())
assert(firstWord ~= changed.uint32() and firstWord ~= otherGame.uint32())
for _ = 1, 1000 do
	assert(first.uint32() == repeatStream.uint32(), "digest refills must reproduce exactly")
end
local integers = Fair.create(secret, "seed", 1, "Forge.Roll")
local counts: { number } = table.create(37, 0)
for _ = 1, 7400 do
	local number = integers.integer(0, 36)
	assert(number >= 0 and number <= 36 and number % 1 == 0)
	counts[number + 1] += 1
end
for _, count in counts do
	assert(count > 140 and count < 270, "fixed-vector distribution smoke test")
end
-- The distribution smoke test is not a proof of uniformity: rejection sampling supplies the construction.
for _, bounds in { { 0, 0 }, { -10, 10 }, { 0, 4294967295 }, { -2147483648, 2147483647 } } do
	for _ = 1, 10 do
		local value = integers.integer(bounds[1], bounds[2])
		assert(value >= bounds[1] and value <= bounds[2])
	end
end
for _ = 1, 100 do
	local value = integers.unit()
	assert(value >= 0 and value < 1)
end
local commitment = Fair.proof(secret, "seed", 1, "Forge.Roll")
assert(commitment.Commitment == Hash.hex(secret))
assert(
	Fair.verifyCommitment({
		Algorithm = commitment.Algorithm,
		Commitment = commitment.Commitment,
		ClientSeed = "seed",
		Nonce = 1,
		Domain = "Forge.Roll",
		ServerSeed = secret,
	})
)
assert(
	not Fair.verifyCommitment({
		Algorithm = commitment.Algorithm,
		Commitment = commitment.Commitment,
		ClientSeed = "seed",
		Nonce = 1,
		Domain = "Forge.Roll",
		ServerSeed = string.rep("wrong", 8),
	})
)
assert(not pcall(function(): ()
	integers.integer(2, 1)
end))
assert(not pcall(function(): ()
	integers.integer(0.5, 3)
end))
assert(not pcall(function(): ()
	Fair.create(secret, "seed", 0 / 0, "Forge.Roll")
end))
assert(not pcall(function(): ()
	Fair.create(secret, "seed", math.huge, "Forge.Roll")
end))
assert(not pcall(function(): ()
	Fair.create(secret, "", 1, "Forge.Roll")
end))
assert(not pcall(function(): ()
	Fair.create("short", "seed", 1, "Forge.Roll")
end))
assert(not pcall(function(): ()
	Fair.create(secret, "seed", 1, "bad:domain")
end))
print(
	"[TEST] independent SHA/HMAC vectors, million-byte digest, seed separation, commitments and rejection-sampled ranges passed"
)
