--!strict
local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)
-- Persistent guild community features. Chat and announcement text is filtered before storage or broadcast.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local STORE_NAME = "AstralForge_GuildCommunity_v1"
local CHAT_LIMIT = 200
local ANNOUNCEMENT_LIMIT = 50
local LOGO_HISTORY_LIMIT = 12
local CACHE_SECONDS = 8
-- cross-server relay: members on other servers see chat/announcements immediately.
-- One topic per guild, subscribed only by servers that currently host a member of that guild.
-- A single shared topic would deliver every guild's traffic to every server, and that fan-out
-- (publishes x servers) exhausts the experience-wide receive budget at high server counts.
local RELAY_PREFIX = "AF_Guild_v2_"
local RELAY_MAX_BYTES = 900 -- MessagingService caps a message at 1 kB
local RELAY_RECONCILE_SECONDS = 5

local function relayTopic(guildId: string): string?
	local topic = RELAY_PREFIX .. guildId
	-- MessagingService topics are at most 80 characters
	return if #topic <= 80 and not string.find(guildId, "[^%w%-_]") then topic else nil
end

export type GuildAnnouncement = {
	Id: string,
	AuthorUserId: number,
	AuthorName: string,
	AuthorRole: string,
	PublishedAt: number,
	EditedAt: number?,
	Pinned: boolean,
	Archived: boolean,
	ExpiresAt: number?,
	Title: string,
	Body: string,
}

export type GuildChatMessage = {
	Id: string,
	SpeakerUserId: number,
	SpeakerName: string,
	SpeakerRole: string,
	PublishedAt: number,
	Message: string,
}

export type GuildLogoRecord = {
	Id: string,
	UploadedBy: number,
	UploadedAt: number,
	Status: "pending" | "approved" | "rejected",
	URL: string?,
	RejectReason: string?,
}

type CommunityDocument = {
	Chat: { GuildChatMessage },
	Announcements: { GuildAnnouncement },
	Logos: { GuildLogoRecord },
	Mutes: { [string]: { MutedBy: number, MutedAt: number } },
	Bans: { [string]: { BannedBy: number, BannedAt: number } },
	Settings: { ChatEnabled: boolean, AnnouncementsEnabled: boolean, LogoEnabled: boolean },
}

local GuildCommunity = {}
GuildCommunity.__index = GuildCommunity

local DEFAULT_SETTINGS = {
	ChatEnabled = true,
	AnnouncementsEnabled = true,
	LogoEnabled = true,
	OfficerAnnouncements = true,
	OfficerModeration = true,
	SlowMode = false,
}
local SLOW_MODE_SECONDS = 6

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[copy(key)] = copy(child) end
	return result
end

local function emptyDocument(): CommunityDocument
	return {
		Chat = {},
		Announcements = {},
		Logos = {},
		Mutes = {},
		Bans = {},
		Settings = table.clone(DEFAULT_SETTINGS),
	}
end

local function normalizeDocument(raw: any): CommunityDocument
	local doc = if type(raw) == "table" then raw else emptyDocument()
	for key, value in emptyDocument() do
		if type(doc[key]) ~= "table" then doc[key] = value end
	end
	for key, value in DEFAULT_SETTINGS do
		if type(doc.Settings[key]) ~= "boolean" then doc.Settings[key] = value end
	end
	return doc :: CommunityDocument
end

local function isMember(guild: any, userId: number): (boolean, string)
	local member = type(guild) == "table" and type(guild.Members) == "table" and guild.Members[tostring(userId)] or nil
	if type(member) ~= "table" then return false, "You are not a member of this guild." end
	local role = if type(member.Role) == "string" then member.Role else "Member"
	return true, role
end

local function canManage(role: string): boolean
	return role == "Leader" or role == "Officer"
end

local function safeGuildAsset(raw: any): string?
	if type(raw) ~= "string" then return nil end
	local id = raw:match("^rbxassetid://(%d+)$") or raw:match("^(%d+)$")
	if not id or #id > 20 or tonumber(id) == nil or tonumber(id) <= 0 then return nil end
	return "rbxassetid://" .. id
