--!strict
-- Offline gates for Trade RevertFailed settle paths + SessionGate/DataService sanitize bags.
-- Mirrors verify_economy_regress style: string markers + lightweight pure logic. No Studio.
-- HARD: DataVersion <= 21, PlatformBadges 0, no vendor/Packages.

local fs = require("@lune/fs")

local deskSrc = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local gateSrc = fs.readFile("src/Server/AstralForge/Services/SessionGate.luau")
local dataSrc = fs.readFile("src/Server/AstralForge/Services/DataService.luau")
local configSrc = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

------------------------------------------------------------------------
-- RevertFailed path markers (FailSettle permanent + ModuleLog + cancel residual)
------------------------------------------------------------------------
assert(string.find(deskSrc, "function TradeDesk:FailSettle", 1, true), "FailSettle must exist")
assert(string.find(deskSrc, 'session.Status = "RevertFailed"', 1, true), "permanent FailSettle must stamp RevertFailed")
assert(string.find(deskSrc, "RevertFailedAt", 1, true), "permanent FailSettle must stamp RevertFailedAt")
assert(string.find(deskSrc, "RevertFailedReason", 1, true), "permanent FailSettle must stamp RevertFailedReason")
assert(string.find(deskSrc, "host-revert-failed", 1, true), "FailSettle must default reason host-revert-failed")
assert(string.find(deskSrc, "Trade settle recovery", 1, true), "FailSettle must cite Trade settle recovery ops note")

assert(string.find(services, "guest-left-during-settle", 1, true), "ConfirmTrade must FailSettle guest-left path")
assert(string.find(services, "guest-apply-failed", 1, true), "ConfirmTrade must FailSettle guest-apply path")
assert(string.find(services, "RevertFailed session=", 1, true), "permanent settle failure must ModuleLog RevertFailed")
assert(string.find(services, "admin note: Trade settle recovery", 1, true), "RevertFailed log must cite admin note")

-- Pure replica of Cancel vs RevertFailed residual (must stay aligned with TradeDesk:Cancel).
local function tryCancel(s: any): (boolean, string?)
	if s.Settling == true or s.Status == "Settling" then
		return false, "That trade is already settling."
	end
	return true, nil
end
do
	local settling = { Settling = true, Status = "Settling" }
	local ok, err = tryCancel(settling)
	assert(ok == false and err == "That trade is already settling.", "cancel during Settling must refuse")
	local residual = { Settling = false, Status = "RevertFailed", RevertFailedReason = "guest-apply-failed" }
	ok = tryCancel(residual)
	assert(ok == true, "cancel after RevertFailed must clear residual desk")
end

------------------------------------------------------------------------
-- SessionGate session bags (txns/txnOrder via _get) — Studio CheckGrant short-circuit
------------------------------------------------------------------------
assert(string.find(gateSrc, "function SessionGate:_get", 1, true), "SessionGate must own _get")
assert(string.find(gateSrc, "txns = {}", 1, true), "_get must allocate txns bag")
assert(string.find(gateSrc, "txnOrder = {}", 1, true), "_get must allocate txnOrder bag")
local getCount = 0
for _ in string.gmatch(gateSrc, "self:_get%(player%)") do
	getCount += 1
end
assert(getCount >= 4, "Hello/Beat/Txn helpers should share _get, got " .. tostring(getCount))
assert(string.find(gateSrc, "session bag via _get", 1, true), "TxnLookup must document Studio bag via _get")
assert(string.find(gateSrc, "TXN_RING", 1, true), "txn ring must bound sanitize/eviction")

------------------------------------------------------------------------
-- DataService sanitize bags (progression / economy bags that crash when partial)
------------------------------------------------------------------------
assert(string.find(dataSrc, "local function sanitize(profile)", 1, true), "DataService sanitize must exist")
for _, bag in {
	"profile.Machines",
	"profile.Research",
	"profile.ForgePath",
	"profile.Trade",
	"profile.Wheel",
	"profile.Lab",
} do
	assert(string.find(dataSrc, bag, 1, true) ~= nil, "sanitize must touch " .. bag)
end
assert(string.find(dataSrc, "ClaimedSteps", 1, true), "sanitize must harden ForgePath.ClaimedSteps")
assert(string.find(dataSrc, "profile.Trade.Sent", 1, true), "sanitize must harden Trade.Sent bag")
assert(string.find(dataSrc, "profile.Lab.Orders", 1, true), "sanitize must harden Lab.Orders bag")
assert(string.find(dataSrc, "profile.Wheel.PityMisses", 1, true), "sanitize must harden Wheel pity bag")

------------------------------------------------------------------------
-- HARD constraints
------------------------------------------------------------------------
local dv = string.match(configSrc, "DataVersion%s*=%s*(%d+)")
assert(dv ~= nil and tonumber(dv) <= 21, "DataVersion must be <= 21")
assert(tonumber(dv) == 21, "DataVersion must remain pinned at 21")
local badges = string.match(configSrc, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "([%w_]+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end
for _, body in { deskSrc, services, gateSrc, dataSrc } do
	assert(not string.find(body, "vendor/", 1, true), "must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), "must not reference Packages/")
end

print("[INFO] [TEST] settle/sanitize regress guards passed | RevertFailed+SessionGate+_get+DataService bags")
