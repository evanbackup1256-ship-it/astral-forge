local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
local Reflect = core.Reflect
local Controller = core.Controller
local ClientLog = require(script.Parent.log).ClientLog
-- Type-only: erased at compile time, so this does NOT become a runtime require("./framework")
-- and cannot participate in the circular require that framework/index.ts's "side effect"
-- import of this file would otherwise create (framework/index.ts -> layoutGuard.ts -> back to
-- framework/index.ts). Keep this a `import type` — switching it to a value import would
-- reintroduce that cycle.
-- Layout guard for a UI-only game.
-- React and the engine layout objects already place almost everything. This pass
-- only repairs what they leave behind, and it refuses to fight them:
--   * text that spills its box, and buttons clipped on a wild aspect ratio
--   * CanvasGroup positions that land on a fractional pixel (that is what blurs them)
--   * a scrolling canvas that is shorter than its content
-- It walks a small slice of the tree per tick, writes a property only when the
-- measured defect is still there, and gives up if a write does not stick. That
-- keeps the screen from flickering and keeps AbsoluteSize reads off the hot path.
local Geom = require(script.Parent.layoutGeom)
local SCAN_INTERVAL_SECONDS = 2
local IGNORE_ATTRIBUTE = "LayoutGuardIgnore"
local SLICE_BUDGET = 280
local FIT_SLOP = 6
local WILD_ASPECT_SLOP = 2
local MAX_TRIES = 3
local CANVAS_SHARP_EDGE = 512
local stats = {
	scans = 0,
	canvasDesyncFixed = 0,
	scrollingReenabled = 0,
	degenerateHidden = 0,
	overlapDemoted = 0,
	outOfBoxFixed = 0,
	textFitFixed = 0,
	canvasSharpFixed = 0,
	gaveUp = 0,
}
local tryCount = setmetatable({}, { __mode = "k" })
local abandoned = setmetatable({}, { __mode = "k" })
local function isFiniteNumber(value)
	return value == value and value ~= math.huge and value ~= -math.huge
end
local function rectOf(object)
	local pos = object.AbsolutePosition
	local size = object.AbsoluteSize
	return {
		x0 = pos.X,
		y0 = pos.Y,
		x1 = pos.X + size.X,
		y1 = pos.Y + size.Y,
	}
end
local function overlapArea(a, b)
	local x = math.max(0, math.min(a.x1, b.x1) - math.max(a.x0, b.x0))
	local y = math.max(0, math.min(a.y1, b.y1) - math.max(a.y0, b.y0))
	return x * y
end
local function rectArea(rect)
	return math.max(0, rect.x1 - rect.x0) * math.max(0, rect.y1 - rect.y0)
end
local function engineOwns(gui)
	if gui:FindFirstChildOfClass("UIFlexItem") ~= nil then
		return true
	end
	local parent = gui.Parent
	if parent == nil then
		return false
	end
	for _, child in parent:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPageLayout") or child:IsA("UITableLayout") then
			return true
		end
	end
	return false
end
local function allowWrite(inst)
	if abandoned[inst] then
		return false
	end
	local tries = tryCount[inst] or 0
	if tries >= MAX_TRIES then
		abandoned[inst] = true
		stats.gaveUp += 1
		return false
	end
	tryCount[inst] = tries + 1
	return true
end
local function repairText(label)
	if abandoned[label] or label:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	if label.Text == "" or not label.Visible then
		return nil
	end
	local size = label.AbsoluteSize
	if size.X < 8 or size.Y < 8 or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
		return nil
	end
	if label.TextFits then
		tryCount[label] = nil
		return nil
	end
	if not allowWrite(label) then
		return nil
	end
	local wrote = false
	if not label.TextScaled then
		label.TextScaled = true
		wrote = true
		local constraint = label:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint == nil then
			constraint = Instance.new("UITextSizeConstraint")
			constraint.Name = "LayoutGuardTextFit"
			constraint.MinTextSize = 8
			constraint.MaxTextSize = math.clamp(label.TextSize, 8, 42)
			constraint.Parent = label
		end
	elseif not label.TextWrapped and label.TextTruncate == Enum.TextTruncate.None then
		label.TextTruncate = Enum.TextTruncate.AtEnd
		wrote = true
	end
	if wrote then
		stats.textFitFixed += 1
	else
		abandoned[label] = true
		stats.gaveUp += 1
	end
