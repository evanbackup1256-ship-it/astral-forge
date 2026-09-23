--!strict
-- Pure-module extract guards: TradeSettle (lock / fail / cancel residual / revert retries
-- / host→guest AtomicUpdate orchestration).
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
-- RevertWithRetries + commit helpers
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

	assert(TradeSettle.IsCommitOk(true, { ok = true }) == true, "commit ok")
	assert(TradeSettle.IsCommitOk(true, { ok = false }) == false, "commit rejected")
	assert(TradeSettle.IsCommitOk(false, { ok = true }) == false, "AtomicUpdate fail")
	assert(TradeSettle.IsCommitOk(true, nil) == false, "nil result")
	assert(TradeSettle.CommitError({ error = "Inventory full." }) == "Inventory full.", "commit error")
	assert(TradeSettle.CommitError({ ok = false }) == nil, "missing error")
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
-- RunHostGuest orchestration (injectable AtomicUpdate path)
------------------------------------------------------------------------
do
	-- Happy path: host apply → guest present → guest apply → complete
	local session = freshSession()
	assert(TradeSettle.TryBegin(session))
	local calls = { host = 0, guest = 0, present = 0, revert = 0 }
	local outcome = TradeSettle.RunHostGuest(session, {
		applyHost = function()
			calls.host += 1
			return true, { ok = true }
		end,
		guestPresent = function()
			calls.present += 1
			return true
		end,
		applyGuest = function()
			calls.guest += 1
			return true, { ok = true }
		end,
		revertHostOnce = function()
			calls.revert += 1
			return true
		end,
	})
	assert(outcome.ok == true and outcome.kind == TradeSettle.KIND_COMPLETE, "happy path completes")
	assert(calls.host == 1 and calls.guest == 1 and calls.present == 1 and calls.revert == 0, "no revert on success")
	assert(session.Status == "Settling", "success leaves Settling for Close")

	-- Host apply fails → reopen desk, no revert
	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	calls = { host = 0, guest = 0, present = 0, revert = 0 }
	outcome = TradeSettle.RunHostGuest(session, {
		applyHost = function()
			calls.host += 1
			return true, { ok = false, error = "Host inventory full." }
		end,
		guestPresent = function()
			calls.present += 1
			return true
		end,
		applyGuest = function()
			calls.guest += 1
			return true, { ok = true }
		end,
		revertHostOnce = function()
			calls.revert += 1
			return true
		end,
	})
	assert(outcome.ok == false and outcome.kind == TradeSettle.KIND_HOST_FAILED, "host-failed kind")
	assert(outcome.message == "Host inventory full.", "host error surfaces")
	assert(calls.guest == 0 and calls.revert == 0 and calls.present == 0, "host fail short-circuits")
	assert(session.Status == "Open" and session.Settling == false, "host fail reopens")

	-- Guest left after host commit → revert retries, permanent if exhausted
	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	calls = { host = 0, guest = 0, present = 0, revert = 0 }
	outcome = TradeSettle.RunHostGuest(session, {
		applyHost = function()
			calls.host += 1
			return true, { ok = true }
		end,
		guestPresent = function()
			calls.present += 1
			return false
		end,
		applyGuest = function()
			calls.guest += 1
			return true, { ok = true }
		end,
		revertHostOnce = function()
			calls.revert += 1
			return calls.revert >= 2
		end,
	})
	assert(outcome.ok == false and outcome.kind == TradeSettle.KIND_GUEST_LEFT, "guest-left kind")
	assert(outcome.permanent == false, "guest-left reverted is not permanent")
	assert(outcome.reason == TradeSettle.REASON_GUEST_LEFT, "guest-left reason")
	assert(calls.revert == 2 and calls.guest == 0, "retries until revert succeeds")
	assert(session.Status == "Open", "successful revert reopens")

	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	calls = { revert = 0 }
	outcome = TradeSettle.RunHostGuest(session, {
		applyHost = function()
			return true, { ok = true }
		end,
		guestPresent = function()
			return false
		end,
		applyGuest = function()
			return true, { ok = true }
		end,
		revertHostOnce = function()
			calls.revert += 1
			return false
		end,
	})
	assert(outcome.permanent == true and outcome.log ~= nil, "exhausted revert → RevertFailed + log")
	assert(session.Status == "RevertFailed", "permanent guest-left stamps RevertFailed")
	assert(calls.revert == TradeSettle.REVERT_ATTEMPTS, "exhausts revert budget")
	assert(string.find(outcome.log, "admin note:", 1, true), "log cites admin note")

	-- Guest apply fails → revert; surface apply error when reverted
	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	outcome = TradeSettle.RunHostGuest(session, {
		applyHost = function()
			return true, { ok = true }
		end,
		guestPresent = function()
			return true
		end,
		applyGuest = function()
			return true, { ok = false, error = "Guest inventory full." }
		end,
		revertHostOnce = function()
			return true
		end,
	})
	assert(outcome.ok == false and outcome.kind == TradeSettle.KIND_GUEST_FAILED, "guest-failed kind")
	assert(outcome.message == "Guest inventory full.", "guest apply error surfaces after revert")
	assert(outcome.permanent == false and outcome.reason == TradeSettle.REASON_GUEST_APPLY)
	assert(session.Status == "Open", "guest-fail + revert reopens")

	session = freshSession()
	assert(TradeSettle.TryBegin(session))
	outcome = TradeSettle.RunHostGuest(session, {
		applyHost = function()
			return true, { ok = true }
		end,
		guestPresent = function()
			return true
		end,
		applyGuest = function()
			return false, nil
		end,
		revertHostOnce = function()
			return false
		end,
	})
	assert(outcome.permanent == true and outcome.log ~= nil, "guest-fail + revert fail → permanent")
	assert(session.Status == "RevertFailed" and session.RevertFailedReason == TradeSettle.REASON_GUEST_APPLY)
	assert(string.find(outcome.message, "host revert did not commit", 1, true), "permanent guest-fail copy")
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
	assert(string.find(services, "TradeSettle.RunHostGuest", 1, true), "ConfirmTrade must orchestrate via RunHostGuest")
	assert(string.find(services, "guestPresent", 1, true), "ConfirmTrade must inject guestPresent")
	assert(string.find(services, "revertHostOnce", 1, true), "ConfirmTrade must inject revertHostOnce")
	assert(string.find(services, "trade-host", 1, true), "host AtomicUpdate label")
	assert(string.find(services, "trade-guest", 1, true), "guest AtomicUpdate label")
	assert(string.find(services, "trade-revert", 1, true), "revert AtomicUpdate label")
	assert(string.find(services, "IsCommitOk", 1, true), "revert uses IsCommitOk")
	local revertCount = 0
	for _ in string.gmatch(services, '"trade%-revert"') do
		revertCount += 1
	end
	assert(revertCount >= 1, "host revert AtomicUpdate must remain in ConfirmTrade hooks")

	local settleSrc = fs.readFile("src/Server/AstralForge/Modules/TradeSettle.luau")
	assert(string.find(settleSrc, "function TradeSettle.RunHostGuest", 1, true), "RunHostGuest exported")
	assert(string.find(settleSrc, "REASON_GUEST_LEFT", 1, true), "guest-left reason constant")
	assert(string.find(settleSrc, "REASON_GUEST_APPLY", 1, true), "guest-apply reason constant")
	assert(string.find(settleSrc, "RevertWithRetries", 1, true), "orchestrator owns retries")

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

print("[INFO] [TEST] trade settle lock/revert/orchestrate helpers passed")
