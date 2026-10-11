--!strict
-- Crews: small parties inside this server (see Shared/CrewMath for the rules).
-- Server-local by design: a crew lives as long as two members share the server. Only the
-- per-player daily claim record persists (profile.Flags.CrewDay / CrewClaimed).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local shared = ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared")
local CrewMath = require(shared:WaitForChild("CrewMath"))
local ChatRules = require(shared:WaitForChild("ChatRules"))

type Crew = {
	Id: string,
	Name: string,
	Leader: number,
	Members: { number },
	Day: number,
	Pooled: number,
	Contribution: { [number]: number },
	Channel: TextChannel?,
}

local CrewService = {}
CrewService.__index = CrewService

local function fail(message: string)
	return { ok = false, error = message }
end

function CrewService.new(effect: RemoteEvent, data: any)
	local self = setmetatable({}, CrewService)
	self._effect = effect
	self._data = data
	self._alive = true
	self._crews = {} :: { [string]: Crew }
	self._memberOf = {} :: { [number]: string }
	self._invites = {} :: { [number]: { FromUserId: number, ExpiresAt: number } }
	self._removing = Players.PlayerRemoving:Connect(function(player)
		self._invites[player.UserId] = nil
		self:_leave(player.UserId, "left the server")
	end)
	return self
end

function CrewService:_crewOf(userId: number): Crew?
	local id = self._memberOf[userId]
	return if id then self._crews[id] else nil
end

function CrewService:_rollDay(crew: Crew)
	local today = CrewMath.dayOf(os.time())
	if crew.Day ~= today then
		crew.Day = today
		crew.Pooled = 0
		crew.Contribution = {}
	end
end