end
local function repairButton(button)
	if button:IsA("TextButton") then
		repairText(button)
	end
	if abandoned[button] or button:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	local parent = button.Parent
	if parent == nil or not parent:IsA("GuiObject") or parent:IsA("ScrollingFrame") or engineOwns(button) then
		return nil
	end
	local pad = parent:FindFirstChildOfClass("UIPadding")
	local parentSize = parent.AbsoluteSize
	local parentPos = parent.AbsolutePosition
	local left = if pad ~= nil then pad.PaddingLeft.Scale * parentSize.X + pad.PaddingLeft.Offset else 0
	local top = if pad ~= nil then pad.PaddingTop.Scale * parentSize.Y + pad.PaddingTop.Offset else 0
	local right = if pad ~= nil then pad.PaddingRight.Scale * parentSize.X + pad.PaddingRight.Offset else 0
	local bottom = if pad ~= nil then pad.PaddingBottom.Scale * parentSize.Y + pad.PaddingBottom.Offset else 0
	local box = Geom.rect(parentPos.X + left, parentPos.Y + top, parentPos.X + parentSize.X - right, parentPos.Y + parentSize.Y - bottom)
	local pos = button.AbsolutePosition
	local size = button.AbsoluteSize
	if not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
		return nil
	end
	local rect = Geom.rectFromPosSize(pos.X, pos.Y, size.X, size.Y)
	if Geom.rectWidth(box) < 8 or Geom.rectHeight(box) < 8 then
		return nil
	end
	if Geom.overflowAmount(rect, box) <= (if math.max(size.X, size.Y) < 64 then WILD_ASPECT_SLOP else FIT_SLOP) then
		tryCount[button] = nil
		return nil
	end
	if not allowWrite(button) then
		return nil
	end
	local fitted = Geom.fitRect(rect, box, button.AnchorPoint.X, button.AnchorPoint.Y, 28, 28)
	local dw = Geom.rectWidth(fitted) - size.X
	local dh = Geom.rectHeight(fitted) - size.Y
	local shift = Geom.offsetDelta(button.AnchorPoint.X, button.AnchorPoint.Y, fitted.x0 - pos.X, fitted.y0 - pos.Y, dw, dh)
	button.Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset + dw, button.Size.Y.Scale, button.Size.Y.Offset + dh)
	button.Position = UDim2.new(button.Position.X.Scale, button.Position.X.Offset + shift.x, button.Position.Y.Scale, button.Position.Y.Offset + shift.y)
	stats.outOfBoxFixed += 1
end
local function repairCanvasGroup(group)
	if abandoned[group] or group:GetAttribute(IGNORE_ATTRIBUTE) == true or engineOwns(group) then
		return nil
	end
	local size = group.AbsoluteSize
	local pos = group.AbsolutePosition
	if not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y) or not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) then
		return nil
	end
	-- Larger than the sharp raster: resizing it would fight the layout that sized it.
	if math.max(size.X, size.Y) > CANVAS_SHARP_EDGE then
		return nil
	end
	local dx = Geom.snapPixel(pos.X) - pos.X
	local dy = Geom.snapPixel(pos.Y) - pos.Y
	if math.abs(dx) < 0.05 and math.abs(dy) < 0.05 then
		tryCount[group] = nil
		return nil
	end
	if not allowWrite(group) then
		return nil
	end
	group.Position = UDim2.new(group.Position.X.Scale, group.Position.X.Offset + dx, group.Position.Y.Scale, group.Position.Y.Offset + dy)
	stats.canvasSharpFixed += 1
