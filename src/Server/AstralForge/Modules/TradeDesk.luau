--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
local ProgressionGate = require(script.Parent:WaitForChild("ProgressionGate"))

local TradeDesk = {}
TradeDesk.__index = TradeDesk

local CURRENCIES = { "Cash", "Stardust", "Cores", "Signals", "Essence" }
local BOOST_IDS = {
	"DomainSurge", "Overdrive", "Hyperdrive", "VaultSurge", "NightShift", "FoundryRush",
	"Afterburner", "SteadyBurn", "CoreSurge", "StarforgeFlow", "EchoDrive", "Ionstorm", "TwinCatalyst", "MidnightForge",
}
local KEY_IDS = { "ForgeCrate", "NebulaCrate", "SingularityCrate" }

local itemNames: { [string]: string }? = nil
local function itemNameFor(definitionId: string): string
	if itemNames == nil then
		itemNames = {}
		local defs = GameConfig.Items and GameConfig.Items.Definitions
		if type(defs) == "table" then
			for _, definition in defs do
				if type(definition) == "table" and type(definition.Id) == "string" then
					itemNames[definition.Id] = type(definition.Name) == "string" and definition.Name or definition.Id
				end
			end
		end
	end
	return itemNames[definitionId] or "Relic"
end

local function utcDay(now: number): number
	local date = os.date("!*t", now)
	return date.year * 1000 + date.yday
end

local function emptyOffer()
	return {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boosts = {
			DomainSurge = 0, Overdrive = 0, Hyperdrive = 0, VaultSurge = 0, NightShift = 0, FoundryRush = 0,
			Afterburner = 0, SteadyBurn = 0, CoreSurge = 0, StarforgeFlow = 0, EchoDrive = 0, Ionstorm = 0, TwinCatalyst = 0, MidnightForge = 0,
		},
		Keys = { ForgeCrate = 0, NebulaCrate = 0, SingularityCrate = 0 },
		ItemIds = {},
	}
end

local function copyOffer(offer)
	local nextOffer = emptyOffer()
	if type(offer) ~= "table" then
		return nextOffer
	end
	for _, key in CURRENCIES do
		nextOffer[key] = math.max(0, math.floor(tonumber(offer[key]) or 0))
	end
	if type(offer.Boosts) == "table" then
		for _, id in BOOST_IDS do
			nextOffer.Boosts[id] = math.max(0, math.floor(tonumber(offer.Boosts[id]) or 0))
		end
	end
	if type(offer.Keys) == "table" then
		for _, id in KEY_IDS do
			nextOffer.Keys[id] = math.max(0, math.floor(tonumber(offer.Keys[id]) or 0))
		end
	end
	if type(offer.ItemIds) == "table" then
		local seen = {}
		for _, uid in offer.ItemIds do
			if type(uid) == "string" and uid ~= "" and not seen[uid] then
				seen[uid] = true
				table.insert(nextOffer.ItemIds, uid)
			end
		end
	end
	if type(offer.Items) == "table" then
		nextOffer.Items = {}
		for _, row in offer.Items do
			if type(row) == "table" and type(row.Uid) == "string" then
				table.insert(nextOffer.Items, {
					Uid = row.Uid,
					DefinitionId = type(row.DefinitionId) == "string" and row.DefinitionId or "",
					Name = type(row.Name) == "string" and row.Name or "Relic",
				})
			end
		end
	end
	return nextOffer
end

local function stampItems(offer, profile)
	offer.Items = {}
	local inventory = profile and profile.Items and profile.Items.Inventory
	if type(inventory) ~= "table" then
		return
	end
	for _, uid in offer.ItemIds do
		local instance = inventory[uid]
		local definitionId = type(instance) == "table" and type(instance.DefinitionId) == "string" and instance.DefinitionId or ""
		table.insert(offer.Items, {
			Uid = uid,
			DefinitionId = definitionId,
			Name = itemNameFor(definitionId),
		})
	end
end

