--!strict

local __defs: { [string]: () -> any } = {}
local __cache: { [string]: { value: any } } = {}
local __loading: { [string]: boolean } = {}

local function __load(name: string): any
	local hit = __cache[name]
	if hit then return hit.value end
	local def = __defs[name]
	if def == nil then error("TradeSuite: unknown module " .. tostring(name), 2) end
	if __loading[name] then error("TradeSuite: cyclic require of member " .. name, 2) end
	__loading[name] = true
	local ok, value = pcall(def)
	__loading[name] = nil
	if not ok then error(value, 0) end
	__cache[name] = { value = value }
	return value
end

__defs["TradeChatMath"] = function()
	local TradeChatMath = {}

	function TradeChatMath.CanSend(lastAt: number?, now: number, cooldown: number?): boolean
		if type(lastAt) ~= "number" or lastAt ~= lastAt then
			return true
		end
		return now - lastAt >= (cooldown or 0.6)
	end

	return table.freeze(TradeChatMath)
end

__defs["TradeRequestMath"] = function()
	local TradeRequestMath = {}

	function TradeRequestMath.Normalize(raw: any, caps: { [string]: number }, currencies: { string }): any
		local request = { ItemIds = {} }
		local itemCap = math.min(8, math.max(0, math.floor(tonumber(caps.Items) or 0)))
		local seen = {}
		if type(raw) == "table" and type(raw.ItemIds) == "table" then
			for _, uid in raw.ItemIds do
				if type(uid) == "string" and #uid > 0 and #uid <= 48 and not seen[uid] and #request.ItemIds < itemCap then
					seen[uid] = true
					table.insert(request.ItemIds, uid)
				end
			end
		end
		for _, key in currencies do
			local amount = type(raw) == "table" and tonumber(raw[key]) or 0
			if type(amount) == "number" and amount == amount and amount > 0 then
				request[key] = math.min(math.floor(amount), math.max(0, math.floor(tonumber(caps[key]) or 0)))
			end
		end
		return request
	end

	return table.freeze(TradeRequestMath)
end

__defs["TradeChatFilter"] = function()
	local TradeChatFilter = {}

	function TradeChatFilter.Apply(textService: any, raw: any, userId: number, context: any): (boolean, string?)
		if type(raw) ~= "string" or #raw == 0 then
			return false, nil
		end
		local text = string.sub(raw, 1, 140)
		local ok, filtered = pcall(function()
			local result = textService:FilterStringAsync(text, userId, context)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok or type(filtered) ~= "string" then
			return false, nil
		end
		return true, filtered
	end

	return table.freeze(TradeChatFilter)
end

__defs["TradeDesk"] = function()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local OmegaMath = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
local ProgressionGate = require(script.Parent:WaitForChild("EconomyMath"))("ProgressionGate")
local TradeHistory = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("TradeHistory"))
local TradeExchange = __load("TradeExchange")
local TradeOfferMath = __load("TradeOfferMath")
local TradeSettle = __load("TradeSettle")
local TradeChatMath = __load("TradeChatMath")
local TradeRequestMath = __load("TradeRequestMath")

local TradeDesk = {}
TradeDesk.__index = TradeDesk

local CURRENCIES = TradeExchange.CURRENCIES
local BOOST_IDS = TradeExchange.BOOST_IDS
local KEY_IDS = TradeExchange.KEY_IDS

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

local function emptyOffer()
	return TradeOfferMath.EmptyOffer(BOOST_IDS, KEY_IDS)
end

local function copyOffer(offer)
	return TradeOfferMath.CopyOffer(offer, CURRENCIES, BOOST_IDS, KEY_IDS)
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
	return TradeOfferMath.OfferEmpty(offer, CURRENCIES, BOOST_IDS, KEY_IDS)
end

local function ensureLedger(profile, now: number)
	TradeOfferMath.EnsureLedger(profile, now)
end

local function itemEquipped(profile, uid: string): boolean
	return TradeOfferMath.ItemEquipped(profile, uid)
end

local function countInventory(profile): number
	return TradeOfferMath.CountInventory(profile)
end

local function boostTotal(offer): number
	return TradeOfferMath.BoostTotal(offer, BOOST_IDS)
end

local function keyTotal(offer): number
	return TradeOfferMath.KeyTotal(offer, KEY_IDS)
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
	return true
end

function TradeDesk:Public(session, userId: number)
	if not session then
		return nil
	end
	local them = if session.Host == userId then session.Guest else session.Host
	local themPlayer = Players:GetPlayerByUserId(them)
	local partnerName = if them == -999 then "Forge Automaton [Practice]" else (themPlayer and themPlayer.DisplayName or "Forge partner")
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
		Chat = table.clone(session.Chat or {}),
		YourRequest = session.Requests and session.Requests[userId] or nil,
		TheirRequest = session.Requests and session.Requests[them] or nil,
		PartnerRelics = self:_tradeableRelics(them),
		PartnerAway = session.Away and session.Away[them] == true or false,
	}
end

