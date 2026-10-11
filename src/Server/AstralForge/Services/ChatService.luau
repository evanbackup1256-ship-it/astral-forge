--!strict
-- Server chat channels beyond RBXGeneral:
--   friends  : one TextChannel that only delivers between Roblox friends in this server
--   whispers : per-pair TextChannels created on request (Roblox filters and respects privacy)
--   global   : filtered text relayed across servers through sharded MemoryStore sorted maps
--              (see ChatRules: polling costs a fixed amount per server; broadcasting does not scale)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)
local ChatRules = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ChatRules"))

local DELIVER_PER_FLUSH = 8 -- busy periods sample global chat instead of flooding every client
local WHISPER_LIMIT = 24 -- open whisper channels per player
local HISTORY = 30

local ChatService = {}
ChatService.__index = ChatService

function ChatService.new(effect: RemoteEvent, data: any?)
	local self = setmetatable({}, ChatService)
	self._effect = effect
	self._data = data
	self._alive = true
	self._friends = {} :: { [string]: boolean }
	self._canChat = {} :: { [number]: boolean }
	self._lastGlobal = {} :: { [number]: number }
	self._whispers = {} :: { [number]: { [string]: boolean } }
	self._outbox = {} :: { any }
	self._inbox = {} :: { any }
	self._history = {} :: { any }
	self._maps = {} :: { MemoryStoreSortedMap }
	self._seen = {} :: { [number]: string } -- newest key already read from each map
	self._sequence = 0
	self._shard = ChatRules.shardFor(game.JobId ~= "" and game.JobId or "studio")
	self._connections = {} :: { RBXScriptConnection }
	self._channels = nil :: Instance?
	self._friendsChannel = nil :: TextChannel?
	task.spawn(function() self:_boot() end)
	return self
end

function ChatService:_boot()
	local channels = TextChatService:WaitForChild("TextChannels", 30)
	if not self._alive or channels == nil then return end
	self._channels = channels
	local friends = channels:FindFirstChild(ChatRules.FRIENDS_CHANNEL)
	if friends == nil then
		local created = Instance.new("TextChannel")
		created.Name = ChatRules.FRIENDS_CHANNEL
		created.Parent = channels
		friends = created
	end
	local friendsChannel = friends :: TextChannel
	self._friendsChannel = friendsChannel
	friendsChannel.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource)
		local source = message.TextSource
		if source == nil then return false end
		if source.UserId == target.UserId then return true end
		return self:_areFriends(source.UserId, target.UserId)
	end
	table.insert(self._connections, Players.PlayerAdded:Connect(function(player) self:_join(player) end))
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player) self:_leave(player) end))
	for _, player in Players:GetPlayers() do task.spawn(function() self:_join(player) end) end
	if not StoreAccess.isPreview() then
		for shard = 1, ChatRules.GLOBAL_SHARDS do
			local ok, map = pcall(function() return MemoryStoreService:GetSortedMap(ChatRules.mapName(shard)) end)
			if ok then self._maps[shard] = map end
		end
	end
	task.spawn(function()
		while self._alive do
			task.wait(ChatRules.GLOBAL_TICK)
			self:_flush()
		end
	end)
end

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

function ChatService:_areFriends(a: number, b: number): boolean
	return self._friends[pairKey(a, b)] == true
end

function ChatService:_join(player: Player)
	if not self._alive then return end
	local friendsChannel = self._friendsChannel
	if friendsChannel then pcall(function() friendsChannel:AddUserAsync(player.UserId) end) end
	local okChat, canChat = pcall(function() return TextChatService:CanUserChatAsync(player.UserId) end)
	self._canChat[player.UserId] = okChat and canChat == true
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, friends = pcall(function() return player:IsFriendsWith(other.UserId) end)
			if ok and friends then self._friends[pairKey(player.UserId, other.UserId)] = true end
		end
	end
	if #self._history > 0 and player.Parent == Players then
		self._effect:FireClient(player, { Type = "ChatGlobal", Messages = self._history, Backlog = true })
	end