local function offerEmpty(offer): boolean
	for _, key in CURRENCIES do
		if offer[key] > 0 then
			return false
		end
	end
	for _, id in BOOST_IDS do
		if offer.Boosts[id] > 0 then
			return false
		end
	end
	for _, id in KEY_IDS do
		if offer.Keys[id] > 0 then
			return false
		end
	end
	return #offer.ItemIds == 0
end

local function ensureLedger(profile, now: number)
	if type(profile.Trade) ~= "table" then
		profile.Trade = { Day = -1, Completed = 0, Sent = {} }
	end
	local day = utcDay(now)
	if profile.Trade.Day ~= day then
		profile.Trade.Day = day
		profile.Trade.Completed = 0
		profile.Trade.Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 }
	end
	if type(profile.Trade.Sent) ~= "table" then
		profile.Trade.Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 }
	end
end

local function itemEquipped(profile, uid: string): boolean
	if type(profile.Items) ~= "table" or type(profile.Items.Equipped) ~= "table" then
		return false
	end
	for _, equipped in profile.Items.Equipped do
		if equipped == uid then
			return true
		end
	end
	return false
end

local function countInventory(profile): number
	local count = 0
	if profile.Items and type(profile.Items.Inventory) == "table" then
		for _ in profile.Items.Inventory do
			count += 1
		end
	end
	return count
end

local function boostTotal(offer): number
	local total = 0
	for _, id in BOOST_IDS do
		total += offer.Boosts[id]
	end
	return total
end

local function keyTotal(offer): number
	local total = 0
	for _, id in KEY_IDS do
		total += offer.Keys[id]
	end
	return total
end

function TradeDesk.new()
	return setmetatable({
		_sessions = {},
		_byUser = {},
		_invites = {},
		_outgoing = {},
		_epoch = 0,
		_nextId = 1,
	}, TradeDesk)
end

function TradeDesk:_bump()
	self._epoch = (self._epoch or 0) + 1
end

function TradeDesk:Epoch(): number
	return self._epoch or 0
end

function TradeDesk:_sessionId(): string
	self._nextId += 1
	return string.format("td_%d_%d", os.time(), self._nextId)
end

function TradeDesk:Unlocked(profile): boolean
	return ProgressionGate.IsFeatureUnlocked(profile, "Trade")
end

function TradeDesk:Public(session, userId: number)
	if not session then
		return nil
	end
	local them = if session.Host == userId then session.Guest else session.Host
	local themPlayer = Players:GetPlayerByUserId(them)
	local partnerName = themPlayer and themPlayer.DisplayName or "Forge partner"
	return {
		Id = session.Id,
		PartnerUserId = them,
		PartnerName = partnerName,
		You = copyOffer(session.Offers[userId]),
		Them = copyOffer(session.Offers[them]),
		YouReady = session.Ready[userId] == true,
		ThemReady = session.Ready[them] == true,
		YouConfirmed = session.Confirmed[userId] == true,
		ThemConfirmed = session.Confirmed[them] == true,
		ConfirmEndsAt = session.ConfirmEndsAt,
		Status = session.Status,
		ExpiresAt = session.ExpiresAt,
	}
end

function TradeDesk:InvitePublic(userId: number)
	local invite = self._invites[userId]
	if not invite or (type(invite.ExpiresAt) == "number" and invite.ExpiresAt < os.time()) then
		if invite then
			self._invites[userId] = nil
		end
		return nil
	end
	local from = Players:GetPlayerByUserId(invite.From)
	return {
		FromUserId = invite.From,
		FromName = from and from.DisplayName or "A forgemaster",
		ExpiresAt = invite.ExpiresAt,
	}
end

function TradeDesk:OutgoingPublic(userId: number)
	local outgoing = self._outgoing[userId]
	if not outgoing or (type(outgoing.ExpiresAt) == "number" and outgoing.ExpiresAt < os.time()) then
		if outgoing then
			self._outgoing[userId] = nil
		end
		return nil
	end
	return {
		ToUserId = outgoing.To,
		ToName = outgoing.ToName,
		ExpiresAt = outgoing.ExpiresAt,
	}
end

