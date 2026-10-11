-- Domain constellation: the radial layout of the real Domain tree never overlaps orbs, keeps every
-- node outside its prerequisites, and the stage wires its interactions.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Math = luau.load(fs.readFile("src/Client/AstralForge/DomainConstellationMath.luau"))()
local config = fs.readFile("src/Shared/AstralForge/Shared/GameConfig.luau")
local start = assert(string.find(config, "Tree = {", string.find(config, "Domain = {", 1, true), true))
local block = string.match(config, "%b{}", start + 7)
local tree = {}
for entry in string.gmatch(block, "{ Id = [^\n]+") do
	local id = string.match(entry, 'Id = "(%w+)"')
	local requires = {}
	local list = string.match(entry, "Requires = (%b{})")
	for parent in string.gmatch(list or "", '"(%w+)"') do table.insert(requires, parent) end
	table.insert(tree, { Id = id, Requires = requires })
end
assert(#tree >= 12, "parsed the Domain tree (" .. #tree .. " nodes)")

local layout = Math.build(tree)
for _, node in tree do
	local placed = assert(layout.positions[node.Id], node.Id .. " is placed")
	local radius = math.sqrt(placed.x ^ 2 + placed.y ^ 2)
	assert(radius > Math.CORE_RADIUS, node.Id .. " sits outside the core")
	for _, parent in node.Requires do
		local origin = layout.positions[parent]
		assert(origin.depth < placed.depth, node.Id .. " sits on a ring outside " .. parent)
	end
end
assert(Math.minSpacing(layout) >= 72, "orbs never overlap (closest " .. math.floor(Math.minSpacing(layout)) .. ")")

-- synthetic trees: wide, deep, and diamond-shaped prerequisites stay placed and separated
local wide = {}
for index = 1, 8 do table.insert(wide, { Id = "R" .. index, Requires = {} }) end
for index = 1, 8 do table.insert(wide, { Id = "C" .. index, Requires = { "R" .. index } }) end
table.insert(wide, { Id = "Join", Requires = { "C1", "C2" } })
local wideLayout = Math.build(wide)
assert(Math.minSpacing(wideLayout) >= 60, "a wide tree keeps its spacing")
assert(wideLayout.positions.Join.depth == 2 and wideLayout.positions.Join.root == "R1", "a shared child joins its first parent's sector")
local fit = Math.fitZoom(layout, 800, 600)
assert(fit > 0 and fit <= 1.6 and (layout.radius + 70) * 2 * fit <= 600 + 1e-6, "fit zoom shows the whole constellation")

local stage = fs.readFile("src/Client/AstralForge/DomainConstellation.luau")
for _, needle in { "UserInputService.TouchPinch", "Enum.UserInputType.MouseWheel", "reaction = \"reveal\"", "useClock(", "MAX_PULSES" } do
	assert(stage:find(needle, 1, true), "constellation stage has " .. needle)
end
assert(fs.readFile("src/Client/AstralForge/UiOverlays.luau"):find("DomainConstellation", 1, true), "the Domain tree uses the constellation")
print("[TEST] domain constellation: radial layout of " .. #tree .. " nodes, spacing, ring order, fit, and stage interactions passed")
