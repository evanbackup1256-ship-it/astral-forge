--!strict
-- Purchase status survives page changes. Only a saved receipt or server ownership
-- confirmation can produce success; Roblox's prompt callback is not delivery.
local Session = {}
type Status = {
	phase: string,
	token: number,
	busy: boolean,
	awaiting: boolean,
	label: string?,
	detail: string?,
}

function Session.new(dependencies: any): any
	local listeners = {}
	local current: Status = { phase = "hidden", token = 0, busy = false, awaiting = false }
	local nextToken = 0
	local label: string? = nil
	local receipts: { [string]: boolean } = {}
	local receiptHistory: { string } = {}
	local pending: any = nil
	local disposed = false
	local stopped: (() -> ())? = nil
	local function publish(phase: string, detail: string?)
		current = {
			phase = phase,
			token = nextToken,
			busy = phase == "pending" or phase == "verifying",
			awaiting = pending ~= nil,
			label = label,
			detail = detail,
		}
		for callback in table.clone(listeners) do
			callback(current)
		end
	end
	local function stopTimer()
		if stopped then
			stopped()
			stopped = nil
		end
	end
	local function complete(phase: string, detail: string?)
		stopTimer()
		pending = nil
		publish(phase, detail)
	end
	local function deadline(token: number)
		stopTimer()
		stopped = dependencies.schedule(45, function()
			if not disposed and pending and current.token == token then
				stopped = nil
				publish(
					"delayed",
					"Confirmation is taking longer than usual. Completed purchases are delivered automatically."
				)
			end
		end)
	end
	local api = {}
	function api.snapshot()
		return current
	end
	function api.subscribe(callback: (any) -> ()): () -> ()
		listeners[callback] = true
		callback(current)
		return function()
			listeners[callback] = nil
		end
	end
	function api.begin(offer: any, kind: string): boolean
		if disposed or current.busy or pending ~= nil or type(offer) ~= "table" or offer.Donation then
			return false
		end
		if kind ~= "product" and kind ~= "pass" then
			return false
		end
		local id = if kind == "pass" then offer.PassId else offer.ProductId
		if type(id) ~= "number" or id ~= id or id <= 0 or id == math.huge or id % 1 ~= 0 then
			return false
		end
		pending = table.clone(offer)
		pending.kind = kind
		pending.id = id
		nextToken += 1
		label = pending.Name
		local token = nextToken
		publish("pending")
		deadline(token)
		local ok = pcall(dependencies.prompt, kind, id)
		if not ok and pending and current.token == token then
			complete("fail", "Roblox checkout could not open. Please try again.")
		end
		return ok
	end
	function api.promptFinished(kind: string, id: number, purchased: boolean)
		if disposed or pending == nil or pending.kind ~= kind or pending.id ~= id then
			return
		end
		if not purchased then
			complete("cancelled", "Purchase prompt closed. You can return to the shop.")
			return
		end
		publish("verifying")
		local token = current.token
		deadline(token)
		if kind == "pass" then
			local key = pending.Key
			local ok = pcall(dependencies.verifyPass, key, function(owned: boolean)
				if disposed or pending == nil or current.token ~= token then
					return
				end
				if owned then
					complete("success", "Your pass is unlocked and its bonuses are active.")
				end
			end)
			if not ok then
				publish(
					"delayed",
					"Ownership has not been confirmed yet. It will update when Roblox confirms the pass."
				)
			end
		end
	end
	function api.receipt(payload: any)
		if disposed or type(payload) ~= "table" or pending == nil or pending.kind ~= "product" then
			return
		end
		if
			payload.ProductId == pending.id
			and type(payload.Key) == "string"
			and payload.Key ~= ""
			and not receipts[payload.Key]
		then
			receipts[payload.Key] = true
			table.insert(receiptHistory, payload.Key)
			if #receiptHistory > 128 then
				receipts[table.remove(receiptHistory, 1)] = nil
			end
			complete("success", "Your purchase has been saved and added to your account.")
		end
	end
	function api.dismiss(): boolean
		if disposed or current.busy then
			return false
		end
		-- Keep delayed delivery tracking alive when the player resumes the game.
		publish("hidden")
		return true
	end
	function api.reconcile(owned: any)
		if disposed then
			return
		end
		if pending and pending.kind == "pass" and type(owned) == "table" and owned[pending.Key] == true then
			complete("success", "Your pass is unlocked and its bonuses are active.")
		end
	end
	function api.resume()
		if not disposed and pending and current.phase == "hidden" then
			publish("delayed", "A purchase is still confirming. Completed rewards arrive automatically.")
		end
	end
	function api.dispose()
		disposed = true
		stopTimer()
		table.clear(listeners)
	end
	return api
end

return Session