end

function GuildCommunity.new(guildService: any, dataService: any, security: any, effect: RemoteEvent, onBanMember: ((Player, string) -> (boolean, any))?)
	local self = setmetatable({}, GuildCommunity)
	self._guilds = guildService
	self._data = dataService
	self._security = security
	self._effect = effect
	self._onBanMember = onBanMember
	self._cache = {} :: { [string]: CommunityDocument }
	self._cacheAt = {} :: { [string]: number }
	self._studio = {} :: { [string]: CommunityDocument }
	self._store = StoreAccess.data(STORE_NAME)
	self._alive = true
	-- guildId -> live subscription, or true while SubscribeAsync is still in flight
	self._relays = {} :: { [string]: RBXScriptConnection | boolean }
	if not StoreAccess.isPreview() then
		task.spawn(function()
			while self._alive do
				self:_reconcileRelays()
				task.wait(RELAY_RECONCILE_SECONDS)
			end
		end)
	end
	return self
end

-- Guilds with at least one member on this server.
function GuildCommunity:_hostedGuilds(): { [string]: boolean }
	local hosted = {}
	for _, player in Players:GetPlayers() do
		local profile = self._data:Get(player)
		local guildId = profile and profile.Guild and profile.Guild.Id
		if type(guildId) == "string" and guildId ~= "" then hosted[guildId] = true end
	end
	return hosted
end

function GuildCommunity:_reconcileRelays()
	local hosted = self:_hostedGuilds()
	for guildId, subscription in self._relays do
		if not hosted[guildId] and typeof(subscription) == "RBXScriptConnection" then
			subscription:Disconnect()
			self._relays[guildId] = nil
		end
	end
	for guildId in hosted do
		local topic = relayTopic(guildId)
		if topic and self._relays[guildId] == nil then
			self._relays[guildId] = true
			task.spawn(function()
				local ok, connection = pcall(function()
					return MessagingService:SubscribeAsync(topic, function(envelope)
						self:_onRelay(if type(envelope) == "table" then envelope.Data else nil)
					end)
				end)
				if not ok then
					self._relays[guildId] = nil -- retried on the next reconcile
				elseif self._alive and self._relays[guildId] == true then
					self._relays[guildId] = connection
				else
					connection:Disconnect()
				end
			end)
		end
	end
end

function GuildCommunity:_read(guildId: string): CommunityDocument?
	local now = os.clock()
	local cached = self._cache[guildId]
	if cached and (self._cacheAt[guildId] or 0) + CACHE_SECONDS > now then return copy(cached) end
	if RunService:IsStudio() and self._studio[guildId] then
		local doc = normalizeDocument(copy(self._studio[guildId]))
		self._cache[guildId], self._cacheAt[guildId] = doc, now
		return copy(doc)
	end
	local ok, raw = pcall(function() return self._store:GetAsync(guildId) end)
	if ok then
		local doc = normalizeDocument(raw)
		self._cache[guildId], self._cacheAt[guildId] = doc, now
		if RunService:IsStudio() then self._studio[guildId] = copy(doc) end
		return copy(doc)
	end
	if cached then return copy(cached) end
	if RunService:IsStudio() then
		local doc = emptyDocument()
		self._studio[guildId], self._cache[guildId], self._cacheAt[guildId] = copy(doc), copy(doc), now
		return copy(doc)
	end
	return nil
end

