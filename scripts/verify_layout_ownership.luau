local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Diagnostics = require("../src/Client/AstralForge/LayoutDiagnostics")
local Geom = require("../src/Client/AstralForge/LayoutKit")("layoutGeom")
local Plan = require("../src/Client/AstralForge/LayoutKit")("layoutGuardPlan")
local clock = 0
local diagnostics = Diagnostics.new(function() return clock end)
local writes = {}
local function instance(class, name, parent, attributes, properties)
	local backing = properties or {}
	backing.Name, backing.Parent = name, parent
	backing.AbsolutePosition = backing.AbsolutePosition or roblox.Vector2.new(0, 0)
	backing.AbsoluteSize = backing.AbsoluteSize or roblox.Vector2.new(200, 100)
	backing.Visible = if backing.Visible == nil then true else backing.Visible
	backing.Children = backing.Children or {}
	local object = setmetatable({}, {
		__index = backing,
		__newindex = function(_, key, value) backing[key] = value; table.insert(writes, key) end,
	})
	backing.IsA = function(_, wanted)
		return class == wanted or (wanted == "GuiObject" and class ~= "ScreenGui" and class ~= "SurfaceGui" and class ~= "PlayerGui")
			or (wanted == "GuiButton" and (class == "TextButton" or class == "ImageButton"))
			or (wanted == "LayerCollector" and (class == "ScreenGui" or class == "SurfaceGui"))
	end
	backing.GetAttribute = function(_, key) return attributes and attributes[key] end
	backing.GetFullName = function() return (if parent then parent:GetFullName() .. "." else "") .. name end
	backing.GetChildren = function() return backing.Children end
	backing.FindFirstChildOfClass = function(_, wanted)
		for _, child in backing.Children do if child:IsA(wanted) then return child end end
	end
	return object, backing
