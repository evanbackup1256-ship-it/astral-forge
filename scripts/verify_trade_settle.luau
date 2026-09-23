--!strict
-- Pure-module extract guards: TradeSettle (lock / fail / cancel residual / revert retries).
-- HARD: DV<=21, PlatformBadges=0, no vendor/Packages.

local fs = require("@lune/fs")

local TradeSettle = require("../src/Server/AstralForge/Modules/TradeSettle")

local function freshSession()
	return {
		Id = "sess-1",
		Host = 10,
		Guest = 20,
		Confirmed = { [10] = true, [20] = true },
		Settling = false,
		Status = "Confirming",
		ConfirmEndsAt = 0,
	}
end

------------------------------------------------------------------------
-- TryBegin single-flight
------------------------------------------------------------------------
do
	local session = freshSession()
	assert(TradeSettle.TryBegin(session) == true, "first settle claim wins")
	assert(session.Settling == true and session.Status == "Settling", "status settles")
	assert(TradeSettle.TryBegin(session) == false, "second settle claim must lose")
	session.Confirmed[20] = false
	session.Settling = false
	session.Status = "Confirming"
	assert(TradeSettle.TryBegin(session) == false, "unconfirmed guest blocks settle")
end

------------------------------------------------------------------------
-- FailSettle permanent vs open + cancel residual
------------------------------------------------------------------------
do
	local session = freshSession()
	assert(TradeSettle.TryBegin(session))
	TradeSettle.Fail(session, true, TradeSettle.REASON_GUEST_APPLY)
	assert(session.Status == "RevertFailed", "permanent fail stamps RevertFailed")
	assert(session.RevertFailedReason == TradeSettle.REASON_GUEST_APPLY, "reason stamped")
	assert(session.Settling == false, "Settling cleared")
	local blocked, err = TradeSettle.CancelBlocked(session)
	assert(blocked == false, "RevertFailed desks stay cancellable")

	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	TradeSettle.Fail(session, false)
	assert(session.Status == "Open", "non-permanent fail reopens desk")
	assert(session.RevertFailedReason == nil)

	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	blocked, err = TradeSettle.CancelBlocked(session)
	assert(blocked == true and err == "That trade is already settling.", "cancel during Settling refuses")
end

------------------------------------------------------------------------
-- RevertWithRetries
------------------------------------------------------------------------
do
	local tries = 0
	local ok = TradeSettle.RevertWithRetries(3, function()
		tries += 1
		return tries >= 2
	end)
	assert(ok == true and tries == 2, "retries until success")

	tries = 0
	ok = TradeSettle.RevertWithRetries(3, function()
		tries += 1
		return false
	end)
	assert(ok == false and tries == 3, "exhausts attempts")
	assert(TradeSettle.REVERT_ATTEMPTS == 3, "default attempt budget is 3")
end

------------------------------------------------------------------------
-- Outcome messages + RevertFailed log format
------------------------------------------------------------------------
do
	assert(
		TradeSettle.GuestLeftMessage(true) == "Guest left during settle — host side was reverted.",
		"guest-left reverted message"
	)
	assert(string.find(TradeSettle.GuestLeftMessage(false), "host revert failed", 1, true), "guest-left permanent message")
	assert(
		TradeSettle.GuestApplyMessage(false, "x") == "Guest side failed and host revert did not commit. Cancel the table and contact support.",
		"guest-apply permanent prefers fixed copy"
	)
	assert(TradeSettle.GuestApplyMessage(true, "Inventory full.") == "Inventory full.", "guest-apply reverted surfaces apply error")
	assert(TradeSettle.GuestApplyMessage(true, nil) == "Guest side of the trade failed.", "guest-apply reverted default")

	local log = TradeSettle.FormatRevertFailedLog("abc", 1, 2, TradeSettle.REASON_GUEST_LEFT)
	assert(string.find(log, "RevertFailed session=abc", 1, true), "log stamps session")
	assert(string.find(log, "admin note: " .. TradeSettle.ADMIN_NOTE, 1, true), "log cites admin note")
end

------------------------------------------------------------------------
-- Source wiring + HARD constraints
------------------------------------------------------------------------
do
	local desk = fs.readFile("src/Server/AstralForge/Modules/TradeDesk.luau")
	assert(string.find(desk, "TradeSettle.TryBegin", 1, true), "TradeDesk must delegate TryBegin")
	assert(string.find(desk, "TradeSettle.Fail", 1, true), "TradeDesk must delegate Fail")
	assert(string.find(desk, "TradeSettle.CancelBlocked", 1, true), "TradeDesk Cancel must use CancelBlocked")

	local services = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
	assert(string.find(services, "TradeSettle.RevertWithRetries", 1, true), "ConfirmTrade must use RevertWithRetries")
	assert(string.find(services, "TradeSettle.FormatRevertFailedLog", 1, true), "ConfirmTrade must format via TradeSettle")
	assert(string.find(services, "TradeSettle.REASON_GUEST_LEFT", 1, true), "guest-left reason constant")
	assert(string.find(services, "TradeSettle.REASON_GUEST_APPLY", 1, true), "guest-apply reason constant")

	local cfg = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
	assert(string.find(cfg, "DataVersion = 21", 1, true), "DataVersion must remain 21")
	local badges = string.match(cfg, "PlatformBadges = %{(.-)\n\t%},")
	assert(badges, "PlatformBadges missing")
	for id, value in string.gmatch(badges, "(%w+)%s*=%s*(%d+)") do
		assert(tonumber(value) == 0, "PlatformBadges." .. id .. " must be 0")
	end
	for _, path in {
		"src/Server/AstralForge/Modules/TradeSettle.luau",
		"src/Server/AstralForge/Modules/TradeDesk.luau",
	} do
		local body = fs.readFile(path)
		assert(not string.find(body, "vendor/", 1, true), path .. " must not reference vendor/")
		assert(not string.find(body, "Packages/", 1, true), path .. " must not reference Packages/")
	end
end

print("[INFO] [TEST] trade settle lock/revert helpers passed")
