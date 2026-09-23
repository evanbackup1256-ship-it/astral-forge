local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- SessionGate is a factory module whose production branches sit behind
-- RunService:IsStudio(). Mock `game` so those branches actually run here.
local guidCounter = 0
local fakeGame = {
	GetService = function(_, name)
		if name == "HttpService" then
			return {
				GenerateGUID = function()
					guidCounter += 1
					return "nonce-" .. tostring(guidCounter)
				end,
			}
		elseif name == "RunService" then
			return {
				IsStudio = function()
					return false
				end,
				IsServer = function()
					return true
				end,
			}
		end
		error("unexpected service " .. tostring(name))
	end,
}

local src = fs.readFile("src/Server/AstralForge/Services/SessionGate.luau")
local factory = luau.load(src, { environment = setmetatable({ game = fakeGame }, { __index = getfenv(0) }) })()
local gate = factory().new()

local player = { Name = "TestPlayer", UserId = 1 }

local gen, nonce = gate:Hello(player)
assert(gen == 1, "hello should issue gen 1")
assert(type(nonce) == "string", "hello should issue a nonce")

local ok, reason, rGen, rNonce = gate:Beat(player, gen, 1, nonce)
assert(ok == true, "first beat should authenticate: " .. tostring(reason))
assert(gate:CheckGrant(player, 1, rNonce, true) == true, "grant should pass after auth")

-- Rejected beats must still return live creds so the client can resync.
ok, reason, rGen, rNonce = gate:Beat(player, 99, 2, "bogus")
assert(ok == false and reason == "gen mismatch", "bad gen should reject")
assert(type(rGen) == "number" and type(rNonce) == "string", "rejection must return live creds")

ok = gate:Beat(player, rGen, 3, rNonce)
assert(ok == true, "resynced beat should authenticate")

ok, reason = gate:Beat(player, rGen, 3, rNonce)
assert(ok == false and reason == "replay", "replayed beat id should reject")

ok, reason, rGen = gate:Beat(player, "x", 4, "y")
assert(ok == false and reason == "malformed beat", "malformed beat should reject")
assert(type(rGen) == "number", "malformed rejection must return creds")

assert(gate:CheckGrant({ UserId = 999 }, 1, "x", false) == false, "no-session grant should reject")
assert(gate:CheckGrant(player, 999, "x", false) == false, "wrong-gen grant should reject")
assert(gate:CheckGrant(player, rGen, "wrong", true) == false, "wrong-nonce grant should reject")
assert(gate:CheckGrant(player, rGen, "wrong", false) == true, "non-nonce grant should pass")

local liveGen, liveNonce = gate:Peek(player)
for id = 10, 20 do
	local bOk, _, bGen, bNonce = gate:Beat(player, liveGen, id, liveNonce)
	liveGen, liveNonce = bGen, bNonce
	if not bOk then break end
end
assert(liveGen > 1, "rotation should bump gen")
assert(gate:CheckGrant(player, liveGen, liveNonce, true) == true, "grant should pass with rotated creds")

local pGen, pNonce = gate:Peek(player)
assert(pGen == liveGen and pNonce == liveNonce, "peek should return live creds")

print("[INFO] [TEST] session gate production path passed")