end
local root = instance("ScreenGui", "Root", nil, nil, { Enabled = true })
local panel, panelBacking = instance("Frame", "Card", root, { LayoutOwner = "InventoryCard" }, { ClipsDescendants = true })
local label = instance("TextLabel", "Title", panel, nil, {
	Text = "A long readable inventory label", TextFits = false, TextScaled = false,
	TextWrapped = false, TextSize = 14, AbsoluteSize = roblox.Vector2.new(120, 24), TextBounds = roblox.Vector2.new(240, 18),
})
assert(Diagnostics.visible(label) and Diagnostics.owner(label) == "InventoryCard")
panelBacking.Visible = false
assert(not Diagnostics.visible(label), "hidden ancestor excludes its text")
panelBacking.Visible = true
local offscreen = instance("TextLabel", "ScrolledAway", panel, nil, { AbsolutePosition = roblox.Vector2.new(0, 200) })
assert(not Diagnostics.visible(offscreen), "clipped offscreen rows are not false-positive defects")
local decoration = instance("Frame", "Glow", panel, { LayoutGuardIgnore = true })
assert(not Diagnostics.visible(instance("TextLabel", "Glyph", decoration)), "intentional decorations are excluded by ancestor")
local disabledSurface = instance("SurfaceGui", "InactiveVR", nil, nil, { Enabled = false })
assert(not Diagnostics.visible(instance("Frame", "Content", disabledSurface)), "disabled world-space layers are excluded")
assert(diagnostics:record(label, "TextOverflow", "observed"))
clock = 1
assert(not diagnostics:record(label, "TextOverflow", "observed again"))
local snapshot = diagnostics:snapshot()
assert(snapshot.Total == 1 and snapshot.Issues[1].Samples == 2 and snapshot.Issues[1].Owner == "InventoryCard")
assert(diagnostics:observations() == 2, "deduplicated recurring defects still drive inspection priority")
snapshot.Issues[1].Detail = "tampered"
assert(diagnostics:snapshot().Issues[1].Detail == "observed again", "diagnostics copies do not alter internal state")
for index = 1, 300 do diagnostics:record(instance("Frame", tostring(index), panel), "Overflow", "fixture") end
assert(#diagnostics:snapshot().Issues == 128, "diagnostics remain bounded under a defective large tree")
diagnostics:beginPairs(2)
for _ = 1, 256 do assert(diagnostics:pairAllowed()) end
assert(not diagnostics:pairAllowed(), "collision comparisons are capped per frame")
diagnostics:beginPairs(2)
clock = 2
assert(not diagnostics:pairAllowed(), "collision work respects the deadline")
diagnostics:reset()
assert(#diagnostics:snapshot().Issues == 0 and diagnostics:snapshot().Epoch == 1)

local source = fs.readFile("src/Client/AstralForge/layoutGuard.luau")
assert(not source:find("TextScaled = true", 1, true) and not source:find("TextTruncate = ", 1, true)
	and not source:find("MinTextSize =", 1, true), "guard never shrinks, truncates or installs text constraints")
assert(not source:find("group.Position =", 1, true) and not source:find("button.Size =", 1, true)
	and not source:find("solid.Position =", 1, true), "motion and component geometry remain owned")
assert(not source:find("self.pendingOverlap and not IS_STUDIO", 1, true), "live clients must run bounded collision passes")
assert(source:find('"Size", "Visible"', 1, true), "owner size and visibility changes trigger revalidation without animation storms")
assert(source:find('"SmallTouchTarget"', 1, true) and source:find('"ActionOutsideViewport"', 1, true),
	"touch size and viewport reachability are diagnosed")
local first = assert(source:find("local interactionLayer", 1, true))
local last = assert(source:find("local function checkOverlappingHitboxes(", first, true))
local stats, tryCount = {
	actionCollisions = 0, actionsOutsideParent = 0, clippedActions = 0, smallTouchTargets = 0,
	actionsOutsideViewport = 0, nestedScrollConflicts = 0, textUnderButtonSeen = 0,
}, {}
local touch = { TouchEnabled = false }
local repairText, repairScrollingFrame, repairButton = luau.load(source:sub(first, last - 1)
	.. "\nreturn repairText, repairScrollingFrame, repairButton", {
	environment = setmetatable({
		diagnostics = diagnostics, Diagnostics = Diagnostics, Geom = Geom, Plan = Plan,
		abandoned = {}, tryCount = tryCount, IGNORE_ATTRIBUTE = "LayoutGuardIgnore", stats = stats,
		Enum = roblox.Enum, UDim2 = roblox.UDim2, FIT_SLOP = 6, WILD_ASPECT_SLOP = 2,
		MIN_TOUCH_TARGET = 44,
		UserInputService = touch,
		isFiniteNumber = function(n) return n == n and math.abs(n) ~= math.huge end,
		rectOf = function(o)
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			return { x0 = p.X, y0 = p.Y, x1 = p.X + s.X, y1 = p.Y + s.Y }
		end,
		engineOwns = function() return false end,
		allowWrite = function(o) return Diagnostics.canRecover(o, "Canvas") end,
		ClientLog = { warnEvery = function() end },
	}, { __index = _G }),
})()
table.clear(writes)
for _ = 1, 30 do repairText(label) end
assert(#writes == 0 and diagnostics:snapshot().Issues[1].Kind == "TextOverflow",
	"repeated overflow diagnoses but does not change font, size, position or wrapping")
local function scroll(attributes, canvas)
	local child = instance("Frame", "BottomRow", nil, nil, {
		AbsolutePosition = roblox.Vector2.new(0, 200), AbsoluteSize = roblox.Vector2.new(200, 50),
	})
	return instance("ScrollingFrame", "List", panel, attributes, {
		ScrollingEnabled = true, AutomaticCanvasSize = roblox.Enum.AutomaticSize.None,
		CanvasSize = canvas, CanvasPosition = roblox.Vector2.new(0, 0), Children = { child },
	})
end
local ordinary = scroll(nil, roblox.UDim2.fromOffset(0, 100))
table.clear(writes)
diagnostics:reset()
repairScrollingFrame(ordinary)
assert(#writes == 0 and diagnostics:snapshot().Issues[1].Kind == "CanvasOverflow",
	"short ordinary canvas diagnoses underflow without changing owner geometry")
local scoped = scroll({ LayoutGuardRecovery = "Canvas" }, roblox.UDim2.fromOffset(0, 100))
stats.canvasDesyncFixed = 0
repairScrollingFrame(scoped)
assert(scoped.CanvasSize.Y.Offset == 250 and stats.canvasDesyncFixed == 1, "explicit Canvas opt-in receives only canvas recovery")
table.clear(writes)
diagnostics:reset()
repairScrollingFrame(scroll(nil, roblox.UDim2.new(0, 0, 3, 0)))
assert(#writes == 0 and #diagnostics:snapshot().Issues == 0,
	"sufficient scaled canvas must not report a fabricated overflow")
repairScrollingFrame(scroll(nil, roblox.UDim2.fromOffset(0, 248)))
assert(diagnostics:snapshot().Issues[1].Kind == "CanvasOverflow", "a short canvas cannot hide up to 24px of real content")
table.clear(writes)
repairScrollingFrame(scroll({ LayoutGuardRecovery = "FloatingPanel" }, roblox.UDim2.fromOffset(0, 100)))
assert(#writes == 0, "FloatingPanel opt-in cannot authorize Canvas writes")
local horizontal, horizontalBacking = scroll({ LayoutGuardRecovery = "Canvas" }, roblox.UDim2.fromOffset(100, 80))
horizontalBacking.ScrollingDirection = roblox.Enum.ScrollingDirection.X
horizontalBacking.CanvasPosition = roblox.Vector2.new(50, 0)
horizontalBacking.Children = {
	instance("Frame", "RightRow", nil, nil, {
		AbsolutePosition = roblox.Vector2.new(300, 0), AbsoluteSize = roblox.Vector2.new(150, 20),
	}),
}
stats.canvasDesyncFixed = 0
diagnostics:reset()
repairScrollingFrame(horizontal)
assert(horizontal.CanvasSize.X.Offset == 500 and horizontal.CanvasSize.Y.Offset == 80,
	"horizontal recovery accounts for scroll position and preserves the non-scrolling axis")
local fitting, fittingBacking = scroll(nil, roblox.UDim2.new())
fittingBacking.Children = {
	instance("Frame", "InsideViewport", nil, nil, { AbsoluteSize = roblox.Vector2.new(100, 50) }),
}
diagnostics:reset()
repairScrollingFrame(fitting)
assert(#diagnostics:snapshot().Issues == 0, "content inside the viewport does not require a larger canvas")
local padded, paddedBacking = scroll({ LayoutGuardRecovery = "Canvas" }, roblox.UDim2.fromOffset(0, 250))
paddedBacking.Children = {
	instance("UIPadding", "Padding", nil, nil, {
		PaddingBottom = roblox.UDim.new(0, 12), PaddingRight = roblox.UDim.new(0, 0),
	}),
	instance("UIListLayout", "Layout", nil, nil, { AbsoluteContentSize = roblox.Vector2.new(200, 200) }),
	instance("Frame", "OffsetRow", nil, nil, {
		AbsolutePosition = roblox.Vector2.new(0, 230), AbsoluteSize = roblox.Vector2.new(200, 50),
	}),
}
repairScrollingFrame(padded)
assert(padded.CanvasSize.Y.Offset == 292, "layout content summaries cannot hide positioned rows and trailing padding")
assert(not Diagnostics.canRecover(label, "Canvas") and not Diagnostics.canRecover(scoped, "FloatingPanel"),
	"recovery kinds do not cross surfaces")
local allowFirst = assert(source:find("local function allowWrite(", 1, true))
local allowLast = assert(source:find("local function isFloatingPanel(", allowFirst, true))
local retries, abandonedRecovery = {}, {}
local recoveryStats = { gaveUp = 0 }
local allowWrite = luau.load(source:sub(allowFirst, allowLast - 1) .. "\nreturn allowWrite", {
	environment = setmetatable({
		Diagnostics = Diagnostics, diagnostics = diagnostics, stats = recoveryStats,
		tryCount = retries, abandoned = abandonedRecovery, MAX_TRIES = Plan.MAX_TRIES,
		suppressed = function() return false end, noteThrash = function() end,
	}, { __index = _G }),
})()
assert(not allowWrite(ordinary), "unmarked components cannot enter scoped recovery")
for _ = 1, Plan.MAX_TRIES do assert(allowWrite(scoped)) end
diagnostics:reset()
assert(not allowWrite(scoped) and abandonedRecovery[scoped] and recoveryStats.gaveUp == 1)
assert(diagnostics:snapshot().Issues[1].Kind == "OwnerConflict",
	"owners repeatedly undoing scoped recovery receive a bounded explicit conflict")

local collisionEnd = assert(source:find("local inspectOnce", last, true))
local checkHitboxes = luau.load(source:sub(last, collisionEnd - 1) .. "\nreturn checkOverlappingHitboxes", {
	environment = setmetatable({
		diagnostics = diagnostics, Diagnostics = Diagnostics, Plan = Plan, stats = stats,
		IGNORE_ATTRIBUTE = "LayoutGuardIgnore",
		isTrackedClass = function() return true end,
		interactionLayer = function(o)
			local current = o.Parent
			while current and not current:IsA("LayerCollector") do current = current.Parent end
			return current
		end,
		isAncestorOf = function(ancestor, o)
			local current = o.Parent
			while current do if current == ancestor then return true end; current = current.Parent end
			return false
		end,
		rectOf = function(o)
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			return { x0 = p.X, y0 = p.Y, x1 = p.X + s.X, y1 = p.Y + s.Y }
		end,
		rectArea = function(r) return (r.x1 - r.x0) * (r.y1 - r.y0) end,
		overlapArea = function(a, b)
			return math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0))
				* math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0))
		end,
	}, { __index = _G }),
})()
local actions = {}
local actionHost = instance("Frame", "Actions", root)
for index = 1, 40 do
	actions[index] = instance("TextButton", "Action" .. index, actionHost, nil, {
		Active = true, ZIndex = 1,
		AbsolutePosition = roblox.Vector2.new((if index == 40 then 39 else index) * 300, 0),
		AbsoluteSize = roblox.Vector2.new(48, 40),
	})
