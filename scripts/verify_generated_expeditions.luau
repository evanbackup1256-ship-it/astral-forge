-- Execute the actual generated-route builders against the authored artifact IDs.
local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")
local source = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local start = assert(string.find(source, "\n\t\tArtifacts = {", 1, true))
local stop = assert(string.find(source, "\n\t\tExpeditions = {", start, true))
local artifacts, ids = {}, {}
for id in string.gmatch(string.sub(source, start, stop - 1), 'Id = "([^"]+)"') do
	table.insert(artifacts, { Id = id })
	ids[id] = true
end
assert(#artifacts == 12, "authored artifact catalog drifted")
local config = {
	MaxGeneratedExpeditions = assert(tonumber((string.gsub(assert(string.match(source, "GameConfig.MaxGeneratedExpeditions = ([%d_]+)")), "_", "")))),
	Operations = { Artifacts = artifacts, Expeditions = {} },
}
local env = setmetatable({ GameConfig = config, Color3 = { fromHSV = function() return {} end } }, { __index = getfenv(0) })
local builderStart = assert(string.find(source, "function GameConfig.ResolveExpedition", 1, true))
local builderStop = assert(string.find(source, "local function attachLazyLoader", builderStart, true))
local generate = luau.load(string.sub(source, builderStart, builderStop - 1) .. "\nreturn generateExpeditions", { environment = env })()
local resolved = {}
for index = 1, config.MaxGeneratedExpeditions do
	local id = "HorizonRun_" .. index
	resolved[id] = config.ResolveExpedition(id)
	assert(ids[resolved[id].ArtifactId], id .. " resolver artifact missing")
end
for _, route in generate() do
	assert(ids[route.ArtifactId], route.Id .. " generated artifact missing")
	assert(route.ArtifactId == resolved[route.Id].ArtifactId, route.Id .. " artifact differs between builders")
end
assert(#config.Operations.Expeditions == config.MaxGeneratedExpeditions)
assert(config.ResolveExpedition("HorizonRun_0") == nil)
assert(config.ResolveExpedition("HorizonRun_" .. (config.MaxGeneratedExpeditions + 1)) == nil)
print("[TEST] all " .. config.MaxGeneratedExpeditions .. " generated expedition artifacts passed")
