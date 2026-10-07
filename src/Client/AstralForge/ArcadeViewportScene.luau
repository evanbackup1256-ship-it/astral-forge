--!strict
-- Purpose: Resolve the selected arcade game's dedicated preview scene.
-- Owner: Astral Forge presentation. Dependencies: ArcadeViewport scene builder modules. Last-reviewed: 2026-10-07.

local tables = require(script.Parent.ArcadeViewportTableScenes)
local games = require(script.Parent.ArcadeViewportGameScenes)

type SceneBuilder = (Instance) -> { BasePart }

local builders: { [string]: SceneBuilder } = {}
for kind, builder in tables do
	builders[kind] = builder
end
for kind, builder in games do
	builders[kind] = builder
end

local function BuildScene(world: WorldModel, kind: string): Model
	local builder = builders[kind]
	assert(builder ~= nil, `ArcadeViewport: no dedicated scene builder for {kind}`)

	local scene = Instance.new("Model")
	scene.Name = kind .. "ArcadeScene"
	scene.Parent = world
	builder(scene)
	scene.WorldPivot = CFrame.identity
	return scene
end

return table.freeze({
	BuildScene = BuildScene,
})