end
diagnostics:reset()
local worker = coroutine.create(function() checkHitboxes(actions) end)
local frames = 0
repeat
	frames += 1
	diagnostics:beginPairs(clock + 1)
until diagnostics:runWork(worker) or frames > 20
assert(coroutine.status(worker) == "dead" and frames <= 20,
	"spatial collision groups complete within bounded frames without restarting")
local found = false
for _, issue in diagnostics:snapshot().Issues do
	if issue.Kind == "ActionCollision" and issue.Path:find("Action39", 1, true) then found = true end
end
assert(found, "late siblings beyond the first 256 comparisons must be inspected")
local wrapperA = instance("Frame", "WrapperA", root)
local wrapperB = instance("Frame", "WrapperB", root)
local nestedA = instance("TextButton", "NestedA", wrapperA, nil, {
	Active = true, ZIndex = 5, AbsolutePosition = roblox.Vector2.new(100, 100), AbsoluteSize = roblox.Vector2.new(100, 60),
})
local nestedB = instance("TextButton", "NestedB", wrapperB, nil, {
	Active = true, ZIndex = 5, AbsolutePosition = roblox.Vector2.new(165, 100), AbsoluteSize = roblox.Vector2.new(100, 60),
})
diagnostics:reset()
local nestedWorker = coroutine.create(function() checkHitboxes({ nestedA, nestedB }) end)
repeat diagnostics:beginPairs(clock + 1) until diagnostics:runWork(nestedWorker)
assert(diagnostics:snapshot().Issues[1] and diagnostics:snapshot().Issues[1].Kind == "ActionCollision",
	"buttons in separate wrappers with substantial overlap must be detected")