-- the relics a player could put on the table (not locked, not equipped), for the partner to browse
function TradeDesk:_tradeableRelics(userId: number)
	local profileOf = self.ProfileOf
	local profile = profileOf and profileOf(userId)
	local inventory = profile and profile.Items and profile.Items.Inventory
	local list = {}
	if type(inventory) ~= "table" then
		return list
	end
	local rarityOf = {}
	for _, definition in (GameConfig.Items and GameConfig.Items.Definitions) or {} do
		if type(definition) == "table" and definition.Id then
			rarityOf[definition.Id] = definition.Rarity
		end
	end
	for uid, instance in inventory do
		if type(instance) == "table" and instance.Locked ~= true and not itemEquipped(profile, uid) then
			table.insert(list, {
				Uid = uid,
				DefinitionId = instance.DefinitionId,
				Name = itemNameFor(tostring(instance.DefinitionId or "")),
				Rarity = rarityOf[instance.DefinitionId] or "Common",
				Level = tonumber(instance.Level) or 1,
			})
		end
		if #list >= 60 then
			break
		end
	end
	table.sort(list, function(a, b)
		return a.Uid < b.Uid
	end)
	return list
end

-- quick phrases anyone can send without typing (never filtered, never misread)
TradeDesk.PHRASES = {
	"Deal?", "Can you add a little more?", "That's fair.", "Not for that.",
	"Let me look.", "Ready when you are.", "Thanks for the trade.", "One sec.",
}

-- a line of table talk: `text` arrives already filtered by the caller; `phrase` is an index
function TradeDesk:Say(player: Player, text: string?, phrase: number?, now: number): (boolean, string?, any)
	local session = self:SessionFor(player.UserId)
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	session.LastSay = session.LastSay or {}
	local clock = os.clock()
	if not TradeChatMath.CanSend(session.LastSay[player.UserId], clock) then
		return false, "Slow down a little."
	end
	local line
	if type(phrase) == "number" and TradeDesk.PHRASES[phrase] then
		line = TradeDesk.PHRASES[phrase]
	elseif type(text) == "string" and #text > 0 then
		line = string.sub(text, 1, 140)
	else
		return false, "Say something first."
	end
	session.LastSay[player.UserId] = clock
	session.Chat = session.Chat or {}
	table.insert(session.Chat, { From = player.UserId, Name = player.DisplayName, Text = line, At = now, Phrase = phrase ~= nil })
	while #session.Chat > 40 do
		table.remove(session.Chat, 1)
	end
	return true, nil, session
end

-- what you'd like from your partner: some of their relics and some amounts; they can add it in one tap
function TradeDesk:Request(player: Player, raw, now: number): (boolean, string?, any)
	local session = self:SessionFor(player.UserId)
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	if session.Settling == true or session.Status == "Settling" then
		return false, "That trade is already settling."
	end
	local caps = GameConfig.Trading.PerTrade
	local request = TradeRequestMath.Normalize(raw, caps, CURRENCIES)
	session.Requests = session.Requests or {}
	session.Requests[player.UserId] = request
	return true, nil, session
end

function TradeDesk:SetAway(player: Player, away: boolean)
	local session = self:SessionFor(player.UserId)
	if not session then
		return nil
	end
	session.Away = session.Away or {}
	session.Away[player.UserId] = away == true
	return session
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

function TradeDesk.LockedPublic()
	return { Unlocked = false, Epoch = 0 }
end

function TradeDesk:StatePublic(profile, player: Player, now: number)
	local ok, result = pcall(function()
		return {
			Unlocked = self:Unlocked(profile),
			Epoch = self:Epoch(),
			Session = self:Public(self:SessionFor(player.UserId), player.UserId),
			Invite = self:InvitePublic(player.UserId),
			Outgoing = self:OutgoingPublic(player.UserId),
			Daily = self:DailyPublic(profile, now),
			History = TradeHistory.public(profile.Trade),
		}
	end)
	if not ok then
		pcall(function()
			local ModuleLog = require(ReplicatedStorage:WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("ModuleLog"))
			ModuleLog.Warn("TradeDesk", string.format("StatePublic error for u=%s: %s", tostring(player and player.UserId), tostring(result)))
		end)
		return {
			Unlocked = self:Unlocked(profile),
			Epoch = self:Epoch(),
			Session = nil,
			Invite = nil,
			Outgoing = nil,
			Daily = {
				Completed = profile.Trade and profile.Trade.Completed or 0,
				Limit = GameConfig.Trading.DailyTrades,
				Sent = { Cash = 0, Stardust = 0, Cores = 0, Signals = 0, Essence = 0, Boost = 0, Keys = 0, Items = 0 },
				Caps = GameConfig.Trading.Daily,
				PerTrade = GameConfig.Trading.PerTrade,
			},
			History = {},
		}
	end
	return result
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
	if targetUserId == -999 then
		local session = {
			Id = self:_sessionId(),
			Host = fromPlayer.UserId,
			Guest = -999,
			Offers = {
				[fromPlayer.UserId] = emptyOffer(),
				[-999] = emptyOffer(),
			},
			Ready = { [fromPlayer.UserId] = false, [-999] = false },
			Confirmed = { [fromPlayer.UserId] = false, [-999] = false },
			ConfirmEndsAt = 0,
			Settling = false,
			Status = "Open",
			ExpiresAt = now + GameConfig.Trading.SessionSeconds,
		}
		self._sessions[session.Id] = session
		self._byUser[fromPlayer.UserId] = session.Id
		self._byUser[-999] = session.Id
		self:_bump()
		return true, nil
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
		Settling = false,
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
	local session = self:SessionFor(player.UserId)
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	if session.Settling == true or session.Status == "Settling" then
		return false, "That trade is already settling."
	end
	if session.Status == "RevertFailed" then
		return false, "This trade hit an error and has to be cancelled."
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
	local session = self:SessionFor(player.UserId)
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	if session.Settling == true or session.Status == "Settling" or session.Status == "RevertFailed" then
		return false, "That trade is already settling."
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
	if session.Guest == -999 or session.Host == -999 then
		local partnerId = if session.Host == player.UserId then session.Guest else session.Host
		if ready and offerEmpty(session.Offers[partnerId]) then
			session.Offers[partnerId].Stardust = 10
		end
		session.Ready[partnerId] = ready == true
	end
	session.Confirmed[session.Host] = false
	session.Confirmed[session.Guest] = false
	session.ConfirmEndsAt = 0
	session.Status = "Open"
	return true, nil, session
