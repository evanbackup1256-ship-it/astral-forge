--!strict

return function()

	local DataStoreService = game:GetService("DataStoreService")
	local RunService = game:GetService("RunService")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
	local LeaderboardCodec = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("LeaderboardCodec"))
	local GuildMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("GuildMath"))
	local GuildGoalMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("GuildGoalMath"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))

	local GuildService = {}
	GuildService.__index = GuildService

	local function finiteNonNegative(value): number
		return GuildMath.FiniteNonNegative(value)
	end

	local function copy(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, child in value do result[key] = copy(child) end
		return result
	end

	local function normalTag(tag: string): string
		return string.upper(tag:gsub("%s+", ""))
	end

	-- Tiered upgrades via GuildMath: named Tiers then endless BaseCost/CostScale /
	-- EffectPerLevel tail so pre-tier guild documents keep the same costs and bonuses.
	local function upgradeCost(definition, level: number): number
		return GuildMath.UpgradeCost(definition, level)
	end

	local function upgradeEffect(definition, level: number): number
		return GuildMath.UpgradeEffect(definition, level)
	end

	--#region Guild Goal
	-- A guild's rotating co-op objective. Stored on the guild document as `Goal`.
	-- Guild documents that predate this field get one lazily via EnsureGoal
	-- (GuildGoalMath) — an old guild simply rolls its first goal the next time
	-- it is touched. Claimed/Contributors rebuilds must persist (EnsureGoal
	-- returns true) so ClaimGoal deny paths no longer drop repaired bags.
	local function goalTypeById(typeId: string)
		return GuildGoalMath.GoalTypeById(GameConfig.Guild.Goal.Types, typeId)
	end

	local function ensureGoal(guild, now: number): boolean
		return GuildGoalMath.EnsureGoal(guild, now, GameConfig.Guild.Goal)
	end

	local function advanceGoal(guild, userKey: string, metric: string, amount: number, now: number)
		GuildGoalMath.AdvanceGoal(guild, userKey, metric, amount, now, GameConfig.Guild.Goal)
	end
	--#endregion

	-- Bonus keys are owned by GuildMath so new categories stay a config-only change
	-- (every key must still be one Economy already reads).
	local function emptyBonuses()
		return GuildMath.EmptyBonuses()
	end

	local function bonusesFromDocument(guild)
		if not guild then
			return emptyBonuses()
		end
		return GuildMath.BonusesFromUpgrades(guild.Upgrades, GameConfig.Guild.Upgrades)
	end

	function GuildService.new()
		local self = setmetatable({}, GuildService)
		self._cache = {}
		self._cacheExpiry = {}
		self._cachePruneAt = 0
		self._studio = {}
		self._store = DataStoreService:GetDataStore(ServerConfig.GuildStoreName)
		self._leaderboard = DataStoreService:GetOrderedDataStore(ServerConfig.GuildLeaderboardStoreName)
		self._leaderboardPending = {}
		self._leaderboardBusy = {}
		self._leaderboardCache = nil
		self._leaderboardCacheExpires = 0
		self._warmQueue = {}
		self._warmQueued = {}
		self._warmWorkers = 0
		self._running = true
		self._workers = {}
		return self
	end

	function GuildService:_spawnWorker(callback)
		if not self._running then return nil end
		local token = {}
		local worker = task.defer(function()
			if self._running then callback() end
			self._workers[token] = nil
		end)
		self._workers[token] = worker
		return worker
	end


	function GuildService:_queueWarmRead(id: string)
		if not self._running then return end
		if self._cache[id] or self._studio[id] or self._warmQueued[id] then return end
		self._warmQueued[id] = true
		table.insert(self._warmQueue, id)
		while self._warmWorkers < 2 and #self._warmQueue > 0 do
			self._warmWorkers += 1
			self:_spawnWorker(function()
				while self._running and #self._warmQueue > 0 do
					local nextId = table.remove(self._warmQueue, 1)
					if nextId then
						self:_read(nextId)
						self._warmQueued[nextId] = nil
						self._leaderboardCacheExpires = 0
					end
				end
				self._warmWorkers -= 1
			end)
		end
	end


	function GuildService:_queueLeaderboard(id: string, activity: number)
		if not self._running then return end
		self._leaderboardPending[id] = LeaderboardCodec.Encode(activity)
		if self._leaderboardBusy[id] then return end
		self._leaderboardBusy[id] = true
		self:_spawnWorker(function()
			while self._running and self._leaderboardPending[id] ~= nil do
				local encoded = self._leaderboardPending[id]
				self._leaderboardPending[id] = nil
				pcall(function()
					self._leaderboard:SetAsync(id, encoded)
				end)
			end
			self._leaderboardBusy[id] = nil
		end)
	end

	function GuildService:Destroy()
		if not self._running then return end
		self._running = false
		for _, worker in self._workers do
			pcall(task.cancel, worker)
		end
		table.clear(self._workers)
		table.clear(self._warmQueue)
		table.clear(self._warmQueued)
		table.clear(self._leaderboardPending)
		table.clear(self._leaderboardBusy)
		self._warmWorkers = 0
	end

	function GuildService:_pruneCache()
		local now = os.clock()
		if now < self._cachePruneAt then return end
		self._cachePruneAt = now + 30
		for id, expiresAt in self._cacheExpiry do
			if type(expiresAt) ~= "number" or expiresAt <= now then
				self._cacheExpiry[id] = nil
				self._cache[id] = nil
			end
		end
	end

	function GuildService:_read(id: string)
		self:_pruneCache()
		if RunService:IsStudio() and self._studio[id] then return copy(self._studio[id]) end
		local cached = self._cache[id]
		if cached and (self._cacheExpiry[id] or 0) > os.clock() then return copy(cached) end
		local ok, result = pcall(function() return self._store:GetAsync(id) end)
		if ok and type(result) == "table" then
			self._cache[id] = result
			self._cacheExpiry[id] = os.clock() + 60
			return copy(result)
		end

		if cached then return copy(cached) end
		return nil
	end

	function GuildService:_update(id: string, transform)
		local updated
		local function apply(current)
			local doc = type(current) == "table" and current or self._studio[id] or self._cache[id]
			if type(doc) ~= "table" then return nil end
			local nextDoc = transform(copy(doc))

			if nextDoc == nil then
				updated = nil
				return doc
			end
			updated = nextDoc
			return nextDoc
		end
		local ok, err = pcall(function()
			return self._store:UpdateAsync(id, apply)
		end)
		if not ok then

			if not RunService:IsStudio() then
				return false, tostring(err), nil
			end
			local fallback = self._studio[id] or self._cache[id]
			if type(fallback) == "table" then
				updated = transform(copy(fallback))
				if type(updated) == "table" then
					self._studio[id] = updated
				end
			else
				return false, tostring(err), nil
			end
		end
		if type(updated) ~= "table" then return false, "Guild request was denied.", nil end
		self._cache[id] = updated
		self._cacheExpiry[id] = os.clock() + 60
		if RunService:IsStudio() then self._studio[id] = updated end
		self:_queueLeaderboard(id, updated.Activity)
		return true, nil, copy(updated)
	end

	function GuildService:_findByTag(tag: string)
		self:_pruneCache()
		local wanted = normalTag(tag)
		for _, doc in self._cache do
			if doc.Tag == wanted then return copy(doc) end
		end
		for _, doc in self._studio do
			if doc.Tag == wanted then return copy(doc) end
		end

		local ok, id = pcall(function() return self._store:GetAsync("tag:" .. wanted) end)
		if ok and type(id) == "string" then return self:_read(id) end
		return nil
	end

	function GuildService:Create(player, profile, rawName: string, rawTag: string)
		if profile.Guild and profile.Guild.Id ~= "" then
			local existing = self:GetCachedPublic(profile.Guild.Id) or self:GetPublic(profile.Guild.Id)
			if existing then return true, "You're already in this guild.", existing end
			return false, "Leave your current guild first."
		end
		local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
		local tag = normalTag(rawTag)
		if #name < 3 or #name > 28 or not string.match(name, "^[%w%s%-_]+$") then return false, "Guild names must be 3–28 letters, numbers, spaces, - or _." end
		if #tag < 3 or #tag > 4 or not string.match(tag, "^[A-Z0-9]+$") then return false, "Guild tags must be 3–4 letters or numbers." end
		if OmegaMath.Lt(profile.Cash, GameConfig.Guild.CreateCost) then return false, "You need more flux to charter a guild." end
		if self:_findByTag(tag) then return false, "That guild tag is already in use." end
		local id = HttpService:GenerateGUID(false)
		local doc = {
			Id = id, Name = name, Tag = tag, Level = 1, XP = 0, Activity = 0, BankCash = 0, BankDust = 0,
			Members = { [tostring(player.UserId)] = { Name = (player.DisplayName ~= "" and player.DisplayName) or player.Name, Role = "Leader", JoinedAt = os.time(), Contributed = 0 } },
			Upgrades = {}, CreatedAt = os.time(), OwnerUserId = player.UserId,
		}
		ensureGoal(doc, os.time())
		local documentCreated = false
		local tagClaimed = false
		local ok = pcall(function()
			self._store:UpdateAsync(id, function(existing)
				if existing ~= nil then return existing end
				documentCreated = true
				return doc
			end)
			if not documentCreated then error("generated guild id already exists") end
			self._store:UpdateAsync("tag:" .. tag, function(existing)
				if existing == nil or existing == id then
					tagClaimed = true
					return id
				end
				return existing
			end)
		end)
		if not RunService:IsStudio() and (not ok or not documentCreated or not tagClaimed) then

			if documentCreated and not tagClaimed then
				pcall(function() self._store:RemoveAsync(id) end)
			end
			if not ok then return false, "Guild records are unavailable. Try again shortly." end
			return false, "That guild tag is already in use."
		end
		self._cache[id] = doc
		if RunService:IsStudio() then self._studio[id] = doc end
		self._cacheExpiry[id] = os.clock() + 60
		profile.Cash = OmegaMath.Sub(profile.Cash, GameConfig.Guild.CreateCost)
		profile.Guild = { Id = id, Role = "Leader", JoinedAt = os.time(), Tag = tag }
		return true, "Guild Hall chartered.", copy(doc)
	end

	function GuildService:JoinByTag(player, profile, rawTag: string)
		if profile.Guild and profile.Guild.Id ~= "" then
			local existing = self:GetCachedPublic(profile.Guild.Id) or self:GetPublic(profile.Guild.Id)
			if existing then return true, "You're already in this guild.", existing end
			return false, "Leave your current guild first."
		end
		local doc = self:_findByTag(rawTag)
		if not doc then return false, "No guild has that tag." end
		-- UpdateAsync transform returning nil is a generic denial; track fullness so the
		-- player sees "full" instead of "Guild request was denied."
		local blockedFull = false
		local ok, message, updated = self:_update(doc.Id, function(guild)
			local key = tostring(player.UserId)
			if guild.Members[key] then return guild end
			local count = 0; for _ in guild.Members do count += 1 end
			if count >= GameConfig.Guild.MaxMembers then
				blockedFull = true
				return nil
			end
			guild.Members[key] = { Name = (player.DisplayName ~= "" and player.DisplayName) or player.Name, Role = "Member", JoinedAt = os.time(), Contributed = 0 }
			return guild
		end)
		if not ok then
			if blockedFull then return false, "That guild is full." end
			return false, message
		end
		local membership = updated.Members[tostring(player.UserId)]
		if not membership then return false, "That guild is full." end
		profile.Guild = { Id = updated.Id, Role = membership.Role or "Member", JoinedAt = os.time(), Tag = updated.Tag }
		return true, "Joined " .. updated.Name .. ".", updated
	end

	function GuildService:Leave(player, profile)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "You are not in a guild." end
		local blockedLastMember = false
		local ok, message, updated = self:_update(guildId, function(guild)
			local key = tostring(player.UserId)
			local member = guild.Members[key]
			if not member then return guild end
			local otherCount = 0
			for otherKey in guild.Members do
				if otherKey ~= key then otherCount += 1 end
			end
			if otherCount == 0 then
				blockedLastMember = true
				return nil
			end
			if member.Role == "Leader" then
				local successor
				for otherKey, other in guild.Members do if otherKey ~= key then successor = otherKey; break end end
				if successor then
					guild.Members[successor].Role = "Leader"
					guild.OwnerUserId = tonumber(successor) or 0
				end
			end
			guild.Members[key] = nil
			return guild
		end)
		if not ok then
			if blockedLastMember then return false, "You're the last member — disband the guild instead of leaving." end
			return false, message
		end
		profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
		profile.GuildBonuses = emptyBonuses()
		return true, "Left the guild.", { Id = "", Name = "", Tag = "", Level = 0, XP = 0, Activity = 0, BankCash = 0, BankDust = 0, Members = {}, Upgrades = {}, CreatedAt = 0, OwnerUserId = 0 }
	end

	-- Leave() refuses to let the last member walk away (there is no invite system, only
	-- join-by-tag, so without this a solo founder had no way out of their own guild once no
	-- one else had joined). Disband permanently deletes the guild document and frees its tag
	-- for reuse; only the Leader can call it, and only once they are the only member left, so a
	-- leader can never nuke a guild other players are still invested in without emptying it
	-- via Kick/Leave first.
	function GuildService:Disband(player, profile)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "You are not in a guild." end
		local guild = self:_read(guildId)
		if not guild then return false, "Guild records are unavailable." end
		local key = tostring(player.UserId)
		local member = guild.Members[key]
		if not member or member.Role ~= "Leader" then return false, "Only the guild leader can disband it." end
		local memberCount = 0
		for _ in guild.Members do memberCount += 1 end
		if memberCount > 1 then return false, "Remove every other member before disbanding." end
		local tag = guild.Tag
		local removedDoc = pcall(function() self._store:RemoveAsync(guildId) end)
		if removedDoc then
			pcall(function()
				self._store:UpdateAsync("tag:" .. tag, function(existing)
					if existing == guildId then return nil end
					return existing
				end)
			end)
		end
		self._cache[guildId] = nil
		self._cacheExpiry[guildId] = nil
		if RunService:IsStudio() then self._studio[guildId] = nil end
		profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
		profile.GuildBonuses = emptyBonuses()
		return true, "Guild disbanded.", { Id = "", Name = "", Tag = "", Level = 0, XP = 0, Activity = 0, BankCash = 0, BankDust = 0, Members = {}, Upgrades = {}, CreatedAt = 0, OwnerUserId = 0 }
	end

	function GuildService:Kick(player, profile, targetUserId: number)
		local guildId = profile.Guild and profile.Guild.Id or ""
		local ok, message, updated = self:_update(guildId, function(guild)
			local actor, target = guild.Members[tostring(player.UserId)], guild.Members[tostring(targetUserId)]
			if not actor or not target or (actor.Role ~= "Leader" and actor.Role ~= "Officer") or target.Role == "Leader" then return nil end
			guild.Members[tostring(targetUserId)] = nil
			return guild
		end)
		return ok, ok and "Member removed." or (message or "You cannot remove that member."), updated
	end

	function GuildService:SetRole(player, profile, targetUserId: number, role: string)
		if role ~= "Officer" and role ~= "Member" then return false, "Invalid guild role." end
		local guildId = profile.Guild and profile.Guild.Id or ""
		local ok, message, updated = self:_update(guildId, function(guild)
			local actor, target = guild.Members[tostring(player.UserId)], guild.Members[tostring(targetUserId)]
			if not actor or actor.Role ~= "Leader" or not target or target.Role == "Leader" then return nil end
			target.Role = role
			return guild
		end)
		return ok, ok and "Role updated." or (message or "Only the leader can set roles."), updated
	end

	function GuildService:ContributeBank(player, profile, amount: number, currency: string)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "Join a guild before contributing." end
		local normalized, amountError = GuildMath.NormalizeContributionAmount(amount)
		if not normalized then
			return false, amountError or "Pick a positive contribution amount."
		end
		amount = normalized
		if currency ~= "Cash" and currency ~= "Dust" then
			return false, "Contribute flux or dust."
		end
		if currency == "Cash" then
			-- Cash can be an OmegaMath string at high exponents — never use raw `<` / `-=`.
			if OmegaMath.Lt(profile.Cash, amount) then
				return false, "You do not have enough currency."
			end
		else
			if (tonumber(profile.Stardust) or 0) < amount then
				return false, "You do not have enough currency."
			end
		end

		local ok, message, updated = self:_update(guildId, function(guild)
			local member = guild.Members[tostring(player.UserId)]
			if not member then return nil end
			local bankKey = currency == "Cash" and "BankCash" or "BankDust"
			guild[bankKey] = GuildMath.CreditBank(OmegaMath, currency, guild[bankKey], amount)
			guild.Activity = GuildMath.AddClamped(guild.Activity, amount)
			member.Contributed = GuildMath.AddClamped(member.Contributed, amount)
			if member.Name == nil or member.Name == "" then
				member.Name = (player.DisplayName ~= "" and player.DisplayName) or player.Name
			end
			advanceGoal(
				guild,
				tostring(player.UserId),
				currency == "Cash" and "ContributeCash" or "ContributeDust",
				amount,
				os.time()
			)
			return guild
		end)
		if not ok then return false, message or "You are not in that guild.", updated end
		if currency == "Cash" then
			profile.Cash = OmegaMath.Sub(profile.Cash, amount)
		else
			profile.Stardust -= amount
		end
		return true, "Contribution deposited.", updated
	end

	function GuildService:BuyUpgrade(player, profile, upgradeId: string)
		local definition = GameConfig.Guild.Upgrades[upgradeId]
		if not definition then return false, "Unknown guild upgrade." end
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "Join a guild first." end
		local guild = self:_read(guildId)
		if not guild then return false, "Guild records are unavailable." end
		local member = guild.Members[tostring(player.UserId)]
		if not member or (member.Role ~= "Leader" and member.Role ~= "Officer") then
			return false, "Only leaders and officers can buy hall upgrades."
		end
		local level = guild.Upgrades[upgradeId] or 0
		if level >= definition.MaxLevel then return false, "That upgrade is already maxed." end
		local cost = upgradeCost(definition, level)
		local bankKey = definition.Currency == "Cash" and "BankCash" or "BankDust"
		local bank = guild[bankKey] or 0
		if not GuildMath.CanAffordBank(OmegaMath, definition.Currency, bank, cost) then
			local label = definition.Currency == "Cash" and "flux" or "dust"
			local haveLabel = if definition.Currency == "Cash"
				then tostring(bank)
				else tostring(math.floor(tonumber(bank) or 0))
			return false, string.format("Need %d %s in the guild bank (have %s). Contribute first.", cost, label, haveLabel)
		end
		local ok, message, updated = self:_update(guildId, function(current)
			local actor = current.Members[tostring(player.UserId)]
			if not actor or (actor.Role ~= "Leader" and actor.Role ~= "Officer") then return nil end
			local nextLevel = current.Upgrades[upgradeId] or 0
			if nextLevel >= definition.MaxLevel then return nil end
			local nextCost = upgradeCost(definition, nextLevel)
			local nextBank = GuildMath.DebitBank(OmegaMath, definition.Currency, current[bankKey], nextCost)
			if nextBank == nil then return nil end
			current[bankKey] = nextBank
			current.Upgrades[upgradeId] = nextLevel + 1
			current.Activity = GuildMath.AddClamped(current.Activity, nextCost)
			advanceGoal(current, tostring(player.UserId), "Upgrades", 1, os.time())
			return current
		end)
		return ok, ok and "Guild upgrade installed." or (message or "Could not buy that upgrade."), updated
	end

	-- Marks this member as having claimed the completed goal and reports back which reward
	-- table the caller should apply. The reward itself is looked up from GameConfig by the
	-- caller, never taken from the client, and the Claimed flag is set inside the UpdateAsync
	-- transform so a double-claim cannot slip through a retry or a second server.
	function GuildService:ClaimGoal(player, profile)
		local guildId = profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return false, "Join a guild first." end
		local userKey = tostring(player.UserId)
		local failure = nil
		local rewardTypeId = nil
		local ok, message, updated = self:_update(guildId, function(guild)
			local now = os.time()
			-- Persist Claimed/Contributors rebuilds even when the claim is denied
			-- (evidence: TypeId-matched bags with nil Claimed used to rebuild then
			-- return nil on "not finished", dropping the repair from UpdateAsync).
			local repaired = ensureGoal(guild, now)
			local goal = guild.Goal
			local canClaim, claimError = GuildGoalMath.CanClaimGoal(
				goal,
				userKey,
				guild.Members[userKey] ~= nil,
				GameConfig.Guild.Goal.MinContributionForReward
			)
			if not canClaim then
				failure = claimError
				return if repaired then guild else nil
			end
			goal.Claimed[userKey] = true
			rewardTypeId = goal.TypeId
			return guild
		end)
		if not ok then return false, failure or message or "Could not claim the guild goal." end
		-- Deny path may still persist Claimed/Contributors repairs (ok=true, failure set).
		if failure then return false, failure, updated end
		local definition = rewardTypeId and goalTypeById(rewardTypeId) or nil
		if not definition then return false, "That guild goal is no longer available." end
		return true, "Guild goal reward claimed.", updated, definition.Reward
	end

	function GuildService:GetPublic(guildId: string)
		if guildId == "" then return nil end
		local doc = self:_read(guildId)
		if not doc then return nil end
		-- Normalizes the returned copy only. Legacy guilds therefore render a live goal
		-- immediately; it is persisted the next time the document is actually written.
		ensureGoal(doc, os.time())
		return doc
	end


	function GuildService:GetCachedPublic(guildId: string)
		if guildId == "" then return nil end
		local doc = self._cache[guildId] or (RunService:IsStudio() and self._studio[guildId] or nil)
		if type(doc) ~= "table" then
			doc = self:_read(guildId)
		end
		if type(doc) ~= "table" then return nil end
		local result = copy(doc)
		ensureGoal(result, os.time())
		return result
	end

	function GuildService:GetLeaderboard(page: number)
		if self._leaderboardCache and self._leaderboardCacheExpires > os.clock() then
			return copy(self._leaderboardCache)
		end
		local entries = {}
		local hasPlaceholders = false
		local ok, pages = pcall(function() return self._leaderboard:GetSortedAsync(false, 20, nil, nil) end)
		if ok and pages then
			for _, row in pages:GetCurrentPage() do
				local doc = self._cache[row.key] or self._studio[row.key]
				if doc then
					table.insert(entries, { Id = doc.Id, Name = doc.Name, Tag = doc.Tag, Activity = LeaderboardCodec.Decode(row.value), Level = doc.Level })
				else
					hasPlaceholders = true
					self:_queueWarmRead(row.key)
					table.insert(entries, { Id = row.key, Name = "Uncharted Guild", Tag = "...", Activity = LeaderboardCodec.Decode(row.value), Level = 0 })
				end
			end
		end
		if #entries == 0 then
			for _, doc in self._cache do table.insert(entries, { Id = doc.Id, Name = doc.Name, Tag = doc.Tag, Activity = doc.Activity, Level = doc.Level }) end
			table.sort(entries, function(a, b) return a.Activity > b.Activity end)
		end
		self._leaderboardCache = copy(entries)
		self._leaderboardCacheExpires = os.clock() + (hasPlaceholders and 3 or 15)
		return copy(entries)
	end

	function GuildService:GetBonuses(guildId: string)
		return bonusesFromDocument(self:GetPublic(guildId))
	end

	function GuildService:GetCachedBonuses(guildId: string)
		return bonusesFromDocument(self:GetCachedPublic(guildId))
	end


	function GuildService:ReconcileMembership(profile, userId: number): boolean
		local membership = profile.Guild
		local guildId = membership and membership.Id or ""
		if guildId == "" then
			profile.GuildBonuses = emptyBonuses()
			return false
		end
		local guild = self:_read(guildId)
		if not guild then return false end
		local member = guild.Members[tostring(userId)]
		if not member then
			profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
			profile.GuildBonuses = emptyBonuses()
			return true
		end
		local changed = membership.Role ~= member.Role or membership.Tag ~= guild.Tag
		membership.Role = member.Role
		membership.Tag = guild.Tag
		profile.GuildBonuses = bonusesFromDocument(guild)
		return changed
	end

	return GuildService
end
