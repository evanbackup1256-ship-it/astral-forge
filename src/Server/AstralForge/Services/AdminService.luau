--!strict

return function(loadService: (string) -> any)
	local DataStoreService = game:GetService("DataStoreService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Protocol = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("Protocol"))
	local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Economy"))
	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))
	local ServerTelemetry = loadService("ServerTelemetry")

	local AdminService = {}
	AdminService.__index = AdminService

	local MAX_GRANT = 1e308
	local MAX_AUDIT_MEMORY = 40
	local MAX_AUDIT_PERSISTED = 100
	local NONCE_TTL = 300

	local COMMANDS = table.freeze({
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
		ShowUpdates = { Label = "Show updates again", Option = false, Category = "Resets" },
		GrantEverything = { Label = "Owner grant bundle", Option = false, Category = "Economy" },
		WipeFlux = { Label = "Wipe flux", Option = false, Category = "Resets" },
		WipeVault = { Label = "Wipe vault", Option = false, Category = "Resets" },
		WipeCores = { Label = "Wipe cores", Option = false, Category = "Resets" },
		WipeStardust = { Label = "Wipe stardust", Option = false, Category = "Resets" },
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
		MaxGrid = { Label = "Max Star Grid", Option = false, Category = "Progress" },
		ResetGrid = { Label = "Reset Star Grid", Option = false, Category = "Resets" },
		FillPityAll = { Label = "Max pity on every crate", Option = false, Category = "Items" },
		ResetTrades = { Label = "Reset daily trades", Option = false, Category = "Resets" },
		ResetDailies = { Label = "Reset all daily clocks", Option = false, Category = "Resets" },
		ZeroZone = { Label = "Kick back to world 1", Option = false, Category = "Troll" },
		GrantEchoCharge = { Label = "Grant echo charge", Option = false, Category = "Progress" },
		MaxCrew = { Label = "Max command crew", Option = false, Category = "Progress" },
		DiscoverArts = { Label = "Discover every artifact", Option = false, Category = "Items" },
		Blind = { Label = "Lights out overlay", Option = false, Category = "Troll", World = true },
		FakeBan = { Label = "Fake ban screen", Option = false, Category = "Troll", World = true },
		FakeCrash = { Label = "Fake crash card", Option = false, Category = "Troll", World = true },
		Jumpscare = { Label = "Jumpscare card", Option = false, Category = "Troll", World = true },
		InvertHud = { Label = "Invert their HUD", Option = false, Category = "Troll", World = true },
		SpinHud = { Label = "Spin their HUD", Option = false, Category = "Troll", World = true },
		TinyHud = { Label = "Shrink their HUD", Option = false, Category = "Troll", World = true },
		GiantHud = { Label = "Blow up their HUD", Option = false, Category = "Troll", World = true },
		ShakeHud = { Label = "Shake the shell", Option = false, Category = "Troll", World = true },
		DiscoHud = { Label = "Disco HUD", Option = false, Category = "Troll", World = true },
		RainbowHud = { Label = "Rainbow wash", Option = false, Category = "Troll", World = true },
		ConfettiStorm = { Label = "Confetti tax overlay", Option = false, Category = "Troll", World = true },
		FakeRebirth = { Label = "Fake rebirth prompt", Option = false, Category = "Troll", World = true },
		FakeTrade = { Label = "Fake incoming trade", Option = false, Category = "Troll", World = true },
		FakeRob = { Label = "Fake wallet hack", Option = false, Category = "Troll", World = true },
		LoadingForever = { Label = "Fake endless load", Option = false, Category = "Troll", World = true },
		BlueScreen = { Label = "Fake blue screen", Option = false, Category = "Troll", World = true },
		LowBattery = { Label = "Fake low battery", Option = false, Category = "Troll", World = true },
		UpdateForced = { Label = "Fake forced update", Option = false, Category = "Troll", World = true },
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
		if type(definition.Danger) == "string" and definition.Danger ~= "" then
			return definition.Danger
		end
		local category = definition.Category or "Economy"
		if category == "Troll" or category == "Resets" or category == "Moderation" then
			return "arm"
		end
		return "quick"
	end

	local function finite(value: any): boolean
		return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
	end

	local function boundedAmount(raw: any, fallback: number?): number?
		local value = if type(raw) == "string" then tonumber(raw) else raw
		if value == nil and fallback ~= nil then value = fallback end
		if not finite(value) or value <= 0 then return nil end
		return math.clamp(value, 1, MAX_GRANT)
	end

	local function cleanText(raw: any, maximum: number): string
		if type(raw) ~= "string" then return "" end
		local value = string.gsub(raw, "[%c]", " ")
		value = string.gsub(value, "^%s+", "")
		value = string.gsub(value, "%s+$", "")
		return string.sub(value, 1, maximum)
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
		-- Partial Items bags (Studio fixtures / Keys-only ensure) must not crash GrantRelic.
		if type(profile.Items) ~= "table" then
			profile.Items = { Inventory = {}, NextId = 1, Essence = 0, Keys = {}, Equipped = {}, Discovered = {} }
		end
		if type(profile.Items.Inventory) ~= "table" then
			profile.Items.Inventory = {}
		end
		local count = 0
		for _ in profile.Items.Inventory do count += 1 end
		if count >= GameConfig.Items.InventoryLimit then return false end
		local uid
		repeat
			uid = string.format("IT%07d", math.max(1, math.floor(profile.Items.NextId or 1)))
			profile.Items.NextId = math.max(1, math.floor(profile.Items.NextId or 1)) + 1
		until not profile.Items.Inventory[uid]
		profile.Items.Inventory[uid] = { DefinitionId = definition.Id, Level = 1, AcquiredAt = os.time() }
		-- Partial Stats bags (Studio fixtures) must not crash GrantRelic before the item sticks.
		if type(profile.Stats) ~= "table" then
			profile.Stats = { ItemsFound = 0 }
		end
		profile.Stats.ItemsFound = math.max(0, math.floor(tonumber(profile.Stats.ItemsFound) or 0)) + 1
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
		firePrank(target, command, duration, option)
		return true, string.format("%s HUD prank on %s for %ds.", command, target.Name, duration)
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
		self._auditStore = DataStoreService:GetDataStore(ServerConfig.AdminAuditStoreName)
		self._discordQueueStore = DataStoreService:GetDataStore(ServerConfig.DiscordModQueueStoreName)
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

	-- Drains kick/ban/unban requests the Discord bot queued via Roblox Open
	-- Cloud (see discord-bot/src/commands/game/*.ts). Each queued action is its
	-- own DataStore key ("DiscordMod_<id>") under the DiscordModQueue prefix so
	-- the bot's write (Open Cloud SetAsync-equivalent) never races the game's
	-- read+delete — no shared list, no compare-and-swap needed. Any server can
	-- win the race to claim a given key since RemoveAsync only succeeds once;
	-- _discordSeenIds is just a same-process fast path, not the source of truth.
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
			local advanceOk = pcall(function() pages:AdvanceToNextPageAsync() end)
			if not advanceOk then break end
		end
	end

	function AdminService:_claimDiscordEntry(key: string)
		local entry
		local getOk = pcall(function()
			entry = self._discordQueueStore:GetAsync(key)
		end)
		if not getOk or type(entry) ~= "table" then return end
		-- RemoveAsync first so a crash mid-execution can't replay the action
		-- forever; worst case a transient failure loses one queued action
		-- rather than double-kicking/banning someone.
		local removed = pcall(function()
			self._discordQueueStore:RemoveAsync(key)
		end)
		if not removed then return end
		self:_executeDiscordAction(entry)
	end

	function AdminService:_executeDiscordAction(entry: any)
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
				-- Production/Capacity are EncodeState projections, not persisted profile
				-- fields — reading profile.Production left Admin RATE stuck at 0/s.
				-- Capacity is what FillVault writes to; surface it so operators can see
				-- vault/cap instead of guessing after a fill.
				-- Zone is the unlock watermark (SetZone / achievements / Discord); CurrentZone
				-- is only the visit location — publishing CurrentZone as Zone made WORLD lag
				-- behind unlocks whenever a player stood in an earlier world.
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
			table.insert(commands, {
				Id = id,
				Label = definition.Label,
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

	local AUDIT_ONLY_REASONS = {
		["Owner gameplay administration"] = true,
		["Balance correction"] = true,
		["Playtest grant"] = true,
		["Troll / joke"] = true,
		["Moderation action"] = true,
		["Player request"] = true,
		["Bug recovery"] = true,
		["Trade settle recovery"] = true,
	}

	local function playerFacingReason(command: string, reason: string): string
		if reason ~= "" and AUDIT_ONLY_REASONS[reason] ~= true then
			return reason
		end
		if command == "ServerBan" then
			return "You are banned from this Astral Forge server."
		end
		if command == "GlobalBan" then
			return "You are banned from Astral Forge."
		end
		return "You were kicked from this Astral Forge server by an administrator."
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

	function AdminService:Execute(actor: Player, payload: any)
		local role = roleFor(actor)
		if not role then return { ok = false, error = "Administrative access denied." } end
		if type(payload) ~= "table" then return { ok = false, error = "Malformed admin request." } end
		local command = cleanText(payload.Command, 48)
		local definition = COMMANDS[command]
		if not definition then return { ok = false, error = "Unknown admin command." } end
		local nonce = cleanText(payload.Nonce, 80)
		if #nonce < 8 or not self:_consumeNonce(actor, nonce) then
			return { ok = false, error = "This admin request was already processed." }
		end
		local reason = cleanText(payload.Reason, 96)
		if #reason < 3 then return { ok = false, error = "Add a short audit reason." } end
		local option = cleanText(payload.Option, 64)
		if definition.Moderation == true then
			local targetUserId = tonumber(payload.TargetUserId)
			if not targetUserId or targetUserId ~= math.floor(targetUserId) then
				return { ok = false, error = "Pick a player to moderate." }
			end
			return self:_moderate(actor, command, targetUserId, payload.Amount, option, reason)
		end
		local target = onlinePlayer(payload.TargetUserId)
		if not target or target.Parent ~= Players then return { ok = false, error = "Target must be online in this server." } end
		if not self._data:Get(target) then return { ok = false, error = "Target profile is still loading." } end
		local amount = boundedAmount(payload.Amount, 1)
		if not amount then return { ok = false, error = "Amount must be a positive finite number." } end

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
				Persisted = true,
			}
		end

		local changedAmount = amount
		local success, result = self._data:AtomicUpdate(target, function(profile)
			if command == "GrantFlux" then
				profile.Cash = OmegaMath.Add(profile.Cash, amount)
				profile.RunCash = OmegaMath.Add(profile.RunCash, amount)
				profile.LifetimeCash = OmegaMath.Add(profile.LifetimeCash, amount)
			elseif command == "GrantCores" then profile.Cores += amount
			elseif command == "GrantStardust" then profile.Stardust += amount
			elseif command == "GrantRebirths" then profile.Rebirths += math.floor(amount)
			elseif command == "GrantDomainEssence" then profile.Domain.Essence += math.floor(amount)
			elseif command == "GrantAnomalyFragments" then profile.Anomaly.Fragments += math.floor(amount)
			elseif command == "GrantSignals" then profile.Command.Signals += math.floor(amount)
			elseif command == "GrantCommandXP" then profile.Command.XP += math.floor(amount)
			elseif command == "GrantSeasonXP" then profile.Command.SeasonXP += math.floor(amount)
			elseif command == "GrantStreakShields" then profile.Command.StreakShields += math.floor(amount)
			elseif command == "GrantItemEssence" then profile.Items.Essence += math.floor(amount)
			elseif command == "GrantContinuumRanks" then
				profile.Continuum.Rank = math.min(GameConfig.Continuum.MaxRank, profile.Continuum.Rank + math.floor(amount))
			elseif command == "GrantAnomalyCharge" then profile.Anomaly.Charge += math.floor(amount)
			elseif command == "GrantAnomalyStabilizations" then
				-- Keep Stats in lockstep with Anomaly.Stabilizations — AchievementProgress /
				-- weekly AnomalyStabilizations directives read Stats when the bag is absent,
				-- and AnomalyService.Stabilize always bumps both.
				local n = math.floor(amount)
				profile.Anomaly.Stabilizations += n
				if type(profile.Stats) == "table" then
					profile.Stats.AnomalyStabilizations =
						math.max(0, math.floor(tonumber(profile.Stats.AnomalyStabilizations) or 0)) + n
				end
			elseif command == "GrantFreeSpins" then profile.Wheel.FreeSpins += math.floor(amount)
			elseif command == "GrantCrateKeys" then
				if profile.Items.Keys[option] == nil then return { ok = false, error = "Unknown crate id." } end
				profile.Items.Keys[option] += math.floor(amount)
			elseif command == "GrantAllCrateKeys" then
				for crateId in profile.Items.Keys do profile.Items.Keys[crateId] += math.floor(amount) end
			elseif command == "GrantPity" then
				if profile.Items.Pity[option] == nil then return { ok = false, error = "Unknown crate id." } end
				profile.Items.Pity[option] += math.floor(amount)
			elseif command == "GrantBoost" then
				if not GameConfig.Boosts[option] then return { ok = false, error = "Unknown boost id." } end
				profile.BoostInventory[option] = (profile.BoostInventory[option] or 0) + math.floor(amount)
			elseif command == "GrantAllBoosts" then
				for boostId in GameConfig.Boosts do
					profile.BoostInventory[boostId] = (profile.BoostInventory[boostId] or 0) + math.floor(amount)
				end
			elseif command == "GrantRelic" then
				changedAmount = 0
				for _ = 1, math.min(10, math.floor(amount)) do
					if not createRelic(profile, option) then break end
					changedAmount += 1
				end
				if changedAmount <= 0 then return { ok = false, error = "Relic id is invalid or inventory is full." } end
			elseif command == "ClearActiveBoost" then
				profile.ActiveBoost.Id = ""
				profile.ActiveBoost.EndsAt = 0
			elseif command == "ResetWheelCooldown" then profile.Wheel.LastSpinAt = 0
			elseif command == "ResetDailyClaim" then profile.Daily.LastClaimDay = -1
			elseif command == "ClearVault" then profile.Vault = 0
			elseif command == "SetZone" then
				local zone = math.clamp(math.floor(amount), 1, GameConfig.MaxZone)
				profile.Zone = math.max(profile.Zone, zone)
				profile.CurrentZone = zone
			elseif command == "EnableUnlimitedFlux" then profile.Flags.UnlimitedMoney = true
			elseif command == "DisableUnlimitedFlux" then profile.Flags.UnlimitedMoney = false
			elseif command == "UnlockProgression" then
				profile.Zone = GameConfig.MaxZone
				profile.CurrentZone = profile.Zone
				for _, machine in GameConfig.Machines do profile.Machines[machine.Id] = machine.MaxLevel end
				for _, research in GameConfig.Research do profile.Research[research.Id] = research.MaxLevel end
				for _, upgrade in GameConfig.GridUpgrades do profile.GridUpgrades[upgrade.Id] = upgrade.MaxLevel end
			elseif command == "ResetTutorial" then
				profile.Flags.TutorialDone = false
				profile.Flags.TutorialStep = 1
				profile.Flags.TutorialRewardClaimed = false
			elseif command == "ShowUpdates" then profile.Flags.LastSeenVersion = ""
			elseif command == "WipeFlux" then
				profile.Cash = 0
				profile.RunCash = 0
			elseif command == "WipeVault" then profile.Vault = 0
			elseif command == "WipeCores" then profile.Cores = 0
			elseif command == "WipeStardust" then profile.Stardust = 0
			elseif command == "PennyPinch" then
				profile.Cash = 1
				profile.RunCash = 1
			elseif command == "TaxHalf" then
				profile.Cash = OmegaMath.Div(profile.Cash, 2)
				profile.RunCash = OmegaMath.Div(profile.RunCash, 2)
			elseif command == "SwapWallet" then
				local parked = profile.Cash
				profile.Cash = profile.Vault
				profile.Vault = parked
			elseif command == "FillVault" then
				-- Capacity is computed (Economy.Capacity), never stored on the profile.
				-- profile.Capacity was always nil, so FillVault was a silent no-op.
				profile.Vault = Economy.Capacity(profile)
			elseif command == "DrainKeys" then
				for crateId in profile.Items.Keys do profile.Items.Keys[crateId] = 0 end
			elseif command == "DrainBoosts" then
				for boostId in profile.BoostInventory do profile.BoostInventory[boostId] = 0 end
			elseif command == "LockRelics" then
				for _, instance in profile.Items.Inventory do instance.Locked = true end
			elseif command == "UnlockRelics" then
				for _, instance in profile.Items.Inventory do instance.Locked = false end
			elseif command == "SalvageRelics" then
				local kept = {}
				local salvaged = 0
				for uid, instance in profile.Items.Inventory do
					local equipped = false
					for _, equippedUid in profile.Items.Equipped do
						if equippedUid == uid then equipped = true break end
					end
					if equipped or instance.Locked == true then
						kept[uid] = instance
					else
						salvaged += 1
						profile.Items.Essence += 8
					end
				end
				profile.Items.Inventory = kept
				changedAmount = salvaged
			elseif command == "SetRebirths" then profile.Rebirths = math.max(0, math.floor(amount))
			elseif command == "SetCores" then profile.Cores = math.max(0, math.floor(amount))
			elseif command == "SetStardust" then profile.Stardust = math.max(0, math.floor(amount))
			elseif command == "SetDomainRank" then
				profile.Domain.Rank = math.max(0, math.floor(amount))
			elseif command == "GrantSkillPoints" then
				profile.Domain.SkillPoints = (profile.Domain.SkillPoints or 0) + math.floor(amount)
			elseif command == "ResetDomain" then
				profile.Domain.Rank = 0
				profile.Domain.SkillPoints = 0
				profile.Domain.Nodes = {}
			elseif command == "MaxMachines" then
				for _, machine in GameConfig.Machines do profile.Machines[machine.Id] = machine.MaxLevel end
			elseif command == "ResetMachines" then
				profile.Machines = { StellarCore = 1 }
			elseif command == "MaxResearch" then
				for _, research in GameConfig.Research do profile.Research[research.Id] = research.MaxLevel end
			elseif command == "ResetResearch" then
				profile.Research = {}
			elseif command == "MaxGrid" then
				for _, upgrade in GameConfig.GridUpgrades do profile.GridUpgrades[upgrade.Id] = upgrade.MaxLevel end
			elseif command == "ResetGrid" then
				profile.GridUpgrades = {}
			elseif command == "FillPityAll" then
				for crateId in profile.Items.Pity do profile.Items.Pity[crateId] = 99 end
			elseif command == "ResetTrades" then
				if profile.Trade then
					profile.Trade.Completed = 0
					profile.Trade.Day = -1
				end
			elseif command == "ResetDailies" then
				profile.Daily.LastClaimDay = -1
				profile.Wheel.LastSpinAt = 0
				if profile.Trade then profile.Trade.Day = -1 end
			elseif command == "ZeroZone" then
				profile.Zone = 1
				profile.CurrentZone = 1
			elseif command == "GrantEchoCharge" then
				if profile.ForgeEchoes then profile.ForgeEchoes.Charge += math.floor(amount) end
			elseif command == "MaxCrew" then
				if profile.Command and profile.Command.Crew then
					for role in profile.Command.Crew do profile.Command.Crew[role] = 10 end
				end
			elseif command == "DiscoverArts" then
				if GameConfig.Operations and GameConfig.Operations.Artifacts then
					for _, artifact in GameConfig.Operations.Artifacts do
						profile.Command.Artifacts[artifact.Id] = profile.Command.Artifacts[artifact.Id] or { Level = 1, Fragments = 0 }
					end
				end
			elseif command == "GrantEverything" then
				local bundle = math.max(amount, 1e12)
				profile.Cash = OmegaMath.Add(profile.Cash, bundle)
				profile.RunCash = OmegaMath.Add(profile.RunCash, bundle)
				profile.LifetimeCash = OmegaMath.Add(profile.LifetimeCash, bundle)
				profile.Cores += math.max(1000, math.floor(amount))
				profile.Stardust += math.max(100000, math.floor(amount))
				profile.Rebirths += math.max(100, math.floor(amount))
				profile.Domain.Essence += math.max(100, math.floor(amount))
				profile.Anomaly.Fragments += math.max(10000, math.floor(amount))
				profile.Command.Signals += math.max(10000, math.floor(amount))
				profile.Wheel.FreeSpins += math.max(100, math.floor(amount))
				for crateId in profile.Items.Keys do profile.Items.Keys[crateId] += 100 end
				for boostId in GameConfig.Boosts do profile.BoostInventory[boostId] = (profile.BoostInventory[boostId] or 0) + 25 end
			else return { ok = false, error = "Admin command has no executor." } end
			return { ok = true }
		end, true, "admin:" .. command)
		if not success then return { ok = false, error = "Profile transaction failed: " .. tostring(result) } end
		if type(result) == "table" and result.ok == false then return result end
		local revision = self._data:GetRevision(target)
		self:_record(actor, target, command, changedAmount, option, reason, revision)

		local persisted = self._data:Save(target, false)
		return {
			ok = true,
			message = string.format(
				"%s applied to %s (revision %d%s).",
				definition.Label,
				target.Name,
				revision,
				persisted and ", saved" or ", autosave retry queued"
			),
			Admin = self:State(actor),
			TargetUserId = target.UserId,
			Persisted = persisted,
		}
	end

	local rawExecute = AdminService.Execute
	function AdminService:Execute(actor: Player, payload: any)
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
