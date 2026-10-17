--!strict
-- Server events (SharedData#ServerEvents) and their wiring:
--  * the cycle runs Rest -> Warning -> Live -> Results -> Rest and never repeats an event back to back,
--  * Meteor Shower multiplies output only while live,
--  * Community Forge points are fair (seconds of your own output, capped) and the goal scales with players,
--  * Stardust Rain drops scale gently and cap, rankings sort, rewards favour the top three,
--  * the service, GameService hooks and the client UI are all connected.

local luau = require("@lune/luau")
local fs = require("./_memberfs")(require("@lune/fs"))

local Events = luau.load(fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau#ServerEvents"), { chunkName = "ServerEvents" })() :: any

-- Cycle
local state, changed = Events.advance(nil, 0, 0)
assert(changed and state.Phase == "Rest" and state.PhaseEndsAt == Events.FIRST_REST_SECONDS, "a new server rests first, briefly")
local same, moved = Events.advance(state, 10, 0.5)
assert(not moved and same == state, "nothing happens mid-phase")
local t = state.PhaseEndsAt
state = Events.advance(state, t, 0.1)
assert(state.Phase == "Warning" and Events.EVENTS[state.Id] ~= nil, "rest ends in a warning")
local id = state.Id
state = Events.advance(state, state.PhaseEndsAt, 0)
assert(state.Phase == "Live" and state.Id == id and state.PhaseEndsAt - (t + Events.WARNING_SECONDS) == Events.LIVE_SECONDS, "then live")
local mods = Events.EVENTS[id].Mods
assert(Events.productionMultiplier(state) == ((mods and mods.Production) or 1), "only production events boost output")
state = Events.advance(state, state.PhaseEndsAt, 0)
assert(state.Phase == "Results" and state.LastId == id and Events.productionMultiplier(state) == 1, "results, boost gone")
state = Events.advance(state, state.PhaseEndsAt, 0)
assert(state.Phase == "Rest" and state.PhaseEndsAt > 0, "back to rest")
for roll = 0, 0.99, 0.11 do
	assert(Events.pick("MeteorShower", roll) ~= "MeteorShower", "no repeat at roll " .. roll)
end
local seen = {}
for roll = 0, 0.99, 0.05 do
	seen[Events.pick(nil, roll)] = true
end
for _, eventId in Events.ORDER do
	assert(seen[eventId], eventId .. " can be picked")
	local def = Events.EVENTS[eventId]
	assert(def.Name ~= "" and def.Blurb ~= "" and def.How ~= "" and def.Icon ~= "", eventId .. " is described")
	assert(not string.find(def.Blurb .. def.How, "!", 1, true), eventId .. ": plain copy")
	assert(({ mod = true, drops = true, goal = true, titan = true, race = true, draw = true, stars = true, supply = true })[def.Kind], eventId .. " has a real mechanic")
end
assert(#Events.ORDER >= 15, "fifteen events")

-- Community Forge
assert(Events.communityGoal(0) == Events.EVENTS.CommunityForge.MinGoal, "empty server still has a goal")
assert(Events.communityGoal(6) == 6 * Events.EVENTS.CommunityForge.PointsPerPlayer, "goal scales with players")
assert(Events.collectPoints(1000, 10) == 100, "points are seconds of your own output")
assert(Events.collectPoints(1e30, 1) == Events.EVENTS.CommunityForge.MaxPointsPerCollect, "one huge vault can't finish it alone")
assert(Events.collectPoints(5, 0) == 1 and Events.collectPoints(0, 10) == 0, "edge cases")
local ranking = Events.ranking({ [3] = 50, [1] = 50, [2] = 90, [4] = 0 })
assert(#ranking == 3 and ranking[1].UserId == 2 and ranking[2].UserId == 1 and ranking[3].UserId == 3, "ranked, ties by id, zeros dropped")
assert(Events.communityStardust(1) > Events.communityStardust(2) and Events.communityStardust(3) > Events.communityStardust(4), "top three get more")

-- Stardust Rain
assert(Events.rainDust(100, 1) == 10, "sqrt of seconds")
assert(Events.rainDust(1e12, 1) == Events.EVENTS.StardustRain.Drops.Dust, "capped")
assert(Events.rainDust(0, 1) == 0, "nothing collected, nothing dropped")

-- Modifiers apply only while their event is live
local function live(eventId)
	return { Phase = "Live", Id = eventId, PhaseEndsAt = 1e9 }
end
assert(Events.mod(live("Overheat"), "Tap") == 3 and Events.mod(live("MeteorShower"), "Tap") == 1, "Overheat triples taps")
assert(Events.mod(live("CriticalMass"), "Crit") == 0.25 and Events.mod(nil, "Crit") == 0, "Critical Mass adds crit")
assert(Events.mod(live("ComboFever"), "ComboWindow") == 2, "Combo Fever doubles the window")
assert(Events.mod(live("GoldenVault"), "Collect") == 0.5, "Golden Vault pays half again")
assert(Events.mod({ Phase = "Results", Id = "Overheat" }, "Tap") == 1, "modifiers end with the event")

-- Drops
local seam = Events.drops("CoreSeam", 100, 1, 0.1, 0.99)
assert(seam.Cores == 3 and seam.Dust == 0, "Core Seam can dig up three")
assert(Events.drops("CoreSeam", 100, 1, 0.5, 0).Cores == 0, "but only 30% of the time")
local cache = Events.drops("KeyCache", 100, 1, 0.1, 0)
assert(cache.Keys == 1 and cache.KeyCrate == "ForgeCrate", "Key Cache turns up a key")
assert(Events.drops("MeteorShower", 100, 1, 0, 0).Dust == 0, "non-drop events drop nothing")

-- Titan, race, draw, supply
assert(Events.titanHealth(1) == Events.EVENTS.IronTitan.MinHealth and Events.titanHealth(10) == 5000, "titan health scales")
assert(Events.titanCollectHit(1e12, 1) == Events.EVENTS.IronTitan.MaxCollectHit, "one collect can't solo it")
assert(Events.racePrize(1).Cores > Events.racePrize(2).Cores and Events.racePrize(9).Stardust == 10, "race prizes")
local winners = Events.drawWinners({ [1] = 10, [2] = 1, [3] = 1 }, { 0, 0, 0 }, 3)
assert(#winners == 3 and winners[1] == 1, "draw picks by ticket")
local seenWin = {}
for _, w in winners do
	assert(not seenWin[w], "nobody wins twice")
	seenWin[w] = true
end
assert(#Events.drawWinners({}, { 0.5 }, 3) == 0, "no tickets, no winners")
local times = Events.supplyTimes()
assert(#times == 4 and times[1] < times[4] and times[4] < Events.LIVE_SECONDS, "four crates inside the event")

-- Wiring
local service = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau#ServerEventService")
for _, needle in { "function ServerEventService:Step", "function ServerEventService:OnCollect", "function ServerEventService:State", "function ServerEventService:Start", "function ServerEventService:OnTap", "function ServerEventService:CatchStar", "function ServerEventService:ClaimSupply", "function ServerEventService:_settle" } do
	assert(string.find(service, needle, 1, true), "service has " .. needle)
end
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "self._events:Step(deltaTime)", 1, true), "the heartbeat runs the cycle")
assert(string.find(server, "self._fluxSurge:Multiplier(now) * self._events:ProductionMultiplier()", 1, true), "production ticks include the event multiplier")
assert(string.find(server, "self._events:OnCollect(player, amountNumber", 1, true), "collects feed the event")
assert(string.find(server, "ServerEvent = self._events:State(player)", 1, true), "the snapshot carries the event")
assert(string.find(server, "function GameService:_payEvent", 1, true), "event payouts")
assert(string.find(server, "self._events:TapMultiplier()", 1, true) and string.find(server, "self._events:CritBonus()", 1, true), "overcharge reads the event")
assert(string.find(server, "self._events:OnTap(player)", 1, true), "taps hit the titan")
assert(string.find(server, "function GameService:_eventAct", 1, true), "stars and crates are claimed through the server")
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau#serverEventsUi")
for _, needle in { "local function ServerEventHost", "local function EventPanel", "local function StarField", "local function SupplyCrates", 'Juice.live, "serverEvent"' } do
	assert(string.find(ui, needle, 1, true), "client has " .. needle)
end
-- the event is shown by the island (a live buff whose row opens the panel) and announced there
assert(not string.find(ui, "local function LiveSplash", 1, true), "no separate start splash")
assert(not string.find(ui, 'Name = "ServerEventBanner"', 1, true), "no floating event banner over the island")
assert(string.find(ui, ".moment(string.upper(def.Name), def.How", 1, true), "an event going live is a moment in the island")
assert(not string.find(ui, "EVENT_DESCRIPTIONS", 1, true), "no filler descriptions left")
local strip = fs.readFile("src/Client/AstralForge/BuffStrip.luau")
assert(string.find(strip, 'if buff.key == "event" then function()', 1, true), "the island's event row opens the panel")

print("verify_server_events: ok")