function TradeDesk:DailyPublic(profile, now: number)
	ensureLedger(profile, now)
	return {
		Completed = profile.Trade.Completed,
		Limit = GameConfig.Trading.DailyTrades,
		Sent = {
			Cash = profile.Trade.Sent.Cash or 0,
			Stardust = profile.Trade.Sent.Stardust or 0,
			Cores = profile.Trade.Sent.Cores or 0,
			Signals = profile.Trade.Sent.Signals or 0,
			Essence = profile.Trade.Sent.Essence or 0,
			Boost = profile.Trade.Sent.Boost or 0,
			Keys = profile.Trade.Sent.Keys or 0,
			Items = profile.Trade.Sent.Items or 0,
		},
		Caps = GameConfig.Trading.Daily,
		PerTrade = GameConfig.Trading.PerTrade,
	}
end

function TradeDesk:Drop(userId: number): { number }
	local notify = {}
	local invite = self._invites[userId]
	if invite then
		self._invites[userId] = nil
		if self._outgoing[invite.From] then
			self._outgoing[invite.From] = nil
			table.insert(notify, invite.From)
		end
	end
	if self._outgoing[userId] then
		local outgoing = self._outgoing[userId]
		self._outgoing[userId] = nil
		if outgoing and self._invites[outgoing.To] and self._invites[outgoing.To].From == userId then
			self._invites[outgoing.To] = nil
			table.insert(notify, outgoing.To)
		end
	end
	for target, pending in self._invites do
		if pending.From == userId then
			self._invites[target] = nil
			table.insert(notify, target)
		end
	end
	local sessionId = self._byUser[userId]
	if sessionId then
		local session = self._sessions[sessionId]
		if session then
			self._sessions[sessionId] = nil
			self._byUser[session.Host] = nil
			self._byUser[session.Guest] = nil
			local other = if session.Host == userId then session.Guest else session.Host
			table.insert(notify, other)
		end
	end
	self._byUser[userId] = nil
	self:_bump()
	return notify
end

function TradeDesk:_validateOffer(profile, offer, now: number, skipDaily: boolean?): string?
	ensureLedger(profile, now)
	local caps = GameConfig.Trading.PerTrade
	local daily = GameConfig.Trading.Daily
	if #offer.ItemIds > GameConfig.Trading.MaxItems or #offer.ItemIds > caps.Items then
		return "That offer has too many relics."
	end
	for _, key in CURRENCIES do
		if offer[key] > caps[key] then
			return string.format("That %s amount is over the per-trade limit.", key == "Cash" and "Flux" or key)
		end
		if not skipDaily and (profile.Trade.Sent[key] or 0) + offer[key] > daily[key] then
			return string.format("Daily %s trade limit reached.", key == "Cash" and "Flux" or key)
		end
	end
	if OmegaMath.Gt(offer.Cash, profile.Cash) then
		return "You do not have that much Flux."
	end
	if offer.Stardust > (tonumber(profile.Stardust) or 0) then
		return "You do not have that much Stardust."
	end
	if offer.Cores > (tonumber(profile.Cores) or 0) then
		return "You do not have that many Cores."
	end
	local signals = profile.Command and tonumber(profile.Command.Signals) or 0
	if offer.Signals > signals then
		return "You do not have that many Signals."
	end
	local essence = profile.Items and tonumber(profile.Items.Essence) or 0
	if offer.Essence > essence then
		return "You do not have that much Essence."
	end
	local boostSum = boostTotal(offer)
	if boostSum > caps.Boost then
		return "That many boosts is over the per-trade limit."
	end
	if not skipDaily and (profile.Trade.Sent.Boost or 0) + boostSum > daily.Boost then
		return "Daily boost trade limit reached."
	end
	for _, id in BOOST_IDS do
		local owned = profile.BoostInventory and tonumber(profile.BoostInventory[id]) or 0
		if offer.Boosts[id] > owned then
			return "You do not have that many of that boost."
		end
	end
	local keySum = keyTotal(offer)
	if keySum > caps.Keys then
		return "That many keys is over the per-trade limit."
	end
	if not skipDaily and (profile.Trade.Sent.Keys or 0) + keySum > daily.Keys then
		return "Daily key trade limit reached."
	end
	for _, id in KEY_IDS do
		local owned = profile.Items and profile.Items.Keys and tonumber(profile.Items.Keys[id]) or 0
		if offer.Keys[id] > owned then
			return "You do not have that many crate keys."
		end
	end
	if not skipDaily and (profile.Trade.Sent.Items or 0) + #offer.ItemIds > daily.Items then
		return "Daily relic trade limit reached."
	end
	if not profile.Items or type(profile.Items.Inventory) ~= "table" then
		if #offer.ItemIds > 0 then
			return "Those relics are not in your inventory."
		end
		return nil
	end
	for _, uid in offer.ItemIds do
		local instance = profile.Items.Inventory[uid]
		if type(instance) ~= "table" then
			return "A relic in that offer is missing."
		end
		if instance.Locked == true then
			return "Locked relics cannot be traded."
		end
		if itemEquipped(profile, uid) then
			return "Unequip a relic before trading it."
		end
	end
	return nil
