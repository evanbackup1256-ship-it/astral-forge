--!strict
-- Purpose: Guard the active score-only arcade against missing or shared placeholder scenes.
-- Owner: Astral Forge verification. Dependencies: ArcadeConfig, Lune filesystem. Last-reviewed: 2026-10-07.

local fs = require("@lune/fs")
local Config = require("../src/Shared/AstralForge/Shared/ArcadeConfig")

local viewport = fs.readFile("src/Client/AstralForge/ArcadeViewport.luau")
local page = fs.readFile("src/Client/AstralForge/ArcadePage.luau")
local buildersStart = assert(viewport:find("local BUILDERS", 1, true), "arcade viewport builder registry is missing")
local buildersEnd = assert(viewport:find("local function buildScene", buildersStart, true), "scene factory is missing")
local registry = viewport:sub(buildersStart, buildersEnd - 1)

local seen: { [string]: boolean } = {}
local builderNameByGame: { [string]: string } = {}
local seenBuilders: { [string]: string } = {}
local builderCount = 0
for gameId, builderName in registry:gmatch("\n\t([%w]+) = ([%w_]+),") do
	assert(
		seenBuilders[builderName] == nil,
		`games {seenBuilders[builderName]} and {gameId} share the {builderName} builder`
	)
	seenBuilders[builderName] = gameId
	builderNameByGame[gameId] = builderName
	builderCount += 1
end
for _, game in Config.Games do
	assert(builderNameByGame[game.Id] ~= nil, `missing dedicated viewport builder for {game.Id}`)
	assert(not seen[game.Id], `duplicate arcade viewport registration for {game.Id}`)
	seen[game.Id] = true
end
assert(builderCount == #Config.Games, "every configured arcade game must have its own builder")

assert(
	page:find("local ArcadeViewport = require(script.Parent.ArcadeViewport)", 1, true),
	"active arcade must load the dedicated viewport module"
)
assert(page:find('id = "game-scene"', 1, true), "active arcade must render a game-scene section")
assert(page:find("kind = selected", 1, true), "selected game must choose its own scene")
assert(viewport:find('scene.Name = kind .. "ArcadeScene"', 1, true), "scene instances must be named by game")
assert(viewport:find("world:Destroy()", 1, true), "viewport cleanup must destroy its isolated scene world")
assert(viewport:find("connection:Disconnect()", 1, true), "viewport cleanup must stop its animation connection")
assert(viewport:find("softMotion", 1, true), "idle model motion must respect reduced-motion settings")

print(`[TEST] active arcade provides {#Config.Games} separately registered scenes with isolated viewport cleanup`)
