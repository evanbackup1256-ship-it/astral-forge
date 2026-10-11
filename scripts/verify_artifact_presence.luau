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

local roblox = require("@lune/roblox")
local visibleStart = assert(presence:find("local function visibleRig", 1, true))
local visibleEnd = assert(presence:find("\nlocal function nameplate", visibleStart, true))
local visible = luau.load(presence:sub(visibleStart, visibleEnd - 1) .. "\nreturn visibleRig", {
	environment = setmetatable({ DRAW_DISTANCE = 140 }, { __index = _G }),
})()
local origin = roblox.Vector3.zero
local camera = {
	CFrame = { Position = origin }, ViewportSize = roblox.Vector2.new(359, 718),
	projected = roblox.Vector3.new(180, 360, 10),
}
function camera:WorldToViewportPoint() return self.projected end
local rig = {
	root = { Parent = {} },
	plate = { Enabled = true, MaxDistance = 80, StudsOffsetWorldSpace = origin,
		Adornee = { Parent = {}, Position = roblox.Vector3.new(0, 0, 20) } },
}
assert(visible(rig, camera))
camera.projected = roblox.Vector3.new(180, 360, -10); assert(not visible(rig, camera), "behind-camera companions pause")
camera.projected = roblox.Vector3.new(600, 360, 10); assert(not visible(rig, camera), "offscreen companions pause")
camera.projected = roblox.Vector3.new(-80, 360, 10); assert(visible(rig, camera), "partially visible billboard margin")
rig.plate.Adornee.Position = roblox.Vector3.new(0, 0, 81); assert(not visible(rig, camera), "actual billboard draw distance respected")
rig.plate.Adornee.Position = roblox.Vector3.new(0, 0, 20)
rig.plate.Enabled = false; assert(not visible(rig, camera)); rig.plate.Enabled = true
rig.root.Parent = nil; assert(not visible(rig, camera)); rig.root.Parent = {}
assert(not visible(rig, nil), "camera replacement gaps pause")
local loopStart = assert(presence:find("local frameStep =", 1, true))
local loopEnd = assert(presence:find("\n\treturn function()", loopStart, true))
local tick
local rigs = {}
for i = 1, 30 do
	rigs[i] = {
		root = rig.root, plate = rig.plate,
		glyph = {},
	}
end
assert(not presence:find("AuraImage", 1, true) and not presence:find('"Aura"', 1, true),
	"world companions are one lit layer; no aura sheet plays behind them")
local guiService = { ReducedMotionEnabled = false }
local loopEnv = setmetatable({
	ElementSprites = { FRAMERATE = 12, FRAME = 170.5, COUNT = 36, COLUMNS = 6 },
	RunService = { RenderStepped = { Connect = function(_, callback) tick = callback; return {} end } },
	GuiService = guiService, connections = {}, rigs = rigs,
	workspace = { CurrentCamera = camera }, spriteClock = 0, spriteFrame = 0,
	visibleRig = visible, MAX_ANIMATED_COMPANIONS = 12, Vector2 = roblox.Vector2,
}, { __index = _G })
camera.projected = roblox.Vector3.new(180, 360, 10)
luau.load(presence:sub(loopStart, loopEnd - 1), { environment = loopEnv })()
tick(0.1)
local count = 0
for _, companion in rigs do
	if companion.glyph.ImageRectOffset then
		count += 1
	end
end
assert(count == 12, "crowded worlds cap animated companions")
local previous = {}
for i, companion in rigs do previous[i] = companion.glyph.ImageRectOffset end
guiService.ReducedMotionEnabled = true; tick(0.2)
for i, companion in rigs do assert(companion.glyph.ImageRectOffset == previous[i], "world reduced motion stops writes") end
guiService.ReducedMotionEnabled = false
camera.projected = roblox.Vector3.new(180, 360, -10); tick(0.2)
for i, companion in rigs do assert(companion.glyph.ImageRectOffset == previous[i], "world offscreen stops writes") end

print("artifact presence ok")