end
-- AutomaticCanvasSize covers most cases, but any ScrollingFrame that computes CanvasSize
-- manually can drift short of its content. Grow only; never shrink a canvas that is
-- intentionally taller for bottom padding. One frame per visit, not a full-tree walk.
local function repairScrollingFrame(descendant)
	if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
		return nil
	end
	if not descendant.ScrollingEnabled and descendant:GetAttribute("LayoutGuardAllowDisabledScroll") ~= true then
		descendant.ScrollingEnabled = true
		stats.scrollingReenabled += 1
		ClientLog:warnEvery(`layoutguard:scrolldisabled:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} had ScrollingEnabled=false with no opt-out attribute — re-enabled`)
	end
	if descendant.AutomaticCanvasSize ~= Enum.AutomaticSize.None then
		return nil
	end
	local maxBottom = 0
	for _, child in descendant:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
			local layoutContentHeight = child.AbsoluteContentSize.Y
			if isFiniteNumber(layoutContentHeight) then
				maxBottom = layoutContentHeight
			end
			break
		end
	end
	if maxBottom <= 0 then
		for _, child in descendant:GetChildren() do
			if not child:IsA("GuiObject") or not child.Visible then
				continue
			end
			local bottom = child.Position.Y.Scale * descendant.AbsoluteSize.Y + child.Position.Y.Offset + child.Size.Y.Scale * descendant.AbsoluteSize.Y + child.Size.Y.Offset
			if isFiniteNumber(bottom) then
				maxBottom = math.max(maxBottom, bottom)
			end
		end
	end
	if maxBottom <= 0 then
		return nil
	end
	local currentCanvas = descendant.CanvasSize.Y.Offset
	if currentCanvas + 24 >= maxBottom then
		tryCount[descendant] = nil
		return nil
	end
	if not allowWrite(descendant) then
		return nil
	end
	descendant.CanvasSize = UDim2.new(descendant.CanvasSize.X.Scale, descendant.CanvasSize.X.Offset, 0, math.ceil(maxBottom))
	stats.canvasDesyncFixed += 1
	ClientLog:warnEvery(`layoutguard:canvas:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} CanvasSize ({currentCanvas}px) was shorter than its content ({string.format("%.0f", maxBottom)}px) — resynced`)