end

function TradeDesk:Confirm(player: Player, now: number): (boolean, string?, any)
	local session = self:SessionFor(player.UserId)
	if not session or session.ExpiresAt < now then
		return false, "That trade is no longer open."
	end
	if session.Settling == true or session.Status == "Settling" or session.Status == "RevertFailed" then
		return false, "That trade is already settling."
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
	if session.Guest == -999 or session.Host == -999 then
		local partnerId = if session.Host == player.UserId then session.Guest else session.Host
		session.Confirmed[partnerId] = true
	end
	return true, nil, session
end

function TradeDesk:TryBeginSettle(session): boolean
	return TradeSettle.TryBegin(session)
end

function TradeDesk:FailSettle(session, permanent: boolean?, reason: string?)
	TradeSettle.Fail(session, permanent, reason)
end

function TradeDesk:Cancel(player: Player): (any, number?, string?)
	local session = self:SessionFor(player.UserId)
	if not session then
		self._invites[player.UserId] = nil
		return nil, nil, nil
	end
	local blocked, blockReason = TradeSettle.CancelBlocked(session)
	if blocked then
		return session, nil, blockReason
	end
	local other = if session.Host == player.UserId then session.Guest else session.Host
	self:Close(session)
	return session, other, nil
end

function TradeDesk:Plan(session, hostProfile, guestProfile, now: number): (any?, string?)
	if session.Confirmed[session.Host] ~= true or session.Confirmed[session.Guest] ~= true then
		return nil, "Waiting for both confirmations."
	end
	if session.ConfirmEndsAt > 0 and now > session.ConfirmEndsAt then
		return nil, "The confirm window expired. Ready up again."
	end
	ensureLedger(hostProfile, now)
	ensureLedger(guestProfile, now)
	if hostProfile.Trade.Completed >= GameConfig.Trading.DailyTrades or guestProfile.Trade.Completed >= GameConfig.Trading.DailyTrades then
		return nil, "A daily trade limit has been reached."
	end
	local hostOffer = copyOffer(session.Offers[session.Host])
	local guestOffer = copyOffer(session.Offers[session.Guest])
	local hostReason = self:_validateOffer(hostProfile, hostOffer, now)
	if hostReason then
		return nil, hostReason
	end
	local guestReason = self:_validateOffer(guestProfile, guestOffer, now)
	if guestReason then
		return nil, guestReason
	end
	local hostIncoming = #guestOffer.ItemIds
	local guestIncoming = #hostOffer.ItemIds
	local hostLimit = GameConfig.Items.InventoryLimit
	local guestLimit = GameConfig.Items.InventoryLimit
	if countInventory(hostProfile) - #hostOffer.ItemIds + hostIncoming > hostLimit then
		return nil, "Their inventory cannot hold those relics."
	end
	if countInventory(guestProfile) - #guestOffer.ItemIds + guestIncoming > guestLimit then
		return nil, "Your inventory cannot hold those relics."
	end
	return {
		HostOffer = hostOffer,
		GuestOffer = guestOffer,
		HostItems = TradeExchange.SnapshotOfferItems(hostOffer, hostProfile),
		GuestItems = TradeExchange.SnapshotOfferItems(guestOffer, guestProfile),
		Now = now,
	}, nil
end

function TradeDesk:ApplyExchange(profile, give, take, giveItems, takeItems, now: number): string?
	return TradeExchange.ApplyExchange(GameConfig, OmegaMath, profile, give, take, giveItems, takeItems, now, function(p, offer, at)
		return self:_validateOffer(p, offer, at)
	end)
end

