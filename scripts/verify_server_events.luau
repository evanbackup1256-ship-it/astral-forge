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
assert(Events.productionMultiplier(state) == (if id == "MeteorShower" then Events.EVENTS.MeteorShower.Multiplier else 1), "only Meteor Shower boosts output")
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
end

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
assert(Events.rainDust(1e12, 1) == Events.EVENTS.StardustRain.MaxDustPerCollect, "capped")
assert(Events.rainDust(0, 1) == 0, "nothing collected, nothing dropped")

-- Wiring
local service = fs.readFile("src/Server/AstralForge/Services/CoreServices.luau#ServerEventService")
for _, needle in { "function ServerEventService:Step", "function ServerEventService:OnCollect", "function ServerEventService:State", "function ServerEventService:Start" } do
	assert(string.find(service, needle, 1, true), "service has " .. needle)
end
local bumped = 0
local ProfileBagMath = {
	BumpStat = function(profile, key, amount)
		profile.Stats[key] = (profile.Stats[key] or 0) + amount
		bumped += amount
	end,
}
local function folder(children)
	return {
		WaitForChild = function(_, name)
			return assert(children[name], `unexpected fixture lookup: {name}`)
		end,
	}
end
local sharedDataModule = {}
local sharedData = folder({ SharedData = sharedDataModule })
local replicatedStorage = folder({ AstralForge = folder({ Shared = sharedData }) })
local moduleFolder = folder({ ProfileBagMath = {} })
local scriptFixture = { Parent = { Parent = folder({ Modules = moduleFolder }) } }
local environment = {
	game = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return replicatedStorage
			end
			assert(name == "Players", `unexpected service: {name}`)
			return { GetPlayers = function() return {} end }
		end,
	},
	script = scriptFixture,
	require = function(module)
		if module == sharedDataModule then
			return function(name)
				assert(name == "ServerEvents")
				return Events
			end
		end
		assert(module == moduleFolder:WaitForChild("ProfileBagMath"))
		return ProfileBagMath
	end,
}
local ServerEventService = luau.load(service, { environment = environment })()()
local eventService = ServerEventService.new({})
local pilot = { UserId = 42, DisplayName = "Pilot" }
local eventProfile = { LiveOps = {}, Stats = { EventParticipations = 0 } }
eventService._state = { Phase = "Live", Id = "MeteorShower", PhaseEndsAt = 100 }
eventService:OnCollect(pilot, eventProfile, 10, 5)
eventService:OnCollect(pilot, eventProfile, 20, 5)
assert(eventProfile.Stats.EventParticipations == 1 and bumped == 1, "one collection event only counts once per live window")
eventService._state.PhaseEndsAt = 200
eventService:OnCollect(pilot, eventProfile, 10, 5)
assert(eventProfile.Stats.EventParticipations == 2 and bumped == 2, "a later live event window counts separately")
eventService._state = { Phase = "Live", Id = "StardustRain", PhaseEndsAt = 300 }
eventService:OnCollect(pilot, eventProfile, 0, 5)
assert(eventProfile.Stats.EventParticipations == 2, "an empty collect does not count as event participation")
eventService._state = { Phase = "Results", Id = "StardustRain", PhaseEndsAt = 300 }
eventService:OnCollect(pilot, eventProfile, 10, 5)
assert(eventProfile.Stats.EventParticipations == 2, "results phase does not count")
eventService._state = { Phase = "Live", Id = "CommunityForge", PhaseEndsAt = 400 }
eventService._goal = 1_000_000
eventService:OnCollect(pilot, eventProfile, 10, 5)
assert(eventProfile.Stats.EventParticipations == 3, "active community forge participation counts")
eventService._state.PhaseEndsAt = 500
eventService._completed = true
eventService:OnCollect(pilot, eventProfile, 10, 5)
assert(eventProfile.Stats.EventParticipations == 3, "completed community forge does not count")

local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "self._events:Step(deltaTime)", 1, true), "the heartbeat runs the cycle")
assert(string.match(server, "self%._fluxSurge:Multiplier%(now%)%s*%*%s*self%._events:ProductionMultiplier%(%)"), "production ticks include the event multiplier")
assert(string.find(server, "self._events:OnCollect(", 1, true), "collects feed the event")
assert(string.find(server, "profile,\n\t\t\t\tamountNumber,", 1, true), "event hook receives the saved profile and collected amount")
assert(string.find(server, "ServerEvent = self._events:State(player)", 1, true), "the snapshot carries the event")
assert(string.find(server, "function GameService:_payCommunityForge", 1, true), "community payouts")
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau#serverEventsUi")
for _, needle in { "local function ServerEventHost", "local function EventPanel", "local function LiveSplash" } do
	assert(string.find(ui, needle, 1, true), "client has " .. needle)
end

print("verify_server_events: ok (participation counts once per positive live event window)")
