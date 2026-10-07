local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local sourceRoot = process.args[1]
local function read(path)
	local target = if sourceRoot then sourceRoot .. "/" .. path else path
	return fs.readFile(target):gsub("\r\n", "\n")
end
local function slice(source, first, last)
	local start = assert(source:find(first, 1, true))
	local finish = assert(source:find(last, start, true))
	return source:sub(start, finish - 1)
end
local inherited = getfenv(0)

-- Render the real atlas face with incomplete or newly introduced icon names.
local art = read("src/Client/AstralForge/ArtKit.luau")
local atlas = slice(art, "local VECTOR_ICON_ATLAS", "local ITEM_ICONS")
local function binding(value)
	return {
		map = function(_, callback)
			return callback(value)
		end,
	}
end
local icon =
	luau.load(atlas .. "return { index = vectorIconIndex, direction = vectorIconDirection, face = VectorIconFace }", {
		environment = setmetatable({
			React = {
				createElement = function(tag, props)
					return { tag = tag, props = props }
				end,
				useMemo = function(callback)
					return callback()
				end,
			},
			useExitPresence = function()
				return binding(1)
			end,
			fadeWithPresence = function(value)
				return value
			end,
			UDim2 = roblox.UDim2,
			Vector2 = roblox.Vector2,
			Enum = { ScaleType = { Stretch = "Stretch" } },
		}, { __index = inherited }),
	})()
for _, kind in { "Core", "Admin", "Gift", "Overcharge", "", "NotAnIcon", false, 12 } do
	local node = icon.face({ kind = kind, color = roblox.Color3.new(1, 1, 1) })
	assert(node.props.ImageRectOffset.X >= 0 and node.props.ImageRectOffset.Y >= 0)
	assert(math.abs(icon.direction(kind)) == 1)
end
assert(icon.index(nil) == icon.index("Guide"), "missing icon must have a valid atlas fallback")
assert(icon.index("Core") == 2 and icon.index("Admin") == 44, "existing atlas indices must remain stable")
icon.face({})

-- Execute the actual message render prelude with missing/invalid author IDs.
local social = read("src/Client/AstralForge/pages/PagesSocial.luau")
local periods = {}
local messageEnvironment = setmetatable({
	TAG_COLORS = { "cyan", "mint", "violet", "mango", "pink", "blue" },
	Palette = { mango = "mango" },
	useMessageEntrance = function()
		return binding(1)
	end,
	usePulse = function(_, period)
		table.insert(periods, period)
	end,
}, { __index = inherited })
local colorSource = slice(social, "local function userColor", "local function useMessageEntrance")
local rowSource = slice(social, "local function MessageRow", "local fade = enter:map")
local renderPrelude = luau.load(colorSource .. rowSource .. "return accent end return MessageRow", {
	environment = messageEnvironment,
})()
for _, message in
	{ { system = true }, {}, { userId = "24" }, { userId = false }, { userId = math.huge }, { userId = 0 / 0 } }
do
	assert(renderPrelude({ message = message }) ~= nil, "message must render without nil modulo")
end
for _, period in periods do
	assert(period == period and period >= 2.4 and period <= 3)
end

local hosts = read("src/Client/AstralForge/ReactHosts.luau")
local boundarySource = slice(hosts, "function PageErrorBoundary:componentDidCatch", "function PageErrorBoundary:render")
local messages = {}
local boundary = luau.load("local PageErrorBoundary = {}\n" .. boundarySource .. "return PageErrorBoundary", {
	environment = setmetatable({
		ClientLog = {
			warnEvery = function(_, key, _, _, message)
				table.insert(messages, { key = key, message = message })
			end,
		},
	}, { __index = inherited }),
})()
boundary.componentDidCatch({ props = { page = "Admin" } }, "nil arithmetic", { componentStack = "\nIcon > AdminView" })
assert(messages[1].key == "react-page-Admin")
assert(
	messages[1].message:find("Admin: nil arithmetic", 1, true) and messages[1].message:find("Icon > AdminView", 1, true)
)
boundary.componentDidCatch({ props = {} }, "root render failed")
assert(messages[2].key == "react-page-AppShell")
assert(hosts:match("key = `{page}:{retryCount}`,%s*page = page,"), "page boundary must receive its real page name")
print("[TEST] icon/chat nil arithmetic guards and named React component error traces passed")