function CrewService:_snapshot(crew: Crew, viewer: number): any
	self:_rollDay(crew)
	local members = {}
	for _, userId in crew.Members do
		local player = Players:GetPlayerByUserId(userId)
		table.insert(members, {
			UserId = userId,
			Name = if player then player.Name else tostring(userId),
			DisplayName = if player then player.DisplayName else tostring(userId),
			Leader = userId == crew.Leader,
			Collects = crew.Contribution[userId] or 0,
			Zone = if player then player:GetAttribute("CurrentZone") else nil,
		})
	end
	local profile = Players:GetPlayerByUserId(viewer) and self._data:Get(Players:GetPlayerByUserId(viewer))
	local record = CrewMath.normalizeRecord(profile and profile.Flags and profile.Flags.CrewDay,
		profile and profile.Flags and profile.Flags.CrewClaimed, crew.Day)
	local tiers = {}
	for index, tier in CrewMath.GOAL_TIERS do
		tiers[index] = { Target = tier.Target, Stardust = tier.Stardust, Claimed = CrewMath.isClaimed(record, index) }
	end
	return {
		Id = crew.Id,
		Name = crew.Name,
		Leader = crew.Leader,
		Members = members,
		Max = CrewMath.MAX_MEMBERS,
		Bonus = CrewMath.multiplier(#crew.Members) - 1,
		Pooled = crew.Pooled,
		Tiers = tiers,
		MinContribution = CrewMath.MIN_CONTRIBUTION,
		Channel = ChatRules.crewChannel(crew.Id),
	}
end

function CrewService:_push(crew: Crew)
	for _, userId in crew.Members do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self._effect:FireClient(player, { Type = "CrewState", Crew = self:_snapshot(crew, userId) })
		end
	end
end

function CrewService:_notify(userId: number, payload: any)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		self._effect:FireClient(player, payload)
	end
end

-- Private crew chat: a TextChannel whose only sources are the members.
function CrewService:_openChannel(crew: Crew)
	local channels = TextChatService:FindFirstChild("TextChannels")
	if channels == nil then return end
	local channel = Instance.new("TextChannel")
	channel.Name = ChatRules.crewChannel(crew.Id)
	channel.Parent = channels
	crew.Channel = channel
	for _, userId in crew.Members do
		task.spawn(function() pcall(function() channel:AddUserAsync(userId) end) end)
	end
end

function CrewService:_dropFromChannel(crew: Crew, userId: number)
	local channel = crew.Channel
	if channel == nil then return end
	for _, source in channel:GetChildren() do
		if source:IsA("TextSource") and source.UserId == userId then
			source:Destroy()
		end
	end
end

function CrewService:_disband(crew: Crew, reason: string)
	for _, userId in crew.Members do
		self._memberOf[userId] = nil
		self:_notify(userId, { Type = "CrewState", Crew = nil, Reason = reason })
	end
	if crew.Channel then crew.Channel:Destroy() end
	self._crews[crew.Id] = nil
end

function CrewService:_leave(userId: number, reason: string)
	local crew = self:_crewOf(userId)
	if crew == nil then return end
	local index = table.find(crew.Members, userId)
	if index then table.remove(crew.Members, index) end
	self._memberOf[userId] = nil
	self:_dropFromChannel(crew, userId)
	self:_notify(userId, { Type = "CrewState", Crew = nil, Reason = reason })
	if #crew.Members < 2 then
		self:_disband(crew, "Your crew disbanded.")
		return
	end
	if crew.Leader == userId then
		crew.Leader = crew.Members[1] -- the longest-standing member leads next
	end
	self:_push(crew)
end

function CrewService:_filterName(player: Player, raw: string): string?
	local name = CrewMath.cleanName(raw)
	if name == nil then return nil end
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(filtered) == "string" and filtered ~= "" then filtered else nil
end

function CrewService:_create(player: Player, name: string?): Crew
	local crew: Crew = {
		Id = string.sub(HttpService:GenerateGUID(false), 1, 8),
		Name = name or `{player.DisplayName}'s crew`,
		Leader = player.UserId,
		Members = { player.UserId },
		Day = CrewMath.dayOf(os.time()),
		Pooled = 0,
		Contribution = {},
		Channel = nil,
	}
	self._crews[crew.Id] = crew
	self._memberOf[player.UserId] = crew.Id
	self:_openChannel(crew)
	return crew
end

function CrewService:Get(player: Player)
	local crew = self:_crewOf(player.UserId)
	local invite = self._invites[player.UserId]
	if invite and invite.ExpiresAt < os.time() then
		self._invites[player.UserId] = nil
		invite = nil
	end
	local from = invite and Players:GetPlayerByUserId(invite.FromUserId)
	return {
		ok = true,
		Crew = if crew then self:_snapshot(crew, player.UserId) else nil,
		Invite = if from then { FromUserId = from.UserId, FromName = from.DisplayName, ExpiresAt = invite.ExpiresAt } else nil,
	}
end

function CrewService:Invite(player: Player, payload: any)
	local targetId = if type(payload) == "table" then tonumber(payload.UserId) else nil
	local target = targetId and Players:GetPlayerByUserId(targetId)
	if target == nil or target == player then return fail("Pick another player in this server.") end
	if self._memberOf[target.UserId] then return fail(`{target.DisplayName} is already in a crew.`) end
	local crew = self:_crewOf(player.UserId)
	if crew and crew.Leader ~= player.UserId then return fail("Only the crew leader can invite.") end
	if crew and #crew.Members >= CrewMath.MAX_MEMBERS then return fail(`Crews hold {CrewMath.MAX_MEMBERS} players.`) end
	-- the target's Social setting decides who may invite them
	local targetProfile = self._data:Get(target)
	local policy = targetProfile and targetProfile.Settings and targetProfile.Settings.CrewInvitePolicy
	if type(policy) == "number" and policy >= 0.25 then
		local okFriend, isFriend = pcall(function() return target:IsFriendsWith(player.UserId) end)
		if not ChatRules.allows(policy, okFriend and isFriend == true) then
			return fail(if policy >= 0.75 then `{target.DisplayName} isn't taking crew invites.` else `{target.DisplayName} only takes crew invites from friends.`)
		end
	end
	local existing = self._invites[target.UserId]
	if existing and existing.ExpiresAt > os.time() and existing.FromUserId ~= player.UserId then
		return fail(`{target.DisplayName} already has an invite waiting.`)
	end
	self._invites[target.UserId] = { FromUserId = player.UserId, ExpiresAt = os.time() + CrewMath.INVITE_SECONDS }
	self._effect:FireClient(target, {
		Type = "CrewInvite", FromUserId = player.UserId, FromName = player.DisplayName,
		CrewName = if crew then crew.Name else `{player.DisplayName}'s crew`, ExpiresAt = os.time() + CrewMath.INVITE_SECONDS,
	})
	return { ok = true, message = `Invite sent to {target.DisplayName}.` }
end

function CrewService:Respond(player: Player, payload: any)
	local invite = self._invites[player.UserId]
	self._invites[player.UserId] = nil
	local accept = type(payload) == "table" and payload.Accept == true
	if invite == nil or invite.ExpiresAt < os.time() then return fail("That invite expired.") end
	local inviter = Players:GetPlayerByUserId(invite.FromUserId)
	if inviter == nil then return fail("They left the server.") end
	if not accept then
		self:_notify(inviter.UserId, { Type = "CrewNotice", Text = `{player.DisplayName} declined your crew invite.` })
		return { ok = true, message = "Invite declined." }
	end
	if self._memberOf[player.UserId] then return fail("Leave your current crew first.") end
	local crew = self:_crewOf(inviter.UserId)
	if crew == nil then
		crew = self:_create(inviter, nil)
	elseif crew.Leader ~= inviter.UserId then
		return fail("That invite is no longer valid.")
	end
	if #crew.Members >= CrewMath.MAX_MEMBERS then return fail("That crew is full.") end
	table.insert(crew.Members, player.UserId)
	self._memberOf[player.UserId] = crew.Id
	if crew.Channel then
		task.spawn(function() pcall(function() (crew.Channel :: TextChannel):AddUserAsync(player.UserId) end) end)
	end
	self:_push(crew)
	return { ok = true, message = `You joined {crew.Name}.` }
end

function CrewService:Leave(player: Player)
	if self._memberOf[player.UserId] == nil then return fail("You're not in a crew.") end
	self:_leave(player.UserId, "You left the crew.")
	return { ok = true, message = "You left the crew." }
end

function CrewService:Kick(player: Player, payload: any)
	local crew = self:_crewOf(player.UserId)
	local targetId = if type(payload) == "table" then tonumber(payload.UserId) else nil
	if crew == nil or crew.Leader ~= player.UserId then return fail("Only the crew leader can remove members.") end
	if targetId == nil or targetId == player.UserId or not table.find(crew.Members, targetId) then
		return fail("That player isn't in your crew.")
	end
	self:_leave(targetId, "You were removed from the crew.")
	return { ok = true, message = "Removed from the crew." }
end

function CrewService:Rename(player: Player, payload: any)
	local crew = self:_crewOf(player.UserId)
	if crew == nil or crew.Leader ~= player.UserId then return fail("Only the crew leader can rename the crew.") end
	local name = self:_filterName(player, if type(payload) == "table" then payload.Name else nil)
	if name == nil then return fail("Crew names need 2 to 20 characters.") end
	crew.Name = name
	self:_push(crew)
	return { ok = true, message = `Crew renamed to {name}.` }
end

function CrewService:RecordCollect(player: Player)
	local crew = self:_crewOf(player.UserId)
	if crew == nil then return end
	self:_rollDay(crew)
	local before = CrewMath.tierReached(crew.Pooled)
	crew.Pooled += 1
	crew.Contribution[player.UserId] = (crew.Contribution[player.UserId] or 0) + 1
	local after = CrewMath.tierReached(crew.Pooled)
	if after > before then
		for _, userId in crew.Members do
			self:_notify(userId, { Type = "CrewNotice", Text = `Crew goal {after} reached. Claim it on the Crew page.` })
		end
	end
	self:_push(crew)
end

function CrewService:Claim(player: Player, payload: any)
	local crew = self:_crewOf(player.UserId)
	if crew == nil then return fail("Join a crew to share crew goals.") end
	self:_rollDay(crew)
	local tier = if type(payload) == "table" then math.floor(tonumber(payload.Tier) or 0) else 0
	local pooled, contribution, today = crew.Pooled, crew.Contribution[player.UserId] or 0, crew.Day
	local ok, result = self._data:AtomicUpdate(player, function(profile)
		profile.Flags = profile.Flags or {}
		local record = CrewMath.normalizeRecord(profile.Flags.CrewDay, profile.Flags.CrewClaimed, today)
		local allowed, reason = CrewMath.canClaim(record, tier, pooled, contribution)
		if not allowed then return fail(reason or "You can't claim that yet.") end
		record = CrewMath.markClaimed(record, tier)
		profile.Flags.CrewDay, profile.Flags.CrewClaimed = record.Day, record.Claimed
		local reward = CrewMath.GOAL_TIERS[tier].Stardust
		profile.Stardust = (tonumber(profile.Stardust) or 0) + reward
		return { ok = true, message = `+{reward} stardust from the crew goal.`, Stardust = reward }
	end, true, "crew-claim")
	if not ok then return fail("Couldn't save that claim. Try again.") end
	if type(result) == "table" and result.ok then self:_push(crew) end
	return result
end

function CrewService:Multiplier(player: Player): number
	local crew = self:_crewOf(player.UserId)
	return if crew then CrewMath.multiplier(#crew.Members) else 1
end

function CrewService:Shutdown()
	self._alive = false
	self._removing:Disconnect()
end

return table.freeze(CrewService)
