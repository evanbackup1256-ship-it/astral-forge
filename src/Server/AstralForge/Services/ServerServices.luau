--!strict

local serviceFactories: { [string]: () -> any } = {}
local serviceCache: { [string]: any } = {}
local serviceLoaded: { [string]: boolean } = {}
local serviceLoading: { [string]: boolean } = {}
local loadService: (string) -> any

serviceFactories["AdminService"] = function() return require(script.Parent:WaitForChild("AdminService"))(loadService) end

serviceFactories["AnomalyService"] = function() return require(script.Parent:WaitForChild("CoreServices"))("AnomalyService")(loadService) end


serviceFactories["BazaarService"] = function() return require(script.Parent:WaitForChild("BazaarService"))(loadService) end
serviceFactories["EncounterService"] = function() return require(script.Parent:WaitForChild("EncounterService"))(loadService) end
serviceFactories["SpecializationService"] = require(script.Parent:WaitForChild("SpecializationService"))


serviceFactories["AtomicState"] = require(script.Parent:WaitForChild("SecurityServices"))("AtomicState")

serviceFactories["CharacterIntegrity"] = function() return require(script.Parent:WaitForChild("CharacterIntegrity"))(loadService) end

serviceFactories["ConvergenceService"] = require(script.Parent:WaitForChild("ConvergenceService"))

serviceFactories["DataService"] = function() return require(script.Parent:WaitForChild("DataService"))(loadService) end

serviceFactories["ForgeEchoService"] = require(script.Parent:WaitForChild("CoreServices"))("ForgeEchoService")

serviceFactories["FluxSurgeService"] = require(script.Parent:WaitForChild("FluxSurgeService"))
serviceFactories["ServerEventService"] = require(script.Parent:WaitForChild("CoreServices"))("ServerEventService")

serviceFactories["GameAntiCheat"] = require(script.Parent:WaitForChild("GameAntiCheat"))

