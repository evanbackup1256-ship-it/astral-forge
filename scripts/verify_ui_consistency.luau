local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function read(path)
	return fs.readFile(path):gsub("\r\n", "\n")
end

-- Run the actual global button hook with deferred callbacks and controller activation.
local audio = read("src/Client/AstralForge/AudioKit.luau")
local first = assert(audio:find("local function hookGuiClicks", 1, true))
local last = assert(audio:find("\n\treturn {\n\t\tbuttonAudioCue", first, true))
local function signal()
	local handlers = {}
	return {
		Connect = function(_, callback)
			table.insert(handlers, callback)
			return {
				Disconnect = function()
					local at = table.find(handlers, callback)
					if at then
						table.remove(handlers, at)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(handlers) do
				callback(...)
			end
		end,
	}
end
local queued, serial, played = {}, 0, 0
local fakeAudio = {
	captureIntent = function()
		return serial
	end,
	playIfUnclaimed = function(_, marker, cue)
		if marker == serial then
			serial += 1
			if cue == "click" then
				played += 1
			end
		end
	end,
}
local button = {
	Active = true,
	Selectable = false,
	Parent = {},
	IsA = function(_, kind)
		return kind == "GuiButton"
	end,
}
for _, name in { "InputBegan", "Activated", "MouseEnter", "SelectionGained", "Destroying" } do
	button[name] = signal()
end
local root = {
	IsA = function()
		return false
	end,
	GetDescendants = function()
		return { button }
	end,
	DescendantAdded = signal(),
}
local env = setmetatable({
	Audio = fakeAudio,
	UserInputService = { InputBegan = signal() },
	isActivationInput = function()
		return true
	end,
	task = {
		defer = function(callback)
			table.insert(queued, callback)
		end,
	},
}, { __index = getfenv(0) })
local hook = luau.load(audio:sub(first, last - 1) .. "\nreturn hookGuiClicks", { environment = env })()
local dispose = hook(root)
local function flush()
	for _, callback in queued do
		callback()
	end
	table.clear(queued)
end
button.Activated:Fire()
flush()
assert(played == 1, "controller activation without press marker must sound")
button.InputBegan:Fire({})
button.Activated:Fire()
serial += 1
flush()
assert(played == 1, "semantic sound must suppress generic click")
button.Activated:Fire()
button.Parent = nil
flush()
assert(played == 2, "navigation may remove a button before its click sound")
button.Active = false
button.Activated:Fire()
flush()
assert(played == 2, "disabled controls must stay quiet")
button.Active = true
button.Activated:Fire()
dispose()
flush()
assert(played == 2, "disposed hook must not emit queued audio")

-- Execute the shared toolbar renderer; labels, chips and borders stay in its bounds.
local browse = read("src/Client/AstralForge/BrowseKit.luau")
local roblox = require("@lune/roblox")
local kit = { CHIP_H = 48, ROW_GAP = 8, ChipRow = "Chips" }
local function h(tag, props, ...)
	return { tag = tag, props = props, children = { ... } }
end
local browseEnv = setmetatable({
	Kit = kit,
	TapTarget = 48,
	UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2,
	Palette = {},
	Font = {
		fromName = function()
			return {}
		end,
	},
	Enum = { FontWeight = { Bold = {} }, TextXAlignment = { Right = {} } },
	ui = { SearchField = "Search", Dropdown = "Sort" },
	h = h,
}, { __index = getfenv(0) })
local heightStart = assert(browse:find("function Kit.barHeight", 1, true))
local heightEnd = assert(browse:find("local function Chip", heightStart, true))
luau.load(browse:sub(heightStart, heightEnd - 1), { environment = browseEnv })()
local barStart = assert(browse:find("function Kit.BrowseBar", 1, true))
local barEnd = assert(browse:find("function Kit.NoResults", barStart, true))
luau.load(browse:sub(barStart, barEnd - 1), { environment = browseEnv })()
for _, stack in { false, true } do
	local node = kit.BrowseBar({
		stack = stack,
		browse = { sorts = { {}, {} }, categories = { {}, {} }, results = {}, total = 0 },
	})
	for _, child in node.children do
		if type(child) == "table" and child.props and child.props.position then
			local props = child.props
			assert(props.position.Y.Offset >= 0, "toolbar control starts above its row")
			assert(
				props.position.Y.Offset + props.size.Y.Offset <= node.props.Size.Y.Offset,
				"toolbar control extends below its row"
			)
		end
	end
end
print("[TEST] controller/click audio dedup, disabled/disposed controls and toolbar geometry passed")

-- Execute the production top-bar wordmark renderer so text scaling cannot
-- silently clip the game's name inside its fixed responsive slot.
local uiCore = read("src/Client/AstralForge/UiCore.luau")
local logoStart = assert(uiCore:find("local function LogoLockup(_param)", 1, true))
local logoEnd = assert(uiCore:find("\n\treturn {\n\t\tacquireDropdownPortal", logoStart, true))
local logoEnvironment = setmetatable({
	React = {
		createElement = function(tag, props, ...)
			if type(tag) == "function" then
				return tag(props)
			end
			return { tag = tag, props = props or {}, children = { ... } }
		end,
	},
	Color3 = {
		fromRGB = function()
			return {}
		end,
	},
	Palette = { cyan = {}, cream = {} },
	GAME_ICON_ASSET = "",
	Enum = {
		FontWeight = { Heavy = {} },
		ApplyStrokeMode = { Border = {} },
		LineJoinMode = { Round = {} },
		ScaleType = { Fit = {} },
	},
	UDim = {
		new = function()
			return {}
		end,
	},
	UDim2 = {
		new = function(...)
			return { ... }
		end,
		fromScale = function(...)
			return { ... }
		end,
		fromOffset = function(...)
			return { ... }
		end,
	},
	Text = function(props)
		return { tag = "Text", props = props }
	end,
	Vector2 = {
		new = function(...)
			return { ... }
		end,
	},
}, { __index = getfenv(0) })
local renderLogo =
	luau.load(uiCore:sub(logoStart, logoEnd - 1) .. "\nreturn LogoLockup", { environment = logoEnvironment })()
for _, variant in
	{
		{ compact = true, micro = false, expectedWordmark = true },
		{ compact = true, micro = true, expectedWordmark = false },
	}
do
	local node = renderLogo(variant)
	local wordmark
	for _, child in node.children do
		if type(child) == "table" and child.tag == "Text" then
			wordmark = child
		end
	end
	assert((wordmark ~= nil) == variant.expectedWordmark, "responsive logo variant exposes the expected wordmark")
	if wordmark then
		assert(wordmark.props.value == "ASTRAL", "top-bar branding retains the full wordmark")
		assert(
			wordmark.props.fit == true and wordmark.props.minSize == 12,
			"wordmark scales down instead of truncating"
		)
	end
end
print("[TEST] top-bar wordmark retains full branding and fits compact slots")

-- Execute the new goal renderer with portrait, landscape and desktop panel bounds.
local goalSource = read("src/Client/AstralForge/GoalSummary.luau")
local goalStart = assert(goalSource:find("return function(props)", 1, true))
local measuredSize = roblox.Vector2.new(800, 120)
local goalEnvironment = setmetatable({
	React = {
		createElement = h,
		useRef = function()
			return {}
		end,
		useState = function()
			return measuredSize, function() end
		end,
		useEffect = function() end,
	},
	ui = { Text = "Text", Meter = "Meter", Button = "Button" },
	Palette = {},
	Vector2 = roblox.Vector2,
	UDim2 = roblox.UDim2,
	Enum = {
		FontWeight = { Bold = {}, Heavy = {} },
		TextXAlignment = { Right = {} },
	},
}, { __index = getfenv(0) })
local renderGoal = luau.load(goalSource:sub(goalStart), { environment = goalEnvironment })()
for _, dimensions in
	{
		roblox.Vector2.new(280, 192),
		roblox.Vector2.new(550, 168),
		roblox.Vector2.new(800, 116),
		roblox.Vector2.new(1200, 128),
	}
do
	measuredSize = dimensions
	for _, hasAction in { false, true } do
		local node = renderGoal({
			title = "Build your next machine",
			body = "Compare machine returns before buying.",
			cta = if hasAction then "Open Workshop" else "",
			action = if hasAction then function() end else nil,
			progress = 0.5,
			value = "50%",
			label = "Progress",
		})
		local children = node.children[1]
		for _, child in children do
			local props = child.props
			local position = props.position or roblox.UDim2.new()
			local size = props.sizeConstraint or props.size
			local top = position.Y.Scale * dimensions.Y + position.Y.Offset
			local bottom = top + size.Y.Scale * dimensions.Y + size.Y.Offset
			assert(top >= 0 and bottom <= dimensions.Y + 1, "goal content exceeds its panel")
		end
		local description = children.Description.props
		local meter = children.Progress.props
		assert(
			description.position.Y.Offset + description.sizeConstraint.Y.Offset <= meter.position.Y.Offset,
			"goal description overlaps progress"
		)
		if hasAction then
			assert(children.Action.props.size.Y.Offset == 48, "goal action needs a full touch target")
		end
	end
end
print("[TEST] goal summary fits mobile and desktop with separate progress and full touch targets")
