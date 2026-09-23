--!strict
-- Pure settle lock / fail / cancel residual / revert-retry / host→guest orchestration
-- helpers for peer trades. No Roblox services — TradeDesk, ServerServices, and Lune
-- verify scripts share this so host→guest AtomicUpdate races and RevertFailed recovery
-- can be tested without Studio. Callers inject apply/revert/presence hooks; ApplyExchange
-- / RevertExchange / DataService.AtomicUpdate stay with the caller.

local TradeSettle = {}

TradeSettle.REVERT_ATTEMPTS = 3
TradeSettle.ADMIN_NOTE = "Trade settle recovery"
TradeSettle.REASON_GUEST_LEFT = "guest-left-during-settle"
TradeSettle.REASON_GUEST_APPLY = "guest-apply-failed"
TradeSettle.REASON_HOST_REVERT = "host-revert-failed"
TradeSettle.KIND_COMPLETE = "complete"
TradeSettle.KIND_HOST_FAILED = "host-failed"
TradeSettle.KIND_GUEST_LEFT = "guest-left"
TradeSettle.KIND_GUEST_FAILED = "guest-failed"

-- Single-flight settle gate: both Confirm handlers can race once Confirmed[host]
-- and Confirmed[guest] flip true; only one caller may own the host→guest apply pair.
function TradeSettle.TryBegin(session): boolean
	if not session then
		return false
	end
	if session.Settling == true or session.Status == "Settling" or session.Status == "RevertFailed" then
		return false
	end
	if session.Confirmed[session.Host] ~= true or session.Confirmed[session.Guest] ~= true then
		return false
	end
	session.Settling = true
	session.Status = "Settling"
	return true
end

function TradeSettle.Fail(session, permanent: boolean?, reason: string?)
	if not session then
		return
	end
	session.Settling = false
	session.Confirmed[session.Host] = false
	session.Confirmed[session.Guest] = false
	session.ConfirmEndsAt = 0
	if permanent then
		session.Status = "RevertFailed"
		-- Ops note: host→guest residual may remain until Cancel clears the desk.
		-- Admins should treat follow-up as "Trade settle recovery" / bug recovery.
		session.RevertFailedAt = os.time()
		session.RevertFailedReason = if type(reason) == "string" and reason ~= ""
			then reason
			else TradeSettle.REASON_HOST_REVERT
	else
		session.Status = "Open"
		session.RevertFailedAt = nil
		session.RevertFailedReason = nil
	end
end

-- Cancel must refuse while settle owns the table. RevertFailed desks stay cancellable
-- so partners can clear residual host→guest mutations.
function TradeSettle.CancelBlocked(session): (boolean, string?)
	if not session then
		return false, nil
	end
	if session.Settling == true or session.Status == "Settling" then
		return true, "That trade is already settling."
	end
	return false, nil
end

-- Run `tryOnce` up to `attempts` times. `tryOnce` returns true when the revert
-- AtomicUpdate committed. Used for host rollback after guest leave / apply fail.
function TradeSettle.RevertWithRetries(attempts: number?, tryOnce: () -> boolean): boolean
	local limit = math.max(1, math.floor(tonumber(attempts) or TradeSettle.REVERT_ATTEMPTS))
	for _ = 1, limit do
		if tryOnce() then
			return true
		end
	end
	return false
end

function TradeSettle.GuestLeftMessage(reverted: boolean): string
	if reverted then
		return "Guest left during settle — host side was reverted."
	end
	return "Guest left and host revert failed. Cancel and contact support."
end

function TradeSettle.GuestApplyMessage(reverted: boolean, applyError: string?): string
	if not reverted then
		return "Guest side failed and host revert did not commit. Cancel the table and contact support."
	end
	if type(applyError) == "string" and applyError ~= "" then
		return applyError
	end
	return "Guest side of the trade failed."
end