function GuildCommunity:_update(guildId: string, transform: (CommunityDocument) -> (CommunityDocument?, any)): (boolean, any, CommunityDocument?)
	if not self._alive or guildId == "" then return false, "Guild community is unavailable.", nil end
	local updated: CommunityDocument? = nil
	local resultValue: any = nil
	local callbackError: string? = nil
	local ok, storeError = pcall(function()
		self._store:UpdateAsync(guildId, function(raw)
			updated, resultValue, callbackError = nil, nil, nil
			local nextDoc, value = transform(normalizeDocument(copy(raw)))
			if nextDoc == nil then
				callbackError = if type(value) == "string" then value else "Guild request was denied."
				return nil
			end
			updated, resultValue = normalizeDocument(nextDoc), value
			return updated
		end)
	end)
	if not ok and RunService:IsStudio() then
		local fallback = normalizeDocument(copy(self._studio[guildId] or self._cache[guildId] or emptyDocument()))
		local transformed, value = transform(fallback)
		if transformed then
			updated, resultValue, ok = normalizeDocument(transformed), value, true
			self._studio[guildId] = copy(updated)
		end
	end
	if not ok then return false, "Guild records are unavailable. Try again shortly. " .. tostring(storeError), nil end
	if not updated then return false, callbackError or "Guild request was denied.", nil end
	self._cache[guildId], self._cacheAt[guildId] = copy(updated), os.clock()
	if RunService:IsStudio() then self._studio[guildId] = copy(updated) end
	return true, resultValue, copy(updated)
end

function GuildCommunity:IsBanned(guildId: string, userId: number): boolean
	local doc = self:_read(guildId)
	return doc ~= nil and doc.Bans[tostring(userId)] ~= nil
end

function GuildCommunity:CanJoinByTag(tag: string, userId: number): (boolean, string?)
	local guild = self._guilds:_findByTag(tag)
	if guild == nil then return true, nil end
	local document = self:_read(guild.Id)
	if document == nil then return false, "Guild records are unavailable. Try again shortly." end
	if document.Bans[tostring(userId)] ~= nil then return false, "You are banned from this guild." end
	return true, nil
end

function GuildCommunity:Snapshot(guildId: string): any
	local doc = self:_read(guildId)
	if not doc then return nil end
	local logo = nil
	for index = #doc.Logos, 1, -1 do
		local candidate = doc.Logos[index]
		if candidate.Status == "approved" then logo = copy(candidate); break end
	end
	return { Settings = copy(doc.Settings), Logo = logo }
end

function GuildCommunity:_filter(player: Player, text: string, maxLength: number): (boolean, string?)
	if not self._security or not self._security.Filter or type(text) ~= "string" or #text > maxLength or maxLength > 800 then return false, nil end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if text == "" then return false, nil end
	local callOk, filteredOk, result = pcall(function()
		return self._security.Filter:Apply(player, text, player.UserId, maxLength)
	end)
	if not callOk or filteredOk ~= true or type(result) ~= "string" or result == "" then return false, nil end
	return true, result
end

function GuildCommunity:_localMembers(guildId: string): { Player }
	local members = {}
	for _, recipient in Players:GetPlayers() do
		local profile = self._data:Get(recipient)
		if profile and profile.Guild and profile.Guild.Id == guildId then table.insert(members, recipient) end
	end
	return members
end

function GuildCommunity:_deliver(guildId: string, payload: any, document: CommunityDocument)
	for _, recipient in self:_localMembers(guildId) do
		if document.Bans[tostring(recipient.UserId)] == nil then self._effect:FireClient(recipient, payload) end
	end
end

function GuildCommunity:_publish(guildId: string, payload: any)
	local topic = relayTopic(guildId)
	if topic == nil or StoreAccess.isPreview() then return end
	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode({ Server = game.JobId, GuildId = guildId, Payload = payload })
	end)
	if not okEncode or #encoded > RELAY_MAX_BYTES then
		-- too large to carry (long announcements): other servers re-read the document instead
		encoded = HttpService:JSONEncode({ Server = game.JobId, GuildId = guildId, Refresh = payload.Type })
	end
	task.spawn(function()
		pcall(function() MessagingService:PublishAsync(topic, encoded) end)
	end)
end

