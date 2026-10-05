local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Vector2 = require("@lune/roblox").Vector2

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			callbacks[callback] = true
			return {
				Disconnect = function()
					callbacks[callback] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for callback in table.clone(callbacks) do
				callback(...)
			end
		end,
	}
end

local ended, began, changed, stepped = signal(), signal(), signal(), signal()
local hits = {}
local inputService = {
	InputBegan = began,
	InputChanged = changed,
	InputEnded = ended,
	MouseEnabled = true,
	GetMouseLocation = function()
		return Vector2.zero
	end,
	IsKeyDown = function()
		return false
	end,
}
local playerGui = {
	GetGuiObjectsAtPosition = function()
		return hits
	end,
}
local environment = setmetatable({
	game = {
		GetService = function(_, name)
			if name == "UserInputService" then
				return inputService
			end
			if name == "RunService" then
				return { RenderStepped = stepped }
			end
			return { LocalPlayer = {
				FindFirstChildOfClass = function()
					return playerGui
				end,
			} }
		end,
	},
	Vector2 = Vector2,
	Enum = { UserInputType = { Touch = "Touch", MouseWheel = "Wheel" } },
}, { __index = getfenv(0) })
local isolation = luau.load(fs.readFile("src/Client/AstralForge/ScrollIsolation.luau"), { environment = environment })()

local function object(ancestor, scrolling, enabled)
	local attributes = {}
	local propertyChanged = signal()
	local state = { enabled = enabled }
	local instance = {
		Parent = ancestor,
		Visible = true,
		AutomaticCanvasSize = "X",
		MouseEnter = signal(),
		MouseLeave = signal(),
		InputBegan = signal(),
		IsA = function(_, name)
			return scrolling and name == "ScrollingFrame"
		end,
		GetAttribute = function(_, key)
			return attributes[key]
		end,
		SetAttribute = function(_, key, value)
			attributes[key] = value
		end,
		GetPropertyChangedSignal = function()
			return propertyChanged
		end,
	}
	function instance:IsDescendantOf(target)
		local cursor = self.Parent
		while cursor do
			if cursor == target then
				return true
			end
			cursor = cursor.Parent
		end
		return false
	end
	return setmetatable(instance, {
		__index = function(_, key)
			return if key == "ScrollingEnabled" then state.enabled else nil
		end,
		__newindex = function(self, key, value)
			if key == "ScrollingEnabled" then
				if state.enabled ~= value then
					state.enabled = value
					propertyChanged:Fire()
				end
			else
				rawset(self, key, value)
			end
		end,
	})
end

local root = object(nil, false, false)
local outer = object(root, true, false)
local page = object(outer, true, true)
local row = object(page, true, true)
local pill = object(row, false, false)
local otherRow = object(page, true, true)
local dispose = isolation.bind(row)
assert(row:GetAttribute("AF_ScrollCapture") == true)

hits = { page, pill, row }
assert(isolation.frameAtPosition(playerGui, Vector2.zero) == row, "nested row wins over its page background")
stepped:Fire()
assert(not page.ScrollingEnabled, "hovering a pill captures the page")
assert(page:GetAttribute("AF_ScrollLocked") == true, "intentional lock must be visible to layout maintenance")
row.MouseLeave:Fire()
assert(not page.ScrollingEnabled, "a child hover transition must not release the lock")
page.ScrollingEnabled = true
assert(not page.ScrollingEnabled, "a rerender must not override active scroll ownership")

-- Execute the real layout repair function while a parent is captured.
local guardSource = fs.readFile("src/Client/AstralForge/layoutGuard.luau"):gsub("\r\n", "\n")
local first = assert(guardSource:find("local function repairScrollingFrame", 1, true))
local last = assert(guardSource:find("local function checkOverlappingHitboxes", first, true))
local repairs = 0
local repairEnvironment = setmetatable({
	IGNORE_ATTRIBUTE = "Ignore",
	Enum = { AutomaticSize = { None = "None" } },
	stats = { scrollingReenabled = 0 },
	allowWrite = function()
		repairs += 1
		return true
	end,
	ClientLog = { warnEvery = function() end },
}, { __index = getfenv(0) })
local repair = luau.load(guardSource:sub(first, last - 1) .. "return repairScrollingFrame", {
	environment = repairEnvironment,
})()
repair(page)
assert(repairs == 0 and not page.ScrollingEnabled, "layout guard must leave captured parents alone")

hits = {}
stepped:Fire()
assert(page.ScrollingEnabled and not outer.ScrollingEnabled, "leaving restores original scrolling flags")
assert(page:GetAttribute("AF_ScrollLocked") == nil, "temporary lock attribute must be restored")

-- A touch begins on a child, crosses outside the row, and ends there.
inputService.MouseEnabled = false
hits = { page, pill }
local touch = { UserInputType = "Touch", Position = Vector2.zero }
began:Fire(touch)
hits = {}
stepped:Fire()
assert(not page.ScrollingEnabled, "child touch retains ownership outside the row")
ended:Fire(touch)
assert(page.ScrollingEnabled, "touch release restores page scrolling")

