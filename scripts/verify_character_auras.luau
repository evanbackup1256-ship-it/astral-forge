local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local environment = setmetatable({
	Color3 = roblox.Color3, Vector2 = roblox.Vector2, UDim2 = roblox.UDim2, Enum = roblox.Enum,
}, { __index = _G })
local sprites = luau.load(fs.readFile("src/Shared/AstralForge/Shared/ElementSprites.luau"), { environment = environment })()
local characters = serde.decode("json", fs.readFile("assets/generated/sprites/characters/manifest.json"))
local effects = serde.decode("json", fs.readFile("assets/generated/sprites/hq/manifest.json"))
assert(#sprites.ORDER == 57)
for _, name in sprites.ORDER do
	local sheet = assert(sprites.sheet(name))
	assert(sheet.Image == "rbxassetid://" .. tostring(characters[name].assetId), name .. ": character stays active")
	assert(sheet.AuraImage == "rbxassetid://" .. tostring(effects[name:lower()].assetId), name .. ": original effect preserved")
	assert(sheet.Image ~= sheet.AuraImage)
	local character, aura = sprites.animation(name), sprites.animation(name, 12, true)
	assert(character.Spritesheet == sheet.Image and aura.Spritesheet == sheet.AuraImage)
	assert(character.SpriteSize.X == 170.5 and aura.SpriteSize.X == 170.5)
	assert(character.SpriteCount == 36 and aura.SpriteCount == 36 and aura.Framerate == 12)
end

local pending, tracks, destroyed = {}, {}, 0
local React = {
	useRef = function(value) return { current = value } end,
	useEffect = function(callback) table.insert(pending, callback) end,
	createElement = function(kind, props, ...)
		return { kind = kind, props = props, children = { ... } }
	end,
}
environment.React = React
environment.ElementSprites = sprites
environment.Playback = { register = function(label, columns, count, size, rate)
	assert(columns == 6 and count == 36 and size.X == 170.5)
	local track = {
		Framerate = rate,
		setRate = function(nextRate) assert(nextRate == rate) end,
		release = function() destroyed += 1 end,
	}
	assert(label.Image:match("^rbxassetid://%d+$"), "each layer retains its own atlas")
	table.insert(tracks, track)
	return track
end }
local source = fs.readFile("src/Client/AstralForge/ElementFx.luau")
local componentStart = assert(source:find("local h = React.createElement", 1, true))
source = source:sub(componentStart)
local render = luau.load(source, { environment = environment })().ElementFx
local function mount(node)
	if type(node.kind) == "function" then node = node.kind(node.props) end
	if node.props.ref then node.props.ref.current = node.props end
	for _, child in node.children do mount(child) end
	return node
end
for _, mode in { "animated", "reduced", "still", "disabled" } do
	pending, tracks, destroyed = {}, {}, 0
	local node = mount(render({
		element = "Fire", transparency = 0.2, framerate = 12,
		reducedMotion = mode == "reduced", still = mode == "still", aura = mode ~= "disabled",
		size = roblox.UDim2.fromOffset(80, 64),
	}))
	if mode == "disabled" then
		assert(node.kind == "imagelabel" and node.props.Image == sprites.sheet("Fire").Image)
	else
		assert(node.kind == "frame" and #node.children == 2)
		local aura = render(node.children[1].props)
		assert(aura.props.Image == sprites.sheet("Fire").AuraImage)
		assert(aura.props.ImageTransparency > 0.5)
		assert(node.children[2].props.ZIndex > aura.props.ZIndex, "character sits in front")
		assert(node.children[2].props.Size == roblox.UDim2.fromScale(1, 1), "wrapper preserves original character bounds")
		-- The separately inspected aura must not participate in the mounted lifecycle.
		table.remove(pending)
		table.remove(pending)
	end
	local cleanups = {}
	for _, callback in pending do
		local cleanup = callback()
		if cleanup then table.insert(cleanups, cleanup) end
	end
	local expected = if mode == "animated" then 2 elseif mode == "disabled" then 1 else 0
	assert(#tracks == expected, mode .. ": correct animated layer count")
	for _, cleanup in cleanups do cleanup() end
	assert(destroyed == expected, mode .. ": all tracks disposed")
end
print("[TEST] character auras: all 57 asset pairs, crop mapping, layering, reduced motion and track cleanup passed")
