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
assert(rGen == 2, "first beat must rotate past the hello nonce")
assert(rNonce ~= nonce, "rotated nonce must differ from hello")
assert(gate:CheckGrant(player, rGen, rNonce, true) == true, "grant should pass after auth")
-- Grace still honors the hello gen with the live nonce for in-flight grants.
assert(gate:CheckGrant(player, 1, rNonce, true) == true, "grace grant should pass with prev gen")

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

-- TxnClaim/Store must work even when Hello was never beaten (Studio CheckGrant path):
-- Claim without a prior Hello used to return "new" then Store no-op'd on a missing session.
do
	local lonely = { Name = "Lonely", UserId = 42 }
	local claimStatus = gate:TxnClaim(lonely, "studio-txn")
	assert(claimStatus == "new", "claim without hello should still allocate")
	assert(gate:TxnClaim(lonely, "studio-txn") == "busy", "pending claim must stick without Hello")
	gate:TxnStore(lonely, "studio-txn", { ok = true, echo = 7 })
	local doneStatus, stored = gate:TxnClaim(lonely, "studio-txn")
	assert(doneStatus == "done" and stored and stored.echo == 7, "store must persist without prior Hello")
end

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

local claimStatus, claimStored = gate:TxnClaim(player, "txn-1")
assert(claimStatus == "new", "first claim should be fresh")
assert(gate:TxnClaim(player, "txn-1") == "busy", "pending claim should be busy")
gate:TxnRelease(player, "txn-1")
claimStatus = gate:TxnClaim(player, "txn-1")
assert(claimStatus == "new", "released txn should be reclaimable")
gate:TxnStore(player, "txn-1", { ok = true, echo = 1 })
claimStatus, claimStored = gate:TxnClaim(player, "txn-1")
assert(claimStatus == "done" and claimStored and claimStored.echo == 1, "stored txn should short-circuit")


-- After rotation, CheckGrant must honor the same GRACE_SEC prev gen/nonce window as Beat.
do
	local g2, n2 = gate:Peek(player)
	local prevGen, prevNonce = g2, n2
	-- Force rotate by beating until gen bumps.
	for id = 30, 50 do
		local bOk, _, bGen, bNonce = gate:Beat(player, prevGen, id, prevNonce)
		if bGen ~= prevGen then
			-- Still inside grace: old creds must grant.
			local grantOk, grantReason = gate:CheckGrant(player, prevGen, prevNonce, true)
			assert(grantOk == true, "grace grant should pass with previous creds: " .. tostring(grantReason))
			assert(gate:CheckGrant(player, bGen, bNonce, true) == true, "live grant should pass after rotate")
			break
		end
		prevGen, prevNonce = bGen, bNonce
		if not bOk then
			error("beat failed while forcing rotate")
		end
	end
end

-- Studio CheckGrant must allocate a session bag via _get so Peek/txn helpers stay coherent
-- when grants run without Hello (Studio short-circuits auth).
do
	local studioGame = {
		GetService = function(_, name)
			if name == "HttpService" then
				return {
					GenerateGUID = function()
						guidCounter += 1
						return "studio-nonce-" .. tostring(guidCounter)
					end,
				}
			elseif name == "RunService" then
				return {
					IsStudio = function()
						return true
					end,
					IsServer = function()
						return true
					end,
				}
			end
			error("unexpected service " .. tostring(name))
		end,
	}
	local studioFactory = luau.load(src, { environment = setmetatable({ game = studioGame }, { __index = getfenv(0) }) })()
	local studioGate = studioFactory().new()
	local studioPlayer = { Name = "StudioDev", UserId = 99 }
	assert(studioGate:CheckGrant(studioPlayer, nil, nil, true) == true, "Studio CheckGrant must pass")
	local sGen, sNonce = studioGate:Peek(studioPlayer)
	assert(type(sGen) == "number" and type(sNonce) == "string", "Studio CheckGrant must allocate session for Peek")
	local claimStatus = studioGate:TxnClaim(studioPlayer, "studio-no-hello")
	assert(claimStatus == "new", "Studio txn claim after CheckGrant must work")
	studioGate:TxnRelease(studioPlayer, "studio-no-hello")
	claimStatus = studioGate:TxnClaim(studioPlayer, "studio-no-hello")
	assert(claimStatus == "new", "Studio TxnRelease via _get must clear pending")
end

print("[INFO] [TEST] session gate production path passed")
