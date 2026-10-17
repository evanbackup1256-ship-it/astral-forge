--!strict
local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)

return function(loadService: (string) -> any)
	local DataStoreService = game:GetService("DataStoreService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Protocol = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("Protocol"))
	local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local AdminGrantMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("OpsMath"))("AdminGrantMath")
	local ProfileBagMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileBagMath"))
	local DataTemplate = require(script.Parent.Parent:WaitForChild("DataTemplate"))
	local CommandMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CommandMath"))
	local WheelMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("WheelMath")
	local EchoMath = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("EchoMath"))
	local BazaarMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("BazaarMath"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local AdminPolicy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AdminPolicy"))
	local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
	local ServerTelemetry = loadService("ServerTelemetry")

	local AdminService = {}
	AdminService.__index = AdminService
	-- Queue entries are unsigned, so only explicitly configured external moderator identities are trusted.
	AdminService.DiscordModeratorIds = {
		[100000001] = true,
		[100000002] = true,
		[100000003] = true,
	}

	local CommandSchema = require(ReplicatedStorage.AstralForge.Shared.AdminCommandSchema)
	local MAX_GRANT = AdminGrantMath.DEFAULT_MAX_GRANT
	local MAX_AUDIT_MEMORY = 40
	local MAX_AUDIT_PERSISTED = 100
	local NONCE_TTL = 300

	local COMMANDS = table.freeze({
		SetFlux = { Label = "Set current flux", Option = false, Category = "Economy" },
		SetVault = { Label = "Set stored vault flux", Option = false, Category = "Economy" },
		SetContinuumRank = { Label = "Set Continuum rank", Option = false, Category = "Progress" },
		SetFreeSpins = { Label = "Set free wheel spins", Option = false, Category = "Items" },
		ResetAnomalyCharge = { Label = "Reset current shift charge", Option = false, Category = "Resets" },
		ClearAnomalyCombo = { Label = "Clear shift combo", Option = false, Category = "Resets" },

		GrantFlux = { Label = "Grant flux", Option = false, Category = "Economy" },
		GrantCores = { Label = "Grant astral cores", Option = false, Category = "Economy" },
		GrantStardust = { Label = "Grant stardust", Option = false, Category = "Economy" },
		GrantRebirths = { Label = "Grant rebirths", Option = false, Category = "Progress" },
		GrantDomainEssence = { Label = "Grant domain essence", Option = false, Category = "Progress" },
		GrantAnomalyFragments = { Label = "Grant reactor fragments", Option = false, Category = "Progress" },
		GrantSignals = { Label = "Grant command signals", Option = false, Category = "Progress" },
		GrantCommandXP = { Label = "Grant command XP", Option = false, Category = "Progress" },
		GrantSeasonXP = { Label = "Grant season XP", Option = false, Category = "Progress" },
		GrantStreakShields = { Label = "Grant streak shields", Option = false, Category = "Progress" },
		GrantItemEssence = { Label = "Grant relic essence", Option = false, Category = "Items" },
		GrantContinuumRanks = { Label = "Grant Continuum ranks", Option = false, Category = "Progress" },
		GrantAnomalyCharge = { Label = "Grant reactor charge", Option = false, Category = "Progress" },
		GrantAnomalyStabilizations = { Label = "Grant reactor stabilizations", Option = false, Category = "Progress" },
		GrantShards = { Label = "Grant Star Foundry shards", Option = false, Category = "Progress" },
		SetFoundryRadius = { Label = "Set Foundry board radius", Option = false, Category = "Progress" },
		GrantFoundryPiece = { Label = "Grant Foundry piece", Option = true, Category = "Progress" },
		GrantFreeSpins = { Label = "Grant wheel spins", Option = false, Category = "Items" },
		GrantCrateKeys = { Label = "Grant crate keys", Option = true, Category = "Items" },
		GrantAllCrateKeys = { Label = "Grant every crate key", Option = false, Category = "Items" },
		GrantPity = { Label = "Grant crate pity", Option = true, Category = "Items" },
		GrantBoost = { Label = "Grant boost", Option = true, Category = "Items" },
		GrantAllBoosts = { Label = "Grant every boost", Option = false, Category = "Items" },
		GrantRelic = { Label = "Grant exact relic", Option = true, Category = "Items" },
		ClearActiveBoost = { Label = "Clear active boost", Option = false, Category = "Items" },
		ResetWheelCooldown = { Label = "Reset wheel cooldown", Option = false, Category = "Resets" },
		ResetDailyClaim = { Label = "Reset daily claim", Option = false, Category = "Resets" },
		ClearVault = { Label = "Clear vault", Option = false, Category = "Resets" },
		SetZone = { Label = "Set unlocked zone", Option = false, Category = "Progress" },
		EnableUnlimitedFlux = { Label = "Enable unlimited flux", Option = false, Category = "Economy" },
		DisableUnlimitedFlux = { Label = "Disable unlimited flux", Option = false, Category = "Economy" },
		UnlockProgression = { Label = "Unlock progression", Option = false, Category = "Progress" },
		ResetTutorial = { Label = "Reset tutorial", Option = false, Category = "Resets" },
		ResetSettings = { Label = "Restore settings defaults", Option = false, Category = "Resets" },
		ShowUpdates = { Label = "Show updates again", Option = false, Category = "Resets" },
		GrantEverything = { Label = "Owner grant bundle", Option = false, Category = "Economy" },
		WipeFlux = { Label = "Wipe flux", Option = false, Category = "Resets" },
		WipeVault = { Label = "Wipe vault", Option = false, Category = "Resets" },
		WipeCores = { Label = "Wipe cores", Option = false, Category = "Resets" },
		WipeStardust = { Label = "Wipe stardust", Option = false, Category = "Resets" },
		SetDomainEssence = { Label = "Set domain essence", Option = false, Category = "Progress" },
		SetItemEssence = { Label = "Set relic essence", Option = false, Category = "Items" },
		SetSignals = { Label = "Set command signals", Option = false, Category = "Progress" },
		SetSeasonXP = { Label = "Set season XP", Option = false, Category = "Progress" },
		SetStreakShields = { Label = "Set streak shields", Option = false, Category = "Progress" },
		SetAnomalyFragments = { Label = "Set reactor fragments", Option = false, Category = "Progress" },
		GrantVaultFlux = { Label = "Grant flux into vault", Option = false, Category = "Economy" },
		DoubleFlux = { Label = "Double current flux", Option = false, Category = "Economy" },
		BankVault = { Label = "Move vault into wallet", Option = false, Category = "Economy" },
		WipeItemEssence = { Label = "Wipe relic essence", Option = false, Category = "Resets" },
		ResetPityAll = { Label = "Reset pity on every crate", Option = false, Category = "Resets" },
		ResetCommandXP = { Label = "Reset command XP", Option = false, Category = "Resets" },
		PennyPinch = { Label = "Set flux to 1", Option = false, Category = "Troll" },
		TaxHalf = { Label = "Tax half their flux", Option = false, Category = "Troll" },
		SwapWallet = { Label = "Swap cash and vault", Option = false, Category = "Troll" },
		FillVault = { Label = "Fill vault to cap", Option = false, Category = "Economy" },
		DrainKeys = { Label = "Drain all crate keys", Option = false, Category = "Troll" },
		DrainBoosts = { Label = "Drain all boosts", Option = false, Category = "Troll" },
		LockRelics = { Label = "Protect every relic", Option = false, Category = "Items" },
		UnlockRelics = { Label = "Unprotect every relic", Option = false, Category = "Items" },
		SalvageRelics = { Label = "Salvage unlocked relics", Option = false, Category = "Troll" },
		SetRebirths = { Label = "Set rebirth count", Option = false, Category = "Progress" },
		SetCores = { Label = "Set core count", Option = false, Category = "Economy" },
		SetStardust = { Label = "Set stardust count", Option = false, Category = "Economy" },
		SetDomainRank = { Label = "Set domain rank", Option = false, Category = "Progress" },
		GrantSkillPoints = { Label = "Grant domain skill points", Option = false, Category = "Progress" },
		ResetDomain = { Label = "Reset domain tree", Option = false, Category = "Resets" },
		MaxMachines = { Label = "Max every machine", Option = false, Category = "Progress" },
		ResetMachines = { Label = "Reset every machine", Option = false, Category = "Resets" },
		MaxResearch = { Label = "Max every research", Option = false, Category = "Progress" },
		ResetResearch = { Label = "Reset every research", Option = false, Category = "Resets" },
		MaxGrid = { Label = "Max legacy foundations", Option = false, Category = "Progress" },
		ResetGrid = { Label = "Reset legacy foundations", Option = false, Category = "Resets" },
		FillPityAll = { Label = "Max pity on every crate", Option = false, Category = "Items" },
		ResetTrades = { Label = "Reset daily trades", Option = false, Category = "Resets" },
		ResetDailies = { Label = "Reset all daily clocks", Option = false, Category = "Resets" },
		ZeroZone = { Label = "Kick back to world 1", Option = false, Category = "Troll" },
		GrantEchoCharge = { Label = "Grant echo charge", Option = false, Category = "Progress" },
		MaxCrew = { Label = "Max command crew", Option = false, Category = "Progress" },
		DiscoverArts = { Label = "Discover every artifact", Option = false, Category = "Items" },
		InspectMarket = { Label = "Inspect Black Market", Option = false, Category = "Economy", Danger = "quick" },
		ResetMarketPurchases = { Label = "Reset market shelf purchases", Option = false, Category = "Resets" },
		CancelMarketRequest = { Label = "Cancel market supply request", Option = false, Category = "Resets" },
		Blind = { Label = "Lights out overlay", Option = false, Category = "Troll", World = true },
		Jumpscare = { Label = "Jumpscare card", Option = false, Category = "Troll", World = true },
		InvertHud = { Label = "Invert their HUD", Option = false, Category = "Troll", World = true },
		SpinHud = { Label = "Spin their HUD", Option = false, Category = "Troll", World = true },
		TinyHud = { Label = "Shrink their HUD", Option = false, Category = "Troll", World = true },
		GiantHud = { Label = "Blow up their HUD", Option = false, Category = "Troll", World = true },
		JumbleHud = { Label = "Jumble the HUD", Option = false, Category = "Troll", World = true },
		ShakeHud = { Label = "Shake the shell", Option = false, Category = "Troll", World = true },
		DiscoHud = { Label = "Disco HUD", Option = false, Category = "Troll", World = true },
		RainbowHud = { Label = "Rainbow wash", Option = false, Category = "Troll", World = true },
		ConfettiStorm = { Label = "Confetti tax overlay", Option = false, Category = "Troll", World = true },
		FakeRareDrop = { Label = "Fake celestial relic drop", Option = false, Category = "Troll", World = true },
		FakeEvent = { Label = "False starfall alert", Option = false, Category = "Troll", World = true },
		FakeRebirth = { Label = "Fake rebirth prompt", Option = false, Category = "Troll", World = true },
		FakeTrade = { Label = "Fake incoming trade", Option = false, Category = "Troll", World = true },
		FakeRob = { Label = "Fake wallet hack", Option = false, Category = "Troll", World = true },
		ClownTitle = { Label = "Clown title splash", Option = true, Category = "Troll", World = true },
		Honk = { Label = "Honk toast", Option = false, Category = "Troll", World = true },
		MuteToasts = { Label = "Fake error toasts", Option = false, Category = "Troll", World = true },
		EmptyBagScare = { Label = "Fake empty bag", Option = false, Category = "Troll", World = true },
		Kick = { Label = "Kick from this server", Option = false, Category = "Moderation", Moderation = true },
		ServerBan = { Label = "Ban from this server", Option = false, Category = "Moderation", Moderation = true },
		GlobalBan = { Label = "Ban from the experience", Option = false, Category = "Moderation", Moderation = true },
		Unban = { Label = "Remove ban", Option = false, Category = "Moderation", Moderation = true },
	})
	local CATEGORY_RANK = { Economy = 1, Progress = 2, Items = 3, Resets = 4, Troll = 5, Moderation = 6 }

	local function commandDanger(definition: { [string]: any }): string
		if string.sub(definition.Label or "",1,4)=="Set " then return "arm" end
		return AdminGrantMath.CommandDanger(definition)
	end

	local function boundedAmount(raw: any, fallback: number?): number?
		return AdminGrantMath.BoundedAmount(raw, fallback, MAX_GRANT)
	end

	local function cleanText(raw: any, maximum: number): string
		return AdminGrantMath.CleanText(raw, maximum)
	end

	local function onlinePlayer(userId: any): Player?
		local id = tonumber(userId)
		if not id or id ~= math.floor(id) then return nil end
		return Players:GetPlayerByUserId(id)
	end

	local function roleFor(player: Player): string?
		local configured = ServerConfig.AdminUserIds[player.UserId]
		if type(configured) == "string" and configured ~= "" then return configured end
		if RunService:IsStudio() and ServerConfig.AllowStudioAdmins == true then return "Studio Developer" end
		return nil
	end

	local function createRelic(profile, definitionId: string): boolean
		local definition = nil
		for _, candidate in GameConfig.Items.Definitions do
			if candidate.Id == definitionId then definition = candidate break end
		end
		if not definition then return false end
		local items = ProfileBagMath.EnsureItems(profile)
		local count = 0
		for _ in items.Inventory do count += 1 end
		if count >= GameConfig.Items.InventoryLimit then return false end
		local uid, nextId = AdminGrantMath.NextRelicUid(items.Inventory, items.NextId)
		if uid == nil then return false end
		local instance = AdminGrantMath.BuildRelicInstance(definition.Id, os.time())
		if instance == nil then return false end
		items.NextId = nextId
		items.Inventory[uid] = instance
		ProfileBagMath.BumpStat(profile, "ItemsFound", 1)
		return true
	end

	local function effectRemote(): RemoteEvent?
		local folder = ReplicatedStorage:FindFirstChild(Protocol.FolderName)
		if folder == nil then return nil end
		local remote = folder:FindFirstChild(Protocol.EffectName)
		if remote and remote:IsA("RemoteEvent") then return remote end
		return nil
	end

	local function toastRemote(): RemoteEvent?
		local folder = ReplicatedStorage:FindFirstChild(Protocol.FolderName)
		if folder == nil then return nil end
		local remote = folder:FindFirstChild(Protocol.ToastName)
		if remote and remote:IsA("RemoteEvent") then return remote end
		return nil
	end

	local function firePrank(player: Player, kind: string, duration: number, caption: string)
		local remote = effectRemote()
		if remote then
			remote:FireClient(player, { Type = "AdminPrank", Kind = kind, Duration = duration, Caption = caption })
		end
	end

	local function applyWorld(_actor: Player, target: Player, command: string, amount: number, option: string): (boolean, string)
		local duration = math.clamp(math.floor(amount), 3, 20)
		if command == "Honk" then
			local toast = toastRemote()
			if toast then toast:FireClient(target, { Title = "HONK", Body = "An admin honked at you.", Tone = "Special" }) end
			return true, "Honked at " .. target.Name
		end
		local caption = option
		if command == "FakeRareDrop" then
			caption = "Astra Prism"
		elseif command == "FakeEvent" then
			caption = "Starfall signatures are converging above the forge."
		elseif command == "JumbleHud" then
			caption = "The forge instruments slipped out of alignment."
		end
		firePrank(target, command, duration, caption)
		return true, string.format("%s in-game prank on %s for %ds.", command, target.Name, duration)
	end

	function AdminService.new(dataService)
		local self = setmetatable({}, AdminService)
		self._data = dataService
		self._audit = {}
		self._nonces = {}
		self._lastByActor = {}
		self._alive = true
		self._workers = {}
		self._serverBans = {}
		self._banLog = {}
		self._auditStore = StoreAccess.data(ServerConfig.AdminAuditStoreName)
		self._discordQueueStore = StoreAccess.data(ServerConfig.DiscordModQueueStoreName)
		self._discordSeenIds = {}
		self._playerAdded = Players.PlayerAdded:Connect(function(player)
			self:EnforceServerBan(player)
		end)
		for _, player in Players:GetPlayers() do
			self:EnforceServerBan(player)
		end
		self._discordQueueWorker = task.spawn(function()
			while self._alive do
				task.wait(ServerConfig.DiscordModQueuePollSeconds)
				if not self._alive then break end
				local ok, err = pcall(function()
				return self:_pollDiscordQueue()
			end)
			if not ok then
				ModuleLog.Every("discord-queue-poll", 60, "Admin", "Discord mod queue poll crashed: " .. tostring(err))
			end
			end
		end)
		return self
	end

	function AdminService:_pollDiscordQueue()
		local pages
		local listOk, listErr = pcall(function()
			pages = self._discordQueueStore:ListKeysAsync(ServerConfig.DiscordModQueuePrefix)
		end)
		if not listOk then
			ModuleLog.Every("discord-queue-list", 60, "Admin", "Discord mod queue list failed: " .. tostring(listErr))
			return
		end
		while true do
			local itemsOk, items = pcall(function()
			return pages:GetCurrentPage()
		end)
		if not itemsOk or type(items) ~= "table" then
			break
		end
			for _, item in items do
				local key = item.KeyName
				if not self._discordSeenIds[key] then
					self._discordSeenIds[key] = true
					self:_claimDiscordEntry(key)
				end
			end
			if pages.IsFinished then break end
			local advanceOk, advanceErr = pcall(function() pages:AdvanceToNextPageAsync() end)
			if not advanceOk then
				ModuleLog.Every("discord-queue-page", 60, "Admin", "Discord mod queue page advance failed: " .. tostring(advanceErr))
				break
			end
		end
	end

	function AdminService:_claimDiscordEntry(key: string)
		local entry
		local getOk, getErr = pcall(function()
			entry = self._discordQueueStore:GetAsync(key)
		end)
		if not getOk then
			self._discordSeenIds[key] = nil
			ModuleLog.Every("discord-queue-get:" .. key, 60, "Admin", "Discord mod queue read failed: " .. tostring(getErr))
			return
		end
		if type(entry) ~= "table" then return end
		local removed, removeErr = pcall(function()
			self._discordQueueStore:RemoveAsync(key)
		end)
		if not removed then
			self._discordSeenIds[key] = nil
			ModuleLog.Every("discord-queue-remove:" .. key, 60, "Admin", "Discord mod queue remove failed: " .. tostring(removeErr))
			return
		end
		self:_executeDiscordAction(entry)
	end

	function AdminService:_executeDiscordAction(entry: any)
		local moderatorId = tonumber(entry.ModeratorId)
		if
			type(moderatorId) ~= "number"
			or moderatorId ~= moderatorId
			or moderatorId <= 0
			or moderatorId ~= math.floor(moderatorId)
			or AdminService.DiscordModeratorIds[moderatorId] ~= true
		then
			-- Drop unsigned/untrusted queue entries before any moderation side effect can occur.
			ModuleLog.Warn("Admin", "Dropped Discord moderation entry with an unauthorized ModeratorId")
			return
		end
		local action = entry.Action
		local userId = tonumber(entry.UserId)
		if type(action) ~= "string" or type(userId) ~= "number" then return end
		userId = math.floor(userId)
		local reason = type(entry.Reason) == "string" and entry.Reason ~= "" and entry.Reason or "Moderated via Discord."
		local moderator = type(entry.Moderator) == "string" and entry.Moderator or "Discord staff"
		local subject = { UserId = userId, Name = tostring(userId) }
		local target = Players:GetPlayerByUserId(userId)
		if target then subject.Name = target.Name end

		if action == "Kick" then
			if target and target.Parent == Players then
				target:Kick(string.format("Kicked by %s: %s", moderator, reason))
				self:_record({ Name = "Discord:" .. moderator, UserId = 0 } :: any, subject, "DiscordKick", 0, "", reason, 0)
			end
			return
		end

		if action == "Ban" then
			local permanent = entry.DurationSeconds == nil or tonumber(entry.DurationSeconds) == nil or (tonumber(entry.DurationSeconds) :: number) <= 0
			local duration = permanent and -1 or math.max(60, math.floor(tonumber(entry.DurationSeconds) :: number))
			local displayReason = string.sub(string.format("Banned by %s: %s", moderator, reason), 1, 400)
			local banOk, banError = pcall(function()
				Players:BanAsync({
					UserIds = { userId },
					Duration = duration,
					DisplayReason = displayReason,
					PrivateReason = string.sub(string.format("Discord ban by %s: %s", moderator, reason), 1, 1000),
					ExcludeAltAccounts = false,
					ApplyToUniverse = true,
				})
			end)
			local untilTime = permanent and -1 or (os.time() + duration)
			self._banLog[userId] = { Name = subject.Name, Scope = "Global", Until = untilTime, Reason = displayReason }
			if not banOk then
				ModuleLog.Warn("Admin", "Discord BanAsync failed: " .. tostring(banError))
				self._serverBans[userId] = { Name = subject.Name, Scope = "Server", Until = untilTime == -1 and 0 or untilTime, Reason = displayReason }
			end
			if target and target.Parent == Players then
				target:Kick(displayReason)
			end
			self:_record({ Name = "Discord:" .. moderator, UserId = 0 } :: any, subject, "DiscordBan", permanent and 0 or duration, "", reason, 0)
			return
		end

		if action == "Unban" then
			self._serverBans[userId] = nil
			self._banLog[userId] = nil
			local unbanOk, unbanError = pcall(function()
				Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
			end)
			if not unbanOk then
				ModuleLog.Warn("Admin", "Discord UnbanAsync failed: " .. tostring(unbanError))
			end
			self:_record({ Name = "Discord:" .. moderator, UserId = 0 } :: any, subject, "DiscordUnban", 0, "", reason, 0)
		end
	end

	function AdminService:HasAccess(player: Player): boolean
		return roleFor(player) ~= nil
	end

	function AdminService:Forget(player: Player)
		self._nonces[player.UserId] = nil
		if self._lastByActor then
			self._lastByActor[player.UserId] = nil
		end
	end

	function AdminService:_consumeNonce(actor: Player, nonce: string): boolean
		local now = os.time()
		local bucket = self._nonces[actor.UserId] or {}
		self._nonces[actor.UserId] = bucket
		for id, expiresAt in bucket do if expiresAt <= now then bucket[id] = nil end end
		if bucket[nonce] then return false end
		bucket[nonce] = now + NONCE_TTL
		return true
	end

	function AdminService:EnforceServerBan(player: Player)
		local record = self._serverBans[player.UserId]
		if record == nil then
			return false
		end
		if type(record.Until) == "number" and record.Until > 0 and record.Until <= os.time() then
			self._serverBans[player.UserId] = nil
			return false
		end
		player:Kick(record.Reason ~= "" and record.Reason or "You are banned from this server.")
		return true
	end

	function AdminService:_record(actor: Player, target: { UserId: number, Name: string }, command: string, amount: number?, option: string, reason: string, revision: number)
		local entry = {
			Id = string.format("%s:%d:%d:%d:%d", game.JobId, actor.UserId, target.UserId, revision, os.time()),
			At = os.time(),
			ActorUserId = actor.UserId,
			ActorName = actor.Name,
			TargetUserId = target.UserId,
			TargetName = target.Name,
			Command = command,
			Amount = amount or 0,
			Option = option,
			Reason = reason,
			Revision = revision,
			JobId = game.JobId,
		}
		table.insert(self._audit, 1, entry)
		while #self._audit > MAX_AUDIT_MEMORY do table.remove(self._audit) end
		ModuleLog.Info("Admin", string.format("%s -> %s: %s (%s)", actor.Name, target.Name, command, reason))
		if not self._alive then return end
		local token = {}
		local worker = task.defer(function()
			if not self._alive then
				self._workers[token] = nil
				return
			end
			local ok, err = pcall(function()
				self._auditStore:UpdateAsync("Recent", function(previous)
					local records = type(previous) == "table" and previous or {}
					table.insert(records, 1, entry)
					while #records > MAX_AUDIT_PERSISTED do table.remove(records) end
					return records
				end)
			end)
			if not ok then ModuleLog.Warn("Admin", "couldn't write the audit log: " .. tostring(err)) end
			self._workers[token] = nil
		end)
		self._workers[token] = worker
	end

	function AdminService:Destroy()
		self._alive = false
		if self._playerAdded then
			self._playerAdded:Disconnect()
			self._playerAdded = nil
		end
		if self._discordQueueWorker then
			task.cancel(self._discordQueueWorker)
			self._discordQueueWorker = nil
		end
		for token, worker in self._workers do
			task.cancel(worker)
			self._workers[token] = nil
		end
		table.clear(self._nonces)
		if self._lastByActor then
			table.clear(self._lastByActor)
		end
		table.clear(self._serverBans)
		table.clear(self._banLog)
		table.clear(self._discordSeenIds)
	end

	function AdminService:State(viewer: Player)
		local role = roleFor(viewer)
		if not role then return { Access = false } end
		local online = {}
		for _, player in Players:GetPlayers() do
			local profile = self._data:Get(player)
			if profile then
				local keys = 0
				local relics = 0
				local boosts = 0
				local essence = 0
				if type(profile.Items) == "table" then
					essence = tonumber(profile.Items.Essence) or 0
					if type(profile.Items.Keys) == "table" then
						for _, count in profile.Items.Keys do
							if type(count) == "number" then
								keys += count
							end
						end
					end
					if type(profile.Items.Inventory) == "table" then
						for _ in profile.Items.Inventory do
							relics += 1
						end
					end
				end
				if type(profile.BoostInventory) == "table" then
					for _, count in profile.BoostInventory do
						if type(count) == "number" then
							boosts += count
						end
					end
				end
				table.insert(online, {
					UserId = player.UserId,
					Name = player.Name,
					DisplayName = player.DisplayName,
					Cash = profile.Cash,
					Vault = profile.Vault,
					Capacity = Economy.Capacity(profile),
					Cores = profile.Cores,
					Rebirths = profile.Rebirths,
					Zone = profile.Zone,
					CurrentZone = profile.CurrentZone,
					Production = Economy.Production(profile),
					Stardust = profile.Stardust,
					Essence = essence,
					Keys = keys,
					Relics = relics,
					Boosts = boosts,
					Unlimited = type(profile.Flags) == "table" and profile.Flags.UnlimitedMoney == true,
				})
			end
		end
		table.sort(online, function(left, right) return left.Name < right.Name end)
		local commands = {}
		for id, definition in COMMANDS do
			if not AdminPolicy.Allows(role, id, definition) then
				continue
			end
			table.insert(commands, {
				Id = id,
				Label = definition.Label,
				Input = CommandSchema.describe(id, definition),
				NeedsOption = definition.Option == true,
				Category = definition.Category or "Economy",
				Danger = commandDanger(definition),
				World = definition.World == true,
			})
		end
		table.sort(commands, function(left, right)
			local leftRank = CATEGORY_RANK[left.Category] or 9
			local rightRank = CATEGORY_RANK[right.Category] or 9
			if leftRank ~= rightRank then return leftRank < rightRank end
			return left.Label < right.Label
		end)
		local audit = {}
		for index = 1, math.min(12, #self._audit) do audit[index] = self._audit[index] end
		local banned = {}
		local seenBan = {}
		local function pushBan(userId: number, record: any)
			if seenBan[userId] or type(record) ~= "table" then return end
			if type(record.Until) == "number" and record.Until > 0 and record.Until <= os.time() then return end
			seenBan[userId] = true
			table.insert(banned, {
				UserId = userId,
				Name = record.Name or tostring(userId),
				Scope = record.Scope or "Server",
				Until = record.Until or 0,
				Reason = record.Reason or "",
			})
		end
		for userId, record in self._serverBans do pushBan(userId, record) end
		for userId, record in self._banLog do pushBan(userId, record) end
		table.sort(banned, function(left, right) return left.Name < right.Name end)
		return {
			Access = true,
			Role = role,
			SelfUserId = viewer.UserId,
			Online = online,
			Commands = commands,
			Recent = audit,
			Banned = banned,
			LastAction = (self._lastByActor and self._lastByActor[viewer.UserId]) or nil,
			Integrity = self._data:GetIntegrityStatus(viewer),
			Telemetry = ServerTelemetry.Snapshot(),
		}
	end

	local AUDIT_ONLY_REASONS = AdminGrantMath.AUDIT_ONLY_REASONS

	local function playerFacingReason(command: string, reason: string): string
		return AdminGrantMath.PlayerFacingReason(command, reason, AUDIT_ONLY_REASONS)
	end

	function AdminService:_moderate(actor: Player, command: string, targetUserId: number, amountRaw: any, option: string, reason: string)
		local target = Players:GetPlayerByUserId(targetUserId)
		local listed = self._serverBans[targetUserId] or self._banLog[targetUserId]
		local targetName = (target and target.Name) or (listed and listed.Name) or tostring(targetUserId)
		local subject = { UserId = targetUserId, Name = targetName }
		if target ~= nil and roleFor(target) ~= nil and target ~= actor then
			return { ok = false, error = "Cannot moderate another administrator." }
		end

		if command == "Unban" then
			self._serverBans[targetUserId] = nil
			self._banLog[targetUserId] = nil
			local unbanOk, unbanError = pcall(function()
				Players:UnbanAsync({
					UserIds = { targetUserId },
					ApplyToUniverse = true,
				})
			end)
			if not unbanOk then
				ModuleLog.Warn("Admin", "UnbanAsync failed: " .. tostring(unbanError))
			end
			self:_record(actor, subject, command, 0, option, reason, 0)
			return {
				ok = true,
				message = string.format("Cleared bans for %s%s.", targetName, unbanOk and "" or " (experience ban service unavailable)"),
				Admin = self:State(actor),
				TargetUserId = targetUserId,
				Persisted = true,
			}
		end

		if target == nil or target.Parent ~= Players then
			return { ok = false, error = "Target must be online in this server." }
		end

		if command == "Kick" then
			local kickMessage = playerFacingReason(command, reason)
			self:_record(actor, subject, command, 0, option, reason, self._data:GetRevision(target) or 0)
			target:Kick(kickMessage)
			return {
				ok = true,
				message = string.format("Kicked %s.", targetName),
				Admin = self:State(actor),
				TargetUserId = targetUserId,
				Persisted = true,
			}
		end

		local seconds = tonumber(amountRaw)
		if seconds == nil then seconds = 0 end
		if command == "ServerBan" then
			local untilTime = (seconds <= 0) and 0 or (os.time() + math.max(60, math.floor(seconds)))
			local kickMessage = playerFacingReason(command, reason)
			local record = { Name = targetName, Scope = "Server", Until = untilTime, Reason = kickMessage }
			self._serverBans[targetUserId] = record
			self._banLog[targetUserId] = record
			self:_record(actor, subject, command, math.max(0, math.floor(seconds)), option, reason, self._data:GetRevision(target) or 0)
			target:Kick(kickMessage)
			return {
				ok = true,
				message = string.format("Server-banned %s%s.", targetName, untilTime == 0 and " for this session" or ""),
				Admin = self:State(actor),
				TargetUserId = targetUserId,
				Persisted = true,
			}
		end

		if command == "GlobalBan" then
			if target == actor then
				return { ok = false, error = "Do not globally ban yourself." }
			end
			local permanent = option == "Permanent" or seconds < 0
			local duration = permanent and -1 or math.max(60, math.floor(seconds))
			local displayReason = string.sub(playerFacingReason(command, reason), 1, 400)
			local banConfig: { [string]: any } = {
				UserIds = { targetUserId },
				Duration = duration,
				DisplayReason = displayReason,
				PrivateReason = string.sub(string.format("%s banned %s: %s", actor.Name, targetName, reason), 1, 1000),
				ExcludeAltAccounts = false,
				ApplyToUniverse = true,
			}
			local banOk, banError = pcall(function()
				Players:BanAsync(banConfig)
			end)
			local untilTime = permanent and -1 or (os.time() + duration)
			self._banLog[targetUserId] = { Name = targetName, Scope = "Global", Until = untilTime, Reason = displayReason }
			if not banOk then
				self._serverBans[targetUserId] = { Name = targetName, Scope = "Server", Until = untilTime == -1 and 0 or untilTime, Reason = displayReason }
				ModuleLog.Warn("Admin", "BanAsync failed: " .. tostring(banError))
				if target.Parent == Players then
					target:Kick(displayReason)
				end
			end
			self:_record(actor, subject, command, permanent and 0 or duration, option, reason, self._data:GetRevision(target) or 0)
			return {
				ok = true,
				message = string.format(
					"%s globally banned %s%s.",
					banOk and "Issued" or "Queued (service failed; kicked this server)",
					targetName,
					permanent and " permanently" or ""
				),
				Admin = self:State(actor),
				TargetUserId = targetUserId,
				Persisted = true,
			}
		end

		return { ok = false, error = "Unknown moderation command." }
	end

	-- Each profile command has one executor; the transaction wrapper owns audits and saving.
	local profileHandlers = {}
	profileHandlers.GrantFlux = function(profile, amount, option)
		local changedAmount = amount
				profile.Cash = OmegaMath.Add(profile.Cash, amount)
				profile.RunCash = OmegaMath.Add(profile.RunCash, amount)
				profile.LifetimeCash = OmegaMath.Add(profile.LifetimeCash, amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantCores = function(profile, amount, option)
		local changedAmount = amount
			profile.Cores += amount
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantStardust = function(profile, amount, option)
		local changedAmount = amount
			profile.Stardust += amount
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantRebirths = function(profile, amount, option)
		local changedAmount = amount
			profile.Rebirths += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantDomainEssence = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureDomain(profile).Essence += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantAnomalyFragments = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureAnomaly(profile).Fragments += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantSignals = function(profile, amount, option)
		local changedAmount = amount
				profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
				profile.Command.Signals += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantCommandXP = function(profile, amount, option)
		local changedAmount = amount
				profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
				profile.Command.XP += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantSeasonXP = function(profile, amount, option)
		local changedAmount = amount
				profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
				profile.Command.SeasonXP += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantStreakShields = function(profile, amount, option)
		local changedAmount = amount
				profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
				profile.Command.StreakShields += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantItemEssence = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureItems(profile).Essence += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantContinuumRanks = function(profile, amount, option)
		local changedAmount = amount
				local continuum = ProfileBagMath.EnsureContinuum(profile)
				continuum.Rank = math.min(GameConfig.Continuum.MaxRank, continuum.Rank + math.floor(amount))
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantAnomalyCharge = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureAnomaly(profile).Charge += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantAnomalyStabilizations = function(profile, amount, option)
		local changedAmount = amount
				local n = math.floor(amount)
				ProfileBagMath.EnsureAnomaly(profile).Stabilizations += n
				ProfileBagMath.BumpStat(profile, "AnomalyStabilizations", n)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantShards = function(profile, amount, option)
		local changedAmount = amount
		local foundry = ProfileBagMath.EnsureFoundry(profile)
		foundry.Shards = (tonumber(foundry.Shards) or 0) + math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetFoundryRadius = function(profile, amount, option)
		local changedAmount = amount
		local foundry = ProfileBagMath.EnsureFoundry(profile)
		foundry.Radius = math.clamp(math.floor(amount), 2, 4)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantFoundryPiece = function(profile, amount, option)
		local changedAmount = amount
		local foundry = ProfileBagMath.EnsureFoundry(profile)
		if type(foundry.Bench) ~= "table" then
			foundry.Bench = {}
		end
		local kind = "Ember"
		local tier = 1
		if type(option) == "string" and option ~= "" then
			local k, t = string.match(option, "([^:]+):?(%d*)")
			if k and k ~= "" then
				kind = k
			end
			if t and tonumber(t) then
				tier = math.clamp(tonumber(t) :: number, 1, 9)
			end
		end
		for _ = 1, math.clamp(math.floor(amount), 1, 10) do
			if #foundry.Bench < 12 then
				table.insert(foundry.Bench, { Kind = kind, Tier = tier, Rotation = 0 })
			end
		end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantFreeSpins = function(profile, amount, option)
		local changedAmount = amount
				profile.Wheel = WheelMath.Ensure(profile.Wheel)
				profile.Wheel.FreeSpins += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantCrateKeys = function(profile, amount, option)
		local changedAmount = amount
				local keys = ProfileBagMath.EnsureItemKeys(profile)
				if keys[option] == nil then return { ok = false, error = "Unknown crate id." } end
				keys[option] += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantAllCrateKeys = function(profile, amount, option)
		local changedAmount = amount
				local keys = ProfileBagMath.EnsureItemKeys(profile)
				for crateId in keys do keys[crateId] += math.floor(amount) end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantPity = function(profile, amount, option)
		local changedAmount = amount
				local items = ProfileBagMath.EnsureItems(profile)
				if items.Pity[option] == nil then return { ok = false, error = "Unknown crate id." } end
				items.Pity[option] += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantBoost = function(profile, amount, option)
		local changedAmount = amount
				if not GameConfig.Boosts[option] then return { ok = false, error = "Unknown boost id." } end
				local inventory = ProfileBagMath.EnsureBoostInventory(profile)
				inventory[option] = (inventory[option] or 0) + math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantAllBoosts = function(profile, amount, option)
		local changedAmount = amount
				local inventory = ProfileBagMath.EnsureBoostInventory(profile)
				for boostId in GameConfig.Boosts do
					inventory[boostId] = (inventory[boostId] or 0) + math.floor(amount)
				end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantRelic = function(profile, amount, option)
		local changedAmount = amount
				changedAmount = 0
				for _ = 1, math.min(10, math.floor(amount)) do
					if not createRelic(profile, option) then break end
					changedAmount += 1
				end
				if changedAmount <= 0 then return { ok = false, error = "Relic id is invalid or inventory is full." } end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ClearActiveBoost = function(profile, amount, option)
		local changedAmount = amount
				local active = ProfileBagMath.EnsureActiveBoost(profile)
				active.Id = ""
				active.EndsAt = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetWheelCooldown = function(profile, amount, option)
		local changedAmount = amount
				profile.Wheel = WheelMath.Ensure(profile.Wheel)
				profile.Wheel.LastSpinAt = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetDailyClaim = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureDaily(profile).LastClaimDay = -1
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ClearVault = function(profile, amount, option)
		local changedAmount = amount
			profile.Vault = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetZone = function(profile, amount, option)
		local changedAmount = amount
				local zone = math.clamp(math.floor(amount), 1, GameConfig.MaxZone)
				profile.Zone = math.max(profile.Zone, zone)
				profile.CurrentZone = zone
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.EnableUnlimitedFlux = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureFlags(profile).UnlimitedMoney = true
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.DisableUnlimitedFlux = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureFlags(profile).UnlimitedMoney = false
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.UnlockProgression = function(profile, amount, option)
		local changedAmount = amount
				profile.Zone = GameConfig.MaxZone
				profile.CurrentZone = profile.Zone
				for _, machine in GameConfig.Machines do profile.Machines[machine.Id] = machine.MaxLevel end
				for _, research in GameConfig.Research do profile.Research[research.Id] = research.MaxLevel end
				for _, upgrade in GameConfig.GridUpgrades do profile.GridUpgrades[upgrade.Id] = upgrade.MaxLevel end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetTutorial = function(profile, amount, option)
		local changedAmount = amount
				local flags = ProfileBagMath.EnsureFlags(profile)
				flags.TutorialDone = false
				flags.TutorialStep = 1
				flags.TutorialRewardClaimed = false
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetSettings = function(profile, amount, option)
		profile.Settings = table.clone(DataTemplate.New().Settings)
		return { ok = true, amount = amount, note = "saved preferences restored to defaults" }
	end
	profileHandlers.ShowUpdates = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureFlags(profile).LastSeenVersion = ""
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.WipeFlux = function(profile, amount, option)
		local changedAmount = amount
				profile.Cash = 0
				profile.RunCash = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.WipeVault = function(profile, amount, option)
		local changedAmount = amount
			profile.Vault = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.WipeCores = function(profile, amount, option)
		local changedAmount = amount
			profile.Cores = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.WipeStardust = function(profile, amount, option)
		local changedAmount = amount
			profile.Stardust = 0
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetDomainEssence = function(profile, amount, option)
		ProfileBagMath.EnsureDomain(profile).Essence = math.max(0, math.floor(amount))
		return { ok = true, amount = amount }
	end
	profileHandlers.SetItemEssence = function(profile, amount, option)
		ProfileBagMath.EnsureItems(profile).Essence = math.max(0, math.floor(amount))
		return { ok = true, amount = amount }
	end
	profileHandlers.SetSignals = function(profile, amount, option)
		profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
		profile.Command.Signals = math.max(0, math.floor(amount))
		return { ok = true, amount = amount }
	end
	profileHandlers.SetSeasonXP = function(profile, amount, option)
		profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
		profile.Command.SeasonXP = math.max(0, math.floor(amount))
		return { ok = true, amount = amount }
	end
	profileHandlers.SetStreakShields = function(profile, amount, option)
		profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
		profile.Command.StreakShields = math.max(0, math.floor(amount))
		return { ok = true, amount = amount }
	end
	profileHandlers.SetAnomalyFragments = function(profile, amount, option)
		ProfileBagMath.EnsureAnomaly(profile).Fragments = math.max(0, math.floor(amount))
		return { ok = true, amount = amount }
	end
	profileHandlers.GrantVaultFlux = function(profile, amount, option)
		profile.Vault = OmegaMath.Min(OmegaMath.Add(profile.Vault, amount), Economy.Capacity(profile))
		return { ok = true, amount = amount }
	end
	profileHandlers.DoubleFlux = function(profile, amount, option)
		profile.Cash = OmegaMath.Add(profile.Cash, profile.Cash)
		profile.RunCash = OmegaMath.Add(profile.RunCash, profile.RunCash)
		return { ok = true, amount = amount }
	end
	profileHandlers.BankVault = function(profile, amount, option)
		profile.Cash = OmegaMath.Add(profile.Cash, profile.Vault)
		profile.RunCash = OmegaMath.Add(profile.RunCash, profile.Vault)
		profile.Vault = 0
		return { ok = true, amount = amount }
	end
	profileHandlers.WipeItemEssence = function(profile, amount, option)
		ProfileBagMath.EnsureItems(profile).Essence = 0
		return { ok = true, amount = amount }
	end
	profileHandlers.ResetPityAll = function(profile, amount, option)
		local items = ProfileBagMath.EnsureItems(profile)
		for crateId in items.Pity do items.Pity[crateId] = 0 end
		return { ok = true, amount = amount }
	end
	profileHandlers.ResetCommandXP = function(profile, amount, option)
		profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
		profile.Command.XP = 0
		return { ok = true, amount = amount }
	end
	profileHandlers.PennyPinch = function(profile, amount, option)
		local changedAmount = amount
				profile.Cash = 1
				profile.RunCash = 1
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.TaxHalf = function(profile, amount, option)
		local changedAmount = amount
				profile.Cash = OmegaMath.Div(profile.Cash, 2)
				profile.RunCash = OmegaMath.Div(profile.RunCash, 2)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SwapWallet = function(profile, amount, option)
		local changedAmount = amount
				local parked = profile.Cash
				profile.Cash = profile.Vault
				profile.Vault = parked
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.FillVault = function(profile, amount, option)
		local changedAmount = amount
				profile.Vault = Economy.Capacity(profile)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.DrainKeys = function(profile, amount, option)
		local changedAmount = amount
				local keys = ProfileBagMath.EnsureItemKeys(profile)
				for crateId in keys do keys[crateId] = 0 end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.DrainBoosts = function(profile, amount, option)
		local changedAmount = amount
				local inventory = ProfileBagMath.EnsureBoostInventory(profile)
				for boostId in inventory do inventory[boostId] = 0 end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.LockRelics = function(profile, amount, option)
		local changedAmount = amount
				local items = ProfileBagMath.EnsureItems(profile)
				for _, instance in items.Inventory do instance.Locked = true end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.UnlockRelics = function(profile, amount, option)
		local changedAmount = amount
				local items = ProfileBagMath.EnsureItems(profile)
				for _, instance in items.Inventory do instance.Locked = false end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SalvageRelics = function(profile, amount, option)
		local changedAmount = amount
				local items = ProfileBagMath.EnsureItems(profile)
				local kept = {}
				local salvaged = 0
				for uid, instance in items.Inventory do
					local equipped = false
					for _, equippedUid in items.Equipped do
						if equippedUid == uid then equipped = true break end
					end
					if equipped or instance.Locked == true then
						kept[uid] = instance
					else
						salvaged += 1
						items.Essence += 8
					end
				end
				items.Inventory = kept
				changedAmount = salvaged
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetRebirths = function(profile, amount, option)
		local changedAmount = amount
			profile.Rebirths = math.max(0, math.floor(amount))
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetCores = function(profile, amount, option)
		local changedAmount = amount
			profile.Cores = math.max(0, math.floor(amount))
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetStardust = function(profile, amount, option)
		local changedAmount = amount
			profile.Stardust = math.max(0, math.floor(amount))
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetDomainRank = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureDomain(profile).Rank = math.max(0, math.floor(amount))
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantSkillPoints = function(profile, amount, option)
		local changedAmount = amount
				local domain = ProfileBagMath.EnsureDomain(profile)
				domain.SkillPoints = (domain.SkillPoints or 0) + math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetDomain = function(profile, amount, option)
		local changedAmount = amount
				local domain = ProfileBagMath.EnsureDomain(profile)
				domain.Rank = 0
				domain.SkillPoints = 0
				domain.Nodes = {}
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.MaxMachines = function(profile, amount, option)
		local changedAmount = amount
				for _, machine in GameConfig.Machines do profile.Machines[machine.Id] = machine.MaxLevel end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetMachines = function(profile, amount, option)
		local changedAmount = amount
				profile.Machines = { StellarCore = 1 }
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.MaxResearch = function(profile, amount, option)
		local changedAmount = amount
				for _, research in GameConfig.Research do profile.Research[research.Id] = research.MaxLevel end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetResearch = function(profile, amount, option)
		local changedAmount = amount
				profile.Research = {}
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.MaxGrid = function(profile, amount, option)
		local changedAmount = amount
				for _, upgrade in GameConfig.GridUpgrades do profile.GridUpgrades[upgrade.Id] = upgrade.MaxLevel end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetGrid = function(profile, amount, option)
		local changedAmount = amount
				profile.GridUpgrades = {}
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.FillPityAll = function(profile, amount, option)
		local changedAmount = amount
				local items = ProfileBagMath.EnsureItems(profile)
				for crateId in items.Pity do items.Pity[crateId] = 99 end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetTrades = function(profile, amount, option)
		local changedAmount = amount
				if profile.Trade then
					profile.Trade.Completed = 0
					profile.Trade.Day = -1
				end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.ResetDailies = function(profile, amount, option)
		local changedAmount = amount
				ProfileBagMath.EnsureDaily(profile).LastClaimDay = -1
				profile.Wheel = WheelMath.Ensure(profile.Wheel)
				profile.Wheel.LastSpinAt = 0
				if profile.Trade then profile.Trade.Day = -1 end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.InspectMarket = function(profile, amount, option)
		local bag = BazaarMath.Ensure(profile.Bazaar)
		profile.Bazaar = bag
		local bucket = BazaarMath.MarketBucket(os.time())
		local merchant = BazaarMath.Merchant(bucket)
		local rare = BazaarMath.RareOffer(bucket)
		local tier = BazaarMath.Reputation(bag.Counters.Deals)
		local spent = 0
		if bag.Market.Bucket == bucket then for _, count in bag.Market.Bought do spent += count end end
		local request = BazaarMath.RegularById(bag.Market.Procure.Id)
		local last = bag.Market.History[1]
		local lastName = if last then (BazaarMath.CatalogById(last.Pick) or { Name = last.Pick }).Name else "none"
		return { ok = true, amount = amount, note = string.format(
			"Shipment %d by %s; rare: %s. %s standing (%d units), %d bought this shipment, %d receipts, last: %s. Request: %s.",
			bucket, merchant.Name, if rare then rare.Name else "none", tier.Name, bag.Counters.Deals, spent,
			#bag.Market.History, lastName, if request then request.Name else "none"
		) }
	end
	profileHandlers.ResetMarketPurchases = function(profile, amount, option)
		local bag = BazaarMath.Ensure(profile.Bazaar)
		profile.Bazaar = bag
		bag.Market.Bought = {}
		return { ok = true, amount = amount }
	end
	profileHandlers.CancelMarketRequest = function(profile, amount, option)
		local bag = BazaarMath.Ensure(profile.Bazaar)
		profile.Bazaar = bag
		if bag.Market.Procure.Id == "" then return { ok = false, error = "That player has no open supply request." } end
		bag.Market.Procure = { Id = "", Since = 0, Filled = 0 }
		return { ok = true, amount = amount }
	end
	profileHandlers.ZeroZone = function(profile, amount, option)
		local changedAmount = amount
				profile.Zone = 1
				profile.CurrentZone = 1
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantEchoCharge = function(profile, amount, option)
		local changedAmount = amount
				local echoes = EchoMath.ensure(profile.ForgeEchoes)
				profile.ForgeEchoes = echoes
				echoes.Charge += math.floor(amount)
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.MaxCrew = function(profile, amount, option)
		local changedAmount = amount
				profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
				for roleId in profile.Command.Crew do
					profile.Command.Crew[roleId] = 10
				end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.DiscoverArts = function(profile, amount, option)
		local changedAmount = amount
				if GameConfig.Operations and GameConfig.Operations.Artifacts then
					profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
					if type(profile.Command.Artifacts) ~= "table" then
						profile.Command.Artifacts = {}
					end
					for _, artifact in GameConfig.Operations.Artifacts do
						profile.Command.Artifacts[artifact.Id] = profile.Command.Artifacts[artifact.Id]
							or { Level = 1, Fragments = 0 }
					end
				end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.GrantEverything = function(profile, amount, option)
		local changedAmount = amount
				local bundle = math.max(amount, 1e12)
				profile.Cash = OmegaMath.Add(profile.Cash, bundle)
				profile.RunCash = OmegaMath.Add(profile.RunCash, bundle)
				profile.LifetimeCash = OmegaMath.Add(profile.LifetimeCash, bundle)
				profile.Cores += math.max(1000, math.floor(amount))
				profile.Stardust += math.max(100000, math.floor(amount))
				profile.Rebirths += math.max(100, math.floor(amount))
				ProfileBagMath.EnsureDomain(profile).Essence += math.max(100, math.floor(amount))
				ProfileBagMath.EnsureAnomaly(profile).Fragments += math.max(10000, math.floor(amount))
				profile.Command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
				profile.Command.Signals += math.max(10000, math.floor(amount))
				profile.Wheel = WheelMath.Ensure(profile.Wheel)
				profile.Wheel.FreeSpins += math.max(100, math.floor(amount))
				local keys = ProfileBagMath.EnsureItemKeys(profile)
				for crateId in keys do keys[crateId] += 100 end
				local boosts = ProfileBagMath.EnsureBoostInventory(profile)
				for boostId in GameConfig.Boosts do boosts[boostId] = (boosts[boostId] or 0) + 25 end
		return { ok = true, amount = changedAmount }
	end
	profileHandlers.SetFlux = function(profile,amount,option)
		profile.Cash = amount
		return {ok=true,amount=amount}
	end
	profileHandlers.SetVault = function(profile,amount,option)
		profile.Vault = OmegaMath.Min(amount, Economy.Capacity(profile))
		return {ok=true,amount=amount}
	end
	profileHandlers.SetContinuumRank = function(profile,amount,option)
		ProfileBagMath.EnsureContinuum(profile).Rank = math.min(GameConfig.Continuum.MaxRank, amount)
		return {ok=true,amount=amount}
	end
	profileHandlers.SetFreeSpins = function(profile,amount,option)
		profile.Wheel = WheelMath.Ensure(profile.Wheel)
			profile.Wheel.FreeSpins = amount
		return {ok=true,amount=amount}
	end
	profileHandlers.ResetAnomalyCharge = function(profile,amount,option)
		ProfileBagMath.EnsureAnomaly(profile).Charge = 0
		return {ok=true,amount=amount}
	end
	profileHandlers.ClearAnomalyCombo = function(profile,amount,option)
		ProfileBagMath.EnsureAnomaly(profile).Combo = 0
		return {ok=true,amount=amount}
	end

	function AdminService:Execute(actor: Player, payload: any)
		local role = roleFor(actor)
		if not role then return { ok = false, error = "Administrative access denied." } end
		if type(payload) ~= "table" then return { ok = false, error = "Malformed admin request." } end
		-- Server-side authorization: canonicalization only accepts names in the COMMANDS allowlist.
		local command = CommandSchema.canonical(cleanText(payload.Command, 48), COMMANDS)
		local definition = command and COMMANDS[command]
		if not definition then return { ok = false, error = "Unknown admin command." } end
		local permitted, permissionError = AdminPolicy.Allows(role, command :: string, definition)
		if not permitted then return { ok = false, error = permissionError } end
		local dryRun = payload.DryRun == true
		local nonce = cleanText(payload.Nonce, 80)
		if #nonce < 8 or not self:_consumeNonce(actor, nonce) then
			return { ok = false, error = "This admin request was already processed." }
		end
		local reason = cleanText(payload.Reason, 96)
		if #reason < 3 and not dryRun then return { ok = false, error = "Add a short audit reason." } end
		local option = cleanText(payload.Option, 64)
		if definition.Moderation == true then
			local duration, problem = CommandSchema.validate(command,definition,payload.Amount,option)
			if duration == nil then return {ok=false,error=problem} end
			local targetUserId = tonumber(payload.TargetUserId)
			if not targetUserId or targetUserId ~= math.floor(targetUserId) then
				return { ok = false, error = "Pick a player to moderate." }
			end
			if dryRun then
				local subject = Players:GetPlayerByUserId(targetUserId)
				return {
					ok = true,
					DryRun = true,
					message = `Preview: {definition.Label} → {if subject then subject.Name else tostring(targetUserId)}.`,
					Preview = { `{definition.Label}: {if option ~= "" then option else tostring(duration)}` },
					PreviewTotal = 1,
				}
			end
			return self:_moderate(actor, command, targetUserId, duration, option, reason)
		end
		local target = onlinePlayer(payload.TargetUserId)
		if not target or target.Parent ~= Players then return { ok = false, error = "Target must be online in this server." } end
		if not self._data:Get(target) then return { ok = false, error = "Target profile is still loading." } end
		local amount, inputError = CommandSchema.validate(command, definition, payload.Amount, option)
		if amount == nil then return { ok = false, error = inputError } end

		if dryRun then
			if definition.World == true then
				return {
					ok = true,
					DryRun = true,
					message = `Preview: {definition.Label} plays on {target.Name}'s screen only. No saved data changes.`,
					Preview = {},
					PreviewTotal = 0,
				}
			end
			local handler = profileHandlers[command]
			if not handler then return { ok = false, error = "Admin command has no executor." } end
			local before = AdminPolicy.DeepCopy(self._data:Get(target))
			local scratch = AdminPolicy.DeepCopy(before)
			local okRun, applied = pcall(handler, scratch, amount, option)
			if not okRun then return { ok = false, error = "Preview failed: " .. tostring(applied) } end
			if type(applied) == "table" and applied.ok == false then return applied end
			local lines, total = AdminPolicy.Diff(before, scratch, 10)
			local previewNote = if type(applied) == "table" and type(applied.note) == "string" then " " .. applied.note else ""
			return {
				ok = true,
				DryRun = true,
				message = (if total == 0
					then `Preview: {definition.Label} would change nothing for {target.Name}.`
					else `Preview: {total} saved value{if total == 1 then "" else "s"} change for {target.Name}.`) .. previewNote,
				Preview = lines,
				PreviewTotal = total,
			}
		end

		if definition.World == true then
			local ok, worldMessage = applyWorld(actor, target, command, amount, option)
			if not ok then return { ok = false, error = worldMessage } end
			local revision = self._data:GetRevision(target)
			self:_record(actor, target, command, amount, option, reason, revision)
			return {
				ok = true,
				message = worldMessage,
				Admin = self:State(actor),
				TargetUserId = target.UserId,
				World = true,
				Persisted = false,
			}
		end

		local changedAmount = amount
		local note = ""
		local success, result = self._data:AtomicUpdate(target, function(profile)
			local handler = profileHandlers[command]
			if not handler then return {ok=false,error="Admin command has no executor."} end
			local applied = handler(profile,amount,option)
			if applied.ok then
				changedAmount = applied.amount
				note = if type(applied.note) == "string" then " " .. applied.note else ""
			end
			return applied
		end, true, "admin:" .. command)
		if not success then return { ok = false, error = "Profile transaction failed: " .. tostring(result) } end
		if type(result) == "table" and result.ok == false then return result end
		local revision = self._data:GetRevision(target)
		self:_record(actor, target, command, changedAmount, option, reason, revision)

		local persisted = self._data:Save(target, false)
		return {
			ok = true,
			message = string.format(
				"%s applied to %s (revision %d%s).%s",
				definition.Label,
				target.Name,
				revision,
				persisted and ", saved" or ", autosave retry queued",
				note
			),
			Admin = self:State(actor),
			TargetUserId = target.UserId,
			Persisted = persisted,
		}
	end

	local rawExecute = AdminService.Execute
	AdminService.Execute = function(self, actor: Player, payload: any)
		local result = rawExecute(self, actor, payload)
		if type(result) == "table" then
			if self._lastByActor == nil then
				self._lastByActor = {}
			end
			self._lastByActor[actor.UserId] = {
				Ok = result.ok == true,
				Command = type(payload) == "table" and cleanText(payload.Command, 48) or "",
				Message = (result.ok and result.message or result.error) or "",
				At = os.time(),
			}
			if result.Admin ~= nil then
				result.Admin = self:State(actor)
			end
		end
		return result
	end

	return AdminService
end