serviceFactories["GameService"] = function()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = game:GetService("HttpService")
	local ServerStorage = game:GetService("ServerStorage")

	local ModuleLog = require(script.Parent.Parent:WaitForChild("ModuleLog"))
	local Economy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("Economy")
	local Format = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("Format")
	local LeaderboardCodec = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("LeaderboardCodec"))
	local ProgressionGate = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("ProgressionGate")
	local SharedDataSuite = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
	local LevelRewards = SharedDataSuite("LevelRewards")
	local ForgeLevels = SharedDataSuite("ForgeLevels")
	local RebirthGate = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("RebirthGate")
	local TradeDesk = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("TradeSuite"))("TradeDesk")
	local TradeSettle = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("TradeSuite"))("TradeSettle")
	local TradeRecovery = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("TradeSuite"))("TradeRecovery")
	local TradeHistory = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("TradeHistory"))
	local ChatRules = require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ChatRules"))
	local CrateRoll = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("CrateRoll")
	local CrateRollResolver = require(script.Parent.Parent.Modules.CrateRollResolver)
	local CrateConfig = require(ReplicatedStorage.AstralForge.Shared.CrateConfig)
	local ShopGrantEligibility = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ShopGrantEligibility")
	local CommandActionValidators = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("CommandActionValidators")
	local SocialBoost = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("SocialBoost")
	local ItemSalvage = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ItemSalvage")
	local VisitSnapshot = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("VisitSnapshot")
	local PublicPlayerRecord = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("PublicPlayerRecord")
	local ReportLedger = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ReportLedger")
	local SettingsSeal = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("SettingsSeal")
	local UnlimitedMoneySeal = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("UnlimitedMoneySeal")
	local StoryMailSnapshot = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("StoryMailSnapshot")
	local VisitorList = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("VisitorList")
	local AutoSalvageSnapshot = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("AutoSalvageSnapshot")
	local OverchargeCombo = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("OverchargeCombo")
	local RankBracket = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("RankBracket")
	local ActionFeatureMaps = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ActionFeatureMaps")
	local ActionResponse = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ActionResponse")
	local GeneralBoardValue = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("GeneralBoardValue")
	local TelemetryMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("TelemetryMath")
	local UtcClockMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("UtcClockMath")
	local DataSanitizeMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("DataSanitizeMath"))
	local ProfileBagMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileBagMath"))
	local ProfileClampMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ProfileClampMath")
	local CommandMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("CommandMath"))
	local ContinuumDomainMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("ContinuumDomainMath")
	local ItemLoadoutMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ProfileMath"))("ItemLoadoutMath")
	local GuildMath = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("OpsMath"))("GuildMath")
	local ForgePathClaim = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("ForgePathClaim")
	local OfflineProjection = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("EconomyMath"))("OfflineProjection")
	local ReceiptLedger = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ReceiptLedger"))
	local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Protocol = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("Protocol"))
	local MonetizationConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("MonetizationConfig")
	local ZoneUnlock = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("ZoneUnlock")
	local MobileLayoutSlots = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("MobileLayoutSlots"))
	local ProgressionService = loadService("ProgressionService")
	local AnomalyService = loadService("AnomalyService")
	local LabService = loadService("LabService")
	local GuildService = loadService("GuildService")
	local MatterRuntime = loadService("MatterRuntime")
	local RemoteFirewall = loadService("RemoteFirewall")
	local SessionGate = loadService("SessionGate")
	local GameAntiCheat = loadService("GameAntiCheat")
	local ConvergenceService = loadService("ConvergenceService")
	local PlayerAnalytics = loadService("PlayerAnalytics")
	local PlayerBadges = loadService("PlayerBadges")
	local ForgeEchoService = loadService("ForgeEchoService")
	local BazaarService = loadService("BazaarService")
	local EncounterService = loadService("EncounterService")
	local Specializations = loadService("SpecializationService")
	local GuildCommunity = require(script.Parent:WaitForChild("GuildCommunity"))
	local ChatService = require(script.Parent:WaitForChild("ChatService"))
	local CrewService = require(script.Parent:WaitForChild("CrewService"))
	local FluxSurgeService = loadService("FluxSurgeService")
	local ServerEventService = loadService("ServerEventService")
	local ServerConfig = require(script.Parent.Parent:WaitForChild("ServerConfig"))

	local GameService = {}
	GameService.__index = GameService

	-- guild kick/ban/reconcile paths reset bonuses; this lived only in CoreServices before
	local function emptyBonuses()
		return GuildMath.EmptyBonuses()
	end

	local MAX_SAFE_CURRENCY = 1e308
	local AUTO_FORGE_INTERVAL = 2
	local PROFILE_MAINTENANCE_INTERVAL = 10
	local GUILD_REFRESH_INTERVAL = 30
	local GLOBAL_LB_PAGE = 25
	local RANK_PING_INTERVAL = 20

	local function applySocialBoost(profile, friendCount: number, premium: boolean): boolean
		return SocialBoost.Apply(profile, friendCount, premium, GameConfig.Social)
	end

	local GENERAL_BOARD_STORE_NAMES = {
		Flux = ServerConfig.LeaderboardStoreName,
		Rebirths = ServerConfig.RebirthLeaderboardStoreName,
		PlayTime = ServerConfig.PlayTimeLeaderboardStoreName,
		Dust = ServerConfig.DustLeaderboardStoreName,
		Cores = ServerConfig.CoresLeaderboardStoreName,
		Domain = ServerConfig.DomainLeaderboardStoreName,
		Worlds = ServerConfig.WorldLeaderboardStoreName,
		Crates = ServerConfig.CratesLeaderboardStoreName,
		Finds = ServerConfig.FindsLeaderboardStoreName,
		Ore = ServerConfig.OreLeaderboardStoreName,
		Wardens = ServerConfig.WardensLeaderboardStoreName,
		Orders = ServerConfig.OrdersLeaderboardStoreName,
		Stars = ServerConfig.StarsLeaderboardStoreName,
		Cipher = ServerConfig.CipherLeaderboardStoreName,
	}

	local function generalBoardValue(profile, id: string)
		return GeneralBoardValue.Of(profile, id, Economy.Persist)
	end

	local anomalyChargeByAction = ActionFeatureMaps.ANOMALY_CHARGE

	local function telemetryNumber(value: any): number
		return TelemetryMath.Number(value, Economy.AsNumber)
	end

	local function encodeTelemetry(
		revision: number,
		settings,
		cash: number,
		vault: number,
		production: number,
		capacity: number,
		cores: number,
		stardust: number
	): buffer
		return TelemetryMath.Encode(
			revision,
			settings,
			cash,
			vault,
			production,
			capacity,
			cores,
			stardust,
			Economy.AsNumber
		)
	end

	local anomalySignalByAction = ActionFeatureMaps.ANOMALY_SIGNAL
	local featureByAction = ActionFeatureMaps.FEATURE

	local function enforceUnlimitedMoney(profile)
		UnlimitedMoneySeal.Apply(profile, MAX_SAFE_CURRENCY, Economy)
	end

	local itemById = {}
	local crateById = {}
	local itemOfferById = {}
	local storyById = {}
	local mailById = {}
	for _, definition in GameConfig.Items.Definitions do
		itemById[definition.Id] = definition
	end
	for _, crate in GameConfig.Items.Crates do
		crateById[crate.Id] = crate
	end
	for _, offer in GameConfig.Items.ShopOffers do
		itemOfferById[offer.Id] = offer
	end
	for _, chapter in GameConfig.Story do
		storyById[chapter.Id] = chapter
	end
	for _, message in GameConfig.Mail do
		mailById[message.Id] = message
	end

	local function utcDay(): number
		return UtcClockMath.Day(os.time())
	end

	local function nextUtcMidnight(): number
		return UtcClockMath.NextMidnight(os.time())
	end

	local function offerStockMax(offer): number
		return ShopGrantEligibility.StockMax(offer)
	end

	local function inventoryCount(profile): number
		local items = ProfileBagMath.EnsureItems(profile)
		return ShopGrantEligibility.InventoryCount(items.Inventory)
	end

	local function ensureItemShop(profile): boolean
		local items = ProfileBagMath.EnsureItems(profile)
		return ShopGrantEligibility.EnsureShop(items.Shop, GameConfig.Items.ShopOffers, utcDay())
	end

	local function ensureStats(profile)
		return ProfileBagMath.EnsureStats(profile)
	end

	local function bumpStat(profile, key: string, amount: number?)
		return ProfileBagMath.BumpStat(profile, key, amount)
	end

	local function ensureActiveBoost(profile)
		return ProfileBagMath.EnsureActiveBoost(profile)
	end

	local function ensureBoostInventory(profile)
		return ProfileBagMath.EnsureBoostInventory(profile)
	end

	local function ensureCommandMastery(profile)
		local command = CommandMath.Ensure(profile.Command, GameConfig.Operations.SeasonId)
		profile.Command = command
		return command.MachineMastery
	end

	local function copyDictionary(source)
		return DataSanitizeMath.DeepCopy(source)
	end

	local function responseError(message: string)
		return ActionResponse.Error(message)
	end

	local function responseSuccess(message: string?, extra)
		return ActionResponse.Success(message, extra)
	end

	local function publicPlayerRecord(player: Player, profile, viewer: Player, presence)
		return PublicPlayerRecord.Build(player, profile, viewer, presence, {
			EnsureItems = ProfileBagMath.EnsureItems,
			itemById = itemById,
			Economy = Economy,
		})
	end

	local function buildVisitSnapshot(player: Player, profile)
		return VisitSnapshot.Build(player, profile, Economy)
	end

	function GameService:_visitorList(host: Player)
		return VisitorList.Build(self._visitors[host.UserId], function(visitor)
			return visitor.Parent == Players
		end)
	end

	function GameService:_clearVisit(visitor: Player, notifyHost: boolean)
		local hostUserId = self._visiting[visitor]
		if hostUserId == nil then
			return
		end
		self._visiting[visitor] = nil
		local bucket = self._visitors[hostUserId]
		if bucket then
			bucket[visitor] = nil
			if next(bucket) == nil then
				self._visitors[hostUserId] = nil
			end
		end
		if not notifyHost then
			return
		end
		for _, host in Players:GetPlayers() do
			if host.UserId == hostUserId then
				self:_toastPlayer(host, "Visitor left", visitor.DisplayName .. " headed home.", "Info")
				self:_pushState(host)
				break
			end
		end
	end

	function GameService:_broadcastVisit(host: Player)
		local bucket = self._visitors[host.UserId]
		if not bucket then
			return
		end
		local profile = self._data:Get(host)
		if not profile then
			return
		end
		local visit = buildVisitSnapshot(host, profile)
		for visitor in bucket do
			if visitor.Parent == Players then
				self._effect:FireClient(visitor, {
					Type = "VisitUpdate",
					Visit = visit,
				})
			end
		end
	end

	function GameService:_visitPlot(visitor: Player, rawUserId: any)
		local extracted = if RemoteFirewall.ExtractUserId then RemoteFirewall.ExtractUserId(rawUserId) else rawUserId

		local userId = RemoteFirewall.CoerceUserId(extracted)
		if userId == nil then
			userId = RemoteFirewall.CoerceUserId(rawUserId)
		end
		if userId == nil then
			return responseError("That workshop could not be found.")
		end
		if userId == visitor.UserId then
			return responseError("You're already at your own workshop.")
		end
		local host = Players:GetPlayerByUserId(userId)
		if not host then
			return responseError("That player is no longer in this server.")
		end
		local profile = self._data:Get(host)
		if not profile then
			return responseError("Their workshop is still loading.")
		end

		self:_clearVisit(visitor, true)
		self._visiting[visitor] = host.UserId
		local bucket = self._visitors[host.UserId]
		if not bucket then
			bucket = {}
			self._visitors[host.UserId] = bucket
		end
		bucket[visitor] = true

		local visit = buildVisitSnapshot(host, profile)
		self:_toastPlayer(host, "Someone stopped by", visitor.DisplayName .. " is checking out your shop.", "Special")
		self:_pushState(host)

		local visitorSnap = self:_snapshot(visitor)
		self:_pushState(visitor)
		return responseSuccess("Visiting " .. host.DisplayName .. ".", { Visit = visit, State = visitorSnap })
	end

	function GameService:_leavePlot(visitor: Player)
		if self._visiting[visitor] == nil then
			return responseSuccess("Already back at your workshop.")
		end
		self:_clearVisit(visitor, true)
		self._effect:FireClient(visitor, { Type = "VisitEnded" })
		return responseSuccess("Back at your workshop.")
	end

	function GameService:_nudgeCrew(sender: Player, rawUserId: any)
		local extracted = if RemoteFirewall.ExtractUserId then RemoteFirewall.ExtractUserId(rawUserId) else rawUserId
		local userId = RemoteFirewall.CoerceUserId(extracted) or RemoteFirewall.CoerceUserId(rawUserId)
		if userId == nil then
			return responseError("Couldn't find that crew member.")
		end
		if userId == sender.UserId then
			return responseError("Wave at someone else.")
		end
		local target = Players:GetPlayerByUserId(userId)
		if not target then
			return responseError("They're not in this server anymore.")
		end

		self._effect:FireClient(target, {
			Type = "CrewNudge",
			FromUserId = sender.UserId,
			FromName = sender.DisplayName,
		})
		return responseSuccess("Waved at " .. target.DisplayName .. ".")
	end

	local PRESENCE_PAGES = {
		Overview = true, Workshop = true, Inventory = true, Research = true, StarGrid = true,
		Echoes = true, Continuum = true, Lab = true, Anomaly = true, Worlds = true,
		Missions = true, Wheel = true, Bazaar = true, Salvage = true, Trials = true, Rewards = true, Command = true, Story = true, Mail = true,
		Chat = true, Crew = true, Milestones = true, Convergence = true, Leaderboards = true,
		Trade = true, Credits = true, Admin = true, Settings = true, Shop = true,
	}

	function GameService:_reportPresence(player: Player, payload: any)
		local page = payload and payload.Page
		if type(page) == "string" and PRESENCE_PAGES[page] then
			self._presence[player.UserId] = { Page = page, UpdatedAt = os.time() }
		end
		if payload == nil or payload.Gen == nil then
			local gen, nonce = self._session:Hello(player)
			return responseSuccess(nil, { Gen = gen, N = nonce })
		end
		local ok, reason, gen, nonce = self._session:Beat(player, payload.Gen, payload.Id, payload.N)
		if not ok and reason ~= "late" then
			ModuleLog.Every(
				string.format("beat:%d", player.UserId),
				15,
				"auth",
				string.format("u=%d beat rejected %s", player.UserId, tostring(reason))
			)
		end
		return responseSuccess(nil, { Gen = gen, N = nonce, Auth = ok })
	end

	function GameService:_getPlayers(viewer: Player)
		local records = {}
		for _, target in Players:GetPlayers() do
			local profile = self._data:Get(target)
			if profile then
				table.insert(records, publicPlayerRecord(target, profile, viewer, self._presence))
			end
		end
		table.sort(records, function(left, right)
			if left.IsLocal ~= right.IsLocal then
				return left.IsLocal
			end
			return left.Production > right.Production
		end)
		return responseSuccess(nil, { Players = records })
	end

	function GameService:_pushTradePartners(hostId: number, guestId: number)
		for _, userId in { hostId, guestId } do
			local other = Players:GetPlayerByUserId(userId)
			if other then
				self:_pushState(other, true)
			end
		end
	end

	function GameService:_tradeAction(player: Player, action: string, payload: any)
		local profile = self._data:Get(player)
		if not profile then
			return responseError("Profile is still loading.")
		end
		local now = os.time()
		if action == Protocol.Actions.GetTrade then
			return responseSuccess(nil)
		end
		local liveSession = self._trades:SessionFor(player.UserId)
		if not self._trades:Unlocked(profile) then
			return responseError("Trade Floor unlocks after your first rebirth.")
		end
		if action == Protocol.Actions.InviteTrade then
			local userId = RemoteFirewall.CoerceUserId(payload.UserId)
			if userId == nil then
				return responseError("Choose a player to invite.")
			end
			if not self._trades:Unlocked(profile) then
				return responseError("Trade Floor unlocks after your first rebirth.")
			end
			local target = Players:GetPlayerByUserId(userId)
			local targetProfile = target and self._data:Get(target)
			if targetProfile and not self._trades:Unlocked(targetProfile) then
				return responseError("They have not unlocked Trade Floor yet.")
			end
			-- the target's Social setting decides who may invite them
			local tradePolicy = targetProfile and targetProfile.Settings and targetProfile.Settings.TradeInvitePolicy
			if target and type(tradePolicy) == "number" and tradePolicy >= 0.25 then
				local okFriend, isFriend = pcall(function() return target:IsFriendsWith(player.UserId) end)
				if not ChatRules.allows(tradePolicy, okFriend and isFriend == true) then
					return responseError(if tradePolicy >= 0.75 then `{target.DisplayName} isn't taking trade invites.` else `{target.DisplayName} only takes trade invites from friends.`)
				end
			end
			local ok, err = self._trades:Invite(player, profile, userId, now)
			if not ok then
				return responseError(err)
			end
			if target then
				self:_toastPlayer(target, "Trade invite", player.DisplayName .. " wants to trade. Open Trade to accept.", "Info")
				self:_pushState(target, true)
			end
			self:_pushState(player, true)
			return responseSuccess("Invite sent.")
		elseif action == Protocol.Actions.RespondTrade then
			local accept = payload.Accept == true
			local ok, err, session, fromId = self._trades:Respond(player, profile, accept, now)
			if not ok then
				return responseError(err)
			end
			if fromId then
				local host = Players:GetPlayerByUserId(fromId)
				if host then
					self:_toastPlayer(host, accept and "Trade opened" or "Invite declined", accept and (player.DisplayName .. " accepted.") or (player.DisplayName .. " declined."), accept and "Success" or "Info")
					self:_pushState(host, true)
				end
			end
			if session then
				self:_pushTradePartners(session.Host, session.Guest)
			end
			return responseSuccess(accept and "Trade opened." or "Invite declined.")
		elseif action == Protocol.Actions.UpdateTradeOffer then
			local ok, err, session = self._trades:UpdateOffer(player, profile, payload.Offer, now)
			if not ok then
				return responseError(err)
			end
			if session then
				self:_pushTradePartners(session.Host, session.Guest)
			end
			return responseSuccess("Offer updated.")
		elseif action == Protocol.Actions.SetTradeReady then
			local ok, err, session = self._trades:SetReady(player, profile, payload.Ready == true, now)
			if not ok then
				return responseError(err)
			end
			if session then
				self:_pushTradePartners(session.Host, session.Guest)
			end
			return responseSuccess(payload.Ready == true and "You are ready." or "Ready cleared.")
		elseif action == Protocol.Actions.ConfirmTrade then
			local ok, err, session = self._trades:Confirm(player, now)
			if not ok then
				return responseError(err)
			end
			if session and session.Confirmed[session.Host] and session.Confirmed[session.Guest] then
				if not self._trades:TryBeginSettle(session) then
					self:_pushTradePartners(session.Host, session.Guest)
					return responseSuccess("Trade is settling.")
				end
				local host = Players:GetPlayerByUserId(session.Host)
				local guest = Players:GetPlayerByUserId(session.Guest)
				local hostProfile = host and self._data:Get(host)
				local guestProfile = guest and self._data:Get(guest)
				if not host or not guest or not hostProfile or not guestProfile then
					self._trades:FailSettle(session, false)
					self._trades:Cancel(player)
					return responseError("A trader left before the swap finished.")
				end
				local plan, planErr = self._trades:Plan(session, hostProfile, guestProfile, now)
				if not plan then
					self._trades:FailSettle(session, false)
					self:_pushTradePartners(session.Host, session.Guest)
					return responseError(planErr or "That trade could not be settled.")
				end

				-- One side's record of this trade: what it gave and what it got, with item names.
				local function tradeHistoryEntry(tradeSession, partner: Player, gave, gaveItems, got, gotItems, at: number)
					local function names(snapshot)
						local list = {}
						for _, instance in (snapshot or {}) do
							local definition = type(instance) == "table" and itemById[instance.DefinitionId]
							table.insert(list, if definition then definition.Name else "an item")
						end
						return list
					end
					local function amount(value)
						local number = tonumber(value)
					if number == nil then
						return require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath")).ToString(value)
					end
					for _, step in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
						if math.abs(number) >= step[1] then
							return (string.gsub(string.format("%.1f%s", number / step[1], step[2]), "%.0(%a)", "%1"))
						end
					end
					return tostring(math.floor(number))
					end
					return {
						Id = tostring(tradeSession.Id), At = at, PartnerId = partner.UserId, Partner = partner.DisplayName,
						Gave = TradeHistory.summarize(gave, names(gaveItems), amount),
						Got = TradeHistory.summarize(got, names(gotItems), amount),
					}
				end

				-- Durability hook: stamp a per-profile fault journal so a faulted trade
				-- can be reconciled the next time the affected profile loads.
				local function writeTradeJournal(targetPlayer: Player, side: string, status: string, reason: string?)
					if status ~= "faulted" then
						return
					end
					local ok, err = pcall(function()
						return self._data:AtomicUpdate(targetPlayer, function(profile)
							local entry = TradeRecovery.MakeFaultedEntry(session, side, plan, reason or "unknown", now)
							profile.Trade.FaultedJournal = entry
							return { ok = true }
						end, true, "trade-journal-" .. side)
					end)
					if not ok then
						ModuleLog.Warn(
							"Trade",
							string.format("Could not write %s fault journal: %s", side, tostring(err))
						)
					end
				end

				local outcome = TradeSettle.RunHostGuest(session, {
					plan = plan,
					applyHost = function()
						return self._data:AtomicUpdate(host, function(profile)
							local applyErr = self._trades:ApplyExchange(
								profile,
								plan.HostOffer,
								plan.GuestOffer,
								plan.HostItems,
								plan.GuestItems,
								plan.Now
							)
							if applyErr then
								return { ok = false, error = applyErr }
							end
							-- history commits in the same save as the exchange
							TradeHistory.record(profile.Trade, tradeHistoryEntry(session, guest, plan.HostOffer, plan.HostItems, plan.GuestOffer, plan.GuestItems, plan.Now))
							return { ok = true }
						end, true, "trade-host")
					end,
					guestPresent = function()
						return self._data:Get(guest) ~= nil
					end,
					applyGuest = function()
						return self._data:AtomicUpdate(guest, function(profile)
							local applyErr = self._trades:ApplyExchange(
								profile,
								plan.GuestOffer,
								plan.HostOffer,
								plan.GuestItems,
								plan.HostItems,
								plan.Now
							)
							if applyErr then
								return { ok = false, error = applyErr }
							end
							TradeHistory.record(profile.Trade, tradeHistoryEntry(session, host, plan.GuestOffer, plan.GuestItems, plan.HostOffer, plan.HostItems, plan.Now))
							return { ok = true }
						end, true, "trade-guest")
					end,
					revertHostOnce = function()
						local revertOk, revertResult = self._data:AtomicUpdate(host, function(profile)
							self._trades:RevertExchange(
								profile,
								plan.HostOffer,
								plan.GuestOffer,
								plan.HostItems,
								plan.GuestItems,
								plan.Now
							)
							-- a reverted side never happened, so its history entry goes too
							TradeHistory.remove(profile.Trade, tostring(session.Id))
							return { ok = true }
						end, true, "trade-revert")
						return TradeSettle.IsCommitOk(revertOk, revertResult)
					end,
					writeHostJournal = function(status: string, reason: string?)
						writeTradeJournal(host, "host", status, reason)
					end,
					writeGuestJournal = function(status: string, reason: string?)
						writeTradeJournal(guest, "guest", status, reason)
					end,
				})
				self:_pushTradePartners(session.Host, session.Guest)
				if not outcome.ok then
					if type(outcome.log) == "string" then
						ModuleLog.Warn(
							"Trade",
							outcome.log,
							{ SessionId = session.Id, Host = session.Host, Guest = session.Guest }
						)
					end
					return responseError(outcome.message or "That trade could not be settled.")
				end
				self._trades:Close(session)
				self:_toastPlayer(host, "Trade complete", "The exchange is locked in.", "Success")
				self:_toastPlayer(guest, "Trade complete", "The exchange is locked in.", "Success")
				return responseSuccess("Trade complete.")
			end
			if session then
				self:_pushTradePartners(session.Host, session.Guest)
			end
			return responseSuccess("Confirmation noted.")
		elseif action == Protocol.Actions.TradeViewAway then
			local session = self._trades:SessionFor(player.UserId)
			if not session then
				return responseSuccess()
			end
		local otherId = session.Host == player.UserId and session.Guest or session.Host
		local other = Players:GetPlayerByUserId(otherId)
			if other then
				if payload and payload.Away == true then
					self:_toastPlayer(other, "Trade", player.DisplayName .. " stepped away from the table.", "Info")
				else
					self:_toastPlayer(other, "Trade", player.DisplayName .. " is back at the table.", "Info")
				end
			end
			return responseSuccess()
		elseif action == Protocol.Actions.CancelTrade then
			local session, otherId, cancelErr = self._trades:Cancel(player)
			if cancelErr then
				return responseError(cancelErr)
			end
			if otherId then
				local other = Players:GetPlayerByUserId(otherId)
				if other then
					self:_toastPlayer(other, "Trade cancelled", player.DisplayName .. " closed the table.", "Info")
					self:_pushState(other, true)
				end
			end
			if session then
				return responseSuccess("Trade cancelled.")
			end
			return responseSuccess("Invite cleared.")
		end
		return responseError("Unknown trade action.")
	end

	function GameService:_getPlayerMirror(viewer: Player, rawUserId: any)
		local extracted = if RemoteFirewall.ExtractUserId then RemoteFirewall.ExtractUserId(rawUserId) else rawUserId
		local userId = RemoteFirewall.CoerceUserId(extracted) or RemoteFirewall.CoerceUserId(rawUserId)
		if userId == nil then
			return responseError("That player could not be found.")
		end
		local target = Players:GetPlayerByUserId(userId)
		if target then
			local profile = self._data:Get(target)
			if profile then
				return responseSuccess(nil, { Mirror = publicPlayerRecord(target, profile, viewer, self._presence) })
			end
		end
		return responseError("That player is no longer in this server.")
	end


	local StoreAccess = require(script.Parent.Parent.Modules.StoreAccess)
	local getOrderedStore = StoreAccess.ordered
	local getDataStore = StoreAccess.data
	local previewEnabled = StoreAccess.isPreview()

	function GameService.new(dataService, worldService, fluxSurgeService, remotes)
		local self = setmetatable({}, GameService)
		self._data = dataService
		self._world = worldService
		self._fluxSurge = fluxSurgeService
		self._request = remotes.Request
		self._state = remotes.State
		self._toast = remotes.Toast
		self._effect = remotes.Effect
		self._security = remotes.Security
		self._admin = remotes.Admin
		self._runtime = {}
		self._visiting = {}
		self._visitors = {}
		self._presence = {}
		self._matter = MatterRuntime.new(self)
		self._matterAccumulator = 0
		self._rankPingAccumulator = 0
		self._rankPingBusy = false
		self._firewall = RemoteFirewall.new()
		self._session = SessionGate.new()
		self._antiCheat = GameAntiCheat.new()
		self._analytics = PlayerAnalytics.new()
		self._badges = PlayerBadges.new()
		self._convergence = ConvergenceService.new(dataService)
		self._events = ServerEventService.new({
			random = function()
				return self._random:NextNumber()
			end,
			announce = function(phase, def)
				self:_announceServerEvent(phase, def)
			end,
			broadcast = function()
				for _, online in Players:GetPlayers() do
					self._effect:FireClient(online, { Type = "ServerEvent", Event = self._events:State(online) })
				end
			end,
			payout = function(ranking, def)
				self:_payCommunityForge(ranking, def)
			end,
		})
		self._guilds = GuildService.new()
		self._guildCommunity = GuildCommunity.new(self._guilds, dataService, self._security, self._effect, function(target: Player, guildId: string)
			local updated, result = self._data:AtomicUpdate(target, function(targetProfile)
				if targetProfile.Guild and targetProfile.Guild.Id == guildId then
					targetProfile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
					targetProfile.GuildBonuses = emptyBonuses()
				end
				return { ok = true }
			end, true, "guild-ban")
			if not updated then return false, result end
			self:_pushState(target)
			-- a guild ban removes guild access only (the client shows the notice); never disconnect the player
			self._effect:FireClient(target, { Type = "GuildBanned", GuildId = guildId })
			return true, nil
		end)
		self._chat = ChatService.new(self._effect, self._data)
		self._crews = CrewService.new(self._effect, self._data)
		self._trades = TradeDesk.new()
		self._random = Random.new()
		self._heartbeat = nil
		self._playerAddedConnection = nil
		self._playerRemovingConnection = nil
		self._characterConnections = {}
		self._joining = {}
		self._running = false
		self._leaderboardStores = {}
		for id, storeName in GENERAL_BOARD_STORE_NAMES do
			self._leaderboardStores[id] = getOrderedStore(storeName)
		end

		self._playerNameCache = {}
		self._nameLookupPending = {}
		self._nameCachePruneAt = 0
		self._globalBoardCache = {}
		self._friendshipCache = {}
		self._queuedStatePushes = {}
		self._socialBoostScheduled = false
		self._socialBoostDirty = false
		self._socialBoostWorker = nil
		self._backgroundWorkers = {}
		self._saveFailedToastAt = {}
		dataService.OnSaveFailed = function(player: Player, reason: string)
			local lastToastAt = self._saveFailedToastAt[player] or 0
			if os.clock() - lastToastAt < 120 then return end
			self._saveFailedToastAt[player] = os.clock()
			self:_toastPlayer(player, "Save trouble", "Your progress couldn't save just now. Stay online while we retry.", "Warning")
		end
		return self
	end

	function GameService:_submitFeedback(player: Player, payload: any)
		local endpoint = ServerStorage:GetAttribute(ServerConfig.FeedbackWebhookAttribute)
		if type(endpoint) ~= "string" or not string.match(endpoint, "^https://") then
			return responseError("Feedback isn't set up yet. Please try again later.")
		end
		local category = payload and payload.Category
		local raw = payload and payload.Message
		if type(category) ~= "string" or type(raw) ~= "string" then
			return responseError("Write a short note before sending it.")
		end
		local filteredOk, filtered = self._security.Filter:Apply(player, raw, player.UserId, 600)
		if not filteredOk or type(filtered) ~= "string" or #filtered < 1 then
			return responseError("That note couldn't be checked. Please try different wording.")
		end
		local profile = self._data:Get(player)
		local categoryColors = { Bug = 15548997, Suggestion = 5959144, Balance = 16762880, Performance = 10181046, Interface = 3447003, Other = 9807270 }
		local impactLabels = { "Minor", "Noticeable", "Annoying", "Major", "Blocking" }
		local impact = payload and payload.Impact
		local fields = {
			{ name = "Player", value = string.format("%s (@%s) · %d", player.DisplayName, player.Name, player.UserId), inline = false },
			{ name = "Progress", value = string.format("World %d · %d rebirths", profile and profile.Zone or 1, profile and profile.Rebirths or 0), inline = true },
			{ name = "Server", value = game.JobId ~= "" and game.JobId or "Studio", inline = true },
		}
		if type(impact) == "number" and impactLabels[impact] then
			table.insert(fields, { name = "Impact", value = string.format("%s (%d/5)", impactLabels[impact], impact), inline = true })
		end
		if type(payload.Device) == "string" then
			local screen = if type(payload.Screen) == "string" then " · " .. payload.Screen else ""
			table.insert(fields, { name = "Device", value = payload.Device .. screen, inline = true })
		end
		if type(payload.Page) == "string" then
			table.insert(fields, { name = "Page", value = payload.Page, inline = true })
		end
		local body = {
			username = "Astral Forge Feedback",
			allowed_mentions = { parse = {} },
			embeds = {
				{
					title = category .. " feedback",
					description = filtered,
					color = categoryColors[category] or 5959144,
					fields = fields,
					footer = { text = "Astral Forge " .. tostring(GameConfig.Game.Version) },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		}
		self:_spawnWorker(function()
			local ok, response = pcall(function()
				return HttpService:RequestAsync({
					Url = endpoint,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = HttpService:JSONEncode(body),
				})
			end)
			if not ok or type(response) ~= "table" or response.Success ~= true then
				ModuleLog.Every("feedback-webhook", 30, "Feedback", "A player note could not be delivered")
			end
		end)
		return responseSuccess("Thanks. Your feedback was sent.")
	end

	local reportLedger = ReportLedger.new()
	Players.PlayerRemoving:Connect(function(leaving)
		reportLedger:forgetReporter(leaving.UserId)
	end)

	function GameService:_reportPlayer(player: Player, payload: any)
		local reason = payload and payload.Reason
		if not ReportLedger.isReason(reason) then
			return responseError("Pick a reason before sending the report.")
		end
		local extracted = if RemoteFirewall.ExtractUserId then RemoteFirewall.ExtractUserId(payload and payload.UserId) else (payload and payload.UserId)
		local targetUserId = RemoteFirewall.CoerceUserId(extracted) or RemoteFirewall.CoerceUserId(payload and payload.UserId)
		if targetUserId == nil then
			return responseError("Couldn't find that player.")
		end
		if targetUserId == player.UserId then
			return responseError("You can't report yourself.")
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return responseError("That player is no longer in this server.")
		end
		local now = os.time()
		local allowed, refusal = reportLedger:canReport(player.UserId, targetUserId, now)
		if not allowed then
			return responseError(refusal)
		end
		local rawDetails = payload and payload.Details
		local details = ""
		if type(rawDetails) == "string" and #rawDetails > 0 then
			local filteredOk, filtered = self._security.Filter:Apply(player, rawDetails, player.UserId, 400)
			details = (filteredOk and type(filtered) == "string") and filtered or ""
		end
		local reportCount, reporterCount = reportLedger:record(player.UserId, targetUserId, reason, now)
		local severity = if payload.Severity == "Serious" or payload.Severity == "Urgent" then payload.Severity else "Minor"
		local when = if payload.When == "Earlier" or payload.When == "Repeated" then payload.When else "Now"
		local where = if payload.Where == "Chat" or payload.Where == "Trade" or payload.Where == "Guild" then payload.Where else "World"
		local endpoint = ServerStorage:GetAttribute(ServerConfig.ReportWebhookAttribute)
		if type(endpoint) ~= "string" or not string.match(endpoint, "^https://") then
			ModuleLog.Every(
				string.format("report:%d", targetUserId),
				5,
				"Report",
				string.format("%s reported %s (%d) for %s; %d reports from %d players this hour", player.Name, target.Name, targetUserId, reason, reportCount, reporterCount)
			)
			return responseSuccess("Report received. Thanks for helping keep the server clean.", { Reported = targetUserId })
		end
		local reporterProfile = self._data:Get(player)
		local targetProfile = self._data:Get(target)
		local body = {
			username = "Astral Forge Reports",
			allowed_mentions = { parse = {} },
			embeds = {
				{
					title = string.format("[%s] Player report: %s", severity, reason),
					description = details ~= "" and details or "(no details provided)",
					color = ReportLedger.SEVERITY_COLORS[severity] or 15548997,
					fields = {
						{ name = "Reported", value = string.format("%s (@%s) · %d", target.DisplayName, target.Name, target.UserId), inline = true },
						{ name = "Reported by", value = string.format("%s (@%s) · %d", player.DisplayName, player.Name, player.UserId), inline = true },
						{ name = "Target progress", value = string.format("World %d · %d rebirths", targetProfile and targetProfile.Zone or 1, targetProfile and targetProfile.Rebirths or 0), inline = true },
						{ name = "Reporter progress", value = string.format("World %d · %d rebirths", reporterProfile and reporterProfile.Zone or 1, reporterProfile and reporterProfile.Rebirths or 0), inline = true },
						{ name = "This hour", value = string.format("%d reports from %d players", reportCount, reporterCount), inline = true },
						{ name = "Target account", value = string.format("%d days old", target.AccountAge), inline = true },
						{ name = "Context", value = string.format("%s · %s", where, when), inline = true },
						{ name = "Server", value = game.JobId ~= "" and game.JobId or "Studio", inline = true },
					},
					footer = { text = "Astral Forge " .. tostring(GameConfig.Game.Version) },
					timestamp = DateTime.now():ToIsoDate(),
				},
			},
		}
		self:_spawnWorker(function()
			local ok, response = pcall(function()
				return HttpService:RequestAsync({
					Url = endpoint,
					Method = "POST",
					Headers = { ["Content-Type"] = "application/json" },
					Body = HttpService:JSONEncode(body),
				})
			end)
			if not ok or type(response) ~= "table" or response.Success ~= true then
				ModuleLog.Every("report-webhook", 30, "Report", "A player report could not be delivered")
			end
		end)
		return responseSuccess("Report sent. Thanks for helping keep the server clean.", { Reported = targetUserId })
	end

	local function itemSalvageValue(instance, definition): number
		local rarity = GameConfig.Items.Rarities[definition.Rarity]
		local rank = rarity and rarity.Rank or 1
		return ItemSalvage.Value(instance.Level, rank)
	end

	local function ensureAutoSalvage(profile)
		return ProfileBagMath.EnsureAutoSalvage(profile)
	end

	function GameService:_spawnWorker(callback)
		if not self._running then return nil end
		local token = {}
		local worker = task.defer(function()
			if self._running then
				local ok, problem = pcall(callback)
				if not ok then
					ModuleLog.Every("background-worker", 5, "Game", tostring(problem))
				end
			end
			self._backgroundWorkers[token] = nil
		end)
		self._backgroundWorkers[token] = worker
		return worker
	end

	local function progressionNumber(value: any): number
		return Economy.AsNumber(value)
	end

	function GameService:_queueSocialBoostRefresh()
		self._socialBoostDirty = true
		if self._socialBoostScheduled then
			return
		end
		self._socialBoostScheduled = true
		self._socialBoostWorker = task.spawn(function()
				repeat
				self._socialBoostDirty = false
				task.wait(0.15)
				if not self._running then
					break
				end
				local cacheNow = os.clock()
				for key, entry in self._friendshipCache do
					if type(entry) ~= "table" or tonumber(entry.ExpiresAt) == nil or entry.ExpiresAt <= cacheNow then
						self._friendshipCache[key] = nil
					end
				end
				local online = Players:GetPlayers()
				local counts = {}
				for _, player in online do
					counts[player] = 0
				end
				for leftIndex = 1, #online do
					local left = online[leftIndex]
					for rightIndex = leftIndex + 1, #online do
						local right = online[rightIndex]
						local low = math.min(left.UserId, right.UserId)
						local high = math.max(left.UserId, right.UserId)
						local key = tostring(low) .. ":" .. tostring(high)
						local cached = self._friendshipCache[key]
						local friends = false
						if cached and cached.ExpiresAt > os.clock() then
							friends = cached.Value
						else
							local ok, result = pcall(function()
								return left:IsFriendsWith(right.UserId)
							end)
							friends = ok and result == true
							self._friendshipCache[key] = {
								Value = friends,
								ExpiresAt = os.clock() + (ok and GameConfig.Social.FriendshipCacheSeconds or 20),
							}
						end
						if friends then
							counts[left] = (counts[left] or 0) + 1
							counts[right] = (counts[right] or 0) + 1
						end
					end
				end
				for _, player in online do
					local updated, updateError = pcall(function()
						local changed = false
						local committed = self._data:AtomicUpdate(player, function(profile)
							changed = applySocialBoost(
								profile,
								counts[player] or 0,
								player.MembershipType == Enum.MembershipType.Premium
							)

							if not changed then return { ok = false, noop = true } end
							return { ok = true }
						end, true, "social-boost")
						if committed and changed then self:_pushState(player) end
					end)
					if not updated then
						ModuleLog.Every("social-boost:" .. tostring(player.UserId), 30, "Social", tostring(updateError))
					end
				end
			until not self._socialBoostDirty
			self._socialBoostScheduled = false
			self._socialBoostWorker = nil

			if self._socialBoostDirty and self._running then
				self:_queueSocialBoostRefresh()
			end
		end)
	end

	local function clampProgressionNumbers(profile)
		ProfileClampMath.ClampProgressionNumbers(profile, Economy.Persist, MAX_SAFE_CURRENCY)
	end

	function GameService:_toastPlayer(player: Player, title: string, body: string, tone: string?)

		if player.Parent ~= Players then return end
		self._toast:FireClient(player, {
			Title = title,
			Body = body,
			Tone = tone or "Info",
		})
	end

	function GameService:_createLeaderstats(player: Player)
		local old = player:FindFirstChild("leaderstats")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player

		local flux = Instance.new("NumberValue")
		flux.Name = "Flux"
		flux.Parent = folder

		local cores = Instance.new("NumberValue")
		cores.Name = "Cores"
		cores.Parent = folder
		local rebirths = Instance.new("NumberValue")
		rebirths.Name = "Rebirths"
		rebirths.Parent = folder
	end

	function GameService:_syncLeaderstats(player: Player, profile)
		if player.Parent ~= Players or type(profile) ~= "table" then return end
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local flux = leaderstats:FindFirstChild("Flux")
			local cores = leaderstats:FindFirstChild("Cores")
			local rebirths = leaderstats:FindFirstChild("Rebirths")
			if flux and flux:IsA("NumberValue") then
				flux.Value = math.floor(progressionNumber(profile.Cash))
			end
			if cores and cores:IsA("NumberValue") then
				cores.Value = math.floor(progressionNumber(profile.Cores))
			end
			if rebirths and rebirths:IsA("NumberValue") then
				rebirths.Value = math.floor(progressionNumber(profile.Rebirths))
			end
		end
		player:SetAttribute("ProductionPerSecond", progressionNumber(Economy.Mul(Economy.Production(profile), self._convergence:Multiplier() * self._events:ProductionMultiplier() * self._crews:Multiplier(player))))
		player:SetAttribute("CurrentZone", profile.CurrentZone)
		if GameConfig.Operations.TitlesEnabled == false then
			player:SetAttribute("EquippedTitle", nil)
			player:SetAttribute("EquippedTitleName", nil)
			player:SetAttribute("EquippedTitleFx", nil)
		else
			local titleId = "Cadet"
			if profile.Command and type(profile.Command.EquippedTitle) == "string" and profile.Command.EquippedTitle ~= "" then
				titleId = profile.Command.EquippedTitle
			end
			local titleName = "Forge Cadet"
			local titleFx = ""
			for _, title in GameConfig.Operations.Titles do
				if title.Id == titleId then
					titleName = title.Name
					titleFx = type(title.Fx) == "string" and title.Fx or ""
					break
				end
			end
			player:SetAttribute("EquippedTitle", titleId)
			player:SetAttribute("EquippedTitleName", titleName)
			player:SetAttribute("EquippedTitleFx", titleFx)
		end
		-- the equipped artifact is public: every client reads these for the overhead aura, the
		-- player list and chat, so it has to be visible to the whole server, not just its owner
		local command = profile.Command
		local artifactId = command and type(command.EquippedArtifact) == "string" and command.EquippedArtifact or ""
		local artifact = artifactId ~= "" and Economy.GetArtifact(artifactId) or nil
		local owned = artifact and type(command.Artifacts) == "table" and command.Artifacts[artifactId] or nil
		if artifact and type(owned) == "table" then
			local level = math.max(1, math.floor(tonumber(owned.Level) or 1))
			local power = (tonumber(artifact.EffectPerLevel) or 0) * level
			local effectText = if artifact.EffectKind == "OfflineHours"
				then string.format("+%.1fh offline", power)
				else string.format("+%.0f%% %s", power * 100, string.lower(tostring(artifact.EffectKind)))
			player:SetAttribute("EquippedArtifactName", tostring(artifact.Name))
			player:SetAttribute("EquippedArtifactElement", tostring(artifact.Element or ""))
			player:SetAttribute("EquippedArtifactRarity", tostring(artifact.Rarity or "COMMON"))
			player:SetAttribute("EquippedArtifactLevel", level)
			player:SetAttribute("EquippedArtifactColor", if typeof(artifact.Color) == "Color3" then artifact.Color else Color3.fromRGB(170, 139, 255))
			player:SetAttribute("EquippedArtifactEffect", effectText)
			player:SetAttribute("EquippedArtifact", artifactId)
		elseif player:GetAttribute("EquippedArtifact") ~= nil then
			for _, key in { "EquippedArtifact", "EquippedArtifactName", "EquippedArtifactElement", "EquippedArtifactRarity", "EquippedArtifactLevel", "EquippedArtifactColor", "EquippedArtifactEffect" } do
				player:SetAttribute(key, nil)
			end
		end
	end

	local OVERCHARGE_COMBO_WINDOW = GameConfig.Overcharge.ComboWindow
	local OVERCHARGE_COMBO_MAX = GameConfig.Overcharge.ComboMax
	local OVERCHARGE_COMBO_BONUS = GameConfig.Overcharge.ComboBonusPerStack

	local function overchargeComboWindow(profile): number
		return OverchargeCombo.Window(OVERCHARGE_COMBO_WINDOW)
	end

	local function overchargeComboMultiplier(profile, combo: number): number
		return OverchargeCombo.Multiplier(combo, OVERCHARGE_COMBO_MAX, OVERCHARGE_COMBO_BONUS)
	end

	function GameService:_announceServerEvent(phase: string, def)
		local title, body, tone
		if phase == "Warning" then
			title, body, tone = def.Name .. " in 1 minute", def.Blurb, "Info"
		elseif phase == "Live" then
			title, body, tone = def.Name .. " has started!", def.How, "Special"
		elseif phase == "Completed" then
			title, body, tone = "Community goal reached!", "Everyone who helped has been paid. Nice work, forge.", "Success"
		else
			title, body, tone = def.Name .. " is over", "Thanks for playing. The next event is on its way.", "Info"
		end
		for _, online in Players:GetPlayers() do
			self:_toastPlayer(online, title, body, tone)
		end
	end

	function GameService:_payCommunityForge(ranking, def)
		for rank, entry in ranking do
			local player = Players:GetPlayerByUserId(entry.UserId)
			if player == nil then
				continue
			end
			local stardust = def.RewardStardust + (def.TopBonusStardust[rank] or 0)
			local paid = 0
			self:_mutate(player, function(profile)
				local amount = Economy.Mul(Economy.Production(profile), def.RewardFluxSeconds)
				if Economy.AsNumber(amount) < 500 then
					amount = 500
				end
				profile.Cash = Economy.Add(profile.Cash, amount)
				profile.Stardust += stardust
				paid = Economy.AsNumber(amount)
				return responseSuccess(nil)
			end)
			local placing = if rank <= 3 then string.format(" You placed #%d!", rank) else ""
			self:_toastPlayer(player, "Community Forge paid out", string.format("+%s flux and +%d stardust.%s", Format.Number(paid), stardust, placing), "Success")
		end
	end

	function GameService:_settleProgression(player: Player, profile, levelState, production)
		local progression = profile.Progression
		if type(progression) ~= "table" then
			progression = { RewardedLevel = -1, HalfwayPaidFor = -1, Surge = { Multiplier = 1, EndsAt = 0 } }
			profile.Progression = progression
		end
		local now = os.time()
		local firstLook = (tonumber(progression.RewardedLevel) or -1) < 0
		local owed, settled = LevelRewards.owed(tonumber(progression.RewardedLevel) or -1, levelState.Level)
		progression.RewardedLevel = settled
		if firstLook then
			progression.HalfwayPaidFor = levelState.Level
		end
		local function fluxFor(seconds, floor)
			local amount = Economy.Mul(production, seconds)
			if Economy.AsNumber(amount) < floor then
				amount = floor
			end
			return amount
		end
		if #owed > 0 then
			local fluxTotal = 0
			local stardustTotal = 0
			local surge = progression.Surge
			for _, reached in owed do
				local def = ForgeLevels.get(reached)
				local reward = LevelRewards.forLevel(reached, def and def.Tier)
				local flux = fluxFor(reward.FluxSeconds, reward.MinFlux)
				profile.Cash = Economy.Add(profile.Cash, flux)
				fluxTotal = Economy.Add(fluxTotal, flux)
				profile.Stardust += reward.Stardust
				stardustTotal += reward.Stardust
				surge = LevelRewards.mergeSurge(surge, now, reward.SurgeMultiplier, reward.SurgeSeconds)
			end
			progression.Surge = surge
			progression.HalfwayPaidFor = math.max(tonumber(progression.HalfwayPaidFor) or -1, levelState.Level)
			self._effect:FireClient(player, {
				Type = "LevelReward",
				Level = levelState.Level,
				Tier = levelState.Tier,
				Levels = owed,
				Flux = Economy.AsNumber(fluxTotal),
				Stardust = stardustTotal,
				SurgeMultiplier = surge.Multiplier,
				SurgeEndsAt = surge.EndsAt,
			})
		end
		local nextStep = levelState.Next
		if nextStep ~= nil and LevelRewards.halfwayDue(tonumber(progression.HalfwayPaidFor) or -1, nextStep.Level, nextStep.Progress, nextStep.Target) then
			local checkpoint = LevelRewards.halfway(nextStep.Level)
			local flux = fluxFor(checkpoint.FluxSeconds, checkpoint.MinFlux)
			profile.Cash = Economy.Add(profile.Cash, flux)
			progression.HalfwayPaidFor = nextStep.Level
			self:_toastPlayer(player, string.format("Halfway to Level %d", nextStep.Level), string.format("+%s flux.", Format.Number(flux)), "Success")
			self._effect:FireClient(player, { Type = "LevelHalfway", Level = nextStep.Level, Flux = Economy.AsNumber(flux) })
		end
		local nextReward = nil
		if nextStep ~= nil then
			nextReward = LevelRewards.forLevel(nextStep.Level, nextStep.Tier)
		end
		return {
			Mastery = LevelRewards.mastery(settled),
			Surge = {
				Multiplier = LevelRewards.surgeMultiplier(progression.Surge, now),
				EndsAt = if LevelRewards.surgeMultiplier(progression.Surge, now) > 1 then progression.Surge.EndsAt else 0,
			},
			HalfwayPaidFor = progression.HalfwayPaidFor,
			NextReward = nextReward,
		}
	end

	function GameService:_snapshot(player: Player)
		local profile = self._data:Get(player)
		local runtime = self._runtime[player]
		if not profile then
			return nil
		end
		if (not runtime or os.clock() >= (runtime.BazaarRecoveryRetryAt or 0)) and BazaarService.NeedsRecovery(profile, player.UserId) then
			local recovered = self:_mutate(player, function(draft)
				local ok, message = BazaarService.Roll(draft, os.time(), player.UserId)
				return if ok then responseSuccess(message) else responseError(message)
			end)
			if not recovered.ok then
				if runtime then runtime.BazaarRecoveryRetryAt = os.clock() + 30 end
				ModuleLog.Every("legacy-refund:" .. player.UserId, 30, "BlackMarket",
					"Legacy refund could not be committed for " .. player.UserId .. ": " .. tostring(recovered.error))
			end
			profile = self._data:Get(player)
			if not profile then return nil end
		end
		local now = os.time()
		local baseProduction = Economy.Production(profile, now)
		local production = Economy.Mul(baseProduction, self._convergence:Multiplier() * self._events:ProductionMultiplier() * self._crews:Multiplier(player))
		local capacity = Economy.Capacity(profile, now)
		local prestigeReward = Economy.PrestigeReward(Economy.Add(profile.RunCash, profile.Vault))
		local domain = profile.Domain or { Rank = 0, Essence = 0, LastExpandedAt = 0, TotalRebirthsSpent = 0, TotalCoresSpent = 0 }
		local domainRank = math.max(0, math.floor(tonumber(domain.Rank) or 0))
		local domainRequiredRebirths, domainRequiredCores = Economy.DomainRequirements(domainRank)
		local domainEssenceReward, domainStardustReward = Economy.DomainRewards(domainRank)
		local continuum = profile.Continuum or { Rank = 0, TotalFluxSpent = 0, TotalStardustSpent = 0 }
		local continuumRank = math.max(0, math.floor(tonumber(continuum.Rank) or 0))
		local continuumFluxCost, continuumStardustCost = Economy.ContinuumCosts(continuumRank)
		local continuumProduction, continuumCapacity, continuumTap, continuumOffline = Economy.ContinuumEffects(profile)
		if runtime then
			runtime.SnapshotId = (runtime.SnapshotId or 0) + 1
		end
		local itemShop = {}
		ensureItemShop(profile)
		for index, offer in GameConfig.Items.ShopOffers do
			local state = copyDictionary(offer)
			local stockMax = offerStockMax(offer)
			local stock = ShopGrantEligibility.RemainingStock(profile.Items.Shop.Stock[offer.Id], stockMax)
			state.Stock = stock
			state.StockMax = stockMax
			state.DailyRefresh = offer.DailyRefresh == true
			state.Purchased = stock <= 0
			itemShop[index] = state
		end
		local featureUnlocks = ProgressionGate.FeatureStates(profile)
		local levelState = ProgressionGate.LevelState(profile)
		if runtime then
			local newlyUnlocked = {}
			if runtime.FeatureUnlocks then
				for id, state in featureUnlocks do
					if state.Unlocked and runtime.FeatureUnlocks[id] ~= true then
						table.insert(newlyUnlocked, { Id = id, State = state })
					end
				end
			end
			local leveledUp = runtime.ForgeLevel ~= nil and levelState.Level > runtime.ForgeLevel
			runtime.ForgeLevel = levelState.Level
			if leveledUp then
				local names = {}
				for _, entry in newlyUnlocked do
					table.insert(names, entry.State.Name)
				end
				table.sort(names)
				local nextStep = levelState.Next
				local body = if #names > 0
					then "New: " .. table.concat(names, ", ") .. ". Find them in the Forge menu."
					elseif nextStep ~= nil then "Next goal: " .. nextStep.Text .. "."
					else "You've reached the top of the forge."
				self:_toastPlayer(player, string.format("Level %d · %s", levelState.Level, levelState.Tier), body, "Special")
				self._effect:FireClient(player, {
					Type = "LevelUp",
					Level = levelState.Level,
					Tier = levelState.Tier,
					Names = names,
				})
			elseif #newlyUnlocked > 0 then
				local names = {}
				for _, entry in newlyUnlocked do
					table.insert(names, entry.State.Name)
				end
				local single = #newlyUnlocked == 1 and newlyUnlocked[1] or nil
				self:_toastPlayer(
					player,
					single and (single.State.Name .. " unlocked") or "New systems unlocked",
					single and "You can open it from the Forge menu." or (table.concat(names, ", ") .. " are ready in the Forge menu."),
					"Special"
				)
				self._effect:FireClient(player, {
					Type = "FeatureUnlocked",
					Id = single and single.Id or nil,
					Name = single and single.State.Name or table.concat(names, ", "),
					Count = #newlyUnlocked,
				})
			end
			local current = {}
			for id, state in featureUnlocks do
				current[id] = state.Unlocked
			end
			runtime.FeatureUnlocks = current
		end
		levelState.Progression = self:_settleProgression(player, profile, levelState, production)
		local storyState = StoryMailSnapshot.BuildStory(profile, GameConfig.Story, ProgressionGate)
		local mailState, unreadMail = StoryMailSnapshot.BuildMailbox(profile, GameConfig.Mail, ProgressionGate)
		local guildMembership = profile.Guild
		local guildId = guildMembership and guildMembership.Id or ""
		local guildCachedPublic = if guildId ~= "" then self._guilds:GetCachedPublic(guildId) else nil
		local guildSnapshot = GuildMath.SnapshotPublic(guildMembership, guildCachedPublic)
		if guildSnapshot and guildId ~= "" then guildSnapshot.Community = self._guildCommunity:Snapshot(guildId) end
		local overchargeCombo, overchargeMultiplier = self:_overchargeCombo(runtime, profile)

		return {
			Game = {
				Name = GameConfig.Game.Name,
				Version = GameConfig.Game.Version,
				Update = GameConfig.Game.Update,
			},
			Cash = profile.Cash,
			Vault = profile.Vault,
			Cores = profile.Cores,
			Stardust = profile.Stardust,
			Rebirths = profile.Rebirths,
			Domain = ContinuumDomainMath.SnapshotDomainPublic({
				domain = domain,
				rank = domainRank,
				requiredRebirths = domainRequiredRebirths,
				requiredCores = domainRequiredCores,
				essenceReward = domainEssenceReward,
				stardustReward = domainStardustReward,
				rebirths = profile.Rebirths,
				cores = profile.Cores,
				domainConfig = GameConfig.Domain,
				MeetsRequired = RebirthGate.MeetsRequired,
				Gte = Economy.Gte,
				DomainTreeBonus = function(kind)
					return Economy.DomainTreeBonus(profile, kind)
				end,
			}),
			Continuum = ContinuumDomainMath.SnapshotContinuumPublic({
				rank = continuumRank,
				totalFluxSpent = continuum.TotalFluxSpent,
				totalStardustSpent = continuum.TotalStardustSpent,
				fluxCost = continuumFluxCost,
				stardustCost = continuumStardustCost,
				cash = profile.Cash,
				stardust = profile.Stardust,
				production = continuumProduction,
				capacity = continuumCapacity,
				tap = continuumTap,
				offline = continuumOffline,
				milestoneEvery = GameConfig.Continuum.MilestoneEvery,
				Gte = Economy.Gte,
			}),
			ForgeEchoes = ForgeEchoService.State(profile),
			RunCash = profile.RunCash,
			LifetimeCash = profile.LifetimeCash,
			Zone = profile.Zone,
			CurrentZone = profile.CurrentZone,
			Machines = copyDictionary(profile.Machines),
			Research = copyDictionary(profile.Research),
			GridUpgrades = copyDictionary(profile.GridUpgrades),
			Specialization = Specializations.Snapshot(profile, Economy, os.time(), runtime, {
				Production = baseProduction, Capacity = capacity,
			}),
			BoostInventory = copyDictionary(profile.BoostInventory),
			ActiveBoost = copyDictionary(profile.ActiveBoost),
			Quests = copyDictionary(profile.Quests.Items),
			Achievements = ProgressionService.AchievementStates(profile),
			Daily = ProgressionService.DailyState(profile),
			Wheel = ProgressionService.WheelState(profile),
			Bazaar = BazaarService.State(profile, os.time(), player.UserId),
			Encounters = EncounterService.State(profile, os.time()),
			Sky = {
				Retired = true,
				Plotted = table.clone(((profile.Sky or {}).Charts or {}).Plotted or {}),
				Cipher = {
					Solves = ((profile.Sky or {}).Cipher or {}).Solves or 0,
					Best = ((profile.Sky or {}).Cipher or {}).Best or 0,
				},
			},
			Command = ProgressionService.CommandState(profile),
			ForgePath = ProgressionService.ForgePathState(profile),
			TimedRewards = ProgressionService.TimedRewardState(profile),
			Items = {
				Inventory = copyDictionary(profile.Items.Inventory),
				Equipped = copyDictionary(profile.Items.Equipped),
				Essence = profile.Items.Essence,
				Keys = copyDictionary(profile.Items.Keys),
				Pity = copyDictionary(profile.Items.Pity),
				InventoryLimit = GameConfig.Items.InventoryLimit,
				Shop = itemShop,
				ShopRefreshAt = nextUtcMidnight(),
				AutoSalvage = AutoSalvageSnapshot.Public(profile.Items.AutoSalvage, copyDictionary),
				Effects = ItemLoadoutMath.EffectsPublic(profile, Economy),
				Discovered = copyDictionary(profile.Items.Discovered or {}),
				CodexBonus = Economy.CodexBonus(profile),
			},
			DailyShop = {
				Day = type(profile.DailyShop) == "table" and profile.DailyShop.Day or -1,
				Bought = copyDictionary(type(profile.DailyShop) == "table" and profile.DailyShop.Bought or {}),
				Owned = if type(profile.DailyShop) == "table" and type(profile.DailyShop.Owned) == "table" then copyDictionary(profile.DailyShop.Owned) else nil,
			},
			Cosmetics = {
				CrateSkins = copyDictionary(type(profile.Cosmetics) == "table" and profile.Cosmetics.CrateSkins or { Classic = true }),
				CrateSkin = type(profile.Cosmetics) == "table" and profile.Cosmetics.CrateSkin or "Classic",
			},
			Anomaly = AnomalyService.State(profile),
			Lab = LabService.State(profile),
			Guild = guildSnapshot,
			GuildBonuses = copyDictionary(profile.GuildBonuses),
			SocialBoost = SocialBoost.PublicSnapshot(profile.SocialBoost, GameConfig.Social.MaxBoostedFriends, copyDictionary),
			SocialRewards = SocialBoost.CreatorRewardsPublic(profile.SocialRewards, ServerConfig.CreatorUsername),
			AutoForge = AutoSalvageSnapshot.PublicAutoForge(profile.AutoForge, copyDictionary),
			Trade = if self._trades then self._trades:StatePublic(profile, player, now) else TradeDesk.LockedPublic(),
			Convergence = self._convergence:State(player, profile),
			FeatureUnlocks = featureUnlocks,
			Level = levelState,
			Story = storyState,
			Mailbox = StoryMailSnapshot.MailboxPublic(mailState, unreadMail),
			Admin = self._admin and self._admin:State(player) or { Access = false },
			Settings = copyDictionary(profile.Settings),
			Flags = copyDictionary(profile.Flags),
			Stats = copyDictionary(profile.Stats),
			Shop = ShopGrantEligibility.CatalogPublic(profile.OwnedPasses, copyDictionary),
			Production = production,
			RawProduction = Economy.RawProduction(profile),
			Capacity = capacity,
			CapacitySeconds = Economy.CapacitySeconds(profile, now),
			SteadyProduction = Economy.SteadyProduction(profile, now),
			FluxSurge = self._fluxSurge and self._fluxSurge:State(now) or FluxSurgeService.IdleState(),
			ServerEvent = self._events:State(player),
			PermanentMultiplier = Economy.PermanentMultiplier(profile),
			AutoCollectRate = Economy.AutoCollectRate(profile),
			OfflineHours = Economy.OfflineHours(profile),
			OfflineEfficiency = Economy.OfflineEfficiency(profile),
			TapPower = Economy.TapPower(profile, now),
			CriticalChance = Economy.CriticalChance(profile),
			CriticalMultiplier = Economy.CriticalMultiplier(profile),
			Overcharge = OverchargeCombo.PublicSnapshot({
				combo = overchargeCombo,
				comboMultiplier = overchargeMultiplier,
				comboMax = GameConfig.Overcharge.ComboMax,
				comboWindow = overchargeComboWindow(profile),
				comboBonusPerStack = GameConfig.Overcharge.ComboBonusPerStack,
			}),
			PrestigeReward = prestigeReward,
			NextPrestigeTarget = Economy.NextPrestigeTarget(prestigeReward),
			Revision = profile.Meta.Revision,
			SnapshotId = runtime and runtime.SnapshotId or 0,
			ServerTime = now,
			Telemetry = encodeTelemetry(
				profile.Meta.Revision,
				profile.Settings,
				profile.Cash,
				profile.Vault,
				production,
				capacity,
				profile.Cores,
				profile.Stardust
			),
			Offline = OfflineProjection.PublicSnapshot({
				runtime = runtime,
				production = production,
				vault = profile.Vault,
				offlineHours = Economy.OfflineHours(profile),
			}),
			Visitors = self:_visitorList(player),
			Visit = VisitSnapshot.Resolve(self._visiting[player], Players:GetPlayers(), function(host)
				return self._data:Get(host)
			end, Economy),
		}
	end

	function GameService:_pushState(player: Player, force: boolean?)
		if player.Parent ~= Players then
			return
		end
		local snapshot = self:_snapshot(player)
		if snapshot then
			local runtime = self._runtime[player]
			local now = os.clock()
			local revision = tonumber(snapshot.Revision) or 0
			if not force and runtime and runtime.LastPushRevision == revision and (now - (runtime.LastPushAt or 0)) < 0.55 then
				return
			end
			if runtime then
				runtime.LastPushRevision = revision
				runtime.LastPushAt = now
			end
			self._state:FireClient(player, snapshot)
		end
		self:_broadcastVisit(player)
	end

	function GameService:_mutate(player: Player, callback, incrementRevision: boolean?)
		local success, result = self._data:Update(player, function(profile)
			local callbackResult = callback(profile)
			if type(callbackResult) == "table" and callbackResult.ok == false then
				return callbackResult
			end
			clampProgressionNumbers(profile)
			enforceUnlimitedMoney(profile)

			local _, wouldReject = self._antiCheat:Observe(player, "Mutation", profile)
			if wouldReject then
				-- Returning a failed transaction quarantines the whole mutation, including the illegal credit.
				return responseError("That economy change was rejected.")
			end
			return callbackResult
		end, incrementRevision)
		if not success then
			return responseError("Your profile is not ready. Please try again.")
		end
		if type(result) ~= "table" or type(result.ok) ~= "boolean" then
			return responseError("Couldn't finish that.")
		end
		if result.ok and self._runtime[player] then
			self._runtime[player].SpecializationPreviewKey = nil
		end
		return result
	end

	function GameService:_progressAnomalyFromAction(player: Player, action: string)
		if not anomalyChargeByAction[action] then return end
		local runtime = self._runtime[player]
		if not runtime then return end
		runtime.PendingAnomalyActions = runtime.PendingAnomalyActions or {}

		if #runtime.PendingAnomalyActions < 64 then
			table.insert(runtime.PendingAnomalyActions, action)
		end
	end

	function GameService:_pulseAnomaly(player: Player)
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.Pulse(profile, self._random)
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, {
				Type = details.BecameReady and "AnomalyReady" or "AnomalyPulse",
				Amount = details.Amount,
				Charge = details.Charge,
				Accurate = details.Accurate,
				Combo = details.Combo,
				PulseWindowStartedAt = details.PulseWindowStartedAt,
			})
			if details.OverdriveTriggered then
				self._effect:FireAllClients({ Type = "OverdriveTriggered", Overdrive = AnomalyService.OverdriveState() })
			end
		end
		return result
	end

	function GameService:_stabilizeAnomaly(player: Player)
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.Stabilize(profile)
			if success then
				LabService.Progress(profile, "Stabilize", 1)
			end
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, {
				Type = "AnomalyStabilized",
				AnomalyId = details.AnomalyId,
				AnomalyName = details.AnomalyName,
				Fragments = details.Fragments,
				Stabilizations = details.Stabilizations,
				CoreTier = details.CoreTier,
				CoreXP = details.CoreXP,
				TiersGained = details.TiersGained,
			})
			if details.OverdriveTriggered then
				self._effect:FireAllClients({ Type = "OverdriveTriggered", Overdrive = AnomalyService.OverdriveState() })
			end
		end
		return result
	end

	function GameService:_buyAnomalyProtocol(player: Player, protocolId: any)
		if type(protocolId) ~= "string" then
			return responseError("Choose a reactor upgrade and try again.")
		end
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.BuyProtocol(profile, protocolId)
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, {
				Type = "AnomalyProtocol",
				ProtocolId = details.ProtocolId,
				ProtocolName = details.ProtocolName,
				Level = details.Level,
			})
		end
		return result
	end

	function GameService:_activateAnomalySurge(player: Player)
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.ActivateSurge(profile)
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, {
				Type = "AnomalySurge",
				EndsAt = details.EndsAt,
				Duration = details.Duration,
			})
		end
		return result
	end

	function GameService:_setAnomalyChannel(player: Player, channelId: any)
		if type(channelId) ~= "string" then
			return responseError("Pick a valid reactor channel.")
		end
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.SetLoadout(profile, { channelId })
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, {
				Type = "AnomalyLoadout",
				Loadout = details.Loadout,
				Channel = details.Loadout and details.Loadout[1] or channelId,
			})
		end
		return result
	end

	function GameService:_setAnomalyLoadout(player: Player, rawLoadout: any)
		if type(rawLoadout) ~= "table" then
			return responseError("Invalid reactor loadout.")
		end
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.SetLoadout(profile, rawLoadout)
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, { Type = "AnomalyLoadout", Loadout = details.Loadout })
		end
		return result
	end

	function GameService:_claimAnomalyMilestone(player: Player, tier: any)
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.ClaimMilestone(profile, tier)
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, { Type = "AnomalyMilestone", Tier = details.Tier })
		end
		return result
	end

	function GameService:_claimAnomalyDirective(player: Player, directiveId: any)
		if type(directiveId) ~= "string" then
			return responseError("That reactor job isn't valid.")
		end
		local details = nil
		local result = self:_mutate(player, function(profile)
			local success, message, payload = AnomalyService.ClaimDirective(profile, directiveId)
			details = payload
			return success and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok and details then
			self._effect:FireClient(player, {
				Type = "AnomalyDirective",
				DirectiveId = details.DirectiveId,
				DirectiveName = details.DirectiveName,
				Fragments = details.Fragments,
			})
		end
		return result
	end

	function GameService:_captureEcho(player: Player)
		local result = self:_mutate(player, function(profile)
			local ok, message, payload = ForgeEchoService.Capture(profile, self._random)
			return ok and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok then self._effect:FireClient(player, { Type = "EchoCapture" }) end
		return result
	end

	function GameService:_claimEcho(player: Player, choiceId: any)
		local result = self:_mutate(player, function(profile)
			local ok, message, payload = ForgeEchoService.Claim(profile, choiceId)
			return ok and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok then self._effect:FireClient(player, { Type = "EchoClaim", Uid = result.EchoUid }) end
		return result
	end

	function GameService:_equipEcho(player: Player, uid: any, slot: any)
		local result = self:_mutate(player, function(profile)
			local ok, message = ForgeEchoService.Equip(profile, uid, slot)
			return ok and responseSuccess(message) or responseError(message)
		end)
		if result.ok then self._effect:FireClient(player, { Type = "EchoEquip" }) end
		return result
	end

	function GameService:_upgradeEcho(player: Player, uid: any)
		local result = self:_mutate(player, function(profile)
			local ok, message, payload = ForgeEchoService.Upgrade(profile, uid)
			return ok and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok then self._effect:FireClient(player, { Type = "EchoUpgrade" }) end
		return result
	end

	function GameService:_dismantleEcho(player: Player, uid: any)
		local result = self:_mutate(player, function(profile)
			local ok, message, payload = ForgeEchoService.Dismantle(profile, uid)
			return ok and responseSuccess(message, payload) or responseError(message)
		end)
		if result.ok then self._effect:FireClient(player, { Type = "EchoDismantle" }) end
		return result
	end

	function GameService:_collect(player: Player)
		local result = self:_mutate(player, function(profile)
			local amount = profile.Vault
			if Economy.Lt(amount, 0.01) then
				return responseError("Your vault is still charging.")
			end
			profile.Vault = 0
			profile.Cash = Economy.Add(profile.Cash, amount)
			profile.RunCash = Economy.Add(profile.RunCash, amount)
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, amount)
			local stats = ensureStats(profile)
			stats.Collected = Economy.Add(stats.Collected, amount)
			local amountNumber = Economy.AsNumber(amount)
			ProgressionService.Progress(profile, "EarnCash", amountNumber)
			LabService.Progress(profile, "BankFlux", amountNumber)
			ProgressionService.AwardCommandXP(
				profile,
				math.max(1, math.floor(math.log(amountNumber + 1) / math.log(10) * 3))
			)
			ProgressionService.AwardForgePathXP(
				profile,
				ForgePathClaim.XpFromBankedAmount(amountNumber, GameConfig.Economy.ForgePathXP)
			)
			ForgeEchoService.Record(profile, "Collect", math.clamp(2 + math.log(amountNumber + 1) / math.log(10), 2, 12))
			local rainDust = self._events:OnCollect(player, amountNumber, Economy.AsNumber(Economy.Production(profile)))
			if rainDust > 0 then
				profile.Stardust += rainDust
				return responseSuccess("Banked " .. Format.Number(amount) .. " flux and caught " .. rainDust .. " stardust.", { Amount = amount, Dust = rainDust })
			end
			return responseSuccess("Banked " .. Format.Number(amount) .. " flux.", { Amount = amount })
		end)
		if result.ok then
			self._effect:FireClient(player, { Type = "Collect", Amount = result.Amount })
		end
		return result
	end

	function GameService:_overchargeCombo(runtime, profile): (number, number)
		if not runtime then
			return 0, 1
		end
		local combo = math.max(0, math.floor(tonumber(runtime.TapCombo) or 0))
		if combo > 0 and os.clock() - (tonumber(runtime.LastTap) or 0) > overchargeComboWindow(profile) then
			return 0, 1
		end
		return combo, overchargeComboMultiplier(profile, combo)
	end

	function GameService:_overcharge(player: Player)
		local runtime = self._runtime[player]
		if not runtime then
			return responseError("Shop's still loading.")
		end
		local profileForCombo = self._data:Get(player)
		local nowClock = os.clock()
		if nowClock - runtime.LastTap < 0.06 then
			return responseError("Overcharge is cooling down.")
		end
		local previousCombo = math.max(0, math.floor(tonumber(runtime.TapCombo) or 0))
		if nowClock - runtime.LastTap > overchargeComboWindow(profileForCombo) then
			previousCombo = 0
		end
		local combo = math.min(OVERCHARGE_COMBO_MAX, previousCombo + 1)
		local comboMultiplier = overchargeComboMultiplier(profileForCombo, combo)
		runtime.LastTap = nowClock
		runtime.TapCombo = combo

		local result = self:_mutate(player, function(profile)
			local capacity = Economy.Capacity(profile)
			local room = Economy.Sub(capacity, profile.Vault)
			if Economy.Lte(room, 0.01) then
				return responseError("Your vault is full. Bank it first.")
			end
			local critical = self._random:NextNumber() <= Economy.CriticalChance(profile)
			local amount = Economy.TapPower(profile)
			if critical then
				amount = Economy.Mul(amount, Economy.CriticalMultiplier(profile))
			end
			if comboMultiplier > 1 then
				amount = Economy.Mul(amount, comboMultiplier)
			end
			amount = Economy.Min(room, amount)
			profile.Vault = Economy.Add(profile.Vault, amount)
			bumpStat(profile, "Taps", 1)
			LabService.Progress(profile, "Tap", 1)
			ProgressionService.Progress(profile, "Tap", 1)
			ProgressionService.AwardCommandXP(profile, 1)
			ForgeEchoService.Record(profile, "Surge", 1)
			return responseSuccess(nil, {
				Amount = amount,
				Critical = critical,
				Combo = combo,
				ComboMultiplier = comboMultiplier,
				ComboMax = OVERCHARGE_COMBO_MAX,
				ComboWindow = overchargeComboWindow(profile),
			})
		end, false)
		if result.ok then
			self._effect:FireClient(player, {
				Type = "Overcharge",
				Amount = result.Amount,
				Critical = result.Critical,
				Combo = result.Combo,
				ComboMultiplier = result.ComboMultiplier,
				ComboMax = result.ComboMax,
				ComboWindow = result.ComboWindow,
			})
		else
			runtime.TapCombo = previousCombo
		end
		return result
	end

	function GameService:_buyMachine(player: Player, machineId: any, requestedAmount: any?)
		if type(machineId) ~= "string" then
			return responseError("Invalid machine request.")
		end
		local machine = Economy.GetMachine(machineId)
		if not machine then
			return responseError("That machine does not exist.")
		end
		local result = self:_mutate(player, function(profile)
			local level = profile.Machines[machineId] or 0
			if level >= machine.MaxLevel then
				return responseError("That machine is already at maximum level.")
			end
			local lockReason = ProgressionGate.UpgradeReason(profile, machine, profile.Machines)
			if lockReason then
				return responseError(lockReason .. " first.")
			end
			local remainingLevels = machine.MaxLevel - level
			local count
			local cost
			if requestedAmount == "Max" then
				count, cost = Economy.AffordableMachineLevels(
					machineId,
					level,
					profile.Cash,
					remainingLevels
				)
			else
				count = type(requestedAmount) == "number" and math.clamp(math.floor(requestedAmount), 1, 50) or 1
				count = math.min(count, remainingLevels)
				cost = Economy.MachineBulkCost(machineId, level, count)
			end
			if count < 1 then
				return responseError("You cannot afford another level yet.")
			end
			if Economy.Lt(profile.Cash, cost) then
				return responseError("You need " .. Format.Number(Economy.Sub(cost, profile.Cash)) .. " more flux.")
			end
			profile.Cash = Economy.Sub(profile.Cash, cost)
			profile.Machines[machineId] = level + count
			bumpStat(profile, "MachinesBought", count)
			LabService.Progress(profile, "BuyLevels", count)
			local mastery = ensureCommandMastery(profile)
			mastery[machineId] = (tonumber(mastery[machineId]) or 0) + count
			ProgressionService.Progress(profile, "BuyMachine", count)
			ProgressionService.AwardCommandXP(profile, count * 5)
			ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.8, 2, 12))
			return responseSuccess(
				string.format("%s gained %d levels and reached level %d.", machine.Name, count, level + count)
			)
		end)
		if result.ok then
			local profile = self._data:Get(player)
			self._world:RefreshPlot(player, profile)
		end
		return result
	end

	function GameService:_queueStatePush(player: Player)
		if self._queuedStatePushes[player] then return end
		self._queuedStatePushes[player] = task.defer(function()
			self._queuedStatePushes[player] = nil
			if self._running and player.Parent == Players then self:_pushState(player) end
		end)
	end

	function GameService:_setAutoForge(player: Player, payload)
		if type(payload) ~= "table" or type(payload.Enabled) ~= "boolean" then
			return responseError("Choose a valid Auto-Forge setup.")
		end
		local machine = Economy.GetMachine(payload.MachineId)
		if not machine then
			return responseError("That machine cannot be queued.")
		end
		local reserve = math.clamp(tonumber(payload.Reserve) or 0.25, 0, 0.9)
		return self:_mutate(player, function(profile)
			profile.AutoForge = profile.AutoForge or {}
			profile.AutoForge.Enabled = payload.Enabled
			profile.AutoForge.MachineId = machine.Id
			profile.AutoForge.Reserve = reserve
			profile.AutoForge.Bought = math.max(0, math.floor(tonumber(profile.AutoForge.Bought) or 0))
			local state = payload.Enabled and "online" or "paused"
			return responseSuccess(string.format("Auto-Forge %s: buying %s and keeping %d%% in reserve.", state, machine.Name, math.floor(reserve * 100 + 0.5)))
		end)
	end

	function GameService:_tickAutoForge(player: Player)
		local live = self._data:Get(player)
		local queue = live and live.AutoForge
		if not live or type(queue) ~= "table" or queue.Enabled ~= true then
			return
		end
		local machine = Economy.GetMachine(queue.MachineId)
		if not machine then
			return
		end
		local level = live.Machines[machine.Id] or 0
		local reserve = math.clamp(tonumber(queue.Reserve) or 0.25, 0, 0.9)
		if level < machine.MaxLevel then
			local lockReason = ProgressionGate.UpgradeReason(live, machine, live.Machines)
			local cost = Economy.MachineCost(machine.Id, level)
			if lockReason or Economy.Gt(cost, Economy.Mul(live.Cash, 1 - reserve)) then
				return
			end
		end

		local ok, result = self._data:AtomicUpdate(player, function(profile)
			local current = profile.AutoForge
			if type(current) ~= "table" or current.Enabled ~= true or current.MachineId ~= machine.Id then
				return responseError("Auto-Forge changed before purchase.")
			end
			local currentLevel = profile.Machines[machine.Id] or 0
			if currentLevel >= machine.MaxLevel then
				current.Enabled = false
				return responseSuccess("Auto-Forge paused at maximum level.")
			end
			if ProgressionGate.UpgradeReason(profile, machine, profile.Machines) then
				return responseError("Auto-Forge target is still locked.")
			end
			local currentReserve = math.clamp(tonumber(current.Reserve) or 0.25, 0, 0.9)
			local remaining = machine.MaxLevel - currentLevel
			local spendable = Economy.Mul(profile.Cash, 1 - currentReserve)
			local count, cost = Economy.AffordableMachineLevels(machine.Id, currentLevel, spendable, remaining)
			if count < 1 then
				return responseError("Auto-Forge is preserving its reserve.")
			end
			profile.Cash = Economy.Sub(profile.Cash, cost)
			profile.Machines[machine.Id] = currentLevel + count
			bumpStat(profile, "MachinesBought", count)
			current.Bought = math.max(0, math.floor(tonumber(current.Bought) or 0)) + count
			LabService.Progress(profile, "BuyLevels", count)
			local mastery = ensureCommandMastery(profile)
			mastery[machine.Id] = (tonumber(mastery[machine.Id]) or 0) + count
			ProgressionService.Progress(profile, "BuyMachine", count)
			ProgressionService.AwardCommandXP(profile, count * 5)
			ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.8, 2, 12))
			enforceUnlimitedMoney(profile)
			self._antiCheat:Observe(player, "AutoForge", profile)
			return responseSuccess("Auto-Forge bought one machine level.")
		end, true, "auto-forge")
		if ok and type(result) == "table" and result.ok == true then
			local profile = self._data:Get(player)
			if profile then
				self._world:RefreshPlot(player, profile)
			end
			self:_queueStatePush(player)
		end
	end

	function GameService:_buyResearch(player: Player, researchId: any, requestedAmount: any?)
		if type(researchId) ~= "string" then
			return responseError("Invalid research request.")
		end
		local research = Economy.GetResearch(researchId)
		if not research then
			return responseError("That research project does not exist.")
		end
		local result = self:_mutate(player, function(profile)
			local level = profile.Research[researchId] or 0
			if level >= research.MaxLevel then
				return responseError("That research is already complete.")
			end
			local lockReason = ProgressionGate.UpgradeReason(profile, research, profile.Research)
			if lockReason then
				return responseError(lockReason .. " first.")
			end
			local remainingLevels = research.MaxLevel - level
			local count
			local cost
			if requestedAmount == "Max" then
				count, cost = Economy.AffordableResearchLevels(
					researchId,
					level,
					profile.Cash,
					remainingLevels
				)
			else
				count = type(requestedAmount) == "number" and math.clamp(math.floor(requestedAmount), 1, 50) or 1
				count = math.min(count, remainingLevels)
				cost = Economy.ResearchBulkCost(researchId, level, count)
			end
			if count < 1 then
				return responseError("You cannot afford another research level yet.")
			end
			if Economy.Lt(profile.Cash, cost) then
				return responseError("You need " .. Format.Number(Economy.Sub(cost, profile.Cash)) .. " more flux.")
			end
			profile.Cash = Economy.Sub(profile.Cash, cost)
			profile.Research[researchId] = level + count
			bumpStat(profile, "ResearchBought", count)
			LabService.Progress(profile, "BuyLevels", count)
			ProgressionService.Progress(profile, "BuyResearch", count)
			ProgressionService.AwardCommandXP(profile, count * 4)
			ForgeEchoService.Record(profile, "Build", math.clamp(2 + count * 0.7, 2, 12))
			return responseSuccess(
				string.format("%s gained %d levels and reached level %d.", research.Name, count, level + count)
			)
		end)
		return result
	end

	function GameService:_unlockZone(player: Player, zoneId: any)
		if type(zoneId) == "string" then
			zoneId = tonumber(zoneId)
		end
		if type(zoneId) ~= "number" then
			return responseError("Invalid world request.")
		end
		zoneId = math.floor(zoneId + 0.5)
		local zone = Economy.GetZone(zoneId)
		if not zone then
			return responseError("That world does not exist.")
		end
		local result = self:_mutate(player, function(profile)
			local kind, err = ZoneUnlock.Evaluate(
				profile.Zone,
				profile.Rebirths,
				profile.Cores,
				profile.Cash,
				zoneId,
				zone,
				Economy.Lt
			)
			if kind == "Travel" then
				profile.CurrentZone = zoneId
				return responseSuccess("Traveled to " .. zone.Name .. ".")
			end
			if kind == "Error" then
				if err == "NEED_MORE_FLUX" then
					return responseError("You need " .. Format.Number(Economy.Sub(zone.Cost, profile.Cash)) .. " more flux.")
				end
				return responseError(err :: string)
			end
			profile.Cash = Economy.Sub(profile.Cash, zone.Cost)
			profile.Zone = zoneId
			profile.CurrentZone = zoneId
			LabService.Progress(profile, "UnlockWorld", 1)
			ForgeEchoService.Record(profile, "Explore", 12)
			return responseSuccess("Unlocked " .. zone.Name .. " and its production bonus.")
		end)
		if result.ok then
			self._world:RefreshPlot(player, self._data:Get(player))
		end
		return result
	end

	function GameService:_selectZone(player: Player, zoneId: any)
		if type(zoneId) == "string" then
			zoneId = tonumber(zoneId)
		end
		if type(zoneId) ~= "number" then
			return responseError("Invalid world request.")
		end
		zoneId = math.floor(zoneId + 0.5)
		local zone = Economy.GetZone(zoneId)
		if not zone then
			return responseError("That world does not exist.")
		end
		local result = self:_mutate(player, function(profile)
			if zoneId > profile.Zone then
				return responseError("Unlock that world first.")
			end
			profile.CurrentZone = zoneId
			return responseSuccess("Traveled to " .. zone.Name .. ".")
		end)
		if result.ok then
			self._world:RefreshPlot(player, self._data:Get(player))
		end
		return result
	end

	function GameService:_rebirth(player: Player)
		local result = self:_mutate(player, function(profile)
			local rebirthConfig = GameConfig.Economy.Rebirth or {}
			local bankVault = rebirthConfig.BankVaultIntoRun ~= false
			local effectiveRun = if bankVault
				then Economy.Add(profile.RunCash, profile.Vault)
				else profile.RunCash
			local reward = Economy.PrestigeReward(effectiveRun)
			if not RebirthGate.CanRebirth(reward, Economy.Gte) then
				return responseError(
					"Bank at least "
						.. Format.Number(GameConfig.Economy.PrestigeRequirement)
						.. " run flux first."
				)
			end
			local bankedVault = profile.Vault
			local multiplierBefore = Economy.PermanentMultiplier(profile)
			reward = Economy.Max(1, Economy.Floor(Economy.Mul(reward, 1 + Economy.DomainTreeBonus(profile, "RebirthYield"))))
			profile.Cores = Economy.AsNumber(Economy.Add(profile.Cores, reward))
			local stardustScale = tonumber(rebirthConfig.StardustSqrtScale) or 5
			local stardustMinimum = tonumber(rebirthConfig.StardustMinimum) or 4
			local stardustReward = RebirthGate.StardustReward(Economy.AsNumber(reward), stardustScale, stardustMinimum)
			profile.Stardust += stardustReward
			profile.BoostInventory = profile.BoostInventory or {}
			local celebrationBoost = rebirthConfig.CelebrationBoostId or "Overdrive"
			local bonusCount = math.max(1, math.floor(tonumber(rebirthConfig.BonusOverdrive) or 1))
			if GameConfig.Boosts[celebrationBoost] then
				profile.BoostInventory[celebrationBoost] = (profile.BoostInventory[celebrationBoost] or 0) + bonusCount
			end
			profile.Rebirths += 1
			profile.Cash = GameConfig.Economy.StartingCash
			profile.Vault = 0
			profile.RunCash = 0
			profile.Zone = 1
			profile.CurrentZone = 1
			profile.Machines = { StellarCore = 1 }

			if profile.Items and profile.Items.Equipped then
				for target in profile.Items.Equipped do
					local slot, targetId = string.match(target, "^(%a+):([%w_]+)$")
					if slot == "Machine" then
						local level = profile.Machines[targetId] or 0
						if type(level) ~= "number" or level < 1 then
							profile.Items.Equipped[target] = nil
						end
					end
				end
			end
			-- reward can be a persisted big-number string, so %d would throw on late-game rebirths
			return responseSuccess("Rebirth complete. +" .. Format.Number(reward) .. " cores, +" .. Format.Number(stardustReward) .. " stardust.", {
				Rebirths = profile.Rebirths,
				MultiplierBefore = multiplierBefore,
				MultiplierAfter = Economy.PermanentMultiplier(profile),
				Reward = reward,
				StardustReward = stardustReward,
				BankedVault = bankedVault,
				CelebrationBoost = celebrationBoost,
				NextTarget = GameConfig.Economy.PrestigeRequirement,
			})
		end)
		if result.ok then
			self._world:RefreshPlot(player, self._data:Get(player))
			self._effect:FireAllClients({
				Type = "Rebirth",
				UserId = player.UserId,
				Position = self._world:GetPlotPosition(player),
				Reward = result.Reward,
				StardustReward = result.StardustReward,
				BankedVault = result.BankedVault,
				CelebrationBoost = result.CelebrationBoost,
			})
		end
		return result
	end

	function GameService:_claimQuest(player: Player, questId: any)
		if type(questId) ~= "string" then
			return responseError("Invalid mission request.")
		end
		local result = self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimQuest(profile, questId)
			return ok and responseSuccess(message) or responseError(message)
		end)
		return result
	end

	function GameService:_claimAchievement(player: Player, achievementId: any)
		if type(achievementId) ~= "string" then
			return responseError("Invalid milestone request.")
		end
		local result = self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimAchievement(profile, achievementId)
			return ok and responseSuccess(message) or responseError(message)
		end)
		return result
	end

	function GameService:_claimDaily(player: Player)
		local result = self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimDaily(profile)
			return ok and responseSuccess(message) or responseError(message)
		end)
		return result
	end

	function GameService:_claimTimedReward(player: Player, rewardIndex: any)
		local result = self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimTimedReward(profile, rewardIndex)
			return ok and responseSuccess(message) or responseError(message)
		end)
		return result
	end

	function GameService:_bazaarPlay(player: Player, payload: any)
		return self:_mutate(player, function(profile)
			local now = os.time()
			local recovered, recoveryMessage = BazaarService.Roll(profile, now, player.UserId)
			if not recovered then return responseError(recoveryMessage) end
			local ok, message, extra = BazaarService.Play(profile, self._random, payload, now, player.UserId)
			if not ok then
				return responseError(message)
			end
			return responseSuccess(message, { Result = extra })
		end)
	end

	function GameService:_spinWheel(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.ExpectedSpin) ~= "number" then return responseError("Refresh the wheel before spinning.") end
		return self:_mutate(player, function(profile)
			local ok, message, prizeIndex, prizeId, pityHit = ProgressionService.SpinWheel(profile, self._random, payload.ExpectedSpin)
			if not ok then
				return responseError(message)
			end
			return responseSuccess(message, {
				PrizeIndex = prizeIndex,
				PrizeId = prizeId,
				Pity = pityHit == true,
			})
		end)
	end

	function GameService:_launchExpedition(player: Player, expeditionId: any)
		if type(expeditionId) ~= "string" then
			return responseError("Invalid expedition request.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.LaunchExpedition(profile, expeditionId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_claimExpedition(player: Player)
		local result = self:_mutate(player, function(profile)
			local ok, message, artifactId, artifactNew = ProgressionService.ClaimExpedition(profile, self._random)
			return ok and responseSuccess(message, { ArtifactId = artifactId, ArtifactNew = artifactNew })
				or responseError(message)
		end)
		return result
	end

	function GameService:_equipArtifact(player: Player, artifactId: any)
		if type(artifactId) ~= "string" then
			return responseError("Invalid artifact request.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.EquipArtifact(profile, artifactId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_buyArtifact(player: Player, artifactId: any)
		if type(artifactId) ~= "string" then
			return responseError("Invalid artifact request.")
		end
		return self:_mutate(player, function(profile)
			local ok, message, fresh = ProgressionService.BuyArtifact(profile, artifactId)
			return ok and responseSuccess(message, { ArtifactId = artifactId, ArtifactNew = fresh }) or responseError(message)
		end)
	end

	function GameService:_upgradeArtifact(player: Player, artifactId: any)
		if type(artifactId) ~= "string" then
			return responseError("Invalid artifact request.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.UpgradeArtifact(profile, artifactId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_upgradeCrew(player: Player, roleId: any)
		if type(roleId) ~= "string" then
			return responseError("Invalid crew request.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.UpgradeCrew(profile, roleId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_claimCommanderReward(player: Player, level: any)
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimCommanderReward(profile, level)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_claimWeeklyDirective(player: Player, directiveId: any)
		if type(directiveId) ~= "string" then
			return responseError("Invalid weekly directive.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimWeeklyDirective(profile, directiveId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_claimSeasonTier(player: Player, tier: any)
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimSeasonTier(profile, tier)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_claimForgePathStep(player: Player, step: any)
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.ClaimForgePathStep(profile, step)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_buySignalOffer(player: Player, offerId: any)
		if type(offerId) ~= "string" then
			return responseError("Invalid signal shop offer.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.BuySignalOffer(profile, offerId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_equipTitle(player: Player, titleId: any)
		if GameConfig.Operations.TitlesEnabled == false then
			return responseError(GameConfig.Operations.TitleStatus or "Titles are temporarily unavailable.")
		end
		if type(titleId) ~= "string" then
			return responseError("Invalid title request.")
		end
		return self:_mutate(player, function(profile)
			local ok, message = ProgressionService.EquipTitle(profile, titleId)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_redeemCode(player: Player, rawCode: any)
		if type(rawCode) ~= "string" then
			return responseError("Enter a valid code.")
		end
		local code = string.upper(rawCode:gsub("%s+", ""))
		if #code < 1 or #code > 24 then
			return responseError("Enter a valid code.")
		end
		local codeData = ServerConfig.Codes[code]
		if not codeData then
			return responseError("That code is invalid or already used.")
		end
		local result = self:_mutate(player, function(profile)
			profile.Codes = profile.Codes or {}
			if profile.Codes[code] then
				return responseError("You already redeemed that code.")
			end
			profile.Codes[code] = true
			local rewardText =
				ProgressionService.ApplyReward(profile, codeData.Reward, Economy.Production(profile))
			return responseSuccess(rewardText)
		end)
		if result.ok then
			self._effect:FireClient(player, { Type = "FeatureUnlocked" })
		end
		return result
	end

	function GameService:_grantDevProduct(profile, productDef): string
		return ProgressionService.ApplyReward(profile, productDef.Reward, Economy.Production(profile))
	end

	function GameService:_processReceipt(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local productDef = MonetizationConfig.FindDevProductByProductId(receiptInfo.ProductId)
		if not productDef then
			ModuleLog.Warn("Shop", string.format("unknown ProductId %s", tostring(receiptInfo.ProductId)))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local purchaseKey = tostring(receiptInfo.PurchaseId)
		local rewardText = ""
		local already = false
		local updated = self._data:Update(player, function(profile)
			local recorded, alreadyProcessed = ReceiptLedger.Record(profile.Receipts, purchaseKey, os.time())
			profile.Receipts = recorded
			if alreadyProcessed then
				already = true
				return
			end
			rewardText = self:_grantDevProduct(profile, productDef)
		end)
		if not updated then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not self._data:Save(player, false) then
			ModuleLog.Warn("Shop", string.format("receipt %s is waiting on a save", purchaseKey))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not already then
			self:_syncLeaderstats(player, self._data:Get(player))
			self:_pushState(player)
			self:_toastPlayer(player, "Purchase complete", rewardText ~= "" and rewardText or productDef.Name, "Special")
			self._effect:FireClient(player, { Type = "FeatureUnlocked" })
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	function GameService:_syncShop(player: Player)

		local ownedPasses = {}
		for _, passDef in MonetizationConfig.GamePasses do
			if passDef.PassId > 0 then
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passDef.PassId)
				end)
				if ok and owns then
					ownedPasses[passDef.Key] = true
				end
			end
		end

		if not self._running or player.Parent ~= Players or self._runtime[player] == nil then
			return responseError("That forge session is no longer active.")
		end
		local result = self:_mutate(player, function(profile)
			profile.OwnedPasses = profile.OwnedPasses or {}
			profile.Receipts = profile.Receipts or {}
			for passKey in ownedPasses do
				profile.OwnedPasses[passKey] = true
			end
			return responseSuccess("Dock inventory synced.")
		end)
		return result
	end

	function GameService:_studioGrantProduct(player: Player, rawKey: any)
		if not ShopGrantEligibility.StudioGrantAllowed(RunService:IsStudio()) then
			return responseError("Studio grants are disabled in live servers.")
		end
		if type(rawKey) ~= "string" then
			return responseError("Invalid product key.")
		end
		local productDef = MonetizationConfig.FindDevProductByKey(rawKey)
		local passDef = MonetizationConfig.FindPassByKey(rawKey)
		if not productDef and not passDef then
			return responseError("Unknown studio product or pass.")
		end
		local result = self:_mutate(player, function(profile)
			if passDef then
				profile.OwnedPasses = profile.OwnedPasses or {}
				if profile.OwnedPasses[passDef.Key] then
					return responseSuccess(passDef.Name .. " already owned.")
				end
				profile.OwnedPasses[passDef.Key] = true
				local parts = {}
				if (passDef.ProductionBonus or 0) > 0 then
					table.insert(parts, string.format("+%d%% production", math.floor((passDef.ProductionBonus or 0) * 100 + 0.5)))
				end
				if (passDef.CapacityBonus or 0) > 0 then
					table.insert(parts, string.format("+%d%% vault", math.floor((passDef.CapacityBonus or 0) * 100 + 0.5)))
				end
				local detail = #parts > 0 and table.concat(parts, " · ") or "Pass linked"
				return responseSuccess(passDef.Name .. ": " .. detail)
			end
			assert(productDef ~= nil, "studio grant missing product")
			local rewardText = self:_grantDevProduct(profile, productDef)
			return responseSuccess(rewardText)
		end)
		if result.ok then
			self:_toastPlayer(player, "Purchase test", result.message or rawKey, "Success")
			self._effect:FireClient(player, { Type = "FeatureUnlocked" })
		end
		return result
	end

	function GameService:_activateBoost(player: Player, boostId: any)
		if type(boostId) ~= "string" or not GameConfig.Boosts[boostId] then
			return responseError("Invalid boost request.")
		end
		local boost = GameConfig.Boosts[boostId]
		local result = self:_mutate(player, function(profile)
			local active = ensureActiveBoost(profile)
			if active.EndsAt > os.time() then
				return responseError("Another boost is already active.")
			end
			local inventory = ensureBoostInventory(profile)
			if (tonumber(inventory[boostId]) or 0) < 1 then
				return responseError("You do not own that boost.")
			end
			inventory[boostId] = math.max(0, math.floor(tonumber(inventory[boostId]) or 0) - 1)
			profile.ActiveBoost = { Id = boostId, EndsAt = os.time() + boost.Duration }
			return responseSuccess(boost.Name .. " activated!")
		end)
		return result
	end

	function GameService:_createItem(profile, definitionId: string): string?
		local items = ProfileBagMath.EnsureItems(profile)
		if not itemById[definitionId] or inventoryCount(profile) >= GameConfig.Items.InventoryLimit then
			return nil
		end
		local uid
		repeat
			uid = string.format("IT%07d", items.NextId)
			items.NextId += 1
		until not items.Inventory[uid]
		items.Inventory[uid] = {
			DefinitionId = definitionId,
			Level = 1,
			AcquiredAt = os.time(),
		}
		items.Discovered = type(items.Discovered) == "table" and items.Discovered or {}
		items.Discovered[definitionId] = true
		bumpStat(profile, "ItemsFound", 1)
		return uid
	end

	function GameService:_rollItemDefinition(crate, pity: number)
		return CrateRollResolver.roll(
			crate,
			pity,
			GameConfig.Items.Rarities,
			GameConfig.Items.Definitions,
			function(definition)
				return definition.Rarity
			end,
			function(lo, hi)
				return self._random:NextNumber(lo, hi)
			end,
			function(lo, hi)
				return self._random:NextInteger(lo, hi)
			end,
			CrateConfig.RarityOrder,
			CrateConfig.MinimumRollInterval
		)
	end

	function GameService:_buyItemOffer(player: Player, offerId: any)
		if type(offerId) ~= "string" or not itemOfferById[offerId] then
			return responseError("That market offer does not exist.")
		end
		local offer = itemOfferById[offerId]
		local result = self:_mutate(player, function(profile)
			local items = ProfileBagMath.EnsureItems(profile)
			ensureItemShop(profile)
			local stockMax = offerStockMax(offer)
			local remaining = ShopGrantEligibility.RemainingStock(items.Shop.Stock[offerId], stockMax)
			local eligible, denyReason = ShopGrantEligibility.EvaluateBuy(
				offer,
				remaining,
				inventoryCount(profile),
				GameConfig.Items.InventoryLimit,
				profile[offer.Currency],
				function(need, currency)
					return string.format("You need %s more %s.", Format.Number(need), currency)
				end
			)
			if not eligible then
				return responseError(denyReason or "That market offer is unavailable.")
			end
			profile[offer.Currency] -= offer.Price
			local itemUid
			if offer.Kind == "Key" then
				items.Keys[offer.CrateId] = (items.Keys[offer.CrateId] or 0) + offer.Amount
			elseif offer.Kind == "Essence" then
				items.Essence += offer.Amount
			elseif offer.Kind == "Item" then
				itemUid = self:_createItem(profile, offer.ItemId)
				if not itemUid then
					return responseError("The market could not deliver that item.")
				end
			else
				return responseError("That market offer is misconfigured.")
			end
			local nextStock = remaining - 1
			items.Shop.Stock[offerId] = nextStock
			items.Shop.Purchased[offerId] = nextStock <= 0
			bumpStat(profile, "ShopPurchases", 1)
			return responseSuccess(offer.Name .. " bought.", { ItemUid = itemUid, Stock = nextStock })
		end)
		return result
	end

	local function shopShared()
		local SharedData = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))
		return SharedData("ShopCatalog"), SharedData("RelicSystem")
	end

	local function spendShopCurrency(profile, currency: string, price: number): string?
		if currency ~= "Stardust" and currency ~= "Cores" then
			return "That offer can't be bought with " .. tostring(currency) .. "."
		end
		local have = tonumber(profile[currency]) or 0
		if have < price then
			return string.format("You need %s more %s.", Format.Number(price - have), string.lower(currency))
		end
		profile[currency] = have - price
		return nil
	end

	function GameService:_buyDailyOffer(player: Player, slot: any)
		if type(slot) ~= "number" or slot ~= slot then
			return responseError("That daily offer does not exist.")
		end
		local ShopCatalog = shopShared()
		local now = os.time()
		local day = ShopCatalog.day(now)
		return self:_mutate(player, function(profile)
			local cosmetics = ProfileBagMath.EnsureCosmetics(profile, function(id)
				return ShopCatalog.skin(id) ~= nil
			end)
			local shop = ProfileBagMath.EnsureDailyShop(profile, day, cosmetics.CrateSkins)
			local offers = ShopCatalog.roll(player.UserId, day, shop.Owned)
			local offer = offers[math.floor(slot)]
			if offer == nil then
				return responseError("That daily offer does not exist.")
			end
			if ShopCatalog.remaining(offer, shop.Bought) <= 0 then
				return responseError("You've bought all of that one today.")
			end
			if offer.Kind == "Skin" and cosmetics.CrateSkins[offer.SkinId] == true then
				return responseError("You already own that skin.")
			end
			if offer.Kind == "Cache" and inventoryCount(profile) >= GameConfig.Items.InventoryLimit then
				return responseError("Your relic inventory is full.")
			end
			local denied = spendShopCurrency(profile, offer.Currency, offer.Price)
			if denied then
				return responseError(denied)
			end
			local items = ProfileBagMath.EnsureItems(profile)
			local detail = { Slot = offer.Slot, Kind = offer.Kind }
			if offer.Kind == "Key" then
				items.Keys[offer.CrateId] = (items.Keys[offer.CrateId] or 0) + offer.Amount
			elseif offer.Kind == "Essence" then
				items.Essence += offer.Amount
			elseif offer.Kind == "Boost" then
				local inventory = ensureBoostInventory(profile)
				inventory[offer.BoostId] = math.floor(tonumber(inventory[offer.BoostId]) or 0) + offer.Amount
			elseif offer.Kind == "Flux" then
				local generated = Economy.Max(500, Economy.Mul(Economy.SteadyProduction(profile), 60 * offer.Minutes))
				profile.Cash = Economy.Add(profile.Cash, generated)
				profile.RunCash = Economy.Add(profile.RunCash, generated)
				profile.LifetimeCash = Economy.Add(profile.LifetimeCash, generated)
			elseif offer.Kind == "Skin" then
				cosmetics.CrateSkins[offer.SkinId] = true
			elseif offer.Kind == "Cache" then
				local candidates = {}
				for _, definition in GameConfig.Items.Definitions do
					if definition.Rarity == offer.Rarity then
						table.insert(candidates, definition)
					end
				end
				if #candidates == 0 then
					return responseError("That cache is empty.")
				end
				local definition = candidates[self._random:NextInteger(1, #candidates)]
				local wasOwned = type(items.Discovered) == "table" and items.Discovered[definition.Id] == true
				local uid = self:_createItem(profile, definition.Id)
				if not uid then
					return responseError("Your relic inventory is full.")
				end
				detail.Rolls = { { Uid = uid, DefinitionId = definition.Id, Rarity = definition.Rarity, New = not wasOwned, Pity = false, AutoSalvaged = false, Essence = 0 } }
			else
				return responseError("That offer is misconfigured.")
			end
			local key = tostring(offer.Slot)
			shop.Bought[key] = (shop.Bought[key] or 0) + 1
			bumpStat(profile, "ShopPurchases", 1)
			return responseSuccess(offer.Name .. " bought.", detail)
		end)
	end

	function GameService:_buyCrateSkin(player: Player, id: any)
		local ShopCatalog = shopShared()
		local skin = ShopCatalog.skin(id)
		if skin == nil or skin.Price == nil then
			return responseError("That skin isn't for sale.")
		end
		if skin.DailyOnly then
			return responseError("That skin only appears in the Daily Shop.")
		end
		return self:_mutate(player, function(profile)
			local cosmetics = ProfileBagMath.EnsureCosmetics(profile, function(skinId)
				return ShopCatalog.skin(skinId) ~= nil
			end)
			if cosmetics.CrateSkins[skin.Id] == true then
				return responseError("You already own that skin.")
			end
			ProfileBagMath.EnsureDailyShop(profile, ShopCatalog.day(os.time()), cosmetics.CrateSkins)
			local denied = spendShopCurrency(profile, skin.Price.Currency, skin.Price.Amount)
			if denied then
				return responseError(denied)
			end
			cosmetics.CrateSkins[skin.Id] = true
			cosmetics.CrateSkin = skin.Id
			bumpStat(profile, "ShopPurchases", 1)
			return responseSuccess(skin.Name .. " unlocked and equipped.", { Skin = skin.Id })
		end)
	end

	function GameService:_equipCrateSkin(player: Player, id: any)
		local ShopCatalog = shopShared()
		local skin = ShopCatalog.skin(id)
		if skin == nil then
			return responseError("That skin doesn't exist.")
		end
		return self:_mutate(player, function(profile)
			local cosmetics = ProfileBagMath.EnsureCosmetics(profile, function(skinId)
				return ShopCatalog.skin(skinId) ~= nil
			end)
			if cosmetics.CrateSkins[skin.Id] ~= true then
				return responseError("You don't own that skin yet.")
			end
			cosmetics.CrateSkin = skin.Id
			return responseSuccess(skin.Name .. " equipped.", { Skin = skin.Id })
		end)
	end

	function GameService:_fuseRelics(player: Player, definitionId: any)
		if type(definitionId) ~= "string" or not itemById[definitionId] then
			return responseError("That relic doesn't exist.")
		end
		local _, RelicSystem = shopShared()
		local definition = itemById[definitionId]
		return self:_mutate(player, function(profile)
			local items = ProfileBagMath.EnsureItems(profile)
			local maxStars = GameConfig.Items.MaxStars or 5
			local targetUid, fodderUid, reason = RelicSystem.fusionPair(items.Inventory, items.Equipped, definitionId, maxStars)
			if targetUid == nil or fodderUid == nil then
				return responseError(reason or "Those relics can't be fused.")
			end
			local target = items.Inventory[targetUid]
			local fodder = items.Inventory[fodderUid]
			local stars, level = RelicSystem.fuse(target, fodder, maxStars)
			target.Stars = stars
			target.Level = math.min(level, definition.MaxLevel)
			items.Inventory[fodderUid] = nil
			bumpStat(profile, "RelicsFused", 1)
			return responseSuccess(string.format("%s fused to %d star%s.", definition.Name, stars, if stars == 1 then "" else "s"), {
				Uid = targetUid,
				Stars = stars,
				DefinitionId = definitionId,
				Rarity = definition.Rarity,
			})
		end)
	end

	function GameService:_openItemCrate(player: Player, crateId: any, rawCount: any)
		if type(crateId) ~= "string" or not crateById[crateId] then
			return responseError("That crate channel does not exist.")
		end
		local count, countError = CrateRoll.NormalizeOpenCount(rawCount)
		if not count then
			return responseError(countError or "Crates can be opened one or five at a time.")
		end
		local crate = crateById[crateId]
		local result = self:_mutate(player, function(profile)
			local items = ProfileBagMath.EnsureItems(profile)
			if (items.Keys[crateId] or 0) < count then
				return responseError(
					string.format(
						"You need %d more %s keys.",
						count - (items.Keys[crateId] or 0),
						crate.Name
					)
				)
			end
			local autoRules = ensureAutoSalvage(profile)
			local autoEnabled = autoRules.Enabled == true
				and profile.OwnedPasses
				and profile.OwnedPasses.AutoSalvage == true

			local guaranteedRecycle = CrateRoll.GuaranteedRecycle(
				crate.Weights,
				autoEnabled,
				autoRules.KeepNew,
				autoRules.Rarities
			)
			local requiredSlots = CrateRoll.RequiredSlots(count, guaranteedRecycle)
			if inventoryCount(profile) + requiredSlots > GameConfig.Items.InventoryLimit then
				return responseError("Your item inventory does not have enough open slots.")
			end
			items.Keys[crateId] -= count
			local rolls = {}
			local cosmetics = ProfileBagMath.EnsureCosmetics(profile)
			local shopCatalog = require(game.ReplicatedStorage.AstralForge.Shared.SharedData)("ShopCatalog")
			local expansion = require(game.ReplicatedStorage.AstralForge.Shared.CrateExpansion)
			local equippedSkin = shopCatalog.skin(cosmetics.CrateSkin)
			local pityStep = expansion.pityStep(cosmetics, equippedSkin)
			for index = 1, count do
				local pity = items.Pity[crateId] or 0
				local definition, rarity, pityHit = self:_rollItemDefinition(crate, pity)
				if not definition then
					return responseError("That crate has no valid drops configured.")
				end
				items.Discovered = type(items.Discovered) == "table" and items.Discovered or {}
				local wasOwned = items.Discovered[definition.Id] == true
				local shouldAutoSalvage = autoEnabled
					and autoRules.Rarities[rarity] == true
					and not (autoRules.KeepNew ~= false and not wasOwned)
				local uid
				local autoEssence = 0
				if shouldAutoSalvage then
					autoEssence = expansion.salvageEssence(cosmetics, equippedSkin, itemSalvageValue({ Level = 1 }, definition))
					items.Essence += autoEssence
					bumpStat(profile, "ItemsFound", 1)
					bumpStat(profile, "ItemsSalvaged", 1)
					items.Discovered[definition.Id] = true
					uid = string.format("AUTO%07d", items.NextId)
					items.NextId += 1
				else
					uid = self:_createItem(profile, definition.Id)
					if not uid then
						return responseError("The crate decoder ran out of inventory space. Adjust auto-salvage or clear a slot.")
					end
				end
				items.Pity[crateId] = pityHit and 0 or pity + pityStep
				rolls[index] = {
					Uid = uid,
					DefinitionId = definition.Id,
					Rarity = rarity,
					New = not wasOwned,
					Pity = pityHit,
					AutoSalvaged = shouldAutoSalvage,
					Essence = autoEssence,
				}
			end
			local skinBonus = expansion.openBonus(cosmetics, equippedSkin, count)
			items.Essence += skinBonus
			bumpStat(profile, "CratesOpened", count)
			LabService.Progress(profile, "OpenCrate", count)
			return responseSuccess(
				string.format("Decoded %d %s%s.", count, crate.Name, count == 1 and "" or "s"),
				{ Rolls = rolls, CrateId = crateId, Pity = items.Pity[crateId], SkinEssence = skinBonus }
			)
		end)
		return result
	end

	function GameService:_equipItem(player: Player, uid: any, target: any)
		if type(uid) ~= "string" or type(target) ~= "string" then
			return responseError("Invalid socket request.")
		end
		local result = self:_mutate(player, function(profile)
			local instance = profile.Items.Inventory[uid]
			local definition = instance and itemById[instance.DefinitionId]
			if not definition then
				return responseError("That item is not in your inventory.")
			end
			local slot, targetId = string.match(target, "^(%a+):([%w_]+)$")
			if definition.Slot ~= slot then
				return responseError(
					string.format("%s items only fit %s sockets.", definition.Name, definition.Slot)
				)
			end
			if definition.Targets and not table.find(definition.Targets, targetId) then
				return responseError(definition.Name .. " is not compatible with that upgrade.")
			end
			local ownedLevel = slot == "Machine" and profile.Machines[targetId]
				or slot == "Research" and profile.Research[targetId]
			if type(ownedLevel) ~= "number" or ownedLevel < 1 then
				return responseError("Unlock at least one level of that upgrade before socketing an item.")
			end
			for equippedTarget, equippedUid in profile.Items.Equipped do
				if equippedUid == uid then
					profile.Items.Equipped[equippedTarget] = nil
				end
			end
			profile.Items.Equipped[target] = uid
			return responseSuccess(definition.Name .. " attached to " .. targetId .. ".", {
				ItemName = definition.Name,
				Rarity = definition.Rarity,
				Target = target,
			})
		end)
		if result.ok then
			self:_toastPlayer(player, "Relic linked", result.message, "Success")
			self._effect:FireClient(player, {
				Type = "ItemLinked",
				ItemName = result.ItemName,
				Rarity = result.Rarity,
				Target = result.Target,
			})
		end
		return result
	end

	function GameService:_unequipItem(player: Player, target: any)
		if type(target) ~= "string" then
			return responseError("Invalid socket request.")
		end
		local result = self:_mutate(player, function(profile)
			if not profile.Items.Equipped[target] then
				return responseError("That socket is already empty.")
			end
			profile.Items.Equipped[target] = nil
			return responseSuccess("Item returned to inventory.")
		end)
		if result.ok then
			self:_toastPlayer(player, "Relic detached", result.message, "Info")
		end
		return result
	end

	function GameService:_upgradeItem(player: Player, uid: any)
		if type(uid) ~= "string" then
			return responseError("Invalid item request.")
		end
		return self:_mutate(player, function(profile)
			local instance = profile.Items.Inventory[uid]
			local definition = instance and itemById[instance.DefinitionId]
			if not definition then
				return responseError("That item is not in your inventory.")
			end
			if instance.Level >= definition.MaxLevel then
				return responseError("That item is already max level.")
			end
			local cost = math.floor(definition.EssenceBase * 1.55 ^ math.max(0, instance.Level - 1))
			if profile.Items.Essence < cost then
				return responseError(
					string.format("You need %d more item essence.", cost - profile.Items.Essence)
				)
			end
			profile.Items.Essence -= cost
			instance.Level += 1
			return responseSuccess(string.format("%s upgraded to level %d.", definition.Name, instance.Level))
		end)
	end

	function GameService:_salvageItem(player: Player, uid: any)
		if type(uid) ~= "string" then
			return responseError("Invalid item request.")
		end
		return self:_mutate(player, function(profile)
			local instance = profile.Items.Inventory[uid]
			local definition = instance and itemById[instance.DefinitionId]
			if not definition then
				return responseError("That item is not in your inventory.")
			end
			if instance.Locked == true then
				return responseError("Unlock that relic before salvaging it.")
			end
			for _, equippedUid in profile.Items.Equipped do
				if equippedUid == uid then
					return responseError("Detach that item before salvaging it.")
				end
			end
			local essence = itemSalvageValue(instance, definition)
			profile.Items.Inventory[uid] = nil
			profile.Items.Essence += essence
			bumpStat(profile, "ItemsSalvaged", 1)
			return responseSuccess(
				string.format("Salvaged %s for %d essence.", definition.Name, essence),
				{ Amount = essence }
			)
		end)
	end

	function GameService:_setSetting(player: Player, payload: any)
		if type(payload) ~= "table" then
			return responseError("Invalid setting request.")
		end
		local Schema = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("SharedData"))("SettingsSchema")
		local sliderKeys = setmetatable({}, {
			__index = function(_, key)
				return Schema.accepts(key)
			end,
		})
		local notifyKeys = {
			NotifyGuild = true,
		}
		local function sealSettings(profile)
			SettingsSeal.Apply(profile)
		end
		if type(payload.Values) == "table" then
			return self:_mutate(player, function(profile)
				local applied = 0
				for key, value in payload.Values do
					if applied >= 24 then
						break
					end
					if type(key) == "string" and type(value) == "number" and sliderKeys[key] then
						profile.Settings[key] = Schema.normalize(key, value)
						applied += 1
					end
				end
				if applied == 0 then
					return responseError("Unknown setting.")
				end
				sealSettings(profile)
				local label = payload.Label
				if type(label) == "string" and label ~= "" then
					label = string.sub(label, 1, 80)
					local _, brokenAt = utf8.len(label)
					return responseSuccess(if brokenAt then string.sub(label, 1, brokenAt - 1) else label)
				end
				return responseSuccess("Settings updated.")
			end)
		end
		if type(payload.Key) ~= "string" or type(payload.Value) ~= "number" then
			return responseError("Unknown setting.")
		end
		if sliderKeys[payload.Key] then
			return self:_mutate(player, function(profile)
				profile.Settings[payload.Key] = Schema.normalize(payload.Key, payload.Value)
				sealSettings(profile)
				return responseSuccess("Setting updated.")
			end)
		end
		if notifyKeys[payload.Key] then
			return self:_mutate(player, function(profile)
				profile.Settings[payload.Key] = payload.Value >= 0.5 and 1 or 0
				return responseSuccess(payload.Value >= 0.5 and "You'll be notified." or "Notification cleared.")
			end)
		end
		return responseError("Unknown setting.")
	end

	function GameService:_upgradeContinuum(player: Player)
		return self:_mutate(player, function(profile)
			profile.Continuum = profile.Continuum or {
				Rank = 0,
				TotalFluxSpent = 0,
				TotalStardustSpent = 0,
			}
			local rank = math.max(0, math.floor(tonumber(profile.Continuum.Rank) or 0))
			if rank >= GameConfig.Continuum.MaxRank then
				return responseError("The Continuum has reached the exact-integer engine limit.")
			end
			local fluxCost, stardustCost = Economy.ContinuumCosts(rank)
			if Economy.Lt(profile.Cash, fluxCost) then
				return responseError("You need " .. Format.Number(Economy.Sub(fluxCost, profile.Cash)) .. " more flux.")
			end
			if Economy.Lt(profile.Stardust, stardustCost) then
				return responseError("You need " .. Format.Number(Economy.Sub(stardustCost, profile.Stardust)) .. " more Stardust.")
			end

			profile.Cash = Economy.Sub(profile.Cash, fluxCost)
			profile.Stardust = Economy.AsNumber(Economy.Sub(profile.Stardust, stardustCost))
			profile.Continuum.Rank = rank + 1
			profile.Continuum.TotalFluxSpent = Economy.Persist(Economy.Add(profile.Continuum.TotalFluxSpent, fluxCost))
			profile.Continuum.TotalStardustSpent = math.min(
				1e308,
				math.max(0, tonumber(profile.Continuum.TotalStardustSpent) or 0) + stardustCost
			)
			local stats = ensureStats(profile)
			stats.ContinuumUpgrades = math.min(
				1e308,
				math.max(0, tonumber(stats.ContinuumUpgrades) or 0) + 1
			)
			ProgressionService.AwardCommandXP(profile, 20 + math.min(480, rank * 2))

			local nextProduction = select(1, Economy.ContinuumEffects(profile))
			local milestone = (rank + 1) % GameConfig.Continuum.MilestoneEvery == 0
			return responseSuccess(
				string.format(
					"Continuum rank %d reached. Production is now %s.",
					rank + 1,
					Format.Number(nextProduction) .. "x"
				),
				{ Level = rank + 1, Milestone = milestone }
			)
		end)
	end

	function GameService:_toggleItemLock(player: Player, uid: any)
		if type(uid) ~= "string" then
			return responseError("Invalid relic request.")
		end
		return self:_mutate(player, function(profile)
			local instance = profile.Items.Inventory[uid]
			local definition = instance and itemById[instance.DefinitionId]
			if not definition then
				return responseError("That relic is not in your inventory.")
			end
			instance.Locked = instance.Locked ~= true
			return responseSuccess(
				instance.Locked and (definition.Name .. " protected.") or (definition.Name .. " unlocked."),
				{ Uid = uid, Locked = instance.Locked }
			)
		end)
	end

	function GameService:_bulkSalvageItems(player: Player, rawUids: any)
		if type(rawUids) ~= "table" then
			return responseError("Select at least one relic.")
		end
		return self:_mutate(player, function(profile)
			local requested = {}
			local requestCount = 0
			for _, uid in rawUids do
				if type(uid) ~= "string" or #uid < 1 or #uid > 48 then
					return responseError("The relic selection is invalid.")
				end
				if not requested[uid] then
					requestCount += 1
					if requestCount > 25 then
						return responseError("Salvage up to 25 relics at once.")
					end
					requested[uid] = true
				end
			end
			if requestCount == 0 then
				return responseError("Select at least one relic.")
			end
			local equipped = {}
			for _, equippedUid in profile.Items.Equipped do
				equipped[equippedUid] = true
			end
			local removed = 0
			local essence = 0
			local protected = 0
			for uid in requested do
				local instance = profile.Items.Inventory[uid]
				local definition = instance and itemById[instance.DefinitionId]
				if definition and not equipped[uid] and instance.Locked ~= true then
					profile.Items.Inventory[uid] = nil
					removed += 1
					essence += itemSalvageValue(instance, definition)
				elseif instance then
					protected += 1
				end
			end
			if removed == 0 then
				return responseError(protected > 0 and "Every selected relic is equipped or protected." or "Those relics are no longer available.")
			end
			profile.Items.Essence += essence
			bumpStat(profile, "ItemsSalvaged", removed)
			return responseSuccess(
				string.format("Salvaged %d relic%s for %d essence%s.", removed, removed == 1 and "" or "s", essence, protected > 0 and string.format("; %d protected", protected) or ""),
				{ Count = removed, Amount = essence, Protected = protected }
			)
		end)
	end

	function GameService:_equipBestItems(player: Player)
		return self:_mutate(player, function(profile)
			local targets = ItemLoadoutMath.BuildTargets(
				GameConfig.Machines,
				GameConfig.Research,
				profile.Machines,
				profile.Research
			)
			local candidates = {}
			for uid, instance in profile.Items.Inventory do
				local definition = itemById[instance.DefinitionId]
				if definition then
					table.insert(candidates, {
						Uid = uid,
						Instance = instance,
						Definition = definition,
						Power = ItemLoadoutMath.CandidatePower(definition, instance.Level),
					})
				end
			end
			local nextEquipped, equippedCount, changed = ItemLoadoutMath.PlanEquipBest(
				targets,
				candidates,
				GameConfig.Items.Rarities,
				profile.Items.Equipped
			)
			profile.Items.Equipped = nextEquipped
			return responseSuccess(
				#targets == 0 and "Unlock a machine or research socket first."
					or equippedCount == 0 and "No compatible relics are available yet."
					or string.format("Best loadout equipped across %d socket%s.", equippedCount, equippedCount == 1 and "" or "s"),
				{ Equipped = equippedCount, Changed = changed }
			)
		end)
	end

	function GameService:_setItemAutoSalvage(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.Enabled) ~= "boolean" or type(payload.KeepNew) ~= "boolean" or type(payload.Rarities) ~= "table" then
			return responseError("Invalid auto-salvage request.")
		end
		return self:_mutate(player, function(profile)
			if not profile.OwnedPasses or profile.OwnedPasses.AutoSalvage ~= true then
				return { ok = false, error = "Relic Recycler is required for auto-salvage.", RequiresPass = "AutoSalvage" }
			end
			local rarities = {}
			for rarity in GameConfig.Items.Rarities do rarities[rarity] = false end
			local count = 0
			for _, rarity in payload.Rarities do
				if type(rarity) ~= "string" or not GameConfig.Items.Rarities[rarity] then
					return responseError("An auto-salvage rarity is invalid.")
				end
				if not rarities[rarity] then
					count += 1
					if count > 6 then return responseError("Too many auto-salvage rarities.") end
					rarities[rarity] = true
				end
			end
			local rules = ensureAutoSalvage(profile)
			rules.Enabled = payload.Enabled
			rules.KeepNew = payload.KeepNew
			rules.Rarities = rarities
			return responseSuccess(payload.Enabled and "Relic Recycler armed." or "Relic Recycler paused.")
		end)
	end

	function GameService:_unlockDomainNode(player: Player, nodeId: any)
		if type(nodeId) ~= "string" or nodeId == "" then
			return responseError("Invalid domain node.")
		end
		return self:_mutate(player, function(profile)
			if (profile.Domain and profile.Domain.Rank or 0) < 1 then
				return responseError("Expand your domain first.")
			end
			profile.Domain.Nodes = type(profile.Domain.Nodes) == "table" and profile.Domain.Nodes or {}
			if profile.Domain.Nodes[nodeId] == true or profile.Domain.Nodes[nodeId] == 1 then
				return responseError("That branch is already open.")
			end
			local definition = nil
			for _, node in GameConfig.Domain.Tree do
				if node.Id == nodeId then
					definition = node
					break
				end
			end
			if not definition then
				return responseError("Unknown domain branch.")
			end
			for _, required in (definition.Requires or {}) do
				if profile.Domain.Nodes[required] ~= true and profile.Domain.Nodes[required] ~= 1 then
					return responseError("Open the earlier branch first.")
				end
			end
			local cost = math.max(1, math.floor(tonumber(definition.Cost) or 1))
			local points = math.max(0, math.floor(tonumber(profile.Domain.SkillPoints) or 0))
			if points < cost then
				return responseError(string.format("Need %d domain points.", cost))
			end
			profile.Domain.SkillPoints = points - cost
			profile.Domain.Nodes[nodeId] = true
			return responseSuccess(definition.Name .. " bound to your domain.")
		end)
	end

	function GameService:_domainExpansion(player: Player)
		local details = nil
		local result = self:_mutate(player, function(profile)
			profile.Domain = profile.Domain or {
				Rank = 0,
				Essence = 0,
				LastExpandedAt = 0,
				TotalRebirthsSpent = 0,
				TotalCoresSpent = 0,
			}
			local expansion = GameConfig.Domain.Expansion or {}
			local cooldown = math.max(1, math.floor(tonumber(expansion.CooldownSeconds) or 6))
			local rank = math.max(0, math.floor(tonumber(profile.Domain.Rank) or 0))
			if os.time() - math.max(0, math.floor(tonumber(profile.Domain.LastExpandedAt) or 0)) < cooldown then
				return responseError("Reality is still settling.")
			end
			local requiredRebirths, requiredCores = Economy.DomainRequirements(rank)
			if not RebirthGate.MeetsRequired(profile.Rebirths, requiredRebirths) then
				return responseError(string.format("Domain rank %d requires %d rebirths.", rank + 1, requiredRebirths))
			end
			if profile.Cores < requiredCores then
				return responseError(string.format("Domain rank %d requires %d astral cores.", rank + 1, requiredCores))
			end

			local essenceReward, stardustReward = Economy.DomainRewards(rank)
			local spentRebirths = profile.Rebirths
			local spentCores = profile.Cores
			local overflowRebirths = math.max(0, spentRebirths - requiredRebirths)
			local overflowCores = math.max(0, spentCores - requiredCores)
			local overflowRebirthScale = tonumber(expansion.OverflowRebirthScale) or 18
			local overflowCoreScale = tonumber(expansion.OverflowCoreSqrtScale) or 6
			local overflowReward = math.floor(overflowRebirths * overflowRebirthScale + math.sqrt(overflowCores) * overflowCoreScale)
			local nextRank = rank + 1
			profile.Domain.Rank = nextRank
			profile.Domain.Nodes = type(profile.Domain.Nodes) == "table" and profile.Domain.Nodes or {}
			profile.Domain.SkillPoints = math.max(0, math.floor(tonumber(profile.Domain.SkillPoints) or 0)) + (GameConfig.Domain.SkillPointPerRank or 2)
			essenceReward += Economy.DomainTreeBonus(profile, "EssenceGain")
			profile.Domain.Essence = math.max(0, math.floor(tonumber(profile.Domain.Essence) or 0)) + essenceReward
			profile.Domain.LastExpandedAt = os.time()
			profile.Domain.TotalRebirthsSpent = math.max(0, math.floor(tonumber(profile.Domain.TotalRebirthsSpent) or 0)) + spentRebirths
			profile.Domain.TotalCoresSpent = math.max(0, math.floor(tonumber(profile.Domain.TotalCoresSpent) or 0)) + spentCores

			ForgeEchoService.Record(profile, "Explore", 14)

			profile.Cash = GameConfig.Economy.StartingCash
			profile.Vault = 0
			profile.Cores = 0
			profile.Rebirths = 0
			profile.RunCash = 0
			profile.Zone = 1
			profile.CurrentZone = 1
			profile.Machines = { StellarCore = 1 }
			if profile.AutoForge then
				profile.AutoForge.Enabled = false
				profile.AutoForge.MachineId = "StellarCore"
			end
			if profile.Items and profile.Items.Equipped then
				for target in profile.Items.Equipped do
					local slot = string.match(target, "^(%a+):")
					if slot == "Machine" then
						profile.Items.Equipped[target] = nil
					end
				end
			end
			if profile.Lab then
				profile.Lab.Routing = { Production = GameConfig.Lab.Power.BaseCells, Storage = 0, Tap = 0 }
			end

			stardustReward = stardustReward + overflowReward
			profile.Stardust += stardustReward
			local freeSpins = math.max(0, math.floor(tonumber(expansion.FreeSpins) or 3))
			profile.Wheel.FreeSpins = (profile.Wheel.FreeSpins or 0) + freeSpins
			local bonusBoostId = expansion.BonusBoostId or GameConfig.Domain.SurgeBoostId
			local bonusBoostCount = math.max(1, math.floor(tonumber(expansion.BonusBoostCount) or 1))
			if GameConfig.Boosts[bonusBoostId] then
				profile.BoostInventory[bonusBoostId] = (profile.BoostInventory[bonusBoostId] or 0) + bonusBoostCount
			end
			profile.BoostInventory.Hyperdrive = (profile.BoostInventory.Hyperdrive or 0) + 2
			profile.BoostInventory.Overdrive = (profile.BoostInventory.Overdrive or 0) + 3
			profile.BoostInventory.VaultSurge = (profile.BoostInventory.VaultSurge or 0) + 2
			local surge = GameConfig.Boosts[GameConfig.Domain.SurgeBoostId]
			profile.ActiveBoost = { Id = surge.Id, EndsAt = os.time() + surge.Duration }

			details = {
				DomainRank = nextRank,
				DomainEssence = essenceReward,
				StardustReward = stardustReward,
				OverflowReward = overflowReward,
				ConsumedRebirths = spentRebirths,
				ConsumedCores = spentCores,
				BoostEndsAt = profile.ActiveBoost.EndsAt,
				FreeSpins = freeSpins,
				BonusBoost = bonusBoostId,
			}
			local nextRequiredRebirths, nextRequiredCores = Economy.DomainRequirements(nextRank)
			details.NextRequiredRebirths = nextRequiredRebirths
			details.NextRequiredCores = nextRequiredCores
			return responseSuccess(
				string.format("Domain %d established. Reality now yields more power.", nextRank),
				details
			)
		end)
		if result.ok then
			local profile = self._data:Get(player)
			self._world:RefreshPlot(player, profile)
			self._effect:FireAllClients({
				Type = "DomainExpansion",
				UserId = player.UserId,
				Rank = details and details.DomainRank or 0,
				Position = self._world:GetPlotPosition(player),
			})
		end
		return result
	end

	function GameService:_verifyCreatorFollow(player: Player)
		-- Roblox exposes no trusted follow check here; only the explicit Studio QA bypass may award it.
		if not RunService:IsStudio() or ServerConfig.AllowStudioFollowVerification ~= true then
			ModuleLog.Every(
				string.format("creator-follow-unverified:%d", player.UserId),
				30,
				"Security",
				string.format("u=%d Creator follow claim denied because verification is unavailable", player.UserId)
			)
			return responseError("Creator follow verification is unavailable.")
		end
		local profile = self._data:Get(player)
		if not profile then return responseError("Your save is still loading. Try again in a moment.") end
		local socialRewards = type(profile.SocialRewards) == "table" and profile.SocialRewards or nil
		if socialRewards and socialRewards.CreatorFollowClaimed == true then
			return responseSuccess("You already claimed this reward.")
		end
		local result = self:_mutate(player, function(current)
			current.SocialRewards = current.SocialRewards or { CreatorFollowClaimed = false }
			if current.SocialRewards.CreatorFollowClaimed == true then
				return responseSuccess("You already claimed this reward.")
			end
			current.SocialRewards.CreatorFollowClaimed = true
			local rewardText = ProgressionService.ApplyReward(current, ServerConfig.FollowReward, Economy.Production(current))
			return responseSuccess(rewardText)
		end)
		if result.ok then self._effect:FireClient(player, { Type = "FeatureUnlocked" }) end
		return result
	end

	function GameService:_setMobileLayout(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.Values) ~= "table" then
			return responseError("Invalid mobile layout.")
		end
		local allowed = {
			MobileQuickX = true,
			MobileQuickY = true,
			MobileDockX = true,
			MobileDockY = true,
			MobileToastX = true,
			MobileToastY = true,
		}
		return self:_mutate(player, function(profile)
			for key, value in payload.Values do
				if allowed[key] and type(value) == "number" then
					profile.Settings[key] = math.clamp(value, 0, 1)
				end
			end
			if payload.Slots ~= nil then
				local normalized = MobileLayoutSlots.Normalize(payload.Slots)
				if normalized == nil then
					return responseError("Invalid layout memory.")
				end
				profile.Flags.MobileLayoutSlots = normalized
				return responseSuccess("Layout memory saved.")
			end
			return responseSuccess("Mobile HUD layout saved.")
		end)
	end

	function GameService:_completeTutorial(player: Player)
		return self:_mutate(player, function(profile)
			if profile.Flags.TutorialDone then
				return responseSuccess("Tutorial already complete.")
			end
			profile.Flags.TutorialDone = true
			profile.Flags.TutorialStep = 15
			if profile.Flags.TutorialRewardClaimed then
				return responseSuccess("Guide done. 250 flux is yours.")
			end
			profile.Flags.TutorialRewardClaimed = true
			local reward = GameConfig.Economy.TutorialReward
			profile.Cash = Economy.Add(profile.Cash, reward)
			profile.RunCash = Economy.Add(profile.RunCash, reward)
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, reward)
			return responseSuccess("Tutorial done. +" .. Format.Number(reward) .. " flux!")
		end)
	end

	function GameService:_setTutorialStep(player: Player, rawStep: any)
		if type(rawStep) ~= "number" then
			return responseError("Invalid tutorial step.")
		end
		local step = math.clamp(math.floor(rawStep), 1, 15)
		return self:_mutate(player, function(profile)
			if profile.Flags.TutorialDone then
				return responseSuccess("Guide progress already complete.")
			end
			profile.Flags.TutorialStep = step
			return responseSuccess("Guide progress saved.")
		end)
	end

	function GameService:_replayTutorial(player: Player)
		return self:_mutate(player, function(profile)
			profile.Flags.TutorialDone = false
			profile.Flags.TutorialStep = 1
			return responseSuccess("Guide reopened.")
		end)
	end

	function GameService:_dismissRelease(player: Player)
		return self:_mutate(player, function(profile)
			profile.Flags.LastSeenVersion = GameConfig.Game.Version
			return responseSuccess()
		end)
	end

	function GameService:_openRelease(player: Player)
		return self:_mutate(player, function(profile)
			profile.Flags.LastSeenVersion = ""
			return responseSuccess()
		end)
	end

	function GameService:_claimLabOrder(player: Player, orderId: any)
		if type(orderId) ~= "string" then
			return responseError("Invalid order request.")
		end
		local result = self:_mutate(player, function(profile)
			LabService.Ensure(profile, player.UserId)
			local ok, message, reward = LabService.ClaimOrder(profile, orderId)
			if not ok then
				return responseError(message)
			end
			local rewardText = ProgressionService.ApplyReward(profile, reward, Economy.Production(profile))
			return responseSuccess(message .. " " .. rewardText)
		end)
		if result.ok then
			self._effect:FireClient(player, { Type = "LabOrder", OrderId = orderId })
		end
		return result
	end

	function GameService:_routeLabPower(player: Player, channelId: any, rawDelta: any)
		if type(channelId) ~= "string" or type(rawDelta) ~= "number" then
			return responseError("Invalid power routing request.")
		end
		local delta = math.floor(rawDelta)
		return self:_mutate(player, function(profile)
			local ok, message = LabService.RoutePower(profile, channelId, delta)
			return ok and responseSuccess(message) or responseError(message)
		end)
	end

	function GameService:_readStoryChapter(player: Player, chapterId: any)
		if type(chapterId) ~= "string" or not storyById[chapterId] then
			return responseError("That story chapter could not be found.")
		end
		return self:_mutate(player, function(profile)
			local chapter = storyById[chapterId]
			if ProgressionGate.Progress(profile, chapter.Kind) < chapter.Target then
				return responseError("Keep progressing to uncover this chapter.")
			end
			profile.Story.Read[chapterId] = true
			return responseSuccess("Chapter added to your archive.")
		end)
	end

	function GameService:_claimStoryChapter(player: Player, chapterId: any)
		if type(chapterId) ~= "string" or not storyById[chapterId] then
			return responseError("That story chapter could not be found.")
		end
		local result = self:_mutate(player, function(profile)
			local chapter = storyById[chapterId]
			if ProgressionGate.Progress(profile, chapter.Kind) < chapter.Target then
				return responseError("Keep progressing to uncover this chapter.")
			end
			if not profile.Story.Read[chapterId] then
				return responseError("Read the chapter before collecting its keepsake.")
			end
			if profile.Story.Claimed[chapterId] then
				return responseError("That keepsake is already in your collection.")
			end
			profile.Story.Claimed[chapterId] = true
			local reward = ProgressionService.ApplyReward(profile, chapter.Reward, Economy.Production(profile))
			return responseSuccess("Story keepsake: " .. reward)
		end)
		if result.ok then
			self._effect:FireClient(player, { Type = "StoryClaimed", Id = chapterId })
		end
		return result
	end

	function GameService:_readMail(player: Player, messageId: any)
		if type(messageId) ~= "string" or not mailById[messageId] then
			return responseError("That letter could not be found.")
		end
		return self:_mutate(player, function(profile)
			local message = mailById[messageId]
			if profile.Mailbox.Deleted[messageId] or not ProgressionGate.Meets(profile, message.Requirement) then
				return responseError("That letter is not available yet.")
			end
			profile.Mailbox.Read[messageId] = true
			return responseSuccess(nil)
		end)
	end

	function GameService:_claimMail(player: Player, messageId: any)
		if type(messageId) ~= "string" or not mailById[messageId] then
			return responseError("That letter could not be found.")
		end
		local result = self:_mutate(player, function(profile)
			local message = mailById[messageId]
			if profile.Mailbox.Deleted[messageId] or not ProgressionGate.Meets(profile, message.Requirement) then
				return responseError("That letter is not available yet.")
			end
			if profile.Mailbox.Claimed[messageId] then
				return responseError("You already collected this attachment.")
			end
			profile.Mailbox.Read[messageId] = true
			profile.Mailbox.Claimed[messageId] = true
			local reward =
				ProgressionService.ApplyReward(profile, message.Attachment, Economy.Production(profile))
			return responseSuccess("Mail attachment: " .. reward)
		end)
		if result.ok then
			self._effect:FireClient(player, { Type = "MailClaimed", Id = messageId })
		end
		return result
	end

	function GameService:_claimAllMail(player: Player)
		local claimedCount = 0
		local result = self:_mutate(player, function(profile)
			for _, message in GameConfig.Mail do
				local messageId = message.Id
				if
					message.Attachment
					and not profile.Mailbox.Deleted[messageId]
					and not profile.Mailbox.Claimed[messageId]
					and ProgressionGate.Meets(profile, message.Requirement)
				then
					profile.Mailbox.Read[messageId] = true
					profile.Mailbox.Claimed[messageId] = true
					ProgressionService.ApplyReward(profile, message.Attachment, Economy.Production(profile))
					claimedCount += 1
				end
			end
			if claimedCount == 0 then
				return responseError("There are no attachments ready to collect.")
			end
			local suffix = if claimedCount == 1 then "" else "s"
			return responseSuccess(string.format("Collected %d mail attachment%s.", claimedCount, suffix))
		end)
		if result.ok then
			self._effect:FireClient(player, { Type = "MailClaimed", Id = "*", Count = claimedCount })
		end
		return result
	end

	function GameService:_deleteMail(player: Player, messageId: any)
		if type(messageId) ~= "string" or not mailById[messageId] then
			return responseError("That letter could not be found.")
		end
		return self:_mutate(player, function(profile)
			local message = mailById[messageId]
			if message.Attachment and not profile.Mailbox.Claimed[messageId] then
				return responseError("Collect the attachment before archiving this letter.")
			end
			profile.Mailbox.Read[messageId] = true
			profile.Mailbox.Deleted[messageId] = true
			return responseSuccess("Letter archived.")
		end)
	end

	local GUILD_ACTIVITY_MILESTONE_STEP = 250_000

	function GameService:_toastGuild(guildId: string, title: string, body: string, tone: string?, skip: Player?)
		if type(guildId) ~= "string" or guildId == "" then return end
		for _, online in Players:GetPlayers() do
			if online ~= skip then
				local profile = self._data:Get(online)
				if profile and profile.Guild and profile.Guild.Id == guildId then
					self:_toastPlayer(online, title, body, tone)
				end
			end
		end
	end

	function GameService:_announceGuildActivity(guildId: string, previousActivity: number, guild)
		if type(guild) ~= "table" then return end
		local current = math.max(0, math.floor(tonumber(guild.Activity) or 0))
		local previous = math.max(0, math.floor(tonumber(previousActivity) or 0))
		if current <= previous then return end
		local reached = math.floor(current / GUILD_ACTIVITY_MILESTONE_STEP)
		local before = math.floor(previous / GUILD_ACTIVITY_MILESTONE_STEP)
		if reached <= before then return end
		local milestone = reached * GUILD_ACTIVITY_MILESTONE_STEP
		self:_toastGuild(
			guildId,
			"Guild milestone",
			string.format("%s passed %s Activity!", guild.Name or "Your guild", Format.Number(milestone)),
			"Special"
		)
	end

	function GameService:_guildAction(player: Player, action: string, payload: any)
		if action == Protocol.Actions.SendGuildChat
			or action == Protocol.Actions.GetGuildChatHistory
			or action == Protocol.Actions.GetGuildAnnouncements
			or action == Protocol.Actions.GetGuildSettings
			or action == Protocol.Actions.GetGuildLogoReview
			or action == Protocol.Actions.SetGuildSettings
			or action == Protocol.Actions.CreateGuildAnnouncement
			or action == Protocol.Actions.EditGuildAnnouncement
			or action == Protocol.Actions.PinGuildAnnouncement
			or action == Protocol.Actions.ArchiveGuildAnnouncement
			or action == Protocol.Actions.SetGuildAnnouncementExpiry
			or action == Protocol.Actions.MuteGuildMember
			or action == Protocol.Actions.UnmuteGuildMember
			or action == Protocol.Actions.BanGuildMember
			or action == Protocol.Actions.UnbanGuildMember
			or action == Protocol.Actions.UploadGuildLogo
			or action == Protocol.Actions.ModerateGuildLogo
		then
			return self._guildCommunity:Handle(player, action, payload)
		end

		if action == Protocol.Actions.KickGuildMember or action == Protocol.Actions.SetGuildRole or action == Protocol.Actions.BuyGuildUpgrade then
			local profile = self._data:Get(player)
			if not profile then return responseError("Your profile is not ready. Please try again.") end
			local ok, message, guild
			local previousActivity = 0
			if action == Protocol.Actions.BuyGuildUpgrade then
				local before = self._guilds:GetCachedPublic(profile.Guild and profile.Guild.Id or "")
				previousActivity = before and tonumber(before.Activity) or 0
			end
			if action == Protocol.Actions.KickGuildMember then
				ok, message, guild = self._guilds:Kick(player, profile, payload.UserId or payload.Id)
			if ok then
				local target = Players:GetPlayerByUserId(tonumber(payload.UserId or payload.Id) or 0)
				if target then
					self._data:AtomicUpdate(target, function(victimProfile)
						victimProfile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
						victimProfile.GuildBonuses = emptyBonuses()
						return { ok = true }
					end, true, "guild-kick")
					self:_pushState(target)
				end
			end
			elseif action == Protocol.Actions.SetGuildRole then
				ok, message, guild = self._guilds:SetRole(player, profile, payload.UserId or payload.Id, payload.Role)
			else
				ok, message, guild = self._guilds:BuyUpgrade(player, profile, payload.Id)
			end
			if not ok then return responseError(message) end
			if action == Protocol.Actions.BuyGuildUpgrade then
				local expectedGuildId = profile.Guild and profile.Guild.Id or ""
				local bonuses = self._guilds:GetCachedBonuses(expectedGuildId)
				self._data:AtomicUpdate(player, function(current)
					if not current.Guild or current.Guild.Id ~= expectedGuildId then
						return { ok = false, noop = true }
					end
					current.GuildBonuses = copyDictionary(bonuses)
					return { ok = true }
				end, true, "guild-bonus")
				local definition = GameConfig.Guild.Upgrades[payload.Id]
				local upgradeName = definition and definition.Name or "a hall upgrade"
				local level = guild and type(guild.Upgrades) == "table" and tonumber(guild.Upgrades[payload.Id]) or nil
				self:_toastGuild(
					expectedGuildId,
					"Guild upgrade",
					level
						and string.format("Your guild unlocked %s (level %d)!", upgradeName, level)
						or string.format("Your guild unlocked %s!", upgradeName),
					"Special"
				)
				self:_announceGuildActivity(expectedGuildId, previousActivity, guild)
			end
			return responseSuccess(message, { Guild = guild })
		end
		if action == Protocol.Actions.CreateGuild or action == Protocol.Actions.RenameGuild then
			local rawName = type(payload.Name) == "string" and payload.Name or ""
			local filteredOk, filtered = self._security.Filter:Apply(player, rawName, player.UserId, 28)
			if not filteredOk or type(filtered) ~= "string" or #filtered < 3 then
				return responseError("That guild name couldn't be checked. Please try different wording.")
			end
			payload = table.clone(payload)
			payload.Name = filtered
		end
		local contributeActivity = 0
		local contributeGuildId = ""
		if action == Protocol.Actions.ContributeGuild then
			local existing = self._data:Get(player)
			contributeGuildId = existing and existing.Guild and existing.Guild.Id or ""
			local before = self._guilds:GetCachedPublic(contributeGuildId)
			contributeActivity = before and tonumber(before.Activity) or 0
		end
		local renameGuildId = ""
		if action == Protocol.Actions.RenameGuild then
			local existing = self._data:Get(player)
			renameGuildId = existing and existing.Guild and existing.Guild.Id or ""
		end
		if action == Protocol.Actions.JoinGuild then
			local canJoin, joinError = self._guildCommunity:CanJoinByTag(payload.Tag, player.UserId)
			if not canJoin then return responseError(joinError or "You cannot join that guild.") end
		end
		local result = self:_mutate(player, function(profile)
			local ok, message, guild
			if action == Protocol.Actions.CreateGuild then
				ok, message, guild = self._guilds:Create(player, profile, payload.Name, payload.Tag)
			elseif action == Protocol.Actions.JoinGuild then
				ok, message, guild = self._guilds:JoinByTag(player, profile, payload.Tag)
			elseif action == Protocol.Actions.LeaveGuild then
				ok, message, guild = self._guilds:Leave(player, profile)
			elseif action == Protocol.Actions.DisbandGuild then
				ok, message, guild = self._guilds:Disband(player, profile)
			elseif action == Protocol.Actions.RenameGuild then
				ok, message, guild = self._guilds:Rename(player, profile, payload.Name, payload.Tag)
			elseif action == Protocol.Actions.ContributeGuild then
				local balanceField = payload.Currency == "Cash" and "Cash" or "Stardust"
				local amount = payload.Amount
				if type(payload.Fraction) == "number" then

					amount = math.max(1, math.floor((profile[balanceField] or 0) * payload.Fraction))
				end
				ok, message, guild = self._guilds:ContributeBank(player, profile, math.floor(amount), payload.Currency)
			elseif action == Protocol.Actions.ClaimGuildGoal then
				local reward
				ok, message, guild, reward = self._guilds:ClaimGoal(player, profile)
				if ok and reward then
					local rewardText = ProgressionService.ApplyReward(profile, reward, Economy.Production(profile))
					if rewardText ~= "" then
						message = "Guild goal complete! " .. rewardText
					end
				end
			end
			if ok then

				profile.GuildBonuses = self._guilds:GetCachedBonuses(profile.Guild.Id)
				return responseSuccess(message, { Guild = guild })
			end
			return responseError(message)
		end)
		if result.ok and action == Protocol.Actions.ContributeGuild and contributeGuildId ~= "" then
			self:_announceGuildActivity(contributeGuildId, contributeActivity, result.Guild)
		end
		if result.ok and action == Protocol.Actions.RenameGuild and renameGuildId ~= "" and result.Guild then
			local guild = result.Guild
			local oldTag = guild.AuditLog and type(guild.AuditLog[1]) == "table" and guild.AuditLog[1].FromTag or nil
			local newTag = guild.AuditLog and type(guild.AuditLog[1]) == "table" and guild.AuditLog[1].ToTag or nil
			local tagText = oldTag and newTag and oldTag ~= newTag and string.format(" Tag changed from %s to %s.", oldTag, newTag) or ""
			self:_toastGuild(
				renameGuildId,
				"Guild renamed",
				string.format("%s renamed the guild to %s.%s", player.DisplayName, guild.Name or "", tagText),
				"Special",
				player
			)
			for _, online in Players:GetPlayers() do
				if online ~= player then
					local onlineProfile = self._data:Get(online)
					if onlineProfile and onlineProfile.Guild and onlineProfile.Guild.Id == renameGuildId then
						self:_pushState(online)
					end
				end
			end
		end
		return result
	end

	function GameService:_resolvePlayerName(userId: number): string
		local now = os.clock()
		if now >= self._nameCachePruneAt then
			self._nameCachePruneAt = now + 300
			for cachedUserId, entry in self._playerNameCache do
				if type(entry) ~= "table" or tonumber(entry.ExpiresAt) == nil or entry.ExpiresAt <= now then
					self._playerNameCache[cachedUserId] = nil
				end
			end
		end
		local online = Players:GetPlayerByUserId(userId)
		if online then
			local label = online.DisplayName ~= "" and online.DisplayName or online.Name
			self._playerNameCache[userId] = { Name = label, ExpiresAt = os.clock() + 300 }
			return label
		end
		local cached = self._playerNameCache[userId]
		if cached and cached.ExpiresAt > now then
			return cached.Name
		end

		if not self._nameLookupPending[userId] then
			self._nameLookupPending[userId] = true
			self:_spawnWorker(function()
				local ok, name = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if ok and type(name) == "string" and name ~= "" then
					self._playerNameCache[userId] = { Name = name, ExpiresAt = os.clock() + 900 }
					table.clear(self._globalBoardCache)
				end
				self._nameLookupPending[userId] = nil
			end)
		end
		return "Pilot " .. tostring(userId)
	end

	function GameService:_primePlayerNames(rows)
		local now = os.clock()
		local missing = {}
		for _, row in rows do
			local userId = tonumber(row.UserId)
			if userId then
				local online = Players:GetPlayerByUserId(userId)
				if online then
					self._playerNameCache[userId] = { Name = online.Name, ExpiresAt = now + 300 }
				else
					local cached = self._playerNameCache[userId]
					if not cached or cached.ExpiresAt <= now then
						table.insert(missing, userId)
					end
				end
			end
		end
		if #missing == 0 then return end
		local ok, infos = pcall(function()
			return Players:GetUserInfosByUserIdsAsync(missing)
		end)
		if not ok or type(infos) ~= "table" then return end
		for _, info in infos do
			local userId = tonumber(info.Id)
			local username = info.Username
			if userId and type(username) == "string" and username ~= "" then
				self._playerNameCache[userId] = { Name = username, ExpiresAt = os.clock() + 900 }
			end
		end
	end

	local RANK_PING_BOARD = "Flux"
	local RANK_PING_BOARD_LABEL = "Lifetime Flux"
	local RANK_PING_BRACKETS = RankBracket.DEFAULT_BRACKETS
	local RANK_PING_UNRANKED = RankBracket.UNRANKED

	function GameService:_announceRankClimbs(id: string, rows)
		if id ~= RANK_PING_BOARD then return end
		local rankByUser = {}
		for index, row in rows do
			rankByUser[row.UserId] = index
		end
		for _, online in Players:GetPlayers() do
			local runtime = self._runtime[online]
			local rank = rankByUser[online.UserId]
			if runtime and rank then
				local previous = math.max(0, math.floor(tonumber(runtime.LeaderboardRank) or 0))
				runtime.LeaderboardRank = rank
				if RankBracket.ShouldAnnounce(previous, rank, RANK_PING_BRACKETS, RANK_PING_UNRANKED) then
					self:_toastPlayer(
						online,
						"Leaderboard climb",
						string.format("You climbed to #%d in %s!", rank, RANK_PING_BOARD_LABEL),
						"Special"
					)
				end
			elseif runtime then
				runtime.LeaderboardRank = 0
			end
		end
	end

	function GameService:_getLeaderboard(id: any)
		if type(id) ~= "string" then
			return responseError("That leaderboard is unavailable.")
		end
		local store = self._leaderboardStores[id]
		if not store then
			return responseError("That leaderboard is unavailable.")
		end
		local cached = self._globalBoardCache[id]
		if cached and cached.ExpiresAt > os.clock() then
			return responseSuccess(nil, { Leaderboard = cached.Entries, LeaderboardId = id })
		end

		local byUser = {}
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, GLOBAL_LB_PAGE)
		end)
		if ok and pages then
			for _, row in pages:GetCurrentPage() do
				local userId = tonumber(row.key)
				local value = LeaderboardCodec.Decode(row.value)
				if userId then byUser[userId] = value end
			end
		end

		for _, online in Players:GetPlayers() do
			local profile = self._data:Get(online)
			if profile then byUser[online.UserId] = generalBoardValue(profile, id) end
		end
		local rows = {}
		for userId, value in byUser do
			local counts = if id == "Worlds" then Economy.Gt(value, 1) else Economy.Gt(value, 0)
			if counts then
				table.insert(rows, { UserId = userId, Value = value })
			end
		end
		table.sort(rows, function(a, b)
			if Economy.Gt(a.Value, b.Value) then
				return true
			end
			if Economy.Lt(a.Value, b.Value) then
				return false
			end
			return a.UserId < b.UserId
		end)
		self:_primePlayerNames(rows)
		local entries = {}
		for index = 1, math.min(#rows, GLOBAL_LB_PAGE) do
			local row = rows[index]
			table.insert(entries, {
				UserId = row.UserId,
				Name = self:_resolvePlayerName(row.UserId),
				Value = row.Value,
				Category = id,
			})
		end
		self._globalBoardCache[id] = { Entries = entries, ExpiresAt = os.clock() + 15 }
		self:_announceRankClimbs(id, rows)
		return responseSuccess(nil, { Leaderboard = entries, LeaderboardId = id })
	end

	function GameService:_handleAction(player: Player, action: any, payload: any)
		if not CommandActionValidators.IsValidAction(action) then
			return responseError("Invalid request.")
		end
		if action == Protocol.Actions.ReportClientIntegrity then
			local accepted = RemoteFirewall.processFirewallViolation(
				player,
				payload and payload.ActionType,
				payload and payload.PenaltyCode
			)
			return accepted and responseSuccess(nil)
				or responseError("Integrity report rejected.")
		end
		if action == Protocol.Actions.ReportPerformance then
			return self._analytics:RecordPerformance(player, payload) and responseSuccess(nil)
				or responseError("Performance sample was already received.")
		end
		local featureId = featureByAction[action]
		if action == Protocol.Actions.BeginEncounter and payload and payload.Mode == "Trial" then
			featureId = "Trials"
		elseif action == Protocol.Actions.ChooseEncounter then
			local encounterProfile = self._data:Get(player)
			local active = encounterProfile and encounterProfile.Encounters and encounterProfile.Encounters.Active
			if active and active.Mode == "Trial" then featureId = "Trials" end
		end
		if featureId then
			local profile = self._data:Get(player)
			local domainOpen = featureId == "Domain" and profile and profile.Domain and (tonumber(profile.Domain.Rank) or 0) >= 1
			if profile and not domainOpen and not ProgressionGate.IsFeatureUnlocked(profile, featureId) then
				local rule = GameConfig.Unlocks[featureId]
				local name = rule and rule.Name or featureId
				if rule and rule.Kind == "Level" then
					local levelDef = GameConfig.Levels[rule.Target]
					return responseError(string.format(
						"%s opens at Level %d (%s). You're Level %d.",
						name,
						rule.Target,
						levelDef and levelDef.Tier or "",
						ProgressionGate.Level(profile)
					))
				end
				return responseError(
					name
						.. " unlocks when you "
						.. string.lower(rule and rule.Requirement or "progress further")
						.. "."
				)
			end
		end
		if action == Protocol.Actions.GetState then
			if self._runtime[player] then self._runtime[player].BazaarRecoveryRetryAt = nil end
			local snapshot = self:_snapshot(player)
			return snapshot and responseSuccess(nil, { State = snapshot })
				or responseError("Profile is still loading.")
		elseif action == Protocol.Actions.MeasureLatency then

			return responseSuccess(nil)
		elseif action == Protocol.Actions.SubmitFeedback then
			return self:_submitFeedback(player, payload)
		elseif action == Protocol.Actions.ReportPlayer then
			return self:_reportPlayer(player, payload)
		elseif action == Protocol.Actions.GetPlayers then
			return self:_getPlayers(player)
		elseif action == Protocol.Actions.GetPlayerMirror then
			return self:_getPlayerMirror(player, payload)
		elseif action == Protocol.Actions.VisitPlot then
			return self:_visitPlot(player, payload)
		elseif action == Protocol.Actions.LeavePlot then
			return self:_leavePlot(player)
		elseif action == Protocol.Actions.NudgeCrew then
			return self:_nudgeCrew(player, payload)
		elseif action == Protocol.Actions.ReportPresence then
			return self:_reportPresence(player, payload)
		elseif action == Protocol.Actions.GetGuild then
			local profile = self._data:Get(player)
			return responseSuccess(nil, { Guild = profile and self._guilds:GetPublic(profile.Guild and profile.Guild.Id or "") })
		elseif action == Protocol.Actions.GetGuildLeaderboard then
			return responseSuccess(nil, { GuildLeaderboard = self._guilds:GetLeaderboard(payload and payload.Page or 1) })
		elseif action == Protocol.Actions.GetLeaderboard then
			return self:_getLeaderboard(payload and payload.Id)
		elseif action == Protocol.Actions.GetAdminState then
			return self._admin and responseSuccess(nil, { Admin = self._admin:State(player) })
				or responseError("Administration is unavailable.")
		elseif action == Protocol.Actions.AdminExecute then
			if not self._admin then return responseError("Administration is unavailable.") end
			local result = self._admin:Execute(player, payload)
			if result.ok and type(result.TargetUserId) == "number" then
				local target = Players:GetPlayerByUserId(result.TargetUserId)
				local targetProfile = target and self._data:Get(target)
				if target and targetProfile then
					self:_syncLeaderstats(target, targetProfile)
					if target ~= player then
						self:_pushState(target)
						self:_toastPlayer(target, "Forgemaster grant", result.message or "Your profile was updated.", "Special")
					end
				end
			end
			return result
		elseif action == Protocol.Actions.CreateGuild
			or action == Protocol.Actions.JoinGuild
			or action == Protocol.Actions.LeaveGuild
			or action == Protocol.Actions.DisbandGuild
			or action == Protocol.Actions.KickGuildMember
			or action == Protocol.Actions.SetGuildRole
			or action == Protocol.Actions.RenameGuild
			or action == Protocol.Actions.ContributeGuild
			or action == Protocol.Actions.BuyGuildUpgrade
			or action == Protocol.Actions.ClaimGuildGoal
			or action == Protocol.Actions.SendGuildChat
			or action == Protocol.Actions.GetGuildChatHistory
			or action == Protocol.Actions.GetGuildAnnouncements
			or action == Protocol.Actions.GetGuildSettings
			or action == Protocol.Actions.SetGuildSettings
			or action == Protocol.Actions.GetGuildLogoReview
			or action == Protocol.Actions.CreateGuildAnnouncement
			or action == Protocol.Actions.EditGuildAnnouncement
			or action == Protocol.Actions.PinGuildAnnouncement
			or action == Protocol.Actions.ArchiveGuildAnnouncement
			or action == Protocol.Actions.SetGuildAnnouncementExpiry
			or action == Protocol.Actions.MuteGuildMember
			or action == Protocol.Actions.UnmuteGuildMember
			or action == Protocol.Actions.BanGuildMember
			or action == Protocol.Actions.UnbanGuildMember
			or action == Protocol.Actions.UploadGuildLogo
			or action == Protocol.Actions.ModerateGuildLogo
		then
			return self:_guildAction(player, action, payload or {})
		elseif action == Protocol.Actions.GetTrade
			or action == Protocol.Actions.InviteTrade
			or action == Protocol.Actions.RespondTrade
			or action == Protocol.Actions.UpdateTradeOffer
			or action == Protocol.Actions.SetTradeReady
			or action == Protocol.Actions.ConfirmTrade
			or action == Protocol.Actions.CancelTrade
			or action == Protocol.Actions.TradeViewAway
		then
			return self:_tradeAction(player, action, payload or {})
		elseif action == Protocol.Actions.CollectVault then
			return self:_collect(player)
		elseif action == Protocol.Actions.Overcharge then
			return self:_overcharge(player)
		elseif action == Protocol.Actions.BuyMachine then
			return self:_buyMachine(player, payload and payload.Id, payload and payload.Amount)
		elseif action == Protocol.Actions.SetAutoForge then
			return self:_setAutoForge(player, payload)
		elseif action == Protocol.Actions.BuyResearch then
			return self:_buyResearch(player, payload and payload.Id, payload and payload.Amount)
		elseif action == Protocol.Actions.BuyGridUpgrade then
			return responseError("Star Grid purchases have retired. Your purchased bonuses remain active; choose a build in Forge Specializations.")
		elseif action == Protocol.Actions.UpgradeContinuum then
			return self:_upgradeContinuum(player)
		elseif action == Protocol.Actions.CaptureEcho then
			return self:_captureEcho(player)
		elseif action == Protocol.Actions.ClaimEcho then
			return self:_claimEcho(player, payload and payload.ChoiceId)
		elseif action == Protocol.Actions.EquipEcho then
			return self:_equipEcho(player, payload and payload.Uid, payload and payload.Slot)
		elseif action == Protocol.Actions.UpgradeEcho then
			return self:_upgradeEcho(player, payload and payload.Uid)
		elseif action == Protocol.Actions.DismantleEcho then
			return self:_dismantleEcho(player, payload and payload.Uid)
		elseif action == Protocol.Actions.UnlockZone then
			return self:_unlockZone(player, payload and payload.Id)
		elseif action == Protocol.Actions.SelectZone then
			return self:_selectZone(player, payload and payload.Id)
		elseif action == Protocol.Actions.Rebirth then
			return self:_rebirth(player)
		elseif action == Protocol.Actions.DomainExpansion then
			return self:_domainExpansion(player)
		elseif action == Protocol.Actions.UnlockDomainNode then
			return self:_unlockDomainNode(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimConvergenceReward then
			return self._convergence:Claim(player, payload and payload.Tier)
		elseif action == Protocol.Actions.ClaimQuest then
			return self:_claimQuest(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimAchievement then
			return self:_claimAchievement(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimDaily then
			return self:_claimDaily(player)
		elseif action == Protocol.Actions.ClaimTimedReward then
			return self:_claimTimedReward(player, payload and payload.Index)
		elseif action == Protocol.Actions.SpinWheel then
			return self:_spinWheel(player, payload)
		elseif action == Protocol.Actions.BazaarPlay then
			return self:_bazaarPlay(player, payload)
		elseif action == Protocol.Actions.SelectSpecialization then
			return self:_mutate(player, function(profile)
				local selected, message = Specializations.Select(profile.Specialization, payload and payload.Id, os.time())
				if not selected then return responseError(message) end
				local previous = profile.Specialization
				if selected.Focus == Specializations.Sanitize(previous).Focus then return responseSuccess(message) end
				profile.Specialization = selected
				if Economy.Gt(profile.Vault, Economy.Capacity(profile)) then
					profile.Specialization = previous
					return responseError("Collect your vault before equipping a build with a smaller capacity.")
				end
				return responseSuccess(message)
			end)
		elseif action == Protocol.Actions.BeginEncounter or action == Protocol.Actions.ChooseEncounter then
			return self:_mutate(player, function(profile)
				local ok, message
				if action == Protocol.Actions.BeginEncounter then
					ok, message = EncounterService.Begin(profile, payload, os.time())
				else
					ok, message = EncounterService.Choose(profile, payload)
				end
				return ok and responseSuccess(message) or responseError(message)
			end)
		elseif action == Protocol.Actions.SetMarketFavorite then
			return self:_mutate(player, function(profile)
				local ok, message = BazaarService.SetFavorite(profile, payload)
				return ok and responseSuccess(message) or responseError(message)
			end)
		elseif action == Protocol.Actions.RequestProcurement then
			return self:_mutate(player, function(profile)
				local ok, message = BazaarService.Procure(profile, payload, os.time())
				return ok and responseSuccess(message) or responseError(message)
			end)
		elseif action == Protocol.Actions.LaunchExpedition then
			return self:_launchExpedition(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimExpedition then
			return self:_claimExpedition(player)
		elseif action == Protocol.Actions.EquipArtifact then
			return self:_equipArtifact(player, payload and payload.Id)
		elseif action == Protocol.Actions.UpgradeArtifact then
			return self:_upgradeArtifact(player, payload and payload.Id)
		elseif action == Protocol.Actions.BuyArtifact then
			return self:_buyArtifact(player, payload and payload.Id)
		elseif action == Protocol.Actions.UpgradeCrew then
			return self:_upgradeCrew(player, payload and payload.Role)
		elseif action == Protocol.Actions.ClaimCommanderReward then
			return self:_claimCommanderReward(player, payload and payload.Level)
		elseif action == Protocol.Actions.ClaimWeeklyDirective then
			return self:_claimWeeklyDirective(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimSeasonTier then
			return self:_claimSeasonTier(player, payload and payload.Tier)
		elseif action == Protocol.Actions.ClaimForgePathStep then
			return self:_claimForgePathStep(player, payload and payload.Step)
		elseif action == Protocol.Actions.BuySignalOffer then
			return self:_buySignalOffer(player, payload and payload.Id)
		elseif action == Protocol.Actions.EquipTitle then
			return self:_equipTitle(player, payload and payload.Id)
		elseif action == Protocol.Actions.RedeemCode then
			return self:_redeemCode(player, payload and payload.Code)
		elseif action == Protocol.Actions.VerifyCreatorFollow then
			return self:_verifyCreatorFollow(player)
		elseif action == Protocol.Actions.SyncShop then
			return self:_syncShop(player)
		elseif action == Protocol.Actions.StudioGrantProduct then
			return self:_studioGrantProduct(player, payload and payload.Id)
		elseif action == Protocol.Actions.ActivateBoost then
			return self:_activateBoost(player, payload and payload.Id)
		elseif action == Protocol.Actions.BuyDailyOffer then
			return self:_buyDailyOffer(player, payload and payload.Slot)
		elseif action == Protocol.Actions.BuyCrateSkin then
			return self:_buyCrateSkin(player, payload and payload.Id)
		elseif action == Protocol.Actions.EquipCrateSkin then
			return self:_equipCrateSkin(player, payload and payload.Id)
		elseif action == Protocol.Actions.FuseRelics then
			return self:_fuseRelics(player, payload and payload.Id)
		elseif action == Protocol.Actions.BuyItemOffer then
			return self:_buyItemOffer(player, payload and payload.Id)
		elseif action == Protocol.Actions.OpenItemCrate then
			return self:_openItemCrate(player, payload and payload.Id, payload and payload.Count)
		elseif action == Protocol.Actions.EquipItem then
			return self:_equipItem(player, payload and payload.Uid, payload and payload.Target)
		elseif action == Protocol.Actions.UnequipItem then
			return self:_unequipItem(player, payload and payload.Target)
		elseif action == Protocol.Actions.UpgradeItem then
			return self:_upgradeItem(player, payload and payload.Uid)
		elseif action == Protocol.Actions.SalvageItem then
			return self:_salvageItem(player, payload and payload.Uid)
		elseif action == Protocol.Actions.BulkSalvageItems then
			return self:_bulkSalvageItems(player, payload and payload.Uids)
		elseif action == Protocol.Actions.EquipBestItems then
			return self:_equipBestItems(player)
		elseif action == Protocol.Actions.ToggleItemLock then
			return self:_toggleItemLock(player, payload and payload.Uid)
		elseif action == Protocol.Actions.SetItemAutoSalvage then
			return self:_setItemAutoSalvage(player, payload)
		elseif action == Protocol.Actions.SetSetting then
			return self:_setSetting(player, payload)
		elseif action == Protocol.Actions.SetMobileLayout then
			return self:_setMobileLayout(player, payload)
		elseif action == Protocol.Actions.ChatOpenWhisper then
			return self._chat:OpenWhisper(player, payload)
		elseif action == Protocol.Actions.ChatGlobal then
			return self._chat:SendGlobal(player, payload)
		elseif action == Protocol.Actions.GetCrew then
			return self._crews:Get(player)
		elseif action == Protocol.Actions.CrewInvite then
			return self._crews:Invite(player, payload)
		elseif action == Protocol.Actions.CrewRespond then
			return self._crews:Respond(player, payload)
		elseif action == Protocol.Actions.CrewLeave then
			return self._crews:Leave(player)
		elseif action == Protocol.Actions.CrewKick then
			return self._crews:Kick(player, payload)
		elseif action == Protocol.Actions.CrewRename then
			return self._crews:Rename(player, payload)
		elseif action == Protocol.Actions.CrewClaim then
			return self._crews:Claim(player, payload)
		elseif action == Protocol.Actions.SetTutorialStep then
			return self:_setTutorialStep(player, payload and payload.Step)
		elseif action == Protocol.Actions.CompleteTutorial then
			return self:_completeTutorial(player)
		elseif action == Protocol.Actions.ReplayTutorial then
			return self:_replayTutorial(player)
		elseif action == Protocol.Actions.DismissRelease then
			return self:_dismissRelease(player)
		elseif action == Protocol.Actions.OpenRelease then
			return self:_openRelease(player)
		elseif action == Protocol.Actions.ReadStoryChapter then
			return self:_readStoryChapter(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimStoryChapter then
			return self:_claimStoryChapter(player, payload and payload.Id)
		elseif action == Protocol.Actions.ReadMail then
			return self:_readMail(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimMail then
			return self:_claimMail(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimAllMail then
			return self:_claimAllMail(player)
		elseif action == Protocol.Actions.DeleteMail then
			return self:_deleteMail(player, payload and payload.Id)
		elseif action == Protocol.Actions.PulseAnomaly then
			return self:_pulseAnomaly(player)
		elseif action == Protocol.Actions.StabilizeAnomaly then
			return self:_stabilizeAnomaly(player)
		elseif action == Protocol.Actions.BuyAnomalyProtocol then
			return self:_buyAnomalyProtocol(player, payload and payload.Id)
		elseif action == Protocol.Actions.ActivateAnomalySurge then
			return self:_activateAnomalySurge(player)
		elseif action == Protocol.Actions.SetAnomalyChannel then
			return self:_setAnomalyChannel(player, payload and payload.Id)
		elseif action == Protocol.Actions.SetAnomalyLoadout then
			return self:_setAnomalyLoadout(player, payload and payload.Loadout)
		elseif action == Protocol.Actions.ClaimAnomalyMilestone then
			return self:_claimAnomalyMilestone(player, payload and payload.Tier)
		elseif action == Protocol.Actions.ClaimAnomalyDirective then
			return self:_claimAnomalyDirective(player, payload and payload.Id)
		elseif action == Protocol.Actions.ClaimLabOrder then
			return self:_claimLabOrder(player, payload and payload.Id)
		elseif action == Protocol.Actions.RouteLabPower then
			return self:_routeLabPower(player, payload and payload.Channel, payload and payload.Delta)
		end
		return responseError("Unknown forge command.")
	end

	function GameService:_processOffline(player: Player, profile)
		local previousLastSeen = self._data:GetPreviousLastSeen(player)
		local now = os.time()
		local reward, elapsed, averageEfficiency, capped =
			Economy.OfflineEarnings(profile, previousLastSeen, now)
		local awaySeconds = math.max(elapsed, math.max(0, now - (tonumber(previousLastSeen) or now)))
		local capHours = Economy.OfflineHours(profile)
		if Economy.Gt(reward, 0) then
			profile.Cash = Economy.Add(profile.Cash, reward)
			profile.RunCash = Economy.Add(profile.RunCash, reward)
			profile.LifetimeCash = Economy.Add(profile.LifetimeCash, reward)
			local stats = ensureStats(profile)
			stats.Collected = Economy.Add(stats.Collected, reward)
			local rewardNumber = Economy.AsNumber(reward)
			ProgressionService.Progress(profile, "EarnCash", rewardNumber)
			LabService.Progress(profile, "BankFlux", rewardNumber)
		end
		return reward, elapsed, averageEfficiency, capped, awaySeconds, capHours
	end

	function GameService:_onPlayerAdded(player: Player, stealLock: boolean?)
		if self._admin and self._admin:EnforceServerBan(player) then
			return
		end
		local loaded, errorMessage = self._data:Load(player, stealLock)
		if not loaded then
			if errorMessage == "refreshing" or self:_refreshing() or player.Parent ~= Players then
				return
			end
			error(errorMessage or "profile load failed", 0)
		end
		if not self._running or player.Parent ~= Players then
			self._data:Save(player, true)
			return
		end

		local profile = self._data:Get(player)
		if not profile then
			self._data:Save(player, true)
			return
		end
		self._antiCheat:Observe(player, "Load", profile)
		local membershipBeforeReconcile = profile.Guild
		local membershipGuildId = membershipBeforeReconcile and membershipBeforeReconcile.Id or ""
		self._guilds:ReconcileMembership(profile, player.UserId)
		if membershipGuildId ~= "" and self._guildCommunity:IsBanned(membershipGuildId, player.UserId) then
			self._guilds:_update(membershipGuildId, function(current)
				current.Members[tostring(player.UserId)] = nil
				return current
			end)
			profile.Guild = { Id = "", Role = "", JoinedAt = 0, Tag = "" }
			profile.GuildBonuses = emptyBonuses()
		end
		if not self._running or player.Parent ~= Players then
			self._data:Save(player, true)
			return
		end

		applySocialBoost(profile, 0, player.MembershipType == Enum.MembershipType.Premium)
		local offlineReward, offlineSeconds, offlineEfficiency, offlineCapped, offlineAwaySeconds, offlineCapHours =
			self:_processOffline(player, profile)
		self._antiCheat:SyncBaseline(player, profile)
		ProgressionService.EnsureQuests(profile, player.UserId)
		ProgressionService.EnsureTimedRewards(profile)
		ProgressionService.EnsureCommandRotations(profile)
		ensureItemShop(profile)
		AnomalyService.Ensure(profile)
		LabService.Ensure(profile, player.UserId)
		bumpStat(profile, "Joins", 1)
		profile.Meta.Revision += 1
		self._data:MarkDirty(player)
		self._runtime[player] = {
			LastTap = 0,
			TapCombo = 0,
			LeaderboardRank = 0,
			ProductionAccumulator = 0,
			AutoForgeAccumulator = 0,
			PushAccumulator = 0,
			DirtyAccumulator = 0,
			MaintenanceAccumulator = 0,
			GuildRefreshAccumulator = 0,
			GuildRefreshBusy = false,
			PendingAnomalyActions = {},
			SnapshotId = 0,
			OfflineReward = offlineReward,
			OfflineSeconds = offlineSeconds,
			OfflineEfficiency = offlineEfficiency,
			OfflineCapped = offlineCapped,
			OfflineAwaySeconds = offlineAwaySeconds,
			OfflineCapHours = offlineCapHours,
		}
		if not self._running or player.Parent ~= Players then
			self._data:Save(player, true)
			self._runtime[player] = nil
			return
		end
		local spawned, spawnProblem = pcall(function()
			if self._matter then
				self._runtime[player].MatterEntity = self._matter:SpawnPlayer(player, self._runtime[player], profile)
			end
		end)
		if not spawned then
			if not self._running then
				self._data:Save(player, true)
				self._runtime[player] = nil
				return
			end
			error(spawnProblem, 0)
		end
		pcall(function()
			self._analytics:PlayerJoined(player, profile)
		end)
		pcall(function()
			self._badges:Evaluate(player, profile)
		end)

		self:_createLeaderstats(player)
		self:_syncLeaderstats(player, profile)
		local plotted, plotProblem = pcall(function()
			self._world:CreatePlot(player, profile)
		end)
		if not plotted then
			if not self._running then
				return
			end
			ModuleLog.Warn("Player", string.format("plot setup failed for %s - %s", player.Name, tostring(plotProblem)))
		end

		table.clear(self._globalBoardCache)
		player:SetAttribute("AstralForgeLoaded", true)

		local joinedRuntime = self._runtime[player]
		self:_spawnWorker(function()
			self:_syncShop(player)
			if self._running and player.Parent == Players and self._runtime[player] == joinedRuntime then
				self:_pushState(player)
			end
		end)

		local previousCharacterConnection = self._characterConnections[player]
		if previousCharacterConnection then previousCharacterConnection:Disconnect() end
		self._characterConnections[player] = player.CharacterAdded:Connect(function(character)
			task.defer(function()
				local animate = character:WaitForChild("Animate", 3)
				local mood = animate and animate:FindFirstChild("mood")
				if mood ~= nil then
					mood:Destroy()
				end
			end)
			self:_spawnWorker(function()
				task.wait(0.15)
				if self._running and player.Parent == Players and self._runtime[player] == joinedRuntime then
					self._world:TeleportToPlot(player)
				end
			end)
		end)
		if player.Character then
			self:_spawnWorker(function()
				if self._running and player.Parent == Players and self._runtime[player] == joinedRuntime then
					self._world:TeleportToPlot(player)
				end
			end)
		end

		self:_pushState(player)
		local away = if offlineSeconds >= 3600
			then string.format("%.0fh", offlineSeconds / 3600)
			elseif offlineSeconds >= 60 then string.format("%.0fm", offlineSeconds / 60)
			else string.format("%.0fs", offlineSeconds)
		ModuleLog.Player(player, string.format("joined world %d after %s away", profile.CurrentZone, away))
	end

	function GameService:_refreshing(): boolean
		if self._running ~= true then
			return true
		end
		local data = self._data
		if data == nil then
			return true
		end
		local ok, closing = pcall(function()
			return data:IsClosing()
		end)
		return ok and closing == true
	end

	function GameService:_safePlayerAdded(player: Player)

		if self:_refreshing() or self._joining[player] or self._runtime[player] then
			return
		end
		self._joining[player] = true
		local attempts = 0
		local joinStartedAt = os.clock()
		local lockNoticeAt = 0
		local lockSince = nil
		local stealNoticeAt = 0
		while player.Parent == Players and not self:_refreshing() do
			attempts += 1
			if self._runtime[player] then
				break
			end
			local stealLock = lockSince ~= nil and os.clock() - lockSince > 90
			local ok, problem = pcall(self._onPlayerAdded, self, player, stealLock)
			if self._runtime[player] then
				break
			end
			if self:_refreshing() or player.Parent ~= Players then
				break
			end
			if not ok then
				ModuleLog.Every(
					"join-retry:" .. tostring(player.UserId),
					8,
					"Player",
					string.format("%s join retry %d — %s", player.Name, attempts, tostring(problem))
				)
			end
			local locked = type(problem) == "string" and string.find(string.lower(tostring(problem)), "another server", 1, true) ~= nil
			if locked then
				if lockSince == nil then
					lockSince = os.clock()
				end
				if os.clock() - lockNoticeAt > 25 then
					lockNoticeAt = os.clock()
					self:_toastPlayer(
						player,
						"Save is still syncing",
						"Your data is still active on another server. Close any other open session, or wait and it clears on its own.",
						"Info"
					)
				end
				if stealLock and os.clock() - stealNoticeAt > 60 then
					stealNoticeAt = os.clock()
					ModuleLog.Warn("Player", string.format("%s save lock held %.0fs — stealing it", player.Name, os.clock() - lockSince), { UserId = player.UserId })
					self:_toastPlayer(
						player,
						"Taking over your session",
						"Your other session is being closed so this one can load your save.",
						"Info"
					)
				end
				task.wait(2.5)
				continue
			end
			lockSince = nil
			if attempts >= 10 then
				if attempts == 10 then
					ModuleLog.Error("Player", string.format("%s join retries degraded to slow retry after %d attempts — %s", player.Name, attempts, tostring(problem)), { UserId = player.UserId })
					self:_toastPlayer(
						player,
						"Still connecting",
						"Your save is taking longer than usual to load. We'll keep retrying, so you don't need to rejoin.",
						"Warning"
					)
				end
				task.wait(25)
				continue
			end
			task.wait(math.min(0.8 + attempts * 0.25, 5))
		end
		self._joining[player] = nil
		if self._runtime[player] or player.Parent ~= Players then
			return
		end
		if self._data:Get(player) then
			pcall(function()
				self._data:Save(player, true)
			end)
		end
	end

	function GameService:_onPlayerRemoving(player: Player)
		ModuleLog.Player(player, "left — saving")
		self._joining[player] = nil
		self._saveFailedToastAt[player] = nil
		local characterConnection = self._characterConnections[player]
		if characterConnection then characterConnection:Disconnect() end
		self._characterConnections[player] = nil
		local pendingPush = self._queuedStatePushes[player]
		if pendingPush then task.cancel(pendingPush) end
		self._queuedStatePushes[player] = nil
		self._presence[player.UserId] = nil
		self:_clearVisit(player, true)
		local hosted = self._visitors[player.UserId]
		if hosted then
			for visitor in hosted do
				self._visiting[visitor] = nil
				if visitor.Parent == Players then
					self:_toastPlayer(visitor, "Visit ended", "The host left the server.", "Info")
					self._effect:FireClient(visitor, { Type = "VisitEnded" })
				end
			end
			self._visitors[player.UserId] = nil
		end
		local profile = self._data:Get(player)
		self._convergence:PlayerRemoving(player)
		if self._trades then
			local notify = self._trades:Drop(player.UserId)
			for _, userId in notify do
				local other = Players:GetPlayerByUserId(userId)
				if other then
					self:_toastPlayer(other, "Trade closed", "Your partner left the server.", "Info")
					self:_pushState(other, true)
				end
			end
		end
		if profile then
			self._analytics:PlayerLeft(player, profile)
			self._data:MarkDirty(player)
		end
		self._world:RemovePlot(player)
		local runtime = self._runtime[player]
		if runtime and runtime.MatterEntity and self._matter then
			self._matter:Despawn(runtime.MatterEntity)
		end
		self._runtime[player] = nil
		self._firewall:Forget(player)
		self._session:Forget(player)
		self._antiCheat:Forget(player)
		if self._admin then self._admin:Forget(player) end
		self._analytics:Forget(player)
		self._badges:Forget(player)
		if not self._data:Save(player, true) then

			self:_spawnWorker(function()
				for attempt = 1, 3 do
					task.wait(attempt * 2)

					if not self._running or self._data:Get(player) == nil then
						return
					end
					if self._data:Save(player, true) then
						return
					end
				end
				ModuleLog.Warn("Data", string.format("release retries exhausted for %s", player.Name))
			end)
		end
		self:_queueSocialBoostRefresh()
	end

	function GameService:_queueGuildMembershipRefresh(player: Player, runtime)
		if runtime.GuildRefreshBusy then return end
		local profile = self._data:Get(player)
		local guildId = profile and profile.Guild and profile.Guild.Id or ""
		if guildId == "" then return end
		runtime.GuildRefreshBusy = true
		local shadow = {
			Guild = copyDictionary(profile.Guild),
			GuildBonuses = copyDictionary(profile.GuildBonuses or { Production = 0, Capacity = 0, Offline = 0, Automation = 0, Tap = 0 }),
		}
		self:_spawnWorker(function()
			local resolved, problem = pcall(function()
				self._guilds:ReconcileMembership(shadow, player.UserId)
			end)
			if resolved and self._running and player.Parent == Players and self._runtime[player] == runtime then
				local changed = false
				local committed = self._data:AtomicUpdate(player, function(current)
					if not current.Guild or current.Guild.Id ~= guildId then
						return { ok = false, noop = true }
					end
					local desiredGuild = shadow.Guild or { Id = "", Role = "", JoinedAt = 0, Tag = "" }
					local desiredBonuses = shadow.GuildBonuses or { Production = 0, Capacity = 0, Offline = 0, Automation = 0, Tap = 0 }
					local currentBonuses = current.GuildBonuses or {}
					changed = current.Guild.Id ~= desiredGuild.Id
						or current.Guild.Role ~= desiredGuild.Role
						or current.Guild.Tag ~= desiredGuild.Tag
						or current.Guild.JoinedAt ~= desiredGuild.JoinedAt
						or currentBonuses.Production ~= desiredBonuses.Production
						or currentBonuses.Capacity ~= desiredBonuses.Capacity
						or currentBonuses.Offline ~= desiredBonuses.Offline
					if not changed then return { ok = false, noop = true } end
					current.Guild = copyDictionary(desiredGuild)
					current.GuildBonuses = copyDictionary(desiredBonuses)
					return { ok = true }
				end, true, "guild-refresh")
				if committed and changed then self:_queueStatePush(player) end
			elseif not resolved then
				ModuleLog.Every("guild-refresh:" .. tostring(player.UserId), 30, "Guild", tostring(problem))
			end
			runtime.GuildRefreshBusy = false
		end)
	end

	function GameService:_processPlayerTick(player: Player, runtime)
		if runtime.MaintenanceAccumulator >= PROFILE_MAINTENANCE_INTERVAL and not self._data:IsBusy(player) then
			runtime.MaintenanceAccumulator %= PROFILE_MAINTENANCE_INTERVAL
			local changed = false
			local committed = self._data:AtomicUpdate(player, function(profile)
				changed = ProgressionService.EnsureQuests(profile, player.UserId) or changed
				changed = ProgressionService.EnsureTimedRewards(profile) or changed
				changed = ProgressionService.EnsureCommandRotations(profile) or changed
				changed = ensureItemShop(profile) or changed
				changed = AnomalyService.Ensure(profile) or changed
				changed = LabService.Ensure(profile, player.UserId) or changed
				if not self._antiCheat:Observe(player, "Maintenance", profile) then
					changed = true
				end
				if not changed then return { ok = false, noop = true } end
				return { ok = true }
			end, true, "maintenance")
			if committed and changed then self:_queueStatePush(player) end
		end
		if runtime.GuildRefreshAccumulator >= GUILD_REFRESH_INTERVAL then
			runtime.GuildRefreshAccumulator %= GUILD_REFRESH_INTERVAL
			self:_queueGuildMembershipRefresh(player, runtime)
		end
		if runtime.ProductionAccumulator >= GameConfig.Game.ProductionTick then
			local step = runtime.ProductionAccumulator
			local pendingAnomalyActions = runtime.PendingAnomalyActions or {}
			local pendingAnomalyCount = #pendingAnomalyActions
			local anomalyDetails = nil

			if self._data:IsBusy(player) then
				local maxCatchUp = GameConfig.Game.ProductionTick * 4
				if runtime.ProductionAccumulator > maxCatchUp then
					runtime.ProductionAccumulator = maxCatchUp
				end
			else
				runtime.ProductionAccumulator = 0
				local ok = self._data:AtomicUpdate(player, function(profile)
					local now = os.time()
					local active = ensureActiveBoost(profile)
					if active.EndsAt > 0 and active.EndsAt <= now then
						profile.ActiveBoost = { Id = "", EndsAt = 0 }
					end
					local production = Economy.Mul(Economy.Production(profile, now), self._convergence:Multiplier() * self._fluxSurge:Multiplier(now) * self._events:ProductionMultiplier() * self._crews:Multiplier(player))
					local capacity = Economy.Capacity(profile, now)
					local produced = Economy.Mul(production, step)
					profile.Vault = Economy.Min(capacity, Economy.Add(profile.Vault, produced))

					local autoRate = Economy.AutoCollectRate(profile)
					if autoRate > 0 and Economy.Gt(profile.Vault, 0) then

						local fromVault = Economy.Mul(profile.Vault, autoRate * step)
						local fromProd = Economy.Mul(produced, autoRate)
						local collected = Economy.Min(profile.Vault, Economy.Max(fromVault, fromProd))
						if Economy.Gt(collected, 0) then
							profile.Vault = Economy.Sub(profile.Vault, collected)
							profile.Cash = Economy.Add(profile.Cash, collected)
							profile.RunCash = Economy.Add(profile.RunCash, collected)
							profile.LifetimeCash = Economy.Add(profile.LifetimeCash, collected)
							local stats = ensureStats(profile)
							stats.Collected = Economy.Add(stats.Collected, collected)
							ProgressionService.Progress(profile, "EarnCash", Economy.AsNumber(collected))
							LabService.Progress(profile, "BankFlux", Economy.AsNumber(collected))
						end
					end
					bumpStat(profile, "PlayTime", step)
					ProgressionService.EnsureTimedRewards(profile)
					profile.TimedRewards.PlaySeconds += step
					if pendingAnomalyCount > 0 then
						local totalAmount = 0
						local becameReady = false
						for index = 1, pendingAnomalyCount do
							local action = pendingAnomalyActions[index]
							local amount, ready = AnomalyService.Progress(profile, anomalyChargeByAction[action] or 0)
							totalAmount += amount
							becameReady = becameReady or ready
							local signal = anomalySignalByAction[action]
							if signal then AnomalyService.Signal(profile, signal, 1) end
						end
						anomalyDetails = {
							Amount = totalAmount,
							BecameReady = becameReady,
							Charge = profile.Anomaly.Charge,
						}
					end
					enforceUnlimitedMoney(profile)
					self._antiCheat:Observe(player, "Production", profile)
				end, false, "production")
				if not ok then
					runtime.ProductionAccumulator += step
				elseif pendingAnomalyCount > 0 then
					-- Drain only the actions we processed; any appended during the tick
					-- remain queued for the next production tick.
					local currentPending = runtime.PendingAnomalyActions or {}
					local remaining = {}
					for i = pendingAnomalyCount + 1, #currentPending do
						table.insert(remaining, currentPending[i])
					end
					runtime.PendingAnomalyActions = remaining
					self:_queueStatePush(player)
					if anomalyDetails and anomalyDetails.BecameReady then
						self._effect:FireClient(player, {
							Type = "AnomalyReady",
							Amount = anomalyDetails.Amount,
							Charge = anomalyDetails.Charge,
						})
						self:_toastPlayer(player, "Reactor ready", "Stabilize it for the payout.", "Special")
					end
				end
			end
		end

		if runtime.AutoForgeAccumulator >= AUTO_FORGE_INTERVAL then
			runtime.AutoForgeAccumulator = runtime.AutoForgeAccumulator % AUTO_FORGE_INTERVAL
			self:_tickAutoForge(player)
		end

		if runtime.DirtyAccumulator >= 5 then
			runtime.DirtyAccumulator = 0
			self._data:MarkDirty(player)
		end
		if runtime.PushAccumulator >= GameConfig.Game.StatePushSeconds then
			runtime.PushAccumulator = 0
			local profile = self._data:Get(player)
			if profile then
				self:_syncLeaderstats(player, profile)
				self:_pushState(player)
			end
		end
	end

	function GameService:_tickPlayer(player: Player, runtime, deltaTime: number)
		if player.Parent ~= Players then
			return
		end
		runtime.ProductionAccumulator += deltaTime
		runtime.AutoForgeAccumulator = (runtime.AutoForgeAccumulator or 0) + deltaTime
		runtime.PushAccumulator += deltaTime
		runtime.DirtyAccumulator += deltaTime
		runtime.MaintenanceAccumulator = (runtime.MaintenanceAccumulator or 0) + deltaTime
		runtime.GuildRefreshAccumulator = (runtime.GuildRefreshAccumulator or 0) + deltaTime

		local hasWork = runtime.ProductionAccumulator >= GameConfig.Game.ProductionTick
			or runtime.AutoForgeAccumulator >= AUTO_FORGE_INTERVAL
			or runtime.DirtyAccumulator >= 5
			or runtime.PushAccumulator >= GameConfig.Game.StatePushSeconds
			or runtime.MaintenanceAccumulator >= PROFILE_MAINTENANCE_INTERVAL
			or runtime.GuildRefreshAccumulator >= GUILD_REFRESH_INTERVAL
		if not hasWork or runtime.MatterWorkQueued then
			return
		end

		runtime.MatterWorkQueued = true
		local workToken = (runtime.MatterWorkToken or 0) + 1
		runtime.MatterWorkToken = workToken
		self:_spawnWorker(function()

			local watchdog = task.delay(15, function()
				if runtime.MatterWorkToken == workToken and runtime.MatterWorkQueued then
					runtime.MatterWorkQueued = false
					ModuleLog.Warn("game loop", string.format("player tick watchdog released %s after 15s", player.Name), { UserId = player.UserId })
				end
			end)
			if not self._running or player.Parent ~= Players or self._runtime[player] ~= runtime then
				runtime.MatterWorkQueued = false
				task.cancel(watchdog)
				return
			end
			local ok, problem = pcall(self._processPlayerTick, self, player, runtime)
			if runtime.MatterWorkToken == workToken then
				runtime.MatterWorkQueued = false
			end
			task.cancel(watchdog)
			if not ok then
				ModuleLog.Every(
					"matter-player-work:" .. tostring(player.UserId),
					5,
					"game loop",
					string.format("deferred production failed for %s — %s", player.Name, tostring(problem))
				)
			end
		end)
	end

	function GameService:_tick(deltaTime: number)
		self._fluxSurge:Tick(deltaTime)
		self._events:Step(deltaTime)

		self._rankPingAccumulator += deltaTime
		if self._rankPingAccumulator >= RANK_PING_INTERVAL then
			self._rankPingAccumulator = 0
			if not self._rankPingBusy and #Players:GetPlayers() > 0 then
				self._rankPingBusy = true
				local worker = self:_spawnWorker(function()
					pcall(function()
						self:_getLeaderboard(RANK_PING_BOARD)
					end)
					self._rankPingBusy = false
				end)
				if not worker then
					self._rankPingBusy = false
				end
			end
		end

		self._matterAccumulator += deltaTime
		if self._matterAccumulator < 0.2 then
			return
		end
		self._matterAccumulator = 0
		if self._matter then
			self._matter:Step()
		end
	end

	function GameService:Start()
		if self._running then
			return
		end
		self._running = true
		self._convergence:Start()
		MarketplaceService.ProcessReceipt = function(receiptInfo)
			local ok, decision = pcall(function()
				return self:_processReceipt(receiptInfo)
			end)
			if ok then
				return decision
			end
			ModuleLog.Warn("Shop", "ProcessReceipt failed — " .. tostring(decision))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if self._matter then
			self._matter:Start()
		end
		self._world:SetInteractionHandler(function(player, action, payload)
			if action == "Collect" then
				self:_collect(player)
			elseif action == "BuyMachine" then
				self:_buyMachine(player, payload)
			elseif action == "Zone" then
				local profile = self._data:Get(player)
				if profile and payload <= profile.Zone then
					self:_selectZone(player, payload)
				else
					self:_unlockZone(player, payload)
				end
			end
			self:_pushState(player)
		end)

		self._request.OnServerInvoke = function(player, action, payload)
			local requestStartedAt = os.clock()

			if player:GetAttribute("AstralForgeLoaded") ~= true
				and action ~= Protocol.Actions.MeasureLatency
				and action ~= Protocol.Actions.ReportClientIntegrity
				and action ~= Protocol.Actions.ReportPerformance
				and action ~= Protocol.Actions.ReportPresence
			then
				return responseError("Profile is still loading.")
			end
			if self._security then
				local authorityOk, authorityMessage = self._security.Authority:Validate(player, action, payload)
				if not authorityOk then
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d authority %s %s", player.UserId, tostring(action), tostring(authorityMessage))
					)
					return responseError(authorityMessage or "Request rejected.")
				end

				if
					not self._security.Rate:Allow(player, action == Protocol.Actions.AdminExecute and 1 or 0.1)
				then
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d rate %s", player.UserId, tostring(action))
					)
					return responseError("Please slow down for a moment.")
				end
			end
			local allowed, firewallMessage = self._firewall:Check(player, action, payload)
			if not allowed then
				if action ~= Protocol.Actions.ReportPresence and action ~= Protocol.Actions.ReportPerformance then
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d firewall %s %s", player.UserId, tostring(action), tostring(firewallMessage))
					)
				end
				return responseError(firewallMessage or "Please slow down for a moment.")
			end
			local readOnly = CommandActionValidators.IsReadOnly(action)
			local payloadTable = type(payload) == "table" and payload or nil
			if not readOnly then
				local grantOk, grantReason = self._session:CheckGrant(
					player,
					payloadTable and payloadTable.Gen,
					payloadTable and payloadTable.N,
					CommandActionValidators.RequiresHighValueNonce(action)
				)
				if not grantOk then
					ModuleLog.Every(
						string.format("gate:%d", player.UserId),
						8,
						"gate",
						string.format("u=%d drop %s %s", player.UserId, tostring(action), tostring(grantReason))
					)
					local liveGen, liveNonce = self._session:Peek(player)
					return {
						ok = false,
						error = "Your session needs to refresh. One moment.",
						Gen = liveGen,
						N = liveNonce,
						Auth = if grantReason == "unauth" then false else nil,
					}
				end
			end
			local txnId = payloadTable and type(payloadTable.TxnId) == "string" and payloadTable.TxnId or nil
			local txnClaimed = false
			if txnId then
				local status, storedResult = self._session:TxnClaim(player, txnId)
				if status == "done" then
					return storedResult
				end
				if status == "busy" then
					return responseError("Still working on that.")
				end
				txnClaimed = true
			end
			local success, result
			success, result = pcall(function()
				return self:_handleAction(player, action, payload)
			end)
			if not success then
				if txnClaimed and txnId then
					self._session:TxnRelease(player, txnId)
				end
				ModuleLog.Every(
					string.format("action:%d:%s", player.UserId, tostring(action)),
					5,
					"Action",
					string.format("u=%d could not run %s — %s", player.UserId, tostring(action), tostring(result))
				)
				return responseError("The forge encountered an error. Please try again.")
			end
			if type(result) ~= "table" or type(result.ok) ~= "boolean" then
				if txnClaimed and txnId then
					self._session:TxnRelease(player, txnId)
				end
				ModuleLog.Every(
					string.format("action-contract:%d:%s", player.UserId, tostring(action)),
					5,
					"Action",
					string.format("u=%d got an invalid response for %s", player.UserId, tostring(action))
				)
				return responseError("The forge returned an invalid response. Please try again.")
			end
			if txnClaimed and txnId then
				if result.ok then
					self._session:TxnStore(player, txnId, result)
				else
					self._session:TxnRelease(player, txnId)
				end
			end
			if result.ok == false
				and action ~= Protocol.Actions.ReportPresence
				and action ~= Protocol.Actions.ReportPerformance
			then
				ModuleLog.Every(
					string.format("result:%d:%s", player.UserId, tostring(action)),
					10,
					"Action",
					string.format("u=%d %s failed — %s", player.UserId, tostring(action), tostring(result.error))
				)
			end
			if result.ok and not readOnly then

				self:_spawnWorker(function()
					if player.Parent ~= Players then return end
					self:_progressAnomalyFromAction(player, action)
					local profile = self._data:Get(player)
					if profile then
						self._convergence:RecordAction(player, tostring(action))
						if action == Protocol.Actions.CollectVault then self._crews:RecordCollect(player) end
						self._analytics:RecordAction(player, tostring(action), profile, (os.clock() - requestStartedAt) * 1000)
						self._badges:Evaluate(player, profile, tostring(action))
					end
					self:_syncLeaderstats(player, profile)
					if not CommandActionValidators.IsDeferredSnapshot(action) then self:_queueStatePush(player) end
				end)
			end
			if not readOnly and result.Gen == nil then
				result.Gen, result.N = self._session:Peek(player)
			end
			return result
		end

		self._playerAddedConnection = Players.PlayerAdded:Connect(function(player)
			self:_spawnWorker(function()
				self:_safePlayerAdded(player)
			end)
		end)
		self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
			self:_onPlayerRemoving(player)
			self:_queueSocialBoostRefresh()
		end)
		for _, player in Players:GetPlayers() do
			local target = player
			self:_spawnWorker(function()
				self:_safePlayerAdded(target)
			end)
		end
		self._heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
			if not self._running then
				return
			end
			self:_tick(deltaTime)
		end)
	end

	function GameService:GrantStudioMoney(player: Player): (boolean, string, number?)
		if not ShopGrantEligibility.StudioGrantAllowed(RunService:IsStudio()) then
			return false, "Studio grants are disabled in published servers."
		end
		if player.Parent ~= Players then
			return false, "That player is not in this server."
		end
		if not self._data:Get(player) then
			return false, "The player's profile is still loading. Wait for the game UI, then retry."
		end

		local updated, updateError = self._data:Update(player, function(profile)
			profile.Flags.UnlimitedMoney = true
			enforceUnlimitedMoney(profile)
		end)
		if not updated then
			return false, "Profile update failed: " .. tostring(updateError)
		end

		self:_syncLeaderstats(player, self._data:Get(player))
		self:_pushState(player)
		self:_toastPlayer(player, "Unlimited Flux enabled", "Your test balance will not decrease.", "Success")
		if not self._data:Save(player, false) then
			return false, "The balance changed in-session, but the forced DataStore save failed."
		end
		return true, "Unlimited Flux lock enabled and saved. Purchases cannot lower it.", MAX_SAFE_CURRENCY
	end

	function GameService:GrantStudioWheelSpins(player: Player, amount: number?): (boolean, string, number?)
		if not ShopGrantEligibility.StudioGrantAllowed(RunService:IsStudio()) then
			return false, "Studio grants are disabled in published servers."
		end
		if player.Parent ~= Players then
			return false, "That player is not in this server."
		end
		if not self._data:Get(player) then
			return false, "The player's profile is still loading. Wait for the game UI, then retry."
		end

		local grant = ShopGrantEligibility.ClampWheelGrant(amount)
		local total = 0
		local updated, updateError = self._data:Update(player, function(profile)
			local current = math.max(0, math.floor(tonumber(profile.Wheel.FreeSpins) or 0))
			total = current + grant
			profile.Wheel.FreeSpins = total
		end)
		if not updated then
			return false, "Profile update failed: " .. tostring(updateError)
		end

		self:_pushState(player)
		self:_toastPlayer(player, "Free wheel spins", tostring(grant) .. " spins added (" .. tostring(total) .. " ready).", "Success")
		return true, "Granted " .. tostring(grant) .. " free wheel spins (" .. tostring(total) .. " total).", total
	end

	function GameService:ShowRelease(player: Player): (boolean, string)
		if player.Parent ~= Players then
			return false, "That player is not in this server."
		end
		local updated, updateError = self._data:Update(player, function(profile)
			profile.Flags.LastSeenVersion = ""
		end)
		if not updated then
			return false, "Profile update failed: " .. tostring(updateError)
		end
		self:_pushState(player)
		return true, "Release notes reopened for " .. player.Name .. "."
	end

	function GameService:Shutdown()
		self._running = false
		self._joining = {}
		self._socialBoostDirty = false
		self._socialBoostScheduled = false
		if self._socialBoostWorker then
			task.cancel(self._socialBoostWorker)
			self._socialBoostWorker = nil
		end
		if self._playerAddedConnection then
			self._playerAddedConnection:Disconnect()
			self._playerAddedConnection = nil
		end
		if self._playerRemovingConnection then
			self._playerRemovingConnection:Disconnect()
			self._playerRemovingConnection = nil
		end
		for player, connection in self._characterConnections do
			connection:Disconnect()
			self._characterConnections[player] = nil
		end
		table.clear(self._joining)
		if self._admin then self._admin:Destroy() end

		self._request.OnServerInvoke = function()
			return responseError("The server is shutting down.")
		end
		for player, pending in self._queuedStatePushes do
			task.cancel(pending)
			self._queuedStatePushes[player] = nil
		end
		for token, worker in self._backgroundWorkers do
			pcall(task.cancel, worker)
			self._backgroundWorkers[token] = nil
		end
		if self._heartbeat then
			self._heartbeat:Disconnect()
			self._heartbeat = nil
		end
		if self._matter then
			self._matter:Stop()
		end
		self._convergence:Stop()
		self._guilds:Destroy()
		self._guildCommunity:Shutdown()
		self._chat:Shutdown()
		self._crews:Shutdown()
		self._badges:Destroy()
	end

	return GameService
end

serviceFactories["GuildService"] = require(script.Parent:WaitForChild("CoreServices"))("GuildService")

serviceFactories["LabService"] = require(script.Parent:WaitForChild("CoreServices"))("LabService")

serviceFactories["MatterRuntime"] = require(script.Parent:WaitForChild("MatterRuntime"))

serviceFactories["PlayerAnalytics"] = function() return require(script.Parent:WaitForChild("PlayerAnalytics"))(loadService) end

serviceFactories["PlayerBadges"] = require(script.Parent:WaitForChild("PlayerBadges"))

serviceFactories["ProfileIntegrity"] = require(script.Parent:WaitForChild("SecurityServices"))("ProfileIntegrity")

serviceFactories["ProgressionService"] = require(script.Parent:WaitForChild("CoreServices"))("ProgressionService")

serviceFactories["RemoteFirewall"] = function() return require(script.Parent:WaitForChild("RemoteFirewall"))(loadService) end

serviceFactories["Security"] = require(script.Parent:WaitForChild("SecurityServices"))("Security")

serviceFactories["SessionGate"] = require(script.Parent:WaitForChild("SecurityServices"))("SessionGate")

serviceFactories["ServerTelemetry"] = require(script.Parent:WaitForChild("SecurityServices"))("ServerTelemetry")

serviceFactories["WorldService"] = require(script.Parent:WaitForChild("WorldServices"))("WorldService")

loadService = function(name: string): any
	if serviceLoaded[name] then
		return serviceCache[name]
	end
	if serviceLoading[name] then
		error("[AF/server] circular service dependency: " .. name, 2)
	end
	local factory = serviceFactories[name]
	if factory == nil then
		error("[AF/server] unknown service: " .. name, 2)
	end
	serviceLoading[name] = true
	local ok, result = xpcall(factory, debug.traceback)
	serviceLoading[name] = nil
	if not ok then
		error(result, 2)
	end
	serviceCache[name] = result
	serviceLoaded[name] = true
	return result
end

local ServerServices = {}
setmetatable(ServerServices, {
	__index = function(target, name)
		if type(name) ~= "string" then
			return nil
		end
		local service = loadService(name)
		rawset(target, name, service)
		return service
	end,
	__newindex = function()
		error("[AF/server] service registry is read-only", 2)
	end,
	__metatable = "locked",
})

return ServerServices