-- Two touches on separate captured rows must not unlock each other's parent.
local disposeOther = isolation.bind(otherRow)
row.InputBegan:Fire(touch)
local otherTouch = { UserInputType = "Touch", Position = Vector2.zero }
otherRow.InputBegan:Fire(otherTouch)
ended:Fire(touch)
assert(not page.ScrollingEnabled, "one row must not release another row's active lock")
disposeOther()
assert(page.ScrollingEnabled and not outer.ScrollingEnabled, "last owner restores original state")

-- Wheel input refreshes ownership before the deferred momentum router runs.
inputService.MouseEnabled = true
hits = { page, pill }
changed:Fire({ UserInputType = "Wheel" })
assert(not page.ScrollingEnabled, "wheel must capture without waiting for another render frame")
-- Exercise the actual wheel router against the same hit list and isolation binding.
local scrolling = require("./_memberfs")(fs).readFile("src/Client/AstralForge/LayoutKit.luau#scrolling")
local pointerStart = assert(scrolling:find("local function scrollingAncestor", 1, true))
local pointerEnd = assert(scrolling:find("local function frameUnderInput", pointerStart, true))
local canStart = assert(scrolling:find("local function canScrollToward", 1, true))
local canEnd = assert(scrolling:find("local ensureMotionDriver", canStart, true))
local wheelStart = assert(scrolling:find("local _arg0_1 = UserInputService.InputChanged:Connect", 1, true))
local wheelEnd = assert(scrolling:find("table.insert(globalConnections, _arg0_1)", wheelStart, true))
local queued, impulses = {}, {}
local routerEnvironment = setmetatable({
	ScrollIsolation = isolation,
	Players = { LocalPlayer = {
		FindFirstChildOfClass = function()
			return playerGui
		end,
	} },
	UserInputService = inputService,
	Vector2 = Vector2,
	Enum = {
		UserInputType = { MouseWheel = "Wheel", Gamepad1 = "Gamepad" },
		KeyCode = { LeftShift = "LeftShift", RightShift = "RightShift", Thumbstick2 = "Thumbstick2" },
		ScrollingDirection = { X = "X", XY = "XY" },
	},
	installed = true,
	scrollPreference = 0.6,
	motions = {},
	bounds = function(frame)
		return frame.maximum
	end,
	addImpulse = function(frame, delta)
		table.insert(impulses, { frame = frame, delta = delta })
	end,
	task = {
		defer = function(callback)
			table.insert(queued, callback)
		end,
	},
}, { __index = getfenv(0) })
local disconnectRouter = luau.load(
	scrolling:sub(pointerStart, pointerEnd - 1)
		.. scrolling:sub(canStart, canEnd - 1)
		.. scrolling:sub(wheelStart, wheelEnd - 1)
		.. "return function() _arg0_1:Disconnect() end",
	{ environment = routerEnvironment }
)()
row.ScrollingDirection = "X"
row.maximum = Vector2.new(500, 0)
row.CanvasPosition = Vector2.new(200, 0)
page.ScrollingDirection = "Y"
page.maximum = Vector2.new(0, 1000)
page.CanvasPosition = Vector2.new(0, 200)
local function wheel(direction)
	table.clear(impulses)
	changed:Fire({ UserInputType = "Wheel", Position = { Z = direction } })
	for _, callback in queued do
		callback()
	end
	table.clear(queued)
end
wheel(-1)
assert(
	#impulses == 1 and impulses[1].frame == row and impulses[1].delta.Y == 0,
	"wheel routes horizontally to the row only"
)
row.CanvasPosition = Vector2.new(500, 0)
wheel(-1)
assert(#impulses == 0, "right edge must consume input without scrolling the page")
row.CanvasPosition = Vector2.zero
wheel(1)
assert(#impulses == 0, "left edge must consume input without scrolling the page")
hits = { page }
wheel(-1)
assert(
	#impulses == 1 and impulses[1].frame == page and impulses[1].delta.X == 0,
	"outside the row page scrolling resumes immediately"
)
local embedded = object(page, true, false)
hits = { embedded, page }
wheel(-1)
assert(#impulses == 1 and impulses[1].frame == page, "disabled embedded lists must retain normal page scrolling")
disconnectRouter()
hits = { pill }
stepped:Fire()
dispose()
assert(page.ScrollingEnabled and not outer.ScrollingEnabled, "unmount restores ancestor state")
assert(row:GetAttribute("AF_ScrollCapture") == nil, "unmount restores capture attribute")
row.MouseEnter:Fire()
assert(page.ScrollingEnabled, "disposed signals cannot lock scrolling")
print("[TEST] Ready row routing, layout guard, rerenders, touch ownership and cleanup passed")