function TradeDesk:RevertExchange(profile, give, take, giveItems, takeItems, now: number)
	TradeExchange.RevertExchange(OmegaMath, profile, give, take, giveItems, takeItems, now)
end

function TradeDesk:Close(session)
	if not session then
		return
	end
	self._sessions[session.Id] = nil
	self._byUser[session.Host] = nil
	self._byUser[session.Guest] = nil
	self:_bump()
end

function TradeDesk:SessionFor(userId: number)
	local id = self._byUser[userId]
	return id and self._sessions[id] or nil
end

return TradeDesk
end

__defs["TradeExchange"] = function()

local TradeExchange = {}

local CURRENCIES = { "Cash", "Stardust", "Cores", "Signals", "Essence" }
local BOOST_IDS = {
	"DomainSurge", "Overdrive", "Hyperdrive", "VaultSurge", "NightShift", "FoundryRush",
	"Afterburner", "SteadyBurn", "CoreSurge", "StarforgeFlow", "EchoDrive", "Ionstorm", "TwinCatalyst", "MidnightForge",
}
local KEY_IDS = { "ForgeCrate", "CrystalCrate", "HorizonCrate", "NebulaCrate", "OrbitCrate", "SingularityCrate", "EchoCrate" }

TradeExchange.CURRENCIES = CURRENCIES
TradeExchange.BOOST_IDS = BOOST_IDS
TradeExchange.KEY_IDS = KEY_IDS

local function utcDay(now: number): number
	local date = os.date("!*t", now)
	return date.year * 1000 + date.yday
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

local function ensureTradeBags(profile)
	profile.Command = type(profile.Command) == "table" and profile.Command or {}
	profile.Items = type(profile.Items) == "table" and profile.Items or { Inventory = {}, Keys = {}, Essence = 0 }
	profile.Items.Inventory = type(profile.Items.Inventory) == "table" and profile.Items.Inventory or {}
	profile.Items.Keys = type(profile.Items.Keys) == "table" and profile.Items.Keys or {}
	profile.BoostInventory = type(profile.BoostInventory) == "table" and profile.BoostInventory or {}
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

function TradeExchange.CopyItemInstance(instance)
	if type(instance) ~= "table" then
		return nil
	end
	local copy = {}
	for key, value in instance do
		if type(value) == "table" then
			local nested = {}
			for nestedKey, nestedValue in value do
				nested[nestedKey] = nestedValue
			end
			copy[key] = nested
		else
			copy[key] = value
		end
	end
	return copy
end

function TradeExchange.SnapshotOfferItems(offer, profile)
	local payloads = {}
	local inventory = profile and profile.Items and profile.Items.Inventory
	if type(inventory) ~= "table" then
		return payloads
	end
	for _, uid in offer.ItemIds do
		local instance = inventory[uid]
		if type(instance) == "table" then
			payloads[uid] = TradeExchange.CopyItemInstance(instance)
		end
	end
	return payloads
end

local function mintItemUid(profile): string
	profile.Items.NextId = (tonumber(profile.Items.NextId) or 0) + 1
	return string.format("IT%07d", profile.Items.NextId)
end