local resumed = false
local blockedWorker = coroutine.create(function() resumed = true end)
diagnostics:beginPairs(clock)
assert(not diagnostics:runWork(blockedWorker) and not resumed, "expired deadlines do not resume collision work")
local bindFirst = assert(source:find("\tfunction LayoutGuardController:bindRoot(root)", 1, true))
local bindLast = assert(source:find("\tfunction LayoutGuardController:checkResize(root)", bindFirst, true))
local callbacks = {}
local function signal()
	return { Connect = function(_, fn)
		table.insert(callbacks, fn)
		return { Disconnect = function() end }
	end }
end
local playerGui = instance("PlayerGui", "PlayerGui", nil)
playerGui.ChildAdded, playerGui.ChildRemoved = signal(), signal()
root.FindFirstAncestorOfClass = function(_, name) return if name == "PlayerGui" then playerGui else nil end
root.GetPropertyChangedSignal = function() return signal() end
root.Destroying = signal()
local binder = luau.load("local LayoutGuardController={}\n" .. source:sub(bindFirst, bindLast - 1)
	.. "\nreturn LayoutGuardController", {
	environment = setmetatable({
		diagnostics = diagnostics, stats = stats, IGNORE_ATTRIBUTE = "LayoutGuardIgnore",
		Instance = { new = function()
			return { Destroy = function(o) o.Parent = nil; o.destroyed = true end }
		end },
	}, { __index = _G }),
})()
local bound = setmetatable({
	rootConnections = {}, geometryConnections = {}, geometryUsers = {}, trackedAncestors = {}, geometryReadyAt = {},
	layerConnections = {}, watchedLayers = {}, fresh = {}, freshReady = {}, freshSet = {},
	freshScratch = {}, freshReadyScratch = {}, cursor = 1, pendingOverlap = false, overlapPhase = 1,
	tracked = {}, trackedIndex = {},
	watchLayer = function(self) self.tracked[1] = label end,
	checkResize = function() end,
}, { __index = binder })
bound:bindRoot(root)
local endpoint = bound.diagnosticEndpoint
assert(endpoint.Parent == playerGui and endpoint.Name == "AstralForgeLayoutDiagnostics",
	"diagnostic endpoint is outside React-owned root descendants")
