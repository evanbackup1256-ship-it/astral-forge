--!strict
-- Offline gates for AtomicState pure semantics + Security / GameAntiCheat residual
-- markers wired through DataService / ServerServices. No Studio.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
assert(not string.find(configSrc, "vendor/", 1, true), "GameConfig must not reference vendor/")
assert(not string.find(configSrc, "Packages/", 1, true), "GameConfig must not reference Packages/")
local dv = tonumber(string.match(configSrc, "DataVersion%s*=%s*(%d+)"))
assert(dv ~= nil and dv == 21, "DataVersion must remain 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

local atomicSrc = fs.readFile("src/Server/AstralForge/Services/AtomicState.luau")
local securitySrc = fs.readFile("src/Server/AstralForge/Services/Security.luau")
local antiSrc = fs.readFile("src/Server/AstralForge/Services/GameAntiCheat.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local servicesSrc = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")

assert(not string.find(atomicSrc, "vendor/", 1, true), "AtomicState must not reference vendor/")
assert(not string.find(securitySrc, "Packages/", 1, true), "Security must not reference Packages/")
assert(not string.find(antiSrc, "vendor/", 1, true), "GameAntiCheat must not reference vendor/")

------------------------------------------------------------------------
-- AtomicState pure semantics (factory; no Roblox services)
------------------------------------------------------------------------
assert(string.find(atomicSrc, "function AtomicState.new", 1, true), "AtomicState.new missing")
assert(string.find(atomicSrc, "function AtomicState:Read", 1, true), "AtomicState:Read missing")
assert(string.find(atomicSrc, "function AtomicState:IsBusy", 1, true), "AtomicState:IsBusy missing")
assert(string.find(atomicSrc, "function AtomicState:Transact", 1, true), "AtomicState:Transact missing")
assert(string.find(atomicSrc, "function AtomicState:Replace", 1, true), "AtomicState:Replace missing")
assert(string.find(atomicSrc, "CONTENTION_TIMEOUT_SECONDS", 1, true), "AtomicState contention timeout missing")
assert(string.find(atomicSrc, "state transaction already in progress", 1, true), "AtomicState busy reject marker missing")

local AtomicState = require("../src/Server/AstralForge/Services/AtomicState")()
local atom = AtomicState.new({ Meta = { Revision = 2 }, Cash = 10 })
local value, revision = atom:Read()
assert(revision == 2 and value.Cash == 10, "AtomicState.Read must surface Meta.Revision")
assert(atom:IsBusy() == false, "AtomicState must start idle")

local ok, result, nextRev = atom:Transact(function(draft)
	draft.Cash = 25
	return { ok = true, Cash = draft.Cash }
end)
assert(ok == true and result.Cash == 25 and nextRev == 3, "AtomicState.Transact must commit and bump revision")
local afterCommit = atom:Read()
assert(afterCommit.Cash == 25, "committed draft must become current value")

local okReject, rejectResult, rejectRev = atom:Transact(function(draft)
	draft.Cash = 999
	return { ok = false, error = "refuse" }
end)
assert(okReject == true and type(rejectResult) == "table" and rejectResult.ok == false, "ok=false return must stay successful pcall")
assert(rejectRev == 3, "ok=false must not bump revision")
local afterReject = atom:Read()
assert(afterReject.Cash == 25, "ok=false must not commit draft mutations")

assert(atom:Replace({ Meta = { Revision = 9 }, Cash = 1 }, 9) == true, "Replace must succeed while idle")
local replaced, replacedRev = atom:Read()
assert(replaced.Cash == 1 and replacedRev == 9, "Replace must honor revision watermark")

------------------------------------------------------------------------
-- DataService / ServerServices AtomicState wiring residuals
------------------------------------------------------------------------
assert(string.find(dataSrc, 'loadService("AtomicState")', 1, true) or string.find(dataSrc, "AtomicState", 1, true), "DataService must load AtomicState")
assert(string.find(dataSrc, "AtomicState.new(profile)", 1, true), "DataService must construct atom from profile")
assert(string.find(dataSrc, "atom:Transact", 1, true), "DataService AtomicUpdate must Transact")
assert(string.find(dataSrc, "function DataService:IsBusy", 1, true), "DataService:IsBusy residual")
assert(string.find(dataSrc, "atom:IsBusy()", 1, true), "IsBusy must consult atom")
assert(string.find(servicesSrc, 'serviceFactories["AtomicState"]', 1, true), "ServerServices must register AtomicState factory")

------------------------------------------------------------------------
-- Security residual markers (Studio-heavy; offline string gates only)
------------------------------------------------------------------------
assert(string.find(securitySrc, "function Authority:Validate", 1, true), "Security Authority:Validate missing")
assert(string.find(securitySrc, "function Nonce:Issue", 1, true), "Security Nonce:Issue missing")
assert(string.find(securitySrc, "function Nonce:Consume", 1, true), "Security Nonce:Consume missing")
assert(string.find(securitySrc, "function Mask:Encode", 1, true), "Security Mask:Encode missing")
assert(string.find(securitySrc, "function Mask:Decode", 1, true), "Security Mask:Decode missing")
assert(string.find(securitySrc, "function Rollback:Push", 1, true), "Security Rollback:Push missing")
assert(string.find(securitySrc, "function Filter:Apply", 1, true), "Security Filter:Apply missing")
assert(string.find(securitySrc, "function Rate:Allow", 1, true), "Security Rate:Allow missing")
assert(string.find(securitySrc, "function Heuristic:Observe", 1, true), "Security Heuristic:Observe missing")
assert(string.find(securitySrc, "function Honey:Trip", 1, true), "Security Honey:Trip missing")
assert(string.find(securitySrc, "AF_SecurityReason", 1, true), "Security reason attribute residual")
assert(string.find(securitySrc, "function Security.new", 1, true), "Security.new missing")
assert(string.find(servicesSrc, 'serviceFactories["Security"]', 1, true), "ServerServices must register Security")
assert(string.find(servicesSrc, "self._security.Authority:Validate", 1, true), "production must Authority:Validate")
assert(string.find(servicesSrc, "self._security.Rate:Allow", 1, true), "production must Rate:Allow")
assert(string.find(servicesSrc, "self._security.Filter:Apply", 1, true), "chat/details must Filter:Apply")

------------------------------------------------------------------------
-- GameAntiCheat residual markers
------------------------------------------------------------------------
assert(string.find(antiSrc, "function AntiCheat:Observe", 1, true), "GameAntiCheat:Observe missing")
assert(string.find(antiSrc, "function AntiCheat:SyncBaseline", 1, true), "GameAntiCheat:SyncBaseline missing")
assert(string.find(antiSrc, "function AntiCheat:Forget", 1, true), "GameAntiCheat:Forget missing")
assert(string.find(antiSrc, "ROOT_CURRENCIES", 1, true), "GameAntiCheat ROOT_CURRENCIES residual")
assert(string.find(antiSrc, "clampSparseLevels", 1, true), "GameAntiCheat clampSparseLevels residual")
assert(string.find(antiSrc, "Cash jump exceeded production ceiling", 1, true), "GameAntiCheat velocity ceiling residual")
assert(string.find(servicesSrc, 'serviceFactories["GameAntiCheat"]', 1, true), "ServerServices must register GameAntiCheat")
assert(string.find(servicesSrc, "GameAntiCheat.new()", 1, true), "production must construct GameAntiCheat")
assert(string.find(servicesSrc, "self._antiCheat:Observe", 1, true), "production must Observe via anti-cheat")
assert(string.find(servicesSrc, "self._antiCheat:SyncBaseline", 1, true), "offline grant must SyncBaseline")
assert(string.find(servicesSrc, "self._antiCheat:Forget", 1, true), "player leave must Forget anti-cheat state")

print("[INFO] [TEST] AtomicState pure + Security/GameAntiCheat residual gates passed")