function GuildCommunity:_onRelay(raw: any)
	if not self._alive or type(raw) ~= "string" then return end
	local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(data) ~= "table" or data.Server == game.JobId or type(data.GuildId) ~= "string" or data.GuildId == "" then return end
	local guildId = data.GuildId
	-- another server changed this guild: the next read must hit the store
	self._cacheAt[guildId] = 0
	if #self:_localMembers(guildId) == 0 then return end
	local payload = if type(data.Payload) == "table" then data.Payload else { Type = data.Refresh, Refresh = true }
	if type(payload.Type) ~= "string" then return end
	payload.GuildId = guildId
	local document = self._cache[guildId] or self:_read(guildId)
	if document then self:_deliver(guildId, payload, document) end
end

function GuildCommunity:_broadcast(guildId: string, payload: any)
	local document = self:_read(guildId)
	if not document then return end
	self:_deliver(guildId, payload, document)
	self:_publish(guildId, payload)
end

function GuildCommunity:Handle(player: Player, action: string, payload: any)
	local profile = self._data:Get(player)
	if not profile then return { ok = false, error = "Your profile is not ready. Please try again." } end
	local guildId = profile.Guild and profile.Guild.Id or ""
	if guildId == "" then return { ok = false, error = "You are not in a guild." } end
	local guild = self._guilds:GetPublic(guildId)
	if not guild then return { ok = false, error = "Guild records are unavailable. Try again shortly." } end
	local member, role = isMember(guild, player.UserId)
	if not member or self:IsBanned(guildId, player.UserId) then return { ok = false, error = "You are not an active member of this guild." } end
	local document = self:_read(guildId)
	if not document then return { ok = false, error = "Guild records are unavailable. Try again shortly." } end

	if action == "GetGuildSettings" then return { ok = true, Settings = copy(document.Settings) } end
	if action == "GetGuildLogoReview" then
		if role ~= "Leader" then return { ok = false, error = "Only the guild leader can review logos." } end
		local pending = {}
		for _, logo in document.Logos do if logo.Status == "pending" then table.insert(pending, copy(logo)) end end
		return { ok = true, Logos = pending }
	end
	if action == "GetGuildAnnouncements" then
		local announcements = {}
		local endIndex = #document.Announcements
		if type(payload.BeforeId) == "string" then
			for index, entry in document.Announcements do
				if entry.Id == payload.BeforeId then endIndex = index - 1; break end
			end
		end
		local limit = math.clamp(math.floor(tonumber(payload.Limit) or 50), 1, 50)
		for index = endIndex, math.max(1, endIndex - limit + 1), -1 do
			local entry = document.Announcements[index]
			if entry and not entry.Archived and (entry.ExpiresAt == nil or entry.ExpiresAt > os.time()) then table.insert(announcements, copy(entry)) end
		end
		table.sort(announcements, function(left, right)
			if left.Pinned ~= right.Pinned then return left.Pinned end
			return left.PublishedAt > right.PublishedAt
		end)
		return { ok = true, Announcements = announcements }
	end
	if action == "GetGuildChatHistory" then
		local messages = {}
		local limit = math.clamp(math.floor(tonumber(payload.Limit) or 50), 1, 50)
		local endIndex = #document.Chat
		if type(payload.BeforeId) == "string" then
			for index, entry in document.Chat do if entry.Id == payload.BeforeId then endIndex = index - 1; break end end
		end
		for index = math.max(1, endIndex - limit + 1), endIndex do table.insert(messages, copy(document.Chat[index])) end
		return { ok = true, Messages = messages }
	end
	if action == "SendGuildChat" then
		if document.Settings.ChatEnabled ~= true then return { ok = false, error = "Guild chat is disabled." } end
		if document.Mutes[tostring(player.UserId)] then return { ok = false, error = "You are muted in this guild." } end
		if document.Settings.SlowMode == true and role ~= "Leader" then
			self._chatAt = self._chatAt or {}
			local key = guildId .. ":" .. tostring(player.UserId)
			local last = self._chatAt[key] or 0
			if os.clock() - last < SLOW_MODE_SECONDS then
				return { ok = false, error = `Slow mode is on. Wait {math.ceil(SLOW_MODE_SECONDS - (os.clock() - last))}s.` }
			end
			self._chatAt[key] = os.clock()
		end
		local filteredOk, filtered = self:_filter(player, type(payload.Content) == "string" and payload.Content or "", 800)
		if not filteredOk or not filtered then return { ok = false, error = "That message could not be checked. Please try different wording." } end
		local message: GuildChatMessage = {
			Id = HttpService:GenerateGUID(false),
			SpeakerUserId = player.UserId,
			SpeakerName = player.DisplayName ~= "" and player.DisplayName or player.Name,
			SpeakerRole = role,
			PublishedAt = os.time(),
			Message = filtered,
		}
		local saved, result = self:_update(guildId, function(doc)
			if doc.Settings.ChatEnabled ~= true or doc.Mutes[tostring(player.UserId)] ~= nil or doc.Bans[tostring(player.UserId)] ~= nil then return nil, "Chat is unavailable for your account." end
			table.insert(doc.Chat, message)
			while #doc.Chat > CHAT_LIMIT do table.remove(doc.Chat, 1) end
			return doc, message
		end)
		if not saved then return { ok = false, error = result } end
		self:_broadcast(guildId, { Type = "GuildChat", GuildId = guildId, Message = message })
		return { ok = true, message = "Guild message sent.", Message = message }
	end

	if action == "SetGuildSettings" then
		if role ~= "Leader" then return { ok = false, error = "Only the guild leader can change guild settings." } end
		local requested = if type(payload.Settings) == "table" then payload.Settings else {}
		local saved, result = self:_update(guildId, function(doc)
			for key, value in requested do
				if DEFAULT_SETTINGS[key] ~= nil and type(value) == "boolean" then doc.Settings[key] = value end
			end
			return doc, copy(doc.Settings)
		end)
		if not saved then return { ok = false, error = result } end
		self:_broadcast(guildId, { Type = "GuildSettings", GuildId = guildId, Settings = result })
		return { ok = true, message = "Guild settings saved.", Settings = result }
	end

	if action == "CreateGuildAnnouncement" or action == "EditGuildAnnouncement" then
		if not canManage(role) then return { ok = false, error = "Only leaders and officers can manage announcements." } end
		if role == "Officer" and document.Settings.OfficerAnnouncements == false then return { ok = false, error = "The leader has reserved announcements for themselves." } end
		if document.Settings.AnnouncementsEnabled ~= true then return { ok = false, error = "Guild announcements are disabled." } end
		local titleOk, title = self:_filter(player, type(payload.Title) == "string" and payload.Title or "", 120)
		local bodyOk, body = self:_filter(player, type(payload.Body) == "string" and payload.Body or "", 800)
		if not titleOk or not bodyOk or not title or not body then return { ok = false, error = "That announcement could not be checked. Please try different wording." } end
		local announcementId = if action == "CreateGuildAnnouncement" then HttpService:GenerateGUID(false) else payload.AnnouncementId
		local saved, result = self:_update(guildId, function(doc)
			if doc.Settings.AnnouncementsEnabled ~= true then return nil, "Guild announcements are disabled." end
			local announcement = nil
			for _, existing in doc.Announcements do if existing.Id == announcementId then announcement = existing; break end end
			if action == "CreateGuildAnnouncement" then
				announcement = { Id = announcementId, AuthorUserId = player.UserId, AuthorName = player.DisplayName ~= "" and player.DisplayName or player.Name, AuthorRole = role, PublishedAt = os.time(), Pinned = false, Archived = false, Title = title, Body = body }
				table.insert(doc.Announcements, announcement)
				while #doc.Announcements > ANNOUNCEMENT_LIMIT do table.remove(doc.Announcements, 1) end
			else
				if not announcement then return nil, "Announcement not found." end
				announcement.Title, announcement.Body, announcement.EditedAt = title, body, os.time()
			end
			return doc, copy(announcement)
		end)
		if not saved then return { ok = false, error = result } end
		self:_broadcast(guildId, { Type = "GuildAnnouncement", GuildId = guildId, Action = action == "CreateGuildAnnouncement" and "Created" or "Edited", Announcement = result })
		return { ok = true, message = action == "CreateGuildAnnouncement" and "Guild announcement published." or "Guild announcement updated.", Announcement = result }
	end

	if action == "PinGuildAnnouncement" or action == "ArchiveGuildAnnouncement" or action == "SetGuildAnnouncementExpiry" then
		if not canManage(role) then return { ok = false, error = "Only leaders and officers can manage announcements." } end
		if role == "Officer" and document.Settings.OfficerAnnouncements == false then return { ok = false, error = "The leader has reserved announcements for themselves." } end
		if action == "SetGuildAnnouncementExpiry" and payload.ExpiresAt ~= nil and payload.ExpiresAt <= os.time() then return { ok = false, error = "Expiry must be a future timestamp or omitted." } end
		local saved, result = self:_update(guildId, function(doc)
			for _, announcement in doc.Announcements do
				if announcement.Id == payload.AnnouncementId then
					if action == "PinGuildAnnouncement" then announcement.Pinned = payload.Pinned ~= false
					elseif action == "ArchiveGuildAnnouncement" then announcement.Archived = true
					else announcement.ExpiresAt = payload.ExpiresAt end
					return doc, copy(announcement)
				end
			end
			return nil, "Announcement not found."
		end)
		if not saved then return { ok = false, error = result } end
		self:_broadcast(guildId, { Type = "GuildAnnouncement", GuildId = guildId, Action = action, Announcement = result })
		return { ok = true, Announcement = result }
	end

	if action == "MuteGuildMember" or action == "UnmuteGuildMember" or action == "BanGuildMember" or action == "UnbanGuildMember" then
		if not canManage(role) then return { ok = false, error = "Only leaders and officers can moderate members." } end
		if role == "Officer" and document.Settings.OfficerModeration == false then return { ok = false, error = "The leader has reserved moderation for themselves." } end
		local targetId = tonumber(payload.UserId)
		if not targetId or targetId <= 0 or targetId == player.UserId then return { ok = false, error = "That member cannot be moderated." } end
		local target = guild.Members[tostring(targetId)]
		local isBan = action == "BanGuildMember" or action == "UnbanGuildMember"
		local remove = action == "UnmuteGuildMember" or action == "UnbanGuildMember"
		local targetHasBan = document.Bans[tostring(targetId)] ~= nil
		if (not target and not (action == "UnbanGuildMember" and targetHasBan)) or (target and target.Role == "Leader") or (role == "Officer" and target ~= nil and target.Role ~= "Member") then return { ok = false, error = "That member cannot be moderated." } end
		if action == "UnbanGuildMember" and not targetHasBan then return { ok = false, error = "That member is not guild-banned." } end
		local saved, result = self:_update(guildId, function(doc)
			if isBan and action == "BanGuildMember" and doc.Bans[tostring(targetId)] ~= nil then return nil, "That member is already guild-banned." end
			local key = tostring(targetId)
			local tableToUpdate = if isBan then doc.Bans else doc.Mutes
			if remove then tableToUpdate[key] = nil else tableToUpdate[key] = { [if isBan then "BannedBy" else "MutedBy"] = player.UserId, [if isBan then "BannedAt" else "MutedAt"] = os.time() } end
			return doc, true
		end)
		if not saved then return { ok = false, error = result } end
		if action == "BanGuildMember" then
			local removed, removeError = self._guilds:_update(guildId, function(current)
				if not current.Members[tostring(targetId)] then return current end
				current.Members[tostring(targetId)] = nil
				return current
			end)
			if not removed then return { ok = false, error = removeError or "Guild ban saved, but membership could not be removed." } end
			local targetPlayer = Players:GetPlayerByUserId(targetId)
			if targetPlayer and self._onBanMember then
				local cleared, clearResult = self._onBanMember(targetPlayer, guildId)
				if not cleared then return { ok = false, error = "Ban was saved, but the member profile could not be refreshed: " .. tostring(clearResult) } end
			end
		end
		self:_broadcast(guildId, { Type = "GuildModeration", GuildId = guildId, Action = action, TargetUserId = targetId })
		return { ok = true, message = "Guild moderation updated." }
	end

	if action == "UploadGuildLogo" then
		if not canManage(role) then return { ok = false, error = "Only leaders and officers can submit guild logos." } end
		if document.Settings.LogoEnabled ~= true then return { ok = false, error = "Guild logos are disabled." } end
		local asset = safeGuildAsset(payload.URL)
		if not asset then return { ok = false, error = "Use a Roblox image asset ID. Roblox platform moderation still applies." } end
		local logo = { Id = HttpService:GenerateGUID(false), UploadedBy = player.UserId, UploadedAt = os.time(), Status = "pending", URL = asset }
		local saved, result = self:_update(guildId, function(doc)
			table.insert(doc.Logos, logo)
			while #doc.Logos > LOGO_HISTORY_LIMIT do table.remove(doc.Logos, 1) end
			return doc, copy(logo)
		end)
		if not saved then return { ok = false, error = result } end
		self:_broadcast(guildId, { Type = "GuildLogo", GuildId = guildId, Action = "Uploaded", Logo = result })
		return { ok = true, message = "Guild logo submitted for leader review.", Logo = result }
	end

	if action == "ModerateGuildLogo" then
		if role ~= "Leader" then return { ok = false, error = "Only the guild leader can review logos." } end
		if payload.Decision ~= "approved" and payload.Decision ~= "rejected" then return { ok = false, error = "Choose approve or reject." } end
		local reason = nil
		if payload.Decision == "rejected" then
			-- the reason is broadcast to every member, so it goes through the text filter
			local reasonOk, filteredReason = self:_filter(player, type(payload.Reason) == "string" and payload.Reason or "", 500)
			if not reasonOk or not filteredReason then return { ok = false, error = "A rejection reason is required (and must pass the chat filter)." } end
			reason = filteredReason
		end
		local pendingLogo = nil
		for _, logo in document.Logos do
			if logo.Id == payload.LogoId and logo.Status == "pending" then pendingLogo = copy(logo); break end
		end
		if not pendingLogo then return { ok = false, error = "Pending logo not found." } end
		local saved, result = self:_update(guildId, function(doc)
			for _, logo in doc.Logos do
				if logo.Id == payload.LogoId and logo.Status == "pending" then
					logo.Status = payload.Decision
					logo.RejectReason = reason
					return doc, copy(logo)
				end
			end
			return nil, "Pending logo not found."
		end)
			if not saved then return { ok = false, error = result } end
		self:_broadcast(guildId, { Type = "GuildLogo", GuildId = guildId, Action = "Moderated", Logo = result })
		return { ok = true, message = payload.Decision == "approved" and "Guild logo approved." or "Guild logo rejected.", Logo = result }
	end

	if action == "RenameGuild" then
		if role ~= "Leader" then return { ok = false, error = "Only the guild leader can change the guild name." } end
		local newName = if type(payload.NewName) == "string" then string.gsub(payload.NewName, "^%s*(.-)%s*$", "%1") else ""
		if #newName < 3 or #newName > 24 then
			return { ok = false, error = "Guild name must be between 3 and 24 characters." }
		end
		local updated, updateError = self._guilds:_update(guildId, function(current)
			current.Name = newName
			return current
		end)
		if not updated then return { ok = false, error = updateError or "Could not update guild name." } end
		self:_broadcast(guildId, { Type = "GuildRenamed", GuildId = guildId, NewName = newName })
		return { ok = true, message = "Guild name updated successfully.", NewName = newName }
	end

	return { ok = false, error = "Unknown guild community action." }
end

function GuildCommunity:Shutdown()
	self._alive = false
	for _, subscription in self._relays do
		if typeof(subscription) == "RBXScriptConnection" then subscription:Disconnect() end
	end
	table.clear(self._relays)
	table.clear(self._cache)
	table.clear(self._cacheAt)
	table.clear(self._studio)
end

return table.freeze(GuildCommunity)