assert(endpoint.OnInvoke().Tracked == 1, "endpoint reads the actual bound controller")
bound.tracked[2] = label
assert(endpoint.OnInvoke().Tracked == 2, "endpoint does not expose a stale cloned controller")
bound:bindRoot(nil)
assert(endpoint.destroyed and bound.diagnosticEndpoint == nil, "root rebind retires the endpoint")
local ui = fs.readFile("src/Client/AstralForge/UiCore.luau")
local textFirst = assert(ui:find("local fontFaceCache = {}", 1, true))
local textLast = assert(ui:find("local function useGuiSize(", textFirst, true))
local textScale = 1
local Text = luau.load(ui:sub(textFirst, textLast - 1) .. "\nreturn Text", {
	environment = setmetatable({
		Enum = roblox.Enum, UDim2 = roblox.UDim2, Font = { fromEnum = function(font) return font end },
		Palette = { cream = roblox.Color3.new(1, 1, 1), void = roblox.Color3.new() },
		MIN_UI_TEXT_SIZE = 10,
		useMotionSettings = function() return { textScale = textScale, boldText = 0 } end,
		useExitPresence = function() return nil end,
		withExitFade = function() return { map = function(_, fn) return fn(0) end } end,
		React = {
			useMemo = function(fn) return fn() end,
			createElement = function(class, props, ...)
				return { class = class, props = props, children = { ... } }
			end,
		},
	}, { __index = _G }),
})()
for _, scale in { 0.8, 1, 1.5 } do
	textScale = scale
	local rendered = Text({ value = "Essential title", size = 20, fit = true, minSize = 8 })
	local face = rendered.children[2]
	assert(face.props.TextTruncate == roblox.Enum.TextTruncate.None)
	assert(face.children[1].props.MinTextSize >= 12 and face.children[1].props.MaxTextSize == face.props.TextSize,
		"shared essential text never shrinks below its readable local floor")
end
local pinFirst = assert(ui:find("local function pinButtonLabel(", 1, true))
local pinLast = assert(ui:find("local function pinLayoutGuardIgnore(", pinFirst, true))
local pin = luau.load(ui:sub(pinFirst, pinLast - 1) .. "\nreturn pinButtonLabel")()
local buttonLabel = {}
pin(buttonLabel)
assert(buttonLabel.Name == "ButtonLabel", "important button labels remain inspectable, not guard-ignored")
print("[TEST] layout ownership: no global mutations, scoped recovery, bounded diagnostics, resumable late-sibling collision checks and deadlines passed")
