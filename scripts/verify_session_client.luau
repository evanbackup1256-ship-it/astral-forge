--!strict
-- Client session parity + beat resync invariants (no Studio).
-- Asserts GRANT_ACTIONS covers every mutating Protocol action the server gates,
-- and models adopt()/attachGrantFields recovery from gate rejections the same way
-- SessionGate:Beat/Peek return live creds (pure; does not require Roblox script).

local fs = require("@lune/fs")

local protocolSrc = fs.readFile("src/Shared/AstralForge/Shared/Protocol.luau")
local sessionSrc = fs.readFile("src/Client/AstralForge/session.luau")
local serverSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local commandValidators = require("../src/Server/AstralForge/Modules/CommandActionValidators")

local function extractStringKeys(block: string): { [string]: boolean }
	local keys = {}
	for key in string.gmatch(block, '%["([%w]+)"%]%s*=%s*true') do
		keys[key] = true
	end
	for key in string.gmatch(block, "%[Protocol%.Actions%.([%w]+)%]%s*=%s*true") do
		keys[key] = true
	end
	for key in string.gmatch(block, "([%w]+)%s*=%s*true") do
		keys[key] = true
	end
	return keys
end

local function extractProtocolActions(src: string): { [string]: boolean }
	local actionsBlock = string.match(src, "Actions%s*=%s*%{(.-)\n\t%},")
	assert(actionsBlock, "Protocol.Actions block missing")
	local actions = {}
	for name, value in string.gmatch(actionsBlock, "([%w]+)%s*=%s*\"([%w]+)\"") do
		assert(name == value, "Protocol action key/value mismatch: " .. name)
		actions[value] = true
	end
	return actions
end

local protocolActions = extractProtocolActions(protocolSrc)
local grantBlock = string.match(sessionSrc, "local GRANT_ACTIONS%s*=%s*%{(.-)\n%}")
assert(grantBlock, "client GRANT_ACTIONS missing")
local grantActions = extractStringKeys(grantBlock)

assert(
	string.find(serverSrc, "CommandActionValidators.RequiresHighValueNonce", 1, true),
	"ServerServices must use CommandActionValidators for high-value grants"
)
local highValue = {}
for action in pairs(commandValidators.HIGH_VALUE_GRANT) do
	highValue[action] = true
end

-- Mirror the server readOnly set from CommandActionValidators (shared with GameService).
local readOnly = {}
for action in pairs(commandValidators.READ_ONLY) do
	readOnly[action] = true
end
assert(string.find(serverSrc, "CommandActionValidators.IsReadOnly", 1, true), "ServerServices must use IsReadOnly")

-- Confirm the server source still lists each readOnly action we mirror.
for action in pairs(readOnly) do
	assert(
		string.find(serverSrc, "Protocol%.Actions%." .. action, 1, false) ~= nil
			or string.find(serverSrc, 'Actions%.' .. action, 1, false) ~= nil
			or string.find(serverSrc, action, 1, true) ~= nil,
		"readOnly mirror references missing action " .. action
	)
end

local grantCount = 0
for action in pairs(protocolActions) do
	if readOnly[action] then
		assert(grantActions[action] == nil, action .. " is readOnly on server but listed in client GRANT_ACTIONS")
	else
		assert(grantActions[action] == true, action .. " mutates on server but missing from client GRANT_ACTIONS")
		grantCount += 1
	end
end

for action in pairs(grantActions) do
	assert(protocolActions[action] == true, "GRANT_ACTIONS has unknown action " .. action)
end

local highValueCount = 0
for action in pairs(highValue) do
	assert(grantActions[action] == true, "HIGH_VALUE " .. action .. " must be in client GRANT_ACTIONS")
	highValueCount += 1
end

-- Pure replica of session.adopt / attachGrantFields credential rules (must stay
-- aligned with src/Client/AstralForge/session.luau — string-checked below).
assert(string.find(sessionSrc, "if response.Gen == nil or response.Gen < gen", 1, true), "adopt gen guard missing")
assert(string.find(sessionSrc, "payload.Gen = gen", 1, true), "attachGrantFields gen missing")
assert(string.find(sessionSrc, "payload.N = nonce", 1, true), "attachGrantFields nonce missing")
assert(string.find(sessionSrc, "Auth = if grantReason", 1, true) == nil, "Auth drop is server-side only")

local gen = 0
local nonce = ""
local auth = false
local function adopt(response)
	if response.Gen == nil or response.Gen < gen then
		return
	end
	if response.N == nil then
		return
	end
	gen = response.Gen
	nonce = response.N
	if response.Auth ~= nil then
		auth = response.Auth
	end
end
local function attachGrantFields(payload)
	payload.Gen = gen
	payload.N = nonce
	return payload
end

adopt({ Gen = 1, N = "hello-nonce", Auth = false })
assert(auth == false and gen == 1, "hello alone does not authenticate")

adopt({ Gen = 2, N = "live-nonce", Auth = true })
assert(auth == true and gen == 2, "auth adopt must flip isAuthed")
local granted = attachGrantFields({})
assert(granted.Gen == 2 and granted.N == "live-nonce", "attach must use live creds after adopt")

-- Gate rejection with live Peek creds: client must resync even when Auth drops.
adopt({ Gen = 3, N = "rotated-nonce", Auth = false })
assert(auth == false and gen == 3, "unauth rejection must clear auth and take live gen")
local resynced = attachGrantFields({})
assert(resynced.Gen == 3 and resynced.N == "rotated-nonce", "post-reject attach must use Peek creds")

-- Stale older gen must not clobber live creds (out-of-order grant response).
adopt({ Gen = 2, N = "stale-nonce", Auth = true })
local still = attachGrantFields({})
assert(still.Gen == 3 and still.N == "rotated-nonce", "older Gen adopt must be ignored")
assert(auth == false, "stale adopt must not resurrect auth")

-- Equal gen with fresh nonce still resyncs (rotation race inside grace).
adopt({ Gen = 3, N = "grace-nonce", Auth = true })
assert(auth == true, "same-gen nonce rotate must re-auth")
local grace = attachGrantFields({})
assert(grace.N == "grace-nonce", "same-gen adopt must take the new nonce")

print(
	"[INFO] [TEST] session client GRANT_ACTIONS parity + beat resync passed | grants="
		.. tostring(grantCount)
		.. " highValue="
		.. tostring(highValueCount)
)