function TradeSettle.FormatRevertFailedLog(sessionId: any, hostId: number, guestId: number, reason: string): string
	return string.format(
		"RevertFailed session=%s host=%d guest=%d reason=%s — cancel table; admin note: %s",
		tostring(sessionId),
		hostId,
		guestId,
		reason,
		TradeSettle.ADMIN_NOTE
	)
end

-- AtomicUpdate result shape used by ConfirmTrade host/guest commits.
function TradeSettle.IsCommitOk(committed: boolean?, result: any): boolean
	return committed == true and type(result) == "table" and result.ok == true
end

function TradeSettle.CommitError(result: any): string?
	if type(result) == "table" and type(result.error) == "string" and result.error ~= "" then
		return result.error
	end
	return nil
end

-- Host→guest settle orchestration after TryBegin + Plan succeed.
-- hooks.applyHost / hooks.applyGuest → (committed, result) matching AtomicUpdate.
-- hooks.guestPresent → true when guest profile is still readable after host commit.
-- hooks.revertHostOnce → true when one host revert AtomicUpdate committed.
-- Returns a plain outcome table so ServerServices can toast / ModuleLog / respond
-- without owning the control flow of apply → re-read → apply → revert retries.
function TradeSettle.RunHostGuest(session, hooks: any): any
	assert(type(hooks) == "table", "RunHostGuest requires hooks")
	assert(type(hooks.applyHost) == "function", "hooks.applyHost required")
	assert(type(hooks.guestPresent) == "function", "hooks.guestPresent required")
	assert(type(hooks.applyGuest) == "function", "hooks.applyGuest required")
	assert(type(hooks.revertHostOnce) == "function", "hooks.revertHostOnce required")

	local hostCommitted, hostResult = hooks.applyHost()
	if not TradeSettle.IsCommitOk(hostCommitted, hostResult) then
		TradeSettle.Fail(session, false)
		return {
			ok = false,
			kind = TradeSettle.KIND_HOST_FAILED,
			message = TradeSettle.CommitError(hostResult) or "Host side of the trade failed.",
			permanent = false,
		}
	end

	if not hooks.guestPresent() then
		local reverted = TradeSettle.RevertWithRetries(TradeSettle.REVERT_ATTEMPTS, hooks.revertHostOnce)
		TradeSettle.Fail(session, not reverted, TradeSettle.REASON_GUEST_LEFT)
		local outcome: any = {
			ok = false,
			kind = TradeSettle.KIND_GUEST_LEFT,
			message = TradeSettle.GuestLeftMessage(reverted),
			permanent = not reverted,
			reason = TradeSettle.REASON_GUEST_LEFT,
		}
		if not reverted then
			outcome.log = TradeSettle.FormatRevertFailedLog(
				session.Id,
				session.Host,
				session.Guest,
				TradeSettle.REASON_GUEST_LEFT
			)
		end
		return outcome
	end

	local guestCommitted, guestResult = hooks.applyGuest()
	if not TradeSettle.IsCommitOk(guestCommitted, guestResult) then
		local reverted = TradeSettle.RevertWithRetries(TradeSettle.REVERT_ATTEMPTS, hooks.revertHostOnce)
		TradeSettle.Fail(session, not reverted, TradeSettle.REASON_GUEST_APPLY)
		local outcome: any = {
			ok = false,
			kind = TradeSettle.KIND_GUEST_FAILED,
			message = TradeSettle.GuestApplyMessage(reverted, TradeSettle.CommitError(guestResult)),
			permanent = not reverted,
			reason = TradeSettle.REASON_GUEST_APPLY,
		}
		if not reverted then
			outcome.log = TradeSettle.FormatRevertFailedLog(
				session.Id,
				session.Host,
				session.Guest,
				TradeSettle.REASON_GUEST_APPLY
			)
		end
		return outcome
	end

	return {
		ok = true,
		kind = TradeSettle.KIND_COMPLETE,
		permanent = false,
	}
end

return table.freeze(TradeSettle)