end

function TradeDesk:Invite(fromPlayer: Player, fromProfile, targetUserId: number, now: number): (boolean, string?)
	if not self:Unlocked(fromProfile) then
		return false, "Trade Floor unlocks after your first rebirth."
	end
	if fromPlayer.UserId == targetUserId then
		return false, "You cannot trade with yourself."
	end
	if self._byUser[fromPlayer.UserId] then
		return false, "Finish or cancel your current trade first."
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		return false, "That player is no longer in this server."
	end
	if self._byUser[targetUserId] then
		return false, "They are already in a trade."
	end
	local pending = self._invites[targetUserId]
	if pending and pending.From ~= fromPlayer.UserId and pending.ExpiresAt > now then
		return false, "They already have an open invite."
	end
	local previous = self._outgoing[fromPlayer.UserId]
	if previous and previous.To ~= targetUserId then
		if self._invites[previous.To] and self._invites[previous.To].From == fromPlayer.UserId then
			self._invites[previous.To] = nil
		end
	end
	local expiresAt = now + GameConfig.Trading.InviteSeconds
	self._invites[targetUserId] = {
		From = fromPlayer.UserId,
		ExpiresAt = expiresAt,
	}
	self._outgoing[fromPlayer.UserId] = {
		To = targetUserId,
		ToName = target.DisplayName,
		ExpiresAt = expiresAt,
	}
	self:_bump()
	return true, nil
end

function TradeDesk:Respond(guest: Player, guestProfile, accept: boolean, now: number): (boolean, string?, any, number?)
	local invite = self._invites[guest.UserId]
	self._invites[guest.UserId] = nil
	if invite and self._outgoing[invite.From] and self._outgoing[invite.From].To == guest.UserId then
		self._outgoing[invite.From] = nil
	end
	if not invite or invite.ExpiresAt < now then
		self:_bump()
		return false, "That invite expired."
	end
	if not accept then
		self:_bump()
		return true, nil, nil, invite.From
	end
	if not self:Unlocked(guestProfile) then
		return false, "Trade Floor unlocks after your first rebirth.", nil, invite.From
	end
	if self._byUser[guest.UserId] or self._byUser[invite.From] then
		return false, "A trade is already open.", nil, invite.From
	end
	local host = Players:GetPlayerByUserId(invite.From)
	if not host then
		return false, "They left the server."
	end
	local session = {
		Id = self:_sessionId(),
		Host = invite.From,
		Guest = guest.UserId,
		Offers = {
			[invite.From] = emptyOffer(),
			[guest.UserId] = emptyOffer(),
		},
		Ready = { [invite.From] = false, [guest.UserId] = false },
		Confirmed = { [invite.From] = false, [guest.UserId] = false },
		ConfirmEndsAt = 0,
		Status = "Open",
		ExpiresAt = now + GameConfig.Trading.SessionSeconds,
	}
	self._sessions[session.Id] = session
	self._byUser[invite.From] = session.Id
	self._byUser[guest.UserId] = session.Id
	self:_bump()
	return true, nil, session, invite.From
end

