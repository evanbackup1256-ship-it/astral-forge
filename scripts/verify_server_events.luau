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
local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
assert(string.find(server, "self._events:Step(deltaTime)", 1, true), "the heartbeat runs the cycle")
assert(string.find(server, "self._fluxSurge:Multiplier(now) * self._events:ProductionMultiplier()", 1, true), "production ticks include the event multiplier")
assert(string.find(server, "self._events:OnCollect(player, amountNumber", 1, true), "collects feed the event")
assert(string.find(server, "ServerEvent = self._events:State(player)", 1, true), "the snapshot carries the event")
assert(string.find(server, "function GameService:_payCommunityForge", 1, true), "community payouts")
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau#serverEventsUi")
for _, needle in { "local function ServerEventHost", "local function EventPanel", "local function LiveSplash" } do
	assert(string.find(ui, needle, 1, true), "client has " .. needle)
end

local roblox = require("@lune/roblox")
local hostStart = assert(ui:find("local function ServerEventHost", 1, true))
local geometryStart = assert(ui:find('\tlocal active = def ~= nil and event.Phase ~= "Rest"', hostStart, true))
local geometryEnd = assert(ui:find("\n\tlocal skyFx", geometryStart, true))
local bannerStart = assert(ui:find('\tlocal banner = React.createElement("textbutton"', geometryEnd, true))
local bannerEnd = assert(ui:find("\n\treturn React.createElement(React.Fragment, nil, skyFx, banner", bannerStart, true))
local bannerSource = ui:sub(geometryStart, geometryEnd - 1) .. "\n" .. ui:sub(bannerStart, bannerEnd - 1) .. "\nreturn banner"
for _, screen in { { 320, true }, { 359, true }, { 705, true }, { 1084, false } } do
	for _, eventId in Events.ORDER do
		local color = roblox.Color3.fromRGB(91, 214, 244)
		local banner = luau.load(bannerSource, { environment = setmetatable({
			event = { Id = eventId, Phase = "Live", Goal = 100, Progress = 20 },
			def = Events.EVENTS[eventId],
			ServerEvents = Events, viewport = { width = screen[1], topInset = 0 },
			chrome = { stack = screen[2], sideSafe = 10, tabBarH = 58 },
			accentOf = function() return color end,
			darken = function() return color end,
			Palette = { night = color, line = color, cream = color, muted = color },
			pulse = { map = function() return 0 end }, now = { map = function() return "4:55 left" end },
			React = { createElement = function(kind, props, ...) return { kind = kind, props = props, children = { ... } } end },
			Icon = "Icon", ProgressBar = "ProgressBar",
			UDim2 = roblox.UDim2, UDim = roblox.UDim, Vector2 = roblox.Vector2,
			Enum = roblox.Enum, Font = roblox.Font,
		}, { __index = _G }) })()
		local title, time, progress = banner.children[4], banner.children[5], banner.children[6]
		assert(title.props.Text == Events.EVENTS[eventId].Name)
		assert(title.props.TextTruncate == roblox.Enum.TextTruncate.None and title.props.TextWrapped, "event name is not ellipsized")
		if screen[2] then
			assert(banner.props.Size.X.Offset >= screen[1] - 20 or banner.props.Size.X.Offset == 320, "phone notice uses available width")
		end
		assert(title.props.Position.Y.Offset + title.props.Size.Y.Offset <= time.props.Position.Y.Offset, "notice rows do not overlap")
		assert(time.props.Position.Y.Offset + time.props.Size.Y.Offset <= progress.props.position.Y.Offset, "timer clears progress bar")
		assert(progress.props.position.Y.Offset + progress.props.size.Y.Offset <= banner.props.Size.Y.Offset, "progress fits notice")
	end
end

print("verify_server_events: ok")