end

function ChatService:_leave(player: Player)
	local userId = player.UserId
	self._canChat[userId] = nil
	self._lastGlobal[userId] = nil
	for key in self._friends do
		local a, b = string.match(key, "^(%d+):(%d+)$")
		if tonumber(a) == userId or tonumber(b) == userId then self._friends[key] = nil end
	end
	local channels = self._channels
	local open = self._whispers[userId]
	self._whispers[userId] = nil
	if channels and open then
		for name in open do
			local channel = channels:FindFirstChild(name)
			if channel then channel:Destroy() end
			local peer = ChatRules.whisperPeer(name, userId)
			if peer and self._whispers[peer] then self._whispers[peer][name] = nil end
		end
	end
end

function ChatService:OpenWhisper(player: Player, payload: any)
	local targetId = if type(payload) == "table" then tonumber(payload.UserId) else nil
	if targetId == nil or targetId == player.UserId then return { ok = false, error = "Pick another player to whisper." } end
	local target = Players:GetPlayerByUserId(targetId)
	if target == nil then return { ok = false, error = "That player is no longer in this server." } end
	local channels = self._channels
	if channels == nil then return { ok = false, error = "Chat is still starting. Try again in a moment." } end
	if self._canChat[player.UserId] == false then return { ok = false, error = "Chat is turned off for your account." } end
	local name = ChatRules.whisperChannel(player.UserId, targetId)
	-- the target's "whispers from friends only" setting; an existing conversation stays open
	local targetProfile = self._data and self._data:Get(target)
	local friendsOnly = targetProfile and targetProfile.Settings and targetProfile.Settings.WhispersFriendsOnly
	if channels:FindFirstChild(name) == nil and type(friendsOnly) == "number" and friendsOnly >= 0.5
		and not self:_areFriends(player.UserId, targetId) then
		return { ok = false, error = `{target.DisplayName} only takes whispers from friends.` }
	end
	local existing = channels:FindFirstChild(name)
	if existing == nil then
		local mine = self._whispers[player.UserId] or {}
		local count = 0
		for _ in mine do count += 1 end
		if count >= WHISPER_LIMIT then return { ok = false, error = "Too many whispers open. Close one first." } end
		local channel = Instance.new("TextChannel")
		channel.Name = name
		channel.Parent = channels
		local okA = pcall(function() channel:AddUserAsync(player.UserId) end)
		local okB, sourceB = pcall(function() return channel:AddUserAsync(targetId) end)
		if not okA or not okB or sourceB == nil then
			channel:Destroy()
			return { ok = false, error = "That player can't receive whispers right now." }
		end
		existing = channel
		self._whispers[player.UserId] = mine
		mine[name] = true
		self._whispers[targetId] = self._whispers[targetId] or {}
		self._whispers[targetId][name] = true
	end
	return { ok = true, Channel = name, UserId = targetId }
end

function ChatService:SendGlobal(player: Player, payload: any)
	local raw = if type(payload) == "table" then payload.Text else nil
	if type(raw) ~= "string" then return { ok = false, error = "Type a message first." } end
	local text = ChatRules.trim(raw)
	if text == "" or utf8.len(text) == nil or (utf8.len(text) :: number) > ChatRules.MAX_INPUT then
		return { ok = false, error = "Message is empty or too long." }
	end
	local now = os.clock()
	local last = self._lastGlobal[player.UserId]
	if last and now - last < ChatRules.GLOBAL_COOLDOWN then
		return { ok = false, error = string.format("Global chat cools down for %ds.", math.ceil(ChatRules.GLOBAL_COOLDOWN - (now - last))) }
	end
	if self._canChat[player.UserId] ~= true then
		local okChat, canChat = pcall(function() return TextChatService:CanUserChatAsync(player.UserId) end)
		self._canChat[player.UserId] = okChat and canChat == true
		if not self._canChat[player.UserId] then return { ok = false, error = "Chat is turned off for your account." } end
	end
	self._lastGlobal[player.UserId] = now
	local okFilter, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not okFilter or type(filtered) ~= "string" or filtered == "" then
		return { ok = false, error = "Roblox could not filter that message. Try again." }
	end
	local entry = {
		Id = HttpService:GenerateGUID(false),
		UserId = player.UserId,
		Name = player.Name,
		Display = player.DisplayName,
		Text = filtered,
		At = os.time(),
	}
	self:_deliver({ entry })
	if not StoreAccess.isPreview() then table.insert(self._outbox, entry) end
	return { ok = true }
