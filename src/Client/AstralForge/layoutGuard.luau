local importTsModule = require(game.ReplicatedStorage.rbxts_include.TSImport)
local core = importTsModule(game.ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out)
local Reflect = core.Reflect
local Controller = core.Controller
local UserInputService = game:GetService("UserInputService")
local ClientLog = require(script.Parent.log).ClientLog
-- Type-only: erased at compile time, so this does NOT become a runtime require("./framework")
-- and cannot participate in the circular require that framework/index.ts's "side effect"
-- import of this file would otherwise create (framework/index.ts -> layoutGuard.ts -> back to
-- framework/index.ts). Keep this a `import type` — switching it to a value import would
-- reintroduce that cycle.
-- Layout guard for a UI-only game, working in real time.
-- React and the engine layout objects already place almost everything. This pass
-- only repairs what they leave behind, and it refuses to fight them:
--   * text that spills its box, and buttons clipped on a wild aspect ratio
--   * text too small to read on a phone, raised when it still fits
--   * CanvasGroup positions that land on a fractional pixel (that is what blurs them)
--   * a scrolling canvas that is shorter than its content
-- It runs every frame on a small budget (layoutGuardPlan): anything newly mounted
-- is checked the frame after the engine measures it, a background sweep revisits
-- everything else about once a second, and a resize or rotation gets a burst so
-- the whole screen settles almost at once. It writes a property only when the
-- measured defect is still there, and gives up if a write does not stick. That
-- keeps the screen from flickering and keeps AbsoluteSize reads off the hot path.
local Geom = require(script.Parent.layoutGeom)
local Plan = require(script.Parent.layoutGuardPlan)
local usesDesktopStructure = require(script.Parent.interaction).usesDesktopStructure
local IGNORE_ATTRIBUTE = "LayoutGuardIgnore"
local FIT_SLOP = 6
local WILD_ASPECT_SLOP = 2
local MAX_TRIES = Plan.MAX_TRIES
local CANVAS_SHARP_EDGE = 512
local stats = {
	scans = 0,
	freshChecked = 0,
	sweepChecked = 0,
	bursts = 0,
	canvasDesyncFixed = 0,
	scrollingReenabled = 0,
	degenerateHidden = 0,
	overlapDemoted = 0,
	outOfBoxFixed = 0,
	textFitFixed = 0,
	textFloorRaised = 0,
	textFloorReverted = 0,
	canvasSharpFixed = 0,
	gaveUp = 0,
}
local tryCount = setmetatable({}, { __mode = "k" })
local abandoned = setmetatable({}, { __mode = "k" })
-- Labels whose size was raised for touch legibility, awaiting a fit check:
-- label -> the size React gave it.
local pendingFloor = setmetatable({}, { __mode = "k" })
local floorRejected = setmetatable({}, { __mode = "k" })
-- The guard's own follow-up checks (a raised label to verify next frame).
local followUp: ((Instance) -> ())? = nil
local touchProfile = false
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
local function isTrackedClass(instance)
	return instance:IsA("TextLabel") or instance:IsA("TextBox") or instance:IsA("GuiButton") or instance:IsA("CanvasGroup") or instance:IsA("ScrollingFrame")
end
-- Phones and tablets: raise small text to a readable size, but only when it
-- still fits its box. The raise is checked on the next frame and undone (for
-- good) if the text no longer fits.
local function applyTextFloor(label): boolean
	local original = pendingFloor[label]
	if original ~= nil then
		pendingFloor[label] = nil
		if not label.TextFits then
			label.TextSize = original
			floorRejected[label] = true
			stats.textFloorReverted += 1
		end
		return true
	end
	if floorRejected[label] or not touchProfile or not label:IsA("TextLabel") and not label:IsA("TextButton") then
		return false
	end
	local target = Plan.textFloor(touchProfile, label.TextSize, label.TextScaled)
	if target == nil or not label.TextFits then
		return false
	end
	pendingFloor[label] = label.TextSize
	label.TextSize = target
	stats.textFloorRaised += 1
	if followUp ~= nil then
		followUp(label)
	end
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
	if applyTextFloor(label) then
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
			constraint.MinTextSize = if touchProfile then 9 else 8
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
	local heldScroll = false
	if not descendant.ScrollingEnabled and descendant:GetAttribute("LayoutGuardAllowDisabledScroll") ~= true then
		heldScroll = true
		if allowWrite(descendant) then
			descendant.ScrollingEnabled = true
			stats.scrollingReenabled += 1
			ClientLog:warnEvery(`layoutguard:scrolldisabled:{descendant:GetFullName()}`, 30, "LayoutGuard", `{descendant.Name} had ScrollingEnabled=false with no opt-out attribute — re-enabled`)
		end
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
		if not heldScroll then
			tryCount[descendant] = nil
		end
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
		if descendant.Parent == nil or not descendant:IsA("GuiButton") then
			continue
		end
		if not descendant.Visible or not descendant.Active then
			continue
		end
		if descendant:GetAttribute(IGNORE_ATTRIBUTE) == true then
			continue
		end
		local parent = descendant.Parent
		local siblings = byParent[parent]
		if siblings then
			table.insert(siblings, descendant)
		else
			byParent[parent] = { descendant }
		end
	end
	for _, siblings in byParent do
		if #siblings < 2 then
			continue
		end
		for i = 1, #siblings do
			local a = siblings[i]
			local rectA = rectOf(a)
			local areaA = rectArea(rectA)
			if areaA <= 0 then
				continue
			end
			for j = i + 1, #siblings do
				local b = siblings[j]
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
				-- React may write the prop ZIndex back; give up after MAX_TRIES instead of
				-- climbing forever.
				if not allowWrite(b) then
					continue
				end
				b.ZIndex = a.ZIndex + 1
				stats.overlapDemoted += 1
				ClientLog:warnEvery(`layoutguard:overlap:{a:GetFullName()}`, 30, "LayoutGuard", `{a.Name} and {b.Name} share ZIndex {a.ZIndex} and overlap {string.format("%.0f", (overlap / smaller) * 100)}% — separated so input reaches the top one`)
			end
		end
	end
