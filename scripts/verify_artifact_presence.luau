local fs = require("./_memberfs")(require("@lune/fs"))

local server = fs.readFile("src/Server/AstralForge/Services/ServerServices.luau")
local profileMath = fs.readFile("src/Server/AstralForge/Modules/ProfileMath.luau")
local shared = fs.readFile("src/Shared/AstralForge/Shared/SharedData.luau")
local uiCore = fs.readFile("src/Client/AstralForge/UiCore.luau")
local runtime = fs.readFile("src/Client/AstralForge/ClientRuntime.luau")
local social = fs.readFile("src/Client/AstralForge/pages/PagesSocial.luau")
local init = fs.readFile("src/Client/AstralForge/init.client.luau")
local presence = fs.readFile("src/Client/AstralForge/ArtifactPresence.luau")

local function has(src, needle, why)
	assert(string.find(src, needle, 1, true), why)
end

local sync = string.match(server, "function GameService:_syncLeaderstats.-\nend\n")
assert(sync, "_syncLeaderstats present")
for _, attr in { "EquippedArtifactName", "EquippedArtifactElement", "EquippedArtifactRarity", "EquippedArtifactLevel", "EquippedArtifactColor", "EquippedArtifactEffect" } do
	has(sync, '"' .. attr .. '"', "server replicates " .. attr)
end
local lastField = string.find(sync, '"EquippedArtifactEffect"', 1, true)
local idField = string.find(sync, 'SetAttribute("EquippedArtifact",', lastField, true)
assert(idField, "EquippedArtifact id is written after its detail fields")

has(profileMath, "Artifact = ", "public player record carries the artifact")
has(shared, "function PlayerlistModel.artifactOf", "playerlist reads live artifact attributes")
has(shared, "Artifact = PlayerlistModel.artifact(entry.Artifact)", "playerlist rows keep the artifact")
has(uiCore, "Model.artifactOf(", "player list rows show equipped artifacts")

has(runtime, "artifactName = title.artifactName", "chat records carry the artifact")
has(runtime, '"EquippedArtifactElement"', "chat reads the artifact element")
has(social, "message.artifactName ~= nil and React.createElement", "chat card renders the artifact chip")

has(init, "require(script.ArtifactPresence).attach()", "world presence attached")
has(presence, 'GetAttributeChangedSignal("EquippedArtifact")', "presence follows equips")
has(presence, "Players.PlayerRemoving:Connect(unwatch)", "presence cleans up leaving players")
has(presence, "folder:Destroy()", "presence disposer tears down")
has(presence, "burst(rig)", "equip burst")
has(presence, "rigBuilds[player] = nil", "clearing a rig invalidates unfinished builds")
local guardStart = assert(presence:find("if rigBuilds[player] ~= buildToken", 1, true))
local guardEnd = assert(presence:find("rigs[player] = rig", guardStart, true))
local guard = presence:sub(guardStart, guardEnd - 1)
local luau = require("@lune/luau")
for _, state in { "current", "newer-build", "departed", "respawned", "unequipped", "disposed", "unwatched" } do
	local character, token, player = {}, {}, { Parent = {} }
	player.Character = if state == "respawned" then {} else character
	player.GetAttribute = function() return if state == "unequipped" then nil else "DroneCrown" end
	if state == "departed" then player.Parent = nil end
	local destroyed = 0
	local environment = setmetatable({
		rigBuilds = { [player] = if state == "newer-build" then {} else token },
		buildToken = token, alive = state ~= "disposed",
		watchers = { [player] = if state == "unwatched" then nil else {} },
		player = player, character = character, info = { Id = "DroneCrown" },
		rig = { instances = {
			{ Destroy = function() destroyed += 1 end },
			{ Destroy = function() destroyed += 1 end },
		} },
	}, { __index = getfenv(0) })
	local commit = luau.load("return function()\n" .. guard .. "\nreturn true\nend", { environment = environment })()
	local accepted = commit()
	assert((accepted == true) == (state == "current"), state .. ": only the current live build may commit")
	assert(destroyed == (if state == "current" then 0 else 2), state .. ": rejected builds destroy every partial visual")
end

print("artifact presence ok")