end

function ChatService:_remember(entries: { any })
	for _, entry in entries do
		table.insert(self._history, entry)
		while #self._history > HISTORY do table.remove(self._history, 1) end
	end
end

function ChatService:_deliver(entries: { any })
	if #entries == 0 then return end
	self:_remember(entries)
	for _, recipient in Players:GetPlayers() do
		if self._canChat[recipient.UserId] == true then
			self._effect:FireClient(recipient, { Type = "ChatGlobal", Messages = entries })
		end
	end
end

-- One tick: write at most one batch to this server's map, then read the newest entries of every map.
function ChatService:_flush()
	local own = self._maps[self._shard]
	if own and #self._outbox > 0 then
		local batch, encoded = ChatRules.takeBatch(self._outbox, function(list)
			return HttpService:JSONEncode({ S = game.JobId, M = list })
		end)
		if #batch > 0 and encoded then
			self._sequence += 1
			local key = ChatRules.entryKey(DateTime.now().UnixTimestampMillis, string.sub(game.JobId, 1, 12) .. tostring(self._sequence))
			pcall(function() own:SetAsync(key, encoded, ChatRules.GLOBAL_TTL) end)
		end
	end
	for shard, map in self._maps do
		local ok, items = pcall(function()
			return map:GetRangeAsync(Enum.SortDirection.Descending, ChatRules.GLOBAL_READ_COUNT)
		end)
		if ok and type(items) == "table" then
			local seen = self._seen[shard]
			local newest = seen
			-- oldest first, and only keys newer than the last pass; the first pass just sets the mark
			for index = #items, 1, -1 do
				local item = items[index]
				local key = if type(item) == "table" then item.key else nil
				if type(key) == "string" and (seen == nil or key > seen) then
					if seen ~= nil then self:_onRelay(item.value) end
					if newest == nil or key > newest then newest = key end
				end
			end
			self._seen[shard] = newest or ""
		end
	end
	if #self._inbox > 0 then
		local take = {}
		local start = math.max(1, #self._inbox - DELIVER_PER_FLUSH + 1)
		for index = start, #self._inbox do table.insert(take, self._inbox[index]) end
		table.clear(self._inbox)
		self:_deliver(take)
	end
end

local function validEntry(entry: any): boolean
	return type(entry) == "table"
		and type(entry.Id) == "string" and #entry.Id <= 64
		and type(entry.UserId) == "number"
		and type(entry.Name) == "string" and #entry.Name <= 32
		and type(entry.Display) == "string" and #entry.Display <= 64
		and type(entry.Text) == "string" and #entry.Text <= 640
		and type(entry.At) == "number"
end

function ChatService:_onRelay(raw: any)
	if not self._alive or type(raw) ~= "string" then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(data) ~= "table" or data.S == game.JobId or type(data.M) ~= "table" then return end
	for _, entry in data.M do
		if validEntry(entry) then
			table.insert(self._inbox, entry)
			if #self._inbox > DELIVER_PER_FLUSH * 4 then table.remove(self._inbox, 1) end
		end
	end
end

function ChatService:Shutdown()
	self._alive = false
	for _, connection in self._connections do connection:Disconnect() end
	table.clear(self._connections)
	table.clear(self._maps)
end

return table.freeze(ChatService)