end
-- Roblox already ignores hits on a GuiObject with Visible=false or Active=false, and
-- InputBegan doesn't fire on descendants covered by a higher-ZIndex sibling that also has
-- Active=true — that native occlusion is exactly what we're checking hasn't gone wrong here.
-- This only flags a *same-parent* pair since ZIndex comparisons across different parents
-- aren't meaningful, and only pairs at the same ZIndex (a deliberately layered higher-ZIndex
-- control on top of a lower one, like a close button over a card, is the normal, correct
-- pattern this app uses everywhere and must not be touched).
local function checkOverlappingHitboxes(root)
	local byParent = {}
	local list = if typeof(root) == "table" then root else root:GetDescendants()
	for _, descendant in list do
		if not descendant:IsA("GuiButton") then
			continue
		end
		if not descendant.Visible or not descendant.Active then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		local parent = descendant.Parent
		if parent == nil then
			continue
		end
		local list = byParent[parent]
		if list then
			table.insert(list, descendant)
		else
			local _arg1 = { descendant }
			byParent[parent] = _arg1
		end
	end
	for _, siblings in byParent do
		if #siblings < 2 then
			continue
		end
		for i = 0, #siblings - 1 do
			local a = siblings[i + 1]
			if a:GetAttribute(IGNORE_ATTRIBUTE) == true then
				continue
			end
			local rectA = rectOf(a)
			local areaA = rectArea(rectA)
			if areaA <= 0 then
				continue
			end
			do
				local j = i + 1
				local _shouldIncrement = false
				while true do
					if _shouldIncrement then
						j += 1
					else
						_shouldIncrement = true
					end
					if not (j < #siblings) then
						break
					end
					local b = siblings[j + 1]
					if b:GetAttribute(IGNORE_ATTRIBUTE) == true then
						continue
					end
					if a.ZIndex ~= b.ZIndex then
						continue
					end
					local rectB = rectOf(b)
					local areaB = rectArea(rectB)
					if areaB <= 0 then
						continue
					end
					local overlap = overlapArea(rectA, rectB)
					local smaller = math.min(areaA, areaB)
					if smaller <= 0 or overlap / smaller < 0.85 then
						continue
					end
					-- Same ZIndex, same parent, one almost entirely covers the other, and neither
					-- opted out: this is the shape of a real accidental stack (e.g. a row's tap
					-- target left full-width behind a narrower action button added later), not a
					-- deliberate composed layer — those always differ in ZIndex in this codebase.
					-- Fix by giving the later sibling (b, which draws on top and therefore already
					-- wins ties) priority and nudging the occluded one behind it, restoring input
					-- to whichever control the ZIndex ordering already implies should win.
					b.ZIndex = a.ZIndex + 1
					stats.overlapDemoted += 1
					ClientLog:warnEvery(`layoutguard:overlap:{a:GetFullName()}`, 30, "LayoutGuard", `{a.Name} and {b.Name} share ZIndex {a.ZIndex} and overlap {string.format("%.0f", (overlap / smaller) * 100)}% — separated so input reaches the top one`)
				end
			end
		end
	end
end
-- A Flamework controller rather than a plain module: its "root" is the same singleton
-- ScreenGui that UiRootComponent/DiagnosticsController already resolve via Components DI
-- (see framework/index.ts), so unlike most systems in this app it has no runtime constructor
-- argument Flamework's zero-arg controller instantiation would need to work around — it can
-- just ask Components for the current UiRootComponent the same way DiagnosticsController does.
local LayoutGuardController
do
	LayoutGuardController = setmetatable({}, {
		__tostring = function()
			return "LayoutGuardController"
		end,
	})
	LayoutGuardController.__index = LayoutGuardController
	function LayoutGuardController.new(...)
		local self = setmetatable({}, LayoutGuardController)
		return self:constructor(...) or self
	end
	function LayoutGuardController:constructor(components)
		self.components = components
		self.elapsed = 0
		self.queue = {}
		self.cursor = 1
		self.lastWidth = -1
		self.lastHeight = -1
	end
	function LayoutGuardController:onStart()
		self.components:onComponentAdded(function(component)
			self.target = component
			return self.target
		end, "client/framework/init@UiRootComponent")
		local _binding = self.components:getAllComponents("client/framework/init@UiRootComponent")
		local existing = _binding[1]
		if existing ~= nil then
			self.target = existing
		end
	end
	function LayoutGuardController:onTick(_dt)
		local _root = self.target
		if _root ~= nil then
			_root = _root.instance
		end
		local root = _root
		if root == nil then
			return nil
		end
		local rootSize = root.AbsoluteSize
		local resized = rootSize.X ~= self.lastWidth or rootSize.Y ~= self.lastHeight
		if resized then
			self.lastWidth = rootSize.X
			self.lastHeight = rootSize.Y
			table.clear(tryCount)
			table.clear(abandoned)
			self.queue = {}
			self.cursor = 1
		end
		self.elapsed += _dt
		if self.elapsed < SCAN_INTERVAL_SECONDS and not resized then
			return nil
		end
		self.elapsed = 0
		if self.cursor > #self.queue then
			local queue = {}
			for _, descendant in root:GetDescendants() do
				if descendant:IsA("TextLabel") or descendant:IsA("TextBox") or descendant:IsA("GuiButton") or descendant:IsA("CanvasGroup") or descendant:IsA("ScrollingFrame") then
					table.insert(queue, descendant)
				end
			end
			self.queue = queue
			self.cursor = 1
			stats.scans += 1
			checkOverlappingHitboxes(self.queue)
		end
		local budget = SLICE_BUDGET
		while budget > 0 and self.cursor <= #self.queue do
			local inst = self.queue[self.cursor]
			self.cursor += 1
			budget -= 1
			if inst.Parent == nil then
				continue
			end
			local size = inst.AbsoluteSize
			local pos = inst.AbsolutePosition
			local broken = not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y)
			if broken and inst:IsA("GuiObject") and inst.Visible and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
				inst.Visible = false
				stats.degenerateHidden += 1
				ClientLog:warnEvery(`layoutguard:degenerate:{inst:GetFullName()}`, 30, "LayoutGuard", `{inst.Name} rendered with non-finite geometry — hidden to avoid a broken/mispositioned element on screen`)
				continue
			end
			if inst:IsA("ScrollingFrame") then
				repairScrollingFrame(inst)
			elseif inst:IsA("CanvasGroup") then
				repairCanvasGroup(inst)
			elseif inst:IsA("GuiButton") then
				repairButton(inst)
			elseif inst:IsA("TextLabel") or inst:IsA("TextBox") then
				repairText(inst)
			end
		end
	end
	do
		-- (Flamework) LayoutGuardController metadata
		Reflect.defineMetadata(LayoutGuardController, "identifier", "client/layoutGuard@LayoutGuardController")
		Reflect.defineMetadata(LayoutGuardController, "flamework:parameters", { "$c:components@Components" })
		Reflect.defineMetadata(LayoutGuardController, "flamework:implements", { "$:flamework@OnStart", "$:flamework@OnTick" })
	end
end
-- (Flamework) LayoutGuardController decorators
Reflect.decorate(LayoutGuardController, "$:flamework@Controller", Controller, { {
	loadOrder = 10,
} })
local function layoutGuardStats()
	return stats
end
return {
	layoutGuardStats = layoutGuardStats,
	LayoutGuardController = LayoutGuardController,
}