function TradeExchange.ApplyExchange(gameConfig, omegaMath, profile, give, take, giveItems, takeItems, now: number, validateOffer): string?
	ensureLedger(profile, now)
	ensureTradeBags(profile)
	if validateOffer then
		local reason = validateOffer(profile, give, now)
		if reason then
			return reason
		end
	end
	local incomingCount = 0
	if type(take) == "table" and type(take.ItemIds) == "table" then
		incomingCount = #take.ItemIds
	end
	if countInventory(profile) - #give.ItemIds + incomingCount > gameConfig.Items.InventoryLimit then
		return "Inventory cannot hold those relics."
	end

	profile.Cash = omegaMath.Sub(profile.Cash, give.Cash)
	profile.Cash = omegaMath.Add(profile.Cash, take.Cash)
	profile.Stardust = math.max(0, (tonumber(profile.Stardust) or 0) - give.Stardust) + take.Stardust
	profile.Cores = math.max(0, (tonumber(profile.Cores) or 0) - give.Cores) + take.Cores
	profile.Command.Signals = math.max(0, (tonumber(profile.Command.Signals) or 0) - give.Signals) + take.Signals
	profile.Items.Essence = math.max(0, (tonumber(profile.Items.Essence) or 0) - give.Essence) + take.Essence

	for _, id in BOOST_IDS do
		local giveAmount = give.Boosts[id]
		local takeAmount = take.Boosts[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.BoostInventory[id] = math.max(0, (tonumber(profile.BoostInventory[id]) or 0) - giveAmount) + takeAmount
		end
	end
	for _, id in KEY_IDS do
		local giveAmount = give.Keys[id]
		local takeAmount = take.Keys[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.Items.Keys[id] = math.max(0, (tonumber(profile.Items.Keys[id]) or 0) - giveAmount) + takeAmount
		end
	end
	for _, uid in give.ItemIds do
		profile.Items.Inventory[uid] = nil
	end
	if type(take.ItemIds) == "table" then
		for _, uid in take.ItemIds do
			local payload = takeItems and takeItems[uid]
			if payload ~= nil then
				-- Receiver UIDs are per-profile monotonic sequences; re-key incoming
				-- items so a sender's UID can never overwrite a different relic here.
				local newUid = mintItemUid(profile)
				payload.NewUid = newUid
				profile.Items.Inventory[newUid] = TradeExchange.CopyItemInstance(payload)
			end
		end
	end

	profile.Trade.Sent.Cash += give.Cash
	profile.Trade.Sent.Stardust += give.Stardust
	profile.Trade.Sent.Cores += give.Cores
	profile.Trade.Sent.Signals += give.Signals
	profile.Trade.Sent.Essence += give.Essence
	profile.Trade.Sent.Boost += boostTotal(give)
	profile.Trade.Sent.Keys += keyTotal(give)
	profile.Trade.Sent.Items += #give.ItemIds
	profile.Trade.Completed += 1
	return nil
end

function TradeExchange.RevertExchange(omegaMath, profile, give, take, giveItems, takeItems, now: number)
	ensureLedger(profile, now)
	ensureTradeBags(profile)

	profile.Cash = omegaMath.Add(profile.Cash, give.Cash)
	profile.Cash = omegaMath.Sub(profile.Cash, take.Cash)
	profile.Stardust = math.max(0, (tonumber(profile.Stardust) or 0) + give.Stardust - take.Stardust)
	profile.Cores = math.max(0, (tonumber(profile.Cores) or 0) + give.Cores - take.Cores)
	profile.Command.Signals = math.max(0, (tonumber(profile.Command.Signals) or 0) + give.Signals - take.Signals)
	profile.Items.Essence = math.max(0, (tonumber(profile.Items.Essence) or 0) + give.Essence - take.Essence)

	for _, id in BOOST_IDS do
		local giveAmount = give.Boosts[id]
		local takeAmount = take.Boosts[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.BoostInventory[id] = math.max(0, (tonumber(profile.BoostInventory[id]) or 0) + giveAmount - takeAmount)
		end
	end
	for _, id in KEY_IDS do
		local giveAmount = give.Keys[id]
		local takeAmount = take.Keys[id]
		if giveAmount > 0 or takeAmount > 0 then
			profile.Items.Keys[id] = math.max(0, (tonumber(profile.Items.Keys[id]) or 0) + giveAmount - takeAmount)
		end
	end
	if type(take.ItemIds) == "table" then
		for _, uid in take.ItemIds do
			local payload = takeItems and takeItems[uid]
			local removeUid = (type(payload) == "table" and payload.NewUid) or uid
			profile.Items.Inventory[removeUid] = nil
		end
	end
	for _, uid in give.ItemIds do
		local payload = giveItems and giveItems[uid]
		if payload ~= nil then
			profile.Items.Inventory[uid] = TradeExchange.CopyItemInstance(payload)
		end
	end

	profile.Trade.Sent.Cash = math.max(0, (profile.Trade.Sent.Cash or 0) - give.Cash)
	profile.Trade.Sent.Stardust = math.max(0, (profile.Trade.Sent.Stardust or 0) - give.Stardust)
	profile.Trade.Sent.Cores = math.max(0, (profile.Trade.Sent.Cores or 0) - give.Cores)
	profile.Trade.Sent.Signals = math.max(0, (profile.Trade.Sent.Signals or 0) - give.Signals)
	profile.Trade.Sent.Essence = math.max(0, (profile.Trade.Sent.Essence or 0) - give.Essence)
	profile.Trade.Sent.Boost = math.max(0, (profile.Trade.Sent.Boost or 0) - boostTotal(give))
	profile.Trade.Sent.Keys = math.max(0, (profile.Trade.Sent.Keys or 0) - keyTotal(give))
	profile.Trade.Sent.Items = math.max(0, (profile.Trade.Sent.Items or 0) - #give.ItemIds)
	profile.Trade.Completed = math.max(0, (profile.Trade.Completed or 0) - 1)
end

return table.freeze(TradeExchange)
end

__defs["TradeOfferMath"] = function()

local TradeOfferMath = {}

type OfferBag = {
	Cash: number,
	Stardust: number,
	Cores: number,
	Signals: number,
	Essence: number,
	Boosts: { [string]: number },
	Keys: { [string]: number },
	ItemIds: { string },
	Items: { any }?,
}

local function utcDay(now: number): number
	local date = os.date("!*t", now)
	return date.year * 1000 + date.yday
end

function TradeOfferMath.EmptyOffer(boostIds: { string }, keyIds: { string }): OfferBag
	local boosts: { [string]: number } = {}
	for _, id in boostIds do
		boosts[id] = 0
	end
	local keys: { [string]: number } = {}
	for _, id in keyIds do
		keys[id] = 0
	end
	return {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boosts = boosts,
		Keys = keys,
		ItemIds = {},
	}
end

function TradeOfferMath.CopyOffer(
	offer: any,
	currencies: { string },
	boostIds: { string },
	keyIds: { string }
): OfferBag
	local nextOffer = TradeOfferMath.EmptyOffer(boostIds, keyIds)
	if type(offer) ~= "table" then
		return nextOffer
	end
	for _, key in currencies do
		nextOffer[key] = math.max(0, math.floor(tonumber(offer[key]) or 0))
	end
	if type(offer.Boosts) == "table" then
		for _, id in boostIds do
			nextOffer.Boosts[id] = math.max(0, math.floor(tonumber(offer.Boosts[id]) or 0))
		end
	end
	if type(offer.Keys) == "table" then
		for _, id in keyIds do
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

function TradeOfferMath.OfferEmpty(offer: any, currencies: { string }, boostIds: { string }, keyIds: { string }): boolean
	if type(offer) ~= "table" then
		return true
	end
	for _, key in currencies do
		if (tonumber(offer[key]) or 0) > 0 then
			return false
		end
	end
	local boosts = offer.Boosts
	if type(boosts) == "table" then
		for _, id in boostIds do
			if (tonumber(boosts[id]) or 0) > 0 then
				return false
			end
		end
	end
	local keys = offer.Keys
	if type(keys) == "table" then
		for _, id in keyIds do
			if (tonumber(keys[id]) or 0) > 0 then
				return false
			end
		end
	end
	local itemIds = offer.ItemIds
	return type(itemIds) ~= "table" or #itemIds == 0
end

function TradeOfferMath.BoostTotal(offer: any, boostIds: { string }): number
	local total = 0
	if type(offer) ~= "table" or type(offer.Boosts) ~= "table" then
		return 0
	end
	for _, id in boostIds do
		total += math.max(0, math.floor(tonumber(offer.Boosts[id]) or 0))
	end
	return total
end

function TradeOfferMath.KeyTotal(offer: any, keyIds: { string }): number
	local total = 0
	if type(offer) ~= "table" or type(offer.Keys) ~= "table" then
		return 0
	end
	for _, id in keyIds do
		total += math.max(0, math.floor(tonumber(offer.Keys[id]) or 0))
	end
	return total
end

function TradeOfferMath.EnsureLedger(profile: any, now: number)
	if type(profile) ~= "table" then
		return
	end
	if type(profile.Trade) ~= "table" then
		profile.Trade = { Day = -1, Completed = 0, Sent = {} }
	end
	local day = utcDay(now)
	local emptySent = {
		Cash = 0,
		Stardust = 0,
		Cores = 0,
		Signals = 0,
		Essence = 0,
		Boost = 0,
		Keys = 0,
		Items = 0,
	}
	if profile.Trade.Day ~= day then
		profile.Trade.Day = day
		profile.Trade.Completed = 0
		profile.Trade.Sent = emptySent
	end
	if type(profile.Trade.Sent) ~= "table" then
		profile.Trade.Sent = emptySent
	end
end

function TradeOfferMath.ItemEquipped(profile: any, uid: string): boolean
	if type(uid) ~= "string" or uid == "" then
		return false
	end
	if type(profile) ~= "table" or type(profile.Items) ~= "table" or type(profile.Items.Equipped) ~= "table" then
		return false
	end
	for _, equipped in profile.Items.Equipped do
		if equipped == uid then
			return true
		end
	end
	return false
end

function TradeOfferMath.CountInventory(profile: any): number
	local count = 0
	if type(profile) == "table" and profile.Items and type(profile.Items.Inventory) == "table" then
		for _ in profile.Items.Inventory do
			count += 1
		end
	end
	return count
end

return table.freeze(TradeOfferMath)
end

__defs["TradeSettle"] = function()

local TradeSettle = {}

TradeSettle.REVERT_ATTEMPTS = 3
TradeSettle.ADMIN_NOTE = "Trade settle recovery"
TradeSettle.REASON_GUEST_LEFT = "guest-left-during-settle"
TradeSettle.REASON_GUEST_APPLY = "guest-apply-failed"
TradeSettle.REASON_HOST_REVERT = "host-revert-failed"
TradeSettle.KIND_COMPLETE = "complete"
TradeSettle.KIND_HOST_FAILED = "host-failed"
TradeSettle.KIND_GUEST_LEFT = "guest-left"
TradeSettle.KIND_GUEST_FAILED = "guest-failed"

function TradeSettle.TryBegin(session): boolean
	if not session then
		return false
	end
	if session.Settling == true or session.Status == "Settling" or session.Status == "RevertFailed" then
		return false
	end
	if session.Confirmed[session.Host] ~= true or session.Confirmed[session.Guest] ~= true then
		return false
	end
	session.Settling = true
	session.Status = "Settling"
	return true
end

function TradeSettle.Fail(session, permanent: boolean?, reason: string?)
	if not session then
		return
	end
	session.Settling = false
	session.Confirmed[session.Host] = false
	session.Confirmed[session.Guest] = false
	session.ConfirmEndsAt = 0
	if permanent then
		session.Status = "RevertFailed"
		session.RevertFailedAt = os.time()
		session.RevertFailedReason = if type(reason) == "string" and reason ~= ""
			then reason
			else TradeSettle.REASON_HOST_REVERT
	else
		session.Status = "Open"
		session.RevertFailedAt = nil
		session.RevertFailedReason = nil
	end
end

function TradeSettle.CancelBlocked(session): (boolean, string?)
	if not session then
		return false, nil
	end
	if session.Settling == true or session.Status == "Settling" then
		return true, "That trade is already settling."
	end
	return false, nil
end

function TradeSettle.RevertWithRetries(attempts: number?, tryOnce: () -> boolean): boolean
	local limit = math.max(1, math.floor(tonumber(attempts) or TradeSettle.REVERT_ATTEMPTS))
	for _ = 1, limit do
		if tryOnce() then
			return true
		end
	end
	return false
end

function TradeSettle.GuestLeftMessage(reverted: boolean): string
	if reverted then
		return "Your partner left before the trade finished. Your items were returned."
	end
	return "Guest left and host revert failed. Cancel and contact support."
end

function TradeSettle.GuestApplyMessage(reverted: boolean, applyError: string?): string
	if not reverted then
		return "Guest side failed and host revert did not commit. Cancel the table and contact support."
	end
	if type(applyError) == "string" and applyError ~= "" then
		return applyError
	end
	return "Guest side of the trade failed."
end

function TradeSettle.FormatRevertFailedLog(sessionId: any, hostId: number, guestId: number, reason: string): string
	return string.format(
		"RevertFailed session=%s host=%d guest=%d reason=%s — cancel table; admin note: %s",
		tostring(sessionId),
		hostId,
		guestId,
		reason,
		TradeSettle.ADMIN_NOTE
	)
end

function TradeSettle.IsCommitOk(committed: boolean?, result: any): boolean
	return committed == true and type(result) == "table" and result.ok == true
end

function TradeSettle.CommitError(result: any): string?
	if type(result) == "table" and type(result.error) == "string" and result.error ~= "" then
		return result.error
	end
	return nil
end

function TradeSettle.RunHostGuest(session, hooks: any): any
	assert(type(hooks) == "table", "RunHostGuest requires hooks")
	assert(type(hooks.applyHost) == "function", "hooks.applyHost required")
	assert(type(hooks.guestPresent) == "function", "hooks.guestPresent required")
	assert(type(hooks.applyGuest) == "function", "hooks.applyGuest required")
	assert(type(hooks.revertHostOnce) == "function", "hooks.revertHostOnce required")

	-- Optional per-profile journal hooks for durable trade settlement.
	local writeHostJournal = hooks.writeHostJournal
	local writeGuestJournal = hooks.writeGuestJournal
	local plan = hooks.plan

	local function safeHostJournal(status: string, reason: string?)
		if type(writeHostJournal) ~= "function" then return end
		pcall(writeHostJournal, status, reason)
	end
	local function safeGuestJournal(status: string, reason: string?)
		if type(writeGuestJournal) ~= "function" then return end
		pcall(writeGuestJournal, status, reason)
	end

	-- Record intent on both profiles before any mutation commits.
	safeHostJournal("pending")
	safeGuestJournal("pending")

	local hostCommitted, hostResult = hooks.applyHost()
	if not TradeSettle.IsCommitOk(hostCommitted, hostResult) then
		safeHostJournal("aborted", TradeSettle.CommitError(hostResult) or "host-apply-failed")
		safeGuestJournal("aborted")
		TradeSettle.Fail(session, false)
		return {
			ok = false,
			kind = TradeSettle.KIND_HOST_FAILED,
			message = TradeSettle.CommitError(hostResult) or "Host side of the trade failed.",
			permanent = false,
		}
	end

	-- Host side is now committed; mark it locked/escrow before attempting guest commit.
	-- This in-memory flag and the journal status let recovery know the host side
	-- may need to be reverted if the guest side cannot complete.
	session.HostCommitted = true
	safeHostJournal("locked")

	if not hooks.guestPresent() then
		safeGuestJournal("aborted", "guest-absent")
		local reverted = TradeSettle.RevertWithRetries(TradeSettle.REVERT_ATTEMPTS, hooks.revertHostOnce)
		if reverted then
			safeHostJournal("reverted", TradeSettle.REASON_GUEST_LEFT)
		end
		TradeSettle.Fail(session, not reverted, TradeSettle.REASON_GUEST_LEFT)
		local outcome: any = {
			ok = false,
			kind = TradeSettle.KIND_GUEST_LEFT,
			message = TradeSettle.GuestLeftMessage(reverted),
			permanent = not reverted,
			reason = TradeSettle.REASON_GUEST_LEFT,
		}
		if not reverted then
			outcome.log = TradeSettle.FormatRevertFailedLog(
				session.Id,
				session.Host,
				session.Guest,
				TradeSettle.REASON_GUEST_LEFT
			)
			-- Never silently fault: stamp a durable faulted journal entry.
			safeHostJournal("faulted", TradeSettle.REASON_GUEST_LEFT)
			safeGuestJournal("faulted", TradeSettle.REASON_GUEST_LEFT)
		end
		return outcome
	end

	local guestCommitted, guestResult = hooks.applyGuest()
	if not TradeSettle.IsCommitOk(guestCommitted, guestResult) then
		local reverted = TradeSettle.RevertWithRetries(TradeSettle.REVERT_ATTEMPTS, hooks.revertHostOnce)
		if reverted then
			safeHostJournal("reverted", TradeSettle.REASON_GUEST_APPLY)
		end
		TradeSettle.Fail(session, not reverted, TradeSettle.REASON_GUEST_APPLY)
		local outcome: any = {
			ok = false,
			kind = TradeSettle.KIND_GUEST_FAILED,
			message = TradeSettle.GuestApplyMessage(reverted, TradeSettle.CommitError(guestResult)),
			permanent = not reverted,
			reason = TradeSettle.REASON_GUEST_APPLY,
		}
		if not reverted then
			outcome.log = TradeSettle.FormatRevertFailedLog(
				session.Id,
				session.Host,
				session.Guest,
				TradeSettle.REASON_GUEST_APPLY
			)
			-- Never silently fault: stamp a durable faulted journal entry.
			safeHostJournal("faulted", TradeSettle.REASON_GUEST_APPLY)
			safeGuestJournal("faulted", TradeSettle.REASON_GUEST_APPLY)
		end
		return outcome
	end

	safeHostJournal("settled")
	safeGuestJournal("settled")
	return {
		ok = true,
		kind = TradeSettle.KIND_COMPLETE,
		permanent = false,
	}
end

return table.freeze(TradeSettle)
end

__defs["TradeRecovery"] = function()

local TradeRecovery = {}

local TradeExchange = __load("TradeExchange")

local function safeRequireOmegaMath(): any
	local ok, OmegaMath = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("AstralForge"):WaitForChild("Shared"):WaitForChild("OmegaMath"))
	end)
	if ok then return OmegaMath end
	return nil
end

local function ensureTradeJournal(profile)
	if type(profile.Trade) ~= "table" then
		profile.Trade = { Day = -1, Completed = 0, Sent = {}, Journal = {}, FaultedJournal = nil }
	end
	if type(profile.Trade.Journal) ~= "table" then
		profile.Trade.Journal = {}
	end
end

-- Build a serializable record of a faulted trade for later reconciliation.
function TradeRecovery.MakeFaultedEntry(session, side: string, plan: any, reason: string, now: number): any
	local entry: any = {
		SessionId = session.Id,
		Side = side,
		Host = session.Host,
		Guest = session.Guest,
		Status = "faulted",
		Reason = reason,
		At = now,
		HostCommitted = session.HostCommitted == true,
		GuestCommitted = session.GuestCommitted == true,
		HostReverted = false,
		GuestReverted = false,
	}
	if side == "host" and type(plan) == "table" then
		entry.Give = plan.HostOffer
		entry.Take = plan.GuestOffer
		entry.GiveItems = plan.HostItems
		entry.TakeItems = plan.GuestItems
	elseif side == "guest" and type(plan) == "table" then
		entry.Give = plan.GuestOffer
		entry.Take = plan.HostOffer
		entry.GiveItems = plan.GuestItems
		entry.TakeItems = plan.HostItems
	end
	return entry
end

-- Reconcile a faulted trade journal against a freshly loaded profile.
-- Only touches the local profile; each side recovers independently on load.
function TradeRecovery.RecoverFaulted(profile, now: number, log: ((string) -> ())?)
	ensureTradeJournal(profile)
	local entry = profile.Trade.FaultedJournal
	if type(entry) ~= "table" or entry.Status ~= "faulted" then
		profile.Trade.FaultedJournal = nil
		return
	end

	local OmegaMath = safeRequireOmegaMath()
	if not OmegaMath then
		-- OmegaMath is not available outside runtime; leave the entry for manual review.
		return
	end

	local side = entry.Side
	local committed = side == "host" and entry.HostCommitted or entry.GuestCommitted
	local reverted = side == "host" and entry.HostReverted or entry.GuestReverted
	if committed and not reverted and type(entry.Give) == "table" and type(entry.Take) == "table" then
		TradeExchange.RevertExchange(OmegaMath, profile, entry.Give, entry.Take, entry.GiveItems, entry.TakeItems, now)
		if side == "host" then
			entry.HostReverted = true
		else
			entry.GuestReverted = true
		end
		entry.RecoveredAt = now
		entry.Status = "recovered"
		if type(log) == "function" then
			log(string.format(
				"Recovered faulted trade session=%s side=%s host=%d guest=%d reason=%s",
				tostring(entry.SessionId),
				tostring(side),
				tonumber(entry.Host) or 0,
				tonumber(entry.Guest) or 0,
				tostring(entry.Reason)
			))
		end
	end
	profile.Trade.FaultedJournal = nil
end

return table.freeze(TradeRecovery)
end

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
		if name == "__members" then
			return __members
		end
		return __load(name)
	end,
})
