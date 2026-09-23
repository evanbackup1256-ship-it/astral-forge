--!strict

return function()
	local HttpService = game:GetService("HttpService")
	local RunService = game:GetService("RunService")

	local ROTATE_EVERY_BEATS = 8
	local ROTATE_EVERY_SEC = 24
	local GRACE_SEC = 2.5
	local UNAUTH_AFTER = 45
	local LATE_BEAT_STRIKE_SEC = 8
	local TXN_RING = 64

	type Session = {
		gen: number,
		nonce: string,
		prevNonce: string?,
		issued: number,
		lastRotate: number,
		lastBeat: number,
		lastBeatId: number,
		beatsSinceRotate: number,
		auth: boolean,
		txns: { [string]: any },
		txnOrder: { string },
	}

	local SessionGate = {}
	SessionGate.__index = SessionGate

	local function newNonce(): string
		return HttpService:GenerateGUID(false)
	end

	function SessionGate.new()
		local self = setmetatable({}, SessionGate)
		self._sessions = {} :: { [Player]: Session }
		return self
	end

	function SessionGate:_get(player: Player): Session
		local existing = self._sessions[player]
		if existing then
			return existing
		end
		local now = os.clock()
		local created: Session = {
			gen = 1,
			nonce = newNonce(),
			prevNonce = nil,
			issued = now,
			lastRotate = now,
			lastBeat = now,
			lastBeatId = 0,
			beatsSinceRotate = 0,
			auth = false,
			txns = {},
			txnOrder = {},
		}
		self._sessions[player] = created
		return created
	end

	-- Called on the player's first request. Returns the values the client needs to start
	-- beating: current gen and nonce. The hello nonce is one-shot -- the first successful
	-- beat rotates past it so a dumped hello response goes stale within one beat interval.
	function SessionGate:Hello(player: Player): (number, string)
		local session = self:_get(player)
		return session.gen, session.nonce
	end

	local function rotate(session: Session)
		session.prevNonce = session.nonce
		session.nonce = newNonce()
		session.gen += 1
		session.lastRotate = os.clock()
		session.beatsSinceRotate = 0
	end

	-- gen/id/n as sent by src_ts/client/session.ts. Returns ok, and on success the gen/nonce
	-- the client should adopt (unchanged if no rotation happened this beat).
	function SessionGate:Beat(player: Player, gen: any, id: any, n: any): (boolean, string?, number?, string?)
		if RunService:IsStudio() then
			local session = self:_get(player)
			session.auth = true
			return true, nil, session.gen, session.nonce
		end
		-- Every rejection still returns the live gen/nonce so a client that missed a
		-- rotation response can resync on its next beat instead of beating a stale gen
		-- forever. Peek() already exposes these on any rejected request, so this leaks
		-- nothing an attacker couldn't already read.
		local session = self:_get(player)
		local now = os.clock()
		if type(gen) ~= "number" or type(id) ~= "number" or type(n) ~= "string" then
			return false, "malformed beat", session.gen, session.nonce
		end

		local inGrace = session.prevNonce ~= nil and now - session.lastRotate < GRACE_SEC
		local genOk = gen == session.gen or (inGrace and gen == session.gen - 1)
		if not genOk then
			return false, "gen mismatch", session.gen, session.nonce
		end
		local nonceOk = n == session.nonce or (inGrace and gen == session.gen - 1 and n == session.prevNonce)
		if not nonceOk then
			return false, "nonce mismatch", session.gen, session.nonce
		end
		if id <= session.lastBeatId then
			return false, "replay", session.gen, session.nonce
		end

		local late = now - session.lastBeat
		session.lastBeat = now
		session.lastBeatId = id
		session.beatsSinceRotate += 1
		session.auth = true

		if late > UNAUTH_AFTER then
			session.auth = false
		end

		if session.beatsSinceRotate >= ROTATE_EVERY_BEATS or now - session.lastRotate >= ROTATE_EVERY_SEC then
			rotate(session)
		end

		if late > LATE_BEAT_STRIKE_SEC then
			return session.auth, "late", session.gen, session.nonce
		end
		return session.auth, nil, session.gen, session.nonce
	end

	-- Grants call this before mutating. Requires auth and a matching gen; requireNonce additionally
	-- requires a matching live nonce for the caller's high-value actions. Idle players past
	-- UNAUTH_AFTER read as unauthenticated even if a Beat has not explicitly failed -- a dropped
	-- connection or backgrounded mobile app should not keep granting on a stale session.
	function SessionGate:CheckGrant(player: Player, gen: any, n: any, requireNonce: boolean): (boolean, string?)
		if RunService:IsStudio() then
			return true
		end
		local session = self._sessions[player]
		if not session then
			return false, "no session"
		end
		local now = os.clock()
		if not session.auth or now - session.lastBeat > UNAUTH_AFTER then
			return false, "unauth"
		end
		-- Match Beat(): in-flight grants that left before a rotation still pass for GRACE_SEC
		-- with the previous gen/nonce, so mid-flight taps are not dropped as gen mismatches.
		local inGrace = session.prevNonce ~= nil and now - session.lastRotate < GRACE_SEC
		local genOk = type(gen) == "number" and (gen == session.gen or (inGrace and gen == session.gen - 1))
		if not genOk then
			return false, "gen mismatch"
		end
		if requireNonce then
			local nonceOk = type(n) == "string"
				and (n == session.nonce or (inGrace and gen == session.gen - 1 and n == session.prevNonce))
			if not nonceOk then
				return false, "nonce mismatch"
			end
		end
		return true
	end

	local TXN_PENDING = { __txn = "pending" }

	function SessionGate:TxnLookup(player: Player, txnId: string): (boolean, any)
		local session = self._sessions[player]
		if not session then
			return false, nil
		end
		local stored = session.txns[txnId]
		if stored == nil or stored == TXN_PENDING then
			return false, nil
		end
		return true, stored
	end

	function SessionGate:TxnClaim(player: Player, txnId: string): (string, any)
		local session = self._sessions[player]
		if not session then
			return "new", nil
		end
		local stored = session.txns[txnId]
		if stored == TXN_PENDING then
			return "busy", nil
		end
		if stored ~= nil then
			return "done", stored
		end
		table.insert(session.txnOrder, txnId)
		if #session.txnOrder > TXN_RING then
			local oldest = table.remove(session.txnOrder, 1)
			if oldest then
				session.txns[oldest] = nil
			end
		end
		session.txns[txnId] = TXN_PENDING
		return "new", nil
	end

	function SessionGate:TxnStore(player: Player, txnId: string, result: any)
		local session = self._sessions[player]
		if not session then
			return
		end
		if session.txns[txnId] == nil then
			table.insert(session.txnOrder, txnId)
			if #session.txnOrder > TXN_RING then
				local oldest = table.remove(session.txnOrder, 1)
				if oldest then
					session.txns[oldest] = nil
				end
			end
		end
		session.txns[txnId] = result
	end

	function SessionGate:TxnRelease(player: Player, txnId: string)
		local session = self._sessions[player]
		if not session then
			return
		end
		if session.txns[txnId] == TXN_PENDING then
			session.txns[txnId] = nil
			for index, id in session.txnOrder do
				if id == txnId then
					table.remove(session.txnOrder, index)
					break
				end
			end
		end
	end

	-- Read-only peek at the live gen/nonce, used to resync a client whose grant request
	-- was rejected (or accepted) with a gen that had already rotated server-side.
	function SessionGate:Peek(player: Player): (number?, string?)
		local session = self._sessions[player]
		if not session then
			return nil, nil
		end
		return session.gen, session.nonce
	end

	function SessionGate:Forget(player: Player)
		self._sessions[player] = nil
	end

	return SessionGate
end
