--!strict
--[=[
	SecurityServices: merged module suite.
	Members (5): ProfileIntegrity, Security, SessionGate, ServerTelemetry, AtomicState.

	Each member keeps its original source inside its own closure (so every member
	still has its own local-register budget) and is evaluated lazily, exactly once,
	on first access.  Use `require(<this module>)("<Member>")` (or index the returned
	table with the member name) to get a member's exports.
]=]

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("SecurityServices: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("SecurityServices: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

-- ======================================================================
-- Module: ProfileIntegrity   (merged from ProfileIntegrity.luau, 213 lines)
-- ======================================================================
__defs["ProfileIntegrity"] = function()

return function()


	local ProfileIntegrity = {}

	local MOD_ADLER = 65521
	local JOURNAL_LIMIT = 12
	local MAX_NODES = 24000
	local ALGORITHM = "AFX-ADLER32-V1"

	local function finite(value: any): boolean
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	local function copy(value: any)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in value do result[copy(key)] = copy(child) end
		return result
	end

	local function orderedKeys(source): { any }
		local keys = {}
		for key in source do table.insert(keys, key) end
		table.sort(keys, function(left, right)
			local leftType, rightType = type(left), type(right)
			if leftType ~= rightType then return leftType < rightType end
			if leftType == "number" then return left < right end
			return tostring(left) < tostring(right)
		end)
		return keys
	end

	local function feed(state, text: string)
		for index = 1, #text do
			state.A = (state.A + string.byte(text, index)) % MOD_ADLER
			state.B = (state.B + state.A) % MOD_ADLER
		end
	end

	local function digestValue(state, value: any, depth: number, parentKey: string?, path: string?)
		state.Nodes += 1
		if state.Nodes > MAX_NODES or depth > 18 then
			error("profile exceeds integrity traversal budget")
		end
		local kind = type(value)
		if kind == "nil" then feed(state, "n;")
		elseif kind == "boolean" then feed(state, value and "b1;" or "b0;")
		elseif kind == "number" then
			if not finite(value) then error("profile contains a non-finite number at " .. (path or "?")) end
			feed(state, "d" .. string.format("%.17g", value) .. ";")
		elseif kind == "string" then
			feed(state, "s" .. tostring(#value) .. ":" .. value .. ";")
		elseif kind == "table" then
			feed(state, "{")
			for _, key in orderedKeys(value) do

				local excluded = parentKey == "Meta" and (key == "Integrity" or key == "Transactions")
				if not excluded then
					digestValue(state, key, depth + 1, nil, (path or "") .. "<key>")
					digestValue(state, value[key], depth + 1, type(key) == "string" and key or nil, (path or "") .. "." .. tostring(key))
				end
			end
			feed(state, "}")
		else
			error("profile contains unsupported value type " .. kind)
		end
	end

	function ProfileIntegrity.Hash(value: any): string
		local state = { A = 1, B = 0, Nodes = 0 }
		digestValue(state, value, 0, nil)
		return string.format("%08x", state.B * 65536 + state.A)
	end

	local function criticalSnapshot(profile)
		return {
			Cash = profile.Cash,
			Vault = profile.Vault,
			Cores = profile.Cores,
			Stardust = profile.Stardust,
			Rebirths = profile.Rebirths,
			RunCash = profile.RunCash,
			LifetimeCash = profile.LifetimeCash,
			Zone = profile.Zone,
			CurrentZone = profile.CurrentZone,
			Domain = copy(profile.Domain),
			Continuum = copy(profile.Continuum),
			Machines = copy(profile.Machines),
			Research = copy(profile.Research),
			GridUpgrades = copy(profile.GridUpgrades),
			BoostInventory = copy(profile.BoostInventory),
			Items = {
				NextId = profile.Items and profile.Items.NextId or 1,
				Essence = profile.Items and profile.Items.Essence or 0,
				Keys = copy(profile.Items and profile.Items.Keys or {}),
			},
			Anomaly = {
				Fragments = profile.Anomaly and profile.Anomaly.Fragments or 0,
				Stabilizations = profile.Anomaly and profile.Anomaly.Stabilizations or 0,
			},
		}
	end

	local function applyCriticalSnapshot(profile, snapshot)
		for _, key in {
			"Cash", "Vault", "Cores", "Stardust", "Rebirths", "RunCash", "LifetimeCash",
			"Zone", "CurrentZone", "Domain", "Continuum", "Machines", "Research", "GridUpgrades", "BoostInventory",
		} do
			if snapshot[key] ~= nil then profile[key] = copy(snapshot[key]) end
		end
		if type(snapshot.Items) == "table" and type(profile.Items) == "table" then
			profile.Items.NextId = snapshot.Items.NextId or profile.Items.NextId
			profile.Items.Essence = snapshot.Items.Essence or profile.Items.Essence
			profile.Items.Keys = copy(snapshot.Items.Keys or profile.Items.Keys)
		end
		if type(snapshot.Anomaly) == "table" and type(profile.Anomaly) == "table" then
			profile.Anomaly.Fragments = snapshot.Anomaly.Fragments or profile.Anomaly.Fragments
			profile.Anomaly.Stabilizations = snapshot.Anomaly.Stabilizations or profile.Anomaly.Stabilizations
		end
	end

	function ProfileIntegrity.EnsureEnvelope(profile)
		profile.Meta = type(profile.Meta) == "table" and profile.Meta or {}
		profile.Meta.Integrity = type(profile.Meta.Integrity) == "table" and profile.Meta.Integrity or {
			Algorithm = ALGORITHM,
			Hash = "",
			SealedRevision = 0,
			SealedAt = 0,
		}
		profile.Meta.Transactions = type(profile.Meta.Transactions) == "table" and profile.Meta.Transactions or {}
		return profile
	end

	function ProfileIntegrity.Seal(profile): string
		ProfileIntegrity.EnsureEnvelope(profile)
		local hash = ProfileIntegrity.Hash(profile)
		profile.Meta.Integrity = {
			Algorithm = ALGORITHM,
			Hash = hash,
			SealedRevision = math.max(0, math.floor(tonumber(profile.Meta.Revision) or 0)),
			SealedAt = os.time(),
		}
		return hash
	end

	function ProfileIntegrity.Record(profile, label: string, revision: number?)
		ProfileIntegrity.EnsureEnvelope(profile)
		local snapshot = criticalSnapshot(profile)
		local entry = {
			Id = string.format("%d:%d", os.time(), math.max(0, math.floor(revision or 0))),
			At = os.time(),
			Revision = math.max(0, math.floor(revision or 0)),
			Label = string.sub(label ~= "" and label or "mutation", 1, 64),
			Snapshot = snapshot,
			Hash = ProfileIntegrity.Hash(snapshot),
		}
		table.insert(profile.Meta.Transactions, entry)
		while #profile.Meta.Transactions > JOURNAL_LIMIT do table.remove(profile.Meta.Transactions, 1) end
		return entry
	end

	function ProfileIntegrity.VerifyAndRecover(profile): (boolean, string)
		ProfileIntegrity.EnsureEnvelope(profile)
		local envelope = profile.Meta.Integrity
		if envelope.Algorithm ~= ALGORITHM or type(envelope.Hash) ~= "string" or envelope.Hash == "" then
			local sealed = pcall(ProfileIntegrity.Seal, profile)
			if not sealed then
				return false, "legacy profile structure is invalid; schema recovery required"
			end
			return true, "sealed legacy profile"
		end
		local ok, current = pcall(ProfileIntegrity.Hash, profile)
		if ok and current == envelope.Hash then return true, "verified" end

		local journal = profile.Meta.Transactions
		for index = #journal, 1, -1 do
			local entry = journal[index]
			if type(entry) == "table" and type(entry.Snapshot) == "table" and type(entry.Hash) == "string" then
				local snapshotOk, snapshotHash = pcall(ProfileIntegrity.Hash, entry.Snapshot)
				if snapshotOk and snapshotHash == entry.Hash then
					applyCriticalSnapshot(profile, entry.Snapshot)
					local sealed = pcall(ProfileIntegrity.Seal, profile)
					if not sealed then
						return false, "transaction recovered critical state; schema recovery still required"
					end
					return false, "recovered critical state from transaction " .. tostring(entry.Id)
				end
			end
		end
		local sealed = pcall(ProfileIntegrity.Seal, profile)
		if not sealed then
			return false, "integrity mismatch; profile structure requires schema recovery"
		end
		return false, "integrity mismatch; no valid recovery entry"
	end

	function ProfileIntegrity.Status(profile)
		ProfileIntegrity.EnsureEnvelope(profile)
		local envelope = profile.Meta.Integrity
		return {
			Algorithm = envelope.Algorithm,
			Hash = envelope.Hash,
			SealedRevision = envelope.SealedRevision,
			SealedAt = envelope.SealedAt,
			JournalDepth = #profile.Meta.Transactions,
		}
	end

	return table.freeze(ProfileIntegrity)
end
end

-- ======================================================================
-- Module: Security   (merged from Security.luau, 345 lines)
-- ======================================================================
__defs["Security"] = function()

return function()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TextService = game:GetService("TextService")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")


	local Protocol = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("Protocol"))

	local Security = {}
	Security.__index = Security

	local Authority = {}
	Authority.__index = Authority

	function Authority.new()
		return setmetatable({ Actions = Protocol.Actions }, Authority)
	end

	function Authority:Validate(player: Player, action: any, payload: any): (boolean, string?)
		if RunService:IsStudio() then
			return true
		end
		if player.Parent ~= Players then
			return false, "player is not active"
		end
		if type(action) ~= "string" or self.Actions[action] == nil then
			return false, "unknown action"
		end
		if payload ~= nil and type(payload) ~= "table" then
			return false, "payload must be a table"
		end
		return true
	end

	local Nonce = {}
	Nonce.__index = Nonce

	function Nonce.new(ttl: number?)
		return setmetatable({ Values = {}, TTL = ttl or 8 }, Nonce)
	end

	function Nonce:Issue(player: Player): string
		local value = HttpService:GenerateGUID(false)
		self.Values[player] = { Value = value, Expires = os.clock() + self.TTL }
		return value
	end

	function Nonce:Consume(player: Player, value: any): boolean
		local record = self.Values[player]
		if not record or type(value) ~= "string" or record.Value ~= value or os.clock() > record.Expires then
			return false
		end
		self.Values[player] = nil
		return true
	end

	function Nonce:Forget(player: Player): ()
		self.Values[player] = nil
	end

	local Mask = {}
	Mask.__index = Mask

	function Mask.new()
		return setmetatable({ Keys = {} }, Mask)
	end

	function Mask:Key(player: Player): number
		local key = self.Keys[player]
		if key then
			return key
		end
		key = bit32.bxor(player.UserId, math.random(1, 0x7fffffff))
		self.Keys[player] = key
		return key
	end

	function Mask:Encode(player: Player, value: number): number
		return bit32.bxor(math.floor(math.max(0, value)) % 0x100000000, self:Key(player))
	end

	function Mask:Decode(player: Player, value: number): number
		return bit32.bxor(value, self:Key(player))
	end

	function Mask:Forget(player: Player): ()
		self.Keys[player] = nil
	end

	local Rollback = {}
	Rollback.__index = Rollback

	function Rollback.new(capacity: number?)
		return setmetatable({ Capacity = capacity or 8, History = {} }, Rollback)
	end

	function Rollback:Push(player: Player, revision: number, snapshot: any): ()
		local history = self.History[player] or {}
		table.insert(history, { Revision = revision, Snapshot = snapshot })
		while #history > self.Capacity do
			table.remove(history, 1)
		end
		self.History[player] = history
	end

	function Rollback:Latest(player: Player): any
		local history = self.History[player]
		return history and history[#history] or nil
	end

	function Rollback:Forget(player: Player): ()
		self.History[player] = nil
	end

	local Caller = {}
	Caller.__index = Caller

	function Caller.new()
		return setmetatable({}, Caller)
	end

	function Caller:Verify(expectedSource: string?): boolean
		local ok, source = pcall(function()
			return debug.info(3, "s")
		end)
		if not ok or expectedSource == nil then
			return ok
		end
		return source == expectedSource
	end

	local Honey = {}
	Honey.__index = Honey

	function Honey.new()
		return setmetatable({ Tokens = {}, Trips = {} }, Honey)
	end

	function Honey:Register(token: string): ()
		self.Tokens[token] = true
	end
	function Honey:Trip(player: Player, token: string): boolean
		if not self.Tokens[token] then
			return false
		end
		self.Trips[player] = (self.Trips[player] or 0) + 1
		player:SetAttribute("AF_HoneyTrips", self.Trips[player])
		return true
	end


	function Honey:Forget(player: Player): ()
		self.Trips[player] = nil
	end

	local Lifecycle = {}
	Lifecycle.__index = Lifecycle

	function Lifecycle.new()
		return setmetatable({ Connections = {} }, Lifecycle)
	end

	function Lifecycle:Watch(instance: Instance, callback: () -> ()): RBXScriptConnection
		local connection
		connection = instance.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				if connection ~= nil then
					connection:Disconnect()
				end
				callback()
			end
		end)
		table.insert(self.Connections, connection)
		return connection
	end

	function Lifecycle:Destroy(): ()
		for _, connection in self.Connections do
			connection:Disconnect()
		end
		table.clear(self.Connections)
	end

	local Filter = {}
	Filter.__index = Filter

	function Filter.new()
		return setmetatable({}, Filter)
	end

	function Filter:Apply(player: Player, raw: any, _contextUserId: number?, maximumLength: number?): (boolean, string?)
		if type(raw) ~= "string" then
			return false, nil
		end
		local text = string.sub(raw, 1, math.clamp(math.floor(maximumLength or 160), 1, 800))
		local ok, result = pcall(function()

			local filtered = TextService:FilterStringAsync(text, player.UserId)
			return filtered:GetNonChatStringForBroadcastAsync()
		end)
		if not ok or type(result) ~= "string" then
			return false, nil
		end
		return true, result
	end

	local Relations = {}
	Relations.__index = Relations

	function Relations.new()
		return setmetatable({}, Relations)
	end

	function Relations:Allows(flags: number, requiredBlockedMask: number): boolean
		return bit32.band(flags, requiredBlockedMask) == 0
	end

	local Device = {}
	Device.__index = Device

	function Device.new()
		return setmetatable({}, Device)
	end

	function Device:Escalate(player: Player, reason: string, severe: boolean?): ()
		player:SetAttribute("AF_SecurityReason", string.sub(reason, 1, 96))
		if severe and player.Parent == Players then
			player:Kick("Astral Forge rejected suspicious activity.")
		end
	end

	local Rate = {}
	Rate.__index = Rate

	function Rate.new(capacity: number?, refill: number?)
		return setmetatable({ Capacity = capacity or 30, Refill = refill or 8, Buckets = {} }, Rate)
	end

	function Rate:Allow(player: Player, cost: number?): boolean
		if RunService:IsStudio() then
			return true
		end
		local now = os.clock()
		local bucket = self.Buckets[player] or { Tokens = self.Capacity, At = now }
		bucket.Tokens = math.min(self.Capacity, bucket.Tokens + (now - bucket.At) * self.Refill)
		bucket.At = now
		local amount = cost or 1
		if bucket.Tokens < amount then
			self.Buckets[player] = bucket
			return false
		end
		bucket.Tokens -= amount
		self.Buckets[player] = bucket
		return true
	end

	function Rate:Forget(player: Player): ()
		self.Buckets[player] = nil
	end

	local Heuristic = {}
	Heuristic.__index = Heuristic

	function Heuristic.new()
		return setmetatable({ State = {} }, Heuristic)
	end

	function Heuristic:Observe(player: Player, production: number, revision: number): number
		local now = os.clock()
		local previous = self.State[player]
		if not previous then
			self.State[player] = { Production = production, Revision = revision, At = now, Score = 0 }
			return 0
		end
		local elapsed = math.max(0.05, now - previous.At)
		local acceleration = math.max(0, production - previous.Production) / elapsed
		if acceleration > math.max(1, production) * 1000 then
			previous.Score += 1
		end
		if revision < previous.Revision then
			previous.Score += 2
		end
		previous.Production = production
		previous.Revision = revision
		previous.At = now
		return previous.Score
	end

	function Security.new()
		local self = setmetatable({}, Security)
		self.Authority = Authority.new()
		self.Nonce = Nonce.new()
		self.Mask = Mask.new()
		self.Rollback = Rollback.new()
		self.Caller = Caller.new()
		self.Honey = Honey.new()
		self.Lifecycle = Lifecycle.new()
		self.Filter = Filter.new()
		self.Relationships = Relations.new()
		self.Device = Device.new()
		self.Rate = Rate.new()
		self.Heuristic = Heuristic.new()
		return self
	end

	function Security:Start(): ()
		if self._alive then
			return
		end
		self._alive = true
		self._playerRemoving = Players.PlayerRemoving:Connect(function(player)
			if not self._alive then
				return
			end
			self.Nonce:Forget(player)
			self.Mask:Forget(player)
			self.Rollback:Forget(player)
			self.Honey:Forget(player)
			self.Rate:Forget(player)
			self.Heuristic.State[player] = nil
		end)
	end

	function Security:Destroy(): ()
		self._alive = false
		if self._playerRemoving then
			self._playerRemoving:Disconnect()
			self._playerRemoving = nil
		end
		self.Lifecycle:Destroy()
		table.clear(self.Nonce.Values)
		table.clear(self.Mask.Keys)
		table.clear(self.Rollback.History)
		table.clear(self.Honey.Trips)
		table.clear(self.Rate.Buckets)
		table.clear(self.Heuristic.State)
	end


	return Security
end
end

-- ======================================================================
-- Module: SessionGate   (merged from SessionGate.luau, 252 lines)
-- ======================================================================
__defs["SessionGate"] = function()

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

		-- Hello issues a one-shot nonce: the first successful beat must rotate past it so a
		-- dumped hello response is stale within one beat. Later rotations keep the cadence.
		if session.prevNonce == nil or session.beatsSinceRotate >= ROTATE_EVERY_BEATS or now - session.lastRotate >= ROTATE_EVERY_SEC then
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
			-- Studio skips gen/nonce auth, but still allocate the session bag so Peek and
			-- txn helpers stay coherent after grants that never said Hello (TxnClaim/_get
			-- alone used to be the only Studio allocator — Peek then returned nil,nil).
			local session = self:_get(player)
			session.auth = true
			session.lastBeat = os.clock()
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
		-- Studio CheckGrant short-circuits without Hello, so txn helpers must create the
		-- session bag via _get — otherwise Claim returns "new", Store no-ops, and retries
		-- never short-circuit as "done"/"busy".
		local session = self:_get(player)
		local stored = session.txns[txnId]
		if stored == nil or stored == TXN_PENDING then
			return false, nil
		end
		return true, stored
	end

	function SessionGate:TxnClaim(player: Player, txnId: string): (string, any)
		local session = self:_get(player)
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
		local session = self:_get(player)
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
		-- Share _get with Claim/Store so Studio grants that never Hello'd still release
		-- against the same txn bag (previously Release no-op'd when _sessions was empty
		-- even after Claim allocated via _get on a different code path — impossible now,
		-- but keep one allocator for the whole txn surface).
		local session = self:_get(player)
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
end

-- ======================================================================
-- Module: ServerTelemetry   (merged from ServerTelemetry.luau, 156 lines)
-- ======================================================================
__defs["ServerTelemetry"] = function()

return function()
	type Timing = {
		Count: number,
		Failures: number,
		TotalMs: number,
		MaximumMs: number,
		LastMs: number,
	}

	local Telemetry = {}
	local startedAt = os.clock()
	local remoteAccepted = 0
	local remoteRejected = 0
	local integrityReports = 0
	local logs = { Info = 0, Warning = 0, Debug = 0 }
	local rejectionReasons: { [string]: number } = {}
	local timings: { [string]: Timing } = {}
	local activeSessions: { [number]: number } = {}
	local sessionsStarted = 0
	local sessionsEnded = 0
	local totalSessionSeconds = 0
	local clientQuality = { Samples = 0, TotalFPS = 0, TotalP95Ms = 0, TotalPingMs = 0, TotalBootMs = 0, TotalJank = 0, WorstP95Ms = 0 }

	local function timingFor(name: string): Timing
		local timing = timings[name]
		if not timing then
			timing = { Count = 0, Failures = 0, TotalMs = 0, MaximumMs = 0, LastMs = 0 }
			timings[name] = timing
		end
		return timing
	end

	function Telemetry.RecordLog(level: string): ()
		if level == "Info" then logs.Info += 1
		elseif level == "Warning" then logs.Warning += 1
		elseif level == "Debug" then logs.Debug += 1 end
	end

	function Telemetry.RecordRemote(accepted: boolean, reason: string?): ()
		if accepted then
			remoteAccepted += 1
			return
		end
		remoteRejected += 1
		local key = string.sub(reason or "unspecified", 1, 64)
		rejectionReasons[key] = (rejectionReasons[key] or 0) + 1
	end

	function Telemetry.RecordIntegrityReport(): ()
		integrityReports += 1
	end

	function Telemetry.RecordPlayerJoined(userId: number): ()
		if activeSessions[userId] then return end
		activeSessions[userId] = os.clock()
		sessionsStarted += 1
	end

	function Telemetry.RecordPlayerLeft(userId: number): ()
		local joinedAt = activeSessions[userId]
		if not joinedAt then return end
		activeSessions[userId] = nil
		sessionsEnded += 1
		totalSessionSeconds += math.max(0, os.clock() - joinedAt)
	end

	function Telemetry.Observe(name: string, seconds: number, succeeded: boolean): ()
		local milliseconds = math.max(0, seconds) * 1000
		local timing = timingFor(name)
		timing.Count += 1
		if not succeeded then timing.Failures += 1 end
		timing.TotalMs += milliseconds
		timing.MaximumMs = math.max(timing.MaximumMs, milliseconds)
		timing.LastMs = milliseconds
	end

	function Telemetry.RecordClientPerformance(sample): ()
		clientQuality.Samples += 1
		clientQuality.TotalFPS += math.clamp(tonumber(sample.FPS) or 0, 0, 360)
		clientQuality.TotalP95Ms += math.clamp(tonumber(sample.P95Ms) or 0, 0, 1000)
		clientQuality.TotalPingMs += math.clamp(tonumber(sample.PingMs) or 0, 0, 10_000)
		clientQuality.TotalBootMs += math.clamp(tonumber(sample.BootMs) or 0, 0, 120_000)
		clientQuality.TotalJank += math.clamp(tonumber(sample.JankPct) or 0, 0, 1)
		clientQuality.WorstP95Ms = math.max(clientQuality.WorstP95Ms, tonumber(sample.P95Ms) or 0)
	end

	function Telemetry.Snapshot()
		local reasonList = {}
		for reason, count in rejectionReasons do
			table.insert(reasonList, { Reason = reason, Count = count })
		end
		table.sort(reasonList, function(left, right)
			if left.Count == right.Count then return left.Reason < right.Reason end
			return left.Count > right.Count
		end)
		while #reasonList > 6 do table.remove(reasonList) end

		local timingList = {}
		for name, timing in timings do
			table.insert(timingList, {
				Name = name,
				Count = timing.Count,
				Failures = timing.Failures,
				AverageMs = timing.Count > 0 and timing.TotalMs / timing.Count or 0,
				MaximumMs = timing.MaximumMs,
				LastMs = timing.LastMs,
			})
		end
		table.sort(timingList, function(left, right) return left.Name < right.Name end)

		local total = remoteAccepted + remoteRejected
		local samples = clientQuality.Samples
		return {
			UptimeSeconds = math.max(0, os.clock() - startedAt),
			RemoteAccepted = remoteAccepted,
			RemoteRejected = remoteRejected,
			RemoteRejectRate = total > 0 and remoteRejected / total or 0,
			IntegrityReports = integrityReports,
			SessionsStarted = sessionsStarted,
			SessionsEnded = sessionsEnded,
			ActiveSessions = sessionsStarted - sessionsEnded,
			AverageSessionSeconds = sessionsEnded > 0 and totalSessionSeconds / sessionsEnded or 0,
			Logs = table.clone(logs),
			TopRejections = reasonList,
			Timings = timingList,
			ClientPerformance = {
				Samples = samples,
				AverageFPS = samples > 0 and clientQuality.TotalFPS / samples or 0,
				AverageP95Ms = samples > 0 and clientQuality.TotalP95Ms / samples or 0,
				AveragePingMs = samples > 0 and clientQuality.TotalPingMs / samples or 0,
				AverageBootMs = samples > 0 and clientQuality.TotalBootMs / samples or 0,
				AverageJankPct = samples > 0 and clientQuality.TotalJank / samples or 0,
				WorstP95Ms = clientQuality.WorstP95Ms,
			},
		}
	end

	function Telemetry.ResetForTests(): ()
		startedAt = os.clock()
		remoteAccepted = 0
		remoteRejected = 0
		integrityReports = 0
		sessionsStarted = 0
		sessionsEnded = 0
		totalSessionSeconds = 0
		logs = { Info = 0, Warning = 0, Debug = 0 }
		table.clear(rejectionReasons)
		table.clear(timings)
		table.clear(activeSessions)
		clientQuality = { Samples = 0, TotalFPS = 0, TotalP95Ms = 0, TotalPingMs = 0, TotalBootMs = 0, TotalJank = 0, WorstP95Ms = 0 }
	end

	return table.freeze(Telemetry)
end
end

-- ======================================================================
-- Module: AtomicState   (merged from AtomicState.luau, 88 lines)
-- ======================================================================
__defs["AtomicState"] = function()

return function()
	local AtomicState = {}
	AtomicState.__index = AtomicState

	local CONTENTION_TIMEOUT_SECONDS = 2
	local CONTENTION_POLL_SECONDS = 0.03

	local function clone(value)
		if type(value) ~= "table" then
			return value
		end
		local result = {}
		for key, child in value do
			result[clone(key)] = clone(child)
		end
		return result
	end

	local function revisionOf(value): number
		if type(value) == "table" and type(value.Meta) == "table" and type(value.Meta.Revision) == "number" then
			return math.max(0, math.floor(value.Meta.Revision))
		end
		return 0
	end

	function AtomicState.new(initial)
		local self = setmetatable({}, AtomicState)
		self._value = initial
		self._revision = revisionOf(initial)
		self._busy = false
		return self
	end

	function AtomicState:Read()
		self._revision = math.max(self._revision, revisionOf(self._value))
		return self._value, self._revision
	end

	function AtomicState:IsBusy(): boolean
		return self._busy == true
	end

	function AtomicState:Transact(callback, incrementRevision: boolean?): (boolean, any, number)
		local deadline = os.clock() + CONTENTION_TIMEOUT_SECONDS
		while self._busy and os.clock() < deadline do
			task.wait(CONTENTION_POLL_SECONDS)
		end
		if self._busy then
			return false, "state transaction already in progress", self._revision
		end
		self._revision = math.max(self._revision, revisionOf(self._value))
		self._busy = true
		local cloneOk, draft = pcall(clone, self._value)
		if not cloneOk then
			self._busy = false
			return false, draft, self._revision
		end
		local ok, result = pcall(callback, draft, self._revision + 1)
		local shouldCommit = ok and not (type(result) == "table" and result.ok == false)
		if shouldCommit then
			if incrementRevision ~= false then
				self._revision += 1
				if type(draft) == "table" and type(draft.Meta) == "table" then
					draft.Meta.Revision = self._revision
				end
			end
			self._value = draft
		end
		self._busy = false
		if not ok then
			return false, result, self._revision
		end
		return true, result, self._revision
	end

	function AtomicState:Replace(value, revision: number?): boolean
		if self._busy then
			return false
		end
		self._value = value
		self._revision = math.max(self._revision, revision or self._revision)
		return true
	end

	return AtomicState
end
end

-- ======================================================================
-- Suite entry point
-- ======================================================================
local __members = {}
for name in __defs do
	table.insert(__members, name)
end
table.sort(__members)
table.freeze(__members)
return setmetatable({}, {
	__call = function(_, name: string): any
		return __load(name)
	end,
	__index = function(_, name: string): any
		-- The boot loader reads the member list to warm every member up front.
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