function TradeDesk:UpdateOffer(player: Player, profile, rawOffer, now: number): (boolean, string?, any)
	local session = self._sessions[self._byUser[player.UserId]]
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	local offer = copyOffer(rawOffer)
	local reason = self:_validateOffer(profile, offer, now, false)
	if reason then
		return false, reason
	end
	stampItems(offer, profile)
	session.Offers[player.UserId] = offer
	session.Ready[session.Host] = false
	session.Ready[session.Guest] = false
	session.Confirmed[session.Host] = false
	session.Confirmed[session.Guest] = false
	session.ConfirmEndsAt = 0
	session.Status = "Open"
	return true, nil, session
end

function TradeDesk:SetReady(player: Player, profile, ready: boolean, now: number): (boolean, string?, any)
	local session = self._sessions[self._byUser[player.UserId]]
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	if ready then
		local reason = self:_validateOffer(profile, session.Offers[player.UserId], now, false)
		if reason then
			return false, reason
		end
		if offerEmpty(session.Offers[session.Host]) and offerEmpty(session.Offers[session.Guest]) then
			return false, "Put something on the table first."
		end
	end
	session.Ready[player.UserId] = ready == true
	session.Confirmed[session.Host] = false
	session.Confirmed[session.Guest] = false
	session.ConfirmEndsAt = 0
	session.Status = "Open"
	return true, nil, session
end

function TradeDesk:Confirm(player: Player, now: number): (boolean, string?, any)
	local session = self._sessions[self._byUser[player.UserId]]
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	if session.Ready[session.Host] ~= true or session.Ready[session.Guest] ~= true then
		return false, "Both sides need to ready up first."
	end
	if session.ConfirmEndsAt == 0 then
		session.ConfirmEndsAt = now + GameConfig.Trading.ConfirmSeconds
		session.Status = "Confirming"
	elseif now > session.ConfirmEndsAt then
		session.Confirmed[session.Host] = false
		session.Confirmed[session.Guest] = false
		session.ConfirmEndsAt = now + GameConfig.Trading.ConfirmSeconds
	end
	session.Confirmed[player.UserId] = true
	return true, nil, session
end

function TradeDesk:Cancel(player: Player): (any, number?)
	local session = self._sessions[self._byUser[player.UserId]]
	if not session then
		self._invites[player.UserId] = nil
		return nil, nil
	end
	local other = if session.Host == player.UserId then session.Guest else session.Host
	self._sessions[session.Id] = nil
	self._byUser[session.Host] = nil
	self._byUser[session.Guest] = nil
	self:_bump()
	return session, other
end