end
-- One instance: hide non-finite geometry, then the class-specific repair.
local function inspect(inst)
	if inst.Parent == nil then
		return nil
	end
	local size = inst.AbsoluteSize
	local pos = inst.AbsolutePosition
	local broken = not isFiniteNumber(size.X) or not isFiniteNumber(size.Y) or not isFiniteNumber(pos.X) or not isFiniteNumber(pos.Y)
	if broken and inst:IsA("GuiObject") and inst.Visible and inst:GetAttribute(IGNORE_ATTRIBUTE) ~= true then
		if allowWrite(inst) then
			inst.Visible = false
			stats.degenerateHidden += 1
			ClientLog:warnEvery(`layoutguard:degenerate:{inst:GetFullName()}`, 30, "LayoutGuard", `{inst.Name} rendered with non-finite geometry — hidden to avoid a broken/mispositioned element on screen`)
		end
		return nil
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
local function readTouchProfile()
	return UserInputService.TouchEnabled and not usesDesktopStructure()
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
	function LayoutGuardController:constructor(components, runtime)
		self.components = components
		self.runtime = runtime
		self.frame = 0
		self.sinceSweep = 0
		-- Fresh work: instances just mounted (or awaiting a follow-up check),
		-- each with the frame it becomes ready on.
		self.fresh = {}
		self.freshReady = {}
		self.freshSet = setmetatable({}, { __mode = "k" })
		-- The background sweep.
		self.queue = {}
		self.cursor = 1
		self.lastWidth = -1
		self.lastHeight = -1
		self.burstLeft = 0
		self.armed = false
		self.rootConnections = {}
		self.pendingOverlap = false
	end
	function LayoutGuardController:onInit()
		self.armed = true
		touchProfile = readTouchProfile()
		followUp = function(instance)
			self:enqueue(instance, Plan.SETTLE_FRAMES + 1)
		end
		local refresh = function()
			touchProfile = readTouchProfile()
		end
		UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh)
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refresh)
	end
	-- Queue one instance for a check `delay` frames from now.
	function LayoutGuardController:enqueue(instance, delay)
		if self.freshSet[instance] or not isTrackedClass(instance) then
			return nil
		end
		if #self.fresh >= Plan.FRESH_CAP then
			-- Too much at once (a whole page mounting): the sweep will get there.
			return nil
		end
		self.freshSet[instance] = true
		table.insert(self.fresh, instance)
		table.insert(self.freshReady, self.frame + (delay or Plan.SETTLE_FRAMES))
	end
	function LayoutGuardController:markDirty(instance)
		if instance ~= nil then
			tryCount[instance] = nil
			abandoned[instance] = nil
			self:enqueue(instance, Plan.SETTLE_FRAMES)
		end
	end
	function LayoutGuardController:bindRoot(root)
		for _, connection in self.rootConnections do
			connection:Disconnect()
		end
		table.clear(self.rootConnections)
		if root == nil then
			return nil
		end
		table.insert(self.rootConnections, root.DescendantAdded:Connect(function(instance)
			self:markDirty(instance)
		end))
		table.insert(self.rootConnections, root.DescendantRemoving:Connect(function(instance)
			tryCount[instance] = nil
			abandoned[instance] = nil
			pendingFloor[instance] = nil
		end))
		-- A resize is handled the frame it happens, not at the next scan.
		table.insert(self.rootConnections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:checkResize(root)
		end))
		self.lastWidth = -1
		self.lastHeight = -1
		self:checkResize(root)
	end
	-- A new screen size (window resize, rotation, keyboard): forget old caps,
	-- restart the sweep and spend a burst budget so everything settles quickly.
	function LayoutGuardController:checkResize(root)
		local size = root.AbsoluteSize
		if not Plan.resized(self.lastWidth, self.lastHeight, size.X, size.Y) then
			return false
		end
		local first = self.lastWidth < 0
		self.lastWidth = size.X
		self.lastHeight = size.Y
		if not first then
			table.clear(tryCount)
			table.clear(abandoned)
		end
		self.queue = {}
		self.cursor = 1
		self.sinceSweep = Plan.MIN_SWEEP_SECONDS
		self.pendingOverlap = false
		self.burstLeft = Plan.BURST_FRAMES
		stats.bursts += 1
		return true
	end
	function LayoutGuardController:onStart()
		self.components:onComponentAdded(function(component)
			self.target = component
			self:bindRoot(component.instance)
			return self.target
		end, "client/framework/init@UiRootComponent")
		local _binding = self.components:getAllComponents("client/framework/init@UiRootComponent")
		local existing = _binding[1]
		if existing ~= nil then
			self.target = existing
			self:bindRoot(existing.instance)
		end
	end
	-- Fresh work whose settle frame has come, oldest first, up to `budget`.
	function LayoutGuardController:drainFresh(budget)
		local fresh = self.fresh
		local ready = self.freshReady
		if #fresh == 0 or budget <= 0 then
			return nil
		end
		-- Nothing due yet (the common frame while a batch is still settling): skip the
		-- two table allocations below.
		local anyDue = false
		for index = 1, #fresh do
			if ready[index] <= self.frame then
				anyDue = true
				break
			end
		end
		if not anyDue then
			return nil
		end
		local keptItems = {}
		local keptReady = {}
		local done = 0
		for index = 1, #fresh do
			local instance = fresh[index]
			if done < budget and ready[index] <= self.frame then
				done += 1
				self.freshSet[instance] = nil
				if instance.Parent ~= nil then
					inspect(instance)
					stats.freshChecked += 1
				end
			else
				table.insert(keptItems, instance)
				table.insert(keptReady, ready[index])
			end
		end
		self.fresh = keptItems
		self.freshReady = keptReady
	end
	function LayoutGuardController:onTick(_dt)
		local _root = self.target
		if _root ~= nil then
			_root = _root.instance
		end
		local root = _root
		if root == nil and self.runtime ~= nil then
			local primary = self.runtime:primary()
			if primary ~= nil then
				self.target = primary
				root = primary.instance
				self:bindRoot(root)
			end
		end
		if root == nil then
			return nil
		end
		self.frame += 1
		self.sinceSweep += _dt
		self:checkResize(root)
		local budget = Plan.budget(self.burstLeft, #self.fresh)
		if self.burstLeft > 0 then
			self.burstLeft -= 1
		end
		self:drainFresh(budget.fresh)
		-- The background sweep. A finished sweep runs the hitbox pass over what it
		-- saw (geometry repairs have settled by then), then waits out the minimum
		-- interval before walking the tree again.
		if self.cursor > #self.queue then
			if self.pendingOverlap then
				checkOverlappingHitboxes(self.queue)
				self.pendingOverlap = false
			end
			if self.sinceSweep < Plan.MIN_SWEEP_SECONDS then
				return nil
			end
			self.sinceSweep = 0
			-- Reuse the previous sweep's table (it is finished with, and the hitbox pass
			-- that read it already ran above) instead of allocating a new one per sweep.
			local queue = self.queue
			table.clear(queue)
			for _, descendant in root:GetDescendants() do
				if isTrackedClass(descendant) then
					table.insert(queue, descendant)
				end
			end
			self.queue = queue
			self.cursor = 1
			self.pendingOverlap = true
			stats.scans += 1
		end
		local sweepBudget = budget.sweep
		while sweepBudget > 0 and self.cursor <= #self.queue do
			local inst = self.queue[self.cursor]
			self.cursor += 1
			sweepBudget -= 1
			if inst.Parent == nil or self.freshSet[inst] then
				continue
			end
			inspect(inst)
			stats.sweepChecked += 1
		end
	end
	do
		-- (Flamework) LayoutGuardController metadata
		Reflect.defineMetadata(LayoutGuardController, "identifier", "client/layoutGuard@LayoutGuardController")
		Reflect.defineMetadata(LayoutGuardController, "flamework:parameters", { "$c:components@Components", "client/framework/init@UiRuntimeController" })
		Reflect.defineMetadata(LayoutGuardController, "flamework:implements", { "$:flamework@OnInit", "$:flamework@OnStart", "$:flamework@OnTick" })
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
