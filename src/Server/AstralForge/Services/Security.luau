--!strict

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
