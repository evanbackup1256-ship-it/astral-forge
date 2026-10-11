local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local callback, connects, disconnects = nil, 0, 0
local guiService = { ReducedMotionEnabled = false }
local function node(class, parent)
	local object = {
		ClassName = class, Parent = parent, Visible = true, Enabled = true,
		ImageTransparency = 0, GroupTransparency = 0, ClipsDescendants = false,
		AbsolutePosition = roblox.Vector2.new(10, 10), AbsoluteSize = roblox.Vector2.new(80, 80),
	}
	function object:IsA(kind)
		return kind == self.ClassName or (kind == "GuiObject" and (self.ClassName == "ImageLabel" or self.ClassName == "Frame" or self.ClassName == "CanvasGroup"))
			or (kind == "LayerCollector" and (self.ClassName == "ScreenGui" or self.ClassName == "BillboardGui"))
	end
	return object
end
local playerGui = node("PlayerGui")
local screen = node("ScreenGui", playerGui)
local camera = { ViewportSize = roblox.Vector2.new(359, 718) }
local runtime = luau.load(fs.readFile("src/Client/AstralForge/CompanionPlayback.luau"), {
	environment = setmetatable({
		game = { GetService = function(_, name)
			if name == "GuiService" then return guiService end
			assert(name == "RunService")
			return { RenderStepped = { Connect = function(_, handler)
				callback = handler; connects += 1
				return { Disconnect = function() disconnects += 1; callback = nil end }
			end } }
		end },
		workspace = { CurrentCamera = camera }, Vector2 = roblox.Vector2,
	}, { __index = _G }),
})()
local group = node("CanvasGroup", screen)
local label = node("ImageLabel", group)
assert(runtime.visible(label))
group.Visible = false; assert(not runtime.visible(label)); group.Visible = true
group.GroupTransparency = 1; assert(not runtime.visible(label)); group.GroupTransparency = 0
screen.Enabled = false; assert(not runtime.visible(label)); screen.Enabled = true
label.ImageTransparency = 1; assert(not runtime.visible(label)); label.ImageTransparency = 0
label.AbsolutePosition = roblox.Vector2.new(400, 10); assert(not runtime.visible(label))
label.AbsolutePosition = roblox.Vector2.new(10, 10)
group.ClipsDescendants = true; group.AbsolutePosition = roblox.Vector2.new(200, 200)
assert(not runtime.visible(label)); group.ClipsDescendants = false
label.Parent = node("BillboardGui", playerGui); assert(not runtime.visible(label)); label.Parent = group

local handles, labels = {}, {}
for i = 1, 150 do
	local image = node("ImageLabel", screen)
	labels[i] = image
	handles[i] = runtime.register(image, 6, 36, roblox.Vector2.new(170.5, 170.5), 12)
end
assert(connects == 1 and runtime.snapshot().Registered == 150)
callback(1 / 60)
assert(runtime.snapshot().Active == 24)
local seen = {}
local admitted = labels[1]
local firstCrop = admitted.ImageRectOffset
callback(0.15)
assert(admitted.ImageRectOffset ~= firstCrop, "visible admitted cards animate continuously, not in rotating bursts")
for i = 1, 126 do labels[i].Visible = false end
for _ = 1, 15 do
	callback(0.15)
	for i, image in labels do if image.ImageRectOffset then seen[i] = true end end
end
assert(seen[150], "bounded admission reaches later cards after scrolling")
screen.Enabled = false
local before = {}
for i, image in labels do before[i] = image.ImageRectOffset end
callback(0.2)
assert(runtime.snapshot().Active == 0)
for i, image in labels do assert(image.ImageRectOffset == before[i], "hidden layers stop crop writes") end
screen.Enabled = true
guiService.ReducedMotionEnabled = true
callback(0.2)
assert(runtime.snapshot().Active == 0, "platform reduced motion stops admitted cards")
guiService.ReducedMotionEnabled = false
callback(0.2)
assert(runtime.snapshot().Active > 0, "animation resumes when platform preference changes")
for _, handle in handles do handle.release(); handle.release() end
assert(disconnects == 1 and not runtime.snapshot().Connected and runtime.snapshot().Registered == 0)
local handle = runtime.register(label, 6, 36, roblox.Vector2.new(170.5, 170.5), 12)
callback(0.1)
assert(label.ImageRectOffset == roblox.Vector2.new(170.5, 0), "exact atlas crop at frame one")
handle.setRate(24)
callback(0.05)
assert(label.ImageRectOffset == roblox.Vector2.new(511.5, 0), "rate updates use shared timeline")
label.Parent = nil
local last = label.ImageRectOffset
callback(0.1); assert(label.ImageRectOffset == last, "detached labels stop immediately")
handle.release()
assert(connects == 2 and disconnects == 2)
print("[TEST] companion playback: single clock, 24-layer cap, bounded fair admission, clipping/visibility, crop math and idempotent disposal passed")
