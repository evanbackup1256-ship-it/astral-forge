--!strict
-- One action in flight; callbacks cannot update a disposed or superseded screen.

export type Reply = { ok: boolean, message: string?, error: string?, [string]: any }
export type Dispatch = (action: string, payload: { [string]: any }, callback: (Reply?) -> ()) -> ()
export type Schedule = (seconds: number, callback: () -> ()) -> any

local REQUEST_TIMEOUT_SECONDS = 12

return function(dispatch: Dispatch, schedule: Schedule, changed: () -> ())
	local Request = { busy = false, status = "", generation = 0, alive = true }
	function Request.dispose()
		Request.alive = false
		Request.generation += 1
		Request.busy = false
	end
	function Request.run(action: string, payload: { [string]: any }?, callback: ((Reply) -> ())?)
		if Request.busy or not Request.alive then
			return false
		end
		Request.busy = true
		Request.generation += 1
		Request.status = "Working…"
		local generation = Request.generation
		changed()
		local function finish(reply: Reply?)
			if not Request.alive or generation ~= Request.generation or not Request.busy then
				return
			end
			Request.busy = false
			Request.generation += 1
			if type(reply) ~= "table" then
				reply = { ok = false, error = "No response. Refresh before trying again." }
			end
			Request.status = if reply.ok == true
				then (reply.message or "Done.")
				else (reply.error or reply.message or "Request failed. Try again.")
			changed()
			if callback then
				callback(reply)
			end
		end
		schedule(REQUEST_TIMEOUT_SECONDS, function()
			finish(nil)
		end)
		local ok = pcall(dispatch, action, payload or {}, finish)
		if not ok then
			finish({ ok = false, error = "Connection interrupted. Try again." })
		end
		return true
	end
	return Request
end