function TradeDesk:Settle(session, hostProfile, guestProfile, now: number): string?
	if session.Confirmed[session.Host] ~= true or session.Confirmed[session.Guest] ~= true then
		return "Waiting for both confirmations."
	end
	if session.ConfirmEndsAt > 0 and now > session.ConfirmEndsAt then
		return "The confirm window expired. Ready up again."
	end
	ensureLedger(hostProfile, now)
	ensureLedger(guestProfile, now)
	if hostProfile.Trade.Completed >= GameConfig.Trading.DailyTrades or guestProfile.Trade.Completed >= GameConfig.Trading.DailyTrades then
		return "A daily trade limit has been reached."
	end
	local hostOffer = session.Offers[session.Host]
	local guestOffer = session.Offers[session.Guest]
	local hostReason = self:_validateOffer(hostProfile, hostOffer, now)
	if hostReason then
		return hostReason
	end
	local guestReason = self:_validateOffer(guestProfile, guestOffer, now)
	if guestReason then
		return guestReason
	end
	local hostIncoming = #guestOffer.ItemIds
	local guestIncoming = #hostOffer.ItemIds
	local hostLimit = GameConfig.Items.InventoryLimit
	local guestLimit = GameConfig.Items.InventoryLimit
	if countInventory(hostProfile) - #hostOffer.ItemIds + hostIncoming > hostLimit then
		return "Their inventory cannot hold those relics."
	end
	if countInventory(guestProfile) - #guestOffer.ItemIds + guestIncoming > guestLimit then
		return "Your inventory cannot hold those relics."
	end

	local function apply(fromProfile, toProfile, offer)
		fromProfile.Command = type(fromProfile.Command) == "table" and fromProfile.Command or {}
		toProfile.Command = type(toProfile.Command) == "table" and toProfile.Command or {}
		fromProfile.Items = type(fromProfile.Items) == "table" and fromProfile.Items or { Inventory = {}, Keys = {}, Essence = 0 }
		toProfile.Items = type(toProfile.Items) == "table" and toProfile.Items or { Inventory = {}, Keys = {}, Essence = 0 }
		fromProfile.Items.Inventory = type(fromProfile.Items.Inventory) == "table" and fromProfile.Items.Inventory or {}
		toProfile.Items.Inventory = type(toProfile.Items.Inventory) == "table" and toProfile.Items.Inventory or {}
		fromProfile.Items.Keys = type(fromProfile.Items.Keys) == "table" and fromProfile.Items.Keys or {}
		toProfile.Items.Keys = type(toProfile.Items.Keys) == "table" and toProfile.Items.Keys or {}
		fromProfile.BoostInventory = type(fromProfile.BoostInventory) == "table" and fromProfile.BoostInventory or {}
		toProfile.BoostInventory = type(toProfile.BoostInventory) == "table" and toProfile.BoostInventory or {}
		fromProfile.Cash = OmegaMath.Sub(fromProfile.Cash, offer.Cash)
		toProfile.Cash = OmegaMath.Add(toProfile.Cash, offer.Cash)
		fromProfile.Stardust -= offer.Stardust
		toProfile.Stardust += offer.Stardust
		fromProfile.Cores -= offer.Cores
		toProfile.Cores += offer.Cores
		fromProfile.Command.Signals = math.max(0, (tonumber(fromProfile.Command.Signals) or 0) - offer.Signals)
		toProfile.Command.Signals = (tonumber(toProfile.Command.Signals) or 0) + offer.Signals
		fromProfile.Items.Essence = math.max(0, (tonumber(fromProfile.Items.Essence) or 0) - offer.Essence)
		toProfile.Items.Essence = (tonumber(toProfile.Items.Essence) or 0) + offer.Essence
		for _, id in BOOST_IDS do
			local amount = offer.Boosts[id]
			if amount > 0 then
				fromProfile.BoostInventory[id] = math.max(0, (tonumber(fromProfile.BoostInventory[id]) or 0) - amount)
				toProfile.BoostInventory[id] = (tonumber(toProfile.BoostInventory[id]) or 0) + amount
			end
		end
		for _, id in KEY_IDS do
			local amount = offer.Keys[id]
			if amount > 0 then
				fromProfile.Items.Keys[id] = math.max(0, (tonumber(fromProfile.Items.Keys[id]) or 0) - amount)
				toProfile.Items.Keys[id] = (tonumber(toProfile.Items.Keys[id]) or 0) + amount
			end
		end
		for _, uid in offer.ItemIds do
			local instance = fromProfile.Items.Inventory[uid]
			fromProfile.Items.Inventory[uid] = nil
			if instance ~= nil then
				toProfile.Items.Inventory[uid] = instance
			end
		end
		fromProfile.Trade.Sent.Cash += offer.Cash
		fromProfile.Trade.Sent.Stardust += offer.Stardust
		fromProfile.Trade.Sent.Cores += offer.Cores
		fromProfile.Trade.Sent.Signals += offer.Signals
		fromProfile.Trade.Sent.Essence += offer.Essence
		fromProfile.Trade.Sent.Boost += boostTotal(offer)
		fromProfile.Trade.Sent.Keys += keyTotal(offer)
		fromProfile.Trade.Sent.Items += #offer.ItemIds
	end

	apply(hostProfile, guestProfile, hostOffer)
	apply(guestProfile, hostProfile, guestOffer)
	hostProfile.Trade.Completed += 1
	guestProfile.Trade.Completed += 1
	self._sessions[session.Id] = nil
	self._byUser[session.Host] = nil
	self._byUser[session.Guest] = nil
	self:_bump()
	return nil
end

function TradeDesk:SessionFor(userId: number)
	local id = self._byUser[userId]
	return id and self._sessions[id] or nil
end

return TradeDesk
