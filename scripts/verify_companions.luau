-- Elemental companions: 57 unique characters with their elemental light lit into every frame
-- (tools/spritegen/companions). One atlas per element; no separate aura sheet plays behind it.
local fs = require("./_memberfs")(require("@lune/fs"))
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local environment = setmetatable({
	Color3 = roblox.Color3, Vector2 = roblox.Vector2, UDim2 = roblox.UDim2, Enum = roblox.Enum,
}, { __index = _G })
local sprites = luau.load(fs.readFile("src/Shared/AstralForge/Shared/ElementSprites.luau"), { environment = environment })()
local manifest = serde.decode("json", fs.readFile("assets/generated/sprites/companions/manifest.json"))

assert(#sprites.ORDER == 57, "57 elements")
local images, concepts = {}, {}
for _, name in sprites.ORDER do
	local record = assert(manifest[name], name .. ": companion missing from manifest")
	assert(record.count == 36 and record.frame == 682 and record.size == 4096, name .. ": atlas format matches playback")
	assert(type(record.concept) == "string" and #record.concept > 40, name .. ": every companion has its own written concept")
	assert(not concepts[record.concept], name .. ": concepts are not shared")
	concepts[record.concept] = true
	local sheet = assert(sprites.sheet(name))
	assert(sheet.Image == "rbxassetid://" .. tostring(record.assetId), name .. ": the lit companion is active")
	assert(sheet.AuraImage == nil, name .. ": no separate aura sheet plays behind the character")
	assert(not images[sheet.Image], name .. ": every element has its own atlas")
	images[sheet.Image] = true
	local animation = sprites.animation(name)
	assert(animation.Spritesheet == sheet.Image and animation.SpriteCount == 36 and animation.SpriteSize.X == 170.5)
end

-- ElementFx renders one lit layer: an imagelabel, never a wrapper with an aura sheet behind it.
-- A tiny hook runtime: state and refs persist per slot across renders of one mounted instance.
local slots, slot, effects = {}, 0, {}
local flashTrigger, flashValue = nil, 0
local React = {
	useRef = function(value)
		slot += 1
		slots[slot] = slots[slot] or { current = value }
		return slots[slot]
	end,
	useState = function(value)
		slot += 1
		local cell = slots[slot] or { value = value }
		slots[slot] = cell
		return cell.value, function(nextValue)
			cell.value = if type(nextValue) == "function" then nextValue(cell.value) else nextValue
		end
	end,
	useEffect = function(callback) table.insert(effects, callback) end,
	createElement = function(kind, props, ...) return { kind = kind, props = props, children = { ... } } end,
}
local function binding(value) return { map = function(_, callback) return callback(value) end } end
environment.React = React
environment.ElementSprites = sprites
environment.Playback = { register = function() return { setRate = function() end, release = function() end } end }
environment.named = function(name) return { Name = name } end
environment.useFlash = function(trigger)
	flashTrigger = trigger
	return binding(flashValue)
end
local source = fs.readFile("src/Client/AstralForge/ElementFx.luau")
local componentStart = source:find("local h = React.createElement", 1, true) or assert(source:find("local REACTIONS = {", 1, true))
local render = luau.load(source:sub(componentStart), { environment = environment })().ElementFx
local function mount(props)
	slot, effects = 0, {}
	local node = render(props)
	for _, effect in effects do effect() end
	return node
end
for _, name in sprites.ORDER do
	slots = {}
	local node = mount({ element = name, size = roblox.UDim2.fromOffset(80, 80) })
	assert(node.kind == "imagelabel" and node.props.Image == sprites.sheet(name).Image, name .. ": single lit layer")
end

-- Reactions play on the companion itself, only when their key changes after mount.
for _, kind in { "select", "reveal", "equip", "mastery" } do
	slots, flashValue = {}, 1
	mount({ element = "Fire", reaction = kind, reactionKey = "a" })
	assert(flashTrigger == 0, kind .. ": no reaction on first render")
	mount({ element = "Fire", reaction = kind, reactionKey = "b" })
	local node = mount({ element = "Fire", reaction = kind, reactionKey = "b" })
	assert(flashTrigger == 1, kind .. ": a key change plays the reaction once")
	local scale = node.children[1]
	assert(scale and scale.kind == "uiscale", kind .. ": reaction scales the character")
	assert(node.props.Rotation ~= 0 or kind == "select", kind .. ": reaction has its own motion")
	flashValue = 0
	node = mount({ element = "Fire", reaction = kind, reactionKey = "b" })
	assert(node.props.Rotation % 360 == 0 and node.children[1].props.Scale == 1, kind .. ": settles exactly upright at rest")
end
slots, flashValue = {}, 1
mount({ element = "Fire", reaction = "equip", reactionKey = "a", reducedMotion = true })
local quiet = mount({ element = "Fire", reaction = "equip", reactionKey = "b", reducedMotion = true })
assert(flashTrigger == 0 and quiet.props.Rotation == 0 and quiet.children[1] == nil, "reduced motion skips reactions")
print("[TEST] companions: 57 unique lit characters, own concepts and atlases, single-layer playback passed")
