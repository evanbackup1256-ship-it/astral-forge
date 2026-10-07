--!strict
-- Purpose: execute the production guild identity filter and fail-closed route guard.
-- Owner: social regression suite. Dependencies: Lune filesystem and Luau runtime. Last-reviewed: 2026-10-07.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local securitySource = fs.readFile("src/Server/AstralForge/Services/SecurityServices.luau")
local serverSource = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")

local filterStart = assert(securitySource:find("\t\tfunction Filter:Apply(", 1, true))
local filterEnd = assert(securitySource:find("\n\t\tend\n\n\t\tlocal Relations", filterStart, true))
local filterSource = securitySource:sub(filterStart, filterEnd + #"\n\t\tend" - 1)

local filterInputs = {}
local filteredText: string? = "Public guild"
local filterFailure = false
local filterEnvironment = {
	TextService = {
		FilterStringAsync = function(_self, text, userId)
			table.insert(filterInputs, { Text = text, UserId = userId })
			if filterFailure then
				error("TextService unavailable")
			end
			return {
				GetNonChatStringForBroadcastAsync = function()
					return filteredText
				end,
			}
		end,
	},
}
local makeFilter = luau.load(
	"local TextService = TextService\nlocal Filter = {}\n" .. filterSource .. "\nreturn Filter",
	{ environment = filterEnvironment }
)
local filter = makeFilter()
local player = { UserId = 731 }

local ok, result = filter:Apply(player, string.rep("x", 50), player.UserId, 28)
assert(ok and result == "Public guild")
assert(filterInputs[1].UserId == player.UserId and #filterInputs[1].Text == 28)

filteredText = "###"
ok, result = filter:Apply(player, "Original name", player.UserId, 28)
assert(ok and result == "###", "censored broadcast text is returned as the only persisted candidate")

filteredText = nil
ok, result = filter:Apply(player, "Original name", player.UserId, 28)
assert(not ok and result == nil, "nil filter output must fail closed")

filterFailure = true
ok, result = filter:Apply(player, "Original name", player.UserId, 28)
assert(not ok and result == nil, "TextService exceptions must fail closed")

local guardStart = assert(serverSource:find(
	"\t\tif action == Protocol.Actions.CreateGuild or action == Protocol.Actions.RenameGuild then",
	1,
	true
))
local guardEnd = assert(serverSource:find(
	"\n\t\tif\n\t\t\taction == Protocol.Actions.SendGuildChat",
	guardStart,
	true
))
local guardSource = serverSource:sub(guardStart, guardEnd - 1)
local routeFactory = luau.load(
	"local GameService = {}\n"
		.. "function GameService:_guildAction(player, action, payload)\n"
		.. guardSource
		.. "\nreturn payload\nend\nreturn GameService._guildAction",
	{
		environment = {
			Protocol = { Actions = { CreateGuild = "CreateGuild", RenameGuild = "RenameGuild" } },
			responseError = function(message)
				return { ok = false, message = message }
			end,
		},
	}
)
local routeGuard = routeFactory()

local filterCalls = 0
local service = {
	_security = {
		Filter = {
			Apply = function(_self, _player, rawName, userId, maximumLength)
				filterCalls += 1
				assert(userId == player.UserId and maximumLength == 28)
				assert(rawName == "Original name")
				return true, "Filtered name"
			end,
		},
	},
}
local originalPayload = { Name = "Original name", Tag = "AF" }
local routedPayload = routeGuard(service, player, "CreateGuild", originalPayload)
assert(routedPayload.Name == "Filtered name" and routedPayload.Tag == "AF")
assert(originalPayload.Name == "Original name", "route guard must clone before replacing the caller's payload")
assert(filterCalls == 1)

service._security.Filter.Apply = function()
	filterCalls += 1
	return false, nil
end
local denied = routeGuard(service, player, "RenameGuild", { Name = "Original name" })
assert(denied.ok == false and filterCalls == 2, "filter failure must stop create/rename before persistence")

service._security.Filter = nil
denied = routeGuard(service, player, "CreateGuild", { Name = "Original name" })
assert(denied.ok == false, "missing filter service must stop create/rename before persistence")

local untouched = { Name = "Raw non-guild payload" }
assert(routeGuard(service, player, "JoinGuild", untouched) == untouched)

print("[TEST] production guild filter and create/rename guard passed raw length, filtered output, censorship, errors, cloning, and fail-closed cases")
