--!nocheck
-- Limited events: the calendar is well formed and sells real things, tokens respect the daily cap,
-- the stall checks stock and price, an ended event's leftovers become Stardust once, and the
-- LimitedEventsPaused flag keeps tokens untouched. Run `npx rbxtsc` first.
local H = require("./_server_harness")

local failures = {}
local checks = 0
local function check(cond, label)
	checks += 1
	if not cond then table.insert(failures, label) end
end

H.mock("Server/AstralForge/Runtime/ServerNetwork", { ServerEvents = H.Stub, ServerFunctions = H.Stub })
H.env.Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local LimitedEvents = H.load("Shared/AstralForge/Shared/LimitedEvents")
local GameConfig = H.load("Shared/AstralForge/Shared/GameConfig")
local HotFlags = H.load("Server/AstralForge/Services/Security/HotFlags")
local GS = H.load("Server/AstralForge/Services/GameService").GameService
local DataTemplate = H.load("Server/AstralForge/DataTemplate")

-- --- the calendar ---------------------------------------------------------------
local crates = {}
for _, crate in GameConfig.Items.Crates do crates[crate.Id] = true end
local boosts = {}
for id in GameConfig.Boosts or {} do boosts[id] = true end
for _, boost in (GameConfig.Boosts or {}) do if type(boost) == "table" and boost.Id then boosts[boost.Id] = true end end
local previousEnd = 0
local ids = {}
for _, event in LimitedEvents.EVENTS do
	check(not ids[event.Id], "event ids are unique: " .. event.Id)
	ids[event.Id] = true
	check(event.EndsAt > event.StartsAt, event.Id .. " ends after it starts")
	check(event.StartsAt >= previousEnd, event.Id .. " doesn't overlap the one before")
	previousEnd = event.EndsAt
	check(event.DailyCap > 0 and #event.Shop > 0, event.Id .. " pays and sells")
	local items = {}
	for _, item in event.Shop do
		check(not items[item.Id], event.Id .. " shop ids are unique")
		items[item.Id] = true
		check(item.Price > 0 and item.Stock > 0, event.Id .. "/" .. item.Id .. " has a price and stock")
		for crate in item.Reward.Keys or {} do
			check(crates[crate], event.Id .. "/" .. item.Id .. " sells keys for a real crate: " .. crate)
		end
		if item.Reward.Boost then
			check(next(boosts) == nil or boosts[item.Reward.Boost], event.Id .. "/" .. item.Id .. " sells a real boost")
		end
	end
	-- the whole stall should be buyable with a fortnight at the cap, not with a weekend
	local total = 0
	for _, item in event.Shop do total += item.Price * item.Stock end
	local days = (event.EndsAt - event.StartsAt) / 86400
	check(total <= event.DailyCap * days, event.Id .. " stall can be cleared at the daily cap")
	check(total > event.DailyCap * 3, event.Id .. " stall takes more than a few days")
	check(LimitedEvents.activeAt(event.StartsAt) == event and LimitedEvents.activeAt(event.EndsAt) ~= event, event.Id .. " window edges")
end
local first = LimitedEvents.EVENTS[1]
check(LimitedEvents.nextAfter(first.StartsAt - 1) == first, "the next event is found")
check(LimitedEvents.activeAt(first.StartsAt - 1) == nil, "nothing runs before the first event")

-- --- the bag ------------------------------------------------------------------------
local now = first.StartsAt + 3600
local profile = { LimitedEvent = { Id = "", Tokens = 0, Earned = 0, Day = -1, DayEarned = 0, Bought = {} } }
local changed, refund = LimitedEvents.ensure(profile, first)
check(changed and refund == 0 and profile.LimitedEvent.Id == first.Id, "joining an event starts a fresh bag")
check(select(1, LimitedEvents.ensure(profile, first)) == false, "a second ensure changes nothing")
check(LimitedEvents.earn(profile, first, 100, now) == 100, "points become tokens")
check(LimitedEvents.earn(profile, first, 10000, now) == first.DailyCap - 100, "the daily cap holds")
check(LimitedEvents.earn(profile, first, 5, now) == 0, "nothing past the cap")
check(LimitedEvents.earn(profile, first, 5, now + 86400) == 5, "the cap resets the next day")
check(profile.LimitedEvent.Tokens == first.DailyCap + 5, "tokens add up")
check(LimitedEvents.earn(profile, first, -50, now) == 0, "negative points do nothing")

local item = first.Shop[1]
local tokens = profile.LimitedEvent.Tokens
local bought, reason = LimitedEvents.buy(profile, first, item.Id)
check(bought == item and reason == nil and profile.LimitedEvent.Tokens == tokens - item.Price, "a buy charges once")
local _, missing = LimitedEvents.buy(profile, first, "nope")
check(missing ~= nil, "unknown items are refused")
profile.LimitedEvent.Tokens = 0
local _, poor = LimitedEvents.buy(profile, first, item.Id)
check(poor ~= nil and string.find(poor, "more", 1, true) ~= nil, "short on tokens says how many")
profile.LimitedEvent.Tokens = 1e6
for _ = 1, item.Stock + 3 do LimitedEvents.buy(profile, first, item.Id) end
check(profile.LimitedEvent.Bought[item.Id] == item.Stock, "stock holds")

profile.LimitedEvent.Tokens = 205
local moved, back = LimitedEvents.ensure(profile, nil)
check(moved and back == math.floor(205 / LimitedEvents.TOKENS_PER_STARDUST), "leftovers turn into Stardust")
check(profile.LimitedEvent.Id == "" and profile.LimitedEvent.Tokens == 0, "the bag is emptied between events")
check(select(2, LimitedEvents.ensure(profile, nil)) == 0, "leftovers are paid once")

local junk = { LimitedEvent = { Id = first.Id, Tokens = "lots", Bought = { [item.Id] = -4, x = 0 / 0 } } }
LimitedEvents.earn(junk, first, 10, now)
check(junk.LimitedEvent.Tokens == 10 and next(junk.LimitedEvent.Bought) == nil, "a damaged bag is read safely")

-- --- GameService ------------------------------------------------------------------------
local function service(p, player)
	local data = { profile = p }
	function data:Update(_, cb)
		local r = cb(self.profile)
		return true, r
	end
	function data:AtomicUpdate(pl, cb) return self:Update(pl, cb) end
	function data:Get() return self.profile end
	local fields = {
		_data = data, _runtime = { [player] = {} }, _running = true,
		_toastPlayer = function() end, _queueStatePush = function() end, _pushState = function() end,
		_syncLeaderstats = function() end, _effect = H.Stub,
		_antiCheat = { Observe = function() return nil, false end },
	}
	return setmetatable(fields, { __index = function(_, k)
		local v = GS[k]
		if v ~= nil then return v end
		return H.Stub
	end }), data
end
local player = H.player("Event shopper")
local runtime = {}
local p = DataTemplate.New()
check(type(p.LimitedEvent) == "table", "the template carries the bag")
p.LimitedEvent = { Id = "OldEvent", Tokens = 400, Earned = 400, Day = 1, DayEarned = 0, Bought = {} }
local s = service(p, player)
HotFlags.Reset()
HotFlags.Set("LimitedEventsPaused", true)
runtime.EventPoints = 50
check(s:_settleEventTokens(player, runtime, p) == false and p.LimitedEvent.Tokens == 400, "paused: tokens are kept as they are")
check(s:_buyEventItem(player, "dust").ok == false, "paused: the stall is closed")
HotFlags.Reset()
local dust = p.Stardust
s:_settleEventTokens(player, runtime, p)
local live = LimitedEvents.activeAt(os.time())
if live == nil then
	check(p.Stardust == dust + 20 and p.LimitedEvent.Id == "", "an ended event pays its leftovers on the next pass")
	check(s:_buyEventItem(player, "dust").ok == false, "no event: the stall is closed")
else
	check(p.LimitedEvent.Id == live.Id, "the bag moves onto the live event")
	p.LimitedEvent.Tokens = 1e5
	check(s:_buyEventItem(player, live.Shop[1].Id).ok == true, "the live stall sells")
end
check(runtime.EventPoints == 0, "queued points are always cleared")

if #failures > 0 then
	error("limited events failed:\n  " .. table.concat(failures, "\n  "))
end
print(string.format("[TEST] limited events: %d checks (calendar, daily cap, stall stock, leftovers, pause flag) passed", checks))
