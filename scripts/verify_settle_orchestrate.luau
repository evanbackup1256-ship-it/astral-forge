--!strict
-- Regress gate: ConfirmTrade host→guest settle orchestration stays delegated to
-- TradeSettle.RunHostGuest (injectable AtomicUpdate path). Complements
-- verify_trade_settle behavioral tests with source-wiring + HARD constraints.
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local settleSrc = fs.readFile("src/Server/AstralForge/Modules/TradeSettle.luau")
local desk = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
local cfg = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")

assert(string.find(services, "TradeSettle.RunHostGuest", 1, true), "ConfirmTrade must call RunHostGuest")
assert(string.find(services, '"trade-host"', 1, true), "trade-host AtomicUpdate")
assert(string.find(services, '"trade-guest"', 1, true), "trade-guest AtomicUpdate")
assert(string.find(services, '"trade-revert"', 1, true), "trade-revert AtomicUpdate")
assert(string.find(services, "guestPresent", 1, true), "guest presence hook")
assert(string.find(services, "revertHostOnce", 1, true), "host revert hook")
assert(string.find(services, "applyHost", 1, true), "host apply hook")
assert(string.find(services, "applyGuest", 1, true), "guest apply hook")
assert(string.find(services, "outcome.log", 1, true), "RevertFailed log surfaces via outcome")
assert(string.find(services, "TryBeginSettle", 1, true), "single-flight begin still via desk")
assert(string.find(services, "FailSettle", 1, true), "early abort still FailSettle")

-- Inline control flow must not re-own host→guest retry loops outside the extract.
local inlineRetry = 0
for _ in string.gmatch(services, "TradeSettle%.RevertWithRetries") do
	inlineRetry += 1
end
assert(inlineRetry == 0, "RevertWithRetries must live inside TradeSettle.RunHostGuest, not ServerServices")

assert(string.find(settleSrc, "function TradeSettle.RunHostGuest", 1, true), "RunHostGuest defined")
assert(string.find(settleSrc, "function TradeSettle.IsCommitOk", 1, true), "IsCommitOk defined")
assert(string.find(settleSrc, "KIND_HOST_FAILED", 1, true), "host-failed kind")
assert(string.find(settleSrc, "KIND_GUEST_LEFT", 1, true), "guest-left kind")
assert(string.find(settleSrc, "KIND_GUEST_FAILED", 1, true), "guest-failed kind")
assert(string.find(settleSrc, "KIND_COMPLETE", 1, true), "complete kind")
assert(string.find(desk, "TradeSettle.TryBegin", 1, true), "desk delegates TryBegin")
assert(string.find(desk, "TradeSettle.Fail", 1, true), "desk delegates Fail")

assert(string.find(cfg, "DataVersion = 21", 1, true), "DataVersion must remain 21")
local badges = string.match(cfg, "PlatformBadges = %{(.-)\n\t%},")
assert(badges, "PlatformBadges missing")
for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
	assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
end

for _, path in {
	"src/Server/AstralForge/Modules/TradeSettle.luau",
	"src/Server/AstralForge/Services/ServerServices.luau",
} do
	local body = fs.readFile(path)
	assert(not string.find(body, "vendor/", 1, true), path .. " must not reference vendor/")
	assert(not string.find(body, "Packages/", 1, true), path .. " must not reference Packages/")
end

-- Behavioral smoke via require (no Studio).
local TradeSettle = require("../src/Server/AstralForge/Modules/TradeSettle")
local session = {
	Id = "orch-1",
	Host = 1,
	Guest = 2,
	Confirmed = { [1] = true, [2] = true },
	Settling = false,
	Status = "Confirming",
	ConfirmEndsAt = 0,
}
assert(TradeSettle.TryBegin(session))
local out = TradeSettle.RunHostGuest(session, {
	applyHost = function()
		return true, { ok = true }
	end,
	guestPresent = function()
		return true
	end,
	applyGuest = function()
		return true, { ok = true }
	end,
	revertHostOnce = function()
		return true
	end,
})
assert(out.ok == true and out.kind == TradeSettle.KIND_COMPLETE, "orchestrate smoke complete")

print("[INFO] [TEST] settle orchestrate regress gate passed | RunHostGuest host→guest AtomicUpdate path")
